\
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../tools/lib.sh"

SERVER=""
JSON_MODE="no"
for arg in "$@"; do
  case "$arg" in
    --json) JSON_MODE="yes" ;;
    *) SERVER="$arg" ;;
  esac
done
load_server "${SERVER}"
ensure_server_dirs

run_state="$(server_runtime_state)"
latest_backup="$(backup_latest_file || true)"
latest_backup_age="never"
latest_backup_epoch="0"
if [[ -n "${latest_backup}" ]]; then
  latest_backup_epoch="$(stat -c %Y "${latest_backup}" 2>/dev/null || echo 0)"
  latest_backup_age="$(human_age_from_epoch "${latest_backup_epoch}")"
fi

lock_state="$(status_get "${LOCK_STATUS_FILE}" LOCKED || echo no)"
crash_count="$(status_get "${CRASH_STATUS_FILE}" CRASH_COUNT_WINDOW || echo 0)"
last_exit_code="$(status_get "${CRASH_STATUS_FILE}" LAST_EXIT_CODE || echo 0)"
last_crash_epoch="$(status_get "${CRASH_STATUS_FILE}" LAST_CRASH_EPOCH || echo 0)"
last_crash_age="$(human_age_from_epoch "${last_crash_epoch}")"

if [[ "${JSON_MODE}" == "yes" ]]; then
  python3 - <<'PY' \
    "${SERVER_NAME}" "${DISPLAY_NAME}" "${run_state}" "${TMUX_SESSION}" "${SERVICE_NAME}" \
    "${lock_state}" "${crash_count}" "${last_exit_code}" "${last_crash_epoch}" "${last_crash_age}" \
    "${latest_backup}" "${latest_backup_epoch}" "${latest_backup_age}" "${GAME_PORT}" "${RCON_PORT}"
import json, sys
keys = ["server","display_name","run_state","tmux_session","service_name","locked","crash_count_window","last_exit_code","last_crash_epoch","last_crash_age","latest_backup","latest_backup_epoch","latest_backup_age","game_port","rcon_port"]
vals = sys.argv[1:]
print(json.dumps(dict(zip(keys, vals)), ensure_ascii=False))
PY
else
  echo "Server             : ${SERVER_NAME}"
  echo "Display name       : ${DISPLAY_NAME}"
  echo "Run state          : ${run_state}"
  echo "tmux session       : ${TMUX_SESSION}"
  echo "Service name       : ${SERVICE_NAME}"
  echo "Crash lock         : ${lock_state}"
  echo "Crash count window : ${crash_count}"
  echo "Last exit code     : ${last_exit_code}"
  echo "Last crash age     : ${last_crash_age}"
  echo "Latest backup      : ${latest_backup:-none}"
  echo "Latest backup age  : ${latest_backup_age}"
  echo "Game/RCON ports    : ${GAME_PORT} / ${RCON_PORT}"
fi
