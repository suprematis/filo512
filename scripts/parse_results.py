#!/usr/bin/env python3
import pathlib
import re

results_dir = pathlib.Path(__file__).resolve().parent.parent / "results"
summary_file = results_dir / "SUMMARY.md"

def extract_regex(file_path: pathlib.Path, pattern: str, default: str = "N/A") -> str:
    if not file_path.exists():
        return default
    text = file_path.read_text(errors="ignore")
    m = re.search(pattern, text, re.MULTILINE)
    return m.group(1).strip() if m else default

env_on = results_dir / "env_avx512_on.txt"
env_off = results_dir / "env_avx512_off.txt"

cpu_model = extract_regex(env_on, r"Model name:\s*(.+)")
if cpu_model == "N/A":
    cpu_model = extract_regex(results_dir / "cpu_model.txt", r":\s*(.+)")

avx_flags = extract_regex(env_on, r"=== Active AVX-512 Flags ===\s*\n(.+)")
if avx_flags == "N/A":
    avx_flags = extract_regex(results_dir / "avx512_flags.txt", r"(.+)")

avx_off_status = extract_regex(env_off, r"=== Active AVX-512 Flags ===\s*\n(.+)")

def extract_clickhouse_metric(file_path: pathlib.Path) -> tuple[str, str]:
    qps = extract_regex(file_path, r"(?:Queries per second|QPS):\s*([0-9.]+)")
    if qps != "N/A":
        return qps, "QPS"
    elapsed = extract_regex(file_path, r"([0-9.]+)\s+seconds time elapsed")
    if elapsed != "N/A":
        return elapsed, "sec"
    return "N/A", "QPS"

ch_off_val, ch_unit = extract_clickhouse_metric(results_dir / "clickhouse_avx512_off.log")
ch_on_val, _ = extract_clickhouse_metric(results_dir / "clickhouse_avx512_on.log")
ch_label = f"ClickHouse Vector+Filter ({ch_unit})"

rows = [
    (
        "C++ SIMD Dot-Product (GFLOPS)",
        extract_regex(results_dir / "micro_avx2.log", r"GFLOPS:\s*([0-9.]+)"),
        extract_regex(results_dir / "micro_avx512.log", r"GFLOPS:\s*([0-9.]+)"),
        extract_regex(results_dir / "micro_avx2.log", r"([0-9,]+)\s+instructions"),
        extract_regex(results_dir / "micro_avx512.log", r"([0-9,]+)\s+instructions"),
        True,
    ),
    (
        "SVT-AV1 4K Encode (FPS)",
        extract_regex(results_dir / "svt_av1_avx2.log", r"Average Speed:\s*([0-9.]+)\s*fps"),
        extract_regex(results_dir / "svt_av1_avx512.log", r"Average Speed:\s*([0-9.]+)\s*fps"),
        extract_regex(results_dir / "svt_av1_avx2.log", r"([0-9,]+)\s+instructions"),
        extract_regex(results_dir / "svt_av1_avx512.log", r"([0-9,]+)\s+instructions"),
        True,
    ),
    (
        ch_label,
        ch_off_val,
        ch_on_val,
        extract_regex(results_dir / "clickhouse_avx512_off.log", r"([0-9,]+)\s+instructions"),
        extract_regex(results_dir / "clickhouse_avx512_on.log", r"([0-9,]+)\s+instructions"),
        (ch_unit == "QPS"),
    ),
]

md = [
    "# Filo512: AMD AVX-512 vs. AVX2 Benchmark Summary",
    f"- **Processor:** `{cpu_model}`",
    f"- **Pass 1 Active AVX-512 Subsets:** `{avx_flags}`",
    f"- **Pass 2 Kernel Mask Status:** `{avx_off_status}`\n",
    "| Workload Metric | AVX2 (256-bit) | AVX-512 (512-bit) | Speedup | Instructions (AVX2) | Instructions (AVX-512) |",
    "| :--- | :---: | :---: | :---: | :---: | :---: |",
]

for name, v_avx2, v_avx512, inst_avx2, inst_avx512, higher_is_better in rows:
    try:
        f_avx2 = float(v_avx2)
        f_avx512 = float(v_avx512)
        ratio = (f_avx512 / f_avx2) if higher_is_better else (f_avx2 / f_avx512)
        speedup = f"{ratio:.2f}x"
    except Exception:
        speedup = "N/A"
    md.append(f"| **{name}** | {v_avx2} | {v_avx512} | **{speedup}** | {inst_avx2} | {inst_avx512} |")

output = "\n".join(md) + "\n"
summary_file.write_text(output)
print("\n" + output)
