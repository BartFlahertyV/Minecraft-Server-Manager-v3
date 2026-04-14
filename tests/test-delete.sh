#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib-test.sh"
source "$(dirname "$0")/assert.sh"

bootstrap_test_env

"${MINECRAFT_BASE_DIR}/tools/create-server-config.sh" DeleteMe --activate >/dev/null

assert_file_exists "${MINECRAFT_BASE_DIR}/config/servers/DeleteMe.conf"
assert_dir_exists "${MINECRAFT_BASE_DIR}/servers/DeleteMe"

assert_exit_zero "${MINECRAFT_BASE_DIR}/tools/delete-server.sh" DeleteMe --force

[[ ! -f "${MINECRAFT_BASE_DIR}/config/servers/DeleteMe.conf" ]] || { echo "FAIL config still exists"; exit 1; }
[[ ! -d "${MINECRAFT_BASE_DIR}/servers/DeleteMe" ]] || { echo "FAIL server dir still exists"; exit 1; }

echo "PASS test-delete"
