# Holden Process Orchestration Demo for AutoSD

This demo showcases the **Holden Process Orchestration System v0.2** in an AutoSD (Automotive Safety Distribution) environment, demonstrating how a pidfd-based monitor running on the host partition can manage processes within the QM (Quality Management) partition using the stateless agent.

Named after 19th century puppeteer Joseph Holden, this system provides precise control over process lifecycles in safety-critical automotive environments using modern Linux pidfd technology.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              AutoSD Host System                                 │
│                                                                                 │
│  ┌───────────────────────────────────┐    ┌────────────────────────────────────┐│
│  │         Main Partition            │    │          QM Partition              ││
│  │      (Safety Critical)            │    │    (Quality Managed/Non-Safety)    ││
│  │         ASIL Processes            │    │                                    ││
│  │                                   │    │                                    ││
│  │  ┌─────────────────────────────┐  │    │  ┌─────────────────────────────┐   ││
│  │  │    holden-pidfd-monitor     │  │    │  │       holden-agent          │   ││
│  │  │   ┌─────────────────────┐   │  │    │  │     ┌─────────────────┐     │   ││
│  │  │   │ pidfd Management:   │   │  │    │  │     │ Stateless Spawn │     │   ││
│  │  │   │ • Poll pidfds       │   │  │    │  │     │ • fork() + exec │     │   ││
│  │  │   │ • Detect deaths     │   │  │    │  │     │ • pidfd_open()  │     │   ││
│  │  │   │ • Auto restart      │   │  │    │  │     │ • fd passing    │     │   ││
│  │  │   │ • Process control   │   │  │    │  │     │ • No state      │     │   ││
│  │  │   └─────────────────────┘   │  │    │  │     └─────────────────┘     │   ││
│  │  └─────────────────────────────┘  │    │  └─────────────────────────────┘   ││
│  │                │                  │    │                │                   ││
│  │                │                  │    │  ┌─────────────────────────────┐   ││
│  │                │                  │    │  │       systemd               │   ││
│  │                │                  │    │  │   ┌─────────────────────┐   │   ││
│  │                │                  │    │  │   │ holden-agent.service│   │   ││
│  │                │                  │    │  │   │ • Auto-start        │   │   ││
│  │                │                  │    │  │   │ • Restart on fail   │   │   ││
│  └────────────────┼──────────────────┘    │  │   │ • Security sandbox  │   │   ││
│                   │                       │  │   └─────────────────────┘   │   ││
│                   │                       │  └─────────────────────────────┘   ││
│                   │                       │                │                   ││
│                   │    ┌───────────────────────────────────┘                   ││
│                   │    │                  │                                    ││
│                   │    │                  │  ┌─────────────────────────────┐   ││
│                   │    │                  │  │   Non-Safety Processes      │   ││
│                   │    │                  │  │  ┌─────┐ ┌─────┐ ┌─────┐    │   ││
│                   │    │                  │  │  │ PID │ │ PID │ │ PID │    │   ││
│                   │    │                  │  │  │ 123 │ │ 456 │ │ 789 │    │   ││
│                   │    │                  │  │  └─────┘ └─────┘ └─────┘    │   ││
│                   │    │                  │  │    ↑       ↑       ↑        │   ││
│                   │    │                  │  │ [pidfd monitoring]          │   ││
│                   │    │                  │  └─────────────────────────────┘   ││
│                   │    │                  │                                    ││
│                   │    └──────────────────┘                                    ││
│                   │                                                            ││
│                   └─── Unix Socket + fd passing ─────────────────────────────────┤
│                        /run/holden/qm_orchestrator.sock                        │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Key Components

### 1. Stateless Agent (QM Partition)
- **No state management**: Agent doesn't track processes
- **Process spawning**: Uses fork() + exec() with container context inheritance
- **pidfd creation**: Calls pidfd_open() for each spawned process
- **fd passing**: Returns pidfd to caller via Unix socket
- **Immediate cleanup**: Agent closes pidfd after passing it

### 2. pidfd Monitor (Main Partition)
- **Direct control**: Receives pidfds and manages processes directly
- **Poll-based monitoring**: Uses poll() on pidfds to detect process death
- **Auto-restart**: Automatically respawns failed processes
- **Process management**: Stop, restart, monitor all handled by monitor

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
2. **Process spawning**: Monitor requests agent to spawn processes
3. **pidfd passing**: Agent returns pidfd references to monitor
4. **Active monitoring**: Monitor polls pidfds for process events
5. **Auto-restart**: Failed processes are automatically restarted
6. **Graceful shutdown**: Monitor can cleanly stop all processes

## Protocol

### Agent Operations
- `MSG_START_PROCESS`: Spawn process, return pidfd via fd passing
- `MSG_PING`: Health check

### Removed Operations (v0.1 legacy)
- ~~`MSG_LIST_PROCESSES`~~: No agent state to list
- ~~`MSG_STOP_PROCESS`~~: Monitor uses pidfd directly
- ~~`MSG_APPLY_CONSTRAINTS`~~: Monitor applies constraints via pidfd

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

## Migration from v0.1

**Old Model (v0.1)**: Stateful agent with controller
```bash
controller start app     # Agent tracks PID internally
controller list          # Agent returns its process list
controller stop PID      # Agent kills tracked process
```

**New Model (v0.2)**: Stateless agent with pidfd monitor
```bash
pidfd_monitor app1 app2  # Agent spawns, returns pidfds
# Monitor polls pidfds, handles all lifecycle management
```

The v0.2 architecture eliminates agent state management entirely, delegating all process control to the caller via pidfd references.

## License

This demo is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.