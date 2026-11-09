'use strict';
// ffseed.cjs -- seed for a FREE-FORM CORNER border: straight single-strand sides joined by corner knots whose
// curves are not on a lattice (e.g. refs/single-strand-dark-corners.png).
//
// The seed:
//   frame   centrelines of the four side strands (x of left / right, y of top / bottom), px
//   stroke  strand fill width, ink width, white halo outside the ink (px)
//   corner  the TL corner knot as a centreline from S (on the left side line, below the knot) to T (on the top
//           line, right of it), as control points relative to the frame corner (xL, yT), spaced ~4 px (a
//           Catmull-Rom spline passes through them); the over / under order of its crossing visits along the
//           path ('O' / 'U'); `transpose` = how far the path matches its own transpose-reverse (the diagonal
//           symmetry of this style)
//   symmetry how the other corners follow from TL: quarter-turn rotation or reflection, chosen by which carries the
//           reference's TL class map onto its other three corners better
//   dark    every hole the corner knot encloses is filled black (the 'darkened corners')
const IM = require('./image.cjs'), FF = require('./freeform.cjs');
const { CLS } = IM;

function sideLines(cm) {
	const W = cm.w, H = cm.h, m = Math.round(Math.min(W, H) * 0.2);
	const meanX = (x0, x1) => { let s = 0, n = 0; for (let y = Math.round(H * 0.3); y < H * 0.7; y++) { for (let x = x0; x < x1; x++) { if (cm.c[y * W + x] === CLS.FILL) { s += x; n++; } } } return s / n; };
	const meanY = (y0, y1) => { let s = 0, n = 0; for (let y = y0; y < y1; y++) { for (let x = Math.round(W * 0.3); x < W * 0.7; x++) { if (cm.c[y * W + x] === CLS.FILL) { s += y; n++; } } } return s / n; };
	return { xL: meanX(0, m), xR: meanX(W - m, W), yT: meanY(0, m), yB: meanY(H - m, H) };
}

// widths across the left side strand: fill run, ink runs, white halo outside the outer ink
function strokes(img, cm, xL) {
	const W = cm.w, H = cm.h, fw = [], iw = [], hw = [];
	for (let y = Math.round(H * 0.3); y < H * 0.7; y++) {
		// the fill run across the strand: first and last fill pixel within +-8 px of the centreline
		let a = -1, b = -1; for (let x = Math.max(0, Math.round(xL) - 8); x <= Math.round(xL) + 8; x++) { if (cm.c[y * W + x] === CLS.FILL) { if (a < 0) { a = x; } b = x; } }
		if (a < 0) { continue; }
		fw.push(b - a + 1);
		let i1 = a - 1, n1 = 0; while (i1 >= 0 && cm.c[y * W + i1] === CLS.INK) { n1++; i1--; }
		let i2 = b + 1, n2 = 0; while (i2 < W && cm.c[y * W + i2] === CLS.INK) { n2++; i2++; }
		iw.push(n1, n2);
		let h = 0; for (let x = i1; x >= 0 && img.lum[y * W + x] >= 250; x--) { h++; }
		if (h < 5) { hw.push(h); }
	}
	// anti-aliased edges: the class runs are integer; the geometric widths are about half a pixel more each side
	return { strand: IM.median(fw), ink: IM.median(iw), halo: IM.median(hw) };
}

function analyse(file) {
	const img = IM.load(file), cm = IM.classify(img, { bandLo: 0.6, bandHi: 1.45 });
	return { img, cm };
}

