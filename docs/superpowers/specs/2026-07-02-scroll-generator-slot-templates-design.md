# Scroll Generator — Slot-Based Templates (rebuild)

**Date:** 2026-07-02
**Branch:** `feature/scroll-generator`
**Status:** Design approved, spec under review

## Summary

Scrap the procedural illuminated-manuscript engine ("Scroll Forge" families/ornaments)
and rebuild the award-scroll generator around **slot-based templates**: a fixed
Letter-ratio page with a **central, auto-scaling text area** made of labeled text
zones, surrounded by **graphic slots** (borders, corners, side panels, shields, a
large illustration) filled from an artwork library, auto-pulled heraldry, or built-in
decorative packs. Some text is auto-filled from the award/player via `{tokens}`.

Kingdom officers **design** reusable templates (place slots + zones, set fonts/defaults,
fixed positions); award granters **fill** them (pick template → tokens auto-resolve →
tweak wording → download a PDF).

This design is driven by four reference scrolls: a full illuminated vine border with a
justified Latin body + drop-cap name; a picture-initial illuminated manuscript; a
landscape piece with two corner heraldry shields and a large bottom illustration on a
gradient; and a rose-trellis parchment with signature lines. The common thread — a
scaling central text block plus freely-placeable edge/side/corner graphics — is the
target the rebuild must reproduce.

## Goals

- Reproduce the *structure* of all four reference scrolls via slots + text zones
  (not necessarily the exact hand-drawn art, which comes from the artwork library).
- Central text area that dynamically scales to fill its space.
- Graphics placeable as: full border, single-edge border, corners, side panel,
  top shields, large center/bottom illustration, watermark.
- Auto-fill recipient/award/date/kingdom/etc. from the award-grant context.
- Portrait **and** landscape, both printing to 8.5×11 Letter.
- One-click **direct PDF download**.
- Kingdoms author and save their own templates; shared starter templates ship.

## Non-Goals

- No procedural ornament generation (SVG vine borders, Celtic knot generators,
  historiated drop-cap alphabets, per-family palettes/fonts). All decoration is
  raster/vector *assets* placed into slots.
- No gradient backgrounds (deferred; solid / texture / full-bleed image only).
- No free-drag repositioning by the *filler* — positions are fixed per template.
- No selectable-vector text in the PDF (client-side raster is accepted).
- Player/persona scroll variants beyond award grants (out of scope for v1).

---

## Scope: Scrap vs. Keep

### Scrap (procedural engine, ~20k+ lines)

- **Font/ornament families:** all `orkui/template/revised-frontend/scroll-forge/families/family-*.css.part`,
  `scroll/families.json`, `system/scripts/seed-scroll-families.php`,
  `class.ScrollFamilyRenderer.php`, `class.ScrollPalette.php`.
- **Procedural decoration:** `class.ScrollDecoration.php`, `class.ScrollPrimitives.php`,
  `scroll/scroll-decoration.js`, `scroll/scroll-primitives.js`, `scroll/scroll-families.js`,
  `scroll/scroll-palette.js`, `assets/scroll/celticknot.js`.
- **Forge system:** every `scroll-forge/sf-*.css.part` / `*.html.part` / `sf-app.js.part`,
  the versal/motif/flourish composers, the SVG frame generators, the inliner build step
  (`tools/scroll_forge_inline.py` / `inline_forge.py`), and the 14k-line
  `Scroll_builder.tpl` (replaced with a lean template).
- **Canvas render templates:** the 5 hardcoded layouts (royal_decree, heraldic_shield,
  chancery_letter, illuminated_ms, battle_standard) in `controller.ScrollAjax.php`.
- **Ornament assets:** `system/assets/scroll/forge/{grounds,alphabets,motifs,flourishes}`
  and per-family frame/seal PNGs under `system/assets/scroll/families/`.
- **Tests:** the family/ornament/gilding/versal/grounds/manifest tests under `tests/scroll/`.

### Keep & reuse

- **Artwork library:** `ork_scroll_artwork` + `ork_scroll_artwork_category` tables,
  `class.ScrollArtwork.php`, `controller.ScrollArtworkAjax.php`, `controller.ScrollGraphics.php`,
  `style/scroll-graphics.css`. Its `layout_location` enum
  (`full_border`, `border_left/right/top/bottom`, `center_image`, `watermark`, `top_graphic`)
  becomes the **slot vocabulary**. Upload / browse / moderation / kingdom-sharing stay.
