'use strict';
// ffcycle.cjs -- scoring and generation cycles for free-form-corner borders (ffseed.cjs / ffgen.cjs).
//
// Regions: the four corner knots and the four straight sides between them. `band` (metric v2's alignment span and
// chamfer scale) is the corner knot's extent, the width of the decorated border. Scores: nominal and the mean
// over four half-pixel phases of our art. Ceiling: the reference against itself under the seed's corner symmetry
// (each corner vs the other three carried onto it; each side vs the opposite side turned 180 degrees).
//
// A cycle = one sweep of coordinate descent: the straight runs' stroke (wS, inkS) and per-side sub-pixel offsets
// (+-0.6 px; the frame lines themselves stay at their measured positions), the curved stroke (w, ink), then every
// corner control point moved 0.25 px along the curve's normal with a smooth bump (+-1 / +-2 neighbours follow at
// 0.6 / 0.2). Scored without the white halo (see evaluate). Every accepted move must keep our ink inside the
// reference band (<= 0.5% outside).
// Objective: the minimum region phase-mean + 0.25 x the average. A move is kept only if the gates still pass
// (topology: same crossings with the seed's alternating over / under; fairness: no more curvature sign changes
// than the traced reference). Stop at target on every region (nominal and phase mean) with all gates, or after
// two consecutive cycles gaining < 0.01.
//
// usage: node --no-maglev ffcycle.cjs <ref.png> <seed.json> <outdir> [maxCycles] [init.json]
const fs = require('fs'), path = require('path');
const KM = require('../knotmatch.cjs'), IM = require('./image.cjs'), SC = require('./score.cjs'), FG = require('./ffgen.cjs');

const TARGET = 0.85, MIN_GAIN = 0.01, PHASES = [[0, 0], [0.5, 0], [0, 0.5], [0.5, 0.5]];

function knotExtent(P) { let x = 0, y = 0; P.pts.forEach(p => { if (p[0] > 3 && p[1] > 3) { x = Math.max(x, p[0]); y = Math.max(y, p[1]); } }); return [x, y]; }

function regions(seed, ref) {
	const F = seed.frame, [ex, ey] = knotExtent(FG.paramsFromSeed(seed)), m = 10, e = Math.max(ex, ey) + m;
	const cl = r => ({ name: r.name, x0: Math.max(2, Math.round(r.x0)), x1: Math.min(ref.w - 2, Math.round(r.x1)), y0: Math.max(2, Math.round(r.y0)), y1: Math.min(ref.h - 2, Math.round(r.y1)) });
	return [
		{ name: 'TL', x0: F.xL - 20, x1: F.xL + e, y0: F.yT - 20, y1: F.yT + e },
		{ name: 'TR', x0: F.xR - e, x1: F.xR + 20, y0: F.yT - 20, y1: F.yT + e },
		{ name: 'BL', x0: F.xL - 20, x1: F.xL + e, y0: F.yB - e, y1: F.yB + 20 },
		{ name: 'BR', x0: F.xR - e, x1: F.xR + 20, y0: F.yB - e, y1: F.yB + 20 },
		{ name: 'left', x0: F.xL - 14, x1: F.xL + 14, y0: F.yT + e, y1: F.yB - e },
		{ name: 'right', x0: F.xR - 14, x1: F.xR + 14, y0: F.yT + e, y1: F.yB - e },
		{ name: 'top', x0: F.xL + e, x1: F.xR - e, y0: F.yT - 14, y1: F.yT + 14 },
		{ name: 'bottom', x0: F.xL + e, x1: F.xR - e, y0: F.yB - 14, y1: F.yB + 14 },
	].map(cl);
}

