#!/bin/bash
set -euo pipefail

echo "Building KodPix compiler..."

mkdir -p build
rm -f build/*.o kdx

nasm -f elf64 src/main.asm -o build/main.o
nasm -f elf64 src/lexer.asm -o build/lexer.o
nasm -f elf64 src/asm/parser.asm -o build/parser.o
nasm -f elf64 src/symbol.asm -o build/symbol.o
nasm -f elf64 src/sema.asm -o build/sema.o
nasm -f elf64 src/optimizer.asm -o build/optimizer.o
nasm -f elf64 src/codegen.asm -o build/codegen.o
nasm -f elf64 src/linker.asm -o build/linker.o

ld -o kdx build/main.o build/lexer.o build/parser.o build/symbol.o build/sema.o build/optimizer.o build/codegen.o build/linker.o -lc --dynamic-linker /lib64/ld-linux-x86-64.so.2

chmod +x kdx
echo "Build successful! Compiler is ready at ./kdx"
