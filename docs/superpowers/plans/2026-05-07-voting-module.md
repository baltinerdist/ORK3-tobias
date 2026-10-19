# Voting Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a unified Voting module supporting officer Elections (majority/plurality/IRV) and Althings (yes/no, multichoice, optionally non-binding) on top of ORK's existing per-kingdom voting eligibility logic, including provisional ballots, runner-entered "external" ballots, anonymous-to-runner option, runner-on-ballot suppression, ballot supersede, and an admin-only audit trail.

**Architecture:** Single `class.Voting.php` (DB + business logic) with thin `model.Voting.php` pass-through, two controllers (`controller.Voting.php` for pages, `controller.VotingAjax.php` for cast/tally/admin actions), templates under `orkui/template/revised-frontend/Voting_*.tpl`. One migration adds 8 tables. Mirrors Tournament module's layering. Reuses `Reports->get_voting_eligible_for_player`. See spec: `docs/superpowers/specs/2026-05-07-voting-module-design.md`.

**Tech Stack:** PHP 8 / MariaDB / yapo ORM / Smarty templates / vanilla JS + Chart.js / kn-ac-results autocomplete pattern / Flatpickr / orkui CSS conventions (`vt-` prefix, dark-mode compliant proactively).

---

## Conventions for every task

- **PHP edits**: use Python for any multi-line PHP edit (per project memory: tab indentation makes Edit tool unreliable). Single-line PHP edits via Edit are OK.
- **DB queries**: every raw `Execute`/`DataSet` call is preceded by `$DB->Clear()`.
- **Authorization**: every business method calls `Ork3::$Lib->authorization->IsAuthorized($request['Token'])` and returns `NoAuthorization()` if invalid.
- **No DELETEs** in the model for ballots/votes/choices once an event is open. State transitions only.
- **Commits**: always stage explicit file paths. Never `git add -A` or `git add .`. Never stage `system/lib/ork3/class.Authorization.php` (`true ||` bypass present).
- **Tests**: tally engine has unit tests (`tests/voting/tally_test.php`); the rest is verified manually through the running app per project convention. **Tally TDD is required**: write the test, run-fail, implement, run-pass, commit.

---

## Phase 1 — Schema and tally engine (foundations)

### Task 1: Discovery — confirm Chart.js availability and dues hook entry point

**Files:**
- Read-only

- [ ] Run: `find . -name "*.js" -path "*/lib/*" 2>/dev/null | xargs grep -l -i "chart\.js\|Chart(" 2>/dev/null | head` to find Chart.js. If not present, fall back to inline SVG bars + a small custom pie renderer (`vt-pie` CSS class).
- [ ] Run: `grep -rn "paid_dues\|membership_paid\|update_membership\|payment_complete\|TransactionAjax\|charge_complete" system/lib/ork3/ orkui/controller/ 2>/dev/null | head -20` to locate the dues-payment confirmation path. Note the file/method.
- [ ] Run: `grep -rn "cron\|scheduled" config/ system/lib/ 2>/dev/null | head -10` and look for an existing cron config. If not found, document that the cron sweep methods will exist callable but are not wired in this task.

This is exploration; it produces no commit. Findings are referenced by later tasks.

### Task 2: Schema migration

**Files:**
- Create: `db-migrations/2026-05-07-voting-module.sql`

- [ ] Write the migration file. Schema (verbatim from spec §4.1, with FK columns that exist becoming actual `FOREIGN KEY` clauses where MariaDB compatibility allows; SET NULL on parent delete for soft references). Engine `InnoDB`, charset `utf8mb4`. Use `DB_PREFIX` style: tables prefixed `ork_`. Concrete CREATE TABLE statements for all 8 tables: `ork_voting_event`, `ork_voting_runner`, `ork_voting_race`, `ork_voting_choice`, `ork_voting_ballot`, `ork_voting_active_ballot`, `ork_voting_vote`, `ork_voting_audit`, `ork_voting_eligibility_snapshot`. Indexes per spec §4.3. Composite `(voting_race_id, voting_ballot_id)` on `ork_voting_vote`.

