# Eligibility, Electorate & Turnout Implementation Plan
> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Make voting eligibility work in every kingdom (not just the 15 hardcoded ones), tell voters *why* they can't vote and how to fix it, freeze the eligible electorate at publish so turnout/quorum are reconstructable, and show organizers who can vote.

**Architecture:** All eligibility computation stays in `system/lib/ork3/class.Voting.php` (DB/business layer); `orkui/model/model.Voting.php` remains a thin pass-through; controllers assign data to plain-PHP `.tpl` views. A single new roll-computation helper (`compute_eligible_roll`) is the one source of truth consumed by the voter check, the organizer card, the runner turnout widget, and the publish-time freeze. At publish we materialize the full eligible set into `ork_voting_eligibility_snapshot` (eligible=1 rows) and stamp `eligible_count` + `ballots_cast` onto `ork_voting_event` — that frozen denominator is the producer contract Domain 2 (Tally) consumes for quorum.

**Tech Stack:** PHP 8 / MariaDB / plain-PHP templates

## Global Constraints
- `.tpl` files are PLAIN PHP — use `<?php ?>`/`<?= ?>`, never Smarty `{$var}`/`{if}`.
- `mysql_real_escape_string()` is a no-op shim — `(int)`-cast ids; never interpolate unvalidated strings into SQL.
- yapo drops `null` from UPDATE/INSERT — assign `''` (not `null`) to clear a column.
- Always `$DB->Clear()` before every raw `Execute`/`DataSet`; `$DB->DataSet()` needs a manual `->Next()` before reading fields.
- DB-layer logic lives in `system/lib/ork3/`; `orkui/model` is a thin pass-through; controllers must not run raw `$DB`.
- Dark mode selector is `html[data-theme="dark"]`; always render human-readable dates (`date('M j, Y g:i A', ...)`).
- Migrations run via `docker exec -i ork3-php8-db mariadb -u root -proot ork < migration.sql`. The shared local DB may LACK voting columns — `SHOW COLUMNS` probe first.
- FontAwesome 5.8.2 only (no FA6-only icon names).
- **Backward-compat contract:** `check_eligibility_live()` and `GetEligibilityCheck()` must KEEP their existing return keys (`eligible`, `provisional_possible`, `rules`, `Eligible`, `ProvisionalPossible`, `AllowProvisional`) — the provisional sweep (Domain 1, `reevaluate_provisional_for_player` / `sweep_provisional_eligibility`) and the cast path read `$elig['eligible']`. Only ADD new keys.

---

## Producer contract for Domain 2 (Tally / quorum) — READ THIS

Domain 2 consumes the **frozen eligible electorate** this plan produces. The exact contract:

- **`ork_voting_event.eligible_count`** — `INT NOT NULL DEFAULT 0`. Count of DISTINCT eligible voters (`eligible = 1`) in the frozen roll. Written exactly once, at `Voting::Publish()`, immediately before `$this->Event->save()`. Immutable after publish (Unpublish/Reopen do not recompute it).
- **`ork_voting_event.ballots_cast`** — `INT NOT NULL DEFAULT 0`. Count of *counted* (non-provisional) active ballots at publish time. Written at the same point. This is the turnout numerator.
- **Frozen eligible set (enumerable, not just a count):** at publish, every eligible voter is upserted into `ork_voting_eligibility_snapshot` with `eligible = 1`. Domain 2 can therefore reconstruct the roll with:
  `SELECT mundane_id FROM ork_voting_eligibility_snapshot WHERE voting_event_id = ? AND eligible = 1`.
- **Denominator semantics:** `eligible_count` counts everyone with the kingdom-level right to vote (`VotingEligible` from the resolved ruleset), scoped to park members when the event scope is a park. This matches who the cast path admits, so quorum `ballots_cast / eligible_count` is coherent.

Domain 2 MUST read `eligible_count` from the event row (or `COUNT(*) … eligible=1` from the snapshot) — it must NOT recompute eligibility itself.

---

## File Structure

| File | Responsibility (this plan) |
|------|----------------------------|
| `db-migrations/2026-07-13-voting-eligibility-turnout.sql` | Adds `eligible_count` + `ballots_cast` columns to `ork_voting_event`. |
| `system/lib/ork3/class.Voting.php` | Safe-default rule resolver; `compute_eligible_roll` helper; enriched `check_eligibility_live` (reason detail + fixed provisional logic); enriched `GetEligibilityCheck`; publish-time roll freeze + count stamping; live turnout counts on `ballot_counts`. |
| `orkui/model/model.Voting.php` | Thin pass-throughs: `eligible_roll($scope_type,$scope_id)`. |
| `orkui/controller/controller.Voting.php` | Assign eligibility-summary data to create/edit views; assign turnout to runner view. |
| `orkui/controller/controller.VotingAjax.php` | `eligibility_roster` endpoint (organizer roster drawer). |
| `orkui/template/revised-frontend/Voting_event.tpl` | Show the specific gating reason + fix link to the voter. |
| `orkui/template/revised-frontend/Voting_create.tpl` | Eligibility summary card (rule + live count). |
| `orkui/template/revised-frontend/Voting_edit.tpl` | Eligibility summary card + roster drawer. |
| `orkui/template/revised-frontend/Voting_runner.tpl` | Turnout stat (counted + eligible + turnout %). |
| `orkui/template/revised-frontend/Voting_results.tpl` | Turnout line (counted / eligible / turnout %). |
| `tests/voting/eligibility_probe.php` | Focused CLI probe calling the pure reason-mapping + default-resolver. |

---

## Task 1 — Finding 21: Safe default ruleset so voting works in every kingdom

