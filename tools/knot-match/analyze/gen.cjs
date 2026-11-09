'use strict';
// gen.cjs -- knotwork generator on a diagonal crossing lattice: seed + frame size in, SVG out.
//
//  layout   the seed's corner tile, periodic side / top tiles and symmetry give every site of an AW x AH frame
//           (frame coordinates a, b; see seed.cjs) a type: 'X' crossing, 'H' / 'V' barrier, '.' no strand.
//  strands  a segment joins two diagonal neighbours when both are in the band. A strand runs straight through an
//           X site and reflects at a barrier (H flips its vertical step, V its horizontal one). Following the
//           segments gives closed loops; every segment is used exactly once.
//  curves   straight lines through crossings; at a barrier a cubic from A1 = B + u (P - B) to A2 = B + u (Q - B),
//           tangent to both segments, handles k * s. Two barriers one segment apart (a tight U-turn: rounded outer
//           corners, inner-corner nubs) are drawn as ONE cubic from the first barrier's A1 to the second's A2
//           (tightU, tightK), so the turn can sit inside the shared segment as the reference draws it.
//  over     global alternation: at a crossing the '\' strand is over where b is odd (XOR seed.over.flip). A strand
//           changes b parity at every step, so over and under alternate along every strand, through barriers too.
//  paint    every loop: ink stroke (w + 2 ink), then every loop: fill stroke (w); then at each crossing the over
//           strand is repainted along its own straight run (ink then fill, butt caps), which cuts the under strand
//           at the over strand's outline with no gap.
// Output is plain SVG: paths and groups, solid colours.
const SD = require('./seed.cjs');

const DIR = { ne: [1, -1], nw: [-1, -1], se: [1, 1], sw: [-1, 1] };

function siteMap(seed, AW, AH, cuts) { const L = SD.layout(seed, AW, AH); if (cuts) { applyCuts(L, seed, cuts); } return L; }

// cutouts: break the top and / or bottom strip between two end walls, leaving the space Ash's border leaves for the
// arms (top) and the award detail (bottom). cuts = { top: E, bottom: E } where E is the column (in sites from the
// outer left edge) of the left half's end wall; the right half is its mirror (AW - E). The end wall is the band's
// own edge construction turned across it: the sites of column E on the strip's odd rows become one-sided barriers
// facing back into the band ('W' on the left half, 'E' on the right), and everything between the walls is
// emptied. Every strand reflects there, so no strand ends: the loops stay closed and the global over / under
// parity still alternates along them.
function applyCuts(L, seed, cuts) {
	const { map, AW, AH } = L, wT = seed.top ? seed.top.width : seed.side.width;
	for (const [edge, E] of Object.entries(cuts)) {
		if (E === undefined || E === null) { continue; }
		const rows = edge === 'top' ? [0, wT] : [AH - wT, AH];
		map.forEach((t, k) => {
			const [a, b] = k.split(',').map(Number); if (b < rows[0] || b > rows[1]) { return; }
			if (a > E && a < AW - E) { map.set(k, '.'); }
			else if (a === E || a === AW - E) { map.set(k, (a + b) % 2 === L.par && b > rows[0] && b < rows[1] ? (a === E ? 'W' : 'E') : '.'); }
		});
	}
	return L;
}

// segments: two diagonal neighbours are joined when each offers the other its direction (seed.cjs OFFERS)
const BACK = { ne: 'sw', nw: 'se', se: 'nw', sw: 'ne' };
function offers(map, a, b, d) { const t = map.get(a + ',' + b); return !!(t && SD.OFFERS[t] && SD.OFFERS[t].includes(d)); }
function joined(map, a, b, d) { return offers(map, a, b, d) && offers(map, a + DIR[d][0], b + DIR[d][1], BACK[d]); }
// gate: every band site's offers are all answered (no dangling strand ends), and no unknown types
function validate(L) {
	const { map } = L, bad = [];
	map.forEach((t, k) => {
		if (t === '.') { return; }
		const [a, b] = k.split(',').map(Number);
		if (!SD.OFFERS[t]) { bad.push({ a, b, t, why: 'unknown type' }); return; }
		const miss = SD.OFFERS[t].filter(d => !joined(map, a, b, d));
		if (miss.length) { bad.push({ a, b, t, miss }); }
	});
	return bad;
}

