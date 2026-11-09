#!/usr/bin/env node
/* knotmatch.cjs -- score the parametric knotwork engine (scroll-knot.js) against Ash's hand-drawn
   Jovious knot, and evolve engine parameters / designed tile geometry toward it.

   node tools/knot-match/knotmatch.cjs score    --engine <scroll-knot.js> --cfg <cfg.json> [--regions side|corner|end|all] [--out dir]
   node tools/knot-match/knotmatch.cjs optimize --engine <scroll-knot.js> --cfg <cfg.json> --stage weave|corner|end --out <dir>
                                                [--init best.json] [--pop N] [--restarts 12] [--max 600] [--workers 8] [--seed 1]
                                                [--primary TL|top-L|...] [--warp off] [--tie off] [--minGen N]
                                                [--periodTol 0.04] [--robust band.width:-0.03,0,0.03]
                                                [--race] [--raceMargin 0.01] [--persist] [--probation 16] [--only key1,key2] [--sigma s]
   V4 speed switches (same selections / byte-identical renders, see evalGenRaced and buildPersistent):
   --race scores a generation nominal-first and renders the --robust copies only for candidates that can still
   reach the top mu; --persist keeps one warm engine context per worker; --probation P ends a swing / scatter
   run at generation P unless it is tracking toward the incumbent. --only restricts the search to some keys.
   Self-checks (see pool): workers echo a hash of their job; every --audit N-th job (default 50, 0 = off) is re-scored
   in a fresh engine and compared exactly. Every scoring process runs with V8_SAFE (--no-maglev; see there).
   node tools/knot-match/knotmatch.cjs show     --engine <scroll-knot.js> --best <best.json> --out <dir> [--primary R]
   V5 (match / capacity; see the V5 blocks below):
   --stage joint [--engineCorner <corner-tile scroll-knot.js>] [--initEnd end.json] [--initCorner corner.json]
     [--weights side:0.4,end:0.3,corner:0.3] [--jointTiles]: ONE cfg scored on the sides + top-L end (+cap) from
     --engine and the TL corner from --engineCorner (scoreJoint); show of a joint best needs --engineCorner.
   V6: without --engineCorner the joint stage is SINGLE-ENGINE: --engine must be the merged engine (knot-v6-engine,
     END_TILES + CORNER_TILES) and one render per cfg draws the corner and the end together; the search also gets
     endSlide (engine cfg.endSlide 0..1: the share of a corner's phase error each end tile takes by sliding).
   V6 --inkMatch [29:15] pins Ash's fill:outline balance (OUTLINE_RATIO, thickness range); --endColor 0 locks the end
     wrap to the blue strand; --wrapSquare searches the end C's squareness (wq.a) and reach into the break (wq.reach).
   V6 fleck gate: 'flecks' (raster fill crumbs of FLECK_MIN..FLECK_FRAC*wf^2 px) may exceed the baseline by
     --fleckTol (default 2) -- those crumbs are antialiasing / fusion slivers, not painted runs; the strict count is
     'fleckRuns' = painted fill runs shorter than one strand width (from the engine's own cut runs, no raster).
   --robustPin: band-width robustness copies keep the run's repeat in px (not lam/band) -- see robustCfgs.
   --fairWrap: flatten the dent out of the end tile's outer wrap first (fairWrap); --wrapModes N: modes on it.
   gate counts added: wrapDent (end wrap curvature sign changes), inkOut / portGap (corner tile containment and
   port fit), curlOut / curlX / curlKink (the painted, cut and curled runs when strands.cutCurl is on).
   every would-be best (and the baseline) is re-scored in a fresh engine context (--verify off to skip).
   V7 (match / capacity; engine knot-v7-engine; see v7CfgFlags, squareCorner and the fleck gate note):
   --cornerColor k: cfg.cornerColor, the corner tiles' colours shifted k palette steps (1 = Ash's pink outer L at TL);
   --cornerFollow: cfg.cornerFollow, corners after a run's anchor keep its shift on the 1/N-repeat lattice (no side
     stretch); --breakExact [woven|tile]: cfg.breakExact, breaks at their true page position on every spine (the cfg's
     breaks are moved to keep the named spine's placement); --searchRepeat (single-engine joint, no --repeatPx):
     searches cfg.repeatLam; --cornerSquare: searches csq.a / csq.b, the corner tile's outer L squared onto its legs and
     its nested nose squared (squareCorner). The gate now counts fleckRuns only (--fleckGate raster: V6 rule).
   weave space: + strands.edgeBend (engine waveform w + e(w - w^3)); end cfgs may set repeatSplit:'top'.
   V8 (match / capacity; engine knot-v8-engine; see v8Flags, chooseCategorical, traceRedraw / traceFit, endFallback):
   --endBlend [b]: search cfg.endBlend (end tiles' port easing length; straight lead-ins into the C); --traceEnd <trace>
     (trace-corner.cjs END=1): tf.a / tf.du / tf.dv / tf.cut redraw the end wrap's C from Ash's traced C; --traceCorner
     <trace>: tc.a pulls the corner tile onto Ash's traced TL centrelines; --tipExt: + strands.tipExt / tipPow (weave);
     --choose "path=v1|v2;path2+=d1|d2": discrete choices scored up front, best gate-clean one fixed for the run;
     --portGapTol n: portGap may exceed the baseline by n. Gate: endFallback (absolute) -- the end tile was not drawn
     (fold caps); a baseline failing it is no bar (the V7 joint13 best drew fold caps: repeatLam 2.475 > tile slack).
   V9 (solver + painter; engine knot-v9-engine; outside review km/expt/review.md; see optimize: polish, subES, sharpCorners):
   --polish N [--polishSigma 0.003] [--polishLam k] [--polishSparse p] [--polishFinal M]: elitist (1+lambda)-ES polish
     (1/5th rule, sigma floor 2e-4) after every CMA-ES run and as a final phase; --polishSparse 0.1 moves ~10% of the dims
     per child (better on the 50-100-D tile / joint spaces). --kick off: no sigma kick (tile stages: with --sigma 0.005).
   --legFirst (corner / joint): a first CMA-ES run + polish over the leg-phase keys only (LEG_RE). V10 --polishParents K:
     after each CMA-ES run polish the K best distinct candidates of that run (incumbent first), polish / K evaluations each. --multiStart K:G: the
     initial run is K short searches of G generations, then the best continues. --cma off: polish only. --maxEvals E.
   --slant [taper]: search strands.cutSlant / cutSlantShift [/ cutTaper] (+ cutCurl on corner / end); --wrapSharp HW /
     --cornerSharp HW: true corner vertices for strands.join 'miter' (pick join with --choose); --wrapDentTol d: a wrapDent
     sign change fails only if the wrap's hull depth grew by more than d band (0.012 ~ 1 px; the count rule fired on
     sub-pixel ripples, km/v9dev/dent).
   V10 (correctness + painter; engine knot-v10-engine; visual review 5):
   run-stretch gate (runStretch, every run on the drawn page): crossing spacing per lane against the page median, plus the
     engine's own warp pieces (tileDbg.warps) where it records them; a spacing / piece off by more than the tolerance, or
     a sparse run, fails. --stretchGate [abs|rel][:tol] | off: absolute on joint / weave (deliverable pages), no worse than
     the baseline on corner / end (their pages compress the far runs, e.g. corner15 0.88), tol 0.08.
   --phaseSpread [b]: cfg.phaseSpread (with --cornerFollow): spread the phase residual instead of dumping it into the bottom
     runs (joint15: 2.9x stretch -> clean at an unchanged 0.7794 with b = 0.8).
   diag.zones (review item 6): metric v2 conf inside the TL / top-L boxes split into the tile zone (ZONE_K = 1.5 band from
     the corner / the break edge) and the legs; in best.json diag, show's diag.json and its log.
   --carryPhase (joint, with --initCorner): the carried corner tile keeps the --init best's port pins (tile-local leg phase).
   --fillMode: engine strands.paint 'fill' (filled-outline painter) + FILL_SPACE (arc / bar width, arc bulge, inks, arc
     shift toward its convex side); a cfg's own fill values are kept on resume.
   V11 (fit on the deliverable page; tile shape; visual review 6; see nlSpace / legWeaveSpace / squareNested / squareWrap):
   --carryTiles (corner / end, with --init): the --init best's OTHER tile kind is drawn unchanged, so a joint best can be the
     corner or end stage's page (runs at their true repeat; pair with --stretchGate abs and --only on the tile's own keys --
     ctp.phase / ctp.lam move the top run's anchor and with it the end tile). corner16's tile pins on joint16 (ctp.lam
     2.46 vs the page's repeat 2.33): TL 0.776; refit there: TL 0.838, joint 0.8093 -> 0.8289 after a joint pass.
   --nestedL [a]: nl.* -- the corner tile's nested bight redrawn as a true L (vertical left leg, square corner, straight top
     leg; squareNested), start values measured on Ash's raster; a resumed tile keeps its L in tile.nl and starts at a = 0.
   --legWeave (corner / end): the legs' braid shape (thickness, angular, bow, scale, edgeBend, ink / gap ratios) searched.
   --wrapSquareB (end, with --wrapSquare): wq.b squares the C's bottom-outer corner on its own, wq.low widens its lower face.
   V12 (fit TL and top-L together on the joint page; engine knot-v12-engine; see parseHold, fieldSpace):
   --hold name[:floor],... / --sideFloor f: a would-be best keeps each held region's nominal score (left, right, TL, top-L,
     cap; period tol 0.04 as the joint scores them) >= min(floor, baseline) - --holdTol (0.003); no floor = >= baseline.
     Lets an end refit move the end (--endPlace) or a joint pass boost TL / top-L (--weights side:0.1,end:0.45,corner:0.45)
     without trading the sides. The held scores are in diag.checks.hold.
   --endPlace (end): + cfg.endSlide and (when the cfg spreads) cfg.phaseSpread; with etp.lam / brk.* the end moves on the page.
   --fillField [end|corner|both] (fill painter): cfg.fillField.<kind>.a<jk>, a 3x3 cosine width field in each tile's own frame
     (all four positions). Default kind = the stage's tile, both on the joint. Starts at the cfg's values.
   Joint-page refits: use --robust off (as the joint stage does) -- the band.width -0.03 copy of joint bests re-rounds the run
     and moves the top end 0.25 repeat (jC's end refit copies 0.39 / 0.81 / 0.80: the objective was mostly a lattice flip).
   V13 (escape pixel luck; km/v13dev errbd.cjs / jitter.cjs / xsweep.cjs; see jitterRefs, endXform):
   --refJitter [h] (default 0.5; off): the objective is the mean region score over Ash's raster moved by (i h, j h) px,
     i, j < 1/h ((0, 0) = Ash's own) -- one render of ours, no cfg copies, so the lattice and the repeat count never move
     (the joint-page robustness that keeps them; the band.width copy re-rounds the run). The nominal score swings 0.01-0.04
     with the sub-pixel phase (v12-best top-L 0.836 nominal, 0.797-0.836 shifted), so sigma-0.005 tile refits sat on
     pixel-luck spikes (polish from v12-best: +0.0002). Run a --refJitter pass, then a nominal pass (--refJitter off
     --cma off --polishFinal N) from its best: v12-best -> top-L 0.8356 -> 0.8395 (tile 0.770 -> 0.780) in two smokes.
     best.json keeps refJitter and each region's nominal score (.jitNominal); the gate / --hold / validate read nominal.
   --endXform (end / joint): ex.du / ex.dv / ex.rot / ex.sc, the end tile moved in its own frame with the ports pinned
     (weight 1 for U <= 1 easing to 0 at portU) -- placement without moving the lattice.
   Launch caveat: --endBlend <value> and --fairWrap REWRITE a best's own endBlend / wrap; to resume from a best use bare
     --endBlend and no --fairWrap (else the baseline is not the best: end14 re-scored 0.7440 instead of 0.7785).

   Pipeline per candidate: engine (fresh vm context, optional constant/tile overrides) -> SVG at the
   production page size (816x1056) -> rsvg-convert raster at RASTER_W -> per-pixel class map
   {ground, ink, colour A, colour B} -> compared region by region with the same raster of Ash's
   knot.svg. Regions are matched after a small alignment search (along the band for side runs,
   a few px elsewhere); colour A/B may swap (which colour leads is a phase choice, not shape).

   Score per region (0..1): 0.35 fill IoU (mean of A,B) + 0.25 ink IoU + 0.15 silhouette IoU
   + 0.25 exp(-chamfer / (0.05 band)), chamfer = symmetric mean distance between class boundaries.
   A stage's score is the mean over its regions -- or, with --primary, that one region only (the owner's
   target for corners and ends: get one right, the engine repeats it at all four positions; Ash's other
   three are hand variation and are logged as diagnostics only). Only the boxes scoring reads are
   rasterised (classMapCropped: pixel-identical to the full raster), and the alignment search runs
   coarse-to-fine.

   --periodTol t (side regions): also match our raster stretched along the band by 1 +- t -- a run's period
   is set by fitting whole repeats between the end tiles, so it moves ~3% with page geometry; scoring the
   exact period measured where that rounding landed. Ash vs his mirror / 180-degree rotation is unchanged
   by it (0.849 / 0.431 sides). --robust key:d1,d2,..: the score is the mean over copies of the cfg with
   key nudged by each d (a best that holds at one exact value only is a lucky discrete state).
   --repeatPx p (weave/end): pin the run's repeat (engine cfg.repeatLam) so the side runs measure p raster px --
   Ash's measured repeat is 181 px (the period command); this replaces leaning on --periodTol at Ash's page size.
   --cap w (end stage, with --primary): score = (1-w) primary + w 'cap' (the ~1.3-band inner turn of the
   top-L end, where Ash's strand folds back as a hairpin); hairpin tiles also get fold controls (hp.*, hb.*)
   and the hairpin gate (hpX: exactly one self-crossing; hpSlit: the fold's legs never fuse).
   node tools/knot-match/knotmatch.cjs period [page.png ...]   -> side-run repeat (px) of Ash and of each page
   Weave runs should pin cfg.endVariant (engine option): unpinned, the end-tile variant search flips the
   whole border's crossing chirality with tiny band-width changes (0.78 -> 0.44 at +-0.03).

   Gate: a candidate about to become the best is re-rendered at full page and checked at all four
   positions (kinks / centreline outside the band / non-alternating crossings / fill flecks); any count
   worse than the run's baseline rejects it. diag (in best.json) also says how alike the four positions are.

   Search: CMA-ES (learns how parameters co-vary) over a box-normalised vector, with IPOP restarts.
   Tile stages add a smooth 2-D warp of the whole tile (warpPts) to the per-path normal modes.
   Stop rule: a run ends at the first generation (>= max(10, 10 + 30n/lambda) into it) where NEITHER a one-sided Welch
   t-test on the selected top-mu scores of the last 5 generations vs the 5 before finds a
   significant rise (p < 0.05) NOR the best-so-far score rose by MIN_GAIN -- five generations with no statistically or
   practically significant improvement. Then it restarts from the best point (wider search, double
   population); it stops for good when a whole restart adds less than MIN_GAIN. */
'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const os = require('os');
const { spawn, fork } = require('child_process');
const crypto = require('crypto');
// V8 SAFETY (Node 26.0.0 / V8 14.6): with both optimising tiers on and concurrent recompilation, a scoring
// worker occasionally (0.3-1% of end-stage results with concurrent runs) returned one region's result object with
// another region's score -- e.g. end top-L reported the cap's 0.629 for a +0.03 robust copy that truly scores
// 0.467, which inflated end10's saved best (0.6197; true 0.5928). The worker's own re-run of the same
// synchronous code on the same inputs was correct, so it is a JIT miscompile, not tool state. --no-maglev,
// --no-turbofan and --no-concurrent-recompilation each remove it (0 in 3072 stress results vs 10-17 per 3072); --no-maglev
// is also the fastest. Every process that scores runs without Maglev: workers via execArgv, this process here.
const V8_SAFE = process.env.KM_V8_UNSAFE ? [] : ['--no-maglev'];   // KM_V8_UNSAFE=1: tests of the self-checks only
require('v8').setFlagsFromString(V8_SAFE.join(' '));
const { PNG } = require('pngjs');

const PAGE_W = 816, PAGE_H = 1056;          // production render size (scroll-render.js)
const RASTER_W = 1275, RASTER_H = 1650;     // half of Ash's 2550x3300 page
const PALETTE = { bg: [244, 234, 210], ink: [0, 0, 0], A: [42, 91, 215], B: [224, 106, 160] };
const CLS = { bg: 0, ink: 1, A: 2, B: 3 };
const WINDOW = 5;                 // generations per comparison window
const MIN_GAIN = 0.005;           // a best-score gain this large over 5 generations is a real improvement (renders are deterministic)
const DEFAULT_REF = path.resolve(__dirname, '../../assets/scrolls/common/knot/knot.svg');
// phase timers for bench.cjs (ms, summed per process; off unless PROF.on): render, raster (rsvg + PNG decode,
// wall time of the crops), classify, align (alignment search + IoU), chamfer (boundaries + DT + means)
// PROF.cpu: the timers read this thread's CPU time (process.threadCpuUsage) instead of the wall clock -- a figure that
// other processes on the machine do not inflate (bench under load)
const PROF = { on: false, t: {}, n: {}, cpu: false };
const threadMs = () => { const u = process.threadCpuUsage(); return (u.user + u.system) / 1000; };
const pnow = () => (PROF.cpu ? threadMs() : Number(process.hrtime.bigint()) / 1e6);
function prof(k, t0) { if (PROF.on) { PROF.t[k] = (PROF.t[k] || 0) + pnow() - t0; PROF.n[k] = (PROF.n[k] || 0) + 1; } }

// ---------------------------------------------------------------- args
function args(argv) {
	const o = { _: [] };
	for (let i = 0; i < argv.length; i++) {
		const a = argv[i];
		if (a.startsWith('--')) { const k = a.slice(2); const v = (argv[i + 1] && !argv[i + 1].startsWith('--')) ? argv[++i] : true; o[k] = v; }
		else { o._.push(a); }
	}
	return o;
}

