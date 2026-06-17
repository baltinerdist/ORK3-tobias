# Pronouns → Free-Text Field Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the structured pronoun dropdown + 5-column "Custom…" picker with a single, 40-char, profanity-checked free-text Pronouns field — relocated into Design My Profile › Name tab, removed from the Account modal, and added (non-required) to both Create Player modals — with a one-time SQL migration of existing data.

**Architecture:** New authoritative column `ork_mundane.pronoun_freetext`. The lib (`class.Player.php`) reads it directly for display and writes it (profanity-checked) on update/create. The `orkui/model` layer stays a thin pass-through; controllers only marshal the `Pronouns` request param. A pure-SQL migration adds the column and backfills the ~3,075 existing rows. Legacy pickers (Account modal, legacy `Admin_player.tpl`) and their now-dead picker JS are removed.

**Tech Stack:** PHP 8 (lib `system/lib/ork3`, MVC `orkui`), MariaDB (Docker `ork3-php8-db`), vanilla JS in `revised.js`, plain-PHP `.tpl` templates, php-cs-fixer (PSR-12).

**Spec:** `docs/superpowers/specs/2026-06-17-pronouns-free-text-field-design.md`

**Testing note:** This codebase has no unit-test harness for templates/JS/controllers; verification is by PHP lint (`php -l`), targeted `grep`, curl-auth AJAX exercises, and a browser dark-mode walk (per project conventions in CLAUDE/memory). Each task below states its concrete verification.

**Editing note (PSR-12 normalize-first):** Before a multi-line Edit on a PHP file, check `awk '/^\t/{c++} END{print c+0}' <file>` — `0` = clean (use Edit directly). If tab-indented, run `php tools/php-cs-fixer.phar fix --config=.php-cs-fixer.dist.php <file>` on that one file first, then Edit. Stage files explicitly; never `git add -A`; never stage `class.Authorization.php`; run `git diff --cached` before committing.

---

## File Structure

| File | Responsibility | Change |
|---|---|---|
| `db-migrations/2026-06-17-mundane-pronoun-freetext.sql` | schema + data | **Create** — add column + backfill |
| `system/lib/ork3/class.Player.php` | DB layer | display read; `UpdatePlayer` + `CreatePlayer` write/profanity |
| `orkui/controller/controller.PlayerAjax.php` | request marshalling | `updateprofile` + `create` pass `Pronouns` |
| `orkui/controller/controller.Player.php` | request marshalling | drop now-unused `PronounOptions`/`PronounList` |
| `orkui/template/revised-frontend/Playernew_index.tpl` | profile UI | add Name-tab field; remove Account-modal picker |
| `orkui/template/revised-frontend/script/revised.js` | profile JS | chip helper; design-save wiring; remove picker init+fn; create-modal wiring |
| `orkui/template/revised-frontend/style/revised.css` | styling | `.pn-pronoun-chips` / `.pn-pronoun-chip` (dark-mode) |
| `orkui/template/revised-frontend/Kingdomnew_index.tpl` | create UI | add Pronouns field |
| `orkui/template/revised-frontend/Parknew_index.tpl` | create UI | add Pronouns field |
| `orkui/template/default/Admin_player.tpl` + `controller.Admin.php` | legacy UI | remove legacy pronoun control (judgment call) |

---

## Task 1: SQL migration — add column + backfill

**Files:**
- Create: `db-migrations/2026-06-17-mundane-pronoun-freetext.sql`

- [ ] **Step 1: Write the migration file**

