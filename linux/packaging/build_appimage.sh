#!/usr/bin/env bash
set -euo pipefail

# Script to build an AppImage for Quiet Paper from a Flutter release bundle
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUNDLE_DIR="${PROJECT_ROOT}/build/linux/x64/release/bundle"
APPDIR="${PROJECT_ROOT}/build/linux/AppDir"
OUTPUT_DIR="${PROJECT_ROOT}/build/linux/dist"

if [ ! -d "${BUNDLE_DIR}" ]; then
  echo "Error: Flutter release bundle not found at ${BUNDLE_DIR}"
  echo "Run 'flutter build linux --release' first."
  exit 1
fi

echo "==> Preparing AppDir at ${APPDIR}..."
rm -rf "${APPDIR}" "${OUTPUT_DIR}"
mkdir -p "${APPDIR}/usr/bin"
mkdir -p "${APPDIR}/usr/lib"
mkdir -p "${APPDIR}/usr/share/applications"
mkdir -p "${APPDIR}/usr/share/metainfo"
mkdir -p "${APPDIR}/usr/share/icons/hicolor/256x256/apps"
mkdir -p "${APPDIR}/usr/share/icons/hicolor/512x512/apps"
mkdir -p "${OUTPUT_DIR}"

# Copy release bundle
cp -a "${BUNDLE_DIR}"/* "${APPDIR}/usr/bin/"

# Copy metadata & desktop entries
cp "${PROJECT_ROOT}/linux/com.blackpiratex.quietpaper.desktop" "${APPDIR}/usr/share/applications/"
cp "${PROJECT_ROOT}/linux/com.blackpiratex.quietpaper.desktop" "${APPDIR}/"
cp "${PROJECT_ROOT}/linux/com.blackpiratex.quietpaper.metainfo.xml" "${APPDIR}/usr/share/metainfo/"
cp "${PROJECT_ROOT}/linux/assets/icon.png" "${APPDIR}/usr/share/icons/hicolor/256x256/apps/com.blackpiratex.quietpaper.png"
cp "${PROJECT_ROOT}/assets/icons/app_icon.png" "${APPDIR}/usr/share/icons/hicolor/512x512/apps/com.blackpiratex.quietpaper.png"
cp "${PROJECT_ROOT}/assets/icons/app_icon.png" "${APPDIR}/com.blackpiratex.quietpaper.png"
ln -sf com.blackpiratex.quietpaper.png "${APPDIR}/.DirIcon"

# Create AppRun entrypoint
cat <<'EOF' > "${APPDIR}/AppRun"
#!/bin/sh
SELF=$(readlink -f "$0")
HERE=${SELF%/*}
export PATH="${HERE}/usr/bin:${PATH}"
export LD_LIBRARY_PATH="${HERE}/usr/lib:${HERE}/usr/bin/lib:${LD_LIBRARY_PATH}"
exec "${HERE}/usr/bin/quitepaper" "$@"
EOF
chmod +x "${APPDIR}/AppRun"

# Download appimagetool if not available
if ! command -v appimagetool &> /dev/null; then
  TOOL_PATH="${PROJECT_ROOT}/build/linux/appimagetool"
  if [ ! -f "${TOOL_PATH}" ]; then
    echo "==> Downloading appimagetool..."
    curl -sLo "${TOOL_PATH}" "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"
    chmod +x "${TOOL_PATH}"
  fi
  APPIMAGETOOL="${TOOL_PATH}"
else
  APPIMAGETOOL="appimagetool"
fi

echo "==> Building AppImage..."
ARCH=x86_64 "${APPIMAGETOOL}" --appimage-extract-and-run "${APPDIR}" "${OUTPUT_DIR}/Quiet_Paper-x86_64.AppImage"
echo "==> AppImage created at ${OUTPUT_DIR}/Quiet_Paper-x86_64.AppImage"