// ---------------------------------------------------------------- engine
// Minimal DOM shim: render() only needs createElementNS/setAttribute/appendChild.
function El(tag) { this.tag = tag; this.attrs = {}; this.kids = []; }
El.prototype.setAttribute = function (k, v) { this.attrs[k] = v instanceof LazyD ? v : String(v); };
El.prototype.appendChild = function (c) { this.kids.push(c); return c; };
El.prototype.ser = function () {
	return '<' + this.tag + Object.keys(this.attrs).map(k => ' ' + k + '="' + this.attrs[k] + '"').join('') + '>' +
		this.kids.map(k => k.ser()).join('') + '</' + this.tag + '>';
};
// The engine's polyPath (hooked, see PATH_HOOK) returns one of these instead of its 'M x y L ...' string: the points,
// copied as numbers. Serialising builds exactly polyPath's text (same toFixed(2)), so the SVG is byte-identical;
// --raster js reads the numbers from the element tree instead (rounded the same way), skipping the text both ways.
function LazyD(pts, closed) {
	const n = pts.length, c = new Float64Array(2 * n);
	for (let i = 0; i < n; i++) { c[2 * i] = pts[i][0]; c[2 * i + 1] = pts[i][1]; }
	this.c = c; this.closed = closed;
}
LazyD.prototype.toString = function () {
	const c = this.c; let d = 'M' + fmt2(c[0]) + ' ' + fmt2(c[1]);
	for (let i = 2; i < c.length; i += 2) { d += 'L' + fmt2(c[i]) + ' ' + fmt2(c[i + 1]); }
	return this.closed ? d + 'Z' : d;
};
// x.toFixed(2), built from the integer n nearest 100|x| (see raster.cjs fix2: Math.round decides unless 100|x| is
// within 1e-7 of a half-integer, where toFixed itself is asked); '-' whenever x < 0, as toFixed writes it
function fmt2(x) {
	const a = x < 0 ? -x : x, y = a * 100, f = y - Math.floor(y);
	if (!(y < 1e15) || (f > 0.5 - 1e-7 && f < 0.5 + 1e-7)) { return x.toFixed(2); }
	const n = Math.round(y), ip = Math.floor(n / 100), fp = n - ip * 100;
	return (x < 0 ? '-' : '') + ip + (fp < 10 ? '.0' : '.') + fp;
}
const PATH_HOOK = ['function polyPath(pts, closed) {', 'function polyPath(pts, closed) { if (pts.length && __km.LazyD) { return new __km.LazyD(pts, closed); }'];
// In a vm context every global the engine names (Math, the typed arrays, document, __km) is looked up through the
// context's interceptors on each use -- several times a local's cost in the engine's hot loops (crossings, wave, path
// strings). The engine runs inside a function that binds those names as locals (the very same objects, looked up
// once), so its code and output are unchanged; the source's line 1 stays line 1.
const ENGINE_GLOBALS = ['Math', 'JSON', 'Object', 'Array', 'isFinite', 'Number', 'String', 'Int32Array', 'Float64Array', 'Uint8Array', 'parseInt', 'parseFloat', 'console', 'document', 'window', 'globalThis', '__km'];
function bindGlobals(src) { return '(function (' + ENGINE_GLOBALS.join(', ') + ') {' + src + '\n}).call(this, ' + ENGINE_GLOBALS.join(', ') + ');'; }
const engineSrcCache = {};
// overrides: { consts: {NAME: number}, endTiles: fn(obj)->obj (GEN block), cornerTiles: fn(CORNER_TILES) }
function loadEngine(enginePath, overrides) {
	let src = engineSrcCache[enginePath] || (engineSrcCache[enginePath] = fs.readFileSync(enginePath, 'utf8'));
	overrides = overrides || {};
	Object.keys(overrides.consts || {}).forEach(name => {
		const re = new RegExp('(var\\s+' + name + '\\s*=\\s*)-?[0-9.eE+-]+');
		if (!re.test(src)) { throw new Error('engine constant not found: ' + name); }
		src = src.replace(re, '$1' + (+overrides.consts[name]));
	});
	if (overrides.endTiles) {
		const m = src.match(/\/\*GEN-BEGIN\*\/([\s\S]*?)\/\*GEN-END\*\//);
		if (!m) { throw new Error('engine has no END_TILES GEN block'); }
		const data = new Function('return ' + m[1])();
		src = src.replace(m[0], '/*GEN-BEGIN*/' + JSON.stringify(overrides.endTiles(data)) + '/*GEN-END*/');
	}
	// tool-side taps (rendering unchanged): the polylines render() builds and the crossings (with their
	// over/under) the painter cuts -- read by the geometry checks in checkGeometry()
	const HOOKS = [['var got = collectPolys(cfg, W, H, slots);', 'var got = collectPolys(cfg, W, H, slots); __km.got = got;'],
		['findCrossings(polys, wf * 0.8).forEach(function (c) {', '(__km.cross = findCrossings(polys, wf * 0.8)).forEach(function (c) {'], PATH_HOOK];
	HOOKS.forEach(([a, b]) => { if (src.indexOf(a) >= 0) { src = src.replace(a, b); } });
	const ctx = { document: { createElementNS: (ns, t) => new El(t) }, Math, JSON, Object, Array, isFinite, Number, String, console, __km: { LazyD } };
	ctx.window = ctx; ctx.globalThis = ctx;
	vm.createContext(ctx);
	vm.runInContext(bindGlobals(src), ctx, { filename: enginePath });
	const K = ctx.ScrollKnot;
	K.__km = ctx.__km;
	if (overrides.cornerTiles) { overrides.cornerTiles(K._geom.CORNER_TILES); }
	return K;
}
// --persist: one engine context per engine file per worker, kept across evaluations. A fresh context
// per evaluation threw away V8's warmed-up code every time (a warm render is ~1/3 cheaper). What varies
// per job is swapped instead of re-baked into the source:
//   constants  -- an injected setter assigns the engine's own top-level `var NAME` (read at call time);
//                 only names that no top-level (load-time) code reads are settable, others fall back
//   END_TILES  -- the load-time unpack loop becomes a function (same body) re-run on every tile per job,
//                 from the pristine GEN data (or the override): fresh objects, so no stale per-tile caches
//   CORNER_TILES -- restored from a pristine JSON copy per job (only when it survives JSON exactly)
//   uidCounter -- reset per render (gradient ids), as a fresh context would have it
// Anything the transform cannot anchor disables persistence for that engine (fresh contexts as before).
// The output is checked byte-identical to fresh contexts (tools: persistcheck in v4dev).
const persistCache = {};
function buildPersistent(enginePath) {
	let src = fs.readFileSync(enginePath, 'utf8');
	const lines = src.split('\n'), consts = {};
	lines.forEach(l => { const m = l.match(/^\tvar ([A-Z_][A-Z0-9_]*) = (-?[0-9.eE+-]+);/); if (m && !(m[1] in consts)) { consts[m[1]] = +m[2]; } });
	// a constant is settable when every line naming it, apart from its declaration, is inside a function
	// (indented twice, or a one-line top-level function declaration)
	const settable = Object.keys(consts).filter(name => {
		const re = new RegExp('\\b' + name + '\\b');
		return lines.every(l => !re.test(l) || /^\tvar [A-Z_0-9]+ = -?[0-9.eE+-]+;/.test(l) && l.indexOf('var ' + name + ' ') >= 0 || /^\t\t/.test(l) || /^\tfunction /.test(l));
	});
	const anchorK = '\n\tvar K = {';
	if (src.indexOf(anchorK) < 0 || !/\n\tvar uidCounter = 0;/.test(src)) { return null; }
	let inject = '\n\t__km.setConst = function (n, v) { switch (n) {' + settable.map(n => ' case \'' + n + '\': ' + n + ' = v; break;').join('') + ' } };' +
		'\n\t__km.resetUid = function () { uidCounter = 0; };';
	const loopHead = '\tObject.keys(END_TILES).forEach(function (k) {\n\t\tObject.keys(END_TILES[k]).forEach(function (fam) {\n';
	const loopTail = '\t\t});\n\t});\n\tfunction endTileFamily';
	let gen = null;
	const gm = src.match(/\/\*GEN-BEGIN\*\/([\s\S]*?)\/\*GEN-END\*\//);
	if (gm) {
		const i0 = src.indexOf(loopHead), i1 = i0 < 0 ? -1 : src.indexOf(loopTail, i0);
		if (i0 < 0 || i1 < 0) { return null; }
		src = src.slice(0, i0) + '\tvar __kmUnpackOne = function (k, fam) {\n' + src.slice(i0 + loopHead.length, i1) +
			'\t};\n\tObject.keys(END_TILES).forEach(function (k) { Object.keys(END_TILES[k]).forEach(function (fam) { __kmUnpackOne(k, fam); }); });\n\tfunction endTileFamily' + src.slice(i1 + loopTail.length);
		inject += '\n\t__km.endTiles = END_TILES; __km.unpackEnd = __kmUnpackOne;';
		gen = JSON.stringify(new Function('return ' + gm[1])());
	}
	src = src.replace(anchorK, () => inject + anchorK);
	const HOOKS = [['var got = collectPolys(cfg, W, H, slots);', 'var got = collectPolys(cfg, W, H, slots); __km.got = got;'],
		['findCrossings(polys, wf * 0.8).forEach(function (c) {', '(__km.cross = findCrossings(polys, wf * 0.8)).forEach(function (c) {'], PATH_HOOK];
	HOOKS.forEach(([a, b]) => { if (src.indexOf(a) >= 0) { src = src.replace(a, b); } });
	const ctx = { document: { createElementNS: (ns, t) => new El(t) }, Math, JSON, Object, Array, isFinite, Number, String, console, __km: { LazyD } };
	ctx.window = ctx; ctx.globalThis = ctx;
	vm.createContext(ctx);
	vm.runInContext(bindGlobals(src), ctx, { filename: enginePath + ' (persistent)' });
	const K = ctx.ScrollKnot, km = ctx.__km;
	if (!K || !km.setConst || !km.resetUid) { return null; }
	K.__km = km;
	let corner = null;
	const CT = K._geom && K._geom.CORNER_TILES;
	if (CT) { corner = jsonExact(CT) ? JSON.stringify(CT) : false; }
	return { K, km, consts, settable: new Set(settable), gen, corner };
}
// survives a JSON round trip unchanged: only plain objects / arrays, strings, booleans, null and finite non-negative-zero
// numbers (the vm context's objects have that realm's prototypes, so a deep-equal against a parsed copy cannot be used)
function jsonExact(v) {
	if (v === null || typeof v === 'string' || typeof v === 'boolean') { return true; }
	if (typeof v === 'number') { return isFinite(v) && !Object.is(v, -0); }
	if (typeof v !== 'object') { return false; }
	if (Array.isArray(v)) { return v.every((x, i) => i in v && jsonExact(x)); }
	const p = Object.getPrototypeOf(v);
	if (p !== null && Object.getPrototypeOf(p) !== null) { return false; }   // a plain object of any realm
	return Object.keys(v).every(k => jsonExact(v[k])) && Object.getOwnPropertySymbols(v).length === 0;
}
function persistentEngine(enginePath, overrides) {
	const P = persistCache[enginePath] === undefined ? (persistCache[enginePath] = buildPersistent(enginePath)) : persistCache[enginePath];
	if (!P) { return null; }
	const want = overrides.consts || {};
	if (Object.keys(want).some(n => !P.settable.has(n))) { return null; }
	if (overrides.cornerTiles && P.corner === false) { return null; }
	if (overrides.endTiles && !P.gen) { return null; }
	P.settable.forEach(n => P.km.setConst(n, n in want ? +want[n] : P.consts[n]));
	if (P.gen) {
		// through JSON, as the fresh path splices JSON.stringify(override) into the source (the unpack mutates)
		const data = JSON.parse(P.gen), d2 = overrides.endTiles ? JSON.parse(JSON.stringify(overrides.endTiles(data))) : data;
		Object.keys(d2).forEach(k => { Object.keys(d2[k]).forEach(fam => { P.km.endTiles[k][fam] = d2[k][fam]; P.km.unpackEnd(k, fam); }); });
	}
	if (P.corner) {
		const fresh = JSON.parse(P.corner), CT = P.K._geom.CORNER_TILES;
		Object.keys(fresh).forEach(k => { CT[k] = fresh[k]; });
		if (overrides.cornerTiles) { overrides.cornerTiles(CT); }
	}
	P.km.resetUid();
	P.km.got = undefined; P.km.cross = undefined;
	return P.K;
}
// the engine for one job: persistent when asked for and possible, else a fresh context
function engineFor(job, overrides) {
	if (job.persist) { const K = persistentEngine(job.engine, overrides); if (K) { return K; } }
	return loadEngine(job.engine, overrides);
}
// tree: return the element tree (for --raster js) instead of the SVG text
function renderSvg(K, cfg, tree) {
	const svg = K.render(cfg, PAGE_W, PAGE_H, []);
	svg.attrs.xmlns = 'http://www.w3.org/2000/svg';
	svg.attrs.width = PAGE_W; svg.attrs.height = PAGE_H;
	const bg = new El('rect'); bg.attrs = { width: PAGE_W, height: PAGE_H, fill: rgbHex(PALETTE.bg) };
	svg.kids.unshift(bg);
	return tree ? svg : svg.ser();
}
function rgbHex(c) { return '#' + c.map(x => x.toString(16).padStart(2, '0')).join(''); }
// Rasterise only the boxes scoring reads. Each crop is the page SVG with its root viewBox narrowed to
// the box (pixel-aligned at RASTER_W/PAGE_W, so its pixels equal the full raster's), rendered by its
// own rsvg in parallel; the class map is full-size with everything outside the crops as ground.
// rsvg + PNG decode scale with output area, so a 4-corner or 1-corner job costs a fraction of a page.
async function classMapCropped(svg, boxes, raster) {
	const s = RASTER_W / PAGE_W, W = RASTER_W, H = RASTER_H;
	// --raster js: the in-process rasteriser (raster.cjs), class map straight from the engine's strokes; null
	// (an SVG it does not handle) falls through to rsvg
	if (isJsRaster(raster)) { const t = pnow(), cm = rasterJS().classMapJS(svg, boxes, W, H, s, [PALETTE.bg, PALETTE.ink, PALETTE.A, PALETTE.B], rasterGY(raster)); if (cm) { prof('raster', t); return cm; } }
	if (typeof svg !== 'string') { svg = svg.ser(); }                // an element tree (renderSvg tree) -> text for rsvg
	const out = new Uint8Array(W * H);
	const bx = boxes.map(b => [Math.max(0, Math.floor(b[0])), Math.max(0, Math.floor(b[1])), Math.min(W, Math.ceil(b[2])), Math.min(H, Math.ceil(b[3]))]);
	const merged = [];                    // merge overlapping boxes (union bbox) so no pixel is rendered twice
	bx.forEach(b => {
		for (let i = 0; i < merged.length; i++) {
			const m = merged[i];
			if (b[0] < m[2] && m[0] < b[2] && b[1] < m[3] && m[1] < b[3]) { merged.splice(i, 1); b = [Math.min(b[0], m[0]), Math.min(b[1], m[1]), Math.max(b[2], m[2]), Math.max(b[3], m[3])]; i = -1; }
		}
		merged.push(b);
	});
	const head = svg.match(/^<svg[^>]*>/)[0], tR = pnow(); let tC = 0;
	await Promise.all(merged.map(async b => {
		const cw = b[2] - b[0], ch = b[3] - b[1];
		const h2 = head.replace(/viewBox="[^"]*"/, `viewBox="${b[0] / s} ${b[1] / s} ${cw / s} ${ch / s}"`).replace(/ width="[^"]*"/, ` width="${cw / s}"`).replace(/ height="[^"]*"/, ` height="${ch / s}"`);
		const png = await rasterize(h2 + svg.slice(head.length), cw, ch);
		const t1 = pnow(), cm = classMap(png); tC += pnow() - t1;
		for (let y = 0; y < ch; y++) { out.set(cm.c.subarray(y * cw, y * cw + cw), (b[1] + y) * W + b[0]); }
	}));
	if (PROF.on) { prof('raster', tR + tC); PROF.t.classify = (PROF.t.classify || 0) + tC; PROF.n.classify = (PROF.n.classify || 0) + 1; }
	return { w: W, h: H, c: out };
}

// ---------------------------------------------------------------- raster + classes
let rasterMod = null;
const rasterJS = () => rasterMod || (rasterMod = require('./raster.cjs'));
// --raster js: cairo's scan (15 sub-rows per pixel). --raster js:N (opt-in speed switch, N < 15 sub-rows): agreement
// with rsvg measured in the commit that added it; not exact.
const isJsRaster = r => r === 'js' || (typeof r === 'string' && /^js:\d+$/.test(r));
const rasterGY = r => (r && r.length > 3 ? +r.slice(3) : 0);
function rasterize(svgText, w, h) {
	return new Promise((resolve, reject) => {
		const p = spawn('rsvg-convert', ['-w', String(w), '-h', String(h), '-f', 'png']);
		const chunks = []; let err = '';
		p.stdout.on('data', d => chunks.push(d));
		p.stderr.on('data', d => { err += d; });
		p.on('error', reject);
		p.on('close', code => {
			if (code !== 0) { return reject(new Error('rsvg-convert failed: ' + err)); }
			try { resolve(PNG.sync.read(Buffer.concat(chunks))); } catch (e) { reject(e); }
		});
		p.stdin.end(svgText);
	});
}
// boxes (optional): classify only these [x0,y0,x1,y1] rectangles; everything else reads as ground.
// Scoring touches only its regions plus their alignment margin, so this skips most of the page.
function classMap(png, boxes) {
	const { width: w, height: h, data } = png, out = new Uint8Array(w * h);
	const pal = [PALETTE.bg, PALETTE.ink, PALETTE.A, PALETTE.B];
	const idx = [];
	if (boxes) {
		boxes.forEach(b => {
			const x0 = Math.max(0, Math.floor(b[0])), x1 = Math.min(w, Math.ceil(b[2])), y0 = Math.max(0, Math.floor(b[1])), y1 = Math.min(h, Math.ceil(b[3]));
			for (let y = y0; y < y1; y++) { idx.push([y * w + x0, y * w + x1]); }
		});
	} else { idx.push([0, w * h]); }
	let pk = -1, pc = 0;                  // a run of one RGBA value classes once
	for (const [i0, i1] of idx) for (let i = i0; i < i1; i++) {
		const r = data[i * 4], g = data[i * 4 + 1], b = data[i * 4 + 2], a = data[i * 4 + 3], key = ((r << 24) | (g << 16) | (b << 8) | a) >>> 0;
		if (key === pk) { out[i] = pc; continue; }
		pk = key;
		if (a < 128) { out[i] = pc = 0; continue; }
		let best = 0, bd = 1e9;
		for (let k = 0; k < 4; k++) { const p = pal[k], d = (r - p[0]) ** 2 + (g - p[1]) ** 2 + (b - p[2]) ** 2; if (d < bd) { bd = d; best = k; } }
		out[i] = pc = best;
	}
	return { w, h, c: out };
}
function refSvg(refPath, sh) {
	const src = fs.readFileSync(refPath, 'utf8');
	const body = src.split('-->').slice(1).join('-->').replace(/<\/svg>\s*$/, '');
	// V13 --refJitter: sh = [dx, dy] raster px -- Ash's art moved by a sub-pixel amount (none = the reference itself)
	const g0 = sh ? '<g transform="translate(' + (sh[0] * 2550 / RASTER_W) + ' ' + (sh[1] * 3300 / RASTER_H) + ')">' : '', g1 = sh ? '</g>' : '';
	return '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 2550 3300" width="2550" height="3300">' +
		'<rect width="2550" height="3300" fill="' + rgbHex(PALETTE.bg) + '"/>' + g0 +
		body.split('var(--knot-c1)').join(rgbHex(PALETTE.A)).split('var(--knot-c2)').join(rgbHex(PALETTE.B)) +
		'<use href="#Knot-Band-1"/><use href="#Knot-Band-2"/>' + g1 + '</svg>';
}

// ---------------------------------------------------------------- regions
// Boxes in raster px. The band geometry is measured from Ash's raster so regions follow his art.
function measureRef(ref) {
	const { w, h, c } = ref;
	const colInk = x => { let n = 0; for (let y = Math.floor(h * 0.3); y < h * 0.7; y++) { if (c[y * w + x]) { n++; } } return n; };
	let x0 = 0; while (x0 < w && colInk(x0) === 0) { x0++; }
	let x1 = x0; while (x1 < w && colInk(x1) > 0) { x1++; }
	const band = x1 - x0;
	// top break: scan the middle of the top band row for the ink-free gap around the page centre
	const yMid = Math.round(x0 + band / 2);
	let gl = Math.round(w / 2), gr = gl;
	const rowInk = x => { for (let y = x0; y < x0 + band; y++) { if (c[y * w + x]) { return true; } } return false; };
	while (gl > 0 && !rowInk(gl)) { gl--; }
	while (gr < w && !rowInk(gr)) { gr++; }
	const rowInkB = x => { for (let y = h - x0 - band; y < h - x0; y++) { if (c[y * w + x]) { return true; } } return false; };
	let bl = Math.round(w / 2), br = bl;
	while (bl > 0 && !rowInkB(bl)) { bl--; }
	while (br < w && !rowInkB(br)) { br++; }
	return { inset: x0, band, topGap: [gl, gr], botGap: [bl, br], yMid };
}
function regionsFor(kind, m) {
	const { inset: i, band: b } = m, W = RASTER_W, H = RASTER_H, pad = Math.round(b * 0.35), out = [];
	const sideX = [i - pad, i + b + pad];
	if (kind === 'side' || kind === 'all') {
		out.push({ name: 'left', x0: sideX[0], x1: sideX[1], y0: Math.round(H * 0.3), y1: Math.round(H * 0.7), axis: 'y' });
		out.push({ name: 'right', x0: W - sideX[1], x1: W - sideX[0], y0: Math.round(H * 0.3), y1: Math.round(H * 0.7), axis: 'y' });
	}
	if (kind === 'corner' || kind === 'all') {
		const s = Math.round(i + b * 3.2);
		out.push({ name: 'TL', x0: 0, x1: s, y0: 0, y1: s }, { name: 'TR', x0: W - s, x1: W, y0: 0, y1: s },
			{ name: 'BL', x0: 0, x1: s, y0: H - s, y1: H }, { name: 'BR', x0: W - s, x1: W, y0: H - s, y1: H });
	}
	if (kind === 'end' || kind === 'all') {
		const ew = Math.round(b * 3.6), y0 = i - pad, y1 = i + b + pad;
		out.push({ name: 'top-L', x0: m.topGap[0] - ew, x1: m.topGap[0] + pad, y0, y1 },
			{ name: 'top-R', x0: m.topGap[1] - pad, x1: m.topGap[1] + ew, y0, y1 },
			{ name: 'bot-L', x0: m.botGap[0] - ew, x1: m.botGap[0] + pad, y0: H - y1, y1: H - y0 },
			{ name: 'bot-R', x0: m.botGap[1] - pad, x1: m.botGap[1] + ew, y0: H - y1, y1: H - y0 });
	}
	if (kind === 'cap') {
		// the inner turn of the top-L end (Ash's hairpin: the strand that folds back on itself inside the
		// C and dives under its own leg) -- ~1.3 band square at the break's outer edge
		out.push({ name: 'cap', x0: m.topGap[0] - Math.round(b * 1.25), x1: m.topGap[0] + Math.round(b * 0.05), y0: i - Math.round(b * 0.15), y1: i + Math.round(b * 1.05) });
	}
	return out.map(r => Object.assign(r, { x0: Math.max(0, r.x0), y0: Math.max(0, r.y0), x1: Math.min(W, r.x1), y1: Math.min(H, r.y1) }));
}

// ---------------------------------------------------------------- metrics
// class boundary mask (a pixel whose right or lower neighbour has a different class)
let ZROW = null;
// scratch: true writes into a shared buffer (valid until the next scratch call) instead of a new array
let BNB = null;
function boundary(cm, r, scratch) {
	const bw = r.x1 - r.x0, bh = r.y1 - r.y0, w = cm.w, h = cm.h;
	let out;
	if (scratch) { if (!BNB || BNB.length < bw * bh) { BNB = new Uint8Array(Math.max(bw * bh, 2 * (BNB ? BNB.length : 0))); } out = BNB.subarray(0, bw * bh); out.fill(0); }
	else { out = new Uint8Array(bw * bh); }
	// a row-mapped raster (stretchRows) reads its source's rows; an unmapped row is ground
	const ro = cm.rowOf || null, src = ro ? cm.base.c : cm.c;
	if (ro && (!ZROW || ZROW.length < w)) { ZROW = new Uint8Array(w); }
	const xa = Math.max(0, -r.x0), xb = Math.min(bw, w - r.x0);        // columns inside the raster
	for (let y = 0; y < bh; y++) {
		const gy = r.y0 + y; if (gy < 0 || gy >= h) { continue; }
		const down = gy + 1 < h, o = y * bw;
		let c = src, row = gy * w, d = src, drow = row + w;
		if (ro) {
			if (ro[gy] < 0) { c = ZROW; row = 0; } else { row = ro[gy] * w; }
			if (down) { if (ro[gy + 1] < 0) { d = ZROW; drow = 0; } else { drow = ro[gy + 1] * w; } }
		}
		for (let x = xa; x < xb; x++) {
			const gx = r.x0 + x, v = c[row + gx];
			if ((gx + 1 < w && c[row + gx + 1] !== v) || (down && d[drow + gx] !== v)) { out[o + x] = 1; }
		}
	}
	return out;
}
// 3-4 chamfer distance transform (px), two passes. Integer steps in an Int32 buffer (values stay whole: 0, INF, or
// sums of 3s and 4s; a pixel that only ever sees INF + k keeps INF, as min() did in the old Float32 version), divided
// by 3 into Float32 at the end -- the same numbers as before.
let DTB = null;
// steps: true returns the shared Int32 buffer of 3-4 steps (valid until the next call; the distance is step / 3,
// stored as Float32 by the default form) instead of a new Float32Array
function chamferDT(mask, bw, bh, steps) {
	const INF = 1e9, n = bw * bh;
	if (!DTB || DTB.length < n) { DTB = new Int32Array(Math.max(n, 2 * (DTB ? DTB.length : 0))); }
	const d = DTB;
	for (let i = 0; i < n; i++) { d[i] = mask[i] ? 0 : INF; }
	for (let x = 1; x < bw; x++) { const t = d[x - 1] + 3; if (t < d[x]) { d[x] = t; } }
	// interior columns without bounds tests (x = 0 and x = bw - 1 apart); integer mins, so the order of the
	// neighbour tests does not matter -- the same values as the per-pixel-checked passes
	const last = bw - 1;
	for (let y = 1; y < bh; y++) {
		const r0 = y * bw;
		let i = r0, v = d[i], t = d[i - bw] + 3;
		if (t < v) { v = t; } if (last > 0) { t = d[i - bw + 1] + 4; if (t < v) { v = t; } }
		d[i] = v;
		let left = v;
		for (let x = 1; x < last; x++) {
			i = r0 + x; v = d[i];
			t = left + 3; if (t < v) { v = t; }
			const u = i - bw;
			t = d[u] + 3; if (t < v) { v = t; }
			t = d[u - 1] + 4; if (t < v) { v = t; }
			t = d[u + 1] + 4; if (t < v) { v = t; }
			d[i] = left = v;
		}
		if (last > 0) {
			i = r0 + last; v = d[i];
			t = left + 3; if (t < v) { v = t; } t = d[i - bw] + 3; if (t < v) { v = t; } t = d[i - bw - 1] + 4; if (t < v) { v = t; }
			d[i] = v;
		}
	}
	for (let x = bw - 2, r0 = (bh - 1) * bw; x >= 0; x--) { const t = d[r0 + x + 1] + 3; if (t < d[r0 + x]) { d[r0 + x] = t; } }
	for (let y = bh - 2; y >= 0; y--) {
		const r0 = y * bw;
		let i = r0 + last, v = d[i], t = d[i + bw] + 3;
		if (t < v) { v = t; } if (last > 0) { t = d[i + bw - 1] + 4; if (t < v) { v = t; } }
		d[i] = v;
		let right = v;
		for (let x = last - 1; x > 0; x--) {
			i = r0 + x; v = d[i];
			t = right + 3; if (t < v) { v = t; }
			const u = i + bw;
			t = d[u] + 3; if (t < v) { v = t; }
			t = d[u + 1] + 4; if (t < v) { v = t; }
			t = d[u - 1] + 4; if (t < v) { v = t; }
			d[i] = right = v;
		}
		if (last > 0) {
			i = r0; v = d[i];
			t = right + 3; if (t < v) { v = t; } t = d[i + bw] + 3; if (t < v) { v = t; } t = d[i + bw + 1] + 4; if (t < v) { v = t; }
			d[i] = v;
		}
	}
	if (steps) { return d; }
	const out = new Float32Array(n);
	for (let i = 0; i < n; i++) { out[i] = d[i] / 3; }
	return out;
}
// IoU terms between ref region r and ours shifted by (dx,dy): ours pixel at (x-dx, y-dy) lines up with ref (x,y).
// Every term is a sum over the joint histogram H[a*4+b] of (ref class a, our class b) over the sampled pixels (ours
// outside the raster reads as ground), so the inner loop only bins; integer counts, so the result is unchanged.
// The bins live in four interleaved copies (the main loop takes four pixels per step, one into each): nearly every
// pixel is ground/ground, and back-to-back increments of one counter wait on each other; the copies are summed after.
const OVH = new Int32Array(64);
// Scoring metric (owner, 2026-11-08). Colours are FIXED: Ash's colour A must land on our colour A and B on B
// (no per-region swap). Pixel disagreements are weighted by what matters: black vs colour, black vs ground and
// colour vs ground cost 1; colour A vs colour B costs AB_COST. conf = 1 - weighted disagreements / pixels where
// either drawing has ink or colour (ground-on-ground is ignored, like IoU). KM_METRIC=legacy restores the old
// swap-tolerant fill/ink/silhouette blend for comparisons.
const METRIC = process.env.KM_METRIC === 'legacy' ? 'legacy' : 'v2';
const AB_COST = 0.25;
const CONF_W = [[0, 1, 1, 1], [1, 0, 1, 1], [1, 1, 0, AB_COST], [1, 1, AB_COST, 0]];
function overlapScan(ref, ours, r, dx, dy, stride) {   // the per-pixel histogram (KM_OVERLAP=scan; reference for overlapPacked)
	const H = OVH; H.fill(0);
	if (ours.rowOf) { ours = { w: ours.w, h: ours.h, c: ours.c }; }
	const rc = ref.c, rw = ref.w, oc = ours.c, ow = ours.w, oh = ours.h;
	// sampled x positions are r.x0 + k*stride; those with 0 <= x - dx < ow read ours, the rest read ground
	let kx0 = Math.max(0, Math.ceil((dx - r.x0) / stride)), kx1 = Math.ceil((Math.min(r.x1, ow + dx) - r.x0) / stride);
	const nk = Math.ceil((r.x1 - r.x0) / stride); if (kx1 > nk) { kx1 = nk; } if (kx0 > kx1) { kx0 = kx1; }
	const s2 = 2 * stride, s3 = 3 * stride, s4 = 4 * stride;
	for (let y = r.y0; y < r.y1; y += stride) {
		const oy = y - dy, row = y * rw;
		if (oy < 0 || oy >= oh) { for (let x = r.x0; x < r.x1; x += stride) { H[rc[row + x] << 2]++; } continue; }
		const orow = oy * ow - dx;
		let k = 0, x = r.x0;
		for (; k < kx0; k++, x += stride) { H[rc[row + x] << 2]++; }
		for (; k + 3 < kx1; k += 4, x += s4) {
			const a = row + x, b = orow + x;
			H[(rc[a] << 2) | oc[b]]++; H[16 | (rc[a + stride] << 2) | oc[b + stride]]++;
			H[32 | (rc[a + s2] << 2) | oc[b + s2]]++; H[48 | (rc[a + s3] << 2) | oc[b + s3]]++;
		}
		for (; k < kx1; k++, x += stride) { H[(rc[row + x] << 2) | oc[orow + x]]++; }
		for (; k < nk; k++, x += stride) { H[rc[row + x] << 2]++; }
	}
	for (let i = 0; i < 16; i++) { H[i] += H[i + 16] + H[i + 32] + H[i + 48]; }
	return H;
}
// The same histogram from bit masks. Each sampled row of the ref region (fixed per region and stride, cached) and of
// ours (per column shift dx and stride, packed on first use and kept while scoring the same raster) is held as one
// 32-bit mask per class 1..3 per 32 samples; the 9 coloured pairs are popcounts of ANDed masks, and the pairs with
// ground follow from the per-row class totals (ground/ground is the remainder). Integer counts: the same H.
const POP16 = (() => { const t = new Uint8Array(65536); for (let i = 1; i < 65536; i++) { t[i] = t[i >> 1] + (i & 1); } return t; })();
const REFPACK = new WeakMap();
function refPack(ref, r, stride) {
	let m = REFPACK.get(ref); if (!m) { m = new Map(); REFPACK.set(ref, m); }
	const key = r.x0 + ',' + r.x1 + ',' + r.y0 + ',' + r.y1 + ',' + stride;
	let p = m.get(key); if (p) { return p; }
	const nk = Math.ceil((r.x1 - r.x0) / stride), ny = Math.ceil((r.y1 - r.y0) / stride), nw = (nk + 31) >> 5, rc = ref.c, rw = ref.w;
	const bits = new Int32Array(ny * 3 * nw), tot = [0, 0, 0, 0];
	for (let j = 0; j < ny; j++) {
		const row = (r.y0 + j * stride) * rw + r.x0, o = j * 3 * nw;
		for (let k = 0; k < nk; k++) { const c = rc[row + k * stride]; tot[c]++; if (c) { bits[o + (c - 1) * nw + (k >> 5)] |= 1 << (k & 31); } }
	}
	p = { nk, ny, nw, bits, tot }; m.set(key, p); return p;
}
// ours packs: per (stride s, residue rho, region columns) the samples at x = bx + rho + m*s across the region's columns
// plus a margin XM either side (bx = r.x0 - XM), one row per raster row, packed on first use: any column shift dx
// with the same (x0 - dx - bx) mod s reads the same pack, offset by whole samples (a funnel shift of the words);
// the row's class totals over the shift's nk samples are popcounts of those words (the last one masked). XM covers
// regionScore's column shifts (<= round(0.12 band) + 2); a shift past it falls back to overlapScan. Entries (and
// their buffers) are kept across rasters and invalidated (done flags cleared) when a different raster comes in.
const XM = 16;
const OPK = { src: null, entries: new Map(), live: [] };
function oursPack(src, stride, rho, bx, M) {
	if (OPK.src !== src) { OPK.live.forEach(e => { e.done.fill(0); e.used = false; }); OPK.live = []; OPK.src = src; }
	const key = stride + ',' + rho + ',' + bx + ',' + M;
	let e = OPK.entries.get(key);
	if (!e || e.h !== src.h) {
		const nwp = (M >> 5) + 2;
		e = { h: src.h, M, nwp, bits: new Int32Array(src.h * 3 * nwp), done: new Uint8Array(src.h), used: false };
		OPK.entries.set(key, e);
	}
	if (!e.used) { e.used = true; OPK.live.push(e); }
	return e;
}
function packRow(e, src, sy, stride, x00) {
	const nwp = e.nwp, M = e.M, o = sy * 3 * nwp, bits = e.bits, c = src.c, w = src.w, row = sy * w;
	bits.fill(0, o, o + 3 * nwp);
	// outside the raster's columns: ground (no bits)
	const m0 = Math.max(0, Math.ceil(-x00 / stride)), m1 = Math.min(M, Math.ceil((w - x00) / stride));
	for (let m = m0, x = x00 + m0 * stride; m < m1; m++, x += stride) {
		const v = c[row + x];
		if (v) { bits[o + (v - 1) * nwp + (m >> 5)] |= 1 << (m & 31); }
	}
	e.done[sy] = 1;
}
function overlapPacked(ref, ours, r, dx, dy, stride) {
	const R = refPack(ref, r, stride), nk = R.nk, ny = R.ny, nw = R.nw, RB = R.bits;
	const bx = r.x0 - XM, X0 = r.x0 - dx, off = X0 - bx, M = Math.ceil((r.x1 - r.x0 + 2 * XM) / stride);
	const rho = off % stride, m0 = (off - rho) / stride;
	if (off < 0 || m0 + nk > M) { return overlapScan(ref, ours, r, dx, dy, stride); }   // a shift past the margin
	const H = OVH; H.fill(0, 0, 16);
	const src = ours.rowOf ? ours.base : ours, rowOf = ours.rowOf || null, oh = ours.h;
	const e = oursPack(src, stride, rho, bx, M), OB = e.bits, done = e.done, P = POP16, nwp = e.nwp, sh = m0 & 31, rs = 32 - sh;
	const lastW = nw - 1, lastMask = nk & 31 ? (1 << (nk & 31)) - 1 : -1;
	let n11 = 0, n12 = 0, n13 = 0, n21 = 0, n22 = 0, n23 = 0, n31 = 0, n32 = 0, n33 = 0, o1 = 0, o2 = 0, o3 = 0;
	for (let j = 0, oy = r.y0 - dy; j < ny; j++, oy += stride) {
		if (oy < 0 || oy >= oh) { continue; }                 // ours all ground: only the ground column of H
		const sy = rowOf ? rowOf[oy] : oy; if (sy < 0) { continue; }
		if (!done[sy]) { packRow(e, src, sy, stride, bx + rho); }
		const rb = j * 3 * nw, ob = sy * 3 * nwp + (m0 >> 5);
		for (let w = 0; w < nw; w++) {
			// ours samples 32w.. of this shift (the last word cut at nk)
			let b1, b2, b3; const i1 = ob + w, i2 = i1 + nwp, i3 = i2 + nwp;
			if (sh) { b1 = (OB[i1] >>> sh) | (OB[i1 + 1] << rs); b2 = (OB[i2] >>> sh) | (OB[i2 + 1] << rs); b3 = (OB[i3] >>> sh) | (OB[i3 + 1] << rs); }
			else { b1 = OB[i1]; b2 = OB[i2]; b3 = OB[i3]; }
			if (w === lastW) { b1 &= lastMask; b2 &= lastMask; b3 &= lastMask; }
			if (!(b1 | b2 | b3)) { continue; }
			o1 += P[b1 & 0xffff] + P[b1 >>> 16]; o2 += P[b2 & 0xffff] + P[b2 >>> 16]; o3 += P[b3 & 0xffff] + P[b3 >>> 16];
			const a1 = RB[rb + w], a2 = RB[rb + nw + w], a3 = RB[rb + 2 * nw + w];
			if (!(a1 | a2 | a3)) { continue; }
			let v;
			v = a1 & b1; n11 += P[v & 0xffff] + P[v >>> 16]; v = a1 & b2; n12 += P[v & 0xffff] + P[v >>> 16]; v = a1 & b3; n13 += P[v & 0xffff] + P[v >>> 16];
			v = a2 & b1; n21 += P[v & 0xffff] + P[v >>> 16]; v = a2 & b2; n22 += P[v & 0xffff] + P[v >>> 16]; v = a2 & b3; n23 += P[v & 0xffff] + P[v >>> 16];
			v = a3 & b1; n31 += P[v & 0xffff] + P[v >>> 16]; v = a3 & b2; n32 += P[v & 0xffff] + P[v >>> 16]; v = a3 & b3; n33 += P[v & 0xffff] + P[v >>> 16];
		}
	}
	H[5] = n11; H[6] = n12; H[7] = n13; H[9] = n21; H[10] = n22; H[11] = n23; H[13] = n31; H[14] = n32; H[15] = n33;
	H[4] = R.tot[1] - n11 - n12 - n13; H[8] = R.tot[2] - n21 - n22 - n23; H[12] = R.tot[3] - n31 - n32 - n33;
	H[1] = o1 - n11 - n21 - n31; H[2] = o2 - n12 - n22 - n32; H[3] = o3 - n13 - n23 - n33;
	H[0] = nk * ny - (R.tot[1] + R.tot[2] + R.tot[3]) - H[1] - H[2] - H[3];
	return H;
}
const OVERLAP_HIST = process.env.KM_OVERLAP === 'scan' ? overlapScan : overlapPacked;
// conf alone (metric v2), for the coarse and middle alignment passes, which rank shifts by conf only: with
// union = pixels where either side has ink or colour and the diagonal / A-B pair counts, cost = union - n11 - n22 -
// n33 - 0.75 (n23 + n32) -- the same exact multiple of 1/4 that overlap() sums term by term, so the same conf.
// Six popcounts per word instead of twelve.
function overlapConf(ref, ours, r, dx, dy, stride) {
	const R = refPack(ref, r, stride), nk = R.nk, ny = R.ny, nw = R.nw, RB = R.bits;
	const bx = r.x0 - XM, X0 = r.x0 - dx, off = X0 - bx, M = Math.ceil((r.x1 - r.x0 + 2 * XM) / stride);
	const rho = off % stride, m0 = (off - rho) / stride;
	if (off < 0 || m0 + nk > M || process.env.KM_OVERLAP === 'scan') { return overlap(ref, ours, r, dx, dy, stride).conf; }
	const src = ours.rowOf ? ours.base : ours, rowOf = ours.rowOf || null, oh = ours.h;
	const e = oursPack(src, stride, rho, bx, M), OB = e.bits, done = e.done, P = POP16, nwp = e.nwp, sh = m0 & 31, rs = 32 - sh;
	const lastW = nw - 1, lastMask = nk & 31 ? (1 << (nk & 31)) - 1 : -1;
	let d = 0, ab = 0, both = 0, onz = 0;
	for (let j = 0, oy = r.y0 - dy; j < ny; j++, oy += stride) {
		if (oy < 0 || oy >= oh) { continue; }
		const sy = rowOf ? rowOf[oy] : oy; if (sy < 0) { continue; }
		if (!done[sy]) { packRow(e, src, sy, stride, bx + rho); }
		const rb = j * 3 * nw, ob = sy * 3 * nwp + (m0 >> 5);
		for (let w = 0; w < nw; w++) {
			let b1, b2, b3; const i1 = ob + w, i2 = i1 + nwp, i3 = i2 + nwp;
			if (sh) { b1 = (OB[i1] >>> sh) | (OB[i1 + 1] << rs); b2 = (OB[i2] >>> sh) | (OB[i2 + 1] << rs); b3 = (OB[i3] >>> sh) | (OB[i3 + 1] << rs); }
			else { b1 = OB[i1]; b2 = OB[i2]; b3 = OB[i3]; }
			let bz = b1 | b2 | b3; if (w === lastW) { bz &= lastMask; }
			if (!bz) { continue; }
			onz += P[bz & 0xffff] + P[bz >>> 16];
			const a1 = RB[rb + w], a2 = RB[rb + nw + w], a3 = RB[rb + 2 * nw + w], az = a1 | a2 | a3;
			if (!az) { continue; }
			let v = (a1 & b1) | (a2 & b2) | (a3 & b3); d += P[v & 0xffff] + P[v >>> 16];      // ref bits are 0 past nk
			v = (a2 & b3) | (a3 & b2); ab += P[v & 0xffff] + P[v >>> 16];
			v = az & bz; both += P[v & 0xffff] + P[v >>> 16];
		}
	}
	const union = R.tot[1] + R.tot[2] + R.tot[3] + onz - both, cost = union - d - 0.75 * ab;
	return union > 0 ? 1 - cost / union : 1;
}

function overlap(ref, ours, r, dx, dy, stride) {
	const H = OVERLAP_HIST(ref, ours, r, dx, dy, stride);
	const SW = [0, 1, 3, 2], cntR = [0, 0, 0, 0], cntO = [0, 0, 0, 0], inter = [0, 0, 0, 0], interSwap = [0, 0, 0, 0];
	let silI = 0, silR = 0, silO = 0;
	for (let a = 0; a < 4; a++) {
		for (let b = 0; b < 4; b++) {
			const h = H[(a << 2) | b]; if (!h) { continue; }
			cntR[a] += h; cntO[b] += h;
			if (a === b) { inter[a] += h; }
			if (a === SW[b]) { interSwap[a] += h; }
			if (a) { silR += h; } if (b) { silO += h; } if (a && b) { silI += h; }
		}
	}
	const iou = (i, c) => { const u = cntR[c] + cntO[c] - i[c]; return u > 0 ? i[c] / u : 1; };
	const iouSw = c => { const oc2 = SW[c], u = cntR[c] + cntO[oc2] - interSwap[c]; return u > 0 ? interSwap[c] / u : 1; };
	const fill = (iou(inter, 2) + iou(inter, 3)) / 2, fillSw = (iouSw(2) + iouSw(3)) / 2;
	let cost = 0, union = 0;
	for (let a = 0; a < 4; a++) { for (let b = 0; b < 4; b++) { const h = H[(a << 2) | b]; if (h && (a || b)) { union += h; cost += CONF_W[a][b] * h; } } }
	const conf = union > 0 ? 1 - cost / union : 1;
	if (METRIC === 'legacy') { return { fill: Math.max(fill, fillSw), swapped: fillSw > fill, ink: iou(inter, 1), sil: silR + silO - silI > 0 ? silI / (silR + silO - silI) : 1, conf }; }
	return { fill, swapped: false, ink: iou(inter, 1), sil: silR + silO - silI > 0 ? silI / (silR + silO - silI) : 1, conf };
}
// the pixels regionScore may read for region r: the box plus its alignment-search margin (+2 for boundaries)
function scanBox(r, band, tol) {
	const my = r.axis === 'y' ? Math.round(band * 1.4) + 6 + Math.ceil((tol || 0) * (r.y1 - r.y0) / 2) + 2 : Math.round(band * 0.12) + 6, mx = r.axis === 'y' ? 8 : my;
	return [r.x0 - mx, r.y0 - my, r.x1 + mx, r.y1 + my];
}
function regionScore(ref, ours, r, band, refDT) {
	// alignment search: along the band axis for long side runs (phase is not shape), small elsewhere
	const span = r.axis === 'y' ? Math.round(band * 1.4) : Math.round(band * 0.12), sx = r.axis === 'y' ? 3 : span;
	// coarse-to-fine: the full shift grid at stride 4, the 3 best at stride 2 (+-2 dy, +-1 dx), the best
	// of those at stride 1 (+-1). Same optimum as the old exhaustive stride-2/stride-1 pass in practice,
	// at about a third of the pixel reads.
	const at = (dx, dy, stride) => { const o = overlap(ref, ours, r, dx, dy, stride); return { s: METRIC === 'legacy' ? 0.45 * o.fill + 0.35 * o.ink + 0.2 * o.sil : o.conf, dx, dy, o }; };
	const atS = METRIC === 'legacy' ? at : (dx, dy, stride) => ({ s: overlapConf(ref, ours, r, dx, dy, stride), dx, dy });   // ranking only
	const tA = pnow(), coarse = [];
	for (let dy = -span; dy <= span; dy += 3) { for (let dx = -sx; dx <= sx; dx += 2) { coarse.push(atS(dx, dy, 4)); } }
	coarse.sort((a, b) => b.s - a.s);
	const seen = new Set(), mid = [];
	coarse.slice(0, 3).forEach(c => {
		for (let dy = c.dy - 2; dy <= c.dy + 2; dy++) { for (let dx = c.dx - 1; dx <= c.dx + 1; dx++) { const k = dx + ',' + dy; if (!seen.has(k)) { seen.add(k); mid.push(atS(dx, dy, 2)); } } }
	});
	mid.sort((a, b) => b.s - a.s);
	let best = null;
	const c = mid[0];
	for (let dy = c.dy - 1; dy <= c.dy + 1; dy++) { for (let dx = c.dx - 1; dx <= c.dx + 1; dx++) { const t = at(dx, dy, 1); if (!best || t.s > best.s) { best = t; } } }
	// symmetric chamfer between class boundaries at the chosen alignment
	prof('align', tA); const tCh = pnow();
	const bw = r.x1 - r.x0, bh = r.y1 - r.y0;
	const shifted = { x0: r.x0 - best.dx, x1: r.x1 - best.dx, y0: r.y0 - best.dy, y1: r.y1 - best.dy };
	// our distance at a pixel: the Float32 of steps / 3, as chamferDT stores it (Math.fround), read where it is needed
	const ob = boundary(ours, shifted, true), dst = chamferDT(ob, bw, bh, true), rb = refDT.mask, rdt = refDT.dt;
	let s1 = 0, n1 = 0, s2 = 0, n2 = 0;
	for (let i = 0; i < bw * bh; i++) { if (ob[i]) { s1 += rdt[i]; n1++; } if (rb[i]) { s2 += Math.fround(dst[i] / 3); n2++; } }
	const cap = band;                                   // missing art entirely -> one band of error
	const chamfer = ((n1 ? Math.min(cap, s1 / n1) : cap) + (n2 ? Math.min(cap, s2 / n2) : cap)) / 2;
	const chamferBand = chamfer / band;
	prof('chamfer', tCh);
	const score = METRIC === 'legacy' ? 0.35 * best.o.fill + 0.25 * best.o.ink + 0.15 * best.o.sil + 0.25 * Math.exp(-chamferBand / 0.05)
		: 0.75 * best.o.conf + 0.25 * Math.exp(-chamferBand / 0.05);
	return { name: r.name, score, conf: best.o.conf, fill: best.o.fill, ink: best.o.ink, sil: best.o.sil, chamferBand, dx: best.dx, dy: best.dy, swapped: best.o.swapped };
}

// Period tolerance (--periodTol, side regions only). A run's repeat is set by the page: a whole number of
// repeats has to fit between the two end tiles, so the same design lands within about +-1/(2n) of its
// nominal period on any real page (n ~ 15 here -> ~3%), and a 3% period error drifts a whole strand
// out of register across the 0.4-page scoring window. Scoring the exact period therefore measured where
// the rounding landed, not the weave's shape. With a tolerance the region is also matched against our
// raster stretched along the band about the region centre by s in [1-tol, 1+tol] (nearest-row
// resampling), coarse (tol/2 steps) then fine (tol/4 either side), and the best s is kept (reported).
// The stretched raster is a row map onto ours (rowOf[y] = the source row, -1 = ground): overlap and boundary read
// through it, and the pixels (.c) are only built when something asks for them (the report images).
function stretchRows(ours, r, s, box) {
	const cy = (r.y0 + r.y1) / 2, rowOf = new Int32Array(ours.h).fill(-1);
	for (let y = Math.max(0, box[1]); y < Math.min(ours.h, box[3]); y++) {
		const sy = Math.round(cy + (y - cy) / s); if (sy < 0 || sy >= ours.h) { continue; }
		rowOf[y] = sy;
	}
	let c = null;
	return { w: ours.w, h: ours.h, base: ours, rowOf, get c() {
		if (!c) { c = new Uint8Array(ours.w * ours.h); for (let y = 0; y < ours.h; y++) { if (rowOf[y] >= 0) { c.set(ours.c.subarray(rowOf[y] * ours.w, rowOf[y] * ours.w + ours.w), y * ours.w); } } }
		return c;
	} };
}
function regionScoreTol(ref, ours, r, band, refDT, tol) {
	if (!(tol > 0) || r.axis !== 'y') { const g = regionScore(ref, ours, r, band, refDT); g.scale = 1; Object.defineProperty(g, 'map', { value: ours }); return g; }
	const box = scanBox(r, band, tol), tried = new Map();
	const at = s => {
		const k = s.toFixed(4); if (tried.has(k)) { return tried.get(k); }
		const m = Math.abs(s - 1) < 1e-9 ? ours : stretchRows(ours, r, s, box), g = regionScore(ref, m, r, band, refDT);
		g.scale = +s.toFixed(4); Object.defineProperty(g, 'map', { value: m }); tried.set(k, g); return g;
	};
	let best = null;
	for (let s = 1 - tol; s <= 1 + tol + 1e-9; s += tol / 2) { const g = at(s); if (!best || g.score > best.score) { best = g; } }
	const s0 = best.scale;
	[s0 - tol / 4, s0 + tol / 4].forEach(s => { const g = at(s); if (g.score > best.score) { best = g; } });
	return best;
}
// Robustness (--robust): the score of a cfg is the MEAN over copies of it with one setting nudged (e.g.
// band.width by -0.03/0/+0.03): a design that only scores at one exact value is a lucky discrete state of
// the engine (repeat rounding, tile variant, over/under parity), not a result. Per region, mean of each
// metric; the copy-by-copy scores are kept in .robust.
function robustCfgs(cfg, robust) {
	if (!robust || !robust.key || !robust.deltas || !robust.deltas.length) { return [cfg]; }
	return robust.deltas.map(d => {
		const c = JSON.parse(JSON.stringify(cfg)), ks = robust.key.split('.'); let q = c;
		for (let i = 0; i < ks.length - 1; i++) { q = q[ks[i]]; }
		q[ks[ks.length - 1]] = +q[ks[ks.length - 1]] + d;
		// V5 --robustPin: a band-width copy keeps the run's repeat in px (repeatLam is lam/band, so it would
		// otherwise move the period ~1 px per 0.03 -- a deterministic drift, not the discrete-state luck the
		// nudge is there to expose; at Ash's 181 px a 1 px drift alone cost the weave 0.07 at -0.03)
		if (robust.pinPx && robust.key === 'band.width' && c.repeatLam && d) { c.repeatLam = +(cfg.repeatLam * cfg.band.width / c.band.width).toFixed(5); }
		return c;
	});
}

// Side-run repeat in raster px: the lag (120..260 px) that best matches the fill classes of the left / right
// run with themselves along the band (central half of the page height). Ash's knot: 181 px (2.45 band).
function measurePeriod(cm, m) {
	const out = {};
	['left', 'right'].forEach(side => {
		const x0 = side === 'left' ? m.inset : cm.w - m.inset - m.band, Y0 = Math.round(cm.h * 0.25), Y1 = Math.round(cm.h * 0.75);
		let best = null;
		for (let lag = 120; lag <= 260; lag++) {
			let s = 0, n = 0;
			for (let y = Y0; y + lag < Y1; y += 2) { for (let x = x0; x < x0 + m.band; x += 2) { const a = cm.c[y * cm.w + x], b = cm.c[(y + lag) * cm.w + x]; if (a >= 2 || b >= 2) { n++; if (a === b) { s++; } } } }
			if (!best || s / n > best.r) { best = { lag, r: s / n }; }
		}
		out[side] = best.lag;
	});
	return out;
}
// ---------------------------------------------------------------- reference (cached per process)
let REF = null;
async function getRef(refPath) {
	if (REF && REF.path === refPath) { return REF; }
	const cm = classMap(await rasterize(refSvg(refPath), RASTER_W, RASTER_H));
	const m = measureRef(cm), dts = {};
	REF = { path: refPath, cm, m, dts };
	return REF;
}
// V13 --refJitter h (sub-pixel phase smoothing; km/v13dev jitter.cjs): the metric reads a thresholded class map at integer
// alignments, so a region's score swings ~0.01-0.04 with the sub-pixel phase between our render and Ash's raster (v12-best
// top-L 0.836 nominal, 0.797-0.836 over page shifts of 0.25-0.75 px; its tile zone -0.002 for a 0.08 px move of the tile).
// Tile refits at sigma 0.005 sat on such pixel-luck spikes. With --refJitter h the objective is the mean over Ash's raster
// moved by every (i h, j h) px, i, j = 0..1/h-1 ((0, 0) = the reference itself): one render of ours, (1/h)^2 alignments,
// no cfg copies -- the lattice and the repeat count are untouched (unlike the band.width robustness copy on a joint page).
// Each region keeps its nominal score in .jitNominal; validate / the gate / --hold read the nominal render as before.
const JREFS = new Map();
async function jitterRefs(refPath, h) {
	const key = refPath + '|' + h; if (JREFS.has(key)) { return JREFS.get(key); }
	const ref = await getRef(refPath), n = Math.max(1, Math.round(1 / h)), out = [];
	for (let i = 0; i < n; i++) { for (let j = 0; j < n; j++) { if (i || j) { out.push({ path: refPath, sh: [i / n, j / n], cm: classMap(await rasterize(refSvg(refPath, [i / n, j / n]), RASTER_W, RASTER_H)), m: ref.m, dts: {} }); } } }
	JREFS.set(key, out); return out;
}
async function jitterRegs(job, ref, rects, ours, tol, nominal) {
	if (!(+job.refJitter > 0)) { return nominal; }
	const sets = [nominal]; for (const jr of await jitterRefs(job.ref, +job.refJitter)) { sets.push(rects.map(r => regionScoreTol(jr.cm, ours, r, ref.m.band, refDTFor(jr, r), tol))); }
	return rects.map((r, i) => {
		const g = Object.assign({}, nominal[i], { jitNominal: +nominal[i].score.toFixed(4) });
		['score', 'conf', 'fill', 'ink', 'sil', 'chamferBand'].forEach(k => { if (typeof nominal[i][k] === 'number') { g[k] = sets.reduce((a, rs) => a + rs[i][k], 0) / sets.length; } });
		return g;
	});
}
function refDTFor(ref, r) {
	const key = [r.x0, r.x1, r.y0, r.y1].join(',');
	if (!ref.dts[key]) { const bw = r.x1 - r.x0, bh = r.y1 - r.y0, mask = boundary(ref.cm, r); ref.dts[key] = { mask, dt: chamferDT(mask, bw, bh) }; }
	return ref.dts[key];
}
async function scoreCandidate(job) {
	if (job.joint) { return scoreJoint(job); }   // V5 joint stage
	const ref = await getRef(job.ref);
	let K, svg;
	const rects = pickRegions(job, ref.m), tol = +job.periodTol || 0;
	const tree = isJsRaster(job.raster) && !job.fullRaster;           // scored from the element tree (no SVG text)
	const boxes = rects.map(r => scanBox(r, ref.m.band, tol));
	const scoreSvg = async sv => {
		const ours = job.fullRaster ? classMap(await rasterize(sv, RASTER_W, RASTER_H), boxes) : await classMapCropped(sv, boxes, job.raster);
		return jitterRegs(job, ref, rects, ours, tol, rects.map(r => regionScoreTol(ref.cm, ours, r, ref.m.band, refDTFor(ref, r), tol)));   // V13 --refJitter
	};
	// --race: one robustness copy of the cfg (job.cfg already carries the nominal's repeatLam), scored alone
	if (job.variant != null) {
		const c = robustCfgs(job.cfg, job.robust)[job.variant];
		const tV = pnow();
		try { svg = renderSvg(engineFor(job, buildOverrides(job)), c, tree); } catch (e) { return { score: 0, error: String(e && e.message || e) }; }
		prof('render', tV);
		return { regs: await scoreSvg(svg) };
	}
	const tN = pnow();
	try {
		K = engineFor(job, buildOverrides(job));
		// --repeatPx p: the run's repeat is pinned (engine cfg.repeatLam, lam/band) so it measures p raster px
		// on the side runs -- Ash's own repeat is 181 px at his page (see measurePeriod). Set on the nominal
		// cfg only: the robustness copies keep that lam/band, as a saved config would.
		if (+job.repeatPx > 0) {
			const G = K._geom, L = G.frameLayout(G.norm(job.cfg), PAGE_W, PAGE_H);
			job.cfg = Object.assign({}, job.cfg, { repeatLam: +(+job.repeatPx / (L.band * RASTER_W / PAGE_W)).toFixed(5) });
		}
		svg = renderSvg(K, job.cfg, tree);           // the gate takes the element tree too (gateMap)
	} catch (e) { return { score: 0, error: String(e && e.message || e) }; }
	if (!job.validate) { prof('render', tN); }
	if (job.validate) { return validateRender(job, ref, K, svg); }
	const regs = await scoreSvg(svg);
	const cfgs = job.nominalOnly ? [job.cfg] : robustCfgs(job.cfg, job.robust);
	const sets = [];
	if (cfgs.length > 1) {
		for (const c of cfgs) {
			if (JSON.stringify(c) === JSON.stringify(job.cfg)) { sets.push(regs); continue; }   // the 0 nudge = the nominal render
			const tR = pnow(); let sv; try { sv = renderSvg(engineFor(job, buildOverrides(job)), c, tree); } catch (e) { return { score: 0, error: String(e && e.message || e) }; }
			prof('render', tR);
			sets.push(await scoreSvg(sv));
		}
	}
	const out = combineRobust(rects, regs, sets);
	if (job.nominalOnly) { out.nominalRegs = regs; }
	if (job.cfg.repeatLam != null) { out.repeatLam = job.cfg.repeatLam; }
	if (job.keepSvg) { out.svg = typeof svg === 'string' ? svg : svg.ser(); }
	return out;
}
// the score of a candidate from its nominal regions and (robustness) the region sets of every cfg copy, in
// robustCfgs order with the nominal at its own place -- one code path for the in-worker and the raced score
function combineRobust(rects, nominal, sets) {
	let regs = nominal, robust = null;
	if (sets && sets.length > 1) {
		const ws = rects.map(r => r.weight || 1), wt = ws.reduce((a, v) => a + v, 0);
		robust = sets.map(rs => +(rs.reduce((a, r, i) => a + r.score * ws[i], 0) / wt).toFixed(4));
		regs = rects.map((r, i) => {
			const m = {}; ['score', 'fill', 'ink', 'sil', 'chamferBand'].forEach(k => { m[k] = sets.reduce((a, rs) => a + rs[i][k], 0) / sets.length; });
			return Object.assign({}, nominal[i], m, { nominal: +nominal[i].score.toFixed(4) });
		});
	}
	const wsum = rects.reduce((a, r) => a + (r.weight || 1), 0);
	const score = regs.reduce((a, r, i) => a + r.score * (rects[i].weight || 1), 0) / wsum;
	const nominalScore = nominal.reduce((a, r, i) => a + r.score * (rects[i].weight || 1), 0) / wsum;
	const out = { score, regions: regs, nominalScore };
	if (robust) { out.robust = robust; }
	return out;
}
// the stage's regions, or only the primary one (--primary TL): the owner's target is one corner / one
// end done right and repeated, so Ash's other three (hand variation) are diagnostics, not targets
function pickRegions(job, m) {
	if (job.regions === 'joint') { return jointRegions(job, m); }
	const all = regionsFor(job.regions, m);
	if (!job.primary) { return all; }
	const p = all.filter(r => r.name === job.primary);
	if (!p.length) { throw new Error('no region ' + job.primary + ' in ' + job.regions); }
	// --cap w (end stage): the hairpin sub-region joins the primary, score = (1-w) primary + w cap
	if (+job.cap > 0) { p[0].weight = 1 - +job.cap; p.push(Object.assign(regionsFor('cap', m)[0], { weight: +job.cap })); }
	return p;
}

// ---------------------------------------------------------------- V5 joint stage (one shared config)
// The weave, the end and the corner were each fitted on their own band width / strand settings (the end tile
// scored 0.514 on the weave's). --stage joint scores ONE cfg on all three: the end engine (--engine, end tiles)
// renders the sides (left, right) and the primary end (top-L + its hairpin cap), the corner engine
// (--engineCorner, corner tiles) renders the primary corner (TL). Until the two engine branches are merged the
// corner comes from a second render of the same cfg: each engine ignores what it does not know (the end engine
// draws its corners 'woven'; the corner engine draws plain folds at the breaks and has no repeatLam), and
// only the regions each engine owns are read. Score = weighted mean (--weights side:a,end:b,corner:c, default
// 0.4/0.3/0.3; the end weight is split (1-cap)/cap between top-L and the cap). Robustness / race / gate work
// as in the single stages (the gate checks the sides, the end and the corner positions, keys prefixed).
const JOINT_W = { side: 0.4, end: 0.3, corner: 0.3 };
function jointWeights(w) { return Object.assign({}, JOINT_W, w || {}); }
function jointRegions(job, m) {
	const w = jointWeights(job.weights), cap = +job.cap > 0 ? +job.cap : 0, out = [];
	regionsFor('side', m).forEach(r => out.push(Object.assign(r, { src: 'E', weight: w.side / 2 })));
	const tl = regionsFor('end', m).find(r => r.name === 'top-L');
	out.push(Object.assign(tl, { src: 'E', weight: w.end * (1 - cap) }));
	if (cap > 0) { out.push(Object.assign(regionsFor('cap', m)[0], { src: 'E', weight: w.end * cap })); }
	out.push(Object.assign(regionsFor('corner', m).find(r => r.name === 'TL'), { src: job.engineCorner ? 'C' : 'E', weight: w.corner }));
	return out.filter(r => r.weight > 0);
}
// per-engine overrides: the end engine gets the end tile, the corner engine the corner tile (each lacks the other's table)
function jointOverrides(job, src) {
	const o = { consts: job.consts || {} };
	if (src === 'E' && job.endTile) { o.endTiles = data => { data[job.endTile.name][job.endTile.family] = job.endTile.tile; return data; }; }
	if ((src === 'C' || !job.engineCorner) && job.cornerTile) { o.cornerTiles = CT => { CT[job.cornerTile.name][job.cornerTile.family] = job.cornerTile.tile; }; }
	return o;
}
function jointRender(job, src, cfg, tree) {
	const t = pnow(), K = engineFor({ engine: src === 'E' ? job.engine : job.engineCorner, persist: job.persist }, jointOverrides(job, src));
	const svg = renderSvg(K, cfg, tree); if (tree) { prof('render', t); }
	return { K, svg };
}
async function scoreJoint(job) {
	const ref = await getRef(job.ref), tol = +job.periodTol || 0, rects = jointRegions(job, ref.m);
	const boxes = src => rects.filter(r => r.src === src).map(r => scanBox(r, ref.m.band, tol));
	const scoreCfg = async c => {
		// --raster js applies here too (it was ignored: joint scoring always used rsvg); element trees, as in scoreCandidate
		const tree = isJsRaster(job.raster), e = jointRender(job, 'E', c, tree), mE = await classMapCropped(e.svg, boxes('E'), job.raster);
		// V6 single-engine mode (no --engineCorner): every region is read from the one render
		const mC = job.engineCorner ? await classMapCropped(jointRender(job, 'C', c, tree).svg, boxes('C'), job.raster) : mE;
		const nom = rects.map(r => regionScoreTol(ref.cm, r.src === 'E' ? mE : mC, r, ref.m.band, refDTFor(ref, r), tol));
		if (!(+job.refJitter > 0)) { return nom; }
		// V13 --refJitter (single engine: one map; a two-engine joint smooths each region on its own engine's map)
		const out = []; for (const src of ['E', 'C']) { const ix = rects.map((r, i) => (r.src === src ? i : -1)).filter(i => i >= 0); if (!ix.length) { continue; } const rs = ix.map(i => rects[i]), js = await jitterRegs(job, ref, rs, src === 'E' ? mE : mC, tol, ix.map(i => nom[i])); ix.forEach((i, k) => { out[i] = js[k]; }); }
		return out;
	};
	try {
		if (job.variant != null) { return { regs: await scoreCfg(robustCfgs(job.cfg, job.robust)[job.variant]) }; }
		if (+job.repeatPx > 0) {
			const K = engineFor({ engine: job.engine, persist: job.persist }, jointOverrides(job, 'E')), G = K._geom, L = G.frameLayout(G.norm(job.cfg), PAGE_W, PAGE_H);
			job.cfg = Object.assign({}, job.cfg, { repeatLam: +(+job.repeatPx / (L.band * RASTER_W / PAGE_W)).toFixed(5) });
		}
		if (job.validate) { return validateJoint(job, ref); }
		const regs = await scoreCfg(job.cfg), cfgs = job.nominalOnly ? [job.cfg] : robustCfgs(job.cfg, job.robust), sets = [];
		if (cfgs.length > 1) { for (const c of cfgs) { sets.push(JSON.stringify(c) === JSON.stringify(job.cfg) ? regs : await scoreCfg(c)); } }
		const out = combineRobust(rects, regs, sets);
		if (job.nominalOnly) { out.nominalRegs = regs; }
		if (job.cfg.repeatLam != null) { out.repeatLam = job.cfg.repeatLam; }
		return out;
	} catch (e) { return { score: 0, error: String(e && e.message || e) }; }
}
// gate for the joint stage: the weave page checks, the end checks and the corner checks, each from its own
// engine's render, keys prefixed (side: / end: / corner:) so gateFails compares like with like
async function validateJoint(job, ref) {
	const diag = { regions: [], checks: {} }, merge = (pfx, d) => {
		(d.regions || []).forEach(r => diag.regions.push([pfx + ':' + r[0]].concat(r.slice(1))));
		Object.keys(d.checks || {}).forEach(k => { diag.checks[pfx + ':' + k] = d.checks[k]; });
		['hairpin', 'wrap', 'ports', 'alike', 'zones'].forEach(k => { if (d[k]) { diag[pfx + ':' + k] = d[k]; } });
	};
	const tree = isJsRaster(job.raster), e = jointRender(job, 'E', job.cfg, tree);
	merge('side', (await validateRender(Object.assign({}, job, { regions: 'side', primary: null, hold: null }), ref, e.K, e.svg)).diag);
	merge('end', (await validateRender(Object.assign({}, job, { regions: 'end', primary: 'top-L', noRuns: true, hold: null }), ref, e.K, e.svg)).diag);   // V10: the page's runs once (side:runs)
	const c = job.engineCorner ? jointRender(job, 'C', job.cfg, tree) : e;
	merge('corner', (await validateRender(Object.assign({}, job, { regions: 'corner', primary: 'TL', endTile: null, noRuns: c === e, hold: null }), ref, c.K, c.svg)).diag);
	// V12 --hold: the held regions read off the validate regions (the joint's own period tolerance)
	if (job.hold) { const h = diag.checks.hold = {}; job.hold.forEach(k => { const r = diag.regions.find(q => q[0] === HOLD_JOINT[k]); if (r) { h[k] = r[1]; } }); }
	return { ok: true, diag };
}
async function snapshotJoint(job, outPng) {
	const ref = await getRef(job.ref), rects = jointRegions(job, ref.m), tol = +job.periodTol || 0;
	const e = jointRender(job, 'E', job.cfg), c = job.engineCorner ? jointRender(job, 'C', job.cfg) : null;
	const mE = classMap(await rasterize(e.svg, RASTER_W, RASTER_H)), mC = c ? classMap(await rasterize(c.svg, RASTER_W, RASTER_H)) : mE;
	const regs = rects.map(r => Object.assign(regionScoreTol(ref.cm, r.src === 'E' ? mE : mC, r, ref.m.band, refDTFor(ref, r), tol), {}));
	// compositeRegions reads each region's map from g.map (set by regionScoreTol)
	compositeRegions(ref.cm, mE, regs, rects, outPng);
	return { svg: e.svg, svgCorner: c ? c.svg : null, regs };
}

// ---------------------------------------------------------------- four-position correctness gate
// A candidate that would become the new best is re-rendered at full page and checked at every
// position the piece appears (4 corners / 4 break ends) -- correctness, not similarity:
//   kinks     polyline vertices turning > KINK_DEG between non-tiny segments (broken G1 joins)
//   outside   centreline points outside the band frame (strand leaving the border band)
//   altBreaks consecutive crossings along a strand (both inside a window, < 2 band apart) that do not
//             alternate over/under
//   flecks    fill components smaller than FLECK_FRAC of a strand-width square (slivers / crumbs)
// It fails when any count exceeds the run's baseline (the committed design's own count), so a run can
// never trade correctness for score. Also reports how alike the four positions are (ink/fill agreement
// of the primary vs each other position under the best of the 8 square symmetries / 4 flips, +-2 px).
const KINK_DEG = 35, FLECK_FRAC = 0.35, FLECK_MIN = 6, FUSION_SIN = 0.25;
function windowsFor(kind, m, W, H) {           // raster px boxes of the four positions
	if (kind === 'corner') { const s = Math.round(m.inset + m.band * 3.2); return { TL: [0, 0, s, s], TR: [W - s, 0, W, s], BL: [0, H - s, s, H], BR: [W - s, H - s, W, H] }; }
	const ew = Math.round(m.band * 3.6), pad = Math.round(m.band * 0.35), y0 = m.inset - pad, y1 = m.inset + m.band + pad;
	return { 'top-L': [m.topGap[0] - ew, y0, m.topGap[0] + pad, y1], 'top-R': [m.topGap[1] - pad, y0, m.topGap[1] + ew, y1],
		'bot-L': [m.botGap[0] - ew, H - y1, m.botGap[0] + pad, H - y0], 'bot-R': [m.botGap[1] - pad, H - y1, m.botGap[1] + ew, H - y0] };
}
function checkGeometry(K, windows) {
	const hk = K.__km || {}, got = hk.got, cross = hk.cross;
	if (!got || !cross) { return null; }        // engine without the taps: no geometric checks
	const L = got.layout, s = RASTER_W / PAGE_W, band = L.band, polys = got.polys;
	const wins = Object.keys(windows).map(k => ({ k, b: windows[k].map(v => v / s) }));   // page units
	const inWin = (x, y) => wins.find(w => x >= w.b[0] && x <= w.b[2] && y >= w.b[1] && y <= w.b[3]);
	const res = {}; wins.forEach(w => { res[w.k] = { kinks: 0, outside: 0, altBreaks: 0 }; });
	const tol = 0.03 * band, x0 = L.inset, y0 = L.inset, x1 = L.W - L.inset, y1 = L.H - L.inset;
	polys.forEach(p => {
		const P = p.pts, n = P.length;
		for (let i = 0; i < n; i++) {
			const q = P[i], w = inWin(q[0], q[1]); if (!w) { continue; }
			const out = q[0] < x0 - tol || q[1] < y0 - tol || q[0] > x1 + tol || q[1] > y1 + tol ||
				(q[0] > x0 + band + tol && q[0] < x1 - band - tol && q[1] > y0 + band + tol && q[1] < y1 - band - tol);
			if (out) { res[w.k].outside++; }
			if (i === 0 || i === n - 1) { continue; }
			const a = P[i - 1], c = P[i + 1], v1 = [q[0] - a[0], q[1] - a[1]], v2 = [c[0] - q[0], c[1] - q[1]];
			const l1 = Math.hypot(v1[0], v1[1]), l2 = Math.hypot(v2[0], v2[1]);
			if (l1 < 0.01 * band || l2 < 0.01 * band) { continue; }
			const ang = Math.acos(Math.max(-1, Math.min(1, (v1[0] * v2[0] + v1[1] * v2[1]) / (l1 * l2)))) * 180 / Math.PI;
			if (ang > KINK_DEG) { res[w.k].kinks++; }
		}
	});
	const ev = polys.map(() => []);
	// self-crossings count too (a strand meeting itself -- a fold, a hairpin -- passes that crossing twice,
	// once over and once under); skipping them made every neighbouring pair look non-alternating (the
	// weave gate read 52 where the engine's own alternationRepeats reads 0)
	cross.forEach(c => {
		if (!c.over) { return; }
		if (K._geom.crossingAngleSin && K._geom.crossingAngleSin(c, polys) < FUSION_SIN) { return; }   // tangent fusion: not woven
		ev[c.a].push({ pos: c.ia + c.fa, over: c.over === 'a', x: c.x, y: c.y });
		ev[c.b].push({ pos: c.ib + c.fb, over: c.over === 'b', x: c.x, y: c.y });
	});
	ev.forEach(list => {
		list.sort((a, b) => a.pos - b.pos);
		for (let i = 1; i < list.length; i++) {
			const a = list[i - 1], b = list[i], w = inWin(b.x, b.y);
			if (!w || inWin(a.x, a.y) !== w || Math.hypot(a.x - b.x, a.y - b.y) > 2 * band) { continue; }
			if (a.over === b.over) { res[w.k].altBreaks++; }
		}
	});
	return res;
}
// V10 run-stretch gate (visual review 5: the joint15 page's bottom runs were stretched ~2x into loose diagonals while
// only TL / top-L were scored). Every woven run on the drawn page must keep its repeat. The painter's own crossings
// (tool tap) are projected onto the spine: s along it, and a lane across it (lateral offset in STRETCH_LANE band
// steps). On a uniform braid the crossings in one lane are evenly spaced; each spacing over the lane's page median is
// the local stretch. Spacings with an end inside STRETCH_CORNER band of a corner or STRETCH_END band of a break edge (tiles, ports,
// easing) are not read. Breaks = gaps of over STRETCH_BREAK band in the page's crossing sequence. Also 'sparse': a
// run (between exclusion zones) holding fewer than (1 - tol) x the crossings its length implies at the page's median
// density. symmetry 'mirror': the left half only (the right is its reflection). Returns null without the taps.
const STRETCH_LANE = 0.12, STRETCH_CORNER = 1.6, STRETCH_END = 1.2, STRETCH_BREAK = 1.5;
let stretchTol = 0.08, stretchAbs = null;          // --stretchGate [abs|rel][:tol] | off (stretchTol null); stretchAbs null = by stage
// the page check (validateRender): the spacing ratios that deviate (> 2%) and the sparse-run count (at 10%); the gate
// (gateFails, main process) counts the ratios beyond stretchTol
function runsCheck(K, cfg) {
	const r = runStretch(K, cfg, 0.1);
	return r ? { stretchDev: r.devs, sparse: r.sparse, worst: r.worst, warpWorst: r.warpWorst, at: r.at, n: r.n } : null;
}
function stretchCount(c) { return stretchTol == null || !c ? 0 : (c.stretchDev || []).filter(r => r > 1 + stretchTol || r < 1 / (1 + stretchTol)).length + (c.sparse | 0); }
function runStretch(K, cfg, tol) {
	const hk = K.__km || {}, got = hk.got, cross = hk.cross;
	if (!got || !cross || !got.spine || !got.spine.table) { return null; }
	const spn = got.spine, T = spn.table, band = got.layout.band, S = spn.S, W = got.layout.W, mirror = cfg.symmetry === 'mirror';
	const grid = new Map(), key = (i, j) => i * 100003 + j;
	T.forEach((p, i) => { const k = key(Math.floor(p.x / band), Math.floor(p.y / band)); if (!grid.has(k)) { grid.set(k, []); } grid.get(k).push(i); });
	const proj = (x, y) => {
		const gi = Math.floor(x / band), gj = Math.floor(y / band); let bi = -1, bd = Infinity;
		for (let a = -1; a <= 1; a++) { for (let b = -1; b <= 1; b++) { (grid.get(key(gi + a, gj + b)) || []).forEach(i => { const d = (T[i].x - x) ** 2 + (T[i].y - y) ** 2; if (d < bd) { bd = d; bi = i; } }); } }
		if (bi < 0) { return null; }
		const P = T[bi]; return { s: P.s + (x - P.x) * P.ny - (y - P.y) * P.nx, lane: Math.round(((x - P.x) * P.nx + (y - P.y) * P.ny) / (STRETCH_LANE * band)) };   // s continuous: along the spine tangent (ny, -nx)
	};
	const X = [];
	cross.forEach(c => { if (mirror && c.x > W / 2 + 0.5) { return; } const q = proj(c.x, c.y); if (q) { X.push(q); } });
	if (X.length < 8) { return { stretch: 0, sparse: 0, worst: 1, n: 0 }; }
	X.sort((a, b) => a.s - b.s);
	const zones = [];                                  // [lo, hi] s intervals not read
	const ar = spn.arcStart || {}, La = spn.La || 0, C = STRETCH_CORNER * band, CE = STRETCH_END * band;
	Object.keys(ar).forEach(k => { const sc = ar[k] + La / 2; [-S, 0, S].forEach(o => zones.push([sc + o - C, sc + o + C])); });
	// a crossing gap is a break only where no strand runs (an unwoven stretch has strands but no crossings: gap counts)
	const pg = new Set(); got.polys.forEach(p => p.pts.forEach(q => pg.add(key(Math.floor(q[0] / (0.5 * band)), Math.floor(q[1] / (0.5 * band))))));
	const spAt = s => { s = ((s % S) + S) % S; let lo = 0, hi = T.length - 1; while (hi - lo > 1) { const m = (lo + hi) >> 1; if (T[m].s <= s) { lo = m; } else { hi = m; } } return T[lo]; };
	const strandAt = s => { const P = spAt(s); return pg.has(key(Math.floor(P.x / (0.5 * band)), Math.floor(P.y / (0.5 * band)))); };
	let unwoven = 0;
	// mirror: a gap reaching the right half is the undrawn half, not a stretch
	const gapAt = (a, b) => { if (b - a <= STRETCH_BREAK * band) { return; } if (!(mirror && spAt((a + b) / 2).x > W / 2) && strandAt((a + b) / 2)) { unwoven++; return; } zones.push([a - CE, b + CE]); };
	for (let i = 1; i < X.length; i++) { gapAt(X[i - 1].s, X[i].s); }
	if (!mirror) { gapAt(X[X.length - 1].s, X[0].s + S); zones.push.apply(zones, zones.filter(z => z[1] > S).map(z => [z[0] - S, z[1] - S])); }
	const inZ = s => zones.some(z => s >= z[0] && s <= z[1]);
	const lanes = new Map();
	X.forEach(q => { if (!lanes.has(q.lane)) { lanes.set(q.lane, []); } lanes.get(q.lane).push(q.s); });
	let stretch = 0, n = 0, worst = 1, at = null; const all = [];
	lanes.forEach((L, lane) => {
		const sp = [];
		for (let i = 1; i < L.length; i++) { if (L[i] - L[i - 1] > 1e-6 && !inZ(L[i]) && !inZ(L[i - 1]) && !zones.some(z => L[i - 1] < z[0] && L[i] > z[1])) { sp.push([L[i] - L[i - 1], L[i - 1]]); } }
		if (sp.length < 4) { return; }
		const med = sp.map(v => v[0]).sort((a, b) => a - b)[sp.length >> 1];
		sp.forEach(([d, s0]) => {
			const r = d / med; n++; if (Math.abs(Math.log(r)) > 0.02) { all.push(+r.toFixed(3)); }
			if (Math.abs(Math.log(r)) > Math.abs(Math.log(worst))) { worst = r; at = { s: +s0.toFixed(1), lane }; }
			if (r > 1 + tol || r < 1 / (1 + tol)) { stretch++; }
		});
	});
	// sparse: runs between zones holding too few crossings for their length (a stretch the lanes might not see)
	const dens = [], runs = [];
	let cur = null;
	X.forEach(q => { if (inZ(q.s)) { if (cur && cur.k > 1) { runs.push(cur); } cur = null; return; } if (!cur) { cur = { s0: q.s, s1: q.s, k: 0 }; } cur.s1 = q.s; cur.k++; });
	if (cur && cur.k > 1) { runs.push(cur); }
	runs.forEach(r => { if (r.s1 - r.s0 > 2 * band) { dens.push((r.k - 1) / (r.s1 - r.s0)); } });
	let sparse = 0;
	if (dens.length) {
		const md = dens.slice().sort((a, b) => a - b)[dens.length >> 1];
		runs.forEach(r => { if (r.s1 - r.s0 > band && r.k - 1 < (1 - tol) * md * (r.s1 - r.s0) - 1) { sparse++; if (process.env.KM_STRETCH_DBG) { console.log('sparse run', JSON.stringify(r), 'median density', md); } } });
	}
	// engines with the V10 debug record (tileDbg.warps): the corner warp's own pieces, exact (ds/du; tile windows skipped)
	const wr = got.spine.tileDbg && got.spine.tileDbg.warps;
	let warpWorst = null;
	if (wr) {
		wr.forEach(w => {
			if (w.tile || w.s1 - w.s0 < 0.3 * band || (mirror && spAt((w.s0 + w.s1) / 2).x > W / 2 + 0.5)) { return; }
			if (Math.abs(Math.log(w.k)) > 0.02) { all.push(+w.k.toFixed(3)); }
			if (warpWorst == null || Math.abs(Math.log(w.k)) > Math.abs(Math.log(warpWorst))) { warpWorst = +w.k.toFixed(3); }
			if (w.k > 1 + tol || w.k < 1 / (1 + tol)) { stretch++; }
		});
	}
	all.sort((a, b) => Math.abs(Math.log(b)) - Math.abs(Math.log(a)));
	return { stretch, sparse: sparse + unwoven, worst: +worst.toFixed(3), at, n, warpWorst, devs: all.slice(0, 40) };
}
function flecks(cm, box, minArea) {             // small 4-connected fill components (classes A, B) inside box
	const [bx0, by0, bx1, by1] = box.map(Math.round), w = cm.w, seen = new Uint8Array((bx1 - bx0) * (by1 - by0));
	let n = 0;
	for (let y = by0; y < by1; y++) {
		for (let x = bx0; x < bx1; x++) {
			const li = (y - by0) * (bx1 - bx0) + (x - bx0), cl = cm.c[y * w + x];
			if (seen[li] || cl < 2) { continue; }
			let area = 0, touches = false; const st = [[x, y]]; seen[li] = 1;
			while (st.length) {
				const [px, py] = st.pop(); area++;
				[[1, 0], [-1, 0], [0, 1], [0, -1]].forEach(([dx, dy]) => {
					const qx = px + dx, qy = py + dy;
					if (qx < bx0 || qy < by0 || qx >= bx1 || qy >= by1) { touches = true; return; }
					const qi = (qy - by0) * (bx1 - bx0) + (qx - bx0);
					if (!seen[qi] && cm.c[qy * w + qx] === cl) { seen[qi] = 1; st.push([qx, qy]); }
				});
			}
			// a piece cut by the window edge is not a fleck; under FLECK_MIN px is antialiasing, not art
			if (area >= FLECK_MIN && area < minArea && !touches) { n++; }
		}
	}
	return n;
}
function silAlike(cm, a, b, square) {          // ink/fill agreement of box a vs box b under the best symmetry
	const aw = a[2] - a[0], ah = a[3] - a[1], bw = b[2] - b[0], bh = b[3] - b[1], c = cm.c, w = cm.w, h = cm.h;
	const maps = square ? [[0, 0, 0], [1, 0, 0], [0, 1, 0], [1, 1, 0], [0, 0, 1], [1, 0, 1], [0, 1, 1], [1, 1, 1]] : [[0, 0, 0], [1, 0, 0], [0, 1, 0], [1, 1, 0]];
	let best = { iou: 0, map: '' };
	// box a's samples (every 2nd px), read once: p = min(2, class); 3 marks a read outside the raster's array (a box
	// past the page edge -- min(2, undefined) was NaN there: never equal, and it counts in U only when q does)
	const nx = Math.ceil(aw / 2), ny = Math.ceil(ah / 2), P = new Uint8Array(nx * ny);
	for (let j = 0; j < ny; j++) { for (let i = 0; i < nx; i++) { const v = c[(a[1] + 2 * j) * w + a[0] + 2 * i]; P[j * nx + i] = v === undefined ? 3 : v < 2 ? v : 2; } }
	// index-exact maps (pixel x -> bw-1-x under a flip), best over a +-2 px shift; same counts, same order as before
	// box b's pixels that any map / shift reads, as min(2, class), in one array (255 = outside the raster: skipped)
	let qx0 = 1e9, qy0 = 1e9, qx1 = -1e9, qy1 = -1e9;
	maps.forEach(([fx, fy, tr]) => {
		const ux = tr ? 0 : (fx ? -2 : 2), vx = tr ? (fy ? -2 : 2) : 0, uy = tr ? (fx ? -2 : 2) : 0, vy = tr ? 0 : (fy ? -2 : 2);
		const X0 = b[0] + (fx ? bw - 1 : 0), Y0 = b[1] + (fy ? bh - 1 : 0);
		[[0, 0], [nx - 1, 0], [0, ny - 1], [nx - 1, ny - 1]].forEach(([i, j]) => {
			const X = X0 + i * ux + j * uy, Y = Y0 + i * vx + j * vy;
			qx0 = Math.min(qx0, X - 2); qx1 = Math.max(qx1, X + 2); qy0 = Math.min(qy0, Y - 2); qy1 = Math.max(qy1, Y + 2);
		});
	});
	const qw = qx1 - qx0 + 1, Q = new Uint8Array(qw * (qy1 - qy0 + 1));
	for (let Y = qy0, o = 0; Y <= qy1; Y++) {
		for (let X = qx0; X <= qx1; X++, o++) { if (X < 0 || Y < 0 || X >= w || Y >= h) { Q[o] = 255; } else { const q0 = c[Y * w + X]; Q[o] = q0 < 2 ? q0 : 2; } }
	}
	maps.forEach(([fx, fy, tr]) => {
		for (let sy = -2; sy <= 2; sy++) {
			for (let sx = -2; sx <= 2; sx++) {
				// sample (i, j) of a lands on b at X = b0 + u + sx, Y = b1 + v + sy with (u, v) = the map of (2i, 2j): both
				// step by a constant per i and per j -- one index step in Q each
				let I = 0, U = 0;
				const ux = tr ? 0 : (fx ? -2 : 2), vx = tr ? (fy ? -2 : 2) : 0, uy = tr ? (fx ? -2 : 2) : 0, vy = tr ? 0 : (fy ? -2 : 2);
				const di = ux + vx * qw, dj = uy + vy * qw;
				let q0i = (b[1] + (fy ? bh - 1 : 0) + sy - qy0) * qw + (b[0] + (fx ? bw - 1 : 0) + sx - qx0);
				for (let j = 0; j < ny; j++, q0i += dj) {
					let qi = q0i, k = j * nx;
					for (let i = 0; i < nx; i++, qi += di, k++) {
						const q = Q[qi]; if (q === 255) { continue; }
						// ink vs fill must agree (fill colour may differ): reads the crossing structure, not just the band
						const p = P[k];
						if (p === 3) { if (q) { U++; } continue; }
						if (p || q) { U++; if (p === q) { I++; } }
					}
				}
				const iou = U ? I / U : 1;
				if (iou > best.iou) { best = { iou: +iou.toFixed(3), map: ((tr ? 'T' : '') + (fx ? 'X' : '') + (fy ? 'Y' : '')) || 'id', shift: [sx, sy] }; }
			}
		}
	});
	return best;
}
// The gate's raster. Its pass/fail counts are geometric (engine polylines, crossings, cut runs, tile checks) except
// the end windows, which sit on OUR measured band / break (measureRef of our raster), and the raster fleck count
// under --fleckGate raster. So with --raster js (and the runs fleck gate) the raster is the JS one over just the
// boxes the gate reads -- every region's scan box, the four windows (+3 px for silAlike's shifts), the cap -- and
// the end's measurement comes from rsvg crops of the strips measureRef scans (left band column, top and bottom band
// rows; a measurement that reads outside them takes the full rsvg page). The counts are the same as with the
// full-page rsvg raster; the reported region scores / alike / raster flecks are the JS raster's (as scored).
// --gateRaster rsvg (job.gateRaster) keeps the full-page rsvg raster.
async function measureOurs(K, svgText) {
	const L = K.__km && K.__km.got && K.__km.got.layout, s = RASTER_W / PAGE_W, W = RASTER_W, H = RASTER_H;
	if (L && L.band > 0) {
		const xa = Math.min(W, Math.ceil((L.inset + L.band) * s) + 8), ya0 = Math.max(0, Math.floor(L.inset * s) - 8), ya1 = Math.min(H >> 1, Math.ceil((L.inset + L.band) * s) + 8);
		const cm = await classMapCropped(svgText, [[0, Math.floor(H * 0.3), xa, Math.ceil(H * 0.7)], [0, ya0, W, ya1], [0, H - ya1, W, H - ya0]], 'rsvg');
		const m = measureRef(cm), x1 = m.inset + m.band;
		if (x1 < xa && m.inset >= ya0 && x1 <= ya1) { return m; }
		measureOurs.fallbacks = (measureOurs.fallbacks || 0) + 1;
	}
	return measureRef(classMap(await rasterize(svgText, W, H)));
}
async function gateMap(job, ref, K, svg, kind) {
	const text = () => (typeof svg === 'string' ? svg : svg.ser());
	if (!isJsRaster(job.raster) || fleckGate === 'raster' || job.gateRaster === 'rsvg') {
		const cm = classMap(await rasterize(text(), RASTER_W, RASTER_H));
		return { cm, ourM: kind === 'end' ? measureRef(cm) : null };
	}
	const ourM = kind === 'end' ? await measureOurs(K, text()) : null, tol = +job.periodTol || 0;
	const boxes = regionsFor(job.regions, ref.m).map(r => scanBox(r, ref.m.band, tol));
	if (kind) {
		const wins = windowsFor(kind, kind === 'end' ? ourM : ref.m, RASTER_W, RASTER_H);
		Object.keys(wins).forEach(k => { const w = wins[k]; boxes.push([w[0] - 3, w[1] - 3, w[2] + 3, w[3] + 3]); });
		if (kind === 'end') { boxes.push(scanBox(regionsFor('cap', ref.m)[0], ref.m.band, 0)); }
	}
	if (job.hold) { holdRegions(job.hold, ref.m).forEach(r => boxes.push(scanBox(r, ref.m.band, HOLD_PTOL))); }   // V12 --hold
	const cm = rasterJS().classMapJS(svg, boxes, RASTER_W, RASTER_H, RASTER_W / PAGE_W, [PALETTE.bg, PALETTE.ink, PALETTE.A, PALETTE.B], rasterGY(job.raster));
	if (cm) { return { cm: { w: cm.w, h: cm.h, c: cm.c.slice() }, ourM }; }   // a copy: the gate's map outlives later rasters
	const full = classMap(await rasterize(text(), RASTER_W, RASTER_H));
	return { cm: full, ourM: kind === 'end' ? measureRef(full) : null };
}
// V10 (review item 6) tile-zone vs leg confidence inside the corner / end boxes: metric v2's conf split between the
// pixels within ZONE_K band of the tile (TL: L-infinity distance from the band's outer corner; top-L: distance from the
// break edge) and the rest of the box (the leg braid), at the region's own alignment. Diagnostic only (diag.zones).
const ZONE_K = 1.5;
function zoneConf(refCm, g, r, inTile) {
	const ours = g.map, oc = ours.c, rc = refCm.c, w = refCm.w, h = refCm.h, acc = { tile: [0, 0], legs: [0, 0] };
	for (let y = r.y0; y < r.y1; y++) {
		const oy = y - g.dy;
		for (let x = r.x0; x < r.x1; x++) {
			const ox = x - g.dx, a = rc[y * w + x], b = ox >= 0 && oy >= 0 && ox < w && oy < h ? oc[oy * w + ox] : 0;
			if (!a && !b) { continue; }
			const z = inTile(x, y) ? acc.tile : acc.legs; z[0]++; z[1] += CONF_W[a][b];
		}
	}
	const f = z => (z[0] ? +(1 - z[1] / z[0]).toFixed(4) : null);
	return { tile: f(acc.tile), legs: f(acc.legs), tilePx: acc.tile[0], legPx: acc.legs[0] };
}
function zonesFor(kind, all, refM, refCm) {
	const out = {}, k = ZONE_K * refM.band;
	all.forEach(g => {
		const r = regionsFor(kind, refM).find(q => q.name === g.name); if (!r || !g.map) { return; }
		if (g.name === 'TL') { out.TL = zoneConf(refCm, g, r, (x, y) => Math.max(x - refM.inset, y - refM.inset) < k); }
		if (g.name === 'top-L') { out['top-L'] = zoneConf(refCm, g, r, x => x > refM.topGap[0] - k); }
	});
	return out;
}
// V12 --hold: the held regions' nominal scores on the gate's full-page map (HOLD_PTOL, as the joint stage scores them)
function holdScores(job, ref, cm) {
	const out = {}, rs = holdRegions(job.hold, ref.m);
	job.hold.forEach((k, i) => { out[k] = +regionScoreTol(ref.cm, cm, rs[i], ref.m.band, refDTFor(ref, rs[i]), HOLD_PTOL).score.toFixed(4); });
	return out;
}
async function validateRender(job, ref, K, svg) {
	const kind = job.regions === 'corner' ? 'corner' : job.regions === 'end' ? 'end' : null;
	// V10 run stretch first: later checks re-render on K (the end's endFallback draws the fold-ends page) and overwrite its taps
	const rc = job.noRuns ? null : runsCheck(K, job.cfg);
	const gm = await gateMap(job, ref, K, svg, kind), cm = gm.cm;
	const all = regionsFor(job.regions, ref.m).map(r => regionScoreTol(ref.cm, cm, r, ref.m.band, refDTFor(ref, r), +job.periodTol || 0));
	const diag = { regions: all.map(r => [r.name, +r.score.toFixed(4)].concat(r.scale !== 1 ? [r.scale] : [])) };
	if (kind) { try { diag.zones = zonesFor(kind, all, ref.m, ref.cm); } catch (e) { diag.zones = { error: e.message }; } }   // V10 tile vs legs
	if (!kind) {
		// weave: the over/under, kink and band checks over the whole (drawn) border -- the weave stage moves
		// band width, which re-rounds the runs and can leave a tile's tuck on top or a repeated crossing
		const wins = { page: [0, 0, job.cfg.symmetry === 'mirror' ? RASTER_W / 2 : RASTER_W, RASTER_H] };
		const geo = checkGeometry(K, wins);
		if (geo) { diag.checks = geo; }
		const cu = curlChecks(K, job.cfg, wins);
		if (cu && geo) { Object.keys(cu).forEach(k => Object.assign(geo[k], cu[k])); }
		if (rc) { (diag.checks = diag.checks || {}).runs = rc; }   // V10 run-stretch gate
		if (job.hold) { (diag.checks = diag.checks || {}).hold = holdScores(job, ref, cm); }   // V12 --hold
		return { ok: true, diag };
	}
	const ourM = gm.ourM;                                 // our own band / break positions (end)
	const wins = windowsFor(kind, kind === 'end' ? ourM : ref.m, RASTER_W, RASTER_H);
	// symmetry:'mirror' paints the right half as the reflection of the left: the right half's own
	// polylines are never drawn, so check the left positions (the right ones are their mirror images)
	const mirror = job.cfg.symmetry === 'mirror', geoWins = {};
	Object.keys(wins).forEach(k => { if (!mirror || /L$/.test(k)) { geoWins[k] = wins[k]; } });
	const geo = checkGeometry(K, geoWins) || {};
	const wf = cm && ref.m.band / 4 * ((job.cfg.strands && job.cfg.strands.thickness) || 0.5);
	Object.keys(wins).forEach(k => { (geo[k] = geo[k] || {}).flecks = flecks(cm, wins[k], FLECK_FRAC * wf * wf); });
	const fr = fleckRuns(K, job.cfg, geoWins);   // mirror: only the drawn (left) positions
	if (fr) { Object.keys(fr).forEach(k => { geo[k].fleckRuns = fr[k]; }); }
	const prim = job.primary || (kind === 'corner' ? 'TL' : 'top-L');
	const alike = {};
	Object.keys(wins).forEach(k => { if (k !== prim) { alike[k] = silAlike(cm, wins[prim].map(Math.round), wins[k].map(Math.round), kind === 'corner'); } });
	if (kind === 'end') {
		const cr = regionsFor('cap', ref.m)[0], cs = regionScore(ref.cm, cm, cr, ref.m.band, refDTFor(ref, cr));
		diag.regions.push(['cap', +cs.score.toFixed(4)]);
		const hp = job.endTile && hairpinChecks(job.endTile.tile, (job.cfg.strands && job.cfg.strands.thickness) || 0.5);
		if (hp) { const g = geo[prim] = geo[prim] || {}; g.hpX = hp.hpX; g.hpSlit = hp.hpSlit; diag.hairpin = hp; }
		const wc = job.endTile && wrapChecks(job.endTile.tile);
		if (wc) { const g = (geo[prim] = geo[prim] || {}); g.wrapDent = wc.wrapDent; wc.wrapDepth = g.wrapDepth = wrapDepth(job.endTile.tile); diag.wrap = wc; }   // V9: depth for --wrapDentTol (gate in the main process)
		// V8 endFallback: the designed end tile was not drawn -- the engine fell back to plain fold caps (lockTileEnds
		// gives up when the run's repeat leaves the tile's TILE_LAM_SLACK or its ports cannot be matched). The V7 joint
		// best (joint13, repeatLam 2.475 against a 2.15 tile) drew fold "O" caps on the whole page this way (visual review
		// 3, items 1-2). Detected by rendering the same cfg with ends 'fold': identical SVG = no tile. Absolute gate.
		if (job.cfg.ends && job.cfg.ends !== 'fold') {
			const s0 = typeof svg === 'string' ? svg : svg.ser(), sF = renderSvg(K, Object.assign({}, job.cfg, { ends: 'fold' }));
			(geo[prim] = geo[prim] || {}).endFallback = s0 === sF ? 1 : 0;
		}
	}
	const cu = curlChecks(K, job.cfg, geoWins);
	if (cu) { Object.keys(cu).forEach(k => { Object.assign(geo[k] = geo[k] || {}, cu[k]); }); }
	if (kind === 'corner') {
		const cc = cornerChecks(K, job.cfg, geoWins);
		if (cc) { Object.keys(cc.res).forEach(k => { Object.assign(geo[k] = geo[k] || {}, cc.res[k]); }); diag.ports = { worstGap: cc.worstPortGap, wOutBand: cc.wOutBand }; }
	}
	if (rc) { geo.runs = rc; }   // V10 run-stretch gate (every run on the page)
	if (job.hold) { geo.hold = holdScores(job, ref, cm); }   // V12 --hold
	diag.checks = geo; diag.alike = alike;
	return { ok: true, diag };                            // pass/fail is decided against the baseline by the caller
}
// Hairpin end tiles (a path with id 'hairpin': port -> into the C -> folds back -> dives under its own
// incoming leg -> back out to a port). In tile units (band widths): hpX = |self-crossings - 1| (exactly
// one, the intended dive-under); hpSlit = 1 when two non-adjacent stretches of the path (more than 3
// strand widths apart along it, away from that crossing) come closer than one strand width -- the fills
// would fuse and the slit between the fold's legs collapse. Both are gate counts (see gateFails).
function hairpinChecks(tile, thickness) {
	const pa = tile && tile.paths && tile.paths.find(p => p.id === 'hairpin');
	if (!pa) { return null; }
	const P = []; for (let i = 0; i + 1 < pa.pts.length; i += 2) { P.push([pa.pts[i], pa.pts[i + 1]]); }
	const wf = thickness / 4, n = P.length, X = [];
	for (let i = 0; i + 1 < n; i++) {
		for (let j = i + 2; j + 1 < n; j++) {
			const a = P[i], r = [P[i + 1][0] - a[0], P[i + 1][1] - a[1]], c = P[j], q = [P[j + 1][0] - c[0], P[j + 1][1] - c[1]];
			const den = r[0] * q[1] - r[1] * q[0]; if (Math.abs(den) < 1e-12) { continue; }
			const t = ((c[0] - a[0]) * q[1] - (c[1] - a[1]) * q[0]) / den, u = ((c[0] - a[0]) * r[1] - (c[1] - a[1]) * r[0]) / den;
			if (t >= 0 && t < 1 && u >= 0 && u < 1) { X.push([a[0] + t * r[0], a[1] + t * r[1]]); }
		}
	}
	const cum = [0]; for (let i = 1; i < n; i++) { cum[i] = cum[i - 1] + Math.hypot(P[i][0] - P[i - 1][0], P[i][1] - P[i - 1][1]); }
	const nearX = q => X.some(x => Math.hypot(q[0] - x[0], q[1] - x[1]) < 2 * wf);
	let minSep = 1e9;
	for (let i = 0; i < n; i += 2) {
		if (nearX(P[i])) { continue; }
		for (let j = i + 1; j < n; j += 2) {
			if (cum[j] - cum[i] < 3 * wf || nearX(P[j])) { continue; }
			const d = Math.hypot(P[i][0] - P[j][0], P[i][1] - P[j][1]); if (d < minSep) { minSep = d; }
		}
	}
	return { hpX: Math.abs(X.length - 1), hpSlit: minSep < wf ? 1 : 0, crossings: X.length, minSep: +minSep.toFixed(4), wf: +wf.toFixed(4) };
}
// V5 -- the end tile's outer wrap (the C around the end). Ash's C is convex all the way round; a stretch
// curving the other way reads as a dent (the committed 'ash-hairpin' wrap had one on its outer face, at
// U ~0.35). wrapCurv: curvature (1/tile units) of the wrap resampled at TILE_DS, over the C (U < WRAP_U,
// away from the port S-bends). wrapDent = sign changes of that curvature beyond +-WRAP_KTHR -- a gate count
// (0 for a clean C). fairWrap flattens only the wrong-sign stretches (local Laplacian smoothing under a
// bump weight, ends pinned) until none is left, so the rest of the traced C is untouched.
const WRAP_U = 1.0, WRAP_KTHR = 0.5;
function wrapPath(tile) { return tile && tile.paths && tile.paths.find(p => p.id === (tile.outer || 'wrap')); }
function pairsOf(flat) { const P = []; for (let i = 0; i + 1 < flat.length; i += 2) { P.push([flat[i], flat[i + 1]]); } return P; }
function wrapCurv(R) {
	const k = new Float64Array(R.length);
	for (let i = 2; i < R.length - 2; i++) {
		const a = Math.atan2(R[i][1] - R[i - 2][1], R[i][0] - R[i - 2][0]), b = Math.atan2(R[i + 2][1] - R[i][1], R[i + 2][0] - R[i][0]);
		let d = b - a; while (d > Math.PI) { d -= 2 * Math.PI; } while (d < -Math.PI) { d += 2 * Math.PI; }
		const l = Math.hypot(R[i + 2][0] - R[i - 2][0], R[i + 2][1] - R[i - 2][1]) / 2 || 1e-9;
		k[i] = d / l;
	}
	return k;
}
function wrapChecks(tile) {
	const pa = wrapPath(tile); if (!pa) { return null; }
	const R = resampleUniform(pairsOf(pa.pts), TILE_DS), k = wrapCurv(R);
	let main = 0; for (let i = 0; i < R.length; i++) { if (R[i][0] < WRAP_U) { main += k[i]; } }
	const sg = main >= 0 ? 1 : -1;
	let ch = 0, last = 0, minK = Infinity;
	for (let i = 2; i < R.length - 2; i++) {
		if (R[i][0] >= WRAP_U) { last = 0; continue; }
		const v = k[i] * sg; minK = Math.min(minK, v);
		const s2 = v > WRAP_KTHR ? 1 : v < -WRAP_KTHR ? -1 : 0;
		if (s2 && last && s2 !== last) { ch++; }
		if (s2) { last = s2; }
	}
	return { wrapDent: ch, minCurv: +minK.toFixed(3) };
}
// V6 -- squared wrap corners (--wrapSquare, end / joint stages). Ash's outer C is a squared U (straight top and
// bottom legs, a near-straight back, tight corners); the traced wrap is rounder. squareWrap(pts, a) blends the BACK
// of the C toward its bounding half-rectangle ALONG RAYS from a centre half a C-height in from the back:
// r' = r + a * w * (R_rect - r), R_rect = the ray's distance to the rectangle (back U = u0, legs V = v0 / v1).
// a = 0 is the identity, a = 1 puts the back on the rectangle (square corners); stretches already on the
// rectangle (a flat back, straight legs) stay put, so -- unlike a superellipse push, which bowed a flat back
// inward (wrapDent) -- the blend only tightens the corners. w fades the push in over the first half-height
// behind the centre, so the legs, ports and S-bends ahead of it never move. reach (wq.reach, band units) also
// moves the back further into the break by that much (visual review 1: Ash's D reaches ~0.4 band further).
function squareWrap(pts, a, reach, ab, low) {
	reach = +reach || 0;
	const hasB = ab != null || low != null;   // V11 wq.b / wq.low (--wrapSquareB); absent = the V6 rule exactly
	if (!(a > 1e-4) && !reach && !(hasB && ((ab > 1e-4) || Math.abs(low || 0) > 1e-6))) { return pts; }
	const C = pts.filter(q => q[0] < WRAP_U); if (C.length < 4) { return pts; }
	let u0 = Infinity, v0 = Infinity, v1 = -Infinity; C.forEach(q => { u0 = Math.min(u0, q[0]); v0 = Math.min(v0, q[1]); v1 = Math.max(v1, q[1]); });
	const h = (v1 - v0) / 2, vc = (v0 + v1) / 2, uc = u0 + h;
	if (!(h > 1e-6)) { return pts; }
	return pts.map(q => {
		const x = (q[0] - uc) / h, y = (q[1] - vc) / h, r = Math.hypot(x, y);
		if (x >= 0 || r < 1e-9 || q[0] >= WRAP_U) { return q; }
		const cx = x / r, cy = y / r, R = Math.min(1 / Math.abs(cx), Math.abs(cy) > 1e-9 ? 1 / Math.abs(cy) : Infinity);
		const t = Math.min(1, -x / 0.5), w = t * t * (3 - 2 * t), aa = hasB && y > 0 && ab != null ? ab : a, r2 = r + (aa || 0) * w * (R - r);
		// reach (band): the back of the C moves this far further into the break (smaller U), legs easing in
		// V11 low: the C's lower half (y > 0, the bottom-outer face) moves outward by low x its own height share, back first
		const ly = hasB && low && y > 0 ? 1 + low * w : 1;
		return [uc + cx * r2 * h - reach * w, vc + cy * r2 * h * ly];
	});
}
// V7 --cornerSquare (visual review 1, corner items 1-2: Ash's outer L and nested L are crisp square corners with
// straight legs; ours are rounded, the top leg wavy, the nested one a round loop). squareCorner works on one corner-
// tile path (band units, TL frame: x along the top run, y down the left run), by where its innermost point (smallest
// x + y, the apex) lies:
//   OUTER L (apex x + y < SQ_OUTER): the stretch that turns the corner -- from where it comes within LEG_W of the left
//     side to where it leaves the top one -- is pulled onto x = xL (left leg) or y = yT (top leg), the legs' median
//     lines, whichever side of the corner's diagonal a point is on, easing in and out over SQ_EASE band of arc: straight
//     legs, a square corner. Weight a.
//   NESTED bight (apex x + y < SQ_NESTED): only its nose -- points within NOSE of the nose's own bounding lines -- is
//     pulled onto those two lines (a square nose; its diagonal legs stay as they are). Weight b.
//   anything else (a strand crossing the corner on a diagonal) is left alone.
// a, b = 0: identity; 1: a sharp L (the kink gate keeps them below where the turn breaks G1). Containment is the gate's
// job (inkOut), not bending.
const SQ_OUTER = 0.6, SQ_NESTED = 1.0, LEG_W = 0.25, SQ_EASE = 0.25, NOSE = 0.3;
function squareCorner(pts, a, b) {
	if (!((a > 1e-4) || (b > 1e-4)) || pts.length < 8) { return pts; }
	let i0 = -1; pts.forEach((q, i) => { if (q[0] < 1 && q[1] < 1 && (i0 < 0 || q[0] + q[1] < pts[i0][0] + pts[i0][1])) { i0 = i; } });
	if (i0 < 0) { return pts; }
	const ap = pts[i0], sum = ap[0] + ap[1];
	const ease = t => { t = Math.min(1, Math.max(0, t)); return t * t * (3 - 2 * t); };
	if (sum < SQ_OUTER && a > 1e-4) {
		const walk = (dir, inLeg) => { let i = i0; while (i + dir >= 0 && i + dir < pts.length && inLeg(pts[i + dir])) { i += dir; } return i; };
		const k = Math.min(pts.length - 1, i0 + 5), dirL = (pts[k][1] - ap[1]) > (pts[k][0] - ap[0]) ? 1 : -1;
		const iL = walk(dirL, q => q[0] < ap[0] + LEG_W), iT = walk(-dirL, q => q[1] < ap[1] + LEG_W), lo = Math.min(iL, iT), hi = Math.max(iL, iT);
		if (hi - lo < 6) { return pts; }
		const med = v => { const s2 = v.slice().sort((x, y) => x - y); return s2.length ? s2[s2.length >> 1] : null; };
		const seg = (from, to) => pts.slice(Math.min(from, to), Math.max(from, to) + 1);
		const xL = med(seg(i0, iL).filter(q => q[1] > ap[1] + 0.1).map(q => q[0])), yT = med(seg(i0, iT).filter(q => q[0] > ap[0] + 0.1).map(q => q[1]));
		if (xL == null || yT == null) { return pts; }
		const cum = [0]; for (let i = 1; i < pts.length; i++) { cum[i] = cum[i - 1] + Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]); }
		return pts.map((q, i) => {
			if (i < lo || i > hi) { return q; }
			const w = a * ease(Math.min(cum[i] - cum[lo], cum[hi] - cum[i]) / SQ_EASE);
			const tg = (q[1] - yT) >= (q[0] - xL) ? [xL, Math.max(q[1], yT)] : [Math.max(q[0], xL), yT];
			return [q[0] + w * (tg[0] - q[0]), q[1] + w * (tg[1] - q[1])];
		});
	}
	if (sum >= SQ_OUTER && sum < SQ_NESTED && b > 1e-4) {
		const near = pts.filter(q => Math.hypot(q[0] - ap[0], q[1] - ap[1]) < 1.5 * NOSE);
		const x0 = Math.min.apply(null, near.map(q => q[0])), y0 = Math.min.apply(null, near.map(q => q[1]));
		return pts.map(q => {
			const dx = q[0] - x0, dy = q[1] - y0;
			if (dx > NOSE || dy > NOSE) { return q; }
			const w = b * ease(1 - Math.max(dx, dy) / NOSE), tg = dy >= dx ? [x0, q[1]] : [q[0], y0];
			return [q[0] + w * (tg[0] - q[0]), q[1] + w * (tg[1] - q[1])];
		});
	}
	return pts;
}
// V11 --nestedL (visual reviews 5-6, V11 goal 1: Ash's nested L is a true L -- a vertical left leg, a square corner, a
// straight top leg -- where ours curls round). squareNested works on the corner tile's NESTED path (squareCorner's rule:
// apex x + y in [SQ_OUTER, SQ_NESTED)), TL frame, band units. From the apex it walks down the leg side (y grows) until
// y >= nl.b and along the top side (x grows) until x >= nl.r; every point between is pulled onto the L x = nl.x (left
// leg, below the corner) / y = nl.y (top leg), whichever side of the L's own diagonal it lies on -- one true corner vertex
// at (nl.x, nl.y) -- with weight nl.a easing in over nl.e band of arc at both ends (the diagonal lead-in below the leg, the
// dive under the bar after the top leg). Start values measured on Ash's raster (meas.cjs, V11): left leg centre 0.36,
// top leg centre 0.32, the leg turns diagonal at ~0.55, the top leg's face at ~0.58 (Ash band units from his outer ink edge).
const NL_ASH = { x: 0.37, y: 0.37, b: 0.58, r: 0.58, e: 0.12 };   // in our tile frame (Ash's band 74 px vs ours ~78, insets 29 / 25 px)
function isNestedL(q) { let m = Infinity; q.forEach(p => { if (p[0] < 1 && p[1] < 1) { m = Math.min(m, p[0] + p[1]); } }); return m >= SQ_OUTER && m < SQ_NESTED; }
function squareNested(pts, nl) {
	if (!(nl && nl.a > 1e-4) || pts.length < 8) { return pts; }
	let i0 = -1; pts.forEach((q, i) => { if (q[0] < 1 && q[1] < 1 && (i0 < 0 || q[0] + q[1] < pts[i0][0] + pts[i0][1])) { i0 = i; } });
	if (i0 < 0) { return pts; }
	const k = Math.min(pts.length - 1, i0 + 5), k2 = Math.max(0, i0 - 5);
	const dirL = (pts[k][1] - pts[k][0]) > (pts[k2][1] - pts[k2][0]) ? 1 : -1;   // the side whose points run down the leg
	let iL = i0; while (iL + dirL >= 0 && iL + dirL < pts.length && pts[iL][1] < nl.b) { iL += dirL; }
	let iT = i0; while (iT - dirL >= 0 && iT - dirL < pts.length && pts[iT][0] < nl.r) { iT -= dirL; }
	const lo = Math.min(iL, iT), hi = Math.max(iL, iT);
	if (hi - lo < 4) { return pts; }
	const cum = [0]; for (let i = 1; i < pts.length; i++) { cum[i] = cum[i - 1] + Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]); }
	const E = Math.max(1e-3, nl.e), ease = t => { t = Math.min(1, Math.max(0, t)); return t * t * (3 - 2 * t); };
	return pts.map((q, i) => {
		if (i < lo || i > hi) { return q; }
		const w = nl.a * ease(Math.min(cum[i] - cum[lo], cum[hi] - cum[i]) / E);
		const tg = (q[1] - nl.y) >= (q[0] - nl.x) ? [nl.x, Math.max(q[1], nl.y)] : [Math.max(q[0], nl.x), nl.y];
		return [q[0] + w * (tg[0] - q[0]), q[1] + w * (tg[1] - q[1])];
	});
}
// V8 trace fit (--traceEnd / --traceCorner <trace.json from trace-corner.cjs>; visual review 2, end items 2-3 and
// corner item 3: redraw from Ash's traced outline instead of deforming ours). Ash's strand centrelines (his raster's
// skeleton, gaps bridged under his over strands) are the target: each tile point moves toward the nearest traced
// point OF ITS OWN COLOUR by a * env(p) * exp(-(d / TF_SIGMA)^2) -- a strand already near one of his strands snaps onto
// it (a crescent straightens into his bar, a round C squares onto his D, a hooked nested bight onto his L); one far
// from any of his (d >> sigma, e.g. a strand his drawing does not have) stays where it is. The displacement field is
// then smoothed along the path (TF_SMOOTH passes, +-TF_WIN points), so a nearest-point jump between two traced chains
// never kinks the strand. env fades the pull out toward the ports (they stay on the live braid: G1 joins unchanged).
// Frames: corner traces are in the corner tile's own TL frame (trace-corner.cjs built ash-traced from them). End
// traces measure U from Ash's break ink edge, so the tile frame is found by matching Ash's strands at the port line
// to the tile's own ports (traceFrameEnd: the U offset du0 whose crossing heights fit the four port heights best);
// tf.du / tf.dv (searched) refine it, tf.a sets the strength.
const TF_SIGMA = 0.22, TF_WIN = 4, TF_SMOOTH = 3, TF_CSM = 4;
function traceChains(file, cls) {
	const T = JSON.parse(fs.readFileSync(file, 'utf8'));
	// a raster skeleton wobbles by a pixel (~0.014 band): resample, then a +-TF_CSM-point moving average (3 passes),
	// so a redrawn wrap carries his shape, not his pixel steps (the wrapDent gate counts curvature sign changes)
	const sm = P => { let p = P; for (let r = 0; r < 3; r++) { p = p.map((q, i) => { if (i === 0 || i === p.length - 1) { return q; } let sx = 0, sy = 0, k = 0; for (let j = Math.max(0, i - TF_CSM); j <= Math.min(p.length - 1, i + TF_CSM); j++) { sx += p[j][0]; sy += p[j][1]; k++; } return [sx / k, sy / k]; }); } return p; };
	return (T.chains || []).filter(c => c.pts && c.pts.length > 3).map(c => ({ cls: c.cls, pts: sm(resampleUniform(c.pts, TILE_DS)).map(q => [+q[0].toFixed(4), +q[1].toFixed(4)]) }));
}
function nearestOn(chains, cls, x, y) {
	let bd = Infinity, bq = null;
	chains.forEach(c => {
		if (cls != null && c.cls !== cls) { return; }
		const P = c.pts;
		for (let i = 1; i < P.length; i++) {
			const ax = P[i - 1][0], ay = P[i - 1][1], dx = P[i][0] - ax, dy = P[i][1] - ay, L2 = dx * dx + dy * dy || 1e-12;
			const t = Math.max(0, Math.min(1, ((x - ax) * dx + (y - ay) * dy) / L2)), qx = ax + t * dx, qy = ay + t * dy, d = (qx - x) ** 2 + (qy - y) ** 2;
			if (d < bd) { bd = d; bq = [qx, qy]; }
		}
	});
	return bq ? { q: bq, d: Math.sqrt(bd) } : null;
}
function traceFit(pts, chains, cls, a, env, off) {
	if (!(a > 1e-4) || !chains || !chains.length || pts.length < 3) { return pts; }
	const ox = off ? off[0] : 0, oy = off ? off[1] : 0, n = pts.length;
	let D = pts.map(p => {
		const e = env(p); if (!(e > 0)) { return [0, 0]; }
		const m = nearestOn(chains, cls, p[0] - ox, p[1] - oy); if (!m) { return [0, 0]; }
		const w = a * e * Math.exp(-((m.d / TF_SIGMA) ** 2));
		return [w * (m.q[0] + ox - p[0]), w * (m.q[1] + oy - p[1])];
	});
	for (let it = 0; it < TF_SMOOTH; it++) {
		D = D.map((d, i) => { let sx = 0, sy = 0, k = 0; for (let j = Math.max(0, i - TF_WIN); j <= Math.min(n - 1, i + TF_WIN); j++) { sx += D[j][0]; sy += D[j][1]; k++; } return [sx / k, sy / k]; });
	}
	return pts.map((p, i) => { const e = env(p); return e > 0 ? [p[0] + D[i][0] * Math.min(1, e / 0.25), p[1] + D[i][1] * Math.min(1, e / 0.25)] : p; });
}
// End wrap: REDRAW, not pull. Nearest-point pulls cannot square a corner (points near a round corner project onto the
// legs), so the C is redrawn by arc-length correspondence: the wrap's stretch behind U = TR_CUT (the C, between its two
// legs) and Ash's traced C (his chain of the same colour that reaches deepest into the break, shifted by the tile frame
// offset, same stretch) are both parametrised by normalised arc length, and p(s) = ours(s) + a w(s) (ash(s) - ours(s)),
// with w easing 0 -> 1 over the first and last TR_EASE of the stretch so the joins to the legs (and the ports beyond)
// stay continuous. a = 1 takes Ash's C exactly: his flat back, square top-outer corner and reach.
const TR_CUT = 1.0, TR_EASE = 0.08;
function arcParam(P) { const c = [0]; for (let i = 1; i < P.length; i++) { c[i] = c[i - 1] + Math.hypot(P[i][0] - P[i - 1][0], P[i][1] - P[i - 1][1]); } return c; }
function atArc(P, cum, t) {
	const L = cum[cum.length - 1] * t; let k = 1; while (k < P.length - 1 && cum[k] < L) { k++; }
	const f = (L - cum[k - 1]) / ((cum[k] - cum[k - 1]) || 1); return [P[k - 1][0] + (P[k][0] - P[k - 1][0]) * f, P[k - 1][1] + (P[k][1] - P[k - 1][1]) * f];
}
function deepRange(P, cut) {         // contiguous index range with U < cut around the deepest (smallest U) point
	let m = 0; P.forEach((q, i) => { if (q[0] < P[m][0]) { m = i; } });
	if (!(P[m][0] < cut)) { return null; }
	let i0 = m, i1 = m; while (i0 > 0 && P[i0 - 1][0] < cut) { i0--; } while (i1 < P.length - 1 && P[i1 + 1][0] < cut) { i1++; }
	return [i0, i1];
}
function traceRedraw(pts, chains, cls, a, off, cut) {
	cut = cut || TR_CUT;
	if (!(a > 1e-4) || !chains || pts.length < 8) { return pts; }
	const ox = off ? off[0] : 0, oy = off ? off[1] : 0;
	let ch = null; chains.forEach(c => { if (c.cls !== cls) { return; } const m = Math.min.apply(null, c.pts.map(q => q[0])); if (!ch || m < ch.m) { ch = { m, pts: c.pts.map(q => [q[0] + ox, q[1] + oy]) }; } });
	if (!ch) { return pts; }
	const ro = deepRange(pts, cut), ra = deepRange(ch.pts, cut); if (!ro || !ra || ro[1] - ro[0] < 8 || ra[1] - ra[0] < 8) { return pts; }
	const O = pts.slice(ro[0], ro[1] + 1); let A = ch.pts.slice(ra[0], ra[1] + 1);
	// same direction of travel: our stretch's first end is nearer which of his ends (by V: the legs are top / bottom)
	if (Math.abs(A[0][1] - O[0][1]) > Math.abs(A[A.length - 1][1] - O[0][1])) { A = A.reverse(); }
	// his stretch is first sheared so its two ends land on ours (minus a linear share of each end's offset), so the
	// joins are continuous without a long S-shaped easing (which put curvature dents into the C)
	const co = arcParam(O), ca = arcParam(A), n = O.length, out = pts.slice();
	const d0 = [A[0][0] - O[0][0], A[0][1] - O[0][1]], d1 = [A[A.length - 1][0] - O[n - 1][0], A[A.length - 1][1] - O[n - 1][1]];
	for (let i = 0; i < n; i++) {
		const t = co[i] / (co[n - 1] || 1), e = Math.min(t, 1 - t) / TR_EASE, w = a * smoothstep(e), q0 = atArc(A, ca, t);
		const q = [q0[0] - (1 - t) * d0[0] - t * d1[0], q0[1] - (1 - t) * d0[1] - t * d1[1]];
		out[ro[0] + i] = [O[i][0] + w * (q[0] - O[i][0]), O[i][1] + w * (q[1] - O[i][1])];
	}
	return out;
}
const smoothstep = t => { t = Math.min(1, Math.max(0, t)); return t * t * (3 - 2 * t); };
// end tile: full pull below U = portU - 0.6, none within 0.15 band of the port line
const tfEnvEnd = portU => p => 1 - smoothstep((p[0] - (portU - 0.6)) / 0.45);
// corner tile (arm A): full pull in the corner, none within 0.2 band of either port line
const tfEnvCorner = arm => p => 1 - smoothstep((Math.max(p[0], p[1]) - (arm - 0.65)) / 0.45);
// colour class (scorer classes: 2 = palette colour 0, 3 = colour 1) a tile path is painted in
function tfClassEnd(tile, p, cfg) {
	const c0 = cfg.endColor != null ? cfg.endColor % 2 : 0;
	return 2 + (p.id === (tile.outer || 'wrap') ? c0 : 1 - c0);
}
function tfClassCorner(p, cfg) { return 2 + (((p.c | 0) + ((cfg && cfg.cornerColor) | 0)) % 2); }
// the end trace's U offset: Ash's chains cut at the port line (U_ash = portU - du) give strand heights; du0 is the
// offset whose heights (and slopes) best match the tile's four port heights, searched within +-0.6 band of the C's
// own alignment (the D's back on the wrap's back)
function traceFrameEnd(tile, chains) {
	const ports = [];
	tile.paths.forEach(p => { const P = pairsOf(p.pts); if (p.a === 'port') { ports.push(P[0][1]); } if (p.b === 'port') { ports.push(P[P.length - 1][1]); } });
	ports.sort((x, y) => x - y);
	const heights = U => { const hs = []; chains.forEach(c => { for (let i = 1; i < c.pts.length; i++) { const a = c.pts[i - 1], b = c.pts[i]; if ((a[0] - U) * (b[0] - U) <= 0 && a[0] !== b[0]) { hs.push(a[1] + (b[1] - a[1]) * (U - a[0]) / (b[0] - a[0])); } } }); return hs.sort((x, y) => x - y); };
	const W = wrapPath(tile), wU = W ? Math.min.apply(null, pairsOf(W.pts).map(q => q[0])) : 0;
	const cU = Math.min.apply(null, chains.map(c => Math.min.apply(null, c.pts.map(q => q[0])))), g = wU - cU;
	let best = null;
	for (let du = g - 0.6; du <= g + 0.6 + 1e-9; du += 0.005) {
		const hs = heights(tile.portU - du); if (hs.length < ports.length) { continue; }
		// each port to its nearest traced height
		const cost = ports.reduce((acc, v) => acc + Math.min.apply(null, hs.map(h => Math.abs(h - v))), 0) / ports.length + 0.02 * Math.abs(du - g);
		if (!best || cost < best.cost) { best = { du: +du.toFixed(4), cost: +cost.toFixed(4) }; }
	}
	return best ? Object.assign(best, { back: +g.toFixed(4) }) : { du: g, cost: null, back: +g.toFixed(4) };
}
function fairWrap(tile0, maxIter) {
	const tile = JSON.parse(JSON.stringify(tile0)), pa = wrapPath(tile); if (!pa) { return { tile, iters: 0 }; }
	const R = resampleUniform(pairsOf(pa.pts), TILE_DS), n = R.length, Wn = Math.round(0.3 / TILE_DS);
	let it = 0;
	for (; it < (maxIter || 2000); it++) {
		const k = wrapCurv(R);
		let main = 0; for (let i = 0; i < n; i++) { if (R[i][0] < WRAP_U) { main += k[i]; } }
		const sg = main >= 0 ? 1 : -1, w = new Float64Array(n);
		let any = false;
		for (let i = 2; i < n - 2; i++) {
			if (R[i][0] >= WRAP_U || k[i] * sg >= -WRAP_KTHR / 4) { continue; }   // fair past the gate's threshold (resampling noise)
			any = true;
			for (let j = Math.max(1, i - Wn); j <= Math.min(n - 2, i + Wn); j++) { w[j] = Math.max(w[j], 0.5 * (1 + Math.cos(Math.PI * (j - i) / (Wn + 1)))); }
		}
		if (!any) { break; }
		const prev = R.map(q => q.slice());
		for (let i = 1; i < n - 1; i++) { if (w[i] > 0) { R[i][0] += 0.5 * w[i] * ((prev[i - 1][0] + prev[i + 1][0]) / 2 - prev[i][0]); R[i][1] += 0.5 * w[i] * ((prev[i - 1][1] + prev[i + 1][1]) / 2 - prev[i][1]); } }
	}
	pa.pts = [].concat.apply([], R.map(q => [+q[0].toFixed(4), +q[1].toFixed(4)]));
	return { tile, iters: it };
}
// V5 corner containment (same measure as the engine's tile test): inkOut = centreline points whose ink
// (half the inked width, fill + both outlines) reaches past the outer frame by more than half a px, per
// window; portGap = tile path ends that met their live braid port more than PORT_GAP band away before the
// G1 snap (the snap hides it, but a big jump bends the strand there). Both are gate counts.
const PORT_GAP = 0.03;
function cornerChecks(K, cfg, windows) {
	const hk = K.__km || {}, got = hk.got, G = K._geom;
	if (!got || !G.weaveW || !G.outlineW || !G.effCount) { return null; }
	const L = got.layout, s = RASTER_W / PAGE_W, b = L.band, ins = L.inset, W = L.W, H = L.H, nc = G.norm(cfg);
	const wf = G.weaveW(nc.pattern, b, G.effCount(nc), nc.strands), wOut = wf + 2 * G.outlineW(wf);
	const wins = Object.keys(windows).map(k => ({ k, b: windows[k].map(v => v / s) }));
	const inWin = (x, y) => wins.find(w => x >= w.b[0] && x <= w.b[2] && y >= w.b[1] && y <= w.b[3]);
	const res = {}; wins.forEach(w => { res[w.k] = { inkOut: 0, portGap: 0 }; });
	got.polys.forEach(p => p.pts.forEach(q => {
		const w = inWin(q[0], q[1]); if (!w) { return; }
		if (q[0] - wOut / 2 < ins - 0.5 || q[0] + wOut / 2 > W - ins + 0.5 || q[1] - wOut / 2 < ins - 0.5 || q[1] + wOut / 2 > H - ins + 0.5) { res[w.k].inkOut++; }
	}));
	let worst = 0;
	const dbg = got.spine && got.spine.tileDbg;
	((dbg && dbg.ports) || []).forEach(pt => { const w = inWin(pt.P[0], pt.P[1]); if (!w) { return; } worst = Math.max(worst, pt.gap); if (pt.gap > PORT_GAP) { res[w.k].portGap++; } });
	return { res, worstPortGap: +worst.toFixed(4), wOutBand: +(wOut / b).toFixed(4) };
}
// V5 gate on what is painted when strands.cutCurl is on: the cut runs with their curled ends, rebuilt from
// the engine's own pieces (underWindow -> splitByWindows -> curlCutEnd, as the engine test does) instead of
// the uncut centrelines checkGeometry reads. Per window: curlOut = curled-run points outside the band frame
// that the uncut run did not already have there; curlX = self-crossings of a curled run (a curl looping back
// over itself); curlKink = vertices of the curled stretch turning > KINK_DEG. Gate counts.
function curlChecks(K, cfg, windows) {
	const hk = K.__km || {}, got = hk.got, G = K._geom;
	if (!got || !G.cutCurlOf || !G.curlCutEnd || !G.splitByWindows || !G.underWindow || !G.weaveW) { return null; }
	const nc = G.norm(cfg), curl = G.cutCurlOf(nc); if (!curl) { return null; }
	const polys = got.polys, L = got.layout, band = L.band, s = RASTER_W / PAGE_W;
	const wf = G.weaveW(nc.pattern, band, G.effCount(nc), nc.strands), wOut = wf + 2 * G.outlineW(wf);
	const wins = Object.keys(windows).map(k => ({ k, b: windows[k].map(v => v / s) }));
	const inWin = (x, y) => wins.find(w => x >= w.b[0] && x <= w.b[2] && y >= w.b[1] && y <= w.b[3]);
	const res = {}; wins.forEach(w => { res[w.k] = { curlOut: 0, curlX: 0, curlKink: 0 }; });
	const tol = 0.03 * band, x0 = L.inset, y0 = L.inset, x1 = L.W - L.inset, y1 = L.H - L.inset;
	const outside = q => q[0] < x0 - tol || q[1] < y0 - tol || q[0] > x1 + tol || q[1] > y1 + tol || (q[0] > x0 + band + tol && q[0] < x1 - band - tol && q[1] > y0 + band + tol && q[1] < y1 - band - tol);
	const win = polys.map(() => []);
	(hk.cross || []).forEach(cr => { const w = G.underWindow(cr, polys, wf, wOut); if (w) { win[w.polyIdx].push({ idx: w.idx, frac: w.frac, halfLen: w.halfLen, over: G.overAtCrossing(cr, polys) }); } });
	const segX = P => { let k = 0; for (let i = 0; i + 1 < P.length; i++) { for (let j = i + 2; j + 1 < P.length; j++) { const d1 = [P[i + 1][0] - P[i][0], P[i + 1][1] - P[i][1]], d2 = [P[j + 1][0] - P[j][0], P[j + 1][1] - P[j][1]], den = d1[0] * d2[1] - d1[1] * d2[0]; if (Math.abs(den) < 1e-12) { continue; } const t = ((P[j][0] - P[i][0]) * d2[1] - (P[j][1] - P[i][1]) * d2[0]) / den, u = ((P[j][0] - P[i][0]) * d1[1] - (P[j][1] - P[i][1]) * d1[0]) / den; if (t > 1e-9 && t < 1 - 1e-9 && u > 1e-9 && u < 1 - 1e-9) { k++; } } } return k; };
	polys.forEach((p, i) => G.splitByWindows(p.pts, p.closed, win[i]).forEach(sp => {
		let P = sp.pts; const before = P;
		[['B', sp.overB, sp.cutB], ['A', sp.overA, sp.cutA]].forEach(([e, ov, isCut]) => {
			if (!isCut || !ov) { return; }
			const Q = e === 'B' ? P : P.slice().reverse(), R = G.curlCutEnd(Q, ov, wf, wOut, curl.k, curl.len);
			if (R === Q) { return; }
			let j = 0; while (j < R.length && j < Q.length && R[j][0] === Q[j][0] && R[j][1] === Q[j][1]) { j++; }
			const tip = R[R.length - 1], w = inWin(tip[0], tip[1]);
			if (w) {
				for (let k = Math.max(1, j); k < R.length - 1; k++) {
					const a = R[k - 1], q = R[k], c = R[k + 1], v1 = [q[0] - a[0], q[1] - a[1]], v2 = [c[0] - q[0], c[1] - q[1]], l1 = Math.hypot(v1[0], v1[1]), l2 = Math.hypot(v2[0], v2[1]);
					if (l1 < 0.01 * band || l2 < 0.01 * band) { continue; }
					if (Math.acos(Math.max(-1, Math.min(1, (v1[0] * v2[0] + v1[1] * v2[1]) / (l1 * l2)))) * 180 / Math.PI > KINK_DEG) { res[w.k].curlKink++; }
				}
			}
			P = e === 'B' ? R : R.slice().reverse();
		});
		if (P === before) { return; }
		const nb = before.filter(outside).length, na = P.filter(outside).length, m = P[P.length >> 1], w = inWin(m[0], m[1]) || inWin(P[0][0], P[0][1]) || inWin(P[P.length - 1][0], P[P.length - 1][1]);
		if (!w) { return; }
		if (na > nb) { res[w.k].curlOut += na - nb; }
		res[w.k].curlX += segX(P);
	}));
	return res;
}
// V6 fleck gate. The raster 'flecks' count (fill components of FLECK_MIN .. FLECK_FRAC*wf^2 px, ~6..19 px at the
// corner10 weights) stalled the corner stage: 8 -> 9..11 rejected most improvements. Geometry says those crumbs
// are not painted runs: on the corner10 best the shortest painted fill run inside the TL window is 14.6 page px
// (3.1 strand widths, ~169 raster px^2 -- km/v6dev/fleckgeo.cjs), nine times the gate's upper bound, so a
// 6..19 px component can only be an antialiasing crumb (4-connected edge pixels classed as fill) or a sliver of
// one fill peeking past another at a tangent fusion (no hole is cut below FUSION_SIN). Those move by +-1..3 with
// any sub-pixel change. So: the raster count may grow by FLECK_TOL (--fleckTol), and the real defect -- a
// painted fill run shorter than FLECK_RUN strand widths (a dot of colour boxed in ink) -- is counted from the
// engine's own cut runs ('fleckRuns', exact, strict).
const FLECK_TOL = 2, FLECK_RUN = 1.0;
let fleckTol = FLECK_TOL;
// V7 fleck gate decision (km/v7dev/fleckev.cjs): over 15 renders (corner 9/10/11 bests, end 10/11 bests, eight corner11
// squaring / recolouring variants) the raster count found 113 components of 6..18 px, every one nearest a painted fill
// run of >= 4.7 strand widths (none near a short run), while fleckRuns was 0 on all 15; the raster count swung 4..13
// with changes that move no run (squaring the outer L by a few hundredths of a band: 9 -> 11 -> 10). So the gate now
// uses fleckRuns only (exact, from the engine's cut runs); 'flecks' is still measured and reported as a diagnostic.
// --fleckGate raster restores the V6 rule (raster count within --fleckTol of the baseline, as well as fleckRuns).
let fleckGate = 'runs';
function fleckRuns(K, cfg, windows) {
	const hk = K.__km || {}, got = hk.got, G = K._geom;
	if (!got || !G.cutRuns || !G.weaveW) { return null; }
	const nc = G.norm(cfg), L = got.layout, b = L.band, s = RASTER_W / PAGE_W;
	const wf = G.weaveW(nc.pattern, b, G.effCount(nc), nc.strands), wOut = wf + 2 * G.outlineW(wf), ink = (wOut - wf) / 2;
	const runs = G.cutRuns(got.polys, wf, wOut, got.spine && got.spine.tile ? null : (G.cornerZoneFn ? G.cornerZoneFn(got.spine) : null), G.cutCurlOf ? G.cutCurlOf(nc) : null);
	const wins = Object.keys(windows).map(k => ({ k, b: windows[k].map(v => v / s) })), res = {};
	wins.forEach(w => { res[w.k] = 0; });
	runs.forEach(r => {
		if (r.closed) { return; }
		let len = 0; for (let i = 1; i < r.pts.length; i++) { len += Math.hypot(r.pts[i][0] - r.pts[i - 1][0], r.pts[i][1] - r.pts[i - 1][1]); }
		const fill = len - (r.cutA ? ink : 0) - (r.cutB ? ink : 0);
		if (fill <= 0 || fill >= FLECK_RUN * wf) { return; }   // <= 0: the painter drops it (no fill drawn)
		const m = r.pts[r.pts.length >> 1], w = wins.find(q => m[0] >= q.b[0] && m[0] <= q.b[2] && m[1] >= q.b[1] && m[1] <= q.b[3]);
		if (w) { res[w.k]++; }
	});
	return res;
}
// V8 --portGapTol n: the joint stage's corner port count may exceed the baseline's by n (a port that meets its live
// braid a little over PORT_GAP away is G1-snapped by the engine; a strict 0 froze the joint's corner phase search)
let portGapTol = 0;
// V9 --wrapDentTol d (band; off by default = V8's count rule). Visual check (km/v9dev/dent): around end14's best, 11.5% of
// sampled candidates (3.5% at sigma 0.003, 21.5% at 0.03) flip a curvature sign on the wrap, and the end14 round rejected
// 17 of them (one at 0.7526) -- yet at 6x zoom none shows a dent: their hull depth (wrapDepth: the farthest the C's
// points (U < WRAP_U) lie inside its own convex hull) is 0.27-0.81 raster px against the best's 0.41 (clean candidates up
// to 0.65). So the sign test fires on sub-pixel ripples. With the tolerance a sign change fails the gate only when the
// depth also grew by more than d; 0.012 band ~ 1 raster px ~ 2 px at 300 dpi.
let wrapDentTol = null;
// V12 --hold name[:floor],... / --sideFloor f (V12 goals 1-2: refit a tile or boost TL / top-L without trading the others):
// a would-be best must keep each held region's NOMINAL score (metric v2, scored on the gate's full-page map at
// HOLD_PTOL period tolerance -- the joint stage's side numbers) at or above min(floor, the baseline's own score) - holdTol;
// without a floor, no worse than the baseline - holdTol. Names: left, right, TL, top-L, cap. --sideFloor f = left:f,right:f.
// The held scores are in diag.checks.hold; the joint stage reads them off its own validate regions.
const HOLD_PTOL = 0.04, HOLD_NAMES = { left: 'side', right: 'side', TL: 'corner', 'top-L': 'end', cap: 'cap' };
const HOLD_JOINT = { left: 'side:left', right: 'side:right', TL: 'corner:TL', 'top-L': 'end:top-L', cap: 'end:cap' };
let holdSpec = null, holdTol = 0.003;
function parseHold(o) {
	const spec = {};
	if (o.hold && o.hold !== true) {
		String(o.hold).split(',').map(t => t.trim()).filter(Boolean).forEach(t => {
			const [k, f] = t.split(':'); if (!HOLD_NAMES[k]) { throw new Error('--hold: unknown region ' + k + ' (left, right, TL, top-L, cap)'); }
			spec[k] = f != null && f !== '' ? +f : null;
		});
	}
	if (o.sideFloor != null && o.sideFloor !== true) { spec.left = spec.right = +o.sideFloor; }
	if (o.holdTol != null && o.holdTol !== true) { holdTol = +o.holdTol; }
	return Object.keys(spec).length ? spec : null;
}
function holdRegions(names, m) { return names.map(k => (HOLD_NAMES[k] === 'cap' ? regionsFor('cap', m)[0] : regionsFor(HOLD_NAMES[k], m).find(r => r.name === k))); }
function holdFails(c, b) {
	if (!holdSpec || !c) { return []; }
	const bad = [];
	Object.keys(holdSpec).forEach(k => {
		const v = c[k], bv = b ? b[k] : null, f = holdSpec[k];
		if (v == null) { return; }
		const thr = f != null ? (bv != null ? Math.min(f, bv) : f) : bv;
		if (thr != null && v < thr - holdTol) { bad.push('hold ' + k + ' ' + v.toFixed(4) + '<' + thr.toFixed(4) + (holdTol ? '-' + holdTol : '')); }
	});
	return bad;
}
function wrapDepth(tile) {
	const pa = wrapPath(tile); if (!pa) { return null; }
	const P = pairsOf(pa.pts).filter(q => q[0] < WRAP_U); if (P.length < 3) { return 0; }
	const cr = (o, a, b) => (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0]), so = P.slice().sort((a, b) => a[0] - b[0] || a[1] - b[1]), lo = [], up = [];
	so.forEach(q => { while (lo.length >= 2 && cr(lo[lo.length - 2], lo[lo.length - 1], q) <= 0) { lo.pop(); } lo.push(q); });
	so.reverse().forEach(q => { while (up.length >= 2 && cr(up[up.length - 2], up[up.length - 1], q) <= 0) { up.pop(); } up.push(q); });
	const H = lo.slice(0, -1).concat(up.slice(0, -1));
	const sd = (q, a, b) => { const dx = b[0] - a[0], dy = b[1] - a[1], L = dx * dx + dy * dy, t = L ? Math.max(0, Math.min(1, ((q[0] - a[0]) * dx + (q[1] - a[1]) * dy) / L)) : 0; return Math.hypot(q[0] - a[0] - t * dx, q[1] - a[1] - t * dy); };
	let d = 0; P.forEach(q => { let m = Infinity; for (let i = 0; i < H.length; i++) { m = Math.min(m, sd(q, H[i], H[(i + 1) % H.length])); } d = Math.max(d, m); });
	return +d.toFixed(5);
}
function gateFails(diag, base) {                  // counts that got worse than the baseline's, at any position
	if (!diag || !diag.checks || !base || !base.checks) { return []; }
	const bad = [];
	Object.keys(diag.checks).forEach(k => {
		const c = diag.checks[k], b = base.checks[k] || {};
		if ((c.endFallback | 0) > 0) { bad.push(k + ' endFallback (fold caps, no end tile)'); }   // V8: absolute, whatever the baseline
		// V10 run stretch: absolute on the joint / weave pages (deliverables), else no worse than the baseline (stretchAbs)
		if (c.stretchDev) {
			const nc = stretchCount(c), nb = stretchCount(b);
			if (stretchAbs ? nc > 0 : nc > nb) { bad.push(k + ' runStretch ' + nc + (stretchAbs ? '' : '>' + nb) + ' (worst ' + c.worst + (c.at ? ' at s ' + c.at.s : '') + ', tol ' + stretchTol + ')'); }
		}
		if (k === 'hold') { holdFails(c, b).forEach(t => bad.push(t)); return; }   // V12 --hold
		if (fleckGate === 'raster' && (c.flecks | 0) > (b.flecks | 0) + fleckTol) { bad.push(k + ' flecks ' + (c.flecks | 0) + '>' + (b.flecks | 0) + '+' + fleckTol); }
		['kinks', 'outside', 'altBreaks', 'fleckRuns', 'hpX', 'hpSlit', 'wrapDent', 'inkOut', 'portGap', 'curlOut', 'curlX', 'curlKink'].forEach(t => {
			const tol = t === 'portGap' ? portGapTol : 0;
			if ((c[t] | 0) > (b[t] | 0) + tol) {
				// V9 --wrapDentTol d: a new curvature sign change counts only if the wrap's hull depth grew by more than d band
				if (t === 'wrapDent' && wrapDentTol != null && c.wrapDepth != null && b.wrapDepth != null && c.wrapDepth - b.wrapDepth <= wrapDentTol) { return; }
				bad.push(k + ' ' + t + ' ' + (c[t] | 0) + '>' + (b[t] | 0) + (tol ? '+' + tol : '') + (t === 'wrapDent' && c.wrapDepth != null ? ' (depth +' + (c.wrapDepth - (b.wrapDepth || 0)).toFixed(4) + ' band)' : ''));
			}
		});
	});
	return bad;
}

