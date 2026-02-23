#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
echo "Stopping OpenClaw..."
docker compose down
echo "OpenClaw stopped. Data volume preserved."
