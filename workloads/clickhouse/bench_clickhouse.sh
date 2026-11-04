#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
LABEL="${1:-avx512_on}"
OUT_DIR="../../results"
mkdir -p "$OUT_DIR"

ITERS=15
ROWS=1000000
if [ "${DRY_RUN:-false}" = "true" ]; then
    ITERS=3
    ROWS=200000
fi

if [ ! -f ./clickhouse ]; then
    echo "Downloading official static ClickHouse binary..."
    curl -fsSL https://clickhouse.com/ | sh
fi

# Warm up / force self-extraction of the ClickHouse binary BEFORE running perf stat!
./clickhouse local --version >/dev/null 2>&1 || true

# Build SQL script: Query 1 creates the in-memory table; Queries 2..N+1 run full-scan cosineDistance + filter
SQL_FILE=$(mktemp /tmp/ch_bench_XXXXXX.sql)
echo "CREATE TABLE vectors ENGINE = Memory AS SELECT number AS id, arrayMap(x -> toFloat32(number % 13 + x * 0.01), range(256)) AS vec, intHash64(number) AS h FROM numbers_mt(${ROWS});" > "$SQL_FILE"

for ((i=1; i<=ITERS; i++)); do
    OFFSET=$(awk "BEGIN {printf \"%.3f\", $i * 0.01}")
    echo "SELECT id, cosineDistance(vec, arrayMap(x -> toFloat32(${OFFSET}), range(256))) AS dist FROM vectors WHERE dist < 0.9999 AND bitAnd(h, 1) = 0 ORDER BY dist ASC LIMIT 50 FORMAT Null;" >> "$SQL_FILE"
done

echo ">>> [ClickHouse] Running Vector + Batch Filter Benchmark ($LABEL, ${ITERS} iters, ${ROWS} rows)..."
RAW_LOG="${OUT_DIR}/clickhouse_${LABEL}.log"
perf stat -e cycles,instructions \
    ./clickhouse local --time --queries-file "$SQL_FILE" \
    > "$RAW_LOG" 2>&1

rm -f "$SQL_FILE"

# Compute exact QPS from the SELECT query execution times (lines 2..ITERS+1 of timing output)
QPS=$(awk -v iters="$ITERS" '
  /^[0-9]+\.[0-9]+$/ {
    count++
    if (count > 1) { sum += $1; q++ }
  }
  END {
    if (q > 0 && sum > 0) printf "%.2f", q / sum;
    else print "N/A"
  }
' "$RAW_LOG")

echo "Queries per second: ${QPS}" | tee -a "$RAW_LOG"
cat "$RAW_LOG"
