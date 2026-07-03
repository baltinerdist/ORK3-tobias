# Scroll Forge Illumination Redesign — Design Spec

**Date:** 2026-07-02
**Status:** Approved (brainstormed with Avery; Q&A decisions recorded below)
**Branch:** `feature/scroll-generator` — ships as part of "Dragon II" (~3.5.7/3.5.8)

## Problem

The current Scroll Forge output reads as computer-generated. The user's assessment
(confirmed by side-by-side review against five reference scrolls): the scrolls need
to feel hand-drawn, calligraphed, and illuminated — less CG.

Root cause is structural, not tuning: **every visual element on the sheet is a
geometric primitive.**

1. **Borders are rectangles.** The frame is 2–4 nested SVG `<rect>` strokes plus
   corner `<circle>` besants (`sf-scroll-markup.html.part`). "Hibernian Knotwork —
   Celtic interlace" renders as flat navy rules. The reference scrolls' identity is
   ~80% dense ornamental border (interlace, foliate drollery, pen filigree).
2. **Texture is feTurbulence noise.** Reads as Photoshop-clouds mottle: uniform,
   fiberless, no scan character.
3. **Gilding is a CSS gradient.** Reads as WordArt bevel/emboss; real gilding and
   period lettering are matte and ragged-edged.
4. **Type is set, not lettered.** Perfectly kerned, evenly-baselined webfont
   blackletter is exactly what "computer-generated" looks like. References get
   their calligraphed feel from swash flourishes off the display lettering.
5. **No figurative art.** Every reference has an inhabitant (jester, flame wash,
   hunting party, fairies, historiated initial). The forge's only imagery is
   heraldry uploads and a small CSS drop cap.

CSS rects + gradients + noise filters have a hard ceiling; reaching "drawn by a
hand" requires actual drawn artwork in the pipeline.

## Decisions (user-approved)

| # | Question | Decision |
|---|---|---|
| 1 | Ship curated public-domain medieval illumination scans as bundled repo assets? | **Yes.** Sourced from PD/CC0 digitized manuscripts (British Library, Bodleian, KB, Morgan, etc.), properly attributed. |
| 2 | Relationship to the existing 10 style families? | **Re-skin the current lineup**, keeping family identities, palette/typography systems, and builder UX. Escape hatch: any family that can't be sourced to the new quality bar is redefined or cut rather than shipping one CG family among nine illuminated ones. |
| 3 | Personalization depth? | **Family ornament + award motif slot.** ~15 curated PD motifs mapped by award name (bounded list of standard Amtgard orders), sourced once (not per family), duotone-tinted to family ink. Future hook: community override via the existing ScrollArtwork upload/moderation system. |
| 4 | Substrate philosophy? | **Per-family ground, both kinds represented.** Parchment families get a real scanned-parchment tile; manuscript-tradition families move to clean white/ivory grounds (better home printing; matches 3 of 5 references). No new UI. |

## Rendering Vocabulary (five subsystems)

Guiding rule: **ornament becomes real `<img>`/inline-SVG elements, never CSS
backgrounds.** Real elements print reliably regardless of the browser's
"print backgrounds" setting, lazy-load individually, and can be tinted per-element.

### 1. Borders → composed ornament frames

Replace the nested-rect frame with a 9-slice-style composition:

- 4 corner plates
- repeating edge strips per side
- optional mid-edge medallions

Assets are curated PD scans, or redrawn/tintable SVG for mathematically-regular
traditions (interlace, key patterns). Intensity dial re-maps:

- **plain** — the current thin SVG rules, kept verbatim. Serves as the legitimate
  "plain diploma" tier AND the loading/fallback state while ornament assets decode.
