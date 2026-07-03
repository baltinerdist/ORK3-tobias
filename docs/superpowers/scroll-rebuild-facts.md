# Scroll Rebuild — Ground-Truth Facts (read-only recon)

Evidence gathered by reading the real code on branch `feature/scroll-generator`.
Every claim below is anchored to `file:line`. Implementation agents should treat
this as authoritative over memory/assumptions.

---

## 1. LIB base class + registration

- **Base class**: `class ScrollArtwork extends Ork3` — `system/lib/ork3/class.ScrollArtwork.php:3`.
  Constructor just calls `parent::__construct()` (`:43-45`).
- **`$this->db`**: comes from the `Ork3` base ctor, which copies the global `$DB`:
  `system/lib/ork3/class.Ork3.php:11-17` — `global $DB; ... $this->db = $DB;`.
  So every lib shares the ONE global Yapo connection (why `Clear()` discipline matters).
- **Registration is fully convention-based, NO manual registry.** `startup.php:39-61`
  scans `DIR_ORK3` (`system/lib/ork3/`), `require_once`s every `class.*.php`, then
  loops again and does:
  ```php
  $class_name = explode('.', basename)[1];   // e.g. "ScrollArtwork"
  $chad_name  = strtolower($class_name);      // "scrollartwork"
  if ($class_name != 'php' && $class_name != 'Ork3')
      $LIB->$chad_name = new $class_name();   // Ork3LibContainer::__set
  Ork3::$Lib = $LIB;                          // startup.php:61
  ```
  `Ork3LibContainer::__set` just stores the property (`class.Ork3.php:26-28`). There
  is no `__get` magic — the property is set eagerly at boot.
- **What a NEW `class.ScrollTemplate.php` must do**: literally nothing beyond
  (a) live in `system/lib/ork3/`, (b) be named `class.ScrollTemplate.php`,
  (c) declare `class ScrollTemplate extends Ork3` with `parent::__construct()`.
  It will auto-resolve as `Ork3::$Lib->scrolltemplate` (lowercased class name). Do
  NOT edit any registry/array. (There is a `$_skipTokenCheck` list in
  `class.Controller.php:40-50` but that is only a stale-session-check bypass list,
  not a registration mechanism.)

---

## 2. `$DB` / db handle usage inside a lib method

All via `$this->db` (the shared Yapo handle). Confirmed idioms in `class.ScrollArtwork.php`:

- **Clear stale bindings**: `$this->db->Clear();` (`:94`, `:151`, `:213`, `:239`, ...). Always before a new bind/query.
- **Bind a param** (magic setter): `$this->db->category_id = $category_id;` (`:95`) → used as `:category_id` in SQL.
- **Read query**: `$r = $this->db->DataSet($sql);` (`:96`, `:245`, `:306`).
- **Write query**: `$this->db->Execute($sql);` (`:189`, `:219`, `:501`).
- **Last insert id**: `$artwork_id = $this->db->GetLastInsertId();` (`:190`, `:1123`).
- **Row count**: `$r->Size()` (`:97`, `:247`, `:314`).
- **Advance cursor**: `$r->Next()` (`:247`, `:308` in a `while`, `:314`).
- **Column read is property access**: `$r->category_id`, `$r->total`, `$r->status`,
  `$r->visibility`, `$r->file_name`, `$r->name` (e.g. `:314`, `:480-482`, `:654`, `:1158`).
  There is **no** `$row->Get('col')` accessor — it's `$row->col`.
- Method names are **case-insensitive** in this codebase: `index.php:71-72` uses the
  same object with lowercase `$DB->query(...)`, `$r->size()`, `$r->next()`. Use the
  Capitalized forms (`DataSet`/`Execute`/`Clear`/`Next`/`Size`/`GetLastInsertId`) to match ScrollArtwork.

---

## 3. Status sentinels — `Success()` / `InvalidParameter()` / `NoAuthorization()`

