# Paragon → Apprentice Association Chain Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Paragon→Apprentice mentor/protégé association chain (mirroring Knight→Squire) that appears in the player profile's My Peers / My Associates cards and in award modals, but NOT in the Beltline Explorer.

**Architecture:** A single global "Apprentice" award (peerage `'Apprentice'`, already a valid ENUM value) is granted with `given_by_id` pointing at the Paragon mentor. The protégé-peerage set is defined once in the lib layer (`Award::ProtegePeerages()`), and the three raw beltline SQL queries currently living in `controller.Player.php` are moved into `class.Player.php` methods (repairing a layer violation while sourcing the peerage set from the new helper).

**Tech Stack:** PHP 8 (no PHPUnit harness in this repo), MariaDB, plain-PHP `.tpl` templates rendered via `extract()`+`include`. Verification is by `php -l` lint, DB probes, synthetic rows, and browser checks per project convention.

**Spec:** `docs/superpowers/specs/2026-06-17-paragon-apprentice-association-chain-design.md`

**Testing note:** This legacy codebase has no unit-test runner. "Tests" here are concrete executable checks: `php -l` for syntax, SQL probes (`docker exec -i ork3-php8-db mariadb -u root -proot ork`) for data, and authenticated browser/curl loads for rendering. Follow them exactly.

**Edit-tool note (project rule):** Before any multi-line Edit on a PHP file, check indentation: `awk '/^\t/{c++} END{print c+0}' <file>` — `0` = clean (use Edit). Non-zero = run `php tools/php-cs-fixer.phar fix --config=.php-cs-fixer.dist.php <file>` on that one file first, then Edit.

---

## File Structure

| File | Responsibility | Change |
|---|---|---|
| `db-migrations/2026-06-17-apprentice-award.sql` | Seed the global Apprentice award | Create |
| `system/lib/ork3/class.Award.php` | Canonical protégé-peerage list; alias options | Add `ProtegePeerages()`; seed Apprentice in `create_system_awards`; add Apprentice to alias options |
| `system/lib/ork3/class.Player.php` | Beltline query methods (moved from controller) | Add `GetBeltlinePeers`, `GetBeltlineAssociates`, 2 private SQL-fragment helpers |
| `orkui/controller/controller.Player.php` | Profile data prep | Replace 3 inline SQL blocks with lib calls |
| `orkui/model/model.Award.php` | Grant-modal optgroup categorization | Route protégé group via `Award::ProtegePeerages()` |
| `orkui/template/revised-frontend/Playernew_index.tpl` | Profile rendering | Apprentice in 3 label maps + belt gate |
| `system/lib/ork3/class.Report.php` | Beltline Explorer query | Comment marking deliberate Apprentice exclusion |

---

## Task 1: Seed the global Apprentice award

**Files:**
- Create: `db-migrations/2026-06-17-apprentice-award.sql`
- Modify: `system/lib/ork3/class.Award.php:216` (add Apprentice to `create_system_awards`)

- [ ] **Step 1: Probe current state (verify it fails / is absent)**

Run:
```bash
docker exec -i ork3-php8-db mariadb -u root -proot ork -t -e \
  "SELECT award_id, name, peerage, is_title, title_class FROM ork_award WHERE peerage='Apprentice';"
```
Expected: empty set (zero Apprentice awards today).

- [ ] **Step 2: Write the idempotent migration**

Create `db-migrations/2026-06-17-apprentice-award.sql`:
```sql
-- 2026-06-17: Seed the global "Apprentice" peerage award (Paragon → Apprentice chain).
-- The 'Apprentice' ENUM value already exists (added 2018-06-18-crown-points.sql);
-- this only inserts the single system award row. Idempotent: re-running is a no-op.
INSERT INTO ork_award (name, is_ladder, is_title, title_class, peerage, officer_role)
SELECT 'Apprentice', 0, 1, 15, 'Apprentice', 'none'
WHERE NOT EXISTS (
    SELECT 1 FROM ork_award WHERE peerage = 'Apprentice'
);
```
(`title_class = 15` matches the Squire award — confirmed at `class.Award.php:216`.)

