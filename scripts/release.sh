#!/bin/bash
set -euo pipefail

# Builds dist/Yoke-<version>.dmg, a universal app with an Applications shortcut.
#   scripts/release.sh             build the DMG
#   scripts/release.sh --publish   also tag v<version> and upload it to GitHub Releases
# The version is CFBundleShortVersionString in macos/Info.plist. Bump it before a release.
# With a "Developer ID Application" certificate the app is signed with it, and with
# YOKE_NOTARY_PROFILE set to a notarytool keychain profile the DMG is notarized and stapled.
# Without one the app is ad-hoc signed, and macOS asks people to allow it on first open.

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' macos/Info.plist)
tag="v$version"
dmg="$root/dist/Yoke-$version.dmg"

if [[ "${1:-}" == "--publish" ]]; then
  [[ -z "$(git status --porcelain)" ]] || { echo "Commit or stash your changes before publishing." >&2; exit 1; }
  git fetch --quiet origin --tags
  [[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] || { echo "HEAD is not origin/main. Push first." >&2; exit 1; }
  if git rev-parse --quiet --verify "refs/tags/$tag" >/dev/null; then
    echo "$tag already exists. Bump the version in macos/Info.plist." >&2; exit 1
  fi
fi

swift test

developer_id=$(security find-identity -p codesigning -v 2>/dev/null | sed -n 's/.*"\(Developer ID Application.*\)"/\1/p' | head -1 || true)
if [[ -n "$developer_id" ]]; then
  YOKE_ARCHS="arm64 x86_64" YOKE_SIGN_IDENTITY="$developer_id" YOKE_HARDENED=1 scripts/build-app.sh
else
  YOKE_ARCHS="arm64 x86_64" YOKE_SIGN_IDENTITY="" scripts/build-app.sh
fi

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
cp -R dist/Yoke.app "$stage/Yoke.app"
ln -s /Applications "$stage/Applications"
rm -f "$dmg"
hdiutil create -quiet -volname "Yoke $version" -srcfolder "$stage" -format UDZO -ov "$dmg"

notarized=no
if [[ -n "$developer_id" ]]; then
  codesign --force --sign "$developer_id" --timestamp "$dmg"
  if [[ -n "${YOKE_NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "$dmg" --keychain-profile "$YOKE_NOTARY_PROFILE" --wait
    xcrun stapler staple "$dmg"
    notarized=yes
  fi
fi

echo "Built $dmg (notarized: $notarized)"
shasum -a 256 "$dmg"

if [[ "${1:-}" == "--publish" ]]; then
  notes="Download Yoke-$version.dmg, open it, and drag Yoke to Applications."
  if [[ "$notarized" == "no" ]]; then
    notes+=$'\n\n'"This build is not notarized by Apple. The first time you open it, macOS will block it: go to System Settings → Privacy & Security and click Open Anyway."
  fi
  gh release create "$tag" "$dmg" --target "$(git rev-parse HEAD)" --title "Yoke $version" --notes "$notes" --generate-notes
fi
