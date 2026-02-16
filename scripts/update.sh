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
docker compose pull open-webui

echo "3️⃣ Starting service..."
systemctl --user start openwebui

echo
echo "✅ Update complete."
echo "Current image:"
docker inspect open-webui --format '{{.Config.Image}}' 2>/dev/null || echo "Container not running"
