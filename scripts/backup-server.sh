\
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../tools/lib.sh"

SERVER="${1:-}"
[[ -n "${SERVER}" ]] || die "usage: backup-server.sh <server>"
load_server "${SERVER}"
ensure_server_dirs
"${TOOLS_DIR}/preflight.sh" backup "${SERVER}" >/dev/null

ts="$(date +%Y-%m-%d_%H%M%S)"
archive="${LOCAL_BACKUP_DIR}/${SERVER_NAME}-${ts}.tar.gz"
manifest="${BACKUP_MANIFEST_DIR}/${SERVER_NAME}-${ts}.manifest.json"

status_write "${CURRENT_OPERATION_FILE}" OPERATION backing_up AT "$(now_iso)"
status_write "${BACKUP_STATUS_FILE}" STATE STARTING AT "$(now_iso)" PATH "${archive}"

if server_running_tmux && [[ -x "${MCRCON}" ]]; then
  "${MCRCON}" -H "${RCON_HOST}" -P "${RCON_PORT}" -p "${RCON_PASSWORD}" "save-off" >/dev/null 2>&1 || true
  "${MCRCON}" -H "${RCON_HOST}" -P "${RCON_PORT}" -p "${RCON_PASSWORD}" "save-all flush" >/dev/null 2>&1 || true
fi

tar -C "${SERVER_DIR}" \
  --exclude='./logs' \
  --exclude='./crash-reports' \
  --exclude='./debug' \
  -czf "${archive}" .

if server_running_tmux && [[ -x "${MCRCON}" ]]; then
  "${MCRCON}" -H "${RCON_HOST}" -P "${RCON_PORT}" -p "${RCON_PASSWORD}" "save-on" >/dev/null 2>&1 || true
fi

sha="$(sha256sum "${archive}" | awk '{print $1}')"
size="$(stat -c %s "${archive}")"

python3 - "${manifest}" "${SERVER_NAME}" "${archive}" "${sha}" "${size}" "${DISPLAY_NAME}" "${MODPACK_NAME}" "${MODPACK_VERSION}" <<'PY'
import json, sys, datetime, os
manifest, server, archive, sha, size, display, modpack, version = sys.argv[1:]
payload = {
    "server": server,
    "display_name": display,
    "modpack_name": modpack,
    "modpack_version": version,
    "created_at": datetime.datetime.now().astimezone().isoformat(),
    "archive_path": archive,
    "archive_name": os.path.basename(archive),
    "sha256": sha,
    "size_bytes": int(size),
}
with open(manifest, "w", encoding="utf-8") as fh:
    json.dump(payload, fh, indent=2, ensure_ascii=False)
PY

status_write "${BACKUP_STATUS_FILE}" STATE SUCCESS AT "$(now_iso)" PATH "${archive}" MANIFEST "${manifest}" SHA256 "${sha}"
status_write "${CURRENT_OPERATION_FILE}" OPERATION idle AT "$(now_iso)"
event_emit "backup_success" "archive=${archive}" "manifest=${manifest}" "sha256=${sha}"

"${TOOLS_DIR}/cleanup-backups.sh" "${SERVER_NAME}" >/dev/null 2>&1 || true
if [[ "${ENABLE_OFFSITE_BACKUP}" == "yes" ]]; then
  "${TOOLS_DIR}/offsite-backup.sh" "${SERVER_NAME}" "${archive}" "${manifest}" >/dev/null 2>&1 || true
fi

echo "Backup created: ${archive}"
