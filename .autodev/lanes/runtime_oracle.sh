#!/bin/bash
set -euo pipefail

LOG_FILE="/tmp/autodev_runtime_oracle.log"
DRIFT_FILE="/tmp/autodev_runtime_oracle_drift.txt"

echo "[oracle] start $(date -u '+%Y-%m-%d %H:%M:%S UTC')" > "$LOG_FILE"
rm -f "$DRIFT_FILE"

./build.sh >> "$LOG_FILE" 2>&1

assert_exit() {
  local src="$1"
  local expected="$2"
  local name
  name="$(basename "$src" .kdx)"
  local out="/tmp/autodev_oracle_${name}_bin"

  ./kdx "$src" -o "$out" >> "$LOG_FILE" 2>&1
  chmod +x "$out"

  set +e
  "$out" >> "$LOG_FILE" 2>&1
  local rc=$?
  set -e

  if [[ "$rc" -ne "$expected" ]]; then
    echo "oracle mismatch: $src expected=$expected got=$rc" | tee -a "$LOG_FILE"
    return 1
  fi
  echo "oracle ok: $src -> $rc" >> "$LOG_FILE"
}

# Hard gate: stable runtime behavior
assert_exit "examples/hello.kdx" 0
assert_exit "examples/control_flow.kdx" 0
assert_exit "examples/while_return.kdx" 0
assert_exit "examples/if_chain.kdx" 0
assert_exit "examples/syntax_v2_increment.kdx" 3

echo "[oracle] done $(date -u '+%Y-%m-%d %H:%M:%S UTC')" >> "$LOG_FILE"
