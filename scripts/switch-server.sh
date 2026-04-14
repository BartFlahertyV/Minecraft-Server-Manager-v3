\
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../tools/lib.sh"

SERVER="${1:-}"
START_AFTER="no"
[[ "$*" == *"--start"* ]] && START_AFTER="yes"
[[ -n "${SERVER}" ]] || die "usage: switch-server.sh <server> [--start]"

load_server "${SERVER}"
ensure_server_dirs
"${TOOLS_DIR}/preflight.sh" switch "${SERVER}" >/dev/null

old="$(active_server || true)"
if [[ -n "${old}" && "${old}" != "${SERVER}" ]]; then
  if [[ -f "$(server_conf_path "${old}")" ]]; then
    "${SCRIPT_DIR}/stop-server.sh" "${old}" >/dev/null 2>&1 || true
    old_service="minecraft-${old}"
    systemctl_do disable "${old_service}-backup.timer" >/dev/null 2>&1 || true
    systemctl_do stop "${old_service}-backup.timer" >/dev/null 2>&1 || true
    systemctl_do disable "${old_service}-scheduled-restart.timer" >/dev/null 2>&1 || true
    systemctl_do stop "${old_service}-scheduled-restart.timer" >/dev/null 2>&1 || true
  fi
fi

set_active_server "${SERVER_NAME}"
"${TOOLS_DIR}/write-systemd-units.sh" "${SERVER_NAME}"

systemctl_do enable "${SERVER_UNIT}" >/dev/null 2>&1 || true
systemctl_do enable "${BACKUP_TIMER_UNIT}" >/dev/null 2>&1 || true
systemctl_do restart "${BACKUP_TIMER_UNIT}" >/dev/null 2>&1 || true

if [[ "${ENABLE_SCHEDULED_RESTARTS}" == "yes" ]]; then
  systemctl_do enable "${RESTART_TIMER_UNIT}" >/dev/null 2>&1 || true
  systemctl_do restart "${RESTART_TIMER_UNIT}" >/dev/null 2>&1 || true
fi

event_emit "active_server_switched" "previous=${old}" "current=${SERVER_NAME}"

if [[ "${START_AFTER}" == "yes" ]]; then
  "${SCRIPT_DIR}/run-server.sh" "${SERVER_NAME}"
fi

echo "Active server set to ${SERVER_NAME}"
