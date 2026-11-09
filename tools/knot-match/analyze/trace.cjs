'use strict';
// trace.cjs -- strand fragments -> centrelines -> loops with an over/under crossing graph.
//
// A fragment is one fill region: a piece of strand between two places where it passes UNDER another strand (or the
// image edge). Its centreline is the ridge of the distance-to-ink map, ordered end to end. At each end the strand
// dives under an over strand; its continuation is the fragment whose end faces it from the other side of that over
// strand, roughly one over-strand width (fill + 2 ink) away, tangent-aligned, with the straight gap between them
// crossing fill (the over strand) and never open ground. Linking every end gives chains; a chain that returns to
// its start is a closed loop. Each link is one crossing: the linked loop is UNDER there and the loop owning the
// fragment under the link midpoint is OVER.
const IM = require('./image.cjs');

// ---- centreline of one band-shaped region: walk the ridge of dInk -------------------------------------------
// Zhang-Suen thinning of the region mask, then the longest path through the skeleton graph.
function thin(mask, w, h, bbox) {
	const [x0, y0, x1, y1] = bbox, W = x1 - x0 + 3, H = y1 - y0 + 3, m = new Uint8Array(W * H);
	for (let y = y0; y <= y1; y++) { for (let x = x0; x <= x1; x++) { if (mask(x, y)) { m[(y - y0 + 1) * W + (x - x0 + 1)] = 1; } } }
	const N = (i) => [m[i - W], m[i - W + 1], m[i + 1], m[i + W + 1], m[i + W], m[i + W - 1], m[i - 1], m[i - W - 1]];
	let changed = true;
	while (changed) {
		changed = false;
		for (const step of [0, 1]) {
			const del = [];
			for (let y = 1; y < H - 1; y++) {
				for (let x = 1; x < W - 1; x++) {
					const i = y * W + x; if (!m[i]) { continue; }
					const p = N(i), B = p.reduce((a, v) => a + v, 0); if (B < 2 || B > 6) { continue; }
					let A = 0; for (let k = 0; k < 8; k++) { if (!p[k] && p[(k + 1) % 8]) { A++; } } if (A !== 1) { continue; }
					if (step === 0 ? (p[0] * p[2] * p[4] || p[2] * p[4] * p[6]) : (p[0] * p[2] * p[6] || p[0] * p[4] * p[6])) { continue; }
					del.push(i);
				}
			}
			if (del.length) { changed = true; del.forEach(i => { m[i] = 0; }); }
		}
	}
	const pts = []; for (let y = 1; y < H - 1; y++) { for (let x = 1; x < W - 1; x++) { if (m[y * W + x]) { pts.push([x + x0 - 1, y + y0 - 1]); } } }
	return pts;
}
function longestPath(pts) {
	if (pts.length < 2) { return pts.slice(); }
	const key = p => p[0] + ',' + p[1], idx = new Map(pts.map((p, i) => [key(p), i]));
	const nb = pts.map(p => { const o = []; for (let dy = -1; dy <= 1; dy++) { for (let dx = -1; dx <= 1; dx++) { if (dx || dy) { const j = idx.get((p[0] + dx) + ',' + (p[1] + dy)); if (j != null) { o.push([j, Math.hypot(dx, dy)]); } } } } return o; });
	const far = s => { const d = new Float64Array(pts.length).fill(Infinity), prev = new Int32Array(pts.length).fill(-1); d[s] = 0; const q = [s];
		// Dijkstra-lite (small graphs): repeated relaxation
		while (q.length) { const i = q.shift(); for (const [j, c] of nb[i]) { if (d[i] + c < d[j]) { d[j] = d[i] + c; prev[j] = i; q.push(j); } } }
		let b = s; for (let i = 0; i < pts.length; i++) { if (d[i] < Infinity && d[i] > d[b]) { b = i; } } return { b, prev, d }; };
	const a = far(0).b, r = far(a), path = []; for (let i = r.b; i >= 0; i = r.prev[i]) { path.push(pts[i]); if (i === a) { break; } }
	return path;
}
// smooth + resample a polyline at ~step px
function resample(P, step) {
	if (P.length < 2) { return P.slice(); }
	const c = [0]; for (let i = 1; i < P.length; i++) { c[i] = c[i - 1] + Math.hypot(P[i][0] - P[i - 1][0], P[i][1] - P[i - 1][1]); }
	const L = c[c.length - 1], n = Math.max(2, Math.round(L / step) + 1), o = []; let k = 1;
	for (let j = 0; j < n; j++) { const t = L * j / (n - 1); while (k < P.length - 1 && c[k] < t) { k++; } const f = (t - c[k - 1]) / ((c[k] - c[k - 1]) || 1); o.push([P[k - 1][0] + (P[k][0] - P[k - 1][0]) * f, P[k - 1][1] + (P[k][1] - P[k - 1][1]) * f]); }
	return o;
}
function smoothPoly(P, it) { let Q = P; for (let k = 0; k < it; k++) { Q = Q.map((p, i) => (i === 0 || i === Q.length - 1) ? p : [(Q[i - 1][0] + 2 * p[0] + Q[i + 1][0]) / 4, (Q[i - 1][1] + 2 * p[1] + Q[i + 1][1]) / 4]); } return Q; }
function tangentAt(P, end, span) {   // outward unit tangent at end 0 (start) or 1 (end), fitted over `span` px
	const Q = end ? P.slice().reverse() : P; let k = 1, L = 0; while (k < Q.length - 1 && L < span) { L += Math.hypot(Q[k][0] - Q[k - 1][0], Q[k][1] - Q[k - 1][1]); k++; }
	const dx = Q[0][0] - Q[k][0], dy = Q[0][1] - Q[k][1], l = Math.hypot(dx, dy) || 1; return [dx / l, dy / l];
}

