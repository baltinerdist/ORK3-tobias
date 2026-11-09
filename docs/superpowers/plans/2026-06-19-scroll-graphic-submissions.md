# Scroll Graphic Submissions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a pseudo-standalone "Scroll Graphic Submissions" module (browse library / submit with wireframe / my submissions / tiered moderation) by reviving and extending the existing `ScrollArtwork` backend, plus an opt-in in-builder share path.

**Architecture:** Approach A — a new `Controller_ScrollGraphics` page controller renders four templates; the existing `Controller_ScrollArtworkAjax` + `class.ScrollArtwork` are extended (visibility/kingdom/category fields + tiered moderation); `ork_scroll_artwork` gets additive columns and a new `ork_scroll_artwork_category` lookup; the render path in `Controller_ScrollAjax` gains an ephemeral `artwork_<slot>_raw` compositing path.

**Tech Stack:** PHP 8 (no framework — convention-routed `Controller_*` classes), MariaDB via the global `$DB` (Yapo `YapoMysql`, hand-written SQL with `:named` params), plain-PHP `.tpl` templates (`extract()`+`include`, NOT Smarty), vanilla JS `fetch`, GD for 300-DPI compositing. Spec: `docs/superpowers/specs/2026-06-19-scroll-graphic-submissions-design.md`.

---

## Reference: load-bearing idioms (read before starting)

These are extracted verbatim from the codebase. Every task below assumes them.

**Lib DB idiom** (`system/lib/ork3/class.ScrollArtwork.php`, `class ScrollArtwork extends Ork3`; instance at `Ork3::$Lib->scrollartwork`; DB at `$this->db` = global `$DB`):
```php
$this->db->Clear();                 // reset bound params (MUST call before each query)
$this->db->some_name = $val;        // binds :some_name (property name = placeholder, NOT necessarily column)
$this->db->Execute($sql);           // INSERT/UPDATE/DELETE
$r = $this->db->DataSet($sql);      // SELECT -> result set
while ($r->Next()) { $x = $r->col; } // iterate; $r->Size() = row count
$id = $this->db->GetLastInsertId(); // after INSERT
// table is DB_PREFIX . "scroll_artwork"; PK scroll_artwork_id; LIMIT/OFFSET interpolated as (int)
```
Return arrays always carry a `'Status'` key from `Success()` / `NoAuthorization()` / `InvalidParameter(null, 'msg')`.

**Auth idiom:** login → `$mid = Ork3::$Lib->authorization->IsAuthorized($request['Token']); if ($mid <= 0) return ['Status'=>NoAuthorization()];`. Admin → `Ork3::$Lib->authorization->HasAuthority($mid, AUTH_ADMIN, 0, AUTH_EDIT)`. Kingdom officer → `HasAuthority($mid, AUTH_KINGDOM, $kingdom_id, AUTH_EDIT)`. **House rule: after any `HasAuthority` calls, run `$this->db->Clear();` (lib) or `global $DB; $DB->Clear();` (controller) before the next DB query** — the auth ORM shares the connection.

**AJAX controller idiom** (`controller.ScrollArtworkAjax.php`, `class Controller_ScrollArtworkAjax extends Controller`): private `json_response($data)` does `header('Content-Type: application/json'); echo json_encode($data); exit;`. `require_login()` returns `(int)$this->session->user_id` or json-errors with `Status=5`. `require_admin()` additionally checks `HasAuthority(...AUTH_ADMIN...)`. Session token = `$this->session->token`. Responses use **capitalized** `Status` (0=success, 1=error, 5=auth) + `Message`. Params read from `$_POST`/`$_GET`.

**Page controller idiom** (`controller.ScrollGraphics.php`, `class Controller_ScrollGraphics extends Controller`): set `$this->template = '../revised-frontend/ScrollGraphics_index.tpl';`, assign `$this->data['x'] = ...` (becomes `$x` in the tpl). Logged-in id: `$uid = isset($this->session->user_id) ? (int)$this->session->user_id : 0;`. Login-gate the whole controller in the constructor (Reports pattern): `if (!isset($this->session->user_id)) { header('Location: ' . UIR . 'Login'); exit; }`. Routing is convention-based — dropping the file is enough (`UIR` = `index.php?Route=`).

**Template idiom** (`template/revised-frontend/*.tpl`): plain PHP. Use `<?= htmlspecialchars($x) ?>`, `<?php foreach(...): ?>`, `<?= UIR ?>Controller/action`. Inject a JS config via `<?= json_encode($cfg, JSON_HEX_TAG|JSON_HEX_AMP|JSON_HEX_APOS) ?>`. Dark mode selector is `html[data-theme="dark"]`. Cache-bust CSS with `?v=<?= filemtime(...) ?>`.

**Migration idiom:** plain `.sql` files in `db-migrations/`, applied manually via `docker exec -i ork3-php8-db mariadb -uork -psecret ork < FILE`. No tracking table.

---

## Phase 1 — Data model + lib foundation

### Task 1.1: Migration — additive columns on `ork_scroll_artwork`

**Files:**
- Create: `db-migrations/2026-06-19-scroll-submissions-tiers.sql`

- [ ] **Step 1: Write the migration**

```sql
-- 2026-06-19 · Scroll Graphic Submissions · add sharing-tier + category columns
-- to ork_scroll_artwork. Additive + re-runnable-safe (guarded by IF NOT EXISTS where
-- the MariaDB version supports it; this DB is MariaDB 10.x which does).

ALTER TABLE ork_scroll_artwork
  ADD COLUMN visibility ENUM('global','kingdom') NOT NULL DEFAULT 'global' AFTER status,
  ADD COLUMN owner_kingdom_id INT UNSIGNED NULL AFTER visibility,
  ADD COLUMN category_id INT UNSIGNED NULL AFTER owner_kingdom_id,
  ADD INDEX idx_vis_status_loc (visibility, status, layout_location),
  ADD INDEX idx_owner_kingdom_status (owner_kingdom_id, status);

-- Down (commented):
-- ALTER TABLE ork_scroll_artwork
--   DROP INDEX idx_vis_status_loc, DROP INDEX idx_owner_kingdom_status,
--   DROP COLUMN category_id, DROP COLUMN owner_kingdom_id, DROP COLUMN visibility;
```

- [ ] **Step 2: Apply it**

Run: `docker exec -i ork3-php8-db mariadb -uork -psecret ork < db-migrations/2026-06-19-scroll-submissions-tiers.sql`
Expected: no output (success).

- [ ] **Step 3: Verify columns + indexes exist**

Run:
```bash
docker exec ork3-php8-db mariadb -uork -psecret ork -e "SHOW COLUMNS FROM ork_scroll_artwork LIKE 'visibility'; SHOW COLUMNS FROM ork_scroll_artwork LIKE 'owner_kingdom_id'; SHOW COLUMNS FROM ork_scroll_artwork LIKE 'category_id';"
```
Expected: three rows printed (one per column).

- [ ] **Step 4: Commit**

```bash
git add db-migrations/2026-06-19-scroll-submissions-tiers.sql
git commit -m "feat(scroll-graphics): add tier + category columns to ork_scroll_artwork"
```

---

### Task 1.2: Migration — `ork_scroll_artwork_category` lookup table + seed

**Files:**
- Create: `db-migrations/2026-06-19-scroll-artwork-categories.sql`

- [ ] **Step 1: Write the migration**

