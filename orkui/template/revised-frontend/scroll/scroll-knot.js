/* scroll-knot.js — parametric Celtic knotwork border engine.
   Geometry core is DOM-free (unit-tested in Node); render()/swatch() build SVG.
   PDF-safe SVG subset only: paths + strokes + userSpaceOnUse linear gradients.
   Assembly model: a single continuous rounded-rectangle SPINE runs clockwise around the
   frame; patterns are generated in local (u,v) then swept along the spine so the weave
   flows continuously through corners. Corners are 'woven' (rounded spine) or 'pointed'
   (degenerate-radius spine + miter vertices inserted during the sweep, so the braid folds
   through a sharp 90-degree point). Breaks cut the spine into open segments (or leave it
   as one closed loop when there are no features); open segment ends finish with natural-fold
   caps: each nesting pair is trimmed at a shared-tangent separation extremum and bridged with
   a slope-sheared semicircle (odd middle strands end in a closed leaf fold), so every strand
   stays contiguous and every wrap is tangent-clean at any density or strand count. */
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
		function num(v, d) { v = +v; return isFinite(v) ? v : d; }
		var band = cfg.band || {}, st = cfg.strands || {}, co = cfg.colors || {}, gr = cfg.gradient || {}, ab = cfg.autoBreak || {};
		var PATTERNS_OK = ['plait', 'openweave', 'twist'];   // whitelist protects old saved configs (e.g. removed 'runningknot')
		// legacy mapping: the removed corners:'hook' option becomes pointed corners.
		var cor = cfg.corners;
		if (cor === 'hook') { cor = 'pointed'; }
		return {
			enabled: !!cfg.enabled,
			pattern: (PATTERNS_OK.indexOf(cfg.pattern) >= 0) ? cfg.pattern : 'plait',
			band: { inset: num(band.inset, 2), width: num(band.width, 6) },
			strands: { count: clamp(num(st.count, 3), 2, 4), thickness: num(st.thickness, 0.55), scale: num(st.scale, 1) },
			colors: {
				strands: (Array.isArray(co.strands) && co.strands.length) ? co.strands.slice(0, 4) : ['#2e7d32', '#f4c542'],
				outline: o(co.outline, '#1a1a1a')
			},
			gradient: {
				enabled: !!gr.enabled, angle: num(gr.angle, 90),
				stops: (Array.isArray(gr.stops) && gr.stops.length >= 2) ? gr.stops : [{ at: 0, color: '#c62828' }, { at: 1, color: '#f9a825' }]
			},
			corners: (cor === 'pointed') ? 'pointed' : 'woven',
			breaks: Array.isArray(cfg.breaks) ? cfg.breaks : [],
			autoBreak: { enabled: ab.enabled == null ? true : !!ab.enabled, padding: num(ab.padding, 2) }
		};
	}

	// ---------- frame layout ----------
	// Edge-local frame: u along the edge run, v across the band (0..band). toPage maps to page px.
	// Kept for: autoBreaks' band-strip overlap math and as the per-edge u-domain that feature
	// intervals are first computed in before being mapped onto the spine (see edgeIntervalToS).
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
	function outlineW(wf) { return clamp(wf * 0.22, 1.2, 4.5); }   // bold inked outline (reference weight)
	function STEP(band) { return clamp(band / 16, 1.25, 4); }
	function TERM(band) { return band * 0.55; }                                  // degenerate-connector inset only

	// ---------- tunable named constants (visual acceptance loop tunes these) ----------
	var SPINE_STEP = 2;                    // px, spine sample density
	var R_FACTOR = 0.75;                   // spine corner radius = clamp(band*R_FACTOR, 6, band)
	var RIM_RADIUS_FACTOR = 1.0;           // cap bulge/gap ratio (1 = true semicircle)
	var CAP_SAMPLES = 28;                  // cap semicircle sampling (first-chord angle ~ pi/CAP_SAMPLES/2)
	var FOLD_SEP_MIN = 0.5;                // candidate folds need >= this * the pair's max separation
	var CAP_END_MARGIN = 0.1;              // *band: cap tip keeps this clear of the segment boundary
	var PAIR_STAGGER = 0.2;                // *lam: min inward stagger between nested pair folds. Kept BELOW the
	//                                       natural lam/4 (0.25) interleave of adjacent mirror pairs, so an
	//                                       inner pair folds right after the outer pair's last crossing
	//                                       (compact interlocking terminal) instead of being skipped a whole
	//                                       half-wave inward (which left the outer pair soloing extra loops).
	var LEAF_STAGGER_RELAXED = 0.2;        // *lam: fallback middle-leaf stagger on short segments
	var LEAF_REACH_FACTOR = 0.5;           // *lam: middle-strand leaf fold reach
	var LEAF_REACH_MAX = 0.45;             // *band: middle-strand leaf reach cap
	var LEAF_WIDTH_FACTOR = 0.5;           // *innermost pair gap at its fold: leaf width
	var LEAF_SAMPLES = 28;                 // leaf teardrop sampling
	var LEAF_TAN_BASE = 0.5;               // *reach: odd-leaf base-tangent handle (matches strand arrival slope)
	var LEAF_TAN_TIP = 0.55;               // *reach: odd-leaf tip vertical handle (roundness of the shared tip)
	var LEAF_TAN_RISE = 0.5;               // *reach: cap on the arm's v-rise so a steep arrival slope can't balloon it
	var JUNCTION_DENSIFY = 0.15;           // *step: extra sample slipped just inside each trim point
	var SWATCH_MAX_SCALE = 0.7;            // panel thumbnails cap density so the short strip holds enough repeats to fold
	var POINTED_R = 0.01;                  // px, degenerate spine corner radius in pointed mode (arcs ~zero-length)
	var POINT_REACH_FACTOR = 1.35;         // *(sep/2): two-strand curved-point cap apex reaches past the round rim
	var POINT_SHOULDER = 0.35;             // *reach: ogee shoulder/sharpness (->1 rounds back toward the semicircle)

	// ---------- spine (centerline rounded-rect the whole border weaves along) ----------
	// Walks CLOCKWISE starting where the top run begins (end of the TL corner arc):
	// top run -> TR arc -> right run -> BR arc -> bottom run (right->left) -> BL arc ->
	// left run (bottom->top) -> TL arc -> close. (nx,ny) is the unit INWARD normal.
	function buildSpine(layout, pointed) {
		var band = layout.band;
		var cx0 = layout.inset + band / 2, cy0 = layout.inset + band / 2;
		var cx1 = layout.W - layout.inset - band / 2, cy1 = layout.H - layout.inset - band / 2;
		var cw = cx1 - cx0, ch = cy1 - cy0;
		// pointed mode: near-zero radius -> arcs are numerically zero-length and the loop is
		// effectively a rectangle; sweepStrand inserts the actual miter vertices.
		var R = pointed ? POINTED_R : clamp(band * R_FACTOR, 6, band || 6);
		var shorter = Math.min(cw, ch);
		if (!(shorter > 0) || 2 * R >= shorter) { R = Math.max(0.5, shorter / 3); }
		var Lt = Math.max(0, cw - 2 * R), Lr = Math.max(0, ch - 2 * R), La = R * Math.PI / 2;
		var runs = [
			{ kind: 'line', p0: [cx0 + R, cy0], p1: [cx1 - R, cy0], len: Lt },
			{ kind: 'arc', c: [cx1 - R, cy0 + R], r: R, a0: -Math.PI / 2, a1: 0, len: La },
			{ kind: 'line', p0: [cx1, cy0 + R], p1: [cx1, cy1 - R], len: Lr },
			{ kind: 'arc', c: [cx1 - R, cy1 - R], r: R, a0: 0, a1: Math.PI / 2, len: La },
			{ kind: 'line', p0: [cx1 - R, cy1], p1: [cx0 + R, cy1], len: Lt },
			{ kind: 'arc', c: [cx0 + R, cy1 - R], r: R, a0: Math.PI / 2, a1: Math.PI, len: La },
			{ kind: 'line', p0: [cx0, cy1 - R], p1: [cx0, cy0 + R], len: Lr },
			{ kind: 'arc', c: [cx0 + R, cy0 + R], r: R, a0: Math.PI, a1: 3 * Math.PI / 2, len: La }
		];
		var S = 2 * Lt + 2 * Lr + 4 * La;
		var table = [], sBase = 0;
		runs.forEach(function (run, ri) {
			var n = Math.max(2, Math.ceil(Math.max(run.len, 1e-6) / SPINE_STEP) + 1);
			var startK = ri === 0 ? 0 : 1;                 // skip k=0: duplicate of previous run's last sample
			for (var k = startK; k < n; k++) {
				var t = k / (n - 1), pt, dx, dy;
				if (run.kind === 'line') {
					pt = [lerp(run.p0[0], run.p1[0], t), lerp(run.p0[1], run.p1[1], t)];
					dx = run.p1[0] - run.p0[0]; dy = run.p1[1] - run.p0[1];
					var dl = Math.hypot(dx, dy) || 1; dx /= dl; dy /= dl;
				} else {
					var a = lerp(run.a0, run.a1, t);
					pt = [run.c[0] + Math.cos(a) * run.r, run.c[1] + Math.sin(a) * run.r];
					dx = -Math.sin(a); dy = Math.cos(a);
				}
				table.push({ s: sBase + t * run.len, x: pt[0], y: pt[1], nx: -dy, ny: dx });
			}
			sBase += run.len;
		});
		table.push({ s: S, x: table[0].x, y: table[0].y, nx: table[0].nx, ny: table[0].ny });   // exact closure
		return {
			table: table, S: S, R: R, band: band, pointed: !!pointed,
			runStart: { top: 0, right: Lt + La, bottom: Lt + La + Lr + La, left: Lt + La + Lr + La + Lt + La },
			arcStart: { tr: Lt, br: Lt + La + Lr, bl: Lt + La + Lr + La + Lt, tl: S - La },
			La: La, Lt: Lt, Lr: Lr, cx0: cx0, cy0: cy0, cx1: cx1, cy1: cy1
		};
	}
	function spine(cfg, W, H) { return buildSpine(frameLayout(cfg, W, H), cfg.corners === 'pointed'); }
	// interpolated {x,y,nx,ny} at arc-length s (wraps mod total length); nx/ny renormalized.
	function spineAt(table, S, s) {
		var sN = ((s % S) + S) % S, n = table.length, lo = 0, hi = n - 1;
		while (hi - lo > 1) { var mid = (lo + hi) >> 1; if (table[mid].s <= sN) { lo = mid; } else { hi = mid; } }
		var A = table[lo], B = table[hi], span = B.s - A.s, t = span > 1e-9 ? (sN - A.s) / span : 0;
		var nx = lerp(A.nx, B.nx, t), ny = lerp(A.ny, B.ny, t), nl = Math.hypot(nx, ny) || 1;
		return { x: lerp(A.x, B.x, t), y: lerp(A.y, B.y, t), nx: nx / nl, ny: ny / nl, s: sN };
	}
	// sweep a (spine-offset s, v) pattern point to a page point: v>band/2 is page-inward everywhere.
	function sweepPt(spn, sAbs, v, band) {
		var P = spineAt(spn.table, spn.S, sAbs);
		return [P.x + P.nx * (v - band / 2), P.y + P.ny * (v - band / 2)];
	}
	// ---------- pointed-corner miter sweep ----------
	// Inward normals of the two runs meeting at each corner, in spine travel order (n1 = run
	// entered from, n2 = run exited to). Miter vertex M = C + d*(n1+n2), where C is the
	// centerline-rectangle corner and d = v - band/2 (verify top-right: C=(cx1,cy0), n1=(0,1),
	// n2=(-1,0) -> M=(cx1-d, cy0+d); an outer strand (d<0) lands OUTSIDE the corner = the point).
	var MITER_NORMALS = {
		tr: [[0, 1], [-1, 0]],
		br: [[-1, 0], [0, -1]],
		bl: [[0, -1], [1, 0]],
		tl: [[1, 0], [0, 1]]
	};
	function cornerPoint(spn, key) {
		if (key === 'tr') { return [spn.cx1, spn.cy0]; }
		if (key === 'br') { return [spn.cx1, spn.cy1]; }
		if (key === 'bl') { return [spn.cx0, spn.cy1]; }
		return [spn.cx0, spn.cy0];
	}
	// Sweep a pattern polyline (local (u,v), u relative to sBase) to page space. Woven spines:
	// plain pointwise sweep. Pointed spines: the pointwise sweep chamfers every strand across
	// each (radius~0) corner, so for every consecutive point pair whose absolute s straddles a
	// corner s-value (incl. wrapped multiples of S on wrapped segments / closed loops) insert
	// the miter vertex, with d = v - band/2 linearly interpolated (by s) at the corner.
	function sweepStrand(spn, sBase, pts, band) {
		if (!spn.pointed) {
			return pts.map(function (p) { return sweepPt(spn, sBase + p[0], p[1], band); });
		}
		var S = spn.S, keys = ['tr', 'br', 'bl', 'tl'], out = [];
		for (var i = 0; i < pts.length; i++) {
			var P = pts[i];
			out.push(sweepPt(spn, sBase + P[0], P[1], band));
			if (i + 1 >= pts.length) { break; }
			var Q = pts[i + 1], sA = sBase + P[0], sB = sBase + Q[0];
			if (!(sB - sA > 1e-9)) { continue; }
			var hits = [];
			for (var k = 0; k < 4; k++) {
				var sc = spn.arcStart[keys[k]] + spn.La / 2;
				for (var mm = Math.floor((sA - sc) / S); ; mm++) {
					var t = sc + mm * S;
					if (t >= sB - 1e-9) { break; }
					if (t > sA + 1e-9) { hits.push({ s: t, key: keys[k] }); }
				}
			}
			if (!hits.length) { continue; }
			hits.sort(function (a, b) { return a.s - b.s; });
			for (var h = 0; h < hits.length; h++) {
				var tt = (hits[h].s - sA) / (sB - sA);
				var d = lerp(P[1], Q[1], tt) - band / 2;
				var C = cornerPoint(spn, hits[h].key), nn = MITER_NORMALS[hits[h].key];
				out.push([C[0] + d * (nn[0][0] + nn[1][0]), C[1] + d * (nn[0][1] + nn[1][1])]);
			}
		}
		return out;
	}
	// map an edge-local u-interval (today's per-edge coordinate) onto spine s (bottom/left reverse
	// direction to match the spine's travel sense on those runs).
	function edgeIntervalToS(name, u0, u1, layout, spn) {
		var e = layout.edges[name], edgeLen = e.len;
		if (u0 > u1) { var t = u0; u0 = u1; u1 = t; }
		if (name === 'top') { return [spn.runStart.top + u0, spn.runStart.top + u1]; }
		if (name === 'right') { return [spn.runStart.right + u0, spn.runStart.right + u1]; }
		if (name === 'bottom') { return [spn.runStart.bottom + (edgeLen - u1), spn.runStart.bottom + (edgeLen - u0)]; }
		return [spn.runStart.left + (edgeLen - u1), spn.runStart.left + (edgeLen - u0)];
	}

	// ---------- intervals / segmentation ----------
	function mergeIntervals(list) {
		var a = list.slice().sort(function (p, q) { return p[0] - q[0]; }), out = [];
		a.forEach(function (iv) {
			if (out.length && iv[0] <= out[out.length - 1][1]) { out[out.length - 1][1] = Math.max(out[out.length - 1][1], iv[1]); }
			else { out.push([iv[0], iv[1]]); }
		});
		return out;
	}
	// feats: [{type:'break', s0, s1}] on the closed spine loop (s0/s1 may fall outside
	// [0,S) -- wraps are split automatically). No features -> one closed segment (full:true).
	// Otherwise: rotate to a cut point in an uncovered gap, linear cursor sweep, then re-merge
	// the rotated domain's two 'weave' ends into one segment wrapping across the seam.
	function segmentLoop(S, feats) {
		if (!feats.length) { return [{ s0: 0, s1: S, full: true }]; }
		var pieces = [];
		feats.forEach(function (f) {
			var s0n = ((f.s0 % S) + S) % S, len = f.s1 - f.s0, s1n = s0n + len;
			if (s1n <= S + 1e-9) { pieces.push([s0n, Math.min(s1n, S)]); }
			else { pieces.push([s0n, S]); pieces.push([0, s1n - S]); }
		});
		var cover = mergeIntervals(pieces);
		var best = -1, cut = 0;
		for (var i = 0; i < cover.length; i++) {
			var a1 = cover[i][1], b0 = (i + 1 < cover.length) ? cover[i + 1][0] : cover[0][0] + S, g = b0 - a1;
			if (g > best) { best = g; cut = a1 + g / 2; }
		}
		if (best <= 1e-6) { return []; }                     // fully covered -> nothing to weave
		cut = ((cut % S) + S) % S;
		var rotFeats = feats.map(function (f) {
			var s0n = ((f.s0 - cut) % S + S) % S, len = f.s1 - f.s0;
			return { type: f.type, u0: s0n, u1: s0n + len };
		}).sort(function (p, q) { return p.u0 - q.u0; });
		var segs = [], cursor = 0, prevEnd = 'weave';
		function push(u0, u1, endA, endB) {
			if (u1 - u0 < 2) { return; }
			segs.push({ u0: u0, u1: u1, endA: endA, endB: endB });
		}
		rotFeats.forEach(function (f) {
			var u0c = clamp(f.u0, 0, S), u1c = clamp(f.u1, 0, S);
			if (u1c <= cursor) { return; }        // fully swallowed by prior coverage: pure no-op, must
			// not overwrite prevEnd (a feature fully inside earlier coverage must not relabel the
			// NEXT real segment's end kind).
			push(cursor, u0c, prevEnd, 'terminal');
			cursor = u1c;
			prevEnd = 'terminal';
		});
		push(cursor, S, prevEnd, 'weave');
		if (segs.length > 1 && segs[0].endA === 'weave' && segs[segs.length - 1].endB === 'weave') {
			var first = segs.shift(), last = segs.pop();
			var mergedLen = (S - last.u0) + first.u1;
			segs.push({ u0: last.u0, u1: last.u0 + mergedLen, endA: last.endA, endB: first.endB });
		}
		return segs.map(function (s) {
			return { s0: cut + s.u0, s1: cut + s.u1, endA: s.endA, endB: s.endB };
		});
	}
	// project padded, break_border-flagged slots onto each edge's band strip (unchanged: still
	// computed per-edge exactly as before; the result is mapped onto the spine by the caller).
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
	// Contract: gen(L, band, sp, opts) -> {strands:[{pts:[[u,v]..], color:int, closed:bool}], lam}
	// Open (opts.closed falsy) and closed modes both emit RAW full-amplitude sinusoids over the
	// whole length with a whole number of wave repeats (reps integral -> closed loops wrap
	// exactly). Open-segment end finishing (trim + fold caps) happens later in
	// buildSpineSegmentPolys via assignFolds -- there is no port easing here anymore.
	var patterns = {};
	patterns.plait = function (L, band, sp, opts) {
		var closedMode = !!(opts && opts.closed);
		var N = clamp(sp.count, 2, 4);
		var lam0 = Math.max(band * 1.5 * sp.scale, 8);
		var reps = Math.max(1, Math.round(L / lam0)), lam = L / reps;
		var wf = strandW(band, N, sp);
		var amp = Math.max(1, band / 2 - wf / 2 - outlineW(wf) - 1);
		var step = STEP(band), strands = [];
		for (var i = 0; i < N; i++) {
			var phi = i * Math.PI * 2 / N, pts = [];
			for (var u = 0; u <= L + 1e-6; u += step) {
				var uu = Math.min(u, L);
				pts.push([uu, band / 2 + amp * Math.sin(Math.PI * 2 * uu / lam + phi)]);
				if (uu >= L) { break; }
			}
			if (pts[pts.length - 1][0] < L) {
				pts.push([L, band / 2 + amp * Math.sin(Math.PI * 2 * L / lam + phi)]);
			}
			strands.push({ pts: pts, color: i, closed: closedMode });
		}
		return { strands: strands, lam: lam };
	};
	// order = [0,2,1,3]: pair A (k=0,1) sits outer/outer, pair B (k=2,3) inner/inner at the lanes
	// so the two-tone lattice mirrors symmetrically across the band.
	patterns.openweave = function (L, band, sp, opts) {
		var closedMode = !!(opts && opts.closed);
		var lam0 = Math.max(band * 2.6 * sp.scale, 10);
		var reps = Math.max(1, Math.round(L / lam0)), lam = L / reps;
		var wf = strandW(band, 4, sp), amp = Math.max(1, band / 2 - wf / 2 - outlineW(wf) - 1);
		var step = STEP(band), order = [0, 2, 1, 3], strands = [];
		for (var k = 0; k < 4; k++) {
			var pair = k >> 1, sign = (k & 1) ? -1 : 1, phase = pair * Math.PI / 2, pts = [];
			for (var u = 0; u <= L + 1e-6; u += step) {
				var uu = Math.min(u, L);
				pts.push([uu, band / 2 + sign * amp * Math.sin(Math.PI * 2 * uu / lam + phase)]);
				if (uu >= L) { break; }
			}
			if (pts[pts.length - 1][0] < L) {
				pts.push([L, band / 2 + sign * amp * Math.sin(Math.PI * 2 * L / lam + phase)]);
			}
			strands.push({ pts: pts, color: pair, closed: closedMode, lane: order[k] });
		}
		// Reorder so array index === lane index (buildSpineSegmentPolys pairs terminals by array
		// order = lane order). Strand array is emitted [A0,A1,B0,B1] (k order) but lanes are
		// [0,2,1,3]; sort by the `lane` tag so index 0..3 walks lanes 0..3 in page order.
		strands.sort(function (a, b) { return a.lane - b.lane; });
		strands.forEach(function (s) { delete s.lane; });
		return { strands: strands, lam: lam };
	};
	patterns.twist = function (L, band, sp, opts) {
		var closedMode = !!(opts && opts.closed);
		var sp2 = { count: 2, thickness: clamp(sp.thickness * 1.25, 0.3, 0.9), scale: sp.scale };
		var lam0 = Math.max(band * 1.15 * sp.scale, 8);
		var reps = Math.max(1, Math.round(L / lam0)), lam = L / reps;
		var wf = strandW(band, 2, sp2), amp = Math.max(1, band / 2 - wf / 2 - outlineW(wf) - 1);
		var step = STEP(band), strands = [];
		for (var k = 0; k < 2; k++) {
			var sign = k ? -1 : 1, pts = [];
			for (var u = 0; u <= L + 1e-6; u += step) {
				var uu = Math.min(u, L);
				pts.push([uu, band / 2 + sign * amp * Math.sin(Math.PI * 2 * uu / lam)]);
				if (uu >= L) { break; }
			}
			if (pts[pts.length - 1][0] < L) {
				pts.push([L, band / 2 + sign * amp * Math.sin(Math.PI * 2 * L / lam)]);
			}
			strands.push({ pts: pts, color: k, closed: closedMode });
		}
		return { strands: strands, lam: lam };
	};
	function effCount(cfg) {
		if (cfg.pattern === 'openweave') { return 4; }
		if (cfg.pattern === 'twist') { return 2; }
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

	// ---------- sub-polyline extraction: arc-length window around (idx,frac) ----------
	// Generic geometry helper (kept as a standalone reusable utility; render()/swatch() no longer
	// call this directly -- true cut gaps use splitByWindows below instead of an over-arc redraw).
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
			i++;
			if (i >= n) { if (!closed) { break; } i -= n; }
			// segLen(n-1) on an open polyline reads P(n-1)->P(0), a phantom wrap segment that
			// isn't part of the path -- only accumulate it when the polyline is actually closed.
			if (closed || i <= n - 2) { acc += segLen(i); }
		}
		if (!closed) { return out; }
		return out;
	}
	// sin of the angle between the two strands at a crossing: shallow crossing angles need a
	// longer under-strand hole to cover the true visual intersection footprint, else cuts bead.
	function crossingAngleSin(c, polys) {
		var A = polys[c.a].pts, B = polys[c.b].pts;
		var ai = clamp(c.ia, 0, A.length - 2), bi = clamp(c.ib, 0, B.length - 2);
		var ax = A[ai + 1][0] - A[ai][0], ay = A[ai + 1][1] - A[ai][1];
		var bx = B[bi + 1][0] - B[bi][0], by = B[bi + 1][1] - B[bi][1];
		var al = Math.hypot(ax, ay) || 1, bl = Math.hypot(bx, by) || 1;
		return Math.abs((ax / al) * (by / bl) - (ay / al) * (bx / bl));
	}
	// total arc length of a polyline (open: sum of consecutive segments; closed: + the wrap
	// segment back to pts[0]) -- used both by splitByWindows (domain length) and underWindow
	// (relative hole-size safety cap on short polylines, see below).
	function polylineLength(pts, closed) {
		var n = pts.length, L = 0, i;
		for (i = 1; i < n; i++) { L += Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]); }
		if (closed && n > 1) { L += Math.hypot(pts[0][0] - pts[n - 1][0], pts[0][1] - pts[n - 1][1]); }
		return L;
	}
	// per-crossing hole window for the UNDER strand (true cut gaps replace the old painted-casing
	// over-arc redraw): halfLen must clear the over strand's full outline footprint plus the gap;
	// shallow crossing angles need a longer hole, else the cut looks too thin / beads visually.
	function underWindow(c, polys, wf, wOut) {
		var underIsA = c.over === 'b';                      // over is the OTHER side -> this side is under
		var polyIdx = underIsA ? c.a : c.b;
		var idx = underIsA ? c.ia : c.ib, frac = underIsA ? c.fa : c.fb;
		var sinA = crossingAngleSin(c, polys);
		// Near-tangent contact is a FUSION, not an over/under: glancing overlaps (e.g. a cap arc
		// grazing a neighboring strand) must not cut a hole -- the paths simply merge.
		if (sinA < 0.25) { return null; }
		var halfLen = Math.min(wf * 3.5, (wOut / 2) / Math.max(0.35, sinA));
		// Safety cap: never let one hole exceed ~1/6 of the affected polyline's own length --
		// long weave strands are far longer than this bound; it only guards short shapes.
		var underLen = polylineLength(polys[polyIdx].pts, polys[polyIdx].closed);
		halfLen = Math.min(halfLen, underLen / 12);
		return { polyIdx: polyIdx, idx: idx, frac: frac, halfLen: halfLen };
	}
	// ---------- true cut gaps: split a polyline into surviving sub-polylines around a set of
	// under-strand "hole" windows (idx/frac use the same segment-index/fraction-along-segment
	// convention as findCrossings' ia/ib,fa/fb). No windows -> unchanged (closed stays closed).
	// A closed polyline with >=1 hole becomes open sub-paths (a stretch wrapping the seam is one
	// of them); an open polyline's holes never wrap -- they just truncate at its free ends.
	function splitByWindows(pts, closed, windows) {
		var n = pts.length;
		if (!windows || !windows.length || n < 2) { return [{ pts: pts.slice(), closed: !!closed }]; }
		var cum = [0], i;
		for (i = 1; i < n; i++) { cum[i] = cum[i - 1] + Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]); }
		var domainLen = polylineLength(pts, closed);
		if (!(domainLen > 0)) { return [{ pts: pts.slice(), closed: !!closed }]; }
		// point at arc-length s (0..domainLen); s>=domainLen on a closed path == pts[0] (the wrap).
		function posAt(s) {
			if (s <= 0) { return pts[0].slice(); }
			if (s >= cum[n - 1]) {
				if (!closed || s >= domainLen - 1e-9) { return (closed ? pts[0] : pts[n - 1]).slice(); }
				var tw = (s - cum[n - 1]) / (domainLen - cum[n - 1]);
				return [lerp(pts[n - 1][0], pts[0][0], tw), lerp(pts[n - 1][1], pts[0][1], tw)];
			}
			var lo = 0, hi = n - 1;
			while (hi - lo > 1) { var mid = (lo + hi) >> 1; if (cum[mid] <= s) { lo = mid; } else { hi = mid; } }
			var span = cum[hi] - cum[lo], t2 = span > 1e-9 ? (s - cum[lo]) / span : 0;
			return [lerp(pts[lo][0], pts[hi][0], t2), lerp(pts[lo][1], pts[hi][1], t2)];
		}
		// interior vertices strictly between s0/s1 plus interpolated exact-boundary endpoints.
		function extractRun(s0, s1) {
			var out = [posAt(s0)];
			for (var k = 0; k < n; k++) { if (cum[k] > s0 + 1e-6 && cum[k] < s1 - 1e-6) { out.push(pts[k].slice()); } }
			out.push(posAt(s1));
			return out;
		}
		var holes = [];
		windows.forEach(function (win) {
			var idx = clamp(win.idx, 0, n - 2), segLen = cum[idx + 1] - cum[idx];
			var center = cum[idx] + clamp(win.frac, 0, 1) * segLen;
			var s0 = center - win.halfLen, s1 = center + win.halfLen;
			if (closed) {                                    // wrap-aware, mirrors segmentLoop's own piece-splitting
				var len = s1 - s0, s0n = ((s0 % domainLen) + domainLen) % domainLen, s1n = s0n + len;
				if (s1n <= domainLen + 1e-9) { holes.push([s0n, Math.min(s1n, domainLen)]); }
				else { holes.push([s0n, domainLen]); holes.push([0, s1n - domainLen]); }
			} else {
				// Snap-to-end: a hole landing near an OPEN strand's end swallows the leftover nub
				// (e.g. a terminal's remnant past its last crossing would otherwise survive as a
				// detached sliver).
				if (s0 < 1.8 * win.halfLen) { s0 = -1; }
				if (s1 > domainLen - 1.8 * win.halfLen) { s1 = domainLen + 1; }
				holes.push([clamp(s0, 0, domainLen), clamp(s1, 0, domainLen)]);
			}
		});
		var merged = mergeIntervals(holes.filter(function (h) { return h[1] > h[0]; }));
		if (!merged.length) { return [{ pts: pts.slice(), closed: !!closed }]; }
		var out = [];
		function pushRun(s0, s1) { if (s1 - s0 >= 1) { out.push({ pts: extractRun(s0, s1), closed: false }); } }
		for (i = 0; i < merged.length - 1; i++) { pushRun(merged[i][1], merged[i + 1][0]); }
		if (closed) {
			var wrapLen = (domainLen - merged[merged.length - 1][1]) + merged[0][0];
			if (wrapLen >= 1) {
				var head = extractRun(merged[merged.length - 1][1], domainLen), tail = extractRun(0, merged[0][0]);
				out.push({ pts: head.concat(tail.slice(1)), closed: false });
			}
		} else {
			pushRun(0, merged[0][0]);
			pushRun(merged[merged.length - 1][1], domainLen);
		}
		return out;
	}

	// ---------- terminals (natural-fold end caps, generated in (u,v) BEFORE sweeping) ----------
	// Every pattern is a sinusoid bundle, so for any pair (i,j) each local extremum of the
	// separation D(u) = v_i(u) - v_j(u) is a point where the two strands share ONE slope s
	// (D'(u) = 0 -> v_i' = v_j' = s). Trimming both strands there and bridging with a TRUE
	// semicircle SHEARED by s is tangent-continuous by construction -- for every pattern,
	// density, and strand count. Pairs are processed outermost -> innermost and staggered
	// along the band (PAIR_STAGGER) so the nested wraps read like the references.
	// Cap semicircle bridging (ue,va)..(ue,vb), bulging toward the segment end (dir); exactly
	// anchored to the trimmed strand endpoints so merge/two-tone endpoints coincide. Callers
	// shear it by the pair's shared fold slope (shearPts).
	function rimArc(ue, va, vb, dir, band) {
		var mid = (va + vb) / 2, r = Math.abs(vb - va) / 2, reach = r * RIM_RADIUS_FACTOR;
		var sign = (va < vb) ? 1 : -1, pts = [];
		for (var k = 0; k <= CAP_SAMPLES; k++) {
			var th = k / CAP_SAMPLES * Math.PI;
			pts.push([ue + dir * Math.sin(th) * reach, mid - Math.cos(th) * r * sign]);
		}
		return pts;
	}
	// Curved-point (ogee) cap for the two-strand line -- bridges the SAME endpoints as rimArc
	// ((ue,va)->(ue,vb)) but as two convex quadratic arms meeting at a point at the apex
	// T = (ue + dir*reach, mid). The control points share each endpoint's v, so the tangent at
	// P0/P1 is purely +/-u (matching rimArc's contract) and stays tangent-clean after shearPts;
	// reach > shoulder makes the apex a cusp (rounded by stroke-linejoin -> the curved point). v
	// stays monotonic va->vb, so there is exactly one clean tip. Used by twist only (see endArcs).
	function pointArc(ue, va, vb, dir, band) {
		var mid = (va + vb) / 2, r = Math.abs(vb - va) / 2;
		var reach = r * POINT_REACH_FACTOR, h = reach * POINT_SHOULDER;
		var half = Math.max(2, Math.round(CAP_SAMPLES / 2));
		var P0 = [ue, va], T = [ue + dir * reach, mid], P1 = [ue, vb];
		var C1 = [ue + dir * h, va], C2 = [ue + dir * h, vb];
		function quad(A, C, B, incStart) {
			var out = [];
			for (var k = incStart ? 0 : 1; k <= half; k++) {
				var t = k / half, mt = 1 - t;
				out.push([
					mt * mt * A[0] + 2 * mt * t * C[0] + t * t * B[0],
					mt * mt * A[1] + 2 * mt * t * C[1] + t * t * B[1]
				]);
			}
			return out;
		}
		// arm 1 keeps both endpoints; arm 2 drops its first sample (== T, already emitted by arm 1).
		return quad(P0, C1, T, true).concat(quad(T, C2, P1, false));
	}
	function shearPts(pts, u0, s) {
		return pts.map(function (p) { return [p[0], p[1] + s * (p[0] - u0)]; });
	}
	// Closed teardrop leaf for the odd middle strand: leaves (ue,v0) toward dir with a
	// horizontal tangent, comes to a point at u = ue + dir*reach, and returns to the exact
	// same endpoint (tangent-symmetric) -- the pointed inner fold of the references. Both
	// endpoints coincide with the strand end so the outline pass unions it (no open tip).
	function leafFold(ue, v0, dir, reach, width) {
		var pts = [];
		for (var k = 0; k <= LEAF_SAMPLES; k++) {
			var t = k / LEAF_SAMPLES * Math.PI * 2;
			pts.push([ue + dir * reach * Math.sin(t / 2), v0 + width / 2 * Math.sin(t) * Math.sin(t / 2)]);
		}
		return pts;
	}
	// Symmetric two-arm leaf for the ODD outer pair (plait-3). At the middle strand's own extremum
	// the two outer strands are COINCIDENT at the foot (ue,vfoot) with equal-and-opposite arrival
	// slopes (+sMag / -sMag). Each strand extends into its OWN arm whose base tangent matches its
	// arrival slope (so the strand->leaf junction is ~0deg at ANY slope, however steep); the two
	// arms bulge apart and meet at a SHARED rounded tip at (ue + dir*reach, vfoot). Returns
	// [armPlus, armMinus] (each foot->tip), sharing the tip endpoint so the outline pass unions
	// them into one contiguous, mirror-symmetric pointed leaf. No shear is applied anywhere, so the
	// leaf is symmetric about the run-parallel axis through the foot and can never tilt/protrude.
	function leafFoldTangent(ue, vfoot, dir, reach, sMag) {
		var F = [ue, vfoot], T = [ue + dir * reach, vfoot];
		// bound the base handle so a steep arrival slope (sMag can be > 3) cannot balloon the arm's
		// v-rise past the band -- v-rise = sMag*hb is held to <= LEAF_TAN_RISE*reach.
		var hb = Math.min(reach * LEAF_TAN_BASE, reach * LEAF_TAN_RISE / Math.max(0.25, sMag));
		var ht = reach * LEAF_TAN_TIP;
		var half = Math.max(3, Math.round(LEAF_SAMPLES / 2));
		function arm(sign) {                               // sign +1 -> slope +sMag, -1 -> -sMag
			var P0 = F, P1 = [F[0] + dir * hb, F[1] + sign * sMag * hb], P2 = [T[0], T[1] + sign * ht], P3 = T, out = [];
			for (var k = 0; k <= half; k++) {
				var t = k / half, mt = 1 - t;
				out.push([
					mt * mt * mt * P0[0] + 3 * mt * mt * t * P1[0] + 3 * mt * t * t * P2[0] + t * t * t * P3[0],
					mt * mt * mt * P0[1] + 3 * mt * mt * t * P1[1] + 3 * mt * t * t * P2[1] + t * t * t * P3[1]
				]);
			}
			return out;
		}
		return [arm(1), arm(-1)];
	}
	// 3-point Lagrange interpolation of v (and dv/du) on a sampled strand polyline at u.
	function sampleVS(pts, u) {
		var n = pts.length;
		if (n < 3) {
			var sl = (pts[n - 1][1] - pts[0][1]) / ((pts[n - 1][0] - pts[0][0]) || 1);
			return [pts[0][1] + sl * (u - pts[0][0]), sl];
		}
		var lo = 0, hi = n - 1;
		while (hi - lo > 1) { var mid = (lo + hi) >> 1; if (pts[mid][0] <= u) { lo = mid; } else { hi = mid; } }
		var k = clamp(lo - 1, 0, n - 3);
		var x0 = pts[k][0], x1 = pts[k + 1][0], x2 = pts[k + 2][0];
		var y0 = pts[k][1], y1 = pts[k + 1][1], y2 = pts[k + 2][1];
		var d0 = (x0 - x1) * (x0 - x2), d1 = (x1 - x0) * (x1 - x2), d2 = (x2 - x0) * (x2 - x1);
		var v = y0 * (u - x1) * (u - x2) / d0 + y1 * (u - x0) * (u - x2) / d1 + y2 * (u - x0) * (u - x1) / d2;
		var s = y0 * (2 * u - x1 - x2) / d0 + y1 * (2 * u - x0 - x2) / d1 + y2 * (2 * u - x0 - x1) / d2;
		return [v, s];
	}
	// u of the vertex (dq/du = 0) of the quadratic through three samples, clamped into [x0,x2].
	function quadVertexU(x0, y0, x1, y1, x2, y2) {
		var d0 = (x0 - x1) * (x0 - x2), d1 = (x1 - x0) * (x1 - x2), d2 = (x2 - x0) * (x2 - x1);
		var A2 = y0 / d0 + y1 / d1 + y2 / d2;
		if (!(Math.abs(A2) > 1e-12)) { return x1; }
		var u = (y0 * (x1 + x2) / d0 + y1 * (x0 + x2) / d1 + y2 * (x0 + x1) / d2) / (2 * A2);
		return clamp(u, x0, x2);
	}
	// Candidate folds for a pair: local extrema of |D| on the shared sample grid, parabola-
	// refined, keeping only real separation extrema (>= FOLD_SEP_MIN of the pair's max
	// separation; the same-sign-neighborhood check skips near-zero kinks where the pair is
	// basically crossing). Returns ascending [{u}].
	function pairFoldCandidates(ptsI, ptsJ) {
		var n = Math.min(ptsI.length, ptsJ.length), D = [], k, a;
		for (k = 0; k < n; k++) { D.push(ptsI[k][1] - ptsJ[k][1]); }
		var maxSep = 0;
		for (k = 0; k < n; k++) { a = Math.abs(D[k]); if (a > maxSep) { maxSep = a; } }
		if (!(maxSep > 1e-6)) { return []; }
		var out = [];
		for (k = 1; k < n - 1; k++) {
			a = Math.abs(D[k]);
			if (!(a >= Math.abs(D[k - 1]) && a > Math.abs(D[k + 1]))) { continue; }
			if (a < FOLD_SEP_MIN * maxSep) { continue; }
			if (D[k - 1] * D[k + 1] <= 0) { continue; }
			out.push({ u: quadVertexU(ptsI[k - 1][0], D[k - 1], ptsI[k][0], D[k], ptsI[k + 1][0], D[k + 1]) });
		}
		return out;
	}
	// Terminal fold partner for strand i of N. EVEN N: the centerline-MIRROR partner i+N/2 --
	// mirror strands satisfy v_j = band - v_i, so their separation-maximum coincides with each
	// strand's own v'=0 peak => shared fold slope s=(v_i'+v_j')/2 = 0 EXACTLY => the bridging cap
	// needs no shear and cannot tilt outward (this is what kills the protruding "hook", proven for
	// all lam/scale/thickness/length). ODD N (only plait-3): no exact mirror exists, so keep the
	// nesting partner N-1-i; the odd terminal is anchored on the middle strand's symmetry axis
	// separately (see assignFolds odd branch). N=2: i+N/2 == N-1-i, so twist/pointArc is untouched.
	function foldPartner(i, N) { return (N % 2 === 0) ? (i + N / 2) : (N - 1 - i); }
	// Local extrema (zero slope) of a single strand's own v(u) -- middle-strand leaf anchors.
	function ownExtrema(pts) {
		var out = [], n = pts.length, k;
		for (k = 1; k < n - 1; k++) {
			var d1 = pts[k][1] - pts[k - 1][1], d2 = pts[k + 1][1] - pts[k][1];
			if (d1 * d2 > 0 || (d1 === 0 && d2 === 0)) { continue; }
			out.push({ u: quadVertexU(pts[k - 1][0], pts[k - 1][1], pts[k][0], pts[k][1], pts[k + 1][0], pts[k + 1][1]) });
		}
		return out;
	}
	// Choose per-pair fold points at both ends of an open segment: outermost pair takes the
	// candidate nearest each end whose cap still clears the segment boundary by CAP_END_MARGIN;
	// each inner pair staggers at least PAIR_STAGGER*lam further inward (never two caps stacked
	// at the same u); the odd middle strand staggers beyond the innermost pair, relaxing to
	// LEAF_STAGGER_RELAXED*lam on short segments (its extrema sit exactly lam/4 from the pair
	// folds, so the strict stagger would always skip to lam*3/4 -- too deep for thumbnails).
	// Returns { A:[{u,va,vb,s,sep}..], B:[..], midA:{u,v}|null, midB:{u,v}|null, lam } or null
	// when the segment is too short to fold cleanly (caller falls back to the connector path).
	function assignFolds(res, band, Lseg) {
		var strandsArr = res.strands, N = strandsArr.length, lam = res.lam;
		var nPairs = Math.floor(N / 2), margin = CAP_END_MARGIN * band;
		var A = [], B = [], prevA = null, prevB = null, i, k, F, reach;
		function foldAt(pi, pj, u) {
			var vi = sampleVS(strandsArr[pi].pts, u), vj = sampleVS(strandsArr[pj].pts, u);
			return { u: u, va: vi[0], vb: vj[0], s: (vi[1] + vj[1]) / 2, sep: Math.abs(vi[0] - vj[0]) };
		}
		// ODD N (plait-3): anchor the OUTER pair (0, N-1) on the MIDDLE strand's own symmetry-axis
		// extrema, where the two outer strands are coincident with equal-and-opposite slopes -> a
		// zero-shear symmetric leaf (leafFoldTangent). The middle strand takes its horizontal-tangent
		// leafFold at inner extrema. Coincident feet at a single u make a boundary-crossing bridge
		// structurally impossible (the failure mode of the rejected own-extremum approach).
		if (N % 2 === 1) {
			var midIdx = (N - 1) / 2, mPts = strandsArr[midIdx].pts;
			var o0 = strandsArr[0].pts, o2 = strandsArr[N - 1].pts, mc = ownExtrema(mPts);
			var oReach = Math.min(LEAF_REACH_FACTOR * lam, LEAF_REACH_MAX * band), uA = null, uB = null;
			for (k = mc.length - 1; k >= 0; k--) { if (mc[k].u + oReach <= Lseg - margin) { uB = mc[k].u; break; } }
			for (k = 0; k < mc.length; k++) { if (mc[k].u - oReach >= margin) { uA = mc[k].u; break; } }
			if (uA == null || uB == null || uB - uA < lam * 0.5) { return null; }
			function oFold(u) {
				var a = sampleVS(o0, u), b = sampleVS(o2, u);
				return { u: u, va: a[0], vb: b[0], s: (a[1] + b[1]) / 2, sep: Math.abs(a[0] - b[0]), leaf: true, si: a[1], sj: b[1] };
			}
			var oMA = null, oMB = null, ostag = [PAIR_STAGGER, LEAF_STAGGER_RELAXED], oi;
			for (oi = 0; oi < ostag.length; oi++) {
				oMA = null; oMB = null;
				for (k = mc.length - 1; k >= 0; k--) { if (mc[k].u <= uB - ostag[oi] * lam && mc[k].u > uA + 1e-6) { oMB = mc[k].u; break; } }
				for (k = 0; k < mc.length; k++) { if (mc[k].u >= uA + ostag[oi] * lam && mc[k].u < uB - 1e-6) { oMA = mc[k].u; break; } }
				if (oMA != null && oMB != null && oMB - oMA >= lam * 0.25) { break; }
			}
			if (oMA == null || oMB == null || oMB - oMA < lam * 0.25) { return null; }
			return { A: [oFold(uA)], B: [oFold(uB)], midA: { u: oMA, v: sampleVS(mPts, oMA)[0] }, midB: { u: oMB, v: sampleVS(mPts, oMB)[0] }, lam: lam };
		}
		// Stagger relaxes on short segments (panel swatches, narrow break runs): the full
		// PAIR_STAGGER nesting is tried first, then progressively tighter packings before
		// giving up to the degenerate connector.
		var relax = [PAIR_STAGGER, PAIR_STAGGER * 0.5, 0.08], rIdx, okAll = false;
		for (rIdx = 0; rIdx < relax.length && !okAll; rIdx++) {
			var stagP = relax[rIdx];
			A.length = 0; B.length = 0; prevA = null; prevB = null; okAll = true;
			for (i = 0; i < nPairs; i++) {
				var j = foldPartner(i, N);
				var cand = pairFoldCandidates(strandsArr[i].pts, strandsArr[j].pts);
				var fA = null, fB = null;
				for (k = cand.length - 1; k >= 0; k--) {
					F = foldAt(i, j, cand[k].u);
					reach = F.sep / 2 * RIM_RADIUS_FACTOR;
					if (F.u + reach > Lseg - margin) { continue; }
					if (prevB != null && F.u > prevB - stagP * lam) { continue; }
					fB = F; break;
				}
				for (k = 0; k < cand.length; k++) {
					F = foldAt(i, j, cand[k].u);
					reach = F.sep / 2 * RIM_RADIUS_FACTOR;
					if (F.u - reach < margin) { continue; }
					if (prevA != null && F.u < prevA + stagP * lam) { continue; }
					fA = F; break;
				}
				if (!fA || !fB || fB.u - fA.u < lam * 0.25) { okAll = false; break; }
				A.push(fA); B.push(fB); prevA = fA.u; prevB = fB.u;
			}
		}
		if (!okAll) { return null; }
		var midA = null, midB = null;
		if (N % 2 === 1) {
			var mPts = strandsArr[(N - 1) / 2].pts;
			var mc = ownExtrema(mPts), stag = [PAIR_STAGGER, LEAF_STAGGER_RELAXED], sIdx;
			for (sIdx = 0; sIdx < stag.length; sIdx++) {
				midA = null; midB = null;
				for (k = mc.length - 1; k >= 0; k--) {
					if (mc[k].u <= prevB - stag[sIdx] * lam) { midB = { u: mc[k].u, v: sampleVS(mPts, mc[k].u)[0] }; break; }
				}
				for (k = 0; k < mc.length; k++) {
					if (mc[k].u >= prevA + stag[sIdx] * lam) { midA = { u: mc[k].u, v: sampleVS(mPts, mc[k].u)[0] }; break; }
				}
				if (midA && midB && midB.u - midA.u >= lam * 0.25) { break; }
			}
			if (!midA || !midB || midB.u - midA.u < lam * 0.25) { return null; }
		}
		return { A: A, B: B, midA: midA, midB: midB, lam: lam };
	}
	// Trim an open strand to [uA,uB] with exact interpolated (u,v) endpoints. A densify point
	// is slipped just inside each cut (JUNCTION_DENSIFY*step) so the junction chord hugs the
	// true tangent -- keeps the <20-degree junction rule honest even at high density.
	function trimOpen(pts, uA, vA, uB, vB, step) {
		var hd = step * JUNCTION_DENSIFY, dense = (uB - uA) > 4 * hd, out = [[uA, vA]], k;
		if (dense) { out.push([uA + hd, sampleVS(pts, uA + hd)[0]]); }
		for (k = 0; k < pts.length; k++) {
			if (pts[k][0] > uA + hd + 1e-6 && pts[k][0] < uB - hd - 1e-6) { out.push(pts[k].slice()); }
		}
		if (dense) { out.push([uB - hd, sampleVS(pts, uB - hd)[0]]); }
		out.push([uB, vB]);
		return out;
	}
	// ---------- segment assembly (spine-local u,v -> page via sweepPt) ----------
	// Build the page-space polylines for one open spine segment, natural-fold end caps merged
	// in. seg: {s0,s1,endA,endB} with endA/endB always 'terminal' (or 'weave' pre-merge).
	// Patterns emit RAW sinusoids over the FULL segment length; per end, each nesting pair
	// (i, N-1-i) is trimmed at a shared-tangent separation extremum (assignFolds) and bridged
	// with a slope-sheared semicircle. dbg (optional, tests) collects junction metadata
	// {kind,end,a,b,c} page triples (angle at b = strand->cap tangent break) + dbg.degenerate.
	function buildSpineSegmentPolys(seg, cfg, layout, spn, dbg) {
		var band = layout.band, sp = cfg.strands;
		var Lseg = seg.s1 - seg.s0;
		var gen = patterns[cfg.pattern] || patterns.plait;
		var step = STEP(band);
		var res = null, folds = null, pi, pj;
		if (Lseg - 2 * TERM(band) >= band * 1.1) {
			res = gen(Lseg, band, sp, {});
			folds = assignFolds(res, band, Lseg);
		}
		if (folds) {
			for (pi = 0; pi < folds.A.length; pi++) {
				pj = foldPartner(pi, res.strands.length);
				var fa = folds.A[pi], fb = folds.B[pi];
				res.strands[pi].pts = trimOpen(res.strands[pi].pts, fa.u, fa.va, fb.u, fb.va, step);
				res.strands[pj].pts = trimOpen(res.strands[pj].pts, fa.u, fa.vb, fb.u, fb.vb, step);
			}
			if (folds.midA) {
				var mI = (res.strands.length - 1) / 2;
				res.strands[mI].pts = trimOpen(res.strands[mI].pts, folds.midA.u, folds.midA.v, folds.midB.u, folds.midB.v, step);
			}
		} else {                                           // degenerate: plain connector strands
			if (dbg) { dbg.degenerate = true; }
			var tC = TERM(band);
			res = {
				strands: [
					{ pts: [[tC, band * 0.35], [Lseg - tC, band * 0.35]], color: 0, closed: false },
					{ pts: [[tC, band * 0.65], [Lseg - tC, band * 0.65]], color: 1, closed: false }
				]
			};
			folds = {
				A: [{ u: tC, va: band * 0.35, vb: band * 0.65, s: 0, sep: band * 0.3 }],
				B: [{ u: Lseg - tC, va: band * 0.35, vb: band * 0.65, s: 0, sep: band * 0.3 }],
				midA: null, midB: null, lam: 0
			};
		}
		var N = res.strands.length;
		var paletteLen = (cfg.colors.strands && cfg.colors.strands.length) || 1;
		// band bounds for the odd-N leaf/teardrop: keep the centerline (plus stroke half-width) inside
		// the band so terminal ornament never bleeds past the edge (v-envelope invariant).
		var wfLoc = strandW(band, N, sp) * (cfg.pattern === 'twist' ? 1.25 : 1);
		var vLo = wfLoc / 2 + 0.5, vHi = band - wfLoc / 2 - 0.5;
		function clampV(pts) { return pts.map(function (p) { return [p[0], clamp(p[1], vLo, vHi)]; }); }
		if (dbg && !dbg.junctions) { dbg.junctions = []; }
		function pageJunction(kind, endName, p0, p1, p2) {
			if (!dbg || !p0 || !p1 || !p2) { return; }
			dbg.junctions.push({
				kind: kind, end: endName,
				a: sweepPt(spn, seg.s0 + p0[0], p0[1], band),
				b: sweepPt(spn, seg.s0 + p1[0], p1[1], band),
				c: sweepPt(spn, seg.s0 + p2[0], p2[1], band)
			});
		}
		// terminal arcs: pair lane i with lane N-1-i (fixed for both A and B passes; the anchor
		// geometry is per-pair fold points now, but the merge machinery is unchanged). Each pair
		// is visited once per open end (once by endArcs('A'), once by endArcs('B')).
		// First visit merges si+sj into one open polyline (owner = si, sj absorbed via sj.merged).
		// Second visit (sj already merged) finds si's two free ends now sitting at THIS end and
		// joins them with an arc, closing the polyline into a loop.
		function endArcs(atEnd) {
			var isA = atEnd === 'A';
			var dir = isA ? -1 : 1, list = isA ? folds.A : folds.B;
			for (var i = 0; i < list.length; i++) {
				var j = foldPartner(i, N);
				var si = res.strands[i], sj = res.strands[j];
				if (!si || !sj || si === sj) { continue; }
				var F = list[i];
				if (F.leaf) {
					// ODD outer pair (plait-3): coincident feet, equal-and-opposite slopes -> symmetric
					// two-arm leaf. Each strand extends into the arm matching its arrival slope; both arms
					// share the rounded tip (contiguous via the shared endpoint, unioned by the outline).
					var lreach = Math.min(LEAF_REACH_FACTOR * folds.lam, LEAF_REACH_MAX * band);
					var sMag = Math.max(Math.abs(F.si), Math.abs(F.sj));
					var larms = leafFoldTangent(F.u, F.va, dir, lreach, sMag);   // [armPlusSlope, armMinusSlope]
					larms = [clampV(larms[0]), clampV(larms[1])];
					// arm dv/du = sign*sMag/dir, so match each strand's arrival slope by sign(F.s*dir).
					var armI = (F.si * dir >= 0) ? larms[0] : larms[1];
					var armJ = (F.sj * dir >= 0) ? larms[0] : larms[1];
					if (isA) {
						pageJunction('leaf', atEnd, si.pts[1], si.pts[0], armI[1]);
						pageJunction('leaf', atEnd, sj.pts[1], sj.pts[0], armJ[1]);
						si.pts = armI.slice().reverse().concat(si.pts);
						sj.pts = armJ.slice().reverse().concat(sj.pts);
					} else {
						pageJunction('leaf', atEnd, si.pts[si.pts.length - 2], si.pts[si.pts.length - 1], armI[1]);
						pageJunction('leaf', atEnd, sj.pts[sj.pts.length - 2], sj.pts[sj.pts.length - 1], armJ[1]);
						si.pts = si.pts.concat(armI);
						sj.pts = sj.pts.concat(armJ);
					}
					continue;
				}
				// two-strand line ends in a curved point (ogee); plait/openweave keep the round rim.
				var capFn = (cfg.pattern === 'twist') ? pointArc : rimArc;
				var arc = shearPts(capFn(F.u, F.va, F.vb, dir, band), F.u, F.s);
				// junction metadata BEFORE any merge mutates si; sj.pts is never mutated by merges,
				// so its trimmed head/tail stays valid even when sj.merged.
				if (isA) {
					pageJunction('cap', atEnd, si.pts[1], si.pts[0], arc[1]);
					pageJunction('cap', atEnd, arc[arc.length - 2], sj.pts[0], sj.pts[1]);
				} else {
					pageJunction('cap', atEnd, si.pts[si.pts.length - 2], si.pts[si.pts.length - 1], arc[1]);
					pageJunction('cap', atEnd, arc[arc.length - 2], sj.pts[sj.pts.length - 1], sj.pts[sj.pts.length - 2]);
				}
				var sameColor = (si.color % paletteLen) === (sj.color % paletteLen);
				if (!sameColor) {
					// Two-tone terminal. Strand i owns the arc at every end it visits; strand j is
					// left as its own bare, unmerged polyline. Endpoints coincide (arc is anchored
					// exactly to both trimmed strand endpoints) so the outline pass unions them
					// seamlessly even though the fill paints never merge.
					if (isA) { si.pts = arc.slice().reverse().concat(si.pts); } else { si.pts = si.pts.concat(arc); }
					continue;
				}
				if (sj.merged) {                             // second visit for this pair -> close the loop
					if (si.merged || si.closed) { continue; }   // defensive only: pairing invariants make this unreachable
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
			// odd middle strand: closed leaf fold at its own zero-slope extremum (folds.midA/midB)
			var mF = isA ? folds.midA : folds.midB;
			if (mF && N % 2 === 1) {
				var m = res.strands[(N - 1) / 2];
				if (m && !m.merged && !m.closed) {              // m.closed: defensive only, never closed elsewhere
					var inner = list[list.length - 1];
					// Leaf width scales with the innermost pair's separation; but the odd-N outer pair
					// folds on the symmetry axis with COINCIDENT feet (sep~0), so fall back to the
					// middle strand's own full v-span (~2*amp) to keep the middle teardrop full-bodied.
					var innerSep = inner.sep;
					if (!(innerSep > band * 0.08)) {
						var mvs = m.pts.map(function (q) { return q[1]; });
						innerSep = Math.max.apply(null, mvs) - Math.min.apply(null, mvs);
					}
					var lf = clampV(leafFold(mF.u, mF.v, dir,
						Math.min(LEAF_REACH_FACTOR * folds.lam, LEAF_REACH_MAX * band),
						LEAF_WIDTH_FACTOR * innerSep));
					if (isA) {
						pageJunction('leaf', atEnd, m.pts[1], m.pts[0], lf[1]);
						m.pts = lf.slice().reverse().concat(m.pts.slice(1));
					} else {
						pageJunction('leaf', atEnd, m.pts[m.pts.length - 2], m.pts[m.pts.length - 1], lf[1]);
						m.pts = m.pts.concat(lf.slice(1));
					}
				}
			}
		}
		endArcs('A'); endArcs('B');
		var out = [];
		res.strands.forEach(function (s) {
			if (s.merged) { return; }
			out.push({ pts: sweepStrand(spn, seg.s0, s.pts, band), color: s.color, closed: !!s.closed });
		});
		return out;
	}
	// No features anywhere on the loop -> one continuous closed weave (whole spine, integral
	// repeats, no easing) instead of open segments with terminals.
	function buildClosedLoopPolys(cfg, layout, spn) {
		var band = layout.band, gen = patterns[cfg.pattern] || patterns.plait;
		var res = gen(spn.S, band, cfg.strands, { closed: true });
		var out = [];
		res.strands.forEach(function (s) {
			out.push({ pts: sweepStrand(spn, 0, s.pts, band), color: s.color, closed: true });
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
	// collectPolys: full border -> [{pts,color,closed}] page space (spine-swept weave).
	function collectPolys(cfg, W, H, slots) {
		var layout = frameLayout(cfg, W, H);
		var spn = buildSpine(layout, cfg.corners === 'pointed');
		var ab = autoBreaks(cfg, W, H, slots, layout);
		var feats = [];
		['top', 'right', 'bottom', 'left'].forEach(function (name) {
			var e = layout.edges[name];
			cfg.breaks.forEach(function (b) {
				if (b.edge !== name) { return; }
				var c = b.at / 100 * e.len, h = b.width / 100 * e.len / 2;
				var iv = edgeIntervalToS(name, c - h, c + h, layout, spn);
				feats.push({ type: 'break', s0: iv[0], s1: iv[1] });
			});
			ab[name].forEach(function (ivU) {
				var iv = edgeIntervalToS(name, ivU[0], ivU[1], layout, spn);
				feats.push({ type: 'break', s0: iv[0], s1: iv[1] });
			});
		});
		// merge plain breaks first so overlapping intervals don't create phantom segments
		var merged = mergeIntervals(feats.map(function (f) { return [f.s0, f.s1]; }))
			.map(function (iv) { return { type: 'break', s0: iv[0], s1: iv[1] }; });
		var segs = segmentLoop(spn.S, merged);
		var polys = [];
		if (segs.length === 1 && segs[0].full) {
			buildClosedLoopPolys(cfg, layout, spn).forEach(function (p) { polys.push(p); });
		} else {
			segs.forEach(function (seg) { buildSpineSegmentPolys(seg, cfg, layout, spn).forEach(function (p) { polys.push(p); }); });
		}
		return { layout: layout, polys: polys, spine: spn };
	}
	// ---------- true-cut assembly + paint (shared by render() and swatch()) ----------
	// Holes every polyline's under-strand crossing windows, then strokes ALL resulting sub-
	// polylines outline-then-fill in two passes (no third "over-arc redraw" pass -- the hole IS
	// the gap; page background shows through where paint used to be). paintOfFn differs between
	// callers (gradient-aware lookup in render(), flat palette lookup in swatch()).
	function paintCutStrokes(svg, polys, outlineColor, wf, wOut, paintOfFn) {
		var windowsByIdx = polys.map(function () { return []; });
		findCrossings(polys, wf * 0.8).forEach(function (c) {
			var w = underWindow(c, polys, wf, wOut);
			if (!w) { return; }                                 // tangent fusion -> no hole
			windowsByIdx[w.polyIdx].push({ idx: w.idx, frac: w.frac, halfLen: w.halfLen });
		});
		var cut = [];
		polys.forEach(function (p, i) {
			splitByWindows(p.pts, p.closed, windowsByIdx[i]).forEach(function (sp) {
				cut.push({ pts: sp.pts, closed: sp.closed, color: p.color });
			});
		});
		var gOutline = svgEl('g'), gFill = svgEl('g');
		cut.forEach(function (p) { strokePath(gOutline, polyPath(p.pts, p.closed), outlineColor, wOut); });
		cut.forEach(function (p) { strokePath(gFill, polyPath(p.pts, p.closed), paintOfFn(p.color), wf); });
		svg.appendChild(gOutline); svg.appendChild(gFill);
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
		var wf = strandW(band, N, cfg.strands) * (cfg.pattern === 'twist' ? 1.25 : 1), wOut = wf + 2 * outlineW(wf);
		function paintOf(colorIdx) { return paints[colorIdx % paints.length]; }
		paintCutStrokes(svg, polys, cfg.colors.outline, wf, wOut, paintOf);
		return svg;
	}
	// small horizontal weave strip for designer pattern thumbnails: straight open two-point
	// spine (constant normal), so it renders a straight strip with the same new-style end caps.
	function swatch(rawCfg, wPx, hPx) {
		var cfg = norm(rawCfg);
		cfg.enabled = true; cfg.breaks = []; cfg.autoBreak.enabled = false;
		cfg.strands.scale = Math.min(cfg.strands.scale, SWATCH_MAX_SCALE);
		var svg = svgEl('svg');
		svg.setAttribute('class', 'sc-knot-swatch');
		svg.setAttribute('viewBox', '0 0 ' + wPx + ' ' + hPx);
		var band = hPx * 0.8, len = wPx - 8, sy = hPx / 2;
		var table = [{ s: 0, x: 4, y: sy, nx: 0, ny: 1 }, { s: len, x: 4 + len, y: sy, nx: 0, ny: 1 }];
		var spn = { table: table, S: len, band: band };
		var layout = { band: band, S: hPx, W: wPx, H: hPx, edges: {}, corners: {} };
		var seg = { s0: 0, s1: len, endA: 'terminal', endB: 'terminal', med: null, medA: null, medB: null };
		var polys = buildSpineSegmentPolys(seg, cfg, layout, spn);
		var N = effCount(cfg);
		var wf = strandW(band, N, cfg.strands) * (cfg.pattern === 'twist' ? 1.25 : 1), wOut = wf + 2 * outlineW(wf);
		paintCutStrokes(svg, polys, cfg.colors.outline, wf, wOut, function (colorIdx) { return cfg.colors.strands[colorIdx % cfg.colors.strands.length]; });
		return svg;
	}

	var K = {
		render: render,
		swatch: swatch,
		_geom: {
			norm: norm, frameLayout: frameLayout, toPage: toPage, lane: lane, strandW: strandW, outlineW: outlineW,
			mergeIntervals: mergeIntervals, segmentLoop: segmentLoop, autoBreaks: autoBreaks,
			patterns: patterns, findCrossings: findCrossings, blendHex: blendHex, subPolyline: subPolyline,
			buildSpineSegmentPolys: buildSpineSegmentPolys, buildClosedLoopPolys: buildClosedLoopPolys, collectPolys: collectPolys,
			rimArc: rimArc, pointArc: pointArc, leafFold: leafFold, shearPts: shearPts, trimOpen: trimOpen,
			sampleVS: sampleVS, pairFoldCandidates: pairFoldCandidates, ownExtrema: ownExtrema, assignFolds: assignFolds,
			crossingAngleSin: crossingAngleSin, underWindow: underWindow, splitByWindows: splitByWindows,
			spine: spine, spineAt: spineAt, sweepPt: sweepPt, sweepStrand: sweepStrand, edgeIntervalToS: edgeIntervalToS,
			STEP: STEP, TERM: TERM, clamp: clamp, lerp: lerp, smooth: smooth, effCount: effCount
		}
	};
	w.ScrollKnot = K;
})(typeof window !== 'undefined' ? window : globalThis);
