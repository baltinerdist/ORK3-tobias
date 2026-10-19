# Security, Authorization, Audit & Anonymity Implementation Plan
> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Add per-request CSRF protection to every Voting mutation, let the officer who ran an election read its own (voter-redacted) audit log, delete the inert `anonymous_to_runner` promise, force every admin voter→choice de-anonymization through one audited path, and render audit detail as human phrases.

**Architecture:** CSRF uses a per-session synchronizer token minted once in the shared base `Controller` (`_csrfToken()`), emitted to every Voting page as `window.VOTING_CSRF`, sent on every mutating `fetch` as the `X-CSRF-Token` header, and validated in the `Controller_VotingAjax` constructor for any action **not** on a small GET read-allowlist (so new mutation actions are auto-protected). Authorization/audit/anonymity changes live in `controller.Voting.php` + the `Voting` service (`system/lib/ork3/class.Voting.php`), which owns audit writes and the voter-identity redaction projection consumed by the audit template.

**Tech Stack:** PHP 8 / MariaDB / plain-PHP templates / fetch + X-CSRF-Token

## Global Constraints
- `.tpl` files are PLAIN PHP — use `<?php ?>`/`<?= ?>`, never Smarty `{$var}`/`{if}`.
- `mysql_real_escape_string()` is a no-op shim — `(int)`-cast ids; regex-validate strings; inline-escape LIKE terms.
- yapo drops `null` from UPDATE/INSERT — assign `''` (not `null`) to clear a column.
- Controller actions read the session via `$this->session->user_id` / `$this->session->token`, NOT `$this->__session` (that silently yields uid 0).
- `$DB->Clear()` before every raw `Execute`/`DataSet`; `$DB->DataSet()` needs a manual `->Next()` before reading fields.
- Migrations run on **MariaDB** (`docker exec -i ork3-php8-db mariadb -u root -proot ork < file.sql`). This plan adds **no** schema — `admin_voter_choice_view` is already in the `ork_voting_audit.action` ENUM (migration `2026-05-07-voting-module.sql:127-138`).
- **NEVER** stage `class.Authorization.php`. Stage files explicitly (never `git add -A`/`.`); verify `git diff --cached` before each commit.
- Editing PHP/`.tpl`: NORMALIZE-FIRST — `awk '/^\t/{c++}END{print c+0}' <file>`; if it reports leading-tab lines the file is tab-indented (all four Voting templates and the two controllers are), so match existing indentation exactly in `old_string`.

---

## CSRF Contract (this domain DEFINES it — Domains 1/4/7 consume it)

Other domains are adding NEW `VotingAjax` POST actions (Domain 1 close, Domain 4 external ballot, Domain 7 tie-resolve + delegate). They do **not** touch the gate. The one-line contract they follow:

> **Every new `VotingAjax` POST `fetch` MUST send the header** `'X-CSRF-Token': (window.VOTING_CSRF || '')`. Any action whose name is **not** in the `$read_actions` allowlist in the `Controller_VotingAjax` constructor is automatically required to be POST **and** to carry a valid token — so a new mutation action needs zero gate code. Only if you add a **GET read** endpoint do you append its lowercase name to `$read_actions`.

- **Bootstrap global name:** `window.VOTING_CSRF` (mirrors `window.CMS_CSRF`).
- **Header name:** `X-CSRF-Token` (read server-side as `$_SERVER['HTTP_X_CSRF_TOKEN']`, with `$this->request->csrf_token` / `$_POST['csrf_token']` as a fallback for plain-form posts).
- **Mint:** `Controller::_csrfToken()` (base class), lazily `bin2hex(random_bytes(32))`, stored at `$this->session->csrf_token`.
- **Validate:** `Controller_VotingAjax` constructor, `hash_equals()`, only for non-read actions; also rejects GET-triggered mutations.

---

## File Structure

| File | Responsibility (this plan) |
|---|---|
| `system/lib/system/class.Controller.php` | NEW `_csrfToken()` — shared per-session token mint (base class, reused by CMS-style pattern). |
| `orkui/controller/controller.VotingAjax.php` | CSRF gate in constructor (validate non-read POST actions); NEW admin-only `voter_choices()` reveal endpoint. |
| `orkui/controller/controller.Voting.php` | Emit `VotingCsrf` to page data; validate CSRF on the `create` form POST; open the `audit()` action to event runners (voter-redacted for non-admins). |
| `system/lib/ork3/class.Voting.php` | `audit_log()` gains detail-decode + voter-redaction projection; NEW guarded `voter_choices()` reader that writes an `admin_voter_choice_view` audit row before returning data. |
| `orkui/template/revised-frontend/Voting_edit.tpl` | Emit `window.VOTING_CSRF`; add header to 11 POST fetches; remove `anonymous_to_runner` config toggle + its JS append. |
| `orkui/template/revised-frontend/Voting_runner.tpl` | Emit `window.VOTING_CSRF`; add header to 4 POST fetches; make Audit Log tab runner-visible; remove `anonymous` chip. |
| `orkui/template/revised-frontend/Voting_event.tpl` | Emit `window.VOTING_CSRF`; add header to the `cast` fetch. |
| `orkui/template/revised-frontend/Voting_create.tpl` | Hidden `csrf_token` input; remove `AnonymousToRunner` checkbox. |
| `orkui/template/revised-frontend/Voting_audit.tpl` | Decode `detail` into human phrases; add missing action labels; admin-only "Reveal a voter's ballot" panel (POSTs to `voter_choices`). |

---

## Task 1 — Base CSRF token mint (`_csrfToken()`)

**Files:** `system/lib/system/class.Controller.php`

**Interfaces:**
- Produces: `Controller::_csrfToken(): string` — 64-hex-char per-session token, stored at `$this->session->csrf_token`, stable for the session's life.
- Consumes: `$this->session` (the `Session` magic-property store already set in `Controller::__construct`).

