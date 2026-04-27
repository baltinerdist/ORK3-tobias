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
| astral_codex | frame_corner_nw | `families/astral_codex/frame_corner_nw__border.png` | Astral Codex — NW corner. Astrological/alchemical motifs: scattered
    five-point silver stars, a small constellation diagram of Ursa Minor
    along the right edge, an alchemical sun glyph at the inner corner,
    Saturn-ring sigil on the bottom edge. Designed for clean 90/180/270
    rotation.
    Informed by: Aratus's Phaenomena (BL Harley MS 647); Liber Astronomiae
    of Bonatti; Splendor Solis alchemical plates (BL Harley MS 3469);
    license: PD.
    SVG path data: original procedural geometry, CC0. | PD |
| astral_codex | frame_edge_top | `families/astral_codex/frame_edge_top__border.png` | Astral Codex — top edge tile. Star-pattern margin: large 5-point
    silver stars at five stations across, smaller star clusters between,
    constellation-line connectors. Tile edges matched for repeat.
    Informed by: Aratus's Phaenomena star-charts; the Vatican Aratus
    (Codex Vat. lat. 9410); license: PD.
    SVG path data: original procedural geometry, CC0. | PD |
| astral_codex | seal_stamp | `families/astral_codex/seal_stamp__gold.png` | Astral Codex — seal stamp. Alchemical pentagram inscribed in a
    double circle, with the seven classical-planet glyphs (☉☽☿♀♂♃♄)
    arrayed at the seven stations between the pentagram and the rim.
    Reads at small size as a five-pointed star in a circle.
    Informed by: Cornelius Agrippa's Three Books of Occult Philosophy
    (1531); the Sworn Book of Honorius (BL Royal MS 17.A.XLII); medieval
    grimoires; license: PD.
    SVG path data: original procedural geometry, CC0. | PD |
