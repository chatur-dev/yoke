#!/bin/bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
app="$root/dist/Yoke.app"
bin="$app/Contents/MacOS"
sdk=$(xcrun --show-sdk-path)
arch=$(uname -m)

rm -rf "$app"
mkdir -p "$bin"

swiftc -O -parse-as-library -swift-version 5 \
  -sdk "$sdk" \
  -target "${arch}-apple-macosx14.0" \
  -framework AppKit \
  -framework SwiftUI \
  -framework GameController \
  -framework IOKit \
  -framework CoreGraphics \
  -framework ApplicationServices \
  -framework ServiceManagement \
  -o "$bin/Yoke" \
  "$root"/Sources/YokeCore/*.swift \
  "$root"/macos/*.swift

mkdir -p "$app/Contents/Resources"
cp "$root/macos/Info.plist" "$app/Contents/Info.plist"

identity=$(security find-identity -p codesigning -v 2>/dev/null | sed -n 's/.*"\(.*\)"/\1/p' | head -1 || true)
if [[ -n "${identity}" ]]; then
  codesign --force --deep --sign "$identity" "$app"
else
  codesign --force --deep --sign - "$app"
fi

echo "Built $app"

if [[ "${1:-}" == "--install" ]]; then
  rm -rf /Applications/Yoke.app
  cp -R "$app" /Applications/Yoke.app
  xattr -dr com.apple.quarantine /Applications/Yoke.app 2>/dev/null || true
  open /Applications/Yoke.app
  echo "Installed and opened /Applications/Yoke.app"
fi
