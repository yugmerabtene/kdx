#!/usr/bin/env python3
import argparse
import datetime as dt
import json
import re
import subprocess
import time
from collections import defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parent
AUTODEV = ROOT / ".autodev"
RUNTIME = AUTODEV / "runtime"

STATE_PATH = RUNTIME / "state.runtime.json"
METRICS_PATH = RUNTIME / "metrics.json"
BACKLOG_PATH = RUNTIME / "backlog.runtime.json"
FEATURE_BACKLOG_PATH = RUNTIME / "feature_backlog.runtime.json"
MVP_REPORT_PATH = RUNTIME / "mvp_report.json"
LANE_MAP_PATH = AUTODEV / "worker_map.json"

WIDTH = 100


DEFAULT_TASK_PREFIX_MAP = {
    "SPRINT-PARSER": "parser",
    "SPRINT-CODEGEN": "codegen",
    "SPRINT-QA": "qa",
    "SPRINT-PERF": "reliability",
    "SPRINT-SEC": "reliability",
    "SPRINT-SPEC": "reliability",
    "SPRINT-INCIDENT": "reliability",
    "SPRINT-METRICS": "reliability",
    "SPRINT-REVIEW": "reliability",
    "SPRINT-FUZZ": "reliability",
    "SPRINT-ORACLE": "reliability",
    "SPRINT-TRIAGE": "reliability",
    "SPRINT-BISECT": "reliability",
    "SPRINT-REGGUARD": "reliability",
    "SPRINT-MINIMIZER": "reliability",
    "SPRINT-RELEASE": "reliability",
    "SPRINT-FLAKY": "reliability",
    "SPRINT-CICD": "reliability",
    "SPRINT-QUICKTEST": "reliability",
    "FEATURE-GROWTH-CORE": "reliability",
    "FEATURE-ROADMAP-SYNC": "reliability",
}

TOKEN_FALLBACK_MAP = {
    "PARSER": "parser",
    "CODEGEN": "codegen",
    "QA": "qa",
    "PERF": "reliability",
    "SEC": "reliability",
    "SPEC": "reliability",
    "INCIDENT": "reliability",
    "METRICS": "reliability",
    "REVIEW": "reliability",
    "FUZZ": "reliability",
    "ORACLE": "reliability",
    "TRIAGE": "reliability",
    "BISECT": "reliability",
    "QUICKTEST": "reliability",
    "REGGUARD": "reliability",
    "MINIMIZER": "reliability",
    "RELEASE": "reliability",
    "FLAKY": "reliability",
    "CICD": "reliability",
}


class Colors:
    RESET = "\033[0m"
    BOLD = "\033[1m"
    DIM = "\033[2m"
    RED = "\033[31m"
    GREEN = "\033[32m"
    YELLOW = "\033[33m"
    BLUE = "\033[34m"
    CYAN = "\033[36m"


def colorize(text: str, color: str, enabled: bool) -> str:
    if not enabled:
        return text
    return f"{color}{text}{Colors.RESET}"


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


def pct(n: int | float, d: int | float) -> float:
    if d == 0:
        return 0.0
    return (float(n) / float(d)) * 100.0


def bar(value: float, width: int = 22, full: str = "#", empty: str = "-") -> str:
    v = max(0.0, min(100.0, value))
    filled = int(round((v / 100.0) * width))
    return full * filled + empty * (width - filled)


def lane_to_worker(task_id: str, known_workers: set[str], prefix_map: dict[str, str]) -> str:
    for prefix, worker in prefix_map.items():
        if task_id.startswith(prefix):
            return worker

    m = re.match(r"^SPRINT-([A-Z0-9_]+)-", task_id)
    if m:
        token = m.group(1)
        mapped = TOKEN_FALLBACK_MAP.get(token, token.lower())
        if mapped in known_workers:
            return mapped
        return mapped

    if task_id.startswith("FEATURE-"):
        return "reliability"

    return "other"


