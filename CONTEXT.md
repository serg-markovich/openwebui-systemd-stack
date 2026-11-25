# CONTEXT.md

Technical snapshot of the current codebase state. Facts only.

## Project Map
```
.
├── docker-compose.yml       # single open-webui service, pinned image, named volume
├── Makefile                 # install/start/stop/status/logs/update/backup/restore/lint/doctor
├── .env.example             # OLLAMA_BASE_URL, WEBUI_PORT, OPENWEBUI_VERSION
├── .gitignore               # .env, backups/, desktop/*.desktop, IDE dirs
├── .editorconfig            # LF, UTF-8, tabs for Makefile, 4 spaces for shell
├── CHANGELOG.md             # Keep-a-Changelog, Unreleased + 1.6.0 (2026-03-19)
├── README.md                # user overview
├── LICENSE                  # MIT
├── scripts/
│   ├── start-with-browser.sh # systemctl start + poll localhost:3000 + xdg-open
│   ├── stop.sh               # systemctl stop + optional notify-send
│   ├── status.sh             # systemctl status + docker ps/stats
│   └── update.sh             # stop, docker compose pull (5 retries), start
├── systemd/
│   └── openwebui.service.template  # Type=oneshot, RemainAfterExit, %%INSTALL_PATH%%
├── desktop/
│   ├── openwebui-start.desktop.template
│   ├── openwebui-stop.desktop.template
│   └── openwebui-status.desktop.template
├── docs/                     # ARCHITECTURE, INSTALLATION, QUICK_START, UPDATING, TROUBLESHOOTING, SECURITY + 3 PNGs
└── .github/
    ├── dependabot.yml        # weekly actions + docker-compose PRs
    └── workflows/
        ├── ci.yml            # compose config, file presence, bash -n, shellcheck
        └── check-updates.yml # weekly GitHub API check, opens issue
```

## Entrypoints & Data Flow
- Operator entrypoint: `Makefile` targets → `systemctl --user {start,stop,restart} openwebui` or `docker`/scripts.
- `make install` renders `systemd/openwebui.service.template` and `desktop/*.template` (sed `%%INSTALL_PATH%%` → `$(PWD)`), then `daemon-reload` + `update-desktop-database`.
- Boot/runtime: user unit runs `docker compose up -d`; `ExecStop` runs `docker compose down`; container has no restart policy.
- Request path: browser `:3000` → container `:8080` → `OLLAMA_BASE_URL` (`http://172.17.0.1:11434`, Docker bridge gateway) → host `ollama.service`.
- Persistence: named Docker volume `openwebui-stack_open-webui` → `/app/backend/data`; backup/restore via `alpine tar` in `Makefile`.

## External Dependencies
- Services: Docker Engine + Compose v2, systemd user session, host Ollama (`OLLAMA_HOST=0.0.0.0:11434` override), `xdg-open`/`update-desktop-database`, optional `notify-send`.
- Registries/APIs: `ghcr.io/open-webui/open-webui`; GitHub REST API in `check-updates.yml`.
- Env vars: `OLLAMA_BASE_URL`, `WEBUI_PORT`, `OPENWEBUI_VERSION` (declared but unused by Compose).
- Host paths touched: `~/.config/systemd/user/`, `~/.local/share/applications/`, `/etc/systemd/system/ollama.service.d/override.conf`.

## Tech Debt & Risks
- `OPENWEBUI_VERSION` in `.env.example` is declared but unused by Compose; image tag is hardcoded in `docker-compose.yml` → `make update` only re-pulls the pinned tag.
- `Makefile` backup/restore hardcode volume `openwebui-stack_open-webui`; renaming/moving the clone breaks both (volume name derives from directory).
- `WEBUI_PORT` is configurable, yet `Makefile` echo and `scripts/start-with-browser.sh` hardcode `localhost:3000`.
- No tests beyond `make lint` (no container smoke test); `scripts/status.sh` lacks `set -euo pipefail`.
- Desktop start launcher uses `env bash`, others use `bash` — inconsistent but functional.
- Docker group membership ≈ root-equivalent; Ollama bound to `0.0.0.0` relies on external firewall rules (documented in `docs/SECURITY.md`, not enforced).
- UI port is published on `0.0.0.0` by default; loopback binding is documented but not the default.

## Revival Effort Estimate
**Low** — stack is self-contained and runnable today with Docker, systemd, and Ollama; only `cp .env.example .env && make install && make start` is required. Remaining work: make the image tag env-driven, fix hardcoded volume/port, add a container smoke test.