// ---------------------------------------------------------------- parameter spaces
// Every stage maps a vector in [0,1]^n (box-normalised) onto a cfg + engine overrides.
function lerpB(b, t) { return b[0] + (b[1] - b[0]) * Math.min(1, Math.max(0, t)); }
// smooth normal-displacement basis on a polyline; 'both' pins both ends with zero slope (keeps
// port joins G1), 'start' pins only the start (a free/tucked end may move)
function displace(pts, coefs, pin) {
	const n = pts.length; if (n < 3 || !coefs.length) { return pts; }
	const cum = [0];
	for (let i = 1; i < n; i++) { cum[i] = cum[i - 1] + Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]); }
	const L = cum[n - 1] || 1;
	return pts.map((p, i) => {
		const t = cum[i] / L, a = pts[Math.max(0, i - 1)], b = pts[Math.min(n - 1, i + 1)];
		let tx = b[0] - a[0], ty = b[1] - a[1]; const tl = Math.hypot(tx, ty) || 1; tx /= tl; ty /= tl;
		let d = 0;
		coefs.forEach((c, k) => {
			const env = pin === 'both' ? Math.sin(Math.PI * t) : (1 - Math.cos(Math.PI * t)) / 2;
			const mode = pin === 'both' ? Math.sin((k + 1) * Math.PI * t) : Math.cos(k * Math.PI * t);
			d += c * env * mode;
		});
		return [p[0] - ty * d, p[1] + tx * d];
	});
}
function samplePath(d) {        // corner tile 'd' (M/L/C) -> polyline, same maths as the engine's samplePathD
	const tok = String(d).match(/[MCLmcl]|-?\d*\.?\d+(?:e-?\d+)?/g) || []; let i = 0, cmd = 'M', cur = [0, 0]; const out = [];
	const n = () => +tok[i++];
	while (i < tok.length) {
		if (/[A-Za-z]/.test(tok[i])) { cmd = tok[i++].toUpperCase(); }
		if (cmd === 'M') { cur = [n(), n()]; out.push(cur.slice()); cmd = 'L'; }
		else if (cmd === 'L') { const q = [n(), n()]; for (let a = 1; a <= 8; a++) { out.push([cur[0] + (q[0] - cur[0]) * a / 8, cur[1] + (q[1] - cur[1]) * a / 8]); } cur = q; }
		else if (cmd === 'C') {
			const c1 = [n(), n()], c2 = [n(), n()], e = [n(), n()];
			for (let b = 1; b <= 12; b++) { const t = b / 12, mt = 1 - t; out.push([mt * mt * mt * cur[0] + 3 * mt * mt * t * c1[0] + 3 * mt * t * t * c2[0] + t * t * t * e[0], mt * mt * mt * cur[1] + 3 * mt * mt * t * c1[1] + 3 * mt * t * t * c2[1] + t * t * t * e[1]]); }
			cur = e;
		} else { i++; }
	}
	return out;
}
const toD = pts => 'M ' + pts.map(p => p[0].toFixed(4) + ' ' + p[1].toFixed(4)).join(' L ');
// uniform arc-length resampling (band units). Carrying a tile from pass to pass must not grow its
// point count: samplePath splits every L, so without this the path grew 8x per pass (and the engine
// rendered the bloated path differently).
function resampleUniform(pts, ds) {
	const cum = [0];
	for (let i = 1; i < pts.length; i++) { cum[i] = cum[i - 1] + Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]); }
	const L = cum[cum.length - 1], n = Math.max(2, Math.round(L / ds) + 1), out = [];
	let k = 1;
	for (let j = 0; j < n; j++) {
		const t = L * j / (n - 1);
		while (k < pts.length - 1 && cum[k] < t) { k++; }
		const a = pts[k - 1], b = pts[k], f = (t - cum[k - 1]) / ((cum[k] - cum[k - 1]) || 1);
		out.push([a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f]);
	}
	return out;
}
const TILE_DS = 0.02;

