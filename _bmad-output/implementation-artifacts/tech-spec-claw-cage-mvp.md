---
title: 'claw-cage MVP — Secure OpenClaw Deployment Template'
slug: 'claw-cage-mvp'
created: '2026-02-23'
status: 'ready-for-dev'
stepsCompleted: [1, 2, 3, 4]
tech_stack: ['bash', 'docker', 'docker-compose', 'iptables', 'iptables-persistent']
files_to_modify: ['.gitignore', 'deploy/docker-compose.yml', 'deploy/.env.example', 'deploy/iptables-rules.sh', 'install.sh', 'README.md']
code_patterns: ['shell-script-strict (set -euo pipefail)', 'docker-compose-yaml', 'curl-raw-github-download', 'idempotent-install']
test_patterns: ['shell-test-in-docker', 'docker-compose-config-validate', 'iptables-rule-verify']
---

# Tech-Spec: claw-cage MVP — Secure OpenClaw Deployment Template

**Created:** 2026-02-23

## Overview

### Problem Statement

No existing OpenClaw Docker deployment provides LAN network isolation combined with a zero-dependency `curl | bash` install. Current solutions (coollabsio, phioranex, andreesg, openclaw-ansible) either require heavy tooling on the target machine (git, ansible, terraform) or skip network hardening entirely. This leaves OpenClaw with full access to the user's local network — the primary attack vector for a self-hosted AI agent running on a home network.

### Solution

A 3-file deployment artifact delivered via a single `curl | bash` command. The host receives only: `docker-compose.yml` (hardened stack), `.env` (secrets), and `iptables-rules.sh` (LAN isolation). The container runs the official OpenClaw image with Docker-level hardening (cap_drop ALL, non-root, no-new-privileges, loopback port) and host-level network isolation (iptables DOCKER-USER blocking RFC1918 ranges).

### Scope

**In Scope:**
- `.gitignore` — standard ignores + .env protection
- `deploy/docker-compose.yml` — official OpenClaw image, hardened security opts, claw-net bridge, named volume, loopback port, CLI run profile
- `deploy/.env.example` — multi-provider, multi-channel, well-commented
- `deploy/iptables-rules.sh` — DOCKER-USER RFC1918 blocking + iptables-persistent
- `install.sh` — idempotent, defensive, downloads 3 files
- `README.md` — install, configure, run, upgrade, SSH tunnel tuto

**Out of Scope:**
- openclaw.json hardened config (skills, sandbox, tools.deny) → v2
- Custom Docker image / Dockerfile → rejected (ADR-003)
- Makefile → rejected (ADR-009)
- init-vm.sh, upgrade.sh → deferred
- docs/CONTRIBUTING.md, TROUBLESHOOTING.md, CHANNELS.md → deferred
- Backup sidecar, healthcheck, Watchtower, LiteLLM → post-MVP

## Context for Development

### Codebase Patterns

- **Clean slate**: No existing implementation code. Only IDEA.md and package.json exist.
- **Shell scripts**: All deploy-side code is pure bash. `set -euo pipefail` everywhere. No Node.js, no Python on target.
- **Docker Compose**: Single YAML file, declarative stack. Uses profiles for CLI service.
- **Idempotent install**: install.sh can be re-run safely. Never overwrites .env. Always overwrites docker-compose.yml and iptables-rules.sh.
- **Two Worlds**: Source repo (dev) has Node.js/BMAD. Deploy artifact (target) is pure bash + Docker.

### Files to Reference

| File | Purpose |
| ---- | ------- |
| `_bmad-output/planning-artifacts/validation-decisions.md` | Source of truth for all architectural decisions |
| `IDEA.md` | Original spec (outdated in parts — validation-decisions.md overrides) |
| `package.json` | GitHub repo URL: `VelocityPulse/claw-cage` |

### Technical Decisions

- **ADR-003**: Official `ghcr.io/openclaw/openclaw:latest` image. No custom Dockerfile.
- **ADR-004**: Docker network `claw-net` (172.30.0.0/24) + iptables DOCKER-USER blocking RFC1918.
- **ADR-007**: Generic OpenClaw deployment, NOT tied to Claude Code.
- **ADR-009**: No Makefile. User runs `docker compose` directly.
- **ADR-010**: MVP security = iptables + docker-compose hardening only.
- **ADR-011**: iptables-persistent for rule persistence across reboots.
- **D4-3**: Dashboard on loopback 127.0.0.1. Access via SSH tunnel. Tuto Windows included.
- **D6-4**: Upgrade = re-run install.sh + `docker compose pull && docker compose up -d`.

