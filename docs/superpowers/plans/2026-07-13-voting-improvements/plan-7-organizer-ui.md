# Organizer / Runner UI & Accessibility Implementation Plan
> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Make the runner dashboard and two-tab edit page usable and accessible — resolve a tied race in-app, delegate a runner, fix mobile results bars, correct tab semantics/contrast, and consolidate each race's settings beside its candidates.

**Architecture:** All UI lives in two plain-PHP templates (`Voting_runner.tpl`, `Voting_edit.tpl`) that render server data and drive `VotingAjax/*` endpoints via `fetch`. The tie-resolution backend (`ResolveTie`) and delegate-auth reads (`user_is_runner_of_event`, `user_can_run_in_scope`) already exist in `class.Voting.php`; this plan WIRES UI + thin AJAX to them and adds ONE minimal delegate-write backend (the only service change — flagged). Data flows controller → template `$data` → inline JS → `VotingAjax` → model pass-through → `class.Voting.php`.

**Tech Stack:** PHP 8 / plain-PHP templates / inline CSS+JS / kn-ac-results playersearch

## Global Constraints
- `.tpl` files are PLAIN PHP — use `<?php ?>`/`<?= ?>`, NEVER Smarty `{$var}`/`{if}`.
- FontAwesome 5.8.2 ONLY — never `fa-gauge-high`/`fa-pen-to-square`/`fa-*-to-*` (FA6, render blank). Use `fa-crown`, `fa-user-plus`, `fa-trophy`, `fa-times`, `fa-pencil-alt`, etc.
- Global h1–h6 get a gray pill box in orkui.css — any heading in a card/hero/modal MUST reset `background:transparent;border:none;padding:0;border-radius:0;text-shadow:none;` (both templates already do this for `h2`/`h3`; match it for any new heading).
- Tooltips = `data-tip` (never native `title=`); the wrap CSS already exists in `Voting_edit.tpl` (`white-space:normal;width:max-content;max-width:240px`); right-anchor Actions-column tips.
- Dark mode REQUIRED — selector `html[data-theme="dark"]`; every color you add needs a dark override.
- Player search MUST use the custom `kn-ac-results` dropdown (never jQuery UI), fetch with `&q=` (not `?q=`), min 2 chars, 150 ms debounce. The delegate search is INLINE (not in a modal), so mirror the existing `#vtr-ext-*` external-vote search in `Voting_runner.tpl` (no `tnFixedAcPosition` needed — that is only for autocompletes inside `position:fixed` modals). Scope it to the event via `VotingAjax/voter_search/{eventId}` (already scope- and auth-gated).
- No native `confirm()/alert()/prompt()` — use `pnConfirm({title,message,confirmText,danger}, cb)` (already used throughout both templates).
- revised.js IIFE guards: bind by class/`querySelector` inside the IIFE (both templates already run one big IIFE after the DOM markup — new handlers go in the SAME IIFE, so elements exist).
- yapo drops `null` from UPDATE/INSERT — never assign `null` to clear a column; use `''`. Delegate writes use raw `INSERT IGNORE`/`DELETE`, so `$DB->Clear()` MUST precede every raw `Execute`/`DataSet`.
- `(int)`-cast every id from the request; `mysql_real_escape_string()` is a no-op shim.
- **CSRF dependency (Security domain, finding 29):** `VotingAjax` currently has NO CSRF check; the Security domain will add one in `_begin()`. Every NEW mutating `fetch` in this plan attaches `X-CSRF-Token` guardedly (`window.VOTING_CSRF ? {'X-CSRF-Token': window.VOTING_CSRF} : {}`, mirroring the `window.CMS_CSRF` pattern). This is forward-compatible: harmless before Security lands, correct after.

---

## File Structure

| File | Responsibility |
|------|----------------|
| `orkui/template/revised-frontend/Voting_runner.tpl` | Runner dashboard. Findings 22 (Resolve-Tie UI in `renderTally`), 35e (Delegate Runner section), 13 (mobile bars CSS), 14 (tab ARIA/semantics), 15 (muted-text contrast). |
| `orkui/template/revised-frontend/Voting_edit.tpl` | Two-tab edit page. Finding 8 (per-race settings moved beside candidates; tab descriptions; Open Voting surfaced in both tabs). |
| `orkui/template/revised-frontend/Voting_event.tpl` | Voter-domain file — ONLY lines 13 & 22 muted-text token (finding 15), flagged for cross-domain merge. |
| `orkui/controller/controller.Voting.php` | `runner()` action passes `delegates` list + `can_delegate` flag to the template (finding 35d). |
| `orkui/controller/controller.VotingAjax.php` | NEW `add_delegate` / `remove_delegate` actions (finding 35c); `resolve_tie` already exists (no change). |
| `orkui/model/model.Voting.php` | NEW thin pass-throughs `add_delegate` / `remove_delegate` / `list_delegates` (finding 35b). |
| `system/lib/ork3/class.Voting.php` | NEW minimal `AddDelegate` / `RemoveDelegate` / `ListDelegates` (finding 35a). **ONLY service change in this domain — keep minimal, reuse existing auth; flag for lifecycle/service-domain review.** |

---

## Task 1 — Finding 15: Darken sub-AA muted body text

**Files:** `orkui/template/revised-frontend/Voting_runner.tpl`, `orkui/template/revised-frontend/Voting_event.tpl`

**Interfaces:** none (pure CSS/color). Consumes: nothing. Produces: readable muted text ≥ 4.5:1 on white.

`#718096` on `#fff` ≈ 4.0:1 (fails AA for 13 px). `#5a6472` on `#fff` ≈ 5.6:1 (passes). Dark-theme `#a0aec0` already passes on dark cards — leave it.

- [ ] **Step 1** In `Voting_runner.tpl` line 14, change `.vtr-sub { color:var(--vtr-meta,#718096); ...`  →  `color:var(--vtr-meta,#5a6472);`.
- [ ] **Step 2** In `Voting_runner.tpl` line 19, change `.vtr-stat-label { color:var(--vtr-meta,#718096); ...`  →  `color:var(--vtr-meta,#5a6472);`.
- [ ] **Step 3** In `Voting_runner.tpl` line 49, change `.vtr-empty { ... color:var(--vtr-meta,#718096); ...`  →  `color:var(--vtr-meta,#5a6472);`.
- [ ] **Step 4** In `Voting_runner.tpl` line 196 (JS `renderTally`), change the inline race-meta line `'<div style="font-size:12px;color:#718096;margin-bottom:8px;">'`  →  `color:#5a6472;`.
- [ ] **Step 5** In `Voting_runner.tpl` line 228 (JS, exhausted-ballots note), change `'<div style="font-size:11px;color:#718096;margin-top:4px;">'`  →  `color:#5a6472;`.
- [ ] **Step 6 — CROSS-DOMAIN (Voter domain owns this file)** In `Voting_event.tpl` line 13 and line 22, change each `#718096` muted-text color to `#5a6472`. Add a commit-message note that this touches the Voter domain's file for a shared token change; if a merge conflict arises, the Voter-domain owner keeps the `#5a6472` value.
- [ ] **Step 7 — Verify (curl):** `curl -s -b /tmp/vote.jar 'http://localhost:19080/orkui/index.php?Route=Voting/runner/1' | grep -c '#718096'` → expect `0` in `Voting_runner.tpl` output (the file no longer emits the old token except any dark-theme block that intentionally keeps `#a0aec0`).
- [ ] **Step 8 — Verify (browser):** Log in (see login recipe under Task 4), open `index.php?Route=Voting/runner/{openEventId}`. In LIGHT theme the "Counted/Provisional" stat labels and the sub-text under each race title read visibly darker. Toggle to dark theme (theme switch) → text still legible on dark cards.
- [ ] `git add orkui/template/revised-frontend/Voting_runner.tpl orkui/template/revised-frontend/Voting_event.tpl && git commit -m "Voting: darken sub-AA muted text to #5a6472 (finding 15)"`

