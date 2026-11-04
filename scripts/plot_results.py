#!/usr/bin/env python3
import pathlib
import sys
import matplotlib.pyplot as plt
import numpy as np

target_dir = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else pathlib.Path("benchmarks/zen5_epyc_9275f")
cpu_name = "AMD EPYC 9275F 24-Core Processor"

workloads = [
    "C++ SIMD Dot-Product\n(L2 Resident, GFLOPS)",
    "SVT-AV1 v2.3.0\n(4K Encode, FPS)",
    "ClickHouse Vector+Filter\n(1M Rows, QPS)"
]
avx2_raw = [29.32, 22.39, 55.97]
avx512_raw = [58.81, 23.03, 66.08]
units = ["GFLOPS", "FPS", "QPS"]

inst_avx2 = [9.90, 603.80, 30.96]
inst_avx512 = [4.95, 573.97, 11.57]

speedups = [a512 / a2 for a2, a512 in zip(avx2_raw, avx512_raw)]
inst_ratios = [(a512 / a2) * 100.0 for a2, a512 in zip(inst_avx2, inst_avx512)]

plt.style.use("dark_background")
fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 6), dpi=300)
fig.patch.set_facecolor("#0d1117")
for ax in (ax1, ax2):
    ax.set_facecolor("#161b22")
    ax.grid(axis="y", linestyle="--", alpha=0.25, color="#8b949e")
    ax.set_axisbelow(True)

x = np.arange(len(workloads))
width = 0.36

b1_avx2 = ax1.bar(x - width/2, [1.0]*len(x), width, label="AVX2 (256-bit, clearcpuid Masked)", color="#3b82f6", edgecolor="#1d4ed8")
b1_512  = ax1.bar(x + width/2, speedups, width, label="AVX-512 (512-bit Native)", color="#10b981", edgecolor="#047857")

ax1.set_title("Normalized Throughput Speedup (Higher = Better)", fontsize=12, fontweight="bold", pad=14, color="#f0f6fc")
ax1.set_ylabel("Relative Throughput vs. AVX2 (x)", fontsize=11, color="#c9d1d9")
ax1.set_xticks(x)
ax1.set_xticklabels(workloads, fontsize=10, color="#e6edf3")
ax1.set_ylim(0, 2.45)
ax1.axhline(1.0, color="#8b949e", linestyle=":", linewidth=1)
ax1.legend(loc="upper right", frameon=True, facecolor="#0d1117", edgecolor="#30363d")

for bar2, bar5, raw2, raw5, sp, u in zip(b1_avx2, b1_512, avx2_raw, avx512_raw, speedups, units):
    ax1.text(bar2.get_x() + bar2.get_width()/2, bar2.get_height() + 0.04, f"1.00x\n({raw2:.1f} {u})", ha="center", va="bottom", fontsize=8.5, color="#93c5fd")
    ax1.text(bar5.get_x() + bar5.get_width()/2, bar5.get_height() + 0.04, f"{sp:.2f}x\n({raw5:.1f} {u})", ha="center", va="bottom", fontsize=9, fontweight="bold", color="#6ee7b7")

b2_avx2 = ax2.bar(x - width/2, [100.0]*len(x), width, label="AVX2 Baseline (100%)", color="#6366f1", edgecolor="#4338ca")
b2_512  = ax2.bar(x + width/2, inst_ratios, width, label="AVX-512 Retired Instructions (%)", color="#f59e0b", edgecolor="#b45309")

ax2.set_title("Retired CPU Instructions (Lower = Fewer Instructions Executed)", fontsize=12, fontweight="bold", pad=14, color="#f0f6fc")
ax2.set_ylabel("Instructions Retired (% of AVX2)", fontsize=11, color="#c9d1d9")
ax2.set_xticks(x)
ax2.set_xticklabels(workloads, fontsize=10, color="#e6edf3")
ax2.set_ylim(0, 125)
ax2.axhline(100.0, color="#8b949e", linestyle=":", linewidth=1)
ax2.legend(loc="upper right", frameon=True, facecolor="#0d1117", edgecolor="#30363d")

for bar2, bar5, i2, i5, ratio in zip(b2_avx2, b2_512, inst_avx2, inst_avx512, inst_ratios):
    delta = ratio - 100.0
    ax2.text(bar2.get_x() + bar2.get_width()/2, bar2.get_height() + 2, f"100%\n({i2:.1f}B inst)", ha="center", va="bottom", fontsize=8.5, color="#a5b4fc")
    ax2.text(bar5.get_x() + bar5.get_width()/2, bar5.get_height() + 2, f"{delta:.1f}%\n({i5:.1f}B inst)", ha="center", va="bottom", fontsize=9, fontweight="bold", color="#fcd34d")

fig.suptitle(f"Filo512 Benchmark: {cpu_name} (Zen 5 Turin - Native 512-bit FMA)", fontsize=14, fontweight="bold", color="#ffffff", y=0.98)
plt.tight_layout(rect=[0, 0, 1, 0.93])

png_path = target_dir / "zen5_avx512_vs_avx2.png"
svg_path = target_dir / "zen5_avx512_vs_avx2.svg"
plt.savefig(png_path, facecolor=fig.get_facecolor(), edgecolor="none")
plt.savefig(svg_path, facecolor=fig.get_facecolor(), edgecolor="none")
print(f"[OK] Saved charts to {png_path} and {svg_path}")
