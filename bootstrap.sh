#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

random_secret() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 16
  else
    tr -dc 'a-f0-9' </dev/urandom | head -c 32
  fi
}

escape_sed_replacement() {
  printf '%s' "$1" | sed -e 's/[&|]/\\&/g'
}

write_env_file() {
  local output_file="$1"
  local transmission_user="$2"
  local transmission_pass="$3"

  cat > "$output_file" <<EOF
PUID=$(id -u)
PGID=$(id -g)
TZ=Etc/UTC
QBITTORRENT_WEBUI_PORT=8080
TRANSMISSION_WEBUI_PORT=9091
TRANSMISSION_USER=${transmission_user}
TRANSMISSION_PASS=${transmission_pass}
EOF
}

write_arr_config() {
  local config_dir="$1"
  local port="$2"
  local username="$3"
  local password="$4"
  local api_key="$5"

  mkdir -p "$config_dir"

  cat > "${config_dir}/config.xml" <<EOF
<Config>
  <ApiKey>${api_key}</ApiKey>
  <AuthenticationMethod>Forms</AuthenticationMethod>
  <AuthenticationRequired>DisabledForLocalAddresses</AuthenticationRequired>
  <AuthenticationEnabled>true</AuthenticationEnabled>
  <Username>${username}</Username>
  <Password>${password}</Password>
  <LogLevel>info</LogLevel>
  <AnalyticsEnabled>false</AnalyticsEnabled>
  <Port>${port}</Port>
</Config>
EOF
}

wait_for_url() {
  local name="$1"
  local url="$2"
  local api_key="$3"
  local header_name="$4"

  echo -n "Waiting for ${name}... "
  for _ in {1..60}; do
    if curl -fsS -H "${header_name}: ${api_key}" "$url" >/dev/null 2>&1; then
      echo "up"
      return 0
    fi
    sleep 2
  done
  echo "timeout"
  return 1
}

prompt_or_default() {
  local prompt="$1"
  local default_value="$2"
  local input_value

  if [[ "${NONINTERACTIVE:-0}" == "1" ]]; then
    printf '%s\n' "$default_value"
    return 0
  fi

  read -r -p "$prompt" input_value
  printf '%s\n' "${input_value:-$default_value}"
}

extract_qbittorrent_password() {
  docker compose --env-file "${WORK_DIR}/.env" -f "${WORK_DIR}/all/docker-compose.all.yml" logs qbittorrent 2>&1 |
    python3 -c 'import re, sys
for line in reversed(sys.stdin.read().splitlines()):
    if "password" not in line.lower():
        continue
    match = re.search(r"password[^A-Za-z0-9]*([A-Za-z0-9@._-]{6,})", line, re.I)
    if match:
        print(match.group(1))
        raise SystemExit(0)
    tokens = re.findall(r"[A-Za-z0-9@._-]{6,}", line)
    if tokens:
        print(tokens[-1])
        raise SystemExit(0)
raise SystemExit(1)'
}

fetch_json() {
  local url="$1"
  local api_key="$2"

  curl -fsS -H "X-Api-Key: ${api_key}" "$url"
}

build_provider_payload() {
  local schema_file="$1"
  local implementation="$2"
  local provider_name="$3"
  local fields_json="$4"
  local extra_json="$5"

  PROVIDER_SCHEMA_FILE="$schema_file" \
  PROVIDER_IMPLEMENTATION="$implementation" \
  PROVIDER_NAME="$provider_name" \
  PROVIDER_FIELDS_JSON="$fields_json" \
  PROVIDER_EXTRA_JSON="$extra_json" \
  python3 - <<'PY'
import json
import os
import sys

with open(os.environ["PROVIDER_SCHEMA_FILE"], "r", encoding="utf-8") as handle:
    providers = json.load(handle)

implementation = os.environ["PROVIDER_IMPLEMENTATION"]
provider_name = os.environ["PROVIDER_NAME"]
field_values = json.loads(os.environ["PROVIDER_FIELDS_JSON"])
extra_values = json.loads(os.environ["PROVIDER_EXTRA_JSON"])

provider = next((item for item in providers if item.get("implementation") == implementation), None)
if provider is None:
    raise SystemExit(f"Provider implementation {implementation!r} not found in schema")

provider["name"] = provider_name
if "enable" in provider:
    provider["enable"] = True
if "syncLevel" in provider:
    provider["syncLevel"] = "fullSync"

for key, value in extra_values.items():
    provider[key] = value

for field in provider.get("fields", []):
    field_name = field.get("name")
    if field_name in field_values:
        field["value"] = field_values[field_name]

json.dump(provider, sys.stdout)
PY
}

post_provider() {
  local api_url="$1"
  local api_key="$2"
  local body_json="$3"

  curl -fsS -X POST \
    -H "X-Api-Key: ${api_key}" \
    -H 'Content-Type: application/json' \
    --data "$body_json" \
    "$api_url" >/dev/null
}

