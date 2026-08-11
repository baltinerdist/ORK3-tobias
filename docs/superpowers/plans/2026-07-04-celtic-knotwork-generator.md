# Celtic Knotwork Border Generator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A parametric Celtic knotwork border engine (`scroll-knot.js`) that renders interlaced knot borders as inline SVG from a `knot` config in the scroll template JSON, with per-strand colors, gradient tinting, woven corners, diamond medallions, and dynamic breaks — plus a designer Border panel and four presets replicating the reference scrolls.

**Architecture:** Approach C from the spec (`docs/superpowers/specs/2026-07-04-celtic-knotwork-generator-design.md`): procedural pattern modules emit strand **polylines** in edge-local (u,v) coordinates; a shared numeric crossing finder assigns alternating over/under per strand pair; a two-pass SVG renderer (all outlines → all fills → per-crossing over-arc redraw) produces the inked interlace look. Geometry core is DOM-free and unit-tested in Node; only `render()`/`swatch()` touch the DOM.

**Tech Stack:** Vanilla ES5-ish JS (IIFE, tabs, matching `scroll-render.js` style), inline SVG (paths + strokes + `userSpaceOnUse` linear gradients ONLY — no masks/filters/clipPath/use, the html2canvas-safe subset), Node for geometry tests (`node tools/test-scroll-knot.cjs`).

## Global Constraints

- Page logical px: portrait **816×1056**, landscape **1056×816** (`--sc-page-w: 816px`, aspect 8.5/11).
- `knot` config schema exactly as in spec §1; templates WITHOUT a `knot` key must render byte-identically to today.
- SVG subset: `<svg>`, `<g>`, `<path>`, `<defs>`, `<linearGradient>`, `<stop>` only. `pointer-events:none` on the layer.
- JS files use TABS for indentation (match `scroll-design.js`). `.tpl` files are PLAIN PHP (never Smarty syntax).
- Dark mode: any new designer CSS must work under `html[data-theme="dark"]` (NOT `body.dark-mode`).
- No native `alert/confirm/title` — `data-tip` tooltips, existing `scToast`.
- FontAwesome 5.8.2 icon names only (FA6 names render blank).
- Never stage `system/lib/ork3/class.Authorization.php` (contains a local login-bypass hack). Stage files explicitly by name; never `git add -A`.
- Commit message style: `Scroll: <what>` + the standard Co-Authored-By/Claude-Session trailer used on this branch.

**File map (whole feature):**

| File | Role |
|---|---|
| Create `orkui/template/revised-frontend/scroll/scroll-knot.js` | The engine (geometry core + SVG renderer) |
| Create `tools/test-scroll-knot.cjs` | Node geometry tests (plain asserts) |
| Modify `orkui/template/revised-frontend/scroll/scroll-render.js` | Insert knot layer in `renderPage()` |
| Modify `orkui/template/revised-frontend/Scroll_builder.tpl` | `<script>` tag for scroll-knot.js |
| Modify `orkui/template/revised-frontend/Scroll_design.tpl` | `<script>` tag + Border panel section |
| Modify `orkui/template/revised-frontend/scroll/scroll-design.js` | Border panel UI, presets, slot `break_border` checkbox, medallion emblem-slot button |
| Modify `orkui/template/revised-frontend/style/scroll.css` | `.sc-knot` layer + Border panel styles (light+dark) |

---

### Task 1: Geometry core — config, frame layout, segmentation, plait pattern, crossings

**Files:**
- Create: `orkui/template/revised-frontend/scroll/scroll-knot.js`
- Create: `tools/test-scroll-knot.cjs`

**Interfaces:**
- Consumes: nothing (standalone).
- Produces (used by every later task), all under `ScrollKnot._geom`:
  - `norm(cfg) -> cfg'` — deep-defaulted copy of a `knot` config (spec §1 schema).
  - `frameLayout(cfg', W, H) -> {S, inset, band, W, H, edges:{top,right,bottom,left}, corners:{tl,tr,bl,br}}` — each edge `{name, ox, oy, ux, uy, vx, vy, len}`; each corner `{x, y}` (top-left of its band×band box).
  - `toPage(edge, u, v) -> [x, y]`.
  - `lane(i, N, band) -> v` — lane center; `strandW(band, N, sp) -> wf`; `outlineW(wf) -> px`.
  - `mergeIntervals(list) -> list` — sorted disjoint `[u0,u1]` union.
  - `autoBreaks(cfg', W, H, slots, layout) -> {top:[[u0,u1]..], right:.., bottom:.., left:..}`.
  - `segmentEdge(edgeLen, feats, band, cornerEnd) -> [{u0, u1, endA, endB, med?}]` — `feats` = `[{type:'break'|'medallion', u0, u1, med?}]`; `endA/endB` ∈ `'corner'|'terminal'|'medallion'`; `cornerEnd` = `'corner'` or `'terminal'` (hook corners open the ends).
  - `patterns.plait(L, band, sp) -> {strands:[{pts:[[u,v],...], color:int, closed:false}]}` — eased to lane centers at both ends, whole number of repeats.
  - `findCrossings(polys) -> [{a, b, ia, fa, ib, fb, x, y, over}]` — `polys` = `[{pts:[[x,y],...], closed}]` in PAGE coords; `over` ∈ `'a'|'b'`; per-pair alternation by order along strand a; handles self-crossings (`a===b`, skips |ia−ib|≤4 neighbors); dedupes hits closer than `dedupeR`.
  - `blendHex(hexA, hexB, t) -> '#rrggbb'`.
  - Constants: `STEP(band)`, `TERM(band)`, `EASE(lam, L)`.

- [ ] **Step 1: Write the failing test**

Create `tools/test-scroll-knot.cjs`:

```js
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
ok(scr.length === 2, 'cycloid self-crosses twice over two loops, got ' + scr.length);

// ---- blendHex
ok(G.blendHex('#000000', '#ffffff', 0.5).toLowerCase() === '#808080', 'blendHex midpoint');
ok(G.blendHex('#ff0000', '#0000ff', 0).toLowerCase() === '#ff0000', 'blendHex t=0');

console.log(bad === 0 ? 'ALL PASS (' + n + ' checks)' : (bad + ' of ' + n + ' checks FAILED'));
process.exit(bad === 0 ? 0 : 1);
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node tools/test-scroll-knot.cjs`
Expected: crash — `Cannot read properties of undefined` / ENOENT (scroll-knot.js does not exist yet).

- [ ] **Step 3: Write the geometry core**

Create `orkui/template/revised-frontend/scroll/scroll-knot.js` (tabs; ES5 style; DOM-free except in later tasks):

