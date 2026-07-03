/* scroll-design.js — layout maker. */
(function () {
	var D = window.SC_DESIGN || {}, R = window.ScrollRender;
	var page = document.getElementById('scPage'), stage = document.getElementById('scStage');
	var tpl = D.template || { name: '', orientation: 'portrait', bg_type: 'color', bg_value: '#ffffff', slots: [], zones: [], kingdom_id: D.kingdomId };
	var sel = null;                                  // {kind:'slot'|'zone', index}

	// ---- lightweight in-page toast (no native alert(); mirrors sgToast) ----
	function scToast(msg, type) {
		var t = document.createElement('div');
		t.textContent = msg;
		t.style.cssText = 'position:fixed;bottom:24px;right:24px;z-index:9999;' +
			'padding:10px 18px;border-radius:8px;font-size:.88rem;font-weight:600;' +
			'box-shadow:0 4px 14px rgba(0,0,0,.25);pointer-events:none;transition:opacity .4s;' +
			'background:' + (type === 'warn' ? '#e53e3e' : '#38a169') + ';color:#fff;';
		document.body.appendChild(t);
		setTimeout(function () {
			t.style.opacity = '0';
			setTimeout(function () { if (t.parentNode) { t.parentNode.removeChild(t); } }, 450);
		}, 2600);
	}

	function render() {
		R.renderPage(page, tpl, { tokens: {}, heraldry: D.heraldry, packBase: D.packBase, libBase: '', editable: true });
		R.autoscaleZones(page); R.fitToStage(page, stage);
		wireDrag(); markSelected();
	}
	function pageRect() { return page.getBoundingClientRect(); }
	function wireDrag() {
		page.querySelectorAll('.sc-slot, .sc-zone').forEach(function (el) {
			var kind = el.classList.contains('sc-slot') ? 'slot' : 'zone';
			var idx = (kind === 'slot' ? tpl.slots : tpl.zones).indexOf(el.__slot || el.__zone);
			el.addEventListener('mousedown', function (e) {
				if (e.target !== el && kind === 'zone') return;   // let inner text select
				e.preventDefault(); sel = { kind: kind, index: idx }; markSelected(); buildInspector();
				var pr = pageRect(), sx = e.clientX, sy = e.clientY;
				var obj = (kind === 'slot' ? tpl.slots : tpl.zones)[idx], ox = obj.x, oy = obj.y;
				function mv(ev) {
					obj.x = Math.max(0, Math.min(100, ox + (ev.clientX - sx) / pr.width  * 100));
					obj.y = Math.max(0, Math.min(100, oy + (ev.clientY - sy) / pr.height * 100));
					el.style.left = obj.x + '%'; el.style.top = obj.y + '%';
				}
				function up() { document.removeEventListener('mousemove', mv); document.removeEventListener('mouseup', up); }
				document.addEventListener('mousemove', mv); document.addEventListener('mouseup', up);
			});
		});
	}
	function markSelected() {
		page.querySelectorAll('.sc-slot,.sc-zone').forEach(function (el) { el.style.outlineWidth = ''; });
		if (!sel) return;
		var list = sel.kind === 'slot' ? page.querySelectorAll('.sc-slot') : page.querySelectorAll('.sc-zone');
		if (list[sel.index]) list[sel.index].style.outline = '2px solid #2a6cff';
	}
	function buildInspector() {
		var box = document.getElementById('scSelProps'); box.innerHTML = '';
		if (!sel) return;
		if (sel.kind === 'zone') {
			var z = tpl.zones[sel.index];
			box.appendChild(field('Font', z.font, function (v) { z.font = v; render(); }));
			box.appendChild(numField('Size', z.size, function (v) { z.size = +v; render(); }));
			box.appendChild(selectField('Align', ['left', 'center', 'right'], z.align, function (v) { z.align = v; render(); }));
			box.appendChild(colorField('Color', z.color || '#000000', function (v) { z.color = v; z.inherit_color = false; render(); }));
			['PlayerName', 'AwardName', 'Kingdom', 'Park', 'Date', 'GivenBy', 'Reason'].forEach(function (tk) {
				var b = document.createElement('button'); b.type = 'button'; b.className = 'sc-chip'; b.textContent = '{' + tk + '}';
				b.onclick = function () { z.text = (z.text || '') + '{' + tk + '}'; render(); }; box.appendChild(b);
			});
		} else {
			var s = tpl.slots[sel.index];
			box.appendChild(selectField('Source', ['pack', 'library', 'heraldry', 'none'], s.source_type, function (v) { s.source_type = v; render(); }));
			box.appendChild(packPicker(s));   // grid of D.packCatalog thumbnails filtered by slot; sets s.source_ref
		}
	}
	// page props (name/orientation/background)
	function buildPageProps() {
		var box = document.getElementById('scPageProps'); box.innerHTML = '';
		box.appendChild(selectField('Orientation', ['portrait', 'landscape'], tpl.orientation, function (v) { tpl.orientation = v; render(); }));
		box.appendChild(selectField('Background', ['color', 'texture', 'image'], tpl.bg_type, function (v) { tpl.bg_type = v; render(); }));
		box.appendChild(field('Background value', tpl.bg_value, function (v) { tpl.bg_value = v; render(); }));
	}
	// small field helpers
	function field(label, val, on) { var l = document.createElement('label'); l.textContent = label; var i = document.createElement('input'); i.value = val || ''; i.oninput = function () { on(i.value); }; l.appendChild(i); return l; }
	function numField(label, val, on) { var l = field(label, val, on); l.querySelector('input').type = 'number'; return l; }
	function colorField(label, val, on) { var l = field(label, val, on); l.querySelector('input').type = 'color'; return l; }
	function selectField(label, opts, val, on) { var l = document.createElement('label'); l.textContent = label; var s = document.createElement('select'); opts.forEach(function (o) { var op = document.createElement('option'); op.value = o; op.textContent = o; if (o === val) op.selected = true; s.appendChild(op); }); s.onchange = function () { on(s.value); }; l.appendChild(s); return l; }
	function packPicker(slot) {
		var d = document.createElement('div'); d.className = 'sc-pack-grid';
		(D.packCatalog || []).forEach(function (a) {
			var img = document.createElement('img'); img.src = D.packBase + a.file;
			img.alt = a.name; img.setAttribute('data-tip', a.name); img.className = 'sc-pack-thumb';   // data-tip, not native title
			img.onclick = function () { slot.source_type = 'pack'; slot.source_ref = a.file; render(); }; d.appendChild(img);
		});
		return d;
	}

	document.getElementById('scAddZone').onclick = function () { tpl.zones.push({ key: 'zone' + tpl.zones.length, label: 'Text', text: '{PlayerName}', font: 'EB Garamond', size: 32, min: 10, max: 48, align: 'center', color: '#000000', inherit_color: false, x: 20, y: 40, w: 60, h: 12, autoscale: true }); render(); };
	document.getElementById('scAddSlot').onclick = function () { tpl.slots.push({ location: 'center_image', x: 35, y: 55, w: 30, h: 30, source_type: 'pack', source_ref: '', fit: 'contain' }); render(); };
	document.getElementById('scSave').onclick = function () {
		tpl.name = document.getElementById('scTplName').value || tpl.name;
		fetch(D.saveUrl, {
			method: 'POST', headers: { 'Content-Type': 'application/json' }, credentials: 'same-origin',
			body: JSON.stringify(Object.assign({ id: tpl.scroll_template_id || 0, kingdom_id: D.kingdomId, token: D.token }, tpl))
		})
			.then(function (r) { return r.json(); }).then(function (j) {
				if (j.Status === 0) { tpl.scroll_template_id = j.TemplateId; scToast('Saved.'); }
				else { scToast(j.Message || 'Save failed.', 'warn'); }
			})
			.catch(function () { scToast('Save failed.', 'warn'); });
	};
	buildPageProps(); render();
})();
