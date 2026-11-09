# Knotwork engine deep-dive: pipeline, parameters, and what it takes to vary it

Scope: `scroll-knot.js` on branch `knot-v6-engine` at 1ef5b0ddd ("V12 painter"), worktree `.worktrees/knot-v6-ends`. Line numbers below are for that file unless another file is named. `K:` refers to `/Users/averykrouse/GitHub/ORK-tobias/ORK3-tobias/.worktrees/knot-hand-drawn/tools/knot-match/knotmatch.cjs`. `D:` refers to `scroll-design.js` and `R:` to `scroll-render.js`, both in the same worktree. "Joint-best" means `tools/knot-match/results/2026-11-08-joint-best.json` on `feature/knot-hand-drawn`.

Every experiment ran under `node --no-maglev`, with scripts in `/private/tmp/claude-501/-Users-averykrouse-GitHub-ORK-tobias-ORK3-tobias/d582c881-63eb-4331-acce-d387afe6d0c7/scratchpad/synth/engine/`. The joint-best was loaded the same way the tool loads it. Its `consts` are patched into the engine source (K:228-236), and its `cornerTile` and `endTile` replace the committed tile data (K:2303-2307). I used fresh engine contexts for every measurement because of finding F3 below. Tagging convention: **[fact]** means measured or read from code, and **[opinion]** means my judgement.

---

## 0. Top findings

