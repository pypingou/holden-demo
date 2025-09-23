# Holden Process Orchestration Demo for AutoSD

This demo showcases the **Holden Process Orchestration System** in an AutoSD (Automotive Safety Distribution) environment, demonstrating how a controller running on the host partition can manage processes within the QM (Quality Management) partition.

Named after 19th century puppeteer Joseph Holden, this system provides precise control over process lifecycles in safety-critical automotive environments.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              AutoSD Host System                                 │
│                                                                                 │
│  ┌───────────────────────────────────┐    ┌─────────────────────────────────────┐│
│  │         Main Partition            │    │          QM Partition               ││
│  │      (Safety Critical)            │    │    (Quality Managed/Non-Safety)    ││
│  │         ASIL Processes            │    │                                     ││
│  │                                   │    │                                     ││
│  │  ┌─────────────────────────────┐  │    │  ┌─────────────────────────────┐    ││
│  │  │     holden-controller       │  │    │  │       holden-agent         │    ││
│  │  │   ┌─────────────────────┐   │  │    │  │     ┌─────────────────┐     │    ││
│  │  │   │ CLI Commands:       │   │  │    │  │     │ Process Manager │     │    ││
│  │  │   │ • start <cmd>       │   │  │    │  │     │ • Fork/Exec     │     │    ││
│  │  │   │ • stop <pid>        │   │  │    │  │     │ • Monitor       │     │    ││
│  │  │   │ • list              │   │  │    │  │     │ • cgroups       │     │    ││
│  │  │   │ • constrain         │   │  │    │  │     │ • Cleanup       │     │    ││
│  │  │   └─────────────────────┘   │  │    │  │     └─────────────────┘     │    ││
│  │  └─────────────────────────────┘  │    │  └─────────────────────────────┘    ││
│  │                │                  │    │                │                    ││
│  │  ┌─────────────────────────────┐  │    │  ┌─────────────────────────────┐    ││
│  │  │     holden-monitor          │  │    │  │       systemd               │    ││
│  │  │   (Real-time monitoring)    │  │    │  │   ┌─────────────────────┐   │    ││
│  │  └─────────────────────────────┘  │    │  │   │ holden-agent.service│   │    ││
│  │                │                  │    │  │   │ • Auto-start        │   │    ││
│  │                │                  │    │  │   │ • Restart on fail   │   │    ││
│  └────────────────┼──────────────────┘    │  │   │ • Security sandbox  │   │    ││
│                   │                       │  │   └─────────────────────┘   │    ││
│                   │                       │  └─────────────────────────────┘    ││
│                   │                       │                │                    ││
│                   │    ┌─────────────────────────────────────┘                 ││
│                   │    │                  │                                     ││
│                   │    │                  │  ┌─────────────────────────────┐    ││
│                   │    │                  │  │   Non-Safety Processes      │    ││
│                   │    │                  │  │  ┌─────┐ ┌─────┐ ┌─────┐     │    ││
│                   │    │                  │  │  │ PID │ │ PID │ │ PID │     │    ││
│                   │    │                  │  │  │ 123 │ │ 456 │ │ 789 │     │    ││
│                   │    │                  │  │  └─────┘ └─────┘ └─────┘     │    ││
│                   │    │                  │  │    ↓       ↓       ↓         │    ││
│                   │    │                  │  │ [cgroups constraints]        │    ││
│                   │    │                  │  └─────────────────────────────┘    ││
│                   │    │                  │                                     ││
│  ┌────────────────▼────▼──────────────────▼─────────────────────────────────────┤│
│  │                     /run/holden (Shared Directory)                         ││
│  │  ┌─────────────────────────────────────────────────────────────────────┐   ││
│  │  │                qm_orchestrator.sock                                 │   ││
│  │  │              (Unix Domain Socket)                                   │   ││
│  │  │                                                                     │   ││
│  │  │  Protocol Messages:                                                 │   ││
│  │  │  • MSG_START_PROCESS  ←→  MSG_PROCESS_STARTED                       │   ││
│  │  │  • MSG_STOP_PROCESS   ←→  MSG_PROCESS_STOPPED                       │   ││
│  │  │  • MSG_LIST_PROCESSES ←→  MSG_PROCESS_LIST                          │   ││
│  │  │  • MSG_APPLY_CONSTRAINTS ←→ MSG_CONSTRAINTS_APPLIED                 │   ││
│  │  └─────────────────────────────────────────────────────────────────────┘   ││
│  └─────────────────────────────────────────────────────────────────────────────┤│
│                                                                                 │
│  Configuration Files:                                                          │
│  • /usr/lib/tmpfiles.d/holden_ipc.conf (creates shared directory)             │
│  • /etc/containers/systemd/qm.container.d/10-holden-ipc.conf (mounts volume)  │
│  • /usr/lib/qm/rootfs/etc/holden/agent.conf (agent configuration)             │
└─────────────────────────────────────────────────────────────────────────────────┘

