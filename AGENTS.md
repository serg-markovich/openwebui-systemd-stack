# AGENTS.md

Rules and environment for AI assistants working in this repo.

## Tech Stack
- Infra-only repo: Bash 5.x, GNU Make, Docker 24.0+ / Compose v2, systemd 249+, XDG desktop entries.
- No language package manager, no build step, no dependency manifests. System deps via `apt` only.
- Runtime: Open WebUI container `ghcr.io/open-webui/open-webui:v0.9.5` + host `ollama.service` (port 11434).

## Commands
| Task | Command |
|---|---|
| Install (user) | `cp .env.example .env && make install` |
| Start / stop / restart | `make start` / `make stop` / `make restart` |
| Status / logs | `make status` / `make logs` |
| Update image | `make update` (runs `scripts/update.sh`, 5 retries) |
| Backup / restore | `make backup` / `make restore FILE=backups/<file>.tar.gz` |
| Test / lint | `make lint` (`bash -n`, `shellcheck`, `docker compose config -q`) |
| Diagnostics | `make doctor` (docker, Ollama, unit, port, config) |
| Build | none (no compile step) |

## Architecture & Boundaries
- `docker-compose.yml` — single `open-webui` service, named volume `open-webui`, `restart: "no"`, healthcheck.
- `Makefile` — sole operator entrypoint; wraps `systemctl --user` + `docker`; also renders templates.
- `scripts/` — runtime helpers (`start-with-browser.sh`, `stop.sh`, `status.sh`, `update.sh`).
- `systemd/*.template`, `desktop/*.template` — source of truth; `make install` substitutes `%%INSTALL_PATH%%` into `~/.config/systemd/user/` and `~/.local/share/applications/`. Never edit generated copies.
- `docs/` user docs, `.github/workflows/` CI (`ci.yml`) + weekly release check (`check-updates.yml`).

## Coding Conventions & Guardrails
- New Bash: `#!/usr/bin/env bash`, `set -euo pipefail`, quote all vars, resolve root via `BASH_SOURCE` (see `scripts/update.sh`).
- Keep templates portable: use `%%INSTALL_PATH%%`, never absolute paths or `$HOME`.
- Version bumps: edit image tag in `docker-compose.yml` **and** `OPENWEBUI_VERSION` in `.env.example` **and** add a `CHANGELOG.md` entry. Compose does not read `OPENWEBUI_VERSION` (known bug).
- Do not hardcode volume names in new code: `openwebui-stack_open-webui` depends on clone directory name (see `Makefile` backup/restore).
- Do not commit `.env`, `backups/`, or generated `desktop/*.desktop`; only `.template` files are tracked.
- CI gate: `shellcheck` + `bash -n` + `docker compose config -q` must pass; CI runs on `master` only.
- Docs were synced on 2026-11-25; re-verify `docs/ARCHITECTURE.md` examples after infra changes.
- No application code or tests exist; do not invent a test framework.
