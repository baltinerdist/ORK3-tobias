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
| astral_codex | seal_stamp | `families/astral_codex/seal_stamp__gold.png` | Pentagram-circle-interlaced
    Source: https://commons.wikimedia.org/wiki/File:Pentagram-circle-interlaced.svg
    Author: AnonMoos
    License: Public domain
    Imported into ORK3 scroll redesign v1.5 — channel-multiplied to family
    palette token at seed time. | Public domain |
| charred_edict | frame_corner_nw | `families/charred_edict/frame_corner_nw__border.png` | Charred Edict — NW corner. Minimal scribal frame: single thin
    ink rule, hastily drawn (irregular line weight), with a small
    hand-stamped sigil at the inner corner. The burnt-edge and
    fold-crease filters overlay this at render time, so the corner
    deliberately stays sparse.
    Informed by: 12th-15th c. battlefield dispatches (administrative
    minuscule hands); license: PD.
    SVG path data: original procedural geometry, CC0. | PD |
| charred_edict | frame_edge_top | `families/charred_edict/frame_edge_top__border.png` | Charred Edict — top edge tile. Single irregular hand-drawn ink rule
    with occasional scribal flecks; minimal by design — the burnt-edge
    filter dominates the visible frame at render time.
    Informed by: rough scribal hands of besieged-keep dispatches;
    license: PD.
    SVG path data: original procedural geometry, CC0. | PD |
| charred_edict | seal_stamp | `families/charred_edict/seal_stamp__gold.png` | Antu BrokenSword
    Source: https://commons.wikimedia.org/wiki/File:Antu_BrokenSword.svg
    Author: Fabián Alexis
    License: CC BY-SA 3.0
    Imported into ORK3 scroll redesign v1.5 — channel-multiplied to family
    palette token at seed time. | CC BY-SA 3 |
| crimson_decree | frame_corner_nw | `families/crimson_decree/frame_corner_nw__border.png` | Crimson Decree — NW corner. Architectural Gothic frame: pointed-arch
    capital springing from a fleur-de-lis pier, dentilled architrave on
    inner edge. Designed for clean 90/180/270 rotation.
    Informed by: Sainte-Chapelle (Paris, c. 1248); Reims Cathedral
    portal arch capitals (c. 1230); manuscript decretals of Boniface VIII
    (BNF Lat. 4080, 14th c.); license: PD.
    SVG path data: original procedural geometry, CC0. | PD |
| crimson_decree | frame_edge_top | `families/crimson_decree/frame_edge_top__border.png` | Crimson Decree — top edge tile. Solid architectural band with dentil
    row on the inner edge and three small fleur-de-lis bosses spaced
    across. Edges matched for horizontal repeat.
    Informed by: Gothic cornice mouldings (Sainte-Chapelle nave bands);
    license: PD.
    SVG path data: original procedural geometry, CC0. | PD |
| crimson_decree | seal_stamp | `families/crimson_decree/seal_stamp__gold.png` | Heraldic Royal Crown (Common)
    Source: https://commons.wikimedia.org/wiki/File:Heraldic_Royal_Crown_(Common).svg
    Author: Wikimedia Commons
    License: CC BY-SA 3.0
    Imported into ORK3 scroll redesign v1.5 — channel-multiplied to family
    palette token at seed time. | CC BY-SA 3 |
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
| crusaders_charter | seal_stamp | `families/crusaders_charter/seal_stamp__gold.png` | Cross-Pattee-Heraldry
    Source: https://commons.wikimedia.org/wiki/File:Cross-Pattee-Heraldry.svg
    Author: Masturbius based on original PNG and PostScript source by AnonMoos, AnonMoos
    License: Public domain
    Imported into ORK3 scroll redesign v1.5 — channel-multiplied to family
    palette token at seed time. | Public domain |
| forest_reverie | frame_corner_nw | `families/forest_reverie/frame_corner_nw__border.png` | Forest Reverie — NW corner. Gnarled oak vine with five-lobed oak
    leaves and acorns; tendrils break past the page-margin line into
    the parchment field; concentric carved-bark spiral at the inner corner.
    Designed for clean 90/180/270 rotation.
    Informed by: Sherwood Forest Hours (BL Add MS 18852, c. 1500);
    Renaissance ornamental engravings of Israhel van Meckenem; license: PD.
    SVG path data: original procedural geometry, CC0. | PD |
| forest_reverie | frame_edge_top | `families/forest_reverie/frame_edge_top__border.png` | Forest Reverie — top edge tile. Gnarled oak vine with five-lobed
    leaves spaced across, three acorns in clusters, irregular sinuous
    trunk. Edges matched for horizontal repeat.
    Informed by: Sherwood Forest Hours marginalia; license: PD.
    SVG path data: original procedural geometry, CC0. | PD |
| forest_reverie | seal_stamp | `families/forest_reverie/seal_stamp__gold.png` | Gold heraldic oak leaf
    Source: https://commons.wikimedia.org/wiki/File:Gold_heraldic_oak_leaf.svg
    Author: Leonardo Piccioni de Almeida
    License: CC BY 3.0
    Imported into ORK3 scroll redesign v1.5 — channel-multiplied to family
    palette token at seed time. | CC BY 3 |
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
| hibernian_knotwork | seal_stamp | `families/hibernian_knotwork/seal_stamp__gold.png` | Triskele-Symbol1
    Source: https://commons.wikimedia.org/wiki/File:Triskele-Symbol1.svg
    Author: Based on work by User:AnonMoos; The original uploader was Dariusofthedark at English Wikipedia.
    License: Public domain
    Imported into ORK3 scroll redesign v1.5 — channel-multiplied to family
    palette token at seed time. | Public domain |
