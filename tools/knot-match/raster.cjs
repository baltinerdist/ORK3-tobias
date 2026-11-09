'use strict';
/* raster.cjs -- in-process rasteriser for the knot engine's SVG (knotmatch --raster js).

   The engine emits only flat-colour stroked polylines: <path d="M..L..[Z]" fill="none" stroke="#rgb"
   stroke-width="w" stroke-linecap="butt|round" stroke-linejoin="round">, plus zero-length round-capped dots
   ('M x y l0 0'), over a full-page background rect, in two plain <g>s (painter's order). That is all this
   draws; anything else (gradients, transforms, other elements or attributes) returns null and the caller
   falls back to rsvg-convert.

   It follows cairo, which rsvg-convert draws with: coordinates in 24.8 fixed point; each stroke turned into
   cairo's stroke polygon (offset contours, inner joins through the vertex, outer round joins as a fan of the
   pen's vertices or a miter point for small turns, dropped near-duplicate points); the polygon filled with
   nonzero winding (GY sub-rows per pixel, exact x coverage); paths composited source-over with an 8-bit
   mask and pixman's rounded multiplies; each pixel classed by the nearest palette colour.

   Against rsvg on 315 renders (105 candidates around the five saved bests, every robust copy): per-pixel class
   agreement >= 99.84% (mean 99.90-99.95%), candidate scores within 0.00052, Spearman 1.0; region scores within
   0.0017 except where the alignment search picks a different shift (2 of 630). Output: the same full-size
   class map as classMapCropped (ground outside the boxes). */

