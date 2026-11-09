'use strict';
// image.cjs -- load a reference knotwork raster and split it into ground / ink / strand fill.
//
// The reference is line art: dark outlines around light strand fills on some background. The background may be
// flat, transparent, or a baked-in transparency checkerboard (which shares the strand fill's white), so colour
// alone cannot tell a strand interior from a background square. We classify by REGION instead:
//   1. ink = pixels darker than the ink threshold (an Otsu split between the dark mode and the light mode);
//   2. every 4-connected non-ink region is one candidate (a strand fragment between crossings, or a hole, or the
//      outside);
//   3. a region is GROUND when it touches the image edge, or when its "deep" pixels (>= 2 px from any ink) are not
//      uniformly the fill colour (checker squares, gradients, texture), or when it is too wide to be a strand
//      (its distance-transform ridge is well above the strand half-width). Everything else is STRAND FILL.
// The strand half-width itself is estimated from the regions (the mode of their distance-transform ridge), so the
// classification is two-pass: provisional (edge + colour test), then the width test with the measured width.
const fs = require('fs');
const { PNG } = require('pngjs');

const CLS = { GROUND: 0, INK: 1, FILL: 2 };

function load(file) {
	const png = PNG.sync.read(fs.readFileSync(file));
	const { width: w, height: h, data } = png, n = w * h;
	const lum = new Float32Array(n), alpha = new Uint8Array(n), rgb = new Uint8Array(n * 3);
	for (let i = 0; i < n; i++) {
		const a = data[i * 4 + 3] / 255, r = data[i * 4], g = data[i * 4 + 1], b = data[i * 4 + 2];
		// composite over white: transparent pixels read as background-light
		const R = r * a + 255 * (1 - a), G = g * a + 255 * (1 - a), B = b * a + 255 * (1 - a);
		rgb[i * 3] = R; rgb[i * 3 + 1] = G; rgb[i * 3 + 2] = B;
		lum[i] = 0.2126 * R + 0.7152 * G + 0.0722 * B; alpha[i] = data[i * 4 + 3];
	}
	return { w, h, lum, rgb, alpha };
}

function otsu(lum) {
	const hist = new Float64Array(256); for (const v of lum) { hist[Math.max(0, Math.min(255, Math.round(v)))]++; }
	const tot = lum.length; let sum = 0; for (let i = 0; i < 256; i++) { sum += i * hist[i]; }
	let sB = 0, wB = 0, best = 0, th = 128;
	for (let t = 0; t < 256; t++) {
		wB += hist[t]; if (!wB) { continue; } const wF = tot - wB; if (!wF) { break; }
		sB += t * hist[t]; const mB = sB / wB, mF = (sum - sB) / wF, v = wB * wF * (mB - mF) * (mB - mF);
		if (v > best) { best = v; th = t; }
	}
	return th;
}

// exact Euclidean distance transform (Felzenszwalb) of a binary mask: distance from each pixel to the nearest
// pixel where src is true
function edt(src, w, h) {
	const INF = 1e20, f = new Float64Array(Math.max(w, h)), d = new Float64Array(Math.max(w, h)), v = new Int32Array(Math.max(w, h)), z = new Float64Array(Math.max(w, h) + 1);
	const g = new Float64Array(w * h);
	for (let i = 0; i < w * h; i++) { g[i] = src[i] ? 0 : INF; }
	function pass(n) {
		let k = 0; v[0] = 0; z[0] = -INF; z[1] = INF;
		for (let q = 1; q < n; q++) {
			let s = ((f[q] + q * q) - (f[v[k]] + v[k] * v[k])) / (2 * q - 2 * v[k]);
			while (s <= z[k]) { k--; s = ((f[q] + q * q) - (f[v[k]] + v[k] * v[k])) / (2 * q - 2 * v[k]); }
			k++; v[k] = q; z[k] = s; z[k + 1] = INF;
		}
		k = 0; for (let q = 0; q < n; q++) { while (z[k + 1] < q) { k++; } d[q] = (q - v[k]) * (q - v[k]) + f[v[k]]; }
	}
	for (let x = 0; x < w; x++) { for (let y = 0; y < h; y++) { f[y] = g[y * w + x]; } pass(h); for (let y = 0; y < h; y++) { g[y * w + x] = d[y]; } }
	for (let y = 0; y < h; y++) { for (let x = 0; x < w; x++) { f[x] = g[y * w + x]; } pass(w); for (let x = 0; x < w; x++) { g[y * w + x] = d[x]; } }
	const out = new Float32Array(w * h); for (let i = 0; i < w * h; i++) { out[i] = Math.sqrt(g[i]); }
	return out;
}

