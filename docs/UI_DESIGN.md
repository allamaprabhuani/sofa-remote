# UI and input design

The first phone layout keeps a large touchpad, labelled click/drag controls and sheets for keyboard, shortcuts and display/power settings. Controls remain usable at 320 px; there are no frontend dependencies, external fonts or screen streaming.

## Pointer and display controls

Pointer motion uses every connected screen, including negative-coordinate monitors. Points in a gap or beyond the desktop project to the nearest real display edge. The Mac briefly carries its emitted pointer target so delayed system observations do not undo movement; idle or off-path physical movement rebases it. Selecting a display is a one-time pointer jump and the destination for an explicit window move; it does not confine the pointer.

The command queue keeps one request in flight and targets roughly 60 motion updates per second where network latency permits. Accumulated relative travel is split into packets within the server's ±1,000-per-axis move/drag limit (scroll remains ±300). Ordinary finger lift flushes pending movement before a following click; cancellation/hidden-page events discard unsent movement and release drag. The drag latch supports multiple finger strokes and sends a heartbeat while stationary.

Backpressure is bounded: twelve queue entries, a maximum coalesced movement of 3,600 points per axis, and a 250 ms age limit for unsent movement. Overload, expired movement or a failed send rejects queued input, including dependent clicks, rather than replaying it after the connection recovers. Urgent Wake can cancel earlier work. Network latency still limits smoothness; physical testing is required.

## Power

Screen off applies to all connected displays. The Mac must stay awake for remote wake to remain reachable. macOS may lock after display sleep; Wake does not unlock. The helper does not change lock policy or inject unlock credentials.

## Artwork

The default is `Assets/AppIcon.png`: cobalt sofa and white pointer on a midnight rounded tile, generated with OpenAI's built-in image-generation tool. AGY and Grok supported that visual direction. Claude supplied the editable alternative `Assets/AppIcon-claude.svg` and implemented the first input/UI patches; integration review corrected protocol, queue-completion and geometry-test issues before installation.

Build-time image conversion produces the native ICNS sizes and local PNG assets for Safari's Home Screen icon. The menu bar keeps a monochrome system cursor symbol for light/dark legibility. The SVG remains a draft alternative; the raster is the current source of the shipped icon. See [the artwork prompt](../Assets/README.md).

## Verification

Swift geometry/event-sink tests and browser interaction tests exercise multiple display layouts, bounded packets, preserved swipe distance, cancellation, request failures and stale-click prevention. They do not establish physical smoothness or provider compatibility. See [recorded device checks](REVIEW.md).

## Public beta simplification

Claude and AGY independently recommended plain copy, a pairing-focused Mac window and a touchpad-first phone. The descriptor is “Control your Mac from your phone.” Setup/practice live in About & Help; preferences are grouped; empty paired-phone lists are omitted. Website entry lives in Shortcuts. Sharing status, stop/revoke controls and the unencrypted-network notice remain visible. Help holds the full guide, contact links, reviewed diagnostics, privacy and licences. No new service, timer or dependency was added for this change.

## Beta 2 appearance

The phone uses local SVG symbols with accessible names and brief visible captions where an icon is ambiguous. Its four CSS-variable themes are Imperial blue (`#003E74`), Light, Ocean and Custom. A native colour picker supplies a validated hex background; the client derives contrast-safe text/surfaces. Preferences live only in browser local storage. No font/icon library, image fetch, new timer or service was added. Controls use `touch-action: manipulation`; the pad keeps `touch-action: none` with a narrow short-single-finger-touch fallback that never sends its own command. Pinch zoom stays available outside the pad. Physical Safari confirmation remains separate from trusted Chromium input tests.
