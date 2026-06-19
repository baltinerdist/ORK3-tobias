# Award System Expansion — Definitions, Custom Awards/Titles/Orders & Frictionless One-off Grants

**Date:** 2026-06-18
**Status:** Phase A **built** (uncommitted at time of writing); corrected below to match what actually shipped.
**Builds on:** `2026-06-18-award-management-redesign-design.md` (the dedicated Award Management page, already shipped)

## As-built corrections (read this first)

Implementation surfaced facts that changed the design. The body below is the original reasoning; these corrections override it where they conflict:

1. **One-off custom grants already exist.** The original spec's §6 ("frictionless one-off grants") was **already shipped on this branch** via migration `2026-04-14-custom-titles.sql` (`ork_awards.custom_name` + `alias_award_id`) — `class.Player.php::AddAward` persists them and the grant UI is wired. **Not rebuilt.** (A parallel workflow attempt to re-implement it was discarded.) This is the third tier from the model; it's done, not pending.
2. **No "add a standard" picker.** Data check: of 35 real kingdoms (freeholds / Þe Olde / a 9-award test group excluded), **34 are missing zero core-standard awards**; one is missing two. So "add a standard you're missing" solved a non-problem and was **dropped**. Per-subsection **"+ Add" is create-only** (create a kingdom-original award in that category). This also removed the confusing surfacing of niche national awards (Autocrat/Olympian/etc., used by only 4–7 kingdoms — *not* "standard").
3. **Badge flags the exception, not the norm.** No "Standard" badge (an opaque word on 98% of rows). Only **kingdom-created** awards get a **"Custom"** pill (hover: "Created by your kingdom — not a standard Amtgard award"). Standard awards are unbadged.
4. **Aliases = shared `award_id`, no schema change.** Confirmed from data: an alias is simply another `ork_kingdomaward` row sharing one system `award_id` (e.g. 35 kingdoms have "Woman-at-Arms" sharing `award_id 14` with "Man-at-Arms"). A **"+ Create Alias"** control in the edit drawer (standard awards only) creates sibling rows; they render with an **"Alias"** badge tooltipped **"Alias of [parent]"**. Aliasing custom awards is explicitly **not** supported (no shared id). No new column.
5. **Catch-all merged** into one **"Kingdom Awards & Orders"** group (the old "Offices & Other" + "Kingdom-Specific"); the Custom/no-badge distinction disambiguates within it.
6. **Phasing as it actually stands:** **A** (per-subsection create-only add + `classifyAward` honoring custom attributes + Custom badge + aliases) is **built**. **B** (one-off grants) **pre-existed** — done. **C** (kingdom ladders) is still future. **D** (promote one-off → definition) still optional.

## Problem

The shipped Award Management page made the existing model *legible*. This phase makes it *capable*. Today's award model has structural limits the data makes obvious:

- **Custom awards can't be categorized.** Every kingdom-original award (`award_id=0`) collapses into a single "Kingdom-Specific" bin regardless of its nature — even though 28 of them are flagged `is_title=1` and many are named "Order of X."
- **Two redundant custom paths.** Kingdoms create custom awards both via `award_id=0` *and* by aliasing a system **"Custom Award" placeholder** and renaming it — messy, duplicative data.
- **No intuitive way to expand the set.** Adding awards means a flat, unscoped alias picker; there's no per-category affordance, even though kingdoms think in categories and already carry ~the full standard set in each.
- **No first-class custom titles or kingdom orders.** Kingdoms clearly want them (Grand Marquis; Order of the Dreamkeeper/Hunter/Tactician) but the model can't represent them properly.

Most importantly, the analysis surfaced a **third, dominant use case the redesign initially missed**: **one-off custom grants.** Officers routinely give a player a single special recognition ("Spring 2027 Poetry Champion") without it ever being a defined award. This must stay **frictionless** — never requiring a kingdom officer to add it to the official set.

## Evidence (meta-analysis of the full prod dataset)

**Definitions** (`ork_kingdomaward`, ~5,006 rows, 38 kingdoms):
- 98% are aliases of standard awards; 94% keep the standard name. Aliasing = *enabling* a standard award in a kingdom; renaming is the ~6% case (top rename: **Man-at-Arms → Woman-at-Arms, 35×**).
- Standard pools per category are small & finite: Noble Titles 21, Paragons 17, Orders 16, Masterhoods 14, Associate 6, Knighthoods 5.
- Net-new custom *definitions* are rare (~101, only **16 of 40** kingdoms): new Orders, A&S/craft titles, honorifics, mis-placed reeve/officer titles, occasional new noble tiers.

