#!/bin/bash
set -euo pipefail

echo "Testing KodPix compiler..."

./build.sh

rm -f ci_out.s ci_out.o ci_out_bin test_output.s test_output.o

echo "[1/4] Help output"
./kdx --help >/dev/null

echo "[2/4] Assembly-only mode"
./kdx examples/simple.kdx -S -o ci_out.s
test -f ci_out.s

echo "[3/4] Compile-only mode"
./kdx examples/simple.kdx -c -o ci_out.o
test -f ci_out.o

echo "[4/4] Full compile and run"
./kdx examples/simple.kdx -o ci_out_bin
test -f ci_out_bin
chmod +x ci_out_bin
./ci_out_bin

echo "All tests passed"