function makeCtx(refFile, seed) {
	const img = IM.load(refFile), cm = IM.classify(img, { bandLo: 0.6, bandHi: 1.45 }), ref = { w: cm.w, h: cm.h, c: cm.c };
	const R = regions(seed, ref), [ex, ey] = knotExtent(FG.paramsFromSeed(seed)), band = Math.round(Math.max(ex, ey) + 10);
	const dtRef = { cm: ref, dts: {} }; R.forEach(r => KM.refDTFor(dtRef, r));
	return { ref, R, band, dtRef, seed };
}

function scoreMap(ctx, ours) {
	const out = {}; ctx.R.forEach(r => { const g = KM.regionScore(ctx.ref, ours, r, ctx.band, KM.refDTFor(ctx.dtRef, r)); out[r.name] = g.score; }); return out;
}

async function evaluate(ctx, P, opt) {
	opt = opt || {};
	const seed = ctx.seed, W = ctx.ref.w, H = ctx.ref.h;
	// scored WITHOUT the white halo: it is ground in both maps, and its anti-aliased edge against the ink reads as a
	// fake fill / colour pixel outside every outline (outside review); the display SVG keeps it
	const b0 = FG.build(seed, P, { noHalo: true });
	if (!b0.gates.topology) { return { bad: 'topology', gates: b0.gates }; }
	const phases = opt.nominalOnly ? [PHASES[0]] : PHASES;
	const maps = await Promise.all(phases.map(sh => SC.classOf(sh[0] || sh[1] ? FG.build(seed, P, { shift: sh, noHalo: true }).svg : b0.svg, W, H)));
	const per = maps.map(m => scoreMap(ctx, m)), names = ctx.R.map(r => r.name);
	const res = { nominal: {}, mean: {}, gates: b0.gates, svg: FG.build(seed, P, {}).svg, map0: maps[0] };
	const GT = require('./gates.cjs'); res.inkOut = GT.inkInBand(ctx.ref.c, maps[0].c, W, H).frac;
	names.forEach(n => { res.nominal[n] = per[0][n]; res.mean[n] = per.reduce((a, p) => a + p[n], 0) / per.length; });
	res.minNominal = Math.min(...names.map(n => res.nominal[n])); res.minMean = Math.min(...names.map(n => res.mean[n]));
	res.avgMean = names.reduce((a, n) => a + res.mean[n], 0) / names.length; res.obj = res.minMean + 0.25 * res.avgMean;
	return res;
}

function ceiling(ctx) {
	const { ref, seed } = ctx, F = seed.frame, W = ref.w, H = ref.h, rot = seed.symmetry.kind !== 'mirror';
	// corner frames: page point <-> TL-relative (u, v)
	const T = rot ? { TL: (u, v) => [F.xL + u, F.yT + v], TR: (u, v) => [F.xR - v, F.yT + u], BR: (u, v) => [F.xR - u, F.yB - v], BL: (u, v) => [F.xL + v, F.yB - u] }
		: { TL: (u, v) => [F.xL + u, F.yT + v], TR: (u, v) => [F.xR - u, F.yT + v], BR: (u, v) => [F.xR - u, F.yB - v], BL: (u, v) => [F.xL + u, F.yB - v] };
	const Ti = rot ? { TL: (x, y) => [x - F.xL, y - F.yT], TR: (x, y) => [y - F.yT, F.xR - x], BR: (x, y) => [F.xR - x, F.yB - y], BL: (x, y) => [F.yB - y, x - F.xL] }
		: { TL: (x, y) => [x - F.xL, y - F.yT], TR: (x, y) => [F.xR - x, y - F.yT], BR: (x, y) => [F.xR - x, F.yB - y], BL: (x, y) => [x - F.xL, F.yB - y] };
	const mk = fn => { const c = new Uint8Array(W * H); for (let y = 0; y < H; y++) { for (let x = 0; x < W; x++) { const [X0, Y0] = fn(x, y), X = Math.round(X0), Y = Math.round(Y0); c[y * W + x] = X >= 0 && Y >= 0 && X < W && Y < H ? ref.c[Y * W + X] : 0; } } return { w: W, h: H, c }; };
	const half = mk((x, y) => [F.xL + F.xR - x, F.yT + F.yB - y]);     // 180 degrees: sides against the opposite side
	const out = {};
	ctx.R.forEach(r => {
		let cands;
		if (T[r.name]) { cands = Object.keys(T).filter(k => k !== r.name).map(k => mk((x, y) => { const [u, v] = Ti[r.name](x, y); return T[k](u, v); })); }
		else { cands = [half]; }
		out[r.name] = Math.max(...cands.map(m => KM.regionScore(ref, m, r, ctx.band, KM.refDTFor(ctx.dtRef, r)).score));
	});
	return out;
}

