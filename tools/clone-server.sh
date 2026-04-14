\
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib.sh"

SRC="${1:-}"
DST="${2:-}"
[[ -n "${SRC}" && -n "${DST}" ]] || die "usage: clone-server.sh <src> <dst>"
sanitize_server_name "${SRC}"
sanitize_server_name "${DST}"

load_server "${SRC}"
src_game_port="${GAME_PORT}"
src_rcon_port="${RCON_PORT}"
src_template="${TEMPLATE_NAME}"

src_dir="${SERVER_DIR}"
dst_conf="$(server_conf_path "${DST}")"
[[ ! -f "${dst_conf}" ]] || die "destination config already exists: ${dst_conf}"
dst_dir="${SERVERS_DIR}/${DST}"
[[ ! -e "${dst_dir}" ]] || die "destination dir already exists: ${dst_dir}"

new_game_port=$(( src_game_port + 1 ))
new_rcon_port=$(( src_rcon_port + 1 ))
"${SCRIPT_DIR}/create-server-config.sh" "${DST}" --display-name "${DISPLAY_NAME} clone" --template "${src_template}" --game-port "${new_game_port}" --rcon-port "${new_rcon_port}"
rsync -a --exclude 'logs' --exclude 'crash-reports' --exclude 'debug' "${src_dir}/" "${dst_dir}/"

echo "Cloned ${SRC} -> ${DST}"
