#!/usr/bin/env bash
set -euo pipefail

echo "🔄 Starting Open WebUI update..."

# Get project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

# Stop service properly
echo "🛑 Stopping service..."
systemctl --user stop openwebui

# Pull with retry logic and increased timeout
echo "🐳 Pulling latest Docker image..."
MAX_RETRIES=3
RETRY_COUNT=0

until COMPOSE_HTTP_TIMEOUT=300 docker compose pull open-webui; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo "❌ Failed after $MAX_RETRIES attempts. Check your network."
        exit 1
    fi
    echo "⚠️  Pull failed. Retry $RETRY_COUNT/$MAX_RETRIES in 5 seconds..."
    sleep 5
done

# Start service through systemd
echo "🚀 Starting service..."
systemctl --user start openwebui

# Wait for health check
echo "⏳ Waiting for container to be healthy..."
sleep 15

# Verify
if docker ps | grep -q "open-webui.*healthy"; then
    echo "✅ Update successful!"
    docker inspect open-webui --format 'Current version: {{.Config.Image}}'
else
    echo "⚠️  Container started but not healthy yet. Check: systemctl --user status openwebui"
fi

# Clean up old images
echo "🧹 Cleaning up old images..."
docker image prune -f

echo ""
echo "Done! Open WebUI is running at http://localhost:3000"
