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
})();
