#!/bin/bash
# Filament Studio — macOS .app builder.
#
# Compiles AppMain.swift with swiftc, assembles a proper .app bundle in ./build/,
# and optionally embeds index.html, signs with Developer ID, notarises with Apple,
# and stapes the notarisation ticket for Gatekeeper-clean distribution.
#
# Usage:
#     ./build.sh                    # build only (ad-hoc signed, works locally)
#     ./build.sh --install          # build + copy to ~/Applications
#     ./build.sh --run              # build + install + launch
#     ./build.sh --release          # build + embed index.html + zip → mac-app/dist/
#     ./build.sh --sign             # sign with Developer ID Application cert
#     ./build.sh --notarize         # notarize + staple (implies --sign --release)
#     ./build.sh --notarize --run   # full pipeline
#
# One-time signing setup (run AFTER Apple Developer enrollment approved):
#     1. Get your Developer ID Application cert into Keychain:
#         Xcode → Settings → Accounts → your team → Manage Certificates → +
#         → "Developer ID Application"
#     2. Generate app-specific password at appleid.apple.com → App-Specific Passwords
#     3. Cache credentials for notarytool (one-time, stored in Keychain):
#         xcrun notarytool store-credentials AC_PASSWORD \
#             --apple-id "your@email.com" \
#             --team-id "YOURTEAMID" \
#             --password "abcd-efgh-ijkl-mnop"
#     4. Confirm cert is discoverable:
#         security find-identity -v -p codesigning | grep "Developer ID Application"

set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Filament Studio"
BUNDLE_NAME="${APP_NAME}.app"
BUILD_DIR="build"
DIST_DIR="dist"
APP_DIR="${BUILD_DIR}/${BUNDLE_NAME}"
BIN_PATH="${APP_DIR}/Contents/MacOS/${APP_NAME}"

# Notarytool credential profile name (stored in Keychain by store-credentials).
NOTARY_PROFILE="${NOTARY_PROFILE:-AC_PASSWORD}"

# --- Parse flags ------------------------------------------------------------
INSTALL=0
RUN=0
RELEASE=0
SIGN=0
NOTARIZE=0
for arg in "$@"; do
    case "$arg" in
        --install)  INSTALL=1 ;;
        --run)      INSTALL=1; RUN=1 ;;
        --release)  RELEASE=1 ;;
        --sign)     SIGN=1 ;;
        --notarize) NOTARIZE=1; SIGN=1; RELEASE=1 ;;
    esac
done

# --- Compile ---------------------------------------------------------------
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

echo "→ compiling AppMain.swift"
swiftc -O AppMain.swift -o "${BIN_PATH}"

echo "→ generating app icon"
ICONSET_DIR="${BUILD_DIR}/AppIcon.iconset"
ICONGEN_BIN="${BUILD_DIR}/generate-icon"
rm -rf "${ICONSET_DIR}"
swiftc -O GenerateIcon.swift -o "${ICONGEN_BIN}"
"${ICONGEN_BIN}" "${ICONSET_DIR}" > /dev/null
iconutil -c icns "${ICONSET_DIR}" -o "${APP_DIR}/Contents/Resources/AppIcon.icns"
echo "→ AppIcon.icns installed"

echo "→ writing Info.plist"
cp Info.plist.template "${APP_DIR}/Contents/Info.plist"

# --- Embed index.html for self-contained releases ---------------------------
if [ "$RELEASE" = "1" ]; then
    echo "→ embedding index.html into Contents/Resources/"
    cp ../index.html "${APP_DIR}/Contents/Resources/index.html"
fi

# --- Code signing -----------------------------------------------------------
if [ "$SIGN" = "1" ]; then
    # Discover a Developer ID Application cert. Prefer the first non-expired match.
    CERT=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed -E 's/.*"(.*)".*/\1/')
    if [ -z "${CERT}" ]; then
        echo "✗ No 'Developer ID Application' certificate found in Keychain."
        echo "  Fix: Xcode → Settings → Accounts → your team → Manage Certificates → + → Developer ID Application"
        exit 1
    fi
    echo "→ signing with: ${CERT}"
    codesign --force --deep --timestamp --options runtime \
        --sign "${CERT}" "${APP_DIR}"
    codesign --verify --deep --strict --verbose=2 "${APP_DIR}"
else
    echo "→ ad-hoc code sign (local use only — Gatekeeper will warn other users)"
    codesign --force --deep --sign - "${APP_DIR}" 2>/dev/null || true
fi

echo "→ built: ${APP_DIR}"

# --- Release zip ------------------------------------------------------------
if [ "$RELEASE" = "1" ]; then
    mkdir -p "${DIST_DIR}"
    VERSION=$(defaults read "$(pwd)/${APP_DIR}/Contents/Info.plist" CFBundleShortVersionString)
    ARCH=$(uname -m)
    ZIP_NAME="Filament-Studio-${VERSION}-macOS-${ARCH}.zip"
    ZIP_PATH="${DIST_DIR}/${ZIP_NAME}"
    rm -f "${ZIP_PATH}"
    echo "→ zipping (ditto preserves signing metadata)"
    (cd "${BUILD_DIR}" && ditto -c -k --keepParent "${BUNDLE_NAME}" "../${ZIP_PATH}")
    echo "→ release zip: ${ZIP_PATH}"
fi

# --- Notarization -----------------------------------------------------------
if [ "$NOTARIZE" = "1" ]; then
    echo "→ notarising via Apple (this takes 2–15 min)"
    xcrun notarytool submit "${ZIP_PATH}" \
        --keychain-profile "${NOTARY_PROFILE}" \
        --wait
    echo "→ stapling notarisation ticket to .app"
    xcrun stapler staple "${APP_DIR}"
    echo "→ re-zipping stapled .app (staple mutates the bundle)"
    rm -f "${ZIP_PATH}"
    (cd "${BUILD_DIR}" && ditto -c -k --keepParent "${BUNDLE_NAME}" "../${ZIP_PATH}")
    echo "→ verifying Gatekeeper acceptance"
    spctl --assess --type execute --verbose "${APP_DIR}" || echo "  (spctl may report deny before staple propagates — the ticket is still stapled)"
    echo "→ notarised release: ${ZIP_PATH}"
fi

# --- Install locally --------------------------------------------------------
if [ "$INSTALL" = "1" ]; then
    DEST="/Applications/${BUNDLE_NAME}"
    mkdir -p "/Applications"
    rm -rf "${DEST}"
    cp -R "${APP_DIR}" "${DEST}"
    echo "→ installed: ${DEST}"
fi

if [ "$RUN" = "1" ]; then
    echo "→ launching"
    open "/Applications/${BUNDLE_NAME}"
fi
