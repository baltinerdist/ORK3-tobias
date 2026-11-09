'use strict';
// ffgen.cjs -- generator for free-form-corner borders (seed from ffseed.cjs): one closed strand made of the TL
// corner curve, mirrored to the other three corners, joined by straight sides.
//
//  curve    Catmull-Rom spline through the corner's control points, as cubic Beziers
//  frame    TL (S -> T), top line, TR, right line, BR, bottom line, BL, left line: a single closed path. The other
//           corners are TL turned (seed symmetry 'rotate') or reflected ('mirror'); see corners()
//  over     the TL curve's own crossings, in path order, take the seed's U / O labels; turning or reflecting the
//           drawing keeps which pass is drawn on top, so every corner uses the same labels. A move that changes the crossing
//           count or breaks alternation fails the topology gate.
//  paint    white halo stroke; black holes (the nonzero interior of each corner curve closed along the side
//           lines); ink stroke; fill stroke; then the over pass repainted around each crossing (ink, then fill a
//           little longer, butt caps), which cuts the under pass at the over strand's outline
const FF = require('./freeform.cjs');

const f = v => (Math.round(v * 1000) / 1000).toString();
const norm2 = v => { const l = Math.hypot(v[0], v[1]) || 1; return [v[0] / l, v[1] / l]; };

function paramsFromSeed(seed) {
	// straight runs (the sides and the corners' straight leads) have their own stroke: in the raster they read wider
	// than the curved knot strands (7 vs 6 px fill); off* = per-side sub-pixel offsets of those runs (px, +-0.6)
	const st = seed.stroke;
	return { xL: seed.frame.xL, xR: seed.frame.xR, yT: seed.frame.yT, yB: seed.frame.yB, w: st.strandPx, ink: st.inkPx, halo: st.haloPx,
		wS: st.sideStrandPx || st.strandPx, inkS: st.sideInkPx || st.inkPx, offL: 0, offR: 0, offT: 0, offB: 0, pts: seed.corner.points.map(p => p.slice()) };
}

// Catmull-Rom -> Bezier segments [p0, c1, c2, p1]
function bez(pts) {
	const n = pts.length, P = i => pts[Math.max(0, Math.min(n - 1, i))], out = [];
	for (let i = 0; i < n - 1; i++) {
		const a = P(i - 1), b = P(i), c = P(i + 1), d = P(i + 2);
		out.push([b, [b[0] + (c[0] - a[0]) / 6, b[1] + (c[1] - a[1]) / 6], [c[0] - (d[0] - b[0]) / 6, c[1] - (d[1] - b[1]) / 6], c]);
	}
	return out;
}
function sampleBez(segs, k) {
	const out = [segs[0][0].slice()];
	segs.forEach(([p0, c1, c2, p1]) => { for (let j = 1; j <= k; j++) { const t = j / k, m = 1 - t; out.push([m * m * m * p0[0] + 3 * m * m * t * c1[0] + 3 * m * t * t * c2[0] + t * t * t * p1[0], m * m * m * p0[1] + 3 * m * m * t * c1[1] + 3 * m * t * t * c2[1] + t * t * t * p1[1]]); } });
	return out;
}

