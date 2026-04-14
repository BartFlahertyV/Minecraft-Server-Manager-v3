#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib-test.sh"
source "$(dirname "$0")/assert.sh"

bootstrap_test_env

"${MINECRAFT_BASE_DIR}/tools/create-server-config.sh" SourceServer --activate >/dev/null
mkdir -p "${MINECRAFT_BASE_DIR}/servers/SourceServer/world"
echo "hello" > "${MINECRAFT_BASE_DIR}/servers/SourceServer/world/test.txt"

assert_exit_zero "${MINECRAFT_BASE_DIR}/tools/clone-server.sh" SourceServer CloneServer

assert_file_exists "${MINECRAFT_BASE_DIR}/config/servers/CloneServer.conf"
assert_file_exists "${MINECRAFT_BASE_DIR}/servers/CloneServer/world/test.txt"

echo "PASS test-clone"
