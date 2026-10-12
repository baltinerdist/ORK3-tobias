# Event Lifecycle & Scheduling Implementation Plan
> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Give runners a real "Close Voting Now" action and make attendance-qualified provisional ballots actually get released (lazily + at close + via a runner review panel) so an election can reach a published winner.

**Architecture:** `class.Voting.php` (DB/business layer, `system/lib/ork3/`) gains a runner-gated `CloseEvent()` and two read/maintenance helpers; `model.Voting.php` adds thin pass-throughs; `controller.VotingAjax.php` gets a `close_event` POST action and per-voter re-eval on the banner fetch; `controller.Voting.php::runner` runs a lazy `cycle_event_status()` sweep + feeds a provisional-review panel into `Voting_runner.tpl`. No cron entrypoint exists in this repo, so the sweep is wired to page loads (runner dashboard = full sweep + auto-close; voter banner = cheap single-player re-eval), which is the intended "lazy sweep on dashboard load."

**Tech Stack:** PHP 8 / MariaDB / plain-PHP .tpl templates / inline JS

## Global Constraints
- `.tpl` files are PLAIN PHP — use `<?php ?>`/`<?= ?>`, never `{$var}`/`{if}`.
- `mysql_real_escape_string()` is a NO-OP shim — `(int)`-cast ids; regex-validate strings. (All ids below are `(int)`-cast.)
- yapo drops `null` from UPDATE/INSERT — assign `''` (not null) to clear a column.
- Always `$DB->Clear()` before raw `Execute`/`DataSet`; `$DB->DataSet()` needs a manual `->Next()` before reading fields.
- Controller action methods read session via `$this->session->user_id`, NOT `$this->__session`.
- DB-layer work belongs in `system/lib/ork3/class.Voting.php`; `orkui/model/model.Voting.php` is a thin pass-through (one wrapper per lib method).
- No native `confirm()/alert()/prompt()` — use the existing `pnConfirm({...}, cb)` helper already used in `Voting_runner.tpl`.
- Dark mode selector is `html[data-theme="dark"]`; reuse the existing `.vtr-*` classes already defined in `Voting_runner.tpl`.
- Return-shape contract (global helpers in `orkservice/Common.definitions.php`): `Success($detail)` → `['Status'=>0,'Error'=>'','Detail'=>$detail]`; `ProcessingError($detail,$error)` → `['Status'=>non-zero,'Error'=>$error,'Detail'=>$detail]`; `NoAuthorization()`/`InvalidParameter()` likewise non-zero `Status`. Controllers test `($r['Status'] ?? 1) != 0`.

---

## File Structure

| File | Responsibility (this plan) |
|------|----------------------------|
| `system/lib/ork3/class.Voting.php` | New `CloseEvent()` (runner-gated open→closed + final sweep); new read `provisional_ballots()`; `TODO(finding-7)` marker in `sweep_provisional_eligibility()`. Existing `cycle_event_status()` / `reevaluate_provisional_for_player()` reused unchanged. |
| `orkui/model/model.Voting.php` | Thin pass-throughs: `close_event()`, `cycle_event_status()`, `reevaluate_provisional_for_player()`, `provisional_ballots()`. |
| `orkui/controller/controller.VotingAjax.php` | New `close_event()` POST action; per-voter re-eval call inside existing `banner()`. |
| `orkui/controller/controller.Voting.php` | `runner()` runs lazy `cycle_event_status()` before load + passes `provisional_ballots` into the view. |
| `orkui/template/revised-frontend/Voting_runner.tpl` | Wire the real `#vtr-close-now` button (replace stub); new Provisional Ballots review panel with per-row reason + Release. |

---

## Task 1: Service — `CloseEvent()` in class.Voting.php

**Files:**
- Modify `system/lib/ork3/class.Voting.php` — insert a new `CloseEvent()` method immediately after `cycle_event_status()` (which ends at line 1711) and before `event_races_valid_for_open()` (line 1717). Add the `TODO(finding-7)` marker inside `sweep_provisional_eligibility()` (lines 1660-1675).
- Verify: curl the new endpoint via Task 2's wiring — but this task's own verify runs the method through a one-off PHP eval.

