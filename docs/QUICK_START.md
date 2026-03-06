# Quick Start

Get Open WebUI + Ollama running in 5 minutes.

## Prerequisites

```bash
docker --version          # 24.0+
systemctl --version       # 249+
ollama --version          # installed
groups | grep docker      # you're in docker group
```

Missing something? See [Installation Guide](INSTALLATION.md).

---

## TL;DR

```bash
cd ~
git clone https://github.com/serg-markovich/openwebui-systemd-stack.git
cd openwebui-systemd-stack

# One-time: configure Ollama for Docker bridge networking
sudo mkdir -p /etc/systemd/system/ollama.service.d/
echo -e '[Service]\nEnvironment="OLLAMA_HOST=0.0.0.0:11434"' | \
  sudo tee /etc/systemd/system/ollama.service.d/override.conf
sudo systemctl daemon-reload && sudo systemctl restart ollama

# Install and start
cp .env.example .env
make install
make start
```

**That's it!** 🎉

---

## What Just Happened?

1. **Ollama configured** — accepts connections from Docker bridge (172.17.0.1)
2. **Service installed** — `make install` copied systemd service and desktop launchers
3. **Container started** — `make start` launched Open WebUI via Docker Compose
4. **Ready** — web interface at http://localhost:3000

---

## Daily Usage

```bash
make start      # start Open WebUI
make stop       # stop Open WebUI
make restart    # restart
make status     # service + container status
make logs       # follow container logs (Ctrl+C to exit)
make update     # pull latest image and restart
make backup     # save chat history to backups/
```

---

## Pull Your First Model

```bash
ollama pull gemma3:3b     # ~2 GB  — fast, good for testing
ollama pull mistral       # ~4.1 GB — general purpose
ollama pull qwen3:14b     # ~9 GB  — best reasoning
ollama pull codellama:7b  # ~3.8 GB — code specialist
```

Start with `gemma3:3b` to verify setup, then pull larger models as needed.

---

## Verify Everything Works

```bash
curl http://172.17.0.1:11434/api/tags    # Ollama reachable from Docker network
docker ps | grep open-webui              # container running
systemctl --user is-active openwebui     # service active
```

---

## Backup and Restore

```bash
make backup

make restore FILE=backups/openwebui-YYYYMMDD-HHMM.tar.gz
```

---

## Common Issues

**Port 3000 already in use** — edit `.env`, set `WEBUI_PORT=8000`, then `make restart`

**Container can't reach Ollama** — verify:
```bash
systemctl cat ollama.service | grep OLLAMA_HOST
# Must show: Environment="OLLAMA_HOST=0.0.0.0:11434"
```

**Service won't start** — check docker group:
```bash
groups | grep docker
# If missing: sudo usermod -aG docker $USER && newgrp docker
```

---

Got stuck? See [Troubleshooting Guide](TROUBLESHOOTING.md).