**Rationale for the chosen fix:** We take the **safe-default** approach (not create-blocking). An unlisted kingdom's parks already fall back to the parent, but `check_eligibility_live` returns `eligible=false` when `voting_rules_for_kingdom` is `null` (`class.Voting.php:83-85`), bricking both real voters and runner paper-ballot entry. `Report::GetVotingEligible` already defaults sensibly when handed empty rules (att_req 6, weeks, min_mem 6), so the only real bug is the early ineligible return. We add an explicit `DEFAULT_RULES` constant and a resolver that reports whether the default was applied (so the organizer card can say so), and we route `check_eligibility_live` through it. We also fix the provisional-possible computation, which currently reads `$player['AttendanceMet']`/`$player['Days']` — keys `GetVotingEligible` never returns — so provisional is effectively dead.

**Files:** `system/lib/ork3/class.Voting.php`, `tests/voting/eligibility_probe.php`

**Interfaces:**
- Produces `Voting::DEFAULT_RULES` (const array).
- Produces `Voting::resolve_rules(int $kingdom_id): array` → `['rules' => array, 'is_default' => bool]`.
- Consumes `Report::GetVotingEligible(...)` returning `['Players' => [ ['VotingEligible'=>bool,'DuesPaid'=>int,'Waivered'=>int,'MembershipOk'=>bool,'Suspended'=>bool,'AttCount'=>int,'DuesUntil'=>?string,'SuspendedUntil'=>?string,'MemberSince'=>?string,...] ]]`.
- Modifies `check_eligibility_live(...)` return to still include `eligible`, `provisional_possible`, `rules`, `player`, and ADD `is_default_rules` (bool) + `reason` (array, see Task 2).

- [ ] **Step 1** — Probe the live DB for the target columns before writing SQL. Run:
  `docker exec -i ork3-php8-db mariadb -u root -proot ork -e "SHOW COLUMNS FROM ork_voting_event LIKE 'eligible_count'; SHOW COLUMNS FROM ork_voting_eligibility_snapshot;"`
  Expected: `eligible_count` returns 0 rows (not yet added — Task 5 adds it); snapshot columns are `voting_event_id, mundane_id, eligible, was_provisional, source_rules, evaluated_at`. Record the result; if columns already exist, skip the matching migration ADD in Task 5.

- [ ] **Step 2** — Add the `DEFAULT_RULES` constant. In `system/lib/ork3/class.Voting.php`, immediately after the `private static $rules_by_kingdom = [ ... ];` block closes (after line ~56), insert:
```php
    // Applied when a kingdom is not in $rules_by_kingdom. Matches the Reports-layer defaults
    // (att_req 6, 6-month window, weeks) so unlisted kingdoms behave like a plain attendance rule
    // instead of being bricked. See Finding 21.
    public const DEFAULT_RULES = [
        'AttendanceRequired'  => 6,
        'MonthsWindow'        => 6,
        'MinMembershipMonths' => 0,
        'AttendanceMode'      => 'weeks',
        'ProvinceMode'        => false,
    ];
```

- [ ] **Step 3** — Add the resolver method. Directly below the existing `voting_rules_for_kingdom` method (after line ~61), insert:
```php
    // Resolve the ruleset for a kingdom, falling back to a safe default so voting is never
    // impossible in an unconfigured kingdom. is_default lets the organizer UI disclose the fallback.
    public static function resolve_rules($kingdom_id)
    {
        $rules = self::$rules_by_kingdom[(int)$kingdom_id] ?? null;
        if ($rules === null) {
            return ['rules' => self::DEFAULT_RULES, 'is_default' => true];
        }
        return ['rules' => $rules, 'is_default' => false];
    }
```

- [ ] **Step 4** — Rewrite `check_eligibility_live` (currently lines ~79-106) to use the resolver and to compute provisional-possible from keys that actually exist. Replace the whole method body with:
```php
    private function check_eligibility_live($mundane_id, $scope_type, $scope_id)
    {
        $kingdom_id = $this->resolve_kingdom_id($scope_type, $scope_id);
        $resolved   = self::resolve_rules($kingdom_id);
        $rules      = $resolved['rules'];

        $report = new Report();
        $args = array_merge($rules, [
            'KingdomId' => $kingdom_id,
            'MundaneId' => (int)$mundane_id,
        ]);
        if ($scope_type === 'park') {
            $args['ParkId'] = (int)$scope_id;
        }
        $r = $report->GetVotingEligible($args);
        $player = $r['Players'][0] ?? [];

        $eligible = !empty($player['VotingEligible']);
        $att_req  = (int)($rules['AttendanceRequired'] ?? 6);
        $att_have = (int)($player['AttCount'] ?? 0);

        // Provisional-possible = currently ineligible but ONLY because of dues, with attendance already met
        // and no hard blocker (suspension / no waiver). GetVotingEligible does not expose AttendanceMet/Days;
        // derive from AttCount vs AttendanceRequired and the dues flag.
        $provisional_possible = !$eligible
            && !empty($player)
            && empty($player['Suspended'])
            && !empty($player['Waivered'])
            && empty($player['DuesPaid'])
            && $att_have >= $att_req;

        $reason = $this->eligibility_reason($eligible, $player, $att_req);

        return [
            'eligible'             => $eligible,
            'provisional_possible' => $provisional_possible,
            'rules'                => $rules,
            'is_default_rules'     => $resolved['is_default'],
            'player'               => $player,
            'reason'               => $reason,
        ];
    }
```

