Sofa Remote is a free, MIT-licensed Mac helper that turns a phone browser into a touchpad, keyboard and media remote. There is no screen streaming, screen recording, analytics, advertising, account requirement or subscription.

This public beta includes the pointer improvements, fractional movement, short-lived pointer tracking across displays, and fewer requests for accelerated swipes. Occasional pointer stepping or acceleration changes remain a known issue; native-trackpad smoothness is not claimed.

New in certificate preview beta 10 (build 34):

- Arrow keys and Return on the main remote; hold navigation and editing keys to repeat, release to stop.
- Hold to speak sends Right Option to a compatible dictation tool on the Mac; audio stays with that tool on the Mac.
- App-specific presentation shortcuts and a connection check. PowerPoint controls were tested on the owner’s iPhone; app-specific controls for Keynote and Google Slides need further checks.
- The Spotlight shortcut was removed after remote typing failed in Spotlight on the tested Mac.

New in certificate preview beta 9 (build 26):

- Cleaner phone remote, three appearances, bottom keyboard, and simplified Settings and Shortcuts.
- Swipe from the main remote surface, including over controls; deliberate taps still activate buttons. The controls fade while pointing.
- Brave's shortcut requests a new window; the owner confirmed it works on their Mac. The address field supports Google search.
- Automated tests cover gesture and control interactions; further physical-device testing is needed across devices and network conditions.

New in certificate preview beta 7 (build 18):

- A single dark remote with a large touchpad and borderless controls, a compact Settings panel, local shortcut initials and a native touchpad double-click gesture.
- Slideshow controls, a temporary laser, coloured pen and disappearing highlighter; optional line smoothing and correction for near-straight lines and circles. Marks are not saved to slides or streamed to the phone.
- Mac brightness-key controls and safer ordering of rapid screen-off/wake requests. Display support varies; waking cannot unlock macOS.
- Presenter controls were exercised with an iPhone and Keynote, PowerPoint and Google Slides. The revised layout passed phone testing; screen-sharing and other display configurations remain to be checked.

New in certificate preview beta 6 (build 12):

- Persistent certificate signing for local updates, with strict signature and update-identity checks. The first move from an ad-hoc build may need one manual Accessibility review. This preview remains unnotarised and is not an Apple-verified distribution.
- Signing status in Mac and phone help/diagnostics, and a free local signing guide.
- Separate public app website and a Homebrew cask in our independent tap.
- Disposable signing regression fixtures; ordinary release packaging now requires Developer ID and successful notarisation.

Earlier beta 5 (build 11; its multi-theme controls have since been removed):

- A working remote preview and all seven theme choices at the top of the static website, with a neutral palette, clearer typography and simpler navigation/download controls.
- Refined native setup and monochrome help icons. Input status distinguishes missing Accessibility permission, stopped sharing, startup and paused input. Check again re-reads permission; it does not grant access.
- Mac and phone diagnostics report blocked or stopped input accurately, without expanding the diagnostic data collected. Pointer handling, authentication and transport are unchanged.

Earlier beta 4 (build 10; its multi-theme controls have since been removed):

- Neutral and custom phone themes were introduced; beta 7 replaces them with a single dark interface.

Also included from beta 3:

- Compact, accessible icon links in About & Help on Mac and phone, with diagnostics and secondary details collapsed.
- A redesigned static product website and optional Ko-fi support link.

Also included from beta 2:

- Local SVG icons with accessible names and short labels for ambiguous controls.
- A local theme system with a custom colour picker; replaced by the single dark interface in beta 7.
- Targeted double-tap zoom prevention while keeping pinch zoom outside the touchpad. The owner verified the beta 7 double-tap gesture on an iPhone.
- Project/developer website and support links on Mac and phone, plus clear bug-report access.
- A minimalist static introduction/download website, initially written by Claude, with an interactive browser-only demo. No framework, analytics or embedded checkout.

Existing About & Help, reviewed diagnostics, setup/practice, manual updates and menu-bar hiding remain. Support links open the project website. The app remains free.

Requires macOS 14 or later, Apple silicon or Intel, and Accessibility permission. Download the DMG, drag Sofa Remote to Applications, open it and scan the pairing QR with your phone on the same trusted network. Existing users should quit the old helper before replacing it; normal upgrades preserve settings and paired phones.

**Signing:** beta 10 is certificate-signed, not Apple-verified or Developer ID notarised. macOS may block first launch. Do not disable Gatekeeper. Source builds and setup instructions are in the README. The repository includes an optional Developer ID/notarisation packaging path for a publisher with their own signing identity.

**Network and power:** direct LAN HTTP is unencrypted. Use a trusted private network or your own Tailscale connection; do not forward the port publicly. The Mac must remain awake and reachable. Wake screen does not unlock the Mac or wake a sleeping system. Keep Mac awake deliberately prevents idle system sleep while sharing.

Automated tests and release verification are recorded in CI. Broader fresh-Mac, multiple-phone, Safari/VoiceOver, Wi-Fi-change, display-reconnection and lock-state acceptance checks remain documented manual work. Physical checks on the owner's setup do not establish compatibility with every Mac, phone or streaming provider.

Questions: https://github.com/allamaprabhuani/sofa-remote/discussions

Bugs/features: https://github.com/allamaprabhuani/sofa-remote/issues

Security reports: https://github.com/allamaprabhuani/sofa-remote/security/advisories/new
