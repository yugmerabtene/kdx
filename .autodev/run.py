#!/usr/bin/env python3
import argparse
import copy
import datetime as dt
import fcntl
import fnmatch
import json
import os
import pathlib
import shlex
import subprocess
import sys
import time
from typing import Dict, List, Optional, Tuple


ROOT = pathlib.Path(__file__).resolve().parents[1]
AUTODEV = ROOT / ".autodev"
RUNTIME = AUTODEV / "runtime"
BACKLOG_TEMPLATE_PATH = AUTODEV / "backlog.json"
FEATURE_TEMPLATE_PATH = AUTODEV / "feature_backlog.json"
STATE_TEMPLATE_PATH = AUTODEV / "state.json"
BACKLOG_PATH = RUNTIME / "backlog.runtime.json"
FEATURE_BACKLOG_PATH = RUNTIME / "feature_backlog.runtime.json"
STATE_PATH = RUNTIME / "state.runtime.json"
POLICY_PATH = AUTODEV / "policy.json"
LOG_PATH = RUNTIME / "autodev.log"
LOCK_PATH = RUNTIME / "orchestrator.lock"
HEARTBEAT_PATH = RUNTIME / "heartbeat.txt"
WORKSPACE_LOCK_PATH = RUNTIME / "workspace.lock"


def now_utc() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def log(message: str) -> None:
    line = f"[{now_utc()}] {message}"
    print(line)
    with LOG_PATH.open("a", encoding="utf-8") as f:
        f.write(line + "\n")


def run_cmd(command: str, check: bool = True) -> subprocess.CompletedProcess:
    lock_file = WORKSPACE_LOCK_PATH
    lock_file.parent.mkdir(parents=True, exist_ok=True)
    lock_file.touch(exist_ok=True)

    wrapped = (
        f"flock -x {shlex.quote(str(lock_file))} "
        f"bash -lc {shlex.quote(f'cd {shlex.quote(str(ROOT))} && {command}')}"
    )
    cp = subprocess.run(
        wrapped,
        shell=True,
        text=True,
        capture_output=True,
        errors="replace",
    )
    if cp.stdout:
        log(f"stdout: {cp.stdout.strip()}")
    if cp.stderr:
        log(f"stderr: {cp.stderr.strip()}")
    if check and cp.returncode != 0:
        raise RuntimeError(f"command failed ({cp.returncode}): {command}")
    return cp


def load_json(path: pathlib.Path, default: Dict) -> Dict:
    if not path.exists():
        return default
    return json.loads(path.read_text(encoding="utf-8"))


def save_json(path: pathlib.Path, payload: Dict) -> None:
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def touch_heartbeat(state: Dict) -> None:
    state["last_heartbeat"] = now_utc()
    HEARTBEAT_PATH.write_text(state["last_heartbeat"] + "\n", encoding="utf-8")


def requeue_failed_tasks(backlog: Dict, policy: Dict, label: str) -> Dict:
    if not bool(policy.get("requeue_failed_tasks", True)):
        return backlog
    changed = False
    for task in backlog.get("tasks", []):
        if task.get("status") == "failed":
            task["status"] = "pending"
            task["retries"] = 0
            task.pop("last_error", None)
            changed = True
    if changed:
        log(f"Requeued failed tasks in {label} backlog")
    return backlog


def parse_iso(value: Optional[str]) -> Optional[dt.datetime]:
    if not value:
        return None
    return dt.datetime.fromisoformat(value)


def should_stop(state: Dict, policy: Dict) -> bool:
    started = parse_iso(state.get("started_at"))
    if started is None:
        return False
    limit = started + dt.timedelta(hours=int(policy["duration_hours"]))
    return dt.datetime.now(dt.timezone.utc) >= limit


def priority_score(value: str) -> int:
    return {"high": 0, "medium": 1, "low": 2}.get(value, 3)


def sort_tasks(tasks: List[Dict]) -> List[Dict]:
    return sorted(tasks, key=lambda t: (priority_score(t.get("priority", "low")), t.get("id", "")))


