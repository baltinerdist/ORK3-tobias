# Award Management — Suggested Rows + Floating Category Nav

**Date:** 2026-06-19
**Surface:** `orkui/template/revised-frontend/Admin_awards.tpl` (template-only)
**Depends on:** the dedicated Award Management page (PR #43 / `feature/award-management`)

## Goal

Two enhancements to the dedicated Award Management page:

1. **Suggested-award rows** — surface **Dragonmaster** and **Weaponmaster** in the
   *Kingdom Awards & Orders* group for every kingdom. When a kingdom does not already
   have the award, show a greyed-out "ghost" row with an **Activate** button that
   makes it live in one click.
2. **Floating category nav** — a sticky left sidebar listing the award categories as
   anchor links, with a "back to top" control, so a long catalog is easy to navigate.

Both are **template-only**. No controller, lib, AJAX, or DB changes; no new endpoints.

## Why these two awards

Across all 38 kingdoms (data analysis 2026-06-18):

- **Weaponmaster** (`award_id 36`) — a near-universal fighting recognition (defined by ~35
  kingdoms, granted in 38). Despite the "-master" suffix it is **not** a Masterhood
  (the Masterhoods are Master Rose/Lion/etc.; the Order of the Battle capstone is
  *Battlemaster*). Its `is_title=1, title_class=10` currently causes `classifyAward` to
  **mis-bucket it into Masterhoods**. It belongs in Kingdom Awards & Orders.
- **Dragonmaster** (`award_id 207`) — represented in ~26 kingdoms, but ~10 of those grant
  it only as a free-text one-off without ever adding the definition (the "promote to
  definition" gap). Plus naming drift ("Dragon Master", "Kingdom Dragon Master") and an
  orphan `award_id 187` "Dragonmaster" in 2 kingdoms.

These two are the clearest cases of a standard award that kingdoms want but frequently
have not formally activated. Surfacing them with a one-click Activate closes that gap.

## Addendum (2026-06-19) — unified ghost model + Other Ladder orders

The suggested-row feature was generalized after the initial build:

- **Unified trigger:** a ghost row appears for a standardized award whenever the kingdom
  does not have it **active** (enabled). If a **disabled** row for it exists, **Activate**
  re-enables it (`setawardstatus`, `Disabled:0`); if **no row** exists, Activate creates a
  reference (`setaward`, as before). This replaces "disabled-but-present counts as has-it"
  — it now applies to Dragonmaster/Weaponmaster too (the "Re-activate" case).
- **Other Ladder Awards suggestions:** the seven standardized system orders outside the
  canonical nine are surfaced as ghosts in the renamed **"Other Ladder Awards"** group
  (section two): Jovius (28), Mask (29), Zodiac (30), Walker in the Middle (31),
  Hydra (32), Griffin (33), Flame (34).
- **Data model:** each `SUGGESTED_AWARDS` entry declares its `group`; `ghostsForGroup(name)`
  returns the missing/disabled suggestions for that group; the empty-group render guard is
  generalized so any group renders when it has ghosts to offer.
- **Section two rename:** "Kingdom and Other Ladder Awards" → "Other Ladder Awards".

Still template-only — both endpoints (`setaward`, `setawardstatus`) already exist.

## Part 1 — Suggested-award rows

### Classification pin

Add an early override at the top of `classifyAward(aw)`:

```js
// Pinned to Kingdom Awards & Orders regardless of title_class.
// 207 = Dragonmaster, 36 = Weaponmaster. Neither is a Masterhood despite the
// "-master" name; Weaponmaster's title_class=10 would otherwise mis-route it.
var PINNED_TO_KAO = [207, 36];
if (PINNED_TO_KAO.indexOf(parseInt(aw.AwardId, 10)) >= 0) return 'Kingdom Awards & Orders';
```

This guarantees a real (activated) Dragonmaster/Weaponmaster row appears in the same
group as the ghost row it replaces — no "where did it go?" confusion.

### Definition of the two suggestions

```js
var SUGGESTED_AWARDS = [
  { awardId: 207, name: 'Dragonmaster', isTitle: 1, nameRx: /dragon\s*master/i },
  { awardId: 36,  name: 'Weaponmaster', isTitle: 1, nameRx: /weapon\s*master/i }
];
```

### Presence detection (client-side)

A kingdom already "has" a suggestion if **any** loaded award row matches either:

- `parseInt(aw.AwardId, 10) === suggestion.awardId`, **or**
- `suggestion.nameRx` matches `aw.KingdomAwardName` **or** `aw.AwardName`.

The name regex (`/dragon\s*master/i`) covers the spaced variants "Dragon Master" and
"Kingdom Dragon Master" and the orphan `award_id 187`; `/weapon\s*master/i` covers the
orphan `award_id 129`. A **disabled-but-present** award still counts as "has it" — no ghost
row is shown; the manager already has the award and can re-enable it via the Disabled filter.

### Ghost row

For each suggestion the kingdom lacks, append a ghost row at the **bottom** of the
*Kingdom Awards & Orders* group body (after the real rows, before the empty placeholder):

```
Dragonmaster  (not currently available — activate it?)            [ Activate ]
```

- Row class `aw-row aw-row-ghost`; name `aw-row-name aw-ghost-name` is greyed
  (`color:#a0aec0`) and italic; the hint text is muted/italic.
- The row itself is **not** clickable (no drawer open; no `aw-row` hover-to-edit).
- The `Activate` button (`aw-btn aw-btn-outline aw-btn-sm`, right-aligned) is the only
  control.
- Ghost rows are only rendered when `AwConfig.canEdit` is true.
- Ghost rows are excluded from the group's count badge and from search/status filtering
  (they are not real awards). They remain visible in the Active and All status views and
  are hidden in the Disabled view.

### Activate

One click, no confirm dialog (non-destructive add). Reuses the existing endpoint:

```js
awPost('setaward', {
  KingdomAwardId: 0,        // 0 => CreateAward
  AwardId: suggestion.awardId,   // 207 or 36 => references the standard award
  KingdomAwardName: suggestion.name,
  ReignLimit: 0, MonthLimit: 0,
  IsTitle: suggestion.isTitle, TitleClass: 0
}, function () {
  awToast(suggestion.name + ' activated.');
  setTimeout(function () { location.reload(); }, 600);
});
```

While the request is in flight the Activate button is disabled to prevent double-submit.
On reload the new real row renders in Kingdom Awards & Orders (via the pin) and the ghost
row no longer appears (presence detection now finds it).

## Part 2 — Floating category nav sidebar

### Layout

The hero stays full-width. Below it, wrap the sidebar + existing content in a two-column
flex shell:

```
.aw-shell { display:flex; gap:24px; max-width:1320px; margin:0 auto; align-items:flex-start; }
.aw-nav   { position:sticky; top:60px; width:210px; flex-shrink:0; align-self:flex-start; }
.aw-main  { flex:1; min-width:0; max-width:1100px; }
```

The toolbar (search / status segment / Add Award) and `#aw-catalog` move inside `.aw-main`.
`top:60px` clears the 48px fixed app nav.

### Behavior

- The nav is built by JS **after** `renderCatalog()`, so it lists only groups that
  actually rendered, each with its current count.
- Each rendered group `.aw-group` gets a stable `id` (slug of the group name, e.g.
  `awgrp-kingdom-awards-orders`) and `scroll-margin-top:56px` so anchor jumps clear the
  fixed nav.
- Clicking a nav item smooth-scrolls to its group section.
- The nav item for the section currently in view is highlighted via `IntersectionObserver`.
- A "↑ Back to top" link is pinned at the bottom of the nav.
- Responsive: at `max-width:900px` the nav is hidden (`display:none`); the page is fully
  usable without it.
- All nav styling has `html[data-theme="dark"]` overrides from the start.

### Interaction with filtering

When the status segment or search hides every row in a group, `applyFilter()` already
hides that whole `.aw-group`. The nav rebuild (or a lightweight sync) hides nav items
whose group is currently hidden, so the nav never links to an empty/hidden section.

## Non-goals

- No backend changes of any kind.
- No change to the precedence / Order of Precedence work.
- No general "promote any one-off to a definition" flow — this ships only the two
  specific, data-justified suggestions. A generic suggested-orders library is future work.
- No change to how other awards classify (only the 207/36 pin is added).

## Testing / verification

Template-only JS, so verification is curl + browser (per project conventions):

1. **Renders:** curl the page (`Admin/awards/{id}`) for a manager session → 200, no PHP error in `docker logs ork3-php8-app`.
2. **Ghost appears:** a kingdom lacking Dragonmaster/Weaponmaster shows both ghost rows at
   the bottom of Kingdom Awards & Orders, greyed + italic, with Activate.
3. **No false ghost:** a kingdom that has Weaponmaster (`award_id 36`) shows no Weaponmaster
   ghost; a kingdom with a "Dragon Master" (spaced) row shows no Dragonmaster ghost.
4. **Pin:** an activated/real Weaponmaster appears in Kingdom Awards & Orders, not Masterhoods.
5. **Activate round-trip:** click Activate → toast → reload → real row present, ghost gone,
   and the row is grant-able (standard `award_id` reference created).
6. **Nav:** sidebar lists rendered groups with counts; clicking scrolls to section with
   correct offset; active highlight tracks scroll; back-to-top works; hidden < 900px.
7. **Dark mode:** walk the ghost rows, Activate button, and the entire nav in
   `html[data-theme="dark"]` — no white-on-dark, muted text still legible.
