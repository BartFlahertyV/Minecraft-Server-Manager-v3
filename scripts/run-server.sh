#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../tools/lib.sh"

SERVER="${1:-}"
[[ -n "${SERVER}" ]] || die "usage: run-server.sh <server>"

load_server "${SERVER}"
ensure_server_dirs
"${TOOLS_DIR}/preflight.sh" start "${SERVER}" >/dev/null

if [[ "$(status_get "${LOCK_STATUS_FILE}" LOCKED 2>/dev/null || true)" == "yes" ]]; then
  die "server is crash-locked; run mcadmin unlock-crash"
fi

safe_copy_template_if_missing "${TEMPLATE_NAME}" "${SERVER_DIR}"

if [[ -f "${SERVER_DIR}/server.properties" ]]; then
  "${TOOLS_DIR}/sync-server-properties.sh" "${SERVER_NAME}" >/dev/null
fi

if server_running_tmux; then
  echo "Server already running in tmux session ${TMUX_SESSION}"
  exit 0
fi

rm -f "${STOP_REQUEST_FILE}"

status_write "${CURRENT_OPERATION_FILE}" \
  OPERATION starting \
  AT "$(now_iso)"

status_write "${RUN_STATUS_FILE}" \
  STATE STARTING \
  STARTED_AT "$(now_iso)" \
  TMUX_SESSION "${TMUX_SESSION}" \
  SERVER_PID 0 \
  SUPERVISOR_PID 0

launch_cmd=""
if [[ -f "${SERVER_DIR}/${START_SCRIPT_NAME}" ]]; then
  chmod +x "${SERVER_DIR}/${START_SCRIPT_NAME}" || true
  launch_cmd="cd \"${SERVER_DIR}\" && exec bash \"./${START_SCRIPT_NAME}\""
elif [[ -n "${SERVER_JAR}" && -f "${SERVER_DIR}/${SERVER_JAR}" ]]; then
  launch_cmd="cd \"${SERVER_DIR}\" && exec \"${JAVA_BIN}\" -jar \"${SERVER_JAR}\" nogui"
elif [[ -f "${SERVER_DIR}/${UNIX_ARGS_FILE}" ]]; then
  launch_cmd="cd \"${SERVER_DIR}\" && exec \"${JAVA_BIN}\" @\"${UNIX_ARGS_FILE}\" nogui"
else
  die "no start script, server jar, or unix args file found in ${SERVER_DIR}"
fi

cat > "${SUPERVISOR_FILE}" <<SUPERVISOR_EOF
#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC1091
source "${TOOLS_DIR}/lib.sh"

load_server "${SERVER_NAME}"
ensure_server_dirs

touch "${RUNTIME_LOG}"
printf '\n[%s] ===== supervisor boot for %s =====\n' "\$(now_iso)" "${SERVER_NAME}" >> "${RUNTIME_LOG}"

status_set "${RUN_STATUS_FILE}" SUPERVISOR_PID "\$\$"