**Two different `Success()` implementations exist. The lib uses the GLOBAL one, not `Errors::`.**

- The bare functions called by the lib (`Success()`, `NoAuthorization()`,
  `InvalidParameter(null, 'msg')`) are the **global** functions in
  `orkservice/Common.definitions.php:10-62`. Signature match confirms it:
  `InvalidParameter($detail = null, $error = null)` (`:55`) — the lib calls
  `InvalidParameter(null, 'Name is required.')` (`class.ScrollArtwork.php:71`).
- **Shape of `Success()`** (`Common.definitions.php:10-17`):
  ```php
  ['Status' => ServiceErrorIds::Success /* = 0 */, 'Error' => 'Success', 'Detail' => $detail]
  ```
  `ServiceErrorIds::Success = 0` (`Common.definitions.php:82-84`).
- Libs wrap it one level deep: they return `array('Status' => Success(), 'ArtworkId' => ...)`.
  So the **full success envelope** a caller receives is:
  ```php
  ['ArtworkId' => 5, 'Status' => ['Status' => 0, 'Error' => 'Success', 'Detail' => null]]
  ```
- **Success is detectable as `$res['Status']['Status'] === 0`** — YES. This is exactly how
  the ajax controller checks it, e.g. `controller.ScrollArtworkAjax.php:115`:
  ```php
  if (is_array($result['Status']) && isset($result['Status']['Status']) && $result['Status']['Status'] == 0) { ... }
  ```
  Error detail is read from `$result['Status']['Detail'] ?? $result['Status']['Error']`
  (`:124`, `:300`, `:345`).
- **Do NOT use `Errors::Success()`** (`system/lib/system/class.Errors.php:11`). That is a
  *different* shape (`['Result'=>…, 'Status'=>bool, 'Code'=>…, 'Value'=>…]`) and is not
  what the scroll stack uses. Match the existing lib: `return array('Status' => Success());`.

---

## 4. Model → lib resolution

Two coexisting patterns; scroll code uses the **direct-`Ork3::$Lib`** one:

- **Legacy MVC models** use `new APIModel('X')`: `orkui/model/model.Authorization.php:8`
  → `$this->Authorization = new APIModel('Authorization');`. `APIModel::__construct`
  does `new $APISource` and `__call` forwards via `call_user_func_array`
  (`system/lib/system/class.APIModel.php:11-18`). So `APIModel('Authorization')`
  instantiates a fresh `Authorization` lib object (NOT the `Ork3::$Lib` singleton).
- **Scroll code skips the model layer and hits the singleton directly**:
  `controller.ScrollArtworkAjax.php:13` → `$this->sa = Ork3::$Lib->scrollartwork;`.
  This is the recommended pattern for the rebuild — a new `Controller_ScrollTemplateAjax`
  should do `$this->st = Ork3::$Lib->scrolltemplate;` in its constructor. No model file needed.

---

## 5. Routing / controller registration

- **Front controller**: `orkui/index.php`. Route string is `?Route=Xxx/call/action/...`,
  split on `/` (`index.php:80`).
- **Pure convention, NO registry.** `index.php:84-86`:
  ```php
  if (file_exists(DIR_CONTROLLER . 'controller.' . $route[0] . '.php')) {
      include_once(...);
      $class = 'Controller_' . $route[0];   // Controller_ScrollTemplateAjax
  ```
  Dispatch: `$route[1]` is the **method**, `$route[2]` (or the `/`-joined remainder for
  4+ segments) is passed as the **first argument**:
  - 3 segments → `$C = new $class($call, $action); $C->$call($action);` (`:109-113`)
  - 4+ segments → `$action = implode('/', array_slice($route,2)); $C->$call($action);` (`:114-120`)
- **A new `controller.ScrollTemplateAjax.php`** (class `Controller_ScrollTemplateAjax
  extends Controller`) is reachable automatically at `ScrollTemplateAjax/{method}/{arg}`.
  No registry entry anywhere. This is exactly how `controller.ScrollArtworkAjax.php`
  (`class Controller_ScrollArtworkAjax extends Controller`, `:3`) is reached.
