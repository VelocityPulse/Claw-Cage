#!/bin/bash
set -euo pipefail

# claw-cage upgrade
# Re-downloads deployment files, pulls latest image, restarts the stack.

REPO="https://raw.githubusercontent.com/VelocityPulse/claw-cage/main"
INSTALL_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Colors ---
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; }

echo ""
echo "  claw-cage — Upgrade"
echo ""

# --- Download latest files ---
echo "Downloading latest deployment files..."

download() {
    local url="$1" dest="$2" name="$3"
    if ! curl -fsSL "$url" -o "$dest"; then
        fail "Failed to download $name — check your internet connection"
        exit 1
    fi
    ok "$name"
}

download "$REPO/deploy/docker-compose.yml" "$INSTALL_DIR/docker-compose.yml" "docker-compose.yml"
download "$REPO/deploy/.env.example" "$INSTALL_DIR/.env.example" ".env.example"
download "$REPO/deploy/iptables-rules.sh" "$INSTALL_DIR/iptables-rules.sh" "iptables-rules.sh"
download "$REPO/deploy/upgrade.sh" "$INSTALL_DIR/upgrade.sh" "upgrade.sh"
chmod +x "$INSTALL_DIR/iptables-rules.sh"
chmod +x "$INSTALL_DIR/upgrade.sh"

# --- Pull & restart ---
echo ""
echo "Pulling latest OpenClaw image..."
docker compose -f "$INSTALL_DIR/docker-compose.yml" pull
ok "image updated"

echo ""
echo "Restarting stack..."
docker compose -f "$INSTALL_DIR/docker-compose.yml" up -d
ok "stack restarted"

echo ""
echo "  Upgrade complete!"
echo "  Your .env and data volume are preserved."
echo ""