## Implementation Plan

### Tasks

Ordered by dependency (lowest-level first).

---

- [ ] **Task 1: .gitignore**
  - File: `.gitignore`
  - Action: Create
  - Details:
    - Ignore `.env` (CRITICAL — contains secrets)
    - Ignore `node_modules/`
    - Ignore `.DS_Store`
    - Ignore `*.log`
    - Do NOT ignore `.env.example` (it must be versioned)

---

- [ ] **Task 2: docker-compose.yml**
  - File: `deploy/docker-compose.yml`
  - Action: Create
  - Details:
    - Service `openclaw`:
      - `image: ghcr.io/openclaw/openclaw:latest`
      - `user: "1000:1000"`
      - `cap_drop: [ALL]`
      - `security_opt: [no-new-privileges:true]`
      - `restart: unless-stopped`
      - `ports: ["127.0.0.1:18789:18789"]`
      - `env_file: .env`
      - `volumes: [claw-data:/home/node/.openclaw]`
      - `networks: [claw-net]`
    - Service `openclaw-cli`:
      - `image: ghcr.io/openclaw/openclaw:latest`
      - `profiles: [cli]`
      - `stdin_open: true`
      - `tty: true`
      - `user: "1000:1000"`
      - `cap_drop: [ALL]`
      - `security_opt: [no-new-privileges:true]`
      - `env_file: .env`
      - `volumes: [claw-data:/home/node/.openclaw]`
      - `networks: [claw-net]`
    - Network `claw-net`:
      - `driver: bridge`
      - `ipam.config: [{subnet: 172.30.0.0/24}]`
      - `enable_ipv6: false` (CRITICAL — prevents IPv6 bypass of iptables rules)
    - Volume `claw-data`: (default driver)

---

- [ ] **Task 3: .env.example**
  - File: `deploy/.env.example`
  - Action: Create
  - Details:
    - Header comment: project name, purpose, link to README
    - Section `# === LLM Providers (at least one required) ===`
      - `ANTHROPIC_API_KEY=` (uncommented, empty — primary)
      - `# OPENAI_API_KEY=` (commented)
      - `# OPENROUTER_API_KEY=` (commented)
      - `# GEMINI_API_KEY=` (commented)
      - `# GROQ_API_KEY=` (commented)
      - `# OLLAMA_BASE_URL=http://host.docker.internal:11434` (commented, for local models)
    - Section `# === Gateway ===`
      - `# OPENCLAW_GATEWAY_TOKEN=` (commented — auto-generated if empty)
      - `OPENCLAW_GATEWAY_BIND=loopback`
      - `OPENCLAW_DISABLE_BONJOUR=1`
    - Section `# === Channels (optional) ===`
      - `# TELEGRAM_BOT_TOKEN=` (commented, with inline doc)
      - `# WHATSAPP_ENABLED=false` (commented)
    - Section `# === Performance (constrained hardware) ===`
      - `# NODE_OPTIONS=--max-old-space-size=384` (commented, with note: "Uncomment on machines with < 1 GB RAM")
    - Every variable has a one-line comment explaining its purpose

---

- [ ] **Task 4: iptables-rules.sh**
  - File: `deploy/iptables-rules.sh`
  - Action: Create
  - Details:
    - `#!/bin/bash` + `set -euo pipefail`
    - Check `EUID -ne 0` → print "This script must be run as root (sudo)" and exit 1
    - Define `CLAW_SUBNET="172.30.0.0/24"`
    - Print "Applying claw-cage network isolation rules..."
    - Flush existing claw-cage rules then reinsert (idempotent — clean slate on each run):
      - First: delete any existing claw-cage rules from DOCKER-USER (grep + delete loop, ignore errors)
      - Then insert rules in correct order (first inserted = last evaluated):
      - `iptables -I DOCKER-USER -s $CLAW_SUBNET -d 192.168.0.0/16 -j DROP`
      - `iptables -I DOCKER-USER -s $CLAW_SUBNET -d 10.0.0.0/8 -j DROP`
      - `iptables -I DOCKER-USER -s $CLAW_SUBNET -d 172.16.0.0/12 -j DROP`
      - CRITICAL — Allow claw-net internal traffic (172.30.0.0/24 is inside 172.16.0.0/12):
      - `iptables -I DOCKER-USER 1 -s $CLAW_SUBNET -d $CLAW_SUBNET -j ACCEPT`
      - Allow established/related connections:
      - `iptables -I DOCKER-USER 1 -s $CLAW_SUBNET -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT`
      - Allow DNS to Docker's embedded DNS (127.0.0.11):
      - `iptables -I DOCKER-USER 1 -s $CLAW_SUBNET -d 127.0.0.11 -p udp --dport 53 -j ACCEPT`
    - Final rule order in DOCKER-USER (top to bottom):
      1. ACCEPT DNS to 127.0.0.11
      2. ACCEPT ESTABLISHED,RELATED
      3. ACCEPT claw-subnet to claw-subnet
      4. DROP claw-subnet to 172.16.0.0/12
      5. DROP claw-subnet to 10.0.0.0/8
      6. DROP claw-subnet to 192.168.0.0/16
    - Install iptables-persistent: `apt-get install -y iptables-persistent`
    - Save rules: `netfilter-persistent save`
    - Print confirmation with summary of rules applied

