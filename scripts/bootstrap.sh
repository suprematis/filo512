#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${FILO512_DIR:-$HOME/filo512}"
REPO_URL="https://github.com/suprematis/filo512.git"

echo ">>> [Bootstrap] Ensuring git and ca-certificates are installed..."
if ! command -v git >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    sudo apt-get -y -qq -o DPkg::Lock::Timeout=120 update
    sudo apt-get -y -qq -o DPkg::Lock::Timeout=120 install git ca-certificates curl
fi

if [ -d "$TARGET_DIR/.git" ]; then
    echo ">>> [Bootstrap] Updating existing repo in $TARGET_DIR..."
    git -C "$TARGET_DIR" pull --ff-only origin main
else
    echo ">>> [Bootstrap] Cloning $REPO_URL into $TARGET_DIR..."
    git clone "$REPO_URL" "$TARGET_DIR"
fi

cd "$TARGET_DIR"
exec ./scripts/run_standalone.sh