// trace closed loops. A loop is a list of {a, b, t, din, dout} (directions as [da, db] unit diagonal steps)
function traceLoops(L, lenient) {
	const { map } = L, used = new Set(), loops = [];
	let firstError = null;
	const type = (a, b) => map.get(a + ',' + b);
	const segKey = (a, b, da, db) => { const a2 = a + da, b2 = b + db; return a < a2 || (a === a2 && b < b2) ? a + ',' + b + '>' + a2 + ',' + b2 : a2 + ',' + b2 + '>' + a + ',' + b; };
	const keys = [...map.keys()].sort((p, q) => { const [a1, b1] = p.split(',').map(Number), [a2, b2] = q.split(',').map(Number); return b1 - b2 || a1 - a2; });
	for (const k of keys) {
		const t = map.get(k); if (t === '.') { continue; }
		const [a0, b0] = k.split(',').map(Number);
		for (const d of ['se', 'sw', 'ne', 'nw']) {
			const [da, db] = DIR[d];
			if (!joined(map, a0, b0, d) || used.has(segKey(a0, b0, da, db))) { continue; }
			// start on segment (a0,b0) -> (a0+da, b0+db)
			const loop = []; let a = a0, b = b0, dir = [da, db], guard = 0, err = null;
			while (!err) {
				used.add(segKey(a, b, dir[0], dir[1]));
				const na = a + dir[0], nb = b + dir[1], nt = type(na, nb);
				let out;
				const dname = (dir[1] < 0 ? 'n' : 's') + (dir[0] > 0 ? 'e' : 'w');
				if (!joined(map, a, b, dname)) { err = 'strand leaves the band at ' + a + ',' + b + ' going ' + dname; break; }
				if (nt === 'X') { out = dir; }
				else if (SD.WALL[nt] === 'H') { out = [dir[0], -dir[1]]; }
				else if (SD.WALL[nt] === 'V') { out = [-dir[0], dir[1]]; }
				else { err = 'strand leaves the band at ' + na + ',' + nb; break; }
				// a 4-segment barrier: the reflected segment must exist (it does by validate)
				loop.push({ a: na, b: nb, t: nt, din: dir, dout: out });
				a = na; b = nb; dir = out;
				if (a === a0 + da && b === b0 + db && false) { break; }
				if (used.has(segKey(a, b, dir[0], dir[1]))) {
					// closed when we are about to re-enter the first segment
					if (a === a0 && b === b0 && dir[0] === da && dir[1] === db) { break; }
					err = 'segment reused at ' + a + ',' + b; break;
				}
				if (++guard > 100000) { err = 'runaway'; break; }
			}
			if (err) { if (!lenient) { return { loops, error: err }; } firstError = firstError || err; continue; }
			loops.push(loop);
		}
	}
	return { loops, error: null, skipped: firstError };
}

const f = v => (Math.round(v * 1000) / 1000).toString();

