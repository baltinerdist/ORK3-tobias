# Shortcut Links (`/me/…`) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give players, kingdoms, parks, and units short shareable links (`ork.amtgard.com/me/{stub}`) that 302-redirect to their public profile — every entity gets a zero-storage derived default, and owners/officers can claim one custom stub.

**Architecture:** A web-server rewrite maps `/me/{stub}` to the existing router (`Route=Me/go/{stub}`). A thin resolver controller (`Controller_Me::go`) delegates to a single DB-owning lib class (`class.ShortLink.php`) and issues the redirect or renders a not-found view. Custom stubs live in one `ork_shortlink` table; derived defaults (`pl46193`, `k17`, `p293`, `u3441`) are computed and never stored. A per-entity "Shortcut Link" management card (shared JS helper for the three revised-frontend surfaces, inline JS for the legacy Unit surface) lets owners check availability live and save.

**Tech Stack:** PHP 8 (no framework), MySQL/MariaDB (MyISAM, latin1), yapo ORM, plain-PHP `.tpl` templates (`extract()`+`include`), vanilla JS (`fetch`), Apache `mod_rewrite`. Local dev: Docker, app at `http://localhost:19080/orkui/`.

## Global Constraints

- **DB access only in `system/lib/ork3/class.ShortLink.php`.** Controllers and `orkui/model/` are thin pass-throughs — **no raw `$DB`** in either. (Architecture-layers rule.)
- **`.tpl` files are PLAIN PHP**, rendered via `extract()`+`include`. Use `<?php ?>` / `<?= ?>`. NEVER Smarty (`{$var}`, `{if}`, `{foreach}`).
- **`$DB->Clear()` before any raw Execute/DataSet** to avoid stale PDO bindings.
- **Controller action session accessor is `$this->session->user_id`** (NOT `$this->__session`).
- **Dark-mode compatible proactively.** Selector is `html[data-theme="dark"]`. Use `var(--ork-*)` tokens; reset global `h1–h6` gray-box if any heading is used.
- **No native `title` tooltips** (use `data-tip`), **no native `confirm()`/`alert()`** (use `tnConfirm()` if needed).
- **FontAwesome 5.8.2 only** — `fa-copy`, `fa-check`, `fa-save`, `fa-link`, `fa-exclamation-circle` are all valid FA5. Avoid FA6-only names.
- **Stub validation (authoritative, server-side):** lowercase; regex `^[a-z][a-z0-9_-]{2,29}$`; reject `^(pl|k|p|u)\d+$` (reserved derived namespace); reject reserved words `me, admin, login, logout, api, assets, orkui, orkservice, index, profile, search, home, about`.
- **Redirects are 302** (temporary) for both derived and custom, so reassigned stubs are never cached stale.
- **Entity type vocabulary** is exactly `player | kingdom | park | unit` everywhere (enum, params, configs). Prefix map: `pl`→player, `k`→kingdom, `p`→park, `u`→unit. Canonical routes: `Player/profile/{id}`, `Kingdom/profile/{id}`, `Park/profile/{id}`, `Unit/index/{id}`.
- **Do NOT stage `system/lib/ork3/class.Authorization.php`** (carries a local login-bypass hack). Stage files explicitly; never `git add -A`/`git add .`.

---

## File Structure

**Create:**
- `db-migrations/2026-06-30-shortcut-links.sql` — `ork_shortlink` table.
- `system/lib/ork3/class.ShortLink.php` — all DB + validation + resolution (the only DB layer).
- `orkui/model/model.ShortLink.php` — thin pass-through.
- `orkui/controller/controller.Me.php` — `go($stub)` resolver + redirect / not-found.
- `orkui/controller/controller.ShortLinkAjax.php` — `check()` + `save()` endpoints.
- `orkui/template/revised-frontend/Me_notfound.tpl` — friendly not-found view.

**Modify:**
- `ork.sql` — add the `ork_shortlink` CREATE TABLE so fresh DBs have it.
- `.htaccess` (repo root) — enable rewrite + `/me/` rule.
- `orkui/template/revised-frontend/style/revised.css` — `.sl-card` styles (+ dark mode).
- `orkui/template/revised-frontend/script/revised.js` — shared `tnShortlinkInit()` helper.
- `orkui/template/revised-frontend/Playernew_index.tpl` — card markup + `PnConfig` fields + init call.
- `orkui/template/revised-frontend/Kingdomnew_index.tpl` — card panel + `KnConfig` fields + init call.
- `orkui/template/revised-frontend/Parknew_index.tpl` — card panel + `PkConfig` fields + init call.
- `orkui/template/default/Admin_unit.tpl` — card + self-contained inline JS (legacy surface, no `revised.js`).

---

## Task 1: Database migration for `ork_shortlink`

**Files:**
- Create: `db-migrations/2026-06-30-shortcut-links.sql`
- Modify: `ork.sql` (append the same CREATE TABLE near the other `CREATE TABLE` blocks)

**Interfaces:**
- Produces: table `ork_shortlink(shortlink_id, slug, entity_type, entity_id, created_by, created, modified)`, `UNIQUE uq_slug(slug)`, `UNIQUE uq_entity(entity_type, entity_id)`.

- [ ] **Step 1: Write the migration file**

Create `db-migrations/2026-06-30-shortcut-links.sql`:

```sql
-- Shortcut links (/me/ vanity redirects) — 2026-06-30
--
-- One row per CUSTOM stub. Derived defaults (pl46193, k17, p293, u3441) are
-- computed at resolve time and never stored here.
--
-- uq_slug      : a slug is globally unique across all entity types.
-- uq_entity    : an entity has at most ONE custom stub; changing it is an
--                in-place UPDATE of `slug`, which instantly frees the old slug.
--
-- Re-runnable: CREATE TABLE IF NOT EXISTS is a no-op once applied.

CREATE TABLE IF NOT EXISTS `ork_shortlink` (
  `shortlink_id` int(11)      NOT NULL AUTO_INCREMENT,
  `slug`         varchar(30)  NOT NULL,
  `entity_type`  enum('player','kingdom','park','unit') NOT NULL,
  `entity_id`    int(11)      NOT NULL,
  `created_by`   int(11)      NOT NULL DEFAULT 0,
  `created`      timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `modified`     timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`shortlink_id`),
  UNIQUE KEY `uq_slug` (`slug`),
  UNIQUE KEY `uq_entity` (`entity_type`, `entity_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
```

- [ ] **Step 2: Apply it to the local dev DB and verify**

Run:
```bash
docker-compose -f docker-compose.php8.yml exec -T db \
  mysql -uroot -proot ork < db-migrations/2026-06-30-shortcut-links.sql
docker-compose -f docker-compose.php8.yml exec -T db \
  mysql -uroot -proot ork -e "SHOW CREATE TABLE ork_shortlink\G"
```
Expected: prints the `ork_shortlink` definition with `uq_slug` and `uq_entity` unique keys.
(If the db service name differs, check `docker-compose.php8.yml`; the README documents `mysql -P 19306 --protocol=tcp -h localhost -u root -proot ork < file.sql` as an alternative.)

- [ ] **Step 3: Mirror the table into `ork.sql`**

Add the identical `CREATE TABLE IF NOT EXISTS ork_shortlink (...)` block to `ork.sql` (so fresh installs get it). Place it alongside other table definitions; the `IF NOT EXISTS` form matches the file's style.

- [ ] **Step 4: Commit**

```bash
git add db-migrations/2026-06-30-shortcut-links.sql ork.sql
git commit -m "Add ork_shortlink table for shortcut links"
```

---

## Task 2: Lib class `class.ShortLink.php` (validation + resolution + CRUD)

**Files:**
- Create: `system/lib/ork3/class.ShortLink.php`
- Test (scratch): `scratchpad/test_shortlink_validate.php` (throwaway, not committed)

**Interfaces:**
- Auto-registers as `Ork3::$Lib->shortlink` (startup.php scans `system/lib/ork3/`, lowercases `ShortLink`).
- Produces (all consumed by model/controllers in later tasks):
  - `ValidateSlug(string $slug): array` → `['ok'=>bool, 'reason'=>string, 'slug'=>string]` (slug lowercased/trimmed).
  - `Resolve(string $stub): array|false` → `['type'=>'player|kingdom|park|unit', 'id'=>int]` or `false`.
  - `DerivedStub(string $type, int $id): string` → e.g. `'pl46193'`.
  - `GetStubFor(string $type, int $id): ?string` → custom slug or `null`.
  - `CheckAvailability(string $slug, string $type, int $id): array` → `['available'=>bool, 'reason'=>string]` (excludes the entity's own current slug).
  - `SetStub(string $type, int $id, string $slug, int $mundaneId): array` → `Success(stub)` / `InvalidParameter(..)` / `ProcessingError(..)`.
  - `ReleaseStub(string $type, int $id): array` → `Success()`.

- [ ] **Step 1: Write a throwaway validation test (red)**

Create `scratchpad/test_shortlink_validate.php`. It boots the app, then asserts the pure validation matrix. (Booting needs the dev config; run it inside the container in Step 3.)

```php
<?php
// Throwaway. Run inside the php container: see Step 3.
require_once dirname(__DIR__) . '/startup.php';