function components(mask, w, h) {   // 4-connected labels of mask==1; returns {lab, comps:[{id, px:[i...], edge}]}
	const lab = new Int32Array(w * h).fill(-1), comps = [], stack = [];
	for (let s = 0; s < w * h; s++) {
		if (!mask[s] || lab[s] >= 0) { continue; }
		const id = comps.length, px = []; let edge = false; lab[s] = id; stack.push(s);
		while (stack.length) {
			const i = stack.pop(), x = i % w, y = (i - x) / w; px.push(i);
			if (x === 0 || y === 0 || x === w - 1 || y === h - 1) { edge = true; }
			if (x > 0 && mask[i - 1] && lab[i - 1] < 0) { lab[i - 1] = id; stack.push(i - 1); }
			if (x < w - 1 && mask[i + 1] && lab[i + 1] < 0) { lab[i + 1] = id; stack.push(i + 1); }
			if (y > 0 && mask[i - w] && lab[i - w] < 0) { lab[i - w] = id; stack.push(i - w); }
			if (y < h - 1 && mask[i + w] && lab[i + w] < 0) { lab[i + w] = id; stack.push(i + w); }
		}
		comps.push({ id, px, edge });
	}
	return { lab, comps };
}

function median(a) { if (!a.length) { return 0; } const s = Float64Array.from(a).sort(); return s[s.length >> 1]; }