// centreline path (SVG d) of one loop, and the straight crossing runs (for patches)
function loopPath(loop, P) {
	const s = P.s, X0 = P.origin[0], Y0 = P.origin[1], px = (a, b) => [X0 + a * s, Y0 + b * s];
	const n = loop.length, cmds = [];
	// group consecutive barriers into turns: a run of 1 barrier = simple arc; 2 = tight U-turn (one cubic);
	// longer runs: chain of simple arcs meeting at segment midpoints
	const isBar = i => loop[(i + n) % n].t !== 'X';
	// start at a crossing if there is one (so the path starts on a straight)
	let start = 0; for (let i = 0; i < n; i++) { if (!isBar(i)) { start = i; break; } }
	const L = [], at = i => loop[(i + n) % n];
	for (let k = 0; k < n; k++) { L.push(at(start + k)); }
	const pts = []; // sequence of drawing ops
	let i = 0;
	const first = px(L[0].a, L[0].b); cmds.push('M' + f(first[0]) + ' ' + f(first[1]));
	i = 1;
	while (i <= n) {
		const cur = L[i % n];
		if (cur.t === 'X') { const p = px(cur.a, cur.b); cmds.push('L' + f(p[0]) + ' ' + f(p[1])); i++; continue; }
		// run of barriers
		let j = i; while (j < i + n && L[j % n].t !== 'X') { j++; }
		const run = []; for (let k = i; k < j; k++) { run.push(L[k % n]); }
		const prev = L[(i - 1 + n) % n], next = L[j % n];
		const tight = run.length === 2;
		if (tight) {
			const B1 = px(run[0].a, run[0].b), B2 = px(run[1].a, run[1].b), Pp = px(prev.a, prev.b), Qn = px(next.a, next.b);
			const u = P.tightU, k = P.tightK * s;
			const A1 = [B1[0] + u * (Pp[0] - B1[0]), B1[1] + u * (Pp[1] - B1[1])], A2 = [B2[0] + u * (Qn[0] - B2[0]), B2[1] + u * (Qn[1] - B2[1])];
			const d1 = norm([B1[0] - Pp[0], B1[1] - Pp[1]]), d2 = norm([Qn[0] - B2[0], Qn[1] - B2[1]]);
			cmds.push('L' + f(A1[0]) + ' ' + f(A1[1]));
			cmds.push('C' + f(A1[0] + d1[0] * k) + ' ' + f(A1[1] + d1[1] * k) + ' ' + f(A2[0] - d2[0] * k) + ' ' + f(A2[1] - d2[1] * k) + ' ' + f(A2[0]) + ' ' + f(A2[1]));
		} else {
			for (let q = 0; q < run.length; q++) {
				const B = px(run[q].a, run[q].b), pr = q === 0 ? prev : run[q - 1], nx = q === run.length - 1 ? next : run[q + 1];
				const Pp = px(pr.a, pr.b), Qn = px(nx.a, nx.b), u = P.u, k = P.k * s;
				const uin = q === 0 ? u : 0.5, uout = q === run.length - 1 ? u : 0.5;
				const A1 = [B[0] + uin * (Pp[0] - B[0]), B[1] + uin * (Pp[1] - B[1])], A2 = [B[0] + uout * (Qn[0] - B[0]), B[1] + uout * (Qn[1] - B[1])];
				const d1 = norm([B[0] - Pp[0], B[1] - Pp[1]]), d2 = norm([Qn[0] - B[0], Qn[1] - B[1]]);
				cmds.push('L' + f(A1[0]) + ' ' + f(A1[1]));
				cmds.push('C' + f(A1[0] + d1[0] * k) + ' ' + f(A1[1] + d1[1] * k) + ' ' + f(A2[0] - d2[0] * k) + ' ' + f(A2[1] - d2[1] * k) + ' ' + f(A2[0]) + ' ' + f(A2[1]));
			}
		}
		i = j;
	}
	cmds.push('Z');
	return cmds.join('');
}
function norm(v) { const l = Math.hypot(v[0], v[1]) || 1; return [v[0] / l, v[1] / l]; }

// the loop's over / under pattern at its crossings must alternate
function alternationOK(loop, flip) {
	const xs = loop.filter(e => e.t === 'X');
	if (!xs.length) { return true; }
	const over = e => { const back = e.din[0] === e.din[1]; return back === (((e.b & 1) === 1) !== !!flip); };   // din with da == db is '\'
	for (let i = 0; i < xs.length; i++) { if (over(xs[i]) === over(xs[(i + 1) % xs.length])) { return false; } }
	return true;
}

