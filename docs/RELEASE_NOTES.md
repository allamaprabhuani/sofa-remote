Sofa Remote is a free, MIT-licensed Mac helper that turns a phone browser into a touchpad, keyboard and media remote. There is no screen streaming, screen recording, analytics, advertising, account requirement or subscription.

This public beta includes the Mac TV-inspired pointer improvements, fractional movement, short-lived pointer tracking across displays, and fewer requests for accelerated swipes. Occasional pointer stepping or acceleration changes remain a known issue; native-trackpad smoothness is not claimed.

New in beta 5 (build 11):

- A working remote preview and all seven theme choices at the top of the static website, with a neutral palette, clearer typography and simpler navigation/download controls.
- Refined native setup and monochrome help icons. Input status distinguishes missing Accessibility permission, stopped sharing, startup and paused input. Check again re-reads permission; it does not grant access.
- Mac and phone diagnostics report blocked or stopped input accurately, without expanding the diagnostic data collected. Pointer handling, authentication and transport are unchanged.

Included from beta 4 (build 10):

- Neutral Dark, true Black, Light, Ivory/brown, Ivory/plum, Ocean and Custom phone themes. The earlier blue theme migrates to Dark; saved custom colours stay available.

Also included from beta 3:

- Compact, accessible icon links in About & Help on Mac and phone, with diagnostics and secondary details collapsed.
- A redesigned static product website and optional Ko-fi support link.

Also included from beta 2:

- Local SVG icons with accessible names and short labels for ambiguous controls.
- A local theme system with a safe custom colour picker, now expanded to seven choices. Choices stay on the phone; no dependencies or extra network requests.
- Targeted double-tap zoom prevention while keeping pinch zoom outside the touchpad. Chromium touch tests verify two taps produce exactly two clicks; physical Safari confirmation is still required.
- Project/developer website and support links on Mac and phone, plus clear bug-report access.
- A minimalist static introduction/download website, initially written by Claude, with an interactive browser-only demo. No framework, analytics or embedded checkout.

Existing About & Help, reviewed diagnostics, setup/practice, manual updates and menu-bar hiding remain. Support links open the project website. The app remains free.

Requires macOS 14 or later, Apple silicon or Intel, and Accessibility permission. Download the DMG, drag Sofa Remote to Applications, open it and scan the pairing QR with your phone on the same trusted network. Existing users should quit the old helper before replacing it; normal upgrades preserve settings and paired phones.

**Signing:** these GitHub-built preview downloads are ad-hoc signed, not Developer ID notarised. macOS may block first launch. Do not disable Gatekeeper. Source builds and setup instructions are in the README. The repository includes an optional Developer ID/notarisation packaging path for a publisher with their own signing identity.

**Network and power:** direct LAN HTTP is unencrypted. Use a trusted private network or your own Tailscale connection; do not forward the port publicly. The Mac must remain awake and reachable. Wake screen does not unlock the Mac or wake a sleeping system. Keep Mac awake deliberately prevents idle system sleep while sharing.

Automated tests and release verification are recorded in CI. Broader fresh-Mac, multiple-phone, Safari/VoiceOver, Wi-Fi-change, display-reconnection and lock-state acceptance checks remain documented manual work. Physical checks on the owner's setup do not establish compatibility with every Mac, phone or streaming provider.

Questions: https://github.com/allamaprabhuani/sofa-remote/discussions

Bugs/features: https://github.com/allamaprabhuani/sofa-remote/issues

Security reports: https://github.com/allamaprabhuani/sofa-remote/security/advisories/new
