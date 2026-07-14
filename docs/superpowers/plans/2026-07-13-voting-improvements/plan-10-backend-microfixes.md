# Backend Micro-Fixes (IRV exhausted count + create date validation) Implementation Plan
> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.
> **Execute AFTER** the 2026-07-13 voting-improvements implementation workflow lands and is verified — anchor on landmarks, not line numbers.

**Goal:** Fix two isolated backend defects in the ORK3 voting module — the IRV round-by-round report always shows zero exhausted ballots (Finding 16), and event creation accepts any start/close datetimes with no ordering or past-date sanity check (Finding 47).

**Architecture:** Both fixes live in the DB-layer service `system/lib/ork3/class.Voting.php`. Finding 16 is inside the pure-PHP IRV tally (`tally_irv`, reachable from the static `tally_pure` engine that the unit harness exercises with no DB). Finding 47 is in the SOAP-style service methods `CreateEvent`/`UpdateEvent`, which receive already-parsed request arrays from the thin `orkui/model/model.Voting.php` pass-throughs and the `controller.Voting::create` / `controller.VotingAjax::edit_event` actions. Neither fix needs a new model wrapper or controller change — validation returns the existing `ProcessingError(...)` shape that the controllers already surface.

**Tech Stack:** PHP 8 / MariaDB / pure-PHP tally engine

## Global Constraints
- **CHURN WARNING:** A separate workflow (Plans 1/2/3) has been editing `class.Voting.php` heavily just before this plan runs. Do NOT trust line numbers below — every task carries a `**Locate:**` grep. Read the CURRENT code around each landmark before editing.
- **Finding 16 overlaps Plan 2 (finding 19, IRV win-share)** — both touch the `tally_irv` round loop. Before editing, read the CURRENT round loop and confirm `$exhausted_this_round` is still declared and still initialized to `0` at the top of the `while (true)` body. If Plan 2 renamed it or moved it, adapt the anchor; do NOT blindly insert.
- **Finding 47 overlaps Plans 1/3** — they may have restructured the create/validation path. Locate the CURRENT create + update methods by name (`CreateEvent`, `UpdateEvent`); do not assume the request keys or ordering.
- `mysql_real_escape_string()` is a NO-OP shim — never rely on it. These two fixes touch no raw SQL string interpolation; keep it that way. Dates are validated in PHP (strtotime), never spliced into SQL.
- yapo drops `null` from UPDATE/INSERT — not relevant here (we reject bad input rather than clear a column), but do not "fix" a date to `null`.
- DB-layer logic lives in `system/lib/ork3/`; `orkui/model` is a thin per-method pass-through. Neither fix adds a service method, so no new wrapper is needed.
- Human-readable dates always; date sanity is validated server-side in the service (not only in JS), because the form can be bypassed.
- Response helpers are the global functions in `orkservice/Common.definitions.php`: `Success($detail)`, `InvalidParameter($detail, $error)`, `ProcessingError($detail, $error)`. The **human message goes in the 2nd arg (`$error`)**; existing code calls e.g. `ProcessingError('', 'Only draft events can be edited.')`. Status is a nonzero int on error, `0` on success; controllers test `($r['Status'] ?? 1) == 0` and display `$r['Error'] . ': ' . $r['Detail']`.

---

## File Structure

Files touched (all pre-existing — no new files):

```
system/lib/ork3/class.Voting.php        # both fixes: tally_irv (F16), CreateEvent + UpdateEvent (F47)
tests/voting/tally_test.php             # F16: add one TDD test method (VotingTallyTests)
```

Verification-only (read, do not edit):
```
tests/voting/tally_test_runner.php      # standalone runner, no DB/framework bootstrap
orkui/controller/controller.Voting.php  # create action (POST Action=create_event) — used for F47 curl
orkservice/Common.definitions.php        # ProcessingError/Success signatures — reference only
```

---

## Task 1 — Finding 16: IRV round report counts exhausted ballots (TDD)

**Files:** `tests/voting/tally_test.php`, `system/lib/ork3/class.Voting.php`

**Locate:**
- Test file: `grep -n "test_irv_exhausted_ballots\|function ballot_irv\|class VotingTallyTests" tests/voting/tally_test.php`
- Fix site: `grep -n "function tally_irv\|exhausted_this_round\|\$head === null" system/lib/ork3/class.Voting.php`

