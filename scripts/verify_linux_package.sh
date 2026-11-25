#!/usr/bin/env bash
# Extract/load only, never install over an existing user's notebook/application.
set -euo pipefail
cd "$(dirname "$0")/.."
format=${1:?format: deb, rpm, appimage, tarball}
artifact=$(realpath "${2:?artifact path}")
workspace=$(mktemp -d)
trap 'rm -r "$workspace"' EXIT
case "$format" in
  deb)
    dpkg-deb --extract "$artifact" "$workspace"
    bundle="$workspace/opt/quitepaper"
    ;;
  rpm)
    (cd "$workspace" && rpm2cpio "$artifact" | cpio -idm --quiet --no-absolute-filenames)
    bundle="$workspace/opt/quitepaper"
    ;;
  appimage)
    (cd "$workspace" && "$artifact" --appimage-extract >/dev/null)
    bundle="$workspace/squashfs-root/usr/bin"
    ;;
  tarball)
    tar --extract --gzip --file "$artifact" --directory "$workspace" --no-same-owner
    bundle="$workspace/quitepaper"
    ;;
  *) echo 'Unsupported package format' >&2; exit 64;;
esac
scripts/smoke_linux_rust_bundle.sh "$bundle"
test -f "$bundle/data/flutter_assets/AssetManifest.bin"
if [ -x "$bundle/bin/qp" ]; then
  scripts/smoke_rust_cli.sh "$bundle/bin/qp"
else
  scripts/smoke_rust_cli.sh "$bundle/qp"
fi
echo "PASS: $format package includes the Flutter app, CLI and loadable Rust engine"
