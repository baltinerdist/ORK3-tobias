# knot-match: how the toolchain fits one drawing, and what it would take to fit any drawing

A read-only deep-dive into the knot-match tool, 2026-11-08. It feeds a synthesis whose goal is to give the knot engine any reference knotwork and have it replicate that artwork, with the parameters exposed as sliders.

## Sources and conventions

- `km:N` is `/Users/averykrouse/GitHub/ORK-tobias/ORK3-tobias/.worktrees/knot-hand-drawn/tools/knot-match/knotmatch.cjs`, line N, at commit a6a58a5f6 (3,174 lines).
- `fit:N` is `fit/fit.cjs` in the working tree. The tree includes this session's uncommitted SMOOTH/INIT diff (71 lines). `lib:N` is `fit/lib.cjs`.
- `raster:N`, `bench:N` and `trace:N` are `raster.cjs`, `bench.cjs` and `trace-corner.cjs`.
- The engine is `/Users/averykrouse/GitHub/ORK-tobias/ORK3-tobias/.worktrees/knot-v6-ends/orkui/template/revised-frontend/scroll/scroll-knot.js` (`eng:N`).
  - **Caution:** a concurrent session edited it while I was reading. At 08:53:52 it added 12 uncommitted lines to `offsetOutline`, a fix for fill-painter edge scalloping.
  - Numbers marked **[pre-edit]** were measured on the committed engine. With the edit, the committed best re-scores 0.8609 instead of 0.8611 (TL 0.8660 instead of 0.8665).
- `S` is the prior session's scratch directory: `/private/tmp/claude-501/-Users-averykrouse-GitHub-ORK-tobias-ORK3-tobias/8e4c23d4-e86e-4eb4-8f60-0409f897e03f/scratchpad/km/`. That includes `S/ledger.md`, `S/expt/review.md` (outside review 1), `S/expt2/` (outside review 2), `S/vr/visual-review-{1..6}.md` and `S/perf/bench.jsonl`.
- `T` is my scratch directory: `/private/tmp/claude-501/-Users-averykrouse-GitHub-ORK-tobias-ORK3-tobias/d582c881-63eb-4331-acce-d387afe6d0c7/scratchpad/synth/tool/`. Every number I measured comes from a script there (see the Appendix).
- **Facts and proposals.** Sections 1–4 and 6 describe the tool as it is. Paragraphs headed **Proposal** are my suggestions. Section 5 keeps facts and proposals apart explicitly.

## 0. Findings in brief

1. **Ingestion only accepts this one drawing's format.**
   - The reference must be an SVG built like Ash's file: a leading comment, two `<symbol>`s, colour placeholders `var(--knot-c1/c2)`, and a 2550×3300 viewBox (km:435-444).
   - Its colours are *assigned* by string substitution, not measured.
   - The default path resolves into the **main checkout**, not the worktree (km:168), so the reference depends on whatever branch the main checkout has.
   - Band measurement assumes a rectangular, axis-aligned frame with one break centred on each of the top and bottom edges (km:448-465).
2. **Metric v2 is `0.75·conf + 0.25·exp(−chamfer/(0.05·band))`.**
   - conf is a confusion-weighted pixel agreement: every class mismatch costs 1, except colour A↔B, which costs 0.25 (km:596-598, 763-765, 806).
   - Alignment is searched only at integer pixels (km:774-791).
   - The nearest-palette classifier turns 22–58% ink-over-ground anti-aliased pixels into **pink**. 20% of all "pink" pixels in Ash's side run are this fringe.
