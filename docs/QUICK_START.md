# Quick Start

Get Open WebUI + Ollama systemd stack running in 5 minutes.

## Prerequisites Check

```bash
# Verify requirements
docker --version          # Should be 24.0+
systemctl --version       # Should be 249+
ollama --version          # Should be installed
groups | grep docker      # You should be in docker group
```

If anything is missing, see [Installation Guide](INSTALLATION.md) for detailed setup.

---

## TL;DR - Copy & Paste

```bash
# 1. Clone repository
git clone https://github.com/serg-markovich/openwebui-systemd-stack.git
cd openwebui-systemd-stack

# 2. Configure Ollama for Docker bridge networking (one-time)
sudo mkdir -p /etc/systemd/system/ollama.service.d/
echo -e '[Service]\nEnvironment="OLLAMA_HOST=0.0.0.0:11434"' | \
  sudo tee /etc/systemd/system/ollama.service.d/override.conf

# 3. Restart Ollama to apply configuration
sudo systemctl daemon-reload
sudo systemctl restart ollama

# 4. Setup systemd user service
mkdir -p ~/.config/systemd/user/
cp systemd/openwebui.service ~/.config/systemd/user/
systemctl --user daemon-reload

# 5. Start Open WebUI
systemctl --user start openwebui

# 6. Wait for container to be ready (~15 seconds)
sleep 15

# 7. Open in browser
xdg-open http://localhost:3000
```

**That's it!** 🎉

---

## What Just Happened?

1. **Ollama configuration** - Allowed Docker containers to access Ollama API via bridge network gateway IP (172.17.0.1)
2. **systemd service** - Registered user service to manage Docker Compose lifecycle
3. **Container start** - Docker pulled Open WebUI image and started container
4. **Browser launch** - Opened web interface at localhost:3000

---

## Desktop Launchers (Optional)

Add GUI launchers to application menu:

```bash
# Copy desktop entries
cp desktop/*.desktop ~/.local/share/applications/

# Refresh application database
update-desktop-database ~/.local/share/applications/
```

**Now you can:**
- Start from application menu: "Open WebUI (Start)"
- Stop from application menu: "Open WebUI (Stop)"
- Check status: "Open WebUI (Status)"

---

## Daily Usage

### Start Service

```bash
systemctl --user start openwebui
# or click "Open WebUI (Start)" in application menu
```

### Stop Service

```bash
systemctl --user stop openwebui
# or click "Open WebUI (Stop)" in application menu
```

### Check Status

```bash
systemctl --user status openwebui
# or click "Open WebUI (Status)" in application menu
```

### View Logs

```bash
# Service logs
journalctl --user -u openwebui -f

# Container logs
docker logs open-webui -f
```

---

## Pull Your First Model

```bash
# Quick models (for testing)
ollama pull gemma3:3b          # ~2 GB - fast responses
ollama pull mistral            # ~4.1 GB - general purpose

# Heavier models (better quality)
ollama pull qwen3:14b          # ~9 GB - best reasoning
ollama pull codellama:7b       # ~3.8 GB - code specialist
```

**Model selection tip:** Start with `gemma3:3b` to test setup, then pull larger models based on your needs.

---

## Verify Everything Works

```bash
# Check Ollama is accessible
curl http://172.17.0.1:11434/api/tags

# Check container is running
docker ps | grep open-webui

# Check service is active
systemctl --user is-active openwebui
```

All commands should succeed ✅

---

## Next Steps

- 📖 Read [Architecture Documentation](ARCHITECTURE.md) to understand design decisions
- 🔧 Check [Troubleshooting Guide](TROUBLESHOOTING.md) if issues arise
- ⚙️ See [Installation Guide](INSTALLATION.md) for detailed configuration options

---

## Common First-Time Issues

### Port 3000 Already in Use

**Error:** `bind: address already in use`

**Fix:** Change port in `docker-compose.yml`:
```yaml
ports:
  - "8000:8080"  # Use 8000 instead
```

Then restart: `systemctl --user restart openwebui`

### Container Can't Reach Ollama

**Error:** `Failed to connect to Ollama`

**Fix:** Verify Ollama configuration:
```bash
# Check override is active
systemctl cat ollama.service | grep OLLAMA_HOST

# Should show: Environment="OLLAMA_HOST=0.0.0.0:11434"
```

### Service Won't Start

**Error:** `Failed to start openwebui.service`

**Fix:** Check you're in docker group:
```bash
groups | grep docker

# If not in docker group:
sudo usermod -aG docker $USER
# Then logout and login
```

---

**Got stuck?** See [Troubleshooting Guide](TROUBLESHOOTING.md) for more solutions.

**Working?** Great! Time to chat with your local AI 🤖