- **Heraldry auto-pull:** `class.Heraldry.php` and the kingdom/park/player heraldry URL
  resolution already in `controller.Scroll.php::builder()`.
- **Fonts:** the 20 TTFs in `assets/scroll/fonts/` feed the per-zone font picker.
- **Route:** `Scroll/builder/{mundaneId}/{awardId}` as the *filler* entry point.

---

## Architecture

Everything renders as **semantic HTML/CSS on a fixed Letter-ratio page** — real
webfonts, fit-to-viewport preview, print/PDF to 8.5×11. No canvas renderer, no
procedural SVG.

### Routes

| Route | Who | Purpose |
|---|---|---|
| `Scroll/design/{kingdomId}` and `Scroll/design/{kingdomId}/{templateId}` | Kingdom officers (`AUTH_KINGDOM`) | **Layout maker** — place slots & zones, set defaults, save reusable template |
| `Scroll/builder/{mundaneId}/{awardId}` | Award granters | **Filler** — pick template, auto-fill tokens, edit text, download PDF |
| `ScrollTemplateAjax/*` | both | Template CRUD (list / load / save / delete / share) |

Auth: the designer requires `AUTH_KINGDOM` over `{kingdomId}` (principality traversal
via `HasAuthority` applies). The filler requires whatever authority already gates
`Scroll/builder` today (viewing/granting the award).

### Shared page renderer

A single render module drives both surfaces (designer = fully editable; filler =
text-editable only, positions locked):

- Fixed page `<div>`, `aspect-ratio` `8.5/11` (portrait) or `11/8.5` (landscape),
  scaled-to-fit the stage (reuse the old `fitScroll` scale-to-container idea, minus
  the family machinery).
- **Background layer:** solid color · parchment/paper texture (curated set) ·
  full-bleed uploaded image. Stored as `bg_type` + `bg_value`.
- **Graphic slots:** absolutely-positioned boxes keyed to `layout_location`. Each holds
  one graphic (library / heraldry / built-in pack). Designer sets position + size;
  fixed thereafter. `object-fit: contain` keeps art undistorted.
- **Text zones:** a set of labeled zones (salutation, recipient, award title, body,
  date, signature — extensible). Each zone stores its own font / size / min-max / align /
  color / color-inherit and text with `{tokens}`. The **body** zone auto-scales to fit
  its box; single-line zones (name/award) scale within `[min,max]` to avoid overflow.

### Data model per template (JSON columns)

```
slots: [ { location, x, y, w, h, source_type, source_ref, fit } ]
       source_type ∈ { library, heraldry, pack, none }
       source_ref  = artwork id | heraldry kind (kingdom|park|player) | pack asset key
zones: [ { key, label, text, font, size, min, max, align, color, inherit_color,
           x, y, w, h, autoscale } ]
```

Coordinates are stored as **percentages of the page box** so the same template renders
identically at preview scale, print scale, and either orientation's page size.

---

## Token / fill system

The filler resolves `{tokens}` from the grant context `controller.Scroll.php` already
loads. Unknown tokens show an "unfilled" chip in the editor and print blank.

| Token | Source |
|---|---|
| `{PlayerName}` | player persona |
| `{AwardName}` | award being granted |
| `{Kingdom}` / `{Park}` | player's org |
| `{Date}` | grant date, human-formatted (optional Anno Amtgardia line) |
| `{GivenBy}` | granting officer / signer |
| `{Reason}` | award reason text if present |

Designer inserts tokens via buttons; the filler can still retype any zone's wording.

---

## Backgrounds

- **Solid color:** hex, stored in `bg_value`.
- **Texture:** a small curated set of paper/parchment/vellum images shipped under
  `system/assets/scroll/textures/`; `bg_value` = texture key.
- **Full-bleed image:** a designer-chosen artwork (library upload) fills the page behind
  everything; `bg_value` = artwork id.

Gradient backgrounds are deferred (not in v1).

---

## PDF export

