\
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib.sh"

SERVER="${1:-}"
FORCE="${2:-}"
[[ -n "${SERVER}" ]] || die "usage: delete-server.sh <server> [--force]"
load_server "${SERVER}"

if [[ "${FORCE}" != "--force" ]]; then
  die "refusing to delete without --force"
fi

"${SCRIPTS_DIR}/stop-server.sh" "${SERVER_NAME}" >/dev/null 2>&1 || true
rm -rf "${SERVER_DIR}" "${LOCAL_BACKUP_DIR}" "${BACKUP_MANIFEST_DIR}" "${SERVER_STATE_DIR}" "${SERVER_LOG_DIR}" "${SERVER_TMP_DIR}" "${SERVER_RESTORE_DIR}" "${SERVER_CRASH_DIR}"
rm -f "$(server_conf_path "${SERVER_NAME}")"
if [[ "$(active_server || true)" == "${SERVER_NAME}" ]]; then
  : > "${ACTIVE_SERVER_FILE}"
fi
event_emit "server_deleted"
echo "Deleted ${SERVER_NAME}"
