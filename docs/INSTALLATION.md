# Installation Guide

Full setup from scratch — for when Docker and Ollama are not yet installed.

## Table of Contents

1. [Install Docker](#1-install-docker)
2. [Install Ollama](#2-install-ollama)
3. [Clone Repository](#3-clone-repository)
4. [Configure Ollama](#4-configure-ollama)
5. [Install Stack](#5-install-stack)
6. [First Run](#6-first-run)
7. [Verification](#7-verification)
8. [Uninstall](#8-uninstall)

---

## 1. Install Docker

```bash
sudo apt update
sudo apt install -y ca-certificates curl gnupg

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin

sudo usermod -aG docker $USER
newgrp docker

sudo systemctl enable --now docker.service

docker --version
docker compose version
```

---

## 2. Install Ollama

```bash
curl -fsSL https://ollama.com/install.sh | sh

systemctl is-active ollama
# Expected: active

ollama pull gemma3:3b
ollama run gemma3:3b "Hello!"
```

---

## 3. Clone Repository

```bash
cd ~
git clone https://github.com/serg-markovich/openwebui-systemd-stack.git
cd openwebui-systemd-stack
```

---

## 4. Configure Ollama

By default Ollama listens on `127.0.0.1:11434` — Docker containers cannot reach that address.
This override makes Ollama listen on all interfaces so the container can connect via `172.17.0.1`.

```bash
sudo mkdir -p /etc/systemd/system/ollama.service.d/

sudo tee /etc/systemd/system/ollama.service.d/override.conf > /dev/null <<EOF
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
EOF

sudo systemctl daemon-reload
sudo systemctl restart ollama

systemctl cat ollama.service | grep OLLAMA_HOST
# Expected: Environment="OLLAMA_HOST=0.0.0.0:11434"

curl http://172.17.0.1:11434/api/tags
# Expected: JSON with model list
```

---

## 5. Install Stack

```bash
cp .env.example .env
make install
```

`make install` does the following:
- Generates `~/.config/systemd/user/openwebui.service` from `systemd/openwebui.service.template` with `%%INSTALL_PATH%%` substitution
- Generates `~/.local/share/applications/*.desktop` from `desktop/*.desktop.template` with path substitution
- Runs `systemctl --user daemon-reload` and `update-desktop-database`

Optional — enable auto-start on login:
```bash
systemctl --user enable openwebui
```

---

## 6. First Run

```bash
make start

make status

xdg-open http://localhost:3000
```

First time: click **Sign up** to create a local admin account.
Nothing is sent externally — all data stays on your machine.

---

## 7. Verification

```bash
sudo systemctl is-active docker           # active
systemctl is-active ollama                # active
systemctl --user is-active openwebui      # active
docker ps | grep open-webui               # container listed
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000   # 200
```

All five checks should pass ✅

---

## 8. Uninstall

```bash
make stop
systemctl --user disable openwebui 2>/dev/null || true

rm ~/.config/systemd/user/openwebui.service
rm ~/.local/share/applications/openwebui-*.desktop
systemctl --user daemon-reload
update-desktop-database ~/.local/share/applications/

cd ~/openwebui-systemd-stack
docker compose down -v

cd ~
rm -rf openwebui-systemd-stack

# Optional: remove Ollama network override
sudo rm /etc/systemd/system/ollama.service.d/override.conf
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

---

Next: [Quick Start](QUICK_START.md) • [Architecture](ARCHITECTURE.md) • [Troubleshooting](TROUBLESHOOTING.md)