---

## Task 2 — Finding 13: Live-results bars stack on a phone

**Files:** `orkui/template/revised-frontend/Voting_runner.tpl`

**Interfaces:** none (CSS media query). Consumes: existing `.vtr-bar`/`.vtr-bar-label`/`.vtr-bar-track`/`.vtr-bar-count`. Produces: a full-width bar under a stacked label at ≤ 480 px.

The fixed `flex:0 0 180px` label + `flex:0 0 60px` count leave ~80 px of bar on a 320 px screen. Below 480 px, stack the label above a full-width track and drop the count inline to the right of the label.

- [ ] **Step 1** In the `<style>` block of `Voting_runner.tpl` (immediately AFTER the `.vtr-bar-count` rule at line 34, before `.vtr-irv-rounds`), add:
```css
	@media (max-width:480px) {
		.vtr-bar { flex-wrap:wrap; align-items:stretch; }
		.vtr-bar-label { flex:1 1 auto; order:1; font-weight:600; }
		.vtr-bar-count { flex:0 0 auto; order:2; text-align:right; }
		.vtr-bar-track { flex:1 1 100%; order:3; height:14px; margin-top:4px; }
	}
```
- [ ] **Step 2 — Verify (browser, mobile viewport):** DevTools device toolbar at 320 px width, open `Voting/runner/{openEventId}` on the Live Results tab. Each candidate/Yes/No row now shows the label + count on one line with a FULL-WIDTH bar beneath. Toggle dark theme → track background (`--vtr-toggle-bg`) still visible.
- [ ] **Step 3 — Verify (desktop unchanged):** At ≥ 481 px the bars remain single-row (label 180 px / bar / count 60 px). No horizontal page scroll at 320 px.
- [ ] `git add orkui/template/revised-frontend/Voting_runner.tpl && git commit -m "Voting: stack live-results bars on mobile <=480px (finding 13)"`

---

## Task 3 — Finding 14: Runner tabs — remove nested interactive + add tablist ARIA

**Files:** `orkui/template/revised-frontend/Voting_runner.tpl`

**Interfaces:** Consumes: existing `.vtr-tab`/`.vtr-pane` + click handler (lines 170-177). Produces: valid `role="tablist"`/`role="tab"`/`role="tabpanel"` with `aria-selected`, roving `tabindex`, Left/Right arrow navigation, and the Audit "tab" as a plain `<a>` (no `<a>` inside `<button>`).

The three real tabs (results/external/manage) toggle panes; the Audit Log entry NAVIGATES to `Voting/audit/{id}` — so it is a link, not a panel toggle. Give the strip `role="tablist"`; the three toggles are `<button role="tab">`; Audit is `<a role="tab" href=...>` (native Enter/click navigation). Arrow keys rove across all `[role=tab]`.

- [ ] **Step 1** Replace the whole `.vtr-tabs` block (lines 91-96) with:
```php
	<div class="vtr-tabs" role="tablist" aria-label="Runner sections">
		<button class="vtr-tab active" data-pane="results" role="tab" id="vtr-tab-results" aria-selected="true" aria-controls="vtr-pane-results" tabindex="0">Live Results</button>
		<button class="vtr-tab" data-pane="external" role="tab" id="vtr-tab-external" aria-selected="false" aria-controls="vtr-pane-external" tabindex="-1">Enter External Votes</button>
		<button class="vtr-tab" data-pane="manage" role="tab" id="vtr-tab-manage" aria-selected="false" aria-controls="vtr-pane-manage" tabindex="-1">Event Management</button>
		<?php if ($is_admin): ?><a class="vtr-tab" role="tab" tabindex="-1" href="<?= UIR ?>Voting/audit/<?= $voting_event_id ?>">Audit Log</a><?php endif; ?>
	</div>
```
- [ ] **Step 2** Add `role="tabpanel"` + `id` + `aria-labelledby` to the three panes. Line 98 pane `results`: `<div class="vtr-pane active" data-pane="results" id="vtr-pane-results" role="tabpanel" aria-labelledby="vtr-tab-results">`. Line 110 pane `external`: add `id="vtr-pane-external" role="tabpanel" aria-labelledby="vtr-tab-external"`. Line 126 pane `manage`: add `id="vtr-pane-manage" role="tabpanel" aria-labelledby="vtr-tab-manage"`.
- [ ] **Step 3** Replace the tab click handler (lines 170-177) with a version that (a) only toggles for `[role=tab]` WITH a `data-pane` (the Audit `<a>` has none → falls through to native navigation), (b) updates `aria-selected` + roving `tabindex`, (c) supports Arrow keys:
```javascript
		// Tabs (ARIA tablist: roving tabindex + arrow keys; the Audit <a> has no data-pane and navigates natively).
		var tabEls = $$('.vtr-tab');
		function activateTab(t){
			var name = t.dataset.pane;
			if (!name) return; // Audit link — let the browser navigate.
			tabEls.forEach(function(x){
				var on = (x === t);
				x.classList.toggle('active', on);
				if (x.hasAttribute('role')) { x.setAttribute('aria-selected', on ? 'true' : 'false'); x.tabIndex = on ? 0 : -1; }
			});
			$$('.vtr-pane').forEach(function(p){ p.classList.toggle('active', p.dataset.pane === name); });
		}
		tabEls.forEach(function(t, i){
			t.addEventListener('click', function(){ if (t.dataset.pane) activateTab(t); });
			t.addEventListener('keydown', function(e){
				if (e.key !== 'ArrowRight' && e.key !== 'ArrowLeft') return;
				e.preventDefault();
				var dir = e.key === 'ArrowRight' ? 1 : -1;
				var next = tabEls[(i + dir + tabEls.length) % tabEls.length];
				next.focus();
				if (next.dataset.pane) activateTab(next);
			});
		});
```
- [ ] **Step 4 — Verify (keyboard/AT):** Open `Voting/runner/{eventId}` as an admin. Tab to the tab strip; only the active tab is in the tab order (roving tabindex). Press Right/Left arrows → focus and selection move across Live Results / External / Event Management; landing on the Audit Log link and pressing Enter navigates to the audit page. No console error. Validate markup: no `<a>` nested inside a `<button>` (view source — the Audit entry is a standalone `<a>`).
- [ ] **Step 5 — Verify (dark mode):** Toggle dark theme; active-tab underline (`#63b3ed`/`#3182ce`) and inactive tab text remain distinguishable.
- [ ] `git add orkui/template/revised-frontend/Voting_runner.tpl && git commit -m "Voting: valid tablist ARIA + roving tabs, Audit as plain link (finding 14)"`

