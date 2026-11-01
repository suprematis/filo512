# Filo512: AMD Zen 4 / Zen 5 AVX-512 Bare-Metal Benchmark Suite

Reproducible bare-metal benchmark suite comparing **AVX-512 (512-bit ZMM)** vs. **AVX2 (256-bit YMM)** across:
1. **C++ SIMD FP32/VNNI Microbenchmarks** (-march=znver5 / -march=znver4)
2. **SVT-AV1 4K Video Encoding** (--asm avx512 vs --asm avx2)
3. **ClickHouse Vector Search & Batch Filtering** (clearcpuid=avx512f toggle)

## Directory Structure
    filo512/
    ├── terraform/
    │   ├── latitude/                   # Latitude.sh IaC (m4.metal.small & f4.metal.large EPYC 9275F)
    │   └── cherry/                     # Cherry Servers IaC (EPYC 9575F 768GB)
    ├── scripts/
    │   ├── 00_preflight_env.sh         # Locks performance governor, THP madvise, audits 12-ch DDR5 & CPUID
    │   ├── 01_toggle_kernel_avx512.sh  # Toggles clearcpuid=avx512f in GRUB for OS-wide AVX-512 masking
    │   ├── 02_redfish_bios_audit.sh    # Dumps Out-of-Band BMC Redfish BIOS attributes
    │   ├── run_all.sh                  # Master execution harness
    │   └── parse_results.py            # Parses logs in results/ into a GitHub Markdown summary table
    ├── workloads/
    │   ├── microbench/                 # C++ auto-vectorized 256-bit vs 512-bit dot-product
    │   ├── svt_av1/                    # SVT-AV1 4K Y4M encode harness (--asm avx2 vs --asm avx512)
    │   └── clickhouse/                 # ClickHouse local vector cosineDistance + batch filter benchmark
    └── results/                        # Output telemetry logs & generated SUMMARY.md

## Quick Execution Workflow on the Server
    # Pass 1: Run everything with native AVX-512 enabled
    ./scripts/run_all.sh avx512_on

    # Optional Pass 2: Mask AVX-512 at the kernel level for ClickHouse A/B comparison
    ./scripts/01_toggle_kernel_avx512.sh disable
    sudo reboot

    # After reboot:
    ./scripts/run_all.sh avx512_off
    python3 ./scripts/parse_results.py
