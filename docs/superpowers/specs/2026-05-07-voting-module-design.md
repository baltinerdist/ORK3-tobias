# Voting Module — Design Spec

**Date:** 2026-05-07
**Branch:** `feature/voting-module`
**Status:** approved sections 1–3, sections 4–5 self-determined per user delegation

---

## 1. Goals

Provide ORK with a unified voting system covering two real-world Amtgard use cases:

1. **Elections** for officer positions, with start/end windows, voter eligibility, multiple voting modes (majority, plurality, IRV), single-candidate confidence votes, abstain and "none of the above" toggles, runner-controlled result publication, and IRV-aware visualizations.
2. **Althings** (kingdom or park business meetings) with Yes/No proposals, multi-choice (single-select) proposals, and a non-binding flag for polls.

Both share eligibility (existing per-kingdom voting rules), a provisional-ballot path for soon-to-be-eligible voters, runner-entered "external" ballots for paper-collected votes, and an admin-only audit trail.

## 2. Non-goals (v1)

- Email/push notifications. Banner alerts on the Playernew dashboard only.
- Open self-nomination by candidates. Runners enter candidates exclusively via player search.
- Multi-select multi-choice althings or runner-configurable althing voting modes.
- Automatic runoff elections on tie. Ties are flagged and runner-resolved.
- Ranked-choice variants other than Instant Runoff (Hare).
- Results visibility behind login (results pages are public link-shareable).
- A separate Voting auth bit. Authority derives from sitting officer roles + ORK admin.

## 3. Architecture

Single feature, modeled as `Voting Event → Race → Choice` with `Ballot → Vote` capturing voter submissions. Election vs Althing is an `event_type` enum, not a schema fork. Mirrors the Tournament module's layering.

| Layer | File | Role |
|---|---|---|
| Data / business | `system/lib/ork3/class.Voting.php` | All DB work: CRUD, tally engine, eligibility, provisional sweep, audit writes. Authoritative. |
| Service model | `orkui/model/model.Voting.php` | Thin pass-through + UI-shaped transforms (per architecture-layers convention). |
| Runner / voter / public UI | `orkui/controller/controller.Voting.php` | List, create/edit, voter ballot, runner dashboard, public results. |
| AJAX | `orkui/controller/controller.VotingAjax.php` | Cast, live tally, manual provisional release, tie resolve, publish/unpublish, external ballot entry. |
| Templates | `orkui/template/revised-frontend/Voting_*.tpl` | All CSS prefixed `vt-`; dark-mode compliant proactively. |
| Migration | `db-migrations/2026-05-07-voting-module.sql` | Schema. |
| Tally tests | `tests/voting/tally_test.php` | Unit tests for the tally engine. |

## 4. Data Model

### 4.1 Schema (8 tables)

