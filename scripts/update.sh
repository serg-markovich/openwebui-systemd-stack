#!/bin/bash

# Stop on errors, but allow retry loops to handle their specific errors
set -e

echo "🔄 Starting Open WebUI update..."

echo "📥 Pulling latest git changes..."
git pull

echo "🐳 Pulling Docker images (with robust retry logic)..."
# Loop until successful pull. Waits 5 seconds between attempts.
# Increases HTTP timeout to handle slow connections.
until COMPOSE_HTTP_TIMEOUT=300 docker compose pull; do
    echo "⚠️ Pull failed (network issue). Retrying in 5 seconds..."
    sleep 5
done

echo "🚀 Recreating containers..."
docker compose up -d --remove-orphans

echo "🧹 Cleaning up old images..."
docker image prune -f

echo "✅ Success! Open WebUI updated."
