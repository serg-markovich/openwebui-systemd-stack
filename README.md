# Open WebUI + Ollama systemd Stack

> Production-ready local AI infrastructure with systemd service management, Docker bridge networking, and desktop integration.

## Why I Built This

I wanted to run Open WebUI + Ollama on my laptop without constantly draining the battery. Most guides just say "docker run" and leave you with a container running 24/7.

After a weekend of figuring out Docker bridge networking (that `172.17.0.1` gateway IP took me 2 hours to debug!), systemd user services, and battery optimization, I decided to document everything properly.

**This is what I use daily on my HP EliteBook 845 G8 running Ubuntu 24.04.**

Key learnings:
- systemd `Type=oneshot` with `RemainAfterExit=yes` is perfect for docker compose
- Docker bridge networking requires `OLLAMA_HOST=0.0.0.0` (not `127.0.0.1`)
- Manual lifecycle control saves 20-30% battery vs auto-start
- XDG desktop integration works great with systemd user services

---

## Overview
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04%2B-E95420?logo=ubuntu&logoColor=white)](https://ubuntu.com)

**Privacy-first local AI with production-grade infrastructure.**

systemd service management • Docker bridge networking • Desktop integration • Battery-optimized • GDPR-compliant by design

Perfect for DevOps portfolios, offline development, and data sovereignty requirements.

![Open WebUI Interface](docs/screenshot.png)

---

## Architecture Overview

```
┌─────────────────────────────────────────────┐
│  Browser (localhost:3000)                   │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│  Docker Container (Open WebUI)              │
│  Port: 3000:8080                            │
│  Network: bridge (172.17.0.0/16)            │
└──────────────────┬──────────────────────────┘
                   │ http://172.17.0.1:11434
┌──────────────────▼──────────────────────────┐
│  Ollama Service (systemd)                   │
│  Models: mistral, codellama, gemma, qwen    │
└─────────────────────────────────────────────┘
```

**Design Principles:**
- **Infrastructure as Code** — Declarative configuration
- **Least Privilege** — User-level service (no root for daily use)
- **Network Isolation** — Bridge mode with explicit gateway routing
- **Operational Excellence** — Structured logging (journalctl), health checks, graceful lifecycle
- **Energy Efficiency** — Manual control for battery-conscious workflows

---

## Prerequisites

| Component | Version | Installation |
|-----------|---------|--------------|
| **Ubuntu** | 22.04+ | Pre-installed |
| **Ollama** | Latest | `curl -fsSL https://ollama.ai/install.sh \| sh` |
| **Docker** | 24.0+ | `sudo apt install docker.io docker-compose-v2` |
| **Models** | ≥1 model | `ollama pull mistral` |

**Pre-flight Check:**
```bash
# Verify installations
ollama --version && docker --version && docker compose version

# Check Ollama service
systemctl status ollama

# Verify at least one model exists
ollama list
```

---

## Quick Start (5 Minutes)

```bash
# 1. Install Ollama (if not present)
curl -fsSL https://ollama.ai/install.sh | sh
ollama pull mistral  # 4.1GB download, ~2-3 minutes

# 2. Install Docker
sudo apt update && sudo apt install -y docker.io docker-compose-v2
sudo usermod -aG docker $USER
newgrp docker  # Activate group without reboot (alternative: reboot)

# 3. Configure Ollama for Docker bridge networking
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo tee /etc/systemd/system/ollama.service.d/override.conf > /dev/null << 'EOF'
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
EOF
sudo systemctl daemon-reload && sudo systemctl restart ollama

# 4. Clone and deploy
git clone https://github.com/YOUR_USERNAME/openwebui-systemd-stack.git
cd openwebui-systemd-stack

# Install systemd service
mkdir -p ~/.config/systemd/user
cp systemd/openwebui.service ~/.config/systemd/user/
systemctl --user daemon-reload

# Install desktop launchers
mkdir -p ~/.local/share/applications
cp desktop/*.desktop ~/.local/share/applications/
update-desktop-database ~/.local/share/applications/
chmod +x scripts/*.sh

# 5. Start and verify
systemctl --user start openwebui
sleep 10 && xdg-open http://localhost:3000
```

**First launch:** Create admin account → Select model → Start chatting

---

## Detailed Installation

### Step 1: Install Ollama

Ollama provides the LLM runtime. Install system-wide as root service:

```bash
curl -fsSL https://ollama.ai/install.sh | sh
```

**What this does:**
- Installs Ollama binary to `/usr/local/bin/ollama`
- Creates systemd service at `/etc/systemd/system/ollama.service`
- Starts service automatically

**Verify installation:**
```bash
systemctl status ollama  # Should show "active (running)"
ollama --version
```

### Step 2: Pull AI Models

Recommended models for development:

```bash
# General-purpose (German + English)
ollama pull mistral        # 4.1GB — Best all-around, excellent German support

# Code generation
ollama pull codellama      # 3.8GB — Optimized for programming tasks

# Lightweight options
ollama pull gemma2:2b      # 1.6GB — Fast, resource-efficient
ollama pull qwen2.5:3b     # 2.0GB — Multilingual, good performance

# Advanced (requires 16GB+ RAM)
ollama pull llama3.1:8b    # 4.7GB — Meta's latest
ollama pull mixtral:8x7b   # 26GB — High performance (experts model)
```

**Model selection guide:**
- **Learning/Testing:** `mistral` or `gemma2:2b`
- **Production work:** `mistral` or `llama3.1:8b`
- **Code-heavy tasks:** `codellama`
- **Multilingual:** `qwen2.5:3b`

**Verify models:**
```bash
ollama list
# Should show at least one model
```

**Model resources:**
- Browse models: [https://ollama.ai/library](https://ollama.ai/library)
- Model cards: [https://huggingface.co/models](https://huggingface.co/models)

### Step 3: Install Docker

```bash
sudo apt update
sudo apt install -y docker.io docker-compose-v2

# Add current user to docker group
sudo usermod -aG docker $USER

# Activate group membership
newgrp docker  # No reboot needed for current shell
# OR: sudo reboot  # Required for persistent activation
```

**⚠️ Group membership:** 
- `newgrp docker` — Temporary (current terminal only)
- `reboot` — Permanent (recommended for production)

**Verify Docker:**
```bash
docker run hello-world
docker compose version
```

### Step 4: Configure Ollama for Bridge Networking

Ollama defaults to `127.0.0.1:11434` (localhost only). Configure to accept connections from Docker bridge network:

```bash
sudo mkdir -p /etc/systemd/system/ollama.service.d

sudo tee /etc/systemd/system/ollama.service.d/override.conf > /dev/null << 'EOF'
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
EOF

sudo systemctl daemon-reload
sudo systemctl restart ollama
```

**Verify networking:**
```bash
# Test localhost access
curl http://localhost:11434/api/tags

# Test Docker bridge access (simulates container)
curl http://172.17.0.1:11434/api/tags

# Both should return JSON with model list
```

**Why this matters:** Docker containers use bridge network (172.17.0.0/16) and access host via gateway IP (172.17.0.1). Without this configuration, Open WebUI cannot reach Ollama.

### Step 5: Clone Repository

```bash
git clone https://github.com/YOUR_USERNAME/openwebui-systemd-stack.git
cd openwebui-systemd-stack
```

### Step 6: Install systemd Service

```bash
mkdir -p ~/.config/systemd/user
cp systemd/openwebui.service ~/.config/systemd/user/
systemctl --user daemon-reload
```

**Service configuration:**
```ini
[Unit]
Description=Open WebUI for Ollama
Documentation=https://docs.openwebui.com

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=%h/openwebui-stack
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down

[Install]
WantedBy=default.target
```

**Design notes:**
- `Type=oneshot` with `RemainAfterExit=yes` — Proper pattern for docker-compose
- User service (`~/.config/systemd/user/`) — No root privileges required
- `WorkingDirectory=%h/openwebui-stack` — Expands to home directory

### Step 7: Install Desktop Integration

```bash
mkdir -p ~/.local/share/applications
cp desktop/*.desktop ~/.local/share/applications/
update-desktop-database ~/.local/share/applications/

chmod +x scripts/*.sh
```

**Desktop launchers:**
- **Open WebUI (Start)** — Launches service + browser
- **Open WebUI (Stop)** — Graceful shutdown
- **Open WebUI (Status)** — Shows resource usage

### Step 8: Start Service

```bash
systemctl --user start openwebui

# Monitor startup logs
journalctl --user -u openwebui -f
```

**Wait for initialization (~10-15 seconds):**
```bash
# Check container health
docker ps | grep open-webui

# Verify HTTP response
curl http://localhost:3000/health
```

**Launch browser:**
```bash
xdg-open http://localhost:3000
```

### Step 9: File Organization (Optional — for Git publishing)

**Concept:** Separate reference copies (in Git) from working copies (used by system).

**Reference copies (tracked by Git):**
```
~/openwebui-stack/systemd/openwebui.service
~/openwebui-stack/desktop/*.desktop
```

**Working copies (system locations):**
```
~/.config/systemd/user/openwebui.service
~/.local/share/applications/openwebui*.desktop
```

**Update workflow:**
1. Edit reference copy in project directory
2. Copy to system location: `cp systemd/openwebui.service ~/.config/systemd/user/`
3. Reload systemd: `systemctl --user daemon-reload`
4. Commit to Git: `git add systemd/openwebui.service && git commit`

**Why not symlinks?** systemd and desktop environments may not follow symlinks reliably. Explicit copies ensure compatibility.

---

## Usage

### Desktop Integration

**GUI Method:**
1. Open application menu
2. Search **"Open WebUI"**
3. Click launcher

**Available actions:**
- **Open WebUI (Start)** — `scripts/start-with-browser.sh`
- **Open WebUI (Stop)** — `scripts/stop.sh`
- **Open WebUI (Status)** — `scripts/status.sh`

### systemd Management

```bash
# Lifecycle
systemctl --user start openwebui
systemctl --user stop openwebui
systemctl --user restart openwebui
systemctl --user status openwebui

# Auto-start on login (optional)
systemctl --user enable openwebui
systemctl --user disable openwebui

# Logs
journalctl --user -u openwebui -f         # Follow live logs
journalctl --user -u openwebui -n 100     # Last 100 lines
journalctl --user -u openwebui --since "1 hour ago"
```

### Docker Direct Access

```bash
# Container status
docker ps | grep open-webui

# Logs
docker logs open-webui -f

# Resource usage
docker stats open-webui

# Shell access
docker exec -it open-webui sh
```

---

## Configuration

### docker-compose.yml

```yaml
services:
  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: open-webui
    ports:
      - "3000:8080"
    environment:
      - OLLAMA_BASE_URL=http://172.17.0.1:11434
    volumes:
      - open-webui:/app/backend/data
    restart: "no"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  open-webui:
```

**Key parameters:**

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| `ports: 3000:8080` | Host 3000 → Container 8080 | Avoids conflict with other services on 8080 |
| `OLLAMA_BASE_URL` | `http://172.17.0.1:11434` | Docker bridge gateway (standard Docker networking) |
| `restart: "no"` | Manual control | Battery optimization, explicit lifecycle management |
| `volumes` | Named volume | Data persistence across container recreation |
| `healthcheck` | HTTP probe | Ensures container readiness before routing traffic |

**Networking comparison:**

| Mode | OLLAMA_BASE_URL | Pros | Cons |
|------|----------------|------|------|
| **Bridge** (used) | `http://172.17.0.1:11434` | Standard pattern, explicit config, portfolio-friendly | Requires Ollama config |
| **Host** | `http://localhost:11434` | Simpler, no Ollama config | Port 8080 conflict risk, less portable |

---

## File Structure

```
openwebui-systemd-stack/
├── README.md                       # Documentation
├── LICENSE                         # MIT License
├── docker-compose.yml              # Container orchestration
├── .gitignore                      # Git exclusions
│
├── systemd/
│   └── openwebui.service          # Service definition (reference copy)
│
├── desktop/
│   ├── openwebui-start.desktop    # GUI launcher (reference copy)
│   ├── openwebui-stop.desktop     # Stop launcher (reference copy)
│   └── openwebui-status.desktop   # Status launcher (reference copy)
│
├── scripts/
│   ├── start-with-browser.sh      # Launch helper
│   ├── stop.sh                    # Shutdown helper
│   └── status.sh                  # Resource monitor
│
└── docs/
    ├── TROUBLESHOOTING.md         # Issue resolution guide
    └── screenshot.png             # UI preview

# System locations (NOT in Git):
~/.config/systemd/user/openwebui.service
~/.local/share/applications/openwebui*.desktop
```

---

## Adding Models

```bash
# Pull new model
ollama pull llama3.1:8b

# Model appears immediately in Open WebUI
# No service restart required
```

**Model management:**
```bash
# List installed models
ollama list

# Remove model
ollama rm modelname

# Update model
ollama pull modelname
```

---

## Resource Usage

**Baseline (container idle, no inference):**
- **RAM:** 150-200 MB
- **CPU:** <1%
- **Battery impact:** ~1-2% per hour

**Active inference (mistral:7b):**
- **RAM:** +3-4 GB (model loaded to memory)
- **CPU:** 80-100% during generation
- **Battery impact:** ~10-15% per hour

**Why manual control matters:**
- Auto-start adds 20-30% daily battery drain on laptops (even idle)
- Manual start/stop = use when needed, conserve energy otherwise
- Perfect for battery-conscious workflows (conferences, remote work, travel)

---

## Troubleshooting

**Full guide:** [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

### Quick Diagnostics

```bash
# System components
sudo systemctl status docker        # Docker daemon
systemctl status ollama            # Ollama service
systemctl --user status openwebui  # Open WebUI service

# Network connectivity
curl http://localhost:11434/api/tags       # Ollama API
curl http://172.17.0.1:11434/api/tags      # Docker bridge access
curl http://localhost:3000/health          # Open WebUI health

# Container inspection
docker ps | grep open-webui                # Running state
docker logs open-webui --tail 50           # Recent logs
docker stats open-webui --no-stream        # Resource usage

# Group membership
groups | grep docker                       # Docker group
```

### Common Issues

#### Problem: Permission denied on Docker socket

**Symptom:**
```
permission denied while trying to connect to the Docker daemon socket
```

**Solution:**
```bash
sudo usermod -aG docker $USER
sudo reboot  # Group changes require full reboot for systemd user services
```

**Why:** systemd user services inherit session groups. Group membership changes don't propagate to existing sessions.

---

#### Problem: Open WebUI shows no models

**Symptom:** Model dropdown is empty in UI

**Root cause:** Ollama listening on 127.0.0.1 only (not accessible from Docker bridge)

**Solution:**
```bash
# Configure Ollama to listen on all interfaces
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo tee /etc/systemd/system/ollama.service.d/override.conf > /dev/null << 'EOF'
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
EOF

sudo systemctl daemon-reload
sudo systemctl restart ollama

# Verify Docker bridge access
curl http://172.17.0.1:11434/api/tags
```

---

#### Problem: Desktop launchers disappeared

**Symptom:** No "Open WebUI" in application menu after file reorganization

**Root cause:** Files moved instead of copied

**Solution:**
```bash
# Restore from reference copies
cp systemd/openwebui.service ~/.config/systemd/user/
cp desktop/*.desktop ~/.local/share/applications/
systemctl --user daemon-reload
update-desktop-database ~/.local/share/applications/
```

---

#### Problem: Container fails to start

**Check logs:**
```bash
journalctl --user -u openwebui -n 50
docker logs open-webui
```

**Common causes:**
- Port 3000 already in use: `sudo lsof -i :3000`
- Ollama not running: `systemctl status ollama`
- Docker not running: `sudo systemctl status docker`

---

## Updates

```bash
cd ~/openwebui-stack

# Update Open WebUI image
docker compose pull

# Restart service with new image
systemctl --user restart openwebui

# Verify version
docker inspect open-webui | grep -i created
```

---

## Backup and Restore

### Backup Chat History

```bash
# Create timestamped backup
docker run --rm \
  -v openwebui-stack_open-webui:/data:ro \
  -v $(pwd):/backup \
  ubuntu tar czf /backup/openwebui-backup-$(date +%Y%m%d-%H%M%S).tar.gz -C /data .

# Verify backup
ls -lh openwebui-backup-*.tar.gz
```

### Restore from Backup

```bash
# Stop service
systemctl --user stop openwebui

# Restore data
docker run --rm \
  -v openwebui-stack_open-webui:/data \
  -v $(pwd):/backup \
  ubuntu tar xzf /backup/openwebui-backup-YYYYMMDD-HHMMSS.tar.gz -C /data

# Restart service
systemctl --user start openwebui
```

---

## Advanced Configuration

### Auto-start on Login

```bash
# Enable
systemctl --user enable openwebui

# Disable
systemctl --user disable openwebui

# Check status
systemctl --user is-enabled openwebui
```

### Custom Port

Edit `docker-compose.yml`:
```yaml
ports:
  - "8080:8080"  # Change 3000 to desired port
```

Then:
```bash
systemctl --user restart openwebui
```

### Resource Limits

Add to `docker-compose.yml`:
```yaml
services:
  open-webui:
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 4G
        reservations:
          memory: 512M
```

### Firewall Configuration

```bash
# Allow local access only
sudo ufw deny 3000
sudo ufw allow from 127.0.0.1 to any port 3000

# Protect Ollama API
sudo ufw deny 11434
sudo ufw allow from 172.17.0.0/16 to any port 11434
```

---

## Security Considerations

**Current security posture:**
- ✅ User-level service (non-root execution)
- ✅ Localhost-only exposure (no external network access)
- ✅ Docker isolation (container sandboxing)
- ✅ Named volumes (data persistence without host filesystem exposure)
- ✅ Explicit network routing (no host mode)

**GDPR compliance:**
- ✅ Data processed locally (no external API calls)
- ✅ No telemetry or tracking
- ✅ Full data ownership
- ✅ Right to erasure (delete Docker volume)

**Production hardening (optional):**
```bash
# Run as dedicated user
sudo useradd -r -s /bin/false openwebui-svc

# SELinux/AppArmor profiles
# Secrets management (Docker secrets)
# TLS termination (nginx reverse proxy)
```

---

## Why This Setup?

Most AI tutorials provide single `docker run` commands. This repository demonstrates production-grade infrastructure:

### DevOps Practices

✅ **Infrastructure as Code** — Declarative configuration, version-controlled  
✅ **Service Management** — systemd lifecycle, dependency ordering  
✅ **Observability** — Structured logging (journalctl), health checks  
✅ **Desktop Integration** — Native OS integration patterns  
✅ **Documentation-Driven** — Real troubleshooting, architecture decisions explained  
✅ **Operational Thinking** — Battery optimization, resource awareness

### Technical Decisions

| Aspect | Choice | Rationale |
|--------|--------|-----------|
| **Service type** | User service (not system) | No root required for daily operations |
| **Networking** | Bridge mode (not host) | Standard Docker pattern, explicit routing |
| **Restart policy** | Manual (not always) | Battery-conscious, intentional resource usage |
| **Configuration** | Separate reference/working copies | Git-friendly, clear separation of concerns |
| **Logging** | journalctl integration | Centralized log management |

### Use Cases

**Ideal for:**
- 🎯 DevOps/SRE portfolio projects
- 🎯 Privacy-focused AI workflows (GDPR compliance)
- 🎯 Offline development environments
- 🎯 Learning infrastructure automation
- 🎯 Battery-conscious laptop users
- 🎯 German tech market (data sovereignty requirements)

**Learning outcomes:**
- Docker Compose orchestration
- systemd service design patterns
- Linux desktop integration (XDG standards)
- Network architecture decisions
- Operational trade-offs (performance vs battery)
- Infrastructure documentation

---

## Project Structure Philosophy

**Reference copies (in Git):**
- Version-controlled
- Documentation of "known good" configuration
- Portable across systems

**Working copies (system locations):**
- Active configuration used by OS
- Not tracked by Git
- Can diverge for local customization

**Workflow:**
1. Modify reference copy
2. Test locally
3. Copy to system location
4. Verify functionality
5. Commit to Git

This pattern enables:
- Clean Git history (no system-specific paths)
- Easy rollback (reference copy = truth)
- Local customization without polluting repository

---

## Contributing

Contributions welcome! This project follows German DevOps community standards:

**Requirements:**
- ✅ Test on Ubuntu 22.04 LTS (German market standard)
- ✅ Update documentation (German/English clarity)
- ✅ Conventional commits (`feat:`, `fix:`, `docs:`)
- ✅ No hardcoded credentials or API keys
- ✅ Maintain GDPR compliance

**Pull request checklist:**
- [ ] Tested on clean Ubuntu 22.04 installation
- [ ] Documentation updated (README + TROUBLESHOOTING if applicable)
- [ ] No breaking changes to systemd service
- [ ] Energy impact documented (if changing Docker configuration)

---

## License

MIT License — See [LICENSE](LICENSE)

Free for commercial and personal use. Attribution appreciated but not required.

---

## Acknowledgments

This project builds on excellent work from the open-source community:

**🙏 Core Technologies:**
- **[Open WebUI Team](https://github.com/open-webui/open-webui)** — Outstanding self-hosted ChatGPT alternative. Special appreciation for clean architecture, comprehensive documentation, and responsive community support.
- **[Ollama](https://ollama.ai/)** — Elegant local LLM runtime. Remarkable work simplifying model deployment and management.
- **[Ubuntu Community](https://ubuntu.com/community)** — Solid foundation for systemd and Docker infrastructure.

**🤖 Model Providers:**
- **[Mistral AI](https://mistral.ai/)** — Exceptional open models with strong multilingual support
- **[Meta AI (LLaMA)](https://ai.meta.com/llama/)** — Pioneering open-source LLM development
- **[Google (Gemma)](https://ai.google.dev/gemma)** — Lightweight, efficient models
- **[Alibaba (Qwen)](https://github.com/QwenLM/Qwen)** — Excellent multilingual capabilities

**💡 Inspiration:**
- German DevOps community emphasis on energy efficiency
- GDPR-first design principles
- Battery-conscious computing movement

**Special thanks to Open WebUI contributors** for creating production-grade software that respects user privacy and runs entirely offline. This is the future of AI tooling.

---

## DevOps Learning Outcomes

**Infrastructure Skills:**
- Docker Compose multi-container orchestration
- systemd service design and lifecycle management
- Linux networking (bridge mode, gateway routing)
- XDG desktop integration standards

**Operational Skills:**
- Structured logging and observability
- Health checks and monitoring
- Backup/restore procedures
- Resource optimization (battery, CPU, memory)

**Documentation Skills:**
- Technical writing for infrastructure
- Troubleshooting methodology
- Architecture decision records (ADRs)
- User-centric documentation

**Workflow Skills:**
- Git-based configuration management
- Separation of concerns (reference vs working copies)
- Version control for infrastructure
- Reproducible deployments

**German Market Relevance:**
- GDPR compliance by design
- Data sovereignty (local processing)
- Energy efficiency (battery optimization)
- Privacy-first architecture

---

## Support

**Documentation:**
- Full troubleshooting guide: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
- Open WebUI docs: [https://docs.openwebui.com](https://docs.openwebui.com)
- Ollama documentation: [https://github.com/ollama/ollama/tree/main/docs](https://github.com/ollama/ollama/tree/main/docs)

**Community:**
- GitHub Issues: [YOUR_USERNAME/openwebui-systemd-stack/issues](https://github.com/YOUR_USERNAME/openwebui-systemd-stack/issues)
- Open WebUI Discord: [https://discord.gg/5rJgQTnV4s](https://discord.gg/5rJgQTnV4s)
- Ollama Discord: [https://discord.gg/ollama](https://discord.gg/ollama)

---

## Roadmap

### Planned Features
- [ ] Prometheus monitoring for container metrics
- [ ] GitHub Actions CI/CD pipeline
- [ ] Ansible playbook for automated deployment
- [ ] Multi-distribution support (Fedora, Arch)
- [ ] Resource limits and quotas

### Completed
- [x] systemd user service integration
- [x] Docker bridge networking setup
- [x] Desktop launchers (XDG standards)
- [x] Comprehensive documentation
- [x] Battery-optimized manual control

Want to contribute? Open an issue or PR!

---

## My Setup

**Hardware:** HP EliteBook 845 G8  
**OS:** Ubuntu 24.04 LTS  
**Docker:** 24.0+  
**Use case:** Daily driver for development + local AI experiments

### Models I Use

| Model | Size | Purpose |
|-------|------|---------|
| `mistral` | ~4.1 GB | Universal workhorse - general tasks + coding |
| `qwen3:14b` | ~9 GB | Heavy lifting - best reasoning for complex problems |
| `gemma3:3b` | ~2 GB | Quick responses for simple questions |
| `codellama:7b` | ~3.8 GB | Code-specific tasks (refactoring, debugging) |

**Model selection strategy:**
- Start with `gemma3:3b` for quick questions (saves battery)
- Switch to `mistral` for coding + general work
- Use `qwen3:14b` when I need best quality (slower, but worth it)
- `codellama:7b` for dedicated code review sessions

---

## License

MIT License - see [LICENSE](LICENSE) file.

**Built with:** 🐳 Docker • ⚙️ systemd • 🐧 Linux • 🤖 Ollama

