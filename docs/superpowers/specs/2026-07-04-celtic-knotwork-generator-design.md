# Celtic Knotwork Border Generator — Design Spec

**Date:** 2026-07-04
**Branch:** `feature/scroll-generator`
**Status:** Approved (brainstormed with Avery 2026-07-04)

## Goal

A parametric Celtic knotwork border engine for the scroll generator that reproduces the
look of the four reference scrolls (Flame, Dragon, Crown, Smith): interlaced knot borders
with true over/under weaving, per-strand coloring, optional gradient tinting, corner
treatments, mid-edge diamond medallions that hold emblems, and dynamic breaks where the
border yields to overlapping art.

The engine is a **live parametric layer**: parameters are stored in the template JSON and
the border is rendered as inline SVG at view time (designer, filler, PDF). Nothing is
frozen to a bitmap.

## Decisions (from brainstorm)

| Decision | Choice |
|---|---|
| Integration | Live parametric `knot` layer in template JSON, rendered client-side as SVG |
| Breaks | Automatic (slots flagged `break_border`) + manual break regions, both with looped strand terminals |
| Medallions | Engine-drawn diamond lozenges woven into the strands; inner clear rect hosts a normal emblem slot |
| Color | Per-strand palette + outline color + optional linear gradient tint (per-strand blended stops) |
| Patterns | 4 named parametric patterns: `plait`, `openweave`, `twist`, `runningknot` |
| Architecture | Approach C — procedural tile modules: pattern geometry computed in code, assembled from edge segments + corner/terminal/medallion modules with matching strand ports |

## 1. Data model

New optional top-level key `knot` in the template JSON. Note: this is stale as originally
written — slots/zones are discrete `ork_scroll_template` columns (not a single JSON blob), and
persisting `knot` required its own schema change: `db-migrations/2026-07-04-scroll-template-knot.sql`
adds a `knot JSON NULL` column.

```json
"knot": {
  "enabled": true,
  "pattern": "plait",
  "band":    { "inset": 2.0, "width": 6.0 },
  "strands": { "count": 3, "thickness": 0.55, "gap": 0.12, "scale": 1.0 },
  "colors":  { "strands": ["#2e7d32", "#f4c542"], "outline": "#1a1a1a" },
  "gradient": { "enabled": false, "angle": 90,
                "stops": [ { "at": 0, "color": "#c62828" }, { "at": 1, "color": "#f9a825" } ] },
  "corners": "woven",
  "medallions": [ { "edge": "left", "at": 45, "size": 14, "shape": "diamond" } ],
  "breaks":  [ { "edge": "bottom", "at": 50, "width": 30 } ],
  "autoBreak": { "enabled": true, "padding": 2 }
}
```

Field semantics:

- `band.inset` / `band.width` — percent of the page's **short dimension**; centerline framing
  identical on all four edges.
- `strands.count` — strands per weave segment (pattern modules may clamp to a supported
  range, e.g. twist = 2).
- `strands.thickness` — strand width as a fraction of the per-strand lane within the band.
- `strands.gap` — visual cut gap at crossings, as a fraction of strand width.
- `strands.scale` — repeat wavelength multiplier (1.0 = pattern default density).
- `colors.strands` — 1..4 hex colors, assigned by strand index (pattern module owns the
  mapping for weaves where a single physical strand alternates tones).
- `gradient` — when enabled, each strand color's fill becomes a linear gradient whose stops
  are `blend(strandColor, stopColor)` — literal color stops, computed in JS, applied with
  `gradientUnits="userSpaceOnUse"` across the page. `angle` in degrees (90 = top→bottom).
- `corners` — `woven` (interlace turns the corner) or `hook` (curled open motif as on the
  reference scroll tops).
- `medallions[]` — `edge` ∈ top/right/bottom/left, `at` = percent along that edge,
  `size` = percent of page short dimension (diamond diagonal), `shape` = `diamond` (v1 only).
- `breaks[]` — manual gaps: `edge`, `at` (center, percent along edge), `width` (percent of
  edge length).
