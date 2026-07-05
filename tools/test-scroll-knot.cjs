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

// ---- mergeIntervals
const m = G.mergeIntervals([[10, 20], [15, 30], [40, 50]]);
ok(m.length === 2 && m[0][0] === 10 && m[0][1] === 30 && m[1][0] === 40, 'mergeIntervals unions overlaps');

// ---- segmentEdge: plain edge = one segment corner-to-corner
const segs0 = G.segmentEdge(700, [], L1.band, 'corner');
ok(segs0.length === 1 && segs0[0].endA === 'corner' && segs0[0].endB === 'corner', 'no features -> single corner segment');
// one central break -> two segments with terminal ends facing the break
const segs1 = G.segmentEdge(700, [{ type: 'break', u0: 300, u1: 400 }], L1.band, 'corner');
ok(segs1.length === 2 && segs1[0].endB === 'terminal' && segs1[1].endA === 'terminal', 'break makes terminal ends');
near(segs1[0].u1, 300, 1e-9, 'segment stops at break');
// medallion feature carries med ref + medallion ends
const med = { edge: 'left', at: 45, size: 14 };
const segs2 = G.segmentEdge(700, [{ type: 'medallion', u0: 280, u1: 420, med: med }], L1.band, 'corner');
ok(segs2.length === 2 && segs2[0].endB === 'medallion' && segs2[1].endA === 'medallion' && segs2[0].med === med, 'medallion ends');
// break swallowing whole edge -> no segments
ok(G.segmentEdge(700, [{ type: 'break', u0: -10, u1: 710 }], L1.band, 'corner').length === 0, 'full-edge break -> nothing');
// cursor pinning: a manual break wholly containing a later-sorted medallion footprint must not
// let the cursor walk backward into the cleared gap (no segment may start inside [100,400)).
const segsPin = G.segmentEdge(700, [
	{ type: 'break', u0: 100, u1: 400 },
	{ type: 'medallion', u0: 250, u1: 350, med: { edge: 'left', at: 45, size: 14 } }
], L1.band, 'corner');
segsPin.forEach(function (s, i) {
	ok(s.u0 >= 400 || s.u1 <= 100, 'pinned segment ' + i + ' does not start inside cleared gap [100,400): u0=' + s.u0 + ' u1=' + s.u1);
});
for (let i = 1; i < segsPin.length; i++) { ok(segsPin[i].u0 >= segsPin[i - 1].u1, 'pinned segments monotonically ordered at index ' + i); }

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

// ---- buildSegmentPolys: terminals merge (same color) or split two-tone (different colors) - Finding 1
const cfgT = G.norm({ enabled: true, pattern: 'plait', strands: { count: 2 } });
const layT = G.frameLayout(cfgT, 816, 1056);
const segT = { u0: 100, u1: 500, endA: 'terminal', endB: 'terminal', medA: null, medB: null };
const polysT = G.buildSegmentPolys(layT.edges.top, segT, cfgT, layT);
ok(polysT.length === 2, '2-strand double-terminal segment, 2 default colors -> two-tone split (2 polylines), got ' + polysT.length);
if (polysT.length === 2) {
	const pA = polysT[0].pts, pB = polysT[1].pts;
	near(Math.hypot(pA[0][0] - pB[0][0], pA[0][1] - pB[0][1]), 0, 0.1, 'two-tone terminal pair share start endpoint');
	near(Math.hypot(pA[pA.length - 1][0] - pB[pB.length - 1][0], pA[pA.length - 1][1] - pB[pB.length - 1][1]), 0, 0.1, 'two-tone terminal pair share end endpoint');
}
// single-color config: the pair shares one color -> old fully-merged closed-loop behavior still holds
const cfgT1 = G.norm({ enabled: true, pattern: 'plait', strands: { count: 2 }, colors: { strands: ['#333333'] } });
const polysT1 = G.buildSegmentPolys(layT.edges.top, segT, cfgT1, layT);
ok(polysT1.length === 1 && polysT1[0].closed === true, 'single-color 2-strand double-terminal segment still closes into one loop, got ' + polysT1.length);
// N=4 single-color double-terminal segment: pairs (0,3) and (1,2) each merge at end A then
// close into a loop at end B -> exactly 2 closed polylines, none left bare/unmerged.
const cfgT4 = G.norm({ enabled: true, pattern: 'plait', strands: { count: 4 }, colors: { strands: ['#333333'] } });
const polysT4 = G.buildSegmentPolys(layT.edges.top, segT, cfgT4, layT);
ok(polysT4.length === 2, 'N=4 single-color double-terminal segment merges into 2 closed loops, got ' + polysT4.length);
polysT4.forEach(function (p, i) { ok(p.closed === true, 'N=4 single-color loop ' + i + ' is closed'); });

