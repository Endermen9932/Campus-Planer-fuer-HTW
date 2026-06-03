#!/usr/bin/env bash
# Baut ein .deb aus dem Flutter-Linux-Release-Bundle.
#
# Voraussetzung: vorher `cd app && flutter build linux --release` ausführen.
# Aufruf (vom Repo-Root):  bash packaging/linux/build_deb.sh [VERSION] [ARCH]
set -euo pipefail

PKG_NAME="htw-center"      # Debian-Paketname (Bindestrich)
BINARY_NAME="htw_center"   # Flutter-Binary aus dem Bundle (= pubspec-Name)
VERSION="${1:-0.1.0}"
ARCH="${2:-amd64}"

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUNDLE_DIR="$REPO_ROOT/app/build/linux/x64/release/bundle"
PKG_ROOT="$REPO_ROOT/build/deb/${PKG_NAME}_${VERSION}_${ARCH}"
INSTALL_DIR="/opt/${PKG_NAME}"

if [ ! -d "$BUNDLE_DIR" ]; then
  echo "FEHLER: Bundle nicht gefunden unter $BUNDLE_DIR" >&2
  echo "Bitte zuerst: cd app && flutter build linux --release" >&2
  exit 1
fi

echo "Baue ${PKG_NAME} ${VERSION} (${ARCH}) ..."
rm -rf "$PKG_ROOT"
mkdir -p \
  "$PKG_ROOT/DEBIAN" \
  "$PKG_ROOT${INSTALL_DIR}" \
  "$PKG_ROOT/usr/bin" \
  "$PKG_ROOT/usr/share/applications"

# Bundle nach /opt/htw-center kopieren
cp -r "$BUNDLE_DIR"/. "$PKG_ROOT${INSTALL_DIR}/"

# control-Datei aus Template
sed -e "s/@VERSION@/${VERSION}/" -e "s/@ARCH@/${ARCH}/" \
  "$REPO_ROOT/packaging/linux/control" > "$PKG_ROOT/DEBIAN/control"

# Launcher in PATH (zeigt auf das Bundle-Binary)
ln -sf "${INSTALL_DIR}/${BINARY_NAME}" "$PKG_ROOT/usr/bin/${PKG_NAME}"

# Desktop-Eintrag
cp "$REPO_ROOT/packaging/linux/${PKG_NAME}.desktop" \
  "$PKG_ROOT/usr/share/applications/"

dpkg-deb --build --root-owner-group "$PKG_ROOT"
echo "Fertig: ${PKG_ROOT}.deb"