- [ ] **Step 1** — Read `system/lib/system/class.Controller.php` and confirm `__construct` sets `$this->session = $Session` (it does, ~line 22). Note the class has NO existing `_csrfToken` (grep confirmed none in the repo).
- [ ] **Step 2** — Add the mint method. Insert immediately after the `__construct` method's closing brace (find the first `\t}` that closes the constructor). Add:
```php
	/**
	 * Per-session CSRF synchronizer token. Lazily minted, stable for the session.
	 * Mirrors the CMS X-CSRF-Token pattern. Used by VotingAjax mutation gating.
	 */
	public function _csrfToken()
	{
		if (!isset($this->session->csrf_token) || !is_string($this->session->csrf_token) || strlen($this->session->csrf_token) !== 64) {
			$this->session->csrf_token = bin2hex(random_bytes(32));
		}
		return $this->session->csrf_token;
	}
```
- [ ] **Step 3** — Verify no syntax error:
```bash
docker exec ork3-php8-app php -l /var/www/html/system/lib/system/class.Controller.php
```
Expected: `No syntax errors detected in ...class.Controller.php`.
- [ ] **Step 4** — `git add system/lib/system/class.Controller.php && git commit -m "Voting/CSRF: add per-session _csrfToken() mint to base Controller"`

---

## Task 2 — CSRF gate in `VotingAjax` constructor

**Files:** `orkui/controller/controller.VotingAjax.php`

**Interfaces:**
- Consumes: `_csrfToken()` (Task 1); `$_SERVER['HTTP_X_CSRF_TOKEN']`; the constructor's `$call` arg = the action name.
- Produces: hard rejection (`status:1`, HTTP 419) of any non-read action that is not a valid-token POST. Read-allowlist: `tally`, `banner`, `candidate_search`, `voter_search`, `preview_resume` (the only GET endpoints — confirmed against every `public function` in the file).