---

## Task 4 — Finding 22: Resolve-Tie UI on the runner dashboard

**Files:** `orkui/template/revised-frontend/Voting_runner.tpl`

**Interfaces:**
- Consumes (already exists): `VotingAjax/resolve_tie/{voting_race_id}` (controller.VotingAjax.php:249) — POST body `WinnerChoiceId` (int), `Note` (non-empty string); returns `{status:0}` or `{status:1,error,detail}`. Service `ResolveTie` requires a non-empty note and a `winner_choice_id` that belongs to the race.
- Consumes: the `tally` JSON already polled every 5 s. Per race: `row.race.choices` = `[{id,label,...}]`; `row.result.outcome` ∈ `tie|tie_at_elimination|tie_at_final` (unresolved) or `win_resolved` (resolved, with `row.result.winner_choice_id` + `row.result.tie_resolution_note`); race id is the `rid` map key.
- Produces: an inline Resolve-Tie form (winner `<select>` from `race.choices` + required note + submit) rendered under any tied race; on success reloads. Also renders the resolution note when `outcome === 'win_resolved'`.

**Note (near-free follow-on, OUT OF SCOPE):** finding 38 wants the same `tie_resolution_note` shown on the PUBLIC results page (`Voting_results.tpl`) — the service already carries `result.tie_resolution_note`, so a later one-line render there is trivial. Not built here.

**CSRF dependency:** the resolve-tie POST attaches `X-CSRF-Token` guardedly (Security domain, finding 29 / `window.CMS_CSRF` pattern).

- [ ] **Step 1** Add CSS for the tie form. In the `<style>` block after `.vtr-pill-fail` (line 53), add:
```css
	.vtr-tie-form { margin-top:10px; padding:12px; border:1px solid #f6ad55; background:#fffaf0; border-radius:8px; }
	.vtr-tie-form label { display:block; font-size:12px; font-weight:600; margin-bottom:4px; color:var(--vtr-text,#1a202c); }
	.vtr-tie-form select, .vtr-tie-form textarea { width:100%; padding:8px 10px; font-size:13px; border:1px solid var(--vtr-card-border,#cbd5e0); background:var(--vtr-card-bg,#fff); color:var(--vtr-text,#1a202c); border-radius:6px; box-sizing:border-box; margin-bottom:8px; }
	.vtr-tie-note { margin-top:8px; padding:8px 10px; background:#c6f6d5; color:#22543d; border-radius:6px; font-size:12px; }
	html[data-theme="dark"] .vtr-tie-form { background:#3a3322; border-color:#975a16; }
	html[data-theme="dark"] .vtr-tie-note { background:#22543d; color:#c6f6d5; }
```
- [ ] **Step 2** Add a shared CSRF-header helper inside the runner IIFE, right after the `$$` helper (line 167). Insert:
```javascript
	function vtHeaders(){ return window.VOTING_CSRF ? {'X-CSRF-Token': window.VOTING_CSRF} : {}; }
```
- [ ] **Step 3** In `renderTally`, in the yes/no/confidence branch, replace the outcome-pill block (lines 205-207) with a version that appends a Resolve-Tie form on an unresolved tie and a resolution note when resolved:
```javascript
				html += '<div style="margin-top:8px;">';
				html += '<span class="vtr-pill ' + (result.outcome === 'pass' ? 'vtr-pill-win' : (result.outcome === 'win_resolved' ? 'vtr-pill-win' : (result.outcome === 'tie' ? 'vtr-pill-tie' : 'vtr-pill-fail'))) + '">' + escapeHtml(outcomeLabel(result.outcome)) + '</span>';
				html += '</div>';
				html += tieBlock(rid, race, result);
```
- [ ] **Step 4** In `renderTally`, IRV branch, after the outcome-pill block (line 235, after the `abstained` pill), append: `html += tieBlock(rid, race, result);`
- [ ] **Step 5** In `renderTally`, plurality/majority branch, after the outcome-pill block (line 248), append: `html += tieBlock(rid, race, result);`
- [ ] **Step 6** Add `tieBlock` + `outcomeLabel` extension. After the `outcomeLabel` function (line 260) add:
```javascript
	function tieBlock(rid, race, result){
		var TIES = { tie:1, tie_at_elimination:1, tie_at_final:1 };
		if (result.outcome === 'win_resolved') {
			return result.tie_resolution_note
				? '<div class="vtr-tie-note"><strong>Tie resolved.</strong> ' + escapeHtml(result.tie_resolution_note) + '</div>' : '';
		}
		if (!TIES[result.outcome]) return '';
		var choices = race.choices || [];
		if (!choices.length) return '';
		var opts = choices.map(function(c){ return '<option value="' + c.id + '">' + escapeHtml(c.label) + '</option>'; }).join('');
		return '<div class="vtr-tie-form" data-tie-race="' + rid + '">' +
			'<label>Declare winner</label><select class="vtr-tie-winner">' + opts + '</select>' +
			'<label>Justification (required — recorded in the audit log)</label>' +
			'<textarea class="vtr-tie-note-input" rows="2" placeholder="e.g., resolved by coin toss per kingdom bylaws"></textarea>' +
			'<button class="vtr-btn vtr-tie-submit" data-race-id="' + rid + '" disabled>Resolve &amp; Declare Winner</button>' +
			'<span class="vtr-tie-msg" style="margin-left:8px;font-size:12px;"></span></div>';
	}
```
- [ ] **Step 7** Prevent the 5 s poll from wiping a half-typed justification. At the TOP of `renderTally` (line 181, before `var host`), add:
```javascript
		if (window.__vtTieEditing) return; // don't clobber an open tie form mid-edit
```
- [ ] **Step 8** Wire the form (enable submit, mark editing, POST). Because the results host is re-rendered, use delegated listeners on `#vtr-results-host`. After the `if (!suppress) { poll(); setInterval(poll, 5000); }` line (line 272), add:
```javascript
	var resultsHost = $('#vtr-results-host');
	if (resultsHost) {
		resultsHost.addEventListener('input', function(e){
			var form = e.target.closest('.vtr-tie-form'); if (!form) return;
			window.__vtTieEditing = true;
			var note = form.querySelector('.vtr-tie-note-input');
			var btn = form.querySelector('.vtr-tie-submit');
			if (btn && note) btn.disabled = (note.value.trim() === '');
		});
		resultsHost.addEventListener('click', function(e){
			var btn = e.target.closest('.vtr-tie-submit'); if (!btn) return;
			var form = btn.closest('.vtr-tie-form');
			var winner = form.querySelector('.vtr-tie-winner').value;
			var note = form.querySelector('.vtr-tie-note-input').value.trim();
			var msg = form.querySelector('.vtr-tie-msg');
			if (!note) { if (msg) { msg.textContent = 'Justification is required.'; msg.style.color = '#c53030'; } return; }
			pnConfirm({ title:'Resolve Tie?', message:'Declare the selected candidate the winner? This is recorded in the audit log.', confirmText:'Resolve', danger:false }, function(){
				btn.disabled = true;
				var data = new FormData();
				data.append('WinnerChoiceId', winner);
				data.append('Note', note);
				fetch('<?= UIR ?>VotingAjax/resolve_tie/' + btn.dataset.raceId, { method:'POST', body:data, credentials:'same-origin', headers: vtHeaders() })
					.then(r => r.json()).then(function(j){
						if (j.status === 0) { window.__vtTieEditing = false; location.reload(); }
						else { btn.disabled = false; if (msg) { msg.textContent = (j.error || 'Failed') + (j.detail ? ': ' + j.detail : ''); msg.style.color = '#c53030'; } }
					});
			});
		});
	}
```
- [ ] **Step 9 — Verify (curl, happy path):** With a closed event that has a tied race, POST resolve_tie:
```bash
curl -s -b /tmp/vote.jar -X POST 'http://localhost:19080/orkui/index.php?Route=VotingAjax/resolve_tie/{tiedRaceId}' \
  --data 'WinnerChoiceId={choiceId}&Note=coin toss'   # expect {"status":0}
```
Then `curl ... VotingAjax/publish/{eventId}` → now returns `{"status":0}` (the previously-blocking "unresolved tie" is gone). Re-running resolve with an empty Note returns `{"status":1,...}` (service requires a note).
- [ ] **Step 10 — Verify (browser + dark mode):** Open `Voting/runner/{tiedEventId}` on Live Results. The tied race shows the amber Resolve-Tie form; the submit button is disabled until a justification is typed. Submit → `pnConfirm` → page reloads and the race now shows the green "Tie resolved." note. Toggle dark theme → the amber form + green note both readable.
- [ ] `git add orkui/template/revised-frontend/Voting_runner.tpl && git commit -m "Voting: in-app Resolve-Tie UI wired to VotingAjax/resolve_tie (finding 22)"`

