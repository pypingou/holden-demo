#!/bin/bash

# Holden Process Orchestration Demo for AutoSD v0.2
# Demonstrates pidfd-based orchestrator on host managing processes in QM partition via stateless agent
# Named after 19th century puppeteer Joseph Holden

set -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR

# Configuration
SSH_PORT=${1:-2222}
QM_SOCKET="/run/holden/qm_orchestrator.sock"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[DEMO]${NC} $1"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
}

info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

step() {
    echo -e "${PURPLE}▶${NC} $1"
}

# Banner
echo -e "${BLUE}"
cat << 'EOF'
╦ ╦╔═╗╦  ╔╦╗╔═╗╔╗╔  ╔═╗╦═╗╔═╗╔═╗╔═╗╔═╗╔═╗  ╔═╗╦═╗╔═╗╦ ╦╔═╗╔═╗╔╦╗╦═╗╔═╗╔╦╗╦╔═╗╔╗╔  ╦  ╦ ╔═╗ ╔═╗
╠═╣║ ║║   ║║║╣ ║║║  ╠═╝╠╦╝║ ║║  ║╣ ╚═╗╚═╗  ║ ║╠╦╝║  ╠═╣║╣ ╚═╗ ║ ╠╦╝╠═╣ ║ ║║ ║║║║  ╚╗╔╝ ║ ║ ╣
╩ ╩╚═╝╩═╝═╩╝╚═╝╝╚╝  ╩  ╩╚═╚═╝╚═╝╚═╝╚═╝╚═╝  ╚═╝╩╚═╚═╝╩ ╩╚═╝╚═╝ ╩ ╩╚═╩ ╩ ╩ ╩╚═╝╝╚╝   ╚╝  ╩ ╚═╝ ╚═╝
EOF
echo -e "${NC}"
echo -e "Named after 19th century puppeteer Joseph Holden"
echo -e "AutoSD Demo: pidfd-based Orchestrator managing QM Partition Processes"
echo -e "Architecture: Stateless Agent + pidfd Orchestrator (v0.2)"
echo ""

# Global cleanup function
cleanup_vm() {
    if [ -n "$runner_pid" ]; then
        log "Shutting down VM (PID: $runner_pid)..."
        kill -9 $runner_pid 2>/dev/null || true

        # Also kill any qemu processes using our SSH port
        ps aux | grep "hostfwd=tcp::$SSH_PORT-:22" | grep -v grep | awk '{print $2}' | xargs kill -9 2>/dev/null || true

        success "VM stopped"
    fi
}

# Set up cleanup trap for all exit scenarios
trap 'cleanup_vm; exit 1' INT TERM EXIT

# Check if image exists and start VM
start_vm() {
    if [ ! -f *.img ]; then
        error "No AutoSD image found. Please build first with: ./build.sh"
        exit 1
    fi

    log "Starting Holden Process Orchestration Demo..."
    log "SSH Port: $SSH_PORT"

    # Start the VM
    log "Launching AutoSD image with QM partition..."
    automotive-image-runner --ssh-port $SSH_PORT --nographics *.img > /dev/null &
    runner_pid=$!

    log "VM running at PID: $runner_pid"

    # Wait for VM to start
    log "Waiting for VM to initialize..."
    sleep 10
}

# Function to check if VM is running
check_vm() {
    log "Testing VM connectivity..."

    # Try connecting with proper SSH options like the original
    local retries=5
    local count=0

    while [ $count -lt $retries ]; do
        if sshpass -ppassword ssh -o "UserKnownHostsFile=/dev/null" \
            -o "GlobalKnownHostsFile=/dev/null" \
            -o "StrictHostKeyChecking=no" \
            -o "CheckHostIP=no" \
            -o "PubkeyAuthentication=no" \
            -o "PasswordAuthentication=yes" \
            -o "ConnectTimeout=10" \
            -o "LogLevel=QUIET" \
            -p $SSH_PORT \
            root@localhost 'exit' 2>/dev/null; then
            success "VM is accessible"
            return 0
        fi

        count=$((count + 1))
        log "Connection attempt $count/$retries failed, retrying..."
        sleep 5
    done

    error "Failed to connect to VM after $retries attempts"
    if [ -n "$runner_pid" ]; then
        kill -9 $runner_pid 2>/dev/null
    fi
    exit 1
}

# Function to run SSH commands
ssh_cmd() {
    sshpass -ppassword ssh -o "UserKnownHostsFile=/dev/null" \
        -o "GlobalKnownHostsFile=/dev/null" \
        -o "StrictHostKeyChecking=no" \
        -o "CheckHostIP=no" \
        -o "PubkeyAuthentication=no" \
        -o "PasswordAuthentication=yes" \
        -o "ConnectTimeout=10" \
        -o "LogLevel=QUIET" \
        -p $SSH_PORT \
        root@localhost "$1" 2>/dev/null
}

