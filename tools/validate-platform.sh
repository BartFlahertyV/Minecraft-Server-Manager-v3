\
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib.sh"

JSON_MODE="${1:-}"
missing=()

for cmd in bash python3 tar sha256sum tmux systemctl ss rsync; do
  command -v "${cmd}" >/dev/null 2>&1 || missing+=("${cmd}")
done

if [[ "${JSON_MODE}" == "--json" ]]; then
  python3 - <<'PY' "${BASE_DIR}" "${SYSTEMD_DIR}" "${missing[@]}"
import json, sys
payload = {"base_dir": sys.argv[1], "systemd_dir": sys.argv[2], "missing": sys.argv[3:], "ok": len(sys.argv[3:]) == 0}
print(json.dumps(payload, ensure_ascii=False))
PY
else
  echo "Base dir   : ${BASE_DIR}"
  echo "Systemd dir: ${SYSTEMD_DIR}"
  if (( ${#missing[@]} )); then
    echo "Missing commands:"
    printf ' - %s\n' "${missing[@]}"
    exit 1
  else
    echo "Platform validation passed"
  fi
fi