// dark holes: every region the corner knot encloses. The strand band (centreline +- w/2) is stamped on a 0.5 px grid
// over the TL corner, the outside is flood-filled from the grid border, and what stays enclosed is a hole. Each
// hole is dilated by 1.5 px (so its edge tucks under the strand's fill and ink) and traced as a polygon.
const HOLES = new Map();
function holesTL(P, dilatePx) {
	const key = P.w.toFixed(3) + '|' + (dilatePx || 1.5) + '|' + P.pts.map(p => p[0].toFixed(3) + ',' + p[1].toFixed(3)).join(';');
	if (HOLES.has(key)) { return HOLES.get(key); }
	const poly = sampleBez(bez(P.pts), 12), R = 0.5;
	let x1 = 0, y1 = 0; poly.forEach(p => { x1 = Math.max(x1, p[0]); y1 = Math.max(y1, p[1]); });
	const x0 = -15, y0 = -15, W = Math.ceil((x1 + 15 - x0) / R), H = Math.ceil((y1 + 15 - y0) / R), m = new Uint8Array(W * H);
	const rr = P.w / 2 / R, rq = Math.ceil(rr);
	for (let k = 0; k < poly.length; k++) {
		const a = poly[k], b = poly[Math.min(poly.length - 1, k + 1)], L = Math.max(1, Math.ceil(Math.hypot(b[0] - a[0], b[1] - a[1]) / R));
		for (let t = 0; t < L; t++) {
			const cx = (a[0] + (b[0] - a[0]) * t / L - x0) / R, cy = (a[1] + (b[1] - a[1]) * t / L - y0) / R;
			for (let dy = -rq; dy <= rq; dy++) { for (let dx = -rq; dx <= rq; dx++) { if (dx * dx + dy * dy > rr * rr) { continue; } const X = Math.round(cx + dx), Y = Math.round(cy + dy); if (X >= 0 && Y >= 0 && X < W && Y < H) { m[Y * W + X] = 1; } } }
		}
	}
	// the side lines continue past the corner: mark them so the frame interior and the outside stay apart
	// (they are joined anyway at the grid border, which is what we want: both are "outside")
	const out = new Uint8Array(W * H), st = [];
	for (let x = 0; x < W; x++) { st.push(x, (H - 1) * W + x); } for (let y = 0; y < H; y++) { st.push(y * W, y * W + W - 1); }
	while (st.length) { const i = st.pop(); if (out[i] || m[i]) { continue; } out[i] = 1; const x = i % W, y = (i - x) / W; if (x > 0) { st.push(i - 1); } if (x < W - 1) { st.push(i + 1); } if (y > 0) { st.push(i - W); } if (y < H - 1) { st.push(i + W); } }
	const hole = new Uint8Array(W * H); for (let i = 0; i < W * H; i++) { hole[i] = !m[i] && !out[i] ? 1 : 0; }
	// dilate by 3 cells (1.5 px)
	const dil = new Uint8Array(W * H), D = Math.round((dilatePx || 1.5) / R);
	for (let y = 0; y < H; y++) { for (let x = 0; x < W; x++) { if (!hole[y * W + x]) { continue; } for (let dy = -D; dy <= D; dy++) { for (let dx = -D; dx <= D; dx++) { if (dx * dx + dy * dy > D * D) { continue; } const X = x + dx, Y = y + dy; if (X >= 0 && Y >= 0 && X < W && Y < H) { dil[Y * W + X] = 1; } } } } }
	// boundary edges (cell inside on the left), chained into loops, collinear runs merged
	const next = new Map(), at = (x, y) => x >= 0 && y >= 0 && x < W && y < H && dil[y * W + x];
	const add = (ax, ay, bx, by) => { next.set(ax + ',' + ay, [bx, by]); };
	for (let y = 0; y < H; y++) { for (let x = 0; x < W; x++) {
		if (!at(x, y)) { continue; }
		if (!at(x, y - 1)) { add(x + 1, y, x, y); } if (!at(x, y + 1)) { add(x, y + 1, x + 1, y + 1); }
		if (!at(x - 1, y)) { add(x, y, x, y + 1); } if (!at(x + 1, y)) { add(x + 1, y + 1, x + 1, y); }
	} }
	const loops = [];
	while (next.size) {
		const k0 = next.keys().next().value; let [x, y] = k0.split(',').map(Number); const lp = [[x, y]];
		for (let guard = 0; guard < 1e6; guard++) { const k = x + ',' + y, nx = next.get(k); if (!nx) { break; } next.delete(k); [x, y] = nx; if (x + ',' + y === k0) { break; } lp.push([x, y]); }
		const simp = lp.filter((p, i) => { const a = lp[(i - 1 + lp.length) % lp.length], b = lp[(i + 1) % lp.length]; return (p[0] - a[0]) * (b[1] - p[1]) - (p[1] - a[1]) * (b[0] - p[0]) !== 0; });
		loops.push(simp.map(p => [x0 + p[0] * R, y0 + p[1] * R]));
	}
	const res = { loops, holeCells: hole.reduce((a, v) => a + v, 0) };
	if (HOLES.size > 200) { HOLES.clear(); } HOLES.set(key, res);
	return res;
}

