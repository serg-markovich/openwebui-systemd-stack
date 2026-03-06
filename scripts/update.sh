#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "🔄 Updating Open WebUI..."
echo "Project: $PROJECT_ROOT"
echo

echo "1️⃣ Stopping service..."
systemctl --user stop openwebui || true

echo "2️⃣ Pulling latest image..."
cd "$PROJECT_ROOT"
RETRIES=5
SUCCESS=false
for i in $(seq 1 $RETRIES); do
    if docker compose pull open-webui; then
        SUCCESS=true
        break
    fi
    echo "⚠️  Attempt $i/$RETRIES failed, retrying in 10s..."
    sleep 10
done

if [ "$SUCCESS" = false ]; then
    echo "❌ Failed to pull image after $RETRIES attempts. Restarting with existing image..."
    systemctl --user start openwebui
    exit 1
fi

echo "3️⃣ Starting service..."
systemctl --user start openwebui

echo
echo "✅ Update complete."
echo "Current image:"
docker inspect open-webui --format '{{.Config.Image}}' 2>/dev/null || echo "Container not running"