const WEAVE_SPACE = [
	{ key: 'band.width', b: [4.5, 7.5] }, { key: 'band.inset', b: [0.6, 2.6] },
	{ key: 'strands.thickness', b: [0.3, 0.7] }, { key: 'strands.angular', b: [0.6, 0.99] },
	{ key: 'strands.bow', b: [-1, 0] }, { key: 'strands.scale', b: [0.7, 1.25] },
	{ key: 'const.OUTLINE_RATIO', b: [0.3, 0.75] }, { key: 'const.GAP_RATIO', b: [0.3, 1.1] },
	// engine strands.cutCurl / cutCurlLen (v4 engines): cut ends curl in to meet the over strand head-on, like
	// Ash's unders. A cfg without them starts at the engine default (off); an older engine ignores them.
	{ key: 'strands.cutCurl', b: [0, 1], v0: 0 }, { key: 'strands.cutCurlLen', b: [0.5, 2.5], v0: 1.5 },
	// V5 engine strands.edgeBend: waveform w -> w + e(w - w^3) -- legs fill out toward the band edge (e > 0) or the
	// turns sharpen (e < 0); starts at 0 (off), an older engine ignores it
	{ key: 'strands.edgeBend', b: [-0.2, 0.2], v0: 0 }   // steep: +-0.1 costs the sides 0.03-0.05
];
const MODES = 6, AMP = 0.14;    // tile displacement: modes per path, max amplitude (band units)
// 2-D warp of the whole tile (all paths move together, so crossings slide along the arms and the nose
// can grow or shrink -- normal displacements alone cannot move a crossing). Field: sum over j,k < WMODES
// of a_jk cos(j pi x/X) cos(k pi y/Y) per axis, times an envelope that is 1 over most of the tile and
// eases to 0 (zero slope) at the port lines, so the joins to the live braid stay G1.
const WMODES = 3, WAMP = 0.3;
const wEnv = t => (t <= 0.6 ? 1 : t >= 1 ? 0 : 0.5 * (1 + Math.cos(Math.PI * (t - 0.6) / 0.4)));
function warpPts(pts, w, X, Y, cornerFrame) {
	if (!w || !Object.keys(w).length) { return pts; }
	return pts.map(([x, y]) => {
		const env = cornerFrame ? wEnv(Math.max(0, x) / X) * wEnv(Math.max(0, y) / Y) : wEnv(Math.max(0, x) / X);
		if (!(env > 0)) { return [x, y]; }
		let dx = 0, dy = 0;
		for (let j = 0; j < WMODES; j++) {
			for (let k = 0; k < WMODES; k++) {
				const b = Math.cos(j * Math.PI * x / X) * Math.cos(k * Math.PI * y / Y);
				dx += (w[j + '.' + k + '.x'] || 0) * b; dy += (w[j + '.' + k + '.y'] || 0) * b;
			}
		}
		return [x + env * dx, y + env * dy];
	});
}
function warpSpace(prefix) {
	const sp = [];
	for (let j = 0; j < WMODES; j++) { for (let k = 0; k < WMODES; k++) { ['x', 'y'].forEach(ax => { const a = WAMP / (1 + j + k); sp.push({ key: prefix + j + '.' + k + '.' + ax, b: [-a, a] }); }); } }
	return sp;
}
function spaceFor(stage, base) {
	// --only k1,k2 (base.only): search just these keys (exact names, or a prefix ending in '.'); the rest keep the cfg / init values
	const sp = spaceFor0(stage, base);
	return base.only ? sp.filter(s => base.only.some(k => s.key === k || (k.endsWith('.') && s.key.startsWith(k)))) : sp;
}
// V6 --inkMatch [fill:outline] (visual review 1, item 1: ours reads "more black"): Ash's strand at his 5100 px
// page width is 29 px of fill with 15 px of outline per side. The weave search drifted to heavier ink
// (weave11: OUTLINE_RATIO 0.574 -> 28.2 / 16.2 px) because ink IoU tolerates it. inkMatch pins OUTLINE_RATIO to
// Ash's outline / fill and narrows strands.thickness to Ash's fill +-1 px at the measured band (309 px at
// 5100: thickness = 4 x fill / band for plait-4), so only the shape is searched, not the ink balance.
const ASH_INK = { fill: 29, outline: 15, pageW: 5100, band: 309 };
// V8 --tipExt: + strands.tipExt / tipPow (engine wave(): arcs run on along the band edge before turning; 0 = off)
const TIP_SPACE = [{ key: 'strands.tipExt', b: [-0.3, 0.6], v0: 0 }, { key: 'strands.tipPow', b: [3, 16], v0: 6 }];
// V9 --slant [taper]: engine V9 painter -- strands.cutSlant (cut face turned toward parallel with the over strand's edge,
// drawn as filled polygons), cutSlantShift (face moved along its normal, steep); 'taper' adds cutTaper (colour narrowing
// at a slanted face; the variable-width prototype -- it measured worse at 0.3+). Weave / joint get them through the weave
// space; --slant on corner / end adds them plus strands.cutCurl (slant and curl compete: the best measured had curl 0).
const SLANT_SPACE = [{ key: 'strands.cutSlant', b: [0, 1], v0: 0 }, { key: 'strands.cutSlantShift', b: [-0.08, 0.12], v0: 0 }];
const TAPER_SPACE = [{ key: 'strands.cutTaper', b: [0, 0.4], v0: 0 }];
function slantSpace(base) { return !base || !base.slant ? [] : SLANT_SPACE.concat(base.slant === 'taper' ? TAPER_SPACE : []); }
// V10 --fillMode: engine strands.paint 'fill' (filled-outline painter, variable width): arc / bar body widths (x fill width),
// the arc's mid bulge, ink weights (x outline width) and the arc body's shift toward its convex side (fill widths).
// Starts at the neutral values (= the stroke render within ~0.001); a cfg's own values win on resume.
const FILL_SPACE = [{ key: 'strands.fillArcW', b: [0.8, 1.25], v0: 1 }, { key: 'strands.fillBarW', b: [0.8, 1.25], v0: 1 },
	{ key: 'strands.fillArcBulge', b: [-0.3, 0.3], v0: 0 }, { key: 'strands.fillInk', b: [0.8, 1.3], v0: 1 }, { key: 'strands.fillBarInk', b: [0.8, 1.3], v0: 1 },
	{ key: 'strands.fillArcOut', b: [-0.15, 0.1], v0: 0 }];