function fragments(cm) {
	const { w, h, c, lab, regions, halfW } = cm, out = [];
	regions.forEach(r => {
		if (r.cls !== IM.CLS.FILL) { return; }
		let x0 = w, y0 = h, x1 = 0, y1 = 0; r.px.forEach(i => { const x = i % w, y = (i - x) / w; if (x < x0) { x0 = x; } if (x > x1) { x1 = x; } if (y < y0) { y0 = y; } if (y > y1) { y1 = y; } });
		const sk = thin((x, y) => x >= 0 && y >= 0 && x < w && y < h && lab[y * w + x] === r.id, w, h, [x0, y0, x1, y1]);
		let P = longestPath(sk);
		if (P.length < 2) { return; }
		P = smoothPoly(resample(P, 1), 3); P = resample(P, 1);
		// thinning stops ~halfW short of each end face: extend each end along its tangent to the region boundary
		for (const end of [0, 1]) {
			const t = tangentAt(P, end, Math.max(4, halfW)), q = end ? P[P.length - 1] : P[0], ext = [];
			for (let s = 1; s < 3 * halfW; s++) { const x = Math.round(q[0] + t[0] * s), y = Math.round(q[1] + t[1] * s); if (x < 0 || y < 0 || x >= w || y >= h || lab[y * w + x] !== r.id) { break; } ext.push([q[0] + t[0] * s, q[1] + t[1] * s]); }
			if (end) { P = P.concat(ext); } else { P = ext.reverse().concat(P); }
		}
		const touchesEdge = r.edge;
		out.push({ id: out.length, region: r.id, pts: P, len: P.length, edge: touchesEdge, ends: [{ p: P[0], t: tangentAt(P, 0, halfW * 1.2) }, { p: P[P.length - 1], t: tangentAt(P, 1, halfW * 1.2) }] });
	});
	return out;
}