**Interfaces:**
- Consumes: `Ork3::$Lib->authorization->IsAuthorized($token)`, `valid_id()`, `$this->user_is_runner_of_event($mundane_id,$voting_event_id)`, `$this->Event` (yapo model with `->clear()/->find()/->save()`), `$this->sweep_provisional_eligibility()`, `$this->audit($event_id,$action,$detail,$actor)`, global helpers `Success/ProcessingError/NoAuthorization/InvalidParameter`.
- Produces: `CloseEvent(array $request): array` — `$request['Token']`, `$request['VotingEventId']`. Returns `Success($voting_event_id)` on success; `ProcessingError('','Voting is not open.')` if status !== 'open'; auth/param errors otherwise.

- [ ] **Step 1: Add the `TODO(finding-7)` marker in `sweep_provisional_eligibility()`.** In `system/lib/ork3/class.Voting.php`, inside `sweep_provisional_eligibility()`, change the release loop (currently lines 1672-1674) from:
```php
        foreach ($ids as $mid) {
            $this->reevaluate_provisional_for_player($mid);
        }
```
to:
```php
        // TODO(finding-7): re-eval against each ballot's captured snapshot source_rules
        // rather than the live eligibility rules. Today this re-runs the CURRENT rules via
        // reevaluate_provisional_for_player(); the snapshot-accurate re-eval is a parked item.
        foreach ($ids as $mid) {
            $this->reevaluate_provisional_for_player($mid);
        }
```

- [ ] **Step 2: Insert the `CloseEvent()` method.** In `system/lib/ork3/class.Voting.php`, directly after the closing `}` of `cycle_event_status()` (line 1711) and before the `/**` doc-comment of `event_races_valid_for_open()` (line 1713), insert:
```php

    /**
     * Runner-initiated immediate close. Flips a single open event to closed and runs the
     * final provisional sweep so attendance-qualified provisional ballots are released and
     * counted before results are reviewed/published. Mirrors OpenEvent's auth + status gate.
     */
    public function CloseEvent($request)
    {
        $mundane_id = Ork3::$Lib->authorization->IsAuthorized($request['Token']);
        if (!valid_id($mundane_id)) {
            return NoAuthorization();
        }
        $voting_event_id = (int)($request['VotingEventId'] ?? 0);
        if (!$voting_event_id) {
            return InvalidParameter();
        }
        if (!$this->user_is_runner_of_event($mundane_id, $voting_event_id)) {
            return NoAuthorization();
        }

        $this->Event->clear();
        $this->Event->voting_event_id = $voting_event_id;
        if (!$this->Event->find()) {
            return InvalidParameter();
        }
        if ($this->Event->status !== 'open') {
            return ProcessingError('', 'Voting is not open.');
        }

        // Final sweep BEFORE flipping status: release any provisional ballot that now
        // qualifies (e.g. attendance recorded) so it counts in the closed tally.
        $this->sweep_provisional_eligibility();

        $this->Event->status = 'closed';
        $this->Event->save();
        $this->audit($voting_event_id, 'event_updated', ['status' => 'closed', 'manual' => true], $mundane_id);
        return Success($voting_event_id);
    }
```

- [ ] **Step 3: Verify the method loads (syntax) and gates correctly.** Run:
```bash
docker exec ork3-php8-app php -l /var/www/html/system/lib/ork3/class.Voting.php
```
Expected: `No syntax errors detected`. (End-to-end behavior is verified in Task 3 via the button.)

- [ ] **Step 4: Commit.**
```bash
git add system/lib/ork3/class.Voting.php && git commit -m "Voting: add runner-gated CloseEvent() with final provisional sweep (finding 20/24)"
```

---

## Task 2: Model + AJAX — `close_event` pass-through and POST action

**Files:**
- Modify `orkui/model/model.Voting.php` — add `close_event()` next to `unpublish()` (after line 95).
- Modify `orkui/controller/controller.VotingAjax.php` — add a `close_event()` action next to `publish()` (after line 275).
- Verify: curl the AJAX route.

**Interfaces:**
- Consumes: `$this->Voting->CloseEvent($request)` (Task 1); `$this->session->token`, `$this->session->user_id`; `$this->Voting->user_is_runner_of_event($uid,$eid)`.
- Produces: model `close_event(array $request): array` → forwards to `CloseEvent`. AJAX `close_event($voting_event_id)` → JSON `{"status":0}` on success or `{"status":1,"error":..,"detail":..}` via the controller's `fail()/ok()` helpers.

- [ ] **Step 1: Add the model pass-through.** In `orkui/model/model.Voting.php`, immediately after the `unpublish()` method (ends line 95), insert:
```php
    public function close_event($request)
    {
        return $this->Voting->CloseEvent($request);
    }
```

