#!/usr/bin/env python3
import datetime as dt
import json
import os
import re
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
AUTODEV = ROOT / ".autodev"
RUNTIME = AUTODEV / "runtime"

PROFILE_PATH = AUTODEV / "cicd_profile.json"
OUT_JSON = RUNTIME / "cicd_devops.json"
OUT_MD = Path("/tmp/autodev_cicd_devops.md")
TOKEN_PATH = ROOT / "token.txt"
USER_TOKEN_PATH = Path.home() / ".config" / "kdx-autodev" / "gh_token"
BRANCHING_DOC_PATH = ROOT / "docs" / "dev" / "branching-strategy.md"


def branching_policy_audit() -> tuple[bool, list[str]]:
    if not BRANCHING_DOC_PATH.exists():
        return False, ["missing docs/dev/branching-strategy.md"]

    text = BRANCHING_DOC_PATH.read_text(encoding="utf-8", errors="replace")
    required_markers = [
        "feature/",
        "release/",
        "hotfix/",
        "Pull request required",
        "Required status checks",
    ]
    missing = [m for m in required_markers if m not in text]
    return len(missing) == 0, missing


def token_from_file() -> str:
    if USER_TOKEN_PATH.exists():
        try:
            return USER_TOKEN_PATH.read_text(encoding="utf-8").strip()
        except Exception:
            pass

    if not TOKEN_PATH.exists():
        return ""
    try:
        return TOKEN_PATH.read_text(encoding="utf-8").strip()
    except Exception:
        return ""


def now_utc() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def run(cmd: str, timeout: int = 120) -> tuple[int, str, str]:
    env = os.environ.copy()
    if not env.get("GH_TOKEN"):
        token = token_from_file()
        if token:
            env["GH_TOKEN"] = token

    cp = subprocess.run(
        cmd,
        cwd=ROOT,
        shell=True,
        text=True,
        capture_output=True,
        env=env,
        timeout=timeout,
    )
    return cp.returncode, cp.stdout, cp.stderr


def load_profile() -> dict:
    if not PROFILE_PATH.exists():
        return {}
    try:
        return json.loads(PROFILE_PATH.read_text(encoding="utf-8"))
    except Exception:
        return {}


def infer_repo_from_remote() -> tuple[str | None, str | None]:
    rc, out, _ = run("git remote get-url origin")
    if rc != 0:
        return None, None
    url = out.strip()
    m = re.search(r"github\.com[:/]([^/]+)/([^/.]+)(?:\.git)?$", url)
    if not m:
        return None, None
    return m.group(1), m.group(2)


def gh_logged_in() -> bool:
    if str(os.environ.get("GH_TOKEN", "")).strip():
        return True
    if token_from_file():
        return True
    rc, _, _ = run("gh auth status")
    return rc == 0


def apply_branch_protection(profile: dict) -> tuple[bool, str]:
    owner = profile.get("owner", "")
    repo = profile.get("repo", "")
    branch = profile.get("default_branch", "main")
    if not owner or not repo:
        return False, "missing owner/repo"

    checks = profile.get("required_checks", [])
    contexts = [{"context": c} for c in checks if isinstance(c, str) and c.strip()]
    review_count = int(profile.get("required_approving_review_count", 1))
    require_code_owner_reviews = bool(profile.get("require_code_owner_reviews", False))

    payload = {
        "required_status_checks": {
            "strict": True,
            "checks": contexts,
        },
        "enforce_admins": True,
        "required_pull_request_reviews": {
            "dismiss_stale_reviews": True,
            "require_code_owner_reviews": require_code_owner_reviews,
            "required_approving_review_count": review_count,
        },
        "restrictions": None,
        "required_conversation_resolution": True,
        "allow_force_pushes": False,
        "allow_deletions": False,
        "block_creations": False,
    }

    temp = Path("/tmp/autodev_branch_protection.json")
    temp.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    cmd = (
        f"gh api -X PUT repos/{owner}/{repo}/branches/{branch}/protection "
        f"--input {temp}"
    )
    rc, out, err = run(cmd, timeout=180)
    if rc != 0:
        msg = (err.strip() or out.strip() or "gh api failed")
        return False, msg
    return True, "branch protection updated"


def main() -> int:
    RUNTIME.mkdir(parents=True, exist_ok=True)

    profile = load_profile()
    owner = str(profile.get("owner", "")).strip()
    repo = str(profile.get("repo", "")).strip()

    infer_owner, infer_repo = infer_repo_from_remote()
    if not owner and infer_owner:
        owner = infer_owner
    if not repo and infer_repo:
        repo = infer_repo

    missing = []
    if not owner:
        missing.append("owner")
    if not repo:
        missing.append("repo")
    if not str(profile.get("author_name", "")).strip():
        missing.append("author_name")
    if not str(profile.get("author_email", "")).strip():
        missing.append("author_email")

    auth_ok = gh_logged_in()
    protection_ok = False
    protection_msg = "skipped"
    branching_ok, branching_missing = branching_policy_audit()

    if not missing and auth_ok:
        merged = dict(profile)
        merged["owner"] = owner
        merged["repo"] = repo
        protection_ok, protection_msg = apply_branch_protection(merged)

    payload = {
        "timestamp": now_utc(),
        "auth_ok": auth_ok,
        "owner": owner,
        "repo": repo,
        "missing_profile_fields": missing,
        "branch_protection_applied": protection_ok,
        "branch_protection_message": protection_msg,
        "branching_policy_doc_ok": branching_ok,
        "branching_policy_missing_markers": branching_missing,
    }
    OUT_JSON.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    lines = [
        "# CI/CD DevOps Agent",
        "",
        f"- Timestamp: {payload['timestamp']}",
        f"- GitHub auth: {'ok' if auth_ok else 'missing'}",
        f"- Repository: {owner}/{repo}" if owner and repo else "- Repository: unresolved",
        f"- Branch protection: {protection_msg}",
        f"- Branching policy doc: {'ok' if branching_ok else 'missing markers'}",
    ]

    if branching_missing:
        lines.append("")
        lines.append("## Branching policy gaps")
        for marker in branching_missing:
            lines.append(f"- {marker}")

    if missing:
        lines.append("")
        lines.append("## Required inputs")
        for item in missing:
            lines.append(f"- {item}")
        lines.append("")
        lines.append("Fill `.autodev/cicd_profile.json` and rerun this lane.")

    if not auth_ok:
        lines.append("")
        lines.append("Run `gh auth login --hostname github.com --git-protocol https --web`.")

    OUT_MD.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