```sql
-- 2026-06-19 · Scroll Graphic Submissions · admin-managed thematic categories.

CREATE TABLE IF NOT EXISTS `ork_scroll_artwork_category` (
  `category_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `slug` VARCHAR(64) NOT NULL,
  `label` VARCHAR(120) NOT NULL,
  `sort_order` SMALLINT NOT NULL DEFAULT 0,
  `active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `modified` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`category_id`),
  UNIQUE KEY `uniq_slug` (`slug`),
  KEY `idx_active_sort` (`active`, `sort_order`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `ork_scroll_artwork_category` (slug, label, sort_order, active)
SELECT * FROM (
  SELECT 'heraldic' AS slug, 'Heraldic' AS label, 10 AS sort_order, 1 AS active UNION ALL
  SELECT 'celtic_knotwork', 'Celtic & Knotwork', 20, 1 UNION ALL
  SELECT 'floral_botanical', 'Floral & Botanical', 30, 1 UNION ALL
  SELECT 'norse_viking', 'Norse & Viking', 40, 1 UNION ALL
  SELECT 'religious_sacred', 'Religious & Sacred', 50, 1 UNION ALL
  SELECT 'geometric', 'Geometric', 60, 1 UNION ALL
  SELECT 'beasts_creatures', 'Beasts & Creatures', 70, 1 UNION ALL
  SELECT 'flourishes_dividers', 'Flourishes & Dividers', 80, 1 UNION ALL
  SELECT 'other', 'Other', 90, 1
) seed
WHERE NOT EXISTS (SELECT 1 FROM `ork_scroll_artwork_category` LIMIT 1);
```

- [ ] **Step 2: Apply it**

Run: `docker exec -i ork3-php8-db mariadb -uork -psecret ork < db-migrations/2026-06-19-scroll-artwork-categories.sql`
Expected: no error.

- [ ] **Step 3: Verify seed**

Run: `docker exec ork3-php8-db mariadb -uork -psecret ork -e "SELECT slug,label,sort_order,active FROM ork_scroll_artwork_category ORDER BY sort_order;"`
Expected: 9 rows, Heraldic → Other.

- [ ] **Step 4: Commit**

```bash
git add db-migrations/2026-06-19-scroll-artwork-categories.sql
git commit -m "feat(scroll-graphics): add ork_scroll_artwork_category lookup + seed"
```

---

### Task 1.3: Lib — category read + admin CRUD methods

**Files:**
- Modify: `system/lib/ork3/class.ScrollArtwork.php` (add public methods near the other public methods, before the private helpers)
- Test: `tests/scroll/test_categories.php` (new)

- [ ] **Step 1: Write the failing test**

`tests/scroll/test_categories.php` (mirror an existing `tests/scroll/test_*.php` bootstrap header; if the harness needs a DB bootstrap, copy it from `tests/scroll/test_curated_assets.php`):
```php
<?php
require_once __DIR__ . '/lib/assert.php';
// Bootstrap ORK libs (copy the exact require/bootstrap lines used at the top of
// tests/scroll/test_curated_assets.php so $DB and Ork3::$Lib are available).

$sa = Ork3::$Lib->scrollartwork;

// list_categories(true) returns only active, sorted
$res = $sa->list_categories(true);
assert_true(isset($res['Categories']) && is_array($res['Categories']), 'Categories key present');
assert_true(count($res['Categories']) >= 9, 'at least 9 seeded categories');
assert_equals('heraldic', $res['Categories'][0]['Slug'], 'first category is heraldic by sort_order');
assert_true(isset($res['Categories'][0]['CategoryId']), 'category has CategoryId');

echo "test_categories OK\n";
```

- [ ] **Step 2: Run it to verify it fails**

Run: `docker exec ork3-php8-app php /var/www/ork.amtgard.com/tests/scroll/test_categories.php`
Expected: FAIL — `Call to undefined method ScrollArtwork::list_categories()`.

- [ ] **Step 3: Implement `list_categories` + admin CRUD**

Add to `class.ScrollArtwork.php`:
```php
	// ---- Categories (admin-managed thematic taxonomy) ----

	public function list_categories($active_only = true) {
		$this->db->Clear();
		$where = $active_only ? "WHERE active = 1" : "";
		$sql = "SELECT category_id, slug, label, sort_order, active
			FROM " . DB_PREFIX . "scroll_artwork_category
			" . $where . "
			ORDER BY sort_order ASC, label ASC";
		$r = $this->db->DataSet($sql);
		$cats = array();
		while ($r->Next()) {
			$cats[] = array(
				'CategoryId' => intval($r->category_id),
				'Slug'       => $r->slug,
				'Label'      => $r->label,
				'SortOrder'  => intval($r->sort_order),
				'Active'     => intval($r->active),
			);
		}
		return array('Categories' => $cats, 'Status' => Success());
	}

	public function save_category($request) {
		$mundane_id = Ork3::$Lib->authorization->IsAuthorized($request['Token']);
		if ($mundane_id <= 0 || !Ork3::$Lib->authorization->HasAuthority($mundane_id, AUTH_ADMIN, 0, AUTH_EDIT)) {
			return array('Status' => NoAuthorization());
		}
		$this->db->Clear(); // clear stale bindings from HasAuthority

		$label = trim($request['Label'] ?? '');
		if (strlen($label) === 0 || strlen($label) > 120) {
			return array('Status' => InvalidParameter(null, 'Label is required (max 120 chars).'));
		}
		$sort_order = intval($request['SortOrder'] ?? 0);
		$active = !empty($request['Active']) ? 1 : 0;
		$category_id = intval($request['CategoryId'] ?? 0);

		if ($category_id > 0) {
			$this->db->Clear();
			$this->db->label = $label;
			$this->db->sort_order = $sort_order;
			$this->db->active = $active;
			$this->db->category_id = $category_id;
			$sql = "UPDATE " . DB_PREFIX . "scroll_artwork_category
				SET label = :label, sort_order = :sort_order, active = :active
				WHERE category_id = :category_id";
			$this->db->Execute($sql);
			return array('CategoryId' => $category_id, 'Status' => Success());
		}

		// New: derive a slug from the label, ensure uniqueness
		$base_slug = preg_replace('/[^a-z0-9]+/', '_', strtolower($label));
		$base_slug = trim($base_slug, '_');
		if ($base_slug === '') { $base_slug = 'category'; }
		$slug = $base_slug;
		$n = 2;
		while (true) {
			$this->db->Clear();
			$this->db->slug = $slug;
			$chk = $this->db->DataSet("SELECT category_id FROM " . DB_PREFIX . "scroll_artwork_category WHERE slug = :slug");
			if ($chk->Size() <= 0) break;
			$slug = $base_slug . '_' . $n;
			$n++;
		}

		$this->db->Clear();
		$this->db->slug = $slug;
		$this->db->label = $label;
		$this->db->sort_order = $sort_order;
		$this->db->active = $active;
		$sql = "INSERT INTO " . DB_PREFIX . "scroll_artwork_category (slug, label, sort_order, active)
			VALUES (:slug, :label, :sort_order, :active)";
		$this->db->Execute($sql);
		return array('CategoryId' => $this->db->GetLastInsertId(), 'Slug' => $slug, 'Status' => Success());
	}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `docker exec ork3-php8-app php /var/www/ork.amtgard.com/tests/scroll/test_categories.php`
Expected: `test_categories OK`.

- [ ] **Step 5: Commit**

```bash
git add system/lib/ork3/class.ScrollArtwork.php tests/scroll/test_categories.php
git commit -m "feat(scroll-graphics): category read + admin CRUD on ScrollArtwork lib"
```

---

### Task 1.4: Lib — extend `upload()` for visibility/kingdom/category

**Files:**
- Modify: `system/lib/ork3/class.ScrollArtwork.php` — `upload()` (lines ~54-196)

- [ ] **Step 1: Add request parsing + validation after the existing license-signer validation block**

Insert after the `$license_signer` length checks (before image validation):
```php
		// Sharing tier + category (new)
		$visibility = ($request['Visibility'] ?? 'global') === 'kingdom' ? 'kingdom' : 'global';
		$owner_kingdom_id = intval($request['OwnerKingdomId'] ?? 0);
		if ($visibility === 'kingdom' && $owner_kingdom_id <= 0) {
			return array('Status' => InvalidParameter(null, 'Kingdom-specific submissions require a kingdom.'));
		}
		if ($visibility === 'global') {
			// still record the submitter's kingdom for provenance, but never gate on it
			$owner_kingdom_id = $owner_kingdom_id > 0 ? $owner_kingdom_id : 0;
		}
		$category_id = intval($request['CategoryId'] ?? 0);
		if ($category_id > 0) {
			$this->db->Clear();
			$this->db->category_id = $category_id;
			$cchk = $this->db->DataSet("SELECT category_id FROM " . DB_PREFIX . "scroll_artwork_category WHERE category_id = :category_id AND active = 1");
			if ($cchk->Size() <= 0) { $category_id = 0; } // ignore invalid/retired
		}
