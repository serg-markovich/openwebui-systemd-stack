#!/bin/bash
set -e

echo "🛑 Stopping Open WebUI..."
systemctl --user stop openwebui

if [ $? -eq 0 ]; then
    notify-send "Open WebUI" "✅ Container stopped" --icon=dialog-information
else
    notify-send "Open WebUI" "⚠️ Error while stopping" --icon=dialog-error
fi
