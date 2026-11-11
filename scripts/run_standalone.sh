#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

export DRY_RUN="${DRY_RUN:-false}"
STATE_DIR="$REPO_ROOT/.state"
RESULTS_DIR="$REPO_ROOT/results"
mkdir -p "$STATE_DIR" "$RESULTS_DIR"

echo "=========================================================="
echo " Filo512 Standalone Live-SSH Runner"
echo " Workspace : $REPO_ROOT"
echo " Dry Run   : $DRY_RUN"
echo "=========================================================="

install_prereqs() {
    echo ">>> [Setup] Checking Ubuntu packages & perf permissions..."
    export DEBIAN_FRONTEND=noninteractive
    APT_OPTS=(-y -qq -o DPkg::Lock::Timeout=120)

    sudo apt-get "${APT_OPTS[@]}" update
    sudo apt-get "${APT_OPTS[@]}" install \
        build-essential g++ g++-14 git curl wget jq bc gawk \
        ffmpeg cmake ninja-build nasm yasm python3 \
        linux-tools-common "linux-tools-$(uname -r)" 2>/dev/null || \
    sudo apt-get "${APT_OPTS[@]}" install \
        build-essential g++ g++-14 git curl wget jq bc gawk \
        ffmpeg cmake ninja-build nasm yasm python3 linux-tools-generic

    # Allow perf hardware counters
    sudo sysctl -w kernel.perf_event_paranoid=-1 >/dev/null || true
    sudo sysctl -w kernel.kptr_restrict=0 >/dev/null || true

    # Set CPU governor to performance if cpufreq sysfs is exposed by BIOS/OS
    if ls /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1; then
        echo ">>> [Setup] Locking CPU scaling_governor to performance..."
        echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null || true
    else
        echo ">>> [Setup] cpufreq scaling_governor not exposed (BIOS deterministic P-state active)."
    fi
}

ACTIVE_AVX512=$({ grep -m1 -o 'avx512[^ ]*' /proc/cpuinfo || true; } | tr '\n' ' ' | sed 's/[[:space:]]*$//')

# ---------------------------------------------------------
# PASS 1: Native AVX-512 ON
# ---------------------------------------------------------
if [ ! -f "$STATE_DIR/pass1.done" ]; then
    if [ -z "$ACTIVE_AVX512" ]; then
        echo "[ERROR] Pass 1 expects native AVX-512 enabled, but /proc/cpuinfo shows NO avx512 flags!"
        echo "Check BIOS settings or run: ./scripts/01_toggle_kernel_avx512.sh enable && sudo reboot"
        exit 1
    fi

    install_prereqs

    echo ">>> [PASS 1/2] Running Native AVX-512 Suite..."
    ./scripts/00_preflight_env.sh avx512_on
    ./workloads/microbench/bench_micro.sh
    ./workloads/svt_av1/bench_svt_av1.sh
    ./workloads/clickhouse/bench_clickhouse.sh avx512_on

    touch "$STATE_DIR/pass1.done"

    echo ">>> [PASS 1 COMPLETE] Applying clearcpuid AVX-512 kernel mask in GRUB..."
    ./scripts/01_toggle_kernel_avx512.sh disable

    echo ""
    echo "=========================================================="
    echo " PASS 1 FINISHED SUCCESSFULLY!"
    echo " Next step: Reboot the server so clearcpuid takes effect,"
    echo " then SSH back in and run the EXACT SAME COMMAND:"
    echo "   cd $REPO_ROOT && DRY_RUN=$DRY_RUN ./scripts/run_standalone.sh"
    echo "=========================================================="

    if [ "${AUTO_REBOOT:-false}" = "true" ]; then
        echo "AUTO_REBOOT=true -> Rebooting in 5 seconds..."
        sleep 5
        sudo reboot
    else
        read -r -p "Reboot server now to start Pass 2? [y/N]: " ans
        if [[ "${ans:-N}" =~ ^[Yy]$ ]]; then
            sudo reboot
        fi
    fi
    exit 0
fi

# ---------------------------------------------------------
# PASS 2: Kernel-Masked AVX-512 OFF (AVX2 Fallback)
# ---------------------------------------------------------
if [ ! -f "$STATE_DIR/pass2.done" ]; then
    if [ -n "$ACTIVE_AVX512" ]; then
        echo "[ERROR] Pass 2 expects AVX-512 to be masked, but flags are still active: $ACTIVE_AVX512"
        echo "Did the server finish rebooting into the default Ubuntu GRUB entry?"
        exit 1
    fi

    sudo sysctl -w kernel.perf_event_paranoid=-1 >/dev/null || true
    if ls /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1; then
        echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null || true
    fi

    echo ">>> [PASS 2/2] Running Masked AVX2 Suite (clearcpuid active)..."
    ./scripts/00_preflight_env.sh avx512_off
    ./workloads/clickhouse/bench_clickhouse.sh avx512_off

    echo ">>> [Summary] Generating SUMMARY.md..."
    python3 ./scripts/parse_results.py

    echo ">>> [Cleanup] Restoring native AVX-512 in GRUB so next reboot is unmasked..."
    ./scripts/01_toggle_kernel_avx512.sh enable

    touch "$STATE_DIR/pass2.done"

    CPU_SLUG=$(awk -F': ' '/Model name/ {gsub(/[^a-zA-Z0-9_-]/, "_", $2); print $2; exit}' "$RESULTS_DIR/env_avx512_on.txt")
    STAMP=$(date -u +"%Y%m%d-%H%M%S")
    ARCHIVE="$REPO_ROOT/filo512_${CPU_SLUG:-results}_${STAMP}.tar.gz"
    tar -czf "$ARCHIVE" -C "$REPO_ROOT" results/

    echo ""
    echo "=========================================================="
    echo " ALL BENCHMARKS COMPLETE!"
    echo " Summary File   : $RESULTS_DIR/SUMMARY.md"
    echo " Results Bundle : $ARCHIVE"
    echo " Note: GRUB has been restored to native AVX-512."
    echo "=========================================================="
    exit 0
fi

echo "Both Pass 1 and Pass 2 are already marked complete in $STATE_DIR."
echo "To run a fresh benchmark from scratch, run: rm -rf $STATE_DIR $RESULTS_DIR/*"