// the four corner transforms (TL-relative point -> page) and whether the corner is traversed backwards.
// 'rotate' (C4): TR = TL turned 90 degrees clockwise, BR 180, BL 270; every corner is traversed forwards and the
// alternation reads the same way round the frame. 'mirror': TR / BL / BR are TL reflected (a reflection of an
// alternating knot shows the opposite over / under at every crossing).
function corners(P, kind) {
	if (kind === 'mirror') {
		return [
			{ name: 'TL', T: p => [P.xL + p[0], P.yT + p[1]], rev: false },
			{ name: 'TR', T: p => [P.xR - p[0], P.yT + p[1]], rev: true },
			{ name: 'BR', T: p => [P.xR - p[0], P.yB - p[1]], rev: false },
			{ name: 'BL', T: p => [P.xL + p[0], P.yB - p[1]], rev: true },
		];
	}
	return [
		{ name: 'TL', T: p => [P.xL + p[0], P.yT + p[1]], rev: false },
		{ name: 'TR', T: p => [P.xR - p[1], P.yT + p[0]], rev: false },
		{ name: 'BR', T: p => [P.xR - p[0], P.yB - p[1]], rev: false },
		{ name: 'BL', T: p => [P.xL + p[1], P.yB - p[0]], rev: false },
	];
}

// TL crossings with over / under from the seed's labels
function crossingsOf(P, seed) {
	const segs = bez(P.pts), poly = sampleBez(segs, 8), X = FF.selfCross(poly);
	const visits = [];
	X.forEach((c, k) => { visits.push({ k, s: c.i + c.ti, pass: 'i' }, { k, s: c.j + c.tj, pass: 'j' }); });
	visits.sort((a, b) => a.s - b.s);
	const order = seed.corner.order, ok = visits.length === order.length;
	const over = X.map(() => null);
	if (ok) { visits.forEach((v, idx) => { if (order[idx] === 'O') { over[v.k] = v.pass; } }); }
	const topoOK = ok && over.every(o => o);
	return { poly, X, over, topoOK, count: X.length };
}

// sub-polyline of poly around arc position s0 (index units) covering +-h px
function around(poly, s0, h) {
	const i0 = Math.floor(s0), t0 = s0 - i0, c = [poly[i0][0] + (poly[i0 + 1][0] - poly[i0][0]) * t0, poly[i0][1] + (poly[i0 + 1][1] - poly[i0][1]) * t0];
	const back = [], fwd = [];
	let acc = 0, prev = c; for (let i = i0; i >= 0 && acc < h; i--) { const q = poly[i], L = Math.hypot(q[0] - prev[0], q[1] - prev[1]); if (acc + L >= h) { const r = (h - acc) / L; back.push([prev[0] + (q[0] - prev[0]) * r, prev[1] + (q[1] - prev[1]) * r]); acc = h; break; } acc += L; back.push(q); prev = q; }
	acc = 0; prev = c; for (let i = i0 + 1; i < poly.length && acc < h; i++) { const q = poly[i], L = Math.hypot(q[0] - prev[0], q[1] - prev[1]); if (acc + L >= h) { const r = (h - acc) / L; fwd.push([prev[0] + (q[0] - prev[0]) * r, prev[1] + (q[1] - prev[1]) * r]); acc = h; break; } acc += L; fwd.push(q); prev = q; }
	return back.reverse().concat([c], fwd);
}
const dPoly = ps => 'M' + ps.map(p => f(p[0]) + ' ' + f(p[1])).join('L');

// ---- openings with P-curl ends (single-strand frames). The top and bottom sides are broken at their centre for the
// arms and the award detail. At each end the strand runs on past the crossing point X, rises into a round bowl that
// curls OUTWARD (away from the page), comes back down as a short stem and crosses its own incoming run at 90 degrees
// at X, ending a little inside the band with a round inked end: a "P" (mirrored on the other side of the opening,
// turned with the corners at the bottom). Local frame at an end: u along the strand towards the opening, v outward;
// the bowl's centreline is the circle centred (R, R), radius R, tangent to the run at (R, 0) and to the stem u = 0.
// Over / under continues the corner's alternation: the run's pass at X is the opposite of the nearest corner
// crossing visit, and the stem's pass the opposite of the run's.
const KAPPA = 0.5523;
// the bowl is an ellipse (Rx along the strand, Ry outward): the margin outside the band limits Ry, and a wider bowl
// keeps its hole readable at that height
function pCurl(X, t, n, Rx, Ry, tail) {
	const P = (u, v) => [X[0] + u * t[0] + v * n[0], X[1] + u * t[1] + v * n[1]], kx = KAPPA * Rx, ky = KAPPA * Ry, pt = (u, v) => P(u, v).map(f).join(' ');
	// approach order: run to (Rx, 0), three quarter arcs to (0, Ry), stem down to (0, -tail)
	const fwd = 'L' + pt(Rx, 0) + 'C' + pt(Rx + kx, 0) + ' ' + pt(2 * Rx, Ry - ky) + ' ' + pt(2 * Rx, Ry) + 'C' + pt(2 * Rx, Ry + ky) + ' ' + pt(Rx + kx, 2 * Ry) + ' ' + pt(Rx, 2 * Ry)
		+ 'C' + pt(Rx - kx, 2 * Ry) + ' ' + pt(0, Ry + ky) + ' ' + pt(0, Ry) + 'L' + pt(0, -tail);
	const rev = 'M' + pt(0, -tail) + 'L' + pt(0, Ry) + 'C' + pt(0, Ry + ky) + ' ' + pt(Rx - kx, 2 * Ry) + ' ' + pt(Rx, 2 * Ry) + 'C' + pt(Rx + kx, 2 * Ry) + ' ' + pt(2 * Rx, Ry + ky) + ' ' + pt(2 * Rx, Ry)
		+ 'C' + pt(2 * Rx, Ry - ky) + ' ' + pt(Rx + kx, 0) + ' ' + pt(Rx, 0);
	const hole = [P(0, 0), P(Rx, 0)];
	for (let a = 0; a <= 270; a += 10) { const th = a * Math.PI / 180; hole.push(P(Rx + Rx * Math.sin(th), Ry - Ry * Math.cos(th))); }
	return { fwd, rev, hole, X, t, n };
}

