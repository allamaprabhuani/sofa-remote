# Signing and Accessibility permission

macOS identifies an app using its code-signing requirements, not just its name or location in Applications. An ad-hoc signature identifies a particular build. Rebuilding or updating it can therefore make an earlier Accessibility grant stop applying, even when the settings switch still appears enabled. Apple explains this in [TN3127: Inside Code Signing: Requirements](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements).

Stable certificate-backed signing addresses that identity problem. It does not grant Accessibility, unlock the Mac, or guarantee that macOS will preserve every permission in every circumstance. The owner remains responsible for approving access. Sofa Remote never edits the privacy database, resets permissions with `tccutil`, changes system-wide certificate trust, or grants itself permission.

## Existing ad-hoc downloads

The older public beta downloads through beta 5/build 11 are ad-hoc signed and not Developer ID notarised. They remain experimental builds; their signatures do not provide update identity continuity. Signing safeguards added afterward do not change those previously downloaded files.

The first migration from an ad-hoc build to a certificate-backed build changes identity. Quit the older app before replacing it, open the new copy from Applications and review Accessibility permission yourself. This may require a one-time manual grant. A continuity check correctly rejects the ad-hoc copy as a compatible certificate-backed baseline; weakening the signing requirement is not a migration solution.

After that migration, keep the same signing identity for local updates. Test an actual upgrade after the owner grants permission before claiming that continuity has been verified on a particular Mac. Automated signature tests alone do not establish that macOS retained the permission.

## Local use without a paid developer membership

A local code-signing certificate can provide a stable identity for builds used on your own Mac. This is separate from Developer ID signing and Apple notarisation. A self-signed local build is not verified for public distribution and may still face Gatekeeper restrictions.

Create or approve a suitable local signing identity yourself only if you choose this route. Its private key belongs in your user Keychain. Keep the same key and certificate for subsequent builds; replacing or losing them changes identity. Do not commit, attach, export into the project, or upload that local private key to GitHub or CI. A certificate should be restricted to code signing; do not install a new trusted root or enable blanket trust to make this app work.

The build script looks for the installed app's certificate-backed identity when it is available in your user Keychain, then for the exact local identity label `Sofa Remote Local Signing`. You can select an existing identity explicitly with `SOFA_SIGN_IDENTITY`. If no suitable identity is available, a normal local build fails with guidance rather than silently producing another ad-hoc update.

For a cloud-synchronised checkout, use an existing local compiler-cache directory:

```sh
SOFA_BUILD_DIR=/absolute/existing/local/scratch \
SOFA_SIGN_IDENTITY='Sofa Remote Local Signing' ./build.sh
```

Local certificate builds use no secure timestamp by default. Once a certificate-backed version has been installed and approved, compare future builds with that version:

```sh
SOFA_PREVIOUS_APP='/Applications/Sofa Remote.app' ./build.sh
```

This builds a separate app; it does not replace the running installed copy. Quit Sofa Remote before installing an update. A different certificate, an ad-hoc signature or weakened designated requirement causes the continuity check to fail. Resolve an identity mismatch explicitly rather than repeatedly removing and re-adding Accessibility entries.

## Free certificate-signed previews

