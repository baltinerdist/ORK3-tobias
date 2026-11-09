/* scroll-builder.js — filler: pick a template, edit zone text, live-render, fit. */
(function () {
	var B = window.SC_BUILDER || {}, R = window.ScrollRender;
	var page = document.getElementById('scPage'), stage = document.getElementById('scStage');
	var picker = document.getElementById('scTemplatePicker'), editor = document.getElementById('scZoneEditor');
	var current = null;                              // working copy of the selected template (zones editable)
	function byId(id) { return (B.templates || []).find(function (t) { return t.scroll_template_id == id; }); }
	function ctx() { return { tokens: B.tokens || {}, heraldry: B.heraldry || {}, packBase: B.packBase, libBase: B.libBase, editable: true }; }

	function render() {
		R.renderPage(page, current, ctx());
		R.autoscaleZones(page);
		R.fitToStage(page, stage);
	}
	function buildEditor() {
		editor.innerHTML = '';
		var head = document.createElement('h3'); head.className = 'sc-eyebrow'; head.textContent = 'Wording';
		editor.appendChild(head);
		if (!(current.zones || []).length) {
			var p = document.createElement('p'); p.className = 'sc-empty'; p.textContent = 'This template has no editable text.';
			editor.appendChild(p); return;
		}
		(current.zones || []).forEach(function (z, i) {
			var wrap = document.createElement('label'); wrap.className = 'sc-field';
			var lab = document.createElement('span'); lab.className = 'sc-field__label'; lab.textContent = z.label || z.key;
			var ta = document.createElement('textarea'); ta.className = 'sc-input'; ta.value = z.text || ''; ta.rows = 2;
			ta.addEventListener('input', function () { current.zones[i].text = ta.value; render(); });
			wrap.appendChild(lab); wrap.appendChild(ta); editor.appendChild(wrap);
		});
	}
	function select(id) {
		var t = byId(id); if (!t) return;
		current = JSON.parse(JSON.stringify(t));       // deep copy so edits don't mutate the source list
		buildEditor(); render();
	}
	// Group the picker: templates tagged for the award being granted come first
	// (under "For <Award>"), the rest under "Other templates"; default to a tagged one.
	function populatePicker() {
		if (!picker) { return; }
		var awardId = B.currentAwardId || 0, all = B.templates || [], matched = [], others = [];
		all.forEach(function (t) {
			var keys = (t.award_keys || []).map(Number);
			if (awardId && keys.indexOf(awardId) >= 0) { matched.push(t); } else { others.push(t); }
		});
		function opt(t) { var o = document.createElement('option'); o.value = t.scroll_template_id; o.textContent = t.name + (t.is_starter ? ' — starter' : ''); return o; }
		function group(label, list) { var g = document.createElement('optgroup'); g.label = label; list.forEach(function (t) { g.appendChild(opt(t)); }); return g; }
		picker.innerHTML = '';
		if (matched.length) {
			var awardName = (B.tokens && B.tokens.AwardName) ? B.tokens.AwardName : 'this award';
			picker.appendChild(group('For ' + awardName, matched));
			if (others.length) { picker.appendChild(group('Other templates', others)); }
		} else {
			all.forEach(function (t) { picker.appendChild(opt(t)); });
		}
		var def = matched.length ? matched[0] : (all[0] || null);
		if (def) { picker.value = def.scroll_template_id; select(def.scroll_template_id); }
	}
	if (picker) picker.addEventListener('change', function () { select(picker.value); });
	window.addEventListener('resize', function () { if (current) R.fitToStage(page, stage); });
	populatePicker();
	window.SC_getCurrent = function () { return current; };   // used by PDF export (Task 12)

	// --- direct client-side PDF download (jsPDF + html2canvas) ---
	var dlBtn = document.getElementById('scDownloadPdf');
	if (dlBtn) dlBtn.addEventListener('click', function () {
		if (!current) return;
		var t0 = page.style.transform; page.style.transform = 'scale(1)';        // export at natural size
		// re-render non-editable so token chips don't print
		R.renderPage(page, current, { tokens: B.tokens || {}, heraldry: B.heraldry || {}, packBase: B.packBase, libBase: B.libBase, editable: false });
		R.autoscaleZones(page);
		html2canvas(page, { scale: 3, useCORS: true, backgroundColor: null }).then(function (canvas) {
			var land = (current.orientation === 'landscape');
			var pdf = new jspdf.jsPDF({ orientation: land ? 'landscape' : 'portrait', unit: 'in', format: 'letter' });
			var w = land ? 11 : 8.5, h = land ? 8.5 : 11;
			pdf.addImage(canvas.toDataURL('image/jpeg', 0.95), 'JPEG', 0, 0, w, h);
			var name = ((B.tokens || {}).PlayerName || 'Scroll') + ' - ' + ((B.tokens || {}).AwardName || 'Award');
			pdf.save('Scroll - ' + name + '.pdf');
			page.style.transform = t0;                                            // restore preview
			R.renderPage(page, current, ctx()); R.autoscaleZones(page); R.fitToStage(page, stage);
		});
	});
})();
