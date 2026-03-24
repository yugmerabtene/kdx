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
  local profiles profile unit output line unit_name
  profiles=(parser codegen qa reliability)

  for profile in "${profiles[@]}"; do
    unit="kdx-autodev-worker@${profile}.service"
    check_service "$unit"
  done

  output="$(systemctl --user list-units 'kdx-autodev-worker@*.service' --all --no-legend --plain || true)"
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    unit_name="${line%% *}"
    [[ -z "$unit_name" ]] && continue
    [[ "$unit_name" == *"@.service" ]] && continue
    check_service "$unit_name"
  done <<< "$output"
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
