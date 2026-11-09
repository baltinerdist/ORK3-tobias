'use strict';
// lattice.cjs -- read a knotwork raster as a CROSSING LATTICE plus a BARRIER MAP (the classic grid construction of
// Celtic knotwork: strands run diagonally between lattice sites; at a crossing site they pass straight through, one
// over the other; at a barrier site they turn back, forming the arcs; the band's outline is a barrier wall).
//
//  1. crossings: at every candidate pixel test both diagonals as "the over direction" u. A crossing with the over
//     strand along u looks like: fill all along u through the centre (the over strand is continuous); across it,
//     along v = u rotated 90 deg: fill for a half strand, then the over strand's ink outline, then fill again (the
//     under strand, cut at the outline). Away from crossings the v probe hits ground (a hole) instead.
//  2. lattice: crossing centres of a diagonal grid lie on a square lattice with spacing s, axis-aligned, on the sites
//     where i + j is even (diagonal neighbours are one strand segment apart). s and the origin come from the
//     nearest-neighbour statistics of the detected centres, then a least-squares refit.
//  3. sites: every lattice site gets a type -- 'X/' or 'X\' (crossing, which diagonal is over), 'H' or 'V' (barrier
//     whose wall runs horizontally / vertically: strands bounce off it), or '.' (no strand: outside the band).
const IM = require('./image.cjs');
const { CLS } = IM;

function sampler(cm) { return (x, y) => { const X = Math.round(x), Y = Math.round(y); return (X < 0 || Y < 0 || X >= cm.w || Y >= cm.h) ? CLS.GROUND : cm.c[Y * cm.w + X]; }; }

function crossingScore(at, x, y, u, hw, ink) {
	const v = [-u[1], u[0]]; let s = 0, n = 0;
	const fr = (d0, d1, dir, off, cls) => { let k = 0, t = 0; for (let d = d0; d <= d1; d += 1) { t++; if (at(x + dir[0] * d + off[0], y + dir[1] * d + off[1]) === cls) { k++; } } return k / t; };
	// over strand continuous along u through the centre (both directions), at the centre line and at +-hw/2
	const a = 0.5 * hw;
	for (const o of [[0, 0], [v[0] * a, v[1] * a], [-v[0] * a, -v[1] * a]]) { s += fr(-(hw + ink), hw + ink, u, o, CLS.FILL); n++; }
	// across: the over strand's ink outline at |v| ~ hw + ink/2, then under-strand fill beyond it
	for (const sg of [1, -1]) {
		const dv = [v[0] * sg, v[1] * sg];
		s += fr(hw + 0.25 * ink, hw + 0.75 * ink + 0.5, dv, [0, 0], CLS.INK); n++;
		s += fr(hw + ink + 1.5, hw + ink + hw, dv, [0, 0], CLS.FILL); n++;
		// the under strand is a band along v: its own two outlines at +-hw along u, beyond the over strand
		const side = (k) => fr(hw + ink + 2, hw + ink + hw, dv, [u[0] * k * (hw + 0.5 * ink), u[1] * k * (hw + 0.5 * ink)], CLS.INK);
		s += 0.5 * (side(1) + side(-1)); n++;
	}
	return s / n;
}

function detectCrossings(cm, opt) {
	opt = opt || {};
	const at = sampler(cm), hw = cm.halfW, ink = cm.inkW, r2 = Math.SQRT1_2;
	// diagonal strands (the default): '/' = over strand rising to the right (screen y down); orthogonal strands
	// (opt.orient === 'axis'): '-' = over strand horizontal, '|' = vertical
	const dirs = opt.orient === 'axis' ? { '-': [1, 0], '|': [0, 1] } : { '/': [r2, -r2], '\\': [r2, r2] };
	const names = Object.keys(dirs);
	const W = cm.w, H = cm.h, best = new Float32Array(W * H), kind = new Int8Array(W * H);
	for (let y = 0; y < H; y++) {
		for (let x = 0; x < W; x++) {
			if (cm.c[y * W + x] !== CLS.FILL) { continue; }
			const a = crossingScore(at, x, y, dirs[names[0]], hw, ink), b = crossingScore(at, x, y, dirs[names[1]], hw, ink);
			best[y * W + x] = Math.max(a, b); kind[y * W + x] = a >= b ? 1 : 2;
		}
	}
	const th = opt.th || 0.82, rad = Math.round(hw), out = [];
	for (let y = 0; y < H; y++) {
		for (let x = 0; x < W; x++) {
			const v = best[y * W + x]; if (v < th) { continue; }
			let isMax = true;
			for (let dy = -rad; dy <= rad && isMax; dy++) { for (let dx = -rad; dx <= rad; dx++) { const X = x + dx, Y = y + dy; if ((dx || dy) && X >= 0 && Y >= 0 && X < W && Y < H && (best[Y * W + X] > v || (best[Y * W + X] === v && (dy < 0 || (dy === 0 && dx < 0))))) { isMax = false; break; } } }
			if (!isMax) { continue; }
			// sub-pixel centre: score-weighted centroid of the plateau
			let sx = 0, sy = 0, sw = 0; for (let dy = -2; dy <= 2; dy++) { for (let dx = -2; dx <= 2; dx++) { const X = x + dx, Y = y + dy; if (X < 0 || Y < 0 || X >= W || Y >= H) { continue; } const q = best[Y * W + X]; if (q >= v - 0.04) { sx += X * q; sy += Y * q; sw += q; } } }
			out.push({ x: sx / sw, y: sy / sw, score: v, over: kind[y * W + x] === 1 ? names[0] : names[1] });
		}
	}
	return out;
}