---

## Task 5 — Finding 35a: Minimal delegate-write backend (service)

**Files:** `system/lib/ork3/class.Voting.php`

> **DEVIATION NOTICE (flag in commit + PR):** This is the ONLY change this domain makes to `class.Voting.php`, which is otherwise the lifecycle/service domain's. Finding 35 requires a delegate WRITE + LIST that does not yet exist (only the delegate-auth READ path exists). Raw DB may not live in a controller (architecture rule), so it MUST go here. Keep these three methods minimal, reuse existing auth helpers, and request lifecycle/service-domain review.

**Interfaces:**
- Produces `AddDelegate($request)` — request `{Token, VotingEventId:int, DelegateMundaneId:int}`; gated to a sitting scope officer or admin; idempotent `INSERT IGNORE` into `ork_voting_runner`; returns `Success($delegate_id)` / `NoAuthorization()` / `InvalidParameter()`.
- Produces `RemoveDelegate($request)` — same request shape; `DELETE` the row; same return shape.
- Produces `ListDelegates($voting_event_id)` — plain read returning `[['mundane_id'=>int,'persona'=>str,'username'=>str], ...]`.
- Consumes existing: `$this->Event` (yapo with `scope_type`/`scope_id`/`voting_event_id`), `user_can_run_in_scope()`, `audit()`, `Ork3::$Lib->authorization`.

- [ ] **Step 1 — Normalize check:** `awk '/^\t/{c++}END{print c+0}' system/lib/ork3/class.Voting.php`. If the file is tab-indented (matches the reads above), Edit directly; if it comes back mixed/dirty, run `php-cs-fixer` on that one file first (per the PSR-12 boy-scout rule) BEFORE editing.
- [ ] **Step 2** Insert the three methods immediately AFTER `ResolveTie` (after its closing `}` around line 1863, before `public function Publish`):
```php
    public function AddDelegate($request)
    {
        $mundane_id = Ork3::$Lib->authorization->IsAuthorized($request['Token']);
        if (!valid_id($mundane_id)) {
            return NoAuthorization();
        }
        $voting_event_id = (int)($request['VotingEventId'] ?? 0);
        $delegate_id = (int)($request['DelegateMundaneId'] ?? 0);
        if (!$voting_event_id || !$delegate_id) {
            return InvalidParameter();
        }
        $this->Event->clear();
        $this->Event->voting_event_id = $voting_event_id;
        if (!$this->Event->find()) {
            return InvalidParameter();
        }
        // Only a sitting scope officer (or admin) may delegate — NOT a mere delegated runner.
        $is_admin = Ork3::$Lib->authorization->HasAuthority($mundane_id, AUTH_ADMIN, 0, AUTH_ADMIN);
        if (!$is_admin && !$this->user_can_run_in_scope($mundane_id, $this->Event->scope_type, $this->Event->scope_id)) {
            return NoAuthorization();
        }
        global $DB;
        $DB->Clear();
        $DB->Execute("INSERT IGNORE INTO " . DB_PREFIX . "voting_runner (voting_event_id, mundane_id) VALUES (" . $voting_event_id . ", " . $delegate_id . ")");
        $this->audit($voting_event_id, 'runner_delegated', ['delegate' => $delegate_id], $mundane_id);
        return Success($delegate_id);
    }

    public function RemoveDelegate($request)
    {
        $mundane_id = Ork3::$Lib->authorization->IsAuthorized($request['Token']);
        if (!valid_id($mundane_id)) {
            return NoAuthorization();
        }
        $voting_event_id = (int)($request['VotingEventId'] ?? 0);
        $delegate_id = (int)($request['DelegateMundaneId'] ?? 0);
        if (!$voting_event_id || !$delegate_id) {
            return InvalidParameter();
        }
        $this->Event->clear();
        $this->Event->voting_event_id = $voting_event_id;
        if (!$this->Event->find()) {
            return InvalidParameter();
        }
        $is_admin = Ork3::$Lib->authorization->HasAuthority($mundane_id, AUTH_ADMIN, 0, AUTH_ADMIN);
        if (!$is_admin && !$this->user_can_run_in_scope($mundane_id, $this->Event->scope_type, $this->Event->scope_id)) {
            return NoAuthorization();
        }
        global $DB;
        $DB->Clear();
        $DB->Execute("DELETE FROM " . DB_PREFIX . "voting_runner WHERE voting_event_id = " . $voting_event_id . " AND mundane_id = " . $delegate_id);
        $this->audit($voting_event_id, 'runner_undelegated', ['delegate' => $delegate_id], $mundane_id);
        return Success($delegate_id);
    }

    public function ListDelegates($voting_event_id)
    {
        global $DB;
        $DB->Clear();
        $rs = $DB->DataSet("SELECT vr.mundane_id, m.persona, m.username
			FROM " . DB_PREFIX . "voting_runner vr
			JOIN " . DB_PREFIX . "mundane m ON m.mundane_id = vr.mundane_id
			WHERE vr.voting_event_id = " . (int)$voting_event_id . "
			ORDER BY m.persona");
        $out = [];
        if ($rs) {
            while ($rs->Next()) {
                $out[] = [
                    'mundane_id' => (int)$rs->mundane_id,
                    'persona'    => $rs->persona,
                    'username'   => $rs->username,
                ];
            }
        }
        return $out;
    }
```
- [ ] **Step 3 — Verify (syntax):** `docker exec ork3-php8-app php -l system/lib/ork3/class.Voting.php` → "No syntax errors detected". (Confirm `$this->Event`, `user_can_run_in_scope`, `audit`, `valid_id`, `Success/NoAuthorization/InvalidParameter` resolve — they are all used elsewhere in this file.)
- [ ] `git add system/lib/ork3/class.Voting.php && git commit -m "Voting: minimal AddDelegate/RemoveDelegate/ListDelegates backend (finding 35; flagged service change)"`

