# KodPix Autonomous Scrum

This repository is operated with a specialized multi-team scrum model for continuous local development.

## Team Topology

### Team Core Compiler

- Agent Alpha (Parser/Lexer): grammar correctness, token handling, AST shape integrity
- Agent Bravo (Codegen/ABI): assembly emission, calls, control flow, stack safety
- Agent Sigma (Sema/Types): semantic checks, symbol/type consistency, error clarity

### Team Platform Pipeline

- Agent Charlie (CLI/Pipeline): flags, file handling, command safety, exit-code contract
- Agent Echo (Runtime/Link): linking flow, startup behavior, binary execution path

### Team Quality Release

- Agent Delta (QA/CI): regression suites, negative tests, stability loops, workflow hygiene
- Agent Nova (Docs/Release): sprint notes, changelog quality, versioning cadence

## Scrum Cadence

- Sprint length: 1 day
- Daily planning: define top 3-5 P0/P1 tasks from backlog
- Build phase: smallest safe increments per team
- Mid-sprint sync: cross-team integration checkpoint (AST/codegen/CLI contract)
- Validation gate: `./build.sh && ./test.sh` must pass
- Stability gate: run at least 2 full regression loops after parser/codegen changes
- Versioning gate: local commit + local semver tag at sprint close

## Definition Of Done

- No new segfaults on covered paths
- Existing examples compile in expected modes (`-S`, `-c`, full)
- Failure paths return deterministic exit codes
- New bugfix includes a regression test when feasible
- Sprint board updated with completed and next tasks

## Operating Rules

- Work locally first, no force operations
- Keep commits focused by subsystem/team lane
- Prefer explicit parser/sema errors over silent acceptance
- Keep outputs reproducible across repeated test loops
- Continue sprint execution autonomously unless a hard blocker appears