function fillSpace(base) { return base && base.fill ? FILL_SPACE : []; }
// V11 --legWeave (visual review 6, corner item 2; V11 goal 1 "then fit the legs"): the corner / end stages search the braid
// shape of their legs -- strand thickness (inkMatch-narrowed), angular, bow, scale, edgeBend, the ink and gap ratios (ink
// ratio not with --inkMatch) -- from the cfg's values. Without it they inherit whatever weave the cfg carries (corner16:
// angular 0.79 / bow -0.575 from corner13, against weave16's 0.60 / -0.571), and the legs are 61% of the TL box.
const LEG_WEAVE = ['strands.thickness', 'strands.angular', 'strands.bow', 'strands.scale', 'strands.edgeBend', 'const.OUTLINE_RATIO', 'const.GAP_RATIO'];
function legWeaveSpace(base) { return base && base.legWeave ? weaveSpace(base).filter(s => LEG_WEAVE.includes(s.key)) : []; }
// V11 --nestedL [a]: nl.a (strength; default 1 on a tile without a stored L, 0 = no-op on a resumed one, which carries
// its own L in tile.nl), nl.x / nl.y (the L's legs), nl.b (where the left leg turns diagonal), nl.r (top leg end), nl.e (ease)
function nlSpace(base) {
	const t = base.cornerTile || {}, s = t.nl || NL_ASH, a0 = base.nestedL !== true ? +base.nestedL : (t.nl ? 0 : 1);
	return [{ key: 'nl.a', b: [0, 1], v0: a0 }, { key: 'nl.x', b: [0.25, 0.5], v0: s.x }, { key: 'nl.y', b: [0.2, 0.45], v0: s.y },
		{ key: 'nl.b', b: [0.4, 0.9], v0: s.b }, { key: 'nl.r', b: [0.45, 0.85], v0: s.r }, { key: 'nl.e', b: [0.04, 0.3], v0: s.e }];
}
// V12 --fillField [end|corner|both] (engine knot-v12-engine cfg.fillField, fill painter): a width field in each tile's own
// frame -- fillField.<kind>.a<j><k>, j, k = 0..2, the cosine coefficients (a00 = the tile's mean width change); the
// engine applies it at all four positions. Starts at the cfg's values (0 = off; see km/v12dev fieldmeas.cjs for Ash's).
const FIELD_N = 3;
function fieldSpace(base, kind) {
	if (!base || !base.fillField || !(base.fillField === 'both' || base.fillField === kind)) { return []; }
	const sp = [];
	for (let j = 0; j < FIELD_N; j++) { for (let k = 0; k < FIELD_N; k++) { const a = 0.3 / (1 + (j + k) / 2); sp.push({ key: 'fillField.' + kind + '.a' + j + k, b: [-a, a], v0: 0 }); } }
	return sp;
}
function weaveSpace(base) {
	const sp0 = (base && base.tipExt ? WEAVE_SPACE.concat(TIP_SPACE) : WEAVE_SPACE).concat(slantSpace(base), fillSpace(base));
	if (!base || !base.inkMatch) { return sp0; }
	const f = base.inkMatch.fill, th = f * 4 / ASH_INK.band;
	return sp0.filter(s => s.key !== 'const.OUTLINE_RATIO').map(s => s.key === 'strands.thickness' ? { key: s.key, b: [th - 4 / ASH_INK.band, th + 4 / ASH_INK.band] } : s);
}
function spaceFor0(stage, base) {
	if (stage === 'weave') { return weaveSpace(base); }
	if (stage === 'joint') {
		// the shared weave settings + the break and tile placement (phase / repeat / fold controls); the tiles' own
		// shape modes only with --jointTiles (100+ dimensions otherwise -- refine shapes in the single stages)
		const keep = s => base.jointTiles || /^(brk\.|etp\.|hp\.|ex\.|ctp\.|csq\.|wq\.|tf\.|tc\.)/.test(s.key) || s.key === 'endBlend';
		// V6 single engine: endSlide decides who absorbs a corner's phase error -- the end tile (slides along the
		// break) or the braid between them (stretches); searched from the cfg's value (default 0)
		const slide = base.singleEngine ? [{ key: 'endSlide', b: [0, 1], v0: 0 }] : [];
		// V7 --searchRepeat (single engine, without --repeatPx): the run's repeat (cfg.repeatLam, lam/band) is searched --
		// the corner tile and the end were fitted at ~188 px (2.42-2.46 band), not at the sides' 181 px (see v7CfgFlags)
		if (base.singleEngine && base.searchRepeat) { slide.push({ key: 'repeatLam', b: [2.2, 2.7], v0: 2.33 }); }
		const isF = s => s.key.startsWith('fillField.');   // V12: the tile width fields join the joint space without --jointTiles
		return weaveSpace(base).concat(slide, spaceFor0('end', base).filter(s => keep(s) && !isF(s)), spaceFor0('corner', base).filter(s => keep(s) && !isF(s)), fieldSpace(base, 'end'), fieldSpace(base, 'corner'));
	}
	if (stage === 'corner') {
		const t = base.cornerTile, sp = [{ key: 'ctp.phase', b: [0, 1] }, { key: 'ctp.lam', b: [1.9, 2.7] }];
		// per-port phase (engine tile.phaseIn): searched within half a repeat of the starting value
		if (t.phaseIn != null) { sp.push({ key: 'ctp.phaseIn', b: [t.phaseIn - 0.5, t.phaseIn + 0.5] }); }
		if (base.cornerSquare) { sp.push({ key: 'csq.a', b: [0, 1], v0: 0 }, { key: 'csq.b', b: [0, 1], v0: 0 }); }   // V7: square the outer L / nested nose (squareCorner)
		if (base.nestedL) { nlSpace(base).forEach(q => sp.push(q)); }   // V11 --nestedL (squareNested)
		if (base.traceCorner) { sp.push({ key: 'tc.a', b: [0, 1], v0: base.tcStart != null ? base.tcStart : 0 }); }   // V8 --traceCorner (traceFit)
		if (base.slant) { slantSpace(base).concat([WEAVE_SPACE.find(q => q.key === 'strands.cutCurl')]).forEach(q => sp.push(q)); }   // V9 --slant
		fillSpace(base).forEach(q => sp.push(q));   // V10 --fillMode
		legWeaveSpace(base).forEach(q => sp.push(q));   // V11 --legWeave
		fieldSpace(base, 'corner').forEach(q => sp.push(q));   // V12 --fillField
		t.paths.forEach((p, pi) => { for (let k = 0; k < MODES; k++) { sp.push({ key: 'ct.' + pi + '.' + k, b: [-AMP / (k + 1), AMP / (k + 1)] }); } });
		return base.warp === false ? sp : sp.concat(warpSpace('cw.'));
	}
	if (stage === 'end') {
		// tieBreaks (set with --primary): the bottom break copies the top one, so the one piece being
		// optimised is the piece drawn at every break end
		const t = base.endTile, sp = base.tieBreaks ? [{ key: 'brk.top', b: [12, 24] }, { key: 'brk.topAt', b: [46, 54] }, { key: 'etp.lam', b: [2.0, 2.8] }]
			: [{ key: 'brk.top', b: [12, 24] }, { key: 'brk.bot', b: [12, 26] }, { key: 'brk.topAt', b: [46, 54] }, { key: 'brk.botAt', b: [46, 54] }, { key: 'etp.lam', b: [2.0, 2.8] }];
		// a hairpin tile concentrates the freedom on the fold: more modes on the hairpin path, fewer on the
		// outer wrap, plus direct fold controls (HAIRPIN_SPACE) and local bumps along the fold (hb.k)
		const hairpin = t.paths.some(p => p.id === 'hairpin');
		t.paths.forEach((p, pi) => { const nm = !hairpin ? MODES : p.id === 'hairpin' ? HP_MODES : (base.wrapModes != null ? base.wrapModes : 4); for (let k = 0; k < nm; k++) { sp.push({ key: 'et.' + pi + '.' + k, b: [-AMP / (k + 1), AMP / (k + 1)] }); } });
		if (hairpin) { HAIRPIN_SPACE.forEach(h => sp.push(h)); for (let k = 0; k < HP_BUMPS; k++) { sp.push({ key: 'hb.' + k, b: [-HP_BAMP, HP_BAMP] }); } }
		if (base.wrapSquare) { sp.push({ key: 'wq.a', b: [0, 1], v0: 0 }, { key: 'wq.reach', b: [-0.1, 0.6], v0: 0 }); }   // V6 squared, deeper wrap (squareWrap)
		// V11 --wrapSquareB (visual review 6, end item 1): the C's bottom-outer corner squared on its own (wq.b, from wq.a's
		// value) and its lower face widened (wq.low)
		if (base.wrapSquare && base.wrapSquareB) { sp.push({ key: 'wq.b', b: [0, 1], v0: 0 }, { key: 'wq.low', b: [-0.1, 0.25], v0: 0 }); }
		// V8 --traceEnd: pull the tile onto Ash's traced end (traceFit; tf.a strength, tf.du / tf.dv frame refinement)
		if (base.traceEnd) { sp.push({ key: 'tf.a', b: [0, 1], v0: base.tfStart != null ? base.tfStart : 0 }, { key: 'tf.du', b: [-0.25, 0.25], v0: 0 }, { key: 'tf.dv', b: [-0.12, 0.12], v0: 0 }, { key: 'tf.cut', b: [0.7, 1.3], v0: TR_CUT }); }
		// V8 --endBlend: cfg.endBlend, the arc length (band) over which the ports ease from the live braid into the tile
		if (base.endBlend) { sp.push({ key: 'endBlend', b: [0.3, 2], v0: 0.6 }); }
		if (base.slant) { slantSpace(base).concat([WEAVE_SPACE.find(q => q.key === 'strands.cutCurl')]).forEach(q => sp.push(q)); }   // V9 --slant
		fillSpace(base).forEach(q => sp.push(q));   // V10 --fillMode
		legWeaveSpace(base).forEach(q => sp.push(q));   // V11 --legWeave
		// V12 --endPlace (V12 goal 1): the end's own placement on a joint page -- cfg.endSlide (the share of the corner's phase
		// error the end tile takes by sliding) and, when the cfg spreads its phase residual, cfg.phaseSpread; with etp.lam and
		// brk.top / brk.topAt (always in this space) the end can move on the page. Pair with --hold left:0.85,right:0.85.
		if (base.endPlace) { sp.push({ key: 'endSlide', b: [0, 1], v0: 0 }); if (base.cfg.phaseSpread > 0) { sp.push({ key: 'phaseSpread', b: [0, 1.6], v0: base.cfg.phaseSpread }); } }
		fieldSpace(base, 'end').forEach(q => sp.push(q));   // V12 --fillField
		if (base.endXform) { EX_SPACE.forEach(q => sp.push(q)); }   // V13 --endXform
		return base.warp === false ? sp : sp.concat(warpSpace('ew.'));
	}
	throw new Error('unknown stage ' + stage);
}
// V13 --endXform (V13 goal 1): the end tile moved in its OWN frame -- ex.du / ex.dv (band; U into the run, V across from
// the outer edge), ex.rot (radians about the tile's middle, U 0.8 / V 0.5) and ex.sc (scale about it) -- with weight 1 for
// U <= EX_U1 easing (cosine) to 0 at the port line, so the ports, the lattice and the repeat count stay where they are
// (the V12 placement keys moved the whole end and re-rounded the run). km/v13dev xsweep.cjs: on v12-best the nominal
// top-L sits on a sharp optimum of all four (0.005 band costs 0.002-0.008), so pair it with --refJitter.
const EX_U1 = 1.0, EX_C = [0.8, 0.5];
const EX_SPACE = [{ key: 'ex.du', b: [-0.06, 0.06], v0: 0 }, { key: 'ex.dv', b: [-0.06, 0.06], v0: 0 }, { key: 'ex.rot', b: [-0.06, 0.06], v0: 0 }, { key: 'ex.sc', b: [0.94, 1.06], v0: 1 }];
function endXform(pts, ex, portU) {
	const du = ex.du || 0, dv = ex.dv || 0, rot = ex.rot || 0, sc = ex.sc == null ? 1 : ex.sc;
	if (!du && !dv && !rot && sc === 1) { return pts; }
	const c = Math.cos(rot), s = Math.sin(rot);
	return pts.map(([U, V]) => {
		const e = U <= EX_U1 ? 1 : U >= portU ? 0 : 0.5 * (1 + Math.cos(Math.PI * (U - EX_U1) / (portU - EX_U1)));
		if (!(e > 0)) { return [U, V]; }
		const x = (U - EX_C[0]) * sc, y = (V - EX_C[1]) * sc;
		return [U + e * (EX_C[0] + c * x - s * y + du - U), V + e * (EX_C[1] + s * x + c * y + dv - V)];
	});
}
// Hairpin fold controls (tile units). The fold = the hairpin's points nearer the cap than HP_U1 (weight 1
// below HP_U0, easing to 0 at HP_U1, so the port legs stay put): hp.scale = fold radius (scale about the
// fold's centroid), hp.dx / hp.dy = where the fold (and its slit) sits, hp.rot = its tilt, hp.tight =
// curl tightness (extra scale of the innermost, tip end of the fold only). hb.k: HP_BUMPS normal bumps
// spread along the fold.
const HP_MODES = 10, HP_BUMPS = 8, HP_BAMP = 0.06, HP_U0 = 0.65, HP_U1 = 1.15;
const HAIRPIN_SPACE = [{ key: 'hp.scale', b: [0.75, 1.3], v0: 1 }, { key: 'hp.dx', b: [-0.15, 0.15], v0: 0 }, { key: 'hp.dy', b: [-0.15, 0.15], v0: 0 },
	{ key: 'hp.rot', b: [-0.4, 0.4], v0: 0 }, { key: 'hp.tight', b: [0.7, 1.3], v0: 1 }];