// gap test: fraction of samples on the straight segment a->b that are fill (the over strand) vs ground
function gapStats(cm, a, b) {
	const n = Math.max(2, Math.ceil(Math.hypot(b[0] - a[0], b[1] - a[1]))); let fill = 0, ground = 0;
	for (let k = 1; k < n; k++) { const x = Math.round(a[0] + (b[0] - a[0]) * k / n), y = Math.round(a[1] + (b[1] - a[1]) * k / n); const v = cm.c[y * cm.w + x]; if (v === IM.CLS.FILL) { fill++; } else if (v === IM.CLS.GROUND) { ground++; } }
	return { fill: fill / (n - 1), ground: ground / (n - 1) };
}
function overAt(cm, a, b) {   // the fill region under the gap midpoint (the over strand's fragment region)
	const x = Math.round((a[0] + b[0]) / 2), y = Math.round((a[1] + b[1]) / 2); let best = null;
	for (let r = 0; r <= 3 && best == null; r++) { for (let dy = -r; dy <= r; dy++) { for (let dx = -r; dx <= r; dx++) { const X = x + dx, Y = y + dy; if (X < 0 || Y < 0 || X >= cm.w || Y >= cm.h) { continue; } if (cm.c[Y * cm.w + X] === IM.CLS.FILL) { best = cm.lab[Y * cm.w + X]; } } } }
	return best;
}

function link(cm, frags) {
	const D = 2 * cm.halfW + 2 * cm.inkW;   // expected gap: one over strand (fill + two inks) -- measured, refined below
	const ends = []; frags.forEach(f => f.ends.forEach((e, k) => ends.push({ f: f.id, k, p: e.p, t: e.t })));
	const cand = [];
	for (let i = 0; i < ends.length; i++) {
		for (let j = i + 1; j < ends.length; j++) {
			const a = ends[i], b = ends[j]; if (a.f === b.f) { continue; }
			const dx = b.p[0] - a.p[0], dy = b.p[1] - a.p[1], d = Math.hypot(dx, dy); if (d < 0.4 * D || d > 2.2 * D) { continue; }
			const ux = dx / d, uy = dy / d, ca = a.t[0] * ux + a.t[1] * uy, cb = -(b.t[0] * ux + b.t[1] * uy);
			if (ca < 0.8 || cb < 0.8) { continue; }
			const g = gapStats(cm, a.p, b.p); if (g.ground > 0.15) { continue; }
			const cost = (1 - ca) + (1 - cb) + Math.abs(d - D) / D + g.ground;
			cand.push({ i, j, d, cost });
		}
	}
	cand.sort((x, y) => x.cost - y.cost);
	const used = new Set(), links = [];
	cand.forEach(c => { if (used.has(c.i) || used.has(c.j)) { return; } used.add(c.i); used.add(c.j); links.push(c); });
	const gap = IM.median(links.map(l => l.d));
	return { ends, links, gap, freeEnds: ends.filter((e, i) => !used.has(i)) };
}

// walk links into chains/loops. Returns loops: [{frags:[{f, rev}], closed, pts (joined centreline), unders:[{at, overRegion}]}]
function chains(cm, frags, L) {
	const partner = new Map(); L.links.forEach(l => { partner.set(l.i, l.j); partner.set(l.j, l.i); });
	const endIdx = (f, k) => L.ends.findIndex(e => e.f === f && e.k === k);
	const seen = new Set(), out = [];
	frags.forEach(f0 => {
		if (seen.has(f0.id)) { return; }
		// walk backwards to a free end (if any) so open chains start at their beginning
		let f = f0.id, k = 0, guard = 0;
		while (guard++ < frags.length) { const e = endIdx(f, k), p = partner.get(e); if (p == null) { break; } const nf = L.ends[p].f, nk = 1 - L.ends[p].k; if (nf === f0.id) { break; } f = nf; k = nk; }
		const seq = []; let closed = false; guard = 0;
		// now walk forward from (f, entering at k)
		while (guard++ <= frags.length) {
			if (seen.has(f)) { closed = f === seq[0].f; break; }
			seen.add(f); seq.push({ f, rev: k === 1 });
			const e = endIdx(f, 1 - k), p = partner.get(e); if (p == null) { break; }
			f = L.ends[p].f; k = L.ends[p].k;
		}
		const pts = [], unders = [];
		seq.forEach((s, n) => {
			const P = s.rev ? frags[s.f].pts.slice().reverse() : frags[s.f].pts;
			if (n > 0) { const a = pts[pts.length - 1], b = P[0]; unders.push({ at: [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2], idx: pts.length, overRegion: overAt(cm, a, b) }); }
			P.forEach(p => pts.push(p));
		});
		if (closed) { const a = pts[pts.length - 1], b = pts[0]; unders.push({ at: [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2], idx: pts.length, overRegion: overAt(cm, a, b) }); }
		out.push({ id: out.length, frags: seq, closed, pts, unders, edge: seq.some(s => frags[s.f].edge) });
	});
	// region -> loop, to name the OVER loop of every crossing
	const regLoop = new Map(); out.forEach(lp => lp.frags.forEach(s => regLoop.set(frags[s.f].region, lp.id)));
	out.forEach(lp => lp.unders.forEach(u => { u.overLoop = regLoop.has(u.overRegion) ? regLoop.get(u.overRegion) : null; }));
	return out;
}

