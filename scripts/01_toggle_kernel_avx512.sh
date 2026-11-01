#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-status}"
GRUB_FILE="/etc/default/grub"

case "$MODE" in
  disable)
    if ! grep -q "clearcpuid=avx512f" "$GRUB_FILE"; then
      sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="clearcpuid=avx512f /' "$GRUB_FILE"
      sudo update-grub
      echo "[OK] clearcpuid=avx512f added to GRUB. Run 'sudo reboot' to boot without AVX-512."
    else
      echo "[INFO] clearcpuid=avx512f is already set in $GRUB_FILE."
    fi
    ;;
  enable)
    sudo sed -i 's/clearcpuid=avx512f //g' "$GRUB_FILE"
    sudo update-grub
    echo "[OK] AVX-512 restored in GRUB. Run 'sudo reboot' to boot with native AVX-512."
    ;;
  *)
    echo "Kernel Cmdline: $(cat /proc/cmdline)"
    echo -n "Active AVX-512 Flags: "
    grep -m1 -o 'avx512[^ ]*' /proc/cpuinfo | tr '\n' ' ' || echo "NONE (Masked)"
    echo ""
    ;;
esac
