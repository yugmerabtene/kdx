#!/bin/bash
set -euo pipefail

PROFILE="${1:-}"

if [[ -z "$PROFILE" ]]; then
  echo "usage: $0 <parser|codegen|qa|reliability|devops|security|release|webdocs|agent_impl|agent_verify|juriste>"
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUNTIME_DIR="$REPO_ROOT/.autodev/runtime"
WORKER_LOG_DIR="$RUNTIME_DIR/workers"
LOCK_FILE="$RUNTIME_DIR/workspace.lock"

mkdir -p "$WORKER_LOG_DIR"
touch "$LOCK_FILE"

LOG_FILE="$WORKER_LOG_DIR/${PROFILE}.log"

run_locked() {
  local cmd="$1"
  flock -x "$LOCK_FILE" bash -lc "cd \"$REPO_ROOT\" && $cmd"
}

log() {
  local msg="$1"
  printf '[%s] %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')" "$msg" | tee -a "$LOG_FILE"
}

run_once=0
WORKER_SLEEP_SECONDS="${AUTODEV_WORKER_SLEEP_SECONDS:-15}"

while true; do
  case "$PROFILE" in
    parser)
      log "parser loop start"
      run_locked "./build.sh >> '$LOG_FILE' 2>&1"
      run_locked "./kdx examples/control_flow.kdx -S -o /tmp/worker_parser_control_flow.s >> '$LOG_FILE' 2>&1"
      run_locked "./kdx examples/if_chain.kdx -S -o /tmp/worker_parser_if_chain.s >> '$LOG_FILE' 2>&1"
      ;;
    codegen)
      log "codegen loop start"
      run_locked "./build.sh >> '$LOG_FILE' 2>&1"
      run_locked "./kdx examples/hello.kdx -S -o /tmp/worker_codegen_hello.s >> '$LOG_FILE' 2>&1"
      run_locked "./kdx examples/simple.kdx -o /tmp/worker_codegen_simple_bin >> '$LOG_FILE' 2>&1"
      ;;
    qa)
      log "qa loop start"
      run_locked "./test.sh >> '$LOG_FILE' 2>&1"
      ;;
    reliability)
      log "reliability loop start"
      run_locked "./.autodev/lanes/security_safety.sh >> '$LOG_FILE' 2>&1"
      run_locked "./.autodev/lanes/perf_memory.sh >> '$LOG_FILE' 2>&1"
      run_locked "./.autodev/lanes/spec_consistency.sh >> '$LOG_FILE' 2>&1"
      run_locked "./.autodev/lanes/quick_tests.sh >> '$LOG_FILE' 2>&1"
      run_locked "python3 ./.autodev/lanes/fuzzing_stability.py >> '$LOG_FILE' 2>&1"
      run_locked "./.autodev/lanes/runtime_oracle.sh >> '$LOG_FILE' 2>&1"
      run_locked "python3 ./.autodev/lanes/crash_triage.py >> '$LOG_FILE' 2>&1"
      run_locked "python3 ./.autodev/lanes/regression_guard.py >> '$LOG_FILE' 2>&1"
      run_locked "python3 ./.autodev/lanes/minimizer.py >> '$LOG_FILE' 2>&1"
      run_locked "python3 ./.autodev/lanes/release_manager.py >> '$LOG_FILE' 2>&1"
      run_locked "python3 ./.autodev/lanes/flaky_hunter.py >> '$LOG_FILE' 2>&1"
      run_locked "python3 ./.autodev/lanes/cicd_devops.py >> '$LOG_FILE' 2>&1"
      run_locked "python3 ./.autodev/lanes/regression_bisect.py >> '$LOG_FILE' 2>&1"
      run_locked "./.autodev/lanes/incident_recovery.sh >> '$LOG_FILE' 2>&1"
      run_locked "python3 ./.autodev/lanes/metrics_observe.py >> '$LOG_FILE' 2>&1"
      ;;
    devops)
      log "devops loop start"
      run_locked "python3 ./.autodev/lanes/cicd_devops.py >> '$LOG_FILE' 2>&1"
      run_locked "python3 ./.autodev/lanes/release_manager.py >> '$LOG_FILE' 2>&1"
      run_locked "python3 ./.autodev/lanes/regression_guard.py >> '$LOG_FILE' 2>&1"
      run_locked "python3 ./.autodev/lanes/devops_sync.py >> '$LOG_FILE' 2>&1"
      ;;
    security)
      log "security loop start"
      run_locked "python3 scripts/secret_scan.py >> '$LOG_FILE' 2>&1"
      run_locked "./.autodev/lanes/security_safety.sh >> '$LOG_FILE' 2>&1"
      ;;
    release)
      log "release loop start"
      run_locked "python3 ./.autodev/lanes/release_manager.py >> '$LOG_FILE' 2>&1"
      run_locked "python3 ./.autodev/lanes/regression_guard.py >> '$LOG_FILE' 2>&1"
      run_locked "python3 ./.autodev/lanes/cicd_devops.py >> '$LOG_FILE' 2>&1"
      ;;
    webdocs)
      log "webdocs loop start"
      run_locked "python3 ./.autodev/lanes/web_launch_site.py >> '$LOG_FILE' 2>&1"
      run_locked "python3 ./.autodev/lanes/webdocs_ops.py >> '$LOG_FILE' 2>&1"
      ;;
    agent_impl)
      log "agent_impl loop start"
      run_locked "python3 ./.autodev/lanes/release_manager.py >> '$LOG_FILE' 2>&1"
      run_locked "python3 ./.autodev/lanes/webdocs_ops.py >> '$LOG_FILE' 2>&1"
      ;;
    agent_verify)
      log "agent_verify loop start"
      run_locked "python3 ./.autodev/lanes/regression_guard.py >> '$LOG_FILE' 2>&1"
      run_locked "python3 scripts/secret_scan.py >> '$LOG_FILE' 2>&1"
      ;;
    juriste)
      log "juriste one-shot start"
      run_locked "python3 ./.autodev/lanes/juriste_license.py >> '$LOG_FILE' 2>&1"
      run_once=1
      ;;
    *)
      log "unknown profile: $PROFILE"
      exit 2
      ;;
  esac

  log "${PROFILE} loop done"
  if [[ "$run_once" -eq 1 ]]; then
    log "${PROFILE} worker completed one-shot mission and is now sleeping"
    exit 0
  fi
  sleep "$WORKER_SLEEP_SECONDS"
done
