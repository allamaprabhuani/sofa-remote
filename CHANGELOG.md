# Changelog

## 0.1.0-beta.2 — 2026-11-01

Build 8. Ad-hoc signed, not Developer ID notarised.

- Add clear local SVG controls, accessible labels and four phone themes: Imperial blue, Light, Ocean and Custom. Theme choice stays in the browser.
- Suppress accidental double-tap zoom on remote controls and short touchpad taps, while preserving pinch zoom outside the pad. Automated Chromium touch checks pass; physical iPhone Safari confirmation remains separate.
- Add project/developer website and support links on Mac and phone, plus an easy-to-find bug-report link.
- Publish a static introduction/demo/download website on GitHub Pages, initially authored by Claude and reviewed during integration. No web frameworks, analytics or embedded payment widgets.

Existing trusted-network, Accessibility, awake-Mac and pointer-jitter limits remain.

## 0.1.0-beta.1 — 2026-11-01

Public beta, build 7. Not Developer ID notarised.

- Bring the physically tested pointer shaping and short-lived cursor-position tracking into the public download. Preserve fractional movement and reduce unnecessary requests during larger accelerated moves.
- Add About & Help, version/developer information, setup/recovery guides, bug and feature links, privacy, licences and manual update checking on Mac and phone.
- Add a diagnostic preview with explicit copy and an allowlist that excludes input, credentials, personal URLs and network/device identifiers.
- Add a menu-bar icon visibility preference and reopen-to-settings behaviour.
- Improve first-use guidance, keyboard/VoiceOver descriptions and phone sheet accessibility.
- Add a drag-to-Applications disk image, release packaging/checksums and publisher signing/notarisation instructions.
- Add issue templates, support/contribution guidance, known issues and a manual reliability matrix.

Occasional pointer stepping or speed changes remain. Broader hardware/OS/network tests are pending; this is not a production-readiness or independent security-audit claim. Direct LAN HTTP remains unencrypted; use a trusted network or Tailscale.

## 0.1.0-alpha.2 — 2026-11-01

- Experimental input-only universal Mac helper and phone browser remote.
- Touchpad/keyboard/media input, shortcuts, display selection/window moves, pairing/revocation and display off/wake requests.
- Refresh the paired-device list after revocation and record a bounded disposable-window keyboard check.

## 0.1.0-alpha.1 — 2026-11-01

- Initial experimental preview.
