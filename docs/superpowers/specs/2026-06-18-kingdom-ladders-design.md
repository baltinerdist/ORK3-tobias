# Kingdom Ladders (Award System Expansion — Phase C) Design Spec

**Date:** 2026-06-18
**Status:** Approved (design) — pending implementation plan
**Builds on:** `2026-06-18-award-system-expansion-design.md` (Phase A built; this is its Phase C). The dedicated Award Management page and per-subsection custom-award creation already shipped.

## Problem

Kingdoms invent their own award series ("Order of the Hunter", "Order of the Dreamkeeper") and want to track a recipient's *progression* through them — level 1, 2, 3… — the way the system "Orders" (Rose, Dragon, Warrior) work. Today they can't: ladder-ness lives on `ork_award.is_ladder` (the global system award), and a kingdom-original award (`award_id=0`, linked to the generic "Custom Award" system row with `is_ladder=0`) has no way to be leveled. The only existing workaround is a **hardcoded `$pseudoLadderIds` allow-list** in `model.Award.php` — a static list of `kingdomaward_id`s manually treated as ladders. Kingdom Ladders replaces that hack with a real, self-service capability.

## Goal

Let a kingdom mark one of its **own custom awards** as a leveled "Order" with a kingdom-defined max level, grant it at a chosen level using the **existing rank-pill machinery**, and see the level on the player's profile — while staying **cleanly distinct from system orders** (no Master capstone, no top-out logic, never appearing in system-order reports/grids).

## Ladder taxonomy (canonized)

Amtgard's **Award Standardization** defines exactly **nine** ladder awards that form the Order → Masterhood → Knighthood progression. The catalog splits the single "Ladder Awards (Orders)" group into two:

- **"Ladder Awards (Award Standardization)"** — the canonical nine, identified by system `award_id`:
  `21` Rose, `22` Smith, `23` Lion, `239` Crown, `24` Owl, `25` Dragon, `26` Garber, `27` Warrior, `243` Battle.
  (These lead to the nine Masterhoods — Master Rose/Smith/Lion/Crown/Owl/Dragon/Garber, Warlord, Battlemaster — which lead to the five Knighthoods: Flame, Crown, Serpent, Sword, Battle.)
- **"Kingdom and Other Ladder Awards"** — every other ladder: the remaining system orders that exist today (Jovius `28`, Mask `29`, Zodiac `30`, Walker in the Middle `31`, Hydra `32`, Griffin `33`, Flame `34`), the 24 legacy pseudo-ladders, and any **kingdom-created** ladder (this is where Kingdom Ladders land).

The canonical nine is a fixed, stable Amtgard standard, so it is encoded as a defined constant list of the nine `award_id`s (`CANONICAL_LADDER_AWARD_IDS`), used by `classifyAward` (and mirrored where the grant-side classifier needs it). This replaces the prior decision that kingdom ladders stay in "Kingdom Awards & Orders."

## Key facts from the current system (that this design relies on)

- A ladder award is identified today in five hardcoded places that must stay in sync: `ork_award.is_ladder`; `GetLadderMasterMap()` (`class.Award.php:17`); `$pnOrderToMaster`/`$pnOrderNames` (`Playernew_index.tpl`); the JS `PnConfig.ladderMasterMap`; and `$pseudoLadderIds` (`model.Award.php:37`).
- **The rank-grant mechanics are already decoupled from system identity.** The grant picker emits `data-is-ladder='1'` (UI trigger → show rank pills) and `data-award-id` (capstone identity, used to look up `GetLadderMasterMap`). Pseudo-ladders already set `data-is-ladder='1'` with `data-award-id='0'` — rank pills, *no* capstone, *no* top-out. **This is exactly kingdom-ladder behavior.**
- `ork_awards.rank` stores the per-grant rung for any award (`AddAward` → `class.Player.php:1787`); a player's current level = `MAX(rank)`. Reused unchanged.
- `MaxRank` is hardcoded (10, or 12 for Zodiac) in `buildRankPills()`, the recommend dialog, the profile grid, and reports. A kingdom-defined max needs a new column threaded into the grant picker + pill builder (the others — grid/recommend/report — are deferred).
- Reports/grids filter on `ork_award.is_ladder` via the `award_id` FK (`controller.Reports.php:1020/1026/1091`; `class.Report.php:325/420`). Because kingdom ladder-ness lives on `ork_kingdomaward` (not on a shared system `award_id`), those queries **exclude kingdom ladders by construction** — no extra work needed to keep them out.

