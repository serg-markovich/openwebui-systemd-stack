# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Planned
- Prometheus monitoring integration
- GitHub Actions CI/CD pipeline
- Ansible playbook for deployment automation
- Multi-distribution support (Fedora, Arch)

## [1.0.0] - 2026-02-09

### Added
- Initial release of systemd-managed Open WebUI stack
- systemd user service for Docker Compose lifecycle
- Docker bridge networking configuration
- XDG desktop launchers (start/stop/status)
- Comprehensive documentation:
  - README with step-by-step setup
  - ARCHITECTURE with design decisions and trade-offs
  - TROUBLESHOOTING guide for common issues
- Battery optimization via manual lifecycle control
- GDPR-compliant local AI setup

### Design Decisions
- Chose bridge networking over host mode for better isolation
- User service instead of system service (no sudo required)
- Manual control (no restart policy) for battery savings
- Named Docker volume for data persistence

### Known Issues
- Only tested on Ubuntu 24.04 (should work on other distros)
- Port 3000 might conflict with other services
- Requires Docker group membership (security consideration)

## [1.0.1] - 2026-02-12

### Changed
- Updated documentation with personal context and origin story
- Added actual hardware specs and model usage patterns
- Documented debugging journey (bridge networking issues)
