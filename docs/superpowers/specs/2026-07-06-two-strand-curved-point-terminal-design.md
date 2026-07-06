# Scroll knotwork — zero-shear terminals (no protruding hooks)

**Date:** 2026-07-06
**Branch:** feature/scroll-generator (PR #6)
**File:** `orkui/template/revised-frontend/scroll/scroll-knot.js`
**Tests:** `tools/test-scroll-knot.cjs`

## Problem

When the knotwork border is cut into open segments by a break (an emblem gap or a manual break),
each open end is finished with a "natural-fold" cap. The original cap was a **slope-sheared
semicircle** (`shearPts(rimArc(...))`). At every terminal one fold protruded into an elongated
"hook/phalange" that shot out past the weave, while its sibling fold curled cleanly. The asymmetry
appeared on all multi-strand patterns (openweave, plait) and, subtly, twist.

## Root cause

The hook **is** the shear. A cap is only tangent-continuous with the strands if it is sheared by
the pair's shared fold slope `s`; when `s ≠ 0` that shear tilts the loop outward — the protrusion.
The controlling identity:

> `s = 0  ⟺  the strand runs parallel to the run at the fold`.

The old anchor (a separation-`|D|` maximum of the *nesting* pair `(i, N−1−i)`) does **not** give
`s = 0` for non-mirror pairs, so those folds were always sheared. (Earlier attempts — pushing the
fold deeper, or filtering by which strand sat above the midline — only *relocated* the hook, because
they treated the symptom, weave phase, not the cause, the shear.)

## Solution — anchor every cap where the strand is parallel to the run (`v' = 0`)

### Even N (openweave-4, plait-2/4, twist-2)
Change the terminal partner from the nesting partner `j = N−1−i` to the **centerline-mirror**
partner `j = i + N/2` (helper `foldPartner(i, N)`). Mirror strands satisfy `v_j = band − v_i`, so
the separation maximum coincides with each strand's own `v' = 0` peak ⇒ shared slope
`s = (v_i' + v_j')/2 = 0` **exactly** ⇒ `shearPts` is a no-op ⇒ no tilt, no hook — unconditional
across lam / scale / thickness / length. Twist N=2 is `i + N/2 == N − 1 − i`, i.e. byte-identical
(it already uses the approved `pointArc` curved point).

**Three pairing sites** must change together (they read differently, so a naive grep misses one;
patching only two breaks the strand→cap junctions): `assignFolds`, the `buildSpineSegmentPolys` trim
loop (`pj`), and `endArcs` (`j`).

### Odd N (plait-3 only)
No exact mirror exists. Anchor the outer pair on the **middle strand's own symmetry-axis extrema**
(`ownExtrema(strand1)`), where the two outer strands are *coincident* with equal-and-opposite
slopes. Close them with `leafFoldTangent` — a symmetric two-arm pointed leaf whose arms leave the
foot at the strands' arrival slopes (`sign(F.si·dir)` selects each arm) and meet at a shared rounded
tip. The middle strand keeps its horizontal-tangent `leafFold`. Coincident feet at a single `u` make
a boundary-crossing bridge structurally impossible. Leaf v-rise is bounded (`LEAF_TAN_RISE`) and
vertices clamped into the band (`clampV`) so nothing bleeds past the edge.

### Pair stagger
`PAIR_STAGGER = 0.2` (was 0.3). Adjacent mirror pairs interleave naturally at `lam/4 = 0.25·λ`; the
stagger must stay **below** 0.25 or an inner pair is skipped a full half-wave (0.75·λ) inward,
leaving the outer pair to solo extra loops. At 0.2 the inner pair folds right after the outer pair's
last crossing — a compact interlocking terminal.

### Morphology
Even-N mirror pairs render as **equal-diameter** full-band loops (clean interlocking figure-eights).
This was chosen over a graduated-nesting taper. (A per-pair reach taper that compresses only the
u-bulge can graduate the lobes if ever wanted; compressing v detaches the cap and reintroduces a
kink, so that variant is out.)

## Permanence invariants (in the harness)

`no hook` is a tested geometric property, not luck. For every pattern × count × density × length:

- **Even N:** `|atan(fold.s)| ≤ 1°` and mirror identity `|va + vb − band| < 1e-3`.
- **Odd N:** outer feet coincident (`|va − vb|` small).
- **All:** v-envelope (vertex + stroke half-width within `[0, band]`), u-containment (no terminal
  vertex past `[0, Lseg]`), and a non-degeneracy floor (real-scale cases actually fold).

Full suite: **24,854 checks pass.** Verified visually (SVG→PNG renders and the live designer) across
densities/lengths and both segment ends for openweave-4, plait-4, plait-3, plait-2, twist-2.

## Provenance

Root cause and solution came from a four-expert adversarial deep-dive (geometry/topology,
procedural-generation, principal-architect, Celtic-knotwork) with a synthesis + verification pass;
the even-N mirror-pairing core was independently confirmed by all four.
