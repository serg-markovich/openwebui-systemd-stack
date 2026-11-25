# Open WebUI + Ollama systemd Stack

**Status:** `MAINTENANCE` — working local stack at v1.6.0 (last commit 2026-05-29); low activity, docs synced 2026-11-25.

Local AI stack: Open WebUI in Docker, Ollama on the host, managed by a systemd user service with XDG desktop launchers. Built for laptops — start when needed, no always-on container.

## Overview
- **Battery-first lifecycle:** `restart: "no"` + manual start/stop; measured ~25% daily battery saving on the author's EliteBook.
- **systemd user service:** `Type=oneshot` + `RemainAfterExit=yes` wraps `docker compose up -d` / `down`; no root for daily use.
- **Docker bridge networking:** container reaches host Ollama via `172.17.0.1:11434`; requires `OLLAMA_HOST=0.0.0.0`.
- **Portable install:** `make install` renders `systemd/` + `desktop/` templates, so the repo works from any path.
- **Local-only data:** chats in a named Docker volume; no external APIs or telemetry.

## Quick Start
Prereqs: Docker 24.0+ with Compose v2, systemd 249+, Ollama installed, user in the `docker` group.

```bash
git clone git@github.com:serg-markovich/openwebui-systemd-stack.git
cd openwebui-systemd-stack
cp .env.example .env    # WEBUI_PORT=3000, OLLAMA_BASE_URL=http://172.17.0.1:11434

# One-time: let Docker bridge reach host Ollama
sudo mkdir -p /etc/systemd/system/ollama.service.d/
echo -e '[Service]\nEnvironment="OLLAMA_HOST=0.0.0.0:11434"' | \
  sudo tee /etc/systemd/system/ollama.service.d/override.conf
sudo systemctl daemon-reload && sudo systemctl restart ollama

make install   # install user service + desktop launchers
make start     # UI at http://localhost:3000
```

Daily: `make stop | restart | status | logs | update | backup`; diagnostics: `make doctor`; lint: `make lint`.
Restore: `make restore FILE=backups/openwebui-YYYYMMDD-HHMM.tar.gz`.
Full guides: [Quick Start](docs/QUICK_START.md) • [Installation](docs/INSTALLATION.md) • [Architecture](docs/ARCHITECTURE.md) • [Updating](docs/UPDATING.md) • [Troubleshooting](docs/TROUBLESHOOTING.md) • [Security](docs/SECURITY.md).

## Tech Stack
| Component | Technology |
|---|---|
| Container | Docker 24.0+, Compose v2, image `ghcr.io/open-webui/open-webui:v0.9.5` |
| Service manager | systemd 249+ (user unit) |
| LLM runtime | Ollama (host service, `0.0.0.0:11434`) |
| Desktop | XDG desktop entries |
| Scripting | Bash 5.x + Make |

Tested on: HP EliteBook 845 G8, Ubuntu 24.04 LTS. Models used: `gemma3:3b`, `mistral`, `qwen3:14b`, `codellama:7b`.

## Status & Roadmap

**Working**
- `make install/start/stop/restart/status/logs` and desktop start/stop/status launchers.
- Bridge connectivity to Ollama; healthcheck; chat persistence in named volume.
- `make backup` / `make restore`; CI (compose validation, `bash -n`, shellcheck); weekly upstream release check.

**Broken / Incomplete**
- `OPENWEBUI_VERSION` in `.env.example` is unused — image tag is hardcoded in `docker-compose.yml`, so `make update` only re-pulls the pinned tag.
- Backup/restore hardcode volume `openwebui-stack_open-webui` — breaks if the clone directory is renamed.
- `WEBUI_PORT` is ignored by launcher/Makefile messages (hardcoded `:3000`).
- No tests beyond `make lint`; no monitoring/Ansible/Fedora/Arch support.

**Next Steps**
1. Make the image tag env-driven (`image: ...:${OPENWEBUI_VERSION:-v0.9.5}`) and sync `.env.example` + `CHANGELOG.md`.
2. Derive the volume name (`docker compose config --volumes` / project name) instead of hardcoding it; honor `WEBUI_PORT` in scripts.
3. Add a CI smoke test against the container health endpoint; let Dependabot handle image/action bumps.

## Screenshots
[Chat](docs/screenshot_1.png) • [Model selection](docs/screenshot_2.png) • [Desktop launchers](docs/screenshot_3.png)

## Contributing
Issues and PRs welcome: bug reports, docs fixes, distro support. Run `make` for the target list.

Part of the [eigenstack](https://github.com/serg-markovich/eigenstack) local-first philosophy: no cloud dependencies, no vendor lock-in.

## License
MIT — see [LICENSE](LICENSE). Copyright (c) 2026 Sergey Markovych.
