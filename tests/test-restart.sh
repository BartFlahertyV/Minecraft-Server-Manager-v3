\
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib-test.sh"
source "$(dirname "$0")/assert.sh"
bootstrap_test_env
"${MINECRAFT_BASE_DIR}/tools/create-server-config.sh" TestServer --activate >/dev/null
"${MINECRAFT_BASE_DIR}/scripts/run-server.sh" TestServer >/dev/null
assert_exit_zero "${MINECRAFT_BASE_DIR}/tools/scheduled-restart-cancel.sh" TestServer
echo "PASS test-restart"