```
ork_voting_event
  voting_event_id PK
  event_type ENUM('election','althing')
  scope_type ENUM('kingdom','park')
  scope_id INT                             -- kingdom_id or park_id
  title VARCHAR(255)
  description TEXT
  start_date DATETIME
  end_date DATETIME
  anonymous_to_runner TINYINT(1)
  hide_results_from_candidate_runners TINYINT(1)
  allow_provisional TINYINT(1)
  status ENUM('draft','open','closed','published','unpublished')
  published_at DATETIME NULL
  published_by_mundane_id INT NULL
  tally_snapshot JSON NULL                 -- frozen at publish, used by public page
  created_by_mundane_id INT
  created_at, updated_at

ork_voting_runner
  voting_event_id FK
  mundane_id FK
  PRIMARY KEY (voting_event_id, mundane_id)

ork_voting_race
  voting_race_id PK
  voting_event_id FK
  race_type ENUM('position','yesno','multichoice')
  voting_mode ENUM('majority','plurality','irv')   -- ignored for yesno (always majority); multichoice forced to plurality
  title VARCHAR(255)
  rationale TEXT
  position_id INT NULL                              -- FK ork_position when race_type=position
  allow_abstain TINYINT(1)
  allow_none_of_above TINYINT(1)
  nota_counts_as ENUM('no','abstain') NULL          -- only consulted in confidence math
  is_non_binding TINYINT(1)                         -- althing polls
  display_order INT
  tie_resolved_winner_choice_id INT NULL    -- FK ork_voting_choice
  tie_resolution_note TEXT NULL
  tie_resolution_at DATETIME NULL
  tie_resolved_by_mundane_id INT NULL

ork_voting_choice
  voting_choice_id PK
  voting_race_id FK
  candidate_mundane_id INT NULL            -- non-null for race_type=position
  label VARCHAR(255)                       -- candidate name snapshot, multichoice option text, or "Yes"/"No"
  display_order INT

ork_voting_ballot
  voting_ballot_id PK
  voting_event_id FK
  voter_mundane_id FK                      -- ALWAYS set
  is_provisional TINYINT(1)
  provisional_released_at DATETIME NULL
  provisional_released_by_mundane_id INT NULL  -- NULL = system, set = runner manual override
  entered_by_runner_id INT NULL            -- NULL = self-cast online; non-null = external ballot keyed by runner
  submitted_at DATETIME
  superseded_by_ballot_id INT NULL
  -- Active ballot per voter is enforced via partial uniqueness:
  -- a voter may have only one row with superseded_by_ballot_id IS NULL per voting_event_id.
  -- MariaDB compatible enforcement: separate table `ork_voting_active_ballot (voting_event_id, voter_mundane_id, voting_ballot_id)`
  -- with UNIQUE(voting_event_id, voter_mundane_id) and an UPDATE-on-supersede pattern.

ork_voting_active_ballot                  -- single source of truth for "the current ballot"
  voting_event_id FK
  voter_mundane_id FK
  voting_ballot_id FK
  PRIMARY KEY (voting_event_id, voter_mundane_id)

ork_voting_vote
  voting_vote_id PK
  voting_ballot_id FK
  voting_race_id FK
  voting_choice_id INT NULL                -- NULL when abstain or NOTA
  rank INT NULL                            -- non-null only for IRV (1=top preference)
  is_abstain TINYINT(1)
  is_none_of_above TINYINT(1)
  UNIQUE KEY (voting_ballot_id, voting_race_id, rank)

ork_voting_audit
  voting_audit_id PK
  voting_event_id FK
  actor_mundane_id INT
  action ENUM(
    'event_created','event_updated','runner_added','runner_removed',
    'race_created','race_updated','candidate_added','candidate_removed',
    'ballot_cast','ballot_changed','ballot_runner_entered','ballot_replaced_by_paper',
    'provisional_released_system','provisional_released_runner',
    'tie_resolved','results_published','results_unpublished',
    'admin_voter_choice_view'
  )
  detail JSON
  created_at DATETIME

ork_voting_eligibility_snapshot
  voting_event_id FK
  mundane_id FK
  eligible TINYINT(1)
  was_provisional TINYINT(1)
  source_rules JSON                        -- snapshot of voting_rules at the time
  evaluated_at DATETIME
  PRIMARY KEY (voting_event_id, mundane_id)
```

### 4.2 Schema notes

- **Active-ballot enforcement** uses a side table `ork_voting_active_ballot` so MariaDB can enforce uniqueness without a partial-index dialect.
- **Supersede locking order** (deadlock-safe): every ballot insert path begins with `SELECT voting_ballot_id FROM ork_voting_active_ballot WHERE voting_event_id = ? AND voter_mundane_id = ? FOR UPDATE` inside a transaction. After the row lock is held, insert the new ballot row, insert the votes, update the prior ballot's `superseded_by_ballot_id` (if any), then `INSERT ... ON DUPLICATE KEY UPDATE voting_ballot_id = VALUES(voting_ballot_id)` on `ork_voting_active_ballot`. Commit. Two concurrent supersedes for the same voter will serialize on the FOR UPDATE row lock; never deadlock because the lock acquisition is single-row and ordered identically by every code path. The same pattern is used for online cast, ballot change, and runner-entered external ballots.
- **Vote insert idempotency** within one ballot: votes for a single ballot are inserted in the same transaction that creates the ballot row, so a double-click that produces two HTTP requests creates two ballot rows (the second supersedes the first naturally). The `UNIQUE (voting_ballot_id, voting_race_id, rank)` key cannot constrain `rank IS NULL` rows, but it doesn't need to — votes for a given `voting_ballot_id` are written exactly once at creation.
- **Tally reads only active, non-provisional ballots** via JOIN through `ork_voting_active_ballot`.
- **Eligibility snapshot is written at ballot submit, not at page load.** The voter's first ballot-page visit reads `Reports->get_voting_eligible_for_player` live; the snapshot row is written only inside the cast transaction. Provisional re-evaluation thereafter runs against the snapshot rules. This closes the "load-now-vote-later to capture favorable rules" path.
- **Anonymous-to-runner** is enforced in the model/controller; `voter_mundane_id` is always stored. ORK-admin reads of voter→choice mapping write an `admin_voter_choice_view` audit row before returning data.
- **No DELETEs in the model** for ballots, votes, choices once an event is open. State transitions only.