def list_worker_services() -> dict[str, str]:
    services: dict[str, str] = {}
    cmd = [
        "systemctl",
        "--user",
        "list-units",
        "kdx-autodev-worker@*.service",
        "--all",
        "--no-legend",
        "--plain",
    ]
    try:
        cp = subprocess.run(cmd, capture_output=True, text=True, check=False)
    except Exception:
        return services

    if cp.returncode != 0:
        return services

    for line in cp.stdout.splitlines():
        parts = line.split()
        if len(parts) < 4:
            continue
        unit = parts[0]
        active = parts[2]
        m = re.match(r"kdx-autodev-worker@(.+)\.service", unit)
        if not m:
            continue
        services[m.group(1)] = active
    return services


def orchestrator_status() -> str:
    cmd = ["systemctl", "--user", "is-active", "kdx-autodev.service"]
    try:
        cp = subprocess.run(cmd, capture_output=True, text=True, check=False)
    except Exception:
        return "unknown"
    if cp.returncode == 0:
        return cp.stdout.strip() or "active"
    return (cp.stdout.strip() or cp.stderr.strip() or "inactive").splitlines()[0]


def read_custom_lane_map() -> dict[str, str]:
    data = load_json(LANE_MAP_PATH, {})
    mapping = data.get("task_prefix_to_worker") if isinstance(data, dict) else None
    if not isinstance(mapping, dict):
        return {}
    out: dict[str, str] = {}
    for k, v in mapping.items():
        if isinstance(k, str) and isinstance(v, str) and k.strip() and v.strip():
            out[k.strip()] = v.strip()
    return out


def worker_share(
    history: list[dict],
    now: dt.datetime,
    hours: int,
    known_workers: set[str],
    prefix_map: dict[str, str],
) -> tuple[dict[str, int], int]:
    cutoff = now - dt.timedelta(hours=hours)
    counts: dict[str, int] = defaultdict(int)
    total = 0

    for item in history:
        if item.get("status") != "completed":
            continue
        t = parse_iso(item.get("time"))
        if t is None or t < cutoff:
            continue
        worker = lane_to_worker(item.get("task", ""), known_workers, prefix_map)
        counts[worker] += 1
        total += 1

    for w in sorted(known_workers):
        counts.setdefault(w, 0)
    counts.setdefault("other", 0)
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


def recent_failures(history: list[dict], now: dt.datetime, limit: int = 5) -> list[str]:
    cutoff = now - dt.timedelta(hours=24)
    out: list[str] = []
    for item in reversed(history):
        if item.get("status") != "failed":
            continue
        t = parse_iso(item.get("time"))
        if t is None or t < cutoff:
            continue
        task = str(item.get("task", "unknown"))
        err = str(item.get("error", "failed"))
        if len(err) > 70:
            err = err[:67] + "..."
        out.append(f"{task}: {err}")
        if len(out) >= limit:
            break
    return out


def next_pending(backlog: dict, feature_backlog: dict, limit: int = 5) -> list[str]:
    out: list[str] = []
    for task in backlog.get("tasks", []):
        if task.get("status") == "pending":
            out.append(str(task.get("id", "?")))
            if len(out) >= limit:
                return out
    for task in feature_backlog.get("tasks", []):
        if task.get("status") == "pending":
            out.append(str(task.get("id", "?")))
            if len(out) >= limit:
                return out
    return out


def box_line(text: str = "") -> str:
    inner = WIDTH - 4
    return f"| {text[:inner]:<{inner}} |"


def top_border() -> str:
    return "+" + "-" * (WIDTH - 2) + "+"


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

    services = list_worker_services()
    known_workers = set(services.keys()) if services else {"parser", "codegen", "qa", "reliability"}
    prefix_map = DEFAULT_TASK_PREFIX_MAP | read_custom_lane_map()

    ws, ws_total = worker_share(history, now, window_hours, known_workers, prefix_map)
    c1, f1, s1 = success_rate(history, now, 1)
    c6, f6, s6 = success_rate(history, now, 6)
    c24, f24, s24 = success_rate(history, now, 24)

    v_done, v_total, f_done, f_total, global_progress = backlog_progress(backlog, feature_backlog)
    pass_cases, fail_cases, future_cases = spec_counts()

    failures = recent_failures(history, now, limit=5)
    pending = next_pending(backlog, feature_backlog, limit=5)

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
        "orchestrator": orchestrator_status(),
        "services": services,
        "known_workers": sorted(known_workers),
        "recent_failures": failures,
        "next_pending": pending,
    }


