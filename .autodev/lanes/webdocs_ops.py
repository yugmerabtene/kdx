#!/usr/bin/env python3
import datetime as dt
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SITE = ROOT / "site"
RUNTIME = ROOT / ".autodev" / "runtime"
OUT_JSON = RUNTIME / "webdocs_ops.json"


def now_utc() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def local_link_issues() -> list[str]:
    issues: list[str] = []
    for html in SITE.rglob("*.html"):
        text = html.read_text(encoding="utf-8", errors="replace")
        for href in re.findall(r'href="([^"]+)"', text):
            if href.startswith(("http", "mailto:", "#")):
                continue
            target = (html.parent / href).resolve()
            if not target.exists():
                rel = html.relative_to(ROOT).as_posix()
                issues.append(f"{rel} -> {href}")
    return issues


def script_hits() -> list[str]:
    hits: list[str] = []
    for html in SITE.rglob("*.html"):
        text = html.read_text(encoding="utf-8", errors="replace").lower()
        if "<script" in text:
            hits.append(html.relative_to(ROOT).as_posix())
    return hits


def main() -> int:
    RUNTIME.mkdir(parents=True, exist_ok=True)
    required = [
        SITE / "index.html",
        SITE / "docs" / "index.html",
        SITE / "downloads" / "index.html",
        SITE / "releases" / "status.html",
    ]
    missing = [p.relative_to(ROOT).as_posix() for p in required if not p.exists()]
    links = local_link_issues()
    scripts = script_hits()

    status = "ok" if not missing and not links and not scripts else "attention"
    payload = {
        "timestamp": now_utc(),
        "mission": "webdocs_ops",
        "status": status,
        "missing_required": missing,
        "broken_links": links,
        "script_tag_hits": scripts,
    }
    OUT_JSON.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    return 0 if status == "ok" else 1


if __name__ == "__main__":
    raise SystemExit(main())