// curvature sign changes along the TL curve (fairness)
function signChanges(pts) {
	const poly = FG.sampleBez(FG.bez(pts), 6); let last = 0, n = 0;
	for (let i = 6; i < poly.length - 6; i += 3) {
		const a = poly[i - 6], b = poly[i], c = poly[i + 6], cr = (b[0] - a[0]) * (c[1] - b[1]) - (b[1] - a[1]) * (c[0] - b[0]);
		const sg = Math.abs(cr) < 0.4 ? 0 : Math.sign(cr); if (sg && last && sg !== last) { n++; } if (sg) { last = sg; }
	}
	return n;
}

function normals(pts) { return pts.map((p, i) => { const a = pts[Math.max(0, i - 1)], b = pts[Math.min(pts.length - 1, i + 1)], t = [b[0] - a[0], b[1] - a[1]], L = Math.hypot(t[0], t[1]) || 1; return [-t[1] / L, t[0] / L]; }); }

async function run(refFile, seedFile, outDir, maxCycles, init) {
	fs.mkdirSync(outDir, { recursive: true });
	const seed = JSON.parse(fs.readFileSync(seedFile, 'utf8')), ctx = makeCtx(refFile, seed), ceil = ceiling(ctx);
	let P = init || FG.paramsFromSeed(seed);
	const fairRef = signChanges(seed.corner.points);
	const fx = o => Object.fromEntries(Object.entries(o).map(([k, v]) => [k, +v.toFixed(4)]));
	const log = { ref: refFile, seed: seedFile, target: TARGET, band: ctx.band, ceiling: fx(ceil), fairnessRef: fairRef, cycles: [] };
	let cur = await evaluate(ctx, P), evals = 1;
	const ok = r => !r.bad && r.gates.topology && r.inkOut <= 0.005 && signChanges(r.P ? r.P.pts : P.pts) <= fairRef;
	const record = (c, note) => {
		const e = { cycle: c, nominal: fx(cur.nominal), mean: fx(cur.mean), minNominal: +cur.minNominal.toFixed(4), minMean: +cur.minMean.toFixed(4), avgMean: +cur.avgMean.toFixed(4), evals, note, stroke: { w: +P.w.toFixed(3), ink: +P.ink.toFixed(3), wS: +P.wS.toFixed(3), inkS: +P.inkS.toFixed(3) }, sideOffsets: { L: P.offL, R: P.offR, T: P.offT, B: P.offB }, inkOutside: +cur.inkOut.toFixed(5) };
		log.cycles.push(e); console.log(JSON.stringify({ cycle: c, minMean: e.minMean, minNominal: e.minNominal, mean: e.mean, evals, note }));
		fs.writeFileSync(path.join(outDir, 'cycles.json'), JSON.stringify(log, null, '\t') + '\n');
		fs.writeFileSync(path.join(outDir, 'best-params.json'), JSON.stringify(P) + '\n');
		fs.writeFileSync(path.join(outDir, 'best.svg'), cur.svg);
	};
	record(0, 'seed');
	const tryP = async Q => { const r = await evaluate(ctx, Q); evals++; r.P = Q; if (ok(r) && r.obj > cur.obj + 1e-5) { P = Q; cur = r; return true; } return false; };
	const met = () => cur.minMean >= TARGET && cur.minNominal >= TARGET;
	// frame lines stay at their measured positions; the straight runs move only by their own sub-pixel offsets
	let stall = 0, step = { w: 0.25, ink: 0.125, off: 0.125, pt: 0.25 };
	const LIM = { w: [3, 10], ink: [0.75, 3], wS: [4, 10], inkS: [0.75, 3], offL: [-0.6, 0.6], offR: [-0.6, 0.6], offT: [-0.6, 0.6], offB: [-0.6, 0.6] };
	for (let c = 1; c <= maxCycles && (process.env.POLISH || !met()); c++) {
		const before = cur.minMean; let kept = 0;
		for (const [k, st] of [['wS', step.w], ['inkS', step.ink], ['offL', step.off], ['offR', step.off], ['offT', step.off], ['offB', step.off], ['w', step.w], ['ink', step.ink]]) {
			for (const sg of [1, -1]) { while (true) { const Q = JSON.parse(JSON.stringify(P)); Q[k] = (Q[k] || 0) + sg * st; if (Q[k] < LIM[k][0] || Q[k] > LIM[k][1] || !(await tryP(Q))) { break; } kept++; } }
		}
		const n = P.pts.length;
		for (let i = 2; i < n - 2; i++) {
			for (const sg of [1, -1]) {
				let moved = 0;
				while (moved < 4) {
					const N = normals(P.pts), Q = JSON.parse(JSON.stringify(P));
					[[0, 1], [1, 0.6], [-1, 0.6], [2, 0.2], [-2, 0.2]].forEach(([o, wgt]) => { const j = i + o; if (j < 2 || j > n - 3) { return; } Q.pts[j][0] += sg * step.pt * wgt * N[i][0]; Q.pts[j][1] += sg * step.pt * wgt * N[i][1]; });
					if (!(await tryP(Q))) { break; } kept++; moved++;
				}
			}
		}
		if (!kept) { for (const k in step) { step[k] /= 2; } }
		record(c, kept ? 'kept ' + kept + ' moves' : 'no move; steps halved');
		if (cur.minMean - before < MIN_GAIN) { stall++; } else { stall = 0; }
		if (stall >= 2) { console.log('stall: two consecutive cycles gained < ' + MIN_GAIN); log.stalled = true; break; }
	}
	log.gates = gates(ctx, P, cur, fairRef);
	log.met = met() && log.gates.all;
	fs.writeFileSync(path.join(outDir, 'cycles.json'), JSON.stringify(log, null, '\t') + '\n');
	return { P, cur, log };
}