```

- [ ] **Step 2: Extend the INSERT to write the new columns**

Change the INSERT block (the `$this->db->Clear(); ... Execute($sql);` that inserts the row) to also bind and insert `visibility`, `owner_kingdom_id`, `category_id`. After `$this->db->status = 'pending';` add:
```php
		$this->db->visibility = $visibility;
		$this->db->owner_kingdom_id = $owner_kingdom_id > 0 ? $owner_kingdom_id : null;
		$this->db->category_id = $category_id > 0 ? $category_id : null;
```
And change the column list + VALUES of the INSERT to include `visibility, owner_kingdom_id, category_id` / `:visibility, :owner_kingdom_id, :category_id`. (NOTE: yapo drops `null` from bound params — see house rule. For nullable FKs that's the desired behavior here: a null `owner_kingdom_id`/`category_id` should INSERT as SQL NULL. Confirm the column DEFAULT is NULL — it is, per Task 1.1 — so omitting them when null is safe. To be explicit and avoid the yapo-null-skip pitfall, when the value is null DO NOT include that column in the INSERT column list. Build the column/placeholder lists conditionally.)

Concretely, replace the static INSERT with a dynamic one:
```php
		$cols = array('uploader_mundane_id','name','description','tags','layout_location',
			'file_name','original_file_name','width','height','file_size',
			'license_signer_name','license_signed_at','status','created_at','visibility');
		if ($owner_kingdom_id > 0) { $cols[] = 'owner_kingdom_id'; $this->db->owner_kingdom_id = $owner_kingdom_id; }
		if ($category_id > 0)      { $cols[] = 'category_id';      $this->db->category_id = $category_id; }
		$placeholders = array_map(function($c){ return ':' . $c; }, $cols);
		$sql = "INSERT INTO " . DB_PREFIX . "scroll_artwork (" . implode(', ', $cols) . ")
			VALUES (" . implode(', ', $placeholders) . ")";
		$this->db->Execute($sql);
```
(Keep the earlier `$this->db->visibility = $visibility;` binding; remove the now-redundant null bindings for owner_kingdom_id/category_id.)

- [ ] **Step 3: Add the test** — `tests/scroll/test_submission_tiers.php`

```php
<?php
require_once __DIR__ . '/lib/assert.php';
// Bootstrap (copy from test_curated_assets.php).
$sa = Ork3::$Lib->scrollartwork;

