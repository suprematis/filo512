#!/usr/bin/env bash
set -euo pipefail
OUT_DIR="$(cd "$(dirname "$0")/.." && pwd)/results"
mkdir -p "$OUT_DIR"

echo "=== [1/6] Installing Required Packages (Ubuntu 24.04) ==="
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -qq
sudo apt-get install -y -qq \
  build-essential g++-14 gcc-14 cmake ninja-build nasm yasm \
  git curl wget aria2 jq numactl hwloc dmidecode ipmitool python3 \
  svt-av1 ffmpeg linux-tools-common linux-tools-generic "linux-tools-$(uname -r)" || true

echo "=== [2/6] Locking CPU Frequency Governor to Performance ==="
if [ -d /sys/devices/system/cpu/cpu0/cpufreq ]; then
    for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo performance | sudo tee "$gov" > /dev/null
    done
fi

echo "=== [3/6] Setting THP to madvise & Perf Paranoid to -1 ==="
echo madvise | sudo tee /sys/kernel/mm/transparent_hugepage/enabled > /dev/null
sudo sysctl -w kernel.perf_event_paranoid=-1 > /dev/null

echo "=== [4/6] Auditing Populated DDR5 Memory Channels ==="
sudo dmidecode -t memory | grep -E "Size:|Configured Memory Speed:|Locator:" | grep -B1 -A1 "GB" > "${OUT_DIR}/memory_channels.txt" || true

echo "=== [5/6] Capturing CPU & NUMA Topology ==="
lscpu > "${OUT_DIR}/lscpu.txt"
numactl --hardware > "${OUT_DIR}/numa_topology.txt" || true
grep -m1 'model name' /proc/cpuinfo | tee "${OUT_DIR}/cpu_model.txt"

echo "=== [6/6] Auditing Active AVX-512 Feature Flags ==="
grep -m1 -o 'avx512[^ ]*' /proc/cpuinfo | sort -u | tr '\n' ' ' | tee "${OUT_DIR}/avx512_flags.txt" || echo "NONE (AVX-512 Masked)"
echo ""
