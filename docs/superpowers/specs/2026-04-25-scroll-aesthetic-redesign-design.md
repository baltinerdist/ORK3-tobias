# Scroll Aesthetic Redesign — Design Document

**Branch:** `feature/scroll-generator`
**Date:** 2026-04-25
**Status:** Pending user review

## 1. Problem Statement

The Scroll Generator has the engineering scaffolding right — dual JS-canvas/PHP-GD renderer at 300 DPI, palette-token primitives, an admin-approved artwork pipeline, 8 templates × 12 palettes × 8 borders × 21 fonts of surface area. But the outputs feel like digital certificates wearing a costume rather than illuminated scrolls. Three root causes:

1. **Decoration density is uniform.** Real illumination has a sharp gradient — heaviest at the historiated initial and title, sparse in the body, moderate at the seal. Today every region is weighted the same.
2. **The frame never breaks.** Real margins have vines extending out of initials and banderoles overlapping the body. Today the frame is a hard fence.
3. **The vocabulary is generic-medieval.** The 8 current templates are *layout variants*, not stylistic worlds — a knighthood scroll and a bardic ballad are visually interchangeable. Plus: flat `#FFD700` cartoon gold, `#000` ink on `#FFF` parchment, no foxing or fold creases, geometric stamped wax seals.

