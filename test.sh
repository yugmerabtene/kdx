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

cleanup_artifacts() {
  rm -f ci_out.s ci_out.o ci_out_bin ci_hello.s ci_hello_bin ci_flow.s ci_big.kdx ci_bad_syntax.kdx /tmp/kdx_test.stderr
}

trap cleanup_artifacts EXIT

echo "Testing KodPix compiler..."

./build.sh

cleanup_artifacts

echo "[1/14] Help output"
./kdx --help >/dev/null

echo "[2/14] Assembly-only mode"
./kdx examples/simple.kdx -S -o ci_out.s
test -f ci_out.s

echo "[3/14] Compile-only mode"
./kdx examples/simple.kdx -c -o ci_out.o
test -f ci_out.o

echo "[4/14] Full compile and run"
./kdx examples/simple.kdx -o ci_out_bin
test -f ci_out_bin
chmod +x ci_out_bin
./ci_out_bin

echo "[5/14] Hello sample (typed return + call syntax)"
./kdx examples/hello.kdx -S -o ci_hello.s
test -f ci_hello.s
./kdx examples/hello.kdx -o ci_hello_bin
test -f ci_hello_bin
chmod +x ci_hello_bin
./ci_hello_bin

echo "[6/14] Control-flow sample emits assembly"
./kdx examples/control_flow.kdx -S -o ci_flow.s
test -f ci_flow.s

echo "[7/14] Invalid flag returns error"
expect_failure 1 ./kdx --bad-flag

echo "[8/14] Missing input returns error"
expect_failure 1 ./kdx

echo "[9/14] Missing file returns I/O error"
expect_failure 5 ./kdx examples/does_not_exist.kdx

echo "[10/14] Oversized input is rejected"
dd if=/dev/zero of=ci_big.kdx bs=1 count=17000 status=none
expect_failure 5 ./kdx ci_big.kdx

echo "[11/14] Incompatible flags are rejected"
expect_failure 1 ./kdx -S -x examples/simple.kdx

echo "[12/14] Missing -o value is rejected"
expect_failure 1 ./kdx -o -S examples/simple.kdx

echo "[13/14] Multiple input files are rejected"
expect_failure 1 ./kdx examples/simple.kdx examples/hello.kdx

echo "[14/14] Malformed syntax returns parser error"
cat > ci_bad_syntax.kdx <<'EOF'
fn main( {
    return 0;
}
EOF
expect_failure 2 ./kdx ci_bad_syntax.kdx

echo "All tests passed"
