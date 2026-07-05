/* scroll-design.js — layout maker (designer). */
(function () {
	var D = window.SC_DESIGN || {}, R = window.ScrollRender;
	var page = document.getElementById('scPage'), stage = document.getElementById('scStage');
	var tpl = (D.template && typeof D.template === 'object')
		? D.template
		: { name: '', orientation: 'portrait', bg_type: 'color', bg_value: '#ffffff', slots: [], zones: [], kingdom_id: D.kingdomId };
	if (!Array.isArray(tpl.slots)) { tpl.slots = []; }
	if (!Array.isArray(tpl.zones)) { tpl.zones = []; }
	if (!Array.isArray(tpl.award_keys)) { tpl.award_keys = []; }
	tpl.award_keys = tpl.award_keys.map(Number);       // ids as numbers for reliable toggling
	if (tpl.kingdom_id == null) { tpl.kingdom_id = D.kingdomId; }
	var sel = null;                                  // { kind:'slot'|'zone', index:Number }
	var groupState = {};                             // explicit type-chip choice, per collection
	var lastSelKey = null;                           // identity of the slot the picker last defaulted for

	var TOKENS = ['PlayerName', 'AwardName', 'Kingdom', 'Park', 'Date', 'GivenBy', 'Reason'];
	var FONTS = ['EB Garamond', 'Cinzel', 'Cinzel Decorative', 'Cormorant Garamond', 'Almendra', 'MedievalSharp',
		'UnifrakturMaguntia', 'Great Vibes', 'Pinyon Script', 'Tangerine', 'Uncial Antiqua', 'Goudy Bookletter 1911',
		'Sorts Mill Goudy', 'Metamorphous', 'Grenze Gotisch', 'Caudex', 'Fondamento', 'Germania One', 'Eagle Lake',
		'Pirata One', 'Jim Nightshade'];
	var LOCATIONS = ['full_border', 'center_image', 'top_graphic', 'background', 'border_left', 'border_right', 'border_top', 'border_bottom'];

	var KNOT_PRESETS = {
		Flame: { enabled: true, pattern: 'plait', band: { inset: 1.8, width: 5.5 }, strands: { count: 3, thickness: 0.48, scale: 0.85 },
			colors: { strands: ['#b3231a', '#e4670f', '#f5a623'], outline: '#2a0c05' },
			gradient: { enabled: true, angle: 90, stops: [{ at: 0, color: '#a11212' }, { at: 0.55, color: '#e4670f' }, { at: 1, color: '#f7c948' }] },
			corners: 'hook',
			breaks: [{ edge: 'top', at: 50, width: 10 }, { edge: 'bottom', at: 50, width: 26 }], autoBreak: { enabled: true, padding: 2 } },
		Dragon: { enabled: true, pattern: 'openweave', band: { inset: 2, width: 6.2 }, strands: { count: 4, thickness: 0.55, scale: 1 },
			colors: { strands: ['#2e6b2f', '#e9b840'], outline: '#12240f' }, gradient: { enabled: false, angle: 90, stops: [{ at: 0, color: '#2e6b2f' }, { at: 1, color: '#e9b840' }] },
			corners: 'woven',
			breaks: [{ edge: 'bottom', at: 50, width: 26 }], autoBreak: { enabled: true, padding: 2 } },
		Crown: { enabled: true, pattern: 'openweave', band: { inset: 2, width: 6 }, strands: { count: 4, thickness: 0.55, scale: 1 },
			colors: { strands: ['#2b2b2e', '#e7b83b'], outline: '#101012' }, gradient: { enabled: false, angle: 90, stops: [{ at: 0, color: '#2b2b2e' }, { at: 1, color: '#e7b83b' }] },
			corners: 'woven',
			breaks: [{ edge: 'bottom', at: 50, width: 30 }], autoBreak: { enabled: true, padding: 2 } },
		Smith: { enabled: true, pattern: 'twist', band: { inset: 2, width: 5.8 }, strands: { count: 2, thickness: 0.6, scale: 1 },
			colors: { strands: ['#8a6844', '#7b8494'], outline: '#241a10' }, gradient: { enabled: false, angle: 90, stops: [{ at: 0, color: '#8a6844' }, { at: 1, color: '#7b8494' }] },
			corners: 'woven',
			breaks: [{ edge: 'bottom', at: 50, width: 30 }], autoBreak: { enabled: true, padding: 2 } }
	};
	var KNOT_PATTERNS = ['plait', 'openweave', 'twist'];

	// which catalog collection suits a given slot placement
	function collectionForPlacement(loc) {
		if (loc === 'full_border' || /^border_/.test(loc)) { return 'borders'; }
		if (loc === 'background' || loc === 'watermark') { return 'backgrounds'; }   // 'watermark' = legacy alias
		return 'order_images';
	}
	var COLLECTION_LABELS = { borders: 'Borders', order_images: 'Order Images', backgrounds: 'Backgrounds' };
	// distinct groups in catalog order (catalog is pre-sorted by group order)
	function orderedGroups(items) {
		var seen = [], set = {};
		items.forEach(function (a) { var g = a.group || 'Other'; if (!set[g]) { set[g] = 1; seen.push(g); } });
		return seen;
	}
	// a sensible default rect (percent) for a placement
	function rectFor(loc) {
		switch (loc) {
			case 'full_border':   return { x: 2, y: 2, w: 96, h: 96 };
			case 'border_left':   return { x: 1, y: 4, w: 14, h: 92 };
			case 'border_right':  return { x: 85, y: 4, w: 14, h: 92 };
			case 'border_top':    return { x: 4, y: 1, w: 92, h: 12 };
			case 'border_bottom': return { x: 4, y: 87, w: 92, h: 12 };
			case 'background':
			case 'watermark':     return { x: 0, y: 0, w: 100, h: 100 };
			case 'top_graphic':   return { x: 6, y: 5, w: 16, h: 20 };
			default:              return { x: 35, y: 40, w: 30, h: 30 };  // center_image
		}
	}
	function baseName(f) { return String(f || '').replace(/^.*\//, ''); }

	// ---- toast (no native alert()) ----
	function scToast(msg, type) {
		var t = document.createElement('div');
		t.textContent = msg;
		t.style.cssText = 'position:fixed;bottom:24px;right:24px;z-index:9999;padding:10px 18px;border-radius:8px;' +
			'font:600 .88rem system-ui;box-shadow:0 4px 14px rgba(0,0,0,.25);pointer-events:none;transition:opacity .4s;' +
			'background:' + (type === 'warn' ? '#c0392b' : '#2f855a') + ';color:#fff;';
		document.body.appendChild(t);
		setTimeout(function () { t.style.opacity = '0'; setTimeout(function () { if (t.parentNode) { t.parentNode.removeChild(t); } }, 450); }, 2400);
	}

	// ---- render + selection ----
	function ctx() { return { tokens: {}, heraldry: D.heraldry, packBase: D.packBase, libBase: '', editable: true }; }
	function render() {
		R.renderPage(page, tpl, ctx());
		R.autoscaleZones(page); R.fitToStage(page, stage);
		wireDrag(); markSelected();
	}
	function pageRect() { return page.getBoundingClientRect(); }
	function wireDrag() {
		page.querySelectorAll('.sc-slot, .sc-zone').forEach(function (elem) {
			var kind = elem.classList.contains('sc-slot') ? 'slot' : 'zone';
			var idx = (kind === 'slot' ? tpl.slots : tpl.zones).indexOf(elem.__slot || elem.__zone);
			elem.addEventListener('mousedown', function (e) {
				e.preventDefault();
				sel = { kind: kind, index: idx }; refreshInspector();
				var pr = pageRect(), sx = e.clientX, sy = e.clientY;
				var obj = (kind === 'slot' ? tpl.slots : tpl.zones)[idx], ox = obj.x, oy = obj.y;
				function mv(ev) {
					obj.x = Math.max(0, Math.min(100, ox + (ev.clientX - sx) / pr.width * 100));
					obj.y = Math.max(0, Math.min(100, oy + (ev.clientY - sy) / pr.height * 100));
					elem.style.left = obj.x + '%'; elem.style.top = obj.y + '%';
				}
				function up() {
					document.removeEventListener('mousemove', mv); document.removeEventListener('mouseup', up);
					if (kind === 'slot' && obj.break_border && tpl.knot && tpl.knot.enabled) { render(); }
				}
				document.addEventListener('mousemove', mv); document.addEventListener('mouseup', up);
			});
		});
	}
	function markSelected() {
		page.querySelectorAll('.sc-slot, .sc-zone').forEach(function (elem) { elem.classList.remove('is-sel'); });
		if (!sel) { return; }
		var list = sel.kind === 'slot' ? page.querySelectorAll('.sc-slot') : page.querySelectorAll('.sc-zone');
		if (list[sel.index]) { list[sel.index].classList.add('is-sel'); }
	}

	// ---- small DOM helpers ----
	function el(tag, cls, txt) { var e = document.createElement(tag); if (cls) { e.className = cls; } if (txt != null) { e.textContent = txt; } return e; }
	function field(label, control) { var f = el('label', 'sc-field'); f.appendChild(el('span', 'sc-field__label', label)); f.appendChild(control); return f; }
	function input(val, type, on) { var i = el('input', 'sc-input'); i.type = type || 'text'; i.value = val == null ? '' : val; i.addEventListener('input', function () { on(i.value); }); return i; }
	function select(opts, val, on) {
		var s = el('select', 'sc-input');
		opts.forEach(function (o) {
			var v = (o && o.value != null) ? o.value : o, lbl = (o && o.label != null) ? o.label : o;
			var op = el('option', null, lbl); op.value = v; if (v === val) { op.selected = true; } s.appendChild(op);
		});
		s.addEventListener('change', function () { on(s.value); });
		return s;
	}

	// Visual font picker: each option previews "Order of the ORK" in the font,
	// with the font name beneath in the UI font. Fixed-positioned menu so the
	// scrolling inspector panel doesn't clip it.
	var FONT_PREVIEW = 'Order of the ORK';
	function fontPicker(current, onPick) {
		var wrap = el('label', 'sc-field');
		wrap.appendChild(el('span', 'sc-field__label', 'Font'));
		var pick = el('div', 'sc-fontpick');
		var trigger = el('button', 'sc-fontpick__trigger'); trigger.type = 'button';
		var prev = el('span', 'sc-fontpick__prev', FONT_PREVIEW); prev.style.fontFamily = "'" + current + "'";
		trigger.appendChild(prev);
		trigger.appendChild(el('span', 'sc-fontpick__name', current + '  ▾'));
		var menu = el('div', 'sc-fontpick__menu');
		FONTS.forEach(function (f) {
			var opt = el('button', 'sc-fontpick__opt' + (f === current ? ' is-sel' : '')); opt.type = 'button';
			var p = el('span', 'sc-fontpick__prev', FONT_PREVIEW); p.style.fontFamily = "'" + f + "'";
			opt.appendChild(p);
			opt.appendChild(el('span', 'sc-fontpick__name', f));
			opt.onmousedown = function (e) { e.preventDefault(); onPick(f); };   // rebuild handles close
			menu.appendChild(opt);
		});
		var isOpen = false;
		function close() { menu.classList.remove('sc-fontpick__menu--open'); isOpen = false; }
		function open() {
			var r = trigger.getBoundingClientRect();
			menu.style.position = 'fixed';
			menu.style.left = r.left + 'px';
			menu.style.top = (r.bottom + 2) + 'px';
			menu.style.width = Math.max(r.width, 240) + 'px';
			menu.classList.add('sc-fontpick__menu--open'); isOpen = true;
			var sel = menu.querySelector('.is-sel'); if (sel) { sel.scrollIntoView({ block: 'nearest' }); }
		}
		trigger.onclick = function () { isOpen ? close() : open(); };
		document.addEventListener('click', function (e) { if (!pick.contains(e.target)) { close(); } });
		pick.appendChild(trigger); pick.appendChild(menu);
		wrap.appendChild(pick);
		return wrap;
	}

	// ---- inspector: Page ----
	function buildPage() {
		var box = document.getElementById('scPageProps'); box.innerHTML = '';
		box.appendChild(field('Orientation', select(['portrait', 'landscape'], tpl.orientation, function (v) { tpl.orientation = v; render(); })));
		box.appendChild(field('Background', select(['color', 'texture', 'image'], tpl.bg_type, function (v) { tpl.bg_type = v; buildPage(); render(); })));
		if (tpl.bg_type === 'color') {
			box.appendChild(field('Color', input(tpl.bg_value || '#ffffff', 'color', function (v) { tpl.bg_value = v; render(); })));
		} else if (tpl.bg_type === 'texture') {
			box.appendChild(field('Texture', groupedPicker('backgrounds', tpl.bg_value,
				function (a) { tpl.bg_value = baseName(a.file); render(); buildPage(); }, buildPage)));
		} else {
			box.appendChild(field('Image', input(tpl.bg_value, 'text', function (v) { tpl.bg_value = v; render(); })));
		}
	}

	// ---- inspector: Border (knotwork) ----
	function knotCfg() {
		if (!tpl.knot) { tpl.knot = { enabled: false }; }
		return tpl.knot;
	}
	function checkbox(labelText, val, on) {
		var wrap = el('label', 'sc-check');
		var c = el('input'); c.type = 'checkbox'; c.checked = !!val;
		c.addEventListener('change', function () { on(c.checked); });
		wrap.appendChild(c); wrap.appendChild(el('span', null, labelText));
		return wrap;
	}
	function slider(labelText, val, min, max, step, on) {
		var wrap = el('label', 'sc-field');
		wrap.appendChild(el('span', 'sc-field__label', labelText));
		var i = el('input', 'sc-input'); i.type = 'range'; i.min = min; i.max = max; i.step = step; i.value = val;
		i.addEventListener('input', function () { on(+i.value); });
		wrap.appendChild(i);
		return wrap;
	}
	function buildKnot() {
		var box = document.getElementById('scKnot'); if (!box) { return; }
		box.innerHTML = '';
		if (!window.ScrollKnot) { box.appendChild(el('p', 'sc-empty', 'Border engine failed to load.')); return; }
		var k = knotCfg();
		// presets
		var pr = el('div', 'sc-chips');
		Object.keys(KNOT_PRESETS).forEach(function (name) {
			var b = el('button', 'sc-chip', name); b.type = 'button';
			b.onclick = function () { tpl.knot = JSON.parse(JSON.stringify(KNOT_PRESETS[name])); render(); buildKnot(); };
			pr.appendChild(b);
		});
		box.appendChild(field('Presets', pr));
		box.appendChild(checkbox('Knotwork border', k.enabled, function (v) { k.enabled = v; render(); buildKnot(); }));
		if (!k.enabled) { return; }
		// normalize once so sub-objects exist for editing
		var full = window.ScrollKnot._geom.norm(k);
		['pattern', 'band', 'strands', 'colors', 'gradient', 'corners', 'breaks', 'autoBreak'].forEach(function (key) {
			if (k[key] == null) { k[key] = full[key]; }
		});
		k.enabled = true;
		// pattern thumbnails
		var pats = el('div', 'sc-knot-pats');
		KNOT_PATTERNS.forEach(function (p) {
			var b = el('button', 'sc-knot-pat' + (k.pattern === p ? ' is-sel' : '')); b.type = 'button'; b.setAttribute('data-tip', p);
			var cfg = JSON.parse(JSON.stringify(k)); cfg.pattern = p;
			b.appendChild(window.ScrollKnot.swatch(cfg, 150, 34));
			b.onclick = function () { k.pattern = p; render(); buildKnot(); };
			pats.appendChild(b);
		});
		box.appendChild(field('Pattern', pats));
		var row1 = el('div', 'sc-row');
		row1.appendChild(slider('Inset', k.band.inset, 0.5, 6, 0.1, function (v) { k.band.inset = v; render(); }));
		row1.appendChild(slider('Width', k.band.width, 3, 10, 0.1, function (v) { k.band.width = v; render(); }));
		box.appendChild(row1);
		var row2 = el('div', 'sc-row');
		row2.appendChild(slider('Strands', k.strands.count, 2, 4, 1, function (v) { k.strands.count = v; render(); buildKnot(); }));
		row2.appendChild(slider('Thickness', k.strands.thickness, 0.3, 0.9, 0.05, function (v) { k.strands.thickness = v; render(); }));
		box.appendChild(row2);
		var row3 = el('div', 'sc-row');
		row3.appendChild(slider('Density', k.strands.scale, 0.6, 1.8, 0.05, function (v) { k.strands.scale = v; render(); }));
		box.appendChild(row3);
		// strand colors
		var cc = el('div', 'sc-chips');
		k.colors.strands.forEach(function (hex, i) {
			var swatchWrap = el('span', 'sc-knot-color');
			var ci = el('input'); ci.type = 'color'; ci.value = hex;
			ci.addEventListener('input', function () { k.colors.strands[i] = ci.value || hex; render(); });
			swatchWrap.appendChild(ci);
			if (k.colors.strands.length > 1) {
				var x = el('button', 'sc-knot-color__del', '×'); x.type = 'button'; x.setAttribute('data-tip', 'Remove color');
				x.onclick = function () { k.colors.strands.splice(i, 1); render(); buildKnot(); };
				swatchWrap.appendChild(x);
			}
			cc.appendChild(swatchWrap);
		});
		if (k.colors.strands.length < 4) {
			var add = el('button', 'sc-chip', '+'); add.type = 'button'; add.setAttribute('data-tip', 'Add strand color');
			add.onclick = function () { k.colors.strands.push('#888888'); render(); buildKnot(); };
			cc.appendChild(add);
		}
		box.appendChild(field('Strand colors', cc));
		box.appendChild(field('Outline', input(k.colors.outline || '#1a1a1a', 'color', function (v) { k.colors.outline = v || '#1a1a1a'; render(); })));
		// gradient
		box.appendChild(checkbox('Gradient tint', k.gradient.enabled, function (v) { k.gradient.enabled = v; render(); buildKnot(); }));
		if (k.gradient.enabled) {
			box.appendChild(slider('Angle', k.gradient.angle, 0, 360, 5, function (v) { k.gradient.angle = v; render(); }));
			var gs = el('div', 'sc-chips');
			k.gradient.stops.forEach(function (st, i) {
				var gi = el('input'); gi.type = 'color'; gi.value = st.color;
				gi.addEventListener('input', function () { st.color = gi.value || st.color; render(); });
				gs.appendChild(gi);
			});
			box.appendChild(field('Gradient colors', gs));
		}
		box.appendChild(field('Corners', select(['woven', 'hook'], k.corners, function (v) { k.corners = v; render(); })));
		// manual breaks
		var brBox = el('div');
		k.breaks.forEach(function (b, i) {
			var row = el('div', 'sc-knot-feat');
			row.appendChild(field('Edge', select(['top', 'bottom', 'left', 'right'], b.edge, function (v) { b.edge = v; render(); })));
			row.appendChild(slider('Position', b.at, 0, 100, 1, function (v) { b.at = v; render(); }));
			row.appendChild(slider('Width', b.width, 4, 60, 1, function (v) { b.width = v; render(); }));
			var del = el('button', 'sc-chip', 'Remove'); del.type = 'button';
			del.onclick = function () { k.breaks.splice(i, 1); render(); buildKnot(); };
			row.appendChild(del);
			brBox.appendChild(row);
		});
		var addBr = el('button', 'sc-chip', '+ Break'); addBr.type = 'button';
		addBr.onclick = function () { k.breaks.push({ edge: 'bottom', at: 50, width: 20 }); render(); buildKnot(); };
		brBox.appendChild(addBr);
		box.appendChild(field('Breaks', brBox));
		box.appendChild(checkbox('Art can break the border', k.autoBreak.enabled, function (v) { k.autoBreak.enabled = v; render(); }));
	}

	// ---- inspector: Elements list ----
	function buildElements() {
		var box = document.getElementById('scElements'); box.innerHTML = '';
		if (!tpl.zones.length && !tpl.slots.length) {
			box.appendChild(el('p', 'sc-empty', 'Nothing on the page yet. Add a text zone or graphic slot above.'));
			return;
		}
		tpl.zones.forEach(function (z, i) { box.appendChild(elemRow('zone', i, 'Text', z.text || '(empty)')); });
		tpl.slots.forEach(function (s, i) { box.appendChild(elemRow('slot', i, 'Graphic', s.location.replace(/_/g, ' '))); });
	}
	function elemRow(kind, i, tag, desc) {
		var row = el('div', 'sc-el' + (sel && sel.kind === kind && sel.index === i ? ' is-sel' : ''));
		var pick = el('button', 'sc-el__pick'); pick.type = 'button';
		pick.appendChild(el('span', 'sc-el__tag', tag));
		pick.appendChild(el('span', 'sc-el__desc', desc));
		pick.onclick = function () { sel = { kind: kind, index: i }; refreshInspector(); };
		var del = el('button', 'sc-el__del', '×'); del.type = 'button'; del.setAttribute('data-tip', 'Delete');
		del.onclick = function (e) {
			e.stopPropagation();
			(kind === 'zone' ? tpl.zones : tpl.slots).splice(i, 1);
			if (sel && sel.kind === kind && sel.index === i) { sel = null; }
			render(); refreshInspector();
		};
		row.appendChild(pick); row.appendChild(del); return row;
	}

	// ---- inspector: Selected element editor ----
	function buildSelected() {
		var head = document.getElementById('scSelectedHead');
		var box = document.getElementById('scSelected'); box.innerHTML = '';
		if (!sel) {
			head.textContent = 'Nothing selected';
			box.appendChild(el('p', 'sc-empty', 'Pick an element above (or click one on the page) to edit it. Drag it on the page to move it.'));
			lastSelKey = null;
			return;
		}
		if (sel.kind === 'zone') {
			lastSelKey = 'zone' + sel.index;
			head.textContent = 'Text zone';
			var z = tpl.zones[sel.index];
			var ta = el('textarea', 'sc-input'); ta.rows = 3; ta.value = z.text || '';
			ta.addEventListener('input', function () { z.text = ta.value; render(); buildElements(); });
			box.appendChild(field('Text', ta));
			var chips = el('div', 'sc-chips');
			TOKENS.forEach(function (tk) {
				var c = el('button', 'sc-chip', '{' + tk + '}'); c.type = 'button';
				c.onclick = function () { z.text = (z.text || '') + '{' + tk + '}'; ta.value = z.text; render(); buildElements(); };
				chips.appendChild(c);
			});
			box.appendChild(field('Insert', chips));
			box.appendChild(fontPicker(z.font, function (v) { z.font = v; render(); buildSelected(); }));
			var row = el('div', 'sc-row');
			row.appendChild(field('Size', input(z.size, 'number', function (v) { z.size = +v || z.size; render(); })));
			row.appendChild(field('Align', select(['left', 'center', 'right'], z.align, function (v) { z.align = v; render(); })));
			box.appendChild(row);
			box.appendChild(field('Color', input(z.color || '#1a1a1a', 'color', function (v) { z.color = v; z.inherit_color = false; render(); })));
		} else {
			head.textContent = 'Graphic slot';
			var s = tpl.slots[sel.index];
			var coll = collectionForPlacement(s.location);
			// only re-default the active type when this is a NEW slot/placement, so a
			// later type-chip click (same slot) is not overridden by the selected art's group.
			var selKey = 'slot' + sel.index + ':' + s.location;
			if (selKey !== lastSelKey) { delete groupState[coll]; lastSelKey = selKey; }
			box.appendChild(field('Placement', select(LOCATIONS.map(function (l) { return { value: l, label: l.replace(/_/g, ' ') }; }), s.location, function (v) {
				s.location = v; var r = rectFor(v); s.x = r.x; s.y = r.y; s.w = r.w; s.h = r.h; render(); buildElements(); buildSelected();
			})));
			box.appendChild(field('Source', select(['pack', 'heraldry', 'none'], s.source_type, function (v) {
				s.source_type = v;
				if (v === 'heraldry' && !/^(kingdom|park|player)$/.test(s.source_ref)) { s.source_ref = 'kingdom'; }
				render(); buildSelected();
			})));
			box.appendChild(checkbox('Border yields to this art', !!s.break_border, function (v) {
				s.break_border = v; render();
			}));
			if (s.source_type === 'heraldry') {
				buildHeraldry(box, s);
			} else if (s.source_type === 'pack') {
				// side placements get only strip/bar art; full-border gets the rectangular frames
				var artFilter = null;
				if (coll === 'borders') {
					artFilter = /^border_/.test(s.location)
						? function (a) { return a.slot === 'border_side'; }
						: function (a) { return a.slot === 'full_border'; };
				}
				box.appendChild(field('Art', groupedPicker(coll, s.source_ref,
					function (a) { s.source_type = 'pack'; s.source_ref = a.file; render(); buildSelected(); }, buildSelected, artFilter)));
			}
		}
	}
	// grouped picker: a Type chip row (border styles / award types / bg tones) + a
	// thumbnail grid of the active type. Reused for graphic slots and bg textures.
	function groupedPicker(collection, currentFile, onPick, rebuild, itemFilter) {
		var items = (D.packCatalog || []).filter(function (a) { return a.collection === collection; });
		if (itemFilter) { items = items.filter(itemFilter); }   // e.g. side placements -> only strip art
		var wrap = el('div', 'sc-picker');
		wrap.appendChild(el('div', 'sc-collection', COLLECTION_LABELS[collection] || collection));
		if (!items.length) { wrap.appendChild(el('p', 'sc-empty', 'No art in this collection yet.')); return wrap; }
		var groups = orderedGroups(items);
		var cur = currentFile ? items.filter(function (a) { return a.file === currentFile || baseName(a.file) === baseName(currentFile); })[0] : null;
		var active = groupState[collection];            // an explicit type-chip choice always wins
		if (!active || groups.indexOf(active) < 0) { active = cur ? cur.group : groups[0]; }
		groupState[collection] = active;
		// type chips (only when there's more than one type to pick from)
		if (groups.length > 1) {
			var row = el('div', 'sc-type-row');
			groups.forEach(function (g) {
				var n = items.filter(function (a) { return a.group === g; }).length;
				var c = el('button', 'sc-type' + (g === active ? ' is-sel' : '')); c.type = 'button';
				c.appendChild(el('span', null, g)); c.appendChild(el('span', 'sc-type__n', String(n)));
				c.onclick = function () { groupState[collection] = g; rebuild(); };
				row.appendChild(c);
			});
			wrap.appendChild(row);
		}
		// grid of the active type
		var grid = el('div', 'sc-pack-grid');
		items.filter(function (a) { return a.group === active; }).forEach(function (a) {
			var t = el('button', 'sc-pack' + ((currentFile && a.file === currentFile) ? ' is-sel' : '')); t.type = 'button'; t.setAttribute('data-tip', a.name);
			var img = el('img'); img.src = D.packBase + a.file; img.alt = a.name; img.loading = 'lazy'; t.appendChild(img);
			t.onclick = function () { onPick(a); };
			grid.appendChild(t);
		});
		wrap.appendChild(grid);
		return wrap;
	}

	// ================= heraldry pickers (dynamic recipient + specific entity) =================
	var heraldryKingdomsCache = null;
	var acTimer = null;
	function heraldryUrl(path) { return (D.uir || '') + path; }
	function scopeKid() { return D.kingdomId || 0; }

	// viewport-safe fixed positioning for an autocomplete dropdown inside the
	// scrolling inspector (absolute would be clipped by the panel's overflow).
	function tnFixedAcPosition(input, dd) {
		var r = input.getBoundingClientRect();
		dd.style.position = 'fixed';
		dd.style.left = r.left + 'px';
		dd.style.top = (r.bottom + 2) + 'px';
		dd.style.width = r.width + 'px';
	}

	function buildHeraldry(box, s) {
		var isRole = (s.source_ref === 'kingdom' || s.source_ref === 'park' || s.source_ref === 'player');
		var mode = isRole ? s.source_ref : ('pick_' + (s.heraldry_kind || 'kingdom'));
		var opts = [
			{ value: 'kingdom', label: "Recipient's kingdom" },
			{ value: 'park', label: "Recipient's park" },
			{ value: 'player', label: "Recipient's player" },
			{ value: 'pick_kingdom', label: 'Pick a kingdom…' },
			{ value: 'pick_park', label: 'Pick a park…' },
			{ value: 'pick_player', label: 'Pick a player…' }
		];
		box.appendChild(field('Heraldry', select(opts, mode, function (v) {
			if (v === 'kingdom' || v === 'park' || v === 'player') {
				s.source_ref = v; delete s.heraldry_kind; delete s.heraldry_label;
			} else {
				s.heraldry_kind = v.replace('pick_', '');
				if (s.source_ref === 'kingdom' || s.source_ref === 'park' || s.source_ref === 'player') { s.source_ref = ''; }
			}
			render(); buildSelected();
		})));
		if (mode === 'pick_kingdom') { box.appendChild(heraldryKingdomPicker(s)); }
		else if (mode === 'pick_park') { box.appendChild(heraldryParkPicker(s)); }
		else if (mode === 'pick_player') { box.appendChild(heraldryPlayerPicker(s)); }
		if (s.heraldry_label && !isRole) { box.appendChild(el('p', 'sc-empty', 'Selected: ' + s.heraldry_label)); }
	}

	function heraldryKingdomPicker(s) {
		var wrap = el('label', 'sc-field');
		wrap.appendChild(el('span', 'sc-field__label', 'Kingdom'));
		var sel = el('select', 'sc-input'); sel.appendChild(new Option('Loading…', ''));
		wrap.appendChild(sel);
		function fill(list) {
			sel.innerHTML = ''; sel.appendChild(new Option('— select —', ''));
			list.forEach(function (k) { var o = new Option(k.name, k.url); if (k.url === s.source_ref) { o.selected = true; } sel.appendChild(o); });
			sel.onchange = function () {
				s.source_ref = sel.value;
				s.heraldry_label = sel.value ? sel.options[sel.selectedIndex].textContent : '';
				render(); buildSelected();
			};
		}
		if (heraldryKingdomsCache) { fill(heraldryKingdomsCache); }
		else {
			fetch(heraldryUrl('ScrollTemplateAjax/heraldrykingdoms&kingdom_id=' + scopeKid()), { credentials: 'same-origin' })
				.then(function (r) { return r.json(); })
				.then(function (j) { heraldryKingdomsCache = j.Kingdoms || []; fill(heraldryKingdomsCache); })
				.catch(function () { sel.innerHTML = ''; sel.appendChild(new Option('(failed to load)', '')); });
		}
		return wrap;
	}

	function heraldryParkPicker(s) {
		return heraldryAutocomplete('Park', s.heraldry_label, function (q, cb) {
			fetch(heraldryUrl('ScrollTemplateAjax/heraldryparks&kingdom_id=' + scopeKid() + '&q=' + encodeURIComponent(q)), { credentials: 'same-origin' })
				.then(function (r) { return r.json(); })
				.then(function (j) { cb((j.Parks || []).map(function (p) { return { label: p.name, sub: p.kingdom, data: { url: p.url, name: p.name } }; })); })
				.catch(function () { cb([]); });
		}, function (item) { s.source_ref = item.data.url; s.heraldry_label = item.data.name; render(); buildSelected(); });
	}

	function heraldryPlayerPicker(s) {
		var scope = scopeKid() > 0 ? 'own' : 'all';
		return heraldryAutocomplete('Player', s.heraldry_label, function (q, cb) {
			fetch(heraldryUrl('KingdomAjax/playersearch/' + scopeKid() + '&scope=' + scope + '&q=' + encodeURIComponent(q)), { credentials: 'same-origin' })
				.then(function (r) { return r.json(); })
				.then(function (data) { cb((data || []).map(function (p) { return { label: p.Persona, sub: (p.KAbbr || '') + (p.PAbbr ? ':' + p.PAbbr : ''), data: { id: p.MundaneId, name: p.Persona } }; })); })
				.catch(function () { cb([]); });
		}, function (item) {
			fetch(heraldryUrl('ScrollTemplateAjax/heraldryresolve&type=player&eid=' + item.data.id), { credentials: 'same-origin' })
				.then(function (r) { return r.json(); })
				.then(function (j) { s.source_ref = j.Url || ''; s.heraldry_label = item.data.name; render(); buildSelected(); });
		});
	}

	// input + kn-ac-results dropdown; fetchFn(q, cb) -> cb([{label,sub,data}]); onPick(item)
	function heraldryAutocomplete(labelText, currentLabel, fetchFn, onPick) {
		var wrap = el('label', 'sc-field');
		wrap.appendChild(el('span', 'sc-field__label', labelText));
		var ic = el('div', 'sc-ac');
		var input = el('input', 'sc-input'); input.type = 'text'; input.placeholder = 'Search…'; input.value = currentLabel || '';
		var dd = el('div', 'kn-ac-results');
		ic.appendChild(input); ic.appendChild(dd); wrap.appendChild(ic);
		function close() { dd.classList.remove('kn-ac-open'); }
		input.addEventListener('input', function () {
			clearTimeout(acTimer);
			var q = input.value.trim();
			if (q.length < 2) { close(); return; }
			acTimer = setTimeout(function () {
				fetchFn(q, function (items) {
					dd.innerHTML = '';
					if (!items.length) { dd.appendChild(el('div', 'kn-ac-none', 'No matches')); }
					else {
						items.forEach(function (it) {
							var rowEl = el('div', 'kn-ac-item');
							rowEl.appendChild(el('span', null, it.label));
							if (it.sub) { rowEl.appendChild(el('span', 'kn-ac-sub', ' ' + it.sub)); }
							rowEl.onmousedown = function (e) { e.preventDefault(); input.value = it.label; close(); onPick(it); };
							dd.appendChild(rowEl);
						});
					}
					tnFixedAcPosition(input, dd);
					dd.classList.add('kn-ac-open');
				});
			}, 220);
		});
		input.addEventListener('blur', function () { setTimeout(close, 150); });
		return wrap;
	}

	// ---- inspector: "For awards" tags (which ladder awards this template is for) ----
	function buildAwardTags() {
		var box = document.getElementById('scAwardTags'); box.innerHTML = '';
		var awards = D.ladderAwards || [];
		if (!awards.length) { box.appendChild(el('p', 'sc-empty', 'No ladder awards available.')); return; }
		box.appendChild(el('p', 'sc-hint', 'Tag the awards this template is for. When someone grants a tagged award, this template is offered first; untagged templates stay available for any award.'));
		var row = el('div', 'sc-chips');
		awards.forEach(function (a) {
			var id = Number(a.AwardId);
			var on = tpl.award_keys.indexOf(id) >= 0;
			var c = el('button', 'sc-tag' + (on ? ' is-sel' : ''), a.AwardName); c.type = 'button';
			c.onclick = function () {
				var i = tpl.award_keys.indexOf(id);
				if (i >= 0) { tpl.award_keys.splice(i, 1); } else { tpl.award_keys.push(id); }
				buildAwardTags();
			};
			row.appendChild(c);
		});
		box.appendChild(row);
	}

	function refreshInspector() { buildElements(); buildSelected(); markSelected(); }

	// ---- toolbar actions ----
	document.getElementById('scAddZone').onclick = function () {
		tpl.zones.push({ key: 'zone' + tpl.zones.length, label: 'Text', text: '{PlayerName}', font: 'Cinzel', size: 40, min: 12, max: 56, align: 'center', color: '#1a1a1a', inherit_color: false, x: 18, y: 40, w: 64, h: 12, autoscale: true });
		sel = { kind: 'zone', index: tpl.zones.length - 1 };
		render(); refreshInspector();
	};
	document.getElementById('scAddSlot').onclick = function () {
		var r = rectFor('center_image');
		tpl.slots.push({ location: 'center_image', x: r.x, y: r.y, w: r.w, h: r.h, source_type: 'pack', source_ref: '', fit: 'contain' });
		sel = { kind: 'slot', index: tpl.slots.length - 1 };
		render(); refreshInspector();
	};
	document.getElementById('scSave').onclick = function () {
		tpl.name = document.getElementById('scTplName').value || tpl.name;
		if (!tpl.name.trim()) { scToast('Name the template before saving.', 'warn'); return; }
		fetch(D.saveUrl, {
			method: 'POST', headers: { 'Content-Type': 'application/json' }, credentials: 'same-origin',
			body: JSON.stringify(Object.assign({ id: tpl.scroll_template_id || 0, kingdom_id: D.kingdomId, token: D.token }, tpl))
		})
			.then(function (r) { return r.json(); })
			.then(function (j) {
				if (j.Status === 0) { tpl.scroll_template_id = j.TemplateId; scToast('Template saved.'); }
				else { scToast(j.Message || 'Save failed.', 'warn'); }
			})
			.catch(function () { scToast('Save failed.', 'warn'); });
	};

	// ---- boot ----
	buildPage(); buildAwardTags(); buildKnot(); render(); refreshInspector();
})();
