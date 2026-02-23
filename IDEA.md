# 🦞🔒 claw-cage

> Secure, portable, Docker-first OpenClaw infrastructure template — designed for self-hosted ARM64 environments with minimal resources.

---

## 1. Vision & Elevator Pitch

**claw-cage** is an infrastructure project that deploys a secure, isolated OpenClaw instance with a single `curl` command. Zero dependencies on the target machine beyond `bash`, `curl`, and `docker`.

```bash
curl -fsSL https://raw.githubusercontent.com/<owner>/claw-cage/main/install.sh | bash
cd ~/claw-cage
nano .env        # fill in API keys and channel config
make first-run   # OpenClaw onboarding
make up          # start the containers
```

The goal: turn OpenClaw into a **remote conversational relay for Claude Code**, controllable from WhatsApp or Telegram, with a defense-first security posture — specifically local network isolation, which is the primary attack vector in existing OpenClaw deployments.

**What claw-cage is NOT:**
- It's not a fork of OpenClaw
- It's not a standalone tool — it's an infra/config layer that wraps OpenClaw
- It's not a product — it's a personal deployment template

---

## 2. Core Architectural Principle: Two Separate Worlds

### 2.1 The Source Repo (dev side)

This is the GitHub repo you clone to **develop** claw-cage. It contains:
- Node.js code (scripts, tests, dev tooling)
- BMAD files (`.bmad/`)
- Deployment source files (the `deploy/` folder)
- The `install.sh` source
- Tests, linting, CI

**This repo is built with Claude Code.** It lives on your dev machine (Mac, PC). It requires Node.js, Git, and all the usual dev tooling.

### 2.2 The Deployment Artifact (target machine side)

This is what the machine that will **run** OpenClaw receives (Freebox Delta, Raspberry Pi, VPS...). It receives **only** the runtime-necessary files via `install.sh`:
- `docker-compose.yml`
- `.env.example`
- `Makefile`
- `config/openclaw.json.template`
- `config/iptables-rules.sh`
- `scripts/first-run.sh`
- `scripts/init-vm.sh`
- `scripts/upgrade.sh`

**The target machine needs neither Node.js, nor Git, nor npm.** Just `bash`, `curl`, and `docker`. This is the same pattern OpenClaw itself uses for installation (`curl | bash`).

### 2.3 The Bridge Between Both Worlds

```
┌─────────────────────────────────────────────────────────────┐
│                    SOURCE REPO (dev)                        │
│                                                             │
│  claw-cage/                                                 │
│  ├── src/                    # Node.js code, tooling        │
│  ├── tests/                  # Tests                        │
│  ├── .bmad/                  # BMAD files                   │
│  ├── deploy/                 # ← DEPLOYMENT ARTIFACT        │
│  │   ├── docker-compose.yml  #    Files that will be        │
│  │   ├── .env.example        #    downloaded by curl        │
│  │   ├── Makefile            #    onto the target machine   │
│  │   ├── config/             #                              │
│  │   └── scripts/            #                              │
│  ├── install.sh              # Install script (curl entry)  │
│  ├── package.json            # Dev dependencies             │
│  └── PROJECT_BRIEF.md        # This document                │
│                                                             │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   │  curl -fsSL .../install.sh | bash
                   │  (downloads only deploy/*)
                   ▼
┌─────────────────────────────────────────────────────────────┐
│               TARGET MACHINE (runtime)                      │
│               Prerequisites: bash + curl + docker           │
│                                                             │
│  ~/claw-cage/                                               │
│  ├── docker-compose.yml                                     │
│  ├── .env.example → .env (configured by user)               │
│  ├── Makefile                                               │
│  ├── config/                                                │
│  │   ├── openclaw.json.template                             │
│  │   ├── iptables-rules.sh                                  │
│  │   └── skills-whitelist.txt                               │
│  └── scripts/                                               │
│      ├── init-vm.sh                                         │
│      ├── first-run.sh                                       │
│      └── upgrade.sh                                         │
│                                                             │
│  No node_modules/, no .git/, no src/                        │
│  Just the runtime files.                                    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 2.4 Update Flow

**Dev side:** you evolve the repo, push to GitHub.

**Target machine side:** `make upgrade` (or `~/claw-cage/scripts/upgrade.sh`) re-downloads the deploy files from GitHub and restarts the containers. No `git pull`, no `npm install`. Just `curl` + `docker compose up -d`.

```bash
# What upgrade.sh does under the hood:
REPO="https://raw.githubusercontent.com/<owner>/claw-cage/main"
for f in docker-compose.yml Makefile config/openclaw.json.template config/iptables-rules.sh; do
  curl -fsSL "$REPO/deploy/$f" -o "$f"
