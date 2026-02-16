# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).


## [1.2.0] - 2026-02-16

### Fixed
- Universal paths in systemd service using %h variable
- Removed hardcoded absolute paths from all components
- Fixed start-with-browser.sh to work from any project location
- Desktop launchers now use portable paths

### Changed
- systemd service simplified: removed docker.service dependency
- Increased startup wait time from 8s to 25s for proper health check
- update.sh script now auto-detects project root
- Desktop launchers use inline bash commands

### Technical
- WorkingDirectory=%h/openwebui-stack for portability
- Scripts use auto-detection for project root
- All executable permissions set via chmod +x

### Documentation
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


## [1.0.1] - 2026-02-12

### Changed
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

### Design Decisions
- Bridge networking over host mode
- User service instead of system service
- Manual control for battery savings
- Named Docker volume for data persistence