function foldWarp(pts, hp, hb) {
	const w = pts.map(p => 1 - (p[0] <= HP_U0 ? 0 : p[0] >= HP_U1 ? 1 : (t => t * t * (3 - 2 * t))((p[0] - HP_U0) / (HP_U1 - HP_U0))));
	let sw = 0, cx = 0, cy = 0; pts.forEach((p, i) => { if (w[i] > 0.5) { sw++; cx += p[0]; cy += p[1]; } });
	if (!sw) { return pts; }
	cx /= sw; cy /= sw;
	const n = pts.length, cum = [0]; for (let i = 1; i < n; i++) { cum[i] = cum[i - 1] + Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]); }
	const inF = w.map((x, i) => (x > 0.5 ? i : -1)).filter(i => i >= 0), s0 = cum[inF[0]], s1 = cum[inF[inF.length - 1]];
	// the tip = the fold's deepest point (smallest U); tightness scales about the centroid, fading out with
	// arc distance from the tip
	let tip = inF[0]; inF.forEach(i => { if (pts[i][0] < pts[tip][0]) { tip = i; } });
	const sc = hp.scale == null ? 1 : hp.scale, tg = hp.tight == null ? 1 : hp.tight, rot = hp.rot || 0, cr = Math.cos(rot), sr = Math.sin(rot);
	let out = pts.map((p, i) => {
		const dt = Math.abs(cum[i] - cum[tip]) / ((s1 - s0) / 2 || 1), k = sc * (1 + (tg - 1) * Math.max(0, 1 - dt));
		const x = (p[0] - cx) * k, y = (p[1] - cy) * k, q = [cx + cr * x - sr * y + (hp.dx || 0), cy + sr * x + cr * y + (hp.dy || 0)];
		return [p[0] + w[i] * (q[0] - p[0]), p[1] + w[i] * (q[1] - p[1])];
	});
	if (hb && hb.length) {
		const sig = (s1 - s0) / (2 * HP_BUMPS) || 0.05;
		out = out.map((p, i) => {
			const a = out[Math.max(0, i - 1)], b = out[Math.min(n - 1, i + 1)]; let tx = b[0] - a[0], ty = b[1] - a[1]; const tl = Math.hypot(tx, ty) || 1; tx /= tl; ty /= tl;
			let d = 0; hb.forEach((c, k) => { const sk = s0 + (s1 - s0) * (k + 0.5) / HP_BUMPS; d += (c || 0) * Math.exp(-0.5 * ((cum[i] - sk) / sig) ** 2); });
			d *= w[i];
			return [p[0] - ty * d, p[1] + tx * d];
		});
	}
	return out;
}
// V9 --wrapSharp HW / --cornerSharp HW (painter review: a mitre join cannot bite on a resampled corner -- after TILE_DS
// resampling no single vertex of the squared wrap turns more than ~22 degrees, so the stroke's outer edge stays round).
// sharpCorners replaces the `count` tightest turns (turn measured over +-HW points; windows at least 6 HW apart; only
// points with U < uMax when given) by ONE vertex: the intersection of the incoming and outgoing lines (each fitted through
// the points HW..2HW before / after). With strands.join 'miter' that vertex paints as a square corner. A turn under
// SHARP_MIN is left alone (no corner to sharpen); a far-off intersection (more than 3 HW spacings away) too.
const SHARP_MIN = 0.6;
function sharpCorners(P, HW, count, uMax) {
	HW = Math.max(2, Math.round(+HW || 4));
	if (P.length < 4 * HW + 2) { return P; }
	const ang = (a, c) => Math.atan2(c[1] - a[1], c[0] - a[0]);
	const turn = i => { let d = ang(P[i], P[i + HW]) - ang(P[i - HW], P[i]); while (d > Math.PI) { d -= 2 * Math.PI; } while (d < -Math.PI) { d += 2 * Math.PI; } return Math.abs(d); };
	// idempotent: a turn already carried by one vertex (a tile that was sharpened before, e.g. a resumed best) is left as is
	const turn1 = i => { let d = ang(P[i], P[i + 1]) - ang(P[i - 1], P[i]); while (d > Math.PI) { d -= 2 * Math.PI; } while (d < -Math.PI) { d += 2 * Math.PI; } return Math.abs(d); };
	const cand = []; for (let i = 2 * HW; i < P.length - 2 * HW; i++) { if (uMax == null || P[i][0] < uMax) { cand.push([turn(i), i]); } }
	const done = []; cand.forEach(([t, i]) => { if (t >= SHARP_MIN && turn1(i) >= 0.7 * t && done.every(j => Math.abs(j - i) > 6 * HW)) { done.push(i); } });
	count -= done.length;
	if (count <= 0) { return P; }
	cand.sort((x, y) => y[0] - x[0]);
	const picks = []; for (const [t, i] of cand) { if (t < SHARP_MIN) { break; } if (picks.concat(done).every(j => Math.abs(j - i) > 6 * HW)) { picks.push(i); } if (picks.length >= count) { break; } }
	const out = P.slice();
	picks.sort((x, y) => y - x).forEach(i => {
		const a0 = out[i - 2 * HW], a1 = out[i - HW], b0 = out[i + HW], b1 = out[i + 2 * HW];
		const d1 = [a1[0] - a0[0], a1[1] - a0[1]], d2 = [b1[0] - b0[0], b1[1] - b0[1]], den = d1[0] * d2[1] - d1[1] * d2[0];
		if (Math.abs(den) < 1e-12) { return; }
		const t = ((b0[0] - a0[0]) * d2[1] - (b0[1] - a0[1]) * d2[0]) / den, X = [a0[0] + d1[0] * t, a0[1] + d1[1] * t];
		const step = Math.hypot(d1[0], d1[1]) / HW;
		if (!(Math.hypot(X[0] - out[i][0], X[1] - out[i][1]) < 3 * HW * step)) { return; }
		out.splice(i - HW + 1, 2 * HW - 1, X);
	});
	return out;
}
// resampleUniform that keeps sharp vertices (single-vertex turns >= SHARP_MIN, i.e. sharpCorners output): each stretch
// between them is resampled on its own. Without such vertices it is resampleUniform exactly.
function resampleKeep(P, ds) {
	const ang = (a, c) => Math.atan2(c[1] - a[1], c[0] - a[0]), cut = [];
	for (let i = 1; i < P.length - 1; i++) { let d = ang(P[i], P[i + 1]) - ang(P[i - 1], P[i]); while (d > Math.PI) { d -= 2 * Math.PI; } while (d < -Math.PI) { d += 2 * Math.PI; } if (Math.abs(d) >= SHARP_MIN) { cut.push(i); } }
	if (!cut.length) { return resampleUniform(P, ds); }
	let out = [], a = 0;
	cut.concat([P.length - 1]).forEach(b => { const seg = resampleUniform(P.slice(a, b + 1), ds); out = out.length ? out.concat(seg.slice(1)) : seg; a = b; });
	return out;
}
// the corner tile's outer L (squareCorner's rule: its innermost point lies within SQ_OUTER of the corner)
function isOuterL(q) { let m = Infinity; q.forEach(p => { if (p[0] < 1 && p[1] < 1) { m = Math.min(m, p[0] + p[1]); } }); return m < SQ_OUTER; }
function setPath(o, key, v) { const ks = key.split('.'); let q = o; for (let i = 0; i < ks.length - 1; i++) { q = q[ks[i]] = q[ks[i]] || {}; } q[ks[ks.length - 1]] = v; }
// decode a normalised vector into a concrete job (cfg + override description, JSON-serialisable)
function decode(stage, base, x) {
	const sp = spaceFor(stage, base), cfg = JSON.parse(JSON.stringify(base.cfg)), consts = Object.assign({}, base.consts || {});
	const ct = {}, et = {}, cw = {}, ew = {}, hp = {}, hb = [], wq = {}, csq = {}, tf = {}, nl = {}, ex = {};
	sp.forEach((s, i) => {
		const v = lerpB(s.b, x[i]);
		if (s.key.startsWith('const.')) { consts[s.key.slice(6)] = v; }
		else if (s.key.startsWith('cw.') || s.key.startsWith('ew.')) { (s.key[0] === 'c' ? cw : ew)[s.key.slice(3)] = v; }
		else if (s.key.startsWith('ct.')) { const [, pi, k] = s.key.split('.'); (ct[pi] = ct[pi] || [])[+k] = v; }
		else if (s.key.startsWith('et.')) { const [, pi, k] = s.key.split('.'); (et[pi] = et[pi] || [])[+k] = v; }
		else if (s.key.startsWith('hp.')) { hp[s.key.slice(3)] = v; }
		else if (s.key.startsWith('ex.')) { ex[s.key.slice(3)] = v; }   // V13 --endXform
		else if (s.key === 'wq.a' || s.key === 'wq.reach' || s.key === 'wq.b' || s.key === 'wq.low') { wq[s.key.slice(3)] = v; }
		else if (s.key.startsWith('nl.')) { nl[s.key.slice(3)] = v; }
		else if (s.key === 'csq.a' || s.key === 'csq.b') { csq[s.key.slice(4)] = v; }
		else if (/^t[fc]\./.test(s.key)) { tf[s.key] = v; }   // V8 trace fit (traceFit)
		else if (s.key.startsWith('hb.')) { hb[+s.key.slice(3)] = v; }
		else if (s.key.startsWith('ctp.') || s.key.startsWith('etp.')) { (s.key.startsWith('ctp.') ? ct : et)[s.key.slice(4)] = v; }
		else if (s.key === 'brk.topAt') { (cfg.breaks.find(b => b.edge === 'top') || {}).at = v; }
		else if (s.key === 'brk.botAt') { (cfg.breaks.find(b => b.edge === 'bottom') || {}).at = v; }
		else if (s.key === 'brk.top') { (cfg.breaks.find(b => b.edge === 'top') || {}).width = v; }
		else if (s.key === 'brk.bot') { (cfg.breaks.find(b => b.edge === 'bottom') || {}).width = v; }
		else { setPath(cfg, s.key, v); }
	});
	if (base.tieBreaks) {
		const tb = cfg.breaks.find(b => b.edge === 'top'), bb = cfg.breaks.find(b => b.edge === 'bottom');
		if (tb && bb) { bb.width = tb.width; bb.at = tb.at; }
	}
	const job = { cfg, consts };
	if (stage === 'corner' || (stage === 'joint' && base.cornerTile)) {
		const t = JSON.parse(JSON.stringify(base.cornerTile));
		if (ct.phase != null) { t.phase = +ct.phase.toFixed(4); }
		if (ct.lam != null) { t.lam = +ct.lam.toFixed(4); }
		if (ct.phaseIn != null) { t.phaseIn = +(((ct.phaseIn % 1) + 1) % 1).toFixed(4); }
		t.paths.forEach((p, pi) => {
			const rsU = base.cornerSharp ? resampleKeep : resampleUniform;   // V9: a sharpened (resumed) corner keeps its vertex
			let q = warpPts(displace(rsU(samplePath(p.d), TILE_DS), ct[pi] || [], 'both'), cw, t.arm, t.arm, true);
			if (base.traceCorner && tf['tc.a'] > 1e-4) { q = traceFit(rsU(q, TILE_DS), base.traceCorner.chains, tfClassCorner(p, cfg), tf['tc.a'], tfEnvCorner(t.arm)); }   // V8 --traceCorner
			if (csq.a > 1e-4 || csq.b > 1e-4) { q = squareCorner(rsU(q, TILE_DS), csq.a, csq.b); }   // V7 --cornerSquare
			if (nl.a > 1e-4 && isNestedL(q)) { q = squareNested(rsU(q, TILE_DS), nl); }   // V11 --nestedL
			q = rsU(q, TILE_DS);
			if (base.cornerSharp && isOuterL(q)) { q = sharpCorners(q, base.cornerSharp, 1); }   // V9 --cornerSharp
			p.d = toD(q);
		});
		if (nl.a > 1e-4) { t.nl = { x: +nl.x.toFixed(4), y: +nl.y.toFixed(4), b: +nl.b.toFixed(4), r: +nl.r.toFixed(4), e: +nl.e.toFixed(4) }; }   // the L, for a resume
		job.cornerTile = { name: base.cornerName, family: base.family, tile: t };
	}
	// V11 --carryTiles: the --init best's OTHER tile kind rides along unchanged (a corner stage on a joint page keeps the
	// joint's fitted end tile, an end stage its corner tile), so a stage can be fitted on the deliverable page itself
	if (base.carryTiles && stage === 'corner' && base.endTile && base.endName) { job.endTile = { name: base.endName, family: base.family, tile: base.endTile }; }
	if (base.carryTiles && stage === 'end' && base.cornerTile && base.cornerName) { job.cornerTile = { name: base.cornerName, family: base.family, tile: base.cornerTile }; }
	if (stage === 'end' || (stage === 'joint' && base.endTile)) {
		const t = JSON.parse(JSON.stringify(base.endTile));
		if (et.lam != null) { t.lam = +et.lam.toFixed(4); }
		t.paths.forEach((p, pi) => {
			const pts = []; for (let i = 0; i + 1 < p.pts.length; i += 2) { pts.push([p.pts[i], p.pts[i + 1]]); }
			const pin = (p.a === 'port' && p.b === 'port') ? 'both' : 'start';
			let q2 = displace(pts, et[pi] || [], pin);
			if (p.id === 'hairpin') { q2 = foldWarp(q2, hp, hb); }
			if ((wq.a != null || wq.reach != null) && p.id === (t.outer || 'wrap')) { q2 = squareWrap(q2, wq.a, wq.reach, wq.b, wq.low); }
			// V8 --traceEnd: the wrap's C redrawn from Ash's traced C (traceRedraw); the rest of the tile is left to the
			// engine's endBlend (straight lead-ins) and the hairpin fold controls
			if (base.traceEnd && tf['tf.a'] > 1e-4 && p.id === (t.outer || 'wrap')) { q2 = traceRedraw(q2, base.traceEnd.chains, tfClassEnd(t, p, cfg), tf['tf.a'], [base.traceEnd.du0 + (tf['tf.du'] || 0), tf['tf.dv'] || 0], tf['tf.cut']); }
			let q3 = endXform(warpPts(q2, ew, t.portU, 1, false), ex, t.portU);   // V13 --endXform (no-op at its start values)
			if (base.wrapSharp && p.id === (t.outer || 'wrap')) { q3 = sharpCorners(q3, base.wrapSharp, 2, WRAP_U); }   // V9 --wrapSharp
			p.pts = [].concat.apply([], q3.map(q => [+q[0].toFixed(4), +q[1].toFixed(4)]));
		});
		job.endTile = { name: base.endName, family: base.family, tile: t };
	}
	return job;
}
function buildOverrides(job) {
	const o = { consts: job.consts || {} };
	if (job.cornerTile) { o.cornerTiles = CT => { CT[job.cornerTile.name][job.cornerTile.family] = job.cornerTile.tile; }; }
	if (job.endTile) { o.endTiles = data => { data[job.endTile.name][job.endTile.family] = job.endTile.tile; return data; }; }
	return o;
}
// current tile data straight from the engine source (so a run starts from what is committed)
function baseTiles(enginePath, cfg) {
	const K = loadEngine(enginePath, {}), out = {};
	const fam = cfg.pattern === 'plait' ? 'plait' + (cfg.strands.count || 3) : cfg.pattern;
	out.family = fam;
	if (K._geom.CORNER_TILES && K._geom.CORNER_TILES[cfg.corners]) {
		out.cornerName = cfg.corners;
		out.cornerTile = JSON.parse(JSON.stringify(K._geom.CORNER_TILES[cfg.corners][fam]));
	}
	const src = fs.readFileSync(enginePath, 'utf8'), m = src.match(/\/\*GEN-BEGIN\*\/([\s\S]*?)\/\*GEN-END\*\//);
	if (m && cfg.ends) {
		const data = new Function('return ' + m[1])();
		if (data[cfg.ends] && data[cfg.ends][fam]) { out.endName = cfg.ends; out.endTile = data[cfg.ends][fam]; }
	}
	return out;
}
// initial normalised vector: weave = the cfg's own values; tiles = zero displacement
function initVector(stage, base) {
	return spaceFor(stage, base).map(s => {
		let v;
		if (s.key.startsWith('const.')) { v = base.consts && base.consts[s.key.slice(6)]; if (v == null) { v = s.key === 'const.OUTLINE_RATIO' ? 0.5 : 0.6; } }
		else if (/^(ct|et|cw|ew|hb)\./.test(s.key)) { v = 0; }
		else if (s.v0 != null) { const cv = s.key.split('.').reduce((q, k) => q && q[k], base.cfg); v = cv != null ? cv : s.v0; }   // a cfg value wins over the default
		else if (s.key.startsWith('ctp.')) { v = base.cornerTile[s.key.slice(4)]; }
		else if (s.key.startsWith('etp.')) { v = base.endTile[s.key.slice(4)]; }
		else if (s.key === 'brk.topAt') { v = (base.cfg.breaks.find(b => b.edge === 'top') || {}).at; }
		else if (s.key === 'brk.botAt') { v = (base.cfg.breaks.find(b => b.edge === 'bottom') || {}).at; }
		else if (s.key === 'brk.top') { v = (base.cfg.breaks.find(b => b.edge === 'top') || {}).width; }
		else if (s.key === 'brk.bot') { v = (base.cfg.breaks.find(b => b.edge === 'bottom') || {}).width; }
		else { v = s.key.split('.').reduce((q, k) => q && q[k], base.cfg); if (v == null) { v = (s.b[0] + s.b[1]) / 2; } }
		return Math.min(1, Math.max(0, (v - s.b[0]) / (s.b[1] - s.b[0])));
	});
}

// ---------------------------------------------------------------- worker pool
// the job's identity for the pool's echo check: a hash of the job as sent (IPC is JSON, so both ends see the same)
function jobHash(job) { return crypto.createHash('sha1').update(JSON.stringify(job)).digest('hex').slice(0, 16); }
// a result's scores (what a fresh re-score must reproduce exactly)
function resultKey(r) {
	if (!r || r.error) { return 'error'; }
	const rs = g => g.map(x => x.score.toFixed(9)).join(',');
	return r.regs ? rs(r.regs) : (r.score || 0).toFixed(9) + '|' + (r.robust || []).join(',') + '|' + rs(r.regions || []) + '|' + rs(r.nominalRegs || []);
}
// Worker pool. Self-checks (pool.stats, printed by close() into the run's log):
//   echo  -- every result carries the hash of the job the worker received; a mismatch (a result matched to the
//            wrong job) throws
//   audit -- every `audit`-th scoring job (default 50, --audit N; 0 = off) is also scored in a FRESH engine context by
//            another worker and compared exactly; on a mismatch a third, fresh score decides and is returned,
//            and the event is logged (stats.mismatches)
function pool(n, opt) {
	opt = opt || {};
	const workers = [], queue = [], busy = new Set(), stats = { jobs: 0, audited: 0, mismatches: 0, echoFail: 0 };
	const audit = opt.audit != null ? +opt.audit : 50;
	const execArgv = process.execArgv.concat(V8_SAFE.filter(f => process.execArgv.indexOf(f) < 0));
	for (let i = 0; i < n; i++) {
		const w = fork(__filename, ['worker'], { stdio: ['ignore', 'inherit', 'inherit', 'ipc'], execArgv });
		w.cb = null; w.on('message', m => { const cb = w.cb; w.cb = null; busy.delete(w); cb(m); pump(); });
		workers.push(w);
	}
	function pump() {
		while (queue.length) {
			const w = workers.find(x => !busy.has(x)); if (!w) { return; }
			const { job, resolve } = queue.shift(); busy.add(w); w.cb = resolve; w.send(job);
		}
	}
	const raw = job => { const h = jobHash(job); return new Promise(resolve => { queue.push({ job, resolve }); pump(); }).then(r => {
		if (r && r.jobHash !== h) { stats.echoFail++; throw new Error('pool: result does not belong to its job (' + r.jobHash + ' vs ' + h + ')'); }
		return r;
	}); };
	return {
		stats,
		run: async job => {
			const k = ++stats.jobs, r = await raw(job);
			if (!(audit > 0) || k % audit || job.validate || r.error) { return r; }
			stats.audited++;
			const fresh = Object.assign({}, job, { persist: false }), f = await raw(fresh);
			if (resultKey(f) === resultKey(r)) { return r; }
			stats.mismatches++;
			const t = await raw(fresh), win = resultKey(t) === resultKey(r) ? r : t;
			console.log(`[pool] AUDIT MISMATCH (job ${k}): pooled ${resultKey(r).slice(0, 80)} vs fresh ${resultKey(f).slice(0, 80)}; third ${resultKey(t).slice(0, 80)} -> using the ${win === r ? 'pooled' : 'fresh'} result`);
			return win;
		},
		close: () => {
			if (stats.audited || stats.echoFail) { console.log('[pool] self-checks: ' + JSON.stringify(stats)); }
			workers.forEach(w => w.kill());
		}
	};
}

// ---------------------------------------------------------------- statistics
function welchOneSided(a, b) {       // H1: mean(a) > mean(b); returns p
	const m = v => v.reduce((s, x) => s + x, 0) / v.length;
	const vr = (v, mu) => v.reduce((s, x) => s + (x - mu) ** 2, 0) / Math.max(1, v.length - 1);
	const ma = m(a), mb = m(b), va = vr(a, ma), vb = vr(b, mb), se = Math.sqrt(va / a.length + vb / b.length);
	if (!(se > 1e-12)) { return ma > mb ? 0 : 1; }
	const t = (ma - mb) / se;
	const df = (va / a.length + vb / b.length) ** 2 / ((va / a.length) ** 2 / (a.length - 1) + (vb / b.length) ** 2 / (b.length - 1));
	return 1 - studentCdf(t, df);
}
function studentCdf(t, df) {         // via the regularised incomplete beta function
	const x = df / (df + t * t), ib = 0.5 * incBeta(df / 2, 0.5, x);
	return t > 0 ? 1 - ib : ib;
}
function incBeta(a, b, x) {
	if (x <= 0) { return 0; } if (x >= 1) { return 1; }
	const lbeta = lgamma(a + b) - lgamma(a) - lgamma(b);
	const front = Math.exp(Math.log(x) * a + Math.log(1 - x) * b + lbeta);
	if (x < (a + 1) / (a + b + 2)) { return front * cf(a, b, x) / a; }
	return 1 - Math.exp(Math.log(1 - x) * b + Math.log(x) * a + lbeta) * cf(b, a, 1 - x) / b;
}
function cf(a, b, x) {
	let c = 1, d = 1 - (a + b) * x / (a + 1); d = 1 / (Math.abs(d) < 1e-30 ? 1e-30 : d); let h = d;
	for (let m = 1; m < 200; m++) {
		const m2 = 2 * m; let aa = m * (b - m) * x / ((a + m2 - 1) * (a + m2));
		d = 1 + aa * d; d = 1 / (Math.abs(d) < 1e-30 ? 1e-30 : d); c = 1 + aa / c; c = Math.abs(c) < 1e-30 ? 1e-30 : c; h *= d * c;
		aa = -(a + m) * (a + b + m) * x / ((a + m2) * (a + m2 + 1));
		d = 1 + aa * d; d = 1 / (Math.abs(d) < 1e-30 ? 1e-30 : d); c = 1 + aa / c; c = Math.abs(c) < 1e-30 ? 1e-30 : c;
		const del = d * c; h *= del; if (Math.abs(del - 1) < 3e-12) { break; }
	}
	return h;
}
function lgamma(z) {
	const g = [676.5203681218851, -1259.1392167224028, 771.32342877765313, -176.61502916214059, 12.507343278686905, -0.13857109526572012, 9.9843695780195716e-6, 1.5056327351493116e-7];
	if (z < 0.5) { return Math.log(Math.PI / Math.abs(Math.sin(Math.PI * z))) - lgamma(1 - z); }
	z -= 1; let x = 0.99999999999980993; for (let i = 0; i < 8; i++) { x += g[i] / (z + i + 1); }
	const t = z + 7.5; return 0.5 * Math.log(2 * Math.PI) + (z + 0.5) * Math.log(t) - t + Math.log(x);
}
function rng(seed) { let s = seed >>> 0 || 1; return () => { s ^= s << 13; s >>>= 0; s ^= s >> 17; s ^= s << 5; s >>>= 0; return s / 4294967296; }; }
function gauss(r) { let u = 0, v = 0; while (u === 0) { u = r(); } while (v === 0) { v = r(); } return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v); }
scoreCandidate.bench = () => ({ PROF, scoringOpts, STAGE_REGIONS, overlapScan, overlapPacked, overlapConf, overlap, chamferDT, fmt2, measureOurs });   // for bench.cjs (a lazy hook, away from lines V5 edits)

