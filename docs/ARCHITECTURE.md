# Architecture Documentation

**Open WebUI + Ollama systemd Stack**

> **Note:** This document grew as I figured things out. Some decisions were made after trial and error - I'll note those below.

## Learning Journey

**What worked immediately:**
- Docker Compose basics
- systemd service definition

**What took debugging:**
- Bridge networking (`172.17.0.1` gateway IP - spent 2 hours on this!)
- `OLLAMA_HOST=0.0.0.0` requirement (default `127.0.0.1` didn't work)
- `Type=oneshot` + `RemainAfterExit=yes` combo for docker compose

**What I'd do differently next time:**
- Start with host networking, then migrate to bridge (would've been faster to prototype)
- Test with smaller models first (gemma3:3b) before pulling qwen3:14b

---

This document explains the technical architecture, design decisions, and system integration patterns used in this project.


**Open WebUI + Ollama systemd Stack**

This document explains the technical architecture, design decisions, and system integration patterns used in this project.

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Component Architecture](#component-architecture)
3. [Network Architecture](#network-architecture)
4. [Service Management](#service-management)
5. [File System Organization](#file-system-organization)
6. [Security Model](#security-model)
7. [Design Decisions](#design-decisions)
8. [Trade-offs Analysis](#trade-offs-analysis)

---

## System Overview

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    User Space                           │
│                                                          │
│  ┌──────────────┐        ┌─────────────────────┐       │
│  │   Browser    │        │  Application Menu   │       │
│  │ (localhost:  │        │  (Desktop Launcher) │       │
│  │    3000)     │        │                     │       │
│  └──────┬───────┘        └──────────┬──────────┘       │
│         │                           │                   │
│         │ HTTP                      │ XDG Desktop       │
│         │                           │ Entry             │
│         ▼                           ▼                   │
│  ┌─────────────────────────────────────────────┐       │
│  │         systemd User Service                │       │
│  │      (openwebui.service)                    │       │
│  │                                              │       │
│  │  ExecStart: docker compose up -d            │       │
│  │  ExecStop:  docker compose down             │       │
│  └──────────────────┬──────────────────────────┘       │
│                     │                                   │
│                     │ Docker API                        │
│                     ▼                                   │
│  ┌─────────────────────────────────────────────┐       │
│  │        Docker Engine (dockerd)              │       │
│  │                                              │       │
│  │  ┌───────────────────────────────────────┐  │       │
│  │  │   Container: open-webui               │  │       │
│  │  │   Image: ghcr.io/open-webui/...      │  │       │
│  │  │   Network: bridge (172.17.0.0/16)    │  │       │
│  │  │   Port: 3000:8080                    │  │       │
│  │  │   Volume: open-webui:/app/...        │  │       │
│  │  └───────────────┬───────────────────────┘  │       │
│  └──────────────────┼──────────────────────────┘       │
│                     │                                   │
│                     │ HTTP to 172.17.0.1:11434          │
│                     │ (Docker bridge gateway)           │
│                     ▼                                   │
│  ┌─────────────────────────────────────────────┐       │
│  │        Ollama System Service                │       │
│  │     (ollama.service - systemd)              │       │
│  │                                              │       │
│  │  Listening: 0.0.0.0:11434                   │       │
│  │  Models: /usr/share/ollama/.ollama/models   │       │
│  └─────────────────────────────────────────────┘       │
│                                                          │
└─────────────────────────────────────────────────────────┘

                    Host System (Ubuntu)
```

### Data Flow

**User Interaction Flow:**
1. User clicks desktop launcher or types `systemctl --user start openwebui`
2. systemd executes `docker compose up -d`
3. Docker starts Open WebUI container
4. Container connects to Ollama via bridge network
5. Browser accesses UI at localhost:3000
6. User queries → Open WebUI → Ollama → Model inference → Response

---

## Component Architecture

### 1. Open WebUI Container

**Technology:** Docker container running Node.js application

**Responsibilities:**
- Web interface (frontend)
- Chat session management
- User authentication
- Model selection and routing
- Conversation history persistence

**Image:** `ghcr.io/open-webui/open-webui:main`

**Configuration:**
```yaml
services:
  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: open-webui
    ports:
      - "3000:8080"                          # Host:Container
    environment:
      - OLLAMA_BASE_URL=http://172.17.0.1:11434
    volumes:
      - open-webui:/app/backend/data        # Named volume for persistence
    restart: "no"                            # Manual lifecycle control
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
```

**Key Characteristics:**
- **Stateful:** Chat history persists in Docker volume
- **No restart policy:** Manual control for battery optimization
- **Health checks:** Ensures readiness before routing traffic
- **Single container:** No orchestration complexity

---

### 2. Ollama Service

**Technology:** Go binary running as system service

**Responsibilities:**
- LLM model management (pull, list, remove)
- Model inference (generation)
- API endpoint for model interactions
- GPU acceleration (if available)

**Service Configuration:**
```ini
[Unit]
Description=Ollama Service
After=network-online.target

[Service]
ExecStart=/usr/local/bin/ollama serve
User=ollama
Group=ollama
Restart=always
RestartSec=3
Environment="OLLAMA_HOST=0.0.0.0:11434"  # Override for Docker access

[Install]
WantedBy=default.target
```

**Network Override:** `/etc/systemd/system/ollama.service.d/override.conf`
```ini
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
```

**Why override needed:** Default `OLLAMA_HOST=127.0.0.1:11434` only accepts localhost connections. Docker bridge network requires `0.0.0.0` to accept connections from gateway IP.

---

### 3. systemd User Service

**Technology:** systemd service running in user context

**Responsibilities:**
- Lifecycle management (start/stop/restart)
- Dependency ordering
- Automatic recovery (optional via enable)
- Log aggregation (journalctl)

**Service Definition:** `~/.config/systemd/user/openwebui.service`
```ini
[Unit]
Description=Open WebUI for Ollama
Documentation=https://docs.openwebui.com
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=%h/openwebui-stack
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
```

**Type Explanation:**
- `Type=oneshot` — Command runs to completion, then exits
- `RemainAfterExit=yes` — Service considered "active" after ExecStart completes
- Perfect for `docker compose` which starts containers in background and exits

**Why User Service (not System):**
- No root privileges required for daily use
- Per-user isolation
- Follows XDG Base Directory spec
- User can manage without sudo

---

### 4. Desktop Integration

**Technology:** XDG Desktop Entry files

**Responsibilities:**
- GUI launcher integration
- Application menu visibility
- Icon/name display
- Script execution on click

**Launcher Example:** `~/.local/share/applications/openwebui-start.desktop`
```ini
[Desktop Entry]
Version=1.0
Type=Application
Name=Open WebUI (Start)
Comment=Start Open WebUI with browser
Exec=/home/USER/openwebui-stack/scripts/start-with-browser.sh
Icon=applications-internet
Terminal=false
Categories=Network;WebBrowser;
```

**XDG Standard Locations:**
- User applications: `~/.local/share/applications/`
- System applications: `/usr/share/applications/`
- Desktop files: `~/.local/share/applications/`

---

## Network Architecture

### Bridge Network Mode (Chosen Approach)

**Network Topology:**
```
┌──────────────────────────────────────────────┐
│              Host System                     │
│                                               │
│  Interface: lo (127.0.0.1)                   │
│  Interface: eth0 (192.168.x.x)               │
│                                               │
│  ┌────────────────────────────────────────┐  │
│  │     Docker Bridge Network              │  │
│  │     Subnet: 172.17.0.0/16              │  │
│  │                                         │  │
│  │  Gateway: 172.17.0.1 (docker0)         │  │
│  │           ▲                             │  │
│  │           │                             │  │
│  │  Container IP: 172.17.0.2              │  │
│  │  ┌─────────────────────────────────┐   │  │
│  │  │  open-webui container           │   │  │
│  │  │  Port 8080 → Host 3000          │   │  │
│  │  │                                  │   │  │
│  │  │  OLLAMA_BASE_URL=               │   │  │
│  │  │    http://172.17.0.1:11434      │   │  │
│  │  └─────────────────────────────────┘   │  │
│  └────────────────────────────────────────┘  │
│                                               │
│  Host Service: Ollama                        │
│  Listening: 0.0.0.0:11434                    │
│  Accessible at:                              │
│    - 127.0.0.1:11434 (localhost)             │
│    - 172.17.0.1:11434 (Docker bridge)        │
│                                               │
└──────────────────────────────────────────────┘
```

**How Bridge Networking Works:**
1. Docker creates virtual bridge `docker0` on host
2. Assigns gateway IP `172.17.0.1` to bridge
3. Container gets IP from `172.17.0.0/16` subnet (e.g., 172.17.0.2)
4. Container routes to host via gateway `172.17.0.1`
5. Port mapping: Host `3000` → Container `8080`

**Critical Configuration:**
- Ollama must listen on `0.0.0.0:11434` (not `127.0.0.1`)
- Container uses `http://172.17.0.1:11434` (gateway IP)
- Port 3000 avoids conflicts with default 8080

---

### Alternative: Host Network Mode (Not Used)

**How it would work:**
```yaml
services:
  open-webui:
    network_mode: "host"
    environment:
      - OLLAMA_BASE_URL=http://localhost:11434
```

**Pros:**
- Simpler configuration
- No need to configure Ollama for 0.0.0.0
- Direct localhost access

**Cons:**
- Uses port 8080 directly (conflict risk)
- Less portable (no explicit port mapping)
- Breaks Docker network isolation
- Not suitable for multi-container setups

**Why Bridge Chosen:**
- Standard Docker pattern
- Explicit configuration (better for portfolios)
- Portable across environments
- Clear separation of concerns
- Demonstrates networking knowledge

---

## Service Management

### systemd Integration

**Service Hierarchy:**
```
default.target
  └── openwebui.service (user)
        ├── After: docker.service
        └── ExecStart: docker compose up -d
              └── Starts: open-webui container
                    └── Connects to: ollama.service (system)
```

**Dependency Chain:**
1. `docker.service` (system) must be running
2. `ollama.service` (system) must be running
3. User starts `openwebui.service` (user)
4. Service runs `docker compose up -d`
5. Container starts and connects to Ollama

**Logging Integration:**
```bash
# Service logs
journalctl --user -u openwebui -f

# Docker container logs
docker logs open-webui -f

# Ollama service logs
journalctl -u ollama -f
```

**State Management:**
```
systemctl --user start openwebui
  → Type=oneshot runs ExecStart
  → docker compose up -d executes
  → Container starts in background
  → ExecStart exits (code 0)
  → RemainAfterExit=yes → Service state: active

systemctl --user stop openwebui
  → ExecStop runs
  → docker compose down executes
  → Container stops
  → Service state: inactive
```

---

## File System Organization

### Directory Structure

```
~/openwebui-stack/                    # Project root (Git repository)
├── docker-compose.yml                # Container orchestration
├── README.md                         # User documentation
├── LICENSE                           # MIT License
├── .gitignore                        # Git exclusions
│
├── systemd/                          # Reference systemd files
│   └── openwebui.service            # Service definition template
│
├── desktop/                          # Reference desktop entries
│   ├── openwebui-start.desktop      # Start launcher
│   ├── openwebui-stop.desktop       # Stop launcher
│   └── openwebui-status.desktop     # Status launcher
│
├── scripts/                          # Helper scripts
│   ├── start-with-browser.sh        # Launch + open browser
│   ├── stop.sh                      # Graceful shutdown
│   └── status.sh                    # Status check
│
└── docs/                             # Documentation
    ├── TROUBLESHOOTING.md           # Issue resolution
    ├── ARCHITECTURE.md              # This file
    └── screenshot.png               # UI preview
```

**System Integration Locations:**
```
~/.config/systemd/user/
└── openwebui.service                # Active service file (working copy)

~/.local/share/applications/
├── openwebui-start.desktop          # Active launcher (working copy)
├── openwebui-stop.desktop           # Active launcher (working copy)
└── openwebui-status.desktop         # Active launcher (working copy)
```

**Docker Persistent Data:**
```
/var/lib/docker/volumes/
└── openwebui-stack_open-webui/      # Named volume
    └── _data/                       # Chat history, settings, uploads
```

**Ollama Data:**
```
/usr/share/ollama/.ollama/
└── models/                          # Downloaded LLM models
    ├── blobs/                       # Model weights
    └── manifests/                   # Model metadata
```

---

### Reference vs Working Copies Pattern

**Concept:** Separate version-controlled configuration from active system files.

**Reference Copies (in Git):**
- Location: `~/openwebui-stack/systemd/`, `~/openwebui-stack/desktop/`
- Purpose: Version control, documentation, portability
- Management: `git add`, `git commit`

**Working Copies (system locations):**
- Location: `~/.config/systemd/user/`, `~/.local/share/applications/`
- Purpose: Active configuration used by OS
- Management: `cp` from reference, `systemctl daemon-reload`

**Workflow:**
1. Edit reference copy: `vim ~/openwebui-stack/systemd/openwebui.service`
2. Test locally: `cp systemd/openwebui.service ~/.config/systemd/user/`
3. Reload systemd: `systemctl --user daemon-reload`
4. Verify: `systemctl --user status openwebui`
5. Commit: `git add systemd/openwebui.service && git commit`

**Why Not Symlinks:**
- systemd may not follow symlinks reliably
- Desktop environments may not resolve symlinks
- Explicit copies ensure compatibility
- Clear separation of concerns

---

## Security Model

### Privilege Separation

**Component Privilege Levels:**

| Component | User | Privileges | Why |
|-----------|------|------------|-----|
| **Ollama** | `ollama` | System service | Requires GPU access, model management |
| **Docker Engine** | `root` | System daemon | Container isolation, networking |
| **Docker Group** | User (e.g., `yourname`) | Group membership | Docker socket access |
| **openwebui service** | User | User service | No root needed for daily use |
| **Container** | `www-data` | Restricted | Application-level isolation |

**Why User Service:**
- No root privileges for start/stop
- Per-user isolation (multiple users can run separate instances)
- Follows principle of least privilege
- Audit trail (user-specific logs)

---

### Network Isolation

**Attack Surface:**

| Port | Service | Exposure | Risk |
|------|---------|----------|------|
| **3000** | Open WebUI | `127.0.0.1` only | Low (localhost) |
| **11434** | Ollama API | `0.0.0.0` but firewalled | Medium (needs firewall) |
| **8080** | Container internal | Not exposed | None (bridge network only) |

**Firewall Configuration (Recommended):**
```bash
# Allow Ollama only from Docker bridge
sudo ufw deny 11434
sudo ufw allow from 172.17.0.0/16 to any port 11434

# Allow Open WebUI only from localhost
sudo ufw deny 3000
sudo ufw allow from 127.0.0.1 to any port 3000
```

**Why This Matters:**
- Prevents external access to Ollama API
- Prevents external access to Open WebUI
- Allows Docker bridge access
- Defense in depth

---

### Data Privacy (GDPR Compliance)

**Data Processing:**
- ✅ All data processed locally (no external API calls)
- ✅ No telemetry or tracking
- ✅ No third-party services
- ✅ Full user control over data

**Data Storage:**
| Data Type | Location | Encryption | Backup |
|-----------|----------|------------|--------|
| Chat history | Docker volume | At-rest (filesystem) | User-managed |
| Models | `/usr/share/ollama/` | At-rest | Reproducible (pull) |
| Configuration | `~/.config/` | At-rest | Git-managed |

**Data Deletion (Right to Erasure):**
```bash
# Remove all chat history
docker volume rm openwebui-stack_open-webui

# Remove models
ollama rm modelname

# Remove configuration
rm -rf ~/.config/systemd/user/openwebui.service
rm -rf ~/.local/share/applications/openwebui*.desktop
```

---

## Design Decisions

### 1. Bridge Network vs Host Network

**Decision:** Use bridge network mode

**Rationale:**
- Standard Docker pattern (better for portfolios)
- Explicit port mapping (clearer configuration)
- Network isolation (security best practice)
- Portable across environments
- Demonstrates networking knowledge

**Trade-off:** Requires Ollama configuration (`OLLAMA_HOST=0.0.0.0`)

---

### 2. Manual Service Control vs Auto-Start

**Decision:** Manual lifecycle control (`restart: "no"`)

**Rationale:**
- Battery optimization (20-30% daily saving on laptops)
- Intentional resource usage (start when needed)
- Reduces idle overhead
- Aligns with "infrastructure as code" mindset

**Trade-off:** User must start service manually

**Alternative Available:** `systemctl --user enable openwebui` for auto-start

---

### 3. User Service vs System Service

**Decision:** User-level systemd service

**Rationale:**
- No root privileges for daily operations
- Per-user isolation (multi-user support)
- Follows XDG standards
- Easier troubleshooting (user logs)

**Trade-off:** Requires Docker group membership

---

### 4. Named Volume vs Bind Mount

**Decision:** Named Docker volume

**Rationale:**
- Docker-managed lifecycle
- Better performance (especially on macOS/Windows)
- Clearer intent (ephemeral vs persistent)
- Easier backup/restore with Docker tools

**Trade-off:** Data location not immediately obvious (`docker volume inspect`)

**Alternative:**
```yaml
volumes:
  - ./data:/app/backend/data  # Bind mount (not used)
```

---

### 5. Single Container vs Multi-Container

**Decision:** Single container (Open WebUI only)

**Rationale:**
- Ollama already runs as system service
- No need for Docker Compose orchestration complexity
- Simpler troubleshooting
- Reduces resource overhead

**Trade-off:** Mixed deployment models (container + system service)

**Alternative:** Could containerize Ollama too, but adds complexity without benefits.

---

## Trade-offs Analysis

### Performance vs Battery

**Choice:** Battery optimization (manual control)

**Performance Impact:**
- Start time: +10-15 seconds (container initialization)
- No impact during active use

**Battery Benefit:**
- Idle: 20-30% daily savings (no background container)
- Active: Same consumption (inference-bound, not container overhead)

**Conclusion:** Battery optimization worth the startup delay for laptop users.

---

### Simplicity vs Flexibility

**Choice:** Flexible configuration (docker-compose.yml)

**Complexity Added:**
- Requires docker-compose-v2
- YAML configuration file
- systemd service definition

**Flexibility Gained:**
- Easy port changes
- Environment variable management
- Volume configuration
- Health checks
- Future scaling options (add sidecars if needed)

**Conclusion:** Infrastructure as Code principles justify added complexity.

---

### Security vs Convenience

**Choice:** Balance (user service + group membership)

**Security Trade-offs:**
- Docker group = near-root privileges (container escape risk)
- User service = no isolation from user processes

**Convenience Gained:**
- No sudo for daily operations
- Desktop integration
- Easy troubleshooting

**Mitigations:**
- Firewall rules
- Network isolation
- No external exposure
- Regular updates

**Conclusion:** Acceptable for local development/personal use. Production would use stricter isolation.

---

## Technology Stack Summary

| Layer | Technology | Version | Purpose |
|-------|------------|---------|---------|
| **OS** | Ubuntu | 22.04+ | Base system |
| **Init** | systemd | 249+ | Service management |
| **Container Runtime** | Docker | 24.0+ | Isolation, deployment |
| **Orchestration** | docker-compose | v2.x | Multi-service definition |
| **Web App** | Open WebUI | latest | Chat interface |
| **LLM Runtime** | Ollama | latest | Model serving |
| **Desktop** | XDG | 1.0 | GUI integration |
| **Shell** | Bash | 5.x | Scripting |

---

## Future Considerations

### Potential Enhancements

1. **Multi-user support** — Separate user services with isolated volumes
2. **Reverse proxy** — nginx for TLS, authentication
3. **Monitoring** — Prometheus metrics, Grafana dashboards
4. **Auto-updates** — systemd timer for `docker compose pull`
5. **Resource limits** — Docker memory/CPU constraints
6. **Model caching** — Persistent model loading for faster inference

### Scalability Paths

**Current:** Single-user, single-model, manual control

**Future Options:**
- **Horizontal:** Multiple Open WebUI instances for load balancing
- **Vertical:** GPU passthrough for faster inference
- **Federation:** Shared Ollama backend for multiple users

---

## Lessons Learned

### Debugging Bridge Networking
Initially tried `OLLAMA_BASE_URL=http://localhost:11434` in container - didn't work.  
Learned that containers can't access host's `localhost` directly.  
**Solution:** Use Docker bridge gateway IP `172.17.0.1`.

Spent 2 hours checking:
- Firewall rules (wasn't the issue)
- Ollama service status (was running fine)
- Container logs (showed connection refused)

Finally found the answer in Docker networking docs - gateway IP is the key.

### systemd Service Type
First tried `Type=simple` - service stayed in "activating" state forever.  
Realized docker compose exits after starting containers (doesn't stay running).  
**Solution:** `Type=oneshot` with `RemainAfterExit=yes`.

### Battery Optimization Discovery
Initially had `restart: unless-stopped` in docker-compose.yml.  
Noticed laptop battery drained 30% overnight even when not using AI.  
**Investigation:** Container was idle but consuming ~200MB RAM constantly.  
**Solution:** Changed to `restart: "no"` and manual control.  
**Result:** 20-30% daily battery savings. Worth the manual startup!

### Port Selection
Chose port 3000 after port 8080 conflicted with my local dev server.  
Considered 8000, but that's often used for Python apps.  
3000 is commonly used for Node.js dev servers, feels natural.

---

## References

- **systemd:** https://systemd.io/
- **Docker Networking:** https://docs.docker.com/network/
- **XDG Base Directory:** https://specifications.freedesktop.org/basedir-spec/
- **Open WebUI Docs:** https://docs.openwebui.com
- **Ollama Architecture:** https://github.com/ollama/ollama/blob/main/docs/api.md

---

**Document Version:** 1.0  
**Last Updated:** 2026-02-09  
**Author:** DevOps Portfolio Project
