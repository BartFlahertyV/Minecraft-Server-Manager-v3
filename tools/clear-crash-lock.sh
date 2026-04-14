\
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib.sh"

SERVER="${1:-}"
[[ -n "${SERVER}" ]] || die "usage: clear-crash-lock.sh <server>"
load_server "${SERVER}"
ensure_server_dirs

status_write "${LOCK_STATUS_FILE}" LOCKED no CLEARED_AT "$(now_iso)" REASON manual_clear
status_set "${CRASH_STATUS_FILE}" LOCKED no
status_set "${CRASH_STATUS_FILE}" CRASH_COUNT_WINDOW 0
event_emit "crash_lock_cleared"
echo "Crash lock cleared for ${SERVER_NAME}"