**Interfaces:**
- Static engine entry: `Voting::tally_pure(array $race, array $ballots): array` → for IRV returns `['outcome'=>..., 'rounds'=>[ ['round'=>N,'counts'=>[cid=>n],'eliminated'=>cid|null,'winner'=>cid|null,'exhausted_this_round'=>int], ... ], ...]`.
- Ballot factory `ballot_irv([cid1, cid2, ...])` builds a ranked ballot (rank = array position + 1).
- The round loop initializes `$exhausted_this_round = 0` at the top of each `while (true)` iteration, tallies each sequence's current `$head` (first non-eliminated ranked choice), and `continue`s when `$head === null` (ballot has no remaining continuing candidate = exhausted). The bug: it `continue`s **without** incrementing `$exhausted_this_round`, so every round entry reports `0`.

### Steps

- [ ] **Step 1 — Read the current round loop.** Open `class.Voting.php` at `tally_irv` and read the whole `while (true) { ... }` body. Confirm: (a) `$exhausted_this_round = 0;` is still present near the top of the loop body, (b) there is a per-ballot `foreach ($sequences as $seq)` that computes `$head` and has an `if ($head === null) { continue; }` branch, and (c) each `$rounds[] = [...]` entry still carries `'exhausted_this_round' => $exhausted_this_round`. If Plan 2 renamed any of these, note the real names and use them in Steps 3–4. Do not edit yet.

- [ ] **Step 2 — Write the failing test.** In `tests/voting/tally_test.php`, add this method to `class VotingTallyTests` immediately AFTER the existing `test_irv_exhausted_ballots` method (find its closing brace with the grep above). Paste exactly:

```php
    public function test_irv_exhausted_count_reported()
    {
        // Same shape as test_irv_exhausted_ballots, but asserts the per-round
        // exhausted counter (Finding 16). One voter ranks only C.
        // R1: A=2, B=2, C=1 — no majority, eliminate C. No ballot exhausts yet.
        // R2: C's lone voter has no continuing candidate → exhausts. A=2, B=2 → tie_at_final.
        $race = ['race_type' => 'position', 'voting_mode' => 'irv',
            'allow_abstain' => 0, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
            'choices' => [['id' => 10,'label' => 'A'],['id' => 11,'label' => 'B'],['id' => 12,'label' => 'C']]];
        $ballots = array_merge(
            array_fill(0, 2, $this->ballot_irv([10, 11])),
            array_fill(0, 2, $this->ballot_irv([11, 10])),
            [$this->ballot_irv([12])]
        );
        $r = Voting::tally_pure($race, $ballots);
        $this->assertEq('tie_at_final', $r['outcome'], 'outcome sanity');
        $this->assertEq(2, count($r['rounds']), 'two rounds run');
        $this->assertEq(0, $r['rounds'][0]['exhausted_this_round'], 'round 1: no ballots exhausted');
        $this->assertEq(1, $r['rounds'][1]['exhausted_this_round'], 'round 2: one ballot exhausted');
    }
```

- [ ] **Step 3 — Run the test; confirm it FAILS.** Run:
  `docker exec -i ork3-php8-app php /var/www/html/tests/voting/tally_test_runner.php`
  Expect a `FAIL  test_irv_exhausted_count_reported — round 2: one ballot exhausted: expected 1 got 0` line and overall exit non-zero. This proves the counter is dead. (If it unexpectedly PASSES, Plan 2 already fixed it — stop and re-verify the fix is truly present before touching the loop.)

- [ ] **Step 4 — Implement the one-line fix.** In `tally_irv`, in the per-ballot `foreach ($sequences as $seq)` loop, change the exhaustion branch to increment the counter before continuing. Edit:

```php
                if ($head === null) {
                    continue;
                }
```
to:
```php
                if ($head === null) {
                    $exhausted_this_round++;
                    continue;
                }
```
(If Plan 2 refactored the head lookup into a helper or renamed the variable, apply the increment at the equivalent "no continuing candidate for this ballot" point instead — the semantics, not the literal text, are what matter.)

- [ ] **Step 5 — Run the test; confirm it PASSES.** Run the same runner command from Step 3. Expect `PASS  test_irv_exhausted_count_reported` and, at the bottom, `N passed, 0 failed` with exit 0. Every previously-passing test must still pass — a regression here means the increment landed in the wrong branch.

- [ ] **Step 6 — Commit.**
  `git add system/lib/ork3/class.Voting.php tests/voting/tally_test.php && git commit -m "Voting: count exhausted ballots per IRV round (Finding 16)"`
  (Never `git add -A`. Do NOT push.)

---

## Task 2 — Finding 47: Server-side date sanity on event create/edit

**Files:** `system/lib/ork3/class.Voting.php`

**Locate:**
- Create: `grep -n "function CreateEvent\|->start_date = \|->end_date" system/lib/ork3/class.Voting.php`
- Update: `grep -n "function UpdateEvent" system/lib/ork3/class.Voting.php`
- Helper insertion point: put the new private helper next to the other private helpers, e.g. just above `CreateEvent` — find an anchor with `grep -n "private function audit\|public function CreateEvent" system/lib/ork3/class.Voting.php`.

