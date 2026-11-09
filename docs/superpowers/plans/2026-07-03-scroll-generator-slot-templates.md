# Scroll Generator (Slot-Based Templates) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the procedural illuminated-manuscript scroll engine with a slot-based template system: a fixed Letter page with an auto-scaling central text area plus placeable graphic slots, token auto-fill, a kingdom-officer designer + a granter filler, and a direct client-side PDF download.

**Architecture:** Everything renders as semantic HTML/CSS on a fixed Letter-ratio page (real webfonts, fit-to-viewport, print/PDF to 8.5×11). Templates are JSON (`slots` + `zones`) stored in `ork_scroll_template`, authored in a designer surface and filled in a builder surface. Graphics come from the reused artwork library (`ork_scroll_artwork`), auto-pulled ORK heraldry, and built-in packs seeded from Alona of Two Trees' CC art library. PDF is generated client-side (vendored jsPDF + html2canvas).

**Tech Stack:** PHP 8 (controllers `orkui/controller/`, lib `system/lib/ork3/`, models `orkui/model/`), MariaDB, plain-PHP `.tpl` templates (`extract()`+`include`, NOT Smarty), vanilla JS, custom PHP test harness (`tests/scroll/lib/assert.php`), Docker (app `http://localhost:19080/orkui/`, db container `ork3-php8-db`).

## Global Constraints

- **`.tpl` files are plain PHP** — use `<?php ?>`/`<?= ?>`, never Smarty `{$var}`/`{if}`/`{foreach}`.
- **Never stage/commit `system/lib/ork3/class.Authorization.php`** (login-bypass hack present). Stage files explicitly; never `git add -A`/`git add .`. Run `git diff --cached` before every commit.
- **Never commit `CLAUDE.md` / `agent-instructions/claude.md`.**
- **Editing PHP: normalize-first** — before a multi-line Edit, check `awk '/^\t/{c++} END{print c+0}' <file>` (0 = clean → Edit directly; dirty → run `php tools/php-cs-fixer.phar fix --config=.php-cs-fixer.dist.php <file>` first).
- **PHP/.tpl/.js use TAB indentation.**
- **Dark-mode compatible** — selector is `html[data-theme="dark"]` (NOT `body.dark-mode`). UI chrome must be dark-mode safe; the scroll surface itself always renders on its own light background. Verify drawers/modals/panels in dark mode.
- **`$DB->Clear()` before every raw Execute/DataSet** (stale PDO bindings cause silent failures).
- **Controller action session accessor:** `$this->session->user_id` (or `_uid()`), NOT `$this->__session`.
- **CMS CSRF:** POST mutations validate `X-CSRF-Token` (from `window.CMS_CSRF`) in `_begin()`; every POST fetch must send the header.
- **No native `title`/`confirm()`/`alert()`** — use `data-tip` tooltips and `tnConfirm()`.
- **FontAwesome 5.8.2 only** (FA6 names render blank).
- **Fixed Letter page** — portrait aspect `8.5/11`, landscape `11/8.5`; content fits inside the page, never grows the page. Print/PDF to 8.5in×11in (or 11×8.5).
- **Frequent commits**, one per task. PR title convention: `Enhancement: {Title}`.

---

## File Structure

**Backend (create):**
- `db-migrations/2026-07-03-scroll-template.sql` — `ork_scroll_template` table.
- `db-migrations/2026-07-03-scroll-artwork-family-backout.sql` — drop dead family columns + purge `system_owned=1` rows (reconcile local DB with rewritten `2026-04-25` migration).
- `system/lib/ork3/class.ScrollTemplate.php` — template CRUD, JSON encode/decode, kingdom-scoped list, starter seeding.
- `orkui/model/model.ScrollTemplate.php` — thin pass-through.
- `orkui/controller/controller.ScrollTemplateAjax.php` — list/load/save/delete/share endpoints (auth + CSRF).
- `system/scripts/seed-scroll-templates.php` — 3 starter templates + built-in-pack seeder (from `system/assets/scroll/packs/catalog.json`).

**Backend (modify):**
- `db-migrations/2026-04-25-scroll-family-assets.sql` — rewrite to add only `system_owned`, `source_attribution`, `source_license`.
- `orkui/controller/controller.Scroll.php` — rework `builder()` (drop family data; provide templates + tokens); add `design()` action.

**Backend (delete):** `class.ScrollFamilyRenderer.php`, `class.ScrollPalette.php`, `class.ScrollDecoration.php`, `class.ScrollPrimitives.php`, `controller.ScrollAjax.php`, `system/scripts/seed-scroll-families.php`, `tools/scroll_forge_inline.py`, `inline_forge.py`.

**Frontend (create):**
- `orkui/template/revised-frontend/scroll/scroll-render.js` — shared page renderer + token resolver.
- `orkui/template/revised-frontend/scroll/scroll-builder.js` — filler logic + PDF export.
- `orkui/template/revised-frontend/scroll/scroll-design.js` — designer logic (drag → % coords, inspector, save).
- `orkui/template/revised-frontend/style/scroll.css` — page/slot/zone/inspector styling (dark-mode chrome).
- `orkui/template/revised-frontend/Scroll_design.tpl` — designer page.
- `vendor/jspdf.umd.min.js`, `vendor/html2canvas.min.js` (force-added).

**Frontend (modify):** `orkui/template/revised-frontend/Scroll_builder.tpl` — replace 14k-line forge with lean filler page.

**Frontend (delete):** `scroll/scroll-decoration.js`, `scroll/scroll-primitives.js`, `scroll/scroll-families.js`, `scroll/scroll-palette.js`, `scroll/families.json`, `assets/scroll/celticknot.js`, the entire `scroll-forge/` dir.

**Assets:**
- Keep `assets/scroll/fonts/` (20 TTFs).
- `system/assets/scroll/packs/{borders,backgrounds,orders,heraldry}/` + `catalog.json` + `ATTRIBUTION.md` (ingested separately; catalog is consumed by the seeder).
- Delete `system/assets/scroll/forge/*`, `system/assets/scroll/families/*`.

**Tests:** `tests/scroll/` — delete family/ornament/gilding/versal/grounds/manifest tests; add `test_scroll_template.php`, `test_token_resolver.php`, `test_template_ajax.php`.

---

## Task Overview

- **Phase 1 — Excision** (Tasks 1–2): delete engine, strip wiring, rewrite/reconcile the family migration.
- **Phase 2 — Data layer** (Tasks 3–6): template table, lib CRUD, model, AJAX endpoints.
- **Phase 3 — Renderer** (Tasks 7–8): shared page CSS + JS renderer + token resolver.
- **Phase 4 — Filler** (Tasks 9–12): builder controller, page, JS, PDF export.
- **Phase 5 — Designer** (Tasks 13–16): design action, page, JS, starter/pack seeder.
- **Phase 6 — Polish/QA** (Tasks 17–19): dark mode, print/PDF fidelity, test refresh.

---

## Phase 1 — Excision

### Task 1: Delete the procedural engine and strip its wiring

**Files:**
- Delete (lib): `system/lib/ork3/class.ScrollFamilyRenderer.php`, `class.ScrollPalette.php`, `class.ScrollDecoration.php`, `class.ScrollPrimitives.php`
- Delete (controller): `orkui/controller/controller.ScrollAjax.php`
- Delete (scripts/tools): `system/scripts/seed-scroll-families.php`, `tools/scroll_forge_inline.py`, `inline_forge.py`
- Delete (frontend): `orkui/template/revised-frontend/scroll/scroll-decoration.js`, `scroll-primitives.js`, `scroll-families.js`, `scroll-palette.js`, `scroll/families.json`, `assets/scroll/celticknot.js`, and the entire `orkui/template/revised-frontend/scroll-forge/` directory
- Delete (assets): `system/assets/scroll/forge/`, `system/assets/scroll/families/`
- Delete (tests): the family/ornament/gilding/versal/grounds/manifest tests under `tests/scroll/` (keep the artwork-library tests: `test_submission_tiers.php`, `test_categories.php`, `test_moderation_authority.php`, `test_curated_assets.php` — verify each keeper does not `require` a deleted class before keeping)
- Modify: `orkui/template/revised-frontend/Scroll_builder.tpl` — replace with a minimal stub (heading + "rebuilding" note) so the route resolves; full filler lands in Task 10
- Modify: any router/registry that references `ScrollAjax` (grep to find)

**Interfaces:**
- Produces: a booting app with the `Scroll/builder/...` route resolving to a stub page and zero references to deleted symbols.

- [ ] **Step 1: Inventory references before deleting.** Run and record output:

```bash
cd /Users/averykrouse/GitHub/ORK-tobias/ORK3-tobias
grep -rIl --exclude-dir=.git -e 'ScrollAjax' -e 'ScrollFamilyRenderer' -e 'ScrollDecoration' \
  -e 'ScrollPrimitives' -e 'ScrollPalette' -e 'scroll-forge' -e 'celticknot' -e 'families.json' \
  -e 'scroll_forge_inline' -e 'inline_forge' orkui system tests tools 2>/dev/null
```
Expected: a list of files. Every hit outside the files being deleted is a wiring reference to fix in Step 3.

- [ ] **Step 2: Delete the engine files/dirs.**

```bash
cd /Users/averykrouse/GitHub/ORK-tobias/ORK3-tobias
git rm -r system/lib/ork3/class.ScrollFamilyRenderer.php system/lib/ork3/class.ScrollPalette.php \
  system/lib/ork3/class.ScrollDecoration.php system/lib/ork3/class.ScrollPrimitives.php \
  orkui/controller/controller.ScrollAjax.php system/scripts/seed-scroll-families.php \
  tools/scroll_forge_inline.py inline_forge.py \
  orkui/template/revised-frontend/scroll/scroll-decoration.js \
  orkui/template/revised-frontend/scroll/scroll-primitives.js \
  orkui/template/revised-frontend/scroll/scroll-families.js \
  orkui/template/revised-frontend/scroll/scroll-palette.js \
  orkui/template/revised-frontend/scroll/families.json \
  assets/scroll/celticknot.js \
  orkui/template/revised-frontend/scroll-forge \
  system/assets/scroll/forge system/assets/scroll/families
```
(If a path 404s because it moved, adjust — do not force. Use `git rm` so deletions are staged; `inline_forge.py` may live at repo root or under `tools/` — grep first.)

- [ ] **Step 3: Fix each wiring reference from Step 1.** For any router/controller registry that maps a `ScrollAjax` route, remove that mapping. For any keeper test that `require`s a deleted class, delete that test too. Re-run the Step 1 grep; expected: only matches inside this plan/spec docs remain (zero in `orkui`/`system`/`tools`).

- [ ] **Step 4: Replace `Scroll_builder.tpl` with a stub.**

```php
<?php /* Scroll_builder.tpl — filler rebuilt in Task 10. Plain PHP template. */ ?>
<div class="sf-rebuild-note" style="max-width:640px;margin:4rem auto;text-align:center;font:16px/1.5 system-ui;">
	<h1 style="background:transparent;border:none;padding:0;border-radius:0;text-shadow:none;">Scroll Generator</h1>
	<p>The scroll builder is being rebuilt. Check back shortly.</p>
</div>
```

- [ ] **Step 5: Verify the app boots and the route resolves.**