- **F1 [fact]. The fill painter's spoke/quad ribbon is cairo's stroke polygon.** In my renders it does not cause the 6× wobble on its own. With unit widths, the fill render matches the stroke render to within 395 of 13.8 M pixels on the whole page at 4×. In 6× crops it matches to within 23–27 of 129,600 pixels in rsvg, WebKit (QuickLook) and headless Chrome. The wobble I can see at 6× is in the **centrelines of the per-point fitted tiles**, and it shows up in both painters. Those tiles have about 7× the curvature noise of the braid and about 80× the curvature sign-flip rate. §1 covers this.
- **F2 [fact]. The fitted design sits on a knife edge.** A band-width change of +0.004 (0.03 px of band) moves the end tiles by up to 0.57 band. One run then crosses the centre line, so `symmetry:'mirror'` switches itself off, and the joint score drops from 0.8603 to 0.7117 (right side 0.48). A change of +0.052 drops it to 0.611 (top-L 0.219). §4.2 covers this.
- **F3 [fact]. Output depends on render history.** The same cfg rendered fresh, and rendered after a band-4% render in the same engine instance, gives different SVGs (worst run stretch 0.970 vs 1.509). The cause is the `tile._ph` cache. Its key leaves out the band size in px (2417-2419). The designer re-renders one engine instance on every slider move, so it is exposed to this.
- **F4 [fact]. Output is not scale-invariant.** The same cfg on the same page shape at 0.5–3× absolute size gives 150–171 crossings on the drawn half, different corner colour lattices (`0300` vs `0301`), and corner-window phase shifts that differ by up to about 1.7 band. §4.2 covers this.
- **F5 [fact]. The designed tiles only work in a narrow window around the fit.**
  - End tiles attach only for `repeatLam` 2.0–2.45 (tile lam 2.2724 ± 12%), `thickness` ≤ 0.5, `bow` within 0.2 of the tile's value, and `angular` 0.5–0.85.
  - Corner and end tiles exist for plait-4 only. Any other strand count or pattern silently falls back to `round` corners and `fold` ends.
  - `strands.scale` (the designer's "Density" slider) does nothing at all when every run ends in designed tiles.
- **F6 [fact]. The joint-best needs things a cfg cannot express.** It depends on two constants that are not cfg keys (`OUTLINE_RATIO` 0.5172, `GAP_RATIO` 0.533) and on refitted tiles that differ from the committed ones. With engine-default constants it scores 0.8517 instead of 0.8603.

---

## 1. Fill painter: the quad/spoke ribbon and smoothness (priority item)

### 1.1 Where the ribbon is built (Q1)

- `offsetOutline(P, h, capA, capB, jn, closed)` at **3295-3334** builds every fill polygon.
  - The per-segment offset points come from the main loop **3323-3326**: for segment k, `P[v] ± off(k, h[v])`, where `off` uses that segment's own normal (3301).
  - The **spoke** is in `joinAt` **3309-3322**. On the inner side of each turn it pushes the centreline vertex itself, then the next segment's offset: `inner.push([V[0], V[1]]); inner.push([V − sg·oi])` (**3314**).
  - The outer side gets a round fan when the turn exceeds about 23° at h ≈ 4.85 px (the `cusp` test, 3317-3319), otherwise a miter point (3320), then `pb` (3321).
  - Closed runs are a keyhole with a bridge, `L.concat([L[0], R[0]], R.reverse())` (**3328**), which is another out-and-back seam. Round caps are fans (3330-3332).
- The comment at **3274-3275** states the intent: "Joins as cairo strokes them: the inner side through the vertex…".
- Callers:
  - `paintFilled` 3444-3475: the body ink polygon at 3467 and the body colour polygon at 3470.
  - `fillFace` 3351-3390: the cut-face stretch polygons at 3387-3388, clipped by Sutherland–Hodgman `clipHalf` 3193-3202.
- Emission is `fillPath` 3017-3021 (default nonzero fill) through `polyPath` 3000-3003. `polyPath` rounds every coordinate to 0.01 px.

In the coordinator's excerpt (`…L49.80 1029.02 L50.22 1034.08 L49.85 1029.01…`), the spoke goes to the **centreline vertex**, which is half the ink width away, not to the far edge. The 5.06 px jump matches h_ink ≈ 4.85 px plus the local tilt. The excerpt is at x ≈ 49, y ≈ 1029–1034, which is inside the bottom-left **corner tile** box (x 15.9–65.5). The vertices there are about 1 px apart, which is the spacing of the per-point fitted tile.

**Measured structure [fact].**

| | fill SVG | stroke SVG |
|---|---|---|
| Size | 2,050,101 B | 619,010 B |
| Paths | 1,908 | 1,908 (1,272 of them are V9 face fills, because `cutSlant` > 0) |
| Vertices | 146,020 | 37,206 |
| Out-and-back spokes (legs > 1.5 px, reversal > 162°) | 21,244 | 0 |

- The 1,908 paths are 318 runs × (body ink, body colour, and up to two ink+colour face pairs).
- 33% of the cut-run segments (2,549 of 7,628 on the drawn half) are shorter than 0.25 px, and each of those vertices produces a spoke. Sources: `curlCutEnd` crowds ≥ 16 samples toward each cut (1817-1825; active here because `cutCurl` is 0.014), `peakGrid` adds ±0.03·step pairs at every peak (1394-1406), `JUNCTION_DENSIFY` (2204-2210), and tile resampling.

### 1.2 Is the quad union what you see? Mostly no [fact]

**Algebra.** The path is L forward, then the cap, then R backward. As a chain this equals Σ(per-segment quads) plus the outer join wedges. Consecutive quads have the same orientation, so their overlap on the inner side has winding 2. Under nonzero fill the region is exactly the union, which is cairo's stroke region with miter or round outer joins.

**Measurements.**

- *Whole page.* I rendered the joint-best with unit widths (`fillArcW = fillBarW = fillInk = fillBarInk = 1`, `bulge = out = 0`, no `fillField`) and compared it with the stroke painter in rsvg at 4×. They differ in **395 of 13.8 M px**.
- *6× crops.* Side run (x 10–70, y 380–440) and BL corner (y 990–1050), unit-width fill vs stroke:
  - rsvg: 27 / 10 px of 129,600
  - WebKit (QuickLook): 26 / 11 px
  - headless Chrome (temp profile): 23 / 13 px
- *Straightness of a side bar at 30×* (sub-pixel edge finder, residual from a fitted line):

  | Edge | fill | stroke |
  |---|---|---|
  | Ink/background, rsvg | 0.009–0.011 px RMS (max 0.036) | 0.008–0.011 px RMS (max 0.037) |
  | Colour/ink, rsvg | 0.003–0.004 px RMS | 0.005 px RMS |
  | Colour/ink, WebKit | 0.004–0.005 px RMS | 0.006 px RMS |

  The fill edges are as straight as the stroke edges.
- *Scores (metric v2).* Stroke 0.8424; fill with unit widths 0.8429; fill without `fillField` 0.8599; fill as saved 0.8603.
  - So the quad construction adds +0.0005.
  - The arc/bar/ink width model adds +0.017.
  - `fillField` adds +0.0004.

I could not reproduce "side bars wobble with fill, clean with stroke" at 6× in any of the three renderers.

### 1.3 What does make visible non-smoothness

**(a) Fitted tile centrelines (both painters) [fact].** I computed the curvature κ = signed turn / mean adjacent segment length. "Noise" is the RMS of κ minus its ±0.15-band moving average. "Flips" counts curvature sign changes (|κ| > 0.002) per band of length. Script `rough.cjs`.

| zone (joint-best) | κ-noise (1/px) | flips / band | mean step |
|---|---|---|---|
| braid | 0.0108 | 0.07 | 2.82 px |
| end tile (fitted `ash-hairpin`) | 0.0709 | 5.9 | 0.99 px |
| corner tile (fitted `ash-contained`) | 0.0753 | 5.77 | 0.85 px |
| for contrast: committed Bézier `ash` corner | 0.0265 | 0.82 | 2.13 px |

The BL-corner crops at 6× (`ql-corner6.png`, `chr-corner6.png`) show the same wavy nested L and outer L in fill, unit-fill **and stroke**. The 22 vertices with turns > 20° on the drawn half are all inside tiles (outer-L corner 65°, nested-L features 20–54°, end wrap/hairpin 21–68°). None are at ports.

**(b) Braid faceting (both painters) [fact].** The braid is a polyline sampled at `STEP(band) = clamp(band/16, 1.25, 4)` px, which is 3.1 px here (213). It reads as faceted at 16× or more.

**(c) Fill-only sub-pixel defects [fact].**
- Hairline anti-aliasing seams along spokes where vertices crowd near cut faces. In rsvg they are visible at 30–150× (`face150.png`: fill and unit-fill have them, stroke does not).
- Jogs of about 0.02 px along the face stretch.

My inference is that the seams come from coverage conflation along near-coincident out-and-back spoke edges, possibly helped by the 0.01 px rounding of sliver-thin triangles. Neither defect is resolvable at 6×.

**(d) Hypothesis [opinion] for the coordinator's "wobble".** The fill width model changes the ink weight in steps from run to run: arcs use `fillInk` 1.092 and bars use `fillBarInk` 0.954, a 14% step. Fill widths step 0.95 vs 1.04. Along one strand the runs alternate arc, bar, arc at every crossing, which can read as a lumpy outline. If the coordinator's viewer was not one of the three I tested, its anti-aliasing of non-simple nonzero polygons may also differ.

### 1.4 Per-sample width noise? (Q2) No [fact]

- `fillWidths` (3423-3443) is smooth along a run:
  - `a` (arc/bar blend) is constant per run (3425).
  - The bulge is `sin²` (3432-3433).
  - End easing is `smooth()` over one wf at free and seam ends (3434-3435).
  - `fillArcOut` is constant × easing (3429, 3439).
  - `fillField` is a cosine series times a raised-cosine envelope (3398-3421).
- Measured over the joint-best's 318 runs (`wprof.cjs`): within-run half-width range ≤ 0.097 px, slope change ≤ 0.0037 px/px. The `fillField` coefficients are all |a| ≤ 0.0086.
- Two latent issues:
  - (i) The end-frame window in `fieldOf` has hard edges at V = −0.25 and 1.25 (3411). A curve crossing them jumps by Σa, up to 0.6×9 in principle and under 3% here.
  - (ii) `runTurning` (3277-3286) sums |turn| over vertices. On noisy per-point tiles the noise inflates the total, so a nearly straight tile bar can be classed as an arc. That is a per-run width error, not a per-sample one.

### 1.5 A true closed outline with the same width model (Q3) [opinion, grounded in the code above]

**Goal.** One simple (non-self-intersecting) closed path per run per layer: left edge forward, end treatment, right edge backward. Keep the existing width model, slanted cut faces and miter option. Changes are local to `paintFilled`, `fillFace` and `offsetOutline`; `cutRuns`, `mirrorHalves` and `fillWidths` stay as they are.

1. **Arc-length parameterise the run.** Compute `cum` once, as now (3449-3450). Resample at a uniform Δs of about 0.5–1 px, plus every **intended corner**: a vertex whose turn after denoising exceeds θc ≈ 25°, or every vertex when `join: 'miter'` is set and the turn exceeds about 10°. This removes the 0.1 px segments, so there is nothing to spoke.
2. **Corner-preserving denoise.** Smooth positions (or heading) with an arc-length Gaussian σ ≈ 0.02 band, split at the intended corners and with the run's endpoints pinned. Measured on the joint-best centrelines (`smooth.cjs`):

   | σ | κ-noise | flips/band | mean shift | max shift |
   |---|---|---|---|---|
   | none | 0.062 | 1.42 | — | — |
   | 1 px | 0.020 | 0.84 | 0.015 px | 0.40 px |
   | 1.5 px | 0.014 | 0.64 | 0.032 px | 0.63 px |

   The max shift happens at the sharp corners, which splitting at corners would protect. *Better long term:* store tiles as smooth curves (§7), so the painter does not have to fix noise.
3. **Frame and widths as functions of s.** Take the tangent T(s) and normal N(s) from the smoothed curve with a centred difference, and the half-widths hF_L/R(s) and hO_L/R(s) from `fillWidths` evaluated at the resampled s. The current code already allows asymmetric L/R (3297-3299).
4. **Offset curves.** L(s) = C(s) + h_L(s)·N(s) and R(s) = C(s) − h_R(s)·N(s).
   - On the concave side, where the local radius of curvature is less than h, the offset folds into a swallowtail. Remove it by finding the local self-intersection of the offset polyline (O(window) search, window ≤ 2h of arc) and cutting the loop. This replaces the vertex spoke; it does not route through V.
   - At intended corners: outer side gets the miter point when within `miterLimit` (as `joinAt` 3316/3318 does), else a bevel or a round arc of radius h. Inner side gets the intersection of the two adjacent inner offset curves.
5. **Ends**, using the same face math as `fillFace` (3357-3376):
   - Cut face: extend C past the cut along the end tangent (as 3386 does), intersect L and R with the face line through F (ink) or FF = F − ink·f (colour), and close along the face. That gives one polygon per layer, with no separate body, no 0.5 px overlap, and none of the `tries` loop at 3372-3384.
   - Seam: ink gets a round arc (two quarter-circle cubics); colour is cut square half an ink width short, matching 3465-3466.
   - Free end: semicircle.
6. **Closed rings.** Emit two subpaths (outer, then inner reversed) in one `d` with nonzero fill, instead of the keyhole bridge at 3328.
7. **Emit.** Either an adaptive polyline (chord error ≤ 0.02 px) or least-squares cubic Béziers per edge (Schneider-style fitting with tolerance 0.02 px, split at corners). Keep the PDF-safe `<path d fill>` contract (comment at 3-4; tests at the V10 block).
8. **Invariants to test:**
   - Each polygon is simple.
   - colour polygon ⊂ ink polygon.
   - Raster area within ε of today's union at unit widths (today's union is the reference, because it equals the stroke).
   - The outline is G1 except at intended corners.
   - Ink and colour edges are parallel to within the width model.
   - Faces keep the slant tests already in the V9/V10 blocks of `test-scroll-knot.cjs`.

Expected effect [opinion]: it removes all 21 k spokes and the conflation seams. It cuts output to roughly 4 vertices per centreline vertex (about 62 k instead of 146 k, fewer with Béziers or resampling). The smoothing step also attacks the real wobble, which is in the tile centrelines.

---

## 2. Pipeline, stage by stage

