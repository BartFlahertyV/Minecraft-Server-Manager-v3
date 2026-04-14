\
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib.sh"

SERVER="${1:-}"
EVENT="${2:-}"
shift 2 || true

[[ -n "${SERVER}" ]] || die "usage: emit-event.sh <server> <event> [key=value ...]"
[[ -n "${EVENT}" ]] || die "event is required"
sanitize_server_name "${SERVER}"

EVENT_FILE="${EVENTS_DIR}/${SERVER}.jsonl"
mkdir -p "$(dirname "${EVENT_FILE}")"

python3 - "$EVENT_FILE" "$SERVER" "$EVENT" "$@" <<'PY'
import json, sys, datetime
event_file = sys.argv[1]
server = sys.argv[2]
event = sys.argv[3]
pairs = sys.argv[4:]
payload = {
    "ts": datetime.datetime.now().astimezone().isoformat(),
    "server": server,
    "event": event,
}
for p in pairs:
    if "=" in p:
        k, v = p.split("=", 1)
        payload[k] = v
with open(event_file, "a", encoding="utf-8") as fh:
    fh.write(json.dumps(payload, ensure_ascii=False) + "\n")
print(json.dumps(payload, ensure_ascii=False))
PY