// ---------------------------------------------------------------- images for the report
function compositeRegions(ref, ours, regs, rects, file) {
	// one row per region: ours | Ash | overlay (agree = class colour dimmed, ours only = red, Ash only = cyan)
	const rows = regs.map((g, i) => ({ g, r: rects[i] }));
	const scale = 1, gapPx = 6;
	const W = Math.max(...rows.map(o => (o.r.x1 - o.r.x0) * 3 + gapPx * 2)), H = rows.reduce((a, o) => a + (o.r.y1 - o.r.y0) + gapPx, 0);
	const png = new PNG({ width: W, height: H }); png.data.fill(255);
	const pal = [PALETTE.bg, PALETTE.ink, PALETTE.A, PALETTE.B];
	let oy = 0;
	rows.forEach(({ g, r }) => {
		const bw = r.x1 - r.x0, bh = r.y1 - r.y0;
		for (let y = 0; y < bh; y++) {
			for (let x = 0; x < bw; x++) {
				const a = ref.c[(r.y0 + y) * ref.w + r.x0 + x];
				const sx = r.x0 + x - g.dx, sy = r.y0 + y - g.dy;
				const om = g.map || ours, b = (sx < 0 || sy < 0 || sx >= om.w || sy >= om.h) ? 0 : om.c[sy * om.w + sx];
				const put = (px, col) => { const i = ((oy + y) * W + px) * 4; png.data[i] = col[0]; png.data[i + 1] = col[1]; png.data[i + 2] = col[2]; png.data[i + 3] = 255; };
				put(x, pal[b]); put(bw + gapPx + x, pal[a]);
				const sil = (a ? 1 : 0) + (b ? 2 : 0);
				put(2 * (bw + gapPx) + x, sil === 3 ? (a === b || (g.swapped && a + b === 5) ? [150, 150, 150] : [120, 90, 160]) : sil === 2 ? [230, 40, 40] : sil === 1 ? [20, 190, 210] : [250, 248, 244]);
			}
		}
		oy += bh + gapPx;
	});
	fs.writeFileSync(file, PNG.sync.write(png));
}
async function snapshot(job, outPng, regionKind) {
	const ref = await getRef(job.ref);
	const K = loadEngine(job.engine, buildOverrides(job)), svg = renderSvg(K, job.cfg);
	const ours = classMap(await rasterize(svg, RASTER_W, RASTER_H));
	const rects = regionsFor(regionKind, ref.m);
	const regs = rects.map(r => regionScoreTol(ref.cm, ours, r, ref.m.band, refDTFor(ref, r), +job.periodTol || 0));
	compositeRegions(ref.cm, ours, regs, rects, outPng);
	return { svg, regs };
}

// ---------------------------------------------------------------- CMA-ES
// Symmetric eigendecomposition (cyclic Jacobi) -- n is at most a few dozen here.
function jacobiEigen(A) {
	const n = A.length, a = A.map(r => r.slice()), v = A.map((r, i) => r.map((_, j) => (i === j ? 1 : 0)));
	for (let sweep = 0; sweep < 80; sweep++) {
		let off = 0;
		for (let i = 0; i < n; i++) { for (let j = i + 1; j < n; j++) { off += a[i][j] * a[i][j]; } }
		if (off < 1e-24) { break; }
		for (let p = 0; p < n; p++) {
			for (let q = p + 1; q < n; q++) {
				if (Math.abs(a[p][q]) < 1e-18) { continue; }
				const th = (a[q][q] - a[p][p]) / (2 * a[p][q]);
				const t = (th >= 0 ? 1 : -1) / (Math.abs(th) + Math.sqrt(th * th + 1)), c = 1 / Math.sqrt(t * t + 1), s = t * c;
				for (let k = 0; k < n; k++) { const kp = a[k][p], kq = a[k][q]; a[k][p] = c * kp - s * kq; a[k][q] = s * kp + c * kq; }
				for (let k = 0; k < n; k++) { const pk = a[p][k], qk = a[q][k]; a[p][k] = c * pk - s * qk; a[q][k] = s * pk + c * qk; }
				for (let k = 0; k < n; k++) { const kp = v[k][p], kq = v[k][q]; v[k][p] = c * kp - s * kq; v[k][q] = s * kp + c * kq; }
			}
		}
	}
	return { vals: a.map((r, i) => r[i]), vecs: v };
}
// Standard (mu/mu_w, lambda)-CMA-ES (Hansen's defaults). Minimises f; the caller passes -score.
function cmaes(x0, sigma0, lam, rnd) {
	const n = x0.length, mu = Math.floor(lam / 2);
	let w = []; for (let i = 0; i < mu; i++) { w.push(Math.log(mu + 0.5) - Math.log(i + 1)); }
	const sw = w.reduce((a, b) => a + b, 0); w = w.map(v => v / sw);
	const mueff = 1 / w.reduce((a, v) => a + v * v, 0);
	const cc = (4 + mueff / n) / (n + 4 + 2 * mueff / n), cs = (mueff + 2) / (n + mueff + 5);
	const c1 = 2 / ((n + 1.3) ** 2 + mueff), cmu = Math.min(1 - c1, 2 * (mueff - 2 + 1 / mueff) / ((n + 2) ** 2 + mueff));
	const damps = 1 + 2 * Math.max(0, Math.sqrt((mueff - 1) / (n + 1)) - 1) + cs, chiN = Math.sqrt(n) * (1 - 1 / (4 * n) + 1 / (21 * n * n));
	const eye = () => Array.from({ length: n }, (_, i) => Array.from({ length: n }, (_, j) => (i === j ? 1 : 0)));
	const S = { n, lam, mu, m: x0.slice(), sigma: sigma0, C: eye(), B: eye(), D: new Array(n).fill(1), pc: new Array(n).fill(0), ps: new Array(n).fill(0), g: 0 };
	S.ask = () => Array.from({ length: lam }, () => {
		const z = Array.from({ length: n }, () => gauss(rnd)), dz = z.map((v, i) => S.D[i] * v);
		const y = S.B.map(row => row.reduce((a, b, j) => a + b * dz[j], 0));
		return { y, x: S.m.map((m, i) => m + S.sigma * y[i]) };
	});
	S.tell = sorted => {                      // sorted best (lowest f) first
		const old = S.m.slice(), sel = sorted.slice(0, mu);
		S.m = old.map((_, i) => sel.reduce((a, s, k) => a + w[k] * s.x[i], 0));
		const yw = S.m.map((v, i) => (v - old[i]) / S.sigma);
		const bty = S.B[0].map((_, j) => S.B.reduce((a, row, i) => a + row[j] * yw[i], 0)).map((v, j) => v / S.D[j]);
		const invsq = S.B.map(row => row.reduce((a, b, j) => a + b * bty[j], 0));
		S.ps = S.ps.map((v, i) => (1 - cs) * v + Math.sqrt(cs * (2 - cs) * mueff) * invsq[i]);
		const psn = Math.hypot(...S.ps);
		const hsig = psn / Math.sqrt(1 - Math.pow(1 - cs, 2 * (S.g + 1))) / chiN < 1.4 + 2 / (n + 1) ? 1 : 0;
		S.pc = S.pc.map((v, i) => (1 - cc) * v + hsig * Math.sqrt(cc * (2 - cc) * mueff) * yw[i]);
		for (let i = 0; i < n; i++) {
			for (let j = 0; j <= i; j++) {
				let rmu = 0; sel.forEach((s, k) => { rmu += w[k] * s.y[i] * s.y[j]; });
				const v = (1 - c1 - cmu) * S.C[i][j] + c1 * (S.pc[i] * S.pc[j] + (1 - hsig) * cc * (2 - cc) * S.C[i][j]) + cmu * rmu;
				S.C[i][j] = v; S.C[j][i] = v;
			}
		}
		S.sigma = Math.min(0.6, Math.max(1e-4, S.sigma * Math.exp((cs / damps) * (psn / chiN - 1))));
		const e = jacobiEigen(S.C);
		S.D = e.vals.map(v => Math.sqrt(Math.max(v, 1e-20))); S.B = e.vecs;
		S.g++;
	};
	return S;
}

// V9 --legFirst: CMA-ES over a subset idx of the dims, the rest held at full's values. ask() returns full vectors
// (x) and the sub-vector (sub) the inner search learns from; tell() takes the sorted {x, y, sub}.
function subES(full, idx, sigma0, lam, rnd) {
	const inner = cmaes(idx.map(i => full[i]), sigma0, lam, rnd), W = {};
	const embed = sv => { const x = full.slice(); idx.forEach((i, k) => { x[i] = sv[k]; }); return x; };
	W.ask = () => inner.ask().map(c => ({ y: c.y, x: embed(c.x), sub: c.x }));
	W.tell = sorted => inner.tell(sorted.map(q => ({ x: q.sub, y: q.y })));
	Object.defineProperty(W, 'sigma', { get: () => inner.sigma, set: v => { inner.sigma = v; } });
	return W;
}
// V9 polish constants (see optimize: polish) and the leg-phase keys of --legFirst
const POLISH_FLOOR = 2e-4, POLISH_CAP = 0.03, POLISH_STALL = 40;
const LEG_RE = /^(ctp\.|etp\.lam$|brk\.|repeatLam$|endSlide$)/;