- **`list` as an action vs method**:
  - As **route[2] (the action/arg)**: totally fine — it's just a string passed to your method.
  - As **route[1] (the method name)**, i.e. `ScrollTemplateAjax/list`: it is invoked
    dynamically as `$C->$call(...)` (`index.php:108/113/119`), and PHP ≥7 allows methods
    named after reserved words, so `public function list(...)` + dynamic `$C->list()` works.
    BUT `index.php` also calls `required_parameter_count($class, $call)` via
    `ReflectionMethod` for 1- and 2-segment routes (`:92`, `:102`, `:140-149`) — a
    2-segment `ScrollTemplateAjax/list` reflects fine. **Recommendation**: to avoid any
    reserved-word footguns, name the endpoint method something like `list_templates`
    or `browse` rather than bare `list`.

---

## 6. Constants for assets + web-serving

Defined in `config.dev.php` (`define(...)`; prod mirror in `config.php`):

| Constant | Value (`config.dev.php`) | Role |
|---|---|---|
| `HTTP_TEMPLATE` | `HTTP_UI . 'template/'` → `http://HOST/orkui/template/` | `:15` — URL base for theme templates/assets under orkui |
| `DIR_TEMPLATE` | `DIR_UI . 'template/'` → `<repo>/orkui/template/` | `:74` — disk path for `.tpl` files |
| `HTTP_ASSETS` | `http://HOST/assets/` | `:16` — URL base for the repo-root `assets/` tree |
| `DIR_ASSETS` | `DIR_BASENAME . 'assets/'` → `<repo>/assets/` | `:47` — disk path of repo-root `assets/` |
| `UIR` | `HTTP_UI_REMOTE . 'index.php?Route='` | `orkui/index.php:4` — **already ends in `?Route=`**; append route + use `&q=` for extra params, never `?q=` (empties `$_GET['q']`) |
| `HTTP_SCROLL_ARTWORK` | `HTTP_ASSETS . 'scroll/artwork/'` | `:36` — URL for uploaded artwork |
| `DIR_SCROLL_ARTWORK` | `DIR_ASSETS . 'scroll/artwork/'` → `<repo>/assets/scroll/artwork/` | `:63` — disk path for uploaded artwork |

- **Web-serving model**: `docker-compose.php8.yml:11` mounts the whole repo root at
  `.:/var/www/ork.amtgard.com`, and that is the Apache docroot. So **any repo path is
  URL-addressable relative to host root** — `/orkui/…`, `/assets/…`, AND `/system/…`.
- **Two distinct scroll asset trees** (do not conflate):
  - `assets/scroll/` (repo-root) — the web/upload tree behind `HTTP_ASSETS`/`DIR_ASSETS`
    (`assets/scroll/` exists: `backgrounds/ borders/ heraldry/ orders/ catalog.json`).
    Note: `assets/scroll/packs/` does **not** exist; `packs/` lives under `system/`.
  - `system/assets/scroll/` — the **system-curated** tree (`packs/ families/ forge/`),
    served directly because the whole repo is under docroot. It is referenced by
    **literal path, NOT a constant**: JS uses `/system/assets/scroll/families`
    (`scroll/scroll-decoration.js:18`) and `/system/assets/scroll/forge/alphabets/…`
    (`Scroll_builder.tpl:13174`).
- **`system/assets/scroll/packs/` addresses**:
  - **From a browser**: `http://localhost:19080/system/assets/scroll/packs/` (e.g.
    `.../packs/catalog.json`).
  - **From PHP (disk)**: `<repo>/system/assets/scroll/packs/`. In Docker that is
    `/var/www/ork.amtgard.com/system/assets/scroll/packs/`. `ScrollDecoration::assetDir()`
    (`class.ScrollDecoration.php:28-34`) shows the canonical resolve pattern: prefer the
    hard-coded Docker path if `is_dir`, else `realpath(__DIR__ . '/../../assets/scroll/…')`
    (from `system/lib/ork3/`, `../../` reaches `system/`). Copy this pattern for a
    `packs/` resolver; there is no `DIR_SCROLL_PACKS` constant.
