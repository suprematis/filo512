#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../terraform/latitude"

# 1. Load API token from terraform.tfvars if not already in env
if [ -z "${LATITUDESH_AUTH_TOKEN:-}" ] && [ -f "terraform.tfvars" ]; then
    LATITUDESH_AUTH_TOKEN=$(awk -F'"' '/latitude_api_key/ {print $2}' terraform.tfvars)
fi

SERVER_ID="${1:-$(terraform output -raw server_id 2>/dev/null || true)}"
if [ -z "$SERVER_ID" ]; then
    echo "Error: Could not determine server_id from Terraform state. Pass it as \$1."
    exit 1
fi

# 2. Get the SSH key ID registered in Terraform state (or query the first key on the account)
SSH_KEY_ID=$(terraform state show latitudesh_ssh_key.filo512_key 2>/dev/null | awk -F'"' '/^[[:space:]]*id[[:space:]]*=/ {print $2}' || true)
if [ -z "$SSH_KEY_ID" ]; then
    SSH_KEY_ID=$(curl -s -H "Authorization: Bearer ${LATITUDESH_AUTH_TOKEN}" \
        -H "Accept: application/vnd.api+json" \
        "https://api.latitude.sh/ssh_keys" | jq -r '.data[0].id')
fi

echo ">>> Requesting Out-of-Band (OOB) serial console for Server: ${SERVER_ID} (SSH Key: ${SSH_KEY_ID})..."

# 3. Trigger POST /servers/{id}/out_of_band_connection
OOB_RESP=$(curl -s -X POST \
    -H "Authorization: Bearer ${LATITUDESH_AUTH_TOKEN}" \
    -H "Accept: application/vnd.api+json" \
    -H "Content-Type: application/json" \
    -d "{
      \"data\": {
        \"type\": \"out_of_band\",
        \"attributes\": {
          \"ssh_key_id\": \"${SSH_KEY_ID}\"
        }
      }
    }" \
    "https://api.latitude.sh/servers/${SERVER_ID}/out_of_band_connection")

# 4. Poll GET /servers/{id}/out_of_band_connection for connection credentials
echo ">>> Waiting for OOB Serial-over-LAN tunnel to become operational..."
for _ in {1..12}; do
    OOB_STATE=$(curl -s -H "Authorization: Bearer ${LATITUDESH_AUTH_TOKEN}" \
        -H "Accept: application/vnd.api+json" \
        "https://api.latitude.sh/servers/${SERVER_ID}/out_of_band_connection")
    
    # Extract connection details from response
    OOB_USER=$(echo "$OOB_STATE" | jq -r '.data.attributes.username // .data[0].attributes.username // empty')
    OOB_HOST=$(echo "$OOB_STATE" | jq -r '.data.attributes.host // .data.attributes.ip // .data[0].attributes.host // empty')
    OOB_PORT=$(echo "$OOB_STATE" | jq -r '.data.attributes.port // .data[0].attributes.port // "2222"')
    OOB_CMD=$(echo "$OOB_STATE" | jq -r '.data.attributes.ssh_command // .data.attributes.connection_string // empty')

    if [ -n "$OOB_CMD" ] || { [ -n "$OOB_USER" ] && [ -n "$OOB_HOST" ]; }; then
        break
    fi
    sleep 3
done

echo ">>> OOB API Response Snapshot:"
echo "$OOB_STATE" | jq '.'

if [ -n "$OOB_CMD" ]; then
    echo ">>> Connecting via: $OOB_CMD (Use '~.' to exit serial console)"
    eval "$OOB_CMD -i ~/.ssh/id_ed25519"
elif [ -n "$OOB_USER" ] && [ -n "$OOB_HOST" ]; then
    echo ">>> Connecting to ${OOB_USER}@${OOB_HOST}:${OOB_PORT} (Use '~.' to exit serial console)"
    ssh -i ~/.ssh/id_ed25519 -p "$OOB_PORT" "${OOB_USER}@${OOB_HOST}"
else
    echo ">>> OOB enabled! If the JSON schema above uses different field names, copy the ssh command above."
fi
