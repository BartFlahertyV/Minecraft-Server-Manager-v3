#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib-test.sh"
source "$(dirname "$0")/assert.sh"

bootstrap_test_env

# Create a server with non-default ports so we can verify sync clearly.
"${MINECRAFT_BASE_DIR}/tools/create-server-config.sh" SyncServer \
  --template blank-neoforge \
  --game-port 25566 \
  --rcon-port 25576 \
  --rcon-password SyncPass123 \
  --activate >/dev/null

PROPS="${MINECRAFT_BASE_DIR}/servers/SyncServer/server.properties"

# Seed server.properties with wrong values to prove sync overwrites them.
cat > "${PROPS}" <<'PROPS_EOF'
server-port=25565
enable-rcon=false
rcon.port=25575
rcon.password=wrongpass
motd=Test Server
PROPS_EOF

assert_file_exists "${PROPS}"

# Run the sync tool directly.
assert_exit_zero "${MINECRAFT_BASE_DIR}/tools/sync-server-properties.sh" SyncServer

assert_contains "server-port=25566" "${PROPS}"
assert_contains "enable-rcon=true" "${PROPS}"
assert_contains "rcon.port=25576" "${PROPS}"
assert_contains "rcon.password=SyncPass123" "${PROPS}"
assert_contains "motd=Test Server" "${PROPS}"

# Change config again and verify sync updates existing keys.
CONF="${MINECRAFT_BASE_DIR}/config/servers/SyncServer.conf"
python3 - "${CONF}" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
text = p.read_text()
text = text.replace('GAME_PORT="25566"', 'GAME_PORT="25567"')
text = text.replace('RCON_PORT="25576"', 'RCON_PORT="25577"')
text = text.replace('RCON_PASSWORD="SyncPass123"', 'RCON_PASSWORD="NewerPass456"')
p.write_text(text)
PY

assert_exit_zero "${MINECRAFT_BASE_DIR}/tools/sync-server-properties.sh" SyncServer

assert_contains "server-port=25567" "${PROPS}"
assert_contains "rcon.port=25577" "${PROPS}"
assert_contains "rcon.password=NewerPass456" "${PROPS}"

echo "PASS test-server-properties-sync"
