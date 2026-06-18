# Award Management Redesign — Design Spec

**Date:** 2026-06-18
**Status:** Approved for prototype build
**Author:** Avery Krouse (with Claude)

## Problem

Award management today is a cramped in-page modal (`Admin_kingdom.tpl`, the "Manage Awards" overlay). It presents awards as a flat table — Name / Reign / Month / Title? / Class — with:

- **No explanation** of what any setting means. "Title Class" is a bare number; "Reign"/"Month" look like enforced caps but aren't; the alias-vs-custom distinction is unexplained.
- **Computed, invisible grouping.** Awards are bucketed by classification logic duplicated across PHP (`model.Award.php`) and JS (`classifyAward` in `Admin_kingdom.tpl`), but the groups aren't surfaced as a teaching structure.
- **No lifecycle safety.** Awards can only be hard-deleted; there is no disable/hide.
- **Hidden knowledge** lives in officers' heads ("to change who can grant this, go to Officers → Permissions"; "rungs are configured by the system"; "that limit isn't actually enforced").

A brand-new Prime Minister cannot understand or safely operate this screen.

## Goal

A **dedicated, self-teaching Award Management page** that a first-time officer can understand at a glance: awards grouped by meaning, every setting explained in plain language, hidden knowledge surfaced inline, and add/edit/disable made fast and unambiguous.

## Scope

Designed for the **target end-state** (so the layout has a home for everything), built in **phases**. This spec covers **Phase 1 (the prototype)**.

### In scope (Phase 1 prototype)
- Dedicated page replacing the modal, linked from the Awards tile on Kingdom Admin.
- Hybrid layout: grouped **catalog** (left) + **teaching drawer** (right/slide-over).
- Plain-language group blurbs + per-field inline help + 💡 hidden-knowledge callouts.
- **Data-driven** counts/groups (render the actual DB; never hardcode counts).
- Single smart **"+ Add Award"** flow (auto alias-vs-custom).
- **Disable vs Delete**: new soft-disable column; Disable is the default safe action, Delete is confirm-gated.
- Reign/month limits shown as **honest "reference only — not enforced"**.

### Split out / parked (NOT this project)
- **Order of Precedence** → its own future project. Orders awards, titles, **and officer positions** per kingdom. The award drawer keeps "Confers a title?" but only *points* to this area for ranking. See `project_order_of_precedence` memory.
- **Limit enforcement** (counting per reign/month at grant time) → parked. Requires a reign-boundary data model that does not exist today.
- **Missing-standard-award nudge** ("you lack Knight of the Battle") → out of scope for v1.

## Research findings that shaped this design

1. **`title_class` is essentially cosmetic.** It is a sort key only. Visible to end users in exactly two places: the player-profile Titles tab (initial order) and the admin award table itself. It does NOT choose a player's headline title and drives no report. → Precedence belongs in its own area, not here. (See `reference_title_class_cosmetic_ordering` memory.)
2. **`reign_limit` / `month_limit` are never enforced.** No grant path or recommendation path reads them; there is no reign-boundary model. They are stored, edited, and round-tripped but functionally dead. → Label them honestly as reference-only.
3. **Knighthood count is data-dependent.** The seed has four (Flame, Crown, Serpent, Sword); the real fifth is Knight of the Battle, added per-DB. → Always render from the DB.
4. **Casing bug** (noted for build): seed stores peerage `'Man-at-Arms'` but classifier checks `'Man-At-Arms'` — may misfile that award. Fix opportunistically.

## Architecture

Follows the project's layering: DB logic in `system/lib/ork3/`, thin pass-through in `orkui/model`, controllers in `orkui/controller`, plain-PHP templates in `orkui/template/revised-frontend/`.

### Components

**1. Page route + controller action.** A new dedicated route (e.g. `Kingdom/awards/{id}`) → controller action that renders a full-page `revised-frontend` template. Reuses existing data feeds (`AdminAwards`, `SystemAwards`) plus the new disabled flag and filter.

