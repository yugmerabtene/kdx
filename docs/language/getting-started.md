# Getting Started

This guide gets you from source code to a running KodPix program.

## Requirements

- Linux x86-64
- NASM 2.15+
- GNU `ld`

## Build the Compiler

```bash
./build.sh
```

The compiler binary is created as `./kdx`.

## Compile and Run a Program

```bash
./kdx examples/hello.kdx -o hello
./hello
```

## Output Modes

- Assembly only:

```bash
./kdx examples/hello.kdx -S -o hello.s
```

- Object only:

```bash
./kdx examples/hello.kdx -c -o hello.o
```

## First Program

```kodpix
function int main() {
    println("Hello, KodPix");
    return 0;
}
```

## Next Steps

- Language rules: `docs/language/reference.md`
- Error meanings: `docs/language/error-codes.md`
- Practical examples: `docs/language/cookbook.md`