function extract(A, opt) {
	opt = opt || {};
	const { img, cm } = A, L0 = sideLines(cm), st = strokes(img, cm, L0.xL);
	// pixel index -> SVG coordinate: pixel centres sit at index + 0.5
	const L = { xL: L0.xL + 0.5, xR: L0.xR + 0.5, yT: L0.yT + 0.5, yB: L0.yB + 0.5 };
	const lead = opt.lead || 120;
	const tr = FF.trace(cm, [L0.xL, L0.yT + lead + 15], [0, -1], p => p[0] > L0.xL + lead && Math.abs(p[1] - L0.yT) < 4);
	if (tr.stopped) { throw new Error('corner trace failed: ' + tr.stopped); }
	const sm = FF.smooth(tr.pts, 1.5);
	// arc length of each raw point (smoothing keeps the count), for placing the jumps
	const arc = [0]; for (let i = 1; i < sm.length; i++) { arc.push(arc[i - 1] + Math.hypot(sm[i][0] - sm[i - 1][0], sm[i][1] - sm[i - 1][1])); }
	const fine = FF.resample(sm, 1), X = FF.selfCross(fine);
	const jumpArc = tr.jumps.map(j => arc[j.at]);
	const visits = [];
	X.forEach((c, k) => {
		const ai = c.i + c.ti, aj = c.j + c.tj;
		const di = Math.min(...jumpArc.map(a => Math.abs(a - ai))), dj = Math.min(...jumpArc.map(a => Math.abs(a - aj)));
		const underI = di < dj;
		visits.push({ arc: ai, k, u: underI }, { arc: aj, k, u: !underI });
	});
	visits.sort((a, b) => a.arc - b.arc);
	const order = visits.map(v => v.u ? 'U' : 'O').join('');
	let alt = true; for (let i = 1; i < order.length; i++) { if (order[i] === order[i - 1]) { alt = false; } }
	// control points, relative to the frame corner; the ends are snapped onto the side lines
	const cp = FF.resample(fine, opt.spacing || 4).map(p => [p[0] - L0.xL, p[1] - L0.yT]);
	cp[0][0] = 0; cp[cp.length - 1][1] = 0;
	// diagonal symmetry: the transpose of the reversed path against the path
	const tp = cp.slice().reverse().map(p => [p[1], p[0]]);
	let dev = 0; const n = Math.min(cp.length, tp.length); for (let i = 0; i < n; i++) { dev += Math.hypot(cp[i][0] - tp[i][0], cp[i][1] - tp[i][1]); }
	const r3 = v => +v.toFixed(3);
	// fill run across each straight side (pixels of fill within +-9 px of its centreline), over the middle of the run
	const sideRuns = { left: [], right: [], top: [], bottom: [] };
	for (let t = Math.round(cm.h * 0.3); t < cm.h * 0.7; t++) { for (const [k, c] of [['left', L0.xL], ['right', L0.xR]]) { let n = 0; for (let d = -9; d <= 9; d++) { if (cm.c[t * cm.w + Math.round(c) + d] === CLS.FILL) { n++; } } sideRuns[k].push(n); } }
	for (let t = Math.round(cm.w * 0.3); t < cm.w * 0.7; t++) { for (const [k, c] of [['top', L0.yT], ['bottom', L0.yB]]) { let n = 0; for (let d = -9; d <= 9; d++) { if (cm.c[(Math.round(c) + d) * cm.w + t] === CLS.FILL) { n++; } } sideRuns[k].push(n); } }
	const sideMed = Object.fromEntries(Object.entries(sideRuns).map(([k, v]) => [k, IM.median(v)]));
	// which symmetry places the other corners: agreement of the reference's TR / BL / BR boxes with its TL box carried
	// there by a quarter-turn rotation vs by reflections
	const ext = Math.max(...cp.filter(p => p[0] > 3 && p[1] > 3).map(p => Math.max(p[0], p[1]))) + 10;
	const symTest = kind => {
		const tf = { rotate: [(u, v) => [L0.xR - v, L0.yT + u], (u, v) => [L0.xR - u, L0.yB - v], (u, v) => [L0.xL + v, L0.yB - u]], mirror: [(u, v) => [L0.xR - u, L0.yT + v], (u, v) => [L0.xR - u, L0.yB - v], (u, v) => [L0.xL + u, L0.yB - v]] }[kind];
		let agree = 0, n = 0;
		for (let v = -12; v <= ext; v++) { for (let u = -12; u <= ext; u++) {
			const a = cm.c[Math.round(L0.yT + v) * cm.w + Math.round(L0.xL + u)]; if (a === undefined) { continue; }
			tf.forEach(T => { const [x, y] = T(u, v), X = Math.round(x), Y = Math.round(y); if (X < 0 || Y < 0 || X >= cm.w || Y >= cm.h) { return; } const b = cm.c[Y * cm.w + X]; if (a || b) { n++; if (a === b) { agree++; } } });
		} }
		return agree / n;
	};
	const symRot = symTest('rotate'), symMir = symTest('mirror');
	return {
		version: 1, kind: 'freeform-corner', source: opt.source || null,
		image: { w: cm.w, h: cm.h },
		frame: { xL: r3(L.xL), xR: r3(L.xR), yT: r3(L.yT), yB: r3(L.yB), centre: [r3((L.xL + L.xR) / 2), r3((L.yT + L.yB) / 2)] },
		// curved knot strands read ~6 px of fill (image.cjs ridge 2 x halfW); the straight sides read st.strand
		stroke: { strandPx: 2 * cm.halfW, sideFillMedians: sideMed, inkPx: 1.75, haloPx: st.halo, sideStrandPx: IM.median(Object.values(sideRuns).flat()), sideInkPx: 1.75, sideInkRunPx: st.ink },
		corner: { points: cp.map(p => [r3(p[0]), r3(p[1])]), spacing: opt.spacing || 4, crossings: X.length, order, alternates: alt, underPasses: tr.jumps.length, transposeMeanDevPx: r3(dev / n) },
		symmetry: { kind: symRot >= symMir ? 'rotate' : 'mirror', agreeRotate: r3(symRot), agreeMirror: r3(symMir), note: 'rotate: TR / BR / BL = TL turned 90 / 180 / 270 degrees clockwise; mirror: reflected' },
		dark: { rule: 'every region enclosed by the corner knot is black' },
		strands: 'single closed strand: TL corner, top, TR, right, BR, bottom, BL, left',
	};
}

module.exports = { analyse, extract, sideLines, strokes };

if (require.main === module) {
	const fs = require('fs');
	const [file, out] = process.argv.slice(2);
	const seed = extract(analyse(file), { source: require('path').relative(process.cwd(), file) });
	if (out) { fs.writeFileSync(out, JSON.stringify(seed, null, '\t') + '\n'); }
	const brief = Object.assign({}, seed, { corner: Object.assign({}, seed.corner, { points: seed.corner.points.length + ' points' }) });
	console.log(JSON.stringify(brief, null, 1));
}
