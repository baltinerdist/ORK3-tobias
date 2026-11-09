#!/usr/bin/env node
/* bench.cjs -- standing performance benchmark for knotmatch.cjs (same candidates, same budget, every version).

   node tools/knot-match/bench.cjs --label <version> --ends <scroll-knot.js> --corners <scroll-knot.js>
        --weave <best.json> --corner <best.json> --end <best.json> [--out bench.jsonl] [--tool knotmatch.cjs]
        [--n 12] [--workers 1,4] [--ttt 15] [--tttDir dir] [--seed 7] [--stages weave,corner,end] [--flags "--fast ..."]
        [--weaveStart best.json --cornerStart best.json --endStart best.json] [--tttPerturb 0.05]
        [--joint best.json] [--reps 3]

   Per stage (weave on --ends, corner on --corners, end on --ends; scoring options = the best.json's own):
   (a) phases: --n candidates (the best, perturbed by N(0, 0.03) in the box-normalised space, fixed rng), scored
       in-process, warm, sequentially, with the full robust set -- ms per candidate split into render / raster /
       classify / align / chamfer (from knotmatch PROF), plus the four-position gate (validate job) on the best;
   (b) throughput: the same candidates through pool(1) and pool(4), evals/s (full robust scoring);
   (c) time to target: optimize --max <ttt> --restarts 0 --seed <seed> --workers 4 from the best (--init; or from
       --<stage>Start; --tttPerturb s starts from the best moved by a fixed-seed N(0, s) step in the box-normalised
       space instead, so the score has room to rise), with
       the round's flags (--race --persist --probation 16 + the best's scoring options + --flags): wall seconds
       and the best score reached.
   --joint best.json adds the joint stage (single merged engine = --ends; the best's primary / cap / periodTol / tiles).
   Under load (other runs on the machine) wall time is noisy: phase (a) is repeated --reps times and each figure is
   the minimum over the repeats, and the phases are this thread's CPU time (PROF.cpu); cpuPerEval is the scoring
   thread's CPU time per candidate and procCpuPerEval the whole process's (GC and compiler threads too), both minima.
   One JSON line per stage is appended to --out. --flags are passed to every scored job and to optimize (a
   speed switch under test, e.g. a rasteriser). */
'use strict';
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

function args(argv) {
	const o = { _: [] };
	for (let i = 0; i < argv.length; i++) {
		const a = argv[i];
		// --flags takes the next argument as is (it is itself a list of --switches)
		if (a.startsWith('--')) { const k = a.slice(2); const v = (argv[i + 1] !== undefined && (k === 'flags' || !argv[i + 1].startsWith('--'))) ? argv[++i] : true; o[k] = v; }
		else { o._.push(a); }
	}
	return o;
}
const o = args(process.argv.slice(2));
const toolPath = path.resolve(o.tool || path.join(__dirname, 'knotmatch.cjs'));
const km0 = require(toolPath), km = Object.assign({}, km0, km0.scoreCandidate.bench());
const N = +(o.n || 12), WORKERS = String(o.workers || '1,4').split(',').map(Number), TTT = +(o.ttt == null ? 15 : o.ttt), SEED = +(o.seed || 7);
const flagArgs = o.flags ? String(o.flags).split(/\s+/).filter(Boolean) : [];
const flagOpts = args(flagArgs);
const STAGES = String(o.stages || ('weave,corner,end' + (o.joint ? ',joint' : ''))).split(',');
const REPS = Math.max(1, +(o.reps || 3));
const now = () => Number(process.hrtime.bigint()) / 1e6;
const med = a => a.slice().sort((x, y) => x - y)[a.length >> 1];
const r1 = v => +v.toFixed(1);

