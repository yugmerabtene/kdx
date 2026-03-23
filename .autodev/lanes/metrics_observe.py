#!/usr/bin/env python3
import datetime as dt
import json
import pathlib
import subprocess


ROOT = pathlib.Path(__file__).resolve().parents[2]
RUNTIME = ROOT / ".autodev" / "runtime"
METRICS = RUNTIME / "metrics.json"
STATE = RUNTIME / "state.runtime.json"


def run(cmd: str) -> int:
    cp = subprocess.run(cmd, shell=True, cwd=ROOT)
    return cp.returncode


def main() -> int:
    RUNTIME.mkdir(parents=True, exist_ok=True)
    now = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()

    test_rc = run("./test.sh >/tmp/autodev_metrics_test.log 2>&1")
    build_rc = run("./build.sh >/tmp/autodev_metrics_build.log 2>&1")

    state = {}
    if STATE.exists():
        state = json.loads(STATE.read_text(encoding="ascii"))

    metrics = {
        "timestamp": now,
        "build_rc": build_rc,
        "test_rc": test_rc,
        "completed_cycles": state.get("completed_cycles", 0),
        "last_completed_task": state.get("last_completed_task"),
        "last_commit": state.get("last_commit"),
        "last_tag": state.get("last_tag"),
    }

    METRICS.write_text(json.dumps(metrics, indent=2) + "\n", encoding="ascii")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