wire_prowlarr() {
  local work_dir="$1"
  local prowlarr_api_key="$2"
  local radarr_api_key="$3"
  local lidarr_api_key="$4"
  local sonarr_api_key="$5"
  local qbit_password="$6"
  local transmission_password="$7"

  local applications_schema_file
  local download_clients_schema_file
  applications_schema_file="$(mktemp)"
  download_clients_schema_file="$(mktemp)"

  fetch_json "http://localhost:9696/api/v1/applications/schema" "$prowlarr_api_key" > "$applications_schema_file"
  fetch_json "http://localhost:9696/api/v1/downloadclient/schema" "$prowlarr_api_key" > "$download_clients_schema_file"

  local radarr_body lidarr_body sonarr_body qbit_body transmission_body

  radarr_body="$(PROVIDER_SCHEMA_FILE="$applications_schema_file" \
    PROVIDER_IMPLEMENTATION="Radarr" \
    PROVIDER_NAME="Radarr" \
    PROVIDER_FIELDS_JSON="{\"prowlarrUrl\":\"http://prowlarr:9696\",\"baseUrl\":\"http://radarr:7878\",\"apiKey\":\"${radarr_api_key}\"}" \
    PROVIDER_EXTRA_JSON="{}" \
    build_provider_payload "$applications_schema_file" "Radarr" "Radarr" \
    '{"prowlarrUrl":"http://prowlarr:9696","baseUrl":"http://radarr:7878","apiKey":"'"${radarr_api_key}"'"}' '{}')"

  lidarr_body="$(build_provider_payload "$applications_schema_file" "Lidarr" "Lidarr" \
    '{"prowlarrUrl":"http://prowlarr:9696","baseUrl":"http://lidarr:8686","apiKey":"'"${lidarr_api_key}"'"}' '{}')"

  sonarr_body="$(build_provider_payload "$applications_schema_file" "Sonarr" "Sonarr" \
    '{"prowlarrUrl":"http://prowlarr:9696","baseUrl":"http://sonarr:8989","apiKey":"'"${sonarr_api_key}"'"}' '{}')"

  qbit_body="$(build_provider_payload "$download_clients_schema_file" "qBittorrent" "qBittorrent" \
    '{"host":"qbittorrent","port":8080,"useSsl":false,"urlBase":"","username":"admin","password":"'"${qbit_password}"'","category":"prowlarr"}' '{}')"

  transmission_body="$(build_provider_payload "$download_clients_schema_file" "Transmission" "Transmission" \
    '{"host":"transmission","port":9091,"useSsl":false,"urlBase":"","username":"arr","password":"'"${transmission_password}"'","category":"prowlarr"}' '{}')"

  post_provider "http://localhost:9696/api/v1/applications" "$prowlarr_api_key" "$radarr_body"
  post_provider "http://localhost:9696/api/v1/applications" "$prowlarr_api_key" "$lidarr_body"
  post_provider "http://localhost:9696/api/v1/applications" "$prowlarr_api_key" "$sonarr_body"
  post_provider "http://localhost:9696/api/v1/downloadclient" "$prowlarr_api_key" "$qbit_body"
  post_provider "http://localhost:9696/api/v1/downloadclient" "$prowlarr_api_key" "$transmission_body"

  rm -f "$applications_schema_file" "$download_clients_schema_file"
}

clone_or_update_repo() {
  local repo_url="$1"
  local target_dir="$2"

  if [ -d "${target_dir}/.git" ]; then
    git -C "$target_dir" pull --ff-only
  else
    git clone "$repo_url" "$target_dir"
  fi
}

GIT_REPO="$(prompt_or_default 'Git repository URL [https://github.com/duckeydev/IAMARR]: ' 'https://github.com/duckeydev/IAMARR')"

TARGET_DIR="$(prompt_or_default 'Target directory to clone into [./arr-deploy]: ' './arr-deploy')"

clone_or_update_repo "$GIT_REPO" "$TARGET_DIR"

WORK_DIR="$TARGET_DIR"

MEDIA_ROOT="$(prompt_or_default 'Absolute media root path [/mnt/media]: ' '/mnt/media')"

TORRENTS_ROOT="$(prompt_or_default 'Absolute torrents root path [/mnt/torrents]: ' '/mnt/torrents')"

CONFIG_ROOT="$(prompt_or_default 'Absolute config root path [/var/lib/arr-config]: ' '/var/lib/arr-config')"

mkdir -p "$MEDIA_ROOT/music" "$MEDIA_ROOT/movies" "$MEDIA_ROOT/tv"
mkdir -p "$TORRENTS_ROOT/music" "$TORRENTS_ROOT/movies" "$TORRENTS_ROOT/tv"
mkdir -p "$CONFIG_ROOT"

PROWLARR_USERNAME="admin"
LIDARR_USERNAME="admin"
RADARR_USERNAME="admin"
SONARR_USERNAME="admin"

PROWLARR_PASSWORD="$(random_secret)"
LIDARR_PASSWORD="$(random_secret)"
RADARR_PASSWORD="$(random_secret)"
SONARR_PASSWORD="$(random_secret)"

PROWLARR_API_KEY="$(random_secret)"
LIDARR_API_KEY="$(random_secret)"
RADARR_API_KEY="$(random_secret)"
SONARR_API_KEY="$(random_secret)"

