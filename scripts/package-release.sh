#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Normal release names require Developer ID and notarisation. Certificate previews
# and CI development artifacts must be selected explicitly and use separate names.
DEVELOPMENT="${SOFA_DEVELOPMENT_ARTIFACT:-0}"
PUBLIC="${SOFA_PUBLIC_RELEASE:-0}"
PREVIEW="${SOFA_CERTIFICATE_PREVIEW:-0}"
FIRST_PREVIEW="${SOFA_FIRST_CERTIFICATE_PREVIEW:-0}"
for value in "$DEVELOPMENT" "$PUBLIC" "$PREVIEW" "$FIRST_PREVIEW"; do
  case "$value" in 0|1) ;; *) echo 'Packaging mode flags must be 0 or 1.' >&2; exit 1 ;; esac
done
case "$DEVELOPMENT:$PUBLIC:$PREVIEW" in
  0:0:0|0:1:0|1:0:0|0:0:1) ;;
  *) echo 'Development, certificate-preview and public-release modes cannot be combined.' >&2; exit 1 ;;
esac
if [ "$FIRST_PREVIEW" = 1 ] && [ "$PREVIEW" != 1 ]; then
  echo 'SOFA_FIRST_CERTIFICATE_PREVIEW is only valid in certificate-preview mode.' >&2; exit 1
fi
if [ "$DEVELOPMENT" = 1 ]; then
  MODE=development
  OUTPUT=build/development
  BASENAME=Sofa-Remote-development
  VOLUME='Sofa Remote Development'
elif [ "$PREVIEW" = 1 ]; then
  if [ "${SOFA_ALLOW_ADHOC:-0}" = 1 ] || [ "${SOFA_SIGN_IDENTITY:-}" = '-' ]; then
    echo 'Certificate previews cannot use ad-hoc signing.' >&2; exit 1
  fi
  if [ "$FIRST_PREVIEW" = 1 ]; then
    if [ -n "${SOFA_PREVIOUS_APP:-}" ]; then
      echo 'Choose a first certificate preview or a previous preview baseline, not both.' >&2; exit 1
    fi
    echo 'First certificate preview: no prior certificate continuity or Accessibility retention is claimed.' >&2
  else
    : "${SOFA_PREVIOUS_APP:?Certificate previews require SOFA_PREVIOUS_APP, or explicit SOFA_FIRST_CERTIFICATE_PREVIEW=1 for the first preview}"
  fi
  MODE=preview
  OUTPUT=build/preview
  BASENAME=Sofa-Remote-preview
  VOLUME='Sofa Remote Preview'
