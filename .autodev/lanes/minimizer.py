#!/usr/bin/env python3
import datetime as dt
import json
import re
import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RUNTIME = ROOT / ".autodev" / "runtime"
STATE_PATH = RUNTIME / "state.runtime.json"
OUT_JSON = RUNTIME / "minimizer.json"
OUT_DIR = Path("/tmp/autodev_minimizer")


def now_utc() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def run(cmd: str, timeout: int = 120) -> tuple[int, str, str]:
    cp = subprocess.run(
        cmd,
        shell=True,
        cwd=ROOT,
        text=True,
        capture_output=True,
        timeout=timeout,
    )
    return cp.returncode, cp.stdout, cp.stderr


def latest_failure_error() -> str | None:
    if not STATE_PATH.exists():
        return None
    try:
        state = json.loads(STATE_PATH.read_text(encoding="utf-8"))
    except Exception:
        return None

    history = state.get("history", [])
    if not isinstance(history, list):
        return None
    for item in reversed(history):
        if item.get("status") == "failed":
            err = item.get("error")
            if isinstance(err, str):
                return err
    return None


def extract_kdx_path(text: str | None) -> Path | None:
    if not text:
        return None
    matches = re.findall(r"([\w./-]+\.kdx)", text)
    for raw in reversed(matches):
        path = (ROOT / raw).resolve() if not raw.startswith("/") else Path(raw)
        if path.exists():
            return path
    return None


def compile_fails(src: Path) -> bool:
    cmd = f"./kdx {src} -S -o /tmp/autodev_minimizer_out.s"
    rc, _, _ = run(cmd)
    return rc != 0


def minimize_lines(source_path: Path) -> tuple[Path, int, int]:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    work_path = OUT_DIR / (source_path.stem + ".min.kdx")
    shutil.copy2(source_path, work_path)

    original_lines = work_path.read_text(encoding="utf-8", errors="ignore").splitlines()
    lines = original_lines[:]

    if not compile_fails(work_path):
        return work_path, len(original_lines), len(lines)

    changed = True
    while changed and len(lines) > 1:
        changed = False
        idx = 0
        while idx < len(lines):
            trial = lines[:idx] + lines[idx + 1 :]
            if not trial:
                break
            work_path.write_text("\n".join(trial) + "\n", encoding="utf-8")
            if compile_fails(work_path):
                lines = trial
                changed = True
            else:
                idx += 1

    work_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return work_path, len(original_lines), len(lines)


def main() -> int:
    RUNTIME.mkdir(parents=True, exist_ok=True)

    err = latest_failure_error()
    src = extract_kdx_path(err)

    payload = {
        "timestamp": now_utc(),
        "source_failure": err,
        "source_file": str(src) if src else None,
        "minimized_file": None,
        "original_lines": 0,
        "minimized_lines": 0,
        "status": "noop",
    }

    if src is not None:
        min_path, original_count, min_count = minimize_lines(src)
        payload["minimized_file"] = str(min_path)
        payload["original_lines"] = original_count
        payload["minimized_lines"] = min_count
        payload["status"] = "reduced" if min_count < original_count else "unchanged"

    OUT_JSON.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