---

## Task 6 — Finding 35b: Model pass-throughs

**Files:** `orkui/model/model.Voting.php`

**Interfaces:** Consumes the service methods from Task 5. Produces `add_delegate($request)`, `remove_delegate($request)`, `list_delegates($id)` matching the existing thin-wrapper style (`$this->Voting->CamelName(...)`).

- [ ] **Step 1** After `resolve_tie` (line 87) add:
```php
    public function add_delegate($request)
    {
        return $this->Voting->AddDelegate($request);
    }
    public function remove_delegate($request)
    {
        return $this->Voting->RemoveDelegate($request);
    }
```
- [ ] **Step 2** In the "Reads" section, after `event_scope` (line 186) add:
```php
    public function list_delegates($voting_event_id)
    {
        return $this->Voting->ListDelegates($voting_event_id);
    }
```
- [ ] **Step 3 — Verify:** `docker exec ork3-php8-app php -l orkui/model/model.Voting.php` → no syntax errors.
- [ ] `git add orkui/model/model.Voting.php && git commit -m "Voting: model pass-throughs for delegate add/remove/list (finding 35)"`

---

## Task 7 — Finding 35c: AJAX actions for delegate add/remove

**Files:** `orkui/controller/controller.VotingAjax.php`

**Interfaces:**
- Produces `add_delegate($voting_event_id)` — reads `$this->request->DelegateMundaneId`; forwards `{Token, VotingEventId, DelegateMundaneId}` to `$this->Voting->add_delegate(...)`; `ok()`/`fail()` on flat `Status`.
- Produces `remove_delegate($voting_event_id)` — same shape → `remove_delegate`.
- Consumes: `$this->session->token`, `$this->session->user_id`, `require_login()`, `ok()`, `fail()`.

**CSRF dependency:** these two POST endpoints will be validated by the Security domain's `_begin()` CSRF check (finding 29); no controller change needed here for that — the header is attached client-side in Task 9.

- [ ] **Step 1** After `resolve_tie` (ends line 262) add:
```php
    public function add_delegate($voting_event_id = null)
    {
        $this->require_login();
        $r = $this->Voting->add_delegate([
            'Token' => $this->session->token,
            'VotingEventId' => (int)$voting_event_id,
            'DelegateMundaneId' => (int)$this->request->DelegateMundaneId,
        ]);
        if (($r['Status'] ?? 1) != 0) {
            $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
        }
        $this->ok();
    }

    public function remove_delegate($voting_event_id = null)
    {
        $this->require_login();
        $r = $this->Voting->remove_delegate([
            'Token' => $this->session->token,
            'VotingEventId' => (int)$voting_event_id,
            'DelegateMundaneId' => (int)$this->request->DelegateMundaneId,
        ]);
        if (($r['Status'] ?? 1) != 0) {
            $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
        }
        $this->ok();
    }
```
- [ ] **Step 2 — Verify (curl):** As a scope officer, `curl -s -b /tmp/vote.jar -X POST '...Route=VotingAjax/add_delegate/{eventId}' --data 'DelegateMundaneId={someMundaneId}'` → `{"status":0}`; repeat → still `{"status":0}` (idempotent). Then `remove_delegate` with the same id → `{"status":0}`. As a NON-officer session → `add_delegate` returns `{"status":1,...}` (NoAuthorization).
- [ ] `git add orkui/controller/controller.VotingAjax.php && git commit -m "Voting: VotingAjax add_delegate/remove_delegate actions (finding 35)"`

---

## Task 8 — Finding 35d: Controller passes delegate list + capability to the runner view

**Files:** `orkui/controller/controller.Voting.php`

**Interfaces:**
- Produces template vars: `$data['delegates']` (from `list_delegates`), `$data['can_delegate']` (bool: admin OR sitting scope officer — NOT a delegated-only runner).
- Consumes: existing `$event` (has `scope_type`,`scope_id`), `$this->data['is_admin']`, `user_can_run_in_scope`.

- [ ] **Step 1** In `runner()` (after the `counts` line at 223, before `$this->template = ...`), add:
```php
        // Delegate Runner (finding 35): who may add/remove, and the current delegate list.
        $this->data['can_delegate'] = $this->data['is_admin']
            || $this->Voting->user_can_run_in_scope((int)$this->session->user_id, strtolower($event['scope_type']), (int)$event['scope_id']);
        $this->data['delegates'] = $this->Voting->list_delegates($voting_event_id);
```
- [ ] **Step 2 — Verify:** `docker exec ork3-php8-app php -l orkui/controller/controller.Voting.php` → no syntax errors. `curl -s -b /tmp/vote.jar '...Route=Voting/runner/{eventId}'` still returns the dashboard HTML (200, no fatal).
- [ ] `git add orkui/controller/controller.Voting.php && git commit -m "Voting: runner() passes delegates + can_delegate to view (finding 35)"`

---

## Task 9 — Finding 35e: Delegate Runner section in the Event Management tab

**Files:** `orkui/template/revised-frontend/Voting_runner.tpl`

