.DEFAULT_GOAL := help

.PHONY: help install start stop restart status logs update backup restore lint doctor

help:
	@echo "Open WebUI systemd Stack"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "  install   Render systemd service and desktop launchers (run once)"
	@echo "  start     Start Open WebUI"
	@echo "  stop      Stop Open WebUI"
	@echo "  restart   Restart Open WebUI"
	@echo "  status    Show service and container status"
	@echo "  logs      Follow container logs (Ctrl+C to exit)"
	@echo "  update    Re-pull pinned image and restart"
	@echo "  backup    Save chat history to backups/"
	@echo "  restore   Restore from backup: make restore FILE=backups/file.tar.gz"
	@echo "  lint      Run bash -n, shellcheck, compose validation"
	@echo "  doctor    Check environment (docker, ollama, ports, config)"


install:
	@echo "📦 Installing systemd service..."
	mkdir -p ~/.config/systemd/user/
	sed "s|%%INSTALL_PATH%%|$(PWD)|g" systemd/openwebui.service.template \
		> ~/.config/systemd/user/openwebui.service
	systemctl --user daemon-reload
	@echo "🖥️  Installing desktop launchers..."
	mkdir -p ~/.local/share/applications/
	for f in desktop/*.desktop.template; do \
		sed "s|%%INSTALL_PATH%%|$(PWD)|g" "$$f" \
			> ~/.local/share/applications/$$(basename $$f .template); \
	done
	update-desktop-database ~/.local/share/applications/ 2>/dev/null || true

start:
	systemctl --user start openwebui
	@echo "✅ Open WebUI started → http://localhost:3000"

stop:
	systemctl --user stop openwebui
	@echo "✅ Open WebUI stopped."

restart:
	systemctl --user restart openwebui
	@echo "✅ Open WebUI restarted → http://localhost:3000"

status:
	@systemctl --user status openwebui --no-pager || true
	@echo ""
	@docker ps --filter name=open-webui --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

logs:
	docker logs open-webui -f

update:
	bash scripts/update.sh

backup:
	@mkdir -p backups
	docker run --rm \
		-v openwebui-stack_open-webui:/data \
		-v $(PWD)/backups:/backup \
		alpine tar czf /backup/openwebui-$(shell date +%Y%m%d-%H%M).tar.gz /data
	@echo "✅ Backup saved to backups/"

restore:
	@test -n "$(FILE)" || (echo "❌ Usage: make restore FILE=backups/openwebui-YYYYMMDD-HHMM.tar.gz" && exit 1)
	docker run --rm \
		-v openwebui-stack_open-webui:/data \
		-v $(PWD)/backups:/backup \
		alpine sh -c "cd / && tar xzf /backup/$(notdir $(FILE))"
	@echo "✅ Restored from $(FILE)"

lint:
	@set -e; for f in scripts/*.sh; do bash -n "$$f"; done; echo "✅ Bash syntax OK"
	@if command -v shellcheck >/dev/null 2>&1; then shellcheck scripts/*.sh && echo "✅ shellcheck OK"; else echo "⚠️  shellcheck not installed — skipped"; fi
	@docker compose config -q && echo "✅ Compose config OK"

doctor:
	@echo "== Docker =="
	@docker --version 2>/dev/null || echo "❌ docker not found"
	@docker compose version 2>/dev/null || echo "❌ docker compose v2 not found"
	@docker info >/dev/null 2>&1 && echo "✅ daemon reachable" || echo "❌ daemon unreachable (check docker group)"
	@echo "== Ollama =="
	@systemctl is-active --quiet ollama && echo "✅ ollama active" || echo "⚠️  ollama not active"
	@systemctl cat ollama 2>/dev/null | grep -q 'OLLAMA_HOST=0.0.0.0' && echo "✅ OLLAMA_HOST=0.0.0.0" || echo "⚠️  OLLAMA_HOST override not detected"
	@curl -fsS --max-time 3 http://172.17.0.1:11434/api/tags >/dev/null 2>&1 && echo "✅ Ollama reachable via bridge" || echo "❌ Ollama unreachable at 172.17.0.1:11434"
	@echo "== Service =="
	@systemctl --user is-active --quiet openwebui && echo "✅ openwebui active" || echo "⚠️  openwebui not active"
	@echo "== Ports =="
	@if command -v ss >/dev/null 2>&1; then ss -ltn | grep -q ":$${WEBUI_PORT:-3000} " && echo "⚠️  port $${WEBUI_PORT:-3000} in use" || echo "✅ port $${WEBUI_PORT:-3000} free"; else echo "⚠️  ss not found — port check skipped"; fi
	@echo "== Config =="
	@docker compose config -q && echo "✅ Compose config valid"

