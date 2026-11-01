# Known beta issues

- **Pointer feel:** occasional stepping, lag or speed changes remain on the tested iPhone/Wi-Fi setup. Mac TV-style shaping improved the owner's experience, but native-trackpad smoothness is not established. Use the bug form with the affected gesture and versions; do not assume a new transport is the fix.
- **First launch:** public beta downloads are ad-hoc signed, not Developer ID notarised. macOS may block them. See [Setup](docs/SETUP.md). Do not disable Gatekeeper globally.
- **Network:** direct HTTP is unencrypted and intended only for a trusted private network. Guest/hotel Wi-Fi may isolate devices. Tailscale IP links work only when both devices are connected to the same permitted tailnet. Network/IP changes may require scanning the Mac's current QR again.
- **Sleep and unlock:** a sleeping/unreachable Mac cannot receive Wake screen. Display sleep can trigger macOS lock; unlock on the Mac. Lock/session signals are conservative and have not been verified for every manually locked state. Stop sharing when the desktop is unattended.
- **Browser clipboard:** HTTP pages may not have clipboard API access. Select and copy the diagnostic preview manually when the phone reports that copying is unavailable.
- **Display/window control:** native fullscreen transitions, unplug/reconnect races and every third-party window have not been verified. A refused move should leave control with the owner; use a disposable test window when reporting it.
- **Media:** global media keys follow macOS/app behaviour. Provider sign-ins, DRM, subtitles and ad blocking remain the responsibility of the existing browser/player.
- **Accessibility:** labels and touch targets are improved, but a complete real-device VoiceOver and large-text audit is pending.
- **Updates:** Check for updates opens release information manually. There is no automatic downloader/installer or silent background update check.

See [the validation matrix](docs/TESTING.md) for recorded and pending checks. Report problems through [Support](SUPPORT.md).
