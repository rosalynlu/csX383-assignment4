#!/usr/bin/env python3
"""
compare_scenarios.py — overlay CDF plots and print a comparison table
for multiple latency scenarios (e.g. baseline, wan30ms, wan80ms).

Usage:
  python3 scripts/compare_scenarios.py \
    --scenarios "PA4 Baseline" "WAN 30ms+1%loss" "WAN 80ms+0.5%loss" \
    --inputs "data/latencies_pa4_u*_rep*.csv" \
             "data/latencies_pa4_wan30ms_u*_rep*.csv" \
             "data/latencies_pa4_wan80ms_u*_rep*.csv" \
    --outdir out \
    --title "PA4 Milestone 2: Baseline vs WAN Degradation"

--scenarios and --inputs must have the same number of entries.
"""

import argparse
import glob
import math
from pathlib import Path
from typing import List, Tuple

import pandas as pd
import matplotlib.pyplot as plt


def expand_glob(pattern: str) -> List[Path]:
    matches = glob.glob(pattern)
    return [Path(m) for m in sorted(matches)]


def load_latencies(pattern: str) -> List[float]:
    files = expand_glob(pattern)
    if not files:
        raise SystemExit(f"No files matched: {pattern!r}")
    vals = []
    for f in files:
        df = pd.read_csv(f)
        col = _pick_col(df)
        vals.extend(pd.to_numeric(df[col], errors="coerce").dropna().tolist())
    if not vals:
        raise SystemExit(f"No numeric latencies found for pattern: {pattern!r}")
    return vals


def _pick_col(df: pd.DataFrame) -> str:
    for c in ["latency_ms", "response_time_ms", "response_time", "latency", "duration_ms"]:
        if c in df.columns:
            return c
    numeric = [c for c in df.columns if pd.api.types.is_numeric_dtype(df[c])]
    if numeric:
        return numeric[0]
    raise ValueError(f"No numeric column found. Columns: {list(df.columns)}")


def percentile(sorted_vals: List[float], p: float) -> float:
    if not sorted_vals:
        raise ValueError("Empty list.")
    n = len(sorted_vals)
    if p <= 0:
        return float(sorted_vals[0])
    if p >= 100:
        return float(sorted_vals[-1])
    r = (p / 100.0) * (n - 1)
    lo, hi = int(math.floor(r)), int(math.ceil(r))
    if lo == hi:
        return float(sorted_vals[lo])
    return float(sorted_vals[lo] * (1 - (r - lo)) + sorted_vals[hi] * (r - lo))


def tail_stats(vals: List[float]) -> dict:
    s = sorted(vals)
    return {
        "count": len(s),
        "p50_ms": percentile(s, 50),
        "p90_ms": percentile(s, 90),
        "p95_ms": percentile(s, 95),
        "p99_ms": percentile(s, 99),
        "min_ms": float(s[0]),
        "max_ms": float(s[-1]),
        "mean_ms": float(sum(s) / len(s)),
    }


def cdf_xy(vals: List[float]) -> Tuple[List[float], List[float]]:
    s = sorted(vals)
    n = len(s)
    return s, [(i + 1) / n for i in range(n)]


def main():
    ap = argparse.ArgumentParser(description="Compare latency CDFs across multiple scenarios.")
    ap.add_argument("--scenarios", nargs="+", required=True, help="Human-readable scenario labels.")
    ap.add_argument("--inputs", nargs="+", required=True, help="Glob patterns, one per scenario.")
    ap.add_argument("--outdir", default="out", help="Output directory.")
    ap.add_argument("--title", default="Latency Comparison", help="Plot title.")
    args = ap.parse_args()

    if len(args.scenarios) != len(args.inputs):
        raise SystemExit("--scenarios and --inputs must have the same number of entries.")

    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    rows = []
    fig, ax = plt.subplots(figsize=(9, 5))
    colors = plt.rcParams["axes.prop_cycle"].by_key()["color"]

    for i, (label, pattern) in enumerate(zip(args.scenarios, args.inputs)):
        vals = load_latencies(pattern)
        stats = tail_stats(vals)
        rows.append({"scenario": label, **stats})

        x, y = cdf_xy(vals)
        ax.plot(x, y, label=label, color=colors[i % len(colors)])

    ax.set_xlabel("Latency (ms)")
    ax.set_ylabel("CDF")
    ax.set_title(args.title)
    ax.grid(True, which="both", linestyle="--", linewidth=0.5)
    ax.legend()
    fig.tight_layout()

    cdf_path = outdir / "comparison_cdf.png"
    fig.savefig(cdf_path, dpi=200)
    print(f"Saved CDF plot: {cdf_path}")

    df = pd.DataFrame(rows)
    table_path = outdir / "comparison_table.csv"
    df.to_csv(table_path, index=False)
    print(f"Saved comparison table: {table_path}")

    cols = ["scenario", "count", "p50_ms", "p90_ms", "p95_ms", "p99_ms", "mean_ms"]
    print("\nScenario comparison (ms):")
    print(df[cols].to_string(index=False))


if __name__ == "__main__":
    main()
