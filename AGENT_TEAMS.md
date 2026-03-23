# KodPix Agent Teams Charter

This file defines autonomous specialist teams and their execution boundaries.

## Team A: Core Compiler

- Scope: `src/asm/parser.asm`, `src/lexer.asm`, `src/sema.asm`, `src/codegen.asm`
- Mission: language correctness, AST integrity, semantic validity, codegen correctness
- Primary KPIs:
  - zero parser/codegen segfaults on covered fixtures
  - deterministic parse/sema/codegen exit behavior
  - reduced mismatch between parser AST and codegen expectations

## Team B: Platform Pipeline

- Scope: `src/main.asm`, `src/linker.asm`, build/link execution path
- Mission: safe compile pipeline and deterministic CLI behavior
- Primary KPIs:
  - stable `-S/-c/-o/-x` matrix behavior
  - bounded and validated file handling paths
  - no accidental shell/command-path regressions

## Team C: Quality and Release

- Scope: `test.sh`, `soak_test.sh`, `.github/workflows/ci.yml`, docs
- Mission: prevent regressions and maintain release cadence
- Primary KPIs:
  - growing negative and stress coverage
  - repeatable multi-loop pass rate
  - sprint-close versioning discipline

## Team D: Reliability and Governance

- Scope: `.autodev/lanes/*`, `.autodev/run.py`, health timers, runtime metrics
- Mission: keep autonomous execution safe, observable, and recoverable
- Primary KPIs:
  - service heartbeat freshness and watchdog recovery success
  - stable build/test timing trends over long runs
  - no unattended degradation in autonomous loop reliability

## Weekly Operating Contract

- Daily sprint cycles per team (plan -> build -> validate -> close)
- Cross-team sync after major AST or ABI changes
- Required gates before sprint close:
  - `./build.sh`
  - `./test.sh`
  - at least 2 repeated stability loops for significant compiler changes

## Branch and Commit Discipline

- Local-first workflow
- Focused commits by team lane
- Local semver tag at sprint close
- No force operations
