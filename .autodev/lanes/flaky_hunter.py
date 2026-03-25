#!/usr/bin/env python3
import datetime as dt
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RUNTIME = ROOT / ".autodev" / "runtime"
OUT_JSON = RUNTIME / "flaky_hunter.json"
OUT_MD = Path("/tmp/autodev_flaky_hunter.md")


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

    suites = [
        {"name": "quick", "cmd": "./quick_tests/run_quick_tests.sh", "iterations": 3},
        {"name": "spec", "cmd": "./quick_tests/run_spec_tests.sh", "iterations": 3},
        {"name": "oracle", "cmd": "./.autodev/lanes/runtime_oracle.sh", "iterations": 3},
    ]

    report = []
    flaky = []
    hard_fail = []

    for suite in suites:
        rcs = []
        for _ in range(suite["iterations"]):
            rc, _, _ = run(suite["cmd"], timeout=300)
            rcs.append(rc)

        unique = sorted(set(rcs))
        row = {
            "name": suite["name"],
            "iterations": suite["iterations"],
            "results": rcs,
            "unique": unique,
            "flaky": len(unique) > 1,
            "all_pass": all(rc == 0 for rc in rcs),
        }
        report.append(row)

        if row["flaky"]:
            flaky.append(suite["name"])
        if not row["all_pass"] and not row["flaky"]:
            hard_fail.append(suite["name"])

    payload = {
        "timestamp": now_utc(),
        "flaky_suites": flaky,
        "hard_fail_suites": hard_fail,
        "stable": (not flaky and not hard_fail),
        "report": report,
    }
    OUT_JSON.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    lines = [
        "# Flaky Hunter",
        "",
        f"- Timestamp: {payload['timestamp']}",
        f"- Stable: {payload['stable']}",
        f"- Flaky suites: {', '.join(flaky) if flaky else 'none'}",
        f"- Hard-fail suites: {', '.join(hard_fail) if hard_fail else 'none'}",
        "",
    ]
    OUT_MD.write_text("\n".join(lines), encoding="utf-8")
    return 1 if flaky or hard_fail else 0


if __name__ == "__main__":
    raise SystemExit(main())
