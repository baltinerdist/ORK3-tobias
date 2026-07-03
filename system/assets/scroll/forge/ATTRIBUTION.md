# Scroll Forge Asset Attribution

Every shipped asset under `system/assets/scroll/forge/` MUST have an entry
here before it is committed (enforced by `tests/scroll/` asset tests).

For curated scans, record: institution/library, shelfmark/identifier, folio,
stated license, direct source URL, and a processing note.
For generated artwork, record: the generating tool, that it is original
in-repo work, and any algorithmic lineage.

---

## hibernian_knotwork — `families/hibernian_knotwork/`

- **Files:** `corner_nw.svg`, `edge_top.svg`, `medallion.svg`
- **Source:** Generated in-repo by `tools/gen_knotwork.py` — original work,
  no external source. Deterministic output; regenerate with
  `python3 tools/gen_knotwork.py`.
- **Lineage:** Python port of the plait/interlace construction from the
  legacy in-repo canvas renderer `assets/scroll/celticknot.js` (itself an
  original ORK3 implementation of the classic tile/break-grid knotwork
  method). Over-under weaving rendered with split-segment crossings; all
  strokes `currentColor` (tinted by the ornament composer).
- **License:** Same as the ORK3 project (original project asset).

## _fixture — `families/_fixture/`

- **Files:** `corner_nw.svg`, `edge_top.svg`
- **Source:** Hand-authored minimal test fixtures for the ornament composer
  (plan Task 3). Original work, no external source.
- **License:** Same as the ORK3 project (original project asset).
