#!/usr/bin/env bash
set -euo pipefail

# Load optional runtime environment config if present (never echoed)
if [ -f /etc/filo512.env ]; then
    set +x
    # shellcheck disable=SC1091
    source /etc/filo512.env
fi

WORK_DIR="${WORK_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
DRY_RUN="${DRY_RUN:-false}"
PUSH_RESULTS="${PUSH_RESULTS:-false}"
AUTO_DESTROY="${AUTO_DESTROY:-false}"
PROVIDER="${PROVIDER:-standalone}"

cd "$WORK_DIR"

if [ ! -f "$WORK_DIR/.pass1_complete" ]; then
    echo ">>> [PASS 1] Running Native AVX-512 Suite (DRY_RUN=${DRY_RUN})..."
    DRY_RUN="${DRY_RUN}" ./scripts/run_all.sh avx512_on
    touch "$WORK_DIR/.pass1_complete"

    echo ">>> [PASS 1 COMPLETE] Masking AVX-512 in GRUB and rebooting..."
    ./scripts/01_toggle_kernel_avx512.sh disable
    systemctl reboot

elif [ ! -f "$WORK_DIR/.pass2_complete" ]; then
    echo ">>> [PASS 2] Running AVX-512 Masked Suite (DRY_RUN=${DRY_RUN})..."
    DRY_RUN="${DRY_RUN}" ./scripts/run_all.sh avx512_off
    touch "$WORK_DIR/.pass2_complete"

    echo ">>> [CLEANUP] Restoring native AVX-512 GRUB configuration..."
    ./scripts/01_toggle_kernel_avx512.sh enable
    if systemctl is-enabled filo512-runner.service >/dev/null 2>&1; then
        systemctl disable filo512-runner.service
    fi

    # Copy sanitized log into results/
    if [ -f /var/log/filo512-autorun.log ]; then
        sed -E 's/(github_pat_[a-zA-Z0-9_]+|ghp_[a-zA-Z0-9]+|Bearer [a-zA-Z0-9._-]+)/[REDACTED]/g' \
            /var/log/filo512-autorun.log > ./results/autorun.log || true
    fi

    echo ">>> [BENCHMARK COMPLETE] Results saved locally in ${WORK_DIR}/results/SUMMARY.md"

    # Optional: Push results branch to GitHub if PUSH_RESULTS=true and token is provided
    if [ "${PUSH_RESULTS}" = "true" ] && [ -n "${GITHUB_TOKEN:-}" ] && [ -n "${GITHUB_USER:-}" ]; then
        GITHUB_REPO="${GITHUB_REPO:-filo512}"
        CPU_SLUG=$(grep -m1 'model name' /proc/cpuinfo | awk -F': ' '{print $2}' | tr ' ' '_' | tr -cd '[:alnum:]_-')
        RUN_BRANCH="results/${CPU_SLUG}-$(date -u +%Y%m%d-%H%M%S)"

        git config user.name "Filo512 Automated Runner"
        git config user.email "bot@filo512.local"
        git checkout -b "${RUN_BRANCH}"
        git add results/
        git commit -m "chore(results): automated AVX-512 vs AVX2 run on ${CPU_SLUG}"

        # Push using ephemeral in-memory URL so token is never saved in .git/config
        git push "https://${GITHUB_USER}:${GITHUB_TOKEN}@github.com/${GITHUB_USER}/${GITHUB_REPO}.git" "HEAD:refs/heads/${RUN_BRANCH}"
        echo ">>> [GIT PUSH COMPLETE] Pushed branch: ${RUN_BRANCH}"
    else
        echo ">>> [LOCAL MODE] Skipping GitHub push (PUSH_RESULTS=${PUSH_RESULTS})."
    fi

    # Optional: Provider-specific self-destruct hook
    if [ "${AUTO_DESTROY}" = "true" ] && [ "${PROVIDER}" = "latitude" ] && [ -n "${LATITUDE_API_KEY:-}" ]; then
        echo ">>> [AUTO-DESTROY] Locating Server ID on Latitude.sh..."
        PRIMARY_IP=$(hostname -I | awk '{print $1}')
        SERVER_ID=$(curl -s -g \
            -H "Authorization: Bearer ${LATITUDE_API_KEY}" \
            -H "Accept: application/vnd.api+json" \
            "https://api.latitude.sh/servers?filter[project]=${PROJECT_ID}" | \
            jq -r ".data[] | select(.attributes.primary_ipv4 == \"${PRIMARY_IP}\") | .id")

        if [ -n "${SERVER_ID}" ] && [ "${SERVER_ID}" != "null" ]; then
            echo ">>> [AUTO-DESTROY] Terminating Latitude Server ID: ${SERVER_ID}"
            curl -s -X DELETE \
                -H "Authorization: Bearer ${LATITUDE_API_KEY}" \
                -H "Accept: application/vnd.api+json" \
                "https://api.latitude.sh/servers/${SERVER_ID}"
        else
            echo ">>> [WARN] Could not match Server ID for IP ${PRIMARY_IP}. Destroy manually!"
        fi
    fi
fi
