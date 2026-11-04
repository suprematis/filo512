#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
LABEL="${1:-avx512_on}"
OUT_DIR="./results"
mkdir -p "$OUT_DIR"
OUT_FILE="${OUT_DIR}/env_${LABEL}.txt"

echo "[1/6] Installing required packages..."
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -qq
KERNEL_REL=$(uname -r)
sudo apt-get install -y -qq build-essential g++-14 git curl jq python3 ffmpeg svt-av1 \
    linux-tools-common "linux-tools-${KERNEL_REL}" || \
    sudo apt-get install -y -qq build-essential g++-14 git curl jq python3 ffmpeg svt-av1 linux-tools-generic

echo "[2/6] Configuring CPU frequency governor to performance..."
for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    [ -f "$gov" ] && echo performance | sudo tee "$gov" >/dev/null || true
done

echo "[3/6] Capturing hardware & kernel telemetry to ${OUT_FILE}..."
{
    echo "=== Filo512 Environment Audit (${LABEL}) ==="
    echo "Timestamp (UTC): $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "Hostname: $(hostname)"
    echo "Kernel: $(uname -a)"
    echo "Kernel cmdline: $(cat /proc/cmdline)"
    echo ""
    echo "=== lscpu Summary ==="
    lscpu | grep -E "Architecture|Model name|Socket|Thread|Core|CPU\(s\)|MHz|L1|L2|L3"
    echo ""
    echo "=== Active AVX-512 Flags ==="
    AVX_FLAGS=$(grep -m1 '^flags' /proc/cpuinfo | tr ' ' '\n' | grep '^avx512' | tr '\n' ' ')
    if [ -n "$AVX_FLAGS" ]; then
        echo "$AVX_FLAGS"
    else
        echo "NONE (AVX-512 Masked)"
    fi
} | tee "$OUT_FILE"