- [ ] **Step 3: Apply the migration**

Run:
```bash
docker exec -i ork3-php8-db mariadb -u root -proot ork < db-migrations/2026-06-17-apprentice-award.sql
```
Expected: no error.

- [ ] **Step 4: Verify the row exists (and idempotency)**

Run:
```bash
docker exec -i ork3-php8-db mariadb -u root -proot ork < db-migrations/2026-06-17-apprentice-award.sql
docker exec -i ork3-php8-db mariadb -u root -proot ork -t -e \
  "SELECT award_id, name, peerage, is_title, title_class FROM ork_award WHERE peerage='Apprentice';"
```
Expected: exactly ONE row named `Apprentice`, `is_title=1`, `title_class=15` (second apply changed nothing).

- [ ] **Step 5: Add Apprentice to `create_system_awards` (fresh-install parity)**

In `system/lib/ork3/class.Award.php`, after line 216 (`$this->create_award('Squire', 0, 1, 15, 'Squire');`) add:
```php
		$this->create_award('Apprentice', 0, 1, 15, 'Apprentice');
```

- [ ] **Step 6: Lint**

Run: `php -l system/lib/ork3/class.Award.php`
Expected: `No syntax errors detected`

- [ ] **Step 7: Commit**

```bash
git add db-migrations/2026-06-17-apprentice-award.sql system/lib/ork3/class.Award.php
git commit -m "Enhancement: seed global Apprentice peerage award"
```

---

## Task 2: Canonical protégé-peerage list + alias options

**Files:**
- Modify: `system/lib/ork3/class.Award.php` (add `ProtegePeerages()`; extend `fetch_custom_title_alias_options` at lines 118–143)

- [ ] **Step 1: Add the `ProtegePeerages()` helper**

In `system/lib/ork3/class.Award.php`, immediately after the `GetLadderMasterMap()` method closes (line 34, before `LookupAward`), add:
```php
	/**
	 * Canonical, display-ordered list of protégé/association peerage ranks
	 * surfaced in the player-profile "My Peers" / "My Associates" cards and the
	 * award modals. Single source of truth — consumed by class.Player.php's
	 * beltline queries and model.Award.php's grant-modal optgroup routing.
	 *
	 * NOTE: the Beltline Explorer (Report::BeltlineData) intentionally uses a
	 * narrower classic-only list and does NOT include 'Apprentice' (yet).
	 */
	public static function ProtegePeerages() {
		return ['Squire', 'Man-At-Arms', 'Lords-Page', 'Page', 'Apprentice'];
	}
```

- [ ] **Step 2: Add 'Apprentice' to the alias-options query (3 spots)**

In `fetch_custom_title_alias_options()`:

Line 124 — add `'Apprentice'` to the IN list:
```php
			  AND (peerage IN ('Page','Lords-Page','Squire','Man-At-Arms','Master','Knight','Apprentice') OR is_title = 1)
```
Line 125 — add `'Apprentice'` to the FIELD ordering (last = lowest, since DESC):
```php
			ORDER BY FIELD(peerage,'Knight','Master','Squire','Man-At-Arms','Lords-Page','Page','Apprentice') DESC, is_title DESC, name ASC";
```
Line 135 — add `'Apprentice'` to the in_array filter:
```php
				if (in_array($r->peerage, ['Page','Lords-Page','Squire','Man-At-Arms','Master','Knight','Apprentice'], true)) {
```

- [ ] **Step 3: Lint**

Run: `php -l system/lib/ork3/class.Award.php`
Expected: `No syntax errors detected`

- [ ] **Step 4: Verify the helper returns the expected list**