```bash
curl -s -o /dev/null -w '%{http_code}\n' 'http://localhost:19080/orkui/index.php?Route=Scroll/builder/2/671'
```
Expected: `200` (not `500`). Also `curl -s 'http://localhost:19080/orkui/index.php?Route=Home' -o /dev/null -w '%{http_code}\n'` → `200`.

- [ ] **Step 6: Verify no dangling PHP includes.**

```bash
php -l orkui/controller/controller.Scroll.php && echo "controller OK"
```
Expected: `No syntax errors`. Then reload `Scroll/builder/2/671` in the browser (dark + light) — stub renders, no console errors about missing scripts.

- [ ] **Step 7: Commit.**

```bash
git status   # confirm class.Authorization.php is NOT among staged files
git diff --cached --stat
git commit -m "Scroll rebuild: excise procedural illuminated-manuscript engine"
```

---

### Task 2: Rewrite the family-assets migration and reconcile the DB

**Files:**
- Modify: `db-migrations/2026-04-25-scroll-family-assets.sql`
- Create: `db-migrations/2026-07-03-scroll-artwork-family-backout.sql`

**Interfaces:**
- Produces: `ork_scroll_artwork` with `system_owned`, `source_attribution`, `source_license` retained and `family_key`/`asset_role`/`tint_mode` gone; zero `system_owned=1` rows (dead family art). These three retained columns are consumed by the built-in-pack seeder in Task 16.

- [ ] **Step 1: Rewrite `2026-04-25-scroll-family-assets.sql`** to add only the retained columns (this file is branch-only, safe to rewrite):

```sql
-- 2026-04-25 · Scroll · flag system-owned (built-in pack) artwork + source metadata
ALTER TABLE ork_scroll_artwork
  ADD COLUMN system_owned TINYINT(1) NOT NULL DEFAULT 0 AFTER status,
  ADD COLUMN source_attribution TEXT NULL AFTER system_owned,
  ADD COLUMN source_license VARCHAR(64) NULL AFTER source_attribution,
  ADD INDEX idx_system_owned (system_owned);
```

- [ ] **Step 2: Create the backout/reconciliation migration** for DBs that already applied the old version:

```sql
-- 2026-07-03 · Scroll · back out dead family-engine columns + purge family asset rows.
-- Idempotent-ish: guard column drops so re-runs don't fatal.
DELETE FROM ork_scroll_artwork WHERE system_owned = 1;

SET @c := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'ork_scroll_artwork' AND column_name = 'family_key');
SET @s := IF(@c > 0, 'ALTER TABLE ork_scroll_artwork DROP INDEX idx_family_role, DROP COLUMN family_key, DROP COLUMN asset_role, DROP COLUMN tint_mode', 'SELECT 1');
PREPARE stmt FROM @s; EXECUTE stmt; DEALLOCATE PREPARE stmt;
```

- [ ] **Step 3: Apply to the local DB.**

```bash
docker exec -i ork3-php8-db mariadb -uroot -proot ork < db-migrations/2026-07-03-scroll-artwork-family-backout.sql
```
Expected: no error.

- [ ] **Step 4: Verify the schema + purge.**

```bash
docker exec ork3-php8-db mariadb -uroot -proot ork -e \
  "SHOW COLUMNS FROM ork_scroll_artwork; SELECT COUNT(*) purged_should_be_0 FROM ork_scroll_artwork WHERE system_owned=1;"
```
Expected: columns include `system_owned`, `source_attribution`, `source_license`; NO `family_key`/`asset_role`/`tint_mode`; `purged_should_be_0` = 0.

- [ ] **Step 5: Commit.**

```bash
git add db-migrations/2026-04-25-scroll-family-assets.sql db-migrations/2026-07-03-scroll-artwork-family-backout.sql
git commit -m "Scroll rebuild: trim family-assets migration to pack columns + DB backout"
```

---

## Phase 2 — Data Layer

> **Auth note (verified in codebase):** the scroll AJAX siblings authenticate with
> `$mundane_id = Ork3::$Lib->authorization->IsAuthorized($this->session->token)` then
> `Ork3::$Lib->authorization->HasAuthority($mundane_id, AUTH_KINGDOM, $kingdom_id, AUTH_EDIT)`.
> There is NO `X-CSRF-Token` header handling in `ScrollArtworkAjax` — mirror the sibling's
> session-token auth, do not invent CSRF header plumbing here.
>
> **Lib registration:** `class.ScrollArtwork.php` is reachable as `Ork3::$Lib->scrollartwork`.
> Before Task 4, open `class.ScrollArtwork.php` and note its class declaration, how it
> obtains `$this->db`, and how the lib is registered/autoloaded; `class.ScrollTemplate.php`
> MUST mirror all three exactly (same base class, same `$this->db` handle, same registration
> so it resolves as `Ork3::$Lib->scrolltemplate`).

### Task 3: `ork_scroll_template` migration

**Files:**
- Create: `db-migrations/2026-07-03-scroll-template.sql`

**Interfaces:**
- Produces: table `ork_scroll_template` with columns consumed by Tasks 4/16.

- [ ] **Step 1: Write the migration.**

```sql
-- 2026-07-03 · Scroll · slot-based template store.
CREATE TABLE `ork_scroll_template` (
  `scroll_template_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `kingdom_id`  INT UNSIGNED NULL,                              -- NULL = shared starter
  `name`        VARCHAR(150) NOT NULL,
  `orientation` ENUM('portrait','landscape') NOT NULL DEFAULT 'portrait',
  `bg_type`     ENUM('color','texture','image') NOT NULL DEFAULT 'color',
  `bg_value`    VARCHAR(255) NOT NULL DEFAULT '#ffffff',
  `slots`       JSON NOT NULL,
  `zones`       JSON NOT NULL,
  `is_starter`  TINYINT(1) NOT NULL DEFAULT 0,
  `status`      ENUM('active','archived') NOT NULL DEFAULT 'active',
  `created_by`  INT UNSIGNED NOT NULL,
  `created_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `modified`    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`scroll_template_id`),
  KEY `idx_kingdom_status` (`kingdom_id`, `status`),
  KEY `idx_starter` (`is_starter`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

- [ ] **Step 2: Apply + verify.**

```bash
docker exec -i ork3-php8-db mariadb -uroot -proot ork < db-migrations/2026-07-03-scroll-template.sql
docker exec ork3-php8-db mariadb -uroot -proot ork -e "SHOW COLUMNS FROM ork_scroll_template;"
```
Expected: 12 columns as declared; `slots`/`zones` type `longtext` (MariaDB renders JSON as longtext) or `json`.

- [ ] **Step 3: Commit.**

```bash
git add db-migrations/2026-07-03-scroll-template.sql
git commit -m "Scroll rebuild: ork_scroll_template migration"
```

---

### Task 4: `class.ScrollTemplate.php` — CRUD + token resolver

**Files:**
- Create: `system/lib/ork3/class.ScrollTemplate.php`
- Test: `tests/scroll/test_scroll_template.php`, `tests/scroll/test_token_resolver.php`

**Interfaces:**
- Produces (mirror ScrollArtwork's class/base/`$this->db`/registration):
  - `create(array $req): array` — keys `KingdomId(int|null)`, `Name`, `Orientation`, `BgType`, `BgValue`, `Slots(array)`, `Zones(array)`, `IsStarter(int)`, `CreatedBy(int)`. Returns `['Status'=>Success(), 'TemplateId'=>int]` or `['Status'=>InvalidParameter(...)]`.
  - `get(int $id): array` — `['Template'=>row, 'Status'=>Success()]` (row has `slots`/`zones` decoded to arrays) or not-found status.
  - `listForKingdom(int $kingdomId): array` — starters (`is_starter=1`) + that kingdom's active templates. `['Templates'=>[...], 'Status'=>Success()]`.
  - `update(int $id, array $req): array`, `delete(int $id): array` (soft: set `status='archived'`).
  - `static resolveTokens(string $text, array $map): string` — replaces `{Key}` with `$map['Key']`; unknown tokens left as-is for the UI to flag; case-sensitive keys.
- Consumes: `$this->db` (Clear/Execute/DataSet/GetLastInsertId), `Success()`, `InvalidParameter()`, `DB_PREFIX`.

- [ ] **Step 1: Write failing token-resolver test.** `tests/scroll/test_token_resolver.php`:

```php
<?php
require_once __DIR__ . '/lib/assert.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollTemplate.php';

test_section('resolveTokens');
$map = ['PlayerName' => 'Auromax Silverhawke', 'AwardName' => 'Order of the Rose', 'Date' => 'the 17th of January'];
assert_equals('Auromax Silverhawke', ScrollTemplate::resolveTokens('{PlayerName}', $map), 'single token');
assert_equals('for Order of the Rose!', ScrollTemplate::resolveTokens('for {AwardName}!', $map), 'token in sentence');
assert_equals('{Unknown}', ScrollTemplate::resolveTokens('{Unknown}', $map), 'unknown token preserved');
assert_equals('A {AwardName} on {Date}', ScrollTemplate::resolveTokens('A {AwardName} on {Date}', $map), 'multiple tokens');
echo "\nALL PASS\n";
```

- [ ] **Step 2: Run it, expect failure** (class not defined):

```bash
docker exec -w /var/www/ork.amtgard.com/tests/scroll ork3-php8-app php test_token_resolver.php
```
Expected: fatal "class ScrollTemplate not found".

- [ ] **Step 3: Write `class.ScrollTemplate.php`.** Open `class.ScrollArtwork.php` first and copy its class declaration, base class, `$this->db` acquisition, and registration hook; then implement:

```php
<?php
// class.ScrollTemplate.php — slot-based scroll template store.
// MIRROR the class header / base class / $this->db handle / lib registration of class.ScrollArtwork.php.
class ScrollTemplate /* extends <same base as ScrollArtwork> */ {

	// ---- static token resolver (pure; unit-tested) ----
	public static function resolveTokens($text, array $map) {
		return preg_replace_callback('/\{([A-Za-z][A-Za-z0-9]*)\}/', function ($m) use ($map) {
			return array_key_exists($m[1], $map) ? $map[$m[1]] : $m[0];
		}, (string)$text);
	}

	public function create($req) {
		$name = trim($req['Name'] ?? '');
		if ($name === '') { return ['Status' => InvalidParameter(null, 'Name required.')]; }
		$orientation = in_array($req['Orientation'] ?? '', ['portrait','landscape'], true) ? $req['Orientation'] : 'portrait';
		$bgType = in_array($req['BgType'] ?? '', ['color','texture','image'], true) ? $req['BgType'] : 'color';
		$this->db->Clear();
		$this->db->kingdom_id = ($req['KingdomId'] ?? null) ? (int)$req['KingdomId'] : null;
		$this->db->name        = $name;
		$this->db->orientation = $orientation;
		$this->db->bg_type     = $bgType;
		$this->db->bg_value    = (string)($req['BgValue'] ?? '#ffffff');
		$this->db->slots       = json_encode(array_values($req['Slots'] ?? []));
		$this->db->zones       = json_encode(array_values($req['Zones'] ?? []));
		$this->db->is_starter  = !empty($req['IsStarter']) ? 1 : 0;
		$this->db->created_by  = (int)($req['CreatedBy'] ?? 0);
		$cols = ['kingdom_id','name','orientation','bg_type','bg_value','slots','zones','is_starter','created_by'];
		$ph = array_map(function ($c) { return ':' . $c; }, $cols);
		$sql = "INSERT INTO " . DB_PREFIX . "scroll_template (" . implode(',', $cols) . ") VALUES (" . implode(',', $ph) . ")";
		$this->db->Execute($sql);
		return ['Status' => Success(), 'TemplateId' => (int)$this->db->GetLastInsertId()];
	}

