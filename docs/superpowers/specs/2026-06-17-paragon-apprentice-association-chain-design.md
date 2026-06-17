# Paragon → Apprentice Association Chain — Design

**Date:** 2026-06-17
**Status:** Approved (design)

## Summary

Add a **Paragon → Apprentice** mentor/protégé association chain that mirrors the
existing **Knight → Squire** belt relationship. An Apprentice is a generic protégé
rank (no class binding); the mentor is recorded via the award's existing
`given_by_id` (a Paragon taking an Apprentice sets `given_by_id` to the Paragon).

The chain must surface in:
- the **My Peers / My Associates** section of the player profile, and
- the **award modals** (grant dropdown, award detail modal, custom-title "Alias of" dropdown).

It is **explicitly excluded** from the **Beltline Explorer** report for now.

## Background / Current State

- The `ork_award.peerage` ENUM in the live DB already includes both `'Paragon'` and
  `'Apprentice'` (added by `db-migrations/2018-06-18-crown-points.sql`). The base
  `ork.sql` predates this, but installs apply the migration. **No ENUM change is needed.**
- `'Paragon'` is a real, heavily-used peerage: 17 per-class award types
  (Paragon Archer, Paragon Wizard, …) with thousands of grants. It already gets its own
  optgroup ("Paragons") in the grant modal.
- `'Apprentice'` exists in the ENUM but has **zero** award rows and is referenced almost
  nowhere — effectively a dead value today.
- The mentor link already exists: the grant modal captures `given_by_id`
  (`class.Player.php::AddAward` sets `$awards->given_by_id`), and the modal even carries
  helper text: *"if a Knight is taking a Squire, enter the Knight's name here."*
- The **My Peers / My Associates** section is fed by **three inline `$DB->DataSet()`
  queries inside `controller.Player.php`** (≈ lines 588, 622, 655). These are an
  architecture-layer violation (raw SQL in a controller) and duplicate the protégé
  peerage list + ordering CASE three times.
- The **Beltline Explorer** report is fed by a *separate* method,
  `Report::BeltlineData()` (`class.Report.php` ≈ line 3199). The profile section and the
  explorer do not share a query, so they can diverge cleanly.

## Goals

1. Make Paragon→Apprentice a first-class association equivalent to Knight→Squire on the
   player profile and in award modals.
2. Define the protégé-peerage set **once**, in the correct layer, and consume it everywhere.
3. Move the inline beltline SQL out of the controller and into `system/lib/ork3/`
   (repair the layer mixing we are directly working in).

## Non-Goals (Out of Scope)

- **Beltline Explorer** (`Report::BeltlineData()`, `Reports_beltlineexplorer.tpl`,
  its `PEERAGE_PRIORITY`) stays classic-only — Apprentice/Paragon are NOT added there.
- **Per-class Apprentice** — Apprentice is a single generic rank (per the chosen design),
  not "Apprentice of the Paragon Archers."
- **Per-kingdom on/off toggle** — the chain is global, exactly like Knight→Squire.
- **Reporting / State of Amtgard** peerage rollups — not touched.

## Design

### 1. Schema (one migration)

`db-migrations/2026-06-17-apprentice-award.sql`:

- **No ENUM change** (`'Paragon'`/`'Apprentice'` already present).
- Insert one global **"Apprentice"** system award:
  `peerage='Apprentice'`, `is_title=1`, `title_class=15` (same tier as the Squire award),
  `officer_role='none'`, `is_ladder=0`. (Verify Squire's actual `title_class` at
  implementation time and match it.)
- **Idempotent:** skip the insert if an award with `peerage='Apprentice'` already exists.
- Kingdoms may customize the display name via `ork_kingdomaward`, same as Squire — no
  special handling required.

### 2. Lib layer — single source of truth (`system/lib/ork3/`)

**`class.Award.php`**
- Add `public static function ProtegePeerages(): array` returning the ordered list
  `['Squire','Man-At-Arms','Lords-Page','Page','Apprentice']`. This is the single source
  for both the SQL `IN (...)` clause and the `ORDER BY CASE` (both built programmatically
  from the array, so the duplicated CASE blocks disappear).
- `fetch_custom_title_alias_options()`: add `'Apprentice'` to the peerage `IN (...)` list,
  the `FIELD(peerage, …)` ordering, and the `in_array(...)` filter. **Paragon is NOT added**
  (Paragons are concrete per-class awards, not alias targets).

**`class.Player.php`**
- Add `GetBeltlinePeers(int $id): array` — "who gave this player a protégé-rank award"
  (the player's mentors). SQL moved verbatim from the controller, with the protégé set
  sourced from `Award::ProtegePeerages()`. Preserves the existing `woman-at-arms`
  text-match clause and the `revoked` / `given_by_id > 0` guards.
- Add `GetBeltlineAssociates(int $id): array` — "who this player gave a protégé-rank award
  to" (the player's protégés). The controller's third query (`given_by_id = $uid`, the
  logged-in viewer) collapses into a second call to this method — removes the duplicate.