```sql
-- Pronouns redesign: single free-text column replaces the pronoun_id dropdown +
-- pronoun_custom JSON picker. Authoritative display source going forward.
-- ~3,075 rows have any pronoun set; backfill is pure SQL (MariaDB JSON funcs).
-- Output uses the new "subject/object" convention (matches the quick-fill chips).

ALTER TABLE ork_mundane
  ADD COLUMN pronoun_freetext VARCHAR(64) NOT NULL DEFAULT '';

-- 1) Custom JSON first (it took display precedence over the standard dropdown).
--    JSON shape: {"s":[id,...],"o":[id,...],"p":[...],"pp":[...],"r":[...]}.
--    Reduce to first subject id ($.s[0]) / first object id ($.o[0]) -> "he/him".
UPDATE ork_mundane m
  JOIN ork_pronoun ps ON ps.pronoun_id = CAST(JSON_UNQUOTE(JSON_EXTRACT(m.pronoun_custom, '$.s[0]')) AS UNSIGNED)
  JOIN ork_pronoun po ON po.pronoun_id = CAST(JSON_UNQUOTE(JSON_EXTRACT(m.pronoun_custom, '$.o[0]')) AS UNSIGNED)
SET m.pronoun_freetext = LEFT(CONCAT(ps.subject, '/', po.object), 64)
WHERE m.pronoun_freetext = ''
  AND m.pronoun_custom IS NOT NULL
  AND m.pronoun_custom <> ''
  AND JSON_VALID(m.pronoun_custom);

-- 2) Standard dropdown (pronoun_id) for rows still blank.
UPDATE ork_mundane m
  JOIN ork_pronoun p ON p.pronoun_id = m.pronoun_id
SET m.pronoun_freetext = LEFT(CONCAT(p.subject, '/', p.object), 64)
WHERE m.pronoun_freetext = ''
  AND m.pronoun_id IS NOT NULL
  AND m.pronoun_id > 0;
```

- [ ] **Step 2: Run the migration against the local DB**

Run:
```bash
docker exec -i ork3-php8-db mariadb -u root -proot ork < db-migrations/2026-06-17-mundane-pronoun-freetext.sql
```
Expected: no errors (the `JSON_EXTRACT` first-id misses on `[0]` sentinels are silently skipped, not errors).

- [ ] **Step 3: Spot-check the backfill**

Run:
```bash
docker exec -i ork3-php8-db mariadb -u root -proot ork -e "
SELECT
  SUM(pronoun_freetext <> '')                                 AS filled,
  SUM(pronoun_id IS NOT NULL AND pronoun_id > 0)              AS had_standard,
  SUM(pronoun_custom IS NOT NULL AND pronoun_custom <> '')    AS had_custom
FROM ork_mundane;
SELECT mundane_id, pronoun_id, pronoun_custom, pronoun_freetext
FROM ork_mundane
WHERE pronoun_freetext <> '' LIMIT 10;"
```
Expected: `filled` is close to `had_standard + had_custom` (minus any custom rows whose first-id is a `0` sentinel); sample rows show clean `subject/object` values like `he/him`, `she/her`.

- [ ] **Step 4: Commit**

```bash
git add db-migrations/2026-06-17-mundane-pronoun-freetext.sql
git commit -m "Enhancement: add mundane.pronoun_freetext column + backfill"
```

---

## Task 2: Backend — display reads `pronoun_freetext`

**Files:**
- Modify: `system/lib/ork3/class.Player.php:318-334` (GetPlayer display block)

- [ ] **Step 1: Replace the pronoun-display computation**

Delete lines 318–323 (the `$subject` / `$pronoun_custom` / `$pronountext` / `$pronouncustomArr` / `$pronouncustomtext` computation). Current text to remove:

```php
            $subject = $this->pronoun->subject;
            $pronoun_custom = $this->mundane->pronoun_custom;
            $pronountext = isset($subject) ? $this->pronoun->subject . '[' . $this->pronoun->object . ']' : '';
            $pronouncustomArr = (isset($pronoun_custom) && json_decode($this->mundane->pronoun_custom)) ? $this->Pronoun->fetch_custom_pronoun_display($this->mundane->pronoun_custom) : false;
            //$pronouncustomtext = json_encode($pronouncustomArr);
            $pronouncustomtext = (isset($pronouncustomArr) && $pronouncustomArr) ? implode('/', $pronouncustomArr['subjective']) . ' [' . implode('/', $pronouncustomArr['objective']) . ' ' . implode('/', $pronouncustomArr['possessive']) . ' ' . implode('/', $pronouncustomArr['possessivepronoun']) . ' ' . implode('/', $pronouncustomArr['reflexive']) . ']' : '';
```

(Leave the `$this->pronoun->...->find()` block at lines 302–304 untouched — it is cheap and may feed other consumers.)

- [ ] **Step 2: Point the response keys at the new column**

Change lines 333–334 from:

```php
                    'PronounText' => $pronountext,
                    'PronounCustomText' => $pronouncustomtext,
```
to:
```php
                    'PronounText' => $this->mundane->pronoun_freetext,
                    'PronounCustomText' => '',
```

