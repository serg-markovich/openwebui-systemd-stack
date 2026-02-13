# Installation Guide

Complete step-by-step installation instructions for Open WebUI systemd Stack.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Install Docker](#install-docker)
3. [Install Ollama](#install-ollama)
4. [Clone Repository](#clone-repository)
5. [Configure Ollama](#configure-ollama)
6. [Setup systemd Service](#setup-systemd-service)
7. [Desktop Integration](#desktop-integration)
8. [First Run](#first-run)
9. [Verification](#verification)

---

## Prerequisites

### System Requirements

- **OS:** Ubuntu 22.04+ (or compatible systemd-based Linux)
- **RAM:** 8GB minimum, 16GB+ recommended
- **Disk:** 20GB+ free space for models
- **Internet:** Required for pulling Docker images and models

### Software Requirements

| Component | Minimum Version | Check Command |
|-----------|----------------|---------------|
| systemd | 249+ | `systemctl --version` |
| Docker | 24.0+ | `docker --version` |
| docker-compose | v2.x | `docker compose version` |

---

## Step 1: Install Docker

### Ubuntu/Debian

```bash
# Update package index
sudo apt update

# Install prerequisites
sudo apt install -y ca-certificates curl gnupg

# Add Docker GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add current user to docker group
sudo usermod -aG docker $USER

# Apply group membership (logout/login or use newgrp)
newgrp docker

# Verify installation
docker --version
docker compose version
```

### Enable Docker Service

```bash
# Enable Docker to start on boot
sudo systemctl enable docker.service
sudo systemctl enable containerd.service

# Start Docker now
sudo systemctl start docker.service

# Verify Docker is running
sudo systemctl status docker.service
```

---

## Step 2: Install Ollama

### Download and Install

```bash
# Download and install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Verify installation
ollama --version
```

### Verify Ollama Service

```bash
# Check service status
systemctl status ollama

# Should show: active (running)
```

### Pull a Test Model

```bash
# Pull a small model to verify Ollama works
ollama pull gemma3:3b

# Test model
ollama run gemma3:3b "Hello, world!"
```

If you get a response, Ollama is working! ✅

---

## Step 3: Clone Repository

```bash
# Navigate to your projects directory
cd ~

# Clone repository
git clone https://github.com/serg-markovich/openwebui-systemd-stack.git

# Enter directory
cd openwebui-systemd-stack

# Verify files
ls -la
```

You should see:
```
docker-compose.yml
systemd/
desktop/
scripts/
docs/
```

---

## Step 4: Configure Ollama

### Why This Is Needed

By default, Ollama listens on `127.0.0.1:11434` (localhost only). Docker containers on bridge network can't access host's localhost. They must use the Docker bridge gateway IP: `172.17.0.1`.

Solution: Configure Ollama to listen on `0.0.0.0:11434` (all interfaces).

### Create Override Configuration

```bash
# Create override directory
sudo mkdir -p /etc/systemd/system/ollama.service.d/

# Create override file
sudo tee /etc/systemd/system/ollama.service.d/override.conf > /dev/null <<EOF
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
EOF

# Reload systemd configuration
sudo systemctl daemon-reload

# Restart Ollama to apply changes
sudo systemctl restart ollama

# Verify configuration
systemctl cat ollama.service | grep OLLAMA_HOST
```

**Expected output:**
```
Environment="OLLAMA_HOST=0.0.0.0:11434"
```

### Verify Ollama Is Accessible from Docker Network

```bash
# Test from host
curl http://172.17.0.1:11434/api/tags

# Should return JSON with model list
```

---

## Step 5: Setup systemd Service

### Copy Service File

```bash
# Create systemd user directory if it doesn't exist
mkdir -p ~/.config/systemd/user/

# Copy service file
cp systemd/openwebui.service ~/.config/systemd/user/

# Reload systemd user daemon
systemctl --user daemon-reload
```

### Verify Service Is Registered

```bash
# Check service status (should be inactive, not loaded yet)
systemctl --user status openwebui

# Should show service is loaded but not running
```

### Optional: Enable Auto-Start on Login

**Note:** This project defaults to manual control for battery optimization. If you want auto-start:

```bash
# Enable service to start on user login
systemctl --user enable openwebui

# To disable later:
# systemctl --user disable openwebui
```

---

## Step 6: Desktop Integration

### Copy Desktop Launchers

```bash
# Copy desktop entry files
cp desktop/*.desktop ~/.local/share/applications/

# Update desktop database
update-desktop-database ~/.local/share/applications/
```

### Make Scripts Executable

```bash
# Ensure scripts are executable
chmod +x scripts/*.sh
```

### Verify Launchers Appear

Open your application menu and search for "Open WebUI". You should see:
- Open WebUI (Start)
- Open WebUI (Stop)
- Open WebUI (Status)

---

## Step 7: First Run

### Start Service

```bash
# Start Open WebUI service
systemctl --user start openwebui

# Check status
systemctl --user status openwebui

# Wait for container to start (~15-30 seconds)
sleep 20

# Check container is running
docker ps | grep open-webui
```

**Expected output:**
```
CONTAINER ID   IMAGE                          STATUS          PORTS
abc123def456   ghcr.io/open-webui/open-webui  Up 20 seconds   0.0.0.0:3000->8080/tcp
```

### Open Web Interface

```bash
# Open in browser
xdg-open http://localhost:3000

# Or manually navigate to: http://localhost:3000
```

### First-Time Setup

1. Browser will open to Open WebUI interface
2. Click **"Sign up"** to create admin account
3. Enter email and password (stored locally, not sent anywhere)
4. Click **"Create Account"**
5. You're ready to chat! 🎉

---

## Step 8: Verification

### Check All Components

```bash
# 1. Docker is running
sudo systemctl is-active docker
# Expected: active

# 2. Ollama is running
systemctl is-active ollama
# Expected: active

# 3. Ollama is listening on 0.0.0.0
ss -tlnp | grep 11434
# Expected: tcp LISTEN 0.0.0.0:11434

# 4. systemd service is active
systemctl --user is-active openwebui
# Expected: active

# 5. Container is running
docker ps | grep open-webui
# Expected: Container listed and Up

# 6. Web interface is accessible
curl -I http://localhost:3000
# Expected: HTTP/1.1 200 OK
```

All checks should pass ✅

### Test Chat Functionality

1. Open http://localhost:3000
2. Select a model (e.g., gemma3:3b)
3. Type: "Hello, can you introduce yourself?"
4. Wait for response (~5-10 seconds first time)
5. If you get a response, everything works! 🎉

---

## Step 9: Pull Additional Models

```bash
# Universal model (recommended)
ollama pull mistral            # ~4.1 GB

# Best reasoning
ollama pull qwen3:14b          # ~9 GB

# Code specialist
ollama pull codellama:7b       # ~3.8 GB

# Check downloaded models
ollama list
```

**Storage note:** Each model requires significant disk space. Make sure you have enough before pulling large models.

---

## Post-Installation

### Daily Usage

**Start service:**
```bash
systemctl --user start openwebui
# or click desktop launcher
```

**Stop service:**
```bash
systemctl --user stop openwebui
# or click desktop launcher
```

**Check status:**
```bash
systemctl --user status openwebui
# or click desktop launcher
```

### View Logs

```bash
# Service logs
journalctl --user -u openwebui -f

# Container logs
docker logs open-webui -f

# Ollama logs
journalctl -u ollama -f
```

### Backup Chat History

```bash
# Chat data is stored in Docker volume
docker volume inspect openwebui-stack_open-webui

# Backup (creates tar.gz in current directory)
docker run --rm \
  -v openwebui-stack_open-webui:/data \
  -v $(pwd):/backup \
  ubuntu tar czf /backup/openwebui-backup-$(date +%Y%m%d).tar.gz /data
```

### Restore from Backup

```bash
# Restore (assuming backup file is in current directory)
docker run --rm \
  -v openwebui-stack_open-webui:/data \
  -v $(pwd):/backup \
  ubuntu tar xzf /backup/openwebui-backup-YYYYMMDD.tar.gz -C /
```

---

## Troubleshooting

If you encounter issues, see [Troubleshooting Guide](TROUBLESHOOTING.md).

Common issues:
- Port 3000 conflicts → See [Port Conflict Resolution](TROUBLESHOOTING.md#port-conflicts)
- Container can't reach Ollama → See [Network Issues](TROUBLESHOOTING.md#network-issues)
- Service won't start → See [Service Issues](TROUBLESHOOTING.md#service-issues)

---

## Uninstallation

### Complete Removal

```bash
# Stop and disable service
systemctl --user stop openwebui
systemctl --user disable openwebui

# Remove systemd service
rm ~/.config/systemd/user/openwebui.service
systemctl --user daemon-reload

# Remove desktop launchers
rm ~/.local/share/applications/openwebui-*.desktop
update-desktop-database ~/.local/share/applications/

# Remove Docker containers and volumes
cd ~/openwebui-systemd-stack
docker compose down -v

# Remove repository
cd ~
rm -rf openwebui-systemd-stack

# Optional: Remove Ollama override
sudo rm /etc/systemd/system/ollama.service.d/override.conf
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

---

## Next Steps

- 📖 Read [Architecture Documentation](ARCHITECTURE.md) to understand how it works
- 🔧 Explore [Troubleshooting Guide](TROUBLESHOOTING.md) for solutions
- 💡 Check [Roadmap](../README.md#roadmap) for planned features

**Enjoy your local AI setup!** 🤖