// lattice from crossing centres: spacing = mode of nearest-neighbour distances projected on the diagonals
function fitLattice(X) {
	// diagonal neighbours sit at (+-s, +-s): collect neighbour offsets with |dx| ~ |dy|
	const offs = [];
	X.forEach((p, i) => { X.forEach((q, j) => { if (i === j) { return; } const dx = q.x - p.x, dy = q.y - p.y, d = Math.hypot(dx, dy); if (d > 4 && d < 80 && Math.abs(Math.abs(dx) - Math.abs(dy)) < 0.25 * d) { offs.push((Math.abs(dx) + Math.abs(dy)) / 2); } }); });
	offs.sort((a, b) => a - b);
	// the smallest strong cluster is s (diagonal step); median of the lowest cluster
	const s0 = offs[Math.floor(offs.length * 0.05)];
	const cl = offs.filter(v => v < s0 * 1.35), s = cl[cl.length >> 1];
	// origin: circular mean of positions modulo 2s, with i + j even
	const phase = (vals, P) => { let cx = 0, cy = 0; vals.forEach(v => { cx += Math.cos(2 * Math.PI * v / P); cy += Math.sin(2 * Math.PI * v / P); }); return ((Math.atan2(cy, cx) / (2 * Math.PI)) * P + P) % P; };
	// sites with i + j even: (x0 + i s, y0 + j s). Project on the two diagonals: x + y and x - y are multiples of 2s
	const pPlus = phase(X.map(p => p.x + p.y), 2 * s), pMinus = phase(X.map(p => p.x - p.y), 2 * s);
	let x0 = (pPlus + pMinus) / 2, y0 = (pPlus - pMinus) / 2;
	// least-squares refine s, x0, y0 on the assigned integer coordinates
	let S = s;
	for (let it = 0; it < 3; it++) {
		const A = [], bx = [], by = [];
		X.forEach(p => { const i = Math.round((p.x - x0) / S), j = Math.round((p.y - y0) / S); if ((i + j) % 2) { return; } A.push([i, j]); bx.push(p.x); by.push(p.y); });
		// x = x0 + i S, y = y0 + j S  -> solve jointly for (x0, y0, S)
		let n = A.length, si = 0, sj = 0, sii = 0, sjj = 0, sx = 0, sy = 0, six = 0, sjy = 0;
		A.forEach((a, k) => { si += a[0]; sj += a[1]; sii += a[0] * a[0]; sjj += a[1] * a[1]; sx += bx[k]; sy += by[k]; six += a[0] * bx[k]; sjy += a[1] * by[k]; });
		// normal equations for [x0, y0, S]
		const M = [[n, 0, si], [0, n, sj], [si, sj, sii + sjj]], r = [sx, sy, six + sjy];
		const sol = solve3(M, r); x0 = sol[0]; y0 = sol[1]; S = sol[2];
	}
	let res = 0; X.forEach(p => { const i = Math.round((p.x - x0) / S), j = Math.round((p.y - y0) / S); res += Math.hypot(p.x - x0 - i * S, p.y - y0 - j * S); });
	return { s: S, x0, y0, residual: res / X.length };
}
function solve3(M, r) {
	const a = M.map((row, i) => row.concat([r[i]]));
	for (let c = 0; c < 3; c++) { let p = c; for (let k = c + 1; k < 3; k++) { if (Math.abs(a[k][c]) > Math.abs(a[p][c])) { p = k; } } [a[c], a[p]] = [a[p], a[c]]; for (let k = 0; k < 3; k++) { if (k === c) { continue; } const f = a[k][c] / a[c][c]; for (let q = c; q < 4; q++) { a[k][q] -= f * a[c][q]; } } }
	return [a[0][3] / a[0][0], a[1][3] / a[1][1], a[2][3] / a[2][2]];
}