### 2.1 Config normalisation: `norm(cfg)` 38-127
- **Input:** a raw cfg. **Output:** a normalised object with NaN guards (`num`, 41) and clamps (the parameter table in §3).
- Whitelists: patterns (43), ends (44), corners. `CORNER_MODES` minus the internal `tile` key, plus `CORNER_TILES` names (81). `'hook'` becomes `'pointed'` (46-47).
- `normCount` clamps the strand count to 2..6 and maps 5 to 4 (131-134).
- `effCount` overrides the count by pattern: openweave/chain 4, twist 2 (1483-1487).
- Unknown keys are dropped, which is why `OUTLINE_RATIO` and `GAP_RATIO` cannot be cfg keys.
- The designer passes unknown keys through untouched (D:507-511).

### 2.2 Frame and spine geometry
- `frameLayout(cfg, W, H)` 140-155:
  - S = min(W, H); inset = inset%·S; band = width%·S.
  - Per-edge (u,v) frames, used only for break mapping.
- `buildSpine(layout, mode)` 403-453: a clockwise rounded rectangle through the band centre.
  - R = clamp(band·0.75, 6, band) px (411), or `POINTED_R` 0.01 px for miter-type modes (`pointed/square/round/tile`, 251-259).
  - Sampled every `SPINE_STEP` = 2 px into `{s, x, y, nx, ny}` with exact closure (445).
- `spineAt` 456-462 interpolates position and normal linearly and renormalises.
- `sweepPt` 464-467: page = spine(s) + (v − band/2)·n.
- Miter map (`miterPt` 529-547, `cornerShape` 513-524): inside ±win of each corner diagonal, the along-run distance is remapped piecewise-linearly so that p(0) = d lands on the miter vertex C + d(n1 + n2). An optional concentric radius r = rConst·band − d.
- **Invariant:** p stays monotone while |d| < win, so no sample crosses the miter line (comment 490-499).

### 2.3 Segmentation
- Breaks are `{edge, at%, width%}` of the **edge length** (3053-3056).
  - `edgeIntervalToS` maps them to spine s (1239-1251). `breakExact` adds band/2 − R, so a break lands at the same page x in every corner mode (1246).
  - `autoBreaks` projects `break_border` slots (1312-1335).
- `segmentLoop(S, feats)` 1266-1309: with no features, one closed loop (`full`). Otherwise open segments with `terminal` ends, a cut chosen in the largest uncovered gap, and the seam re-merged. Segments shorter than 2 px are dropped (1288).
- **Invariant:** the cursor never moves backward (1293-1295).
- `collectPolys` 3041-3093 then calls `buildClosedLoopPolys` (2976-2995) or `buildSegments` (2860-2945).

### 2.4 Strand generation in (u, v): `patterns` 1343-1474
Contract: `gen(L, band, sp, opts) → {strands: [{pts: [[u, v]], color, closed}], lam}`, with whole repeats so closed loops wrap (1338-1342).

**plait** (1408-1426):
- λ0 = max(band·(N = 2 ? 2.0 : max(1.5, 0.6·N))·scale, 8 px) (1414).
- λ = opts.lam, or L / round(L/λ0) (`repeatLen` 1407).
- wf = `weaveW` (1367-1372).
- **amp = max(1, band/2 − wf/2 − outlineW(wf) − 1)** (1417). Note the absolute −1 px.
- Strand i: v_i(u) = band/2 + amp·wave(2πu/λ + 2πi/N, …) (1423). Colour i means palette index i mod P.

**openweave** (1429-1444): 4 strands, two phase pairs (0, π/2) each with ± sign, λ0 = 3.0·band·scale, width from band/5.5. Re-sorted so array index = lane (1441-1442). **Invariant:** the fold pairing is index-based.

**twist** (1445-1455): 2 strands ±, λ0 = 2.0·band, width band/3 × 1.15.

**chain** (1463-1474): two twists centred at 0.38·band and 0.62·band, λ0 = 3.2·band, width band/5.

**Sampling** (`sampleStrand` 1376-1388): step `STEP(band)`, always ending exactly at L. It attaches the exact evaluator `pts.vf`, which `sampleVS` (2024-2043) and fold refinement use. `peakGrid` (1394-1406) adds exact peaks ±h when bow ≠ 0.

**Structural fact:** every pattern is a bundle of single-valued functions v(u). No strand can turn back in u except inside tiles or terminals.

### 2.5 Waveform: `wave` 179-189, `waveCore` 193-208
Let w(θ) ∈ [−1, 1].

- **angular k** (clamped to 0..0.995): w = asin(k·sin θ)/asin(k). It is a sine at k → 0 and approaches a triangle wave (straight diagonals) as k → 1. It is odd, half-period antisymmetric, and has w′ = 0 at the peaks (comment 165-168).
- **bow b**: applies only on legs where (cos θ < 0) === (b > 0) (196). With t = |b|:
  - t ≤ 0.5: k ← k(1 − 2t), relaxing the leg toward a sine.
  - t > 0.5: w = tanh(c·sin θ)/tanh(c) with c = 2.5(2t − 1) (`BOW_GAIN` 221).
  - The peaks stay at θ = π/2 + nπ, but the mirror symmetry v_j = band − v_i is lost (comment 169-178).
- **edgeBend e** (clamped −0.9..0.45): w ← w + e(w − w³) (181). It is odd and keeps the peaks.
- **tipExt t, tipPow m**: w ← w + t·sign(w)|w|^m(1 − |w|) (187). It acts near the edge and keeps the peaks and the mid slope.
- Normalisers are memoised in module globals (192, 200, 206).

### 2.6 Sweeping along the spine, corners and warps
- `sweepStrand(spn, sBase, pts, band, warp)` 1204-1236:
  - On rounded spines, each point is swept with `sweepPt`.
  - On miter spines it uses `miterPt`, and inserts miter vertices where a pair of points straddles a corner s-value (1209-1233).
  - `warp(u)` maps pattern u to spine offset.
- **Corner phase lock** (`cornerWarp` 580-651) for pointed/square/round:
  - Per corner, it searches 161 candidates over ±λ/2 for the u where the strand set is mirror-symmetric about the diagonal (score at 592-609; 'peak' also wants an even-coloured strand at its outer peak).
  - Later corners snap to the anchor on a 1·λ lattice (618-623).
  - The warp is piecewise linear: pure translation within ±min(1.5·band, λ) of each corner (632-633), and stretch mid-edge.
  - **Invariant:** knots strictly increase (640), otherwise there is no warp.
- `cornerHold` (660-685), for square corners: the strand at the outer peak holds a straight L, and the others are squeezed affinely in v.
- `pinEnds` (571-579) keeps end tiles rigid. The warp is a pure shift over each tile out to its port; `endSlide` and the explicit `dA`/`dB` let the tile slide instead of the run stretching.

### 2.7 Designed corner tiles
- **Data** `CORNER_TILES` 706-784, in band units of a TL frame (origin at the outer corner, x along the outgoing run, y inward):
  - `lam`: the repeat it was drawn for.
  - `arm`: the port line.
  - `phase`: the out-port phase in repeats.
  - `phaseIn`: optional in-port phase.
  - `over: [a, b]`: weave seed.
  - `paths: [{c, d}]`: SVG M/C/L in band units. `ports` is documentation only (698-699).
- **Selection:**
  - `cornerTileFor` (788-791) looks up by `tileFamily`, i.e. `'plait' + N` or the pattern name (787).
  - `cornerColor` k shifts colours and moves `phase`/`phaseIn` by −k/N (`recolourTile` 798-806). This is exact only when the palette size divides N (comment 795).
  - `cornerModeOf` falls back to `'round'` when there is no tile for the family (809-812).