- **balanced** — full strip border (reference scrolls #1/#2 register here).
- **ornate** — strips + medallions + inhabited corners (references #4/#5).

### 2. Substrate → per-family real grounds

- Parchment families: genuine scanned-parchment tile (one or two shared scans,
  color-graded per family via CSS filters/tint layer).
- Manuscript families: clean ivory/white ground.
- Deckled edges only on parchment families; white families get a clean sheet.
- feTurbulence survives only as a whisper-opacity fiber pass, if at all.

### 3. Lettering → flourishes + matte gilding

Display faces stay. Three changes:

- **Flourish plates:** PD pen-flourish/ribbon swash assets positioned off the title
  block (per-family style, palette-tinted) — the ref-#2 ribbon treatment.
- **Matte gilding:** gradient gold replaced by matte ink or clipped gold-leaf scan
  texture (`background-clip: text`), plus a very subtle SVG displacement so glyph
  edges aren't laser-perfect. Fallback when displacement is unavailable in print:
  plain matte fill (still correct, just cleaner).
- **Body text stays clean.** In real manuscripts the display letters carry the
  calligraphy; ruled, even body text is authentic and preserves legibility.

### 4. Drop caps → illuminated initial plates

Replace CSS `::first-letter` styling with scanned illuminated initials.
Full A–Z per family is absurd (260 assets); instead **2–3 shared illuminated
alphabets** (~26 glyphs each — e.g., one foliate, one pen-filigree, one
historiated). The family manifest picks a set + tint. ~60–80 shared assets cover
every recipient name.

### 5. Award motif slot

One reserved anchor position (bottom-center, matching the jester / "II" placement
in references). Renders the award's curated motif, duotone-tinted to the family ink
so any motif harmonizes in any family. Manifest-mapped by award name; awards
without a motif omit the slot entirely.

### Palette direction (consequence of going art-first)

For scan-heavy families, **the palette derives FROM the chosen artwork** rather
than tinting artwork to the current hex palettes. Line-art and SVG ornament still
tint to palette; painted scans are never recolored.

## Family Treatment Matrix

| Family | Source tradition | Ground | Border source |
|---|---|---|---|
| Hibernian Knotwork | Insular (Kells/Lindisfarne) | parchment | **SVG interlace**, tintable (knotwork is regular; refs #1/#2 are themselves vector knotwork) |
| Northern Gothic | Gothic tracery | parchment | line-art scans, tinted |
| Provençal Bestiary | Books-of-Hours drollery | **white/ivory** | painted scans w/ birds & berries (ref #4) |
| Crimson Decree | Royal acanthus | parchment | painted acanthus scans |
| Forest Reverie | Rinceaux vinework | ivory | painted vine scans |
| Charred Edict | Scorched document | parchment + burnt-edge photo assets | minimal rules — the substrate IS the identity |
| Imperial Edict | Carolingian purple & gold | parchment | laurel/eagle scans |
| Scholar's Hand | Plain diploma | white | stays rules + filigree initial (deliberately plain) |
| Crusader's Charter | Romanesque charter | parchment | line-art, tinted |
| Astral Codex | Starry Book-of-Hours skies | **ivory w/ night-blue border panels** (printable); full dark ground only if panels don't sing — escape hatch applies | gold-on-blue star/line-art |

## Award Motifs (~15, data-driven)

Flame, Rose, Owl, Dragon, Lion, Hydra, Mask, Garber (shears), Smith (anvil),
Warrior (crossed swords), Battle, Crown, Jovious (jester), Zodiac, Knighthood
(spurs/sword). Mapped by award name in a manifest; extensible without code changes.

## Asset Organization & Specs

- New namespace: `system/assets/scroll/forge/{families,alphabets,motifs,grounds,flourishes}/`
- Per-family `manifest.json`; **mandatory** ATTRIBUTION.md entry per asset
  (library, manuscript shelfmark, license, source URL).
- Formats: PNG-with-alpha for scans, SVG for tintable line-art/interlace.
- Resolution targets (~300dpi at placed size): edge strips ~3000px long side,
  corner plates ~900px, initials ~600px, motifs ~800px. pngquant-optimized.
- Budget: ~4–6MB per rendered family at balanced tier.
- Assets stay **external files** — `inline_forge.py` never inlines them; only the
  selected family's assets are preloaded.

## Engineering Deltas

- `families.json` schema grows an ornament manifest section.
- `sf-scroll-markup.html.part` gains absolutely-positioned ornament layer
  containers (absolute so `fitPage()` measurements are untouched).
- `sf-app.js.part` composes the frame/initial/motif/flourish layers from the
  manifest.
- Per-family CSS shrinks to positioning + tint variables.
- Existing test harness extends naturally: `test_curated_assets.php` /
  `test_families_manifest.php` enforce manifest ↔ file ↔ attribution completeness;
  intensity-tier and print-ratio tests unchanged in spirit.

## Curation Workflow

Documented checklist: source → crop → alpha-cut → level → resize → optimize →
attribute. Executed in waves:

- **Wave 1 (pipeline proof):** Hibernian Knotwork (SVG family), Provençal Bestiary
  (painted-scan family), Crimson Decree (hybrid).
- **Waves 2–3:** remaining seven families.
- **Pre-release escape-hatch review:** cut or redefine anything below the bar.

Timeline pressure is low — this ships with Dragon II, 3–4 releases out.

## Hard Constraints (inherited, unchanged)

- Sheet must remain a fixed 8.5×11 Letter-ratio page; content fits the page, never
  grows it. Verify ratio in-browser.
- Edit `.part` files and re-run `inline_forge.py`; never edit inlined `.tpl`
  regions directly.
- Dark-mode-safe UI chrome; the scroll itself always renders on its own ground.
- Ornament layers take explicit z-index from the token stack (must never cover
  text).
- No `initial-letter` CSS ever (Chrome giant-versal bug).
- rAF-based layout work keeps its `setTimeout` fallback (hidden-tab pause).

## Explicitly Unchanged

Wording engine, panel UX, heraldry white-removal pipeline, letter-ratio fit model,
print CSS approach, intensity dial UI, the legacy canvas/GD generator, ScrollArtwork
upload/moderation system (future integration hook only).

## Out of Scope (this effort)

- Community motif overrides via ScrollArtwork (hook acknowledged, not built).
- Printer-friendly white-ground toggle (option C from Q4 — add later if requested).
- Per-family × per-award art matrix (the 150-asset dream).
- Landscape-specific ornament sets (ornament must tolerate both orientations via
  the 9-slice model, but no landscape-only art).

## Risks

- **Sourcing quality variance.** Mitigated by the escape hatch (Q2) and wave
  structure — the bar is set by Wave 1 before the long tail is curated.
- **Asset weight.** Budgeted; preload only the selected family; plain tier remains
  asset-free.
- **Painted-scan tint mismatch with existing palettes.** Resolved by the art-first
  palette rule: palettes re-derive from artwork for scan families.
- **Print fidelity of SVG filters (displacement on gilding).** Fallback is plain
  matte fill; the effect is progressive enhancement.
