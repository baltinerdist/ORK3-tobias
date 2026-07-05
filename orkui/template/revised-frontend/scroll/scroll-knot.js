/* scroll-knot.js — parametric Celtic knotwork border engine.
   Geometry core is DOM-free (unit-tested in Node); render()/swatch() build SVG.
   PDF-safe SVG subset only: paths + strokes + userSpaceOnUse linear gradients.
   Assembly model: a single continuous rounded-rectangle SPINE runs clockwise around the
   frame; patterns are generated in local (u,v) then swept along the spine so the weave
   flows continuously through corners. Breaks/hooks cut the spine into open segments (or
   leave it as one closed loop when there are no features). */
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
			corners: o(cfg.corners, 'woven'),
			breaks: Array.isArray(cfg.breaks) ? cfg.breaks : [],
			autoBreak: { enabled: ab.enabled == null ? true : !!ab.enabled, padding: num(ab.padding, 2) }
		};
	}

	// ---------- frame layout ----------
	// Edge-local frame: u along the edge run, v across the band (0..band). toPage maps to page px.
	// Kept for: autoBreaks' band-strip overlap math, corner box coords (hook spiral placement),
	// and as the per-edge u-domain that feature intervals are first computed in before being
	// mapped onto the spine (see edgeIntervalToS).
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
	function TERM(band) { return band * 0.55; }
	function EASE(lam, L) { return Math.min(lam * 0.35, L * 0.25); }             // shortened (was 0.6/0.4) -- kills long necks

	// ---------- tunable named constants (visual acceptance loop tunes these) ----------
	var SPINE_STEP = 2;                    // px, spine sample density
	var R_FACTOR = 0.75;                   // spine corner radius = clamp(band*R_FACTOR, 6, band)
	var RIM_RADIUS_FACTOR = 1.0;            // outer (lane0/laneN-1) cap: bulge/gap ratio (1 = true circle)
	var INNER_RADIUS_FACTOR = 1.05;        // nested inner cap radius = |gap|/2 * this
	var INNER_REACH_FACTOR = 0.55;         // nested inner cap bulge depth = radius * this
	var CURL_RADIUS_FACTOR = 0.18;         // odd-middle-strand curl radius = band * this
	var HOOK_MARGIN_FACTOR = 0.2;          // hook feature interval = quarter-arc span +/- band*this

	// ---------- spine (centerline rounded-rect the whole border weaves along) ----------
	// Walks CLOCKWISE starting where the top run begins (end of the TL corner arc):
	// top run -> TR arc -> right run -> BR arc -> bottom run (right->left) -> BL arc ->
	// left run (bottom->top) -> TL arc -> close. (nx,ny) is the unit INWARD normal.
	function buildSpine(layout) {
		var band = layout.band;
		var cx0 = layout.inset + band / 2, cy0 = layout.inset + band / 2;
		var cx1 = layout.W - layout.inset - band / 2, cy1 = layout.H - layout.inset - band / 2;
		var cw = cx1 - cx0, ch = cy1 - cy0;
		var R = clamp(band * R_FACTOR, 6, band || 6);
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
			table: table, S: S, R: R, band: band,
			runStart: { top: 0, right: Lt + La, bottom: Lt + La + Lr + La, left: Lt + La + Lr + La + Lt + La },
			arcStart: { tr: Lt, br: Lt + La + Lr, bl: Lt + La + Lr + La + Lt, tl: S - La },
			La: La, Lt: Lt, Lr: Lr, cx0: cx0, cy0: cy0, cx1: cx1, cy1: cy1
		};
	}
	function spine(cfg, W, H) { return buildSpine(frameLayout(cfg, W, H)); }
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
	// feats: [{type:'break'|'hook', s0, s1}] on the closed spine loop (s0/s1 may fall outside
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
			var kind = (f.type === 'hook') ? 'hook' : 'terminal';
			push(cursor, u0c, prevEnd, kind);
			cursor = u1c;
			prevEnd = kind;
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

	// Per-point end-easing shared by all pattern generators: blends the raw sinusoid value `vv`
	// toward whichever end (A at u=0 / B at u=L) is nearer, easing to that end's lane center over
	// `ease`. Only the closer end's window ever applies (always far shorter than L/2 for any
	// real weave run).
	function endBlend(vv, uu, L, ease, laneTarget) {
		var d = Math.min(uu, L - uu);
		return (ease > 0 && d < ease) ? lerp(laneTarget, vv, smooth(d / ease)) : vv;
	}

	// ---------- patterns ----------
	// Contract: gen(L, band, sp, opts) -> {strands:[{pts:[[u,v]..], color:int, closed:bool}]}
	// Open (opts.closed falsy): strands eased to lane centers over EASE at both ends, whole number
	// of wave repeats. Closed (opts.closed true): L = full spine length, reps still whole, but NO
	// end easing -- the sinusoid just continues seamlessly (reps integral -> wraps exactly).
	var patterns = {};
	patterns.plait = function (L, band, sp, opts) {
		var closedMode = !!(opts && opts.closed);
		var N = clamp(sp.count, 2, 4);
		var lam0 = Math.max(band * 1.5 * sp.scale, 8);
		var reps = Math.max(1, Math.round(L / lam0)), lam = L / reps;
		var wf = strandW(band, N, sp);
		var amp = Math.max(1, band / 2 - wf / 2 - outlineW(wf) - 1);
		var ease = closedMode ? 0 : EASE(lam, L), step = STEP(band), strands = [];
		for (var i = 0; i < N; i++) {
			var phi = i * Math.PI * 2 / N, pts = [], laneTarget = lane(i, N, band);
			for (var u = 0; u <= L + 1e-6; u += step) {
				var uu = Math.min(u, L);
				var vv = band / 2 + amp * Math.sin(Math.PI * 2 * uu / lam + phi);
				vv = closedMode ? vv : endBlend(vv, uu, L, ease, laneTarget);
				pts.push([uu, vv]);
				if (uu >= L) { break; }
			}
			if (pts[pts.length - 1][0] < L) {
				var vEnd = band / 2 + amp * Math.sin(Math.PI * 2 * L / lam + phi);
				vEnd = closedMode ? vEnd : endBlend(vEnd, L, L, ease, laneTarget);
				pts.push([L, vEnd]);
			}
			strands.push({ pts: pts, color: i, closed: closedMode });
		}
		return { strands: strands };
	};
	// order = [0,2,1,3]: pair A (k=0,1) sits outer/outer, pair B (k=2,3) inner/inner at the lanes
	// so the two-tone lattice mirrors symmetrically at the segment ports.
	patterns.openweave = function (L, band, sp, opts) {
		var closedMode = !!(opts && opts.closed);
		var lam0 = Math.max(band * 2.6 * sp.scale, 10);
		var reps = Math.max(1, Math.round(L / lam0)), lam = L / reps;
		var wf = strandW(band, 4, sp), amp = Math.max(1, band / 2 - wf / 2 - outlineW(wf) - 1);
		var ease = closedMode ? 0 : EASE(lam, L), step = STEP(band), order = [0, 2, 1, 3], strands = [];
		for (var k = 0; k < 4; k++) {
			var pair = k >> 1, sign = (k & 1) ? -1 : 1, phase = pair * Math.PI / 2, pts = [];
			var laneTarget = lane(order[k], 4, band);
			for (var u = 0; u <= L + 1e-6; u += step) {
				var uu = Math.min(u, L);
				var vv = band / 2 + sign * amp * Math.sin(Math.PI * 2 * uu / lam + phase);
				vv = closedMode ? vv : endBlend(vv, uu, L, ease, laneTarget);
				pts.push([uu, vv]);
				if (uu >= L) { break; }
			}
			if (pts[pts.length - 1][0] < L) {
				var vEnd = band / 2 + sign * amp * Math.sin(Math.PI * 2 * L / lam + phase);
				vEnd = closedMode ? vEnd : endBlend(vEnd, L, L, ease, laneTarget);
				pts.push([L, vEnd]);
			}
			strands.push({ pts: pts, color: pair, closed: closedMode, lane: order[k] });
		}
		// Reorder so array index === lane index (buildSpineSegmentPolys pairs terminals by array
		// order = lane order). Strand array is emitted [A0,A1,B0,B1] (k order) but lanes are
		// [0,2,1,3]; sort by the `lane` tag so index 0..3 walks lanes 0..3 in page order.
		strands.sort(function (a, b) { return a.lane - b.lane; });
		strands.forEach(function (s) { delete s.lane; });
		return { strands: strands };
	};
	patterns.twist = function (L, band, sp, opts) {
		var closedMode = !!(opts && opts.closed);
		var sp2 = { count: 2, thickness: clamp(sp.thickness * 1.25, 0.3, 0.9), scale: sp.scale };
		var lam0 = Math.max(band * 1.15 * sp.scale, 8);
		var reps = Math.max(1, Math.round(L / lam0)), lam = L / reps;
		var wf = strandW(band, 2, sp2), amp = Math.max(1, band / 2 - wf / 2 - outlineW(wf) - 1);
		var ease = closedMode ? 0 : EASE(lam, L), step = STEP(band), strands = [];
		for (var k = 0; k < 2; k++) {
			var sign = k ? -1 : 1, pts = [], laneTarget = lane(k, 2, band);
			for (var u = 0; u <= L + 1e-6; u += step) {
				var uu = Math.min(u, L);
				var vv = band / 2 + sign * amp * Math.sin(Math.PI * 2 * uu / lam);
				vv = closedMode ? vv : endBlend(vv, uu, L, ease, laneTarget);
				pts.push([uu, vv]);
				if (uu >= L) { break; }
			}
			if (pts[pts.length - 1][0] < L) {
				var vEnd = band / 2 + sign * amp * Math.sin(Math.PI * 2 * L / lam);
				vEnd = closedMode ? vEnd : endBlend(vEnd, L, L, ease, laneTarget);
				pts.push([L, vEnd]);
			}
			strands.push({ pts: pts, color: k, closed: closedMode });
		}
		return { strands: strands };
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

	// ---------- terminals (end caps, generated in (u,v) BEFORE sweeping) ----------
	// Rim pair (outermost lanes): a TRUE (non-squashed) semicircle -- same radius for both axes,
	// exactly anchored to (ue,va)/(ue,vb) so the two-tone split rule's shared endpoints still land
	// exactly -- so the outer strand reads as a rounded rim (image 8 style), not a flattened U.
	// (RIM_RADIUS_FACTOR ~1 keeps it a true circle; nudge slightly >1 for a touch more bulge.)
	function rimArc(ue, va, vb, dir, band) {
		var mid = (va + vb) / 2, r = Math.abs(vb - va) / 2, reach = r * RIM_RADIUS_FACTOR;
		var sign = (va < vb) ? 1 : -1, pts = [];
		for (var k = 0; k <= 20; k++) {
			var th = k / 20 * Math.PI;
			pts.push([ue + dir * Math.sin(th) * reach, mid - Math.cos(th) * r * sign]);
		}
		return pts;
	}
	// Nested inner pair(s): smaller, shallower arcs that sit inside the rim (short necks). Also
	// anchored exactly to (ue,va)/(ue,vb); only the bulge depth (reach) is scaled down, keeping
	// the v-span exact so it nests without a kink.
	function innerArc(ue, va, vb, dir) {
		var mid = (va + vb) / 2, r = Math.abs(vb - va) / 2, reach = r * INNER_RADIUS_FACTOR * INNER_REACH_FACTOR;
		var sign = (va < vb) ? 1 : -1, pts = [];
		for (var k = 0; k <= 20; k++) {
			var th = k / 20 * Math.PI;
			pts.push([ue + dir * Math.sin(th) * reach, mid - Math.cos(th) * r * sign]);
		}
		return pts;
	}
	// Spiral curl for the middle strand of an odd count.
	function curl(ue, v, dir, band) {
		var pts = [], r0 = band * CURL_RADIUS_FACTOR, cx = ue + dir * r0, turns = 1.5 * Math.PI * 2 * 0.75; // 270 deg
		for (var k = 0; k <= 24; k++) {
			var th = k / 24 * turns, r = r0 * (1 - 0.7 * (k / 24));
			pts.push([cx - dir * Math.cos(th) * r, v + Math.sin(th) * r]);
		}
		return pts;
	}

	// ---------- segment assembly (spine-local u,v -> page via sweepPt) ----------
	// Build the page-space polylines for one open spine segment, terminals merged in.
	// seg: {s0,s1,endA,endB} with endA/endB in {'terminal','hook'}.
	function buildSpineSegmentPolys(seg, cfg, layout, spn) {
		var band = layout.band, sp = cfg.strands;
		var tA = TERM(band), tB = TERM(band);
		var Lseg = seg.s1 - seg.s0;
		var Lw = Lseg - tA - tB;
		var gen = patterns[cfg.pattern] || patterns.plait;
		var res, off = tA;
		if (Lw < band * 1.1) {                             // degenerate: plain connector strands
			var pts0 = [[tA, band * 0.35], [Lseg - tB, band * 0.35]];
			var pts1 = [[tA, band * 0.65], [Lseg - tB, band * 0.65]];
			res = { strands: [{ pts: pts0, color: 0, closed: false }, { pts: pts1, color: 1, closed: false }] };
			off = 0;
		} else {
			res = gen(Lw, band, sp, {});
			res.strands.forEach(function (s) { s.pts = s.pts.map(function (p) { return [p[0] + off, p[1]]; }); });
		}
		var N = res.strands.length;
		var paletteLen = (cfg.colors.strands && cfg.colors.strands.length) || 1;
		// terminal arcs: pair lane i with lane N-1-i (fixed for both A and B passes); odd middle curls.
		// Each pair (i, N-1-i) is visited once per open end (once by endArcs('A'), once by endArcs('B')).
		// First visit merges si+sj into one open polyline (owner = si, sj absorbed via sj.merged).
		// Second visit (sj already merged) finds si's two free ends now sitting at THIS end and
		// joins them with an arc, closing the polyline into a loop.
		function endArcs(atEnd) {
			var isA = atEnd === 'A';
			var ue = isA ? tA : (Lseg - tB), dir = isA ? -1 : 1;
			for (var i = 0; i < Math.floor(N / 2); i++) {
				var j = N - 1 - i;
				var si = res.strands[i], sj = res.strands[j];
				if (!si || !sj || si === sj) { continue; }
				var va = lane(i, N, band), vb = lane(j, N, band);
				var arc = (i === 0) ? rimArc(ue, va, vb, dir, band) : innerArc(ue, va, vb, dir);
				var sameColor = (si.color % paletteLen) === (sj.color % paletteLen);
				if (!sameColor) {
					// Finding 1: two-tone terminal. Strand i owns the arc at every end it visits;
					// strand j is left as its own bare, unmerged polyline. Endpoints coincide (both
					// sample lane i/lane j at the same ue) so the outline pass unions them seamlessly
					// even though the fill paints never merge.
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
			if (N % 2 === 1) {
				var m = res.strands[(N - 1) / 2];
				if (m && !m.merged && !m.closed) {              // m.closed: defensive only, never closed elsewhere
					var c = curl(ue, lane((N - 1) / 2, N, band), dir, band);
					if (isA) { m.pts = c.slice().reverse().concat(m.pts); } else { m.pts = m.pts.concat(c); }
				}
			}
		}
		endArcs('A'); endArcs('B');
		var out = [];
		res.strands.forEach(function (s, idx) {
			if (s.merged) { return; }
			var pagePts = s.pts.map(function (p) { return sweepPt(spn, seg.s0 + p[0], p[1], band); });
			out.push({ pts: pagePts, color: s.color, closed: !!s.closed, _strandIdx: idx });
		});
		return out.map(function (o) { return { pts: o.pts, color: o.color, closed: o.closed }; });
	}
	// No features anywhere on the loop -> one continuous closed weave (whole spine, integral
	// repeats, no easing) instead of open segments with terminals.
	function buildClosedLoopPolys(cfg, layout, spn) {
		var band = layout.band, gen = patterns[cfg.pattern] || patterns.plait;
		var res = gen(spn.S, band, cfg.strands, { closed: true });
		var out = [];
		res.strands.forEach(function (s) {
			out.push({ pts: s.pts.map(function (p) { return sweepPt(spn, p[0], p[1], band); }), color: s.color, closed: true });
		});
		return out;
	}

	// ---------- hook corners (spiral curl drawn in the corner box; woven connectors DELETED) ----------
	var HOOK_DIR = { tl: [-1, 0], tr: [1, 0], bl: [-1, 0], br: [1, 0] };
	function hookPolys(key, layout) {
		var box = layout.corners[key], cx = box.x + layout.band / 2, cy = box.y + layout.band / 2;
		var dirA = HOOK_DIR[key], a0 = Math.atan2(dirA[1], dirA[0]) + Math.PI;
		var pts = [];
		for (var k = 0; k <= 32; k++) {
			var th = a0 + k / 32 * 1.5 * Math.PI, r = lerp(layout.band * 0.42, layout.band * 0.12, k / 32);
			pts.push([cx + Math.cos(th) * r, cy + Math.sin(th) * r]);
		}
		return [{ pts: pts, color: 0, closed: false }];
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
	// collectPolys: full border -> [{pts,color,closed}] page space (spine-swept weave + hook
	// spirals).
	function collectPolys(cfg, W, H, slots) {
		var layout = frameLayout(cfg, W, H);
		var spn = buildSpine(layout);
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
		var allFeats = merged.slice();
		if (cfg.corners === 'hook') {
			['tr', 'br', 'bl', 'tl'].forEach(function (key) {
				var a0 = spn.arcStart[key], a1 = a0 + spn.La, margin = layout.band * HOOK_MARGIN_FACTOR;
				allFeats.push({ type: 'hook', s0: a0 - margin, s1: a1 + margin });
			});
		}
		var segs = segmentLoop(spn.S, allFeats);
		var polys = [];
		if (segs.length === 1 && segs[0].full) {
			buildClosedLoopPolys(cfg, layout, spn).forEach(function (p) { polys.push(p); });
		} else {
			segs.forEach(function (seg) { buildSpineSegmentPolys(seg, cfg, layout, spn).forEach(function (p) { polys.push(p); }); });
		}
		if (cfg.corners === 'hook') {
			['tl', 'tr', 'bl', 'br'].forEach(function (key) { hookPolys(key, layout).forEach(function (p) { polys.push(p); }); });
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
			curl: curl, rimArc: rimArc, innerArc: innerArc, hookPolys: hookPolys,
			crossingAngleSin: crossingAngleSin, underWindow: underWindow, splitByWindows: splitByWindows,
			spine: spine, spineAt: spineAt, sweepPt: sweepPt, edgeIntervalToS: edgeIntervalToS,
			STEP: STEP, TERM: TERM, EASE: EASE, clamp: clamp, lerp: lerp, smooth: smooth, effCount: effCount
		}
	};
	w.ScrollKnot = K;
})(typeof window !== 'undefined' ? window : globalThis);
