/* ============================================================================
   Shared Org Design modal module (Kingdom / Park / Unit).

   Org-neutral: reads everything it needs from the modal root's data attributes
   (#od-dm-overlay: data-od-org / data-od-id / data-od-ajax / data-od-name /
   data-od-name-font) and a JSON bootstrap island (#od-dm-bootstrap). No prefix-
   or org-specific code. No-ops gracefully when the modal root is absent (e.g.
   a non-manager viewing the page).

   Endpoints (all POST FormData):
     {ajax}/{id}/savedesign
     {ajax}/{id}/addmilestone
     {ajax}/{id}/deletemilestone

   Milestone delete uses tnConfirm() when present; otherwise an in-product
   confirm dialog (NEVER native confirm()/alert()).
   ============================================================================ */
(function () {
	'use strict';

	var overlay = document.getElementById('od-dm-overlay');
	if (!overlay) { return; } // non-manager view, or modal not rendered

	function gid(id) { return document.getElementById(id); }
	function esc(s) {
		return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
			return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c];
		});
	}

	/* --- Config from the modal root + bootstrap island --------------------- */
	var ORG_ID   = parseInt(overlay.getAttribute('data-od-id'), 10) || 0;
	var AJAX_BASE = (overlay.getAttribute('data-od-ajax') || '').replace(/\/+$/, '');
	// UIR is the app's index-route prefix (e.g. ".../index.php?Route="), baked
	// into the modal root by the partial. Fall back to window.UIR if present.
	var BASE_UIR = overlay.getAttribute('data-od-uir')
		|| ((typeof window.UIR === 'string' && window.UIR) ? window.UIR : '');

	var boot = {};
	var bootEl = gid('od-dm-bootstrap');
	if (bootEl) {
		try { boot = JSON.parse(bootEl.textContent || '{}'); } catch (e) { boot = {}; }
	}
	var FONTS    = Array.isArray(boot.fonts) ? boot.fonts : [];
	var SNIPPETS = boot.snippets && typeof boot.snippets === 'object' ? boot.snippets : {};
	var SAMPLE_NAME = boot.sampleName || '';
	var FEATURES = boot.features || {};

	var selectedFont = boot.nameFont || overlay.getAttribute('data-od-name-font') || '';
	var selectedIcon = 'fa-star';
	var customMs = Array.isArray(boot.customMs) ? boot.customMs.slice() : [];

	// Stored (possibly empty) hero colors, so we can tell "never customized" from
	// the prefilled placeholder defaults and avoid forcing a solid color on save.
	var STORED_PRIMARY   = boot.colorPrimary   || '';
	var STORED_ACCENT    = boot.colorAccent    || '';
	var STORED_SECONDARY = boot.colorSecondary || '';
	var colorsDirty = false; // user picked/edited a color control
	var colorsReset = false; // user hit "reset colors to default"
	function markColorsDirty() { colorsDirty = true; colorsReset = false; updatePreview(); }

	function endpoint(action) { return BASE_UIR + AJAX_BASE + '/' + ORG_ID + '/' + action; }

	/* --- On-demand vendor libs (perf) --------------------------------------
	   marked / DOMPurify / flatpickr are used ONLY inside the design modal, so
	   the profile templates no longer ship them as blocking <script> tags. They
	   are injected the first time a manager opens the modal. Everything that
	   uses them already degrades gracefully, so a failed load must still call
	   back rather than hang the UI. Note flatpickr may ALREADY be present on
	   Kingdom/Park (revised.js uses it elsewhere) — handle both cases. */
	var odScripts = {}; // src -> { done: bool, queue: [cb] }
	function odLoadScript(src, globalName, cb) {
		cb = cb || function () {};
		if (globalName && typeof window[globalName] !== 'undefined') { cb(); return; }
		var st = odScripts[src];
		if (st) {
			if (st.done) { cb(); } else { st.queue.push(cb); }
			return;
		}
		st = odScripts[src] = { done: false, queue: [cb] };
		var s = document.createElement('script');
		s.src = src;
		s.async = true;
		function settle() {
			if (st.done) return;
			st.done = true;
			var q = st.queue; st.queue = [];
			for (var i = 0; i < q.length; i++) { q[i](); }
		}
		s.addEventListener('load', settle);
		s.addEventListener('error', settle); // degrade, never hang
		document.head.appendChild(s);
	}
	function odLoadStyle(href) {
		if (document.querySelector('link[data-od-lib-css="' + href + '"]')) return;
		if (document.querySelector('link[rel="stylesheet"][href="' + href + '"]')) return;
		var l = document.createElement('link');
		l.rel = 'stylesheet';
		l.href = href;
		l.setAttribute('data-od-lib-css', href);
		document.head.appendChild(l);
	}
	var libsRequested = false;
	/* Fire-and-forget: takes no callback, so it cannot promise a "settled"
	   moment it does not actually track. Each library hydrates its own
	   dependants as it lands. */
	function odEnsureLibs() {
		if (libsRequested) return;
		libsRequested = true;
		odLoadScript('https://cdn.jsdelivr.net/npm/marked@12/marked.min.js', 'marked');
		odLoadScript('https://cdn.jsdelivr.net/npm/dompurify@3/dist/purify.min.js', 'DOMPurify');
		if (typeof window.flatpickr !== 'function') {
			odLoadStyle('https://cdn.jsdelivr.net/npm/flatpickr@4/dist/flatpickr.min.css');
		}
		// Pinned major + explicit dist file: /npm/flatpickr@4 alone resolves the
		// package main field and serves the UNMINIFIED build via a redirect.
		odLoadScript('https://cdn.jsdelivr.net/npm/flatpickr@4/dist/flatpickr.min.js', 'flatpickr', function () {
			hydrateAnnounceDatePickers();
		});
	}

	/* --- In-product confirm (tnConfirm if available, else fallback) --------
	   odConfirmClose holds the close handler for the currently-open fallback
	   confirm. A single shared Escape listener (registered with the modal's,
	   below) reads it, so repeat opens never stack listeners. */
	var odConfirmClose = null;
	function odConfirm(opts) {
		opts = opts || {};
		if (typeof window.tnConfirm === 'function') {
			window.tnConfirm({
				title: opts.title || 'Confirm',
				body: opts.body || '',
				confirmLabel: opts.confirmLabel || 'Confirm',
				danger: !!opts.danger,
				onConfirm: opts.onConfirm || function () {}
			});
			return;
		}
		// Self-contained fallback dialog (no native confirm()).
		var ov = document.getElementById('od-confirm-overlay');
		if (!ov) {
			ov = document.createElement('div');
			ov.className = 'od-confirm-overlay';
			ov.id = 'od-confirm-overlay';
			ov.innerHTML =
				'<div class="od-confirm-box">' +
				'<div class="od-confirm-head" id="od-confirm-head"></div>' +
				'<div class="od-confirm-body" id="od-confirm-body"></div>' +
				'<div class="od-confirm-foot">' +
				'<button type="button" class="od-confirm-btn" id="od-confirm-cancel">Cancel</button>' +
				'<button type="button" class="od-confirm-btn od-confirm-btn-danger" id="od-confirm-ok"></button>' +
				'</div></div>';
			document.body.appendChild(ov);
		}
		gid('od-confirm-head').textContent = opts.title || 'Confirm';
		gid('od-confirm-body').textContent = opts.body || '';
		var okBtn = gid('od-confirm-ok');
		okBtn.textContent = opts.confirmLabel || 'Confirm';
		okBtn.classList.toggle('od-confirm-btn-danger', !!opts.danger);
		function closeC() { ov.classList.remove('od-open'); odConfirmClose = null; }
		ov.classList.add('od-open');
		odConfirmClose = closeC;
		gid('od-confirm-cancel').onclick = closeC;
		ov.onclick = function (e) { if (e.target === ov) closeC(); };
		okBtn.onclick = function () { closeC(); if (opts.onConfirm) opts.onConfirm(); };
	}

	function odNotify(msg) {
		// Non-blocking error surface: reuse the modal's error band when open,
		// else fall back to the in-product confirm (info-only).
		var errEl = gid('od-dm-error');
		if (errEl && overlay.classList.contains('od-open')) {
			errEl.textContent = msg;
			errEl.style.display = 'block';
			return;
		}
		odConfirm({ title: 'Heads up', body: msg, confirmLabel: 'OK', onConfirm: function () {} });
	}

	/* --- Open / close ------------------------------------------------------ */
	/* Scroll lock: body{overflow:hidden} alone does not hold on iOS, so pin the
	   body with position:fixed at the saved scroll offset and restore whatever
	   inline values were there before (not a blind clear). */
	var scrollLock = null;
	function lockScroll() {
		if (scrollLock) return;
		var b = document.body;
		scrollLock = {
			y: window.pageYOffset || document.documentElement.scrollTop || 0,
			overflow: b.style.overflow,
			position: b.style.position,
			top: b.style.top,
			width: b.style.width
		};
		b.style.overflow = 'hidden';
		b.style.position = 'fixed';
		b.style.top = '-' + scrollLock.y + 'px';
		b.style.width = '100%';
	}
	function unlockScroll() {
		if (!scrollLock) return;
		var b = document.body;
		b.style.overflow = scrollLock.overflow;
		b.style.position = scrollLock.position;
		b.style.top      = scrollLock.top;
		b.style.width    = scrollLock.width;
		var y = scrollLock.y;
		scrollLock = null;
		window.scrollTo(0, y);
	}
	function confirmIsOpen() {
		var c = document.getElementById('od-confirm-overlay');
		return !!(c && c.classList.contains('od-open'));
	}
	window.odOpenDesignModal = function (panel) {
		odEnsureLibs(); // marked / DOMPurify / flatpickr are modal-only
		overlay.classList.add('od-open');
		lockScroll();
		if (panel) switchPanel(panel);
		renderCustomMsList();
		updatePreview();
	};
	function closeModal() {
		overlay.classList.remove('od-open');
		unlockScroll();
	}
	gid('od-dm-close').addEventListener('click', closeModal);
	gid('od-dm-cancel').addEventListener('click', closeModal);
	overlay.addEventListener('click', function (e) { if (e.target === overlay) closeModal(); });
	document.addEventListener('keydown', function (e) {
		if (e.key !== 'Escape' && e.keyCode !== 27) return;
		// A flatpickr calendar layers above everything and does not stop Escape
		// propagation — let it close first so unsaved edits survive.
		if (document.querySelector('.flatpickr-calendar.open')) return;
		// The confirm dialog layers ABOVE the design modal — dismiss it first and
		// leave the modal open underneath.
		if (confirmIsOpen()) { if (odConfirmClose) odConfirmClose(); return; }
		if (overlay.classList.contains('od-open')) closeModal();
	});

	function switchPanel(name) {
		document.querySelectorAll('.od-dm-tab').forEach(function (t) {
			t.classList.remove('od-active');
			t.setAttribute('aria-selected', 'false');
		});
		document.querySelectorAll('.od-dm-panel').forEach(function (p) { p.classList.remove('od-active'); });
		var tab = document.querySelector('.od-dm-tab[data-odtab-dm="' + name + '"]');
		var panel = gid('od-dm-panel-' + name);
		if (tab) { tab.classList.add('od-active'); tab.setAttribute('aria-selected', 'true'); }
		if (panel) panel.classList.add('od-active');
		// FE#32: the font picker lives on the Header panel. Defer loading all the
		// Google fonts until the manager actually opens it (only the selected font
		// is eager-loaded at init). loadFont() dedupes, so re-hitting this is safe.
		if (name === 'header') { hydrateAllFonts(); }
	}
	document.querySelectorAll('.od-dm-tab').forEach(function (t) {
		t.addEventListener('click', function () { switchPanel(t.dataset.odtabDm); });
	});

	/* --- Color presets + custom + hex sync ---------------------------------
	   The preset/gradient swatches are rendered here from the bootstrap island
	   (they used to be ~27KB of server markup). Because they no longer exist at
	   module-init time, the click handling is DELEGATED to the stable grids. */
	var COLOR_PRESETS    = Array.isArray(boot.colorPresets) ? boot.colorPresets : [];
	var GRADIENT_PRESETS = Array.isArray(boot.gradientPresets) ? boot.gradientPresets : [];
	var MS_ICONS         = Array.isArray(boot.msIcons) ? boot.msIcons : [];

	function renderColorPresets() {
		var c = gid('od-dm-presets');
		if (!c || !COLOR_PRESETS.length) return;
		var html = '';
		for (var i = 0; i < COLOR_PRESETS.length; i++) {
			var p = COLOR_PRESETS[i];
			html += '<div class="od-dm-swatch" data-primary="' + esc(p.primary) + '" data-accent="' + esc(p.accent) + '"'
				 +    ' style="background:' + esc(p.primary) + '"></div>';
		}
		c.innerHTML = html;
	}
	function renderGradientPresets() {
		var c = gid('od-dm-gradient-presets');
		if (!c || !GRADIENT_PRESETS.length) return;
		var html = '';
		for (var i = 0; i < GRADIENT_PRESETS.length; i++) {
			var g = GRADIENT_PRESETS[i];
			html += '<div class="od-dm-swatch" data-primary="' + esc(g.primary) + '" data-accent="' + esc(g.accent) + '"'
				 +    ' data-secondary="' + esc(g.secondary) + '" style="background:' + esc(g.css) + '"></div>';
		}
		c.innerHTML = html;
	}
	function renderMsIcons() {
		var c = gid('od-dm-ms-icons');
		if (!c || !MS_ICONS.length) return;
		var html = '';
		for (var i = 0; i < MS_ICONS.length; i++) {
			var ic = MS_ICONS[i];
			html += '<div class="od-dm-ms-icon-opt' + (ic === selectedIcon ? ' od-active' : '') + '" data-icon="' + esc(ic) + '">'
				 +    '<i class="fas ' + esc(ic) + '"></i></div>';
		}
		c.innerHTML = html;
	}
	renderColorPresets();
	renderGradientPresets();
	renderMsIcons();

	function clearSwatchSelection() {
		document.querySelectorAll('.od-dm-swatch').forEach(function (s) { s.classList.remove('od-selected'); });
	}
	function bindSwatchGrid(gridId) {
		var grid = gid(gridId);
		if (!grid) return;
		grid.addEventListener('click', function (e) {
			var sw = e.target.closest('.od-dm-swatch');
			if (!sw || !grid.contains(sw)) return;
			clearSwatchSelection();
			sw.classList.add('od-selected');
			gid('od-dm-color-primary').value     = sw.dataset.primary;
			gid('od-dm-color-primary-hex').value = sw.dataset.primary;
			gid('od-dm-color-accent').value      = sw.dataset.accent;
			gid('od-dm-color-accent-hex').value  = sw.dataset.accent;
			if (sw.dataset.secondary) {
				gid('od-dm-color-secondary').value     = sw.dataset.secondary;
				gid('od-dm-color-secondary-hex').value = sw.dataset.secondary;
				gid('od-dm-gradient-enabled').checked  = true;
			} else {
				gid('od-dm-color-secondary-hex').value = '';
				gid('od-dm-gradient-enabled').checked  = false;
			}
			markColorsDirty();
		});
	}
	bindSwatchGrid('od-dm-presets');
	bindSwatchGrid('od-dm-gradient-presets');

	function syncHex(colorId, hexId) {
		var c = gid(colorId), h = gid(hexId);
		if (!c || !h) return;
		c.addEventListener('input', function () { h.value = this.value; markColorsDirty(); });
		h.addEventListener('input', function () {
			if (/^#[0-9a-f]{6}$/i.test(this.value)) { c.value = this.value; }
			markColorsDirty();
		});
	}
	syncHex('od-dm-color-primary',   'od-dm-color-primary-hex');
	syncHex('od-dm-color-accent',    'od-dm-color-accent-hex');
	syncHex('od-dm-color-secondary', 'od-dm-color-secondary-hex');
	var gradEnabled = gid('od-dm-gradient-enabled');
	if (gradEnabled) gradEnabled.addEventListener('change', markColorsDirty);

	/* --- Reset colors to default (FE#17) ---------------------------------- */
	var colorResetBtn = gid('od-dm-color-reset');
	if (colorResetBtn) {
		colorResetBtn.addEventListener('click', function () {
			colorsReset = true; colorsDirty = false;
			gid('od-dm-color-primary').value       = '#2c5282';
			gid('od-dm-color-primary-hex').value   = '';
			gid('od-dm-color-accent').value        = '#4299e1';
			gid('od-dm-color-accent-hex').value    = '';
			gid('od-dm-color-secondary').value     = '#2c5282';
			gid('od-dm-color-secondary-hex').value = '';
			gid('od-dm-gradient-enabled').checked  = false;
			clearSwatchSelection();
			updatePreview();
		});
	}

	/* --- Live hero preview (FE#29) ----------------------------------------- */
	function updatePreview() {
		var hero = gid('od-dm-preview-hero');
		if (!hero) return;
		var primary   = gid('od-dm-color-primary').value || '#2c5282';
		var gradOn    = gid('od-dm-gradient-enabled').checked;
		var secondary = gid('od-dm-color-secondary').value || primary;
		hero.style.background = gradOn
			? 'linear-gradient(135deg,' + primary + ',' + secondary + ')'
			: primary;
		var ov = (gid('od-dm-hero-overlay') && gid('od-dm-hero-overlay').value) || 'med';
		var veilMap = { low: 0.06, med: 0.13, high: 0.28, vignette: 0.45 };
		hero.style.setProperty('--od-preview-overlay', veilMap[ov] != null ? veilMap[ov] : 0.13);
		hero.classList.toggle('od-preview-vignette', ov === 'vignette');
		var nameEl = gid('od-dm-preview-name');
		if (nameEl) {
			var fam = '';
			for (var i = 0; i < FONTS.length; i++) {
				if (FONTS[i].key === selectedFont && FONTS[i].key) { fam = FONTS[i].family + ", 'Cinzel', serif"; break; }
			}
			nameEl.style.fontFamily = fam;
		}
		var tagEl = gid('od-dm-preview-tagline');
		if (tagEl) {
			var tg = (gid('od-dm-tagline') && gid('od-dm-tagline').value || '').trim();
			if (tg) { tagEl.textContent = tg; tagEl.style.display = ''; }
			else { tagEl.textContent = ''; tagEl.style.display = 'none'; }
		}
	}

	/* --- Overlay strength -------------------------------------------------- */
	document.querySelectorAll('.od-dm-overlay-btn').forEach(function (btn) {
		btn.addEventListener('click', function () {
			document.querySelectorAll('.od-dm-overlay-btn').forEach(function (b) { b.classList.remove('od-active'); });
			btn.classList.add('od-active');
			gid('od-dm-hero-overlay').value = btn.dataset.overlay;
			updatePreview();
		});
	});

	/* --- Recruitment segmented control (Unit) ------------------------------ */
	var recruitRow = gid('od-dm-recruit-row');
	if (recruitRow) {
		recruitRow.addEventListener('click', function (e) {
			var opt = e.target.closest('.od-dm-recruit-opt');
			if (!opt) return;
			recruitRow.querySelectorAll('.od-dm-recruit-opt').forEach(function (o) { o.classList.remove('od-active'); });
			opt.classList.add('od-active');
			gid('od-dm-recruit-status').value = opt.dataset.recruit || '';
		});
	}

	/* --- Font picker ------------------------------------------------------- */
	function loadFont(key) {
		if (!key) return;
		if (document.querySelector('link[data-od-font="' + key + '"]')) return;
		var link = document.createElement('link');
		link.rel = 'stylesheet';
		link.href = 'https://fonts.googleapis.com/css2?family=' + key.replace(/ /g, '+') + '&display=swap';
		link.setAttribute('data-od-font', key);
		document.head.appendChild(link);
	}
	// FE#32: lazy font hydration. At init we eager-load ONLY the currently-selected
	// font (needed for the live hero preview / name display). The remaining picker
	// fonts load the first time the Header panel — which hosts the picker — is shown.
	var fontsHydrated = false;
	function hydrateAllFonts() {
		if (fontsHydrated) { return; }
		fontsHydrated = true;
		for (var i = 0; i < FONTS.length; i++) { loadFont(FONTS[i].key); }
	}
	function renderFontPicker() {
		var container = gid('od-dm-font-picker');
		if (!container) return;
		var html = '';
		for (var i = 0; i < FONTS.length; i++) {
			var f = FONTS[i];
			var active = f.key === selectedFont;
			html += '<div class="od-dm-font-card' + (active ? ' od-active' : '') + '" data-font-key="' + esc(f.key) + '">'
				 +    '<div class="od-dm-font-sample" style="font-family:' + f.family + '">' + esc(SAMPLE_NAME) + '</div>'
				 +    '<div class="od-dm-font-label">' + esc(f.label) + '</div>'
				 + '</div>';
		}
		container.innerHTML = html;
		container.addEventListener('click', function (e) {
			var card = e.target.closest('.od-dm-font-card');
			if (!card) return;
			selectedFont = card.dataset.fontKey;
			loadFont(selectedFont); // in case fonts weren't hydrated yet
			container.querySelectorAll('.od-dm-font-card').forEach(function (c) {
				c.classList.toggle('od-active', c === card);
			});
			updatePreview();
		});
	}
	renderFontPicker();
	loadFont(selectedFont); // FE#32: eager-load only the current hero font at init

	/* --- Counters ---------------------------------------------------------- */
	function bindCounter(taId, counterId, limit, formatted) {
		var ta = gid(taId), c = gid(counterId);
		if (!ta || !c) return;
		function upd() {
			var n = (ta.value || '').length;
			c.textContent = n + ' / ' + (formatted || limit);
			c.classList.toggle('od-over', n > limit);
		}
		ta.addEventListener('input', upd);
		upd();
	}
	bindCounter('od-dm-tagline',      'od-dm-tagline-counter',      160);
	bindCounter('od-dm-announcement', 'od-dm-announcement-counter', 280);
	bindCounter('od-dm-reign-text',   'od-dm-reign-counter',        2000, '2,000');
	var taglineInput = gid('od-dm-tagline');
	if (taglineInput) taglineInput.addEventListener('input', updatePreview);

	/* --- Announcement lifecycle (FE#39) ------------------------------------
	   Human-readable date pickers for "starts"/"until", a clear-both control, and
	   a computed Live / Scheduled / Expired indicator. Flatpickr is optional and
	   now arrives on demand with the modal (odEnsureLibs), so everything degrades
	   to the native date input until/unless it loads. */
	var fpAnnounce = {};
	function annToday() {
		var d = new Date();
		var mo = ('0' + (d.getMonth() + 1)).slice(-2);
		var da = ('0' + d.getDate()).slice(-2);
		return d.getFullYear() + '-' + mo + '-' + da;
	}
	function annHuman(iso) {
		if (!iso || iso === '0000-00-00') return '';
		var d = new Date(iso + 'T00:00:00');
		if (isNaN(d.getTime())) return iso;
		return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
	}
	function updateAnnounceStatus() {
		var el = gid('od-dm-announce-status');
		if (!el) return;
		var txt    = (gid('od-dm-announcement').value || '').trim();
		var sEl    = gid('od-dm-announcement-starts');
		var starts = sEl ? sEl.value : '';
		var until  = gid('od-dm-announcement-until').value;
		var today  = annToday();
		var label, cls;
		if (!txt) {
			label = 'Not currently shown'; cls = 'od-neutral';
		} else if (until && until !== '0000-00-00' && until < today) {
			label = 'Expired'; cls = 'od-expired';
		} else if (starts && starts !== '0000-00-00' && starts > today) {
			label = 'Scheduled (starts ' + annHuman(starts) + ')'; cls = 'od-scheduled';
		} else {
			label = 'Live'; cls = 'od-live';
		}
		el.textContent = label;
		el.className = 'od-dm-announce-status ' + cls;
		el.style.display = '';
	}
	// Idempotent: attaches a flatpickr instance only once per input, and only
	// once the library exists (it is now loaded on demand with the modal).
	function attachAnnounceFlatpickr(id) {
		if (fpAnnounce[id]) return;
		if (typeof window.flatpickr !== 'function') return;
		var el = gid(id);
		if (!el || el._flatpickr) return;
		fpAnnounce[id] = window.flatpickr(el, {
			altInput: true,
			altFormat: 'F j, Y',
			dateFormat: 'Y-m-d',
			onChange: updateAnnounceStatus
		});
	}
	function hydrateAnnounceDatePickers() {
		attachAnnounceFlatpickr('od-dm-announcement-starts');
		attachAnnounceFlatpickr('od-dm-announcement-until');
	}
	function initAnnounceDatePicker(id) {
		var el = gid(id);
		if (!el) return;
		attachAnnounceFlatpickr(id); // no-op when flatpickr isn't loaded yet
		el.addEventListener('change', updateAnnounceStatus); // bound exactly once
	}
	function clearAnnounceDate(id) {
		if (fpAnnounce[id]) { fpAnnounce[id].clear(); }
		else if (gid(id)) { gid(id).value = ''; }
	}
	initAnnounceDatePicker('od-dm-announcement-starts');
	initAnnounceDatePicker('od-dm-announcement-until');
	var anClear = gid('od-dm-announcement-clear');
	if (anClear) anClear.addEventListener('click', function () {
		clearAnnounceDate('od-dm-announcement-starts');
		clearAnnounceDate('od-dm-announcement-until');
		updateAnnounceStatus();
	});
	var anTextEl = gid('od-dm-announcement');
	if (anTextEl) anTextEl.addEventListener('input', updateAnnounceStatus);
	updateAnnounceStatus();

	/* --- Markdown Write/Preview toggles ------------------------------------ */
	function taIdForField(field) {
		if (field === 'about')   return 'od-dm-about-text';
		if (field === 'history') return 'od-dm-history-text';
		if (field === 'reign')   return 'od-dm-reign-text';
		if (field === 'join')    return 'od-dm-join-text';
		return 'od-dm-' + field + '-text';
	}
	document.querySelectorAll('[data-odmd-target]').forEach(function (btn) {
		btn.addEventListener('click', function () {
			var field  = btn.dataset.odmdField;
			var target = btn.dataset.odmdTarget;
			var ta     = gid(taIdForField(field));
			var pv     = gid('od-dm-' + field + '-preview');
			if (!ta || !pv) return;
			btn.parentElement.querySelectorAll('button').forEach(function (b) { b.classList.remove('od-active'); });
			btn.classList.add('od-active');
			if (target === 'preview') {
				ta.style.display = 'none';
				pv.style.display = '';
				if (typeof marked !== 'undefined' && typeof DOMPurify !== 'undefined') {
					// Mirror the published server render (org_design_markdown):
					// Parsedown SafeMode + line-breaks, with <img> stripped. So we
					// enable breaks and forbid <img> here too, otherwise the manager
					// previews GFM/images that visitors will never actually see.
					var _html = marked.parse(ta.value || '', { breaks: true });
					pv.innerHTML = DOMPurify.sanitize(_html, { FORBID_TAGS: ['img'] });
				} else {
					pv.textContent = ta.value;
				}
			} else {
				ta.style.display = '';
				pv.style.display = 'none';
			}
		});
	});

	/* --- Quick-snippet insertion ------------------------------------------- */
	document.querySelectorAll('[data-odquick]').forEach(function (btn) {
		btn.addEventListener('click', function () {
			var key   = btn.dataset.odquick;
			var field = btn.dataset.odfield;
			var ta    = gid(taIdForField(field));
			if (!ta) return;
			var writeBtn = document.querySelector('[data-odmd-field="' + field + '"][data-odmd-target="edit"]');
			if (writeBtn && !writeBtn.classList.contains('od-active')) writeBtn.click();
			var snippet = SNIPPETS[key] || '';
			if (!snippet) return;
			var existing = ta.value;
			var sep = existing.length === 0 ? '' : (existing.endsWith('\n\n') ? '' : (existing.endsWith('\n') ? '\n' : '\n\n'));
			ta.value = existing + sep + snippet;
			ta.focus();
			ta.setSelectionRange(ta.value.length, ta.value.length);
		});
	});

	/* --- Custom milestones list -------------------------------------------- */
	var editingMsId = null; // FE#27: id of the milestone currently being edited, or null
	function renderCustomMsList() {
		var list = gid('od-dm-ms-list');
		if (!list) return;
		var newestFirst = gid('od-dm-ms-newest-first').checked;
		customMs.sort(function (a, b) {
			var ad = a.MilestoneDate || '', bd = b.MilestoneDate || '';
			return newestFirst ? bd.localeCompare(ad) : ad.localeCompare(bd);
		});
		if (customMs.length === 0) {
			list.innerHTML = '<div style="padding:14px;font-size:12px;color:#a0aec0">No custom milestones yet.</div>';
			return;
		}
		var html = '';
		for (var i = 0; i < customMs.length; i++) {
			var m = customMs[i];
			var dateStr = m.MilestoneDate || '';
			if (dateStr && dateStr !== '0000-00-00') {
				var d = new Date(dateStr + 'T00:00:00');
				if (!isNaN(d.getTime())) dateStr = d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
			}
			var icon = (m.Icon || 'fa-star').replace(/[^a-z0-9-]/g, '');
			html += '<div class="od-dm-ms-row" data-ms-id="' + m.MilestoneId + '">'
				 +    '<i class="fas ' + icon + '"></i>'
				 +    '<span class="od-dm-ms-desc">' + esc(m.Description) + '</span>'
				 +    '<span class="od-dm-ms-date">' + dateStr + '</span>'
				 +    '<button type="button" data-tip="Edit" aria-label="Edit milestone" data-ms-edit="' + m.MilestoneId + '"><i class="fas fa-pencil-alt" aria-hidden="true"></i></button>'
				 +    '<button type="button" data-tip="Delete" aria-label="Delete milestone" data-ms-del="' + m.MilestoneId + '"><i class="fas fa-trash" aria-hidden="true"></i></button>'
				 + '</div>';
		}
		list.innerHTML = html;
	}
	/* Milestone visibility + ordering config (FE#26): shared by the main Save and
	   the immediate per-change persist below, so toggle state never depends on the
	   manager remembering to hit Save (previously toggle-then-Cancel lost it). */
	function buildMilestoneConfig() {
		var msConfig = {};
		document.querySelectorAll('#od-dm-ms-toggles input[data-odms-type]').forEach(function (t) {
			msConfig[t.dataset.odmsType] = t.checked ? 1 : 0;
		});
		msConfig['newest_first'] = gid('od-dm-ms-newest-first').checked ? 1 : 0;
		return msConfig;
	}
	// Partial POST — the server only touches milestone_config (fields absent from
	// the request are left untouched), so this can't clobber other design fields.
	function persistMilestoneConfig() {
		var fd = new FormData();
		fd.append('MilestoneConfig', JSON.stringify(buildMilestoneConfig()));
		fetch(endpoint('savedesign'), { method: 'POST', body: fd })
			.then(function (r) { return r.json(); })
			.then(function (result) {
				if (!(result && result.status === 0)) {
					odNotify((result && result.error) || 'Could not save milestone settings.');
				}
			})
			.catch(function () { odNotify('Could not save milestone settings.'); });
	}
	var newestFirstToggle = gid('od-dm-ms-newest-first');
	if (newestFirstToggle) newestFirstToggle.addEventListener('change', function () {
		renderCustomMsList();
		persistMilestoneConfig();
	});
	document.querySelectorAll('#od-dm-ms-toggles input[data-odms-type]').forEach(function (t) {
		t.addEventListener('change', persistMilestoneConfig);
	});

	// Delegated delete (replaces inline onclick + native confirm()).
	var msList = gid('od-dm-ms-list');
	if (msList) {
		msList.addEventListener('click', function (e) {
			var editBtn = e.target.closest('[data-ms-edit]');
			if (editBtn) {
				var eid = parseInt(editBtn.getAttribute('data-ms-edit'), 10);
				var m = null;
				for (var i = 0; i < customMs.length; i++) {
					if (customMs[i].MilestoneId === eid) { m = customMs[i]; break; }
				}
				if (m) enterMsEditMode(m);
				return;
			}
			var delBtn = e.target.closest('[data-ms-del]');
			if (!delBtn) return;
			var id = parseInt(delBtn.getAttribute('data-ms-del'), 10);
			deleteMilestone(id);
		});
	}

	/* --- Icon picker ------------------------------------------------------- */
	var iconGrid = gid('od-dm-ms-icons');
	if (iconGrid) {
		iconGrid.addEventListener('click', function (e) {
			var opt = e.target.closest('.od-dm-ms-icon-opt');
			if (!opt) return;
			iconGrid.querySelectorAll('.od-dm-ms-icon-opt').forEach(function (o) { o.classList.remove('od-active'); });
			opt.classList.add('od-active');
			selectedIcon = opt.dataset.icon;
		});
	}

	/* --- Add / update milestone (FE#27) ------------------------------------ */
	var addBtn = gid('od-dm-ms-add-btn');
	function msAddLabel()    { return '<i class="fas fa-plus"></i> Add'; }
	function msUpdateLabel() { return '<i class="fas fa-save"></i> Update Milestone'; }
	function selectMsIcon(icon) {
		selectedIcon = icon || 'fa-star';
		if (!iconGrid) return;
		iconGrid.querySelectorAll('.od-dm-ms-icon-opt').forEach(function (o) {
			o.classList.toggle('od-active', o.dataset.icon === selectedIcon);
		});
	}
	// Load a row into the add-inputs and flip into edit mode.
	function enterMsEditMode(m) {
		editingMsId = m.MilestoneId;
		gid('od-dm-ms-add-desc').value = m.Description || '';
		gid('od-dm-ms-add-date').value = (m.MilestoneDate && m.MilestoneDate !== '0000-00-00') ? m.MilestoneDate : '';
		selectMsIcon(m.Icon);
		if (addBtn) addBtn.innerHTML = msUpdateLabel();
		var cancel = gid('od-dm-ms-edit-cancel');
		if (cancel) cancel.style.display = '';
		var err = gid('od-dm-ms-add-err');
		if (err) err.style.display = 'none';
		gid('od-dm-ms-add-desc').focus();
	}
	// Reset the add-inputs and return to plain add mode.
	function exitMsEditMode() {
		editingMsId = null;
		gid('od-dm-ms-add-desc').value = '';
		gid('od-dm-ms-add-date').value = '';
		selectMsIcon('fa-star');
		if (addBtn) addBtn.innerHTML = msAddLabel();
		var cancel = gid('od-dm-ms-edit-cancel');
		if (cancel) cancel.style.display = 'none';
	}
	var msEditCancel = gid('od-dm-ms-edit-cancel');
	if (msEditCancel) msEditCancel.addEventListener('click', exitMsEditMode);
	if (addBtn) {
		addBtn.addEventListener('click', function () {
			var desc = gid('od-dm-ms-add-desc').value.trim();
			var date = gid('od-dm-ms-add-date').value;
			var err  = gid('od-dm-ms-add-err');
			err.style.display = 'none';
			if (!desc) { err.textContent = 'Description is required.'; err.style.display = ''; return; }
			if (!date) { err.textContent = 'Date is required.'; err.style.display = ''; return; }
			var editing = editingMsId != null;
			var btn = this; btn.disabled = true; btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i>';
			var fd = new FormData();
			fd.append('Description', desc);
			fd.append('MilestoneDate', date);
			fd.append('Icon', selectedIcon);
			if (editing) { fd.append('MilestoneId', editingMsId); }
			fetch(endpoint(editing ? 'updatemilestone' : 'addmilestone'), { method: 'POST', body: fd })
				.then(function (r) { return r.json(); })
				.then(function (result) {
					if (result && result.status === 0) {
						if (editing) {
							for (var i = 0; i < customMs.length; i++) {
								if (customMs[i].MilestoneId === editingMsId) {
									customMs[i].Description   = desc;
									customMs[i].MilestoneDate = date;
									customMs[i].Icon          = selectedIcon;
									break;
								}
							}
							exitMsEditMode();
							renderCustomMsList();
						} else {
							customMs.push({
								MilestoneId: result.milestoneId,
								Icon: selectedIcon,
								Description: desc,
								MilestoneDate: date
							});
							renderCustomMsList();
							gid('od-dm-ms-add-desc').value = '';
							gid('od-dm-ms-add-date').value = '';
							selectMsIcon('fa-star');
						}
					} else {
						err.textContent = (result && result.error) || (editing ? 'Failed to update milestone.' : 'Failed to add milestone.');
						err.style.display = '';
					}
				})
				.catch(function () { err.textContent = 'Request failed.'; err.style.display = ''; })
				.finally(function () {
					btn.disabled = false;
					btn.innerHTML = (editingMsId != null) ? msUpdateLabel() : msAddLabel();
				});
		});
	}

	/* --- Delete milestone (in-product confirm) ----------------------------- */
	function deleteMilestone(id) {
		odConfirm({
			title: 'Delete milestone?',
			body: 'This will permanently remove this custom milestone from the timeline.',
			confirmLabel: 'Delete',
			danger: true,
			onConfirm: function () {
				var fd = new FormData();
				fd.append('MilestoneId', id);
				fetch(endpoint('deletemilestone'), { method: 'POST', body: fd })
					.then(function (r) { return r.json(); })
					.then(function (result) {
						if (result && result.status === 0) {
							customMs = customMs.filter(function (m) { return m.MilestoneId !== id; });
							renderCustomMsList();
						} else {
							odNotify((result && result.error) || 'Failed to delete milestone.');
						}
					})
					.catch(function () { odNotify('Request failed.'); });
			}
		});
	}
	// Expose for any legacy inline handlers that may still reference it.
	/* odDeleteMilestone export removed — no callers */;

	/* --- Save -------------------------------------------------------------- */
	gid('od-dm-save').addEventListener('click', function () {
		var btn = this; btn.disabled = true; btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Saving...';
		var errEl = gid('od-dm-error'); errEl.style.display = 'none';
		var fd = new FormData();
		fd.append('AboutText', gid('od-dm-about-text').value);
		fd.append('OurHistory', gid('od-dm-history-text').value);

		// Colors (FE#17): only commit edited values. Untouched → resend the stored
		// value (which may be empty). Reset → send '' so the server clears the
		// columns — never the prefilled placeholder default, which would otherwise
		// force the hero to a solid color on the first save of any field.
		var primaryOut, accentOut, secondaryOut;
		if (colorsReset) {
			primaryOut = ''; accentOut = ''; secondaryOut = '';
		} else if (colorsDirty) {
			primaryOut   = gid('od-dm-color-primary').value;
			accentOut    = gid('od-dm-color-accent').value;
			secondaryOut = gid('od-dm-gradient-enabled').checked ? gid('od-dm-color-secondary').value : '';
		} else {
			primaryOut   = STORED_PRIMARY;
			accentOut    = STORED_ACCENT;
			secondaryOut = STORED_SECONDARY;
		}
		fd.append('ColorPrimary', primaryOut);
		fd.append('ColorAccent', accentOut);
		fd.append('ColorSecondary', secondaryOut);
		fd.append('HeroOverlay', gid('od-dm-hero-overlay').value);
		fd.append('NameFont', selectedFont || '');

		fd.append('MilestoneConfig', JSON.stringify(buildMilestoneConfig()));

		fd.append('Tagline', gid('od-dm-tagline').value);
		fd.append('Announcement', gid('od-dm-announcement').value);
		var _annStartsEl = gid('od-dm-announcement-starts');
		fd.append('AnnouncementStarts', _annStartsEl ? _annStartsEl.value : '');
		fd.append('AnnouncementUntil', gid('od-dm-announcement-until').value);

		// Reign (Kingdom)
		if (FEATURES.reign) {
			var mr = gid('od-dm-monarch-reign'), rr = gid('od-dm-regent-reign'), rl = gid('od-dm-reign-text');
			if (mr) fd.append('MonarchReignStarted', mr.value);
			if (rr) fd.append('RegentReignStarted', rr.value);
			if (rl) fd.append('ReignLore', rl.value);
		}
		// Recruitment + How to Join (Unit)
		if (FEATURES.recruitment) {
			var rs = gid('od-dm-recruit-status');
			if (rs) fd.append('RecruitmentStatus', rs.value);
		}
		if (FEATURES.how_to_join) {
			var hj = gid('od-dm-join-text');
			if (hj) fd.append('HowToJoin', hj.value);
		}

		var socialPayload = {};
		document.querySelectorAll('[data-odsoc]').forEach(function (inp) {
			var v = (inp.value || '').trim();
			if (v) socialPayload[inp.dataset.odsoc] = v;
		});
		fd.append('SocialLinks', JSON.stringify(socialPayload));

		var aboutEnabledEl = gid('od-dm-about-enabled');
		if (aboutEnabledEl) {
			fd.append('AboutEnabled', aboutEnabledEl.checked ? '1' : '0');
		}

		fetch(endpoint('savedesign'), { method: 'POST', body: fd })
			.then(function (r) { return r.json(); })
			.then(function (result) {
				if (result && result.status === 0) {
					// Release the position:fixed scroll lock BEFORE reloading, or
					// the document scrollTop is 0 at unload and the browser
					// restores the manager to the top of the page.
					unlockScroll();
					window.location.reload();
				} else {
					errEl.textContent = (result && result.error) || 'Save failed.';
					errEl.style.display = 'block';
					btn.disabled = false;
					btn.innerHTML = '<i class="fas fa-save"></i> Save Changes';
				}
			})
			.catch(function (e) {
				errEl.textContent = 'Request failed: ' + e.message;
				errEl.style.display = 'block';
				btn.disabled = false;
				btn.innerHTML = '<i class="fas fa-save"></i> Save Changes';
			});
	});

	renderCustomMsList();
	updatePreview();
})();
