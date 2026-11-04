#include <iostream>
#include <vector>
#include <chrono>
#include <iomanip>

// 65,536 floats * 4 bytes = 256 KB per vector (512 KB total working set -> fits inside 1 MB L2 cache per core)
constexpr size_t N = 65536;
constexpr size_t ITERS = 200000;

__attribute__((noinline))
float dot_product(const float* __restrict__ a, const float* __restrict__ b, size_t n, float scale) {
    float sum = 0.0f;
    #pragma omp simd reduction(+:sum) aligned(a, b: 64)
    for (size_t i = 0; i < n; ++i) {
        sum += (a[i] * scale) * b[i];
    }
    return sum;
}

int main() {
    alignas(64) std::vector<float> a(N, 1.0001f);
    alignas(64) std::vector<float> b(N, 0.9999f);

    // Warmup cache and frequency
    volatile float sink = 0.0f;
    for (size_t i = 0; i < 1000; ++i) {
        sink += dot_product(a.data(), b.data(), N, 1.0f);
    }

    auto start = std::chrono::high_resolution_clock::now();
    float total = 0.0f;
    for (size_t iter = 0; iter < ITERS; ++iter) {
        total += dot_product(a.data(), b.data(), N, 1.0f + static_cast<float>(iter) * 1e-7f);
    }
    auto end = std::chrono::high_resolution_clock::now();
    sink = total;

    double elapsed = std::chrono::duration<double>(end - start).count();
    // 3 FLOPs per element (mul + fma)
    double total_flops = static_cast<double>(N) * static_cast<double>(ITERS) * 3.0;
    double gflops = (total_flops / elapsed) / 1e9;

    std::cout << std::fixed << std::setprecision(4);
    std::cout << "Elapsed_Sec: " << elapsed << "\n";
    std::cout << "GFLOPS: " << gflops << "\n";
    std::cout << "Checksum: " << sink << "\n";
    return 0;
}
