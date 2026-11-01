#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
LOCATION=(--scratch-path "${SOFA_BUILD_DIR:-.build}")
swift build -c release --arch arm64 --arch x86_64 "${LOCATION[@]}"
BIN="$(swift build -c release --arch arm64 --arch x86_64 "${LOCATION[@]}" --show-bin-path)"
STAGING="$(mktemp -d build-staging.XXXXXX)"
trap 'rm -rf "$STAGING"' EXIT
APP="$STAGING/Sofa Remote.app"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN/SofaRemote" "$APP/Contents/MacOS/SofaRemote"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign "${SOFA_SIGN_IDENTITY:--}" "$APP"
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
