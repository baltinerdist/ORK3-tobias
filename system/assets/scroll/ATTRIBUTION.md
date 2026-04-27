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
| charred_edict | seal_stamp | `families/charred_edict/seal_stamp__gold.png` | Charred Edict — seal stamp. Broken sword crossed over a battered
    shield: the blade snapped at midpoint, jagged break, hilt cross-guard
    intact. The composition reads as defeat-yet-defiance — fitting for
    edicts smuggled out of besieged keeps.
    Informed by: 14th-c. effigy tomb iconography (knight with broken
    sword); the heraldic charge of "sword inverted" symbolizing surrender
    or martyrdom; license: PD.
    SVG path data: original procedural geometry, CC0. | PD |
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
| crimson_decree | seal_stamp | `families/crimson_decree/seal_stamp__gold.png` | Crimson Decree — seal stamp. Royal crown with three jeweled fleur-de-lis
    apex spikes, ermine band, three jewel cabochons set in the band.
    Encircled by an inscription-style ring with twelve fleurettes.
    Informed by: French royal crown of Charles V (c. 1380); English St
    Edward's crown silhouette; license: PD.
    SVG path data: original procedural geometry, CC0. | PD |
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
| forest_reverie | seal_stamp | `families/forest_reverie/seal_stamp__gold.png` | Forest Reverie — seal stamp. Single five-lobed oak leaf with central
    vein and lateral veins, paired acorns at the base, encircled by a
    ring of woven vine knots. The oak is the druidic axis-mundi tree.
    Informed by: Quercus heraldic emblems; Sherwood Forest Hours; the
    Green Man tradition of European folk illumination; license: PD.
    SVG path data: original procedural geometry, CC0. | PD |
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
| imperial_edict | seal_stamp | `families/imperial_edict/seal_stamp__gold.png` | Imperial Edict — seal stamp. Byzantine double-headed eagle (the
    Palaiologan dynastic emblem): two heads turned outward, wings
    outspread, tail fanned, holding orb and scepter. Encircled by
    pearl ring + cross-pattée at the four cardinal points.
    Informed by: Palaiologan imperial seal of Andronikos II
    (c. 1295); Byzantine catepan double-eagle on the manuscript of the
    Treaty of Devol (1108); license: PD.
    SVG path data: original procedural geometry, CC0. | PD |
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
| provencal_bestiary | seal_stamp | `families/provencal_bestiary/seal_stamp__gold.png` | Provençal Bestiary — seal stamp. Rabbit knight on hind legs holding
    a lance, encircled by a ring of pomegranate clusters and ivy leaves.
    The whimsical "rabbit knight" trope is a Luttrell Psalter signature
    bas-de-page motif.
    Informed by: Luttrell Psalter rabbit-knight marginalia; license: PD.
    SVG path data: original procedural geometry, CC0. | PD |
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
| scholars_hand | seal_stamp | `families/scholars_hand/seal_stamp__gold.png` | Scholar's Hand — seal stamp. Quill pen crossed over an unfurled
    scroll, ink-pot at base, laurel wreath encircling the composition.
    Reads as the universal humanist scribal emblem.
    Informed by: Renaissance printer's marks (Aldus Manutius dolphin-
    and-anchor); the Aldine Press emblem tradition; classical Tabula
    Iliaca scroll-and-stylus motif; license: PD.
    SVG path data: original procedural geometry, CC0. | PD |