| imperial_edict | frame_corner_nw | `families/imperial_edict/frame_corner_nw__border.png` | Imperial Edict — NW corner. Byzantine jeweled cabochon border:
    alternating round + lozenge cabochons set in gold cloisonné cells,
    pearl-row inner edge, axial-symmetric corner medallion with cross.
    Designed for clean 90/180/270 rotation.
    Informed by: cloisonné enamel of the Pala d'Oro (St Mark's Venice,
    c. 11th-14th c.); Byzantine Lectionary BNF Coislin 18 borders;
    license: PD.
    SVG path data: original procedural geometry, CC0. | PD |
| imperial_edict | frame_edge_top | `families/imperial_edict/frame_edge_top__border.png` | Imperial Edict — top edge tile. Byzantine cloisonné jeweled band:
    alternating round + lozenge cabochons in gold cells, pearl row on
    inner edge, axial-symmetric repeat.
    Informed by: Pala d'Oro cell-and-jewel decoration; Constantinopolitan
    enamel ateliers; license: PD.
    SVG path data: original procedural geometry, CC0. | PD |
| imperial_edict | seal_stamp | `families/imperial_edict/seal_stamp__gold.png` | Double-headed eagle of the Sultanate of Rum
    Source: https://commons.wikimedia.org/wiki/File:Double-headed_eagle_of_the_Sultanate_of_Rum.svg
    Author: Samhanin
    License: CC0
    Imported into ORK3 scroll redesign v1.5 — channel-multiplied to family
    palette token at seed time. | CC0 |
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
| northern_gothic | seal_stamp | `families/northern_gothic/seal_stamp__gold.png` | Lion rampant
    Source: https://commons.wikimedia.org/wiki/File:Lion_rampant.svg
    Author: Wikimedia Commons
    License: CC BY-SA 3.0
    Imported into ORK3 scroll redesign v1.5 — channel-multiplied to family
    palette token at seed time. | CC BY-SA 3 |
| provencal_bestiary | frame_corner_nw | `families/provencal_bestiary/frame_corner_nw__border.png` | Provençal Bestiary — NW corner. Asymmetric whimsical ivy with curling
    tendrils, marginal grotesque (small hybrid bird-headed creature peeks
    from inner corner). Designed for clean 90/180/270 rotation.
    Informed by: Luttrell Psalter bas-de-page marginalia (BL Add MS 42130);
    Romance of Alexander (Bodleian MS Bodley 264); license: PD.
    SVG path data: original procedural geometry, CC0. | PD |
| provencal_bestiary | frame_edge_top | `families/provencal_bestiary/frame_edge_top__border.png` | Provençal Bestiary — top edge tile. Whimsical ivy with curling tendrils,
    pomegranate-fruit clusters, asymmetric leaf placement. Edges matched
    for horizontal repeat.
    Informed by: Luttrell Psalter and Romance of Alexander marginalia
    bar borders; license: PD.
    SVG path data: original procedural geometry, CC0. | PD |
| provencal_bestiary | seal_stamp | `families/provencal_bestiary/seal_stamp__gold.png` | Coa Illustration Elements Animal Rabbit Couchant
    Source: https://commons.wikimedia.org/wiki/File:Coa_Illustration_Elements_Animal_Rabbit_Couchant.svg
    Author: Arthur Charles Fox-Davies
    License: Public domain
    Imported into ORK3 scroll redesign v1.5 — channel-multiplied to family
    palette token at seed time. | Public domain |
| scholars_hand | frame_corner_nw | `families/scholars_hand/frame_corner_nw__border.png` | Scholar's Hand — NW corner. Renaissance bianchi girari (white-vine
    scrollwork): three triangulated white vine spirals on a dark ground
    band, classical urn at the inner corner, restrained pinpoint pearls.
    Designed for clean 90/180/270 rotation.
    Informed by: Florentine humanist book hands (Bartolomeo Sanvito,
    c. 1470-1490); Vespasiano da Bisticci copies of Cicero; Roman
    Tabula Iliaca-style framing; license: PD.
    SVG path data: original procedural geometry, CC0. | PD |
| scholars_hand | frame_edge_top | `families/scholars_hand/frame_edge_top__border.png` | Scholar's Hand — top edge tile. Bianchi girari band: white-vine
    spirals carved in negative space against a solid ground band, with
    pinpoint pearl row on inner edge. Edges matched for repeat.
    Informed by: Sanvito's hands for Cardinal Bessarion's library;
    license: PD.
    SVG path data: original procedural geometry, CC0. | PD |
| scholars_hand | seal_stamp | `families/scholars_hand/seal_stamp__gold.png` | Heraldry quill and ink
    Source: https://commons.wikimedia.org/wiki/File:Heraldry_quill_and_ink.svg
    Author: Wikimedia Commons
    License: Public domain
    Imported into ORK3 scroll redesign v1.5 — channel-multiplied to family
    palette token at seed time. | Public domain |