function analyseStrands(cm) {
	const frags = fragments(cm), L = link(cm, frags), loops = chains(cm, frags, L);
	return { frags, links: L.links, gap: L.gap, freeEnds: L.freeEnds, loops };
}

module.exports = { fragments, link, chains, analyseStrands, resample, smoothPoly };

if (require.main === module) {
	const [file, outPng] = process.argv.slice(2);
	const cm = IM.classify(IM.load(file)), S = analyseStrands(cm);
	const closed = S.loops.filter(l => l.closed), open = S.loops.filter(l => !l.closed);
	console.log(JSON.stringify({ halfW: cm.halfW, inkW: cm.inkW, frags: S.frags.length, links: S.links.length, gap: +S.gap.toFixed(2), freeEnds: S.freeEnds.length, loops: S.loops.length, closed: closed.length, open: open.length, openOnEdge: open.filter(l => l.edge).length,
		closedSizes: closed.map(l => l.frags.length + '/' + l.pts.length).join(' ') }));
	if (outPng) {
		const { PNG } = require('pngjs'), fs = require('fs'), sc = 2, W = cm.w * sc, H = cm.h * sc, png = new PNG({ width: W, height: H });
		for (let i = 0; i < W * H; i++) { const k = cm.c[(((i / W) | 0) / sc | 0) * cm.w + ((i % W) / sc | 0)]; const v = k === 1 ? 120 : k === 2 ? 235 : 250; png.data[i * 4] = png.data[i * 4 + 1] = png.data[i * 4 + 2] = v; png.data[i * 4 + 3] = 255; }
		const hue = id => { const a = (id * 137.5) % 360 / 60, x = 1 - Math.abs(a % 2 - 1), t = [[1, x, 0], [x, 1, 0], [0, 1, x], [0, x, 1], [x, 0, 1], [1, 0, x]][Math.floor(a) % 6]; return t.map(v => Math.round(40 + 200 * v)); };
		const dot = (x, y, col, r) => { for (let dy = -r; dy <= r; dy++) { for (let dx = -r; dx <= r; dx++) { const X = Math.round(x * sc) + dx, Y = Math.round(y * sc) + dy; if (X < 0 || Y < 0 || X >= W || Y >= H) { continue; } const o = (Y * W + X) * 4; png.data[o] = col[0]; png.data[o + 1] = col[1]; png.data[o + 2] = col[2]; } } };
		S.loops.forEach(lp => { const col = lp.closed ? hue(lp.id) : [255, 0, 0]; lp.pts.forEach(p => dot(p[0], p[1], col, 1)); for (let i = 1; i < lp.pts.length; i++) { const a = lp.pts[i - 1], b = lp.pts[i], n = Math.ceil(Math.hypot(b[0] - a[0], b[1] - a[1])); for (let k = 0; k < n; k++) { dot(a[0] + (b[0] - a[0]) * k / n, a[1] + (b[1] - a[1]) * k / n, col, 0); } } });
		S.freeEnds.forEach(e => dot(e.p[0], e.p[1], [255, 0, 0], 3));
		fs.writeFileSync(outPng, PNG.sync.write(png));
	}
}
