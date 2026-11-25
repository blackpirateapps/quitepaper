#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

cargo fmt -p quietpaper_cli -- --check
cargo clippy --locked -p quietpaper_cli --all-targets -- -D warnings
cargo test --locked -p quietpaper_cli
cargo build --locked -p quietpaper_cli
flutter analyze
QP_RUST_CLI_BIN="$PWD/target/debug/qp" flutter test --no-pub test/cli
