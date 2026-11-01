# Privacy

Sofa Remote sends mouse, keyboard and control requests from your phone to your Mac. It does not stream the screen or collect input history, screenshots, screen/audio recordings, analytics or a cloud account. It does not read browser profiles or upload app data. The developer does not receive remote input or diagnostics automatically.

## Data kept on your devices

The Mac stores settings, saved shortcut names/addresses, optional display preference and paired-device records in `~/Library/Application Support/Sofa Remote`. Phone names are local pairing labels. Each phone receives a random secret; only its SHA-256 digest is kept on the Mac. The phone browser keeps the secret in that origin's local storage. Anyone able to copy that browser storage may obtain access until you revoke it.

Requests necessarily carry the input/website address you ask the Mac to use. Direct LAN HTTP is **unencrypted**: a hostile network participant may observe or alter traffic. Authentication does not encrypt it. Use a trusted network or your own Tailscale encrypted transport; see [Security](../SECURITY.md).

## Diagnostics and support

About & Help provides a preview and explicit Copy action. The allowlist contains app version/build, macOS version, CPU architecture on the Mac, browser family/version on the phone, Accessibility permission and sharing/input-paused status. It excludes typed text, pairing codes/secrets, network addresses, device/computer names, personal URLs, app names, screenshots and raw browser user-agent strings. Nothing is uploaded automatically. Review the summary and any description before posting; GitHub issues and discussions are public and use GitHub's own service policies.

Manual Check for updates, guide, licence, source and support links open GitHub in your browser. GitHub receives an ordinary web request when you choose those links. The app has no periodic update service. Existing browsers/players and optional Tailscale operate under their own privacy policies.

## Stop and delete

Stop sharing or Quit closes the listener and connections. Revoking a phone invalidates its secret permanently; stopping sharing preserves pairings for later. Remove local app settings and the phone's stored site data only if you want to reset them. See [uninstall instructions](SETUP.md#remove-access-or-uninstall).

No independent privacy/security audit is claimed. Report a suspected leak [privately](https://github.com/allamaprabhuani/sofa-remote/security/advisories/new); see [SECURITY.md](../SECURITY.md).
