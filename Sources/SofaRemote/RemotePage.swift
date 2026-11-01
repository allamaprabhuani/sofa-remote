import Foundation

/// Self-contained phone interface. It uses only the local Sofa Remote listener.
enum RemotePage {
    static let html = #"""
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover" />
    <meta name="theme-color" content="#1f1f1f" />
    <meta name="apple-mobile-web-app-capable" content="yes" />
    <link rel="manifest" href="/manifest.webmanifest" />
    <link rel="icon" type="image/png" href="/icon-192.png" />
    <link rel="apple-touch-icon" sizes="180x180" href="/icon-180.png" />
    <title>Sofa Remote</title>
    <style>
      :root {
        color-scheme: dark;
        --bg: #1f1f1f;
        --card: #292929;
        --line: #777777;
        --muted: #b8b8b8;
        --accent: #a9cdf5;
        --ink: #ededed;
        --pad: #181818;
        --sheet: #1f1f1f;
        --pressed: #383838;
        --selection: #ededed;
        --selection-ink: #1f1f1f;
        --danger: #ffb4ab;
        --error: #ffb4ab;
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
      .icon-caption > span { font-size: 0.75rem; font-weight: 600; line-height: 1.2; }
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
        font-family: ui-rounded, -apple-system, BlinkMacSystemFont, system-ui, sans-serif;
        font-weight: 700;
        font-size: 1.1875rem;
        letter-spacing: -0.02em;
        margin: 0;
        flex: 1;
        min-width: 0;
        overflow-wrap: anywhere;
      }
      header small {
        display: block;
        font-size: 0.75rem;
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
      .icon.toolbar-caption { width: auto; min-width: 70px; flex-shrink: 0; padding-inline: 6px; }
      .toolbar-caption > span { white-space: nowrap; }
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
      .present-open { width: 100%; margin-top: 8px; min-height: 48px; font-weight: 650; }
      .present-nav { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
      .present-nav button { min-height: 64px; font-size: 1.05rem; font-weight: 700; }
      #present-sheet .sheet-status:empty { display: none; }
      #present-sheet .sheet-status:not(:empty) { position: sticky; top: 0; z-index: 2; margin: 0; padding: 10px 12px; background: var(--sheet); border: 1px solid var(--line); border-radius: 10px; overflow-wrap: anywhere; }
      #present-sheet .sheet-status.error { color: var(--error); }
      .present-tools { display: flex; gap: 8px; flex-wrap: wrap; margin: 10px 0; }
      .present-tools button { flex: 1 1 auto; min-height: 48px; }
      .present-tools button[aria-pressed="true"] { background: var(--selection); color: var(--selection-ink); }
      #present-pad { position: relative; width: 100%; aspect-ratio: 16 / 9; min-height: 150px; max-height: 300px; border: 2px solid var(--line); border-radius: 15px; background: var(--pad); touch-action: none; user-select: none; display: grid; place-items: center; text-align: center; padding: 16px; }
      #present-pad:focus-visible { outline: 3px solid var(--accent); outline-offset: 3px; }
      #present-dot { position: absolute; width: 14px; height: 14px; border-radius: 50%; background: var(--accent); transform: translate(-50%, -50%); pointer-events: none; }
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
        overscroll-behavior: contain;
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
      .support-icons a:active { background: var(--pressed); }
      @media (hover: hover) { .support-icons a:hover { background: var(--pressed); } }
      .support-icons a:focus-visible, .help-disclosure summary:focus-visible { outline: 3px solid var(--accent); outline-offset: 2px; }
      .help-disclosure { margin: 12px 0; }
      .help-disclosure summary { cursor: pointer; min-height: 44px; padding: 12px 0; }
      @media (max-width: 380px) { .support-icons { grid-template-columns: repeat(3, minmax(44px, 1fr)); } }
    </style>
  </head>
  <body>
    <svg class="icon-definitions" aria-hidden="true" focusable="false" xmlns="http://www.w3.org/2000/svg">
      <symbol id="icon-mute" viewBox="0 0 24 24"><g fill="currentColor" stroke="none"><path d="M13.5 4.06c0-1.336-1.616-2.005-2.56-1.06l-4.5 4.5H4.508c-1.141 0-2.318.664-2.66 1.905A9.76 9.76 0 0 0 1.5 12c0 .898.121 1.768.35 2.595.341 1.24 1.518 1.905 2.659 1.905h1.93l4.5 4.5c.945.945 2.561.276 2.561-1.06V4.06ZM17.78 9.22a.75.75 0 1 0-1.06 1.06L18.44 12l-1.72 1.72a.75.75 0 1 0 1.06 1.06l1.72-1.72 1.72 1.72a.75.75 0 1 0 1.06-1.06L20.56 12l1.72-1.72a.75.75 0 1 0-1.06-1.06l-1.72 1.72-1.72-1.72Z" />
</g></symbol>
      <symbol id="icon-shortcuts" viewBox="0 0 24 24"><g fill="currentColor" stroke="none"><path fill-rule="evenodd" d="M3 6a3 3 0 0 1 3-3h2.25a3 3 0 0 1 3 3v2.25a3 3 0 0 1-3 3H6a3 3 0 0 1-3-3V6Zm9.75 0a3 3 0 0 1 3-3H18a3 3 0 0 1 3 3v2.25a3 3 0 0 1-3 3h-2.25a3 3 0 0 1-3-3V6ZM3 15.75a3 3 0 0 1 3-3h2.25a3 3 0 0 1 3 3V18a3 3 0 0 1-3 3H6a3 3 0 0 1-3-3v-2.25Zm9.75 0a3 3 0 0 1 3-3H18a3 3 0 0 1 3 3V18a3 3 0 0 1-3 3h-2.25a3 3 0 0 1-3-3v-2.25Z" clip-rule="evenodd" />
</g></symbol>
      <symbol id="icon-settings" viewBox="0 0 24 24"><g fill="currentColor" stroke="none"><path fill-rule="evenodd" d="M11.078 2.25c-.917 0-1.699.663-1.85 1.567L9.05 4.889c-.02.12-.115.26-.297.348a7.493 7.493 0 0 0-.986.57c-.166.115-.334.126-.45.083L6.3 5.508a1.875 1.875 0 0 0-2.282.819l-.922 1.597a1.875 1.875 0 0 0 .432 2.385l.84.692c.095.078.17.229.154.43a7.598 7.598 0 0 0 0 1.139c.015.2-.059.352-.153.43l-.841.692a1.875 1.875 0 0 0-.432 2.385l.922 1.597a1.875 1.875 0 0 0 2.282.818l1.019-.382c.115-.043.283-.031.45.082.312.214.641.405.985.57.182.088.277.228.297.35l.178 1.071c.151.904.933 1.567 1.85 1.567h1.844c.916 0 1.699-.663 1.85-1.567l.178-1.072c.02-.12.114-.26.297-.349.344-.165.673-.356.985-.57.167-.114.335-.125.45-.082l1.02.382a1.875 1.875 0 0 0 2.28-.819l.923-1.597a1.875 1.875 0 0 0-.432-2.385l-.84-.692c-.095-.078-.17-.229-.154-.43a7.614 7.614 0 0 0 0-1.139c-.016-.2.059-.352.153-.43l.84-.692c.708-.582.891-1.59.433-2.385l-.922-1.597a1.875 1.875 0 0 0-2.282-.818l-1.02.382c-.114.043-.282.031-.449-.083a7.49 7.49 0 0 0-.985-.57c-.183-.087-.277-.227-.297-.348l-.179-1.072a1.875 1.875 0 0 0-1.85-1.567h-1.843ZM12 15.75a3.75 3.75 0 1 0 0-7.5 3.75 3.75 0 0 0 0 7.5Z" clip-rule="evenodd" />
</g></symbol>
      <symbol id="icon-right-click" viewBox="0 0 24 24"><rect x="6" y="2" width="12" height="20" rx="6"/><path d="M12 2v8h6m-6 0H6"/><path d="M13 4h2l1 2v2h-3Z" fill="currentColor" stroke="none"/></symbol>
      <symbol id="icon-double-click" viewBox="0 0 24 24"><g fill="currentColor" stroke="none"><path fill-rule="evenodd" d="M12 1.5a.75.75 0 0 1 .75.75V4.5a.75.75 0 0 1-1.5 0V2.25A.75.75 0 0 1 12 1.5ZM5.636 4.136a.75.75 0 0 1 1.06 0l1.592 1.591a.75.75 0 0 1-1.061 1.06l-1.591-1.59a.75.75 0 0 1 0-1.061Zm12.728 0a.75.75 0 0 1 0 1.06l-1.591 1.592a.75.75 0 0 1-1.06-1.061l1.59-1.591a.75.75 0 0 1 1.061 0Zm-6.816 4.496a.75.75 0 0 1 .82.311l5.228 7.917a.75.75 0 0 1-.777 1.148l-2.097-.43 1.045 3.9a.75.75 0 0 1-1.45.388l-1.044-3.899-1.601 1.42a.75.75 0 0 1-1.247-.606l.569-9.47a.75.75 0 0 1 .554-.68ZM3 10.5a.75.75 0 0 1 .75-.75H6a.75.75 0 0 1 0 1.5H3.75A.75.75 0 0 1 3 10.5Zm14.25 0a.75.75 0 0 1 .75-.75h2.25a.75.75 0 0 1 0 1.5H18a.75.75 0 0 1-.75-.75Zm-8.962 3.712a.75.75 0 0 1 0 1.061l-1.591 1.591a.75.75 0 1 1-1.061-1.06l1.591-1.592a.75.75 0 0 1 1.06 0Z" clip-rule="evenodd" />
</g></symbol>
      <symbol id="icon-drag" viewBox="0 0 24 24"><g fill="currentColor" stroke="none"><path d="M10.5 1.875a1.125 1.125 0 0 1 2.25 0v8.219c.517.162 1.02.382 1.5.659V3.375a1.125 1.125 0 0 1 2.25 0v10.937a4.505 4.505 0 0 0-3.25 2.373 8.963 8.963 0 0 1 4-.935A.75.75 0 0 0 18 15v-2.266a3.368 3.368 0 0 1 .988-2.37 1.125 1.125 0 0 1 1.591 1.59 1.118 1.118 0 0 0-.329.79v3.006h-.005a6 6 0 0 1-1.752 4.007l-1.736 1.736a6 6 0 0 1-4.242 1.757H10.5a7.5 7.5 0 0 1-7.5-7.5V6.375a1.125 1.125 0 0 1 2.25 0v5.519c.46-.452.965-.832 1.5-1.141V3.375a1.125 1.125 0 0 1 2.25 0v6.526c.495-.1.997-.151 1.5-.151V1.875Z" />
</g></symbol>
      <symbol id="icon-previous" viewBox="0 0 24 24"><g fill="currentColor" stroke="none"><path d="M9.195 18.44c1.25.714 2.805-.189 2.805-1.629v-2.34l6.945 3.968c1.25.715 2.805-.188 2.805-1.628V8.69c0-1.44-1.555-2.343-2.805-1.628L12 11.029v-2.34c0-1.44-1.555-2.343-2.805-1.628l-7.108 4.061c-1.26.72-1.26 2.536 0 3.256l7.108 4.061Z" />
</g></symbol>
      <symbol id="icon-play-pause" viewBox="0 0 24 24"><g fill="currentColor" stroke="none"><path d="M15 6.75a.75.75 0 0 0-.75.75V18a.75.75 0 0 0 .75.75h.75a.75.75 0 0 0 .75-.75V7.5a.75.75 0 0 0-.75-.75H15ZM20.25 6.75a.75.75 0 0 0-.75.75V18c0 .414.336.75.75.75H21a.75.75 0 0 0 .75-.75V7.5a.75.75 0 0 0-.75-.75h-.75ZM5.055 7.06C3.805 6.347 2.25 7.25 2.25 8.69v8.122c0 1.44 1.555 2.343 2.805 1.628l7.108-4.061c1.26-.72 1.26-2.536 0-3.256L5.055 7.061Z" />
</g></symbol>
      <symbol id="icon-next" viewBox="0 0 24 24"><g fill="currentColor" stroke="none"><path d="M5.055 7.06C3.805 6.347 2.25 7.25 2.25 8.69v8.122c0 1.44 1.555 2.343 2.805 1.628L12 14.471v2.34c0 1.44 1.555 2.343 2.805 1.628l7.108-4.061c1.26-.72 1.26-2.536 0-3.256l-7.108-4.061C13.555 6.346 12 7.249 12 8.689v2.34L5.055 7.061Z" />
</g></symbol>
      <symbol id="icon-volume-down" viewBox="0 0 24 24"><path d="m11 5-5 4H3v6h3l5 4V5m5 7h6"/></symbol>
      <symbol id="icon-volume-up" viewBox="0 0 24 24"><path d="m11 5-5 4H3v6h3l5 4V5m5 7h6m-3-3v6"/></symbol>
      <symbol id="icon-keyboard" viewBox="0 0 24 24"><rect x="2" y="5" width="20" height="14" rx="2"/><path d="M6 9h.01M10 9h.01M14 9h.01M18 9h.01M6 12h.01M10 12h.01M14 12h.01M18 12h.01M7 16h10"/></symbol>
      <symbol id="icon-apps" viewBox="0 0 24 24"><rect x="2" y="6" width="15" height="15" rx="2"/><path d="M7 6V3h15v15h-5M2 11h15"/></symbol>
      <symbol id="icon-fullscreen" viewBox="0 0 24 24"><path d="M8 3H3v5m13-5h5v5M3 16v5h5m13-5v5h-5"/></symbol>
      <symbol id="icon-search" viewBox="0 0 24 24"><circle cx="10" cy="10" r="7"/><path d="m15 15 6 6"/></symbol>
      <symbol id="icon-desktop" viewBox="0 0 24 24"><g fill="currentColor" stroke="none"><path fill-rule="evenodd" d="M2.25 5.25a3 3 0 0 1 3-3h13.5a3 3 0 0 1 3 3V15a3 3 0 0 1-3 3h-3v.257c0 .597.237 1.17.659 1.591l.621.622a.75.75 0 0 1-.53 1.28h-9a.75.75 0 0 1-.53-1.28l.621-.622a2.25 2.25 0 0 0 .659-1.59V18h-3a3 3 0 0 1-3-3V5.25Zm1.5 0v7.5a1.5 1.5 0 0 0 1.5 1.5h13.5a1.5 1.5 0 0 0 1.5-1.5v-7.5a1.5 1.5 0 0 0-1.5-1.5H5.25a1.5 1.5 0 0 0-1.5 1.5Z" clip-rule="evenodd" />
</g></symbol>
      <symbol id="icon-folder" viewBox="0 0 24 24"><g fill="currentColor" stroke="none"><path d="M19.5 21a3 3 0 0 0 3-3v-4.5a3 3 0 0 0-3-3h-15a3 3 0 0 0-3 3V18a3 3 0 0 0 3 3h15ZM1.5 10.146V6a3 3 0 0 1 3-3h5.379a2.25 2.25 0 0 1 1.59.659l2.122 2.121c.14.141.331.22.53.22H19.5a3 3 0 0 1 3 3v1.146A4.483 4.483 0 0 0 19.5 9h-15a4.483 4.483 0 0 0-3 1.146Z" />
</g></symbol>
      <symbol id="icon-screen-off" viewBox="0 0 24 24"><path d="M2 3h20v14H2Zm6 18h8m-4-4v4m-6-9 12-6"/></symbol>
      <symbol id="icon-wake" viewBox="0 0 24 24"><path d="M12 2v8m-5-6a9 9 0 1 0 10 0"/></symbol>
      <symbol id="icon-lock" viewBox="0 0 24 24"><g fill="currentColor" stroke="none"><path fill-rule="evenodd" d="M12 1.5a5.25 5.25 0 0 0-5.25 5.25v3a3 3 0 0 0-3 3v6.75a3 3 0 0 0 3 3h10.5a3 3 0 0 0 3-3v-6.75a3 3 0 0 0-3-3v-3c0-2.9-2.35-5.25-5.25-5.25Zm3.75 8.25v-3a3.75 3.75 0 1 0-7.5 0v3h7.5Z" clip-rule="evenodd" />
</g></symbol>
      <symbol id="icon-help" viewBox="0 0 24 24"><g fill="currentColor" stroke="none"><path fill-rule="evenodd" d="M2.25 12c0-5.385 4.365-9.75 9.75-9.75s9.75 4.365 9.75 9.75-4.365 9.75-9.75 9.75S2.25 17.385 2.25 12Zm11.378-3.917c-.89-.777-2.366-.777-3.255 0a.75.75 0 0 1-.988-1.129c1.454-1.272 3.776-1.272 5.23 0 1.513 1.324 1.513 3.518 0 4.842a3.75 3.75 0 0 1-.837.552c-.676.328-1.028.774-1.028 1.152v.75a.75.75 0 0 1-1.5 0v-.75c0-1.279 1.06-2.107 1.875-2.502.182-.088.351-.199.503-.331.83-.727.83-1.857 0-2.584ZM12 18a.75.75 0 1 0 0-1.5.75.75 0 0 0 0 1.5Z" clip-rule="evenodd" />
</g></symbol>
      <symbol id="icon-copy" viewBox="0 0 24 24"><g fill="currentColor" stroke="none"><path d="M7.5 3.375c0-1.036.84-1.875 1.875-1.875h.375a3.75 3.75 0 0 1 3.75 3.75v1.875C13.5 8.161 14.34 9 15.375 9h1.875A3.75 3.75 0 0 1 21 12.75v3.375C21 17.16 20.16 18 19.125 18h-9.75A1.875 1.875 0 0 1 7.5 16.125V3.375Z" />
  <path d="M15 5.25a5.23 5.23 0 0 0-1.279-3.434 9.768 9.768 0 0 1 6.963 6.963A5.23 5.23 0 0 0 17.25 7.5h-1.875A.375.375 0 0 1 15 7.125V5.25ZM4.875 6H6v10.125A3.375 3.375 0 0 0 9.375 19.5H16.5v1.125c0 1.035-.84 1.875-1.875 1.875h-9.75A1.875 1.875 0 0 1 3 20.625V7.875C3 6.839 3.84 6 4.875 6Z" />
</g></symbol>
      <symbol id="icon-bug" viewBox="0 0 24 24"><g fill="currentColor" stroke="none"><path fill-rule="evenodd" d="M8.478 1.6a.75.75 0 0 1 .273 1.026 3.72 3.72 0 0 0-.425 1.121c.058.058.118.114.18.168A4.491 4.491 0 0 1 12 2.25c1.413 0 2.673.651 3.497 1.668.06-.054.12-.11.178-.167a3.717 3.717 0 0 0-.426-1.125.75.75 0 1 1 1.298-.752 5.22 5.22 0 0 1 .671 2.046.75.75 0 0 1-.187.582c-.241.27-.505.52-.787.749a4.494 4.494 0 0 1 .216 2.1c-.106.792-.753 1.295-1.417 1.403-.182.03-.364.057-.547.081.152.227.273.476.359.742a23.122 23.122 0 0 0 3.832-.803 23.241 23.241 0 0 0-.345-2.634.75.75 0 0 1 1.474-.28c.21 1.115.348 2.256.404 3.418a.75.75 0 0 1-.516.75c-1.527.499-3.119.854-4.76 1.049-.074.38-.22.735-.423 1.05 2.066.209 4.058.672 5.943 1.358a.75.75 0 0 1 .492.75 24.665 24.665 0 0 1-1.189 6.25.75.75 0 0 1-1.425-.47 23.14 23.14 0 0 0 1.077-5.306c-.5-.169-1.009-.32-1.524-.455.068.234.104.484.104.746 0 3.956-2.521 7.5-6 7.5-3.478 0-6-3.544-6-7.5 0-.262.037-.511.104-.746-.514.135-1.022.286-1.522.455.154 1.838.52 3.616 1.077 5.307a.75.75 0 1 1-1.425.468 24.662 24.662 0 0 1-1.19-6.25.75.75 0 0 1 .493-.749 24.586 24.586 0 0 1 4.964-1.24h.01c.321-.046.644-.085.969-.118a2.983 2.983 0 0 1-.424-1.05 24.614 24.614 0 0 1-4.76-1.05.75.75 0 0 1-.516-.75c.057-1.16.194-2.302.405-3.417a.75.75 0 0 1 1.474.28c-.164.862-.28 1.74-.345 2.634 1.237.371 2.517.642 3.832.803.085-.266.207-.515.359-.742a18.698 18.698 0 0 1-.547-.08c-.664-.11-1.311-.612-1.417-1.404a4.535 4.535 0 0 1 .217-2.103 6.788 6.788 0 0 1-.788-.751.75.75 0 0 1-.187-.583 5.22 5.22 0 0 1 .67-2.04.75.75 0 0 1 1.026-.273Z" clip-rule="evenodd" />
</g></symbol>
      <symbol id="icon-idea" viewBox="0 0 24 24"><g fill="currentColor" stroke="none"><path d="M12 .75a8.25 8.25 0 0 0-4.135 15.39c.686.398 1.115 1.008 1.134 1.623a.75.75 0 0 0 .577.706c.352.083.71.148 1.074.195.323.041.6-.218.6-.544v-4.661a6.714 6.714 0 0 1-.937-.171.75.75 0 1 1 .374-1.453 5.261 5.261 0 0 0 2.626 0 .75.75 0 1 1 .374 1.452 6.712 6.712 0 0 1-.937.172v4.66c0 .327.277.586.6.545.364-.047.722-.112 1.074-.195a.75.75 0 0 0 .577-.706c.02-.615.448-1.225 1.134-1.623A8.25 8.25 0 0 0 12 .75Z" />
  <path fill-rule="evenodd" d="M9.013 19.9a.75.75 0 0 1 .877-.597 11.319 11.319 0 0 0 4.22 0 .75.75 0 1 1 .28 1.473 12.819 12.819 0 0 1-4.78 0 .75.75 0 0 1-.597-.876ZM9.754 22.344a.75.75 0 0 1 .824-.668 13.682 13.682 0 0 0 2.844 0 .75.75 0 1 1 .156 1.492 15.156 15.156 0 0 1-3.156 0 .75.75 0 0 1-.668-.824Z" clip-rule="evenodd" />
</g></symbol>
      <symbol id="icon-chat" viewBox="0 0 24 24"><g fill="currentColor" stroke="none"><path d="M4.913 2.658c2.075-.27 4.19-.408 6.337-.408 2.147 0 4.262.139 6.337.408 1.922.25 3.291 1.861 3.405 3.727a4.403 4.403 0 0 0-1.032-.211 50.89 50.89 0 0 0-8.42 0c-2.358.196-4.04 2.19-4.04 4.434v4.286a4.47 4.47 0 0 0 2.433 3.984L7.28 21.53A.75.75 0 0 1 6 21v-4.03a48.527 48.527 0 0 1-1.087-.128C2.905 16.58 1.5 14.833 1.5 12.862V6.638c0-1.97 1.405-3.718 3.413-3.979Z" />
  <path d="M15.75 7.5c-1.376 0-2.739.057-4.086.169C10.124 7.797 9 9.103 9 10.609v4.285c0 1.507 1.128 2.814 2.67 2.94 1.243.102 2.5.157 3.768.165l2.782 2.781a.75.75 0 0 0 1.28-.53v-2.39l.33-.026c1.542-.125 2.67-1.433 2.67-2.94v-4.286c0-1.505-1.125-2.811-2.664-2.94A49.392 49.392 0 0 0 15.75 7.5Z" />
</g></symbol>
      <symbol id="icon-globe" viewBox="0 0 24 24"><g fill="currentColor" stroke="none"><path d="M21.721 12.752a9.711 9.711 0 0 0-.945-5.003 12.754 12.754 0 0 1-4.339 2.708 18.991 18.991 0 0 1-.214 4.772 17.165 17.165 0 0 0 5.498-2.477ZM14.634 15.55a17.324 17.324 0 0 0 .332-4.647c-.952.227-1.945.347-2.966.347-1.021 0-2.014-.12-2.966-.347a17.515 17.515 0 0 0 .332 4.647 17.385 17.385 0 0 0 5.268 0ZM9.772 17.119a18.963 18.963 0 0 0 4.456 0A17.182 17.182 0 0 1 12 21.724a17.18 17.18 0 0 1-2.228-4.605ZM7.777 15.23a18.87 18.87 0 0 1-.214-4.774 12.753 12.753 0 0 1-4.34-2.708 9.711 9.711 0 0 0-.944 5.004 17.165 17.165 0 0 0 5.498 2.477ZM21.356 14.752a9.765 9.765 0 0 1-7.478 6.817 18.64 18.64 0 0 0 1.988-4.718 18.627 18.627 0 0 0 5.49-2.098ZM2.644 14.752c1.682.971 3.53 1.688 5.49 2.099a18.64 18.64 0 0 0 1.988 4.718 9.765 9.765 0 0 1-7.478-6.816ZM13.878 2.43a9.755 9.755 0 0 1 6.116 3.986 11.267 11.267 0 0 1-3.746 2.504 18.63 18.63 0 0 0-2.37-6.49ZM12 2.276a17.152 17.152 0 0 1 2.805 7.121c-.897.23-1.837.353-2.805.353-.968 0-1.908-.122-2.805-.353A17.151 17.151 0 0 1 12 2.276ZM10.122 2.43a18.629 18.629 0 0 0-2.37 6.49 11.266 11.266 0 0 1-3.746-2.504 9.754 9.754 0 0 1 6.116-3.985Z" />
</g></symbol>
      <symbol id="icon-heart" viewBox="0 0 24 24"><g fill="currentColor" stroke="none"><path d="m11.645 20.91-.007-.003-.022-.012a15.247 15.247 0 0 1-.383-.218 25.18 25.18 0 0 1-4.244-3.17C4.688 15.36 2.25 12.174 2.25 8.25 2.25 5.322 4.714 3 7.688 3A5.5 5.5 0 0 1 12 5.052 5.5 5.5 0 0 1 16.313 3c2.973 0 5.437 2.322 5.437 5.25 0 3.925-2.438 7.111-4.739 9.256a25.175 25.175 0 0 1-4.244 3.17 15.247 15.247 0 0 1-.383.219l-.022.012-.007.004-.003.001a.752.752 0 0 1-.704 0l-.003-.001Z" />
</g></symbol>
      <symbol id="icon-updates" viewBox="0 0 24 24"><g fill="currentColor" stroke="none"><path fill-rule="evenodd" d="M12 2.25c-5.385 0-9.75 4.365-9.75 9.75s4.365 9.75 9.75 9.75 9.75-4.365 9.75-9.75S17.385 2.25 12 2.25Zm-.53 14.03a.75.75 0 0 0 1.06 0l3-3a.75.75 0 1 0-1.06-1.06l-1.72 1.72V8.25a.75.75 0 0 0-1.5 0v5.69l-1.72-1.72a.75.75 0 0 0-1.06 1.06l3 3Z" clip-rule="evenodd" />
</g></symbol>
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
      <button id="present-open" class="present-open" data-icon="fullscreen" title="Slideshow controls">Present</button>
      <div id="status" class="status" role="status" aria-live="polite"></div>
      <aside id="connection-help" hidden aria-label="Reconnect to your Mac">
        <p>Keep your Mac awake and Sofa Remote sharing. Check that both devices are on the same Wi-Fi or Tailscale network. If the Mac's address changed, open Sofa Remote on the Mac and scan its new QR code.</p>
        <div class="sheet-row"><button id="reconnect">Try reconnecting</button><button data-help data-icon="help" title="About and Help">About &amp; Help</button></div>
      </aside>
    </main>
    <div class="scrim" id="present-sheet">
      <div class="sheet" role="dialog" aria-modal="true" aria-label="Presenter controls">
        <div class="sheet-head"><h2>Present</h2><button data-close>Done</button></div>
        <p>Start your slideshow on the Mac. Previous and Next send arrow keys to the active app.</p>
        <div class="present-nav"><button id="present-previous" aria-label="Previous slide">← Previous</button><button id="present-next" aria-label="Next slide">Next →</button></div>
        <div class="present-tools"><button id="present-exit">End slideshow</button></div>
        <label for="present-display">Presentation display</label><select class="field" id="present-display" aria-label="Presentation display"></select>
        <p>Choose the screen showing your slides. Changing display clears marks.</p>
        <div class="present-tools" role="group" aria-label="Pointer and annotation tools">
          <button id="present-laser" aria-pressed="true">Laser</button><button id="present-pen" aria-pressed="false">Pen</button>
          <button id="present-undo">Undo</button><button id="present-clear">Clear</button>
        </div>
        <div id="present-pad" role="application" tabindex="0" aria-label="Presentation pointer. Touch and move to point or draw. Keyboard: move with arrow keys, hold Space to point or draw."><span>Touch and move to point or draw</span><span id="present-dot" hidden aria-hidden="true"></span></div>
        <p>This is a control surface, not a slide preview. Marks are temporary and are not saved to your slides. They clear on Previous or Next, when you leave Present, or after 30 seconds without a connection. They may not appear when sharing a single app window.</p>
      </div>
    </div>
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
          <label for="theme">Appearance<select class="field" id="theme"><option value="dark">Dark</option><option value="black">Black</option><option value="light">Light</option><option value="ivory">Ivory · brown</option><option value="plum">Ivory · plum</option><option value="ocean">Ocean</option><option value="custom">Custom</option></select></label>
          <label for="custom-colour">Custom background colour<input class="field" type="color" id="custom-colour" value="#1f1f1f" disabled /></label>
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
          <a data-icon="globe" href="https://sofa-remote.doublehoney1.chatgpt.site/" target="_blank" rel="noopener noreferrer" aria-label="Project website" title="Project website"></a>
          <a data-icon="heart" href="https://sofa-remote.doublehoney1.chatgpt.site/#support" target="_blank" rel="noopener noreferrer" aria-label="Support this project" title="Support this project"></a>
          <a data-icon="updates" href="https://github.com/allamaprabhuani/sofa-remote/releases" target="_blank" rel="noopener noreferrer" aria-label="Check for updates and release notes" title="Check for updates and release notes"></a>
        </nav>
        <details class="help-disclosure"><summary>Setup and connection help</summary>
        <p id="signing-help">Signing: Unknown. Signing type alone does not verify Developer ID or notarisation.</p>
        <p>Allow Accessibility in the Mac app, show its pairing code and scan the QR with your phone Camera. In Safari, use Share → Add to Home Screen. For connection or permission problems, follow the setup guide below.</p>
          <nav class="help-links" aria-label="Setup links">
            <a href="https://github.com/allamaprabhuani/sofa-remote/blob/main/docs/SETUP.md" target="_blank" rel="noopener noreferrer">Setup guide</a>
            <a href="https://github.com/allamaprabhuani/sofa-remote/blob/main/SUPPORT.md" target="_blank" rel="noopener noreferrer">Troubleshooting</a>
            <a href="https://github.com/allamaprabhuani/sofa-remote/blob/main/docs/SIGNING.md" target="_blank" rel="noopener noreferrer">Signing and permission updates</a>
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
        <p>Preview before copying. Only app, macOS and browser versions, signing type and permission/sharing status are included. No typed text, tokens, personal URLs, screenshots, Mac names or network addresses. Nothing is uploaded automatically.</p>
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
      // Neutral surfaces inspired by VS Code's built-in modern themes.
      // Stronger control borders keep the phone touch targets distinguishable.
      const themes = {
        dark: { bg: "#1f1f1f", card: "#292929", pad: "#181818", sheet: "#1f1f1f", line: "#777777", muted: "#b8b8b8", accent: "#a9cdf5", ink: "#ededed", pressed: "#383838", selection: "#ededed", "selection-ink": "#1f1f1f", danger: "#ffb4ab", error: "#ffb4ab" },
        black: { bg: "#000000", card: "#000000", pad: "#000000", sheet: "#000000", line: "#737373", muted: "#bdbdbd", accent: "#c7dcf5", ink: "#f5f5f5", pressed: "#222222", selection: "#f5f5f5", "selection-ink": "#000000", danger: "#ffb4ab", error: "#ffb4ab" },
        ivory: { bg: "#f6f1e7", card: "#fffaf0", pad: "#eee7da", sheet: "#fffaf0", line: "#99836c", muted: "#645141", accent: "#754726", ink: "#35261c", pressed: "#e4d8c7", selection: "#754726", "selection-ink": "#fffaf0", danger: "#962e2e", error: "#962e2e" },
        plum: { bg: "#f8f2ed", card: "#fff9f5", pad: "#efe4ec", sheet: "#fff9f5", line: "#9b7f99", muted: "#685369", accent: "#704381", ink: "#38233c", pressed: "#e7d9e5", selection: "#704381", "selection-ink": "#fff9f5", danger: "#952d49", error: "#952d49" },
        ocean: { bg: "#062d35", card: "#103c45", pad: "#0b343d", sheet: "#0b343d", line: "#75949a", muted: "#bcd8dd", accent: "#a1e9ee", ink: "#f4ffff", pressed: "#244e57", selection: "#c5f4f5", "selection-ink": "#062d35", danger: "#ffb8b8", error: "#ffb8b8" },
        light: { bg: "#f8f8f8", card: "#ffffff", pad: "#f0f0f0", sheet: "#ffffff", line: "#767676", muted: "#555555", accent: "#005fb8", ink: "#242424", pressed: "#e5e5e5", selection: "#242424", "selection-ink": "#ffffff", danger: "#9d1e2c", error: "#a51627" },
      };
      const safeColour = (v) => typeof v === "string" && /^#[0-9a-f]{6}$/i.test(v) ? v.toLowerCase() : "#1f1f1f";
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
      let themeState = { name: "dark", colour: "#1f1f1f" };
      function applyTheme(name, colour) {
        const requested = ({ oxford: "dark", imperial: "dark" })[name] || name;
        const known = ["dark", "black", "light", "ivory", "plum", "ocean", "custom"].includes(requested) ? requested : "dark";
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
      catch { applyTheme("dark", "#1f1f1f"); }
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
      function signingLabel(value) {
        switch (value) {
          case "ad-hoc": return "Ad hoc";
          case "certificate-signed": return "Certificate-signed";
          case "unsigned": return "Unsigned";
          default: return "Unknown";
        }
      }
      function diagnosticSummary() {
        const state = supportState || {};
        const yesNo = (v) => v === true ? "Yes" : v === false ? "No" : "Unavailable";
        const inputStatus = (() => {
          if (state.accessibility === false) return "blocked (Accessibility not allowed)";
          if (state.sharing === false) return "stopped (Sharing off)";
          if (state.sessionLocked === true) return "paused";
          if (state.accessibility === true && state.sharing === true) return "ready";
          return "Unavailable";
        })();
        return [
          "Sofa Remote diagnostic summary",
          `App version: ${safeVersion(state.appVersion)}`,
          `Build: ${safeVersion(state.appBuild)}`,
          `macOS: ${safeVersion(state.macOSVersion)}`,
          `Browser: ${browserVersion()}`,
          `Signing: ${signingLabel(state.signingStatus)}`,
          `Accessibility allowed: ${yesNo(state.accessibility)}`,
          `Sharing enabled: ${yesNo(state.sharing)}`,
          `Input paused: ${yesNo(state.sessionLocked)}`,
          `Input: ${inputStatus}`,
          supportState ? "Mac status is from the last successful connection." : "Connect to the Mac to include its version and status.",
        ].join("\n");
      }
      function updateSupport() {
        const version = safeVersion(supportState?.appVersion), build = safeVersion(supportState?.appBuild);
        $("#app-version").textContent = supportState
          ? `Sofa Remote ${version} · build ${build}`
          : "Sofa Remote · connect to see the Mac app version";
        const signing = signingLabel(supportState?.signingStatus);
        $("#signing-help").textContent = (signing === "Ad hoc" || signing === "Unsigned")
          ? `Signing: ${signing}. This build has no stable signing identity; updates may require Accessibility permission again. Stable signing is needed for permission continuity.`
          : `Signing: ${signing}. Signing type alone does not verify Developer ID, notarisation or permission continuity.`;
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
        if (sheet.parentElement?.id === "present-sheet") sheet.querySelector(".sheet-head").after(note);
        else sheet.append(note);
      });
      function showPair() {
        stopPresenting();
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
          (body.type === "drag" && body.phase === "move") ||
          (body.type === "presenter" && body.action === "move")
        );
      }
      function discardQueuedInput() {
        const release = drag || queue.some((item) => item.body.type === "drag");
        while (queue.length) queue.shift().done(false);
        clearTimeout(gestureTimer);
        gestureTimer = 0;
        if (presentUsed) stopPresenting();
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
        if (motion && body.type === "presenter") {
          queue.shift();
          outbound = body;
          lastGesture = Date.now();
        } else if (motion) {
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
        request(body.type === "presenter" ? "/presenter" : "/command", outbound, true, controller.signal)
          .then(
            () => {
              if (body.type === "presenter" && !["heartbeat", "stop"].includes(body.action) && statusKind === "presenter") status("");
              else clearRuntimeError();
              return true;
            },
            (e) => {
              if (e.message !== "unpaired" && e.message !== "cancelled") status(e.message, true, body.type === "presenter" ? "presenter" : "runtime");
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
            if (body.type === "presenter") {
              // Absolute points are coalesced to the latest position under load.
              last.body.x = body.x; last.body.y = body.y;
              last.queuedAt = Date.now();
              resolve(true);
              return;
            }
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
          if (body.type === "presenter" && body.action === "stop") {
            // Always make room for cleanup without overtaking the in-flight request.
            while (queue.length >= 12) queue.pop().done(false);
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
        if (current?.id === "present-sheet") {
          stopPresenting();
          if (statusKind === "presenter") status("");
        }
        $$(".scrim").forEach((x) => x.classList.remove("open"));
        const previous = sheetStack.at(-1);
        if (previous && (!locked || previous.id === "help-sheet")) $("#" + previous.id).classList.add("open");
        else if (locked) sheetStack.length = 0;
        updateLayers();
        if (current?.opener?.isConnected && current.opener.getClientRects().length && !current.opener.closest("[inert]")) current.opener.focus();
        else if (activeOverlay()) activeOverlay().querySelector("button,input,a")?.focus();
        else $("#settings-open").focus();
      }
      let presentMode = "laser", presentPointer = null, presentUsed = false, presentKeyboardDown = false, presentHeartbeat = 0;
      let presentX = 0.5, presentY = 0.5;
      const presentPad = $("#present-pad"), presentDot = $("#present-dot"), presentDisplay = $("#present-display");
      function presenter(action, values = {}, urgent = false) {
        return command({ type: "presenter", action, ...values }, urgent);
      }
      function stopPresenting() {
        presentPointer = null; presentKeyboardDown = false; presentDot.hidden = true;
        clearInterval(presentHeartbeat); presentHeartbeat = 0;
        if (presentUsed) {
          presentUsed = false;
          dropQueuedMotion();
          // Preserve ordering with any in-flight start. An abort could let that start
          // arrive after stop; the Mac also expires disconnected overlays.
          presenter("stop");
        }
      }
      function markPosition(x, y) {
        presentX = Math.max(0, Math.min(1, x)); presentY = Math.max(0, Math.min(1, y));
        presentDot.style.left = `${presentX * 100}%`; presentDot.style.top = `${presentY * 100}%`;
        presentDot.hidden = false;
      }
      function pointFromEvent(e) {
        const r = presentPad.getBoundingClientRect();
        if (!r.width || !r.height) return false;
        markPosition((e.clientX - r.left) / r.width, (e.clientY - r.top) / r.height);
        return true;
      }
      function startPresentPoint() {
        if (!presentDisplay.value || locked || !key) { status("Choose a connected presentation display.", true); return; }
        presentUsed = true;
        if (!presentHeartbeat) presentHeartbeat = setInterval(() => {
          if (presentUsed && !document.hidden && $("#present-sheet").classList.contains("open")) presenter("heartbeat");
        }, 10000);
        presenter("start", { mode: presentMode, display: presentDisplay.value, x: presentX, y: presentY });
      }
      function endPresentPoint() { if (presentUsed) presenter("end"); }
      presentPad.addEventListener("pointerdown", (e) => {
        if (presentPointer !== null || e.button !== 0 || locked || !key || !pointFromEvent(e)) return;
        e.preventDefault(); presentPointer = e.pointerId; presentPad.setPointerCapture(e.pointerId); startPresentPoint();
      });
      presentPad.addEventListener("pointermove", (e) => {
        if (presentPointer !== e.pointerId || !pointFromEvent(e)) return;
        e.preventDefault(); if (presentUsed) presenter("move", { x: presentX, y: presentY });
      });
      function liftPresentPoint(e) {
        if (presentPointer !== e.pointerId) return;
        presentPointer = null; endPresentPoint();
        if (presentMode === "laser") presentDot.hidden = true;
      }
      presentPad.addEventListener("pointerup", liftPresentPoint);
      presentPad.addEventListener("pointercancel", liftPresentPoint);
      presentPad.addEventListener("lostpointercapture", liftPresentPoint);
      presentPad.addEventListener("keydown", (e) => {
        if (locked || !key || e.altKey || e.ctrlKey || e.metaKey) return;
        const movement = { ArrowLeft: [-0.02, 0], ArrowRight: [0.02, 0], ArrowUp: [0, -0.02], ArrowDown: [0, 0.02] }[e.key];
        if (movement) {
          e.preventDefault(); markPosition(presentX + movement[0], presentY + movement[1]);
          if (presentKeyboardDown && presentUsed) presenter("move", { x: presentX, y: presentY });
        } else if (e.key === " " && !e.repeat && !presentKeyboardDown) {
          e.preventDefault(); presentKeyboardDown = true; markPosition(presentX, presentY); startPresentPoint();
        }
      });
      presentPad.addEventListener("keyup", (e) => {
        if (e.key === " " && presentKeyboardDown) { e.preventDefault(); presentKeyboardDown = false; endPresentPoint(); if (presentMode === "laser") presentDot.hidden = true; }
      });
      presentPad.addEventListener("blur", () => { if (presentKeyboardDown) { presentKeyboardDown = false; endPresentPoint(); } });
      for (const mode of ["laser", "pen"]) $("#present-" + mode).onclick = () => {
        if (presentPointer !== null || presentKeyboardDown) return;
        presentMode = mode;
        for (const item of ["laser", "pen"]) $("#present-" + item).setAttribute("aria-pressed", String(item === mode));
      };
      presentDisplay.onchange = () => stopPresenting();
      function presentMarks(action) {
        if (!presentUsed) return;
        presentPointer = null; presentKeyboardDown = false; presentDot.hidden = true;
        dropQueuedMotion();
        presenter(action);
      }
      $("#present-undo").onclick = () => presentMarks("undo");
      $("#present-clear").onclick = () => presentMarks("clear");
      function presentSlide(key) {
        presentMarks("clear");
        command({ type: "key", key, modifiers: [] });
      }
      $("#present-previous").onclick = () => presentSlide("left");
      $("#present-next").onclick = () => presentSlide("right");
      $("#present-exit").onclick = () => { stopPresenting(); command({ type: "key", key: "escape", modifiers: [] }); };
      $("#present-open").onclick = (e) => { presentDisplay.value = currentDisplay; sheet("present-sheet", e.currentTarget); };
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
        const focusable = [...overlay.querySelectorAll("button:not(:disabled),a[href],input:not(:disabled),select:not(:disabled),textarea:not(:disabled),summary,[tabindex]:not([tabindex='-1'])")]
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
              appVersion: s.appVersion, appBuild: s.appBuild, macOSVersion: s.macOSVersion, signingStatus: s.signingStatus,
              accessibility: s.accessibility, sharing: s.sharing, sessionLocked: s.sessionLocked,
            };
            updateSupport();
            $("#connection-help").hidden = true;
            const wasLocked = locked;
            locked = !!s.sessionLocked;
            if (locked) {
              fingers.clear();
              stopPresenting();
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
              const previousPresentDisplay = presentDisplay.value;
              presentDisplay.replaceChildren();
              for (const d of s.displays || []) {
                const option = document.createElement("option"); option.value = d.id; option.textContent = d.name; presentDisplay.append(option);
              }
              presentDisplay.value = [...presentDisplay.options].some((o) => o.value === previousPresentDisplay) ? previousPresentDisplay : currentDisplay;
              presentDisplay.disabled = !presentDisplay.options.length;
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
          stopPresenting();
          dropQueuedMotion();
          endDrag();
        }
      });
      window.addEventListener("pagehide", () => {
        fingers.clear();
        stopPresenting();
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