**Interfaces:**
- Consumes: `$can_delegate` (bool), `$delegates` (array of `{mundane_id,persona,username}`), `$voting_event_id`, existing `vtHeaders()` (added in Task 4).
- Consumes AJAX: `VotingAjax/voter_search/{eventId}&q=` (scoped player search, returns `{results:[{value,label}]}`); `VotingAjax/add_delegate/{eventId}` + `VotingAjax/remove_delegate/{eventId}` (POST `DelegateMundaneId`).
- Produces: a "Delegate Runner" card in the `manage` pane — a scoped `kn-ac-results` player search + Add button, and a list of current delegates each with a Remove button. Mirrors the existing `#vtr-ext-*` inline search pattern (NO modal → NO `tnFixedAcPosition`).

**CSRF dependency:** add/remove POSTs attach `X-CSRF-Token` via `vtHeaders()` (Security domain finding 29).

- [ ] **Step 1** In the `manage` pane, add a second card AFTER the Event Management card (after its closing `</div>` at line 156, before the pane's closing `</div>`). Gate on `$can_delegate`:
```php
			<?php if (!empty($can_delegate)): ?>
			<div class="vtr-card">
				<h2>Delegate Runner</h2>
				<div class="vtr-banner vtr-banner-info">Add another officer as a runner for this event — useful when you are on the ballot and must hand the election to someone else. Delegates can manage and publish, but only sitting scope officers can add or remove them.</div>
				<div style="display:flex;gap:8px;align-items:flex-start;">
					<div style="flex:1;position:relative;">
						<input id="vtr-del-input" type="text" placeholder="Search a player..." autocomplete="off" style="width:100%;padding:10px 12px;font-size:14px;border:1px solid var(--vtr-card-border,#cbd5e0);border-radius:6px;box-sizing:border-box;background:var(--vtr-card-bg,#fff);color:var(--vtr-text,#1a202c);" />
						<input id="vtr-del-id" type="hidden" />
						<div id="vtr-del-results" class="kn-ac-results"></div>
					</div>
					<button id="vtr-del-go" class="vtr-btn" disabled>Add Delegate</button>
				</div>
				<div id="vtr-del-msg" style="margin-top:10px;"></div>
				<div id="vtr-del-list" style="margin-top:12px;">
					<?php if (empty($delegates)): ?>
						<div class="vtr-empty" style="padding:14px;">No delegated runners yet.</div>
					<?php else: ?>
						<?php foreach ($delegates as $d): ?>
							<div class="vtr-del-row" data-del-id="<?= (int)$d['mundane_id'] ?>" style="display:flex;align-items:center;gap:8px;padding:8px 10px;border:1px solid var(--vtr-card-border,#e2e8f0);border-radius:6px;margin-bottom:6px;">
								<i class="fas fa-user-shield" style="opacity:0.6"></i>
								<span style="flex:1;color:var(--vtr-text,#1a202c);"><?= htmlspecialchars($d['persona'] ?: $d['username']) ?> <span class="vtr-sub" style="margin:0;">(<?= htmlspecialchars($d['username']) ?>)</span></span>
								<button class="vtr-btn vtr-btn-ghost vtr-del-remove" data-del-id="<?= (int)$d['mundane_id'] ?>" data-tip="Remove delegate" aria-label="Remove delegate">Remove</button>
							</div>
						<?php endforeach; ?>
					<?php endif; ?>
				</div>
			</div>
			<?php endif; ?>
```
- [ ] **Step 2** Add the JS (inside the SAME runner IIFE, after the external-ballot search block that ends near line 320). Mirror the `#vtr-ext-*` search; POSTs use `vtHeaders()`:
```javascript
	// Delegate Runner search + add/remove (finding 35). Inline dropdown — mirrors external-vote search.
	var delInput = $('#vtr-del-input');
	if (delInput) {
		var delResults = $('#vtr-del-results');
		var delId = $('#vtr-del-id');
		var delBtn = $('#vtr-del-go');
		var delMsg = $('#vtr-del-msg');
		var delT;
		delInput.addEventListener('input', function(){
			delId.value = ''; delBtn.disabled = true;
			clearTimeout(delT);
			var q = delInput.value.trim();
			if (q.length < 2) { delResults.classList.remove('kn-ac-open'); delResults.innerHTML=''; return; }
			delT = setTimeout(function(){
				fetch('<?= UIR ?>VotingAjax/voter_search/' + eventId + '&q=' + encodeURIComponent(q))
					.then(r => r.json()).then(function(j){
						delResults.innerHTML = '';
						if (!j.results || !j.results.length) {
							delResults.innerHTML = '<div class="kn-ac-row" style="opacity:0.6;padding:8px 10px;">No matches</div>';
						} else {
							j.results.forEach(function(r){
								var row = document.createElement('div');
								row.className = 'kn-ac-row';
								row.style.cssText = 'padding:8px 10px;cursor:pointer;';
								row.textContent = r.label;
								row.addEventListener('click', function(){
									delId.value = r.value; delInput.value = r.label; delBtn.disabled = false;
									delResults.classList.remove('kn-ac-open');
								});
								delResults.appendChild(row);
							});
						}
						delResults.classList.add('kn-ac-open');
					});
			}, 150);
		});
		document.addEventListener('click', function(e){
			if (delInput && !delInput.contains(e.target) && delResults && !delResults.contains(e.target)) delResults.classList.remove('kn-ac-open');
		});
		delBtn.addEventListener('click', function(){
			var vid = parseInt(delId.value, 10);
			if (!vid) return;
			delBtn.disabled = true;
			var data = new FormData();
			data.append('DelegateMundaneId', vid);
			fetch('<?= UIR ?>VotingAjax/add_delegate/' + eventId, { method:'POST', body:data, credentials:'same-origin', headers: vtHeaders() })
				.then(r => r.json()).then(function(j){
					if (j.status === 0) location.reload();
					else { delBtn.disabled = false; delMsg.innerHTML = '<div class="vtr-banner vtr-banner-warn">' + escapeHtml(j.error || 'Failed') + (j.detail ? ': ' + escapeHtml(j.detail) : '') + '</div>'; }
				});
		});
		$$('.vtr-del-remove').forEach(function(btn){
			btn.addEventListener('click', function(){
				pnConfirm({ title:'Remove Delegate?', message:'This officer will no longer be able to run this election.', confirmText:'Remove', danger:true }, function(){
					btn.disabled = true;
					var data = new FormData();
					data.append('DelegateMundaneId', btn.dataset.delId);
					fetch('<?= UIR ?>VotingAjax/remove_delegate/' + eventId, { method:'POST', body:data, credentials:'same-origin', headers: vtHeaders() })
						.then(r => r.json()).then(function(j){
							if (j.status === 0) location.reload();
							else { btn.disabled = false; if (delMsg) delMsg.innerHTML = '<div class="vtr-banner vtr-banner-warn">' + escapeHtml(j.error || 'Failed') + '</div>'; }
						});
				});
			});
		});
	}
```
- [ ] **Step 3 — Verify (browser, happy path):** As a scope officer, open `Voting/runner/{eventId}` → Event Management tab. The "Delegate Runner" card appears. Type ≥2 chars → the `kn-ac-results` dropdown lists scoped players (custom dropdown, not jQuery UI). Pick one → Add Delegate → page reloads and the officer appears in the list. Click Remove → `pnConfirm` → row disappears after reload. Confirm the delegated officer (log in as them) can now reach the runner dashboard for this event.
- [ ] **Step 4 — Verify (auth gate + dark mode):** The card is HIDDEN for a delegated-only runner (`$can_delegate` false). Toggle dark theme → card, banner, delegate rows, and Remove buttons all readable.
- [ ] `git add orkui/template/revised-frontend/Voting_runner.tpl && git commit -m "Voting: Delegate Runner section (scoped search + add/remove) (finding 35)"`

---

## Task 10 — Finding 8: Consolidate per-race settings beside candidates; tab descriptions; Open Voting from both tabs

**Files:** `orkui/template/revised-frontend/Voting_edit.tpl`

**Interfaces:**
- Consumes: existing `$event['races']`, `$can_edit`, existing per-race JS (`.vte-rs-mode`/`.vte-rs-abstain`/`.vte-rs-nota`/`.vte-rs-nca`/`.vte-rs-nb`/`.vte-rs-save`, the NOTA-reveal handler, and `.vte-rs-save` submit → `VotingAjax/edit_race_settings/{raceId}`). All of these query WITHIN `.vte-race`, so moving the settings markup INTO the ballot-tab race card keeps them working unchanged.
- Produces: (a) one-line description under each tab button; (b) per-race settings block rendered inside each ballot-tab race card (removing the separate "Per-Race Settings" card from the Configuration tab); (c) an "Open Voting Now"/"Resume Voting" action visible ABOVE the tabs (so it is reachable from both tabs).

- [ ] **Step 1 — Tab descriptions.** Replace the `.vte-tabs` block (lines 129-132) with buttons that carry `aria-describedby` plus a description line beneath:
```php
		<div class="vte-tabs">
			<button class="vte-tab active" data-pane="config" type="button"><i class="fas fa-sliders-h"></i> Configuration</button>
			<button class="vte-tab" data-pane="ballot" type="button"><i class="fas fa-list-ol"></i> Ballot Management</button>
		</div>
		<div class="vte-sub" data-pane-desc="config" style="margin-top:-6px;">Event-wide settings: title, description, open/close dates, and privacy options.</div>
		<div class="vte-sub" data-pane-desc="ballot" style="margin-top:-6px;display:none;">Add races and candidates. Each race's voting mode, abstain, and NOTA options live right beside its candidate list.</div>
```
- [ ] **Step 2 — Show the right description per tab.** In the tab-switching handler (lines 691-697), inside the `tab.addEventListener('click', ...)` after the pane toggle, add:
```javascript
			$$('[data-pane-desc]').forEach(function(d){ d.style.display = (d.dataset.paneDesc === name) ? '' : 'none'; });
```
- [ ] **Step 3 — Delete the standalone Per-Race Settings card.** Remove the entire `<?php if (!empty($event['races'])): ?> ... <?php endif; ?>` block that renders the "Per-Race Settings" card in the Configuration pane (lines 164-213). The Configuration pane then contains only the Event Settings card.
- [ ] **Step 4 — Embed per-race settings into each ballot-tab race card.** In the ballot-pane race loop, inside the `.vte-race` card, AFTER the choices block and BEFORE the add-choice row (i.e., after the `<?php endif; ?>` closing the choices at line 271, before `<?php if ($can_edit): ?>` at line 273), insert the settings sub-section (reuses the `is_position`/`is_althing` guards and the same control classes the JS already binds):
```php
						<?php if ($can_edit): ?>
							<?php $is_position = ($race['race_type'] === 'position'); $is_althing = in_array($race['race_type'], ['yesno','multichoice'], true); ?>
							<div class="vte-edit-form" style="margin-top:12px;">
								<div style="font-size:12px;font-weight:600;margin-bottom:8px;color:var(--vte-meta,#5a6472);">Race settings</div>
								<div class="vte-grid-2">
									<?php if ($is_position): ?>
										<div class="vte-row">
											<label>Voting mode</label>
											<select class="vte-rs-mode">
												<option value="plurality" <?= $race['voting_mode'] === 'plurality' ? 'selected' : '' ?>>Plurality (top vote-getter wins)</option>
												<option value="majority" <?= $race['voting_mode'] === 'majority' ? 'selected' : '' ?>>Majority (50%+1)</option>
												<option value="irv" <?= $race['voting_mode'] === 'irv' ? 'selected' : '' ?>>Ranked Choice (Instant Runoff)</option>
											</select>
											<div style="font-size:11px;color:var(--vte-meta,#5a6472);margin-top:4px;">Cannot change once votes are cast.</div>
										</div>
									<?php else: ?>
										<div class="vte-row">
											<label>Voting mode</label>
											<input type="text" value="<?= htmlspecialchars($race['voting_mode']) ?>" disabled />
											<div style="font-size:11px;color:var(--vte-meta,#5a6472);margin-top:4px;">Mode is fixed for <?= htmlspecialchars($race['race_type']) ?> races.</div>
										</div>
									<?php endif; ?>
									<div>
										<div class="vte-toggle"><input class="vte-rs-abstain" type="checkbox" <?= !empty($race['allow_abstain']) ? 'checked' : '' ?> /><label>Allow abstain</label></div>
										<div class="vte-toggle"><input class="vte-rs-nota" type="checkbox" <?= !empty($race['allow_none_of_above']) ? 'checked' : '' ?> /><label>Allow None of the Above</label></div>
										<div class="vte-row" style="margin-top:6px;<?= !empty($race['allow_none_of_above']) ? '' : 'display:none' ?>" data-rs-nota-row>
											<label style="font-size:11px;">NOTA counts as</label>
											<select class="vte-rs-nca">
												<option value="abstain" <?= $race['nota_counts_as'] === 'abstain' ? 'selected' : '' ?>>Abstain (excluded from threshold)</option>
												<option value="no" <?= $race['nota_counts_as'] === 'no' ? 'selected' : '' ?>>No (counts against)</option>
											</select>
										</div>
										<?php if ($is_althing): ?>
											<div class="vte-toggle"><input class="vte-rs-nb" type="checkbox" <?= !empty($race['is_non_binding']) ? 'checked' : '' ?> /><label>Non-binding (poll only)</label></div>
										<?php endif; ?>
									</div>
								</div>
								<div class="vte-actions" style="margin-top:10px;"><button class="vte-btn vte-btn-primary vte-rs-save" data-race-id="<?= (int)$race['voting_race_id'] ?>" type="button">Save Race Settings</button><span class="vte-rs-msg" style="margin-left:10px;font-size:13px;"></span></div>
							</div>
						<?php endif; ?>
```
> The existing `$is_position`/`$is_althing` are re-declared locally so this block is self-contained; the ballot-loop already sets `data-race-id` on the outer `.vte-race`, and the settings controls the JS binds (`.vte-rs-*`) are queried via `btn.closest('.vte-race')`, so they resolve to THIS card.
- [ ] **Step 5 — Surface "Open Voting" from both tabs.** Move the draft "Open/Resume Voting" action out of the ballot pane into an always-visible bar above the tabs. Insert BEFORE the `<div class="vte-tabs">` (line 129):
```php
		<?php if ($can_edit && $event['status'] === 'draft' && !empty($event['races'])): ?>
			<div style="display:flex;justify-content:flex-end;align-items:center;gap:10px;margin-bottom:12px;flex-wrap:wrap;">
				<div id="vte-open-msg-top" style="font-size:13px;"></div>
				<?php if (!empty($event['reopened_at'])): ?>
					<button id="vte-resume-event-top" class="vte-btn vte-btn-success" style="font-size:14px;padding:10px 20px;"><i class="fas fa-play"></i> Resume Voting</button>
				<?php else: ?>
					<button id="vte-open-event-top" class="vte-btn vte-btn-success" style="font-size:14px;padding:10px 20px;">Open Voting Now</button>
				<?php endif; ?>
			</div>
		<?php endif; ?>
```
- [ ] **Step 6 — Wire the top buttons to the SAME handlers.** The existing open handler binds `#vte-open-event` and the resume handler binds `#vte-resume-event`. Generalize both to also fire for the `-top` twins. In the open-event handler (lines 500-507) change the selector line and success/error target:
  - Change `var openBtn = $('#vte-open-event');` → `var openBtn = $('#vte-open-event') || $('#vte-open-event-top');`
  - Also bind the twin: immediately after that handler's `});`, add:
```javascript
		var openBtnTop = $('#vte-open-event-top');
		if (openBtnTop && openBtnTop !== openBtn) openBtnTop.addEventListener('click', function(){ (openBtn || openBtnTop) && openBtnTop.click; });
```
  Simpler and robust — instead of the above twin hack, REPLACE the single-button open handler with a class-based one. Change the ballot-tab button (line 344) to add class `vte-open-event-btn`, add the same class to the `-top` button in Step 5, and replace the handler (lines 500-507) with:
```javascript
		// Open event (bound to every Open-Voting button — top bar + ballot tab).
		$$('.vte-open-event-btn').forEach(function(openBtn){
			openBtn.addEventListener('click', function(){
				var msg = $('#vte-open-msg-top') || $('#vte-open-msg');
				fetch('<?= UIR ?>VotingAjax/open_event/' + eventId, { method:'POST', credentials:'same-origin' })
					.then(r => r.json()).then(function(j){
						if (j.status === 0) location.reload();
						else if (msg) msg.innerHTML = '<div class="vte-error">' + escapeHtml(j.error || 'Failed') + (j.detail ? ': ' + escapeHtml(j.detail) : '') + '</div>';
					});
			});
		});
```
  - Give BOTH open buttons the class: Step-5 top button → add `vte-open-event-btn`; ballot-tab button at line 344 → `<button id="vte-open-event" class="vte-btn vte-btn-success vte-open-event-btn" ...>`.
- [ ] **Step 7 — Resume twin.** The resume handler (lines 670-678) binds `#vte-resume-event`. Change `var resumeBtn = $('#vte-resume-event');` → `var resumeBtn = $('#vte-resume-event') || $('#vte-resume-event-top');` so the top Resume button drives the same impact-preview modal. (Only one resume button shows at a time in practice, but the `||` covers whichever is present.)
- [ ] **Step 8 — Verify (browser, config integrity):** Open `Voting/edit/{draftEventId}` with ≥1 race. Configuration tab shows ONLY Event Settings + the tab description; Ballot Management tab shows each race with its candidates AND its Race-settings block directly beneath. Toggle a race's NOTA checkbox → the "NOTA counts as" select reveals (existing handler still binds). Click "Save Race Settings" → inline "Saved." appears. `curl` cross-check: `VotingAjax/edit_race_settings/{raceId}` with `AllowNoneOfAbove=1&NotaCountsAs=no` → `{"status":0}`.
- [ ] **Step 9 — Verify (Open Voting from both tabs):** The "Open Voting Now" button is visible in the top bar on BOTH tabs. Click it from the Configuration tab → event opens (reload). Toggle dark theme → tab descriptions (`.vte-sub`), the Race-settings sub-block, and the top action bar all readable.
- [ ] `git add orkui/template/revised-frontend/Voting_edit.tpl && git commit -m "Voting: consolidate per-race settings beside candidates + tab descriptions + Open Voting in both tabs (finding 8)"`

---

## Login recipe (used by every curl/browser verify)

```bash
# 1. Auth (bypass accepts any password); persist the cookie jar.
curl -s -c /tmp/vote.jar -X POST 'http://localhost:19080/orkui/index.php?Route=Login/login' \
  --data 'Username={officerUsername}&Password=x' >/dev/null
# 2. Hit any route with -b /tmp/vote.jar, e.g.:
curl -s -b /tmp/vote.jar 'http://localhost:19080/orkui/index.php?Route=Voting/runner/{eventId}'
```
Container: `ork3-php8-app`. DB client for spot-checks: `docker exec ork3-php8-db mariadb -u root -proot ork`. Routes are `index.php?Route=Controller/action/id` (NOT clean URLs).

## Self-review checklist (run before declaring done)
- [ ] Every finding (22, 35, 8, 13, 14, 15) maps to a task above.
- [ ] No `title=` attributes added (used `data-tip`); no FA6 icon names; every heading in a card resets the pill box.
- [ ] Every new color has an `html[data-theme="dark"]` override; dark-mode checked in each verify step.
- [ ] Every new mutating `fetch` sends `X-CSRF-Token` via `vtHeaders()` (findings 22 & 35) — dependency on Security domain finding 29 noted.
- [ ] Delegate search uses `kn-ac-results` + `&q=` + 2-char/150 ms; scoped via `voter_search/{eventId}`; inline (no `tnFixedAcPosition`).
- [ ] `$DB->Clear()` precedes every raw `Execute`/`DataSet`; ids `(int)`-cast; `ListDelegates` calls `$rs->Next()` before reading fields.
- [ ] Name/type consistency: AJAX `add_delegate`/`remove_delegate` → model `add_delegate`/`remove_delegate`/`list_delegates` → service `AddDelegate`/`RemoveDelegate`/`ListDelegates`; request keys `VotingEventId`/`DelegateMundaneId`/`WinnerChoiceId`/`Note`.
- [ ] `class.Voting.php` change is limited to the three flagged delegate methods (deviation noted for lifecycle/service-domain review).