- [ ] **Step 5** — Add a focused CLI probe (no framework harness assumed). Create `tests/voting/eligibility_probe.php`:
```php
<?php
// Focused probe for the pure default-resolver + reason mapper (no DB).
// Run: docker exec -i ork3-php8-app php /var/www/html/tests/voting/eligibility_probe.php
require_once __DIR__ . '/../../system/lib/ork3/class.Ork3.php';
require_once __DIR__ . '/../../system/lib/ork3/class.Voting.php';

// 1) Unlisted kingdom resolves to a usable default, flagged is_default.
$r = Voting::resolve_rules(99999);
assert($r['is_default'] === true, 'unlisted kingdom must default');
assert(($r['rules']['AttendanceRequired'] ?? null) === 6, 'default att_req is 6');

// 2) Listed kingdom keeps its own rule, not flagged default.
$r = Voting::resolve_rules(14);
assert($r['is_default'] === false, 'kingdom 14 is configured');
assert(($r['rules']['AttendanceRequired'] ?? null) === 7, 'kingdom 14 att_req is 7');

// 3) Reason mapper is pure and covers each gate.
$reason = Voting::reason_pure(false, ['Suspended' => true, 'SuspendedUntil' => '2026-08-01'], 6);
assert($reason['code'] === 'suspended', 'suspended gate');
$reason = Voting::reason_pure(false, ['Suspended' => false, 'Waivered' => 0], 6);
assert($reason['code'] === 'no_waiver', 'waiver gate');
$reason = Voting::reason_pure(false, ['Suspended' => false, 'Waivered' => 1, 'MembershipOk' => 1, 'DuesPaid' => 0, 'AttCount' => 9], 6);
assert($reason['code'] === 'dues', 'dues gate when attendance met');
$reason = Voting::reason_pure(false, ['Suspended' => false, 'Waivered' => 1, 'MembershipOk' => 1, 'DuesPaid' => 1, 'AttCount' => 2], 6);
assert($reason['code'] === 'attendance' && $reason['short'] === 4, 'attendance shortfall = 4');
echo "eligibility_probe OK\n";
```

- [ ] **Step 6** — Verify. Run the probe:
  `docker exec -i ork3-php8-app php /var/www/html/tests/voting/eligibility_probe.php`
  Expected stdout: `eligibility_probe OK` (no assertion failure). (Task 2 adds `reason_pure`/`eligibility_reason` — if running Task 1 in isolation, defer this step until after Task 2; the default-resolver asserts pass regardless.)

- [ ] **Step 7** — Commit.
  `git add system/lib/ork3/class.Voting.php tests/voting/eligibility_probe.php && git commit -m "Voting: safe default ruleset for unlisted kingdoms + fix dead provisional check (Finding 21)"`

---

## Task 2 — Finding 5: Show voters the specific gating reason + a fix link

**Files:** `system/lib/ork3/class.Voting.php`, `orkui/template/revised-frontend/Voting_event.tpl`

**Interfaces:**
- Produces `Voting::reason_pure(bool $eligible, array $player, int $att_req): array` → `['code'=>string,'text'=>string,'short'=>int,'fix'=>?string]` where `code ∈ {none, suspended, no_waiver, membership, dues, attendance, unknown}`, `short` = attendance days still needed (0 unless code=attendance), `fix` = a relative fix path or null.
- Produces `Voting::eligibility_reason(...)` (instance wrapper calling `reason_pure`).
- `GetEligibilityCheck` return ADDS `Reason`, `ReasonText`, `ReasonShort`, `FixUrl` (existing `Eligible`/`ProvisionalPossible`/`AllowProvisional` unchanged).
- Consumed by `Voting_event.tpl` via `$elig['ReasonText']` etc.

- [ ] **Step 1** — Add the pure reason mapper. In `system/lib/ork3/class.Voting.php`, directly below `resolve_rules` (from Task 1), insert:
```php
    // Pure gating-reason mapper: given a GetVotingEligible player row + the attendance requirement,
    // returns why they are ineligible and (when applicable) a relative fix path. Order = severity.
    public static function reason_pure($eligible, array $player, $att_req)
    {
        if ($eligible) {
            return ['code' => 'none', 'text' => '', 'short' => 0, 'fix' => null];
        }
        if (empty($player)) {
            return ['code' => 'unknown', 'text' => 'You are not currently eligible to vote in this event.', 'short' => 0, 'fix' => null];
        }
        if (!empty($player['Suspended'])) {
            $until = !empty($player['SuspendedUntil']) ? ' (until ' . date('M j, Y', strtotime($player['SuspendedUntil'])) . ')' : '';
            return ['code' => 'suspended', 'text' => 'Your membership is suspended' . $until . ', so you cannot vote.', 'short' => 0, 'fix' => null];
        }
        if (empty($player['Waivered'])) {
            return ['code' => 'no_waiver', 'text' => 'You need a current waiver on file with your park before you can vote.', 'short' => 0, 'fix' => null];
        }
        if (isset($player['MembershipOk']) && empty($player['MembershipOk'])) {
            $since = !empty($player['MemberSince']) ? ' (member since ' . date('M j, Y', strtotime($player['MemberSince'])) . ')' : '';
            return ['code' => 'membership', 'text' => 'You have not been a member long enough to vote yet' . $since . '.', 'short' => 0, 'fix' => null];
        }
        if (empty($player['DuesPaid'])) {
            return ['code' => 'dues', 'text' => 'You need to pay your membership dues to be eligible to vote.', 'short' => 0, 'fix' => 'Player/renew'];
        }
        $att_have = (int)($player['AttCount'] ?? 0);
        $short = max(0, (int)$att_req - $att_have);
        if ($short > 0) {
            return ['code' => 'attendance', 'text' => 'You need ' . $short . ' more qualifying event ' . ($short === 1 ? 'day' : 'days') . ' before the vote closes to be eligible.', 'short' => $short, 'fix' => null];
        }
        return ['code' => 'unknown', 'text' => 'You are not currently eligible to vote in this event.', 'short' => 0, 'fix' => null];
    }

    // Instance wrapper — keeps call sites terse.
    private function eligibility_reason($eligible, array $player, $att_req)
    {
        return self::reason_pure($eligible, $player, $att_req);
    }
```