// ---- Ash inked style (opt.gap): bold ink, no dark fill, and every under pass truly cut with a clear gap of
// ground each side of the over strand (same construction as gen.cjs: centreline sampled, the stretch within
// w/2 + ink + gap of each under crossing removed, pieces drawn with butt caps, fill trimmed by the ink width).
// Strand ends that are real ends (the P stems) get round inked caps.
function sampleOpen(sub) {
	const G = require('./gen.cjs'), pts = G.samplePath(sub);
	return pts;
}
function cutOpen(pts, centres, r, trim, closed) {
	const A = [0]; for (let i = 1; i < pts.length; i++) { A.push(A[i - 1] + Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1])); }
	const T = A[A.length - 1];
	const at = s => { let lo = 0, hi = A.length - 1; while (hi - lo > 1) { const m = (lo + hi) >> 1; if (A[m] <= s) { lo = m; } else { hi = m; } } const t = (s - A[lo]) / ((A[hi] - A[lo]) || 1); return [pts[lo][0] + (pts[hi][0] - pts[lo][0]) * t, pts[lo][1] + (pts[hi][1] - pts[lo][1]) * t]; };
	const cs = centres.slice().sort((a, b) => a - b), out = [];
	if (closed) { const G = require('./gen.cjs'); return G.cutPolyline(pts, cs, r, trim).map(q => ({ pts: q.pts, s0: null, s1: null })); }
	// open strand: kept intervals between the ends and the cuts (trim only at cut faces, not at the strand's ends)
	const bounds = [[0, false]]; cs.forEach(c => { bounds.push([c - r - trim, true], [c + r + trim, true]); }); bounds.push([T, false]);
	for (let k = 0; k < bounds.length; k += 2) {
		const [s0, cut0] = bounds[k], [s1, cut1] = bounds[k + 1]; if (s1 - s0 < 0.5) { continue; }
		const seg = [at(s0)]; for (let s = Math.ceil(s0); s < s1; s += 1) { seg.push(at(s)); } seg.push(at(s1));
		out.push({ pts: seg, end0: !cut0 && s0 === 0, end1: !cut1 && s1 === T });
	}
	return out;
}

