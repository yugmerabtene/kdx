#!/usr/bin/env python3
import datetime as dt
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
AUTODEV = ROOT / ".autodev"
RUNTIME = AUTODEV / "runtime"

STATE_PATH = RUNTIME / "state.runtime.json"
BACKLOG_PATH = RUNTIME / "backlog.runtime.json"
FEATURE_BACKLOG_PATH = RUNTIME / "feature_backlog.runtime.json"
METRICS_PATH = RUNTIME / "metrics.json"
SPEC_PATH = AUTODEV / "mvp_tracking_spec.json"

OUT_JSON = RUNTIME / "mvp_report.json"
OUT_MD = Path("/tmp/autodev_mvp_report.md")


def now_utc() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def load_json(path: Path, default: dict) -> dict:
    if not path.exists():
        return default
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return default


def parse_iso(value: str | None) -> dt.datetime | None:
    if not value:
        return None
    try:
        return dt.datetime.fromisoformat(value)
    except Exception:
        return None


def rolling_success(history: list[dict], last: dt.datetime, hours: int) -> dict:
    cutoff = last - dt.timedelta(hours=hours)
    completed = 0
    failed = 0
    for item in history:
        t = parse_iso(item.get("time"))
        if t is None or t < cutoff:
            continue
        if item.get("status") == "completed":
            completed += 1
        elif item.get("status") == "failed":
            failed += 1
    total = completed + failed
    rate = (completed / total * 100.0) if total else 0.0
    return {
        "hours": hours,
        "completed": completed,
        "failed": failed,
        "total": total,
        "success_rate_pct": rate,
        "velocity_cycles_per_hour": (completed / float(hours)) if hours > 0 else 0.0,
    }


def backlog_progress(backlog: dict, feature_backlog: dict) -> dict:
    v_tasks = backlog.get("tasks", [])
    f_tasks = feature_backlog.get("tasks", [])
    total = len(v_tasks) + len(f_tasks)
    completed = sum(1 for t in v_tasks if t.get("status") == "completed") + sum(
        1 for t in f_tasks if t.get("status") == "completed"
    )
    return {
        "validation": {
            "completed": sum(1 for t in v_tasks if t.get("status") == "completed"),
            "total": len(v_tasks),
            "pct": (sum(1 for t in v_tasks if t.get("status") == "completed") / len(v_tasks) * 100.0)
            if v_tasks
            else 0.0,
        },
        "feature": {
            "completed": sum(1 for t in f_tasks if t.get("status") == "completed"),
            "total": len(f_tasks),
            "pct": (sum(1 for t in f_tasks if t.get("status") == "completed") / len(f_tasks) * 100.0)
            if f_tasks
            else 0.0,
        },
        "global": {
            "completed": completed,
            "total": total,
            "pct": (completed / total * 100.0) if total else 0.0,
        },
    }


def gate_passes(metrics: dict) -> tuple[int, int]:
    checks = [
        bool(metrics.get("build_rc") == 0),
        bool(metrics.get("test_rc") == 0),
        bool(metrics.get("heartbeat_fresh", True)),
        bool(metrics.get("runtime_oracle_green", True)),
        bool(metrics.get("fuzz_green", True)),
        bool(metrics.get("crash_triage_clean", True)),
    ]
    passed = sum(1 for c in checks if c)
    return passed, len(checks)


def main() -> int:
    spec = load_json(SPEC_PATH, {})
    state = load_json(STATE_PATH, {})
    backlog = load_json(BACKLOG_PATH, {"tasks": []})
    feature_backlog = load_json(FEATURE_BACKLOG_PATH, {"tasks": []})
    metrics = load_json(METRICS_PATH, {})

    started = parse_iso(state.get("started_at"))
    last = parse_iso(state.get("last_heartbeat")) or dt.datetime.now(dt.timezone.utc)
    history = state.get("history", []) if isinstance(state.get("history"), list) else []

    elapsed_hours = ((last - started).total_seconds() / 3600.0) if started else 0.0
    completed_total = sum(1 for h in history if h.get("status") == "completed")
    velocity = (completed_total / elapsed_hours) if elapsed_hours > 0 else 0.0

    windows = spec.get("tracking_window_hours", [1, 3, 6, 12, 24])
    rolling = [rolling_success(history, last, int(w)) for w in windows]
    win6 = next((w for w in rolling if w["hours"] == 6), {"success_rate_pct": 0.0})
    win24 = next((w for w in rolling if w["hours"] == 24), {"success_rate_pct": 0.0})

    progress = backlog_progress(backlog, feature_backlog)
    cycle_progress_pct = progress["global"]["pct"]

    passed, total = gate_passes(metrics)
    product_pct = (passed / total * 100.0) if total else 0.0

    model = spec.get("score_model", {})
    velocity_ref = float(model.get("velocity_reference_cycles_per_hour", 30.0))
    velocity_cap = float(model.get("velocity_score_cap", 100.0))
    velocity_score_pct = min((velocity / velocity_ref) * 100.0, velocity_cap) if velocity_ref > 0 else 0.0

    ops_model = model.get("ops_components", {})
    ops_pct = (
        float(ops_model.get("cycle_progress_weight", 0.2)) * cycle_progress_pct
        + float(ops_model.get("success_rate_6h_weight", 0.5)) * float(win6["success_rate_pct"])
        + float(ops_model.get("success_rate_24h_weight", 0.2)) * float(win24["success_rate_pct"])
        + float(ops_model.get("velocity_weight", 0.1)) * velocity_score_pct
    )

    product_weight = float(model.get("product_weight", 0.6))
    ops_weight = float(model.get("ops_weight", 0.4))
    mvp_global_pct = product_weight * product_pct + ops_weight * ops_pct

    report = {
        "timestamp": now_utc(),
        "elapsed_hours": elapsed_hours,
        "completed_total": completed_total,
        "avg_velocity_cycles_per_hour": velocity,
        "rolling": rolling,
        "progress": progress,
        "product_mvp": {
            "passed": passed,
            "total": total,
            "pct": product_pct,
        },
        "ops_health_pct": ops_pct,
        "velocity_score_pct": velocity_score_pct,
        "mvp_global_pct": mvp_global_pct,
    }

    OUT_JSON.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    lines = [
        "# AutoDev MVP Report",
        "",
        f"- Timestamp: {report['timestamp']}",
        f"- MVP global: {report['mvp_global_pct']:.6f}%",
        f"- Product MVP: {report['product_mvp']['pct']:.6f}% ({passed}/{total})",
        f"- Ops health: {report['ops_health_pct']:.6f}%",
        f"- Cycle progress: {report['progress']['global']['pct']:.6f}%",
        f"- Velocity: {report['avg_velocity_cycles_per_hour']:.6f} cycles/h",
        "",
    ]
    OUT_MD.write_text("\n".join(lines), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
