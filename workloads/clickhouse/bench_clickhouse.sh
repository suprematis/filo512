#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
LABEL="${1:-avx512_on}"
OUT_DIR="../../results"
mkdir -p "$OUT_DIR"

ITERS=15
ROWS=2000000
if [ "${DRY_RUN:-false}" = "true" ]; then
    ITERS=2
    ROWS=200000
fi

if [ ! -f ./clickhouse ]; then
    echo "Downloading official static ClickHouse binary..."
    curl -fsSL https://clickhouse.com/ | sh
fi

SQL_QUERY="CREATE TABLE vectors ENGINE = Memory AS SELECT number AS id, arrayMap(x -> toFloat32(randCanonical()), range(256)) AS vec, toString(intHash64(number)) AS tag FROM numbers_mt(${ROWS});"
for ((i=1; i<=ITERS; i++)); do
    SQL_QUERY+=" SELECT id, cosineDistance(vec, arrayMap(x -> toFloat32(0.25), range(256))) AS dist FROM vectors WHERE tag LIKE '%99%' ORDER BY dist ASC LIMIT 50 FORMAT Null;"
done

echo ">>> [ClickHouse] Running Vector + Batch Filter Benchmark ($LABEL, ${ITERS} iters, ${ROWS} rows)..."
perf stat -e cycles,instructions \
    ./clickhouse local --time --queries-file <(echo "$SQL_QUERY") \
    2>&1 | tee "${OUT_DIR}/clickhouse_${LABEL}.log"
