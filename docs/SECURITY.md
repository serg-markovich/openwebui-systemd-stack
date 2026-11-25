# Security

## Supported Versions
Only the latest `master` is supported. Security fixes land there; no backports.

## Reporting
- Use GitHub **Security → Report a vulnerability** (private advisory).
- Do not open a public issue with exploit details or personal data.
- No dedicated security email is configured `[UNKNOWN / NEEDS CHECK]`.

## Security Model
| Component | Exposure | Notes |
|---|---|---|
| Open WebUI | Host `0.0.0.0:${WEBUI_PORT:-3000}` → container `8080` | Docker publishes on all interfaces by default; restrict with firewall or bind `127.0.0.1:3000:8080` |
| Ollama API | `0.0.0.0:11434` | Required for Docker bridge access; must be firewalled from untrusted networks |
| Docker socket | User via `docker` group | Group membership is effectively root-equivalent |
| Chat data | Named volume `openwebui-stack_open-webui` | Local only; no telemetry or external API calls |

## Hardening Baseline
```bash
# UI: localhost only
sudo ufw deny 3000
sudo ufw allow from 127.0.0.1 to any port 3000

# Ollama: Docker bridge only
sudo ufw deny 11434
sudo ufw allow from 172.17.0.0/16 to any port 11434
```

- Bind UI to loopback in `docker-compose.yml`: `"127.0.0.1:${WEBUI_PORT:-3000}:8080"`.
- Keep the image pinned; update deliberately via `make update` + `CHANGELOG.md`.
- Treat `.env` as local-only: it is gitignored, never commit it.
- Do not expose port `11434` to the internet — the Ollama API has no authentication.

## Known Caveats
- `OLLAMA_HOST=0.0.0.0` is set via a systemd drop-in, not by this repo; firewall rules above are manual.
- `restart: "no"` is intentional (battery); do not "fix" it without understanding the trade-off.
- CI validates config and shell syntax only — it does not scan containers or dependencies.