$sl = Ork3::$Lib->shortlink;
$cases = [
    ['tobias',        true ],   // good
    ['House-of-X',    true ],   // hyphen ok, lowercased
    ['ab',            false],   // too short (<3)
    ['1abc',          false],   // must start with letter
    ['has space',     false],   // space illegal
    ['pl46193',       false],   // reserved derived pattern (player)
    ['k17',           false],   // reserved derived pattern (kingdom)
    ['p9',            false],   // reserved derived pattern (park)
    ['u100',          false],   // reserved derived pattern (unit)
    ['admin',         false],   // reserved word
    ['me',            false],   // reserved word
    [str_repeat('a',31), false],// too long (>30)
];
$fail = 0;
foreach ($cases as [$in, $want]) {
    $got = $sl->ValidateSlug($in)['ok'];
    $ok  = ($got === $want);
    if (!$ok) { $fail++; }
    printf("%s  %-14s want=%d got=%d\n", $ok ? 'PASS' : 'FAIL', $in, $want, $got);
}
echo $fail ? "\n$fail FAILURES\n" : "\nALL PASS\n";
exit($fail ? 1 : 0);
```

- [ ] **Step 2: Run it to confirm it fails**

Run:
```bash
docker-compose -f docker-compose.php8.yml exec -T php php /var/www/html/scratchpad/test_shortlink_validate.php
```
Expected: fatal error / "Call to a member function ValidateSlug() on null" (class doesn't exist yet). That is the red state.
(If `/var/www/html` is not the container web root, find it with `docker-compose -f docker-compose.php8.yml exec php sh -lc 'ls /var/www'` and adjust the path; the repo root is mounted there.)

- [ ] **Step 3: Implement `class.ShortLink.php`**

Create `system/lib/ork3/class.ShortLink.php`:

```php
<?php

class ShortLink extends Ork3
{
    /** entity_type => derived-stub prefix */
    private const PREFIX = [
        'player'  => 'pl',
        'kingdom' => 'k',
        'park'    => 'p',
        'unit'    => 'u',
    ];

    /** entity_type => [table, id column, optional "active" guard column] */
    private const ENTITY = [
        'player'  => ['ork_mundane',  'mundane_id',  'active'],
        'kingdom' => ['ork_kingdom',  'kingdom_id',  null],
        'park'    => ['ork_park',     'park_id',     null],
        'unit'    => ['ork_unit',     'unit_id',     'active'],
    ];

    private const RESERVED = [
        'me','admin','login','logout','api','assets',
        'orkui','orkservice','index','profile','search','home','about',
    ];

    public function __construct()
    {
        parent::__construct();
        $this->shortlink = new yapo($this->db, DB_PREFIX . 'shortlink');
    }

    /** Validate + normalize a candidate custom slug. */
    public function ValidateSlug($slug)
    {
        $slug = strtolower(trim((string)$slug));
        if ($slug === '') {
            return ['ok' => false, 'reason' => 'Enter a shortcut.', 'slug' => $slug];
        }
        if (!preg_match('/^[a-z][a-z0-9_-]{2,29}$/', $slug)) {
            return ['ok' => false, 'reason' => '3–30 characters: start with a letter; letters, numbers, hyphen, underscore only.', 'slug' => $slug];
        }
        if (preg_match('/^(pl|k|p|u)\d+$/', $slug)) {
            return ['ok' => false, 'reason' => 'That looks like a default ID link and is reserved.', 'slug' => $slug];
        }
        if (in_array($slug, self::RESERVED, true)) {
            return ['ok' => false, 'reason' => 'That word is reserved.', 'slug' => $slug];
        }
        return ['ok' => true, 'reason' => '', 'slug' => $slug];
    }

    /** Derived (always-on, unstored) stub for an entity, e.g. "pl46193". */
    public function DerivedStub($type, $id)
    {
        $type = strtolower($type);
        return isset(self::PREFIX[$type]) ? self::PREFIX[$type] . (int)$id : '';
    }

    /** Resolve a stub to ['type'=>.., 'id'=>..] or false. Derived first, then custom. */
    public function Resolve($stub)
    {
        $stub = strtolower(trim((string)$stub));
        if ($stub === '') {
            return false;
        }
        // 1) Derived default: ^(pl|k|p|u)\d+$  (pl before p — alternation order matters)
        if (preg_match('/^(pl|k|p|u)(\d+)$/', $stub, $m)) {
            $byPrefix = array_flip(self::PREFIX); // 'pl'=>'player', ...
            $type = $byPrefix[$m[1]];
            $id   = (int)$m[2];
            return $this->EntityExists($type, $id) ? ['type' => $type, 'id' => $id] : false;
        }
        // 2) Custom slug lookup
        $sql = "SELECT entity_type, entity_id FROM " . DB_PREFIX . "shortlink WHERE slug = "
             . $this->db->quote($stub) . " LIMIT 1";
        $r = $this->db->query($sql);
        if ($r !== false && $r->size() > 0 && $r->next()) {
            $type = $r->entity_type;
            $id   = (int)$r->entity_id;
            return $this->EntityExists($type, $id) ? ['type' => $type, 'id' => $id] : false;
        }
        return false;
    }

    /** Current custom slug for an entity, or null if it uses the derived default. */
    public function GetStubFor($type, $id)
    {
        $type = strtolower($type);
        $sql = "SELECT slug FROM " . DB_PREFIX . "shortlink WHERE entity_type = "
             . $this->db->quote($type) . " AND entity_id = " . (int)$id . " LIMIT 1";
        $r = $this->db->query($sql);
        if ($r !== false && $r->size() > 0 && $r->next()) {
            return $r->slug;
        }
        return null;
    }

    /** Availability for the management UI. Excludes the entity's own current slug. */
    public function CheckAvailability($slug, $type, $id)
    {
        $v = $this->ValidateSlug($slug);
        if (!$v['ok']) {
            return ['available' => false, 'reason' => $v['reason']];
        }
        $slug = $v['slug'];
        $sql = "SELECT entity_type, entity_id FROM " . DB_PREFIX . "shortlink WHERE slug = "
             . $this->db->quote($slug) . " LIMIT 1";
        $r = $this->db->query($sql);
        if ($r !== false && $r->size() > 0 && $r->next()) {
            $ownedBySelf = (strtolower($r->entity_type) === strtolower($type) && (int)$r->entity_id === (int)$id);
            if (!$ownedBySelf) {
                return ['available' => false, 'reason' => 'That shortcut is already taken.'];
            }
        }
        return ['available' => true, 'reason' => 'Available'];
    }

    /** Upsert the single custom stub for an entity. */
    public function SetStub($type, $id, $slug, $mundaneId)
    {
        $type = strtolower($type);
        if (!isset(self::ENTITY[$type]) || !valid_id($id)) {
            return InvalidParameter(null, 'Unknown entity.');
        }
        $avail = $this->CheckAvailability($slug, $type, $id);
        if (!$avail['available']) {
            return InvalidParameter(null, $avail['reason']);
        }
        $slug = $this->ValidateSlug($slug)['slug'];

        // Upsert by (entity_type, entity_id): update in place if a row exists.
        $this->shortlink->clear();
        $this->shortlink->entity_type = $type;
        $this->shortlink->entity_id   = (int)$id;
        $exists = $this->shortlink->find();   // finds by the set fields

        $this->shortlink->clear();
        if ($exists) {
            $this->shortlink->shortlink_id = $this->shortlink->shortlink_id; // preserve PK for update path
        }
        // Re-find to obtain PK cleanly:
        $this->shortlink->clear();
        $this->shortlink->entity_type = $type;
        $this->shortlink->entity_id   = (int)$id;
        if ($this->shortlink->find()) {
            $this->shortlink->slug       = $slug;
            $this->shortlink->created_by = (int)$mundaneId;
            $this->shortlink->save();
        } else {
            $this->shortlink->clear();
            $this->shortlink->slug        = $slug;
            $this->shortlink->entity_type = $type;
            $this->shortlink->entity_id   = (int)$id;
            $this->shortlink->created_by  = (int)$mundaneId;
            $this->shortlink->save();
        }

        // Read-back confirmation (lastInsertId is unreliable under PDO warning mode).
        $confirm = $this->GetStubFor($type, $id);
        if ($confirm !== $slug) {
            return ProcessingError(null, 'That shortcut was just taken. Try another.');
        }
        return Success($slug);
    }