## Scope

### In scope (v1)
- **Canonize the ladder taxonomy:** split the catalog's "Ladder Awards (Orders)" into "Ladder Awards (Award Standardization)" (the nine) and "Kingdom and Other Ladder Awards" (everything else laddered). This touches the already-shipped Phase A catalog (`Admin_awards.tpl`) and is bundled here because kingdom ladders need the second group as their home.
- Define: a "Track as levels (Order)" toggle + Max level on a **custom** kingdom award, in the Award Management drawer.
- Grant: the existing rank-pill picker, driven by the kingdom award's `max_level`.
- Display: the granted level visible on the player profile (the existing rank pill in the awards list/feed).
- Cleanup: replace the hardcoded `$pseudoLadderIds` list with the new `ka.is_ladder` flag (with a backfill migration so existing pseudo-ladders keep working).

### Explicitly deferred (per design review)
- The kingdom-ladder **progress grid** (bars/tiles) on the profile.
- Any kingdom-ladder **report** or report-grid section.
- **Recommendation-flow** top-out integration for kingdom ladders.
- Leveling **standard** (non-custom) awards — system-controlled, out of scope.
- Master/capstone concept for kingdom ladders — intentionally none.

## Architecture

Layering unchanged: schema migration, DB logic in `system/lib/ork3/`, thin controllers, plain-PHP templates.

### 1. Schema (one additive migration)
`db-migrations/2026-06-18-kingdomaward-ladder.sql`:
```sql
ALTER TABLE ork_kingdomaward
  ADD COLUMN is_ladder tinyint(1) NOT NULL DEFAULT 0 AFTER award_id,
  ADD COLUMN max_level tinyint(1) NOT NULL DEFAULT 0 AFTER is_ladder;
```
Backfill the existing pseudo-ladders so behavior is preserved, then they no longer need the hardcoded list:
```sql
UPDATE ork_kingdomaward
   SET is_ladder = 1, max_level = 10
 WHERE kingdomaward_id IN (7067,7249,6628,5813,6045,6050,6430,6283,7055,
                           6403,6297,7273,7070,6311,6310,7277,6411,6771,
                           6577,94,7084,6171,6574,7254);
```
`ork_awards.rank` is unchanged.

### 2. Lib (`system/lib/ork3/class.Kingdom.php`)
- `GetAwardList` returns `IsLadder` (true when **either** the linked system award's `a.is_ladder` **or** the kingdom row's `ka.is_ladder` is set) and `MaxLevel` (from `ka.max_level`) per row. This single combined flag drives both the catalog and the grant picker.
- `CreateAward` / `EditAward` accept and persist `IsLadder` + `MaxLevel`. Guard: only honor them when the award is kingdom-original (`award_id=0`); ignore for aliased standard awards.