// classify(img) -> { w, h, c (Uint8 classes), inkTh, halfW (strand half-width px), inkW (outline width px),
//                    fillRGB, regions:[{id, cls, area, ridge, deepVar, edge}], lab }
function classify(img, opt) {
	opt = opt || {};
	const { w, h, lum, rgb } = img, n = w * h;
	const inkTh = opt.inkTh || Math.min(170, otsu(lum));
	const ink = new Uint8Array(n); for (let i = 0; i < n; i++) { ink[i] = lum[i] < inkTh ? 1 : 0; }
	const dInk = edt(ink, w, h);
	const light = new Uint8Array(n); for (let i = 0; i < n; i++) { light[i] = ink[i] ? 0 : 1; }
	const { lab, comps } = components(light, w, h);
	// the fill colour: the most common colour among deep pixels of the regions (strand fills dominate the art)
	const votes = new Map();
	for (let i = 0; i < n; i++) { if (!ink[i] && dInk[i] >= 2) { const k = (rgb[i * 3] >> 3) << 10 | (rgb[i * 3 + 1] >> 3) << 5 | (rgb[i * 3 + 2] >> 3); votes.set(k, (votes.get(k) || 0) + 1); } }
	// candidate colours, most common first; the strand fill is the most common colour INSIDE non-edge regions
	const inner = new Map();
	comps.forEach(c => { if (c.edge) { return; } c.px.forEach(i => { if (dInk[i] >= 2) { const k = (rgb[i * 3] >> 3) << 10 | (rgb[i * 3 + 1] >> 3) << 5 | (rgb[i * 3 + 2] >> 3); inner.set(k, (inner.get(k) || 0) + 1); } }); });
	const fillKey = [...inner.entries()].sort((a, b) => b[1] - a[1])[0][0];
	const fillRGB = [((fillKey >> 10) & 31) * 8 + 4, ((fillKey >> 5) & 31) * 8 + 4, (fillKey & 31) * 8 + 4];
	const isFill = i => { const dr = rgb[i * 3] - fillRGB[0], dg = rgb[i * 3 + 1] - fillRGB[1], db = rgb[i * 3 + 2] - fillRGB[2]; return dr * dr + dg * dg + db * db < 10 * 10; };
	// ridge pixels: local maxima of the distance to ink (the medial axis, sampled). A strand fragment is a band of
	// near-constant width, so its ridge sits at ~the strand half-width all along; a hole between strands is a
	// crescent / triangle / lens whose ridge varies widely; the outside is huge.
	const isRidge = i => {
		const x = i % w, y = (i - x) / w, v = dInk[i]; if (v < 1.5 || ink[i]) { return false; }
		for (let dy = -1; dy <= 1; dy++) { for (let dx = -1; dx <= 1; dx++) { if (!dx && !dy) { continue; } const X = x + dx, Y = y + dy; if (X < 0 || Y < 0 || X >= w || Y >= h) { continue; } if (dInk[Y * w + X] > v + 1e-6) { return false; } } }
		return true;
	};
	const regions = comps.map(c => {
		let deep = 0, off = 0, ridge = 0; const rv = [];
		c.px.forEach(i => { if (dInk[i] > ridge) { ridge = dInk[i]; } if (dInk[i] >= 2) { deep++; if (!isFill(i)) { off++; } } if (isRidge(i)) { rv.push(dInk[i]); } });
		return { id: c.id, area: c.px.length, edge: c.edge, ridge, deep, offFrac: deep ? off / deep : 0, rv, px: c.px };
	});
	// strand half-width = the mode of ridge values over every interior region (strand fragments dominate them)
	const hist = new Map(); regions.forEach(r => { if (r.edge && r.area > n / 4) { return; } r.rv.forEach(v => { const b = Math.round(v * 4) / 4; hist.set(b, (hist.get(b) || 0) + 1); }); });
	let halfW = 0, hb = -1; hist.forEach((cnt, b) => { const sm = cnt + (hist.get(b - 0.25) || 0) + (hist.get(b + 0.25) || 0); if (sm > hb) { hb = sm; halfW = b; } });
	// does colour separate fill from ground at all? (transparent strands over a checker share the background)
	regions.forEach(r => { const band = r.rv.filter(v => v >= (opt.bandLo || 0.72) * halfW && v <= (opt.bandHi || 1.3) * halfW).length; r.bandFrac = r.rv.length ? band / r.rv.length : 0; });
	// colour is informative only when band-shaped interior regions are fill-coloured AND the outside is not
	const wavg = rs => { const t = rs.reduce((a, r) => [a[0] + r.offFrac * r.deep, a[1] + r.deep], [0, 0]); return t[1] ? t[0] / t[1] : null; };
	const outOff = wavg(regions.filter(r => r.edge && r.area > n / 4)), bandOff = wavg(regions.filter(r => !r.edge && r.bandFrac >= 0.8 && r.ridge <= 1.4 * halfW));
	const colourInformative = outOff != null && bandOff != null && outOff > 0.3 && bandOff < 0.1;
	regions.forEach(r => {
		const bandFrac = r.bandFrac;
		let strand = r.ridge <= 1.4 * halfW && bandFrac >= 0.6 && r.rv.length >= 0.8 * halfW && r.area >= 1.5 * halfW * halfW;
		if (colourInformative && r.offFrac > 0.08) { strand = false; }
		if (r.edge && r.area > n / 4) { strand = false; }
		r.cls = strand ? CLS.FILL : CLS.GROUND;
	});
	const c = new Uint8Array(n);
	for (let i = 0; i < n; i++) { c[i] = ink[i] ? CLS.INK : regions[lab[i]].cls; }
	// outline width: across each ink line, the ink run between fill and ground/fill -- 2x the median ink ridge
	const dLight = edt(light, w, h), inkR = []; for (let i = 0; i < n; i++) { if (ink[i]) { inkR.push(dLight[i]); } }
	const inkW = 2 * quantile(inkR, 0.9);
	return { w, h, c, inkTh, halfW, inkW, fillRGB, regions, lab, dInk };
}
function quantile(a, q) { const s = Float64Array.from(a).sort(); return s[Math.min(s.length - 1, Math.floor(q * s.length))]; }

function writeClassPng(cm, file, scale) {
	scale = scale || 1;
	const W = cm.w * scale, H = cm.h * scale, png = new PNG({ width: W, height: H });
	const col = [[238, 232, 214], [20, 20, 20], [90, 150, 230]];
	for (let y = 0; y < H; y++) { for (let x = 0; x < W; x++) { const k = cm.c[((y / scale) | 0) * cm.w + ((x / scale) | 0)], o = (y * W + x) * 4, p = col[k] || [255, 0, 255]; png.data[o] = p[0]; png.data[o + 1] = p[1]; png.data[o + 2] = p[2]; png.data[o + 3] = 255; } }
	fs.writeFileSync(file, PNG.sync.write(png));
}

module.exports = { CLS, load, classify, edt, components, otsu, writeClassPng, median, quantile };

if (require.main === module) {
	const [file, out] = process.argv.slice(2);
	const img = load(file), cm = classify(img);
	const counts = [0, 0, 0]; cm.c.forEach(k => counts[k]++);
	console.log(JSON.stringify({ w: cm.w, h: cm.h, inkTh: cm.inkTh, halfW: cm.halfW, strandW: 2 * cm.halfW, inkW: cm.inkW, fillRGB: cm.fillRGB, counts, regions: cm.regions.length, fillRegions: cm.regions.filter(r => r.cls === 2).length }));
	if (out) { writeClassPng(cm, out, 3); }
}
