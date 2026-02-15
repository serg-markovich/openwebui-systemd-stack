# Updating Open WebUI

This project uses a hybrid approach for updates to balance stability with ease of maintenance.

## Update Strategy

1.  **Automated Checks:** A GitHub Action runs weekly to check for new releases of Open WebUI.
2.  **Notification:** If a new version is found, an Issue is automatically created in this repository.
3.  **Manual Trigger:** The update is applied manually to ensure stability before committing.

## How to Update

When a new version is released (or an Issue is created):

1.  **Check the Changelog:**
    Review changes at [Open WebUI Releases](https://github.com/open-webui/open-webui/releases).
    *Look for breaking changes or required database migrations.*

2.  **Edit Configuration:**
    Open `docker-compose.yml` and update the image tag:
    ```yaml
    services:
      open-webui:
        image: ghcr.io/open-webui/open-webui:v0.5.x  # Change to new version
    ```

3.  **Test Locally (Optional but recommended):**
    ```bash
    docker compose pull
    docker compose up -d
    # Check logs and functionality
    ```

4.  **Commit:**
    ```bash
    git add docker-compose.yml
    git commit -m "chore(deps): update open-webui to v0.5.x"
    git push
    ```

5.  **Cleanup:**
    Close the automated Issue regarding the update.
## 🔧 Troubleshooting

### Network Issues (Connection Reset / Timeout)
If you encounter `read: connection reset by peer` or timeouts during `docker compose pull`, especially with large images (>1GB):

1.  **Use the update script:** The `./update.sh` script includes a retry loop and increased timeouts automatically.
2.  **Force IPv4 (Temporary):**
    If IPv6 routing is unstable, disable it temporarily:
    ```bash
    sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
    # run update
    sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0
    ```
3.  **Docker Daemon Config:**
    Limit concurrent downloads to prevent bandwidth saturation. Add to `/etc/docker/daemon.json`:
    ```json
    {
      "max-concurrent-downloads": 1
    }
    ```
