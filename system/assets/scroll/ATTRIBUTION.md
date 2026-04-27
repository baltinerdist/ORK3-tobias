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
| crusaders_charter | frame_corner_nw | `families/crusaders_charter/frame_corner_nw__border.png` | Crusader's Charter — NW corner. Romanesque round-arch architectural
    frame: half-column with stylized capital springing into a rounded
    arch shoulder, chevron moulding on the inner edge, jeweled cross
    boss at the corner. Designed for clean 90/180/270 rotation.
    Informed by: Romanesque tympana of Vézelay (c. 1130) and Saint-
    Trophime in Arles; Westminster Psalter (BL Royal MS 2.A.XXII)
    initial pages; license: PD.
    SVG path data: original procedural geometry, CC0. | PD |
| crusaders_charter | frame_edge_top | `families/crusaders_charter/frame_edge_top__border.png` | Crusader's Charter — top edge tile. Romanesque architrave: solid
    band with chevron moulding row on inner edge, three small Latin
    crosses spaced across, axial repeat.
    Informed by: Vézelay nave triforium chevron mouldings; license: PD.
    SVG path data: original procedural geometry, CC0. | PD |
| crusaders_charter | seal_stamp | `families/crusaders_charter/seal_stamp__gold.png` | Crusader's Charter — seal stamp. Templar-style fleur-de-lis with
    cross-band: a fleur-de-lis (purity/Trinity) overlaid by a horizontal
    Latin cross-band (martial). Flanked by twin lions passant guardant
    serving as supporters. Encircled by inscription ring with pearl row.
    Informed by: Knights Hospitaller and Knights Templar seals (12th-13th
    c.); the Plantagenet "three lions" royal arms; the manuscript Charter
    of Jerusalem (Cambridge, Trinity College B.10.4); license: PD.
    SVG path data: original procedural geometry, CC0. | PD |