    /** Remove an entity's custom stub (revert to derived default). */
    public function ReleaseStub($type, $id)
    {
        $type = strtolower($type);
        $this->shortlink->clear();
        $this->shortlink->entity_type = $type;
        $this->shortlink->entity_id   = (int)$id;
        if ($this->shortlink->find()) {
            $this->shortlink->delete();
        }
        return Success();
    }

    /** Lightweight existence/active check for a resolve target. */
    private function EntityExists($type, $id)
    {
        if (!isset(self::ENTITY[$type]) || !valid_id($id)) {
            return false;
        }
        [$table, $idCol, $activeCol] = self::ENTITY[$type];
        $sql = "SELECT $idCol FROM " . DB_PREFIX . substr($table, strlen('ork_'))
             . " WHERE $idCol = " . (int)$id;
        if ($activeCol !== null) {
            $sql .= " AND $activeCol = 1";
        }
        $sql .= " LIMIT 1";
        $r = $this->db->query($sql);
        return ($r !== false && $r->size() > 0);
    }
}
```

Note: `DB_PREFIX` is `ork_`; `self::ENTITY` table names are written with the `ork_` prefix for readability, so `EntityExists` strips it and re-prepends `DB_PREFIX`. If `$this->db->quote()` is unavailable in this yapo build, substitute `"'" . $this->db->escape($stub) . "'"` (check `class.Pronoun.php`/`class.Award.php` for the project's escaping helper) — slugs are already regex-constrained, but keep the parameterization.

- [ ] **Step 4: Run the validation test (green)**

Run:
```bash
docker-compose -f docker-compose.php8.yml exec -T php php /var/www/html/scratchpad/test_shortlink_validate.php
```
Expected: `ALL PASS`. If any FAIL, fix the regex/reserved logic, not the test.

- [ ] **Step 5: Smoke-test resolution against real data**

Pick a real id from the dev DB and confirm `Resolve`/`DerivedStub`:
```bash
docker-compose -f docker-compose.php8.yml exec -T php php -r '
require "/var/www/html/startup.php";
$sl = Ork3::$Lib->shortlink;
var_dump($sl->DerivedStub("player", 46193));      // string "pl46193"
var_dump($sl->Resolve("pl46193"));                // ["type"=>"player","id"=>46193] if active
var_dump($sl->Resolve("k1"));                      // kingdom 1 if exists
var_dump($sl->Resolve("pl999999999"));            // false (missing)
var_dump($sl->Resolve("definitely-not-a-stub"));  // false
'
```
Expected: derived stub string; valid arrays for existing ids; `false` for missing/unknown.

- [ ] **Step 6: Commit**

```bash
git add system/lib/ork3/class.ShortLink.php
git commit -m "Add ShortLink lib: validation, derived/custom resolution, stub CRUD"
```

---

## Task 3: Model pass-through `model.ShortLink.php`

**Files:**
- Create: `orkui/model/model.ShortLink.php`

**Interfaces:**
- Consumes: `Ork3::$Lib->shortlink->{Resolve,CheckAvailability,SetStub,ReleaseStub,GetStubFor,DerivedStub}`.
- Produces: `Model_ShortLink` with methods `resolve`, `check`, `set`, `release`, `get_stub`, `derived` for controllers via `$this->load_model('ShortLink')`.

- [ ] **Step 1: Implement the model**

Create `orkui/model/model.ShortLink.php`:

```php
<?php

class Model_ShortLink extends Model
{
    public function resolve($stub)
    {
        return Ork3::$Lib->shortlink->Resolve($stub);
    }

    public function check($slug, $type, $id)
    {
        return Ork3::$Lib->shortlink->CheckAvailability($slug, $type, $id);
    }

    public function set($type, $id, $slug, $mundaneId)
    {
        return Ork3::$Lib->shortlink->SetStub($type, $id, $slug, $mundaneId);
    }

    public function release($type, $id)
    {
        return Ork3::$Lib->shortlink->ReleaseStub($type, $id);
    }

    public function get_stub($type, $id)
    {
        return Ork3::$Lib->shortlink->GetStubFor($type, $id);
    }

    public function derived($type, $id)
    {
        return Ork3::$Lib->shortlink->DerivedStub($type, $id);
    }
}
```

- [ ] **Step 2: Verify it loads without error**

Run:
```bash
docker-compose -f docker-compose.php8.yml exec -T php php -r '
require "/var/www/html/startup.php";
require "/var/www/html/orkui/model/model.ShortLink.php";
$m = new Model_ShortLink();
var_dump($m->derived("kingdom", 17));   // string "k17"
'
```
Expected: `string(3) "k17"`. No fatal errors.

- [ ] **Step 3: Commit**

```bash
git add orkui/model/model.ShortLink.php
git commit -m "Add ShortLink model pass-through"
```

---

## Task 4: Resolver controller + not-found view + rewrite

**Files:**
- Create: `orkui/controller/controller.Me.php`
- Create: `orkui/template/revised-frontend/Me_notfound.tpl`
- Modify: `.htaccess` (repo root)

**Interfaces:**
- Consumes: `Model_ShortLink::resolve()` (via `$this->load_model('ShortLink')` → `$this->ShortLink`).
- Dispatch: `index.php?Route=Me/go/{stub}` → `new Controller_Me('go','{stub}')` → `$C->go('{stub}')`.
- Route map produced: `player→Player/profile`, `kingdom→Kingdom/profile`, `park→Park/profile`, `unit→Unit/index`.

- [ ] **Step 1: Write a failing curl test (red)**

Run (app must be up: `docker-compose -f docker-compose.php8.yml up -d`):
```bash
curl -s -o /dev/null -w "%{http_code} %{redirect_url}\n" \
  "http://localhost:19080/orkui/index.php?Route=Me/go/pl46193"
```
Expected now: NOT a 302 to a profile (controller doesn't exist → blank/200 or error). This is red.

- [ ] **Step 2: Implement the resolver controller**

Create `orkui/controller/controller.Me.php`:

```php
<?php

class Controller_Me extends Controller
{
    /** entity_type => canonical profile route prefix */
    private $routeMap = [
        'player'  => 'Player/profile/',
        'kingdom' => 'Kingdom/profile/',
        'park'    => 'Park/profile/',
        'unit'    => 'Unit/index/',
    ];

    public function __construct($call = null, $action = null)
    {
        parent::__construct($call, $action);
        $this->load_model('ShortLink');
    }

    public function go($stub = null)
    {
        $hit = $this->ShortLink->resolve($stub);
        if ($hit && isset($this->routeMap[$hit['type']])) {
            header('Location: ' . UIR . $this->routeMap[$hit['type']] . (int)$hit['id'], true, 302);
            exit;
        }
        // Miss: render a friendly not-found page (view() is called by the dispatcher).
        $this->template = '../revised-frontend/Me_notfound.tpl';
        $this->data['stub'] = htmlspecialchars((string)$stub, ENT_QUOTES);
        $this->data['search_url'] = UIR . 'Search/index';
        $this->data['home_url'] = HTTP_UI;
    }
}
```

(Confirm the template-path convention by matching how `controller.Player.php` sets `$this->template` — it uses `'../revised-frontend/Playernew_index.tpl'`. Mirror that exact relative form.)

- [ ] **Step 3: Create the not-found view**

Create `orkui/template/revised-frontend/Me_notfound.tpl` (PLAIN PHP):

```php
<div class="sl-notfound">
    <i class="fas fa-link" aria-hidden="true"></i>
    <h2>Shortcut not found</h2>
    <p>We couldn't find <strong>/me/<?= $stub ?></strong>. It may have been changed or never existed.</p>
    <p>
        <a class="sl-notfound-btn" href="<?= $search_url ?>">Search the ORK</a>
        <a class="sl-notfound-btn sl-notfound-btn--ghost" href="<?= $home_url ?>">Go home</a>
    </p>
