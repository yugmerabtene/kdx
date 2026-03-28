#!/usr/bin/env python3
import datetime as dt
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SITE = ROOT / "site"
RUNTIME = ROOT / ".autodev" / "runtime"
OUT = RUNTIME / "web_launch_site.json"


def now_utc() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def main() -> int:
    required = [
        SITE / "index.html",
        SITE / "docs" / "index.html",
        SITE / "downloads" / "index.html",
        SITE / "company" / "index.html",
        SITE / "legal" / "privacy-rgpd.html",
        SITE / "assets" / "css" / "base.css",
    ]
    missing = [str(p.relative_to(ROOT)) for p in required if not p.exists()]

    script_hits = []
    for html in SITE.rglob("*.html"):
        text = html.read_text(encoding="utf-8", errors="replace").lower()
        if "<script" in text:
            script_hits.append(str(html.relative_to(ROOT)))

    payload = {
        "timestamp": now_utc(),
        "mission": "web_launch_site",
        "site_exists": SITE.exists(),
        "missing_required_files": missing,
        "script_tag_hits": script_hits,
        "status": "ok" if not missing and not script_hits else "attention",
    }

    RUNTIME.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    return 0 if payload["status"] == "ok" else 1


if __name__ == "__main__":
    raise SystemExit(main())