def regenerate_backlog(backlog: Dict) -> Dict:
    generated = now_utc()
    backlog["generated_at"] = generated
    backlog["tasks"] = [
        {
            "id": f"SPRINT-PARSER-{generated}",
            "title": "Parser lane periodic validation",
            "lane": "dev_parser",
            "priority": "high",
            "status": "pending",
            "retries": 0,
            "commit_message": "chore(parser): periodic autonomous validation",
            "steps": [
                "./build.sh",
                "./kdx examples/control_flow.kdx -S -o /tmp/autodev_regen_parser.s",
            ],
        },
        {
            "id": f"SPRINT-CODEGEN-{generated}",
            "title": "Codegen lane periodic validation",
            "lane": "dev_codegen",
            "priority": "high",
            "status": "pending",
            "retries": 0,
            "commit_message": "chore(codegen): periodic autonomous validation",
            "steps": [
                "./build.sh",
                "./kdx examples/hello.kdx -S -o /tmp/autodev_regen_codegen.s",
            ],
        },
        {
            "id": f"SPRINT-QA-{generated}",
            "title": "QA lane periodic regression",
            "lane": "qa",
            "priority": "high",
            "status": "pending",
            "retries": 0,
            "commit_message": "chore(qa): periodic autonomous regression",
            "steps": ["./test.sh"],
        },
        {
            "id": f"SPRINT-QUICKTEST-{generated}",
            "title": "Quick test lane generation and sweep",
            "lane": "quick_tests",
            "priority": "high",
            "status": "pending",
            "retries": 0,
            "commit_message": "chore(quick-tests): periodic quick suite sweep",
            "steps": ["./.autodev/lanes/quick_tests.sh"],
        },
        {
            "id": f"SPRINT-FUZZ-{generated}",
            "title": "Fuzzing lane crash sweep",
            "lane": "fuzzing_stability",
            "priority": "high",
            "status": "pending",
            "retries": 0,
            "commit_message": "chore(fuzz): periodic autonomous crash sweep",
            "steps": ["python3 ./.autodev/lanes/fuzzing_stability.py"],
        },
        {
            "id": f"SPRINT-ORACLE-{generated}",
            "title": "Runtime oracle behavior checks",
            "lane": "runtime_oracle",
            "priority": "high",
            "status": "pending",
            "retries": 0,
            "commit_message": "chore(oracle): periodic runtime behavior checks",
            "steps": ["./.autodev/lanes/runtime_oracle.sh"],
        },
        {
            "id": f"SPRINT-PERF-{generated}",
            "title": "Perf and memory periodic sweep",
            "lane": "perf_memory",
            "priority": "high",
            "status": "pending",
            "retries": 0,
            "commit_message": "chore(perf): periodic autonomous sweep",
            "steps": ["./.autodev/lanes/perf_memory.sh"],
        },
        {
            "id": f"SPRINT-SEC-{generated}",
            "title": "Security and safety periodic checks",
            "lane": "security_safety",
            "priority": "high",
            "status": "pending",
            "retries": 0,
            "commit_message": "chore(security): periodic autonomous checks",
            "steps": ["./.autodev/lanes/security_safety.sh"],
        },
        {
            "id": f"SPRINT-SPEC-{generated}",
            "title": "Language spec periodic consistency",
            "lane": "spec_consistency",
            "priority": "medium",
            "status": "pending",
            "retries": 0,
            "commit_message": "chore(spec): periodic autonomous consistency",
            "steps": ["./.autodev/lanes/spec_consistency.sh"],
        },
        {
            "id": f"SPRINT-INCIDENT-{generated}",
            "title": "Incident periodic recovery check",
            "lane": "incident_recovery",
            "priority": "medium",
            "status": "pending",
            "retries": 0,
            "commit_message": "chore(incident): periodic autonomous recovery",
            "steps": ["./.autodev/lanes/incident_recovery.sh"],
        },
        {
            "id": f"SPRINT-METRICS-{generated}",
            "title": "Metrics periodic observability snapshot",
            "lane": "metrics_observe",
            "priority": "medium",
            "status": "pending",
            "retries": 0,
            "commit_message": "chore(metrics): periodic autonomous snapshot",
            "steps": ["python3 ./.autodev/lanes/metrics_observe.py"],
        },
        {
            "id": f"SPRINT-TRIAGE-{generated}",
            "title": "Crash triage and minimization snapshot",
            "lane": "crash_triage",
            "priority": "medium",
            "status": "pending",
            "retries": 0,
            "commit_message": "chore(triage): periodic crash triage snapshot",
            "steps": ["python3 ./.autodev/lanes/crash_triage.py"],
        },
        {
            "id": f"SPRINT-BISECT-{generated}",
            "title": "Regression bisect suspect extraction",
            "lane": "regression_bisect",
            "priority": "medium",
            "status": "pending",
            "retries": 0,
            "commit_message": "chore(bisect): periodic suspect extraction snapshot",
            "steps": ["python3 ./.autodev/lanes/regression_bisect.py"],
        },
    ]
    log("Backlog was empty; regenerated default sprint tasks")
    return backlog


def regenerate_feature_backlog() -> Dict:
    template = load_json(FEATURE_TEMPLATE_PATH, {"generated_at": "", "tasks": []})
    generated = now_utc()
    out = {"generated_at": generated, "tasks": []}

    for task in template.get("tasks", []):
        t = copy.deepcopy(task)
        base_id = t.get("id", "FEATURE-TASK")
        t["id"] = f"{base_id}-{generated}"
        t["status"] = "pending"
        t["retries"] = 0
        t.pop("started_at", None)
        t.pop("completed_at", None)
        t.pop("last_error", None)
        out["tasks"].append(t)

    log("Feature backlog regenerated from template")
    return out


