#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cargo build --locked --release -p quietpaper_cli --bin qp --jobs "${QP_CARGO_JOBS:-2}"
cli_target_dir="${CARGO_TARGET_DIR:-$PWD/target}"
mkdir -p build/cli/bin
cli_staged="$PWD/build/cli/bin/.qp.$$.tmp"
trap 'rm -f "$cli_staged"' EXIT
install -m755 "$cli_target_dir/release/qp" "$cli_staged"
mv -f "$cli_staged" build/cli/bin/qp
build/cli/bin/qp --version | grep -F '(Rust)'
