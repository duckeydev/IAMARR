#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

if [ ! -f .env ]; then
  echo "Creating .env with current user IDs"
  cat > .env <<EOF
PUID=$(id -u)
PGID=$(id -g)
TZ=Etc/UTC
QBITTORRENT_WEBUI_PORT=8080
TRANSMISSION_WEBUI_PORT=9091
EOF
fi

echo "Bringing up all services (this may take a few minutes)"
docker compose -f all/docker-compose.all.yml up -d

# Wait helpers
wait_for() {
  local name="$1"; shift
  local url="$1"; shift
  echo -n "Waiting for $name... "
  for i in {1..60}; do
    if curl -sSf "$url" > /dev/null 2>&1; then
      echo "up"
      return 0
    fi
    sleep 2
  done
  echo "timeout"
  return 1
}

# Check some web UIs
wait_for "Prowlarr" "http://localhost:9696" || true
wait_for "qBittorrent" "http://localhost:${QBITTORRENT_WEBUI_PORT}" || true
wait_for "Radarr" "http://localhost:7878" || true
wait_for "Lidarr" "http://localhost:8686" || true
wait_for "Jellyfin" "http://localhost:8096" || true

cat <<EOF
Setup complete (containers started).
Visit the web UIs to finish app-specific setup:
- Prowlarr: http://localhost:9696
- qBittorrent: http://localhost:${QBITTORRENT_WEBUI_PORT}
- Transmission: http://localhost:${TRANSMISSION_WEBUI_PORT}
- Lidarr: http://localhost:8686
- Radarr: http://localhost:7878
- Sonarr: http://localhost:8989
- Navidrome: http://localhost:4533
- Jellyfin: http://localhost:8096
- Overseerr: http://localhost:5055

Notes:
- Some apps require API keys (Prowlarr/Overseerr) or passwords. Open each UI and follow the first-run prompts.
- If you want, I can automate app API wiring (connect Radarr/Lidarr/Sonarr to Prowlarr and qBittorrent/Transmission) but I'll need the initial API keys and passwords created by the services.
EOF
