#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib-test.sh"
source "$(dirname "$0")/assert.sh"

bootstrap_test_env

"${MINECRAFT_BASE_DIR}/tools/create-server-config.sh" ArchiveMe --activate >/dev/null
echo "data" > "${MINECRAFT_BASE_DIR}/servers/ArchiveMe/test.txt"

assert_exit_zero "${MINECRAFT_BASE_DIR}/tools/archive-server.sh" ArchiveMe

archive_count="$(find "${MINECRAFT_BASE_DIR}/archives/servers" -maxdepth 1 -name 'ArchiveMe-*.tar.gz' | wc -l)"
[[ "${archive_count}" -ge 1 ]] || { echo "FAIL archive not created"; exit 1; }

archived_conf_count="$(find "${MINECRAFT_BASE_DIR}/config/archived" -maxdepth 1 -name 'ArchiveMe-*.conf' | wc -l)"
[[ "${archived_conf_count}" -ge 1 ]] || { echo "FAIL archived config not created"; exit 1; }

echo "PASS test-archive"
