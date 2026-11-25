#!/usr/bin/env bash
# Official v2.12.0 x86_64-musl release, independently pinned SHA256.
set -euo pipefail
version=2.12.0
expected=e6bb14697f28f10907f01cd4a64defc71e31139d1f6b2400b509524c6c10e898
output=${1:?Usage: scripts/install_frb_codegen.sh /destination/bin}
mkdir -p "$output"
temporary=$(mktemp -d)
trap 'rm -r "$temporary"' EXIT
curl --fail --location --retry 3 "https://github.com/fzyzcjy/flutter_rust_bridge/releases/download/v${version}/flutter_rust_bridge_codegen-x86_64-unknown-linux-musl-v${version}.tgz" -o "$temporary/frb.tgz"
printf '%s  %s\n' "$expected" "$temporary/frb.tgz" | sha256sum --check
tar -xzf "$temporary/frb.tgz" -C "$temporary"
install -m755 "$temporary/flutter_rust_bridge_codegen" "$output/flutter_rust_bridge_codegen"
"$output/flutter_rust_bridge_codegen" --version