TRANSMISSION_USER="arr"
TRANSMISSION_PASS="$(random_secret)"

write_env_file "${WORK_DIR}/.env" "$TRANSMISSION_USER" "$TRANSMISSION_PASS"

cat >> "${WORK_DIR}/.env" <<EOF
PROWLARR_USERNAME=${PROWLARR_USERNAME}
PROWLARR_PASSWORD=${PROWLARR_PASSWORD}
PROWLARR_API_KEY=${PROWLARR_API_KEY}
LIDARR_USERNAME=${LIDARR_USERNAME}
LIDARR_PASSWORD=${LIDARR_PASSWORD}
LIDARR_API_KEY=${LIDARR_API_KEY}
RADARR_USERNAME=${RADARR_USERNAME}
RADARR_PASSWORD=${RADARR_PASSWORD}
RADARR_API_KEY=${RADARR_API_KEY}
SONARR_USERNAME=${SONARR_USERNAME}
SONARR_PASSWORD=${SONARR_PASSWORD}
SONARR_API_KEY=${SONARR_API_KEY}
EOF

write_arr_config "${CONFIG_ROOT}/prowlarr" 9696 "$PROWLARR_USERNAME" "$PROWLARR_PASSWORD" "$PROWLARR_API_KEY"
write_arr_config "${CONFIG_ROOT}/lidarr" 8686 "$LIDARR_USERNAME" "$LIDARR_PASSWORD" "$LIDARR_API_KEY"
write_arr_config "${CONFIG_ROOT}/radarr" 7878 "$RADARR_USERNAME" "$RADARR_PASSWORD" "$RADARR_API_KEY"
write_arr_config "${CONFIG_ROOT}/sonarr" 8989 "$SONARR_USERNAME" "$SONARR_PASSWORD" "$SONARR_API_KEY"

CONFIG_ROOT_ESCAPED="$(escape_sed_replacement "$CONFIG_ROOT")"
MEDIA_ROOT_ESCAPED="$(escape_sed_replacement "$MEDIA_ROOT")"
TORRENTS_ROOT_ESCAPED="$(escape_sed_replacement "$TORRENTS_ROOT")"

while IFS= read -r -d '' compose_file; do
  sed -i "s|./config/|${CONFIG_ROOT_ESCAPED}/|g" "$compose_file"
  sed -i "s|./data/media|${MEDIA_ROOT_ESCAPED}|g" "$compose_file"
  sed -i "s|./data/torrents|${TORRENTS_ROOT_ESCAPED}|g" "$compose_file"
done < <(find "$WORK_DIR" -type f \( -name 'docker-compose*.yml' -o -name '*.yml' \) -print0)

echo "Starting the full stack..."
docker compose --env-file "${WORK_DIR}/.env" -f "${WORK_DIR}/all/docker-compose.all.yml" up -d

wait_for_url "Prowlarr" "http://localhost:9696/api/v1/system/status" "$PROWLARR_API_KEY" "X-Api-Key" || true
wait_for_url "Radarr" "http://localhost:7878/api/v3/system/status" "$RADARR_API_KEY" "X-Api-Key" || true
wait_for_url "Lidarr" "http://localhost:8686/api/v1/system/status" "$LIDARR_API_KEY" "X-Api-Key" || true
wait_for_url "Sonarr" "http://localhost:8989/api/v3/system/status" "$SONARR_API_KEY" "X-Api-Key" || true

QBITTORRENT_PASSWORD="$(extract_qbittorrent_password || true)"
if [[ -n "$QBITTORRENT_PASSWORD" ]]; then
  wire_prowlarr "$WORK_DIR" "$PROWLARR_API_KEY" "$RADARR_API_KEY" "$LIDARR_API_KEY" "$SONARR_API_KEY" "$QBITTORRENT_PASSWORD" "$TRANSMISSION_PASS" || true
else
  echo "Warning: could not extract qBittorrent password from logs; skipping qBittorrent client seeding."
fi

echo
echo "Bootstrap complete."
echo "API keys and login credentials were written to ${WORK_DIR}/.env and seeded into ${CONFIG_ROOT}."
echo "qBittorrent still prints its temporary Web UI password to container logs on first start."
echo
echo "URLs:"
echo "- Prowlarr: http://localhost:9696"
echo "- qBittorrent: http://localhost:8080"
echo "- Transmission: http://localhost:9091"
echo "- Lidarr: http://localhost:8686"
echo "- Radarr: http://localhost:7878"
echo "- Sonarr: http://localhost:8989"
echo "- Bazarr: http://localhost:6767"
echo "- Navidrome: http://localhost:4533"
echo "- Jellyfin: http://localhost:8096"
echo "- Overseerr: http://localhost:5055"
echo
echo "Credentials:"
echo "- Prowlarr admin / ${PROWLARR_PASSWORD}"
echo "- Radarr admin / ${RADARR_PASSWORD}"
echo "- Lidarr admin / ${LIDARR_PASSWORD}"
echo "- Sonarr admin / ${SONARR_PASSWORD}"
echo "- Transmission ${TRANSMISSION_USER} / ${TRANSMISSION_PASS}"