const cfgT3 = G.norm({ enabled: true, pattern: 'plait', strands: { count: 3 } });
const polysT3 = G.buildSegmentPolys(layT.edges.top, { u0: 100, u1: 500, endA: 'corner', endB: 'terminal', medA: null, medB: null }, cfgT3, layT);
ok(polysT3.length === 2, '3 strands, default 2 colors: outer pair (0,2) shares color -> merges, middle strand curls (2 polylines)');

// ---- collectPolys: full-border sanity (permanent geometry invariants for render() smoke path)
const cfgFull = G.norm({ enabled: true, pattern: 'plait', colors: { strands: ['#b3231a', '#e4670f', '#f5a623'], outline: '#2a0c05' }, breaks: [{ edge: 'bottom', at: 50, width: 26 }] });
const got = G.collectPolys(cfgFull, 816, 1056, []);
ok(got.polys.length > 6, 'collectPolys returns >6 polylines for a full border, got ' + got.polys.length);
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

// ---- runningknot: loop strand self-crosses once per repeat + rail
const RK = G.patterns.runningknot(500, 48, cfg.strands);
ok(RK.strands.length === 2, 'runningknot: loop + rail');
const rkSelf = G.findCrossings([{ pts: RK.strands[0].pts, closed: false }]);
ok(rkSelf.length >= 3, 'runningknot loop self-crosses per repeat, got ' + rkSelf.length);

// ---- effCount
ok(G.effCount(G.norm({ pattern: 'twist' })) === 2, 'effCount twist');
ok(G.effCount(G.norm({ pattern: 'openweave' })) === 4, 'effCount openweave');
ok(G.effCount(G.norm({ pattern: 'plait', strands: { count: 3 } })) === 3, 'effCount plait');

// ---- collectPolys: every pattern runs the full segmentation+terminal path cleanly
['plait', 'openweave', 'twist', 'runningknot'].forEach(function (patName) {
	const cfgP = G.norm({ enabled: true, pattern: patName });
	const gotP = G.collectPolys(cfgP, 816, 1056, []);
	ok(gotP.polys.length > 0, 'collectPolys(' + patName + ') returns polylines, got ' + gotP.polys.length);
	gotP.polys.forEach(function (p, i) {
		ok(p.pts.length >= 2, 'collectPolys(' + patName + ') polyline ' + i + ' has >=2 points');
		p.pts.forEach(function (pt) {
			ok(isFinite(pt[0]) && isFinite(pt[1]), 'collectPolys(' + patName + ') polyline ' + i + ' coords finite');
		});
	});
});

// ---- corners: woven corner connects lanes with parity-preserving permutation
const cp = G.cornerPolys('tl', cfg, L1);
ok(cp.length === 3, 'woven tl corner emits one connector per lane');
cp.forEach(function (p) { ok(p.pts.length >= 10, 'corner connector sampled'); });
// connectors start at top-edge u=0 ports and end at left-edge u=0 ports (page coords sanity)
const tlBox = L1.corners.tl;
cp.forEach(function (p) {
	const a = p.pts[0], z = p.pts[p.pts.length - 1];
	ok(a[0] >= tlBox.x - 1 && a[1] >= tlBox.y - 1, 'corner connector stays around box start');
	ok(z[0] >= tlBox.x - 1 && z[1] >= tlBox.y - 1, 'corner connector stays around box end');
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

// ---- full render polys include corners + medallions (collectPolys)
const full = G.collectPolys(medCfg, 816, 1056, []);
ok(full.polys.length > 8, 'collectPolys includes edges + corners + medallion rings');

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

console.log(bad === 0 ? 'ALL PASS (' + n + ' checks)' : (bad + ' of ' + n + ' checks FAILED'));
process.exit(bad === 0 ? 0 : 1);
