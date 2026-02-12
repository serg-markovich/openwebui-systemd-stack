#!/bin/bash
set -e

echo "Starting Open WebUI..."

if ! systemctl is-active --quiet docker; then
    notify-send "Open WebUI" "Docker not running. Starting..." --icon=dialog-warning
    sudo systemctl start docker
    sleep 2
fi

systemctl --user start openwebui

echo "Waiting for service to be ready..."
for i in {1..30}; do
    if curl -s http://localhost:3000/health > /dev/null 2>&1; then
        notify-send "Open WebUI" "Started successfully!" --icon=dialog-information
        xdg-open http://localhost:3000
        exit 0
    fi
    sleep 1
done

notify-send "Open WebUI" "Timeout waiting for service" --icon=dialog-error
exit 1
