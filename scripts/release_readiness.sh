#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCK_FILE="$ROOT_DIR/.autodev/runtime/workspace.lock"
LOG_FILE="${1:-/tmp/kdx_release_readiness.log}"

if [[ "${KDX_RELEASE_LOCKED:-0}" != "1" ]]; then
  mkdir -p "$ROOT_DIR/.autodev/runtime"
  exec env KDX_RELEASE_LOCKED=1 flock -x "$LOCK_FILE" "$0" "$@"
fi

branch="$(git -C "$ROOT_DIR" rev-parse --abbrev-ref HEAD)"
remote_head="$(git -C "$ROOT_DIR" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
expected="${remote_head#origin/}"

{
  echo "[release] start $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
  echo "[release] branch=$branch expected=${expected:-unknown}"
} | tee "$LOG_FILE"

if [[ -n "$expected" && "$branch" != "$expected" ]]; then
  echo "[release] warning: current branch differs from remote HEAD" | tee -a "$LOG_FILE"
fi

(
  cd "$ROOT_DIR"
  ./build.sh
  ./test.sh
  ./quick_tests/run_quick_tests.sh
  ./quick_tests/run_spec_tests.sh
  ./.autodev/lanes/runtime_oracle.sh
  ./.autodev/lanes/security_safety.sh
  python3 ./.autodev/lanes/regression_guard.py
  python3 ./.autodev/lanes/flaky_hunter.py
  python3 ./.autodev/lanes/release_manager.py
) >>"$LOG_FILE" 2>&1

{
  echo "[release] gates complete $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
  echo "[release] runtime snapshots:"
  echo "  - .autodev/runtime/regression_guard.json"
  echo "  - .autodev/runtime/flaky_hunter.json"
  echo "  - .autodev/runtime/release_manager.json"
} | tee -a "$LOG_FILE"
