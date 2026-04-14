#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib.sh"

MODE="${1:-}"
SERVER="${2:-}"
JSON_MODE="${3:-}"

[[ -n "${MODE}" && -n "${SERVER}" ]] || die "usage: preflight.sh <start|backup|restore|switch|delete|archive> <server> [--json]"

load_server "${SERVER}"
ensure_server_dirs

errors=()
warnings=()

add_error() {
  errors+=("$1")
}

add_warning() {
  warnings+=("$1")
}

launch_mode=""

detect_launch_mode() {
  if [[ -f "${SERVER_DIR}/${START_SCRIPT_NAME}" ]]; then
    launch_mode="start_script"
    return 0
  fi

  if [[ -n "${SERVER_JAR}" && -f "${SERVER_DIR}/${SERVER_JAR}" ]]; then
    launch_mode="server_jar"
    return 0
  fi

  if [[ -f "${SERVER_DIR}/${UNIX_ARGS_FILE}" ]]; then
    launch_mode="unix_args"
    return 0
  fi

  launch_mode=""
  return 1
}

validate_java_if_needed() {
  case "${launch_mode}" in
    server_jar|unix_args)
      [[ -n "${JAVA_BIN}" ]] || add_error "JAVA_BIN is empty"
      [[ -x "${JAVA_BIN}" ]] || add_error "JAVA_BIN is not executable: ${JAVA_BIN}"
      ;;
    start_script)
      # start scripts may invoke Java internally, so we only warn if JAVA_BIN is absent
      if [[ -z "${JAVA_BIN}" || ! -x "${JAVA_BIN}" ]]; then
        add_warning "JAVA_BIN is not executable; assuming ${START_SCRIPT_NAME} handles Java itself"
      fi
      ;;
  esac
}

validate_common() {
  "${SCRIPT_DIR}/validate-server-config.sh" "${SERVER}" >/dev/null || add_error "config validation failed"
  [[ -d "${SERVER_DIR}" ]] || add_error "server dir missing: ${SERVER_DIR}"
}

case "${MODE}" in
  start)
    validate_common
    require_command tmux || add_error "tmux missing"

    if ! detect_launch_mode; then
      add_error "no valid launch path found"
    else
      validate_java_if_needed
    fi

    free_mb="$(disk_free_mb || echo 0)"
    [[ "${free_mb}" =~ ^[0-9]+$ ]] || free_mb=0
    (( free_mb >= MIN_FREE_MB_START )) || add_error "free disk below MIN_FREE_MB_START (${MIN_FREE_MB_START} MB)"

    if [[ "${GAME_PORT}" =~ ^[0-9]+$ ]] && port_in_use "${GAME_PORT}" && ! server_running_tmux; then
      add_warning "GAME_PORT ${GAME_PORT} already listening"
    fi
    ;;

  backup)
    validate_common
    require_command tar || add_error "tar missing"

    free_mb="$(disk_free_mb || echo 0)"
    [[ "${free_mb}" =~ ^[0-9]+$ ]] || free_mb=0
    (( free_mb >= MIN_FREE_MB_BACKUP )) || add_error "free disk below MIN_FREE_MB_BACKUP (${MIN_FREE_MB_BACKUP} MB)"
    ;;

  restore)
    validate_common
    require_command rsync || add_error "rsync missing"

    free_mb="$(disk_free_mb || echo 0)"
    [[ "${free_mb}" =~ ^[0-9]+$ ]] || free_mb=0
    (( free_mb >= MIN_FREE_MB_RESTORE )) || add_error "free disk below MIN_FREE_MB_RESTORE (${MIN_FREE_MB_RESTORE} MB)"
    ;;

  switch|delete|archive)
    [[ -f "$(server_conf_path "${SERVER}")" ]] || add_error "server config missing"
    ;;

  *)
    add_error "unknown mode: ${MODE}"
    ;;
esac

if [[ "${JSON_MODE}" == "--json" ]]; then
  python3 - <<'PY' "${MODE}" "${SERVER}" "${#errors[@]}" "${#warnings[@]}" "${errors[@]}" -- "${warnings[@]}"
import json, sys
mode, server = sys.argv[1], sys.argv[2]
errn = int(sys.argv[3]); warnn = int(sys.argv[4]); items = sys.argv[5:]
sep = items.index("--")
errs = items[:sep]
warns = items[sep+1:]
print(json.dumps({
    "ok": errn == 0,
    "mode": mode,
    "server": server,
    "errors": errs,
    "warnings": warns
}, ensure_ascii=False))
PY
else
  echo "Preflight: ${MODE} ${SERVER}"
  for w in "${warnings[@]}"; do
    echo "WARN: ${w}"
  done
  if (( ${#errors[@]} )); then
    for e in "${errors[@]}"; do
      echo "ERR : ${e}"
    done
    exit 1
  fi
  echo "OK"
fi
