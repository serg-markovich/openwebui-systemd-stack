# Troubleshooting Guide

Common issues and solutions for Open WebUI + Ollama systemd setup.

---

## Problem: Desktop launchers or systemd service stopped working after reorganizing files

**Symptom:**
- Desktop launcher doesn't appear in menu
- systemd service shows "Unit not found"
- Scripts fail to execute

**Cause:**
You moved (not copied) configuration files from system locations (`~/.config/systemd/user/`, `~/.local/share/applications/`) to project directories (`systemd/`, `desktop/`).

**Solution:**

```bash
# Restore systemd service
cp ~/openwebui-stack/systemd/openwebui.service ~/.config/systemd/user/
systemctl --user daemon-reload

# Restore desktop launchers
cp ~/openwebui-stack/desktop/*.desktop ~/.local/share/applications/
update-desktop-database ~/.local/share/applications/

# Verify scripts are executable
chmod +x ~/openwebui-stack/scripts/*.sh
```

**Prevention:**
Always **copy** configuration files to system locations, never move them. Project directories contain reference copies for Git, system locations contain working copies.

---

## Problem: "permission denied" when accessing Docker socket

**Symptom:**

```
permission denied while trying to connect to the Docker daemon socket
```

**Root cause:**
User is not in the `docker` group, or group membership changes haven't taken effect.

**Solution:**

```bash
# Verify user is in docker group
groups | grep docker

# If not present, add user to docker group
sudo usermod -aG docker $USER

# CRITICAL: Full system reboot required
sudo reboot
```

**Why reboot is mandatory:**
systemd user services inherit session groups at login. Group changes don't propagate with `su -` or `newgrp`. Full reboot ensures proper group membership.

**Alternative (temporary, not recommended):**
```bash
# Run specific command with docker group
newgrp docker
systemctl --user start openwebui
```

This works for current session only. Next login will fail without reboot.

---

## Problem: systemd service fails with "No medium found"

**Symptom:**

```
Failed to connect to bus: No medium found
```

**Root cause:**
Using `su - $USER` creates new session without D-Bus socket, breaking systemd user services.

**Solution:**
- Don't use `su - $USER` to switch users
- Close terminal and open new one, OR
- Log out and log back in, OR
- Reboot system

**Why this happens:**
systemd user services require `$DBUS_SESSION_BUS_ADDRESS` environment variable. `su -` creates clean environment without it.

---

## Problem: Open WebUI can't connect to Ollama

**Symptom:**

```
ERROR | Connection error: Cannot connect to host 172.17.0.1:11434
```

**Root cause:**
Ollama listening only on `127.0.0.1:11434` (localhost). Docker containers on bridge network access host via `172.17.0.1` (gateway IP), which isn't listening.

**Solution:**
Configure Ollama to listen on all interfaces:

```bash
sudo mkdir -p /etc/systemd/system/ollama.service.d

sudo tee /etc/systemd/system/ollama.service.d/override.conf > /dev/null << 'EOF'
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
EOF

sudo systemctl daemon-reload
sudo systemctl restart ollama
```

**Verify fix:**

```bash
# Test from host
curl http://localhost:11434/api/tags

# Test from Docker bridge IP
curl http://172.17.0.1:11434/api/tags

# Both should return JSON with model list
```

**Security note:**
`0.0.0.0:11434` means Ollama listens on all network interfaces. If you have firewall rules allowing external access, configure firewall to block port 11434 from external networks:

```bash
sudo ufw deny from any to any port 11434
sudo ufw allow from 172.17.0.0/16 to any port 11434
```

---

## Problem: systemd service fails to start

**Symptom:**

```
openwebui.service: Control process exited with error code
```

**Diagnosis:**

```bash
# Check detailed logs
journalctl --user -u openwebui -n 50 --no-pager

# Check Docker service status
sudo systemctl status docker

# Test docker-compose manually
cd ~/openwebui-stack
docker compose up
```

**Common causes:**

### 1. Docker service not running

```bash
sudo systemctl start docker
sudo systemctl enable docker
```

### 2. docker-compose.yml syntax error

```bash
cd ~/openwebui-stack
docker compose config
# Should output valid configuration
```

### 3. Port 3000 already in use

```bash
sudo lsof -i :3000
# Kill conflicting process or change port in docker-compose.yml
```

### 4. Docker volume permission issues

```bash
docker volume ls
docker volume inspect openwebui-stack_open-webui
# Check if volume exists and is accessible
```