- **Placement** (`tileLock` 816-917):
  - Half-window A = (arm − 0.5)·band·λ/(tile.lam·band) (`tileHalf` 813).
  - Corner u_c = tile.phase·λ − A − phase0, rounded to whole λ near the corner (880-881).
  - With `phaseIn`, u0 is moved to its own phase (886-893).
  - `cornerFollow` places the anchor (a top corner) first. Every other corner then keeps the anchor's shift, rounded to the **λ/N lattice**, and shifts colours by kc (828-863).
  - `phaseSpread` re-places a follower by a cost (`spreadFollowers` 927-987, `SPREAD_TOL` 0.04).
  - The window must clear the segment end by `TILE_END_CLEAR`·λ = 1.0·λ (840, 877). Otherwise that corner is **not placed** and falls back to the raw miter sweep.
  - Debug records of the warp pieces are kept in `fn.warps` (911-915).
- **Assembly** (`tileAssemble` 1039-1195):
  - Cuts the (u, v) strands at each window (1046-1092).
  - Samples the tile paths at `step/band` (`samplePathD` 989-1012).
  - **Stretches the arms piecewise-linearly**: x > 1 becomes 1 + (x − 1)·kx with kx = (lamB − 1)/(arm − 1) (1094-1101).
  - Maps to the page through `tileFrame` (1014-1017).
  - Matches tile ends to braid ends at the same port line (1116-1131), then `snapTileEnd` replaces the first `TILE_SNAP` = 0.3 band of the tile path with a G1 cubic from the live braid point and tangent (1022-1036, 1134-1140).
  - Records port gap and colour continuity (1142-1146), seeds over/under at the first crossing of `over[0]` × `over[1]` (1151-1167), and stitches pieces into continuous polylines (1168-1194).

### 2.8 Designed end tiles (inside `buildSpineSegmentPolys0` 2244-2854)
- **Data** `END_TILES` 278-333, inside the GEN block that the tool rewrites (K:237-242):
  - Band units. U runs from the end's outer edge into the weave; V is 0..1 across.
  - `portU`, `lam`, `bow`, `outer`, optional `phi {A, B}` attach-phase hints, and `paths: [{id, a, b, pts}]` with roles `port` / `free` / `tuck`.
  - Each tile also gets a vertical-mirror variant and any authored `alt`s (337-359). Variants keep `portU`, `lam` and `paths` only (348-350), so **no `phi` hint**.
- **Applicability:** `endTileFor` returns null when |tile.bow − cfg.bow| > 0.2 (375-379). `endsMode` then falls back to `fold` silently (1478-1482).
- **Phase lock** (`lockTileEnds` 2440-2501):
  - λ0 = tile.lam·band (2444).
  - `tilePhases` (2416-2439) scans 720 phases over one repeat of a nominal braid (`gen(8·λ0)`). For each phase it compares the sorted (v, slope) of the strands against the tile ports. Cost = mean(|Δv|/band + 0.15·|Δatan slope|) (2431).
  - With `phi`, the search stays within ±1/8 repeat (2428). The result is **cached on the tile object** under a key without band px (2417-2419, 2437); see F3.
  - It rejects when cost > `TILE_PORT_TOL` = 0.06 (2464).
  - uA = margin + portU·band and uB = L − margin − portU·band (2465).
  - n = round(D/λ − frac) + dn (2468), and λ = D/(n + frac) (2483). Alternatively, `repeatLam` holds λ and moves the tiles, split by `repeatSplit` (2467-2482).
  - It rejects when |λ/λ0 − 1| > `TILE_LAM_SLACK` = 0.12 (2484).
  - Finally it regenerates strands from phase offset `off` (2485-2494).
- **Assembly** (`assembleTileEnds` 2502-2572):
  - Trims the strands at the port (2505-2508).
  - Maps tile paths with a **fixed stretch k = 1** (2498, `tileLocal` 2358-2363).
  - Eases each port in v over `endBlend`·band with `smooth()` (2518-2526).
  - Port-to-port paths of the same colour become links; different colours become a seam at the midpoint (2536-2546).
  - Tucks pin the nearest crossing under (2549-2566).
  - Chains are assembled by `assembleChains` (2279-2318), and passed through corner tiles when present (`chainsThroughCornerTiles` 2324-2353).
- **Variant and repeat search** (`buildSegments` 2860-2945):
  - Odd N or designed ends trigger a search: per segment end, try the variant codes and keep the build with the fewest over/under repeats (`alternationRepeats` 2947-2973).
  - With `endVariant` pinned (`pinnedEnds` 2875-2892), it tries dn ∈ {1, −1, 2, −2}.

### 2.9 Fold terminals (default ends, and the fallback)
- `assignFolds` 2118-2199.
  - **Even N:** partner i + N/2 (`foldPartner` 2092). The fold sits at the separation extremum, so the shared slope s = 0 and `rimArc` needs no shear.
  - **Odd N (plait-3):** a middle-axis leaf, or a tuck-and-cap scheme (`planOddEnd` 2610-2641; it requires exactly 3 strands, 2643).
  - Stagger `PAIR_STAGGER` = 0.2·λ (228).
- Caps: `rimArc` 1922-1930 and `pointArc` 1937-1956 (twist). Merging is done in `endArcs` 2747-2838.
- **Invariants** (comment 1913-1918, tests §6): tangent continuity, zero shear, v-envelope.

### 2.10 Crossing detection
- `crossPairs` 1512-1570: a uniform grid over segment boxes. Exact, and bit-identical to the all-pairs scan. Self-crossings are only counted for segments ≥ 5 apart; shared-endpoint seams are dropped.
- `findCrossingsOnce` 1598-1633:
  - Dedupes within `dedupeR` (wf·0.8 at the call site 3122; default 3 px).
  - Assigns per-pair alternation as a seed (1611-1617).
  - Pins tucks with `force` (1620-1630).
- Memoised per render on identical input (`fcMemo` 1575-1596).

### 2.11 Over/under: `alternateGlobally` 1643-1714
- Each crossing k is a boolean x_k. Walking any strand, consecutive crossings must alternate, which gives the constraint x1 XOR x2 = 1 XOR b1 XOR b2 (1663-1665).
- Exclusions: fusions (sin < `FUSION_SIN` 0.25, 1647) and crossings within 3 px of each other (1662).
- BFS 2-colouring, seeded in order: forced tucks (1670-1680), then corner-tile seeds by proximity (1683-1698), then everything else (1699-1712).
- **Odd cycles are silently dropped.** The first assignment wins (comment 1639-1641).

### 2.12 Cut gaps and holes
- `underWindow` 1767-1786:
  - Fusion: no hole.
  - Otherwise halfLen = min(6wf, (wOut/2 + wf·`GAP_RATIO` + (wOut/2)·cosA·0.5)/max(0.35, sinA)), capped at underLen/12.
- `splitByWindows` 1843-1910: holes in arc length, merged. Snap-to-end swallows nubs (1884-1885). Runs shorter than 1 px are dropped (1897). Runs are tagged `cutA`/`cutB` and with the over strand.
- `curlCutEnd` 1795-1827: a Hermite tail turning the end toward the over strand's normal by k.
- `cutRuns` 3118-3148: removes corner flecks (`RUN_FLOOR`, pointed spines only, 3134-3137) and marks seams (3140-3141).
- `mirrorHalves` 3154-3168: when no run crosses x = W/2, the left half is kept and reflected; otherwise everything is left as swept (3159).

### 2.13 Painting
- **Stroke mode** (`paintCutStrokes` 3476-3531):
  - Ink pass: `stroke-width` wOut, butt caps at cut and seam ends, round otherwise, round joins or miter (`join`).
  - Colour pass: wf, trimmed by the ink width at cut ends (3525).
  - V9 `cutSlant`/`cutTaper` replace a cut end's last stretch with two clipped filled polygons (`slantEnd` 3205-3262, applied at 3499-3522).
- **Fill mode** (`paintFilled` 3444-3475, §1): body polygons plus face polygons from `fillWidths` and `fillFace`.
- **V12 `fillField`**: inside the placed tile frames, wf is multiplied by 1 + env·Σ a_jk cos(jπU/X) cos(kπV/Y), with env a raised cosine over the last 40% toward the ports (3391-3421).
- Frames come from `tileAssemble` (1098) and `assembleTileEnds` (2511-2515).

