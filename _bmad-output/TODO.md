# TODO — Validation IDEA.md & Documentation claw-cage

> Objectif : Valider chaque aspect de l'IDEA.md avec assez de granularité pour partir directement en dev.
> Toutes les conclusions vont dans `docs/` pour servir de référence pendant l'implémentation.
> **Registre des décisions** : `_bmad-output/planning-artifacts/validation-decisions.md`

---

## Phase 1 — Validation de l'IDEA

### 1. Vision & Scope ✅
- [x] Valider le périmètre exact du MVP vs Nice-to-have
- [x] Confirmer que claw-cage est bien un wrapper infra/config et PAS un fork
- [x] Clarifier le public cible → repo public, template partageable
- [x] **PIVOT** : claw-cage = générique OpenClaw, pas lié à Claude Code
- [x] F3 reclassé : config/doc, pas une feature claw-cage
- [x] ADR-007 ajouté : séparation Claude Code / claw-cage

### 2. Architecture "Two Worlds" (Dev / Deploy) ✅
- [x] Valider la séparation stricte `deploy/` vs `src/`
- [x] Vérifier qu'aucun fichier dans `deploy/` ne dépend de Node.js/Git/npm
- [x] Valider la structure de fichiers source repo — révisée (Dockerfile, entrypoint.sh, config/)
- [x] Valider la structure de fichiers target machine — réduite à 3 fichiers (.env, compose, iptables)
- [x] Confirmer le flow de mise à jour → `docker compose pull && docker compose up -d`
- [x] **PIVOT** : Approche 2 — image Docker custom sur ghcr.io (ADR-008)
- [x] Makefile supprimé (make pas dispo sur Debian bare)
- [x] package.json/src/ conservés côté dev (BMAD), invisibles pour l'utilisateur

### 3. Faisabilité Technique — Contraintes Hardware ✅
- [x] Valider le budget RAM → ~770 MB réaliste (1 canal), ~870 MB (2 canaux). IDEA corrigée.
- [x] Confirmer ARM64 → OK, image officielle multi-arch confirmée
- [x] Swap → 2 GB fichier + zram recommandé
- [x] Portabilité x86_64 / ARM64 → OK natif via image officielle
- [x] **PIVOT** : Pas d'image custom. Image officielle + volumes. ADR-008 annulé, ADR-003 rétabli.
- [x] Isolation réseau = iptables DOCKER-USER (host-level, n'affecte pas le réseau de la machine hôte)

### 4. Modèle de Sécurité ✅
- [x] Valider S1-S9 individuellement — tous validés (S1 simplifié, S4 révisé)
- [x] Threat model — couvert, principal risque = accès LAN (résolu par S1)
- [x] iptables DOCKER-USER — validé comme mécanisme d'isolation
- [x] Filtrage egress par domaine → **supprimé** (over-engineering, on bloque RFC1918 seulement)
- [x] Risques curl|bash → acceptés, mitigés par S9 (checks prerequisites)
- [x] S4 confirmé : loopback `127.0.0.1` + accès via SSH tunnel + tuto Windows (PowerShell/PuTTY)

### 5. Stack Docker ✅
- [x] Services : gateway (always on) + cli (profil run, onboarding)
- [x] Réseau : claw-net bridge, subnet fixe 172.30.0.0/24
- [x] Volumes : named volume claw-data pour persistence
- [x] Security opts : cap_drop ALL, no-root, no-new-privileges, loopback port
- [x] Restart : unless-stopped + systemctl enable docker
- [x] Image : officielle `ghcr.io/openclaw/openclaw:latest`
- [x] **SIMPLIFICATION** : pas de openclaw.json hardened au MVP. Host = 3 fichiers (.env, compose, iptables)
- [x] Config hardened (skills, sandbox, tools) → renvoyé en v2

### 6. Script d'Installation (`install.sh`) ✅
- [x] Contrat validé : idempotent, défensif, respectueux, jamais de sudo
- [x] Checks : bash >= 4, curl, docker, docker compose v2, arch (info)
- [x] Download : 3 fichiers via curl raw GitHub
- [x] Edge cases : .env jamais écrasé, docker-compose.yml et iptables-rules.sh écrasés (voulu)
- [x] Pas de sudo dans install.sh — iptables exécuté manuellement par l'utilisateur
- [x] Persistance iptables : iptables-persistent installé par iptables-rules.sh (sudo, une seule fois)
- [x] Upgrade = re-run install.sh + docker compose pull (pas de upgrade.sh séparé)

### 7. Requirements Fonctionnels (F1-F6) ✅
- [x] F1 — Curl Install : simplifié (3 fichiers), contrat Domaine 6
- [x] F2 — Configure & Run : 1 variable min, pas de Makefile, .env.example commenté
- [x] ~~F3 — Channels~~ → Reclassé (Domaine 1)
- [x] F4 — Persistence : volume nommé claw-data, survie restarts/rebuilds
- [x] F5 — Auto-restart : unless-stopped + systemctl enable docker
- [x] F6 — Git-free upgrade : re-run install.sh + docker compose pull

### 8. ADRs (Architecture Decision Records) ✅
- [x] ADR-001 à 006 revus (003 rétabli, 004 simplifié)
- [x] ADR-007 ajouté (séparation Claude Code), ADR-008 annulé
- [x] ADR-009 (pas de Makefile), 010 (MVP sécurité), 011 (iptables-persistent) ajoutés
- [x] Liste complète documentée dans validation-decisions.md

### 9. Nice-to-have (N1-N5) — Priorisation ✅
- [x] Évalué — tout renvoyé post-MVP
- [x] Rien n'impacte le MVP
- [x] Priorité post-MVP : N6 (config hardened) > N1 (backup) > N2/N7 > N5 > N8 > N3 > N4

---

## Phase 2 — Documentation

### 10. Produire les documents de référence
- [ ] Rédiger le document d'architecture validé
- [ ] Rédiger le document de sécurité (threat model + mitigations)
- [ ] Rédiger les specs techniques pour chaque composant du MVP
- [ ] Créer le fichier de contexte projet pour le dev agent

---

## Progression

| Phase | Statut | Date |
|-------|--------|------|
| 1. Vision & Scope | **VALIDÉ** ✅ | 2026-02-23 |
| 2. Architecture Two Worlds | **VALIDÉ** ✅ | 2026-02-23 |
| 3. Faisabilité Technique | **VALIDÉ** ✅ | 2026-02-23 |
| 4. Modèle de Sécurité | **VALIDÉ** ✅ | 2026-02-23 |
| 5. Stack Docker | **VALIDÉ** ✅ | 2026-02-23 |
| 6. Script install.sh | **VALIDÉ** ✅ | 2026-02-23 |
| 7. Requirements F1-F6 | **VALIDÉ** ✅ | 2026-02-23 |
| 8. ADRs | **VALIDÉ** ✅ | 2026-02-23 |
| 9. Nice-to-have | **VALIDÉ** ✅ | 2026-02-23 |
| 10. Documentation | **SKIP** — intégré au dev | 2026-02-23 |
