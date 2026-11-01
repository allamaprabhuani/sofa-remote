# Contributing

Small reproducible fixes, accessibility improvements, tests and documentation are welcome. For a larger change, discuss the user problem first in an issue or Discussion.

## Product scope

Sofa Remote is an input-only Mac helper and browser remote. Prioritise pointing, keyboard input, reconnecting, clear recovery and bounded resource use. Keep personal shortcuts local. No screen streaming, accounts, analytics, ads, subscriptions, shell-command API, saved credentials or unlock bypass. Preserve Mac TV's MIT attribution.

## Development

1. Fork the repository and create a focused branch.
2. Read [AGENTS.md](AGENTS.md). Keep generated files outside Documents/iCloud and use an established local `SOFA_BUILD_DIR` for cloud-synchronised checkouts.
3. Run `./scripts/test.sh` and `./build.sh`. Describe which checks you ran and any unavailable hardware checks separately.
4. Open a PR describing the concrete problem, resulting behaviour, validation and remaining limits. Add a regression test when it protects a meaningful failure case.

Tests must use fake sinks or disposable windows and isolated data. Do not type into personal apps, sleep/lock a person's Mac, grant permissions, or overwrite a running app bundle as part of an automated test. Do not commit build outputs, credentials, settings, personal URLs, diagnostics or private screenshots.

Input routes must stay authenticated, bounded and cancellation-aware. Avoid timers, background network traffic or dependencies without a demonstrated need. Do not claim a loopback benchmark proves physical iPhone smoothness or provider playback works.

By contributing, you agree to the [Code of conduct](CODE_OF_CONDUCT.md). Contributions are distributed under the repository's [MIT licence](LICENSE).