function setup(stage) {
	const best = JSON.parse(fs.readFileSync(path.resolve(o[stage]), 'utf8'));
	const engine = path.resolve(stage === 'corner' ? o.corners : o.ends);
	const base = Object.assign({ cfg: best.cfg, consts: best.consts || {} }, km.baseTiles(engine, best.cfg));
	if (best.cornerTile && best.cornerTile.tile) { base.cornerTile = best.cornerTile.tile; }
	if (best.endTile && best.endTile.tile) { base.endTile = best.endTile.tile; }
	base.warp = true; base.tieBreaks = stage === 'end' && !!best.primary || stage === 'joint';
	if (stage === 'joint') { base.singleEngine = true; base.cornerName = best.cornerTile.name; }
	const sopts = Object.assign(km.scoringOpts(Object.assign({ persist: true }, flagOpts), best));
	const x0 = km.initVector(stage, base), r = km.rng(SEED);
	const g = () => { let u = 0, v = 0; while (!u) { u = r(); } while (!v) { v = r(); } return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v); };
	const jobs = [];
	for (let i = 0; i < N; i++) {
		const x = i === 0 ? x0 : x0.map(v => Math.min(1, Math.max(0, v + 0.03 * g())));
		jobs.push(Object.assign(km.decode(stage, base, x), { engine, ref: km.DEFAULT_REF, regions: km.STAGE_REGIONS[stage], primary: best.primary || null }, sopts, stage === 'joint' ? { joint: true } : {}));
	}
	return { best, engine, jobs, base, x0 };
}

async function phases(stage, S) {
	const clone = j => JSON.parse(JSON.stringify(j));
	await km.scoreCandidate(clone(S.jobs[0])); await km.scoreCandidate(clone(S.jobs[1 % N]));   // warm (ref, DTs, JIT, persistent engine)
	let P = null, tot = null, scores = null, renders = 0, cpu = Infinity, pcpu = Infinity;
	const tcpu = () => { const u = process.threadCpuUsage(); return (u.user + u.system) / 1000; };
	for (let rep = 0; rep < REPS; rep++) {
		km.PROF.on = true; km.PROF.cpu = true; km.PROF.t = {}; km.PROF.n = {};
		const tt = [], sc = [], c0 = process.cpuUsage(), t0 = tcpu();
		for (const j of S.jobs) { const t = now(); const res = await km.scoreCandidate(clone(j)); tt.push(now() - t); sc.push(+(res.score || 0).toFixed(6)); }
		const c1 = process.cpuUsage(c0); pcpu = Math.min(pcpu, (c1.user + c1.system) / 1000 / N); cpu = Math.min(cpu, (tcpu() - t0) / N);
		const Pr = {}; Object.keys(km.PROF.t).forEach(k => { Pr[k] = km.PROF.t[k] / N; });
		if (!P) { P = Pr; } else { Object.keys(Pr).forEach(k => { P[k] = Math.min(P[k] == null ? Infinity : P[k], Pr[k]); }); }
		if (!tot || tt.reduce((a, v) => a + v, 0) < tot.reduce((a, v) => a + v, 0)) { tot = tt; }
		if (scores && scores.join() !== sc.join()) { throw new Error('bench: scores differ between repeats'); }
		scores = sc; renders = (km.PROF.n.render || 0) / N;
	}
	Object.keys(P).forEach(k => { P[k] = r1(P[k]); });
	km.PROF.t = {}; km.PROF.n = {};
	const gt = [];
	for (let i = 0; i < 3; i++) { const t = now(); await km.scoreCandidate(Object.assign(clone(S.jobs[0]), { validate: true })); gt.push(now() - t); }
	km.PROF.on = false; km.PROF.cpu = false;
	return { msPerEval: r1(tot.reduce((a, v) => a + v, 0) / N), msPerEvalMedian: r1(med(tot)), cpuPerEval: r1(cpu), procCpuPerEval: r1(pcpu), rendersPerEval: renders, phase: P, gateMs: r1(med(gt)), scores };
}

async function throughput(S, w) {
	const P = km.pool(w);
	await Promise.all(S.jobs.slice(0, w).map(j => P.run(j)));     // warm every worker
	const reps = Math.max(1, Math.ceil(2 * w * 4 / N));             // >= 8 jobs per worker
	const all = []; for (let k = 0; k < reps; k++) { S.jobs.forEach(j => all.push(j)); }
	const t = now(); await Promise.all(all.map(j => P.run(j))); const sec = (now() - t) / 1000;
	P.close();
	return +(all.length / sec).toFixed(2);
}