// ---- cut style (Ash): the under strand is truly cut, leaving a clear gap of ground each side of the over strand.
// Each loop's centreline path is sampled to a polyline; every crossing where the loop passes UNDER removes the
// stretch within (w/2 + ink + gap) of the crossing centre, measured along the strand (strands cross at 90 degrees,
// so the cut faces run parallel to the over strand's edge). The pieces are drawn with butt caps: ink at full
// length, fill trimmed by the ink width at each cut so the outline closes the end square.
function samplePath(d) {
	const tok = d.match(/[MLCZ]|-?[\d.]+(?:e-?\d+)?/g), pts = []; let i = 0, cur = null, start = null;
	while (i < tok.length) {
		const c = tok[i++];
		if (c === 'M') { cur = [+tok[i++], +tok[i++]]; start = cur; pts.push(cur); }
		else if (c === 'L') { const q = [+tok[i++], +tok[i++]], L = Math.hypot(q[0] - cur[0], q[1] - cur[1]), n = Math.max(1, Math.ceil(L / 0.75)); for (let k = 1; k <= n; k++) { pts.push([cur[0] + (q[0] - cur[0]) * k / n, cur[1] + (q[1] - cur[1]) * k / n]); } cur = q; }
		else if (c === 'C') {
			const c1 = [+tok[i++], +tok[i++]], c2 = [+tok[i++], +tok[i++]], q = [+tok[i++], +tok[i++]], n = 24;
			for (let k = 1; k <= n; k++) { const t = k / n, m = 1 - t; pts.push([m * m * m * cur[0] + 3 * m * m * t * c1[0] + 3 * m * t * t * c2[0] + t * t * t * q[0], m * m * m * cur[1] + 3 * m * m * t * c1[1] + 3 * m * t * t * c2[1] + t * t * t * q[1]]); }
			cur = q;
		}
		else if (c === 'Z') { if (start && Math.hypot(start[0] - cur[0], start[1] - cur[1]) > 1e-6) { pts.push(start.slice()); } }
	}
	return pts;   // closed: last point == first
}
// pieces of a closed polyline outside the cut intervals [centre - r, centre + r] (arc length); returns open polylines
function cutPolyline(pts, centres, r, trim) {
	const A = [0]; for (let i = 1; i < pts.length; i++) { A.push(A[i - 1] + Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1])); }
	const T = A[A.length - 1];
	if (!centres.length) { return [{ closed: true, pts }]; }
	const cs = centres.map(c => ((c % T) + T) % T).sort((a, b) => a - b), out = [];
	const at = s => { s = ((s % T) + T) % T; let lo = 0, hi = A.length - 1; while (hi - lo > 1) { const m = (lo + hi) >> 1; if (A[m] <= s) { lo = m; } else { hi = m; } } const t = (s - A[lo]) / ((A[hi] - A[lo]) || 1); return [pts[lo][0] + (pts[hi][0] - pts[lo][0]) * t, pts[lo][1] + (pts[hi][1] - pts[lo][1]) * t]; };
	for (let k = 0; k < cs.length; k++) {
		let s0 = cs[k] + r + trim, s1 = (k + 1 < cs.length ? cs[k + 1] : cs[0] + T) - r - trim;
		if (s1 - s0 < 0.5) { continue; }
		const seg = [at(s0)];
		for (let s = Math.ceil(s0); s < s1; s += 1) { seg.push(at(s)); }
		seg.push(at(s1)); out.push({ closed: false, pts: seg });
	}
	return out;
}
const dOpen = q => 'M' + q.pts.map(p => f(p[0]) + ' ' + f(p[1])).join('L') + (q.closed ? 'Z' : '');

// params from a seed (overridable): s, origin, w, ink, u, k, tightU, tightK
function paramsFromSeed(seed) {
	return { s: seed.grid.s, origin: seed.grid.originPx.slice(), w: seed.stroke.strand * seed.grid.s, ink: seed.stroke.ink * seed.grid.s, u: seed.curve.u, k: seed.curve.k, tightU: seed.curve.tightU, tightK: seed.curve.tightK, flip: seed.over.flip };
}