**2. Catalog (left).** Collapsible groups, each with a plain-language blurb and a live count:
*Knighthoods · Noble Titles · Masterhoods · Ladder Awards (Orders) · Associate Titles · Kingdom-Specific · Offices & Other.*
Grouping reuses the canonical `classifyAward` logic (single source of truth — consolidate the duplicated copy where practical). Toolbar: search, **Active / Disabled / All** filter, single **+ Add Award**. Rows show at-a-glance badges (Title, Ladder·rungs) and a limit summary; clicking a row opens the drawer.

**3. Teaching drawer (right / slide-over).** For the selected award:
- "**What this is**" plain-English explainer, templated per group/type.
- Display name (with "rename for your kingdom" help; underlying system award stays linked).
- Reign / Month limit fields, labeled **"reference only — not enforced."**
- **Confers a title?** toggle.
- A one-line pointer: *"Where this ranks is set in Order of Precedence →"* (future area).
- 💡 hidden-knowledge callouts (permissions live in Officers; rungs/capstone are system-configured).
- **Disable** (safe; keeps history) + **Delete** behind a confirm.

**4. Add flow.** A single "+ Add Award" that searches existing system awards first (alias path); "can't find it? create a custom award" (custom path). Drives the **same** `setaward` endpoint the modal uses — alias = `KingdomAwardId:0` + `AwardId>0`; custom = `AwardId:0`.

**5. Soft-disable.** New column on `ork_kingdomaward` (`disabled tinyint NOT NULL DEFAULT 0`). Threaded into:
- `GetAwardList` — select the column + accept an Active/Disabled/All filter param (default Active).
- Save path — set/clear `disabled` (extend `setaward` or add `setawardstatus`).
- Catalog filter UI reflects it.
Delete remains available (confirm-gated) for true removal.

### Data flow

Page load → controller action → `Kingdom->GetAwardList` (with disabled column + filter) → config JSON (`adminAwards`, `systemAwards`) emitted to the template → JS renders grouped catalog → row click opens drawer → edits POST to `KingdomAjax` (`setaward` / `deleteaward` / disable) → re-render.

### Schema change (the only one in Phase 1)

```sql
ALTER TABLE ork_kingdomaward
  ADD COLUMN disabled tinyint(1) NOT NULL DEFAULT 0;
```
(Exact migration filename per `db-migrations/` convention.)

## Error handling

- Permission checks unchanged (`kingdom.award.create/edit/remove`); add an equivalent check for the disable action.
- Disable instead of delete is the safe default; Delete requires explicit confirm (`tnConfirm`, never native `confirm()`).
- Reign/month inputs accept blank = "no limit (reference)"; no enforcement implied.
- Add flow validates name presence; alias requires a selected system award.

## Dark mode

All new surfaces (page, catalog, drawer, modals, callouts) must be dark-mode compatible proactively — headings reset against the global `h1–h6` pill styles, ghost/cancel buttons legible, callout backgrounds and tooltips themed. Walk every surface in dark mode before "done."

## Testing

- Prototype verified in-browser (Claude-in-Chrome) after build: page loads from the tile, groups render data-driven, drawer opens/edits/saves, Add (both alias + custom) round-trips, Disable hides from Active filter and reappears under Disabled/All, Delete confirm-gated. Dark mode walked.
- Lib changes (GetAwardList filter, disabled set) exercised via curl-auth session where the local DB allows.

## Build decomposition (parallel surfaces)

1. **Migration + lib** — add column; thread into `GetAwardList` (select + filter) and save/disable in `class.Kingdom.php`.
2. **Controller + AJAX** — new page action + data feed; disable endpoint.
3. **Template + catalog** — full-page template, grouped catalog, toolbar/filter, tile link.
4. **Drawer + add flow** — teaching drawer, inline help, callouts, unified Add.
5. **CSS** — page + catalog + drawer styling, dark-mode.

Contracts between surfaces: the config JSON shape (`adminAwards` rows incl. `Disabled`, `systemAwards`), the `classifyAward` group keys, and the `setaward`/`deleteaward`/disable endpoint signatures.
