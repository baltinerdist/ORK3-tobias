# Event Site Details Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "Site" tab to the event page: quick-toggle + freeform site rules, an uploadable site-map image with tagged pin locations (Leaflet), and schedule↔map interactivity.

**Architecture:** Three new DB tables + one schedule column, all keyed to `event_calendardetail_id`. Five new `EventAjax` JSON actions cloned from the `add_schedule` conventions. All UI lives in `Eventnew_index.tpl` (plain-PHP template, `ev-` namespace) with two small shared-file edits to `revised.js`. Map viewer = Leaflet 1.9.4 `L.CRS.Simple` + `L.imageOverlay` + `L.divIcon` pins, coordinates stored as 0–1 fractions.

**Tech Stack:** PHP 8 (no framework), MySQL/MariaDB, plain-PHP `.tpl` templates, vanilla JS, Leaflet 1.9.4 (CDN), FontAwesome 5.8.2.

**Spec:** `docs/superpowers/specs/2026-07-16-event-site-details-design.md`

## Global Constraints

- **`.tpl` files are PLAIN PHP** — `<?php ?>`/`<?= ?>`, never Smarty syntax.
- **FontAwesome 5.8.2 only** — every icon in this plan was verified against FA 5.8.2; do not substitute FA6 names.
- **No native `alert()`/`confirm()`/`prompt()`** — in-page modals/inline errors only.
- **Dark mode required** on every new surface: `html[data-theme="dark"]` selector.
- **`$DB->Clear()` before every raw `Execute`/`DataSet`** — no exceptions.
- **Manual SQL escaping**: `str_replace(["'", '\\'], ["''", '\\\\'], $v)` for strings; `(int)`-cast every id; `sprintf('%.6F', $f)` for floats (locale-safe).
- **Upload cap: 2MB** (2,097,152 bytes), JPEG/PNG only, magic-byte checked via `exif_imagetype()`.
- **No transactions** — `YapoMysql` on this branch has no `Begin`/`Commit`/`Rollback` (they exist only on an unmerged branch). Validate fully before the first write; the spec's "one transaction" for rules-save becomes DELETE + single multi-row INSERT.
- **PSR-12 normalize-first**: before editing a PHP file, run `awk '/^\t/{c++}END{print c+0}' <file>`; if non-zero, run `./php-cs-fixer.phar fix <file>` first, commit that separately. (`Eventnew_index.tpl` and `revised.js` legitimately use tabs — match the file's existing style there; do NOT run the fixer on `.tpl`.)
- **NEVER stage `system/lib/ork3/class.Authorization.php`** (contains a local `true ||` auth bypass) or `CLAUDE.md`/`agent-instructions/claude.md`. Stage files explicitly by name; never `git add -A`/`git add .`. Run `git diff --cached` before every commit.
- **Local testing note:** the local `class.Authorization.php` bypass makes `HasAuthority` return true for any logged-in user, so authorized-path curl tests work with any account, and **denial paths can only be verified by code review locally** (each auth-denial step below says "code-review verify").
- **App URL:** `http://localhost:19080/orkui/index.php?Route=...` (query-string routing; clean URLs 404). Containers: `ork3-php8-app` (app), `ork3-php8-db` (MariaDB, client binary is `mariadb`).
- **APCu caches table schemas for 24h** — after applying the migration, `docker restart ork3-php8-app`.

## Shared test setup (used by many tasks)

Login (bypass accepts any password; field names are `username`/`password`; sessions are single-device — reuse ONE cookie jar):

```bash
JAR=/private/tmp/claude-501/-Users-averykrouse-GitHub-ORK-tobias-ORK3-tobias/15549047-8f6f-4fd0-9de4-42a0cd86ff00/scratchpad/ork-cookies.txt
BASE='http://localhost:19080/orkui/index.php?Route='
curl -s -c "$JAR" -d 'username=Baltasar&password=x' "${BASE}Login/login" -o /dev/null
```

(If the persona `Baltasar` doesn't exist locally, pick any: `docker exec ork3-php8-db mariadb -u root -proot ork -N -e "SELECT username FROM ork_mundane WHERE username != '' LIMIT 5"`.)

Pick a test event (needs an event_id + detail_id pair):

```bash
docker exec ork3-php8-db mariadb -u root -proot ork -e \
  "SELECT cd.event_id, cd.event_calendardetail_id FROM ork_event_calendardetail cd ORDER BY cd.event_calendardetail_id DESC LIMIT 5"
# export EID=<event_id> DID=<detail_id> from a row of this output
```

All AJAX calls need the header `-H 'X-Requested-With: XMLHttpRequest'` (convention, not enforced).

---

### Task 1: Migration + config constants

**Files:**
- Create: `db-migrations/2026-07-16-add-event-site-details.sql`
- Modify: `config.dist.php` (HTTP constants ~L24-25 block; DIR constants ~L54-55 block)
- Modify: `config.dev.php` (same constants — find the matching blocks with `grep -n 'DIR_EVENT_BANNER\|HTTP_EVENT_BANNER' config.dev.php`)

**Interfaces:**
- Produces: tables `ork_event_site_map`, `ork_event_site_rule`, `ork_event_site_location`; column `ork_event_schedule.site_location_id`; PHP constants `DIR_SITEMAP` (filesystem path, trailing slash), `HTTP_SITEMAP` (URL prefix, trailing slash). Every later task depends on these.

- [ ] **Step 1: Write the migration file**

Create `db-migrations/2026-07-16-add-event-site-details.sql`:

```sql
-- Event Site Details: site-map image metadata, tagged map locations,
-- structured site rules, and schedule→location linkage.
-- Spec: docs/superpowers/specs/2026-07-16-event-site-details-design.md
-- Engine + charset explicit so the FKs validate (legacy installs default
-- to MyISAM, which can't accept FK declarations).

-- One uploaded site map per event. File lives at
-- assets/sitemaps/{event_calendardetail_id %05d}.{ext}; width/height are the
-- image's natural pixel dimensions (needed for Leaflet CRS.Simple bounds).
CREATE TABLE IF NOT EXISTS ork_event_site_map (
    event_calendardetail_id INT NOT NULL,
    ext                     VARCHAR(4) NOT NULL DEFAULT 'jpg',
    width                   SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    height                  SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    uploaded_by             INT NOT NULL DEFAULT 0,
    modified                TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (event_calendardetail_id),
    CONSTRAINT fk_sitemap_detail
        FOREIGN KEY (event_calendardetail_id)
        REFERENCES ork_event_calendardetail (event_calendardetail_id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- One row per site rule. rule_key is a curated-catalog key ('smoking', ...)
-- for pill rules and NULL for freeform custom rules; the UNIQUE key permits
-- each pill at most once per event while allowing unlimited customs (NULLs
-- don't collide in MySQL unique indexes).
CREATE TABLE IF NOT EXISTS ork_event_site_rule (
    event_site_rule_id      INT NOT NULL AUTO_INCREMENT,
    event_calendardetail_id INT NOT NULL,
    rule_key                VARCHAR(40) NULL,
    value                   VARCHAR(60) NOT NULL DEFAULT '',
    title                   VARCHAR(120) NOT NULL DEFAULT '',
    details                 TEXT NULL,
    sort_order              SMALLINT NOT NULL DEFAULT 0,
    PRIMARY KEY (event_site_rule_id),
    UNIQUE KEY uq_site_rule (event_calendardetail_id, rule_key),
    CONSTRAINT fk_siterule_detail
        FOREIGN KEY (event_calendardetail_id)
        REFERENCES ork_event_calendardetail (event_calendardetail_id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tagged pins on the site map. x/y are fractions (0–1) of the image's
-- natural width/height so pins survive re-uploads and any display size.
CREATE TABLE IF NOT EXISTS ork_event_site_location (
    event_site_location_id  INT NOT NULL AUTO_INCREMENT,
    event_calendardetail_id INT NOT NULL,
    name                    VARCHAR(80) NOT NULL DEFAULT '',
    description             TEXT NULL,
    category                VARCHAR(30) NOT NULL DEFAULT 'other',
    x                       DECIMAL(7,6) NOT NULL DEFAULT 0,
    y                       DECIMAL(7,6) NOT NULL DEFAULT 0,
    sort_order              SMALLINT NOT NULL DEFAULT 0,
    modified                TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (event_site_location_id),
    KEY idx_site_location_detail (event_calendardetail_id),
    CONSTRAINT fk_siteloc_detail
        FOREIGN KEY (event_calendardetail_id)
        REFERENCES ork_event_calendardetail (event_calendardetail_id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Schedule items may link to a tagged location. ON DELETE SET NULL so
-- deleting a pin never breaks the schedule (the free-text `location`
-- column keeps a readable copy of the pin name).
ALTER TABLE ork_event_schedule
    ADD COLUMN site_location_id INT NULL DEFAULT NULL,
    ADD KEY idx_sched_site_location (site_location_id),
    ADD CONSTRAINT fk_sched_site_location
        FOREIGN KEY (site_location_id)
        REFERENCES ork_event_site_location (event_site_location_id)
        ON DELETE SET NULL;
```

- [ ] **Step 2: Apply it locally and verify**

```bash
docker exec -i ork3-php8-db mariadb -u root -proot ork < db-migrations/2026-07-16-add-event-site-details.sql
docker exec ork3-php8-db mariadb -u root -proot ork -e "SHOW CREATE TABLE ork_event_site_location\G SHOW COLUMNS FROM ork_event_schedule LIKE 'site_location_id'"
docker restart ork3-php8-app
```

Expected: all three tables exist with FKs; `site_location_id | int(11) | YES`. (If the schedule FK errors on a legacy MyISAM `ork_event_schedule`, run `ALTER TABLE ork_event_schedule ENGINE=InnoDB;` first — local-DB-only fix, do not add to the migration.)

- [ ] **Step 3: Add config constants**

In `config.dist.php`, after `define('HTTP_PARK_BANNER', ...)` (~L25) add:

```php
define('HTTP_SITEMAP', HTTP_ASSETS . 'sitemaps/');
```

After `define('DIR_EVENT_BANNER', ...)` (~L55) add:

```php
define('DIR_SITEMAP', DIR_ASSETS . "sitemaps/");
```

Make the identical two additions in `config.dev.php` next to its matching `HTTP_EVENT_BANNER`/`DIR_EVENT_BANNER` lines. (The live local `config.php` is generated from dev — check `docker exec ork3-php8-app php -r 'require "/var/www/html/config.php"; echo DIR_SITEMAP;'`; if the container mounts `config.php` directly and it lacks the constants, add the same two lines there too — but never commit `config.php`.)

- [ ] **Step 4: Verify constants resolve**

```bash
docker exec ork3-php8-app php -r 'require "/var/www/html/config.php"; echo DIR_SITEMAP, "\n", HTTP_SITEMAP, "\n";'
```

Expected: two paths ending in `sitemaps/`, no warnings.

- [ ] **Step 5: Commit**

```bash
git add db-migrations/2026-07-16-add-event-site-details.sql config.dist.php config.dev.php
git diff --cached   # verify ONLY these files, no Authorization.php
git commit -m "Enhancement: site-details schema + sitemap asset constants"
```

---

### Task 2: Rule + location catalog include

**Files:**
- Create: `system/lib/ork3/eventsite-catalog.php`

**Interfaces:**
- Produces: `event_site_rule_catalog(): array` — `key => ['label'=>string, 'icon'=>string(FA5, no 'fas' prefix), 'values'=> valueKey => ['label'=>string, 'severity'=>'restrictive'|'neutral'|'permissive']]`; and `event_site_location_categories(): array` — `key => ['label'=>string, 'icon'=>string, 'color'=>hex]`. Consumed by EventAjax validation (Tasks 3, 5) and the template (Tasks 7–9). Include path: `require_once(DIR_LIB . 'ork3/eventsite-catalog.php');` — both functions are guarded so a double-include is safe.

- [ ] **Step 1: Write the file**

Create `system/lib/ork3/eventsite-catalog.php` (4-space indentation, PSR-12):

```php
<?php

/**
 * Curated catalogs for the event Site tab.
 * Shared by the Eventnew template (rendering) and Controller_EventAjax
 * (validation) — single source of truth, no admin surface.
 * Severity drives rule-chip color: restrictive=red, neutral=gray,
 * permissive=green. Icons are FontAwesome 5.8.2 names (no fa/fas prefix).
 */
if (!function_exists('event_site_rule_catalog')) {
    function event_site_rule_catalog(): array
    {
        return [
            'smoking' => ['label' => 'Smoking', 'icon' => 'fa-smoking-ban', 'values' => [
                'none'       => ['label' => 'None on site',     'severity' => 'restrictive'],
                'designated' => ['label' => 'Designated areas', 'severity' => 'neutral'],
                'outdoors'   => ['label' => 'Outdoors only',    'severity' => 'neutral'],
            ]],
            'alcohol' => ['label' => 'Alcohol', 'icon' => 'fa-wine-bottle', 'values' => [
                'none'    => ['label' => 'None on site',       'severity' => 'restrictive'],
                'private' => ['label' => 'Private areas only', 'severity' => 'neutral'],
                'legal'   => ['label' => 'Permitted 21+',      'severity' => 'permissive'],
                'byob'    => ['label' => 'BYOB',               'severity' => 'permissive'],
            ]],
            'pets' => ['label' => 'Pets', 'icon' => 'fa-paw', 'values' => [
                'none'    => ['label' => 'No pets',              'severity' => 'restrictive'],
                'service' => ['label' => 'Service animals only', 'severity' => 'restrictive'],
                'leashed' => ['label' => 'Leashed pets welcome', 'severity' => 'permissive'],
            ]],
            'fires' => ['label' => 'Fires', 'icon' => 'fa-fire', 'values' => [
                'none'   => ['label' => 'No open flame',          'severity' => 'restrictive'],
                'rings'  => ['label' => 'Fire rings only',        'severity' => 'neutral'],
                'stoves' => ['label' => 'Camp stoves only',       'severity' => 'neutral'],
                'open'   => ['label' => 'Ground fires permitted', 'severity' => 'permissive'],
            ]],
            'weapons' => ['label' => 'Weapons', 'icon' => 'fa-shield-alt', 'values' => [
                'amtgard'    => ['label' => 'Amtgard-legal only',    'severity' => 'neutral'],
                'peace-tied' => ['label' => 'Live steel peace-tied', 'severity' => 'neutral'],
                'no-steel'   => ['label' => 'No live steel',         'severity' => 'restrictive'],
            ]],
            'minors' => ['label' => 'Minors', 'icon' => 'fa-child', 'values' => [
                'welcome'  => ['label' => 'Minors welcome',       'severity' => 'permissive'],
                'guardian' => ['label' => 'Minors with guardian', 'severity' => 'neutral'],
                'adults'   => ['label' => '18+ site',             'severity' => 'restrictive'],
            ]],
            'quiet' => ['label' => 'Quiet Hours', 'icon' => 'fa-moon', 'values' => [
                'enforced' => ['label' => 'Quiet hours enforced', 'severity' => 'neutral'],
                'none'     => ['label' => 'No quiet hours',       'severity' => 'permissive'],
            ]],
            'vehicles' => ['label' => 'Vehicles', 'icon' => 'fa-car', 'values' => [
                'lot'     => ['label' => 'Designated parking only', 'severity' => 'neutral'],
                'no-gate' => ['label' => 'No vehicles past gate',   'severity' => 'restrictive'],
                'camp'    => ['label' => 'Drive-in camping OK',     'severity' => 'permissive'],
            ]],
            'swimming' => ['label' => 'Swimming', 'icon' => 'fa-swimmer', 'values' => [
                'allowed'  => ['label' => 'Allowed',     'severity' => 'permissive'],
                'own-risk' => ['label' => 'At own risk', 'severity' => 'neutral'],
                'no'       => ['label' => 'Prohibited',  'severity' => 'restrictive'],
            ]],
            'trash' => ['label' => 'Trash', 'icon' => 'fa-trash-alt', 'values' => [
                'packout'   => ['label' => 'Pack in, pack out', 'severity' => 'neutral'],
                'dumpsters' => ['label' => 'Dumpsters on site', 'severity' => 'permissive'],
            ]],
        ];
    }
}

if (!function_exists('event_site_location_categories')) {
    function event_site_location_categories(): array
    {
        return [
            'battlefield' => ['label' => 'Battlefield', 'icon' => 'fa-flag',           'color' => '#c53030'],
            'feast'       => ['label' => 'Feast Hall',  'icon' => 'fa-utensils',       'color' => '#dd6b20'],
            'camping'     => ['label' => 'Camping',     'icon' => 'fa-campground',     'color' => '#38a169'],
            'parking'     => ['label' => 'Parking',     'icon' => 'fa-parking',        'color' => '#3182ce'],
            'water'       => ['label' => 'Water',       'icon' => 'fa-tint',           'color' => '#00b5d8'],
            'firstaid'    => ['label' => 'First Aid',   'icon' => 'fa-first-aid',      'color' => '#e53e3e'],
            'privies'     => ['label' => 'Restrooms',   'icon' => 'fa-restroom',       'color' => '#805ad5'],
            'vendors'     => ['label' => 'Vendors',     'icon' => 'fa-store',          'color' => '#d69e2e'],
            'stage'       => ['label' => 'Stage/Court', 'icon' => 'fa-theater-masks',  'color' => '#6b46c1'],
            'other'       => ['label' => 'Other',       'icon' => 'fa-map-marker-alt', 'color' => '#4a5568'],
        ];
    }
}
```

- [ ] **Step 2: Lint + smoke it in the container**

```bash
docker exec ork3-php8-app php -l /var/www/html/system/lib/ork3/eventsite-catalog.php
docker exec ork3-php8-app php -r 'require "/var/www/html/system/lib/ork3/eventsite-catalog.php"; $c=event_site_rule_catalog(); echo count($c), " rule cats / ", count(event_site_location_categories()), " loc cats\n";'
```

Expected: `No syntax errors` then `10 rule cats / 10 loc cats`.

- [ ] **Step 3: Commit**

```bash
git add system/lib/ork3/eventsite-catalog.php
git diff --cached
git commit -m "Enhancement: curated site-rule + map-location catalogs"
```

---

### Task 3: EventAjax shared helpers + `site_rules_save`

**Files:**
- Modify: `orkui/controller/controller.EventAjax.php` (append new methods before the closing `}` of the class at L1882; file is 4-space PSR-12 — run the normalize-first check anyway)

**Interfaces:**
- Consumes: catalog functions from Task 2; tables from Task 1.
- Produces (used by Tasks 4–6):
  - `private function _detailBelongsToEvent(int $event_id, int $detail_id): bool`
  - `private function _canManageSite(int $event_id, int $detail_id): bool` — includes the belongs-to check
  - `private function _loadSiteRules(int $detail_id): array` — rows `['RuleId'=>int,'RuleKey'=>?string,'Value'=>string,'Title'=>string,'Details'=>string,'SortOrder'=>int]`
  - `private function _escSql(string $v): string`
  - HTTP: `POST EventAjax/site_rules_save/{event_id}/{detail_id}` with form field `Rules` = JSON array of `{RuleKey, Value, Title, Details}` (RuleKey empty/absent = custom rule; array order = custom sort order). Returns `{status:0, rules:[...]}` (same row shape as `_loadSiteRules`).

- [ ] **Step 1: Add the shared private helpers**

Append inside `Controller_EventAjax`, before the final class `}`:

```php
    private function _escSql(string $v): string
    {
        return str_replace(["'", '\\'], ["''", '\\\\'], $v);
    }

    private function _detailBelongsToEvent(int $event_id, int $detail_id): bool
    {
        global $DB;
        $DB->Clear();
        $row = $DB->DataSet('SELECT 1 FROM ' . DB_PREFIX . 'event_calendardetail WHERE event_calendardetail_id = ' . $detail_id . ' AND event_id = ' . $event_id . ' LIMIT 1');
        return $row && $row->Next();
    }

    // Site Details editing gate: full event managers only (AUTH_EDIT or a
    // staff row with can_manage). Also preflights that the detail belongs to
    // the event — site-map files are keyed by detail_id alone, so an id
    // mismatch here would let an editor of event A write files for event B.
    private function _canManageSite(int $event_id, int $detail_id): bool
    {
        if (!$this->_detailBelongsToEvent($event_id, $detail_id)) {
            return false;
        }
        $uid = (int)$this->session->user_id;
        if (Ork3::$Lib->authorization->HasAuthority($uid, AUTH_EVENT, $event_id, AUTH_EDIT)) {
            return true;
        }
        global $DB;
        $DB->Clear();
        $staffRow = $DB->DataSet('SELECT 1 FROM ' . DB_PREFIX . 'event_staff WHERE event_calendardetail_id = ' . $detail_id . ' AND mundane_id = ' . $uid . ' AND can_manage = 1 LIMIT 1');
        return $staffRow && $staffRow->Next();
    }

    private function _loadSiteRules(int $detail_id): array
    {
        global $DB;
        $DB->Clear();
        $rows = $DB->DataSet(
            'SELECT event_site_rule_id AS RuleId, rule_key AS RuleKey, value AS Value, title AS Title, details AS Details, sort_order AS SortOrder
			FROM ' . DB_PREFIX . 'event_site_rule
			WHERE event_calendardetail_id = ' . $detail_id . '
			ORDER BY sort_order, event_site_rule_id'
        );
        $out = [];
        if ($rows) {
            while ($rows->Next()) {
                $out[] = [
                    'RuleId'    => (int)$rows->RuleId,
                    'RuleKey'   => $rows->RuleKey !== null ? (string)$rows->RuleKey : null,
                    'Value'     => (string)($rows->Value ?? ''),
                    'Title'     => (string)($rows->Title ?? ''),
                    'Details'   => (string)($rows->Details ?? ''),
                    'SortOrder' => (int)$rows->SortOrder,
                ];
            }
        }
        return $out;
    }
```

- [ ] **Step 2: Add `site_rules_save`**

Append after the helpers:

```php
    public function site_rules_save($p = null)
    {
        header('Content-Type: application/json');
        if (!isset($this->session->user_id)) {
            echo json_encode(['status' => 5, 'error' => 'Not logged in']);
            exit;
        }

        $params    = explode('/', $p ?? '');
        $event_id  = (int)preg_replace('/[^0-9]/', '', $params[0] ?? '');
        $detail_id = (int)preg_replace('/[^0-9]/', '', $params[1] ?? '');
        if (!valid_id($event_id) || !valid_id($detail_id)) {
            echo json_encode(['status' => 1, 'error' => 'Invalid Event ID.']);
            exit;
        }
        if (!$this->_canManageSite($event_id, $detail_id)) {
            echo json_encode(['status' => 3, 'error' => 'Not authorized.']);
            exit;
        }

        require_once(DIR_LIB . 'ork3/eventsite-catalog.php');
        $catalog = event_site_rule_catalog();

        $rulesJson = trim($_POST['Rules'] ?? '');
        $rulesIn   = ($rulesJson !== '') ? json_decode($rulesJson, true) : [];
        if (!is_array($rulesIn)) {
            echo json_encode(['status' => 1, 'error' => 'Invalid rules payload.']);
            exit;
        }

        // Validate the full payload BEFORE any write (no transactions on
        // this branch — the failure window between DELETE and INSERT must
        // only ever contain pre-validated data).
        $pillRows   = [];
        $customRows = [];
        foreach ($rulesIn as $r) {
            if (!is_array($r)) {
                continue;
            }
            $key     = trim((string)($r['RuleKey'] ?? ''));
            $value   = trim((string)($r['Value']   ?? ''));
            $title   = trim((string)($r['Title']   ?? ''));
            $details = trim((string)($r['Details'] ?? ''));
            if ($key !== '') {
                if (!isset($catalog[$key]['values'][$value])) {
                    echo json_encode(['status' => 1, 'error' => 'Unknown rule option.']);
                    exit;
                }
                $pillRows[$key] = ['value' => $value, 'details' => $details];
            } elseif ($title !== '') {
                $customRows[] = ['title' => mb_substr($title, 0, 120), 'details' => $details];
            }
        }

        global $DB;
        $values = [];
        foreach ($pillRows as $key => $r) {
            $values[] = '(' . $detail_id . ", '" . $this->_escSql($key) . "', '" . $this->_escSql($r['value']) . "', '', '" . $this->_escSql($r['details']) . "', 0)";
        }
        $sort = 0;
        foreach ($customRows as $r) {
            $values[] = '(' . $detail_id . ", NULL, '', '" . $this->_escSql($r['title']) . "', '" . $this->_escSql($r['details']) . "', " . $sort++ . ')';
        }

        $DB->Clear();
        $DB->Execute('DELETE FROM ' . DB_PREFIX . 'event_site_rule WHERE event_calendardetail_id = ' . $detail_id);
        if (!empty($values)) {
            $DB->Clear();
            $DB->Execute(
                'INSERT INTO ' . DB_PREFIX . 'event_site_rule
				(event_calendardetail_id, rule_key, value, title, details, sort_order)
				VALUES ' . implode(', ', $values)
            );
        }

        echo json_encode(['status' => 0, 'rules' => $this->_loadSiteRules($detail_id)]);
        exit;
    }
```

- [ ] **Step 3: Lint, then curl-test the failure and success paths**

```bash
docker exec ork3-php8-app php -l /var/www/html/orkui/controller/controller.EventAjax.php
# (login + EID/DID from Shared test setup)
# Invalid catalog key must reject:
curl -s -b "$JAR" -H 'X-Requested-With: XMLHttpRequest' \
  --data-urlencode 'Rules=[{"RuleKey":"smoking","Value":"bogus"}]' \
  "${BASE}EventAjax/site_rules_save/$EID/$DID"
# Expected: {"status":1,"error":"Unknown rule option."}

# Valid save (2 pills + 1 custom):
curl -s -b "$JAR" -H 'X-Requested-With: XMLHttpRequest' \
  --data-urlencode 'Rules=[{"RuleKey":"smoking","Value":"designated"},{"RuleKey":"alcohol","Value":"none","Details":"Dry site by park rules"},{"Title":"No glass containers","Details":"Gravel swim beach"}]' \
  "${BASE}EventAjax/site_rules_save/$EID/$DID"
# Expected: {"status":0,"rules":[ ...3 rows, custom row has "RuleKey":null... ]}

# Replace-all semantics — save a smaller set, expect exactly 1 row back:
curl -s -b "$JAR" -H 'X-Requested-With: XMLHttpRequest' \
  --data-urlencode 'Rules=[{"RuleKey":"pets","Value":"service"}]' \
  "${BASE}EventAjax/site_rules_save/$EID/$DID"
docker exec ork3-php8-db mariadb -u root -proot ork -e "SELECT rule_key, value, title FROM ork_event_site_rule WHERE event_calendardetail_id = $DID"
# Expected: exactly one row: pets/service
```

Also verify a mismatched pair is denied (code-path is `_detailBelongsToEvent`, which runs before the local auth bypass can matter — this one IS locally testable): call with a `$DID` belonging to a different event; expect `{"status":3,...}`.

- [ ] **Step 4: Commit**

```bash
git add orkui/controller/controller.EventAjax.php
git diff --cached
git commit -m "Enhancement: site_rules_save endpoint + site-details auth helpers"
```

---

### Task 4: `site_map_upload` + `site_map_delete`

**Files:**
- Modify: `orkui/controller/controller.EventAjax.php` (append after `site_rules_save`)

**Interfaces:**
- Consumes: `_canManageSite` (Task 3), `DIR_SITEMAP`/`HTTP_SITEMAP` (Task 1).
- Produces:
  - `POST EventAjax/site_map_upload/{event_id}/{detail_id}` with multipart file field `SiteMap`. Returns `{status:0, map:{Url, Width, Height}}`.
  - `POST EventAjax/site_map_delete/{event_id}/{detail_id}` → `{status:0}`. Pins stay in the DB (spec: a future re-upload restores them).
  - File on disk: `DIR_SITEMAP . sprintf('%05d', $detail_id) . '.' . ('jpg'|'png')`.

- [ ] **Step 1: Add `site_map_upload`**

```php
    public function site_map_upload($p = null)
    {
        header('Content-Type: application/json');
        if (!isset($this->session->user_id)) {
            echo json_encode(['status' => 5, 'error' => 'Not logged in']);
            exit;
        }

        $params    = explode('/', $p ?? '');
        $event_id  = (int)preg_replace('/[^0-9]/', '', $params[0] ?? '');
        $detail_id = (int)preg_replace('/[^0-9]/', '', $params[1] ?? '');
        if (!valid_id($event_id) || !valid_id($detail_id)) {
            echo json_encode(['status' => 1, 'error' => 'Invalid Event ID.']);
            exit;
        }
        if (!$this->_canManageSite($event_id, $detail_id)) {
            echo json_encode(['status' => 3, 'error' => 'Not authorized.']);
            exit;
        }

        if (empty($_FILES['SiteMap']['tmp_name'])) {
            echo json_encode(['status' => 1, 'error' => 'No file uploaded.']);
            exit;
        }
        // Real HTTP upload only (prevents path spoofing).
        if (!is_uploaded_file($_FILES['SiteMap']['tmp_name'])) {
            echo json_encode(['status' => 1, 'error' => 'Invalid upload.']);
            exit;
        }
        // Server-side size gate — the client precheck is bypassable via curl.
        if (($_FILES['SiteMap']['size'] ?? 0) > 2 * 1024 * 1024) {
            echo json_encode(['status' => 1, 'error' => 'File too large (max 2 MB).']);
            exit;
        }
        $tmp = $_FILES['SiteMap']['tmp_name'];
        // Magic-byte check, not the browser-supplied MIME (trivially spoofed).
        $detectedType = exif_imagetype($tmp);
        if ($detectedType !== IMAGETYPE_JPEG && $detectedType !== IMAGETYPE_PNG) {
            echo json_encode(['status' => 1, 'error' => 'Only JPEG and PNG images are supported.']);
            exit;
        }
        // Dimensions from headers only — no GD decode, so no decompression
        // bomb. SMALLINT storage + Leaflet sanity both cap at 16000/edge.
        $dims = @getimagesize($tmp);
        if (!$dims || (int)$dims[0] < 1 || (int)$dims[1] < 1) {
            echo json_encode(['status' => 1, 'error' => 'Could not read image dimensions.']);
            exit;
        }
        if ((int)$dims[0] > 16000 || (int)$dims[1] > 16000 || (int)$dims[0] * (int)$dims[1] > 40000000) {
            echo json_encode(['status' => 1, 'error' => 'Image dimensions too large.']);
            exit;
        }

        $ext  = ($detectedType === IMAGETYPE_PNG) ? 'png' : 'jpg';
        if (!is_dir(DIR_SITEMAP)) {
            @mkdir(DIR_SITEMAP, 0775, true);
        }
        $base = DIR_SITEMAP . sprintf('%05d', $detail_id);
        // Land the new file under a temp name first so a failed move can
        // never destroy the existing map.
        $newPath = $base . '.new.' . $ext;
        if (!@move_uploaded_file($tmp, $newPath)) {
            echo json_encode(['status' => 1, 'error' => 'Could not save uploaded file.']);
            exit;
        }
        if (file_exists($base . '.jpg')) {
            @unlink($base . '.jpg');
        }
        if (file_exists($base . '.png')) {
            @unlink($base . '.png');
        }
        if (!@rename($newPath, $base . '.' . $ext)) {
            @unlink($newPath);
            echo json_encode(['status' => 1, 'error' => 'Could not save uploaded file.']);
            exit;
        }

        global $DB;
        $DB->Clear();
        $DB->Execute(
            'INSERT INTO ' . DB_PREFIX . 'event_site_map (event_calendardetail_id, ext, width, height, uploaded_by)
			VALUES (' . $detail_id . ", '" . $ext . "', " . (int)$dims[0] . ', ' . (int)$dims[1] . ', ' . (int)$this->session->user_id . ")
			ON DUPLICATE KEY UPDATE ext = VALUES(ext), width = VALUES(width), height = VALUES(height), uploaded_by = VALUES(uploaded_by)"
        );
        // Execute() is void and the Yapo layer can silently swallow failures
        // (sql_mode etc.) — verify the row landed before reporting success.
        $DB->Clear();
        $verify = $DB->DataSet('SELECT ext, width FROM ' . DB_PREFIX . 'event_site_map WHERE event_calendardetail_id = ' . $detail_id . ' LIMIT 1');
        if (!$verify || !$verify->Next() || (string)$verify->ext !== $ext || (int)$verify->width !== (int)$dims[0]) {
            @unlink($base . '.' . $ext);
            echo json_encode(['status' => 1, 'error' => 'Saved file but could not update the database. Please try again.']);
            exit;
        }

        echo json_encode(['status' => 0, 'map' => [
            'Url'    => HTTP_SITEMAP . sprintf('%05d', $detail_id) . '.' . $ext . '?v=' . filemtime($base . '.' . $ext),
            'Width'  => (int)$dims[0],
            'Height' => (int)$dims[1],
        ]]);
        exit;
    }
```

- [ ] **Step 2: Add `site_map_delete`**

```php
    public function site_map_delete($p = null)
    {
        header('Content-Type: application/json');
        if (!isset($this->session->user_id)) {
            echo json_encode(['status' => 5, 'error' => 'Not logged in']);
            exit;
        }

        $params    = explode('/', $p ?? '');
        $event_id  = (int)preg_replace('/[^0-9]/', '', $params[0] ?? '');
        $detail_id = (int)preg_replace('/[^0-9]/', '', $params[1] ?? '');
        if (!valid_id($event_id) || !valid_id($detail_id)) {
            echo json_encode(['status' => 1, 'error' => 'Invalid Event ID.']);
            exit;
        }
        if (!$this->_canManageSite($event_id, $detail_id)) {
            echo json_encode(['status' => 3, 'error' => 'Not authorized.']);
            exit;
        }

        global $DB;
        $DB->Clear();
        $DB->Execute('DELETE FROM ' . DB_PREFIX . 'event_site_map WHERE event_calendardetail_id = ' . $detail_id);
        // Pins are intentionally KEPT (fractional coords survive a future
        // re-upload); only the image row + files go.
        $base = DIR_SITEMAP . sprintf('%05d', $detail_id);
        if (file_exists($base . '.jpg')) {
            @unlink($base . '.jpg');
        }
        if (file_exists($base . '.png')) {
            @unlink($base . '.png');
        }
        echo json_encode(['status' => 0]);
        exit;
    }
```

- [ ] **Step 3: Lint + curl-test**

```bash
docker exec ork3-php8-app php -l /var/www/html/orkui/controller/controller.EventAjax.php
SCRATCH=/private/tmp/claude-501/-Users-averykrouse-GitHub-ORK-tobias-ORK3-tobias/15549047-8f6f-4fd0-9de4-42a0cd86ff00/scratchpad
# Make a valid ~1400x900 test JPEG inside the container, copy it out:
docker exec ork3-php8-app php -r '$im=imagecreatetruecolor(1400,900);imagefilledrectangle($im,0,0,1399,899,imagecolorallocate($im,200,220,180));imagestring($im,5,40,40,"TEST SITE MAP",imagecolorallocate($im,30,30,30));imagejpeg($im,"/tmp/sitemap-test.jpg",85);'
docker cp ork3-php8-app:/tmp/sitemap-test.jpg "$SCRATCH/sitemap-test.jpg"
# Oversize reject (3MB of noise in a jpg wrapper is unnecessary — size gate fires first):
mkfile -n 3m "$SCRATCH/big.jpg" 2>/dev/null || dd if=/dev/zero of="$SCRATCH/big.jpg" bs=1m count=3
curl -s -b "$JAR" -H 'X-Requested-With: XMLHttpRequest' -F "SiteMap=@$SCRATCH/big.jpg" "${BASE}EventAjax/site_map_upload/$EID/$DID"
# Expected: {"status":1,"error":"File too large (max 2 MB)."}
# Wrong type reject:
echo 'not an image' > "$SCRATCH/fake.jpg"
curl -s -b "$JAR" -H 'X-Requested-With: XMLHttpRequest' -F "SiteMap=@$SCRATCH/fake.jpg" "${BASE}EventAjax/site_map_upload/$EID/$DID"
# Expected: {"status":1,"error":"Only JPEG and PNG images are supported."}
# Success:
curl -s -b "$JAR" -H 'X-Requested-With: XMLHttpRequest' -F "SiteMap=@$SCRATCH/sitemap-test.jpg" "${BASE}EventAjax/site_map_upload/$EID/$DID"
# Expected: {"status":0,"map":{"Url":"...assets/sitemaps/000NN.jpg?v=...","Width":1400,"Height":900}}
# File served:
curl -s -o /dev/null -w '%{http_code}\n' "$(curl -s -b "$JAR" -F "SiteMap=@$SCRATCH/sitemap-test.jpg" "${BASE}EventAjax/site_map_upload/$EID/$DID" | php -r '$d=json_decode(stream_get_contents(STDIN),true);echo $d["map"]["Url"];' 2>/dev/null || echo retry-by-hand)"
# Expected: 200
# Delete:
curl -s -b "$JAR" -H 'X-Requested-With: XMLHttpRequest' -X POST "${BASE}EventAjax/site_map_delete/$EID/$DID"
docker exec ork3-php8-db mariadb -u root -proot ork -e "SELECT COUNT(*) FROM ork_event_site_map WHERE event_calendardetail_id = $DID"
# Expected: {"status":0} then COUNT 0
# Re-upload for later tasks' use:
curl -s -b "$JAR" -H 'X-Requested-With: XMLHttpRequest' -F "SiteMap=@$SCRATCH/sitemap-test.jpg" "${BASE}EventAjax/site_map_upload/$EID/$DID"
```

(If `php` is missing on the host for the "File served" one-liner, extract `map.Url` by eye and curl it directly.)

- [ ] **Step 4: Commit**

```bash
git add orkui/controller/controller.EventAjax.php
git diff --cached
git commit -m "Enhancement: site map upload/delete endpoints (2MB, jpg/png, bomb-guarded)"
```

---

### Task 5: `site_location_save` + `site_location_delete`

**Files:**
- Modify: `orkui/controller/controller.EventAjax.php` (append)

**Interfaces:**
- Consumes: `_canManageSite`, `_escSql` (Task 3); `event_site_location_categories()` (Task 2).
- Produces:
  - `POST EventAjax/site_location_save/{event_id}/{detail_id}` — fields `LocationId` (0/absent = insert), `Name` (required), `Category`, `Description`, `X`, `Y` (0–1 floats). Returns `{status:0, location:{LocationId,Name,Category,Description,X,Y}}`. On rename, syncs the denormalized `ork_event_schedule.location` text of linked rows.
  - `POST EventAjax/site_location_delete/{event_id}/{detail_id}` — field `LocationId`. Returns `{status:0}`. FK sets linked schedules' `site_location_id` NULL; free-text location is backfilled with the pin name where empty.

- [ ] **Step 1: Add `site_location_save`**

```php
    public function site_location_save($p = null)
    {
        header('Content-Type: application/json');
        if (!isset($this->session->user_id)) {
            echo json_encode(['status' => 5, 'error' => 'Not logged in']);
            exit;
        }

        $params    = explode('/', $p ?? '');
        $event_id  = (int)preg_replace('/[^0-9]/', '', $params[0] ?? '');
        $detail_id = (int)preg_replace('/[^0-9]/', '', $params[1] ?? '');
        if (!valid_id($event_id) || !valid_id($detail_id)) {
            echo json_encode(['status' => 1, 'error' => 'Invalid Event ID.']);
            exit;
        }
        if (!$this->_canManageSite($event_id, $detail_id)) {
            echo json_encode(['status' => 3, 'error' => 'Not authorized.']);
            exit;
        }

        require_once(DIR_LIB . 'ork3/eventsite-catalog.php');
        $loc_id   = (int)($_POST['LocationId'] ?? 0);
        $name     = mb_substr(trim($_POST['Name'] ?? ''), 0, 80);
        $category = trim($_POST['Category'] ?? 'other');
        $desc     = trim($_POST['Description'] ?? '');
        $x        = max(0.0, min(1.0, (float)($_POST['X'] ?? 0)));
        $y        = max(0.0, min(1.0, (float)($_POST['Y'] ?? 0)));
        if (!isset(event_site_location_categories()[$category])) {
            $category = 'other';
        }
        if ($name === '') {
            echo json_encode(['status' => 1, 'error' => 'A name is required.']);
            exit;
        }

        $name_safe = $this->_escSql($name);
        $cat_safe  = $this->_escSql($category);
        $desc_safe = $this->_escSql($desc);
        $x_sql     = sprintf('%.6F', $x);
        $y_sql     = sprintf('%.6F', $y);

        global $DB;
        if ($loc_id > 0) {
            $DB->Clear();
            $own = $DB->DataSet('SELECT 1 FROM ' . DB_PREFIX . 'event_site_location WHERE event_site_location_id = ' . $loc_id . ' AND event_calendardetail_id = ' . $detail_id . ' LIMIT 1');
            if (!($own && $own->Next())) {
                echo json_encode(['status' => 1, 'error' => 'Unknown location.']);
                exit;
            }
            $DB->Clear();
            $DB->Execute('UPDATE ' . DB_PREFIX . "event_site_location SET name = '" . $name_safe . "', category = '" . $cat_safe . "', description = '" . $desc_safe . "', x = " . $x_sql . ', y = ' . $y_sql . ' WHERE event_site_location_id = ' . $loc_id);
            // Keep the denormalized schedule location text in sync on rename.
            $DB->Clear();
            $DB->Execute('UPDATE ' . DB_PREFIX . "event_schedule SET location = '" . $name_safe . "' WHERE site_location_id = " . $loc_id);
        } else {
            $DB->Clear();
            $DB->Execute('INSERT INTO ' . DB_PREFIX . "event_site_location (event_calendardetail_id, name, category, description, x, y) VALUES (" . $detail_id . ", '" . $name_safe . "', '" . $cat_safe . "', '" . $desc_safe . "', " . $x_sql . ', ' . $y_sql . ')');
            // lastInsertId is unreliable here (see project memory) — read back.
            $DB->Clear();
            $idrow = $DB->DataSet('SELECT event_site_location_id FROM ' . DB_PREFIX . 'event_site_location WHERE event_calendardetail_id = ' . $detail_id . ' ORDER BY event_site_location_id DESC LIMIT 1');
            $loc_id = ($idrow && $idrow->Next()) ? (int)$idrow->event_site_location_id : 0;
            if ($loc_id === 0) {
                echo json_encode(['status' => 1, 'error' => 'Could not save the location. Please try again.']);
                exit;
            }
        }

        echo json_encode(['status' => 0, 'location' => [
            'LocationId'  => $loc_id,
            'Name'        => $name,
            'Category'    => $category,
            'Description' => $desc,
            'X'           => $x,
            'Y'           => $y,
        ]]);
        exit;
    }
```

- [ ] **Step 2: Add `site_location_delete`**

```php
    public function site_location_delete($p = null)
    {
        header('Content-Type: application/json');
        if (!isset($this->session->user_id)) {
            echo json_encode(['status' => 5, 'error' => 'Not logged in']);
            exit;
        }

        $params    = explode('/', $p ?? '');
        $event_id  = (int)preg_replace('/[^0-9]/', '', $params[0] ?? '');
        $detail_id = (int)preg_replace('/[^0-9]/', '', $params[1] ?? '');
        $loc_id    = (int)($_POST['LocationId'] ?? 0);
        if (!valid_id($event_id) || !valid_id($detail_id) || !valid_id($loc_id)) {
            echo json_encode(['status' => 1, 'error' => 'Invalid parameters.']);
            exit;
        }
        if (!$this->_canManageSite($event_id, $detail_id)) {
            echo json_encode(['status' => 3, 'error' => 'Not authorized.']);
            exit;
        }

        global $DB;
        $DB->Clear();
        $own = $DB->DataSet('SELECT name FROM ' . DB_PREFIX . 'event_site_location WHERE event_site_location_id = ' . $loc_id . ' AND event_calendardetail_id = ' . $detail_id . ' LIMIT 1');
        if (!($own && $own->Next())) {
            echo json_encode(['status' => 1, 'error' => 'Unknown location.']);
            exit;
        }
        $name_safe = $this->_escSql((string)$own->name);

        // Graceful degradation: make sure every linked schedule row keeps a
        // readable location string before the FK nulls the link.
        $DB->Clear();
        $DB->Execute('UPDATE ' . DB_PREFIX . "event_schedule SET location = '" . $name_safe . "' WHERE site_location_id = " . $loc_id . " AND location = ''");
        $DB->Clear();
        $DB->Execute('DELETE FROM ' . DB_PREFIX . 'event_site_location WHERE event_site_location_id = ' . $loc_id);

        echo json_encode(['status' => 0]);
        exit;
    }
```

- [ ] **Step 3: Lint + curl-test**

```bash
docker exec ork3-php8-app php -l /var/www/html/orkui/controller/controller.EventAjax.php
# Insert (coords deliberately out of range to confirm the clamp):
curl -s -b "$JAR" -H 'X-Requested-With: XMLHttpRequest' \
  -d 'LocationId=0&Name=Feast Hall&Category=feast&Description=Dinner here&X=1.7&Y=0.42' \
  "${BASE}EventAjax/site_location_save/$EID/$DID"
# Expected: {"status":0,"location":{"LocationId":N,"Name":"Feast Hall","Category":"feast",...,"X":1,"Y":0.42}}
# Bad category coerces to 'other'; missing name rejects:
curl -s -b "$JAR" -H 'X-Requested-With: XMLHttpRequest' -d 'LocationId=0&Name=Mystery&Category=lava&X=0.5&Y=0.5' "${BASE}EventAjax/site_location_save/$EID/$DID"
# Expected: "Category":"other"
curl -s -b "$JAR" -H 'X-Requested-With: XMLHttpRequest' -d 'LocationId=0&Name=&Category=other&X=0.1&Y=0.1' "${BASE}EventAjax/site_location_save/$EID/$DID"
# Expected: {"status":1,"error":"A name is required."}
# Update/rename (use LocationId N from the first call):
curl -s -b "$JAR" -H 'X-Requested-With: XMLHttpRequest' -d "LocationId=$LOC&Name=Great Hall&Category=feast&X=0.3&Y=0.42" "${BASE}EventAjax/site_location_save/$EID/$DID"
# Expected: {"status":0,...,"Name":"Great Hall"}
# Foreign-location reject: use a LocationId that belongs to a different detail
# Expected: {"status":1,"error":"Unknown location."}
# Delete:
curl -s -b "$JAR" -H 'X-Requested-With: XMLHttpRequest' -d "LocationId=$LOC" "${BASE}EventAjax/site_location_delete/$EID/$DID"
docker exec ork3-php8-db mariadb -u root -proot ork -e "SELECT COUNT(*) FROM ork_event_site_location WHERE event_site_location_id = $LOC"
# Expected: {"status":0} then 0. (Schedule linkage degradation is tested end-to-end in Task 6.)
# Leave 2-3 locations saved for later tasks.
```

- [ ] **Step 4: Commit**

```bash
git add orkui/controller/controller.EventAjax.php
git diff --cached
git commit -m "Enhancement: site location save/delete endpoints with schedule text sync"
```

---

### Task 6: Schedule endpoints accept `SiteLocationId`

**Files:**
- Modify: `orkui/controller/controller.EventAjax.php` — `add_schedule` (L773-929) and `update_schedule` (L982+, mirror the add changes in its UPDATE statement and response)
- Modify: `orkui/controller/controller.Event.php` — ScheduleList query (L750-758) + row array (L763-776)

**Interfaces:**
- Consumes: `ork_event_site_location` rows (Task 5).
- Produces: `add_schedule`/`update_schedule` accept optional int field `SiteLocationId`; when it names a pin of the same detail, the row links it AND `location` free text is set to the pin name if the posted text was empty; when invalid/0, the link is NULL and free text passes through. JSON responses gain `'SiteLocationId' => int|null`. `ScheduleList` rows gain `'SiteLocationId' => int|null` (consumed by Tasks 7, 10).

- [ ] **Step 1: `add_schedule` — accept + validate the field**

After L810 (`$location = trim($_POST['Location'] ?? '');`) add:

```php
        $site_location_id = (int)($_POST['SiteLocationId'] ?? 0);
```

After the auth/validation block, immediately before the `$title_safe = ...` escaping block (L870), add:

```php
        // Optional link to a tagged site-map location. Must belong to this
        // same occurrence; anything else silently degrades to free text.
        if ($site_location_id > 0) {
            global $DB;
            $DB->Clear();
            $slRow = $DB->DataSet('SELECT name FROM ' . DB_PREFIX . 'event_site_location WHERE event_site_location_id = ' . $site_location_id . ' AND event_calendardetail_id = ' . $detail_id . ' LIMIT 1');
            if ($slRow && $slRow->Next()) {
                if ($location === '') {
                    $location = (string)$slRow->name;
                }
            } else {
                $site_location_id = 0;
            }
        }
```

- [ ] **Step 2: `add_schedule` — write + echo it**

In the INSERT (L887-891): add `site_location_id` to the column list after `allergens`, and append the value expression `', ' . ($site_location_id > 0 ? $site_location_id : 'NULL') . '`' before the closing paren:

```php
        $DB->Execute(
            'INSERT INTO ' . DB_PREFIX . 'event_schedule
			(event_calendardetail_id, title, start_time, end_time, location, description, category, secondary_category, menu, cost, dietary, allergens, site_location_id)
			VALUES (' . $detail_id . ', \'' . $title_safe . '\', \'' . $start_fmt . '\', \'' . $end_fmt . '\', \'' . $location_safe . '\', \'' . $description_safe . '\', \'' . $category_safe . '\', \'' . $secondary_category_safe . '\', ' . $menu_sql . ', ' . $cost_sql . ', ' . $dietary_sql . ', ' . $allergens_sql . ', ' . ($site_location_id > 0 ? $site_location_id : 'NULL') . ')'
        );
```

In the response array (after `'Location' => $location,` L918) add:

```php
            'SiteLocationId'    => $site_location_id > 0 ? $site_location_id : null,
```

- [ ] **Step 3: `update_schedule` — same three changes**

Read `update_schedule` in full first (starts L982; same structure as `add_schedule`: gates → field reads → validation → escaping → UPDATE → response). Then:

(a) Next to its `$location = trim($_POST['Location'] ?? '');` line add:

```php
        $site_location_id = (int)($_POST['SiteLocationId'] ?? 0);
```

(b) Immediately before its escaping block (`$title_safe = ...`), add the same validation block as `add_schedule`:

```php
        // Optional link to a tagged site-map location. Must belong to this
        // same occurrence; anything else silently degrades to free text.
        if ($site_location_id > 0) {
            global $DB;
            $DB->Clear();
            $slRow = $DB->DataSet('SELECT name FROM ' . DB_PREFIX . 'event_site_location WHERE event_site_location_id = ' . $site_location_id . ' AND event_calendardetail_id = ' . $detail_id . ' LIMIT 1');
            if ($slRow && $slRow->Next()) {
                if ($location === '') {
                    $location = (string)$slRow->name;
                }
            } else {
                $site_location_id = 0;
            }
        }
```

(c) In its UPDATE statement's SET list, after the `allergens = ...` assignment add:

```php
			site_location_id = ' . ($site_location_id > 0 ? $site_location_id : 'NULL') . ',
```

(exact string-concatenation style must match the statement it lands in — read it and splice accordingly; the WHERE clause scoping by `event_schedule_id` AND `event_calendardetail_id` stays untouched).

(d) In its JSON response array, after `'Location' => $location,` add:

```php
            'SiteLocationId'    => $site_location_id > 0 ? $site_location_id : null,
```

- [ ] **Step 4: Controller ScheduleList carries the link**

In `orkui/controller/controller.Event.php` L750-758, add `site_location_id AS SiteLocationId,` to the SELECT (after `location AS Location,`), and in the row array (after `'Location' => ...` L768):

```php
                    'SiteLocationId'    => $scheduleRows->SiteLocationId !== null ? (int)$scheduleRows->SiteLocationId : null,
```

- [ ] **Step 5: Lint + curl-test the round trip**

```bash
docker exec ork3-php8-app php -l /var/www/html/orkui/controller/controller.EventAjax.php
docker exec ork3-php8-app php -l /var/www/html/orkui/controller/controller.Event.php
# $LOC = an existing location id from Task 5. Empty Location text → name copied:
curl -s -b "$JAR" -H 'X-Requested-With: XMLHttpRequest' \
  -d "Title=Feast&StartTime=2026-08-01 18:00&EndTime=2026-08-01 20:00&Location=&SiteLocationId=$LOC&Category=Feast and Food" \
  "${BASE}EventAjax/add_schedule/$EID/$DID"
# Expected: {"status":0,"schedule":{...,"Location":"<pin name>","SiteLocationId":$LOC,...}}
# Foreign/bogus id degrades silently:
curl -s -b "$JAR" -H 'X-Requested-With: XMLHttpRequest' \
  -d 'Title=Court&StartTime=2026-08-01 20:00&EndTime=2026-08-01 21:00&Location=Under the oak&SiteLocationId=999999&Category=Court' \
  "${BASE}EventAjax/add_schedule/$EID/$DID"
# Expected: "SiteLocationId":null, "Location":"Under the oak"
# Pin-delete degradation end-to-end: delete $LOC via site_location_delete, then:
docker exec ork3-php8-db mariadb -u root -proot ork -e "SELECT title, location, site_location_id FROM ork_event_schedule WHERE event_calendardetail_id = $DID ORDER BY event_schedule_id DESC LIMIT 2"
# Expected: Feast row shows location='<pin name>' and site_location_id=NULL
# Re-create a location + linked schedule row for the UI tasks.
```

- [ ] **Step 6: Commit**

```bash
git add orkui/controller/controller.EventAjax.php orkui/controller/controller.Event.php
git diff --cached
git commit -m "Enhancement: schedule items link to tagged site locations"
```

---

### Task 7: Controller data load + template plumbing (Site tab shell)

**Files:**
- Modify: `orkui/controller/controller.Event.php` — `CanManageSite` after L688; site-data block after the MealList derivation (~L854)
- Modify: `orkui/template/revised-frontend/Eventnew_index.tpl` — locals (~L153), Leaflet include (~L175), tab gate (L872), tab nav (L1064-1068), Map panel → Site panel (L1917-1948), EvConfig (L2389-2420)

**Interfaces:**
- Consumes: tables + constants (Task 1), catalogs (Task 2), `ScheduleList[].SiteLocationId` (Task 6).
- Produces (consumed by Tasks 8–10):
  - `$this->data['SiteRules']` (rows as `_loadSiteRules`), `$this->data['SiteLocations']` (`[{LocationId,Name,Category,Description,X,Y}]`), `$this->data['SiteMap']` (`{Url,Width,Height}` or `null`), `$this->data['CanManageSite']` (bool).
  - Template locals: `$siteRules, $siteLocations, $siteMap, $canManageSite, $siteRuleCatalog, $siteLocCategories, $hasSiteTab`.
  - Tab `li` with `data-tab="ev-tab-site"`; panel `<div class="ev-tab-panel" id="ev-tab-site">` containing three placeholder sections with stable ids: `#ev-site-rules-section`, `#ev-site-map-section`, `#ev-site-directions-section` (directions = the moved Google map, fully working after this task).
  - `EvConfig` keys: `canManageSite` (bool), `siteMap` (object|null), `siteLocations` (array), `siteLocCategories` (object), `siteRuleCatalog` (object).

- [ ] **Step 1: Controller — permission flag + data block**

After L688 (`CanManageFeast` line) add:

```php
        $this->data['CanManageSite'] = $this->data['CanManageEvent'];
```

After the MealList line (L854, `$this->data['MealList'] = ...`) add:

```php
        // ---- Site Details: rules, tagged locations, uploaded site map ----
        $DB->Clear();
        $siteRuleRows = $DB->DataSet(
            'SELECT event_site_rule_id AS RuleId, rule_key AS RuleKey, value AS Value, title AS Title, details AS Details, sort_order AS SortOrder
			FROM ' . DB_PREFIX . 'event_site_rule
			WHERE event_calendardetail_id = ' . $detail_id . '
			ORDER BY sort_order, event_site_rule_id'
        );
        $siteRules = [];
        if ($siteRuleRows) {
            while ($siteRuleRows->Next()) {
                $siteRules[] = [
                    'RuleId'    => (int)$siteRuleRows->RuleId,
                    'RuleKey'   => $siteRuleRows->RuleKey !== null ? (string)$siteRuleRows->RuleKey : null,
                    'Value'     => (string)($siteRuleRows->Value ?? ''),
                    'Title'     => (string)($siteRuleRows->Title ?? ''),
                    'Details'   => (string)($siteRuleRows->Details ?? ''),
                    'SortOrder' => (int)$siteRuleRows->SortOrder,
                ];
            }
        }
        $this->data['SiteRules'] = $siteRules;

        $DB->Clear();
        $siteLocRows = $DB->DataSet(
            'SELECT event_site_location_id AS LocationId, name AS Name, category AS Category, description AS Description, x AS X, y AS Y
			FROM ' . DB_PREFIX . 'event_site_location
			WHERE event_calendardetail_id = ' . $detail_id . '
			ORDER BY sort_order, name'
        );
        $siteLocations = [];
        if ($siteLocRows) {
            while ($siteLocRows->Next()) {
                $siteLocations[] = [
                    'LocationId'  => (int)$siteLocRows->LocationId,
                    'Name'        => (string)$siteLocRows->Name,
                    'Category'    => (string)$siteLocRows->Category,
                    'Description' => (string)($siteLocRows->Description ?? ''),
                    'X'           => (float)$siteLocRows->X,
                    'Y'           => (float)$siteLocRows->Y,
                ];
            }
        }
        $this->data['SiteLocations'] = $siteLocations;

        $siteMap = null;
        $DB->Clear();
        $siteMapRow = $DB->DataSet('SELECT ext, width, height FROM ' . DB_PREFIX . 'event_site_map WHERE event_calendardetail_id = ' . $detail_id . ' LIMIT 1');
        if ($siteMapRow && $siteMapRow->Next()) {
            $smFile = sprintf('%05d', $detail_id) . '.' . $siteMapRow->ext;
            if (file_exists(DIR_SITEMAP . $smFile)) {
                $siteMap = [
                    'Url'    => HTTP_SITEMAP . $smFile . '?v=' . filemtime(DIR_SITEMAP . $smFile),
                    'Width'  => (int)$siteMapRow->width,
                    'Height' => (int)$siteMapRow->height,
                ];
            }
        }
        $this->data['SiteMap'] = $siteMap;
```

- [ ] **Step 2: Template locals + Leaflet include**

In `Eventnew_index.tpl` after L151 (`$canManageFeast = ...`) add:

```php
	$canManageSite = $CanManageSite ?? false;
	$siteRules     = $SiteRules     ?? [];
	$siteLocations = $SiteLocations ?? [];
	$siteMap       = $SiteMap       ?? null;
	require_once(DIR_LIB . 'ork3/eventsite-catalog.php');
	$siteRuleCatalog   = event_site_rule_catalog();
	$siteLocCategories = event_site_location_categories();
```

After the `revised.css` `<link>` (L175) add:

```php
<?php if (!empty($siteMap) || $canManageSite): ?>
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css">
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" defer></script>
<?php endif; ?>
```

- [ ] **Step 3: Tab gate + nav**

Replace L872:

```php
	<?php $hasMapTab = (bool)($locationDisplay ?: $locationFallback); ?>
```

with:

```php
	<?php
		$hasMapTab  = (bool)($locationDisplay ?: $locationFallback);
		$hasSiteTab = $hasMapTab || !empty($siteRules) || !empty($siteMap) || $canManageSite;
	?>
```

(Leave the two OTHER `$hasMapTab` usages — L880/L882, the Details-tab address card — untouched.)

Replace the Map tab `li` (L1064-1068):

```php
				<?php if ($hasSiteTab): ?>
				<li data-tab="ev-tab-site" onclick="evShowTab(this,'ev-tab-site')">
					<i class="fas fa-map-marked-alt"></i><span class="ev-tab-label"> Site</span>
				</li>
				<?php endif; ?>
```

- [ ] **Step 4: Replace the Map panel with the Site panel shell**

Replace the whole block L1917-1948 (`<?php if ($hasMapTab): ?>` through `<?php endif; ?>` after the map panel div):

```php
			<?php if ($hasSiteTab): ?>
			<?php // ---- Site Tab: rules + site map + directions ---- ?>
			<div class="ev-tab-panel" id="ev-tab-site">

				<div id="ev-site-rules-section">
					<?php /* Filled in by the Site Rules task */ ?>
				</div>

				<div id="ev-site-map-section">
					<?php /* Filled in by the Site Map task */ ?>
				</div>

				<?php if ($hasMapTab): ?>
				<?php
					$mapOpenUrl  = $mapLink ?: null;
					$mapQuery    = urlencode($mapQueryAddress);
					if ($mapLink && strpos($mapLink, 'q=@') !== false) {
						// lat/lng link — strip @ for embed (Google Maps embed doesn't accept @)
						$mapEmbedUrl = str_replace('?q=@', '?q=', $mapLink) . '&output=embed&z=14';
					} else {
						$mapEmbedUrl = 'https://maps.google.com/maps?q=' . $mapQuery . '&output=embed';
					}
					if (!$mapOpenUrl) $mapOpenUrl = 'https://maps.google.com/maps?q=' . $mapQuery;
				?>
				<div id="ev-site-directions-section">
					<div class="ev-site-section-head">
						<h3 class="ev-site-section-title"><i class="fas fa-directions"></i> Getting There</h3>
						<a href="<?= htmlspecialchars($mapOpenUrl) ?>" target="_blank" class="pk-btn pk-btn-secondary" style="font-size:13px;padding:6px 14px;text-decoration:none">
							<i class="fas fa-external-link-alt" style="margin-right:6px"></i>Open in Maps
						</a>
					</div>
					<div style="width:100%;border-radius:8px;overflow:hidden;border:1px solid #e2e8f0">
						<iframe
							src="<?= htmlspecialchars($mapEmbedUrl) ?>"
							width="100%"
							height="400"
							style="border:0;display:block"
							allowfullscreen=""
							loading="lazy"
							referrerpolicy="no-referrer-when-downgrade"
						></iframe>
					</div>
				</div>
				<?php endif; ?>

			</div><!-- /.ev-tab-panel (site) -->
			<?php endif; ?>
```

Section-head CSS (add inside the page's existing `<style>` block — find it with `grep -n '^<style>' Eventnew_index.tpl`):

```css
.ev-site-section-head { display:flex; align-items:center; justify-content:space-between; gap:10px; margin:18px 0 10px; }
#ev-tab-site .ev-site-section-title { background:none; border:none; padding:0; border-radius:0; margin:0; font-size:16px; font-weight:700; color:#2d3748; }
#ev-tab-site .ev-site-section-title i { margin-right:7px; color:#4a5568; }
html[data-theme="dark"] #ev-tab-site .ev-site-section-title { color:#e2e8f0; }
html[data-theme="dark"] #ev-tab-site .ev-site-section-title i { color:#a0aec0; }
```

(The explicit `background/border/padding/border-radius` reset on the `h3` is required — global heading rules in orkui.css add a gray pill box otherwise.)

- [ ] **Step 5: EvConfig keys**

In the `EvConfig` object (before the closing `};` at L2420) add:

```php
	canManageSite:     <?= !empty($canManageSite) ? 'true' : 'false' ?>,
	siteMap:           <?= json_encode($siteMap) ?>,
	siteLocations:     <?= json_encode($siteLocations) ?>,
	siteLocCategories: <?= json_encode($siteLocCategories) ?>,
	siteRuleCatalog:   <?= json_encode($siteRuleCatalog) ?>,
```

- [ ] **Step 6: Verify the page renders**

```bash
docker exec ork3-php8-app php -l /var/www/html/orkui/controller/controller.Event.php
curl -s -b "$JAR" "${BASE}Event/detail/$EID/$DID" | grep -c 'ev-tab-site\|siteLocCategories\|Getting There'
```

Expected: ≥3 (tab li + panel + EvConfig + directions header). Then load `http://localhost:19080/orkui/index.php?Route=Event/detail/$EID/$DID` in a browser: the Site tab must appear where Map was, and the Google map must render at the bottom of its panel. No JS console errors.

- [ ] **Step 7: Commit**

```bash
git add orkui/controller/controller.Event.php orkui/template/revised-frontend/Eventnew_index.tpl
git diff --cached
git commit -m "Enhancement: Site tab shell replaces Map tab; site data plumbed to page + EvConfig"
```

---

### Task 8: Site Rules UI (display + edit modal)

**Files:**
- Modify: `orkui/template/revised-frontend/Eventnew_index.tpl` — fill `#ev-site-rules-section`; add the rules modal after the schedule modal (find its end: `grep -n 'ev-schedule-modal' Eventnew_index.tpl`, the modal's closing `</div>` ~L2866); add CSS to the page `<style>` block; add a JS IIFE near the page's other script blocks at the end of the file.

**Interfaces:**
- Consumes: `$siteRules`, `$siteRuleCatalog`, `$canManageSite`, `EvConfig.siteRuleCatalog`, `POST site_rules_save` (Task 3).
- Produces: globals `window.evOpenSiteRulesModal()`, `window.evCloseSiteRulesModal()`; display container `#ev-site-rules-display` re-rendered from JS after save. Rules modal id: `#ev-site-rules-modal`.

- [ ] **Step 1: Rules display markup (inside `#ev-site-rules-section`)**

Replace the placeholder comment from Task 7 with:

```php
					<?php if (!empty($siteRules) || $canManageSite): ?>
					<div class="ev-site-section-head">
						<h3 class="ev-site-section-title"><i class="fas fa-clipboard-check"></i> Site Rules</h3>
						<?php if ($canManageSite): ?>
						<button type="button" class="pk-btn pk-btn-secondary" style="font-size:13px;padding:6px 14px" onclick="evOpenSiteRulesModal()">
							<i class="fas fa-pencil-alt" style="margin-right:6px"></i>Edit Rules
						</button>
						<?php endif; ?>
					</div>
					<div id="ev-site-rules-display">
						<?php if (empty($siteRules) && $canManageSite): ?>
						<div class="ev-site-cta" onclick="evOpenSiteRulesModal()">
							<i class="fas fa-plus-circle"></i> Add site rules — smoking, alcohol, pets, fires, and more
						</div>
						<?php endif; ?>
						<?php if (!empty($siteRules)): ?>
						<div class="ev-site-pills">
							<?php foreach ($siteRules as $r): if ($r['RuleKey'] === null || !isset($siteRuleCatalog[$r['RuleKey']])) continue;
								$cat = $siteRuleCatalog[$r['RuleKey']];
								$val = $cat['values'][$r['Value']] ?? null; if (!$val) continue; ?>
							<span class="ev-site-pill ev-site-pill-<?= $val['severity'] ?>"<?= $r['Details'] !== '' ? ' data-tip="' . htmlspecialchars($r['Details'], ENT_QUOTES) . '"' : '' ?>>
								<i class="fas <?= $cat['icon'] ?>"></i>
								<strong><?= htmlspecialchars($cat['label']) ?>:</strong>&nbsp;<?= htmlspecialchars($val['label']) ?>
								<?php if ($r['Details'] !== ''): ?><i class="fas fa-info-circle ev-site-pill-info"></i><?php endif; ?>
							</span>
							<?php endforeach; ?>
						</div>
						<?php $customRules = array_values(array_filter($siteRules, fn ($r) => $r['RuleKey'] === null)); ?>
						<?php if (!empty($customRules)): ?>
						<ul class="ev-site-custom-rules">
							<?php foreach ($customRules as $r): ?>
							<li>
								<strong><?= htmlspecialchars($r['Title']) ?></strong>
								<?php if ($r['Details'] !== ''): ?><span class="ev-site-custom-detail"><?= htmlspecialchars($r['Details']) ?></span><?php endif; ?>
							</li>
							<?php endforeach; ?>
						</ul>
						<?php endif; ?>
						<?php endif; ?>
					</div>
					<?php endif; ?>
```

- [ ] **Step 2: Rules modal markup**

After the schedule modal's closing `</div>` (the `<!-- /Schedule Modal -->`-adjacent one — verify visually), gated on manager:

```php
<?php if ($canManageSite): ?>
<!-- Site Rules Modal -->
<div class="ev-modal-overlay" id="ev-site-rules-modal">
	<div class="ev-modal" style="max-width:640px">
		<div class="ev-modal-header">
			<h3><i class="fas fa-clipboard-check" style="margin-right:8px"></i>Edit Site Rules</h3>
			<button class="ev-modal-close" type="button" onclick="evCloseSiteRulesModal()">&times;</button>
		</div>
		<div class="ev-modal-body">
			<div id="ev-site-rules-groups">
				<?php foreach ($siteRuleCatalog as $key => $cat): ?>
				<div class="ev-site-rule-group" data-rule-key="<?= $key ?>">
					<div class="ev-site-rule-group-label"><i class="fas <?= $cat['icon'] ?>"></i> <?= htmlspecialchars($cat['label']) ?></div>
					<div class="ev-site-rule-options">
						<?php foreach ($cat['values'] as $vkey => $v): ?>
						<button type="button" class="ev-site-opt" data-value="<?= $vkey ?>"><?= htmlspecialchars($v['label']) ?></button>
						<?php endforeach; ?>
					</div>
					<input type="text" class="ev-site-rule-details" placeholder="Optional details (times, areas, exceptions)..." style="display:none;width:100%;margin-top:6px">
				</div>
				<?php endforeach; ?>
			</div>
			<div style="border-top:1px solid #e2e8f0;margin-top:14px;padding-top:12px">
				<div class="ev-site-rule-group-label" style="margin-bottom:8px"><i class="fas fa-plus"></i> Custom Rules</div>
				<div id="ev-site-custom-list"></div>
				<button type="button" class="pk-btn pk-btn-secondary" style="font-size:12px;padding:5px 12px" onclick="evSiteAddCustomRow('','')">
					<i class="fas fa-plus" style="margin-right:5px"></i>Add custom rule
				</button>
			</div>
			<div class="ev-modal-error" id="ev-site-rules-error" style="display:none"></div>
		</div>
		<div class="ev-modal-footer">
			<button class="ev-btn ev-btn-outline" type="button" onclick="evCloseSiteRulesModal()" style="margin-right:auto">Cancel</button>
			<button class="ev-submit-btn" type="button" id="ev-site-rules-save-btn" onclick="evSubmitSiteRules()">
				<i class="fas fa-save"></i> <span>Save Rules</span>
			</button>
		</div>
	</div>
</div>
<?php endif; ?>
```

- [ ] **Step 3: CSS (page `<style>` block)**

```css
/* Site rules pills */
.ev-site-pills { display:flex; flex-wrap:wrap; gap:8px; margin-bottom:10px; }
.ev-site-pill { display:inline-flex; align-items:center; gap:5px; padding:5px 12px; border-radius:999px; font-size:13px; border:1px solid; }
.ev-site-pill i { font-size:12px; }
.ev-site-pill-restrictive { background:#fff5f5; border-color:#feb2b2; color:#c53030; }
.ev-site-pill-neutral     { background:#f7fafc; border-color:#cbd5e0; color:#4a5568; }
.ev-site-pill-permissive  { background:#f0fff4; border-color:#9ae6b4; color:#276749; }
.ev-site-pill-info { opacity:.6; font-size:11px; }
.ev-site-custom-rules { margin:6px 0 0; padding-left:20px; }
.ev-site-custom-rules li { margin-bottom:5px; font-size:14px; color:#2d3748; }
.ev-site-custom-detail { display:block; font-size:12.5px; color:#718096; }
.ev-site-cta { border:2px dashed #cbd5e0; border-radius:8px; padding:16px; text-align:center; color:#718096; cursor:pointer; font-size:14px; }
.ev-site-cta:hover { border-color:#a0aec0; color:#4a5568; }
/* Rules modal */
.ev-site-rule-group { margin-bottom:12px; }
.ev-site-rule-group-label { font-size:12px; font-weight:700; text-transform:uppercase; letter-spacing:.05em; color:#4a5568; margin-bottom:5px; }
.ev-site-rule-group-label i { margin-right:4px; }
.ev-site-rule-options { display:flex; flex-wrap:wrap; gap:6px; }
.ev-site-opt { border:1px solid #cbd5e0; background:#fff; border-radius:999px; padding:4px 12px; font-size:12.5px; color:#4a5568; cursor:pointer; }
.ev-site-opt.ev-site-opt-on { background:#2c5282; border-color:#2c5282; color:#fff; }
.ev-site-custom-row { display:flex; gap:6px; margin-bottom:6px; align-items:flex-start; }
.ev-site-custom-row input { flex:1; }
.ev-site-custom-row .ev-site-custom-del { background:none; border:none; color:#e53e3e; cursor:pointer; font-size:16px; padding:4px; }
/* Dark mode */
html[data-theme="dark"] .ev-site-pill-restrictive { background:#3b1f1f; border-color:#822727; color:#feb2b2; }
html[data-theme="dark"] .ev-site-pill-neutral     { background:#2d3748; border-color:#4a5568; color:#cbd5e0; }
html[data-theme="dark"] .ev-site-pill-permissive  { background:#1c2f24; border-color:#276749; color:#9ae6b4; }
html[data-theme="dark"] .ev-site-custom-rules li { color:#e2e8f0; }
html[data-theme="dark"] .ev-site-custom-detail { color:#a0aec0; }
html[data-theme="dark"] .ev-site-cta { border-color:#4a5568; color:#a0aec0; }
html[data-theme="dark"] .ev-site-rule-group-label { color:#a0aec0; }
html[data-theme="dark"] .ev-site-opt { background:#2d3748; border-color:#4a5568; color:#cbd5e0; }
html[data-theme="dark"] .ev-site-opt.ev-site-opt-on { background:#3182ce; border-color:#3182ce; color:#fff; }
```

- [ ] **Step 4: JS IIFE**

Add a `<script>` IIFE near the page's other end-of-file script blocks. Gate on `EvConfig.canManageSite` (a config flag — NEVER on `getElementById`, the script may sit above later modal HTML):

```html
<script>
(function() {
	'use strict';
	if (!window.EvConfig || !EvConfig.canManageSite) return;
	function gid(id) { return document.getElementById(id); }

	// Current rules state, keyed for the modal. Seeded from the server render.
	var siteRules = <?= json_encode($siteRules) ?>;

	window.evOpenSiteRulesModal = function() {
		// Reset all groups to current saved state.
		document.querySelectorAll('#ev-site-rules-groups .ev-site-rule-group').forEach(function(g) {
			var key = g.getAttribute('data-rule-key');
			var saved = siteRules.find(function(r) { return r.RuleKey === key; });
			var details = g.querySelector('.ev-site-rule-details');
			g.querySelectorAll('.ev-site-opt').forEach(function(b) {
				b.classList.toggle('ev-site-opt-on', !!saved && b.getAttribute('data-value') === saved.Value);
			});
			details.value = saved ? (saved.Details || '') : '';
			details.style.display = saved ? '' : 'none';
		});
		gid('ev-site-custom-list').innerHTML = '';
		siteRules.filter(function(r) { return r.RuleKey === null; }).forEach(function(r) {
			evSiteAddCustomRow(r.Title, r.Details || '');
		});
		gid('ev-site-rules-error').style.display = 'none';
		gid('ev-site-rules-modal').classList.add('ev-modal-open');
	};
	window.evCloseSiteRulesModal = function() {
		gid('ev-site-rules-modal').classList.remove('ev-modal-open');
	};

	// Single-choice per group; tapping the active pill clears it.
	document.querySelectorAll('#ev-site-rules-groups .ev-site-rule-group').forEach(function(g) {
		var details = g.querySelector('.ev-site-rule-details');
		g.querySelectorAll('.ev-site-opt').forEach(function(b) {
			b.addEventListener('click', function() {
				var wasOn = b.classList.contains('ev-site-opt-on');
				g.querySelectorAll('.ev-site-opt').forEach(function(o) { o.classList.remove('ev-site-opt-on'); });
				if (!wasOn) b.classList.add('ev-site-opt-on');
				details.style.display = wasOn ? 'none' : '';
				if (wasOn) details.value = '';
			});
		});
	});

	window.evSiteAddCustomRow = function(title, details) {
		var row = document.createElement('div');
		row.className = 'ev-site-custom-row';
		row.innerHTML = '<input type="text" class="ev-site-custom-title" placeholder="Rule (e.g. No glass containers)" maxlength="120">' +
			'<input type="text" class="ev-site-custom-details" placeholder="Details (optional)">' +
			'<button type="button" class="ev-site-custom-del" data-tip="Remove">&times;</button>';
		row.querySelector('.ev-site-custom-title').value = title || '';
		row.querySelector('.ev-site-custom-details').value = details || '';
		row.querySelector('.ev-site-custom-del').addEventListener('click', function() { row.remove(); });
		gid('ev-site-custom-list').appendChild(row);
	};

	window.evSubmitSiteRules = function() {
		var out = [];
		document.querySelectorAll('#ev-site-rules-groups .ev-site-rule-group').forEach(function(g) {
			var on = g.querySelector('.ev-site-opt-on');
			if (on) out.push({
				RuleKey: g.getAttribute('data-rule-key'),
				Value:   on.getAttribute('data-value'),
				Details: g.querySelector('.ev-site-rule-details').value.trim()
			});
		});
		document.querySelectorAll('#ev-site-custom-list .ev-site-custom-row').forEach(function(row) {
			var t = row.querySelector('.ev-site-custom-title').value.trim();
			if (t) out.push({ Title: t, Details: row.querySelector('.ev-site-custom-details').value.trim() });
		});

		var btn = gid('ev-site-rules-save-btn');
		var orig = btn.innerHTML;
		btn.disabled = true;
		btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Saving…';
		var fd = new FormData();
		fd.append('Rules', JSON.stringify(out));
		fetch(EvConfig.uir + 'EventAjax/site_rules_save/' + EvConfig.eventId + '/' + EvConfig.detailId, {
			method: 'POST', body: fd,
			headers: { 'X-Requested-With': 'XMLHttpRequest' }
		})
		.then(function(r) { return r.json(); })
		.then(function(data) {
			if (data.status === 0) {
				siteRules = data.rules;
				evSiteRenderRules();
				evCloseSiteRulesModal();
			} else {
				var err = gid('ev-site-rules-error');
				err.textContent = data.error || 'Could not save rules.';
				err.style.display = 'block';
			}
		})
		.catch(function() {
			var err = gid('ev-site-rules-error');
			err.textContent = 'Network error — please try again.';
			err.style.display = 'block';
		})
		.finally(function() { btn.disabled = false; btn.innerHTML = orig; });
	};

	function escH(s) {
		return String(s == null ? '' : s).replace(/[&<>"']/g, function(c) {
			return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
		});
	}

	// Re-render the public display from state (mirrors the PHP render).
	window.evSiteRenderRules = function() {
		var cat = EvConfig.siteRuleCatalog;
		var pills = '', customs = '';
		siteRules.forEach(function(r) {
			if (r.RuleKey !== null && cat[r.RuleKey] && cat[r.RuleKey].values[r.Value]) {
				var c = cat[r.RuleKey], v = c.values[r.Value];
				pills += '<span class="ev-site-pill ev-site-pill-' + v.severity + '"' +
					(r.Details ? ' data-tip="' + escH(r.Details) + '"' : '') + '>' +
					'<i class="fas ' + c.icon + '"></i><strong>' + escH(c.label) + ':</strong>&nbsp;' + escH(v.label) +
					(r.Details ? '<i class="fas fa-info-circle ev-site-pill-info"></i>' : '') + '</span>';
			} else if (r.RuleKey === null) {
				customs += '<li><strong>' + escH(r.Title) + '</strong>' +
					(r.Details ? '<span class="ev-site-custom-detail">' + escH(r.Details) + '</span>' : '') + '</li>';
			}
		});
		var html = '';
		if (!pills && !customs) {
			html = '<div class="ev-site-cta" onclick="evOpenSiteRulesModal()"><i class="fas fa-plus-circle"></i> Add site rules — smoking, alcohol, pets, fires, and more</div>';
		} else {
			if (pills)   html += '<div class="ev-site-pills">' + pills + '</div>';
			if (customs) html += '<ul class="ev-site-custom-rules">' + customs + '</ul>';
		}
		gid('ev-site-rules-display').innerHTML = html;
	};
})();
</script>
```

- [ ] **Step 5: Verify in browser (Claude-in-Chrome)**

On `Event/detail/$EID/$DID` as a logged-in manager: Site tab → Edit Rules → toggle several pills (verify single-choice per group and tap-again-to-clear), fill a details field, add two custom rules, delete one, Save. Expected: modal closes, pill row + custom list render immediately; reload page — state persists; hover a pill with details — `data-tip` tooltip wraps. Repeat with all rules cleared → CTA card returns. Toggle dark mode: pills, modal options, CTA all legible.

- [ ] **Step 6: Commit**

```bash
git add orkui/template/revised-frontend/Eventnew_index.tpl
git diff --cached
git commit -m "Enhancement: site rules display + quick-toggle edit modal"
```

---

### Task 9: Site map viewer/editor + upload modal

**Files:**
- Modify: `orkui/template/revised-frontend/Eventnew_index.tpl` — fill `#ev-site-map-section`; add upload modal + pin-form modal; CSS; the map JS IIFE.

**Interfaces:**
- Consumes: `EvConfig.siteMap`, `EvConfig.siteLocations`, `EvConfig.siteLocCategories`, `EvConfig.canManageSite`; endpoints from Tasks 4–5; Leaflet global `L` (deferred script from Task 7).
- Produces (consumed by Task 10):
  - `window.evSiteFlyTo(locationId)` — switches to the Site tab, initializes the map if needed, flies to the pin, opens its popup. Safe no-op when the map/pin is missing.
  - `window.evSiteMapInit()` — idempotent lazy initializer (also called on first Site-tab open).
  - Internal state: `evSiteMarkers` = `{locationId: L.marker}`; locations array kept in `EvConfig.siteLocations` (mutated on save/delete so other code can read it).
  - Map container: `#ev-site-map` (block, 480px tall, 360px on ≤640px viewports).

- [ ] **Step 1: Map section markup (inside `#ev-site-map-section`)**

```php
					<?php if (!empty($siteMap) || $canManageSite): ?>
					<div class="ev-site-section-head">
						<h3 class="ev-site-section-title"><i class="fas fa-map"></i> Site Map</h3>
						<?php if ($canManageSite): ?>
						<div style="display:flex;gap:8px">
							<?php if (!empty($siteMap)): ?>
							<button type="button" class="pk-btn pk-btn-secondary" id="ev-site-editmode-btn" style="font-size:13px;padding:6px 14px" onclick="evSiteToggleEditMode()">
								<i class="fas fa-map-pin" style="margin-right:6px"></i><span>Edit Locations</span>
							</button>
							<?php endif; ?>
							<button type="button" class="pk-btn pk-btn-secondary" style="font-size:13px;padding:6px 14px" onclick="evOpenSiteMapUploadModal()">
								<i class="fas fa-upload" style="margin-right:6px"></i><?= !empty($siteMap) ? 'Replace Map' : 'Upload Site Map' ?>
							</button>
						</div>
						<?php endif; ?>
					</div>
					<?php if (!empty($siteMap)): ?>
					<div id="ev-site-map-wrap">
						<div id="ev-site-map"></div>
						<div id="ev-site-editmode-hint" style="display:none"><i class="fas fa-hand-pointer"></i> Click the map to place a pin. Drag pins to move them.</div>
						<div class="ev-site-legend" id="ev-site-legend"></div>
					</div>
					<noscript>
						<div style="overflow:auto;max-height:480px;border:1px solid #e2e8f0;border-radius:8px">
							<img src="<?= htmlspecialchars($siteMap['Url']) ?>" alt="Site map" style="max-width:none">
						</div>
					</noscript>
					<?php elseif ($canManageSite): ?>
					<div class="ev-site-cta" onclick="evOpenSiteMapUploadModal()">
						<i class="fas fa-map"></i> Upload a site map to tag battlefields, camping, parking, and more
					</div>
					<?php endif; ?>
					<?php endif; ?>
```

- [ ] **Step 2: Upload modal + pin form modal markup** (next to the rules modal, gated `<?php if ($canManageSite): ?>`)

```php
<?php if ($canManageSite): ?>
<!-- Site Map Upload Modal -->
<div class="ev-modal-overlay" id="ev-site-upload-modal">
	<div class="ev-modal" style="max-width:520px">
		<div class="ev-modal-header">
			<h3><i class="fas fa-upload" style="margin-right:8px"></i>Upload Site Map</h3>
			<button class="ev-modal-close" type="button" onclick="evCloseSiteMapUploadModal()">&times;</button>
		</div>
		<div class="ev-modal-body">
			<p style="font-size:13px;color:#718096;margin:0 0 10px">JPEG or PNG, up to 2 MB. A drawn or annotated map works best — aerial photos are fine too.</p>
			<?php if (!empty($siteMap)): ?>
			<div class="ev-modal-warning-box" style="margin-bottom:10px">
				<i class="fas fa-info-circle" style="margin-right:6px;flex-shrink:0;margin-top:2px"></i>
				<span>Replacing the map keeps your existing location pins — they're stored as relative positions. If the new image is a different area, drag them into place afterward.</span>
			</div>
			<?php endif; ?>
			<input type="file" id="ev-site-file" accept="image/jpeg,image/png" style="width:100%">
			<div id="ev-site-upload-preview" style="display:none;margin-top:10px;text-align:center">
				<img id="ev-site-upload-preview-img" style="max-width:100%;max-height:240px;border-radius:6px;border:1px solid #e2e8f0" alt="Preview">
			</div>
			<div class="ev-modal-error" id="ev-site-upload-error" style="display:none"></div>
		</div>
		<div class="ev-modal-footer">
			<button class="ev-btn ev-btn-outline" type="button" onclick="evCloseSiteMapUploadModal()" style="margin-right:auto">Cancel</button>
			<button class="ev-submit-btn" type="button" id="ev-site-upload-btn" onclick="evSubmitSiteMapUpload()" disabled>
				<i class="fas fa-upload"></i> <span>Upload</span>
			</button>
		</div>
	</div>
</div>
<!-- Site Location (pin) Form Modal -->
<div class="ev-modal-overlay" id="ev-site-loc-modal">
	<div class="ev-modal" style="max-width:460px">
		<div class="ev-modal-header">
			<h3><i class="fas fa-map-pin" style="margin-right:8px"></i><span id="ev-site-loc-modal-title">Add Location</span></h3>
			<button class="ev-modal-close" type="button" onclick="evCloseSiteLocModal()">&times;</button>
		</div>
		<div class="ev-modal-body">
			<div class="ev-modal-row">
				<div class="ev-modal-field ev-field-full">
					<label>Name <span style="color:#e53e3e">*</span></label>
					<input type="text" id="ev-site-loc-name" maxlength="80" placeholder="Main Battlefield, Feast Hall, Troll Booth..." style="width:100%">
				</div>
			</div>
			<div class="ev-modal-row">
				<div class="ev-modal-field ev-field-full">
					<label>Category</label>
					<select id="ev-site-loc-category" style="width:100%">
						<?php foreach ($siteLocCategories as $ck => $cc): ?>
						<option value="<?= $ck ?>"><?= htmlspecialchars($cc['label']) ?></option>
						<?php endforeach; ?>
					</select>
				</div>
			</div>
			<div class="ev-modal-row">
				<div class="ev-modal-field ev-field-full">
					<label>Description <span style="font-size:11px;color:#718096;font-weight:400">(optional)</span></label>
					<textarea id="ev-site-loc-desc" rows="2" placeholder="Anything attendees should know about this spot..." style="width:100%;resize:vertical"></textarea>
				</div>
			</div>
			<div class="ev-modal-error" id="ev-site-loc-error" style="display:none"></div>
			<input type="hidden" id="ev-site-loc-id" value="0">
			<input type="hidden" id="ev-site-loc-x" value="0">
			<input type="hidden" id="ev-site-loc-y" value="0">
		</div>
		<div class="ev-modal-footer">
			<button class="ev-btn ev-btn-outline" type="button" onclick="evCloseSiteLocModal()" style="margin-right:auto">Cancel</button>
			<button class="ev-btn ev-btn-outline" type="button" id="ev-site-loc-delete-btn" style="color:#e53e3e;display:none" onclick="evSiteDeleteLocation()">
				<i class="fas fa-trash-alt"></i> Delete
			</button>
			<button class="ev-submit-btn" type="button" id="ev-site-loc-save-btn" onclick="evSubmitSiteLocation()">
				<i class="fas fa-save"></i> <span>Save Location</span>
			</button>
		</div>
	</div>
</div>
<?php endif; ?>
```

- [ ] **Step 3: CSS**

```css
/* Site map */
#ev-site-map-wrap { position:relative; }
#ev-site-map { width:100%; height:480px; border-radius:8px; border:1px solid #e2e8f0; background:#f7fafc; z-index:0; }
@media (max-width:640px) { #ev-site-map { height:360px; } }
#ev-site-editmode-hint { position:absolute; top:10px; left:50%; transform:translateX(-50%); z-index:500; background:#2c5282; color:#fff; font-size:12.5px; padding:6px 14px; border-radius:999px; box-shadow:0 2px 8px rgba(0,0,0,.25); pointer-events:none; }
#ev-site-map.ev-site-editing { cursor:crosshair; }
.ev-site-legend { display:flex; flex-wrap:wrap; gap:6px; margin-top:8px; }
.ev-site-legend-chip { display:inline-flex; align-items:center; gap:5px; padding:3px 10px; border-radius:999px; font-size:12px; border:1px solid #cbd5e0; background:#fff; color:#4a5568; cursor:pointer; }
.ev-site-legend-chip i { font-size:11px; }
/* divIcon pin */
.ev-site-pin { display:flex; align-items:center; justify-content:center; width:30px; height:30px; border-radius:50% 50% 50% 0; transform:rotate(-45deg); border:2px solid #fff; box-shadow:0 2px 6px rgba(0,0,0,.35); }
.ev-site-pin i { transform:rotate(45deg); color:#fff; font-size:13px; }
.ev-site-popup-name { font-weight:700; font-size:14px; margin-bottom:2px; }
.ev-site-popup-cat { font-size:11px; text-transform:uppercase; letter-spacing:.05em; color:#718096; margin-bottom:4px; }
.ev-site-popup-desc { font-size:12.5px; color:#4a5568; margin-bottom:6px; }
.ev-site-popup-sched { border-top:1px solid #e2e8f0; margin-top:6px; padding-top:6px; }
.ev-site-popup-sched a { display:block; font-size:12px; margin-bottom:3px; }
.ev-site-popup-actions { border-top:1px solid #e2e8f0; margin-top:6px; padding-top:6px; display:flex; gap:10px; }
.ev-site-popup-actions button { background:none; border:none; cursor:pointer; font-size:12px; color:#3182ce; padding:0; }
.ev-site-popup-actions button.ev-site-popup-del { color:#e53e3e; }
/* Leaflet dark mode (pattern proven on the Weather page) */
html[data-theme="dark"] #ev-site-map { background:#1a202c; border-color:#4a5568; }
html[data-theme="dark"] .leaflet-bar a { background:#2d3748; color:#e2e8f0; border-color:#4a5568; }
html[data-theme="dark"] .leaflet-popup-content-wrapper, html[data-theme="dark"] .leaflet-popup-tip { background:#2d3748; color:#e2e8f0; }
html[data-theme="dark"] .ev-site-popup-desc { color:#cbd5e0; }
html[data-theme="dark"] .ev-site-popup-cat { color:#a0aec0; }
html[data-theme="dark"] .ev-site-popup-sched, html[data-theme="dark"] .ev-site-popup-actions { border-color:#4a5568; }
html[data-theme="dark"] .ev-site-legend-chip { background:#2d3748; border-color:#4a5568; color:#cbd5e0; }
```

- [ ] **Step 4: Map JS IIFE**

This IIFE serves BOTH viewers and managers — gate the whole block only on `EvConfig.siteMap || EvConfig.canManageSite`, and the editor pieces on `EvConfig.canManageSite` internally. Lazy-init: Leaflet renders a blank map inside `display:none` panels, so init happens on first Site-tab open (hook the tab `li` click) or on `evSiteFlyTo`.

```html
<script>
(function() {
	'use strict';
	if (!window.EvConfig || (!EvConfig.siteMap && !EvConfig.canManage)) { /* viewers still need it when a map exists */ }
	if (!window.EvConfig) return;
	if (!EvConfig.siteMap && !EvConfig.canManageSite) return;
	function gid(id) { return document.getElementById(id); }

	var map = null, imageLayer = null, editMode = false;
	var evSiteMarkers = {};
	var COORD_H = 1000; // fixed CRS height; width scales by aspect ratio

	function catCfg(key) {
		return EvConfig.siteLocCategories[key] || EvConfig.siteLocCategories.other;
	}
	function escH(s) {
		return String(s == null ? '' : s).replace(/[&<>"']/g, function(c) {
			return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
		});
	}
	function coordW() {
		return COORD_H * (EvConfig.siteMap.Width / EvConfig.siteMap.Height);
	}
	// fractional x/y (0-1, y from image TOP) <-> CRS.Simple latlng (y up)
	function fracToLatLng(x, y) { return [COORD_H - y * COORD_H, x * coordW()]; }
	function latLngToFrac(ll) {
		return {
			x: Math.max(0, Math.min(1, ll.lng / coordW())),
			y: Math.max(0, Math.min(1, (COORD_H - ll.lat) / COORD_H))
		};
	}

	window.evSiteMapInit = function() {
		if (map || !EvConfig.siteMap || !gid('ev-site-map') || typeof L === 'undefined') return;
		var bounds = [[0, 0], [COORD_H, coordW()]];
		map = L.map('ev-site-map', { crs: L.CRS.Simple, minZoom: -3, maxZoom: 2, zoomSnap: 0.25, attributionControl: false });
		imageLayer = L.imageOverlay(EvConfig.siteMap.Url, bounds).addTo(map);
		map.fitBounds(bounds);
		map.setMaxBounds(L.latLngBounds(bounds).pad(0.25));
		EvConfig.siteLocations.forEach(addMarker);
		renderLegend();
		if (EvConfig.canManageSite) {
			map.on('click', function(e) {
				if (!editMode) return;
				var f = latLngToFrac(e.latlng);
				openLocModal({ LocationId: 0, Name: '', Category: 'other', Description: '', X: f.x, Y: f.y });
			});
		}
	};

	function pinHtml(cat) {
		var c = catCfg(cat);
		return '<div class="ev-site-pin" style="background:' + c.color + '"><i class="fas ' + c.icon + '"></i></div>';
	}
	function addMarker(loc) {
		var m = L.marker(fracToLatLng(loc.X, loc.Y), {
			icon: L.divIcon({ className: '', html: pinHtml(loc.Category), iconSize: [30, 30], iconAnchor: [15, 30], popupAnchor: [0, -30] }),
			draggable: false
		}).addTo(map);
		m.bindPopup(function() { return popupHtml(loc); });
		m.on('dragend', function() {
			var f = latLngToFrac(m.getLatLng());
			saveLocation({ LocationId: loc.LocationId, Name: loc.Name, Category: loc.Category, Description: loc.Description, X: f.x, Y: f.y }, null);
		});
		evSiteMarkers[loc.LocationId] = m;
	}
	function popupHtml(loc) {
		var c = catCfg(loc.Category);
		var html = '<div class="ev-site-popup-name">' + escH(loc.Name) + '</div>' +
			'<div class="ev-site-popup-cat"><i class="fas ' + c.icon + '" style="color:' + c.color + ';margin-right:3px"></i>' + escH(c.label) + '</div>';
		if (loc.Description) html += '<div class="ev-site-popup-desc">' + escH(loc.Description) + '</div>';
		// Schedule items at this location — read live from the schedule table's
		// row data attributes so there's no second copy of schedule state.
		var items = document.querySelectorAll('tr[data-site-location-id="' + loc.LocationId + '"]');
		if (items.length) {
			html += '<div class="ev-site-popup-sched">';
			items.forEach(function(tr) {
				var t = tr.getAttribute('data-title') || '';
				var s = tr.getAttribute('data-start') || '';
				var timeLabel = s ? new Date(s).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' }) : '';
				html += '<a href="javascript:void(0)" onclick="evSiteGoToScheduleItem(\'' + tr.id + '\')"><i class="fas fa-clock" style="margin-right:4px"></i>' + escH(timeLabel) + ' — ' + escH(t) + '</a>';
			});
			html += '</div>';
		}
		if (EvConfig.canManageSite && editMode) {
			html += '<div class="ev-site-popup-actions">' +
				'<button type="button" onclick="evSiteEditLocation(' + loc.LocationId + ')"><i class="fas fa-pencil-alt"></i> Edit</button>' +
				'<button type="button" class="ev-site-popup-del" onclick="evSiteEditLocation(' + loc.LocationId + ', true)"><i class="fas fa-trash-alt"></i> Delete</button>' +
				'</div>';
		}
		return html;
	}
	function renderLegend() {
		var el = gid('ev-site-legend');
		if (!el) return;
		var seen = {};
		EvConfig.siteLocations.forEach(function(l) { seen[l.Category] = (seen[l.Category] || 0) + 1; });
		el.innerHTML = Object.keys(seen).map(function(k) {
			var c = catCfg(k);
			return '<span class="ev-site-legend-chip" onclick="evSiteLegendClick(\'' + k + '\')"><i class="fas ' + c.icon + '" style="color:' + c.color + '"></i>' + escH(c.label) + ' (' + seen[k] + ')</span>';
		}).join('');
	}
	var legendCycle = {};
	window.evSiteLegendClick = function(cat) {
		var matches = EvConfig.siteLocations.filter(function(l) { return l.Category === cat; });
		if (!matches.length || !map) return;
		legendCycle[cat] = ((legendCycle[cat] || 0) + 1) % matches.length;
		var loc = matches[legendCycle[cat]];
		map.flyTo(fracToLatLng(loc.X, loc.Y), Math.max(map.getZoom(), 0));
		evSiteMarkers[loc.LocationId] && evSiteMarkers[loc.LocationId].openPopup();
	};

	// ---- Cross-tab entry points ----
	window.evSiteFlyTo = function(locationId) {
		var loc = EvConfig.siteLocations.find(function(l) { return l.LocationId === locationId; });
		if (!loc) return;
		var li = document.querySelector('#ev-tab-nav li[data-tab="ev-tab-site"]');
		if (li && window.evShowTab) evShowTab(li, 'ev-tab-site');
		evSiteMapInit();
		if (!map) return;
		map.invalidateSize();
		map.flyTo(fracToLatLng(loc.X, loc.Y), 0.5);
		var m = evSiteMarkers[locationId];
		if (m) setTimeout(function() { m.openPopup(); }, 600);
	};
	window.evSiteGoToScheduleItem = function(rowId) {
		var li = document.querySelector('#ev-tab-nav li[data-tab="ev-tab-schedule"]');
		if (li && window.evShowTab) evShowTab(li, 'ev-tab-schedule');
		var row = gid(rowId);
		if (row) {
			row.scrollIntoView({ behavior: 'smooth', block: 'center' });
			row.style.outline = '2px solid #3182ce';
			setTimeout(function() { row.style.outline = ''; }, 2500);
		}
	};

	// Lazy init on first Site-tab open (Leaflet can't lay out in display:none).
	var siteTabLi = document.querySelector('#ev-tab-nav li[data-tab="ev-tab-site"]');
	if (siteTabLi) siteTabLi.addEventListener('click', function() {
		setTimeout(function() { evSiteMapInit(); if (map) map.invalidateSize(); }, 50);
	});

	// ---- Manager-only: edit mode, pin CRUD, upload ----
	if (!EvConfig.canManageSite) return;

	window.evSiteToggleEditMode = function() {
		editMode = !editMode;
		var btn = gid('ev-site-editmode-btn');
		if (btn) {
			btn.querySelector('span').textContent = editMode ? 'Done Editing' : 'Edit Locations';
			btn.style.background = editMode ? '#2c5282' : '';
			btn.style.color = editMode ? '#fff' : '';
		}
		gid('ev-site-editmode-hint').style.display = editMode ? '' : 'none';
		gid('ev-site-map').classList.toggle('ev-site-editing', editMode);
		Object.keys(evSiteMarkers).forEach(function(id) {
			if (evSiteMarkers[id].dragging) editMode ? evSiteMarkers[id].dragging.enable() : evSiteMarkers[id].dragging.disable();
		});
		map && map.closePopup();
	};

	function openLocModal(loc, deleteFocus) {
		gid('ev-site-loc-modal-title').textContent = loc.LocationId ? 'Edit Location' : 'Add Location';
		gid('ev-site-loc-id').value   = loc.LocationId;
		gid('ev-site-loc-x').value    = loc.X;
		gid('ev-site-loc-y').value    = loc.Y;
		gid('ev-site-loc-name').value = loc.Name;
		gid('ev-site-loc-category').value = loc.Category || 'other';
		gid('ev-site-loc-desc').value = loc.Description || '';
		gid('ev-site-loc-error').style.display = 'none';
		gid('ev-site-loc-delete-btn').style.display = loc.LocationId ? '' : 'none';
		gid('ev-site-loc-modal').classList.add('ev-modal-open');
		if (!deleteFocus) setTimeout(function() { gid('ev-site-loc-name').focus(); }, 50);
	}
	window.evCloseSiteLocModal = function() { gid('ev-site-loc-modal').classList.remove('ev-modal-open'); };
	window.evSiteEditLocation = function(locationId, focusDelete) {
		var loc = EvConfig.siteLocations.find(function(l) { return l.LocationId === locationId; });
		if (loc) openLocModal(loc, !!focusDelete);
	};

	function refreshMarker(loc) {
		if (evSiteMarkers[loc.LocationId]) { map.removeLayer(evSiteMarkers[loc.LocationId]); delete evSiteMarkers[loc.LocationId]; }
		addMarker(loc);
		if (editMode && evSiteMarkers[loc.LocationId].dragging) evSiteMarkers[loc.LocationId].dragging.enable();
	}
	function saveLocation(payload, onDone) {
		var fd = new FormData();
		fd.append('LocationId', payload.LocationId);
		fd.append('Name', payload.Name);
		fd.append('Category', payload.Category);
		fd.append('Description', payload.Description || '');
		fd.append('X', payload.X);
		fd.append('Y', payload.Y);
		fetch(EvConfig.uir + 'EventAjax/site_location_save/' + EvConfig.eventId + '/' + EvConfig.detailId, {
			method: 'POST', body: fd, headers: { 'X-Requested-With': 'XMLHttpRequest' }
		})
		.then(function(r) { return r.json(); })
		.then(function(data) {
			if (data.status === 0) {
				var idx = EvConfig.siteLocations.findIndex(function(l) { return l.LocationId === data.location.LocationId; });
				if (idx >= 0) EvConfig.siteLocations[idx] = data.location; else EvConfig.siteLocations.push(data.location);
				refreshMarker(data.location);
				renderLegend();
				if (typeof window.evSiteSyncScheduleOptions === 'function') window.evSiteSyncScheduleOptions();
				if (onDone) onDone(null, data.location);
			} else if (onDone) onDone(data.error || 'Could not save.');
		})
		.catch(function() { if (onDone) onDone('Network error — please try again.'); });
	}
	window.evSubmitSiteLocation = function() {
		var name = gid('ev-site-loc-name').value.trim();
		var err  = gid('ev-site-loc-error');
		if (!name) { err.textContent = 'Please enter a name.'; err.style.display = 'block'; return; }
		var btn = gid('ev-site-loc-save-btn'), orig = btn.innerHTML;
		btn.disabled = true; btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Saving…';
		saveLocation({
			LocationId: parseInt(gid('ev-site-loc-id').value, 10) || 0,
			Name: name,
			Category: gid('ev-site-loc-category').value,
			Description: gid('ev-site-loc-desc').value.trim(),
			X: parseFloat(gid('ev-site-loc-x').value) || 0,
			Y: parseFloat(gid('ev-site-loc-y').value) || 0
		}, function(errMsg) {
			btn.disabled = false; btn.innerHTML = orig;
			if (errMsg) { err.textContent = errMsg; err.style.display = 'block'; }
			else evCloseSiteLocModal();
		});
	};
	window.evSiteDeleteLocation = function() {
		var id = parseInt(gid('ev-site-loc-id').value, 10) || 0;
		if (!id) return;
		var btn = gid('ev-site-loc-delete-btn'), orig = btn.innerHTML;
		btn.disabled = true; btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i>';
		var fd = new FormData();
		fd.append('LocationId', id);
		fetch(EvConfig.uir + 'EventAjax/site_location_delete/' + EvConfig.eventId + '/' + EvConfig.detailId, {
			method: 'POST', body: fd, headers: { 'X-Requested-With': 'XMLHttpRequest' }
		})
		.then(function(r) { return r.json(); })
		.then(function(data) {
			btn.disabled = false; btn.innerHTML = orig;
			if (data.status === 0) {
				EvConfig.siteLocations = EvConfig.siteLocations.filter(function(l) { return l.LocationId !== id; });
				if (evSiteMarkers[id]) { map.removeLayer(evSiteMarkers[id]); delete evSiteMarkers[id]; }
				renderLegend();
				if (typeof window.evSiteSyncScheduleOptions === 'function') window.evSiteSyncScheduleOptions();
				// Linked schedule chips degrade to plain text on next reload;
				// live rows just lose fly-to (evSiteFlyTo no-ops on a missing pin).
				evCloseSiteLocModal();
			} else {
				var err = gid('ev-site-loc-error');
				err.textContent = data.error || 'Could not delete.'; err.style.display = 'block';
			}
		});
	};

	// ---- Upload modal ----
	window.evOpenSiteMapUploadModal = function() {
		gid('ev-site-file').value = '';
		gid('ev-site-upload-preview').style.display = 'none';
		gid('ev-site-upload-error').style.display = 'none';
		gid('ev-site-upload-btn').disabled = true;
		gid('ev-site-upload-modal').classList.add('ev-modal-open');
	};
	window.evCloseSiteMapUploadModal = function() { gid('ev-site-upload-modal').classList.remove('ev-modal-open'); };
	gid('ev-site-file') && gid('ev-site-file').addEventListener('change', function() {
		var f = this.files && this.files[0];
		var err = gid('ev-site-upload-error');
		err.style.display = 'none';
		gid('ev-site-upload-btn').disabled = true;
		gid('ev-site-upload-preview').style.display = 'none';
		if (!f) return;
		if (f.size > 2 * 1024 * 1024) { err.textContent = 'That file is over 2 MB. Please resize or compress it first.'; err.style.display = 'block'; return; }
		if (f.type !== 'image/jpeg' && f.type !== 'image/png') { err.textContent = 'Only JPEG and PNG images are supported.'; err.style.display = 'block'; return; }
		gid('ev-site-upload-preview-img').src = URL.createObjectURL(f);
		gid('ev-site-upload-preview').style.display = '';
		gid('ev-site-upload-btn').disabled = false;
	});
	window.evSubmitSiteMapUpload = function() {
		var f = gid('ev-site-file').files && gid('ev-site-file').files[0];
		if (!f) return;
		var btn = gid('ev-site-upload-btn'), orig = btn.innerHTML;
		btn.disabled = true; btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Uploading…';
		var fd = new FormData();
		fd.append('SiteMap', f);
		fetch(EvConfig.uir + 'EventAjax/site_map_upload/' + EvConfig.eventId + '/' + EvConfig.detailId, {
			method: 'POST', body: fd, headers: { 'X-Requested-With': 'XMLHttpRequest' }
		})
		.then(function(r) { return r.json(); })
		.then(function(data) {
			btn.disabled = false; btn.innerHTML = orig;
			if (data.status === 0) {
				// Section structure (map div, edit button) is PHP-rendered on
				// whether a map exists — a reload is the honest way to swap in.
				location.hash = 'ev-tab-site';
				location.reload();
			} else {
				var err = gid('ev-site-upload-error');
				err.textContent = data.error || 'Upload failed.'; err.style.display = 'block';
			}
		})
		.catch(function() {
			btn.disabled = false; btn.innerHTML = orig;
			var err = gid('ev-site-upload-error');
			err.textContent = 'Network error — please try again.'; err.style.display = 'block';
		});
	};
})();
</script>
```

Note: markers must be created with `draggable: false` then `.dragging.enable()`-d in edit mode — creating draggable markers and disabling them immediately is glitchy in Leaflet 1.9. **Check the deep-link hash wrapper** (`grep -n 'location.hash' Eventnew_index.tpl`, ~L2888): if it doesn't already handle arbitrary tab ids, extend it so `#ev-tab-site` opens the Site tab after the upload reload.

- [ ] **Step 5: Verify in browser (Claude-in-Chrome)**

Manager flow: Site tab → Upload Site Map (test image from Task 4) → page reloads on Site tab with the image displayed in Leaflet; pan + wheel-zoom work. Edit Locations → click map → pin form → save → pin appears with category icon/color; drag it (position persists after reload — verify by reloading); open its popup → Edit changes category (pin recolors), Delete removes it (in-modal button, no native confirm). Legend chips render with counts; clicking one flies to a pin. Add 3 pins across categories for Task 10. Public flow (logged-out window): map + pins + popups visible, no edit buttons anywhere, no `Upload` button. Dark mode: map controls, popups, legend legible.

- [ ] **Step 6: Commit**

```bash
git add orkui/template/revised-frontend/Eventnew_index.tpl
git diff --cached
git commit -m "Enhancement: Leaflet site map with tagged pin locations, upload + edit modes"
```

---

### Task 10: Schedule ↔ map integration UI

**Files:**
- Modify: `orkui/template/revised-frontend/Eventnew_index.tpl` — schedule modal Location field (L2771-2776); list row attrs + Location cell (L1211, L1215); grid block loc line (L1380-1382); small IIFE for the location dropdown.
- Modify: `orkui/template/revised-frontend/script/revised.js` — `evSubmitSchedule` (append field, L2409-2417 region; row-update block ~L9455-9465) and `evOpenScheduleEditModal` (populate, ~L9338-9355).

**Interfaces:**
- Consumes: `evSiteFlyTo` (Task 9), `ScheduleList[].SiteLocationId` (Task 6), `EvConfig.siteLocations`.
- Produces: schedule modal `<select id="ev-sched-site-location">` (present only when the page has locations OR manager; value = LocationId or ''); rows carry `data-site-location-id`; `window.evSiteSyncScheduleOptions()` refreshes the dropdown after pin CRUD (called by Task 9's code — must exist even when empty-select).

- [ ] **Step 1: Schedule modal — location combo**

Replace L2771-2776 (the Location row) with:

```php
			<div class="ev-modal-row">
				<div class="ev-modal-field ev-field-full">
					<label>Location</label>
					<select id="ev-sched-site-location" style="width:100%;margin-bottom:6px<?= empty($siteLocations) ? ';display:none' : '' ?>">
						<option value="">— Pick from the site map (optional) —</option>
						<?php foreach ($siteLocations as $sl): ?>
						<option value="<?= (int)$sl['LocationId'] ?>"><?= htmlspecialchars($sl['Name']) ?></option>
						<?php endforeach; ?>
					</select>
					<input type="text" id="ev-sched-location" placeholder="Main field, Feast hall, etc." autocomplete="off" style="width:100%">
				</div>
			</div>
```

- [ ] **Step 2: Dropdown behavior IIFE (in the tpl, near the other schedule-modal patch IIFEs ~L3369+)**

```html
<script>
(function() {
	'use strict';
	var sel = document.getElementById('ev-sched-site-location');
	if (!sel) return;
	// Picking a tag fills the text field (still editable); clearing leaves text.
	sel.addEventListener('change', function() {
		if (!sel.value) return;
		var loc = (EvConfig.siteLocations || []).find(function(l) { return l.LocationId === parseInt(sel.value, 10); });
		if (loc) document.getElementById('ev-sched-location').value = loc.Name;
	});
	// Refresh options after pin CRUD on the Site tab (keeps selection if alive).
	window.evSiteSyncScheduleOptions = function() {
		var cur = sel.value;
		sel.innerHTML = '<option value="">— Pick from the site map (optional) —</option>' +
			(EvConfig.siteLocations || []).map(function(l) {
				return '<option value="' + l.LocationId + '">' + String(l.Name).replace(/[&<>"]/g, function(c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }) + '</option>';
			}).join('');
		sel.value = cur;
		if (sel.value !== cur) sel.value = '';
		sel.style.display = (EvConfig.siteLocations || []).length ? '' : 'none';
	};
})();
</script>
```

- [ ] **Step 3: revised.js — send + persist the field**

(a) In `evSubmitSchedule`, after `fd.append('Description', desc);` (L9416) add:

```js
            var slSel = gid('ev-sched-site-location');
            fd.append('SiteLocationId', slSel && slSel.value ? slSel.value : '');
```

(b) In the edit-success row-update block (after `row.setAttribute('data-location', s.Location);` ~L9461) add:

```js
                            row.setAttribute('data-site-location-id', s.SiteLocationId != null ? s.SiteLocationId : '');
```

(c) In `evOpenScheduleEditModal` (the base one at ~L9338), after `gid('ev-sched-location').value = row.getAttribute('data-location') || '';` (L9350) add:

```js
            var slSel = gid('ev-sched-site-location');
            if (slSel) slSel.value = row.getAttribute('data-site-location-id') || '';
```

(d) Find where `evSubmitSchedule` builds a NEW row's cells for the add path (the `locCell`/location `<td>` construction just below the row-update block — read L9465-9540 to locate it) and render the chip there too when `s.SiteLocationId` is set, matching Step 4's markup: `<a href="javascript:void(0)" class="ev-loc-chip" onclick="evSiteFlyTo(N)">...`. Also include `data-site-location-id` in the new `<tr>`'s attributes.

- [ ] **Step 4: List + grid render chips**

(a) L1211 — add to the `<tr ...>` attribute list (after `data-location="..."`):

```php
data-site-location-id="<?= $item['SiteLocationId'] !== null ? (int)$item['SiteLocationId'] : '' ?>"
```

(b) Replace the Location cell (L1215):

```php
							<td><?php if (!empty($item['SiteLocationId'])): ?><a href="javascript:void(0)" class="ev-loc-chip" onclick="evSiteFlyTo(<?= (int)$item['SiteLocationId'] ?>)" data-tip="Show on site map"><i class="fas fa-map-marker-alt"></i> <?= htmlspecialchars($item['Location']) ?></a><?php else: ?><?= htmlspecialchars($item['Location']) ?><?php endif; ?></td>
```

(c) Replace the grid block's location line (L1380-1382) — note `event.stopPropagation()` so the chip click doesn't also trigger the block's own onclick:

```php
										<?php if (!empty($it['Location'])): ?>
										<div class="ev-grid-block-loc"><?php if (!empty($it['SiteLocationId'])): ?><a href="javascript:void(0)" class="ev-loc-chip ev-loc-chip-grid" onclick="event.stopPropagation();evSiteFlyTo(<?= (int)$it['SiteLocationId'] ?>)"><i class="fas fa-map-marker-alt"></i> <?= htmlspecialchars($it['Location']) ?></a><?php else: ?><i class="fas fa-map-marker-alt"></i> <?= htmlspecialchars($it['Location']) ?><?php endif; ?></div>
										<?php endif; ?>
```

(d) Chip CSS (page `<style>` block):

```css
.ev-loc-chip { display:inline-flex; align-items:center; gap:4px; padding:1px 8px; border-radius:999px; font-size:12.5px; background:#ebf8ff; border:1px solid #90cdf4; color:#2b6cb0; text-decoration:none; cursor:pointer; }
.ev-loc-chip:hover { background:#bee3f8; }
.ev-loc-chip-grid { font-size:11px; padding:0 6px; }
html[data-theme="dark"] .ev-loc-chip { background:#1e3a5f; border-color:#2c5282; color:#90cdf4; }
html[data-theme="dark"] .ev-loc-chip:hover { background:#2c5282; }
```

- [ ] **Step 5: Verify end-to-end in browser (Claude-in-Chrome)**

(1) Schedule tab → Add Schedule Item → pick a map location from the dropdown → text fills with the name → save → row shows a blue location chip. (2) Click the chip → page switches to Site tab, map flies to the pin, popup opens, and the popup lists the schedule item. (3) Click the schedule item in the popup → back on Schedule tab, row scrolls into view with a highlight ring. (4) Grid view: same chip on the block; chip click flies (block click still opens its own behavior). (5) Edit the schedule item → dropdown pre-selected; clear it to free text `Under the oak` → chip becomes plain text after save. (6) Delete the linked pin on the Site tab → reload → row shows plain text (the pin name), no chip, no JS errors. (7) Dark mode + a ~400px-wide viewport pass over both tabs.

- [ ] **Step 6: Commit**

```bash
git add orkui/template/revised-frontend/Eventnew_index.tpl orkui/template/revised-frontend/script/revised.js
git diff --cached
git commit -m "Enhancement: schedule location picker + map fly-to chips with popup backlinks"
```

---

### Task 10b: Client-side auto-downsize for oversized site maps (added 2026-07-16 by Avery mid-build)

**Files:**
- Modify: `orkui/template/revised-frontend/Eventnew_index.tpl` — site-map IIFE (upload modal handlers) only.

**Interfaces:**
- Consumes: the upload modal from Task 9 (`#ev-site-file` change handler, `evSubmitSiteMapUpload`), the live `site_map_upload` endpoint (server 2MB gate UNCHANGED — it stays as the backstop).
- Produces: files ≤2MB upload untouched (byte-identical, zero recompression). Files >2MB are automatically downsized client-side before upload, quality-first:
  1. Decode via Image + canvas. Flatten to white like the banner path (site maps don't need alpha once they exceed 2MB; a >2MB PNG converts to JPEG).
  2. First attempt: clamp longest edge to 3000px (no-op if smaller), encode JPEG **q0.92**.
  3. While still >2MB target (use 2,000,000 bytes as the working target for headroom under the 2,097,152 server gate): scale dimensions by `sqrt(target/size) * 0.95` at q0.92, up to 3 attempts; then one final attempt at q0.85; then error "Could not downsize this image enough — please export it smaller."
  4. Local function inside the site IIFE (e.g. `evSiteDownsizeMap(file, onReady, onError)`); do NOT modify the shared `resizeImageToLimit` in orkui.js (other callers depend on its behavior).
- UX: the file-change handler no longer rejects >2MB files; it shows an inline notice in the modal ("Downsizing 5.2 MB image…" → "Downsized to 1.8 MB — some detail may be reduced"), previews the downsized result, and enables Upload with the downsized blob (`new File([blob], 'sitemap.jpg', {type:'image/jpeg'})`). The type check (jpeg/png only) still rejects other formats before any downsizing.

- [ ] Implement per the above; verify in browser: a >2MB JPEG and a >2MB PNG both auto-downsize + upload successfully (server accepts, dims recorded), a ≤2MB file uploads byte-identical (no recompression — confirm the served file's dimensions match the original exactly and the notice does not appear), a non-image still rejects client-side. Zero console errors; dark-mode notice legibility.
- [ ] Commit (tpl only).

### Task 10c: In-product confirmation for schedule-item removal (added 2026-07-16 by Avery mid-build)

**Files:**
- Modify: `orkui/template/revised-frontend/script/revised.js` — `window.evRemoveSchedule` (~L9655; `if (!confirm('Remove this schedule item?')) return;` at ~L9656)
- Modify: `orkui/template/revised-frontend/Eventnew_index.tpl` — confirm modal markup (manager-gated) + any CSS needed.

**Interfaces:**
- Consumes: existing `evRemoveSchedule(btn, scheduleId)` call sites (static rows in the tpl AND the JS-built row string ~L9457 — signature must not change) and the `ev-` modal pattern.
- Produces: clicking a schedule row's × opens a small in-page `ev-modal-overlay` confirm dialog (title "Remove Schedule Item", body shows the item's title read from the row's `data-title`, Cancel + red "Remove" buttons — NO native `confirm()`). Confirming runs the existing removal fetch unchanged; canceling closes the dialog and does nothing. Reuse an existing event-page confirm helper if one exists (grep `evConfirm`/similar in revised.js first); otherwise add a minimal one following the `.ev-modal-overlay`/`.ev-modal-open` pattern. Dark mode covered by the existing ev-modal styles.

- [ ] Implement; verify in browser: × opens the dialog with the right item title; Cancel leaves the row; Remove deletes it (row disappears, feast card syncs if applicable); zero console errors; grep confirms no `confirm(` remains in `evRemoveSchedule`.
- [ ] Commit (both files).

### Task 11: Full verification + polish gate

**Files:** none new — fixes land where found.

- [ ] **Step 1: Full curl regression** — re-run every curl block from Tasks 3–6 top to bottom against a fresh event (create one via the UI if needed). All expected outputs must match. Flush memcache if anything looks stale: `docker exec ork3-php8-app php -r '$m=new Memcached();$m->addServer("memcache",11211);$m->flush();'` (adjust host if the container names differ — check `docker-compose.php8.yml`).
- [ ] **Step 2: Auth-denial code review** — with the local bypass in place these can't be curl-verified, so re-read each new endpoint and confirm: login gate first; `valid_id` on every id; `_canManageSite` (which embeds `_detailBelongsToEvent`) before any read/write; every location/rule query scoped by `detail_id`; `LocationId` ownership checked before UPDATE/DELETE.
- [ ] **Step 3: Dark-mode pre-flight checklist** — every new surface (pills, CTA cards, both modals, map, legend, popups, chips, section titles) inspected in dark mode via Chrome. Headings inside the Site tab must show NO gray pill box (the orkui.css reset from Task 7).
- [ ] **Step 4: Standards sweep** — `docker exec ork3-php8-app php -l` on all three touched PHP files; confirm zero FA6 icon names slipped in (`grep -n 'fa-gauge-high\|fa-pen-to-square\|fa-location-dot\|fa-map-location' Eventnew_index.tpl` → no hits); confirm no native dialogs (`grep -n 'confirm(\|alert(' Eventnew_index.tpl` → only pre-existing hits, none in `ev-site` code); confirm every new raw `$DB` call is preceded by `$DB->Clear()`.
- [ ] **Step 5: Request review** — run the superpowers:requesting-code-review skill against the branch diff (`git diff master...HEAD`), fix findings, commit.

---

## Self-review notes (already applied)

- Spec coverage: rules builder (T3, T8), pill catalog + severity colors (T2, T8), custom rules (T3, T8), map upload 2MB (T4, T9), pin CRUD + drag (T5, T9), fractional coords (T1, T9), schedule link + fallback text (T6, T10), fly-to + popup backlinks (T9, T10), Getting There fold-in (T7), empty states (T8, T9), degradation paths (T5, T6, T10 step 5.6), dark mode (T8–T10, T11), no-JS `<noscript>` fallback (T9).
- Spec deviation, deliberate: `site_rules_save` uses validate-everything-then-DELETE+single-INSERT instead of a transaction — `YapoMysql` has no transaction methods on this branch (Global Constraints).
- Type consistency: `SiteLocationId` (int|null) everywhere; `LocationId/Name/Category/Description/X/Y` shape identical in EvConfig, `site_location_save` response, and controller load; `evSiteSyncScheduleOptions` defined in T10, guarded-called in T9.
