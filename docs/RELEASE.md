# Publishing a release

Keep the app free and MIT-licensed. Building locally does not require a paid developer account. A smooth public Gatekeeper experience needs the publisher's Developer ID signing identity and Apple notarisation setup; those cannot be replaced by an ad-hoc signature.

## Build and package

1. Start with a clean tree, review the changelog, and set marketing version/build in `Info.plist`.
2. Run `./scripts/test.sh`. Use an established local `SOFA_BUILD_DIR` when the checkout is cloud-synchronised.
3. Run `./build.sh`, then `./scripts/package-release.sh`. The package script produces the drag-to-Applications disk image, ZIP and SHA256SUMS from `build/Sofa Remote.app`.
4. Verify both architectures, code signature, bundled licences/icon, archive/checksums and a mounted disk image. Quit before updating an installed bundle. Test the actual downloaded artifact after publication, not just a local build.

Normal public releases require `SOFA_PUBLIC_RELEASE=1`, `SOFA_SIGN_IDENTITY` (Developer ID Application), `SOFA_TEAM_ID` and `SOFA_NOTARY_PROFILE`. Set `SOFA_SIGN_KEYCHAIN` if needed. Missing credentials fail before compilation; ad-hoc signatures cannot be normal public updates. Keep publisher credentials in Keychain/CI secrets and never put them in source, issue reports or command output.

A free, explicitly selected certificate-signed preview route is described in [Signing](SIGNING.md). It keeps the private signing key on the publisher’s Mac, uses the same certificate across updates, and is not Apple-notarised or Apple-verified publisher identity. Gatekeeper or managed-device policy may block it. Use a `preview-v…` tag and mark it prerelease; it does not use the normal `v*` publishing workflow. Older ad-hoc beta files remain experimental and do not acquire stable identity retroactively.

CI’s explicit ad-hoc development artifacts are separate, differently named files. Do not publish them as updates or call a signature-integrity check a Gatekeeper/notarisation pass.

## Publish and verify

The tag workflow handles `v*` release builds. Check its tests/packaging and the exact source commit. Mark experimental versions as prereleases, include known issues and evidence/limits in the notes, and attach the DMG, ZIP and checksums. Make download links point at the intended prerelease; GitHub's generic latest-release link may skip prereleases.

After publishing, download to a disposable directory, compare published hashes, inspect architectures and signature, and mount the DMG to confirm the Applications link and app. Record release URL/source SHA and the checks actually performed. Gatekeeper launch on a clean Mac, phone gestures, upgrade permissions, wake/lock and other physical checks remain separate.

Update the download link, changelog and validation matrix. Retain source history and a verified installed app before clearing generated build directories. Do not delete personal settings/pairings as build cleanup.

## Update policy

The current app provides manual release links only. No updater polls, silently downloads or replaces the app. A future signed automatic updater should use a reviewed standard framework and require explicit policy/security review; it is not part of this beta.

## Encrypted transport investigation

Tailscale IP links provide the currently documented encrypted network option. Native HTTPS pairing would need a certificate trust/renewal plan compatible with iPhone Safari and changing local addresses; a self-signed warning is not a usable solution. Browser WebCrypto also has secure-context constraints, and application-layer encryption needs a reviewed authenticated protocol and key lifecycle. No new cryptographic protocol, certificate installer or HTTPS endpoint is claimed by this release. Revisit this work with a specific threat model and usability prototype before broad promotion beyond trusted-network beta users.

## Website and Homebrew

The primary public app site is <https://sofa-remote.doublehoney1.chatgpt.site/>. Its public static source is `site/`; `./scripts/build-site.sh` copies only those assets into ignored `dist/`. `.openai/hosting.json` preserves the existing Sites project identity. Publish through the Sites source/version/deployment workflow for that ID; do not register a replacement site. The GitHub Pages URL remains a compatible mirror and its canonical metadata points to the primary site. Never package app settings, build outputs or signing credentials as website assets.

The independent [Homebrew tap](https://github.com/allamaprabhuani/homebrew-tap) contains `Casks/sofa-remote.rb`. After publishing and independently downloading an intended release, update the cask version, exact asset URL and SHA-256 checksum. Run `ruby -c` and `brew style` on the cask, then verify `brew fetch --cask` without installing over a running helper. Keep preview/Gatekeeper caveats; never strip quarantine in a cask. This is separate from acceptance into Homebrew's official catalogue.