```js
/* scroll-knot.js — parametric Celtic knotwork border engine.
   Geometry core is DOM-free (unit-tested in Node); render()/swatch() build SVG.
   PDF-safe SVG subset only: paths + strokes + userSpaceOnUse linear gradients. */
(function (w) {
	'use strict';
	var SVGNS = 'http://www.w3.org/2000/svg';

	// ---------- small math ----------
	function clamp(v, a, b) { return v < a ? a : (v > b ? b : v); }
	function lerp(a, b, t) { return a + (b - a) * t; }
	function smooth(t) { t = clamp(t, 0, 1); return t * t * (3 - 2 * t); }
	function hexRgb(h) {
		h = String(h || '#000').replace('#', '');
		if (h.length === 3) { h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2]; }
		var v = parseInt(h, 16) || 0;
		return [(v >> 16) & 255, (v >> 8) & 255, v & 255];
	}
	function rgbHex(r, g, b) {
		function c(x) { x = clamp(Math.round(x), 0, 255).toString(16); return x.length < 2 ? '0' + x : x; }
		return '#' + c(r) + c(g) + c(b);
	}
	function blendHex(a, b, t) {
		var A = hexRgb(a), B = hexRgb(b);
		return rgbHex(lerp(A[0], B[0], t), lerp(A[1], B[1], t), lerp(A[2], B[2], t));
	}

	// ---------- config ----------
	function norm(cfg) {
		cfg = cfg || {};
		function o(v, d) { return (v == null) ? d : v; }
		var band = cfg.band || {}, st = cfg.strands || {}, co = cfg.colors || {}, gr = cfg.gradient || {}, ab = cfg.autoBreak || {};
		return {
			enabled: !!cfg.enabled,
			pattern: o(cfg.pattern, 'plait'),
			band: { inset: +o(band.inset, 2), width: +o(band.width, 6) },
			strands: { count: clamp(+o(st.count, 3), 1, 4), thickness: +o(st.thickness, 0.55), gap: +o(st.gap, 0.12), scale: +o(st.scale, 1) },
			colors: {
				strands: (Array.isArray(co.strands) && co.strands.length) ? co.strands.slice(0, 4) : ['#2e7d32', '#f4c542'],
				outline: o(co.outline, '#1a1a1a')
			},
			gradient: {
				enabled: !!gr.enabled, angle: +o(gr.angle, 90),
				stops: (Array.isArray(gr.stops) && gr.stops.length >= 2) ? gr.stops : [{ at: 0, color: '#c62828' }, { at: 1, color: '#f9a825' }]
			},
			corners: o(cfg.corners, 'woven'),
			medallions: Array.isArray(cfg.medallions) ? cfg.medallions : [],
			breaks: Array.isArray(cfg.breaks) ? cfg.breaks : [],
			autoBreak: { enabled: ab.enabled == null ? true : !!ab.enabled, padding: +o(ab.padding, 2) }
		};
	}

	// ---------- frame layout ----------
	// Edge-local frame: u along the edge run, v across the band (0..band). toPage maps to page px.
	function frameLayout(cfg, W, H) {
		var S = Math.min(W, H);
		var inset = cfg.band.inset / 100 * S, band = cfg.band.width / 100 * S;
		var x0 = inset, y0 = inset, x1 = W - inset, y1 = H - inset;
		function edge(name, ox, oy, ux, uy, vx, vy, len) { return { name: name, ox: ox, oy: oy, ux: ux, uy: uy, vx: vx, vy: vy, len: Math.max(0, len) }; }
		return {
			S: S, inset: inset, band: band, W: W, H: H,
			edges: {
				top:    edge('top',    x0 + band, y0,        1, 0, 0, 1, (x1 - x0) - 2 * band),
				bottom: edge('bottom', x0 + band, y1 - band, 1, 0, 0, 1, (x1 - x0) - 2 * band),
				left:   edge('left',   x0,        y0 + band, 0, 1, 1, 0, (y1 - y0) - 2 * band),
				right:  edge('right',  x1 - band, y0 + band, 0, 1, 1, 0, (y1 - y0) - 2 * band)
			},
			corners: { tl: { x: x0, y: y0 }, tr: { x: x1 - band, y: y0 }, bl: { x: x0, y: y1 - band }, br: { x: x1 - band, y: y1 - band } }
		};
	}
	function toPage(e, u, v) { return [e.ox + e.ux * u + e.vx * v, e.oy + e.uy * u + e.vy * v]; }

	// ---------- strand metrics ----------
	function lane(i, N, band) { return band * (i + 0.5) / N; }
	function strandW(band, N, sp) { return Math.max(2, (band / N) * clamp(sp.thickness, 0.2, 0.95)); }
	function outlineW(wf) { return clamp(wf * 0.16, 1.1, 3); }
	function STEP(band) { return clamp(band / 16, 1.25, 4); }
	function TERM(band) { return band * 0.55; }
	function EASE(lam, L) { return Math.min(lam * 0.6, L * 0.4); }

	// ---------- intervals / segmentation ----------
	function mergeIntervals(list) {
		var a = list.slice().sort(function (p, q) { return p[0] - q[0]; }), out = [];
		a.forEach(function (iv) {
			if (out.length && iv[0] <= out[out.length - 1][1]) { out[out.length - 1][1] = Math.max(out[out.length - 1][1], iv[1]); }
			else { out.push([iv[0], iv[1]]); }
		});
		return out;
	}
	// feats: [{type:'break'|'medallion', u0, u1, med?}] -> ordered weave segments with end kinds.
	function segmentEdge(edgeLen, feats, band, cornerEnd) {
		var fs = feats.slice().sort(function (p, q) { return p.u0 - q.u0; });
		var segs = [], cursor = 0, prevEnd = cornerEnd, prevMed = null;
		function push(u0, u1, endA, endB, medA, medB) {
			if (u1 - u0 < 2) { return; }
			segs.push({ u0: u0, u1: u1, endA: endA, endB: endB, med: medB || medA || null, medA: medA || null, medB: medB || null });
		}
		fs.forEach(function (f) {
			var kind = f.type === 'medallion' ? 'medallion' : 'terminal';
			push(cursor, clamp(f.u0, 0, edgeLen), prevEnd, kind, prevMed, f.type === 'medallion' ? f.med : null);
			cursor = clamp(f.u1, 0, edgeLen);
			prevEnd = kind; prevMed = (f.type === 'medallion') ? f.med : null;
		});
		push(cursor, edgeLen, prevEnd, cornerEnd, prevMed, null);
		return segs;
	}
	// project padded, break_border-flagged slots onto each edge's band strip.
	function autoBreaks(cfg, W, H, slots, layout) {
		var out = { top: [], right: [], bottom: [], left: [] };
		if (!cfg.autoBreak.enabled) { return out; }
		var pad = cfg.autoBreak.padding / 100 * layout.S;
		(slots || []).forEach(function (s) {
			if (!s || !s.break_border) { return; }
			var rx = s.x / 100 * W - pad, ry = s.y / 100 * H - pad;
			var rw = s.w / 100 * W + 2 * pad, rh = s.h / 100 * H + 2 * pad;
			['top', 'right', 'bottom', 'left'].forEach(function (name) {
				var e = layout.edges[name];
				// band strip rect of this edge in page coords
				var p00 = toPage(e, 0, 0), p11 = toPage(e, e.len, layout.band);
				var sx0 = Math.min(p00[0], p11[0]), sy0 = Math.min(p00[1], p11[1]);
				var sx1 = Math.max(p00[0], p11[0]), sy1 = Math.max(p00[1], p11[1]);
				var ix0 = Math.max(rx, sx0), iy0 = Math.max(ry, sy0);
				var ix1 = Math.min(rx + rw, sx1), iy1 = Math.min(ry + rh, sy1);
				if (ix1 <= ix0 || iy1 <= iy0) { return; }
				var u0 = e.ux ? (ix0 - Math.min(p00[0], p11[0])) : (iy0 - Math.min(p00[1], p11[1]));
				var u1 = e.ux ? (ix1 - Math.min(p00[0], p11[0])) : (iy1 - Math.min(p00[1], p11[1]));
				out[name].push([clamp(u0, 0, e.len), clamp(u1, 0, e.len)]);
			});
		});
		['top', 'right', 'bottom', 'left'].forEach(function (n) { out[n] = mergeIntervals(out[n]); });
		return out;
	}

	// ---------- patterns ----------
	// Contract: gen(L, band, sp) -> {strands:[{pts:[[u,v]..], color:int, closed:false}]}
	// Strands eased to lane centers over EASE at both ends; whole number of wave repeats.
	var patterns = {};
	patterns.plait = function (L, band, sp) {
		var N = clamp(sp.count, 2, 4);
		var lam0 = Math.max(band * 1.5 * sp.scale, 8);
		var reps = Math.max(1, Math.round(L / lam0)), lam = L / reps;
		var wf = strandW(band, N, sp);
		var amp = Math.max(1, band / 2 - wf / 2 - outlineW(wf) - 1);
		var ease = EASE(lam, L), step = STEP(band), strands = [];
		for (var i = 0; i < N; i++) {
			var phi = i * Math.PI * 2 / N, pts = [];
			for (var u = 0; u <= L + 1e-6; u += step) {
				var uu = Math.min(u, L);
				var vv = band / 2 + amp * Math.sin(Math.PI * 2 * uu / lam + phi);
				var d = Math.min(uu, L - uu);
				if (d < ease) { vv = lerp(lane(i, N, band), vv, smooth(d / ease)); }
				pts.push([uu, vv]);
				if (uu >= L) { break; }
			}
			if (pts[pts.length - 1][0] < L) { pts.push([L, lane(i, N, band)]); }
			strands.push({ pts: pts, color: i, closed: false });
		}
		return { strands: strands };
	};

	// ---------- crossings ----------
	function segInt(p1, p2, p3, p4) {                    // segment intersection -> {t,s,x,y} or null
		var d1x = p2[0] - p1[0], d1y = p2[1] - p1[1], d2x = p4[0] - p3[0], d2y = p4[1] - p3[1];
		var den = d1x * d2y - d1y * d2x;
		if (Math.abs(den) < 1e-12) { return null; }
		var t = ((p3[0] - p1[0]) * d2y - (p3[1] - p1[1]) * d2x) / den;
		var s = ((p3[0] - p1[0]) * d1y - (p3[1] - p1[1]) * d1x) / den;
		if (t < 0 || t > 1 || s < 0 || s > 1) { return null; }
		return { t: t, s: s, x: p1[0] + d1x * t, y: p1[1] + d1y * t };
	}
	function bbox(pts) {
		var x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
		pts.forEach(function (p) { if (p[0] < x0) x0 = p[0]; if (p[0] > x1) x1 = p[0]; if (p[1] < y0) y0 = p[1]; if (p[1] > y1) y1 = p[1]; });
		return [x0, y0, x1, y1];
	}
	// polys: [{pts, closed}] page coords. Returns crossings with alternating over/under per pair.
	function findCrossings(polys, dedupeR) {
		dedupeR = dedupeR || 3;
		var raw = [];
		for (var a = 0; a < polys.length; a++) {
			for (var b = a; b < polys.length; b++) {
				var A = polys[a].pts, B = polys[b].pts;
				if (a !== b) {
					var ba = bbox(A), bb = bbox(B);
					if (ba[2] < bb[0] - 1 || bb[2] < ba[0] - 1 || ba[3] < bb[1] - 1 || bb[3] < ba[1] - 1) { continue; }
				}
				var nA = A.length - 1, nB = B.length - 1;
				for (var i = 0; i < nA; i++) {
					var j0 = (a === b) ? i + 5 : 0;      // skip adjacent segments on self-crossing scan
					for (var j = j0; j < nB; j++) {
						var hit = segInt(A[i], A[i + 1], B[j], B[j + 1]);
						if (hit) { raw.push({ a: a, b: b, ia: i, fa: hit.t, ib: j, fb: hit.s, x: hit.x, y: hit.y }); }
					}
				}
			}
		}
		// dedupe near-coincident hits (same crossing straddling sample points)
		var cross = [];
		raw.forEach(function (c) {
			for (var k = 0; k < cross.length; k++) {
				var o = cross[k];
				if (o.a === c.a && o.b === c.b && (o.x - c.x) * (o.x - c.x) + (o.y - c.y) * (o.y - c.y) < dedupeR * dedupeR) { return; }
			}
			cross.push(c);
		});
		// per-pair alternation, ordered along strand a
		var groups = {};
		cross.forEach(function (c) { var k = c.a + ':' + c.b; (groups[k] = groups[k] || []).push(c); });
		Object.keys(groups).forEach(function (k) {
			var g = groups[k].sort(function (p, q) { return (p.ia + p.fa) - (q.ia + q.fa); });
			var start = (g[0].a + g[0].b) % 2;
			g.forEach(function (c, idx) { c.over = ((idx + start) % 2 === 0) ? 'a' : 'b'; });
		});
		return cross;
	}

	var K = {
		_geom: {
			norm: norm, frameLayout: frameLayout, toPage: toPage, lane: lane, strandW: strandW, outlineW: outlineW,
			mergeIntervals: mergeIntervals, segmentEdge: segmentEdge, autoBreaks: autoBreaks,
			patterns: patterns, findCrossings: findCrossings, blendHex: blendHex,
			STEP: STEP, TERM: TERM, EASE: EASE, clamp: clamp, lerp: lerp, smooth: smooth
		}
	};
	w.ScrollKnot = K;
})(typeof window !== 'undefined' ? window : globalThis);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `node tools/test-scroll-knot.cjs`
Expected: `ALL PASS (…checks)`. If the cycloid self-cross count differs by ±1, adjust the `j0 = i + 5` neighbor-skip window — the invariant is one crossing per loop.

- [ ] **Step 5: Commit**

```bash
git add orkui/template/revised-frontend/scroll/scroll-knot.js tools/test-scroll-knot.cjs
git commit -m "Scroll: knotwork engine geometry core (layout, segmentation, plait, crossings)"
```

---

### Task 2: SVG renderer — two-pass interlace, terminals, gradients, `render()` + `swatch()`

**Files:**
- Modify: `orkui/template/revised-frontend/scroll/scroll-knot.js`
- Modify: `tools/test-scroll-knot.cjs` (append tests)

**Interfaces:**
- Consumes: everything from Task 1 (`_geom`).
- Produces:
  - `ScrollKnot.render(knotCfg, W, H, slots) -> SVGSVGElement` — `class="sc-knot"`, `viewBox="0 0 W H"`, absolute overlay.
  - `ScrollKnot.swatch(knotCfg, wPx, hPx) -> SVGSVGElement` — one horizontal weave strip (for designer thumbnails).
  - `_geom.subPolyline(pts, closed, idx, frac, halfLen) -> [[x,y]..]` — arc-length window around a point on a polyline (wraps when closed).
  - `_geom.terminal(portsEnd, dir)` behavior (internal `buildSegmentPolys`): U-turn pairing lane i ↔ lane N−1−i, middle strand of odd N curls.
  - Internal: `buildSegmentPolys(edge, seg, cfg, layout) -> [{pts(page), color, closed}]` — weave + terminal arcs merged into continuous polylines.

Rendering rules (from spec §2.4):
- Group 1: every polyline stroked in `colors.outline` at `w_out = wf + 2*outlineW(wf)`.
- Group 2: every polyline stroked in its strand paint at `wf`.
- Group 3: per crossing, the OVER strand's sub-polyline (`halfLen = wf*0.75 + gapPx`) stroked outline-color at `w_out + 2*gapPx`, then strand paint at `wf`. `gapPx = cfg.strands.gap * wf`.
- All strokes: `fill="none"`, `stroke-linecap="round"`, `stroke-linejoin="round"`.
- Gradient: when enabled, one `<linearGradient gradientUnits="userSpaceOnUse">` per distinct strand color k, id `skg{instance}_{k}`; stops at `stop.at` with color `blendHex(strandColor, stop.color, 0.8)`; direction from `angle` (90 = top→bottom): `d=(cos(rad), sin(rad))`, `rad = angle*π/180`, line from page center ± d·((|dx|·W+|dy|·H)/2). Outline never tinted.

- [ ] **Step 1: Append failing tests**

Append to `tools/test-scroll-knot.cjs` BEFORE the final `console.log` line:

```js
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

