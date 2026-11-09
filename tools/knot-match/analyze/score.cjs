'use strict';
// score.cjs -- metric v2 (knotmatch.cjs regionScore, unchanged) for a generated border against a reference raster.
//
// The reference is classified by shape (image.cjs: 0 ground, 1 ink, 2 strand fill). Our SVG is rasterised at the
// reference's pixel size by rsvg-convert and classified to the same classes (fill is painted in the A colour, so
// KM.classMap's palette maps it to class 2). Regions come from the seed's frame: TL and BL corners, the left side
// between them, and the visible top and bottom strips. Scores are reported at nominal phase and as the mean over the
// four half-pixel phases of our art (the winner's-curse guard: select on the phase mean, never on nominal alone).
// The ceiling is the reference against itself: TL vs BL mirrored, BL vs TL mirrored, the side / strips vs
// themselves shifted by one period.
const KM = require('../knotmatch.cjs');
const IM = require('./image.cjs');
const G = require('./gen.cjs');

const PHASES = [[0, 0], [0.5, 0], [0, 0.5], [0.5, 0.5]];

function loadRef(file) { const cm = IM.classify(IM.load(file)); return { w: cm.w, h: cm.h, c: cm.c, cm }; }

function regions(seed, ref) {
	const s = seed.grid.s, [X0, Y0] = seed.grid.originPx, C = seed.corner.size, H = seed.frame.H, wS = seed.side.width, wT = seed.top ? seed.top.width : wS;
	const m = Math.round(0.85 * s);    // margin outside the outermost site row / column: the outer arcs and ink
	const clamp = r => ({ name: r.name, x0: Math.max(2, Math.round(r.x0)), x1: Math.min(ref.w - 2, Math.round(r.x1)), y0: Math.max(2, Math.round(r.y0)), y1: Math.min(ref.h - 2, Math.round(r.y1)) });
	const cEdge = (C - 0.5) * s;
	const R = [
		{ name: 'TL', x0: X0 - m, x1: X0 + cEdge, y0: Y0 - m, y1: Y0 + cEdge },
		{ name: 'BL', x0: X0 - m, x1: X0 + cEdge, y0: Y0 + H * s - cEdge, y1: Y0 + H * s + m },
		{ name: 'left', x0: X0 - m, x1: X0 + wS * s + m, y0: Y0 + cEdge, y1: Y0 + H * s - cEdge },
		{ name: 'top', x0: X0 + cEdge, x1: ref.w, y0: Y0 - m, y1: Y0 + wT * s + m },
		{ name: 'bottom', x0: X0 + cEdge, x1: ref.w, y0: Y0 + (H - wT) * s - m, y1: Y0 + H * s + m },
	].map(clamp);
	return R;
}
function bandPx(seed) { return seed.side.width * seed.grid.s + (seed.stroke.strand + 2 * seed.stroke.ink) * seed.grid.s; }

function makeRefCtx(file, seed) {
	const ref = loadRef(file), R = regions(seed, ref), band = bandPx(seed);
	const dtRef = { cm: ref, dts: {} };
	R.forEach(r => KM.refDTFor(dtRef, r));
	return { ref, R, band, dtRef, seed };
}

async function classOf(svg, W, H) { return KM.classMap(await KM.rasterize(svg, W, H)); }

function scoreMap(ctx, ours) {
	const out = {};
	ctx.R.forEach(r => { const g = KM.regionScore(ctx.ref, ours, r, ctx.band, KM.refDTFor(ctx.dtRef, r)); out[r.name] = { score: g.score, conf: g.conf, chamferBand: g.chamferBand, dx: g.dx, dy: g.dy }; });
	return out;
}

// score a parameter set: nominal and 4-phase mean per region
async function scoreParams(ctx, seed, P, opt) {
	opt = opt || {};
	const W = ctx.ref.w, H = ctx.ref.h, AH = seed.frame.H, AW = opt.AW || AH;
	const phases = opt.nominalOnly ? [PHASES[0]] : PHASES;
	const builds = phases.map(sh => G.build(seed, P, { AW, AH, W, H, shift: sh[0] || sh[1] ? sh : null }));
	const maps = await Promise.all(builds.map(b => classOf(b.svg, W, H)));
	const per = maps.map(m => scoreMap(ctx, m));
	const names = ctx.R.map(r => r.name), res = { nominal: {}, mean: {}, gates: builds[0].gates, loops: builds[0].loops.length, svg: builds[0].svg, map0: maps[0] };
	names.forEach(n => { res.nominal[n] = per[0][n].score; res.mean[n] = per.reduce((a, p) => a + p[n].score, 0) / per.length; res[n + 'Detail'] = per[0][n]; });
	res.minNominal = Math.min(...names.map(n => res.nominal[n]));
	res.minMean = Math.min(...names.map(n => res.mean[n]));
	res.avgMean = names.reduce((a, n) => a + res.mean[n], 0) / names.length;
	return res;
}

// the reference's own self-consistency
function ceiling(ctx) {
	const { ref, seed } = ctx, s = seed.grid.s, H = seed.frame.H, Y0 = seed.grid.originPx[1], p = seed.side.period;
	const yc = Y0 + H * s / 2, W = ref.w, Hh = ref.h;
	const mk = fn => { const c = new Uint8Array(W * Hh); for (let y = 0; y < Hh; y++) { for (let x = 0; x < W; x++) { const q = fn(x, y); c[y * W + x] = q && q[0] >= 0 && q[1] >= 0 && q[0] < W && q[1] < Hh ? ref.c[q[1] * W + q[0]] : 0; } } return { w: W, h: Hh, c }; };
	const mir = mk((x, y) => [x, Math.round(2 * yc - y)]);
	const per = Math.round(p * s);
	const shY = mk((x, y) => [x, y + per]), shX = mk((x, y) => [x + per, y]);
	const out = {};
	ctx.R.forEach(r => {
		const src = r.name === 'TL' || r.name === 'BL' || r.name === 'top' || r.name === 'bottom' ? mir : null;
		const cands = [];
		if (r.name === 'TL' || r.name === 'BL') { cands.push(['mirror', mir]); }
		if (r.name === 'left') { cands.push(['period', shY]); }
		if (r.name === 'top' || r.name === 'bottom') { cands.push(['period', shX], ['mirror', mir]); }
		let best = null; cands.forEach(([k, m]) => { const g = KM.regionScore(ref, m, r, ctx.band, KM.refDTFor(ctx.dtRef, r)); if (!best || g.score > best.score) { best = { score: g.score, conf: g.conf, how: k }; } });
		out[r.name] = best;
		void src;
	});
	return out;
}

module.exports = { loadRef, regions, bandPx, makeRefCtx, scoreParams, scoreMap, classOf, ceiling, PHASES };

if (require.main === module) {
	(async () => {
		const fs = require('fs');
		const [refFile, seedFile, paramFile] = process.argv.slice(2);
		const seed = JSON.parse(fs.readFileSync(seedFile, 'utf8'));
		const ctx = makeRefCtx(refFile, seed);
		const P = paramFile ? JSON.parse(fs.readFileSync(paramFile, 'utf8')) : G.paramsFromSeed(seed);
		console.log('regions', JSON.stringify(ctx.R));
		console.log('ceiling', JSON.stringify(ceiling(ctx)));
		const r = await scoreParams(ctx, seed, P);
		const fx = o => Object.fromEntries(Object.entries(o).map(([k, v]) => [k, +v.toFixed(4)]));
		console.log('nominal', JSON.stringify(fx(r.nominal)), 'mean', JSON.stringify(fx(r.mean)), 'gates', JSON.stringify(r.gates));
	})();
}
