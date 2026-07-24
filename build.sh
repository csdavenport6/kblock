#!/bin/bash
# Builds KeyLock.app into the project directory.
set -euo pipefail
cd "$(dirname "$0")"

APP=KeyLock.app

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O Sources/main.swift -o "$APP/Contents/MacOS/KeyLock"
cp Info.plist "$APP/Contents/Info.plist"

# Ad-hoc sign so the Accessibility grant survives rebuilds/moves more reliably.
codesign --force --sign - "$APP"

echo "Built $PWD/$APP"