// A 1x1 transparent PNG, base64 (no data: prefix)
$png = base64_encode(base64_decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='));
$token = getenv('TEST_TOKEN'); // a valid session token for a logged-in test user; see tests/scroll/README

$res = $sa->upload(array(
  'Token' => $token, 'Name' => 'Test Kingdom Border', 'LayoutLocation' => 'border_left',
  'LicenseSignerName' => 'Test User', 'Image' => $png, 'ImageMimeType' => 'image/png',
  'Visibility' => 'kingdom', 'OwnerKingdomId' => 1, 'CategoryId' => 1,
));
assert_true(isset($res['ArtworkId']) && $res['ArtworkId'] > 0, 'upload returned ArtworkId');

$got = $sa->get($res['ArtworkId']);
assert_equals('kingdom', $got['Artwork']['Visibility'], 'visibility stored');
assert_equals(1, intval($got['Artwork']['OwnerKingdomId']), 'owner_kingdom_id stored');
echo "test_submission_tiers OK\n";
```
(If obtaining a `TEST_TOKEN` is impractical in the harness, this becomes a curl-based test in Phase 2 instead — see Task 2.1. Keep the lib change; gate the assertion behind `if ($token)`.)

- [ ] **Step 4: Run + verify** (fails before Step 1-2, passes after)

Run: `docker exec ork3-php8-app php /var/www/ork.amtgard.com/tests/scroll/test_submission_tiers.php`
Expected: `test_submission_tiers OK` (or skip-with-notice if no token).

- [ ] **Step 5: Commit**

```bash
git add system/lib/ork3/class.ScrollArtwork.php tests/scroll/test_submission_tiers.php
git commit -m "feat(scroll-graphics): upload() records visibility/kingdom/category"
```

---

### Task 1.5: Lib — visibility-aware `browse()`/`search()` + zone/category filters + `format_artwork_row`

**Files:**
- Modify: `system/lib/ork3/class.ScrollArtwork.php` — `browse()`, `search()`, `format_artwork_row()`

- [ ] **Step 1: Extend `format_artwork_row()`** to expose the new fields. Add to the returned array:
```php
			'Visibility'     => $r->visibility,
			'OwnerKingdomId' => $r->owner_kingdom_id ? intval($r->owner_kingdom_id) : null,
			'CategoryId'     => $r->category_id ? intval($r->category_id) : null,
			'CategoryLabel'  => $r->category_label ?? null,
```

- [ ] **Step 2: Rewrite `browse()` signature + query** to accept a viewer context and filters:
```php
	public function browse($layout_location = '', $page = 1, $per_page = 20, $opts = array()) {
		$page = max(1, (int)$page); $per_page = max(1, min(100, (int)$per_page));
		$offset = ($page - 1) * $per_page;
		$viewer_kingdom_id = intval($opts['ViewerKingdomId'] ?? 0);
		$tier = $opts['Tier'] ?? 'all';        // all | global | kingdom
		$category_id = intval($opts['CategoryId'] ?? 0);

		// Visibility clause: approved global to everyone; approved kingdom only to that kingdom.
		$vis = "sa.status = 'approved' AND (sa.visibility = 'global'";
		if ($viewer_kingdom_id > 0) {
			$vis .= " OR (sa.visibility = 'kingdom' AND sa.owner_kingdom_id = " . (int)$viewer_kingdom_id . ")";
		}
		$vis .= ")";
		if ($tier === 'global') { $vis = "sa.status = 'approved' AND sa.visibility = 'global'"; }
		if ($tier === 'kingdom' && $viewer_kingdom_id > 0) {
			$vis = "sa.status = 'approved' AND sa.visibility = 'kingdom' AND sa.owner_kingdom_id = " . (int)$viewer_kingdom_id;
		}

		$filters = "";
		$this->db->Clear();
		if (strlen($layout_location) > 0 && in_array($layout_location, self::VALID_LOCATIONS)) {
			$filters .= " AND sa.layout_location = :layout_location";
			$this->db->layout_location = $layout_location;
		}
		if ($category_id > 0) {
			$filters .= " AND sa.category_id = :category_id";
			$this->db->category_id = $category_id;
		}

		$base = "FROM " . DB_PREFIX . "scroll_artwork sa
			LEFT JOIN " . DB_PREFIX . "mundane m ON m.mundane_id = sa.uploader_mundane_id
			LEFT JOIN " . DB_PREFIX . "scroll_artwork_category c ON c.category_id = sa.category_id
			WHERE " . $vis . $filters;

		$sql = "SELECT sa.*, m.persona AS uploader_persona, c.label AS category_label
			" . $base . " ORDER BY sa.created_at DESC
			LIMIT " . (int)$per_page . " OFFSET " . (int)$offset;
		$r = $this->db->DataSet($sql);
		$artwork = array();
		while ($r->Next()) { $artwork[] = $this->format_artwork_row($r); }

		$cr = $this->db->DataSet("SELECT COUNT(*) AS total " . $base);
		$total = ($cr->Size() > 0 && $cr->Next()) ? intval($cr->total) : 0;

		return array('Artwork' => $artwork, 'Total' => $total, 'Page' => $page, 'PerPage' => $per_page, 'Status' => Success());
	}
```
(Note: the bound `:layout_location`/`:category_id` params persist across both the SELECT and the COUNT `DataSet` calls because we don't `Clear()` between them — correct here.)

- [ ] **Step 3: Update `search()`** identically — add the same `$opts` param + visibility clause, keep its `name/tags LIKE :query` filter, and add `c.label AS category_label` + the category join. (Apply the same `$vis`/`$base` construction; append `AND (sa.name LIKE :q OR sa.tags LIKE :q)` to `$filters` with `$this->db->q = '%' . $query . '%';`.)

- [ ] **Step 4: Test** — extend `tests/scroll/test_submission_tiers.php`:
```php
// Global browse from a different kingdom must NOT see the kingdom-1 upload
$b = $sa->browse('', 1, 50, array('ViewerKingdomId' => 2, 'Tier' => 'all'));
$ids = array_map(function($a){ return $a['ArtworkId']; }, $b['Artwork']);
assert_true(!in_array($res['ArtworkId'], $ids), 'kingdom-1 private hidden from kingdom-2 viewer');
// Same upload IS visible to a kingdom-1 viewer
$b1 = $sa->browse('', 1, 50, array('ViewerKingdomId' => 1, 'Tier' => 'all'));
$ids1 = array_map(function($a){ return $a['ArtworkId']; }, $b1['Artwork']);
assert_true(in_array($res['ArtworkId'], $ids1), 'kingdom-1 private visible to kingdom-1 viewer (once approved)');
```
(This assertion only holds after the row is approved; either approve it inline via `$sa->approve(...)` with an admin token, or adjust to assert the pending row is excluded. Keep the test consistent with what you can set up.)

- [ ] **Step 5: Run + commit**

Run the test; expect OK. Then:
```bash
git add system/lib/ork3/class.ScrollArtwork.php tests/scroll/test_submission_tiers.php
git commit -m "feat(scroll-graphics): visibility-aware browse/search + category filter"
```

---

### Task 1.6: Lib — tier-aware `get_pending()` + tiered `approve()`/`reject()`

**Files:**
- Modify: `system/lib/ork3/class.ScrollArtwork.php` — `get_pending()`, `approve()`, `reject()`

- [ ] **Step 1: Rewrite `get_pending()`** to accept a tier + authority context:
```php
	public function get_pending($page = 1, $per_page = 20, $opts = array()) {
		$page = max(1, (int)$page); $per_page = max(1, min(100, (int)$per_page));
		$offset = ($page - 1) * $per_page;
		$scope = $opts['Scope'] ?? 'global';          // 'global' or 'kingdom'
		$kingdom_ids = $opts['KingdomIds'] ?? array(); // ints, for 'kingdom' scope

		if ($scope === 'kingdom') {
			$kingdom_ids = array_values(array_filter(array_map('intval', $kingdom_ids), function($x){ return $x > 0; }));
			if (count($kingdom_ids) === 0) {
				return array('Artwork' => array(), 'Total' => 0, 'Page' => $page, 'PerPage' => $per_page, 'Status' => Success());
			}
			$where = "sa.status = 'pending' AND sa.visibility = 'kingdom' AND sa.owner_kingdom_id IN (" . implode(',', $kingdom_ids) . ")";
		} else {
			$where = "sa.status = 'pending' AND sa.visibility = 'global'";
		}

		$base = "FROM " . DB_PREFIX . "scroll_artwork sa
			LEFT JOIN " . DB_PREFIX . "mundane m ON m.mundane_id = sa.uploader_mundane_id
			LEFT JOIN " . DB_PREFIX . "scroll_artwork_category c ON c.category_id = sa.category_id
			WHERE " . $where;

		$this->db->Clear();
		$sql = "SELECT sa.*, m.persona AS uploader_persona, c.label AS category_label
			" . $base . " ORDER BY sa.created_at ASC
			LIMIT " . (int)$per_page . " OFFSET " . (int)$offset;
		$r = $this->db->DataSet($sql);
		$artwork = array();
		while ($r->Next()) { $artwork[] = $this->format_artwork_row($r); }
		$cr = $this->db->DataSet("SELECT COUNT(*) AS total " . $base);
		$total = ($cr->Size() > 0 && $cr->Next()) ? intval($cr->total) : 0;

		return array('Artwork' => $artwork, 'Total' => $total, 'Page' => $page, 'PerPage' => $per_page, 'Status' => Success());
	}
```

- [ ] **Step 2: Make `approve()`/`reject()` tier-aware.** Replace the single `HasAuthority(...AUTH_ADMIN...)` gate at the top of each with: load the row first (need its `visibility`/`owner_kingdom_id`), then authorize by tier. New shared private helper:
```php
	private function can_moderate($mundane_id, $visibility, $owner_kingdom_id) {
		if (Ork3::$Lib->authorization->HasAuthority($mundane_id, AUTH_ADMIN, 0, AUTH_EDIT)) { $this->db->Clear(); return true; }
		if ($visibility === 'kingdom' && intval($owner_kingdom_id) > 0
			&& Ork3::$Lib->authorization->HasAuthority($mundane_id, AUTH_KINGDOM, intval($owner_kingdom_id), AUTH_EDIT)) {
			$this->db->Clear(); return true;
		}
		$this->db->Clear();
		return false;
	}
```
In `approve()`: after `IsAuthorized`, fetch `SELECT scroll_artwork_id, status, visibility, owner_kingdom_id FROM ... WHERE scroll_artwork_id = :artwork_id`, then `if (!$this->can_moderate($mundane_id, $r->visibility, $r->owner_kingdom_id)) return ['Status'=>NoAuthorization()];`, then the existing pending-check + UPDATE. Same change in `reject()`.

- [ ] **Step 3: Test** — `tests/scroll/test_moderation_authority.php`: assert a kingdom-1 officer token can approve a kingdom-1 pending row but NOT a global pending row, and an ORK admin token can approve both. (Gate behind available test tokens; if unavailable, mark these as Phase-2 curl tests in Task 2.3.)

- [ ] **Step 4: Run + commit**

```bash
git add system/lib/ork3/class.ScrollArtwork.php tests/scroll/test_moderation_authority.php
git commit -m "feat(scroll-graphics): tier-aware pending queue + tiered approve/reject"
```

---

## Phase 2 — AJAX endpoints

### Task 2.1: AJAX — `upload` passes tier/category; add `categories` endpoint

**Files:**
- Modify: `orkui/controller/controller.ScrollArtworkAjax.php`

- [ ] **Step 1: Extend `upload()`** — add to the `$request` array built from `$_POST`:
```php
		'Visibility'     => trim($_POST['visibility'] ?? 'global'),
		'OwnerKingdomId' => (int)($_POST['owner_kingdom_id'] ?? 0),
		'CategoryId'     => (int)($_POST['category_id'] ?? 0),
```
For a global submission with no explicit kingdom, default `OwnerKingdomId` to the submitter's kingdom for provenance: after building `$request`, `if ($request['OwnerKingdomId'] <= 0 && isset($this->session->kingdom_id)) { $request['OwnerKingdomId'] = (int)$this->session->kingdom_id; }`.

- [ ] **Step 2: Add a public `categories()` endpoint** (GET, login required) returning active categories for dropdowns/filters:
```php
	public function categories($id = null) {
		$this->require_login();
		$result = $this->sa->list_categories(true);
		$this->json_response(array('Categories' => $result['Categories'] ?? array(), 'Status' => 0));
	}
```

- [ ] **Step 3: Verify via curl** (use the project's curl-auth session pattern from `reference_local_curl_auth_session.md`: log in to `Login/login` with a cookie jar, then GET the endpoint with the same jar):
```bash
# After establishing $JAR via Login/login:
curl -s -b "$JAR" "http://localhost:19080/orkui/index.php?Route=ScrollArtworkAjax/categories" | head -c 400
```
Expected: JSON with `"Categories":[...]` containing Heraldic etc., `"Status":0`.

- [ ] **Step 4: Commit**

```bash
git add orkui/controller/controller.ScrollArtworkAjax.php
git commit -m "feat(scroll-graphics): AJAX upload tier/category params + categories endpoint"
```

---

### Task 2.2: AJAX — `browse`/`search` pass viewer context + filters

**Files:**
- Modify: `orkui/controller/controller.ScrollArtworkAjax.php` — `browse()`, `search()`

- [ ] **Step 1:** In both, read filters from `$_GET` and pass `$opts` with the viewer's kingdom from session:
```php
		$opts = array(
			'ViewerKingdomId' => isset($this->session->kingdom_id) ? (int)$this->session->kingdom_id : 0,
			'Tier'            => in_array($_GET['tier'] ?? 'all', array('all','global','kingdom')) ? $_GET['tier'] : 'all',
			'CategoryId'      => (int)($_GET['category_id'] ?? 0),
		);
		$result = $this->sa->browse($layout_location, $page, $per_page, $opts);
```
(Both endpoints must `require_login()` first — browsing is login-gated per spec. Add `$this->require_login();` at the top of `browse()`/`search()` if not already present.)

- [ ] **Step 2: Verify via curl** that a logged-in user only gets approved rows their kingdom may see (spot-check `Status:0` + array shape).

Run: `curl -s -b "$JAR" "http://localhost:19080/orkui/index.php?Route=ScrollArtworkAjax/browse&layout_location=border_left&tier=all" | head -c 300`
Expected: JSON `{"Artwork":[...],"Total":...,"Status":0}`.

- [ ] **Step 3: Commit**

```bash
git add orkui/controller/controller.ScrollArtworkAjax.php
git commit -m "feat(scroll-graphics): AJAX browse/search visibility + filters"
```

---

### Task 2.3: AJAX — tier-aware `pending`/`approve`/`reject` + kingdom-officer gating

**Files:**
- Modify: `orkui/controller/controller.ScrollArtworkAjax.php`

- [ ] **Step 1: Add a private helper** that returns the kingdoms a user may moderate (their own + any they're an officer of). Minimal version — their session kingdom if they hold `AUTH_KINGDOM` edit there:
```php
	private function moderatable_kingdom_ids($mundane_id) {
		$ids = array();
		$kid = isset($this->session->kingdom_id) ? (int)$this->session->kingdom_id : 0;
		if ($kid > 0 && Ork3::$Lib->authorization->HasAuthority($mundane_id, AUTH_KINGDOM, $kid, AUTH_EDIT)) {
			$ids[] = $kid;
		}
		global $DB; $DB->Clear();
		return $ids;
	}
```
(YAGNI: officers of multiple kingdoms are rare; session kingdom covers the common case. A fuller enumeration can come later.)

- [ ] **Step 2: Rewrite `pending()`** to serve global to admins and kingdom to officers, by `scope` GET param (default chooses by authority):
```php
	public function pending($id = null) {
		$mundane_id = Ork3::$Lib->authorization->IsAuthorized($this->session->token ?? '');
		if ($mundane_id <= 0) { $this->json_response(array('Status' => 5, 'Message' => 'Not authorized.')); }
		$is_admin = Ork3::$Lib->authorization->HasAuthority($mundane_id, AUTH_ADMIN, 0, AUTH_EDIT);
		global $DB; $DB->Clear();
		$scope = ($_GET['scope'] ?? ($is_admin ? 'global' : 'kingdom'));
		$page = max(1, (int)($_GET['page'] ?? 1));
		$per_page = max(1, min(100, (int)($_GET['per_page'] ?? 20)));

		if ($scope === 'global') {
			if (!$is_admin) { $this->json_response(array('Status' => 5, 'Message' => 'Admin privileges required.')); }
			$result = $this->sa->get_pending($page, $per_page, array('Scope' => 'global'));
		} else {
			$kingdom_ids = $this->moderatable_kingdom_ids($mundane_id);
			if (count($kingdom_ids) === 0) { $this->json_response(array('Status' => 5, 'Message' => 'No kingdom moderation authority.')); }
			$result = $this->sa->get_pending($page, $per_page, array('Scope' => 'kingdom', 'KingdomIds' => $kingdom_ids));
		}
		$this->json_response(array('Artwork' => $result['Artwork'] ?? array(), 'Total' => $result['Total'] ?? 0,
			'Page' => $result['Page'] ?? $page, 'PerPage' => $result['PerPage'] ?? $per_page, 'Status' => 0));
	}
```

- [ ] **Step 3: Simplify `approve()`/`reject()`** — drop the `require_admin()` gate (the lib now authorizes by tier). Replace with `require_login()` and let `$this->sa->approve($request)` return `NoAuthorization()` if the caller lacks tier authority. Keep the existing success/error response mapping.

- [ ] **Step 4: Verify via curl** — as an ORK admin, `pending?scope=global` returns rows; as a non-admin kingdom officer, `pending?scope=kingdom` returns only their kingdom's pending. Confirm a non-admin gets `Status:5` for `scope=global`.

- [ ] **Step 5: Commit**

```bash
git add orkui/controller/controller.ScrollArtworkAjax.php
git commit -m "feat(scroll-graphics): tier-aware moderation endpoints"
```

---

### Task 2.4: AJAX — category admin CRUD endpoints

**Files:**
- Modify: `orkui/controller/controller.ScrollArtworkAjax.php`

- [ ] **Step 1: Add `save_category()`** (POST, admin) delegating to the lib:
```php
	public function save_category($id = null) {
		$this->require_admin();
		$request = array(
			'Token'      => $this->session->token,
			'CategoryId' => (int)($_POST['category_id'] ?? 0),
			'Label'      => trim($_POST['label'] ?? ''),
			'SortOrder'  => (int)($_POST['sort_order'] ?? 0),
			'Active'     => !empty($_POST['active']) ? 1 : 0,
		);
		$result = $this->sa->save_category($request);
		if (is_array($result['Status']) && isset($result['Status']['Status']) && $result['Status']['Status'] == 0) {
			$this->json_response(array('Status' => 0, 'CategoryId' => $result['CategoryId'] ?? 0, 'Message' => 'Category saved.'));
		}
		$detail = is_array($result['Status']) ? ($result['Status']['Detail'] ?? $result['Status']['Error'] ?? 'Save failed.') : 'Save failed.';
		$this->json_response(array('Status' => 1, 'Message' => $detail));
	}
```
(Retiring a category = `save_category` with `active=0`. No hard delete, per spec.)

- [ ] **Step 2: Verify via curl** that an admin can create a category and a non-admin gets `Status:5`.

- [ ] **Step 3: Commit**

```bash
git add orkui/controller/controller.ScrollArtworkAjax.php
git commit -m "feat(scroll-graphics): AJAX category admin CRUD"
```

---

## Phase 3 — Standalone module pages

### Task 3.1: New page controller `Controller_ScrollGraphics`

**Files:**
- Create: `orkui/controller/controller.ScrollGraphics.php`

- [ ] **Step 1: Write the controller** (login-gated; four actions; injects a JS config):
```php
<?php
class Controller_ScrollGraphics extends Controller {
	public function __construct($call = null, $id = null) {
		parent::__construct($call, $id);
		// Login-gate the whole module (Reports pattern)
		if (!isset($this->session->user_id)) {
			header('Location: ' . UIR . 'Login');
			exit;
		}
		$this->load_model('Player');
		$this->data['page_title'] = 'Scroll Graphic Submissions';
	}

	private function inject_config() {
		$uid = (int)$this->session->user_id;
		$is_admin = Ork3::$Lib->authorization->HasAuthority($uid, AUTH_ADMIN, 0, AUTH_EDIT);
		$kid = isset($this->session->kingdom_id) ? (int)$this->session->kingdom_id : 0;
		$is_kingdom_officer = $kid > 0 && Ork3::$Lib->authorization->HasAuthority($uid, AUTH_KINGDOM, $kid, AUTH_EDIT);
		global $DB; $DB->Clear();
		$this->data['sg_config'] = array(
			'uir'             => UIR,
			'token'           => isset($this->session->token) ? $this->session->token : '',
			'kingdomId'       => $kid,
			'kingdomName'     => isset($this->session->kingdom_name) ? $this->session->kingdom_name : '',
			'isOrkAdmin'      => $is_admin ? 1 : 0,
			'isKingdomOfficer'=> $is_kingdom_officer ? 1 : 0,
			'canModerate'     => ($is_admin || $is_kingdom_officer) ? 1 : 0,
		);
	}

	public function index($id = null)    { $this->inject_config(); $this->template = '../revised-frontend/ScrollGraphics_index.tpl'; }
	public function upload($id = null)   { $this->inject_config(); $this->template = '../revised-frontend/ScrollGraphics_upload.tpl'; }
	public function mine($id = null)     { $this->inject_config(); $this->template = '../revised-frontend/ScrollGraphics_mine.tpl'; }
	public function moderate($id = null) {
		$this->inject_config();
		if (empty($this->data['sg_config']['canModerate'])) { header('Location: ' . UIR . 'ScrollGraphics'); exit; }
		$this->template = '../revised-frontend/ScrollGraphics_moderate.tpl';
	}
}
```

- [ ] **Step 2: Verify routing** — visit `http://localhost:19080/orkui/index.php?Route=ScrollGraphics` while logged in; expect the index template to attempt to render (next task creates it). Logged out → redirect to Login.

- [ ] **Step 3: Commit**

```bash
git add orkui/controller/controller.ScrollGraphics.php
git commit -m "feat(scroll-graphics): ScrollGraphics page controller (4 routes, login-gated)"
```

---

### Task 3.2: Homepage nav link

**Files:**
- Modify: `orkui/template/default/default.tpl` (the `hm-find-list` block, ~lines 642-697)

- [ ] **Step 1: Add the link** inside a `<?php if (!empty($LoggedIn)): ?> ... <?php endif; ?>` guard, matching the existing `hm-find-item` markup:
```php
            <?php if (!empty($LoggedIn)): ?>
            <a class="hm-find-item" href="<?= UIR ?>ScrollGraphics">
                <i class="fas fa-palette"></i> Scroll Graphic Submissions
            </a>
            <?php endif; ?>
```

- [ ] **Step 2: Verify** the link appears on the homepage when logged in and routes to the module.

- [ ] **Step 3: Commit**

```bash
git add orkui/template/default/default.tpl
git commit -m "feat(scroll-graphics): homepage nav link"
```

---

### Task 3.3: Library page template (`ScrollGraphics_index.tpl`)

**Files:**
- Create: `orkui/template/revised-frontend/ScrollGraphics_index.tpl`
- Create: `orkui/template/revised-frontend/style/scroll-graphics.css`

**Layout:** left filter rail (search, 8 zone checkboxes, category checkboxes loaded from `ScrollArtworkAjax/categories`, tier radio All/Amtgard/My Kingdom) + results grid. Top nav row links: Library (active) · Submit · My Submissions · Moderate (only if `canModerate`).

- [ ] **Step 1: Write the template.** Inject config, include the CSS (cache-busted), render the rail + grid containers, and a `<script>` that:
  - reads `var SG = <?= json_encode($sg_config, JSON_HEX_TAG|JSON_HEX_AMP|JSON_HEX_APOS) ?>;`
  - on load, GETs `SG.uir + 'ScrollArtworkAjax/categories'` → renders category checkboxes;
  - `sgLibLoad()` builds `SG.uir + 'ScrollArtworkAjax/browse?layout_location=<zones>&tier=<tier>&category_id=<id>&page=<n>'` (or `search?query=` when a search term is present) → renders grid cards.
  - **Port the grid-render + pagination logic** from `Scroll_builder.tpl.pre-reinvent.bak` `sgArtworkRenderBrowseGrid` (lines 6054-6091), adapting: card shows thumbnail (`item.Url`), `item.Name`, `item.UploaderPersona`, a tier badge (`item.Visibility === 'kingdom' ? 'Kingdom' : 'Global'`), and `item.CategoryLabel`. Keep `sgEscapeHtml` (copy its definition from the .bak). Card hover action "Use in builder" links to `<?= UIR ?>Scroll/builder` (the builder reads artwork via its own browse modal; deep-linking is out of scope — a plain link is fine for the prototype).

  Provide the full HTML skeleton:
```php
<?php $sg = $sg_config; ?>
<link rel="stylesheet" href="<?= HTTP_TEMPLATE ?>revised-frontend/style/scroll-graphics.css?v=<?= filemtime(DIR_TEMPLATE . 'revised-frontend/style/scroll-graphics.css') ?>">
<div class="sg-wrap">
  <nav class="sg-tabs">
    <a class="sg-tab active" href="<?= UIR ?>ScrollGraphics"><i class="fas fa-images"></i> Library</a>
    <a class="sg-tab" href="<?= UIR ?>ScrollGraphics/upload"><i class="fas fa-upload"></i> Submit a Graphic</a>
    <a class="sg-tab" href="<?= UIR ?>ScrollGraphics/mine"><i class="fas fa-folder"></i> My Submissions</a>
    <?php if (!empty($sg['canModerate'])): ?>
      <a class="sg-tab" href="<?= UIR ?>ScrollGraphics/moderate"><i class="fas fa-gavel"></i> Moderate</a>
    <?php endif; ?>
  </nav>
  <div class="sg-body">
    <aside class="sg-rail">
      <div class="sg-field"><label>Search</label><input type="text" id="sg-search" placeholder="Name or tags"></div>
      <div class="sg-field"><label>Placement zone</label><div id="sg-zone-filters"><!-- 8 checkboxes --></div></div>
      <div class="sg-field"><label>Category</label><div id="sg-category-filters"></div></div>
      <div class="sg-field"><label>Tier</label>
        <label><input type="radio" name="sg-tier" value="all" checked> All</label>
        <label><input type="radio" name="sg-tier" value="global"> Amtgard</label>
        <label><input type="radio" name="sg-tier" value="kingdom"> My Kingdom</label>
      </div>
    </aside>
    <main class="sg-grid-wrap"><div id="sg-grid" class="sg-grid"></div><div id="sg-pagination" class="sg-pagination"></div></main>
  </div>
</div>
<script>
var SG = <?= json_encode($sg, JSON_HEX_TAG|JSON_HEX_AMP|JSON_HEX_APOS) ?>;
// ... sgEscapeHtml (copy from .bak), zone list, category load, sgLibLoad(), render, pagination, debounced search ...
</script>
```
  Fill the `<script>` with complete functions (zone checkbox list = the 8 `VALID_LOCATIONS`; debounce search by 300ms; wire radios + checkboxes to re-call `sgLibLoad()`).

- [ ] **Step 2: Write `scroll-graphics.css`** — flex layout for `.sg-body` (rail `flex:0 0 220px`, grid fills), `.sg-grid` responsive `grid-template-columns: repeat(auto-fill, minmax(150px,1fr))`, card styles, tier badge (`.sg-badge-global`/`.sg-badge-kingdom`), and a **`html[data-theme="dark"]`** override block for every surface (rail bg, cards, inputs, badges). Follow the existing revised.css token conventions (colors like `#2c5282` blue, `#276749` green).

- [ ] **Step 3: Verify in browser** (logged in): rail renders, categories load, grid populates with approved graphics, tier radio filters, dark mode looks correct. (Use Chrome only to verify after implementation, per project rule.)

- [ ] **Step 4: Commit**

```bash
git add orkui/template/revised-frontend/ScrollGraphics_index.tpl orkui/template/revised-frontend/style/scroll-graphics.css
git commit -m "feat(scroll-graphics): library page (filter rail + grid)"
```

---

### Task 3.4: Submit page template (`ScrollGraphics_upload.tpl`)

**Files:**
- Create: `orkui/template/revised-frontend/ScrollGraphics_upload.tpl`

**Single page:** upload → interactive 8-zone wireframe (click sets `layout_location`, shows `SLOT_DIMENSIONS` target + "Download placement guide" → `ScrollArtworkAjax/template_guide`) → name/desc/tags/category → **Amtgard|Kingdom** segmented toggle → license + signature → submit.

- [ ] **Step 1: Write the template.** Reuse the CSS file from 3.3. Port the upload form fields + license block + signature input from `.bak` lines 2580-2630 (the license `<div class="sc-artwork-license">…</div>` text and the signer/agree inputs), restyled with `sg-` classes. Add:
  - the wireframe diagram (a portrait box with 8 clickable zone divs; clicking sets a JS `_zone` var + highlights + updates a dimensions readout from a JS copy of `SLOT_DIMENSIONS`);
  - the **tier toggle**: two buttons "Amtgard" / "Kingdom" backed by a hidden `visibility` value (`global`/`kingdom`); show the "reviewed by ORK admins / your kingdom's officers" note;
  - a category `<select>` populated from `ScrollArtworkAjax/categories`.
  - **Port `sgArtworkUpload`** from `.bak` lines 6143-6199, changing the `FormData` to also append `visibility` (from the toggle), `owner_kingdom_id` (`SG.kingdomId` when tier=kingdom, else `0`), and `category_id` (from the select). Keep the FileReader→base64 (`reader.result.split(',')[1]`), 2 MB client cap, required name/signer/agree validation, and `data.Status === 0` success handling (redirect to `ScrollGraphics/mine` on success).

- [ ] **Step 2: Verify** a real upload round-trips (submit → appears in My Submissions as pending; check the DB row has the chosen `visibility`/`owner_kingdom_id`/`category_id`).

- [ ] **Step 3: Commit**

```bash
git add orkui/template/revised-frontend/ScrollGraphics_upload.tpl
git commit -m "feat(scroll-graphics): submit page (wireframe + tier toggle + license)"
```

---

### Task 3.5: My Submissions template (`ScrollGraphics_mine.tpl`)

**Files:**
- Create: `orkui/template/revised-frontend/ScrollGraphics_mine.tpl`

- [ ] **Step 1: Write the template.** Tab nav (Mine active). Port `sgArtworkLoadMyUploads`/`sgArtworkRenderMyUploads` (`.bak` 6240-6292) and `sgArtworkDelete` (6302-6329), adapting: status badge (pending/approved/rejected), show `RejectionReason` when rejected, show tier badge + category, "Withdraw/Delete" button calling `ScrollArtworkAjax/delete` (FormData `artwork_id`). **Replace the native `confirm()`** in `sgArtworkDelete` with the project's `tnConfirm({...})` modal pattern (per project rule — no native dialogs). Use `ScrollArtworkAjax/my_uploads?page=`.

- [ ] **Step 2: Verify** own uploads list with correct statuses; delete removes the row.

- [ ] **Step 3: Commit**

```bash
git add orkui/template/revised-frontend/ScrollGraphics_mine.tpl
git commit -m "feat(scroll-graphics): My Submissions page"
```

---

### Task 3.6: Moderation page template (`ScrollGraphics_moderate.tpl`)

**Files:**
- Create: `orkui/template/revised-frontend/ScrollGraphics_moderate.tpl`

- [ ] **Step 1: Write the template.** Tab nav (Moderate active, only reachable if `canModerate`). Two sub-sections gated by config:
  - if `SG.isOrkAdmin`: a **Global queue** (`pending?scope=global`) + a **Manage Categories** panel (list from `categories`, add/edit form POSTing `ScrollArtworkAjax/save_category`, retire = save with `active=0`).
  - if `SG.isKingdomOfficer`: a **Kingdom queue** (`pending?scope=kingdom`).
  Port `sgArtworkLoadAdmin`/`sgArtworkRenderAdmin`/`sgArtworkApprove`/`sgArtworkShowReject`/`sgArtworkReject` (`.bak` 6348-6475), adding the submitter persona + tier + license-signer/timestamp to each row, and a `scope` param to the pending fetch. Reject input already inline (keep), but route approve/reject to the same endpoints (now tier-aware server-side).

- [ ] **Step 2: Verify** as ORK admin (global queue + category management) and as a kingdom officer (kingdom queue only); approve/reject move rows out; category add/retire reflects in the Submit page dropdown.

- [ ] **Step 3: Commit**

```bash
git add orkui/template/revised-frontend/ScrollGraphics_moderate.tpl
git commit -m "feat(scroll-graphics): tier-aware moderation page + category management"
```

---

## Phase 4 — In-builder share + ephemeral render

### Task 4.1: Render — refactor compositor + add ephemeral `artwork_<slot>_raw` path

**Files:**
- Modify: `orkui/controller/controller.ScrollAjax.php` — `generate()` (read loop ~272-278, load ~333-345, composite sites ~387-410 & 1362-1367), `compositeArtwork()` (~473-524)

- [ ] **Step 1: Extract a resource-based compositor.** Split `compositeArtwork()` so the body from `imagesavealpha($src,true)` onward lives in a new `compositeArtworkResource($img, $src, $x, $y, $w, $h, $opacity)`, and `compositeArtwork()` becomes:
```php
	private function compositeArtwork($img, $artworkPath, $x, $y, $w, $h, $opacity) {
		$src = @imagecreatefrompng($artworkPath);
		if (!$src) return;
		$this->compositeArtworkResource($img, $src, $x, $y, $w, $h, $opacity);
	}
	private function compositeArtworkResource($img, $src, $x, $y, $w, $h, $opacity) {
		// ... existing body from line 477 (imagesavealpha($src,true);) through imagedestroy($resized); ...
	}
```

- [ ] **Step 2: Add a RAW read loop** after the existing `artwork_<slot>` loop (~line 278):
```php
		// ---- Read ephemeral raw artwork (base64, not persisted) ----
		$artworkRaw = [];
		foreach ($artwork_slots as $slot) {
			$b64 = $_POST['artwork_' . $slot . '_raw'] ?? '';
			if (is_string($b64) && strlen($b64) > 0 && strlen($b64) <= ScrollArtwork::MAX_UPLOAD_BASE64) {
				$bytes = base64_decode($b64, true);
				if ($bytes !== false && strlen($bytes) <= ScrollArtwork::MAX_UPLOAD_BYTES) {
					$res = @imagecreatefromstring($bytes);
					if ($res !== false) { $artworkRaw[$slot] = $res; }
				}
			}
		}
```
Bundle `$artworkRaw` into the render state next to `artworkImages` (~line 432): `'artworkRaw' => $artworkRaw,`.

- [ ] **Step 3: Composite raw at the four sites with identical z-order/opacity.** At each existing `compositeArtwork(...)` call site (watermark@10 line 388, full_border@100 397, edge borders@100 401-405, top_graphic@100 407, center_image@15 in `drawCenterImageSlot`), add a parallel raw branch using `SLOT_DIMENSIONS` + `compositeArtworkResource`. Example for watermark:
```php
		if (isset($artworkRaw['watermark'])) {
			$dims = ScrollArtwork::SLOT_DIMENSIONS['watermark'];
			$this->compositeArtworkResource($img, $artworkRaw['watermark'], $dims['x'], $dims['y'], $dims['w'], $dims['h'], 10);
		}
```
Repeat for each slot at its opacity. In `drawCenterImageSlot($state)` add the `$state['artworkRaw']['center_image']` branch at opacity 15. **Raw takes precedence over ID for the same slot** is unnecessary (a slot uses one or the other); compositing both is harmless but prefer raw if present — guard the ID branch with `if (!isset($artworkRaw[$slot]) && isset($artworkImages[$slot]))`.

- [ ] **Step 4: Verify** with a synthetic POST: send `artwork_watermark_raw` = base64 of a test PNG to `ScrollAjax/generate` (with the other required fields) and confirm a 200 PNG comes back and the watermark is composited. (Use the curl-auth session.)

- [ ] **Step 5: Commit**

```bash
git add orkui/controller/controller.ScrollAjax.php
git commit -m "feat(scroll-graphics): ephemeral artwork_<slot>_raw compositing path"
```

---

### Task 4.2: Builder — in-builder share modal + tier toggle + ephemeral send

**Files:**
- Modify: the active builder template (`orkui/template/revised-frontend/Scroll_builder.tpl` and/or the `scroll-forge/` partials — confirm which is live; the forge partials are the current source)

- [ ] **Step 1: Add an "Upload your own" action per zone** in the builder's artwork section that opens a modal: file picker + preview + a **"Share this with the Amtgard Graphics Library"** checkbox (default **unchecked**). When checked, reveal the **Amtgard|Kingdom** toggle, the license text, agree checkbox, and signature input. Button label: "Use on My Scroll" → "Use & Submit to Library" when sharing.

- [ ] **Step 2: Wire the two outcomes.**
  - **Not shared:** read the file as base64, store it in `sgState.artwork[slot] = { raw: base64 }` (no id), draw it into the preview. Nothing else.
  - **Shared:** validate agree+signer, POST to `ScrollArtworkAjax/upload` with `visibility` (from toggle), `owner_kingdom_id` (`SgConfig.kingdomId` if kingdom), `category_id` (optional), and the standard fields — AND also set `sgState.artwork[slot] = { raw: base64 }` so the current scroll renders it immediately (it's pending, so it can't be loaded by id yet).

- [ ] **Step 3: Send raw bytes on export.** In `sgDownload()` artwork loop (`.bak`/live ~lines 5187-5192), alongside `fd.append('artwork_'+_akey, ...id)`, append the raw when present:
```js
      if (sgState.artwork[_akey] && sgState.artwork[_akey].raw) {
        fd.append('artwork_' + _akey + '_raw', sgState.artwork[_akey].raw);
      }
```

- [ ] **Step 4: Verify** end-to-end: in the builder, upload-without-sharing → the graphic appears on the downloaded 300-DPI PNG (via `_raw`), and no library row is created. Upload-with-sharing → same render PLUS a pending row appears in My Submissions / the correct moderation queue with the chosen tier.

- [ ] **Step 5: Commit**

```bash
git add orkui/template/revised-frontend/Scroll_builder.tpl   # + any scroll-forge/*.part touched
git commit -m "feat(scroll-graphics): in-builder opt-in share + ephemeral raw render"
```

---

## Self-review checklist (completed)

- **Spec coverage:** Library (3.3), Submit+wireframe (3.4), My Submissions (3.5), tier-aware Moderation (3.6, 2.3), admin categories (1.2/1.3/2.4/3.6), two-tier visibility (1.1/1.5), tiered moderation authority (1.6/2.3), in-builder opt-in share + ephemeral render (4.1/4.2), license capture (existing + ported form), homepage link (3.2), dark mode (3.3 CSS), 8 fixed zones/wireframe (3.4) — all mapped.
- **Out-of-scope held out:** no per-user private library (in-builder non-shared = ephemeral, Task 4.2); no category hierarchy; no approved-file versioning.
- **Type/naming consistency:** lib returns PascalCase keys (`ArtworkId`, `Visibility`, `OwnerKingdomId`, `CategoryId`, `CategoryLabel`); AJAX responses use capitalized `Status`/`Message` (0=success); JS reads `data.Status === 0`, `item.Url/Name/UploaderPersona/Visibility/CategoryLabel`; `visibility` values are `global`/`kingdom`; `SLOT_DIMENSIONS`/`VALID_LOCATIONS` reused verbatim; `compositeArtworkResource` used by both render paths.
- **House rules honored:** `$this->db->Clear()`/`global $DB; $DB->Clear()` after `HasAuthority`; nullable FKs omitted from INSERT when null (yapo-null-skip); `tnConfirm` instead of native `confirm`; `html[data-theme="dark"]` dark mode; `.tpl` = plain PHP; never stage `class.Authorization.php`.

## Known follow-ups (not blocking the prototype)

- License text is a draft pending legal review (spec §9, §13).
- `moderatable_kingdom_ids()` covers the session kingdom only; multi-kingdom officers need a fuller enumeration later.
- Deep-linking a library graphic straight into the builder is a plain link for now (insert-by-id from the library page is a later enhancement).