function build(seed, P, opt) {
	opt = opt || {};
	const W = opt.W || seed.image.w, H = opt.H || seed.image.h;
	const colours = Object.assign({ ink: '#000000', fill: '#2a5bd7', halo: '#ffffff', dark: '#000000' }, opt.colours || {});
	const segs = bez(P.pts), C = corners(P, seed.symmetry.kind), cx = crossingsOf(P, seed);
	// the closed path
	let d = '';
	C.forEach((c, ci) => {
		const sg = c.rev ? segs.slice().reverse().map(([a, b, e, g]) => [g, e, b, a]) : segs;
		const tp = q => c.T(q);
		const s0 = tp(sg[0][0]);
		d += (ci === 0 ? 'M' : 'L') + f(s0[0]) + ' ' + f(s0[1]);
		sg.forEach(([, c1, c2, p1]) => { const a = tp(c1), b = tp(c2), e = tp(p1); d += 'C' + f(a[0]) + ' ' + f(a[1]) + ' ' + f(b[0]) + ' ' + f(b[1]) + ' ' + f(e[0]) + ' ' + f(e[1]); });
	});
	d += 'Z';
	// openings: rebuild the path as two open strands with P-curl ends (see pCurl)
	let ends = null;
	if (opt.cuts) {
		if (seed.symmetry.kind === 'mirror') { throw new Error('openings: P-curl ends assume rotation symmetry'); }
		const Ry = opt.cuts.radius || 7.5, Rx = opt.cuts.width || 10, tail = opt.cuts.tail || 8, G = opt.cuts.gap || 0.30 * (P.xR - P.xL), cxF = (P.xL + P.xR) / 2;
		// opt.cuts.gapBottom: a different opening at the bottom (default: the same as the top)
		const GB = opt.cuts.gapBottom || G, reach = 2 * Rx + P.w / 2 + P.ink, xa = cxF - G / 2 - reach, xb = cxF + G / 2 + reach, xaB = cxF - GB / 2 - reach, xbB = cxF + GB / 2 + reach, ord = seed.corner.order;
		const opp = c => c === 'O' ? 'U' : 'O';
		ends = {
			tl: Object.assign(pCurl([xa, P.yT], [1, 0], [0, -1], Rx, Ry, tail), { run: opp(ord[ord.length - 1]) }),
			tr: Object.assign(pCurl([xb, P.yT], [-1, 0], [0, -1], Rx, Ry, tail), { run: opp(ord[0]) }),
			br: Object.assign(pCurl([xbB, P.yB], [-1, 0], [0, 1], Rx, Ry, tail), { run: opp(ord[ord.length - 1]) }),
			bl: Object.assign(pCurl([xaB, P.yB], [1, 0], [0, 1], Rx, Ry, tail), { run: opp(ord[0]) }),
		};
		// the corner curve is trimmed where its lead settles onto the side line (past the knot's last crossing): the
		// run from there to the P is a straight line
		const pts0 = P.pts, nP = pts0.length;
		let iA = 0; while (iA < nP - 1 && Math.abs(pts0[iA][0]) < 1 && pts0[iA][1] > 70) { iA++; }        // S lead: settled while v > 70
		let iB = nP - 1; while (iB > 0 && Math.abs(pts0[iB][1]) < 1 && pts0[iB][0] > 70) { iB--; }       // T lead: settled while u > 70
		ends.iA = iA; ends.iB = iB;
		if (Math.min(xa, xaB) - (P.xL + pts0[iB][0]) < P.w + 2 * P.ink) { throw new Error('openings: the P would overlap the corner knot; narrow the opening'); }
		const cmd = (c, i0, i1) => { const tp = q => c.T(q); let o = ''; segs.slice(i0, i1).forEach(([, c1, c2, p1]) => { const a = tp(c1), b = tp(c2), e = tp(p1); o += 'C' + f(a[0]) + ' ' + f(a[1]) + ' ' + f(b[0]) + ' ' + f(b[1]) + ' ' + f(e[0]) + ' ' + f(e[1]); }); return o; };
		const S = c => c.T(segs[0][0]), L = q => 'L' + f(q[0]) + ' ' + f(q[1]);
		const [TL, TR, BR, BL] = C;
		// right half: top-right end -> run -> TR (from its trimmed S lead) -> right side -> BR (to its trimmed T lead) -> bottom-right end
		d = ends.tr.rev + L(TR.T(pts0[iA])) + cmd(TR, iA, nP - 1) + L(S(BR)) + cmd(BR, 0, iB);
		d += ends.br.fwd;
		// left half: bottom-left end -> BL (trimmed S lead) -> left side -> TL (trimmed T lead) -> top-left end
		d += ends.bl.rev + L(BL.T(pts0[iA])) + cmd(BL, iA, nP - 1) + L(S(TL)) + cmd(TL, 0, iB) + ends.tl.fwd;
	}
	// dark holes, traced once in TL coordinates, then placed in every corner
	// cut style with dark holes: tuck each hole past the strand's centreline so neighbouring holes meet under a gap
	const HL = holesTL(P, opt.gap !== undefined && opt.gap !== null && opt.dark ? P.w / 2 + 0.5 * P.ink : 1.5);
	const darkD = C.map(c => HL.loops.map(lp => dPoly(lp.map(c.T)) + 'Z').join(''));
	const endList = ends ? [ends.tl, ends.tr, ends.br, ends.bl] : [];
	endList.forEach(e => darkD.push(dPoly(e.hole) + 'Z'));
	// patches over each crossing's over pass
	const h = P.w / 2 + P.ink + 1.5, patches = [];
	if (cx.topoOK) {
		cx.X.forEach((x, k) => {
			const s = cx.over[k] === 'i' ? x.i + x.ti : x.j + x.tj;
			const loc = around(cx.poly, s, h), locF = around(cx.poly, s, h + 1);
			C.forEach(c => { patches.push({ d: dPoly(loc.map(c.T)), df: dPoly(locF.map(c.T)) }); });
		});
	}
	if (ends) {
		// the over pass at each P crossing: the run (along t) or the stem (along -n)
		endList.forEach(e => {
			const dir = e.run === 'O' ? e.t : e.n, X = e.X, seg = q => 'M' + f(X[0] - dir[0] * q) + ' ' + f(X[1] - dir[1] * q) + 'L' + f(X[0] + dir[0] * q) + ' ' + f(X[1] + dir[1] * q);
			patches.push({ d: seg(h), df: seg(h + 1) });
		});
	}
	// straight side runs: from where one corner's T lead leaves its knot to where the next corner's S lead enters it
	// opt.capLeads: ...and never into the knot itself: a lead that runs straight on through the knot (as a bar of it)
	// stops at the knot's extent plus a strand width, so the knot's own bars keep the curved stroke. Off for the
	// matched design (fitted without it); on where the leads are snapped straight (export-scrollery.cjs)
	const pts = P.pts, n = pts.length, capL = !!opt.capLeads;
	let extU = 0, extV = 0; pts.forEach(p => { if (p[1] > 3) { extU = Math.max(extU, p[0]); } if (p[0] > 3) { extV = Math.max(extV, p[1]); } });
	let iS = 0; while (iS < n - 1 && Math.abs(pts[iS + 1][0]) < 0.4 && (!capL || pts[iS + 1][1] >= extV + P.w)) { iS++; }
	let iT = n - 1; while (iT > 0 && Math.abs(pts[iT - 1][1]) < 0.4 && (!capL || pts[iT - 1][0] >= extU + P.w)) { iT--; }
	// each straight run is drawn as two tapered polygons (ink, fill) whose width eases from the curved stroke's at the
	// ends to the straight stroke's over TAPER px, so there is no step where a side meets a corner lead
	const sideInk = [], sideFill = [], TAPER = 8;
	const offs = [['offT', [0, 1]], ['offR', [1, 0]], ['offB', [0, 1]], ['offL', [1, 0]]];
	// ext: the fill polygon runs ext px past the ink polygon at both ends, so the ink polygon's anti-aliased end edge
	// leaves no seam across the strand
	const band = (a0, b0, h0, h1, ext) => {
		ext = ext || 0;
		const L0 = Math.hypot(b0[0] - a0[0], b0[1] - a0[1]), t = [(b0[0] - a0[0]) / L0, (b0[1] - a0[1]) / L0];
		const a = [a0[0] - t[0] * ext, a0[1] - t[1] * ext], b = [b0[0] + t[0] * ext, b0[1] + t[1] * ext];
		const L = L0 + 2 * ext, nr = [-t[1], t[0]], k = Math.min(TAPER + ext, L / 2);
		const at = (p, s, h) => [p[0] + t[0] * s + nr[0] * h, p[1] + t[1] * s + nr[1] * h];
		const q = [at(a, 0, h0), at(a, k, h1), at(b, -k, h1), at(b, 0, h0), at(b, 0, -h0), at(b, -k, -h1), at(a, k, -h1), at(a, 0, -h0)];
		return dPoly(q) + 'Z';
	};
	if (P.wS) {
		C.forEach((c, ci) => {
			const nx = C[(ci + 1) % 4], a0 = c.T(pts[iT]), b0 = nx.T(pts[iS]), [k, dir] = offs[ci], o = P[k] || 0;
			const a = [a0[0] + dir[0] * o, a0[1] + dir[1] * o], b = [b0[0] + dir[0] * o, b0[1] + dir[1] * o];
			const runs = [[a, b]];
			if (ends && (ci === 0 || ci === 2)) {
				// a broken side: two runs, each stopping short of its end's crossing
				// from where the trimmed corner leads meet the side line to just short of each end's crossing
				const e1 = ci === 0 ? ends.tl : ends.br, e2 = ci === 0 ? ends.tr : ends.bl, m = h + 2;
				const stop = e => [e.X[0] - e.t[0] * m + dir[0] * o, e.X[1] - e.t[1] * m + dir[1] * o], sh = q => [q[0] + dir[0] * o, q[1] + dir[1] * o];
				runs.splice(0, 1, [sh(c.T(pts[ends.iB])), stop(e1)], [stop(e2), sh(nx.T(pts[ends.iA]))]);
			}
			runs.forEach(([p, q]) => { if (Math.hypot(q[0] - p[0], q[1] - p[1]) > 20) { sideInk.push(band(p, q, P.w / 2 + P.ink, P.wS / 2 + P.inkS)); sideFill.push(band(p, q, P.w / 2, P.wS / 2, 1)); } });
		});
	}
	if (opt.gap !== undefined && opt.gap !== null) {
		// under crossings in page coordinates, with the under pass's direction
		const unders = [];
		if (cx.topoOK) {
			const tan = (poly, s0) => { const i = Math.min(poly.length - 2, Math.max(0, Math.floor(s0))); return [poly[i + 1][0] - poly[i][0], poly[i + 1][1] - poly[i][1]]; };
			cx.X.forEach((x, k) => {
				const su = cx.over[k] === 'i' ? x.j + x.tj : x.i + x.ti, tu = tan(cx.poly, su), p0 = [x.x, x.y];
				C.forEach(c => { const a = c.T(p0), b = c.T([p0[0] + tu[0], p0[1] + tu[1]]); unders.push({ p: a, dir: norm2([b[0] - a[0], b[1] - a[1]]) }); });
			});
		}
		if (ends) { [ends.tl, ends.tr, ends.br, ends.bl].forEach(e => { unders.push({ p: e.X, dir: e.run === 'U' ? e.t : e.n }); }); }
		const r = P.w / 2 + P.ink + opt.gap, ink = [], fill = [], caps = [];
		d.split(/(?=M)/).filter(x => x.trim()).forEach(sub => {
			const closed = /Z\s*$/.test(sub), pts = sampleOpen(sub);
			const A = [0]; for (let i = 1; i < pts.length; i++) { A.push(A[i - 1] + Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1])); }
			const centres = [];
			unders.forEach(u => {
				let best = -1, bv = -1e9;
				for (let i = 1; i < pts.length - 1; i++) { const dd = Math.hypot(pts[i][0] - u.p[0], pts[i][1] - u.p[1]); if (dd > 1.5) { continue; } const h2 = norm2([pts[i + 1][0] - pts[i - 1][0], pts[i + 1][1] - pts[i - 1][1]]), v = Math.abs(h2[0] * u.dir[0] + h2[1] * u.dir[1]) - dd; if (v > bv) { bv = v; best = i; } }
				if (best >= 0 && bv > 0.5) { centres.push(A[best]); }
			});
			const pi = cutOpen(pts, centres, r, 0, closed), pf = cutOpen(pts, centres, r, P.ink, closed);
			pi.forEach(q => ink.push(dPoly(q.pts)));
			pf.forEach(q => { fill.push(dPoly(q.pts)); if (q.end0) { caps.push(q.pts[0]); } if (q.end1) { caps.push(q.pts[q.pts.length - 1]); } });
		});
		const sw2 = P.w + 2 * P.ink, tf2 = opt.shift ? ' transform="translate(' + f(opt.shift[0]) + ' ' + f(opt.shift[1]) + ')"' : '';
		let sv = '<svg xmlns="http://www.w3.org/2000/svg" width="' + W + '" height="' + H + '" viewBox="0 0 ' + W + ' ' + H + '">';
		if (opt.background) { sv += '<rect width="' + W + '" height="' + H + '" fill="' + opt.background + '"/>'; }
		sv += '<g' + tf2 + ' stroke-linejoin="round">';
		// opt.dark: keep the enclosed holes filled (the darkened-corner look) under the cut strands
		if (opt.dark) { sv += '<g fill="' + colours.dark + '" fill-rule="evenodd">' + darkD.map(x => '<path d="' + x + '"/>').join('') + '</g>'; }
		sv += '<g fill="none" stroke-linecap="butt" stroke="' + colours.ink + '" stroke-width="' + f(sw2) + '">' + ink.map(x => '<path d="' + x + '"/>').join('') + '</g>';
		sv += '<g fill="' + colours.ink + '">' + caps.map(c => '<circle cx="' + f(c[0]) + '" cy="' + f(c[1]) + '" r="' + f(sw2 / 2) + '"/>').join('') + '</g>';
		sv += '<g fill="none" stroke-linecap="butt" stroke="' + colours.fill + '" stroke-width="' + f(P.w) + '">' + fill.map(x => '<path d="' + x + '"/>').join('') + '</g>';
		sv += '<g fill="' + colours.fill + '">' + caps.map(c => '<circle cx="' + f(c[0]) + '" cy="' + f(c[1]) + '" r="' + f(P.w / 2) + '"/>').join('') + '</g>';
		sv += '</g></svg>';
		const gates = { closed: !ends, topology: cx.topoOK, crossings: cx.count, unders: unders.length };
		return { svg: sv, gates, cx, d, parts: { ink, fill, caps, dark: darkD, inkWidth: sw2, fillWidth: P.w } };
	}
	const sw = P.w + 2 * P.ink, tf = opt.shift ? ' transform="translate(' + f(opt.shift[0]) + ' ' + f(opt.shift[1]) + ')"' : '';
	let svg = '<svg xmlns="http://www.w3.org/2000/svg" width="' + W + '" height="' + H + '" viewBox="0 0 ' + W + ' ' + H + '">';
	if (opt.background) { svg += '<rect width="' + W + '" height="' + H + '" fill="' + opt.background + '"/>'; }
	svg += '<g' + tf + ' stroke-linejoin="round"' + (ends ? ' stroke-linecap="round"' : '') + '>';
	if (P.halo > 0 && !opt.noHalo) { svg += '<path fill="none" stroke="' + colours.halo + '" stroke-width="' + f(sw + 2 * P.halo) + '" d="' + d + '"/>'; }
	svg += '<g fill="' + colours.dark + '" fill-rule="evenodd">' + darkD.map(s => '<path d="' + s + '"/>').join('') + '</g>';
	svg += '<path fill="none" stroke="' + colours.ink + '" stroke-width="' + f(sw) + '" d="' + d + '"/>';
	svg += '<path fill="none" stroke="' + colours.fill + '" stroke-width="' + f(P.w) + '" d="' + d + '"/>';
	if (sideInk.length) {
		// drawn before the crossing patches, so an over strand crossing a straight run still cuts it
		svg += '<path fill="' + colours.ink + '" d="' + sideInk.join('') + '"/><path fill="' + colours.fill + '" d="' + sideFill.join('') + '"/>';
	}
	svg += '<g fill="none" stroke-linecap="butt">' + patches.map(p => '<path stroke="' + colours.ink + '" stroke-width="' + f(sw) + '" d="' + p.d + '"/><path stroke="' + colours.fill + '" stroke-width="' + f(P.w) + '" d="' + p.df + '"/>').join('') + '</g>';
	svg += '</g></svg>';
	let alt = true; const ord = seed.corner.order; for (let i = 1; i < ord.length; i++) { if (ord[i] === ord[i - 1]) { alt = false; } }
	// with openings: two open strands, each ending in a P curl; the P crossings continue the alternation by construction
	const gates = ends ? { closed: false, strands: 2, endsPCurl: 4, topology: cx.topoOK, crossings: cx.count, alternates: alt && cx.topoOK && endList.every(e => e.run === 'O' || e.run === 'U') }
		: { closed: true, singleStrand: true, topology: cx.topoOK, crossings: cx.count, alternates: alt && cx.topoOK };
	return { svg, gates, cx, d };
}

