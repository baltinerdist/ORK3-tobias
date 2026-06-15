# Org Profile-Design DRY Refactor — Design Spec

**Date:** 2026-06-15
**Branch:** feature/mask-ii-org-enhancements
**Status:** Implemented (Kingdom/Park/Unit). Player migration attempted then **reverted** — see "Outcome: Player" below.

## Outcome: Player (reverted — left separate)

Player migration was attempted (Phase 5a: a configurable `auth_check` hook + a `milestone_semantics='player'` branch in the trait so Player's milestone CRUD could delegate). It was **reverted by decision** because it produced *negative* simplification: Player's milestone semantics diverge from the orgs on far more than auth (plain-array return, raw uncast ids, profanity-first ordering, preserve-old update, no guards), so "migrating" only relocated Player's code into the trait behind a flag — adding conditional complexity to the shared abstraction for ~zero dedup. `class.Player.php` is back at HEAD and the trait is purely org-focused. Player keeps its own (already self-contained) `mundane_design` / `player_milestones` implementation. **Lesson: Player is a superset, not a peer — do not force it onto `OrgDesign`.**

## Problem

The "Mask II" branch added manager-customizable profile design + milestones to three orgs
(Kingdom, Park, Unit) by **copy-pasting** a single implementation three times. A fourth org —
**Player** — already had an older, divergent design layer in `master` (`ork_mundane_design`,
`PlayerAjax` endpoints, `Get/Add/Update/DeleteCustomMilestone`). The result is large-scale
duplication across three layers, verified against `git diff origin/master..HEAD`:

| Layer | Duplicated | Nature |
|---|---|---|
| Library (`system/lib/ork3/`) | ~860 lines | `Set*Design`, `Get/Add/Delete*Milestone`, `GetDerived*Milestones`, design-row seeding — ~95% identical, differing only in table/FK names, validated-field lists, and derived-milestone thresholds |
| Controllers (`orkui/controller/`) | ~200 lines | Near-identical AJAX handlers; **inconsistency**: Kingdom/Park use `*Ajax/savedesign` (camelCase, dedicated controller) while Unit folds `save_design` (snake_case) into `controller.Unit.php` |
| Templates (`orkui/template/`) | ~2,700 lines | The 3-tab design modal, timeline, connect pills, markdown helpers, and inline CSS/JS — copy-pasted with only the `kn-`/`pk-`/`un-` prefix swapped |

**No new DB-layer violations were introduced by this branch** — all added controller/model code is
correctly layered (controllers parse + whitelist + delegate; models are pure pass-throughs; all
DB/ORM work lives in `class.*.php`). This refactor is therefore **purely DRY consolidation and
standardization — behavior-preserving**, not a layer-violation cleanup. (The app-wide layer
violations catalogued in `2026-06-15-layer-separation-refactor-inventory.md` are pre-existing and
out of scope here.)

## Goal

One shared, well-bounded design/milestone system consumed by all four orgs, so that adding a fifth
org or changing a validation rule is a one-place edit. Reduce ~3,760 duplicated lines by an
estimated 55–65% with **zero behavior change** on any existing endpoint or page.

## Non-Goals

- No new user-facing features. No schema changes beyond what already exists on the branch.
- No app-wide layer-separation cleanup (separate effort / separate spec).
- No change to Player's privacy, identity, or admin-gated field behavior.

---

## Architecture

### Layer 1 — Library: `trait OrgDesign`

New file `system/lib/ork3/trait.OrgDesign.php`, used by `Kingdom`, `Park`, `Unit`, and `Player`
(all already extend `Ork3`; a trait composes cleanly alongside single inheritance).

Each consuming class implements **one** method, `getDesignConfig()`, returning a contract:

```php
[
  'design_table'    => 'kingdom_design',      // 'mundane_design' for Player
  'fk'              => 'kingdom_id',           // 'mundane_id' for Player
  'milestone_table' => 'kingdom_milestones',   // 'player_milestones' (FK mundane_id) for Player
  'auth'            => AUTH_KINGDOM,            // null for Player (self-or-admin handled by override)
  'profanity_fields'=> ['AboutText','OurHistory','Tagline','Announcement'],
  'char_limits'     => ['AboutText'=>10000,'Tagline'=>160,'Announcement'=>280, ...],
  'derived'         => callable|null,          // returns the derived-milestone rows for this org
]
```

The trait provides the shared, **behavior-identical** implementations:

- `GetDesignMilestones($id)` — custom-milestone read (100% generic today)
- `AddDesignMilestone($request)` — create (auth + profanity + date + icon validation)
- `DeleteDesignMilestone($request)` — delete
- `UpdateDesignMilestone($request)` — edit. **Player-only today** (orgs have only Add/Delete); the
  trait provides it generically and Player routes to it. Orgs keep Add/Delete only — no new
  edit feature is exposed on org profiles (preserves the no-new-features non-goal).
- `GetDerivedDesignMilestones($request)` — caching + sorting orchestration; **delegates the actual
  query to the config's `derived` callable** (the one genuinely divergent piece)
- `seedDesignRow($id)` — the find-or-insert design-row bootstrap (currently duplicated 6×)
- **Reusable field validators** (static/protected helpers): hex color, font-name regex,
  hero-overlay enum, social-links JSON+URL normalization, profanity check, char-limit check,
  date parse, icon validation, milestone-config JSON. These are the highest-value extraction —
  every org and Player share them.

Org-specific design writers:

- **Kingdom / Park / Unit** each get a `Set{Org}Design()` that is now a thin wrapper: seed row →
  apply the **shared** common-field validators → apply a small `validateExtraFields()` override
  (Kingdom: `monarch_reign_started`, `regent_reign_started`, `reign_lore`; Unit:
  `recruitment_status`, `how_to_join`; Park: none) → save. The `about_enabled` opt-in gate stays
  exactly as-is.
- The derived-milestone `derived` callables stay org-specific (Kingdom/Park: org-attendance
  thresholds with their existing per-org threshold arrays; Unit: `unit_mundane` join). These move
  verbatim into closures/methods — **thresholds and queries are not changed**.

### Player: reuse the engine, not the org shape (refinement)

**Discovery during spec prep:** Player's design layer is a *superset*, not a peer. `updateprofile`
carries ~25 fields the orgs lack — privacy opt-ins (`ShowMundaneFirst/Last/Email`, `ShowBeltline`),
identity/name formatting (`NamePrefix/Suffix/SuffixComma/Persona/BeltDisplay/PronunciationGuide`),
photo focus (`PhotoFocusX/Y/Size`), and admin-gated fields (`Active`, `Waivered`, `ParkMemberSince`
— gated behind `HasAuthority` inside `UpdatePlayer`) — and it lacks org concepts (`announcement`,
`about_enabled`, org "history"). Forcing Player's profile-save through the org-shaped `SetDesign`
would produce a leaky god-trait, defeating the simplification.

**Resolution (still "Player on the shared abstraction," done correctly):**
- Player **consumes `trait OrgDesign`** for the **milestone engine** (custom CRUD + derived
  orchestration) and the **shared field validators** (colors, font, social links, profanity, etc.).
  This is the bulk of the real duplication and it *is* shared.
- Player keeps a thin, Player-specific design setter for its privacy/identity/admin fields. Today
  that logic is fused into the `UpdatePlayer` god-method; we extract the **design-customization
  portion** into a dedicated `SetPlayerDesign()` that calls the shared validators where they apply,
  leaving the admin-gated identity logic in `UpdatePlayer` untouched. Player's derived-milestone
  `derived` callable computes personal-attendance milestones.
- **Net effect:** Player stops duplicating the validators/milestone logic and gains the shared
  engine, without contaminating the abstraction with privacy/identity concerns.

### Layer 2 — Controllers: standardize

- Create **`controller.UnitAjax.php`**; move Unit's `save_design` / `add_milestone` /
  `delete_milestone` out of the `controller.Unit.php` index switch so all four orgs use a dedicated
  `*Ajax` controller.
- **Standardize action names** across all four `*Ajax` controllers: `savedesign`, `addmilestone`,
  `updatemilestone`, `deletemilestone`. This renames Unit's snake_case actions and Player's
  `updateprofile`→`savedesign`. Safe because the calling template JS is rewritten in the same branch.
- A shared controller helper (`orkui/lib/` or a controller trait) handles the identical
  parse→whitelist→delegate→JSON-encode flow incl. the profanity-error response shape; each
  controller supplies only its field whitelist. **Add the profanity-error branch to Unit** (it was
  missing — a real consistency bug surfaced by the review).
- Models stay pure pass-throughs (already correct).

### Layer 3 — Templates: shared partials + shared assets

Shared **plain-PHP** partials (rendered via `extract()`+`include`, per project convention — NOT
Smarty), parameterized by a `$ctx` array:

- `orkui/template/partials/_design_modal.tpl` — 3-tab Header/About/Milestones modal
- `orkui/template/partials/_milestones_timeline.tpl` — custom + derived timeline
- `orkui/template/partials/_connect_block.tpl` — social pills
- `orkui/template/partials/_design_helpers.php` — `*_markdown`, social-platform map, font list, snippet text
- One shared CSS file + one shared JS module, keyed off a `data-design-prefix` attribute so a single
  copy drives all orgs.

Each org template builds `$ctx` (prefix, org type, id, current design values, capability flags, save
endpoint, which optional sections to show — e.g. Kingdom's reign banner, Unit's recruitment pill)
and `include`s the partials. `$ctx` is the well-defined interface; a partial can be understood
without reading the host template.

---

## Risk & Verification

This is the highest-risk option, on a branch where **Kingdom/Park/Unit have not shipped** (low risk
— no production users yet) but **Player IS in production** (real regression risk). Mitigations:

1. **Sequence Player last**, after the trait is proven on the three orgs.
2. **Behavior-preserving discipline.** Every endpoint is a read or save. For each org and Player,
   capture before/after JSON from `savedesign` + each milestone action + the derived endpoint using
   the curl-auth session (login via `Login/login`, single cookie jar — see project memory), and
   **diff must be empty**.
3. **Static checks.** `php -l` + `php tools/php-cs-fixer.phar fix` on every touched PHP file
   (normalize-first workflow). JS/CSS smoke via page load with no console errors.
4. **Functional verification in Claude-in-Chrome (main loop, post-build):** exercise every new
   function on each of the four profiles — open design modal, change colors/gradient/overlay/font,
   edit About/History (+ reign/recruitment/how-to-join where applicable), social links, announcement,
   add/edit/delete a custom milestone, toggle milestone visibility + newest-first, toggle the
   `about_enabled` opt-in and confirm public vs. manager view. Verify light **and** dark mode.
5. **Regression test (small, near touched code):** confirm adjacent behaviors still work — the
   non-design parts of each profile page (stats, tabs, rosters), Player's privacy opt-ins
   (`ShowMundaneFirst/Last/Email`) and admin-gated fields still behave, the legacy About fallback
   when the gate is off, and that `UpdatePlayer` (which we partially extract) still saves identity
   fields correctly.

Nothing is "done" until: empty JSON diff, clean lint, no console errors, identical render in both
themes.

---

## Execution sequence (workflow phases)

1. **Trait pilot — Kingdom.** Build `trait OrgDesign`; migrate Kingdom lib methods to it; curl-diff
   Kingdom endpoints. Prove the seam before fanning out.
2. **Park + Unit lib migration** (parallel) onto the trait; curl-diff each.
3. **Controller standardization** — `controller.UnitAjax.php`, action-name unification, shared
   handler, Unit profanity-branch fix.
4. **Template partials** — extract shared modal/timeline/connect + CSS/JS; convert Kingdom, then
   Park, then Unit to include them; verify each page after conversion.
5. **Player migration (last)** — Player consumes the trait's milestone engine + validators; extract
   `SetPlayerDesign()`; convert Player template + endpoints to the standard; strict before/after diff.
6. **Integration + full QA** — comprehensive Chrome functional pass across all four orgs + the
   regression checklist above.

Each phase is reviewed before the next begins. Implementation is subagent-driven (fresh subagent per
task, review between).
