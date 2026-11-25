#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
bundle=${1:?Usage: scripts/smoke_linux_rust_bundle.sh /path/to/bundle}
library="$bundle/lib/libquietpaper_watched_import.so"
test -f "$library"
readelf -h "$library" | grep -E 'Class:|Machine:'
if ldd "$library" | grep 'not found'; then
  echo 'Unresolved native dependencies' >&2
  exit 1
fi
# Deliberately remove developer loader overrides. FRB uses this absolute bundle path.
env -u LD_LIBRARY_PATH dart run tool/smoke_watched_import.dart "$library"
