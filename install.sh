#!/bin/bash
set -e

echo "=== KodPix Compiler Installation ==="

# Check for NASM
echo "Checking for NASM..."
if ! command -v nasm &> /dev/null; then
    echo "[INFO] NASM not found. Installing..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y nasm
    elif command -v brew &> /dev/null; then
        brew install nasm
    else
        echo "[ERROR] Cannot install NASM. Please install NASM manually."
        exit 1
    fi
fi

NASM_VERSION=$(nasm -v | head -n1 | grep -oP '\d+\.\d+' | head -1)
echo "[OK] NASM version: $NASM_VERSION"

MAJOR=$(echo $NASM_VERSION | cut -d. -f1)
MINOR=$(echo $NASM_VERSION | cut -d. -f2)
if [ "$MAJOR" -lt 2 ] || ([ "$MAJOR" -eq 2 ] && [ "$MINOR" -lt 15 ]); then
    echo "[ERROR] NASM version >= 2.15 required. Found: $NASM_VERSION"
    exit 1
fi

# Check for GCC or clang
echo "Checking for C compiler..."
if ! command -v gcc &> /dev/null && ! command -v clang &> /dev/null; then
    echo "[ERROR] GCC or clang required but not found."
    exit 1
fi
CC=$(command -v gcc || command -v clang)
echo "[OK] Using compiler: $CC"

# Check for Linux x86_64
echo "Checking platform..."
if [[ "$(uname -s)" != "Linux" ]] || [[ "$(uname -m)" != "x86_64" ]]; then
    echo "[ERROR] KodPix requires Linux x86_64."
    exit 1
fi
echo "[OK] Platform: Linux x86_64"

# Create directories
echo "Creating directories..."
mkdir -p "$HOME/.local/bin"
mkdir -p build

# Build the compiler
echo "Building compiler..."
nasm -f elf64 src/asm/*.asm -o build/*.o
$CC -no-pie -nostdlib -o kdx build/*.o -lc

# Install
echo "[OK] Installing kdx to ~/.local/bin/"
cp kdx "$HOME/.local/bin/"
chmod +x "$HOME/.local/bin/kdx"

# Update PATH in bashrc
BASHRC_LINE='export PATH="$HOME/.local/bin:$PATH"'
if ! grep -q "$BASHRC_LINE" "$HOME/.bashrc" 2>/dev/null; then
    echo "" >> "$HOME/.bashrc"
    echo "# KodPix Compiler" >> "$HOME/.bashrc"
    echo "$BASHRC_LINE" >> "$HOME/.bashrc"
    echo "[OK] Added ~/.local/bin to PATH in ~/.bashrc"
else
    echo "[OK] PATH already configured in ~/.bashrc"
fi

echo ""
echo "=== Installation Complete ==="
echo ""
echo "To use kdx immediately, run:"
echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
echo ""
echo "To use kdx in new terminals, restart bash or run:"
echo "    source ~/.bashrc"
