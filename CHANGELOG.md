# Changelog

## Unreleased — build 17

- Add presenter controls with previous/next, end slideshow, a laser, coloured pen and automatically disappearing highlighter on a chosen display.
- Add optional smoothing and correction for simple hand-drawn shapes.
- Simplify the phone remote to a single dark appearance with borderless controls in one panel; put display power and brightness in Settings, and show local initials beside saved shortcuts.
- Keep presenter traffic authenticated, bounded and rate limited; temporary marks clear on exit, slide navigation and connection loss.
- Presenter controls were tested from an iPhone with Keynote, PowerPoint and Google Slides; other display and sharing configurations need physical testing.

## Certificate preview beta 6 — build 12

- Require stable certificate signing for normal local builds and check update identity across all architectures. Reject ad-hoc updates, changed signers, modified signatures and weakened requirements.
- Reserve normal public release packaging for verified Developer ID and notarisation. Keep explicit certificate-signed previews and ad-hoc CI artifacts separate.
- Publish a standalone app site and an independent Homebrew tap; retain licence notices without a front-facing origin line.
- Report only the signing category in setup/help and reviewed diagnostics; preserve all mouse, keyboard, pairing and network controls.

## 0.1.0-beta.5 — 2026-11-01

Build 11. Ad-hoc signed, not Developer ID notarised.

- Put a working, seven-theme remote preview at the top of the static website. Replace blue gradients and repeated device mockups with a neutral layout, clearer type and simpler download controls.
- Refine native setup and monochrome help actions. Show denied Accessibility, stopped sharing, server startup and paused input separately. Add an explicit permission-status refresh.
- Make diagnostic input status reflect permission and sharing state on Mac and phone, without collecting additional personal data.
- Keep the existing pointer handling, authentication, transport and seven local phone themes.

## 0.1.0-beta.4 — 2026-11-01

Build 10. Ad-hoc signed, not Developer ID notarised.

- Replace blue remote surfaces with seven local themes: Dark (default), Black, Light, Ivory, Plum, Ocean and Custom. Dark and Light take inspiration from VS Code’s built-in modern palettes; Black uses black surfaces with visible outlines.
- Migrate saved Imperial/Oxford themes to Dark; retain Ocean, Light and custom colour choices.
- Add solid local icons for common actions, a rounded system heading and clearer captions. Keep all beta 3 icon/help improvements. No changes to input transport or mouse handling.

## 0.1.0-beta.3 — 2026-11-01

Build 9. Ad-hoc signed, not Developer ID notarised.

- Replace the six main help links with rounded local icons on Mac and phone; retain accessible names and Mac tooltips.
- Collapse diagnostics and secondary help/privacy details until requested.
- Refine the static blue product website, typography, download controls and optional Ko-fi link.
- Record a presentation-remote survey; presenter mode remains future work.

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