**Grants** (`ork_awards`, ~384,520 rows):
- **17,858** one-off "Custom Award/Title" grants; **15,317** carry a note with the real name; **~8,600 distinct** one-off names. "Custom **Award**" carries 17,802 (officers use it even for titles; "Custom Title" is nearly unused at 56).

**Conclusion:** definitions are a small curated set kingdoms mostly *enable and occasionally rename*; one-off recognitions are a high-volume, ad-hoc, grant-time activity. These are different concerns and the design must separate them.

## The model: Source × Kind, across three tiers

Replace the tangle of `award_id`/`is_title`/`is_ladder`/`title_class`/`peerage`/placeholder with two explicit axes:

- **Source** — **Standard** (Amtgard's set, aliased into the kingdom) vs **Kingdom-original** (`award_id=0`, the kingdom made it).
- **Kind** — **Title** (confers a title) vs **Award/Recognition** (no title) vs **Order** (a series tracked over time).

These produce **three tiers**:

| Tier | What | Managed where | Volume |
|---|---|---|---|
| **Standard** | Amtgard awards enabled per kingdom (aliased, optionally renamed) | Award Management page | the bulk |
| **Kingdom award** | A *recurring* award the kingdom adds to its official set | Award Management page | rare, deliberate |
| **One-off custom grant** | A single special recognition for one player, one time — *no definition* | the **grant flow** (any officer) | ~18k, ~8.6k unique |

The officer's decision rule stays crisp: **recurring → define it as a Kingdom award; one-time → grant a one-off, zero admin.**

## Design by question

### 1. Make the patterns kingdoms already use easier
Per-subsection **"+ Add [Category]"** opens a **category-scoped** picker, framed as *"turn on the standard awards you're missing."* It shows that category's standard set with already-enabled ones marked, so expanding = ticking the missing ones (the small finite pools make this tractable). Renaming stays a per-award edit in the drawer. Knighthoods & Paragons get **no** button (Amtgard-controlled: fixed sets of 5 and 17, zero customs in the data).

### 2. Clean up redundant / bad-data paths
- **One custom-definition path:** kingdom-original definitions are always `award_id=0`. The "Custom Award" placeholder is **removed from the definition surface** — it no longer appears as something to alias into a kingdom's catalog.
- **The placeholder survives only as the one-off grant vehicle** (see §6) — it is a system sentinel, not a catalog award.
- **Migration:** existing kingdomaward rows that are renamed aliases of the "Custom Award" placeholder are reclassified — recurring ones become proper `award_id=0` Kingdom awards; the rest are recognized as one-off vehicles. `classifyAward` loses its `sysName==='Custom Award'` special case once data is normalized.

### 3. Custom Titles, made intuitive
"+ Add" on a **title** subsection (Noble / Associate / Masterhood) creates a **Kingdom-original Title** in that tier. The subsection you clicked answers "what kind," so the form is plain-language ("a new Baronial-tier title") and auto-sets `is_title=1` + a **category-default precedence**. A **"Kingdom" badge** distinguishes it from Standard. Fine precedence ordering still defers to the future Order of Precedence project. **Enabling change:** `classifyAward` must honor a kingdom-original's own attributes instead of flattening it.

### 4. Custom Awards & Orders (non-title recognitions)
Repurpose the catch-all into a clear **"Kingdom Awards & Orders"** home. "+ Add" there creates a Kingdom-original recognition (`is_title=0`), with a gentle naming nudge toward the "Order of the X" convention. These get a real section instead of an undifferentiated bin.

### 5. Kingdom ladders (distinguished from system ladders)
A **leveled "Kingdom Order"** — a Kingdom-original award the kingdom *opts into* tracking as levels 1…N. Explicitly **not** a system ladder: no Master capstone, no hardcoded `GetLadderMasterMap` entry, no system precedence; the kingdom defines its own max level. Precedent exists — `model.Award.php`'s hardcoded `$pseudoLadderIds` already fakes kingdom pseudo-ladders; this replaces that list with a real per-award flag. Distinguished visually ("Kingdom Order · levels" vs system "Order") and in data, and never allowed to masquerade as a system order in reports. **This is the heaviest piece** (touches the grant flow's level entry and reporting) and is **phased last**.

