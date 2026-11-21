#!/usr/bin/env bash
set -euo pipefail

# Script to build an AppImage for Quiet Paper from a Flutter release bundle
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUNDLE_DIR="${PROJECT_ROOT}/build/linux/x64/release/bundle"
APPDIR="${PROJECT_ROOT}/build/linux/AppDir"
OUTPUT_DIR="${PROJECT_ROOT}/build/linux/dist"

# Refuse incomplete bundles before packaging. No host-installed library fallback.
"${PROJECT_ROOT}/scripts/smoke_linux_rust_bundle.sh" "${BUNDLE_DIR}"

VERSION="${1:-}"
if [ -z "${VERSION}" ]; then
  VERSION=$(grep '^version:' "${PROJECT_ROOT}/pubspec.yaml" | awk '{print $2}' | cut -d'+' -f1)
fi

if [ ! -d "${BUNDLE_DIR}" ]; then
  echo "Error: Flutter release bundle not found at ${BUNDLE_DIR}"
  echo "Run 'flutter build linux --release' first."
  exit 1
fi

echo "==> Preparing AppDir at ${APPDIR}..."
rm -rf "${APPDIR}"
mkdir -p "${APPDIR}/usr/bin"
mkdir -p "${APPDIR}/usr/lib"
mkdir -p "${APPDIR}/usr/share/applications"
mkdir -p "${APPDIR}/usr/share/metainfo"
mkdir -p "${APPDIR}/usr/share/icons/hicolor/256x256/apps"
mkdir -p "${APPDIR}/usr/share/icons/hicolor/512x512/apps"
mkdir -p "${OUTPUT_DIR}"

# Copy release bundle
cp -a "${BUNDLE_DIR}"/* "${APPDIR}/usr/bin/"

# Build & include native CLI binary if bin/qp.dart exists
if [ -f "${PROJECT_ROOT}/bin/qp.dart" ]; then
  echo "==> Building native Quiet Paper CLI binary (qp)..."
  dart build cli -t "${PROJECT_ROOT}/bin/qp.dart" -o "${PROJECT_ROOT}/build/cli"
  cp -a "${PROJECT_ROOT}/build/cli/bundle/bin/qp" "${APPDIR}/usr/bin/qp"
  if [ -d "${PROJECT_ROOT}/build/cli/bundle/lib" ]; then
    cp -a "${PROJECT_ROOT}/build/cli/bundle/lib"/* "${APPDIR}/usr/lib/" 2>/dev/null || :
    cp -a "${PROJECT_ROOT}/build/cli/bundle/lib"/* "${APPDIR}/usr/bin/lib/" 2>/dev/null || :
  fi
  chmod +x "${APPDIR}/usr/bin/qp"
  ln -sf qp "${APPDIR}/usr/bin/quietpaper-cli"
fi

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
    curl -sLo "${TOOL_PATH}" "https://github.com/AppImage/appimagetool/releases/download/1.9.1/appimagetool-x86_64.AppImage"
    chmod +x "${TOOL_PATH}"
  fi
  # Official 1.9.1 release, pinned by immutable content digest.
  printf '%s  %s\n' 'ed4ce84f0d9caff66f50bcca6ff6f35aae54ce8135408b3fa33abfc3cb384eb0' "${TOOL_PATH}" | sha256sum --check
  APPIMAGETOOL="${TOOL_PATH}"
else
  APPIMAGETOOL="appimagetool"
fi

# Pin the embedded runtime too; appimagetool otherwise fetches moving continuous.
RUNTIME_PATH="${PROJECT_ROOT}/build/linux/appimage-runtime-20251108-x86_64"
if [ ! -f "${RUNTIME_PATH}" ]; then
  curl --fail --location --retry 3 "https://github.com/AppImage/type2-runtime/releases/download/20251108/runtime-x86_64" -o "${RUNTIME_PATH}"
fi
printf '%s  %s\n' '2fca8b443c92510f1483a883f60061ad09b46b978b2631c807cd873a47ec260d' "${RUNTIME_PATH}" | sha256sum --check

echo "==> Building AppImage..."
export APPIMAGE_EXTRACT_AND_RUN=1
ARCH=x86_64 "${APPIMAGETOOL}" --appimage-extract-and-run --runtime-file "${RUNTIME_PATH}" --mksquashfs-opt -processors --mksquashfs-opt "${QP_PACKAGING_JOBS:-2}" -n "${APPDIR}" "${OUTPUT_DIR}/Quiet_Paper-${VERSION}-x86_64.AppImage"
ln -sf "Quiet_Paper-${VERSION}-x86_64.AppImage" "${OUTPUT_DIR}/Quiet_Paper-x86_64.AppImage"
ln -sf "Quiet_Paper-${VERSION}-x86_64.AppImage" "${OUTPUT_DIR}/quiet-paper-${VERSION}-x86_64.AppImage"
echo "==> AppImage created at ${OUTPUT_DIR}/Quiet_Paper-${VERSION}-x86_64.AppImage"
