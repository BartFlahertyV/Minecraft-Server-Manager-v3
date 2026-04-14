#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib-test.sh"
source "$(dirname "$0")/assert.sh"

bootstrap_test_env

"${MINECRAFT_BASE_DIR}/tools/create-server-config.sh" Crashy --activate >/dev/null

cat > "${MINECRAFT_BASE_DIR}/servers/Crashy/startserver.sh" <<'SH'
#!/usr/bin/env bash
echo "crashing immediately"
exit 1
SH
chmod +x "${MINECRAFT_BASE_DIR}/servers/Crashy/startserver.sh"

conf="${MINECRAFT_BASE_DIR}/config/servers/Crashy.conf"
python3 - "$conf" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
text = p.read_text()
text = text.replace('CRASH_LOCK_THRESHOLD="3"', 'CRASH_LOCK_THRESHOLD="2"')
text = text.replace('CRASH_RESTART_BACKOFF_SECONDS="15"', 'CRASH_RESTART_BACKOFF_SECONDS="1"')
p.write_text(text)
PY

"${MINECRAFT_BASE_DIR}/scripts/run-server.sh" Crashy || true
sleep 5

assert_file_exists "${MINECRAFT_BASE_DIR}/runtime/state/Crashy/lock.status"
assert_contains "LOCKED=yes" "${MINECRAFT_BASE_DIR}/runtime/state/Crashy/lock.status"

"${MINECRAFT_BASE_DIR}/tools/clear-crash-lock.sh" Crashy
assert_contains "LOCKED=no" "${MINECRAFT_BASE_DIR}/runtime/state/Crashy/lock.status"

echo "PASS test-crash-lock"
