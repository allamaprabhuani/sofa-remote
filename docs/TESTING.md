# Validation and manual acceptance

## Beta 5 UI checks

The local integration run passed 34 Swift tests plus transport and mocked-browser checks. Isolated Playwright CLI checks covered all seven website preview themes, custom colour, pointer and keyboard interaction, 44-pixel controls, 320/390/768/1440-pixel layouts, 200% text reflow, reduced motion and a JavaScript-disabled download/setup fallback. These are Chromium checks. Physical iPhone Safari, VoiceOver and fresh installation/permission acceptance remain separate. The UI reports permission denial; it does not grant access.

Automated checks use fake input sinks, loopback connections and isolated browser profiles. They do not prove physical iPhone smoothness, third-party playback or every macOS permission/session state. Manual input checks must use empty/disposable windows; never type into personal documents. Use isolated data on a test account/VM for fresh-install, upgrade or corrupt-settings checks, rather than replacing the owner's pairing/settings files.

## Recorded evidence before the public-beta release

On 1 November 2026, a bounded authenticated local-client check sent Unicode text (including emoji) and Enter into the disposable native fixture. Revocation returned HTTP 401 and Stop sharing closed the listener. These establish that event path and lifecycle on the tested Mac only.

A physical iPhone then confirmed QR pairing, pointer movement and clicks, explicit window movement to both displays, and display off/wake with Keep Mac awake enabled. macOS required Touch ID afterwards. Later changes freed the pointer across both displays. With Mac TV-style shaping and a short-lived pointer anchor, the owner reported smoother movement. After the request-count optimisation, the owner still reported occasional tiny lag or acceleration changes and considered it acceptable for their use. These observations are subjective and do not establish native-trackpad smoothness.

Before the public-beta UI work, local/CI Swift and browser checks passed for the pointer changes. They cover proportional/fractional travel, packet validation, serial transport, cancellation and stale-click prevention. A separate WebSocket experiment felt worse on the physical phone despite passing loopback tests; it is not part of the installed beta path.

Short normal-background samples on the tested Mac showed 0.0% sampled idle CPU, approximately 60–63 MiB RSS, one TCP listener and an approximately 3.8 MiB app bundle. These are short observations of the earlier build, not an energy benchmark or a promise for every Mac. Brave/IINA and test-browser resource use is separate. Keep Mac awake intentionally prevents idle system sleep.

## Beta 2 automated touch and theme checks

On 1 November 2026, the beta 2 source passed all 33 Swift tests and browser/transport checks. Trusted touch input in an isolated Chromium mobile emulator verified that a double tap on the pad and a repeated right-click control generated exactly two commands at visualViewport scale 1; two-finger scrolling still worked, and pinch zoom outside the pad increased scale. This is browser-emulation evidence, not a physical iPhone Safari acceptance result. All four themes, saved reload/legacy fallbacks, custom-colour validation/contrast, accessible SVG controls, six viewport sizes and 200% text checks passed. No input transport/gain/authentication changes or new runtime dependencies were introduced.

## Release-candidate checklist

Record app/build, macOS, phone/browser, network type, result and a reproduction without identifiers or private content. A prior-build observation does not automatically accept a new build. CI results and physical results should be reported separately in release notes.

