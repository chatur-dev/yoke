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

if [[ -f "$root/macos/AppIcon.png" ]] && command -v sips >/dev/null && command -v iconutil >/dev/null; then
  iconset="$root/dist/AppIcon.iconset"
  rm -rf "$iconset"
  mkdir -p "$iconset"
  sips -z 16 16 "$root/macos/AppIcon.png" --out "$iconset/icon_16x16.png" >/dev/null
  sips -z 32 32 "$root/macos/AppIcon.png" --out "$iconset/icon_16x16@2x.png" >/dev/null
  sips -z 32 32 "$root/macos/AppIcon.png" --out "$iconset/icon_32x32.png" >/dev/null
  sips -z 64 64 "$root/macos/AppIcon.png" --out "$iconset/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 "$root/macos/AppIcon.png" --out "$iconset/icon_128x128.png" >/dev/null
  sips -z 256 256 "$root/macos/AppIcon.png" --out "$iconset/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "$root/macos/AppIcon.png" --out "$iconset/icon_256x256.png" >/dev/null
  sips -z 512 512 "$root/macos/AppIcon.png" --out "$iconset/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "$root/macos/AppIcon.png" --out "$iconset/icon_512x512.png" >/dev/null
  cp "$root/macos/AppIcon.png" "$iconset/icon_512x512@2x.png"
  iconutil -c icns "$iconset" -o "$app/Contents/Resources/AppIcon.icns"
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$app/Contents/Info.plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$app/Contents/Info.plist"
  rm -rf "$iconset"
fi

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
