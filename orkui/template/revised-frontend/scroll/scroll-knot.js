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
	// order = [0,2,1,3]: pair A (k=0,1) sits outer/outer, pair B (k=2,3) inner/inner at the lanes
	// so the two-tone lattice mirrors symmetrically at the segment ports.
	patterns.openweave = function (L, band, sp) {
		var lam0 = Math.max(band * 2.6 * sp.scale, 10);
		var reps = Math.max(1, Math.round(L / lam0)), lam = L / reps;
		var wf = strandW(band, 4, sp), amp = Math.max(1, band / 2 - wf / 2 - outlineW(wf) - 1);
		var ease = EASE(lam, L), step = STEP(band), order = [0, 2, 1, 3], strands = [];
		for (var k = 0; k < 4; k++) {
			var pair = k >> 1, sign = (k & 1) ? -1 : 1, phase = pair * Math.PI / 2, pts = [];
			for (var u = 0; u <= L + 1e-6; u += step) {
				var uu = Math.min(u, L);
				var vv = band / 2 + sign * amp * Math.sin(Math.PI * 2 * uu / lam + phase);
				var d = Math.min(uu, L - uu);
				if (d < ease) { vv = lerp(lane(order[k], 4, band), vv, smooth(d / ease)); }
				pts.push([uu, vv]);
				if (uu >= L) { break; }
			}
			if (pts[pts.length - 1][0] < L) { pts.push([L, lane(order[k], 4, band)]); }
			strands.push({ pts: pts, color: pair, closed: false, lane: order[k] });
		}
		// Reorder so array index === lane index (buildSegmentPolys pairs terminals by array
		// order = lane order). Strand array is emitted [A0,A1,B0,B1] (k order) but lanes are
		// [0,2,1,3]; sort by the `lane` tag so index 0..3 walks lanes 0..3 in page order.
		strands.sort(function (a, b) { return a.lane - b.lane; });
		strands.forEach(function (s) { delete s.lane; });
		return { strands: strands };
	};
	patterns.twist = function (L, band, sp) {
		var sp2 = { count: 2, thickness: clamp(sp.thickness * 1.25, 0.3, 0.9), gap: sp.gap, scale: sp.scale };
		var lam0 = Math.max(band * 1.15 * sp.scale, 8);
		var reps = Math.max(1, Math.round(L / lam0)), lam = L / reps;
		var wf = strandW(band, 2, sp2), amp = Math.max(1, band / 2 - wf / 2 - outlineW(wf) - 1);
		var ease = EASE(lam, L), step = STEP(band), strands = [];
		for (var k = 0; k < 2; k++) {
			var sign = k ? -1 : 1, pts = [];
			for (var u = 0; u <= L + 1e-6; u += step) {
				var uu = Math.min(u, L);
				var vv = band / 2 + sign * amp * Math.sin(Math.PI * 2 * uu / lam);
				var d = Math.min(uu, L - uu);
				if (d < ease) { vv = lerp(lane(k, 2, band), vv, smooth(d / ease)); }
				pts.push([uu, vv]);
				if (uu >= L) { break; }
			}
			if (pts[pts.length - 1][0] < L) { pts.push([L, lane(k, 2, band)]); }
			strands.push({ pts: pts, color: k, closed: false });
		}
		return { strands: strands };
	};
	patterns.runningknot = function (L, band, sp) {
		var wf = strandW(band, 2, sp), amp = Math.max(2, band / 2 - wf / 2 - outlineW(wf) - 1);
		var lam0 = Math.min(Math.max(band * 1.8 * sp.scale, 10), band * 2);
		var reps = Math.max(2, Math.round(L / lam0)), lam = L / reps;
		var R = lam / (2 * Math.PI), d = Math.max(amp * 0.95, R * 1.35);
		var vLo = wf / 2 + 1, vHi = band - wf / 2 - 1;
		var pts = [], T = reps * 2 * Math.PI;
		for (var t = 0; t <= T + 1e-9; t += 0.12) {
			var tt = Math.min(t, T);
			var fade = Math.min(1, Math.min(tt, T - tt) / Math.PI);       // straighten ends over a half-turn
			var dt = d * lerp(0.25, 1, smooth(fade));
			var uRaw = R * tt - dt * Math.sin(tt);
			pts.push([clamp(uRaw / (R * T) * L, 0, L), clamp(band / 2 - dt * Math.cos(tt), vLo, vHi)]);
			if (tt >= T) { break; }
		}
		var rail = [[0, band / 2], [L, band / 2]];
		return { strands: [{ pts: pts, color: 0, closed: false }, { pts: rail, color: 1, closed: false }] };
	};
	function effCount(cfg) {
		if (cfg.pattern === 'openweave') { return 4; }
		if (cfg.pattern === 'twist' || cfg.pattern === 'runningknot') { return 2; }
		return clamp(cfg.strands.count, 2, 4);
	}

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

	// ---------- sub-polyline extraction (for crossing over-arcs) ----------
	function subPolyline(pts, closed, idx, frac, halfLen) {
		var n = pts.length;
		function P(i) { return pts[((i % n) + n) % n]; }
		function segLen(i) { var A = P(i), B = P(i + 1); return Math.hypot(B[0] - A[0], B[1] - A[1]); }
		var cx = lerp(P(idx)[0], P(idx + 1)[0], frac), cy = lerp(P(idx)[1], P(idx + 1)[1], frac);
		var out = [[cx, cy]], acc, i, steps;
		// walk backward
		acc = frac * segLen(idx); i = idx; steps = 0;
		while (acc < halfLen && steps++ < n) {
			out.unshift(P(i).slice());
			i--; if (i < 0) { if (!closed) { break; } i += n; }
			acc += segLen(i);
		}
		// walk forward
		acc = (1 - frac) * segLen(idx); i = idx + 1; steps = 0;
		while (acc < halfLen && steps++ < n) {
			out.push(P(i).slice());
			i++; if (i >= n && !closed) { break; }
			acc += segLen(i);
		}
		if (!closed) { return out; }
		return out;
	}

	// ---------- terminals + segment assembly ----------
	// Sample a U-turn arc joining (ue, va)->(ue, vb), bulging dir (+1/-1) beyond the segment end.
	function uTurn(ue, va, vb, dir, reach) {
		var pts = [], mid = (va + vb) / 2, r = Math.abs(vb - va) / 2;
		for (var k = 0; k <= 16; k++) {
			var th = k / 16 * Math.PI;
			pts.push([ue + dir * Math.sin(th) * Math.max(r, reach), mid - Math.cos(th) * r * (va < vb ? 1 : -1)]);
		}
		return pts;
	}
	// Spiral curl for the middle strand of an odd count.
	function curl(ue, v, dir, band) {
		var pts = [], r0 = band * 0.22, cx = ue + dir * r0, turns = 1.5 * Math.PI * 2 * 0.75; // 270 deg
		for (var k = 0; k <= 24; k++) {
			var th = k / 24 * turns, r = r0 * (1 - 0.7 * (k / 24));
			pts.push([cx - dir * Math.cos(th) * r, v + Math.sin(th) * r]);
		}
		return pts;
	}
	// Build the page-space polylines for one weave segment, terminals merged in.
	function buildSegmentPolys(edge, seg, cfg, layout) {
		var band = layout.band, sp = cfg.strands;
		var tA = seg.endA === 'corner' ? 0 : TERM(band), tB = seg.endB === 'corner' ? 0 : TERM(band);
		if (seg.endA === 'medallion') { tA = band * 0.35; }
		if (seg.endB === 'medallion') { tB = band * 0.35; }
		var Lw = (seg.u1 - seg.u0) - tA - tB;
		var gen = patterns[cfg.pattern] || patterns.plait;
		var res, off = seg.u0 + tA;
		if (Lw < band * 1.1) {                             // degenerate: plain connector strands
			var pts0 = [[seg.u0 + tA, band * 0.35], [seg.u1 - tB, band * 0.35]];
			var pts1 = [[seg.u0 + tA, band * 0.65], [seg.u1 - tB, band * 0.65]];
			res = { strands: [{ pts: pts0, color: 0, closed: false }, { pts: pts1, color: 1, closed: false }] };
			off = 0;
		} else {
			res = gen(Lw, band, sp);
			res.strands.forEach(function (s) { s.pts = s.pts.map(function (p) { return [p[0] + off, p[1]]; }); });
		}
		var N = res.strands.length;
		// terminal arcs: pair lane i with lane N-1-i (fixed for both A and B passes); odd middle curls.
		// Each pair (i, N-1-i) is visited once per open end (once by endArcs('A'), once by endArcs('B')).
		// First visit merges si+sj into one open polyline (owner = si, sj absorbed via sj.merged).
		// Second visit (sj already merged) finds si's two free ends now sitting at THIS end and
		// joins them with an arc, closing the polyline into a loop.
		function endArcs(atEnd) {                           // atEnd: 'A'|'B'
			var isA = atEnd === 'A', kind = isA ? seg.endA : seg.endB;
			if (kind === 'corner') { return; }
			var ue = isA ? (seg.u0 + tA) : (seg.u1 - tB), dir = isA ? -1 : 1;
			var reach = (kind === 'medallion') ? (isA ? tA : tB) + band * 0.3 : Math.min(TERM(band) * 0.8, band * 0.45);
			for (var i = 0; i < Math.floor(N / 2); i++) {
				var j = N - 1 - i;
				var si = res.strands[i], sj = res.strands[j];
				if (!si || !sj || si === sj) { continue; }
				var arc = uTurn(ue, lane(i, N, band), lane(j, N, band), dir, reach * (1 - i * 0.25));
				if (sj.merged) {                             // second visit for this pair -> close the loop
					if (si.merged || si.closed) { continue; }
					si.pts = si.pts.concat(arc);
					si.closed = true;
					continue;
				}
				// first visit: merge si.pts + arc + reversed sj.pts (orientation depends on end)
				var joined;
				if (isA) { joined = sj.pts.slice().reverse().concat(arc.slice().reverse(), si.pts); }
				else { joined = si.pts.concat(arc, sj.pts.slice().reverse()); }
				si.pts = joined; sj.merged = true;
			}
			if (N % 2 === 1) {
				var m = res.strands[(N - 1) / 2];
				if (m && !m.merged && !m.closed) {
					var c = curl(ue, lane((N - 1) / 2, N, band), dir, band);
					if (isA) { m.pts = c.slice().reverse().concat(m.pts); } else { m.pts = m.pts.concat(c); }
				}
			}
		}
		endArcs('A'); endArcs('B');
		var out = [];
		res.strands.forEach(function (s) {
			if (s.merged) { return; }
			out.push({ pts: s.pts.map(function (p) { return toPage(edge, p[0], p[1]); }), color: s.color, closed: !!s.closed });
		});
		return out;
	}

	// ---------- corners ----------
	var CORNER_DEF = {
		tl: { A: ['top', 0], B: ['left', 0], dirA: [-1, 0], dirB: [0, -1] },
		tr: { A: ['top', 1], B: ['right', 0], dirA: [1, 0], dirB: [0, -1] },
		bl: { A: ['bottom', 0], B: ['left', 1], dirA: [-1, 0], dirB: [0, 1] },
		br: { A: ['bottom', 1], B: ['right', 1], dirA: [1, 0], dirB: [0, 1] }
	};
	function cubic(p0, c1, c2, p1, samples) {
		var pts = [];
		for (var k = 0; k <= samples; k++) {
			var t = k / samples, mt = 1 - t;
			pts.push([
				mt * mt * mt * p0[0] + 3 * mt * mt * t * c1[0] + 3 * mt * t * t * c2[0] + t * t * t * p1[0],
				mt * mt * mt * p0[1] + 3 * mt * mt * t * c1[1] + 3 * mt * t * t * c2[1] + t * t * t * p1[1]
			]);
		}
		return pts;
	}
	function cornerPolys(key, cfg, layout) {
		var def = CORNER_DEF[key], N = effCount(cfg), out = [];
		var eA = layout.edges[def.A[0]], eB = layout.edges[def.B[0]];
		var uA = def.A[1] ? eA.len : 0, uB = def.B[1] ? eB.len : 0;
		if (cfg.corners === 'hook') {
			var box = layout.corners[key], cx = box.x + layout.band / 2, cy = box.y + layout.band / 2;
			var pts = [], a0 = Math.atan2(def.dirA[1], def.dirA[0]) + Math.PI;   // enter opposite the into-dir
			for (var k = 0; k <= 32; k++) {
				var th = a0 + k / 32 * 1.5 * Math.PI, r = lerp(layout.band * 0.42, layout.band * 0.12, k / 32);
				pts.push([cx + Math.cos(th) * r, cy + Math.sin(th) * r]);
			}
			out.push({ pts: pts, color: 0, closed: false });
			return out;
		}
		function perm(i) { return (N % 2 === 0) ? (i + 2) % N : (N - 1 - i); }
		for (var i = 0; i < N; i++) {
			var PA = toPage(eA, uA, lane(i, N, layout.band));
			var PB = toPage(eB, uB, lane(perm(i), N, layout.band));
			var c1 = [PA[0] + def.dirA[0] * layout.band * 0.45, PA[1] + def.dirA[1] * layout.band * 0.45];
			var c2 = [PB[0] + def.dirB[0] * layout.band * 0.45, PB[1] + def.dirB[1] * layout.band * 0.45];
			out.push({ pts: cubic(PA, c1, c2, PB, 24), color: i, closed: false });
		}
		return out;
	}
	// ---------- medallions ----------
	function diamond(cx, cy, huU, hvV, e, samples) {
		// half-diagonals huU (along edge u dir) and hvV (along v dir), in page space via edge axes
		var ux = e.ux, uy = e.uy, vx = e.vx, vy = e.vy;
		var V = [
			[cx - ux * huU, cy - uy * huU], [cx + vx * hvV, cy + vy * hvV],
			[cx + ux * huU, cy + uy * huU], [cx - vx * hvV, cy - vy * hvV]
		];
		var pts = [];
		for (var s = 0; s < 4; s++) {
			var A = V[s], B = V[(s + 1) % 4];
			for (var k = 0; k < samples; k++) { var t = k / samples; pts.push([lerp(A[0], B[0], t), lerp(A[1], B[1], t)]); }
		}
		return pts;
	}
	function medallionPolys(med, e, layout, cfg) {
		var hd = (med.size / 100 * layout.S) / 2;
		var C = toPage(e, med.at / 100 * e.len, layout.band / 2);
		return [
			{ pts: diamond(C[0], C[1], hd * 1.0, hd * 0.8, e, 12), color: 0, closed: true },
			{ pts: diamond(C[0], C[1], hd * 0.8, hd * 1.0, e, 12), color: 1, closed: true }
		];
	}
	function medallionInnerRects(rawCfg, W, H) {
		var cfg = norm(rawCfg), layout = frameLayout(cfg, W, H), out = [];
		cfg.medallions.forEach(function (m) {
			var e = layout.edges[m.edge]; if (!e) { return; }
			var hd = (m.size / 100 * layout.S) / 2;
			var C = toPage(e, m.at / 100 * e.len, layout.band / 2);
			var half = hd * 0.8 / Math.SQRT2 * 0.9;
			out.push({ edge: m.edge, at: m.at, x: (C[0] - half) / W * 100, y: (C[1] - half) / H * 100, w: 2 * half / W * 100, h: 2 * half / H * 100 });
		});
		return out;
	}

	// ---------- SVG ----------
	var uidCounter = 0;
	function svgEl(tag) { return document.createElementNS(SVGNS, tag); }
	function polyPath(pts, closed) {
		var d = 'M' + pts[0][0].toFixed(2) + ' ' + pts[0][1].toFixed(2);
		for (var i = 1; i < pts.length; i++) { d += 'L' + pts[i][0].toFixed(2) + ' ' + pts[i][1].toFixed(2); }
		return closed ? d + 'Z' : d;
	}
	function strokePath(parent, d, paint, width) {
		var p = svgEl('path');
		p.setAttribute('d', d); p.setAttribute('fill', 'none');
		p.setAttribute('stroke', paint); p.setAttribute('stroke-width', width.toFixed(2));
		p.setAttribute('stroke-linecap', 'round'); p.setAttribute('stroke-linejoin', 'round');
		parent.appendChild(p);
		return p;
	}
	// collectPolys: full border -> [{pts,color,closed}] page space (corners/medallions join in Tasks 3-4)
	function collectPolys(cfg, W, H, slots) {
		var layout = frameLayout(cfg, W, H);
		var ab = autoBreaks(cfg, W, H, slots, layout);
		var polys = [];
		['top', 'right', 'bottom', 'left'].forEach(function (name) {
			var e = layout.edges[name];
			var feats = [];
			cfg.breaks.forEach(function (b) {
				if (b.edge !== name) { return; }
				var c = b.at / 100 * e.len, h = b.width / 100 * e.len / 2;
				feats.push({ type: 'break', u0: c - h, u1: c + h });
			});
			ab[name].forEach(function (iv) { feats.push({ type: 'break', u0: iv[0], u1: iv[1] }); });
			cfg.medallions.forEach(function (m) {
				if (m.edge !== name) { return; }
				var hd = (m.size / 100 * layout.S) / 2, c = m.at / 100 * e.len, pad = layout.band * 0.15;
				feats.push({ type: 'medallion', u0: c - hd - pad, u1: c + hd + pad, med: m });
			});
			// merge plain breaks first so overlapping intervals don't create phantom segments
			var brk = mergeIntervals(feats.filter(function (f) { return f.type === 'break'; }).map(function (f) { return [f.u0, f.u1]; }))
				.map(function (iv) { return { type: 'break', u0: iv[0], u1: iv[1] }; });
			var meds = feats.filter(function (f) { return f.type === 'medallion'; });
			var cornerEnd = (cfg.corners === 'hook') ? 'terminal' : 'corner';
			segmentEdge(e.len, brk.concat(meds), layout.band, cornerEnd).forEach(function (seg) {
				buildSegmentPolys(e, seg, cfg, layout).forEach(function (p) { polys.push(p); });
			});
		});
		['tl', 'tr', 'bl', 'br'].forEach(function (key) {
			cornerPolys(key, cfg, layout).forEach(function (p) { polys.push(p); });
		});
		cfg.medallions.forEach(function (m) {
			var e = layout.edges[m.edge]; if (!e) { return; }
			medallionPolys(m, e, layout, cfg).forEach(function (p) { polys.push(p); });
		});
		return { layout: layout, polys: polys };
	}
	function render(rawCfg, W, H, slots) {
		var cfg = norm(rawCfg);
		var svg = svgEl('svg');
		svg.setAttribute('class', 'sc-knot');
		svg.setAttribute('viewBox', '0 0 ' + W + ' ' + H);
		svg.setAttribute('preserveAspectRatio', 'none');
		if (!cfg.enabled) { return svg; }
		var uid = ++uidCounter;
		var got = collectPolys(cfg, W, H, slots);
		var polys = got.polys;
		// paints
		var paints = cfg.colors.strands.slice();
		if (cfg.gradient.enabled) {
			var defs = svgEl('defs');
			var rad = cfg.gradient.angle * Math.PI / 180;
			var dx = Math.cos(rad), dy = Math.sin(rad);
			var R = (Math.abs(dx) * W + Math.abs(dy) * H) / 2, cx = W / 2, cy = H / 2;
			cfg.colors.strands.forEach(function (hex, k) {
				var g = svgEl('linearGradient');
				g.setAttribute('id', 'skg' + uid + '_' + k); g.setAttribute('gradientUnits', 'userSpaceOnUse');
				g.setAttribute('x1', (cx - dx * R).toFixed(1)); g.setAttribute('y1', (cy - dy * R).toFixed(1));
				g.setAttribute('x2', (cx + dx * R).toFixed(1)); g.setAttribute('y2', (cy + dy * R).toFixed(1));
				cfg.gradient.stops.forEach(function (st) {
					var s = svgEl('stop');
					s.setAttribute('offset', (clamp(st.at, 0, 1) * 100) + '%');
					s.setAttribute('stop-color', blendHex(hex, st.color, 0.8));
					g.appendChild(s);
				});
				defs.appendChild(g);
				paints[k] = 'url(#skg' + uid + '_' + k + ')';
			});
			svg.appendChild(defs);
		}
		var band = got.layout.band, N = effCount(cfg);
		var wf = strandW(band, N, cfg.strands) * (cfg.pattern === 'twist' ? 1.25 : 1), wOut = wf + 2 * outlineW(wf), gapPx = cfg.strands.gap * wf;
		function paintOf(colorIdx) { return paints[colorIdx % paints.length]; }
		var gOutline = svgEl('g'), gFill = svgEl('g'), gCross = svgEl('g');
		polys.forEach(function (p) { strokePath(gOutline, polyPath(p.pts, p.closed), cfg.colors.outline, wOut); });
		polys.forEach(function (p) { strokePath(gFill, polyPath(p.pts, p.closed), paintOf(p.color), wf); });
		findCrossings(polys, wf * 0.8).forEach(function (c) {
			var overIdx = (c.over === 'a') ? c.a : c.b;
			var idx = (c.over === 'a') ? c.ia : c.ib, frac = (c.over === 'a') ? c.fa : c.fb;
			var p = polys[overIdx];
			var arc = subPolyline(p.pts, p.closed, idx, frac, wf * 0.75 + gapPx);
			if (arc.length < 2) { return; }
			var d = polyPath(arc, false);
			strokePath(gCross, d, cfg.colors.outline, wOut + 2 * gapPx);
			strokePath(gCross, d, paintOf(p.color), wf);
		});
		svg.appendChild(gOutline); svg.appendChild(gFill); svg.appendChild(gCross);
		return svg;
	}
	// small horizontal weave strip for designer pattern thumbnails
	function swatch(rawCfg, wPx, hPx) {
		var cfg = norm(rawCfg);
		cfg.enabled = true; cfg.breaks = []; cfg.medallions = []; cfg.autoBreak.enabled = false;
		var svg = svgEl('svg');
		svg.setAttribute('class', 'sc-knot-swatch');
		svg.setAttribute('viewBox', '0 0 ' + wPx + ' ' + hPx);
		var band = hPx * 0.8;
		var edge = { name: 'top', ox: 4, oy: (hPx - band) / 2, ux: 1, uy: 0, vx: 0, vy: 1, len: wPx - 8 };
		var layout = { band: band, S: hPx, W: wPx, H: hPx };
		var seg = { u0: 0, u1: edge.len, endA: 'terminal', endB: 'terminal', medA: null, medB: null };
		var polys = buildSegmentPolys(edge, seg, cfg, layout);
		var N = effCount(cfg);
		var wf = strandW(band, N, cfg.strands) * (cfg.pattern === 'twist' ? 1.25 : 1), wOut = wf + 2 * outlineW(wf), gapPx = cfg.strands.gap * wf;
		var g1 = svgEl('g'), g2 = svgEl('g'), g3 = svgEl('g');
		polys.forEach(function (p) { strokePath(g1, polyPath(p.pts, p.closed), cfg.colors.outline, wOut); });
		polys.forEach(function (p) { strokePath(g2, polyPath(p.pts, p.closed), cfg.colors.strands[p.color % cfg.colors.strands.length], wf); });
		findCrossings(polys, wf * 0.8).forEach(function (c) {
			var overIdx = (c.over === 'a') ? c.a : c.b, idx = (c.over === 'a') ? c.ia : c.ib, frac = (c.over === 'a') ? c.fa : c.fb;
			var p = polys[overIdx], arc = subPolyline(p.pts, p.closed, idx, frac, wf * 0.75 + gapPx);
			if (arc.length < 2) { return; }
			strokePath(g3, polyPath(arc, false), cfg.colors.outline, wOut + 2 * gapPx);
			strokePath(g3, polyPath(arc, false), cfg.colors.strands[p.color % cfg.colors.strands.length], wf);
		});
		svg.appendChild(g1); svg.appendChild(g2); svg.appendChild(g3);
		return svg;
	}

	var K = {
		render: render,
		swatch: swatch,
		medallionInnerRects: medallionInnerRects,
		_geom: {
			norm: norm, frameLayout: frameLayout, toPage: toPage, lane: lane, strandW: strandW, outlineW: outlineW,
			mergeIntervals: mergeIntervals, segmentEdge: segmentEdge, autoBreaks: autoBreaks,
			patterns: patterns, findCrossings: findCrossings, blendHex: blendHex, subPolyline: subPolyline,
			buildSegmentPolys: buildSegmentPolys, collectPolys: collectPolys, uTurn: uTurn, curl: curl,
			cornerPolys: cornerPolys, medallionPolys: medallionPolys, cubic: cubic,
			STEP: STEP, TERM: TERM, EASE: EASE, clamp: clamp, lerp: lerp, smooth: smooth, effCount: effCount
		}
	};
	w.ScrollKnot = K;
})(typeof window !== 'undefined' ? window : globalThis);