- [ ] **Step 2: Add the AJAX action.** In `orkui/controller/controller.VotingAjax.php`, immediately after the `publish()` method (ends line 275) and before `unpublish()`, insert:
```php
    public function close_event($voting_event_id = null)
    {
        $this->require_login();
        $voting_event_id = (int)$voting_event_id;
        // NOTE(finding-29): once the Security domain lands CSRF for VotingAjax, this POST
        // must send the X-CSRF-Token header (window.CMS_CSRF pattern) and _begin() will
        // validate it. Matches the existing publish/unpublish/reopen_event actions, which
        // are also not yet CSRF-guarded — do not diverge from them.
        if (!$this->Voting->user_is_runner_of_event((int)$this->session->user_id, $voting_event_id)) {
            $this->fail('Not authorized to close this event.');
        }
        $r = $this->Voting->close_event([
            'Token' => $this->session->token,
            'VotingEventId' => $voting_event_id,
        ]);
        if (($r['Status'] ?? 1) != 0) {
            $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
        }
        $this->ok();
    }
```

- [ ] **Step 3: Verify via curl.** Log in (bypass accepts any password) and hit the route against an OPEN event id (replace `123`):
```bash
curl -s -c /tmp/vt.jar "http://localhost:19080/orkui/index.php?Route=Login/login" --data "Username=<a-runner-username>&Password=x" -o /dev/null
curl -s -b /tmp/vt.jar -X POST "http://localhost:19080/orkui/index.php?Route=VotingAjax/close_event/123"
```
Expected on an open event: `{"status":0}`. Re-running it returns `{"status":1,"error":"Voting is not open.",...}` (already closed). A non-runner session returns `{"status":1,"error":"Not authorized to close this event."}`.

- [ ] **Step 4: Commit.**
```bash
git add orkui/model/model.Voting.php orkui/controller/controller.VotingAjax.php && git commit -m "Voting: wire close_event AJAX action + model pass-through (finding 20)"
```

---

## Task 3: Template — wire the real "Close Voting Now" button

**Files:**
- Modify `orkui/template/revised-frontend/Voting_runner.tpl` — replace the open-status banner copy (lines 130-135) and the stub `#vtr-close-now` handler (lines 340-344).
- Verify: browser click-path on the runner dashboard.

**Interfaces:**
- Consumes: `POST <?= UIR ?>VotingAjax/close_event/<eventId>` (Task 2); existing JS locals `eventId`, `$()`, `escapeHtml()`, and the global `pnConfirm()`.
- Produces: on success reloads the page (status now `closed`, so the Publish flow renders).

- [ ] **Step 1: Fix the open-status banner copy (no cron/end_date wording).** In `Voting_runner.tpl`, replace lines 130-135:
```php
				<?php if ($event['status'] === 'open'): ?>
					<div class="vtr-banner vtr-banner-warn">Voting is currently open. The event will close automatically at <?= htmlspecialchars(date('M j, Y g:i A', strtotime($event['end_date']))) ?>.</div>
					<div style="display:flex;gap:8px;flex-wrap:wrap;">
						<button id="vtr-close-now" class="vtr-btn vtr-btn-danger">Close Voting Now</button>
						<button id="vtr-reopen-config" class="vtr-btn"><i class="fas fa-pause"></i> Reopen Configuration</button>
					</div>
					<div id="vtr-reopen-msg" style="margin-top:8px;"></div>
```
with:
```php
				<?php if ($event['status'] === 'open'): ?>
					<div class="vtr-banner vtr-banner-warn">Voting is currently open. It closes on its own at <?= htmlspecialchars(date('M j, Y g:i A', strtotime($event['end_date']))) ?>, or you can close it now to review and publish results immediately.</div>
					<div style="display:flex;gap:8px;flex-wrap:wrap;">
						<button id="vtr-close-now" class="vtr-btn vtr-btn-danger">Close Voting Now</button>
						<button id="vtr-reopen-config" class="vtr-btn"><i class="fas fa-pause"></i> Reopen Configuration</button>
					</div>
					<div id="vtr-reopen-msg" style="margin-top:8px;"></div>
```

