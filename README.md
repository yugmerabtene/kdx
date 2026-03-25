# KodPix (`kdx`)

KodPix is a compiled language and toolchain written in x86-64 NASM assembly.
It currently targets Linux ELF output and focuses on deterministic compiler behavior,
clear error signaling, and strong autonomous quality gates.

## Why KodPix

- Assembly-first compiler architecture
- C-like syntax with evolving modernized declarations
- End-to-end pipeline: `.kdx -> .s/.o -> ELF binary`
- Continuous autonomous validation through orchestrated workers

## Quick Start

### Requirements

- Linux x86-64
- NASM 2.15+
- GNU `ld` (binutils)

### Build

```bash
./build.sh
```

### Compile and Run

```bash
./kdx examples/hello.kdx -o hello
./hello
```

### Common Modes

```bash
# Assembly only
./kdx examples/hello.kdx -S -o hello.s

# Object only
./kdx examples/hello.kdx -c -o hello.o
```

## CLI Reference

```bash
kdx [options] <input.kdx>
```

- `-S` emit assembly only
- `-c` emit object only
- `-o <file>` set output path
- `-x` execute after successful build
- `-h`, `--help` show help

## Language Documentation

- `docs/language/getting-started.md`
- `docs/language/reference.md`
- `docs/language/error-codes.md`
- `docs/language/cookbook.md`
- `docs/language/roadmap-compatibility.md`

## CI and Quality Gates

The repository uses structured CI with required quality gates:

- build
- full test suite
- quick suite
- spec suite
- runtime oracle
- flaky detection
- security checks
- secret leak scan (tracked files)
- regression guard

CI workflow: `.github/workflows/ci.yml`

## Confidentiality Safeguards

- `scripts/secret_scan.py` scans tracked files for common secret patterns
- `scripts/install_git_hooks.sh` installs `pre-commit` and `pre-push` secret scan hooks
- `.gitignore` blocks local secret material (`token.txt`, `*.token`, `*.secret`, `*.pem`, `*.key`, `secrets/`)

## Branching and Release Discipline

Recommended workflow:

- `main`
- `feature/*`
- `release/*`
- `hotfix/*`

Detailed strategy: `docs/dev/branching-strategy.md`

## Autonomous Engineering System

Persistent orchestrator and workers are defined in `.autodev/`.

- install services: `./.autodev/install_systemd.sh`
- live metrics dashboard: `python3 ./metrics.py`
- worker roles and charter: `SCRUM_AGENTS.md`, `AGENT_TEAMS.md`

## Project Status

KodPix is under active development with stable core validation loops and continuous
improvement of syntax, codegen, and release readiness automation.
