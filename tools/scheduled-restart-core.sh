\
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib.sh"

SERVER="${1:-}"
[[ -n "${SERVER}" ]] || die "usage: scheduled-restart-core.sh <server>"
load_server "${SERVER}"
ensure_server_dirs

status_write "${RESTART_STATUS_FILE}" STATE STARTING AT "$(now_iso)"
event_emit "scheduled_restart_begin"

if [[ "${ENABLE_RESTART_WARNINGS}" == "yes" ]] && server_running_tmux && [[ -x "${MCRCON}" ]]; then
  for mins in ${RESTART_WARNING_INTERVALS}; do
    "${MCRCON}" -H "${RCON_HOST}" -P "${RCON_PORT}" -p "${RCON_PASSWORD}" "say Server restarting in ${mins} minute(s)." >/dev/null 2>&1 || true
    sleep 60
  done
  for ((i=FINAL_RESTART_WARNING_SECONDS;i>=1;i--)); do
    "${MCRCON}" -H "${RCON_HOST}" -P "${RCON_PORT}" -p "${RCON_PASSWORD}" "say Restarting in ${i} second(s)." >/dev/null 2>&1 || true
    sleep 1
  done
fi

"${SCRIPTS_DIR}/stop-server.sh" "${SERVER_NAME}"
"${SCRIPTS_DIR}/run-server.sh" "${SERVER_NAME}"

status_write "${RESTART_STATUS_FILE}" STATE SUCCESS AT "$(now_iso)"
event_emit "scheduled_restart_success"