- [ ] **Step 2: Replace the stub click handler with a real close call.** In `Voting_runner.tpl`, replace the handler at lines 340-344:
```php
	var closeBtn = $('#vtr-close-now');
	if (closeBtn) closeBtn.addEventListener('click', function(){
		var m = $('#vtr-reopen-msg');
		if (m) m.innerHTML = '<div class="vtr-banner vtr-banner-info">To close immediately, set the event end_date to a past time. Status auto-flips on cron sweep or next page load.</div>';
	});
```
with:
```php
	var closeBtn = $('#vtr-close-now');
	if (closeBtn) closeBtn.addEventListener('click', function(){
		var m = $('#vtr-reopen-msg');
		pnConfirm({ title:'Close Voting Now?', message:'This ends voting immediately. Provisional ballots that now qualify are released and counted, then you can review and publish results. This cannot be undone (you would have to Reopen Configuration to change anything).', confirmText:'Close Voting', danger:true }, function(){
			closeBtn.disabled = true;
			fetch('<?= UIR ?>VotingAjax/close_event/' + eventId, { method:'POST', credentials:'same-origin' })
				.then(function(r){ return r.json(); })
				.then(function(j){
					if (j.status === 0) { location.reload(); return; }
					closeBtn.disabled = false;
					if (m) m.innerHTML = '<div class="vtr-banner vtr-banner-warn">' + escapeHtml(j.error || 'Failed') + (j.detail ? ': ' + escapeHtml(j.detail) : '') + '</div>';
				})
				.catch(function(){ closeBtn.disabled = false; if (m) m.innerHTML = '<div class="vtr-banner vtr-banner-warn">Network error.</div>'; });
		});
	});
```

- [ ] **Step 3: Verify in the browser.** Navigate to `http://localhost:19080/orkui/index.php?Route=Voting/runner/<openEventId>` as a runner, open the **Event Management** tab, click **Close Voting Now**, confirm in the dialog. Expected: page reloads, banner now reads "Voting has closed. Review results, then publish…" and a **Publish Results** button is present. Confirm no console errors and dark mode (toggle theme) keeps the banner/button readable.

- [ ] **Step 4: Commit.**
```bash
git add orkui/template/revised-frontend/Voting_runner.tpl && git commit -m "Voting: bind Close Voting Now button to real CloseEvent, drop cron/end_date copy (finding 20)"
```

---

## Task 4: Lazy auto-close + full provisional sweep on runner dashboard load

**Files:**
- Modify `orkui/model/model.Voting.php` — add `cycle_event_status()` pass-through (after the `close_event()` added in Task 2).
- Modify `orkui/controller/controller.Voting.php` — call the sweep at the top of `runner()` (before line 194 `get_event`).
- Verify: browser + curl.

**Interfaces:**
- Consumes: `$this->Voting->cycle_event_status()` (lib, no args, void) — auto-opens due drafts, runs `sweep_provisional_eligibility()` once, auto-closes events past `end_date`.
- Produces: side effect only. `runner()` re-reads the event AFTER the sweep so a just-auto-closed event renders the closed/publish UI.

- [ ] **Step 1: Add the model pass-through.** In `orkui/model/model.Voting.php`, after the `close_event()` method (added in Task 2), insert:
```php
    public function cycle_event_status()
    {
        return $this->Voting->cycle_event_status();
    }
```

- [ ] **Step 2: Run the sweep before loading the runner dashboard.** In `orkui/controller/controller.Voting.php::runner()`, the method currently begins (lines 190-194):
```php
    public function runner($voting_event_id = null)
    {
        $this->require_login();
        $voting_event_id = (int)$voting_event_id;
        $r = $this->Voting->get_event($voting_event_id);
```
Insert the sweep call between the `(int)` cast and the `get_event` read so the fetched event reflects any auto-close:
```php
    public function runner($voting_event_id = null)
    {
        $this->require_login();
        $voting_event_id = (int)$voting_event_id;
        // Lazy scheduler (no cron in this repo): auto-open due drafts, release provisional
        // ballots that now qualify, and auto-close events past end_date — so the dashboard a
        // runner opens is always current. cycle_event_status() runs the full sweep once.
        $this->Voting->cycle_event_status();
        $r = $this->Voting->get_event($voting_event_id);
```

- [ ] **Step 3: Verify auto-close.** Pick an OPEN event, set its `end_date` to the past directly in the DB, then load the dashboard:
```bash
docker exec -i ork3-php8-db mariadb -u root -proot ork -e "UPDATE ork_voting_event SET end_date = NOW() - INTERVAL 1 HOUR WHERE voting_event_id = 123;"
```
Then browse `http://localhost:19080/orkui/index.php?Route=Voting/runner/123`. Expected: dashboard renders with status **closed** and the Publish button (no manual click needed). Confirm the DB row flipped:
```bash
docker exec -i ork3-php8-db mariadb -u root -proot ork -e "SELECT status FROM ork_voting_event WHERE voting_event_id = 123;"
```
Expected: `closed`.