// parse the page SVG produced by knotmatch renderSvg -> { W, H, bg:[r,g,b], paths:[{pts:Float64Array, closed, rgb, hw, round}] } or null
const RGB = new Map();
function hexRgb(h) { if (!RGB.has(h)) { RGB.set(h, hexRgb0(h)); } return RGB.get(h); }
function hexRgb0(h) {
	if (!/^#([0-9a-f]{3}|[0-9a-f]{6})$/i.test(h)) { return null; }
	if (h.length === 4) { return [parseInt(h[1] + h[1], 16), parseInt(h[2] + h[2], 16), parseInt(h[3] + h[3], 16)]; }
	return [parseInt(h.slice(1, 3), 16), parseInt(h.slice(3, 5), 16), parseInt(h.slice(5, 7), 16)];
}
const RE_TAG = /<(\/?)([a-zA-Z]+)([^>]*)>/g;
const RE_ATTR = / ([a-zA-Z-]+)="([^"]*)"/g;
// svg: the SVG text, or knotmatch's element tree ({tag, attrs, kids}; a path's d may be a LazyD -- points as numbers,
// read here exactly as the text would parse: each coordinate +x.toFixed(2)). Same checks either way.
function parseSvg(svg) {
	let m, root = null, bg = null; const paths = [];
	const tags = [];
	if (typeof svg === 'string') {
		RE_TAG.lastIndex = 0;
		while ((m = RE_TAG.exec(svg))) {
			if (m[1]) { continue; }
			const at = {}; let a;
			RE_ATTR.lastIndex = 0;
			while ((a = RE_ATTR.exec(m[3]))) { at[a[1]] = a[2]; }
			tags.push([m[2], at]);
		}
	} else {
		const walk = el => { tags.push([el.tag, el.attrs]); el.kids.forEach(walk); };
		walk(svg);
	}
	for (const [tag, at] of tags) {
		if (tag === 'svg') {
			if (root) { return null; }
			root = at; continue;
		}
		if (tag === 'g') { if (Object.keys(at).length) { return null; } continue; }
		if (tag === 'rect') {
			if (bg || paths.length || at.x || at.y || Object.keys(at).some(k => !/^(width|height|fill)$/.test(k))) { return null; }
			bg = { w: +at.width, h: +at.height, rgb: hexRgb(at.fill) }; if (!bg.rgb) { return null; }
			continue;
		}
		if (tag !== 'path') { return null; }
		if (Object.keys(at).some(k => !/^(d|fill|stroke|stroke-width|stroke-linecap|stroke-linejoin|stroke-miterlimit)$/.test(k))) { return null; }
		// V9 painter: a filled closed polygon (no stroke) -- the engine's slanted / tapered cut ends
		if (at.fill !== 'none' && at.fill != null && Object.keys(at).length === 2) {
			const rgbF = hexRgb(at.fill); if (!rgbF) { return null; }
			const pf = typeof at.d === 'string' ? parseD(at.d) : (at.d && at.d.c ? { pts: null, lazy: at.d, closed: !!at.d.closed } : null);
			if (!pf || !pf.closed) { return null; }
			paths.push({ pts: pf.pts, lazy: pf.lazy, closed: true, rgb: rgbF, hw: 0, round: false, fill: true });
			continue;
		}
		// V9: stroke-linejoin miter (+ stroke-miterlimit, default 4) besides round
		const jn = at['stroke-linejoin'], miter = jn === 'miter' ? (at['stroke-miterlimit'] != null ? +at['stroke-miterlimit'] : 4) : 0;
		if (at.fill !== 'none' || (jn !== 'round' && !(miter >= 1))) { return null; }
		if (jn === 'round' && at['stroke-miterlimit'] != null) { return null; }
		const rgb = hexRgb(at.stroke), cap = at['stroke-linecap'];
		if (!rgb || (cap !== 'butt' && cap !== 'round')) { return null; }
		// a LazyD's points are rounded only if the path reaches a box (classMapJS)
		const p = typeof at.d === 'string' ? parseD(at.d) : (at.d && at.d.c ? { pts: null, lazy: at.d, closed: !!at.d.closed } : null); if (!p) { return null; }
		paths.push(miter ? { pts: p.pts, lazy: p.lazy, closed: p.closed, rgb, hw: +at['stroke-width'] / 2, round: cap === 'round', miter } : { pts: p.pts, lazy: p.lazy, closed: p.closed, rgb, hw: +at['stroke-width'] / 2, round: cap === 'round' });
	}
	if (!root || !bg || !root.viewBox) { return null; }
	const vb = root.viewBox.split(/\s+/).map(Number);
	if (vb[0] !== 0 || vb[1] !== 0 || bg.w !== vb[2] || bg.h !== vb[3]) { return null; }
	return { W: vb[2], H: vb[3], bg: bg.rgb, paths };
}
// +x.toFixed(2) without the string: toFixed picks the integer n nearest to 100|x| (the larger on a tie) and the text
// n/100 parses to the double nearest n/100 -- which is what n / 100 (a correctly rounded division) is. 100|x| is
// within an ulp of the true product, so unless it lies within 1e-7 of a half-integer Math.round gives that n; near a
// half (and for huge or non-finite x) the string route decides. The sign is kept as toFixed keeps it (-0.001 -> -0).
function fix2(x) {
	const a = x < 0 ? -x : x, y = a * 100, f = y - Math.floor(y);
	if (!(y < 1e15) || (f > 0.5 - 1e-7 && f < 0.5 + 1e-7)) { return +x.toFixed(2); }
	const v = Math.round(y) / 100 + 0;            // + 0: x = -0 reads as 0, as (-0).toFixed(2) does
	return x < 0 ? -v : v;
}
// a LazyD's points as parseD would read its text: coordinates rounded by toFixed(2), consecutive duplicates dropped
function lazyPts(d) {
	if (!d || !d.c) { return null; }
	const c = d.c, out = [];
	for (let i = 0; i < c.length; i += 2) {
		const x = fix2(c[i]), y = fix2(c[i + 1]);
		if (!(out.length && out[out.length - 2] === x && out[out.length - 1] === y)) { out.push(x, y); }
	}
	return { pts: out, closed: !!d.closed };
}
// 'M x y L x y ... [Z]' or 'M x y l0 0' (one subpath); consecutive duplicate points dropped
function parseD(d) {
	const tok = d.match(/[MLlZz]|-?\d*\.?\d+(?:[eE][-+]?\d+)?/g);
	if (!tok || tok[0] !== 'M') { return null; }
	const out = []; let i = 1, cmd = 'M', closed = false;
	while (i < tok.length) {
		const t = tok[i];
		if (t === 'L' || t === 'l') { cmd = t; i++; continue; }
		if (t === 'Z' || t === 'z') { closed = true; i++; if (i < tok.length) { return null; } break; }
		if (t === 'M') { return null; }
		let x = +tok[i], y = +tok[i + 1]; i += 2;
		if (cmd === 'l') { x += out[out.length - 2]; y += out[out.length - 1]; }
		if (!(out.length && out[out.length - 2] === x && out[out.length - 1] === y)) { out.push(x, y); }
	}
	return { pts: out, closed };
}

