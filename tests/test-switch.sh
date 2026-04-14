#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib-test.sh"
source "$(dirname "$0")/assert.sh"

bootstrap_test_env

"${MINECRAFT_BASE_DIR}/tools/create-server-config.sh" One >/dev/null
"${MINECRAFT_BASE_DIR}/tools/create-server-config.sh" Two >/dev/null

"${MINECRAFT_BASE_DIR}/scripts/switch-server.sh" One

assert_file_exists "${MINECRAFT_BASE_DIR}/active_server.txt"
assert_contains "One" "${MINECRAFT_BASE_DIR}/active_server.txt"

echo "PASS test-switch"