- [ ] Apply: `docker exec -i ork3-php8-db mariadb -u root -proot ork < db-migrations/2026-05-07-voting-module.sql`. Verify all 9 tables exist: `docker exec -i ork3-php8-db mariadb -u root -proot ork -e "SHOW TABLES LIKE 'ork_voting_%';"` — expect 9 rows including `ork_voting_active_ballot` and `ork_voting_eligibility_snapshot`.

- [ ] Commit:
```bash
git add db-migrations/2026-05-07-voting-module.sql
git commit -m "Voting: Schema migration (events, races, choices, ballots, votes, audit)"
```

### Task 3: Tally engine — write failing tests first

**Files:**
- Create: `tests/voting/tally_test.php` and `tests/voting/tally_test_runner.php`

The test harness calls a pure static function `Voting::tally_pure($race_config, $ballots_config)` that takes the race shape + a flat in-memory ballot set so the tests don't need DB. The same logic is exercised internally by the DB-backed `Voting->tally()`.

- [ ] Write `tests/voting/tally_test_runner.php`:
```php
<?php
require_once __DIR__ . '/../../system/lib/ork3/class.Voting.php';
require_once __DIR__ . '/tally_test.php';
$tests = get_class_methods('VotingTallyTests');
$pass = 0; $fail = 0;
foreach ($tests as $t) {
    if (strpos($t, 'test_') !== 0) continue;
    try {
        (new VotingTallyTests())->$t();
        echo "PASS  $t\n"; $pass++;
    } catch (Throwable $e) {
        echo "FAIL  $t — " . $e->getMessage() . "\n"; $fail++;
    }
}
echo "\n$pass passed, $fail failed\n";
exit($fail === 0 ? 0 : 1);
```

- [ ] Write `tests/voting/tally_test.php` with these tests covering every row of spec §6.1 + the IRV input filter (§6.1 IRV row + §10):

```php
<?php
class VotingTallyTests {
    private function assertEq($expected, $actual, $msg = '') {
        if ($expected !== $actual) throw new Exception("$msg: expected " . json_encode($expected) . " got " . json_encode($actual));
    }

    // CONFIDENCE
    function test_confidence_pass() {
        $r = Voting::tally_pure(
            ['race_type' => 'position', 'voting_mode' => 'confidence', 'allow_abstain' => 1, 'allow_none_of_above' => 0, 'choices' => [['id' => 1, 'label' => 'Alice']]],
            [['votes' => [['choice_id' => 1, 'rank' => null, 'is_abstain' => 0, 'is_nota' => 0]]],
             ['votes' => [['choice_id' => 1, 'rank' => null, 'is_abstain' => 0, 'is_nota' => 0]]],
             ['votes' => [['choice_id' => 0, 'rank' => null, 'is_abstain' => 0, 'is_nota' => 0]]]] // No vote (no choice) - actually we represent confidence as Yes(1)/No(0)
        );
        // ... assertEq('pass', $r['outcome']);
    }
    // (test bodies elided here for plan length; the implementer writes one assertion per case below)

    function test_confidence_fail();           // No > Yes
    function test_confidence_tie();            // Yes == No
    function test_confidence_abstain_ignored(); // 1 Yes, 0 No, 5 Abstain → pass
    function test_confidence_nota_as_no();      // 3 Yes, 0 No, 2 NOTA → fail (NOTA→No: 3 vs 2 is still pass — pick numbers carefully)
    function test_confidence_nota_as_abstain(); // NOTA folded out of denominator
    function test_plurality_simple();
    function test_plurality_with_abstain();
    function test_plurality_tie_at_top();
    function test_majority_pass();
    function test_majority_no_majority();
    function test_majority_strict_threshold();  // exactly 50% is NOT a pass
    function test_irv_simple_majority_round_one();
    function test_irv_one_round_elimination();
    function test_irv_multi_round();
    function test_irv_exhausted_ballots();      // ballot ranks only one candidate; that candidate eliminated → exhausts
    function test_irv_zero_ranked_ballot();     // ballot with only abstain row → excluded from IRV entirely
    function test_irv_tie_at_elimination();
    function test_irv_tie_at_final();
    function test_yesno_passed();
    function test_yesno_failed();
    function test_yesno_tied();
    function test_multichoice_plurality();
}
```

