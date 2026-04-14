\
#!/usr/bin/env bash
set -euo pipefail

assert_file_exists() { [[ -f "$1" ]] || { echo "FAIL missing file: $1"; exit 1; }; }
assert_dir_exists() { [[ -d "$1" ]] || { echo "FAIL missing dir: $1"; exit 1; }; }
assert_contains() { grep -q -- "$1" "$2" || { echo "FAIL '$1' not in $2"; exit 1; }; }
assert_exit_zero() { "$@" || { echo "FAIL command failed: $*"; exit 1; }; }