- [ ] **Step 4: Commit.**
```bash
git add orkui/model/model.Voting.php orkui/controller/controller.Voting.php && git commit -m "Voting: lazy cycle_event_status sweep + auto-close on runner dashboard load (finding 20/24)"
```

---

## Task 5: Per-voter provisional re-eval on banner fetch

**Files:**
- Modify `orkui/model/model.Voting.php` — add `reevaluate_provisional_for_player()` pass-through (after `cycle_event_status()` from Task 4).
- Modify `orkui/controller/controller.VotingAjax.php` — call it inside `banner()` (lines 220-233).
- Verify: attendance-qualification scenario.

**Interfaces:**
- Consumes: `$this->Voting->reevaluate_provisional_for_player($mundane_id)` (lib, void) — releases the caller's own provisional ballots on open events that now pass `check_eligibility_live`.
- Produces: side effect only; `banner()` still returns `{status:0, events:[...]}` unchanged.

- [ ] **Step 1: Add the model pass-through.** In `orkui/model/model.Voting.php`, after `cycle_event_status()` (Task 4), insert:
```php
    public function reevaluate_provisional_for_player($mundane_id)
    {
        return $this->Voting->reevaluate_provisional_for_player($mundane_id);
    }
```

- [ ] **Step 2: Re-eval the voter before building the banner.** In `controller.VotingAjax.php::banner()`, the body currently reads (lines 222-232):
```php
        $mundane_id = (int)$mundane_id;
        // Only allow self or admin.
        $uid = (int)$this->session->user_id;
        if ($mundane_id !== $uid && !Ork3::$Lib->authorization->HasAuthority($uid, AUTH_ADMIN, 0, AUTH_ADMIN)) {
            $this->fail('Not authorized.');
        }
        $events = $this->Voting->active_for_voter($mundane_id);
```
Insert the re-eval immediately after the auth gate, before `active_for_voter`:
```php
        $mundane_id = (int)$mundane_id;
        // Only allow self or admin.
        $uid = (int)$this->session->user_id;
        if ($mundane_id !== $uid && !Ork3::$Lib->authorization->HasAuthority($uid, AUTH_ADMIN, 0, AUTH_ADMIN)) {
            $this->fail('Not authorized.');
        }
        // Cheap single-player lazy sweep: the banner fetch fires on nearly every page load
        // (Playernew), so a voter who just became eligible via attendance has their own
        // provisional ballot released here — no cron and no runner action required.
        $this->Voting->reevaluate_provisional_for_player($mundane_id);
        $events = $this->Voting->active_for_voter($mundane_id);
```

- [ ] **Step 3: Verify the attendance path releases a ballot.** Find (or create) a provisional active ballot on an OPEN event whose voter qualifies only by attendance. Record the ballot state, then load any page as that voter (which fires `VotingAjax/banner/<uid>`), or hit it directly:
```bash
docker exec -i ork3-php8-db mariadb -u root -proot ork -e "SELECT voting_ballot_id,is_provisional,provisional_released_at FROM ork_voting_ballot WHERE voting_ballot_id = <bid>;"
curl -s -b /tmp/vt.jar "http://localhost:19080/orkui/index.php?Route=VotingAjax/banner/<uid>" -o /dev/null
docker exec -i ork3-php8-db mariadb -u root -proot ork -e "SELECT voting_ballot_id,is_provisional,provisional_released_at FROM ork_voting_ballot WHERE voting_ballot_id = <bid>;"
```
Expected: after the banner fetch, if the voter now passes eligibility, `is_provisional` flips `1`→`0` and `provisional_released_at` is set. (If the voter still does not qualify, the row is unchanged — that is correct.) Also confirm an audit row: `SELECT action FROM ork_voting_audit WHERE action='provisional_released_system' ORDER BY voting_audit_id DESC LIMIT 1;`.

- [ ] **Step 4: Commit.**
```bash
git add orkui/model/model.Voting.php orkui/controller/controller.VotingAjax.php && git commit -m "Voting: per-voter provisional re-eval on banner fetch (finding 24)"
```

---

## Task 6: Service read — `provisional_ballots()` list

