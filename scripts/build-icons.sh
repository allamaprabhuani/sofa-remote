#!/bin/bash
set -euo pipefail
# Rasterise only at build time. No image libraries or artwork generation at runtime.
STAGING="$1"
RESOURCES="$2"
ICONSET="$STAGING/AppIcon.iconset"
mkdir -p "$ICONSET" "$RESOURCES"
for SIZE in 16 32 128 256 512; do
  sips -z "$SIZE" "$SIZE" Assets/AppIcon.png --out "$ICONSET/icon_${SIZE}x${SIZE}.png" >/dev/null
  DOUBLE=$((SIZE * 2))
  sips -z "$DOUBLE" "$DOUBLE" Assets/AppIcon.png --out "$ICONSET/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$RESOURCES/AppIcon.icns"
for SIZE in 180 192 512; do
  sips -z "$SIZE" "$SIZE" Assets/AppIcon.png --out "$RESOURCES/icon-$SIZE.png" >/dev/null
done
