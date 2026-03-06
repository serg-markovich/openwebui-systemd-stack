# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [1.3.0] - 2026-03-06

### Added
- `Makefile` — unified entry point: `make install`, `make start`, `make stop`, `make status`, `make logs`, `make update`
- `ci.yml` — GitHub Actions CI: validates docker-compose, checks required files, runs shellcheck on all scripts
- `.env.example` — documents `OLLAMA_BASE_URL` and `WEBUI_PORT`

### Fixed
- `stop.sh` — dead code after `set -e` removed, `notify-send` fallback added for headless environments
- `start-with-browser.sh` — `PROJECT_ROOT` now used via `cd` (shellcheck SC2034)
- `check-updates.yml` — guard against unpinned image tags (`latest`/`main`)

### Removed
- `FUNDING.yml` — misleading file, not a sponsor project

---

**Full Changelog**: https://github.com/serg-markovich/openwebui-systemd-stack/compare/v1.2.0...v1.3.0

## [1.2.0] - 2026-02-16

### Fixed
- Universal paths in systemd service using %h variable
- Removed hardcoded absolute paths from all components
- Fixed start-with-browser.sh to work from any project location
- Desktop launchers now use portable paths

### Changed
- systemd service simplified: removed docker.service dependency
- Startup wait replaced with HTTP health check loop (was: sleep 8s)
- update.sh script now auto-detects project root via BASH_SOURCE
- Desktop launchers use portable $HOME paths
- WorkingDirectory=%h/openwebui-stack for portability
- Added notes about custom installation paths


## [1.1.0] - 2026-02-15

### Added
- Automated update script with network retry logic
- GitHub Actions workflow for monitoring releases
- systemd integration in update script
- Comprehensive update documentation

### Changed
- Consolidated network troubleshooting
- Improved documentation structure
- Updated documentation with personal context
- Added hardware specs and model usage patterns
- Documented debugging journey


## [1.0.0] - 2026-02-09

### Added
- Initial release of systemd-managed Open WebUI stack
- systemd user service for Docker Compose lifecycle
- Docker bridge networking configuration
- XDG desktop launchers
- Comprehensive documentation
- Battery optimization via manual control
- GDPR-compliant local AI setup
