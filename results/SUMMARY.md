# Filo512: AMD AVX-512 vs. AVX2 Benchmark Summary
- **Processor:** `N/A`
- **Active AVX-512 Subsets:** `N/A`

| Workload Metric | AVX2 (256-bit) | AVX-512 (512-bit) | Speedup | Instructions (AVX2) | Instructions (AVX-512) |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **C++ SIMD Dot-Product (GFLOPS)** | 9.39194 | 9.35403 | **1.00x** | 5,029,306,324 | 2,879,949,390 |
| **SVT-AV1 4K Encode (FPS)** | 6.559 | 6.447 | **0.98x** | 175,146,426,495 | 175,157,357,661 |
| **ClickHouse Vector+Filter (QPS)** | N/A | N/A | **N/A** | 1,270,033,791 | 81,369,843,804 |
