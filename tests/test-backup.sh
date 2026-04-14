\
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib-test.sh"
source "$(dirname "$0")/assert.sh"
bootstrap_test_env
"${MINECRAFT_BASE_DIR}/tools/create-server-config.sh" TestServer --activate >/dev/null
assert_exit_zero "${MINECRAFT_BASE_DIR}/scripts/backup-server.sh" TestServer
latest="$(ls -1 "${MINECRAFT_BASE_DIR}/backups/local/TestServer/"*.tar.gz | head -n1)"
assert_file_exists "${latest}"
echo "PASS test-backup"
