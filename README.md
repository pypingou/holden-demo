# Holden Process Orchestration Demo for AutoSD

This demo showcases the **Holden Process Orchestration System v0.2** in an AutoSD (Automotive Safety Distribution) environment, demonstrating how a pidfd-based orchestrator running on the host partition can manage processes within the QM (Quality Management) partition using the stateless agent.

Named after 19th century puppeteer Joseph Holden, this system provides precise control over process lifecycles in safety-critical automotive environments using modern Linux pidfd technology.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                               AutoSD Host System                                       │
│                                                                                         │
│  ┌────────────────────────────────┐              ┌─────────────────────────────────┐  │
│  │        Main Partition          │              │         QM Partition            │  │
│  │     (Safety Critical)          │              │   (Quality Managed/Non-Safety)  │  │
│  │                                │              │                                 │  │
│  │  ┌──────────────────────────┐  │              │  ┌───────────────────────────┐  │  │
│  │  │   holden-orchestrator    │  │              │  │      holden-agent         │  │  │
│  │  │                          │  │              │  │                           │  │  │
│  │  │ ┌─────────┬─────────────┐│  │              │  │ ┌─────────────────────────┐│  │  │
│  │  │ │Local    │Agent        ││  │   Socket     │  │ │   Stateless Agent       ││  │  │
│  │  │ │Process  │Process      ││  │ ◄──────────► │  │ │                         ││  │  │
│  │  │ │         │             ││  │   + fd       │  │ │ 1. Receive command      ││  │  │
│  │  │ │fork()   │spawn via    ││  │   passing    │  │ │ 2. fork() + exec()      ││  │  │
│  │  │ │pidfd    │agent        ││  │              │  │ │ 3. pidfd_open(child)    ││  │  │
│  │  │ │         │get pidfd    ││  │              │  │ │ 4. send_fd(pidfd)       ││  │  │
│  │  │ └─────────┴─────────────┘│  │              │  │ │ 5. close(pidfd)         ││  │  │
│  │  │                          │  │              │  │ │                         ││  │  │
│  │  │ ┌─────────────────────────┐│  │              │  │ No state maintained     ││  │  │
│  │  │ │   Event Loop:           ││  │              │  │ No process tracking     ││  │  │
│  │  │ │                         ││  │              │  │ No lifecycle mgmt       ││  │  │
│  │  │ │ poll(local_pidfd,       ││  │              │  │                         ││  │  │
│  │  │ │      agent_pidfd)       ││  │              │  └─────────────────────────┘│  │  │
│  │  │ │                         ││  │              │                             │  │  │
│  │  │ │ if process dies:        ││  │              │  QM Child Process:          │  │  │
│  │  │ │   restart immediately   ││  │              │  ┌─────────────────────────┐│  │  │
│  │  │ │                         ││  │              │  │ PID: 789                ││  │  │
│  │  │ │ Restart count: N        ││  │              │  │ Context: QM container   ││  │  │
│  │  │ └─────────────────────────┘│  │              │  │ Managed via: pidfd      ││  │  │
│  │  └──────────────────────────────┘  │              │  │ (from Main partition)   ││  │  │
│  │                                │  │              │  └─────────────────────────┘│  │  │
│  │  Local Child Process:         │  │              │                             │  │  │
│  │  ┌─────────────────────────┐  │  │              │  ┌───────────────────────────┐│  │  │
│  │  │ PID: 456                │  │  │              │  │       systemd             ││  │  │
│  │  │ Context: Main partition │  │  │              │  │ ┌───────────────────────┐ ││  │  │
│  │  │ Managed via: pidfd      │  │  │              │  │ │ holden-agent.service  │ ││  │  │
│  │  └─────────────────────────┘  │  │              │  │ │ • Auto-start agent    │ ││  │  │
│  └────────────────────────────────┘  │              │  │ │ • Restart on failure │ ││  │  │
│                                       │              │  │ │ • Security sandbox   │ ││  │  │
│                                       │              │  │ └───────────────────────┘ ││  │  │
│                                       │              │  └───────────────────────────┘│  │  │
│                                       │              └─────────────────────────────────┘  │
│                                       │                                                    │
│ Key Advantages:                       │                                                    │
│ • Event-driven monitoring (no polls) │                                                    │
│ • Immediate death detection          │                                                    │
│ • Cross-partition process control    │                                                    │
│ • Agent reliability (stateless)      │                                                    │
│ • No zombie processes (pidfd cleanup)│                                                    │
│                                       │                                                    │
│ Communication: Unix Socket (/run/holden/qm_orchestrator.sock) + fd passing               │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

## Key Components

### 1. Stateless Agent (QM Partition)
- **No state management**: Agent doesn't track processes
- **Process spawning**: Uses fork() + exec() with container context inheritance
- **pidfd creation**: Calls pidfd_open() for each spawned process
- **fd passing**: Returns pidfd to caller via Unix socket
- **Immediate cleanup**: Agent closes pidfd after passing it

### 2. pidfd Orchestrator (Main Partition)
- **Direct control**: Receives pidfds and manages processes directly
- **Poll-based monitoring**: Uses poll() on pidfds to detect process death
- **Auto-restart**: Automatically respawns failed processes
- **Process management**: Stop, restart, orchestration all handled by orchestrator

## New Architecture Benefits

### Safety & Reliability
- **Stateless agent**: No agent state to corrupt or lose
- **pidfd reliability**: Kernel-guaranteed process references
- **Immediate detection**: poll() provides instant process death notification
- **No race conditions**: pidfd eliminates PID reuse issues

### Performance
- **Minimal overhead**: Agent just spawns and passes reference
- **Efficient monitoring**: poll() scales better than traditional approaches
- **No periodic polling**: Event-driven process monitoring

### Security
- **Least privilege**: Agent has minimal responsibilities
- **fd passing security**: Secure pidfd transfer over Unix sockets
- **Container isolation**: Processes inherit agent's container context

## Demo Flow

The demo demonstrates the complete lifecycle:

1. **Agent startup**: Stateless agent starts in QM partition
2. **Process spawning**: Orchestrator requests agent to spawn processes
3. **pidfd passing**: Agent returns pidfd references to orchestrator
4. **Active orchestration**: Orchestrator polls pidfds for process events
5. **Auto-restart**: Failed processes are automatically restarted
6. **Graceful shutdown**: Orchestrator can cleanly stop all processes

## Protocol

### Agent Operations
- `MSG_START_PROCESS`: Spawn process, return pidfd via fd passing
- `MSG_PING`: Health check

### Removed Operations (v0.1 legacy)
- ~~`MSG_LIST_PROCESSES`~~: No agent state to list
- ~~`MSG_STOP_PROCESS`~~: Orchestrator uses pidfd directly
- ~~`MSG_APPLY_CONSTRAINTS`~~: Orchestrator applies constraints via pidfd

## Files

- `demo.sh`: Main demonstration script
- `holden-demo.aib.yml`: AutoSD image builder configuration
- `build.sh`: Demo VM image build script
- `test.sh`: Quick functionality test

## Usage

### Quick Demo
```bash
./demo.sh
```

### Build Demo VM
```bash
./build.sh
```

### Test Functionality
```bash
./test.sh
```

## Requirements

- Linux with pidfd support (kernel 5.3+)
- AutoSD or compatible container environment
- SSH access to QM partition (for demo)


## License

This demo is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.