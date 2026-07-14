# External / Paper Ballots Implementation Plan
> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Finish the runner "Enter External Votes" flow so a runner can open a real ballot for a scope-eligible voter and submit it, with an eligibility-attestation override, an explicit overwrite confirmation when it would replace a voter's own online ballot, a voter notification, and a co-runner-visible roster.

**Architecture:** The runner picks a voter (existing scoped `kn-ac-results` search on the External tab), clicks **Open Ballot**, and a modal fetches the event's races/choices plus the voter's current ballot/eligibility state from a new `VotingAjax/external_ballot_form` read endpoint. The modal renders the same vote widgets the voter page uses and POSTs to the existing `VotingAjax/external_ballot` action, which forwards to `Voting::CastBallot`. `CastBallot` gains two runner-only request flags: `OverwriteConfirm` (hard-required before superseding a voter's *electronic* ballot) and `AttestEligibility`+`AttestReason` (lets the runner attest a door-verified voter who the live eligibility check rejects). A voter whose online ballot was replaced sees a dismissible banner on the Playernew dashboard; co-runners/scope officers see an "External ballots entered" roster on the runner dashboard (audit remains admin-only, so this is the non-admin visibility surface).

**Tech Stack:** PHP 8 / MariaDB / plain-PHP templates / inline JS + kn-ac-results playersearch

## Global Constraints
- `.tpl` files are PLAIN PHP — use `<?php ?>`/`<?= ?>`, never Smarty `{$var}`/`{if}`.
- `mysql_real_escape_string()` is a no-op shim — `(int)`-cast every id; regex-validate any string used in SQL.
- yapo drops `null` from UPDATE/INSERT — assign `''` (not `null`) to clear a column.
- Always `$DB->Clear()` before a raw `Execute`/`DataSet`; `$DB->DataSet()` needs a manual `->Next()` before reading fields.
- Controller actions read the session via `$this->session->user_id` / `$this->session->token`, never `$this->__session`.
- Player search: custom `kn-ac-results` dropdown only (never jQuery UI), scoped to the event scope, `&q=` (not `?q=`), with `tnFixedAcPosition(input,dropdown)` defined on the page. The existing External-tab search already satisfies this (scoped `VotingAjax/voter_search/{id}&q=`); do not regress it.
- No native `confirm()`/`alert()`/`prompt()` — use the page's `pnConfirm(...)` helper (already loaded in `Voting_runner.tpl`) for confirmations.
- Dark mode: every new UI surface must style `html[data-theme="dark"]`; the modal reuses `--vtr-*` CSS vars already themed in this template.
- **CSRF dependency (Security domain, finding 29):** every `VotingAjax` POST touched or added here (`external_ballot`, new `ack_paper_notice`) MUST send the `X-CSRF-Token` header (mirror the `window.CMS_CSRF`/`CmsAjax` pattern) once finding 29 lands. Each task that adds a POST fetch notes this; wire the header when the Security task merges.

## Cross-domain coordination
- This domain OWNS the `external_ballot`/paper-ballot cast path in `class.Voting.php` (`CastBallot` runner-entry branch, `~:1356-1364, 1382-1391, 1438-1555`) and the External-votes tab in `Voting_runner.tpl` (`~:110-124, 316-320`). Do NOT touch the tally engine, lifecycle transitions, the eligibility rules map, or the voter's own cast path — other domains own those.
- The eligibility-attestation override (finding 10) calls the eligibility check owned by the Eligibility domain (Domain 3) **read-only**. Do not modify eligibility sources; pass an explicit "runner attests" flag and branch on the returned result only. A new `runner_eligibility_preview()` read helper wraps the existing private `check_eligibility_live()` — a read, not a rule change.

---

## File Structure

| File | Responsibility |
| --- | --- |
| `db-migrations/2026-07-13-voting-external-ballots.sql` (NEW) | Adds `runner_notice_ack_at DATETIME NULL` to `ork_voting_ballot` for the dismissible "paper replaced your online ballot" banner. |
| `system/lib/ork3/class.Voting.php` | `CastBallot`: overwrite-confirm gate + eligibility-attestation override + richer audit detail. New reads: `runner_eligibility_preview()`, `external_ballots_roster()`, `paper_replacement_notices()`, `ack_paper_notice()`. |
| `orkui/model/model.Voting.php` | Thin pass-throughs for the new lib reads/writes. |
| `orkui/controller/controller.VotingAjax.php` | `external_ballot`: forward `OverwriteConfirm`/`AttestEligibility`/`AttestReason`; return `confirm_required`. New actions: `external_ballot_form`, `external_roster`, `ack_paper_notice`. `banner`: append paper-replacement notices. |
| `orkui/template/revised-frontend/Voting_runner.tpl` | Replace the stub Open-Ballot handler with a real ballot modal, an overwrite-confirm modal, an attest-eligibility checkbox, and an "External ballots entered" roster in the External pane. |
| `orkui/template/revised-frontend/Playernew_index.tpl` | Render the dismissible paper-replacement notice from the extended `VotingAjax/banner` payload. |

---

## Task 1 — Migration: ack column for the paper-replacement notice

**Files:** `db-migrations/2026-07-13-voting-external-ballots.sql` (NEW)

**Interfaces:**
- Produces: column `ork_voting_ballot.runner_notice_ack_at DATETIME NULL` (NULL = not yet acknowledged by the voter).

- [ ] **Step 1** — Create `db-migrations/2026-07-13-voting-external-ballots.sql` with exactly:
```sql
-- Voting: dismissible "a paper ballot replaced your online ballot" notice.
-- NULL = voter has not dismissed the banner yet. Set to NOW() when the voter dismisses.
ALTER TABLE `ork_voting_ballot`
    ADD COLUMN `runner_notice_ack_at` DATETIME NULL DEFAULT NULL AFTER `superseded_by_ballot_id`;
```
- [ ] **Step 2** — Apply the migration to the local DB (MariaDB client, not mysql):
```bash
docker exec -i ork3-php8-db mariadb -u root -proot ork < db-migrations/2026-07-13-voting-external-ballots.sql
```
- [ ] **Step 3** — Verify the column exists:
```bash
docker exec -i ork3-php8-db mariadb -u root -proot ork -e "SHOW COLUMNS FROM ork_voting_ballot LIKE 'runner_notice_ack_at';"
```
Expected: one row naming `runner_notice_ack_at`, type `datetime`, Null `YES`.
- [ ] **Step 4** — Commit:
```bash
git add db-migrations/2026-07-13-voting-external-ballots.sql && git commit -m "Voting: add runner_notice_ack_at for paper-replacement notice"
```

---

## Task 2 — Service: overwrite-confirm gate + eligibility attestation in `CastBallot`

**Files:** `system/lib/ork3/class.Voting.php`

**Interfaces:**
- Consumes (new optional `$request` keys, honored ONLY when `$is_runner_entry` is true):
  - `OverwriteConfirm` (0|1) — required to supersede a voter's own *electronic* active ballot.
  - `AttestEligibility` (0|1) — runner attests door-verified eligibility.
  - `AttestReason` (string) — free-text reason recorded in the attestation audit row.
- Produces:
  - On confirm needed: `ProcessingError('has_online_ballot', 'confirm_required')` (Status≠0, `Error='confirm_required'`, `Detail='has_online_ballot'`) — transaction rolled back, no ballot written.
  - On success: unchanged `Success($new_ballot_id)`.
  - Audit rows: existing `ballot_runner_entered` / `ballot_replaced_by_paper`, plus a new `ballot_eligibility_attested` row (action string; `voting_audit.action` is `varchar(64)`, free-form) when the runner attested.

- [ ] **Step 1** — Read `system/lib/ork3/class.Voting.php` around lines 1356–1391 and 1435–1584 to anchor the edits (already normalized/tabbed).
- [ ] **Step 2** — Replace the eligibility block (currently lines ~1382–1391) to add the attest override. Find:
```php
        // Eligibility check.
        $elig = $this->check_eligibility_live($voter_mundane_id, $this->Event->scope_type, $this->Event->scope_id);
        $is_provisional = 0;
        if (!$elig['eligible']) {
            if (!empty($this->Event->allow_provisional) && $elig['provisional_possible']) {
                $is_provisional = 1;
            } else {
                return ProcessingError('', 'Not eligible to vote in this event.');
            }
        }
```
Replace with:
```php
        // Eligibility check. (Read-only — the Eligibility domain owns the rules map.)
        $elig = $this->check_eligibility_live($voter_mundane_id, $this->Event->scope_type, $this->Event->scope_id);
        $is_provisional = 0;
        // Runner attestation: a runner keying a door-verified paper ballot may attest eligibility the
        // live check can't confirm (lapsed dues not yet recorded, unlogged attendance, etc.). Honored
        // only on runner entry; recorded with a reason in the audit trail.
        $attested_eligibility = $is_runner_entry && !empty($request['AttestEligibility']);
        $attest_reason = $attested_eligibility ? trim((string)($request['AttestReason'] ?? '')) : '';
        if (!$elig['eligible']) {
            if ($attested_eligibility) {
                // Runner attests: count as eligible, non-provisional.
                $is_provisional = 0;
            } elseif (!empty($this->Event->allow_provisional) && $elig['provisional_possible']) {
                $is_provisional = 1;
            } else {
                return ProcessingError('', 'Not eligible to vote in this event.');
            }
        }
```
- [ ] **Step 3** — Add the overwrite-confirm gate immediately after the `FOR UPDATE` read of the prior ballot. Find:
```php
        $rs = $DB->DataSet("SELECT voting_ballot_id FROM " . DB_PREFIX . "voting_active_ballot
			WHERE voting_event_id = " . $voting_event_id . " AND voter_mundane_id = " . $voter_mundane_id . " FOR UPDATE");
        $prior_ballot_id = ($rs && $rs->Next()) ? (int)$rs->voting_ballot_id : null;
```
Replace with:
```php
        $rs = $DB->DataSet("SELECT voting_ballot_id FROM " . DB_PREFIX . "voting_active_ballot
			WHERE voting_event_id = " . $voting_event_id . " AND voter_mundane_id = " . $voter_mundane_id . " FOR UPDATE");
        $prior_ballot_id = ($rs && $rs->Next()) ? (int)$rs->voting_ballot_id : null;

        // Overwrite-confirm gate: a runner-entered paper ballot may NOT silently supersede a voter's
        // own electronic ballot. Require an explicit OverwriteConfirm; otherwise roll back and signal
        // the UI to show the "Replace with paper?" confirmation. (Replacing a prior *paper* ballot —
        // entered_by_runner_id NOT NULL — is a routine correction and does not require this gate.)
        $prior_is_electronic = false;
        if ($is_runner_entry && $prior_ballot_id) {
            $DB->Clear();
            $prs = $DB->DataSet("SELECT entered_by_runner_id FROM " . DB_PREFIX . "voting_ballot WHERE voting_ballot_id = " . (int)$prior_ballot_id);
            $prior_is_electronic = ($prs && $prs->Next() && $prs->entered_by_runner_id === null);
            if ($prior_is_electronic && empty($request['OverwriteConfirm'])) {
                $DB->Clear();
                $DB->Execute("ROLLBACK");
                $DB->Clear();
                return ProcessingError('has_online_ballot', 'confirm_required');
            }
        }
```
- [ ] **Step 4** — Enrich the final audit detail so the roster/audit can distinguish attested + online-replacement entries. Find:
```php
        $this->audit(
            $voting_event_id,
            $action,
            ['ballot_id' => $new_ballot_id, 'voter_mundane_id' => $voter_mundane_id, 'is_provisional' => $is_provisional, 'prior_ballot_id' => $prior_ballot_id],
            $actor_mundane_id
        );

        return Success($new_ballot_id);
```
Replace with:
```php
        $this->audit(
            $voting_event_id,
            $action,
            ['ballot_id' => $new_ballot_id, 'voter_mundane_id' => $voter_mundane_id, 'is_provisional' => $is_provisional,
                'prior_ballot_id' => $prior_ballot_id, 'replaced_online_ballot' => ($prior_is_electronic ? 1 : 0),
                'attested_eligibility' => ($attested_eligibility ? 1 : 0)],
            $actor_mundane_id
        );
        if ($attested_eligibility) {
            $this->audit(
                $voting_event_id,
                'ballot_eligibility_attested',
                ['ballot_id' => $new_ballot_id, 'voter_mundane_id' => $voter_mundane_id, 'reason' => $attest_reason],
                $actor_mundane_id
            );
        }

        return Success($new_ballot_id);
```
Note: `$prior_is_electronic` is defined in Step 3's block, which runs before this audit in all paths.
- [ ] **Step 5** — Lint the file (must parse):
```bash
docker exec -i ork3-php8-app php -l system/lib/ork3/class.Voting.php
```
Expected: `No syntax errors detected`.
- [ ] **Step 6** — Commit:
```bash
git add system/lib/ork3/class.Voting.php && git commit -m "Voting: overwrite-confirm gate + runner eligibility attestation in CastBallot"
```

---

## Task 3 — Service reads: eligibility preview, roster, notices, ack

**Files:** `system/lib/ork3/class.Voting.php`

**Interfaces:**
- Produces (all `public`):
  - `runner_eligibility_preview($voting_event_id, $voter_mundane_id): array` → `['eligible'=>bool,'provisional_possible'=>bool]` (read-only wrapper over `check_eligibility_live`).
  - `external_ballots_roster($voting_event_id): array` → rows `['voting_ballot_id'=>int,'voter_mundane_id'=>int,'voter_label'=>string,'runner_label'=>string,'submitted_at'=>string,'is_provisional'=>int,'replaced_online'=>int]` (voter identity blanked to `'(anonymous)'` when the event is `anonymous_to_runner`).
  - `paper_replacement_notices($voter_mundane_id): array` → rows `['voting_ballot_id'=>int,'voting_event_id'=>int,'title'=>string,'replaced_at'=>string]` for active runner-entered ballots that superseded this voter's electronic ballot and have `runner_notice_ack_at IS NULL`.
  - `ack_paper_notice($voter_mundane_id, $voting_ballot_id): bool` → sets `runner_notice_ack_at = NOW()` on the voter's own active ballot; returns whether a row was updated.

- [ ] **Step 1** — Read lines ~218–284 of `class.Voting.php` to match the existing read-helper style (`ballot_counts`, `audit_log`) and place the new methods near them.
- [ ] **Step 2** — Add `runner_eligibility_preview` (place it right after `check_eligibility_live`, i.e. after line ~106):
```php
    // Read-only eligibility preview for a runner about to key an external ballot for another member.
    // Wraps the private live check; the Eligibility domain owns the underlying rules. Source:
    // controller.VotingAjax.php::external_ballot_form.
    public function runner_eligibility_preview($voting_event_id, $voter_mundane_id)
    {
        global $DB;
        $DB->Clear();
        $rs = $DB->DataSet("SELECT scope_type, scope_id FROM " . DB_PREFIX . "voting_event WHERE voting_event_id = " . (int)$voting_event_id . " LIMIT 1");
        if (!$rs || !$rs->Next()) {
            return ['eligible' => false, 'provisional_possible' => false];
        }
        $elig = $this->check_eligibility_live((int)$voter_mundane_id, $rs->scope_type, (int)$rs->scope_id);
        return ['eligible' => !empty($elig['eligible']), 'provisional_possible' => !empty($elig['provisional_possible'])];
    }
```
- [ ] **Step 3** — Add `external_ballots_roster` (place after `ballot_counts`, ~line 270). It reads the *active* ballots that were runner-entered, joins voter + runner names, and flags rows that superseded an electronic ballot:
```php
    // Roster of currently-active external (runner-entered) ballots for an event, for co-runner /
    // scope-officer visibility (the audit log is admin-only). Respects anonymous_to_runner by
    // blanking voter identity. Source: controller.VotingAjax.php::external_roster.
    public function external_ballots_roster($voting_event_id)
    {
        global $DB;
        $DB->Clear();
        $ev = $DB->DataSet("SELECT anonymous_to_runner FROM " . DB_PREFIX . "voting_event WHERE voting_event_id = " . (int)$voting_event_id . " LIMIT 1");
        $anon = ($ev && $ev->Next() && (int)$ev->anonymous_to_runner === 1);

        $DB->Clear();
        $rs = $DB->DataSet("SELECT b.voting_ballot_id, b.voter_mundane_id, b.entered_by_runner_id, b.submitted_at, b.is_provisional,
				vm.persona AS voter_persona, vm.username AS voter_username,
				rm.persona AS runner_persona, rm.username AS runner_username,
				EXISTS(SELECT 1 FROM " . DB_PREFIX . "voting_ballot pb
					WHERE pb.superseded_by_ballot_id = b.voting_ballot_id AND pb.entered_by_runner_id IS NULL) AS replaced_online
			FROM " . DB_PREFIX . "voting_active_ballot ab
			JOIN " . DB_PREFIX . "voting_ballot b ON b.voting_ballot_id = ab.voting_ballot_id
			LEFT JOIN " . DB_PREFIX . "mundane vm ON vm.mundane_id = b.voter_mundane_id
			LEFT JOIN " . DB_PREFIX . "mundane rm ON rm.mundane_id = b.entered_by_runner_id
			WHERE ab.voting_event_id = " . (int)$voting_event_id . "
			  AND b.entered_by_runner_id IS NOT NULL
			ORDER BY b.submitted_at DESC, b.voting_ballot_id DESC");
        $rows = [];
        while ($rs && $rs->Next()) {
            $voter_label = $anon ? '(anonymous)' : ((string)($rs->voter_persona ?: $rs->voter_username ?: ('#' . (int)$rs->voter_mundane_id)));
            $runner_label = (string)($rs->runner_persona ?: $rs->runner_username ?: ('#' . (int)$rs->entered_by_runner_id));
            $rows[] = [
                'voting_ballot_id' => (int)$rs->voting_ballot_id,
                'voter_mundane_id' => $anon ? 0 : (int)$rs->voter_mundane_id,
                'voter_label' => $voter_label,
                'runner_label' => $runner_label,
                'submitted_at' => (string)$rs->submitted_at,
                'is_provisional' => (int)$rs->is_provisional,
                'replaced_online' => (int)$rs->replaced_online,
            ];
        }
        return $rows;
    }
```
- [ ] **Step 4** — Add `paper_replacement_notices` and `ack_paper_notice` (place after the roster method):
```php
    // Dismissible notices for a voter whose active ballot is a runner-entered paper ballot that
    // superseded their own electronic ballot and has not yet been acknowledged. Source:
    // controller.VotingAjax.php::banner.
    public function paper_replacement_notices($voter_mundane_id)
    {
        global $DB;
        $DB->Clear();
        $rs = $DB->DataSet("SELECT b.voting_ballot_id, b.voting_event_id, b.submitted_at AS replaced_at, e.title
			FROM " . DB_PREFIX . "voting_active_ballot ab
			JOIN " . DB_PREFIX . "voting_ballot b ON b.voting_ballot_id = ab.voting_ballot_id
			JOIN " . DB_PREFIX . "voting_event e ON e.voting_event_id = b.voting_event_id
			WHERE ab.voter_mundane_id = " . (int)$voter_mundane_id . "
			  AND b.entered_by_runner_id IS NOT NULL
			  AND b.runner_notice_ack_at IS NULL
			  AND EXISTS(SELECT 1 FROM " . DB_PREFIX . "voting_ballot pb
				WHERE pb.superseded_by_ballot_id = b.voting_ballot_id AND pb.entered_by_runner_id IS NULL)
			ORDER BY b.submitted_at DESC");
        $rows = [];
        while ($rs && $rs->Next()) {
            $rows[] = [
                'voting_ballot_id' => (int)$rs->voting_ballot_id,
                'voting_event_id' => (int)$rs->voting_event_id,
                'title' => (string)$rs->title,
                'replaced_at' => (string)$rs->replaced_at,
            ];
        }
        return $rows;
    }

    // Voter dismisses a paper-replacement notice. Scoped to the voter's OWN active ballot so one
    // member cannot ack another's. Source: controller.VotingAjax.php::ack_paper_notice.
    public function ack_paper_notice($voter_mundane_id, $voting_ballot_id)
    {
        global $DB;
        $DB->Clear();
        $DB->Execute("UPDATE " . DB_PREFIX . "voting_ballot b
			JOIN " . DB_PREFIX . "voting_active_ballot ab ON ab.voting_ballot_id = b.voting_ballot_id
			SET b.runner_notice_ack_at = NOW()
			WHERE b.voting_ballot_id = " . (int)$voting_ballot_id . "
			  AND ab.voter_mundane_id = " . (int)$voter_mundane_id . "
			  AND b.runner_notice_ack_at IS NULL");
        $DB->Clear();
        $chk = $DB->DataSet("SELECT runner_notice_ack_at FROM " . DB_PREFIX . "voting_ballot WHERE voting_ballot_id = " . (int)$voting_ballot_id . " LIMIT 1");
        return (bool)($chk && $chk->Next() && $chk->runner_notice_ack_at !== null);
    }
```
- [ ] **Step 5** — Lint:
```bash
docker exec -i ork3-php8-app php -l system/lib/ork3/class.Voting.php
```
Expected: `No syntax errors detected`.
- [ ] **Step 6** — Commit:
```bash
git add system/lib/ork3/class.Voting.php && git commit -m "Voting: external-ballot roster, paper-replacement notices, eligibility preview reads"
```

---

## Task 4 — Model pass-throughs

**Files:** `orkui/model/model.Voting.php`

**Interfaces:**
- Produces model methods forwarding to the Task 3 lib reads and the `get_event` shape reused by the ballot form.

- [ ] **Step 1** — Read `orkui/model/model.Voting.php` lines ~130–180 to match the pass-through style (some call `$this->Voting->ApiMethod([...])`, dashboard reads call `$this->Voting->method(args)` directly).
- [ ] **Step 2** — Add these methods after `ballot_counts` (~line 173):
```php
    public function runner_eligibility_preview($voting_event_id, $voter_mundane_id)
    {
        return $this->Voting->runner_eligibility_preview($voting_event_id, $voter_mundane_id);
    }
    public function external_ballots_roster($voting_event_id)
    {
        return $this->Voting->external_ballots_roster($voting_event_id);
    }
    public function paper_replacement_notices($voter_mundane_id)
    {
        return $this->Voting->paper_replacement_notices($voter_mundane_id);
    }
    public function ack_paper_notice($voter_mundane_id, $voting_ballot_id)
    {
        return $this->Voting->ack_paper_notice($voter_mundane_id, $voting_ballot_id);
    }
```
- [ ] **Step 3** — Lint:
```bash
docker exec -i ork3-php8-app php -l orkui/model/model.Voting.php
```
Expected: `No syntax errors detected`.
- [ ] **Step 4** — Commit:
```bash
git add orkui/model/model.Voting.php && git commit -m "Voting: model pass-throughs for external-ballot reads"
```

---

## Task 5 — Controller: ballot-form read, roster read, ack, and external_ballot flags

**Files:** `orkui/controller/controller.VotingAjax.php`

**Interfaces:**
- Produces:
  - `external_ballot_form($voting_event_id)` — GET; runner-gated; requires `?...&VoterMundaneId=`. Returns `{status:0, races:[...], has_active:0|1, active_is_electronic:0|1, eligible:0|1, provisional_possible:0|1}`. `races` is the `get_event` races array with withdrawn choices filtered (same as the voter page).
  - `external_roster($voting_event_id)` — GET; runner-gated. Returns `{status:0, roster:[...]}` from `external_ballots_roster`.
  - `ack_paper_notice($voting_ballot_id)` — POST; self-only. Returns `{status:0}`.
- Modifies:
  - `external_ballot($voting_event_id)` — forward `OverwriteConfirm`, `AttestEligibility`, `AttestReason` from the request into `cast_ballot`; on `confirm_required` the existing `fail()` returns `error:'confirm_required'` to the UI.

- [ ] **Step 1** — Read `controller.VotingAjax.php` lines 143–180 (`external_ballot`) and 335–349 (`voter_search`) to anchor edits.
- [ ] **Step 2** — In `external_ballot`, add the three flags to the `cast_ballot` request array. Find:
```php
        $r = $this->Voting->cast_ballot([
            'Token' => $this->session->token,
            'VotingEventId' => $voting_event_id,
            'VoterMundaneId' => $voter_id,
            'EnteredByRunnerId' => (int)$this->session->user_id,
            'Votes' => $votes,
        ]);
```
Replace with:
```php
        $r = $this->Voting->cast_ballot([
            'Token' => $this->session->token,
            'VotingEventId' => $voting_event_id,
            'VoterMundaneId' => $voter_id,
            'EnteredByRunnerId' => (int)$this->session->user_id,
            'OverwriteConfirm' => !empty($this->request->OverwriteConfirm) ? 1 : 0,
            'AttestEligibility' => !empty($this->request->AttestEligibility) ? 1 : 0,
            'AttestReason' => (string)($this->request->AttestReason ?? ''),
            'Votes' => $votes,
        ]);
```
Note: this POST must carry the `X-CSRF-Token` header once finding 29 (Security) lands; the modal fetch in Task 6 wires it.
- [ ] **Step 3** — Add `external_ballot_form` immediately after the `external_ballot` method (after line ~180). It reuses `get_event` and filters withdrawn choices exactly like `controller.Voting::event`:
```php
    public function external_ballot_form($voting_event_id = null)
    {
        $this->require_login();
        $voting_event_id = (int)$voting_event_id;
        if (!$this->Voting->user_is_runner_of_event((int)$this->session->user_id, $voting_event_id)) {
            $this->fail('Not authorized to enter external ballots.');
        }
        $voter_id = (int)$this->request->VoterMundaneId;
        if (!$voter_id) {
            $this->fail('Voter required.');
        }
        $r = $this->Voting->get_event($voting_event_id);
        if (($r['Status'] ?? 1) != 0) {
            $this->fail('Event not found.');
        }
        $event = $r['Event'];
        if (($event['status'] ?? '') !== 'open') {
            $this->fail('Voting is not open.');
        }
        // Hide withdrawn choices from the entry UI (same rule as the voter page).
        foreach ($event['races'] as &$_race) {
            if (!empty($_race['choices'])) {
                $_race['choices'] = array_values(array_filter($_race['choices'], fn ($c) => empty($c['withdrawn_at'])));
            }
        }
        unset($_race);

        $active = $this->Voting->active_ballot_for_voter($voting_event_id, $voter_id);
        $active_is_electronic = ($active && ($active['entered_by_runner_id'] ?? null) === null) ? 1 : 0;
        $elig = $this->Voting->runner_eligibility_preview($voting_event_id, $voter_id);

        $this->ok([
            'races' => array_values($event['races']),
            'has_active' => $active ? 1 : 0,
            'active_is_electronic' => $active_is_electronic,
            'eligible' => !empty($elig['eligible']) ? 1 : 0,
            'provisional_possible' => !empty($elig['provisional_possible']) ? 1 : 0,
        ]);
    }

    public function external_roster($voting_event_id = null)
    {
        $this->require_login();
        $voting_event_id = (int)$voting_event_id;
        if (!$this->Voting->user_is_runner_of_event((int)$this->session->user_id, $voting_event_id)) {
            $this->fail('Not authorized.');
        }
        $this->ok(['roster' => $this->Voting->external_ballots_roster($voting_event_id)]);
    }

    public function ack_paper_notice($voting_ballot_id = null)
    {
        $this->require_login();
        $voting_ballot_id = (int)$voting_ballot_id;
        $ok = $this->Voting->ack_paper_notice((int)$this->session->user_id, $voting_ballot_id);
        $this->ok(['acked' => $ok ? 1 : 0]);
    }
```
Note: `ack_paper_notice` is a POST mutation — add the `X-CSRF-Token` header when finding 29 lands.
- [ ] **Step 4** — Lint:
```bash
docker exec -i ork3-php8-app php -l orkui/controller/controller.VotingAjax.php
```
Expected: `No syntax errors detected`.
- [ ] **Step 5** — Verify the form endpoint end-to-end (auth via curl, one cookie jar). First log in and capture the cookie jar, then pick an OPEN event id + an eligible voter mundane_id from the DB, then hit the endpoint. Substitute real ids:
```bash
# Login (bypass accepts any password); reuse cookies.txt for all calls.
curl -s -c /tmp/vc.txt -b /tmp/vc.txt "http://localhost:19080/orkui/index.php?Route=Login/login" \
  --data "Username=<a-runner-username>&Password=x" >/dev/null
# Find an open event + a member in scope:
docker exec -i ork3-php8-db mariadb -u root -proot ork -e \
  "SELECT voting_event_id, scope_type, scope_id, status FROM ork_voting_event WHERE status='open' LIMIT 5;"
# Fetch the ballot form:
curl -s -b /tmp/vc.txt "http://localhost:19080/orkui/index.php?Route=VotingAjax/external_ballot_form/<EVENT_ID>&VoterMundaneId=<VOTER_ID>"
```
Expected: JSON `{"status":0,"races":[...],"has_active":..., "eligible":...}`. `races` non-empty for an event with races.
- [ ] **Step 6** — Commit:
```bash
git add orkui/controller/controller.VotingAjax.php && git commit -m "Voting: external ballot-form/roster/ack endpoints + confirm/attest flags"
```

---

## Task 6 — Runner tab: real ballot modal, overwrite confirm, attest, roster

**Files:** `orkui/template/revised-frontend/Voting_runner.tpl`

**Interfaces:**
- Consumes: `VotingAjax/external_ballot_form/{id}&VoterMundaneId=`, `VotingAjax/external_ballot/{id}` (POST), `VotingAjax/external_roster/{id}`.
- Produces: a working "Enter External Votes" flow — the stub message at lines ~316–320 is removed.

- [ ] **Step 1** — Read `Voting_runner.tpl` lines 110–124 (External pane markup) and 274–320 (search + stub handler). Confirm `.tpl` is plain PHP (`<?= ?>`), and that `pnConfirm` is available (used at lines 332/355).
- [ ] **Step 2** — Replace the External pane markup (lines ~110–124) to add a modal host and a roster host. Find the whole `<div class="vtr-pane" data-pane="external"> ... </div>` block and replace with:
```php
	<div class="vtr-pane" data-pane="external">
		<div class="vtr-card">
			<h2>Enter External Votes</h2>
			<div class="vtr-banner vtr-banner-info">Enter votes received outside of ORK voting (e.g., paper ballots collected at events). The voter must already have an ORK record.</div>
			<div style="display:flex;gap:8px;align-items:flex-start;">
				<div style="flex:1;position:relative;">
					<input id="vtr-ext-input" type="text" placeholder="Search a player..." autocomplete="off" style="width:100%;padding:10px 12px;font-size:14px;border:1px solid var(--vtr-card-border,#cbd5e0);border-radius:6px;box-sizing:border-box;background:var(--vtr-card-bg,#fff);color:var(--vtr-text,#1a202c);" />
					<input id="vtr-ext-id" type="hidden" />
					<div id="vtr-ext-results" class="kn-ac-results"></div>
				</div>
				<button id="vtr-ext-go" class="vtr-btn" disabled>Open Ballot</button>
			</div>
			<div id="vtr-ext-msg" style="margin-top:10px;"></div>
		</div>
		<div class="vtr-card" style="margin-top:14px;">
			<h2>External Ballots Entered</h2>
			<div id="vtr-ext-roster"><div class="vtr-empty">Loading…</div></div>
		</div>
	</div>

	<!-- External-ballot entry modal -->
	<div id="vtr-ext-modal" style="display:none;position:fixed;inset:0;z-index:1000;background:rgba(0,0,0,0.5);align-items:flex-start;justify-content:center;overflow:auto;padding:40px 16px;">
		<div style="background:var(--vtr-card-bg,#fff);color:var(--vtr-text,#1a202c);border:1px solid var(--vtr-card-border,#cbd5e0);border-radius:10px;max-width:640px;width:100%;padding:20px;box-shadow:0 10px 40px rgba(0,0,0,0.3);">
			<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:6px;">
				<h2 style="margin:0;" id="vtr-ext-modal-title">Enter Paper Ballot</h2>
				<button id="vtr-ext-modal-x" class="vtr-btn" style="padding:4px 10px;">&times;</button>
			</div>
			<div id="vtr-ext-modal-sub" style="font-size:13px;color:#718096;margin-bottom:10px;"></div>
			<div id="vtr-ext-attest" style="display:none;margin-bottom:12px;"></div>
			<form id="vtr-ext-form"><div id="vtr-ext-races"></div></form>
			<div id="vtr-ext-modal-msg" style="margin-top:10px;"></div>
			<div style="display:flex;gap:8px;justify-content:flex-end;margin-top:14px;">
				<button id="vtr-ext-cancel" class="vtr-btn">Cancel</button>
				<button id="vtr-ext-submit" class="vtr-btn vtr-btn-success">Submit Ballot</button>
			</div>
		</div>
	</div>
```
- [ ] **Step 3** — Replace the stub Open-Ballot handler (lines ~316–320). Find:
```php
	if (extBtn) extBtn.addEventListener('click', function(){
		var vid = parseInt(extId.value, 10);
		if (!vid) return;
		extMsg.innerHTML = '<div class="vtr-banner vtr-banner-info">External ballot entry is in stub form for the prototype. The voter you selected (id ' + escapeHtml(String(vid)) + ') would receive a runner-keyed ballot. Full UI lands in a follow-up.</div>';
	});
```
Replace with the real flow (fetches the form, renders race widgets, handles attest + overwrite-confirm + submit):
```php
	var extModal = $('#vtr-ext-modal');
	var extRacesHost = $('#vtr-ext-races');
	var extAttestHost = $('#vtr-ext-attest');
	var extModalMsg = $('#vtr-ext-modal-msg');
	var extModalSub = $('#vtr-ext-modal-sub');
	var extVoterId = null, extVoterLabel = '', extActiveElectronic = false;

	function closeExtModal(){ extModal.style.display = 'none'; extRacesHost.innerHTML = ''; extAttestHost.style.display='none'; extAttestHost.innerHTML=''; extModalMsg.innerHTML=''; }
	if ($('#vtr-ext-modal-x')) $('#vtr-ext-modal-x').addEventListener('click', closeExtModal);
	if ($('#vtr-ext-cancel')) $('#vtr-ext-cancel').addEventListener('click', closeExtModal);

	function renderExtRace(race){
		var rid = parseInt(race.voting_race_id,10);
		var choices = (race.choices||[]);
		var isIrv = (race.race_type === 'position' && race.voting_mode === 'irv' && choices.length > 1);
		var isConfidence = (race.race_type === 'position' && choices.length === 1);
		var h = '<div class="vtv-race" data-race-id="'+rid+'" data-race-type="'+escapeHtml(race.race_type)+'" data-voting-mode="'+escapeHtml(race.voting_mode||'')+'" data-irv="'+(isIrv?'1':'0')+'" style="padding:12px 0;border-bottom:1px solid var(--vtr-card-border,#e2e8f0);">';
		h += '<div style="font-weight:600;margin-bottom:8px;">'+escapeHtml(race.title||'')+'</div>';
		if (isIrv) {
			h += '<div class="vtv-irv-list">';
			choices.forEach(function(c){ h += '<label class="vtv-irv-item" data-choice-id="'+parseInt(c.voting_choice_id,10)+'" style="display:block;padding:4px 0;"><input type="checkbox" class="vtv-irv-cb" value="'+parseInt(c.voting_choice_id,10)+'" /> '+escapeHtml(c.label||'')+'</label>'; });
			h += '</div><div style="font-size:11px;color:#718096;">Check candidates in preference order (first checked = 1st choice).</div>';
			if (race.allow_abstain) h += '<label style="display:block;margin-top:6px;"><input type="checkbox" class="vtv-abstain-cb" /> Abstain this race</label>';
		} else if (isConfidence) {
			h += '<label style="display:block;"><input type="radio" name="r_'+rid+'" value="'+parseInt(choices[0].voting_choice_id,10)+'" /> Yes — confidence in '+escapeHtml(choices[0].label||'')+'</label>';
			h += '<label style="display:block;"><input type="radio" name="r_'+rid+'" value="no" /> No</label>';
			if (race.allow_abstain) h += '<label style="display:block;"><input type="radio" name="r_'+rid+'" value="abstain" /> Abstain</label>';
		} else {
			choices.forEach(function(c){ h += '<label style="display:block;"><input type="radio" name="r_'+rid+'" value="'+parseInt(c.voting_choice_id,10)+'" /> '+escapeHtml(c.label||'')+'</label>'; });
			if (race.allow_none_of_above) h += '<label style="display:block;"><input type="radio" name="r_'+rid+'" value="nota" /> None of the above</label>';
			if (race.allow_abstain) h += '<label style="display:block;"><input type="radio" name="r_'+rid+'" value="abstain" /> Abstain</label>';
		}
		h += '</div>';
		return h;
	}

	function buildExtVotes(){
		var votes = [];
		$$('.vtv-race', extRacesHost).forEach(function(race){
			var rid = parseInt(race.dataset.raceId,10);
			var isIrv = race.dataset.irv === '1';
			if (isIrv) {
				var abst = race.querySelector('.vtv-abstain-cb');
				if (abst && abst.checked) { votes.push({ VotingRaceId: rid, IsAbstain: 1 }); return; }
				var ids = $$('.vtv-irv-cb', race).filter(function(cb){ return cb.checked; }).map(function(cb){ return parseInt(cb.value,10); });
				votes.push({ VotingRaceId: rid, ChoiceIds: ids });
				return;
			}
			var sel = race.querySelector('input[type=radio]:checked');
			if (!sel) { votes.push({ VotingRaceId: rid, ChoiceIds: [] }); return; }
			if (sel.value === 'abstain') { votes.push({ VotingRaceId: rid, IsAbstain: 1 }); return; }
			if (sel.value === 'nota' || sel.value === 'no') { votes.push({ VotingRaceId: rid, IsNoneOfAbove: 1 }); return; }
			votes.push({ VotingRaceId: rid, ChoiceIds: [parseInt(sel.value,10)] });
		});
		return votes;
	}

	function submitExt(overwriteConfirm){
		var votes = buildExtVotes();
		var attestCb = extAttestHost.querySelector('#vtr-attest-cb');
		var attestReason = extAttestHost.querySelector('#vtr-attest-reason');
		var fd = new FormData();
		fd.append('VoterMundaneId', String(extVoterId));
		fd.append('Votes', JSON.stringify(votes));
		if (overwriteConfirm) fd.append('OverwriteConfirm', '1');
		if (attestCb && attestCb.checked) { fd.append('AttestEligibility', '1'); fd.append('AttestReason', attestReason ? attestReason.value : ''); }
		// NOTE: add X-CSRF-Token header here once finding 29 (Security) lands (window.CMS_CSRF pattern).
		fetch('<?= UIR ?>VotingAjax/external_ballot/' + eventId, { method:'POST', body:fd, credentials:'same-origin' })
			.then(r => r.json()).then(function(j){
				if (j.status === 0) {
					closeExtModal();
					extMsg.innerHTML = '<div class="vtr-banner vtr-banner-info">Paper ballot recorded for ' + escapeHtml(extVoterLabel) + '.</div>';
					extInput.value = ''; extId.value = ''; extBtn.disabled = true;
					loadExtRoster();
					return;
				}
				if (j.error === 'confirm_required') {
					pnConfirm({ title:'Replace online ballot?', message:extVoterLabel + ' already voted online. Recording this paper ballot will replace their electronic ballot and notify them. Continue?', confirmText:'Replace with paper', danger:true }, function(){ submitExt(true); });
					return;
				}
				extModalMsg.innerHTML = '<div class="vtr-banner vtr-banner-warn">' + escapeHtml(j.error || 'Failed') + (j.detail ? ': ' + escapeHtml(j.detail) : '') + '</div>';
			});
	}

	function openExtBallot(voterId, voterLabel){
		extVoterId = voterId; extVoterLabel = voterLabel;
		extModalMsg.innerHTML = ''; extRacesHost.innerHTML = '<div class="vtr-empty">Loading ballot…</div>';
		extAttestHost.style.display = 'none'; extAttestHost.innerHTML = '';
		extModalSub.textContent = 'For ' + voterLabel;
		extModal.style.display = 'flex';
		fetch('<?= UIR ?>VotingAjax/external_ballot_form/' + eventId + '&VoterMundaneId=' + encodeURIComponent(voterId), { credentials:'same-origin' })
			.then(r => r.json()).then(function(j){
				if (j.status !== 0) { extRacesHost.innerHTML = '<div class="vtr-banner vtr-banner-warn">' + escapeHtml(j.error || 'Failed') + '</div>'; return; }
				extActiveElectronic = j.active_is_electronic === 1;
				if (!j.races || !j.races.length) { extRacesHost.innerHTML = '<div class="vtr-empty">No races configured.</div>'; return; }
				extRacesHost.innerHTML = j.races.map(renderExtRace).join('');
				if (j.eligible !== 1) {
					extAttestHost.style.display = 'block';
					extAttestHost.innerHTML = '<div class="vtr-banner vtr-banner-warn" style="margin-bottom:6px;"><i class="fas fa-exclamation-triangle"></i> The system does not currently show this member as eligible.</div>'
						+ '<label style="display:block;"><input type="checkbox" id="vtr-attest-cb" /> I verified this member at the door and attest their eligibility.</label>'
						+ '<input type="text" id="vtr-attest-reason" placeholder="Reason (e.g., dues paid at door)" style="width:100%;margin-top:6px;padding:8px;border:1px solid var(--vtr-card-border,#cbd5e0);border-radius:6px;box-sizing:border-box;background:var(--vtr-card-bg,#fff);color:var(--vtr-text,#1a202c);" />';
				}
				if (extActiveElectronic) {
					var note = document.createElement('div');
					note.className = 'vtr-banner vtr-banner-info';
					note.style.marginTop = '4px';
					note.innerHTML = '<i class="fas fa-info-circle"></i> This member already voted online. Submitting will ask you to confirm replacing their electronic ballot.';
					extRacesHost.parentNode.insertBefore(note, extRacesHost);
				}
			});
	}

	var extForm = $('#vtr-ext-form');
	if (extForm) extForm.addEventListener('submit', function(e){ e.preventDefault(); submitExt(false); });
	if ($('#vtr-ext-submit')) $('#vtr-ext-submit').addEventListener('click', function(){ submitExt(false); });

	if (extBtn) extBtn.addEventListener('click', function(){
		var vid = parseInt(extId.value, 10);
		if (!vid) return;
		openExtBallot(vid, extInput.value.trim() || ('#' + vid));
	});

	function loadExtRoster(){
		var host = $('#vtr-ext-roster');
		if (!host) return;
		fetch('<?= UIR ?>VotingAjax/external_roster/' + eventId, { credentials:'same-origin' })
			.then(r => r.json()).then(function(j){
				if (j.status !== 0 || !j.roster || !j.roster.length) { host.innerHTML = '<div class="vtr-empty">No external ballots entered yet.</div>'; return; }
				var h = '<table style="width:100%;border-collapse:collapse;font-size:13px;"><thead><tr style="text-align:left;color:#718096;"><th style="padding:6px;">Voter</th><th style="padding:6px;">Entered by</th><th style="padding:6px;">When</th><th style="padding:6px;"></th></tr></thead><tbody>';
				j.roster.forEach(function(row){
					h += '<tr style="border-top:1px solid var(--vtr-card-border,#e2e8f0);">'
						+ '<td style="padding:6px;">' + escapeHtml(row.voter_label) + (row.is_provisional ? ' <span class="vtr-pill">provisional</span>' : '') + '</td>'
						+ '<td style="padding:6px;">' + escapeHtml(row.runner_label) + '</td>'
						+ '<td style="padding:6px;">' + escapeHtml(row.submitted_at) + '</td>'
						+ '<td style="padding:6px;">' + (row.replaced_online ? '<span class="vtr-pill vtr-pill-fail">replaced online ballot</span>' : '') + '</td>'
						+ '</tr>';
				});
				h += '</tbody></table>';
				host.innerHTML = h;
			}).catch(function(){});
	}
	loadExtRoster();
```
- [ ] **Step 4** — Verify no leftover stub text and the file is valid PHP:
```bash
grep -n "stub form for the prototype" orkui/template/revised-frontend/Voting_runner.tpl   # expect: no match
docker exec -i ork3-php8-app php -l orkui/template/revised-frontend/Voting_runner.tpl
```
Expected: grep prints nothing; lint prints `No syntax errors detected`.
- [ ] **Step 5** — Browser verify (runner dashboard). Log in as a scope officer/runner, open `http://localhost:19080/orkui/index.php?Route=Voting/runner/<OPEN_EVENT_ID>`, click **Enter External Votes**, search a member, click **Open Ballot**. Expected: a modal opens showing the event's races with selectable options (not the old stub banner); the roster card below shows "No external ballots entered yet." Fill a race, click **Submit Ballot**. Expected: modal closes, an info banner confirms the paper ballot, and the roster now lists the voter. Toggle dark mode (`html[data-theme="dark"]`) and confirm the modal + roster are legible.
- [ ] **Step 6** — Commit:
```bash
git add orkui/template/revised-frontend/Voting_runner.tpl && git commit -m "Voting: finish external-ballot entry modal + overwrite confirm + attest + roster"
```

---

## Task 7 — Voter notification banner on the Playernew dashboard

**Files:** `orkui/controller/controller.VotingAjax.php`, `orkui/template/revised-frontend/Playernew_index.tpl`

**Interfaces:**
- Modifies `VotingAjax/banner/{mundane_id}` to also return `notices` (from `paper_replacement_notices`): `{status:0, events:[...], notices:[{voting_ballot_id, voting_event_id, title, replaced_at}]}`.
- Consumes in `Playernew_index.tpl`: the `notices` array; POSTs `VotingAjax/ack_paper_notice/{ballotId}` on dismiss.

- [ ] **Step 1** — Read `controller.VotingAjax.php` lines 220–233 (`banner`).
- [ ] **Step 2** — Extend `banner` to include notices. Find:
```php
        $events = $this->Voting->active_for_voter($mundane_id);
        // Filter to those without an active ballot.
        $pending = array_values(array_filter($events, fn ($e) => empty($e['active_ballot_id']) || !empty($e['pending_revote'])));
        $this->ok(['events' => $pending]);
```
Replace with:
```php
        $events = $this->Voting->active_for_voter($mundane_id);
        // Filter to those without an active ballot.
        $pending = array_values(array_filter($events, fn ($e) => empty($e['active_ballot_id']) || !empty($e['pending_revote'])));
        $notices = $this->Voting->paper_replacement_notices($mundane_id);
        $this->ok(['events' => $pending, 'notices' => $notices]);
```
- [ ] **Step 3** — Read `Playernew_index.tpl` lines ~3694–3725 (the voting-banner JS that consumes `VotingAjax/banner`). Locate the `.then(...)` that builds `html` from `j.events` and appends it to `#pn-voting-banner`.
- [ ] **Step 4** — In that same `.then` callback, before/after the events loop, render notices. Insert (adapt to the exact surrounding variable names found in Step 3 — the host element is `#pn-voting-banner`, the accumulator is `html`):
```php
			(j.notices || []).forEach(function(n){
				html += '<div style="display:flex;align-items:center;gap:12px;padding:12px 16px;background:#c05621;color:#fff;border-radius:10px;margin-bottom:10px;">'
					+ '<i class="fas fa-file-signature" style="font-size:20px;"></i>'
					+ '<div style="flex:1;"><div style="font-weight:600;">A paper ballot replaced your online vote</div>'
					+ '<div style="font-size:13px;opacity:0.95;">An event runner recorded a paper ballot for you in "' + escapeHtml(n.title) + '", replacing the vote you cast online.</div></div>'
					+ '<button data-ack-ballot="' + parseInt(n.voting_ballot_id,10) + '" class="pn-ack-paper" style="background:rgba(255,255,255,0.2);border:none;color:#fff;border-radius:6px;padding:6px 10px;cursor:pointer;">Dismiss</button>'
					+ '</div>';
			});
```
- [ ] **Step 5** — After the banner `html` is written into the host and shown, wire the Dismiss buttons. Add (inside the same callback, after `host.innerHTML = html;` / the display toggle):
```php
			Array.prototype.forEach.call(host.querySelectorAll('.pn-ack-paper'), function(btn){
				btn.addEventListener('click', function(e){
					e.preventDefault(); e.stopPropagation();
					var bid = parseInt(btn.getAttribute('data-ack-ballot'),10);
					// NOTE: add X-CSRF-Token header here once finding 29 (Security) lands.
					fetch(PnConfig.uir + 'VotingAjax/ack_paper_notice/' + bid, { method:'POST', credentials:'same-origin' })
						.then(function(){ var w = btn.closest('div'); if (w && w.parentNode) w.parentNode.removeChild(w); });
				});
			});
```
Note: `escapeHtml` and `host` already exist in this block (used by the events rendering); reuse them. If the existing code guards `host.style.display` on `html` being non-empty, ensure notices count toward "non-empty" so the banner shows for a notice even with zero open events.
- [ ] **Step 6** — Lint the controller and confirm the template still parses:
```bash
docker exec -i ork3-php8-app php -l orkui/controller/controller.VotingAjax.php
docker exec -i ork3-php8-app php -l orkui/template/revised-frontend/Playernew_index.tpl
```
Expected: `No syntax errors detected` for both.
- [ ] **Step 7** — End-to-end verify the full replace→notify→dismiss cycle. Using the curl session from Task 5: (a) as the voter, cast an online ballot (`VotingAjax/cast/<EVENT_ID>` with a `Votes` payload); (b) as a runner, submit a paper ballot for that voter with `OverwriteConfirm=1`; (c) confirm the supersede + audit rows in the DB:
```bash
docker exec -i ork3-php8-db mariadb -u root -proot ork -e \
  "SELECT voting_ballot_id, voter_mundane_id, entered_by_runner_id, superseded_by_ballot_id, runner_notice_ack_at \
   FROM ork_voting_ballot WHERE voting_event_id=<EVENT_ID> AND voter_mundane_id=<VOTER_ID> ORDER BY voting_ballot_id;"
docker exec -i ork3-php8-db mariadb -u root -proot ork -e \
  "SELECT action, detail FROM ork_voting_audit WHERE voting_event_id=<EVENT_ID> ORDER BY voting_audit_id DESC LIMIT 5;"
```
Expected: the electronic ballot row has `superseded_by_ballot_id` = the new paper ballot's id and `entered_by_runner_id IS NULL`; the paper ballot has `entered_by_runner_id` = runner id; audit shows a `ballot_replaced_by_paper` row. Then hit the banner endpoint as the voter and confirm the notice appears:
```bash
curl -s -b /tmp/vc.txt "http://localhost:19080/orkui/index.php?Route=VotingAjax/banner/<VOTER_ID>"   # expect notices[] non-empty
curl -s -b /tmp/vc.txt -X POST "http://localhost:19080/orkui/index.php?Route=VotingAjax/ack_paper_notice/<PAPER_BALLOT_ID>"
curl -s -b /tmp/vc.txt "http://localhost:19080/orkui/index.php?Route=VotingAjax/banner/<VOTER_ID>"   # expect notices[] now empty
```
Also verify the confirm gate: repeat the paper submit WITHOUT `OverwriteConfirm` against a fresh online ballot and expect `{"status":1,"error":"confirm_required",...}` and NO new ballot row.
- [ ] **Step 8** — Commit:
```bash
git add orkui/controller/controller.VotingAjax.php orkui/template/revised-frontend/Playernew_index.tpl && git commit -m "Voting: notify voter when a paper ballot replaces their online ballot"
```

---

## Self-review checklist (must all hold before "done")
- [ ] Finding 34 (stub) → Tasks 5+6: the Open-Ballot handler renders a real ballot and submits through `external_ballot`; the "stub form for the prototype" string is gone; `Voting_index.tpl` promise (line 88) is now truthful (no code change needed — the tab works).
- [ ] Finding 10 (no override) → Task 2 attest branch + Task 5 flag forwarding + Task 6 attest checkbox/reason; eligibility check stays read-only (Domain 3 untouched); a `ballot_eligibility_attested` audit row is written.
- [ ] Finding 28 (forge/overwrite) → Task 2 confirm gate (`confirm_required` on replacing an electronic ballot) + Task 6 `pnConfirm` overwrite modal + Task 3/7 voter notification + Task 3/6 co-runner roster.
- [ ] Every id is `(int)`-cast in SQL; every raw `Execute`/`DataSet` is preceded by `$DB->Clear()`; every `DataSet` read calls `->Next()` first.
- [ ] No native `confirm/alert/prompt`; `pnConfirm` used for the overwrite modal.
- [ ] Dark mode styled via `--vtr-*` vars / `html[data-theme="dark"]` on the modal + roster + banner.
- [ ] Name/type consistency: `OverwriteConfirm`/`AttestEligibility`/`AttestReason` request keys, `runner_notice_ack_at` column, `external_ballot_form`/`external_roster`/`ack_paper_notice` routes, and the `notices[]`/`roster[]` JSON shapes match across service ↔ model ↔ controller ↔ template.

## Cross-domain dependency flagged
- **Security (finding 29 / CSRF):** the modified `VotingAjax/external_ballot` POST and the new `VotingAjax/ack_paper_notice` POST must send `X-CSRF-Token` (window.CMS_CSRF / CmsAjax pattern) once finding 29 lands. Both fetch sites carry an inline `NOTE:` marker to wire the header then.
