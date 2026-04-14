\
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib.sh"

SERVER="${1:-}"
[[ -n "${SERVER}" ]] || die "usage: cleanup-backups.sh <server>"
load_server "${SERVER}"
ensure_server_dirs

mapfile -t backups < <(ls -1t "${LOCAL_BACKUP_DIR}"/*.tar.gz 2>/dev/null || true)

keep="${KEEP_HOURLY}"
count=0
deleted=0
for file in "${backups[@]}"; do
  count=$((count + 1))
  if (( count > keep )); then
    manifest="$(manifest_for_backup "${file}")"
    rm -f "${file}" "${manifest}"
    deleted=$((deleted + 1))
  fi
done

status_write "${BACKUP_STATUS_FILE}" STATE CLEANED AT "$(now_iso)" DELETED_COUNT "${deleted}"
event_emit "backup_cleanup" "deleted_count=${deleted}"

echo "Deleted ${deleted} old backups"
