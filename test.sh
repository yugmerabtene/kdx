#!/bin/bash
set -euo pipefail

echo "Testing KodPix compiler..."

./build.sh

rm -f ci_out.s ci_out.o ci_out_bin ci_hello.s ci_hello_bin test_output.s test_output.o

echo "[1/5] Help output"
./kdx --help >/dev/null

echo "[2/5] Assembly-only mode"
./kdx examples/simple.kdx -S -o ci_out.s
test -f ci_out.s

echo "[3/5] Compile-only mode"
./kdx examples/simple.kdx -c -o ci_out.o
test -f ci_out.o

echo "[4/5] Full compile and run"
./kdx examples/simple.kdx -o ci_out_bin
test -f ci_out_bin
chmod +x ci_out_bin
./ci_out_bin

echo "[5/5] Hello sample (typed return + call syntax)"
./kdx examples/hello.kdx -S -o ci_hello.s
test -f ci_hello.s
./kdx examples/hello.kdx -o ci_hello_bin
test -f ci_hello_bin
chmod +x ci_hello_bin
./ci_hello_bin

echo "All tests passed"
