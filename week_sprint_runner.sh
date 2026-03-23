#!/bin/bash
set -euo pipefail

HOURS="${1:-168}"
LOG_FILE="${2:-week_sprint.log}"

if ! [[ "$HOURS" =~ ^[0-9]+$ ]]; then
  echo "Usage: ./week_sprint_runner.sh [hours] [log-file]"
  exit 1
fi

START_TS=$(date +%s)
END_TS=$((START_TS + HOURS * 3600))
ITER=0

echo "[week-runner] start $(date -u '+%Y-%m-%d %H:%M:%S UTC')" | tee -a "$LOG_FILE"
echo "[week-runner] target hours=$HOURS" | tee -a "$LOG_FILE"

while [[ $(date +%s) -lt $END_TS ]]; do
  ITER=$((ITER + 1))
  LOOP_START=$(date +%s)

  echo "[loop $ITER] build+test start $(date -u '+%Y-%m-%d %H:%M:%S UTC')" | tee -a "$LOG_FILE"

  if ! ./build.sh >>"$LOG_FILE" 2>&1; then
    echo "[loop $ITER] build FAILED" | tee -a "$LOG_FILE"
    exit 1
  fi

  if ! ./test.sh >>"$LOG_FILE" 2>&1; then
    echo "[loop $ITER] tests FAILED" | tee -a "$LOG_FILE"
    exit 1
  fi

  LOOP_END=$(date +%s)
  echo "[loop $ITER] ok in $((LOOP_END - LOOP_START))s" | tee -a "$LOG_FILE"

  sleep 60
done

echo "[week-runner] completed loops=$ITER" | tee -a "$LOG_FILE"
echo "[week-runner] end $(date -u '+%Y-%m-%d %H:%M:%S UTC')" | tee -a "$LOG_FILE"
