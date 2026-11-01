#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
LOCATION=(--scratch-path "${SOFA_BUILD_DIR:-.build}")
swift build -c release --arch arm64 --arch x86_64 "${LOCATION[@]}"
BIN="$(swift build -c release --arch arm64 --arch x86_64 "${LOCATION[@]}" --show-bin-path)"
STAGING="$(mktemp -d build-staging.XXXXXX)"
trap 'rm -rf "$STAGING"' EXIT
APP="$STAGING/Sofa Remote.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/SofaRemote" "$APP/Contents/MacOS/SofaRemote"
cp Info.plist "$APP/Contents/Info.plist"
cp LICENSE NOTICE "$APP/Contents/Resources/"
cp docs/PRIVACY.md SUPPORT.md "$APP/Contents/Resources/"
SOURCE_REVISION="$(git rev-parse HEAD)"
if [ -n "$(git status --porcelain=v1 --untracked-files=normal)" ]; then SOURCE_REVISION="$SOURCE_REVISION-dirty"; fi
/usr/libexec/PlistBuddy -c "Add :SofaSourceRevision string $SOURCE_REVISION" "$APP/Contents/Info.plist"
./scripts/build-icons.sh "$STAGING" "$APP/Contents/Resources"
if [ "${SOFA_SIGN_IDENTITY:--}" = '-' ]; then
  codesign --force --sign - "$APP"
else
  codesign --force --options runtime --timestamp --sign "$SOFA_SIGN_IDENTITY" "$APP"
fi
codesign --verify --deep --strict "$APP"
# Build staging is independent of an installed/running app. Never replace a live build bundle.
mkdir -p build
if [ -e 'build/Sofa Remote.app' ] && pgrep -f "$(pwd)/build/Sofa Remote.app/Contents/MacOS/SofaRemote" >/dev/null; then
  echo 'Quit the app running from build/ before replacing that bundle.' >&2
  exit 1
fi
rm -rf 'build/Sofa Remote.app'
mv "$APP" build/
echo "Built $(pwd)/build/Sofa Remote.app"
