# claw-cage

Secure deployment template for [OpenClaw](https://github.com/openclaw/openclaw). LAN network isolation + Docker hardening, delivered via a single `curl | bash` command.

## What is claw-cage?

claw-cage deploys OpenClaw inside a hardened Docker stack with host-level network isolation. Containers can reach the internet (LLM APIs, messaging services) but are **blocked from accessing your local network** — the primary attack surface for a self-hosted AI agent.

Zero dependencies beyond `bash`, `curl`, and `docker`.

## What claw-cage is NOT

- Not a fork of OpenClaw — it uses the official image as-is
- Not a standalone tool — it wraps and secures an existing OpenClaw deployment
- Not tied to any specific LLM — works with Anthropic, OpenAI, Gemini, Groq, Ollama, OpenRouter, and more

## Quick Start

```bash
# 1. Install
curl -fsSL https://raw.githubusercontent.com/VelocityPulse/claw-cage/main/install.sh | bash

# 2. Configure
cd ~/claw-cage
nano .env                              # Add at least one API key

# 3. Network isolation (one-time, requires sudo)
sudo bash iptables-rules.sh

# 4. Start
docker compose up -d
```

## Prerequisites

| Requirement | Minimum | Check |
|------------|---------|-------|
| bash | >= 4 | `bash --version` |
| curl | any | `curl --version` |
| Docker Engine | any | `docker --version` |
| Docker Compose | v2 | `docker compose version` |
| iptables | any | `sudo iptables -L` |
| OS | Debian/Ubuntu (for iptables-persistent) | `cat /etc/os-release` |

## Configuration

Edit `~/claw-cage/.env` — at minimum, set one LLM provider API key.

| Variable | Required | Description |
|----------|----------|-------------|
| `ANTHROPIC_API_KEY` | one key required | Anthropic (Claude) API key |
| `OPENAI_API_KEY` | | OpenAI (GPT) API key |
| `OPENROUTER_API_KEY` | | OpenRouter API key (access multiple models) |
| `GEMINI_API_KEY` | | Google Gemini API key |
| `GROQ_API_KEY` | | Groq API key (fast inference) |
| `OLLAMA_BASE_URL` | | Ollama URL for local models |
| `OPENCLAW_GATEWAY_BIND` | set | Gateway bind mode (`loopback` = default) |
| `OPENCLAW_DISABLE_BONJOUR` | set | Disable mDNS advertisement (`1` = default) |
| `TELEGRAM_BOT_TOKEN` | | Telegram bot token |
| `WHATSAPP_ENABLED` | | Enable WhatsApp channel |
| `NODE_OPTIONS` | | V8 heap limit (uncomment for < 1 GB RAM machines) |

## Security

claw-cage provides two layers of protection:

**1. Host-level: iptables DOCKER-USER chain**

The `iptables-rules.sh` script adds rules to the `DOCKER-USER` chain that block all traffic from the Docker network (`172.30.0.0/24`) to private IP ranges (RFC1918: `192.168.0.0/16`, `10.0.0.0/8`, `172.16.0.0/12`). Internet access is allowed — LAN access is not.

These rules **only affect Docker traffic**. Your host machine's network access is completely unaffected.

**2. Container-level: Docker Compose hardening**

- `cap_drop: ALL` — no Linux capabilities
- `user: 1000:1000` — non-root process
- `security_opt: no-new-privileges` — prevents privilege escalation
- `127.0.0.1:18789` — dashboard bound to loopback only
- `enable_ipv6: false` — prevents IPv6 bypass of iptables rules

## Accessing the Dashboard

The dashboard listens on `127.0.0.1:18789` (loopback only). To access it from your local machine, use an SSH tunnel.

### Linux / macOS

```bash
ssh -L 18789:127.0.0.1:18789 user@<server-ip>
```

Then open `http://localhost:18789` in your browser.

### Windows (PowerShell)

```powershell
ssh -L 18789:127.0.0.1:18789 user@<server-ip>
```

OpenSSH is built into Windows 10+. Then open `http://localhost:18789`.

### Windows (PuTTY)

1. Open PuTTY, enter your server IP under **Session**
2. Go to **Connection > SSH > Tunnels**
3. Source port: `18789`
4. Destination: `127.0.0.1:18789`
5. Click **Add**, then **Open**
6. Open `http://localhost:18789` in your browser

## Upgrade

```bash
# Update deployment files
curl -fsSL https://raw.githubusercontent.com/VelocityPulse/claw-cage/main/install.sh | bash

# Pull latest OpenClaw image and restart
cd ~/claw-cage
docker compose pull
docker compose up -d
```

Your `.env` and `claw-data` volume are preserved. Only `docker-compose.yml` and `iptables-rules.sh` are updated.

## Uninstall

```bash
# Stop and remove containers + volume
cd ~/claw-cage
docker compose down -v

# Remove claw-cage files
rm -rf ~/claw-cage

# Remove iptables rules (optional)
sudo iptables -D DOCKER-USER -s 172.30.0.0/24 -d 192.168.0.0/16 -j DROP
sudo iptables -D DOCKER-USER -s 172.30.0.0/24 -d 10.0.0.0/8 -j DROP
sudo iptables -D DOCKER-USER -s 172.30.0.0/24 -d 172.16.0.0/12 -j DROP
sudo iptables -D DOCKER-USER -s 172.30.0.0/24 -d 172.30.0.0/24 -j ACCEPT
sudo iptables -D DOCKER-USER -s 172.30.0.0/24 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -D DOCKER-USER -s 172.30.0.0/24 -d 127.0.0.11 -p udp --dport 53 -j ACCEPT
sudo netfilter-persistent save
```

## Architecture

```
┌─────────────────────────────────────────────┐
│  Host Machine                               │
│                                             │
│  ~/claw-cage/                               │
│  ├── .env              (secrets)            │
│  ├── docker-compose.yml (hardened stack)    │
│  └── iptables-rules.sh (LAN isolation)     │
│                                             │
│  ┌─────────────────────────────────┐        │
│  │  Docker (claw-net 172.30.0.0/24)│        │
│  │                                 │        │
│  │  ┌───────────────────────┐      │        │
│  │  │  OpenClaw (official)  │      │        │
│  │  │  127.0.0.1:18789     │      │        │
│  │  └───────────────────────┘      │        │
│  │         │                       │        │
│  └─────────┼───────────────────────┘        │
│            │                                │
│  iptables DOCKER-USER                       │
│    ✓ Internet (APIs, services)              │
│    ✗ LAN (192.168.x.x, 10.x.x.x)          │
└─────────────────────────────────────────────┘
```

## License

ISC
