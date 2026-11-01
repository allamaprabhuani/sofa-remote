#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
MIGRATE=0
if [ "${1:-}" = '--first-certificate-migration' ]; then MIGRATE=1; shift; fi
CANDIDATE="${1:-build/Sofa Remote.app}"
if [ "$#" -gt 1 ]; then echo 'Usage: install-local.sh [--first-certificate-migration] [APP]' >&2; exit 1; fi
DEST='/Applications/Sofa Remote.app'
./scripts/verify-signing.sh --mode certificate --app "$CANDIDATE"
if pgrep -x SofaRemote >/dev/null; then
  echo 'Quit Sofa Remote before installing. This installer does not stop it or replace a live bundle.' >&2; exit 1
fi
if [ -d "$DEST" ]; then
  if ./scripts/verify-signing.sh --mode certificate --app "$DEST" >/dev/null 2>&1; then
    ./scripts/verify-signing.sh --mode certificate --app "$CANDIDATE" --previous "$DEST"
  else
    if [ "$MIGRATE" != 1 ]; then
      echo 'Existing app has no verified certificate identity. A first migration needs --first-certificate-migration and manual macOS permission approval.' >&2; exit 1
    fi
    ./scripts/verify-signing.sh --mode development --app "$DEST"
    echo 'First certificate migration: macOS permission must be approved by the owner. Nothing grants it automatically.' >&2
  fi
fi
STAGE="$(mktemp -d /Applications/.sofa-remote-install.XXXXXX)"
COMPLETE=0
cleanup() {
  if [ "$COMPLETE" = 1 ] || [ ! -d "$STAGE/previous.app" ]; then
    rm -rf "$STAGE"
  elif [ ! -e "$DEST" ]; then
    mv "$STAGE/previous.app" "$DEST"
    rm -rf "$STAGE"
  else
    echo "Installation incomplete; previous app retained for recovery in $STAGE" >&2
  fi
}
trap cleanup EXIT
chmod 700 "$STAGE"
ditto "$CANDIDATE" "$STAGE/new.app"
./scripts/verify-signing.sh --mode certificate --app "$STAGE/new.app"
if pgrep -x SofaRemote >/dev/null; then echo 'Sofa Remote restarted; installation stopped.' >&2; exit 1; fi
if [ -e "$DEST" ]; then mv "$DEST" "$STAGE/previous.app"; fi
mv "$STAGE/new.app" "$DEST"
./scripts/verify-signing.sh --mode certificate --app "$DEST"
COMPLETE=1
echo 'Installed certificate-signed Sofa Remote. Pairing/preferences were not read or changed.'