---

## Problem: Container won't start or crashes immediately

**Diagnosis:**

```bash
# Check container logs
docker logs open-webui

# Check container status
docker ps -a | grep open-webui

# Inspect container
docker inspect open-webui
```

**Common causes:**

### 1. Image pull failed

```bash
docker compose pull
# Re-pull image
```

### 2. Out of disk space

```bash
df -h
docker system df
# Clean up if needed:
docker system prune -a
```

### 3. Container health check failing

```bash
# Check health check endpoint manually
docker exec open-webui curl -f http://localhost:8080/health
```

---

## Problem: Can't access localhost:3000

**Diagnosis:**

```bash
# Is container running?
docker ps | grep open-webui

# Is port mapped correctly?
docker port open-webui

# Is something listening on 3000?
sudo lsof -i :3000

# Can you reach container directly?
curl http://localhost:3000/health
```

**Solutions:**

### Port conflict
```bash
# Find process using port 3000
sudo lsof -i :3000
# Kill it or change port in docker-compose.yml
```

### Container not exposing port
Check `docker-compose.yml`:
```yaml
ports:
  - "3000:8080"  # Must be present
```

### Firewall blocking localhost
```bash
sudo ufw status
# localhost should not be blocked, but check anyway
```

---

## Problem: Models don't appear in Open WebUI

**Diagnosis:**

```bash
# Check Ollama has models
ollama list

# Check Ollama API responds
curl http://localhost:11434/api/tags

# Check Open WebUI logs
docker logs open-webui | grep -i ollama
```

**Solutions:**

### 1. Ollama not accessible from container
See "Open WebUI can't connect to Ollama" above.

### 2. No models installed
```bash
ollama pull mistral
ollama pull codellama
```

### 3. Wrong OLLAMA_BASE_URL in docker-compose.yml
Should be:
```yaml
environment:
  - OLLAMA_BASE_URL=http://172.17.0.1:11434
```

---

## Problem: High CPU usage when idle

**Diagnosis:**

```bash
# Check container resource usage
docker stats open-webui

# Check processes inside container
docker exec open-webui ps aux
```

**Expected behavior:**
- Idle container: <1% CPU, ~150-200 MB RAM
- Active inference: High CPU usage is normal

**If CPU high when idle:**
```bash
# Restart container
systemctl --user restart openwebui

# Check for stuck processes
docker logs open-webui --tail 100
```

---

## Problem: Desktop launcher doesn't appear in menu

**Diagnosis:**

```bash
# Check files exist
ls -la ~/.local/share/applications/openwebui*.desktop

# Check file permissions
ls -la ~/openwebui-stack/scripts/*.sh
```

**Solutions:**

### 1. Desktop files not installed
```bash
cp ~/openwebui-stack/desktop/*.desktop ~/.local/share/applications/
update-desktop-database ~/.local/share/applications/
```

### 2. Scripts not executable
```bash
chmod +x ~/openwebui-stack/scripts/*.sh
```

### 3. Wrong paths in .desktop files
Edit `~/.local/share/applications/openwebui-start.desktop`:
```ini
Exec=/home/YOUR_USERNAME/openwebui-stack/scripts/start-with-browser.sh
```
Replace `YOUR_USERNAME` with actual username.

### 4. Desktop database not updated
```bash
update-desktop-database ~/.local/share/applications/
# Log out and log back in
```

---

## Problem: Script fails with "command not found"

**Symptom:**
```
./start-with-browser.sh: line 10: docker: command not found
```

**Cause:**
Docker not in PATH, or scripts not sourcing proper environment.

**Solution:**

```bash
# Add Docker to PATH in script
# Edit scripts to use full path:
/usr/bin/docker compose up -d

# Or ensure PATH is set
export PATH="/usr/bin:$PATH"
```

---

## Problem: Browser doesn't open automatically

**Diagnosis:**

```bash
# Test xdg-open manually
xdg-open http://localhost:3000

# Check default browser
xdg-settings get default-web-browser
```

**Solutions:**

### 1. xdg-utils not installed
```bash
sudo apt install xdg-utils
```

### 2. No default browser set
```bash
xdg-settings set default-web-browser firefox.desktop
# Or: google-chrome.desktop, chromium-browser.desktop
```

### 3. Service starts too slow
Increase wait time in `start-with-browser.sh`:
```bash
for i in {1..60}; do  # Increase from 30 to 60
```

---

## Problem: Updates break the setup