done
docker compose pull
docker compose up -d
# .env is NEVER overwritten (it contains local secrets)
```

---

## 3. Context & Problem

### 3.1 Primary Use Case

The user is a developer-architect working on Claude Code projects (BMAD method). They want to interact with their Claude Code sessions **remotely from their phone** (WhatsApp/Telegram) when not at their machine. Interaction happens at **human speed** (no autonomous loops), which reduces token consumption and the risk of unsupervised actions.

### 3.2 Why a New Repo?

Existing Docker solutions for OpenClaw don't cover all the constraints:

| Existing repo | What it does well | What's missing |
|---|---|---|
| `coollabsio/openclaw` | Multi-arch ARM64 image, auto-rebuild | No network hardening, no dev/deploy separation |
| `phioranex/openclaw-docker` | Simple, pre-built | No security hardening |
| `andreesg/openclaw-docker-config` | Good infra/config separation, backup sidecar | Coupled to Hetzner/Terraform, not portable, requires git on target |
| `openclaw/openclaw-ansible` | Full hardening (Tailscale, UFW) | Ansible = complexity, not Docker-first, requires heavy tooling on target |

**None** of these projects offer a `curl | bash` install that drops a minimal deployment artifact on a bare machine.

### 3.3 Primary Hardware Constraint

**Freebox Delta (stock):**
- CPU: ARM64 (aarch64), 2 vCPUs max per VM
- RAM: ~957 MB max per VM
- Storage: Internal SSD/HDD
- Network: Bridge mode (local IP on LAN)
- VM OS: Debian 12 ARM64 headless (recommended)
- Always on, accessible 24/7

**Realistic RAM budget:**
```
Debian 12 headless minimal   ~80 MB
Docker Engine                 ~50 MB
OpenClaw gateway container   ~300-400 MB
Swap (2 GB file)             safety buffer
─────────────────────────────
Estimated total              ~430-530 MB (out of 957 MB available)
Remaining headroom           ~400 MB (OK with swap)
```

---

## 4. Functional Requirements

### 4.1 Core — MVP

- [ ] **F1 — Curl Install**: `curl -fsSL .../install.sh | bash` drops the deployment files into `~/claw-cage/` on a bare machine (bash + curl + docker required, nothing else)
- [ ] **F2 — Configure & Run**: After install, `cp .env.example .env` → fill in 3-4 variables → `make up` → OpenClaw running
- [ ] **F3 — Channel messaging**: WhatsApp AND Telegram support configurable via `.env` (one or both)
- [ ] **F4 — Persistence**: Config, OpenClaw memory, and workspace survive restarts/rebuilds via named Docker volumes
- [ ] **F5 — Auto-restart**: Container restarts automatically on VM boot (restart policy `unless-stopped` + systemd Docker)
- [ ] **F6 — Git-free upgrade**: `make upgrade` re-downloads deploy files from GitHub via curl and restarts containers. Local `.env` is never overwritten.

### 4.2 Security — Non-negotiable

- [ ] **S1 — Network isolation**: The OpenClaw container CANNOT scan or access the local network (LAN). Isolated Docker network with egress limited to required API domains (api.anthropic.com, api.openai.com, web.whatsapp.com, api.telegram.org, etc.)
- [ ] **S2 — Non-root**: Container runs as user `node` (UID 1000), not root
- [ ] **S3 — Minimal capabilities**: `cap_drop: ALL`, `security_opt: no-new-privileges`
- [ ] **S4 — Gateway loopback**: Gateway listens on loopback only, not exposed on LAN
- [ ] **S5 — mDNS disabled**: No discovery broadcast on local network
- [ ] **S6 — Skills whitelist**: Shell, browser, filesystem disabled by default. Only explicitly needed skills are enabled
- [ ] **S7 — Secrets out of Git**: All secrets in `.env` (gitignored), never in versioned files
- [ ] **S8 — File permissions**: Config and credentials at 600/700
- [ ] **S9 — Verified install script**: `install.sh` checks prerequisites (docker, bash version, arch) before downloading anything

### 4.3 Nice-to-have — Post-MVP

- [ ] **N1 — Backup sidecar**: Container that pushes the workspace to a private Git repo (inspired by andreesg)
- [ ] **N2 — Healthcheck**: Health endpoint + basic monitoring (uptime, RAM usage)
- [ ] **N3 — Watchtower**: Auto-update of the OpenClaw image (opt-in)
- [ ] **N4 — LiteLLM proxy**: Intermediate layer between OpenClaw and LLM providers for rate limiting, cost tracking, centralized logs
- [ ] **N5 — Version pinning**: `install.sh` accepts a `--version` argument to install a specific version of the deploy files

---

## 5. Technical Architecture

### 5.1 Source Repo Structure (dev side)

```
claw-cage/                           # GitHub repo — built with Claude Code
├── README.md                        # User guide (points to curl install)
├── PROJECT_BRIEF.md                 # This document
├── package.json                     # Dev dependencies (tests, linting, CI)
├── .gitignore
│
├── install.sh                       # curl | bash entry point
│                                    # Downloads deploy/* to ~/claw-cage/
│
├── deploy/                          # ★ DEPLOYMENT ARTIFACT ★
│   │                                # This entire folder is what the
│   │                                # target machine receives. Self-contained.
│   │
│   ├── docker-compose.yml           # Main stack (hardened)
│   ├── .env.example                 # Config template (all secrets)
│   ├── Makefile                     # make up, make logs, make upgrade...
│   │
│   ├── config/
│   │   ├── openclaw.json.template   # Hardened OpenClaw config
│   │   ├── iptables-rules.sh        # Firewall rules for network isolation
│   │   └── skills-whitelist.txt     # Explicitly allowed skills
│   │
│   └── scripts/
│       ├── init-vm.sh               # Debian VM setup (swap, Docker, systemd)
│       ├── first-run.sh             # First OpenClaw onboarding
│       └── upgrade.sh               # Re-download deploy/* + restart
│
├── src/                             # Node.js code (dev tooling)
│   ├── validate-config.js           # .env and openclaw.json validation
│   ├── generate-env.js              # Interactive .env generator
│   └── test-network-isolation.js    # Post-deploy network isolation test
│
├── tests/                           # Tests
│   ├── install.test.sh              # Install script test
│   ├── compose.test.sh              # docker-compose test
│   └── security.test.sh             # Network isolation test
│
├── docs/
│   ├── FREEBOX_SETUP.md             # Freebox Delta VM specific guide
│   ├── SECURITY.md                  # Threat model and mitigations
│   ├── CHANNELS.md                  # WhatsApp / Telegram setup guide
│   ├── CONTRIBUTING.md              # Contribution guide
│   └── TROUBLESHOOTING.md           # Common issues
│
└── .bmad/                           # BMAD files for Claude Code
    ├── prd.md
    ├── architecture.md
    └── stories/