(`Playernew_index.tpl:24` does `$Player['PronounCustomText'] ?: $Player['PronounText']`, so this resolves to the free-text value with no template change. `PronounId` / `PronounCustom` keys are left as-is.)

- [ ] **Step 3: Verify lint + that display resolves**

Run: `php -l system/lib/ork3/class.Player.php`
Expected: `No syntax errors detected`.

Run (curl-auth — uses the documented single-cookie-jar login, see memory `reference_local_curl_auth_session`):
```bash
# In ONE shell block: login then load a profile page known to have a pronoun.
```
Expected: profile hero shows the migrated pronoun string (e.g. `he/him`); no PHP 500 in `docker logs ork3-php8-app`.

- [ ] **Step 4: Commit**

```bash
git add system/lib/ork3/class.Player.php
git commit -m "Enhancement: read pronoun display from pronoun_freetext"
```

---

## Task 3: Backend — `UpdatePlayer` writes Pronouns (profanity-checked)

**Files:**
- Modify: `system/lib/ork3/class.Player.php:1313-1315` (after persona assignment)

- [ ] **Step 1: Add the Pronouns write + profanity check**

Immediately after line 1315 (`$this->mundane->pronoun_custom = ...`), insert:

```php
                // Pronouns — authoritative free-text display value (40-char cap),
                // profanity-checked. null = field not sent (preserve); '' = cleared.
                if (!is_null($request['Pronouns'])) {
                    require_once(__DIR__ . '/class.ProfanityFilter.php');
                    $_pf = new ProfanityFilter();
                    $_pronouns = substr(trim((string)$request['Pronouns']), 0, 40);
                    if ($_pronouns !== '' && $_pf->containsProfanity($_pronouns)) {
                        return InvalidParameter('Pronouns', ProfanityFilter::ERROR_MESSAGE);
                    }
                    $this->mundane->pronoun_freetext = $_pronouns;
                }
```

(Assigning `''` clears — never `null`, per the yapo null-skip rule. The profanity `return` fires before any `save()`, so no partial write.)

- [ ] **Step 2: Verify lint**

Run: `php -l system/lib/ork3/class.Player.php`
Expected: `No syntax errors detected`.

- [ ] **Step 3: Commit**

```bash
git add system/lib/ork3/class.Player.php
git commit -m "Enhancement: UpdatePlayer writes profanity-checked Pronouns"
```

---

## Task 4: Controller — `updateprofile` passes Pronouns

**Files:**
- Modify: `orkui/controller/controller.PlayerAjax.php:393` (inside the `updateprofile` `$fields` array)

- [ ] **Step 1: Add the Pronouns field to the request array**

In the `$fields` array (currently lines 375–405), add a line next to `PronunciationGuide` (line 393):

```php
					'Pronouns'      => isset($_POST['Pronouns']) ? trim($_POST['Pronouns']) : null,
```

(The existing profanity surfacing at lines 407–412 already maps `$r['Detail']` → `field`, so a `Pronouns` rejection returns `{status, error, field:'Pronouns'}` automatically.)

- [ ] **Step 2: Verify lint**

Run: `php -l orkui/controller/controller.PlayerAjax.php`
Expected: `No syntax errors detected`.

- [ ] **Step 3: Commit**

```bash
git add orkui/controller/controller.PlayerAjax.php
git commit -m "Enhancement: updateprofile passes Pronouns to UpdatePlayer"
```

---

## Task 5: Backend + controller — Create Player writes Pronouns

**Files:**
- Modify: `system/lib/ork3/class.Player.php:713-718` (CreatePlayer pronoun handling)
- Modify: `orkui/controller/controller.PlayerAjax.php:31-32,61-62,74-79` (create block)

- [ ] **Step 1: CreatePlayer — replace pronoun_id/custom write with free-text + profanity**

Replace lines 713–718:

```php
                if (!empty($request['PronounId'])) {
                    $this->mundane->pronoun_id     = (int)$request['PronounId'];
                }
                if (!empty($request['PronounCustom'])) {
                    $this->mundane->pronoun_custom = $request['PronounCustom'];
                }
```
with:
```php
                // Pronouns — free-text, profanity-checked, 40-char cap. Returns
                // before save() so a rejected entry creates no partial row.
                $_pronouns = isset($request['Pronouns']) ? substr(trim((string)$request['Pronouns']), 0, 40) : '';
                if ($_pronouns !== '') {
                    require_once(__DIR__ . '/class.ProfanityFilter.php');
                    $_pf = new ProfanityFilter();
                    if ($_pf->containsProfanity($_pronouns)) {
                        return InvalidParameter('Pronouns', ProfanityFilter::ERROR_MESSAGE);
                    }
                }
                $this->mundane->pronoun_freetext = $_pronouns;
```

- [ ] **Step 2: Controller create block — extract Pronouns instead of PronounId/Custom**

Replace lines 31–32:
```php
			$pronounId     = (int)($_POST['PronounId']    ?? 0);
			$pronounCustom = trim($_POST['PronounCustom'] ?? '');
```
with:
```php
			$pronouns      = substr(trim($_POST['Pronouns'] ?? ''), 0, 40);
```

Replace lines 61–62 in the `$request` array:
```php
				'PronounId'     => $pronounId > 0 ? $pronounId : null,
				'PronounCustom' => strlen($pronounCustom) ? $pronounCustom : null,
```
with:
```php
				'Pronouns'      => $pronouns,
```

- [ ] **Step 3: Controller create block — surface profanity cleanly**

Replace the result handling at lines 75–79:
```php
			$r = $this->Player->create_player($request);
			if ($r['Status'] == 0) {
				echo json_encode(['status' => 0, 'mundaneId' => (int)($r['Detail'] ?? 0)]);
			} else {
				echo json_encode(['status' => $r['Status'], 'error' => rtrim(($r['Error'] ?? 'Error') . ': ' . ($r['Detail'] ?? ''), ': ')]);
			}
```
with:
```php
			$r = $this->Player->create_player($request);
			if ($r['Status'] == 0) {
				echo json_encode(['status' => 0, 'mundaneId' => (int)($r['Detail'] ?? 0)]);
			} elseif (($r['Error'] ?? '') === ProfanityFilter::ERROR_MESSAGE) {
				echo json_encode(['status' => $r['Status'], 'error' => $r['Error']]);
			} else {
				echo json_encode(['status' => $r['Status'], 'error' => rtrim(($r['Error'] ?? 'Error') . ': ' . ($r['Detail'] ?? ''), ': ')]);
			}
```

- [ ] **Step 4: Verify lint**

Run: `php -l system/lib/ork3/class.Player.php && php -l orkui/controller/controller.PlayerAjax.php`
Expected: `No syntax errors detected` for both.

- [ ] **Step 5: Commit**

```bash
git add system/lib/ork3/class.Player.php orkui/controller/controller.PlayerAjax.php
git commit -m "Enhancement: Create Player writes profanity-checked Pronouns"
```

---

## Task 6: Frontend — chip + field CSS (dark-mode)

**Files:**
- Modify: `orkui/template/revised-frontend/style/revised.css` (append near the existing `.pronoun-row` rules, ~line 6031)

- [ ] **Step 1: Add chip/field styles using ORK CSS vars**

Append:

```css
/* Pronouns free-text field — Design modal Name tab + Create Player modals */
.pn-pronoun-chips { display: flex; flex-wrap: wrap; gap: 6px; margin-bottom: 8px; }
.pn-pronoun-chip {
  padding: 4px 12px;
  border: 1px solid var(--ork-border, #cbd5e0);
  border-radius: 999px;
  background: var(--ork-bg-secondary, #f7fafc);
  color: var(--ork-text, #2d3748);
  font-size: 12px;
  cursor: pointer;
  transition: background .12s, border-color .12s;
}
.pn-pronoun-chip:hover {
  background: var(--ork-bg-tertiary, #edf2f7);
  border-color: var(--ork-border-dark, #a0aec0);
}
html[data-theme="dark"] .pn-pronoun-chip {
  background: var(--ork-bg-tertiary, #2d3748);
  border-color: var(--ork-border-dark, #374151);
  color: var(--ork-text, #e2e8f0);
}
```

- [ ] **Step 2: Verify the vars exist / no obvious breakage**

