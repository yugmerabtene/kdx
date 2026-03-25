#!/usr/bin/env python3
import datetime as dt
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RUNTIME = ROOT / ".autodev" / "runtime"
OUT_JSON = RUNTIME / "regression_guard.json"
OUT_MD = Path("/tmp/autodev_regression_guard.md")


def now_utc() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def run(cmd: str, timeout: int = 300) -> tuple[int, str, str]:
    cp = subprocess.run(
        cmd,
        shell=True,
        cwd=ROOT,
        text=True,
        capture_output=True,
        timeout=timeout,
    )
    return cp.returncode, cp.stdout, cp.stderr


def main() -> int:
    RUNTIME.mkdir(parents=True, exist_ok=True)
    checks = [
        {"name": "build", "cmd": "./build.sh", "timeout": 240},
        {"name": "quick_suite", "cmd": "./quick_tests/run_quick_tests.sh", "timeout": 300},
        {"name": "spec_suite", "cmd": "./quick_tests/run_spec_tests.sh", "timeout": 300},
        {"name": "runtime_oracle", "cmd": "./.autodev/lanes/runtime_oracle.sh", "timeout": 240},
    ]

    results = []
    failed = []
    for check in checks:
        rc, out, err = run(check["cmd"], timeout=check["timeout"])
        item = {
            "name": check["name"],
            "cmd": check["cmd"],
            "rc": rc,
            "stdout_tail": out[-800:],
            "stderr_tail": err[-800:],
        }
        results.append(item)
        if rc != 0:
            failed.append(check["name"])

    tag_rc, tag_out, _ = run("git tag --list --sort=v:refname")
    tags = [t.strip() for t in tag_out.splitlines() if t.strip()] if tag_rc == 0 else []

    payload = {
        "timestamp": now_utc(),
        "status": "red" if failed else "green",
        "failed_checks": failed,
        "results": results,
        "latest_tag": tags[-1] if tags else None,
    }
    OUT_JSON.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    lines = [
        "# Regression Guard",
        "",
        f"- Timestamp: {payload['timestamp']}",
        f"- Status: {payload['status']}",
        f"- Latest tag: {payload['latest_tag']}",
        f"- Failed checks: {', '.join(failed) if failed else 'none'}",
        "",
    ]
    OUT_MD.write_text("\n".join(lines), encoding="utf-8")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