// ---- buildSegmentPolys: terminals merge strand pairs into continuous polylines
const cfgT = G.norm({ enabled: true, pattern: 'plait', strands: { count: 2 } });
const layT = G.frameLayout(cfgT, 816, 1056);
const segT = { u0: 100, u1: 500, endA: 'terminal', endB: 'terminal', medA: null, medB: null };
const polysT = G.buildSegmentPolys(layT.edges.top, segT, cfgT, layT);
ok(polysT.length === 1 && polysT[0].closed === true, '2-strand double-terminal segment closes into one loop, got ' + polysT.length);
const cfgT3 = G.norm({ enabled: true, pattern: 'plait', strands: { count: 3 } });
const polysT3 = G.buildSegmentPolys(layT.edges.top, { u0: 100, u1: 500, endA: 'corner', endB: 'terminal', medA: null, medB: null }, cfgT3, layT);
ok(polysT3.length === 2, '3 strands, one terminal end: outer pair merges into one polyline, middle strand curls (2 polylines)');
```

- [ ] **Step 2: Run tests to verify the new ones fail**

Run: `node tools/test-scroll-knot.cjs`
Expected: FAIL — `G.subPolyline is not a function`.

- [ ] **Step 3: Implement renderer**

Add to `scroll-knot.js` (inside the IIFE, before `var K = {...}`; then extend `K`):

```js
	// ---------- sub-polyline extraction (for crossing over-arcs) ----------
	function subPolyline(pts, closed, idx, frac, halfLen) {
		var n = pts.length;
		function P(i) { return pts[((i % n) + n) % n]; }
		function segLen(i) { var A = P(i), B = P(i + 1); return Math.hypot(B[0] - A[0], B[1] - A[1]); }
		var cx = lerp(P(idx)[0], P(idx + 1)[0], frac), cy = lerp(P(idx)[1], P(idx + 1)[1], frac);
		var out = [[cx, cy]], acc, i, steps;
		// walk backward
		acc = frac * segLen(idx); i = idx; steps = 0;
		while (acc < halfLen && steps++ < n) {
			out.unshift(P(i).slice());
			i--; if (i < 0) { if (!closed) { break; } i += n; }
			acc += segLen(i);
		}
		// walk forward
		acc = (1 - frac) * segLen(idx); i = idx + 1; steps = 0;
		while (acc < halfLen && steps++ < n) {
			out.push(P(i).slice());
			i++; if (i >= n && !closed) { break; }
			acc += segLen(i);
		}
		if (!closed) { return out; }
		return out;
	}

	// ---------- terminals + segment assembly ----------
	// Sample a U-turn arc joining (ue, va)->(ue, vb), bulging dir (+1/-1) beyond the segment end.
	function uTurn(ue, va, vb, dir, reach) {
		var pts = [], mid = (va + vb) / 2, r = Math.abs(vb - va) / 2;
		for (var k = 0; k <= 16; k++) {
			var th = k / 16 * Math.PI;
			pts.push([ue + dir * Math.sin(th) * Math.max(r, reach), mid - Math.cos(th) * r * (va < vb ? 1 : -1)]);
		}
		return pts;
	}
	// Spiral curl for the middle strand of an odd count.
	function curl(ue, v, dir, band) {
		var pts = [], r0 = band * 0.22, cx = ue + dir * r0, turns = 1.5 * Math.PI * 2 * 0.75; // 270 deg
		for (var k = 0; k <= 24; k++) {
			var th = k / 24 * turns, r = r0 * (1 - 0.7 * (k / 24));
			pts.push([cx - dir * Math.cos(th) * r, v + Math.sin(th) * r]);
		}
		return pts;
	}
	// Build the page-space polylines for one weave segment, terminals merged in.
	function buildSegmentPolys(edge, seg, cfg, layout) {
		var band = layout.band, sp = cfg.strands;
		var tA = seg.endA === 'corner' ? 0 : TERM(band), tB = seg.endB === 'corner' ? 0 : TERM(band);
		if (seg.endA === 'medallion') { tA = band * 0.35; }
		if (seg.endB === 'medallion') { tB = band * 0.35; }
		var Lw = (seg.u1 - seg.u0) - tA - tB;
		var gen = patterns[cfg.pattern] || patterns.plait;
		var res, off = seg.u0 + tA;
		if (Lw < band * 1.1) {                             // degenerate: plain connector strands
			var pts0 = [[seg.u0 + tA, band * 0.35], [seg.u1 - tB, band * 0.35]];
			var pts1 = [[seg.u0 + tA, band * 0.65], [seg.u1 - tB, band * 0.65]];
			res = { strands: [{ pts: pts0, color: 0, closed: false }, { pts: pts1, color: 1, closed: false }] };
			off = 0;
		} else {
			res = gen(Lw, band, sp);
			res.strands.forEach(function (s) { s.pts = s.pts.map(function (p) { return [p[0] + off, p[1]]; }); });
		}
		var N = res.strands.length;
		// terminal arcs: pair lane i with lane N-1-i; odd middle curls.
		function endArcs(atEnd) {                           // atEnd: 'A'|'B'
			var isA = atEnd === 'A', kind = isA ? seg.endA : seg.endB;
			if (kind === 'corner') { return; }
			var ue = isA ? (seg.u0 + tA) : (seg.u1 - tB), dir = isA ? -1 : 1;
			var reach = (kind === 'medallion') ? (isA ? tA : tB) + band * 0.3 : Math.min(TERM(band) * 0.8, band * 0.45);
			for (var i = 0; i < Math.floor(N / 2); i++) {
				var j = N - 1 - i;
				var arc = uTurn(ue, lane(i, N, band), lane(j, N, band), dir, reach * (1 - i * 0.25));
				var si = res.strands[i], sj = res.strands[j];
				if (!si || !sj || si === sj || si.merged || sj.merged) { continue; }
				// merge: si.pts + arc + reversed sj.pts (orientation depends on end)
				var joined;
				if (isA) { joined = sj.pts.slice().reverse().concat(arc.slice().reverse().length ? arc.reverse() : arc, si.pts); }
				else { joined = si.pts.concat(arc, sj.pts.slice().reverse()); }
				si.pts = joined; sj.merged = true;
				if (si.pendingClose) { si.closed = true; }   // both ends terminal -> loop closes
				si.pendingClose = true;
			}
			if (N % 2 === 1) {
				var m = res.strands[(N - 1) / 2];
				if (m && !m.merged) {
					var c = curl(ue, lane((N - 1) / 2, N, band), dir, band);
					if (isA) { m.pts = c.slice().reverse().concat(m.pts); } else { m.pts = m.pts.concat(c); }
				}
			}
		}
		endArcs('A'); endArcs('B');
		var out = [];
		res.strands.forEach(function (s) {
			if (s.merged) { return; }
			// double-terminal 2-strand case: pendingClose set twice -> closed loop
			if (s.pendingClose && seg.endA !== 'corner' && seg.endB !== 'corner' && N === 2) { s.closed = true; }
			out.push({ pts: s.pts.map(function (p) { return toPage(edge, p[0], p[1]); }), color: s.color, closed: !!s.closed });
		});
		return out;
	}