**Symptom:**
After `docker compose pull`, service fails to start.

**Solution:**

```bash
# Stop service first
systemctl --user stop openwebui

# Pull updates
cd ~/openwebui-stack
docker compose pull

# Remove old container
docker compose down

# Start fresh
systemctl --user start openwebui

# Check logs
journalctl --user -u openwebui -f
```

---

## Problem: Data loss after container restart

**Symptom:**
Chat history disappears after stopping/starting container.

**Cause:**
Docker volume not persisting data.

**Diagnosis:**

```bash
# Check volume exists
docker volume ls | grep open-webui

# Inspect volume
docker volume inspect openwebui-stack_open-webui
```

**Solution:**

Ensure `docker-compose.yml` has:
```yaml
volumes:
  - open-webui:/app/backend/data

volumes:
  open-webui:
```

If volume was lost, restore from backup (see README.md Backup section).

---

## Debugging Checklist

Before asking for help, verify:

- [ ] Docker service is running: `sudo systemctl status docker`
- [ ] User is in docker group: `groups | grep docker`
- [ ] System rebooted after adding to docker group
- [ ] Container is running: `docker ps | grep open-webui`
- [ ] Port 3000 is not occupied: `sudo lsof -i :3000`
- [ ] Ollama is running: `systemctl status ollama`
- [ ] Ollama API responds: `curl http://localhost:11434/api/tags`
- [ ] Ollama listening on 0.0.0.0: Check override.conf
- [ ] Check systemd logs: `journalctl --user -u openwebui -n 50`
- [ ] Check container logs: `docker logs open-webui`
- [ ] Scripts are executable: `ls -la ~/openwebui-stack/scripts/`
- [ ] Desktop files installed: `ls ~/.local/share/applications/openwebui*.desktop`

---

## Getting Help

If you're still stuck:

1. **Gather logs:**
```bash
# System logs
journalctl --user -u openwebui -n 100 > systemd-logs.txt

# Container logs
docker logs open-webui > container-logs.txt

# System info
docker version > system-info.txt
systemctl --version >> system-info.txt
```

2. **Open GitHub issue** with:
   - Description of problem
   - Steps to reproduce
   - Log files above
   - Output of debugging checklist

3. **Check existing issues:**
   - [GitHub Issues](https://github.com/YOUR_USERNAME/openwebui-systemd-stack/issues)
   - [Open WebUI Docs](https://docs.openwebui.com)
   - [Ollama Troubleshooting](https://github.com/ollama/ollama/blob/main/docs/troubleshooting.md)

---

## Problem: Docker Pull Issues (Connection Reset / Timeouts)

**Symptom:**
- `docker compose pull` fails with `read: connection reset by peer`.
- Download freezes at 0% or stays at the same GB for a long time.
- Connection timeouts when downloading large images (>1GB).

**Solution 1: Use the maintenance script (Recommended)**
The provided update script includes a retry loop and increased timeouts to handle unstable connections.

```
./scripts/update.sh
```

**Solution 2: Limit Concurrent Downloads**
Prevent Docker from saturating your bandwidth, which often causes the reset. Create or edit /etc/docker/daemon.json:

```
{
  "max-concurrent-downloads": 1
}
```

Then restart Docker: 

```
sudo systemctl restart docker.
```

**Solution 3: Temporary IPv4 Force**
If your IPv6 routing is unstable (common with some ISPs), disable it during the pull:

```
sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
./scripts/update.sh
sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0
```

---

## Performance Tuning

### Reduce memory usage

```yaml
# In docker-compose.yml, add:
deploy:
  resources:
    limits:
      memory: 512M
```

### Faster startup

```yaml
# Disable health checks (not recommended for production)
# Remove healthcheck section from docker-compose.yml
```

### Model loading optimization

```bash
# Preload models in Ollama
ollama run mistral ""  # Loads model into memory
```

---

## Known Issues

### Issue: systemd service shows "active" but container not running

**Workaround:**
```bash
systemctl --user stop openwebui
docker compose down
systemctl --user start openwebui
```

### Issue: Desktop launcher works but scripts fail from terminal

**Cause:** Different environment variables.

**Workaround:**
```bash
# Source profile before running scripts
source ~/.profile
~/openwebui-stack/scripts/start-with-browser.sh
```

---

**Still having issues?** Open a [GitHub issue](https://github.com/YOUR_USERNAME/openwebui-systemd-stack/issues) with detailed logs and system information.