### 3. Award Management drawer (`Admin_awards.tpl` + `controller.Admin.php`)
- The `awards()` feed (`AdminAwards`) already maps per-award fields; add `IsLadder` + `MaxLevel`.
- In the edit drawer, for a **custom** award only (`AwardId===0`), show a **"Track as levels (Order)"** toggle. When checked, reveal a **Max level** number input (default 10, min 1, max 20). Hidden for standard awards.
- On Save, send `IsLadder` (0/1) + `MaxLevel` to `setaward`. (`setaward` → `CreateAward`/`EditAward` already exist; thread the two fields through `controller.KingdomAjax.php`'s `setaward` action.)
- Catalog grouping (per the Ladder taxonomy above): `classifyAward` routes any ladder award (system `a.is_ladder` OR kingdom `ka.is_ladder`) to **"Ladder Awards (Award Standardization)"** when its `award_id` is in `CANONICAL_LADDER_AWARD_IDS`, otherwise to **"Kingdom and Other Ladder Awards"**. A leveled kingdom award (`award_id=0`) therefore lands in "Kingdom and Other Ladder Awards" (never the canonical group). `GROUP_ORDER`/`GROUP_BLURB` replace the single `'Ladder Awards (Orders)'` entry with these two. Leveled awards keep their existing **`Ladder`** badge (optionally relabeled "Levels").

### 4. Grant picker + rank pills (`model.Award.php`, `Playernew_index.tpl`, `revised.js`)
- `model.Award.php::fetch_award_option_list`: **replace** the `$pseudoLadderIds` allow-list with `!empty($award['IsLadder'])` driven by `ka.is_ladder`. For a kingdom ladder (kingdom-original + `ka.is_ladder=1`), emit the option with `data-is-ladder='1'`, `data-award-id='0'` (no system capstone), and a new **`data-max-level='<MaxLevel>'`**. (`GetAwardList` must surface `IsLadder`/`MaxLevel` for this builder; confirm the model path passes them through.)
- `revised.js::buildRankPills(awardId)`: read `data-max-level` from the selected option; if present (>0) use it as the pill count; else fall back to the existing 10/12 rule (system orders unchanged).
- `class.Player.php::AddAward`: unchanged — stores `rank`.

### 5. Profile display (minimal)
- `class.Player.php::AwardsForPlayer`: include `ka.is_ladder` in the ladder COALESCE (`COALESCE(alias.is_ladder, a.is_ladder, ka.is_ladder)`) so a kingdom-ladder grant is flagged `IsLadder` and its `rank` renders. This makes the level show via the existing rank pill (`pna-feed-rank`, guarded by `valid_id(rank)`).
- Do **not** add kingdom ladders to the system progress grid (`$pnOrderToMaster`/`$pnOrderNames` loops) — deferred. They simply display with their level on the award row/feed.

## Data flow
Define (drawer) → `setaward` → `Kingdom::CreateAward/EditAward` persists `is_ladder`/`max_level` on `ork_kingdomaward`. Grant (player page) → award picker reads `IsLadder`/`MaxLevel` → `data-is-ladder` + `data-max-level` → rank pills 1…max → `AddAward` writes `ork_awards.rank`. Display → `AwardsForPlayer` flags `IsLadder` via `ka.is_ladder` → level pill renders.

## Error handling / edges
- Only `award_id=0` (kingdom-original) awards can be leveled; the lib ignores `IsLadder`/`MaxLevel` on aliased standard awards.
- `max_level` clamped to 1–20 server-side; default 10 when the toggle is turned on with no value.
- Toggling levels off, or lowering `max_level` below existing grants' rank, leaves existing `ork_awards` rows untouched (lenient; no retroactive rewrite). A level above the current max simply isn't offered in the picker going forward.
- A kingdom ladder never appears in system-order reports/grids (lives only on `ork_kingdomaward`); no extra exclusion code needed.

## Dark mode / conventions
- The toggle + max-level field follow the existing drawer styling and dark-mode rules (`html[data-theme="dark"]`); `data-tip` for any help; no native tooltips/dialogs.

## Testing
- Migration applies; `ka.is_ladder`/`max_level` present; the 24 pseudo-ladders backfilled.
- Define: toggling "Track as levels" + max on a custom award persists `is_ladder=1, max_level=N` (curl + DB); hidden on standard awards.
- Grant: the kingdom ladder shows the rank picker with N pills (= max_level); granting level k writes `ork_awards.rank=k`.
- Display: the player profile shows the kingdom award with its level pill; it does **not** appear in the system ladder grid or the Reports ladder grid.
- Regression: system orders (Rose etc.) still grant with 10/12 pills and show Master capstones; the retired `$pseudoLadderIds` awards still behave as ladders via the new flag.