</div>
<style>
.sl-notfound{max-width:520px;margin:60px auto;padding:32px;text-align:center;
  background:var(--ork-card-bg,#fff);border:1px solid var(--ork-border,#e2e8f0);border-radius:10px}
.sl-notfound i{font-size:34px;color:#a0aec0;margin-bottom:8px}
.sl-notfound h2{background:transparent;border:none;padding:0;border-radius:0;text-shadow:none;
  margin:6px 0 10px;font-size:22px;color:var(--ork-text,#2d3748)}
.sl-notfound p{color:var(--ork-text-secondary,#4a5568);margin:6px 0}
.sl-notfound-btn{display:inline-block;margin:12px 6px 0;padding:8px 16px;border-radius:6px;
  background:#2b6cb0;color:#fff;text-decoration:none;font-weight:600}
.sl-notfound-btn--ghost{background:transparent;color:var(--ork-text,#2d3748);
  border:1px solid var(--ork-border,#cbd5e0)}
html[data-theme="dark"] .sl-notfound-btn--ghost{color:var(--ork-text-secondary,#cbd5e0)}
</style>
```

(If `View` requires the template to exist under a theme path that differs, mirror an existing simple controller that renders a non-list template; the `../revised-frontend/...` form used by `Controller_Player::profile` is the reference.)

- [ ] **Step 4: Run the curl test (green)**

```bash
curl -s -o /dev/null -w "%{http_code} %{redirect_url}\n" \
  "http://localhost:19080/orkui/index.php?Route=Me/go/pl46193"
curl -s -o /dev/null -w "%{http_code} %{redirect_url}\n" \
  "http://localhost:19080/orkui/index.php?Route=Me/go/k1"
curl -s "http://localhost:19080/orkui/index.php?Route=Me/go/no-such-stub" | grep -o "Shortcut not found"
```
Expected: first two print `302 ...index.php?Route=Player/profile/46193` and `...Route=Kingdom/profile/1`; third prints `Shortcut not found`. Use real active ids from your DB.

- [ ] **Step 5: Add the `/me/` rewrite rule**

Edit repo-root `.htaccess`. Replace the `RewriteEngine Off` block so the engine is on and add the `/me/` rule (this is the infra change approved for deploy):

```apache
<IfModule mod_rewrite.c>
RewriteEngine On
# Vanity shortcut links: /me/{stub} -> orkui router
RewriteRule ^me/([A-Za-z0-9_-]+)/?$ /orkui/index.php?Route=Me/go/$1 [L,QSA]
</IfModule>
```

Add a one-line note in the PR description that production Apache must allow `.htaccess` overrides (or carry the equivalent `RewriteRule` in the vhost). Document the vhost form:
```apache
RewriteRule ^/me/([A-Za-z0-9_-]+)/?$ /orkui/index.php?Route=Me/go/$1 [L,QSA]
```

- [ ] **Step 6: Verify the pretty URL (best-effort in dev)**

```bash
curl -s -o /dev/null -w "%{http_code} %{redirect_url}\n" "http://localhost:19080/me/pl46193"
```
Expected: `302 ...Route=Player/profile/46193`. If the dev container serves the app only under `/orkui/` (no root docroot), this may 404 locally — that's acceptable; the `?Route=Me/go/...` path (Step 4) is the functional contract, and the rewrite is verified in the target environment. Note the outcome in the task notes either way.

- [ ] **Step 7: Commit**

```bash
git add orkui/controller/controller.Me.php orkui/template/revised-frontend/Me_notfound.tpl .htaccess
git commit -m "Add /me/ shortcut resolver, not-found view, and rewrite rule"
```

---

## Task 5: Ajax endpoints `controller.ShortLinkAjax.php`

**Files:**
- Create: `orkui/controller/controller.ShortLinkAjax.php`

**Interfaces:**
- Consumes: `Model_ShortLink::{check,set,release,get_stub,derived}`; `Ork3::$Lib->authorization->HasAuthority`; helpers `valid_id()`.
- Dispatch: `Route=ShortLinkAjax/check` → `$C->check()`; `Route=ShortLinkAjax/save` → `$C->save()`.
- Auth constants: `AUTH_ADMIN`, `AUTH_KINGDOM('Kingdom')`, `AUTH_PARK('Park')`, `AUTH_UNIT('Unit')`, `AUTH_EDIT('edit')`.
- JSON shape: `{status:0, available:bool, reason:str}` (check) and `{status:0, stub:str, url:str}` (save); errors `{status:1|5, error:str}`.

- [ ] **Step 1: Write a failing curl test (red)**

```bash
curl -s "http://localhost:19080/orkui/index.php?Route=ShortLinkAjax/check" \
  -d "type=player&id=46193&slug=tobias"
```
Expected now: empty/HTML (controller absent). Red.

- [ ] **Step 2: Implement the Ajax controller**

Create `orkui/controller/controller.ShortLinkAjax.php`:

```php
<?php

class Controller_ShortLinkAjax extends Controller
{
    public function __construct($call = null, $action = null)
    {
        parent::__construct($call, $action);
        $this->load_model('ShortLink');
    }

    /** POST: type, id, slug -> availability for the management UI. */
    public function check()
    {
        header('Content-Type: application/json');
        $uid  = (int)($this->session->user_id ?? 0);
        $type = strtolower(trim($_POST['type'] ?? ''));
        $id   = (int)($_POST['id'] ?? 0);
        $slug = (string)($_POST['slug'] ?? '');

        if (!$uid) { echo json_encode(['status' => 5, 'error' => 'Not logged in']); exit; }
        if (!$this->canEdit($uid, $type, $id)) {
            echo json_encode(['status' => 5, 'error' => 'Not authorized']); exit;
        }
        $r = $this->ShortLink->check($slug, $type, $id);
        echo json_encode(['status' => 0, 'available' => (bool)$r['available'], 'reason' => $r['reason']]);
        exit;
    }

    /** POST: type, id, slug (empty slug = reset to default). */
    public function save()
    {
        header('Content-Type: application/json');
        $uid  = (int)($this->session->user_id ?? 0);
        $type = strtolower(trim($_POST['type'] ?? ''));
        $id   = (int)($_POST['id'] ?? 0);
        $slug = trim((string)($_POST['slug'] ?? ''));

        if (!$uid) { echo json_encode(['status' => 5, 'error' => 'Not logged in']); exit; }
        if (!$this->canEdit($uid, $type, $id)) {
            echo json_encode(['status' => 5, 'error' => 'Not authorized']); exit;
        }

        if ($slug === '') {
            $this->ShortLink->release($type, $id);
            $stub = $this->ShortLink->derived($type, $id);
            echo json_encode(['status' => 0, 'stub' => $stub, 'url' => $this->meUrl($stub)]);
            exit;
        }

        $res = $this->ShortLink->set($type, $id, $slug, $uid);
        if (($res['Status'] ?? 1) === 0) {
            $stub = $res['Detail'];
            echo json_encode(['status' => 0, 'stub' => $stub, 'url' => $this->meUrl($stub)]);
        } else {
            echo json_encode(['status' => 1, 'error' => $res['Error'] ?? 'Could not save shortcut.']);
        }
        exit;
    }

    /** Authority gate per entity type. */
    private function canEdit($uid, $type, $id)
    {
        if (!valid_id($id)) { return false; }
        $auth = Ork3::$Lib->authorization;
        if ($auth->HasAuthority($uid, AUTH_ADMIN, 0, AUTH_ADMIN)) { return true; }
        switch ($type) {
            case 'player':  return $uid === (int)$id; // self
            case 'kingdom': return $auth->HasAuthority($uid, AUTH_KINGDOM, (int)$id, AUTH_EDIT);
            case 'park':    return $auth->HasAuthority($uid, AUTH_PARK, (int)$id, AUTH_EDIT);
            case 'unit':    return $auth->HasAuthority($uid, AUTH_UNIT, (int)$id, AUTH_EDIT);
            default:        return false;
        }
    }

    private function meUrl($stub)
    {
        // Public-facing short URL. Host comes from config; fall back to current host.
        $host = defined('HTTP_UI') ? preg_replace('#/orkui/?$#', '/', HTTP_UI) : '/';
        return $host . 'me/' . $stub;
    }
}
```

- [ ] **Step 3: Run the curl tests (green)**

Unauthenticated (should be blocked):
```bash
curl -s "http://localhost:19080/orkui/index.php?Route=ShortLinkAjax/check" \
  -d "type=player&id=46193&slug=tobias"
```
Expected: `{"status":5,"error":"Not logged in"}` (or "Not authorized").

Authenticated path: obtain a session cookie by logging in via the dev UI in a browser/curl jar, then re-run `check` and `save` for an entity you control. Expected `check` → `{"status":0,"available":true,...}` for a free slug, `available:false` for `admin`/`k1`-style reserved inputs; `save` → `{"status":0,"stub":"...","url":".../me/..."}`. Verify the row:
```bash
docker-compose -f docker-compose.php8.yml exec -T db \
  mysql -uroot -proot ork -e "SELECT * FROM ork_shortlink;"
```

- [ ] **Step 4: Commit**

```bash
git add orkui/controller/controller.ShortLinkAjax.php
git commit -m "Add ShortLinkAjax check/save endpoints with per-entity authority"
```

---

## Task 6: Shared card CSS + `tnShortlinkInit()` JS helper

**Files:**
- Modify: `orkui/template/revised-frontend/style/revised.css` (append `.sl-card` block)
- Modify: `orkui/template/revised-frontend/script/revised.js` (append `tnShortlinkInit`)

**Interfaces:**
- Produces global `window.tnShortlinkInit(opts)` consumed by Tasks 7–9. `opts`:
  - `root` (string, AJAX base, e.g. `PnConfig.uir` = `.../index.php?Route=`)
  - `prefix` (string, e.g. `ork.amtgard.com/me/` display prefix)
  - `type` (`'player'|'kingdom'|'park'|'unit'`), `id` (int)
  - `defaultStub` (string), `currentStub` (string, '' if none), `canEdit` (bool)
  - `els`: `{input, feedback, saveBtn, resetBtn, copyBtn, currentUrl}` (DOM elements)
- Produces CSS classes: `.sl-card`, `.sl-card__url`, `.sl-card__prefix`, `.sl-input`, `.sl-feedback`(`.ok`/`.bad`), `.sl-btn`, `.sl-copy-btn`.

- [ ] **Step 1: Append the CSS**

Append to `revised.css`:

```css
/* ── Shortcut Link card ───────────────────────────────────────── */
.sl-card{background:var(--ork-card-bg,#fff);border:1px solid var(--ork-border,#e2e8f0);
  border-radius:8px;padding:14px 16px;margin:12px 0}
.sl-card__url{display:flex;align-items:center;gap:8px;font-size:13px;
  color:var(--ork-text,#2d3748);margin-bottom:10px;flex-wrap:wrap}
.sl-card__url code{background:var(--ork-bg-tertiary,#edf2f7);padding:2px 6px;border-radius:4px}
.sl-input-row{display:flex;align-items:center;gap:0;flex-wrap:wrap}
.sl-card__prefix{font-size:13px;color:var(--ork-text-secondary,#4a5568);
  background:var(--ork-bg-tertiary,#edf2f7);border:1px solid var(--ork-border,#e2e8f0);
  border-right:none;border-radius:6px 0 0 6px;padding:7px 8px;white-space:nowrap}
.sl-input{font-size:13px;padding:7px 8px;border:1px solid var(--ork-border,#e2e8f0);
  border-radius:0 6px 6px 0;min-width:140px;color:var(--ork-text,#2d3748);
  background:var(--ork-input-bg,#fff)}
.sl-feedback{font-size:12px;margin:6px 0 0;min-height:16px}
.sl-feedback.ok{color:#2f855a}
.sl-feedback.bad{color:#c53030}
.sl-actions{margin-top:10px;display:flex;gap:8px;flex-wrap:wrap}
.sl-btn{padding:7px 14px;border-radius:6px;border:none;background:#2b6cb0;color:#fff;
  font-weight:600;font-size:13px;cursor:pointer}
.sl-btn:disabled{opacity:.5;cursor:not-allowed}
.sl-btn--ghost{background:transparent;color:var(--ork-text-secondary,#4a5568);
  border:1px solid var(--ork-border,#e2e8f0)}
.sl-copy-btn{padding:4px 8px;border:1px solid var(--ork-border,#e2e8f0);border-radius:4px;
  background:var(--ork-bg-tertiary,#edf2f7);cursor:pointer;color:var(--ork-text-secondary,#4a5568);font-size:12px}
.sl-copy-btn:hover{background:var(--ork-bg-secondary,#e2e8f0)}
html[data-theme="dark"] .sl-input{background:var(--ork-bg-secondary,#2d3748)}
```

(If a `--ork-input-bg` token isn't defined in this file, drop that line; the dark override sets the dark background explicitly.)

- [ ] **Step 2: Append the JS helper**

Append to `revised.js` (uses the file's existing `AUTOCOMPLETE_DEBOUNCE_MS` if present, else define locally):

```javascript
/* ── Shortcut Link management card (shared by Player/Kingdom/Park) ── */
window.tnShortlinkInit = function (opts) {
    var DEBOUNCE = (typeof AUTOCOMPLETE_DEBOUNCE_MS !== 'undefined') ? AUTOCOMPLETE_DEBOUNCE_MS : 250;
    var els = opts.els || {};
    if (!els.input) { return; }

    function escHtmlLocal(s) {
        return String(s).replace(/[&<>"']/g, function (c) {
            return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c];
        });
    }
    function setUrl(stub) {
        if (els.currentUrl) { els.currentUrl.textContent = opts.prefix + stub; }
    }
    function feedback(cls, msg) {
        if (!els.feedback) { return; }
        els.feedback.className = 'sl-feedback ' + cls;
        els.feedback.textContent = msg;
    }

    var lastChecked = '', lastAvailable = false, timer;

    if (!opts.canEdit) { return; } // read-only: card shows the URL + copy only

    els.input.addEventListener('input', function () {
        clearTimeout(timer);
        var slug = this.value.trim().toLowerCase();
        if (els.saveBtn) { els.saveBtn.disabled = true; }
        if (slug === '') { feedback('', ''); return; }
        if (slug === opts.currentStub) { feedback('ok', 'This is your current shortcut.'); return; }
        feedback('', 'Checking…');
        timer = setTimeout(function () {
            var body = 'type=' + encodeURIComponent(opts.type) +
                       '&id=' + encodeURIComponent(opts.id) +
                       '&slug=' + encodeURIComponent(slug);
            fetch(opts.root + 'ShortLinkAjax/check', {
                method: 'POST',
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                credentials: 'same-origin',
                body: body
            }).then(function (r) { return r.json(); }).then(function (d) {
                lastChecked = slug;
                lastAvailable = !!d.available;
                feedback(d.available ? 'ok' : 'bad',
                    (d.available ? '✓ ' : '✗ ') + escHtmlLocal(d.reason || ''));
                if (els.saveBtn) { els.saveBtn.disabled = !d.available; }
            }).catch(function () { feedback('bad', 'Could not check availability.'); });
        }, DEBOUNCE);
    });

    if (els.saveBtn) {
        els.saveBtn.addEventListener('click', function () {
            var slug = els.input.value.trim().toLowerCase();
            if (slug !== lastChecked || !lastAvailable) { return; }
            els.saveBtn.disabled = true;
            var body = 'type=' + encodeURIComponent(opts.type) +
                       '&id=' + encodeURIComponent(opts.id) +
                       '&slug=' + encodeURIComponent(slug);
            fetch(opts.root + 'ShortLinkAjax/save', {
                method: 'POST',
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                credentials: 'same-origin',
                body: body
            }).then(function (r) { return r.json(); }).then(function (d) {
                if (d.status === 0) {
                    opts.currentStub = d.stub;
                    setUrl(d.stub);
                    feedback('ok', 'Saved! Your shortcut is ' + opts.prefix + d.stub);
                } else {
                    feedback('bad', d.error || 'Could not save.');
                    els.saveBtn.disabled = false;
                }
            }).catch(function () { feedback('bad', 'Could not save.'); els.saveBtn.disabled = false; });
        });
    }

    if (els.resetBtn) {
        els.resetBtn.addEventListener('click', function () {
            var body = 'type=' + encodeURIComponent(opts.type) +
                       '&id=' + encodeURIComponent(opts.id) + '&slug=';
            fetch(opts.root + 'ShortLinkAjax/save', {
                method: 'POST',
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                credentials: 'same-origin',
                body: body
            }).then(function (r) { return r.json(); }).then(function (d) {
                if (d.status === 0) {
                    opts.currentStub = '';
                    els.input.value = '';
                    setUrl(d.stub);
                    feedback('ok', 'Reset to default: ' + opts.prefix + d.stub);
                }
            });
        });
    }

    if (els.copyBtn && els.currentUrl) {
        els.copyBtn.addEventListener('click', function () {
            var url = els.currentUrl.textContent;
            var done = function (ok) {
                var orig = els.copyBtn.innerHTML;
                els.copyBtn.innerHTML = ok ? '<i class="fas fa-check"></i> Copied!' : '<i class="fas fa-exclamation-circle"></i>';
                els.copyBtn.disabled = true;
                setTimeout(function () { els.copyBtn.innerHTML = orig; els.copyBtn.disabled = false; }, 1400);
            };
            if (navigator.clipboard && navigator.clipboard.writeText) {
                navigator.clipboard.writeText(url).then(function () { done(true); }, function () { done(false); });
            } else {
                var ta = document.createElement('textarea');
                ta.value = url; ta.style.position = 'fixed'; ta.style.opacity = '0';
                document.body.appendChild(ta); ta.select();
                var ok = false; try { ok = document.execCommand('copy'); } catch (e) {}
                document.body.removeChild(ta); done(ok);
            }
        });
    }
};
```

- [ ] **Step 3: Verify the JS parses (no syntax error)**

Run:
```bash
npx --yes esbuild orkui/template/revised-frontend/script/revised.js --bundle=false > /dev/null && echo "JS OK"
```
Expected: `JS OK` (esbuild parses without error). If `npx`/esbuild is unavailable, run `node --check` on a copy, or load the player page in the browser and confirm no console `SyntaxError`.

- [ ] **Step 4: Commit**

```bash
git add orkui/template/revised-frontend/style/revised.css orkui/template/revised-frontend/script/revised.js
git commit -m "Add shared Shortcut Link card CSS and tnShortlinkInit helper"
```

---

## Task 7: Player profile card (revised-frontend)

**Files:**
- Modify: `orkui/template/revised-frontend/Playernew_index.tpl` (account modal markup + `PnConfig` fields + init call)

**Interfaces:**
- Consumes: `window.tnShortlinkInit` (Task 6); `Model_ShortLink::{get_stub,derived}` for initial values (via the controller that renders this template — `Controller_Player::profile`).
- `PnConfig` is the existing JS config object on this page (see `revised.js` `PnConfig.uir`, `PnConfig.canEditAccount`).

- [ ] **Step 1: Surface current stub + default into the page**

In `orkui/controller/controller.Player.php` `profile()` (the action that sets `$this->template = '../revised-frontend/Playernew_index.tpl'`), add (using the model, not raw DB):
```php
$this->load_model('ShortLink');
$this->data['ShortlinkStub']    = $this->ShortLink->get_stub('player', (int)$id) ?? '';
$this->data['ShortlinkDefault'] = $this->ShortLink->derived('player', (int)$id);
```
Place these near the other `$this->data[...]` assignments in `profile()`.

- [ ] **Step 2: Add the card markup in the account modal**

In `Playernew_index.tpl`, inside the account modal (`pn-acct-overlay`), after the Preferences section and before the Admin section, insert (PLAIN PHP):
```php
<?php $slStub = $ShortlinkStub ?? ''; $slDefault = $ShortlinkDefault ?? ''; ?>
<div class="sl-card" id="sl-card-player">
    <h4 style="background:transparent;border:none;padding:0;text-shadow:none;border-radius:0;">Shortcut Link</h4>
    <div class="sl-card__url">
        <span>Your link:</span>
        <code id="sl-url-player">ork.amtgard.com/me/<?= $slStub !== '' ? $slStub : $slDefault ?></code>
        <button type="button" class="sl-copy-btn" id="sl-copy-player" data-tip="Copy link"><i class="fas fa-copy"></i></button>
    </div>
    <div class="sl-input-row">
        <span class="sl-card__prefix">ork.amtgard.com/me/</span>
        <input type="text" class="sl-input" id="sl-input-player" maxlength="30"
               placeholder="custom-name" value="<?= htmlspecialchars($slStub, ENT_QUOTES) ?>">
    </div>
    <div class="sl-feedback" id="sl-feedback-player"></div>
    <div class="sl-actions">
        <button type="button" class="sl-btn" id="sl-save-player" disabled>Save shortcut</button>
        <button type="button" class="sl-btn sl-btn--ghost" id="sl-reset-player">Reset to default</button>
    </div>
</div>
```

- [ ] **Step 3: Wire the init call**

In the page's inline `<script>` where `PnConfig` is available (same block that reads `PnConfig.canEditAccount`), add:
```php
<script>
(function () {
    if (typeof tnShortlinkInit !== 'function') { return; }
    tnShortlinkInit({
        root: PnConfig.uir,
        prefix: 'ork.amtgard.com/me/',
        type: 'player',
        id: <?= (int)($PlayerId ?? $id ?? 0) ?>,
        defaultStub: <?= json_encode($ShortlinkDefault ?? '') ?>,
        currentStub: <?= json_encode($ShortlinkStub ?? '') ?>,
        canEdit: !!PnConfig.canEditAccount,
        els: {
            input: document.getElementById('sl-input-player'),
            feedback: document.getElementById('sl-feedback-player'),
            saveBtn: document.getElementById('sl-save-player'),
            resetBtn: document.getElementById('sl-reset-player'),
            copyBtn: document.getElementById('sl-copy-player'),
            currentUrl: document.getElementById('sl-url-player')
        }
    });
})();
</script>
```
(Confirm the correct PHP variable for the profile's player id in this template — it is the `$id`/`PlayerId` already used elsewhere in the file. Use the existing one.)

- [ ] **Step 4: Manual verification in the browser**

Start the app, open a player profile you own, open the Account modal. Verify: current link shows `…/me/plNNNN`; typing `tobias` shows green "✓ Available"; typing `admin` or `k1` shows red reserved/taken; Save persists (re-open modal → input prefilled); Copy button flips to "Copied!"; Reset reverts to default. Walk it in **dark mode** (`html[data-theme="dark"]`) — card, input, feedback, buttons all legible.

- [ ] **Step 5: Commit**

```bash
git add orkui/template/revised-frontend/Playernew_index.tpl orkui/controller/controller.Player.php
git commit -m "Add Shortcut Link card to player account modal"
```

---

## Task 8: Kingdom management card (revised-frontend)

**Files:**
- Modify: `orkui/template/revised-frontend/Kingdomnew_index.tpl` (new admin panel + `KnConfig` data + init call)
- Modify: `orkui/controller/controller.Kingdom.php` (`profile()` — surface stub/default via model)

**Interfaces:**
- Consumes: `window.tnShortlinkInit` (Task 6); `KnConfig` (existing; `KnConfig.canEdit`, and a UIR/route base — confirm the field name, e.g. `KnConfig.uir`; if absent, use the page's `UIR` PHP constant printed into the script).

- [ ] **Step 1: Surface current stub + default**

In `controller.Kingdom.php` `profile()`, add (model layer):
```php
$this->load_model('ShortLink');
$this->data['ShortlinkStub']    = $this->ShortLink->get_stub('kingdom', (int)$kingdom_id) ?? '';
$this->data['ShortlinkDefault'] = $this->ShortLink->derived('kingdom', (int)$kingdom_id);
```

- [ ] **Step 2: Add a collapsible admin panel**

In `Kingdomnew_index.tpl`, after the Configuration `.kn-admin-panel` and before Park Titles, insert (PLAIN PHP), matching the existing panel pattern:
```php
<?php $slStub = $ShortlinkStub ?? ''; $slDefault = $ShortlinkDefault ?? ''; ?>
<div class="kn-admin-panel">
    <button class="kn-admin-panel-hdr" id="kn-admin-hdr-shortlink" aria-expanded="false">
        <span><i class="fas fa-link" style="margin-right:6px;color:#a0aec0"></i>Shortcut Link</span>
        <i class="fas fa-chevron-down kn-admin-chevron" id="kn-admin-chev-shortlink"></i>
    </button>
    <div class="kn-admin-panel-body" id="kn-admin-body-shortlink" style="display:none">
        <div class="sl-card" id="sl-card-kingdom">
            <div class="sl-card__url">
                <span>Kingdom link:</span>
                <code id="sl-url-kingdom">ork.amtgard.com/me/<?= $slStub !== '' ? $slStub : $slDefault ?></code>
                <button type="button" class="sl-copy-btn" id="sl-copy-kingdom" data-tip="Copy link"><i class="fas fa-copy"></i></button>
            </div>
            <div class="sl-input-row">
                <span class="sl-card__prefix">ork.amtgard.com/me/</span>
                <input type="text" class="sl-input" id="sl-input-kingdom" maxlength="30"
                       placeholder="custom-name" value="<?= htmlspecialchars($slStub, ENT_QUOTES) ?>">
            </div>
            <div class="sl-feedback" id="sl-feedback-kingdom"></div>
            <div class="sl-actions">
                <button type="button" class="sl-btn" id="sl-save-kingdom" disabled>Save shortcut</button>
                <button type="button" class="sl-btn sl-btn--ghost" id="sl-reset-kingdom">Reset to default</button>
            </div>
        </div>
    </div>
</div>
```
Also wire the header toggle the same way sibling panels do (the page's existing `kn-admin-panel-hdr` click handler may already delegate to all panels — verify; if it's per-id, add a matching toggle for `kn-admin-hdr-shortlink`).

- [ ] **Step 3: Wire the init call**

In the `KnConfig` script block:
```php
<script>
(function () {
    if (typeof tnShortlinkInit !== 'function' || !window.KnConfig) { return; }
    tnShortlinkInit({
        root: (KnConfig.uir || '<?= UIR ?>'),
        prefix: 'ork.amtgard.com/me/',
        type: 'kingdom',
        id: <?= (int)($kingdom_id ?? 0) ?>,
        defaultStub: <?= json_encode($ShortlinkDefault ?? '') ?>,
        currentStub: <?= json_encode($ShortlinkStub ?? '') ?>,
        canEdit: !!KnConfig.canEdit,
        els: {
            input: document.getElementById('sl-input-kingdom'),
            feedback: document.getElementById('sl-feedback-kingdom'),
            saveBtn: document.getElementById('sl-save-kingdom'),
            resetBtn: document.getElementById('sl-reset-kingdom'),
            copyBtn: document.getElementById('sl-copy-kingdom'),
            currentUrl: document.getElementById('sl-url-kingdom')
        }
    });
})();
</script>
```

- [ ] **Step 4: Manual verification (incl. dark mode)**

As a kingdom officer, open the kingdom admin modal → Shortcut Link panel. Verify availability check, save, copy, reset, and that a non-officer never sees an editable card (panel hidden when `KnConfig.canEdit` is false). Dark-mode walk.

- [ ] **Step 5: Commit**

```bash
git add orkui/template/revised-frontend/Kingdomnew_index.tpl orkui/controller/controller.Kingdom.php
git commit -m "Add Shortcut Link panel to kingdom admin"
```

---

## Task 9: Park management card (revised-frontend)

**Files:**
- Modify: `orkui/template/revised-frontend/Parknew_index.tpl` (new admin panel + config + init call)
- Modify: `orkui/controller/controller.Park.php` (`profile()` — surface stub/default via model)

**Interfaces:**
- Consumes: `window.tnShortlinkInit` (Task 6); `PkConfig` (existing; `PkConfig.canEdit`/`$CanEditPark` gate, UIR base — confirm field).

- [ ] **Step 1: Surface current stub + default**

In `controller.Park.php` `profile()`:
```php
$this->load_model('ShortLink');
$this->data['ShortlinkStub']    = $this->ShortLink->get_stub('park', (int)$park_id) ?? '';
$this->data['ShortlinkDefault'] = $this->ShortLink->derived('park', (int)$park_id);
```

- [ ] **Step 2: Add the panel**

In `Parknew_index.tpl`, between the Park Details panel and the Operations panel, insert a `.kn-admin-panel` block identical in structure to Task 8 Step 2 but with `kingdom`→`park` in every id/label:
```php
<?php $slStub = $ShortlinkStub ?? ''; $slDefault = $ShortlinkDefault ?? ''; ?>
<div class="kn-admin-panel">
    <button class="kn-admin-panel-hdr" id="kn-admin-hdr-shortlink-park" aria-expanded="false">
        <span><i class="fas fa-link" style="margin-right:6px;color:#a0aec0"></i>Shortcut Link</span>
        <i class="fas fa-chevron-down kn-admin-chevron" id="kn-admin-chev-shortlink-park"></i>
    </button>
    <div class="kn-admin-panel-body" id="kn-admin-body-shortlink-park" style="display:none">
        <div class="sl-card" id="sl-card-park">
            <div class="sl-card__url">
                <span>Park link:</span>
                <code id="sl-url-park">ork.amtgard.com/me/<?= $slStub !== '' ? $slStub : $slDefault ?></code>
                <button type="button" class="sl-copy-btn" id="sl-copy-park" data-tip="Copy link"><i class="fas fa-copy"></i></button>
            </div>
            <div class="sl-input-row">
                <span class="sl-card__prefix">ork.amtgard.com/me/</span>
                <input type="text" class="sl-input" id="sl-input-park" maxlength="30"
                       placeholder="custom-name" value="<?= htmlspecialchars($slStub, ENT_QUOTES) ?>">
            </div>
            <div class="sl-feedback" id="sl-feedback-park"></div>
            <div class="sl-actions">
                <button type="button" class="sl-btn" id="sl-save-park" disabled>Save shortcut</button>
                <button type="button" class="sl-btn sl-btn--ghost" id="sl-reset-park">Reset to default</button>
            </div>
        </div>
    </div>
</div>
```
Wire the header toggle to match sibling park panels.

- [ ] **Step 3: Wire the init call**

```php
<script>
(function () {
    if (typeof tnShortlinkInit !== 'function' || !window.PkConfig) { return; }
    tnShortlinkInit({
        root: (PkConfig.uir || '<?= UIR ?>'),
        prefix: 'ork.amtgard.com/me/',
        type: 'park',
        id: <?= (int)($park_id ?? 0) ?>,
        defaultStub: <?= json_encode($ShortlinkDefault ?? '') ?>,
        currentStub: <?= json_encode($ShortlinkStub ?? '') ?>,
        canEdit: !!PkConfig.canEdit,
        els: {
            input: document.getElementById('sl-input-park'),
            feedback: document.getElementById('sl-feedback-park'),
            saveBtn: document.getElementById('sl-save-park'),
            resetBtn: document.getElementById('sl-reset-park'),
            copyBtn: document.getElementById('sl-copy-park'),
            currentUrl: document.getElementById('sl-url-park')
        }
    });
})();
</script>
```
(If `PkConfig.canEdit` isn't the gate, use whatever the template already uses — `$CanEditPark` printed as a boolean — to set `canEdit`.)

- [ ] **Step 4: Manual verification (incl. dark mode)** — as a park officer, same checks as Task 8 Step 4.

- [ ] **Step 5: Commit**

```bash
git add orkui/template/revised-frontend/Parknew_index.tpl orkui/controller/controller.Park.php
git commit -m "Add Shortcut Link panel to park admin"
```

---

## Task 10: Unit management card (legacy `Admin_unit.tpl`)

**Files:**
- Modify: `orkui/template/default/Admin_unit.tpl` (card markup + self-contained inline JS — this surface does NOT load `revised.js`)
- Modify: the controller/action that renders `Admin_unit.tpl` (surface stub/default + a `canEdit` flag via model)

**Interfaces:**
- Consumes: `ShortLinkAjax/check` + `/save` (Task 5). Self-contained JS (no `tnShortlinkInit`).
- Confirm which controller renders `Admin_unit.tpl` (search `Admin_unit.tpl` references) and that the manager edit-gate is available there (`HasAuthority($uid, AUTH_UNIT, $unit_id, AUTH_EDIT)`).

- [ ] **Step 1: Surface data into the template**

In the action that renders `Admin_unit.tpl`, add (model layer):
```php
$this->load_model('ShortLink');
$this->data['ShortlinkStub']    = $this->ShortLink->get_stub('unit', (int)$unit_id) ?? '';
$this->data['ShortlinkDefault'] = $this->ShortLink->derived('unit', (int)$unit_id);
$this->data['ShortlinkCanEdit'] = (int)(($uid ?? 0) > 0 &&
    Ork3::$Lib->authorization->HasAuthority((int)$uid, AUTH_UNIT, (int)$unit_id, AUTH_EDIT));
$this->data['ShortlinkUnitId']  = (int)$unit_id;
```
(Use the action's actual `$unit_id`/`$uid` variables.)

- [ ] **Step 2: Add card markup + inline JS**

In `Admin_unit.tpl`, within a settings `.info-container`, insert (PLAIN PHP + self-contained vanilla JS):
```php
<?php $slStub = $ShortlinkStub ?? ''; $slDefault = $ShortlinkDefault ?? ''; $slCanEdit = !empty($ShortlinkCanEdit); $slUnitId = (int)($ShortlinkUnitId ?? 0); ?>
<div class="info-container" id="sl-card-unit">
    <h3 style="background:transparent;border:none;padding:0;text-shadow:none;border-radius:0;">Shortcut Link</h3>
    <p>Unit link:
        <code id="sl-url-unit">ork.amtgard.com/me/<?= $slStub !== '' ? $slStub : $slDefault ?></code>
        <button type="button" id="sl-copy-unit">Copy</button>
    </p>
    <?php if ($slCanEdit): ?>
    <div>
        <span>ork.amtgard.com/me/</span>
        <input type="text" id="sl-input-unit" maxlength="30" placeholder="custom-name"
               value="<?= htmlspecialchars($slStub, ENT_QUOTES) ?>">
    </div>
    <div id="sl-feedback-unit" style="font-size:12px;min-height:16px;margin-top:6px;"></div>
    <button type="button" id="sl-save-unit" disabled>Save shortcut</button>
    <button type="button" id="sl-reset-unit">Reset to default</button>
    <?php endif; ?>
</div>
<?php if ($slCanEdit): ?>
<script>
(function () {
    var ROOT = '<?= UIR ?>', TYPE = 'unit', ID = <?= $slUnitId ?>;
    var PREFIX = 'ork.amtgard.com/me/', CUR = <?= json_encode($slStub) ?>;
    var input = document.getElementById('sl-input-unit'),
        fb = document.getElementById('sl-feedback-unit'),
        saveBtn = document.getElementById('sl-save-unit'),
        resetBtn = document.getElementById('sl-reset-unit'),
        copyBtn = document.getElementById('sl-copy-unit'),
        urlEl = document.getElementById('sl-url-unit');
    var timer, lastChecked = '', lastAvailable = false;
    function fbk(c, m) { fb.style.color = (c === 'ok' ? '#2f855a' : c === 'bad' ? '#c53030' : ''); fb.textContent = m; }
    input.addEventListener('input', function () {
        clearTimeout(timer);
        var slug = this.value.trim().toLowerCase();
        saveBtn.disabled = true;
        if (!slug) { fbk('', ''); return; }
        if (slug === CUR) { fbk('ok', 'Current shortcut.'); return; }
        fbk('', 'Checking…');
        timer = setTimeout(function () {
            fetch(ROOT + 'ShortLinkAjax/check', { method: 'POST',
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, credentials: 'same-origin',
                body: 'type=' + TYPE + '&id=' + ID + '&slug=' + encodeURIComponent(slug) })
              .then(function (r) { return r.json(); }).then(function (d) {
                lastChecked = slug; lastAvailable = !!d.available;
                fbk(d.available ? 'ok' : 'bad', (d.available ? '✓ ' : '✗ ') + (d.reason || ''));
                saveBtn.disabled = !d.available;
            }).catch(function () { fbk('bad', 'Could not check.'); });
        }, 250);
    });
    saveBtn.addEventListener('click', function () {
        var slug = input.value.trim().toLowerCase();
        if (slug !== lastChecked || !lastAvailable) { return; }
        saveBtn.disabled = true;
        fetch(ROOT + 'ShortLinkAjax/save', { method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, credentials: 'same-origin',
            body: 'type=' + TYPE + '&id=' + ID + '&slug=' + encodeURIComponent(slug) })
          .then(function (r) { return r.json(); }).then(function (d) {
            if (d.status === 0) { CUR = d.stub; urlEl.textContent = PREFIX + d.stub; fbk('ok', 'Saved!'); }
            else { fbk('bad', d.error || 'Could not save.'); saveBtn.disabled = false; }
        });
    });
    resetBtn.addEventListener('click', function () {
        fetch(ROOT + 'ShortLinkAjax/save', { method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, credentials: 'same-origin',
            body: 'type=' + TYPE + '&id=' + ID + '&slug=' })
          .then(function (r) { return r.json(); }).then(function (d) {
            if (d.status === 0) { CUR = ''; input.value = ''; urlEl.textContent = PREFIX + d.stub; fbk('ok', 'Reset to default.'); }
        });
    });
    copyBtn.addEventListener('click', function () {
        var url = urlEl.textContent, orig = copyBtn.textContent;
        function done(ok) { copyBtn.textContent = ok ? 'Copied!' : 'Copy failed'; setTimeout(function () { copyBtn.textContent = orig; }, 1400); }
        if (navigator.clipboard && navigator.clipboard.writeText) { navigator.clipboard.writeText(url).then(function () { done(true); }, function () { done(false); }); }
        else { var ta = document.createElement('textarea'); ta.value = url; ta.style.position = 'fixed'; ta.style.opacity = '0'; document.body.appendChild(ta); ta.select(); var ok = false; try { ok = document.execCommand('copy'); } catch (e) {} document.body.removeChild(ta); done(ok); }
    });
})();
</script>
<?php endif; ?>
```

- [ ] **Step 3: Manual verification**

As a unit manager, open the unit admin page. Verify availability check, save (confirm row `entity_type='unit'`), copy, reset. Confirm a non-manager sees only the read-only URL line (no input/buttons, because `$slCanEdit` is false).

- [ ] **Step 4: Commit**

```bash
git add orkui/template/default/Admin_unit.tpl orkui/controller/controller.Unit.php
git commit -m "Add Shortcut Link card to unit admin (legacy template)"
```

(Replace the controller path in `git add` with whichever controller actually renders `Admin_unit.tpl`.)

---

## Task 11: Cross-entity integration pass

**Files:** none new — verification + cleanup.

- [ ] **Step 1: End-to-end resolution matrix**

For one real entity of each type, with a custom stub set, verify both the derived and custom links 302 to the right profile:
```bash
for s in pl46193 k1 p1 u1 tobias; do
  printf "%-10s " "$s"
  curl -s -o /dev/null -w "%{http_code} %{redirect_url}\n" \
    "http://localhost:19080/orkui/index.php?Route=Me/go/$s"
done
```
Expected: each prints `302` + the correct `Route=.../...`. (`tobias` only after you set it on a player.)

- [ ] **Step 2: Stub reassignment releases the old slug**

Set a player's stub to `aaa-test`, then change it to `bbb-test`, then confirm `aaa-test` is free (resolves to not-found) and claimable by another entity:
```bash
curl -s -o /dev/null -w "old=%{http_code} %{redirect_url}\n" \
  "http://localhost:19080/orkui/index.php?Route=Me/go/aaa-test"   # expect not-found (200, no redirect)
```
Confirm `ork_shortlink` has exactly one row for that entity (uq_entity held).

- [ ] **Step 3: Remove the scratch test file**

```bash
rm -f scratchpad/test_shortlink_validate.php
```

- [ ] **Step 4: Final dark-mode walk** of all four cards; confirm no global `h1–h6` gray box leaks on the card headings (each heading carries the transparent reset).

- [ ] **Step 5: Commit any cleanup**

```bash
git add -A -- ':!system/lib/ork3/class.Authorization.php'
git commit -m "Shortcut links: integration verification cleanup" --allow-empty
```
(Verify `git diff --cached` excludes `class.Authorization.php` before committing.)

---

## Self-Review Notes (author check — completed)

- **Spec coverage:** rewrite + resolver (Task 4), derived defaults (Task 2 `DerivedStub`/`Resolve`), custom stubs table (Task 1), one-per-entity + release-on-change (Task 1 `uq_entity` + Task 2 `SetStub`/Task 11 Step 2), validation incl. reserved pattern/words (Task 2 `ValidateSlug`), per-entity authority incl. admin override (Task 5 `canEdit`), live availability + copy + reset cards on all four surfaces (Tasks 7–10), 302s (Task 4), not-found view (Task 4), dark mode (Tasks 6–11), DB-in-lib-only (Tasks 2–3, controllers use model). All covered.
- **Layer rule:** controllers (`Me`, `ShortLinkAjax`, and the four profile controllers) touch only `Model_ShortLink`/`Ork3::$Lib->shortlink`; no raw `$DB`.
- **Type consistency:** entity vocabulary `player|kingdom|park|unit` and prefix map `pl|k|p|u` identical across migration enum, lib constants, model, controllers, and every config object.
- **Known confirm-on-implementation points (flagged inline, not placeholders):** exact `PnConfig`/`KnConfig`/`PkConfig` UIR + canEdit field names; the controller that renders `Admin_unit.tpl`; the yapo quoting helper (`quote` vs `escape`); the container web-root path. Each step says how to confirm.