### 2.14 SVG output
- `render` 3533-3576: one `<svg>` with a viewBox, optional `userSpaceOnUse` gradients (3546-3566), and two `<g>`s (ink, then colour).
- Coordinates are rounded to 0.01 (3000-3003). The output is PDF-safe: path/g/defs/linearGradient/stop only.
- Production always renders at 816×1056 or 1056×816 viewBoxes (R:62-64).
- `swatch` 3579-3597: a straight strip with scale capped at 0.7 (3583, `SWATCH_MAX_SCALE` 242).

---

## 3. Parameter inventory

Units: **%S** = percent of min(W, H); **band** = band heights; **λ** = repeats; **wf** = fill widths; **px** = absolute. The "Added" column gives the version or commit from the 49 engine commits since `feature/scroll-generator`. "Base" means it predates the hand-drawn match.

### 3.1 cfg keys (via `norm`)

| key | default | clamp / range | units | controls | added |
|---|---|---|---|---|---|
| `enabled` | false | bool | – | render at all (3540) | base |
| `pattern` | `plait` | plait/openweave/twist/chain (43) | – | generator (1408-1474) | chain: match R2 (d5f4d6554) |
| `band.inset` | 2 | none (51) | %S | frame offset (142) | base |
| `band.width` | 6 | none in norm; designer slider 3–10 (D:525) | %S | band height (142) | base |
| `strands.count` | 3 | 2..6, 5 → 4 (131-134) | – | N for plait | 6: R2 |
| `strands.thickness` | 0.55 | `strandW` clamps 0.2–0.95, floor 2 px (160) | fraction of band/max(N,3) | fill width wf | base |
| `strands.scale` | 1 | none; swatch ≤ 0.7 | multiplies λ0 | repeat length (fold/closed runs only) | base |
| `strands.angular` | 0.97 | 0..0.995 (52) | – | asin(k·sin) straightness | R1 (63c783aa8) |
| `strands.bow` | 0 | −1..1 | – | leg reshaping (196-204) | R2 |
| `strands.edgeBend` | 0 | −0.9..0.45 (58) | – | w + e(w − w³) | 790d2339f / f498eb67b |
| `strands.tipExt` / `tipPow` | 0 / 6 | ±0.9 / 1..24 (60) | – | arc-tip extension | V8 |
| `strands.cutCurl` / `cutCurlLen` | 0 / 1.5 | 0..1 / 0.25..4 (54) | – / wf | cut-end curl | V4 |
| `strands.cutSlant` / `cutSlantShift` / `cutTaper` | 0/0/0 | 0..1 / ±0.5 / 0..1 (63) | – / wf / – | slanted, tapered cut faces | V9 |
| `strands.join` / `miterLimit` | round / 4 | round/miter, 1..20 (65) | – | stroke joins | V9 |
| `strands.paint` | stroke | stroke/fill (70) | – | painter | V10 |
| `strands.fillArcW` / `fillBarW` | 1 / 1 | 0.4..1.8 | × wf | arc / bar fill width | V10 |
| `strands.fillArcBulge` | 0 | ±0.6 | – | sin² swell on arcs | V10 |
| `strands.fillInk` / `fillBarInk` | 1 / = fillInk | 0.3..2.5 | × outline width | ink weight per class | V10 |
| `strands.fillArcOut` | 0 | ±0.4 | × wf | body shift to the convex side | V10 |
| `colors.strands` | 2 colours | ≤ 4 entries (74) | – | palette (strand i → i mod P) | base |
| `colors.outline` | `#1a1a1a` | – | – | ink colour | base |
| `gradient.*` | off | – | – | per-colour linear gradients | base |
| `corners` | woven | woven/pointed/square/round or tile names (81) | – | corner mode | modes R2; tiles R3 (e81c00d91…) |
| `ends` | fold | fold/ash/ash-hairpin/loop/heart (44) | – | end treatment | R3 (28b83b97a, a48eb5e02) |
| `breaks[]` | [] | `{edge, at, width}` | % of edge length | segment gaps (3053-3058) | base |
| `autoBreak.{enabled, padding}` | true / 2 | – | %S | slot-driven breaks (1312-1335) | base |
| `symmetry` | none | none/mirror (124) | – | left half reflected (3154) | 05bfdbcc1 |
| `endVariant` | null | int or {A, B} ≥ 0 (117-119) | – | pins the variant (chirality) | 8d4f60d8e |
| `endColor` | null | int ≥ 0 (84) | – | outer-wrap colour filter | 48593ba4c |
| `repeatLam` | null | > 0 (96) | band | fixed λ between end tiles | a48eb5e02 |
| `repeatSplit` | null | 'top'/'bottom'/0..1 (111-112) | – | which end absorbs the remainder | 790d2339f |
| `endSlide` | 0 | 0..1 (103) | – | end slides by a share of the corner error | V6 |
| `endBlend` | null (= 0.6) | 0.1..2 (110) | band | port easing length | V8 |
| `cornerColor` | 0 | int ≥ 0 (86) | palette steps | corner tile recolour plus phase shift | V7 |
| `cornerFollow` | false | bool (90) | – | 1/N-lattice following corners (plait only, 3046) | V7 |
| `breakExact` | false | bool (91) | – | break page position independent of R | V7 |
| `phaseSpread` | 0 | 0..2, true = 0.5 (107) | band | spread phase residual; max end slide | V10 (bd87334e3) |
| `fillField` | null | {end, corner}·a00..a22, each ±0.6 (361-372) | – | tile width field | V12 |

### 3.2 Engine constants (not cfg; the tool patches them by regex, K:231-235)

- **Widths:** `OUTLINE_RATIO` 0.5 (×wf per side; joint-best 0.5172), `GAP_RATIO` 0.6 (×wf; joint-best 0.533), `FUSION_SIN` 0.25 (217-219).
- **Waveform:** `ANGULAR_DEFAULT` 0.97, `BOW_GAIN` 2.5 (220-221).
- **Geometry:** `SPINE_STEP` 2 px, `R_FACTOR` 0.75 (222-223); cap and leaf constants (224-241).
- **Repeats and widths per pattern** (1345-1365), in band units: `PLAIT_LAM_MIN` 1.5, `PLAIT2_LAM` 2.0, `PLAIT_LAM_PER_N` 0.6, `PLAIT_MIN_W_N` 3; openweave 3.0 / 5.5; twist 2.0, ×1.15, /3; chain 3.2, 0.38, /5.
- **Tiles:** `TILE_LAM_SLACK` 0.12, `TILE_BLEND` 0.6 band, `TILE_PORT_TOL` 0.06 band (266-268); `TILE_SNAP` 0.3 band, `TILE_END_CLEAR` 1.0 λ (785-786).
- **Locks:** `LOCK_LATTICE` 1 λ, `LOCK_FLAT` 1.5 band, `LOCK_END_CLEAR` 1.5 λ (557-559); `SPREAD_TOL` 0.04 (926).
- **Painter:** `RUN_FLOOR` 2 wf, `CORNER_ZONE` 1.6 band (3104-3107); `FILL_ARC0/1` 20°/50° (3276); `FIELD_N` 3, `FIELD_MAX` 0.6 (361).
- **Hidden px constants**, the source of scale variance:
  - `strandW` floor 2 (160); `outlineW` floor 0.6 (164)
  - `STEP` clamp 1.25–4 (213)
  - amp −1 (1417, 1432, 1448, 1467)
  - λ0 floor 8 or 10 px (1414, 1431, 1447, 1465)
  - R floor 6 (411)
  - dedupe 3 px (1599, 1662), alternation 3 px (2960)
  - min run 1 px (1897, 1901), min segment 2 px (1288)
  - miter window +1 (522), trim 0.25 (3028), face overlaps 0.5 px (3261, 3465-3466)
  - nearest-end tolerance 0.5 px (2341, 2347)

### 3.3 Tile data fields (the "parameters" hidden in data)
- **Corner:** `lam`, `arm`, `phase`, `phaseIn`, `over`, `paths[{c, d}]`, `ports` (unused by the engine), `notes`. The joint-best tile also carries `nl`, which only the tool reads (K:2052-2054).
- **End:** `lam`, `bow` (used only for the 0.2 gate), `portU`, `outer`, `phi`, `alt`, `paths[{id, a, b, pts}]`.