- [ ] Implement each test body explicitly (no elision in the actual file). Use the data shape exactly as listed: `['choice_id' => N, 'rank' => N|null, 'is_abstain' => 0|1, 'is_nota' => 0|1]`. For confidence, `choice_id` is 1 for Yes, 2 for No (mapped to labels `Yes`/`No`), and the race config carries `'choices' => [['id'=>1,'label'=>'Yes'],['id'=>2,'label'=>'No']]`.

- [ ] Run: `docker exec -i ork3-php8-php php /var/www/html/tests/voting/tally_test_runner.php`
Expected: every test FAILs with "Class 'Voting' not found" or `tally_pure` undefined. (If running outside Docker: `php tests/voting/tally_test_runner.php` from project root.)

- [ ] Commit:
```bash
git add tests/voting/tally_test.php tests/voting/tally_test_runner.php
git commit -m "Voting: Tally engine unit tests (failing — implementation next)"
```

### Task 4: Tally engine — minimal class.Voting.php skeleton + tally_pure

**Files:**
- Create: `system/lib/ork3/class.Voting.php`

- [ ] Create the file with class skeleton, constants, and a static `tally_pure(array $race, array $ballots): array` that implements §6.1 in full. Pseudocode for the IRV branch:

```php
public static function tally_pure(array $race, array $ballots): array {
    switch ($race['race_type']) {
        case 'yesno':
        case 'position':
            // single-candidate position → confidence shape
            if ($race['race_type'] === 'position' && count($race['choices']) === 1) {
                return self::tally_confidence($race, $ballots);
            }
            if ($race['race_type'] === 'yesno') {
                return self::tally_confidence($race, $ballots); // yesno uses confidence math
            }
            // multi-candidate position → plurality / majority / irv per voting_mode
            switch ($race['voting_mode']) {
                case 'plurality': return self::tally_plurality($race, $ballots);
                case 'majority':  return self::tally_majority($race, $ballots);
                case 'irv':       return self::tally_irv($race, $ballots);
            }
        case 'multichoice': return self::tally_plurality($race, $ballots);
    }
}

private static function tally_confidence(array $race, array $ballots): array {
    // Yes choice id is the smallest choice_id among the race's choices (label='Yes' for yesno;
    // for single-candidate position, the lone candidate's choice_id IS the Yes vote).
    // For yesno: $yes = choice with label 'Yes', $no = choice with label 'No'.
    // For single-cand position: $yes = the lone candidate; $no is implicit (a 'No' option label) — but our ballot UI for confidence presents Yes/No as two choices; we will store them as label='Yes'/'No' choice rows alongside the candidate's choice — actually simpler: for single-cand position confidence, we INSERT two synthetic choices labeled 'Confidence in <name>' (Yes) and 'No confidence' (No) at runtime. Implementor: confirm in Task 5 when writing run-time choice resolution.
    // Counts: yes, no, abstain, nota. NOTA→ per nota_counts_as: 'no' adds to no, 'abstain' adds to abstain.
    // Outcome: Yes > No → 'pass'; Yes < No → 'fail'; Yes == No → 'tie'.
    // Return array: ['outcome' => 'pass'|'fail'|'tie', 'yes' => N, 'no' => N, 'abstain' => N, 'nota' => N, 'denominator' => yes+no, 'tie' => null|true]
}

private static function tally_plurality(array $race, array $ballots): array {
    // For each ballot, find the vote row for this race with rank IS NULL and is_abstain=0 and is_nota=0; that row's choice_id gets +1.
    // Track abstain count, nota count separately.
    // Determine top: max count. If multiple choices share the max → tie.
    // Return ['outcome' => 'win'|'tie', 'winner_choice_id' => N|null, 'counts' => {choice_id: count}, 'abstain' => N, 'nota' => N, 'tie' => null|[ids]]
}

private static function tally_majority(array $race, array $ballots): array {
    // Same counting as plurality.
    // Outcome: top must be > 50% of (yes+no equivalent: total_choice_votes excluding abstain/nota).
    // 'no_majority' if top <= 50%, 'tie' if multiple at top.
}

private static function tally_irv(array $race, array $ballots): array {
    // Step 1 - input filter: for each ballot, build sequence of choice_ids ordered by rank ASC for this race;
    //          drop rank=null/abstain/nota rows (but track those for 'abstained' count); drop ballots with empty sequence.
    // Step 2 - rounds: each round, count first-pref of remaining sequences. If top has > floor(remaining_total / 2),
    //          declare winner. Otherwise eliminate lowest. If ties at lowest → return 'tie_at_elimination', round, tied_ids.
    // Step 3 - redistribute: any ballot whose head was eliminated advances to next surviving id; if none surviving in
    //          its sequence, mark exhausted_this_round++.
    // Step 4 - if only one candidate remaining and no majority yet, pick them as winner (only happens with even split + exhaustion).
    // Step 5 - tie at final round: two candidates with equal counts and no remaining ballots → 'tie_at_final', round, tied_ids.
    // Return ['outcome' => 'win'|'tie_at_elimination'|'tie_at_final', 'winner_choice_id' => N|null, 'rounds' => [...], 'tie' => null|[ids], 'abstained' => N]
}
```