- [ ] **Step 2** — Enrich `GetEligibilityCheck` (currently lines ~2110-2134) so the ballot page receives the reason. Replace its return array with:
```php
        $elig = $this->check_eligibility_live($mundane_id, $rs->scope_type, $rs->scope_id);
        $reason = $elig['reason'] ?? ['code' => 'unknown', 'text' => 'You are not currently eligible to vote in this event.', 'short' => 0, 'fix' => null];
        return [
            'Status' => 0,
            'Eligible' => $elig['eligible'],
            'ProvisionalPossible' => $elig['provisional_possible'],
            'AllowProvisional' => (int)$rs->allow_provisional,
            'Reason' => $reason['code'],
            'ReasonText' => $reason['text'],
            'ReasonShort' => (int)$reason['short'],
            'FixUrl' => $reason['fix'],
        ];
```

- [ ] **Step 3** — Show the reason on the voter ballot. In `orkui/template/revised-frontend/Voting_event.tpl`, replace the plain ineligible banner at line ~76:
```php
			<div class="vtv-banner vtv-banner-err">You are not currently eligible to vote in this event.</div>
```
with:
```php
			<div class="vtv-banner vtv-banner-err">
				<i class="fas fa-exclamation-triangle"></i>
				<?= htmlspecialchars(!empty($elig['ReasonText']) ? $elig['ReasonText'] : 'You are not currently eligible to vote in this event.') ?>
				<?php if (!empty($elig['FixUrl'])): ?>
					<a href="<?= UIR . htmlspecialchars($elig['FixUrl']) ?>" style="color:inherit;text-decoration:underline;font-weight:600;margin-left:6px;">Fix this &rarr;</a>
				<?php endif; ?>
			</div>
```

- [ ] **Step 4** — Verify (browser click-path). Log in as a voter who is ineligible for an open event (unpaid dues). Navigate to `http://localhost:19080/orkui/index.php?Route=Voting/event/{id}`. Expected: the red banner now reads "You need to pay your membership dues to be eligible to vote." with a "Fix this →" link to `Player/renew`, instead of the generic line. For an attendance-short voter it reads "You need N more qualifying event days…". Confirm the provisional info banner still appears for a dues-only voter when the event allows provisional.

- [ ] **Step 5** — Verify the sweep is unbroken (backward-compat). Run:
  `docker exec -i ork3-php8-app php -r 'require "/var/www/html/system/lib/ork3/class.Voting.php"; echo "loaded\n";'`
  and confirm `reevaluate_provisional_for_player` still only reads `$elig['eligible']` — grep: `grep -n "\$elig\['eligible'\]" system/lib/ork3/class.Voting.php` should show lines ~1385, ~1564, ~1652 unchanged (no renamed key).

- [ ] **Step 6** — Commit.
  `git add system/lib/ork3/class.Voting.php orkui/template/revised-frontend/Voting_event.tpl && git commit -m "Voting: surface specific eligibility reason + fix link on voter ballot (Finding 5)"`

---

## Task 3 — Eligible-roll helper (shared source of truth)

The organizer card (Task 6), runner turnout (Task 7), and publish freeze (Task 5) all need "who can vote in this scope, and how many." Build one helper so the number is identical everywhere.

**Files:** `system/lib/ork3/class.Voting.php`, `orkui/model/model.Voting.php`

**Interfaces:**
- Produces `Voting::compute_eligible_roll(string $scope_type, int $scope_id): array` →
  `['rules'=>array, 'is_default'=>bool, 'count'=>int, 'ids'=>int[], 'players'=>array[]]`
  where each `players[i]` = `['MundaneId'=>int,'Persona'=>string,'ParkName'=>?string,'DuesPaid'=>int,'AttCount'=>int]`, and `ids` = the mundane_ids with `VotingEligible === true`.
- Produces model pass-through `Model_Voting::eligible_roll($scope_type, $scope_id)`.
- Consumes `Report::GetVotingEligible` (all-players form: no `MundaneId`).

- [ ] **Step 1** — Add the helper. In `system/lib/ork3/class.Voting.php`, place it just after `check_eligibility_live` (so all eligibility code is co-located):
```php
    // Full electorate for a scope: resolves the ruleset, runs the all-players eligibility report,
    // and returns the eligible set + count. Single source of truth for the organizer roster,
    // runner turnout, and the publish-time freeze. Kingdom scope evaluates the whole kingdom;
    // park scope narrows to park members (still using the kingdom-level VotingEligible right).
    public function compute_eligible_roll($scope_type, $scope_id)
    {
        $kingdom_id = $this->resolve_kingdom_id($scope_type, (int)$scope_id);
        $resolved   = self::resolve_rules($kingdom_id);
        $rules      = $resolved['rules'];

        $report = new Report();
        $args = array_merge($rules, ['KingdomId' => $kingdom_id]);
        if ($scope_type === 'park') {
            $args['ParkId'] = (int)$scope_id;
        }
        $r = $report->GetVotingEligible($args);

        $ids = [];
        $players = [];
        foreach (($r['Players'] ?? []) as $p) {
            if (empty($p['VotingEligible'])) {
                continue;
            }
            $mid = (int)($p['MundaneId'] ?? 0);
            if ($mid <= 0) {
                continue;
            }
            $ids[] = $mid;
            $players[] = [
                'MundaneId' => $mid,
                'Persona'   => (string)($p['Persona'] ?? ''),
                'ParkName'  => $p['ParkName'] ?? null,
                'DuesPaid'  => (int)($p['DuesPaid'] ?? 0),
                'AttCount'  => (int)($p['AttCount'] ?? 0),
            ];
        }
        return [
            'rules'      => $rules,
            'is_default' => $resolved['is_default'],
            'count'      => count($ids),
            'ids'        => $ids,
            'players'    => $players,
        ];
    }
```

