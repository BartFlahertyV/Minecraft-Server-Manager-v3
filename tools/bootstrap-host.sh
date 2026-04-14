\
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib.sh"

echo "Bootstrapping ${PLATFORM_NAME} ${PLATFORM_VERSION}"
echo "Base dir: ${BASE_DIR}"

if command -v apt-get >/dev/null 2>&1; then
  if [[ $EUID -eq 0 ]]; then
    APT="apt-get"
  else
    APT="sudo apt-get"
  fi
  ${APT} update
  ${APT} install -y tmux rsync tar coreutils python3 jq curl unzip zip
else
  warn "apt-get not found; install dependencies manually: tmux rsync tar python3 jq curl zip unzip"
fi

mkdir -p \
  "${SERVER_CONFIG_DIR}" \
  "${ARCHIVED_CONFIG_DIR}" \
  "${TEMPLATES_DIR}" \
  "${SERVERS_DIR}" \
  "${STATE_DIR}" \
  "${LOGS_DIR}" \
  "${EVENTS_DIR}" \
  "${RESTORE_DIR}" \
  "${TMP_DIR}" \
  "${CRASH_DIR}" \
  "${LOCAL_BACKUPS_DIR}" \
  "${BACKUP_MANIFESTS_DIR}" \
  "${ARCHIVE_SERVERS_DIR}" \
  "${ARCHIVE_BACKUPS_DIR}"

chmod +x "${SCRIPTS_DIR}"/* "${TOOLS_DIR}"/* "${TESTS_DIR}"/* || true

# Create placeholder templates that make the platform runnable even before real MC files are copied in.
mkdir -p "${TEMPLATES_DIR}/blank-neoforge" "${TEMPLATES_DIR}/atm10-base"

cat > "${TEMPLATES_DIR}/blank-neoforge/startserver.sh" <<'EOF'
#!/usr/bin/env bash
echo "Placeholder blank-neoforge template launched."
echo "Replace this template with real Minecraft server files."
while true; do
  sleep 60
done
EOF
chmod +x "${TEMPLATES_DIR}/blank-neoforge/startserver.sh"

cat > "${TEMPLATES_DIR}/atm10-base/startserver.sh" <<'EOF'
#!/usr/bin/env bash
echo "Placeholder ATM10 template launched."
echo "Replace this template with real ATM10 server files."
while true; do
  sleep 60
done
EOF
chmod +x "${TEMPLATES_DIR}/atm10-base/startserver.sh"

if [[ ! -f "${ACTIVE_SERVER_FILE}" ]]; then
  : > "${ACTIVE_SERVER_FILE}"
fi

echo "Bootstrap complete."
echo
echo "Next:"
echo "  ./tools/create-server-config.sh TestServer --template blank-neoforge --activate"
echo "  ./scripts/mcadmin doctor"
echo "  ./scripts/mcadmin switch TestServer --start"
