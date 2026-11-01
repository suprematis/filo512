#!/usr/bin/env bash
set -euo pipefail
OUT_DIR="$(cd "$(dirname "$0")/.." && pwd)/results"
mkdir -p "$OUT_DIR"

BMC_IP="${1:-}"
BMC_USER="${2:-}"
BMC_PASS="${3:-}"

if [[ -z "$BMC_IP" || -z "$BMC_USER" || -z "$BMC_PASS" ]]; then
  echo "Usage: $0 <BMC_IP> <BMC_USER> <BMC_PASS>"
  exit 1
fi

echo "=== Querying Redfish BIOS Attributes on $BMC_IP ==="
SYSTEM_PATH=$(curl -sk -u "${BMC_USER}:${BMC_PASS}" "https://${BMC_IP}/redfish/v1/Systems" | jq -r '.Members[0]."@odata.id"')
curl -sk -u "${BMC_USER}:${BMC_PASS}" "https://${BMC_IP}${SYSTEM_PATH}/Bios" | jq '.Attributes' | tee "${OUT_DIR}/bios_attributes.json"
