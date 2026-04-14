#!/usr/bin/env bash
set -euo pipefail

TEST_ROOT="$(mktemp -d)"
export MINECRAFT_BASE_DIR="${TEST_ROOT}/minecraft"
export SYSTEMD_DIR="${TEST_ROOT}/systemd"
export TMUX_TMPDIR="${TEST_ROOT}/tmux"
export MCADMIN_TEST_MODE="1"
export TMUX_SOCKET_NAME="mcadmin-test-$$"

mkdir -p "${MINECRAFT_BASE_DIR}" "${SYSTEMD_DIR}" "${TMUX_TMPDIR}"

rsync -a "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/" "${MINECRAFT_BASE_DIR}/"

chmod +x "${MINECRAFT_BASE_DIR}/scripts/"* \
         "${MINECRAFT_BASE_DIR}/tools/"* \
         "${MINECRAFT_BASE_DIR}/tests/"* || true

cleanup_test_env() {
  tmux -L "${TMUX_SOCKET_NAME}" kill-server 2>/dev/null || true
  rm -rf "${TEST_ROOT}"
}

bootstrap_test_env() {
  trap cleanup_test_env EXIT
  "${MINECRAFT_BASE_DIR}/tools/bootstrap-host.sh" >/dev/null 2>&1 || true
}
