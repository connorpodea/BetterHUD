#!/usr/bin/env bash
#
# Runs the test suite.
#
# Plain `swift test` fails on a Command Line Tools-only install: swift-testing
# ships as a framework under the active developer directory, and SwiftPM puts
# neither a framework search path nor an rpath to it on the test bundle, so the
# build can't find the module and the bundle can't be dlopen'd if it does. Both
# flags below point at the same directory to fix each half of that.
#
# The path is resolved from xcode-select rather than hardcoded, and a search
# path that doesn't exist is ignored, so this is also correct on a machine with
# full Xcode where the flags aren't needed at all.

set -euo pipefail

cd "$(dirname "$0")/.."

FRAMEWORKS="$(xcode-select -p)/Library/Developer/Frameworks"

if [[ -d "${FRAMEWORKS}" ]]; then
    exec swift test \
        -Xswiftc -F -Xswiftc "${FRAMEWORKS}" \
        -Xlinker -rpath -Xlinker "${FRAMEWORKS}" \
        "$@"
else
    exec swift test "$@"
fi