// ---------------------------------------------------------------- scatter seeds
// Quite different starting points for scatter restarts. Each is {label, base} (a different tile, or
// the current one at another phase / break position) or {label} alone = a random scouting round.
function seedsFor(stage, base, enginePath) {
	const clone = o => JSON.parse(JSON.stringify(o)), out = [];
	if (stage === 'corner') {
		const K = loadEngine(enginePath, {}), CT = K._geom.CORNER_TILES || {};
		Object.keys(CT).forEach(name => {
			const t = CT[name] && CT[name][base.family];
			if (t && name !== base.cornerName && t.paths.length === base.cornerTile.paths.length) { const b = clone(base); b.cornerTile = clone(t); if (base.cornerTile.phaseIn != null && b.cornerTile.phaseIn == null) { b.cornerTile.phaseIn = base.cornerTile.phaseIn; } out.push({ label: 'tile ' + name, base: b }); }
		});
		[1 / 3, 2 / 3].forEach(d => { const b = clone(base); b.cornerTile.phase = +(((b.cornerTile.phase || 0) + d) % 1).toFixed(4); if (b.cornerTile.phaseIn != null) { b.cornerTile.phaseIn = +((b.cornerTile.phaseIn + d) % 1).toFixed(4); } out.push({ label: 'phase +' + d.toFixed(2), base: b }); });
	}
	if (stage === 'end') {
		const src = fs.readFileSync(enginePath, 'utf8'), m = src.match(/\/\*GEN-BEGIN\*\/([\s\S]*?)\/\*GEN-END\*\//);
		const data = m ? new Function('return ' + m[1])() : {};
		Object.keys(data).forEach(name => {
			const t = data[name] && data[name][base.family];
			// only tiles with the same path topology (a hairpin tile's space differs from a free-end tile's)
			const topo = x => x.paths.map(p => p.id + p.a + p.b).join('|');
			if (t && name !== base.endName && topo(t) === topo(base.endTile)) { const b = clone(base); b.endTile = clone(t); out.push({ label: 'tile ' + name, base: b }); }
		});
		[-2, 2].forEach(d => { const b = clone(base); b.cfg.breaks.forEach(k => { k.at = Math.min(54, Math.max(46, (k.at || 50) + d)); }); out.push({ label: 'breaks ' + (d > 0 ? '+' : '') + d, base: b }); });
	}
	out.push({ label: 'random scout' });
	return out;
}

// ---------------------------------------------------------------- optimize
const STAGE_REGIONS = { weave: 'side', corner: 'corner', end: 'end', joint: 'joint' };
// V7 cfg switches (engine options, opt-in; a cfg without them renders exactly as before):
//   --cornerColor k  cfg.cornerColor: every corner tile wears its colours shifted k palette steps, its phase pin moving
//                    k/N repeat to match (plait-4, two colours: 1 swaps them -- Ash's TL outer L is pink)
//   --cornerFollow   cfg.cornerFollow: in a run with corner tiles, the corners after the anchor (the top one) keep its
//                    shift on the 1/N-repeat lattice, so the side between them is a pure shift (single-engine joint:
//                    the side repeat no longer collapses to 165 px)
//   --breakExact [woven|tile]  cfg.breakExact: a break lands at its true page position on every spine; the cfg's
//                    breaks are first moved so they stay where the named spine (default woven, the ends engine's)
//                    put them -- only when the cfg does not already have breakExact
function v7CfgFlags(o, cfg, stage) {
	if (o.cornerColor != null && o.cornerColor !== true) { cfg.cornerColor = +o.cornerColor; }
	if (o.cornerFollow) { cfg.cornerFollow = true; }
	if (o.breakExact && !cfg.breakExact) {
		const from = o.breakExact === true ? 'woven' : String(o.breakExact), S = Math.min(PAGE_W, PAGE_H);
		const band = cfg.band.width / 100 * S, inset = cfg.band.inset / 100 * S, R = from === 'woven' ? Math.min(band, Math.max(6, band * 0.75)) : 0.01;
		(cfg.breaks || []).forEach(b => {
			const len = (b.edge === 'top' || b.edge === 'bottom' ? PAGE_W : PAGE_H) - 2 * inset - 2 * band, sgn = b.edge === 'top' || b.edge === 'right' ? 1 : -1;
			b.at = +(b.at + sgn * (R - band / 2) / len * 100).toFixed(6);
		});
		cfg.breakExact = true;
		console.log(`[${stage}] breakExact: breaks moved to keep the ${from} spine's page positions -> ${JSON.stringify(cfg.breaks.map(b => [b.edge, b.at]))}`);
	}
}
// V8 search switches (opt-in; without them a run's space and renders are V7's):
//   --traceEnd <trace.json> [--tfStart a]     end / joint: tf.a, tf.du, tf.dv -- pull the end tile onto Ash's traced end
//                                             (trace-corner.cjs with END=1; traceFit / traceFrameEnd)
//   --traceCorner <trace.json> [--tcStart a]  corner / joint: tc.a -- pull the corner tile onto Ash's traced TL corner
//   --endBlend                                end / joint: cfg.endBlend, the ports' braid-to-tile easing length (engine V8)
//   --tipExt                                  weave / joint: strands.tipExt / tipPow, the arc-tip extension (engine V8)
function v8Flags(o, base, stage) {
	const file = v => (v && v !== true ? path.resolve(String(v)) : null);
	if (file(o.traceEnd) && base.endTile) {
		const chains = traceChains(file(o.traceEnd)), fr = traceFrameEnd(base.endTile, chains);
		base.traceEnd = { chains, du0: fr.du };
		if (o.tfStart != null && o.tfStart !== true) { base.tfStart = +o.tfStart; }
		console.log(`[${stage}] traceEnd: ${chains.length} traced chains, tile frame U offset ${fr.du} (port fit ${fr.cost}; back-to-back ${fr.back})`);
	}
	if (file(o.traceCorner) && base.cornerTile) {
		base.traceCorner = { chains: traceChains(file(o.traceCorner)) };
		if (o.tcStart != null && o.tcStart !== true) { base.tcStart = +o.tcStart; }
		console.log(`[${stage}] traceCorner: ${base.traceCorner.chains.length} traced chains`);
	}
	if (o.endBlend) { base.endBlend = true; if (o.endBlend !== true) { base.cfg.endBlend = +o.endBlend; } }
	if (o.tipExt) { base.tipExt = true; }
	// V9 painter switches (engine knot-v9-engine): --slant [taper] search space; --wrapSharp / --cornerSharp HW true corner
	// vertices (sharpCorners) for strands.join 'miter' (set it in the cfg, or pick it with --choose 'cfg.strands.join="round"|"miter"')
	if (o.slant) { base.slant = o.slant === 'taper' ? 'taper' : true; }
	if (o.wrapSharp) { base.wrapSharp = o.wrapSharp === true ? 4 : +o.wrapSharp; }
	if (o.cornerSharp) { base.cornerSharp = o.cornerSharp === true ? 4 : +o.cornerSharp; }
	// V10 --phaseSpread [b] (engine knot-v10-engine, with cornerFollow): cfg.phaseSpread -- the run's phase residual no longer
	// lands in the short run between the last following corner and its end tile (spreadFollowers); b = the end tile's
	// largest slide (band). Bare: keeps the cfg's own value, else 0.8 (joint15 re-scores unchanged at 0.8 and its bottom
	// runs keep their repeat; at 0.25-0.5 the left side moves and the side regions drop).
	// V10 --fillMode: strands.paint 'fill' (the cfg's own fill values are kept) + the FILL_SPACE search keys
	if (o.fillMode) { base.fill = true; base.cfg.strands = Object.assign({}, base.cfg.strands, { paint: 'fill' }); }
	if (o.phaseSpread) { if (o.phaseSpread !== true) { base.cfg.phaseSpread = +o.phaseSpread; } else if (!(base.cfg.phaseSpread > 0)) { base.cfg.phaseSpread = 0.8; } }
}
// --choose "path=v1|v2|...;path2+=d1|d2" (paths into the run's base: cfg.*, cornerTile.*, endTile.*; '+=' adds to the
// current value; values are JSON or numbers): every combination is scored at the run's start point, all in parallel
// on the pool, and gated against the unchanged base; the best clean one wins (the unchanged base is always option 0).
async function chooseCategorical(spec, base0, evalBase, gate, stage) {
	const dims = spec.split(';').map(t => t.trim()).filter(Boolean).map(t => {
		const m = t.match(/^([A-Za-z0-9_.]+)(\+?=)(.*)$/); if (!m) { throw new Error('--choose: bad term ' + t); }
		return { path: m[1], add: m[2] === '+=', vals: m[3].split('|').map(v => { try { return JSON.parse(v); } catch (e) { return v; } }) };
	});
	let combos = [[]]; dims.forEach(d => { combos = [].concat.apply([], combos.map(c => d.vals.map(v => c.concat([v])))); });
	const get = (o, p) => p.split('.').reduce((q, k) => (q == null ? q : q[k]), o);
	const mk = combo => {
		const b = JSON.parse(JSON.stringify(Object.assign({}, base0, { traceEnd: undefined, traceCorner: undefined })));
		b.traceEnd = base0.traceEnd; b.traceCorner = base0.traceCorner;
		combo.forEach((v, i) => { const d = dims[i], cur = get(b, d.path); setPath(b, d.path, d.add ? +(((+cur || 0) + +v)).toFixed(6) : v); });
		if (b.cornerTile && b.cornerTile.phase != null) { b.cornerTile.phase = +(((b.cornerTile.phase % 1) + 1) % 1).toFixed(6); }
		return b;
	};
	const ref = await evalBase(base0);
	const res = await Promise.all(combos.map(async c => { const b = mk(c), r = await evalBase(b); return { combo: c, b, score: r.res.error ? 0 : r.res.score, bad: gate(r.diag, ref.diag) }; }));
	const table = res.map(r => ({ choice: dims.map((d, i) => d.path + (d.add ? '+=' : '=') + JSON.stringify(r.combo[i])).join(' '), score: +r.score.toFixed(4), gate: r.bad }));
	table.forEach(t => console.log(`[${stage}] choose ${t.choice}: ${t.score}${t.gate.length ? '  gate: ' + t.gate.slice(0, 3).join('; ') : ''}`));
	const ok = res.filter(r => !r.bad.length).sort((p, q) => q.score - p.score);
	const refBad = gate(ref.diag, ref.diag).length > 0;   // the start itself fails an absolute gate (endFallback): any clean option beats it
	const win = ok.length && (refBad || ok[0].score > ref.res.score) ? ok[0] : null;
	console.log(`[${stage}] choose: start ${ref.res.score.toFixed(4)} -> ${win ? win.score.toFixed(4) + ' with ' + table[res.indexOf(win)].choice : 'kept as is'}`);
	return { base: win ? win.b : base0, table: [{ choice: '(as is)', score: +ref.res.score.toFixed(4) }].concat(table) };
}
async function optimize(o) {
	const engine = path.resolve(o.engine), refPath = path.resolve(o.ref || DEFAULT_REF);
	const cfg = JSON.parse(fs.readFileSync(o.cfg, 'utf8')), stage = o.stage, outDir = path.resolve(o.out);
	fs.mkdirSync(outDir, { recursive: true });
	const init = o.init ? JSON.parse(fs.readFileSync(o.init, 'utf8')) : null;
	const base = Object.assign({ cfg, consts: init ? (init.consts || {}) : {} }, baseTiles(engine, cfg));   // --init carries engine constants; cfg values come from --cfg
	if (init && init.cornerTile && init.cornerTile.tile) { base.cornerTile = init.cornerTile.tile; }
	if (o.phaseIn != null && o.phaseIn !== true && base.cornerTile && base.cornerTile.phaseIn == null) { base.cornerTile.phaseIn = +o.phaseIn; }
	if (init && init.endTile && init.endTile.tile) { base.endTile = init.endTile.tile; }
	// V5: --fairWrap flattens the dent out of the starting tile's wrap (see fairWrap); --wrapModes N sets the
	// number of normal modes on a hairpin tile's wrap (default 4; 0 freezes it -- the warp still moves it)
	if (o.fairWrap && base.endTile) { const fw = fairWrap(base.endTile); console.log(`[${stage}] fairWrap: ${JSON.stringify(wrapChecks(base.endTile))} -> ${JSON.stringify(wrapChecks(fw.tile))} (${fw.iters} iterations)`); base.endTile = fw.tile; }
	if (o.wrapModes != null && o.wrapModes !== true) { base.wrapModes = +o.wrapModes; }
	if (o.inkMatch) {
		const [f, ol] = o.inkMatch === true ? [ASH_INK.fill, ASH_INK.outline] : String(o.inkMatch).split(':').map(Number);
		base.inkMatch = { fill: f, outline: ol };
		base.consts = Object.assign({}, base.consts, { OUTLINE_RATIO: +(ol / f).toFixed(4) });
		console.log(`[${stage}] inkMatch: fill ${f} / outline ${ol} px at ${ASH_INK.pageW} -> OUTLINE_RATIO ${base.consts.OUTLINE_RATIO} pinned, thickness ${JSON.stringify(weaveSpace(base).find(s => s.key === 'strands.thickness').b.map(v => +v.toFixed(3)))}`);
	}
	// V6 --endColor c (visual review 1, item 5): the designed end's outer wrap is fed by strand colour c (0 = blue)
	if (o.endColor != null && o.endColor !== true) { base.cfg.endColor = +o.endColor; }
	if (o.wrapSquare) { base.wrapSquare = true; }   // V6: search the wrap's corner squareness (wq.a, squareWrap)
	if (o.cornerSquare) { base.cornerSquare = true; }   // V7: search the corner tile's L squareness (csq.a, squareCorner)
	// V11 search switches (opt-in; without them a run's space and renders are V10's): --nestedL [a] (corner: squareNested),
	// --legWeave (corner / end: the legs' braid shape, legWeaveSpace), --wrapSquareB (end, with --wrapSquare: wq.b / wq.low),
	// --carryTiles (corner / end: the --init best's other tile rides along -- fit a tile on the joint page)
	if (o.nestedL) { base.nestedL = o.nestedL === true ? true : +o.nestedL; }
	if (o.legWeave) { base.legWeave = true; }
	if (o.wrapSquareB) { base.wrapSquareB = true; }
	if (o.endPlace) { base.endPlace = true; }   // V12 --endPlace (end: endSlide / phaseSpread)
	if (o.endXform) { base.endXform = true; }   // V13 --endXform (end / joint: ex.*)
	if (o.fillField) { base.fillField = o.fillField === true ? (stage === 'corner' ? 'corner' : stage === 'end' ? 'end' : 'both') : String(o.fillField); }   // V12 --fillField
	if (o.carryTiles) {
		base.carryTiles = true;
		if (!init) { throw new Error('--carryTiles needs --init'); }
		console.log(`[${stage}] carryTiles: ${stage === 'corner' ? 'end tile ' + (base.endName || 'none') : 'corner tile ' + (base.cornerName || 'none')} carried from --init unchanged`);
	}
	v7CfgFlags(o, base.cfg, stage);
	base.warp = o.warp !== 'off';
	if (stage === 'joint') {
		// --engineCorner: the corner-tile engine; --initEnd / --initCorner: the end / corner bests to start the tiles from
		// V6: no --engineCorner = single-engine joint (the merged engine draws both tile kinds in one render)
		if (o.engineCorner === true) { throw new Error('--engineCorner needs a path'); }
		base.singleEngine = !o.engineCorner;
		const ct = baseTiles(path.resolve(o.engineCorner || o.engine), cfg);
		base.cornerName = ct.cornerName; base.cornerTile = ct.cornerTile;
		const ie = o.initEnd && o.initEnd !== true ? JSON.parse(fs.readFileSync(o.initEnd, 'utf8')) : null, ic = o.initCorner && o.initCorner !== true ? JSON.parse(fs.readFileSync(o.initCorner, 'utf8')) : null;
		if (ie && ie.endTile && ie.endTile.tile) { base.endTile = ie.endTile.tile; }
		if (ic && ic.cornerTile && ic.cornerTile.tile && ic.cornerTile.name === base.cornerName) { base.cornerTile = ic.cornerTile.tile; }
		// V10 --carryPhase (tile-local leg phase): a carried corner tile keeps its SHAPE (relative to its own ports) but takes
		// the --init joint best's port pins (ctp.*: phase, phaseIn, lam). Its own pins were fitted on the corner-stage page,
		// whose legs differ (the far runs there are compressed ~11%); on the joint page they move the TL anchor and with it
		// the whole top run (corner15's tile on joint15: 0.625, top-L 0.44; with joint15's pins: 0.7969, TL 0.704 -> 0.765).
		if (o.carryPhase && ic && base.cornerTile === ic.cornerTile.tile) {
			const ij = o.init && o.init !== true ? JSON.parse(fs.readFileSync(o.init, 'utf8')) : null, jt = ij && ij.cornerTile && ij.cornerTile.tile;
			if (jt) { base.cornerTile = Object.assign({}, base.cornerTile); ['phase', 'phaseIn', 'lam'].forEach(k => { if (jt[k] != null) { base.cornerTile[k] = jt[k]; } }); console.log(`[${stage}] carryPhase: the carried corner tile takes the --init best's port pins (phase ${jt.phase}, phaseIn ${jt.phaseIn}, lam ${jt.lam})`); }
		}
		// the same for a carried end tile: its etp.* pin (lam) from the --init best (end15's own lam on joint15 broke the mirror:
		// 0.665, right side 0.48; with joint15's lam 0.7836)
		if (o.carryPhase && ie && base.endTile === ie.endTile.tile) {
			const ij = o.init && o.init !== true ? JSON.parse(fs.readFileSync(o.init, 'utf8')) : null, je = ij && ij.endTile && ij.endTile.tile;
			if (je && je.lam != null) { base.endTile = Object.assign({}, base.endTile, { lam: je.lam }); console.log(`[${stage}] carryPhase: the carried end tile takes the --init best's lam ${je.lam}`); }
		}
		base.jointTiles = !!o.jointTiles;
		if (o.searchRepeat) {
			if (o.repeatPx != null && o.repeatPx !== true) { throw new Error('--searchRepeat searches cfg.repeatLam; drop --repeatPx (it would override it)'); }
			base.searchRepeat = true;
		}
		if (!base.endTile || !base.cornerTile) { throw new Error('joint: cfg.ends needs an END_TILES entry in --engine and cfg.corners a corner tile in ' + (base.singleEngine ? '--engine (single-engine mode needs the merged V6 engine)' : '--engineCorner')); }
	}
	v8Flags(o, base, stage);
	if (o.only && o.only !== true) { base.only = String(o.only).split(',').map(s => s.trim()).filter(Boolean); }
	const primary = o.primary && o.primary !== true ? String(o.primary) : null;
	base.tieBreaks = (stage === 'end' && !!primary || stage === 'joint') && o.tie !== 'off';
	if (stage === 'corner' && !base.cornerTile) { throw new Error('cfg.corners has no tile for this weave in this engine'); }
	if (stage === 'end' && !base.endTile) { throw new Error('cfg.ends has no END_TILES entry for this weave in this engine'); }
	const n = spaceFor(stage, base).length, maxGen = +(o.max || 600), maxRestarts = +(o.restarts == null ? 12 : o.restarts);
	const lam0 = Math.max(+(o.pop || 0), 4 + Math.floor(3 * Math.log(n))), mu = Math.floor(lam0 / 2);
	const nWorkers = +(o.workers || Math.max(2, Math.min(8, os.cpus().length - 2)));
	const P = pool(nWorkers, { audit: o.audit != null ? +o.audit : undefined }), r = rng(+(o.seed || 1));
	const regions = STAGE_REGIONS[stage], sopts = scoringOpts(o);
	if (stage === 'joint') { sopts.joint = true; if (o.engineCorner) { sopts.engineCorner = path.resolve(o.engineCorner); } }
	const clip = x => x.map(v => Math.min(1, Math.max(0, v)));
	// every evaluation carries the base it was decoded against: scatter restarts may switch to a
	// different starting tile, and later restarts from "best" must keep that tile.
	const evalX = async (x, b) => { const xc = clip(x), job = Object.assign(decode(stage, b, xc), { engine, ref: refPath, regions, primary }, sopts); const res = await P.run(job); if (res.repeatLam != null) { job.cfg.repeatLam = res.repeatLam; } return { x: xc, job, res, base: b }; };
	// --race (lazy robustness): with --robust, a generation is first scored at the nominal cfg only; the
	// robustness copies are rendered just for candidates that could still reach the generation's top mu
	// (CMA-ES selects only those) or beat the best. "Could": robust <= nominal + dHi(nominal). The gap
	// robust - nominal falls with the nominal (corr -0.5..-0.8 on the pass-9 populations: a lucky nominal
	// regresses, an unlucky one recovers), so dHi is a least-squares line in the nominal (slope <= 0) plus the
	// largest residual seen in the last 400 fully scored candidates plus --raceMargin (0.005). The first
	// RACE_WARM generations score everyone fully, and every later generation fully scores one random skipped
	// candidate (audit; one that would have made the top mu is logged as a race miss). The top mu get exactly
	// the score the full mode gives them, in the same order, so CMA-ES takes the same steps (checked: seeded
	// runs, every stage, identical per generation); a skipped candidate's logged score is the line's estimate.
	const raceOn = o.race != null && o.race !== 'off' && !!(sopts.robust && sopts.robust.deltas && sopts.robust.deltas.length > 1);
	const RACE_WARM = 3, raceMargin = o.raceMargin != null ? +o.raceMargin : 0.005, dObs = [], rAudit = rng(+(o.seed || 1) * 7919 + 13);
	const nRob = sopts.robust && sopts.robust.deltas ? sopts.robust.deltas.length : 1;
	const raceRef = await getRef(refPath), raceRects = pickRegions({ regions, primary, cap: sopts.cap, weights: sopts.weights }, raceRef.m);
	let renders = 0, rendersFull = 0, raceMiss = 0, raceSkipped = 0;
	const evalNominal = async (x, b) => {
		const xc = clip(x), job = Object.assign(decode(stage, b, xc), { engine, ref: refPath, regions, primary }, sopts);
		const nres = await P.run(Object.assign({}, job, { nominalOnly: true }));
		if (nres.repeatLam != null) { job.cfg.repeatLam = nres.repeatLam; }
		renders++; rendersFull += nRob;
		return { x: xc, job, nres, base: b };
	};
	const finishRobust = async c => {
		if (c.full) { return c; }
		c.full = true;
		if (c.nres.error) { c.res = c.nres; return c; }
		const cfgs = robustCfgs(c.job.cfg, sopts.robust), nomKey = JSON.stringify(c.job.cfg);
		const sets = await Promise.all(cfgs.map((cf, i) => (JSON.stringify(cf) === nomKey ? c.nres.nominalRegs
			: (renders++, P.run(Object.assign({}, c.job, { variant: i, repeatPx: undefined })).then(v => (v.error ? Promise.reject(new Error(v.error)) : v.regs))))))
			.catch(e => null);
		if (!sets) { c.res = { score: 0, error: 'robust variant failed' }; return c; }
		c.res = combineRobust(raceRects, c.nres.nominalRegs, sets);
		if (c.nres.repeatLam != null) { c.res.repeatLam = c.nres.repeatLam; }
		dObs.push({ n: c.res.nominalScore, d: c.res.score - c.res.nominalScore }); if (dObs.length > 400) { dObs.shift(); }
		if (o.raceDump) { fs.appendFileSync(path.resolve(String(o.raceDump)), JSON.stringify({ g, nominal: c.res.nominalScore, robust: c.res.score, copies: c.res.robust }) + '\n'); }
		return c;
	};
	const penOf = raw => raw.reduce((a, v) => a + (v < 0 ? v * v : v > 1 ? (v - 1) ** 2 : 0), 0);
	// one generation, raced: returns the evaluations with .res (full score, or the estimate when skipped)
	const evalGenRaced = async (pop, b, gen) => {
		const ev = await Promise.all(pop.map(async c => Object.assign(await evalNominal(c.x, b), { y: c.y, raw: c.x, sub: c.sub })));
		ev.forEach(e => { e.pen = penOf(e.raw); });
		const muG = Math.floor(ev.length / 2);
		if (gen <= RACE_WARM || dObs.length < 2) { await Promise.all(ev.map(finishRobust)); return { ev, skipped: 0, dHi: null }; }
		const N = dObs.length, mx = dObs.reduce((a, q) => a + q.n, 0) / N, my = dObs.reduce((a, q) => a + q.d, 0) / N;
		let sxy = 0, sxx = 0; dObs.forEach(q => { sxy += (q.n - mx) * (q.d - my); sxx += (q.n - mx) ** 2; });
		const slope = sxx > 0 ? Math.min(0, sxy / sxx) : 0, icpt = my - slope * mx, dFit = nn => icpt + slope * nn;
		const resid = Math.max.apply(null, dObs.map(q => q.d - dFit(q.n))) + raceMargin;
		const dHiOf = nn => dFit(nn) + resid, dHi = resid, lb = e => -(e.nres.score + dHiOf(e.nres.score)) + e.pen;
		const fFull = () => ev.filter(e => e.full).map(e => -e.res.score + e.pen).sort((p, q) => p - q);
		let batch = ev.slice().sort((p, q) => lb(p) - lb(q)).slice(0, muG);
		while (batch.length) {
			await Promise.all(batch.map(finishRobust));
			const T = fFull()[muG - 1];
			batch = ev.filter(e => !e.full && (lb(e) <= T || e.nres.score + dHiOf(e.nres.score) > best.res.score));
		}
		const T = fFull()[muG - 1], rest = ev.filter(e => !e.full);
		if (rest.length) {                                  // audit one skipped candidate
			const a = rest[Math.floor(rAudit() * rest.length)];
			await finishRobust(a); a.audit = true;
			if (!a.res.error && -a.res.score + a.pen <= T) { raceMiss++; console.log(`[${stage}] race miss: a skipped candidate (nominal ${a.nres.score.toFixed(4)}) scored ${a.res.score.toFixed(4)}, inside the top mu; bound ${(a.nres.score + dHiOf(a.nres.score)).toFixed(4)}`); }
		}
		let skipped = 0;
		ev.forEach(e => { if (!e.full) { skipped++; e.res = Object.assign({}, e.nres, { score: e.nres.score + dFit(e.nres.score), raced: true }); } });
		raceSkipped += skipped;
		return { ev, skipped, dHi };
	};
	// correctness gate (see checkGeometry): only a candidate about to become the best is re-rendered at
	// full page and checked at all four positions; it must be no worse than the baseline on every count
	// (the raster fleck gate counts flecks on the full rsvg page: --fleckGate raster / --gateRaster rsvg keep that raster)
	const gateRsvg = o.fleckGate === 'raster' || o.gateRaster === 'rsvg';
	const validate = async c => { const v = await P.run(Object.assign({}, c.job, { validate: true }, gateRsvg ? { gateRaster: 'rsvg' } : {}, holdSpec ? { hold: Object.keys(holdSpec) } : {})); c.diag = v.diag; return c; };
	// V5 verify: a would-be best (and the baseline) is re-scored once, fully, in a fresh engine context. The V4
	// round's end baseline logged 0.6197 but every later scoring of the same job gives 0.5928 (its +0.03 copy
	// came back as 0.629 for both regions); a best that cannot be reproduced must not become the bar.
	// On a mismatch the lower score is kept and logged (verify.jsonl). --verify off skips it.
	let verifyMismatch = 0, g = 0;
	const verify = async c => {
		if (o.verify === 'off' || c.res.error) { return c; }
		const v = await P.run(Object.assign({}, c.job, { persist: false, nominalOnly: false, variant: undefined, validate: false, repeatPx: c.job.cfg.repeatLam != null ? undefined : c.job.repeatPx }));
		if (v.error || Math.abs(v.score - c.res.score) > 1e-6) {
			verifyMismatch++;
			const rec = { gen: g, scored: c.res.score, fresh: v.error ? null : v.score, freshRobust: v.robust, robust: c.res.robust, error: v.error };
			fs.appendFileSync(path.join(outDir, 'verify.jsonl'), JSON.stringify(rec) + '\n');
			console.log(`[${stage}] verify: score ${c.res.score.toFixed(4)} re-scored ${v.error ? 'ERROR' : v.score.toFixed(4)} in a fresh context -- keeping the lower`);
			if (v.error || v.score < c.res.score) { c.res = v.error ? Object.assign({}, c.res, { score: 0 }) : Object.assign(v, { repeatLam: c.res.repeatLam }); }
		}
		return c;
	};
	if (o.fleckTol != null && o.fleckTol !== true) { fleckTol = +o.fleckTol; }
	if (o.fleckGate === 'raster') { fleckGate = 'raster'; }
	if (o.portGapTol != null && o.portGapTol !== true) { portGapTol = +o.portGapTol; }
	if (o.wrapDentTol != null && o.wrapDentTol !== true) { wrapDentTol = +o.wrapDentTol; }
	holdSpec = parseHold(o);   // V12 --hold / --sideFloor
	if (holdSpec) { console.log(`[${stage}] hold gate: ${Object.keys(holdSpec).map(k => k + (holdSpec[k] != null ? ' >= min(' + holdSpec[k] + ', baseline)' : ' >= baseline')).join(', ')} - ${holdTol} (nominal, period tol ${HOLD_PTOL})`); }
	// V10 --stretchGate [abs|rel][:tol] | off: the run-stretch gate (runStretch); default abs on joint / weave, rel elsewhere, tol 0.08
	{ const sg = o.stretchGate == null || o.stretchGate === true ? '' : String(o.stretchGate), m = sg.match(/^(abs|rel)?:?([0-9.]+)?$/);
		if (sg === 'off') { stretchTol = null; } else if (!m) { throw new Error('--stretchGate: abs|rel[:tol] | tol | off'); } else { if (m[2]) { stretchTol = +m[2]; } stretchAbs = m[1] ? m[1] === 'abs' : (stage === 'joint' || stage === 'weave'); }
		console.log(`[${stage}] run-stretch gate: ${stretchTol == null ? 'off' : (stretchAbs ? 'absolute' : 'vs baseline') + ', tol ' + stretchTol}`); }
	// V8 --choose: discrete choices are scored option by option up front (in parallel, at the start point) and the best
	// gate-clean one is fixed for the run, instead of being a CMA dimension that cannot jump between modes
	if (o.choose && o.choose !== true) {
		const ch = await chooseCategorical(String(o.choose), base, async b => validate(await evalX(initVector(stage, b), b)), gateFails, stage);
		Object.keys(ch.base).forEach(k => { base[k] = ch.base[k]; });
		fs.writeFileSync(path.join(outDir, 'choose.json'), JSON.stringify(ch.table, null, 1));
	}
	const baseline = await validate(await verify(await evalX(initVector(stage, base), base)));
	const baseDiag = baseline.diag;
	let rejected = 0;
	// V8: a baseline that fails an absolute gate (endFallback) is no bar to beat -- any gate-clean candidate replaces it
	const baseBad = gateFails(baseDiag, baseDiag);
	if (baseBad.length) { console.log(`[${stage}] WARNING baseline fails an absolute gate (${baseBad.join('; ')}): its score ${baseline.res.score.toFixed(4)} is not a bar; the first gate-clean candidate becomes the best`); baseline.res = Object.assign({}, baseline.res, { score: -1, rawScore: baseline.res.score }); }
	const accept = async c => {                   // validated candidate may replace best?
		if (!(c.res.score > best.res.score)) { return false; }
		await verify(c);
		if (!(c.res.score > best.res.score)) { return false; }
		await validate(c);
		const bad = gateFails(c.diag, baseDiag);
		if (bad.length) { rejected++; c.rejected = bad; console.log(`[${stage}] gate rejected ${c.res.score.toFixed(4)}: ${bad.slice(0, 4).join('; ')}`); return false; }
		best = c; return true;
	};
	let best = baseline; const log = [], topByGen = [];
	const t0 = Date.now(); let stopReason = 'max generations', evals = 1;
	// Search width. Probing the corner best (44-D): N(0, 0.005..0.015) perturbations score at or above the
	// best (0.440-0.446), 0.04 drops to 0.385-0.436, 0.1 to 0.36-0.42 -- the optimum is a narrow ridge
	// (the weave phase / tile fit), so the old 0.15-0.22 sampled only the plateau below it and the mean
	// walked off the ridge; no run since round 2 improved. Local search starts narrow.
	const sigma0 = +(o.sigma || 0.03);
	const seeds = seedsFor(stage, base, engine);           // "quite different" starting points for scatter restarts
	console.log(`[${stage}] baseline ${baseline.res.score.toFixed(4)}${primary ? ' (primary ' + primary + ')' : ''}  diag ${JSON.stringify(baseDiag)}`);
	console.log(`[${stage}] (${n} params, CMA-ES pop ${lam0}; restart cycle local/swing/scatter, ${seeds.length} scatter seeds)`);
	// CMA-ES with a diversifying restart schedule. A run ends after its search stops improving (see
	// the significance rule below). Restarts then cycle through three kinds:
	//   local   -- from the best point, search width sigma0, population doubled each cycle (IPOP);
	//   swing   -- from the best point with a 3x wider search: a bigger swing at the same design;
	//   scatter -- from a quite different seed: another tile design in the engine, the current tile at
	//              a shifted weave phase or break position, or the best of a random scouting round.
	// Inside a run, when gains are slowing (still significant, but under 2x MIN_GAIN per window) and the
	// search has narrowed below its start width, the width is doubled (capped at 2x start) once per
	// window -- a kick out of a narrowing valley.
	// It stops for good when a full cycle (three consecutive restarts) adds less than MIN_GAIN, or at
	// --restarts / --max. Significance: the selected (top-mu) scores pooled over the last WINDOW
	// generations vs the WINDOW before (one-sided Welch), or a best-score gain of MIN_GAIN in WINDOW.
	let failStreak = 0, cycle = 0, seedIdx = 0;
	const minGen = (lam, nn) => (o.minGen != null ? +o.minGen : Math.ceil(10 + 30 * (nn || n) / lam));
	const probation = o.probation != null && o.probation !== true ? +o.probation : 0;
	// V9 (outside review, km/expt/review.md, ranked change 1): near the bests the score lies on a narrow smooth ridge;
	// CMA-ES at sigma ~0.03 samples ~10x too wide (its population averages 0.13-0.18 below the best) and the kick grew
	// sigma. Opt-in switches (without them a run is V8's, step for step):
	//   --polish N [--polishSigma 0.003] [--polishLam k] [--polishFinal M]: an elitist (1+lambda)-ES with the 1/5th success
	//     rule, sigma floor POLISH_FLOOR, after every CMA-ES run (N evaluations, skipped when the best has not moved since
	//     the last polish) and as a final phase (M, default N). Every would-be best goes through accept() (verify + gate).
	//   --kick off: no sigma kick inside a run (tile stages: use with --sigma 0.005).
	//   --legFirst: (corner / joint) a first CMA-ES run (+ polish) over the leg-phase keys only (LEG_RE: the port phase and
	//     repeat, the break, the top run's repeat, endSlide) -- the braid legs fill 60-80% of the TL / top-L boxes and sat at
	//     0.68-0.78 there -- before the full space.
	//   --cma off: no CMA-ES at all (baseline, then the polish phase); --maxEvals E: stop at E evaluations (comparisons).
	const polishN = o.polish != null && o.polish !== true ? +o.polish : 0;
	const polishFinal = o.polishFinal != null && o.polishFinal !== true ? +o.polishFinal : polishN;
	const polishSig0 = o.polishSigma != null && o.polishSigma !== true ? +o.polishSigma : 0.003;
	const polishLam = o.polishLam != null && o.polishLam !== true ? Math.max(1, +o.polishLam) : nWorkers;
	// --polishSparse p: each child moves each dim with probability p (at least one) -- a coordinate-subset polish for the
	// 50-100-D tile / joint spaces, where an isotropic step mixes every dim (default 1 = isotropic)
	const polishSparse = o.polishSparse != null && o.polishSparse !== true ? Math.min(1, Math.max(0, +o.polishSparse)) : 1;
	// V10 --polishParents K: after each CMA-ES run the polish starts from the K best distinct, fully scored, gate-unchecked
	// candidates of that run (the incumbent first), each with budget / K; a child that beats its own parent moves that
	// parent, one that beats the best goes through accept() as always. 1 (default) = the V9 polish from the best only.
	const polishParents = o.polishParents != null && o.polishParents !== true ? Math.max(1, Math.floor(+o.polishParents)) : 1;
	let runElite = [];
	const noteElite = ev => {
		if (polishParents < 2) { return; }
		ev.forEach(e => {
			if (!e.res || e.res.raced || e.res.error || e.f === 1 || !e.x) { return; }
			if (runElite.some(q => q.base === e.base && Math.hypot.apply(null, q.x.map((v, i) => v - e.x[i])) < 1e-3)) { return; }
			runElite.push({ x: e.x.slice(), score: e.res.score, base: e.base });
		});
		runElite.sort((p2, q2) => q2.score - p2.score); runElite = runElite.slice(0, 4 * polishParents);
	};
	const multiStart = o.multiStart && o.multiStart !== true ? String(o.multiStart).split(':').map(Number) : null;   // --multiStart K:G
	const noKick = o.kick === 'off', cmaOff = o.cma === 'off', maxEvals = o.maxEvals != null && o.maxEvals !== true ? +o.maxEvals : Infinity;
	const legIdx = o.legFirst && (stage === 'corner' || stage === 'joint') ? spaceFor(stage, base).map((s, i) => (LEG_RE.test(s.key) ? i : -1)).filter(i => i >= 0) : null;
	if (legIdx) { console.log(`[${stage}] legFirst: ${legIdx.length} leg-phase keys first: ${legIdx.map(i => spaceFor(stage, base)[i].key).join(', ')}`); }
	let polishEvals = 0, polishGain = 0, polishedAt = null;
	const writeBest = () => fs.writeFileSync(path.join(outDir, 'best.json'), JSON.stringify({ stage, primary, score: best.res.score, periodTol: sopts.periodTol, robust: sopts.robust, refJitter: sopts.refJitter, cap: sopts.cap, repeatPx: sopts.repeatPx, weights: sopts.weights, robustScores: best.res.robust, diag: best.diag || null, regions: best.res.regions, cfg: best.job.cfg, consts: best.job.consts, cornerTile: best.job.cornerTile || null, endTile: best.job.endTile || null, x: best.x }, null, 1));
	// (1+lambda)-ES polish from the incumbent: lambda children N(x, sigma^2 I) (only the dims in idx, if given) scored
	// fully (robust); the best child that beats the incumbent AND passes accept() replaces it. sigma x1.5 on a success,
	// x1.5^(-lambda/4) on a failure (the 1/5th rule per trial), clamped to [POLISH_FLOOR, POLISH_CAP]; it ends at the
	// budget, or after POLISH_STALL evaluations without a success at the floor.
	const polish = async (budget, label, idx, parent) => {
		if (!(budget > 0) || evals >= maxEvals) { return 0; }
		const s0 = best.res.score, b = parent ? parent.base : best.base, t1 = Date.now();
		let sig = polishSig0, used = 0, wins = 0, since = 0, x = (parent ? parent.x : best.x).slice(), inc = parent ? parent.score : best.res.score;
		console.log(`[${stage}] polish (${label}): from ${(parent ? parent.score : s0).toFixed(4)}${parent ? ' (parent; best ' + s0.toFixed(4) + ')' : ''}, ${budget} evaluations, (1+${polishLam}) sigma ${sig}${idx ? ', ' + idx.length + ' keys' : ''}`);
		while (used < budget && evals < maxEvals) {
			const lamP = Math.min(polishLam, budget - used);
			const kids = Array.from({ length: lamP }, () => {
				const dims = (idx || x.map((_, i) => i)), mv = polishSparse < 1 ? dims.filter(() => r() < polishSparse) : dims;
				if (!mv.length) { mv.push(dims[Math.floor(r() * dims.length)]); }
				const y = x.slice(); mv.forEach(i => { y[i] += sig * gauss(r); }); return clip(y);
			});
			const ev = await Promise.all(kids.map(k => evalX(k, b)));
			used += ev.length; evals += ev.length; polishEvals += ev.length; renders += ev.length * nRob; rendersFull += ev.length * nRob;
			ev.sort((p, q) => q.res.score - p.res.score);
			let won = false;
			for (const e of ev) {
				if (!(e.res.score > inc)) { break; }
				if (e.res.score > best.res.score) { if (await accept(e)) { won = true; x = best.x.slice(); inc = best.res.score; writeBest(); break; } continue; }
				if (parent && !e.res.raced && !e.res.error) { won = true; x = e.x.slice(); inc = e.res.score; break; }   // V10: the parent moves (not a best)
			}
			if (won) { wins++; since = 0; } else { since += lamP; }
			sig = Math.min(POLISH_CAP, Math.max(POLISH_FLOOR, sig * (won ? 1.5 : Math.pow(1.5, -lamP / 4))));
			const row = { polish: label, used, best: best.res.score, genBest: ev[0].res.score, sigma: +sig.toFixed(5), wins, evals, sec: (Date.now() - t0) / 1000 };
			fs.appendFileSync(path.join(outDir, 'log.jsonl'), JSON.stringify(row) + '\n');
			if (used % (8 * lamP) < lamP || won) { console.log(`[${stage}] polish ${label} ${String(used).padStart(4)}  best ${best.res.score.toFixed(4)}  child ${ev[0].res.score.toFixed(4)}  sigma ${sig.toFixed(4)}${won ? '  +' : ''}`); }
			if (sig <= POLISH_FLOOR + 1e-12 && since >= POLISH_STALL) { break; }
		}
		const gain = best.res.score - s0; polishGain += gain;
		fs.appendFileSync(path.join(outDir, 'runs.jsonl'), JSON.stringify({ polish: label, evaluations: used, wins, gained: gain, best: best.res.score, seconds: (Date.now() - t1) / 1000 }) + '\n');
		console.log(`[${stage}] polish (${label}) gained +${gain.toFixed(4)} in ${used} evaluations (${wins} wins)`);
		polishedAt = idx ? null : best;    // a leg-only polish does not count as polished
		return gain;
	};
	for (let rs = legIdx ? -1 : 0; rs <= maxRestarts && !cmaOff; rs++) {
		const kind = rs === -1 ? 'legs' : rs === 0 ? 'initial' : ['local', 'swing', 'scatter'][(rs - 1) % 3];
		if (kind === 'local' && rs > 1) { cycle++; }
		let startX = best.x, startBase = best.base, sig = sigma0, label = kind;
		if (kind === 'initial' && !legIdx) { startX = baseline.x; startBase = baseline.base; }
		if (kind === 'swing') { sig = Math.min(0.5, sigma0 * 3); }
		if (kind === 'scatter') {
			const sd = seeds[seedIdx++ % Math.max(1, seeds.length)];
			if (sd && sd.base) { startBase = sd.base; startX = initVector(stage, sd.base); sig = sigma0 * 2; label = 'scatter: ' + sd.label; }
			else {                                       // random scouting round: best of 2*lam0 uniform points
				const scouts = await Promise.all(Array.from({ length: 2 * lam0 }, () => evalX(Array.from({ length: n }, () => r()), best.base)));
				evals += scouts.length; scouts.sort((a, b) => b.res.score - a.res.score);
				startX = scouts[0].x; startBase = best.base; label = 'scatter: random scout (best ' + scouts[0].res.score.toFixed(4) + ')';
				for (const sc of scouts) { if (!(sc.res.score > best.res.score) || await accept(sc)) { break; } }
			}
		}
		const lam = kind === 'legs' ? Math.max(6, 4 + Math.floor(3 * Math.log(legIdx.length))) : Math.min(96, lam0 * Math.pow(2, kind === 'local' ? cycle + 1 : (kind === 'initial' ? 0 : cycle)));
		let es = kind === 'legs' ? subES(startX, legIdx, sig, lam, r) : cmaes(startX, sig, lam, r); const nRun = kind === 'legs' ? legIdx.length : n;
		// V9 --multiStart K:G (initial run; perf3's end-stage trial: 4 short x 8 generations then continuing the best for 32
		// averaged 0.701 vs 0.665 for one long run, same budget): K independent CMA-ES searches from the start, G generations
		// each (no stop test inside), then the run continues the one whose generations scored best, under the normal rules.
		const ms = kind === 'initial' && multiStart ? { K: multiStart[0], G: multiStart[1], list: [es], top: [] } : null;
		if (ms) { for (let k = 1; k < ms.K; k++) { ms.list.push(cmaes(startX, sig, lam, r)); } ms.top = ms.list.map(() => -Infinity); console.log(`[${stage}] multiStart: ${ms.K} searches x ${ms.G} generations, then the best continues`); }
		const bestAtStart = best.res.score; let gIn = 0, lastKick = -1e9, runBest = -1; const runHist = [];
		console.log(`[${stage}] run ${rs} (${label}): pop ${lam}, sigma ${sig < 0.01 ? sig.toFixed(4) : sig.toFixed(2)}`);
		while (g < maxGen && evals < maxEvals) {
			g++; gIn++;
			const blk = ms && gIn <= ms.K * ms.G ? Math.floor((gIn - 1) / ms.G) : -1;
			if (blk >= 0) { es = ms.list[blk]; }
			const pop = es.ask();
			let ev, race = null;
			if (raceOn) { race = await evalGenRaced(pop, startBase, g); ev = race.ev; }
			else { ev = await Promise.all(pop.map(async c => Object.assign(await evalX(c.x, startBase), { y: c.y, raw: c.x, sub: c.sub }))); renders += ev.length * nRob; rendersFull += ev.length * nRob; }
			evals += ev.length;
			ev.forEach(e => { const pen = penOf(e.raw); e.f = -e.res.score + pen; });
			ev.sort((a, b) => a.f - b.f);
			for (const e of ev) {                      // best-first: gate each would-be best until one passes
				if (!(e.res.score > best.res.score)) { break; }
				if (await accept(e)) { break; }
				e.f = 1;                                // failed the gate: ranks last for the update
			}
			ev.sort((a, b) => a.f - b.f);
			noteElite(ev);   // V10 --polishParents
			es.tell(ev.map(e => ({ x: e.raw, y: e.y, sub: e.sub })));
			topByGen.push(ev.slice(0, mu).map(e => (e.f === 1 ? 0 : e.res.score)));
			const scores = ev.map(e => e.res.score), avg = scores.reduce((a, b) => a + b, 0) / scores.length;
			const row = { gen: g, restart: rs, kind, best: best.res.score, genBest: scores[0], mean: avg, sd: Math.sqrt(scores.reduce((a, s) => a + (s - avg) ** 2, 0) / scores.length), sigma: es.sigma, lam, evalsPerSec: +(evals / ((Date.now() - t0) / 1000)).toFixed(2), sec: (Date.now() - t0) / 1000, renders, rendersFull };
			if (race) { row.raced = race.skipped; if (race.dHi != null) { row.dHi = +race.dHi.toFixed(4); } }
			const runTop = ev.slice(0, mu).filter(e => e.f !== 1).map(e => e.res.score);
			runHist.push(runTop.length ? runTop.reduce((a, v) => a + v, 0) / runTop.length : 0); runBest = Math.max(runBest, scores[0]);
			if (gIn >= 2 * WINDOW) {
				const pool5 = (a, b) => [].concat.apply([], topByGen.slice(a, b));
				const p = welchOneSided(pool5(g - WINDOW, g), pool5(g - 2 * WINDOW, g - WINDOW)), gain = best.res.score - log[g - 1 - WINDOW].best;
				row.p = p; row.gain5 = gain; row.significant = p < 0.05 || gain >= MIN_GAIN;
				// kick only a search that has narrowed below its start width, and never past 2x it: on these
				// ridge landscapes a wide search only samples the plateau, and the old uncapped kick
				// compounded (the population's recovery after a kick read as 'significant' -> kick again;
				// the corner run reached sigma 0.27)
				if (!noKick && row.significant && gain < 2 * MIN_GAIN && g - lastKick >= WINDOW && es.sigma < sig) { es.sigma = Math.min(2 * sig, es.sigma * 2); lastKick = g; row.kick = true; }
			}
			log.push(row);
			fs.appendFileSync(path.join(outDir, 'log.jsonl'), JSON.stringify(row) + '\n');
			console.log(`[${stage}] r${rs} gen ${String(g).padStart(3)}  best ${row.best.toFixed(4)}  gen-best ${row.genBest.toFixed(4)}  mean ${avg.toFixed(4)}  sigma ${es.sigma.toFixed(3)}` + (row.p != null ? `  p=${row.p.toFixed(3)} gain5=${row.gain5.toFixed(4)}${row.significant ? '' : '  (not significant)'}${row.kick ? '  KICK' : ''}` : ''));
			writeBest();
			// a run may not stop before CMA-ES has had time to learn its covariance: Hansen's stagnation
			// horizon 10 + 30n/lambda generations (44 tile parameters at pop 15 -> 98). The old 10-generation
			// floor ended runs on the 44-D tile spaces while the population was still far from the best.
			// swing / scatter restarts get a third of that floor: in passes 6-8 they never produced a gain
			// (every one ran its full horizon for nothing), so they are now cheap probes -- a probe that
			// finds a rising slope keeps going under the normal significance rule
			const floor = (kind === 'swing' || kind === 'scatter') ? Math.ceil(minGen(lam) / 3) : minGen(lam, nRun);
			if (blk >= 0) {
				ms.top[blk] = Math.max(ms.top[blk], ev[0].f === 1 ? -Infinity : ev[0].res.score);
				if (gIn === ms.K * ms.G) { const w = ms.top.indexOf(Math.max.apply(null, ms.top)); es = ms.list[w]; console.log(`[${stage}] multiStart: search ${w} continues (block bests ${ms.top.map(v => v.toFixed(4)).join(' ')})`); }
				continue;                               // no stop test while the short searches run
			}
			if (gIn >= Math.max(2 * WINDOW, floor) && !row.significant) { break; }
			// --probation P (swing / scatter): at generation P of the run it goes on only if it is tracking toward
			// the incumbent: its best is within MIN_GAIN of it, or the gap between the incumbent and the run's
			// selected (top-mu) mean is closing -- at least halved since the run's first WINDOW generations, at
			// a rate that reaches the incumbent within 2P more generations. In passes 6-9 no swing or scatter
			// run ever produced a gain; this ends a run that is not even heading there.
			if (probation > 0 && (kind === 'swing' || kind === 'scatter') && gIn === probation) {
				const inc = best.res.score, avgOf = a => a.reduce((x, v) => x + v, 0) / a.length;
				const gapE = inc - avgOf(runHist.slice(0, WINDOW)), gapL = inc - avgOf(runHist.slice(-WINDOW)), rate = (gapE - gapL) / Math.max(1, gIn - WINDOW);
				const tracking = runBest >= inc - MIN_GAIN || (gapL <= 0.5 * gapE && rate > 0 && gapL / rate <= 2 * probation);
				const pr = { run: rs, gen: g, gapEarly: +gapE.toFixed(4), gapLate: +gapL.toFixed(4), runBest: +runBest.toFixed(4), incumbent: +inc.toFixed(4), tracking };
				fs.appendFileSync(path.join(outDir, 'runs.jsonl'), JSON.stringify(Object.assign({ probation: true }, pr)) + '\n');
				console.log(`[${stage}] probation at gen ${gIn} of run ${rs}: gap ${gapE.toFixed(4)} -> ${gapL.toFixed(4)}, run best ${runBest.toFixed(4)} vs ${inc.toFixed(4)} -> ${tracking ? 'continue' : 'end run'}`);
				if (!tracking) { break; }
			}
		}
		const cmaGained = best.res.score - bestAtStart;
		fs.appendFileSync(path.join(outDir, 'runs.jsonl'), JSON.stringify({ run: rs, kind: label, generations: gIn, gained: cmaGained, best: best.res.score }) + '\n');
		// V9 --polish: a small-step polish of every run's result (the run's gain then includes it); legs: over the leg keys only
		if (polishN > 0 && polishParents > 1 && kind !== 'legs' && runElite.length) {
			// V10 --polishParents: the incumbent and the run's next best distinct candidates, budget / K each
			const per = Math.max(1, Math.floor(polishN / polishParents)), others = runElite.filter(q => !(q.base === best.base && Math.hypot.apply(null, q.x.map((v, i) => v - best.x[i])) < 1e-3)).slice(0, polishParents - 1);
			if (best !== polishedAt) { await polish(per, 'run ' + rs); }
			for (let pi = 0; pi < others.length; pi++) { await polish(per, 'run ' + rs + ' parent ' + (pi + 2), null, others[pi]); }
			polishedAt = best; runElite = [];
		} else if (polishN > 0 && best !== polishedAt) { await polish(polishN, kind === 'legs' ? 'legs' : 'run ' + rs, kind === 'legs' ? legIdx : null); }
		runElite = [];
		const gained = best.res.score - bestAtStart;
		failStreak = (rs > 0 && gained < MIN_GAIN) ? failStreak + 1 : 0;
		if (evals >= maxEvals) { stopReason = `evaluation budget ${maxEvals} used`; break; }
		if (g >= maxGen) { stopReason = 'max generations'; break; }
		if (failStreak >= 3) { stopReason = `a full local/swing/scatter cycle found no significant improvement; stopped at gen ${g} after ${rs} restarts`; break; }
		if (rs === maxRestarts) { stopReason = `all ${maxRestarts} restarts used; stopped at gen ${g}`; break; }
		console.log(`[${stage}] run ${rs} gained +${gained.toFixed(4)} (fail streak ${failStreak})`);
	}
	if (cmaOff) { stopReason = 'polish only (--cma off)'; }
	if (polishFinal > 0 && best !== polishedAt) { await polish(polishFinal, 'final'); }
	writeBest();
	P.close();
	const summary = { stage, primary, baseline: baseline.res.score, best: best.res.score, generations: log.length, evaluations: evals, gateRejected: rejected, verifyMismatch, renders, rendersFull, race: raceOn ? { skipped: raceSkipped, misses: raceMiss, margin: raceMargin } : null, seconds: (Date.now() - t0) / 1000, polish: polishN || polishFinal ? { evaluations: polishEvals, gained: polishGain } : null, baselineDiag: baseDiag, bestDiag: best.diag || null, stopReason, baselineRegions: baseline.res.regions, bestRegions: best.res.regions };
	fs.writeFileSync(path.join(outDir, 'summary.json'), JSON.stringify(summary, null, 1));
	const job0 = Object.assign({}, baseline.job, { engine, ref: refPath }, sopts), job1 = Object.assign({}, best.job, { engine, ref: refPath }, sopts);
	const snap = stage === 'joint' ? (j, f) => snapshotJoint(j, f) : (j, f) => snapshot(j, f, regions);
	const s0 = await snap(job0, path.join(outDir, 'baseline-regions.png'));
	const s1 = await snap(job1, path.join(outDir, 'best-regions.png'));
	if (s1.svgCorner) { fs.writeFileSync(path.join(outDir, 'best-corner.svg'), s1.svgCorner); }
	fs.writeFileSync(path.join(outDir, 'best.svg'), s1.svg);
	fs.writeFileSync(path.join(outDir, 'baseline.svg'), s0.svg);
	console.log(`[${stage}] done: ${summary.baseline.toFixed(4)} -> ${summary.best.toFixed(4)} in ${log.length} generations; ${stopReason}`);
	return summary;
}

// ---------------------------------------------------------------- CLI
// --periodTol 0.04 / --robust band.width:-0.03,0,0.03 (see regionScoreTol / robustCfgs); a show without
// them uses what the best.json was scored with
function scoringOpts(o, saved) {
	saved = saved || {};
	const out = {};
	const tol = o.periodTol != null && o.periodTol !== true ? +o.periodTol : saved.periodTol;
	if (tol > 0) { out.periodTol = tol; }
	let rb = saved.robust || null;
	if (o.robust === 'off') { rb = null; }
	else if (o.robust && o.robust !== true) { const [key, ds] = String(o.robust).split(':'); rb = { key, deltas: ds.split(',').map(Number) }; }
	if (rb && o.robustPin && o.robustPin !== 'off') { rb = Object.assign({}, rb, { pinPx: true }); }
	if (rb) { out.robust = rb; }
	const rp = o.repeatPx != null && o.repeatPx !== true ? +o.repeatPx : saved.repeatPx;
	if (rp > 0) { out.repeatPx = rp; }
	const rj = o.refJitter === 'off' ? 0 : o.refJitter != null && o.refJitter !== true ? +o.refJitter : o.refJitter === true ? 0.5 : saved.refJitter;   // V13
	if (rj > 0) { out.refJitter = rj; }
	const cap = o.cap != null && o.cap !== true ? +o.cap : saved.cap;
	if (cap > 0) { out.cap = cap; }
	// --weights side:0.4,end:0.3,corner:0.3 (joint stage)
	let wts = saved.weights || null;
	if (o.weights && o.weights !== true) { wts = {}; String(o.weights).split(',').forEach(kv => { const [k, v] = kv.split(':'); wts[k.trim()] = +v; }); }
	if (wts) { out.weights = wts; }
	// --persist: keep one engine context per worker (see buildPersistent); a speed switch only, never saved
	if (o.persist && o.persist !== 'off') { out.persist = true; }
	// --raster js: score with the in-process rasteriser (raster.cjs) instead of rsvg-convert; a speed switch, never saved
	if (o.raster && o.raster !== true && o.raster !== 'rsvg') { out.raster = String(o.raster); }
	return out;
}
async function main() {
	const o = args(process.argv.slice(2)), cmd = o._[0];
	if (cmd === 'worker') {
		process.on('message', async job => {
			const h = jobHash(job);                      // before scoreCandidate (it adds fields to the job)
			try { process.send(Object.assign(await scoreCandidate(job), { jobHash: h })); } catch (e) { process.send({ score: 0, error: String(e && e.stack || e), jobHash: h }); }
		});
		return;
	}
	if (cmd === 'score') {
		const job = Object.assign({ engine: path.resolve(o.engine), ref: path.resolve(o.ref || DEFAULT_REF), cfg: JSON.parse(fs.readFileSync(o.cfg, 'utf8')), consts: {}, regions: o.regions || 'all' }, scoringOpts(o));
		const res = await scoreCandidate(job);
		if (o.out) { fs.mkdirSync(o.out, { recursive: true }); await snapshot(job, path.join(o.out, 'regions.png'), job.regions); }
		console.log(JSON.stringify({ score: +res.score.toFixed(4), error: res.error, regions: (res.regions || []).map(r => ({ name: r.name, score: +r.score.toFixed(4), fillIoU: +r.fill.toFixed(3), inkIoU: +r.ink.toFixed(3), silIoU: +r.sil.toFixed(3), chamferBand: +r.chamferBand.toFixed(4), shift: [r.dx, r.dy] })) }, null, 1));
		return;
	}
	if (cmd === 'optimize') { await optimize(o); return; }
	if (cmd === 'period') {               // side-run repeat (raster px) of Ash and of each given page.png
		const ref = await getRef(path.resolve(o.ref || DEFAULT_REF));
		const pages = o._.slice(1);
		console.log(JSON.stringify({ ash: measurePeriod(ref.cm, ref.m) }));
		for (const f of pages) { console.log(JSON.stringify({ [f]: measurePeriod(classMap(PNG.sync.read(fs.readFileSync(f))), ref.m) })); }
		return;
	}
	if (cmd === 'show') {                 // re-render a saved best.json: region composite + full page PNG + score
		const b = JSON.parse(fs.readFileSync(o.best, 'utf8')), out = path.resolve(o.out); fs.mkdirSync(out, { recursive: true });
		const job = Object.assign({ engine: path.resolve(o.engine), ref: path.resolve(o.ref || DEFAULT_REF), cfg: b.cfg, consts: b.consts || {}, cornerTile: b.cornerTile || undefined, endTile: b.endTile || undefined, regions: o.regions || STAGE_REGIONS[b.stage] || 'all', primary: o.primary && o.primary !== true ? String(o.primary) : null }, scoringOpts(o, b));
		// a joint best: two-engine with --engineCorner, single-engine (merged V6 engine) without
		if (b.stage === 'joint') { if (o.engineCorner === true) { throw new Error('--engineCorner needs a path'); } Object.assign(job, { joint: true, regions: 'joint' }, o.engineCorner ? { engineCorner: path.resolve(o.engineCorner) } : {}); }
		const res = await scoreCandidate(job), snap = job.joint ? await snapshotJoint(job, path.join(out, 'regions.png')) : await snapshot(job, path.join(out, 'regions.png'), job.regions);
		if (snap.svgCorner) { fs.writeFileSync(path.join(out, 'page-corner.svg'), snap.svgCorner); }
		fs.writeFileSync(path.join(out, 'page.svg'), snap.svg);
		fs.writeFileSync(path.join(out, 'page.png'), PNG.sync.write(await rasterize(snap.svg, RASTER_W, RASTER_H)));
		const v = await scoreCandidate(Object.assign({}, job, { validate: true }));
		fs.writeFileSync(path.join(out, 'diag.json'), JSON.stringify(v.diag, null, 1));
		Object.keys(v.diag || {}).filter(k => /zones$/.test(k)).forEach(k => console.log('zones ' + k + ' (conf, tile zone ' + ZONE_K + ' band vs legs): ' + JSON.stringify(v.diag[k])));   // V10
		if (v.diag && v.diag.checks) { Object.keys(v.diag.checks).filter(k => /runs$/.test(k)).forEach(k => console.log('run stretch ' + k + ': worst ' + v.diag.checks[k].worst + (v.diag.checks[k].warpWorst != null ? ' (warp ' + v.diag.checks[k].warpWorst + ')' : '') + ', beyond tol ' + stretchCount(v.diag.checks[k]))); }
		console.log(JSON.stringify({ saved: b.score, rescored: +res.score.toFixed(4), robust: res.robust, regions: res.regions.map(r => [r.name, +r.score.toFixed(3)].concat(r.scale && r.scale !== 1 ? ['x' + r.scale] : [])), diag: v.diag }));
		return;
	}
	console.error('usage: knotmatch.cjs score|optimize|show --engine <scroll-knot.js> --cfg <cfg.json> [...]'); process.exit(2);
}
module.exports = { runStretch, v8Flags, traceFit, traceRedraw, traceChains, traceFrameEnd, nearestOn, tfEnvEnd, tfEnvCorner, tfClassEnd, tfClassCorner, v7CfgFlags, squareCorner, squareWrap, fleckRuns, gateFails, scoreJoint, jointRegions, validateJoint, pool, hairpinChecks, wrapChecks, fairWrap, cornerChecks, curlChecks, foldWarp, regionScoreTol, classMapCropped, checkGeometry, measureRef, pickRegions, loadEngine, renderSvg, classMap, rasterize, regionScore, regionsFor, scanBox, getRef, refDTFor, welchOneSided, displace, decode, spaceFor, cmaes, jacobiEigen, rng, DEFAULT_REF, seedsFor, initVector, baseTiles, scoreCandidate, combineRobust, robustCfgs, engineFor, persistentEngine, buildOverrides };
if (require.main === module) { main().catch(e => { console.error(e); process.exit(1); }); }
