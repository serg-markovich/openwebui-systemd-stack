#!/usr/bin/env bash
set -euo pipefail

echo "🛑 Stopping Open WebUI..."

if systemctl --user stop openwebui; then
    echo "✅ Open WebUI stopped."
    # notify-send is optional (not available on headless or CI)
    if command -v notify-send &>/dev/null; then
        notify-send "Open WebUI" "✅ Container stopped" --icon=dialog-information
    fi
else
    echo "❌ Error while stopping Open WebUI." >&2
    if command -v notify-send &>/dev/null; then
        notify-send "Open WebUI" "⚠️ Error while stopping" --icon=dialog-error
    fi
    exit 1
fi