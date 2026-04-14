\
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib-test.sh"
source "$(dirname "$0")/assert.sh"
bootstrap_test_env
assert_exit_zero "${MINECRAFT_BASE_DIR}/tools/create-server-config.sh" TestServer --activate
assert_file_exists "${MINECRAFT_BASE_DIR}/config/servers/TestServer.conf"
echo "PASS test-config"