- `autoBreak` — when enabled, any slot with `break_border: true` whose footprint (padded by
  `padding` % of page) overlaps the band projects a gap onto the overlapped edge(s).

Slot addition: optional boolean `break_border` on any slot ("Border yields to this art").

Templates without a `knot` key (all existing templates) are untouched — the layer is
strictly additive and defaults off.

## 2. Engine — `scroll-knot.js`

New standalone file `orkui/template/revised-frontend/scroll/scroll-knot.js`, no
dependencies, IIFE exposing:

```js
window.ScrollKnot = {
  render(knotCfg, pageW, pageH, slots) -> SVGSVGElement,  // absolutely positioned page overlay
  medallionInnerRects(knotCfg, pageW, pageH) -> [{edge, at, x, y, w, h}]  // % coords for designer
}
```

`scroll-render.js` inserts the SVG between the background and the slots when
`tpl.knot && tpl.knot.enabled`. The SVG uses `viewBox="0 0 pageW pageH"` in layout px,
`width/height 100%`, `position:absolute; inset:0; pointer-events:none`.

**PDF-safe constraint:** paths + strokes + `userSpaceOnUse` linear gradients ONLY. No
masks, no filters, no clipPath, no foreignObject, no `<use>` — the subset html2canvas
rasterizes faithfully.

### Render pipeline

1. **Frame layout** — compute the band ring (centerline rectangle + band width in px) from
   `band.inset`/`band.width`; four edge runs between corner modules.
2. **Segmentation** — per edge, subtract corner footprints, medallion footprints, manual
   breaks, and auto-break projections → ordered list of weave segments. Each segment
   stretches its repeat wavelength to fit a whole number of repeats (seamlessness
   invariant). Segments shorter than one minimum repeat render as a plain connector strand
   pair rather than a degenerate weave.
3. **Pattern generators** — one module per pattern. Contract: given
   `(segmentLengthPx, bandWidthPx, strandParams)` emit, per strand:
   - an ordered list of cubic bezier spans (the strand path through the segment),
   - crossing metadata: `{t, otherStrand, over}` sorted along the path, alternation
     guaranteed by construction,
   - port positions (y-offsets within the band) at both segment ends, identical across all
     four patterns' *port scheme* so corners/terminals/medallions interoperate.
4. **Two-pass interlace rendering** —
   - Pass 1: per segment, ALL strands' outline strokes first (outline color, width
     `w_out = w_fill + 2·outlinePx`), then ALL strands' fill strokes (strand color, width
     `w_fill`). At this point crossings show merged fills — no interlace yet.
   - Pass 2: for every crossing, extract the *over* strand's sub-arc around the crossing
     (t-window sized from strand width + `strands.gap`) and re-stroke it twice: outline
     color at `w_out + 2·gapPx`, then the strand's fill at `w_fill`. The widened dark
     casing cuts the under-strand's fill on both sides of the over strand — the inked
     over/under look of the reference scrolls (dark outline separations, no parchment
     gap), with `gap` controlling how heavy the cut reads.
5. **Terminals** — a segment end not meeting a corner/medallion port gets a looped-back
   terminal: strands pair up and U-turn into each other (odd strand counts loop the middle
   strand onto itself with a small spiral curl). Generated per pattern via the shared port
   scheme.
6. **Corners** — parametric modules with ports on both arms:
   - `woven`: strands turn 90° with at least one interlaced crossing inside the corner box.
   - `hook`: the curled open motif from the reference tops — outer strand sweeps into a
     spiral curl, inner strands U-turn; visually an intentional gap at the corner.
7. **Medallions** — diamond lozenge: edge strands enter via ports, one strand pair traces
   the diamond outline with crossings at the four diamond vertices, remaining strands pass
   behind/loop back. Inner clear rect (diamond inscribed rect × ~0.6) reported by
   `medallionInnerRects()`.
8. **Color & gradient** — strand index → `colors.strands[i % n]`. With gradient enabled,
   each distinct strand color gets one `<linearGradient>` def (stops pre-blended in JS);
   strand fill strokes reference their gradient. Outline color is never gradient-tinted.

