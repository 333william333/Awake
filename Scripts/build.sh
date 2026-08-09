#!/usr/bin/env bash
#
# Builds dist/Awake.app. Pass --package to also produce the .zip and .dmg
# that go on a release.
#
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
NAME="Awake"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
DIST="$ROOT/dist"
BUNDLE="$DIST/$NAME.app"

echo "▸ $NAME $VERSION"

if swift build -c release --arch arm64 --arch x86_64 2>/dev/null; then
    BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"
    echo "  universal (arm64 + x86_64)"
else
    echo "  universal build unavailable — building for this Mac only"
    swift build -c release
    BIN="$(swift build -c release --show-bin-path)"
fi

[ -f Resources/AppIcon.icns ] || swift Scripts/make-icon.swift

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$BIN/$NAME" "$BUNDLE/Contents/MacOS/$NAME"
strip -x "$BUNDLE/Contents/MacOS/$NAME" 2>/dev/null || true
cp Resources/Info.plist "$BUNDLE/Contents/Info.plist"
cp Resources/AppIcon.icns "$BUNDLE/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$BUNDLE/Contents/PkgInfo"

codesign --force --sign - "$BUNDLE" >/dev/null 2>&1 || echo "  (ad-hoc signing skipped)"

echo "  → $BUNDLE ($(du -h "$BUNDLE/Contents/MacOS/$NAME" | cut -f1) binary)"

if [ "${1:-}" = "--package" ]; then
    ditto -c -k --keepParent "$BUNDLE" "$DIST/$NAME-$VERSION.zip"

    STAGE="$(mktemp -d)"
    cp -R "$BUNDLE" "$STAGE/"
    ln -s /Applications "$STAGE/Applications"
    rm -f "$DIST/$NAME-$VERSION.dmg"
    hdiutil create -volname "$NAME" -srcfolder "$STAGE" -ov -format UDZO \
        "$DIST/$NAME-$VERSION.dmg" >/dev/null
    rm -rf "$STAGE"

    echo "  → $DIST/$NAME-$VERSION.zip"
    echo "  → $DIST/$NAME-$VERSION.dmg"
fi