---

- [ ] **Task 5: install.sh**
  - File: `install.sh`
  - Action: Create
  - Details:
    - `#!/bin/bash` + `set -euo pipefail`
    - Variables:
      - `REPO="https://raw.githubusercontent.com/VelocityPulse/claw-cage/main"`
      - `INSTALL_DIR="${CLAW_CAGE_DIR:-$HOME/claw-cage}"`
    - Color output helpers (green checkmark, red X) — optional but nice for public repo
    - Check bash version >= 4: `[[ "${BASH_VERSINFO[0]}" -lt 4 ]]` → error
    - Check curl: `command -v curl >/dev/null` → error
    - Check docker: `command -v docker >/dev/null` → error
    - Check docker compose v2: `docker compose version >/dev/null 2>&1` → error with hint "Install Docker Compose v2 plugin"
    - Detect and print architecture: `uname -m` (info only, not blocking)
    - Print "Installing claw-cage to $INSTALL_DIR..."
    - `mkdir -p "$INSTALL_DIR"`
    - Download 3 files:
      - `curl -fsSL "$REPO/deploy/docker-compose.yml" -o "$INSTALL_DIR/docker-compose.yml"`
      - `curl -fsSL "$REPO/deploy/.env.example" -o "$INSTALL_DIR/.env.example"`
      - `curl -fsSL "$REPO/deploy/iptables-rules.sh" -o "$INSTALL_DIR/iptables-rules.sh"`
    - `chmod +x "$INSTALL_DIR/iptables-rules.sh"`
    - If `.env` does not exist:
      - `cp "$INSTALL_DIR/.env.example" "$INSTALL_DIR/.env"`
      - `chmod 600 "$INSTALL_DIR/.env"`
      - Print ".env created — edit it with your API keys"
    - Else: print ".env already exists — not overwriting"
    - Print next steps block:
      ```
      cd ~/claw-cage
      nano .env                              # Add your API keys
      sudo bash iptables-rules.sh            # Network isolation (one-time)
      docker compose up -d                   # Start OpenClaw
      ```

---

- [ ] **Task 6: README.md**
  - File: `README.md`
  - Action: Create
  - Details:
    - **Header**: claw-cage name + one-line description + badges (optional)
    - **What is claw-cage**: 2-3 sentences. Secure OpenClaw deployment template. LAN isolation. Zero dependencies beyond bash+curl+docker.
    - **What is claw-cage NOT**: Not a fork, not a standalone tool, not tied to any specific LLM.
    - **Quick Start**: 4 commands (curl install, edit .env, iptables, docker compose up)
    - **Prerequisites**: bash >= 4, curl, docker, docker compose v2
    - **Configuration**: Table of .env variables with descriptions
    - **Security**: What claw-cage does (LAN isolation via iptables, Docker hardening). Brief explanation of DOCKER-USER chain.
    - **Accessing the Dashboard**: SSH tunnel instructions
      - Linux/Mac: `ssh -L 18789:127.0.0.1:18789 user@<vm-ip>` then open `localhost:18789`
      - Windows PowerShell: same command (OpenSSH built into Windows 10+)
      - Windows PuTTY: step-by-step (Connection > SSH > Tunnels > Source port 18789, Destination 127.0.0.1:18789)
    - **Upgrade**: `curl install.sh | bash && docker compose pull && docker compose up -d`
    - **Uninstall**: `docker compose down -v && rm -rf ~/claw-cage` + iptables cleanup command
    - **Architecture**: Minimal diagram (host with 3 files → Docker → OpenClaw, iptables blocking LAN)
    - **License**: ISC (from package.json)

