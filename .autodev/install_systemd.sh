#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"

mkdir -p "$SYSTEMD_USER_DIR"

render_unit() {
  local src="$1"
  local dst="$2"
  sed "s|__REPO_ROOT__|$REPO_ROOT|g" "$src" > "$dst"
}

render_unit "$REPO_ROOT/.autodev/systemd/kdx-autodev.service.template" "$SYSTEMD_USER_DIR/kdx-autodev.service"
render_unit "$REPO_ROOT/.autodev/systemd/kdx-autodev-health.service.template" "$SYSTEMD_USER_DIR/kdx-autodev-health.service"
cp "$REPO_ROOT/.autodev/systemd/kdx-autodev-health.timer" "$SYSTEMD_USER_DIR/kdx-autodev-health.timer"

chmod +x "$REPO_ROOT/.autodev/run.py"
chmod +x "$REPO_ROOT/.autodev/healthcheck_and_restart.sh"

systemctl --user daemon-reload
systemctl --user enable --now kdx-autodev.service
systemctl --user enable --now kdx-autodev-health.timer

echo "Installed and started kdx-autodev.service"
echo "Health timer enabled: kdx-autodev-health.timer"
