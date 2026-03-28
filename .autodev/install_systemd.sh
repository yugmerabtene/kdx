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
render_unit "$REPO_ROOT/.autodev/systemd/kdx-autodev-worker@.service.template" "$SYSTEMD_USER_DIR/kdx-autodev-worker@.service"
cp "$REPO_ROOT/.autodev/systemd/kdx-autodev-health.timer" "$SYSTEMD_USER_DIR/kdx-autodev-health.timer"

chmod +x "$REPO_ROOT/.autodev/run.py"
chmod +x "$REPO_ROOT/.autodev/healthcheck_and_restart.sh"
chmod +x "$REPO_ROOT/.autodev/worker_runner.sh"

systemctl --user daemon-reload
systemctl --user enable --now kdx-autodev.service
systemctl --user enable --now kdx-autodev-health.timer
systemctl --user enable --now kdx-autodev-worker@parser.service
systemctl --user enable --now kdx-autodev-worker@codegen.service
systemctl --user enable --now kdx-autodev-worker@qa.service
systemctl --user enable --now kdx-autodev-worker@reliability.service
systemctl --user enable --now kdx-autodev-worker@devops.service
systemctl --user enable --now kdx-autodev-worker@security.service
systemctl --user enable --now kdx-autodev-worker@release.service
systemctl --user enable --now kdx-autodev-worker@webdocs.service
systemctl --user enable --now kdx-autodev-worker@agent_impl.service
systemctl --user enable --now kdx-autodev-worker@agent_verify.service

echo "Installed and started kdx-autodev.service"
echo "Health timer enabled: kdx-autodev-health.timer"
echo "Workers enabled: parser, codegen, qa, reliability, devops, security, release, webdocs, agent_impl, agent_verify"
echo "One-shot worker available on demand: systemctl --user start kdx-autodev-worker@juriste.service"
