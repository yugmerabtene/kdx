#!/usr/bin/env python3
import datetime as dt
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RUNTIME = ROOT / ".autodev" / "runtime"
OUT_JSON = RUNTIME / "release_manager.json"
OUT_MD = Path("/tmp/autodev_release_manager.md")


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


def bump_patch(tag: str | None) -> str:
    if not tag or not tag.startswith("v"):
        return "v0.1.0"
    try:
        major, minor, patch = tag[1:].split(".")
        return f"v{int(major)}.{int(minor)}.{int(patch) + 1}"
    except Exception:
        return "v0.1.0"


def main() -> int:
    RUNTIME.mkdir(parents=True, exist_ok=True)

    gates = [
        {"name": "build", "cmd": "./build.sh", "timeout": 240},
        {"name": "test", "cmd": "./test.sh", "timeout": 300},
        {"name": "quick", "cmd": "./quick_tests/run_quick_tests.sh", "timeout": 300},
        {"name": "spec", "cmd": "./quick_tests/run_spec_tests.sh", "timeout": 300},
        {"name": "oracle", "cmd": "./.autodev/lanes/runtime_oracle.sh", "timeout": 240},
    ]

    results = []
    failed = []
    for gate in gates:
        rc, out, err = run(gate["cmd"], timeout=gate["timeout"])
        row = {
            "name": gate["name"],
            "rc": rc,
            "stdout_tail": out[-600:],
            "stderr_tail": err[-600:],
        }
        results.append(row)
        if rc != 0:
            failed.append(gate["name"])

    _, tag_out, _ = run("git tag --list --sort=v:refname")
    tags = [t.strip() for t in tag_out.splitlines() if t.strip()]
    current_tag = tags[-1] if tags else None
    suggested_tag = bump_patch(current_tag)

    payload = {
        "timestamp": now_utc(),
        "release_ready": not failed,
        "failed_gates": failed,
        "current_tag": current_tag,
        "suggested_next_tag": suggested_tag,
        "results": results,
    }
    OUT_JSON.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    lines = [
        "# Release Manager",
        "",
        f"- Timestamp: {payload['timestamp']}",
        f"- Release ready: {payload['release_ready']}",
        f"- Current tag: {current_tag}",
        f"- Suggested next tag: {suggested_tag}",
        f"- Failed gates: {', '.join(failed) if failed else 'none'}",
        "",
    ]
    OUT_MD.write_text("\n".join(lines), encoding="utf-8")

    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
