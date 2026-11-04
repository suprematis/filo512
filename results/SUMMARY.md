# Filo512: AMD AVX-512 vs. AVX2 Benchmark Summary
- **Processor:** `N/A`
- **Active AVX-512 Subsets:** `N/A`

| Workload Metric | AVX2 (256-bit) | AVX-512 (512-bit) | Speedup | Instructions (AVX2) | Instructions (AVX-512) |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **C++ SIMD Dot-Product (GFLOPS)** | 12.3436 | 12.4475 | **1.01x** | 5,058,593,480 | 2,893,129,364 |
| **SVT-AV1 4K Encode (FPS)** | 9.969 | 9.968 | **1.00x** | 896,583,783,162 | 896,622,477,936 |
| **ClickHouse Vector+Filter (QPS)** | N/A | N/A | **N/A** | 10,708,431,854 | 91,974,302,890 |