module.exports = { build, paramsFromSeed, bez, sampleBez, corners, crossingsOf, holesTL };

if (require.main === module) {
	const fs = require('fs');
	const [seedFile, out, pFile] = process.argv.slice(2);
	const seed = JSON.parse(fs.readFileSync(seedFile, 'utf8')), P = pFile ? JSON.parse(fs.readFileSync(pFile, 'utf8')) : paramsFromSeed(seed);
	// CUTS=1: openings at top and bottom centre with P-curl ends (PR = bowl radius px)
	// ASH=fill: Ash's inked style -- fill px, ink 0.52 x fill per side, true cut gap 0.53 x fill, no dark fill;
	// the P stems are longer (13 px) so a stem passing under its run still shows past the gap
	let gap = null; if (process.env.ASH) { const fl = +process.env.ASH; P.w = fl; P.ink = 0.52 * fl; gap = 0.53 * fl; }
	const cuts = process.env.CUTS ? { radius: +(process.env.PR || 7.5), width: +(process.env.PW || 10), tail: gap !== null ? 13 : 8 } : null;
	const r = build(seed, P, { cuts, gap, colours: process.env.DISPLAY_COLOURS ? { fill: '#ffffff' } : {} });
	fs.writeFileSync(out, r.svg);
	console.log(JSON.stringify(r.gates));
}
