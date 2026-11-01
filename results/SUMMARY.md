# Filo512: AMD AVX-512 vs. AVX2 Benchmark Summary
- **Processor:** `AMD EPYC 4244P 6-Core Processor`
- **Active AVX-512 Subsets:** `avx512_bf16 avx512_bitalg avx512bw avx512cd avx512dq avx512f avx512ifma avx512vbmi avx512_vbmi2 avx512vl avx512_vnni avx512_vpopcntdq`

| Workload Metric | AVX2 (256-bit) | AVX-512 (512-bit) | Speedup | Instructions (AVX2) | Instructions (AVX-512) |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **C++ SIMD Dot-Product (GFLOPS)** | 11.8344 | 11.4984 | **0.97x** | 5,081,673,405 | 2,931,272,688 |
| **SVT-AV1 4K Encode (FPS)** | 4.564 | 4.750 | **1.04x** | 175,976,502,115 | 175,676,259,326 |
| **ClickHouse Vector+Filter (QPS)** | N/A | N/A | **N/A** | 1,268,149,527 | 998,221,691 |
