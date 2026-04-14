#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib.sh"

SERVER="${1:-}"
[[ -n "${SERVER}" ]] || die "usage: sync-server-properties.sh <server>"

load_server "${SERVER}"
ensure_server_dirs

PROPS_FILE="${SERVER_DIR}/server.properties"
[[ -f "${PROPS_FILE}" ]] || die "server.properties not found: ${PROPS_FILE}"

set_prop() {
  local key="$1"
  local value="$2"

  if grep -qE "^${key}=" "${PROPS_FILE}"; then
    python3 - "${PROPS_FILE}" "${key}" "${value}" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
key = sys.argv[2]
value = sys.argv[3]

lines = path.read_text(encoding="utf-8").splitlines()
out = []
replaced = False

for line in lines:
    if line.startswith(key + "="):
        out.append(f"{key}={value}")
        replaced = True
    else:
        out.append(line)

if not replaced:
    out.append(f"{key}={value}")

path.write_text("\n".join(out) + "\n", encoding="utf-8")
PY
  else
    printf '%s=%s\n' "${key}" "${value}" >> "${PROPS_FILE}"
  fi
}

set_prop "server-port" "${GAME_PORT}"
set_prop "enable-rcon" "true"
set_prop "rcon.port" "${RCON_PORT}"
set_prop "rcon.password" "${RCON_PASSWORD}"

event_emit "server_properties_synced" \
  "server_port=${GAME_PORT}" \
  "rcon_port=${RCON_PORT}"

echo "Synced server.properties for ${SERVER_NAME}"
echo "  server-port=${GAME_PORT}"
echo "  enable-rcon=true"
echo "  rcon.port=${RCON_PORT}"
echo "  rcon.password=${RCON_PASSWORD}"
