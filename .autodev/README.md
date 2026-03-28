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
- `fuzzing_stability`: grammar and random-input crash hunting lane
- `runtime_oracle`: compile+run behavior oracle lane
- `crash_triage`: crash/drift triage and signal summarization lane
- `regression_bisect`: non-destructive suspect-commit extraction lane
- `quick_tests`: generate and run fast manual test pack
- `regression_guard`: release safety gate over core suites
- `minimizer`: failed-case reducer and repro minimizer lane
- `release_manager`: release readiness and next-tag suggestion lane
- `flaky_hunter`: repeated-run instability detector lane
- `cicd_devops`: branch protection and CI policy synchronization lane
- `juriste_license`: licensing and commercial-usage policy audit (one-shot)

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
- `kdx-autodev-worker@devops.service`
- `kdx-autodev-worker@security.service`
- `kdx-autodev-worker@release.service`
- `kdx-autodev-worker@webdocs.service`
- `kdx-autodev-worker@agent_impl.service`
- `kdx-autodev-worker@agent_verify.service`

`agent_impl` and `agent_verify` are designed to work on the same mission split:

- `agent_impl`: implementation and artifact preparation
- `agent_verify`: regression/security verification and gate validation

One-shot worker (manual trigger):

- `kdx-autodev-worker@juriste.service` (runs once, then exits)

## Safety

- No force git operations
- Commits only include files outside configured ignore patterns
- Autocommit respects policy branch (`commit_branch`), with `auto` using remote HEAD branch
- DevOps worker performs periodic commit+push sync via `lanes/devops_sync.py`
  - Manual dry run: `python3 ./.autodev/lanes/devops_sync.py --dry-run`
- Failed tasks are retried up to the policy limit
- Empty backlog auto-regenerates from sprint templates

## Throughput Mode (Commando)

- Policy file: `.autodev/policy.json`
- Default throughput settings:
  - `loop_sleep_seconds = 15`
  - `qa_loops = 1`
  - `feature_enabled = false` (validation/release focus)
  - `feature_every_n_validation_tasks = 6`
  - `p0p1_only = true`
  - `strict_focus_only = true`
- `focus_lanes` prioritize CI/security/release lanes first
- Worker loop interval can be overridden with:
  - `AUTODEV_WORKER_SLEEP_SECONDS=<n>`
- DevOps push cadence can be tuned in `.autodev/policy.json`:
  - `devops_sync_min_minutes`
  - `autopush`
  - `push_remote`

## Minimal 3-Agent Acceleration Plan

Execution order is chosen for maximum impact with minimal orchestration overhead:

1. `fuzzing_stability` (first)
   - KPI: zero segfault/timeouts across seeded fuzz batch (`/tmp/autodev_fuzzing_report.json`)
2. `runtime_oracle` (second)
   - KPI: stable exit-code contract on pinned runtime fixtures (`hello`, `control_flow`, `if_chain`, `while_return`)
3. `crash_triage` (third)
   - KPI: triage snapshot produced every cycle with crash/drift counts and top candidates (`/tmp/autodev_crash_triage.md`)

## Optional Add-On Agent

- `regression_bisect`
  - Purpose: infer suspect commits around latest failure window without checkout-based bisect
  - Outputs: `/.autodev/runtime/regression_bisect.json`, `/tmp/autodev_regression_bisect.md`

## Additional High-Impact Lanes

- `regression_guard`
  - Purpose: run release safety gate over build/test/quick/spec/oracle
  - Outputs: `/.autodev/runtime/regression_guard.json`, `/tmp/autodev_regression_guard.md`
- `minimizer`
  - Purpose: reduce latest failing `.kdx` case to minimal repro candidate
  - Outputs: `/.autodev/runtime/minimizer.json`, `/tmp/autodev_minimizer/`
- `release_manager`
  - Purpose: evaluate release readiness and suggest next semantic tag
  - Outputs: `/.autodev/runtime/release_manager.json`, `/tmp/autodev_release_manager.md`
- `flaky_hunter`
  - Purpose: re-run critical suites multiple times to detect instability
  - Outputs: `/.autodev/runtime/flaky_hunter.json`, `/tmp/autodev_flaky_hunter.md`

## Quick Manual Suite

- Generate/update files: `python3 ./.autodev/features/quick_test_agent.py --refresh`
- Run stable fast suite: `./quick_tests/run_quick_tests.sh`
- Lane entrypoint: `./.autodev/lanes/quick_tests.sh`
- Generate spec pack: `python3 ./.autodev/features/spec_test_agent.py --refresh`
- Run spec tracking suite: `./quick_tests/run_spec_tests.sh`
- Run strict target-spec suite: `./quick_tests/run_spec_tests.sh --target`
