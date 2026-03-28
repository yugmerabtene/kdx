#!/bin/bash
set -euo pipefail

LOG_FILE="/tmp/autodev_incident_recovery.log"

echo "[incident] start $(date -u '+%Y-%m-%d %H:%M:%S UTC')" > "$LOG_FILE"

python3 .autodev/run.py --healthcheck >> "$LOG_FILE" 2>&1 || true

if ! python3 .autodev/run.py --healthcheck >/dev/null 2>&1; then
  systemctl --user restart kdx-autodev.service
  echo "[incident] service restarted" >> "$LOG_FILE"
fi

./build.sh >> "$LOG_FILE" 2>&1
./test.sh >> "$LOG_FILE" 2>&1

echo "[incident] done $(date -u '+%Y-%m-%d %H:%M:%S UTC')" >> "$LOG_FILE"