### 3.4 What the joint-best actually uses
- **Live knobs:**
  - band.inset 1.945 / width 6.079; two breaks at 48.78%, width 16.36%; autoBreak off.
  - plait-4, thickness 0.384, angular 0.742, bow −0.584.
  - cutSlant 0.970, cutSlantShift 0.041; paint `fill` with fillArcW 0.950, fillBarW 1.037, fillInk 1.092, fillBarInk 0.954, fillArcOut −0.031.
  - symmetry mirror, endVariant 1, repeatLam 2.3237, repeatSplit 'top', cornerColor 1, cornerFollow, breakExact, endBlend 1.735, phaseSpread 0.802, endColor 0.
  - consts OUTLINE_RATIO 0.5172 and GAP_RATIO 0.533.
- **Present but about off:** cutCurl 0.014, edgeBend −0.011, fillArcBulge 0.014, endSlide 0.004. `fillField` coefficients are ≤ 0.009 (worth +0.0004).
- **Inert:** `scale` 1.0098 (end tiles fix λ; §4.1).
- **Tiles:**
  - `ash-contained` refit: lam 2.3353, phase 0.8162, phaseIn 0.1957; 4 polyline paths of 140–209 segments.
  - `ash-hairpin` refit: lam 2.2724, `bow: −0.75`, which is stale metadata because the braid is at −0.584; 2 paths of 388 and 352 points.

Both differ from the committed tiles (742-770, 307-312). **[fact]** The joint-best is therefore not reproducible from a cfg alone.

---

## 4. Variation, axis by axis

All of the following is measured on the joint-best with fresh engines and the drawn half only. Script `sweep.cjs`. "Stretch" is the tool's `runStretch` worst ratio on the drawn half; 1.0 means the run keeps its repeat. "Alt" counts over/under repeats.

### 4.1 Weave tightness (λ relative to band)

**Knobs today [fact].**
- `strands.scale` sets λ0 = band·0.6N·scale (plait), rounded to whole repeats per segment (1407-1415).
- `repeatLam` (band) applies between end tiles.
- The tile's own `lam` is the reference: `TILE_LAM_SLACK` gives ±12% (2484).

**Experiments [fact].**
- `scale` 0.7 / 1.0 / 1.4 renders **identically** (318 crossings, same warps), with or without `repeatLam`. When every run ends in designed tiles, λ comes from `tile.lam` or `repeatLam` (2444, 2467), so the designer's "Density" slider (D:532) is dead in this configuration.
- `repeatLam` sweep: end tiles are drawn at 2.00, 2.05, 2.15, 2.32 and 2.45, with stretch 0.97–0.98 and no alt repeats. At **1.9 and ≥ 2.55** they silently become fold caps, stretch 1.254, and 4 fewer kinks because the hairpin is gone.

**Do tiles stay valid?**
- **End tiles:** stored in band units, rigid (k = 1, 2498). Attach phase in repeats (`phi`), ports matched against a braid at λ0 = tile.lam (2444). Valid only near the λ they were fitted at.
- **Corner tiles:** band units. Only the arms beyond the unit square stretch, by kx = (lamB − 1)/(arm − 1) (1094-1101). Measured: kx = 0.785 at `repeatLam` 2.0 and 1.074 at 2.45. That linear stretch is a slope discontinuity at x = 1 and y = 1 by construction. Here the 10° per-vertex fit noise hides it (`armkink.cjs`).
- `phase` and `phaseIn` are in repeats and are found on one waveform.

**What breaks and why.** The tile interior encodes diagonals at one slope (band/λ). Outside ±12%, the run either cannot land on the tile phase with a whole n, or the drawn diagonals no longer meet the live braid's slopes (port cost > 0.06).

**What must become parametric [opinion].** Tile geometry must be expressed relative to the live braid: ports derived from the generator at the current λ, and the interior mapped through a smooth deformation, or regenerated (§7). λ also needs to be a cfg key that works with or without tiles; today it is `scale` for one case and `repeatLam` for another.

### 4.2 Band thickness

**Knobs [fact].** `band.width` and `band.inset` (%S). Tiles are in band units, so they scale with the band.

**Experiments [fact].**

| band.width | tiles | port gap | stretch | alt | notes |
|---|---|---|---|---|---|
| 3 | end ✓, 4 corners | 0.047 band | 0.99 | 0 | |
| 4 | ✓ | 0.043 | 0.98 | 0 | |
| 5 | ✓ | 0.040 | 1.03 | 0 | |
| 6.079 (fit) | ✓ | 0.039 | 0.97 | 0 | |
| 7 | ✓ | 0.038 | 0.97 | 3 | |
| 8 | ✓ | 0.037 | 1.02 | 0 | |
| 10 | end ✓, **0 corners** | – | 1.0 | 6 | max turn 172.7°, raw miter corners |

At 10%, the corner windows no longer clear the segment ends by 1·λ (840/877) and are skipped silently.

**Knife edge (F2).** Band width ±0.004 swings the worst stretch between 0.97 and 1.51 (`fine2.cjs`). The corner colour codes jump between `0300`, `0301`, `0000`, `0001`, `0201` and `0302`.

| d (band.width) | top-L end origin | mirror | joint score |
|---|---|---|---|
| 0 | x 338.7 | applied | **0.8603** |
| +0.004 | x 367.2; bottom end at x 426.2, past the centre line | **off** | **0.7117** (right 0.48, top-L 0.673) |
| +0.052 | x 298.4 | applied | **0.611** (top-L 0.219, cap 0.15) |

**Mechanism.** Discrete choices amplify continuous error: n = round(…) (2468), the dn ∈ {±1, ±2} search on alternation repeats (2881), the λ/N lattice rounding (852, 859), the spread search over jj (941), and the variant pick. Also at band +0.004, the right half carries a **1.51× stretched run** at x ≈ 632 that only `mirror` hides. At the exact fitted value no stretched pieces exist on either half.

**Scale variance (F4).** At page scales 0.5–3× (same aspect ratio), crossings on the drawn half are 171, 168, 159, 150, 165, 150 and 165, and the corner codes and corner shifts differ (`scaleinv.cjs`). Production is pinned to 816×1056 (R:62-64), so the product renders consistently. Fitting to reference art at another scale is not consistent.

**History dependence (F3).** A fresh render gives warp 0.970; after a band-4% render, 1.509; after a band-6.019% render, 1.473. The SVGs differ.

**What must become parametric [opinion].** Every px constant in §3.2 should be expressed relative to band or wf. The placement solver needs continuity or hysteresis. Caches need complete keys (§7).

### 4.3 Strand width, outline weight, gap

**Knobs [fact].**
- wf = max(2, band/max(N,3)·clamp(thickness, 0.2, 0.95)) (160, 1371).
- Outline per side = clamp(wf·`OUTLINE_RATIO`, 0.6, wf) (164).
- Gap = wf·`GAP_RATIO` (1779).
- Fill-mode multipliers (§3.1).
- `OUTLINE_RATIO` and `GAP_RATIO` are not cfg keys. With engine defaults instead of the fitted constants the score is **0.8517 instead of 0.8603**.

**Coupling [fact].** Amplitude depends on width: amp = band/2 − wf/2 − outlineW − 1 (1417). Thicker strands pull every centreline toward the middle, which moves the ports.

| thickness | result |
|---|---|
| 0.25 | ✓ |
| 0.30 | ✓ but stretch 1.25 (knife edge) |
| 0.384 (fit) | ✓ |
| 0.45 | ✓; inks touch at 10 points (min centreline gap 0.986·wOut) |
| 0.50 | ✓; touch, min 0.92·wOut |
| **0.60** | **end tiles fall back to fold** |
| **0.75** | fold plus **8 colour jumps at corner ports**, port gap 0.198 band |

