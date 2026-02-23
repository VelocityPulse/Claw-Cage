# claw-cage

Deploy [OpenClaw](https://github.com/openclaw/openclaw) securely on any Linux machine. Your AI agent can reach the internet but **cannot access your local network**.

## What it does

- Installs OpenClaw via the official Docker image
- Blocks LAN access with iptables (RFC1918 isolation)
- Hardens the container (no root, no capabilities, loopback-only dashboard)
- 3 files on your host. That's it.

## Prerequisites

- Linux (Debian/Ubuntu recommended)
- bash >= 4, curl
- Docker Engine + Compose v2
- iptables

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/VelocityPulse/claw-cage/main/install.sh | bash
```

Then:

```bash
cd ~/claw-cage
vim .env                              # Add at least one API key
sudo bash iptables-rules.sh            # LAN isolation (one-time)
docker compose up -d                   # Start OpenClaw
```

## Access the dashboard

The dashboard is bound to `127.0.0.1:18789`. If OpenClaw runs on a remote server, use an SSH tunnel:

```bash
ssh -L 18789:127.0.0.1:18789 user@your-server
```

Then open http://localhost:18789 in your browser.

<details>
<summary>Windows (PuTTY)</summary>

1. Open PuTTY, enter your server IP
2. Go to **Connection > SSH > Tunnels**
3. Source port: `18789` / Destination: `127.0.0.1:18789`
4. Click **Add**, then **Open**
5. Open http://localhost:18789

</details>

## Configuration

Edit `~/claw-cage/.env`. At minimum, set one LLM provider key:

```bash
ANTHROPIC_API_KEY=sk-ant-...
# or
OPENAI_API_KEY=sk-...
# or
OPENROUTER_API_KEY=sk-or-...
```

All available variables are documented in [.env.example](deploy/.env.example).

## Upgrade

```bash
cd ~/claw-cage
bash upgrade.sh
```

Updates deployment files, pulls the latest OpenClaw image, and restarts the stack. Your `.env` and data volume are preserved.

## Shell into the running container

```bash
docker exec -it openclaw /bin/sh
```

> **Note:** The production container is hardened (`cap_drop: ALL`, `no-new-privileges`). Commands like `apt` won't work — even as root. This is by design.

## Debug mode (unhardened)

For maintenance tasks that need full root access (install packages, inspect configs, debug):

```bash
cd ~/claw-cage
docker compose --profile debug run --rm -u 0 openclaw-debug /bin/sh
```

This starts a temporary container with no security restrictions, same data volume and same network as production. It is destroyed on exit.

## Uninstall

```bash
cd ~/claw-cage
docker compose down -v
rm -rf ~/claw-cage
```

## How it works

```
  Host
  ├── .env                 ← your API keys
  ├── docker-compose.yml   ← hardened Docker stack
  └── iptables-rules.sh    ← LAN isolation

  Docker (claw-net)
  └── OpenClaw (official image)
       ├── Internet  ✓
       └── LAN       ✗  ← blocked by iptables
```

claw-cage is not a fork. It deploys the official OpenClaw image with network isolation and Docker hardening on top.

## License

ISC
