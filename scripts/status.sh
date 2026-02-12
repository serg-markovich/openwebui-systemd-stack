#!/bin/bash

echo "=== Open WebUI Status ==="
systemctl --user status openwebui --no-pager
echo ""
echo "=== Docker Container ==="
docker ps -a --filter name=open-webui
echo ""
echo "=== Resource Usage ==="
docker stats open-webui --no-stream 2>/dev/null || echo "Container not running"
