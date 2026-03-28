#!/bin/bash
set -euo pipefail

LOG_FILE="/tmp/autodev_perf_memory.log"

echo "[perf] start $(date -u '+%Y-%m-%d %H:%M:%S UTC')" > "$LOG_FILE"

time ./build.sh >> "$LOG_FILE" 2>&1

time ./kdx examples/simple.kdx -S -o /tmp/autodev_perf_simple.s >> "$LOG_FILE" 2>&1
time ./kdx examples/hello.kdx -S -o /tmp/autodev_perf_hello.s >> "$LOG_FILE" 2>&1

./test.sh >> "$LOG_FILE" 2>&1

echo "[perf] done $(date -u '+%Y-%m-%d %H:%M:%S UTC')" >> "$LOG_FILE"
