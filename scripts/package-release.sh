#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP='build/Sofa Remote.app'
test -d "$APP"
codesign --verify --deep --strict "$APP"
STAGING="$(mktemp -d build/package-staging.XXXXXX)"
trap 'rm -rf "$STAGING"' EXIT
ditto "$APP" "$STAGING/Sofa Remote.app"
APP="$STAGING/Sofa Remote.app"

# Credentials stay in the publisher's keychain. No account/password is bundled.
# Ad-hoc builds are deliberately allowed for clearly labelled preview releases.
if [ -n "${SOFA_NOTARY_PROFILE:-}" ]; then
  : "${SOFA_SIGN_IDENTITY:?Set SOFA_SIGN_IDENTITY to your Developer ID Application identity}"
  codesign -dv --verbose=4 "$APP" 2>&1 | /usr/bin/grep -q 'Authority=Developer ID Application:' || {
    echo 'Notarization requires a Developer ID Application signed build.' >&2; exit 1;
  }
  ditto -c -k --sequesterRsrc --keepParent "$APP" "$STAGING/notarize.zip"
  xcrun notarytool submit "$STAGING/notarize.zip" --keychain-profile "$SOFA_NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"
  xcrun stapler validate "$APP"
fi

mkdir "$STAGING/installer"
ditto "$APP" "$STAGING/installer/Sofa Remote.app"
ln -s /Applications "$STAGING/installer/Applications"
cat > "$STAGING/installer/Install Sofa Remote.txt" <<'INSTALL'
Drag Sofa Remote into Applications, then open it from Applications.
Quit an older copy before replacing it. Grant Accessibility when asked,
scan the pairing QR with your phone on the same trusted network, and
optionally save the remote to your phone's Home Screen.

Preview builds without Developer ID notarization may be blocked by macOS.
Do not disable Gatekeeper. See the release page and source-build guide:
https://github.com/allamaprabhuani/sofa-remote

Direct LAN HTTP is unencrypted. Use a trusted network or your own Tailscale
connection. Stop sharing or Quit closes the listener.
INSTALL
hdiutil create -volname 'Sofa Remote' -srcfolder "$STAGING/installer" -ov -format UDZO "$STAGING/Sofa-Remote.dmg" >/dev/null
if [ -n "${SOFA_NOTARY_PROFILE:-}" ]; then
  codesign --force --timestamp --sign "$SOFA_SIGN_IDENTITY" "$STAGING/Sofa-Remote.dmg"
  xcrun notarytool submit "$STAGING/Sofa-Remote.dmg" --keychain-profile "$SOFA_NOTARY_PROFILE" --wait
  xcrun stapler staple "$STAGING/Sofa-Remote.dmg"
  xcrun stapler validate "$STAGING/Sofa-Remote.dmg"
fi
hdiutil verify "$STAGING/Sofa-Remote.dmg" >/dev/null
ditto -c -k --sequesterRsrc --keepParent "$APP" "$STAGING/Sofa-Remote.zip"
mv "$STAGING/Sofa-Remote.dmg" "$STAGING/Sofa-Remote.zip" build/
(cd build && shasum -a 256 Sofa-Remote.dmg Sofa-Remote.zip > SHA256SUMS)
echo 'Created build/Sofa-Remote.dmg, build/Sofa-Remote.zip and build/SHA256SUMS'
