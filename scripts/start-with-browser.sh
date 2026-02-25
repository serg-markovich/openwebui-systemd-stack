#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "🚀 Starting Open WebUI..."
systemctl --user start openwebui

echo "⏳ Waiting for the application to become fully ready (this may take up to a minute)..."

# HTTP Health Check loop: Wait until the server returns an HTTP 200 OK status
MAX_RETRIES=30
RETRY_COUNT=0

while true; do
    # Fetch the HTTP status code using curl (returns 000 if connection is refused)
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 || echo "000")
    
    if [ "$HTTP_STATUS" -eq 200 ]; then
        echo "✅ Application API is up and responding!"
        break
    fi

    if [ "$RETRY_COUNT" -ge "$MAX_RETRIES" ]; then
        echo "❌ Service failed to become ready within 60 seconds."
        echo "   Please check the logs:"
        echo "   systemctl --user status openwebui"
        echo "   journalctl --user -u openwebui -n 50"
        sleep 10
        exit 1
    fi

    sleep 2
    RETRY_COUNT=$((RETRY_COUNT + 1))
done

# Add a tiny buffer to allow the frontend to fully load static assets
sleep 3

echo "🌐 Opening browser to http://localhost:3000..."

# Run xdg-open in the background, detached from the terminal process
nohup xdg-open http://localhost:3000 >/dev/null 2>&1 &

# Small delay to ensure the D-Bus message reaches the browser before terminal exits
sleep 2

