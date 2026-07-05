/* scroll-knot.js — parametric Celtic knotwork border engine.
   Geometry core is DOM-free (unit-tested in Node); render()/swatch() build SVG.
   PDF-safe SVG subset only: paths + strokes + userSpaceOnUse linear gradients. */
(function (w) {
	'use strict';
	var SVGNS = 'http://www.w3.org/2000/svg';

	// ---------- small math ----------
	function clamp(v, a, b) { return v < a ? a : (v > b ? b : v); }
	function lerp(a, b, t) { return a + (b - a) * t; }
	function smooth(t) { t = clamp(t, 0, 1); return t * t * (3 - 2 * t); }
	function hexRgb(h) {
		h = String(h || '#000').replace('#', '');
		if (h.length === 3) { h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2]; }
		var v = parseInt(h, 16) || 0;
		return [(v >> 16) & 255, (v >> 8) & 255, v & 255];
	}
	function rgbHex(r, g, b) {
		function c(x) { x = clamp(Math.round(x), 0, 255).toString(16); return x.length < 2 ? '0' + x : x; }
		return '#' + c(r) + c(g) + c(b);
	}
	function blendHex(a, b, t) {
		var A = hexRgb(a), B = hexRgb(b);
		return rgbHex(lerp(A[0], B[0], t), lerp(A[1], B[1], t), lerp(A[2], B[2], t));
	}

	// ---------- config ----------
	function norm(cfg) {
		cfg = cfg || {};
		function o(v, d) { return (v == null) ? d : v; }
		var band = cfg.band || {}, st = cfg.strands || {}, co = cfg.colors || {}, gr = cfg.gradient || {}, ab = cfg.autoBreak || {};
		return {
			enabled: !!cfg.enabled,
			pattern: o(cfg.pattern, 'plait'),
			band: { inset: +o(band.inset, 2), width: +o(band.width, 6) },
			strands: { count: clamp(+o(st.count, 3), 1, 4), thickness: +o(st.thickness, 0.55), gap: +o(st.gap, 0.12), scale: +o(st.scale, 1) },
			colors: {
				strands: (Array.isArray(co.strands) && co.strands.length) ? co.strands.slice(0, 4) : ['#2e7d32', '#f4c542'],
				outline: o(co.outline, '#1a1a1a')
			},
			gradient: {
				enabled: !!gr.enabled, angle: +o(gr.angle, 90),
				stops: (Array.isArray(gr.stops) && gr.stops.length >= 2) ? gr.stops : [{ at: 0, color: '#c62828' }, { at: 1, color: '#f9a825' }]
			},
			corners: o(cfg.corners, 'woven'),
			medallions: Array.isArray(cfg.medallions) ? cfg.medallions : [],
			breaks: Array.isArray(cfg.breaks) ? cfg.breaks : [],
			autoBreak: { enabled: ab.enabled == null ? true : !!ab.enabled, padding: +o(ab.padding, 2) }
		};
	}

	// ---------- frame layout ----------
	// Edge-local frame: u along the edge run, v across the band (0..band). toPage maps to page px.
	function frameLayout(cfg, W, H) {
		var S = Math.min(W, H);
		var inset = cfg.band.inset / 100 * S, band = cfg.band.width / 100 * S;
		var x0 = inset, y0 = inset, x1 = W - inset, y1 = H - inset;
		function edge(name, ox, oy, ux, uy, vx, vy, len) { return { name: name, ox: ox, oy: oy, ux: ux, uy: uy, vx: vx, vy: vy, len: Math.max(0, len) }; }
		return {
			S: S, inset: inset, band: band, W: W, H: H,
			edges: {
				top:    edge('top',    x0 + band, y0,        1, 0, 0, 1, (x1 - x0) - 2 * band),
				bottom: edge('bottom', x0 + band, y1 - band, 1, 0, 0, 1, (x1 - x0) - 2 * band),
				left:   edge('left',   x0,        y0 + band, 0, 1, 1, 0, (y1 - y0) - 2 * band),
				right:  edge('right',  x1 - band, y0 + band, 0, 1, 1, 0, (y1 - y0) - 2 * band)
			},
			corners: { tl: { x: x0, y: y0 }, tr: { x: x1 - band, y: y0 }, bl: { x: x0, y: y1 - band }, br: { x: x1 - band, y: y1 - band } }
		};
	}
	function toPage(e, u, v) { return [e.ox + e.ux * u + e.vx * v, e.oy + e.uy * u + e.vy * v]; }

	// ---------- strand metrics ----------
	function lane(i, N, band) { return band * (i + 0.5) / N; }
	function strandW(band, N, sp) { return Math.max(2, (band / N) * clamp(sp.thickness, 0.2, 0.95)); }
	function outlineW(wf) { return clamp(wf * 0.16, 1.1, 3); }
	function STEP(band) { return clamp(band / 16, 1.25, 4); }
	function TERM(band) { return band * 0.55; }
	function EASE(lam, L) { return Math.min(lam * 0.6, L * 0.4); }

	// ---------- intervals / segmentation ----------
	function mergeIntervals(list) {
		var a = list.slice().sort(function (p, q) { return p[0] - q[0]; }), out = [];
		a.forEach(function (iv) {
			if (out.length && iv[0] <= out[out.length - 1][1]) { out[out.length - 1][1] = Math.max(out[out.length - 1][1], iv[1]); }
			else { out.push([iv[0], iv[1]]); }
		});
		return out;
	}
	// feats: [{type:'break'|'medallion', u0, u1, med?}] -> ordered weave segments with end kinds.
	function segmentEdge(edgeLen, feats, band, cornerEnd) {
		var fs = feats.slice().sort(function (p, q) { return p.u0 - q.u0; });
		var segs = [], cursor = 0, prevEnd = cornerEnd, prevMed = null;
		function push(u0, u1, endA, endB, medA, medB) {
			if (u1 - u0 < 2) { return; }
			segs.push({ u0: u0, u1: u1, endA: endA, endB: endB, med: medB || medA || null, medA: medA || null, medB: medB || null });
		}
		fs.forEach(function (f) {
			var kind = f.type === 'medallion' ? 'medallion' : 'terminal';
			push(cursor, clamp(f.u0, 0, edgeLen), prevEnd, kind, prevMed, f.type === 'medallion' ? f.med : null);
			cursor = clamp(f.u1, 0, edgeLen);
			prevEnd = kind; prevMed = (f.type === 'medallion') ? f.med : null;
		});
		push(cursor, edgeLen, prevEnd, cornerEnd, prevMed, null);
		return segs;
	}
	// project padded, break_border-flagged slots onto each edge's band strip.
	function autoBreaks(cfg, W, H, slots, layout) {
		var out = { top: [], right: [], bottom: [], left: [] };
		if (!cfg.autoBreak.enabled) { return out; }
		var pad = cfg.autoBreak.padding / 100 * layout.S;
		(slots || []).forEach(function (s) {
			if (!s || !s.break_border) { return; }
			var rx = s.x / 100 * W - pad, ry = s.y / 100 * H - pad;
			var rw = s.w / 100 * W + 2 * pad, rh = s.h / 100 * H + 2 * pad;
			['top', 'right', 'bottom', 'left'].forEach(function (name) {
				var e = layout.edges[name];
				// band strip rect of this edge in page coords
				var p00 = toPage(e, 0, 0), p11 = toPage(e, e.len, layout.band);
				var sx0 = Math.min(p00[0], p11[0]), sy0 = Math.min(p00[1], p11[1]);
				var sx1 = Math.max(p00[0], p11[0]), sy1 = Math.max(p00[1], p11[1]);
				var ix0 = Math.max(rx, sx0), iy0 = Math.max(ry, sy0);
				var ix1 = Math.min(rx + rw, sx1), iy1 = Math.min(ry + rh, sy1);
				if (ix1 <= ix0 || iy1 <= iy0) { return; }
				var u0 = e.ux ? (ix0 - Math.min(p00[0], p11[0])) : (iy0 - Math.min(p00[1], p11[1]));
				var u1 = e.ux ? (ix1 - Math.min(p00[0], p11[0])) : (iy1 - Math.min(p00[1], p11[1]));
				out[name].push([clamp(u0, 0, e.len), clamp(u1, 0, e.len)]);
			});
		});
		['top', 'right', 'bottom', 'left'].forEach(function (n) { out[n] = mergeIntervals(out[n]); });
		return out;
	}

	// ---------- patterns ----------
	// Contract: gen(L, band, sp) -> {strands:[{pts:[[u,v]..], color:int, closed:false}]}
	// Strands eased to lane centers over EASE at both ends; whole number of wave repeats.
	var patterns = {};
	patterns.plait = function (L, band, sp) {
		var N = clamp(sp.count, 2, 4);
		var lam0 = Math.max(band * 1.5 * sp.scale, 8);
		var reps = Math.max(1, Math.round(L / lam0)), lam = L / reps;
		var wf = strandW(band, N, sp);
		var amp = Math.max(1, band / 2 - wf / 2 - outlineW(wf) - 1);
		var ease = EASE(lam, L), step = STEP(band), strands = [];
		for (var i = 0; i < N; i++) {
			var phi = i * Math.PI * 2 / N, pts = [];
			for (var u = 0; u <= L + 1e-6; u += step) {
				var uu = Math.min(u, L);
				var vv = band / 2 + amp * Math.sin(Math.PI * 2 * uu / lam + phi);
				var d = Math.min(uu, L - uu);
				if (d < ease) { vv = lerp(lane(i, N, band), vv, smooth(d / ease)); }
				pts.push([uu, vv]);
				if (uu >= L) { break; }
			}
			if (pts[pts.length - 1][0] < L) { pts.push([L, lane(i, N, band)]); }
			strands.push({ pts: pts, color: i, closed: false });
		}
		return { strands: strands };
	};

	// ---------- crossings ----------
	function segInt(p1, p2, p3, p4) {                    // segment intersection -> {t,s,x,y} or null
		var d1x = p2[0] - p1[0], d1y = p2[1] - p1[1], d2x = p4[0] - p3[0], d2y = p4[1] - p3[1];
		var den = d1x * d2y - d1y * d2x;
		if (Math.abs(den) < 1e-12) { return null; }
		var t = ((p3[0] - p1[0]) * d2y - (p3[1] - p1[1]) * d2x) / den;
		var s = ((p3[0] - p1[0]) * d1y - (p3[1] - p1[1]) * d1x) / den;
		if (t < 0 || t > 1 || s < 0 || s > 1) { return null; }
		return { t: t, s: s, x: p1[0] + d1x * t, y: p1[1] + d1y * t };
	}
	function bbox(pts) {
		var x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
		pts.forEach(function (p) { if (p[0] < x0) x0 = p[0]; if (p[0] > x1) x1 = p[0]; if (p[1] < y0) y0 = p[1]; if (p[1] > y1) y1 = p[1]; });
		return [x0, y0, x1, y1];
	}
	// polys: [{pts, closed}] page coords. Returns crossings with alternating over/under per pair.
	function findCrossings(polys, dedupeR) {
		dedupeR = dedupeR || 3;
		var raw = [];
		for (var a = 0; a < polys.length; a++) {
			for (var b = a; b < polys.length; b++) {
				var A = polys[a].pts, B = polys[b].pts;
				if (a !== b) {
					var ba = bbox(A), bb = bbox(B);
					if (ba[2] < bb[0] - 1 || bb[2] < ba[0] - 1 || ba[3] < bb[1] - 1 || bb[3] < ba[1] - 1) { continue; }
				}
				var nA = A.length - 1, nB = B.length - 1;
				for (var i = 0; i < nA; i++) {
					var j0 = (a === b) ? i + 5 : 0;      // skip adjacent segments on self-crossing scan
					for (var j = j0; j < nB; j++) {
						var hit = segInt(A[i], A[i + 1], B[j], B[j + 1]);
						if (hit) { raw.push({ a: a, b: b, ia: i, fa: hit.t, ib: j, fb: hit.s, x: hit.x, y: hit.y }); }
					}
				}
			}
		}
		// dedupe near-coincident hits (same crossing straddling sample points)
		var cross = [];
		raw.forEach(function (c) {
			for (var k = 0; k < cross.length; k++) {
				var o = cross[k];
				if (o.a === c.a && o.b === c.b && (o.x - c.x) * (o.x - c.x) + (o.y - c.y) * (o.y - c.y) < dedupeR * dedupeR) { return; }
			}
			cross.push(c);
		});
		// per-pair alternation, ordered along strand a
		var groups = {};
		cross.forEach(function (c) { var k = c.a + ':' + c.b; (groups[k] = groups[k] || []).push(c); });
		Object.keys(groups).forEach(function (k) {
			var g = groups[k].sort(function (p, q) { return (p.ia + p.fa) - (q.ia + q.fa); });
			var start = (g[0].a + g[0].b) % 2;
			g.forEach(function (c, idx) { c.over = ((idx + start) % 2 === 0) ? 'a' : 'b'; });
		});
		return cross;
	}

	var K = {
		_geom: {
			norm: norm, frameLayout: frameLayout, toPage: toPage, lane: lane, strandW: strandW, outlineW: outlineW,
			mergeIntervals: mergeIntervals, segmentEdge: segmentEdge, autoBreaks: autoBreaks,
			patterns: patterns, findCrossings: findCrossings, blendHex: blendHex,
			STEP: STEP, TERM: TERM, EASE: EASE, clamp: clamp, lerp: lerp, smooth: smooth
		}
	};
	w.ScrollKnot = K;
})(typeof window !== 'undefined' ? window : globalThis);
