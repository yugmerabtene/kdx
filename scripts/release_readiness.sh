#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="${1:-/tmp/kdx_release_readiness.log}"

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
) >>"$LOG_FILE" 2>&1

{
  echo "[release] gates complete $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
} | tee -a "$LOG_FILE"
