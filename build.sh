#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
LOCATION=(--scratch-path "${SOFA_BUILD_DIR:-.build}")
STAGING="$(mktemp -d build-staging.XXXXXX)"
trap 'rm -rf "$STAGING"' EXIT
IDENTITY="${SOFA_SIGN_IDENTITY:-}"
KEYCHAIN=()
if [ -n "${SOFA_SIGN_KEYCHAIN:-}" ]; then KEYCHAIN=(--keychain "$SOFA_SIGN_KEYCHAIN"); fi
IDENTITY_KEYCHAIN=()
if [ -n "${SOFA_SIGN_KEYCHAIN:-}" ]; then IDENTITY_KEYCHAIN=("$SOFA_SIGN_KEYCHAIN"); fi
PREVIOUS="${SOFA_PREVIOUS_APP:-/Applications/Sofa Remote.app}"

if [ "${SOFA_PUBLIC_RELEASE:-0}" = 1 ]; then
  : "${SOFA_SIGN_IDENTITY:?Public releases require a Developer ID identity}"
  : "${SOFA_TEAM_ID:?Public releases require the expected Team ID}"
  : "${SOFA_NOTARY_PROFILE:?Public releases require notarization credentials}"
  if [ "${SOFA_ALLOW_ADHOC:-0}" = 1 ] || [ "$IDENTITY" = '-' ]; then
    echo 'Public releases cannot use ad-hoc signing.' >&2; exit 1
  fi
fi

# An explicit development-artifact request never consumes the persistent local key.
if [ -z "$IDENTITY" ] && [ "${SOFA_ALLOW_ADHOC:-0}" = 1 ]; then IDENTITY='-'; fi

# Prefer the installed certificate: never silently fall back to a new identity.
# Only public certificate bytes are extracted; private keys stay in Keychain.
if [ -z "$IDENTITY" ] && [ -d "$PREVIOUS" ] && \
   ./scripts/verify-signing.sh --mode certificate --app "$PREVIOUS" >/dev/null 2>&1; then
  codesign --display --extract-certificates="$STAGING/previous-cert-" "$PREVIOUS" 2>/dev/null
  IDENTITY="$(shasum -a 1 "$STAGING/previous-cert-0" | awk '{print toupper($1)}')"
  if ! security find-identity -p codesigning ${IDENTITY_KEYCHAIN[@]+"${IDENTITY_KEYCHAIN[@]}"} | awk '{print $2}' | grep -Fxq "$IDENTITY"; then
    echo 'The installed signing key is unavailable. Restore that identity; do not replace it with an ad-hoc build.' >&2
    exit 1
  fi
fi
if [ -z "$IDENTITY" ]; then
  MATCHES="$(security find-identity -p codesigning ${IDENTITY_KEYCHAIN[@]+"${IDENTITY_KEYCHAIN[@]}"} | awk '/"Sofa Remote Local Signing"/ {print $2}' | sort -u)"
  if [ -n "$MATCHES" ]; then
    if [ "$(printf '%s\n' "$MATCHES" | wc -l | tr -d ' ')" != 1 ]; then
      echo 'Multiple local signing identities found. Select SOFA_SIGN_IDENTITY explicitly.' >&2; exit 1
    fi
    IDENTITY="$MATCHES"
  elif [ "${SOFA_ALLOW_ADHOC:-0}" = 1 ]; then
    IDENTITY='-'
  else
    echo 'No stable signing identity found. See docs/SIGNING.md for free local signing or Developer ID.' >&2
    echo 'For a disposable development artifact only, set SOFA_ALLOW_ADHOC=1 explicitly.' >&2
    exit 1
  fi
fi
if [ "$IDENTITY" = '-' ] && [ "${SOFA_ALLOW_ADHOC:-0}" != 1 ]; then
  echo 'Ad-hoc signing requires explicit SOFA_ALLOW_ADHOC=1; it cannot retain permission across builds.' >&2; exit 1
fi

swift build -c release --arch arm64 --arch x86_64 "${LOCATION[@]}"
BIN="$(swift build -c release --arch arm64 --arch x86_64 "${LOCATION[@]}" --show-bin-path)"
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
if [ "$IDENTITY" = '-' ]; then
  codesign --force --sign - "$APP"
  ./scripts/verify-signing.sh --mode development --app "$APP"
else
  TIMESTAMP=(--timestamp=none)
  if [ "${SOFA_PUBLIC_RELEASE:-0}" = 1 ]; then TIMESTAMP=(--timestamp); fi
  # Always generate the default DR. Never preserve/override requirements to bypass identity checks.
  codesign --force --options runtime "${TIMESTAMP[@]}" --sign "$IDENTITY" ${KEYCHAIN[@]+"${KEYCHAIN[@]}"} "$APP"
  ./scripts/verify-signing.sh --mode certificate --app "$APP"
  if [ -d "$PREVIOUS" ]; then
    if ./scripts/verify-signing.sh --mode certificate --app "$PREVIOUS" >/dev/null 2>&1; then
      if [ "${SOFA_ALLOW_IDENTITY_MIGRATION:-0}" = 1 ]; then
        echo 'Explicit identity migration: this staged build may need a new manual permission grant.' >&2
      else
        ./scripts/verify-signing.sh --mode certificate --app "$APP" --previous "$PREVIOUS"
      fi
    else
      echo 'The previous app has no verified certificate identity. First certificate migration requires manual permission review.' >&2
    fi
  fi
  if [ "${SOFA_PUBLIC_RELEASE:-0}" = 1 ]; then
    ./scripts/verify-signing.sh --mode release --team "$SOFA_TEAM_ID" --app "$APP"
  fi
fi
codesign --verify --deep --strict --all-architectures "$APP"
# Stage only: never replace a running or installed application from a build script.
mkdir -p build
if [ -e 'build/Sofa Remote.app' ] && pgrep -f "$(pwd)/build/Sofa Remote.app/Contents/MacOS/SofaRemote" >/dev/null; then
  echo 'Quit the app running from build/ before replacing that bundle.' >&2; exit 1
fi
rm -rf 'build/Sofa Remote.app'
mv "$APP" build/
echo "Built $(pwd)/build/Sofa Remote.app"
