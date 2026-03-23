# KodPix (`kdx`)

KodPix is a compiled programming language with C/Java-like syntax.  
The current compiler is written in x86-64 NASM assembly and targets Linux ELF binaries.

## Current Status

- Compiler frontend and pipeline are functional (`.kdx -> .s/.o -> ELF binary`)
- Core commands are available: `-S`, `-c`, `-o`, `-x`, `-h`
- Project is under active development (language features are being expanded)

## Installation

### Option 1: Prebuilt binary (recommended)

1. Go to the releases page: `https://github.com/yugmerabtene/kdx/releases`
2. Download the latest `kdx` Linux x86-64 binary
3. Make it executable and install it:

```bash
chmod +x kdx
sudo mv kdx /usr/local/bin/kdx
```

4. Verify:

```bash
kdx --help
```

### Option 2: Build from source

Requirements:

- Linux x86-64
- NASM 2.15+
- GNU `ld` (binutils)

Build:

```bash
git clone https://github.com/yugmerabtene/kdx.git
cd kdx
./build.sh
```

## Usage

```bash
kdx [options] <input.kdx>
```

Options:

- `-S` output assembly only
- `-c` compile to object only (no link)
- `-o <file>` output file path
- `-x` execute after successful build
- `-O0/-O1/-O2` optimization level flag (reserved/in progress)
- `-h`, `--help` show help

Examples:

```bash
# Build executable
./kdx examples/simple.kdx -o hello
./hello

# Generate assembly
./kdx examples/simple.kdx -S -o hello.s

# Generate object file
./kdx examples/simple.kdx -c -o hello.o
```

## Development

Build and test locally:

```bash
./build.sh
./test.sh
```

`test.sh` now includes:

- positive smoke checks for `-S`, `-c`, and full compile/run
- control-flow assembly generation check (`examples/control_flow.kdx`)
- negative CLI checks (invalid flag, missing input, missing file)
- oversized input rejection checks for lexer buffer safety

CI runs on pushes and pull requests via GitHub Actions.

Autonomous sprint tracking:

- `SCRUM_AGENTS.md` defines specialized agent roles and cadence
- `AGENT_TEAMS.md` defines multi-team charters and weekly operating contract
- `SPRINT_BOARD.md` tracks current in-progress and next-queue work

Long-run stability workflow is documented in `TESTING.md`.
Continuous week-long loop automation is available via `week_sprint_runner.sh`.

## Roadmap

1. Lexer / parser / basic codegen
2. Type system and semantic checks
3. Optimizations
4. Standard library modules
5. Tooling and release polish

## License

License file will be added in a future release.
