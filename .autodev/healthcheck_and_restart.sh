#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG_FILE="/tmp/autodev_supervisor.log"

log() {
  printf '[%s] %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')" "$1" >> "$LOG_FILE"
}

check_service() {
  local service="$1"
  if ! systemctl --user is-active --quiet "$service"; then
    log "service down: $service -> restarting"
    systemctl --user restart "$service" || true
  fi
}

check_workers() {
  local output found unit _state
  output="$(systemctl --user list-unit-files 'kdx-autodev-worker@*.service' --no-legend --plain)"
  found=0

  if [[ -z "$output" ]]; then
    log "no worker unit files found"
    return
  fi

  while IFS=' ' read -r unit _state; do
    [[ -z "$unit" ]] && continue
    found=1
    check_service "$unit"
  done <<< "$output"

  if [[ "$found" -eq 0 ]]; then
    log "no worker units parsed"
  fi
}

if ! python3 "$REPO_ROOT/.autodev/run.py" --healthcheck; then
  log "orchestrator heartbeat unhealthy -> restarting kdx-autodev.service"
  systemctl --user restart kdx-autodev.service
else
  log "orchestrator heartbeat healthy"
fi

check_workers

# Refresh derived project metrics snapshots for dashboard consumers
python3 "$REPO_ROOT/.autodev/lanes/mvp_estimate.py" >/dev/null 2>&1 || true
python3 "$REPO_ROOT/.autodev/lanes/metrics_observe.py" >/dev/null 2>&1 || true

log "supervisor pass complete"
