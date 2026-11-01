# Mac TV pointer comparison

Compared against [Mac TV 361f4a3](https://github.com/allamaprabhuani/mac-tv/commit/361f4a32d784d51ce6d03d74e1ad8650d69f308f) on 1 November 2026, following the owner's report that its pointer felt smoother on the same devices.

Mac TV's phone touchpad uses serialized HTTP and a 33 ms coalescing timer. It applies `1.6 + min(hypot(dx,dy)/6, 3)` gain, retains fractional remainders, and maintains pointer coordinates on the Mac. Its owned WebKit/Brave routes immediately warp the cursor and dispatch events into their target window/process.

Sofa Remote originally used linear one-to-one movement and re-read the system cursor for every delta. It controls the whole desktop through the HID event tap, so Mac TV's app-specific activation, window confinement and process-targeted events cannot simply replace the desktop route.

Claude and AGY independently recommended deferring a native Bluetooth app and first testing gain, fractional carry and maintained pointer coordinates on the existing HTTP path. They differed on immediate warping. The first comparison patch keeps global HID events and adds no per-move warp: it carries its emitted target briefly, recognizes observations of its own recent events, rebases after idle or physical movement off that path, and clears on explicit reset/stop/revocation. Button events preserve the pending position until it settles.

The patch passed 28 Swift tests and browser tests for proportional travel, fractional movement, gesture cancellation, queue bounds and stale-click prevention. Physical smoothness still needs the owner's comparison. The 150 ms anchor interval is a heuristic, not a guarantee about every simultaneous physical/remote input pattern.

The WebSocket experiment is retained separately at `experimental/same-port-input`. Its real loopback browser test passed near 56 updates/second, but it felt worse on physical Safari and was removed from the installed daily-use app. Loopback evidence does not rule out a Safari/Wi-Fi problem. TCP stream order also means multiple outstanding messages do not, by themselves, reorder commands. Neither review establishes that Bluetooth is necessary or that the new pointer patch is smooth on a real phone.

Native iPhone/Bluetooth work remains deferred. First compare this smaller patch on the same Mac, phone, displays and network. Reconsider a new transport only after that result.