def render_pretty(d: dict, interval: float, color: bool) -> str:
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

    mvp_global = float(mvp.get("mvp_global_pct", 0.0)) if mvp else 0.0
    mvp_product = float(mvp.get("product_mvp", {}).get("pct", 0.0)) if mvp else 0.0
    mvp_ops = float(mvp.get("ops_health_pct", 0.0)) if mvp else 0.0

    hb_text = "OK" if d["hb_fresh"] else "STALE"
    hb_color = Colors.GREEN if d["hb_fresh"] else Colors.RED

    orch = d["orchestrator"]
    orch_color = Colors.GREEN if orch == "active" else Colors.RED

    alert_parts = []
    if not d["hb_fresh"]:
        alert_parts.append("heartbeat stale")
    if metrics.get("build_rc", 0) != 0:
        alert_parts.append("build failing")
    if metrics.get("test_rc", 0) != 0:
        alert_parts.append("tests failing")
    inactive_workers = [w for w, st in d["services"].items() if st != "active"]
    if inactive_workers:
        alert_parts.append("inactive workers: " + ",".join(inactive_workers))
    alert_text = "none" if not alert_parts else " | ".join(alert_parts)

    lines: list[str] = []
    lines.append(top_border())
    title = colorize("KodPix Live Dashboard", Colors.BOLD + Colors.CYAN, color)
    lines.append(box_line(f"{title}  {now}"))
    lines.append(top_border())

    ctrl = (
        f"orchestrator={colorize(orch, orch_color, color)}  "
        f"heartbeat={colorize(hb_text, hb_color, color)} age={d['hb_age']:.1f}s  "
        f"cycles={state.get('completed_cycles', 0)}"
    )
    lines.append(box_line(ctrl))
    lines.append(
        box_line(
            f"build={metrics.get('build_rc','n/a')} test={metrics.get('test_rc','n/a')} "
            f"tag={metrics.get('last_tag','n/a')} commit={metrics.get('last_commit','n/a')}"
        )
    )
    lines.append(top_border())

    lines.append(box_line(f"MVP global  [{bar(mvp_global)}] {mvp_global:6.2f}%"))
    lines.append(box_line(f"MVP product [{bar(mvp_product)}] {mvp_product:6.2f}%"))
    lines.append(box_line(f"MVP ops     [{bar(mvp_ops)}] {mvp_ops:6.2f}%"))
    lines.append(top_border())

    lines.append(
        box_line(
            f"backlog: validation {v_done}/{v_total}  feature {f_done}/{f_total}  "
            f"global {global_progress:.2f}%"
        )
    )
    lines.append(
        box_line(
            f"success: 1h {s1:.2f}% ({c1}/{c1+f1})  "
            f"6h {s6:.2f}% ({c6}/{c6+f6})  24h {s24:.2f}% ({c24}/{c24+f24})"
        )
    )
    lines.append(box_line(f"spec: pass={p} fail={f} future={t}"))
    lines.append(top_border())

    lines.append(box_line(f"workers ({d['window_hours']}h share, events={ws_total})"))
    for worker in d["known_workers"] + ["other"]:
        share = pct(ws.get(worker, 0), ws_total)
        service_state = d["services"].get(worker, "n/a")
        st_color = Colors.GREEN if service_state == "active" else Colors.YELLOW if service_state == "n/a" else Colors.RED
        svc = colorize(service_state, st_color, color)
        lines.append(
            box_line(
                f"{worker:<12} [{bar(share, 20)}] {share:6.2f}%  "
                f"service={svc:<10} completed={ws.get(worker,0)}"
            )
        )
    lines.append(top_border())

    lines.append(box_line(f"alerts: {alert_text}"))
    if d["next_pending"]:
        lines.append(box_line("next pending:"))
        for item in d["next_pending"]:
            lines.append(box_line(f"  - {item}"))
    else:
        lines.append(box_line("next pending: none"))

    if d["recent_failures"]:
        lines.append(box_line("recent failures (24h):"))
        for item in d["recent_failures"]:
            lines.append(box_line(f"  - {item}"))
    else:
        lines.append(box_line("recent failures (24h): none"))

    lines.append(top_border())
    lines.append(box_line(f"refresh={interval:.1f}s  Ctrl+C to stop  add worker map via .autodev/worker_map.json"))
    lines.append(top_border())
    return "\n".join(lines)


