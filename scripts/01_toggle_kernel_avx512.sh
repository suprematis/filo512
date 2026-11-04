#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-status}"
DROPIN_FILE="/etc/default/grub.d/99-filo512.cfg"

# Mask avx512f (and all dependent AVX-512 flags) at the kernel boot level
MASK_ARGS="clearcpuid=avx512f,avx512dq,avx512ifma,avx512cd,avx512bw,avx512vl,avx512_bf16,avx512vbmi,avx512_vbmi2,avx512_vnni,avx512_bitalg,avx512_vpopcntdq"

case "$MODE" in
  disable)
    sudo mkdir -p /etc/default/grub.d
    cat << GRUB_EOF | sudo tee "$DROPIN_FILE" >/dev/null
# Managed by filo512 benchmark state machine
GRUB_CMDLINE_LINUX_DEFAULT="\$GRUB_CMDLINE_LINUX_DEFAULT ${MASK_ARGS}"
GRUB_CMDLINE_LINUX="\$GRUB_CMDLINE_LINUX ${MASK_ARGS}"
GRUB_EOF
    sudo update-grub
    echo "[OK] ${MASK_ARGS} written to ${DROPIN_FILE} and GRUB updated."
    ;;
  enable)
    sudo rm -f "$DROPIN_FILE"
    sudo sed -i 's/clearcpuid=[^ "]* *//g' /etc/default/grub || true
    sudo update-grub
    echo "[OK] Removed ${DROPIN_FILE} and restored native AVX-512 in GRUB."
    ;;
  *)
    echo "Kernel Cmdline: $(cat /proc/cmdline)"
    echo -n "Active AVX-512 Flags: "
    grep -m1 -o 'avx512[^ ]*' /proc/cpuinfo | tr '\n' ' ' || echo "NONE (Masked)"
    echo ""
    ;;
esac
