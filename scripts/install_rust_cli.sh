#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd "$(dirname "$0")/.." && pwd)
destination=${1:?Usage: scripts/install_rust_cli.sh /path/to/package/application}
bash "$project_root/scripts/build_rust_cli.sh"
mkdir -p "$destination/bin"
install -m755 "$project_root/build/cli/bin/qp" "$destination/bin/qp"
ln -sfn bin/qp "$destination/qp"
ln -sfn bin/qp "$destination/quietpaper-cli"
