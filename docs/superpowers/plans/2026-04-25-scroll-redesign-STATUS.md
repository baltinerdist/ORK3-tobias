# Scroll Aesthetic Redesign — Execution Status

**Branch:** `feature/scroll-generator`
**Last commit:** `9be29e9` — `Scroll redesign · plan 1 · extend renderer test to 300 DPI print scale`
**Date:** 2026-04-25

## Summary

Plan 1 (Foundation & Manifest) is substantively complete and committed. The new family-driven scroll path renders all 10 illuminated style families end-to-end through both JS canvas (preview) and PHP GD (export at 300 DPI). The legacy 8-template path is preserved alongside (Plan 3 retires it under a 90-day deprecation window).

Plans 2 (Asset-Driven Quality) and 3 (Per-Family Renderers, Aging, Cleanup, Tests) are documented in full detail under `docs/superpowers/plans/` and have not yet been executed in this session — they require additional execution time. Each is suitable for `superpowers:subagent-driven-development` or `superpowers:executing-plans` continuation.

## What ships in this branch right now

### Foundation infrastructure
- ✅ `system/lib/ork3/class.ScrollPalette.php` — 7-token palette schema, validator, hex/RGB/lighten/darken utilities
- ✅ `system/lib/ork3/class.ScrollPrimitives.php` — `fillGildedRect`, `fillGildedCircle`, `applyParchment` (with foxing/vignette/noise), `drawStubFrame`
- ✅ `orkui/template/revised-frontend/scroll/scroll-palette.js` — JS mirror of palette utilities
- ✅ `orkui/template/revised-frontend/scroll/scroll-primitives.js` — JS mirror primitives (`gildingGradient`, `parchmentTexture`, `stubFrame`, `loadAsset`, `tintAsset`)
- ✅ `tests/scroll/lib/assert.php` — lightweight assertion helpers
- ✅ `tests/scroll/lib/brace_edit.py` — brace-balanced block extractor (for safe Python-driven refactors in Plans 2-3)
- ✅ `tests/scroll/run-all.sh` — test runner

### Family system
- ✅ `orkui/template/revised-frontend/scroll/families.json` — single source of truth for all 10 families (palette tokens, fonts, decoration list, layout, sigCount)
- ✅ `system/lib/ork3/class.ScrollFamilyRenderer.php` — PHP renderer with `renderCanonical()` shared layout + dispatch hook for per-family `render_<key>` methods (Plan 3 splits)
- ✅ `orkui/template/revised-frontend/scroll/scroll-families.js` — JS mirror with `ScrollFamilies.renderFamily()`
- ✅ All 10 families render to PNG at preview (480×624) AND print scale (2550×3300 / 300 DPI)
- ✅ Print-scale render of Northern Gothic measured at 0.17s — well under the 8s budget

### Database
- ✅ `db-migrations/2026-04-25-scroll-family-assets.sql` — extends `ork_scroll_artwork` with `system_owned`, `family_key`, `asset_role`, `tint_mode`, `source_attribution`, `source_license` + indexes; includes commented down-migration
- ✅ Migration applied to local Docker DB

### Builder UI
- ✅ New "Style Family" section added to top of controls panel (10 family cards, click-to-select)
- ✅ Inline `window.SC_FAMILIES` JSON loaded from families.json
- ✅ Auto-suggest family based on award type (knighthoods → Crimson Decree, ladders → Hibernian Knotwork, titles → Northern Gothic)
- ✅ New family preview canvas + "Download (Style Family)" button on right panel
- ✅ `sgSelectFamily`, `sgRenderFamily`, `sgDownloadFamilyScroll` JS handlers
- ✅ Live re-render when award name / recipient / body / signatures change
- ✅ Legacy template picker preserved with "(legacy · 90-day deprecation)" label

### Backend
- ✅ New endpoint `POST /ScrollAjax/generate_family` returning a 300 DPI PNG
- ✅ Astral Codex print-substitute applied in `generate_family` (dark celestial bg → parchment for export)
- ✅ Legacy `generate()` endpoint untouched

### Tests
- ✅ `test_palette_linter.php` — palette schema + lighten/darken + hex utilities
- ✅ `test_primitives.php` — gilding center brightness, parchment density scaling, stub frame correctness
- ✅ `test_families_manifest.php` — manifest schema + all 50 font_php references resolve to real TTFs on disk
- ✅ `test_php_render.php` — all 10 families render to PNG, smoke + print scale
- All tests pass via `bash tests/scroll/run-all.sh`

