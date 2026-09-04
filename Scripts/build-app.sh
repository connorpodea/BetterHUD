#!/usr/bin/env bash
#
# Assembles dist/BetterHUD.app from the release binary and signs it.
#
# Signing identity matters more than usual here. An ad-hoc signature's
# designated requirement is the binary's own cdhash, so every rebuild looks
# like a different app to macOS and the Accessibility grant is silently
# dropped. Signing with a certificate yields a requirement of the form
#   identifier "com.connorpodea.betterhud" and certificate leaf = H"..."
# which is stable across rebuilds, so the grant survives.
#
# "CenterHUD Dev" is a locally generated, locally trusted code-signing cert
# (see CLAUDE.md). Shipping to other machines still needs a Developer ID
# certificate and notarization.

set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="BetterHUD"
# The app is built outside the repo on purpose. This project lives under
# ~/Desktop, which iCloud syncs, and the file provider continually re-adds
# com.apple.FinderInfo to the bundle — which codesign rejects as "resource
# fork, Finder information, or similar detritus". ~/Applications is not synced,
# and is where the app should live for everyday use anyway.
INSTALL_DIR="${BETTERHUD_INSTALL_DIR:-${HOME}/Applications}"
BUNDLE="${INSTALL_DIR}/${APP_NAME}.app"
# The local cert is still named "CenterHUD Dev" from before the rename.
# Renaming the app doesn't require a new certificate, and regenerating one
# would mean re-trusting it in the keychain for no benefit.
SIGN_IDENTITY="${BETTERHUD_SIGN_IDENTITY:-CenterHUD Dev}"

swift build -c release
BIN_PATH="$(swift build -c release --show-bin-path)/${APP_NAME}"

rm -rf "${BUNDLE}"
mkdir -p "${INSTALL_DIR}"
mkdir -p "${BUNDLE}/Contents/MacOS" "${BUNDLE}/Contents/Resources"
cp "${BIN_PATH}" "${BUNDLE}/Contents/MacOS/${APP_NAME}"
cp Resources/Info.plist "${BUNDLE}/Contents/Info.plist"
cp Resources/AppIcon.icns "${BUNDLE}/Contents/Resources/"
printf 'APPL????' > "${BUNDLE}/Contents/PkgInfo"

# Extended attributes picked up along the way make codesign refuse the bundle.
xattr -cr "${BUNDLE}"

if security find-identity -v -p codesigning | grep -qF "${SIGN_IDENTITY}"; then
    codesign --force --options runtime --sign "${SIGN_IDENTITY}" "${BUNDLE}"
else
    echo "warning: '${SIGN_IDENTITY}' not found; falling back to ad-hoc." >&2
    echo "         Accessibility permission will reset on every rebuild." >&2
    codesign --force --options runtime --sign - "${BUNDLE}"
fi

echo "Built ${BUNDLE}"
codesign -d -r- "${BUNDLE}" 2>&1 | tail -1
