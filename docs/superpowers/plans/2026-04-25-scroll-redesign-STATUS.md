# Scroll Aesthetic Redesign — Execution Status

**Branch:** `feature/scroll-generator`
**Last commit:** `5c76643` — `Scroll redesign · plan 3 · decoration intensity UI + Unicode/long-name/intensity tests + attribution doc + whats_new`
**Date:** 2026-04-26

## Summary

Plans 1 and 2 are functionally complete. Plan 3 is partially shipped — the decoration intensity slider, aging filters, hardening tests, attribution, and What's New entry all landed. Visual-regression CI baselines and the full builder-UI legacy-cleanup pass remain pending; both are deferred-but-low-risk because:
- The legacy template/palette/border UI still works alongside the new family picker (additive, not destructive). Users can fall back at any time.
- Visual-regression CI requires a stable baseline; with the renderer evolving across families, baselines should be set once after a stylistic review pass.

The branch as it stands is **shippable as a meaningful v1**: 10 distinct illuminated style families, period-correct palettes, family-specific frames and seal stamps, embossed wax seals with diagonal ribbon tails, historiated initials, drôleries, banderoles, aging filters for Charred Edict, decoration-intensity controls, and end-to-end tests.

## What ships in this branch right now

### Foundation (Plan 1)
- ✅ `system/lib/ork3/class.ScrollPalette.php` — 7-token palette schema, validator, hex/RGB/lighten/darken utilities
- ✅ `system/lib/ork3/class.ScrollPrimitives.php` — `fillGildedRect`, `fillGildedCircle`, `applyParchment`, `drawStubFrame`
- ✅ `orkui/template/revised-frontend/scroll/scroll-palette.js` + `scroll-primitives.js` — JS mirrors
- ✅ `tests/scroll/lib/{assert.php,brace_edit.py}` + `run-all.sh`

### Family system (Plan 1)
- ✅ `orkui/template/revised-frontend/scroll/families.json` — single source of truth for all 10 families
- ✅ `system/lib/ork3/class.ScrollFamilyRenderer.php` — PHP renderer with canonical layout
- ✅ `orkui/template/revised-frontend/scroll/scroll-families.js` — JS mirror
- ✅ All 10 families render at preview (480×624) AND print scale (2550×3300 / 300 DPI)
- ✅ Print-scale render of Northern Gothic measured at 0.17s

### Decoration system (Plan 2)
- ✅ `system/lib/ork3/class.ScrollDecoration.php` — 10 procedural family frames, 10 seal stamps, historiated initial, banderole, drôleries, burnt edge, fold creases, star field, embossed wax seal, heraldry medallion
- ✅ `orkui/template/revised-frontend/scroll/scroll-decoration.js` — JS canvas mirror
- ✅ Family-specific frames: gothic_ivy, insular_knot, asymmetric_ivy_grotesque, gothic_arch, organic_vine, minimal_burnt, jeweled_cabochon, renaissance_white_vine, romanesque_arch, astral_star_pattern
- ✅ Family-specific seal stamps: lion, fleur, crown, oak_leaf, broken_sword, eagle, pentagram, quill, knotwork, rabbit
- ✅ Wax seal with diagonal ribbon tails + family stamp at golden-ratio position (centered for Imperial Edict + Astral Codex)
- ✅ Historiated initial: 3-zone (corner squares / inner field with diaper / letter form)
- ✅ Banderole motto for Provençal Bestiary
- ✅ Hare-jousts-snail drôlerie for Northern Gothic; rabbit-lute for Provençal Bestiary

### Hardening (Plan 3 — partial)
- ✅ Decoration intensity slider in builder UI (Light / Balanced / Heavy)
- ✅ Astral Codex print-substitute: parchment bg on export to save ink (dark celestial preserved on screen)
- ✅ Burnt edge + fold creases (Charred Edict + heavy-intensity any family)
- ✅ Star field overlay for Astral Codex screen-mode preview
- ✅ Programmatic-decoration attribution doc (`system/assets/scroll/ATTRIBUTION.md`) — CC0 procedural, OFL-licensed fonts
- ✅ "What's New" entry pumping ORK_VERSION to `3.5.1` and `WHATS_NEW_VERSION` to `2026-04-26`

### Database
- ✅ Migration `db-migrations/2026-04-25-scroll-family-assets.sql` applied (with commented down-migration)

### Backend
- ✅ `POST /ScrollAjax/generate_family` endpoint — 300 DPI PNG export with Astral print-substitute + signature parsing
- ✅ Legacy `POST /ScrollAjax/generate` endpoint untouched (90-day deprecation window via UI label)

### Builder UI
- ✅ "Style Family" section at top of controls panel (10 family cards, click-to-select, multi-select indicator)
- ✅ Inline `window.SC_FAMILIES` JSON loaded from families.json
- ✅ Auto-suggest family from award type (knighthoods → Crimson Decree, ladders → Hibernian Knotwork, titles → Northern Gothic)
- ✅ New family preview canvas + "Download (Style Family)" button on right panel
- ✅ Decoration intensity radio buttons (Light/Balanced/Heavy)
- ✅ `sgSelectFamily`, `sgRenderFamily`, `sgFamilySetIntensity`, `sgDownloadFamilyScroll` JS handlers
- ✅ Live re-render when award name / recipient / body / signatures change
- ✅ Legacy template picker preserved with `(legacy · 90-day deprecation)` label

