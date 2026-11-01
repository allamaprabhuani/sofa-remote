(function () {
  'use strict';

  var touchpad = document.getElementById('touchpad');
  var cursor = document.getElementById('cursor');
  var desktop = document.getElementById('desktop');
  var windowEl = document.querySelector('.window');
  var status = document.getElementById('phoneStatus');
  var playBtn = document.getElementById('playBtn');
  var playIcon = document.getElementById('playIcon');
  if (!touchpad || !cursor || !desktop) return;

  // Cursor position as fraction of the desktop (0..1).
  var cx = 0.5, cy = 0.55;
  var dragging = false;
  var activePointerId = null;
  var lastX = 0, lastY = 0;
  var playing = false;
  var statusTimer = null;

  // Cursor SVG hotspot offset so the arrow tip sits at (x,y).
  var HOTSPOT_X = 1;
  var HOTSPOT_Y = 1;

  function clamp(v, lo, hi) { return v < lo ? lo : v > hi ? hi : v; }

  function placeCursor() {
    var rect = desktop.getBoundingClientRect();
    if (!rect.width || !rect.height) return;
    var x = clamp(cx * rect.width, 2, rect.width - 2);
    var y = clamp(cy * rect.height, 2, rect.height - 2);
    cursor.style.transform = 'translate(' + (x - HOTSPOT_X) + 'px,' + (y - HOTSPOT_Y) + 'px)';
  }
  placeCursor();
  window.addEventListener('resize', placeCursor);

  function moveBy(dx, dy, padW, padH) {
    cx = clamp(cx + dx / padW, 0.02, 0.98);
    cy = clamp(cy + dy / padH, 0.04, 0.96);
    placeCursor();
  }

  function setStatus(msg) {
    if (!status) return;
    status.textContent = msg;
    if (statusTimer) clearTimeout(statusTimer);
    statusTimer = setTimeout(function () { status.textContent = 'Demo ready'; }, 1400);
  }

  function flashWindow() {
    if (!windowEl) return;
    windowEl.classList.add('flash');
    setTimeout(function () { windowEl.classList.remove('flash'); }, 220);
  }

  touchpad.addEventListener('pointerdown', function (e) {
    if (!e.isPrimary) return;
    if (dragging) return;
    dragging = true;
    activePointerId = e.pointerId;
    lastX = e.clientX; lastY = e.clientY;
    touchpad.classList.add('active');
    try { touchpad.setPointerCapture(e.pointerId); } catch (_) {}
    e.preventDefault();
  });
  touchpad.addEventListener('pointermove', function (e) {
    if (!e.isPrimary) return;
    if (!dragging || e.pointerId !== activePointerId) return;
    var rect = touchpad.getBoundingClientRect();
    var dx = e.clientX - lastX;
    var dy = e.clientY - lastY;
    lastX = e.clientX; lastY = e.clientY;
    moveBy(dx, dy, rect.width, rect.height);
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
      case 'ArrowUp':    cy = clamp(cy - step, 0.04, 0.96); break;
      case 'ArrowDown':  cy = clamp(cy + step, 0.04, 0.96); break;
      case 'Enter':
      case ' ':
      case 'Spacebar':
        flashWindow(); setStatus('Click');
        break;
      default: handled = false;
    }
    if (handled) { placeCursor(); e.preventDefault(); }
  });

  var buttons = document.querySelectorAll('[data-act]');
  for (var i = 0; i < buttons.length; i++) {
    buttons[i].addEventListener('click', function (ev) {
      var act = ev.currentTarget.getAttribute('data-act');
      switch (act) {
        case 'left':    flashWindow(); setStatus('Click'); break;
        case 'right':   flashWindow(); setStatus('Right click'); break;
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