3. **The ceiling is Ash against his own left-right mirror** (re-measured): sides 0.883/0.888, TL 0.903, top-L 0.923, cap 0.918. A 180° rotation, which is a wrong-chirality design, scores 0.22–0.49.
4. **"Goal met" holds on the nominal metric only.**
   - The committed best is 0.856/0.854 on the sides, TL 0.867 and top-L 0.868 nominal [pre-edit].
   - Its top-L and left nominals are still the **maximum** over 16 sub-pixel phases (winner's curse).
   - Averaged over the 16 phases at 1×, only TL passes 0.85 (TL 0.858, top-L 0.840, left 0.843).
   - Averaged over the tool's own 4 phases, the sides sit at 0.8505/0.8499. At 2× resolution all three pass on the phase mean.
5. **The metric does not reward smoothness.**
   - The per-point fit raised the tile centrelines' curvature inflections from 32 to 121 and their wiggle energy (∫κ′²) by 58%, in exchange for +0.024 TL and +0.028 top-L.
   - A smoothing penalty on knot second differences cut knot roughness about 8× for ≤0.002 of score, but left 116 inflections. It penalises the wrong quantity.
   - Part of the "zoom-only bumps" is the fill painter itself (the concurrent engine fix above), not the fit.
6. **Topology errors are nearly invisible to the metric.**
   - My estimate: one wrong over/under crossing costs about 0.01 of score, about one standard deviation of sub-pixel noise.
   - Correctness lives entirely in the gates (Section 4). The gates fire only on would-be bests, relative to the baseline.
7. **Why the optimisers stalled, and what broke the stall.**
   - CMA-ES stalled first on sampling width: the optimum is a narrow ridge.
   - It then stalled on representation: 6 normal modes per path plus a 3×3 warp cannot express 1–2 px local moves.
   - The decisive lever was coordinate descent on about 100 local knot offsets per tile (fit.cjs): +0.024 to +0.028 in about 2,000 renders on one process.
8. **Only the joint page counts.**
   - Stage pages compress their far runs (repeat 168/188 px against Ash's 179/181 px), so tiles fitted there do not transfer.
   - Stage bests are mutually incompatible: the corner13 page scores 0.47 on the sides.
9. **Speed.** Single-thread cost per candidate fell 4.5–5.8× with exact results: weave 390 → 71 ms, corner 255 → 57, end 259 → 45. Throughput of a 4-worker pool rose 2–3.4×, from 9–16 to 31–38 candidates/s (bench).
10. **Generalisation is the big gap.**
    - The scoring, optimiser and gate machinery is generic once a class map exists.
    - Everything upstream of the class map is hand-measured for this one drawing.
    - The missing pieces are colour clustering with anti-aliasing unmixing, band-spine extraction, period and strand-count estimation, tile library matching, topology extraction, and a fairness prior.
    - My probes show that the obvious estimators fail without a model:
      - autocorrelation peaks at 1.5 repeats;
      - colour runs per row cannot count strands;
      - a naive outline-width estimate is broken by the fringe.

---

## 1. Reference ingestion

### 1.1 How the reference is loaded

- **Path.** `DEFAULT_REF = path.resolve(__dirname, '../../../../assets/scrolls/common/knot/knot.svg')` (km:168).
  - From `.worktrees/knot-hand-drawn/tools/knot-match/` that is four levels up: `/Users/averykrouse/GitHub/ORK-tobias/ORK3-tobias/assets/scrolls/common/knot/knot.svg`, in the **main checkout**, which is currently on `feature/scrollery`.
  - The worktree itself has no `assets/scrolls/`. If the main checkout switches to a branch without that asset, every score breaks. If the asset changes, every score silently changes.
  - `--ref` overrides the path (km:2667, 3141, 3157), but the file must still be in the same SVG dialect.
- **The file** (364,992 bytes):
  - viewBox 2550×3300, which is 8.5×11 in at 300 dpi;
  - one leading comment, and two `<symbol>`s: `Knot-Band-1` (blue band) and `Knot-Band-2` (pink band);
  - 636 filled paths. 318 are colour pieces with `style="fill:var(--knot-c1|c2)"` (158 + 160). The other 318 have no style, so they are black outline shapes (default fill). `fill-rule="evenodd"`.
  - The outlines are **filled shapes, not strokes**. The engine instead draws outlines as strokes, or as filled ribbons in fill mode.
- **refSvg (km:435-444)** rebuilds a renderable page:
  - It drops everything before the first `-->` and strips the closing `</svg>`.
  - It wraps the result in a fresh `<svg viewBox="0 0 2550 3300">` with a background rect in `PALETTE.bg`.
  - It replaces `var(--knot-c1)` with `PALETTE.A` and `var(--knot-c2)` with `PALETTE.B`.
  - It appends `<use href="#Knot-Band-1"/><use href="#Knot-Band-2"/>`.
  - For `--refJitter` it wraps the art in a sub-pixel `translate` (km:438-439).
  - The expt2 helper `lib.ashSvg` adds an optional left-right mirror transform for the ceiling measurement (lib:8-15).
- **getRef (km:881-887)** rasterises the page with `rsvg-convert` at `RASTER_W×RASTER_H = 1275×1650`, "half of Ash's page" (km:163). It then classifies the pixels (`classMap`), measures the band (`measureRef`), and caches all of it per process.
- **Our side.**
  - `renderSvg` (km:349-356) renders the engine at the production page size `PAGE_W×PAGE_H = 816×1056` (km:162), which is also 8.5×11 at 96 dpi. It prepends a `PALETTE.bg` rect.
  - The page is rasterised to the same 1275×1650 (×1.5625), only inside the boxes that scoring reads:
    - `classMapCropped` (km:362-388) issues one `rsvg-convert` per merged box, using a narrowed viewBox;
    - or `raster.cjs`, an in-process emulation of cairo (24.8 fixed point, cairo's stroke polygons, nonzero fill with 15 sub-rows, pixman compositing). It agrees with rsvg on ≥99.84% of pixels, and candidate scores agree within 0.00052 (raster:1-19).
  - `raster.cjs` handles only the engine's own SVG subset and returns null for anything else (raster:1-8), so **the reference always goes through rsvg**.
  - My check on the committed best: rsvg and the JS raster give region scores within 0.0002 of each other (TL 0.8667 vs 0.8665 [pre-edit]).
  - **The tool assumes both drawings share the same page aspect ratio.** Region boxes are computed once on Ash's raster and applied unchanged to ours.

### 1.2 Classification: the four-class map and the palette

- **classMap (km:413-433).** Each pixel with alpha < 128 is ground (km:428). Every other pixel gets the class of the nearest palette colour in RGB Euclidean distance: `{0 ground, 1 ink, 2 colour A, 3 colour B}` (km:165).
- **The palette (km:164)** is fixed:

  | Class | RGB |
  |---|---|
  | bg (ground) | [244,234,210] |
  | ink | [0,0,0] |
  | A | [42,91,215] |
  | B | [224,106,160] |

  These are exactly the engine colours in the committed design (`cfg.colors.strands = ['#2a5bd7','#e06aa0']`, outline `#000`). Because refSvg *writes* the same colours into the reference, both images share one palette by construction. Nothing in the tool measures colours from an image.
- **Ash's full 1275×1650 class map** (my `verify.cjs`): ground 1,852,398 px, ink 140,950, A 52,888, B 57,514. Ink is 56% of the non-ground pixels, so ink placement dominates every score.

### 1.3 The soft-edge problem (anti-aliasing)

- **Both rasters are anti-aliased, and the classifier is nearest-palette.**
- I computed which class a linear blend between two palette colours falls into (`T/` one-liner, Section 1 of the Appendix):

  | Edge | Ink or colour coverage | Class assigned |
  |---|---|---|
  | ground → ink | 0–22% | ground |
  | ground → ink | **22–58%** | **B (pink)** |
  | ground → ink | 58–64% | A (blue) |
  | ground → ink | ≥64% | ink |
  | ground → A | 44–54% | **B** |
  | A↔ink, B↔ink, A↔B | | split cleanly at about 50% |

  So every ink/ground silhouette edge carries a pink (sometimes blue) fringe about 1 px wide. The effect depends on this palette: with yellow strands, for example, a different blend would leak.
- **Measured on Ash's left run** (`T/outline.cjs`, box x 19..113, y 0.3H..0.7H):
  - The nearest-palette map has 7,874 pink px; a coverage-aware map has 6,287. So **20% of "pink" is fringe**.
  - Blue goes from 6,856 to 6,283 px (8%). This matches the first outside review's 20% (S/expt/review.md Q5).
- **Consequences:**
  - **(a) Scores.** Fringe pixels count as colour in both images and move with the sub-pixel phase. The coverage-aware classifier (`S/expt2/q4.cjs:6-14`: project each pixel onto the nearest bg–ink, ink–A, ink–B or A–B mixing line and split at t = ½) raises *every* score by +0.014 to +0.027, the ceiling included:

    | Region | Mirror ceiling (v2 → coverage-aware) | fit-both (v2 → coverage-aware) |
    |---|---|---|
    | TL | 0.903 → 0.927 | 0.867 → 0.895 |
    | top-L | 0.923 → 0.937 | 0.868 → 0.891 |
    | left | 0.883 → 0.909 | 0.856 → 0.883 |

    (results/2026-11-08-review-2.md Q4.) The coverage-aware classifier exists only as scratch code. Owner question (b) is still open.
  - **(b) Measurements.** In my `autoest.cjs`, a distance-transform outline-width estimator on the nearest-palette map returned **1.4 px**, against a true ≈3.75 px, because the fringe sits between the ink and the ground.
    - Scan-line ink runs between ground and colour (`outline.cjs`): the coverage-aware map gives 3,358 valid runs, with a median of 5 px horizontally (≈3.5 px normal to a 45° outline). The nearest-palette map gives only 2,051, because the fringe breaks the ground|ink|colour pattern.
    - **Any automatic parameter estimation must use a coverage-aware classifier.**

### 1.4 How band geometry and regions are measured

- **measureRef (km:448-465)** works on the reference class map.
  - **Inset:** the first column from x = 0 with any non-ground pixel in rows 0.3H–0.7H (km:450-451).
  - **Band:** the run of consecutive inked columns after that (km:452-453).
  - **Breaks:** from the page centre column, scan left and right along the *top* band's rows until a column with ink appears (km:456-459). The tool takes the top band's rows to be `[inset, inset + band]`, i.e. **the left inset is reused as the top inset**. The bottom break is found the same way on the bottom band rows (km:460-463).
  - `yMid` is computed but unused (km:455).
  - **Results for Ash:** inset 29 px, band 74 px, `topGap` [523, 751] (228 px wide), `botGap` [488, 787] (299 px wide). Both breaks are centred near x = 637, but Ash's top and bottom breaks have different widths.
  - **Implicit assumptions:**
    - the frame is an axis-aligned rectangle;
    - the left band is continuous over 0.3–0.7H;
    - nothing inks the margin;
    - every side has the same inset;
    - there is exactly one break on the top edge and one on the bottom, each straddling the page's centre column;
    - there are no breaks on the sides.
- **Band, two meanings.** The measured band (74 px) is the *ink extent*. The engine's band is nominal: `band.width` percent of `min(W, H)` (eng:140-142). The committed design's 6.0787% × 816 = 49.6 page px is 77.5 raster px. `ASH_INK` uses Ash's band as 309 px at 5100 wide, i.e. 77.25 at 1275 (km:2028). Region boxes use the measured 74.
- **regionsFor (km:466-491).** With pad = 0.35 band:

  | Region | Definition | Ash's box (raster px) |
  |---|---|---|
  | `left` / `right` (`axis: 'y'`) | x ∈ [inset − pad, inset + band + pad] (and its mirror), y ∈ [0.3H, 0.7H] | left [3,495]–[129,1155] |
  | Corners | squares of side `inset + 3.2·band` at each page corner (km:474-476) | TL [0,0]–[266,266] |
  | Ends | 3.6 band long × (band + 2·pad) tall, running outward from each gap edge (km:478-483) | top-L [257,3]–[549,129] |
  | `cap` | a hand-placed ~1.3-band box at the top-L gap edge, the hairpin's inner turn, with constants 1.25 / 0.05 / 0.15 / 1.05 band (km:485-489) | [430,18]–[527,107] |

  - Only TL, top-L, cap and the two sides are targets. The other corner and end positions are diagnostics (km:987-997; owner rule).
  - About 60–80% of the TL and top-L box pixels are leg braid, not tile (S/expt/review.md Q1). So a "corner score" largely measures the phase of the legs.
- **Our page is never measured for the scoring boxes.** The same boxes are read on our raster, and the alignment search absorbs offsets (±9 px for tiles, ±104 px along the sides). Our own band and breaks are measured (`measureOurs`, km:1313-1323) only to place the *gate windows* for our ends (`windowsFor`, km:1099-1104), because our breaks can sit elsewhere.
- **Period.**
  - `measurePeriod` (km:865-878) scans lags **120–260 px** along the left and right runs. At each lag it scores the agreement of fill classes, and it picks 181 px (2.45 band). That 181 is then hard-coded into the chain scripts as `--repeatPx 181`.
  - My probe (`T/ceiling.cjs`, `T/autoest.cjs`) scanned lags 40–400 px on the left run instead. Peak autocorrelation:

    | Lag | Colour-exact agreement |
    |---|---|
    | 272 px | 0.917 |
    | 363 px | 0.903 |
    | 91 px | 0.835 |
    | 181 px | 0.773 |

    The ink mask alone and the colour-blind fill mask rank the same four lags in the same order.
  - So **the chosen repeat is only the fourth-highest peak**. A half-repeat shift (91 px) matches the drawing almost as well as a full repeat, and Ash's art matches itself best at 1.5 repeats. The 120–260 window is what selects 181. An automatic λ estimator therefore needs a model of which harmonic `repeatLam` refers to.
- **Other hand measurements of this drawing baked into the tool:**
  - `ASH_INK = {fill 29, outline 15, pageW 5100, band 309}` (km:2028), used by `--inkMatch` to pin `OUTLINE_RATIO = 15/29` and narrow `strands.thickness`;
  - `NL_ASH`, the nested-L geometry of the corner (km:1585);
  - traced centrelines of Ash's TL corner and top-L end. `trace-corner.cjs` builds them by 4-connected components → Zhang–Suen skeleton → longest path → tangent-rule linking across under-crossings (trace:40-130), plus **FORCE links read off the art by eye** (trace:5-9). They feed `--traceCorner`/`--traceEnd` (km:1618-1721);
  - the hairpin fold-zone constants (km:2157-2159) and `ZONE_K = 1.5` (km:1346);
  - engine tiles fitted to this art, `ash-contained` (corner) and `ash-hairpin` (end), which exist **only for plait4**. The engine's tile library is: corners `ash[plait4, plait3, twist]`, `ash-traced[plait4]`, `ash-contained[plait4]`, `mitre[plait4]`; ends `ash[plait4, plait3]`, `ash-hairpin[plait4]`, `loop[plait4, twist]`, `heart[plait4, twist]`;
  - design choices read off this art: `symmetry: 'mirror'`, `cornerColor: 1` (the TL outer L is pink), `endColor: 0`, and a pinned `endVariant`.
- **My feasibility probe for automatic measurement** (`T/autoest.cjs`, left run):
  - Fill width = 2 × the median distance-transform ridge of the colour classes = **7.66 px**, against the hand value 29/4 = 7.25 px (+6%). This one works.
  - The histogram of colour-edge normals peaks at 0°, 45°, 135° and 90°: diagonals at ±45° plus the axis-aligned bar ends.
  - **Colour runs per row across the band** have a histogram of {2: 12, 3: 42, 4: 81, 5: 144, 6: 138, 7: 144, 8: 77, …}. Counting them does **not** give N = 4: gaps at under-crossings and turns split strands.

### 1.5 What would generalise and what is hand-coded

| Step | Location | Generalises? |
|---|---|---|
| Rasterise an SVG with rsvg | km:397-411 | Yes, for any SVG. There is no path for raster (PNG/JPG) references. |
| refSvg rewriting | km:435-444 | **No.** It is tied to the comment/`symbol`/`var(--knot-c*)` dialect and to the 2550×3300 viewBox. |
| Fixed four-colour palette, nearest-RGB classification | km:164, 413-433 | **No.** It assumes known colours, exactly two strand colours, black ink and a flat ground. It also mis-classifies anti-aliased edges (1.3). |
| measureRef inset/band/breaks | km:448-465 | **Partly.** It works for any rectangular frame with one centred break on the top and bottom and none on the sides. It fails for other layouts. |
| Region boxes (side 0.3–0.7H, corner 3.2 band, end 3.6 band, cap) | km:466-491 | Proportional to the band, so they scale. The cap box and the choice of primary are hand-placed for this hairpin. |
| Period window 120–260 px | km:870 | **No** (it is in pixels). It is also harmonic-ambiguous (1.4). |
| ASH_INK, NL_ASH, traces, `--repeatPx 181` | km:2028, 1585; trace-corner; chain scripts | **No.** They are measured by hand on this drawing. |
| Metric v2, alignment, chamfer, jitter, period tolerance | km:590-910 | **Yes**, given any four-class map. |
| CMA-ES / polish / fit.cjs | km:2476-3101; fit | **Yes**, given a parameterisation. |
| Gates | km:1087-1922 | **Mostly yes.** They check *our* geometry, with thresholds in band units. |

---

## 2. The metric

### 2.1 Metric v2, exactly

For a region box r, a shift (dx, dy) and class maps R (Ash) and O (ours):

- **Joint histogram.** H[a][b] counts box pixels where R = a and O(x − dx, y − dy) = b. Ours outside the raster reads as ground. This is computed exactly with packed bit masks and popcounts (km:590-708).
- **conf** = 1 − Σ W[a][b]·H[a][b] / Σ_{(a,b)≠(0,0)} H[a][b] (km:763-765).
  - W = 1 for every mismatch (ground/ink/A/B), except **A↔B, which costs `AB_COST = 0.25`** (km:597-598).
  - Ground-on-ground pixels are excluded from the denominator, as in an IoU.
- **Colour mapping is fixed:** Ash's A must land on our A and his B on our B, with no per-region swap (comment km:591-595; `METRIC = 'v2'` km:596). This is the owner's "A→A1, B→B1" rule. The legacy metric allowed the swap (km:766).
- **Boundary chamfer.**
  - A boundary pixel is one whose right or lower neighbour has a *different class* (km:498-521). So ink|colour and A|B edges count as well as the silhouette.
  - A 3-4 chamfer distance transform (km:528-588) gives the symmetric mean distance between our boundaries and Ash's, at the chosen alignment.
  - Each direction is capped at one band (km:801-803), and the result is divided by the band to give `chamferBand`.
- **Region score** = **0.75·conf + 0.25·exp(−chamferBand / 0.05)** (km:806).
- **Alignment search** (km:774-791). Integer pixels only. The ranking passes use conf alone (`overlapConf`, km:715-745).

  | Pass | Stride | Side regions | Tile regions |
  |---|---|---|---|
  | Coarse | 4 | dy ∈ ±round(1.4·band) = ±104 px in steps of 3; dx ∈ ±3 in steps of 2 | dx, dy ∈ ±round(0.12·band) = ±9 px |
  | Middle | 2 | the 3 best: ±2 dy × ±1 dx around each | same |
  | Final | 1 | 3×3 around the best, with the full score | same |

  The side search spans more than a half-repeat, so phase along the run is free. The 1.4·band span was chosen for this period.
- **Period tolerance** (`--periodTol t`, side regions only; km:808-847). Our map is row-mapped and stretched about the box centre by s ∈ {1−t, 1−t/2, 1, 1+t/2, 1+t}, then s₀ ± t/4. The maximum is kept. With t = 0.04 that is seven scorings per side region.
- **Aggregation.**
  - Stage scores: the region mean, or `--primary` (the one target region) with an optional cap weight (km:987-997).
  - The joint score weights the sides 0.4 (0.2 each), the end 0.3 (split (1−cap) to top-L and cap to the cap region) and TL 0.3 (km:1008-1018). The chains used cap 0.3, so top-L carries 0.21 and the cap 0.09.
- **Optional smoothing of the objective:**
  - `--robust`: the mean over copies of the configuration with `band.width` moved by ±0.03 (km:849-863). `--robustPin` keeps the repeat fixed in pixels (km:855-859).
  - `--refJitter h`: the mean over the reference shifted by (i·h, j·h) px for i, j < 1/h. With h = 0.5 that is four phases (km:896-910).
- **Legacy v1** (rounds 1–11) was 0.35·mean fill IoU (A, B, swap allowed) + 0.25·ink IoU + 0.15·silhouette IoU + 0.25·the same chamfer term (km:806). The file header still documents v1 as "the" score (km:111-113). That text is stale.
- **Worked example** (my `verify.cjs`, [pre-edit]). The committed best's top-L has conf 0.8502 and chamferBand 0.0042, a mean boundary distance of 0.31 px. Score = 0.75 × 0.8502 + 0.25 × e^(−0.084) = 0.6377 + 0.2298 = 0.8675; the reported 0.8677 is the unrounded value.
  - The chamfer term is about 0.92 everywhere in the regime of interest.
  - Doubling the mean boundary distance to 0.62 px would cost about 0.018, so the chamfer term is not negligible.

### 2.2 The ceiling: Ash against his own mirror

- **The idea.** Ash's border is left-right mirror-symmetric as a *design*, but the halves are hand-drawn, so they disagree slightly. Mirroring his page and scoring it against the original measures his self-consistency. For example, his TR corner mirrored onto his TL. That gives a practical ceiling, not a theoretical maximum.
- **Re-measured** (`T/ceiling.cjs`, nominal, 1×):

  | Region | Mirror score | conf | chamferBand |
  |---|---|---|---|
  | left | 0.8833 | 0.867 | 0.0036 |
  | right | 0.8876 | 0.870 | |
  | TL | 0.9034 | 0.889 | |
  | top-L | 0.9229 | 0.912 | 0.0022 |
  | cap | 0.9182 | | |

  The right side's best alignment is a half-repeat (91 px) shift.
- **A floor.** Ash against his own 180° rotation scores 0.47 (left), 0.48 (right), 0.49 (TL), 0.37 (top-L) and 0.22 (cap). That is roughly what a correct-looking braid with the wrong chirality or phase earns.
- **How the ceiling depends on the scoring choices** (S/expt2/q1.json; review-2):

  | Mirror ceiling | TL | top-L | left |
  |---|---|---|---|
  | 1×, 16-phase mean | 0.897 ± 0.024 | 0.904 ± 0.028 | 0.903 ± 0.015 |
  | 2× | 0.93 | 0.94 | 0.93 |
  | Sub-pixel alignment | about +0.035 | about +0.035 | about +0.035 |
  | Coverage-aware classifier | +0.024 | +0.014 | +0.026 |

  - The mirror's nominal left score (0.883) sits *below* its own phase mean, because Ash's halves are not pixel-registered.
  - Any change to the metric moves the ceiling more than it moves us. The first review therefore recommended **gap closure**, (score − baseline)/(ceiling − baseline), as a headline that does not depend on the classifier (S/expt/review.md Q5).

### 2.3 Sub-pixel phase and the winner's curse

- **The cause.** The class map is thresholded and alignment is integer-only, so a design's score moves with its sub-pixel phase against Ash's raster.
- **The size.** At 1× the standard deviation over 16 quarter-pixel phases is ±0.011–0.014 for our designs and ±0.024–0.028 for the mirror (q1.json).
- **The curse.** A search that maximises the *nominal* (phase 0,0) score selects phase-lucky designs. In outside review 2, the V13 incumbent "e2" had its nominal TL, top-L and left **each equal to the maximum** of the 16 phases, about +0.02 above its phase mean (review-2 Q1). This is why V12 and V13 gained under 0.01 over two cycles: their CMA-ES and polish runs were partly fitting the pixel grid.
- **The response.**
  - `--refJitter` (V13) and fit.cjs optimise the 4-phase mean (km:896-910; fit:15-17, 50-52).
  - Selection still includes phase (0,0) as one of the four, and the score is still *reported* at nominal.
- **The committed design** (S/expt2/q1-fitboth.json):

  | Region | 1× nominal | 1× 16-phase mean ± sd | 1× max | 2× nominal | 2× mean |
  |---|---|---|---|---|---|
  | TL | 0.8667 | 0.8578 ± 0.011 | 0.8737 | 0.8731 | 0.8665 |
  | top-L | **0.8677** | 0.8399 ± 0.014 | **0.8677** | 0.8699 | 0.8608 |
  | left | **0.8558** | 0.8427 ± 0.011 | **0.8558** | 0.8658 | 0.8535 |

  - The review's statement that the fitted tiles are "not at the phase max" holds for **TL only**. The top-L and left nominals are still the 16-phase maxima. The left value is inherited from e2, because fit.cjs does not touch the sides.
  - Under the tool's own 4-phase jitter mean (my `verify.cjs`, [pre-edit]): joint 0.8528; left **0.8505**, right **0.8499**, top-L 0.8555, cap 0.8398, TL 0.8582.
  - So the claim that **all three exceed 0.85** holds at 1× nominal. It holds at 2× on the phase mean. It does **not** hold at 1× on the 16-phase mean, where the sides and top-L fall short. Any new target should name which convention it uses.

### 2.4 Strengths

- **Exact and deterministic.** Integer counts, bit-packed. My repeated runs reproduce to 5 decimals with persistent and fresh engine contexts (`T/determ.cjs`). A fresh-context re-score and a pool audit back this up (km:2358-2396, 2829-2848).
- **Penalises the right things in the right proportion for flat line art.** Ink placement (56% of the art) dominates. Colour order matters, so colour swaps are caught: the cornerColor fix was worth +0.065 at TL. A colour slip costs only a quarter as much as geometry.
- **Tolerant where hand art varies.** It ignores where the run phase lands (the ±1.4-band search) and the period rounding (±4%), but still sees shape.
- **Fast.** About 2–9 ms per region at stride 1 after the perf work (bench phases, Section 3.1).
- **Region-resolved** (and zone-resolved: tile against legs, km:1346-1369). That makes failures attributable.

### 2.5 Blind spots

1. **No reward for curvature smoothness ("fluid").**
   - The pixel metric is flat for sub-pixel wiggles. A 1-px bump moves a few dozen pixels by one class step, and those moves can just as easily *help* if they track pixel-grid noise in the reference.
   - My measurement (`T/curv.cjs`): tile centrelines resampled at 0.01 band, curvature from ±3-point turning angles, E3 = ∫(dκ/ds)² ds, inflections = curvature sign changes beyond |κ| > 1/band.

     | Design | Σ E3 | Inflections (4 corner + 2 end paths) | Score (nominal TL / top-L) |
     |---|---|---|---|
     | e2 (V13 base) | 373,373 | 32 | 0.843 / 0.8395 |
     | fit-both (committed) | **589,125 (+58%)** | **121** | 0.867 / 0.868 |
     | SMOOTH 0.05, warm-started from fit-both | 496,992 | 121 | 0.868 / 0.868 (post-edit) |
     | SMOOTH 0.2, warm-started from fit-both | 427,589 | 116 | 0.866 / 0.868 (post-edit) |
     | fit at h = 0.30 (coarser knots) | 393,673 | 46 | 0.859 / 0.853 |

     - The fit bought +0.024 / +0.028 with nearly 4× the inflections.
     - The SMOOTH runs in this session (`/private/tmp/claude-501/-Users-averykrouse-GitHub-ORK-tobias-ORK3-tobias/d582c881-63eb-4331-acce-d387afe6d0c7/scratchpad/smooth/*.log`) cut the knot roughness Σ(Δ²d)² from 0.185 to 0.024 (corner) and from 0.115 to 0.022 (end). They lost only 0.0008 (corner) and 0.0022 (end) of 4-phase score. **The metric gives the wiggle almost no value.**
     - Yet the inflections barely moved. A penalty on knot second differences flattens knot-to-knot zigzag, but any non-constant raised-cosine displacement at h = 0.15 band still bends the curve at that scale.
     - A coarser basis (h = 0.30) is the only variant that stayed close to the base's fairness.
   - **Gates do not catch this either.**
     - The kink gate needs more than 35° at a single vertex (km:1098, 1120-1125).
     - The wrapDent count went from 2 to 11 on fit-both and was accepted, because the wrap's hull depth grew only 0.0071 band, under `--wrapDentTol 0.012` (km:1915; review-2 gate table).
   - Part of the visible bumpiness is the **fill painter**. This session's comparison sheet (`.../scratchpad/smooth/sheet-side.png`, fill painter against stroke painter on the sides, where no tile is fitted) shows scalloped arcs from the fill painter only. The concurrent engine edit (`offsetOutline`, eng:3293+) says why: offsetting the two sides of an asymmetric outline separately flips the outer side with sample noise.
2. **Topology is cheap.**
   - My estimate, not a measurement: one crossing with the wrong over/under in the committed design (fill ≈ 7.4 px, outline ≈ 3.9 px per side, gap ≈ 4 px) changes about 200–300 px of ink, gap and colour in a TL union of about 15,000 px (`tilePx + legPx = 14,958`).
   - That is Δconf ≈ 0.015–0.02, so Δscore ≈ 0.01: about one sd of phase noise.
   - A *global* chirality flip is obvious (0.78 → 0.44 when `endVariant` was unpinned, km:130-131). A single wrong crossing is not reliably visible. Hence the `altBreaks` gate.
3. **Unscored positions.** Only TL and top-L are targets. Visual review 5 found the joint page's *bottom* runs stretched into loose diagonals that no region saw (S/vr/visual-review-5.md). Hence the run-stretch gate (V10).
4. **The anti-aliasing fringe** (1.3). It biases everyone equally but injects phase noise.
5. **Piecewise-flat objective.**
   - Below about 0.5 px the score is a step function.
   - Finite differences need δ ≥ 0.008 band (0.6 px), and gradient methods do not pay off without a coverage-based or signed-distance-smoothed objective (review-2 Q3).
6. **Alignment slack hides placement.**
   - A tile up to 9 px (0.12 band) off is re-aligned for free inside its box, and the sides re-phase by up to 1.4 band.
   - This is intended (shape, not position), but absolute placement is unscored. On the joint page it is constrained only through the shared lattice.
7. **Area weighting.**
   - Thin structures (a 1-px outline offset along a long edge) and large fills get equal weight per pixel.
   - Box composition decides the score: 60–80% of the TL box is legs (S/expt/review.md Q1). After the fit, the remaining loss is mostly thin yellow ink↔colour inner-edge offsets, which point to a *width* error (review-2 Q5.4).

### 2.6 What a perceptual metric for "fluid and smooth" would add (Proposal)

These terms would sit beside metric v2, either as gates or as small weighted terms, so ledger continuity is kept.

- **Fairness relative to the reference.**
  - Extract centrelines from both images: our engine's polylines, and a coverage-aware skeleton of the reference after linking (trace-corner's method, generalised).
  - Compare the curvature *distribution* along each strand: inflections per band of arc length, ∫(dκ/ds)², and the peak |κ| at turns.
  - Penalise only the excess over the reference, so designed square corners stay allowed.
  - This would have scored fit-both's 121 inflections against e2's 32 (and Ash's, once measured), and would have ranked the h = 0.30 fit, or a curvature-penalised fit, above it.
- **Fairness prior inside the fit.**
  - Penalise ∫(dκ/ds)² of the *rendered* displaced centreline, not Σ(Δ²d)², or use a B-spline basis with fewer knots.
  - Accept a knot move only if it improves score per unit of added bending energy.
- **Outline-tangent smoothness.**
  - On sub-pixel contours (marching squares on the coverage map), take the variance of the tangent-angle derivative along each ink/colour boundary.
  - This catches painter scallops, which centreline fairness cannot see.
- **Width-profile match.** Compare the distance-transform width along each skeleton in both images (Ash's arcs taper, his bars do not). It targets the post-fit residual directly (2.5.7) and is the measurement that a per-knot width channel would fit to.
- **Signed-distance or coverage comparison** per class instead of thresholded classes. This makes the objective continuous in sub-pixel geometry, so the jitter averaging is no longer needed and gradients become possible.
- **A topology graph check.** The crossing graph (strands, crossings, over/under sequence, number of closed loops, colour per strand) is extracted from both images and compared exactly. It is a gate, not a score.
- **Multi-scale or structure-aware similarity** (MS-SSIM on per-class coverage; orientation-field agreement from structure tensors at band scale). These would be secondary checks. Learned perceptual metrics such as LPIPS are untested on flat two-colour line art, so I would not use them as the main objective.

---

## 3. Optimisers

### 3.1 The evaluation pipeline and its cost

- **One candidate:**
  1. `decode(stage, base, x)` maps a box-normalised vector to a configuration plus tile and constant overrides (km:2233-2302).
  2. The engine runs in a `vm` context. Overrides are applied by regex on constants and by GEN-block replacement for end tiles (km:228-266). With `--persist`, one warm context per worker gives byte-identical output (km:262-342).
  3. The page is rendered, rasterised inside the boxes, classified and scored per region.
- **The worker pool** (km:2358-2396) checks every result against a hash of its job. Every 50th job is also re-scored in a fresh context, with a third score to decide on a mismatch.
- **Every scoring process runs with `--no-maglev`** (km:145-158). Without it, a V8 miscompile returned one region's score for another in 0.3–1% of results under load, which inflated end10's best to 0.6197 (true 0.5928).
- **Every would-be best is re-scored in a fresh context** before it can be accepted (`verify`, km:2829-2848).
- **The standing benchmark** (bench.cjs; S/perf/bench.jsonl, 64 rows). Single-thread milliseconds per candidate (CPU time for H0+), split by phase, and pool(4) throughput. Robust stages render 3 copies per candidate; the joint stage renders 1:

  | Build | Stage | ms/candidate | render | raster | align | chamfer | pool(4) candidates/s |
  |---|---|---|---|---|---|---|---|
  | baseline-v4 (rsvg) | weave | 390 | 114 | 163 | 95 | 12 | 9.1 |
  | | corner | 255 | 98 | 127 | 24 | 6 | 15.2 |
  | | end | 259 | 116 | 121 | 17 | 4 | 15.5 |
  | E1 bindGlobals (+JS raster) | weave / corner / end | 168 / 87 / 71 | 35 / 37 / 34 | | | | 16.7 / 31.0 / 31.5 |
  | H1 perf3-exact | weave | 71 | 16 | 39 | 9 | 6 | 30.5 |
  | | corner | 57 | 30 | 19 | 2.5 | 3 | 30.8 |
  | | end | 45 | 27 | 11 | 2 | 2 | 38.1 |
  | | joint | 68 | 11 | 22 | 18 | 16 | 23.0 |
  | H2 js:7 (approximate raster) | weave / corner / end / joint | 58 / 37 / 30 / 55 | | | | | 38 / 67 / 61 / 45 |

  - The gate (`validate`, full four-position check) costs 36–330 ms and runs only on would-be bests.
- **My wall-clock check** on the committed joint best (one process, load ≈ 3.7): 190 ms per nominal joint score with the JS raster (periodTol 0.04, so 7 stretches per side region), 227–239 ms with rsvg, and 350 ms with `--refJitter 0.5`.

### 3.2 CMA-ES with local/swing/scatter restarts

- **Parameter vector.** A box-normalised x ∈ [0,1]^n per stage (spaces at km:1979-2131). Size by round, from the logs' "(n params, CMA-ES pop λ)" lines:

  | Stage | n by round | What is in it |
  |---|---|---|
  | weave | 8 (R3–R9) → 10–11 (R10–R13) → 12 (R14, `tipExt`) → 14 (R15, `slant`) → 20 (R16+, fill painter) | `WEAVE_SPACE` (km:1979-1990): `band.width`/`inset`, `strands.thickness`, `angular`, `bow`, `scale`, `OUTLINE_RATIO`, `GAP_RATIO`, `cutCurl`/`Len`, `edgeBend` |
  | corner | 26 (R3–R5) → 44–45 (R6–R12) → 47–57 (R13–R16) → 70 (R17) | `ctp.phase`/`lam`/`phaseIn`; per path 6 normal modes with amplitude 0.14/(k+1) (`MODES`, `AMP`, km:1991; `displace` km:1928-1944); a 3×3×2 cosine warp (`WMODES`, km:1996-2017); plus squaring, nested-L, trace, slant, fill, leg-weave and width-field keys as the versions add them |
  | end | 23 → 39 → 48–50 → 55–64 → 73 | break width and position, `etp.lam`; wrap 4 modes, hairpin 10; fold controls `hp.*` (5) and bumps `hb.*` (8) (km:2157-2192); `wq`, `tf`, `endBlend`, `ex`, … |
  | joint | 22 (R11) → 38 (R16) → 50 (R18) | weave keys plus placement keys only: `brk.`, `etp.`, `hp.`, `ex.`, `ctp.`, `csq.`, `wq.`, `tf.`, `tc.`, `endBlend`, `endSlide`, `repeatLam`, `fillField` (km:2076-2088). Tile shape modes only with `--jointTiles`. |

- **Objective:** −score plus a quadratic penalty for leaving the box (km:2789). Evaluations are clipped to the box.
- **Algorithm:**
  - Standard (μ/μ_w, λ)-CMA-ES with Hansen's defaults and a Jacobi eigendecomposition every generation (km:2476-2538). σ is clamped to [1e-4, 0.6] (km:2530).
  - λ₀ = max(pop, 4 + ⌊3 ln n⌋) (km:2743). σ₀ defaults to 0.03 (km:2879); it was 0.15 through round 5.
  - **Restarts** cycle initial → local (from the best, population doubled: IPOP) → swing (3σ) → scatter (km:2974-2990). Scatter starts from seeds: other tiles in the engine with the same topology, the tile at phase +⅓ or +⅔, breaks ±2, or the best of 2λ random scouts (km:2555-2578, 2981-2987).
  - **Stop rule within a run:** a one-sided Welch test of the pooled top-μ scores of the last 5 generations against the 5 before (p < 0.05), or a best-score gain of at least `MIN_GAIN` = 0.005 in 5 generations (km:3022-3033). The minimum run length is 10 + 30n/λ generations (Hansen's stagnation horizon); swing and scatter get a third of it (km:2896, 3044, 3050).
  - **Global stop:** 3 consecutive restarts that each add less than 0.005 (km:3081).
- **Add-ons:**
  - `--race` (V4) renders the robust copies only for candidates that a regression bound says can still reach the top μ. CMA-ES takes identical steps (km:2762-2820).
  - `--probation` ends swing and scatter runs that are not closing on the incumbent (km:3056-3069).
  - `--multiStart K:G`, and `--legFirst` (a sub-CMA over leg-phase keys only, km:2540-2550).
- **Where it stalled, and why:**
  - **Search width (R5).** At σ₀ 0.15 every stage was flat. Round 6's σ₀ 0.03 ("the optimum is a ridge, not a basin", commit 742f54b2b) gave the weave +0.032 (0.751 → 0.783).
  - **The ridge (R12–R14, corner).**
    - Outside review 1 probed the corner landscape: random steps of σ 0.003 average −0.001 (best +0.008), while σ 0.03 average −0.18.
    - The population mean sat 0.13–0.18 below the best, and σ *grew* from 0.028 to 0.041 through the "kick".
    - corner13 and corner14 spent 7,562 candidates (17,098 renders) for +0.0000 (summary.json; S/expt/review.md Q4).
  - **Representation (weave, R12–R14).**
    - The weave sat at a true local maximum next to discrete cliffs: 0.839 → 0.555 for a 0.006 step, from repeat re-rounding and end-variant flips.
    - Re-drawing Ash's *own* centrelines with constant-width strokes scores only about 0.85 (expt Q2).
    - The stall broke only when the painter gained capacity: V9 slanted cuts, V10 fill painter.
  - **Discrete toggles (end).** The score flickers 0.72 ↔ 0.59 at 0.002 steps, and end14 had 17 wrapDent rejections.
  - **Few modes (V12–V13, joint page).**
    - TL and top-L on the joint page were flat at about 0.843 / 0.836–0.8395 (±0.003) for two cycles.
    - Six global sine modes per path and a 3×3 warp cannot express 1–2 px *local* outline moves.
    - The nominal objective was phase-lucky (2.3).

### 3.3 The polish phase (V9–V10)

- **Algorithm:** an elitist (1+λ)-ES with the 1/5th success rule (km:2940-2972).
  - λ = the number of workers. σ starts at 0.003, multiplies by 1.5 on a success and by 1.5^(−λ/4) on a failure, and is clamped to [2e-4, 0.03] (km:2549, 2962).
  - It stops after 40 evaluations without a success at the σ floor.
  - `--polishSparse 0.1` moves about 10% of the dimensions per child (km:2948). `--polishParents K` polishes the K best distinct candidates of a run (km:2919-2928).
- **Effect.**
  - The outside-review prototype took corner TL from 0.7307 to **0.7501** in 80 evaluations (S/expt/review.md Q4).
  - Adopted in V9, it helped the corner gain +0.075 over that cycle (ledger).
  - It too sat on pixel-luck spikes until V13: `--refJitter` plus a nominal pass took v12-best's top-L from 0.8356 to 0.8395 (km:92-99).

### 3.4 Stage pages against the joint page (and `--carryTiles`)

- **Each stage scores a full page rendered from its own configuration.** The weave stage draws woven corners. The corner stage originally used a separate corner engine. The end stage uses the end engine.
- **The stages are mutually incompatible:**
  - the end tile scored 0.514 under the weave's settings (km:998-1001);
  - the corner13 page scores **0.47** on the sides, and the weave14 page scores **0.39** on TL (S/expt/review.md Q1).
- **The joint stage** (V5, single engine from V6) scores one configuration on the sides, top-L, cap and TL in one render (km:1031-1061).
- **The compression lesson (V11).**
  - The corner stage's page compresses its far runs to a repeat of 168/188 px, against Ash's 179/181 (ledger V11 row).
  - Tile pins fitted there misplace the top run on the joint page. corner16's tile on joint16 scored TL 0.776, with `ctp.lam` 2.46 against the page's 2.33.
  - `--carryTiles` (km:2279-2282) runs the corner or end stage *on the joint page itself*: the `--init` best's other tile rides along unchanged, and `--only` restricts the search to the tile's own keys. That refit gave TL 0.838, and joint 0.8093 → 0.8289 after a joint pass (km:73-79).
- **Joint-page refits use `--robust off`.** The band.width −0.03 copy re-rounds the run and moves the top end by 0.25 repeat (km:90-91).
- **`--hold` (V12)** keeps each held region's nominal score at or above min(floor, baseline) − 0.003, so tiles can be refit without trading away the sides (km:1860-1886, 1909).

### 3.5 fit.cjs: per-point tile centreline descent

- **Parameters** (fit:21-29, 35-43).
  - For each path of one tile (the end tile's wrap and hairpin, or the corner tile's four polylines), knots are spaced every h band of arc length (default h = 0.15 band ≈ 11.6 raster px).
  - Each point is displaced along the *base* path's normal by Σ d_k·½(1 + cos πx) over its two neighbouring knots, a raised-cosine partition of unity.
  - The end knots are pinned (d₀ = d_K = 0), so the ports and their G1 joins to the live braid stay put.
  - Counts: end 28 + 23 knots (47 free); corner 28 + 25 + 20 + 29 knots (94 free).
- **Objective** (fit:44-53).
  - The target region's metric-v2 score (top-L for the end, TL for the corner), averaged over Ash rasterised at 4 phases: (0,0), (½,0), (0,½), (½,½) px (fit:15-17).
  - The cap is reported but not targeted; it lies inside the top-L box.
  - **SMOOTH = λ** (this session, uncommitted) subtracts λ·Σ_k(d_{k−1} − 2d_k + d_{k+1})² (fit:9-12, 34, 52). **INIT** warm-starts d from an earlier fit (fit:30-33).
  - Everything else is fixed: the configuration, the other tile, the sides.
- **Search** (fit:56-67). Coordinate descent with δ = 0.03 → 0.015 → 0.008 band (2.3 → 0.6 raster px).
  - For each knot, try +δ, then −δ. Accept the first that improves the objective by more than 1e-5.
  - Sweep until a sweep accepts nothing, or until maxSweeps (default 3; the committed runs used 4).
  - **No gate during the search.** The result is gated afterwards (S/expt2/gate.cjs).
  - It runs on one process with a persistent engine and the JS raster cropped to the target box (fit:46-47).
- **Rates and results** (S/expt2/fit-*.log; review-2 Q2):

  | Run | Renders | Wall (s) | Renders/s | Nominal | 4-phase | Notes |
  |---|---|---|---|---|---|---|
  | end, h = 0.15 | 1,083 | 186 | 5.8 | top-L 0.8395 → **0.8677** | 0.827 → 0.856 | cap 0.802 → 0.856; tile zone 0.780 → 0.847 |
  | corner, h = 0.15 | 2,011 | 303 | 6.6 | TL 0.8429 → **0.8665** | 0.822 → 0.858 | legs 0.813 → 0.849 |
  | end, h = 0.30 | 481 | 74 | 6.5 | 0.8532 | 0.847 | smoother |
  | corner, h = 0.30 | 853 | 122 | 7.0 | 0.8587 | 0.852 | |
  | SMOOTH 0.2 end (warm) | 1,105 | 225 | 4.9 | 0.8677 → 0.8679 | 0.8555 → 0.8533 | knot roughness 0.115 → 0.022 |
  | SMOOTH 0.2 corner (warm) | 2,231 | 358 | 6.2 | 0.8665 → 0.8661 | 0.8582 → 0.8574 | knot roughness 0.185 → 0.024 |

  The machine was loaded (load average about 11) during the h = 0.15 runs.
- **Why it worked where CMA-ES stalled:**
  - Each knot has local support (about 2h of arc, a few hundred pixels), so the objective is nearly separable at that scale. Coordinate descent exploits this; a covariance-learning method over 100 dimensions has to discover it.
  - δ = 0.6–2.3 px sits above the quantisation flatness.
  - The 4-phase mean blunts pixel luck.
  - Review-2 puts the rate at about +0.3/hour while in the basin, against under +0.01 per cycle for V12–V13.
- **Where it saturates.**
  - After about 2,000 renders, the last sweeps accept 0–2 moves.
  - The residual is mainly ink↔colour inner-edge offsets, i.e. width. The engine has only global thickness plus a low-order 3×3 `fillField` per tile (km:2061-2067).
  - Review-2's next lever is a per-knot width offset in the same descent (not run).
  - The per-point fit also leaves the fairness debt measured in 2.5.1.
- **Committed state, and a caveat about it.**
  - `results/2026-11-08-joint-best.json` is `S/expt2/fit-both.json`: e2's configuration with the two fitted tiles, plus `expt2` metadata.
  - Its top-level `stage`, `score`, `regions` and `diag` fields are **stale, copied from e2** (`stage: 'end'`, score 0.8206, top-L 0.8395, wrapDent 2).
  - Running `knotmatch show` on it would therefore score *end-stage* regions, not the joint page.
  - The real numbers come from scoring it as a joint job, as gate.cjs and my verify.cjs do: joint 0.8611 [pre-edit] (0.8609 post-edit).
  - The fit also started from e2, not from the round-19 best `jend19` (top-L 0.8472). Review-2's "run again from chain19's output" was not done.

### 3.6 Summary table

| Optimiser | Vector | Objective | Throughput (measured) | Stalled because |
|---|---|---|---|---|
| CMA-ES, weave stage | 8–20 weave keys | mean of left/right; robust ±0.03, periodTol 0.04, repeatPx 181 | R16: 6.8 candidates/s (≈20 renders/s; 2 workers, 4 jobs concurrent); bench H1 30.5/s pool(4) | true local max next to discrete cliffs; the constant-width painter caps at ≈0.85 |
| CMA-ES, corner stage | 26–70 | TL (robust) | R15/R16: 23.2 / 10.9 candidates/s | narrow ridge, σ 10× too wide; stage page compression |
| CMA-ES, end stage | 23–73 | top-L + cap 0.5 (robust) | R15/R16: 21.6 / 13.6 candidates/s | discrete toggles; wrapDent rejections |
| CMA-ES, joint | 22–50 | weighted 5 regions (nominal) | R15/R16: 15.7 / 9.2 candidates/s; bench 23/s | placement keys only; nominal = phase-lucky |
| (1+λ) polish | same as stage | same (or refJitter mean) | runs at the stage rate; 80–600 evaluations per pass | σ floor 2e-4; few modes cannot express local moves |
| CMA-ES / polish with refJitter (R19) | 51–58 tile keys on the joint page (`--only`) | 4-phase mean | jend19j 11.9/s; jcorner19j 12.6/s | still few modes: +0.008–0.012 top-L, TL traded down |
| fit.cjs coordinate descent | 47 (end) / 94 (corner) knot offsets | 4-phase mean of one region (− SMOOTH·roughness) | 5–7 renders/s on one process | saturates near 2,000 renders; width residual; wiggle not penalised |

---

## 4. Gates and quality checks

**How the gate works.**

- When a candidate is about to become the best, it is re-scored in a fresh context, then re-rendered and checked (`accept`, km:2864-2874).
- `gateFails` (km:1898-1922) rejects it if **any count is worse than the run's baseline**, plus a tolerance where one is defined. A run can therefore never trade correctness for score.
- The checks are relative: a baseline that already has 2 kinks permits 2.
- Absolute exceptions: `endFallback` always, and run-stretch on the joint and weave pages (km:1902-1907).
- Joint pages are validated as three sub-pages, with keys prefixed `side:`, `end:` and `corner:` (km:1062-1076).
- With `symmetry: 'mirror'`, only the drawn left positions are checked geometrically (km:1397-1400).
- **The population is never gated.** CMA-ES sees raw scores. A gated-out would-be best is ranked last for the update (km:3010-3014).

| Check | What it detects | How (threshold) | Where |
|---|---|---|---|
| **kinks** | broken G1 joins | polyline vertices turning > 35° between segments ≥ 0.01 band, inside a position window | km:1098, 1120-1125 |
| **outside** | centreline leaving the band | points outside the outer frame or inside the inner frame by more than 0.03 band | km:1116-1119 |
| **altBreaks** | over/under not alternating | consecutive crossings along a strand, both in one window and < 2 band apart, with the same over state. Self-crossings count; tangent fusions (crossing-angle sine < 0.25) are skipped. | km:1128-1150 |
| **flecks** (raster) | colour crumbs | 4-connected A/B components with 6 ≤ area < 0.35·wf² px not touching the window edge (wf = band/4 × thickness). **Diagnostic since V7**: it swung 4–13 with sub-pixel changes and was never near a short run (km:1818-1826). `--fleckGate raster` brings it back with `--fleckTol 2`. | km:1233-1254, 1402 |
| **fleckRuns** | a dot of colour boxed in ink | engine cut runs whose painted fill length (minus ink at cut ends) < 1 strand width; exact, from the engine's `cutRuns` | km:1827-1858 |
| **hpX** | hairpin not crossing itself exactly once | \|self-crossings − 1\| of the `hairpin` path, in tile units | km:1441-1465 |
| **hpSlit** | the slit between the fold's legs fusing | two stretches more than 3 wf apart along the path, away from the crossing, closer than wf | km:1455-1464 |
| **wrapDent** | a dent in the end's outer C | curvature sign changes beyond ±0.5 on the wrap (U < 1.0), resampled at 0.02. With `--wrapDentTol d`, a new change counts only if the C's hull depth grew by more than d band (0.012 ≈ 1 px; the count rule fired on sub-pixel ripples) | km:1472-1507, 1887-1897, 1915 |
| **inkOut** | corner ink past the outer frame | centreline ± half the inked width beyond the frame by more than 0.5 px | km:1748-1759 |
| **portGap** | tile ends meeting the live braid badly | tile path ends more than 0.03 band from their braid port before the G1 snap; `--portGapTol n` | km:1747, 1760-1764, 1912 |
| **curlOut / curlX / curlKink** | painted curled cut ends misbehaving | rebuilt from the engine's own cut/curl pieces | km:1770-1816 |
| **endFallback** | the designed end tile silently not drawn (fold caps) | render the same configuration with `ends: 'fold'`; an identical SVG means no tile. Absolute. Caught the invalid V7 joint (joint13) | km:1416-1423 |
| **runStretch** (V10) | a run stretched or unwoven anywhere on the page | the engine's crossings projected onto the spine; per lateral lane, each crossing spacing against the page median, outside 1.6 band of corners and 1.2 band of breaks; plus 'sparse' runs and the engine's own warp pieces. tol 0.08; absolute on joint/weave | km:1156-1231, 1902-1907 |
| **hold** (V12) | trading a held region's score for another | nominal score ≥ min(floor, baseline) − 0.003, at period tolerance 0.04 | km:1860-1886, 1909 |
| alike (diagnostic) | how alike the four positions are | ink/fill agreement of the primary against each other position, under the best of 8 symmetries, ±2 px | km:1256-1311 |
| zones (diagnostic) | tile against leg errors | conf inside 1.5 band of the corner or break against the rest | km:1346-1369 |

**Score-side safeguards** (not gates):

- **Period tolerance (`--periodTol`).** It makes the side score indifferent to the ±1/(2n) period rounding that fitting whole repeats between end tiles causes (about 3% here). Ash against his mirror is unchanged by it (km:119-121).
- **Robust configs (`--robust band.width:-0.03,0,0.03`).** A design that scores at one exact value only is "a lucky discrete state" (repeat rounding, tile variant, over/under parity). `--robustPin` keeps the repeat in pixels (km:849-863). The race skips copies that cannot matter (km:2762-2820).
- **refJitter** (2.3), **verify** (fresh-context re-score) and the **pool audit** (3.1).

**What the gates miss:**

- low-amplitude wiggle: the kink threshold is per vertex, and the wrapDent tolerance is set by hull depth;
- painter scalloping;
- wrong colour order at non-primary positions (alike is diagnostic);
- any over/under error where a self-crossing or tangent fusion is excluded;
- topology at the four positions beyond what `altBreaks` sees in its windows.

**Proposal:** promote a curvature-excess check and the topology graph comparison (2.6) to gates.

---

## 5. Pipeline for an arbitrary reference

### 5.1 What the current tool needs from a reference (facts)

To score another drawing today, it must be:

1. An SVG in Ash's dialect: a leading comment; `symbol`s with ids `Knot-Band-1` and `Knot-Band-2`; colour fills written as `var(--knot-c1)`/`var(--knot-c2)`; black outlines; viewBox 2550×3300, since refSvg hard-codes it (km:435-444).
2. On the same page aspect as the engine page (816×1056), since boxes are shared (1.1).
3. A rectangular, axis-aligned border with equal insets, one break centred on the top edge and one on the bottom, and none on the sides (km:448-465).
4. Two strand colours plus black ink on a flat ground. The palette is fixed and *assigned* (km:164, 440).
5. A pattern and family the engine has tiles for. Fitted tiles exist only for plait4 (`ash-contained`, `ash-hairpin`). plait3 has only the generic `ash` corner and end. Twist has `ash`, `loop` and `heart`.
6. Hand inputs re-measured for the new drawing: `--repeatPx` (by `period`, with its 120–260 px window), `ASH_INK` for `--inkMatch`, `NL_ASH`, traces with FORCE links, the cap box, and the primary positions.

### 5.2 A step-by-step pipeline (Proposal, with the existing parts it reuses)

**Step 1: Ingest (new).**
- Accept SVG, PNG or JPG.
- Rasterise SVGs as now. Resample rasters to a working scale where the band is about 70–80 px (the regime every constant was tuned in).
- Record the page aspect. Render ours at the same aspect, or crop both to the border's bounding box and score in band-normalised coordinates.

**Step 2: Colour model (new; replaces km:164 and km:413-433).**
- Cluster pixels in Lab space (k-means or a Gaussian mixture, choosing k by BIC, with k ≥ 3).
- Ground = the largest cluster touching the page border. Ink = the darkest cluster. The rest are strand colours; a cluster under 1% of the ink area is a highlight or noise.
- Then **unmix anti-aliasing**: project each pixel onto the nearest mixing line between cluster centres and split at ½ (the q4.cjs rule, generalised to k colours). Without this, widths cannot be measured (1.3).
- Output a class map with N_colours ≥ 1.
- The metric's W matrix generalises: every mismatch costs 1, colour↔colour costs AB_COST.
- Also detect hatched or gradient fills by within-cluster variance. Those need a different class model, out of scope for flat art.

**Step 3: Frame and layout (generalises km:448-491).**
- Build the non-ground mask, close it morphologically at about 0.5 × the expected strand width, and take its largest component's outline.
- For page borders: fit the outer and inner contours (rectangle, rounded rectangle or general closed curve) and take the **medial axis** of the band as the spine.
- **Breaks** are spine stretches where the band mask is empty for more than about 1 band. **Corners** are spine points of high turning. **Ends** are spine endpoints at breaks.
- Detect symmetry by scoring the image against its mirror and its 180° rotation with metric v2. For Ash: mirror 0.88–0.92 against rotation 0.22–0.49 (2.2), so `symmetry: 'mirror'` follows. This reuses `regionScore` unchanged.

**Step 4: Unroll the band (new).**
- Sample the class map along spine normals into a straightened strip image (s along the band, v across it) for each straight run, excluding about 1.6 band at corners and 1.2 band at breaks (the run-stretch gate's exclusion zones, km:1156).
- Every remaining measurement is 1-D or 2-D on this strip, so it is independent of layout.

**Step 5: Weave parameters from the strip (new). This is the core of "replicate any reference".**
- **Band width and inset:** the extent of the strip's ink, plus the frame offsets from Step 3. Convert to the engine's `band.width`/`inset` percentages of min(W, H) (eng:140-142).
- **Period λ:** autocorrelation or FFT along s of the ink, fill and colour-exact channels.
  - The harmonic must be resolved with a model. On Ash, all three channels peak at 272 > 363 > 91 > 181 px (1.4), and the engine's repeat is 181.
  - Rule: λ is the smallest lag L such that the colour-exact peak at L, 2L and so on is within x% of the global maximum, *and* the crossing count per L matches the pattern model. A plait of N strands has a fixed number of crossings per repeat.
  - Allow ±4% drift along the run (hand art): use the period tolerance, or fit a slowly varying λ(s).
- **Crossings and strands:**
  - Skeletonise each colour class, link pieces across under-crossing gaps by the tangent rule, and use the "gap never crosses open ground" test. This is trace-corner.cjs's method (trace:40-130), generalised to the strip and without FORCE links.
  - Count the distinct linked strands that cross a transverse line to get **N** (colour runs per row do *not* work: 1.4), along with the colour per strand and the colour cycle.
  - The over/under sequence along each strand gives the pattern class (plait, twist, chain, …) and the alternation, to be checked against what the engine generates.
- **Widths:**
  - fill width = 2 × the median distance-transform ridge of the colour classes (7.66 px against a hand value of 7.25 on Ash);
  - outline = ink-ring thickness along skeleton normals, on the *coverage-aware* map;
  - gap = the cut length of the under strand at crossings, minus the over strand's inked width.
  - These give `strands.thickness` = N × fill / band (km:2068-2073 uses this for N = 4), `OUTLINE_RATIO` = outline / fill, and `GAP_RATIO`.
- **Waveform:** least-squares fit of the engine's waveform (`angular`, `bow`, `scale`, `edgeBend`, `tipExt`) to the linked strand centrelines in (s, v). Dominant edge orientations (Ash: ±45°) give a starting slope.
- **Painter features:** cut-face angle at crossings (from ink edge orientation at the gaps, giving `cutSlant`), arc-tip taper (giving the fill-mode width keys), and the corner join style.

**Step 6: Corners and ends (new, plus an existing tile path).**
- Cut each corner and end patch in band-normalised coordinates.
- Score each against the engine's tile library for the detected family after the weave fit, with metric v2 on the joint page. This is `seedsFor` (km:2555-2578), generalised to a library search.
- If nothing is close (below an agreed fraction of gap closure), trace the patch into a candidate tile with the generalised Step-5 tracer, and fit its ports to the run's phase. That is what `ash-traced` and `ash-hairpin` were, done by hand.
- Product constraint: the owner rejected traced tiles as *product* tiles (memory: "designed tiles"). For "replicate this reference" a traced tile is the right first answer, which a designer can then clean up.
- Choose the primary position per kind automatically: the one whose corner or end agrees best with the other three under symmetry (`silAlike`, km:1256-1311).

**Step 7: Initial configuration, then a staged fit on the deliverable page.**
1. Weave: CMA-ES over about 10–20 keys, started from the Step-5 estimates. Use σ₀ ≤ 0.03 and a polish phase.
2. Tiles fitted **on the joint page only** (`--carryTiles`, `--hold` on the sides). Never on stage pages (3.4).
3. Per-point centreline descent (fit.cjs) with a **fairness prior** on the rendered curvature (2.6), then the same descent over per-knot **width** offsets.
4. Gates, plus a topology-graph match against Step 5's extracted graph.

**Step 8: Report.**
- Report against the reference's own self-consistency ceiling: mirror or rotation where a symmetry exists, otherwise split-half agreement between repeats of the run.
- Report **gap closure**, nominal and phase-mean (or 2×) scores, a fairness excess, and topology pass/fail.

### 5.3 Missing pieces, by name

| # | Missing piece | Status today |
|---|---|---|
| 1 | Generic reference loader (PNG/JPG/arbitrary SVG; page-aspect handling) | absent; refSvg is dialect-specific |
| 2 | Colour clustering and anti-aliasing unmixing (coverage-aware class map, k colours) | fixed palette; prototype unmixer only in scratch (q4.cjs) |
| 3 | Frame and spine extraction, region detection for any closed or open layout | rectangle-only measureRef with fixed region fractions |
| 4 | Band unrolling into (s, v) strips | absent (the engine has a spine; the tool has none for references) |
| 5 | Period estimator with harmonic resolution and drift | `measurePeriod` with a hand window of 120–260 px |
| 6 | Strand tracer and crossing-graph extractor (N, colours, over/under, pattern class) | trace-corner.cjs for one corner or end, with hand FORCE links |
| 7 | Width estimators (fill, outline, gap, taper) | ASH_INK measured by hand |
| 8 | Waveform fitter from traced centrelines to the engine's waveform keys | absent (CMA-ES finds them by rendering) |
| 9 | Tile library search plus trace-to-tile authoring with port fitting | `seedsFor` tries same-topology tiles; tiles authored by hand per drawing |
| 10 | Symmetry detection | done by hand (R4); the metric can do it (2.2) |
| 11 | Topology-graph gate (ours against the reference) | only internal consistency gates (`altBreaks`, `hpX`) |
| 12 | Fairness/perceptual terms and a fairness prior in the per-point fit | absent; the SMOOTH penalty acts on knots, not on curvature (2.5.1) |
| 13 | Per-knot width channel in the painter | only global thickness plus a 3×3 `fillField` per tile |
| 14 | Self-ceiling and gap-closure reporting | mirror ceiling measured by hand; the ledger target was set by the owner |
| 15 | Reference path independent of the checkout | `DEFAULT_REF` points into the main checkout (km:168) |
| 16 | Result files carrying their own score and stage | the committed best has stale `stage`/`score`/`diag` (3.5) |

### 5.4 The four example variations

- **Looser weave.**
  - Larger λ/band (`repeatLam`), lower `angular` (rounder turns), possibly smaller `thickness`. Steps 5's period and waveform fitter give the starting point.
  - Caveat: the end tiles carry `lam` and the engine's tile slack. joint13 drew fold caps when `repeatLam` 2.475 exceeded the tile slack (km:46-49). A looser weave may need re-authored tiles, or a tile `lam` that the fit is allowed to move.
- **Thicker band.**
  - `band.width` plus `thickness`. The region boxes scale with the measured band. The alignment spans (0.12 / 1.4 band) and the period window (in pixels) do not; they must become band-relative.
  - Thicker strokes make the ink fraction, and so the fringe, matter less. More pixels per feature also lowers phase noise.
- **Three strands.**
  - The engine has the `plait3` family, but the fitted `ash-contained` / `ash-hairpin` tiles are plait4-only. The tile library search falls back to the generic `ash` corner and end.
  - `inkMatch` hard-codes N = 4 in the thickness conversion (km:2068-2073).
  - Colour cycles with 3 strands and 2 colours are not periodic in one repeat: the colour-exact period differs from the shape period, which is another reason for an explicit harmonic model.
- **Different corner.** A library search over `CORNER_TILES[family]`, then a trace-to-tile step, then a joint-page fit. Squaring keys (`csq`), the nested L (`nl`) and `cornerColor` are specific to this corner; they would become per-tile options learned from the trace rather than global flags.

### 5.5 Sliders

- The engine configuration is already slider-shaped. `WEAVE_SPACE` and its extensions give natural ranges (km:1979-1990, 2030-2066):

  | Key | Range |
  |---|---|
  | band width | 4.5–7.5% |
  | inset | 0.6–2.6% |
  | thickness | 0.3–0.7 |
  | angular | 0.6–0.99 |
  | bow | −1–0 |
  | scale | 0.7–1.25 |
  | outline ratio | 0.3–0.75 |
  | gap ratio | 0.3–1.1 |
  | edgeBend | ±0.2 |
  | cutSlant | 0–1 |
  | fill arc/bar widths | 0.8–1.25 |
  | ink | 0.8–1.3 |
  | repeatLam | 2.2–2.7 |

- **The landscape is not slider-friendly in three places:**
  1. **Discrete re-rounding.** The number of repeats between end tiles is an integer, so a smooth slider produces jumps (0.839 → 0.555 for a 0.006 step).
  2. **Chirality and variant flips.** `endVariant` must be pinned.
  3. **Steep keys.** `edgeBend` ±0.1 costs 0.03–0.05 (km:1989).
- **Proposal:**
  - Expose repeat as "repeats per run (integer) + phase" rather than raw λ.
  - Pin variants.
  - Present tile choices as discrete pickers.
  - Show the live metric (gap closure) beside each slider, using the race and persistent-engine path (about 40–70 ms per score).

---

## 6. Quantitative timeline

**Conventions.**

- Rounds 1–11 used **metric v1** (legacy, swap-tolerant). Rounds 12 and later use **v2**.
- The ledger's bridge: V5's bests re-scored under v2 are sides 0.827, TL 0.639, top-L 0.625, joint 0.702 (v1: 0.791 / 0.659 / 0.651 / 0.698).
- Stage bests from round 8 on are robust means. Joint numbers are nominal.
- Through round 5 the corner and end are means over all 4 positions; from round 6 they are the primary (TL, top-L).
- Values are "baseline → best" from each run's `summary.json` or `best.json` (my `T/summaries.cjs`), the ledger, and the review files.
- Times are EST (2026-11-07/08).

| Round (tool) | Sides (weave stage) | Corner | End | Joint | Change in that round → what it bought |
|---|---|---|---|---|---|
| R1 (initial tool, 20:05) | 0.309 → 0.584 (L 0.748, R 0.420) | 0.389 → 0.402 (4-pos) | 0.426 → 0.513 (4-pos) | – | First CMA-ES fits of the asin waveform and alternation engine |
| R2–R3 (stop and restart rules) | 0.584 flat | 0.402 → 0.409; 0.393 flat | 0.513 flat | – | Restart and stop-rule work; no gains |
| **R4** (20:54) | **0.746** (R 0.420 → 0.744) | 0.383 flat | 0.629 (all 4 ends ≈ 0.63) | – | **Engine `symmetry: 'mirror'`: sides +0.162 (v1), the largest single gain** |
| R5 (σ₀ 0.15) | 0.746 flat | 0.445 flat | 0.629 flat | – | Wide σ samples only the plateau |
| **R6** (21:17) | 0.751 → **0.783** | TL 0.443 → 0.451 | top-L 0.632 → 0.646 | – | **σ₀ 0.03 (ridge)**, primary regions, cropped rasters, four-position gate: weave +0.032 |
| R7 | 0.783 | 0.451 → 0.467 | 0.646 → 0.661 | – | Capped kick, swing/scatter restarts |
| **R8** (22:13) | 0.764 → 0.780 (robust + periodTol) | **0.564 → 0.603** | 0.647 → 0.663 | – | **Ash-traced corner tile (trace-corner.cjs): TL baseline +0.10**; robustness and period tolerance redefine the scores; `endVariant` pinned |
| R9 | 0.755 → 0.757 (repeatPx 181) | 0.637 → 0.667 | 0.454 → 0.589 (top-L + cap) | – | Owner-mandated **hairpin** end topology plus the cap region (score falls by design); corner with phaseIn |
| R10 (V4) | 0.768 flat | 0.672 → 0.676 | 0.620 (JIT-inflated; true 0.593) | – | race, persist, probation, cutCurl; found the V8 miscompile → `--no-maglev` |
| R11 (V5) | 0.786 → 0.791 | 0.659 (contained tile) | 0.648 → 0.651 | 0.698 (two engines) | Joint stage, fairWrap, containment and port gates. **v2 re-score: 0.827 / 0.639 / 0.625 / 0.702** |
| **R12** (V6, v2) | 0.789 → **0.832** | 0.639 → 0.666 | 0.580 → **0.715** | 0.378 → 0.669 | Merged single engine, **inkMatch** (Ash's ink balance), wrapSquare, **endColor 0**: end +0.090 |
| **R13** (V7) | 0.825 (wrong configuration) | **0.731** (baseline, no search gain) | 0.715 flat | 0.729 (invalid: fold caps); corrected 0.737 | **cornerColor 1 (TL outer L pink): TL +0.065**; cornerFollow, breakExact, searchRepeat |
| **R14** (V8) | 0.8324 → 0.8326 | 0.731 flat (7,562 candidates, +0.000 over R13–R14) | 0.731 → **0.779** | 0.737 → 0.752 | **endBlend + traceEnd: end +0.047**; endFallback gate. Stall rule fired → outside review 1 |
| Review 1 (expt) | 0.8325 (true local max) | **0.7307 → 0.7501 in 80 evaluations** | – | – | (1+1)-ES σ 0.003; diagnosis: corner limited by the solver, sides by the representation |
| **R15** (V9) | 0.8425 → **0.8434** | 0.782 → **0.806** | 0.799 → 0.805 | 0.767 → 0.779 (bottom runs stretched: invalid) | Polish, multiStart, legFirst, **slanted cut faces**, mitre: corner +0.075 over the cycle |
| **R16** (V10) | 0.854 → **0.8626** (L 0.869 / R 0.856) | 0.815 → 0.819 | 0.820 → 0.824 | 0.805 → 0.809 (joint-page sides 0.855/0.851, TL 0.776) | **Fill painter (variable width): sides past 0.85**; phaseSpread fixes the stretch; run-stretch gate |
| **R17** (V11; launch broken) | 0.8626 → 0.864; joint-page 0.857/0.853 | joint-page **TL 0.842** (stage 0.820) | joint-page top-L 0.833 | **0.8403** | **`--carryTiles`: fitting on the joint page, TL +0.066 on the deliverable**; nestedL, legWeave. Passes ran with a bare `--sigma` and no polish (zsh arrays under bash) |
| R18 (V12; launch broken) | 0.864 | 0.843 | 0.836 | 0.8417 (+0.000) | hold, endPlace, fillField, weights; stall cycle 1 |
| R19 (V13) | 0.856/0.854 (held) | 0.843 (corner pass traded TL down; rejected) | **0.836 → 0.847** (tile 0.780 → 0.799) | **0.8464** | **refJitter pass + nominal polish: top-L +0.012 over the cycle**; stall cycle 2 → outside review 2 |
| Review 2 + fit.cjs (05:41–05:50) | 0.856/0.854 (unchanged) | **0.843 → 0.867** | **0.8395 → 0.868** (cap 0.802 → 0.856) | **0.843 → 0.861** | **Per-point centreline descent, 3,094 renders, about 8 minutes on one process**. Committed a6a58a5f6 |
| This session (SMOOTH, uncommitted) | – | 0.867 → 0.866 (4-phase −0.0008) | 0.868 → 0.868 (4-phase −0.0022) | 0.8608 (post-edit) | Knot roughness 8× lower; inflections 121 → 116 (2.5.1) |

**Which change produced which gain, in descending order of effect on the deliverable:**

1. **Structural engine facts read off the art.**
   - mirror symmetry (R4): +0.16 on the sides, v1;
   - the colour assignment at the corner (R13): +0.065 TL;
   - the end wrap colour and squaring (R12): +0.09 top-L;
   - the traced corner tile (R8): about +0.10 TL, v1.

   These are discrete design decisions, not continuous optimisation. Section 5's estimators (symmetry, colour per strand, tile choice) would need to produce them automatically.
2. **Representation capacity matched to the residual.**
   - Slanted cuts and the fill painter took the sides from 0.833 to 0.863 (R14–R16).
   - Per-point tile centrelines took TL +0.024 and top-L +0.028 (fit.cjs).
   - Each came after a stall that the outside reviews diagnosed as representation-limited.
3. **Fitting where the score is defined.** Joint page with `--carryTiles` gave TL +0.066 on the joint page (R17). Fixing the bottom-run defect (R16) gained no score, but made the joint page a valid deliverable.
4. **Search hygiene.**
   - σ₀ 0.03 (R6, +0.032);
   - the polish phase (+0.019 on the probe, part of +0.075 in V9);
   - refJitter plus a nominal pass (+0.008–0.012 top-L).
5. **Speed.** 4.5–5.8× cheaper candidates, 2–3.4× pool throughput (Section 3.1). It made later rounds feasible, but no score gain is directly attributable to it.
6. **Things that did not help.**
   - more CMA-ES restarts or larger populations on the sides (expt Q4);
   - wide σ (R5);
   - V12's width field and placement keys (R18, +0.000);
   - Ash's literal art pasted as a module: it lowers TL on the fitted page (0.848 against 0.867, review-2 Q4).

---

## Appendix: scripts and outputs I wrote

Everything is under `/private/tmp/claude-501/-Users-averykrouse-GitHub-ORK-tobias-ORK3-tobias/d582c881-63eb-4331-acce-d387afe6d0c7/scratchpad/synth/tool/`. All were run with `node --no-maglev`. None runs an optimisation.

- `summaries.cjs`: tabulates every `S/*/summary.json` (baseline, best, evaluations, seconds, renders, stop reason).
- `verify.cjs`: reference measurements (inset/band/gaps, class histogram, region boxes); joint re-score of the committed best at nominal, rsvg and refJitter 0.5, with timing.
- `ceiling.cjs`: Ash against his mirror and his 180° rotation per region; side autocorrelation over lags 60–400.
- `curv.cjs`: centreline fairness (E3, inflections) of e2, fit-both, the SMOOTH variants, h30 and smooth-best.
- `autoest.cjs`: automatic-estimation probes (colour runs per row, autocorrelation per channel, fill width by distance-transform ridge, edge orientations).
- `outline.cjs`: nearest-palette against coverage-aware class counts and ink-run widths on Ash's left run.
- `smoothscore.cjs`: joint nominal and 4-phase scores, plus gate counts, for the committed best and the SMOOTH 0.05 / 0.2 variants (post-edit engine).
- `determ.cjs`: reproducibility of a joint score across persistent and fresh contexts and both rasterisers.

The palette blend table (1.3) came from a one-line `node -e` over linear mixes of the `PALETTE` colours, using `classMap`'s nearest-RGB rule.

**Not analysed:** `results/2026-11-08-smooth-best.json`. A concurrent session added it, untracked, during this read: SMOOTH 0.2 from scratch, nominal 0.8688 / 0.8674, Σ E3 272,646 and 77 inflections by my `curv.cjs`. Its corner paths' sharp-corner energy also dropped sharply, which may mean that designed square corners were softened. It needs its own visual check.
