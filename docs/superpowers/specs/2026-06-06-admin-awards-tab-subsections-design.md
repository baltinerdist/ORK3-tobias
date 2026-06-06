# Admin Awards Tab — System / Alias / Kingdom-Specific Subsections

**Date:** 2026-06-06
**Status:** Design approved, pending spec review
**Scope:** Front-end only. No backend, DB, or grant-side changes.

## Problem

The Awards tab of the kingdom admin modal (`Kingdomnew`) renders every one of a
kingdom's configured awards as a single flat, undifferentiated list. With the
creation of principalities (and years of accumulated award-config history), that
list mixes three conceptually distinct kinds of entries with no visual
separation:

1. **Standard Amtgard awards** the kingdom shares with everyone (Order of the
   Rose, Knight of the Sword, Warlord, …).
2. **Aliases** — standard awards the kingdom displays under a local name
   (e.g. "Woman-at-Arms" for the system award "Man-at-Arms").
3. **Kingdom-specific awards** — the kingdom's own local creations: the generic
   "Custom Award" bucket, legacy locally-defined awards, and orphaned/broken
   leftover entries.

An admin (e.g. a Prime Minister auditing their award set) currently can't tell at
a glance which awards are universal standards versus their kingdom's own — which
matters now that principalities maintain their own award sets distinct from the
parent kingdom.

## Goals

- Group the admin Awards tab into three clearly labeled subsections so admins can
  immediately distinguish standard, alias, and kingdom-specific awards.
- Pure cosmetic/organizational change. **Touch no data and no grants.** Surfacing
  existing data-debt (duplicate/orphaned rows) is an accepted side effect, not a
  goal — this pass does not flag, triage, or repair it.

## Non-Goals (explicitly out of scope)

- No "needs attention" markers, duplicate detection, or repair actions on rows.
- No backend/endpoint changes, no migrations, no re-pointing of grants.
- No changes to the award-grant ("give an award") flow — admin config tab only.

## Data Signal (derivation)

No schema flag distinguishes system vs kingdom awards; it is **derived
client-side** from fields the `adminAwards` payload already provides per row:
`AwardId`, `AwardName` (the canonical/system name, empty when the row does not
resolve to a real `ork_award`), and `KingdomAwardName` (the kingdom's local
name).

Classification, applied in this priority order:

| Order | Condition | Group |
|-------|-----------|-------|
| 1 | `AwardId === 94` (the Custom Award bucket) | **Kingdom-Specific** |
| 2 | `AwardName === ''` (no canonical resolved — legacy `award_id=0` or orphaned id) | **Kingdom-Specific** |
| 3 | resolved canonical & `AwardName === KingdomAwardName` | **System Standard** |
| 4 | resolved canonical & `AwardName !== KingdomAwardName` | **Aliases of System Awards** |

This matches the verified DB categorization. Example counts at design time —
Northern Lights (kingdom 20): 105 System / 10 Alias / 23 Kingdom-Specific;
The Painted Skies (kingdom 40, a clean principality): 135 / 11 / ~2.

## Design

### Rendering

Implemented in the admin-awards render path in
`orkui/template/revised-frontend/script/revised.js` (the `makeAdminAwards` build
loop that populates `#kn-admin-awards-tbody`, using `makeAwardRow` per row).

- Partition `KnConfig.adminAwards` into the three groups via the rule above.
- Render a **group-header `<tr>`** before each non-empty group: a single
  full-width `<td colspan="6">` styled as a subheader. Keeping headers as rows in
  the existing single `<table>` preserves column alignment and the existing
  search logic.
- Header text includes a **count**: e.g. `SYSTEM STANDARD AWARDS (105)`.
- Fixed group order: **System Standard → Aliases of System Awards →
  {KingdomName}-Specific Awards**.
- The third header uses the org's own display name from `KnConfig.kingdomName`
  verbatim (correct for principalities, which are kingdom rows), e.g.
  `THE KINGDOM OF NORTHERN LIGHTS — SPECIFIC AWARDS`. Because the header is a
  full-width row, long kingdom names wrap/fit without layout issues; no trimming.
- Rows are **alpha-sorted by display name** (`KingdomAwardName`) within each
  group. (Current order is whatever `GetAwardList` returns; sorting is applied
  per-group at render.)
- **Empty groups are not rendered** (no header, no placeholder). A pristine
  principality with zero kingdom-specific rows simply shows two groups.

### Search integration

The existing `wireAwardSearch` row filter (matches against
`tr.dataset.searchHaystack`) continues to operate. Addition: after filtering,
**a group header hides when all of its data rows are hidden**, so the user never
sees a populated-looking header (e.g. "(10)") with no visible rows beneath it.
When the search is cleared, headers and rows restore. The header count reflects
the **total** rows in the group, not the filtered count (counts are a property of
the award set, not the current filter).

### Dark mode

Group headers use existing `kn-admin` design tokens (muted background / border /
text), no inline color styles. Verified in both light and dark mode per project
convention before completion.

## Files Touched

- `orkui/template/revised-frontend/script/revised.js` — grouping + group-header
  injection in the admin-awards render loop; group-aware hide/show in
  `wireAwardSearch`.
- `orkui/template/revised-frontend/Kingdomnew_index.tpl` — CSS for the
  group-header row class (dark-mode compatible). `KnConfig.kingdomName` is
  already exposed; no new server data required.

No changes to `controller.Kingdom.php`, `class.Kingdom.php`, `GetAwardList`, or
any model/DB layer.

## Testing / Verification

- Load the admin modal Awards tab for Northern Lights (kingdom 20): confirm three
  groups appear with correct membership, alpha-sorted, dark-mode clean, and
  counts in the design-time ballpark (≈105 / 10 / 23 — exact numbers drift as the
  award set changes).
- Load it for The Painted Skies (kingdom 40): confirm the kingdom-specific group
  is tiny or absent (empty group hidden), and the other two render.
- Type in the search box: confirm rows filter and group headers disappear when
  their group is fully filtered out; clearing restores all.
- Confirm no change to add-award, edit-award, delete-award, or alias flows.

## Risks

- Low. Pure presentation over an existing payload. Worst case is a mis-grouped
  row from an unexpected `AwardName`/`AwardId` combination — cosmetic only, no
  data impact.