### 6. Frictionless one-off custom grants (the critical capability)
In the grant modal, alongside the official-set picker, a first-class **"One-off / Custom"** option any park/kingdom officer can use with **no kingdom-admin step**:
- Type the **award/title name directly** ("Spring 2027 Poetry Champion") as the *primary* field — not the note.
- Toggle **Award vs Title** (for sensible grouping on the profile).
- Optional note for context, as today.
- Stored as a one-off grant carrying the name as a **first-class field**; displays with its **real name** + a small "one-off" marker; **never enters the kingdom catalog.**

This is strictly easier than today (name is the first thing typed, not buried in a note), yields structured data (8.6k real names instead of free-text notes), and preserves the recurring-vs-one-time line exactly.

**Optional follow-on (not core):** "promote to the set" — when a one-off name recurs often, let a kingdom officer turn it into a real Kingdom award in one click.

## Architecture & data model

Layering unchanged (DB in `system/lib/ork3/`, thin controllers, plain-PHP templates).

**Schema changes**
- `ork_kingdomaward`: add `is_ladder tinyint NOT NULL DEFAULT 0` (kingdom-original orders — Standard awards still read `is_ladder` from `ork_award`), and `max_level tinyint NULL` (kingdom ladders, §5). `is_title`/`title_class` already exist. Source is implicit (`award_id=0` = Kingdom-original).
- `ork_awards` (grants): add `custom_name varchar(100) NULL` and `custom_is_title tinyint NOT NULL DEFAULT 0` for first-class one-offs. Forward-only — existing grants keep displaying via their current note-based path; no risky note-parsing backfill.

**Logic changes**
- `classifyAward` (JS + the PHP mirror in `model.Award.php`): for `award_id=0`, classify by the kingdom-original's own `is_title`/`title_class`/`is_ladder` instead of returning "Kingdom-Specific"; drop the `Custom Award` special case post-migration. **Consolidate the duplicated classifier** into a single source of truth as part of this work.
- `GetAwardList` / creation paths: accept and persist the new `ka` attributes; per-subsection add sets category-default `is_title`/`title_class`/`is_ladder`.
- Grant read/display (`AwardsForPlayer`, the grant modal, profile rendering): prefer `custom_name` when present.

**Surfaces touched**
- Award Management page (`Admin_awards.tpl`, `controller.Admin.php`, `class.Kingdom.php`): per-subsection add, custom-title/award creation, badges.
- Grant modal (`Playernew_index.tpl` + `script/revised.js` + `controller.PlayerAjax.php`): the one-off custom grant flow.
- `model.Award.php`: classifier consolidation + retire `$pseudoLadderIds`.

## Phasing

- **A — Definition model & per-subsection add** (the original ask): Source × Kind, `classifyAward` change + consolidation, `ka` schema (`is_ladder`), per-subsection "+ Add" (add-missing-standard + create Kingdom title/award), "Kingdom" badge, Custom-Award definition cleanup migration. Knight/Paragon excluded.
- **B — Frictionless one-off custom grants**: grant-modal one-off flow + `ork_awards.custom_name`. High value (user-emphasized "frictionless"); independent of A and can run in parallel.
- **C — Kingdom ladders**: `max_level`, leveled grant entry, report distinction, retire `$pseudoLadderIds`.
- **D (optional)** — promote a recurring one-off into a Kingdom award.

Recommended order: **A and B first** (parallel; B is high-value and self-contained), then **C**, then optionally **D**.

## Error handling, dark mode, testing

- Permissions: definition edits keep the existing `CanManageKingdom` gate; one-off grants use the existing **grant** permission (any park/kingdom officer who can already award players) — explicitly *not* the kingdom-admin gate, to preserve frictionlessness.
- All new surfaces dark-mode compatible proactively (`html[data-theme="dark"]`), `data-tip` tooltips, `tnConfirm` for destructive actions, IIFE config-flag guards.
- Migrations are additive (`NOT NULL DEFAULT`/nullable), non-destructive; the Custom-Award reclassification migration is reviewed against grant references before running.
- Verify in-browser + curl: per-subsection add (standard + custom) lands in the correct group; a custom title/award/order classifies correctly with the Kingdom badge; one-off grant shows its real name on the profile with zero kingdom-admin steps; kingdom ladder never appears as a system order in reports.
