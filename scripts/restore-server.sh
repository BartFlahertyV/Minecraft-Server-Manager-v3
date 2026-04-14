\
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../tools/lib.sh"

usage() {
  cat <<EOF
Usage:
  $0 <server> list
  $0 <server> latest [--dry-run]
  $0 <server> <backup-file> [--dry-run]
EOF
  exit 1
}

SERVER="${1:-}"
TARGET="${2:-}"
DRY="no"
[[ "$*" == *"--dry-run"* ]] && DRY="yes"
[[ -n "${SERVER}" && -n "${TARGET}" ]] || usage

load_server "${SERVER}"
ensure_server_dirs
"${TOOLS_DIR}/preflight.sh" restore "${SERVER}" >/dev/null

if [[ "${TARGET}" == "list" ]]; then
  ls -1t "${LOCAL_BACKUP_DIR}"/*.tar.gz 2>/dev/null || true
  exit 0
fi

if [[ "${TARGET}" == "latest" ]]; then
  TARGET="$(backup_latest_file || true)"
fi
[[ -n "${TARGET}" ]] || die "backup not found"

require_file "${TARGET}"
manifest="$(manifest_for_backup "${TARGET}")"
require_file "${manifest}"

"${TOOLS_DIR}/verify-backup.sh" "${SERVER}" "${TARGET}" >/dev/null

status_write "${CURRENT_OPERATION_FILE}" OPERATION restoring AT "$(now_iso)"
status_write "${RESTORE_STATUS_FILE}" STATE STARTING AT "$(now_iso)" SOURCE "${TARGET}"

staging="${SERVER_RESTORE_DIR}/staging-$(date +%Y%m%d_%H%M%S)"
snapshot="${LOCAL_BACKUP_DIR}/${SERVER_NAME}-pre-restore-$(date +%Y-%m-%d_%H%M%S).tar.gz"
mkdir -p "${staging}"

if [[ "${DRY}" == "yes" ]]; then
  tar -tzf "${TARGET}" >/dev/null
  status_write "${RESTORE_STATUS_FILE}" STATE DRY_RUN_OK AT "$(now_iso)" SOURCE "${TARGET}"
  echo "Dry-run restore check passed: ${TARGET}"
  exit 0
fi

if server_running_tmux; then
  "${SCRIPT_DIR}/stop-server.sh" "${SERVER_NAME}"
fi

tar -C "${SERVER_DIR}" -czf "${snapshot}" .
tar -C "${staging}" -xzf "${TARGET}"

rsync -a --delete "${staging}/" "${SERVER_DIR}/"
rm -rf "${staging}"

status_write "${RESTORE_STATUS_FILE}" STATE SUCCESS AT "$(now_iso)" SOURCE "${TARGET}" SNAPSHOT "${snapshot}"
status_write "${CURRENT_OPERATION_FILE}" OPERATION idle AT "$(now_iso)"
event_emit "restore_success" "source=${TARGET}" "snapshot=${snapshot}"

echo "Restore complete from ${TARGET}"