### 4.3 Indexes

- `ork_voting_ballot (voting_event_id, voter_mundane_id, superseded_by_ballot_id)` — **history/audit reads only**; the active-ballot read path uses `ork_voting_active_ballot` PK directly. NULL-trailing-column reads on this index are filtered scans, not range scans, which is fine for the small N of any single voter's history.
- `ork_voting_vote (voting_race_id, voting_ballot_id)` — composite, drives tally reads from the race side and lets the JOIN to `ork_voting_active_ballot` be index-driven.
- `ork_voting_audit (voting_event_id, created_at)` — audit reads.
- `ork_voting_event (scope_type, scope_id, status, end_date)` — kingdom/park profile listings + cron sweeps.
- `ork_voting_eligibility_snapshot (mundane_id)` — Playernew banner lookups.

## 5. Flows

### 5.1 Creator (officer sets up an event)

1. Officer of kingdom/park clicks **Voting → Create Event** on the Kingdom or Park profile sidebar.
2. Picks `event_type` (Election | Althing), title, description, start/end dates, scope (defaulted from origin), `anonymous_to_runner`, `hide_results_from_candidate_runners`, `allow_provisional`.
3. Adds runners. Default runner-set is "any sitting officer of scope" (resolved at request-time from `ork_officer`); runner can switch to explicit list via player search.
4. Adds races:
   - Election → race_type=`position`, picks position from `ork_position`, adds candidates via player search (`kn-ac-results`), picks voting_mode, toggles abstain/NOTA, sets `nota_counts_as` if NOTA on. Single-candidate races render as confidence at runtime — runner is shown a banner.
   - Althing → race_type=`yesno` (auto-creates Yes/No choices) OR `multichoice` (runner adds N option texts). Either can be `is_non_binding`. Voting mode forced (yesno=majority, multichoice=plurality).
5. Save as `draft`. When `start_date` passes, status flips to `open` (cron + lazy on-access check); runner can flip earlier with "Open now."

### 5.2 Voter (cast or change a ballot)

1. Eligible voter sees a banner on Playernew dashboard: *"Voting open: <title> — closes <date>"*. Click → ballot page.
2. Server runs eligibility check, writes/reads `eligibility_snapshot`. Eligible → normal ballot. Pending-but-could-become-eligible AND `allow_provisional` on → provisional-ballot UI with a clear banner. Otherwise → blocked with explanation.
3. Ballot renders all races on one page in `display_order`.
   - Position/multichoice/yesno (majority/plurality): radio buttons. Abstain and NOTA appear when toggled on.
   - Position with IRV: drag-to-reorder list with explainer: *"Rank as many candidates as you like — 1st is your top choice. Unranked candidates won't receive any of your support. If your top choice is eliminated, your vote moves to your next ranked candidate."* Plus an expandable 3-step worked example.
4. Submit → ballot row inserted, votes inserted per race, `ballot_cast` audit row, active_ballot pointer set.
5. If voter resubmits before `end_date`: new ballot inserted, prior ballot's `superseded_by_ballot_id` set, active_ballot pointer flipped. `ballot_changed` audit row.
6. After submit, voter sees a confirmation page summarizing choices and a "You can change your vote until <end_date>" notice.

