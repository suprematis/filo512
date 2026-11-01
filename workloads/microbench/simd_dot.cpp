#include <iostream>
#include <vector>
#include <chrono>

__attribute__((noinline))
float dot_product(const float* __restrict__ a, const float* __restrict__ b, size_t n) {
    float sum = 0.0f;
    #pragma omp simd reduction(+:sum)
    for (size_t i = 0; i < n; ++i) {
        sum += a[i] * b[i];
    }
    return sum;
}

int main() {
    const size_t N = 64 * 1024 * 1024; // 64M floats (256 MB per vector)
    const int ITERS = 100;
    std::vector<float> a(N, 1.0001f);
    std::vector<float> b(N, 0.9999f);

    volatile float sink = dot_product(a.data(), b.data(), N);

    auto start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < ITERS; ++i) {
        sink = dot_product(a.data(), b.data(), N);
    }
    auto end = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double> diff = end - start;

    double gflops = (2.0 * N * ITERS) / (diff.count() * 1e9);
    std::cout << "Elapsed: " << diff.count() << " s | GFLOPS: " << gflops << " | sink: " << sink << "\n";
    return 0;
}
