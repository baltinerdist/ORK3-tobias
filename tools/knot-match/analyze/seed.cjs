'use strict';
// seed.cjs -- turn the lattice + site map of a reference border into generator seeds.
//
// Frame coordinates: a = across/along x from the band's outer-left site column, b = from the band's outer-top site
// row (a = i - iL, b = j - jT in lattice indices). A site exists where (a + b) has the parity of (iL + jT).
// Site types are collapsed to the barrier map: 'X' (crossing; which strand is over comes from a global parity rule),
// 'H' / 'V' (barrier wall horizontal / vertical), '.' (no strand).
//
// The seed (seed.json):
//   grid:     s (px), origin of the frame (px, site (a, b) = (0, 0)), angle
//   stroke:   strand width / s, ink width / s
//   curve:    arc shape at barriers (u: where the turn starts along each segment, k: Bezier handle / s),
//             tight-turn shape (two barriers one segment apart)
//   side:     the periodic side tile: width (sites across, edge to edge), period p (sites along), rows[b mod p] as
//             strings over a = 0..width (sites of the wrong parity are ' ')
//   top:      the same for the top strip (rows indexed by a mod p, columns by b); `transposeOfSide` says whether it is
//             the side tile transposed with H <-> V
//   corner:   the TL corner tile: C x C sites in frame coordinates; outside it the side / top tiles rule
//   symmetry: how the other corners follow (BL = TL mirrored in y, measured; the right side assumed mirrored in x)
//   over:     over-direction rule: '\' over where b is odd (XOR flip)
//   frame:    the reference's frame size in sites (H measured; the residue H mod p that keeps corners compatible)
const fs = require('fs');
const IM = require('./image.cjs'), LA = require('./lattice.cjs');

// barrier types: 'H' / 'V' = a wall with strands bouncing on both sides (4 segments); a band-edge or one-sided
// barrier is named by the side its two strands are on: 'N' (ne + nw: a horizontal wall below them), 'S' (se + sw),
// 'E' (ne + se: a vertical wall left of them), 'W' (nw + sw).
const collapse = t => (t === 'X/' || t === 'X\\') ? 'X' : t;
const swapHV = t => ({ H: 'V', V: 'H', N: 'W', W: 'N', S: 'E', E: 'S' })[t] || t;      // transpose (a, b) -> (b, a)
const mirY = t => ({ N: 'S', S: 'N' })[t] || t, mirX = t => ({ E: 'W', W: 'E' })[t] || t;
const OFFERS = { X: ['ne', 'nw', 'se', 'sw'], H: ['ne', 'nw', 'se', 'sw'], V: ['ne', 'nw', 'se', 'sw'], N: ['ne', 'nw'], S: ['se', 'sw'], E: ['ne', 'se'], W: ['nw', 'sw'] };
const WALL = { H: 'H', N: 'H', S: 'H', V: 'V', E: 'V', W: 'V' };
// refine a read site: one-sided barriers get their side
function refine(v) {
	if (v.t !== 'H' && v.t !== 'V') { return v.t; }
	const g = v.segs, d = g.ne + g.nw + g.se + g.sw; if (d === 4) { return v.t; }
	if (v.t === 'H') { return g.ne && g.nw ? 'N' : 'S'; }
	return g.ne && g.se ? 'E' : 'W';
}

function analyse(file) {
	const img = IM.load(file), cm = IM.classify(img), X = LA.detectCrossings(cm), L = LA.fitLattice(X), S = LA.sites(cm, L, X);
	return { img, cm, X, L, S };
}

