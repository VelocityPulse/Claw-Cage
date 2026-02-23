#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo ""
echo -e "  ${RED}WARNING: This will stop OpenClaw and DELETE ALL DATA.${NC}"
echo "  (configs, memory, workspace — everything in the claw-data volume)"
echo ""

CONFIRM=""
if [[ -t 0 ]]; then
    read -r -p "  Type 'reset' to confirm: " CONFIRM
elif [[ -r /dev/tty ]]; then
    read -r -p "  Type 'reset' to confirm: " CONFIRM </dev/tty
fi

if [[ "$CONFIRM" != "reset" ]]; then
    echo "  Cancelled."
    exit 0
fi

echo ""
echo "Stopping OpenClaw and removing data..."
docker compose down -v
echo -e "  ${GREEN}✓${NC} Reset complete. Run 'bash up.sh' to start fresh."
