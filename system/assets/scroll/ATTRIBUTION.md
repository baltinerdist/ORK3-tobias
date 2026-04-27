# Scroll redesign — decorative element attribution

## Frame, seal-stamp, drôlerie, banderole, historiated-initial decorations

All decorative elements rendered by the new family-driven scroll path
(`ScrollDecoration` PHP class + `scroll-decoration.js`) are **procedurally generated**
via PHP GD and HTML5 Canvas drawing primitives. They are not derived from
external manuscript scans, font glyphs, or third-party SVG assets.

License: **CC0** — public domain dedication.

## Fonts

The 21 fonts bundled in `assets/scroll/fonts/` are licensed under the
**SIL Open Font License (OFL) v1.1** by their respective authors via Google Fonts.
Bundled in this repository under the OFL-permitted distribution clause.

Notable fonts used in the family palettes:
- UnifrakturMaguntia (Peter Wiegel) — Northern Gothic title
- Uncial Antiqua (Sorkin Type) — Hibernian Knotwork title
- MedievalSharp (Carrois Apostrophe) — Provençal Bestiary title
- Cinzel (Natanael Gama) — Crimson Decree, Imperial Edict, Crusader's Charter title
- Caudex (Hjort Nidudsson) — Hibernian Knotwork, Imperial Edict body
- EB Garamond (Georg Duffner) — primary body face across most families
- Goudy Bookletter 1911 (Barry Schwartz) — Charred Edict title
- Pirata One (Rodrigo Fuenzalida) — Astral Codex title
- Sorts Mill Goudy (Barry Schwartz) — Provençal Bestiary, Charred Edict body
- Pinyon Script, Great Vibes, Tangerine — signatures across families

Full font metadata in `controller.ScrollAjax.php::$FONTS`.

## Heraldry images

Heraldry images displayed inside the medallion (when present) come from the
ORK kingdom/park/player image library — provided by ORK users and used per
the standing ORK content licensing.

## Future v1.5+ asset additions

The spec contemplated curated public-domain manuscript art from BNF Gallica,
British Library, Met Open Access, Getty Open Content, and Wikimedia Commons,
plus optional Game-icons.net (CC-BY 3.0) silhouettes. Those were not landed in
v1 due to network constraints during initial implementation. When/if added,
each curated asset will be recorded here with its source URL and license.

## Curated family asset attribution

Each row lists a system-owned, palette-tinted asset committed under
`system/assets/scroll/families/<family>/`. Sources listed are the
manuscript or open-content references the SVG was *informed by*; the
SVG path data itself is original procedural geometry committed as
CC0 by the ORK project unless otherwise noted in the row's License.

| Family | Role | File | Source / informed by | License |
|---|---|---|---|---|
| northern_gothic | frame_corner_nw | `families/northern_gothic/frame_corner_nw__border.png` | Northern Gothic — NW corner. Naturalistic ivy bar with three-lobed
    leaves, acanthus curl at the inner corner, gilded besant boss.
    Designed for clean 90/180/270 rotation.
    Informed by: Luttrell Psalter (BL Add MS 42130, c. 1325-1340) bar
    border conventions; license: PD.
    SVG path data: original procedural geometry, CC0. | PD |
| northern_gothic | frame_edge_top | `families/northern_gothic/frame_edge_top__border.png` | Northern Gothic — top edge tile. Continuous ivy bar with five trefoil
    leaves, gilded besants between, sinuous central trunk. Edges matched
    for horizontal repeat.
    Informed by: Luttrell Psalter bar borders; license: PD.
    SVG path data: original procedural geometry, CC0. | PD |
| northern_gothic | seal_stamp | `families/northern_gothic/seal_stamp__gold.png` | Northern Gothic — seal stamp. Lion rampant with raised forepaw and
    flowing mane, encircled by gilded ring with twelve cabochon dots.
    Reads at small size as a leonine silhouette in profile.
    Informed by: heraldic lions of the Holy Roman Empire and English
    royal arms (c. 13th-14th c.); license: PD.
    SVG path data: original procedural geometry, CC0. | PD |
