#!/usr/bin/env bash
set -euo pipefail

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="${MINECRAFT_BASE_DIR:-$(cd "${LIB_DIR}/.." && pwd)}"
GLOBAL_CONF="${BASE_DIR}/config/global.conf"

[[ -f "${GLOBAL_CONF}" ]] || { echo "Error: global config missing: ${GLOBAL_CONF}" >&2; exit 1; }
# shellcheck disable=SC1090
source "${GLOBAL_CONF}"

die() {
  echo "Error: $*" >&2
  exit 1
}

warn() {
  echo "Warning: $*" >&2
}

log() {
  local msg="$*"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${msg}"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

require_file() {
  [[ -f "$1" ]] || die "required file not found: $1"
}

require_dir() {
  [[ -d "$1" ]] || die "required directory not found: $1"
}

json_escape() {
  python3 - <<'PY' "$1"
import json,sys
print(json.dumps(sys.argv[1]))
PY
}

now_iso() {
  date -Iseconds
}

now_epoch() {
  date +%s
}

active_server() {
  [[ -f "${ACTIVE_SERVER_FILE}" ]] || return 1
  local v
  v="$(tr -d '[:space:]' < "${ACTIVE_SERVER_FILE}")"
  [[ -n "${v}" ]] || return 1
  printf '%s\n' "${v}"
}

set_active_server() {
  local server="$1"
  printf '%s\n' "${server}" > "${ACTIVE_SERVER_FILE}"
}

sanitize_server_name() {
  local value="$1"
  [[ "${value}" =~ ^[A-Za-z0-9._-]+$ ]] || die "invalid server name: ${value}"
}

server_conf_path() {
  printf '%s/%s.conf\n' "${SERVER_CONFIG_DIR}" "$1"
}

load_server() {
  local requested="${1:-}"
  if [[ -z "${requested}" ]]; then
    requested="$(active_server || true)"
  fi
  [[ -n "${requested}" ]] || die "no server specified and no active server set"

  sanitize_server_name "${requested}"
  local conf
  conf="$(server_conf_path "${requested}")"
  require_file "${conf}"

  # shellcheck disable=SC1090
  source "${conf}"

  SERVER_NAME="${SERVER_NAME:-${requested}}"
  DISPLAY_NAME="${DISPLAY_NAME:-${DEFAULT_DISPLAY_NAME}}"
  SERVER_DIR="${SERVER_DIR:-${SERVERS_DIR}/${SERVER_NAME}}"
  WORLD_DIR="${WORLD_DIR:-${SERVER_DIR}/world}"
  TEMPLATE_NAME="${TEMPLATE_NAME:-${DEFAULT_TEMPLATE_NAME}}"
  MODPACK_NAME="${MODPACK_NAME:-}"
  MODPACK_VERSION="${MODPACK_VERSION:-}"

  TMUX_SESSION="${TMUX_SESSION:-mc-${SERVER_NAME}}"
  SERVICE_NAME="${SERVICE_NAME:-minecraft-${SERVER_NAME}}"

  JAVA_BIN="${JAVA_BIN:-${DEFAULT_JAVA_BIN}}"
  MCRCON="${MCRCON:-${DEFAULT_MCRCON}}"

  GAME_PORT="${GAME_PORT:-${DEFAULT_GAME_PORT}}"
  RCON_HOST="${RCON_HOST:-${DEFAULT_RCON_HOST}}"
  RCON_PORT="${RCON_PORT:-${DEFAULT_RCON_PORT}}"
  RCON_PASSWORD="${RCON_PASSWORD:-${DEFAULT_RCON_PASSWORD}}"

  LOCAL_BACKUP_DIR="${LOCAL_BACKUP_DIR:-${LOCAL_BACKUPS_DIR}/${SERVER_NAME}}"
  BACKUP_MANIFEST_DIR="${BACKUP_MANIFEST_DIR:-${BACKUP_MANIFESTS_DIR}/${SERVER_NAME}}"
  RESTORE_WORK_DIR="${RESTORE_WORK_DIR:-${RESTORE_DIR}/${SERVER_NAME}}"

  BACKUP_ON_CALENDAR="${BACKUP_ON_CALENDAR:-${DEFAULT_BACKUP_ON_CALENDAR}}"
  ENABLE_SCHEDULED_RESTARTS="${ENABLE_SCHEDULED_RESTARTS:-${DEFAULT_ENABLE_SCHEDULED_RESTARTS}}"
  RESTART_ON_CALENDAR="${RESTART_ON_CALENDAR:-${DEFAULT_RESTART_ON_CALENDAR}}"
  ENABLE_RESTART_WARNINGS="${ENABLE_RESTART_WARNINGS:-${DEFAULT_ENABLE_RESTART_WARNINGS}}"
  RESTART_WARNING_INTERVALS="${RESTART_WARNING_INTERVALS:-${DEFAULT_RESTART_WARNING_INTERVALS}}"
  FINAL_RESTART_WARNING_SECONDS="${FINAL_RESTART_WARNING_SECONDS:-${DEFAULT_FINAL_RESTART_WARNING_SECONDS}}"

  KEEP_HOURLY="${KEEP_HOURLY:-${DEFAULT_KEEP_HOURLY}}"
  KEEP_DAILY="${KEEP_DAILY:-${DEFAULT_KEEP_DAILY}}"
  KEEP_WEEKLY="${KEEP_WEEKLY:-${DEFAULT_KEEP_WEEKLY}}"

  ENABLE_OFFSITE_BACKUP="${ENABLE_OFFSITE_BACKUP:-${DEFAULT_ENABLE_OFFSITE_BACKUP}}"
  OFFSITE_TARGET="${OFFSITE_TARGET:-${DEFAULT_OFFSITE_TARGET}}"

  SHUTDOWN_TIMEOUT="${SHUTDOWN_TIMEOUT:-${DEFAULT_SHUTDOWN_TIMEOUT}}"
  MAX_BACKUP_AGE_HOURS="${MAX_BACKUP_AGE_HOURS:-${DEFAULT_MAX_BACKUP_AGE_HOURS}}"
  CRASH_LOCK_THRESHOLD="${CRASH_LOCK_THRESHOLD:-${DEFAULT_CRASH_LOCK_THRESHOLD}}"
  CRASH_LOCK_WINDOW_MINUTES="${CRASH_LOCK_WINDOW_MINUTES:-${DEFAULT_CRASH_LOCK_WINDOW_MINUTES}}"
  CRASH_RESTART_BACKOFF_SECONDS="${CRASH_RESTART_BACKOFF_SECONDS:-${DEFAULT_CRASH_RESTART_BACKOFF_SECONDS}}"

  START_SCRIPT_NAME="${START_SCRIPT_NAME:-${DEFAULT_START_SCRIPT_NAME}}"
  UNIX_ARGS_FILE="${UNIX_ARGS_FILE:-${DEFAULT_UNIX_ARGS_FILE}}"
  SERVER_JAR="${SERVER_JAR:-}"

  MIN_FREE_MB_START="${MIN_FREE_MB_START:-${DEFAULT_MIN_FREE_MB_START}}"
  MIN_FREE_MB_BACKUP="${MIN_FREE_MB_BACKUP:-${DEFAULT_MIN_FREE_MB_BACKUP}}"
  MIN_FREE_MB_RESTORE="${MIN_FREE_MB_RESTORE:-${DEFAULT_MIN_FREE_MB_RESTORE}}"

  SERVER_STATE_DIR="${STATE_DIR}/${SERVER_NAME}"
  SERVER_LOG_DIR="${LOGS_DIR}/${SERVER_NAME}"
  SERVER_TMP_DIR="${TMP_DIR}/${SERVER_NAME}"
  SERVER_CRASH_DIR="${CRASH_DIR}/${SERVER_NAME}"
  SERVER_RESTORE_DIR="${RESTORE_DIR}/${SERVER_NAME}"
  SERVER_EVENTS_FILE="${EVENTS_DIR}/${SERVER_NAME}.jsonl"

  RUN_STATUS_FILE="${SERVER_STATE_DIR}/run.status"
  BACKUP_STATUS_FILE="${SERVER_STATE_DIR}/backup.status"
  RESTORE_STATUS_FILE="${SERVER_STATE_DIR}/restore.status"
  RESTART_STATUS_FILE="${SERVER_STATE_DIR}/restart.status"
  CRASH_STATUS_FILE="${SERVER_STATE_DIR}/crash.status"
  HEALTH_STATUS_FILE="${SERVER_STATE_DIR}/health.status"
  LOCK_STATUS_FILE="${SERVER_STATE_DIR}/lock.status"
  CURRENT_OPERATION_FILE="${SERVER_STATE_DIR}/current-operation.status"
  STOP_REQUEST_FILE="${SERVER_STATE_DIR}/stop.request"
  SUPERVISOR_FILE="${SERVER_TMP_DIR}/supervisor.sh"

  ADMIN_LOG="${SERVER_LOG_DIR}/admin.log"
  RUNTIME_LOG="${SERVER_LOG_DIR}/runtime.log"
  BACKUP_LOG="${SERVER_LOG_DIR}/backup.log"
  RESTORE_LOG="${SERVER_LOG_DIR}/restore.log"
  RESTART_LOG="${SERVER_LOG_DIR}/restart.log"
  HEALTH_LOG="${SERVER_LOG_DIR}/health.log"
  CRASH_LOG="${SERVER_LOG_DIR}/crash.log"

  SERVER_UNIT="${SERVICE_NAME}.service"
  BACKUP_SERVICE_UNIT="${SERVICE_NAME}-backup.service"
  BACKUP_TIMER_UNIT="${SERVICE_NAME}-backup.timer"
  RESTART_SERVICE_UNIT="${SERVICE_NAME}-scheduled-restart.service"
  RESTART_TIMER_UNIT="${SERVICE_NAME}-scheduled-restart.timer"
}

ensure_server_dirs() {
  mkdir -p \
    "${SERVER_DIR}" \
    "${WORLD_DIR}" \
    "${LOCAL_BACKUP_DIR}" \
    "${BACKUP_MANIFEST_DIR}" \
    "${RESTORE_WORK_DIR}" \
    "${SERVER_STATE_DIR}" \
    "${SERVER_LOG_DIR}" \
    "${SERVER_TMP_DIR}" \
    "${SERVER_CRASH_DIR}" \
    "${SERVER_RESTORE_DIR}"
  touch "${ADMIN_LOG}" "${RUNTIME_LOG}" "${BACKUP_LOG}" "${RESTORE_LOG}" "${RESTART_LOG}" "${HEALTH_LOG}" "${CRASH_LOG}"
}

status_write() {
  local file="$1"; shift
  mkdir -p "$(dirname "${file}")"
  : > "${file}"
  while (( "$#" )); do
    printf '%s=%s\n' "$1" "$2" >> "${file}"
    shift 2
  done
}

status_get() {
  local file="$1" key="$2"
  [[ -f "${file}" ]] || return 1
  grep -E "^${key}=" "${file}" | tail -n1 | cut -d= -f2-
}

status_set() {
  local file="$1" key="$2" value="$3"
  mkdir -p "$(dirname "${file}")"
  touch "${file}"
  if grep -q -E "^${key}=" "${file}"; then
    python3 - "$file" "$key" "$value" <<'PY'
import sys, pathlib
path = pathlib.Path(sys.argv[1]); key = sys.argv[2]; value = sys.argv[3]
lines = path.read_text().splitlines()
done = False
out = []
for line in lines:
    if line.startswith(key + "="):
        out.append(f"{key}={value}")
        done = True
    else:
        out.append(line)
if not done:
    out.append(f"{key}={value}")
path.write_text("\n".join(out) + ("\n" if out else ""))
PY
  else
    printf '%s=%s\n' "${key}=%s\n" "${key}" "${value}" >> "${file}"
  fi
}

event_emit() {
  local event="$1"
  shift || true
  "${TOOLS_DIR}/emit-event.sh" "${SERVER_NAME}" "${event}" "$@" >/dev/null || true
}

tmux_cmd() {
  local socket_name="${TMUX_SOCKET_NAME:-mcadmin-default}"
  if [[ -n "${MCADMIN_TEST_MODE:-}" ]]; then
    tmux -L "${socket_name}" "$@"
  else
    tmux "$@"
  fi
}

server_running_tmux() {
  tmux_cmd has-session -t "${TMUX_SESSION}" 2>/dev/null
}

server_runtime_state() {
  if server_running_tmux; then
    echo "RUNNING"
  else
    echo "STOPPED"
  fi
}

unit_path() {
  printf '%s/%s\n' "${SYSTEMD_DIR}" "$1"
}

write_root_file() {
  local target="$1"
  local tmp
  tmp="$(mktemp)"
  cat > "${tmp}"

  mkdir -p "$(dirname "${target}")"

  if [[ -n "${MCADMIN_TEST_MODE:-}" ]]; then
    install -m 0644 "${tmp}" "${target}"
  elif [[ -w "$(dirname "${target}")" ]]; then
    install -m 0644 "${tmp}" "${target}"
  else
    sudo install -m 0644 "${tmp}" "${target}"
  fi

  rm -f "${tmp}"
}

systemctl_do() {
  if [[ -n "${MCADMIN_TEST_MODE:-}" ]]; then
    return 0
  fi

  if [[ $EUID -eq 0 ]]; then
    systemctl "$@"
  else
    sudo systemctl "$@"
  fi
}

disk_free_mb() {
  df -Pm "${BASE_DIR}" | awk 'NR==2 {print $4}'
}

port_in_use() {
  local port="$1"
  ss -ltn "( sport = :${port} )" | tail -n +2 | grep -q .
}

safe_copy_template_if_missing() {
  local template="${1}"
  local dst="${2}"
  if [[ -d "${dst}" ]] && [[ -n "$(find "${dst}" -mindepth 1 -maxdepth 1 2>/dev/null)" ]]; then
    return 0
  fi
  local src="${TEMPLATES_DIR}/${template}"
  [[ -d "${src}" ]] || die "template not found: ${src}"
  mkdir -p "${dst}"
  rsync -a "${src}/" "${dst}/"
}

human_age_from_epoch() {
  local epoch="${1:-0}"
  if [[ -z "${epoch}" || "${epoch}" == "0" ]]; then
    echo "never"
    return
  fi
  python3 - "$epoch" <<'PY'
import sys, time
t = int(sys.argv[1]); delta = int(time.time()) - t
if delta < 60: print(f"{delta}s")
elif delta < 3600: print(f"{delta//60}m")
elif delta < 86400: print(f"{delta//3600}h")
else: print(f"{delta//86400}d")
PY
}

backup_latest_file() {
  [[ -d "${LOCAL_BACKUP_DIR}" ]] || return 1
  ls -1t "${LOCAL_BACKUP_DIR}"/*.tar.gz 2>/dev/null | head -n1
}

manifest_for_backup() {
  local backup_file="$1"
  local base
  base="$(basename "${backup_file}" .tar.gz)"
  printf '%s/%s.manifest.json\n' "${BACKUP_MANIFEST_DIR}" "${base}"
}
