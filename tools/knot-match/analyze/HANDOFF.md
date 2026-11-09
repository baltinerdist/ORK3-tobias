# Handoff: knotwork analysis engine (2026-11-08)

## What the owner asked for

> "Create an analysis engine that can review a piece of knotwork given to it and generate the necessary algorithm and procedure generator seeds and other component parts necessary to run generation and design."

> "I want procedural generation cycles with scoring and the .85 target."

After the playback below the owner said "Go". There are no further questions to ask.

**Playback the owner approved.** You hand the engine a reference knotwork image. It reads the drawing, works out what it is made of, and writes the generator's starting settings (the seeds). Then it runs cycles on its own: generate, score against the reference, adjust, and repeat, until the score reaches **0.85**. The 0.85 is measured the same way as for Ash's knot: metric v2, against the reference's own self-consistency ceiling. "Done" means a generated border at 0.85 or above that also passes the visual and correctness checks.

**Test references** (in `analyze/refs/`, all supplied by the owner). These borders are built from **interlocking closed pieces**, not one continuous braid.

| File | Size | What it shows |
|---|---|---|
| `interlock-corner-side.png` | 280×782 | One corner (TL), the left side, and the start of the top |
| `interlock-two-corners.png` | 586×1404 | TL and BL corners, the full left side, and the starts of the top and bottom. **The main test image.** |
| `interlock-corner-side-colour.png` | 630×1606 | The first image filled red and green: **each closed piece is one colour, and pieces alternate along the side.** Use it as ground truth for loop identity. It is a screenshot: there is a dark window-chrome bar on the left and top edges, which must be cropped or ignored. |

**Caution: the strands in the grey images are TRANSPARENT.** The checkerboard is baked into the pixels and shows through the strands as well as the holes. Colour cannot tell strand from background, so the classifier works on shape (below).

## Context documents

- `docs/2026-11-08-engine-deep-dive.md`: `scroll-knot.js`, the Ash-match engine on branch `knot-v6-engine`.
- `docs/2026-11-08-toolchain-deep-dive.md`: `knotmatch.cjs`. It covers metric v2, the optimisers, the gates, and a proposed pipeline for any reference.
- `docs/2026-11-08-history.md`: the project history, the owner's aesthetic principles (§4) and the rejected approaches (§2).
- The synthesis page: https://claude.ai/artifact/TiPKqtrTwN8fLRCp16qe2Z (private to the owner).

## The key design decision: read the knot as a crossing lattice plus a barrier map

I made this call after a fragment-skeleton tracer failed. That tracer is `trace.cjs`. Kept for reference, it linked only 20 of about 90 under-crossings, because the short bars between crossings are about as long as they are wide, so their skeleton direction is unreliable.

Celtic knotwork is classically drawn on a **diagonal grid**:
- Crossing sites sit on a square lattice of spacing `s`, at the sites (i, j) where i + j is even.
- Strands run diagonally from site to site.
- At a **crossing** site, strands pass straight through, one over the other.
- At a **barrier** site, they bounce off a wall and form the arcs. A barrier is `H` (the wall runs horizontally) or `V` (vertically).
- The band's outline is a ring of barriers.
- Interlocking closed pieces are just a plait with periodic barriers that split it into separate loops.

So the **seed** for a border is:
- **grid:** `s` (px), origin, angle (0 here);
- **stroke:** strand width, ink width, as ratios to `s`;
- **curve:** how the arc at a barrier is shaped, i.e. roundness or tension;
- **site maps:**
  - a periodic **side tile**: a few sites across × `p` sites along, plus its phase from the corner;
  - a **corner tile**: a site map in the corner's frame;
  - the **symmetry** that places the other corners. Infer it by comparing TL with BL in the two-corner image.
- **over/under:** alternate along each strand. Verify it against the detected over directions.
- **colouring:** optional per-loop colours, 2-coloured along the interlock graph (as the red/green reference shows).

This representation gives variation for free:
- tightness = `s` relative to strand width;
- band thickness = sites across;
- pattern = the barrier map.

That matches the variation goals in the synthesis.

## Current state (uncommitted work from the previous session is now in this commit)