**Files:**
- Modify `system/lib/ork3/class.Voting.php` — add `provisional_ballots()` read helper next to `ballot_counts()` (after line 268).
- Modify `orkui/model/model.Voting.php` — add pass-through next to `ballot_counts()` (after line 170).
- Verify: one-off DB comparison.

**Interfaces:**
- Consumes: `$DB->DataSet()` on `voting_active_ballot` ⋈ `voting_ballot` ⋈ `mundane`.
- Produces: `provisional_ballots(int $voting_event_id): array` — list of rows `['voting_ballot_id'=>int, 'voter_mundane_id'=>int, 'submitted_at'=>string, 'voter_name'=>string, 'username'=>string]`, oldest-first. Only CURRENTLY-active provisional ballots (joined via `voting_active_ballot`, so superseded ballots are excluded).

- [ ] **Step 1: Add the read helper.** In `system/lib/ork3/class.Voting.php`, immediately after `ballot_counts()` (ends line 268) and before the `// Audit rows…` comment (line 270), insert:
```php

    // Currently-active PROVISIONAL ballots for an event (runner review panel). Joined via
    // voting_active_ballot so superseded ballots are excluded. Source: finding 24.
    public function provisional_ballots($voting_event_id)
    {
        global $DB;
        $DB->Clear();
        $rs = $DB->DataSet("SELECT b.voting_ballot_id, b.voter_mundane_id, b.submitted_at,
            m.username, m.persona, m.given_name, m.surname
            FROM " . DB_PREFIX . "voting_active_ballot ab
            JOIN " . DB_PREFIX . "voting_ballot b ON b.voting_ballot_id = ab.voting_ballot_id
            LEFT JOIN " . DB_PREFIX . "mundane m ON m.mundane_id = b.voter_mundane_id
            WHERE ab.voting_event_id = " . (int)$voting_event_id . " AND b.is_provisional = 1
            ORDER BY b.submitted_at ASC, b.voting_ballot_id ASC");
        $rows = [];
        while ($rs && $rs->Next()) {
            $name = $rs->persona ?: trim(($rs->given_name ?? '') . ' ' . ($rs->surname ?? ''));
            if ($name === '') {
                $name = $rs->username ?? '';
            }
            $rows[] = [
                'voting_ballot_id' => (int)$rs->voting_ballot_id,
                'voter_mundane_id' => (int)$rs->voter_mundane_id,
                'submitted_at' => $rs->submitted_at,
                'voter_name' => $name,
                'username' => $rs->username ?? '',
            ];
        }
        return $rows;
    }
```

- [ ] **Step 2: Add the model pass-through.** In `orkui/model/model.Voting.php`, immediately after `ballot_counts()` (ends line 170), insert:
```php
    public function provisional_ballots($voting_event_id)
    {
        return $this->Voting->provisional_ballots($voting_event_id);
    }
```

- [ ] **Step 3: Verify the row set matches the DB.** Compare the helper output count against a direct query for an event with provisional ballots (replace `123`):
```bash
docker exec -i ork3-php8-db mariadb -u root -proot ork -e "SELECT COUNT(*) AS n FROM ork_voting_active_ballot ab JOIN ork_voting_ballot b ON b.voting_ballot_id=ab.voting_ballot_id WHERE ab.voting_event_id=123 AND b.is_provisional=1;"
docker exec ork3-php8-app php -l /var/www/html/system/lib/ork3/class.Voting.php
```
Expected: `No syntax errors detected`; the panel in Task 7 will render exactly that count of rows.

- [ ] **Step 4: Commit.**
```bash
git add system/lib/ork3/class.Voting.php orkui/model/model.Voting.php && git commit -m "Voting: provisional_ballots() read helper for runner review panel (finding 24)"
```

---

## Task 7: Runner provisional-review panel (controller data + template)

**Files:**
- Modify `orkui/controller/controller.Voting.php::runner()` — pass `provisional_ballots` into the view (after line 223 `ballot_counts`).
- Modify `orkui/template/revised-frontend/Voting_runner.tpl` — render a Provisional Ballots card inside the Event Management pane and add its Release JS.
- Verify: browser click-path.

**Interfaces:**
- Consumes: `$this->Voting->provisional_ballots($voting_event_id)` (Task 6); existing `POST <?= UIR ?>VotingAjax/release_provisional/<ballotId>` with body field `Reason` (already implemented — `VotingAjax::release_provisional` → `ReleaseProvisionalManual`, which REQUIRES a non-empty `Reason`).
- Produces: `$this->data['provisional_ballots']` (array from Task 6). Template variable `$provisional_ballots` consumed in `Voting_runner.tpl`.