### 5.3 Runner (dashboard, external entry, tie, publish)

Runner dashboard for an event has tabs:

- **Overview**: status, dates, participation counts (cast / eligible / provisional pending / provisional released).
- **Live Results**: per-race tally, AJAX-polled every 5s.
  - Plurality / majority → bar chart + pie chart (Chart.js).
  - IRV → round-by-round table (round number, counts per candidate, eliminated, exhausted).
  - Confidence (single-candidate position) → Yes/No bars + abstain/NOTA reported separately.
  - **Officer-on-ballot suppression**: if `hide_results_from_candidate_runners` is on and the viewing runner's `mundane_id` is a `candidate_mundane_id` in any race in this event AND viewer is not ORK admin → entire Live Results tab is hidden with the candidate-runner message.
- **Voter list**:
  - With `anonymous_to_runner` on → shows counts only.
  - Off → name, cast time, provisional flag, "external" indicator if `entered_by_runner_id` is set.
- **Provisional**: list of pending provisional ballots; runner can manually release with required reason (audit `provisional_released_runner`). Cannot un-release. **Manual release is an explicit override** — it bypasses the eligibility-snapshot recheck (the runner is attesting offline knowledge the system can't verify). The audit row records the runner's mundane_id and reason text. ORK admin retains the ability to manually release as well; officer-runners do not need admin escalation.
- **Enter External Votes** (tab + CTA): subtitle *"Enter votes received outside of ORK voting."* Runner runs player search scoped to event scope; system checks for an existing active ballot for that player.
  - No active ballot → ballot form, on submit stores with `entered_by_runner_id`.
  - Active online ballot exists → modal with three options: *Replace with paper* (audit `ballot_replaced_by_paper`), *Keep online, discard paper*, *Cancel*.
- **Tie resolution**: after `end_date`, tied races flagged on the Results tab. Runner picks winner from tied candidates and enters required justification (audit `tie_resolved`).
- **Publish**: button on Overview, only enabled after `end_date` AND when no race has an unresolved tie. **Publish is hard-blocked** if any race has `winner = null` AND `tie != null` AND `tie_resolved_winner_choice_id IS NULL`. The runner sees an explicit "Cannot publish: <race title> has an unresolved tie" error with a link to the tie resolution UI. Sets status=`published`, snapshots tally to `tally_snapshot`, records `published_at` and `published_by_mundane_id`. **Reversible** — Unpublish writes `results_unpublished` audit; status flips to `unpublished` and the public page shows "Results temporarily withdrawn." Re-publish from `unpublished` is allowed: button reappears on Overview, flips status back to `published`, refreshes `tally_snapshot` (in case post-unpublish state changed, e.g., a runner-released provisional), writes another `results_published` audit row.

### 5.4 Public

- `Voting/results/{event_id}` — no auth required.
- 404-style "not yet published" page unless `status = published`.
- Renders tally from frozen `tally_snapshot`. Per-race results with charts; election winners called out; non-binding althing proposals labeled "Poll — non-binding."
- Voter list is NEVER shown publicly, regardless of `anonymous_to_runner`.

### 5.5 Provisional ballot lifecycle

```
Cast as provisional → is_provisional=1, excluded from tally
        ↓
Triggered re-eval (any of):
  - Player pays dues (hook in dues/membership update path) → Voting->reevaluate_provisional_for_player($id)
  - Runner manual release (reason required) → Voting->release_provisional_manual($ballot_id, $reason)
  - Cron sweep nightly during open events → Voting->sweep_provisional_eligibility()
  - Final sweep at end_date when status flips open→closed
        ↓
Now eligible → is_provisional=0, provisional_released_at=NOW(), audit row.
Still ineligible at end_date → ballot stays is_provisional=1, never counts.
```

System and runner releases are surfaced separately on the runner dashboard with their distinguishing audit reason.

## 6. Tally Engine

Lives in `class.Voting.php`. Single entry point `Voting->tally($voting_event_id)` returns a per-race result structure rendered by views. Operates only on active, non-provisional ballots.

### 6.1 Per-race resolvers

| Race shape | Math |
|---|---|
| Confidence (single-candidate position auto-converted) | Tally Yes / No / Abstain / NOTA. Pass if `Yes > No`. NOTA folded into No or Abstain per `nota_counts_as`. **Both Abstain and NOTA-folded-as-Abstain are excluded from the threshold denominator** — they are reported in the result for transparency but do not factor into Yes>No comparison. Result: `pass` / `fail` / `tie` (Yes == No). |
| Yes/No proposal (althing) | Same as confidence; result: `passed` / `failed` / `tied`. Non-binding flag carried to display. |
| Plurality (multi-candidate position OR multichoice althing) | Top vote-getter wins. Abstain/NOTA reported but excluded. Tie = ≥2 candidates with equal top count. |
| Majority (50%+1) | Top candidate must hold strictly more than 50% of non-abstain, non-NOTA votes. Otherwise `no_majority` — flagged for runner to escalate. |
| IRV (Instant Runoff, Hare) | **Input filter, applied before round 1**: each ballot's votes for this race are reduced to a sequence of `voting_choice_id` values ordered by `rank ASC` with NULL/abstain/NOTA rows dropped. Ballots whose resulting sequence is empty (voter ranked zero candidates, or only chose abstain/NOTA) are excluded entirely from IRV — they are reported in the result as "abstained" but never contribute to any round's denominator. Round 1 first-preference is the head of each remaining ballot's sequence. Each round, the lowest first-preference candidate is eliminated and each ballot whose head was that candidate advances to the next surviving candidate in its sequence; if no surviving candidate remains in a ballot's sequence, the ballot is exhausted. Continue until a surviving candidate holds strict majority of non-exhausted ballots. Tie at elimination → flagged for runner to resolve which to eliminate. Tie at final round → race tied; runner resolves. |

### 6.2 IRV result structure

```
{
  "rounds": [
    {"round": 1, "counts": {"Alice": 12, "Bob": 9, "Carol": 8, "Dan": 4}, "eliminated": "Dan", "exhausted_this_round": 0},
    {"round": 2, "counts": {"Alice": 13, "Bob": 11, "Carol": 9}, "eliminated": "Carol", "exhausted_this_round": 0},
    {"round": 3, "counts": {"Alice": 18, "Bob": 13}, "eliminated": null, "winner": "Alice", "exhausted_this_round": 2}
  ],
  "winner": "Alice",
  "tie": null
}
```

UI renders the structure as a stepped table; voter-facing explainer mirrors the same shape with a worked example.

### 6.3 Determinism & caching

- Pure function of ballot set; no randomness.
- Pre-publish: tally runs on every dashboard refresh (5s AJAX poll). Cheap on small N. No caching v1.
- Post-publish: `tally_snapshot` JSON column captures result at the moment of publish. Public page reads from snapshot.

### 6.4 Officer-on-ballot suppression

Server-side gate on the runner-dashboard tally read (Live Results tab and `VotingAjax/tally`):

```
if event.hide_results_from_candidate_runners
   AND requesting_user.mundane_id IN (
     SELECT candidate_mundane_id FROM ork_voting_choice
     JOIN ork_voting_race USING (voting_race_id)
     WHERE voting_event_id = :id AND candidate_mundane_id IS NOT NULL
   )
   AND user is not ORK admin
   AND event.status IN ('open','closed'):
   → return 403 with the candidate-runner message
```

Suppression is event-wide and applies only to **pre-publish** states (`open` and `closed`). Once `status = published`, the runner-dashboard Live Results tab is replaced with the same frozen `tally_snapshot` view that the public page renders — a candidate-runner viewing their own dashboard post-publish sees only what every member of the public can see, never the live re-evaluation. Re-entering `unpublished` brings the gate back.

## 7. UI surfaces & integration points

### 7.1 Routes

| Route | Purpose | Gate |
|---|---|---|
| `Voting/index/Kingdom/{id}` | Kingdom voting landing — list of events | logged-in |
| `Voting/index/Park/{id}` | Park voting landing | logged-in |
| `Voting/event/{id}` | Voter ballot page | eligibility |
| `Voting/runner/{id}` | Runner dashboard | runner perms |
| `Voting/create/{scope_type}/{scope_id}` | Create event | officer of scope or admin |
| `Voting/edit/{id}` | Edit draft event | runner perms + status=`draft` |
| `Voting/results/{id}` | Public results | status=`published` |
| `Voting/audit/{id}` | Admin audit log | ORK admin |
| `VotingAjax/cast/{event_id}` | POST submit ballot | eligibility |
| `VotingAjax/tally/{event_id}` | GET live tally | runner perms + officer-on-ballot gate |
| `VotingAjax/banner/{mundane_id}` | GET active events for player banner | session = mundane_id or admin |
| `VotingAjax/external_ballot/{event_id}` | POST runner-entered ballot | runner perms |
| `VotingAjax/release_provisional/{ballot_id}` | POST manual release | runner perms |
| `VotingAjax/resolve_tie/{race_id}` | POST tie resolution | runner perms |
| `VotingAjax/publish/{event_id}` | POST publish | runner perms + status=`closed` |
| `VotingAjax/unpublish/{event_id}` | POST unpublish | runner perms + status=`published` |

### 7.2 Integration points

- **Kingdomnew sidebar**: new Voting link → `Voting/index/Kingdom/{id}`. Active-event count badge if any open events exist.
- **Parknew sidebar**: same for park.
- **Playernew dashboard banner**: AJAX call to `VotingAjax/banner/{mundane_id}` returns active events the player is eligible for and hasn't voted in. Banner CTA links to ballot. Reuses existing `voting_eligible` AJAX pattern in Playernew.
- **Dues payment hook**: locate the membership/dues update path (likely `class.Mundane.php` or a transaction handler) and add a single call: `Voting->reevaluate_provisional_for_player($mundane_id)`. No-op if no provisional ballots; cheap.
- **Cron sweep**: daily job calling `Voting->sweep_provisional_eligibility()` and `Voting->cycle_event_status()` (which flips draft→open at start_date, open→closed at end_date and runs final provisional sweep).
- **Audit admin view**: `Voting/audit/{event_id}` lists every audit row chronologically. Reading individual voter→choice mapping (admin-only) writes its own `admin_voter_choice_view` audit row.

### 7.3 Styling

- All CSS prefixed `vt-`.
- **Dark-mode compliance is mandatory and proactive** per the dark-mode checklist:
  - Heading reset (h1–h6) inside hero/card/modal — `background: transparent; border: none; padding: 0; border-radius: 0;`.
  - Modal headers, ghost/cancel buttons, inline `style="color:#xxx"`, form labels, placeholders, segmented toggles, info boxes — all walked in dark mode before declaring done.
- **Datetime fields** use Flatpickr with `altInput: true, altFormat: 'F j, Y h:i K'`.
- **Player search** uses `kn-ac-results` pattern, never jQuery UI autocomplete.
- **Modal autocompletes** use `position: fixed` via `tnFixedAcPosition` per the in-modal autocomplete rule.
- **Tooltips** are CSS `data-tip` only — no native `title` attributes.
- **Charts**: Chart.js (audit existing usage during impl; reuse if already vendored).

## 8. Security & permissions

- Officer-of-scope check on creation: server-side `Voting->user_can_create_in_scope($mundane_id, $scope_type, $scope_id)` resolves against `ork_officer` for the scope (and admin).
- Runner perm check happens in controller AND in class layer (defense in depth).
- AJAX endpoints check session and re-verify perms; never trust client-sent role state.
- Voter identity for ballot submission comes from session, never from request body.
- Eligibility check on the server side at every ballot submission, regardless of UI state.
- All `$DB->Clear()` calls before raw `Execute`/`DataSet` per project rule.
- Audit rows are append-only (no UPDATE/DELETE in code paths).
- Anonymity enforcement is server-side: when `anonymous_to_runner` is on, model methods explicitly omit `voter_mundane_id` from runner-facing projections.
- ORK admin viewing voter→choice mapping writes `admin_voter_choice_view` audit row before returning data.
- Eligibility snapshot prevents retroactive re-evaluation when kingdom rules change mid-window.

## 9. Edge cases (handled)

- Voter loses eligibility mid-window after casting → ballot stands; snapshot freezes rules per voter.
- Kingdom rules change mid-window → existing snapshots unaffected; new voters get current rules; runner banner alerts that rules changed.
- Voter is themselves a candidate → CAN vote in their own race (standard practice).
- Runner is a candidate → covered by hide-results-from-candidate-runners; retains create/edit perms unless admin removes them.
- Single-candidate race auto-converts to confidence at runtime. If a candidate is removed during draft and only one remains, conversion happens at that moment. Once event opens, candidate list is locked.
- Voter changes vote → old ballot rows kept; supersede pointer flipped; tally only reads active.
- Race condition: two runners adding the same external ballot for the same voter → enforced at insert via active_ballot uniqueness; second runner sees a clear error.
- Event end_date passes mid-entry → server rejects new ballots with status check.
- Tie at IRV elimination round → flagged at that round; runner resolves which to eliminate; tally re-runs from that point.
- Empty election (no candidates added) → blocked from `draft → open`; validation requires ≥1 candidate per race.
- Publish before end_date → blocked with explanation.
- Provisional ballot for voter never eligible → stays unreleased; never counts.
- Anonymous-to-runner toggle flipped after votes cast → respected immediately on subsequent runner reads (just a controller gate).
- Event unpublished → public page shows "Results temporarily withdrawn"; tally_snapshot retained.

## 10. Testing approach

- **Tally unit tests** (`tests/voting/tally_test.php`, runnable via `php tests/voting/tally_test.php`) covering:
  - Confidence: pass / fail / tie.
  - Confidence with NOTA → No.
  - Confidence with NOTA → Abstain.
  - Plurality with abstain (abstain excluded from comparison).
  - Plurality tie at top.
  - Majority strict-majority pass / no_majority / tie.
  - IRV simple (no elimination needed).
  - IRV with one-round elimination + redistribution.
  - IRV with multi-round elimination.
  - IRV with exhausted ballots (voter only ranked their top choice; that choice eliminated → ballot exhausts).
  - IRV tie at elimination step.
  - IRV tie at final round.
  - Yes/No althing pass / fail / tied.
  - Multichoice plurality with multiple options.

- **Manual happy-path verification** through the browser, dark mode walked on every new surface, per `feedback_dark_mode_checklist`.

- **No DB-mocked tests** (per `feedback_db_clear_before_execute` and project conventions). Tally tests are the unit-testable piece; the rest verifies through the running app.

## 11. Prototype scope (cut line for first user-visible deliverable)

**In prototype:**
- Schema migration applied.
- Create event (election + althing), add races, add candidates.
- Cast ballot online (all voting modes including IRV with ranked UI).
- Vote-change supersede flow.
- Live tally on runner dashboard.
- Officer-on-ballot suppression.
- Publish + public results page.
- Kingdomnew + Parknew sidebar links.
- Playernew banner for active eligible events.
- Tally engine + tally unit tests.

**Deferred past prototype (still in spec, for follow-up implementation):**
- External ballot entry (paper) UI — schema and core method present; runner UI minimal stub.
- Manual provisional release UI polish.
- Tie resolution UI polish.
- Audit admin view (`Voting/audit`) — schema captures all events, view is minimal.
- Cron sweep job wiring to host cron; method exists and is callable.
- Dues payment hook integration — method exists and is callable; the hook into the dues path is a small follow-up once the dues entry-point is located.
- Notifications beyond the dashboard banner.
- IRV drag-reorder polish (functional first, polish second).

## 12. Open implementation questions (resolved by discovery during build)

- Exact dues/membership entry point to call `reevaluate_provisional_for_player` from. Will locate during impl; if not trivially findable, hook is left as a function and a `TODO` for a follow-up PR.
- Whether Chart.js is already vendored in the project; if not, reuse whatever charting library exists (or inline SVG bar/pie) rather than introduce a new dep.
- Existing cron infrastructure path; if absent, methods are written, callable, and deferred to ops wiring.

These are intentionally left open — they're discovery, not design.
