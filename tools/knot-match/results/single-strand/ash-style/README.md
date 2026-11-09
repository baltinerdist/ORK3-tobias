# Single-strand frame, Ash inked style

- Geometry: run2's best corner curve, smoothed along its control points with a Gaussian of sigma 1.0 points
  (`params-smoothed-sigma1.json`). The fitted curve carries a sub-pixel waver from matching the reference's pixels,
  which the heavy ink makes visible. Smoothing keeps all 10 crossings and their over/under order and cuts curvature
  sign changes from 19 to 10. Fine-line style against the reference it scores min phase-mean 0.835 / nominal 0.831
  (unsmoothed 0.880 / 0.872; sigma 0.8 would give 0.853 / 0.848, sigma 1.5 0.776).
- Style: fill 3.5 px, ink 0.52 x fill per side, true cut gap 0.53 x fill, no dark fill in the holes, no halo,
  one stroke width everywhere. 44 under-crossings cut (10 per corner plus one per P).
- Openings with P-curl ends as in `../p-ends`; stems lengthened to 13 px.
- CLI: `CUTS=1 ASH=3.5 node --no-maglev analyze/ffgen.cjs analyze/seed-single-strand.json out.svg results/single-strand/ash-style/params-smoothed-sigma1.json`