The tile note itself limits `ash-contained` to thickness ≤ about 0.45 (760). My touch metric excludes ±2·wOut around crossings, so it is approximate at small widths.

**Do tiles stay valid?** Tiles are centrelines and width is painted, so they survive moderate width changes. Two things break them: (a) the amplitude coupling moves the braid's ports, and (b) parallel strands inside a tile were spaced for one width.

**What must become parametric [opinion].**
- Decouple amplitude from width, with an explicit lane-fill fraction.
- Make outline and gap cfg keys.
- Express tile lanes as strand slots whose spacing follows wf + gap.

### 4.4 Strand count

**Knobs [fact].** `strands.count` 2..6 (5 → 4). The phase step is 2π/N. λ0 grows 0.6·band per strand. Folds: even N pairs i with i + N/2; odd N is plait-3 only (2643).

**Tiles [fact].**

| Tile | Families available |
|---|---|
| corner `ash` | plait4, plait3, twist |
| corner `mitre`, `ash-traced`, `ash-contained` | plait4 |
| end `ash` | plait4, plait3 |
| end `ash-hairpin` | plait4 |
| end `loop`, `heart` | plait4, twist |

Experiments on the joint-best: count 2, 3 and 6 gave corners `round` and ends `fold` (silent fallback, 810, 1480). There were also 12–18 points outside the frame and overlapping inks (touch at 0·wOut) from the round-corner squeeze.

**What breaks and why.** A tile is a specific knot diagram with N ports and a crossing pattern. A different N needs a different diagram.

**What must become parametric [opinion].** Tiles become diagram templates parameterised by N (e.g. "outer L + nested bights, one per pair"), or each family gets a generator.

### 4.5 Pattern family

**Fact.**
- plait (N phase-shifted copies of one waveform), openweave (two ± pairs), twist (±), chain (two offset twists) (1408-1474).
- All are single-valued v(u), so key patterns, Solomon rings, spirals and anything that turns back can only exist as tiles or terminals.
- Patterns carry their own λ and width tables (1345-1372).
- Over/under is global parity (§2.11), which suits any diagram.
- Experiments: twist, openweave and chain on the joint-best cfg all fall back to round/fold. Chain's drawn-half stretch was 0.394 (heavily compressed), because the round-corner lock fits the chain repeat badly.

**Opinion.** New families need a representation richer than v(u) bundles: a strand graph in band coordinates, i.e. (u(t), v(t)) curves with ports.

### 4.6 Corners and ends

