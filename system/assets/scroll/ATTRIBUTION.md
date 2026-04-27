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
| hibernian_knotwork | frame_corner_nw | `families/hibernian_knotwork/frame_corner_nw__border.png` | Hibernian Knotwork — NW corner. Insular triskele with two interlocked
    knot bands radiating along the right and bottom edges to meet the
    frame_edge_top tile at the corner seam. Designed to rotate 90/180/270
    cleanly to produce NE/SE/SW corners.
    Informed by: Book of Kells, Trinity College Dublin MS 58, folio 34r
    (the carpet page); license: PD (manuscript ~AD 800).
    SVG path data: original procedural geometry, CC0. | PD (manuscript ~AD 800) |
| hibernian_knotwork | frame_edge_top | `families/hibernian_knotwork/frame_edge_top__border.png` | Hibernian Knotwork — top edge tile. Continuous interlocking knot band
    with five round knot stations across 150 units; left and right edges
    matched so the tile repeats horizontally without seams. Designed to
    rotate 90/180/270 cleanly to produce left/bottom/right edge tiles.
    Informed by: Lindisfarne Gospels, BL Cotton Nero D.IV, carpet pages;
    license: PD (manuscript ~AD 700).
    SVG path data: original procedural geometry, CC0. | PD (manuscript ~AD 700) |
| hibernian_knotwork | seal_stamp | `families/hibernian_knotwork/seal_stamp__gold.png` | Hibernian Knotwork — seal stamp. Triskele in concentric Insular knot ring,
    central spiral hub. Reads at small size (~36 px preview) as three radial
    arms in a circle.
    Informed by: Cross of Patrick and Columba, Kells, Co. Meath; carpet pages
    of Lindisfarne and Kells; license: PD.
    SVG path data: original procedural geometry, CC0. | PD |