function extract(A, opt) {
	opt = opt || {};
	const { cm, L, S } = A;
	// sites within one lattice step of the image border cannot be read reliably (their strands leave the image)
	S.forEach(v => { if (v.x > cm.w - L.s || v.y > cm.h - L.s || v.x < L.s * 0.5 || v.y < L.s * 0.5) { v.t = '~'; } });
	S.forEach(v => { v.t = refine(v); });
	const band = [...S.values()].filter(v => v.t !== '.' && v.t !== '~');
	const iL = Math.min(...band.map(v => v.i)), jT = Math.min(...band.map(v => v.j)), jB = Math.max(...band.map(v => v.j));
	const par = (iL + jT) & 1;
	const get = (a, b) => { const v = S.get((a + iL) + ',' + (b + jT)); return v ? v.t : undefined; };      // raw type
	const known = t => t !== undefined && t !== '~';
	const H = jB - jT, mid = H / 2;
	// side band width: the widest band extent in the middle third of the side
	let wS = 0; for (let b = Math.round(H / 3); b <= Math.round(2 * H / 3); b++) { for (let a = 0; a < 40; a++) { const t = get(a, b); if (known(t) && t !== '.') { wS = Math.max(wS, a); } } }
	// top band width: rows of band in columns well past the corner
	let wT = 0, aMax = 0; band.forEach(v => { aMax = Math.max(aMax, v.i - iL); });
	for (let a = wS + 8; a <= aMax; a++) { for (let b = 0; b < mid; b++) { const t = get(a, b); if (known(t) && t !== '.') { wT = Math.max(wT, b); } } }
	// side period: smallest even p with every known site in the side's middle matching b vs b + p
	const sideRows = []; for (let b = Math.round(H * 0.25); b <= Math.round(H * 0.75); b++) { sideRows.push(b); }
	const periodOf = (cell, lo, hi, across) => {
		for (let p = 2; p <= 40; p += 2) {
			let ok = 0, bad = 0;
			for (let q = lo; q + p <= hi; q++) { for (let c = 0; c <= across; c++) { const t1 = cell(c, q), t2 = cell(c, q + p); if (!known(t1) || !known(t2)) { continue; } if (collapse(t1) === collapse(t2)) { ok++; } else { bad++; } } }
			if (ok > 0 && bad === 0) { return { p, ok }; }
		}
		return null;
	};
	const sideP = periodOf((a, b) => get(a, b), sideRows[0], sideRows[sideRows.length - 1], wS);
	const topLo = wS + 4, topHi = aMax - 1;
	const topP = periodOf((b, a) => get(a, b), topLo, topHi, wT);
	if (!sideP) { throw new Error('no side period found'); }
	const p = sideP.p;
	// tiles: rows[b mod p][a] (side), rows[a mod p][b] (top)
	const tile = (cell, lo, hi, across) => {
		const rows = []; for (let r = 0; r < p; r++) { let line = ''; for (let c = 0; c <= across; c++) { let t; for (let q = lo; q <= hi; q++) { if (((q % p) + p) % p !== r) { continue; } const v = cell(c, q); if (known(v)) { t = collapse(v); break; } } line += t === undefined ? ' ' : t; } rows.push(line); }
		return rows;
	};
	const side = tile((a, b) => get(a, b), sideRows[0], sideRows[sideRows.length - 1], wS);
	const top = topP ? tile((b, a) => get(a, b), topLo, topHi, wT) : null;
	// is the top strip the side tile transposed (H <-> V)?
	let transposeOfSide = !!top && wT === wS && topP.p === p;
	if (transposeOfSide) { for (let r = 0; r < p; r++) { for (let c = 0; c <= wS; c++) { const a = side[r][c], t = top[r][c]; if (a !== ' ' && t !== ' ' && swapHV(a) !== t) { transposeOfSide = false; } } } }
	// predict a TL-quadrant site from the tiles
	const fromTiles = (a, b) => {
		if (a <= wS && b >= 0) { const c = side[((b % p) + p) % p][a]; return c === ' ' ? undefined : c; }
		if (b <= wT && a >= 0 && top) { const c = top[((a % p) + p) % p][b]; return c === ' ' ? undefined : c; }
		return '.';
	};
	// corner extent C: smallest C such that every known TL-quadrant site outside [0,C)^2 matches the tiles
	let C = 0;
	for (C = Math.max(wS, wT) + 1; C < 60; C++) {
		let bad = 0;
		S.forEach(v => { const a = v.i - iL, b = v.j - jT; if (b > mid || (a < C && b < C) || !known(v.t) || a < -1 || b < -1) { return; } const pr = fromTiles(a, b); if (pr !== undefined && pr !== collapse(v.t)) { bad++; } });
		if (!bad) { break; }
	}
	const corner = []; for (let b = 0; b < C; b++) { let line = ''; for (let a = 0; a < C; a++) { const t = (a + b + iL + jT) & 1 ? ' ' : get(a, b); line += t === undefined || t === ' ' ? ' ' : known(t) ? collapse(t) : '.'; } corner.push(line); }
	// corner self-symmetry (the corner tile transposed with H <-> V)
	let cornerTranspose = true; for (let b = 0; b < C; b++) { for (let a = 0; a < C; a++) { const x = corner[b][a], y = corner[a][b]; if (x !== ' ' && y !== ' ' && swapHV(x) !== y) { cornerTranspose = false; } } }
	// BL vs TL: mirror in y about the frame's middle row, and the 90-degree rotation, as match fractions
	const cmpSym = map => { let ok = 0, n = 0; S.forEach(v => { const a = v.i - iL, b = v.j - jT; if (b <= mid || !known(v.t)) { return; } const m = map(a, b); if (!m) { return; } const t2 = get(m[0], m[1]); if (!known(t2)) { return; } n++; if (m[2](collapse(t2)) === collapse(v.t)) { ok++; } }); return n ? { ok, n, frac: ok / n } : null; };
	const mirrorY = cmpSym((a, b) => [a, H - b, mirY]);
	const rot90 = cmpSym((a, b) => [H - b, a, t => mirX(swapHV(t))]);      // (a, b) -> (H - b, a): BL rotated onto TL
	// over/under: '\' over where b is odd?
	let agree = 0, nx = 0; S.forEach(v => { if (v.t[0] !== 'X') { return; } const b = v.j - jT; nx++; if ((v.t === 'X\\') === ((b & 1) === 1)) { agree++; } });
	const overFlip = agree < nx / 2, overConsistency = Math.max(agree, nx - agree) / nx;
	const s = L.s;
	const seed = {
		version: 1,
		source: opt.source || null,
		image: { w: cm.w, h: cm.h },
		grid: { s: +s.toFixed(4), originPx: [+(L.x0 + iL * s).toFixed(3), +(L.y0 + jT * s).toFixed(3)], angle: 0, latticeResidualPx: +L.residual.toFixed(3), parity: par },
		stroke: { strand: +(2 * cm.halfW / s).toFixed(4), ink: +(cm.inkW / s).toFixed(4), strandPx: 2 * cm.halfW, inkPx: cm.inkW },
		curve: { u: 0.5, k: 0.39, tightU: 0.5, tightK: 0.39 },
		side: { width: wS, period: p, rows: side, periodSupport: sideP.ok },
		top: top ? { width: wT, period: topP.p, rows: top, transposeOfSide } : null,
		corner: { size: C, rows: corner, transposeSymmetric: cornerTranspose },
		symmetry: { BL: mirrorY && mirrorY.frac >= 0.99 ? 'mirrorY' : rot90 && rot90.frac >= 0.99 ? 'rot90' : 'none', mirrorY, rot90, right: 'mirrorX (assumed: not in the reference)' },
		over: { rule: "'\\\\' over where b is odd", flip: overFlip, consistency: +overConsistency.toFixed(4), crossings: nx },
		frame: { H, Hmod: ((H % p) + p) % p, aVisible: aMax },
	};
	return seed;
}