- **`vendor/` / SimpleXlsx**: there is **no repo-root `vendor/`** and **no
  `TournamentExport`/`SimpleXlsx` on this branch** (`find` for both returns nothing;
  the only `SimpleXlsx` hit is a doc). `.gitignore:32` lists `vendor`. Per project memory
  the xlsx stack lives on a different branch and is force-added (`git add -f`). **Do not
  depend on a web-served `vendor/` for the scroll rebuild** — none exists here.

---

## 7. `controller.Scroll.php::builder()` — exact variable names to reuse

`orkui/controller/controller.Scroll.php`, method `builder($id)` (`:21`). Template is
`../revised-frontend/Scroll_builder.tpl` (`:22`). Values are put on `$this->data[...]`:

```php
$this->data['kingdom_name']         // :33 default '';  :66 = KingdomInfo['KingdomName']
$this->data['park_name']            // :34 default '';  :64 = ParkInfo['ParkName']
$this->data['kingdom_heraldry_url'] // :35 default '';  :80 = $kingdom_info['HeraldryUrl']['Url']
$this->data['park_heraldry_url']    // :36 default '';  :72 = $park_details['Heraldry']['Url']
$this->data['player_heraldry_url']  // :37 default '';  :53-55 = $player['Heraldry'] or HTTP_PLAYER_HERALDRY.'000000.jpg'
```

Supporting/context vars also set: `$this->data['kingdom_id']` (`:84`),
`$this->data['park_id']` (`:85`), `$this->data['player']` (`:50`),
`$this->data['session_user_id']` (`:38`), `$this->data['session_token']` (`:44`),
`$this->data['preload_officers']` (`:110`).

Source calls: player via `$this->Player->fetch_player($mundane_id)` (`:48`), park via
`$this->Park->get_park_info($park_id)` (`:62`) + `get_park_details($park_id)` (`:70`),
kingdom via `$this->Kingdom->get_kingdom_shortinfo($kingdom_id)` (`:78`).

---

## 8. CLI test bootstrap for `Ork3::$Lib`

`test_php_render.php` / `test_curated_assets.php` do **NOT** boot the runtime — they
`require_once` the individual `class.Scroll*.php` files directly and call static
renderers (`test_php_render.php:4-7`, `test_curated_assets.php:14-17`). They never touch
`Ork3::$Lib` or `$DB`.

The DB-touching test that DOES boot the full runtime is
`tests/scroll/test_moderation_authority.php:11-21` — **copy this block** for any new
lib/DB test:

```php
require_once __DIR__ . '/lib/assert.php';

// Bootstrap the ORK runtime so $DB + Ork3::$Lib are available (CLI-safe).
chdir(__DIR__ . '/../../orkui');
if (!isset($_SERVER['HTTP_HOST'])) {
    $_SERVER['HTTP_HOST'] = 'localhost';
}
putenv('ENVIRONMENT=DEV');
require_once __DIR__ . '/../../startup.php';

$sa = Ork3::$Lib->scrollartwork;   // → for a new lib: Ork3::$Lib->scrolltemplate
```

Notes: `chdir` into `orkui` + `HTTP_HOST=localhost` are required because `config.dev.php`
builds URL constants from `$_SERVER['HTTP_HOST']` and relative includes assume the ui cwd.
`ENVIRONMENT=DEV` selects `config.dev.php` (`startup.php:3-7`). After `startup.php`,
`$DB` and the entire `Ork3::$Lib->*` container are live. This connects to the real dev DB
(`ork3-php8-db`), so it must run inside/against the Docker DB.
