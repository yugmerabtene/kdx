#!/usr/bin/env python3
import argparse
import datetime as dt
import json
import os
import time
from collections import defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parent
RUNTIME = ROOT / ".autodev" / "runtime"

STATE_PATH = RUNTIME / "state.runtime.json"
METRICS_PATH = RUNTIME / "metrics.json"
BACKLOG_PATH = RUNTIME / "backlog.runtime.json"
FEATURE_BACKLOG_PATH = RUNTIME / "feature_backlog.runtime.json"
MVP_REPORT_PATH = RUNTIME / "mvp_report.json"


WORKER_MAP = [
    ("SPRINT-PARSER", "parser"),
    ("SPRINT-CODEGEN", "codegen"),
    ("SPRINT-QA", "qa"),
    ("SPRINT-PERF", "reliability"),
    ("SPRINT-SEC", "reliability"),
    ("SPRINT-SPEC", "reliability"),
    ("SPRINT-INCIDENT", "reliability"),
    ("SPRINT-METRICS", "reliability"),
    ("SPRINT-REVIEW", "reliability"),
    ("SPRINT-FUZZ", "reliability"),
    ("SPRINT-ORACLE", "reliability"),
    ("SPRINT-TRIAGE", "reliability"),
    ("SPRINT-BISECT", "reliability"),
    ("SPRINT-QUICKTEST", "reliability"),
    ("FEATURE-GROWTH-CORE", "reliability"),
    ("FEATURE-ROADMAP-SYNC", "reliability"),
]


def load_json(path: Path, default: dict) -> dict:
    if not path.exists():
        return default
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return default


def parse_iso(value: str | None) -> dt.datetime | None:
    if not value or not isinstance(value, str):
        return None
    try:
        return dt.datetime.fromisoformat(value)
    except Exception:
        return None


def lane_to_worker(task_id: str) -> str:
    for prefix, worker in WORKER_MAP:
        if task_id.startswith(prefix):
            return worker
    return "other"


def pct(n: int | float, d: int | float) -> float:
    if d == 0:
        return 0.0
    return (float(n) / float(d)) * 100.0


def bar(value: float, width: int = 26) -> str:
    value = max(0.0, min(100.0, value))
    filled = int(round((value / 100.0) * width))
    return "#" * filled + "-" * (width - filled)


def worker_share(history: list[dict], now: dt.datetime, hours: int) -> tuple[dict[str, int], int]:
    cutoff = now - dt.timedelta(hours=hours)
    counts: dict[str, int] = defaultdict(int)
    total = 0

    for item in history:
        if item.get("status") != "completed":
            continue
        t = parse_iso(item.get("time"))
        if t is None or t < cutoff:
            continue
        worker = lane_to_worker(item.get("task", ""))
        counts[worker] += 1
        total += 1

    for w in ("reliability", "parser", "codegen", "qa", "other"):
        counts.setdefault(w, 0)
    return counts, total


def success_rate(history: list[dict], now: dt.datetime, hours: int) -> tuple[int, int, float]:
    cutoff = now - dt.timedelta(hours=hours)
    completed = 0
    failed = 0
    for item in history:
        t = parse_iso(item.get("time"))
        if t is None or t < cutoff:
            continue
        st = item.get("status")
        if st == "completed":
            completed += 1
        elif st == "failed":
            failed += 1
    total = completed + failed
    return completed, failed, pct(completed, total)


def backlog_progress(backlog: dict, feature_backlog: dict) -> tuple[int, int, int, int, float]:
    v_tasks = backlog.get("tasks", []) if isinstance(backlog.get("tasks"), list) else []
    f_tasks = feature_backlog.get("tasks", []) if isinstance(feature_backlog.get("tasks"), list) else []

    v_done = sum(1 for t in v_tasks if t.get("status") == "completed")
    f_done = sum(1 for t in f_tasks if t.get("status") == "completed")
    v_total = len(v_tasks)
    f_total = len(f_tasks)
    done = v_done + f_done
    total = v_total + f_total
    return v_done, v_total, f_done, f_total, pct(done, total)


def spec_counts() -> tuple[int, int, int]:
    base = ROOT / "quick_tests" / "spec"
    if not base.exists():
        return 0, 0, 0
    p = len(list((base / "pass").glob("*.kdx"))) if (base / "pass").exists() else 0
    f = len(list((base / "fail").glob("*.kdx"))) if (base / "fail").exists() else 0
    t = len(list((base / "future").glob("*.kdx"))) if (base / "future").exists() else 0
    return p, f, t


