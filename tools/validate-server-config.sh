\
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib.sh"

usage() {
  echo "Usage: $0 <server_name> [--json]"
  exit 1
}

SERVER="${1:-}"
JSON_MODE="${2:-}"
[[ -n "${SERVER}" ]] || usage
sanitize_server_name "${SERVER}"

CONF="$(server_conf_path "${SERVER}")"
require_file "${CONF}"
# shellcheck disable=SC1090
source "${CONF}"

errors=()
add_error() { errors+=("$1"); }

must_nonempty() {
  local n="$1"; local v="${!n:-}"
  [[ -n "${v}" ]] || add_error "${n} must not be empty"
}

for v in SERVER_NAME DISPLAY_NAME SERVER_DIR WORLD_DIR TEMPLATE_NAME TMUX_SESSION SERVICE_NAME JAVA_BIN GAME_PORT RCON_HOST RCON_PORT RCON_PASSWORD LOCAL_BACKUP_DIR BACKUP_MANIFEST_DIR RESTORE_WORK_DIR BACKUP_ON_CALENDAR ENABLE_SCHEDULED_RESTARTS RESTART_ON_CALENDAR ENABLE_RESTART_WARNINGS RESTART_WARNING_INTERVALS FINAL_RESTART_WARNING_SECONDS KEEP_HOURLY KEEP_DAILY KEEP_WEEKLY ENABLE_OFFSITE_BACKUP SHUTDOWN_TIMEOUT MAX_BACKUP_AGE_HOURS CRASH_LOCK_THRESHOLD CRASH_LOCK_WINDOW_MINUTES CRASH_RESTART_BACKOFF_SECONDS START_SCRIPT_NAME UNIX_ARGS_FILE; do
  must_nonempty "$v"
done

[[ "${SERVER_NAME}" == "${SERVER}" ]] || add_error "SERVER_NAME must match filename"
[[ "${SERVER_NAME}" =~ ^[A-Za-z0-9._-]+$ ]] || add_error "SERVER_NAME contains invalid characters"
[[ "${TMUX_SESSION}" == "mc-${SERVER_NAME}" ]] || add_error "TMUX_SESSION should be mc-${SERVER_NAME}"
[[ "${SERVICE_NAME}" =~ ^[A-Za-z0-9._-]+$ ]] || add_error "SERVICE_NAME contains invalid characters"
[[ "${RCON_PORT}" =~ ^[0-9]+$ ]] || add_error "RCON_PORT must be numeric"
[[ "${GAME_PORT}" =~ ^[0-9]+$ ]] || add_error "GAME_PORT must be numeric"
[[ "${KEEP_HOURLY}" =~ ^[0-9]+$ ]] || add_error "KEEP_HOURLY must be numeric"
[[ "${KEEP_DAILY}" =~ ^[0-9]+$ ]] || add_error "KEEP_DAILY must be numeric"
[[ "${KEEP_WEEKLY}" =~ ^[0-9]+$ ]] || add_error "KEEP_WEEKLY must be numeric"
[[ "${SHUTDOWN_TIMEOUT}" =~ ^[0-9]+$ ]] || add_error "SHUTDOWN_TIMEOUT must be numeric"
[[ "${MAX_BACKUP_AGE_HOURS}" =~ ^[0-9]+$ ]] || add_error "MAX_BACKUP_AGE_HOURS must be numeric"
[[ "${CRASH_LOCK_THRESHOLD}" =~ ^[0-9]+$ ]] || add_error "CRASH_LOCK_THRESHOLD must be numeric"
[[ "${CRASH_LOCK_WINDOW_MINUTES}" =~ ^[0-9]+$ ]] || add_error "CRASH_LOCK_WINDOW_MINUTES must be numeric"
[[ "${CRASH_RESTART_BACKOFF_SECONDS}" =~ ^[0-9]+$ ]] || add_error "CRASH_RESTART_BACKOFF_SECONDS must be numeric"

case "${ENABLE_SCHEDULED_RESTARTS}" in yes|no) ;; *) add_error "ENABLE_SCHEDULED_RESTARTS must be yes or no" ;; esac
case "${ENABLE_RESTART_WARNINGS}" in yes|no) ;; *) add_error "ENABLE_RESTART_WARNINGS must be yes or no" ;; esac
case "${ENABLE_OFFSITE_BACKUP}" in yes|no) ;; *) add_error "ENABLE_OFFSITE_BACKUP must be yes or no" ;; esac

if command -v systemd-analyze >/dev/null 2>&1; then
  systemd-analyze calendar "${BACKUP_ON_CALENDAR}" >/dev/null 2>&1 || add_error "invalid BACKUP_ON_CALENDAR: ${BACKUP_ON_CALENDAR}"
  if [[ "${ENABLE_SCHEDULED_RESTARTS}" == "yes" ]]; then
    systemd-analyze calendar "${RESTART_ON_CALENDAR}" >/dev/null 2>&1 || add_error "invalid RESTART_ON_CALENDAR: ${RESTART_ON_CALENDAR}"
  fi
fi

if (( ${#errors[@]} )); then
  if [[ "${JSON_MODE}" == "--json" ]]; then
    python3 - <<'PY' "${SERVER}" "${errors[@]}"
import json, sys
print(json.dumps({"ok": False, "server": sys.argv[1], "errors": sys.argv[2:]}, ensure_ascii=False))
PY
  else
    echo "FAIL: config validation failed for ${SERVER}"
    for e in "${errors[@]}"; do echo " - ${e}"; done
  fi
  exit 1
fi

if [[ "${JSON_MODE}" == "--json" ]]; then
  python3 - <<'PY' "${SERVER}"
import json, sys
print(json.dumps({"ok": True, "server": sys.argv[1]}, ensure_ascii=False))
PY
else
  echo "PASS: config validation passed for ${SERVER}"
fi
