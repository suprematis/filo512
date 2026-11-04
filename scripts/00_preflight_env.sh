#!/usr/bin/env bash
set -euo pipefail

PASS_LABEL="${1:-avx512_on}"
OUT_DIR="./results"
mkdir -p "$OUT_DIR"
ENV_FILE="${OUT_DIR}/env_${PASS_LABEL}.txt"

echo "Capturing hardware & kernel telemetry to ${ENV_FILE}..."
{
  echo "=== Filo512 Environment Audit (${PASS_LABEL}) ==="
  echo "Timestamp (UTC): $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "Hostname: $(hostname)"
  echo "Kernel: $(uname -a)"
  echo "Kernel cmdline: $(cat /proc/cmdline)"
  echo ""
  echo "=== lscpu Summary ==="
  lscpu | grep -E "Architecture|CPU\(s\)|Model name|Thread|Core|Socket|MHz|cache|NUMA|Vulnerability L1tf" || true
  echo ""
  echo "=== Active AVX-512 Flags ==="
  AVX_FLAGS=$({ grep -m1 -o 'avx512[^ ]*' /proc/cpuinfo || true; } | tr '\n' ' ' | sed 's/[[:space:]]*$//')
  if [ -n "$AVX_FLAGS" ]; then
      echo "$AVX_FLAGS"
  else
      echo "NONE (AVX-512 Masked)"
  fi
} | tee "$ENV_FILE"

if [ "$PASS_LABEL" = "avx512_on" ]; then
    lscpu | grep "Model name:" > "${OUT_DIR}/cpu_model.txt" || true
    { grep -m1 -o 'avx512[^ ]*' /proc/cpuinfo || true; } | tr '\n' ' ' > "${OUT_DIR}/avx512_flags.txt"
fi
