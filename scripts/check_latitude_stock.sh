#!/usr/bin/env bash
set -euo pipefail

TFVARS_FILE="$(dirname "$0")/../terraform/latitude/terraform.tfvars"
if [ -z "${LATITUDESH_AUTH_TOKEN:-}" ] && [ -f "$TFVARS_FILE" ]; then
    LATITUDESH_AUTH_TOKEN=$(awk -F'"' '/latitude_api_key/ {print $2}' "$TFVARS_FILE")
fi

if [ -z "${LATITUDESH_AUTH_TOKEN:-}" ]; then
    echo "Error: LATITUDESH_AUTH_TOKEN is not set."
    echo "Export it or add it to terraform/latitude/.env first."
    exit 1
fi

FILTER_REGEX="${1:-EPYC|f4|m4|c4|rs4}"

echo ">>> Querying Latitude.sh API for available AVX-512 / AMD EPYC bare-metal stock..."
echo "----------------------------------------------------------------------------------------"
printf "%-18s | %-28s | %-6s | %-10s | %-10s\n" "PLAN SLUG" "CPU MODEL" "SITE" "STOCK" "USD/HR"
echo "----------------------------------------------------------------------------------------"

curl -s -H "Authorization: Bearer ${LATITUDESH_AUTH_TOKEN}" \
     -H "Accept: application/vnd.api+json" \
     "https://api.latitude.sh/plans" | \
jq -r --arg regex "$FILTER_REGEX" '
  .data[]
  | select(
      (.attributes.slug | test($regex; "i")) or
      ((.attributes.specs.cpu.type // "") | test($regex; "i"))
    )
  | .attributes as $attr
  | (
      # Handle both Latitude API availability schemas (.regions and .availabilities)
      if ($attr.availabilities != null) then
        $attr.availabilities[]
        | select(.in_stock == true)
        | [
            ($attr.slug | gsub("\\."; "-")),
            ($attr.specs.cpu.type // "Unknown CPU"),
            (.site_slug // .region // "N/A"),
            (.stock_level // "available"),
            (if .pricing.USD.hour then "$\(.pricing.USD.hour)" else "N/A" end)
          ]
      elif ($attr.regions != null) then
        $attr.regions[]
        | . as $reg
        | ($reg.locations.in_stock // [])[]
        | [
            ($attr.slug | gsub("\\."; "-")),
            ($attr.specs.cpu.type // "Unknown CPU"),
            .,
            "in_stock",
            (if $reg.pricing.USD.hour then "$\($reg.pricing.USD.hour)" else "N/A" end)
          ]
      else
        empty
      end
    )
  | @tsv
' | while IFS=$'\t' read -r slug cpu site stock price; do
    printf "%-18s | %-28s | %-6s | %-10s | %-10s\n" "$slug" "${cpu:0:28}" "$site" "$stock" "$price"
done

echo "----------------------------------------------------------------------------------------"