| Scenario | Acceptance criterion | Physical status before beta publication |
| --- | --- | --- |
| Fresh installation | Actual downloaded app opens on a clean supported Mac; permission guide identifies the installed copy; no Screen Recording prompt. | Clean-machine/Gatekeeper check pending; beta not notarised. |
| First-run QR and guide | Permission → QR → disposable pointing/click → Home Screen instructions can be followed without assistance. | Earlier pairing confirmed; new walkthrough needs external testers. |
| Hidden icon and reopen | Hide icon; reopen from Applications; setup and Show menu bar icon remain accessible; hiding does not stop sharing. | New beta behaviour needs device check. |
| Upgrade from alpha | Quit before replacement; previous pairings/settings survive; new preferences default correctly; Accessibility recovery instructions work. | Isolated upgrade and real permission check pending. |
| Multiple phones | Pair two independent clients; revoke one without invalidating the other; no privilege upgrade. | Automated pairing/revocation coverage; two physical phones pending. |
| Reload/background/reconnect | No stale queued click/text/drag is replayed after timeout, phone backgrounding or reconnect. | Automated queue checks; extended Safari checks pending. |
| Wi-Fi/address change | Old connection reports failure; current QR recovers; instructions explain stale Home Screen address. | Manual Wi-Fi/IP-change check pending. |
| Gesture precision | Slow motion, quick swipe, tap, two-finger tap/scroll, drag/hold/cancel; every drag releases. | Basic pointing/click confirmed earlier; slight jitter remains; full gesture sweep pending. |
| Keyboard | Unicode, Enter/Escape/Backspace and modifiers work in fixture; failures preserve unsent text without automatic mutation replay. | Local fixture path confirmed; broader physical Safari keyboard sweep pending. |
| Displays | Pointer crosses both screens; explicit window move works each way; unplug/reconnect does not move unrelated windows. | Earlier cross-display and two-way move confirmed; hot-plug/native fullscreen races pending. |
| Power | With explicit owner consent, displays go dark and return while system stays awake; physical fallback works. | Earlier off/wake confirmed; locked afterwards; broader hardware coverage pending. |
| Lock and secure input | Input pauses; physical unlock and local Resume input required; no unlock/password injection. | Manual-lock variants pending; no universal lock-state detector claimed. |
| About/help/diagnostics | Version and links correct; preview excludes input, URLs, token/address/device fields; copy is explicit and unavailable clipboard has fallback. | Automated allowlist/browser checks required; physical phone copy fallback pending. |
| Accessibility | VoiceOver describes controls; keyboard focus stays usable; sheets dismiss correctly; larger text and portrait/landscape remain usable. | Browser layout/focus checks required; full macOS/iOS VoiceOver audit pending. |
| Stop/quit | One helper only; listener/connections close and held input/sleep assertions release. | Earlier local lifecycle confirmed; recheck updated release build. |
| Resources | Measure idle with native settings closed and active input separately; verify listener count and lack of capture/encoder. | Earlier short sample recorded above; longer active-input/energy measurement pending. |
| Existing browsers/players | Normal provider/Finder/IINA controls remain reachable; focus and app-specific media semantics documented. | Provider/DRM/fullscreen/subtitle combinations pending; no compatibility guarantee. |

For power/lock checks, get explicit consent and a working physical recovery method first. Do not turn a test plan into an unattended command that sleeps or locks the owner's Mac.

## Automated checks

Run `./scripts/test.sh` and `./build.sh`, then the release packaging checks in [RELEASE.md](RELEASE.md). Swift tests cover pairing, persistence, loopback transport/deadlines, finite command bounds, geometry and fake-sink event sequencing. Browser tests use a mocked backend at six portrait/landscape sizes and test transport order, gestures and UI states. Diagnostic tests must use deliberately private-looking sentinel strings to establish that only allowlisted fields are copied.

For a disposable local fixture, launch a locally built app with `--input-fixture`. `SOFA_REMOTE_DATA_DIR=/absolute/test/folder` isolates settings; close other copies first. The flag does not grant permissions. Keep test files in the established scratch location, never Documents/iCloud. Do not post app-data files, logs containing secrets, private screenshots or raw browser storage.

## Beta 4 theme and help checks

On 1 November 2026, 33 Swift tests and the browser/transport suites passed for the compact help controls, seven neutral/warm phone themes, saved theme migration, custom-colour validation, text/secondary-text/control-boundary contrast, 44px controls, six viewport sizes and collapsed diagnostic keyboard navigation. Theme preview images use a mocked Mac and contain no user data. Native iPhone Safari appearance and double-tap acceptance remain manual checks. No input timing, gain, authentication or listener changes were made for this UI update.

### Persistent identity check — 1 November 2026

On the development Mac, the owner manually approved the first certificate-signed build 11 once. The installer then replaced that closed app with build 12 using the same default certificate-backed designated requirement. After relaunch, build 12 reported **Input ready** without removing, re-adding or toggling its Accessibility entry. The paired phone and preferences remained present. This establishes permission retention for that local upgrade, not all macOS versions or a change to a different publisher certificate.

The integrated suite passed 38 Swift tests, browser/loopback transport checks and six disposable signing checks. Signing fixtures reject a different certificate, ad-hoc code, a weakened custom requirement, tampered resources and a self-signed certificate presented as Developer ID. They also verify two distinct universal builds with the same identity.