else
  : "${SOFA_SIGN_IDENTITY:?Public packaging requires SOFA_SIGN_IDENTITY}"
  : "${SOFA_TEAM_ID:?Public packaging requires SOFA_TEAM_ID}"
  : "${SOFA_NOTARY_PROFILE:?Public packaging requires SOFA_NOTARY_PROFILE}"
  if [ "$SOFA_SIGN_IDENTITY" = '-' ] || [ "${SOFA_ALLOW_ADHOC:-0}" = 1 ]; then
    echo 'Public packages cannot use ad-hoc signing.' >&2; exit 1
  fi
  [[ "$SOFA_TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] || { echo 'Invalid publisher Team ID.' >&2; exit 1; }
  MODE=release
  OUTPUT=build
  BASENAME=Sofa-Remote
  VOLUME='Sofa Remote'
fi

APP='build/Sofa Remote.app'
test -d "$APP"
VERIFY=(--mode "$MODE" --app "$APP")
if [ "$MODE" = release ]; then VERIFY+=(--team "$SOFA_TEAM_ID"); fi
if [ "$MODE" != development ] && [ -n "${SOFA_PREVIOUS_APP:-}" ]; then
  VERIFY+=(--previous "$SOFA_PREVIOUS_APP")
fi
./scripts/verify-signing.sh "${VERIFY[@]}"

STAGING="$(mktemp -d build/package-staging.XXXXXX)"
trap 'rm -rf "$STAGING"' EXIT
chmod 700 "$STAGING"
ditto "$APP" "$STAGING/Sofa Remote.app"
APP="$STAGING/Sofa Remote.app"
NOTARY=(--keychain-profile "${SOFA_NOTARY_PROFILE:-}")
SIGN=(codesign --force --timestamp --sign "${SOFA_SIGN_IDENTITY:--}")
if [ -n "${SOFA_SIGN_KEYCHAIN:-}" ]; then
  NOTARY+=(--keychain "$SOFA_SIGN_KEYCHAIN")
  SIGN+=(--keychain "$SOFA_SIGN_KEYCHAIN")
fi
notarize() {
  local item="$1" result="$2" staple_target="$3"
  xcrun notarytool submit "$item" "${NOTARY[@]}" --wait --timeout 30m --output-format json > "$result"
  python3 - "$result" <<'PY'
import json, sys
try:
    accepted = json.load(open(sys.argv[1]))["status"] == "Accepted"
except (OSError, ValueError, KeyError, TypeError):
    accepted = False
if not accepted:
    raise SystemExit("Notarisation did not return Accepted; no public package will be produced.")
PY
  xcrun stapler staple "$staple_target"
  xcrun stapler validate "$staple_target"
}

if [ "$MODE" = release ]; then
  ditto -c -k --sequesterRsrc --keepParent "$APP" "$STAGING/notarize.zip"
  # ZIP files cannot be stapled. Staple the accepted app before making final archives.
  notarize "$STAGING/notarize.zip" "$STAGING/app-notary.json" "$APP"
  ./scripts/verify-signing.sh --mode release --app "$APP" --team "$SOFA_TEAM_ID"
fi

mkdir "$STAGING/installer"
ditto "$APP" "$STAGING/installer/Sofa Remote.app"
ln -s /Applications "$STAGING/installer/Applications"
if [ "$MODE" = development ]; then
  cat > "$STAGING/installer/DEVELOPMENT ONLY.txt" <<'INSTALL'
This is a development artifact, not a public update.
It is not Developer ID notarised. Its signing identity may change on every build,
so macOS privacy permissions may reset. Do not publish this as a normal release.
Do not disable Gatekeeper or alter privacy databases to run it.
https://github.com/allamaprabhuani/sofa-remote/blob/main/docs/SIGNING.md
INSTALL
elif [ "$MODE" = preview ]; then
  cat > "$STAGING/installer/README - Certificate Preview.txt" <<'INSTALL'
Sofa Remote — certificate-signed, unnotarised preview

The app has a certificate-backed signature. Its publisher is not verified by
Apple, and this preview is not notarised. Gatekeeper may block first launch;
only choose app-level approval if you trust this download and your macOS or
organisation policy permits it. Do not disable Gatekeeper or install a trusted
root certificate. This disk image is intentionally unsigned; the app inside
is certificate-signed.

Quit an older copy before updating. Drag Sofa Remote into Applications, eject
this disk image, then open the Applications copy. macOS controls Accessibility;
a first change from an ad-hoc signing identity may need a manual grant. Future
previews must use the same certificate-backed identity. Signature continuity
checks do not prove that macOS retained a permission on your particular Mac.

Direct LAN HTTP is unencrypted. Use a trusted network or your own Tailscale
connection. Stop sharing or Quit closes the listener. Never forward the port.
https://github.com/allamaprabhuani/sofa-remote/blob/main/docs/SIGNING.md
INSTALL
else
  cat > "$STAGING/installer/Install Sofa Remote.txt" <<'INSTALL'
Quit an older copy before updating. Drag Sofa Remote into Applications, eject
this disk image, then open it from Applications. macOS controls Accessibility
permission; grant it yourself when prompted. A first move from an ad-hoc build
to this signing identity may require a one-time permission review.

Scan the pairing QR with your phone on a trusted network. Direct LAN HTTP is
unencrypted; use a trusted network or your own encrypted Tailscale connection.
Stop sharing or Quit closes the listener. Never forward the port publicly.
https://github.com/allamaprabhuani/sofa-remote/blob/main/docs/SETUP.md
INSTALL
fi
hdiutil create -volname "$VOLUME" -srcfolder "$STAGING/installer" -ov -format UDZO "$STAGING/$BASENAME.dmg" >/dev/null
if [ "$MODE" = release ]; then
  "${SIGN[@]}" "$STAGING/$BASENAME.dmg"
  codesign --verify --strict "$STAGING/$BASENAME.dmg"
  notarize "$STAGING/$BASENAME.dmg" "$STAGING/dmg-notary.json" "$STAGING/$BASENAME.dmg"
fi
hdiutil verify "$STAGING/$BASENAME.dmg" >/dev/null
ditto -c -k --sequesterRsrc --keepParent "$APP" "$STAGING/$BASENAME.zip"
mkdir -p "$OUTPUT"
mv "$STAGING/$BASENAME.dmg" "$STAGING/$BASENAME.zip" "$OUTPUT/"
(cd "$OUTPUT" && shasum -a 256 "$BASENAME.dmg" "$BASENAME.zip" > SHA256SUMS)
echo "Created $OUTPUT/$BASENAME.dmg, $OUTPUT/$BASENAME.zip and $OUTPUT/SHA256SUMS"
