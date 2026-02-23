# Validation IDEA.md — Registre des Décisions

> Ce document capture toutes les décisions prises lors de la validation de l'IDEA.md.
> Il sert de référence pour le dev et pour la rédaction de la documentation finale.
> Date de début : 2026-02-23

---

## Domaine 1 — Vision & Scope

### D1-1 : Identité du projet
- **Décision** : claw-cage est un template de déploiement sécurisé pour OpenClaw, **générique et agnostique de Claude Code**.
- **Justification** : OpenClaw supporte 15+ fournisseurs LLM, 10+ canaux de messagerie, 5700+ skills communautaires. Lier claw-cage à Claude Code masque 90% de la valeur. Le relais Claude Code est un cas d'usage parmi des dizaines.
- **Impact** : README, vision, config template et skills whitelist doivent être génériques.
- **ADR associé** : ADR-007 (nouveau)

### D1-2 : Reclassification de F3 (Channel messaging)
- **Décision** : F3 n'est pas une feature claw-cage. C'est de la configuration OpenClaw (variables .env + règles egress).
- **Justification** : claw-cage ne code rien pour les channels. Il configure et documente.
- **Impact** : Pas de code spécifique channels. La config .env.example expose les vars nécessaires, les règles egress autorisent les domaines WA/TG.

### D1-3 : Positionnement public
- **Décision** : Repo public dès le départ sur GitHub.
- **Impact** : install.sh défensif, README soigné, .env.example bien commenté. Pas de CONTRIBUTING.md au MVP.