- Both methods `$DB->Clear()` before/after, consistent with the existing controller code
  and the project's stale-binding rule.

**`class.Report.php`**
- `BeltlineData()` is left as-is (classic belt ranks only). Add a one-line comment marking
  the deliberate divergence: the profile association section includes Apprentice, the
  explorer does not (yet).

### 3. Controller (`controller.Player.php`)

- Replace the three inline SQL blocks (≈ lines 588–680) with:
  - `$this->data['BeltlinePeers'] = $this->Player->GetBeltlinePeers((int)$id);`
  - `$this->data['BeltlineAssociates'] = $this->Player->GetBeltlineAssociates((int)$id);`
  - (own-profile block) `... = $this->Player->GetBeltlineAssociates($uid);`
  via the model `__call` pass-through. Net result: no raw SQL remains in this controller block.

### 4. Award modals ("show in award modals")

**Grant dropdown** (`orkui/model/model.Award.php`, `fetch_award_option_list`)
- The new Apprentice award already routes into the protégé/"Associate Titles" optgroup via
  the existing `$sysName === 'Apprentice'` special-case. Switch its hardcoded protégé list
  to reference `Award::ProtegePeerages()` for robustness (so peerage-based routing also
  works, not only name-based).

**Award detail modal** (`orkui/template/.../Playernew_index.tpl`)
- Add `'Apprentice'` to the belt-treatment gate (≈ line 2123) so an Apprentice award is
  rendered as a belt/association award (with its mentor) in the detail view.
- Add `'Apprentice'` to the `$_maPeerageLabels` map (≈ line 1619).

**Custom-title "Alias of" dropdown**
- Driven by `Award::fetch_custom_title_alias_options()` (covered in §2). After the change,
  kingdoms can create a custom-named title (e.g. "Protégé") that counts as Apprentice.

### 5. Template labels (`Playernew_index.tpl`)

- `$_blPeerLabels` (≈ line 1712): `'Apprentice' => 'Apprentice to'`
- `$_blAssocLabels` (≈ line 1730): `'Apprentice' => 'Apprentices'`

## Data Flow

```
Grant: Paragon selects "Apprentice" award for recipient, enters self as Given By
   → ork_awards row: award_id=<Apprentice>, mundane_id=<apprentice>, given_by_id=<paragon>

Apprentice's profile  → Player::GetBeltlinePeers(apprentice_id)
   → row where mundane_id=apprentice AND peerage ∈ ProtegePeerages()
   → "Apprentice to {Paragon persona}"   (My Peers)

Paragon's profile     → Player::GetBeltlineAssociates(paragon_id)
   → row where given_by_id=paragon AND peerage ∈ ProtegePeerages()
   → "Apprentices: {names}"              (My Associates)

Beltline Explorer     → Report::BeltlineData()  [classic list, Apprentice excluded]
   → Apprentice rows do NOT appear
```

## Change Surface (file checklist)

| Layer | File | Change |
|---|---|---|
| Migration | `db-migrations/2026-06-17-apprentice-award.sql` | Insert global Apprentice award (idempotent) |
| Lib | `system/lib/ork3/class.Award.php` | Add `ProtegePeerages()`; add `'Apprentice'` to alias options (list/ordering/filter) |
| Lib | `system/lib/ork3/class.Player.php` | Add `GetBeltlinePeers()`, `GetBeltlineAssociates()` (SQL moved from controller) |
| Lib | `system/lib/ork3/class.Report.php` | Comment marking deliberate Apprentice divergence in `BeltlineData()` |
| Controller | `orkui/controller/controller.Player.php` | Replace 3 inline SQL blocks with lib calls |
| Model | `orkui/model/model.Award.php` | Route protégé optgroup via `Award::ProtegePeerages()` |
| Template | `orkui/template/.../Playernew_index.tpl` | Apprentice in `$_blPeerLabels`, `$_blAssocLabels`, `$_maPeerageLabels`, belt gate (~2123) |

## Testing / Verification

1. **Lint** all touched PHP.
2. **Migration**: run against local DB; confirm exactly one `peerage='Apprentice'` award
   exists and re-running is a no-op (idempotency).
3. **Synthetic data**: insert an `ork_awards` row granting the Apprentice award to player B
   with `given_by_id` = a Paragon (player A).
4. **My Peers**: load `Player/profile/{B}` → "Apprentice to {A}" renders under My Peers.
5. **My Associates**: load `Player/profile/{A}` → "Apprentices: {B}" renders.
6. **Grant modal**: Apprentice appears in the protégé optgroup; Given By captures the mentor.
7. **Detail modal**: the Apprentice award renders as a belt/association award with mentor.
8. **Alias dropdown**: "Apprentice" is an available alias target; Paragon is not.
9. **Beltline Explorer**: confirm Apprentice rows do NOT appear (negative test).
10. **Dark mode**: walk every touched profile/modal surface in dark mode.

## Open Questions

None — design approved 2026-06-17.