## Known issues / scoped-down

### Asset acquisition (deferred to Plan 2)
- The Docker container has no outbound network in this dev environment, blocking direct font/asset downloads.
- Plan 1 uses only the 21 fonts already present in `assets/scroll/fonts/`. Two fonts in that directory are corrupt (committed as HTML 404 pages instead of TTFs):
  - `CormorantGaramond-Regular.ttf` — substituted with EB Garamond in `families.json`
  - `GrenzeGotisch-Regular.ttf` — was unused in any family
- Plan 2 was supposed to download Game-icons.net SVGs (CC-BY 3.0). With the network restriction, Plan 2's seed script will need either: (a) executor with network access, (b) pre-staged asset bundle, or (c) fallback to programmatic-only SVG generation (lower quality ceiling but possible).

### Aesthetic distinction (deferred to Plan 3)
- All 10 families currently render through the same `renderCanonical()` layout, distinguished only by palette + fonts. This is intentional Plan 1 scope: prove the architecture, ship 10 families end-to-end, then differentiate.
- Plan 3 adds 10 family-specific `render_<key>` methods (Crimson Decree's gold-ground panel, Imperial Edict's axial tympanum, Astral Codex's star-field, etc.).

### UI cleanup (deferred to Plan 3)
- Legacy template picker / palette picker / border picker / celtic options panel are still in the UI alongside the new family picker. Plan 3 removes them once the new path is validated.
- "Classic templates" preserve mode (the 90-day deprecation safety net) is not yet implemented; Plan 3 R2 ships it.

## What's outstanding — Plan 2 and Plan 3

### Plan 2 — Asset-Driven Quality (~10 days)
Read: [`2026-04-25-scroll-redesign-plan-2-quality.md`](./2026-04-25-scroll-redesign-plan-2-quality.md). Header includes "REFINEMENTS APPLIED" overrides (R1 = pre-tint at seed time, R2 = async render race-fix, R3 = drop motto field, R4 = brace-counter helper).

Key tasks:
- Asset directory + seed script for 10 families × 8-12 assets each
- Programmatic SVG library for frame/initial/seal/drôlerie generators
- Pre-tint pipeline at seed time (writes `<role>__<token>.png` per family)
- `frameFamily` primitive (JS + PHP) to composite curated frame assets
- `historiatedInitial` primitive (3-zone parameterized)
- `waxSealEmboss` primitive with diagonal ribbon tails + family stamp
- `banderole` primitive (text-along-curve)
- Remove the 7 legacy `drawBorder*` functions

### Plan 3 — Per-Family Renderers, Aging, Cleanup, Tests (~10 days)
Read: [`2026-04-25-scroll-redesign-plan-3-renderers-cleanup.md`](./2026-04-25-scroll-redesign-plan-3-renderers-cleanup.md). Header includes "REFINEMENTS APPLIED" overrides R1-R10.

Key tasks:
- 10 family-specific `render_<key>` methods (JS + PHP) — bespoke layouts, not just palette swaps
- `burntEdgeMask` + `foldCreaseOverlay` for Charred Edict (with deterministic seeded RNG per R4)
- Decoration intensity slider, Game-icons attribution rendering on scrolls
- Classic Templates preserve mode (90-day deprecation, R2)
- Backward-compat for legacy `?template=X` URLs
- Remove `$TEMPLATES`, `$PALETTES`, all legacy primitives
- Visual regression CI with `PARITY_EXCLUSIONS` for text/initial regions (R5)
- Additional tests: font availability, Unicode award names, long names, asset integrity, families.json schema (R10)
- Print-test pass on 3 printer types in done-definition (R9)

## How to continue

1. **Execute Plan 2**: invoke `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` and point at `2026-04-25-scroll-redesign-plan-2-quality.md`. The plan's REFINEMENTS section at the top must be honored.
2. **Execute Plan 3**: same pattern with `2026-04-25-scroll-redesign-plan-3-renderers-cleanup.md`.
3. **Visual smoke check**: hit the builder at `/orkui/Scroll/...` (auth required), pick each family from the new picker, click Download (Style Family). Compare to the legacy templates side-by-side.

## Commit log (this session)

```
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

Plan 1 substantive completion: 7 commits, ~1600 lines added across PHP/JS/JSON/SQL.
