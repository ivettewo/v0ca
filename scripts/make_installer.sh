#!/bin/bash
# Builds the Release configuration and packages it into a DMG with an
# Applications shortcut, placing the result in installer/.
#
#     ./scripts/make_installer.sh
#
# Produces two files: installer/v0ca-<version>.dmg (archive of that version)
# and installer/v0ca-latest.dmg (copy of the latest build — a stable link).
set -euo pipefail

cd "$(dirname "$0")/.."

OUT_DIR="installer"
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT

VERSION=$(awk '/MARKETING_VERSION:/ {print $2}' project.yml)
[ -n "$VERSION" ] || { echo "✗ MARKETING_VERSION not found in project.yml" >&2; exit 1; }

echo "→ Building Release ${VERSION}…"
xcodebuild -project v0ca.xcodeproj -scheme v0ca -configuration Release \
    -destination 'platform=macOS' \
    CONFIGURATION_BUILD_DIR="$BUILD_DIR" \
    build >/dev/null

APP="$BUILD_DIR/v0ca.app"
[ -d "$APP" ] || { echo "✗ Build produced no v0ca.app" >&2; exit 1; }

echo "→ Verifying signature…"
codesign --verify --deep --strict "$APP" || echo "  ⚠︎ Signature check failed — building the DMG anyway."

echo "→ Packaging DMG…"
STAGE="$BUILD_DIR/dmg"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

mkdir -p "$OUT_DIR"
DMG="$OUT_DIR/v0ca-${VERSION}.dmg"
rm -f "$DMG" "$OUT_DIR/v0ca-latest.dmg"
hdiutil create -volname "v0ca ${VERSION}" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
cp "$DMG" "$OUT_DIR/v0ca-latest.dmg"

echo "✓ $DMG ($(du -h "$DMG" | cut -f1))"
echo "✓ $OUT_DIR/v0ca-latest.dmg"
echo
echo "The build is signed with a Development certificate and not notarized — on"
echo "another Mac, Gatekeeper will block the first launch. Tell the user to:"
echo "  1) right-click v0ca in Applications → Open → Open in the dialog;"
echo "  2) or System Settings → Privacy & Security → Open Anyway;"
echo "  3) or strip quarantine manually: xattr -dr com.apple.quarantine /Applications/v0ca.app"
echo "The only way to remove this step entirely is a Developer ID certificate + notarization."