// classify every lattice site (i + j even) in the image.
// Strand SEGMENTS join diagonal neighbours; the midpoint of a segment is a half-integer point (i + 1/2, j + 1/2), and
// each half-integer point is the midpoint of exactly one segment. A segment is present when its midpoint sits in
// strand fill. A site that is not a detected crossing is then typed by which of its four diagonal segments are
// present: NE+NW or SE+SW (strands arrive from one side of a horizontal wall) -> 'H'; NE+SE or NW+SW -> 'V'; none ->
// '.'; all four -> an interior barrier, whose wall orientation comes from the run of ground through the site (a
// vertical wall leaves a vertical gap between the two arcs). Anything else is flagged '?' (a reading error).
function segPresent(cm, L, i2, j2) {   // i2, j2 = 2 * the half-integer coordinates (odd numbers)
	const x = L.x0 + i2 * L.s / 2, y = L.y0 + j2 * L.s / 2, r = Math.max(2, Math.round(cm.halfW * 0.45));
	let f = 0, t = 0;
	for (let dy = -r; dy <= r; dy++) { for (let dx = -r; dx <= r; dx++) { if (dx * dx + dy * dy > r * r) { continue; } const X = Math.round(x + dx), Y = Math.round(y + dy); t++; if (X >= 0 && Y >= 0 && X < cm.w && Y < cm.h && cm.c[Y * cm.w + X] === CLS.FILL) { f++; } } }
	return f / t >= 0.5;
}
function sites(cm, L, X) {
	const at = sampler(cm), s = L.s, out = new Map();
	const iMin = Math.floor((0 - L.x0) / s) - 1, iMax = Math.ceil((cm.w - L.x0) / s) + 1, jMin = Math.floor((0 - L.y0) / s) - 1, jMax = Math.ceil((cm.h - L.y0) / s) + 1;
	const xs = new Map(); X.forEach(p => { const i = Math.round((p.x - L.x0) / s), j = Math.round((p.y - L.y0) / s); if (!((i + j) & 1)) { xs.set(i + ',' + j, p); } });
	const frac = (x, y, dir, d0, d1, cls) => { let k = 0, t = 0; for (let d = d0; d <= d1; d++) { t++; if (at(x + dir[0] * d, y + dir[1] * d) === cls) { k++; } } return k / t; };
	const seg = new Map(), segAt = (i2, j2) => { const k = i2 + ',' + j2; if (!seg.has(k)) { seg.set(k, segPresent(cm, L, i2, j2)); } return seg.get(k); };
	for (let j = jMin; j <= jMax; j++) {
		for (let i = iMin; i <= iMax; i++) {
			if ((i + j) & 1) { continue; }
			const x = L.x0 + i * s, y = L.y0 + j * s; if (x < -s || y < -s || x > cm.w + s || y > cm.h + s) { continue; }
			const key = i + ',' + j;
			const ne = segAt(2 * i + 1, 2 * j - 1), nw = segAt(2 * i - 1, 2 * j - 1), se = segAt(2 * i + 1, 2 * j + 1), sw = segAt(2 * i - 1, 2 * j + 1);
			const deg = ne + nw + se + sw;
			let t;
			if (xs.has(key)) { t = 'X' + xs.get(key).over; }
			else if (deg === 0) { t = '.'; }
			else if (deg === 4) {
				const vert = frac(x, y, [0, 1], -0.6 * s, 0.6 * s, CLS.GROUND) + frac(x, y, [0, 1], -0.6 * s, 0.6 * s, CLS.INK) * 0.5;
				const horz = frac(x, y, [1, 0], -0.6 * s, 0.6 * s, CLS.GROUND) + frac(x, y, [1, 0], -0.6 * s, 0.6 * s, CLS.INK) * 0.5;
				t = vert >= horz ? 'V' : 'H';
			}
			else if (deg === 2 && ((ne && nw) || (se && sw))) { t = 'H'; }
			else if (deg === 2 && ((ne && se) || (nw && sw))) { t = 'V'; }
			else { t = '?'; }
			out.set(key, { i, j, x, y, t, segs: { ne, nw, se, sw } });
		}
	}
	// a tight turn (two barriers one segment apart, e.g. a rounded outer corner or an inner-corner nub) bends the strand
	// inside the segment's midpoint, so that segment reads absent and both barriers read degree 1. Pair such
	// diagonal neighbours and restore the segment.
	const DIRS = { ne: [1, -1, 'sw'], nw: [-1, -1, 'se'], se: [1, 1, 'nw'], sw: [-1, 1, 'ne'] };
	const typeOf = g => { const { ne, nw, se, sw } = g, d = ne + nw + se + sw; return d === 2 && ((ne && nw) || (se && sw)) ? 'H' : d === 2 && ((ne && se) || (nw && sw)) ? 'V' : '?'; };
	out.forEach(v => {
		if (v.t !== '?') { return; }
		for (const [k, [di, dj, back]] of Object.entries(DIRS)) {
			const u = out.get((v.i + di) + ',' + (v.j + dj));
			if (!u || u.t !== '?' || v.segs[k]) { continue; }
			const gv = Object.assign({}, v.segs, { [k]: true }), gu = Object.assign({}, u.segs, { [back]: true });
			if (typeOf(gv) !== '?' && typeOf(gu) !== '?') { v.segs = gv; u.segs = gu; v.t = typeOf(gv); u.t = typeOf(gu); v.tight = u.tight = true; break; }
		}
	});
	// sites whose neighbourhood leaves the image cannot be read: mark them unknown
	out.forEach(v => { if (v.t === '?' && (v.x < s || v.y < s || v.x > cm.w - s || v.y > cm.h - s)) { v.t = '~'; } });
	return out;
}