function timeToTarget(stage, S, label) {
	const dir = path.resolve(o.tttDir || path.join(path.dirname(path.resolve(o.out || 'bench.jsonl')), 'ttt'), label.replace(/[^\w.-]/g, '_'), stage);
	fs.mkdirSync(dir, { recursive: true });
	let startF = path.resolve(o[stage + 'Start'] || o[stage]);
	if (+o.tttPerturb > 0) {                                  // a fixed degraded start: the best, perturbed
		const r = km.rng(SEED * 31 + 3), g = () => { let u = 0, v = 0; while (!u) { u = r(); } while (!v) { v = r(); } return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v); };
		const x = S.x0.map(v => Math.min(1, Math.max(0, v + +o.tttPerturb * g()))), j = km.decode(stage, S.base, x);
		startF = path.join(dir, 'start.json');
		fs.writeFileSync(startF, JSON.stringify({ stage, primary: S.best.primary, cfg: j.cfg, consts: j.consts, cornerTile: j.cornerTile || null, endTile: j.endTile || null }));
	}
	const b = Object.assign(JSON.parse(fs.readFileSync(startF, 'utf8')), { primary: S.best.primary, cap: S.best.cap, repeatPx: S.best.repeatPx, periodTol: S.best.periodTol, robust: S.best.robust });
	const cfgFile = path.join(dir, 'cfg.json'); fs.writeFileSync(cfgFile, JSON.stringify(b.cfg));
	const a = [toolPath, 'optimize', '--stage', stage, '--engine', S.engine, '--cfg', cfgFile, '--init', startF, '--out', dir,
		'--workers', '4', '--seed', String(SEED), '--max', String(TTT), '--restarts', '0', '--race', '--persist', '--probation', '16'];
	if (b.primary) { a.push('--primary', b.primary); }
	if (b.cap) { a.push('--cap', String(b.cap)); }
	if (b.repeatPx) { a.push('--repeatPx', String(b.repeatPx)); }
	if (b.periodTol) { a.push('--periodTol', String(b.periodTol)); }
	if (b.robust) { a.push('--robust', b.robust.key + ':' + b.robust.deltas.join(',')); if (b.robust.pinPx) { a.push('--robustPin'); } }
	if (stage === 'joint') { a.push('--initEnd', startF, '--initCorner', startF); }
	a.push(...flagArgs);
	try { fs.unlinkSync(path.join(dir, 'log.jsonl')); } catch (e) { /* first run */ }
	const t = now(), p = spawnSync(process.execPath, a, { encoding: 'utf8', maxBuffer: 1 << 26 });
	const wall = (now() - t) / 1000;
	if (p.status !== 0) { return { error: (p.stderr || '').slice(-400) }; }
	const sm = JSON.parse(fs.readFileSync(path.join(dir, 'summary.json'), 'utf8'));
	return { gens: sm.generations, evals: sm.evaluations, sec: +sm.seconds.toFixed(1), wall: +wall.toFixed(1), baseline: +sm.baseline.toFixed(4), best: +sm.best.toFixed(4) };
}

(async () => {
	const label = String(o.label || 'unlabelled'), out = path.resolve(o.out || 'bench.jsonl');
	for (const stage of STAGES) {
		const S = setup(stage);
		const row = { label, stage, at: new Date().toISOString(), n: N, flags: flagArgs.join(' '), load: require('os').loadavg().map(v => +v.toFixed(2)) };
		Object.assign(row, await phases(stage, S));
		row.evalsPerSec = {}; for (const w of WORKERS) { row.evalsPerSec['w' + w] = await throughput(S, w); }
		if (TTT > 0) { row.ttt = timeToTarget(stage, S, label); }
		fs.appendFileSync(out, JSON.stringify(row) + '\n');
		console.log(JSON.stringify(row));
	}
})().catch(e => { console.error(e); process.exit(1); });
