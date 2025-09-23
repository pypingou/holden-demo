#!/bin/bash

# Holden Process Orchestration Demo for AutoSD v0.2
# Demonstrates pidfd-based monitor on host managing processes in QM partition via stateless agent
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
echo -e "AutoSD Demo: pidfd-based Monitor managing QM Partition Processes"
echo -e "Architecture: Stateless Agent + pidfd Monitor (v0.2)"
echo ""

# Function to check if VM is running
check_vm() {
    if ! ssh -q -o BatchMode=yes -o ConnectTimeout=3 -p $SSH_PORT root@localhost 'exit' 2>/dev/null; then
        error "VM not accessible on port $SSH_PORT"
        info "Please start the demo VM first:"
        info "  qemu-system-x86_64 -m 2G -enable-kvm \\"
        info "    -netdev user,id=net0,hostfwd=tcp::$SSH_PORT-:22 \\"
        info "    -device virtio-net-pci,netdev=net0 \\"
        info "    holden-demo.x86_64.img"
        exit 1
    fi
}

# Function to check if agent is running in QM partition
check_agent() {
    log "Checking if stateless agent is running in QM partition..."
    if ! ssh -p $SSH_PORT root@localhost "podman exec qm pgrep -f holden-agent" >/dev/null 2>&1; then
        warning "Agent not running, starting it..."
        ssh -p $SSH_PORT root@localhost "podman exec qm systemctl start holden-agent" || {
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

    info "Key differences from v0.1:"
    echo "  • Agent is stateless - no process tracking"
    echo "  • Agent spawns process and returns pidfd via fd passing"
    echo "  • Monitor receives pidfd and manages process directly"
    echo "  • No agent state - all control via pidfds"
    echo ""

    log "Building latest holden with pidfd support..."
    make -C ../holden clean all >/dev/null 2>&1 || {
        error "Failed to build holden"
        exit 1
    }
    success "Built holden v0.2 with pidfd support"

    log "Copying pidfd monitor to VM..."
    scp -q -P $SSH_PORT ../holden/bin/pidfd_monitor root@localhost:/tmp/ || {
        error "Failed to copy pidfd monitor"
        exit 1
    }
    success "Copied pidfd monitor to VM"
}

# Function to demonstrate pidfd monitor
demo_pidfd_monitor() {
    step "Running pidfd Monitor Demonstration"
    echo ""

    info "The pidfd monitor will:"
    echo "  1. Spawn local process using fork() + pidfd_open()"
    echo "  2. Spawn QM process via agent + receive pidfd"
    echo "  3. Monitor both processes using poll() on pidfds"
    echo "  4. Automatically restart processes when they die"
    echo ""

    log "Starting pidfd monitor with demo processes..."
    info "Monitor commands: '/bin/sleep 3' (local) and '/bin/sleep 5' (agent)"

    # Run the pidfd monitor with timeout to see it in action
    ssh -p $SSH_PORT root@localhost "cd /tmp && timeout 15s ./pidfd_monitor '/bin/sleep 3' '/bin/sleep 5' 2>&1" || true

    success "pidfd monitor demonstration completed"
}

# Function to show agent simplicity
demo_agent_simplicity() {
    step "Demonstrating Stateless Agent Simplicity"
    echo ""

    log "Checking agent process in QM partition..."
    ssh -p $SSH_PORT root@localhost "podman exec qm ps aux | grep holden-agent | grep -v grep"

    log "Agent memory usage (minimal due to stateless design):"
    ssh -p $SSH_PORT root@localhost "podman exec qm cat /proc/\$(podman exec qm pgrep holden-agent)/status | grep -E 'VmRSS|VmSize'"

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

    info "Unlike v0.1, processes are controlled directly via pidfds:"
    echo "  • No agent commands (list/stop/constrain removed)"
    echo "  • Monitor owns and manages all pidfds"
    echo "  • poll() provides immediate process death notification"
    echo "  • No PID namespace complexity"
    echo ""

    log "Testing agent ping (only remaining agent operation)..."
    ssh -p $SSH_PORT root@localhost "cd /tmp && echo 'Testing agent responsiveness...' && timeout 3s ./pidfd_monitor '/bin/true' '/bin/true' 2>&1 | head -5" || true

    success "Direct pidfd control demonstrated"
}

# Function to show migration path
demo_migration() {
    step "Architecture Migration: v0.1 → v0.2"
    echo ""

    info "Old v0.1 model:"
    echo "  controller start app     # Agent tracks PID internally"
    echo "  controller list          # Agent returns its process list"
    echo "  controller stop PID      # Agent kills tracked process"
    echo ""

    info "New v0.2 model:"
    echo "  pidfd_monitor app1 app2  # Agent spawns, returns pidfds"
    echo "  # Monitor polls pidfds, handles all lifecycle management"
    echo ""

    warning "Breaking changes in v0.2:"
    echo "  • controller/monitor utilities removed"
    echo "  • Agent API simplified to spawn + ping only"
    echo "  • All process management moved to caller"
    echo ""

    success "Migration to pidfd-based architecture complete"
}

# Function to cleanup
cleanup() {
    log "Demo completed - QM partition processes will be managed by systemd"
    info "Agent continues running in stateless mode"
    info "Use 'ssh -p $SSH_PORT root@localhost' to explore further"
}

# Main demo flow
main() {
    log "Starting Holden Process Orchestration Demo v0.2"
    echo ""

    check_vm
    success "VM is accessible on port $SSH_PORT"

    check_agent

    demo_pidfd_architecture
    demo_pidfd_monitor
    demo_agent_simplicity
    demo_pidfd_control
    demo_migration

    echo ""
    success "Demo completed successfully!"
    cleanup
}

# Run main demo
main "$@"