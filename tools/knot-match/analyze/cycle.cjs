'use strict';
// cycle.cjs -- procedural generation cycles: generate, score, adjust, until every region reaches the target on
// metric v2 (phase mean AND nominal) with all gates passing, or two consecutive cycles gain < minGain.
//
// One cycle = one coordinate-descent sweep over the continuous parameters (s, origin x/y, strand width, ink width,
// barrier arc u / k, tight-turn u / k, patch extension). Each coordinate tries +-step; a move is kept when the
// objective (the minimum over regions of the 4-phase mean score, ties broken by the regions' average) rises. Steps
// halve when a sweep keeps nothing. Every candidate must pass the gates (closed loops, valid site map,
// alternation) -- the continuous parameters cannot break them, but they are checked anyway.
//
// usage: node --no-maglev cycle.cjs <ref.png> <seed.json> <outdir> [maxCycles]
const fs = require('fs'), path = require('path');
const G = require('./gen.cjs'), SC = require('./score.cjs');

const TARGET = 0.85, MIN_GAIN = 0.01;
const KEYS = [
	// [name, get, set, step0, lo, hi]
	['s', P => P.s, (P, v) => { P.s = v; }, 0.05, 20, 32],
	['ox', P => P.origin[0], (P, v) => { P.origin[0] = v; }, 0.25, -1e9, 1e9],
	['oy', P => P.origin[1], (P, v) => { P.origin[1] = v; }, 0.25, -1e9, 1e9],
	['w', P => P.w, (P, v) => { P.w = v; }, 0.25, 6, 22],
	['ink', P => P.ink, (P, v) => { P.ink = v; }, 0.2, 1, 8],
	['u', P => P.u, (P, v) => { P.u = v; }, 0.03, 0.2, 0.65],
	['k', P => P.k, (P, v) => { P.k = v; }, 0.03, 0.05, 1.2],
	['tightU', P => P.tightU, (P, v) => { P.tightU = v; }, 0.03, 0.1, 0.65],
	['tightK', P => P.tightK, (P, v) => { P.tightK = v; }, 0.04, 0.05, 2.0],
];
const objective = r => r.minMean + 0.25 * r.avgMean;

async function run(refFile, seedFile, outDir, maxCycles, init) {
	fs.mkdirSync(outDir, { recursive: true });
	const seed = JSON.parse(fs.readFileSync(seedFile, 'utf8'));
	const ctx = SC.makeRefCtx(refFile, seed), ceil = SC.ceiling(ctx);
	let P = init || G.paramsFromSeed(seed);
	const steps = Object.fromEntries(KEYS.map(k => [k[0], k[3]]));
	const log = { ref: refFile, seed: seedFile, target: TARGET, ceiling: Object.fromEntries(Object.entries(ceil).map(([k, v]) => [k, +v.score.toFixed(4)])), cycles: [] };
	const evalP = async Q => { const r = await SC.scoreParams(ctx, seed, Q); r.obj = objective(r); return r; };
	let cur = await evalP(P), evals = 1;
	const fx = o => Object.fromEntries(Object.entries(o).map(([k, v]) => [k, +v.toFixed(4)]));
	const record = (c, note) => {
		const e = { cycle: c, nominal: fx(cur.nominal), mean: fx(cur.mean), minNominal: +cur.minNominal.toFixed(4), minMean: +cur.minMean.toFixed(4), avgMean: +cur.avgMean.toFixed(4), gates: { sitesValid: cur.gates.sitesValid, closed: cur.gates.closed, alternates: cur.gates.alternates }, loops: cur.loops, params: JSON.parse(JSON.stringify(P)), evals, note };
		log.cycles.push(e); console.log(JSON.stringify({ cycle: c, minMean: e.minMean, minNominal: e.minNominal, mean: e.mean, nominal: e.nominal, evals, note }));
		fs.writeFileSync(path.join(outDir, 'cycles.json'), JSON.stringify(log, null, '\t') + '\n');
		fs.writeFileSync(path.join(outDir, 'best-params.json'), JSON.stringify(P, null, '\t') + '\n');
		fs.writeFileSync(path.join(outDir, 'best.svg'), cur.svg);
	};
	record(0, 'seed');
	const gatesOK = r => r.gates.sitesValid && r.gates.closed && r.gates.alternates;
	const done = () => !process.env.POLISH && cur.minMean >= TARGET && cur.minNominal >= TARGET && gatesOK(cur);
	let stall = 0;
	for (let c = 1; c <= maxCycles && !done(); c++) {
		const before = cur.minMean;
		let kept = 0;
		for (const [name, get, set, , lo, hi] of KEYS) {
			for (const sg of [1, -1]) {
				let improved = true;
				while (improved) {
					improved = false;
					const Q = JSON.parse(JSON.stringify(P)), v = get(Q) + sg * steps[name];
					if (v < lo || v > hi) { break; }
					set(Q, v);
					const r = await evalP(Q); evals++;
					if (gatesOK(r) && r.obj > cur.obj + 1e-5) { P = Q; cur = r; improved = true; kept++; }
				}
			}
		}
		if (!kept) { for (const k in steps) { steps[k] /= 2; } }
		const gain = cur.minMean - before;
		record(c, kept ? 'kept ' + kept + ' moves' : 'no move; steps halved');
		if (gain < MIN_GAIN) { stall++; } else { stall = 0; }
		if (stall >= 2) { console.log('stall: two consecutive cycles gained < ' + MIN_GAIN); log.stalled = true; break; }
	}
	// full gates on the final design (ink in band, loops per period vs the reference, fallback, fairness)
	const GT = require('./gates.cjs'), SDm = require('./seed.cjs');
	const A = SDm.analyse(refFile); SDm.extract(A);
	const b = G.build(seed, P, { AW: seed.frame.H, AH: seed.frame.H, W: ctx.ref.w, H: ctx.ref.h }); b.P = P;
	log.gates = GT.allGates(seed, b, ctx.ref.c, cur.map0.c, ctx.ref.w, ctx.ref.h, GT.refSideLoops(A, seed));
	log.met = cur.minMean >= TARGET && cur.minNominal >= TARGET && log.gates.all;
	console.log('gates', JSON.stringify({ all: log.gates.all, inkOutsideFrac: log.gates.inkOutsideFrac, loopsPerPeriod: log.gates.loopsPerPeriod, wiggly: log.gates.wigglyCurves }));
	fs.writeFileSync(path.join(outDir, 'cycles.json'), JSON.stringify(log, null, '\t') + '\n');
	return { P, cur, log };
}

module.exports = { run, KEYS, objective };

if (require.main === module) {
	const [ref, seedFile, outDir, maxC, initFile] = process.argv.slice(2);
	run(ref, seedFile, outDir, +(maxC || 30), initFile ? JSON.parse(fs.readFileSync(initFile, 'utf8')) : null).then(r => { console.log('met', r.log.met, 'stalled', !!r.log.stalled, 'minMean', r.cur.minMean.toFixed(4), 'minNominal', r.cur.minNominal.toFixed(4)); });
}