Run:
```bash
docker exec -i ork3-php8-app php -r 'require "/var/www/ork.amtgard.com/system/lib/ork3/class.Ork3.php"; require "/var/www/ork.amtgard.com/system/lib/ork3/class.Award.php"; echo implode(",", Award::ProtegePeerages());'
```
Expected output: `Squire,Man-At-Arms,Lords-Page,Page,Apprentice`
(If the `require` paths differ or bootstrap is required, instead just `grep -n "ProtegePeerages" system/lib/ork3/class.Award.php` to confirm the method is present and move on — the runtime check happens in Task 8.)

- [ ] **Step 5: Commit**

```bash
git add system/lib/ork3/class.Award.php
git commit -m "Enhancement: add ProtegePeerages() and Apprentice alias option"
```

---

## Task 3: Move beltline queries into the lib layer

**Files:**
- Modify: `system/lib/ork3/class.Player.php` (add 2 public methods + 2 private helpers; place them after the constructor / near the existing award-related methods, e.g. after line ~549)

- [ ] **Step 1: Add the private SQL-fragment helpers**

In `system/lib/ork3/class.Player.php`, add (inside the `Player` class):
```php
	/**
	 * WHERE fragment matching the protégé/association awards shown in the
	 * profile beltline cards. $peerageExpr is the resolved-peerage SQL
	 * expression (handles custom-title aliases). Includes the legacy
	 * woman-at-arms custom-name match. Source list: Award::ProtegePeerages().
	 */
	private function beltlinePeerageWhere($peerageExpr) {
		$in = "'" . implode("','", Award::ProtegePeerages()) . "'";
		return "($peerageExpr IN ($in)
			OR LOWER(COALESCE(NULLIF(ma.custom_name,''), ka.name, a.name)) LIKE '%woman%at%arms%')";
	}

	/**
	 * ORDER BY CASE fragment ranking protégé peerages in display order,
	 * derived from Award::ProtegePeerages().
	 */
	private function beltlineOrderCase($peerageExpr) {
		$ranks = array_values(Award::ProtegePeerages());
		$case = "CASE $peerageExpr ";
		foreach ($ranks as $i => $p) {
			$case .= "WHEN '$p' THEN " . ($i + 1) . " ";
		}
		$case .= "ELSE " . (count($ranks) + 1) . " END";
		return $case;
	}
```

