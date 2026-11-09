// fit.cjs <best.json> <end|corner> <out.json> [h=0.15] [deltas=0.03,0.015,0.008] [maxSweeps=3]
// Many-parameter local search on ONE tile's centrelines: normal displacement at knots every h band of arc length,
// raised-cosine partition of unity, path ends pinned (ports). Coordinate descent; objective = the target region's
// metric-v2 score averaged over Ash's raster at 4 sub-pixel phases (0/0.5 px in x and y) -- the jitter mean.
// Everything else (cfg, the other tile) fixed. No gate (an upper-bound probe), checked visually afterwards.
const L = require('./lib.cjs'), KM = L.KM, fs = require('fs');
const [bp, which, outp, hS, dS, mS] = process.argv.slice(2), h = +(hS || 0.15), deltas = (dS || '0.03,0.015,0.008').split(',').map(Number), maxSweeps = +(mS || 3);
const OBJ = process.env.OBJ || 'jit';   // jit | nom
// SMOOTH=λ subtracts λ·Σ_k (d[k-1] − 2d[k] + d[k+1])² (pinned ends included) from the objective: penalises knot-to-knot
// wiggle (the zoom-only bumps/hooks an unregularised fit leaves). INIT=<fit.json> warm-starts d from its expt2.disp
// (same base tile and h), so a smoothing pass can start from an earlier unregularised fit.
const SMOOTH = +(process.env.SMOOTH || 0), INIT = process.env.INIT || '';
(async () => {
	const b = JSON.parse(fs.readFileSync(bp, 'utf8')), { R, band } = await L.regions(1), rn = which === 'end' ? 'top-L' : 'TL', r = R[rn], rc = R.cap;
	const shifts = [[0, 0], [0.5, 0], [0, 0.5], [0.5, 0.5]], refs = [];
	for (const s of shifts) { refs.push(await L.cm(L.ashSvg(s[0] || s[1] ? s : null, false), 1)); }
	const DT = refs.map(c => ({ cm: c, dts: {} }));
	const box = [KM.scanBox(r, band, 0)]; if (which === 'end') { box.push(KM.scanBox(rc, band, 0)); }
	// paths -> point lists
	const tile = which === 'end' ? b.endTile.tile : b.cornerTile.tile;
	const P = tile.paths.map(p => {
		let q = [];
		if (which === 'end') { for (let i = 0; i + 1 < p.pts.length; i += 2) { q.push([p.pts[i], p.pts[i + 1]]); } }
		else { const t = p.d.replace(/[ML]/g, ' ').trim().split(/\s+/).map(Number); for (let i = 0; i + 1 < t.length; i += 2) { q.push([t[i], t[i + 1]]); } }
		const n = q.length, s = [0]; for (let i = 1; i < n; i++) { s[i] = s[i - 1] + Math.hypot(q[i][0] - q[i - 1][0], q[i][1] - q[i - 1][1]); }
		const nr = q.map((_, i) => { const a = q[Math.max(0, i - 1)], c = q[Math.min(n - 1, i + 1)], dx = c[0] - a[0], dy = c[1] - a[1], l = Math.hypot(dx, dy) || 1; return [-dy / l, dx / l]; });
		const Lt = s[n - 1], K = Math.max(2, Math.round(Lt / h)), knots = []; for (let k = 0; k <= K; k++) { knots.push(k * Lt / K); }
		return { q, s, nr, knots, hk: Lt / K, d: new Float64Array(K + 1) };   // d[0] and d[K] stay 0 (ports)
	});
	if (INIT) {
		const disp = JSON.parse(fs.readFileSync(INIT, 'utf8')).expt2.disp;
		P.forEach((p, j) => { if (!disp[j] || disp[j].length !== p.d.length) { throw new Error('INIT knot count mismatch on path ' + j); } p.d.set(disp[j]); });
	}
	const rough = () => { let r = 0; for (const p of P) for (let k = 1; k < p.d.length - 1; k++) { const v = p.d[k - 1] - 2 * p.d[k] + p.d[k + 1]; r += v * v; } return r; };
	const build = () => {
		const t2 = JSON.parse(JSON.stringify(tile));
		P.forEach((p, j) => {
			const pts = p.q.map((pt, i) => { let dd = 0; const u = p.s[i] / p.hk, k0 = Math.floor(u); for (const k of [k0, k0 + 1]) { if (k >= 0 && k < p.d.length) { const x = u - k; if (Math.abs(x) < 1) { dd += p.d[k] * 0.5 * (1 + Math.cos(Math.PI * x)); } } } return [pt[0] + dd * p.nr[i][0], pt[1] + dd * p.nr[i][1]]; });
			if (which === 'end') { t2.paths[j].pts = [].concat(...pts.map(v => [+v[0].toFixed(5), +v[1].toFixed(5)])); }
			else { t2.paths[j].d = 'M ' + pts.map(v => v[0].toFixed(5) + ' ' + v[1].toFixed(5)).join(' L '); }
		});
		return t2;
	};
	const evalT = async t2 => {
		const bb = Object.assign({}, b, which === 'end' ? { endTile: Object.assign({}, b.endTile, { tile: t2 }) } : { cornerTile: Object.assign({}, b.cornerTile, { tile: t2 }) });
		const K = KM.engineFor({ engine: L.E, persist: true }, KM.buildOverrides({ consts: bb.consts || {}, cornerTile: bb.cornerTile, endTile: bb.endTile }));
		const ours = await KM.classMapCropped(KM.renderSvg(K, bb.cfg, true), box, 'js');
		const sc = DT.map(ro => KM.regionScore(ro.cm, ours, r, band, KM.refDTFor(ro, r)).score);
		const cap = which === 'end' ? KM.regionScore(DT[0].cm, ours, rc, band, KM.refDTFor(DT[0], rc)).score : null;
		const jit = sc.reduce((a, c) => a + c, 0) / sc.length;
		const rg = rough();
		return { nom: sc[0], jit, cap, rough: rg, obj: (OBJ === 'nom' ? sc[0] : jit) - SMOOTH * rg, bb };
	};
	let cur = await evalT(build()), nEval = 1; const t0 = Date.now();
	console.log('start', rn, 'nom', cur.nom.toFixed(4), 'jit4', cur.jit.toFixed(4), 'rough', cur.rough.toFixed(4), 'cap', cur.cap, 'knots', P.map(p => p.d.length).join('+'));
	for (const dl of deltas) {
		for (let sw = 0; sw < maxSweeps; sw++) {
			let acc = 0;
			for (const p of P) for (let k = 1; k < p.d.length - 1; k++) {
				const d0 = p.d[k]; let best = null;
				for (const sg of [1, -1]) { p.d[k] = d0 + sg * dl; const e = await evalT(build()); nEval++; if (e.obj > cur.obj + 1e-5 && (!best || e.obj > best.obj)) { best = e; best.v = p.d[k]; } if (best) { break; } }
				if (best) { p.d[k] = best.v; cur = best; acc++; } else { p.d[k] = d0; }
			}
			console.log('delta', dl, 'sweep', sw, 'accepted', acc, 'nom', cur.nom.toFixed(4), 'jit4', cur.jit.toFixed(4), 'rough', cur.rough.toFixed(4), 'cap', cur.cap && cur.cap.toFixed(4), 'evals', nEval, 's', ((Date.now() - t0) / 1000).toFixed(0));
			if (!acc) { break; }
		}
	}
	const out = Object.assign({}, cur.bb, { expt2: { which, h, deltas, smooth: SMOOTH, init: INIT || null, nom: cur.nom, jit4: cur.jit, rough: cur.rough, cap: cur.cap, evals: nEval, disp: P.map(p => Array.from(p.d).map(v => +v.toFixed(4))) } });
	fs.writeFileSync(outp, JSON.stringify(out));
	process.exit(0);
})();
