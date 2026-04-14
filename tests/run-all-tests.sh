#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for t in \
  test-sandbox-isolation.sh \
  test-config.sh \
  test-server-properties-sync.sh \
  test-runtime.sh \
  test-backup.sh \
  test-verify-backup.sh \
  test-cleanup-backups.sh \
  test-restore.sh \
  test-switch.sh \
  test-restart.sh \
  test-health.sh \
  test-clone.sh \
  test-archive.sh \
  test-delete.sh \
  test-crash-lock.sh \
  test-preflight-failures.sh
do
  echo "==> running ${t}"
  bash "${DIR}/${t}"
done

echo "ALL TESTS PASSED"
