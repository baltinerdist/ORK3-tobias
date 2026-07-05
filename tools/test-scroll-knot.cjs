/* Node geometry tests for scroll-knot.js. Run: node tools/test-scroll-knot.cjs */
'use strict';
const fs = require('fs'), path = require('path');
const src = fs.readFileSync(path.join(__dirname, '../orkui/template/revised-frontend/scroll/scroll-knot.js'), 'utf8');
eval(src);                                   // IIFE attaches ScrollKnot to globalThis (no window in node)
const K = globalThis.ScrollKnot, G = K._geom;
let n = 0, bad = 0;
function ok(cond, msg) { n++; if (!cond) { bad++; console.error('FAIL: ' + msg); } }
function near(a, b, eps, msg) { ok(Math.abs(a - b) <= (eps || 1e-6), msg + ' (' + a + ' vs ' + b + ')'); }

// ---- norm(): defaults fill in
const cfg = G.norm({ enabled: true, pattern: 'plait' });
ok(cfg.band.inset === 2 && cfg.band.width === 6, 'norm band defaults');
ok(cfg.strands.count === 3 && cfg.strands.thickness === 0.55 && cfg.strands.gap === 0.12 && cfg.strands.scale === 1, 'norm strand defaults');
ok(Array.isArray(cfg.colors.strands) && cfg.colors.strands.length >= 1 && /^#/.test(cfg.colors.outline), 'norm color defaults');
ok(cfg.gradient.enabled === false && cfg.autoBreak.enabled === true, 'norm gradient/autoBreak defaults');

// ---- frameLayout(): portrait letter
const L1 = G.frameLayout(cfg, 816, 1056);
near(L1.S, 816, 0, 'S = min(W,H)');
near(L1.inset, 816 * 0.02, 1e-9, 'inset px');
near(L1.band, 816 * 0.06, 1e-9, 'band px');
near(L1.edges.top.len, (816 - 2 * L1.inset) - 2 * L1.band, 1e-9, 'top run excludes corner boxes');
near(L1.edges.left.len, (1056 - 2 * L1.inset) - 2 * L1.band, 1e-9, 'left run excludes corner boxes');
// toPage: top edge u along +x, v along +y
const p0 = G.toPage(L1.edges.top, 0, 0);
near(p0[0], L1.inset + L1.band, 1e-9, 'top origin x');
near(p0[1], L1.inset, 1e-9, 'top origin y');

// ---- spine(): centerline rounded-rect table (spec §7 item 1)
const SPN1 = G.spine(cfg, 816, 1056);
const cwSpn = SPN1.cx1 - SPN1.cx0, chSpn = SPN1.cy1 - SPN1.cy0;
near(SPN1.S, 2 * (cwSpn + chSpn) - 8 * SPN1.R + 2 * Math.PI * SPN1.R, 0.5, 'spine total length formula');
let badNormal = 0;
SPN1.table.forEach(function (p) { if (Math.abs(Math.hypot(p.nx, p.ny) - 1) > 0.02) { badNormal++; } });
ok(badNormal === 0, 'spine normals are unit length, got ' + badNormal + ' bad of ' + SPN1.table.length);
const atMid = G.spineAt(SPN1.table, SPN1.S, SPN1.S * 0.5);
const atMidWrapped = G.spineAt(SPN1.table, SPN1.S, SPN1.S * 0.5 + SPN1.S * 3);
near(atMid.x, atMidWrapped.x, 0.5, 's wraps mod total length (x)');
near(atMid.y, atMidWrapped.y, 0.5, 's wraps mod total length (y)');
const atZero = G.spineAt(SPN1.table, SPN1.S, 0);
near(atZero.x, SPN1.cx0 + SPN1.R, 0.5, 'spine s=0 sits at top-run start x');
near(atZero.y, SPN1.cy0, 0.5, 'spine s=0 sits at top-run start y');

// ---- mergeIntervals
const m = G.mergeIntervals([[10, 20], [15, 30], [40, 50]]);
ok(m.length === 2 && m[0][0] === 10 && m[0][1] === 30 && m[1][0] === 40, 'mergeIntervals unions overlaps');

// ---- segmentLoop: circular segmentation on the spine (replaces the old per-edge segmentEdge)
// no features -> one closed (full) loop marker
const loopSegs0 = G.segmentLoop(2000, []);
ok(loopSegs0.length === 1 && loopSegs0[0].full === true, 'no features -> single full-loop segment');
// one break on the loop -> ONE open segment wrapping almost all the way around, both ends terminal
const loopSegs1 = G.segmentLoop(2000, [{ type: 'break', s0: 300, s1: 400 }]);
ok(loopSegs1.length === 1 && loopSegs1[0].endA === 'terminal' && loopSegs1[0].endB === 'terminal', 'single break -> one wrapped open segment, terminal ends');
near(loopSegs1[0].s1 - loopSegs1[0].s0, 1900, 1e-6, 'wrapped segment length = loop minus the break');
// medallion feature carries med ref + medallion ends
const med = { edge: 'left', at: 45, size: 14 };
const loopSegs2 = G.segmentLoop(2000, [{ type: 'medallion', s0: 280, s1: 420, med: med }]);
ok(loopSegs2.length === 1 && loopSegs2[0].endA === 'medallion' && loopSegs2[0].endB === 'medallion' && loopSegs2[0].med === med, 'single medallion -> wrapped segment with medallion ends + med ref');
// two breaks tiling the whole loop -> nothing to weave
ok(G.segmentLoop(2000, [{ type: 'break', s0: 0, s1: 1000 }, { type: 'break', s0: 1000, s1: 2000 }]).length === 0, 'fully-covered loop -> nothing');
// cursor pinning: a manual break wholly containing a later-sorted medallion footprint must not
// let the cursor walk backward into the cleared gap (no segment may start inside [100,400)).
const pinSegs = G.segmentLoop(2000, [
	{ type: 'break', s0: 100, s1: 400 },
	{ type: 'medallion', s0: 250, s1: 350, med: { edge: 'left', at: 45, size: 14 } }
]);
pinSegs.forEach(function (s, i) {
	const s0n = ((s.s0 % 2000) + 2000) % 2000, s1n = s0n + (s.s1 - s.s0);
	ok(s1n <= 100 + 2000 || s0n >= 400, 'pinned segment ' + i + ' does not start inside cleared gap [100,400): s0=' + s.s0 + ' s1=' + s.s1);
});
// hook quarter-arc interval straddles the s=0 seam (TL corner) and must still segment cleanly
const spnHook = G.spine(G.norm({ enabled: true, corners: 'hook' }), 816, 1056);
const hookFeats = ['tr', 'br', 'bl', 'tl'].map(function (key) {
	const a0 = spnHook.arcStart[key], a1 = a0 + spnHook.La, margin = spnHook.band * 0.2;
	return { type: 'hook', s0: a0 - margin, s1: a1 + margin };
});
const hookSegs = G.segmentLoop(spnHook.S, hookFeats);
ok(hookSegs.length === 4, 'four hook feature intervals (incl. the one straddling s=0) -> four woven segments, got ' + hookSegs.length);
hookSegs.forEach(function (s) { ok(isFinite(s.s0) && isFinite(s.s1) && s.s1 > s.s0, 'hook segment has finite positive length'); });

// ---- autoBreaks: a flagged slot overlapping the bottom band projects an interval
const slot = { location: 'center_image', break_border: true, x: 35, y: 88, w: 30, h: 10 };  // % of page
const ab = G.autoBreaks(cfg, 816, 1056, [slot], L1);
ok(ab.bottom.length === 1, 'flagged slot breaks bottom edge');
ok(ab.top.length === 0 && ab.left.length === 0 && ab.right.length === 0, 'no phantom breaks');
const abU = ab.bottom[0];
ok(abU[0] > 0 && abU[1] < L1.edges.bottom.len && abU[1] > abU[0], 'projected interval inside edge');
ok(G.autoBreaks(cfg, 816, 1056, [Object.assign({}, slot, { break_border: false })], L1).bottom.length === 0, 'unflagged slot ignored');

// ---- plait: repeats, easing, containment
const sp = cfg.strands;
const P = G.patterns.plait(400, 48, sp);
ok(P.strands.length === 3, 'plait strand count');
P.strands.forEach(function (s, i) {
	const first = s.pts[0], last = s.pts[s.pts.length - 1];
	near(first[0], 0, 1e-9, 'strand ' + i + ' starts at u=0');
	near(last[0], 400, 1e-6, 'strand ' + i + ' ends at u=L');
	near(first[1], G.lane(i, 3, 48), 0.01, 'strand ' + i + ' eased to lane at start');
	near(last[1], G.lane(i, 3, 48), 0.01, 'strand ' + i + ' eased to lane at end');
	s.pts.forEach(function (p) { ok(p[1] > 0 && p[1] < 48, 'strand ' + i + ' inside band'); });
	ok(s.color === i, 'strand color index');
});
// closed mode: no easing, strand marked closed, seamless wrap (integral repeats)
const Pc = G.patterns.plait(400, 48, sp, { closed: true });
Pc.strands.forEach(function (s, i) {
	ok(s.closed === true, 'closed plait strand ' + i + ' marked closed');
	const first = s.pts[0], last = s.pts[s.pts.length - 1];
	near(first[1], last[1], 0.5, 'closed plait strand ' + i + ' wraps seamlessly (v)');
});

// ---- findCrossings: two crossing sinusoids -> alternating over/under
function sine(phase) {
	const pts = [];
	for (let u = 0; u <= 400; u += 2) { pts.push([u, 24 + 18 * Math.sin(2 * Math.PI * u / 100 + phase)]); }
	return { pts: pts, closed: false };
}
const cr = G.findCrossings([sine(0), sine(Math.PI)]);
ok(cr.length >= 7 && cr.length <= 9, 'two opposed sines cross ~8 times, got ' + cr.length);
for (let i = 1; i < cr.length; i++) { ok(cr[i].over !== cr[i - 1].over, 'alternation at crossing ' + i); }
// self-crossing: a loop (prolate cycloid) crosses itself once per loop
const loop = { pts: [], closed: false };
for (let t = 0; t <= 4 * Math.PI; t += 0.05) { loop.pts.push([12 * t - 20 * Math.sin(t), 30 - 20 * Math.cos(t)]); }
const scr = G.findCrossings([loop]);
// t in [0,4*PI] centers backward-loop excursions at t=0, 2*PI, 4*PI; only the t=2*PI
// loop is fully interior to the sampled range (the other two are bisected by the
// domain boundary), so exactly one full self-crossing loop is actually present here.
ok(scr.length === 1, 'cycloid self-crosses once (one full loop interior to range), got ' + scr.length);

// ---- blendHex
ok(G.blendHex('#000000', '#ffffff', 0.5).toLowerCase() === '#808080', 'blendHex midpoint');
ok(G.blendHex('#ff0000', '#0000ff', 0).toLowerCase() === '#ff0000', 'blendHex t=0');

// ---- subPolyline: arc-length window
const straight = { pts: [], closed: false };
for (let u = 0; u <= 100; u += 2) { straight.pts.push([u, 0]); }
const sub = G.subPolyline(straight.pts, false, 25, 0, 10);   // centered at x=50
near(sub[0][0], 40, 2.1, 'subPolyline left reach');
near(sub[sub.length - 1][0], 60, 2.1, 'subPolyline right reach');
// closed wraparound: window across the seam returns contiguous pts
const ring = { pts: [], closed: true };
for (let a2 = 0; a2 < 64; a2++) { ring.pts.push([Math.cos(a2 / 64 * 2 * Math.PI) * 50, Math.sin(a2 / 64 * 2 * Math.PI) * 50]); }
const sub2 = G.subPolyline(ring.pts, true, 0, 0, 15);
ok(sub2.length >= 5, 'closed subPolyline wraps the seam');

// ---- buildSpineSegmentPolys: terminals merge (same color) or split two-tone (different colors)
// Segments placed on the top run (spine s === edge u there, since topRunStart = 0) so the
// numbers line up 1:1 with what used to be edge-local u0/u1.
const cfgT = G.norm({ enabled: true, pattern: 'plait', strands: { count: 2 } });
const layT = G.frameLayout(cfgT, 816, 1056);
const spnT = G.spine(cfgT, 816, 1056);
const segT = { s0: 100, s1: 500, endA: 'terminal', endB: 'terminal', med: null, medA: null, medB: null };
const polysT = G.buildSpineSegmentPolys(segT, cfgT, layT, spnT);
ok(polysT.length === 2, '2-strand double-terminal segment, 2 default colors -> two-tone split (2 polylines), got ' + polysT.length);
if (polysT.length === 2) {
	const pA = polysT[0].pts, pB = polysT[1].pts;
	near(Math.hypot(pA[0][0] - pB[0][0], pA[0][1] - pB[0][1]), 0, 0.1, 'two-tone terminal pair share start endpoint');
	near(Math.hypot(pA[pA.length - 1][0] - pB[pB.length - 1][0], pA[pA.length - 1][1] - pB[pB.length - 1][1]), 0, 0.1, 'two-tone terminal pair share end endpoint');
}
// single-color config: the pair shares one color -> old fully-merged closed-loop behavior still holds
const cfgT1 = G.norm({ enabled: true, pattern: 'plait', strands: { count: 2 }, colors: { strands: ['#333333'] } });
const polysT1 = G.buildSpineSegmentPolys(segT, cfgT1, layT, spnT);
ok(polysT1.length === 1 && polysT1[0].closed === true, 'single-color 2-strand double-terminal segment still closes into one loop, got ' + polysT1.length);
// N=4 single-color double-terminal segment: pairs (0,3) and (1,2) each merge at end A then
// close into a loop at end B -> exactly 2 closed polylines, none left bare/unmerged.
const cfgT4 = G.norm({ enabled: true, pattern: 'plait', strands: { count: 4 }, colors: { strands: ['#333333'] } });
const polysT4 = G.buildSpineSegmentPolys(segT, cfgT4, layT, spnT);
ok(polysT4.length === 2, 'N=4 single-color double-terminal segment merges into 2 closed loops, got ' + polysT4.length);
polysT4.forEach(function (p, i) { ok(p.closed === true, 'N=4 single-color loop ' + i + ' is closed'); });

const cfgT3 = G.norm({ enabled: true, pattern: 'plait', strands: { count: 3 } });
const segT3 = { s0: 100, s1: 500, endA: 'hook', endB: 'terminal', med: null, medA: null, medB: null };
const polysT3 = G.buildSpineSegmentPolys(segT3, cfgT3, layT, spnT);
ok(polysT3.length === 2, '3 strands, default 2 colors: outer pair (0,2) shares color -> merges, middle strand curls (2 polylines)');

// ---- collectPolys: full-border sanity (permanent geometry invariants for render() smoke path)
const cfgFull = G.norm({ enabled: true, pattern: 'plait', colors: { strands: ['#b3231a', '#e4670f', '#f5a623'], outline: '#2a0c05' }, breaks: [{ edge: 'bottom', at: 50, width: 26 }] });
const got = G.collectPolys(cfgFull, 816, 1056, []);
// (spine-sweep note: a single break now yields ONE continuous wrapped segment -- not a
// per-edge/per-corner patchwork -- so the polyline count is naturally lower than the old
// per-edge assembly; the invariant that matters here is "renders a well-formed border",
// checked below via in-bounds/finite coords and a healthy crossing count.)
ok(got.polys.length >= 2, 'collectPolys returns polylines for a full border, got ' + got.polys.length);
got.polys.forEach(function (p, i) {
	ok(p.pts.length >= 2, 'polyline ' + i + ' has >=2 points');
	p.pts.forEach(function (pt) {
		ok(isFinite(pt[0]) && isFinite(pt[1]), 'polyline ' + i + ' coords finite');
		ok(pt[0] >= -5 && pt[0] <= 816 + 50 && pt[1] >= -5 && pt[1] <= 1056 + 50, 'polyline ' + i + ' coords within page bounds, got ' + pt);
	});
});
const fullCross = G.findCrossings(got.polys, 3);
ok(fullCross.length > 20, 'full border has >20 crossings, got ' + fullCross.length);
fullCross.forEach(function (c) { ok(isFinite(c.x) && isFinite(c.y), 'crossing coords finite'); });

// ---- bottom-run mapping: a manual break at bottom at=50 produces a gap centered at page
// bottom-center; no polyline point should sit inside the gap's central 60% band-strip rect.
const bottomCfg = G.norm({ enabled: true, pattern: 'plait', breaks: [{ edge: 'bottom', at: 50, width: 20 }], autoBreak: { enabled: false } });
const bottomLayout = G.frameLayout(bottomCfg, 816, 1056);
const bottomGot = G.collectPolys(bottomCfg, 816, 1056, []);
const gapFullW = 20 / 100 * bottomLayout.edges.bottom.len;
const gapHalfW = gapFullW / 2 * 0.6;                     // central 60% of the gap width
const gapCx = 816 / 2, gapY0 = 1056 - bottomLayout.inset - bottomLayout.band, gapY1 = 1056 - bottomLayout.inset;
let gapIntrusions = 0;
bottomGot.polys.forEach(function (p) {
	p.pts.forEach(function (pt) {
		if (Math.abs(pt[0] - gapCx) < gapHalfW && pt[1] > gapY0 && pt[1] < gapY1) { gapIntrusions++; }
	});
});
ok(gapIntrusions === 0, 'bottom-center break leaves the gap free of weave points, got ' + gapIntrusions + ' intrusions');

// ---- openweave: 4 strands, 2 colors, mirror symmetry
const OW = G.patterns.openweave(520, 48, cfg.strands);
ok(OW.strands.length === 4, 'openweave emits 4 strands');
ok(OW.strands.filter(s => s.color === 0).length === 2 && OW.strands.filter(s => s.color === 1).length === 2, 'openweave two color pairs');
OW.strands.forEach((s, i) => s.pts.forEach(p => ok(p[1] > 0 && p[1] < 48, 'openweave strand ' + i + ' in band')));

// ---- twist: 2 strands, crossings every half-wave
const TW = G.patterns.twist(400, 48, cfg.strands);
ok(TW.strands.length === 2, 'twist emits 2 strands');
const twPolys = TW.strands.map(s => ({ pts: s.pts, closed: false }));
ok(G.findCrossings(twPolys).length >= 5, 'twist strands cross repeatedly');

// ---- norm(): pattern whitelist (Change 2 -- runningknot removed; anything else -> plait)
ok(G.norm({ pattern: 'runningknot' }).pattern === 'plait', 'removed runningknot pattern normalizes to plait');
ok(G.norm({ pattern: 'nonsense' }).pattern === 'plait', 'unknown/garbage pattern normalizes to plait');
ok(G.norm({ pattern: 'twist' }).pattern === 'twist', 'known pattern (twist) passes through unchanged');
ok(G.norm({ pattern: 'openweave' }).pattern === 'openweave', 'known pattern (openweave) passes through unchanged');
ok(G.norm({}).pattern === 'plait', 'default pattern is plait');

// ---- effCount
ok(G.effCount(G.norm({ pattern: 'twist' })) === 2, 'effCount twist');
ok(G.effCount(G.norm({ pattern: 'openweave' })) === 4, 'effCount openweave');
ok(G.effCount(G.norm({ pattern: 'plait', strands: { count: 3 } })) === 3, 'effCount plait');

// ---- collectPolys: every pattern runs the full segmentation+terminal path cleanly. With no
// breaks/medallions and 'woven' corners, this exercises the NO-FEATURES closed-loop path ->
// every emitted polyline must be closed:true.
['plait', 'openweave', 'twist'].forEach(function (patName) {
	const cfgP = G.norm({ enabled: true, pattern: patName });
	const gotP = G.collectPolys(cfgP, 816, 1056, []);
	ok(gotP.polys.length > 0, 'collectPolys(' + patName + ') returns polylines, got ' + gotP.polys.length);
	gotP.polys.forEach(function (p, i) {
		ok(p.pts.length >= 2, 'collectPolys(' + patName + ') polyline ' + i + ' has >=2 points');
		ok(p.closed === true, 'collectPolys(' + patName + ') polyline ' + i + ' is closed (no-features full loop)');
		const first = p.pts[0], last = p.pts[p.pts.length - 1];
		near(Math.hypot(first[0] - last[0], first[1] - last[1]), 0, 0.5, 'collectPolys(' + patName + ') polyline ' + i + ' wraps seamlessly');
		p.pts.forEach(function (pt) {
			ok(isFinite(pt[0]) && isFinite(pt[1]), 'collectPolys(' + patName + ') polyline ' + i + ' coords finite');
		});
	});
});

// ---- hook corners: quarter-arc feature intervals segment cleanly through the full pipeline
const cfgHook = G.norm({ enabled: true, pattern: 'plait', corners: 'hook' });
const gotHook = G.collectPolys(cfgHook, 816, 1056, []);
ok(gotHook.polys.length > 4, 'collectPolys(hook) returns polylines (weave + 4 spirals), got ' + gotHook.polys.length);
gotHook.polys.forEach(function (p, i) {
	p.pts.forEach(function (pt) { ok(isFinite(pt[0]) && isFinite(pt[1]), 'collectPolys(hook) polyline ' + i + ' coords finite'); });
});

// ---- medallion rings + inner rect
const medCfg = G.norm({ enabled: true, medallions: [{ edge: 'left', at: 45, size: 14 }] });
const mL = G.frameLayout(medCfg, 816, 1056);
const rings = G.medallionPolys(medCfg.medallions[0], mL.edges.left, mL, medCfg);
ok(rings.length === 2 && rings[0].closed && rings[1].closed, 'medallion = two closed rings');
// Two axis-aligned rhombi sharing a center + the same u/v axes (differing only in aspect,
// per the brief's exact geometry) cross exactly once per quadrant = 4 crossings, not 8 --
// 8 would require rotating one ring relative to the other, which the spec does not call for.
ok(G.findCrossings(rings).length >= 4, 'medallion rings interlace (>=4 crossings), got ' + G.findCrossings(rings).length);
const inner = K.medallionInnerRects({ enabled: true, medallions: [{ edge: 'left', at: 45, size: 14 }] }, 816, 1056);
ok(inner.length === 1 && inner[0].edge === 'left', 'medallionInnerRects returns entry');
ok(inner[0].w > 2 && inner[0].w < 14 && inner[0].h > 1 && inner[0].h < 14, 'inner rect sane');
const cxPct = inner[0].x + inner[0].w / 2;
ok(cxPct < 15, 'left-edge medallion sits near left side');

// ---- full render polys include hook spirals / medallion rings (collectPolys)
const full = G.collectPolys(medCfg, 816, 1056, []);
// a single medallion is one wrapped segment (weave strands merged/landed) + 2 rings
ok(full.polys.length >= 4, 'collectPolys includes weave + medallion rings, got ' + full.polys.length);

// ---- collectPolys: hook corners + medallions exercised through the full pipeline (no NaN)
const cfgHookMed = G.norm({
	enabled: true, pattern: 'plait', corners: 'hook',
	medallions: [{ edge: 'left', at: 45, size: 14 }, { edge: 'right', at: 55, size: 12 }]
});
const gotHookMed = G.collectPolys(cfgHookMed, 816, 1056, []);
ok(gotHookMed.polys.length > 8, 'collectPolys(hook+medallions) returns polylines, got ' + gotHookMed.polys.length);
gotHookMed.polys.forEach(function (p, i) {
	ok(p.pts.length >= 2, 'collectPolys(hook+medallions) polyline ' + i + ' has >=2 points');
	p.pts.forEach(function (pt) {
		ok(isFinite(pt[0]) && isFinite(pt[1]), 'collectPolys(hook+medallions) polyline ' + i + ' coords finite');
	});
});
const hookMedCross = G.findCrossings(gotHookMed.polys, 3);
hookMedCross.forEach(function (c) { ok(isFinite(c.x) && isFinite(c.y), 'hook+medallion crossing coords finite'); });

// ---- medallion segment ends (spec §7 item 4): the centermost lane(s) at a medallion end must
// land within ~wf of the medallion's ring paths (sweep landing fuses onto the rings).
const medOnlyCfg = G.norm({ enabled: true, pattern: 'plait', medallions: [{ edge: 'left', at: 45, size: 14 }] });
const medOnlyLayout = G.frameLayout(medOnlyCfg, 816, 1056);
const medOnlyGot = G.collectPolys(medOnlyCfg, 816, 1056, []);
const medOnlyRings = G.medallionPolys(medOnlyCfg.medallions[0], medOnlyLayout.edges.left, medOnlyLayout, medOnlyCfg);
const wfMed = G.strandW(medOnlyLayout.band, G.effCount(medOnlyCfg), medOnlyCfg.strands);
function distToRing(pt, ring) {
	let best = Infinity;
	ring.pts.forEach(function (rp) { const d = Math.hypot(rp[0] - pt[0], rp[1] - pt[1]); if (d < best) { best = d; } });
	return best;
}
let landedEndpoints = 0;
medOnlyGot.polys.forEach(function (p) {
	[p.pts[0], p.pts[p.pts.length - 1]].forEach(function (ep) {
		const d = Math.min(distToRing(ep, medOnlyRings[0]), distToRing(ep, medOnlyRings[1]));
		if (d <= wfMed * 2) { landedEndpoints++; }
	});
});
ok(landedEndpoints >= 2, 'medallion sweep landings: at least 2 polyline endpoints land near the medallion rings, got ' + landedEndpoints);

// ---- break-over-medallion: a break wide enough to swallow a medallion leaves no weave in the
// cleared gap (adapts the segmentLoop cursor-pinning invariant to the full collectPolys pipeline).
const breakOverMedCfg = G.norm({
	enabled: true, pattern: 'plait',
	medallions: [{ edge: 'left', at: 45, size: 10 }],
	breaks: [{ edge: 'left', at: 45, width: 30 }], autoBreak: { enabled: false }
});
const bomLayout = G.frameLayout(breakOverMedCfg, 816, 1056);
const bomGot = G.collectPolys(breakOverMedCfg, 816, 1056, []);
const bomE = bomLayout.edges.left;
const bomC = bomE.len * 0.45, bomH = bomE.len * 0.30 / 2;
// page-space probe rect: left edge's band strip (x), central 60% of the break's u-span (y),
// shrunk off the break edges where rim/ring geometry legitimately lives.
const bomU0 = bomC - bomH * 0.6, bomU1 = bomC + bomH * 0.6;
const bomY0 = bomE.oy + bomU0, bomY1 = bomE.oy + bomU1;
const bomX0 = bomE.ox + bomE.vx * (bomLayout.band * 0.15), bomX1 = bomE.ox + bomE.vx * (bomLayout.band * 0.85);
// exclude the medallion's own ring polylines (always appended last, 2 per medallion): they are
// legitimately drawn even when their weave connection was swallowed by an overlapping break --
// this probe only cares about WEAVE points intruding into the cleared gap.
const bomWeavePolys = bomGot.polys.slice(0, bomGot.polys.length - 2 * breakOverMedCfg.medallions.length);
let bomIntrusions = 0;
bomWeavePolys.forEach(function (p) {
	p.pts.forEach(function (pt) {
		if (pt[0] > Math.min(bomX0, bomX1) && pt[0] < Math.max(bomX0, bomX1) && pt[1] > bomY0 && pt[1] < bomY1) { bomIntrusions++; }
	});
});
ok(bomIntrusions === 0, 'break swallowing a medallion leaves its interior free of weave points, got ' + bomIntrusions);

// ---- medallion inward shift: an oversized lozenge must never clip the page edge
const medBig = G.norm({ enabled: true, medallions: [{ edge: 'left', at: 45, size: 14 }] });
const mbL = G.frameLayout(medBig, 816, 1056);
G.medallionPolys(medBig.medallions[0], mbL.edges.left, mbL, medBig).forEach(function (ring) {
	ring.pts.forEach(function (p) { ok(p[0] >= 1, 'medallion ring inside left page edge, x=' + p[0].toFixed(1)); });
});
G.medallionPolys(medBig.medallions[0], mbL.edges.right, mbL, medBig).forEach(function (ring) {
	ring.pts.forEach(function (p) { ok(p[0] <= 815, 'medallion ring inside right page edge, x=' + p[0].toFixed(1)); });
});
const innerB = K.medallionInnerRects(medBig, 816, 1056)[0];
ok(innerB.x > 0 && innerB.x + innerB.w < 100 && innerB.y > 0, 'shifted inner rect fully within page');
// a small medallion that already fits stays centered on the band centerline
const medSm = G.norm({ enabled: true, band: { inset: 4, width: 8 }, medallions: [{ edge: 'left', at: 45, size: 8 }] });
const msL = G.frameLayout(medSm, 816, 1056);
const smC = G.medallionCenter(medSm.medallions[0], msL.edges.left, msL);
near(smC[0], msL.inset + msL.band / 2, 0.01, 'small medallion stays on band centerline');

// ---- splitByWindows (Change 1: true cut gaps -- cut holes in under-strand polylines instead of
// painting a casing arc). RED-first: this geometry helper does not exist yet on the old engine.
{
	// open polyline, one central hole -> 2 sub-paths with exact-boundary endpoints
	const openPts = [];
	for (let ox = 0; ox <= 100; ox += 5) { openPts.push([ox, 0]); }
	const splitCentral = G.splitByWindows(openPts, false, [{ idx: 10, frac: 0, halfLen: 10 }]); // center u=50
	ok(splitCentral.length === 2, 'central hole on open polyline -> 2 sub-paths, got ' + splitCentral.length);
	if (splitCentral.length === 2) {
		near(splitCentral[0].pts[0][0], 0, 1e-6, 'first sub-path starts at the open path start');
		near(splitCentral[0].pts[splitCentral[0].pts.length - 1][0], 40, 1e-6, 'first sub-path ends at the hole boundary');
		near(splitCentral[1].pts[0][0], 60, 1e-6, 'second sub-path starts at the hole boundary');
		near(splitCentral[1].pts[splitCentral[1].pts.length - 1][0], 100, 1e-6, 'second sub-path ends at the open path end');
		ok(splitCentral[0].closed === false && splitCentral[1].closed === false, 'sub-paths from an open polyline are open');
	}
	// hole at the very start -> 1 sub-path
	const splitStart = G.splitByWindows(openPts, false, [{ idx: 0, frac: 0, halfLen: 8 }]);
	ok(splitStart.length === 1, 'hole at the very start -> 1 sub-path, got ' + splitStart.length);
	if (splitStart.length === 1) { near(splitStart[0].pts[0][0], 8, 1e-6, 'surviving sub-path starts right after the start hole'); }
	// no windows -> unchanged (closed stays closed)
	const ringPts = [];
	for (let ra = 0; ra < 64; ra++) { ringPts.push([Math.cos(ra / 64 * 2 * Math.PI) * 50, Math.sin(ra / 64 * 2 * Math.PI) * 50]); }
	const unchanged = G.splitByWindows(ringPts, true, []);
	ok(unchanged.length === 1 && unchanged[0].closed === true && unchanged[0].pts.length === ringPts.length, 'no windows -> unchanged closed polyline');
	// closed ring with 2 holes -> 2 open sub-paths whose combined length ~= ring length minus the holes
	const ringLen = 2 * Math.PI * 50;
	const twoHoles = G.splitByWindows(ringPts, true, [{ idx: 8, frac: 0, halfLen: 3 }, { idx: 40, frac: 0, halfLen: 3 }]);
	ok(twoHoles.length === 2, 'closed ring with 2 holes -> 2 open sub-paths, got ' + twoHoles.length);
	ok(twoHoles.every(function (sp) { return sp.closed === false; }), 'ring sub-paths with holes present are open, not closed');
	function runLen(sp) { let Lr = 0; for (let q = 1; q < sp.pts.length; q++) { Lr += Math.hypot(sp.pts[q][0] - sp.pts[q - 1][0], sp.pts[q][1] - sp.pts[q - 1][1]); } return Lr; }
	const combined = twoHoles.reduce(function (s, sp) { return s + runLen(sp); }, 0);
	near(combined, ringLen - 12, ringLen * 0.03, 'combined sub-path length ~= ring length minus the two holes');
	// overlapping windows merge into one hole (still just 2 survivors: before + after)
	const overlap = G.splitByWindows(openPts, false, [{ idx: 8, frac: 0, halfLen: 8 }, { idx: 10, frac: 0, halfLen: 8 }]);
	ok(overlap.length === 2, 'overlapping windows merge into one hole -> still 2 sub-paths, got ' + overlap.length);
}

// ---- true cut gaps behavioral test (Change 1): drive findCrossings + underWindow + splitByWindows
// on a two-sine crossing pair exactly as render()/swatch() now do. Every under strand gets holed;
// no surviving under-strand point sits inside the over strand's outline footprint at a crossing it
// is under at; the over strand stays continuous (unbroken) through every crossing it is over at.
{
	const cutPolysSrc = [sine(0), sine(Math.PI)];
	const wfCut = 10, gapCut = 1.4, wOutCut = wfCut + 2 * G.outlineW(wfCut);
	const crCut = G.findCrossings(cutPolysSrc, wfCut * 0.8);
	ok(crCut.length > 0, 'two-sine pair produces crossings to test true cut gaps against');
	const windowsByIdx = cutPolysSrc.map(function () { return []; });
	const underCount = { 0: 0, 1: 0 };
	crCut.forEach(function (c) {
		const w = G.underWindow(c, cutPolysSrc, wfCut, gapCut, wOutCut);
		windowsByIdx[w.polyIdx].push({ idx: w.idx, frac: w.frac, halfLen: w.halfLen });
		underCount[w.polyIdx]++;
	});
	ok(underCount[0] > 0 && underCount[1] > 0, 'both strands take a turn as the under strand across the alternating crossings');
	const cutStrand0 = G.splitByWindows(cutPolysSrc[0].pts, false, windowsByIdx[0]);
	const cutStrand1 = G.splitByWindows(cutPolysSrc[1].pts, false, windowsByIdx[1]);
	ok(cutStrand0.length > 1, 'under-strand 0 gets split by its holes, got ' + cutStrand0.length + ' sub-paths');
	ok(cutStrand1.length > 1, 'under-strand 1 gets split by its holes, got ' + cutStrand1.length + ' sub-paths');
	function nearestDist(subPolys, x, y) {
		let best = Infinity;
		subPolys.forEach(function (sp) { sp.pts.forEach(function (pt) { const d = Math.hypot(pt[0] - x, pt[1] - y); if (d < best) { best = d; } }); });
		return best;
	}
	let underIntrusions = 0, overBreaks = 0;
	crCut.forEach(function (c) {
		const underIdx = (c.over === 'a') ? 1 : 0, overIdx = (c.over === 'a') ? 0 : 1;
		const underArr = underIdx === 0 ? cutStrand0 : cutStrand1;
		const overArr = overIdx === 0 ? cutStrand0 : cutStrand1;
		if (nearestDist(underArr, c.x, c.y) < wOutCut / 2 - 1e-6) { underIntrusions++; }
		if (nearestDist(overArr, c.x, c.y) > 2) { overBreaks++; }
	});
	ok(underIntrusions === 0, 'no surviving under sub-path point lies within wOut/2 of a crossing it is under at, got ' + underIntrusions);
	ok(overBreaks === 0, 'over strand remains continuous (unsplit) through every crossing it is over at, got ' + overBreaks);
}

console.log(bad === 0 ? 'ALL PASS (' + n + ' checks)' : (bad + ' of ' + n + ' checks FAILED'));
process.exit(bad === 0 ? 0 : 1);
