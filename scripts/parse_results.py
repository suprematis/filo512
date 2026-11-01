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

cpu_model = extract_regex(results_dir / "cpu_model.txt", r":\s*(.+)")
avx_flags = extract_regex(results_dir / "avx512_flags.txt", r"(.+)")

rows = [
    (
        "C++ SIMD Dot-Product (GFLOPS)",
        extract_regex(results_dir / "micro_avx2.log", r"GFLOPS:\s*([0-9.]+)"),
        extract_regex(results_dir / "micro_avx512.log", r"GFLOPS:\s*([0-9.]+)"),
        extract_regex(results_dir / "micro_avx2.log", r"([0-9,]+)\s+instructions"),
        extract_regex(results_dir / "micro_avx512.log", r"([0-9,]+)\s+instructions"),
    ),
    (
        "SVT-AV1 4K Encode (FPS)",
        extract_regex(results_dir / "svt_av1_avx2.log", r"Average Speed:\s*([0-9.]+)\s*fps"),
        extract_regex(results_dir / "svt_av1_avx512.log", r"Average Speed:\s*([0-9.]+)\s*fps"),
        extract_regex(results_dir / "svt_av1_avx2.log", r"([0-9,]+)\s+instructions"),
        extract_regex(results_dir / "svt_av1_avx512.log", r"([0-9,]+)\s+instructions"),
    ),
    (
        "ClickHouse Vector+Filter (QPS)",
        extract_regex(results_dir / "clickhouse_avx512_off.log", r"Queries per second:\s*([0-9.]+)"),
        extract_regex(results_dir / "clickhouse_avx512_on.log", r"Queries per second:\s*([0-9.]+)"),
        extract_regex(results_dir / "clickhouse_avx512_off.log", r"([0-9,]+)\s+instructions"),
        extract_regex(results_dir / "clickhouse_avx512_on.log", r"([0-9,]+)\s+instructions"),
    ),
]

md = [
    "# Filo512: AMD AVX-512 vs. AVX2 Benchmark Summary",
    f"- **Processor:** `{cpu_model}`",
    f"- **Active AVX-512 Subsets:** `{avx_flags}`\n",
    "| Workload Metric | AVX2 (256-bit) | AVX-512 (512-bit) | Speedup | Instructions (AVX2) | Instructions (AVX-512) |",
    "| :--- | :---: | :---: | :---: | :---: | :---: |",
]

for name, v_avx2, v_avx512, inst_avx2, inst_avx512 in rows:
    try:
        speedup = f"{float(v_avx512) / float(v_avx2):.2f}x"
    except Exception:
        speedup = "N/A"
    md.append(f"| **{name}** | {v_avx2} | {v_avx512} | **{speedup}** | {inst_avx2} | {inst_avx512} |")

output = "\n".join(md) + "\n"
summary_file.write_text(output)
print("\n" + output)
