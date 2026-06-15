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

	function endpoint(action) { return BASE_UIR + AJAX_BASE + '/' + ORG_ID + '/' + action; }

	/* --- In-product confirm (tnConfirm if available, else fallback) -------- */
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
		function closeC() { ov.classList.remove('od-open'); }
		ov.classList.add('od-open');
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
	window.odOpenDesignModal = function (panel) {
		overlay.classList.add('od-open');
		document.body.style.overflow = 'hidden';
		if (panel) switchPanel(panel);
		renderCustomMsList();
	};
	function closeModal() {
		overlay.classList.remove('od-open');
		document.body.style.overflow = '';
	}
	gid('od-dm-close').addEventListener('click', closeModal);
	gid('od-dm-cancel').addEventListener('click', closeModal);
	overlay.addEventListener('click', function (e) { if (e.target === overlay) closeModal(); });
	document.addEventListener('keydown', function (e) {
		if ((e.key === 'Escape' || e.keyCode === 27) && overlay.classList.contains('od-open')) closeModal();
	});

	function switchPanel(name) {
		document.querySelectorAll('.od-dm-tab').forEach(function (t) { t.classList.remove('od-active'); });
		document.querySelectorAll('.od-dm-panel').forEach(function (p) { p.classList.remove('od-active'); });
		var tab = document.querySelector('.od-dm-tab[data-odtab-dm="' + name + '"]');
		var panel = gid('od-dm-panel-' + name);
		if (tab) tab.classList.add('od-active');
		if (panel) panel.classList.add('od-active');
	}
	document.querySelectorAll('.od-dm-tab').forEach(function (t) {
		t.addEventListener('click', function () { switchPanel(t.dataset.odtabDm); });
	});

	/* --- Color presets + custom + hex sync --------------------------------- */
	var swatches = document.querySelectorAll('.od-dm-swatch');
	swatches.forEach(function (sw) {
		sw.addEventListener('click', function () {
			swatches.forEach(function (s) { s.classList.remove('od-selected'); });
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
		});
	});
	function syncHex(colorId, hexId) {
		var c = gid(colorId), h = gid(hexId);
		if (!c || !h) return;
		c.addEventListener('input', function () { h.value = this.value; });
		h.addEventListener('input', function () {
			if (/^#[0-9a-f]{6}$/i.test(this.value)) { c.value = this.value; }
		});
	}
	syncHex('od-dm-color-primary',   'od-dm-color-primary-hex');
	syncHex('od-dm-color-accent',    'od-dm-color-accent-hex');
	syncHex('od-dm-color-secondary', 'od-dm-color-secondary-hex');

	/* --- Overlay strength -------------------------------------------------- */
	document.querySelectorAll('.od-dm-overlay-btn').forEach(function (btn) {
		btn.addEventListener('click', function () {
			document.querySelectorAll('.od-dm-overlay-btn').forEach(function (b) { b.classList.remove('od-active'); });
			btn.classList.add('od-active');
			gid('od-dm-hero-overlay').value = btn.dataset.overlay;
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
			loadFont(f.key);
		}
		container.innerHTML = html;
		container.addEventListener('click', function (e) {
			var card = e.target.closest('.od-dm-font-card');
			if (!card) return;
			selectedFont = card.dataset.fontKey;
			container.querySelectorAll('.od-dm-font-card').forEach(function (c) {
				c.classList.toggle('od-active', c === card);
			});
		});
	}
	renderFontPicker();

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
	var anClear = gid('od-dm-announcement-clear');
	if (anClear) anClear.addEventListener('click', function () { gid('od-dm-announcement-until').value = ''; });

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
					pv.innerHTML = DOMPurify.sanitize(marked.parse(ta.value || ''));
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
				 +    '<button type="button" data-tip="Delete" data-ms-del="' + m.MilestoneId + '"><i class="fas fa-trash"></i></button>'
				 + '</div>';
		}
		list.innerHTML = html;
	}
	var newestFirstToggle = gid('od-dm-ms-newest-first');
	if (newestFirstToggle) newestFirstToggle.addEventListener('change', renderCustomMsList);

	// Delegated delete (replaces inline onclick + native confirm()).
	var msList = gid('od-dm-ms-list');
	if (msList) {
		msList.addEventListener('click', function (e) {
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

	/* --- Add milestone ----------------------------------------------------- */
	var addBtn = gid('od-dm-ms-add-btn');
	if (addBtn) {
		addBtn.addEventListener('click', function () {
			var desc = gid('od-dm-ms-add-desc').value.trim();
			var date = gid('od-dm-ms-add-date').value;
			var err  = gid('od-dm-ms-add-err');
			err.style.display = 'none';
			if (!desc) { err.textContent = 'Description is required.'; err.style.display = ''; return; }
			if (!date) { err.textContent = 'Date is required.'; err.style.display = ''; return; }
			var btn = this; btn.disabled = true; btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i>';
			var fd = new FormData();
			fd.append('Description', desc);
			fd.append('MilestoneDate', date);
			fd.append('Icon', selectedIcon);
			fetch(endpoint('addmilestone'), { method: 'POST', body: fd })
				.then(function (r) { return r.json(); })
				.then(function (result) {
					if (result && result.status === 0) {
						customMs.push({
							MilestoneId: result.milestoneId,
							Icon: selectedIcon,
							Description: desc,
							MilestoneDate: date
						});
						renderCustomMsList();
						gid('od-dm-ms-add-desc').value = '';
						gid('od-dm-ms-add-date').value = '';
						iconGrid.querySelectorAll('.od-dm-ms-icon-opt').forEach(function (o) { o.classList.remove('od-active'); });
						var star = iconGrid.querySelector('[data-icon="fa-star"]');
						if (star) star.classList.add('od-active');
						selectedIcon = 'fa-star';
					} else {
						err.textContent = (result && result.error) || 'Failed to add milestone.';
						err.style.display = '';
					}
				})
				.catch(function () { err.textContent = 'Request failed.'; err.style.display = ''; })
				.finally(function () { btn.disabled = false; btn.innerHTML = '<i class="fas fa-plus"></i> Add'; });
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
	window.odDeleteMilestone = deleteMilestone;

	/* --- Save -------------------------------------------------------------- */
	gid('od-dm-save').addEventListener('click', function () {
		var btn = this; btn.disabled = true; btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Saving...';
		var errEl = gid('od-dm-error'); errEl.style.display = 'none';
		var fd = new FormData();
		fd.append('AboutText', gid('od-dm-about-text').value);
		fd.append('OurHistory', gid('od-dm-history-text').value);
		fd.append('ColorPrimary', gid('od-dm-color-primary').value);
		fd.append('ColorAccent', gid('od-dm-color-accent').value);
		fd.append('ColorSecondary', gid('od-dm-gradient-enabled').checked ? gid('od-dm-color-secondary').value : '');
		fd.append('HeroOverlay', gid('od-dm-hero-overlay').value);
		fd.append('NameFont', selectedFont || '');

		var msConfig = {};
		document.querySelectorAll('#od-dm-ms-toggles input[data-odms-type]').forEach(function (t) {
			msConfig[t.dataset.odmsType] = t.checked ? 1 : 0;
		});
		msConfig['newest_first'] = gid('od-dm-ms-newest-first').checked ? 1 : 0;
		fd.append('MilestoneConfig', JSON.stringify(msConfig));

		fd.append('Tagline', gid('od-dm-tagline').value);
		fd.append('Announcement', gid('od-dm-announcement').value);
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
})();
