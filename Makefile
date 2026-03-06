.DEFAULT_GOAL := help

.PHONY: help install start stop restart status logs update backup restore

help:
	@echo "Open WebUI systemd Stack"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "  install   Copy systemd service and desktop launchers (run once)"
	@echo "  start     Start Open WebUI"
	@echo "  stop      Stop Open WebUI"
	@echo "  restart   Restart Open WebUI"
	@echo "  status    Show service and container status"
	@echo "  logs      Follow container logs (Ctrl+C to exit)"
	@echo "  update    Pull latest image and restart"
	@echo "  backup    Save chat history to backups/"
	@echo "  restore   Restore from backup: make restore FILE=backups/file.tar.gz"


install:
	@echo "📦 Installing systemd service..."
	mkdir -p ~/.config/systemd/user/
	cp systemd/openwebui.service ~/.config/systemd/user/openwebui.service
	systemctl --user daemon-reload
	@echo "🖥️  Installing desktop launchers..."
	mkdir -p ~/.local/share/applications/
	cp desktop/*.desktop ~/.local/share/applications/
	update-desktop-database ~/.local/share/applications/ 2>/dev/null || true
	@echo "✅ Done. Run 'make start' to launch."

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

