#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib-test.sh"
source "$(dirname "$0")/assert.sh"

bootstrap_test_env

"${MINECRAFT_BASE_DIR}/tools/create-server-config.sh" TestServer --activate >/dev/null

"${MINECRAFT_BASE_DIR}/scripts/run-server.sh" TestServer
sleep 1

assert_file_exists "${MINECRAFT_BASE_DIR}/runtime/state/TestServer/run.status"
assert_contains "STATE=RUNNING" "${MINECRAFT_BASE_DIR}/runtime/state/TestServer/run.status"

"${MINECRAFT_BASE_DIR}/scripts/stop-server.sh" TestServer

assert_file_exists "${MINECRAFT_BASE_DIR}/runtime/state/TestServer/run.status"
assert_contains "STATE=STOPPED" "${MINECRAFT_BASE_DIR}/runtime/state/TestServer/run.status"

echo "PASS test-runtime"
