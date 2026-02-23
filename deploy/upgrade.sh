#!/bin/bash
set -euo pipefail

# claw-cage upgrade
# Re-downloads deployment files, pulls latest image, restarts the stack.
# Wrapped in main() so bash reads the entire script before executing —
# this prevents issues when upgrade.sh overwrites itself mid-run.

main() {
    REPO="https://raw.githubusercontent.com/VelocityPulse/claw-cage/main"
    INSTALL_DIR="$(cd "$(dirname "$0")" && pwd)"

    # --- Colors ---
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    YELLOW='\033[1;33m'
    NC='\033[0m'

    ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
    fail() { echo -e "  ${RED}✗${NC} $1"; }
    warn() { echo -e "  ${YELLOW}!${NC} $1"; }

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
}

main "$@"
