#!/bin/bash
set -euo pipefail

LOG_FILE="/tmp/autodev_quick_tests.log"

echo "[quick-tests] start $(date -u '+%Y-%m-%d %H:%M:%S UTC')" > "$LOG_FILE"

python3 ./.autodev/features/quick_test_agent.py --refresh >> "$LOG_FILE" 2>&1
./quick_tests/run_quick_tests.sh >> "$LOG_FILE" 2>&1
python3 ./.autodev/features/spec_test_agent.py --refresh >> "$LOG_FILE" 2>&1
./quick_tests/run_spec_tests.sh >> "$LOG_FILE" 2>&1

echo "[quick-tests] done $(date -u '+%Y-%m-%d %H:%M:%S UTC')" >> "$LOG_FILE"