### Auto-break geometry

For each slot with `break_border`, compute its padded rect; for each edge whose band rect
intersects it, project the intersection onto the edge axis → an interval merged into that
edge's break list (union of overlapping intervals). Breaks clamp so at least one repeat of
weave survives between any two features; if a break would consume an entire edge, the edge
renders as two terminals only.

## 3. Designer UX

`Scroll_design.tpl` + `scroll-design.js` gain a **Border** panel:

- Enable toggle; pattern picker as 4 live-rendered SVG thumbnails (the engine rendering a
  small horizontal swatch — no static images).
- Sliders: band inset, band width, strand count, thickness, gap, scale.
- Color: strand color chips (add/remove up to 4), outline color. `<input type=color>`
  values guarded with `!empty()`-style fallbacks per house rule.
- Gradient: enable toggle, angle, 2–3 stops (position + color).
- Corner style select (woven/hook).
- Medallion list: add/edit/remove (edge, position slider, size); each row has
  "Add emblem slot here" which creates a normal slot centered on
  `medallionInnerRects()` output.
- Manual break list: add/edit/remove (edge, position, width).
- Auto-break toggle + padding.
- Slot inspector: new "Border yields to this art" checkbox (`break_border`).
- Presets row: Flame / Dragon / Crown / Smith one-click configs (§5).

Every control change re-renders the page immediately (`ScrollKnot.render` is fast enough
to run on `input` events; debounce at ~30 ms if needed).

House rules honored: dark-mode compatible panel (walk the checklist), `data-tip` tooltips
only, no native dialogs (`tnConfirm` for medallion/break deletion if confirmation is
warranted), FA5 icons only, headings reset against orkui.css pill styles.

## 4. Filler + PDF integration

`scroll-render.js#renderPage` renders the knot layer for every surface (designer preview,
filler/builder, PDF capture) — one code path. Auto-breaks recompute from the slots present
at render time, so filler-side emblem swaps keep correct gaps. html2canvas rasterizes the
inline SVG during PDF export; the PDF-safe constraint set (§2) is the compatibility
contract.

## 5. Presets

Four presets stored as plain JS objects in `scroll-design.js`, reproducing the reference
scrolls:

| Preset | Pattern | Colors | Extras |
|---|---|---|---|
| Flame  | plait (3-strand, tight) | reds/oranges + near-black outline | vertical gradient red→gold; diamond medallions mid-left/right; hook corners top; bottom-center break |
| Dragon | openweave (2-color) | green + gold, dark outline | diamond medallions mid-left/right; bottom-center break |
| Crown  | openweave | black + gold | medallions at upper-third left/right; bottom-center break |
| Smith  | twist (2-strand rope) | brown + slate | diamond medallions mid-left/right; bottom-center break |

Presets only set the `knot` config (plus flagging nothing) — they do not touch slots/zones.

## 6. Out of scope (v1)

- Additional patterns (key pattern, spirals, triquetra chains) — architecture admits them
  as new pattern modules later.
- Non-diamond medallion shapes; medallions on corners.
- Zoomorphic terminals (dragon-head strand ends).
- Server-side rendering of the knot layer; artwork-library PNG export.
- Applying knotwork to arbitrary shapes (circles, banners) — rectangular page frame only.

## 7. Verification

Post-implementation Chrome walk-through (per Chrome-scope rule):

1. All four presets render in designer, portrait + landscape, visually matching the
   reference scrolls' border character (weave style, colors, medallions, breaks).
2. Medallion "Add emblem slot here" places a slot inside the clear rect; emblem renders
   above the lozenge.
3. Dragging a `break_border` slot across the bottom border opens/closes/moves the gap live
   with looped terminals.
4. Gradient editor reproduces the Flame fade; disabling returns flat strand colors.
5. Filler (`Scroll/builder`) renders the identical border; PDF export matches the screen
   (no missing SVG, no gradient dropout).
6. Designer Border panel is clean in dark mode (checklist walk).
7. Existing templates without `knot` render byte-identically (no regression).
