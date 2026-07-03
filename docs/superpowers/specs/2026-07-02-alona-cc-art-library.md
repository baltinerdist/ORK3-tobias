# Alona of Two Trees — CC Award Art Library (source of built-in packs)

**Source page:** https://sites.google.com/view/alonatwotrees/awards/editable-awards
**Author:** Alona of Two Trees (Amtgard)
**Retrieved:** 2026-07-02

This is the sourcing record for the scroll generator's **built-in decorative packs**
(see `2026-07-02-scroll-generator-slot-templates-design.md`). It captures licensing, the
public Drive folder IDs, the category→slot mapping, and a reproducible re-fetch script so
the art can be pulled into the final asset location during implementation.

## License

Quoted from the page's "A Note About Copyright":

> "You can use any of the artwork I have provided on this page below, I am giving it away
> free for use, under creative commons. You can use it in personal and commercial use. I
> have either come up with the designs myself, or used free for use copyright free artwork
> to create these pieces. If you find something that you think someone else has made a
> piece and it is falsely put online by me, send me an email and I will be glad to remove
> it."

**Practical grant:** free for personal **and** commercial use. Permits bundling into ORK.
**Obligation:** none stated, but we will **credit "Alona of Two Trees"** in an
`ATTRIBUTION.md` alongside the assets (courtesy + honors the takedown clause — if she asks
to remove a piece, we comply). Some pieces are her assemblies of copyright-free art.

## Public Drive folders (embeddedfolderview `id`)

| Section | Folder ID | Maps to slot(s) |
|---|---|---|
| Backgrounds | `1or62gKZZvj558aro1Jrziuxt9xCLf8yE` | `bg_type=image` (full-bleed) / texture |
| Borders | `1L1EMdd0OG_ZpeFyxmNhlogv7JjBhLAvI` | `full_border`; the "…Side" files → `border_left`/`border_right` |
| Orders | `1G5G6-dAbfwdAYA34gUCpW4A4SdwYjhsm` | `center_image` / `top_graphic` (award emblems; **19 sub-folders by award type**) |
| Heraldry | `0B8BEMLQWvP8ifnFvWEJUTGFUMmo4aWNqQURoT0xjek5uZFNMeXJYTmtlWVV0empXcndXMTQ` | shield decals — legacy folder ID, did **not** list via embeddedfolderview; revisit |

Full file inventory (id + name per folder) is stored beside this doc:
`assets/alona-drive-manifest.json` (borders/backgrounds/orders top level) and
`assets/alona-orders-index.json` (per-order-subfolder file lists).

## What maps to what

- **Borders → `full_border`:** BlackWhite, BlueGold, Blue/Green/Orange/Purple/Reg/White/
  Yellow/LightGreen/Silver "Gold Border Celtic", 2ribbon (Gold/Silver), Knotwork_bw_1,
  rose border, Rose Circle Border, Scroll Border, Warlord/Warlordbw. (PNG + several SVG.)
- **Borders → side slots:** "Gold Swirl Side", "Swirl Side", "Leaf Side" → `border_left`/
  `border_right`.
- **Backgrounds → `bg_type=image`:** Brown Tea Stained, Dark Corona, Gray Smoke, Green
  Forest, Purple Lightening, Warlord, White Marble. (Tea Stained / Marble read as
  parchment/texture; the others are scenic full-bleed.)
- **Orders → award-name emblem map (design win):** the Orders sub-folders are named by
  award type — Crown, Dragon, Flame, Rose, Owl, Smith, Lion, Griffon, Hydra, Warrior,
  Masterhoods, Sashes, Titles, Zodiac, Paragons, Garber, Jovious, Mask, Walker of the
  Middle. This feeds the filler's `{AwardName}` → emblem auto-suggestion for the
  `center_image` slot. The **Masterhoods** sub-folder also yields Master_Lion / _Owl /
  _Smith / _Garber / _Rose / _Dragon emblems that cover several otherwise-empty folders.

## Re-fetch script (public folders, no auth)

`embeddedfolderview` lists a public folder as HTML (`id="entry-<FILE_ID>"` +
`flip-entry-title">NAME`). Download each file from
`https://drive.usercontent.google.com/download?id=<FILE_ID>&export=download`, following the
one virus-scan confirm hop for larger files (parse `uuid`/`confirm` from the interstitial
HTML and re-request). Filter to `.png`/`.svg` (skip `.ai`/`.psd` source files and `.jpg`
duplicates). A verified Python implementation of exactly this ran on 2026-07-02 and pulled
62 valid files (37 borders+backgrounds, 25 order emblems); it is reproduced in the
implementation plan's asset-ingestion phase.

## Retrieved on 2026-07-02 (staged, verified PNG/SVG)

- **borders/** 30 files (23 PNG designs + 7 SVG)
- **backgrounds/** 7 PNG
- **orders/** 25 files across Crown, Dragon, Flame, Masterhoods, Rose, Sashes, Warrior

## Open items for implementation

- Empty Orders sub-folders (Garber, Griffon, Hydra, Jovious, Lion, Mask, Paragons, Smith,
  Titles, Walker of the Middle, Zodiac) returned no files via embeddedfolderview — they may
  nest further or be JS-gated. Re-check during ingestion; Masterhoods covers several.
- Heraldry folder (legacy ID) needs a different listing path; low priority (we auto-pull
  real ORK heraldry).
- Curate: pick a tasteful default subset per slot rather than exposing all 60+ at once.
- Transparency: confirm the border PNGs have transparent centers (they preview as frames);
  spot-check before wiring into `full_border`.
