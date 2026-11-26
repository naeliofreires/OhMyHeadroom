#!/bin/sh
# Builds Headroom and installs it in ~/Applications as a menu bar app (LSUIElement: no Dock icon).
set -eu

here="$(cd "$(dirname "$0")" && pwd)"
cd "$here"

app="$HOME/Applications/Headroom.app"
if [ -e "$app" ] || [ -L "$app" ]; then
  identifier=""
  if [ ! -L "$app" ] && [ -d "$app" ]; then
    identifier="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist" 2>/dev/null || true)"
  fi
  if [ "$identifier" != "local.police-scan" ]; then
    echo "Refusing to replace unrelated app: $app" >&2
    exit 1
  fi
fi

swift build -c release

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp .build/release/Headroom "$app/Contents/MacOS/Headroom"
cp Info.plist "$app/Contents/Info.plist"
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
cp -R .build/release/Headroom_Headroom.bundle "$app/Contents/Resources/"
# One Localizable.strings per language; SwiftUI picks the one that matches the system language.
cp -R Localization/*.lproj "$app/Contents/Resources/"
# Ad-hoc signature: enough for a local build on this Mac, not for distribution.
codesign --force --sign - "$app"

echo "Installed at: $app"
