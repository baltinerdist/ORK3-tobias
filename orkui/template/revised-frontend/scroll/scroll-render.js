/* scroll-render.js — render a slot-based scroll template into a fixed Letter page. */
(function (w) {
	function resolveTokens(text, map) {
		return String(text == null ? '' : text).replace(/\{([A-Za-z][A-Za-z0-9]*)\}/g, function (m, k) {
			return Object.prototype.hasOwnProperty.call(map || {}, k) ? map[k] : m;
		});
	}
	function slotSrc(slot, ctx) {
		if (slot.source_type === 'pack')     return slot.source_ref ? ctx.packBase + slot.source_ref : '';
		if (slot.source_type === 'library')  return slot.source_ref ? ctx.libBase + encodeURIComponent(slot.source_ref) : '';
		if (slot.source_type === 'heraldry') {
			// role keyword (kingdom|park|player) = recipient's arms, resolved at fill;
			// anything else is a specific entity's heraldry URL baked into the template.
			if (slot.source_ref === 'kingdom' || slot.source_ref === 'park' || slot.source_ref === 'player') {
				return (ctx.heraldry && ctx.heraldry[slot.source_ref]) || '';
			}
			return slot.source_ref || '';
		}
		return '';
	}
	function pct(v) { return (Number(v) || 0) + '%'; }
	// A rotated (top/bottom) strip: give the img the slot's SWAPPED px dims so that after a
	// 90deg rotation (in CSS) it fills the horizontal bar. Uses layout px (page is fixed-width),
	// so it also renders correctly under html2canvas for the PDF.
	function sizeRot90(slotEl) {
		var img = slotEl.querySelector('img'); if (!img) { return; }
		var w = slotEl.clientWidth, h = slotEl.clientHeight;
		if (!w || !h) { return; }
		img.style.width = h + 'px'; img.style.height = w + 'px';
	}

	function renderPage(pageEl, tpl, opts) {
		opts = opts || {}; var tokens = opts.tokens || {};
		pageEl.setAttribute('data-orientation', tpl.orientation || 'portrait');
		pageEl.innerHTML = '';
		// background
		var bg = document.createElement('div');
		bg.className = 'sc-bg'; bg.setAttribute('data-bg-type', tpl.bg_type || 'color');
		if (tpl.bg_type === 'color') {
			bg.style.background = tpl.bg_value || '#ffffff';
		} else if (tpl.bg_type === 'texture' || tpl.bg_type === 'image') {
			var url = (tpl.bg_type === 'texture')
				? opts.packBase + 'backgrounds/' + tpl.bg_value
				: opts.libBase + encodeURIComponent(tpl.bg_value);
			bg.style.backgroundImage = 'url(' + url + ')';
			bg.style.backgroundPosition = 'center';
			// fit: tile (repeat), fill (cover), stretch (100% x 100%). Empty/unknown falls back
			// to the historical per-type default (texture tiled, single image covered).
			var fit = (['tile', 'fill', 'stretch'].indexOf(tpl.bg_fit) >= 0)
				? tpl.bg_fit
				: (tpl.bg_type === 'texture' ? 'tile' : 'fill');
			if (fit === 'tile') { bg.style.backgroundRepeat = 'repeat'; bg.style.backgroundSize = 'auto'; }
			else if (fit === 'stretch') { bg.style.backgroundRepeat = 'no-repeat'; bg.style.backgroundSize = '100% 100%'; }
			else { bg.style.backgroundRepeat = 'no-repeat'; bg.style.backgroundSize = 'cover'; }
		}
		// opacity: 0-100 (%). Default 100 (fully opaque); lower fades the background toward the
		// white page beneath -- a watermark effect for images, a lighter tint for a solid color.
		var op = (tpl.bg_opacity == null || isNaN(+tpl.bg_opacity)) ? 100 : Math.max(0, Math.min(100, +tpl.bg_opacity));
		if (op < 100) { bg.style.opacity = (op / 100).toFixed(3); }
		pageEl.appendChild(bg);
		// knotwork border layer (parametric, drawn between bg and slots)
		if (tpl.knot && tpl.knot.enabled && w.ScrollKnot) {
			var kd = (tpl.orientation === 'landscape') ? [1056, 816] : [816, 1056];
			pageEl.appendChild(w.ScrollKnot.render(tpl.knot, kd[0], kd[1], tpl.slots || []));
		}
		// slots
		(tpl.slots || []).forEach(function (s) {
			var el = document.createElement('div');
			el.className = 'sc-slot'; el.setAttribute('data-location', s.location); el.setAttribute('data-fit', s.fit || 'contain');
			el.style.left = pct(s.x); el.style.top = pct(s.y); el.style.width = pct(s.w); el.style.height = pct(s.h);
			// top/bottom borders use the vertical strip art turned on its side
			var rot90 = (s.location === 'border_top' || s.location === 'border_bottom');
			if (rot90) { el.classList.add('sc-slot--rot90'); }
			var src = slotSrc(s, opts);
			var heraldryRole = (s.source_type === 'heraldry' && /^(kingdom|park|player)$/.test(s.source_ref)) ? s.source_ref : '';
			if (src) { var img = document.createElement('img'); img.src = src; img.alt = ''; el.appendChild(img); }
			else if (opts.editable && heraldryRole) {
				// heraldry placeholder: autopopulates with the recipient's kingdom/park/player
				// arms at generation. On the design surface the park/player arms aren't known,
				// so a labeled shield placeholder marks where they'll land (editor-only).
				el.classList.add('sc-slot--empty', 'sc-slot--heraldry');
				var hl = { kingdom: 'Kingdom heraldry', park: 'Park heraldry', player: 'Player heraldry' };
				var hp = document.createElement('span');
				hp.className = 'sc-slot__ph';
				hp.innerHTML = '<i class="fa fa-shield-alt"></i> ' + hl[heraldryRole];
				el.appendChild(hp);
			}
			else if (opts.editable) {
				// designer-only placeholder: an empty slot is otherwise a near-invisible
				// 1px outline on white paper (never rendered in filler/PDF -- not editable)
				el.classList.add('sc-slot--empty');
				var ph = document.createElement('span');
				ph.className = 'sc-slot__ph';
				ph.innerHTML = '<i class="fa fa-image"></i> Empty slot';
				el.appendChild(ph);
			}
			el.__slot = s; pageEl.appendChild(el);
			// size the rotated image in real px (swapped) so it fills the bar after rotation,
			// which also survives html2canvas/PDF (container-query units would not).
			if (rot90 && src) { sizeRot90(el); }
		});
		// zones
		(tpl.zones || []).forEach(function (z) {
			var el = document.createElement('div');
			el.className = 'sc-zone'; el.setAttribute('data-key', z.key); el.setAttribute('data-align', z.align || 'center');
			if (z.autoscale) el.setAttribute('data-autoscale', '1');
			el.style.left = pct(z.x); el.style.top = pct(z.y); el.style.width = pct(z.w); el.style.height = pct(z.h);
			el.style.fontFamily = "'" + (z.font || 'EB Garamond') + "'";
			el.style.fontSize = (z.size || 24) + 'px';
			if (!z.inherit_color && z.color) el.style.color = z.color;
			el.dataset.min = z.min || 8; el.dataset.max = z.max || (z.size || 24);
			// token fill
			var filled = resolveTokens(z.text, tokens);
			if (opts.editable) {
				el.innerHTML = String(z.text || '').replace(/\{([A-Za-z][A-Za-z0-9]*)\}/g, function (m, k) {
					return Object.prototype.hasOwnProperty.call(tokens, k)
						? tokens[k]
						: '<span class="sc-token-unfilled">' + m + '</span>';
				}).replace(/\n/g, '<br>');
			} else {
				el.textContent = filled;
			}
			el.__zone = z; pageEl.appendChild(el);
		});
		// re-size rotated strips once layout has settled (guards a 0-width first paint)
		setTimeout(function () { pageEl.querySelectorAll('.sc-slot--rot90').forEach(sizeRot90); }, 0);
	}

	function autoscaleZones(pageEl) {
		pageEl.querySelectorAll('.sc-zone[data-autoscale]').forEach(function (el) {
			var min = parseFloat(el.dataset.min) || 8, max = parseFloat(el.dataset.max) || 24, size = max;
			el.style.fontSize = size + 'px';
			var guard = 0;
			while (size > min && (el.scrollHeight > el.clientHeight + 1 || el.scrollWidth > el.clientWidth + 1) && guard++ < 200) {
				size -= 1; el.style.fontSize = size + 'px';
			}
		});
	}

	// Scale the page to fit the stage in BOTH dimensions so the preview never needs its own
	// scrollbar. Two modes:
	//  - bounded (stage has class 'sc-stage--bounded'): the stage's height is controlled by an
	//    external layout (the designer grid sizes it to the free viewport height), so we fit the
	//    page into the stage's current content box and DON'T touch its height.
	//  - unbounded (filler): the height budget is measured from the stage's top to the viewport
	//    bottom, and the stage height is pinned to the scaled page so it reserves no extra space.
	function fitToStage(pageEl, stageEl) {
		function apply() {
			pageEl.style.transform = 'scale(1)';
			var cs = w.getComputedStyle(stageEl);
			var vChrome = (parseFloat(cs.paddingTop) || 0) + (parseFloat(cs.paddingBottom) || 0);
			var hChrome = (parseFloat(cs.paddingLeft) || 0) + (parseFloat(cs.paddingRight) || 0);
			var r = pageEl.getBoundingClientRect();                 // natural size at scale(1)
			var bounded = stageEl.classList.contains('sc-stage--bounded');
			var availW = stageEl.clientWidth - hChrome;
			var availH;
			if (bounded) {
				availH = stageEl.clientHeight - vChrome;
			} else {
				var stageTop = stageEl.getBoundingClientRect().top;
				availH = (w.innerHeight || document.documentElement.clientHeight) - stageTop - vChrome - 8;
			}
			var k = Math.min(availW / r.width, availH / r.height, 1);
			if (!isFinite(k) || k <= 0) { k = 1; }
			pageEl.style.transform = 'scale(' + k + ')';
			if (!bounded) { stageEl.style.height = Math.ceil(r.height * k + vChrome) + 'px'; }
		}
		requestAnimationFrame(apply);
		setTimeout(apply, 60);           // rAF is paused in background tabs — always pair with a timeout
	}

	w.ScrollRender = { renderPage: renderPage, resolveTokens: resolveTokens, autoscaleZones: autoscaleZones, fitToStage: fitToStage, slotSrc: slotSrc };
})(window);
