# Sofa Remote

Your iPhone is the mouse and keyboard. Your Mac does the playing.

A free, MIT-licensed Mac menu-bar helper and phone-browser remote. No screen streaming, Screen Recording permission, accounts, ads, analytics, subscriptions, or cloud relay. Keep using Brave for websites and IINA for movies and subtitles.

**Experimental v0.1.** Direct local HTTP is **unencrypted**. Use a trusted private network or your own Tailscale connection. Do not expose the listener through router port forwarding. This is not an internet remote-desktop service. See [SECURITY.md](SECURITY.md).

## What it does

- Touchpad movement, tap/click, right/double click, drag, and two-finger scrolling.
- Unicode text, modifier keys and keyboard shortcuts; app switcher, Spotlight, media keys, volume and mute.
- Open a website in installed Brave, falling back to your default browser; launch saved app/website shortcuts and reorder them.
- Open Downloads in Finder. Browse files and use IINA's own playback/subtitle tools with normal mouse and keyboard input.
- Select any connected display by its real name. Selection moves the pointer there; **Move front window to display** is a separate explicit action, with bounded fullscreen handling.
- Request display off/wake while the Mac remains awake; optional idle-system-sleep prevention while sharing.
- Lock the Mac deliberately. After using Lock, unlock on the Mac and choose **Resume input on this Mac** in Sofa Remote.
- Pair individual phones, revoke them, and stop sharing from the Mac. Stop sharing and Quit close the listener and release held remote drag input.

There is no custom video player, file server, subtitle service or shell-command endpoint. Your browser and player keep their usual sign-ins and settings. This does not add ad blocking or guarantee streaming-service compatibility.

## Requirements

- macOS 14 or later, Apple silicon or Intel.
- A phone browser on the same private network; a USB cable or Bluetooth-only connection is not implemented.
- Accessibility permission for pointer, keyboard, media-key and window controls. **Screen Recording is not requested.**
- The Mac must be awake and reachable. Wake screen is not system wake, TV hardware power, or unlock. Sharing an Apple Account with an iPhone does not implement automatic Mac unlock here; Apple Watch Auto Unlock is a separate macOS feature.

## Build and use

Requires a current Swift toolchain/Apple command-line tools on the Mac. No package dependencies, npm install, iOS build, App Store purchase or paid developer account is needed to build locally.

```sh
git clone https://github.com/allamaprabhuani/sofa-remote.git
cd sofa-remote
./build.sh
open 'build/Sofa Remote.app'
```

The build produces one arm64/x86_64 app. On cloud-synchronised checkouts, point `SOFA_BUILD_DIR` to an existing local scratch directory to keep the compiler database off the cloud drive:

```sh
SOFA_BUILD_DIR=/absolute/local/scratch ./build.sh
```

1. Open Sofa Remote from its menu-bar cursor icon. Allow Accessibility in **System Settings → Privacy & Security → Accessibility** if requested.
2. Click **Show pairing code**. Scan the QR on your phone, or open the displayed address and enter its six-digit code. Pairing expires after five minutes and ends when this window closes.
3. Add the phone page to your Home Screen if you like. The large area is your touchpad; keyboard, shortcuts and settings open in sheets.
4. Choose the TV display in the phone's settings. Use **Move front window to display** when you need to relocate an app, then **Full screen**.
5. Close the settings window to keep sharing running. Use **Stop sharing** or **Quit Sofa Remote** to end access. Open at login and Keep Mac awake are optional and off by default.

The app uses one TCP listener, on the first available port in 8740–8749. The phone polls state only while visible; input is coalesced and bounded. It does not inspect the screen or record keystrokes.

Downloaded beta builds are ad-hoc signed, **not Developer ID notarized**. macOS may block their first launch. Building the source locally is the development path; a notarized public download is not claimed. A publisher can set `SOFA_SIGN_IDENTITY` when building with their own signing identity. Never replace a running app bundle during an update.

## Testing and limits

```sh
./scripts/test.sh
```

Swift tests cover pairing and revocation, real loopback HTTP, parser/origin limits, persistence, command validation, display geometry, and input-event sequencing with a fake event sink. Browser tests use an isolated Chrome/Brave profile and mocked API at six portrait/landscape sizes. They do not open a real provider or type into your documents.

For manual input testing, launch a locally built app with `--input-fixture`; it creates a disposable text/click window. Use `SOFA_REMOTE_DATA_DIR=/absolute/test/folder` to isolate settings and pairing. Close other copies before testing. This flag is optional, writes no document and does not grant permissions.

Physical iPhone Safari gestures, provider playback, display reconnection and manually locked-screen behaviour need real-device testing. macOS secure input and session signals pause control, but they are not a proven universal lock-state detector. This release does not offer lock-screen typing or automatic unlock. See [the manual checklist](docs/TESTING.md).

## Contribute

Small fixes and reproducible issues are welcome. Keep the product input-only: improve gestures, reconnect behaviour, accessibility, platform compatibility and transport safety before expanding scope. No screenshots, passwords, tokens, personal URLs, app data or logs containing them in issues or PRs. Report vulnerabilities privately as described in [SECURITY.md](SECURITY.md).

Copyright © 2026 Allamaprabhu Ani. Selected pairing, networking and wake code is adapted from [Mac TV](https://github.com/Arunprakaash/mac-tv), copyright © 2026 Arunprakaash. Original MIT attribution is retained in [LICENSE](LICENSE) and [NOTICE](NOTICE). Personal shortcuts belong in local settings and are not public defaults.
