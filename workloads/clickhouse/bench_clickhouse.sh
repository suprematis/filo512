#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
LABEL="${1:-avx512_on}"
OUT_DIR="../../results"
mkdir -p "$OUT_DIR"

if [ ! -f ./clickhouse ]; then
    echo "Downloading official static ClickHouse binary..."
    curl -fsSL https://clickhouse.com/ | sh
fi

echo ">>> [ClickHouse] Running Vector + Batch Filter Benchmark ($LABEL)..."
perf stat -e cycles,instructions \
    ./clickhouse local --query "
        CREATE TABLE vectors ENGINE = Memory AS
        SELECT
            number AS id,
            arrayMap(x -> toFloat32(randCanonical()), range(256)) AS vec,
            toString(intHash64(number)) AS tag
        FROM numbers_mt(2000000);

        SELECT
            id,
            cosineDistance(vec, arrayMap(x -> toFloat32(0.25), range(256))) AS dist
        FROM vectors
        WHERE tag LIKE '%99%'
        ORDER BY dist ASC
        LIMIT 50
        FORMAT Null;
    " --benchmark --iterations 15 2>&1 | tee "${OUT_DIR}/clickhouse_${LABEL}.log"
