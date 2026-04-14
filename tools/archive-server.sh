\
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib.sh"

SERVER="${1:-}"
[[ -n "${SERVER}" ]] || die "usage: archive-server.sh <server>"
load_server "${SERVER}"

if [[ "$(active_server || true)" == "${SERVER_NAME}" ]]; then
  "${SCRIPTS_DIR}/stop-server.sh" "${SERVER_NAME}" >/dev/null 2>&1 || true
fi

ts="$(date +%Y-%m-%d_%H%M%S)"
dst="${ARCHIVE_SERVERS_DIR}/${SERVER_NAME}-${ts}.tar.gz"
tar -C "${SERVER_DIR}" -czf "${dst}" .

conf="$(server_conf_path "${SERVER_NAME}")"
mv "${conf}" "${ARCHIVED_CONFIG_DIR}/${SERVER_NAME}-${ts}.conf"
event_emit "server_archived" "archive=${dst}"

echo "Archived ${SERVER_NAME} to ${dst}"