Run: `grep -nE '\-\-ork-(bg-secondary|bg-tertiary|border|border-dark|text)\b' orkui/template/revised-frontend/style/revised.css | head`
Expected: each referenced var is defined (fallbacks cover any that aren't). Visually confirmed in Task 12's browser walk.

- [ ] **Step 3: Commit**

```bash
git add orkui/template/revised-frontend/style/revised.css
git commit -m "Enhancement: pronoun chip + field styles (dark-mode)"
```

---

## Task 7: Frontend — Design modal Name-tab field + JS wiring

**Files:**
- Modify: `orkui/template/revised-frontend/Playernew_index.tpl:3317` (after the Pronunciation Guide field, inside `#pn-design-name`)
- Modify: `orkui/template/revised-frontend/script/revised.js` (chip helper; design-save append + fieldMap)

- [ ] **Step 1: Add the Pronouns field markup**

After the Pronunciation Guide `</div>` (line 3317), insert:

```php
					<div class="pn-design-field" style="margin-top:16px">
						<label for="pn-design-pronouns">Pronouns</label>
						<div class="pn-pronoun-chips">
							<button type="button" class="pn-pronoun-chip" data-pronoun-chip-for="pn-design-pronouns" data-val="he/him">he/him</button>
							<button type="button" class="pn-pronoun-chip" data-pronoun-chip-for="pn-design-pronouns" data-val="she/her">she/her</button>
							<button type="button" class="pn-pronoun-chip" data-pronoun-chip-for="pn-design-pronouns" data-val="they/them">they/them</button>
						</div>
						<input type="text" id="pn-design-pronouns" maxlength="40" placeholder="e.g. she/her, they/them" value="<?= htmlspecialchars($Player['PronounText'] ?? '') ?>" />
						<div class="pn-design-hint">How you'd like to be referred to. Leave blank to omit.</div>
					</div>
```

- [ ] **Step 2: Add the shared chip helper to revised.js**

Append (top-level, e.g. just below the `setupPronounPicker` location once removed in Task 8 — anywhere top-level is fine):

```javascript
// ---- Shared: pronoun quick-fill chips ----
// Each chip carries data-pronoun-chip-for="<inputId>" and data-val; clicking it
// fills the target input. Idempotent + safe if the input is absent.
function pnSetupPronounChips(inputId) {
    var input = document.getElementById(inputId);
    if (!input) return;
    var chips = document.querySelectorAll('[data-pronoun-chip-for="' + inputId + '"]');
    Array.prototype.forEach.call(chips, function(chip) {
        chip.addEventListener('click', function() {
            input.value = chip.getAttribute('data-val') || '';
            input.focus();
        });
    });
}
```

- [ ] **Step 3: Wire chips for the design field**

Inside the design-modal IIFE (near the other `gid(...)` setup, e.g. right after `var coreInput = gid('pn-name-core');` at line 4107), add:

```javascript
	pnSetupPronounChips('pn-design-pronouns');
```

- [ ] **Step 4: Append Pronouns to the design save FormData**

After line 4440 (`fd.append('PronunciationGuide', ...)`), add:

```javascript
		fd.append('Pronouns', gid('pn-design-pronouns') ? gid('pn-design-pronouns').value.trim() : '');
```

- [ ] **Step 5: Add Pronouns to the inline-profanity field map**

In `pnShowProfanityFieldError`'s `fieldMap` (line 4474, next to `PronunciationGuide`), add:

```javascript
					'Pronouns':           { fieldId: 'pn-design-pronouns',        tabPanel: 'name'  },
```

- [ ] **Step 6: Verify**

Run: `node --check orkui/template/revised-frontend/script/revised.js` (or `grep -n "pn-design-pronouns" orkui/template/revised-frontend/script/revised.js orkui/template/revised-frontend/Playernew_index.tpl`)
Expected: JS parses; the new id appears in both files.

- [ ] **Step 7: Commit**

```bash
git add orkui/template/revised-frontend/Playernew_index.tpl orkui/template/revised-frontend/script/revised.js
git commit -m "Enhancement: pronouns free-text field in Design My Profile (Name tab)"
```

---

## Task 8: Frontend — remove the Account-modal picker

**Files:**
- Modify: `orkui/template/revised-frontend/Playernew_index.tpl:2434-2483` (remove the pronoun block)
- Modify: `orkui/template/revised-frontend/script/revised.js:1620-1628` (remove `setupPronounPicker` init)
- Modify: `orkui/template/revised-frontend/script/revised.js:8625-8719` (remove the `setupPronounPicker` function)

- [ ] **Step 1: Remove the Account-modal pronoun field**

Delete the entire `<div class="pn-acct-field">` that contains `pn-acct-pronouns` — lines 2434–2483 (from `<div class="pn-acct-field">` immediately before `<label for="pn-acct-pronouns">` through its closing `</div>` just before the `Restrict Mundane Name Visibility` field at line 2485).

- [ ] **Step 2: Remove the picker init call**

Delete lines 1620–1628 (the `setupPronounPicker({ ... });` call inside the Update Account Modal IIFE).

- [ ] **Step 3: Remove the now-dead `setupPronounPicker` function**

Delete the whole function — lines 8625–8719 (from the `// ---- Shared: pronoun picker helper ----` comment through the closing `}` of `setupPronounPicker`).

- [ ] **Step 4: Verify no dangling references**

Run:
```bash
grep -rn "setupPronounPicker\|pn-acct-pronouns\|pn-pronoun-custom\|pn-pronoun-picker\|pn-p-subject" orkui/template/revised-frontend/
node --check orkui/template/revised-frontend/script/revised.js
```
Expected: **zero** matches (all picker ids/fn gone); JS still parses.

- [ ] **Step 5: Commit**

```bash
git add orkui/template/revised-frontend/Playernew_index.tpl orkui/template/revised-frontend/script/revised.js
git commit -m "Enhancement: remove legacy pronoun picker from Account modal"
```

---

## Task 9: Frontend — add Pronouns to both Create Player modals

**Files:**
- Modify: `orkui/template/revised-frontend/Kingdomnew_index.tpl:1761` (after the Waivered field row, before the waiver-file row)
- Modify: `orkui/template/revised-frontend/Parknew_index.tpl:1757` (same relative spot)
- Modify: `orkui/template/revised-frontend/script/revised.js:8810` (Kingdom submit FormData) and `:8911` (Park submit FormData)
- Modify: `orkui/template/revised-frontend/script/revised.js` (chip init in each create IIFE)

- [ ] **Step 1: Kingdomnew — add the field markup**

After the Waivered `plr-field-row` (the radios at lines 1750–1751) and before `<div class="plr-field-row" id="kn-addplayer-waiver-row" ...>` (line 1763), insert:

```php
			<div class="plr-field-row">
				<div class="plr-field plr-field-grow">
					<label>Pronouns <span class="plr-hint">(optional — e.g. she/her, they/them)</span></label>
					<div class="pn-pronoun-chips">
						<button type="button" class="pn-pronoun-chip" data-pronoun-chip-for="kn-addplayer-pronouns" data-val="he/him">he/him</button>
						<button type="button" class="pn-pronoun-chip" data-pronoun-chip-for="kn-addplayer-pronouns" data-val="she/her">she/her</button>
						<button type="button" class="pn-pronoun-chip" data-pronoun-chip-for="kn-addplayer-pronouns" data-val="they/them">they/them</button>
					</div>
					<input type="text" id="kn-addplayer-pronouns" maxlength="40" placeholder="Optional">
				</div>
			</div>
```

- [ ] **Step 2: Parknew — add the field markup**

After the Parknew Waivered `plr-field-row` (radios at lines 1754–1755) and before `<div class="plr-field-row" id="pk-addplayer-waiver-row" ...>` (line 1759), insert the same block but with `pk-addplayer-pronouns` as the id and `data-pronoun-chip-for="pk-addplayer-pronouns"`:

```php
			<div class="plr-field-row">
				<div class="plr-field plr-field-grow">
					<label>Pronouns <span class="plr-hint">(optional — e.g. she/her, they/them)</span></label>
					<div class="pn-pronoun-chips">
						<button type="button" class="pn-pronoun-chip" data-pronoun-chip-for="pk-addplayer-pronouns" data-val="he/him">he/him</button>
						<button type="button" class="pn-pronoun-chip" data-pronoun-chip-for="pk-addplayer-pronouns" data-val="she/her">she/her</button>
						<button type="button" class="pn-pronoun-chip" data-pronoun-chip-for="pk-addplayer-pronouns" data-val="they/them">they/them</button>
					</div>
					<input type="text" id="pk-addplayer-pronouns" maxlength="40" placeholder="Optional">
				</div>
			</div>
```

- [ ] **Step 3: Kingdom submit — append Pronouns + reset on open + chip init**

In the Kingdom create submit handler, after line 8810 (`if (waiverFile && waiverFile.files[0]) fd.append('Waiver', ...)`), add:

```javascript
            var knPronouns = gid('kn-addplayer-pronouns');
            fd.append('Pronouns', knPronouns ? knPronouns.value.trim() : '');
```

Inside the Kingdom create `$(document).ready(...)` block (where the other listeners are wired, before the submit listener at line 8784), add the chip init:

```javascript
        pnSetupPronounChips('kn-addplayer-pronouns');
```

- [ ] **Step 4: Park submit — append Pronouns + reset on open + chip init**

In the Park create submit handler, after line 8911 (`if (waiverFile && waiverFile.files[0]) fd.append('Waiver', ...)`), add:

```javascript
            var pkPronouns = gid('pk-addplayer-pronouns');
            fd.append('Pronouns', pkPronouns ? pkPronouns.value.trim() : '');
```

In `pkOpenAddPlayerModal` (lines 8851–8866), after `gid('pk-addplayer-password').value = '';` (line 8859), add a reset so the field clears between opens:

```javascript
        if (gid('pk-addplayer-pronouns')) gid('pk-addplayer-pronouns').value = '';
```

Inside the Park create `$(document).ready(...)` block (before the submit listener at line 8887), add:

```javascript
        pnSetupPronounChips('pk-addplayer-pronouns');
```

- [ ] **Step 5: Verify**

Run:
```bash
grep -n "addplayer-pronouns" orkui/template/revised-frontend/Kingdomnew_index.tpl orkui/template/revised-frontend/Parknew_index.tpl orkui/template/revised-frontend/script/revised.js
node --check orkui/template/revised-frontend/script/revised.js
```
Expected: ids present in all three files (markup + two `fd.append` + two chip inits); JS parses.

- [ ] **Step 6: Commit**

```bash
git add orkui/template/revised-frontend/Kingdomnew_index.tpl orkui/template/revised-frontend/Parknew_index.tpl orkui/template/revised-frontend/script/revised.js
git commit -m "Enhancement: optional Pronouns field on Create Player modals"
```

---

## Task 10: Controller cleanup — drop unused pronoun option loads

**Files:**
- Modify: `orkui/controller/controller.Player.php:230-231` and `:388-389`

- [ ] **Step 1: Remove the now-unused assignments**

The Account-modal picker (the only consumer of these in Playernew) is gone, so delete both pairs:

Lines 230–231:
```php
        $this->data['PronounOptions'] = $this->Pronoun->fetch_pronoun_option_list($this->data['Player']['PronounId']);
        $this->data['PronounList']    = $this->Pronoun->fetch_pronoun_list();
```
Lines 388–389 (identical pair in the `profile` method).

(Leave `controller.Kingdom.php:780-781` and `controller.Park.php:327-328` — pre-existing dead vars unrelated to this change; out of scope. `controller.Admin.php:1442-1443` is handled in Task 11.)

- [ ] **Step 2: Verify nothing else references them in Playernew**

Run: `grep -n "PronounOptions\|PronounList" orkui/template/revised-frontend/Playernew_index.tpl`
Expected: **zero** matches.
Run: `php -l orkui/controller/controller.Player.php`
Expected: `No syntax errors detected`.

- [ ] **Step 3: Commit**

```bash
git add orkui/controller/controller.Player.php
git commit -m "Refactor: drop unused pronoun option loads from Player controller"
```

---

## Task 11: Legacy `Admin_player.tpl` — remove pronoun control (judgment call)

> Flagged in the spec: removes a control that would otherwise be a silently-no-op widget (display is now sourced from `pronoun_freetext`, which the legacy picker doesn't write). If the reviewer prefers leaving the legacy template untouched, **skip this task** — the rest of the feature is unaffected.

**Files:**
- Modify: `orkui/template/default/Admin_player.tpl:73-81` (the Pronouns field) and `:854-970` (the picker popup + its inline JS)
- Modify: `orkui/controller/controller.Admin.php:1442-1443` (the option loads)

- [ ] **Step 1: Remove the Pronouns field block**

Delete lines 73–81 (the `<div>` containing `<span>Pronouns:</span>`, the `PronounId` select, the `#pronoun-picker` link, and the `#pronoun_custom` hidden input).

- [ ] **Step 2: Remove the picker popup markup + inline JS**

Delete the pronoun picker popup block and its inline `<script>` (lines ~854–970: from the `$pronoun_custom_arr = ...` PHP through the `#pronoun-picker` click handler and its `popup(...)` setup). Confirm the exact span with:
```bash
grep -n -i "pronoun\|pselect_display\|p_subject\|p_reflexive" orkui/template/default/Admin_player.tpl
```
Remove only the contiguous pronoun-picker region surfaced there.

- [ ] **Step 3: Remove the controller option loads**

Delete `controller.Admin.php:1442-1443`:
```php
        $this->data['PronounOptions'] = $this->Pronoun->fetch_pronoun_option_list($this->data['Player']['PronounId']);
        $this->data['PronounList'] = $this->Pronoun->fetch_pronoun_list();
```

- [ ] **Step 4: Verify**

Run:
```bash
grep -n -i "pronoun" orkui/template/default/Admin_player.tpl
php -l orkui/controller/controller.Admin.php
```
Expected: zero pronoun references remain in the template; controller lints clean.

- [ ] **Step 5: Commit**

```bash
git add orkui/template/default/Admin_player.tpl orkui/controller/controller.Admin.php
git commit -m "Enhancement: remove legacy pronoun picker from admin player template"
```

---

## Task 12: Full verification pass

**Files:** none (verification only)

- [ ] **Step 1: Lint all touched PHP**

Run:
```bash
php -l system/lib/ork3/class.Player.php
php -l orkui/controller/controller.PlayerAjax.php
php -l orkui/controller/controller.Player.php
php -l orkui/controller/controller.Admin.php
node --check orkui/template/revised-frontend/script/revised.js
```
Expected: all clean.

- [ ] **Step 2: Confirm the picker is fully gone**

Run: `grep -rn "setupPronounPicker\|pronoun-picker\|pn-p-subject\|PronounCustom\b" orkui/template/revised-frontend/`
Expected: no picker remnants (a `PronounCustom` reference may remain only if intentionally left in `class.Player.php` signatures — none in the revised frontend).

- [ ] **Step 3: Exercise update via curl-auth**

In ONE shell block (login + call, single cookie jar — see `reference_local_curl_auth_session`): POST to `PlayerAjax/player/{ownId}/updateprofile` with `Pronouns=she/her` and the other required Name-tab fields; then reload the profile.
Expected: `{"status":0}`; profile hero shows `she/her`. Then POST a known-profane value → expect `{"status":...,"error":...,"field":"Pronouns"}` and DB unchanged.

- [ ] **Step 4: Exercise create via curl-auth**

POST to `PlayerAjax/park/{parkId}/create` with required fields + `Pronouns=they/them`.
Expected: `{"status":0,"mundaneId":N}`; the new row has `pronoun_freetext='they/them'`. Repeat with a profane value → `{"status":...,"error":"<profanity message>"}` and no row created.

- [ ] **Step 5: Browser dark-mode walk (per `feedback_chrome_usage` — verification only)**

Open Design My Profile → Name tab: chips fill the input, 40-char cap holds, Save persists, value re-loads. Toggle dark mode (moon icon): chips, input, placeholder, and hint are all legible. Open both Create Player modals: field renders, chips work, dark mode OK.

- [ ] **Step 6: Final staged-diff review + branch wrap**

Run: `git diff --cached` review discipline already applied per-task. Confirm `class.Authorization.php` was never staged (`git log --oneline` of this work shows only the intended files).

---

## Self-Review (completed during planning)

- **Spec coverage:** column+backfill (T1), display read (T2), update write+profanity (T3/T4), create write+profanity (T5), Name-tab field+chips (T6/T7), Account-modal removal (T8), Create Player modals (T9), controller cleanup (T10), legacy admin removal (T11), verification (T12). All spec sections mapped.
- **Type/name consistency:** input ids `pn-design-pronouns` / `kn-addplayer-pronouns` / `pk-addplayer-pronouns`; request key `Pronouns`; column `pronoun_freetext`; helper `pnSetupPronounChips`; profanity field detail `'Pronouns'` — used consistently across tasks.
- **No placeholders:** every code step shows complete code; verification steps give exact commands + expected output.