```

**Careful with the merge bookkeeping above** — the closed-loop rule is: a polyline is `closed` when BOTH of its free ends got terminal arcs (only happens for the outer pair of a both-ends-terminal segment with N=2, or after chaining both ends for the same pair). The test in Step 1 pins the two cases that matter (N=2 both-terminal → 1 closed loop; N=3 one-terminal → 2 open polylines). Implement to the tests; simplify the flags if a cleaner equivalent passes.

Then the SVG assembly (still inside the IIFE):

```js
	// ---------- SVG ----------
	var uidCounter = 0;
	function svgEl(tag) { return document.createElementNS(SVGNS, tag); }
	function polyPath(pts, closed) {
		var d = 'M' + pts[0][0].toFixed(2) + ' ' + pts[0][1].toFixed(2);
		for (var i = 1; i < pts.length; i++) { d += 'L' + pts[i][0].toFixed(2) + ' ' + pts[i][1].toFixed(2); }
		return closed ? d + 'Z' : d;
	}
	function strokePath(parent, d, paint, width) {
		var p = svgEl('path');
		p.setAttribute('d', d); p.setAttribute('fill', 'none');
		p.setAttribute('stroke', paint); p.setAttribute('stroke-width', width.toFixed(2));
		p.setAttribute('stroke-linecap', 'round'); p.setAttribute('stroke-linejoin', 'round');
		parent.appendChild(p);
		return p;
	}
	// collectPolys: full border -> [{pts,color,closed}] page space (corners/medallions join in Tasks 3-4)
	function collectPolys(cfg, W, H, slots) {
		var layout = frameLayout(cfg, W, H);
		var ab = autoBreaks(cfg, W, H, slots, layout);
		var polys = [];
		['top', 'right', 'bottom', 'left'].forEach(function (name) {
			var e = layout.edges[name];
			var feats = [];
			cfg.breaks.forEach(function (b) {
				if (b.edge !== name) { return; }
				var c = b.at / 100 * e.len, h = b.width / 100 * e.len / 2;
				feats.push({ type: 'break', u0: c - h, u1: c + h });
			});
			ab[name].forEach(function (iv) { feats.push({ type: 'break', u0: iv[0], u1: iv[1] }); });
			cfg.medallions.forEach(function (m) {
				if (m.edge !== name) { return; }
				var hd = (m.size / 100 * layout.S) / 2, c = m.at / 100 * e.len, pad = layout.band * 0.15;
				feats.push({ type: 'medallion', u0: c - hd - pad, u1: c + hd + pad, med: m });
			});
			// merge plain breaks first so overlapping intervals don't create phantom segments
			var brk = mergeIntervals(feats.filter(function (f) { return f.type === 'break'; }).map(function (f) { return [f.u0, f.u1]; }))
				.map(function (iv) { return { type: 'break', u0: iv[0], u1: iv[1] }; });
			var meds = feats.filter(function (f) { return f.type === 'medallion'; });
			var cornerEnd = (cfg.corners === 'hook') ? 'terminal' : 'corner';
			segmentEdge(e.len, brk.concat(meds), layout.band, cornerEnd).forEach(function (seg) {
				buildSegmentPolys(e, seg, cfg, layout).forEach(function (p) { polys.push(p); });
			});
		});
		return { layout: layout, polys: polys };
	}
	function render(rawCfg, W, H, slots) {
		var cfg = norm(rawCfg);
		var svg = svgEl('svg');
		svg.setAttribute('class', 'sc-knot');
		svg.setAttribute('viewBox', '0 0 ' + W + ' ' + H);
		svg.setAttribute('preserveAspectRatio', 'none');
		if (!cfg.enabled) { return svg; }
		var uid = ++uidCounter;
		var got = collectPolys(cfg, W, H, slots);
		var polys = got.polys;
		// paints
		var paints = cfg.colors.strands.slice();
		if (cfg.gradient.enabled) {
			var defs = svgEl('defs');
			var rad = cfg.gradient.angle * Math.PI / 180;
			var dx = Math.cos(rad), dy = Math.sin(rad);
			var R = (Math.abs(dx) * W + Math.abs(dy) * H) / 2, cx = W / 2, cy = H / 2;
			cfg.colors.strands.forEach(function (hex, k) {
				var g = svgEl('linearGradient');
				g.setAttribute('id', 'skg' + uid + '_' + k); g.setAttribute('gradientUnits', 'userSpaceOnUse');
				g.setAttribute('x1', (cx - dx * R).toFixed(1)); g.setAttribute('y1', (cy - dy * R).toFixed(1));
				g.setAttribute('x2', (cx + dx * R).toFixed(1)); g.setAttribute('y2', (cy + dy * R).toFixed(1));
				cfg.gradient.stops.forEach(function (st) {
					var s = svgEl('stop');
					s.setAttribute('offset', (clamp(st.at, 0, 1) * 100) + '%');
					s.setAttribute('stop-color', blendHex(hex, st.color, 0.8));
					g.appendChild(s);
				});
				defs.appendChild(g);
				paints[k] = 'url(#skg' + uid + '_' + k + ')';
			});
			svg.appendChild(defs);
		}
		var band = got.layout.band, N = clamp(cfg.strands.count, 1, 4);
		var wf = strandW(band, N, cfg.strands), wOut = wf + 2 * outlineW(wf), gapPx = cfg.strands.gap * wf;
		function paintOf(colorIdx) { return paints[colorIdx % paints.length]; }
		var gOutline = svgEl('g'), gFill = svgEl('g'), gCross = svgEl('g');
		polys.forEach(function (p) { strokePath(gOutline, polyPath(p.pts, p.closed), cfg.colors.outline, wOut); });
		polys.forEach(function (p) { strokePath(gFill, polyPath(p.pts, p.closed), paintOf(p.color), wf); });
		findCrossings(polys, wf * 0.8).forEach(function (c) {
			var overIdx = (c.over === 'a') ? c.a : c.b;
			var idx = (c.over === 'a') ? c.ia : c.ib, frac = (c.over === 'a') ? c.fa : c.fb;
			var p = polys[overIdx];
			var arc = subPolyline(p.pts, p.closed, idx, frac, wf * 0.75 + gapPx);
			if (arc.length < 2) { return; }
			var d = polyPath(arc, false);
			strokePath(gCross, d, cfg.colors.outline, wOut + 2 * gapPx);
			strokePath(gCross, d, paintOf(p.color), wf);
		});
		svg.appendChild(gOutline); svg.appendChild(gFill); svg.appendChild(gCross);
		return svg;
	}
	// small horizontal weave strip for designer pattern thumbnails
	function swatch(rawCfg, wPx, hPx) {
		var cfg = norm(rawCfg);
		cfg.enabled = true; cfg.breaks = []; cfg.medallions = []; cfg.autoBreak.enabled = false;
		var svg = svgEl('svg');
		svg.setAttribute('class', 'sc-knot-swatch');
		svg.setAttribute('viewBox', '0 0 ' + wPx + ' ' + hPx);
		var band = hPx * 0.8;
		var edge = { name: 'top', ox: 4, oy: (hPx - band) / 2, ux: 1, uy: 0, vx: 0, vy: 1, len: wPx - 8 };
		var layout = { band: band, S: hPx, W: wPx, H: hPx };
		var seg = { u0: 0, u1: edge.len, endA: 'terminal', endB: 'terminal', medA: null, medB: null };
		var polys = buildSegmentPolys(edge, seg, cfg, layout);
		var N = clamp(cfg.strands.count, 1, 4);
		var wf = strandW(band, N, cfg.strands), wOut = wf + 2 * outlineW(wf), gapPx = cfg.strands.gap * wf;
		var g1 = svgEl('g'), g2 = svgEl('g'), g3 = svgEl('g');
		polys.forEach(function (p) { strokePath(g1, polyPath(p.pts, p.closed), cfg.colors.outline, wOut); });
		polys.forEach(function (p) { strokePath(g2, polyPath(p.pts, p.closed), cfg.colors.strands[p.color % cfg.colors.strands.length], wf); });
		findCrossings(polys, wf * 0.8).forEach(function (c) {
			var overIdx = (c.over === 'a') ? c.a : c.b, idx = (c.over === 'a') ? c.ia : c.ib, frac = (c.over === 'a') ? c.fa : c.fb;
			var p = polys[overIdx], arc = subPolyline(p.pts, p.closed, idx, frac, wf * 0.75 + gapPx);
			if (arc.length < 2) { return; }
			strokePath(g3, polyPath(arc, false), cfg.colors.outline, wOut + 2 * gapPx);
			strokePath(g3, polyPath(arc, false), cfg.colors.strands[p.color % cfg.colors.strands.length], wf);
		});
		svg.appendChild(g1); svg.appendChild(g2); svg.appendChild(g3);
		return svg;
	}
```

Register in the export block (replace the existing `var K = {...}` tail):

```js
	var K = {
		render: render,
		swatch: swatch,
		_geom: {
			norm: norm, frameLayout: frameLayout, toPage: toPage, lane: lane, strandW: strandW, outlineW: outlineW,
			mergeIntervals: mergeIntervals, segmentEdge: segmentEdge, autoBreaks: autoBreaks,
			patterns: patterns, findCrossings: findCrossings, blendHex: blendHex, subPolyline: subPolyline,
			buildSegmentPolys: buildSegmentPolys, collectPolys: collectPolys, uTurn: uTurn, curl: curl,
			STEP: STEP, TERM: TERM, EASE: EASE, clamp: clamp, lerp: lerp, smooth: smooth
		}
	};
	w.ScrollKnot = K;
