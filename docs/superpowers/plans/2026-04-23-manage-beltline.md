# Manage Beltline Implementation Plan

> **For agentic workers:** Implement task-by-task. Commit after each task.

**Goal:** Self-service add/end of beltline associations on the Playernew own-profile page (Option A — trust-based, no consent handshake).

**Architecture:** Reuse `ork_awards` storage. End of association = `revoked=1, revocation='ended'` sentinel. New backend endpoints on `controller.PlayerAjax.php::player()` dispatch chain. New "My Beltline" card with two columns replaces the existing "My Associates" block on the own-profile Playernew view.

**Tech Stack:** PHP 8, MariaDB 10, vanilla JS + existing `kn-ac-results` autocomplete pattern, Flatpickr, GhettoCache. No build step, no unit tests (codebase has no PHP unit test harness — manual QA only).

**Core associate award IDs:** 13 (Lord's Page), 14 (Man-at-Arms), 15 (Page), 16 (Squire).

---

## Task 1: Backend — MySponsors + BeltlineTitleOptions

**Files:**
- Modify: `orkui/controller/controller.Player.php` (block starting ~line 523)

**Step 1.1:** After the existing `$this->data['MyAssociates'] = $__assocs;` block, add a mirror query for sponsors (where the viewer is `ma.mundane_id`), returning `AwardsId`, `SponsorId`, `Persona`, `TitleName`, `Peerage`, `Date`. Join `ork_mundane` on `ma.given_by_id`. Apply the same associate peerage/alias filter. Add the resulting array to `$this->data['MySponsors']`.

**Step 1.2:** Also extend the existing MyAssociates query to return `AwardsId` on each row.

**Step 1.3:** Add a title-options builder immediately after: query `ork_kingdomaward WHERE kingdom_id = <mentor kingdom_id> AND award_id IN (13,14,15,16)` and build an ordered list of title options (core awards + kingdom aliases). Core awards always present; aliases grouped under their parent. Store on `$this->data['BeltlineTitleOptions']`.

**Step 1.4:** Commit: `Enhancement: Add My Beltline data queries (MySponsors, title options) to Playernew`.

---

## Task 2: Backend — `beltline_playersearch` endpoint

**Files:**
- Modify: `orkui/controller/controller.PlayerAjax.php` (inside `player()` action dispatch chain)

**Step 2.1:** Add new `elseif ($action === 'beltline_playersearch')` branch. Read `q` from GET. If `strlen(q) < 2`, return empty array.

**Step 2.2:** Derive scope anchor from the session user: `SELECT park_id, kingdom_id FROM ork_mundane WHERE mundane_id = session.user_id`. Default 0 if not found.

**Step 2.3:** Copy the query pattern from `controller.KingdomAjax.php::playersearch` (~line 740) — abbreviation-prefix parsing (`KK:PP`), term sanitization, scope prioritization, 15-row limit.

**Step 2.4:** Prioritization: `ORDER BY m.suspended ASC, m.active DESC, CASE WHEN m.park_id = <actor_park> THEN 0 WHEN m.kingdom_id = <actor_kingdom> THEN 1 ELSE 2 END, m.persona`.

**Step 2.5:** Exclude self: `AND m.mundane_id != <session.user_id>`.

**Step 2.6:** Return `{ MundaneId, Persona, ParkName, KingdomName, p_abbr, k_abbr }`.

**Step 2.7:** Commit: `Enhancement: Add beltline_playersearch endpoint`.

---

## Task 3: Backend — `beltline_take` endpoint

**Files:**
- Modify: `orkui/controller/controller.PlayerAjax.php` (same `player()` dispatch chain)

**Step 3.1:** Add `elseif ($action === 'beltline_take')` branch. Read POST: `MundaneId`, `AwardId`, `KingdomAwardId` (optional), `Date`, `Note` (optional).

**Step 3.2:** Validate:
- `MundaneId != session.user_id`
- `AwardId` is one of (13, 14, 15, 16), OR if `KingdomAwardId > 0`, `ork_kingdomaward.award_id` for that row is one of (13, 14, 15, 16) AND `kingdom_id` matches the mentor's kingdom_id.
- `Date` parses and is not in the future.
- No duplicate active row: `SELECT 1 FROM ork_awards WHERE given_by_id = <mentor> AND mundane_id = <target> AND award_id = <award> AND kingdomaward_id = <ka_or_0> AND (revoked = 0 OR revoked IS NULL) LIMIT 1`.

**Step 3.3:** `$DB->Clear()` then INSERT `ork_awards` row with:
- `given_by_id = session.user_id`
- `by_whom_id = session.user_id`
- `mundane_id = <target>`
- `award_id`, `kingdomaward_id` (0 if none)
- `date = <posted>`
- `note = <posted or empty>`
- `revoked = 0`, `revoked_at = NULL`, `revocation = ''`, `revoked_by_id = 0`
- `rank = 0`, `unit_id = 0`, `team_id = 0`, `park_id = 0`, `kingdom_id = 0`, `at_park_id = 0`, `at_kingdom_id = 0`, `at_event_id = 0`, `custom_name = ''`, `alias_award_id = NULL`, `stripped_from = NULL`
- `entered_at = NOW()`

**Step 3.4:** Flush memcache for the mentor's and associate's player profile keys.

**Step 3.5:** Return `{ status: 0, row: { AwardsId, RecipientId, Persona, TitleName, Date } }`.

**Step 3.6:** Commit: `Enhancement: Add beltline_take endpoint`.

---

## Task 4: Backend — `beltline_end` endpoint

**Files:**
- Modify: `orkui/controller/controller.PlayerAjax.php` (same `player()` dispatch chain)

**Step 4.1:** Add `elseif ($action === 'beltline_end')` branch. Read POST `AwardsId`.

**Step 4.2:** Load the row: `SELECT given_by_id, mundane_id, award_id, revoked FROM ork_awards WHERE awards_id = <id>`.

**Step 4.3:** Validate:
- Row exists.
- Session user_id equals `given_by_id` OR `mundane_id`.
- Award is one of (13,14,15,16) OR joined kingdomaward resolves to one of those (defense-in-depth: prevents someone POSTing an unrelated awards_id and ending it).
- Not already revoked.

**Step 4.4:** `$DB->Clear()` then UPDATE: `SET revoked=1, revoked_at=CURDATE(), revoked_by_id=<session.user_id>, revocation='ended' WHERE awards_id=<id>`.

**Step 4.5:** Flush memcache for both players' profile keys.

**Step 4.6:** Return `{ status: 0, AwardsId }`.

**Step 4.7:** Commit: `Enhancement: Add beltline_end endpoint`.

---

## Task 5: Template — replace MyAssociates block with My Beltline card

**Files:**
- Modify: `orkui/template/revised-frontend/Playernew_index.tpl` (lines 987-1010)

**Step 5.1:** Replace the `<!-- My Associates -->` block with a two-column "My Beltline" card. Show both columns (My Sponsors on left, My Associates on right) always — empty states for each. `[+ Take New]` button in the My Associates header.

**Step 5.2:** Add CSS (pn-prefixed, dark-mode compatible) for `.pn-beltline-card`, `.pn-beltline-grid`, `.pn-beltline-col`, `.pn-beltline-col-header`, `.pn-beltline-row`, `.pn-beltline-empty`, `[End]` button, responsive stacking at mobile breakpoint.

**Step 5.3:** Render both `$MyAssociates` and `$MySponsors` with `AwardsId` as a `data-awards-id` attribute on each row for the End button.

**Step 5.4:** Heading reset (memory rule): `.pn-beltline-card h3 { background: transparent; border: none; padding: 0; border-radius: 0; text-shadow: none; }`.

**Step 5.5:** Commit: `Enhancement: Replace My Associates with My Beltline two-column card`.

---

## Task 6: Template — Take Associate modal + JS

**Files:**
- Modify: `orkui/template/revised-frontend/Playernew_index.tpl` (bottom of file, near other modals)

**Step 6.1:** Add modal markup with: player search input + `kn-ac-results` dropdown, title radio group built from `$BeltlineTitleOptions`, Flatpickr date input (altInput + altFormat 'F j, Y', maxDate today), optional note textarea with char counter, Cancel + Take buttons, in-modal error banner div.

**Step 6.2:** Add JS (inlined in template, guarded by `PnConfig.isOwnProfile` not `getElementById` — memory rule):
- Wire `[+ Take New]` button to open modal.
- Implement autocomplete using existing `kn-ac-results` helpers; call `tnFixedAcPosition(inputEl, dropdownEl)` before `classList.add('kn-ac-open')` in BOTH the no-results and results branches (memory rule).
- Debounce queries at 250ms; `q` param to `PlayerAjax/player/{sessionUserId}/beltline_playersearch?q=...`.
- On selection, store `mundaneId` and show pill with persona; allow clearing.
- On submit: POST form-encoded to `PlayerAjax/player/{sessionUserId}/beltline_take` with `MundaneId`, `AwardId`, `KingdomAwardId`, `Date` (native ISO value), `Note`.
- On success: close modal, inject the new row into My Associates column DOM, clear form.
- On error: show `status !== 0` message in in-modal banner.

**Step 6.3:** Dark-mode compatibility on modal chrome.

**Step 6.4:** Commit: `Enhancement: Add Take Associate modal`.

---

## Task 7: Template — End Association modal + JS

**Files:**
- Modify: `orkui/template/revised-frontend/Playernew_index.tpl` (near Take modal)

**Step 7.1:** Add confirm modal markup with dynamic sentence area, Cancel + End buttons.

**Step 7.2:** JS:
- Wire every `[End]` button (both columns) to open modal with the correct wording:
  - Sponsors column: "You're ending your association with **{persona}** as their **{title}**."
  - Associates column: "You're ending **{persona}**'s association as your **{title}**."
- On End click: POST to `PlayerAjax/player/{sessionUserId}/beltline_end` with `AwardsId`.
- On success: close modal and remove the row from its column with a fade.
- On error: show message.

**Step 7.3:** Commit: `Enhancement: Add End Association modal`.

---

## Task 8: Filter ended rows from officer revoked-awards views

**Files:** grep during task.

**Step 8.1:** `grep -rni "revoked.*=.*1\|revoked=1\|WHERE.*revoked" --include="*.php" system/lib/ork3 orkui/controller orkui/model orkui/template` to find any UI that lists revoked awards.

**Step 8.2:** For each surface that shows a revoked-awards list to officers (not the general "active awards" queries), add `AND (ma.revocation IS NULL OR ma.revocation != 'ended')` so beltline ends don't leak in.

**Step 8.3:** Commit: `Enhancement: Exclude ended beltline associations from officer revoked lists`.

---

## Task 9: Manual QA + deliver

**Step 9.1:** Confirm docker stack runs: `docker-compose -f docker-compose.php8.yml up -d`.

**Step 9.2:** Navigate to `http://localhost:19080/orkui/Playernew/index/<own-id>` and smoke-test each path from the spec's QA checklist — at minimum: render both columns, open Take modal, search, take a core associate, take a kingdom-alias associate, end from both sides.

**Step 9.3:** Report results and known gaps to the user.

## Self-review notes

- Spec coverage: data model, eligibility, UI (both cards + both modals), endpoints, consumer updates, edge cases — each maps to at least one task.
- Placeholders: Task 8 is intentionally discovery-driven (spec flagged the TBD), but it has a concrete grep and rule to apply.
- No unit tests — this codebase does not have a PHP test harness. QA is manual.
