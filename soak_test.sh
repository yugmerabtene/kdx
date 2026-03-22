#!/bin/bash
set -euo pipefail

HOURS="${1:-24}"
LOG_FILE="${2:-soak_test.log}"

if ! [[ "$HOURS" =~ ^[0-9]+$ ]]; then
  echo "Usage: ./soak_test.sh [hours] [log-file]"
  exit 1
fi

SECONDS_TOTAL=$((HOURS * 3600))
START_TS=$(date +%s)
END_TS=$((START_TS + SECONDS_TOTAL))
ITERATION=0
MAX_LOOPS="${SOAK_MAX_LOOPS:-0}"

echo "Starting soak test for ${HOURS}h" | tee -a "$LOG_FILE"
echo "Start: $(date -u '+%Y-%m-%d %H:%M:%S UTC')" | tee -a "$LOG_FILE"

while [[ $(date +%s) -lt $END_TS ]]; do
  if [[ "$MAX_LOOPS" -gt 0 && "$ITERATION" -ge "$MAX_LOOPS" ]]; then
    break
  fi

  ITERATION=$((ITERATION + 1))
  ITER_START=$(date +%s)

  echo "[loop ${ITERATION}] running ./test.sh" | tee -a "$LOG_FILE"
  if ! ./test.sh >>"$LOG_FILE" 2>&1; then
    echo "[loop ${ITERATION}] FAILED at $(date -u '+%Y-%m-%d %H:%M:%S UTC')" | tee -a "$LOG_FILE"
    exit 1
  fi

  ITER_END=$(date +%s)
  echo "[loop ${ITERATION}] ok in $((ITER_END - ITER_START))s" | tee -a "$LOG_FILE"
done

echo "Completed ${ITERATION} loops" | tee -a "$LOG_FILE"
echo "End: $(date -u '+%Y-%m-%d %H:%M:%S UTC')" | tee -a "$LOG_FILE"
