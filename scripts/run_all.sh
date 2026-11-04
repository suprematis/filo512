#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
LABEL="${1:-avx512_on}"
export DRY_RUN="${DRY_RUN:-false}"

echo "=========================================================="
echo " Filo512 Benchmark Suite - Pass: ${LABEL} (DRY_RUN=${DRY_RUN})"
echo "=========================================================="

# 1. Preflight environment & CPU flag capture (tagged by pass label)
./scripts/00_preflight_env.sh "$LABEL"

# 2. Run C++ Microbenchmark & SVT-AV1 on Pass 1 (instruction-flag controlled)
if [ "$LABEL" = "avx512_on" ]; then
    ./workloads/microbench/bench_micro.sh
    ./workloads/svt_av1/bench_svt_av1.sh
fi

# 3. Run ClickHouse Vector/Filter Benchmark (dynamic dispatch tested in BOTH passes)
./workloads/clickhouse/bench_clickhouse.sh "$LABEL"

# 4. Generate/update Markdown summary if both ClickHouse pass logs exist
if [ -f "./results/clickhouse_avx512_on.log" ] && [ -f "./results/clickhouse_avx512_off.log" ]; then
    python3 ./scripts/parse_results.py
fi
