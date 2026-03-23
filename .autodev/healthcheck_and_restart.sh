#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if ! python3 "$REPO_ROOT/.autodev/run.py" --healthcheck; then
  systemctl --user restart kdx-autodev.service
fi