const PAL = [[244, 234, 210], [0, 0, 0], [42, 91, 215], [224, 106, 160]];
// Scratch buffers, reused across calls. The class map itself comes from a ring of OUT_RING full-size buffers: each
// is handed out zeroed (the boxes written into it last time are cleared on reuse), so a map stays valid until
// OUT_RING - 1 later calls -- callers score a raster before rendering the next (a two-engine joint holds two).
const OUT_RING = 4, OUTS = [];
let OUTI = 0, SCR = null;
function outBuffer(W, H, merged) {
	OUTI = (OUTI + 1) % OUT_RING;
	let o = OUTS[OUTI];
	if (!o || o.W !== W || o.H !== H) { o = OUTS[OUTI] = { W, H, c: new Uint8Array(W * H), boxes: [] }; }
	else { o.boxes.forEach(b => { for (let y = b[1]; y < b[3]; y++) { o.c.fill(0, y * W + b[0], y * W + b[2]); } }); }
	o.boxes = merged;
	return o.c;
}
function scratch(n) {
	if (!SCR || SCR.n < n) { const m = Math.max(n, SCR ? 2 * SCR.n : 0); SCR = { n: m, R: new Uint8Array(m), G: new Uint8Array(m), B: new Uint8Array(m), cov: new Float32Array(m) }; }
	return SCR;
}
// boxes: [x0,y0,x1,y1] in raster px; s = raster px per page unit. Returns { w, h, c } or null (unsupported SVG).
function classMapJS(svg, boxes, W, H, s, pal, gy) {
	const P = parseSvg(svg); if (!P) { return null; }
	GY = gy > 0 ? gy : GY_CAIRO;
	pal = pal || PAL;
	const bx = boxes.map(b => [Math.max(0, Math.floor(b[0])), Math.max(0, Math.floor(b[1])), Math.min(W, Math.ceil(b[2])), Math.min(H, Math.ceil(b[3]))]);
	const merged = [];
	bx.forEach(b => {
		for (let i = 0; i < merged.length; i++) {
			const m = merged[i];
			if (b[0] < m[2] && m[0] < b[2] && b[1] < m[3] && m[1] < b[3]) { merged.splice(i, 1); b = [Math.min(b[0], m[0]), Math.min(b[1], m[1]), Math.max(b[2], m[2]), Math.max(b[3], m[3])]; i = -1; }
		}
		if (b[2] > b[0] && b[3] > b[1]) { merged.push(b); }
	});
	// a lazy path (element tree) whose raw box -- one px wider than the rounded one could be -- misses every box is
	// one the loop below would skip at every box anyway: dropped before its points are rounded
	const reaches = p => {
		const c = p.lazy.c, hw = p.hw * s; let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
		for (let i = 0; i < c.length; i += 2) { const x = c[i], y = c[i + 1]; if (x < x0) { x0 = x; } if (x > x1) { x1 = x; } if (y < y0) { y0 = y; } if (y > y1) { y1 = y; } }
		const bb = [x0 * s - hw - 2, y0 * s - hw - 2, x1 * s + hw + 2, y1 * s + hw + 2];
		return merged.some(b => Math.max(b[0], Math.floor(bb[0])) < Math.min(b[2], Math.ceil(bb[2])) && Math.max(b[1], Math.floor(bb[1])) < Math.min(b[3], Math.ceil(bb[3])));
	};
	const out = outBuffer(W, H, merged);
	const live = P.paths.filter(p => { if (!p.lazy) { return true; } if (!reaches(p)) { return false; } p.pts = lazyPts(p.lazy).pts; return true; });
	// paths in raster px, with their bounding boxes (stroke included)
	const paths = live.map(p => {
		const q = new Float64Array(p.pts.length); let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
		for (let i = 0; i < q.length; i += 2) {
			const x = q[i] = Math.round(p.pts[i] * s * 256) / 256, y = q[i + 1] = Math.round(p.pts[i + 1] * s * 256) / 256;   // cairo's 24.8 fixed point
			if (x < x0) { x0 = x; } if (x > x1) { x1 = x; } if (y < y0) { y0 = y; } if (y > y1) { y1 = y; }
		}
		const hw = p.hw * s;
		let m = 2; for (let i = 2; i < q.length; i += 2) { if (q[i] !== q[m - 2] || q[i + 1] !== q[m - 1]) { q[m++] = q[i]; q[m++] = q[i + 1]; } }
		if (p.closed && m > 2 && q[0] === q[m - 2] && q[1] === q[m - 1]) { m -= 2; }
		const r = { q: q.subarray(0, m), closed: p.closed, rgb: p.rgb, hw, hwUser: p.hw, round: p.round, bb: [x0 - hw - 1, y0 - hw - 1, x1 + hw + 1, y1 + hw + 1] };
		if (p.fill) { r.fill = true; } if (p.miter) { r.miter = p.miter; }   // V9 (absent on V8 SVGs)
		return r;
	});
	for (const b of merged) {
		const cw = b[2] - b[0], ch = b[3] - b[1];
		// channels are whole numbers 0..255 throughout (mul8 rounds), so 8-bit arrays hold them exactly
		const S = scratch(cw * ch), R = S.R.subarray(0, cw * ch), G = S.G.subarray(0, cw * ch), B = S.B.subarray(0, cw * ch), cov = S.cov.subarray(0, cw * ch);
		R.fill(P.bg[0]); G.fill(P.bg[1]); B.fill(P.bg[2]); cov.fill(0);
		for (const p of paths) {
			const X0 = Math.max(b[0], Math.floor(p.bb[0])), Y0 = Math.max(b[1], Math.floor(p.bb[1])), X1 = Math.min(b[2], Math.ceil(p.bb[2])), Y1 = Math.min(b[3], Math.ceil(p.bb[3]));
			if (X0 >= X1 || Y0 >= Y1) { continue; }
			// cov is all zero between paths: fillNonzero writes only inside its per-row spans (SPAN), which are
			// composited and cleared here -- the rest of the path's bounding box is never touched
			const ry = fillNonzero(p.fill ? [Array.from(p.q)] : strokePolys(p, p.hwUser), cov, b[0], b[1], cw, X0, Y0, X1, Y1);
			if (!ry) { continue; }
			const r = p.rgb[0], g = p.rgb[1], bl = p.rgb[2];
			for (let y = ry[0]; y < ry[1]; y++) {
				const lo = SPAN[2 * (y - ry[0])], hi = SPAN[2 * (y - ry[0]) + 1]; if (hi < lo) { continue; }
				let i = (y - b[1]) * cw + X0 - b[0] + lo;
				for (let x = lo; x <= hi; x++, i++) {
					const c = cov[i]; if (c <= 0) { continue; }
					cov[i] = 0;
					// pixman OVER with an 8-bit mask, as cairo composites: alpha = round(255 cov), rounded multiplies
					const a = Math.round(c * 255);
					if (a === 255) { R[i] = r; G[i] = g; B[i] = bl; continue; }     // mul8(x, 255) = x, mul8(x, 0) = 0
					const na = 255 - a;
					R[i] = mul8(r, a) + mul8(R[i], na); G[i] = mul8(g, a) + mul8(G[i], na); B[i] = mul8(bl, a) + mul8(B[i], na);
				}
			}
		}
		if (classMapJS.debug) { classMapJS.debug.push({ b, R: R.slice(), G: G.slice(), B: B.slice() }); }
		for (let y = 0; y < ch; y++) {
			let i = y * cw, o = (b[1] + y) * W + b[0], pr = -1, pg = -1, pb = -1, best = 0;
			for (let x = 0; x < cw; x++, i++, o++) {
				const r = R[i], g = G[i], bl = B[i];
				if (r !== pr || g !== pg || bl !== pb) {      // a run of one colour classes once
					let bd = 1e18; best = 0; pr = r; pg = g; pb = bl;
					for (let k = 0; k < 4; k++) { const q = pal[k], d = (r - q[0]) * (r - q[0]) + (g - q[1]) * (g - q[1]) + (bl - q[2]) * (bl - q[2]); if (d < bd) { bd = d; best = k; } }
				}
				out[o] = best;
			}
		}
	}
	return { w: W, h: H, c: out };
}
function mul8(x, a) { const t = x * a + 0x80; return ((t >> 8) + t) >> 8; }

