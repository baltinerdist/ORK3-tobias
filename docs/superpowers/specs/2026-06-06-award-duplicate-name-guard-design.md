# Award List — Duplicate-Name Save Guard (Kingdom/Principality Admin)

**Date:** 2026-06-06
**Status:** Design approved, pending spec review
**Scope:** Kingdom/Principality Admin modal (`Kingdomnew`), Awards tab. Front-end
primary; optional server-side mirror.

## Problem

The Awards tab lets an admin add awards through two paths and edit existing rows
inline. All of them POST to `setaward` → `CreateAward`/`EditAward`
(`class.Kingdom.php:180`/`:199`), which perform a **blind insert/update with no
duplicate detection** — no check on name, no check on `award_id`.

As a result an admin can (often unknowingly) create a second award row with the
same name as one that already exists. Over time this produces duplicate entries
for the same award (e.g. two "Custom Award" rows, multiple "Master" rows), which
cause real data-integrity problems: grants land on different rows, per-kingdom
`is_title` toggles only affect one of them, and canonical descriptors silently
disappear. (See the companion analysis of the Northern Lights "Custom Award"
duplication.)

The goal is a guardrail in the admin UI that catches a name collision **at save
time** and asks the admin to confirm before creating/renaming into a duplicate —
without blocking the legitimate cases.

## Goals

- On save, detect when the entered award name collides with an existing award in
  the same kingdom, and surface a soft, override-able confirmation before
  proceeding.
- Cover every path that can add or rename a row: *Add Award Alias*, *Add custom
  award*, and inline *edit/rename* of an existing row.
- Reduce accidental duplicate-row creation that drives downstream data-integrity
  issues.

## Non-Goals

- **Not a hard block.** Multiple aliases of the same *system* award are
  intentional and supported (e.g. "Woman-at-Arms" and "Person-at-Arms" both
  aliasing "Man-at-Arms"). The guard warns and allows override; it never prevents
  a determined, informed save.
- No detection or repair of *existing* duplicates (that's the cosmetic-grouping
  spec's surfacing job, and any cleanup is separate).
- No fuzzy/typo matching in this pass (normalized exact only — see below).
- No changes to the award-grant ("give an award") flow.

## Design

### Trigger points

All three save paths in the Awards tab run the collision check **before** the
existing `setaward` POST:

1. **Add Award Alias** — `kn-admin-new-award-save` handler (`revised.js` ~5109).
2. **Add custom award** — `kn-admin-custom-save` handler (`revised.js` ~5162).
3. **Inline edit/rename** — the per-row save handler (`revised.js` ~4910).

### Collision check (client-side)

- Runs against the already-loaded `KnConfig.adminAwards` (every existing row's
  `KingdomAwardName` and `KingdomAwardId` are in memory — no extra request).
- **Normalized comparison:** lowercase → trim → collapse internal whitespace.
  So "Custom Award", "custom award", and "Custom  Award" all match. No fuzzy /
  Levenshtein matching (avoids false alarms).
- **Self-exclusion:** on inline edit, the row's own `KingdomAwardId` is excluded
  from the candidate set, so saving an unchanged name — or renaming to a value
  that doesn't collide with a *different* row — does not warn.
- A collision is any other row whose normalized name equals the entered name.

### Confirmation (soft override)

- On a collision, show a `tnConfirm()` modal (project-standard in-product dialog;
  never a native `confirm()`):

  > "It looks like you already have an award called **"{existing name}"** in your
  > awards list. Did you mean to set an alias of it, or create a different award?
  > Duplicate awards can cause data-integrity issues, so we don't recommend
  > saving this. Continue anyway?"

  - Confirm label: "Continue anyway" (styled as the cautionary/danger action).
  - Cancel: abort the save, re-focus the name field, leave the form as-is.
- On confirm, proceed with the existing POST unchanged.
- No collision → save proceeds immediately, exactly as today.

### Optional server-side mirror (defense-in-depth)

To enforce regardless of client, `CreateAward`/`EditAward` may run the same
normalized check and, on collision, return an override-able warning
(`status: warning` + reason) unless the request carries an explicit
`AllowDuplicate=1` flag (set by the client only after the user confirms). Still
soft — never a hard rejection. This can be a follow-up phase; the client-side
guard delivers the user-facing prevention on its own.

## Files Touched

- `orkui/template/revised-frontend/script/revised.js` — shared
  normalized-name-collision helper; invoke it in the three save handlers, gated
  through `tnConfirm()` before POST.
- (Optional, if server mirror included) `system/lib/ork3/class.Kingdom.php` —
  `CreateAward`/`EditAward` collision check honoring `AllowDuplicate`;
  `orkui/controller/controller.KingdomAjax.php` `setaward` — pass the flag
  through.

No DB/schema changes. No changes to grant records.

## Testing / Verification

- Add an alias named "Custom Award" when one exists → warning fires; cancel
  aborts; confirm proceeds and the row is created.
- Add a custom award named "order of the hunter" (different case/spacing) when
  "Order of the Hunter" exists → warning fires (normalization works).
- Inline-edit a row and save without changing its name → **no** warning
  (self-exclusion).
- Inline-rename a row to an unrelated unique name → no warning.
- Add a deliberately legitimate second alias of the same system award under a
  *new* distinct name (e.g. "Person-at-Arms") → no warning (different name);
  and under a colliding name → warning but override works.
- Verify the `tnConfirm` modal renders correctly in dark mode.

## Risks

- Low. The check is additive and soft; worst case is a spurious confirm prompt on
  an intended duplicate, which the admin overrides in one click. No data path
  changes unless the optional server mirror is implemented, which stays
  override-able.