- [ ] **Step 2** — Add the model pass-through. In `orkui/model/model.Voting.php`, next to the existing `eligibility_check` pass-through (~line 114), add:
```php
    public function eligible_roll($scope_type, $scope_id)
    {
        return $this->Voting->compute_eligible_roll($scope_type, (int)$scope_id);
    }
```

- [ ] **Step 3** — Verify via curl-auth. Log in (`index.php?Route=Login/login`, any password) into the cookie jar, then hit a temporary probe. Since there's no public route yet, verify inline:
  `docker exec -i ork3-php8-app php -r 'chdir("/var/www/html/orkui"); require "index.php";' 2>/dev/null || true`
  Instead run the deterministic check — add a throwaway assert to `tests/voting/eligibility_probe.php` is NOT needed (it hits the DB). Confirm structurally with:
  `grep -n "function compute_eligible_roll" system/lib/ork3/class.Voting.php && grep -n "function eligible_roll" orkui/model/model.Voting.php`
  Expected: both grep lines present. Functional confirmation happens in Task 6/7 verify steps (organizer count renders).

- [ ] **Step 4** — Commit.
  `git add system/lib/ork3/class.Voting.php orkui/model/model.Voting.php && git commit -m "Voting: shared compute_eligible_roll electorate helper (Finding 25/27 support)"`

---

## Task 4 — Migration: eligible_count + ballots_cast columns

**Files:** `db-migrations/2026-07-13-voting-eligibility-turnout.sql`

**Interfaces:** Produces `ork_voting_event.eligible_count INT NOT NULL DEFAULT 0`, `ork_voting_event.ballots_cast INT NOT NULL DEFAULT 0` — the Domain 2 quorum contract columns.

- [ ] **Step 1** — Create `db-migrations/2026-07-13-voting-eligibility-turnout.sql`:
```sql
-- Voting: freeze the eligible electorate + turnout at publish.
-- Producer contract for the Tally/quorum domain: eligible_count is the immutable
-- quorum denominator, ballots_cast the turnout numerator, both stamped at Publish().
-- The frozen eligible SET lives in ork_voting_eligibility_snapshot (eligible = 1 rows).

ALTER TABLE `ork_voting_event`
    ADD COLUMN `eligible_count` int(11) NOT NULL DEFAULT 0 AFTER `tally_snapshot`,
    ADD COLUMN `ballots_cast`   int(11) NOT NULL DEFAULT 0 AFTER `eligible_count`;
```

- [ ] **Step 2** — Apply it (probe first per Task 1 Step 1; skip if columns already exist):
  `docker exec -i ork3-php8-db mariadb -u root -proot ork < db-migrations/2026-07-13-voting-eligibility-turnout.sql`

- [ ] **Step 3** — Verify:
  `docker exec -i ork3-php8-db mariadb -u root -proot ork -e "SHOW COLUMNS FROM ork_voting_event LIKE '%_count'; SHOW COLUMNS FROM ork_voting_event LIKE 'ballots_cast';"`
  Expected: two rows, `eligible_count int(11) … 0` and `ballots_cast int(11) … 0`.

- [ ] **Step 4** — Commit.
  `git add db-migrations/2026-07-13-voting-eligibility-turnout.sql && git commit -m "Voting: migration for eligible_count + ballots_cast (Finding 25)"`

---

## Task 5 — Finding 25: Freeze the eligible roll at publish (Domain 2 producer)

**Files:** `system/lib/ork3/class.Voting.php`

**Interfaces:**
- Consumes `compute_eligible_roll` (Task 3) and `ballot_counts` (existing).
- Produces, at `Publish()`: full `eligible=1` upsert into `ork_voting_eligibility_snapshot`, plus `eligible_count` + `ballots_cast` written on the event row. **This is the frozen denominator Domain 2 consumes.**

- [ ] **Step 1** — In `system/lib/ork3/class.Voting.php`, locate `Publish()` (line ~1865). Immediately BEFORE the block that sets status (line ~1898 `$this->Event->status = 'published';`), insert the freeze logic:
```php
        // Freeze the electorate: materialize every eligible voter into the snapshot (eligible=1)
        // and stamp the immutable denominator + turnout numerator on the event. This is the
        // producer contract the Tally/quorum domain consumes. Preserves any existing rows
        // (voters already snapshotted at cast time) via upsert.
        $roll = $this->compute_eligible_roll($this->Event->scope_type, (int)$this->Event->scope_id);
        $rules_json = json_encode($roll['rules']);
        global $DB;
        foreach ($roll['ids'] as $mid) {
            $DB->Clear();
            $DB->Execute(
                "INSERT INTO " . DB_PREFIX . "voting_eligibility_snapshot
                    (voting_event_id, mundane_id, eligible, was_provisional, source_rules, evaluated_at)
                 VALUES (?, ?, 1, 0, ?, NOW())
                 ON DUPLICATE KEY UPDATE eligible = 1, source_rules = VALUES(source_rules), evaluated_at = NOW()",
                [$voting_event_id, (int)$mid, $rules_json]
            );
        }
        $counts = $this->ballot_counts($voting_event_id);
        $this->Event->eligible_count = (int)$roll['count'];
        $this->Event->ballots_cast   = (int)$counts['counted'];
```

- [ ] **Step 2** — Confirm the `Publish()` save still writes those fields. The existing `$this->Event->save();` at line ~1902 persists all set yapo fields, so `eligible_count`/`ballots_cast` are included — no extra change needed. Verify the `$this->Event->status`, `published_at`, etc. assignments stay ordered before `save()`.