// build: returns {svg, loops, gates}
function build(seed, P, opt) {
	opt = opt || {};
	const AW = opt.AW, AH = opt.AH, W = opt.W, H = opt.H;
	const Lm = siteMap(seed, AW, AH, opt.cuts), bad = validate(Lm), tr = traceLoops(Lm);
	const colours = opt.colours || { ink: '#000000', fill: '#2a5bd7' };
	const loopFill = opt.loopColours || null;     // array of fills, by 2-colouring
	const s = P.s, X0 = P.origin[0], Y0 = P.origin[1];
	const paths = tr.loops.map(l => loopPath(l, P));
	// crossings: over direction per site
	const patches = [];
	const h = P.w / 2 + P.ink + 1.5;
	// loop membership of each crossing's over strand (for per-loop colours)
	const overLoop = new Map();
	tr.loops.forEach((l, li) => l.forEach(e => {
		if (e.t !== 'X') { return; }
		const back = e.din[0] === e.din[1], isOver = back === (((e.b & 1) === 1) !== !!P.flip);
		if (isOver) { overLoop.set(e.a + ',' + e.b, { li, dir: e.din }); }
	}));
	overLoop.forEach((o, k) => {
		const [a, b] = k.split(',').map(Number), cx = X0 + a * s, cy = Y0 + b * s, d = norm(o.dir);
		// the fill patch runs 1 px past the ink patch so the ink patch's anti-aliased butt ends leave no seam
		const seg = q => 'M' + f(cx - d[0] * q) + ' ' + f(cy - d[1] * q) + 'L' + f(cx + d[0] * q) + ' ' + f(cy + d[1] * q);
		patches.push({ li: o.li, d: seg(h), df: seg(h + 1) });
	});
	const colourOf = li => loopFill ? loopFill[tr.colour ? tr.colour[li] : li % loopFill.length] : colours.fill;
	if (loopFill) { tr.colour = twoColour(tr.loops); }
	const sw = f(P.w + 2 * P.ink), fw = f(P.w);
	if (opt.gap !== undefined && opt.gap !== null) {
		// cut style: under passes removed geometrically (see cutPolyline); no patches
		const r = P.w / 2 + P.ink + opt.gap, inkPieces = [], fillPieces = [];
		tr.loops.forEach((l, li) => {
			const poly = samplePath(paths[li]), A = [0]; for (let i = 1; i < poly.length; i++) { A.push(A[i - 1] + Math.hypot(poly[i][0] - poly[i - 1][0], poly[i][1] - poly[i - 1][1])); }
			const centres = [];
			l.forEach(e => {
				if (e.t !== 'X') { return; }
				const back = e.din[0] === e.din[1], isOver = back === (((e.b & 1) === 1) !== !!P.flip); if (isOver) { return; }
				const cx = X0 + e.a * s, cy = Y0 + e.b * s, dn = norm(e.din);
				// the polyline sample on this site whose heading matches this pass (a loop can cross itself)
				let best = -1, bv = -1e9;
				for (let i = 1; i < poly.length - 1; i++) { const dd = Math.hypot(poly[i][0] - cx, poly[i][1] - cy); if (dd > 1.5) { continue; } const h = norm([poly[i + 1][0] - poly[i - 1][0], poly[i + 1][1] - poly[i - 1][1]]), v = h[0] * dn[0] + h[1] * dn[1] - dd; if (v > bv) { bv = v; best = i; } }
				if (best >= 0) { centres.push(A[best]); }
			});
			cutPolyline(poly, centres, r, 0).forEach(q => inkPieces.push({ li, d: dOpen(q) }));
			cutPolyline(poly, centres, r, P.ink).forEach(q => fillPieces.push({ li, d: dOpen(q) }));
		});
		const tf2 = opt.shift ? ' transform="translate(' + f(opt.shift[0]) + ' ' + f(opt.shift[1]) + ')"' : '';
		let sv = '<svg xmlns="http://www.w3.org/2000/svg" width="' + W + '" height="' + H + '" viewBox="0 0 ' + W + ' ' + H + '">';
		if (opt.background) { sv += '<rect width="' + W + '" height="' + H + '" fill="' + opt.background + '"/>'; }
		sv += '<g' + tf2 + ' fill="none" stroke-linejoin="round" stroke-linecap="butt">';
		sv += '<g stroke="' + colours.ink + '" stroke-width="' + sw + '">' + inkPieces.map(p => '<path d="' + p.d + '"/>').join('') + '</g>';
		sv += '<g stroke-width="' + fw + '">' + fillPieces.map(p => '<path stroke="' + colourOf(p.li) + '" d="' + p.d + '"/>').join('') + '</g>';
		sv += '</g></svg>';
		const gates = { sitesValid: bad.length === 0, closed: !tr.error, alternates: tr.loops.every(l => alternationOK(l, P.flip)), badSites: bad.slice(0, 10), traceError: tr.error, pieces: inkPieces.length };
		// pieces by loop colour (2-colouring along the interlock graph), for exporters that place each colour separately
		return { svg: sv, loops: tr.loops, map: Lm, gates, pieces: { ink: inkPieces, fill: fillPieces, colour: twoColour(tr.loops), inkWidth: +sw, fillWidth: +fw } };
	}
	const tf = opt.shift ? ' transform="translate(' + f(opt.shift[0]) + ' ' + f(opt.shift[1]) + ')"' : '';
	let svg = '<svg xmlns="http://www.w3.org/2000/svg" width="' + W + '" height="' + H + '" viewBox="0 0 ' + W + ' ' + H + '">';
	if (opt.background) { svg += '<rect width="' + W + '" height="' + H + '" fill="' + opt.background + '"/>'; }
	svg += '<g' + tf + ' fill="none" stroke-linejoin="round">';
	svg += '<g stroke="' + colours.ink + '" stroke-width="' + sw + '">' + paths.map(d => '<path d="' + d + '"/>').join('') + '</g>';
	svg += '<g stroke-width="' + fw + '">' + paths.map((d, li) => '<path stroke="' + colourOf(li) + '" d="' + d + '"/>').join('') + '</g>';
	svg += '<g stroke-linecap="butt">' + patches.map(p => '<path stroke="' + colours.ink + '" stroke-width="' + sw + '" d="' + p.d + '"/><path stroke="' + colourOf(p.li) + '" stroke-width="' + fw + '" d="' + p.df + '"/>').join('') + '</g>';
	svg += '</g></svg>';
	const gates = {
		sitesValid: bad.length === 0,
		closed: !tr.error,
		alternates: tr.loops.every(l => alternationOK(l, P.flip)),
		badSites: bad.slice(0, 10), traceError: tr.error,
	};
	return { svg, loops: tr.loops, map: Lm, gates };
}

