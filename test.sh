#!/bin/bash
set -euo pipefail

expect_failure() {
  local expected_code="$1"
  shift

  set +e
  "$@" >/tmp/kdx_test.stderr 2>&1
  local actual_code=$?
  set -e

  if [[ $actual_code -ne $expected_code ]]; then
    echo "Expected exit code $expected_code, got $actual_code for: $*"
    cat /tmp/kdx_test.stderr
    exit 1
  fi
}

echo "Testing KodPix compiler..."

./build.sh

rm -f ci_out.s ci_out.o ci_out_bin ci_hello.s ci_hello_bin test_output.s test_output.o /tmp/kdx_test.stderr

echo "[1/8] Help output"
./kdx --help >/dev/null

echo "[2/8] Assembly-only mode"
./kdx examples/simple.kdx -S -o ci_out.s
test -f ci_out.s

echo "[3/8] Compile-only mode"
./kdx examples/simple.kdx -c -o ci_out.o
test -f ci_out.o

echo "[4/8] Full compile and run"
./kdx examples/simple.kdx -o ci_out_bin
test -f ci_out_bin
chmod +x ci_out_bin
./ci_out_bin

echo "[5/8] Hello sample (typed return + call syntax)"
./kdx examples/hello.kdx -S -o ci_hello.s
test -f ci_hello.s
./kdx examples/hello.kdx -o ci_hello_bin
test -f ci_hello_bin
chmod +x ci_hello_bin
./ci_hello_bin

echo "[6/8] Invalid flag returns error"
expect_failure 1 ./kdx --bad-flag

echo "[7/8] Missing input returns error"
expect_failure 1 ./kdx

echo "[8/8] Missing file returns I/O error"
expect_failure 5 ./kdx examples/does_not_exist.kdx

echo "All tests passed"