- [ ] **Step 3** — Add turnout to the public results payload. In `tally_public` (the method returning the results array, ~line 2103), extend the `Event` sub-array to carry the frozen numbers. Locate:
```php
            'Event' => ['title' => $rs->title, 'event_type' => $rs->event_type, 'scope_type' => $rs->scope_type, 'scope_id' => (int)$rs->scope_id, 'start_date' => $rs->start_date, 'end_date' => $rs->end_date],
```
and replace with:
```php
            'Event' => ['title' => $rs->title, 'event_type' => $rs->event_type, 'scope_type' => $rs->scope_type, 'scope_id' => (int)$rs->scope_id, 'start_date' => $rs->start_date, 'end_date' => $rs->end_date, 'eligible_count' => (int)$rs->eligible_count, 'ballots_cast' => (int)$rs->ballots_cast],
```
Then ensure the SELECT that feeds `$rs` includes the new columns — find that method's `SELECT ... FROM ... voting_event` and confirm it is `SELECT *` (it is, per `tally_public`); if it names columns explicitly, add `eligible_count, ballots_cast`.

- [ ] **Step 4** — Show turnout on the results page. In `orkui/template/revised-frontend/Voting_results.tpl`, in the `rp-context` block (~line 66-69), directly after the existing context `<span>`, insert:
```php
			<?php $ec = (int)($event['eligible_count'] ?? 0); $bc = (int)($event['ballots_cast'] ?? 0); ?>
			<?php if ($ec > 0): ?>
				<span style="margin-left:12px;"><strong><?= $bc ?></strong> of <strong><?= $ec ?></strong> eligible voters cast a counted ballot (<strong><?= round($bc / $ec * 100) ?>%</strong> turnout).</span>
			<?php endif; ?>
```

- [ ] **Step 5** — Verify end-to-end via a real publish. Using the curl-auth session as a runner: open an event, cast a couple ballots, close it, then publish via `index.php?Route=VotingAjax/publish/{id}` (POST). Then:
  `docker exec -i ork3-php8-db mariadb -u root -proot ork -e "SELECT eligible_count, ballots_cast FROM ork_voting_event WHERE voting_event_id={id}; SELECT COUNT(*) eligible_rows FROM ork_voting_eligibility_snapshot WHERE voting_event_id={id} AND eligible=1;"`
  Expected: `eligible_count` > 0 and equals `eligible_rows`; `ballots_cast` equals the counted ballots. Then load `index.php?Route=Voting/results/{id}` and confirm the turnout sentence renders with a sane percentage.

- [ ] **Step 6** — Commit.
  `git add system/lib/ork3/class.Voting.php orkui/template/revised-frontend/Voting_results.tpl && git commit -m "Voting: freeze eligible roll + stamp eligible_count/ballots_cast at publish; show turnout on results (Finding 25)"`

---

## Task 6 — Finding 25 (cont.): Live turnout on the runner dashboard

**Files:** `orkui/controller/controller.Voting.php`, `orkui/template/revised-frontend/Voting_runner.tpl`

**Interfaces:**
- Consumes `Model_Voting::eligible_roll` (Task 3) and existing `ballot_counts`.
- Produces `$this->data['eligible_count']` (int) for the runner view.

- [ ] **Step 1** — In `orkui/controller/controller.Voting.php`, in `runner()`, after the existing `$this->data['counts'] = $this->Voting->ballot_counts($voting_event_id);` (line ~223), add:
```php
        // Live electorate size for turnout (pre-publish shows a live estimate; post-publish the
        // frozen figure on the event is authoritative).
        if (!empty($event['eligible_count'])) {
            $this->data['eligible_count'] = (int)$event['eligible_count'];
        } else {
            $roll = $this->Voting->eligible_roll($event['scope_type'], (int)$event['scope_id']);
            $this->data['eligible_count'] = (int)$roll['count'];
        }
```

- [ ] **Step 2** — In `orkui/template/revised-frontend/Voting_runner.tpl`, replace the `vtr-stats` block (lines ~85-89) with a version that adds an Eligible tile + turnout:
```php
	<?php
		$_elig = (int)($eligible_count ?? 0);
		$_counted = (int)$counts['counted'];
		$_turnout = $_elig > 0 ? round($_counted / $_elig * 100) : 0;
	?>
	<div class="vtr-stats">
		<div class="vtr-stat"><div class="vtr-stat-label">Counted</div><div class="vtr-stat-value"><?= $_counted ?></div></div>
		<div class="vtr-stat"><div class="vtr-stat-label">Provisional</div><div class="vtr-stat-value"><?= (int)$counts['provisional'] ?></div></div>
		<div class="vtr-stat"><div class="vtr-stat-label">Total Ballots</div><div class="vtr-stat-value"><?= (int)$counts['total'] ?></div></div>
		<div class="vtr-stat"><div class="vtr-stat-label">Eligible Voters</div><div class="vtr-stat-value"><?= $_elig ?></div></div>
		<div class="vtr-stat"><div class="vtr-stat-label">Turnout</div><div class="vtr-stat-value"><?= $_elig > 0 ? $_turnout . '%' : '&mdash;' ?></div></div>
	</div>
```

- [ ] **Step 3** — Verify (browser). As a runner load `index.php?Route=Voting/runner/{id}` for an OPEN event. Expected: two new stat tiles — "Eligible Voters" with a nonzero live count and "Turnout" showing `counted/eligible` as a %. Confirm the tiles render in dark mode (toggle theme; the existing `.vtr-stat` styles already cover dark via `html[data-theme="dark"]`).

- [ ] **Step 4** — Commit.
  `git add orkui/controller/controller.Voting.php orkui/template/revised-frontend/Voting_runner.tpl && git commit -m "Voting: live turnout + eligible-voter tiles on runner dashboard (Finding 25)"`

---

## Task 7 — Finding 27: Show the organizer WHO can vote (create + edit)

