# Updating Open WebUI

This project uses a hybrid update strategy to balance stability with ease of maintenance.

---

## Update Strategy

1. Automated checks (GitHub Actions) - weekly checks for latest release
2. Notification instead of auto-update - creates Issue for review
3. Manual trigger - you apply update locally and commit

---

## Option 1: Quick Update via Script

cd ~/openwebui-stack
./scripts/update.sh

The script will stop service, pull image, restart, and verify.

After completion, open http://localhost:3000 and verify.

---

## Option 2: Manual Version-Pinned Update

Step 1: Check changelog at https://github.com/open-webui/open-webui/releases

Step 2: Edit docker-compose.yml and change image tag

Step 3: Apply update
cd ~/openwebui-stack
systemctl --user stop openwebui
docker compose pull open-webui
systemctl --user start openwebui

Step 4: Verify
docker ps | grep open-webui
systemctl --user status openwebui
curl -I http://localhost:3000

Step 5: Commit
git add docker-compose.yml CHANGELOG.md
git commit -m "chore: update open-webui to vX.Y.Z"
git push

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
