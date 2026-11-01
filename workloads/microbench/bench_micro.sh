#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
OUT_DIR="../../results"
mkdir -p "$OUT_DIR"

CXX_BIN="g++-14"
if ! command -v "$CXX_BIN" &>/dev/null; then CXX_BIN="g++"; fi

ARCH_FLAG="-march=znver5"
if ! $CXX_BIN $ARCH_FLAG -E -x c++ /dev/null >/dev/null 2>&1; then
    ARCH_FLAG="-march=znver4"
fi

echo "=== [Microbench] Compiling with $CXX_BIN ($ARCH_FLAG) ==="
$CXX_BIN -O3 -ffast-math -fopenmp-simd $ARCH_FLAG -mno-avx512f simd_dot.cpp -o simd_avx2
$CXX_BIN -O3 -ffast-math -fopenmp-simd $ARCH_FLAG -mprefer-vector-width=512 simd_dot.cpp -o simd_avx512

echo ">>> Running C++ SIMD Dot-Product: AVX2 (256-bit YMM)..."
taskset -c 0 perf stat -e cycles,instructions ./simd_avx2 2>&1 | tee "${OUT_DIR}/micro_avx2.log"

echo ">>> Running C++ SIMD Dot-Product: AVX-512 (512-bit ZMM)..."
taskset -c 0 perf stat -e cycles,instructions ./simd_avx512 2>&1 | tee "${OUT_DIR}/micro_avx512.log"