def gather(window_hours: int) -> dict:
    state = load_json(STATE_PATH, {})
    metrics = load_json(METRICS_PATH, {})
    backlog = load_json(BACKLOG_PATH, {"tasks": []})
    feature_backlog = load_json(FEATURE_BACKLOG_PATH, {"tasks": []})
    mvp = load_json(MVP_REPORT_PATH, {})

    now = dt.datetime.now(dt.timezone.utc)
    history = state.get("history", []) if isinstance(state.get("history"), list) else []

    heartbeat = parse_iso(state.get("last_heartbeat"))
    hb_age = (now - heartbeat).total_seconds() if heartbeat else -1.0
    hb_fresh = hb_age >= 0 and hb_age <= 180

    ws, ws_total = worker_share(history, now, window_hours)
    c1, f1, s1 = success_rate(history, now, 1)
    c6, f6, s6 = success_rate(history, now, 6)
    c24, f24, s24 = success_rate(history, now, 24)

    v_done, v_total, f_done, f_total, global_progress = backlog_progress(backlog, feature_backlog)
    pass_cases, fail_cases, future_cases = spec_counts()

    return {
        "now": now,
        "state": state,
        "metrics": metrics,
        "mvp": mvp,
        "hb_age": hb_age,
        "hb_fresh": hb_fresh,
        "ws": ws,
        "ws_total": ws_total,
        "s1": (c1, f1, s1),
        "s6": (c6, f6, s6),
        "s24": (c24, f24, s24),
        "progress": (v_done, v_total, f_done, f_total, global_progress),
        "spec": (pass_cases, fail_cases, future_cases),
        "window_hours": window_hours,
    }


def render_plain(d: dict) -> str:
    now = d["now"].replace(microsecond=0).isoformat()
    c1, f1, s1 = d["s1"]
    c6, f6, s6 = d["s6"]
    c24, f24, s24 = d["s24"]
    v_done, v_total, f_done, f_total, global_progress = d["progress"]
    p, f, t = d["spec"]
    ws = d["ws"]
    ws_total = d["ws_total"]
    metrics = d["metrics"]
    state = d["state"]
    mvp = d["mvp"]

    lines = []
    lines.append("=" * 72)
    lines.append(f"KodPix Live Metrics  |  {now}")
    lines.append("=" * 72)
    lines.append(
        f"Heartbeat: {'fresh' if d['hb_fresh'] else 'stale'}"
        f"  age={d['hb_age']:.1f}s  completed_cycles={state.get('completed_cycles', 0)}"
    )
    lines.append(
        f"Build/Test RC: build={metrics.get('build_rc', 'n/a')} test={metrics.get('test_rc', 'n/a')}"
        f"  last_tag={metrics.get('last_tag', 'n/a')}"
    )
    lines.append(
        f"Backlog Progress: validation={v_done}/{v_total} feature={f_done}/{f_total}"
        f" global={global_progress:.2f}%"
    )
    lines.append(
        f"Success Rate: 1h={s1:.2f}% ({c1}/{c1+f1})  6h={s6:.2f}% ({c6}/{c6+f6})"
        f"  24h={s24:.2f}% ({c24}/{c24+f24})"
    )
    lines.append(
        f"Worker Share {d['window_hours']}h: reliability={pct(ws['reliability'], ws_total):.2f}%"
        f" parser={pct(ws['parser'], ws_total):.2f}%"
        f" codegen={pct(ws['codegen'], ws_total):.2f}%"
        f" qa={pct(ws['qa'], ws_total):.2f}%"
        f" (events={ws_total})"
    )
    lines.append(f"Spec Pack: pass={p} fail={f} future={t}")
    if mvp:
        lines.append(
            f"MVP: global={mvp.get('mvp_global_pct', 0):.6f}%"
            f" product={mvp.get('product_mvp', {}).get('pct', 0):.6f}%"
            f" ops={mvp.get('ops_health_pct', 0):.6f}%"
        )
    return "\n".join(lines)


