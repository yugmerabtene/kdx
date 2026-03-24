#!/usr/bin/env python3
import datetime as dt
import json
import random
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TMP_DIR = Path("/tmp/autodev_fuzz")
REPORT_PATH = Path("/tmp/autodev_fuzzing_report.json")
ITERATIONS = 24
COMPILE_TIMEOUT_SECONDS = 6


def now_utc() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def run(cmd: list[str], timeout: int = 60) -> subprocess.CompletedProcess:
    return subprocess.run(
        cmd,
        cwd=ROOT,
        text=True,
        capture_output=True,
        timeout=timeout,
    )


def make_valid_program(rng: random.Random) -> str:
    var_name = f"v{rng.randint(0, 999)}"
    init = rng.randint(0, 7)
    loops = rng.randint(0, 2)

    lines = [
        "function main() -> int {",
        f"    int {var_name} = {init};",
    ]

    for _ in range(loops):
        lines.append(f"    if ({rng.randint(0, 1)}) {{")
        lines.append(f"        {var_name}++;")
        lines.append("    }")

    lines.append(f"    return {var_name};")
    lines.append("}")
    return "\n".join(lines) + "\n"


def make_invalid_program(rng: random.Random) -> str:
    choice = rng.randint(0, 3)
    if choice == 0:
        return "function main() -> int {\n    int x = 1\n    return x;\n}\n"
    if choice == 1:
        return "function main() -> int {\n    @@@\n    return 0;\n}\n"
    if choice == 2:
        return "function main() -> int {\n    if (1 {\n        return 0;\n    }\n}\n"
    return "function main() -> int {\n    for (int i = 0 i < 3; i++) { return 0; }\n    return 0;\n}\n"


def main() -> int:
    TMP_DIR.mkdir(parents=True, exist_ok=True)

    build = run(["./build.sh"], timeout=120)
    if build.returncode != 0:
        REPORT_PATH.write_text(
            json.dumps(
                {
                    "timestamp": now_utc(),
                    "status": "build_failed",
                    "build_rc": build.returncode,
                    "stderr": build.stderr,
                },
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )
        return 1

    rng = random.Random(20260324)
    crashes: list[dict] = []
    outcomes = {"ok": 0, "errors": 0, "timeouts": 0, "crashes": 0}

    for i in range(ITERATIONS):
        valid = (i % 3) != 0
        source = make_valid_program(rng) if valid else make_invalid_program(rng)
        src = TMP_DIR / f"fuzz_{i:03d}.kdx"
        out = TMP_DIR / f"fuzz_{i:03d}.s"
        src.write_text(source, encoding="utf-8")

        try:
            cp = run(["./kdx", str(src), "-S", "-o", str(out)], timeout=COMPILE_TIMEOUT_SECONDS)
        except subprocess.TimeoutExpired:
            outcomes["timeouts"] += 1
            crashes.append(
                {
                    "case": str(src),
                    "kind": "timeout",
                    "valid_program": valid,
                }
            )
            continue

        rc = cp.returncode
        if rc in (139, -11):
            outcomes["crashes"] += 1
            crashes.append(
                {
                    "case": str(src),
                    "kind": "sigsegv",
                    "valid_program": valid,
                    "stdout": cp.stdout[-800:],
                    "stderr": cp.stderr[-800:],
                }
            )
        elif rc == 0:
            outcomes["ok"] += 1
        else:
            outcomes["errors"] += 1

    payload = {
        "timestamp": now_utc(),
        "iterations": ITERATIONS,
        "outcomes": outcomes,
        "crashes": crashes,
        "seed": 20260324,
    }
    REPORT_PATH.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")

    if outcomes["crashes"] > 0 or outcomes["timeouts"] > 0:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
