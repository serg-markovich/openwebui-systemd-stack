#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "🚀 Starting Open WebUI..."
systemctl --user start openwebui

echo "⏳ Waiting for service to be ready..."
sleep 25  # Увеличили время для health check

if docker ps | grep -q open-webui; then
    echo "✅ Service started successfully"
    xdg-open http://localhost:3000
    echo "🌐 Browser opened to http://localhost:3000"
else
    echo "❌ Service failed to start. Check logs:"
    echo "   systemctl --user status openwebui"
    echo "   journalctl --user -u openwebui -n 20"
    exit 1
fi
