import Foundation

/// Self-contained phone interface. It uses only the local Sofa Remote listener.
enum RemotePage {
    static let html = #"""
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover" />
    <meta name="theme-color" content="#10121a" />
    <meta name="apple-mobile-web-app-capable" content="yes" />
    <link rel="manifest" href="/manifest.webmanifest" />
    <link rel="icon" type="image/png" href="/icon-192.png" />
    <link rel="apple-touch-icon" sizes="180x180" href="/icon-180.png" />
    <title>Sofa Remote</title>
    <style>
      :root {
        color-scheme: dark;
        --bg: #10121a;
        --card: rgba(255, 255, 255, 0.08);
        --line: rgba(255, 255, 255, 0.13);
        --muted: #aeb6c8;
        --accent: #8fafff;
      }
      * {
        box-sizing: border-box;
        -webkit-tap-highlight-color: transparent;
      }
      html,
      body {
        margin: 0;
        min-height: 100%;
        font:
          16px/1.35 -apple-system,
          BlinkMacSystemFont,
          system-ui,
          sans-serif;
        background: var(--bg);
        color: #f8f9ff;
      }
      body {
        background:
          radial-gradient(ellipse at 10% -5%, #293d67 0, transparent 45%),
          radial-gradient(ellipse at 100% 60%, #372c4b 0, transparent 45%), var(--bg);
      }
      button,
      input,
      select {
        font: inherit;
      }
      button {
        color: inherit;
        cursor: pointer;
      }
      button:focus-visible,
      input:focus-visible,
      select:focus-visible {
        outline: 3px solid var(--accent);
        outline-offset: 2px;
      }
      main {
        max-width: 480px;
        min-height: 100dvh;
        margin: auto;
        padding: calc(12px + env(safe-area-inset-top)) 16px calc(16px + env(safe-area-inset-bottom));
        display: flex;
        flex-direction: column;
        gap: 10px;
      }
      header {
        display: flex;
        align-items: center;
        gap: 10px;
      }
      header h1 {
        font-size: 19px;
        letter-spacing: -0.02em;
        margin: 0;
        flex: 1;
      }
      header small {
        display: block;
        font-size: 11px;
        color: var(--muted);
        font-weight: 500;
      }
      button,
      .field {
        border: 1px solid var(--line);
        background: var(--card);
        border-radius: 15px;
      }
      button {
        min-height: 44px;
        padding: 0 13px;
      }
      button:active {
        background: rgba(255, 255, 255, 0.2);
      }
      button:disabled {
        opacity: 0.45;
        cursor: default;
      }
      .icon {
        width: 44px;
        padding: 0;
        font-size: 20px;
      }
      .address {
        display: flex;
        gap: 7px;
      }
      .field {
        min-width: 0;
        min-height: 46px;
        padding: 0 12px;
        color: inherit;
      }
      .address input {
        flex: 1;
      }
      .address button {
        font-weight: 700;
      }
      #pad {
        flex: 1 1 auto;
        min-height: 180px;
        max-height: 420px;
        border-radius: 28px;
        border: 1px solid var(--line);
        background: linear-gradient(145deg, rgba(255, 255, 255, 0.1), rgba(255, 255, 255, 0.035));
        touch-action: none;
        position: relative;
        user-select: none;
      }
      #pad .hint {
        position: absolute;
        bottom: 15px;
        left: 8px;
        right: 8px;
        text-align: center;
        color: var(--muted);
        font-size: 12px;
        pointer-events: none;
      }
      .pad-title {
        position: absolute;
        top: 15px;
        left: 18px;
        font-size: 11px;
        letter-spacing: 0.1em;
        text-transform: uppercase;
        color: var(--muted);
        font-weight: 700;
        pointer-events: none;
      }
      .row {
        display: grid;
        gap: 7px;
      }
      .clicks {
        grid-template-columns: repeat(3, 1fr);
      }
      .media {
        grid-template-columns: repeat(5, 1fr);
      }
      .actions {
        grid-template-columns: repeat(4, 1fr);
      }
      .row button {
        padding: 0 4px;
        font-size: 13px;
        font-weight: 650;
      }
      .row button.on,
      .modifiers button.on {
        background: #e6edff;
        color: #11182c;
      }
      .media button {
        font-size: 20px;
      }
      .status {
        font-size: 12px;
        color: var(--muted);
        min-height: 16px;
      }
      .status.error {
        color: #ffaaa7;
      }
      .scrim {
        position: fixed;
        inset: 0;
        z-index: 5;
        background: rgba(3, 4, 9, 0.66);
        display: none;
        align-items: flex-end;
      }
      .scrim.open {
        display: flex;
      }
      .sheet {
        width: 100%;
        max-width: 480px;
        max-height: 90dvh;
        overflow: auto;
        margin: auto auto 0;
        padding: 20px 18px calc(20px + env(safe-area-inset-bottom));
        display: flex;
        flex-direction: column;
        gap: 11px;
        background: #20232f;
        border: 1px solid var(--line);
        border-radius: 24px 24px 0 0;
      }
      .sheet-head {
        display: flex;
        align-items: center;
        gap: 10px;
      }
      .sheet-head h2 {
        font-size: 18px;
        flex: 1;
        margin: 0;
      }
      .sheet-head button {
        min-width: 65px;
      }
      .sheet .field {
        width: 100%;
      }
      .sheet p {
        color: var(--muted);
        font-size: 13px;
        margin: 0;
      }
      .sheet p.error {
        color: #ffaaa7;
      }
      .sheet label {
        font-size: 13px;
        color: var(--muted);
      }
      .sheet form {
        display: flex;
        flex-direction: column;
        gap: 8px;
      }
      .sheet-row {
        display: flex;
        gap: 8px;
        align-items: center;
      }
      .sheet-row > * {
        flex: 1;
        min-width: 0;
      }
      .modifiers {
        display: grid;
        grid-template-columns: repeat(4, 1fr);
        gap: 6px;
      }
      .modifiers button {
        padding: 0;
        font-size: 12px;
      }
      .keygrid {
        display: grid;
        grid-template-columns: repeat(4, 1fr);
        gap: 6px;
      }
      .shortcut {
        display: flex;
        gap: 6px;
        align-items: center;
      }
      .shortcut span {
        flex: 1;
        min-width: 0;
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
      }
      .shortcut button {
        min-width: 44px;
        padding: 0 10px;
      }
      .shortcut .launch {
        text-align: left;
        flex: 1;
      }
      .danger {
        color: #ffb8b8;
      }
      #pair,
      #locked {
        position: fixed;
        inset: 0;
        z-index: 10;
        background: #141824;
        padding: 24px;
        display: none;
        align-items: center;
        justify-content: center;
      }
      #pair.open,
      #locked.open {
        display: flex;
      }
      #locked {
        z-index: 11;
      }
      .card {
        width: min(100%, 390px);
        display: flex;
        flex-direction: column;
        gap: 12px;
      }
      .card h1 {
        margin: 0;
        font-size: 25px;
      }
      .card p {
        color: var(--muted);
        margin: 0;
      }
      .card input {
        width: 100%;
      }
      .card button {
        min-height: 50px;
      }
      .card .primary {
        background: #e6edff;
        color: #11182c;
        font-weight: 700;
      }
      .card .error {
        color: #ffaaa7;
      }
      @media (max-height: 650px) {
        main {
          gap: 7px;
        }
        #pad {
          min-height: 150px;
        }
        .row button {
          min-height: 44px;
        }
      }
    </style>
  </head>
  <body>
    <main>
      <header>
        <h1>Sofa Remote<small id="connection">Connecting…</small></h1>
        <button class="icon" data-action="mute" aria-label="Mute">◖×</button
        ><button class="icon" id="shortcuts-open" aria-label="Shortcuts">▦</button
        ><button class="icon" id="settings-open" aria-label="Settings">⚙</button>
      </header>
      <form class="address" id="open-form">
        <input
          class="field"
          id="url"
          inputmode="url"
          aria-label="Website address"
          placeholder="Open a website…"
          autocapitalize="off"
          autocorrect="off"
          spellcheck="false"
        /><button>Go</button>
      </form>
      <div
        id="pad"
        role="application"
        aria-label="Touchpad. Drag to move, tap to click, use two fingers to scroll."
      >
        <span class="pad-title">Touchpad</span
        ><span class="hint">Move · tap to click · two fingers to scroll</span>
      </div>
      <div class="row clicks">
        <button id="right">Right click</button><button id="double">Double click</button
        ><button id="drag" aria-pressed="false">Drag</button>
      </div>
      <div class="row media">
        <button data-action="previous" aria-label="Previous">⏮</button
        ><button data-action="playPause" aria-label="Play or pause">⏯</button
        ><button data-action="next" aria-label="Next">⏭</button
        ><button data-action="volumeDown" aria-label="Volume down">−</button
        ><button data-action="volumeUp" aria-label="Volume up">＋</button>
      </div>
      <div class="row actions">
        <button id="keyboard-open">Keyboard</button><button data-action="appSwitcher">App switcher</button
        ><button data-action="fullscreen">Full screen</button
        ><button data-action="spotlight">Spotlight</button>
      </div>
      <div id="status" class="status" role="status" aria-live="polite"></div>
    </main>
    <div class="scrim" id="keyboard-sheet">
      <div class="sheet" role="dialog" aria-modal="true" aria-label="Keyboard">
        <div class="sheet-head">
          <h2>Keyboard</h2>
          <button data-close>Done</button>
        </div>
        <form id="text-form">
          <label for="text">Type on your Mac</label
          ><input
            class="field"
            id="text"
            maxlength="1000"
            autocomplete="off"
            aria-label="Text to send"
          /><button>Send text</button>
        </form>
        <p>Modifiers apply to the next key.</p>
        <div class="modifiers">
          <button data-mod="command" aria-pressed="false">⌘ Command</button
          ><button data-mod="control" aria-pressed="false">⌃ Control</button
          ><button data-mod="option" aria-pressed="false">⌥ Option</button
          ><button data-mod="shift" aria-pressed="false">⇧ Shift</button>
        </div>
        <form id="key-form">
          <label for="key-character">Letter or number key</label>
          <div class="sheet-row">
            <input
              class="field"
              id="key-character"
              maxlength="1"
              aria-label="Letter or number key"
              autocapitalize="off"
              autocomplete="off"
            /><button>Send key</button>
          </div>
        </form>
        <div class="keygrid">
          <button data-key="escape">Esc</button><button data-key="tab">Tab</button
          ><button data-key="backspace">⌫</button><button data-key="delete">Delete</button
          ><button data-key="left">←</button><button data-key="up">↑</button><button data-key="down">↓</button
          ><button data-key="right">→</button><button data-key="space">Space</button
          ><button data-key="enter">Return</button>
        </div>
      </div>
    </div>
    <div class="scrim" id="shortcuts-sheet">
      <div class="sheet" role="dialog" aria-modal="true" aria-label="Shortcuts">
        <div class="sheet-head">
          <h2>Shortcuts</h2>
          <button data-close>Done</button>
        </div>
        <p>Open a saved website or app. Changes are saved on your Mac.</p>
        <div id="shortcut-list"></div>
        <form id="shortcut-form">
          <label for="shortcut-name">Add shortcut</label
          ><input
            class="field"
            id="shortcut-name"
            maxlength="80"
            placeholder="Name"
            aria-label="Shortcut name"
            required
          /><input
            class="field"
            id="shortcut-value"
            placeholder="Website URL or app bundle ID"
            aria-label="Website URL or app bundle ID"
            required
          /><select class="field" id="shortcut-kind" aria-label="Shortcut type">
            <option value="url">Website</option>
            <option value="bundleID">Mac app bundle ID</option></select
          ><button>Add shortcut</button>
        </form>
      </div>
    </div>
    <div class="scrim" id="settings-sheet">
      <div class="sheet" role="dialog" aria-modal="true" aria-label="Settings">
        <div class="sheet-head">
          <h2>Settings</h2>
          <button data-close>Done</button>
        </div>
        <label for="display">Preferred display</label
        ><select class="field" id="display"></select>
        <p>Selecting a display moves the pointer there. Move the front window separately.</p>
        <button data-action="moveWindow">Move front window to display</button>
        <div class="sheet-row">
          <button data-action="showDesktop">Show desktop</button
          ><button data-action="downloads">Downloads</button>
        </div>
        <div class="sheet-row">
          <button data-action="screenOff">Screen off</button
          ><button data-action="screenOn">Wake screen</button>
        </div>
        <label class="sheet-row"
          ><span>Keep Mac awake while sharing</span><input type="checkbox" id="awake"
        /></label>
        <p>Prevents idle system sleep; the display can still sleep.</p>
        <button class="danger" id="lock">Lock Mac…</button>
        <p>
          Waking the screen does not unlock your Mac. Unlock on the Mac; Apple Watch unlock is a separate
          macOS setting.
        </p>
        <div id="devices"></div>
      </div>
    </div>
    <div id="pair">
      <div class="card">
        <h1>Pair with your Mac</h1>
        <p>
          Enter the code shown in Sofa Remote on your Mac. Pair only on a trusted network: direct local HTTP
          is unencrypted. Tailscale offers an encrypted connection.
        </p>
        <input
          class="field"
          id="code"
          inputmode="numeric"
          maxlength="6"
          autocomplete="one-time-code"
          placeholder="6-digit code"
          aria-label="Pairing code"
        /><input
          class="field"
          id="device-name"
          maxlength="60"
          placeholder="Phone name (optional)"
          aria-label="Phone name"
        /><button class="primary" id="pair-button">Pair</button>
        <p class="error" id="pair-error" role="status"></p>
      </div>
    </div>
    <div id="locked">
      <div class="card">
        <h1>Input paused</h1>
        <p>
          Mac is locked, using secure text input, or paused. Unlock the Mac and choose Resume input in Sofa
          Remote on the Mac if needed.
        </p>
        <button class="primary" id="wake">Wake screen</button>
        <p id="locked-error" role="status"></p>
      </div>
    </div>
    <script>
      const $ = (s) => document.querySelector(s),
        $$ = (s) => [...document.querySelectorAll(s)];
      const storage = {
        get() {
          try {
            return localStorage.getItem("sofaKey") || "";
          } catch {
            return "";
          }
        },
        set(v) {
          try {
            localStorage.setItem("sofaKey", v);
          } catch {}
        },
      };
      const pairCode = new URLSearchParams(location.hash.slice(1)).get("pair") || "";
      if (location.hash) history.replaceState(null, "", location.pathname + location.search);
      let key = storage.get(),
        locked = false,
        statePending = null,
        changing = false,
        stateSerial = 0;
      let statusKind = "notice",
        permissionMissing = false;
      let drag = false,
        dragHeartbeat = 0,
        modifiers = new Set(),
        shortcuts = [],
        shortcutSignature = "",
        displaySignature = "",
        currentDisplay = "";
      function status(message, error = false, kind = "notice") {
        statusKind = kind;
        if (locked) $("#locked-error").textContent = message;
        $("#status").textContent = message;
        $("#status").classList.toggle("error", error);
        $$(".sheet-status").forEach((x) => {
          x.textContent = message;
          x.classList.toggle("error", error);
        });
      }
      function clearRuntimeError() {
        if (statusKind === "runtime")
          status(
            permissionMissing ? "Allow Accessibility access for Sofa Remote on your Mac." : "",
            permissionMissing,
            permissionMissing ? "permission" : "notice",
          );
      }
      $$(".sheet").forEach((sheet) => {
        const note = document.createElement("p");
        note.className = "sheet-status";
        note.setAttribute("role", "status");
        sheet.append(note);
      });
      function showPair() {
        clearInterval(dragHeartbeat);
        dragHeartbeat = 0;
        drag = false;
        $("#drag").classList.remove("on");
        $("#drag").setAttribute("aria-pressed", "false");
        $("#locked").classList.remove("open");
        if ($("#pair").classList.contains("open")) return;
        $("#pair").classList.add("open");
        setTimeout(() => $("#code").focus(), 50);
      }
      async function request(path, body, authenticated = true, externalSignal = null) {
        if (externalSignal?.aborted) throw Error("cancelled");
        const controller = new AbortController(),
          credential = key;
        let timer, cancel;
        const deadline = new Promise((_, reject) => {
          timer = setTimeout(() => {
            controller.abort();
            reject(Error("Request timed out."));
          }, 9000);
          cancel = () => {
            controller.abort();
            reject(Error("cancelled"));
          };
          externalSignal?.addEventListener("abort", cancel, { once: true });
        });
        try {
          return await Promise.race([
            deadline,
            (async () => {
              const response = await fetch(path, {
                method: body ? "POST" : "GET",
                headers: authenticated
                  ? { "Content-Type": "application/json", "X-Sofa-Key": credential }
                  : { "Content-Type": "application/json" },
                body: body ? JSON.stringify(body) : undefined,
                signal: controller.signal,
              });
              if (authenticated && response.status === 401) {
                if (key === credential) {
                  key = "";
                  storage.set("");
                  showPair();
                }
                throw Error("unpaired");
              }
              const data = await response.json();
              if (!response.ok) throw Error(data.error || "Request failed.");
              return data;
            })(),
          ]);
        } finally {
          clearTimeout(timer);
          externalSignal?.removeEventListener("abort", cancel);
        }
      }
      async function pair(code) {
        if (!/^\d{6}$/.test(code)) {
          $("#pair-error").textContent = "Enter the 6-digit code.";
          return;
        }
        $("#pair-button").disabled = true;
        try {
          const result = await request("/pair", { code, name: $("#device-name").value.trim() }, false);
          key = result.token;
          storage.set(key);
          $("#pair").classList.remove("open");
          $("#pair-error").textContent = "";
          await refresh();
        } catch (e) {
          $("#pair-error").textContent = e.message;
        } finally {
          $("#pair-button").disabled = false;
        }
      }
      $("#pair-button").onclick = () => pair($("#code").value.trim());
      const queue = [];
      let active = null,
        gestureTimer = 0,
        lastGesture = 0;
      function pump() {
        if (active || gestureTimer || !queue.length) return;
        const next = queue[0].body,
          motion =
            next.type === "move" || next.type === "scroll" || (next.type === "drag" && next.phase === "move");
        const delay = motion ? Math.max(0, 33 - (Date.now() - lastGesture)) : 0;
        if (delay) {
          gestureTimer = setTimeout(() => {
            gestureTimer = 0;
            pump();
          }, delay);
          return;
        }
        const item = queue.shift();
        if (motion) lastGesture = Date.now();
        if (!key || (locked && item.body.action !== "screenOn")) {
          item.done(false);
          pump();
          return;
        }
        const controller = new AbortController();
        active = controller;
        request("/command", item.body, true, controller.signal)
          .then(
            () => {
              clearRuntimeError();
              return true;
            },
            (e) => {
              if (e.message !== "unpaired" && e.message !== "cancelled") status(e.message, true, "runtime");
              return false;
            },
          )
          .then((ok) => {
            active = null;
            item.done(ok);
            pump();
          });
      }
      function command(body, urgent = false) {
        return new Promise((resolve) => {
          if (locked && body.action !== "screenOn") {
            resolve(false);
            return;
          }
          if (urgent) {
            while (queue.length) queue.shift().done(false);
            clearTimeout(gestureTimer);
            gestureTimer = 0;
            active?.abort();
          }
          const last = queue[queue.length - 1];
          if (
            !urgent &&
            last &&
            (body.type === "move" ||
              body.type === "scroll" ||
              (body.type === "drag" && body.phase === "move")) &&
            last.body.type === body.type &&
            last.body.phase === body.phase
          ) {
            last.body.dx = Math.max(-300, Math.min(300, (last.body.dx || 0) + (body.dx || 0)));
            last.body.dy = Math.max(-300, Math.min(300, (last.body.dy || 0) + (body.dy || 0)));
            resolve(true);
            return;
          }
          if (body.type === "drag" && body.phase === "end") {
            while (queue.length >= 12) {
              let i = queue.length - 1;
              while (i >= 0 && !(queue[i].body.type === "drag" && queue[i].body.phase === "move")) i--;
              (i >= 0 ? queue.splice(i, 1)[0] : queue.pop()).done(false);
            }
          }
          if (queue.length >= 12) {
            resolve(false);
            return;
          }
          queue.push({ body, done: resolve });
          pump();
        });
      }
      function action(action) {
        return command({ type: "action", action }, action === "screenOn");
      }
      function endDrag() {
        if (!drag) return;
        drag = false;
        clearInterval(dragHeartbeat);
        dragHeartbeat = 0;
        $("#drag").classList.remove("on");
        $("#drag").setAttribute("aria-pressed", "false");
        command({ type: "drag", phase: "end" });
      }
      const pad = $("#pad"),
        fingers = new Map();
      let travel = 0,
        down = 0,
        multi = false;
      pad.addEventListener("pointerdown", (e) => {
        if (locked) return;
        pad.setPointerCapture(e.pointerId);
        if (!fingers.size) {
          travel = 0;
          down = Date.now();
          multi = false;
        }
        fingers.set(e.pointerId, { x: e.clientX, y: e.clientY });
        if (fingers.size > 1) multi = true;
      });
      pad.addEventListener("pointermove", (e) => {
        const f = fingers.get(e.pointerId);
        if (!f || locked) return;
        let dx = e.clientX - f.x,
          dy = e.clientY - f.y;
        f.x = e.clientX;
        f.y = e.clientY;
        travel += Math.abs(dx) + Math.abs(dy);
        dx = Math.max(-300, Math.min(300, dx));
        dy = Math.max(-300, Math.min(300, dy));
        if (fingers.size > 1) {
          if (drag) endDrag();
          command({ type: "scroll", dx: -dx / fingers.size, dy: -dy / fingers.size });
        } else command(drag ? { type: "drag", phase: "move", dx, dy } : { type: "move", dx, dy });
      });
      function lift(e) {
        if (!fingers.delete(e.pointerId)) return;
        if (e.type !== "pointerup") {
          fingers.clear();
          endDrag();
          return;
        }
        if (!fingers.size && !multi && !drag && travel < 8 && Date.now() - down < 300)
          command({ type: "click", button: "left", count: 1 });
      }
      pad.addEventListener("pointerup", lift);
      pad.addEventListener("pointercancel", lift);
      pad.addEventListener("lostpointercapture", (e) => {
        if (fingers.has(e.pointerId)) {
          fingers.clear();
          endDrag();
        }
      });
      $("#right").onclick = () => command({ type: "click", button: "right", count: 1 });
      $("#double").onclick = () => command({ type: "click", button: "left", count: 2 });
      $("#drag").onclick = () => {
        if (drag) {
          endDrag();
          return;
        }
        drag = true;
        $("#drag").classList.add("on");
        $("#drag").setAttribute("aria-pressed", "true");
        command({ type: "drag", phase: "start" });
        dragHeartbeat = setInterval(() => {
          if (drag) command({ type: "drag", phase: "move", dx: 0, dy: 0 });
        }, 1000);
      };
      $$("[data-action]").forEach((b) => (b.onclick = () => action(b.dataset.action)));
      $$("[data-mod]").forEach(
        (b) =>
          (b.onclick = () => {
            const m = b.dataset.mod;
            modifiers.has(m) ? modifiers.delete(m) : modifiers.add(m);
            b.classList.toggle("on", modifiers.has(m));
            b.setAttribute("aria-pressed", String(modifiers.has(m)));
          }),
      );
      function sendKey(key) {
        command({ type: "key", key, modifiers: [...modifiers] });
        modifiers.clear();
        $$("[data-mod]").forEach((x) => {
          x.classList.remove("on");
          x.setAttribute("aria-pressed", "false");
        });
      }
      $$("[data-key]").forEach((b) => (b.onclick = () => sendKey(b.dataset.key)));
      $("#key-form").onsubmit = (e) => {
        e.preventDefault();
        const input = $("#key-character"),
          value = input.value.toLowerCase();
        if (!/^[a-z0-9]$/.test(value)) {
          status("Enter one letter or number.", true);
          return;
        }
        sendKey(value);
        input.value = "";
      };
      $("#text-form").onsubmit = async (e) => {
        e.preventDefault();
        const input = $("#text"),
          value = input.value,
          button = e.currentTarget.querySelector("button");
        if (!value || locked || button.disabled) return;
        button.disabled = true;
        try {
          const sent = await command({ type: "text", value: value.slice(0, 1000) });
          if (sent && input.value === value) input.value = "";
          else if (!sent && !key) status("Pair with your Mac, then send the text again.", true, "runtime");
          else if (!sent && statusKind !== "runtime" && statusKind !== "permission")
            status("Could not send text. Try again.", true, "runtime");
        } finally {
          button.disabled = false;
        }
      };
      function sheet(id) {
        if (locked) return;
        $("#" + id).classList.add("open");
        $("#" + id + " [data-close]").focus();
      }
      $("#keyboard-open").onclick = () => sheet("keyboard-sheet");
      $("#shortcuts-open").onclick = () => sheet("shortcuts-sheet");
      $("#settings-open").onclick = () => {
        sheet("settings-sheet");
        loadDevices();
      };
      $$("[data-close]").forEach((b) => (b.onclick = () => b.closest(".scrim").classList.remove("open")));
      $$(".scrim").forEach(
        (s) =>
          (s.onclick = (e) => {
            if (e.target === s) s.classList.remove("open");
          }),
      );
      async function mutate(path, body) {
        if (changing || locked) return;
        changing = true;
        ++stateSerial;
        try {
          await request(path, body);
          await refresh(true);
          status(path === "/launch" ? "Opened." : "Saved.");
          return true;
        } catch (e) {
          if (e.message !== "unpaired") status(e.message, true);
          await refresh(true);
          return false;
        } finally {
          changing = false;
        }
      }
      $("#open-form").onsubmit = async (e) => {
        e.preventDefault();
        const url = $("#url").value.trim();
        if (!url || locked) return;
        const button = e.currentTarget.querySelector("button");
        if (button.disabled) return;
        button.disabled = true;
        try {
          await request("/open", { url });
          $("#url").value = "";
          status("Opened on your Mac.");
        } catch (err) {
          if (err.message !== "unpaired") status(err.message, true);
        } finally {
          button.disabled = false;
        }
      };
      $("#shortcut-form").onsubmit = async (e) => {
        e.preventDefault();
        const name = $("#shortcut-name").value.trim(),
          value = $("#shortcut-value").value.trim();
        if (!name || !value) return;
        const body = { name };
        body[$("#shortcut-kind").value] = value;
        if (await mutate("/shortcuts/add", body)) {
          $("#shortcut-name").value = "";
          $("#shortcut-value").value = "";
        }
      };
      function renderShortcuts() {
        const list = $("#shortcut-list");
        list.replaceChildren();
        shortcuts.forEach((item, index) => {
          const row = document.createElement("div");
          row.className = "shortcut";
          const launch = document.createElement("button");
          launch.className = "launch";
          launch.textContent = item.name;
          launch.onclick = () => mutate("/launch", { id: item.id });
          row.append(launch);
          for (const [label, offset] of [
            ["↑", -1],
            ["↓", 1],
          ]) {
            const b = document.createElement("button");
            b.textContent = label;
            b.setAttribute("aria-label", `${offset < 0 ? "Move up" : "Move down"} ${item.name}`);
            b.disabled = offset < 0 ? index === 0 : index === shortcuts.length - 1;
            b.onclick = () => mutate("/shortcuts/move", { id: item.id, offset });
            row.append(b);
          }
          const remove = document.createElement("button");
          remove.textContent = "×";
          remove.setAttribute("aria-label", `Remove ${item.name}`);
          remove.onclick = () => {
            if (confirm(`Remove ${item.name}?`)) mutate("/shortcuts/remove", { id: item.id });
          };
          row.append(remove);
          list.append(row);
        });
      }
      $("#display").onchange = (e) => mutate("/display", { id: e.target.value });
      $("#awake").onchange = (e) => mutate("/settings", { keepAwake: e.target.checked });
      $("#lock").onclick = () => {
        if (confirm("Lock this Mac? Unlock it on the Mac.")) {
          endDrag();
          action("lock");
        }
      };
      $("#wake").onclick = () => action("screenOn");
      async function loadDevices() {
        try {
          const devices = await request("/devices");
          const box = $("#devices");
          box.replaceChildren();
          for (const d of devices) {
            const row = document.createElement("div");
            row.className = "shortcut";
            const label = document.createElement("span");
            label.textContent = d.name + (d.current ? " · this phone" : "");
            const remove = document.createElement("button");
            remove.textContent = "Remove";
            remove.onclick = async () => {
              if (!confirm(`Remove ${d.name}?`)) return;
              try {
                await request("/devices/revoke", { id: d.id });
                if (d.current) {
                  key = "";
                  storage.set("");
                  showPair();
                } else loadDevices();
              } catch (e) {
                status(e.message, true);
              }
            };
            row.append(label, remove);
            box.append(row);
          }
        } catch (e) {
          if (e.message !== "unpaired") status(e.message, true);
        }
      }
      async function refresh(force = false) {
        if (changing && !force) return false;
        if (!key) {
          showPair();
          return false;
        }
        if (statePending) {
          if (!force) return statePending;
          await statePending;
          if (!key) return false;
        }
        const generation = ++stateSerial;
        const pending = (async () => {
          try {
            const s = await request("/state");
            if (generation !== stateSerial) return false;
            locked = !!s.sessionLocked;
            if (locked) {
              fingers.clear();
              drag = false;
              clearInterval(dragHeartbeat);
              dragHeartbeat = 0;
              $("#drag").classList.remove("on");
              $("#drag").setAttribute("aria-pressed", "false");
              $$(".scrim").forEach((x) => x.classList.remove("open"));
            }
            $("#locked").classList.toggle("open", locked);
            $$("main,.scrim").forEach((x) => {
              x.inert = locked;
            });
            const appName = typeof s.frontApp === "string" ? s.frontApp.trim() : "";
            $("#connection").textContent = (s.name || "Connected") + (appName ? ` · ${appName}` : "");
            permissionMissing = s.accessibility === false;
            if (permissionMissing)
              status("Allow Accessibility access for Sofa Remote on your Mac.", true, "permission");
            else if (statusKind === "permission") status("");
            else clearRuntimeError();
            shortcuts = Array.isArray(s.shortcuts) ? s.shortcuts : [];
            const sig = JSON.stringify(shortcuts);
            if (sig !== shortcutSignature) {
              shortcutSignature = sig;
              renderShortcuts();
            }
            const select = $("#display");
            currentDisplay = s.displayID || "";
            const ds = JSON.stringify([s.displays, currentDisplay]);
            if (ds !== displaySignature) {
              displaySignature = ds;
              select.replaceChildren();
              for (const d of s.displays || []) {
                const option = document.createElement("option");
                option.value = d.id;
                option.textContent = d.name;
                select.append(option);
              }
              select.value = currentDisplay;
              select.disabled = !select.options.length;
            }
            $("#awake").checked = !!s.keepAwake;
            return true;
          } catch (e) {
            if (e.message !== "unpaired") status(e.message, true, "runtime");
            return false;
          }
        })();
        statePending = pending;
        try {
          return await pending;
        } finally {
          if (statePending === pending) statePending = null;
        }
      }
      document.addEventListener("visibilitychange", () => {
        if (document.visibilityState === "visible") refresh();
        else {
          fingers.clear();
          endDrag();
        }
      });
      window.addEventListener("pagehide", () => {
        fingers.clear();
        endDrag();
      });
      if (/^\d{6}$/.test(pairCode)) pair(pairCode);
      else refresh();
      setInterval(() => {
        if (document.visibilityState === "visible" && key) refresh();
      }, 3000);
    </script>
  </body>
</html>
"""#
}
