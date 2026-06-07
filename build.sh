#!/bin/zsh
set -euo pipefail

APP_NAME="Global Clipboard"
EXECUTABLE_NAME="GlobalClipboard"
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
SIGN_IDENTITY="${CODE_SIGN_IDENTITY:-}"

if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | awk -F '"' '/"[^"]+"/ { print $2; exit }')"
fi

if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="-"
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"

cp "$ROOT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"

xcrun swiftc \
  -swift-version 5 \
  -target arm64-apple-macosx13.0 \
  -framework AppKit \
  -framework Carbon \
  -framework ApplicationServices \
  -framework ServiceManagement \
  -O \
  "$ROOT_DIR"/Sources/*.swift \
  -o "$MACOS_DIR/$EXECUTABLE_NAME"

xattr -cr "$APP_DIR"
codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_DIR" >/dev/null

echo "已构建：$APP_DIR"
echo "签名身份：$SIGN_IDENTITY"
