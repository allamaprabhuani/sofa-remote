import Foundation

/// Self-contained phone interface. It uses only the local Sofa Remote listener.
enum RemotePage {
    static let html = #"""
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover" />
    <meta name="theme-color" content="#003e74" />
    <meta name="apple-mobile-web-app-capable" content="yes" />
    <link rel="manifest" href="/manifest.webmanifest" />
    <link rel="icon" type="image/png" href="/icon-192.png" />
    <link rel="apple-touch-icon" sizes="180x180" href="/icon-180.png" />
    <title>Sofa Remote</title>
    <style>
      :root {
        color-scheme: dark;
        --bg: #003e74;
        --card: #0b4a80;
        --line: #7596b6;
        --muted: #d3e5f6;
        --accent: #d4ebff;
        --ink: #ffffff;
        --pad: #00335f;
        --sheet: #002e58;
        --pressed: #245e91;
        --selection: #dcecff;
        --selection-ink: #003e74;
        --danger: #ffd7d7;
        --error: #ffaaa7;
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
          100%/1.35 -apple-system,
          BlinkMacSystemFont,
          system-ui,
          sans-serif;
        background: var(--bg);
        color: var(--ink);
      }
      body {
        background: var(--bg);
      }
      button,
      input,
      select,
      textarea {
        font: inherit;
      }
      button {
        color: inherit;
        cursor: pointer;
      }
      button, a, input, select, textarea {
        /* Keep pinch zoom, but do not interpret repeated control taps as page zoom. */
        touch-action: manipulation;
      }
      .icon-definitions { position: absolute; width: 0; height: 0; overflow: hidden; }
      .control-icon { width: 22px; height: 22px; flex: 0 0 auto; fill: none; stroke: currentColor; stroke-width: 1.8; stroke-linecap: round; stroke-linejoin: round; pointer-events: none; }
      button[data-icon] { display: inline-flex; align-items: center; justify-content: center; gap: 7px; }
      button.icon-caption { flex-direction: column; gap: 4px; padding: 7px 4px; }
      .icon-caption > span { font-size: 0.6875rem; line-height: 1.2; }
      button:focus-visible,
      input:focus-visible,
      select:focus-visible,
      textarea:focus-visible,
      a:focus-visible {
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
        font-size: 1.1875rem;
        letter-spacing: -0.02em;
        margin: 0;
        flex: 1;
        min-width: 0;
        overflow-wrap: anywhere;
      }
      header small {
        display: block;
        font-size: 0.6875rem;
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
        overflow-wrap: anywhere;
      }
      button:active {
        background: var(--pressed);
      }
      button:disabled {
        opacity: 0.45;
        cursor: default;
      }
      .icon {
        width: 44px;
        padding: 0;
      }
      .icon.toolbar-caption { width: 62px; }
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
        background: var(--pad);
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
        grid-template-columns: repeat(3, minmax(0, 1fr));
      }
      .media {
        grid-template-columns: repeat(5, minmax(0, 1fr));
      }
      .actions {
        grid-template-columns: repeat(4, minmax(0, 1fr));
      }
      .row button {
        padding: 0 4px;
        font-size: 0.8125rem;
        font-weight: 650;
        overflow-wrap: anywhere;
      }
      .row button.on,
      .modifiers button.on {
        background: var(--selection);
        color: var(--selection-ink);
      }
      .media button {
        font-size: 1.25rem;
      }
      .status {
        font-size: 12px;
        color: var(--muted);
        min-height: 16px;
      }
      .status.error {
        color: var(--error);
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
        background: var(--sheet);
        border: 1px solid var(--line);
        border-radius: 24px 24px 0 0;
      }
      .sheet-head {
        display: flex;
        align-items: center;
        gap: 10px;
      }
      .sheet-head h2 {
        font-size: 1.125rem;
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
        font-size: 0.875rem;
        margin: 0;
      }
      a { color: var(--accent); overflow-wrap: anywhere; }
      .theme-controls { display: grid; grid-template-columns: minmax(0, 2fr) minmax(0, 1fr); gap: 10px; }
      .theme-controls label { display: flex; flex-direction: column; gap: 6px; overflow-wrap: anywhere; }
      .sheet a { min-height: 44px; display: flex; align-items: center; }
      input[type="color"] { padding: 4px; width: 100%; height: 46px; }
      .help-links { display: grid; gap: 6px; }
      .help-links a { min-height: 44px; display: flex; align-items: center; }
      .sheet ol { margin: 0; padding-left: 24px; }
      .sheet li { margin: 6px 0; }
      .sheet h3 { font-size: 1rem; margin: 6px 0 0; }
      #help-sheet { z-index: 12; }
      #diagnostics { width: 100%; min-height: 190px; padding: 12px; line-height: 1.5; resize: vertical; }
      #connection-help { border: 1px solid var(--line); border-radius: 15px; padding: 12px; }
      #connection-help[hidden] { display: none; }
      #connection-help p { margin: 0 0 10px; }
      .sheet p.error {
        color: var(--error);
      }
      .sheet label {
        font-size: 0.875rem;
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
        grid-template-columns: repeat(4, minmax(0, 1fr));
        gap: 6px;
      }
      .modifiers button {
        padding: 0;
        font-size: 0.75rem;
        overflow-wrap: anywhere;
      }
      .keygrid {
        display: grid;
        grid-template-columns: repeat(4, minmax(0, 1fr));
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
        color: var(--danger);
      }
      #pair,
      #locked {
        position: fixed;
        inset: 0;
        z-index: 10;
        background: var(--bg);
        padding: 24px;
        display: none;
        align-items: center;
        justify-content: center;
        overflow: auto;
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
        margin: auto;
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
        background: var(--selection);
        color: var(--selection-ink);
        font-weight: 700;
      }
      .card .error {
        color: var(--error);
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
      .support-icons { display: grid; grid-template-columns: repeat(6, minmax(44px, 1fr)); gap: 8px; margin: 18px 0; }
      .support-icons a { display: flex; align-items: center; justify-content: center; min-height: 48px; border-radius: 14px; background: var(--card); color: var(--ink); border: 1px solid var(--line); touch-action: manipulation; }
      .support-icons a:hover, .support-icons a:active { background: var(--pressed); }
      .support-icons a:focus-visible, .help-disclosure summary:focus-visible { outline: 3px solid var(--accent); outline-offset: 2px; }
      .help-disclosure { margin: 12px 0; }
      .help-disclosure summary { cursor: pointer; min-height: 44px; padding: 12px 0; }
      @media (max-width: 380px) { .support-icons { grid-template-columns: repeat(3, minmax(44px, 1fr)); } }
    </style>
  </head>
  <body>
    <svg class="icon-definitions" aria-hidden="true" focusable="false" xmlns="http://www.w3.org/2000/svg">
      <symbol id="icon-mute" viewBox="0 0 24 24"><path d="M10 5 5 9H2v6h3l5 4V5m6 4 6 6m0-6-6 6"/></symbol>
      <symbol id="icon-shortcuts" viewBox="0 0 24 24"><rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/></symbol>
      <symbol id="icon-settings" viewBox="0 0 24 24"><path d="m9 3-.6 2.4-2 .9L4 5.5 2 9l1.8 1.6v2.8L2 15l2 3.5 2.4-.8 2 .9L9 21h4l.6-2.4 2-.9 2.4.8 2-3.5-1.8-1.6v-2.8L20 9l-2-3.5-2.4.8-2-.9L13 3Z"/><circle cx="11" cy="12" r="3"/></symbol>
      <symbol id="icon-right-click" viewBox="0 0 24 24"><rect x="6" y="2" width="12" height="20" rx="6"/><path d="M12 2v8h6m-6 0H6"/><path d="M13 4h2l1 2v2h-3Z" fill="currentColor" stroke="none"/></symbol>
      <symbol id="icon-double-click" viewBox="0 0 24 24"><path d="m3 2 2 15 4-4 4 7 3-2-4-7 6-1Z"/><path d="M15 3V1m4 5 2-1m-1 5h3"/></symbol>
      <symbol id="icon-drag" viewBox="0 0 24 24"><path d="M8 12V5a2 2 0 0 1 4 0v6-1a2 2 0 0 1 4 0v1a2 2 0 0 1 4 0v5c0 4-3 6-6 6h-2c-2 0-3-1-4-3l-4-6a2 2 0 0 1 3-2l1 1Z"/></symbol>
      <symbol id="icon-previous" viewBox="0 0 24 24"><path d="M5 5v14m14-14L8 12l11 7Z"/></symbol>
      <symbol id="icon-play-pause" viewBox="0 0 24 24"><path d="m3 4 10 8-10 8Zm13 0v16m5-16v16"/></symbol>
      <symbol id="icon-next" viewBox="0 0 24 24"><path d="M19 5v14M5 5l11 7-11 7Z"/></symbol>
      <symbol id="icon-volume-down" viewBox="0 0 24 24"><path d="m11 5-5 4H3v6h3l5 4V5m5 7h6"/></symbol>
      <symbol id="icon-volume-up" viewBox="0 0 24 24"><path d="m11 5-5 4H3v6h3l5 4V5m5 7h6m-3-3v6"/></symbol>
      <symbol id="icon-keyboard" viewBox="0 0 24 24"><rect x="2" y="5" width="20" height="14" rx="2"/><path d="M6 9h.01M10 9h.01M14 9h.01M18 9h.01M6 12h.01M10 12h.01M14 12h.01M18 12h.01M7 16h10"/></symbol>
      <symbol id="icon-apps" viewBox="0 0 24 24"><rect x="2" y="6" width="15" height="15" rx="2"/><path d="M7 6V3h15v15h-5M2 11h15"/></symbol>
      <symbol id="icon-fullscreen" viewBox="0 0 24 24"><path d="M8 3H3v5m13-5h5v5M3 16v5h5m13-5v5h-5"/></symbol>
      <symbol id="icon-search" viewBox="0 0 24 24"><circle cx="10" cy="10" r="7"/><path d="m15 15 6 6"/></symbol>
      <symbol id="icon-desktop" viewBox="0 0 24 24"><rect x="2" y="3" width="20" height="14" rx="2"/><path d="M8 21h8m-4-4v4"/></symbol>
      <symbol id="icon-folder" viewBox="0 0 24 24"><path d="M2 8V4h7l3 3h10v13H2V8Zm0 0h20"/></symbol>
      <symbol id="icon-screen-off" viewBox="0 0 24 24"><path d="M2 3h20v14H2Zm6 18h8m-4-4v4m-6-9 12-6"/></symbol>
      <symbol id="icon-wake" viewBox="0 0 24 24"><path d="M12 2v8m-5-6a9 9 0 1 0 10 0"/></symbol>
      <symbol id="icon-lock" viewBox="0 0 24 24"><rect x="4" y="10" width="16" height="12" rx="2"/><path d="M8 10V6a4 4 0 0 1 8 0v4m-4 5v3"/></symbol>
      <symbol id="icon-help" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"/><path d="M9 8a3 3 0 0 1 6 0c0 2-3 2-3 5m0 4h.01"/></symbol>
      <symbol id="icon-copy" viewBox="0 0 24 24"><rect x="8" y="8" width="13" height="13" rx="2"/><path d="M16 8V3H3v13h5"/></symbol>
      <symbol id="icon-bug" viewBox="0 0 24 24"><path d="M8 8h8v9a4 4 0 0 1-8 0ZM9 8V6a3 3 0 0 1 6 0v2M4 9l4 2M4 16h4M20 9l-4 2M20 16h-4M12 9v11"/></symbol>
      <symbol id="icon-idea" viewBox="0 0 24 24"><path d="M8 15a7 7 0 1 1 8 0l-1 3H9ZM9 21h6"/></symbol>
      <symbol id="icon-chat" viewBox="0 0 24 24"><path d="M3 4h15v11H8l-5 4ZM18 9h3v12l-5-3h-5v-3"/></symbol>
      <symbol id="icon-globe" viewBox="0 0 24 24"><circle cx="12" cy="12" r="9"/><ellipse cx="12" cy="12" rx="4" ry="9"/><path d="M3 12h18"/></symbol>
      <symbol id="icon-heart" viewBox="0 0 24 24"><path d="M12 21 3 12C-3 4 7 0 12 7 17 0 27 4 21 12Z"/></symbol>
      <symbol id="icon-updates" viewBox="0 0 24 24"><circle cx="12" cy="12" r="9"/><path d="M12 6v12M7 13l5 5 5-5"/></symbol>
    </svg>
    <main>
      <header>
        <h1>Sofa Remote<small id="connection">Connecting…</small></h1>
        <button class="icon" data-icon="mute" data-action="mute" aria-label="Mute" title="Mute"></button
        ><button class="icon icon-caption toolbar-caption" data-icon="shortcuts" id="shortcuts-open" aria-label="Shortcuts" title="Shortcuts"><span>Shortcuts</span></button
        ><button class="icon" data-icon="settings" id="settings-open" aria-label="Settings" title="Settings"></button>
      </header>
      <div
        id="pad"
        role="group"
        tabindex="0"
        aria-label="Touchpad. Drag to move, tap to click, use two fingers to scroll. With a keyboard, use arrow keys to move and Enter or Space to click."
      >
        <span class="pad-title">Touchpad</span
        ><span class="hint">Tap to click · Two fingers to scroll</span>
      </div>
      <div class="row clicks">
        <button id="right" data-icon="right-click" class="icon-caption" title="Right click"><span>Right click</span></button><button id="double" data-icon="double-click" class="icon-caption" title="Double click"><span>Double click</span></button
        ><button id="drag" data-icon="drag" class="icon-caption" aria-pressed="false" title="Drag: toggle to hold or release"><span>Drag</span></button>
      </div>
      <div class="row media">
        <button data-icon="previous" data-action="previous" aria-label="Previous track" title="Previous track"></button
        ><button data-icon="play-pause" data-action="playPause" aria-label="Play or pause" title="Play or pause"></button
        ><button data-icon="next" data-action="next" aria-label="Next track" title="Next track"></button
        ><button data-icon="volume-down" data-action="volumeDown" aria-label="Volume down" title="Volume down"></button
        ><button data-icon="volume-up" data-action="volumeUp" aria-label="Volume up" title="Volume up"></button>
      </div>
      <div class="row actions">
        <button id="keyboard-open" data-icon="keyboard" class="icon-caption" title="Keyboard"><span>Keyboard</span></button><button data-icon="apps" class="icon-caption" data-action="appSwitcher" aria-label="App switcher" title="App switcher"><span>Apps</span></button
        ><button data-icon="fullscreen" class="icon-caption" data-action="fullscreen" title="Full screen"><span>Full screen</span></button
        ><button data-icon="search" class="icon-caption" data-action="spotlight" title="Spotlight search"><span>Spotlight</span></button>
      </div>
      <div id="status" class="status" role="status" aria-live="polite"></div>
      <aside id="connection-help" hidden aria-label="Reconnect to your Mac">
        <p>Keep your Mac awake and Sofa Remote sharing. Check that both devices are on the same Wi-Fi or Tailscale network. If the Mac's address changed, open Sofa Remote on the Mac and scan its new QR code.</p>
        <div class="sheet-row"><button id="reconnect">Try reconnecting</button><button data-help data-icon="help" title="About and Help">About &amp; Help</button></div>
      </aside>
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
          ><button data-key="backspace" aria-label="Backspace">⌫</button><button data-key="delete">Delete</button
          ><button data-key="left" aria-label="Left arrow">←</button><button data-key="up" aria-label="Up arrow">↑</button><button data-key="down" aria-label="Down arrow">↓</button
          ><button data-key="right" aria-label="Right arrow">→</button><button data-key="space">Space</button
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
        <label for="url">Open a website on your Mac</label>
      <form class="address" id="open-form">
        <input
          class="field"
          id="url"
          inputmode="url"
          aria-label="Website address"
          placeholder="Website address"
          autocapitalize="off"
          autocorrect="off"
          spellcheck="false"
        /><button>Open</button>
      </form>
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
        <div class="theme-controls">
          <label for="theme">Appearance<select class="field" id="theme"><option value="imperial">Imperial blue</option><option value="light">Light</option><option value="ocean">Ocean</option><option value="custom">Custom</option></select></label>
          <label for="custom-colour">Custom background colour<input class="field" type="color" id="custom-colour" value="#003e74" disabled /></label>
        </div>
        <p>Appearance is saved only in this phone browser. Custom colours get automatic high-contrast text.</p>
        <a href="https://github.com/allamaprabhuani/sofa-remote/issues/new?template=bug_report.yml" target="_blank" rel="noopener noreferrer">Report a bug</a>
        <label for="display">Jump pointer to display</label
        ><select class="field" id="display"></select>
        <p>Choosing a display jumps the pointer there once. The touchpad still moves the pointer freely across every connected display, like a Mac trackpad.</p>
        <button data-icon="desktop" data-action="moveWindow" title="Move front window">Move front window to this display</button>
        <div class="sheet-row">
          <button data-icon="desktop" data-action="showDesktop" title="Show desktop">Show desktop</button
          ><button data-icon="folder" data-action="downloads" title="Open Downloads">Downloads</button>
        </div>
        <div class="sheet-row">
          <button data-icon="screen-off" data-action="screenOff" title="Turn displays off">Screen off</button
          ><button data-icon="wake" data-action="screenOn" title="Wake displays">Wake screen</button>
        </div>
        <p>Screen off turns every connected display dark; macOS may lock while the display is off.</p>
        <label class="sheet-row"
          ><span>Keep Mac awake while sharing</span><input type="checkbox" id="awake"
        /></label>
        <p>Prevents idle system sleep; the display can still sleep.</p>
        <button class="danger" data-icon="lock" id="lock" title="Lock Mac">Lock Mac…</button>
        <p>
          Waking the screen does not unlock your Mac. Unlock on the Mac; Apple Watch unlock is a separate
          macOS setting.
        </p>
        <div id="devices"></div>
        <button data-help data-icon="help" title="About and Help">About &amp; Help</button>
      </div>
    </div>
    <div class="scrim" id="help-sheet">
      <div class="sheet" role="dialog" aria-modal="true" aria-label="About and Help">
        <div class="sheet-head"><h2>About &amp; Help</h2><button data-close>Done</button></div>
        <p id="app-version">Sofa Remote · connect to see the Mac app version</p>
        <p>Control your Mac from your phone. By Allamaprabhu Ani · Free and open source.</p>
        <nav class="support-icons" aria-label="Support and project links">
          <a data-icon="bug" href="https://github.com/allamaprabhuani/sofa-remote/issues/new?template=bug_report.yml" target="_blank" rel="noopener noreferrer" aria-label="Report a bug" title="Report a bug"></a>
          <a data-icon="idea" href="https://github.com/allamaprabhuani/sofa-remote/issues/new?template=feature_request.yml" target="_blank" rel="noopener noreferrer" aria-label="Suggest a feature" title="Suggest a feature"></a>
          <a data-icon="chat" href="https://github.com/allamaprabhuani/sofa-remote/discussions" target="_blank" rel="noopener noreferrer" aria-label="Questions and developer contact" title="Questions and developer contact"></a>
          <a data-icon="globe" href="https://allamaprabhuani.github.io/sofa-remote/" target="_blank" rel="noopener noreferrer" aria-label="Project website" title="Project website"></a>
          <a data-icon="heart" href="https://allamaprabhuani.github.io/sofa-remote/#support" target="_blank" rel="noopener noreferrer" aria-label="Support this project" title="Support this project"></a>
          <a data-icon="updates" href="https://github.com/allamaprabhuani/sofa-remote/releases" target="_blank" rel="noopener noreferrer" aria-label="Check for updates and release notes" title="Check for updates and release notes"></a>
        </nav>
        <details class="help-disclosure"><summary>Setup and connection help</summary>
        <p>Allow Accessibility in the Mac app, show its pairing code and scan the QR with your phone Camera. In Safari, use Share → Add to Home Screen. For connection or permission problems, follow the setup guide below.</p>
          <nav class="help-links" aria-label="Setup links">
            <a href="https://github.com/allamaprabhuani/sofa-remote/blob/main/docs/SETUP.md" target="_blank" rel="noopener noreferrer">Setup guide</a>
            <a href="https://github.com/allamaprabhuani/sofa-remote/blob/main/SUPPORT.md" target="_blank" rel="noopener noreferrer">Troubleshooting</a>
          </nav>
        </details>
        <details class="help-disclosure"><summary>Privacy and credits</summary>
          <p>No screen streaming, analytics, ads or accounts. Paired phones can control your desktop. Local HTTP is unencrypted; use trusted Wi-Fi or Tailscale. Stop sharing or revoke a phone on the Mac to end access.</p>
          <nav class="help-links" aria-label="Privacy and credits links">
            <a href="https://github.com/allamaprabhuani/sofa-remote/blob/main/docs/PRIVACY.md" target="_blank" rel="noopener noreferrer">Privacy policy</a>
            <a href="https://github.com/allamaprabhuani/sofa-remote/blob/main/LICENSE" target="_blank" rel="noopener noreferrer">MIT licence</a>
            <a href="https://github.com/allamaprabhuani/sofa-remote/blob/main/NOTICE" target="_blank" rel="noopener noreferrer">Credits and third-party notices</a>
            <a href="https://github.com/allamaprabhuani/sofa-remote/security/advisories/new" target="_blank" rel="noopener noreferrer">Report a security vulnerability privately</a>
            <a href="https://github.com/allamaprabhuani/sofa-remote" target="_blank" rel="noopener noreferrer">Source code</a>
            <a href="https://allamaprabhuani.github.io/" target="_blank" rel="noopener noreferrer">Developer website</a>
          </nav>
        </details>
        <details class="help-disclosure" id="diagnostic-details"><summary>Diagnostic summary</summary>
        <p>Preview before copying. Only app, macOS and browser versions plus permission and sharing status are included. No typed text, tokens, personal URLs, screenshots, Mac names or network addresses. Nothing is uploaded automatically.</p>
        <label for="diagnostics">Review diagnostic summary</label>
        <textarea class="field" id="diagnostics" readonly spellcheck="false"></textarea>
        <button id="copy-diagnostics" data-icon="copy" title="Copy diagnostic summary">Copy diagnostic summary</button>
        <p id="copy-result" role="status" aria-live="polite"></p>
        </details>
      </div>
    </div>
    <div id="pair" role="dialog" aria-modal="true" aria-labelledby="pair-title">
      <div class="card">
        <h1 id="pair-title">Pair with your Mac</h1>
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
        <button data-help data-icon="help" title="About and Help">About &amp; Help</button>
      </div>
    </div>
    <div id="locked" role="dialog" aria-modal="true" aria-labelledby="locked-title">
      <div class="card">
        <h1 id="locked-title">Input paused</h1>
        <p>
          Mac is locked, using secure text input, or paused. Unlock the Mac and choose Resume input in Sofa
          Remote on the Mac if needed.
        </p>
        <button class="primary" data-icon="wake" id="wake" title="Wake displays">Wake screen</button>
        <p id="locked-error" role="status"></p>
        <button data-help data-icon="help" title="About and Help">About &amp; Help</button>
      </div>
    </div>
    <script>
      const $ = (s) => document.querySelector(s),
        $$ = (s) => [...document.querySelectorAll(s)];
      // Reuse small local SVG paths; icons never fetch a library or contact a service.
      $$('[data-icon]').forEach((button) => {
        const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
        svg.setAttribute("class", "control-icon");
        svg.setAttribute("viewBox", "0 0 24 24");
        svg.setAttribute("aria-hidden", "true");
        svg.setAttribute("focusable", "false");
        const use = document.createElementNS("http://www.w3.org/2000/svg", "use");
        use.setAttribute("href", "#icon-" + button.dataset.icon);
        svg.append(use);
        button.prepend(svg);
      });
      const themes = {
        imperial: { bg: "#003e74", card: "#0b4a80", pad: "#00335f", sheet: "#002e58", line: "#7596b6", muted: "#d3e5f6", accent: "#d4ebff", ink: "#ffffff", pressed: "#245e91", selection: "#dcecff", "selection-ink": "#003e74", danger: "#ffd7d7", error: "#ffaaa7" },
        light: { bg: "#f4f7fc", card: "#ffffff", pad: "#e7eef7", sheet: "#ffffff", line: "#72869d", muted: "#3c526b", accent: "#003e7d", ink: "#003e74", pressed: "#dee8f5", selection: "#003e74", "selection-ink": "#ffffff", danger: "#9d1e2c", error: "#a51627" },
        ocean: { bg: "#062d35", card: "#103c45", pad: "#0b343d", sheet: "#0b343d", line: "#517780", muted: "#bcd8dd", accent: "#a1e9ee", ink: "#f4ffff", pressed: "#244e57", selection: "#c5f4f5", "selection-ink": "#062d35", danger: "#ffb8b8", error: "#ffaaa7" },
      };
      const safeColour = (v) => typeof v === "string" && /^#[0-9a-f]{6}$/i.test(v) ? v.toLowerCase() : "#003e74";
      function luminance(hex) {
        const channels = [1, 3, 5].map((n) => {
          const value = parseInt(hex.slice(n, n + 2), 16) / 255;
          return value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4;
        });
        return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722;
      }
      function contrast(a, b) {
        const first = luminance(a), second = luminance(b);
        return (Math.max(first, second) + 0.05) / (Math.min(first, second) + 0.05);
      }
      function mixColour(a, b, ratio) {
        return "#" + [1, 3, 5].map((n) => Math.round(parseInt(a.slice(n, n + 2), 16) * (1 - ratio) + parseInt(b.slice(n, n + 2), 16) * ratio).toString(16).padStart(2, "0")).join("");
      }
      function customTheme(colour) {
        const bg = safeColour(colour);
        const ink = contrast(bg, "#ffffff") >= contrast(bg, "#000000") ? "#ffffff" : "#000000";
        const shade = ink === "#ffffff" ? "#000000" : "#ffffff";
        const card = mixColour(bg, shade, 0.12), pad = mixColour(bg, shade, 0.06);
        let line = ink;
        for (const ratio of [0.55, 0.7, 0.85, 1]) {
          const candidate = mixColour(bg, ink, ratio);
          if (contrast(candidate, bg) >= 3 && contrast(candidate, card) >= 3) { line = candidate; break; }
        }
        return { bg, card, pad, sheet: card, line, muted: ink, accent: ink, ink,
          pressed: mixColour(bg, shade, 0.2), selection: ink, "selection-ink": bg, danger: ink, error: ink };
      }
      let themeState = { name: "imperial", colour: "#003e74" };
      function applyTheme(name, colour) {
        const requested = name === "oxford" ? "imperial" : name;
        const known = ["imperial", "light", "ocean", "custom"].includes(requested) ? requested : "imperial";
        themeState = { name: known, colour: safeColour(colour) };
        const palette = known === "custom" ? customTheme(themeState.colour) : themes[known];
        Object.entries(palette).forEach(([key, value]) => document.documentElement.style.setProperty("--" + key, value));
        document.documentElement.style.colorScheme = contrast(palette.bg, "#000000") > contrast(palette.bg, "#ffffff") ? "light" : "dark";
        $("meta[name=theme-color]").content = palette.bg;
        $("#theme").value = known;
        $("#custom-colour").value = themeState.colour;
        $("#custom-colour").disabled = known !== "custom";
      }
      function saveTheme() {
        try { localStorage.setItem("sofaTheme", themeState.name); localStorage.setItem("sofaColour", themeState.colour); } catch {}
      }
      try { applyTheme(localStorage.getItem("sofaTheme"), localStorage.getItem("sofaColour")); }
      catch { applyTheme("imperial", "#003e74"); }
      $("#theme").onchange = (e) => { applyTheme(e.target.value, themeState.colour); saveTheme(); };
      $("#custom-colour").oninput = (e) => applyTheme("custom", e.target.value);
      $("#custom-colour").onchange = saveTheme;
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
      let supportState = null;
      const sheetStack = [];
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
      function safeVersion(value) {
        return typeof value === "string" && /^\d{1,5}(?:\.\d{1,5}){0,3}$/.test(value) ? value : "Unavailable";
      }
      function browserVersion() {
        const ua = navigator.userAgent;
        for (const [name, pattern] of [
          ["Edge", /(?:Edg|EdgiOS|EdgA)\/([\d.]+)/],
          ["Firefox", /(?:Firefox|FxiOS)\/([\d.]+)/],
          ["Chrome", /(?:Chrome|CriOS)\/([\d.]+)/],
          ["Safari", /Version\/([\d.]+).*Safari\//],
        ]) {
          const found = ua.match(pattern);
          if (found) return `${name} ${safeVersion(found[1])}`;
        }
        return "Other browser";
      }
      function diagnosticSummary() {
        const state = supportState || {};
        const yesNo = (v) => v === true ? "Yes" : v === false ? "No" : "Unavailable";
        return [
          "Sofa Remote diagnostic summary",
          `App version: ${safeVersion(state.appVersion)}`,
          `Build: ${safeVersion(state.appBuild)}`,
          `macOS: ${safeVersion(state.macOSVersion)}`,
          `Browser: ${browserVersion()}`,
          `Accessibility allowed: ${yesNo(state.accessibility)}`,
          `Sharing enabled: ${yesNo(state.sharing)}`,
          `Input paused: ${yesNo(state.sessionLocked)}`,
          supportState ? "Mac status is from the last successful connection." : "Connect to the Mac to include its version and status.",
        ].join("\n");
      }
      function updateSupport() {
        const version = safeVersion(supportState?.appVersion), build = safeVersion(supportState?.appBuild);
        $("#app-version").textContent = supportState
          ? `Sofa Remote ${version} · build ${build}`
          : "Sofa Remote · connect to see the Mac app version";
        const summary = diagnosticSummary();
        if ($("#diagnostics").value !== summary) $("#diagnostics").value = summary;
      }
      function activeOverlay() {
        return $(".scrim.open") || $("#locked.open") || $("#pair.open");
      }
      function updateLayers() {
        const active = activeOverlay();
        $("main").inert = !!active;
        $$(".scrim,#pair,#locked").forEach((x) => x.inert = !!active && x !== active);
      }
      $$(".sheet").forEach((sheet) => {
        const note = document.createElement("p");
        note.className = "sheet-status";
        note.setAttribute("role", "status");
        sheet.append(note);
      });
      function showPair() {
        supportState = null;
        updateSupport();
        clearInterval(dragHeartbeat);
        dragHeartbeat = 0;
        drag = false;
        $("#drag").classList.remove("on");
        $("#drag").setAttribute("aria-pressed", "false");
        $("#locked").classList.remove("open");
        if ($("#help-sheet").classList.contains("open")) {
          const help = sheetStack.find((entry) => entry.id === "help-sheet");
          sheetStack.splice(0, sheetStack.length, ...(help ? [help] : []));
        } else {
          $$(".scrim").forEach((x) => x.classList.remove("open"));
          sheetStack.length = 0;
        }
        if ($("#pair").classList.contains("open")) { updateLayers(); return; }
        $("#pair").classList.add("open");
        updateLayers();
        setTimeout(() => { if (!$("#help-sheet.open")) $("#code").focus(); }, 50);
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
          updateLayers();
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
      function isMotion(body) {
        return (
          body.type === "move" ||
          body.type === "scroll" ||
          (body.type === "drag" && body.phase === "move")
        );
      }
      function discardQueuedInput() {
        const release = drag || queue.some((item) => item.body.type === "drag");
        while (queue.length) queue.shift().done(false);
        clearTimeout(gestureTimer);
        gestureTimer = 0;
        if (drag) endDrag();
        else if (release) command({ type: "drag", phase: "end" });
      }
      function pump() {
        if (active || gestureTimer || !queue.length) return;
        const head = queue[0],
          body = head.body,
          motion = isMotion(body);
        if (motion && Date.now() - head.queuedAt > 250) {
          discardQueuedInput();
          status("Connection is slow; old movement was stopped. Try again.", true, "runtime");
          return;
        }
        const delay = motion ? Math.max(0, 16 - (Date.now() - lastGesture)) : 0;
        if (delay) {
          gestureTimer = setTimeout(() => {
            gestureTimer = 0;
            pump();
          }, delay);
          return;
        }
        if (!key || (locked && body.action !== "screenOn")) {
          queue.shift();
          head.done(false);
          pump();
          return;
        }
        let outbound;
        if (motion) {
          // Split accumulated travel into bounded packets so the server never sees
          // out-of-range deltas. The head keeps the remainder in correct order so trailing
          // clicks/drag-end stay queued behind the full gesture.
          const limit = body.type === "scroll" ? 300 : 1000;
          const dx = Math.max(-limit, Math.min(limit, body.dx || 0));
          const dy = Math.max(-limit, Math.min(limit, body.dy || 0));
          body.dx = (body.dx || 0) - dx;
          body.dy = (body.dy || 0) - dy;
          outbound = Object.assign({}, body, { dx, dy });
          lastGesture = Date.now();
          if ((body.dx || 0) === 0 && (body.dy || 0) === 0) {
            queue.shift();
          }
        } else {
          queue.shift();
          outbound = body;
        }
        const controller = new AbortController();
        active = controller;
        request("/command", outbound, true, controller.signal)
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
            if (!motion) head.done(ok);
            // A failed/ambiguous send invalidates queued input rather than replaying it later.
            // An urgent wake already cleared the old queue before aborting its request.
            if (!ok && !controller.signal.aborted) discardQueuedInput();
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
          const motion = isMotion(body);
          const last = queue[queue.length - 1];
          if (
            !urgent &&
            motion &&
            last &&
            isMotion(last.body) &&
            last.body.type === body.type &&
            last.body.phase === body.phase
          ) {
            // Keep exact accumulated proportional travel; splitting at pump time bounds the
            // per-packet delta sent to the server.
            const dx = (last.body.dx || 0) + (body.dx || 0),
              dy = (last.body.dy || 0) + (body.dy || 0);
            if (Math.abs(dx) > 3600 || Math.abs(dy) > 3600) {
              discardQueuedInput();
              status("Connection is slow; old movement was stopped. Try again.", true, "runtime");
              resolve(false);
              return;
            }
            last.body.dx = dx;
            last.body.dy = dy;
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
          if (motion) {
            // Motion is best-effort; the caller does not need to block on a specific packet.
            queue.push({ body, done: () => {}, queuedAt: Date.now() });
            resolve(true);
          } else {
            queue.push({ body, done: resolve });
          }
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
      pad.addEventListener("keydown", (e) => {
        if (e.target !== pad || document.activeElement !== pad || locked || !key || document.hidden || activeOverlay()
            || e.altKey || e.ctrlKey || e.metaKey) return;
        const delta = e.shiftKey ? 40 : 10;
        const movement = { ArrowLeft: [-delta, 0], ArrowRight: [delta, 0], ArrowUp: [0, -delta], ArrowDown: [0, delta] }[e.key];
        if (movement) {
          e.preventDefault(); e.stopPropagation();
          command({ type: "move", dx: movement[0], dy: movement[1] });
        } else if (e.key === "Enter" || e.key === " ") {
          e.preventDefault(); e.stopPropagation();
          if (!e.repeat) command({ type: "click", button: "left", count: 1 });
        }
      });
      let travel = 0,
        down = 0,
        multi = false;
      const pointerFraction = { dx: 0, dy: 0 };
      // CSS touch-action handles modern browsers. This local fallback suppresses only
      // the default browser action of a short one-finger pad tap on older Safari.
      // It sends no input: pointerup below is still the sole remote-click handler.
      let padTouchSequence = null;
      pad.addEventListener("touchstart", (e) => {
        if (!padTouchSequence && e.touches.length) {
          const first = e.touches[0];
          padTouchSequence = { x: first.clientX, y: first.clientY, started: Date.now(), moved: false, multi: e.touches.length !== 1 };
        } else if (padTouchSequence && e.touches.length > 1) padTouchSequence.multi = true;
      }, { passive: true });
      pad.addEventListener("touchmove", (e) => {
        if (!padTouchSequence || !e.touches.length) return;
        const first = e.touches[0];
        if (e.touches.length > 1) padTouchSequence.multi = true;
        if (Math.abs(first.clientX - padTouchSequence.x) + Math.abs(first.clientY - padTouchSequence.y) >= 8)
          padTouchSequence.moved = true;
      }, { passive: true });
      pad.addEventListener("touchend", (e) => {
        if (e.touches.length) return;
        const tap = padTouchSequence;
        padTouchSequence = null;
        if (tap && !tap.multi && !tap.moved && e.changedTouches.length === 1
            && Date.now() - tap.started < 300 && e.cancelable) e.preventDefault();
      }, { passive: false });
      pad.addEventListener("touchcancel", () => { padTouchSequence = null; }, { passive: true });
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
        } else {
          // Match Mac TV's touchpad feel and preserve small movements across samples.
          const gain = 1.6 + Math.min(Math.hypot(dx, dy) / 6, 3);
          pointerFraction.dx += dx * gain;
          pointerFraction.dy += dy * gain;
          const moveX = Math.round(pointerFraction.dx), moveY = Math.round(pointerFraction.dy);
          pointerFraction.dx -= moveX;
          pointerFraction.dy -= moveY;
          if (moveX || moveY)
            command(drag ? { type: "drag", phase: "move", dx: moveX, dy: moveY } : { type: "move", dx: moveX, dy: moveY });
        }
      });
      function dropQueuedMotion() {
        pointerFraction.dx = pointerFraction.dy = 0;
        // Discard still-queued motion for explicit cancel/hidden/disconnect only; a normal
        // pointerup must leave queued motion in place so the full travel is still delivered.
        for (let i = queue.length - 1; i >= 0; i--) {
          if (isMotion(queue[i].body)) queue.splice(i, 1)[0].done(false);
        }
      }
      function lift(e) {
        if (!fingers.delete(e.pointerId)) return;
        if (e.type !== "pointerup") {
          fingers.clear();
          dropQueuedMotion();
          endDrag();
          return;
        }
        // Ordinary lift flushes: queued motion stays queued, click is appended after it.
        if (!fingers.size && !multi && !drag && travel < 8 && Date.now() - down < 300)
          command({ type: "click", button: "left", count: 1 });
      }
      pad.addEventListener("pointerup", lift);
      pad.addEventListener("pointercancel", lift);
      pad.addEventListener("lostpointercapture", (e) => {
        if (fingers.has(e.pointerId)) {
          fingers.clear();
          dropQueuedMotion();
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
      function sheet(id, opener = document.activeElement) {
        if (locked && id !== "help-sheet") return;
        if ($("#" + id).classList.contains("open")) return;
        $$(".scrim").forEach((x) => x.classList.remove("open"));
        sheetStack.push({ id, opener });
        $("#" + id).classList.add("open");
        if (id === "help-sheet") { $("#diagnostic-details").open = false; updateSupport(); $("#copy-result").textContent = ""; }
        updateLayers();
        $("#" + id + " [data-close]").focus();
      }
      function closeSheet() {
        const current = sheetStack.pop();
        $$(".scrim").forEach((x) => x.classList.remove("open"));
        const previous = sheetStack.at(-1);
        if (previous && (!locked || previous.id === "help-sheet")) $("#" + previous.id).classList.add("open");
        else if (locked) sheetStack.length = 0;
        updateLayers();
        if (current?.opener?.isConnected && current.opener.getClientRects().length && !current.opener.closest("[inert]")) current.opener.focus();
        else if (activeOverlay()) activeOverlay().querySelector("button,input,a")?.focus();
        else $("#settings-open").focus();
      }
      $("#keyboard-open").onclick = (e) => sheet("keyboard-sheet", e.currentTarget);
      $("#shortcuts-open").onclick = (e) => sheet("shortcuts-sheet", e.currentTarget);
      $("#settings-open").onclick = (e) => {
        sheet("settings-sheet", e.currentTarget);
        loadDevices();
      };
      $$("[data-help]").forEach((b) => b.onclick = (e) => sheet("help-sheet", e.currentTarget));
      $$("[data-close]").forEach((b) => (b.onclick = closeSheet));
      $$(".scrim").forEach(
        (s) =>
          (s.onclick = (e) => {
            if (e.target === s) closeSheet();
          }),
      );
      document.addEventListener("keydown", (e) => {
        const overlay = activeOverlay();
        if (!overlay) return;
        if (e.key === "Escape" && overlay.classList.contains("scrim")) {
          e.preventDefault(); closeSheet(); return;
        }
        if (e.key !== "Tab") return;
        const focusable = [...overlay.querySelectorAll("button:not(:disabled),a[href],input:not(:disabled),select:not(:disabled),textarea:not(:disabled),summary")]
          .filter((x) => {
            if (!x.getClientRects().length || x.closest("[inert]")) return false;
            for (let parent = x.parentElement; parent; parent = parent.parentElement) {
              if (parent.matches("details:not([open])") && !parent.querySelector(":scope > summary")?.contains(x)) return false;
            }
            return true;
          });
        if (!focusable.length) { e.preventDefault(); return; }
        const first = focusable[0], last = focusable.at(-1);
        if (e.shiftKey && (document.activeElement === first || !overlay.contains(document.activeElement))) {
          e.preventDefault(); last.focus();
        } else if (!e.shiftKey && (document.activeElement === last || !overlay.contains(document.activeElement))) {
          e.preventDefault(); first.focus();
        }
      });
      $("#copy-diagnostics").onclick = async () => {
        const preview = $("#diagnostics"), result = $("#copy-result");
        try {
          if (!navigator.clipboard?.writeText) throw Error("Clipboard unavailable");
          await navigator.clipboard.writeText(preview.value);
          result.textContent = "Diagnostic summary copied. Review it again before posting publicly.";
        } catch {
          preview.focus(); preview.select(); preview.setSelectionRange(0, preview.value.length);
          result.textContent = "Automatic copy is unavailable on this connection. Touch and hold the selected summary, then choose Copy.";
        }
      };
      $("#reconnect").onclick = () => { $("#connection").textContent = "Reconnecting…"; refresh(); };
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
            supportState = {
              appVersion: s.appVersion, appBuild: s.appBuild, macOSVersion: s.macOSVersion,
              accessibility: s.accessibility, sharing: s.sharing, sessionLocked: s.sessionLocked,
            };
            updateSupport();
            $("#connection-help").hidden = true;
            const wasLocked = locked;
            locked = !!s.sessionLocked;
            if (locked) {
              fingers.clear();
              drag = false;
              clearInterval(dragHeartbeat);
              dragHeartbeat = 0;
              $("#drag").classList.remove("on");
              $("#drag").setAttribute("aria-pressed", "false");
              if ($("#help-sheet.open")) {
                const help = sheetStack.find((entry) => entry.id === "help-sheet");
                sheetStack.splice(0, sheetStack.length, ...(help ? [help] : []));
              } else {
                $$(".scrim").forEach((x) => x.classList.remove("open"));
                sheetStack.length = 0;
              }
            }
            $("#locked").classList.toggle("open", locked);
            updateLayers();
            if (locked && !wasLocked && !$("#help-sheet.open")) $("#wake").focus();
            else if (!locked && wasLocked && !activeOverlay()) $("#settings-open").focus();
            const appName = typeof s.frontApp === "string" ? s.frontApp.trim() : "";
            $("#connection").textContent = "Connected" + (s.name ? ` · ${s.name}` : "") + (appName ? ` · ${appName}` : "");
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
            if (e.message !== "unpaired") {
              $("#connection").textContent = "Disconnected · try reconnecting";
              $("#connection-help").hidden = false;
              status(e.message, true, "runtime");
            }
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
          dropQueuedMotion();
          endDrag();
        }
      });
      window.addEventListener("pagehide", () => {
        fingers.clear();
        dropQueuedMotion();
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
