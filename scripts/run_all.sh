#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PASS_LABEL="${1:-avx512_on}"

echo "========================================================"
echo " Starting Filo512 Benchmark Suite Pass: ${PASS_LABEL}"
echo "========================================================"

"${ROOT_DIR}/scripts/00_preflight_env.sh"

# Run single-binary A/B workloads when AVX-512 is active on the host
if grep -q "avx512f" /proc/cpuinfo; then
    "${ROOT_DIR}/workloads/microbench/bench_micro.sh"
    "${ROOT_DIR}/workloads/svt_av1/bench_svt_av1.sh"
fi

# Run ClickHouse under the current kernel CPUID state (avx512_on or avx512_off)
"${ROOT_DIR}/workloads/clickhouse/bench_clickhouse.sh" "${PASS_LABEL}"

python3 "${ROOT_DIR}/scripts/parse_results.py" || true

echo "========================================================"
echo " Pass Complete! Summary written to results/SUMMARY.md"
echo "========================================================"
