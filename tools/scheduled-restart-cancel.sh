\
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib.sh"

SERVER="${1:-}"
[[ -n "${SERVER}" ]] || die "usage: scheduled-restart-cancel.sh <server>"
load_server "${SERVER}"
status_write "${RESTART_STATUS_FILE}" STATE CANCELLED AT "$(now_iso)"
event_emit "scheduled_restart_cancelled"
echo "Marked scheduled restart as cancelled for ${SERVER_NAME}"