while true; do
  printf '[%s] launching server process\n' "\$(now_iso)"
  printf '[%s] launching server process\n' "\$(now_iso)" >> "${RUNTIME_LOG}"

  status_write "${RUN_STATUS_FILE}" \
    STATE RUNNING \
    STARTED_AT "\$(now_iso)" \
    TMUX_SESSION "${TMUX_SESSION}" \
    SERVER_PID 0 \
    SUPERVISOR_PID "\$\$"

  set +e
  bash -lc ${launch_cmd@Q} &
  server_pid=\$!
  status_set "${RUN_STATUS_FILE}" SERVER_PID "\${server_pid}"
  status_set "${RUN_STATUS_FILE}" STATE RUNNING

  wait "\${server_pid}"
  exit_code=\$?
  set -e

  status_set "${RUN_STATUS_FILE}" LAST_EXIT_CODE "\${exit_code}"
  status_set "${RUN_STATUS_FILE}" SERVER_PID 0

  printf '[%s] server process exited code=%s\n' "\$(now_iso)" "\${exit_code}"
  printf '[%s] server process exited code=%s\n' "\$(now_iso)" "\${exit_code}" >> "${RUNTIME_LOG}"

  if [[ -f "${STOP_REQUEST_FILE}" ]]; then
    rm -f "${STOP_REQUEST_FILE}"
    status_write "${RUN_STATUS_FILE}" \
      STATE STOPPED \
      STOPPED_AT "\$(now_iso)" \
      TMUX_SESSION "${TMUX_SESSION}" \
      SERVER_PID 0 \
      SUPERVISOR_PID "\$\$" \
      LAST_EXIT_CODE "\${exit_code}"
    status_set "${CRASH_STATUS_FILE}" LAST_EXIT_CODE "\${exit_code}"
    event_emit "server_stopped" "exit_code=\${exit_code}"
    exit 0
  fi

  now="\$(now_epoch)"
  last="\$(status_get "${CRASH_STATUS_FILE}" LAST_CRASH_EPOCH 2>/dev/null || true)"
  count="\$(status_get "${CRASH_STATUS_FILE}" CRASH_COUNT_WINDOW 2>/dev/null || true)"

  last="\${last:-0}"
  count="\${count:-0}"

  [[ "\${last}" =~ ^[0-9]+$ ]] || last=0
  [[ "\${count}" =~ ^[0-9]+$ ]] || count=0

  if (( last == 0 )); then
    count=1
  else
    window_secs=\$(( CRASH_LOCK_WINDOW_MINUTES * 60 ))
    if (( now - last <= window_secs )); then
      count=\$(( count + 1 ))
    else
      count=1
    fi
  fi

  status_write "${CRASH_STATUS_FILE}" \
    LAST_CRASH_EPOCH "\${now}" \
    CRASH_COUNT_WINDOW "\${count}" \
    LAST_EXIT_CODE "\${exit_code}" \
    LOCKED "no"

  cp "${RUNTIME_LOG}" "${SERVER_CRASH_DIR}/runtime-\$(date +%Y%m%d_%H%M%S).log" 2>/dev/null || true
  printf '[%s] unexpected exit detected; crash_count_window=%s\n' "\$(now_iso)" "\${count}" >> "${CRASH_LOG}"
  event_emit "server_crash" "exit_code=\${exit_code}" "crash_count_window=\${count}"

  if (( count >= CRASH_LOCK_THRESHOLD )); then
    status_write "${LOCK_STATUS_FILE}" \
      LOCKED yes \
      LOCKED_AT "\$(now_iso)" \
      REASON "crash_threshold"

    status_set "${CRASH_STATUS_FILE}" LOCKED yes

    status_write "${RUN_STATUS_FILE}" \
      STATE LOCKED \
      LOCKED_AT "\$(now_iso)" \
      TMUX_SESSION "${TMUX_SESSION}" \
      SERVER_PID 0 \
      SUPERVISOR_PID "\$\$" \
      LAST_EXIT_CODE "\${exit_code}"

    printf '[%s] crash lock engaged\n' "\$(now_iso)" | tee -a "${CRASH_LOG}"
    event_emit "crash_lock_engaged" "crash_count_window=\${count}"
    exit 1
  fi

  status_write "${RUN_STATUS_FILE}" \
    STATE RESTARTING \
    RESTART_AT "\$(now_iso)" \
    TMUX_SESSION "${TMUX_SESSION}" \
    SERVER_PID 0 \
    SUPERVISOR_PID "\$\$" \
    LAST_EXIT_CODE "\${exit_code}"

  printf '[%s] restarting after %ss backoff\n' "\$(now_iso)" "${CRASH_RESTART_BACKOFF_SECONDS}" | tee -a "${RUNTIME_LOG}"
  sleep "${CRASH_RESTART_BACKOFF_SECONDS}"
done
SUPERVISOR_EOF

chmod +x "${SUPERVISOR_FILE}"

touch "${RUNTIME_LOG}"
printf '\n[%s] ===== new session for %s =====\n' "$(now_iso)" "${SERVER_NAME}" >> "${RUNTIME_LOG}"

tmux_cmd new-session -d -s "${TMUX_SESSION}" "bash '${SUPERVISOR_FILE}'"
sleep 1

if ! server_running_tmux; then
  status_write "${RUN_STATUS_FILE}" \
    STATE FAILED \
    FAILED_AT "$(now_iso)" \
    TMUX_SESSION "${TMUX_SESSION}" \
    SERVER_PID 0 \
    SUPERVISOR_PID 0
  die "tmux session failed to stay alive; check ${RUNTIME_LOG} and ${CRASH_LOG}"
fi

tmux_cmd pipe-pane -t "${TMUX_SESSION}:0.0" -o "cat >> '${RUNTIME_LOG}'"

supervisor_pid="$(tmux_cmd list-panes -t "${TMUX_SESSION}:0.0" -F '#{pane_pid}' | head -n1 || true)"
supervisor_pid="${supervisor_pid:-0}"

status_write "${RUN_STATUS_FILE}" \
  STATE RUNNING \
  STARTED_AT "$(now_iso)" \
  TMUX_SESSION "${TMUX_SESSION}" \
  SERVER_PID 0 \
  SUPERVISOR_PID "${supervisor_pid}"

status_write "${CURRENT_OPERATION_FILE}" \
  OPERATION running \
  AT "$(now_iso)"

event_emit "server_started" "tmux_session=${TMUX_SESSION}" "game_port=${GAME_PORT}"

echo "Started ${SERVER_NAME} in tmux session ${TMUX_SESSION}"
echo "Attach with: tmux attach -t ${TMUX_SESSION}"
