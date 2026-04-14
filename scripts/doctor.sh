\
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../tools/lib.sh"

SERVER=""
JSON_MODE="no"
for arg in "$@"; do
  case "$arg" in
    --json) JSON_MODE="yes" ;;
    *) SERVER="$arg" ;;
  esac
done
load_server "${SERVER}"
ensure_server_dirs

checks=()
failures=0

check() {
  local name="$1" cmd="$2"
  if bash -lc "${cmd}" >/dev/null 2>&1; then
    checks+=("${name}:ok")
  else
    checks+=("${name}:fail")
    failures=$((failures + 1))
  fi
}

check "config" "\"${TOOLS_DIR}/validate-server-config.sh\" \"${SERVER_NAME}\""
check "platform" "\"${TOOLS_DIR}/validate-platform.sh\" >/dev/null"
check "server_dir" "[ -d \"${SERVER_DIR}\" ]"
check "backup_dir" "[ -d \"${LOCAL_BACKUP_DIR}\" ]"
check "tmux" "command -v tmux"
check "systemctl" "command -v systemctl"

latest_backup="$(backup_latest_file || true)"
backup_ok="no"
if [[ -n "${latest_backup}" ]]; then
  backup_epoch="$(stat -c %Y "${latest_backup}" 2>/dev/null || echo 0)"
  age_hours="$(( ( $(now_epoch) - backup_epoch ) / 3600 ))"
  if (( age_hours <= MAX_BACKUP_AGE_HOURS )); then
    backup_ok="yes"
  fi
else
  age_hours="999999"
fi

status_write "${HEALTH_STATUS_FILE}" STATE "$([[ ${failures} -eq 0 ]] && echo OK || echo FAIL)" LAST_RUN "$(now_iso)" BACKUP_OK "${backup_ok}"

if [[ "${JSON_MODE}" == "yes" ]]; then
  python3 - <<'PY' "${SERVER_NAME}" "${failures}" "${backup_ok}" "${latest_backup}" "${checks[@]}"
import json, sys
server = sys.argv[1]; failures = int(sys.argv[2]); backup_ok = sys.argv[3]; latest_backup = sys.argv[4]
checks = []
for item in sys.argv[5:]:
    name, status = item.split(":",1)
    checks.append({"name": name, "status": status})
print(json.dumps({"server": server, "ok": failures == 0, "backup_ok": backup_ok == "yes", "latest_backup": latest_backup, "checks": checks}, ensure_ascii=False))
PY
else
  echo "Doctor: ${SERVER_NAME}"
  for item in "${checks[@]}"; do
    printf ' - %s\n' "${item}"
  done
  echo "Latest backup: ${latest_backup:-none}"
  echo "Backup fresh : ${backup_ok}"
  [[ ${failures} -eq 0 ]]
fi