// 2-colour loops along the interlock graph (loops that cross each other get different colours where possible)
function twoColour(loops) {
	const at = new Map(); loops.forEach((l, li) => l.forEach(e => { if (e.t === 'X') { const k = e.a + ',' + e.b; if (!at.has(k)) { at.set(k, new Set()); } at.get(k).add(li); } }));
	const adj = loops.map(() => new Set()); at.forEach(set => { const a = [...set]; if (a.length === 2) { adj[a[0]].add(a[1]); adj[a[1]].add(a[0]); } });
	const col = loops.map(() => -1);
	for (let r = 0; r < loops.length; r++) { if (col[r] >= 0) { continue; } col[r] = 0; const q = [r]; while (q.length) { const x = q.shift(); adj[x].forEach(y => { if (col[y] < 0) { col[y] = 1 - col[x]; q.push(y); } }); } }
	return col;
}

module.exports = { samplePath, cutPolyline, build, siteMap, applyCuts, validate, traceLoops, loopPath, paramsFromSeed, twoColour, alternationOK };

if (require.main === module) {
	const fs = require('fs');
	const [seedFile, out, AWs, AHs] = process.argv.slice(2);
	const seed = JSON.parse(fs.readFileSync(seedFile, 'utf8'));
	const AH = +(AHs || seed.frame.H), AW = +(AWs || AH);
	const P = paramsFromSeed(seed), W = seed.image.w, H = seed.image.h;
	// CUTS=E: break the top and bottom strips for the arms and the award detail, end walls at column E and AW - E
	const cuts = process.env.CUTS ? { top: +process.env.CUTS, bottom: +process.env.CUTS } : null;
	// ASH=fill: Ash's inked style -- fill px, ink 0.52 x fill per side, true cut gap 0.53 x fill (see cutPolyline)
	let gap = null; if (process.env.ASH) { const fl = +process.env.ASH; P.w = fl; P.ink = 0.52 * fl; gap = 0.53 * fl; }
	const r = build(seed, P, { AW, AH, W, H, cuts, gap, loopColours: process.env.COLOUR ? ['#c0392b', '#2e9e3e'] : null });
	fs.writeFileSync(out, r.svg);
	console.log(JSON.stringify({ loops: r.loops.length, gates: r.gates }));
}
