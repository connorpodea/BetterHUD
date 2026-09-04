#!/usr/bin/env bash
#
# Assembles dist/CenterHUD.app from the release binary and ad-hoc codesigns it.
#
# Ad-hoc signing is for local testing only. Its identity changes on every
# rebuild, so macOS may drop the Accessibility / Input Monitoring grant and
# require re-toggling. Notarized distribution needs a Developer ID identity
# (see CLAUDE.md).

set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="CenterHUD"
BUNDLE="dist/${APP_NAME}.app"

swift build -c release
BIN_PATH="$(swift build -c release --show-bin-path)/${APP_NAME}"

rm -rf "${BUNDLE}"
mkdir -p "${BUNDLE}/Contents/MacOS"
cp "${BIN_PATH}" "${BUNDLE}/Contents/MacOS/${APP_NAME}"
cp Resources/Info.plist "${BUNDLE}/Contents/Info.plist"
printf 'APPL????' > "${BUNDLE}/Contents/PkgInfo"

codesign --force --options runtime --sign - "${BUNDLE}"

echo "Built ${BUNDLE}"
