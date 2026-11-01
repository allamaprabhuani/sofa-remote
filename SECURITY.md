# Security and privacy

Sofa Remote grants a paired phone control of the logged-in desktop. Treat it like a wireless keyboard and mouse. This is an experimental trusted-network tool, not a hardened remote-administration service.

## Transport boundary

Direct LAN HTTP does **not** encrypt pairing codes, tokens, URLs or text. A hostile device or network operator may intercept or alter traffic. Authentication and private-address filters do not prevent that. Use only a trusted private network or your own encrypted network such as Tailscale. Keep the Mac and phone on the same tailnet and scan its Tailscale address when available. No public tunnel, router forwarding, automatic firewall exception or UPnP is configured.

The listener accepts loopback, RFC1918, link-local and shared/Tailscale address ranges; validates literal/private Host headers and browser Origin; serves no CORS access; bounds requests, deadlines and clients. These reduce exposure and denial-of-service risk, and are not a substitute for encrypted transport. Tailscale hostnames and custom HTTPS reverse-proxy origins are not supported by the current Host policy; use the displayed IP link.

The input WebSocket shares the HTTP port and the same unencrypted transport boundary. It requires a matching Origin and a paired-device token in its first message, never a URL token. Frame/buffer/client bounds and per-device input rate limits apply. The server processes commands in order and checks authorization again during asynchronous operations. Closing a stream cancels its pending operation and releases held input; the browser does not replay uncertain commands after reconnecting. A revoked idle stream is rejected on its next activity or closed by the idle deadline.

## Pairing and stored data

Pairing is opened by the person at the Mac, lasts five minutes, and ends when its window closes. Failed attempts are rate-limited. Each phone receives an independent 32-byte random secret; the Mac stores only SHA-256 digests with file mode 0600. The browser stores its actual secret in that origin's local storage. Local storage can be copied by someone with access to that browser or by hostile injected page code; do not pair over an untrusted network.

Up to 16 phones can be paired. Remove a device on the Mac or from a trusted phone. Stopping sharing closes the listener and connections but preserves saved pairings for the next start. Revoke a device to invalidate its secret permanently.

Settings and device digests are in `~/Library/Application Support/Sofa Remote`. Corrupt files are not silently overwritten. No input history, screenshots, browser profiles, passwords, screen/audio recording or analytics are collected. Saved shortcut names/addresses are local settings. The app opens only HTTP(S) websites and saved installed applications; there is no shell-command or file-download API.

## Input lifecycle and lock

Lost drags are released by a watchdog, and stop/revoke/session loss resets held input. Asynchronous window moves recheck authorization and pinned window identity. Requests have deadlines and mutations are never automatically replayed; a timeout can mean an action already occurred.

Remote Lock uses the ordinary macOS lock shortcut and pauses input locally. Unlock on the Mac and use Resume input in Sofa Remote. Secure keyboard input, inactive-session signals and loginwindow detection also pause inputs. These are conservative signals, not a verified detector for every manually locked-screen state. No automatic unlock, password saving or credential injection is provided. macOS login security remains separate from pairing. Do not rely on this beta as a security boundary protecting an unattended desktop; stop sharing when it is not in use.

## Reporting

Use GitHub's private vulnerability reporting for this repository when available. Otherwise open a public issue requesting a private contact **without exploit details, secrets or logs**. Please report the revision, macOS/browser versions and a minimal reproduction using disposable data.

No independent security audit, penetration test or Developer ID notarization is claimed.