**Client-side raster.** Vendor `jsPDF` + `html2canvas` (same "vendor a pure lib" pattern
as the xlsx export; `vendor/` is gitignored so assets are `git add -f`'d). On *Download
PDF*: clear the preview transform, render the page at high DPI to a canvas, place it into
a Letter-size (portrait or landscape) `jsPDF` page, and trigger a direct file download.
No server round-trip; no headless Chromium dependency. Text is rasterized — acceptable at
print DPI for a decorative scroll. A server-side headless-Chrome path is a possible future
fidelity upgrade but is out of scope.

Print stylesheet still targets `@page size: letter` for browsers that Print → Save as PDF.

---

## Database changes

None of the four existing scroll migrations are in `master`; all are branch-only and may
be rewritten before merge. The local DB has all four applied and holds **30 rows, all
`system_owned=1`** (family frame/seal assets pointing at art being deleted) and **zero
real user uploads** — safe to purge.

1. **`2026-04-04-scroll-artwork.sql`** — KEEP unchanged (core library table; its
   `layout_location` enum is the slot vocabulary).
2. **`2026-04-25-scroll-family-assets.sql`** — REWRITE. Drop the family-only columns
   `family_key`, `asset_role`, `tint_mode`; retain `system_owned` (repurposed to flag
   built-in decorative packs) and `source_attribution` / `source_license` (pack
   licensing). Update the file to add only the retained columns.
3. **`2026-06-19-scroll-artwork-categories.sql`** — KEEP (category browsing).
4. **`2026-06-19-scroll-submissions-tiers.sql`** — KEEP (`visibility` / `owner_kingdom_id`
   / `category_id` kingdom-scoped sharing).
5. **NEW `2026-07-02-scroll-template.sql`** — `ork_scroll_template`:

```sql
CREATE TABLE `ork_scroll_template` (
  `scroll_template_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `kingdom_id`        INT UNSIGNED NULL,            -- NULL = shared starter
  `name`              VARCHAR(150) NOT NULL,
  `orientation`       ENUM('portrait','landscape') NOT NULL DEFAULT 'portrait',
  `bg_type`           ENUM('color','texture','image') NOT NULL DEFAULT 'color',
  `bg_value`          VARCHAR(255) NOT NULL DEFAULT '#ffffff',
  `slots`             JSON NOT NULL,
  `zones`             JSON NOT NULL,
  `is_starter`        TINYINT(1) NOT NULL DEFAULT 0,
  `status`            ENUM('active','archived') NOT NULL DEFAULT 'active',
  `created_by`        INT UNSIGNED NOT NULL,
  `created_at`        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `modified`          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`scroll_template_id`),
  KEY `idx_kingdom_status` (`kingdom_id`, `status`),
  KEY `idx_starter` (`is_starter`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

6. **Local-DB reconciliation** (run once on the shared local DB to match the rewritten
   migration): `DELETE FROM ork_scroll_artwork WHERE system_owned = 1;` then
   `ALTER TABLE ork_scroll_artwork DROP COLUMN family_key, DROP COLUMN asset_role,
   DROP COLUMN tint_mode, DROP INDEX idx_family_role;` (keep `system_owned`,
   `source_attribution`, `source_license`, `idx_system_owned`).

Kingdoms see: starter templates (`is_starter=1`, `kingdom_id` NULL) + their own kingdom's
templates.

---

## New / changed backend files

| File | Change |
|---|---|
| `system/lib/ork3/class.ScrollTemplate.php` | NEW — template CRUD, JSON encode/decode, starter seeding, kingdom-scoped list, `$DB->Clear()` before writes. |
| `orkui/controller/controller.ScrollTemplateAjax.php` | NEW — list/load/save/delete/share endpoints; `AUTH_KINGDOM` gate; CSRF per project convention. |
| `orkui/controller/controller.Scroll.php` | MODIFY — `builder()` keeps award/player/heraldry loading, drops family data; add `design()` action. |
| `orkui/model/model.ScrollTemplate.php` | NEW — thin pass-through per architecture layers. |
| `orkui/controller/controller.ScrollAjax.php` | DELETE (canvas render templates) or reduce to nothing if any non-scroll caller — verify none. |
| `class.ScrollFamilyRenderer.php`, `class.ScrollPalette.php`, `class.ScrollDecoration.php`, `class.ScrollPrimitives.php` | DELETE. |
| `system/scripts/seed-scroll-families.php` | DELETE; replace with `seed-scroll-templates.php` (starter templates) + a built-in-pack seeder. |

## New / changed frontend files

| File | Change |
|---|---|
| `orkui/template/revised-frontend/Scroll_builder.tpl` | REPLACE with a lean filler page (template picker, editable text zones, download button). |
| `orkui/template/revised-frontend/Scroll_design.tpl` | NEW — designer page (slot/zone placement, font/size/color inspector, save/share). |
| `orkui/template/revised-frontend/scroll/scroll-render.js` | NEW — shared page renderer (background, slots, zones, fit-to-page, token resolve). |
| `orkui/template/revised-frontend/scroll/scroll-builder.js` | NEW — filler logic (load template, resolve tokens, edit zones, PDF). |
| `orkui/template/revised-frontend/scroll/scroll-design.js` | NEW — designer logic (drag placement → % coords, inspector, save). |
| `orkui/template/revised-frontend/style/scroll.css` | NEW — page/slot/zone/inspector styles; dark-mode chrome, light scroll surface. |
| `scroll/scroll-decoration.js`, `scroll-primitives.js`, `scroll-families.js`, `scroll-palette.js`, `families.json`, `assets/scroll/celticknot.js` | DELETE. |
| `scroll-forge/` (entire dir), `tools/scroll_forge_inline.py`, `inline_forge.py` | DELETE. |
| `vendor` jsPDF + html2canvas | ADD (force-add). |

## Assets

- KEEP `assets/scroll/fonts/` (20 TTFs) — per-zone font picker.
- ADD `system/assets/scroll/packs/{borders,backgrounds,orders}/` seeded from **Alona of
  Two Trees' CC art library** (free personal + commercial use; see
  `2026-07-02-alona-cc-art-library.md` for folder IDs, license, mappings, re-fetch script).
  These become the built-in decorative packs as `ork_scroll_artwork` `system_owned=1` rows
  (borders → `full_border`/side slots; backgrounds → `bg_type=image`/texture; order emblems
  → `center_image`, name-mapped to `{AwardName}`). Ship an `ATTRIBUTION.md` crediting Alona.
