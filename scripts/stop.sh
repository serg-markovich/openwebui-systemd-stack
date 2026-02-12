#!/bin/bash
set -e

echo "🛑 Остановка Open WebUI..."
systemctl --user stop openwebui

if [ $? -eq 0 ]; then
    notify-send "Open WebUI" "✅ Контейнер остановлен" --icon=dialog-information
else
    notify-send "Open WebUI" "⚠️ Ошибка при остановке" --icon=dialog-error
fi