	public function get($id) {
		$this->db->Clear();
		$this->db->scroll_template_id = (int)$id;
		$sql = "SELECT * FROM " . DB_PREFIX . "scroll_template WHERE scroll_template_id = :scroll_template_id";
		$r = $this->db->DataSet($sql);
		if ($r->Size() > 0 && $r->Next()) { return ['Template' => $this->format_row($r), 'Status' => Success()]; }
		return ['Status' => InvalidParameter(null, 'Template not found.')];
	}

	public function listForKingdom($kingdomId) {
		$this->db->Clear();
		$this->db->kingdom_id = (int)$kingdomId;
		$sql = "SELECT * FROM " . DB_PREFIX . "scroll_template
			WHERE status='active' AND (is_starter=1 OR kingdom_id = :kingdom_id)
			ORDER BY is_starter DESC, name ASC";
		$r = $this->db->DataSet($sql);
		$out = [];
		while ($r->Next()) { $out[] = $this->format_row($r); }
		return ['Templates' => $out, 'Status' => Success()];
	}

	public function update($id, $req) {
		$this->db->Clear();
		$this->db->scroll_template_id = (int)$id;
		$this->db->name        = trim($req['Name'] ?? '');
		$this->db->orientation = in_array($req['Orientation'] ?? '', ['portrait','landscape'], true) ? $req['Orientation'] : 'portrait';
		$this->db->bg_type     = in_array($req['BgType'] ?? '', ['color','texture','image'], true) ? $req['BgType'] : 'color';
		$this->db->bg_value    = (string)($req['BgValue'] ?? '#ffffff');
		$this->db->slots       = json_encode(array_values($req['Slots'] ?? []));
		$this->db->zones       = json_encode(array_values($req['Zones'] ?? []));
		$sql = "UPDATE " . DB_PREFIX . "scroll_template SET name=:name, orientation=:orientation,
			bg_type=:bg_type, bg_value=:bg_value, slots=:slots, zones=:zones
			WHERE scroll_template_id = :scroll_template_id";
		$this->db->Execute($sql);
		return ['Status' => Success()];
	}

	public function delete($id) {
		$this->db->Clear();
		$this->db->scroll_template_id = (int)$id;
		$sql = "UPDATE " . DB_PREFIX . "scroll_template SET status='archived' WHERE scroll_template_id = :scroll_template_id";
		$this->db->Execute($sql);
		return ['Status' => Success()];
	}

	private function format_row($r) {
		return [
			'scroll_template_id' => (int)$r->scroll_template_id,
			'kingdom_id'  => $r->kingdom_id !== null ? (int)$r->kingdom_id : null,
			'name'        => $r->name,
			'orientation' => $r->orientation,
			'bg_type'     => $r->bg_type,
			'bg_value'    => $r->bg_value,
			'slots'       => json_decode($r->slots ?? '[]', true) ?: [],
			'zones'       => json_decode($r->zones ?? '[]', true) ?: [],
			'is_starter'  => (int)$r->is_starter,
		];
	}
}
```
Note: if ScrollArtwork reads columns as `$r->col` via a different accessor (e.g. `$r->Get('col')`), match that in `format_row`.

- [ ] **Step 4: Run the token test, expect PASS.**

```bash
docker exec -w /var/www/ork.amtgard.com/tests/scroll ork3-php8-app php test_token_resolver.php
```
Expected: `ALL PASS`.

- [ ] **Step 5: Write CRUD integration test** `tests/scroll/test_scroll_template.php` (round-trips against the DB; mirror how any existing DB-touching scroll test bootstraps `Ork3::$Lib` — check `test_php_render.php`/`test_curated_assets.php` for the bootstrap include; if lib bootstrap is unavailable in the CLI test harness, assert `create`/`get` via a thin script run inside the app container that calls `Ork3::$Lib->scrolltemplate`):

```php
<?php
require_once __DIR__ . '/lib/assert.php';
// Bootstrap Ork3::$Lib exactly as the existing DB-touching scroll tests do (copy that include block).
test_section('ScrollTemplate CRUD');
$lib = Ork3::$Lib->scrolltemplate;
$res = $lib->create([
	'KingdomId' => null, 'Name' => 'Test Starter', 'Orientation' => 'portrait',
	'BgType' => 'color', 'BgValue' => '#ffffff',
	'Slots' => [['location'=>'full_border','x'=>0,'y'=>0,'w'=>100,'h'=>100,'source_type'=>'pack','source_ref'=>'borders/scroll_border.png']],
	'Zones' => [['key'=>'recipient','label'=>'Recipient','text'=>'{PlayerName}','font'=>'Cinzel','size'=>48]],
	'IsStarter' => 1, 'CreatedBy' => 1,
]);
assert_equals(0, $res['Status']['Status'] ?? -1, 'create ok');   // Success() has Status==0
$id = $res['TemplateId']; assert_true($id > 0, "got template id $id");
$got = $lib->get($id);
assert_equals('Test Starter', $got['Template']['name'], 'name round-trips');
assert_equals('full_border', $got['Template']['slots'][0]['location'], 'slots JSON round-trips');
$list = $lib->listForKingdom(999999);
assert_true(count(array_filter($list['Templates'], fn($t)=>$t['scroll_template_id']==$id)) === 1, 'starter appears for any kingdom');
$lib->delete($id);
echo "\nALL PASS\n";
```
(Confirm `Success()` returns an array whose `['Status']` is `0` by checking an existing lib's usage; adjust the assertion to the real success sentinel.)

- [ ] **Step 6: Run CRUD test, expect PASS.**

```bash
docker exec -w /var/www/ork.amtgard.com/tests/scroll ork3-php8-app php test_scroll_template.php
```
Expected: `ALL PASS`.

- [ ] **Step 7: Commit.**

```bash
git add system/lib/ork3/class.ScrollTemplate.php tests/scroll/test_token_resolver.php tests/scroll/test_scroll_template.php
git commit -m "Scroll rebuild: ScrollTemplate lib (CRUD + token resolver) + tests"
```

---

### Task 5: `model.ScrollTemplate.php` pass-through

**Files:**
- Create: `orkui/model/model.ScrollTemplate.php`

**Interfaces:**
- Produces: `Model_ScrollTemplate` delegating `create/get/list_for_kingdom/update/delete` to the lib (mirror `model.Authorization.php`).

- [ ] **Step 1: Write the model** (mirror `orkui/model/model.Authorization.php`):

```php
<?php
class Model_ScrollTemplate extends Model {
	public function __construct($call = null, $method = null) {
		parent::__construct($call, $method);
		$this->ScrollTemplate = new APIModel('ScrollTemplate');
	}
	public function create($request)            { return $this->ScrollTemplate->create($request); }
	public function get($id)                     { return $this->ScrollTemplate->get($id); }
	public function list_for_kingdom($kingdomId) { return $this->ScrollTemplate->listForKingdom($kingdomId); }
	public function update($id, $request)        { return $this->ScrollTemplate->update($id, $request); }
	public function del($id)                     { return $this->ScrollTemplate->delete($id); }
}
```
Confirm `APIModel('ScrollTemplate')` resolves to the lib (same mechanism `Model_Authorization` uses). If models instead reach the lib via `Ork3::$Lib->scrolltemplate`, use that form to match the sibling.

- [ ] **Step 2: Lint + commit.**

```bash
php -l orkui/model/model.ScrollTemplate.php
git add orkui/model/model.ScrollTemplate.php
git commit -m "Scroll rebuild: ScrollTemplate model pass-through"
```

---

### Task 6: `controller.ScrollTemplateAjax.php` — CRUD endpoints

**Files:**
- Create: `orkui/controller/controller.ScrollTemplateAjax.php`
- Test: `tests/scroll/test_template_ajax.sh` (curl-based)

**Interfaces:**
- Produces endpoints (routes `ScrollTemplateAjax/<action>`):
  - `list` (GET, `?kingdom_id=`) → `{Status,Templates}`
  - `load` (GET, `?id=`) → `{Status,Template}`
  - `save` (POST) → `{Status,TemplateId}` — creates (no `id`) or updates (`id` present); requires `AUTH_KINGDOM` over the target kingdom (starters require `AUTH_ADMIN`)
  - `remove` (POST, `id`) → `{Status}` — same auth
- Consumes: `Ork3::$Lib->scrolltemplate`, `IsAuthorized`, `HasAuthority`.

- [ ] **Step 1: Write the controller** (mirror `controller.ScrollArtworkAjax.php` helpers `json_response`/`require_login`):

```php
<?php
class Controller_ScrollTemplateAjax extends Controller {
	private $st;
	public function __construct($call = null, $id = null) {
		parent::__construct($call, $id);
		$this->st = Ork3::$Lib->scrolltemplate;
	}
	private function json_response($data) { header('Content-Type: application/json'); echo json_encode($data); exit; }
	private function require_login() {
		if (!isset($this->session->user_id)) { $this->json_response(['Status'=>5,'Message'=>'Not logged in.']); }
		return (int)$this->session->user_id;
	}
	// mundane_id for the logged-in user (auth subject)
	private function mundane() { return (int)Ork3::$Lib->authorization->IsAuthorized($this->session->token); }
	// gate: kingdom officer (AUTH_KINGDOM/EDIT) over $kingdomId, or admin for starters (kingdom_id null)
	private function require_kingdom_edit($kingdomId) {
		$mid = $this->mundane();
		if ($mid <= 0) { $this->json_response(['Status'=>5,'Message'=>'Authorization failed.']); }
		$ok = $kingdomId
			? Ork3::$Lib->authorization->HasAuthority($mid, AUTH_KINGDOM, (int)$kingdomId, AUTH_EDIT)
			: Ork3::$Lib->authorization->HasAuthority($mid, AUTH_ADMIN, 0, AUTH_EDIT);
		if (!$ok) { $this->json_response(['Status'=>5,'Message'=>'Kingdom officer privileges required.']); }
		return $mid;
	}

