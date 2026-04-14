\
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib.sh"

SERVER="${1:-}"
BACKUP_FILE="${2:-}"
JSON_MODE="${3:-}"

[[ -n "${SERVER}" ]] || die "usage: verify-backup.sh <server> [backup-file] [--json]"
load_server "${SERVER}"

if [[ -z "${BACKUP_FILE}" || "${BACKUP_FILE}" == "--json" ]]; then
  BACKUP_FILE="$(backup_latest_file || true)"
  [[ "${2:-}" == "--json" ]] && JSON_MODE="--json"
fi
[[ -n "${BACKUP_FILE}" ]] || die "no backup file found"

MANIFEST="$(manifest_for_backup "${BACKUP_FILE}")"
require_file "${BACKUP_FILE}"
require_file "${MANIFEST}"

actual="$(sha256sum "${BACKUP_FILE}" | awk '{print $1}')"
expected="$(python3 - "${MANIFEST}" <<'PY'
import json,sys
with open(sys.argv[1],encoding="utf-8") as fh:
    print(json.load(fh)["sha256"])
PY
)"

ok="false"
[[ "${actual}" == "${expected}" ]] && ok="true"

if [[ "${JSON_MODE}" == "--json" ]]; then
  python3 - <<'PY' "${SERVER_NAME}" "${BACKUP_FILE}" "${MANIFEST}" "${expected}" "${actual}" "${ok}"
import json,sys
keys=["server","backup_file","manifest","expected_sha256","actual_sha256","ok"]
print(json.dumps(dict(zip(keys, sys.argv[1:])), ensure_ascii=False))
PY
else
  echo "Backup file : ${BACKUP_FILE}"
  echo "Manifest    : ${MANIFEST}"
  echo "Expected    : ${expected}"
  echo "Actual      : ${actual}"
  echo "Verified    : ${ok}"
fi

[[ "${ok}" == "true" ]]