### D1-4 : Périmètre MVP validé
- **MVP** : install.sh, docker-compose.yml, .env.example, iptables-rules.sh, openclaw.json.template, skills-whitelist.txt, first-run.sh, README.md
- **Defer** : init-vm.sh, src/*.js (dev tooling), docs/CONTRIBUTING.md, docs/TROUBLESHOOTING.md, docs/CHANNELS.md

---

## Domaine 2 — Architecture "Two Worlds"

### D2-1 : Approche de déploiement — Image Docker custom
- **Décision** : Approche 2 — image Docker custom basée sur l'image officielle OpenClaw, publiée sur ghcr.io.
- **Justification** : Minimise les fichiers sur le host (3 fichiers vs 10), upgrade simplifié (`docker compose pull`), UX propre pour l'utilisateur.
- **Impact** : Dockerfile + GitHub Action CI/CD à maintenir dans le repo source.
- **ADR associé** : ADR-008 (nouveau) — remplace partiellement ADR-003
- **Statut** : ⚠️ EN RÉÉVALUATION — voir D3-4

### D2-2 : Suppression du Makefile
- **Décision** : Pas de Makefile. `make` n'est pas installé sur Debian bare.
- **Justification** : Le principe fondamental est bash + curl + docker, rien d'autre. L'interface utilisateur est `docker compose` directement.
- **Impact** : Suppression du Makefile de deploy/. Les commandes sont documentées dans le README.

### D2-3 : Structure source repo révisée
- **Décision** : La structure inclut Dockerfile, entrypoint.sh, config/ (baked dans l'image), deploy/ (3 fichiers host), et conserve package.json/src/ pour le dev BMAD.
- **Justification** : Séparation stricte maintenue. Node.js = dev only, invisible pour l'utilisateur final.

### D2-4 : Flow de mise à jour simplifié
- **Décision** : Upgrade = `docker compose pull && docker compose up -d`. Plus de re-téléchargement de fichiers via curl.
- **Justification** : Tout le hardening est dans l'image. Seuls .env et iptables restent sur le host et ne changent que rarement.

---

## Domaine 3 — Faisabilité Technique (en cours)

### D3-1 : Budget RAM réaliste
- **Constat** : Les estimations de l'IDEA sont trop optimistes. OpenClaw consomme ~530 MB (pas 300-400 MB). Avec 1 canal : ~770 MB sur 957 MB. Avec 2 canaux : ~870 MB (zone OOM).
- **Décision** : On documente les vrais chiffres. Pas d'over-engineering pour contourner la limite. Si ça passe pas sur la Freebox, next.
- **Mitigation documentée** : `NODE_OPTIONS="--max-old-space-size=384"` dans .env pour limiter le heap V8.

### D3-2 : Compatibilité ARM64
- **Constat** : Confirmé. L'image officielle publie des variantes ARM64. Pas de blocker connu.

### D3-3 : Swap + zram
- **Décision** : Prévoir 2 GB swap fichier + zram pour de meilleures performances. À documenter dans les instructions de setup VM (ou dans init-vm.sh quand il sera implémenté).

### D3-4 : Image custom vs image officielle + volumes
- **Constat** : L'image officielle supporte la config via env vars, volume mounts, et scripts d'init custom. OpenClaw réécrit openclaw.json au démarrage (gotcha connu).
- **Décision** : **Image officielle, pas de Dockerfile custom.**
- **Justification** : La vraie sécurité (isolation LAN) est côté HOST (iptables DOCKER-USER), pas dans l'image. Docker hardening (cap_drop, no-root) est dans docker-compose.yml. Image custom = gain marginal pour coût de maintenance élevé (CI/CD, registry, délai updates).
- **Impact** : Pas de Dockerfile, pas de GitHub Action build, pas de ghcr.io custom. L'upgrade = `docker compose pull` de l'image officielle directement.
- **ADR-003 rétabli** : utiliser l'image officielle telle quelle.
- **ADR-008 annulé** : plus d'image custom.
- **Retour à Option B** : image officielle + volumes montés. ~5 fichiers sur le host.

### D3-5 : Isolation réseau — mécanisme iptables DOCKER-USER
- **Constat** : Les règles iptables sont appliquées sur le host mais ne ciblent QUE le trafic Docker (chaîne DOCKER-USER). Le réseau de la machine hôte n'est PAS affecté.
- **Décision** : Utiliser la chaîne DOCKER-USER pour bloquer les plages RFC1918 (192.168.0.0/16, 10.0.0.0/8, 172.16.0.0/12) depuis le réseau Docker claw-net.
- **Impact** : Compatible avec machine perso (PC de dev) ET VM serveur. Le host garde 100% de son accès réseau local.

### D3-6 : Structure host révisée (post-décision D3-4)
- **Décision** : Le host reçoit ~5 fichiers au lieu de 3.
- **Structure** :
  ```
  ~/claw-cage/
  ├── .env                            ← secrets utilisateur
  ├── docker-compose.yml              ← stack + security opts
  ├── iptables-rules.sh               ← isolation réseau LAN
  ├── config/openclaw.json            ← config hardened (volume mount)
  └── config/skills-whitelist.txt     ← whitelist skills (volume mount)
  ```

---

## Domaine 4 — Modèle de Sécurité

### D4-1 : Exigences S1-S9 — validation individuelle

| Exigence | Statut | Décision |
|---|---|---|
| S1 — Isolation réseau | **Validé — simplifié** | Bloquer plages RFC1918 via DOCKER-USER. Pas de filtrage par domaine (over-engineering). |
| S2 — Non-root | **Validé** | `user: "1000:1000"` dans docker-compose.yml |
| S3 — Capabilities | **Validé** | `cap_drop: ALL` + `security_opt: no-new-privileges` dans docker-compose.yml |
| S4 — Gateway access | **Validé — révisé** | Écoute sur IP locale de la VM (pas loopback). Dashboard accessible depuis le LAN. Tuto Windows inclus dans docs. Auth par token OpenClaw. |
| S5 — mDNS | **Validé** | Config openclaw.json. Redondant avec S1 mais défense en profondeur. |
| S6 — Skills whitelist | **Validé** | Defense-in-depth. Pas critique grâce à S1. Config-level (contournable mais limité). |
| S7 — Secrets | **Validé** | .env gitignored, .env.example versionné. Standard. |
| S8 — Permissions | **Validé** | chmod 600 .env dans install.sh. |
| S9 — Install checks | **Validé** | install.sh vérifie docker, curl, compose v2, arch avant download. |

### D4-2 : Simplification du filtrage egress
- **Décision** : Pas de filtrage par domaine. Bloquer les plages privées (RFC1918), autoriser tout internet.
- **Justification** : iptables travaille avec des IPs, pas des domaines. Résolution DNS → IPs changeantes. Un proxy egress serait overkill. Le risque résiduel (accès internet complet) est acceptable — l'objectif premier est de protéger le LAN.

### D4-3 : S4 confirmé — Dashboard en loopback + SSH tunnel
- **Décision** : Le dashboard écoute sur `127.0.0.1:18789` (loopback strict). Accès via SSH tunnel uniquement.
- **Justification** : Sécurité maximale — le dashboard n'est jamais visible sur le LAN. SSH tunnel = chiffré + authentifié.
- **Impact** : Documentation avec tuto clé en main SSH tunnel pour Linux/Mac (terminal) et Windows (PowerShell + PuTTY).

---

## Domaine 6 — Script d'installation (install.sh)

### D6-1 : Contrat install.sh simplifié
- **Décision** : install.sh télécharge 3 fichiers (.env.example, docker-compose.yml, iptables-rules.sh), crée .env si inexistant. C'est tout.
- **Propriétés** : Idempotent (re-runnable), défensif (checks prerequisites), respectueux (jamais de sudo, jamais écraser .env).
- **Checks** : bash >= 4, curl, docker, docker compose v2. Architecture détectée et affichée (info, pas bloquant).

### D6-2 : iptables — pas de sudo dans install.sh
- **Décision** : install.sh ne lance jamais sudo. L'utilisateur exécute `sudo bash iptables-rules.sh` manuellement.
- **Justification** : Séparation claire. L'utilisateur sait ce qui nécessite des droits root.

### D6-3 : Persistance iptables via iptables-persistent
- **Décision** : Le script `iptables-rules.sh` applique les règles ET installe `iptables-persistent` (via apt) pour les sauvegarder. Exécution unique avec sudo.
- **Justification** : L'utilisateur lance le script une seule fois. Les règles survivent aux reboots automatiquement.
- **Impact** : Le script nécessite un système Debian/Ubuntu (apt). À documenter.

### D6-4 : Upgrade simplifié
- **Décision** : Pas de upgrade.sh séparé. Upgrade = re-run install.sh (idempotent) + docker compose pull.
- **Justification** : install.sh écrase docker-compose.yml et iptables-rules.sh (c'est voulu), ne touche jamais .env. Pas besoin d'un script dédié.

---

## Domaine 7 — Requirements Fonctionnels

### D7-1 : F1 Curl Install — validé simplifié
- 3 fichiers téléchargés. Contrat bouclé au Domaine 6.

### D7-2 : F2 Configure & Run — validé révisé
- install.sh crée .env automatiquement (pas de cp manuel)
- `docker compose up -d` (pas de Makefile)
- 1 seule variable requise pour démarrer (une clé API LLM)
- .env.example bien commenté (repo public)

### D7-3 : F3 Channels — reclassé
- Déjà traité au Domaine 1 (D1-2). Config/doc, pas une feature claw-cage.

### D7-4 : F4 Persistence — validé tel quel
- Volume nommé `claw-data` sur `/home/node/.openclaw`
- Persiste config, mémoire agent, workspace. Survit aux restarts/rebuilds.

### D7-5 : F5 Auto-restart — validé tel quel
- `restart: unless-stopped` + `systemctl enable docker` documenté.

### D7-6 : F6 Git-free upgrade — validé révisé
- Re-run install.sh (idempotent) + `docker compose pull && docker compose up -d`
- Aucune dépendance git côté target.

---

## Domaine 8 — ADRs

### Liste complète des ADRs validés

| ADR | Titre | Statut |
|---|---|---|
| 001 | Séparation Dev / Deploy (Two Worlds) | Validé — renforcé (host 3 fichiers) |
| 002 | Distribution curl \| bash | Validé — simplifié (3 fichiers) |
| 003 | Image officielle OpenClaw (pas de Dockerfile custom) | Rétabli et confirmé |
| 004 | Docker network custom + iptables DOCKER-USER | Validé — simplifié (RFC1918 only, pas de filtrage domaine) |
| 005 | Named volumes pour data | Validé (claw-data) |
| 006 | Debian 12 headless (target recommandé, pas bloquant) | Validé |
| 007 | Séparation Claude Code / claw-cage (générique OpenClaw) | Nouveau |
| ~~008~~ | ~~Image custom ghcr.io~~ | Annulé |
| 009 | Pas de Makefile (make absent sur Debian bare) | Nouveau |
| 010 | MVP sécurité = iptables + compose uniquement | Nouveau |
| 011 | iptables-persistent pour persistance règles réseau | Nouveau |

---

## Domaine 5 — Stack Docker (en cours)

### D5-1 : Services
- **Décision** : 2 services — `openclaw-gateway` (toujours actif) + `openclaw-cli` (profil run, onboarding uniquement).
- **Justification** : Le CLI est utile pour le premier setup sans compliquer le stack permanent.

### D5-2 : Réseau claw-net
- **Décision** : Réseau bridge custom `claw-net` avec subnet fixe `172.30.0.0/24`.
- **Justification** : Subnet fixe = pas besoin de détection dynamique dans iptables-rules.sh. Plus robuste.

### D5-3 : Security opts
- **Décision** : `user: 1000:1000`, `cap_drop: ALL`, `no-new-privileges: true`, `restart: unless-stopped`, `ports: 127.0.0.1:18789:18789`.
- **Statut** : Validé (cohérent avec Domaine 4).

### D5-4 : Restart policy
- **Décision** : `restart: unless-stopped` + `systemctl enable docker` documenté.

### D5-5 : Config OpenClaw — simplifié
- **Constat** : L'image officielle ne réécrit PAS openclaw.json au démarrage normal. Le hardening avancé (skills, sandbox, tools.deny) est JSON-only.
- **Décision** : **Pas de openclaw.json hardened au MVP.** Config minimale ou absente. Le hardening avancé (skills whitelist, sandbox, tools.deny, mDNS) est renvoyé en v2.
- **Justification** : Le MVP sécurité = iptables (isolation LAN) + docker-compose (cap_drop, no-root, loopback). C'est suffisant. Le reste est defense-in-depth, pas critique.
- **Impact** : Suppression de `config/openclaw.json` et `config/skills-whitelist.txt` du MVP. Le host passe de 5 fichiers à 3.

### D5-6 : Périmètre sécurité MVP vs v2
- **MVP** : iptables DOCKER-USER (isolation LAN) + docker-compose (cap_drop ALL, no-root, no-new-privileges, loopback port, secrets .env)
- **v2** : openclaw.json hardened (skills, sandbox, tools, mDNS), documentation SECURITY.md approfondie

### D5-7 : Structure host révisée (post-simplification)
- **Structure MVP** :
  ```
  ~/claw-cage/
  ├── .env                    ← secrets utilisateur (clés API, tokens)
  ├── docker-compose.yml      ← stack hardened (image officielle + security opts)
  └── iptables-rules.sh       ← isolation réseau LAN (DOCKER-USER)
  ```
- **3 fichiers. C'est tout.**

### D5-8 : Image Docker
- **Décision** : Image officielle `ghcr.io/openclaw/openclaw:latest`. Pas d'image custom, pas de coollabsio.
- **Justification** : Pas de config rewrite surprise, source officielle, ARM64 natif, env vars suffisants pour le MVP.
- **Décision** : Le dashboard écoute sur `127.0.0.1:18789` (loopback strict). Accès via SSH tunnel uniquement.
- **Justification** : Sécurité maximale — le dashboard n'est jamais visible sur le LAN. SSH tunnel = chiffré + authentifié.
- **Impact** : Documentation avec tuto clé en main SSH tunnel pour Linux/Mac (terminal) et Windows (PowerShell + PuTTY).
