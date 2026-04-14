#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib-test.sh"
source "$(dirname "$0")/assert.sh"

bootstrap_test_env

"${MINECRAFT_BASE_DIR}/tools/create-server-config.sh" Broken --activate >/dev/null
rm -f "${MINECRAFT_BASE_DIR}/servers/Broken/startserver.sh"

if "${MINECRAFT_BASE_DIR}/tools/preflight.sh" start Broken >/tmp/preflight_fail.out 2>&1; then
  echo "FAIL preflight should have failed"
  exit 1
fi

grep -Eq "no valid launch path found|launch path" /tmp/preflight_fail.out || {
  echo "FAIL expected launch-path failure"
  cat /tmp/preflight_fail.out
  exit 1
}

echo "PASS test-preflight-failures"
