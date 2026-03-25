#!/bin/bash
set -euo pipefail

INCLUDE_EXPERIMENTAL=0
if [[ "${1:-}" == "--include-experimental" ]]; then
  INCLUDE_EXPERIMENTAL=1
fi

expect_compile_ok() {
  local src="$1"
  local out="$2"
  ./kdx "$src" -o "$out" >/tmp/quick_test.stderr 2>&1
  test -f "$out"
}

expect_program_exit() {
  local expected="$1"
  local bin="$2"
  set +e
  "$bin" >/tmp/quick_test.stdout 2>/tmp/quick_test.stderr
  local rc=$?
  set -e
  if [[ "$rc" -ne "$expected" ]]; then
    echo "FAIL: expected exit $expected, got $rc for $bin"
    cat /tmp/quick_test.stderr
    exit 1
  fi
}

expect_compile_fail() {
  local expected="$1"
  local src="$2"
  set +e
  ./kdx "$src" -S -o /tmp/quick_fail.s >/tmp/quick_test.stdout 2>/tmp/quick_test.stderr
  local rc=$?
  set -e
  if [[ "$rc" -ne "$expected" ]]; then
    echo "FAIL: expected compile error $expected, got $rc for $src"
    cat /tmp/quick_test.stderr
    exit 1
  fi
}

rm -f /tmp/quick_test.stdout /tmp/quick_test.stderr /tmp/quick_fail.s /tmp/quick_*.bin

if [[ -f ./.autodev/features/quick_test_agent.py ]]; then
  python3 ./.autodev/features/quick_test_agent.py >/dev/null
fi

echo "[quick] building compiler"
./build.sh >/dev/null

echo "[quick] pass cases"
expect_compile_ok "quick_tests/cases/pass/p01_print_literals.kdx" "/tmp/quick_p01.bin"
chmod +x /tmp/quick_p01.bin
expect_program_exit 0 "/tmp/quick_p01.bin"

expect_compile_ok "quick_tests/cases/pass/p02_two_int_vars.kdx" "/tmp/quick_p02.bin"
chmod +x /tmp/quick_p02.bin
expect_program_exit 7 "/tmp/quick_p02.bin"

expect_compile_ok "quick_tests/cases/pass/p03_control_if.kdx" "/tmp/quick_p03.bin"
chmod +x /tmp/quick_p03.bin
expect_program_exit 0 "/tmp/quick_p03.bin"

expect_compile_ok "quick_tests/cases/pass/p04_postfix_increment.kdx" "/tmp/quick_p04.bin"
chmod +x /tmp/quick_p04.bin
expect_program_exit 3 "/tmp/quick_p04.bin"

expect_compile_ok "quick_tests/cases/pass/p05_while_skip.kdx" "/tmp/quick_p05.bin"
chmod +x /tmp/quick_p05.bin
expect_program_exit 0 "/tmp/quick_p05.bin"

echo "[quick] syntax fail cases"
expect_compile_fail 2 "quick_tests/cases/fail/f01_missing_semicolon.kdx"
expect_compile_fail 2 "quick_tests/cases/fail/f02_bad_token.kdx"
expect_compile_fail 2 "quick_tests/cases/fail/f03_unclosed_call_paren.kdx"

if [[ "$INCLUDE_EXPERIMENTAL" -eq 1 ]]; then
  echo "[quick] experimental cases"
  expect_compile_ok "quick_tests/cases/experimental/x01_two_string_vars_print.kdx" "/tmp/quick_x01.bin"
  chmod +x /tmp/quick_x01.bin
  /tmp/quick_x01.bin >/tmp/quick_test.stdout 2>/tmp/quick_test.stderr || true
  expect_compile_ok "quick_tests/cases/experimental/x02_while_with_variable.kdx" "/tmp/quick_x02.bin"
  chmod +x /tmp/quick_x02.bin
  /tmp/quick_x02.bin >/tmp/quick_test.stdout 2>/tmp/quick_test.stderr || true
fi

echo "[quick] all checks passed"
