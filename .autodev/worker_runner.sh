#!/bin/bash
set -euo pipefail

PROFILE="${1:-}"

if [[ -z "$PROFILE" ]]; then
  echo "usage: $0 <parser|codegen|qa|reliability>"
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
      run_locked "python3 ./.autodev/lanes/regression_bisect.py >> '$LOG_FILE' 2>&1"
      run_locked "./.autodev/lanes/incident_recovery.sh >> '$LOG_FILE' 2>&1"
      run_locked "python3 ./.autodev/lanes/metrics_observe.py >> '$LOG_FILE' 2>&1"
      ;;
    *)
      log "unknown profile: $PROFILE"
      exit 2
      ;;
  esac

  log "${PROFILE} loop done"
  sleep 30
done