def render_plain(d: dict) -> str:
    now = d["now"].replace(microsecond=0).isoformat()
    c1, f1, s1 = d["s1"]
    c6, f6, s6 = d["s6"]
    c24, f24, s24 = d["s24"]
    v_done, v_total, f_done, f_total, global_progress = d["progress"]
    p, f, t = d["spec"]
    mvp = d["mvp"]

    lines: list[str] = []
    lines.append("=" * 100)
    lines.append(f"KodPix Live Metrics | {now}")
    lines.append("=" * 100)
    lines.append(
        f"orchestrator={d['orchestrator']} heartbeat={'fresh' if d['hb_fresh'] else 'stale'} "
        f"age={d['hb_age']:.1f}s cycles={d['state'].get('completed_cycles',0)}"
    )
    lines.append(
        f"build={d['metrics'].get('build_rc','n/a')} test={d['metrics'].get('test_rc','n/a')} "
        f"tag={d['metrics'].get('last_tag','n/a')} commit={d['metrics'].get('last_commit','n/a')}"
    )
    lines.append(
        f"backlog validation={v_done}/{v_total} feature={f_done}/{f_total} global={global_progress:.2f}%"
    )
    lines.append(
        f"success 1h={s1:.2f}% ({c1}/{c1+f1}) 6h={s6:.2f}% ({c6}/{c6+f6}) 24h={s24:.2f}% ({c24}/{c24+f24})"
    )
    lines.append(f"spec pass={p} fail={f} future={t}")
    if mvp:
        lines.append(
            f"mvp global={mvp.get('mvp_global_pct',0):.6f}% "
            f"product={mvp.get('product_mvp',{}).get('pct',0):.6f}% ops={mvp.get('ops_health_pct',0):.6f}%"
        )
    lines.append(f"worker share ({d['window_hours']}h events={d['ws_total']}):")
    for worker in d["known_workers"] + ["other"]:
        lines.append(
            f"  - {worker}: {pct(d['ws'].get(worker,0), d['ws_total']):.2f}% "
            f"completed={d['ws'].get(worker,0)} service={d['services'].get(worker,'n/a')}"
        )
    if d["next_pending"]:
        lines.append("next pending:")
        for item in d["next_pending"]:
            lines.append(f"  - {item}")
    if d["recent_failures"]:
        lines.append("recent failures (24h):")
        for item in d["recent_failures"]:
            lines.append(f"  - {item}")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="Animated KodPix metrics dashboard")
    parser.add_argument("--interval", type=float, default=2.0, help="refresh interval in seconds")
    parser.add_argument("--window-hours", type=int, default=1, help="worker share lookback window")
    parser.add_argument("--once", action="store_true", help="print one snapshot and exit")
    parser.add_argument("--plain", action="store_true", help="plain output (no dashboard clear)")
    parser.add_argument("--no-color", action="store_true", help="disable ANSI colors")
    args = parser.parse_args()

    use_color = (not args.no_color) and (not args.plain)

    if args.once:
        data = gather(args.window_hours)
        print(render_plain(data) if args.plain else render_pretty(data, args.interval, use_color))
        return 0

    try:
        while True:
            data = gather(args.window_hours)
            output = render_plain(data) if args.plain else render_pretty(data, args.interval, use_color)
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