```

- [ ] **Step 4: Run tests**

Run: `node tools/test-scroll-knot.cjs`
Expected: `ALL PASS`. The `render`/`swatch` functions reference `document` — that's fine in Node as long as tests never CALL them (they don't).

- [ ] **Step 5: Visual smoke check (scratchpad, not committed)**

Write a scratchpad HTML page that loads `scroll-knot.js`, calls `ScrollKnot.render({enabled:true, pattern:'plait', colors:{strands:['#b3231a','#e4670f','#f5a623'], outline:'#2a0c05'}, breaks:[{edge:'bottom',at:50,width:26}]}, 816, 1056, [])`, appends it to a 816×1056 div with a parchment background color, and open it via `open <file>` in the default browser (or read it back with a headless screenshot if available). Confirm by eye: continuous braid on all four edges, dark outlines, over/under alternation visible, bottom gap with looped terminal ends, no strand escaping the band. Iterate constants (λ factor, amp margin, TERM reach) until the braid reads like the reference tight plait.

- [ ] **Step 6: Commit**

```bash
git add orkui/template/revised-frontend/scroll/scroll-knot.js tools/test-scroll-knot.cjs
git commit -m "Scroll: knotwork SVG renderer (two-pass interlace, terminals, gradients, swatch)"
```

---

### Task 3: Remaining patterns — openweave, twist, runningknot

**Files:**
- Modify: `orkui/template/revised-frontend/scroll/scroll-knot.js` (add to `patterns`)
- Modify: `tools/test-scroll-knot.cjs` (append tests)

**Interfaces:**
- Consumes: pattern contract from Task 1.
- Produces: `patterns.openweave`, `patterns.twist`, `patterns.runningknot` — same contract as `patterns.plait`.

Geometry (exact):

- **openweave** (Dragon/Crown look — interlocking two-tone diamond lattice): 4 strands, `λ0 = band*2.6*scale`. Strand k ∈ {0..3}: pair = k>>1 (0=A,1=B), sign = (k&1) ? −1 : +1, phase = pair * π/2. `v(u) = band/2 + sign * amp * sin(2πu/λ + phase)`. `color = pair`. Lane easing: ease strand k to `lane(order[k], 4, band)` with `order = [0, 2, 1, 3]` (keeps pair A outer/inner symmetric at ports). If `sp.count <= 2`, emit only pair A plus pair B *with color 1* anyway (openweave is inherently 2-pair; count is ignored, document via clamp).
- **twist** (rope): 2 strands, `λ0 = band*1.15*scale`, `v(u) = band/2 ± amp*sin(2πu/λ)`, thickness boosted: use `wf' = strandW(band, 2, sp) * 1.2` — implement by passing `N=2` and letting `render()` compute `wf` from `count`; instead set `sp2 = {count:2, thickness: clamp(sp.thickness*1.25, .3, .9), ...}` inside the generator for its OWN amp math only (render's stroke width uses cfg count — so ALSO clamp `cfg.strands.count` to the pattern's natural count in `norm()`? No — width must match. Resolution: `render()`/`swatch()` derive `wf` from `res.strands.length` actually generated per segment. **Adjust render/swatch in this task**: compute `wf` per-polyline group using `NEff = (pattern==='twist'||pattern==='runningknot') ? 2 : (pattern==='openweave' ? 4 : cfg.strands.count)`; expose `_geom.effCount(cfg)` and use it in both `render()` and `swatch()`.)
- **runningknot** (loop chain): ONE strand (color 0) as a prolate cycloid: `reps = max(2, round(L/λ0))`, `λ = L/reps`, `R = λ/(2π)`, `d = amp*0.95` (d > R guaranteed by clamping λ ≤ band*2): points `u(t) = R*t − d*sin(t)` normalized so u spans [0,L], `v(t) = band/2 − d_t*cos(t)` where `d_t` fades to 0.25·d over the first/last half-turn (straightens the ends); sample `t ∈ [0, reps*2π]` at `dt = 0.12`. Plus a straight companion "rail" strand (color 1) at `v = band/2` drawn UNDER the loops (it threads the chain — crossings with the loop strand alternate naturally). `effCount = 2`.

- [ ] **Step 1: Append failing tests**

Append before the final `console.log`:

```js
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
```

- [ ] **Step 2: Run tests to verify the new ones fail**

Run: `node tools/test-scroll-knot.cjs` → FAIL with `G.patterns.openweave is not a function`.

- [ ] **Step 3: Implement the three generators + effCount**

```js
	function effCount(cfg) {
		if (cfg.pattern === 'openweave') { return 4; }
		if (cfg.pattern === 'twist' || cfg.pattern === 'runningknot') { return 2; }
		return clamp(cfg.strands.count, 2, 4);
	}
	patterns.openweave = function (L, band, sp) {
		var lam0 = Math.max(band * 2.6 * sp.scale, 10);
		var reps = Math.max(1, Math.round(L / lam0)), lam = L / reps;
		var wf = strandW(band, 4, sp), amp = Math.max(1, band / 2 - wf / 2 - outlineW(wf) - 1);
		var ease = EASE(lam, L), step = STEP(band), order = [0, 2, 1, 3], strands = [];
		for (var k = 0; k < 4; k++) {
			var pair = k >> 1, sign = (k & 1) ? -1 : 1, phase = pair * Math.PI / 2, pts = [];
			for (var u = 0; u <= L + 1e-6; u += step) {
				var uu = Math.min(u, L);
				var vv = band / 2 + sign * amp * Math.sin(Math.PI * 2 * uu / lam + phase);
				var d = Math.min(uu, L - uu);
				if (d < ease) { vv = lerp(lane(order[k], 4, band), vv, smooth(d / ease)); }
				pts.push([uu, vv]);
				if (uu >= L) { break; }
			}
			if (pts[pts.length - 1][0] < L) { pts.push([L, lane(order[k], 4, band)]); }
			strands.push({ pts: pts, color: pair, closed: false });
		}
		return { strands: strands };
	};
	patterns.twist = function (L, band, sp) {
		var sp2 = { count: 2, thickness: clamp(sp.thickness * 1.25, 0.3, 0.9), gap: sp.gap, scale: sp.scale };
		var lam0 = Math.max(band * 1.15 * sp.scale, 8);
		var reps = Math.max(1, Math.round(L / lam0)), lam = L / reps;
		var wf = strandW(band, 2, sp2), amp = Math.max(1, band / 2 - wf / 2 - outlineW(wf) - 1);
		var ease = EASE(lam, L), step = STEP(band), strands = [];
		for (var k = 0; k < 2; k++) {
			var sign = k ? -1 : 1, pts = [];
			for (var u = 0; u <= L + 1e-6; u += step) {
				var uu = Math.min(u, L);
				var vv = band / 2 + sign * amp * Math.sin(Math.PI * 2 * uu / lam);
				var d = Math.min(uu, L - uu);
				if (d < ease) { vv = lerp(lane(k, 2, band), vv, smooth(d / ease)); }
				pts.push([uu, vv]);
				if (uu >= L) { break; }
			}
			if (pts[pts.length - 1][0] < L) { pts.push([L, lane(k, 2, band)]); }
			strands.push({ pts: pts, color: k, closed: false });
		}
		return { strands: strands };
	};
	patterns.runningknot = function (L, band, sp) {
		var wf = strandW(band, 2, sp), amp = Math.max(2, band / 2 - wf / 2 - outlineW(wf) - 1);
		var lam0 = Math.min(Math.max(band * 1.8 * sp.scale, 10), band * 2);
		var reps = Math.max(2, Math.round(L / lam0)), lam = L / reps;
		var R = lam / (2 * Math.PI), d = Math.max(amp * 0.95, R * 1.35);
		var pts = [], T = reps * 2 * Math.PI;
		for (var t = 0; t <= T + 1e-9; t += 0.12) {
			var tt = Math.min(t, T);
			var fade = Math.min(1, Math.min(tt, T - tt) / Math.PI);       // straighten ends over a half-turn
			var dt = d * lerp(0.25, 1, smooth(fade));
			var uRaw = R * tt - dt * Math.sin(tt);
			pts.push([clamp(uRaw / (R * T) * L, 0, L), band / 2 - dt * Math.cos(tt)]);
			if (tt >= T) { break; }
		}
		var rail = [[0, band / 2], [L, band / 2]];
		return { strands: [ { pts: pts, color: 0, closed: false }, { pts: rail, color: 1, closed: false } ] };
	};
```

Then update `render()` and `swatch()`: replace `var N = clamp(cfg.strands.count, 1, 4);` with `var N = effCount(cfg);`, and for twist boost width: `var wf = strandW(band, N, cfg.strands) * (cfg.pattern === 'twist' ? 1.25 : 1);`. Add `effCount: effCount` to `_geom`.

Note the runningknot loop strand's v-extent is `band/2 ± d` with `d` up to `R*1.35` — clamp final v into `[wf/2+1, band−wf/2−1]` when pushing points so loops never escape the band.

- [ ] **Step 4: Run tests**

`node tools/test-scroll-knot.cjs` → `ALL PASS`.

- [ ] **Step 5: Visual smoke check**

Extend the scratchpad page: four stacked 816×140 strips, one per pattern (`swatch(cfg, 780, 120)`), Dragon colors for openweave, Smith colors for twist. Eyeball: openweave = interlocking two-tone diamonds; twist = rope; runningknot = loop chain threaded on a rail. Tune λ factors if a pattern reads wrong.

- [ ] **Step 6: Commit**

```bash
git add orkui/template/revised-frontend/scroll/scroll-knot.js tools/test-scroll-knot.cjs
git commit -m "Scroll: knotwork patterns — openweave, twist, runningknot"
```

---

### Task 4: Corners (woven + hook) and medallions

**Files:**
- Modify: `orkui/template/revised-frontend/scroll/scroll-knot.js`
- Modify: `tools/test-scroll-knot.cjs` (append tests)

**Interfaces:**
- Consumes: Tasks 1–3.
- Produces:
  - `collectPolys` extended: corner polylines + medallion ring polylines included in its output.
  - `ScrollKnot.medallionInnerRects(knotCfg, W, H) -> [{edge, at, x, y, w, h}]` — PERCENT page coords of each medallion's inner clear rect (public API used by the designer in Task 6).
  - `_geom.cornerPolys(cornerKey, cfg, layout) -> [{pts, color, closed}]`; `_geom.medallionPolys(med, edge, layout, cfg) -> [{pts, color, closed}]`.

Geometry (exact):

