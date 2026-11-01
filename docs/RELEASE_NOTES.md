Sofa Remote is a free, MIT-licensed Mac helper that turns a phone browser into a touchpad, keyboard and media remote. There is no screen streaming, screen recording, analytics, advertising, account requirement or subscription.

This public beta includes the Mac TV-inspired pointer improvements, fractional movement, short-lived pointer tracking across displays, and fewer requests for accelerated swipes. Occasional pointer stepping or acceleration changes remain a known issue; native-trackpad smoothness is not claimed.

New in this beta:

- About & Help on Mac and phone: setup, developer contact, bug/feature reports, privacy, licences, credits, source and manual update checking.
- Allowlisted diagnostic summaries that you preview before copying. No automatic uploads, typed text, pairing tokens, personal URLs, screenshots, device names or input history.
- A setup walkthrough, disposable practice window and clearer connection/permission recovery instructions.
- Optional menu-bar icon hiding. Reopen Sofa Remote from Applications to show its controls and restore the icon. Hiding the icon keeps sharing running; Stop sharing and Quit end remote access.
- Drag-to-Applications DMG and ZIP downloads with SHA-256 checksums, support/community guides, known issues and an expanded manual test matrix.
- Improved accessibility labels, dialog focus handling and phone layouts.

Requires macOS 14 or later, Apple silicon or Intel, and Accessibility permission. Download the DMG, drag Sofa Remote to Applications, open it and scan the pairing QR with your phone on the same trusted network. Existing users should quit the old helper before replacing it; normal upgrades preserve settings and paired phones.

**Signing:** these GitHub-built preview downloads are ad-hoc signed, not Developer ID notarised. macOS may block first launch. Do not disable Gatekeeper. Source builds and setup instructions are in the README. The repository includes an optional Developer ID/notarisation packaging path for a publisher with their own signing identity.

**Network and power:** direct LAN HTTP is unencrypted. Use a trusted private network or your own Tailscale connection; do not forward the port publicly. The Mac must remain awake and reachable. Wake screen does not unlock the Mac or wake a sleeping system. Keep Mac awake deliberately prevents idle system sleep while sharing.

Automated tests and release verification are recorded in CI. Broader fresh-Mac, multiple-phone, Safari/VoiceOver, Wi-Fi-change, display-reconnection and lock-state acceptance checks remain documented manual work. Physical checks on the owner's setup do not establish compatibility with every Mac, phone or streaming provider.

Questions: https://github.com/allamaprabhuani/sofa-remote/discussions

Bugs/features: https://github.com/allamaprabhuani/sofa-remote/issues

Security reports: https://github.com/allamaprabhuani/sofa-remote/security/advisories/new
