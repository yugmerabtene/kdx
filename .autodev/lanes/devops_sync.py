#!/usr/bin/env python3
import argparse
import datetime as dt
import fnmatch
import json
import os
import re
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
AUTODEV = ROOT / ".autodev"
RUNTIME = AUTODEV / "runtime"
POLICY_PATH = AUTODEV / "policy.json"
STATE_PATH = RUNTIME / "devops_sync.json"
OUT_MD = Path("/tmp/autodev_devops_sync.md")
TOKEN_PATH = ROOT / "token.txt"


def now_utc() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def run(cmd: str, check: bool = False) -> tuple[int, str, str]:
    cp = subprocess.run(
        cmd,
        cwd=ROOT,
        shell=True,
        text=True,
        capture_output=True,
    )
    if check and cp.returncode != 0:
        raise RuntimeError(cp.stderr.strip() or cp.stdout.strip() or f"command failed: {cmd}")
    return cp.returncode, cp.stdout, cp.stderr


def load_policy() -> dict:
    if not POLICY_PATH.exists():
        return {}
    try:
        return json.loads(POLICY_PATH.read_text(encoding="utf-8"))
    except Exception:
        return {}


def load_state() -> dict:
    if not STATE_PATH.exists():
        return {}
    try:
        return json.loads(STATE_PATH.read_text(encoding="utf-8"))
    except Exception:
        return {}


def save_state(payload: dict) -> None:
    RUNTIME.mkdir(parents=True, exist_ok=True)
    STATE_PATH.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def current_branch() -> str | None:
    rc, out, _ = run("git rev-parse --abbrev-ref HEAD")
    branch = out.strip()
    if rc != 0 or not branch or branch == "HEAD":
        return None
    return branch


def changed_paths(ignore_globs: list[str]) -> list[str]:
    rc, out, _ = run("git status --porcelain")
    if rc != 0:
        return []

    paths: list[str] = []
    for raw in out.splitlines():
        if not raw.strip() or len(raw) < 4:
            continue
        path = raw[3:]
        if " -> " in path:
            path = path.split(" -> ", 1)[1]
        if any(fnmatch.fnmatch(path, pattern) for pattern in ignore_globs):
            continue
        paths.append(path)
    return sorted(set(paths))


def should_push_now(state: dict, min_minutes: int) -> bool:
    last = str(state.get("last_push_at", "")).strip()
    if not last:
        return True
    try:
        last_dt = dt.datetime.fromisoformat(last)
    except Exception:
        return True
    return (dt.datetime.now(dt.timezone.utc) - last_dt) >= dt.timedelta(minutes=min_minutes)


def commit_message() -> str:
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    return f"chore(devops): autonomous sync {stamp}"


def write_report(state: dict) -> None:
    lines = [
        "# DevOps Sync Agent",
        "",
        f"- Timestamp: {state.get('timestamp', '')}",
        f"- Status: {state.get('status', 'unknown')}",
        f"- Branch: {state.get('branch', 'unknown')}",
        f"- Committed files: {len(state.get('committed_paths', []))}",
        f"- Pushed: {state.get('pushed', False)}",
        f"- Message: {state.get('message', '')}",
    ]
    if state.get("committed_paths"):
        lines.append("")
        lines.append("## Paths")
        for path in state["committed_paths"]:
            lines.append(f"- {path}")
    OUT_MD.write_text("\n".join(lines) + "\n", encoding="utf-8")


def ensure_upstream(remote: str, branch: str) -> tuple[bool, str]:
    rc, _, _ = run("git rev-parse --abbrev-ref --symbolic-full-name @{u}")
    if rc == 0:
        return True, "upstream exists"

    rc, out, err = run(f"git push -u {remote} {branch}")
    if rc != 0:
        return False, (err.strip() or out.strip() or "unable to set upstream")
    return True, "upstream created"


def token_from_file() -> str:
    if not TOKEN_PATH.exists():
        return ""
    try:
        return TOKEN_PATH.read_text(encoding="utf-8").strip()
    except Exception:
        return ""


def github_token() -> str:
    token = str(os.environ.get("GH_TOKEN", "")).strip()
    if token:
        return token
    return token_from_file()


def infer_repo_from_remote(remote: str) -> tuple[str | None, str | None]:
    rc, out, _ = run(f"git remote get-url {remote}")
    if rc != 0:
        return None, None
    url = out.strip()
    m = re.search(r"github\.com[:/]([^/]+)/([^/.]+)(?:\.git)?$", url)
    if not m:
        return None, None
    return m.group(1), m.group(2)


