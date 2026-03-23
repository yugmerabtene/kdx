# AutoDev Orchestrator

This directory contains a local autonomous multi-agent loop that runs for one week by default.

## Agent Lanes

- `dev_parser`: parser and lexer lane
- `dev_codegen`: codegen and ABI lane
- `qa`: regression and soak lane
- `review`: diff and hygiene lane
- `release`: local commit and version tag lane

## Core Files

- `run.py`: orchestrator and lane executor
- `policy.json`: runtime policy and safety limits
- `backlog.json`: template sprint tasks
- `state.json`: template initial state
- `runtime/`: live backlog/state/heartbeat/log files (ignored)
- `systemd/*.template`: user-service unit templates
- `install_systemd.sh`: installs and enables user units

## Quick Start

```bash
python3 .autodev/run.py --once
python3 .autodev/run.py --daemon
```

## Safety

- No force git operations
- Commits only include files outside configured ignore patterns
- Failed tasks are retried up to the policy limit
- Empty backlog auto-regenerates from sprint templates
