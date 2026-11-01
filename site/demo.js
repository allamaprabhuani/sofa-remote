(function () {
  'use strict';

  // Theme palettes mirror Sources/SofaRemote/RemotePage.swift.
  // Keep in sync by eye if those change; the real remote is authoritative.
  var THEMES = {
    dark:   { bg: '#1f1f1f', card: '#292929', pad: '#181818', line: '#777777', muted: '#b8b8b8', accent: '#a9cdf5', ink: '#ededed', pressed: '#383838' },
    black:  { bg: '#000000', card: '#000000', pad: '#000000', line: '#737373', muted: '#bdbdbd', accent: '#c7dcf5', ink: '#f5f5f5', pressed: '#222222' },
    light:  { bg: '#f8f8f8', card: '#ffffff', pad: '#f0f0f0', line: '#767676', muted: '#555555', accent: '#005fb8', ink: '#242424', pressed: '#e5e5e5' },
    ivory:  { bg: '#f6f1e7', card: '#fffaf0', pad: '#eee7da', line: '#99836c', muted: '#645141', accent: '#754726', ink: '#35261c', pressed: '#e4d8c7' },
    plum:   { bg: '#f8f2ed', card: '#fff9f5', pad: '#efe4ec', line: '#9b7f99', muted: '#685369', accent: '#704381', ink: '#38233c', pressed: '#e7d9e5' },
    ocean:  { bg: '#062d35', card: '#103c45', pad: '#0b343d', line: '#75949a', muted: '#bcd8dd', accent: '#a1e9ee', ink: '#f4ffff', pressed: '#244e57' },
  };
  var THEME_NAMES = ['dark', 'black', 'light', 'ivory', 'plum', 'ocean', 'custom'];
  var HEX6 = /^#[0-9a-f]{6}$/i;
  function safeColour(v, fallback) { return typeof v === 'string' && HEX6.test(v) ? v.toLowerCase() : fallback; }
  function luminance(hex) {
    var ch = [1,3,5].map(function (n) {
      var v = parseInt(hex.slice(n, n + 2), 16) / 255;
      return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
    });
    return ch[0] * 0.2126 + ch[1] * 0.7152 + ch[2] * 0.0722;
  }
  function contrast(a, b) {
    var la = luminance(a), lb = luminance(b);
    return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
  }
  function mixColour(a, b, ratio) {
    return '#' + [1,3,5].map(function (n) {
      var v = Math.round(parseInt(a.slice(n, n + 2), 16) * (1 - ratio) + parseInt(b.slice(n, n + 2), 16) * ratio);
      return v.toString(16).padStart(2, '0');
    }).join('');
  }
  function customPalette(colour) {
    var bg = safeColour(colour, '#1f1f1f');
    var ink = contrast(bg, '#ffffff') >= contrast(bg, '#000000') ? '#ffffff' : '#000000';
    var shade = ink === '#ffffff' ? '#000000' : '#ffffff';
    var card = mixColour(bg, shade, 0.12), pad = mixColour(bg, shade, 0.06);
    var line = ink;
    [0.55, 0.7, 0.85, 1].some(function (r) {
      var cand = mixColour(bg, ink, r);
      if (contrast(cand, bg) >= 3 && contrast(cand, card) >= 3) { line = cand; return true; }
      return false;
    });
    return { bg: bg, card: card, pad: pad, line: line, muted: ink, accent: ink, ink: ink, pressed: mixColour(bg, shade, 0.2) };
  }

  var STORAGE_THEME = 'sofaSiteTheme';
  var STORAGE_COLOUR = 'sofaSiteColour';

  var swatches = Array.prototype.slice.call(document.querySelectorAll('.swatch'));
  var stage = document.querySelector('.live-shell');
  var customInput = document.getElementById('customColour');
  var customDot = document.getElementById('customDot');
  var themeStatus = document.getElementById('themeStatus');

  var state = { name: 'dark', colour: '#1f1f1f' };

  function applyTheme(name, colour) {
    var known = THEME_NAMES.indexOf(name) >= 0 ? name : 'dark';
    state.name = known;
    state.colour = safeColour(colour, state.colour || '#1f1f1f');
    var palette = known === 'custom' ? customPalette(state.colour) : THEMES[known];
    if (stage) {
      stage.style.setProperty('--demo-bg', palette.bg);
      stage.style.setProperty('--demo-card', palette.card);
      stage.style.setProperty('--demo-pad', palette.pad);
      stage.style.setProperty('--demo-line', palette.line);
      stage.style.setProperty('--demo-muted', palette.muted);
      stage.style.setProperty('--demo-ink', palette.ink);
      stage.style.setProperty('--demo-pressed', palette.pressed);
      stage.style.setProperty('--demo-accent', palette.accent);
      stage.style.setProperty('--demo-accent-ink', contrast(palette.accent, '#ffffff') >= contrast(palette.accent, '#000000') ? '#ffffff' : '#000000');
    }
    swatches.forEach(function (btn) {
      var active = btn.getAttribute('data-theme') === known;
      btn.classList.toggle('is-active', active);
      btn.setAttribute('aria-pressed', active ? 'true' : 'false');
    });
    if (customDot) {
      customDot.style.background = state.colour;
      customDot.style.borderColor = palette.line;
    }
    if (customInput && customInput.value.toLowerCase() !== state.colour) {
      customInput.value = state.colour;
    }
    if (themeStatus) {
      themeStatus.innerHTML = 'Showing <strong>' + prettyName(known) + '</strong>. Seven free themes. Change your phone remote in Settings.';
    }
    document.body.setAttribute('data-site-theme', known);
  }
  function prettyName(name) {
    return { dark: 'Dark', black: 'Black', light: 'Light', ivory: 'Ivory', plum: 'Plum', ocean: 'Ocean', custom: 'Custom' }[name] || name;
  }
  function saveTheme() {
    try {
      localStorage.setItem(STORAGE_THEME, state.name);
      localStorage.setItem(STORAGE_COLOUR, state.colour);
    } catch (_) {}
  }

  try {
    var savedName = localStorage.getItem(STORAGE_THEME) || 'dark';
    var savedColour = localStorage.getItem(STORAGE_COLOUR) || '#1f1f1f';
    applyTheme(savedName, savedColour);
  } catch (_) { applyTheme('dark', '#1f1f1f'); }

  swatches.forEach(function (btn) {
    btn.addEventListener('click', function () {
      applyTheme(btn.getAttribute('data-theme'), state.colour);
      saveTheme();
    });
  });
  if (customInput) {
    customInput.addEventListener('input', function (e) {
      applyTheme('custom', e.target.value);
    });
    customInput.addEventListener('change', saveTheme);
  }

  // -------------------- Touchpad preview --------------------
  var touchpad = document.getElementById('touchpad');
  var cursor = document.getElementById('cursor');
  var status = document.getElementById('phoneStatus');
  var playBtn = document.getElementById('playBtn');
  var playIcon = document.getElementById('playIcon');
  if (!touchpad || !cursor) return;

  var cx = 0.5, cy = 0.5;
  var dragging = false;
  var activePointerId = null;
  var lastX = 0, lastY = 0;
  var playing = false;
  var statusTimer = null;

  function clamp(v, lo, hi) { return v < lo ? lo : v > hi ? hi : v; }
  function placeCursor() {
    var rect = touchpad.getBoundingClientRect();
    if (!rect.width || !rect.height) return;
    var x = clamp(cx * rect.width, 6, rect.width - 6);
    var y = clamp(cy * rect.height, 6, rect.height - 6);
    cursor.style.transform = 'translate(' + x + 'px,' + y + 'px)';
  }
  placeCursor();
  window.addEventListener('resize', placeCursor);

  function markMoved() { touchpad.classList.add('has-moved'); }
  function moveBy(dx, dy, w, h) {
    cx = clamp(cx + dx / w, 0.02, 0.98);
    cy = clamp(cy + dy / h, 0.02, 0.98);
    placeCursor();
    markMoved();
  }
  function setStatus(msg) {
    if (!status) return;
    status.textContent = msg;
    if (statusTimer) clearTimeout(statusTimer);
    statusTimer = setTimeout(function () { status.textContent = 'Preview ready.'; }, 1400);
  }

  touchpad.addEventListener('pointerdown', function (e) {
    if (!e.isPrimary || dragging) return;
    dragging = true;
    activePointerId = e.pointerId;
    lastX = e.clientX; lastY = e.clientY;
    touchpad.classList.add('active');
    try { touchpad.setPointerCapture(e.pointerId); } catch (_) {}
    e.preventDefault();
  });
  touchpad.addEventListener('pointermove', function (e) {
    if (!e.isPrimary || !dragging || e.pointerId !== activePointerId) return;
    var rect = touchpad.getBoundingClientRect();
    moveBy(e.clientX - lastX, e.clientY - lastY, rect.width, rect.height);
    lastX = e.clientX; lastY = e.clientY;
  });
  function endDrag(e) {
    if (!dragging || e.pointerId !== activePointerId) return;
    dragging = false;
    activePointerId = null;
    touchpad.classList.remove('active');
    try { touchpad.releasePointerCapture(e.pointerId); } catch (_) {}
  }
  touchpad.addEventListener('pointerup', endDrag);
  touchpad.addEventListener('pointercancel', endDrag);

  touchpad.addEventListener('keydown', function (e) {
    var step = e.shiftKey ? 0.08 : 0.03;
    var handled = true;
    switch (e.key) {
      case 'ArrowLeft':  cx = clamp(cx - step, 0.02, 0.98); break;
      case 'ArrowRight': cx = clamp(cx + step, 0.02, 0.98); break;
      case 'ArrowUp':    cy = clamp(cy - step, 0.02, 0.98); break;
      case 'ArrowDown':  cy = clamp(cy + step, 0.02, 0.98); break;
      case 'Enter':
      case ' ':
      case 'Spacebar':
        setStatus('Click'); markMoved();
        break;
      default: handled = false;
    }
    if (handled) { placeCursor(); markMoved(); e.preventDefault(); }
  });

  var acts = document.querySelectorAll('[data-act]');
  for (var i = 0; i < acts.length; i++) {
    acts[i].addEventListener('click', function (ev) {
      var act = ev.currentTarget.getAttribute('data-act');
      switch (act) {
        case 'right':   setStatus('Right click'); markMoved(); break;
        case 'double':  setStatus('Double click'); markMoved(); break;
        case 'drag':    setStatus('Drag toggle'); markMoved(); break;
        case 'prev':    setStatus('Previous track'); break;
        case 'next':    setStatus('Next track'); break;
        case 'voldown': setStatus('Volume down'); break;
        case 'volup':   setStatus('Volume up'); break;
        case 'play':
          playing = !playing;
          if (playIcon) {
            playIcon.innerHTML = playing
              ? '<path d="M7 5h4v14H7zM13 5h4v14h-4z" fill="currentColor"/>'
              : '<path d="M7 5l12 7-12 7z" fill="currentColor"/>';
          }
          if (playBtn) playBtn.setAttribute('aria-label', playing ? 'Pause' : 'Play');
          setStatus(playing ? 'Play' : 'Pause');
          break;
      }
    });
  }
})();