**Corners [fact].**
- Algorithmic modes: woven (rounded spine), pointed/square/round (miter map plus phase lock plus square's hold) (251-259, 529-547, 580-685).
- Designed tile mode (§2.7).
- The designer offers only Woven and Pointed (D:570-571).
- A tile corner falls back to an **unlocked raw miter** whenever its window doesn't clear the segment ends: breaks at 30% → 2 of 4 corner tiles placed, max turn 170°, alt 7; break width 35% → 0 placed.

**Ends [fact].**
- Fold (default and fallback), plait-3 tuck ends, designed end tiles (§2.8).
- `endVariant` fixes chirality. The test at 912-940 holds it across band widths and page sizes, but only the chirality, not the placement.
- Moving the breaks: widths 10–25% keep everything. One break, or left/right breaks, also work (alt 0–2).
- No breaks gives a closed loop with corner tiles only; the end tiles are unused (by design).

---

## 5. Hard-coded assumptions tied to the one reference

1. **Tile data is Ash's art.** `END_TILES` (278-333) and `CORNER_TILES` (706-784) are traced or fitted from the Jovious border in band units, for plait-4. The joint-best refits again outside the engine.
2. **4-strand plait shape constants:** λ0 = 0.6·N·band, "4-strand hand-drawn ≈ 2.4 band" (1347, 1411-1413); `ANGULAR_DEFAULT` 0.97; `BOW_GAIN` 2.5.
3. **Ink weight:** `OUTLINE_RATIO` 0.5 from "Jovious knot: 29 px fill, 15 px outline at 600 dpi" (161-163; also `ASH_INK` at K:2028).
4. **Two colours:**
   - `cornerColor` is exact only when the palette size divides N (795).
   - `cornerFollow` assumes plait colours step with strand index (`fol.N`, `fol.P`, 3046), and colour equals strand index mod palette (1423).
   - The palette is capped at 4 (74).
5. **Mirror symmetry:** `symmetry:'mirror'` is left–right only, justified by Jovious self-scores (3149-3153). It applies only when no run crosses x = W/2 (3159), and the fitted page relies on it (§4.2).
6. **Break semantics:** `repeatSplit` 'top'/'bottom' compares against H/2 (2476-2479). `breakExact` exists because the fitted break was placed by page x (1242-1246).
7. **Hairpin special-casing:** `endHasHairpin` (1477) routes `buildSegments` (2864, 2897).
8. **Bow gate of 0.2** against the stored tile.bow (377). The joint-best's stored −0.75 is stale against its −0.584 braid.
9. **Rectangle frame:** four right-hand corners, one TL tile rotated to all four (687-693, 1014-1017). No other frame shape.
10. **Odd N limited to 3** (2643). N = 5 is mapped to 4 (133).
11. **Fixed render size** 816×1056 in production (R:62-64). Px constants assume roughly 50 px bands.
12. **Fold geometry choices** made for the earlier references: `PAIR_STAGGER` 0.2 (228-232), equal-diameter loops.

---

## 6. Smoothness and fluidity mechanics

**Smooth by construction [fact]:**
- Analytic waveform with exact evaluators. Peak-exact sampling for bowed waves (`peakGrid`, 1389-1406).
- Fold caps tangent-continuous with zero shear (1913-1918).
- `snapTileEnd` G1 cubic over 0.3 band (1019-1036).
- End-tile ports eased with smoothstep over `endBlend` (2518-2526).
- `curlCutEnd` Hermite, G1 at the blend start (1787-1827).
- Corner warp is a pure translation over each corner window (630-633).
- Width easing (3434-3435), bulge sin² (3433), `fieldEnv` raised cosine (3398), `cutTaper` smoothstep (3254).

**Known sources of non-smoothness [fact]:**
1. **Per-point fitted tiles** carry centreline noise: κ-noise 0.071–0.075/px vs 0.011 for the braid; 5.8–5.9 curvature flips per band vs 0.07 (§1.3a). This is the visible 6× wobble, the "bump on the end wrap shoulder" and the "hook in the nested L".
2. **Waveform curvature jump at every peak when bow ≠ 0.** The bowed and straight legs use different formulas (196-207). At the joint-best settings, w″ is −0.910 on one side of a peak and −1.353 on the other, a ×1.49 jump. The waveform is G1 but not G2 at every arc tip. With bow = 0 it is −1.324 on both sides.
3. **Piecewise-linear warps** (`cornerWarp` 641-648, `tileLock` 900-907). The stretch ratio du/ds jumps at each knot, so the strand slope jumps where a run's stretch k differs from its neighbour's. That is small at about 3% and visible at 1.5×.
4. **Corner-tile arm stretch** kx is piecewise-linear at x = 1 and y = 1 (1101).
5. **Miter map** p(t) is piecewise-linear (536-546). Strands get slope breaks at the diagonal and at the window edges. These are the algorithmic corners that were rejected in the match work.
6. **Polyline output:** braid facets every 3.1 px (213), spine table every 2 px (222), and coordinates rounded to 0.01 px (3000-3003).
7. **Fill painter** (§1): spokes, seams, and run-to-run ink weight steps between arc and bar classes.

**Tile sampling and joining [fact].**
- Corner tiles: `samplePathD` at step/band (1100), cubic Béziers flattened. Fitted tiles are already dense polylines.
- End tiles: stored as point lists, mapped linearly (2358-2363).
- Joins: corners use the G1 cubic from the live braid point and tangent; ends use smoothstep v-easing over `endBlend`.
- Port gaps before the snap are ≤ 0.039–0.047 band on the joint-best.

---

## 7. Test coverage (`tools/test-scroll-knot.cjs`, 1,553 lines; ALL PASS, 26,375 checks in 6.4 s)

**What it protects [fact]** (sections located by the line in the test file):
- `norm` defaults, whitelists, clamps and legacy maps (11-16, 231-266, 552, 802-809, 956-961, 1146, 1216-1217, 1297, 1327-1329, 1391, 1445-1447).
- Frame and spine formulas, normals, wrap (18-43). Segmentation, including the cursor pin and seam wrap (49-82).
- Patterns: whole repeats, closed wrap, inside band, colours (92-115, 219-230, 799-848). Waveform identities: bow 0 equals the R1 wave, peaks preserved, tipExt odd and monotone (824-829, 1340-1342).
- Crossings and alternation basics (116-133). True cut gaps, including that no under-strand point lies inside the over footprint (391-466).
- **Fold permanence invariants:** shear ≤ 1°, |va + vb − band| < 1e-3, odd feet coincident, v-envelope, u-containment, ≥ 40% non-degenerate (502-547). Fold junctions < 20° with contiguity (307-366).
- Alternative ends: tangent junctions, envelope, tucks under, page alternation (548-641).
- Corner modes: miter map monotone, continuous, rejoining; mirror symmetry; no overflow; fleck floor (642-798).
- `endVariant` chirality across band widths and page sizes (912-940).
- Designed corner tiles: placed at four corners, ports matched with no colour jump, pre-snap gap, G1 at ports, inside frame, alternation through tiles, all four corners identical up to rotation (941-1072).
- V4–V12 opt-ins: off means byte-identical, plus their own geometric claims (1073-1553). Examples: curl within 4° of square; drawn braid pieces within 8% of the repeat with `phaseSpread`; slanted faces parallel; fill polygons closed; `fillField` limited to the tiles; mirrored.

**Gaps relevant to variation [fact].**
- Every page test runs at **816×1056** only, except the `endVariant` chirality check.
- The tests use the **committed** tiles, so the joint-best design itself is untested.
- No test checks:
  - (a) render-history independence (F3)
  - (b) scale invariance (F4)
  - (c) continuity under small parameter changes (F2)
  - (d) the drawn-half stretch at nearby slider values
  - (e) silent fallbacks (tiles vs fold/round) across sliders
  - (f) centreline smoothness inside tiles (curvature noise)
  - (g) that fill outlines are simple polygons

**Invariants a variation-capable engine needs [opinion]:**
1. **Determinism:** same cfg gives the same bytes regardless of what was rendered before.
2. **Scale covariance:** rendering at s× equals s× the geometry, within tolerance.
3. **Lipschitz placement:** a slider move of δ moves every tile by at most C·δ, unless the move crosses a declared topology change, which must be reported.
4. **Validity envelope per tile:** declared ranges (λ, width, amplitude, N) with tested attach and no fallback inside them.
5. **Smoothness:** G2 (or bounded curvature variation) along strands except at declared corners, measured as κ-noise and flips per band.
6. **Stroke validity:** no ink touching between non-crossing neighbours, gap ≥ GAP·wf at every crossing, colour polygon ⊂ ink polygon, simple polygons.
7. **Mirror independence:** both halves valid without `mirror`, so `mirror` cannot hide a defect.

---

## 8. Recommended parameterisation for sliders plus fitting to reference art [opinion]

**What the evidence says, before the proposal [fact]:**
- The continuous visual knobs are smooth and mostly well-behaved: angular, bow, edgeBend, width multipliers, band height within 3–8%.
- The problems are all in four places: (i) discrete placement decisions, (ii) tile geometry frozen as point data in band units at one λ, width and waveform, (iii) px-absolute constants and caches, and (iv) per-point fitting, which buys score with centreline noise.

**Proposed layers:**

1. **Topology (discrete, chosen from a catalogue or inferred from art):**
   - Family plus N, expressed as a strand permutation per repeat with crossing signs. This generalises v(u) bundles.
   - Corner and end treatments as small **knot diagrams**: a graph whose nodes are ports (lane slots), crossings and turns. Over/under comes from global parity, as now.
   - This is what you "pick" when replicating art.

2. **Braid geometry (continuous, dimensionless):**
   - Height H in px.
   - Repeat ρ = λ/H, with **one** key that works with and without tiles (replacing `scale`, `repeatLam` and `tile.lam` for this purpose).
   - Waveform: today's k, bow, edgeBend and tipExt, or a monotone spline for one leg made **G2 at the peaks** (bow currently breaks G2).
   - Amplitude fraction α, explicitly **decoupled** from width.
   - All px constants become fractions of H or wf.

3. **Stroke (continuous):**
   - Fill fraction φ = wf/(H/N), ink ratio, gap ratio (both promoted from constants to cfg).
   - Per-class widths (arc/bar) with a smooth class weight instead of a per-run step.
   - Face model (slant, shift, taper), join mode.
   - Painted as true outlines (§1.5).

4. **Tiles as smooth parametric curves anchored to the live braid:**
   - Store each tile path as a short cubic B-spline (tens of control points, not 140–388 vertices).
   - Use a frame whose along-run axis is in **repeats** near the ports and in band units in the core.
   - Ports are computed from the generator at the current (ρ, α, waveform, N) and are never stored. The interior is deformed by a smooth map (e.g. thin-plate or harmonic in the tile frame) from stored ports to live ports, so attachment holds for any slider value inside a declared envelope.
   - A per-tile envelope (ρ, φ, α ranges) replaces the silent `TILE_PORT_TOL` and `TILE_LAM_SLACK` fallbacks with explicit "out of range" signals.

5. **Placement solver with continuity:**
   - Choose the repeat count n and lattice offsets once.
   - While a slider drags, hold the discrete state ("sticky"), and absorb changes by continuous slides or stretches inside declared bounds. Re-solve only on release, or when a bound is exceeded.
   - Report every topology change.
   - This removes the knife edge (F2) without losing the discrete optimum.

6. **Determinism hygiene:** cache keys complete, or no caches across renders (2417); scale-covariant constants; tests from §7.

7. **Fitting to reference art:** two stages.
   - (a) Infer topology: N from crossing density per lane, family, symmetry, and tile diagrams from skeleton graphs. `trace-corner.cjs` already extracts skeletons.
   - (b) Fit the continuous layers (2–4) with the existing raster score, plus regularisers. A curvature-variation energy on the tile splines, which would have prevented the 7× κ-noise, and a robustness term that scores neighbours ±δ in H and ρ. The knot-match `--robust` option exists (K:9) and should be on by default, because the current optimum is not robust (0.8603 → 0.7117 at +0.004).
   - Fitted tiles should be **saved in the parametric form** and then re-validated across the envelope, not saved as per-point data.

**Smallest useful first steps, in order:**
1. Fix the `_ph` cache key and the px constants.
2. Promote `OUTLINE_RATIO` and `GAP_RATIO` to cfg.
3. Add sticky placement plus mirror-independent validity tests.
4. Refit the two fitted tiles as smoothed splines (corner-preserving smoothing at σ ≈ 1 px costs a 0.015 px mean shift).
5. Build the true-outline fill painter.
6. Only then generalise tiles to live-port deformation and N-parametric diagrams.

---

### Scratch artefacts
All in `/private/tmp/claude-501/-Users-averykrouse-GitHub-ORK-tobias-ORK3-tobias/d582c881-63eb-4331-acce-d387afe6d0c7/scratchpad/synth/engine/`:

- **Harness:** `h.cjs` (loads the engine with the joint-best overrides; metrics).
- **Fill-painter investigation:** `e0.cjs`, `e1.cjs`, `edge.cjs`, `edgec.cjs`, `aa*.cjs`, `wprof.cjs`, `rough.cjs`, `smooth.cjs`, `cnt.cjs`, and the crops `z30-both.png`, `ql-*.png`, `chr-*.png`, `face150.png`, `insp1.png`.
- **Variation:** `sweep.cjs`, `fine2.cjs`, `knife.cjs`, `leak.cjs`, `scaleinv.cjs`, `warpwhere.cjs`, `armkink.cjs`, `score.cjs`.
