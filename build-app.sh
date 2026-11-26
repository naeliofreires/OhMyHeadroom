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

mkdir -p "$HOME/Applications"
staging="$(mktemp -d "$HOME/Applications/.headroom.XXXXXXXX")"
trap 'rm -rf "$staging"' EXIT
staged_app="$staging/Headroom.app"
contents="$staged_app/Contents"
engine="$contents/Resources/Engine"
mkdir -p "$contents/MacOS" "$engine"
cp .build/release/Headroom "$contents/MacOS/Headroom"
cp Info.plist "$contents/Info.plist"
cp Resources/AppIcon.icns "$contents/Resources/AppIcon.icns"
cp -R .build/release/Headroom_Headroom.bundle "$contents/Resources/"
# One Localizable.strings per language; SwiftUI picks the one that matches the system language.
cp -R Localization/*.lproj "$contents/Resources/"
cp cleanup.py "$engine/"
rsync -r --exclude='__pycache__/' --exclude='*.pyc' headroom_engine "$engine/"
# Ad-hoc signature for a local build.
codesign --force --sign - "$staged_app"

rm -rf "$app"
mv "$staged_app" "$app"

echo "Installed at: $app"
