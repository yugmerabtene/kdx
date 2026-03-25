# KodPix (`kdx`)

KodPix is a compiled language and toolchain written in x86-64 NASM assembly.
It currently targets Linux ELF output and focuses on deterministic compiler behavior
and clear error signaling.

## Why KodPix

- Assembly-first compiler architecture
- C-like syntax with evolving modernized declarations
- End-to-end pipeline: `.kdx -> .s/.o -> ELF binary`
- Structured quality gates for open-source collaboration

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
- secret scan

CI workflow: `.github/workflows/ci.yml`

## Branching and Release Discipline

Recommended workflow:

- `main`
- `feature/*`
- `release/*`
- `hotfix/*`

Detailed strategy: `docs/dev/branching-strategy.md`

## Project Status

KodPix is under active development with stable core validation loops and continuous
improvement of syntax, codegen, and release readiness automation.