A publisher can distribute an explicitly labelled **certificate-signed, unnotarised preview** without an annual Apple developer membership. This is a separate opt-in path from normal Developer ID releases. It provides a certificate-backed code identity, not an Apple-verified publisher or notarisation. [TN2206](https://developer.apple.com/library/archive/technotes/tn2206/) distinguishes designated-requirement tracking from Gatekeeper policy; current [TN3161](https://developer.apple.com/documentation/technotes/tn3161-inside-code-signing-certificates) explains that Gatekeeper blocks non-Apple signing certificates by default.

Gatekeeper may block first launch. A user who trusts the download may choose the app-level approval offered by their macOS version, if their organisation's policy permits it. Do not disable Gatekeeper, install a trusted root, import the publisher's certificate into the user's Keychain, or edit privacy settings databases to make the preview run. Some managed Macs will not allow the preview. The public certificate is already embedded in the app's signature; the private signing key stays on the publisher's Mac and never goes to GitHub or CI.

Build the app with the chosen stable certificate-backed identity using the local build path above. For the first certificate preview only, explicitly bootstrap the preview packaging policy:

```sh
SOFA_CERTIFICATE_PREVIEW=1 SOFA_FIRST_CERTIFICATE_PREVIEW=1 \
./scripts/package-release.sh
```

Do not provide an ad-hoc app as a previous baseline. The first preview has no earlier certificate-backed public baseline and makes no claim that Accessibility permission was retained. Keep its verified app for comparison with the next preview.

For every subsequent preview, provide the previous certificate-signed preview app:

```sh
SOFA_CERTIFICATE_PREVIEW=1 \
SOFA_PREVIOUS_APP='/absolute/path/to/previous-preview/Sofa Remote.app' \
./scripts/package-release.sh
```

Use `SOFA_FIRST_CERTIFICATE_PREVIEW=1` only for that initial preview, never to skip a failed continuity check. Supplying both the first-preview flag and a previous baseline is rejected. Packaging verifies both architectures, hardened runtime, a certificate-backed default designated requirement and, when supplied, identity continuity with the baseline. Ad-hoc, weakened-requirement and changed-identity updates are rejected. Code-signature continuity is separate from a physical test showing that an owner-granted Accessibility permission survives an installed two-version upgrade. Do not claim that physical test passed until it has actually been checked.

Preview packages are `build/preview/Sofa-Remote-preview.dmg`, `Sofa-Remote-preview.zip` and `SHA256SUMS`. The DMG is intentionally **unsigned** and contains the certificate-signed app and an explanatory README. Neither package is notarised; this path invokes no notary service and claims no secure timestamp or Apple trust. The same key and certificate are needed for subsequent preview builds. Key loss, rotation or compromise requires explicit migration review and may require new manual permissions; do not weaken the designated requirement to accept a replacement identity.

Publish these packages manually only as clearly labelled GitHub **prereleases**, using a `preview-v…` tag, for example `preview-v0.1.0-beta.6`. That namespace does not trigger the normal `v*` Developer ID release workflow. Check the exact source commit, signatures and final published checksums before directing users to the download. Never upload the private key or signing Keychain. A public certificate embedded in the app is expected and cannot itself sign a replacement update.

Certificate-preview, development-artifact and public-release modes cannot be combined. There is no automatic fallback from Developer ID publication to previews. The normal CI/tag release path remains strict.

## Developer ID releases

Normal distribution releases require the publisher's Developer ID Application identity, expected Team ID and Apple notarisation credentials. A local self-signed certificate, an Apple Development certificate, or a certificate merely named “Developer ID” cannot satisfy this policy. Users can continue using the app for free; the publishing identity is the developer's distribution responsibility.

For an already configured publisher Keychain:

```sh
SOFA_PUBLIC_RELEASE=1 \
SOFA_SIGN_IDENTITY='Developer ID Application: your publisher identity' \
SOFA_TEAM_ID=YOURTEAMID \
SOFA_NOTARY_PROFILE=sofa-release ./build.sh
```

Pass the same environment values to `./scripts/package-release.sh`. Set `SOFA_SIGN_KEYCHAIN` when the identity and notary profile are in a dedicated Keychain. `SOFA_NOTARY_PROFILE` names an existing `notarytool` profile; no password belongs in source or shell history. For subsequent releases, provide a verified previous signed app through `SOFA_PREVIOUS_APP` to check identity continuity.

Normal packaging (without the explicit certificate-preview or development-artifact flag) fails closed without Developer ID signing and notarisation, including `v*` beta tags. It verifies the app's signing policy, submits it to Apple, requires an explicit `Accepted` result, and staples and validates the app before making the final ZIP. It separately signs, notarises, staples and validates the disk image. Checksums are computed from the final packages. These checks do not replace a fresh-Mac installation and physical upgrade test.

The tag workflow requires these GitHub **Secrets**:

- `SOFA_SIGN_P12_BASE64`: the publisher's Developer ID signing identity, exported as a password-protected P12 and encoded as one base64 value.
- `SOFA_SIGN_P12_PASSWORD`: that P12's password.
- `SOFA_SIGN_IDENTITY`: the exact signing identity selector.
- `SOFA_NOTARY_API_KEY_BASE64`: the publisher's App Store Connect team API private key, encoded as one base64 value.
- `SOFA_NOTARY_KEY_ID` and `SOFA_NOTARY_ISSUER_ID`: the API key's identifiers.

The repository **Variable** `SOFA_TEAM_ID` pins the expected publisher Team ID. Configure these only for a deliberate publisher setup; never put their values in repository files, issues, logs or release assets. Do not upload the personal local-use signing key described above. The publisher's CI identity is separate sensitive material stored in GitHub Secrets.

The workflow fails before compilation if configuration is missing. It imports the publisher identity into a password-protected temporary runner Keychain, writes the API key with mode 0600, scopes the notary profile to that Keychain, and deletes the temporary material in an always-run cleanup step. It does not import into or replace the login Keychain or change certificate trust. Only successfully Developer ID signed and notarised normal release packages can reach this workflow's GitHub publication step. The free preview path above is a separate manual process.

## Development and CI artifacts

Developers and CI can explicitly request an ad-hoc test build:

```sh
SOFA_ALLOW_ADHOC=1 SOFA_SIGN_IDENTITY=- ./build.sh
SOFA_DEVELOPMENT_ARTIFACT=1 ./scripts/package-release.sh
```

These artifacts go only to `build/development/`, use `Sofa-Remote-development` filenames and are labelled **not for distribution** in CI. They are not normal public updates and may lose privacy permission continuity after rebuilding. Combining development-artifact, certificate-preview and public-release modes is rejected. Tests use disposable signature fixtures; they do not launch apps, grant permissions or modify certificate trust.

## Diagnostics and limits

About & Help and the phone diagnostic preview report only `Ad hoc`, `Certificate-signed`, `Unsigned` or `Unknown`. The type is inspected read-only using public Security APIs and cached for the process lifetime. It does not expose certificate subjects, Team IDs, hashes, private keys or designated requirements. `Certificate-signed` does not assert Developer ID, notarisation, trust or permission continuity. Accessibility status is read separately from macOS.

Code-signing certificates do not encrypt the phone connection. Direct LAN HTTP remains unencrypted; use a trusted network or your own Tailscale connection. Never forward the listener's port publicly. Nothing in this signing work enables password storage or lock-screen input.

See [Apple's distribution guidance](https://developer.apple.com/macos/distribution/), [the release guide](RELEASE.md), and [setup help](SETUP.md).
