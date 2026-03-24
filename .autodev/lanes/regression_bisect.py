#!/usr/bin/env python3
import datetime as dt
import json
import pathlib
import subprocess
from typing import Any


ROOT = pathlib.Path(__file__).resolve().parents[2]
RUNTIME = ROOT / ".autodev" / "runtime"
STATE_PATH = RUNTIME / "state.runtime.json"
OUT_PATH = RUNTIME / "regression_bisect.json"
MD_PATH = pathlib.Path("/tmp/autodev_regression_bisect.md")


def now_utc() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def run(cmd: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        cmd,
        shell=True,
        cwd=ROOT,
        text=True,
        capture_output=True,
        errors="replace",
    )


def parse_iso(value: str) -> dt.datetime:
    return dt.datetime.fromisoformat(value)


def read_state() -> dict[str, Any]:
    if not STATE_PATH.exists():
        return {}
    try:
        return json.loads(STATE_PATH.read_text(encoding="utf-8"))
    except Exception:
        return {}


def latest_failure_window(history: list[dict[str, Any]]) -> tuple[dict[str, Any] | None, dict[str, Any] | None]:
    failed = [h for h in history if h.get("status") == "failed" and isinstance(h.get("time"), str)]
    if not failed:
        return None, None

    failed.sort(key=lambda h: h.get("time", ""))
    target = failed[-1]
    target_time = target.get("time")
    if not isinstance(target_time, str):
        return target, None

    t_bad = parse_iso(target_time)
    prior_completed = [
        h
        for h in history
        if h.get("status") == "completed"
        and isinstance(h.get("time"), str)
        and parse_iso(h["time"]) <= t_bad
    ]
    if not prior_completed:
        return target, None
    prior_completed.sort(key=lambda h: h.get("time", ""))
    return target, prior_completed[-1]


def suspect_commits(window_start: str | None, window_end: str | None) -> list[str]:
    if not window_end:
        cp = run("git log --oneline -n 20")
        lines = [ln.strip() for ln in cp.stdout.splitlines() if ln.strip()]
        return lines

    if window_start:
        cmd = (
            "git log --oneline "
            f"--since='{window_start}' --until='{window_end}' -n 40"
        )
    else:
        cmd = f"git log --oneline --until='{window_end}' -n 40"

    cp = run(cmd)
    lines = [ln.strip() for ln in cp.stdout.splitlines() if ln.strip()]
    return lines


def main() -> int:
    RUNTIME.mkdir(parents=True, exist_ok=True)

    state = read_state()
    history_raw = state.get("history", []) if isinstance(state, dict) else []
    history = history_raw if isinstance(history_raw, list) else []

    failure, prior_success = latest_failure_window(history)

    failure_time = failure.get("time") if isinstance(failure, dict) else None
    success_time = prior_success.get("time") if isinstance(prior_success, dict) else None
    if not isinstance(failure_time, str):
        failure_time = None
    if not isinstance(success_time, str):
        success_time = None

    status_cp = run("git status --porcelain")
    dirty = bool(status_cp.stdout.strip())

    suspects = suspect_commits(success_time, failure_time)

    payload = {
        "timestamp": now_utc(),
        "mode": "non_destructive",
        "workspace_dirty": dirty,
        "latest_failed_task": failure,
        "latest_prior_success": prior_success,
        "suspect_commits": suspects,
        "note": "Uses time-window suspect extraction; does not run git bisect checkout.",
    }
    OUT_PATH.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    lines = [
        "# Regression Bisect Snapshot",
        "",
        f"- Timestamp: {payload['timestamp']}",
        f"- Mode: {payload['mode']}",
        f"- Workspace dirty: {payload['workspace_dirty']}",
        "",
    ]

    if isinstance(failure, dict):
        lines.append(f"- Latest failed task: `{failure.get('task', 'unknown')}` at `{failure.get('time', 'unknown')}`")
        if failure.get("error"):
            lines.append(f"- Error: `{failure.get('error')}`")
    else:
        lines.append("- Latest failed task: none recorded")

    if isinstance(prior_success, dict):
        lines.append(
            f"- Prior successful task: `{prior_success.get('task', 'unknown')}` at `{prior_success.get('time', 'unknown')}`"
        )
    lines.append("")

    lines.append("## Suspect Commits")
    lines.append("")
    if suspects:
        for commit in suspects[:15]:
            lines.append(f"- {commit}")
    else:
        lines.append("- No suspect commits found in the inferred window")
    lines.append("")

    if dirty:
        lines.append("## Action")
        lines.append("")
        lines.append("- Workspace is dirty, so checkout-based `git bisect` is intentionally skipped.")
        lines.append("- Use this suspect list to prioritize fixes without interrupting autonomous loops.")
        lines.append("")

    MD_PATH.write_text("\n".join(lines), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
