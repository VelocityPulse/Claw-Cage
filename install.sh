#!/bin/bash
set -euo pipefail

# claw-cage installer
# Usage: curl -fsSL https://raw.githubusercontent.com/VelocityPulse/claw-cage/main/install.sh | bash

REPO="https://raw.githubusercontent.com/VelocityPulse/claw-cage/main"
INSTALL_DIR="${CLAW_CAGE_DIR:-$HOME/claw-cage}"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; }
warn() { echo -e "  ${YELLOW}!${NC} $1"; }

# --- Banner ---
echo ""
echo "  claw-cage — Secure OpenClaw Deployment"
echo "  https://github.com/VelocityPulse/claw-cage"
echo ""

# --- Prerequisites ---
echo "Checking prerequisites..."

if [[ "${BASH_VERSINFO[0]:-0}" -lt 4 ]]; then
    fail "bash >= 4 required (found ${BASH_VERSION:-unknown})"
    exit 1
fi
ok "bash ${BASH_VERSION}"

if ! command -v curl >/dev/null; then
    fail "curl not found — install it with: apt-get install curl"
    exit 1
fi
ok "curl"

if ! command -v docker >/dev/null; then
    fail "docker not found — install Docker Engine: https://docs.docker.com/engine/install/"
    exit 1
fi
ok "docker"

if ! docker compose version >/dev/null 2>&1; then
    fail "docker compose v2 not found — install the Compose plugin: https://docs.docker.com/compose/install/"
    exit 1
fi
COMPOSE_VER=$(docker compose version --short 2>/dev/null || echo "v2")
ok "docker compose $COMPOSE_VER"

ARCH=$(uname -m)
ok "architecture: $ARCH"

echo ""

# --- Download ---
echo "Installing claw-cage to $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"

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
chmod +x "$INSTALL_DIR/iptables-rules.sh"

# --- .env ---
if [[ ! -f "$INSTALL_DIR/.env" ]]; then
    cp "$INSTALL_DIR/.env.example" "$INSTALL_DIR/.env"
    chmod 600 "$INSTALL_DIR/.env"
    ok ".env created (mode 600)"
else
    warn ".env already exists — not overwriting"
fi

# --- Next steps ---
echo ""
echo "  Installation complete!"
echo ""
echo "  Next steps:"
echo ""
echo "    cd $INSTALL_DIR"
echo "    nano .env                              # Add your API keys"
echo "    sudo bash iptables-rules.sh            # Network isolation (one-time)"
echo "    docker compose up -d                   # Start OpenClaw"
echo ""