	public function list($id = null) {
		$this->require_login();
		$res = $this->st->listForKingdom((int)($_GET['kingdom_id'] ?? 0));
		$this->json_response(['Status'=>0,'Templates'=>$res['Templates'] ?? []]);
	}
	public function load($id = null) {
		$this->require_login();
		$res = $this->st->get((int)($_GET['id'] ?? 0));
		if (($res['Status']['Status'] ?? 1) != 0) { $this->json_response(['Status'=>1,'Message'=>'Not found.']); }
		$this->json_response(['Status'=>0,'Template'=>$res['Template']]);
	}
	public function save($id = null) {
		$this->require_login();
		$body = json_decode(file_get_contents('php://input'), true) ?: [];
		$kingdomId = ($body['kingdom_id'] ?? null) ? (int)$body['kingdom_id'] : null;
		$mid = $this->require_kingdom_edit($kingdomId);
		$req = [
			'KingdomId'=>$kingdomId, 'Name'=>$body['name'] ?? '', 'Orientation'=>$body['orientation'] ?? 'portrait',
			'BgType'=>$body['bg_type'] ?? 'color', 'BgValue'=>$body['bg_value'] ?? '#ffffff',
			'Slots'=>$body['slots'] ?? [], 'Zones'=>$body['zones'] ?? [],
			'IsStarter'=>!empty($body['is_starter']) ? 1 : 0, 'CreatedBy'=>$mid,
		];
		if (!empty($body['id'])) { $this->st->update((int)$body['id'], $req); $this->json_response(['Status'=>0,'TemplateId'=>(int)$body['id']]); }
		$res = $this->st->create($req);
		$this->json_response(['Status'=>0,'TemplateId'=>$res['TemplateId'] ?? 0]);
	}
	public function remove($id = null) {
		$this->require_login();
		$body = json_decode(file_get_contents('php://input'), true) ?: [];
		$tid = (int)($body['id'] ?? 0);
		$tpl = $this->st->get($tid);
		$kingdomId = $tpl['Template']['kingdom_id'] ?? null;
		$this->require_kingdom_edit($kingdomId);
		$this->st->delete($tid);
		$this->json_response(['Status'=>0]);
	}
}
```
Note: `list` is a PHP reserved word only as a language construct, not a method name — it is legal as a method. If the router rejects it, rename to `templates`. Register the controller/route if the router needs an explicit entry (check how `ScrollArtworkAjax` is routed and add the parallel entry).

- [ ] **Step 2: Write a curl smoke test** `tests/scroll/test_template_ajax.sh` (unauth list should still return JSON with a Status; save without auth must be rejected):

```bash
#!/usr/bin/env bash
BASE='http://localhost:19080/orkui/index.php?Route=ScrollTemplateAjax'
echo "== list ==";  curl -s "$BASE/list&kingdom_id=1" | head -c 300; echo
echo "== save unauth (expect Status 5) =="; \
  curl -s -X POST "$BASE/save" -H 'Content-Type: application/json' \
  -d '{"name":"x","kingdom_id":1,"slots":[],"zones":[]}' | head -c 300; echo
```

- [ ] **Step 3: Run it.**

```bash
bash tests/scroll/test_template_ajax.sh
```
Expected: `list` returns `{"Status":0,"Templates":[...]}` (valid JSON, not a 500 HTML page); `save` unauth returns a `Status` of `5` (rejected). Confirm no PHP notice leaks into the JSON.

- [ ] **Step 4: Commit.**

```bash
git add orkui/controller/controller.ScrollTemplateAjax.php tests/scroll/test_template_ajax.sh
git commit -m "Scroll rebuild: ScrollTemplateAjax CRUD endpoints"
```

---

## Phase 3 — Shared Renderer

**Data shapes (canonical — used by all Phase 3–5 tasks):**

```js
// slot: a graphic box, coordinates are PERCENT (0–100) of the page box
{ location:'full_border'|'border_left'|'border_right'|'border_top'|'border_bottom'|'center_image'|'top_graphic'|'watermark',
  x:Number, y:Number, w:Number, h:Number,          // percent of page
  source_type:'library'|'heraldry'|'pack'|'none',
  source_ref:String,                                // artwork id | 'kingdom'|'park'|'player' | pack path e.g. 'borders/scroll_border.png'
  fit:'contain'|'cover'|'stretch' }                 // default 'contain'
// zone: a text box, coordinates PERCENT of page
{ key:String, label:String, text:String,            // text may contain {Tokens}
  font:String, size:Number,                          // size in page-CSS px at 816-wide portrait base
  min:Number, max:Number,                            // autoscale bounds (px); size clamps within
  align:'left'|'center'|'right', color:String, inherit_color:Boolean,
  x:Number, y:Number, w:Number, h:Number, autoscale:Boolean }
```

### Task 7: `scroll.css` — page, slots, zones, backgrounds, both orientations, dark chrome

**Files:**
- Create: `orkui/template/revised-frontend/style/scroll.css`

**Interfaces:**
- Produces CSS classes consumed by the renderer/pages: `.sc-stage`, `.sc-page`, `.sc-page[data-orientation]`, `.sc-bg`, `.sc-slot`, `.sc-zone`, `.sc-panel`, `.sc-inspector`. Fonts registered via `@font-face` from `assets/scroll/fonts/`.

- [ ] **Step 1: Write the CSS.** Core structure (complete; extend fonts to all 20 TTFs):

```css
/* scroll.css — slot-based scroll renderer. Chrome is dark-mode aware; the page surface is always light. */
:root { --sc-page-w: 816px; }  /* 8.5in @ 96dpi; height derives from aspect-ratio */

/* --- webfonts (repeat @font-face for each of the 20 TTFs in assets/scroll/fonts/) --- */
@font-face { font-family:'Cinzel';            src:url('../../../assets/scroll/fonts/Cinzel-Regular.ttf') format('truetype'); font-display:swap; }
@font-face { font-family:'Cinzel Decorative'; src:url('../../../assets/scroll/fonts/CinzelDecorative-Regular.ttf') format('truetype'); font-display:swap; }
@font-face { font-family:'EB Garamond';       src:url('../../../assets/scroll/fonts/EBGaramond-Regular.ttf') format('truetype'); font-display:swap; }
@font-face { font-family:'UnifrakturMaguntia';src:url('../../../assets/scroll/fonts/UnifrakturMaguntia-Book.ttf') format('truetype'); font-display:swap; }
@font-face { font-family:'Great Vibes';       src:url('../../../assets/scroll/fonts/GreatVibes-Regular.ttf') format('truetype'); font-display:swap; }
/* ...remaining 15 fonts... */