- [ ] Run tally tests again:
```bash
docker exec -i ork3-php8-php php /var/www/html/tests/voting/tally_test_runner.php
```
Expected: every test PASSes.

- [ ] Commit:
```bash
git add system/lib/ork3/class.Voting.php
git commit -m "Voting: Tally engine (confidence, plurality, majority, IRV)"
```

---

## Phase 2 — Business logic and persistence

### Task 5: class.Voting.php — CRUD methods (events, races, choices, runners)

**Files:**
- Modify: `system/lib/ork3/class.Voting.php`

- [ ] Add yapo bindings in constructor for: `voting_event`, `voting_runner`, `voting_race`, `voting_choice`, `voting_ballot`, `voting_active_ballot`, `voting_vote`, `voting_audit`, `voting_eligibility_snapshot`.

- [ ] Add methods (each returns `Success($id)` or `NoAuthorization()` / `InvalidParameter()` / `Failure(...)`):
  - `CreateEvent($request)` — auth check, scope check (`user_can_run_in_scope`), insert `ork_voting_event` with status='draft', insert default runners (=officers of scope) into `ork_voting_runner` UNLESS `request['Runners']` is set, write `event_created` audit.
  - `UpdateEvent($request)` — must be status=draft, perm-checked, writes `event_updated` audit with diff.
  - `AddRace($request)` — race_type, voting_mode, allow_abstain, allow_none_of_above, nota_counts_as (validated), is_non_binding, position_id, title, rationale. For yesno race: also auto-insert the two choices ('Yes', 'No'). Write `race_created` audit.
  - `AddCandidate($request)` — race_type=position only, candidate_mundane_id, label snapshot of player name. Write `candidate_added`.
  - `RemoveCandidate($request)` — only allowed when event status=draft.
  - `AddOption($request)` — multichoice options. status=draft only.
  - `SetRunners($request)` — replaces runner list entirely (transactional). Writes runner_added/runner_removed for each diff.
  - `OpenEvent($request)` — flips draft→open. Validates: every race has ≥1 candidate (position) or ≥2 options (multichoice); start_date ≤ now. Writes `event_updated` with status change.
  - `CloseEvent($request)` — flips open→closed. Triggers final provisional sweep.

- [ ] Implement `user_can_run_in_scope($mundane_id, $scope_type, $scope_id)`: ORK admin via `HasAuthority(... AUTH_ADMIN)` OR row in `ork_voting_runner` for an existing event in scope OR sitting officer per `ork_officer` for the scope (resolve via existing model). For event creation specifically (no event yet), only "officer of scope" or admin counts.

- [ ] Implement `get_event($voting_event_id)` returning the joined event/races/choices structure used by views.

- [ ] No tests required for this task (CRUD is verified end-to-end). But run the tally tests to confirm no regression: `docker exec -i ork3-php8-php php /var/www/html/tests/voting/tally_test_runner.php`.

- [ ] Commit:
```bash
git add system/lib/ork3/class.Voting.php
git commit -m "Voting: Event/race/candidate CRUD + perms + open/close transitions"
```

### Task 6: class.Voting.php — eligibility snapshot + cast ballot + supersede

**Files:**
- Modify: `system/lib/ork3/class.Voting.php`

- [ ] Implement `is_eligible_live($mundane_id, $scope_type, $scope_id)`: wraps `Reports->get_voting_eligible_for_player($mundane_id, $kingdom_id_resolved_from_scope)`. Returns `['eligible' => bool, 'provisional_possible' => bool, 'rules' => [...]]`. For park scope, resolves kingdom_id from park.

