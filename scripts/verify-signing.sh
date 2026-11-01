#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CACHE="${SOFA_BUILD_DIR:-$ROOT/.build}/signing-tools"
mkdir -p "$CACHE"
if [ ! -x "$CACHE/verify-signing" ] || [ "$ROOT/scripts/verify-signing.swift" -nt "$CACHE/verify-signing" ]; then
  xcrun swiftc -O -module-cache-path "$CACHE/modules" "$ROOT/scripts/verify-signing.swift" -o "$CACHE/verify-signing"
fi
exec "$CACHE/verify-signing" "$@"
