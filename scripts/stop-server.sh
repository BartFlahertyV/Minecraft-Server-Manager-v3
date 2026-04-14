#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../tools/lib.sh"

SERVER="${1:-}"
[[ -n "${SERVER}" ]] || die "usage: stop-server.sh <server>"

load_server "${SERVER}"
ensure_server_dirs

if ! server_running_tmux; then
  status_write "${RUN_STATUS_FILE}" \
    STATE STOPPED \
    STOPPED_AT "$(now_iso)" \
    TMUX_SESSION "${TMUX_SESSION}" \
    SERVER_PID 0
  echo "Server not running"
  exit 0
fi

status_write "${CURRENT_OPERATION_FILE}" \
  OPERATION stopping \
  AT "$(now_iso)"

touch "${STOP_REQUEST_FILE}"

server_pid="$(status_get "${RUN_STATUS_FILE}" SERVER_PID 2>/dev/null || true)"
server_pid="${server_pid:-0}"
[[ "${server_pid}" =~ ^[0-9]+$ ]] || server_pid=0

echo "Stopping ${SERVER_NAME}..."
echo "Initial tracked server PID: ${server_pid}"

# Send stop into tmux first so the live console definitely receives it.
tmux_cmd send-keys -t "${TMUX_SESSION}" "stop" C-m >/dev/null 2>&1 || true

# Then try RCON for servers that respond better to it.
if [[ -x "${MCRCON}" ]]; then
  "${MCRCON}" -H "${RCON_HOST}" -P "${RCON_PORT}" -p "${RCON_PASSWORD}" "save-off" >/dev/null 2>&1 || true
  "${MCRCON}" -H "${RCON_HOST}" -P "${RCON_PORT}" -p "${RCON_PASSWORD}" "save-all flush" >/dev/null 2>&1 || true
  "${MCRCON}" -H "${RCON_HOST}" -P "${RCON_PORT}" -p "${RCON_PASSWORD}" "stop" >/dev/null 2>&1 || true
fi

deadline=$(( $(now_epoch) + SHUTDOWN_TIMEOUT ))
graceful="no"

while true; do
  current_pid="$(status_get "${RUN_STATUS_FILE}" SERVER_PID 2>/dev/null || true)"
  current_pid="${current_pid:-0}"
  [[ "${current_pid}" =~ ^[0-9]+$ ]] || current_pid=0

  if (( current_pid == 0 )); then
    graceful="yes"
    break
  fi

  if ! kill -0 "${current_pid}" 2>/dev/null; then
    graceful="yes"
    break
  fi

  if (( $(now_epoch) >= deadline )); then
    break
  fi

  sleep 2
done

if [[ "${graceful}" != "yes" ]]; then
  warn "Graceful stop timed out; killing server process and tmux session ${TMUX_SESSION}"

  current_pid="$(status_get "${RUN_STATUS_FILE}" SERVER_PID 2>/dev/null || true)"
  current_pid="${current_pid:-0}"
  [[ "${current_pid}" =~ ^[0-9]+$ ]] || current_pid=0

  if (( current_pid > 0 )); then
    kill "${current_pid}" 2>/dev/null || true
    sleep 3
    kill -9 "${current_pid}" 2>/dev/null || true
  fi

  tmux_cmd kill-session -t "${TMUX_SESSION}" >/dev/null 2>&1 || true
else
  # If the server process exited but tmux/supervisor is lingering, give it a moment to notice STOP_REQUEST_FILE.
  linger_deadline=$(( $(now_epoch) + 10 ))
  while server_running_tmux; do
    if (( $(now_epoch) >= linger_deadline )); then
      tmux_cmd kill-session -t "${TMUX_SESSION}" >/dev/null 2>&1 || true
      break
    fi
    sleep 1
  done
fi

rm -f "${STOP_REQUEST_FILE}"

status_write "${RUN_STATUS_FILE}" \
  STATE STOPPED \
  STOPPED_AT "$(now_iso)" \
  TMUX_SESSION "${TMUX_SESSION}" \
  SERVER_PID 0 \
  SUPERVISOR_PID 0

status_write "${CURRENT_OPERATION_FILE}" \
  OPERATION stopped \
  AT "$(now_iso)"

event_emit "server_stop_requested"

echo "Stopped ${SERVER_NAME}"
