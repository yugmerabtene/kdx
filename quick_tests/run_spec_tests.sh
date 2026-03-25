#!/bin/bash
set -euo pipefail

TARGET_MODE=0
if [[ "${1:-}" == "--target" ]]; then
  TARGET_MODE=1
fi

expect_compile_ok() {
  local src="$1"
  local out="$2"
  ./kdx "$src" -o "$out" >/tmp/spec_test.stdout 2>/tmp/spec_test.stderr
  test -f "$out"
}

expect_compile_fail() {
  local src="$1"
  set +e
  ./kdx "$src" -o /tmp/spec_fail.bin >/tmp/spec_test.stdout 2>/tmp/spec_test.stderr
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL: expected compile failure for $src"
    exit 1
  fi
}

expect_program_exit() {
  local expected="$1"
  local bin="$2"
  set +e
  "$bin" >/tmp/spec_test.stdout 2>/tmp/spec_test.stderr
  local rc=$?
  set -e
  if [[ "$rc" -ne "$expected" ]]; then
    echo "FAIL: expected exit $expected, got $rc for $bin"
    cat /tmp/spec_test.stderr
    exit 1
  fi
}

rm -f /tmp/spec_test.stdout /tmp/spec_test.stderr /tmp/spec_fail.s /tmp/spec_*.bin

if [[ -f ./.autodev/features/spec_test_agent.py ]]; then
  python3 ./.autodev/features/spec_test_agent.py --refresh >/dev/null
fi

echo "[spec] building compiler"
./build.sh >/dev/null

echo "[spec] baseline pass cases"
expect_compile_ok "quick_tests/spec/pass/p01_function_arrow_baseline.kdx" "/tmp/spec_p01.bin"
chmod +x /tmp/spec_p01.bin
expect_program_exit 5 "/tmp/spec_p01.bin"

expect_compile_ok "quick_tests/spec/pass/p02_increment_runtime.kdx" "/tmp/spec_p02.bin"
chmod +x /tmp/spec_p02.bin
expect_program_exit 3 "/tmp/spec_p02.bin"

expect_compile_ok "quick_tests/spec/pass/p03_print_and_return.kdx" "/tmp/spec_p03.bin"
chmod +x /tmp/spec_p03.bin
expect_program_exit 0 "/tmp/spec_p03.bin"

expect_compile_ok "quick_tests/spec/pass/p04_new_header_main.kdx" "/tmp/spec_p04.bin"
chmod +x /tmp/spec_p04.bin
expect_program_exit 8 "/tmp/spec_p04.bin"

expect_compile_ok "quick_tests/spec/pass/p05_typed_params_header.kdx" "/tmp/spec_p05.bin"
chmod +x /tmp/spec_p05.bin
expect_program_exit 0 "/tmp/spec_p05.bin"

expect_compile_ok "quick_tests/spec/pass/p06_strict_equality.kdx" "/tmp/spec_p06.bin"
chmod +x /tmp/spec_p06.bin
expect_program_exit 0 "/tmp/spec_p06.bin"

expect_compile_ok "quick_tests/spec/pass/p07_new_signature_call.kdx" "/tmp/spec_p07.bin"
chmod +x /tmp/spec_p07.bin
expect_program_exit 9 "/tmp/spec_p07.bin"

expect_compile_ok "quick_tests/spec/pass/p08_class_main_void.kdx" "/tmp/spec_p08.bin"
chmod +x /tmp/spec_p08.bin
expect_program_exit 0 "/tmp/spec_p08.bin"

echo "[spec] baseline syntax fail cases"
expect_compile_fail "quick_tests/spec/fail/f01_malformed_header.kdx"
expect_compile_fail "quick_tests/spec/fail/f02_bad_token.kdx"

if [[ "$TARGET_MODE" -eq 1 ]]; then
  echo "[spec] target mode (future cases must compile)"
  expect_compile_ok "quick_tests/spec/future/t04_array_decl.kdx" "/tmp/spec_t04.bin"
  expect_compile_ok "quick_tests/spec/future/t05_switch_minimal.kdx" "/tmp/spec_t05.bin"
else
  echo "[spec] tracking mode (future cases expected to fail for now)"
  expect_compile_fail "quick_tests/spec/future/t04_array_decl.kdx"
  expect_compile_fail "quick_tests/spec/future/t05_switch_minimal.kdx"
fi

echo "[spec] all checks passed"
