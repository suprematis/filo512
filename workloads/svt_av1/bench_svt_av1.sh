#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
OUT_DIR="../../results"
mkdir -p "$OUT_DIR"

FRAMES=120
if [ "${DRY_RUN:-false}" = "true" ]; then
    FRAMES=20
fi

# Build SVT-AV1 v2.3.0 with -DBUILD_AVX512=ON if not already built locally
SVT_BIN="./SvtAv1EncApp"
if [ ! -x "$SVT_BIN" ]; then
    echo ">>> [SVT-AV1] Building SVT-AV1 v2.3.0 from source with -DBUILD_AVX512=ON..."
    sudo apt-get update -qq && sudo apt-get install -y -qq cmake ninja-build nasm yasm build-essential git
    rm -rf SVT-AV1-src
    git clone --depth 1 --branch v2.3.0 https://gitlab.com/AOMediaCodec/SVT-AV1.git SVT-AV1-src
    cmake -S SVT-AV1-src -B SVT-AV1-src/build -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_APPS=ON \
        -DBUILD_DEC=OFF \
        -DBUILD_AVX512=ON
    ninja -C SVT-AV1-src/build SvtAv1EncApp
    cp SVT-AV1-src/Bin/Release/SvtAv1EncApp "$SVT_BIN"
    chmod +x "$SVT_BIN"
fi

Y4M_FILE="test_4k.y4m"
if [ ! -f "$Y4M_FILE" ]; then
    echo "Generating synthetic 4K (3840x2160) ${FRAMES}-frame YUV420p test stream via ffmpeg..."
    ffmpeg -hide_banner -loglevel error -f lavfi -i testsrc2=size=3840x2160:rate=60 -frames:v "$FRAMES" -pix_fmt yuv420p "$Y4M_FILE"
fi

for ISA in avx2 avx512; do
    echo ">>> [SVT-AV1] Running 4K Encode (${FRAMES} frames) with --asm ${ISA}..."
    perf stat -e cycles,instructions \
        "$SVT_BIN" \
        -i "$Y4M_FILE" \
        -b "/dev/null" \
        --preset 6 \
        --crf 30 \
        --asm "$ISA" \
        2>&1 | tee "${OUT_DIR}/svt_av1_${ISA}.log"
done
