# KodPix Autonomous Scrum

This repository is operated with a multi-agent scrum model for continuous local development.

## Team Roles

- Agent Alpha (Parser/Lexer): grammar correctness, token handling, AST shape integrity
- Agent Bravo (Codegen/ABI): assembly emission, call lowering, control flow, stack safety
- Agent Charlie (CLI/Pipeline): flags, file handling, command execution safety, exit codes
- Agent Delta (QA/CI): regression tests, failure-path tests, looped stability checks, workflow hygiene

## Sprint Cadence

- Sprint length: 1 day
- Planning: define top 3-5 P0/P1 tasks from backlog
- Build phase: implement smallest safe increments
- Validation gate: `./build.sh && ./test.sh` must pass
- Stability gate: run test loop at least 2 times after non-trivial parser/codegen changes
- Versioning: local commit + local semver tag after each completed sprint

## Definition Of Done

- No new segfaults on covered paths
- Existing examples compile in expected modes (`-S`, `-c`, full)
- New bugfix has a regression test whenever possible
- CLI exit-code behavior remains deterministic

## Backlog Priorities

1. Parser strictness for malformed grammar and delimiter recovery
2. Codegen correctness for expression statements and call ABI
3. Memory and buffer safety for label/string/input paths
4. CI quality gates and stress loops
5. Language feature growth (control flow/type coverage)

## Operating Rules

- Work locally first, no forced git operations
- Keep commits focused by subsystem
- Prefer failing fast with explicit parser/sema errors over silent acceptance
- Preserve reproducibility: test results must be repeatable across loops