- DELETE `system/assets/scroll/forge/*` and `system/assets/scroll/families/*`.

---

## Build sequence (phased, subagent-driven, review between phases)

1. **Excision** — delete scrapped files/assets; strip forge route wiring; rewrite the
   `2026-04-25` migration; add the local-DB reconciliation; leave a minimal
   `Scroll_builder.tpl` stub. Verify the app boots and no dangling includes/route refs.
2. **Data layer** — `ork_scroll_template` migration + `class.ScrollTemplate.php` +
   `model.ScrollTemplate.php` + `controller.ScrollTemplateAjax.php` (CRUD, auth, CSRF).
3. **Shared renderer** — `scroll-render.js` + `scroll.css`: fixed Letter page (both
   orientations), background layer, slot boxes (% coords), text zones with auto-scale,
   token resolver, fit-to-stage.
4. **Filler** — rebuild `Scroll/builder`: template picker → auto-fill tokens → edit
   zones → client-side PDF download (vendor jsPDF + html2canvas).
5. **Designer** — `Scroll/design`: drag-place slots/zones (persist % coords), font/size/
   color inspector, background chooser, save/share; seed 2–3 starter templates matching
   the references (illuminated full-border, rose-trellis parchment portrait, landscape
   shields + bottom illustration).
6. **Polish/QA** — dark-mode chrome, print/PDF fidelity across both orientations,
   token-resolution + auth + overflow-scaling tests; refresh `tests/scroll/`.

## Testing

- Template CRUD + kingdom scoping + starter visibility.
- Token resolution (all tokens, unknown token → blank, unicode/long names).
- Auto-scale: long body text and long recipient names stay within their boxes.
- Both orientations render at correct Letter aspect and print/PDF at 8.5×11 / 11×8.5.
- Auth: designer gated to `AUTH_KINGDOM`; filler gated as today.
- Dark-mode chrome; scroll surface stays light.

## Open questions / risks

- **`controller.ScrollAjax.php` callers** — confirm nothing outside the scroll builder
  calls its endpoints before deleting.
- **html2canvas fidelity** — verify texture backgrounds + `object-fit: contain` graphics
  rasterize faithfully; if a specific CSS feature breaks, constrain the renderer to what
  html2canvas supports.
- **Built-in pack sourcing** — RESOLVED: seeded from Alona of Two Trees' CC library
  (`2026-07-02-alona-cc-art-library.md`); 62 files retrieved + verified on 2026-07-02.
  Remaining ingestion follow-ups (empty Orders sub-folders, Heraldry legacy folder,
  transparency spot-check, curated default subset) tracked in that doc.
- **Order-emblem name mapping** — the Orders folders are named by award type (Crown,
  Dragon, Rose, Owl, Smith…), enabling `{AwardName}` → `center_image` emblem suggestion in
  the filler. Wire this into the token/slot system in the designer + filler phases.
