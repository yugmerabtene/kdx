# KodPix AGENTS.md

## Project Overview

KodPix is a compiled programming language with C/Java-like syntax, targeting x86-64 Linux ELF.
The compiler is written in x86-64 NASM assembly. Source files use `.kdx` extension.

**Repository structure:**
```
kodpix/                    # Main compiler project
├── src/asm/              # Assembly compiler sources
├── examples/             # Example .kdx programs
└── vscode/              # VSCode extension

kodpix-asm/               # Standalone lexer implementation
├── src/lexer.asm         # Working lexer example
└── examples/
```

---

## Build Commands

### KodPix Compiler (NASM Assembly)

```bash
# Build the compiler
nasm -f elf64 src/asm/*.asm -o build/*.o
ld -o kdx build/*.o
chmod +x kdx

# Build with debug symbols
nasm -g -f elf64 src/asm/*.asm -o build/*.o
```

### KodPix-ASM (Lexer Reference Implementation)

```bash
# Build the lexer
nasm -f elf64 src/lexer.asm -o lexer.o
ld -o lexer lexer.o
chmod +x lexer
```

### Compile KodPix Source Files

```bash
# Compile a .kdx program
./kdx examples/hello.kdx -o hello
./hello

# Compile to assembly output
./kdx examples/hello.kdx -S -o hello.s

# Compile without linking
./kdx examples/hello.kdx -c -o hello.o
```

### Required Tools

- **Assembler:** NASM 2.15+
- **Linker:** LD (GNU Binutils)
- **Platform:** Linux x86-64

---

## Code Style Guidelines

### Section Organization

Structure assembly files with these sections in order:

```asm
section .data
    ; Read-only and initialized data
    TOKEN_EOF         equ 0
    TOKEN_NUMBER      equ 1
    message db 'Hello', 0

section .bss
    ; Uninitialized data
    input_buffer: resb 65536
    counter:      resq 1

section .text
    global function_name
    extern external_func
```

### Label Naming

- **Labels (functions/local):** `camelCase` or `snake_case`
- **Constants/Macros:** `SCREAMING_SNAKE_CASE`
- **Local labels within functions:** `.label_name` (prefixed with dot)

```asm
lexer_init:              ; Function label
    push rbp
    mov rbp, rsp
    ; ...
    pop rbp
    ret

.token_loop:             ; Local label
    call skip_whitespace
    jmp .token_loop
```

### Register Conventions (System V AMD64 ABI)

| Register      | Purpose                              |
|---------------|--------------------------------------|
| `rax`         | Return value, scratch                |
| `rdi`         | 1st argument                         |
| `rsi`         | 2nd argument                         |
| `rdx`         | 3rd argument, scratch               |
| `rcx`         | 4th argument, scratch                |
| `r8`          | 5th argument                         |
| `r9`          | 6th argument                         |
| `r10-r11`     | Scratch registers                    |
| `r12-r15`     | Callee-saved                         |
| `rbx, rbp`    | Callee-saved                         |
| `rsp`         | Stack pointer                        |

### Function Prologue/Epilogue

Always use frame pointer:

```asm
function_name:
    push rbp
    mov rbp, rsp
    ; Function body
    pop rbp
    ret
```

### Comments

- Use semicolons for comments, aligned at column 41 or with preceding code
- Header comment block at file start with module name and purpose
- Section comments in uppercase

```asm
; KodPix Compiler - Lexer Module
; x86-64 NASM Assembly
; Tokenizes .kdx source files

section .text

; Skip whitespace characters
skip_whitespace:
    push rbp
    mov rbp, rsp
```

### Data Alignment

- Align `.data` constants appropriately
- Use `equ` for constants, not immediate values
- Prefer `db/dw/dd/dq` for data definitions

```asm
TOKEN_EOF    equ 0
TOKEN_NUMBER equ 1
message      db 'Hello, World!', 10, 0
buffer       resb 256
```

### Error Handling

Use these exit codes per the CLI spec:

| Code | Meaning                    |
|------|----------------------------|
| 0    | Success                    |
| 1    | Compilation error          |
| 2    | Syntax error               |
| 3    | Semantic error             |
| 4    | Linker error              |
| 5    | I/O error                  |

```asm
error_syntax:
    mov rdi, 2          ; Exit code 2
    mov rax, 60         ; sys_exit
    syscall
```

---

## Language Syntax Reference

### KodPix Keywords

```
fn if else while for let const return break continue
import export struct enum match true false null self pub mod use as loop in
```

### Data Types

| Type   | Description              |
|--------|--------------------------|
| i8/i16/i32/i64 | Signed integers |
| u8/u16/u32/u64 | Unsigned integers |
| f32/f64 | Floating point    |
| bool   | Boolean                 |
| char   | Character (4 bytes)     |
| str    | String slice (16 bytes)  |
| void   | Unit type               |

### Example KodPix Code

```kodpix
fn factorial(n: i64) -> i64 {
    if n <= 1 {
        return 1;
    }
    return n * factorial(n - 1);
}

fn main() -> i32 {
    let result = factorial(10);
    return 0;
}
```

---

## Testing

Currently no automated test suite. Manual testing process:

1. Write a `.kdx` program in `examples/`
2. Compile with `./kdx examples/test.kdx -o test`
3. Run: `./test`
4. Verify expected output

```bash
# Example test workflow
./kdx examples/hello.kdx -o hello && ./hello
```

---

## File Naming

| Extension | Purpose                           |
|-----------|-----------------------------------|
| `.kdx`    | KodPix source files               |
| `.asm`    | Assembly source                   |
| `.s`      | Assembly source (alternative)     |
| `.o`      | Object files                      |

---

## Development Priorities

Per the roadmap, focus development in this order:

1. **Phase 1:** Lexer, Parser, Basic codegen, Variables/Functions/Control
2. **Phase 2:** Type system, Structures, Symbol table, Enums
3. **Phase 3:** Optimizations (constant folding, type propagation)
4. **Phase 4:** Standard library modules (core::io, core::fmt, core::math)
5. **Phase 5:** Documentation, VSCode extension, Release

---

## Reference Implementation

The `kodpix-asm/src/lexer.asm` file serves as a reference for coding style and conventions.
Study it for patterns on:
- Token type definitions
- State machine implementation
- String/identifier parsing
- Keyword lookup

---

## Current Status

### Build Status
- Compiler builds successfully: ✅
- Binary created: ✅ (kdx - 88KB)
- Runtime: ❌ (segfaults on startup)

### Issues to Fix

1. **Runtime crash** - The compiler crashes with SIGSEGV even on `--help`
   - Likely cause: Issues in initialization, memory management, or libc interop
   - Need to debug with GDB or add runtime checks

2. **codegen.asm** - Multiple broken function call patterns were fixed
   - `call emit_sub rsp, imm` → properly set up register args
   - `call emit_mov_stack rax, imm` → fixed
   - `call emit_je_label r14` → `mov rsi, r14; call emit_je_label`
   - `call emit_char '0'` → `mov dil, '0'; call emit_char`
   - Missing `emit_instruction` alias added
   - Missing `NODE_HEADER_SIZE` constant added

3. **main.asm** - Multiple issues fixed
   - Replaced broken fork+execve pattern with system() calls
   - Fixed undefined symbols (fork, argv references)
   - Fixed invalid operand combinations
   - Fixed function name mismatches (parser_parse → parse_program, etc.)

4. **ast.asm** - Fixed line 92 size specifier
   - `mov [ast_pool_ptr], rax` → `mov qword [ast_pool_ptr], rax`
