(function () {
  'use strict';

  // -------------------- Touchpad preview --------------------
  var touchpad = document.getElementById('touchpad');
  var cursor = document.getElementById('cursor');
  var status = document.getElementById('phoneStatus');
  var playBtn = document.getElementById('playBtn');
  var playIcon = document.getElementById('playIcon');
  if (!touchpad || !cursor) return;

  // A local, replayable illustration; this does not connect to a Mac.
  var desktop = document.getElementById('desktopDemo');
  var desktopCursor = document.getElementById('desktopCursor');
  var replay = document.getElementById('demoReplay');
  if (replay) {
    replay.addEventListener('click', function () {
      touchpad.classList.remove('is-demonstrating');
      if (desktop) desktop.classList.remove('is-demonstrating');
      if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
        if (status) status.textContent = 'Move a finger on the touchpad to move the pointer. Preview only.';
        return;
      }
      // Restart on a fresh frame, including if the animation is already running.
      requestAnimationFrame(function () { requestAnimationFrame(function () {
        touchpad.classList.add('is-demonstrating');
        if (desktop) desktop.classList.add('is-demonstrating');
      }); });
      if (status) status.textContent = 'Gesture demonstration. Preview only.';
    });
    touchpad.addEventListener('animationend', function (event) {
      if (event.animationName === 'demo-swipe') {
        touchpad.classList.remove('is-demonstrating');
        if (desktop) desktop.classList.remove('is-demonstrating');
        if (status) status.textContent = 'Preview — not connected.';
      }
    });
  }

  var cx = 0.5, cy = 0.5;
  var dragging = false;
  var activePointerId = null;
  var lastX = 0, lastY = 0, startX = 0, startY = 0;
  var moved = false;
  var playing = false;
  var statusTimer = null;

  function clamp(v, lo, hi) { return v < lo ? lo : v > hi ? hi : v; }
  function placeCursor() {
    var rect = touchpad.getBoundingClientRect();
    if (!rect.width || !rect.height) return;
    var x = clamp(cx * rect.width, 6, rect.width - 6);
    var y = clamp(cy * rect.height, 6, rect.height - 6);
    cursor.style.transform = 'translate(' + x + 'px,' + y + 'px)';
    if (desktop && desktopCursor) {
      var desktopRect = desktop.getBoundingClientRect();
      desktopCursor.style.left = (cx * Math.max(0, desktopRect.width - 18)) + 'px';
      desktopCursor.style.top = (cy * Math.max(0, desktopRect.height - 22)) + 'px';
    }
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
    statusTimer = setTimeout(function () { status.textContent = 'Preview — not connected.'; }, 1400);
  }

  touchpad.addEventListener('pointerdown', function (e) {
    if (!e.isPrimary || dragging) return;
    dragging = true;
    activePointerId = e.pointerId;
    lastX = startX = e.clientX; lastY = startY = e.clientY;
    moved = false;
    touchpad.classList.add('active');
    try { touchpad.setPointerCapture(e.pointerId); } catch (_) {}
    e.preventDefault();
  });
  touchpad.addEventListener('pointermove', function (e) {
    if (!e.isPrimary || !dragging || e.pointerId !== activePointerId) return;
    var rect = touchpad.getBoundingClientRect();
    if (Math.hypot(e.clientX - startX, e.clientY - startY) > 6) moved = true;
    moveBy(e.clientX - lastX, e.clientY - lastY, rect.width, rect.height);
    lastX = e.clientX; lastY = e.clientY;
  });
  function endDrag(e) {
    if (!dragging || e.pointerId !== activePointerId) return;
    dragging = false;
    activePointerId = null;
    touchpad.classList.remove('active');
    if (e.type === 'pointerup' && !moved) setStatus('Click');
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
        case 'help': setStatus('Help is available in the connected remote.'); break;
        case 'keyboard': setStatus('Keyboard is available in the connected remote.'); break;
        case 'shortcuts': setStatus('Shortcuts are available in the connected remote.'); break;
        case 'settings': setStatus('Settings are available in the connected remote.'); break;
        case 'right':   setStatus('Right click'); markMoved(); break;
        case 'drag':
          var enabled = ev.currentTarget.getAttribute('aria-pressed') !== 'true';
          ev.currentTarget.setAttribute('aria-pressed', String(enabled));
          setStatus(enabled ? 'Drag on' : 'Drag off'); markMoved(); break;
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
