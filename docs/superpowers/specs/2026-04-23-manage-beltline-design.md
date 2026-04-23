# Manage Beltline — Self-Service Associations

**Branch:** `feature/manage-beltline`
**Date:** 2026-04-23
**Approach:** Option A — self-service, trust-based, no consent handshake.

## Problem

A player who is eligible to take associates (knight, squire, any noble title) currently must ask a park or kingdom officer to record the association in `ork_awards`. An associate who wants to drop their sponsor also has to ask an officer to revoke the award. This is friction for what is fundamentally a mutual relationship between two players, and it piles unnecessary work on officers.

## Goal

Let either party manage their own beltline associations from the Playernew profile without officer intervention:

- A player may take another player as an associate.
- Either party may end an existing association.

Officer oversight remains available via the existing award admin UI, but is not required for ordinary adds and ends.

## Approach summary

- Reuse the existing `ork_awards` storage model for associations — no new tables.
- Use the existing `revoked` / `revoked_at` / `revoked_by_id` / `revocation` columns for soft-delete, with `revocation = 'ended'` as a sentinel that distinguishes a mutual end from a true revocation.
- Trust-based eligibility — any logged-in player can take any associate, and any associate may end their own sponsorship. UI shows all four associate title types (Squire, Man-at-Arms, Page, Lord's Page) and their kingdom-award aliases at all times. Community norms police misuse; abuse is visible via the Beltline Explorer.
- A single "My Beltline" card on the own-profile Playernew view with two columns — My Sponsors and My Associates.

## Data model

**No schema change.** `ork_awards` already has every column we need.

- Active association row: `ended implicitly defined as revoked = 0 OR revoked IS NULL`.
- Ended association row (via self-service): `revoked = 1`, `revoked_at = CURDATE()`, `revoked_by_id = <session user>`, `revocation = 'ended'`.
- True revocations (officer strips a title) continue to use the same columns with a different `revocation` string (`''`, `'stripped'`, `'error'`, etc. — whatever the existing admin paths already write).

**Consumer implication:** every existing query that filters active beltline rows already uses `revoked = 0 OR revoked IS NULL`. Ended rows are filtered out automatically; no new `WHERE` clauses to add in consumers.

**Tradeoff accepted:** ended rows appear in whatever officer "revoked awards" list exists, distinguishable by `revocation = 'ended'`. Implementation will filter `revocation != 'ended'` out of that officer view so it stays clean.

## Eligibility

Trust-based. No peerage-based gating.

- Any logged-in player may take any other player as an associate.
- Title picker always shows all four associate types plus every `ork_kingdomaward` alias in the mentor's kingdom that aliases one of the four core associate award IDs.
- Server-side validation is a minimal sanity check — the posted award must resolve to one of the four core associate award IDs (directly or through a kingdom alias). This prevents endpoint misuse from creating non-associate award rows (e.g. a Knight of the Flame) but does not enforce peerage rank on the mentor.

Rationale: kingdoms vary in what they allow (some permit man-at-arms to nobles). Encoding a rigid rule would block legitimate variations.

## UI — Playernew own profile

Replace the current "My Associates" card in `orkui/template/revised-frontend/Playernew_index.tpl` (lines 987-1010) with a "My Beltline" card.

### Layout

```
┌──────────────────────────────────────────────────────────────────┐
│  My Beltline                                                     │
├──────────────────────────────────┬───────────────────────────────┤
│  My Sponsors                     │  My Associates   [+ Take New] │
│                                  │                               │
│  • Sir Alric   — Squire (2019)   │  • Jayne   — Squire (2022)    │
│                           [End]  │                        [End]  │
│  • Duke Corwin — Page   (2017)   │  • Riven   — Man-at-Arms …    │
│                           [End]  │                        [End]  │
│                                  │                               │
│  (empty state: "No current       │  (empty state: "You have no   │
│   sponsors.")                    │   associates yet. Take one?") │
└──────────────────────────────────┴───────────────────────────────┘
```

- Two-column grid on desktop, stacked on mobile.
- Gated on `$isOwnProfile` — unchanged visibility scope.
- Each row: persona (linked to their Playernew profile), title held in the relationship, start date ("Since April 2019"), `[End]` button.
- `[+ Take New]` button in the My Associates column header — always shown to the profile owner.
- **No "Join Sponsor" or "Ask to be sponsored" button** — mentors always initiate. You cannot ask someone for a belt via the ORK.
- All CSS uses the existing `pn-` prefix. All JS inlined in the template. Dark-mode compatible proactively (memory rule).

### Data sources

- **My Associates** — extend the existing query in `controller.Player.php` (~line 525) to also return `awards_id`.
- **My Sponsors** (new) — mirror the existing query with `WHERE ma.mundane_id = $uid` (instead of `ma.given_by_id = $uid`), same peerage + kingdom-alias filter, joined to `ork_mundane` on `ma.given_by_id` to get the sponsor's persona.

Both lists filter `(ma.revoked = 0 OR ma.revoked IS NULL)` — unchanged from the existing pattern.

## UI — Take Associate modal

Opened by the `[+ Take New]` button.

**Fields:**

- **Person** — custom `kn-ac-results` autocomplete (memory rule — never jQuery UI). Dropdown uses `tnFixedAcPosition()` + `position: fixed` because it's inside a modal (memory rule). Queries `controller.PlayerAjax.php::player action=beltline_playersearch`. Disallows selecting self.
- **Title** — radio list of the four core associate types plus every `ork_kingdomaward` alias in the mentor's kingdom that aliases one of those four. Each option carries `{ award_id, kingdomaward_id? }`. Kingdom aliases show a small "(kingdom alias)" sub-caption.
- **Start date** — flatpickr with `altInput: true`, `altFormat: 'F j, Y'` (memory rule — no raw ISO visible). Default today. `maxDate: 'today'` — no future dates. No lower bound.
- **Note** — optional textarea mapped to `ork_awards.note` (400 chars). Char counter.

**Submit:** POST to `controller.PlayerAjax.php::player action=beltline_take`.

**Player search endpoint (`beltline_playersearch`):**

- New action on `controller.PlayerAjax.php`.
- Query pattern copied from `controller.ParkAjax.php::playersearch` (~lines 180-240), anchored on the session user's `park_id` so scope priority is: own park → own kingdom → everywhere.
- Preserves the existing abbreviation-prefix syntax (e.g. `EH: wolf`, `EH:RD wolf`).
- Max 15 results. Excludes self. Excludes suspended. Active = 1.

## UI — End Association modal

Triggered by any row's `[End]` button in either column.

Single confirm step:

```
You're ending your association with Sir Alric as their Squire.

This can't be undone from here — a park or kingdom officer would
need to restore it.

                                    [ Cancel ]  [ End ]
```

Wording adapts by side:

- From My Sponsors: "You're ending your association with **{sponsor}** as their **{title}**."
- From My Associates: "You're ending **{associate}**'s association as your **{title}**."

**Submit:** POST to `controller.PlayerAjax.php::player action=beltline_end` with `{ awards_id }`.

## Endpoints

All three live on `controller.PlayerAjax.php::player($p)` as new branches in the existing action-dispatch `elseif` chain (pattern of `addnote`, `moveplayer`, `deleteaward`, etc.). No new files.

### `action=beltline_playersearch`

- Input: `q` (search term, supports `KK:*` / `KK:PP` prefix).
- Output: JSON array (max 15) with `MundaneId`, `Persona`, `ParkName`, `KingdomName`, `p_abbr`, `k_abbr`.
- Anchored on session user's `park_id` for scope priority.

### `action=beltline_take`

- Input: `mundane_id`, `award_id`, optional `kingdomaward_id`, `date`, optional `note`.
- Validations:
  1. Actor is a logged-in user (session `user_id > 0`).
  2. Target `mundane_id != session.user_id`.
  3. Posted `award_id` resolves to one of the four core associate award IDs, directly or via `ork_kingdomaward.alias_award_id` — reject otherwise.
  4. `date <= today`.
  5. No existing active row with the same `given_by_id`, `mundane_id`, `award_id` (and `kingdomaward_id` when present) — reject duplicates with "This association already exists."
- `$DB->Clear()` before the INSERT (memory rule).
- INSERT row with: `given_by_id = session.user_id`, `mundane_id = target`, `award_id`, `kingdomaward_id` (0 if none), `date = posted`, `note` (if any), `revoked = 0`, `by_whom_id = session.user_id`, `entered_at = NOW()`, reasonable defaults for unused fields.
- Flush memcache for both players' profile / beltline keys.
- Output: `{ success: true, row: {...display data...} }`.

### `action=beltline_end`

- Input: `awards_id`.
- Validations:
  1. Row exists.
  2. Session `user_id` equals the row's `given_by_id` OR its `mundane_id`. Otherwise reject as 403 JSON.
  3. Row is not already revoked (`revoked = 1`) — otherwise reject with "This association has already ended."
- `$DB->Clear()` before UPDATE.
- UPDATE: `revoked = 1`, `revoked_at = CURDATE()`, `revoked_by_id = session.user_id`, `revocation = 'ended'`.
- Flush memcache for both players' profile / beltline keys.
- Output: `{ success: true, awards_id }`.

## Controller-level changes

`controller.Player.php` — in the profile-data-loading path (~lines 523-552):

- Keep `$this->data['MyAssociates']` (to avoid template churn elsewhere).
- Add `$this->data['MySponsors']` with the mirror query.
- Both queries also return `AwardsId` so the `[End]` button has a handle.
- Resolve kingdom-award aliases for the title picker into `$this->data['BeltlineTitleOptions']` — an ordered list of `{ label, award_id, kingdomaward_id, is_alias }` entries, built once server-side from the mentor's kingdom.

## Consumer updates

- `controller.Player.php` MyAssociates query — already filters `(ma.revoked = 0 OR ma.revoked IS NULL)`. No change.
- `class.Report.php::BeltlineData` (~line 2527) — confirm `revoked = 0` filter is in place; add if missing.
- Beltline Explorer (`Reports_beltlineexplorer.tpl`) — no template change, relies on `BeltlineData`.
- Voting eligibility reports (Emerald Hills, Winter's Edge, Dragonspine) — spot-check for the same filter; no expected changes.
- Officer "revoked awards" list (location TBD during implementation — grep required) — add `AND revocation != 'ended'` so ended beltline rows don't leak in.
- Memcache flushes — implementation phase enumerates the exact GhettoCache keys to bust on take/end for both players.

## Edge cases

- **Self-take:** rejected by validation.
- **Duplicate active (same mentor/target/title):** rejected by validation.
- **Many-to-many:** multiple sponsors across different mentors, or different titles from one mentor, are allowed.
- **Simultaneous end by both parties:** second request gets the "already ended" error cleanly.
- **Ending a row the user isn't part of:** 403 JSON error.
- **Cross-kingdom associate:** allowed — no locality gate. Title picker is built from the mentor's kingdom alias vocabulary only.
- **Stale memcache:** flushed on take/end for both players (memory rule).

## Error handling

- All modal errors render in an in-modal red banner. No toasts, no page reloads.
- All JSON error responses include a user-safe `message` field.
- Debug output uses `console.log` / `die(json_encode(...))` only (memory rule).

## Authorization

- Self-service endpoints rely on the existing session guard in `PlayerAjax::player()`. The session `user_id` is always the actor.
- Officer override continues through the existing award admin UI — unchanged.

## Manual QA checklist

1. Own-profile: "My Beltline" renders both columns, correct data, empty states work.
2. Other's profile: block not visible.
3. Take Associate modal: player search prioritizes own park > own kingdom > elsewhere.
4. Take with core award (Squire) inserts correct row.
5. Take with kingdom alias (Woman-at-Arms in EH) inserts row with the right `kingdomaward_id`.
6. Take with backdated date writes that date.
7. Duplicate take shows error.
8. Self-take shows error.
9. End from mentor side: row moves out of My Associates.
10. End from associate side: row moves out of My Sponsors.
11. End already-ended row shows graceful error.
12. End-then-refresh confirms persistence (memcache flushed correctly).
13. Officer `ork_awards` admin view shows the row with `revoked = 1, revocation = 'ended'`.
14. Officer "revoked awards" list does NOT show rows with `revocation = 'ended'`.
15. Beltline Explorer reflects the end — row no longer appears as active.
16. Dark mode: modal + card render correctly; no light-mode bleed.
17. Mobile: two columns stack.
18. Autocomplete dropdown in modal positions correctly inside the modal (no clipping).

## Memory-rule checklist for implementation

- Custom `kn-ac-results` autocomplete — not jQuery UI.
- `$DB->Clear()` before every raw Execute/DataSet.
- Debug via `console.log` / `die(json_encode(...))` only.
- Autocomplete inside modal → `tnFixedAcPosition()` + `position: fixed`.
- Dark-mode compatibility proactively on all new CSS.
- Flatpickr with `altInput: true` + human-readable `altFormat`.
- No native `title` tooltips — use `data-tip` pattern.
- No browser tooltips anywhere.
- For multi-line PHP edits: use Python, not the Edit tool (tab/space matching).
- Do not stage `CLAUDE.md`, `agent-instructions/claude.md`, or `class.Authorization.php`.
- Never IIFE-guard `revised.js` sections with `document.getElementById(...)`; use a `PnConfig.*` flag.
- Heading elements inside hero/card/modal contexts must reset the global `h1-h6` box styling.

## Out of scope

- Invitation/consent handshake (Option B).
- Separate `ork_beltline_association` table (Option C).
- Officer audit feed for recent beltline changes (Option D).
- Public visibility of the My Beltline section on non-own profiles.
- Restoring an ended association from the self-service UI.
- Notifications to either party when taken or ended.
- Peerage-based eligibility enforcement.