// ---------------------------------------------------------------- cairo-style stroke polygon + nonzero scan
// The stroke as cairo's polygon stroker builds it: left and right offset contours; at each join the inner side
// runs through the vertex, the outer side gets a fan of pen vertices (or, when the turn is within the cusp
// tolerance, a miter point); points within CTOL of the previous one are dropped and joins whose offset points
// all fall within CTOL are skipped. Filled with nonzero winding by a scanline with GY sub-rows (exact x).
const TOL = 0.1, CTOL = 0.1, MITER = 4, GY_CAIRO = 15;
let GY = GY_CAIRO;           // classMapJS(..., gy): fewer sub-rows (knotmatch --raster js:N, opt-in, not cairo's 15)
function penN(r) { if (TOL >= 4 * r) { return 1; } if (TOL >= r) { return 4; } let n = Math.ceil(2 * Math.PI / Math.acos(1 - TOL / r)); if (n % 2) { n++; } return Math.max(4, n); }
const fx8 = v => Math.round(v * 256) / 256;
function strokePolys(p, hwUser) {
	const q = p.q, hw = p.hw, n = q.length >> 1, N = penN(hw), polys = [];
	const cusp = 2 * (1 - TOL / hwUser) * (1 - TOL / hwUser) - 1;
	const add = (c, x, y) => { const m = c.length; if (m && (c[m - 2] - x) * (c[m - 2] - x) + (c[m - 1] - y) * (c[m - 1] - y) < CTOL * CTOL) { return; } c.push(x, y); };
	// pen vertices strictly between angles a0 -> a1 going in direction dir (+1 ccw in angle, -1 cw)
	const fan = (c, cx, cy, a0, a1, dir) => {
		let d = (a1 - a0) * dir; while (d < 0) { d += 2 * Math.PI; } while (d >= 2 * Math.PI) { d -= 2 * Math.PI; }
		const st = 2 * Math.PI / N; let i0 = dir > 0 ? Math.floor(a0 / st) + 1 : Math.ceil(a0 / st) - 1;
		for (let k = 0; k < N + 1; k++) {
			const th = (i0 + dir * k) * st; let e = (th - a0) * dir; while (e < 0) { e += 2 * Math.PI; } while (e >= 2 * Math.PI) { e -= 2 * Math.PI; }
			if (e <= 1e-12) { continue; } if (e >= d - 1e-12) { break; }
			add(c, fx8(cx + hw * Math.cos(th)), fx8(cy + hw * Math.sin(th)));
		}
	};
	if (n === 1) {
		if (!p.round) { return polys; }
		const c = []; for (let i = 0; i < N; i++) { const th = 2 * Math.PI * i / N; c.push(fx8(q[0] + hw * Math.cos(th)), fx8(q[1] + hw * Math.sin(th))); } polys.push(c); return polys;
	}
	const nseg = p.closed ? n : n - 1, U = [];
	for (let k = 0; k < nseg; k++) { const k2 = (k + 1) % n, dx = q[2 * k2] - q[2 * k], dy = q[2 * k2 + 1] - q[2 * k + 1], L = Math.hypot(dx, dy); U.push([dx / L, dy / L]); }
	const off = k => [fx8(-U[k][1] * hw), fx8(U[k][0] * hw)];      // left offset of segment k (fixed point, as cairo)
	const Lc = [], Rc = [];
	let o0 = off(0); add(Lc, q[0] + o0[0], q[1] + o0[1]); add(Rc, q[0] - o0[0], q[1] - o0[1]);
	const joinAt = (k, kn) => {                             // vertex at the end of segment k, next segment kn
		const vx = q[2 * ((k + 1) % n)], vy = q[2 * ((k + 1) % n) + 1], a = U[k], b = U[kn], oa = off(k), ob = off(kn);
		const cr = a[0] * b[1] - a[1] * b[0], dt = a[0] * b[0] + a[1] * b[1];
		if (cr === 0 && dt > 0) { return; }
		if (Math.abs(oa[0] - ob[0]) < CTOL && Math.abs(oa[1] - ob[1]) < CTOL && (oa[0] - ob[0]) ** 2 + (oa[1] - ob[1]) ** 2 < CTOL * CTOL) { return; }
		// cr > 0: the turn bends toward the left offset (+off), so the outer side is the right contour
		const outer = cr > 0 ? Rc : Lc, inner = cr > 0 ? Lc : Rc, sg = cr > 0 ? -1 : 1;
		add(inner, vx, vy); add(inner, vx - sg * ob[0], vy - sg * ob[1]);
		const pa = [vx + sg * oa[0], vy + sg * oa[1]], pb = [vx + sg * ob[0], vy + sg * ob[1]];
		if (p.miter) {                                          // V9 miter join (cairo): the miter point within the limit, else a bevel
			if (2 <= p.miter * p.miter * (1 + dt)) {
				const den = a[0] * b[1] - a[1] * b[0];
				if (Math.abs(den) > 1e-12) { const t = ((pb[0] - pa[0]) * b[1] - (pb[1] - pa[1]) * b[0]) / den; add(outer, fx8(pa[0] + a[0] * t), fx8(pa[1] + a[1] * t)); }
			}
		}
		else if (dt < cusp) { fan(outer, vx, vy, Math.atan2(sg * oa[1], sg * oa[0]), Math.atan2(sg * ob[1], sg * ob[0]), cr > 0 ? 1 : -1); }   // the normals turn with the path
		else if (2 <= MITER * MITER * (1 + dt)) {               // miter point: intersection of the two outer offset lines
			const den = a[0] * b[1] - a[1] * b[0];
			if (Math.abs(den) > 1e-12) { const t = ((pb[0] - pa[0]) * b[1] - (pb[1] - pa[1]) * b[0]) / den; add(outer, fx8(pa[0] + a[0] * t), fx8(pa[1] + a[1] * t)); }
		}
		add(outer, pb[0], pb[1]);
	};
	for (let k = 0; k < nseg; k++) {
		const v = (k + 1) % n, ok = off(k);
		add(Lc, q[2 * v] + ok[0], q[2 * v + 1] + ok[1]); add(Rc, q[2 * v] - ok[0], q[2 * v + 1] - ok[1]);
		if (k < nseg - 1 || p.closed) { joinAt(k, (k + 1) % nseg); }
	}
	if (p.closed) { polys.push(Lc); const r = []; for (let i = Rc.length - 2; i >= 0; i -= 2) { r.push(Rc[i], Rc[i + 1]); } polys.push(r); return polys; }
	const c = Lc.slice();
	const capFan = (cx, cy, from, dir) => fan(c, cx, cy, from, from + Math.PI * dir, dir);
	const ex = q[2 * n - 2], ey = q[2 * n - 1], oe = off(nseg - 1);
	if (p.round) { capFan(ex, ey, Math.atan2(oe[1], oe[0]), -1); }          // left end -> around the front -> right end
	for (let i = Rc.length - 2; i >= 0; i -= 2) { add(c, Rc[i], Rc[i + 1]); }
	if (p.round) { capFan(q[0], q[1], Math.atan2(-o0[1], -o0[0]), -1); }    // right start -> around the back -> left start
	polys.push(c);
	return polys;
}
// nonzero coverage of polygons into cov (max-accumulated, box origin ox, oy, width cw) within X0..X1, Y0..Y1:
// GY sub-rows per pixel row sampled at their centres, exact x coverage of each nonzero span
let EB = null, AB = null, XS = null, DS = null, ACC = null, DIF = null, SPAN = null;   // SPAN: per row of the last fill, its [lo, hi] (x - X0)
function grow(n, w) {
	if (!EB || EB.x0.length < n) { const m = Math.max(n, 2 * (EB ? EB.x0.length : 256)); EB = { x0: new Float64Array(m), y0: new Float64Array(m), y1: new Float64Array(m), m: new Float64Array(m), d: new Int8Array(m), ord: new Int32Array(m), sx0: new Float64Array(m), sy0: new Float64Array(m), sy1: new Float64Array(m), sm: new Float64Array(m), sd: new Int8Array(m), tmp: new Int32Array(m) }; AB = new Int32Array(m); XS = new Float64Array(m); DS = new Int8Array(m); }
	if (!ACC || ACC.length < w + 2) { ACC = new Float64Array(w + 2); DIF = new Float64Array(w + 2); }
}
// stable sort of the index list a by key[a[i]] (bottom-up merge, runs of 16 by insertion) -- the same order as
// a.sort((p, q) => key[p] - key[q]) (V8's typed-array sort is a stable merge sort), without a callback per comparison
function sortByKey(a, key, tmp) {
	const n = a.length;
	for (let s = 0; s < n; s += 16) {
		const e = Math.min(n, s + 16);
		for (let i = s + 1; i < e; i++) { const v = a[i], kv = key[v]; let j = i; while (j > s && key[a[j - 1]] > kv) { a[j] = a[j - 1]; j--; } a[j] = v; }
	}
	let src = a, dst = tmp;
	for (let w = 16; w < n; w *= 2) {
		for (let lo = 0; lo < n; lo += 2 * w) {
			const mid = Math.min(n, lo + w), hi = Math.min(n, lo + 2 * w); let i = lo, j = mid, o = lo;
			if (mid >= hi || key[src[mid - 1]] <= key[src[mid]]) { while (i < hi) { dst[o++] = src[i++]; } continue; }
			while (i < mid && j < hi) { dst[o++] = key[src[j]] < key[src[i]] ? src[j++] : src[i++]; }
			while (i < mid) { dst[o++] = src[i++]; } while (j < hi) { dst[o++] = src[j++]; }
		}
		const t = src; src = dst; dst = t;
	}
	if (src !== a) { a.set(src.subarray(0, n)); }
}
function fillNonzero(polys, cov, ox, oy, cw, X0, Y0, X1, Y1) {
	let ne = 0; polys.forEach(P => { ne += P.length >> 1; });
	const W = X1 - X0; grow(ne, W);
	const ex0 = EB.x0, ey0 = EB.y0, ey1 = EB.y1, em = EB.m, ed = EB.d;
	let n = 0, ymin = Infinity, ymax = -Infinity;
	for (const P of polys) {
		const m = P.length >> 1;
		for (let i = 0; i < m; i++) {
			const j = i + 1 === m ? 0 : i + 1; let x0 = P[2 * i], y0 = P[2 * i + 1], x1 = P[2 * j], y1 = P[2 * j + 1], d = 1;
			if (y0 === y1) { continue; }
			if (y0 > y1) { let t = x0; x0 = x1; x1 = t; t = y0; y0 = y1; y1 = t; d = -1; }
			if (y1 <= Y0 || y0 >= Y1) { continue; }
			ex0[n] = x0; ey0[n] = y0; ey1[n] = y1; em[n] = (x1 - x0) / (y1 - y0); ed[n] = d; n++;
			if (y0 < ymin) { ymin = y0; } if (y1 > ymax) { ymax = y1; }
		}
	}
	if (!n) { return null; }
	const ord = EB.ord; for (let i = 0; i < n; i++) { ord[i] = i; }
	const os = ord.subarray(0, n); sortByKey(os, ey0, EB.tmp);
	// the edges again in that order (rank r = position in os), so the scan reads them without indirection
	const sx0 = EB.sx0, sy0 = EB.sy0, sy1 = EB.sy1, sm = EB.sm, sd = EB.sd;
	for (let r = 0; r < n; r++) { const e = os[r]; sx0[r] = ex0[e]; sy0[r] = ey0[e]; sy1[r] = ey1[e]; sm[r] = em[e]; sd[r] = ed[e]; }
	const ry0 = Math.max(Y0, Math.floor(ymin)), ry1 = Math.min(Y1, Math.ceil(ymax));
	if (!SPAN || SPAN.length < 2 * Math.max(0, ry1 - ry0)) { SPAN = new Int32Array(Math.max(2 * (ry1 - ry0), 2 * (SPAN ? SPAN.length : 512))); }
	const act = AB, xs = XS, ds = DS, acc = ACC, dif = DIF;
	let ei = 0, na = 0;
	for (let y = ry0; y < ry1; y++) {
		let lo = W, hi = -1;
		for (let k = 0; k < GY; k++) {
			const ys = y + (k + 0.5) / GY;
			// the active edges (ranks) stay in last sub-row's x order; new ones join at the end. Re-sorting by (x, rank)
			// is then near-linear and gives exactly the order of a fresh stable sort by x of the rank-ordered list
			while (ei < n && sy0[ei] <= ys) { act[na++] = ei++; }
			let w2 = 0;
			for (let a = 0; a < na; a++) {
				const r = act[a]; if (sy1[r] <= ys) { continue; }
				act[w2] = r; xs[w2++] = sx0[r] + (ys - sy0[r]) * sm[r];
			}
			na = w2;
			if (na < 3) {
				// zero or two active edges (most sub-rows of a stroke): the same order test, winding and span as the
				// general path below, without its loops
				if (na === 2) {
					let xa = xs[0], xb = xs[1];
					const ra = act[0], rb = act[1];
					if (xa > xb || (xa === xb && ra > rb)) { xs[0] = xb; xs[1] = xa; act[0] = rb; act[1] = ra; xa = xs[0]; xb = xs[1]; }
					if (sd[act[0]] + sd[act[1]] === 0) {
						const a0 = (xa > X0 ? xa : X0) - X0, b0 = (xb < X1 ? xb : X1) - X0;
						if (b0 > a0) {
							const ia = Math.floor(a0), ib = Math.floor(b0);
							if (ia < lo) { lo = ia; } if (ib > hi) { hi = ib; }
							if (ia === ib) { acc[ia] += b0 - a0; } else { acc[ia] += ia + 1 - a0; dif[ia + 1] += 1; dif[ib] -= 1; acc[ib] += b0 - ib; }
						}
					}
				}
				continue;
			}
			for (let a = 1; a < na; a++) {
				const x = xs[a], r = act[a]; let i = a;
				while (i > 0 && (xs[i - 1] > x || (xs[i - 1] === x && act[i - 1] > r))) { xs[i] = xs[i - 1]; act[i] = act[i - 1]; i--; }
				xs[i] = x; act[i] = r;
			}
			const nx = na;
			for (let a = 0; a < na; a++) { ds[a] = sd[act[a]]; }
			let w = 0, sx = 0;
			for (let i = 0; i < nx; i++) {
				const pw = w; w += ds[i];
				if (pw === 0 && w !== 0) { sx = xs[i]; }
				else if (pw !== 0 && w === 0) {
					const a0 = (sx > X0 ? sx : X0) - X0, b0 = (xs[i] < X1 ? xs[i] : X1) - X0; if (b0 <= a0) { continue; }
					const ia = Math.floor(a0), ib = Math.floor(b0);
					if (ia < lo) { lo = ia; } if (ib > hi) { hi = ib; }
					if (ia === ib) { acc[ia] += b0 - a0; } else { acc[ia] += ia + 1 - a0; dif[ia + 1] += 1; dif[ib] -= 1; acc[ib] += b0 - ib; }
				}
			}
		}
		if (hi < 0) { SPAN[2 * (y - ry0)] = 1; SPAN[2 * (y - ry0) + 1] = 0; continue; }
		let run = 0, i = (y - oy) * cw + X0 - ox + lo;
		const top = Math.min(hi, W - 1);
		SPAN[2 * (y - ry0)] = lo; SPAN[2 * (y - ry0) + 1] = top;
		for (let x = lo; x <= top; x++, i++) { run += dif[x]; const c = (acc[x] + run) / GY; if (c > cov[i]) { cov[i] = c > 1 ? 1 : c; } }
		acc.fill(0, lo, hi + 2); dif.fill(0, lo, hi + 2);
	}
	return ry1 > ry0 ? [ry0, ry1] : null;
}
module.exports = { classMapJS, parseSvg, parseD, fix2 };