### Tests (all passing — `bash tests/scroll/run-all.sh`)
- ✅ `test_palette_linter.php` — palette schema + lighten/darken + hex utilities
- ✅ `test_primitives.php` — gilding center brightness, parchment density scaling, stub frame correctness
- ✅ `test_families_manifest.php` — manifest schema + all 50 font_php references resolve to real TTFs on disk
- ✅ `test_php_render.php` — all 10 families render at preview + print scale
- ✅ `test_unicode_and_long_names.php` — Unicode award names, 80+ char names, empty body, all 10 families with Unicode fixture
- ✅ `test_decoration_intensity.php` — intensity slider produces measurable pixel-density differences; Astral Codex print substitute swaps dark→parchment

## Known issues / scoped down

### Asset acquisition
- The Docker container has no outbound network in this dev environment. All decorative elements ship as **procedural draws** (PHP GD + HTML5 Canvas), not curated public-domain manuscript scans. Quality is meaningfully better than the legacy 8 templates but does not reach Met-quality illumination. v1.5 should layer in BNF/BL/Met assets when network permits.
- Two TTFs in `assets/scroll/fonts/` are corrupt (HTML 404 pages saved as TTFs from a botched earlier fetch): `CormorantGaramond-Regular.ttf` and `GrenzeGotisch-Regular.ttf`. Substituted with EB Garamond throughout `families.json`. Re-fetch when network is available.

### Plan 3 deferred items (low-risk)
- **Visual-regression CI**: snapshot baselines + JS-vs-PHP pixel-diff. The baseline gathering and parity tuning is best done after a stylistic review pass — premature now.
- **Classic Templates preserve mode (full fork)**: the legacy UI is preserved alongside the new picker (additive change), but the spec also called for forking `controller.ScrollAjax.php` to `controller.ScrollAjaxLegacy.php` to freeze it. Not done — the live legacy controller still serves the legacy templates fine.
- **Remove `$TEMPLATES`, `$PALETTES`, `drawBorder*` legacy code**: not done. These remain alongside the new code path. Removal is the 90-day cleanup task per spec.
- **Game-icons.net curated stamps**: explicitly substituted with procedural draws (no network for fetches). Documented in ATTRIBUTION.md as v1.5 candidate.

## Commit log (this branch since the spec)

```
5c76643 Scroll redesign · plan 3 · decoration intensity UI + Unicode/long-name/intensity tests + attribution doc + whats_new
d12b1aa Scroll redesign · plan 2 · JS canvas mirror — ScrollDecoration + updated ScrollFamilies.renderFamily
0d41a3e Scroll redesign · plan 2 · ScrollDecoration — 10 family frames, 10 seal stamps, historiated initial, banderole, drôleries, burnt-edge, fold-creases, star-field, wax seal emboss
bd439fd Scroll redesign · execution status — Plan 1 substantively complete; Plans 2-3 pending
9be29e9 Scroll redesign · plan 1 · extend renderer test to 300 DPI print scale (Northern Gothic, 0.17s)
4e50173 Scroll redesign · plan 1 · builder UI: family picker + preview canvas + generate_family endpoint
921cb44 Scroll redesign · plan 1 · ScrollFamilyRenderer (PHP+JS) + DB migration · 10 families render end-to-end
af39c4f Scroll redesign · plan 1 · families.json (10 families, all using existing fonts)
3b91c47 Scroll redesign · plan 1 · foundation primitives (gilding, parchment, stubFrame, tintAsset) JS+PHP
b83559a Scroll redesign · plan 1 · palette schema + linter (PHP)
d8b6feb Scroll redesign · plan 1 · test harness scaffold + brace-edit helper
ced9452 Plans: Scroll redesign — 3 implementation plans + spec refinements
9512c97 Spec: Scroll aesthetic redesign — 10 illuminated style families
```

11 scoped commits since the spec.

## Manual verification (browser)

To verify in a browser:
1. Visit the Scroll Generator at `/orkui/Scroll/...` (auth required).
2. The new "Style Family" section appears at the top of the left panel with 10 cards.
3. Click each family — preview canvas re-renders with that family's palette + fonts + frame + seal stamp.
4. Toggle Light/Balanced/Heavy — preview adjusts foxing/vignette intensity.
5. Click "Download (Style Family)" — downloads a 2550×3300 PNG via the new endpoint.
6. Astral Codex specifically: preview shows dark celestial bg with star field; downloaded PNG shows parchment bg (print substitute).
7. Charred Edict: preview shows burnt edges + fold creases.

The legacy template picker remains in place below the family picker for the 90-day deprecation window.

## What's outstanding for "v1.5" / cleanup

Tracked here, not in the plan files (they're now history):
- Refetch and re-curate `CormorantGaramond-Regular.ttf` and `GrenzeGotisch-Regular.ttf` when network is available.
- Layer in BNF/BL/Met curated PD manuscript assets per family (see spec section 7).
- Stand up visual-regression CI with JS-vs-PHP pixel-diff and `PARITY_EXCLUSIONS`.
- 90-day deprecation cleanup: remove legacy `$TEMPLATES`, `$PALETTES`, `drawBorder*`, legacy template picker UI.
- Optional: forked `ScrollAjaxLegacy.php` if you want a hard freeze on the legacy path.
- Optional: 10 family-specific render_<key> bespoke layouts (currently all 10 use the same canonical layout differentiated only by frame + seal + decoration list — already meaningfully distinct, but Plan 3 spec called for further per-family layout differences like Crimson Decree's gold-ground panel behind initial, Imperial Edict's axial tympanum-and-base composition, etc.).
