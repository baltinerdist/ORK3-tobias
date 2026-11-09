/* scroll-border.js — the template designer's knotwork border.
 *
 * Draws Scrollery's Custom Border knots (Scroll::KNOT_STYLES, the sprites that
 * tools/knot-match exports on feature/knot-tools) on a slot-template page, in the
 * template's two colours. It replaces the old parametric engine (scroll-knot.js).
 *
 * Config, as saved in ork_scroll_template.knot:
 *   { enabled: bool, style: 1-4, color1: '#rrggbb', color2: '#rrggbb' }
 * A config saved by the old engine (pattern/strands/colors…) still loads: it becomes
 * style 1 in its first two strand colours.
 *
 * window.SC_KNOT (set by the page, from Controller_Scroll) gives the asset base, the
 * style list and the default colours.
 *
 * The sprites are 2550x3300 portrait. A landscape page draws them turned 90 degrees.
 * Every <svg> this returns is SELF-CONTAINED — the symbol geometry is copied in and
 * var(--knot-c1/c2) replaced with literal colours — because html2canvas rasterises an
 * inline SVG on its own, where neither a <use> into the page nor a custom property
 * would resolve, and the PDF would print a blank or white border.
 *
 * A slot flagged break_border cuts a hole in the border around itself (an SVG mask).
 */
(function (w) {
	'use strict';
	var NS = 'http://www.w3.org/2000/svg';
	var CFG = w.SC_KNOT || { base: '', styles: {}, defaults: { color1: '#6AC1FF', color2: '#E84C92' } };
	var HEX = /^#[0-9a-f]{6}$/i;
	var BREAK_PAD = 1;          // percent of the page width kept clear around broken-out art
	var loaded = {};            // style key -> { band1, band2 } markup
	var pending = {};           // style key -> Promise
	var maskSeq = 0;

	function styleKey(s) {
		var k = String(parseInt(s, 10) || 1);
		return CFG.styles && CFG.styles[k] ? k : '1';
	}
	function colour(v, fallback) { return HEX.test(v || '') ? v : fallback; }

	/** The config the renderer draws from, whatever shape was saved. */
	function normalize(k) {
		k = k || {};
		var d = CFG.defaults || {};
		var legacy = (k.colors && k.colors.strands) || [];
		return {
			enabled: !!k.enabled,
			style: parseInt(styleKey(k.style), 10),
			color1: colour(k.color1, colour(legacy[0], d.color1 || '#6AC1FF')),
			color2: colour(k.color2, colour(legacy[1] || legacy[0], d.color2 || '#E84C92'))
		};
	}

	function load(style) {
		var key = styleKey(style);
		if (loaded[key]) { return Promise.resolve(loaded[key]); }
		if (!pending[key]) {
			var def = CFG.styles[key];
			pending[key] = fetch(CFG.base + def.sprite, { credentials: 'same-origin' })
				.then(function (r) { if (!r.ok) { throw new Error('knot sprite ' + r.status); } return r.text(); })
				.then(function (txt) {
					// The sprites' header comments mention "--knot-c1", and "--" inside a
					// comment is not well-formed XML, so drop comments before parsing (as
					// Scrollery's _knot_defs.tpl does).
					var doc = new DOMParser().parseFromString(txt.replace(/<!--[\s\S]*?-->/g, ''), 'image/svg+xml');
					if (doc.querySelector('parsererror')) { throw new Error('knot sprite did not parse'); }
					function band(n) {
						var sym = doc.querySelector('[id="' + def.symbol + '-Band-' + n + '"]');
						return sym ? new XMLSerializer().serializeToString(sym).replace(/^<symbol[^>]*>|<\/symbol>$/g, '') : '';
					}
					loaded[key] = { band1: band(1), band2: band(2) };
					return loaded[key];
				})
				.catch(function (e) { delete pending[key]; throw e; });
		}
		return pending[key];
	}

	function paint(svg, bands, k, land, slots) {
		var W = land ? 3300 : 2550, H = land ? 2550 : 3300;
		var body = (bands.band1 + bands.band2)
			.split('var(--knot-c1)').join(k.color1)
			.split('var(--knot-c2)').join(k.color2);
		if (land) { body = '<g transform="translate(3300 0) rotate(90)">' + body + '</g>'; }
		var holes = (slots || []).filter(function (s) { return s && s.break_border; });
		if (holes.length) {
			var id = 'sc-knot-mask-' + (++maskSeq), pad = BREAK_PAD / 100 * W, rects = '';
			holes.forEach(function (s) {
				var x = (+s.x || 0) / 100 * W - pad, y = (+s.y || 0) / 100 * H - pad;
				var rw = (+s.w || 0) / 100 * W + 2 * pad, rh = (+s.h || 0) / 100 * H + 2 * pad;
				rects += '<rect x="' + x.toFixed(1) + '" y="' + y.toFixed(1) + '" width="' + rw.toFixed(1) + '" height="' + rh.toFixed(1) + '" fill="#000"/>';
			});
			body = '<defs><mask id="' + id + '" maskUnits="userSpaceOnUse" x="0" y="0" width="' + W + '" height="' + H + '">'
				+ '<rect width="' + W + '" height="' + H + '" fill="#fff"/>' + rects + '</mask></defs>'
				+ '<g mask="url(#' + id + ')">' + body + '</g>';
		}
		svg.innerHTML = body;
		svg.setAttribute('data-ready', '1');
	}

	/**
	 * A full-page border layer for a template. Synchronous: when the style's sprite is
	 * not cached yet the layer is returned empty and fills itself when it arrives.
	 */
	function render(cfg, orientation, slots) {
		var k = normalize(cfg), land = orientation === 'landscape';
		var svg = document.createElementNS(NS, 'svg');
		svg.setAttribute('class', 'sc-knot');
		svg.setAttribute('viewBox', land ? '0 0 3300 2550' : '0 0 2550 3300');
		svg.setAttribute('aria-hidden', 'true');
		svg.setAttribute('focusable', 'false');
		var key = styleKey(k.style);
		if (loaded[key]) { paint(svg, loaded[key], k, land, slots); }
		else {
			load(key).then(function (b) { paint(svg, b, k, land, slots); })
				.catch(function () { svg.setAttribute('data-ready', 'error'); });
		}
		return svg;
	}

	/** Resolves once every border layer inside root has drawn (or failed) — await before rasterising. */
	function ready(root) {
		var layers = Array.prototype.slice.call((root || document).querySelectorAll('svg.sc-knot'));
		return Promise.all(Object.keys(pending).map(function (key) { return pending[key].catch(function () {}); }))
			.then(function () {
				// paint() runs in the same microtask chain as the load; one more tick for safety
				return new Promise(function (res) { setTimeout(res, 0); });
			})
			.then(function () { return layers; });
	}

	w.ScrollBorder = { render: render, normalize: normalize, load: load, ready: ready, styles: function () { return Object.keys(CFG.styles || {}); } };
})(window);