- [ ] **Step 1** — Read `controller.VotingAjax.php:1-30`. Confirm the constructor is:
```php
	public function __construct($call = null, $id = null)
	{
		parent::__construct($call, $id);
		$this->load_model('Voting');
		header('Content-Type: application/json');
	}
```
and that `fail()` is defined at line ~12 (it is).
- [ ] **Step 2** — Replace that constructor body's final `header('Content-Type: application/json');` line so the gate runs after the JSON content-type is set. Change:
```php
		$this->load_model('Voting');
		header('Content-Type: application/json');
	}
```
to:
```php
		$this->load_model('Voting');
		header('Content-Type: application/json');
		$this->_csrf_gate($call);
	}

	/**
	 * CSRF + method gate. Any action NOT on the GET read-allowlist must be a POST
	 * carrying a valid X-CSRF-Token header (window.VOTING_CSRF). New mutation
	 * actions are auto-protected — do not add them here. Reject GET-triggered mutations.
	 */
	private function _csrf_gate($call)
	{
		$read_actions = ['tally', 'banner', 'candidate_search', 'voter_search', 'preview_resume'];
		$action = strtolower((string)$call);
		if (in_array($action, $read_actions, true)) {
			return;
		}
		if (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'POST') {
			http_response_code(405);
			$this->fail('This action must be submitted as POST.');
		}
		$sent = $_SERVER['HTTP_X_CSRF_TOKEN'] ?? ($this->request->csrf_token ?? '');
		if (!is_string($sent) || !hash_equals($this->_csrfToken(), $sent)) {
			http_response_code(419);
			$this->fail('Invalid or expired request token. Reload the page and try again.');
		}
	}
```
- [ ] **Step 3** — `docker exec ork3-php8-app php -l /var/www/html/orkui/controller/controller.VotingAjax.php` → expect `No syntax errors detected`.
- [ ] **Step 4** — Curl proof the gate REJECTS a tokenless mutation (see Task 3 for the login helper; run this after Task 3's global is emitted, or now with a stale token — either way a tokenless POST must fail). Log in once to `cookies.txt`, then:
```bash
curl -s -b cookies.txt -X POST 'http://localhost:19080/orkui/index.php?Route=VotingAjax/publish/1'
```
Expected JSON: `{"status":1,"error":"Invalid or expired request token. Reload the page and try again.",...}` (HTTP 419).
- [ ] **Step 5** — `git add orkui/controller/controller.VotingAjax.php && git commit -m "Voting/CSRF: gate every non-read VotingAjax action on POST + X-CSRF-Token"`

---

## Task 3 — Emit `window.VOTING_CSRF` + add the header to existing fetches

**Files:** `orkui/controller/controller.Voting.php`, `orkui/template/revised-frontend/Voting_runner.tpl`, `orkui/template/revised-frontend/Voting_edit.tpl`, `orkui/template/revised-frontend/Voting_event.tpl`

**Interfaces:**
- Produces: `$this->data['VotingCsrf']` (string) on every `Controller_Voting` page; `window.VOTING_CSRF` (JS string) on each rendered page; the header on all 16 existing mutating fetches.
- Consumes: `_csrfToken()` (Task 1).

- [ ] **Step 1** — In `controller.Voting.php` `__construct`, after `$this->load_model('Reports');` (line ~11), add:
```php
		$this->data['VotingCsrf'] = $this->_csrfToken();
```
- [ ] **Step 2** — In `Voting_runner.tpl`, find the main script open at line ~161 (`<script>` right after the `revised.js` include on line 160). Insert BEFORE that `<script>`:
```php
<script>window.VOTING_CSRF = <?= json_encode($VotingCsrf ?? '') ?>;</script>
```
- [ ] **Step 3** — In `Voting_runner.tpl`, add the header to each of the 4 POST fetches (`publish` ~324, `unpublish` ~333, `reopen_event` ~351 and ~357). For each, change `{ method:'POST', credentials:'same-origin' }` (or `{ method:'POST', body:data, credentials:'same-origin' }`) to include `headers:{'X-CSRF-Token': (window.VOTING_CSRF||'')}`. Example — line ~324:
```js
			fetch('<?= UIR ?>VotingAjax/publish/' + eventId, { method:'POST', headers:{'X-CSRF-Token': (window.VOTING_CSRF||'')}, credentials:'same-origin' })
```
Apply the same `headers:{...}` insertion to the `unpublish` fetch and BOTH `reopen_event` fetches (they carry `body:data`/`body:d2` — keep the body, add the header key alongside).
- [ ] **Step 4** — In `Voting_edit.tpl`, insert BEFORE the main `<script>` (line ~370, after the `revised.js` include line 369):
```php
<script>window.VOTING_CSRF = <?= json_encode($VotingCsrf ?? '') ?>;</script>
```
- [ ] **Step 5** — In `Voting_edit.tpl`, add `headers:{'X-CSRF-Token': (window.VOTING_CSRF||'')}` to EACH of the 11 POST fetches: `add_race` (~412), `add_candidate` (~460), `remove_choice` (~474), `add_option` (~491), `open_event` (~502), `reopen_event` (~514, ~520), `edit_race` (~555), `edit_choice` (~598), `restore_choice` (~611), `remove_race` (~624), `resume_event` (~661), `edit_event` (~711), `edit_race_settings` (~738). Leave the two GET fetches unchanged: `candidate_search` (~432) and `preview_resume` (~671). Pattern (keep any existing `body:`):
```js
			fetch('<?= UIR ?>VotingAjax/add_race/' + eventId, { method:'POST', body:data, headers:{'X-CSRF-Token': (window.VOTING_CSRF||'')}, credentials:'same-origin' })
```
- [ ] **Step 6** — In `Voting_event.tpl`, insert BEFORE its `<script>` (line ~161):
```php
<script>window.VOTING_CSRF = <?= json_encode($VotingCsrf ?? '') ?>;</script>
```
- [ ] **Step 7** — In `Voting_event.tpl`, add the header to the `cast` fetch (~255):
```js
		fetch('<?= UIR ?>VotingAjax/cast/' + eventId, { method:'POST', body:fd, headers:{'X-CSRF-Token': (window.VOTING_CSRF||'')}, credentials:'same-origin' })
```
- [ ] **Step 8** — `php -l` each edited template (plain-PHP templates parse):
```bash
for f in Voting_runner Voting_edit Voting_event; do docker exec ork3-php8-app php -l /var/www/html/orkui/template/revised-frontend/$f.tpl; done
docker exec ork3-php8-app php -l /var/www/html/orkui/controller/controller.Voting.php
```
Expected: `No syntax errors detected` for all four.
- [ ] **Step 9** — End-to-end CSRF proof. Log in (bypass accepts any password) and grab the emitted token:
```bash
# 1. login → cookie jar
curl -s -c cookies.txt 'http://localhost:19080/orkui/index.php?Route=Login/login' \
  --data 'username=<known_user>&password=x' -o /dev/null
# 2. read the token the runner page emits (event 1 must exist + you are its runner)
TOKEN=$(curl -s -b cookies.txt 'http://localhost:19080/orkui/index.php?Route=Voting/runner/1' \
  | grep -o 'window.VOTING_CSRF = "[a-f0-9]\{64\}"' | grep -o '[a-f0-9]\{64\}')
echo "token=$TOKEN"
# 3. WITH token → accepted (status 0 or a domain error, NOT the 419 token error)
curl -s -b cookies.txt -X POST -H "X-CSRF-Token: $TOKEN" \
  'http://localhost:19080/orkui/index.php?Route=VotingAjax/publish/1'
# 4. WITHOUT token → rejected
curl -s -b cookies.txt -X POST \
  'http://localhost:19080/orkui/index.php?Route=VotingAjax/publish/1'
```
Expected: step 3 returns NO `Invalid or expired request token` (publish either succeeds `status:0` or fails on its own rules, e.g. "Cannot publish… unresolved tie"); step 4 returns `{"status":1,"error":"Invalid or expired request token..."}`.
- [ ] **Step 10** — `git add orkui/controller/controller.Voting.php orkui/template/revised-frontend/Voting_runner.tpl orkui/template/revised-frontend/Voting_edit.tpl orkui/template/revised-frontend/Voting_event.tpl && git commit -m "Voting/CSRF: emit window.VOTING_CSRF and send X-CSRF-Token on all mutating fetches"`

---

## Task 4 — CSRF on the `Voting/create` HTML-form POST

**Files:** `orkui/controller/controller.Voting.php`, `orkui/template/revised-frontend/Voting_create.tpl`

**Interfaces:**
- The create form is a plain `<form method="POST">` (not a fetch), so it uses the `$_POST['csrf_token']` fallback, not the header.
- Consumes: `_csrfToken()`.

- [ ] **Step 1** — In `Voting_create.tpl`, the form opens at line ~63 (`<form method="POST" class="vtc-card">`) and already has a hidden `Action` input at line ~64. Immediately after line 64 add:
```php
			<input type="hidden" name="csrf_token" value="<?= htmlspecialchars($VotingCsrf ?? '', ENT_QUOTES) ?>" />
```
- [ ] **Step 2** — In `controller.Voting.php` `create()`, the submit branch begins at line ~84 (`if (!empty($this->request->Action) && $this->request->Action === 'create_event') {`). Insert a token check as the FIRST statement inside that `if`:
```php
			if (!hash_equals($this->_csrfToken(), (string)($this->request->csrf_token ?? ''))) {
				$this->data['Error'] = 'Invalid or expired request token. Reload and try again.';
				$this->template = '../revised-frontend/Voting_create.tpl';
				return;
			}
```
- [ ] **Step 3** — `php -l` both files:
```bash
docker exec ork3-php8-app php -l /var/www/html/orkui/controller/controller.Voting.php
docker exec ork3-php8-app php -l /var/www/html/orkui/template/revised-frontend/Voting_create.tpl
```
Expected: `No syntax errors detected` for both.
- [ ] **Step 4** — Curl proof: POST the create form without a token → the page re-renders with the token error (not an event). With `Action=create_event` and no `csrf_token`:
```bash
curl -s -b cookies.txt -X POST 'http://localhost:19080/orkui/index.php?Route=Voting/create/Kingdom_1' \
  --data 'Action=create_event&EventType=althing&Title=t&StartDate=2026-01-01+00:00&EndDate=2026-12-31+00:00' \
  | grep -o 'Invalid or expired request token'
```
Expected: prints `Invalid or expired request token`.
- [ ] **Step 5** — `git add orkui/controller/controller.Voting.php orkui/template/revised-frontend/Voting_create.tpl && git commit -m "Voting/CSRF: protect the create-event form POST with a hidden csrf_token"`

---

## Task 5 — Finding 30: event runners can read their own audit log (voter-redacted)

**Files:** `system/lib/ork3/class.Voting.php`, `orkui/controller/controller.Voting.php`, `orkui/template/revised-frontend/Voting_runner.tpl`

**Design decision (resolves the Finding-30 × Finding-31 interaction):** Because Finding 31 removes `anonymous_to_runner`, the runner audit view does **not** key redaction on that (now-deleted) flag. Instead it **always** redacts voter-identifying data for non-admin viewers: only a site admin (`AUTH_ADMIN`) ever sees voter identities, and even then only through the audited `voter_choices()` path (Task 7). This is strictly safer than a per-event flag and removes the cross-finding coupling.

**Interfaces:**
- Produces: `Voting::audit_log($voting_event_id, $limit = 500, $redact_voters = false): array` — each row gains `detail_data` (decoded array or `null`) and, when `$redact_voters`, has voter-identifying keys stripped from `detail_data` and its actor name blanked for voter-cast actions.
- Consumes (controller): `user_is_runner_of_event($uid, $voting_event_id)`, `HasAuthority(...AUTH_ADMIN...)`.
- Redaction sets: voter-identifying detail keys = `['voter_mundane_id','mundane_id','ballot_id','prior_ballot_id','superseded_ballot_id']`; actor-is-voter actions (blank the actor column) = `['ballot_cast','ballot_changed']`.

- [ ] **Step 1** — In `class.Voting.php`, read `audit_log()` (line ~272). Replace it with a version that decodes detail and applies optional redaction:
```php
	public function audit_log($voting_event_id, $limit = 500, $redact_voters = false)
	{
		global $DB;
		$DB->Clear();
		$rs = $DB->DataSet("SELECT a.*, m.username, m.persona FROM " . DB_PREFIX . "voting_audit a
			LEFT JOIN " . DB_PREFIX . "mundane m ON m.mundane_id = a.actor_mundane_id
			WHERE a.voting_event_id = " . (int)$voting_event_id . " ORDER BY a.created_at DESC, a.voting_audit_id DESC LIMIT " . (int)$limit);
		$voter_keys = ['voter_mundane_id', 'mundane_id', 'ballot_id', 'prior_ballot_id', 'superseded_ballot_id'];
		$actor_is_voter = ['ballot_cast', 'ballot_changed'];
		$rows = [];
		while ($rs && $rs->Next()) {
			$row = (array)$rs;
			$decoded = ($row['detail'] ?? null) !== null ? json_decode($row['detail'], true) : null;
			$row['detail_data'] = is_array($decoded) ? $decoded : null;
			if ($redact_voters) {
				if (is_array($row['detail_data'])) {
					foreach ($voter_keys as $k) {
						unset($row['detail_data'][$k]);
					}
				}
				if (in_array($row['action'], $actor_is_voter, true)) {
					$row['username'] = null;
					$row['persona']  = 'A voter';
				}
			}
			$rows[] = $row;
		}
		return $rows;
	}
```
- [ ] **Step 2** — In `controller.Voting.php`, replace the `audit()` action (line ~245-257). New body opens the log to event runners and redacts for non-admins:
```php
	public function audit($voting_event_id = null)
	{
		$this->require_login();
		$voting_event_id = (int)$voting_event_id;
		$uid = (int)$this->session->user_id;
		if (!$this->Voting->user_is_runner_of_event($uid, $voting_event_id)) {
			header('Location: ' . UIR . 'Voting/results/' . $voting_event_id);
			exit;
		}
		$is_admin = Ork3::$Lib->authorization->HasAuthority($uid, AUTH_ADMIN, 0, AUTH_ADMIN);
		$this->data['is_admin'] = $is_admin;
		$this->data['rows'] = $this->Voting->audit_log($voting_event_id, 500, !$is_admin);
		$this->data['voting_event_id'] = $voting_event_id;
		$this->template = '../revised-frontend/Voting_audit.tpl';
	}
```
- [ ] **Step 3** — In `Voting_runner.tpl` line ~95, the Audit Log tab is admin-gated. Make it runner-visible (any dashboard viewer is already a runner — the controller enforces it). Change:
```php
			<?php if ($is_admin): ?><button class="vtr-tab" data-pane="audit"><a href="<?= UIR ?>Voting/audit/<?= $voting_event_id ?>" style="color:inherit;text-decoration:none;">Audit Log</a></button><?php endif; ?>
```
to:
```php
			<button class="vtr-tab" data-pane="audit"><a href="<?= UIR ?>Voting/audit/<?= $voting_event_id ?>" style="color:inherit;text-decoration:none;">Audit Log</a></button>
```
- [ ] **Step 4** — `php -l` all three:
```bash
docker exec ork3-php8-app php -l /var/www/html/system/lib/ork3/class.Voting.php
docker exec ork3-php8-app php -l /var/www/html/orkui/controller/controller.Voting.php
docker exec ork3-php8-app php -l /var/www/html/orkui/template/revised-frontend/Voting_runner.tpl
```
Expected: `No syntax errors detected` for all.
- [ ] **Step 5** — Authorization proof. Pick event 1 whose runner is a non-admin officer, plus an unrelated user. As the **runner** (non-admin):
```bash
curl -s -b runner_cookies.txt 'http://localhost:19080/orkui/index.php?Route=Voting/audit/1' | grep -o 'Audit Log'
```
Expected: prints `Audit Log` (page renders; previously redirected). Confirm redaction — a `ballot_cast` row's Actor cell shows `A voter`, not a name:
```bash
curl -s -b runner_cookies.txt 'http://localhost:19080/orkui/index.php?Route=Voting/audit/1' | grep -c 'A voter'
```
Expected: `>= 1` if any ballots were cast. As an **unrelated** user:
```bash
curl -s -o /dev/null -w '%{http_code} %{redirect_url}\n' -b other_cookies.txt \
  'http://localhost:19080/orkui/index.php?Route=Voting/audit/1'
```
Expected: a redirect to `.../Voting/results/1` (denied).
- [ ] **Step 6** — `git add system/lib/ork3/class.Voting.php orkui/controller/controller.Voting.php orkui/template/revised-frontend/Voting_runner.tpl && git commit -m "Voting: event runners can read own audit log; voter identities redacted for non-admins"`

---

## Task 6 — Finding 31: remove the inert `anonymous_to_runner` toggle

**Files:** `orkui/template/revised-frontend/Voting_create.tpl`, `orkui/template/revised-frontend/Voting_edit.tpl`, `orkui/template/revised-frontend/Voting_runner.tpl`

**Decision (RECOMMENDED — remove):** `anonymous_to_runner` is inert. The runner dashboard exposes only aggregate counts + tally; there is **no** per-voter runner projection anywhere (confirmed: `Voting_runner.tpl` has no voter-list surface — only `counts` and the tally host). The flag therefore protects nothing, defaults off, and advertises an anonymity guarantee the code never delivered. Removing the three UI surfaces stops the false promise with near-zero risk. Task 5 already made the runner audit view redact voters unconditionally, so nothing depends on the flag.
- **Non-destructive:** leave the `ork_voting_event.anonymous_to_runner` column in place (no migration). With the inputs gone, `!empty($request['AnonymousToRunner'])` evaluates to `0` in `CreateEvent`/`EditEvent`, so the column simply pins to 0 — no service edits needed. Mark it deprecated in a code comment.
- **Alternative (NOT chosen — build it):** Implement the spec §5.3 runner "Voter list" tab (name/cast-time/provisional/external per voter when off; counts-only when on) and honor the flag there. Far larger: new model projection, new runner AJAX action + tab UI, and it *introduces* a de-anonymization surface (runner-visible voter list) that today does not exist — net-new anonymity risk for a feature no one has requested. Deferred.

- [ ] **Step 1** — In `Voting_create.tpl`, delete the Anonymous toggle block (lines ~100-106): the `<div class="vtc-toggle">` wrapping `#vtc-anon` through its closing `</div>`. Leave the `#vtc-hide` and `#vtc-prov` toggles intact.
- [ ] **Step 2** — In `Voting_edit.tpl` line ~157, delete the config toggle:
```php
				<div class="vte-toggle"><input id="vte-cfg-anon" type="checkbox" <?= !empty($event['anonymous_to_runner']) ? 'checked' : '' ?> /><label for="vte-cfg-anon">Anonymous to runner (runners cannot see who voted what)</label></div>
```
- [ ] **Step 3** — In `Voting_edit.tpl` line ~708, delete the JS append that referenced the removed input:
```js
		data.append('AnonymousToRunner', $('#vte-cfg-anon').checked ? 1 : 0);
```
- [ ] **Step 4** — In `Voting_runner.tpl`, delete the anonymity chip (lines ~76-78):
```php
				<?php if (!empty($event['anonymous_to_runner'])): ?>
					<span class="rp-scope-chip" style="cursor:default;"><i class="fas fa-user-secret"></i> anonymous</span>
				<?php endif; ?>
```
- [ ] **Step 5** — Add a one-line deprecation comment above `class.Voting.php` line ~429 (`$this->Event->anonymous_to_runner = ...`) so the next reader knows why it always writes 0:
```php
		// DEPRECATED: anonymous_to_runner UI removed (was inert — no per-voter runner projection existed).
		// Column retained non-destructively; always pins to 0. Runner audit view redacts voters unconditionally.
```
- [ ] **Step 6** — `php -l` the three templates + the service:
```bash
for f in Voting_create Voting_edit Voting_runner; do docker exec ork3-php8-app php -l /var/www/html/orkui/template/revised-frontend/$f.tpl; done
docker exec ork3-php8-app php -l /var/www/html/system/lib/ork3/class.Voting.php
```
Expected: `No syntax errors detected` for all four.
- [ ] **Step 7** — Verify the toggle is gone from all UI:
```bash
curl -s -b cookies.txt 'http://localhost:19080/orkui/index.php?Route=Voting/create/Kingdom_1' | grep -c 'vtc-anon'
curl -s -b cookies.txt 'http://localhost:19080/orkui/index.php?Route=Voting/edit/1'         | grep -c 'vte-cfg-anon'
```
Expected: `0` from both. Grep proof no orphan references remain:
```bash
grep -rn 'vtc-anon\|vte-cfg-anon\|AnonymousToRunner\|user-secret.*anonymous' \
  orkui/template/revised-frontend/Voting_*.tpl
```
Expected: no matches in the templates (the `.fa-user-secret` CSS glyph in `orkui.css` is shared and stays).
- [ ] **Step 8** — `git add orkui/template/revised-frontend/Voting_create.tpl orkui/template/revised-frontend/Voting_edit.tpl orkui/template/revised-frontend/Voting_runner.tpl system/lib/ork3/class.Voting.php && git commit -m "Voting: remove inert anonymous_to_runner toggle (never implemented); mark column deprecated"`

---

## Task 7 — Finding 32: audited `admin_voter_choice_view` on any per-voter choice read

**Files:** `system/lib/ork3/class.Voting.php`, `orkui/controller/controller.VotingAjax.php`, `orkui/template/revised-frontend/Voting_audit.tpl`

**Decision:** Today an admin can silently reconstruct any named member's ballot straight from `ork_voting_ballot`/`ork_voting_vote` with zero trace. The concrete, in-scope deliverable is a **single guarded read path**: `Voting::voter_choices()` writes an `admin_voter_choice_view` audit row **before** returning the voter→choice mapping, and a thin admin-only `VotingAjax/voter_choices` endpoint (a mutation → auto-CSRF-gated by Task 2) plus a minimal reveal panel on the audit page exercise it. **Full cryptographic secret-ballot decoupling** (breaking the `voter_mundane_id` ↔ vote linkage so even a DB admin cannot reconstruct it) is a **documented FUTURE item** — it needs a new ballot-token table + migration + a rewrite of the supersede/tally paths, which is out of scope here; noted, not planned.

**Interfaces:**
- Produces: `Voting::voter_choices($voting_event_id, $voter_mundane_id, $viewer_mundane_id): array` — writes `audit(..., 'admin_voter_choice_view', ['voter_mundane_id'=>N], $viewer)` then returns rows `['race_title','label','candidate_mundane_id','rank','is_abstain','is_none_of_above']` for the voter's active ballot.
- Produces: `VotingAjax::voter_choices($voting_event_id)` — admin-only POST; body `VoterMundaneId`; returns `{status:0, choices:[...]}`.
- Consumes: existing `audit()` private helper; `active_ballot` → `vote` join.

- [ ] **Step 1** — In `class.Voting.php`, add the guarded reader immediately AFTER `user_is_candidate_in_event()` (ends ~line 191). The audit write comes FIRST so a read that later errors still leaves a trace:
```php
	/**
	 * Admin-only voter→choice reveal for a single voter's active ballot.
	 * Writes an admin_voter_choice_view audit row BEFORE returning data — this is
	 * the ONLY sanctioned per-voter read path. (Full secret-ballot decoupling is a
	 * documented future item; see plan-5-security-audit.md.)
	 */
	public function voter_choices($voting_event_id, $voter_mundane_id, $viewer_mundane_id)
	{
		$voting_event_id = (int)$voting_event_id;
		$voter_mundane_id = (int)$voter_mundane_id;
		$this->audit($voting_event_id, 'admin_voter_choice_view', ['voter_mundane_id' => $voter_mundane_id], (int)$viewer_mundane_id);

		global $DB;
		$DB->Clear();
		$rs = $DB->DataSet("SELECT r.title AS race_title, r.display_order, c.label, c.candidate_mundane_id,
				v.rank, v.is_abstain, v.is_none_of_above
			FROM " . DB_PREFIX . "voting_active_ballot ab
			JOIN " . DB_PREFIX . "voting_vote v ON v.voting_ballot_id = ab.voting_ballot_id
			JOIN " . DB_PREFIX . "voting_race r ON r.voting_race_id = v.voting_race_id
			LEFT JOIN " . DB_PREFIX . "voting_choice c ON c.voting_choice_id = v.voting_choice_id
			WHERE ab.voting_event_id = " . $voting_event_id . " AND ab.voter_mundane_id = " . $voter_mundane_id . "
			ORDER BY r.display_order, v.rank");
		$out = [];
		while ($rs && $rs->Next()) {
			$out[] = (array)$rs;
		}
		return $out;
	}
```
- [ ] **Step 2** — In `controller.VotingAjax.php`, add the admin-only endpoint after `voter_search()` (ends ~line 349). It is a mutation (writes audit) → not on the read-allowlist → already CSRF/POST-gated by Task 2:
```php
	// Admin-only voter->choice reveal. Writes an admin_voter_choice_view audit row.
	// POST + X-CSRF-Token enforced by the constructor gate (not a read action).
	public function voter_choices($voting_event_id = null)
	{
		$this->require_login();
		$voting_event_id = (int)$voting_event_id;
		$uid = (int)$this->session->user_id;
		if (!Ork3::$Lib->authorization->HasAuthority($uid, AUTH_ADMIN, 0, AUTH_ADMIN)) {
			$this->fail('Only ORK administrators may reveal an individual ballot.');
		}
		$voter_id = (int)$this->request->VoterMundaneId;
		if (!$voter_id) {
			$this->fail('Voter required.');
		}
		$choices = $this->Voting->voter_choices($voting_event_id, $voter_id, $uid);
		$this->ok(['choices' => $choices]);
	}
```
- [ ] **Step 3** — In `Voting_audit.tpl`, add an admin-only reveal panel + its script. Insert AFTER the closing `</div><!-- /rp-root -->` region's table block — specifically before the final `</div>` on line ~71, add (uses `window.VOTING_CSRF`, so also emit the global):
```php
<?php if (!empty($is_admin)): ?>
	<div class="vta-wrap" style="margin-top:16px;">
		<div style="border:1px solid var(--vta-card-border,#e2e8f0);border-radius:8px;padding:12px;">
			<div style="font-weight:600;margin-bottom:8px;">Reveal a voter's ballot (ORK admin — audited)</div>
			<div style="font-size:12px;color:#718096;margin-bottom:8px;">Every reveal writes an <code>admin_voter_choice_view</code> audit row.</div>
			<input id="vta-reveal-id" type="number" min="1" placeholder="Voter mundane id" style="padding:8px;border:1px solid #cbd5e0;border-radius:6px;" />
			<button id="vta-reveal-go" type="button" class="vta-action-pill" style="cursor:pointer;border:none;">Reveal</button>
			<div id="vta-reveal-out" style="margin-top:10px;font-size:13px;"></div>
		</div>
	</div>
	<script>window.VOTING_CSRF = <?= json_encode($VotingCsrf ?? '') ?>;</script>
	<script>
	(function(){
		var go = document.getElementById('vta-reveal-go');
		if (!go) return;
		go.addEventListener('click', function(){
			var vid = parseInt(document.getElementById('vta-reveal-id').value, 10);
			var out = document.getElementById('vta-reveal-out');
			if (!vid) { out.textContent = 'Enter a voter id.'; return; }
			fetch('<?= UIR ?>VotingAjax/voter_choices/<?= (int)$voting_event_id ?>', {
				method:'POST',
				headers:{'X-CSRF-Token': (window.VOTING_CSRF||''), 'Content-Type':'application/x-www-form-urlencoded'},
				credentials:'same-origin',
				body:'VoterMundaneId=' + vid
			}).then(function(r){ return r.json(); }).then(function(j){
				if (j.status !== 0) { out.textContent = j.error || 'Failed'; return; }
				if (!j.choices || !j.choices.length) { out.textContent = 'No active ballot for that voter.'; return; }
				var lines = j.choices.map(function(c){
					var pick = c.is_abstain == 1 ? '(abstain)' : (c.is_none_of_above == 1 ? '(none of the above)' : (c.label || ''));
					var rank = c.rank ? ' [rank ' + c.rank + ']' : '';
					return (c.race_title || '') + ': ' + pick + rank;
				});
				out.innerHTML = lines.map(function(l){ return l.replace(/[<>&]/g, ''); }).join('<br>');
			});
		});
	})();
	</script>
<?php endif; ?>
```
Note: `$VotingCsrf` reaches this template because `Controller_Voting::__construct` sets it for every action, including `audit()` (Task 3, Step 1).
- [ ] **Step 4** — `php -l` all three:
```bash
docker exec ork3-php8-app php -l /var/www/html/system/lib/ork3/class.Voting.php
docker exec ork3-php8-app php -l /var/www/html/orkui/controller/controller.VotingAjax.php
docker exec ork3-php8-app php -l /var/www/html/orkui/template/revised-frontend/Voting_audit.tpl
```
Expected: `No syntax errors detected` for all.
- [ ] **Step 5** — Audit-write proof. As an **admin**, count `admin_voter_choice_view` rows before/after a reveal (`<eid>` open with a cast ballot from `<voterid>`):
```bash
BEFORE=$(docker exec -i ork3-php8-db mariadb -u root -proot ork -N -e \
  "SELECT COUNT(*) FROM ork_voting_audit WHERE voting_event_id=<eid> AND action='admin_voter_choice_view'")
TOKEN=$(curl -s -b admin_cookies.txt 'http://localhost:19080/orkui/index.php?Route=Voting/audit/<eid>' | grep -o '[a-f0-9]\{64\}' | head -1)
curl -s -b admin_cookies.txt -X POST -H "X-CSRF-Token: $TOKEN" \
  --data 'VoterMundaneId=<voterid>' \
  'http://localhost:19080/orkui/index.php?Route=VotingAjax/voter_choices/<eid>'
AFTER=$(docker exec -i ork3-php8-db mariadb -u root -proot ork -N -e \
  "SELECT COUNT(*) FROM ork_voting_audit WHERE voting_event_id=<eid> AND action='admin_voter_choice_view'")
echo "before=$BEFORE after=$AFTER"
```
Expected: the curl returns `{"status":0,"choices":[...]}` with the voter's picks, and `after == before + 1`.
- [ ] **Step 6** — Authorization proof. As a **non-admin runner**, the same endpoint is denied:
```bash
TOKEN=$(curl -s -b runner_cookies.txt 'http://localhost:19080/orkui/index.php?Route=Voting/runner/<eid>' | grep -o '[a-f0-9]\{64\}' | head -1)
curl -s -b runner_cookies.txt -X POST -H "X-CSRF-Token: $TOKEN" \
  --data 'VoterMundaneId=<voterid>' \
  'http://localhost:19080/orkui/index.php?Route=VotingAjax/voter_choices/<eid>'
```
Expected: `{"status":1,"error":"Only ORK administrators may reveal an individual ballot."}`.
- [ ] **Step 7** — `git add system/lib/ork3/class.Voting.php orkui/controller/controller.VotingAjax.php orkui/template/revised-frontend/Voting_audit.tpl && git commit -m "Voting: audited admin voter->choice reveal (writes admin_voter_choice_view); document future secret-ballot decoupling"`

---

## Task 8 — Finding 12 (+ parked Finding 50): human-readable audit Detail + missing labels

**Files:** `orkui/template/revised-frontend/Voting_audit.tpl`

**Interfaces:**
- Consumes: each `$rows[i]['detail_data']` (decoded array or `null`, produced by Task 5's `audit_log()`), `$rows[i]['action']`.
- Produces: the Detail cell renders a human phrase per action type instead of a raw JSON blob; adds `$action_labels` for `results_published`, `results_unpublished`, `tie_resolved`, `admin_voter_choice_view` (Finding 50).

- [ ] **Step 1** — In `Voting_audit.tpl`, extend the `$action_labels` map (ends ~line 54). Add before its closing `];`:
```php
					'results_published' => 'Results published',
					'results_unpublished' => 'Results unpublished',
					'tie_resolved' => 'Tie resolved',
					'admin_voter_choice_view' => 'Admin viewed a voter\'s ballot',
```
(Keep all existing entries; these four are the only additions. `event_resumed_keep`/`event_resumed_discard` etc. are already present in the map — do not duplicate them.)
- [ ] **Step 2** — Add a detail-phrase helper as a plain-PHP function at the top of the template's `<?php ... ?>` block (line 1, after the existing `$rows`/`$voting_event_id` normalization). Insert:
```php
<?php
if (!function_exists('vta_detail_phrase')) {
	function vta_detail_phrase($action, $d)
	{
		if (!is_array($d)) {
			return '';
		}
		$esc = function ($v) {
			return htmlspecialchars(is_scalar($v) ? (string)$v : json_encode($v), ENT_QUOTES);
		};
		switch ($action) {
			case 'event_created':
			case 'event_updated':
				return isset($d['title']) ? 'Title: ' . $esc($d['title']) : (isset($d['status']) ? 'Status: ' . $esc($d['status']) : '');
			case 'race_created':
			case 'race_wording_edited':
				return isset($d['title']) ? 'Race: ' . $esc($d['title']) : '';
			case 'choice_label_edited':
				return (isset($d['from'], $d['to'])) ? 'Label: ' . $esc($d['from']) . ' &rarr; ' . $esc($d['to']) : '';
			case 'tie_resolved':
				return isset($d['winner_choice_id']) ? 'Winner chosen: choice #' . $esc($d['winner_choice_id']) . (isset($d['justification']) ? ' — ' . $esc($d['justification']) : '') : '';
			case 'provisional_released_runner':
				return isset($d['reason']) ? 'Reason: ' . $esc($d['reason']) : '';
			case 'admin_voter_choice_view':
				return 'Revealed ballot of voter #' . $esc($d['voter_mundane_id'] ?? '(redacted)');
			case 'ballot_cast':
			case 'ballot_changed':
				return isset($d['is_provisional']) && $d['is_provisional'] ? 'Provisional ballot' : 'Ballot recorded';
		}
		// Fallback: compact key: value pairs (voter-identifying keys already stripped upstream when redacted).
		$parts = [];
		foreach ($d as $k => $v) {
			$parts[] = $esc($k) . ': ' . $esc($v);
		}
		return implode(', ', $parts);
	}
}
?>
```
- [ ] **Step 3** — Replace the raw-JSON Detail cell (line ~62):
```php
					<td class="vta-detail"><?= htmlspecialchars($r['detail'] ?? '') ?></td>
```
with the decoded phrase (falls back to empty when there is no detail):
```php
					<td class="vta-detail"><?= vta_detail_phrase($r['action'], $r['detail_data'] ?? null) ?></td>
```
- [ ] **Step 4** — `php -l`:
```bash
docker exec ork3-php8-app php -l /var/www/html/orkui/template/revised-frontend/Voting_audit.tpl
```
Expected: `No syntax errors detected`.
- [ ] **Step 5** — Render proof. Load the audit page as a runner/admin for an event with history and confirm phrases, not braces:
```bash
curl -s -b admin_cookies.txt 'http://localhost:19080/orkui/index.php?Route=Voting/audit/1' \
  | grep -o 'vta-detail">[^<]*' | head -5
```
Expected: human phrases (e.g. `Title: ...`, `Ballot recorded`, `Results published`) with NO `{"` JSON braces. Confirm the new labels render:
```bash
curl -s -b admin_cookies.txt 'http://localhost:19080/orkui/index.php?Route=Voting/audit/1' | grep -c 'Results published\|Tie resolved\|Admin viewed'
```
Expected: `>= 1` when such rows exist.
- [ ] **Step 6** — `git add orkui/template/revised-frontend/Voting_audit.tpl && git commit -m "Voting: render audit Detail as human phrases; add results/tie/admin-view action labels (Findings 12+50)"`

---

## Self-Review Checklist (every finding → a task; no placeholders; name/type consistency)
- **Finding 29 (CSRF):** Tasks 1-4. Gate in the VotingAjax constructor (Task 2) + `window.VOTING_CSRF`/`X-CSRF-Token` on all 16 fetches (Task 3) + create-form guard (Task 4). Contract documented for Domains 1/4/7 at the top.
- **Finding 30 (runner audit access):** Task 5 — `audit()` opens to `user_is_runner_of_event`, non-admins get `audit_log(..., $redact_voters=true)`; unrelated users redirected.
- **Finding 31 (`anonymous_to_runner` inert):** Task 6 — REMOVE the three UI surfaces + create-form checkbox; column retained non-destructively (pins to 0); alternative (build the voter-list projection) documented and rejected with rationale.
- **Finding 32 (voter→choice linkage):** Task 7 — single audited `voter_choices()` read path writes `admin_voter_choice_view` before returning; endpoint admin-only + CSRF-gated; full crypto secret-ballot decoupling documented as future, not planned.
- **Finding 12 (raw JSON Detail) + Finding 50 (missing labels):** Task 8 — `vta_detail_phrase()` renderer + four new `$action_labels`.
- **Name/type consistency:** `window.VOTING_CSRF` / `$_SERVER['HTTP_X_CSRF_TOKEN']` / `$this->session->csrf_token` / `_csrfToken()` used identically everywhere; `audit_log($id,$limit,$redact_voters)` signature matches its one caller; `voter_choices()` arg order `(event, voter, viewer)` matches controller call; `detail_data` produced in Task 5 and consumed in Tasks 7-8.
- **No placeholders:** every step shows the actual code/command. `<known_user>`, `<eid>`, `<voterid>` in verify commands are the only runtime values the operator supplies (local DB is per-branch — pick a real open event + its runner/voter).
- **Gotchas honored:** `(int)` casts on all ids; `$DB->Clear()` + `->Next()` in the new reader; templates are plain PHP; explicit `git add <files>` per commit (never `-A`); `class.Authorization.php` never touched.
