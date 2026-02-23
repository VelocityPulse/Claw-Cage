#!/bin/bash
set -euo pipefail

# claw-cage installer
# Usage: curl -fsSL https://raw.githubusercontent.com/VelocityPulse/claw-cage/main/install.sh | bash

VERSION="0.16"
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
echo "  claw-cage v$VERSION — Secure OpenClaw Deployment"
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

if ! docker info >/dev/null 2>&1; then
    # Check if user is in docker group but session doesn't have it yet
    if getent group docker 2>/dev/null | grep -qw "$USER"; then
        fail "Cannot connect to Docker daemon"
        echo ""
        echo "    Your user is in the docker group but the session is stale."
        echo "    Log out and back in (SSH reconnect), then re-run this installer."
    else
        fail "Cannot connect to Docker daemon — permission denied"
        echo ""
        echo "    Fix:"
        echo "      sudo usermod -aG docker $USER"
        echo ""
        echo "    Then DISCONNECT and RECONNECT your SSH session."
        echo "    The group change only takes effect after a new login."
    fi
    exit 1
fi
ok "docker daemon accessible"

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
download "$REPO/deploy/upgrade.sh" "$INSTALL_DIR/upgrade.sh" "upgrade.sh"
chmod +x "$INSTALL_DIR/iptables-rules.sh"
chmod +x "$INSTALL_DIR/upgrade.sh"

# --- .env ---
if [[ ! -f "$INSTALL_DIR/.env" ]]; then
    cp "$INSTALL_DIR/.env.example" "$INSTALL_DIR/.env"
    chmod 600 "$INSTALL_DIR/.env"
    ok ".env created (mode 600)"
else
    warn ".env already exists — not overwriting"
fi

# --- Helper scripts (up/down/reset) ---
HELPERS_EXIST=""
[[ -f "$INSTALL_DIR/up.sh" ]] && HELPERS_EXIST="yes"

echo ""
HELPERS_ANSWER=""
HELPERS_PROMPT="  Install helper scripts (up.sh, down.sh, reset.sh)? [y/N] "
if [[ "$HELPERS_EXIST" == "yes" ]]; then
    HELPERS_PROMPT="  Keep helper scripts (up.sh, down.sh, reset.sh)? [Y/n] "
fi

if [[ "${CLAW_HELPERS:-}" != "" ]]; then
    HELPERS_ANSWER="${CLAW_HELPERS}"
elif [[ -t 0 ]]; then
    read -r -p "$HELPERS_PROMPT" HELPERS_ANSWER
elif [[ -r /dev/tty ]]; then
    read -r -p "$HELPERS_PROMPT" HELPERS_ANSWER </dev/tty
fi

if [[ "$HELPERS_EXIST" == "yes" ]]; then
    # Currently installed — remove on explicit "n"
    if [[ "$HELPERS_ANSWER" =~ ^[Nn] ]]; then
        rm -f "$INSTALL_DIR/up.sh" "$INSTALL_DIR/down.sh" "$INSTALL_DIR/reset.sh"
        warn "Helper scripts removed."
    else
        download "$REPO/deploy/up.sh" "$INSTALL_DIR/up.sh" "up.sh"
        download "$REPO/deploy/down.sh" "$INSTALL_DIR/down.sh" "down.sh"
        download "$REPO/deploy/reset.sh" "$INSTALL_DIR/reset.sh" "reset.sh"
        chmod +x "$INSTALL_DIR/up.sh" "$INSTALL_DIR/down.sh" "$INSTALL_DIR/reset.sh"
        ok "Helper scripts updated."
    fi
else
    # Not installed — install on explicit "y"
    if [[ "$HELPERS_ANSWER" =~ ^[Yy] ]]; then
        download "$REPO/deploy/up.sh" "$INSTALL_DIR/up.sh" "up.sh"
        download "$REPO/deploy/down.sh" "$INSTALL_DIR/down.sh" "down.sh"
        download "$REPO/deploy/reset.sh" "$INSTALL_DIR/reset.sh" "reset.sh"
        chmod +x "$INSTALL_DIR/up.sh" "$INSTALL_DIR/down.sh" "$INSTALL_DIR/reset.sh"
        ok "Helper scripts installed."
    else
        warn "Helper scripts skipped."
    fi
fi

# --- Auto-start on boot ---
if command -v systemctl >/dev/null 2>&1; then
    DOCKER_ENABLED=""
    if systemctl is-enabled docker >/dev/null 2>&1; then
        DOCKER_ENABLED="yes"
    fi

    echo ""
    AUTOSTART_ANSWER=""
    if [[ "$DOCKER_ENABLED" == "yes" ]]; then
        PROMPT="  Auto-start is currently ENABLED. Keep it enabled? [Y/n] "
    else
        PROMPT="  Enable OpenClaw auto-start on boot? [y/N] "
    fi

    # Read answer from user (works in both interactive and curl|bash mode)
    if [[ "${CLAW_AUTOSTART:-}" != "" ]]; then
        # Env var override — no prompt
        AUTOSTART_ANSWER="${CLAW_AUTOSTART}"
    elif [[ -t 0 ]]; then
        read -r -p "$PROMPT" AUTOSTART_ANSWER
    elif [[ -r /dev/tty ]]; then
        read -r -p "$PROMPT" AUTOSTART_ANSWER </dev/tty
    fi

    if [[ "$DOCKER_ENABLED" == "yes" ]]; then
        # Currently enabled — disable on explicit "n"
        if [[ "$AUTOSTART_ANSWER" =~ ^[Nn] ]]; then
            sudo systemctl disable docker
            warn "Auto-start DISABLED. Docker will not start on boot."
        else
            ok "Auto-start kept enabled."
        fi
    else
        # Currently disabled — enable on explicit "y"
        if [[ "$AUTOSTART_ANSWER" =~ ^[Yy] ]]; then
            sudo systemctl enable docker
            ok "Auto-start ENABLED. OpenClaw will start on boot."
        else
            warn "Auto-start skipped. To enable later: sudo systemctl enable docker"
        fi
    fi
fi

# --- Next steps ---
echo ""
echo "  Installation complete!"
echo ""
echo "  Next steps:"
echo ""
echo "    cd $INSTALL_DIR"
echo "    vim .env                              # Add your API keys"
echo "    sudo bash iptables-rules.sh            # Network isolation (one-time)"
echo "    docker compose up -d                   # Start OpenClaw"
echo ""
