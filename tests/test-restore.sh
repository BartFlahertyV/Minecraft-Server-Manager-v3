\
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib-test.sh"
source "$(dirname "$0")/assert.sh"
bootstrap_test_env
"${MINECRAFT_BASE_DIR}/tools/create-server-config.sh" TestServer --activate >/dev/null
"${MINECRAFT_BASE_DIR}/scripts/backup-server.sh" TestServer >/dev/null
assert_exit_zero "${MINECRAFT_BASE_DIR}/scripts/restore-server.sh" TestServer latest --dry-run
echo "PASS test-restore"
