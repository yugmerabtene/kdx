#!/usr/bin/env python3
import datetime as dt
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
AUTODEV = ROOT / ".autodev"
RUNTIME = AUTODEV / "runtime"
PROFILE_PATH = AUTODEV / "cicd_profile.json"

OUT_JSON = RUNTIME / "juriste_license.json"
OUT_MD = Path("/tmp/autodev_juriste_license.md")


def now_utc() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def load_profile() -> dict:
    if not PROFILE_PATH.exists():
        return {}
    try:
        return json.loads(PROFILE_PATH.read_text(encoding="utf-8"))
    except Exception:
        return {}


def main() -> int:
    RUNTIME.mkdir(parents=True, exist_ok=True)

    profile = load_profile()
    author_name = str(profile.get("author_name", "")).strip()
    author_email = str(profile.get("author_email", "")).strip()

    required_files = {
        "license": ROOT / "LICENSE",
        "commercial_license": ROOT / "LICENSE-COMMERCIAL.md",
        "notice": ROOT / "NOTICE",
        "legal_doc": ROOT / "docs" / "legal" / "licensing.md",
    }

    missing = [name for name, path in required_files.items() if not path.exists()]
    mission_status = "completed" if not missing else "blocked"

    payload = {
        "timestamp": now_utc(),
        "mission": "juriste_license",
        "mode": "one-shot",
        "worker_state": "sleeping" if mission_status == "completed" else "needs-attention",
        "author_name": author_name,
        "author_email": author_email,
        "licensing_model": "dual-license-gpl3-commercial",
        "commercial_contact": author_email,
        "missing_artifacts": missing,
    }
    OUT_JSON.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    lines = [
        "# Juriste Worker Report",
        "",
        f"- Timestamp: {payload['timestamp']}",
        f"- Mission: {payload['mission']}",
        f"- Mode: {payload['mode']}",
        f"- Licensing model: {payload['licensing_model']}",
        f"- Author: {author_name or 'missing'}",
        f"- Commercial contact: {author_email or 'missing'}",
        f"- Missing artifacts: {', '.join(missing) if missing else 'none'}",
        f"- Worker state: {payload['worker_state']}",
        "",
        "This report is informational and not legal advice.",
    ]
    OUT_MD.write_text("\n".join(lines) + "\n", encoding="utf-8")

    return 0 if mission_status == "completed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