function gates(ctx, P, cur, fairRef) {
	const GT = require('./gates.cjs');
	const ib = GT.inkInBand(ctx.ref.c, cur.map0.c, ctx.ref.w, ctx.ref.h), sc = signChanges(P.pts);
	const g = { closed: cur.gates.closed, singleStrand: cur.gates.singleStrand, topology: cur.gates.topology, crossingsPerCorner: cur.gates.crossings, alternates: cur.gates.alternates,
		inkInBand: ib.frac <= 0.005, inkOutsideFrac: +ib.frac.toFixed(5), noFallback: true, fairness: sc <= fairRef, curvatureSignChanges: sc, curvatureSignChangesRef: fairRef };
	g.all = g.closed && g.singleStrand && g.topology && g.alternates && g.inkInBand && g.noFallback && g.fairness;
	return g;
}

module.exports = { run, evaluate, makeCtx, ceiling, regions, signChanges };

if (require.main === module) {
	const [ref, seedFile, outDir, maxC, initFile] = process.argv.slice(2);
	run(ref, seedFile, outDir, +(maxC || 20), initFile ? JSON.parse(fs.readFileSync(initFile, 'utf8')) : null).then(r => { console.log('gates', JSON.stringify(r.log.gates)); console.log('met', r.log.met, 'minMean', r.cur.minMean.toFixed(4), 'minNominal', r.cur.minNominal.toFixed(4)); });
}