def default_remote_branch(remote: str) -> str | None:
    rc, out, _ = run(f"git symbolic-ref --quiet --short refs/remotes/{remote}/HEAD")
    if rc == 0:
        value = out.strip()
        if value and "/" in value:
            return value.split("/", 1)[1]

    rc, out, _ = run(f"git remote show {remote}")
    if rc != 0:
        return None
    for line in out.splitlines():
        m = re.search(r"HEAD branch\s*:\s*(\S+)", line)
        if m:
            return m.group(1)
        m = re.search(r"Branche HEAD\s*:\s*(\S+)", line)
        if m:
            return m.group(1)
    return None


def push_target(remote: str) -> tuple[str, str]:
    token = github_token()
    if not token:
        return remote, "standard"
    owner, repo = infer_repo_from_remote(remote)
    if not owner or not repo:
        return remote, "standard"
    url = f"https://x-access-token:{token}@github.com/{owner}/{repo}.git"
    return url, "token"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Auto commit/push sync for devops worker")
    parser.add_argument("--dry-run", action="store_true", help="Report only, no git add/commit/push")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    policy = load_policy()
    state = load_state()

    enabled = bool(policy.get("autopush", True))
    min_minutes = int(policy.get("devops_sync_min_minutes", 20))
    remote = str(policy.get("push_remote", "origin")).strip() or "origin"
    ignore = [str(x) for x in policy.get("ignore_commit_globs", []) if isinstance(x, str)]
    push_dest, push_mode = push_target(remote)
    expected_branch = str(policy.get("commit_branch", "")).strip()
    if expected_branch.lower() == "auto" or not expected_branch:
        expected_branch = default_remote_branch(remote) or ""

    branch = current_branch()
    snapshot = {
        "timestamp": now_utc(),
        "status": "skipped",
        "branch": branch or "",
        "committed_paths": [],
        "pushed": False,
        "message": "",
        "remote": remote,
        "push_mode": push_mode,
        "expected_branch": expected_branch,
        "min_minutes": min_minutes,
    }

    if not enabled:
        snapshot["message"] = "autopush disabled by policy"
        save_state(snapshot)
        write_report(snapshot)
        return 0

    if not branch:
        snapshot["message"] = "detached HEAD, sync skipped"
        save_state(snapshot)
        write_report(snapshot)
        return 0

    if expected_branch and branch != expected_branch:
        snapshot["message"] = f"branch mismatch (current={branch}, expected={expected_branch})"
        save_state(snapshot)
        write_report(snapshot)
        return 0

    if not should_push_now(state, min_minutes):
        snapshot["message"] = "push cadence window not reached"
        save_state(snapshot)
        write_report(snapshot)
        return 0

    paths = changed_paths(ignore)
    if not paths:
        snapshot["message"] = "no committable changes"
        save_state(snapshot)
        write_report(snapshot)
        return 0

    if args.dry_run:
        snapshot["status"] = "dry_run"
        snapshot["committed_paths"] = paths
        snapshot["message"] = "dry-run mode, no git operations executed"
        save_state(snapshot)
        write_report(snapshot)
        return 0

    quoted = " ".join([f'"{p}"' for p in paths])
    rc, out, err = run(f"git add {quoted}")
    if rc != 0:
        snapshot["status"] = "failed"
        snapshot["message"] = err.strip() or out.strip() or "git add failed"
        save_state(snapshot)
        write_report(snapshot)
        return 0

    rc, out, err = run(f"git commit -m \"{commit_message()}\"")
    if rc != 0:
        snapshot["status"] = "failed"
        snapshot["message"] = err.strip() or out.strip() or "git commit failed"
        save_state(snapshot)
        write_report(snapshot)
        return 0

    ok_upstream, upstream_msg = ensure_upstream(push_dest, branch)
    if not ok_upstream:
        snapshot["status"] = "failed"
        snapshot["committed_paths"] = paths
        snapshot["message"] = upstream_msg
        save_state(snapshot)
        write_report(snapshot)
        return 0

    rc, out, err = run(f"git push {push_dest} {branch}")
    if rc != 0:
        snapshot["status"] = "failed"
        snapshot["committed_paths"] = paths
        message = err.strip() or out.strip() or "git push failed"
        if "Username for 'https://github.com'" in message:
            message = "git push auth failed (configure GH_TOKEN or token.txt)"
        snapshot["message"] = message
        save_state(snapshot)
        write_report(snapshot)
        return 0

    snapshot["status"] = "synced"
    snapshot["committed_paths"] = paths
    snapshot["pushed"] = True
    snapshot["last_push_at"] = now_utc()
    snapshot["message"] = upstream_msg
    save_state(snapshot)
    write_report(snapshot)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