- [ ] Implement `CastBallot($request)`:
  1. Auth check; voter is `$request['VoterMundaneId']` (default to session voter).
  2. If `$request['EnteredByRunnerId']` is set, perm-check that the runner is on the event's runner list.
  3. Verify event status='open' and `now() < end_date`.
  4. Live eligibility check. If ineligible AND `event.allow_provisional` AND `provisional_possible` → mark `is_provisional=1`. If ineligible and not provisional-possible → return `Failure('Not eligible')`.
  5. **Open transaction.**
  6. `SELECT ... FROM ork_voting_active_ballot WHERE voting_event_id=? AND voter_mundane_id=? FOR UPDATE` — get prior ballot id (if any).
  7. If prior ballot exists and is_provisional=0 (already counts), this is a vote-change. If exists and is_provisional=1, replace.
  8. Insert new `ork_voting_ballot` row.
  9. For each race in `$request['Votes']`: insert `ork_voting_vote` rows. IRV votes are inserted one row per rank. Validate each vote row against the race config (e.g., NOTA only allowed if `allow_none_of_above`; abstain only if `allow_abstain`).
  10. If prior ballot exists, update its `superseded_by_ballot_id`.
  11. Insert into `ork_voting_eligibility_snapshot` ON DUPLICATE KEY UPDATE (write at submit, not page-load — per spec §4.2).
  12. `INSERT INTO ork_voting_active_ballot (...) VALUES (...) ON DUPLICATE KEY UPDATE voting_ballot_id = VALUES(voting_ballot_id)`.
  13. Audit row: `ballot_cast` (or `ballot_changed`, `ballot_runner_entered`, `ballot_replaced_by_paper`).
  14. Commit transaction.
  15. Return `Success($new_ballot_id)`.

- [ ] Implement `ReleaseProvisionalManual($request)`: requires Token, voting_ballot_id, reason. Perm-check runner; sets `is_provisional=0`, `provisional_released_at=NOW()`, `provisional_released_by_mundane_id=$mundane_id`. Audit `provisional_released_runner` with reason.