module.exports = { detectCrossings, fitLattice, sites, crossingScore, segPresent };

if (require.main === module) {
	const [file, outPng] = process.argv.slice(2);
	const cm = IM.classify(IM.load(file)), X = detectCrossings(cm), L = fitLattice(X), S = sites(cm, L, X);
	const counts = {}; S.forEach(v => { counts[v.t] = (counts[v.t] || 0) + 1; });
	console.log(JSON.stringify({ crossings: X.length, lattice: { s: +L.s.toFixed(3), x0: +L.x0.toFixed(2), y0: +L.y0.toFixed(2), residual: +L.residual.toFixed(3) }, sites: counts, strandW: 2 * cm.halfW, inkW: cm.inkW }));
	if (outPng) {
		const { PNG } = require('pngjs'), fs = require('fs'), sc = 2, Wd = cm.w * sc, Hd = cm.h * sc, png = new PNG({ width: Wd, height: Hd });
		for (let i = 0; i < Wd * Hd; i++) { const k = cm.c[(((i / Wd) | 0) / sc | 0) * cm.w + ((i % Wd) / sc | 0)]; const v = k === 1 ? 110 : k === 2 ? 236 : 252; png.data[i * 4] = png.data[i * 4 + 1] = png.data[i * 4 + 2] = v; png.data[i * 4 + 3] = 255; }
		const put = (x, y, col, r) => { for (let dy = -r; dy <= r; dy++) { for (let dx = -r; dx <= r; dx++) { const X2 = Math.round(x * sc) + dx, Y2 = Math.round(y * sc) + dy; if (X2 < 0 || Y2 < 0 || X2 >= Wd || Y2 >= Hd) { continue; } const o = (Y2 * Wd + X2) * 4; png.data[o] = col[0]; png.data[o + 1] = col[1]; png.data[o + 2] = col[2]; } } };
		S.forEach(st => {
			const col = { 'X/': [220, 40, 40], 'X\\': [40, 90, 220], 'H': [20, 160, 60], 'V': [200, 140, 0], '.': [200, 200, 200] }[st.t];
			if (st.t === '.') { put(st.x, st.y, col, 1); return; }
			if (st.t === 'H') { for (let d = -6; d <= 6; d++) { put(st.x + d, st.y, col, 1); } return; }
			if (st.t === 'V') { for (let d = -6; d <= 6; d++) { put(st.x, st.y + d, col, 1); } return; }
			const sg = st.t === 'X/' ? -1 : 1; for (let d = -5; d <= 5; d++) { put(st.x + d, st.y + sg * d, col, 1); }
		});
		fs.writeFileSync(outPng, PNG.sync.write(png));
	}
}
