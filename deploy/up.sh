#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
echo "Starting OpenClaw..."
docker compose up -d
echo "OpenClaw is running. Dashboard: http://127.0.0.1:18789"