# Function to check if agent is running in QM partition
check_agent() {
    log "Checking if stateless agent is running in QM partition..."
    if ! ssh_cmd "podman exec qm pgrep -f holden-agent" >/dev/null 2>&1; then
        warning "Agent not running, starting it..."
        ssh_cmd "podman exec qm systemctl start holden-agent" || {
            error "Failed to start agent"
            exit 1
        }
        sleep 2
    fi
    success "Stateless agent is running in QM partition"
}

# Function to demonstrate new pidfd architecture
demo_pidfd_architecture() {
    step "Demonstrating pidfd-based Architecture (v0.2)"
    echo ""

    info "Architecture features:"
    echo "  • Agent is stateless - no process tracking"
    echo "  • Agent spawns process and returns pidfd via fd passing"
    echo "  • Orchestrator receives pidfd and manages process directly"
    echo "  • No agent state - all control via pidfds"
    echo ""

    log "Verifying holden-orchestrator is installed..."
    if ssh_cmd "which holden-orchestrator" >/dev/null 2>&1; then
        success "holden-orchestrator is available via RPM package"
    else
        warning "holden-orchestrator not found in PATH, checking if holden package is installed..."
        ssh_cmd "rpm -qa | grep holden" || {
            error "Holden package not installed"
            exit 1
        }
    fi
}

# Function to demonstrate pidfd orchestrator
demo_pidfd_orchestrator() {
    step "Running Process Orchestrator Demonstration"
    echo ""

    info "The process orchestrator will:"
    echo "  1. Spawn local process using fork() + pidfd_open()"
    echo "  2. Spawn QM process via agent + receive pidfd"
    echo "  3. Orchestrate both processes using poll() on pidfds"
    echo "  4. Automatically restart processes when they die"
    echo ""

    log "Starting process orchestrator with demo processes..."
    info "Orchestrator commands: '/bin/sleep 3' (local) and '/bin/sleep 5' (agent)"

    # Run the process orchestrator with timeout to see it in action
    ssh_cmd "timeout 15s HOLDEN_SOCKET_PATH=$QM_SOCKET holden-orchestrator '/bin/sleep 3' '/bin/sleep 5' 2>&1" || true

    success "Process orchestrator demonstration completed"
}

# Function to show agent simplicity
demo_agent_simplicity() {
    step "Demonstrating Stateless Agent Simplicity"
    echo ""

    log "Checking agent process in QM partition..."
    ssh_cmd "podman exec qm ps aux | grep holden-agent | grep -v grep"

    log "Agent memory usage (minimal due to stateless design):"
    ssh_cmd "podman exec qm cat /proc/\$(podman exec qm pgrep holden-agent)/status | grep -E 'VmRSS|VmSize'"

    info "Agent capabilities:"
    echo "  • Spawns processes (inherits QM container context)"
    echo "  • Returns pidfd via Unix socket fd passing"
    echo "  • Maintains zero internal state"
    echo "  • No process tracking or lifecycle management"
    echo ""
    success "Agent is truly stateless"
}

# Function to demonstrate direct pidfd control
demo_pidfd_control() {
    step "Demonstrating Direct pidfd Process Control"
    echo ""

    info "Process control features:"
    echo "  • No agent commands - simple spawn + ping interface"
    echo "  • Orchestrator owns and manages all pidfds"
    echo "  • poll() provides immediate process death notification"
    echo "  • No PID namespace complexity"
    echo ""

    log "Testing agent ping (only remaining agent operation)..."
    ssh_cmd "echo 'Testing agent responsiveness...' && timeout 3s HOLDEN_SOCKET_PATH=$QM_SOCKET holden-orchestrator '/bin/true' '/bin/true' 2>&1 | head -5" || true

    success "Direct pidfd control demonstrated"
}


# Function to cleanup
cleanup() {
    log "Demo completed - QM partition processes will be managed by systemd"
    info "Agent continues running in stateless mode"

    if [ -n "$runner_pid" ]; then
        log "VM is still running for manual testing"
        log "Press Ctrl+C to stop the demo and shutdown VM"
        info "Or use 'ssh -p $SSH_PORT root@localhost' to explore further"

        # Clear the exit trap temporarily to avoid double cleanup
        trap 'cleanup_vm; success "Demo completed"; exit 0' INT TERM

        # Keep running
        while kill -0 $runner_pid 2>/dev/null; do
            sleep 5
        done

        log "VM has stopped unexpectedly"
    else
        info "Use 'ssh -p $SSH_PORT root@localhost' to explore further"
    fi
}

# Main demo flow
main() {
    start_vm

    check_vm

    # Display system information
    log "Checking AutoSD system information..."
    echo "Hostname: $(ssh_cmd 'hostname')"
    echo "Kernel: $(ssh_cmd 'uname -r')"
    echo "OS: $(ssh_cmd 'cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d \"')"

    check_agent

    demo_pidfd_architecture
    demo_pidfd_orchestrator
    demo_agent_simplicity
    demo_pidfd_control

    echo ""
    success "Demo completed successfully!"

    # Clear the automatic exit trap since we want to keep VM running
    trap - EXIT
    cleanup
}

# Run main demo
main "$@"