---

### Acceptance Criteria

- [ ] **AC-1: Fresh install works end-to-end**
  - Given a bare machine with bash >= 4, curl, and docker with compose v2
  - When user runs `curl -fsSL .../install.sh | bash`
  - Then `~/claw-cage/` is created containing `.env` (mode 600), `docker-compose.yml`, `.env.example`, and `iptables-rules.sh` (executable)

- [ ] **AC-2: docker-compose.yml is correctly hardened**
  - Given the docker-compose.yml file
  - When parsed by `docker compose config`
  - Then the openclaw service uses `ghcr.io/openclaw/openclaw:latest`, has `cap_drop: [ALL]`, `user: "1000:1000"`, `security_opt: [no-new-privileges:true]`, port `127.0.0.1:18789:18789`, and network `claw-net` with subnet `172.30.0.0/24`

- [ ] **AC-3: iptables blocks LAN, allows internet**
  - Given `iptables-rules.sh` has been run with sudo
  - When the OpenClaw container tries to reach `192.168.1.1`
  - Then the connection is dropped
  - And when the container tries to reach an external API (e.g., `api.anthropic.com`)
  - Then the connection succeeds

- [ ] **AC-4: iptables rules persist across reboot**
  - Given `iptables-rules.sh` has been run with sudo
  - When the machine reboots
  - Then `iptables -L DOCKER-USER` still shows the RFC1918 drop rules

- [ ] **AC-5: Idempotent install preserves .env**
  - Given claw-cage is installed and `.env` has been edited by the user
  - When user re-runs `install.sh`
  - Then `.env` is NOT overwritten (user secrets preserved)
  - And `docker-compose.yml` IS updated to latest version
  - And `iptables-rules.sh` IS updated to latest version

- [ ] **AC-6: Upgrade preserves data**
  - Given a running claw-cage instance with data in claw-data volume
  - When user runs `install.sh` + `docker compose pull` + `docker compose up -d`
  - Then the stack restarts with updated image
  - And claw-data volume content is preserved

- [ ] **AC-7: install.sh fails gracefully on missing prerequisites**
  - Given a machine without docker installed
  - When user runs `install.sh`
  - Then the script exits with a clear error message naming the missing prerequisite
  - And no files are downloaded or created

## Additional Context

### Dependencies

- Official OpenClaw Docker image: `ghcr.io/openclaw/openclaw:latest` (multi-arch: amd64 + arm64)
- iptables + iptables-persistent (Debian/Ubuntu — `apt-get install`)
- Docker Engine with Compose v2 plugin
- No Node.js, no Git, no Python required on target

### Testing Strategy

- **install.sh**: Run in a clean Debian 12 Docker container to simulate bare machine. Test: prereq checks fail gracefully, files created correctly, .env permissions, idempotency (run twice).
- **docker-compose.yml**: Validate with `docker compose config`. Inspect running container for security opts with `docker inspect`.
- **iptables-rules.sh**: Apply rules, verify with `iptables -L DOCKER-USER -n`. Test from within container: `curl -s --connect-timeout 5 192.168.1.1` should fail, `curl -s https://api.anthropic.com` should succeed.
- **README.md**: Manual review for accuracy and completeness.

### Notes

- IDEA.md is outdated. `validation-decisions.md` is the source of truth.
- OpenClaw uses ~530 MB RAM. On Freebox Delta (957 MB), 1 channel = tight but works, 2 channels = OOM risk. Document `NODE_OPTIONS=--max-old-space-size=384` in .env.example as mitigation.
- The iptables rules use flush-and-reinsert (not check-then-insert) to guarantee correct ordering on re-run.
- The DOCKER-USER chain only affects Docker traffic. The host machine's own network access is unaffected.
- CRITICAL: 172.30.0.0/24 (claw-net) is inside 172.16.0.0/12. An explicit ACCEPT for claw-subnet-to-claw-subnet MUST appear before the /12 DROP rule, otherwise inter-container and Docker DNS traffic is blocked.
- IPv6 is disabled on claw-net (`enable_ipv6: false`) because iptables rules are IPv4-only. Without this, containers could bypass isolation via IPv6.
- Docker's embedded DNS resolver (127.0.0.11) is used for container DNS. No LAN DNS dependency. An explicit ACCEPT rule for UDP/53 to 127.0.0.11 ensures DNS works even with DROP rules active.
