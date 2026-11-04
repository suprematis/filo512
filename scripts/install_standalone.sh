#!/usr/bin/env bash
set -euo pipefail

# Usage on any independent server:
#   git clone https://github.com/suprematis/filo512.git /opt/filo512
#   cd /opt/filo512
#   sudo DRY_RUN=false ./scripts/install_standalone.sh

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: sudo ./scripts/install_standalone.sh"
    exit 1
fi

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Create /etc/filo512.env only if it doesn't already exist (e.g., from cloud-init)
if [ ! -f /etc/filo512.env ]; then
    cat << ENV_EOF > /etc/filo512.env
WORK_DIR="${REPO_DIR}"
PROVIDER="${PROVIDER:-standalone}"
DRY_RUN="${DRY_RUN:-false}"
PUSH_RESULTS="${PUSH_RESULTS:-false}"
AUTO_DESTROY="${AUTO_DESTROY:-false}"
GITHUB_USER="${GITHUB_USER:-}"
GITHUB_REPO="${GITHUB_REPO:-filo512}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
ENV_EOF
    chmod 600 /etc/filo512.env
fi

# Reset any previous pass markers if re-running on an existing machine
rm -f "${REPO_DIR}/.pass1_complete" "${REPO_DIR}/.pass2_complete"

cat << SERVICE_EOF > /etc/systemd/system/filo512-runner.service
[Unit]
Description=Filo512 Automated Two-Pass AVX-512 Benchmark State Machine
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=${REPO_DIR}/scripts/auto_pipeline.sh
StandardOutput=append:/var/log/filo512-autorun.log
StandardError=append:/var/log/filo512-autorun.log

[Install]
WantedBy=multi-user.target
SERVICE_EOF

systemctl daemon-reload
systemctl enable --now filo512-runner.service
echo ">>> Filo512 standalone runner started! Follow progress with:"
echo "    sudo tail -f /var/log/filo512-autorun.log"
