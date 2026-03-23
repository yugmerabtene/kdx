# AutoDev Orchestrator

This directory contains a local autonomous multi-agent loop that runs for one week by default.

## Agent Lanes

- `dev_parser`: parser and lexer lane
- `dev_codegen`: codegen and ABI lane
- `qa`: regression and soak lane
- `review`: diff and hygiene lane
- `release`: local commit and version tag lane
- `perf_memory`: performance and memory sweep lane
- `security_safety`: safety and hardening lane
- `spec_consistency`: language-spec drift lane
- `incident_recovery`: watchdog and restart lane
- `metrics_observe`: observability snapshot lane

Feature-growth lanes are defined in `.autodev/feature_backlog.json` and executed
periodically between validation cycles.

## Core Files

- `run.py`: orchestrator and lane executor
- `policy.json`: runtime policy and safety limits
- `backlog.json`: template sprint tasks
- `feature_backlog.json`: template feature-growth tasks
- `state.json`: template initial state
- `runtime/`: live backlog/state/heartbeat/log files (ignored)
- `systemd/*.template`: user-service unit templates
- `install_systemd.sh`: installs and enables user units

## Quick Start

```bash
python3 .autodev/run.py --once
python3 .autodev/run.py --daemon
```

Install persistent orchestrator + workers:

```bash
./.autodev/install_systemd.sh
```

Default non-stop workers:

- `kdx-autodev-worker@parser.service`
- `kdx-autodev-worker@codegen.service`
- `kdx-autodev-worker@qa.service`
- `kdx-autodev-worker@reliability.service`

## Safety

- No force git operations
- Commits only include files outside configured ignore patterns
- Failed tasks are retried up to the policy limit
- Empty backlog auto-regenerates from sprint templates
