# Updating Open WebUI

This project uses a hybrid update strategy to balance stability with ease of maintenance.

---

## Update Strategy

1. Automated checks (GitHub Actions) - weekly checks for latest release
2. Notification instead of auto-update - creates Issue for review
3. Manual trigger - you apply update locally and commit

---

## Option 1: Quick Update via Script

```bash
make update
```

The script stops the service, pulls the latest image with retry logic,
restarts, and shows the current image version.

---

## Option 2: Manual Version-Pinned Update

Step 1: Check changelog at https://github.com/open-webui/open-webui/releases

Step 2: Edit docker-compose.yml — change image tag:
image: ghcr.io/open-webui/open-webui:vX.Y.Z

Also update .env.example if you track OPENWEBUI_VERSION there.

Step 3: Apply update

```bash
make update
```

Step 4: Verify

```bash
make status
curl -I http://localhost:3000
```

Step 5: Commit the version bump

```bash
git add docker-compose.yml CHANGELOG.md
git commit -m "chore(deps): update open-webui to vX.Y.Z"
git push
```

---

## Post-Update Checklist

- docker ps shows Up and healthy
- systemctl shows active exited
- localhost:3000 loads
- chats preserved

---

## Troubleshooting

See docs/TROUBLESHOOTING.md for network issues and other problems.

---

## Custom Installation Paths

update.sh auto-detects project root. Works from any location.