This redesign replaces the 8 layout-variant templates with **10 named style families** — each a coordinated palette + typography + decoration system grounded in a real medieval period or fantasy mood. Output reaches "real illumination" quality by combining programmatic primitives (which we control) with curated public-domain manuscript art (which provides the ornament fidelity code can't reach). The dual-renderer architecture stays; the renderer is not the problem.

## 2. Goals & Non-Goals

**Goals (v1):**
- Replace the 8 generic templates with 10 distinctive style families, each visually identifiable at a glance.
- Reach a quality bar where the output reads as illumination, not as a certificate.
- Preserve the dual canvas-preview / PHP-GD-export architecture.
- Reach feature parity between preview and export (no Celtic-knot-style drift).
- Reuse and extend existing primitives where possible; introduce only the new ones the families demand.
- Build an asset pipeline that can ingest curated public-domain manuscript art and tint it to family palettes.

**Non-goals (v1, deferred to v2+):**
- SVG-master template renderer (replaces dual canvas/GD with single-source-of-truth SVG). Identified during brainstorming as the right v3 horizon; keep dual-render for now.
- PDF export.
- A4 / letter / poster page sizes — stays 8.5×11 PNG only.
- User-customizable palette colors beyond family selection.
- Per-letter historiated initial library for every letter A–Z (v1 ships parametric initials with a small curated set for high-frequency letters; full library is v1.1).
- Animation or interactive scroll output.
- Backward compatibility with the 8 legacy templates — v1 fully replaces them.

## 3. The 10 Style Families

Each family is a locked bundle in v1: palette + fonts + frame + decoration set ship together. (Mix-and-match — pick Family A's palette but Family B's frame — is a v1.1 enhancement; locking simplifies the asset pipeline and the builder UI.)

| # | Family | Period / Mood | Palette tokens (hex) | Title font | Body font | Frame family | Signature decoration |
|---|---|---|---|---|---|---|---|
| 1 | **Hibernian Knotwork** | Insular, c. 700, pagan-Christian, no gold | bg `#EBDDB2` · text `#1C1810` · accent `#E34234` · border `#0B6623` · second `#D4A017` | Uncial Antiqua | Cardo | Insular knotwork band | Spiral triskeles at corners, zoomorphic terminals on knotwork |
| 2 | **Northern Gothic** | 14th-c. Germanic imperial decree | bg `#F4E8C8` · text `#1C1810` · accent `#B71C2A` · border `#2A4B8D` · gold `#D4AF37` | UnifrakturCook | EB Garamond | Gothic ivy-bar | Gilded besants at corners, hare-and-snail drôlerie bas-de-page |
| 3 | **Provençal Bestiary** | Whimsical Gothic margins, marginalia overrun | bg `#F1E4BD` · text `#1C1810` · accent `#E34234` · border `#3B5998` · second `#43A47A` · third `#E8C547` · gold `#D4AF37` | MedievalSharp | Sorts Mill Goudy | Asymmetric ivy with grotesques | Marginal hybrids (rabbit knights, hybrid creatures), banderole motto |
| 4 | **Crimson Decree** | Royal/Byzantine monarchical proclamation | bg `#F8F4E3` · text `#1C1810` · accent `#7B1F2A` · border `#7B1F2A` · gold `#D4AF37` · wax `#7B1F2A` | Cormorant SC | Cormorant Garamond | Gothic arch architectural frame | Gold ground behind initial, oversized red wax seal w/ double diagonal ribbon, gilded fleurs |
| 5 | **Forest Reverie** | Fey/druidic, naturalistic, Sylvan order | bg `#EFE2BD` · text `#2C1810` · accent `#43745A` · border `#704214` · second `#D4A017` · wax `#1F4D2E` | Cardo SC | Alegreya | Organic vine breaking border | Asymmetric leaf rosettes, green wax, oxbow ribbons |
| 6 | **Charred Edict** | Battlefield, beleaguered, "smuggled out" | bg `#C2A672` (aged) · text `#1C1810` · accent `#5C0E1A` · border `#3D2418` · wax `#1A1A1A` (black) | IM Fell English | IM Fell DW Pica | Minimal frame, burnt edges | Burn-edge mask, fold creases, foxing-heavy, off-center black wax with broken ribbon |
| 7 | **Imperial Edict** | Byzantine gold-ground icon, hieratic | bg `#F8F4E3` · text `#1C1810` · accent `#E34234` · border `#2A4B8D` · gold `#D4AF37` (full ground top third) | Cormorant SC tracked | Cardo | Jeweled cabochon border | Gold-leaf ground at top third, alternating red/blue cabochons, axial symmetry, icon-style heraldry |
| 8 | **Scholar's Hand** | Renaissance restraint, humanist Italian c. 1480 | bg `#F8F4E3` · text `#1C1810` · accent `#2A4B8D` · border `#0B6623` · second `#E34234` · gold `#D4AF37` | Cormorant Garamond italic | EB Garamond | Renaissance white-vine bianchi girari | Tri-color ground bands with white scrollwork, classical urn at top, putti, restrained gilding |
| 9 | **Crusader's Charter** | Romanesque c. 1100, holy military order | bg `#F4E8C8` · text `#1C1810` · accent `#8B0000` · border `#8B0000` · gold `#D4AF37` · second `#0B6623` | Cardo (small caps) | EB Garamond | Romanesque round-arch architectural | Lion or eagle supporters flanking shield, jeweled cross at top, triumphal-arch composition |
| 10 | **Astral Codex** | Occult/arcane, alchemical/astrological grimoire | bg `#0A0A1F` · text `#F0F0F0` · accent `#B8860B` · border `#3D1F4E` · second `#C0C0C0` (silver) · third `#9370DB` | Pirata One | EB Garamond italic | Star-pattern margin band | Zodiac glyphs, alchemical symbols (☉☽☿), constellation diagrams, silvered frame on celestial blue ground |

Note: family 10 (Astral Codex) inverts the convention — dark ground, light ink — for the only "magical" family. All others use cream/parchment grounds.

### Orientation handling

Orientation (portrait 8.5×11 / landscape 11×8.5) is **independent of family** in v1. Every family supports both. The current Battle Standard template was the only landscape outlet; under the new system, landscape is a state toggle — `Charred Edict + landscape` covers the battle-award use case the old Battle Standard served. Each family's `render()` function receives `orientation` and adapts: title/body block widths shift, signature bar may go horizontal-bar (landscape) vs. vertical-stack (portrait), heraldry positioning adjusts. Auto-suggestion logic picks portrait by default; landscape is opt-in via the orientation toggle, which is preserved from the current builder UI.

## 4. Palette Token System

Current palette has 4 tokens: `bg`, `text`, `accent`, `border`. Extend to 8 to support real illumination:

```
bg              — primary parchment / ground color
text            — primary ink color (iron-gall, never #000)
accent          — primary decorative color (vermilion, crimson, etc.)
border          — secondary structural color (ultramarine, malachite, etc.)
gold            — burnished gold base (mid-stop of gilding gradient)
gold_highlight  — gold gradient highlight stop (#FFF3B0 / #FFF8DC tier)
wax             — wax seal color (varies family-to-family)
ground_a        — supporting decoration color (per family)
```

Two optional extension tokens for families that need more:
```
ground_b        — third decoration color (Provençal Bestiary, Imperial Edict, Scholar's Hand, Crusader's Charter)
ink_secondary   — secondary ink for sub-headings, marginalia (italics, small-caps subtitles)
```

Token references inside primitives stay the same — primitives ask the palette for the token they need. Adding tokens is additive; existing primitives that consume only `bg/text/accent/border` continue to work.

The 12 legacy palettes (`classic`, `royal`, `nature`, `crimson`, `obsidian`, `white`, `burgundy`, `forest`, `ink`, `illuminated`, `sable`, `twilight`) are removed — replaced by the 10 family palettes. No legacy fallback; v1 ships clean.

## 5. Family Manifest (Single Source of Truth)

A new file `/orkui/template/revised-frontend/scroll/families.json` holds the entire family configuration in one place:

```json
{
  "northern_gothic": {
    "name": "Northern Gothic",
    "period": "Germanic · 14th c.",
    "mood": "Imperial decree, dense ivy borders…",
    "orientation": "portrait",
    "palette": { "bg": "#F4E8C8", "text": "#1C1810", "accent": "#B71C2A", "border": "#2A4B8D", "gold": "#D4AF37", "gold_highlight": "#FFF3B0", "wax": "#7B1F2A", "ground_a": "#0B6623" },
    "fonts": { "title": "UnifrakturCook", "subtitle": "Cormorant Garamond Italic", "body": "EB Garamond", "signatures": "Italianno", "date": "IM Fell English Italic" },
    "frame": "gothic_ivy",
    "decoration": ["historiated_initial", "drolerie", "heraldry_medallion", "gilded_besants"],
    "layout": "three_zone_vertical",
    "sigCount": 2,
    "assets": {
      "frame_corner_nw": "manuscript/northern-gothic/frame-nw.png",
      "frame_corner_ne": "manuscript/northern-gothic/frame-ne.png",
      "frame_corner_sw": "manuscript/northern-gothic/frame-sw.png",
      "frame_corner_se": "manuscript/northern-gothic/frame-se.png",
      "frame_edge_top": "manuscript/northern-gothic/frame-top-tile.png",
      "frame_edge_right": "manuscript/northern-gothic/frame-right-tile.png",
      "frame_edge_bottom": "manuscript/northern-gothic/frame-bottom-tile.png",
      "frame_edge_left": "manuscript/northern-gothic/frame-left-tile.png",
      "drolerie": "manuscript/northern-gothic/drolerie-hare-snail.png",
      "seal_stamp": "manuscript/northern-gothic/lion-rampant.svg",
      "initial_decoration": "manuscript/northern-gothic/initial-vine.svg"
    }
  },
  "...": "..."
}
```

Loaded by both renderers:
- **JS canvas:** `<?= file_get_contents(...) ?>` inlined into the template head as `window.SC_FAMILIES = {...};`
- **PHP GD:** `json_decode(file_get_contents($familiesPath), true)` at controller load.

This replaces the duplicated `TEMPLATES` object in JS and `$TEMPLATES` array in PHP. Render functions (`render_northern_gothic($state)` and the JS `tpl.render(ctx, w, h, st, pal)`) still live in code — canvas and GD have different APIs, so the *rendering* stays dual. But layout zones, palette tokens, font names, decoration list, asset references — all single-source.

## 6. Primitive Library Upgrades

### New primitives

**`historiatedInitial(ctx, x, y, w, h, letter, palette, options)` / `php drawHistoriatedInitial(...)`**
Three-zone parameterized drop-cap. Outer 4-corner-square frame in palette colors, inner field with diaper-pattern overlay, white-vine letter form (font: family-specific), gilded extensions in 2 corners, optional vine extending from one edge into the body margin (when `options.vineDirection` is set). Replaces the existing `drawDropCap`. The existing simple drop cap stays as a fallback for low-emphasis families.

**`gildingGradient(ctx, x, y, w, h, palette, angle = 135)` / `php fillGildedRect(...)`**
Multi-stop linear gradient using `palette.gold` and `palette.gold_highlight`: `gold_dark → gold → gold_highlight → gold → gold_dark`. Used everywhere the current code paints `accent` for a "gold" element (besants, frame extensions, seal embossing, initial corners). Never paint flat gold again.

**`parchmentTexture(ctx, w, h, palette, agingPreset)` / `php applyParchment(...)`**
Layered texture: base palette `bg` color, radial vignette to `ground_a` at edges (40% opacity), fiber-noise overlay (existing 2x2 dot pattern, kept), Poisson-distributed foxing spots (`#5C3F1A`/`#6B4523` at 30%, density per `agingPreset`: `light`/`moderate`/`heavy`). Replaces the current `bg.fillRect` + ad-hoc noise approach.

**`foxingPattern(ctx, w, h, density, palette)`**
Helper called by `parchmentTexture`. Emits N foxing spots at randomized but seeded positions (so the same scroll always foxes the same way). N = `density × area / 10000` (roughly: 50 spots for moderate aging on a 480×624 preview).

**`burntEdgeMask(ctx, w, h, intensity)` / `php applyBurntEdge(...)`**
Family-specific (Charred Edict primarily). Noise-displaced gradient mask burning the perimeter at variable depth. Black-to-transparent radial gradient with perlin noise displacement.

**`foldCreaseOverlay(ctx, w, h, foldPattern)` / `php applyFoldCreases(...)`**
Letter-fold crease lines at 8% black, three vertical lines for the standard letter fold, two horizontal for the fold-in-thirds variant. Family-specific (Charred Edict primarily).

**`banderole(ctx, x, y, w, h, text, palette, options)` / `php drawBanderole(...)`**
Curling ribbon-banner with text along curve. Single-curl and double-curl variants. Used by Provençal Bestiary for motto, optional in others. Text renders along the curve via canvas path-text (Path2D + measureText positioning) or PHP `imagettftext` along sampled curve points.

**`frameFamily(ctx, w, h, palette, familyKey, options)` / `php drawFrame(...)`**
Replaces the 8 individual `drawBorder*` functions. Switches on `familyKey` (`gothic_ivy`, `insular_knot`, `renaissance_white_vine`, `organic_vine`, `gothic_arch`, `romanesque_arch`, `jeweled_cabochon`, `astral_star_pattern`, `minimal_burnt`, `none`) and dispatches to the appropriate frame implementation. Each frame implementation composites four corner assets and four edge tile assets (loaded from family manifest), tinted to palette colors via channel multiplication.

**`waxSealEmboss(ctx, cx, cy, r, palette, sealAsset, ribbonOptions)` / `php drawWaxSeal(...)`**
Replaces the geometric stamped-initials seal. Wax disc with radial gradient (palette `wax` color, lightened 20% at the highlight, darkened 40% at the rim). Embossed `sealAsset` (PNG/SVG of family-specific symbol — lion, fleur, cross, eagle, alchemical sigil, etc.) overlaid in `gold` gradient with 1px inner shadow for the embossed effect. Two diagonal ribbon tails (`palette.wax`, lightened 10%) trailing down-right at varying angles. Asymmetric position at φ from bottom-right corner is the layout convention; primitive itself is position-agnostic.

**`droleries(ctx, x, y, w, h, palette, drolerieAsset)` / `php drawDrolerie(...)`**
Composites a marginalia asset (PNG with transparent bg, hare/snail/grotesque/zoomorphic creature) at given position, optionally tinted to a palette color. Used by Northern Gothic, Provençal Bestiary, Forest Reverie.

**`heraldryMedallion(ctx, x, y, r, heraldryUrl, palette)` / `php drawHeraldryMedallion(...)`**
Gilded ring around a circular-cropped heraldry image. Replaces the current flat heraldry image placement for families that use the medallion convention (Northern Gothic, Crusader's Charter, Imperial Edict). Other families (Heraldic Shield-style) keep direct heraldry composition.

### Updated primitives

- `drawDropCap` → kept as fallback for low-emphasis use; `historiatedInitial` is the new default for body-leading initials.
- `drawWaxSealLarge` → deprecated, removed; `waxSealEmboss` replaces.
- `drawSealElement` → deprecated, removed.
- All 8 `drawBorder*` functions → consolidated into `frameFamily` + 10 frame implementations.
- `drawCornerFlourish` → kept (used as filler decoration); rendered via gilding gradient instead of flat color.
- `drawOrnamentalRule` → kept; gets gilding gradient on the fleur.
- `drawSignatureBar` / `drawSignatureStack` → kept unchanged.

### Removed (no longer needed)

- `drawBorderClassic`, `drawBorderOrnate`, `drawBorderCeltic`, `drawBorderSimple`, `drawBorderRoyal`, `drawBorderRustic`, `drawBorderFiligree` — all replaced by `frameFamily`.
- The `celticknot.js` external script and its options panel — Insular Knotwork frame uses curated knotwork assets, not procedural generation. (The current procedural celtic knot is a known JS↔PHP feature gap; replacing it with assets fixes the gap.)
- The 6 legacy palettes' specific definitions.

## 7. Asset Pipeline

The existing `class.ScrollArtwork` system handles user-uploaded artwork with admin approval. Extend it to host **system-curated public-domain manuscript art** as the family asset packs.

### Storage

New rows in `ork_scroll_artwork` table:
- `system_owned BOOLEAN DEFAULT 0` — flag for curated assets (immune to user delete, served bundled with releases)
- `family_key VARCHAR(64) NULL` — which family owns this asset (`northern_gothic`, etc.)
- `asset_role VARCHAR(64) NULL` — role within the family (`frame_corner_nw`, `drolerie`, `seal_stamp`, etc.)
- `tint_mode ENUM('none','channel_multiply','overlay') DEFAULT 'none'` — how to apply palette tinting at render time
- `source_attribution TEXT NULL` — public-domain source for credit (BNF Gallica MS 12345, BL Add MS 6789, etc.)
- `source_license VARCHAR(64) NULL` — license tag (`PD`, `CC0`, etc.)

Existing user-uploaded artwork (`system_owned=0`, `family_key=NULL`) continues to work as-is.

### Curation

Per-family seed asset packs (~10–15 assets each, ~120 total for v1):

| Asset role | Source preference |
|---|---|
| `frame_corner_*` (4 corners) | Manuscript folio borders, extracted via clipping. BNF Gallica and BL Catalogue are richest. |
| `frame_edge_*` (4 tiles) | Repeating patterns from the same folio. Tile cleanly. |
| `historiated_initial_X` (5–10 letters) | Decorated initials from the same period source. High-frequency letters: A, B, I, T, L, S, W, M, K, R. |
| `drolerie_*` (1–2 per family) | Marginal grotesques. Luttrell Psalter is the gold mine for Gothic. |
| `seal_stamp` (1 per family) | Family-themed silhouette. Often newly drawn or extracted from coats of arms. |
| `banderole` (optional) | Ribbon-banner shape — usually programmatic, but families like Provençal can use a curated one. |

All assets stored as PNG with transparent backgrounds at 600 DPI source resolution (so they scale cleanly to 300 DPI print). Tinting applied at render time via channel multiplication (preserves luminance, swaps hue).

### Seeding

A new migration `db-migrations/2026-04-25-scroll-family-assets.sql` adds the columns. A companion script `system/scripts/seed-scroll-families.php` ingests the seed asset bundle from `system/assets/scroll/families/<family_key>/<role>.png` into the DB on first run.

Asset bundle ships in-repo at `/system/assets/scroll/families/`. ~120 PNGs at ~30 KB each ≈ 3.6 MB committed to the repo. Acceptable for v1.

### Tint pipeline

At render time, for each asset reference:
1. Load source PNG (alpha-preserved).
2. If `tint_mode = 'channel_multiply'`: multiply each non-transparent pixel by the target palette token color. (Preserves shading; converts e.g. red ink to ultramarine.)
3. If `tint_mode = 'overlay'`: composite the asset over a palette-color fill, using the asset's alpha as the mask. (Replaces the asset's color with palette color.)
4. If `tint_mode = 'none'`: composite as-is.

JS canvas: implemented via `globalCompositeOperation = 'multiply'` plus a colored fill rect masked by the asset's alpha channel.
PHP: GD's `imagefilter(IMG_FILTER_COLORIZE)` is **additive**, not multiplicative — it lightens, doesn't replace luminance correctly. Real channel-multiply requires per-pixel manipulation or Imagick. **Decision (v1):** prefer Imagick (`Imagick::compositeImage(Imagick::COMPOSITE_MULTIPLY)`) when available; fall back to a hand-rolled per-pixel multiply via `imagecolorat`/`imagesetpixel` when not. Performance acceptable due to the asset cache (each `<asset, palette>` tinted once, then cached as PNG). Phase 1 validates the Imagick path against the production container before committing.

Asset caching: tinted variants cached server-side (filesystem) keyed on `<asset_id>_<palette_hash>.png`. Cache lifetime indefinite; invalidated when the source asset is replaced.

## 8. Layout Conventions

These become explicit, programmatically enforced constraints rather than per-template ad-hoc choices:

**Density gradient** — every family's `render()` function lays out three zones:
- `density_high` zone (top 25%): title, heraldry medallion, ornamental rule. Ornament density target ≥ 8 elements per 100×100 region.
- `density_mid` zone (middle 55%): body block, historiated initial top-left. Density target ≤ 3 elements (the initial + maybe a vine).
- `density_low` zone (bottom 20%): signatures, wax seal, date. Density target ~5 elements concentrated bottom-right.

**Frame-break** — at least one decorative element per family must extend past or into the body block. Default implementation: vine from historiated initial extending 30–50px into top/right margin. Families without an initial (Charred Edict, Imperial Edict) substitute a different break: a banderole that overlaps the frame, a drôlerie peering into the text block, etc.

**Asymmetric seal placement** — wax seal positioned at golden ratio from bottom-right corner: `(1−0.382) × w` from left, `(1−0.382) × h` from top, with diagonal ribbon tails. Imperial Edict and Astral Codex are exceptions (axial-symmetric layouts) and use a centered seal at the bottom.

**Three-zone vertical default** — title/heraldry top 25%, body 55% with 3–7-line historiated initial top-left, signature/seal bottom 20%. Battle Standard (renamed and absorbed into Northern Gothic landscape variant or kept as a separate orientation) overrides.

**Real ink colors** — `#000000` and `#FFFFFF` are banned palette values. Linter check at family-manifest load time rejects any family palette containing pure black or white.

## 9. Auto-Template Mapping (Updated)

Replaces the current `sgAutoTemplate` logic in `Scroll_builder.tpl:19-29`:

| Award type / context | Recommended family |
|---|---|
| Knighthood (AwardId in [17,18,19,20,245]) | Crimson Decree |
| Title / peerage (`IsTitle = 1`) | Northern Gothic |
| Ladder award / order (`IsLadder = 1`) | Hibernian Knotwork |
| Master peerage (top of ladder) | Scholar's Hand |
| Battle / martial award (Order of the Warrior, Battlemaster) | Charred Edict |
| Bardic / artistic award (Garber, Mask, Owl) | Provençal Bestiary |
| Service award (Smith, Service, Lion) | Forest Reverie |
| Magical / arcane / research-themed | Astral Codex |
| Religious / chivalric order | Crusader's Charter |
| Empire-wide proclamation | Imperial Edict |
| Custom / unrecognized | Northern Gothic (default) |

Mapping is suggestion, not enforcement — user can override via the family picker. Mapping logic lives in PHP (`controller.Scroll.php`) and is mirrored to JS via SgConfig.

## 10. Builder UI Changes

### Replaced
- **Template picker** — 8 cards become 10 family cards. Each card shows: family name, period descriptor, mini live preview (frame motif + title font sample + palette swatches). Selecting a family applies its palette + fonts + frame in one click.
- **Palette picker** — 12 swatches become 10 family palettes. In v1, palette is locked to family choice (changing palette changes family). v1.1 unlocks mix-and-match.
- **Border picker** — 8 styles become irrelevant; replaced by family selection. Removed from UI entirely. (Frame style is determined by family.)
- **Celtic knot options panel** (strand thickness, colors) — removed; Insular Knotwork uses curated assets.

### Kept
- Element toggles (8 switches) — pruned to family-relevant set per family. E.g., Crimson Decree shows Wax Seal, Historiated Initial, Heraldry Medallion toggles; Charred Edict shows Burnt Edge, Fold Creases, Wax Seal.
- Font slot pickers (4 slots × 21 fonts, expanded as needed for new families) — defaults set by family, user can override.
- Heraldry toggles (3 switches, kingdom/park/player) — unchanged.
- Award details fields, signatures (1–3), artwork slots (8) — unchanged.
- Award name, recipient, body, given-by — unchanged.

### Added
- **Decoration intensity slider** — `light` / `balanced` / `heavy`. Light skips drôlerie, foxing, and aging. Heavy adds extra marginalia and stronger aging. Balanced is the default. Wired into `parchmentTexture` aging preset and decoration toggle defaults.

### CSS (dark mode)
All new builder UI must be dark-mode compatible per project hard rule. Family card thumbnails work in both modes (parchment is still parchment); UI chrome (cards, swatches, slider) follows existing `data-theme="dark"` overrides.

## 11. Render Pipeline

Architecture stays: JS canvas preview at 850×1100 (portrait) / 1100×850 (landscape), PHP GD export at 2550×3300 / 3300×2550 (3× scale).

### Render order (per scroll)
1. Fill `bg` palette color.
2. `parchmentTexture(ctx, w, h, palette, agingPreset)` — fiber noise + foxing.
3. Radial vignette to `ground_a` at edges.
4. (Charred Edict only) `burntEdgeMask`.
5. (Charred Edict only) `foldCreaseOverlay`.
6. Watermark artwork slot (existing).
7. `frameFamily(ctx, w, h, palette, familyKey)` — composites corner + edge tiles, tinted.
8. Full-border / edge / top-graphic artwork slots (existing).
9. Family-specific `render(ctx, w, h, state, palette)` function — dispatches title, heraldry, historiated initial, body, drôlerie, signatures, wax seal in zone order.

### Family-specific renderers

10 functions, each ≤ 80 lines:
- `renderHibernian(ctx, w, h, state, palette)` — Insular Knotwork frame, body-centered title, knotwork triskele corners, no historiated initial in v1 (v1.1 adds Insular initials).
- `renderNorthernGothic(...)` — historiated initial top-left, ivy frame with gilded besants, drôlerie bas-de-page, asymmetric red wax seal w/ embossed lion.
- `renderProvencalBestiary(...)` — asymmetric ivy with grotesques, banderole motto, no full frame.
- `renderCrimsonDecree(...)` — Gothic arch architectural frame, gold ground panel behind initial, oversized red wax seal w/ double diagonal ribbon, gilded fleurs at corners.
- `renderForestReverie(...)` — organic vine breaking border, leaf rosettes, green wax seal.
- `renderCharredEdict(...)` — burnt edges, fold creases, foxing-heavy aging, off-center black wax with broken ribbon, minimal frame.
- `renderImperialEdict(...)` — gold-ground top third, jeweled cabochon border, axial symmetry, icon-style heraldry medallion.
- `renderScholarsHand(...)` — white-vine bianchi girari frame on tri-color ground, classical urn at top, restrained gilding.
- `renderCrusaders(...)` — Romanesque round-arch frame, lion/eagle supporters flanking heraldry, jeweled cross at top, triumphal-arch composition.
- `renderAstralCodex(...)` — dark celestial ground, silvered frame with star-pattern, zodiac glyphs, alchemical seal.

Each renderer exists in both JS (in `Scroll_builder.tpl`) and PHP (in `controller.ScrollAjax.php`). Layout zones, font slots, palette tokens, asset references all sourced from `families.json` so the duplication is in API surface only — coordinates and decoration choices come from the manifest.

### Feature parity

The Celtic-knot-style preview/export drift caused by the JS-vs-PHP procedural mismatch is resolved by replacing procedural knotwork with curated assets. Going forward, a CI check runs both renderers against a fixed input set and pixel-diffs the output: tolerance ≤ 1% per channel for non-text regions.

## 12. Data Model Changes

### `ork_scroll_artwork` (extension)
```sql
ALTER TABLE ork_scroll_artwork
  ADD COLUMN system_owned TINYINT(1) NOT NULL DEFAULT 0,
  ADD COLUMN family_key VARCHAR(64) NULL,
  ADD COLUMN asset_role VARCHAR(64) NULL,
  ADD COLUMN tint_mode ENUM('none','channel_multiply','overlay') NOT NULL DEFAULT 'none',
  ADD COLUMN source_attribution TEXT NULL,
  ADD COLUMN source_license VARCHAR(64) NULL,
  ADD INDEX idx_family_role (family_key, asset_role);
```

Migration file: `db-migrations/2026-04-25-scroll-family-assets.sql`.

### Static config files
- `/orkui/template/revised-frontend/scroll/families.json` — single source of truth for family definitions.
- `/system/assets/scroll/families/<family_key>/*.png` — per-family asset bundle (committed to repo).
- `/system/assets/scroll/fonts/*.ttf` — existing PHP font directory, extend with new family fonts (UnifrakturCook, IM Fell DW Pica, Cardo SC if not already present, Pirata One). Verify via `controller.ScrollAjax.php:202-228` `$FONTS` map.

### `SgConfig` (additions)
- `family` — current selected family key (replaces `template`)
- `decorationIntensity` — `light` | `balanced` | `heavy`
- `families` — full manifest inlined for client-side use
- (Removed) `palette` field — now derived from family.
- (Removed) `borderStyle` field — now derived from family.

### Migration of existing in-flight builders
None required. The builder is single-session — there's no persisted "draft scroll" state. Users who hit the page after deploy see the new picker.

## 13. Backwards Compatibility

- **Existing generated PNG scrolls** — unaffected (output PNGs already downloaded).
- **Existing builder URLs** — `/Scroll/index/{playerId}/{awardId}` continues to work; loads with the new picker.
- **Old `template` query param** — if present and matches a legacy template name, redirect-map to nearest family equivalent: `royal_decree → crimson_decree`, `heraldic_shield → crimson_decree`, `chancery_letter → scholars_hand`, `illuminated_ms → northern_gothic`, `battle_standard → charred_edict` (landscape), `guild_charter → crusaders_charter`, `arcane_grimoire → astral_codex`, `bardic_ballad → provencal_bestiary`. Logged via `error_log` for the first month so we can audit usage.
- **Old palettes / borders** — no in-flight consumers (single-session builder), removed cleanly.
- **`controller.ScrollAjax.php` API contract** — `POST /ScrollAjax/generate` accepts the new `family` field; rejects requests with old `template`+`palette`+`borderStyle` shape with a clear error pointing to the new shape. (User-facing builder always sends the new shape; only old bookmarks or scripted callers would hit this.)

## 14. Testing

### Visual regression

CI test: render all 10 families with a fixed input fixture (same recipient name, award name, body text, signatures, heraldry stubs) on both renderers. Pixel-diff JS-canvas output (rendered to PNG via headless Chrome) against PHP-GD output. Tolerance ≤ 1% per-channel on non-text regions. Failures block merge.

Snapshot test: render all 10 families with the same fixture, store result PNGs in `tests/scroll/snapshots/`. PR that changes any family must update its snapshot intentionally; uncommitted snapshot diffs fail CI.

### Unit-level

- `families.json` schema validation: required fields per family, palette token presence, asset path resolution.
- Palette linter: rejects `#000000` / `#FFFFFF`; rejects malformed hex; requires `bg`, `text`, `accent`, `border`, `gold`, `gold_highlight` minimum.
- Asset existence check: every `assets.*` path in `families.json` resolves to a real file under `/system/assets/scroll/families/`.
- Tint pipeline: `channel_multiply` and `overlay` produce expected outputs against synthetic test images.
- Font availability: every `fonts.*` value in `families.json` exists in `$FONTS` PHP map and as a Google Font in the JS font preload list.

### Manual QA per family

For each of 10 families, manually verify:
1. Builder picks the family by default for the matching auto-template type.
2. Preview renders without console errors.
3. Export renders to PNG at 300 DPI, identical (within tolerance) to preview.
4. Element toggles work — turning off historiated initial falls back to drop cap; turning off seal removes seal cleanly.
5. Long award names / recipient names don't break layout (tested with 80-char inputs).
6. Heraldry images (kingdom/park/player) display correctly when present, gracefully when missing.

## 15. Build Order

Phasing is dev-internal — all 10 families ship together as v1. This is the order of work, not staged release.

### Phase 1: Foundation (~3 days)
- Extend palette token system to 8 tokens; add `gold`, `gold_highlight`, `wax`, `ground_a`.
- Build `parchmentTexture` (replaces ad-hoc bg + noise + vignette).
- Build `gildingGradient` primitive (JS canvas + PHP GD parallel).
- Build palette linter; remove legacy 12 palettes.
- Load new fonts (UnifrakturCook, Cardo, Cardo SC, Pirata One, IM Fell DW Pica) in JS @import and copy TTFs into `/system/assets/scroll/fonts/`. Update `$FONTS` map.

### Phase 2: Family manifest + 10 family stubs (~2 days)
- Author `families.json` with all 10 family definitions (palettes + fonts + layout + decoration list, but with frame/asset paths still pointing at placeholders).
- Wire JS to load `window.SC_FAMILIES` from inline JSON; wire PHP to load same via `json_decode`.
- Replace `TEMPLATES` references with `SC_FAMILIES` lookups in both renderers.
- Remove dual `TEMPLATES` and `$TEMPLATES` arrays.
- Render all 10 families using only the foundation primitives — output is "all families look pretty similar" but the manifest plumbing works end-to-end.

### Phase 3: Frame families (~5 days)
- Build `frameFamily` primitive (JS + PHP).
- Implement frame compositing (4 corners + 4 edge tiles, tinted via channel-multiply).
- Curate seed frame asset packs for all 10 families: 80 frame assets total (8 per family × 10 families). Source from BNF Gallica, BL, Met, Wikimedia.
- Wire frame asset paths into `families.json`.
- Remove the 8 legacy `drawBorder*` functions.
- Remove `celticknot.js` external dependency.

### Phase 4: Historiated initial (~3 days)
- Build `historiatedInitial` primitive (JS + PHP).
- Three-zone implementation: outer 4-corner-square frame, inner field with diaper pattern, white-vine letter form, gilded extensions, optional vine extension.
- Family-specific styling (Northern Gothic = ivy extensions; Crimson Decree = gold ground; Forest Reverie = organic leaf form; etc.).
- Wire to all families that use it (8 of 10; Charred Edict and Imperial Edict use other openings).

### Phase 5: Wax seal + banderole (~2 days)
- Build `waxSealEmboss` primitive (JS + PHP).
- Curate 10 family-themed seal stamps (lion, fleur, cross, eagle, leaf, etc.).
- Build `banderole` primitive (JS + PHP) for families that use it.
- Asymmetric placement at φ from corner.

### Phase 6: Family-specific renderers (~5 days)
- Implement 10 `render*` functions in JS and PHP, one per family.
- Each composes the family's full visual signature using foundation + frame + initial + seal primitives.
- Curate per-family drôlerie/marginalia assets (~20 total).
- Wire decoration intensity slider.

### Phase 7: Aging filter stack (~2 days)
- Build `burntEdgeMask`, `foldCreaseOverlay` for Charred Edict.
- Build `foxingPattern` (already partially in `parchmentTexture` — extract for reuse).
- Wire to Charred Edict and the "heavy" decoration intensity preset for any family.

### Phase 8: Builder UI (~3 days)
- Replace template picker with family picker (10 cards with mini previews).
- Remove palette picker, border picker, celtic options panel.
- Add decoration intensity slider.
- Update `auto-template` mapping to `auto-family` (controller-side + JS-side mirror).
- Dark-mode pass on all new UI.

### Phase 9: Migration + cleanup (~2 days)
- Run migration `2026-04-25-scroll-family-assets.sql`.
- Run seed script `seed-scroll-families.php`.
- Add backward-compat redirect for old `template` query params.
- Remove legacy template/palette/border code paths.
- Update `controller.Scroll.php` `SgConfig` shape.

### Phase 10: Tests + visual regression CI (~2 days)
- Author 10 family snapshot fixtures.
- Wire JS-vs-PHP pixel-diff CI check.
- Author palette / asset-existence linters.
- Manual QA per family.

**Total estimate: ~29 working days (~6 weeks)** for a single dev. Compresses to ~4 weeks with parallelism on phases 3–7 (asset curation parallel to renderer work).

## 16. Risks and Open Questions

### Risks

**Asset sourcing pace.** Curating 120 PD manuscript assets at print quality is the long pole. Mitigation: start in phase 1 by farming the curation work to a sub-agent or contract artist; don't block on it. Each family can ship with fewer than the target asset count if curation slips — degrade to programmatic frame for that family until assets land.

**Public-domain provenance.** Some Wikimedia Commons items have unclear or contested PD status. Mitigation: prefer institutional sources (BNF, BL, Met, Getty Open Content) which assert PD/CC0 explicitly; document `source_attribution` and `source_license` per asset; legal review on first batch.

**JS-PHP renderer drift recurring.** New primitives in dual-implement form risk the same drift the Celtic knot showed. Mitigation: visual regression CI from phase 1; both implementations share the same `families.json` configuration; render-function bodies are short (≤ 80 lines each) and structurally parallel.

**Font licensing.** All recommended fonts are SIL Open Font License or similar permissive — verify before bundling TTFs into the repo.

**Asset bundle size.** 120 assets × ~30KB ≈ 3.6 MB committed to repo. Acceptable for v1. If it grows past 10 MB consider moving to a CDN or release artifact.

**Imagick dependency.** Per section 7, PHP GD's colorize filter is additive, not channel-multiply. Imagick is the preferred path. Risk: Imagick may not be installed in the production container. Mitigation: phase 1 first task is to verify `extension_loaded('imagick')` in the prod-equivalent Docker container (`ork3-php8`); if missing, install via dockerfile update before any other work proceeds. The hand-rolled per-pixel fallback is acceptable as a backup but slower for first-render of un-cached assets.

### Open questions for user review

None gating the design. Spec proceeds to writing-plans on user approval. Implementation discoveries surfaced during phase 1 may prompt follow-up clarifications, escalated as they arise.

## 17. Out of Scope (Reserved for v1.1+)

- Full A–Z historiated initial library per family.
- Mix-and-match family bundles (palette from A, frame from B, fonts from C).
- User-editable palette colors.
- PDF export with embedded fonts.
- A4 / letter / poster page sizes.
- Animated scroll preview (e.g., hover-to-zoom heraldry).
- AI-generated marginalia per scroll (from award context).
- SVG-master template renderer (the v3 horizon).
- Per-scroll asset upload of custom decorative elements (artwork system already supports admin-approved generic uploads; per-scroll customization is a separate UX problem).
- Multi-language scroll text (date format localization, body text generation in non-English languages).

---

## Appendix A: Anti-Pattern Checklist

These patterns are explicitly forbidden in v1 and any v1+. The visual regression CI snapshot tests will catch most; a code-review checklist catches the rest:

- ✗ Pure black ink (`#000000`) or pure white ground (`#FFFFFF`).
- ✗ Flat gold (`#FFD700` painted as `fillStyle`); gold must always be a gradient.
- ✗ Wax seal centered at bottom of page (only Imperial Edict and Astral Codex are exempt).
- ✗ Decoration density uniform across the page.
- ✗ Frame never broken by any decorative element.
- ✗ Title and body in the same font face.
- ✗ Heraldry rendered as an unframed flat clip-art shield (must be in a medallion or with mantling/supporters).
- ✗ Procedurally drawn celtic knots (use curated assets).
- ✗ Stamped-initials wax seal with radial ticks (use family seal stamp).
- ✗ Symmetric four-corner clip-art flourishes with empty edges between them.

## Appendix B: Sources & Attribution

Public-domain manuscript collections targeted for asset curation:

- **British Library Catalogue of Illuminated Manuscripts** (`bl.uk/catalogues/illuminatedmanuscripts/welcome.htm`) — Western European Gothic primary source.
- **BNF Gallica** (`gallica.bnf.fr`) — French Gothic, Très Riches Heures.
- **The Met Open Access** (`metmuseum.org/art/collection`) — CC0; Cloisters Apocalypse, Belles Heures.
- **Wikimedia Commons Illuminated Manuscripts** category — verify per-image licensing.
- **Public Domain Review** (`publicdomainreview.org`) — curated marginalia (Luttrell Psalter drôleries).
- **Getty Open Content** (`getty.edu/art/collection`) — CC0; Stammheim Missal, Spitzer Hours.
- **Trinity College Dublin Digital Collections** — Book of Kells (Insular sourcing).
- **e-codices** (`e-codices.unifr.ch`) — Swiss medieval manuscripts.

Game-icons.net (CC-BY 3.0) for fantasy-themed primitives (wax seal sigils, swords, scrolls) where authentic medieval art doesn't exist for the family (e.g., Astral Codex alchemical glyphs).
