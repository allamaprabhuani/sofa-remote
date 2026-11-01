# UI and icon design notes

Status: draft. Nothing here is final; both the icon and the UI copy need
real-device review (iPhone Safari standalone, 320 px wide display, both
orientations) and reviewer consensus before shipping.

## Phone UI

The phone page targets a 320 px minimum width (older iPhone SE in a
narrow Safari viewport). Changes in this iteration are minimal on purpose
— no new dependencies, no redesign, test selectors preserved:

- Touchpad hint now reads *"Move · tap · two fingers scroll · spans all
  displays"* so the user knows the pointer is not caged on the preferred
  display.
- Settings section renames *Preferred display* to *Jump pointer to
  display* and *Move front window to display* to *Move front window to
  this display*, and adds one explanatory line distinguishing the one-shot
  pointer jump from free trackpad-style movement across every connected
  display.
- A concise power hint sits directly under *Screen off / Wake screen*:
  turning the screen off affects every connected display and macOS may
  lock while the screen is off; the paragraph under *Lock Mac…* already
  notes that waking the screen does not unlock the Mac, so the hint does
  not repeat that. No synthetic unlock keystrokes are added — the user's
  physical confirmation showed Touch ID was still required after wake,
  which is the macOS security contract we do not try to work around.

## Pointer transport (phone → Mac)

The remote command endpoint rejects any motion delta with
`|dx|>300` or `|dy|>300` as HTTP 400. The phone page therefore keeps
exact accumulated proportional travel on the client, and splits each
queued motion into bounded ±300 packets at send time. One command is in
flight at a time, cadence is capped at ~60 fps, and the backlog is
bounded by the existing 12-item queue cap. Timeout or request
cancellation discards the stale motion remainder — a motion POST is
never replayed because its on-wire effect is ambiguous.

Ordinary `pointerup` leaves queued motion in place so the full swipe
distance is delivered before the trailing click. Only an explicit
`pointercancel`, `visibilitychange→hidden`, `pagehide`, or
`lostpointercapture` discards pending movement and releases the drag
latch. The drag latch itself keeps multi-stroke usability and the 1 Hz
heartbeat.

## Multi-display geometry

`DisplayController.desktopBounds` remains available as a bounding-rect
helper, but the active pointer clamp is now `project(_:onto:)`: points
already inside any display pass through unchanged (free crossing between
monitors, including negative-coordinate secondaries), while points in a
staggered/L-shaped gap or past an outer edge snap to the nearest in-bounds
pixel of the closest display rect. The selected display is a jump-to and
window-move destination, never consulted for normal moves. The physical
cursor position is read fresh for every command so another mouse on the
Mac is respected.

What is deliberately not changed:

- No new primary controls at the top level — the touchpad plus
  click/media/action rows already fit on 320 px. Adding a per-display
  switcher at the main level would push the touchpad below the fold on
  short viewports.
- Element `id`s and `data-action` values are preserved so the parent's
  browser test harness continues to find them.
- No new fonts, images, or JS libraries. Everything is still inline.

## Icon

Two candidates exist on the branch:

| File | Format | Origin |
| --- | --- | --- |
| `Assets/AppIcon.*` (parent branch) | Blue sofa + white cursor raster | Parent-generated |
| `Assets/AppIcon-claude.svg` (this change) | Editable vector draft | This change |

The SVG draft keeps the same visual grammar — midnight-blue background,
blue sofa silhouette, white Mac arrow pointer — but as a standalone
editable alternative. It is not proposed as a replacement.

### Tradeoffs

- **Raster first-pass (parent)**: ships immediately as `.icns`, matches
  what the user already sees in the dock; harder to tweak proportions,
  cannot be re-rendered at a new size without a round trip through the
  generator.
- **SVG draft (this file)**: editable in any vector tool, scales cleanly
  down to 32 px (readability was the primary constraint for geometry
  choices — thick arm radii, two cushions rather than three, pointer
  offset bottom-right so the sofa stays centred). Still needs an `.icns`
  export pipeline before it can replace the current icon; still needs a
  look-review on a real device at the dock size, Launchpad size, and in
  the macOS menu bar's small greyscale template rendering.

### Recommendation

Keep the parent's raster as the default for the next build. Treat the
SVG as the source of truth for future icon work: edits made to the SVG
re-export cleanly, which the raster does not. Do not ship a new icon
until a reviewer has compared both at real display sizes.

### Open questions for the parent

- Does macOS menu-bar rendering need a separate monochrome template icon
  (the current colour icon can look muddy once masked)? If yes, a
  monochrome SVG derivative belongs here too.
- Should the pointer be the classic macOS arrow or a stylised dot? The
  draft uses the arrow for immediate recognition.
