#!/bin/bash

# Holden Process Orchestration Demo for AutoSD
# Demonstrates controller on host managing processes in QM partition via shared filesystem
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

# Banner
echo -e "${BLUE}"
cat << 'EOF'
╦ ╦╔═╗╦  ╔╦╗╔═╗╔╗╔  ╔═╗╦═╗╔═╗╔═╗╔═╗╔═╗╔═╗  ╔═╗╦═╗╔═╗╦ ╦╔═╗╔═╗╔╦╗╦═╗╔═╗╔╦╗╦╔═╗╔╗╔
╠═╣║ ║║   ║║║╣ ║║║  ╠═╝╠╦╝║ ║║  ║╣ ╚═╗╚═╗  ║ ║╠╦╝║  ╠═╣║╣ ╚═╗ ║ ╠╦╝╠═╣ ║ ║║ ║║║║
╩ ╩╚═╝╩═╝═╩╝╚═╝╝╚╝  ╩  ╩╚═╚═╝╚═╝╚═╝╚═╝╚═╝  ╚═╝╩╚═╚═╝╩ ╩╚═╝╚═╝ ╩ ╩╚═╩ ╩ ╩ ╩╚═╝╝╚╝
EOF
echo -e "${NC}"
echo -e "Named after 19th century puppeteer Joseph Holden"
echo -e "AutoSD Demo: Host Controller managing QM Partition Processes"
echo ""

# Check if image exists
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
sleep 20

# Function to run SSH commands
ssh_cmd() {
    sshpass -ppassword ssh -o "UserKnownHostsFile=/dev/null" \
        -o "StrictHostKeyChecking no" \
        -o "PubkeyAuthentication=no" \
        -o "ConnectTimeout=10" \
        -p $SSH_PORT \
        root@localhost "$1" 2>/dev/null
}

# Test basic connectivity
log "Testing VM connectivity..."
if ssh_cmd "echo 'VM is ready'"; then
    success "VM is accessible"
else
    error "Failed to connect to VM"
    kill -9 $runner_pid 2>/dev/null
    exit 1
fi

# Display system information
log "Checking AutoSD system information..."
echo "Hostname: $(ssh_cmd 'hostname')"
echo "Kernel: $(ssh_cmd 'uname -r')"
echo "OS: $(ssh_cmd 'cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d \"')"

# Check QM partition
log "Verifying QM partition is mounted..."
if ssh_cmd "ls -la /usr/lib/qm/rootfs" | grep -q "bin"; then
    success "QM partition is properly mounted"
    ssh_cmd "df -h /usr/lib/qm/rootfs | tail -1"
else
    error "QM partition not found or not mounted"
fi

# Check holden packages installation
log "Verifying Holden package installation..."
echo "Main partition packages:"
ssh_cmd "rpm -qa | grep holden | grep -v agent || echo 'holden controller not found'"

echo "QM partition packages:"
if ssh_cmd "podman exec -ti qm rpm -qa | grep holden-agent"; then
    success "holden-agent found in QM partition"
else
    warning "holden-agent not found in QM partition"
fi

# Check shared filesystem setup
log "Verifying shared filesystem configuration..."
if ssh_cmd "ls -ld /run/holden"; then
    success "Shared IPC directory exists: /run/holden"
else
    warning "Shared IPC directory not found, creating it..."
    ssh_cmd "mkdir -p /run/holden && chmod 755 /run/holden"
fi

# Check holden-agent service status in QM partition
log "Checking holden-agent service status in QM partition..."
if ssh_cmd "podman exec -ti qm systemctl is-active holden-agent"; then
    success "holden-agent service is running in QM partition"
elif ssh_cmd "podman exec -ti qm systemctl is-enabled holden-agent"; then
    success "holden-agent service is enabled in QM partition"
    log "Service should start automatically with QM partition"
    sleep 3
else
    warning "holden-agent service not found or not enabled"
    log "Check systemd service configuration in AIB manifest"
fi

# Check if agent socket exists
log "Checking for agent socket..."
if ssh_cmd "ls -la $QM_SOCKET 2>/dev/null"; then
    success "Agent socket found: $QM_SOCKET"
else
    warning "Agent socket not found"
    log "Checking agent process and socket location..."
    ssh_cmd "podman exec -ti qm ps aux | grep holden-agent | grep -v grep || echo 'No agent process found'"
    ssh_cmd "podman exec -ti qm find /tmp -name '*orchestrator*' 2>/dev/null || echo 'No orchestrator sockets found in QM /tmp'"
    ssh_cmd "find /run -name '*orchestrator*' 2>/dev/null || echo 'No orchestrator sockets found in /run'"
fi

# Demonstrate controller commands
log "Testing Holden controller functionality..."

echo ""
echo -e "${YELLOW}=== HOLDEN DEMO COMMANDS ===${NC}"
echo -e "You can now test the Holden process orchestration system!"
echo ""
echo -e "${GREEN}1. Connect to the VM:${NC}"
echo "   sshpass -ppassword ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p $SSH_PORT root@localhost"
echo ""
echo -e "${GREEN}2. Test controller from main partition (managing QM processes):${NC}"
echo "   HOLDEN_SOCKET_PATH=$QM_SOCKET holden-controller list"
echo "   HOLDEN_SOCKET_PATH=$QM_SOCKET holden-controller start sleep 30"
echo "   HOLDEN_SOCKET_PATH=$QM_SOCKET holden-controller start ping -c 10 127.0.0.1"
echo "   HOLDEN_SOCKET_PATH=$QM_SOCKET holden-controller list"
echo "   HOLDEN_SOCKET_PATH=$QM_SOCKET holden-controller monitor"
echo ""
echo -e "${GREEN}3. Apply resource constraints (if cgroups available):${NC}"
echo "   HOLDEN_SOCKET_PATH=$QM_SOCKET holden-controller constrain <pid> 50 25"
echo ""
echo -e "${GREEN}4. Stop processes:${NC}"
echo "   HOLDEN_SOCKET_PATH=$QM_SOCKET holden-controller stop <pid>"
echo ""
echo -e "${GREEN}5. Check from QM perspective:${NC}"
echo "   podman exec -ti qm ps aux"
echo "   podman exec -ti qm holden-controller list"
echo ""

# Test a basic command to show it's working
log "Demonstrating basic functionality..."
if ssh_cmd "HOLDEN_SOCKET_PATH=$QM_SOCKET timeout 5 holden-controller list"; then
    success "Controller can communicate with QM agent!"
else
    warning "Controller communication test failed - this is expected in some configurations"
fi

# Keep VM running for manual testing
log "VM is ready for manual testing"
log "Press Ctrl+C to stop the demo and shutdown VM"

# Wait for user interrupt
trap 'echo ""; log "Shutting down demo..."; kill -9 $runner_pid 2>/dev/null; ps aux | grep "hostfwd=tcp::$SSH_PORT-:22" | head -n -1 | awk "{ print \$2 }" | xargs kill -9 2>/dev/null; success "Demo completed"; exit 0' INT

# Keep running
while kill -0 $runner_pid 2>/dev/null; do
    sleep 5
done

log "VM has stopped unexpectedly"