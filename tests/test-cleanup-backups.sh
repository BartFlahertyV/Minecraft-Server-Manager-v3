#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib-test.sh"
source "$(dirname "$0")/assert.sh"

bootstrap_test_env

"${MINECRAFT_BASE_DIR}/tools/create-server-config.sh" TestServer --activate >/dev/null

conf="${MINECRAFT_BASE_DIR}/config/servers/TestServer.conf"
python3 - "$conf" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
text = p.read_text()
text = text.replace('KEEP_HOURLY="24"', 'KEEP_HOURLY="2"')
p.write_text(text)
PY

for _ in 1 2 3 4; do
  "${MINECRAFT_BASE_DIR}/scripts/backup-server.sh" TestServer >/dev/null
  sleep 1
done

count_before="$(find "${MINECRAFT_BASE_DIR}/backups/local/TestServer" -maxdepth 1 -name '*.tar.gz' | wc -l)"
[[ "${count_before}" -ge 2 ]] || { echo "FAIL expected backups before cleanup"; exit 1; }

assert_exit_zero "${MINECRAFT_BASE_DIR}/tools/cleanup-backups.sh" TestServer

count_after="$(find "${MINECRAFT_BASE_DIR}/backups/local/TestServer" -maxdepth 1 -name '*.tar.gz' | wc -l)"
[[ "${count_after}" -le 2 ]] || { echo "FAIL cleanup did not prune backups"; exit 1; }

echo "PASS test-cleanup-backups"
