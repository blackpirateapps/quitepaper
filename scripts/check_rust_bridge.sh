#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
codegen=${FRB_CODEGEN:-flutter_rust_bridge_codegen}
test "$($codegen --version)" = 'flutter_rust_bridge_codegen 2.12.0'
test -f Cargo.lock
# Compare with BEFORE generation, including uncommitted code, without modifying HEAD.
snapshot=$(mktemp -d)
trap 'rm -r "$snapshot"' EXIT
cp -a lib/features/watched_import/native "$snapshot/native"
cp rust/quietpaper_watched_import/src/frb_generated.rs "$snapshot/frb_generated.rs"
"$codegen" generate
diff -ru "$snapshot/native" lib/features/watched_import/native
diff -u "$snapshot/frb_generated.rs" rust/quietpaper_watched_import/src/frb_generated.rs
