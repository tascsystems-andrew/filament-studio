#!/bin/bash
# Filament Studio — macOS .app builder.
#
# Compiles AppMain.swift with swiftc (Xcode Command Line Tools), assembles a
# proper .app bundle in ./build/, and (optionally) installs it to ~/Applications.
#
# Usage:
#     ./build.sh              # build only
#     ./build.sh --install    # build + copy to ~/Applications
#     ./build.sh --run        # build + launch

set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Filament Studio"
BUNDLE_NAME="${APP_NAME}.app"
BUILD_DIR="build"
APP_DIR="${BUILD_DIR}/${BUNDLE_NAME}"
BIN_PATH="${APP_DIR}/Contents/MacOS/${APP_NAME}"

rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

echo "→ compiling AppMain.swift"
swiftc -O AppMain.swift -o "${BIN_PATH}"

echo "→ writing Info.plist"
cp Info.plist.template "${APP_DIR}/Contents/Info.plist"

echo "→ ad-hoc code sign (so Gatekeeper lets us run it locally)"
codesign --force --deep --sign - "${APP_DIR}" 2>/dev/null || true

echo "→ built: ${APP_DIR}"

INSTALL=0
RUN=0
for arg in "$@"; do
    case "$arg" in
        --install) INSTALL=1 ;;
        --run)     INSTALL=1; RUN=1 ;;
    esac
done

if [ "$INSTALL" = "1" ]; then
    DEST="${HOME}/Applications/${BUNDLE_NAME}"
    mkdir -p "${HOME}/Applications"
    rm -rf "${DEST}"
    cp -R "${APP_DIR}" "${DEST}"
    echo "→ installed: ${DEST}"

    # Copy index.html next to the .app on first install so the app finds it.
    SIBLING="${HOME}/Applications/index.html"
    if [ ! -f "${SIBLING}" ]; then
        ln -s "$(pwd)/../index.html" "${SIBLING}"
        echo "→ symlinked index.html into ~/Applications (live edits reflect on next launch)"
    fi
fi

if [ "$RUN" = "1" ]; then
    echo "→ launching"
    open "${HOME}/Applications/${BUNDLE_NAME}"
fi
