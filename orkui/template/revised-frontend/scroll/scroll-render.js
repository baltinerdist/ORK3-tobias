/* scroll-render.js — render a slot-based scroll template into a fixed Letter page. */
(function (w) {
	function resolveTokens(text, map) {
		return String(text == null ? '' : text).replace(/\{([A-Za-z][A-Za-z0-9]*)\}/g, function (m, k) {
			return Object.prototype.hasOwnProperty.call(map || {}, k) ? map[k] : m;
		});
	}
	function slotSrc(slot, ctx) {
		if (slot.source_type === 'pack')     return ctx.packBase + slot.source_ref;
		if (slot.source_type === 'library')  return ctx.libBase + encodeURIComponent(slot.source_ref);
		if (slot.source_type === 'heraldry') return (ctx.heraldry && ctx.heraldry[slot.source_ref]) || '';
		return '';
	}
	function pct(v) { return (Number(v) || 0) + '%'; }

	function renderPage(pageEl, tpl, opts) {
		opts = opts || {}; var tokens = opts.tokens || {};
		pageEl.setAttribute('data-orientation', tpl.orientation || 'portrait');
		pageEl.innerHTML = '';
		// background
		var bg = document.createElement('div');
		bg.className = 'sc-bg'; bg.setAttribute('data-bg-type', tpl.bg_type || 'color');
		if (tpl.bg_type === 'color')        bg.style.background = tpl.bg_value || '#ffffff';
		else if (tpl.bg_type === 'texture') bg.style.backgroundImage = 'url(' + opts.packBase + 'backgrounds/' + tpl.bg_value + ')';
		else if (tpl.bg_type === 'image')   bg.style.backgroundImage = 'url(' + (opts.libBase + encodeURIComponent(tpl.bg_value)) + ')';
		pageEl.appendChild(bg);
		// slots
		(tpl.slots || []).forEach(function (s) {
			var el = document.createElement('div');
			el.className = 'sc-slot'; el.setAttribute('data-location', s.location); el.setAttribute('data-fit', s.fit || 'contain');
			el.style.left = pct(s.x); el.style.top = pct(s.y); el.style.width = pct(s.w); el.style.height = pct(s.h);
			var src = slotSrc(s, opts);
			if (src) { var img = document.createElement('img'); img.src = src; img.alt = ''; el.appendChild(img); }
			el.__slot = s; pageEl.appendChild(el);
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

	function fitToStage(pageEl, stageEl) {
		function apply() {
			pageEl.style.transform = 'scale(1)';
			var pad = 32;
			var r = pageEl.getBoundingClientRect();                 // natural size at scale(1)
			var k = Math.min((stageEl.clientWidth - pad) / r.width, (stageEl.clientHeight - pad) / r.height, 1);
			if (!isFinite(k) || k <= 0) k = 1;
			pageEl.style.transform = 'scale(' + k + ')';
			stageEl.style.height = Math.ceil(r.height * k + pad) + 'px';   // collapse scaled empty space
		}
		requestAnimationFrame(apply);
		setTimeout(apply, 60);           // rAF is paused in background tabs — always pair with a timeout
	}

	w.ScrollRender = { renderPage: renderPage, resolveTokens: resolveTokens, autoscaleZones: autoscaleZones, fitToStage: fitToStage, slotSrc: slotSrc };
})(window);
