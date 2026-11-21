#!/usr/bin/env bash
# Install/run only in a disposable user installation and home; never reuse a vault.
set -euo pipefail
cd "$(dirname "$0")/.."
artifact=$(realpath "${1:?Flatpak bundle path}")
harness=$(realpath "${2:?Compiled tool/smoke_watched_import.dart executable}")
workspace=$(mktemp -d)
trap 'rm -r "$workspace"' EXIT
runtime_location=$(flatpak info --show-location org.gnome.Platform//50)
runtime_installation=${runtime_location%%/runtime/*}
mkdir -p "$workspace/home" "$workspace/data" "$workspace/config" "$workspace/cache"
export HOME="$workspace/home"
export XDG_DATA_HOME="$workspace/data"
export XDG_CONFIG_HOME="$workspace/config"
export XDG_CACHE_HOME="$workspace/cache"
export FLATPAK_USER_DIR="$workspace/installation"
export FLATPAK_SYSTEM_DIR="$runtime_installation"
# Prove isolation before installing any package with the application's real ID.
test -z "$(flatpak list --user --app --columns=application)"
flatpak install --user --noninteractive --assumeyes --no-deps "$artifact"
flatpak run --user --nosocket=wayland --nosocket=x11 --nosocket=fallback-x11 \
  --nofilesystem=host --nofilesystem=home --filesystem="$harness:ro" \
  --unset-env=LD_LIBRARY_PATH --command="$harness" \
  com.blackpiratex.quietpaper /app/bin/lib/libquietpaper_watched_import.so
flatpak run --user --nosocket=wayland --nosocket=x11 --nosocket=fallback-x11 \
  --nofilesystem=host --nofilesystem=home --unset-env=LD_LIBRARY_PATH \
  --command=qp com.blackpiratex.quietpaper --version
echo 'PASS: disposable installed Flatpak loads the Rust engine and CLI without a real user vault'
