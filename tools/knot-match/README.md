# knot-match

Knotwork analysis, generation and comparison tooling for the Scrollery's Custom Border.

- `analyze/` — the analysis engine and generators: reads a reference knot as a crossing
  lattice + barrier map (`lattice.cjs`, `trace.cjs`, `seed.cjs`), generates interlock
  (`gen.cjs`) and free-form single-strand (`freeform.cjs`, `ffgen.cjs`) borders, scores
  and cycles them toward a target (`score.cjs`, `cycle.cjs`, `ffcycle.cjs`, `gates.cjs`),
  and exports the Scrollery sprites (`export-scrollery.cjs`). See `analyze/HANDOFF.md`.
- `knotmatch.cjs` — the comparison tool: rasterises, class-maps and region-scores a design
  against Ash's hand-drawn knot (`assets/scrolls/common/knot/knot.svg`). Its `score` /
  `optimize` / `show` modes drove the old parametric engine (`scroll-knot.js`, from the
  July scroll generator); that engine is not on this branch, so those modes need
  `--engine <path>` from the archived `knot-v6-engine` line. The scoring functions that
  `analyze/` uses need no engine.
- `fit/`, `bench.cjs`, `raster.cjs`, `trace-corner.cjs`, `results/`, `docs/` — the
  engine-fitting rounds of 2026-11-07/08 and their results, kept as a record.

Regenerate the Scrollery sprites (styles 2-4):

    npm install --no-save pngjs      # not in package.json
    node --no-maglev tools/knot-match/analyze/export-scrollery.cjs assets/scrolls/common/knot

`KNOT_CORNER` (default 0.6) sets the single-strand corner scale. Needs `rsvg-convert` and
ImageMagick for scoring and review sheets.