- [ ] **Step 2: Add `GetBeltlinePeers()` (the player's mentors)**

Add to the `Player` class:
```php
	/**
	 * "My Peers": who granted this player a protégé-rank award (their mentors).
	 * Moved out of controller.Player.php (raw SQL did not belong in a controller).
	 */
	public function GetBeltlinePeers($mundane_id) {
		$mundane_id = (int)$mundane_id;
		$peerageExpr = "COALESCE(alias.peerage, a.peerage)";
		$sql = "SELECT m.mundane_id AS PeerId, m.persona AS Persona,
				COALESCE(NULLIF(ma.custom_name,''), ka.name, a.name) AS TitleName,
				$peerageExpr AS Peerage, ma.date AS Date
				FROM " . DB_PREFIX . "awards ma
				JOIN " . DB_PREFIX . "award a ON a.award_id = ma.award_id
				LEFT JOIN " . DB_PREFIX . "award alias ON alias.award_id = ma.alias_award_id
				LEFT JOIN " . DB_PREFIX . "kingdomaward ka ON ka.kingdomaward_id = ma.kingdomaward_id
				JOIN " . DB_PREFIX . "mundane m ON m.mundane_id = ma.given_by_id
				WHERE ma.mundane_id = $mundane_id
					AND " . $this->beltlinePeerageWhere($peerageExpr) . "
					AND (ma.revoked = 0 OR ma.revoked IS NULL)
					AND ma.given_by_id > 0
				ORDER BY " . $this->beltlineOrderCase($peerageExpr) . ", m.persona ASC";
		$r = $this->db->query($sql);
		$out = array();
		if ($r !== false && $r->size() > 0) {
			while ($r->next()) {
				$out[] = array(
					'PeerId'    => (int)$r->PeerId,
					'Persona'   => $r->Persona,
					'TitleName' => $r->TitleName,
					'Peerage'   => $r->Peerage,
					'Date'      => $r->Date,
				);
			}
		}
		return $out;
	}
```

- [ ] **Step 3: Add `GetBeltlineAssociates()` (the player's protégés)**

Add to the `Player` class:
```php
	/**
	 * "My Associates": who this player granted a protégé-rank award to (their
	 * protégés). Used for both the sidebar (any profile) and the own-profile
	 * main-body associates card. Moved out of controller.Player.php.
	 */
	public function GetBeltlineAssociates($giver_id) {
		$giver_id = (int)$giver_id;
		$peerageExpr = "COALESCE(alias.peerage, a.peerage)";
		$sql = "SELECT ma.mundane_id AS RecipientId, m.persona AS Persona,
				COALESCE(NULLIF(ma.custom_name,''), ka.name, a.name) AS TitleName,
				$peerageExpr AS Peerage, ma.date AS Date
				FROM " . DB_PREFIX . "awards ma
				JOIN " . DB_PREFIX . "award a ON a.award_id = ma.award_id
				LEFT JOIN " . DB_PREFIX . "award alias ON alias.award_id = ma.alias_award_id
				LEFT JOIN " . DB_PREFIX . "kingdomaward ka ON ka.kingdomaward_id = ma.kingdomaward_id
				JOIN " . DB_PREFIX . "mundane m ON m.mundane_id = ma.mundane_id
				WHERE ma.given_by_id = $giver_id
					AND " . $this->beltlinePeerageWhere($peerageExpr) . "
					AND (ma.revoked = 0 OR ma.revoked IS NULL)
				ORDER BY " . $this->beltlineOrderCase($peerageExpr) . ", m.persona ASC";
		$r = $this->db->query($sql);
		$out = array();
		if ($r !== false && $r->size() > 0) {
			while ($r->next()) {
				$out[] = array(
					'RecipientId' => (int)$r->RecipientId,
					'Persona'     => $r->Persona,
					'TitleName'   => $r->TitleName,
					'Peerage'     => $r->Peerage,
					'Date'        => $r->Date,
				);
			}
		}
		return $out;
	}
```

- [ ] **Step 4: Lint**

Run: `php -l system/lib/ork3/class.Player.php`
Expected: `No syntax errors detected`

- [ ] **Step 5: Commit**

```bash
git add system/lib/ork3/class.Player.php
git commit -m "Refactor: move beltline peer/associate queries into class.Player.php"
```

---

## Task 4: Wire the controller to the lib methods

**Files:**
- Modify: `orkui/controller/controller.Player.php:586-688` (replace the three inline SQL blocks)

- [ ] **Step 1: Replace the three inline blocks**

Delete the entire span from line 586 (`// Beltline: My Peers (who gave this player peerage awards)`) through line 688 (the closing `}` of the `if ($uid === (int)$id)` block that ends with `$this->data['MyAssociates'] = $__assocs;`). Replace with:
```php
        // Beltline cards (My Peers / My Associates). DB work lives in the lib layer
        // (class.Player.php); the protégé-peerage set comes from Award::ProtegePeerages().
        $this->data['BeltlinePeers']      = $this->Player->GetBeltlinePeers((int)$id);
        $this->data['BeltlineAssociates'] = $this->Player->GetBeltlineAssociates((int)$id);
        if ($uid === (int)$id) {
            $this->data['MyAssociates'] = $this->Player->GetBeltlineAssociates($uid);
        }
```
(The `__call` magic on `$this->Player` forwards to `class.Player.php`, exactly as the existing `$this->Player->fetch_player_details($id)` call at line 388 does.)

- [ ] **Step 2: Confirm no orphaned beltline SQL remains in the controller**

Run:
```bash
grep -n "BeltlinePeers\|BeltlineAssociates\|MyAssociates\|__peerSql\|__blAssocSql\|__assocSql" orkui/controller/controller.Player.php
```
Expected: only the three `$this->data[...]` assignments from Step 1 — NO `__peerSql` / `__blAssocSql` / `__assocSql` variables remain.

- [ ] **Step 3: Lint**

Run: `php -l orkui/controller/controller.Player.php`
Expected: `No syntax errors detected`

- [ ] **Step 4: Smoke-test the profile renders (no fatal)**

Load a profile in the browser/curl (logged-in session per project convention) — pick any player id, e.g. `index.php?Route=Player/profile/1`. Expected: page renders HTTP 200; check `docker logs ork3-php8-app` shows no new PHP fatal/500.

- [ ] **Step 5: Commit**

```bash
git add orkui/controller/controller.Player.php
git commit -m "Refactor: delegate beltline cards to class.Player.php lib methods"
```

---

## Task 5: Grant-modal optgroup routing via the helper

**Files:**
- Modify: `orkui/model/model.Award.php:61-62`

- [ ] **Step 1: Route the protégé optgroup through `Award::ProtegePeerages()`**

Replace lines 61–62:
```php
                } elseif (in_array($award['Peerage'] ?? '', ['Squire','Man-At-Arms','Page','Lords-Page'])
                          || $sysName === 'Apprentice') {
```
with:
```php
                } elseif (in_array($award['Peerage'] ?? '', Award::ProtegePeerages())
                          || $sysName === 'Apprentice') {
```
(`ProtegePeerages()` now includes `'Apprentice'`; the `$sysName === 'Apprentice'` clause stays as a belt-and-suspenders fallback for an award named Apprentice with a non-matching peerage.)

- [ ] **Step 2: Lint**

Run: `php -l orkui/model/model.Award.php`
Expected: `No syntax errors detected`

- [ ] **Step 3: Verify the Apprentice award lands in the grant dropdown**

In the browser, open a player profile's Add Award modal (logged-in officer/admin session). Expected: an "Apprentice" entry appears under the **Associate Titles** optgroup. (The ghettocache on `fetch_award_option_list` has a 1200s TTL — if stale, flush memcache per project rule, then reload.)

- [ ] **Step 4: Commit**

```bash
git add orkui/model/model.Award.php
git commit -m "Enhancement: route Apprentice into grant-modal Associate Titles group"
```

---

## Task 6: Template labels + award-detail belt gate

**Files:**
- Modify: `orkui/template/revised-frontend/Playernew_index.tpl` lines 1619, 1712, 1730, 2123

**Pre-check (project rule):** Run `awk '/^\t/{c++} END{print c+0}' orkui/template/revised-frontend/Playernew_index.tpl`. If non-zero, the Edit tool may mismatch tabs — use the Python `replace` fallback from CLAUDE.md for these edits instead.

- [ ] **Step 1: My Associates (main body) label map — line 1619**

Replace:
```php
							$_maPeerageLabels = ['Squire' => 'Squires', 'Man-At-Arms' => 'Men/Women-at-Arms', 'Lords-Page' => 'Lords-Pages', 'Page' => 'Pages'];
```
with:
```php
							$_maPeerageLabels = ['Squire' => 'Squires', 'Man-At-Arms' => 'Men/Women-at-Arms', 'Lords-Page' => 'Lords-Pages', 'Page' => 'Pages', 'Apprentice' => 'Apprentices'];
```

- [ ] **Step 2: My Peers (sidebar) label map — line 1712**

Replace:
```php
								$_blPeerLabels = ['Squire' => 'Squire to', 'Man-At-Arms' => 'Person-at-Arms to', 'Lords-Page' => "Lord's Page to", 'Page' => 'Page to'];
```
with:
```php
								$_blPeerLabels = ['Squire' => 'Squire to', 'Man-At-Arms' => 'Person-at-Arms to', 'Lords-Page' => "Lord's Page to", 'Page' => 'Page to', 'Apprentice' => 'Apprentice to'];
```

- [ ] **Step 3: My Associates (sidebar) label map — line 1730**

Replace:
```php
								$_blAssocLabels = ['Squire' => 'Squires', 'Man-At-Arms' => 'People-at-Arms', 'Lords-Page' => "Lords-Pages", 'Page' => 'Pages'];
```
with:
```php
								$_blAssocLabels = ['Squire' => 'Squires', 'Man-At-Arms' => 'People-at-Arms', 'Lords-Page' => "Lords-Pages", 'Page' => 'Pages', 'Apprentice' => 'Apprentices'];
```

- [ ] **Step 4: Award-detail belt gate — line 2123**

Replace:
```php
											$_isPeerageTitleRow = in_array($detail['Peerage'] ?? '', ['Squire', 'Man-At-Arms', 'Lords-Page', 'Page']);
```
with:
```php
											$_isPeerageTitleRow = in_array($detail['Peerage'] ?? '', ['Squire', 'Man-At-Arms', 'Lords-Page', 'Page', 'Apprentice']);
```
(This makes the award-detail modal treat an Apprentice award as a belt/association row — surfacing/expecting its Given By mentor like Squire.)

- [ ] **Step 5: Lint the template as PHP**

Run: `php -l orkui/template/revised-frontend/Playernew_index.tpl`
Expected: `No syntax errors detected` (these `.tpl` files are plain PHP).

- [ ] **Step 6: Commit**

```bash
git add orkui/template/revised-frontend/Playernew_index.tpl
git commit -m "Enhancement: Apprentice labels in beltline cards + award-detail gate"
```

---

## Task 7: Mark the Beltline Explorer's deliberate divergence

**Files:**
- Modify: `system/lib/ork3/class.Report.php` (the `BeltlineData()` query, the `IN (...)` clause near line 3213)

- [ ] **Step 1: Add the explanatory comment**

Immediately above the `WHERE (COALESCE(alias.peerage, a.peerage) IN ('Squire', 'Man-At-Arms', 'Page', 'Lords-Page')` line in `BeltlineData()`, add:
```php
				// NOTE: classic belt ranks only — 'Apprentice' (Paragon→Apprentice chain)
				// is intentionally EXCLUDED from the Beltline Explorer for now. The player
				// profile cards include it; this report does not. Keep in sync with
				// Award::ProtegePeerages() only if/when Apprentice is added to the explorer.
```

- [ ] **Step 2: Confirm the explorer list was NOT changed**

Run:
```bash
grep -n "IN ('Squire', 'Man-At-Arms', 'Page', 'Lords-Page')" system/lib/ork3/class.Report.php
```
Expected: the line still lists exactly those four ranks (no Apprentice).

- [ ] **Step 3: Lint**

Run: `php -l system/lib/ork3/class.Report.php`
Expected: `No syntax errors detected`

- [ ] **Step 4: Commit**

```bash
git add system/lib/ork3/class.Report.php
git commit -m "Docs: mark Apprentice exclusion in Beltline Explorer query"
```

---

## Task 8: End-to-end verification with synthetic data

**Files:** none (verification only)

- [ ] **Step 1: Pick two real players and the Apprentice award id**

Run:
```bash
docker exec -i ork3-php8-db mariadb -u root -proot ork -t -e \
  "SELECT award_id FROM ork_award WHERE peerage='Apprentice' LIMIT 1;
   SELECT mundane_id, persona FROM ork_mundane WHERE persona <> '' ORDER BY mundane_id LIMIT 2;"
```
Record: `APPRENTICE_AWARD_ID`, a mentor `PARAGON_ID` (first row), an apprentice `APPR_ID` (second row).

- [ ] **Step 2: Insert a synthetic grant (Paragon grants Apprentice)**

Run (substitute the recorded ids):
```bash
docker exec -i ork3-php8-db mariadb -u root -proot ork -e \
  "INSERT INTO ork_awards (mundane_id, given_by_id, award_id, date, revoked)
   VALUES (APPR_ID, PARAGON_ID, APPRENTICE_AWARD_ID, CURDATE(), 0);"
```
Expected: 1 row inserted. Record the new `ork_awards.awards_id` (`SELECT LAST_INSERT_ID();`) for cleanup.

- [ ] **Step 3: Verify the lib methods return the relationship**

Load `index.php?Route=Player/profile/APPR_ID` (authenticated). Expected: the **My Peers** sidebar card shows a group header **"Apprentice to"** with the mentor's persona linked.

Load `index.php?Route=Player/profile/PARAGON_ID`. Expected: the **My Associates** card shows a group header **"Apprentices"** with the apprentice's persona linked. (If viewing your own profile as PARAGON_ID, the main-body "My Associates" card should also show it.)

- [ ] **Step 4: Verify the award-detail modal treats it as a belt row**

On the apprentice's profile Awards tab, open the Apprentice award row's detail. Expected: the Given By column shows the mentor (the row is treated as a peerage/belt title row).

- [ ] **Step 5: NEGATIVE test — Beltline Explorer must NOT show it**

Load the Beltline Explorer report (`Reports/beltlineexplorer`, kingdom-scoped to the test players' kingdom). Expected: the Apprentice relationship does NOT appear (only classic belt ranks render).

- [ ] **Step 6: Dark-mode pass**

Toggle dark mode and re-check the My Peers / My Associates cards and the Add Award + award-detail modals on the two profiles. Expected: all readable, no gray-box heading leaks, labels legible.

- [ ] **Step 7: Clean up the synthetic row**

Run:
```bash
docker exec -i ork3-php8-db mariadb -u root -proot ork -e \
  "DELETE FROM ork_awards WHERE awards_id = <recorded_awards_id>;"
```
Expected: 1 row deleted. (Do NOT leave test data in the shared local DB.)

- [ ] **Step 8: Final full lint sweep + commit (if any verification fixes were made)**

Run:
```bash
for f in system/lib/ork3/class.Award.php system/lib/ork3/class.Player.php \
         system/lib/ork3/class.Report.php orkui/controller/controller.Player.php \
         orkui/model/model.Award.php orkui/template/revised-frontend/Playernew_index.tpl; do
  php -l "$f"; done
```
Expected: `No syntax errors detected` for every file. Commit any fixes; otherwise the feature is complete across Tasks 1–7.

---

## Self-Review

- **Spec coverage:** Schema/migration → T1. `ProtegePeerages()` single source → T2 (consumed in T3 lib queries, T5 model). Lib-layer move of the 3 controller queries → T3+T4. Grant modal → T5. Award-detail modal + alias dropdown → T2 (alias) + T6 (detail gate). My Peers/Associates labels → T6. Explorer exclusion → T7 (+ negative test T8.5). Verification incl. dark mode → T8. All spec sections mapped.
- **Type/name consistency:** `Award::ProtegePeerages()` (T2) is the exact symbol referenced in T3 (`beltlinePeerageWhere`/`beltlineOrderCase`) and T5. Lib methods `GetBeltlinePeers`/`GetBeltlineAssociates` (T3) match the controller calls (T4). Return-array keys (`PeerId`/`RecipientId`, `Persona`, `TitleName`, `Peerage`, `Date`) match the template's existing field reads at lines 1716–1738.
- **Placeholder scan:** No TBD/TODO; every code step shows full code; every command shows expected output. The only `<...>` are the user-substituted DB ids in T8, which is correct (runtime values).