```

### 5.2 Target Machine Structure (after curl install)

```
~/claw-cage/                         # Dropped by install.sh — NOT a git repo
├── docker-compose.yml
├── .env.example                     # → copied to .env by user
├── .env                             # Local secrets (NEVER overwritten by upgrade)
├── Makefile
├── config/
│   ├── openclaw.json.template
│   ├── iptables-rules.sh
│   └── skills-whitelist.txt
└── scripts/
    ├── init-vm.sh
    ├── first-run.sh
    └── upgrade.sh
```

### 5.3 The install.sh — Contract and Behavior

The install script is the key deliverable of claw-cage. It must be:
- **Idempotent**: can be re-run without breaking anything
- **Defensive**: checks prerequisites, fails cleanly with clear messages
- **Respectful**: never touches an existing `.env`, never deletes anything

**Contract pseudo-code:**
```bash
#!/bin/bash
set -euo pipefail

REPO_URL="https://raw.githubusercontent.com/<owner>/claw-cage/main"
INSTALL_DIR="${CLAW_CAGE_DIR:-$HOME/claw-cage}"
VERSION="${1:-main}"  # Supports --version for future pinning

# 1. Check prerequisites: docker, curl, docker compose v2, arch
# 2. Display detected arch and destination
# 3. Create directories ~/claw-cage/{config,scripts}
# 4. Download each file from deploy/ to ~/claw-cage/
# 5. chmod +x on scripts
# 6. If .env doesn't exist: copy .env.example → .env (chmod 600)
#    If .env exists: don't touch it, display a message
# 7. Display next steps (cd, nano .env, make first-run, make up)
```

### 5.4 Docker Stack

```
┌─────────────────────────────────────────────┐
│          Docker Network: claw-net           │
│          (isolated, filtered egress)        │
│                                             │
│  ┌───────────────────────────────────────┐  │
│  │      openclaw-gateway                 │  │
│  │      image: ghcr.io/openclaw/         │  │
│  │             openclaw:latest           │  │
│  │      user: 1000:1000                  │  │
│  │      cap_drop: ALL                    │  │
│  │      security_opt: no-new-privileges  │  │
│  │      restart: unless-stopped          │  │
│  │      ports: 127.0.0.1:18789:18789    │  │
│  │                                       │  │
│  │      volumes:                         │  │
│  │        - claw-config:/home/node/      │  │
│  │            .openclaw                  │  │
│  │        - claw-workspace:/home/node/   │  │
│  │            .openclaw/workspace        │  │
│  └───────────────────────────────────────┘  │
│                                             │
│  ┌───────────────────────────────────────┐  │
│  │      openclaw-cli (run profile)       │  │
│  │      For onboarding and one-off       │  │
│  │      admin commands                   │  │
│  └───────────────────────────────────────┘  │
│                                             │
└─────────────────────────────────────────────┘