def next_task(backlog: Dict) -> Optional[Dict]:
    pending = [t for t in backlog.get("tasks", []) if t.get("status") == "pending"]
    if not pending:
        return None
    return sort_tasks(pending)[0]


def has_pending(backlog: Dict) -> bool:
    return bool([t for t in backlog.get("tasks", []) if t.get("status") in {"pending", "in_progress"}])


def qa_gate(policy: Dict) -> None:
    loops = int(policy.get("qa_loops", 1))
    for i in range(1, loops + 1):
        log(f"QA gate loop {i}/{loops}")
        run_cmd("./test.sh")


def safe_commit_paths(policy: Dict) -> List[str]:
    ignore = policy.get("ignore_commit_globs", [])
    cp = run_cmd("git status --porcelain", check=True)
    paths: List[str] = []
    for line in cp.stdout.splitlines():
        if not line.strip():
            continue
        path = line[3:]
        if " -> " in path:
            path = path.split(" -> ", 1)[1]
        if any(fnmatch.fnmatch(path, pattern) for pattern in ignore):
            continue
        paths.append(path)
    return sorted(set(paths))


def latest_tag() -> Optional[str]:
    cp = run_cmd("git tag --list --sort=v:refname", check=True)
    tags = [t.strip() for t in cp.stdout.splitlines() if t.strip()]
    return tags[-1] if tags else None


def bump_patch(tag: Optional[str]) -> str:
    if not tag or not tag.startswith("v"):
        return "v0.1.0"
    try:
        major, minor, patch = tag[1:].split(".")
        return f"v{int(major)}.{int(minor)}.{int(patch) + 1}"
    except Exception:
        return "v0.1.0"


def commit_and_tag(task: Dict, policy: Dict, state: Dict) -> None:
    if not bool(policy.get("autocommit", True)):
        log("Autocommit disabled by policy")
        return
    paths = safe_commit_paths(policy)
    if not paths:
        log("No committable source changes detected")
        return
    quoted = " ".join([f'"{p}"' for p in paths])
    run_cmd(f"git add {quoted}")
    msg = task.get("commit_message") or f"chore: autonomous task {task.get('id')}"
    run_cmd(f"git commit -m \"{msg}\"")
    head = run_cmd("git rev-parse --short HEAD").stdout.strip()
    state["last_commit"] = head
    log(f"Committed autonomous changes: {head}")

    if bool(policy.get("autotag", True)):
        current = latest_tag()
        new_tag = bump_patch(current)
        run_cmd(f"git tag -a {new_tag} -m \"{new_tag} autonomous sprint\"")
        state["last_tag"] = new_tag
        log(f"Created autonomous tag: {new_tag}")


def execute_task(task: Dict, backlog: Dict, backlog_path: pathlib.Path, state: Dict, policy: Dict) -> Tuple[bool, str]:
    task["status"] = "in_progress"
    task["started_at"] = now_utc()
    save_json(backlog_path, backlog)

    log(f"Starting task {task['id']} ({task.get('lane')})")
    try:
        for step in task.get("steps", []):
            log(f"step: {step}")
            run_cmd(step)

        qa_gate(policy)
        commit_and_tag(task, policy, state)

        task["status"] = "completed"
        task["completed_at"] = now_utc()
        state["completed_cycles"] = int(state.get("completed_cycles", 0)) + 1
        state["last_completed_task"] = task["id"]
        state.setdefault("history", []).append(
            {
                "task": task["id"],
                "status": "completed",
                "time": now_utc(),
            }
        )
        log(f"Task completed: {task['id']}")
        return True, "completed"
    except Exception as exc:
        task["status"] = "pending"
        task["retries"] = int(task.get("retries", 0)) + 1
        task["last_error"] = str(exc)
        if task["retries"] > int(policy.get("max_retries_per_task", 2)):
            task["status"] = "failed"
            log(f"Task marked failed after retries: {task['id']}")
        state.setdefault("history", []).append(
            {
                "task": task["id"],
                "status": "failed",
                "time": now_utc(),
                "error": str(exc),
            }
        )
        log(f"Task error: {task['id']}: {exc}")
        return False, str(exc)
    finally:
        save_json(backlog_path, backlog)
        save_json(STATE_PATH, state)


def healthcheck() -> int:
    if not HEARTBEAT_PATH.exists():
        print("heartbeat missing")
        return 1
    content = HEARTBEAT_PATH.read_text(encoding="utf-8").strip()
    hb = parse_iso(content)
    if hb is None:
        print("heartbeat invalid")
        return 1
    age = dt.datetime.now(dt.timezone.utc) - hb
    if age > dt.timedelta(minutes=10):
        print(f"heartbeat stale: {age}")
        return 2
    print(f"heartbeat ok: {age}")
    return 0