**Interfaces:**
- `CreateEvent($request)` reads `$request['StartDate']` / `$request['EndDate']` (raw strings from the create form) and assigns them straight to `$this->Event->start_date` / `end_date` with NO validation, then `->save()` and returns `Success($voting_event_id)`.
- `UpdateEvent($request)` (draft-only edit) copies `StartDate`/`EndDate` from the request into the event when present. This is the "save path" — dates flow through here too, so both must validate.
- New private helper `validate_event_dates(?string $start, ?string $end): ?string` — returns `null` when OK, or a human-readable error string when invalid. Uses `strtotime()` to parse; rejects unparseable, `end <= start`, and a past `end`.

### Steps

- [ ] **Step 1 — Read the current create + update methods.** Open `CreateEvent` and `UpdateEvent` and confirm the request keys are still `StartDate`/`EndDate` and that `CreateEvent` still assigns them before `->save()`. Note where auth/param checks end and the save begins — the date check goes AFTER auth/scope validation (don't leak validity to unauthorized callers) but BEFORE `->save()`. Do not edit yet.

- [ ] **Step 2 — Add the validation helper.** Insert this private method just above `CreateEvent` (adjust indentation to the file's tabs — check with `awk '/^\t/{c++}END{print c+0}' system/lib/ork3/class.Voting.php`; the file uses 4-space PSR-12, so match surrounding methods):

```php
    /**
     * Sanity-check event window dates. Returns null when OK, else a human message.
     * Dates arrive as strings from the create/edit form; validate server-side because
     * the form's JS gate can be bypassed. Never trust the client.
     */
    private function validate_event_dates(?string $start, ?string $end): ?string
    {
        $s = ($start === null || $start === '') ? false : strtotime($start);
        $e = ($end === null || $end === '') ? false : strtotime($end);
        if ($s === false) {
            return 'A valid opening date is required.';
        }
        if ($e === false) {
            return 'A valid closing date is required.';
        }
        if ($e <= $s) {
            return 'The closing date must be after the opening date.';
        }
        if ($e <= time()) {
            return 'The closing date is already in the past — pick a future closing date.';
        }
        return null;
    }
```

- [ ] **Step 3 — Enforce in `CreateEvent`.** In `CreateEvent`, after the auth/scope checks pass and BEFORE `$this->Event->clear();` (or before the first `$this->Event->start_date =` assignment), add:

```php
        $date_error = $this->validate_event_dates($request['StartDate'] ?? null, $request['EndDate'] ?? null);
        if ($date_error !== null) {
            return ProcessingError('', $date_error);
        }
```
(Message in the 2nd arg per the Global Constraints. `ProcessingError` yields a nonzero `Status`, so `controller.Voting::create` shows `$r['Error']: $r['Detail']`.)

- [ ] **Step 4 — Enforce in `UpdateEvent`.** In `UpdateEvent`, dates are optional on edit and only some keys may be present, so validate the EFFECTIVE window (incoming value if present, else the currently-persisted value). After the event is loaded and confirmed to be a draft, but before the field-diff `foreach` that writes changes, add:

```php
        $eff_start = array_key_exists('StartDate', $request) ? $request['StartDate'] : $this->Event->start_date;
        $eff_end   = array_key_exists('EndDate', $request) ? $request['EndDate'] : $this->Event->end_date;
        if (array_key_exists('StartDate', $request) || array_key_exists('EndDate', $request)) {
            $date_error = $this->validate_event_dates($eff_start, $eff_end);
            if ($date_error !== null) {
                return ProcessingError('', $date_error);
            }
        }
```
(Only validate when the caller is actually changing a date, so unrelated edits to an already-past draft aren't blocked spuriously. Confirm the loaded-event landmark: `grep -n "if (!\$this->Event->find())\|status !== 'draft'" system/lib/ork3/class.Voting.php` — place this block after those guards, before the `$diff = [];` loop.)

- [ ] **Step 5 — Verify rejection via curl (bad dates).** App is at http://localhost:19080/orkui/, routes are `index.php?Route=Controller/action/id`. First authenticate (login accepts any password; single cookie jar):
  ```bash
  J=/private/tmp/claude-501/-Users-averykrouse-GitHub-ORK-tobias-ORK3-tobias/5c20979b-170c-4876-a3a2-3e29860d8b56/scratchpad/vote_cookies.txt
  curl -s -c "$J" -b "$J" "http://localhost:19080/orkui/index.php?Route=Login/login" \
    --data-urlencode "Login=<a_runner_login>" --data-urlencode "Password=x" -o /dev/null
  ```
  Then GET the create page to mint a CSRF token and pick a scope you can run (e.g. `Kingdom_<id>`), scraping `csrf_token` from the returned HTML:
  ```bash
  curl -s -c "$J" -b "$J" "http://localhost:19080/orkui/index.php?Route=Voting/create/Kingdom_<id>" \
    | grep -o "name=['\"]csrf_token['\"][^>]*value=['\"][^'\"]*" | head -1
  ```
  POST a create with **end before start**, expecting the page to re-render with the error text (not a redirect to `Voting/edit/...`):
  ```bash
  curl -s -c "$J" -b "$J" "http://localhost:19080/orkui/index.php?Route=Voting/create/Kingdom_<id>" \
    --data-urlencode "Action=create_event" --data-urlencode "csrf_token=<token>" \
    --data-urlencode "EventType=election" --data-urlencode "Title=DateTest" \
    --data-urlencode "Description=" \
    --data-urlencode "StartDate=2026-08-01 12:00" --data-urlencode "EndDate=2026-07-01 12:00" \
    | grep -i "closing date must be after"
  ```
  Expect the "closing date must be after the opening date" message to appear. Repeat with a **past end date** (`EndDate=2020-01-01 12:00`) and expect "closing date is already in the past".

- [ ] **Step 6 — Verify acceptance via curl (good dates) + DB.** POST a valid future window and confirm success (the controller redirects to `Voting/edit/<id>` on `Status==0`); use `-i` to see the `Location` header:
  ```bash
  curl -s -i -c "$J" -b "$J" "http://localhost:19080/orkui/index.php?Route=Voting/create/Kingdom_<id>" \
    --data-urlencode "Action=create_event" --data-urlencode "csrf_token=<fresh_token>" \
    --data-urlencode "EventType=election" --data-urlencode "Title=DateTestOK" \
    --data-urlencode "Description=" \
    --data-urlencode "StartDate=2026-09-01 12:00" --data-urlencode "EndDate=2026-09-08 12:00" \
    | grep -i "^location:"
  ```
  Expect a `Location: .../Voting/edit/<new_id>`. Confirm the row landed:
  ```bash
  docker exec -i ork3-php8-db mariadb -u root -proot ork \
    -e "SELECT voting_event_id, title, start_date, end_date, status FROM ork_voting_event WHERE title='DateTestOK' ORDER BY voting_event_id DESC LIMIT 1;"
  ```
  (Confirm the actual table prefix first: `docker exec -i ork3-php8-db mariadb -u root -proot ork -e "SHOW TABLES LIKE '%voting_event%';"` — use whatever prefix it reports.) Expect one row with the future dates and `status='draft'`. Clean up the test row afterward if desired.

- [ ] **Step 7 — Commit.**
  `git add system/lib/ork3/class.Voting.php && git commit -m "Voting: reject invalid/past event dates on create and edit (Finding 47)"`
  (Never `git add -A`. Do NOT push.)

---

## Self-Review Checklist

- [ ] **Line numbers not trusted** — every edit was located by the task's `grep`/`Locate` anchor against the CURRENT (post-Plans-1/2/3) tree, not by the numbers referenced in the findings.
- [ ] **F16 overlap honored** — confirmed `$exhausted_this_round` still declared and zero-initialized per round in the CURRENT `tally_irv` before adding the increment; the increment sits in the exact "ballot has no continuing candidate" (`$head === null`) branch.
- [ ] **F16 is real TDD** — the new test was seen FAILING (Step 3) before the fix and PASSING (Step 5) after; full suite exit 0, no regressions.
- [ ] **F47 overlap honored** — located the CURRENT `CreateEvent`/`UpdateEvent`; date check placed AFTER auth/scope guards, BEFORE `->save()`/the diff loop.
- [ ] **F47 validates server-side** — rejection is enforced in the service, independent of any JS; verified by curl for both bad-date cases (ordering + past) and the valid case, and the valid row confirmed in the DB.
- [ ] **Error shape correct** — messages returned via `ProcessingError('', $msg)` (message in 2nd arg), nonzero Status surfaces through the existing controller display path.
- [ ] **No new SQL string interpolation** of dates; no reliance on the `mysql_real_escape_string` shim; no `null` assigned to clear a column.
- [ ] **No model/controller changes required** — confirmed the existing thin pass-throughs and controllers already carry `StartDate`/`EndDate` and surface `Error`/`Detail`; no new wrapper added.
- [ ] **Two focused commits**, files staged explicitly (never `git add -A`), nothing pushed. `class.Authorization.php` and `CLAUDE.md` untouched/unstaged.