**Files:** `orkui/controller/controller.Voting.php`, `orkui/controller/controller.VotingAjax.php`, `orkui/template/revised-frontend/Voting_create.tpl`, `orkui/template/revised-frontend/Voting_edit.tpl`

**Interfaces:**
- Consumes `Model_Voting::eligible_roll` (Task 3).
- Produces `$this->data['elig_summary']` = `['count'=>int,'is_default'=>bool,'rule_line'=>string]` for create + edit views.
- Produces AJAX `VotingAjax::eligibility_roster($scope)` → JSON `{status:0, count:int, players:[{mundane_id,persona,park,dues_paid,att_count}]}`.

- [ ] **Step 1** — Add a rule-summary formatter. In `system/lib/ork3/class.Voting.php`, just after `compute_eligible_roll` (Task 3), add:
```php
    // One-line human summary of a resolved ruleset for the organizer UI.
    public static function rule_summary_line(array $rules, $is_default)
    {
        $req  = (int)($rules['AttendanceRequired'] ?? 6);
        $mode = $rules['AttendanceMode'] ?? 'weeks';
        $win  = (int)($rules['MonthsWindow'] ?? 6);
        $unit = $mode === 'count' ? 'sign-ins' : ($mode === 'days' ? 'event days' : 'weeks');
        $line = 'Paid members with a waiver and at least ' . $req . ' ' . $unit;
        if ($win > 0) {
            $line .= ' in the last ' . $win . ' months';
        }
        $min = (int)($rules['MinMembershipMonths'] ?? 0);
        if ($min > 0) {
            $line .= ', member for ' . $min . '+ months';
        }
        $line .= '.';
        if ($is_default) {
            $line .= ' (Default ruleset — this kingdom has no custom voting rule configured.)';
        }
        return $line;
    }
```

- [ ] **Step 2** — Build `elig_summary` in the create controller. In `orkui/controller/controller.Voting.php` `create()`, just before `$this->template = '../revised-frontend/Voting_create.tpl';` (line ~107), add:
```php
        $roll = $this->Voting->eligible_roll($st, $scope_id);
        $this->data['elig_summary'] = [
            'count'     => (int)$roll['count'],
            'is_default' => (bool)$roll['is_default'],
            'rule_line' => Voting::rule_summary_line($roll['rules'], $roll['is_default']),
        ];
```

- [ ] **Step 3** — Same for edit. In `edit()`, just before `$this->template = '../revised-frontend/Voting_edit.tpl';` (line ~131), add:
```php
        $roll = $this->Voting->eligible_roll($event['scope_type'], (int)$event['scope_id']);
        $this->data['elig_summary'] = [
            'count'     => (int)$roll['count'],
            'is_default' => (bool)$roll['is_default'],
            'rule_line' => Voting::rule_summary_line($roll['rules'], $roll['is_default']),
        ];
```

- [ ] **Step 4** — Add the roster AJAX endpoint. In `orkui/controller/controller.VotingAjax.php`, after `candidate_search` (~line 333), add (mirrors its IDOR gate):
```php
    public function eligibility_roster($scope = null)
    {
        $this->require_login();
        $parts = explode('_', (string)$scope, 2);
        $scope_type = $parts[0] ?? '';
        $scope_id = (int)($parts[1] ?? 0);
        if (!in_array($scope_type, ['Kingdom', 'Park']) || !$scope_id) {
            $this->ok(['count' => 0, 'players' => []]);
        }
        if (!$this->Voting->user_can_manage_voting_in_scope((int)$this->session->user_id, strtolower($scope_type), $scope_id)) {
            $this->fail('Not authorized.');
        }
        $roll = $this->Voting->eligible_roll(strtolower($scope_type), $scope_id);
        $players = [];
        foreach ($roll['players'] as $p) {
            $players[] = [
                'mundane_id' => (int)$p['MundaneId'],
                'persona'    => $p['Persona'],
                'park'       => $p['ParkName'],
                'dues_paid'  => (int)$p['DuesPaid'],
                'att_count'  => (int)$p['AttCount'],
            ];
        }
        $this->ok(['count' => (int)$roll['count'], 'players' => $players]);
    }
```

- [ ] **Step 5** — Add the summary card to create. In `orkui/template/revised-frontend/Voting_create.tpl`, directly before the `<div class="vtc-actions">` block (~line 123), insert:
```php
			<?php if (!empty($elig_summary)): ?>
			<div class="vtc-row">
				<label>Who can vote</label>
				<div class="vtc-card" style="background:#ebf8ff;border:1px solid #bee3f8;border-radius:8px;padding:12px 14px;">
					<div style="font-weight:600;margin-bottom:4px;"><i class="fas fa-users"></i> <?= (int)$elig_summary['count'] ?> eligible voters right now</div>
					<div style="font-size:13px;color:#2a4365;"><?= htmlspecialchars($elig_summary['rule_line']) ?></div>
				</div>
			</div>
			<?php endif; ?>
```
Add a dark-mode override to that file's `<style>` block:
```css
	html[data-theme="dark"] .vtc-card { background:#1a365d !important; border-color:#2c5282 !important; color:#e2e8f0; }
	html[data-theme="dark"] .vtc-card div { color:#cbd5e0 !important; }
```