- [ ] Implement `reevaluate_provisional_for_player($mundane_id)`: finds all `is_provisional=1` ballots in events where status='open', for this voter; runs `is_eligible_live` against the snapshot rules per ballot (snapshot has source_rules JSON; if voter's eligibility against THAT ruleset has flipped to true, release). Audit `provisional_released_system`.

- [ ] Implement `sweep_provisional_eligibility()`: same as above but for ALL provisional voters across all open events. Idempotent.

- [ ] Implement `cycle_event_status()`: cron entry point. Flips `draft→open` where `start_date <= NOW()` and event has races with candidates/options; flips `open→closed` where `end_date <= NOW()` and runs the final provisional sweep on those events.

- [ ] Implement `tally($voting_event_id)` (DB-backed): loads races + active non-provisional ballots + their votes, calls `tally_pure` per race, returns assoc array keyed by voting_race_id. Honors `tie_resolved_winner_choice_id` (if set on a tied race, replaces the tie outcome with that winner).

- [ ] Implement `ResolveTie($request)` (race_id, winner_choice_id, note). Auth + runner check. Update race row.

- [ ] Implement `Publish($request)` and `Unpublish($request)`. Publish blocks if any race has unresolved tie (per spec §5.3). Publish writes `tally_snapshot` JSON column from current `tally()` result.

- [ ] No tests for these methods (manual verification). Run tally tests once more to ensure no regression.

- [ ] Commit:
```bash
git add system/lib/ork3/class.Voting.php
git commit -m "Voting: Cast/supersede ballots, provisional lifecycle, publish, tie resolve"
```

---

## Phase 3 — Service model and controllers

### Task 7: model.Voting.php (thin pass-through)

**Files:**
- Create: `orkui/model/model.Voting.php`

- [ ] Mirror Tournament's pattern. `class Model_Voting extends Model` with `$this->Voting = new APIModel('Voting');` and `$this->Reports = new APIModel('Report');`. Methods are 1-line pass-throughs that wrap `Token` injection where needed. Also include UI-shape transforms where useful:
  - `get_event($id)` — calls `$this->Voting->GetEvent(...)`, returns the joined structure.
  - `list_events_for_scope($scope_type, $scope_id, $statuses)` — paginated listing for the kingdom/park profile.
  - `active_events_for_voter($mundane_id)` — for the dashboard banner.

- [ ] Commit:
```bash
git add orkui/model/model.Voting.php
git commit -m "Voting: Model layer (thin pass-through + UI-shape transforms)"
```

### Task 8: controller.Voting.php — pages

**Files:**
- Create: `orkui/controller/controller.Voting.php`

- [ ] `class Controller_Voting extends Controller` with constructor loading `Voting`, `Park`, `Kingdom`, `Reports` models. Methods:
  - `index($scope_type=null, $scope_id=null)` — list events for kingdom/park; perm-aware (officers see drafts).
  - `event($voting_event_id=null)` — voter ballot page. If not eligible, render an explanation. If eligible, render the ballot. If event status != 'open', render appropriate message.
  - `runner($voting_event_id=null)` — runner dashboard. Perm-check; render dashboard with all five tabs (Overview, Live Results, Voter list, Provisional, Enter External Votes).
  - `create($scope_type=null, $scope_id=null)` — wizard form. Officer-of-scope check.
  - `edit($voting_event_id=null)` — only when status=draft. Officer/runner check.
  - `results($voting_event_id=null)` — public page. 404 unless status=published. No auth required.
  - `audit($voting_event_id=null)` — admin-only audit log view.
- [ ] All form submits use the request->save / read pattern from Tournament's `create()`. POST handlers use `switch ($post)` on action.
- [ ] All views set `$this->template = 'Voting_*.tpl'`.

- [ ] Commit:
```bash
git add orkui/controller/controller.Voting.php
git commit -m "Voting: Controller for index/event/runner/create/edit/results/audit pages"
```

### Task 9: controller.VotingAjax.php — AJAX endpoints

**Files:**
- Create: `orkui/controller/controller.VotingAjax.php`

- [ ] `class Controller_VotingAjax extends Controller`. All endpoints emit JSON, use `header('Content-Type: application/json')`, `exit` after echo. Methods:
  - `cast($voting_event_id=null)` — POST body has votes per race; calls `Voting->CastBallot`. Voter is session user.
  - `tally($voting_event_id=null)` — runner-perm gate + officer-on-ballot suppression (see §6.4). Returns the tally structure.
  - `banner($mundane_id=null)` — returns active eligible events for the player.
  - `external_ballot($voting_event_id=null)` — runner-only; voter id from request body (after player search).
  - `release_provisional($voting_ballot_id=null)` — runner manual override; reason required.
  - `resolve_tie($voting_race_id=null)` — runner picks winner.
  - `publish($voting_event_id=null)` and `unpublish` — runner gates.
  - `add_candidate_search($scope_type=null, $scope_id=null)` — player search backing the candidate-add autocomplete (kn-ac-results format).
  - `voter_search($voting_event_id=null)` — player search scoped to event scope, used by Enter External Votes.

- [ ] All endpoints `header('Content-Type: application/json'); echo json_encode([...]); exit;`. Failures return `{"status": 1, "error": "..."}`.

- [ ] Commit:
```bash
git add orkui/controller/controller.VotingAjax.php
git commit -m "Voting: AJAX endpoints (cast, tally, banner, external ballot, publish)"
```

---

## Phase 4 — Templates

### Task 10: Templates — listing, create wizard, voter ballot

**Files:**
- Create: `orkui/template/revised-frontend/Voting_index.tpl`
- Create: `orkui/template/revised-frontend/Voting_create.tpl`
- Create: `orkui/template/revised-frontend/Voting_event.tpl`

- [ ] `Voting_index.tpl` — kingdom/park voting landing. Cards for each event with status badge, dates, type, and quick actions ("Vote", "View results", "Manage" if runner). Inline CSS prefixed `vt-`. Dark-mode-ready (test heading reset, segmented filter pill, ghost cancel buttons).

- [ ] `Voting_create.tpl` — multi-section form: Event meta (title, description, dates with Flatpickr `altInput: true, altFormat: 'F j, Y h:i K'`); flags (anonymous_to_runner, hide_results_from_candidate_runners, allow_provisional); event type selector. Race builder: dynamic add-race UI, per-race fields based on race_type. Candidate add via player search using `kn-ac-results` pattern (NOT jQuery UI). All toasts/modals use `data-tip` for tooltips, never `title`.

- [ ] `Voting_event.tpl` — voter ballot. One section per race. Position/multichoice/yesno → radio buttons. IRV → drag-to-reorder list (HTML5 sortable.js if vendored, otherwise vanilla drag handlers). Explainer collapsible: 3-step worked example. Submit calls `VotingAjax/cast/{id}`. Confirmation page: review choices, "you can change your vote until <end_date>" notice.

- [ ] Commit:
```bash
git add orkui/template/revised-frontend/Voting_index.tpl orkui/template/revised-frontend/Voting_create.tpl orkui/template/revised-frontend/Voting_event.tpl
git commit -m "Voting: Templates for index, create wizard, voter ballot"
```

### Task 11: Templates — runner dashboard, public results

**Files:**
- Create: `orkui/template/revised-frontend/Voting_runner.tpl`
- Create: `orkui/template/revised-frontend/Voting_results.tpl`
- Create: `orkui/template/revised-frontend/Voting_audit.tpl` (minimal)

- [ ] `Voting_runner.tpl` — five tabs (Overview, Live Results, Voter list, Provisional, Enter External Votes). Live Results polls `VotingAjax/tally/{id}` every 5s. Charts: bar+pie (Chart.js if vendored — confirmed in Task 1; otherwise inline SVG bars and a simple pie via CSS conic-gradient). IRV renders a round-by-round table. Officer-on-ballot suppression UI message when AJAX returns 403. Enter External Votes uses player search (`kn-ac-results`, `position: fixed` via `tnFixedAcPosition` since it's in a modal — per project memory).

- [ ] `Voting_results.tpl` — public-page rendering of `tally_snapshot`. Same chart components but read from frozen JSON. Non-binding althing proposals labeled "Poll — non-binding."

- [ ] `Voting_audit.tpl` — minimal table of audit rows for admin. Filterable by action.

- [ ] Walk all surfaces in dark mode per `feedback_dark_mode_checklist`: heading reset (h1-h6 background-color leak), modal headers, ghost buttons, form labels, placeholders, segmented toggles, info boxes.

- [ ] Commit:
```bash
git add orkui/template/revised-frontend/Voting_runner.tpl orkui/template/revised-frontend/Voting_results.tpl orkui/template/revised-frontend/Voting_audit.tpl
git commit -m "Voting: Templates for runner dashboard, public results, audit"
```

---

## Phase 5 — Integration

### Task 12: Profile sidebar links + Playernew banner + dues hook

**Files:**
- Modify: `orkui/template/revised-frontend/Kingdomnew_index.tpl`
- Modify: `orkui/template/revised-frontend/Parknew_index.tpl`
- Modify: `orkui/template/revised-frontend/Playernew_index.tpl`
- Modify: dues entry-point (located in Task 1 discovery; if unfindable, skip and note)

- [ ] Kingdomnew sidebar — add Voting link near Voting Eligible link (around line 627). Active-event count badge: `<?= $kn_voting_active_count ?>` populated by controller.Kingdomnew. Add a corresponding `$kn_voting_active_count = $this->Voting->count_active_events('Kingdom', $kingdom_id);` in `controller.Kingdom.php`.

- [ ] Parknew sidebar — same pattern around line 946.

- [ ] Playernew banner — add a banner block above the hero stats row that AJAX-loads `VotingAjax/banner/{mundane_id}`. Renders nothing if no active eligible events. CTAs link to `Voting/event/{id}`. JS guard: NOT `document.getElementById(...)` (per memory rule), use `PnConfig.playerId` as the IIFE guard.

- [ ] Dues hook (if entry point found in Task 1): add `Ork3::$Lib->voting->reevaluate_provisional_for_player($mundane_id);` after the dues row write. Best-effort — wrap in try/catch so a voting failure doesn't block dues.

- [ ] Commit:
```bash
git add orkui/template/revised-frontend/Kingdomnew_index.tpl orkui/template/revised-frontend/Parknew_index.tpl orkui/template/revised-frontend/Playernew_index.tpl orkui/controller/controller.Kingdom.php orkui/controller/controller.Park.php orkui/controller/controller.Playernew.php
git commit -m "Voting: Integration — kingdom/park sidebar, Playernew banner, dues hook"
```

---

## Phase 6 — Verification

### Task 13: End-to-end happy path in browser

- [ ] Start app: `docker-compose -f docker-compose.php8.yml up -d`. Confirm: `curl -s http://localhost:19080/orkui/ | head -5`.

- [ ] Browser walk:
  1. Log in as a kingdom officer of one of the supported voting kingdoms (e.g., kingdom_id=10).
  2. Navigate to `Kingdom/index/10`. Click sidebar **Voting**. Should land on `Voting/index/Kingdom/10` with empty list.
  3. Click **Create Event**. Fill: type=Election, title="Test Crown 2026", desc, start=now, end=now+1day, scope=Kingdom 10, anonymous_to_runner=off, hide_results_from_candidate_runners=on, allow_provisional=on. Add 1 race: race_type=position, position=Monarch, voting_mode=irv, abstain=on. Add 3 candidates via player search.
  4. Open the event. Status flips to `open`.
  5. Log out, log in as an eligible voter (member in the same kingdom). Visit Playernew dashboard — banner should show "Test Crown 2026" with a Vote CTA. Click Vote. Drag-rank candidates. Submit. Confirmation page renders.
  6. Resubmit (change vote) — verify supersede banner.
  7. Log back in as runner. Open Runner dashboard. Live Results tab should show round-by-round IRV with at least one round.
  8. Set end_date in the past via DB or UI; flip to closed. Publish. Public results page (open in incognito) should render IRV result.
  9. Unpublish. Public page now reads "Results temporarily withdrawn." Re-publish. Results return.

- [ ] Walk every surface in **dark mode** (toggle the theme): index, create wizard, voter ballot, runner dashboard tabs, public results. Verify per `feedback_dark_mode_checklist`: heading reset (h1-h6 background-color leak inside hero/card/modal), modal headers, ghost/cancel buttons, inline `style="color:#xxx"`, form labels, placeholders, segmented toggles, info boxes. Fix any issues inline.

- [ ] Run tally tests one final time:
```bash
docker exec -i ork3-php8-php php /var/www/html/tests/voting/tally_test_runner.php
```
Expected: all tests PASS.

- [ ] Commit any dark-mode polish fixes.

- [ ] Surface to user: report happy-path completion + remaining deferred items per spec §11.

---

## Self-review checklist

**Spec coverage** (every section/requirement of the spec → covered by which task):
- §3 layering → Task 5 (class), Task 7 (model), Tasks 8/9 (controllers), Tasks 10/11 (templates), Task 2 (migration), Task 3 (tests).
- §4 schema → Task 2.
- §5.1 creator → Tasks 5, 8, 10.
- §5.2 voter → Tasks 6, 8, 10.
- §5.3 runner dashboard → Tasks 6, 8, 9, 11.
- §5.4 public → Tasks 6 (publish), 8 (results route), 11 (results template).
- §5.5 provisional lifecycle → Task 6.
- §6 tally → Tasks 3, 4.
- §6.4 officer-on-ballot suppression → Task 9 (`tally` AJAX gate) + Task 11 (UI message).
- §7.1 routes → Tasks 8, 9.
- §7.2 integration → Task 12.
- §7.3 styling → Tasks 10, 11 (with dark-mode walk in Task 13).
- §8 security → enforced inline in every method (auth checks, $DB->Clear, server-side eligibility re-check).
- §9 edge cases → covered in Task 6 (cast logic) + Task 4 (tally edge cases tested).
- §10 testing → Tasks 3, 4, 13.
- §11 prototype scope → Tasks 1–13.

**Placeholder scan**: Task 3's test bodies are described concisely but the implementer is told to write each one explicitly with the exact data shape — this is one elided block of test bodies, not a TODO. All other tasks have concrete code or explicit specifications. Confirmed no "TBD" or "implement later" remains.

**Type consistency**: Method names referenced across tasks — `tally_pure` (Task 3, 4), `CastBallot` (Tasks 6, 9), `Publish/Unpublish` (Tasks 6, 9), `ResolveTie` (Tasks 6, 9), `reevaluate_provisional_for_player` (Tasks 6, 12), `sweep_provisional_eligibility` (Task 6), `cycle_event_status` (Task 6) — consistent throughout.
