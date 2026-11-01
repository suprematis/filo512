#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
OUT_DIR="../../results"
mkdir -p "$OUT_DIR"

FRAMES=120
if [ "${DRY_RUN:-false}" = "true" ]; then
    FRAMES=20
fi

Y4M_FILE="test_4k.y4m"
if [ ! -f "$Y4M_FILE" ]; then
    echo "Generating synthetic 4K (3840x2160) ${FRAMES}-frame YUV420p test stream via ffmpeg..."
    ffmpeg -hide_banner -loglevel error -f lavfi -i testsrc2=size=3840x2160:rate=60 -frames:v "$FRAMES" -pix_fmt yuv420p "$Y4M_FILE"
fi

for ISA in avx2 avx512; do
    echo ">>> [SVT-AV1] Running 4K Encode (${FRAMES} frames) with --asm ${ISA}..."
    perf stat -e cycles,instructions \
        SvtAv1EncApp \
        -i "$Y4M_FILE" \
        -b "/dev/null" \
        --preset 6 \
        --crf 30 \
        --asm "$ISA" \
        2>&1 | tee "${OUT_DIR}/svt_av1_${ISA}.log"
done
