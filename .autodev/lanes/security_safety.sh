#!/bin/bash
set -euo pipefail

LOG_FILE="/tmp/autodev_security_safety.log"

echo "[security] start $(date -u '+%Y-%m-%d %H:%M:%S UTC')" > "$LOG_FILE"

./build.sh >> "$LOG_FILE" 2>&1

./kdx --bad-flag >> "$LOG_FILE" 2>&1 || true
./kdx -S -x examples/simple.kdx >> "$LOG_FILE" 2>&1 || true
./kdx -o -S examples/simple.kdx >> "$LOG_FILE" 2>&1 || true
./kdx examples/does_not_exist.kdx >> "$LOG_FILE" 2>&1 || true

./test.sh >> "$LOG_FILE" 2>&1

echo "[security] done $(date -u '+%Y-%m-%d %H:%M:%S UTC')" >> "$LOG_FILE"