- [ ] **Step 1: Feed the panel data from the controller.** In `controller.Voting.php::runner()`, after the counts line (line 223):
```php
        // Counts.
        $this->data['counts'] = $this->Voting->ballot_counts($voting_event_id);
```
add:
```php
        // Provisional ballots awaiting release (runner review panel, finding 24). Only
        // meaningful pre-publish; the template gates on status open/closed.
        $this->data['provisional_ballots'] = $this->Voting->provisional_ballots($voting_event_id);
```

- [ ] **Step 2: Guard the new template var at the top of the file.** In `Voting_runner.tpl`, the header block ends at line 7 (`if (!$event) { ... return; }`). Immediately after line 6 (`$is_admin = !empty($is_admin);`) add a default so the var is always defined:
```php
	$provisional_ballots = $provisional_ballots ?? [];
```

- [ ] **Step 3: Render the Provisional Ballots card inside the Event Management pane.** In `Voting_runner.tpl`, the manage pane's card ends at lines 154-156:
```php
				<?php elseif ($event['status'] === 'draft'): ?>
					<div class="vtr-banner vtr-banner-info">Event is in draft. <a href="<?= UIR ?>Voting/edit/<?= $voting_event_id ?>">Continue editing</a> to add races and open voting.</div>
				<?php endif; ?>
			</div>
```
Insert a second card AFTER that closing `</div>` (still inside `<div class="vtr-pane" data-pane="manage">`), before its closing `</div>` on line 156. Replace lines 154-156:
```php
				<?php elseif ($event['status'] === 'draft'): ?>
					<div class="vtr-banner vtr-banner-info">Event is in draft. <a href="<?= UIR ?>Voting/edit/<?= $voting_event_id ?>">Continue editing</a> to add races and open voting.</div>
				<?php endif; ?>
			</div>
```
with:
```php
				<?php elseif ($event['status'] === 'draft'): ?>
					<div class="vtr-banner vtr-banner-info">Event is in draft. <a href="<?= UIR ?>Voting/edit/<?= $voting_event_id ?>">Continue editing</a> to add races and open voting.</div>
				<?php endif; ?>
			</div>
			<?php if (in_array($event['status'], ['open','closed'], true)): ?>
			<div class="vtr-card">
				<h2>Provisional Ballots</h2>
				<div class="vtr-banner vtr-banner-info">These voters were provisional when they cast (e.g. dues not yet recorded). Any who now qualify are released automatically; use this panel to release one manually with a reason. Released ballots count in the tally.</div>
				<div id="vtr-prov-list">
					<?php if (empty($provisional_ballots)): ?>
						<div class="vtr-empty">No provisional ballots.</div>
					<?php else: ?>
						<?php foreach ($provisional_ballots as $pb): ?>
							<div class="vtr-bar" style="align-items:center;gap:10px;margin-bottom:8px;" data-ballot="<?= (int)$pb['voting_ballot_id'] ?>">
								<div style="flex:1;">
									<div style="font-weight:600;color:var(--vtr-text,#1a202c);"><?= htmlspecialchars($pb['voter_name']) ?> <span style="font-weight:400;color:var(--vtr-meta,#718096);">(<?= htmlspecialchars($pb['username']) ?>)</span></div>
									<div style="font-size:12px;color:var(--vtr-meta,#718096);">Cast <?= $pb['submitted_at'] ? htmlspecialchars(date('M j, Y g:i A', strtotime($pb['submitted_at']))) : '—' ?></div>
								</div>
								<input type="text" class="vtr-prov-reason" placeholder="Reason (required)" style="flex:0 0 200px;padding:6px 8px;font-size:13px;border:1px solid var(--vtr-card-border,#cbd5e0);border-radius:6px;background:var(--vtr-card-bg,#fff);color:var(--vtr-text,#1a202c);" />
								<button class="vtr-btn vtr-prov-release" data-ballot="<?= (int)$pb['voting_ballot_id'] ?>">Release</button>
							</div>
						<?php endforeach; ?>
					<?php endif; ?>
				</div>
				<div id="vtr-prov-msg" style="margin-top:8px;"></div>
			</div>
			<?php endif; ?>
```

