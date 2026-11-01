# Manual acceptance checklist

Use disposable windows and isolated app data. Automated tests use mocked input; a green build is not proof of physical iPhone behaviour.

- First launch: the menu-bar helper appears, Accessibility instructions are actionable, QR/code pairs the intended phone, no Screen Recording permission appears.
- Reconnect: reload phone; background/lock it for several minutes; return without stale queued clicks or repeated text. Revoke the phone and confirm the next request is denied.
- Touchpad: motion, tap, two-finger scroll/tap, right/double click, drag, stationary hold, pointer cancellation and leaving the page. Confirm every drag eventually releases.
- Keyboard: Unicode text, Enter/Escape/Backspace, sticky modifiers and Cmd-L/Cmd-Tab. Preserve unsent text on failure and never retry a timed-out mutation automatically.
- Displays: use real connected names/UUIDs; select each; move a disposable window in both directions while windowed and fullscreen. Unplug a display, change foreground windows during a move and stop sharing mid-move. No unrelated window should move.
- Brave/IINA: launch a saved app/website; operate normal provider controls, Finder Downloads, IINA subtitles and fullscreen. Verify focus rather than assuming global media keys target a particular player.
- Power: with explicit consent, turn displays off then request wake while the Mac remains awake. Verify system notifications rather than interpreting request acceptance as physical TV power.
- Lock: only with the owner's explicit consent and a working physical unlock method. Use remote Lock, verify input is paused, unlock on the Mac and resume locally. Test manual Lock separately; record the observed boundaries without promising automatic unlock.
- Stop/quit: listener and connections close; no held input or sleep assertion remains. Starting again uses saved preferences. Only one helper instance should be running.
- Resources: measure process CPU/memory at idle with native settings closed, then while receiving input. List listener count. Keep test-browser and Brave/IINA costs separate. No streaming encoder/capture should run.

The first public version is experimental. Record tested OS/browser/hardware and failures before treating a scenario as supported. Never attach real credentials, personal window content or local settings to a public issue.

## Local checks on 1 November 2026

A paired local client sent Unicode text (including an emoji) and Enter through the authenticated HTTP route into the app's disposable native text window. The foreground app was checked before sending input and the resulting text was read back from that window. Revoking that test client made its next authenticated request return HTTP 401. Native Stop sharing closed the listener, and the helper was then quit. These checks verify the keyboard/event path and revocation on this Mac; they do not verify physical iPhone touch gestures, live pointer movement, external-display movement, provider playback or lock/power behaviour.