def main_loop(once: bool = False) -> int:
    AUTODEV.mkdir(parents=True, exist_ok=True)
    RUNTIME.mkdir(parents=True, exist_ok=True)
    lock_file = LOCK_PATH.open("w", encoding="utf-8")
    try:
        fcntl.flock(lock_file, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        log("Another orchestrator instance is already running")
        return 0

    if not BACKLOG_PATH.exists() and BACKLOG_TEMPLATE_PATH.exists():
        BACKLOG_PATH.write_text(BACKLOG_TEMPLATE_PATH.read_text(encoding="utf-8"), encoding="utf-8")
    if not FEATURE_BACKLOG_PATH.exists() and FEATURE_TEMPLATE_PATH.exists():
        FEATURE_BACKLOG_PATH.write_text(FEATURE_TEMPLATE_PATH.read_text(encoding="utf-8"), encoding="utf-8")
    if not STATE_PATH.exists() and STATE_TEMPLATE_PATH.exists():
        STATE_PATH.write_text(STATE_TEMPLATE_PATH.read_text(encoding="utf-8"), encoding="utf-8")

    backlog = load_json(BACKLOG_PATH, {"generated_at": "", "tasks": []})
    feature_backlog = load_json(FEATURE_BACKLOG_PATH, {"generated_at": "", "tasks": []})
    state = load_json(
        STATE_PATH,
        {
            "started_at": None,
            "last_heartbeat": None,
            "completed_cycles": 0,
            "validation_since_feature": 0,
            "history": [],
        },
    )
    policy = load_json(POLICY_PATH, {"duration_hours": 168, "loop_sleep_seconds": 60})

    if state.get("started_at") is None:
        state["started_at"] = now_utc()
        log(f"Initialized autonomous window at {state['started_at']}")

    save_json(STATE_PATH, state)

    while True:
        touch_heartbeat(state)
        save_json(STATE_PATH, state)

        if should_stop(state, policy):
            log("Autonomous window reached duration limit; stopping daemon")
            return 0

        if not has_pending(backlog):
            backlog = regenerate_backlog(backlog)
            save_json(BACKLOG_PATH, backlog)
        backlog = requeue_failed_tasks(backlog, policy, "validation")
        save_json(BACKLOG_PATH, backlog)

        feature_enabled = bool(policy.get("feature_enabled", True))
        if feature_enabled and not has_pending(feature_backlog):
            feature_backlog = regenerate_feature_backlog()
            save_json(FEATURE_BACKLOG_PATH, feature_backlog)
        if feature_enabled:
            feature_backlog = requeue_failed_tasks(feature_backlog, policy, "feature")
            save_json(FEATURE_BACKLOG_PATH, feature_backlog)

        validation_task = next_task(backlog)
        feature_task = next_task(feature_backlog) if feature_enabled else None

        feature_every = int(policy.get("feature_every_n_validation_tasks", 3))
        validation_since_feature = int(state.get("validation_since_feature", 0))

        selected_task: Optional[Dict] = None
        selected_path = BACKLOG_PATH
        selected_track = "validation"

        if feature_task is not None and (validation_task is None or validation_since_feature >= feature_every):
            selected_task = feature_task
            selected_path = FEATURE_BACKLOG_PATH
            selected_track = "feature"
        else:
            selected_task = validation_task
            selected_path = BACKLOG_PATH
            selected_track = "validation"

        if selected_task is None:
            log("No pending tasks available")
            if once:
                return 0
            time.sleep(int(policy.get("loop_sleep_seconds", 60)))
            continue

        target_backlog = feature_backlog if selected_track == "feature" else backlog
        ok, _ = execute_task(selected_task, target_backlog, selected_path, state, policy)

        if ok:
            if selected_track == "feature":
                state["validation_since_feature"] = 0
            else:
                state["validation_since_feature"] = int(state.get("validation_since_feature", 0)) + 1
            save_json(STATE_PATH, state)

        if selected_track == "feature":
            feature_backlog = target_backlog
        else:
            backlog = target_backlog

        if once:
            return 0

        time.sleep(int(policy.get("loop_sleep_seconds", 60)))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="KodPix autonomous multi-agent runner")
    parser.add_argument("--once", action="store_true", help="run a single orchestration cycle")
    parser.add_argument("--daemon", action="store_true", help="run continuously")
    parser.add_argument("--healthcheck", action="store_true", help="check heartbeat freshness")
    args = parser.parse_args()

    if args.healthcheck:
        sys.exit(healthcheck())

    if args.once:
        sys.exit(main_loop(once=True))

    if args.daemon:
        sys.exit(main_loop(once=False))

    parser.print_help()
    sys.exit(1)