| File | State |
|---|---|
| `analyze/image.cjs` | **Working.** Loads the PNG, finds the ink threshold (Otsu, capped at 170), labels non-ink regions, and classifies each region as **strand fill** or **ground** by shape. A strand fragment is a band of near-constant width: the distance-to-ink ridge stays at about the strand half-width all along it. Holes and the outside fail that test. Colour is used only when it actually separates fill from ground. Results: both grey images classify correctly by eye. Strand width is 14–14.5 px, ink 4 px. |
| `analyze/trace.cjs` | Fragment centreline tracer and linker. **Superseded** by the lattice approach (see above). Its fragment and centreline code may still help for curve fitting. |
| `analyze/lattice.cjs` | **Working.** Crossing detector, which probes both diagonals at every fill pixel. Lattice fit and site classifier. On the two-corner image: 118 crossings found, each with its over direction; `s` = 25.385 px; mean distance of a crossing from its grid point 0.62 px; sites: 62 `X/`, 56 `X\`, 45 `H`, 53 `V`, the rest outside. On the small image, `s` = 25.38 (consistent). The overlay shows crossings, over directions and edge barriers correct in the TL corner. **Not yet verified site by site**, especially the H/V barrier orientation at interior barrier sites. |

Run commands (always `node --no-maglev`, because of a Node 26 V8 JIT bug):

```
node --no-maglev tools/knot-match/analyze/image.cjs   tools/knot-match/analyze/refs/interlock-two-corners.png out.png
node --no-maglev tools/knot-match/analyze/lattice.cjs tools/knot-match/analyze/refs/interlock-two-corners.png lat.png
```

## Next steps, in order

1. **Verify and fix the site map.**
   - Render the site map as an ASCII grid per region (side, TL, BL) and check it against the colour image.
   - Every interior non-crossing site must be a barrier with the right orientation. Every site on the band edge must be a barrier.
   - Detect the band: the sites with strand.
   - Detect the frame: the side strip, the corners, and the top and bottom strips.
2. **Extract the seed**, in a new `analyze/seed.cjs`.
   - Find the period of the side's barrier pattern along the edge. It should be a few sites, for one closed piece.
   - Cut the side tile and the corner tile(s). Test the corner symmetry (TL vs BL: mirror or rotation).
   - Measure stroke ratios.
   - Write `seed.json`.
3. **Generator**, in `analyze/gen.cjs` or a new `knotgrid` module: seed plus frame size in, SVG out.
   - **Layout:** lay the site grid around the frame, tile the side pattern, place the corners.
   - **Strands:** trace them through the site graph (straight through at X sites, reflected at barriers). This gives closed loops.
   - **Curves:** straight diagonals through crossings; round arcs at barriers, matching the reference's semicircles.
   - **Over/under:** global alternation (2-colouring parity, as in `alternateGlobally` in `scroll-knot.js`).
   - **Painting:** cut the under strand at the over strand's outline, with no gap in this style. Draw an ink stroke of width w + 2·ink, then a fill stroke of width w, using butt caps at the cuts.
   - **Output:** PDF-safe SVG only: paths, groups, solid fills.
4. **Scorer.**
   - Rasterise our SVG at the reference's pixel size (`KM.rasterize` uses rsvg-convert).
   - Classify into ground/ink/fill. Use class 2 for fill, so `KM.regionScore` works unchanged: it is exported from `knotmatch.cjs`, and the reference DT object is `{cm, dts: {}}`.
   - Score regions: the TL corner, the BL corner, a left-side box, and the top and bottom strips.
   - **Ceiling:** the side box against itself shifted by one piece period, and TL against mirrored BL.
   - Report nominal and phase-mean scores. Never select on the nominal score alone; the toolchain deep-dive §2.3 explains the winner's curse.
5. **Cycle runner.**
   - Seed from the analysis, render, score, then search the continuous parameters (`s`, origin, strand and ink ratios, arc shape) with small-step CMA-ES or coordinate descent, σ ≤ 0.03.
   - Then a discrete local search on site types: flip a site, keep the change only if the score rises **and** the topology stays valid.
   - Log every cycle. Stop at **≥ 0.85 on every region with all gates passing**, or report a stall.
   - Do a visual review of zoomed ours | reference | overlay sheets after each new best; the pixel metric misses things.
6. **Gates.**
   - Every strand is closed.
   - Over/under alternates.
   - Ink stays inside the band.
   - The loop count per side piece matches the reference.
   - No fallback.
   - Fairness: no curvature wiggle beyond the reference.


## Update (2026-11-08, second session): target met

Steps 1–6 are done. The best border on `interlock-two-corners.png` scores **min phase-mean 0.936, min nominal 0.938** (TL 0.936/0.938, BL 0.938/0.939, left 0.940/0.942, top 0.941/0.949, bottom 0.940/0.938; mean/nominal). All gates pass. Review page: https://claude.ai/artifact/UvzhD76ju5dtEo7Uwgm5gX (private).

| File | What it does |
|---|---|
| `lattice.cjs` | Sites are typed by which diagonal segments carry strand (midpoint-in-fill test). One-sided barriers are named by the side their strands are on: N, S, E, W. Tight U-turns, whose curve bends inside the shared segment's midpoint, are paired and restored. |
| `seed.cjs` | Writes `seed-two-corners.json`. Side period 6, side and top tiles (the top is the side transposed), a 7×7 TL corner tile (transpose-symmetric), BL = TL mirrored in y (362/362 sites), over rule (118/118 crossings), stroke ratios. `layout()` expands a seed to any frame where AW ≡ AH ≡ 4 (mod 6). |
| `gen.cjs` | Seed + frame → SVG. Traces closed loops, draws straight crossings and cubic barrier arcs (u, k), uses one cubic per tight turn (tightU, tightK), applies parity over/under, and paints butt-capped patches (the fill patch is 1 px longer, so there is no seam). |
| `score.cjs` | Metric v2 via `KM.regionScore` on TL/BL/left/top/bottom, nominal and 4-phase mean, plus the self-ceiling. The mirror ceiling (0.87–0.92) is *not* a hard ceiling: mirroring flips over/under at every crossing. |
| `gates.cjs` | Checks closed loops, valid sites, alternation, ink in band, loops per side period vs the reference's own traced map (3 loops of 24 sites each), no fallback, and cubic fairness. |
| `cycle.cjs` | Coordinate-descent cycles on the phase mean, with the stop rule. `POLISH=1` keeps going past the target. |
| `sheet.cjs` | Zoomed ours / reference / overlay sheets. |

**Runs** (`results/interlock/`): `run1` goes from the seed (0.766) to 0.9105 in one cycle. The visual review then showed square tight turns. Coordinate descent could not escape that (tightU and tightK are coupled). A 2-D grid found tightU 0.65 / tightK 0.75, and `run2` from there stalled at 0.936 (two cycles under +0.01). Ink-mismatch pixels fell from 15831 to 11197 between the two.

**Loop identity vs the colour image:** 3 colour switches per period at two columns, both in the reference and in ours. The colour screenshot is at 2.0× scale, not 2.25×.

**Not done / open:**
- A discrete site-flip search was not needed: the seed *is* the reference's site map.
- `interlock-corner-side.png` reads the same side tile and s (25.380). With one corner it cannot give the frame height.
- Ordinary barrier arcs are still slightly flatter than the reference's circles: k sits at 0.24 with u at 0.59, near its bound of 0.65. A circular-arc model may fit better than the cubic.

## Update (2026-11-09): single-strand frame with darkened corners, target met

Reference: `refs/single-strand-dark-corners.png` (360×445). It has straight single-strand sides and free-form corner knots with black holes. The strands are transparent, with a 2 px white halo.

**Result:** best `results/single-strand/run2`. Min phase-mean 0.879, min nominal 0.872 over TL/TR/BL/BR/left/right/top/bottom. All gates pass.

| File | What it does |
|---|---|
| `freeform.cjs` | Centreline walker. Uses 1 px-eroded labels so anti-aliased bridges between strands don't connect them. Bends are chosen by ridge depth. It fans out to jump across over strands, and tells rim from ink so small breaks aren't read as crossings. Traces TL: 10 crossings, UOUO… alternation. |
| `ffseed.cjs` | Writes the seed: side lines (pixel centre +0.5), curved stroke 6 / 1.75, straight-run stroke 7 / 1.75, 160 Catmull-Rom points, crossing order. Symmetry is picked by pixel agreement: **rotation** 0.859 vs mirror 0.775. A mirror flips over/under at every crossing. |
| `ffgen.cjs` | One closed path with C4-rotated corners. Enclosed holes are flood-filled on a 0.5 px grid and traced as black polygons. Draws halo, ink, fill, straight-run overlay and over-strand patches. |
| `ffcycle.cjs` | Scoring regions, rotation self-ceiling, coordinate descent. Scores **without the halo**. Frame lines are locked; only per-side ±0.6 px offsets move. Corner points move 0.25 px along their normals. Ink must stay in the band on every move. |

**Lessons from the run1 stall at 0.821** (diagnosed by an outside review):
- A white halo that is ground in both images still costs points. Its anti-aliased edge is read as fill.
- Straight and curved runs threshold to different widths.
- The alignment search lets frame lines drift, so lock them.

Sides' self-ceilings are 0.83–0.86, because the reference's opposite sides really differ by a pixel.

## Gotchas

- Run node with `--no-maglev` (see `reference_node26_v8_maglev_miscompile` in the owner's notes).
- Launch any generated shell script with its own shebang shell; zsh arrays break under bash.
- **Pixel-diff before making visual claims.** Run `magick compare -metric AE -fuzz 10% a.png b.png null:`. Last session, an "obvious" visual improvement turned out to be 44 pixels.
- The Ash-match tool (`knotmatch.cjs`) hard-codes Ash's SVG dialect and palette. Reuse its **scoring functions**, not its reference loader.
- `pngjs` is **not** declared in `package.json`; locally it resolves from the main checkout's `node_modules`. In a fresh clone run `npm install --no-save pngjs` at the repo root before running anything here. The scorer also needs `rsvg-convert` (librsvg) and the sheets use ImageMagick (`magick`).

## Also in this commit (from the earlier polish task)

- `fit/fit.cjs`: an optional `SMOOTH=λ` penalty on knot second differences, and an `INIT=<fit.json>` warm start.
- `results/2026-11-08-smooth-best.json`: the Ash-match design with smoothed corner and end tiles. Scores: joint 0.8617, TL 0.8675, top-L 0.8688. Corner kinks 2 → 0, wrap dents 11 → 4, tile wiggle energy −54%. It needs the engine on branch `knot-v6-engine` (pushed alongside this one).
