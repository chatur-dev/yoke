#!/bin/bash
set -euo pipefail

# YOKE_ARCHS: architectures to build, default this Mac's. YOKE_SIGN_IDENTITY: codesign identity,
# default the first one in the keychain, or ad-hoc. YOKE_HARDENED=1 turns on the hardened runtime.

root=$(cd "$(dirname "$0")/.." && pwd)
app="$root/dist/Yoke.app"
bin="$app/Contents/MacOS"
sdk=$(xcrun --show-sdk-path)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

rm -rf "$app"
mkdir -p "$bin"

slices=()
for arch in ${YOKE_ARCHS:-$(uname -m)}; do
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
    -o "$work/Yoke-$arch" \
    "$root"/Sources/YokeCore/*.swift \
    "$root"/macos/*.swift
  slices+=("$work/Yoke-$arch")
done
lipo -create "${slices[@]}" -output "$bin/Yoke"

mkdir -p "$app/Contents/Resources"
cp "$root/macos/Info.plist" "$app/Contents/Info.plist"

if [[ -z "${YOKE_SIGN_IDENTITY+x}" ]]; then
  YOKE_SIGN_IDENTITY=$(security find-identity -p codesigning -v 2>/dev/null | sed -n 's/.*"\(.*\)"/\1/p' | head -1 || true)
fi
sign=(codesign --force --deep --sign "${YOKE_SIGN_IDENTITY:--}")
if [[ "${YOKE_HARDENED:-}" == "1" ]]; then sign+=(--options runtime --timestamp); fi
"${sign[@]}" "$app"

echo "Built $app"

if [[ "${1:-}" == "--install" ]]; then
  rm -rf /Applications/Yoke.app
  cp -R "$app" /Applications/Yoke.app
  xattr -dr com.apple.quarantine /Applications/Yoke.app 2>/dev/null || true
  open /Applications/Yoke.app
  echo "Installed and opened /Applications/Yoke.app"
fi