def render_pretty(d: dict, interval: float) -> str:
    now = d["now"].replace(microsecond=0).isoformat()
    ws = d["ws"]
    ws_total = d["ws_total"]
    metrics = d["metrics"]
    state = d["state"]
    mvp = d["mvp"]
    c1, f1, s1 = d["s1"]
    c6, f6, s6 = d["s6"]
    c24, f24, s24 = d["s24"]
    v_done, v_total, f_done, f_total, global_progress = d["progress"]
    p, f, t = d["spec"]

    rel = pct(ws["reliability"], ws_total)
    par = pct(ws["parser"], ws_total)
    cod = pct(ws["codegen"], ws_total)
    qa = pct(ws["qa"], ws_total)
    oth = pct(ws["other"], ws_total)

    mvp_global = float(mvp.get("mvp_global_pct", 0.0)) if mvp else 0.0
    mvp_product = float(mvp.get("product_mvp", {}).get("pct", 0.0)) if mvp else 0.0
    mvp_ops = float(mvp.get("ops_health_pct", 0.0)) if mvp else 0.0

    hb_status = "OK" if d["hb_fresh"] else "STALE"
    hb_line = f"Heartbeat: {hb_status}  age={d['hb_age']:.1f}s"

    lines = []
    lines.append("+------------------------------------------------------------------------+")
    lines.append(f"| KodPix Live Dashboard                              {now:<24} |")
    lines.append("+------------------------------------------------------------------------+")
    lines.append(
        f"| {hb_line:<70} |"
    )
    lines.append(
        f"| Build={metrics.get('build_rc','n/a')}  Test={metrics.get('test_rc','n/a')}  "
        f"Cycles={state.get('completed_cycles',0)}  Tag={str(metrics.get('last_tag','n/a')):<12} |"
    )
    lines.append("+------------------------------------------------------------------------+")
    lines.append(
        f"| MVP Global  [{bar(mvp_global)}] {mvp_global:6.2f}%                      |"
    )
    lines.append(
        f"| MVP Product [{bar(mvp_product)}] {mvp_product:6.2f}%                      |"
    )
    lines.append(
        f"| MVP Ops     [{bar(mvp_ops)}] {mvp_ops:6.2f}%                      |"
    )
    lines.append("+------------------------------------------------------------------------+")
    lines.append(
        f"| Backlog: validation {v_done:>2}/{v_total:<2}  feature {f_done:>2}/{f_total:<2}  "
        f"global {global_progress:6.2f}%               |"
    )
    lines.append(
        f"| Success: 1h {s1:6.2f}% ({c1:>3}/{c1+f1:<3})  "
        f"6h {s6:6.2f}% ({c6:>3}/{c6+f6:<3})  24h {s24:6.2f}% ({c24:>3}/{c24+f24:<3}) |
"
    )
    lines[-1] = lines[-1].rstrip("\n")
    lines.append("+------------------------------------------------------------------------+")
    lines.append(f"| Worker Share ({d['window_hours']}h, events={ws_total:<4})                                         |")
    lines.append(f"| reliability [{bar(rel, 20)}] {rel:6.2f}%                               |")
    lines.append(f"| parser      [{bar(par, 20)}] {par:6.2f}%                               |")
    lines.append(f"| codegen     [{bar(cod, 20)}] {cod:6.2f}%                               |")
    lines.append(f"| qa          [{bar(qa, 20)}] {qa:6.2f}%                               |")
    lines.append(f"| other       [{bar(oth, 20)}] {oth:6.2f}%                               |")
    lines.append("+------------------------------------------------------------------------+")
    lines.append(f"| Spec Cases: pass={p:<3} fail={f:<3} future={t:<3}                                       |")
    lines.append(f"| Refresh: {interval:.1f}s  Ctrl+C to stop                                      |")
    lines.append("+------------------------------------------------------------------------+")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="Live KodPix orchestrator metrics dashboard")
    parser.add_argument("--interval", type=float, default=2.0, help="refresh interval in seconds")
    parser.add_argument("--window-hours", type=int, default=1, help="worker share window")
    parser.add_argument("--once", action="store_true", help="print one snapshot and exit")
    parser.add_argument("--plain", action="store_true", help="plain output (no screen animation)")
    args = parser.parse_args()

    if args.once:
        data = gather(args.window_hours)
        if args.plain:
            print(render_plain(data))
        else:
            print(render_pretty(data, args.interval))
        return 0

    try:
        while True:
            data = gather(args.window_hours)
            output = render_plain(data) if args.plain else render_pretty(data, args.interval)
            if args.plain:
                print(output)
                print("Ctrl+C to stop\n")
            else:
                print("\033[2J\033[H", end="")
                print(output)
            time.sleep(max(args.interval, 0.5))
    except KeyboardInterrupt:
        if not args.plain:
            print("\n")
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
