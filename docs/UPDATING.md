# Updating Open WebUI

This project uses a hybrid update strategy to balance stability with ease of maintenance.

---

## 🔔 Update Strategy

1. **Automated checks (GitHub Actions)**  
   A scheduled workflow runs weekly and checks for the latest Open WebUI release.  
   If a newer version is found, it automatically creates an Issue in this repository.

2. **Notification instead of auto-update**  
   The workflow does not change your files automatically.  
   It opens an Issue so you can review the changelog and update when ready.

3. **Manual trigger**  
   You apply the update locally (via script or manual steps) and commit changes.

---

## 🚀 Option 1: Quick Update via Script

Use the automated script to update both repository code and Docker images:

```bash
cd ~/openwebui-stack
./scripts/update.sh
```

The script will:

1. Stop the service via systemd
2. Pull the latest Docker image (with network retry logic)
3. Restart the service
4. Clean up old images
5. Verify the container is healthy

After completion, open http://localhost:3000 and verify everything works.

---

## 🎯 Option 2: Manual Version-Pinned Update

Use this when a new release is published and you want to pin to a specific version.

### Step 1: Check the changelog

Review release notes for breaking changes or migrations:

https://github.com/open-webui/open-webui/releases

### Step 2: Update Docker image tag

Edit `docker-compose.yml`:

```yaml
services:
  open-webui:
    image: ghcr.io/open-webui/open-webui:v0.8.2  # Change to new version
```

### Step 3: Apply the update

```bash
cd ~/openwebui-stack

# Stop service
systemctl --user stop openwebui

# Pull new image
docker compose pull open-webui

# Start service
systemctl --user start openwebui
```

### Step 4: Verify

```bash
# Check container status
docker ps | grep open-webui

# Check service status
systemctl --user status openwebui

# Test web interface
curl -I http://localhost:3000
```

Open http://localhost:3000 in browser and verify chats are intact.

### Step 5: Commit changes

```bash
git add docker-compose.yml
git commit -m "chore(deps): update open-webui to v0.8.2"
git push
```

### Step 6: Close the automated Issue

If GitHub Actions created an Issue, close it with a comment:

> Updated to v0.8.2 - tested and working.

---

## ✅ Post-Update Checklist

After any update, verify:

- [ ] `docker ps` shows container as `Up` and `healthy`
- [ ] `systemctl --user status openwebui` shows `active (exited)`
- [ ] http://localhost:3000 loads successfully
- [ ] Existing chats and settings are preserved

---

## 🔧 Troubleshooting

For network issues during `docker compose pull` (timeouts, connection resets):

See [Troubleshooting Guide - Docker Pull Issues](TROUBLESHOOTING.md#problem-docker-pull-issues-connection-reset--timeouts)

For other issues (service won't start, permission errors, port conflicts):

See [Troubleshooting Guide](TROUBLESHOOTING.md)