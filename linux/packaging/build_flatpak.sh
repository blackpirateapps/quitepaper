#!/usr/bin/env bash
set -euo pipefail

# Script to build a Flatpak bundle for Quiet Paper from a Flutter release bundle
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUNDLE_DIR="${PROJECT_ROOT}/build/linux/x64/release/bundle"
PACKAGING_DIR="${PROJECT_ROOT}/linux/packaging"
STAGING_DIR="${PACKAGING_DIR}/flatpak-staging"
OUTPUT_DIR="${PROJECT_ROOT}/build/linux/dist"

VERSION="${1:-}"
if [ -z "${VERSION}" ]; then
  VERSION=$(grep '^version:' "${PROJECT_ROOT}/pubspec.yaml" | awk '{print $2}' | cut -d'+' -f1)
fi

if [ ! -d "${BUNDLE_DIR}" ]; then
  echo "Error: Flutter release bundle not found at ${BUNDLE_DIR}"
  echo "Run 'flutter build linux --release' first."
  exit 1
fi

echo "==> Preparing Flatpak staging directory at ${STAGING_DIR}..."
rm -rf "${STAGING_DIR}"
mkdir -p "${OUTPUT_DIR}"
mkdir -p "${STAGING_DIR}/bundle"

# Copy release bundle and metadata assets
cp -a "${BUNDLE_DIR}"/* "${STAGING_DIR}/bundle/"
cp "${PROJECT_ROOT}/linux/com.blackpiratex.quietpaper.desktop" "${STAGING_DIR}/"
cp "${PROJECT_ROOT}/linux/com.blackpiratex.quietpaper.metainfo.xml" "${STAGING_DIR}/"
cp "${PROJECT_ROOT}/linux/assets/icon.png" "${STAGING_DIR}/icon_256.png"
cp "${PROJECT_ROOT}/assets/icons/app_icon.png" "${STAGING_DIR}/icon_512.png"

if ! command -v flatpak-builder &>/dev/null; then
  echo "Flatpak staging files prepared at ${STAGING_DIR}."
  echo "Note: 'flatpak-builder' not found locally. Use GitHub Actions container or install flatpak-builder to compile the bundle."
  exit 0
fi

echo "==> Compiling Flatpak bundle..."
REPO_DIR="${PROJECT_ROOT}/build/linux/flatpak-repo"
BUILD_DIR="${PROJECT_ROOT}/build/linux/flatpak-build"
rm -rf "${BUILD_DIR}"

flatpak-builder --force-clean --repo="${REPO_DIR}" "${BUILD_DIR}" "${PACKAGING_DIR}/com.blackpiratex.quietpaper.yml"
flatpak build-bundle "${REPO_DIR}" "${OUTPUT_DIR}/quiet-paper-${VERSION}-x86_64.flatpak" com.blackpiratex.quietpaper

echo "==> Flatpak bundle created at ${OUTPUT_DIR}/quiet-paper-${VERSION}-x86_64.flatpak"
