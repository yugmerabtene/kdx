#!/usr/bin/env python3
import datetime as dt
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RUNTIME = ROOT / ".autodev" / "runtime"
FUZZ_REPORT = Path("/tmp/autodev_fuzzing_report.json")
ORACLE_DRIFT = Path("/tmp/autodev_runtime_oracle_drift.txt")
OUT_MD = Path("/tmp/autodev_crash_triage.md")
OUT_JSON = RUNTIME / "crash_triage.json"
AUTODEV_LOG = RUNTIME / "autodev.log"


def now_utc() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def tail_lines(path: Path, max_lines: int = 300) -> list[str]:
    if not path.exists():
        return []
    lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
    return lines[-max_lines:]


def main() -> int:
    RUNTIME.mkdir(parents=True, exist_ok=True)

    fuzz = {}
    if FUZZ_REPORT.exists():
        try:
            fuzz = json.loads(FUZZ_REPORT.read_text(encoding="utf-8"))
        except Exception:
            fuzz = {"parse_error": True}

    log_tail = tail_lines(AUTODEV_LOG)
    recent_failures = [
        line
        for line in log_tail
        if "Task error:" in line or "command failed (139)" in line or "segfault" in line.lower()
    ]

    oracle_drift = []
    if ORACLE_DRIFT.exists():
        oracle_drift = ORACLE_DRIFT.read_text(encoding="utf-8", errors="ignore").splitlines()

    crashes = fuzz.get("crashes", []) if isinstance(fuzz, dict) else []
    outcomes = fuzz.get("outcomes", {}) if isinstance(fuzz, dict) else {}

    summary = {
        "timestamp": now_utc(),
        "fuzz_outcomes": outcomes,
        "fuzz_crash_count": len(crashes),
        "oracle_drift_count": len([l for l in oracle_drift if l.strip()]),
        "recent_failure_lines": recent_failures[-20:],
        "fuzz_crashes": crashes[:10],
    }
    OUT_JSON.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")

    lines = [
        "# AutoDev Crash Triage",
        "",
        f"- Timestamp: {summary['timestamp']}",
        f"- Fuzz crashes: {summary['fuzz_crash_count']}",
        f"- Oracle drifts: {summary['oracle_drift_count']}",
        "",
        "## Fuzz Outcomes",
        "",
        f"- {json.dumps(outcomes, ensure_ascii=False)}",
        "",
    ]

    if crashes:
        lines.extend(["## Top Crash Candidates", ""])
        for item in crashes[:5]:
            case = item.get("case", "unknown")
            kind = item.get("kind", "unknown")
            lines.append(f"- {kind}: `{case}`")
        lines.append("")

    if oracle_drift:
        lines.extend(["## Runtime Drift", ""])
        for drift in oracle_drift[:10]:
            if drift.strip():
                lines.append(f"- {drift}")
        lines.append("")

    if recent_failures:
        lines.extend(["## Recent Failure Signals", ""])
        for line in recent_failures[-10:]:
            lines.append(f"- {line}")
        lines.append("")

    if not crashes and not oracle_drift and not recent_failures:
        lines.extend(["## Status", "", "- No crash signals detected in latest snapshot.", ""])

    OUT_MD.write_text("\n".join(lines), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