- **Woven corner** (`cornerKey` ∈ tl/tr/bl/br): connect the N lanes of the two adjacent edge runs through the band×band corner box. Lane permutation `perm(i) = (N even) ? (i+2)%N : (N-1-i)` (parity-preserving → strand colors continue). Each connection = cubic bezier sampled at 24 points: from port `PA` (end of edge A at lane i, page coords) to `PB` (start of edge B at lane perm(i)), control points `PA + dirA*band*0.45` and `PB − dirB*band*0.45` where dirA/dirB are the edges' unit u-vectors pointing INTO the corner. Color = `i % strands.length`. Crossings between the connections are found by the existing global `findCrossings`.
  - Edge/corner adjacency (edge runs oriented +x / +y): `tl`: left edge start ↔ top edge start (dirA = (0,−1) out of left start means INTO corner is (0,−1)? — concretely: for corner tl, ports are top edge at u=0 and left edge at u=0; INTO-corner directions are (−1,0) from the top edge and (0,−1) from the left edge. `tr`: top u=len (into: (1,0)) ↔ right u=0 (into: (0,−1)). `bl`: bottom u=0 (into: (−1,0)) ↔ left u=len (into: (0,1)). `br`: bottom u=len (into: (1,0)) ↔ right u=len (into: (0,1)).
- **Hook corner**: edge ends adjacent to the corner already terminate (Task 2's `cornerEnd='terminal'` when `cfg.corners==='hook'`). The hook itself = one thick spiral: 270° arc sampled at 32 pts, center at the corner box center, radius from `band*0.42` decaying to `band*0.12`, starting angle facing edge A; color 0, drawn as a normal polyline (outline+fill passes apply).
- **Medallion**: two closed diamond rings centered at `C = toPage(edge, at/100*len, band/2)`:
  - Ring A (color 0): half-diagonals `(hd*1.0, hd*0.8)` — wide;
  - Ring B (color 1): `(hd*0.8, hd*1.0)` — tall; `hd = size/100*S/2`.
  - Each ring = the 4 diamond sides sampled at 12 pts/side (closed polyline, 48 pts). Diamond axes: along-edge axis = edge's u direction, across = v direction. Rings intersect at 8 points → `findCrossings` interlaces them.
  - `medallionInnerRects`: inner half = `hd*0.8/Math.SQRT2*0.9`; rect centered on C: `{x:(Cx−half)/W*100, y:(Cy−half)/H*100, w:2*half/W*100, h:2*half/H*100}`.

- [ ] **Step 1: Append failing tests**

```js
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
ok(G.findCrossings(rings).length >= 6, 'medallion rings interlace (>=6 crossings), got ' + G.findCrossings(rings).length);
const inner = K.medallionInnerRects({ enabled: true, medallions: [{ edge: 'left', at: 45, size: 14 }] }, 816, 1056);
ok(inner.length === 1 && inner[0].edge === 'left', 'medallionInnerRects returns entry');
ok(inner[0].w > 2 && inner[0].w < 14 && Math.abs(inner[0].w / inner[0].h - (1056 / 816) * (816 / 1056) * (816 / 1056) - 0) < 10, 'inner rect sane');  // w% and h% differ by page aspect
const cxPct = inner[0].x + inner[0].w / 2;
ok(cxPct < 15, 'left-edge medallion sits near left side');

// ---- full render polys include corners + medallions (collectPolys)
const full = G.collectPolys(medCfg, 816, 1056, []);
ok(full.polys.length > 8, 'collectPolys includes edges + corners + medallion rings');
```

(Drop the over-clever aspect assertion if it fights you — assert `inner[0].h > 1 && inner[0].h < 14` instead. The invariant: percent rect, centered on the medallion, small.)

- [ ] **Step 2: Run to verify failure** — `G.cornerPolys is not a function`.

- [ ] **Step 3: Implement**

```js
	// ---------- corners ----------
	var CORNER_DEF = {
		tl: { A: ['top', 0], B: ['left', 0], dirA: [-1, 0], dirB: [0, -1] },
		tr: { A: ['top', 1], B: ['right', 0], dirA: [1, 0], dirB: [0, -1] },
		bl: { A: ['bottom', 0], B: ['left', 1], dirA: [-1, 0], dirB: [0, 1] },
		br: { A: ['bottom', 1], B: ['right', 1], dirA: [1, 0], dirB: [0, 1] }
	};
	function cubic(p0, c1, c2, p1, samples) {
		var pts = [];
		for (var k = 0; k <= samples; k++) {
			var t = k / samples, mt = 1 - t;
			pts.push([
				mt * mt * mt * p0[0] + 3 * mt * mt * t * c1[0] + 3 * mt * t * t * c2[0] + t * t * t * p1[0],
				mt * mt * mt * p0[1] + 3 * mt * mt * t * c1[1] + 3 * mt * t * t * c2[1] + t * t * t * p1[1]
			]);
		}
		return pts;
	}
	function cornerPolys(key, cfg, layout) {
		var def = CORNER_DEF[key], N = effCount(cfg), out = [];
		var eA = layout.edges[def.A[0]], eB = layout.edges[def.B[0]];
		var uA = def.A[1] ? eA.len : 0, uB = def.B[1] ? eB.len : 0;
		if (cfg.corners === 'hook') {
			var box = layout.corners[key], cx = box.x + layout.band / 2, cy = box.y + layout.band / 2;
			var pts = [], a0 = Math.atan2(def.dirA[1], def.dirA[0]) + Math.PI;   // enter opposite the into-dir
			for (var k = 0; k <= 32; k++) {
				var th = a0 + k / 32 * 1.5 * Math.PI, r = lerp(layout.band * 0.42, layout.band * 0.12, k / 32);
				pts.push([cx + Math.cos(th) * r, cy + Math.sin(th) * r]);
			}
			out.push({ pts: pts, color: 0, closed: false });
			return out;
		}
		function perm(i) { return (N % 2 === 0) ? (i + 2) % N : (N - 1 - i); }
		for (var i = 0; i < N; i++) {
			var PA = toPage(eA, uA, lane(i, N, layout.band));
			var PB = toPage(eB, uB, lane(perm(i), N, layout.band));
			var c1 = [PA[0] + def.dirA[0] * layout.band * 0.45, PA[1] + def.dirA[1] * layout.band * 0.45];
			var c2 = [PB[0] + def.dirB[0] * layout.band * 0.45, PB[1] + def.dirB[1] * layout.band * 0.45];
			out.push({ pts: cubic(PA, c1, c2, PB, 24), color: i, closed: false });
		}
		return out;
	}
	// ---------- medallions ----------
	function diamond(cx, cy, huU, hvV, e, samples) {
		// half-diagonals huU (along edge u dir) and hvV (along v dir), in page space via edge axes
		var ux = e.ux, uy = e.uy, vx = e.vx, vy = e.vy;
		var V = [
			[cx - ux * huU, cy - uy * huU], [cx + vx * hvV, cy + vy * hvV],
			[cx + ux * huU, cy + uy * huU], [cx - vx * hvV, cy - vy * hvV]
		];
		var pts = [];
		for (var s = 0; s < 4; s++) {
			var A = V[s], B = V[(s + 1) % 4];
			for (var k = 0; k < samples; k++) { var t = k / samples; pts.push([lerp(A[0], B[0], t), lerp(A[1], B[1], t)]); }
		}
		return pts;
	}
	function medallionPolys(med, e, layout, cfg) {
		var hd = (med.size / 100 * layout.S) / 2;
		var C = toPage(e, med.at / 100 * e.len, layout.band / 2);
		return [
			{ pts: diamond(C[0], C[1], hd * 1.0, hd * 0.8, e, 12), color: 0, closed: true },
			{ pts: diamond(C[0], C[1], hd * 0.8, hd * 1.0, e, 12), color: 1, closed: true }
		];
	}
	function medallionInnerRects(rawCfg, W, H) {
		var cfg = norm(rawCfg), layout = frameLayout(cfg, W, H), out = [];
		cfg.medallions.forEach(function (m) {
			var e = layout.edges[m.edge]; if (!e) { return; }
			var hd = (m.size / 100 * layout.S) / 2;
			var C = toPage(e, m.at / 100 * e.len, layout.band / 2);
			var half = hd * 0.8 / Math.SQRT2 * 0.9;
			out.push({ edge: m.edge, at: m.at, x: (C[0] - half) / W * 100, y: (C[1] - half) / H * 100, w: 2 * half / W * 100, h: 2 * half / H * 100 });
		});
		return out;
	}
```

Wire into `collectPolys` (after the four-edge loop):

```js
		['tl', 'tr', 'bl', 'br'].forEach(function (key) {
			cornerPolys(key, cfg, layout).forEach(function (p) { polys.push(p); });
		});
		cfg.medallions.forEach(function (m) {
			var e = layout.edges[m.edge]; if (!e) { return; }
			medallionPolys(m, e, layout, cfg).forEach(function (p) { polys.push(p); });
		});
```

Export: add `medallionInnerRects` to `K`, and `cornerPolys`/`medallionPolys`/`cubic` to `_geom`.

- [ ] **Step 4: Run tests** — `node tools/test-scroll-knot.cjs` → `ALL PASS`.

- [ ] **Step 5: Visual smoke check**

Scratchpad page full border with medallions left+right at 45, woven corners, then hook corners, then a bottom break. Eyeball: corners weave and colors continue; medallion lozenges interlace and connect visually with the edge terminal arcs; hooks curl at corners with open edge ends.

- [ ] **Step 6: Commit**

```bash
git add orkui/template/revised-frontend/scroll/scroll-knot.js tools/test-scroll-knot.cjs
git commit -m "Scroll: knotwork corners (woven/hook) + diamond medallions with inner-rect API"
```

---

### Task 5: Shared renderer + template integration

**Files:**
- Modify: `orkui/template/revised-frontend/scroll/scroll-render.js` (in `renderPage`, right after the `pageEl.appendChild(bg);` line)
- Modify: `orkui/template/revised-frontend/Scroll_builder.tpl` (script tag)
- Modify: `orkui/template/revised-frontend/Scroll_design.tpl` (script tag)
- Modify: `orkui/template/revised-frontend/style/scroll.css` (`.sc-knot`)

**Interfaces:**
- Consumes: `ScrollKnot.render(cfg, W, H, slots)`.
- Produces: any template whose JSON has `knot.enabled` renders the border on ALL surfaces (designer, filler, PDF). Templates without `knot` untouched.

- [ ] **Step 1: Insert the knot layer in `renderPage`**

In `scroll-render.js`, after `pageEl.appendChild(bg);` add:

```js
		// knotwork border layer (parametric, drawn between bg and slots)
		if (tpl.knot && tpl.knot.enabled && w.ScrollKnot) {
			var kd = (tpl.orientation === 'landscape') ? [1056, 816] : [816, 1056];
			pageEl.appendChild(w.ScrollKnot.render(tpl.knot, kd[0], kd[1], tpl.slots || []));
		}
```

(The IIFE parameter is already `w`; `window.ScrollKnot` is reachable as `w.ScrollKnot`.)

- [ ] **Step 2: Script tags**

In BOTH `Scroll_builder.tpl` and `Scroll_design.tpl`, add directly BEFORE the `scroll-render.js` script tag (plain PHP, mirrors the existing lines):

```php
<script src="<?= HTTP_TEMPLATE ?>revised-frontend/scroll/scroll-knot.js?v=<?= filemtime(DIR_TEMPLATE.'revised-frontend/scroll/scroll-knot.js') ?>"></script>
```

`.tpl` edit caveat: these files may be tab-indented — if the Edit tool misses on whitespace, use the python3 pathlib `replace` fallback from memory.

- [ ] **Step 3: CSS layer rule**

In `scroll.css`, near the `.sc-slot` rules add:

```css
.sc-knot { position:absolute; inset:0; width:100%; height:100%; pointer-events:none; }
```

- [ ] **Step 4: Verify in the running app**

Docker app at `http://localhost:19080/orkui/`. In the designer (`Scroll/design/{kingdomId}`), via browser console:
`SC_DESIGN` page → run `(function(){ var t = JSON.parse(sessionStorage.getItem('x')||'null'); })()` — simpler: in console on the designer page run:

```js
// grab the live tpl via a slot add + render hook is overkill; instead render directly:
document.getElementById('scPage').appendChild(ScrollKnot.render({enabled:true, pattern:'openweave', colors:{strands:['#2e6b2f','#e9b840'], outline:'#12240f'}}, 816, 1056, []));
```

Expected: green/gold interlaced border overlays the page. Then remove it (`document.querySelector('.sc-knot').remove()`). Full integration (knot in tpl JSON) is exercised in Task 6 when the panel writes `tpl.knot`.

- [ ] **Step 5: Commit**

```bash
git add orkui/template/revised-frontend/scroll/scroll-render.js orkui/template/revised-frontend/Scroll_builder.tpl orkui/template/revised-frontend/Scroll_design.tpl orkui/template/revised-frontend/style/scroll.css
git commit -m "Scroll: render knotwork layer in shared renderer + include engine on both surfaces"
```

---

### Task 6: Designer Border panel, presets, break_border checkbox, emblem-slot button

**Files:**
- Modify: `orkui/template/revised-frontend/Scroll_design.tpl` (Border section between the "Page" and "Elements" sections)
- Modify: `orkui/template/revised-frontend/scroll/scroll-design.js`
- Modify: `orkui/template/revised-frontend/style/scroll.css`

**Interfaces:**
- Consumes: `ScrollKnot.swatch`, `ScrollKnot.medallionInnerRects`, existing helpers `el/field/input/select/render/refreshInspector`, `tpl` object.
- Produces: `tpl.knot` config persisted through the existing save path (JSON blob — no backend change); slots may carry `break_border: true`.

- [ ] **Step 1: Border section in Scroll_design.tpl**

After the `Page` section line (`<section class="sc-sec"><h3 class="sc-eyebrow">Page</h3>...`), insert:

```php
			<section class="sc-sec"><h3 class="sc-eyebrow">Border</h3><div id="scKnot"></div></section>
```

- [ ] **Step 2: Presets + panel in scroll-design.js**

Add after the `LOCATIONS` declaration:

```js
	var KNOT_PRESETS = {
		Flame: { enabled: true, pattern: 'plait', band: { inset: 1.8, width: 5.5 }, strands: { count: 3, thickness: 0.6, gap: 0.12, scale: 1 },
			colors: { strands: ['#b3231a', '#e4670f', '#f5a623'], outline: '#2a0c05' },
			gradient: { enabled: true, angle: 90, stops: [{ at: 0, color: '#a11212' }, { at: 0.55, color: '#e4670f' }, { at: 1, color: '#f7c948' }] },
			corners: 'hook', medallions: [{ edge: 'left', at: 42, size: 13, shape: 'diamond' }, { edge: 'right', at: 42, size: 13, shape: 'diamond' }],
			breaks: [{ edge: 'top', at: 50, width: 10 }, { edge: 'bottom', at: 50, width: 26 }], autoBreak: { enabled: true, padding: 2 } },
		Dragon: { enabled: true, pattern: 'openweave', band: { inset: 2, width: 6.2 }, strands: { count: 4, thickness: 0.55, gap: 0.12, scale: 1 },
			colors: { strands: ['#2e6b2f', '#e9b840'], outline: '#12240f' }, gradient: { enabled: false, angle: 90, stops: [{ at: 0, color: '#2e6b2f' }, { at: 1, color: '#e9b840' }] },
			corners: 'woven', medallions: [{ edge: 'left', at: 40, size: 14, shape: 'diamond' }, { edge: 'right', at: 40, size: 14, shape: 'diamond' }],
			breaks: [{ edge: 'bottom', at: 50, width: 26 }], autoBreak: { enabled: true, padding: 2 } },
		Crown: { enabled: true, pattern: 'openweave', band: { inset: 2, width: 6 }, strands: { count: 4, thickness: 0.55, gap: 0.12, scale: 1 },
			colors: { strands: ['#2b2b2e', '#e7b83b'], outline: '#101012' }, gradient: { enabled: false, angle: 90, stops: [{ at: 0, color: '#2b2b2e' }, { at: 1, color: '#e7b83b' }] },
			corners: 'woven', medallions: [{ edge: 'left', at: 33, size: 13, shape: 'diamond' }, { edge: 'right', at: 33, size: 13, shape: 'diamond' }],
			breaks: [{ edge: 'bottom', at: 50, width: 30 }], autoBreak: { enabled: true, padding: 2 } },
		Smith: { enabled: true, pattern: 'twist', band: { inset: 2, width: 5.8 }, strands: { count: 2, thickness: 0.6, gap: 0.14, scale: 1 },
			colors: { strands: ['#8a6844', '#7b8494'], outline: '#241a10' }, gradient: { enabled: false, angle: 90, stops: [{ at: 0, color: '#8a6844' }, { at: 1, color: '#7b8494' }] },
			corners: 'woven', medallions: [{ edge: 'left', at: 45, size: 13, shape: 'diamond' }, { edge: 'right', at: 45, size: 13, shape: 'diamond' }],
			breaks: [{ edge: 'bottom', at: 50, width: 30 }], autoBreak: { enabled: true, padding: 2 } }
	};
	var KNOT_PATTERNS = ['plait', 'openweave', 'twist', 'runningknot'];
```

Then the panel builder (near `buildPage`); complete code:

```js
	// ---- inspector: Border (knotwork) ----
	function knotCfg() {
		if (!tpl.knot) { tpl.knot = { enabled: false }; }
		return tpl.knot;
	}
	function checkbox(labelText, val, on) {
		var wrap = el('label', 'sc-check');
		var c = el('input'); c.type = 'checkbox'; c.checked = !!val;
		c.addEventListener('change', function () { on(c.checked); });
		wrap.appendChild(c); wrap.appendChild(el('span', null, labelText));
		return wrap;
	}
	function slider(labelText, val, min, max, step, on) {
		var wrap = el('label', 'sc-field');
		wrap.appendChild(el('span', 'sc-field__label', labelText));
		var i = el('input', 'sc-input'); i.type = 'range'; i.min = min; i.max = max; i.step = step; i.value = val;
		i.addEventListener('input', function () { on(+i.value); });
		wrap.appendChild(i);
		return wrap;
	}
	function buildKnot() {
		var box = document.getElementById('scKnot'); if (!box) { return; }
		box.innerHTML = '';
		var k = knotCfg();
		// presets
		var pr = el('div', 'sc-chips');
		Object.keys(KNOT_PRESETS).forEach(function (name) {
			var b = el('button', 'sc-chip', name); b.type = 'button';
			b.onclick = function () { tpl.knot = JSON.parse(JSON.stringify(KNOT_PRESETS[name])); render(); buildKnot(); };
			pr.appendChild(b);
		});
		box.appendChild(field('Presets', pr));
		box.appendChild(checkbox('Knotwork border', k.enabled, function (v) { k.enabled = v; render(); buildKnot(); }));
		if (!k.enabled) { return; }
		// normalize once so sub-objects exist for editing
		var full = window.ScrollKnot._geom.norm(k);
		['pattern', 'band', 'strands', 'colors', 'gradient', 'corners', 'medallions', 'breaks', 'autoBreak'].forEach(function (key) {
			if (k[key] == null) { k[key] = full[key]; }
		});
		k.enabled = true;
		// pattern thumbnails
		var pats = el('div', 'sc-knot-pats');
		KNOT_PATTERNS.forEach(function (p) {
			var b = el('button', 'sc-knot-pat' + (k.pattern === p ? ' is-sel' : '')); b.type = 'button'; b.setAttribute('data-tip', p);
			var cfg = JSON.parse(JSON.stringify(k)); cfg.pattern = p;
			b.appendChild(window.ScrollKnot.swatch(cfg, 150, 34));
			b.onclick = function () { k.pattern = p; render(); buildKnot(); };
			pats.appendChild(b);
		});
		box.appendChild(field('Pattern', pats));
		var row1 = el('div', 'sc-row');
		row1.appendChild(slider('Inset', k.band.inset, 0.5, 6, 0.1, function (v) { k.band.inset = v; render(); }));
		row1.appendChild(slider('Width', k.band.width, 3, 10, 0.1, function (v) { k.band.width = v; render(); }));
		box.appendChild(row1);
		var row2 = el('div', 'sc-row');
		row2.appendChild(slider('Strands', k.strands.count, 2, 4, 1, function (v) { k.strands.count = v; render(); buildKnot(); }));
		row2.appendChild(slider('Thickness', k.strands.thickness, 0.3, 0.9, 0.05, function (v) { k.strands.thickness = v; render(); }));
		box.appendChild(row2);
		var row3 = el('div', 'sc-row');
		row3.appendChild(slider('Cut gap', k.strands.gap, 0, 0.3, 0.02, function (v) { k.strands.gap = v; render(); }));
		row3.appendChild(slider('Density', k.strands.scale, 0.6, 1.8, 0.05, function (v) { k.strands.scale = v; render(); }));
		box.appendChild(row3);
		// strand colors
		var cc = el('div', 'sc-chips');
		k.colors.strands.forEach(function (hex, i) {
			var swatchWrap = el('span', 'sc-knot-color');
			var ci = el('input'); ci.type = 'color'; ci.value = hex;
			ci.addEventListener('input', function () { k.colors.strands[i] = ci.value || hex; render(); });
			swatchWrap.appendChild(ci);
			if (k.colors.strands.length > 1) {
				var x = el('button', 'sc-knot-color__del', '×'); x.type = 'button'; x.setAttribute('data-tip', 'Remove color');
				x.onclick = function () { k.colors.strands.splice(i, 1); render(); buildKnot(); };
				swatchWrap.appendChild(x);
			}
			cc.appendChild(swatchWrap);
		});
		if (k.colors.strands.length < 4) {
			var add = el('button', 'sc-chip', '+'); add.type = 'button'; add.setAttribute('data-tip', 'Add strand color');
			add.onclick = function () { k.colors.strands.push('#888888'); render(); buildKnot(); };
			cc.appendChild(add);
		}
		box.appendChild(field('Strand colors', cc));
		box.appendChild(field('Outline', input(k.colors.outline || '#1a1a1a', 'color', function (v) { k.colors.outline = v || '#1a1a1a'; render(); })));
		// gradient
		box.appendChild(checkbox('Gradient tint', k.gradient.enabled, function (v) { k.gradient.enabled = v; render(); buildKnot(); }));
		if (k.gradient.enabled) {
			box.appendChild(slider('Angle', k.gradient.angle, 0, 360, 5, function (v) { k.gradient.angle = v; render(); }));
			var gs = el('div', 'sc-chips');
			k.gradient.stops.forEach(function (st, i) {
				var gi = el('input'); gi.type = 'color'; gi.value = st.color;
				gi.addEventListener('input', function () { st.color = gi.value || st.color; render(); });
				gs.appendChild(gi);
			});
			box.appendChild(field('Gradient colors', gs));
		}
		box.appendChild(field('Corners', select(['woven', 'hook'], k.corners, function (v) { k.corners = v; render(); })));
		// medallions
		var medBox = el('div');
		k.medallions.forEach(function (m, i) {
			var row = el('div', 'sc-knot-feat');
			row.appendChild(field('Edge', select(['left', 'right', 'top', 'bottom'], m.edge, function (v) { m.edge = v; render(); })));
			row.appendChild(slider('Position', m.at, 5, 95, 1, function (v) { m.at = v; render(); }));
			row.appendChild(slider('Size', m.size, 6, 22, 0.5, function (v) { m.size = v; render(); }));
			var act = el('div', 'sc-chips');
			var slotBtn = el('button', 'sc-chip', 'Add emblem slot'); slotBtn.type = 'button';
			slotBtn.onclick = function () {
				var rects = window.ScrollKnot.medallionInnerRects(k, tpl.orientation === 'landscape' ? 1056 : 816, tpl.orientation === 'landscape' ? 816 : 1056);
				var r = rects[i]; if (!r) { return; }
				tpl.slots.push({ location: 'center_image', x: r.x, y: r.y, w: r.w, h: r.h, source_type: 'pack', source_ref: '', fit: 'contain' });
				sel = { kind: 'slot', index: tpl.slots.length - 1 };
				render(); refreshInspector();
			};
			var del = el('button', 'sc-chip', 'Remove'); del.type = 'button';
			del.onclick = function () { k.medallions.splice(i, 1); render(); buildKnot(); };
			act.appendChild(slotBtn); act.appendChild(del);
			row.appendChild(act);
			medBox.appendChild(row);
		});
		var addMed = el('button', 'sc-chip', '+ Medallion'); addMed.type = 'button';
		addMed.onclick = function () { k.medallions.push({ edge: 'left', at: 45, size: 13, shape: 'diamond' }); render(); buildKnot(); };
		medBox.appendChild(addMed);
		box.appendChild(field('Medallions', medBox));
		// manual breaks
		var brBox = el('div');
		k.breaks.forEach(function (b, i) {
			var row = el('div', 'sc-knot-feat');
			row.appendChild(field('Edge', select(['top', 'bottom', 'left', 'right'], b.edge, function (v) { b.edge = v; render(); })));
			row.appendChild(slider('Position', b.at, 0, 100, 1, function (v) { b.at = v; render(); }));
			row.appendChild(slider('Width', b.width, 4, 60, 1, function (v) { b.width = v; render(); }));
			var del = el('button', 'sc-chip', 'Remove'); del.type = 'button';
			del.onclick = function () { k.breaks.splice(i, 1); render(); buildKnot(); };
			row.appendChild(del);
			brBox.appendChild(row);
		});
		var addBr = el('button', 'sc-chip', '+ Break'); addBr.type = 'button';
		addBr.onclick = function () { k.breaks.push({ edge: 'bottom', at: 50, width: 20 }); render(); buildKnot(); };
		brBox.appendChild(addBr);
		box.appendChild(field('Breaks', brBox));
		box.appendChild(checkbox('Art can break the border', k.autoBreak.enabled, function (v) { k.autoBreak.enabled = v; render(); }));
	}
```

Wire up: add `buildKnot();` to the boot line (`buildPage(); buildAwardTags(); buildKnot(); render(); refreshInspector();`).

Slot inspector (`buildSelected`, graphic-slot branch, after the Source field): add

```js
				box.appendChild(checkbox('Border yields to this art', !!s.break_border, function (v) {
					s.break_border = v; render();
				}));
```

Dragging a flagged slot must live-update the gap: in `wireDrag`'s `mv()` add after the `elem.style.top` line:

```js
					if (kind === 'slot' && obj.break_border && tpl.knot && tpl.knot.enabled) { render(); }
```

(A full re-render on drag of flagged slots only — acceptable; `render()` rebuilds drag wiring, so guard: on re-render mid-drag the mousemove keeps working because `mv` closes over `obj`, but `elem` is replaced — live with slight visual lag or debounce via `requestAnimationFrame`; simplest correct: re-render on mouseup instead: in `up()` add `if (kind === 'slot' && obj.break_border && tpl.knot && tpl.knot.enabled) { render(); }`.) **Use the mouseup variant.**

- [ ] **Step 3: CSS (light + dark)**

Append to `scroll.css`:

```css
/* ---- knotwork Border panel ---- */
.sc-check { display:flex; align-items:center; gap:8px; margin:8px 0; font-size:.85rem; cursor:pointer; }
.sc-knot-pats { display:flex; flex-direction:column; gap:6px; }
.sc-knot-pat { border:1px solid var(--sc-panel-line); border-radius:6px; padding:2px; background:#f4f3ef; cursor:pointer; }
.sc-knot-pat.is-sel { outline:2px solid var(--sc-gold, #b8912f); }
.sc-knot-pat svg { display:block; width:100%; height:34px; }
.sc-knot-color { position:relative; display:inline-flex; align-items:center; gap:2px; }
.sc-knot-color input[type=color] { width:34px; height:26px; padding:0; border:1px solid var(--sc-panel-line); border-radius:4px; background:none; cursor:pointer; }
.sc-knot-color__del { border:none; background:none; cursor:pointer; color:inherit; font-size:.9rem; padding:0 2px; }
.sc-knot-feat { border:1px solid var(--sc-panel-line); border-radius:6px; padding:6px 8px; margin:6px 0; }
html[data-theme="dark"] .sc-knot-pat { background:#3a3f4a; }
```

(Verify `--sc-panel-line` exists in scroll.css vars; if the var name differs, use the one the file actually defines.)

- [ ] **Step 4: Verify in browser**

Designer page: Border section appears; clicking preset `Dragon` renders the green/gold border live; sliders/colors update live; medallion "Add emblem slot" drops a selectable slot inside the lozenge; a slot with "Border yields to this art" opens a gap after drag (on mouseup); Save → reload designer with `?templateId` → knot config round-trips (it's in the JSON blob). Confirm a template saved WITHOUT knot still loads clean.

- [ ] **Step 5: Commit**

```bash
git add orkui/template/revised-frontend/Scroll_design.tpl orkui/template/revised-frontend/scroll/scroll-design.js orkui/template/revised-frontend/style/scroll.css
git commit -m "Scroll: designer Border panel — knotwork presets, pattern/color/gradient controls, medallions, breaks"
```

---

### Task 7: End-to-end Chrome verification + fixes

**Files:** whatever the walk-through demands (fix-forward).

- [ ] **Step 1: Verification pass (Chrome, per spec §7)**

1. All four presets in designer, portrait + landscape — border character matches the reference scrolls (weave style, colors, medallions, breaks; screenshot each against `~/.claude/image-cache/.../1-4.jpeg` composition).
2. Medallion emblem slot: add + assign pack art (e.g. Flame order emblem) → renders above the lozenge.
3. Auto-break: flag a bottom-center slot, drag it across the bottom border → gap follows on mouseup with looped terminals.
4. Gradient editor reproduces the Flame fade; toggling off restores flat colors.
5. Filler `Scroll/builder/{mundaneId}/{awardId}`: pick the saved knot template — identical border; **Download PDF** → open PDF: border present, gradients intact, no SVG dropout (html2canvas). If html2canvas mangles the inline SVG, fallback: pre-serialize the SVG to a data-URI `<img>` for capture only (documented fallback — implement only if needed).
6. Dark mode: walk the designer Border panel with the dark-mode checklist (labels, sliders, chips, pattern tiles readable; no light leaks).
7. Regression: the three starter templates (no `knot` key) render identically to master behavior.
8. `node tools/test-scroll-knot.cjs` still ALL PASS.

- [ ] **Step 2: Fix everything found; keep tests green; commit fixes**

```bash
git add <specific files>
git commit -m "Scroll: knotwork verification fixes"
```

---

## Plan Self-Review (performed at write time)

- **Spec coverage:** §1 data model → Tasks 1/6; §2 engine incl. two-pass, terminals, corners, medallions, gradients, auto-breaks → Tasks 1–4; §3 designer UX → Task 6; §4 filler+PDF → Tasks 5/7; §5 presets → Task 6; §7 verification → Task 7. Out-of-scope list respected (no extra patterns/shapes).
- **Known judgment points for implementers:** terminal merge bookkeeping (Task 2 — tests pin behavior, simplify freely if equivalent), cycloid self-cross neighbor window (Task 1 Step 4 note), λ/amp tuning constants are START values — the visual smoke steps exist precisely to tune them.
- **Type consistency:** `_geom` names match across tasks (`norm/frameLayout/toPage/lane/strandW/outlineW/mergeIntervals/segmentEdge/autoBreaks/patterns/findCrossings/blendHex/subPolyline/buildSegmentPolys/collectPolys/cornerPolys/medallionPolys/effCount`); public API `render/swatch/medallionInnerRects`.