Allowed egress only:
  → api.anthropic.com:443
  → api.openai.com:443
  → web.whatsapp.com:443 / *.whatsapp.net:443
  → api.telegram.org:443
  → ghcr.io:443 (pull images)
  → github.com:443 (git clone project repos)

Blocked egress:
  → 192.168.0.0/16 (local network)
  → 10.0.0.0/8 (private networks)
  → 172.16.0.0/12 (private networks, excluding Docker internal)
```

### 5.5 Data Flow

```
Phone (WhatsApp/Telegram)
        │
        ▼ (internet, E2E encrypted / TLS)
┌───────────────────┐
│  WA/TG Servers    │
└───────┬───────────┘
        │ (outbound WebSocket from container)
        ▼
┌───────────────────────────────┐
│  claw-cage (Freebox Delta)    │
│  Debian VM → Docker           │
│  openclaw-gateway container   │
│       │                       │
│       ▼                       │
│  Claude API (Anthropic)       │
│  → Response → WA/TG          │
└───────────────────────────────┘
```

---

## 6. Technical Constraints

### 6.1 Hard Constraints — Target Machine

| Constraint | Value | Impact |
|---|---|---|
| Runtime prerequisites | bash + curl + docker (NOTHING else) | No Node.js, no Git, no Python on target |
| CPU architecture | ARM64 (aarch64) + x86_64 | Multi-arch Docker image, install.sh detects arch |
| Max VM RAM (Freebox) | 957 MB | Lightweight image mandatory, 2 GB swap needed |
| Max vCPUs (Freebox) | 2 | Use pre-built images only |
| VM networking | Bridge mode, static LAN IP | Accessible via SSH from LAN |
| Storage | Freebox internal HDD/SSD | Moderate I/O |
| VM OS | Debian 12 ARM64 headless | No GUI, CLI/SSH only |
| Connectivity | Internet via NAT | Egress OK, no ingress without port forwarding |

### 6.2 Hard Constraints — Source Repo (dev)

| Constraint | Value | Impact |
|---|---|---|
| Dev language | Node.js | Dev tooling, tests, validation, CI |
| Dev tool | Claude Code (BMAD) | Repo contains `.bmad/` to drive development |
| Strict separation | `deploy/` is self-contained | No file in `deploy/` may depend on `src/`, `node_modules/`, or the Git repo |
| Idempotent install.sh | Can be re-run without breaking | Never deletes anything, never overwrites `.env` |

### 6.3 Soft Constraints

- **Portability**: `deploy/` must work on any machine with Docker (x86_64 or ARM64). Freebox is the first target but not the only one.
- **Simplicity**: A user should be able to deploy in under 15 minutes after the curl.
- **Maintainability**: `make upgrade` updates without data loss and without additional tooling.

---

## 7. Threat Model (Summary)

### 7.1 Risk Vectors Specific to the Setup

| Threat | Risk | claw-cage Mitigation |
|---|---|---|
| OpenClaw scans LAN and discovers devices | **Critical** — NAS, other VMs, Freebox IoT | S1: isolated Docker network, filtered egress, RFC1918 blocking |
| Prompt injection via content read by agent | **High** — malicious email/web page could execute commands | S6: shell/browser/filesystem skills disabled by default |
| API key leakage | **High** — Anthropic/OpenAI token theft | S7: secrets in .env (chmod 600), never in container image |
| Container escape → host access | **Medium** — Docker kernel vulnerability | S2/S3: non-root, dropped capabilities, no-new-privileges |
| Unauthorized gateway access | **Medium** — someone on LAN accesses dashboard | S4: loopback only, token auth |
| Malicious skills/extensions | **High** — documented trojans in the ecosystem | S6: explicit whitelist, autoUpdate: false, pinned versions |
| mDNS broadcast reveals OpenClaw existence | **Low** — info disclosure surface | S5: mDNS disabled |
| Compromised install.sh (supply chain) | **Medium** — man-in-the-middle on curl | S9: HTTPS only, checksum verification (post-MVP) |

---

## 8. Architecture Decision Records (ADRs)

### ADR-001: Strict Dev / Deploy Separation (Two Worlds)
**Context**: The repo is developed with Claude Code (Node.js, BMAD). But the target machine is a minimal Debian VM that should only have bash + curl + docker.
**Decision**: The repo contains a `deploy/` folder that is the self-contained deployment artifact. The `install.sh` only downloads that folder. No file in `deploy/` may depend on Node.js, npm, git, or the source repo.
**Consequence**: Every script in `deploy/` is pure bash. Node.js code in `src/` is reserved for dev tooling (validation, tests, CI). This separation is the most important architectural constraint of the project.

### ADR-002: Distribution via curl | bash Rather Than git clone or npm
**Context**: The target machine must have no dependencies beyond bash/curl/docker. A `git clone` requires git. An `npx` requires Node.js. Both add attack surface and complexity.
**Decision**: Distribution via `curl -fsSL .../install.sh | bash` which downloads files individually from GitHub raw.
**Consequence**: Updates also happen via curl (`make upgrade` → `scripts/upgrade.sh`). No Git version management on the target machine. Versioning is handled on the source repo side (GitHub tags).

### ADR-003: Use Official Pre-built OpenClaw Image Rather Than Build From Source
**Context**: The Freebox Delta has 957 MB of RAM and 2 vCPUs. Building OpenClaw from source requires more RAM and CPU time.
**Decision**: Use `ghcr.io/openclaw/openclaw:latest` (multi-arch, includes ARM64).
**Consequence**: No customization of the OpenClaw Dockerfile itself. Adaptations are done via config, env vars, and volumes.

### ADR-004: Custom Docker Network With Filtered Egress Rather Than network: none
**Context**: `network: none` would prevent OpenClaw from contacting LLM APIs and WhatsApp/Telegram servers.
**Decision**: Create a custom Docker bridge network (`claw-net`) with iptables rules blocking access to private networks (RFC1918) while allowing egress to required API domains.
**Consequence**: Requires an iptables script executed on the host. This script is part of `deploy/config/` and is pure bash.

### ADR-005: Named Docker Volumes Rather Than Bind Mounts
**Context**: Bind mounts expose host paths and can create UID permission issues.
**Decision**: Use named Docker volumes (`claw-config`, `claw-workspace`) for persistence.
**Consequence**: Backup requires `docker cp` or a sidecar rather than a simple `rsync`. Acceptable tradeoff for portability.

### ADR-006: Debian 12 Headless as Freebox VM OS
**Context**: The Freebox offers Ubuntu and Debian as pre-installed options.
**Decision**: Debian 12 (Bookworm) for its lightweight RAM footprint (~80 MB idle vs ~120 MB Ubuntu) and stability.
**Consequence**: Compatible with OpenClaw's base image (`node:22-bookworm`).

---

## 9. Execution Plan (Stories)

### Sprint 1 — Skeleton + Install Script (tonight)

**Story 1.1**: Initialize the repo structure with the `deploy/` and `src/` separation (section 5.1). Create empty or minimal-content files so the structure exists.

**Story 1.2**: Create complete `install.sh` (contract described in section 5.3):
- Prerequisite checks (docker, curl, compose v2, arch)
- Download `deploy/*` files to `~/claw-cage/`
- Create `.env` from `.env.example` (without overwriting existing)
- Clear help messages on output
- Idempotent

**Story 1.3**: Create `deploy/docker-compose.yml` with:
- `openclaw-gateway` service (official image, full hardening S1-S5)
- `openclaw-cli` service (run profile, for one-off commands)
- `claw-net` network (isolated bridge)
- Named volumes
- All variables from `.env`

**Story 1.4**: Create `deploy/.env.example` with all parameters documented via inline comments.

**Story 1.5**: Create `deploy/Makefile` with: `up`, `down`, `logs`, `status`, `first-run`, `upgrade`, `shell`.

**Story 1.6**: Create `deploy/scripts/upgrade.sh` — re-downloads deploy files, preserves `.env`, restarts containers.

### Sprint 2 — Network Security

**Story 2.1**: Create `deploy/config/iptables-rules.sh` — RFC1918 blocking rules for the Docker network.

**Story 2.2**: Create `deploy/config/openclaw.json.template` — hardened config (gateway loopback, mDNS off, skills whitelist, strict sandbox).

**Story 2.3**: Create `deploy/config/skills-whitelist.txt` — explicit, commented list of allowed skills.

**Story 2.4**: Write `docs/SECURITY.md` — threat model and mitigations documentation.

### Sprint 3 — VM & Onboarding

**Story 3.1**: Create `deploy/scripts/init-vm.sh` — Debian VM initialization script (2 GB swap, Docker Engine, systemd enable, minimal SSH hardening).

**Story 3.2**: Create `deploy/scripts/first-run.sh` — wrapper for initial OpenClaw onboarding (launches interactive CLI).

**Story 3.3**: Write `docs/FREEBOX_SETUP.md` — step-by-step guide for creating the VM on Freebox OS.

### Sprint 4 — Channels & Testing

**Story 4.1**: Write `docs/CHANNELS.md` — WhatsApp and Telegram setup guide.

**Story 4.2**: Test full deployment on a real (or emulated) ARM64 machine.

**Story 4.3**: Write `docs/TROUBLESHOOTING.md` based on encountered issues.

### Sprint 5 — Dev Tooling (src/)

**Story 5.1**: Create `src/validate-config.js` — `.env` and `openclaw.json.template` validation.

**Story 5.2**: Create `tests/install.test.sh` — install script test in a simulated Docker environment.

**Story 5.3**: Create `tests/security.test.sh` — automated network isolation test (container cannot ping 192.168.x.x).

### Sprint 6 — Nice-to-have

**Story 6.1**: Add backup sidecar (N1).
**Story 6.2**: Add healthcheck (N2).
**Story 6.3**: Add opt-in Watchtower (N3).
**Story 6.4**: Version pinning in install.sh (N5).

---

## 10. Success Criteria (Definition of Done)

The MVP is achieved when:

1. ✅ `curl -fsSL .../install.sh | bash` installs claw-cage on a bare machine with only bash + curl + docker
2. ✅ After configuring `.env` and running `make up`, an OpenClaw instance is functional
3. ✅ The instance is reachable from WhatsApp or Telegram on the phone
4. ✅ The container CANNOT ping/access local network IPs (192.168.x.x)
5. ✅ The container restarts automatically after a VM reboot
6. ✅ `make upgrade` updates deploy files without overwriting `.env` and without requiring git/node
7. ✅ No secrets are present in versioned files
8. ✅ The `deploy/` folder contains ZERO Node.js dependencies — only bash, YAML, JSON, and Makefile

---

## 11. References & Sources

- [OpenClaw Docker docs](https://docs.openclaw.ai/install/docker)
- [OpenClaw Security docs](https://docs.openclaw.ai/gateway/security)
- [OpenClaw GitHub Packages (ARM64)](https://github.com/openclaw/openclaw/pkgs/container/openclaw) — Official ARM64 images
- [coollabsio/openclaw](https://github.com/coollabsio/openclaw) — Multi-arch Docker image, env var config patterns
- [openclaw/openclaw-ansible](https://github.com/openclaw/openclaw-ansible) — Network and system hardening patterns
- [andreesg/openclaw-docker-config](https://github.com/andreesg/openclaw-docker-config) — Infra/config separation, backup sidecar
- [Composio secure-openclaw guide](https://composio.dev/blog/secure-openclaw-moltbot-clawdbot-setup) — RAK Framework (Root, Agency, Keys)
- [OpenClaw hardening guide (3-tier)](https://aimaker.substack.com/p/openclaw-security-hardening-guide) — Progressive hardening
- [Five Steps to OpenClaw Hardening](https://medium.com/@C.Dalrymple/five-steps-to-openclaw-hardening-0d5cdfc4ea7b) — Security quick wins
- [OpenClaw host network issue #19827](https://github.com/openclaw/openclaw/issues/19827) — Context on sandbox network isolation