Data Flow:
1. User runs: HOLDEN_SOCKET_PATH=/run/holden/qm_orchestrator.sock holden-controller start sleep 30
2. Controller (safety-critical partition) connects to Unix socket
3. Agent (QM partition) receives command, forks non-safety process
4. Agent applies cgroups constraints (memory/CPU limits)
5. Agent responds with process PID
6. Safety-critical controller can monitor, constrain, or stop QM processes
```

## Key Components

### Main Partition
- **holden-controller**: CLI tool for process orchestration
- **holden-monitor**: Process monitoring utility
- **Shared IPC Directory**: `/run/holden` (mounted into QM partition)

### QM Partition
- **holden-agent**: Daemon that manages processes (runs as systemd service)
- **Socket**: `/run/holden/qm_orchestrator.sock` (accessible from host)
- **Configuration**: `/etc/holden/agent.conf` (customized for QM environment)

## Setup and Configuration

### AIB Manifest Configuration

The `holden-demo.aib.yml` manifest configures:

1. **Shared Filesystem Setup**:
   ```yaml
   add_files:
     - path: /usr/lib/tmpfiles.d/holden_ipc.conf
       text: |
         D! /run/holden 0755 root root
     - path: /etc/containers/systemd/qm.container.d/10-holden-ipc.conf
       text: |
         [Container]
         Volume=/run/holden:/run/holden
   ```

2. **QM Agent Configuration**:
   ```yaml
   qm:
     content:
       add_files:
         - path: /etc/holden/agent.conf
           text: |
             SOCKET_PATH=/run/holden/qm_orchestrator.sock
             # ... other configuration
   ```

3. **Systemd Service**:
   ```yaml
   systemd:
     enabled_services:
       - holden-agent
   ```

## Running the Demo

### 1. Build the AutoSD Image
```bash
./build.sh
```

### 2. Launch the Demo
```bash
./demo.sh [ssh_port]
```

Default SSH port is 2222. The demo will:
- Start the AutoSD VM
- Verify QM partition mounting
- Check holden package installation
- Verify shared filesystem setup
- Test holden-agent service status
- Provide interactive commands

### 3. Interactive Testing

Once the demo is running, connect to the VM:
```bash
sshpass -ppassword ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p 2222 root@localhost
```

## Demo Commands

### Basic Process Management
```bash
# List processes managed by QM agent
HOLDEN_SOCKET_PATH=/run/holden/qm_orchestrator.sock holden-controller list

# Start processes in QM partition
HOLDEN_SOCKET_PATH=/run/holden/qm_orchestrator.sock holden-controller start sleep 60
HOLDEN_SOCKET_PATH=/run/holden/qm_orchestrator.sock holden-controller start ping -c 10 127.0.0.1

# Monitor processes
HOLDEN_SOCKET_PATH=/run/holden/qm_orchestrator.sock holden-controller monitor
```

### Resource Constraints (if cgroups available)
```bash
# Apply memory and CPU limits
HOLDEN_SOCKET_PATH=/run/holden/qm_orchestrator.sock holden-controller constrain <pid> 50 25
```

### Process Cleanup
```bash
# Stop specific process
HOLDEN_SOCKET_PATH=/run/holden/qm_orchestrator.sock holden-controller stop <pid>
```

### QM Partition Verification
```bash
# Check processes from QM perspective
podman exec -ti qm ps aux
podman exec -ti qm holden-controller list

# Check systemd service
podman exec -ti qm systemctl status holden-agent
```

## Communication Protocol

The system uses Unix domain sockets for secure, high-performance communication:

- **Socket Path**: `/run/holden/qm_orchestrator.sock`
- **Protocol**: Binary message-based
- **Messages**: START_PROCESS, LIST_PROCESSES, STOP_PROCESS, APPLY_CONSTRAINTS
- **Security**: Local-only communication, no network exposure

## Features Demonstrated

### ✅ Cross-Partition Process Management
- Host controller managing QM partition processes
- Secure communication via shared filesystem

### ✅ Safety-Critical Architecture
- QM partition isolation for quality-managed code
- Systemd service management with proper lifecycle

### ✅ Resource Management
- cgroups v2 integration for memory/CPU constraints
- Process monitoring and health checking

### ✅ Automotive Compliance
- AutoSD distribution compatibility
- Quality Management partition support

## Testing and Validation

### Automated Tests
```bash
# Quick functionality test
./test.sh
```

### Manual Verification
1. **Service Status**: Verify holden-agent runs as systemd service
2. **Socket Communication**: Test controller-agent communication
3. **Process Isolation**: Confirm processes run in QM partition
4. **Resource Constraints**: Apply and verify cgroups limits

## Troubleshooting

### Common Issues

1. **Agent Not Running**
   - Check: `systemctl --root=/usr/share/qm/rootfs status holden-agent`
   - Fix: Verify service is enabled in AIB manifest

2. **Socket Not Found**
   - Check: `ls -la /run/holden/`
   - Fix: Verify shared filesystem configuration

3. **Controller Connection Failed**
   - Check: `HOLDEN_SOCKET_PATH=/run/holden/qm_orchestrator.sock holden-controller list`
   - Fix: Ensure agent is running and socket exists

4. **QM Partition Not Mounted**
   - Check: `ls -la /usr/lib/qm/rootfs`
   - Fix: Verify QM partition in AIB manifest

### Debug Commands
```bash
# Check agent process
podman exec -ti qm ps aux | grep holden

# Verify socket permissions
ls -la /run/holden/

# Check systemd logs
podman exec -ti qm journalctl -u holden-agent
```

## Security Considerations

- **Local Communication**: Unix sockets provide secure local IPC
- **Process Isolation**: QM partition provides safety-critical isolation
- **No Network Exposure**: System operates entirely locally
- **systemd Integration**: Proper service lifecycle management

## Requirements

- **AutoSD 9 or later**
- **cgroups v2 support** (for resource constraints)
- **QM partition support**
- **Root privileges** (for cgroups operations)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

*Named after 19th century puppeteer Joseph Holden, this system provides precise control over process lifecycles in automotive safety-critical environments.*