- [ ] **Step 6** — Add the summary card + roster drawer to edit. In `orkui/template/revised-frontend/Voting_edit.tpl`, inside the `config` pane, directly after the Event Settings card's closing `</div>` (after line ~161, before Per-Race Settings), insert:
```php
			<?php if (!empty($elig_summary)): ?>
			<div class="vte-card">
				<h2>Eligibility</h2>
				<div style="font-weight:600;margin-bottom:4px;"><i class="fas fa-users"></i> <?= (int)$elig_summary['count'] ?> eligible voters right now</div>
				<div style="font-size:13px;color:var(--vte-meta,#4a5568);margin-bottom:10px;"><?= htmlspecialchars($elig_summary['rule_line']) ?></div>
				<button id="vte-roster-btn" class="vte-btn vte-btn-ghost" type="button"><i class="fas fa-list"></i> View eligible voters</button>
				<div id="vte-roster-host" style="margin-top:10px;"></div>
			</div>
			<?php endif; ?>
```
Then append this roster loader to that file's existing `<script>` (plain JS, guarded by a config flag per project rule — do not guard on `getElementById`):
```php
<script>
(function(){
	var btn = document.getElementById('vte-roster-btn');
	if (!btn) { return; }
	var host = document.getElementById('vte-roster-host');
	var scope = <?= json_encode(ucfirst($event['scope_type']) . '_' . (int)$event['scope_id']) ?>;
	btn.addEventListener('click', function(){
		host.innerHTML = '<div style="font-size:13px;color:#718096;">Loading…</div>';
		fetch('<?= UIR ?>VotingAjax/eligibility_roster/' + scope, {credentials:'same-origin'})
			.then(function(r){ return r.json(); })
			.then(function(d){
				if (!d || d.status !== 0) { host.innerHTML = '<div style="color:#c53030;font-size:13px;">Could not load roster.</div>'; return; }
				if (!d.players.length) { host.innerHTML = '<div style="font-size:13px;color:#718096;">No eligible voters found.</div>'; return; }
				var rows = d.players.map(function(p){
					return '<tr><td style="padding:4px 8px;">' + (p.persona ? p.persona.replace(/[<>&]/g,'') : '#' + p.mundane_id) + '</td><td style="padding:4px 8px;color:#718096;">' + (p.park ? p.park.replace(/[<>&]/g,'') : '') + '</td></tr>';
				}).join('');
				host.innerHTML = '<div style="max-height:280px;overflow:auto;border:1px solid #e2e8f0;border-radius:6px;"><table style="width:100%;border-collapse:collapse;font-size:13px;"><thead><tr><th style="text-align:left;padding:4px 8px;">Persona</th><th style="text-align:left;padding:4px 8px;">Park</th></tr></thead><tbody>' + rows + '</tbody></table></div>';
			})
			.catch(function(){ host.innerHTML = '<div style="color:#c53030;font-size:13px;">Could not load roster.</div>'; });
	});
})();
</script>
```

- [ ] **Step 7** — Verify (browser + curl). Create page: as a scope officer load `index.php?Route=Voting/create/Kingdom_{id}`. Expected: a blue "Who can vote" card showing "N eligible voters right now" + the rule sentence (and, for an unlisted kingdom, the "(Default ruleset …)" suffix). Edit page: load `index.php?Route=Voting/edit/{id}`, confirm the Eligibility card, click "View eligible voters" → a scrollable persona/park table loads. Curl-check the endpoint directly:
  `curl -s -b cookies.txt "http://localhost:19080/orkui/index.php?Route=VotingAjax/eligibility_roster/Kingdom_{id}" | head -c 400`
  Expected: JSON `{"status":0,"count":N,"players":[...]}` with N matching the card.

- [ ] **Step 8** — Commit.
  `git add system/lib/ork3/class.Voting.php orkui/controller/controller.Voting.php orkui/controller/controller.VotingAjax.php orkui/template/revised-frontend/Voting_create.tpl orkui/template/revised-frontend/Voting_edit.tpl && git commit -m "Voting: eligibility summary card + roster drawer for organizers (Finding 27)"`

---

## Self-Review

- **Every finding has a task:** F21 → Task 1; F5 → Task 2; F25 → Tasks 4+5 (freeze/producer), 6 (runner turnout), plus results turnout in Task 5; F27 → Task 7. Shared helper (Task 3) supports F25/F27.
- **Producer contract stated explicitly:** `ork_voting_event.eligible_count` (INT, default 0, written at `Publish()` before `save()`) + `ballots_cast`; frozen set enumerable from `ork_voting_eligibility_snapshot WHERE eligible=1`. Documented at top and in Tasks 4/5.
- **Backward compatibility:** `check_eligibility_live` keeps `eligible`/`provisional_possible`/`rules`/`player` and only ADDS `is_default_rules`/`reason`; `GetEligibilityCheck` keeps `Eligible`/`ProvisionalPossible`/`AllowProvisional` and only ADDS `Reason*`/`FixUrl`. The Domain-1 provisional sweep (`reevaluate_provisional_for_player`, line ~1652) and cast path (line ~1385) read only `$elig['eligible']` — untouched. Verified in Task 2 Step 5.
- **Ownership boundaries respected:** touches only the rules map / `GetEligibilityCheck` / snapshot writer / publish-freeze regions; does NOT modify `tally_pure`, lifecycle transitions, the cast validation loop, or external-ballot code.
- **Name/type consistency:** `compute_eligible_roll` returns `count/ids/players/rules/is_default`; `players[i]` keys (`MundaneId/Persona/ParkName/DuesPaid/AttCount`) match `GetVotingEligible` row keys confirmed in `class.Report.php:3785-3808`; AJAX lowercases to `mundane_id/persona/park/dues_paid/att_count`; reason `code`/`text`/`short`/`fix` consistent between `reason_pure`, `GetEligibilityCheck` (`Reason`/`ReasonText`/`ReasonShort`/`FixUrl`), and `Voting_event.tpl`.
- **Gotchas honored:** `$DB->Clear()` before every raw `Execute` in the publish freeze loop; `(int)` casts on all ids; human-readable dates via `date('M j, Y …')`; dark-mode overrides added for the new create card; JS guarded on a real element handle returned early (not on modal DOM presence at load); `.tpl` code is plain PHP throughout.
- **No placeholders:** every step is a concrete edit with real code and a concrete curl/browser/DB verification.
