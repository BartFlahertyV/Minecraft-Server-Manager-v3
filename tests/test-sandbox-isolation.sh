#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib-test.sh"
source "$(dirname "$0")/assert.sh"

bootstrap_test_env

echo "Sandbox variables:"
echo "  TEST_ROOT=${TEST_ROOT}"
echo "  MINECRAFT_BASE_DIR=${MINECRAFT_BASE_DIR}"
echo "  SYSTEMD_DIR=${SYSTEMD_DIR}"
echo "  TMUX_TMPDIR=${TMUX_TMPDIR}"
echo "  TMUX_SOCKET_NAME=${TMUX_SOCKET_NAME}"
echo "  MCADMIN_TEST_MODE=${MCADMIN_TEST_MODE:-}"

# 1) Assert sandbox env vars are under /tmp and set correctly
[[ -n "${TEST_ROOT:-}" ]] || { echo "FAIL TEST_ROOT not set"; exit 1; }
[[ "${TEST_ROOT}" == /tmp/* ]] || { echo "FAIL TEST_ROOT is not under /tmp"; exit 1; }

[[ -n "${MINECRAFT_BASE_DIR:-}" ]] || { echo "FAIL MINECRAFT_BASE_DIR not set"; exit 1; }
[[ "${MINECRAFT_BASE_DIR}" == /tmp/* ]] || { echo "FAIL MINECRAFT_BASE_DIR is not under /tmp"; exit 1; }

[[ -n "${SYSTEMD_DIR:-}" ]] || { echo "FAIL SYSTEMD_DIR not set"; exit 1; }
[[ "${SYSTEMD_DIR}" == /tmp/* ]] || { echo "FAIL SYSTEMD_DIR is not under /tmp"; exit 1; }
[[ "${SYSTEMD_DIR}" != "/etc/systemd/system" ]] || { echo "FAIL SYSTEMD_DIR points to real systemd"; exit 1; }

[[ -n "${TMUX_TMPDIR:-}" ]] || { echo "FAIL TMUX_TMPDIR not set"; exit 1; }
[[ "${TMUX_TMPDIR}" == /tmp/* ]] || { echo "FAIL TMUX_TMPDIR is not under /tmp"; exit 1; }

[[ "${MCADMIN_TEST_MODE:-}" == "1" ]] || { echo "FAIL MCADMIN_TEST_MODE is not 1"; exit 1; }
[[ -n "${TMUX_SOCKET_NAME:-}" ]] || { echo "FAIL TMUX_SOCKET_NAME not set"; exit 1; }

# 2) Create a sandbox server and switch to it, which should write unit files into sandbox SYSTEMD_DIR
"${MINECRAFT_BASE_DIR}/tools/create-server-config.sh" Sandboxed --activate >/dev/null
"${MINECRAFT_BASE_DIR}/scripts/switch-server.sh" Sandboxed >/dev/null

# 3) Confirm unit files exist in sandbox SYSTEMD_DIR
assert_file_exists "${SYSTEMD_DIR}/minecraft-Sandboxed.service"
assert_file_exists "${SYSTEMD_DIR}/minecraft-Sandboxed-backup.service"
assert_file_exists "${SYSTEMD_DIR}/minecraft-Sandboxed-backup.timer"
assert_file_exists "${SYSTEMD_DIR}/minecraft-Sandboxed-scheduled-restart.service"
assert_file_exists "${SYSTEMD_DIR}/minecraft-Sandboxed-scheduled-restart.timer"

# 4) Confirm the real systemd dir was not used for this test server
if [[ -e "/etc/systemd/system/minecraft-Sandboxed.service" ]]; then
  echo "FAIL real /etc/systemd/system was modified by sandbox test"
  exit 1
fi

# 5) Confirm default tmux server does not contain the sandbox session
if tmux ls 2>/dev/null | grep -q "mc-Sandboxed"; then
  echo "FAIL sandbox session leaked into default tmux server"
  exit 1
fi

# 6) Confirm sandbox tmux server can be used independently
"${MINECRAFT_BASE_DIR}/scripts/run-server.sh" Sandboxed >/dev/null
sleep 1

tmux -L "${TMUX_SOCKET_NAME}" ls 2>/dev/null | grep -q "mc-Sandboxed" || {
  echo "FAIL sandbox tmux session was not created in sandbox tmux server"
  exit 1
}

"${MINECRAFT_BASE_DIR}/scripts/stop-server.sh" Sandboxed >/dev/null || true

echo "PASS test-sandbox-isolation"
