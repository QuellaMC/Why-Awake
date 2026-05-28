#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Why Awake"
PROJECT_FILE="Why Awake.xcodeproj"
SCHEME="Why Awake"
CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA="${DERIVED_DATA:-/private/tmp/whyawake-release-dd}"
OUTPUT_DIR="${OUTPUT_DIR:-/private/tmp/whyawake-release}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -z "${VERSION:-}" ]]; then
  VERSION="$(/usr/bin/git -C "$ROOT_DIR" describe --tags --always --dirty 2>/dev/null || echo local)"
fi

SAFE_VERSION="${VERSION#refs/tags/}"
SAFE_VERSION="${SAFE_VERSION//\//-}"
APP_BUNDLE="$DERIVED_DATA/Build/Products/$CONFIGURATION/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
ZIP_NAME="Why-Awake-$SAFE_VERSION-macOS.zip"
ZIP_PATH="$OUTPUT_DIR/$ZIP_NAME"
DMG_NAME="Why-Awake-$SAFE_VERSION-macOS.dmg"
DMG_PATH="$OUTPUT_DIR/$DMG_NAME"

/bin/mkdir -p "$OUTPUT_DIR"

xcodebuild \
  -project "$ROOT_DIR/$PROJECT_FILE" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$DERIVED_DATA" \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED="${CODE_SIGNING_ALLOWED:-NO}" \
  build >&2

if [[ ! -x "$APP_BINARY" ]]; then
  echo "Expected app binary not found at $APP_BINARY" >&2
  exit 1
fi

if [[ -e "$ZIP_PATH" ]]; then
  echo "Release archive already exists at $ZIP_PATH" >&2
  exit 1
fi

if [[ -e "$DMG_PATH" ]]; then
  echo "Release disk image already exists at $DMG_PATH" >&2
  exit 1
fi

/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"

DMG_STAGING_DIR="$(/usr/bin/mktemp -d "$OUTPUT_DIR/dmg-staging.XXXXXX")"
cleanup() {
  /bin/rm -rf "$DMG_STAGING_DIR"
}
trap cleanup EXIT

/usr/bin/ditto "$APP_BUNDLE" "$DMG_STAGING_DIR/$APP_NAME.app"
/bin/ln -s /Applications "$DMG_STAGING_DIR/Applications"

/usr/bin/hdiutil create \
  -volname "$APP_NAME $SAFE_VERSION" \
  -srcfolder "$DMG_STAGING_DIR" \
  -format UDZO \
  "$DMG_PATH" >&2

echo "$ZIP_PATH"
echo "$DMG_PATH"
