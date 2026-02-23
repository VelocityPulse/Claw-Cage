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
nano .env                              # Add at least one API key
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
curl -fsSL https://raw.githubusercontent.com/VelocityPulse/claw-cage/main/install.sh | bash
cd ~/claw-cage && docker compose pull && docker compose up -d
```

Your `.env` and data volume are preserved.

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

## CLI access

```bash
docker compose run --rm openclaw-cli
```

## License

ISC
