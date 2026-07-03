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
		(current.zones || []).forEach(function (z, i) {
			var wrap = document.createElement('label'); wrap.textContent = z.label || z.key;
			var ta = document.createElement('textarea'); ta.value = z.text || ''; ta.rows = 2; ta.style.width = '100%';
			ta.addEventListener('input', function () { current.zones[i].text = ta.value; render(); });
			wrap.appendChild(ta); editor.appendChild(wrap);
		});
	}
	function select(id) {
		var t = byId(id); if (!t) return;
		current = JSON.parse(JSON.stringify(t));       // deep copy so edits don't mutate the source list
		buildEditor(); render();
	}
	if (picker) picker.addEventListener('change', function () { select(picker.value); });
	window.addEventListener('resize', function () { if (current) R.fitToStage(page, stage); });
	if ((B.templates || []).length) select(B.templates[0].scroll_template_id);
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
