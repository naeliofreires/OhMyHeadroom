#!/bin/sh
# Builds Police Scan and installs it in ~/Applications as a menu bar app (LSUIElement: no Dock icon).
set -eu

here="$(cd "$(dirname "$0")" && pwd)"
cd "$here"

swift build -c release

app="$HOME/Applications/Police Scan.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp .build/release/PoliceScan "$app/Contents/MacOS/PoliceScan"
cp Info.plist "$app/Contents/Info.plist"
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
# One Localizable.strings per language; SwiftUI picks the one that matches the system language.
cp -R Localization/*.lproj "$app/Contents/Resources/"
# Ad-hoc signature: enough for a local build on this Mac, not for distribution.
codesign --force --sign - "$app"

echo "Installed at: $app"
