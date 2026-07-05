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

console.log(bad === 0 ? 'ALL PASS (' + n + ' checks)' : (bad + ' of ' + n + ' checks FAILED'));
process.exit(bad === 0 ? 0 : 1);
