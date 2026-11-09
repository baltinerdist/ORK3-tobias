'use strict';
// gates.cjs -- correctness gates for a generated border (handoff step 6).
//   closed      every strand is a closed loop (trace finished without leaving the band or reusing a segment)
//   sitesValid  every band site's segment offers are answered
//   alternates  over / under alternates along every loop
//   inkInBand   our ink lies inside the reference band (ref ink or fill, dilated 3 px): <= 0.5% outside
//   loopsPerPeriod  closed side pieces per side period equal the reference's (the reference site map traced the
//               same way), and the colour reference's loop switches per period equal ours (measured separately)
//   noFallback  every frame site came from the seed (no '?' from a missing tile entry)
//   fairness    every barrier curve turns one way only (no curvature sign change: no wiggle)
const SD = require('./seed.cjs'), G = require('./gen.cjs');

// distinct loops passing through one side period in the middle of the side, and how many are closed side pieces
function sideLoopsPerPeriod(loops, seed, AH) {
	const C = seed.corner.size, wS = seed.side.width, p = seed.side.period, b0 = Math.round(AH / 2 - p / 2);
	const touch = loops.filter(l => l.some(e => e.a <= wS && e.b >= b0 && e.b < b0 + p));
	return { window: [b0, b0 + p], loops: touch.length, perPeriod: touch.length, sizes: touch.map(l => l.length).sort((x, y) => x - y) };
	void C;
}

function cubicSignChanges(P0, P1, P2, P3) {
	let last = 0, ch = 0;
	for (let t = 0.02; t < 0.99; t += 0.02) {
		const mt = 1 - t;
		const d1 = [3 * mt * mt * (P1[0] - P0[0]) + 6 * mt * t * (P2[0] - P1[0]) + 3 * t * t * (P3[0] - P2[0]), 3 * mt * mt * (P1[1] - P0[1]) + 6 * mt * t * (P2[1] - P1[1]) + 3 * t * t * (P3[1] - P2[1])];
		const d2 = [6 * mt * (P2[0] - 2 * P1[0] + P0[0]) + 6 * t * (P3[0] - 2 * P2[0] + P1[0]), 6 * mt * (P2[1] - 2 * P1[1] + P0[1]) + 6 * t * (P3[1] - 2 * P2[1] + P1[1])];
		const cr = d1[0] * d2[1] - d1[1] * d2[0], sg = Math.abs(cr) < 1e-6 ? 0 : Math.sign(cr);
		if (sg && last && sg !== last) { ch++; } if (sg) { last = sg; }
	}
	return ch;
}
function fairness(svgPaths) {
	let curves = 0, wiggly = 0;
	svgPaths.forEach(d => {
		const toks = d.match(/[MLCZ]|-?[\d.]+/g); let cur = null, i = 0;
		while (i < toks.length) {
			const c = toks[i++];
			if (c === 'M' || c === 'L') { cur = [+toks[i++], +toks[i++]]; }
			else if (c === 'C') { const p1 = [+toks[i++], +toks[i++]], p2 = [+toks[i++], +toks[i++]], p3 = [+toks[i++], +toks[i++]]; curves++; if (cubicSignChanges(cur, p1, p2, p3)) { wiggly++; } cur = p3; }
		}
	});
	return { curves, wiggly };
}

function inkInBand(refC, oursC, W, H) {
	const band = new Uint8Array(W * H); for (let i = 0; i < W * H; i++) { if (refC[i]) { band[i] = 1; } }
	const R = 3, dil = new Uint8Array(W * H);
	for (let y = 0; y < H; y++) { for (let x = 0; x < W; x++) { if (!band[y * W + x]) { continue; } for (let dy = -R; dy <= R; dy++) { const Y = y + dy; if (Y < 0 || Y >= H) { continue; } for (let dx = -R; dx <= R; dx++) { const X = x + dx; if (X >= 0 && X < W) { dil[Y * W + X] = 1; } } } } }
	let ink = 0, out = 0; for (let i = 0; i < W * H; i++) { if (oursC[i] === 1) { ink++; if (!dil[i]) { out++; } } }
	return { ink, outside: out, frac: ink ? out / ink : 0 };
}

// refLoops: loops traced on the reference's own site map (frame coordinates), for the per-period count
function refSideLoops(A, seed) {
	const iL = Math.min(...[...A.S.values()].filter(v => v.t !== '.' && v.t !== '~').map(v => v.i));
	const jT = Math.min(...[...A.S.values()].filter(v => v.t !== '.' && v.t !== '~').map(v => v.j));
	const map = new Map(); A.S.forEach(v => { const t = SD.collapse(v.t); map.set((v.i - iL) + ',' + (v.j - jT), t === '~' ? '.' : t); });
	// only side-zone loops can be trusted (the frame's far side is outside the image): trace and keep closed ones
	const tr = G.traceLoops({ map }, true);
	return sideLoopsPerPeriod(tr.loops, seed, seed.frame.H);
}

function allGates(seed, build, refC, oursC, W, H, refSide) {
	const paths = build.loops.map(l => G.loopPath(l, build.P));
	const fb = [...build.map.map.values()].filter(t => t === '?').length;
	const ours = sideLoopsPerPeriod(build.loops, seed, build.map.AH), ib = inkInBand(refC, oursC, W, H), fr = fairness(paths);
	const g = {
		closed: build.gates.closed, sitesValid: build.gates.sitesValid, alternates: build.gates.alternates,
		inkInBand: ib.frac <= 0.005, inkOutsideFrac: +ib.frac.toFixed(5),
		loopsPerPeriod: refSide ? ours.perPeriod === refSide.perPeriod && ours.sizes.join() === refSide.sizes.join() : null, oursSide: ours, refSide,
		noFallback: fb === 0, fallbackSites: fb,
		fairness: fr.wiggly === 0, curves: fr.curves, wigglyCurves: fr.wiggly,
	};
	g.all = g.closed && g.sitesValid && g.alternates && g.inkInBand && g.loopsPerPeriod !== false && g.noFallback && g.fairness;
	return g;
}

module.exports = { allGates, sideLoopsPerPeriod, fairness, inkInBand, refSideLoops };

if (require.main === module) {
	(async () => {
		const fs = require('fs'), SC = require('./score.cjs');
		const [refFile, seedFile, pFile] = process.argv.slice(2);
		const seed = JSON.parse(fs.readFileSync(seedFile, 'utf8')), P = JSON.parse(fs.readFileSync(pFile, 'utf8'));
		const A = SD.analyse(refFile); SD.extract(A);
		const refSide = refSideLoops(A, seed);
		const ref = SC.loadRef(refFile), W = ref.w, H = ref.h, AH = seed.frame.H;
		const b = G.build(seed, P, { AW: AH, AH, W, H }); b.P = P;
		const om = await SC.classOf(b.svg, W, H);
		console.log(JSON.stringify(allGates(seed, b, ref.c, om.c, W, H, refSide), null, 1));
	})();
}