- [ ] **Step 4: Add the Release JS.** In `Voting_runner.tpl`, inside the closing IIFE — immediately before the final `})();` (line 371) — insert:
```php
	$$('.vtr-prov-release').forEach(function(btn){
		btn.addEventListener('click', function(){
			var bid = parseInt(btn.dataset.ballot, 10);
			var row = btn.closest('[data-ballot]');
			var reasonInput = row ? $('.vtr-prov-reason', row) : null;
			var reason = reasonInput ? reasonInput.value.trim() : '';
			var msg = $('#vtr-prov-msg');
			if (!reason) {
				if (msg) msg.innerHTML = '<div class="vtr-banner vtr-banner-warn">Enter a reason before releasing.</div>';
				if (reasonInput) reasonInput.focus();
				return;
			}
			btn.disabled = true;
			var data = new FormData();
			data.append('Reason', reason);
			// NOTE(finding-29): add X-CSRF-Token header once the Security domain lands CSRF
			// for VotingAjax (window.CMS_CSRF pattern); mirrors publish/unpublish today.
			fetch('<?= UIR ?>VotingAjax/release_provisional/' + bid, { method:'POST', body:data, credentials:'same-origin' })
				.then(function(r){ return r.json(); })
				.then(function(j){
					if (j.status === 0) { if (row) row.remove(); if (msg) msg.innerHTML = '<div class="vtr-banner vtr-banner-info">Ballot released and counted.</div>'; return; }
					btn.disabled = false;
					if (msg) msg.innerHTML = '<div class="vtr-banner vtr-banner-warn">' + escapeHtml(j.error || 'Failed') + (j.detail ? ': ' + escapeHtml(j.detail) : '') + '</div>';
				})
				.catch(function(){ btn.disabled = false; if (msg) msg.innerHTML = '<div class="vtr-banner vtr-banner-warn">Network error.</div>'; });
		});
	});
```

- [ ] **Step 5: Verify in the browser.** Open `http://localhost:19080/orkui/index.php?Route=Voting/runner/<eventWithProvisionalBallots>` → **Event Management** tab. Expected: a **Provisional Ballots** card lists each provisional voter with a reason field + Release button. Click Release with an empty reason → inline "Enter a reason before releasing." Enter a reason and click Release → row disappears, "Ballot released and counted." Confirm in DB the ballot flipped and an audit row `provisional_released_runner` exists:
```bash
docker exec -i ork3-php8-db mariadb -u root -proot ork -e "SELECT is_provisional, provisional_released_by_mundane_id FROM ork_voting_ballot WHERE voting_ballot_id=<bid>; SELECT action, detail FROM ork_voting_audit WHERE action='provisional_released_runner' ORDER BY voting_audit_id DESC LIMIT 1;"
```
Toggle dark mode and confirm the card, inputs, and buttons remain readable.

- [ ] **Step 6: Commit.**
```bash
git add orkui/controller/controller.Voting.php orkui/template/revised-frontend/Voting_runner.tpl && git commit -m "Voting: runner provisional-review panel with one-click release + reason (finding 24)"
```

---

## Self-review checklist (completed at authoring)
- **Finding 20 → Tasks 1-4:** `CloseEvent()` (T1), model+AJAX wiring (T2), button bound with cron/end_date copy removed (T3), lazy `cycle_event_status()` auto-close on dashboard load (T4). ✔
- **Finding 24 → Tasks 1,4,5,6,7:** final sweep inside `CloseEvent` (T1) and inside lazy `cycle_event_status` (T4); per-voter re-eval on banner fetch (T5); `provisional_ballots()` read (T6); runner review panel with one-click release+reason (T7); `TODO(finding-7)` marker left in `sweep_provisional_eligibility()` (T1). ✔
- **No placeholders:** all code is literal; the existing `release_provisional` AJAX endpoint is reused verbatim (no new endpoint needed for release). ✔
- **Type/name consistency:** service `CloseEvent`/`provisional_ballots`; model `close_event`/`cycle_event_status`/`reevaluate_provisional_for_player`/`provisional_ballots`; AJAX `close_event`; view var `$provisional_ballots` (keys `voting_ballot_id`,`voter_mundane_id`,`submitted_at`,`voter_name`,`username`). Return shape `Status==0` ⇒ success throughout. ✔
- **Cross-domain:** did NOT rewrite tally engine, eligibility rules map, or cast path. Left `TODO(finding-7)` for snapshot-accurate re-eval. Flagged the `X-CSRF-Token` (finding-29 Security domain) dependency on the new `close_event` POST and on the panel's `release_provisional` POST, following the existing `window.CMS_CSRF`/publish-unpublish pattern. ✔