.sc-stage { position:relative; width:100%; display:flex; justify-content:center; align-items:flex-start;
	overflow:hidden; background:#e9e9ee; padding:16px; box-sizing:border-box; }
html[data-theme="dark"] .sc-stage { background:#20232a; }

/* the fixed Letter page; JS scales it to fit the stage via transform */
.sc-page { position:relative; width:var(--sc-page-w); aspect-ratio:8.5/11; transform-origin:top center;
	background:#fff; box-shadow:0 2px 18px rgba(0,0,0,.35); overflow:hidden; }
.sc-page[data-orientation="landscape"] { aspect-ratio:11/8.5; }

.sc-bg { position:absolute; inset:0; z-index:0; background-size:cover; background-position:center; }
.sc-bg[data-bg-type="texture"] { background-repeat:repeat; background-size:auto; }

.sc-slot { position:absolute; z-index:1; }                 /* x/y/w/h set inline as % by JS */
.sc-slot img { width:100%; height:100%; object-fit:contain; display:block; }
.sc-slot[data-fit="cover"] img { object-fit:cover; }
.sc-slot[data-fit="stretch"] img { object-fit:fill; }

.sc-zone { position:absolute; z-index:2; overflow:hidden; box-sizing:border-box;
	display:flex; flex-direction:column; justify-content:center; }
.sc-zone[data-align="left"]   { text-align:left; align-items:flex-start; }
.sc-zone[data-align="center"] { text-align:center; align-items:center; }
.sc-zone[data-align="right"]  { text-align:right; align-items:flex-end; }
.sc-zone .sc-token-unfilled { outline:1px dashed #b00; opacity:.6; }  /* editor-only; print hides via .sc-print */

/* editor chrome (designer/filler panels) — dark-mode aware */
.sc-panel { background:#fff; border:1px solid #ccc; border-radius:6px; }
html[data-theme="dark"] .sc-panel { background:#2a2e37; border-color:#444; color:#e8e8ea; }
.sc-inspector label { display:block; font:12px/1.4 system-ui; margin:.4rem 0 .1rem; }
html[data-theme="dark"] .sc-inspector label { color:#c8c8cc; }

/* designer-only slot/zone handles */
.sc-editing .sc-slot, .sc-editing .sc-zone { outline:1px solid rgba(40,90,200,.5); cursor:move; }
.sc-editing .sc-zone[contenteditable] { cursor:text; }
```

- [ ] **Step 2: Verify it loads with no 404s.** Add a throwaway link in the Task 1 stub temporarily, load `Scroll/builder/2/671`, open DevTools Network → confirm `scroll.css` and every font `200`s. Remove the throwaway link. (Or `curl -sI '<HTTP_TEMPLATE>revised-frontend/style/scroll.css' | head -1` → `200`.)

- [ ] **Step 3: Commit.**

```bash
git add orkui/template/revised-frontend/style/scroll.css
git commit -m "Scroll rebuild: slot/zone/page renderer CSS + webfonts"
```

---

### Task 8: `scroll-render.js` — render + fit-to-stage + JS token substitution

**Files:**
- Create: `orkui/template/revised-frontend/scroll/scroll-render.js`

**Interfaces:**
- Produces global `ScrollRender` with:
  - `renderPage(pageEl, template, {tokens, packBase, libBase, heraldry, editable})` — populates `pageEl` (an `.sc-page`) with bg + slots + zones from `template` (`{orientation,bg_type,bg_value,slots,zones}`); resolves `{Tokens}` in zone text using `tokens`; wraps unresolved tokens in `<span class="sc-token-unfilled">` when `editable`.
  - `resolveTokens(text, map)` — JS mirror of PHP `ScrollTemplate::resolveTokens`.
  - `autoscaleZones(pageEl)` — shrinks each `[data-autoscale]` zone's font-size until content fits (down to its `min`).
  - `fitToStage(pageEl, stageEl)` — sets `pageEl.style.transform = scale(k)` so the page fits `stageEl` (pairs rAF with a setTimeout fallback — rAF is paused in background tabs).
  - `slotSrc(slot, {packBase, libBase, heraldry})` — resolves a slot's image URL.

- [ ] **Step 1: Write the renderer** (complete):

```js
/* scroll-render.js — render a slot-based scroll template into a fixed Letter page. */
(function (w) {
	function resolveTokens(text, map) {
		return String(text == null ? '' : text).replace(/\{([A-Za-z][A-Za-z0-9]*)\}/g, function (m, k) {
			return Object.prototype.hasOwnProperty.call(map || {}, k) ? map[k] : m;
		});
	}
	function slotSrc(slot, ctx) {
		if (slot.source_type === 'pack')     return ctx.packBase + slot.source_ref;
		if (slot.source_type === 'library')  return ctx.libBase + encodeURIComponent(slot.source_ref);
		if (slot.source_type === 'heraldry') return (ctx.heraldry && ctx.heraldry[slot.source_ref]) || '';
		return '';
	}
	function pct(v) { return (Number(v) || 0) + '%'; }

	function renderPage(pageEl, tpl, opts) {
		opts = opts || {}; var tokens = opts.tokens || {};
		pageEl.setAttribute('data-orientation', tpl.orientation || 'portrait');
		pageEl.innerHTML = '';
		// background
		var bg = document.createElement('div');
		bg.className = 'sc-bg'; bg.setAttribute('data-bg-type', tpl.bg_type || 'color');
		if (tpl.bg_type === 'color')        bg.style.background = tpl.bg_value || '#ffffff';
		else if (tpl.bg_type === 'texture') bg.style.backgroundImage = 'url(' + opts.packBase + 'backgrounds/' + tpl.bg_value + ')';
		else if (tpl.bg_type === 'image')   bg.style.backgroundImage = 'url(' + (opts.libBase + encodeURIComponent(tpl.bg_value)) + ')';
		pageEl.appendChild(bg);
		// slots
		(tpl.slots || []).forEach(function (s) {
			var el = document.createElement('div');
			el.className = 'sc-slot'; el.setAttribute('data-location', s.location); el.setAttribute('data-fit', s.fit || 'contain');
			el.style.left = pct(s.x); el.style.top = pct(s.y); el.style.width = pct(s.w); el.style.height = pct(s.h);
			var src = slotSrc(s, opts);
			if (src) { var img = document.createElement('img'); img.src = src; img.alt = ''; el.appendChild(img); }
			el.__slot = s; pageEl.appendChild(el);
		});
		// zones
		(tpl.zones || []).forEach(function (z) {
			var el = document.createElement('div');
			el.className = 'sc-zone'; el.setAttribute('data-key', z.key); el.setAttribute('data-align', z.align || 'center');
			if (z.autoscale) el.setAttribute('data-autoscale', '1');
			el.style.left = pct(z.x); el.style.top = pct(z.y); el.style.width = pct(z.w); el.style.height = pct(z.h);
			el.style.fontFamily = "'" + (z.font || 'EB Garamond') + "'";
			el.style.fontSize = (z.size || 24) + 'px';
			if (!z.inherit_color && z.color) el.style.color = z.color;
			el.dataset.min = z.min || 8; el.dataset.max = z.max || (z.size || 24);
			// token fill
			var filled = resolveTokens(z.text, tokens);
			if (opts.editable) {
				el.innerHTML = String(z.text || '').replace(/\{([A-Za-z][A-Za-z0-9]*)\}/g, function (m, k) {
					return Object.prototype.hasOwnProperty.call(tokens, k)
						? tokens[k]
						: '<span class="sc-token-unfilled">' + m + '</span>';
				}).replace(/\n/g, '<br>');
			} else {
				el.textContent = filled;
			}
			el.__zone = z; pageEl.appendChild(el);
		});
	}

	function autoscaleZones(pageEl) {
		pageEl.querySelectorAll('.sc-zone[data-autoscale]').forEach(function (el) {
			var min = parseFloat(el.dataset.min) || 8, max = parseFloat(el.dataset.max) || 24, size = max;
			el.style.fontSize = size + 'px';
			var guard = 0;
			while (size > min && (el.scrollHeight > el.clientHeight + 1 || el.scrollWidth > el.clientWidth + 1) && guard++ < 200) {
				size -= 1; el.style.fontSize = size + 'px';
			}
		});
	}

	function fitToStage(pageEl, stageEl) {
		function apply() {
			pageEl.style.transform = 'scale(1)';
			var pad = 32;
			var r = pageEl.getBoundingClientRect();                 // natural size at scale(1)
			var k = Math.min((stageEl.clientWidth - pad) / r.width, (stageEl.clientHeight - pad) / r.height, 1);
			if (!isFinite(k) || k <= 0) k = 1;
			pageEl.style.transform = 'scale(' + k + ')';
			stageEl.style.height = Math.ceil(r.height * k + pad) + 'px';   // collapse scaled empty space
		}
		requestAnimationFrame(apply);
		setTimeout(apply, 60);           // rAF is paused in background tabs — always pair with a timeout
	}

	w.ScrollRender = { renderPage: renderPage, resolveTokens: resolveTokens, autoscaleZones: autoscaleZones, fitToStage: fitToStage, slotSrc: slotSrc };
})(window);
```

- [ ] **Step 2: Sanity-check in the browser (no formal JS test runner exists).** Temporarily include `scroll-render.js` on the stub and run in the DevTools console:

```js
ScrollRender.resolveTokens('for {AwardName}', {AwardName:'Order of the Rose'});  // -> "for Order of the Rose"
var p=document.createElement('div'); p.className='sc-page'; document.querySelector('.sf-rebuild-note').appendChild(p);
ScrollRender.renderPage(p, {orientation:'portrait',bg_type:'color',bg_value:'#fff',
  slots:[], zones:[{key:'r',label:'R',text:'{PlayerName}',font:'Cinzel',size:48,align:'center',x:10,y:40,w:80,h:20,autoscale:true}]},
  {tokens:{PlayerName:'Auromax Silverhawke'}, packBase:'/x/', libBase:'/y/'});
ScrollRender.autoscaleZones(p);  // zone text shows the name, scaled to fit
```
Expected: the name renders centered and fits; console line returns the resolved string. Remove the temporary include after.

- [ ] **Step 3: Commit.**

```bash
git add orkui/template/revised-frontend/scroll/scroll-render.js
git commit -m "Scroll rebuild: shared page renderer (slots/zones/tokens/fit)"
```

---

## Phase 4 — Filler

### Task 9: rework `controller.Scroll.php::builder()` — templates + token map

**Files:**
- Modify: `orkui/controller/controller.Scroll.php` (`builder()`; keep award/player/heraldry loading, drop family data)

**Interfaces:**
- Produces `$this->data` for `Scroll_builder.tpl`: `templates` (array from `listForKingdom($player.kingdom_id)`), `token_map` (assoc of the tokens below), `heraldry` (`{kingdom,park,player}` URLs), `pack_base`, `lib_base`, `session_user_id`, `player_kingdom_id`.

- [ ] **Step 1: Normalize the file if tab-indented, then edit.** `awk '/^\t/{c++} END{print c+0}' orkui/controller/controller.Scroll.php` (0 = clean → Edit; else run php-cs-fixer on it first).

- [ ] **Step 2: Build the token map + template list inside `builder()`** (replace the family-data assembly; keep the existing award/player/heraldry fetches):

```php
// after award/player/heraldry are loaded:
$kingdomId = (int)($player['kingdom_id'] ?? 0);
$templates = Ork3::$Lib->scrolltemplate->listForKingdom($kingdomId);
$this->data['templates'] = $templates['Templates'] ?? [];
$this->data['player_kingdom_id'] = $kingdomId;
$this->data['token_map'] = [
	'PlayerName' => $player['Persona']    ?? '',
	'AwardName'  => $award['AwardName']    ?? '',
	'Kingdom'    => $kingdom_name          ?? '',
	'Park'       => $park_name             ?? '',
	'Date'       => date('F j, Y'),                       // grant date; swap to award date if available
	'GivenBy'    => $award['GivenByPersona'] ?? '',
	'Reason'     => $award['Reason']       ?? '',
];
$this->data['heraldry'] = [
	'kingdom' => $kingdom_heraldry_url ?? '',            // reuse the existing resolved vars
	'park'    => $park_heraldry_url    ?? '',
	'player'  => $player_heraldry_url  ?? '',
];
$this->data['pack_base'] = HTTP_ASSETS . 'scroll/packs/';   // confirm the packs URL base (see Task 16 asset placement)
$this->data['lib_base']  = UIR . 'ScrollArtworkAjax/raw&id=';   // existing artwork-image endpoint; confirm the real one
```

- [ ] **Step 3: Verify** the route still returns 200 and the data is present:

```bash
curl -s -o /dev/null -w '%{http_code}\n' 'http://localhost:19080/orkui/index.php?Route=Scroll/builder/2/671'
```
Expected: `200`. (Full render verified in Task 10.)

- [ ] **Step 4: Commit.**

```bash
git add orkui/controller/controller.Scroll.php
git commit -m "Scroll rebuild: builder() provides templates + token map + heraldry"
```

---

### Task 10: `Scroll_builder.tpl` — filler page

**Files:**
- Modify: `orkui/template/revised-frontend/Scroll_builder.tpl` (replace stub with the filler)

**Interfaces:**
- Consumes `$templates`, `$token_map`, `$heraldry`, `$pack_base`, `$lib_base`. Produces DOM: a template picker, an `.sc-stage > .sc-page`, an editable zone list, a "Download PDF" button, and a bootstrap `<script>` exposing `window.SC_BUILDER`.

- [ ] **Step 1: Write the template** (plain PHP; `<?= ?>`; reset global h1 pill):

```php
<?php /* Scroll_builder.tpl — filler. Plain PHP template. */ ?>
<link rel="stylesheet" href="<?= HTTP_TEMPLATE ?>revised-frontend/style/scroll.css?v=<?= filemtime(DIR_TEMPLATE.'revised-frontend/style/scroll.css') ?>">
<div class="sc-filler">
	<header class="sc-panel" style="padding:.75rem 1rem;margin-bottom:1rem;">
		<h1 style="background:transparent;border:none;padding:0;border-radius:0;text-shadow:none;font:600 20px/1.2 system-ui;">Scroll Generator</h1>
		<label class="sc-inspector">Template
			<select id="scTemplatePicker">
				<?php foreach (($templates ?? []) as $t): ?>
					<option value="<?= (int)$t['scroll_template_id'] ?>"><?= htmlspecialchars($t['name']) ?><?= $t['is_starter'] ? ' (starter)' : '' ?></option>
				<?php endforeach; ?>
			</select>
		</label>
		<button id="scDownloadPdf" type="button" class="sc-btn">Download PDF</button>
	</header>
	<div class="sc-stage" id="scStage"><div class="sc-page" id="scPage"></div></div>
	<aside class="sc-panel sc-inspector" id="scZoneEditor" style="padding:1rem;margin-top:1rem;"></aside>
</div>
<script>
window.SC_BUILDER = {
	templates: <?= json_encode($templates ?? []) ?>,
	tokens:    <?= json_encode($token_map ?? []) ?>,
	heraldry:  <?= json_encode($heraldry ?? []) ?>,
	packBase:  <?= json_encode($pack_base ?? '') ?>,
	libBase:   <?= json_encode($lib_base ?? '') ?>
};
</script>
<script src="<?= HTTP_TEMPLATE ?>revised-frontend/scroll/scroll-render.js?v=<?= filemtime(DIR_TEMPLATE.'revised-frontend/scroll/scroll-render.js') ?>"></script>
<script src="<?= HTTP_TEMPLATE ?>revised-frontend/scroll/scroll-builder.js?v=<?= filemtime(DIR_TEMPLATE.'revised-frontend/scroll/scroll-builder.js') ?>"></script>
```
Note: guard the two `filemtime()` on `scroll-builder.js` — it is created in Task 11; until then, hardcode `?v=1` to avoid a warning, then switch to `filemtime` after Task 11.

- [ ] **Step 2: Verify render.** Load `Scroll/builder/2/671` (light + dark). Expected: header + template picker populated from starters, empty page frame (renderer wired in Task 11), no PHP warnings, no console errors. Reset-pill check: the h1 shows no gray box.

- [ ] **Step 3: Commit.**

```bash
git add orkui/template/revised-frontend/Scroll_builder.tpl
git commit -m "Scroll rebuild: filler page (template picker + stage + zone editor shell)"
```

---

### Task 11: `scroll-builder.js` — load template, live tokens, edit zones

**Files:**
- Create: `orkui/template/revised-frontend/scroll/scroll-builder.js`

**Interfaces:**
- Consumes `window.SC_BUILDER`, `window.ScrollRender`. On load: render the first template; on picker change: re-render; builds a zone editor (textarea per zone) that live-updates the page; re-fits on resize.

- [ ] **Step 1: Write it** (complete):

```js
/* scroll-builder.js — filler: pick a template, edit zone text, live-render, fit. */
(function () {
	var B = window.SC_BUILDER || {}, R = window.ScrollRender;
	var page = document.getElementById('scPage'), stage = document.getElementById('scStage');
	var picker = document.getElementById('scTemplatePicker'), editor = document.getElementById('scZoneEditor');
	var current = null;                              // working copy of the selected template (zones editable)
	function byId(id) { return (B.templates || []).find(function (t) { return t.scroll_template_id == id; }); }
	function ctx() { return { tokens: B.tokens || {}, heraldry: B.heraldry || {}, packBase: B.packBase, libBase: B.libBase, editable: true }; }

	function render() {
		R.renderPage(page, current, ctx());
		R.autoscaleZones(page);
		R.fitToStage(page, stage);
	}
	function buildEditor() {
		editor.innerHTML = '';
		(current.zones || []).forEach(function (z, i) {
			var wrap = document.createElement('label'); wrap.textContent = z.label || z.key;
			var ta = document.createElement('textarea'); ta.value = z.text || ''; ta.rows = 2; ta.style.width = '100%';
			ta.addEventListener('input', function () { current.zones[i].text = ta.value; render(); });
			wrap.appendChild(ta); editor.appendChild(wrap);
		});
	}
	function select(id) {
		var t = byId(id); if (!t) return;
		current = JSON.parse(JSON.stringify(t));       // deep copy so edits don't mutate the source list
		buildEditor(); render();
	}
	if (picker) picker.addEventListener('change', function () { select(picker.value); });
	window.addEventListener('resize', function () { if (current) R.fitToStage(page, stage); });
	if ((B.templates || []).length) select(B.templates[0].scroll_template_id);
	window.SC_getCurrent = function () { return current; };   // used by PDF export (Task 12)
})();
```

- [ ] **Step 2: Switch the `.tpl` cache-bust** for `scroll-builder.js` from `?v=1` to `filemtime(...)`. Load `Scroll/builder/2/671`. Expected: first starter renders with `{PlayerName}`/`{AwardName}` filled from the award grant; editing a zone textarea live-updates the page; switching templates re-renders; unresolved tokens show the dashed outline.

- [ ] **Step 3: Commit.**

```bash
git add orkui/template/revised-frontend/scroll/scroll-builder.js orkui/template/revised-frontend/Scroll_builder.tpl
git commit -m "Scroll rebuild: filler logic (template select, live token edit, fit)"
```

---

### Task 12: Direct PDF download (vendor jsPDF + html2canvas)

**Files:**
- Create: `vendor/jspdf.umd.min.js`, `vendor/html2canvas.min.js` (force-added — `vendor/` is gitignored)
- Modify: `orkui/template/revised-frontend/scroll/scroll-builder.js` (export fn), `Scroll_builder.tpl` (script includes)

**Interfaces:**
- Produces: clicking `#scDownloadPdf` renders `#scPage` to a high-DPI canvas and saves a Letter PDF (portrait/landscape per template) named `Scroll - <PlayerName> - <AwardName>.pdf`.

- [ ] **Step 1: Vendor the libs.** Download pinned UMD builds to `vendor/` (self-hosted, no CDN at runtime):

```bash
mkdir -p vendor
curl -sL https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js -o vendor/jspdf.umd.min.js
curl -sL https://cdnjs.cloudflare.com/ajax/libs/html2canvas/1.4.1/html2canvas.min.js -o vendor/html2canvas.min.js
head -c 40 vendor/jspdf.umd.min.js; echo; head -c 40 vendor/html2canvas.min.js; echo
```
Expected: JS (not HTML). Confirm the app serves `vendor/` (check how the xlsx export vendored SimpleXlsx is referenced; place/serve consistently — if `vendor/` isn't web-served, put these under `orkui/template/revised-frontend/vendor/` instead and adjust paths).

- [ ] **Step 2: Add the includes to `Scroll_builder.tpl`** before `scroll-builder.js`:

```php
<script src="<?= HTTP_ROOT ?>vendor/html2canvas.min.js"></script>
<script src="<?= HTTP_ROOT ?>vendor/jspdf.umd.min.js"></script>
```
(Use whatever base constant maps to the vendored path confirmed in Step 1.)

- [ ] **Step 3: Add the export function to `scroll-builder.js`:**

```js
document.getElementById('scDownloadPdf').addEventListener('click', function () {
	var t0 = page.style.transform; page.style.transform = 'scale(1)';        // export at natural size
	// re-render non-editable so token chips don't print
	R.renderPage(page, current, { tokens: B.tokens, heraldry: B.heraldry, packBase: B.packBase, libBase: B.libBase, editable: false });
	R.autoscaleZones(page);
	html2canvas(page, { scale: 3, useCORS: true, backgroundColor: null }).then(function (canvas) {
		var land = (current.orientation === 'landscape');
		var pdf = new jspdf.jsPDF({ orientation: land ? 'landscape' : 'portrait', unit: 'in', format: 'letter' });
		var w = land ? 11 : 8.5, h = land ? 8.5 : 11;
		pdf.addImage(canvas.toDataURL('image/jpeg', 0.95), 'JPEG', 0, 0, w, h);
		var name = (B.tokens.PlayerName || 'Scroll') + ' - ' + (B.tokens.AwardName || 'Award');
		pdf.save('Scroll - ' + name + '.pdf');
		page.style.transform = t0;                                            // restore preview
		R.renderPage(page, current, ctx()); R.autoscaleZones(page); R.fitToStage(page, stage);
	});
});
```

- [ ] **Step 4: Verify.** Load `Scroll/builder/2/671`, click Download PDF. Expected: a Letter PDF downloads; open it — the scroll fills the page, correct orientation, text + graphics present, no dashed token outlines, no clipping. Test a landscape template too.

- [ ] **Step 5: Commit** (force-add vendored libs):

```bash
git add -f vendor/jspdf.umd.min.js vendor/html2canvas.min.js
git add orkui/template/revised-frontend/scroll/scroll-builder.js orkui/template/revised-frontend/Scroll_builder.tpl
git commit -m "Scroll rebuild: client-side direct PDF download (jsPDF + html2canvas)"
```

---

## Phase 5 — Designer

### Task 13: `controller.Scroll.php::design()` action + route

**Files:**
- Modify: `orkui/controller/controller.Scroll.php` (add `design()`), plus router entry if needed

**Interfaces:**
- Produces the designer page data: `$this->data` with `kingdom_id`, `template` (existing template to edit, or null for new), `pack_catalog` (from `catalog.json`), `library` (kingdom-visible artwork list), `heraldry`, `pack_base`, `lib_base`, `csrf`/session token. Route `Scroll/design/{kingdomId}` and `Scroll/design/{kingdomId}/{templateId}`. Gated: `HasAuthority($mid, AUTH_KINGDOM, $kingdomId, AUTH_EDIT)`; on failure render a "not authorized" view.

- [ ] **Step 1: Add the action** (mirror `builder()` param parsing):

```php
public function design($id = null) {
	$this->template = '../revised-frontend/Scroll_design.tpl';
	$parts = explode('/', $id ?? '');
	$kingdomId  = isset($parts[0]) ? (int)$parts[0] : 0;
	$templateId = isset($parts[1]) ? (int)$parts[1] : 0;
	$mid = (int)Ork3::$Lib->authorization->IsAuthorized($this->session->token);
	$this->data['authorized'] = ($mid > 0 && Ork3::$Lib->authorization->HasAuthority($mid, AUTH_KINGDOM, $kingdomId, AUTH_EDIT));
	$this->data['kingdom_id'] = $kingdomId;
	$this->data['template'] = $templateId ? (Ork3::$Lib->scrolltemplate->get($templateId)['Template'] ?? null) : null;
	$this->data['templates'] = Ork3::$Lib->scrolltemplate->listForKingdom($kingdomId)['Templates'] ?? [];
	$this->data['pack_catalog'] = json_decode(@file_get_contents(DIR_ASSETS . 'scroll/packs/catalog.json'), true) ?: [];
	$this->data['heraldry'] = [ 'kingdom' => '', 'park' => '', 'player' => '' ];     // placeholders shown in designer
	$this->data['pack_base'] = HTTP_ASSETS . 'scroll/packs/';
	$this->data['session_token'] = $this->session->token ?? '';
}
```
(Confirm `DIR_ASSETS`/`HTTP_ASSETS` constants and the on-disk packs path from Task 16.)

- [ ] **Step 2: Verify routing + auth.**

```bash
curl -s -o /dev/null -w '%{http_code}\n' 'http://localhost:19080/orkui/index.php?Route=Scroll/design/1'
```
Expected: `200`. In-browser as a non-officer → "not authorized" copy; as a kingdom officer → the designer (built in Task 14).

- [ ] **Step 3: Commit.**

```bash
git add orkui/controller/controller.Scroll.php
git commit -m "Scroll rebuild: designer action + kingdom-officer auth gate"
```

---

### Task 14: `Scroll_design.tpl` — designer page

**Files:**
- Create: `orkui/template/revised-frontend/Scroll_design.tpl`

**Interfaces:**
- Consumes `$authorized`, `$kingdom_id`, `$template`, `$templates`, `$pack_catalog`, `$heraldry`, `$pack_base`, `$session_token`. Produces: the `.sc-stage > .sc-page.sc-editing`, an inspector panel (page: name/orientation/background; selected slot: source picker from pack catalog / library / heraldry; selected zone: font/size/align/color/token-insert buttons), an "Add slot"/"Add zone" toolbar, and Save/Save-as-starter buttons. Bootstraps `window.SC_DESIGN`.

- [ ] **Step 1: Write the template** (plain PHP; key structure — the interactive wiring is Task 15):

```php
<?php /* Scroll_design.tpl — layout maker. Plain PHP. */ ?>
<link rel="stylesheet" href="<?= HTTP_TEMPLATE ?>revised-frontend/style/scroll.css?v=<?= filemtime(DIR_TEMPLATE.'revised-frontend/style/scroll.css') ?>">
<?php if (empty($authorized)): ?>
	<div class="sc-panel" style="max-width:520px;margin:4rem auto;padding:2rem;text-align:center;">
		<h1 style="background:transparent;border:none;padding:0;text-shadow:none;">Not authorized</h1>
		<p>You must be a kingdom officer to design scroll templates for this kingdom.</p>
	</div>
<?php else: ?>
	<div class="sc-designer" style="display:grid;grid-template-columns:1fr 340px;gap:1rem;align-items:start;">
		<div class="sc-stage" id="scStage"><div class="sc-page sc-editing" id="scPage"></div></div>
		<aside class="sc-panel sc-inspector" id="scInspector" style="padding:1rem;position:sticky;top:14px;">
			<div class="sc-toolbar">
				<button type="button" id="scAddZone" class="sc-btn">+ Text zone</button>
				<button type="button" id="scAddSlot" class="sc-btn">+ Graphic slot</button>
			</div>
			<div id="scPageProps"></div>     <!-- name / orientation / background -->
			<div id="scSelProps"></div>       <!-- selected slot or zone props -->
			<div class="sc-actions" style="margin-top:1rem;">
				<input id="scTplName" placeholder="Template name" value="<?= htmlspecialchars($template['name'] ?? '') ?>">
				<button type="button" id="scSave" class="sc-btn sc-btn-primary">Save</button>
			</div>
		</aside>
	</div>
	<script>
	window.SC_DESIGN = {
		kingdomId: <?= (int)$kingdom_id ?>,
		template:  <?= json_encode($template ?: null) ?>,
		packCatalog: <?= json_encode($pack_catalog ?? []) ?>,
		heraldry:  <?= json_encode($heraldry ?? []) ?>,
		packBase:  <?= json_encode($pack_base ?? '') ?>,
		token:     <?= json_encode($session_token ?? '') ?>,
		saveUrl:   <?= json_encode(UIR.'ScrollTemplateAjax/save') ?>
	};
	</script>
	<script src="<?= HTTP_TEMPLATE ?>revised-frontend/scroll/scroll-render.js?v=<?= filemtime(DIR_TEMPLATE.'revised-frontend/scroll/scroll-render.js') ?>"></script>
	<script src="<?= HTTP_TEMPLATE ?>revised-frontend/scroll/scroll-design.js?v=1"></script>
<?php endif; ?>
```

- [ ] **Step 2: Verify** the designer shell renders for an officer (empty page + inspector), and the "not authorized" branch renders otherwise. Dark + light.

- [ ] **Step 3: Commit.**

```bash
git add orkui/template/revised-frontend/Scroll_design.tpl
git commit -m "Scroll rebuild: designer page shell + inspector layout"
```

---

### Task 15: `scroll-design.js` — placement, inspector, save

**Files:**
- Create: `orkui/template/revised-frontend/scroll/scroll-design.js`
- Modify: `Scroll_design.tpl` (cache-bust → filemtime)

**Interfaces:**
- Consumes `window.SC_DESIGN`, `window.ScrollRender`. Maintains a working `template` object; renders it editable; drag-moves slots/zones (writing back **percent** x/y); inspector edits page props, selected slot source (from `packCatalog`/library/heraldry), and zone font/size/align/color + token-insert; POSTs to `saveUrl` (JSON body, session token included) and reflects the returned `TemplateId`.

- [ ] **Step 1: Write it** (complete core — model, render, drag→%, inspector, save):

```js
/* scroll-design.js — layout maker. */
(function () {
	var D = window.SC_DESIGN || {}, R = window.ScrollRender;
	var page = document.getElementById('scPage'), stage = document.getElementById('scStage');
	var tpl = D.template || { name:'', orientation:'portrait', bg_type:'color', bg_value:'#ffffff', slots:[], zones:[], kingdom_id: D.kingdomId };
	var sel = null;                                  // {kind:'slot'|'zone', index}

	function render() {
		R.renderPage(page, tpl, { tokens:{}, heraldry:D.heraldry, packBase:D.packBase, libBase:'', editable:true });
		R.autoscaleZones(page); R.fitToStage(page, stage);
		wireDrag(); markSelected();
	}
	function pageRect() { return page.getBoundingClientRect(); }
	function wireDrag() {
		page.querySelectorAll('.sc-slot, .sc-zone').forEach(function (el) {
			var kind = el.classList.contains('sc-slot') ? 'slot' : 'zone';
			var idx = (kind === 'slot' ? tpl.slots : tpl.zones).indexOf(el.__slot || el.__zone);
			el.addEventListener('mousedown', function (e) {
				if (e.target !== el && kind === 'zone') return;   // let inner text select
				e.preventDefault(); sel = { kind:kind, index:idx }; markSelected(); buildInspector();
				var pr = pageRect(), sx = e.clientX, sy = e.clientY;
				var obj = (kind==='slot'?tpl.slots:tpl.zones)[idx], ox = obj.x, oy = obj.y;
				function mv(ev) {
					obj.x = Math.max(0, Math.min(100, ox + (ev.clientX - sx) / pr.width  * 100));
					obj.y = Math.max(0, Math.min(100, oy + (ev.clientY - sy) / pr.height * 100));
					el.style.left = obj.x + '%'; el.style.top = obj.y + '%';
				}
				function up() { document.removeEventListener('mousemove', mv); document.removeEventListener('mouseup', up); }
				document.addEventListener('mousemove', mv); document.addEventListener('mouseup', up);
			});
		});
	}
	function markSelected() {
		page.querySelectorAll('.sc-slot,.sc-zone').forEach(function (el) { el.style.outlineWidth = ''; });
		if (!sel) return;
		var list = sel.kind==='slot' ? page.querySelectorAll('.sc-slot') : page.querySelectorAll('.sc-zone');
		if (list[sel.index]) list[sel.index].style.outline = '2px solid #2a6cff';
	}
	function buildInspector() {
		var box = document.getElementById('scSelProps'); box.innerHTML = '';
		if (!sel) return;
		if (sel.kind === 'zone') {
			var z = tpl.zones[sel.index];
			box.appendChild(field('Font', z.font, function (v){ z.font=v; render(); }));
			box.appendChild(numField('Size', z.size, function (v){ z.size=+v; render(); }));
			box.appendChild(selectField('Align', ['left','center','right'], z.align, function (v){ z.align=v; render(); }));
			box.appendChild(colorField('Color', z.color||'#000000', function (v){ z.color=v; z.inherit_color=false; render(); }));
			['PlayerName','AwardName','Kingdom','Park','Date','GivenBy','Reason'].forEach(function (tk) {
				var b=document.createElement('button'); b.type='button'; b.className='sc-chip'; b.textContent='{'+tk+'}';
				b.onclick=function(){ z.text=(z.text||'')+'{'+tk+'}'; render(); }; box.appendChild(b);
			});
		} else {
			var s = tpl.slots[sel.index];
			box.appendChild(selectField('Source', ['pack','library','heraldry','none'], s.source_type, function (v){ s.source_type=v; render(); }));
			box.appendChild(packPicker(s));   // grid of D.packCatalog thumbnails filtered by slot; sets s.source_ref
		}
	}
	// page props (name/orientation/background)
	function buildPageProps() {
		var box = document.getElementById('scPageProps'); box.innerHTML='';
		box.appendChild(selectField('Orientation', ['portrait','landscape'], tpl.orientation, function (v){ tpl.orientation=v; render(); }));
		box.appendChild(selectField('Background', ['color','texture','image'], tpl.bg_type, function (v){ tpl.bg_type=v; render(); }));
		box.appendChild(field('Background value', tpl.bg_value, function (v){ tpl.bg_value=v; render(); }));
	}
	// small field helpers
	function field(label,val,on){ var l=document.createElement('label'); l.textContent=label; var i=document.createElement('input'); i.value=val||''; i.oninput=function(){on(i.value);}; l.appendChild(i); return l; }
	function numField(label,val,on){ var l=field(label,val,on); l.querySelector('input').type='number'; return l; }
	function colorField(label,val,on){ var l=field(label,val,on); l.querySelector('input').type='color'; return l; }
	function selectField(label,opts,val,on){ var l=document.createElement('label'); l.textContent=label; var s=document.createElement('select'); opts.forEach(function(o){var op=document.createElement('option');op.value=o;op.textContent=o;if(o===val)op.selected=true;s.appendChild(op);}); s.onchange=function(){on(s.value);}; l.appendChild(s); return l; }
	function packPicker(slot){ var d=document.createElement('div'); d.className='sc-pack-grid';
		(D.packCatalog||[]).forEach(function(a){ var img=document.createElement('img'); img.src=D.packBase+a.file; img.title=a.name; img.className='sc-pack-thumb';
			img.onclick=function(){ slot.source_type='pack'; slot.source_ref=a.file; render(); }; d.appendChild(img); }); return d; }

	document.getElementById('scAddZone').onclick=function(){ tpl.zones.push({key:'zone'+tpl.zones.length,label:'Text',text:'{PlayerName}',font:'EB Garamond',size:32,min:10,max:48,align:'center',color:'#000000',inherit_color:false,x:20,y:40,w:60,h:12,autoscale:true}); render(); };
	document.getElementById('scAddSlot').onclick=function(){ tpl.slots.push({location:'center_image',x:35,y:55,w:30,h:30,source_type:'pack',source_ref:'',fit:'contain'}); render(); };
	document.getElementById('scSave').onclick=function(){
		tpl.name=document.getElementById('scTplName').value||tpl.name;
		fetch(D.saveUrl, { method:'POST', headers:{'Content-Type':'application/json'},
			body: JSON.stringify(Object.assign({ id: tpl.scroll_template_id||0, kingdom_id: D.kingdomId, token: D.token }, tpl)) })
			.then(function(r){return r.json();}).then(function(j){
				if (j.Status===0) { tpl.scroll_template_id=j.TemplateId; alert('Saved.'); }   // replace alert with tnConfirm/toast per convention
				else alert(j.Message||'Save failed.');
			});
	};
	buildPageProps(); render();
})();
```
Note: replace `alert()` with the project toast/`tnConfirm` per the no-native-dialogs rule before final. The save POST relies on the endpoint reading the session cookie for auth (the token is also included in the body for the lib).

- [ ] **Step 2: Cache-bust → filemtime** in `Scroll_design.tpl`. Verify end-to-end as a kingdom officer: add a zone (drag it — position persists as %), add a slot and pick a pack graphic, set font/size/align/color, insert a token, Save → returns `TemplateId`; reload the designer with that id → the saved layout restores. Confirm the saved template now appears in the filler's picker.

- [ ] **Step 3: Commit.**

```bash
git add orkui/template/revised-frontend/scroll/scroll-design.js orkui/template/revised-frontend/Scroll_design.tpl
git commit -m "Scroll rebuild: designer logic (drag placement, inspector, save)"
```

---

### Task 16: seed starter templates + built-in pack rows

**Files:**
- Create: `system/scripts/seed-scroll-templates.php`

**Interfaces:**
- Produces: 3 starter templates (`is_starter=1`, `kingdom_id` NULL) reproducing the reference looks — (a) illuminated full-border portrait, (b) rose-trellis parchment portrait, (c) landscape corner-shields + bottom illustration — and `system_owned=1` `ork_scroll_artwork` rows for every entry in `system/assets/scroll/packs/catalog.json` (so packs are browsable in the library). Idempotent (delete-then-insert starters by name; skip pack rows whose `file_name` already exists).

- [ ] **Step 1: Confirm the packs are in place.** The ingestion produced `system/assets/scroll/packs/{borders,backgrounds,orders,...}/` + `catalog.json` + `ATTRIBUTION.md`. Verify:

```bash
ls system/assets/scroll/packs/ && head -c 400 system/assets/scroll/packs/catalog.json
```
Expected: category dirs + a JSON array of `{file,name,category,slot,award_type,tags,...}`.

- [ ] **Step 2: Write the seeder** (bootstrap `Ork3::$Lib` like the other seed scripts; insert pack rows + starters):

```php
<?php
// seed-scroll-templates.php — starter templates + built-in pack artwork rows.
require_once __DIR__ . '/../..'; // bootstrap Ork3::$Lib exactly as system/scripts/seed-* do (copy the include block)
$packDir = DIR_ASSETS . 'scroll/packs/';
$catalog = json_decode(file_get_contents($packDir . 'catalog.json'), true) ?: [];
$sa = Ork3::$Lib->scrollartwork; $st = Ork3::$Lib->scrolltemplate; $db = /* the shared $DB handle these scripts use */;

// 1) built-in pack rows (system_owned=1); map catalog slot -> layout_location
$slotToLoc = ['full_border'=>'full_border','border_side'=>'border_left','bg_image'=>'watermark','center_image'=>'center_image','shield'=>'top_graphic'];
foreach ($catalog as $a) {
	$loc = $slotToLoc[$a['slot']] ?? 'center_image';
	$db->Clear();
	$db->file_name = $a['file'];
	$exists = $db->DataSet("SELECT scroll_artwork_id FROM ".DB_PREFIX."scroll_artwork WHERE file_name=:file_name AND system_owned=1");
	if ($exists->Size() > 0) continue;
	$db->Clear();
	$db->uploader_mundane_id=0; $db->name=$a['name']; $db->description=''; $db->tags=implode(',', $a['tags'] ?? []);
	$db->layout_location=$loc; $db->file_name=$a['file']; $db->original_file_name=basename($a['file']);
	$db->width=(int)($a['width']??0); $db->height=(int)($a['height']??0); $db->file_size=0;
	$db->license_signer_name='Alona of Two Trees'; $db->license_signed_at=date('Y-m-d H:i:s');
	$db->status='approved'; $db->system_owned=1; $db->source_attribution='Alona of Two Trees'; $db->source_license=$a['license'] ?? 'CC';
	$cols=['uploader_mundane_id','name','description','tags','layout_location','file_name','original_file_name','width','height','file_size','license_signer_name','license_signed_at','status','system_owned','source_attribution','source_license'];
	$ph=array_map(fn($c)=>':'.$c,$cols);
	$db->Execute("INSERT INTO ".DB_PREFIX."scroll_artwork (".implode(',',$cols).") VALUES (".implode(',',$ph).")");
}

// 2) starter templates (delete existing starters by name, re-insert)
function slot($loc,$x,$y,$w,$h,$type,$ref){ return ['location'=>$loc,'x'=>$x,'y'=>$y,'w'=>$w,'h'=>$h,'source_type'=>$type,'source_ref'=>$ref,'fit'=>'contain']; }
function zone($k,$l,$t,$f,$s,$mn,$mx,$al,$x,$y,$w,$h){ return ['key'=>$k,'label'=>$l,'text'=>$t,'font'=>$f,'size'=>$s,'min'=>$mn,'max'=>$mx,'align'=>$al,'color'=>'#1a1a1a','inherit_color'=>false,'x'=>$x,'y'=>$y,'w'=>$w,'h'=>$h,'autoscale'=>true]; }

$starters = [
	['Illuminated Border (Portrait)','portrait','color','#fdfcf7',
		[slot('full_border',2,2,96,96,'pack','borders/scroll_border.png')],
		[ zone('salutation','Salutation','Amtgard and {Kingdom} present','EB Garamond',22,14,26,'center',14,12,72,8),
		  zone('recipient','Recipient','{PlayerName}','Cinzel',54,28,60,'center',10,22,80,12),
		  zone('award','Award','{AwardName}','Cinzel Decorative',40,22,48,'center',12,38,76,10),
		  zone('body','Body','for {Reason}','EB Garamond',24,12,28,'center',16,52,68,18),
		  zone('date','Date','Done this {Date}','EB Garamond',18,12,22,'center',16,74,68,8),
		  zone('signature','Signature','{GivenBy}','Great Vibes',30,16,36,'center',20,84,60,8) ]],
	['Rose Trellis (Portrait)','portrait','texture','Brown_Tea_Stained.png',
		[slot('full_border',1,1,98,98,'pack','borders/rose_border.png')],
		[ zone('recipient','Recipient','{PlayerName}','Almendra',52,28,58,'center',12,24,76,12),
		  zone('award','Award','{AwardName}','MedievalSharp',40,22,46,'center',14,40,72,10),
		  zone('body','Body','for {Reason}','EB Garamond',22,12,26,'center',18,54,64,16),
		  zone('date','Date','the {Date}','EB Garamond',18,12,22,'left',14,80,40,10) ]],
	['Corner Shields (Landscape)','landscape','color','#ffffff',
		[ slot('top_graphic',3,4,16,22,'heraldry','kingdom'), slot('top_graphic',81,4,16,22,'heraldry','park'),
		  slot('center_image',35,55,30,40,'pack','orders/dragon/gold_dragon.png') ],
		[ zone('body','Body','In recognition of your service, you, {PlayerName}, shall forever be known as','EB Garamond',22,12,26,'center',20,10,60,14),
		  zone('award','Award','{AwardName}','Cinzel',34,20,40,'center',25,26,50,10),
		  zone('date','Date','Done this {Date}','EB Garamond',18,12,22,'center',25,40,50,8) ]],
];
foreach ($starters as $s) {
	$db->Clear(); $db->name=$s[0];
	$db->Execute("DELETE FROM ".DB_PREFIX."scroll_template WHERE is_starter=1 AND name=:name");
	$st->create(['KingdomId'=>null,'Name'=>$s[0],'Orientation'=>$s[1],'BgType'=>$s[2],'BgValue'=>$s[3],'Slots'=>$s[4],'Zones'=>$s[5],'IsStarter'=>1,'CreatedBy'=>0]);
}
echo "seeded ".count($catalog)." pack rows + ".count($starters)." starters\n";
```
(Confirm the `$DB` handle name the seed scripts use; align `slotToLoc` and `source_ref` pack paths with the real `catalog.json` files — e.g. the actual scroll-border filename.)

- [ ] **Step 3: Run + verify.**

```bash
docker exec -w /var/www/ork.amtgard.com ork3-php8-app php system/scripts/seed-scroll-templates.php
docker exec ork3-php8-db mariadb -uroot -proot ork -e \
  "SELECT COUNT(*) starters FROM ork_scroll_template WHERE is_starter=1; SELECT COUNT(*) packs FROM ork_scroll_artwork WHERE system_owned=1;"
```
Expected: `starters`=3, `packs`=catalog count. Then load `Scroll/builder/2/671` → the 3 starters populate the picker and render with real border/emblem art.

- [ ] **Step 4: Commit** (seeder only; the pack asset files + catalog + ATTRIBUTION are committed with the ingestion, force-added if under a gitignored path):

```bash
git add system/scripts/seed-scroll-templates.php
git add system/assets/scroll/packs   # add the ingested art + catalog.json + ATTRIBUTION.md if not already tracked
git commit -m "Scroll rebuild: seed 3 starter templates + built-in pack artwork rows"
```

---

## Phase 6 — Polish / QA

### Task 17: Dark-mode chrome pass

**Files:** Modify `orkui/template/revised-frontend/style/scroll.css` and any inline styles in the two `.tpl`s.

- [ ] **Step 1:** Walk the filler + designer in dark mode (`html[data-theme="dark"]`). Check against the dark-mode checklist: panel/inspector backgrounds, `<select>`/`<input>`/`<textarea>` contrast, labels, buttons (no muted ghost text), the stage backdrop, pack-thumb grid, the "not authorized" card. The `.sc-page` scroll surface itself must STAY light in dark mode.
- [ ] **Step 2:** Fix each contrast issue with `html[data-theme="dark"]` overrides (never `body.dark-mode`). Re-walk.
- [ ] **Step 3: Commit.** `git commit -m "Scroll rebuild: dark-mode chrome polish"`

### Task 18: Print / PDF fidelity, both orientations

- [ ] **Step 1:** Add `@media print` + `@page { size: letter; margin:0; }` to `scroll.css`; hide editor chrome and `.sc-token-unfilled` outlines in print; ensure `.sc-page` prints at `8.5in×11in` (portrait) / `11in×8.5in` (landscape) with the fit transform cleared.
- [ ] **Step 2:** For each of the 3 starters: Download PDF and browser Print→PDF. Open both; verify correct page size/orientation, full-bleed backgrounds reach the edges, borders aren't clipped, text isn't cut, no dashed token outlines. Measure the PDF page is Letter.
- [ ] **Step 3: Commit.** `git commit -m "Scroll rebuild: print + PDF fidelity (portrait + landscape)"`

### Task 19: Test suite refresh + full run

- [ ] **Step 1:** Ensure `tests/scroll/` contains only current tests: `test_token_resolver.php`, `test_scroll_template.php`, `test_template_ajax.sh`, plus surviving artwork-library tests. Delete any leftover family/ornament test still present. Add a `test_starters.php` asserting `listForKingdom(0)` returns 3 starters with non-empty `slots`+`zones`.
- [ ] **Step 2:** Run everything:

```bash
bash tests/scroll/run-all.sh
bash tests/scroll/test_template_ajax.sh
docker exec -w /var/www/ork.amtgard.com/tests/scroll ork3-php8-app php test_starters.php
```
Expected: all `ALL PASS` / expected JSON; no fatals.

- [ ] **Step 3: Final verification pass** (evidence before claiming done): app boots; `Scroll/builder/2/671` renders a real filled scroll; designer saves + reloads a template; PDF downloads correctly in both orientations; dark mode clean; `git grep` finds zero references to deleted engine symbols.
- [ ] **Step 4: Commit.** `git commit -m "Scroll rebuild: test suite refresh + full-run green"`

---

## Self-Review

**1. Spec coverage** — every spec section maps to a task: scrap list → T1; keep artwork library → preserved (not deleted); migrations (keep 3 / rewrite 1 / add template / reconcile) → T2–T3; routes (ajax/builder/design) → T6/T9/T13; shared renderer → T7–T8; backgrounds (color/texture/image) → T7 + starters T16; slots (library/heraldry/pack) → renderer `slotSrc` + designer `packPicker`; text zones + tokens → T4/T8/T10/T11/T15; token map → T9; client PDF → T12; designer/filler surfaces + auth → T9–T16; starters (3) → T16; built-in packs from Alona → T16 + ingestion; dark mode → T17; print both orientations → T18; tests → T19.

**2. Placeholder scan** — no "TODO/TBD/implement later". The "confirm X against the codebase" notes (lib base class + registration, `$DB` handle name, `HTTP_ASSETS`/`DIR_ASSETS`/`HTTP_ROOT` + `vendor/` serving, existing `builder()` heraldry var names, AJAX router registration, `Success()` sentinel) are deliberate verification gates where the pattern-extraction did not pin an exact value — an implementer resolves each by opening the named sibling file. These are honest unknowns, not lazy gaps.

**3. Type consistency** — `resolveTokens` matches across PHP (`ScrollTemplate::resolveTokens`) and JS (`ScrollRender.resolveTokens`); slot shape `{location,x,y,w,h,source_type,source_ref,fit}` and zone shape `{key,label,text,font,size,min,max,align,color,inherit_color,x,y,w,h,autoscale}` are identical in the data-shapes block, renderer, designer, and seeder; `listForKingdom`/`create`/`get`/`update`/`delete` names consistent lib↔model↔controller↔seeder.

**Known thin spots (documented, acceptable for v1):**
- **Library-artwork browse in the designer** — the designer's slot source picker fully implements the *pack* grid; `source_type:'library'`/`'heraldry'` are selectable and the renderer resolves them, but a rich "browse the kingdom artwork library" UI is not built. Packs + heraldry cover the reference looks; wiring the existing `ScrollArtworkAjax` browse into the slot picker is a fast follow-up (note in T15).
- **`vendor/` serving path** — if `vendor/` is not web-served, T12 relocates the two libs under `revised-frontend/vendor/`; resolved during T12 Step 1.
- **Native `alert()` in `scroll-design.js`** — replaced with the project toast/`tnConfirm` before final (flagged in T15).

**Recon prerequisite:** because of the verification gates above, execution should begin with a short recon that resolves them into a facts note the implementation tasks consume, before Phase 2.



