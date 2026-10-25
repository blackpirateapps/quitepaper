#!/usr/bin/env bash
set -euo pipefail

# Script to build a Debian package (.deb) for Quiet Paper from a Flutter release bundle
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUNDLE_DIR="${PROJECT_ROOT}/build/linux/x64/release/bundle"
OUTPUT_DIR="${PROJECT_ROOT}/build/linux/dist"
STAGING_DIR="${PROJECT_ROOT}/build/linux/deb_staging"

VERSION="${1:-}"
if [ -z "${VERSION}" ]; then
  VERSION=$(grep '^version:' "${PROJECT_ROOT}/pubspec.yaml" | awk '{print $2}' | cut -d'+' -f1)
fi

if [ ! -d "${BUNDLE_DIR}" ]; then
  echo "Error: Flutter release bundle not found at ${BUNDLE_DIR}"
  echo "Run 'flutter build linux --release' first."
  exit 1
fi

echo "==> Preparing Debian package staging directory at ${STAGING_DIR}..."
rm -rf "${STAGING_DIR}"
mkdir -p "${OUTPUT_DIR}"
mkdir -p "${STAGING_DIR}/DEBIAN"
mkdir -p "${STAGING_DIR}/opt/quitepaper"
mkdir -p "${STAGING_DIR}/usr/bin"
mkdir -p "${STAGING_DIR}/usr/share/applications"
mkdir -p "${STAGING_DIR}/usr/share/metainfo"
mkdir -p "${STAGING_DIR}/usr/share/icons/hicolor/256x256/apps"
mkdir -p "${STAGING_DIR}/usr/share/icons/hicolor/512x512/apps"

# Copy release bundle
cp -a "${BUNDLE_DIR}"/* "${STAGING_DIR}/opt/quitepaper/"
chmod +x "${STAGING_DIR}/opt/quitepaper/quitepaper"

# Symlink binary to /usr/bin/quitepaper
ln -sf /opt/quitepaper/quitepaper "${STAGING_DIR}/usr/bin/quitepaper"

# Copy desktop and metainfo
cp "${PROJECT_ROOT}/linux/com.blackpiratex.quietpaper.desktop" "${STAGING_DIR}/usr/share/applications/"
cp "${PROJECT_ROOT}/linux/com.blackpiratex.quietpaper.metainfo.xml" "${STAGING_DIR}/usr/share/metainfo/"

# Copy icons
cp "${PROJECT_ROOT}/linux/assets/icon.png" "${STAGING_DIR}/usr/share/icons/hicolor/256x256/apps/com.blackpiratex.quietpaper.png"
cp "${PROJECT_ROOT}/assets/icons/app_icon.png" "${STAGING_DIR}/usr/share/icons/hicolor/512x512/apps/com.blackpiratex.quietpaper.png"

# Calculate installed size in KB
INSTALLED_SIZE=$(du -sk "${STAGING_DIR}" | cut -f1)

# Generate control file
cat <<EOF > "${STAGING_DIR}/DEBIAN/control"
Package: quitepaper
Version: ${VERSION}
Section: utils
Priority: optional
Architecture: amd64
Maintainer: Black Pirate <dev@quitepaper.app>
Installed-Size: ${INSTALLED_SIZE}
Homepage: https://github.com/blackpirateapps/quitepaper
Depends: libc6 (>= 2.31), libgtk-3-0 (>= 3.24.0), libglib2.0-0 (>= 2.64.0), libsecret-1-0, liblzma5, libsqlite3-0, gstreamer1.0-plugins-base, gstreamer1.0-plugins-good
Description: Privacy-first, local-first encrypted notes and markdown journal
 Quiet Paper is an elegant, distraction-free markdown note-taking app and daily
 journal engineered with local-first, zero-knowledge encryption.
EOF

# Post-install script
cat <<'EOF' > "${STAGING_DIR}/DEBIAN/postinst"
#!/bin/sh
set -e
if [ -x /usr/bin/gtk-update-icon-cache ]; then
  /usr/bin/gtk-update-icon-cache -f -t /usr/share/icons/hicolor >/dev/null 2>&1 || true
fi
if [ -x /usr/bin/update-desktop-database ]; then
  /usr/bin/update-desktop-database >/dev/null 2>&1 || true
fi
EOF
chmod 755 "${STAGING_DIR}/DEBIAN/postinst"

# Post-remove script
cat <<'EOF' > "${STAGING_DIR}/DEBIAN/postrm"
#!/bin/sh
set -e
if [ -x /usr/bin/gtk-update-icon-cache ]; then
  /usr/bin/gtk-update-icon-cache -f -t /usr/share/icons/hicolor >/dev/null 2>&1 || true
fi
if [ -x /usr/bin/update-desktop-database ]; then
  /usr/bin/update-desktop-database >/dev/null 2>&1 || true
fi
EOF
chmod 755 "${STAGING_DIR}/DEBIAN/postrm"

echo "==> Building Debian package..."
DEB_NAME="quiet-paper-${VERSION}-amd64.deb"
dpkg-deb --build --root-owner-group "${STAGING_DIR}" "${OUTPUT_DIR}/${DEB_NAME}"
cp "${OUTPUT_DIR}/${DEB_NAME}" "${OUTPUT_DIR}/quietpaper_${VERSION}_amd64.deb"

echo "==> Debian package created at ${OUTPUT_DIR}/${DEB_NAME}"
