\
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib.sh"

SERVER="${1:-}"
ARCHIVE="${2:-}"
MANIFEST="${3:-}"
[[ -n "${SERVER}" && -n "${ARCHIVE}" && -n "${MANIFEST}" ]] || die "usage: offsite-backup.sh <server> <archive> <manifest>"
load_server "${SERVER}"

if [[ "${ENABLE_OFFSITE_BACKUP}" != "yes" ]]; then
  echo "Offsite backup disabled"
  exit 0
fi

[[ -n "${OFFSITE_TARGET}" ]] || die "OFFSITE_TARGET is empty"

if command -v rclone >/dev/null 2>&1; then
  rclone copy "${ARCHIVE}" "${OFFSITE_TARGET}/$(basename "${ARCHIVE}")"
  rclone copy "${MANIFEST}" "${OFFSITE_TARGET}/$(basename "${MANIFEST}")"
else
  die "rclone not installed"
fi

event_emit "offsite_backup_success" "target=${OFFSITE_TARGET}" "archive=${ARCHIVE}"
echo "Offsite backup copied to ${OFFSITE_TARGET}"
