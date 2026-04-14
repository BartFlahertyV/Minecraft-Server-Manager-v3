\
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib.sh"

SERVER="${1:-}"
[[ -n "${SERVER}" ]] || die "usage: write-systemd-units.sh <server>"
load_server "${SERVER}"
ensure_server_dirs

USER_NAME="${SUDO_USER:-$USER}"

SERVER_UNIT_PATH="$(unit_path "${SERVER_UNIT}")"
BACKUP_SERVICE_PATH="$(unit_path "${BACKUP_SERVICE_UNIT}")"
BACKUP_TIMER_PATH="$(unit_path "${BACKUP_TIMER_UNIT}")"
RESTART_SERVICE_PATH="$(unit_path "${RESTART_SERVICE_UNIT}")"
RESTART_TIMER_PATH="$(unit_path "${RESTART_TIMER_UNIT}")"

write_root_file "${SERVER_UNIT_PATH}" <<EOF
[Unit]
Description=${PLATFORM_NAME} server (${SERVER_NAME})
After=network.target

[Service]
Type=oneshot
User=${USER_NAME}
WorkingDirectory=${SERVER_DIR}
ExecStart=${SCRIPTS_DIR}/run-server.sh ${SERVER_NAME}
ExecStop=${SCRIPTS_DIR}/stop-server.sh ${SERVER_NAME}
RemainAfterExit=yes
TimeoutStartSec=30
TimeoutStopSec=${SHUTDOWN_TIMEOUT}
StandardOutput=append:${ADMIN_LOG}
StandardError=append:${ADMIN_LOG}

[Install]
WantedBy=multi-user.target
EOF

write_root_file "${BACKUP_SERVICE_PATH}" <<EOF
[Unit]
Description=${PLATFORM_NAME} backup (${SERVER_NAME})

[Service]
Type=oneshot
User=${USER_NAME}
WorkingDirectory=${SERVER_DIR}
ExecStart=${SCRIPTS_DIR}/backup-server.sh ${SERVER_NAME}
StandardOutput=append:${BACKUP_LOG}
StandardError=append:${BACKUP_LOG}
EOF

write_root_file "${BACKUP_TIMER_PATH}" <<EOF
[Unit]
Description=${PLATFORM_NAME} backup timer (${SERVER_NAME})

[Timer]
OnCalendar=${BACKUP_ON_CALENDAR}
Persistent=true
Unit=${BACKUP_SERVICE_UNIT}

[Install]
WantedBy=timers.target
EOF

write_root_file "${RESTART_SERVICE_PATH}" <<EOF
[Unit]
Description=${PLATFORM_NAME} scheduled restart (${SERVER_NAME})

[Service]
Type=oneshot
User=${USER_NAME}
WorkingDirectory=${SERVER_DIR}
ExecStart=${TOOLS_DIR}/scheduled-restart-start.sh ${SERVER_NAME}
StandardOutput=append:${RESTART_LOG}
StandardError=append:${RESTART_LOG}
EOF

if [[ "${ENABLE_SCHEDULED_RESTARTS}" == "yes" ]]; then
  write_root_file "${RESTART_TIMER_PATH}" <<EOF
[Unit]
Description=${PLATFORM_NAME} scheduled restart timer (${SERVER_NAME})

[Timer]
OnCalendar=${RESTART_ON_CALENDAR}
Persistent=true
Unit=${RESTART_SERVICE_UNIT}

[Install]
WantedBy=timers.target
EOF
else
  if [[ -w "${SYSTEMD_DIR}" ]]; then
    rm -f "${RESTART_TIMER_PATH}"
  else
    sudo rm -f "${RESTART_TIMER_PATH}"
  fi
fi

if command -v systemctl >/dev/null 2>&1; then
  systemctl_do daemon-reload
fi

echo "Wrote units for ${SERVER_NAME}"