// expand a seed into a full site map for a frame of AW x AH sites (outer edge to outer edge)
function layout(seed, AW, AH) {
	const p = seed.side.period, wS = seed.side.width, C = seed.corner.size, par = seed.grid.parity;
	const top = seed.top || { width: wS, rows: seed.side.rows.map((_, r) => seed.side.rows[r]), transposeOfSide: true };
	const wT = top.width;
	const sideAt = (a, b) => seed.side.rows[((b % p) + p) % p][a];
	const topAt = (a, b) => seed.top ? seed.top.rows[((a % p) + p) % p][b] : swapHV(sideAt(b, a));
	const quad = (a, b) => {   // TL-quadrant rule
		if (a < C && b < C) { return seed.corner.rows[b][a]; }
		if (a <= wS) { return sideAt(a, b); }
		if (b <= wT) { return topAt(a, b); }
		return '.';
	};
	const map = new Map();
	for (let b = -1; b <= AH + 1; b++) {
		for (let a = -1; a <= AW + 1; a++) {
			if (((a + b) & 1) !== par) { continue; }
			let t;
			if (a < 0 || b < 0 || a > AW || b > AH) { t = '.'; }
			else {
				let aa = a, bb = b, my = false, mx = false;
				if (bb > AH / 2) { bb = AH - bb; my = true; }                // BL / bottom: mirror in y
				if (aa > AW / 2) { aa = AW - aa; mx = true; }                // right side: mirror in x
				t = quad(aa, bb);
				if (t === ' ' || t === undefined) { t = '?'; }
				if (my) { t = mirY(t); } if (mx) { t = mirX(t); }
			}
			map.set(a + ',' + b, t);
		}
	}
	return { map, AW, AH, par };
}

module.exports = { analyse, extract, layout, collapse, swapHV, mirX, mirY, OFFERS, WALL, refine };

if (require.main === module) {
	const [file, out] = process.argv.slice(2);
	const A = analyse(file), seed = extract(A, { source: require('path').relative(process.cwd(), file) });
	const txt = JSON.stringify(seed, null, '\t');
	if (out) { fs.writeFileSync(out, txt + '\n'); }
	console.log(txt);
}
