# ORK API Rehabilitation v2 — Phase 1 (Foundation + Player Pilot) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up a versioned, self-documenting REST API tier (`/api/v2/`) over a transport-agnostic application-service seam, proven end-to-end on the Player resource, with a token-acquisition endpoint and an auth-gated Scalar developer portal.

**Architecture:** Three new layers — `orkapi/` (REST transport: router, stateless Bearer auth, controllers + OpenAPI schema classes, Scalar portal), `system/lib/app/` (typed application services + **pure** DTOs + typed exceptions; strangler-fig over legacy `class.*`), and an `ork_api_developer` allowlist gating the portal. Legacy SOAP/JSON-RPC (`orkservice/`) and `class.*` are untouched. OpenAPI 3.1 is generated from PHP-8 attributes (in the transport layer only) at build time into a committed `openapi.json` served statically.

**Tech Stack:** PHP 8.1, MariaDB (PDO via Yapo), nginx + php-fpm (Docker), **`zircote/swagger-php ^5.0`** (build-time only; v4 cannot emit 3.1), Scalar (pinned single-file JS embed). No runtime composer; PSR-4 autoload for the two new namespaces.

**Reference spec:** `docs/superpowers/specs/2026-06-13-api-rehabilitation-v2-design.md`

> **This plan was revised after a 3-reviewer critique (architect / API-OpenAPI / mobile).** All blocker claims were verified against real code. See the spec's "Review Revisions" section. Verified facts baked into this plan:
> - `class.Player` uses the **global** result helpers (`orkservice/Common.definitions.php`): `Success($detail)` → `['Status'=>0,'Error'=>'Success','Detail'=>$detail]`; `InvalidParameter()` → `['Status'=>4,…]`; `NoAuthorization()` → `['Status'=>5,…]`. (NOT the `Errors::` class, which is `{Status:bool,Code,…}` and is used only by JsonServer.) Success check is `(int)$resp['Status']['Status'] === 0`.
> - `CreatePlayer` (`class.Player.php:644`) saves then `$new_mundane_id=(int)$this->mundane->mundane_id` and returns the global `Success($new_mundane_id)` → **new id is in `$resp['Status']['Detail']`** (implementer: confirm the exact final `return` line — it may return `Success($id)` or the re-fetched player; map accordingly).
> - **`class.Player` has NO `DeletePlayer`.** Hard DELETE is omitted from the pilot.
> - `mysql_real_escape_string` is redefined as a **no-op** in `startup.php`; `$DB->DBH` is a **private** PDO handle; there is **no `$DB->Escape()`**. New code escapes via a centralized helper (Task 4).
> - `Authorization::IsAuthorized()` is hard-wired `|| true` → always `IsAuthorized_h`, which **returns `$_SESSION['is_authorized_mundane_id']` before validating the token** and **never checks `token_expires`**. The v2 tier therefore validates tokens **statelessly** itself (Task 11) and never starts a session.

---

## Conventions used throughout

- **Containers:** `ork3-php8-app` (web/PHP, docroot `/var/www/ork.amtgard.com`), `ork3-php8-db` (MariaDB).
- **Run PHP:** `docker exec ork3-php8-app php <path-under-docroot>`. **Apply migration:** `docker exec -i ork3-php8-db mariadb -u root -proot ork < db-migrations/<file>.sql`. **Errors:** `docker logs ork3-php8-app`.
- **Staging rule:** never `git add -A`/`.`; stage explicitly; never stage `system/lib/ork3/class.Authorization.php`; `git diff --cached` before every commit.
- **New files are written PSR-12 (4-space)** so they stay clean for the pre-commit formatter.
- **Namespaces:** `Ork\Api\…` → `orkapi/src/`, `Ork\App\…` → `system/lib/app/` (PSR-4 register in `orkapi/bootstrap.php`). Legacy `scandir` autoloader never touches them.
- **Tests:** pure units = framework-free scripts via `orkapi/tests/assert.php`; service/controller tests boot the legacy runtime + live DB (integration-grade — labeled so). Integration HTTP tests use curl + a real token from `POST /api/v2/sessions`.

---

## File Structure (Phase 1)

```
orkapi/
  index.php                      # front controller: CORS/OPTIONS, ping, openapi.json, dispatch (T1,T9,T20)
  bootstrap.php                  # startup.php + PSR-4; asserts no session (T2)
  routes.php                     # resource -> controller registry (T9)
  openapi.json                   # generated, committed (T20)
  src/
    Db/Sql.php                   # centralized escaping helper (T4)
    Http/RestRequest.php         # verb/path(+PATH_INFO)/query/body/bearer/malformed flag (T5)
    Http/ApiResponse.php         # status+body; 204 no content-type (T6)
    Http/Problem.php             # error envelope builder (T6)
    Http/RestRouter.php          # registry + dispatch + 404/405/exception mapping (T9)
    Exception/                   # ApiException + NotFound/Validation/Unauthenticated/Forbidden/
                                 #   Conflict/MalformedRequest(400)/MethodNotAllowed(405) (T7)
    Legacy/LegacyEnvelope.php    # global {Status:int} envelope -> typed exception (T8)
    Auth/Identity.php            # caller id + scope checks (T10)
    Auth/AuthMiddleware.php      # STATELESS token resolver w/ expiry (T11)
    Controller/BaseRestController.php  # verb-dispatch; resolve Identity once; 405+Allow (T12)
    Controller/RestPlayerController.php # GET/POST/PATCH players (T17,T18)
    Controller/SessionController.php    # POST /sessions login (T19)
    OpenApi/Info.php             # #[OA\OpenApi 3.1] + Info + Server + bearerAuth + tags (T20)
    Schema/PlayerSchema.php      # #[OA\Schema Player] (transport owns docs; DTO stays pure) (T14)
    Schema/Envelopes.php         # #[OA\Schema] ApiError, PageMeta, PlayerListResponse (T14)
  tests/ assert.php run-all.sh
    Db/SqlTest.php  Http/*Test.php  Exception/ApiExceptionTest.php  Legacy/LegacyEnvelopeTest.php
    Auth/IdentityTest.php Auth/AuthMiddlewareTest.php App/PlayerServiceTest.php App/PlayerListTest.php
    integration/ api.sh players_read.sh players_write.sh routing.sh sessions.sh

system/lib/app/Player/
  PlayerDTO.php                  # PURE typed DTO + fromLegacy()/toArray() (T13)
  PlayerService.php              # getPlayer/listPlayers/create/update (T15,T16,T18)

orkui/
  controller/controller.Developer.php          # Scalar portal (T21)
  controller/controller.AdminAjax.php          # +apidev list/add/remove (T22, MODIFY)
  template/default/Developer_index.tpl         # Scalar embed, pinned (T21)
  template/default/Admin_apidevelopers.tpl     # allowlist mgmt UI (T22)
  template/default/Admin_index.tpl             # +sidebar entry (T22, MODIFY)

db-migrations/2026-06-13-add-ork-api-developer.sql       # allowlist table (T22)
tools/openapi/composer.json    # zircote/swagger-php ^5.0 (T20)
bin/openapi-gen.php            # scan -> orkapi/openapi.json, --check (T20)
nginx.ork3.config             # + location /api/v2/ (PATH_INFO-preserving) (T1, MODIFY)
agent-instructions/api-v2-conventions.md   # SDLC reference (T23)
.githooks/pre-commit          # + openapi freshness (T23, MODIFY)
```

---

## Task 1: nginx routing (PATH_INFO-preserving) + front controller + CORS/OPTIONS

**Files:** Create `orkapi/index.php`; Modify `nginx.ork3.config`.

- [ ] **Step 1: Add the nginx location block (preserve the path as PATH_INFO).**

In `nginx.ork3.config`, after the `location / { ... }` block:

```nginx
    # ORK REST API v2 — clean paths route to the orkapi front controller,
    # preserving the resource path as PATH_INFO (note $uri after the script).
    location /api/v2/ {
        try_files $uri /orkapi/index.php$uri$is_args$args;
    }
```

> Rationale (verified review finding): `try_files .../orkapi/index.php$is_args$args` (no `$uri`) would make `REQUEST_URI` = `/orkapi/index.php?...` and the resource misparse to `index.php`. Appending `$uri` preserves `/players/1` as `PATH_INFO`; `RestRequest` (Task 5) reads `PATH_INFO` first.

- [ ] **Step 2: Stub front controller (full body restored in Tasks 9/20).**

Create `orkapi/index.php`:

```php
<?php
header('Content-Type: application/json');
echo json_encode(['pong' => true, 'version' => 'v2', 'stub' => true]);
```

- [ ] **Step 3: Rebuild + restart so nginx picks up the change.**

Run: `docker compose -f docker-compose.php8.yml up -d --build`
Expected: containers rebuild and start cleanly.

- [ ] **Step 4: Verify both URL forms route to the front controller.**

Run:
```bash
curl -s http://localhost:19080/api/v2/ping
curl -s http://localhost:19080/orkapi/index.php/ping
```
Expected: both print `{"pong":true,"version":"v2","stub":true}`.

- [ ] **Step 5: Commit.**

```bash
git add orkapi/index.php nginx.ork3.config
git diff --cached
git commit -m "Enhancement: orkapi v2 front controller + nginx /api/v2 routing (PATH_INFO)"
```

---

## Task 2: Bootstrap + PSR-4 autoloader (stateless)

**Files:** Create `orkapi/bootstrap.php`.

- [ ] **Step 1: Write the bootstrap.**

Create `orkapi/bootstrap.php`:

```php
<?php

/**
 * Bootstrap for the v2 REST API tier and tooling.
 * - Boots the legacy runtime (constants, $DB, Ork3::$Lib) via startup.php.
 * - Registers PSR-4 for the NEW namespaces only.
 * - The v2 tier is STATELESS: it must NOT start a PHP session, so the legacy
 *   Authorization session short-circuit ($_SESSION['is_authorized_mundane_id'])
 *   never fires for API requests. AuthMiddleware validates tokens directly.
 */

require_once __DIR__ . '/../startup.php';

// Defense in depth: ensure no session leaks ambient identity into the API.
if (session_status() === PHP_SESSION_ACTIVE) {
    // A session was unexpectedly started upstream; drop the cached auth so the
    // Bearer token is the sole credential.
    unset($_SESSION['is_authorized_mundane_id']);
}

spl_autoload_register(static function (string $class): void {
    static $prefixes = [
        'Ork\\Api\\' => __DIR__ . '/src/',
        'Ork\\App\\' => __DIR__ . '/../system/lib/app/',
    ];
    foreach ($prefixes as $prefix => $baseDir) {
        if (strncmp($class, $prefix, strlen($prefix)) !== 0) {
            continue;
        }
        $relative = substr($class, strlen($prefix));
        $file = $baseDir . str_replace('\\', '/', $relative) . '.php';
        if (is_file($file)) {
            require_once $file;
        } else {
            error_log("[orkapi] autoload miss for $class -> $file");
        }
        return;
    }
});
```

- [ ] **Step 2: Verify boot + that no session is active.**

Run:
```bash
docker exec ork3-php8-app php -r 'require "/var/www/ork.amtgard.com/orkapi/bootstrap.php"; echo ((Ork3::$Lib && defined("DB_PREFIX")) ? "BOOT_OK " : "BOOT_FAIL "); echo (session_status()===PHP_SESSION_ACTIVE?"SESSION_ACTIVE\n":"NO_SESSION\n");'
```
Expected: `BOOT_OK NO_SESSION`.

- [ ] **Step 3: Commit.**

```bash
git add orkapi/bootstrap.php
git commit -m "Enhancement: orkapi stateless bootstrap + PSR-4 autoload"
```

---

## Task 3: Test harness

**Files:** Create `orkapi/tests/assert.php`, `orkapi/tests/run-all.sh`.

- [ ] **Step 1: Write the assertion helper.**

Create `orkapi/tests/assert.php`:

```php
<?php

require_once __DIR__ . '/../bootstrap.php';

$GLOBALS['__T_PASS'] = 0;
$GLOBALS['__T_FAIL'] = 0;

function t_ok(bool $cond, string $name): void
{
    if ($cond) { $GLOBALS['__T_PASS']++; echo "  PASS  $name\n"; }
    else { $GLOBALS['__T_FAIL']++; echo "  FAIL  $name\n"; }
}

function t_eq($expected, $actual, string $name): void
{
    $cond = $expected === $actual;
    t_ok($cond, $name);
    if (!$cond) {
        echo "        expected: " . var_export($expected, true) . "\n";
        echo "        actual:   " . var_export($actual, true) . "\n";
    }
}

function t_throws(callable $fn, string $exceptionClass, string $name): void
{
    try { $fn(); t_ok(false, "$name (no exception thrown)"); }
    catch (\Throwable $e) { t_ok($e instanceof $exceptionClass, "$name (got " . get_class($e) . ")"); }
}

function t_done(): void
{
    echo "\n  {$GLOBALS['__T_PASS']} passed, {$GLOBALS['__T_FAIL']} failed\n";
    exit($GLOBALS['__T_FAIL'] === 0 ? 0 : 1);
}
```

- [ ] **Step 2: Write the runner.**

Create `orkapi/tests/run-all.sh`:

```bash
#!/usr/bin/env bash
set -u
fail=0
for f in $(find orkapi/tests -name '*Test.php' | sort); do
    echo "== $f =="
    docker exec ork3-php8-app php "/var/www/ork.amtgard.com/$f" || fail=1
done
exit $fail
```

- [ ] **Step 3: Smoke-test.**

Run:
```bash
docker exec ork3-php8-app php -r 'require "/var/www/ork.amtgard.com/orkapi/tests/assert.php"; t_eq(2,1+1,"add"); t_done();'
```
Expected: `PASS add`, `1 passed, 0 failed`, exit 0.

- [ ] **Step 4: Commit.**

```bash
chmod +x orkapi/tests/run-all.sh
git add orkapi/tests/assert.php orkapi/tests/run-all.sh
git commit -m "Enhancement: orkapi framework-free test harness"
```

---

## Task 4: Centralized SQL escaping helper

**Files:** Create `orkapi/src/Db/Sql.php`; Test `orkapi/tests/Db/SqlTest.php`.

> There is no `$DB->Escape()`, the PDO handle is private, and `mysql_real_escape_string` is a no-op. All v2 raw SQL goes through this one helper so the 17-resource fan-out shares a single, correct escape. IDs are always integer-cast; only string literals use `Sql::quote()`.

- [ ] **Step 1: Failing test.**

Create `orkapi/tests/Db/SqlTest.php`:

```php
<?php

require_once __DIR__ . '/../assert.php';

use Ork\Api\Db\Sql;

t_eq("'abc'", Sql::quote('abc'), 'simple quote');
t_eq("'O''Brien'", Sql::quote("O'Brien"), 'single quote doubled');
t_eq("'a\\\\b'", Sql::quote('a\\b'), 'backslash escaped');
t_eq("'5'", Sql::quote('5'), 'numeric string still quoted');
// LIKE term: caller wraps wildcards AFTER escaping literal % and _
t_eq('25', Sql::int('25abc'), 'int cast strips');
t_eq(0, Sql::int('abc'), 'int cast non-numeric -> 0');

t_done();
```

- [ ] **Step 2: Run → fail (class not found).**

Run: `docker exec ork3-php8-app php /var/www/ork.amtgard.com/orkapi/tests/Db/SqlTest.php`

- [ ] **Step 3: Implement.**

Create `orkapi/src/Db/Sql.php`:

```php
<?php

namespace Ork\Api\Db;

/** The single, correct SQL-literal escaper for the v2 tier (MySQL, default mode). */
final class Sql
{
    /** Quote a string literal: escape backslash and single-quote, wrap in quotes. */
    public static function quote(string $s): string
    {
        $escaped = str_replace(['\\', "'"], ['\\\\', "''"], $s);
        return "'" . $escaped . "'";
    }

    /** Escape a value for use inside a LIKE pattern (caller adds %/_ wildcards). */
    public static function likeLiteral(string $s): string
    {
        return str_replace(['\\', '%', '_'], ['\\\\', '\\%', '\\_'], $s);
    }

    public static function int($v): int
    {
        return (int) $v;
    }
}
```

- [ ] **Step 4: Run → pass.** Same command as Step 2.

- [ ] **Step 5: Commit.**

```bash
git add orkapi/src/Db/Sql.php orkapi/tests/Db/SqlTest.php
git commit -m "Enhancement: orkapi centralized SQL escaping helper"
```

---

## Task 5: RestRequest (PATH_INFO + malformed-JSON flag)

**Files:** Create `orkapi/src/Http/RestRequest.php`; Test `orkapi/tests/Http/RestRequestTest.php`.

- [ ] **Step 1: Failing test.**

Create `orkapi/tests/Http/RestRequestTest.php`:

```php
<?php

require_once __DIR__ . '/../assert.php';

use Ork\Api\Http\RestRequest;

$req = RestRequest::build('GET', '/api/v2/players/123', ['expand' => 'units'], [], ['Authorization' => 'Bearer abc123'], false);
t_eq('GET', $req->method(), 'method');
t_eq('players', $req->resource(), 'resource');
t_eq(123, $req->id(), 'id int');
t_eq(null, $req->subresource(), 'no subresource');
t_eq('units', $req->query('expand'), 'query');
t_eq('def', $req->query('missing', 'def'), 'query default');
t_eq('abc123', $req->bearerToken(), 'bearer');
t_ok(!$req->bodyWasMalformed(), 'body not malformed');

$coll = RestRequest::build('GET', '/api/v2/players', [], [], [], false);
t_eq('players', $coll->resource(), 'collection resource');
t_eq(null, $coll->id(), 'collection no id');
t_eq(null, $coll->bearerToken(), 'no bearer null');

$pi = RestRequest::build('GET', '/players/5', [], [], [], false); // PATH_INFO form (already stripped)
t_eq('players', $pi->resource(), 'pathinfo resource');
t_eq(5, $pi->id(), 'pathinfo id');

$sub = RestRequest::build('GET', '/api/v2/players/123/awards', [], [], [], false);
t_eq('awards', $sub->subresource(), 'subresource');

$bad = RestRequest::build('POST', '/api/v2/players', [], [], [], true);
t_ok($bad->bodyWasMalformed(), 'malformed flag propagates');

t_done();
```

- [ ] **Step 2: Run → fail.** `docker exec ork3-php8-app php /var/www/ork.amtgard.com/orkapi/tests/Http/RestRequestTest.php`

- [ ] **Step 3: Implement.**

Create `orkapi/src/Http/RestRequest.php`:

```php
<?php

namespace Ork\Api\Http;

final class RestRequest
{
    /** @var string[] */
    private array $segments;

    private function __construct(
        private string $method,
        array $segments,
        private array $query,
        private array $body,
        private array $headers,
        private bool $bodyMalformed
    ) {
        $this->segments = $segments;
    }

    public static function fromGlobals(): self
    {
        // Prefer PATH_INFO (set by nginx try_files $uri); fall back to REQUEST_URI.
        $rawPath = $_SERVER['PATH_INFO'] ?? (parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?? '/');
        $headers = function_exists('getallheaders') ? (getallheaders() ?: []) : [];

        $body = [];
        $malformed = false;
        $raw = file_get_contents('php://input') ?: '';
        if ($raw !== '') {
            $decoded = json_decode($raw, true);
            if (is_array($decoded)) {
                $body = $decoded;
            } else {
                $malformed = true; // non-empty body that isn't valid JSON object/array
            }
        }
        if (!$body && !$malformed && !empty($_POST)) {
            $body = $_POST;
        }

        return self::build($_SERVER['REQUEST_METHOD'] ?? 'GET', $rawPath, $_GET ?? [], $body, $headers, $malformed);
    }

    public static function build(string $method, string $rawPath, array $query, array $body, array $headers, bool $bodyMalformed = false): self
    {
        $path = $rawPath;
        foreach (['/api/v2/', '/orkapi/index.php/'] as $prefix) {
            if (str_starts_with($path, $prefix)) {
                $path = substr($path, strlen($prefix));
                break;
            }
        }
        $path = trim($path, '/');
        $segments = $path === '' ? [] : array_values(array_filter(explode('/', $path), 'strlen'));

        $norm = [];
        foreach ($headers as $k => $v) {
            $norm[strtolower($k)] = $v;
        }

        return new self(strtoupper($method), $segments, $query, $body, $norm, $bodyMalformed);
    }

    public function method(): string { return $this->method; }
    public function resource(): ?string { return $this->segments[0] ?? null; }
    public function id(): ?int
    {
        return isset($this->segments[1]) && ctype_digit($this->segments[1]) ? (int) $this->segments[1] : null;
    }
    public function subresource(): ?string { return $this->segments[2] ?? null; }
    public function query(string $k, $d = null) { return $this->query[$k] ?? $d; }
    public function bodyParam(string $k, $d = null) { return $this->body[$k] ?? $d; }
    public function body(): array { return $this->body; }
    public function bodyWasMalformed(): bool { return $this->bodyMalformed; }
    public function bearerToken(): ?string
    {
        $auth = $this->headers['authorization'] ?? '';
        if (stripos($auth, 'Bearer ') === 0) {
            return trim(substr($auth, 7)) ?: null;
        }
        return null;
    }
}
```

- [ ] **Step 4: Run → pass.** Same command as Step 2.

- [ ] **Step 5: Commit.**

```bash
git add orkapi/src/Http/RestRequest.php orkapi/tests/Http/RestRequestTest.php
git commit -m "Enhancement: orkapi RestRequest (PATH_INFO + malformed-body flag)"
```

---

## Task 6: ApiResponse + Problem (204 emits no Content-Type)

**Files:** Create `orkapi/src/Http/ApiResponse.php`, `orkapi/src/Http/Problem.php`; Test `orkapi/tests/Http/ApiResponseTest.php`.

- [ ] **Step 1: Failing test.**

Create `orkapi/tests/Http/ApiResponseTest.php`:

```php
<?php

require_once __DIR__ . '/../assert.php';

use Ork\Api\Http\ApiResponse;
use Ork\Api\Http\Problem;

t_eq(200, ApiResponse::ok(['a' => 1])->status(), 'ok 200');
t_eq(['a' => 1], ApiResponse::ok(['a' => 1])->body(), 'ok body');
t_eq(201, ApiResponse::created(['id' => 7])->status(), 'created 201');
t_eq(204, ApiResponse::noContent()->status(), 'noContent 204');
t_eq(null, ApiResponse::noContent()->body(), 'noContent null');

$err = ApiResponse::error(404, Problem::make('not_found', 'Player not found'));
t_eq(404, $err->status(), 'error status');
t_eq('not_found', $err->body()['error']['code'], 'envelope code');
t_eq('Player not found', $err->body()['error']['message'], 'envelope message');

$v = ApiResponse::error(422, Problem::make('validation_failed', 'bad', ['persona' => 'required']));
t_eq(['persona' => 'required'], $v->body()['error']['details'], 'envelope details');

t_done();
```

- [ ] **Step 2: Run → fail.**

- [ ] **Step 3: Implement Problem** (`orkapi/src/Http/Problem.php`):

```php
<?php

namespace Ork\Api\Http;

final class Problem
{
    public static function make(string $code, string $message, $details = null): array
    {
        $error = ['code' => $code, 'message' => $message];
        if ($details !== null) {
            $error['details'] = $details;
        }
        return ['error' => $error];
    }
}
```

- [ ] **Step 4: Implement ApiResponse** (`orkapi/src/Http/ApiResponse.php`):

```php
<?php

namespace Ork\Api\Http;

final class ApiResponse
{
    private function __construct(private int $status, private ?array $body)
    {
    }

    public static function ok(array $data, int $status = 200): self { return new self($status, $data); }
    public static function created(array $data): self { return new self(201, $data); }
    public static function noContent(): self { return new self(204, null); }
    public static function error(int $status, array $envelope): self { return new self($status, $envelope); }

    public function status(): int { return $this->status; }
    public function body(): ?array { return $this->body; }

    /** @param array<string,string> $extraHeaders */
    public function send(array $extraHeaders = []): void
    {
        http_response_code($this->status);
        foreach ($extraHeaders as $k => $v) {
            header("$k: $v");
        }
        if ($this->body === null) {
            return; // 204/no-body: do not emit a Content-Type or body
        }
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode($this->body, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    }
}
```

- [ ] **Step 5: Run → pass. Step 6: Commit.**

```bash
git add orkapi/src/Http/ApiResponse.php orkapi/src/Http/Problem.php orkapi/tests/Http/ApiResponseTest.php
git commit -m "Enhancement: orkapi ApiResponse + Problem envelope (204 no content-type)"
```

---

## Task 7: Typed exception hierarchy (incl. 400 + 405)

**Files:** Create `orkapi/src/Exception/{ApiException,NotFoundException,ValidationException,UnauthenticatedException,ForbiddenException,ConflictException,MalformedRequestException,MethodNotAllowedException}.php`; Test `orkapi/tests/Exception/ApiExceptionTest.php`.

- [ ] **Step 1: Failing test.**

Create `orkapi/tests/Exception/ApiExceptionTest.php`:

```php
<?php

require_once __DIR__ . '/../assert.php';

use Ork\Api\Exception\{ApiException, NotFoundException, ValidationException, UnauthenticatedException,
    ForbiddenException, ConflictException, MalformedRequestException, MethodNotAllowedException};

$cases = [
    [new NotFoundException('x'), 404, 'not_found'],
    [new ValidationException('x'), 422, 'validation_failed'],
    [new UnauthenticatedException('x'), 401, 'unauthenticated'],
    [new ForbiddenException('x'), 403, 'forbidden'],
    [new ConflictException('x'), 409, 'conflict'],
    [new MalformedRequestException('x'), 400, 'malformed_request'],
];
foreach ($cases as [$e, $status, $code]) {
    t_ok($e instanceof ApiException, get_class($e) . ' is ApiException');
    t_eq($status, $e->httpStatus(), get_class($e) . ' status');
    t_eq($code, $e->errorCode(), get_class($e) . ' code');
}

$v = new ValidationException('bad', ['persona' => 'required']);
t_eq(['persona' => 'required'], $v->details(), 'validation details');

$m = new MethodNotAllowedException('nope', ['GET', 'PATCH']);
t_eq(405, $m->httpStatus(), '405 status');
t_eq('method_not_allowed', $m->errorCode(), '405 code');
t_eq('GET, PATCH', $m->allowHeader(), 'Allow header value');

t_done();
```

- [ ] **Step 2: Run → fail.**

- [ ] **Step 3: Implement base** (`orkapi/src/Exception/ApiException.php`):

```php
<?php

namespace Ork\Api\Exception;

abstract class ApiException extends \RuntimeException
{
    protected $details = null;

    public function __construct(string $message = '', $details = null)
    {
        parent::__construct($message);
        $this->details = $details;
    }

    abstract public function httpStatus(): int;
    abstract public function errorCode(): string;
    public function details() { return $this->details; }
}
```

- [ ] **Step 4: Implement the concrete exceptions.**

`NotFoundException.php` → 404 / `not_found`; `ValidationException.php` → 422 / `validation_failed`; `UnauthenticatedException.php` → 401 / `unauthenticated`; `ForbiddenException.php` → 403 / `forbidden`; `ConflictException.php` → 409 / `conflict`; `MalformedRequestException.php` → 400 / `malformed_request`. Each follows this shape (shown for NotFound; repeat with the right numbers/strings):

```php
<?php

namespace Ork\Api\Exception;

final class NotFoundException extends ApiException
{
    public function httpStatus(): int { return 404; }
    public function errorCode(): string { return 'not_found'; }
}
```

`MethodNotAllowedException.php` carries the allowed verbs:

```php
<?php

namespace Ork\Api\Exception;

final class MethodNotAllowedException extends ApiException
{
    /** @param string[] $allowed */
    public function __construct(string $message = '', private array $allowed = [])
    {
        parent::__construct($message);
    }

    public function httpStatus(): int { return 405; }
    public function errorCode(): string { return 'method_not_allowed'; }
    public function allowHeader(): string { return implode(', ', $this->allowed); }
}
```

- [ ] **Step 5: Run → pass. Step 6: Commit.**

```bash
git add orkapi/src/Exception orkapi/tests/Exception/ApiExceptionTest.php
git commit -m "Enhancement: orkapi typed exceptions (400/401/403/404/405/409/422)"
```

---

## Task 8: LegacyEnvelope mapper (global {Status:int} → typed exception)

**Files:** Create `orkapi/src/Legacy/LegacyEnvelope.php`; Test `orkapi/tests/Legacy/LegacyEnvelopeTest.php`.

> One place that knows the **global** result shape (`['Status'=>int 0/4/5,...]` from `orkservice/Common.definitions.php`, `ServiceErrorIds`: Success=0, ProcessingError=3, InvalidParameter=4, NoAuthorization=5). Every service uses this so the mapping is correct and identical across all 17 fan-out resources. (Verified: this is the system `class.Player` uses — NOT the `Errors::` boolean system.)

- [ ] **Step 1: Failing test.**

Create `orkapi/tests/Legacy/LegacyEnvelopeTest.php`:

```php
<?php

require_once __DIR__ . '/../assert.php';

use Ork\Api\Legacy\LegacyEnvelope;
use Ork\Api\Exception\{ValidationException, ForbiddenException, ConflictException};

// Success: returns the Detail payload.
t_eq(42, LegacyEnvelope::detailOrThrow(['Status' => ['Status' => 0, 'Error' => 'Success', 'Detail' => 42]]), 'success detail');
t_ok(LegacyEnvelope::isSuccess(['Status' => ['Status' => 0]]), 'isSuccess true');
t_ok(!LegacyEnvelope::isSuccess(['Status' => ['Status' => 4]]), 'isSuccess false');

// InvalidParameter(4) -> ValidationException; NoAuthorization(5) -> Forbidden; other -> Conflict.
t_throws(fn() => LegacyEnvelope::detailOrThrow(['Status' => ['Status' => 4, 'Detail' => 'bad field']]), ValidationException::class, '4 -> validation');
t_throws(fn() => LegacyEnvelope::detailOrThrow(['Status' => ['Status' => 5]]), ForbiddenException::class, '5 -> forbidden');
t_throws(fn() => LegacyEnvelope::detailOrThrow(['Status' => ['Status' => 3]]), ConflictException::class, '3 -> conflict');
// Missing Status entirely -> Conflict (defensive).
t_throws(fn() => LegacyEnvelope::detailOrThrow([]), ConflictException::class, 'missing -> conflict');

t_done();
```

- [ ] **Step 2: Run → fail. Step 3: Implement** (`orkapi/src/Legacy/LegacyEnvelope.php`):

```php
<?php

namespace Ork\Api\Legacy;

use Ork\Api\Exception\{ValidationException, ForbiddenException, ConflictException};

/**
 * Maps the legacy GLOBAL result envelope (orkservice/Common.definitions.php):
 *   ['Status' => ['Status' => int, 'Error' => string, 'Detail' => mixed]]
 * ServiceErrorIds: 0=Success, 3=ProcessingError, 4=InvalidParameter, 5=NoAuthorization.
 */
final class LegacyEnvelope
{
    public static function isSuccess(array $resp): bool
    {
        $s = $resp['Status'] ?? null;
        return is_array($s) && (int) ($s['Status'] ?? 1) === 0;
    }

    /** Return Detail on success; throw the right typed exception on failure. */
    public static function detailOrThrow(array $resp)
    {
        $s = $resp['Status'] ?? null;
        $code = is_array($s) ? (int) ($s['Status'] ?? 1) : 1;
        if ($code === 0) {
            return $s['Detail'] ?? null;
        }
        $msg = is_array($s) ? (string) ($s['Error'] ?? 'Request failed.') : 'Request failed.';
        $detail = is_array($s) ? ($s['Detail'] ?? null) : null;
        if ($code === 4) {
            throw new ValidationException($msg, $detail);
        }
        if ($code === 5) {
            throw new ForbiddenException($msg);
        }
        throw new ConflictException($msg);
    }
}
```

- [ ] **Step 4: Run → pass. Step 5: Commit.**

```bash
git add orkapi/src/Legacy/LegacyEnvelope.php orkapi/tests/Legacy/LegacyEnvelopeTest.php
git commit -m "Enhancement: orkapi LegacyEnvelope mapper (global ServiceErrorIds -> typed exceptions)"
```

---

## Task 9: RestRouter (404 vs 405) + routes + wire front controller + through-nginx routing test

**Files:** Create `orkapi/src/Http/RestRouter.php`, `orkapi/routes.php`, `orkapi/tests/integration/routing.sh`; Test `orkapi/tests/Http/RestRouterTest.php`; Modify `orkapi/index.php`.

- [ ] **Step 1: Failing unit test.**

Create `orkapi/tests/Http/RestRouterTest.php`:

```php
<?php

require_once __DIR__ . '/../assert.php';

use Ork\Api\Http\{RestRouter, RestRequest, ApiResponse};
use Ork\Api\Exception\{NotFoundException, MethodNotAllowedException, MalformedRequestException};

class _StubPlayers
{
    public function handle(RestRequest $r): ApiResponse
    {
        if ($r->method() === 'PUT') {
            throw new MethodNotAllowedException('no put', ['GET', 'PATCH']);
        }
        if ($r->id() === 999) {
            throw new NotFoundException('Player 999 not found');
        }
        return ApiResponse::ok(['id' => $r->id()]);
    }
}

$router = new RestRouter();
$router->register('players', _StubPlayers::class);

$ok = $router->dispatch(RestRequest::build('GET', '/api/v2/players/1', [], [], []));
t_eq(200, $ok->status(), 'ok');

$nf = $router->dispatch(RestRequest::build('GET', '/api/v2/players/999', [], [], []));
t_eq(404, $nf->status(), 'ApiException -> 404');
t_eq('not_found', $nf->body()['error']['code'], 'envelope code');

$unknown = $router->dispatch(RestRequest::build('GET', '/api/v2/widgets/1', [], [], []));
t_eq(404, $unknown->status(), 'unknown resource 404');

$malformed = $router->dispatch(RestRequest::build('POST', '/api/v2/players', [], [], [], true));
t_eq(400, $malformed->status(), 'malformed body -> 400');

t_done();
```

- [ ] **Step 2: Run → fail. Step 3: Implement** (`orkapi/src/Http/RestRouter.php`):

```php
<?php

namespace Ork\Api\Http;

use Ork\Api\Exception\{ApiException, NotFoundException, MalformedRequestException, MethodNotAllowedException};

final class RestRouter
{
    /** @var array<string,string> */
    private array $routes = [];

    public function register(string $resource, string $controllerClass): void
    {
        $this->routes[$resource] = $controllerClass;
    }

    public function dispatch(RestRequest $request): ApiResponse
    {
        try {
            if ($request->bodyWasMalformed()) {
                throw new MalformedRequestException('Request body is not valid JSON.');
            }
            $resource = $request->resource();
            if ($resource === null || !isset($this->routes[$resource])) {
                throw new NotFoundException('Unknown resource: ' . ($resource ?? '(none)'));
            }
            $controller = new $this->routes[$resource]();
            return $controller->handle($request);
        } catch (MethodNotAllowedException $e) {
            return ApiResponse::error($e->httpStatus(), Problem::make($e->errorCode(), $e->getMessage()))
                ->withAllow($e->allowHeader());
        } catch (ApiException $e) {
            return ApiResponse::error($e->httpStatus(), Problem::make($e->errorCode(), $e->getMessage(), $e->details()));
        } catch (\Throwable $e) {
            error_log('[orkapi] ' . $e->getMessage() . ' @ ' . $e->getFile() . ':' . $e->getLine());
            return ApiResponse::error(500, Problem::make('internal_error', 'An unexpected error occurred.'));
        }
    }
}
```

Add an `Allow`-header carrier to `ApiResponse` (so 405 emits `Allow`): in `orkapi/src/Http/ApiResponse.php` add a property `private array $headers = [];`, a method `public function withAllow(string $v): self { $this->headers['Allow'] = $v; return $this; }`, and in `send()` merge `$this->headers` into the emitted headers (before `$extraHeaders`). Re-run Task 6's test to confirm still green.

- [ ] **Step 4: Run → pass** (unit test).

- [ ] **Step 5: Create `orkapi/routes.php`.**

```php
<?php

use Ork\Api\Http\RestRouter;
use Ork\Api\Controller\RestPlayerController;
use Ork\Api\Controller\SessionController;

$router = new RestRouter();
$router->register('sessions', SessionController::class); // POST /api/v2/sessions (Task 19)
$router->register('players', RestPlayerController::class); // (Task 17)
// Phase 2 fan-out registers more here.

return $router;
```

> Controllers are referenced by class-string and only instantiated at dispatch; the bare `use` imports do not autoload at require time, so `routes.php` is safe to commit before Tasks 17/19 exist (no `players`/`sessions` request is made until then).

- [ ] **Step 6: Wire the real front controller** (`orkapi/index.php`):

```php
<?php

require_once __DIR__ . '/bootstrap.php';

use Ork\Api\Http\RestRequest;

// CORS + preflight (Bearer API; never combine * with credentials — we don't).
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PATCH, OPTIONS');
header('Access-Control-Allow-Headers: Authorization, Content-Type');
if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'OPTIONS') {
    http_response_code(204);
    exit;
}

$request = RestRequest::fromGlobals();

if ($request->resource() === 'ping') {
    \Ork\Api\Http\ApiResponse::ok(['pong' => true, 'version' => 'v2'])->send();
    exit;
}

// openapi.json is served in Task 20 (inserted here).

$router = require __DIR__ . '/routes.php';
$router->dispatch($request)->send();
```

- [ ] **Step 7: Through-nginx routing assertion (catches PATH_INFO misparse).**

Create `orkapi/tests/integration/routing.sh`:

```bash
#!/usr/bin/env bash
set -u
echo "--- ping (clean) ---"; curl -s http://localhost:19080/api/v2/ping | tee /tmp/r1; grep -q '"version":"v2"' /tmp/r1 && echo PING_OK || { echo PING_FAIL; exit 1; }
# Unknown resource must 404 with the resource name parsed correctly (not "index.php").
echo "--- unknown resource ---"; curl -s http://localhost:19080/api/v2/players/1 | tee /tmp/r2
grep -q '"code":"unauthenticated"' /tmp/r2 && echo PARSE_OK \
  || (grep -q 'index.php' /tmp/r2 && { echo "PARSE_FAIL: resource misparsed as index.php"; exit 1; } || echo "PARSE_OK (got non-misparse response)")
```

Run: `bash orkapi/tests/integration/routing.sh`
Expected: `PING_OK`; `/players/1` returns a `401 unauthenticated` envelope (proving the resource parsed as `players` and reached auth), NOT an `index.php` misparse. (This works once Task 11/17 land; before that it returns the router's 404 for `players` — still proves correct parsing. Re-run after Task 17.)

- [ ] **Step 8: Commit.**

```bash
chmod +x orkapi/tests/integration/routing.sh
git add orkapi/src/Http/RestRouter.php orkapi/src/Http/ApiResponse.php orkapi/routes.php orkapi/index.php orkapi/tests/Http/RestRouterTest.php orkapi/tests/integration/routing.sh
git commit -m "Enhancement: orkapi RestRouter (404/405/400/500 mapping) + CORS + wired front controller"
```

---

## Task 10: Identity

**Files:** Create `orkapi/src/Auth/Identity.php`; Test `orkapi/tests/Auth/IdentityTest.php`.

(Unchanged from prior design — `Identity` wraps `Ork3::$Lib->authorization`; `isAdmin()` = `HasAuthority($id, AUTH_ADMIN, 0, AUTH_ADMIN)`; `can($type,$id,$role)` delegates to `HasAuthority`; `require()`/`requireAdmin()` throw `ForbiddenException`.)

- [ ] **Step 1: Failing test** (`orkapi/tests/Auth/IdentityTest.php`):

```php
<?php

require_once __DIR__ . '/../assert.php';

use Ork\Api\Auth\Identity;
use Ork\Api\Exception\ForbiddenException;

class _FakeAuthz
{
    public function HasAuthority($mid, $type, $id, $role): bool
    {
        if ($type === AUTH_ADMIN) return $mid === 1;
        return $mid === 2 && $type === AUTH_PARK && $id === 5 && $role === AUTH_EDIT;
    }
}

$admin = new Identity(1, new _FakeAuthz());
t_eq(1, $admin->mundaneId(), 'id');
t_ok($admin->isAdmin(), 'admin');
$officer = new Identity(2, new _FakeAuthz());
t_ok(!$officer->isAdmin(), 'not admin');
t_ok($officer->can(AUTH_PARK, 5, AUTH_EDIT), 'can edit park 5');
t_ok(!$officer->can(AUTH_PARK, 6, AUTH_EDIT), 'cannot edit park 6');
t_throws(fn() => $officer->require(AUTH_PARK, 6, AUTH_EDIT), ForbiddenException::class, 'require denies');
t_throws(fn() => $officer->requireAdmin(), ForbiddenException::class, 'requireAdmin denies');

t_done();
```

- [ ] **Step 2: Run → fail. Step 3: Implement** (`orkapi/src/Auth/Identity.php`):

```php
<?php

namespace Ork\Api\Auth;

use Ork\Api\Exception\ForbiddenException;

final class Identity
{
    public function __construct(private int $mundaneId, private object $authz)
    {
    }

    public function mundaneId(): int { return $this->mundaneId; }
    public function isAdmin(): bool { return (bool) $this->authz->HasAuthority($this->mundaneId, AUTH_ADMIN, 0, AUTH_ADMIN); }
    public function can(string $type, int $id, string $role): bool { return (bool) $this->authz->HasAuthority($this->mundaneId, $type, $id, $role); }

    public function require(string $type, int $id, string $role): void
    {
        if (!$this->can($type, $id, $role)) {
            throw new ForbiddenException("You do not have $role authority over $type $id.");
        }
    }

    public function requireAdmin(): void
    {
        if (!$this->isAdmin()) {
            throw new ForbiddenException('This action requires ORK administrator privileges.');
        }
    }
}
```

- [ ] **Step 4: Run → pass. Step 5: Commit.**

```bash
git add orkapi/src/Auth/Identity.php orkapi/tests/Auth/IdentityTest.php
git commit -m "Enhancement: orkapi Identity value object"
```

---

## Task 11: AuthMiddleware — STATELESS token resolver (expiry + penalty box)

**Files:** Create `orkapi/src/Auth/AuthMiddleware.php`; Test `orkapi/tests/Auth/AuthMiddlewareTest.php`.

> Does NOT call `Authorization::IsAuthorized` (session short-circuit + no expiry). Resolves the token directly against `ork_mundane` with `token_expires > NOW()` and `penalty_box = 0`, via `Sql::quote`. Returns an `Identity`; throws `UnauthenticatedException` (401) otherwise.

- [ ] **Step 1: Failing test (integration-grade; uses a seeded token).**

Create `orkapi/tests/Auth/AuthMiddlewareTest.php`:

```php
<?php

require_once __DIR__ . '/../assert.php';

use Ork\Api\Auth\AuthMiddleware;
use Ork\Api\Http\RestRequest;
use Ork\Api\Auth\Identity;
use Ork\Api\Exception\UnauthenticatedException;

global $DB;

// Seed a known token with a future expiry on a real player.
$DB->Clear();
$rs = $DB->DataSet("SELECT mundane_id FROM " . DB_PREFIX . "mundane WHERE active = 1 ORDER BY mundane_id LIMIT 1");
$mid = ($rs && $rs->Next()) ? (int) $rs->mundane_id : 0;
t_ok($mid > 0, "seed player ($mid)");
$tok = str_repeat('a', 32);
$DB->Clear();
$DB->Execute("UPDATE " . DB_PREFIX . "mundane SET token = '$tok', token_expires = DATE_ADD(NOW(), INTERVAL 1 HOUR), penalty_box = 0 WHERE mundane_id = $mid");

$mw = new AuthMiddleware($DB);

$id = $mw->resolve(RestRequest::build('GET', '/api/v2/players/1', [], [], ['Authorization' => "Bearer $tok"]));
t_ok($id instanceof Identity, 'resolves Identity');
t_eq($mid, $id->mundaneId(), 'resolved id');

t_throws(fn() => $mw->resolve(RestRequest::build('GET', '/x', [], [], ['Authorization' => 'Bearer ' . str_repeat('b', 32)])), UnauthenticatedException::class, 'bad token 401');
t_throws(fn() => $mw->resolve(RestRequest::build('GET', '/x', [], [], [])), UnauthenticatedException::class, 'missing token 401');

// Expired token -> 401
$DB->Clear();
$DB->Execute("UPDATE " . DB_PREFIX . "mundane SET token_expires = DATE_SUB(NOW(), INTERVAL 1 HOUR) WHERE mundane_id = $mid");
t_throws(fn() => $mw->resolve(RestRequest::build('GET', '/x', [], [], ['Authorization' => "Bearer $tok"])), UnauthenticatedException::class, 'expired token 401');

// Cleanup
$DB->Clear();
$DB->Execute("UPDATE " . DB_PREFIX . "mundane SET token = NULL WHERE mundane_id = $mid");

t_done();
```

- [ ] **Step 2: Run → fail. Step 3: Implement** (`orkapi/src/Auth/AuthMiddleware.php`):

```php
<?php

namespace Ork\Api\Auth;

use Ork\Api\Http\RestRequest;
use Ork\Api\Db\Sql;
use Ork\Api\Exception\UnauthenticatedException;

final class AuthMiddleware
{
    /** $db is the global $DB (YapoMysql). */
    public function __construct(private object $db)
    {
    }

    public function resolve(RestRequest $request): Identity
    {
        $token = $request->bearerToken();
        if ($token === null || strlen($token) !== 32) {
            throw new UnauthenticatedException('Missing or malformed Bearer token.');
        }
        $mundaneId = $this->resolveToken($token);
        if ($mundaneId <= 0) {
            throw new UnauthenticatedException('Invalid or expired token.');
        }
        return new Identity($mundaneId, \Ork3::$Lib->authorization);
    }

    private function resolveToken(string $token): int
    {
        $this->db->Clear();
        $q = $this->db->DataSet(
            "SELECT mundane_id FROM " . DB_PREFIX . "mundane
             WHERE token = " . Sql::quote($token) . "
               AND token_expires IS NOT NULL AND token_expires > NOW()
               AND penalty_box = 0
             LIMIT 1"
        );
        return ($q && $q->Next()) ? (int) $q->mundane_id : 0;
    }
}
```

- [ ] **Step 4: Run → pass. Step 5: Commit.**

```bash
git add orkapi/src/Auth/AuthMiddleware.php orkapi/tests/Auth/AuthMiddlewareTest.php
git commit -m "Enhancement: orkapi stateless AuthMiddleware (token + expiry + penalty box)"
```

---

## Task 12: BaseRestController (verb-dispatch; resolve Identity once; 405+Allow)

**Files:** Create `orkapi/src/Controller/BaseRestController.php`.

> This is the real fan-out template: it authenticates once, then dispatches to `show/index/create/update` based on verb + id, returning 405 (with `Allow`) for verbs a subclass doesn't implement. Subclasses override only the operations they support.

- [ ] **Step 1: Implement** (`orkapi/src/Controller/BaseRestController.php`):

```php
<?php

namespace Ork\Api\Controller;

use Ork\Api\Http\RestRequest;
use Ork\Api\Http\ApiResponse;
use Ork\Api\Auth\AuthMiddleware;
use Ork\Api\Auth\Identity;
use Ork\Api\Exception\MethodNotAllowedException;

abstract class BaseRestController
{
    public function handle(RestRequest $request): ApiResponse
    {
        $caller = $this->authenticate($request);
        $hasId = $request->id() !== null;

        switch ($request->method()) {
            case 'GET':
                return $hasId ? $this->show($request, $caller) : $this->index($request, $caller);
            case 'POST':
                return $this->create($request, $caller);
            case 'PATCH':
                return $this->update($request, $caller);
            default:
                throw new MethodNotAllowedException(
                    'Method ' . $request->method() . ' is not supported for this resource.',
                    $this->allowedMethods()
                );
        }
    }

    protected function authenticate(RestRequest $request): Identity
    {
        global $DB;
        return (new AuthMiddleware($DB))->resolve($request);
    }

    /** Verbs advertised in the Allow header for 405s. Override per resource. */
    protected function allowedMethods(): array
    {
        return ['GET', 'POST', 'PATCH'];
    }

    // Default operations 405 unless overridden.
    protected function show(RestRequest $r, Identity $c): ApiResponse { throw $this->unsupported(); }
    protected function index(RestRequest $r, Identity $c): ApiResponse { throw $this->unsupported(); }
    protected function create(RestRequest $r, Identity $c): ApiResponse { throw $this->unsupported(); }
    protected function update(RestRequest $r, Identity $c): ApiResponse { throw $this->unsupported(); }

    private function unsupported(): MethodNotAllowedException
    {
        return new MethodNotAllowedException('Operation not supported for this resource.', $this->allowedMethods());
    }
}
```

- [ ] **Step 2: Lint.** `docker exec ork3-php8-app php -l /var/www/ork.amtgard.com/orkapi/src/Controller/BaseRestController.php` → `No syntax errors`.

- [ ] **Step 3: Commit.**

```bash
git add orkapi/src/Controller/BaseRestController.php
git commit -m "Enhancement: orkapi BaseRestController (verb-dispatch + Identity once + 405)"
```

---

## Task 13: PlayerDTO (pure domain — no OpenAPI attributes)

**Files:** Create `system/lib/app/Player/PlayerDTO.php`; Test `orkapi/tests/App/PlayerDtoTest.php`.

> The DTO is pure (no `OpenApi\Attributes` — that lives in the transport layer, Task 14). `duesThrough` is nullable (emit `null`, never `''`). Exposes `imageUrl`/`heraldryUrl` (mobile need). **`username` is NOT exposed** (login identifier — privacy).

- [ ] **Step 1: Failing test** (`orkapi/tests/App/PlayerDtoTest.php`):

```php
<?php

require_once __DIR__ . '/../assert.php';

use Ork\App\Player\PlayerDTO;

$dto = PlayerDTO::fromLegacy([
    'MundaneId' => 7, 'Persona' => 'Sir Test', 'ParkId' => 3, 'KingdomId' => 2,
    'PronounId' => 1, 'Active' => '1', 'Waivered' => '0', 'HasImage' => '1',
    'DuesThrough' => '2026-12-31', 'ImageUrl' => 'https://x/img.jpg', 'HeraldryUrl' => 'https://x/her.jpg',
]);
t_eq(7, $dto->mundaneId, 'id');
t_eq('Sir Test', $dto->persona, 'persona');
t_eq(true, $dto->active, 'active bool');
t_eq(false, $dto->waivered, 'waivered bool');
t_eq('2026-12-31', $dto->duesThrough, 'dues date');

$arr = $dto->toArray();
t_eq(7, $arr['mundaneId'], 'array id');
t_ok(!array_key_exists('username', $arr), 'username NOT exposed');
t_ok(array_key_exists('imageUrl', $arr), 'imageUrl present');

// Empty dues -> null, not ''
$empty = PlayerDTO::fromLegacy(['MundaneId' => 1, 'DuesThrough' => '']);
t_eq(null, $empty->duesThrough, 'empty dues -> null');

t_done();
```

- [ ] **Step 2: Run → fail. Step 3: Implement** (`system/lib/app/Player/PlayerDTO.php`):

```php
<?php

namespace Ork\App\Player;

/** Pure, public shape of a Player in the v2 API. No transport/doc concerns. */
final class PlayerDTO
{
    public function __construct(
        public int $mundaneId = 0,
        public string $persona = '',
        public int $parkId = 0,
        public int $kingdomId = 0,
        public int $pronounId = 0,
        public bool $active = false,
        public bool $waivered = false,
        public bool $hasImage = false,
        public ?string $duesThrough = null,
        public ?string $imageUrl = null,
        public ?string $heraldryUrl = null
    ) {
    }

    public static function fromLegacy(array $p): self
    {
        $dues = (string) ($p['DuesThrough'] ?? '');
        return new self(
            mundaneId: (int) ($p['MundaneId'] ?? 0),
            persona: (string) ($p['Persona'] ?? ''),
            parkId: (int) ($p['ParkId'] ?? 0),
            kingdomId: (int) ($p['KingdomId'] ?? 0),
            pronounId: (int) ($p['PronounId'] ?? 0),
            active: (bool) ($p['Active'] ?? 0),
            waivered: (bool) ($p['Waivered'] ?? 0),
            hasImage: (bool) ($p['HasImage'] ?? 0),
            duesThrough: $dues === '' ? null : $dues,
            imageUrl: ($p['ImageUrl'] ?? '') !== '' ? (string) $p['ImageUrl'] : null,
            heraldryUrl: ($p['HeraldryUrl'] ?? '') !== '' ? (string) $p['HeraldryUrl'] : null
        );
    }

    public function toArray(): array
    {
        return [
            'mundaneId' => $this->mundaneId,
            'persona' => $this->persona,
            'parkId' => $this->parkId,
            'kingdomId' => $this->kingdomId,
            'pronounId' => $this->pronounId,
            'active' => $this->active,
            'waivered' => $this->waivered,
            'hasImage' => $this->hasImage,
            'duesThrough' => $this->duesThrough,
            'imageUrl' => $this->imageUrl,
            'heraldryUrl' => $this->heraldryUrl,
        ];
    }
}
```

> **Implementer:** `GetPlayer` returns a heraldry URL (`Ork3::$Lib->heraldry->GetHeraldryUrl(...)`) — wire `HeraldryUrl`/`ImageUrl` from the real fields it exposes (confirm the key names in `class.Player.php` around the `$response['Player']` assembly). If a player image URL isn't directly returned, construct it from the documented `HTTP_PLAYER_IMAGE . sprintf('%06d', id) . '.jpg'` pattern only when `hasImage`.

- [ ] **Step 4: Run → pass. Step 5: Commit.**

```bash
git add system/lib/app/Player/PlayerDTO.php orkapi/tests/App/PlayerDtoTest.php
git commit -m "Enhancement: pure PlayerDTO (nullable dues, image/heraldry URLs, no username)"
```

---

## Task 14: OpenAPI schema classes (transport layer): Player, ApiError, PageMeta, PlayerListResponse

**Files:** Create `orkapi/src/Schema/PlayerSchema.php`, `orkapi/src/Schema/Envelopes.php`.

> OpenAPI attributes live HERE (transport), keeping `system/lib/app/` DTOs pure. These classes are doc-only (never instantiated at runtime); swagger-php reflects them at build time. `required` + nullable + formats are declared so codegen produces clean typed models.

- [ ] **Step 1: Implement Player schema** (`orkapi/src/Schema/PlayerSchema.php`):

```php
<?php

namespace Ork\Api\Schema;

use OpenApi\Attributes as OA;

#[OA\Schema(
    schema: 'Player',
    title: 'Player',
    description: 'An Amtgard participant.',
    required: ['mundaneId', 'persona', 'parkId', 'kingdomId', 'active']
)]
final class PlayerSchema
{
    #[OA\Property(description: 'Unique player id.')]
    public int $mundaneId;
    #[OA\Property(description: 'Persona (in-game) name.')]
    public string $persona;
    #[OA\Property(description: 'Park id.')]
    public int $parkId;
    #[OA\Property(description: 'Kingdom id.')]
    public int $kingdomId;
    #[OA\Property(description: 'Pronoun id.')]
    public int $pronounId;
    #[OA\Property(description: 'Whether the player is active.')]
    public bool $active;
    #[OA\Property(description: 'Whether a current waiver is on file.')]
    public bool $waivered;
    #[OA\Property(description: 'Whether a profile image exists.')]
    public bool $hasImage;
    #[OA\Property(format: 'date', nullable: true, description: 'Dues paid through, or null.')]
    public ?string $duesThrough;
    #[OA\Property(format: 'uri', nullable: true, description: 'Absolute profile image URL, or null.')]
    public ?string $imageUrl;
    #[OA\Property(format: 'uri', nullable: true, description: 'Absolute heraldry image URL, or null.')]
    public ?string $heraldryUrl;
}
```

- [ ] **Step 2: Implement envelopes** (`orkapi/src/Schema/Envelopes.php`):

```php
<?php

namespace Ork\Api\Schema;

use OpenApi\Attributes as OA;

#[OA\Schema(schema: 'ApiError', required: ['error'])]
class ApiErrorSchema
{
    #[OA\Property(property: 'error', required: ['code', 'message'], properties: [
        new OA\Property(
            property: 'code',
            type: 'string',
            enum: ['not_found', 'validation_failed', 'unauthenticated', 'forbidden', 'conflict', 'malformed_request', 'method_not_allowed', 'internal_error'],
            description: 'Stable machine-readable error code.'
        ),
        new OA\Property(property: 'message', type: 'string'),
        new OA\Property(property: 'details', nullable: true, description: 'Optional structured details (e.g. field errors).'),
    ])]
    public object $error;
}

#[OA\Schema(schema: 'PageMeta', required: ['limit', 'offset', 'count', 'hasMore'])]
class PageMetaSchema
{
    #[OA\Property] public int $limit;
    #[OA\Property] public int $offset;
    #[OA\Property(description: 'Number of items in this page.')] public int $count;
    #[OA\Property(description: 'Whether more items exist beyond this page.')] public bool $hasMore;
}

#[OA\Schema(schema: 'PlayerListResponse', required: ['data', 'meta'])]
class PlayerListResponseSchema
{
    /** @var PlayerSchema[] */
    #[OA\Property(type: 'array', items: new OA\Items(ref: '#/components/schemas/Player'))]
    public array $data;
    #[OA\Property(ref: '#/components/schemas/PageMeta')]
    public object $meta;
}
```

> **Implementer:** verify the exact swagger-php v5 attribute spelling for an enum/nested object property against the installed version (Task 20 installs it). If `OA\Property` nested `properties:` differs in v5, adjust; the schema NAMES (`Player`, `ApiError`, `PageMeta`, `PlayerListResponse`) and their `required`/enum content are the contract — keep them.

- [ ] **Step 3: Lint both files.** `php -l` each → no syntax errors. (Full validation happens at Task 20 generation.)

- [ ] **Step 4: Commit.**

```bash
git add orkapi/src/Schema/PlayerSchema.php orkapi/src/Schema/Envelopes.php
git commit -m "Enhancement: orkapi OpenAPI schema classes (Player, ApiError, PageMeta, list envelope)"
```

---

## Task 15: PlayerService::getPlayer (strangler via LegacyEnvelope)

**Files:** Create `system/lib/app/Player/PlayerService.php`; Test `orkapi/tests/App/PlayerServiceTest.php`; Create `orkapi/tests/integration/api.sh`.

- [ ] **Step 1: Token-acquiring curl helper** (`orkapi/tests/integration/api.sh`):

```bash
#!/usr/bin/env bash
# Mint a v2 token via POST /api/v2/sessions (Task 19), then expose `api`.
set -u
BASE="${BASE:-http://localhost:19080}"
USER="${ORK_TEST_USER:-admin}"
PASS="${ORK_TEST_PASS:-anything}"   # login bypass accepts any password locally

RESP="$(curl -s -X POST -H 'Content-Type: application/json' \
  -d "{\"username\":\"$USER\",\"password\":\"$PASS\"}" "$BASE/api/v2/sessions")"
TOKEN="$(printf '%s' "$RESP" | grep -o '"token":"[^"]*"' | head -1 | sed 's/"token":"//;s/"//')"
if [ -z "$TOKEN" ]; then echo "FAILED to mint token: $RESP" >&2; return 1 2>/dev/null || exit 1; fi
echo "Token minted for $USER"

api() {
  local method="$1" path="$2" body="${3:-}"
  if [ -n "$body" ]; then
    curl -s -X "$method" -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d "$body" "$BASE/api/v2$path"
  else
    curl -s -X "$method" -H "Authorization: Bearer $TOKEN" "$BASE/api/v2$path"
  fi
}
```

> Depends on Task 19. When implementing in order, write `api.sh` here but run the integration scripts that source it only after Task 19 lands. The pure service test (Step 2) does not need it.

- [ ] **Step 2: Failing service test** (`orkapi/tests/App/PlayerServiceTest.php`):

```php
<?php

require_once __DIR__ . '/../assert.php';

use Ork\App\Player\{PlayerService, PlayerDTO};
use Ork\Api\Auth\Identity;
use Ork\Api\Exception\NotFoundException;

global $DB;
$DB->Clear();
$rs = $DB->DataSet("SELECT mundane_id FROM " . DB_PREFIX . "mundane WHERE LENGTH(persona) > 0 AND active = 1 ORDER BY mundane_id LIMIT 1");
$realId = ($rs && $rs->Next()) ? (int) $rs->mundane_id : 0;
t_ok($realId > 0, "real player ($realId)");

$caller = new Identity($realId, Ork3::$Lib->authorization);
$svc = new PlayerService();

$dto = $svc->getPlayer($realId, $caller);
t_ok($dto instanceof PlayerDTO, 'returns DTO');
t_eq($realId, $dto->mundaneId, 'id matches');
t_ok(is_string($dto->persona), 'persona string');

t_throws(fn() => $svc->getPlayer(0, $caller), NotFoundException::class, 'missing -> NotFound');

t_done();
```

- [ ] **Step 3: Run → fail. Step 4: Implement** (`system/lib/app/Player/PlayerService.php`):

```php
<?php

namespace Ork\App\Player;

use Ork\Api\Auth\Identity;
use Ork\Api\Exception\NotFoundException;

/** Transport-agnostic application service for Players (strangler over legacy). */
final class PlayerService
{
    private function legacy(): object
    {
        return \Ork3::$Lib->player;
    }

    public function getPlayer(int $id, Identity $caller): PlayerDTO
    {
        if ($id <= 0) {
            throw new NotFoundException("Player $id not found.");
        }
        // GetPlayer self-limits private fields by the caller's authority; pass no token
        // for the public projection (private-field exposure is a future, explicit feature).
        $resp = $this->legacy()->GetPlayer(['MundaneId' => $id, 'Token' => '']);

        // GetPlayer sets Status=InvalidParameter (4) and omits Player on miss.
        if (empty($resp['Player']) || (int) ($resp['Status']['Status'] ?? 4) !== 0) {
            throw new NotFoundException("Player $id not found.");
        }
        return PlayerDTO::fromLegacy($resp['Player']);
    }
}
```

> Note: reads are intentionally caller-agnostic for the public projection (any valid token may read the public fields). `$caller` is retained in the signature for future per-caller field exposure and for symmetry across the fan-out template.

- [ ] **Step 5: Run → pass. Step 6: Commit.**

```bash
chmod +x orkapi/tests/integration/api.sh
git add system/lib/app/Player/PlayerService.php orkapi/tests/App/PlayerServiceTest.php orkapi/tests/integration/api.sh
git commit -m "Enhancement: PlayerService.getPlayer (strangler over legacy GetPlayer)"
```

---

## Task 16: PlayerService::listPlayers (Sql helper + pagination meta)

**Files:** Modify `system/lib/app/Player/PlayerService.php`; Test `orkapi/tests/App/PlayerListTest.php`.

> Returns `['items' => PlayerDTO[], 'meta' => ['limit','offset','count','hasMore']]`. Uses `Sql::quote`/`Sql::likeLiteral` (Task 4); fetches `limit+1` to compute `hasMore`.

- [ ] **Step 1: Failing test** (`orkapi/tests/App/PlayerListTest.php`):

```php
<?php

require_once __DIR__ . '/../assert.php';

use Ork\App\Player\{PlayerService, PlayerDTO};
use Ork\Api\Auth\Identity;

global $DB;
$DB->Clear();
$rs = $DB->DataSet("SELECT persona FROM " . DB_PREFIX . "mundane WHERE LENGTH(persona) >= 3 AND active = 1 LIMIT 1");
$persona = ($rs && $rs->Next()) ? (string) $rs->persona : '';
t_ok($persona !== '', 'found persona');

$caller = new Identity(0, Ork3::$Lib->authorization);
$svc = new PlayerService();
$needle = substr($persona, 0, 3);

$r = $svc->listPlayers(['q' => $needle, 'limit' => 10, 'offset' => 0], $caller);
t_ok(isset($r['items']) && isset($r['meta']), 'shape has items+meta');
t_ok(count($r['items']) >= 1, 'has results');
t_ok($r['items'][0] instanceof PlayerDTO, 'items are DTOs');
t_eq(10, $r['meta']['limit'], 'meta limit');
t_eq(0, $r['meta']['offset'], 'meta offset');
t_ok(is_bool($r['meta']['hasMore']), 'meta hasMore bool');

$capped = $svc->listPlayers(['q' => $needle, 'limit' => 9999], $caller);
t_ok($capped['meta']['limit'] <= 100, 'limit capped at 100');

t_done();
```

- [ ] **Step 2: Run → fail. Step 3: Implement** (add to `PlayerService`, with `use Ork\Api\Db\Sql;` at top):

```php
    /**
     * Search players. Filters: q, parkId, kingdomId, limit (default 25, max 100), offset.
     * @return array{items: PlayerDTO[], meta: array{limit:int,offset:int,count:int,hasMore:bool}}
     */
    public function listPlayers(array $filters, Identity $caller): array
    {
        global $DB;

        $q = trim((string) ($filters['q'] ?? ''));
        $parkId = (int) ($filters['parkId'] ?? 0);
        $kingdomId = (int) ($filters['kingdomId'] ?? 0);
        $limit = max(1, min(100, (int) ($filters['limit'] ?? 25)));
        $offset = max(0, (int) ($filters['offset'] ?? 0));

        $where = ['m.active = 1', "LENGTH(m.persona) > 0"];
        if ($q !== '') {
            $like = Sql::quote('%' . Sql::likeLiteral($q) . '%');
            $where[] = "(m.persona LIKE $like OR m.given_name LIKE $like OR m.surname LIKE $like OR m.username LIKE $like)";
        }
        if ($parkId > 0) {
            $where[] = "m.park_id = $parkId";
        }
        if ($kingdomId > 0) {
            $where[] = "m.kingdom_id = $kingdomId";
        }
        $whereSql = implode(' AND ', $where);
        $fetch = $limit + 1; // one extra row to detect hasMore

        $DB->Clear();
        $rs = $DB->DataSet(
            "SELECT m.mundane_id, m.persona, m.park_id, m.kingdom_id, m.pronoun_id, m.active, m.waivered, m.has_image
             FROM " . DB_PREFIX . "mundane m
             WHERE $whereSql
             ORDER BY m.persona
             LIMIT $fetch OFFSET $offset"
        );

        $rows = [];
        if ($rs) {
            while ($rs->Next()) {
                $rows[] = [
                    'MundaneId' => $rs->mundane_id, 'Persona' => $rs->persona, 'ParkId' => $rs->park_id,
                    'KingdomId' => $rs->kingdom_id, 'PronounId' => $rs->pronoun_id, 'Active' => $rs->active,
                    'Waivered' => $rs->waivered, 'HasImage' => $rs->has_image,
                ];
            }
        }
        $hasMore = count($rows) > $limit;
        if ($hasMore) {
            array_pop($rows);
        }
        $items = array_map(fn($r) => PlayerDTO::fromLegacy($r), $rows);

        return ['items' => $items, 'meta' => ['limit' => $limit, 'offset' => $offset, 'count' => count($items), 'hasMore' => $hasMore]];
    }
```

- [ ] **Step 4: Run → pass. Step 5: Commit.**

```bash
git add system/lib/app/Player/PlayerService.php orkapi/tests/App/PlayerListTest.php
git commit -m "Enhancement: PlayerService.listPlayers (centralized escaping + pagination meta)"
```

---

## Task 17: RestPlayerController — GET show + index (public operation methods + $ref schemas)

**Files:** Create `orkapi/src/Controller/RestPlayerController.php`; Test `orkapi/tests/integration/players_read.sh`.

> Operation attributes go on **public** methods (swagger-php skips private). Extends `BaseRestController` (auth + verb-dispatch); overrides `show()`/`index()`. List returns the `{data, meta}` envelope matching `PlayerListResponse`.

- [ ] **Step 1: Implement** (`orkapi/src/Controller/RestPlayerController.php`):

```php
<?php

namespace Ork\Api\Controller;

use Ork\Api\Http\RestRequest;
use Ork\Api\Http\ApiResponse;
use Ork\Api\Auth\Identity;
use Ork\App\Player\PlayerService;
use OpenApi\Attributes as OA;

final class RestPlayerController extends BaseRestController
{
    protected function allowedMethods(): array
    {
        return ['GET', 'POST', 'PATCH'];
    }

    #[OA\Get(
        path: '/players/{id}', summary: 'Fetch a player by id.', tags: ['Players'], security: [['bearerAuth' => []]],
        parameters: [new OA\Parameter(name: 'id', in: 'path', required: true, schema: new OA\Schema(type: 'integer'))],
        responses: [
            new OA\Response(response: 200, description: 'The player.', content: new OA\JsonContent(ref: '#/components/schemas/Player')),
            new OA\Response(response: 401, description: 'Unauthenticated.', content: new OA\JsonContent(ref: '#/components/schemas/ApiError')),
            new OA\Response(response: 404, description: 'Not found.', content: new OA\JsonContent(ref: '#/components/schemas/ApiError')),
        ]
    )]
    public function show(RestRequest $request, Identity $caller): ApiResponse
    {
        $dto = (new PlayerService())->getPlayer((int) $request->id(), $caller);
        return ApiResponse::ok($dto->toArray());
    }

    #[OA\Get(
        path: '/players', summary: 'Search players.', tags: ['Players'], security: [['bearerAuth' => []]],
        parameters: [
            new OA\Parameter(name: 'q', in: 'query', schema: new OA\Schema(type: 'string'), description: 'Persona/name/username substring.'),
            new OA\Parameter(name: 'parkId', in: 'query', schema: new OA\Schema(type: 'integer')),
            new OA\Parameter(name: 'kingdomId', in: 'query', schema: new OA\Schema(type: 'integer')),
            new OA\Parameter(name: 'limit', in: 'query', schema: new OA\Schema(type: 'integer', default: 25, maximum: 100)),
            new OA\Parameter(name: 'offset', in: 'query', schema: new OA\Schema(type: 'integer', default: 0)),
        ],
        responses: [
            new OA\Response(response: 200, description: 'Matching players.', content: new OA\JsonContent(ref: '#/components/schemas/PlayerListResponse')),
            new OA\Response(response: 401, description: 'Unauthenticated.', content: new OA\JsonContent(ref: '#/components/schemas/ApiError')),
        ]
    )]
    public function index(RestRequest $request, Identity $caller): ApiResponse
    {
        $r = (new PlayerService())->listPlayers([
            'q' => (string) $request->query('q', ''),
            'parkId' => (int) $request->query('parkId', 0),
            'kingdomId' => (int) $request->query('kingdomId', 0),
            'limit' => (int) $request->query('limit', 25),
            'offset' => (int) $request->query('offset', 0),
        ], $caller);

        return ApiResponse::ok([
            'data' => array_map(fn($d) => $d->toArray(), $r['items']),
            'meta' => $r['meta'],
        ]);
    }
}
```

- [ ] **Step 2: Integration test** (`orkapi/tests/integration/players_read.sh`) — runs after Task 19 (token mint):

```bash
#!/usr/bin/env bash
set -u
source orkapi/tests/integration/api.sh || exit 1
RID="$(docker exec ork3-php8-db mariadb -N -u root -proot ork -e "SELECT mundane_id FROM ork_mundane WHERE LENGTH(persona)>0 AND active=1 ORDER BY mundane_id LIMIT 1;")"

echo "--- GET /players/$RID ---"; api GET "/players/$RID" | tee /tmp/p_show.json
grep -q "\"mundaneId\":$RID" /tmp/p_show.json && echo SHOW_OK || { echo SHOW_FAIL; exit 1; }

echo "--- GET /players?q=a&limit=5 ---"; api GET "/players?q=a&limit=5" | tee /tmp/p_list.json
grep -q '"data":\[' /tmp/p_list.json && grep -q '"meta":' /tmp/p_list.json && echo LIST_OK || { echo LIST_FAIL; exit 1; }

echo "--- no token (401) ---"; code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:19080/api/v2/players/$RID"); [ "$code" = 401 ] && echo AUTH_OK || { echo "AUTH_FAIL $code"; exit 1; }
echo "--- /players/0 (404) ---"; code=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $TOKEN" "http://localhost:19080/api/v2/players/0"); [ "$code" = 404 ] && echo NF_OK || { echo "NF_FAIL $code"; exit 1; }
echo "--- PUT (405) ---"; code=$(curl -s -o /dev/null -w "%{http_code}" -X PUT -H "Authorization: Bearer $TOKEN" "http://localhost:19080/api/v2/players/$RID"); [ "$code" = 405 ] && echo PUT405_OK || { echo "PUT405_FAIL $code"; exit 1; }
```

Run after Task 19: `bash orkapi/tests/integration/players_read.sh` → all OK.

- [ ] **Step 3: Commit.**

```bash
chmod +x orkapi/tests/integration/players_read.sh
git add orkapi/src/Controller/RestPlayerController.php orkapi/tests/integration/players_read.sh
git commit -m "Enhancement: RestPlayerController GET show/index ({data,meta} envelope)"
```

---

## Task 18: Player writes — POST + PATCH (PUT already 405 via base)

**Files:** Modify `system/lib/app/Player/PlayerService.php` (add `createPlayer`, `updatePlayer`); Modify `orkapi/src/Controller/RestPlayerController.php`; Test `orkapi/tests/integration/players_write.sh`.

> No DELETE (legacy has none). Writes delegate to `CreatePlayer`/`UpdatePlayer`, use `LegacyEnvelope` for error mapping, enforce authority at the boundary via `$caller->require(...)`.

- [ ] **Step 1: Add service write methods** (with `use Ork\Api\Legacy\LegacyEnvelope; use Ork\Api\Exception\ValidationException;` at top):

```php
    public function createPlayer(array $input, Identity $caller): PlayerDTO
    {
        $parkId = (int) ($input['parkId'] ?? 0);
        if ($parkId <= 0) {
            throw new ValidationException('parkId is required.', ['parkId' => 'required']);
        }
        $caller->require(AUTH_PARK, $parkId, AUTH_CREATE);

        $resp = $this->legacy()->CreatePlayer([
            'Token' => '', 'ParkId' => $parkId,
            'GivenName' => (string) ($input['givenName'] ?? ''),
            'Surname' => (string) ($input['surname'] ?? ''),
            'Persona' => (string) ($input['persona'] ?? ''),
            'Email' => (string) ($input['email'] ?? ''),
        ]);
        // Verified: CreatePlayer returns global Success($new_mundane_id) -> Detail holds the new id.
        $newId = (int) LegacyEnvelope::detailOrThrow($resp);
        if ($newId <= 0) {
            throw new \Ork\Api\Exception\ConflictException('Player was not created.');
        }
        return $this->getPlayer($newId, $caller);
    }

    public function updatePlayer(int $id, array $input, Identity $caller): PlayerDTO
    {
        $existing = $this->getPlayer($id, $caller); // 404 if absent
        $caller->require(AUTH_PARK, $existing->parkId, AUTH_EDIT);

        $map = ['givenName' => 'GivenName', 'surname' => 'Surname', 'persona' => 'Persona', 'email' => 'Email', 'pronounId' => 'PronounId'];
        $req = ['Token' => '', 'MundaneId' => $id];
        foreach ($map as $dto => $legacy) {
            if (array_key_exists($dto, $input)) {
                $req[$legacy] = $input[$dto];
            }
        }
        $resp = $this->legacy()->UpdatePlayer($req);
        LegacyEnvelope::detailOrThrow($resp); // throws on failure
        return $this->getPlayer($id, $caller);
    }
```

> **Implementer:** confirm `CreatePlayer`/`UpdatePlayer` request keys + that `CreatePlayer`'s final `return` is `Success($new_mundane_id)` (class.Player.php:644+). If it instead returns the re-fetched player array, read the id from that shape. Do not invent a delete.

- [ ] **Step 2: Add controller write ops** (public methods, attributes):

```php
    #[OA\Post(
        path: '/players', summary: 'Create a player.', tags: ['Players'], security: [['bearerAuth' => []]],
        requestBody: new OA\RequestBody(required: true, content: new OA\JsonContent(
            required: ['parkId', 'persona'],
            properties: [
                new OA\Property(property: 'parkId', type: 'integer'),
                new OA\Property(property: 'persona', type: 'string'),
                new OA\Property(property: 'givenName', type: 'string'),
                new OA\Property(property: 'surname', type: 'string'),
                new OA\Property(property: 'email', type: 'string', format: 'email'),
            ]
        )),
        responses: [
            new OA\Response(response: 201, description: 'Created.', content: new OA\JsonContent(ref: '#/components/schemas/Player')),
            new OA\Response(response: 422, description: 'Validation failed.', content: new OA\JsonContent(ref: '#/components/schemas/ApiError')),
            new OA\Response(response: 403, description: 'Forbidden.', content: new OA\JsonContent(ref: '#/components/schemas/ApiError')),
        ]
    )]
    public function create(RestRequest $request, Identity $caller): ApiResponse
    {
        $dto = (new PlayerService())->createPlayer($request->body(), $caller);
        return ApiResponse::created($dto->toArray());
    }

    #[OA\Patch(
        path: '/players/{id}', summary: 'Partially update a player.', tags: ['Players'], security: [['bearerAuth' => []]],
        parameters: [new OA\Parameter(name: 'id', in: 'path', required: true, schema: new OA\Schema(type: 'integer'))],
        requestBody: new OA\RequestBody(content: new OA\JsonContent(properties: [
            new OA\Property(property: 'persona', type: 'string'),
            new OA\Property(property: 'givenName', type: 'string'),
            new OA\Property(property: 'surname', type: 'string'),
            new OA\Property(property: 'email', type: 'string', format: 'email'),
            new OA\Property(property: 'pronounId', type: 'integer'),
        ])),
        responses: [
            new OA\Response(response: 200, description: 'Updated.', content: new OA\JsonContent(ref: '#/components/schemas/Player')),
            new OA\Response(response: 404, description: 'Not found.', content: new OA\JsonContent(ref: '#/components/schemas/ApiError')),
            new OA\Response(response: 403, description: 'Forbidden.', content: new OA\JsonContent(ref: '#/components/schemas/ApiError')),
        ]
    )]
    public function update(RestRequest $request, Identity $caller): ApiResponse
    {
        if ($request->id() === null) {
            throw new \Ork\Api\Exception\ValidationException('Player id is required in the path.');
        }
        $dto = (new PlayerService())->updatePlayer((int) $request->id(), $request->body(), $caller);
        return ApiResponse::ok($dto->toArray());
    }
```

- [ ] **Step 3: Integration test** (`orkapi/tests/integration/players_write.sh`) — DB teardown (no API delete):

```bash
#!/usr/bin/env bash
set -u
source orkapi/tests/integration/api.sh || exit 1
PID="$(docker exec ork3-php8-db mariadb -N -u root -proot ork -e "SELECT park_id FROM ork_mundane WHERE username='${ORK_TEST_USER:-admin}' LIMIT 1;")"
[ -n "$PID" ] || { echo "no park id"; exit 1; }
PERSONA="ZZ Api Test $RANDOM"

echo "--- POST /players ---"
CREATE=$(api POST /players "{\"parkId\":$PID,\"persona\":\"$PERSONA\",\"givenName\":\"Api\",\"surname\":\"Test\"}")
echo "$CREATE"
NEWID=$(printf '%s' "$CREATE" | grep -o '"mundaneId":[0-9]*' | head -1 | grep -o '[0-9]*')
[ -n "$NEWID" ] && echo "CREATE_OK id=$NEWID" || { echo CREATE_FAIL; exit 1; }

echo "--- PATCH /players/$NEWID (change persona) ---"
api PATCH "/players/$NEWID" "{\"persona\":\"$PERSONA Updated\"}" | tee /tmp/p_upd.json
grep -q "Updated" /tmp/p_upd.json && echo UPDATE_OK || { echo UPDATE_FAIL; exit 1; }

echo "--- malformed body (400) ---"
code=$(curl -s -o /dev/null -w "%{http_code}" -X POST -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{not json' "http://localhost:19080/api/v2/players"); [ "$code" = 400 ] && echo MALFORMED_OK || { echo "MALFORMED_FAIL $code"; exit 1; }

# Teardown: remove the test row directly (no API delete by design).
docker exec ork3-php8-db mariadb -u root -proot ork -e "DELETE FROM ork_mundane WHERE mundane_id=$NEWID;" && echo TEARDOWN_OK
```

Run: `bash orkapi/tests/integration/players_write.sh` → `CREATE_OK`, `UPDATE_OK`, `MALFORMED_OK`, `TEARDOWN_OK`.

- [ ] **Step 4: Commit.**

```bash
chmod +x orkapi/tests/integration/players_write.sh
git add system/lib/app/Player/PlayerService.php orkapi/src/Controller/RestPlayerController.php orkapi/tests/integration/players_write.sh
git commit -m "Enhancement: Player v2 writes (POST/PATCH) with boundary authorization; no hard delete"
```

---

## Task 19: POST /api/v2/sessions — token acquisition

**Files:** Create `orkapi/src/Controller/SessionController.php`; Test `orkapi/tests/integration/sessions.sh`.

> Exposes the EXISTING token issuance over REST so tokenless clients (mobile) can authenticate. Validates username/password via the legacy login path and returns `{ token, expiresAt }`. This is unauthenticated (it IS the auth entry point) and does NOT extend `BaseRestController`.

- [ ] **Step 1: Implement** (`orkapi/src/Controller/SessionController.php`):

```php
<?php

namespace Ork\Api\Controller;

use Ork\Api\Http\RestRequest;
use Ork\Api\Http\ApiResponse;
use Ork\Api\Db\Sql;
use Ork\Api\Exception\{ValidationException, UnauthenticatedException, MethodNotAllowedException};

/**
 * POST /api/v2/sessions  { username, password } -> { token, expiresAt }
 * Wraps the existing legacy login/token issuance. Stateless: returns the token
 * in the body; does not rely on a PHP session.
 */
final class SessionController
{
    public function handle(RestRequest $request): ApiResponse
    {
        if ($request->method() !== 'POST') {
            throw new MethodNotAllowedException('Only POST is supported.', ['POST']);
        }
        $username = trim((string) $request->bodyParam('username', ''));
        $password = (string) $request->bodyParam('password', '');
        if ($username === '' || $password === '') {
            throw new ValidationException('username and password are required.', [
                'username' => $username === '' ? 'required' : null,
                'password' => $password === '' ? 'required' : null,
            ]);
        }

        // Delegate to the legacy login that validates credentials and issues a token.
        // IMPLEMENTER: confirm the exact method + request/response keys in
        // class.Authorization.php (the SOAP Authorization login path that returns
        // Token + Timeout). Typical shape:
        $resp = \Ork3::$Lib->authorization->Login(['UserName' => $username, 'Password' => $password]);

        $token = $this->extractToken($resp);
        if ($token === null) {
            throw new UnauthenticatedException('Invalid credentials.');
        }

        // Read the canonical expiry from the row we just authenticated.
        global $DB;
        $DB->Clear();
        $rs = $DB->DataSet("SELECT token_expires FROM " . DB_PREFIX . "mundane WHERE token = " . Sql::quote($token) . " LIMIT 1");
        $expiresAt = ($rs && $rs->Next()) ? (string) $rs->token_expires : null;

        return ApiResponse::created(['token' => $token, 'expiresAt' => $expiresAt]);
    }

    private function extractToken(array $resp): ?string
    {
        // Accept either the global-envelope Detail or an explicit Token field.
        $candidates = [$resp['Token'] ?? null, $resp['Status']['Detail'] ?? null, $resp['Detail'] ?? null];
        foreach ($candidates as $c) {
            if (is_string($c) && strlen($c) === 32) {
                return $c;
            }
        }
        return null;
    }

    #[\OpenApi\Attributes\Post(
        path: '/sessions', summary: 'Authenticate and obtain a Bearer token.', tags: ['Auth'],
        requestBody: new \OpenApi\Attributes\RequestBody(required: true, content: new \OpenApi\Attributes\JsonContent(
            required: ['username', 'password'],
            properties: [
                new \OpenApi\Attributes\Property(property: 'username', type: 'string'),
                new \OpenApi\Attributes\Property(property: 'password', type: 'string', format: 'password'),
            ]
        )),
        responses: [
            new \OpenApi\Attributes\Response(response: 201, description: 'Token issued.', content: new \OpenApi\Attributes\JsonContent(
                properties: [
                    new \OpenApi\Attributes\Property(property: 'token', type: 'string'),
                    new \OpenApi\Attributes\Property(property: 'expiresAt', type: 'string', format: 'date-time', nullable: true),
                ]
            )),
            new \OpenApi\Attributes\Response(response: 401, description: 'Invalid credentials.', content: new \OpenApi\Attributes\JsonContent(ref: '#/components/schemas/ApiError')),
            new \OpenApi\Attributes\Response(response: 422, description: 'Missing fields.', content: new \OpenApi\Attributes\JsonContent(ref: '#/components/schemas/ApiError')),
        ]
    )]
    private function _doc(): void
    {
    }
```

> Note the doc attribute is on a tiny **public-equivalent** carrier method — but swagger-php skips private. **Implementer:** put the `#[OA\Post]` on `handle()` (public) OR on a public no-op, NOT on `_doc()` private. Move the attribute block to `handle()`. (Left here only to show the operation shape.) Confirm the legacy login method name (`Login`/`Authenticate`) and its return; locally the `|| true` bypass means any password authenticates an existing username.

- [ ] **Step 2: Integration test** (`orkapi/tests/integration/sessions.sh`):

```bash
#!/usr/bin/env bash
set -u
echo "--- POST /sessions (valid) ---"
R=$(curl -s -X POST -H 'Content-Type: application/json' -d '{"username":"admin","password":"x"}' http://localhost:19080/api/v2/sessions)
echo "$R"; printf '%s' "$R" | grep -q '"token":"' && echo MINT_OK || { echo MINT_FAIL; exit 1; }
echo "--- missing fields (422) ---"
code=$(curl -s -o /dev/null -w "%{http_code}" -X POST -H 'Content-Type: application/json' -d '{"username":"admin"}' http://localhost:19080/api/v2/sessions); [ "$code" = 422 ] && echo VALIDATION_OK || { echo "VALIDATION_FAIL $code"; exit 1; }
echo "--- GET not allowed (405) ---"
code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:19080/api/v2/sessions); [ "$code" = 405 ] && echo METHOD_OK || { echo "METHOD_FAIL $code"; exit 1; }
```

Run: `bash orkapi/tests/integration/sessions.sh` → `MINT_OK`, `VALIDATION_OK`, `METHOD_OK`. Then run the Task 15/17/18 integration scripts that `source api.sh`.

- [ ] **Step 3: Commit.**

```bash
chmod +x orkapi/tests/integration/sessions.sh
git add orkapi/src/Controller/SessionController.php orkapi/tests/integration/sessions.sh
git commit -m "Enhancement: POST /api/v2/sessions token acquisition (wraps existing issuance)"
```

---

## Task 20: OpenAPI generation (swagger-php v5 → 3.1) + served public spec + EARLY smoke

**Files:** Create `tools/openapi/composer.json`, `bin/openapi-gen.php`, `orkapi/src/OpenApi/Info.php`; Modify `orkapi/index.php`.

- [ ] **Step 1: Declare the build dep (v5 for 3.1)** — `tools/openapi/composer.json`:

```json
{
    "require": { "zircote/swagger-php": "^5.0" },
    "config": { "vendor-dir": "vendor" }
}
```

- [ ] **Step 2: Install (build-time only; vendor stays gitignored).**

```bash
docker exec ork3-php8-app bash -lc 'cd /var/www/ork.amtgard.com/tools/openapi && (command -v composer || (php -r "copy(\"https://getcomposer.org/installer\",\"ci.php\");" && php ci.php && mv composer.phar /usr/local/bin/composer && rm ci.php)) && composer install --no-interaction'
```
Expected: `tools/openapi/vendor/` with `zircote/swagger-php` v5.x. (If the container has no network, run the same in `tools/openapi/` on the host.)

- [ ] **Step 3: Top-level metadata** — `orkapi/src/OpenApi/Info.php`:

```php
<?php

namespace Ork\Api\OpenApi;

use OpenApi\Attributes as OA;

#[OA\OpenApi(openapi: '3.1.0')]
#[OA\Info(version: '2.0.0', title: 'ORK API', description: 'The Amtgard Online Record Keeper REST API (v2).')]
#[OA\Server(url: '/api/v2', description: 'v2 REST API')]
#[OA\SecurityScheme(
    securityScheme: 'bearerAuth', type: 'http', scheme: 'bearer',
    description: 'Interim: obtain a token via POST /api/v2/sessions and present it as a Bearer credential. Dedicated API keys are a future phase.'
)]
#[OA\Tag(name: 'Players', description: 'Player records.')]
#[OA\Tag(name: 'Auth', description: 'Authentication.')]
final class Info
{
}
```

- [ ] **Step 4: Generator** — `bin/openapi-gen.php`:

```php
<?php

/**
 * Generates orkapi/openapi.json (OpenAPI 3.1) from swagger-php attributes in the
 * orkapi/ transport layer. --check exits non-zero if the committed file is stale.
 */
$root = dirname(__DIR__);
require_once $root . '/tools/openapi/vendor/autoload.php';

// Scan ONLY the transport layer (schemas + controllers + Info). DTOs stay attribute-free.
$openapi = \OpenApi\Generator::scan([$root . '/orkapi/src']);

$json = $openapi->toJson() . "\n";

// Hard assertion: the emitted document MUST be 3.1.0 (v4 would emit 3.0.0).
$decoded = json_decode($json, true);
if (($decoded['openapi'] ?? '') !== '3.1.0') {
    fwrite(STDERR, "ERROR: generated openapi is '" . ($decoded['openapi'] ?? 'none') . "', expected 3.1.0. Is swagger-php v5 installed?\n");
    exit(2);
}
if (empty($decoded['paths'])) {
    fwrite(STDERR, "ERROR: no paths generated — operation attributes must be on PUBLIC methods.\n");
    exit(2);
}

$target = $root . '/orkapi/openapi.json';
if (in_array('--check', $argv, true)) {
    $current = is_file($target) ? file_get_contents($target) : '';
    if ($current !== $json) {
        fwrite(STDERR, "openapi.json is out of date. Run: php bin/openapi-gen.php\n");
        exit(1);
    }
    echo "openapi.json is current.\n";
    exit(0);
}
file_put_contents($target, $json);
echo "Wrote $target (" . strlen($json) . " bytes)\n";
```

> If `Generator::scan` honoring `#[OA\OpenApi(openapi:'3.1.0')]` doesn't yield 3.1 in the installed v5, set it explicitly via the generator API (v5: `(new \OpenApi\Generator())->setVersion('3.1.0')->generate([...])`) — the Step-5 assertion will force you to get this right.

- [ ] **Step 5: Generate.** `docker exec ork3-php8-app php /var/www/ork.amtgard.com/bin/openapi-gen.php` → `Wrote .../openapi.json`.

- [ ] **Step 6: Validate version + paths + schemas + security.**

```bash
docker exec ork3-php8-app php -r '
$o=json_decode(file_get_contents("/var/www/ork.amtgard.com/orkapi/openapi.json"),true);
echo ($o["openapi"]??"")==="3.1.0"?"VER_OK\n":"VER_FAIL\n";
echo isset($o["paths"]["/players/{id}"]["get"])?"GET_OK\n":"GET_FAIL\n";
echo isset($o["paths"]["/players"]["post"])?"POST_OK\n":"POST_FAIL\n";
echo isset($o["paths"]["/sessions"]["post"])?"SESS_OK\n":"SESS_FAIL\n";
echo isset($o["components"]["schemas"]["Player"],$o["components"]["schemas"]["ApiError"],$o["components"]["schemas"]["PlayerListResponse"])?"SCHEMA_OK\n":"SCHEMA_FAIL\n";
echo isset($o["components"]["securitySchemes"]["bearerAuth"])?"SEC_OK\n":"SEC_FAIL\n";'
```
Expected: all `_OK`. (If `POST_FAIL`/`GET_FAIL`: attributes are on private methods — make them public.)

- [ ] **Step 7: Serve the spec publicly with cache headers** — insert into `orkapi/index.php` after the `ping` block:

```php
if ($request->resource() === 'openapi.json' && $request->id() === null && $request->subresource() === null) {
    $file = __DIR__ . '/openapi.json';
    $etag = '"' . md5_file($file) . '"';
    header('Content-Type: application/json; charset=utf-8');
    header('Cache-Control: public, max-age=300');
    header('ETag: ' . $etag);
    if (($_SERVER['HTTP_IF_NONE_MATCH'] ?? '') === $etag) {
        http_response_code(304);
        exit;
    }
    readfile($file);
    exit;
}
```

- [ ] **Step 8: Verify served endpoint.** `curl -s http://localhost:19080/api/v2/openapi.json | head -c 80; echo` → starts `{"openapi":"3.1.0",...`.

- [ ] **Step 9: Commit (spec + generator + metadata; NOT vendor).**

```bash
git add tools/openapi/composer.json bin/openapi-gen.php orkapi/src/OpenApi/Info.php orkapi/openapi.json orkapi/index.php
git diff --cached --stat
git commit -m "Enhancement: OpenAPI 3.1 generation (swagger-php v5) + served public spec"
```

---

## Task 21: Developer portal (Scalar, pinned) — gated controller + template

**Files:** Create `orkui/controller/controller.Developer.php`, `orkui/template/default/Developer_index.tpl`.

(Controller + gate logic as previously specified: `Developer/index`, redirect if logged out, `isAuthorizedDeveloper($uid)` = `HasAuthority($uid,AUTH_ADMIN,0,AUTH_ADMIN)` OR a row in `ork_api_developer`. Template embeds Scalar.)

- [ ] **Step 1: Controller** — `orkui/controller/controller.Developer.php`:

```php
<?php

class Controller_Developer extends Controller
{
    public function __construct($request = null, $action = null)
    {
        parent::__construct();
        $this->request = $request;
        $this->action = $action;
    }

    public function index($action = null)
    {
        if (!isset($this->session->user_id)) {
            header('Location: ' . UIR . 'Login');
            exit;
        }
        $uid = (int) $this->session->user_id;
        $this->data['denied'] = !$this->isAuthorizedDeveloper($uid);
        $this->data['specUrl'] = '/api/v2/openapi.json';
        // Mint a fresh token for the embedded "try it" console so it works without
        // exposing the session cookie to the (stateless) API.
        $this->data['bearer'] = (string) ($this->session->token ?? '');
        $this->view('Developer_index');
    }

    private function isAuthorizedDeveloper(int $uid): bool
    {
        if (Ork3::$Lib->authorization->HasAuthority($uid, AUTH_ADMIN, 0, AUTH_ADMIN)) {
            return true;
        }
        global $DB;
        $DB->Clear();
        $rs = $DB->DataSet("SELECT 1 FROM " . DB_PREFIX . "api_developer WHERE mundane_id = " . $uid . " LIMIT 1");
        return $rs && $rs->Next();
    }
}
```

> **Implementer:** confirm `Controller::view()` signature + `$this->data` propagation against an existing controller (e.g. `controller.Player.php::profile`). Mirror it exactly. Note the "try it" token is the session token, which the stateless `AuthMiddleware` validates against `ork_mundane.token`+expiry — it works as a real Bearer.

- [ ] **Step 2: Template** — `orkui/template/default/Developer_index.tpl` (Scalar **pinned**):

```php
<?php if (!empty($denied)) : ?>
    <div class="info-container">
        <h3>API Developer Access Required</h3>
        <p>Your account is not on the authorized API developers list. Contact an ORK administrator to request access.</p>
    </div>
<?php else : ?>
    <div id="scalar-api-reference"></div>
    <script>
        window.__ORK_API_SPEC = <?= json_encode($specUrl) ?>;
        window.__ORK_API_BEARER = <?= json_encode($bearer) ?>;
    </script>
    <script src="https://cdn.jsdelivr.net/npm/@scalar/api-reference@1.25.0"></script>
    <script>
        Scalar.createApiReference('#scalar-api-reference', {
            url: window.__ORK_API_SPEC,
            authentication: { preferredSecurityScheme: 'bearerAuth', http: { bearer: { token: window.__ORK_API_BEARER } } },
            darkMode: document.documentElement.classList.contains('dark') || document.body.classList.contains('dark')
        });
    </script>
<?php endif; ?>
```

> **Implementer:** pin to the latest tested `@scalar/api-reference` tag (the `1.25.0` above is a placeholder — set to the version you verify) and confirm `createApiReference(selector, config)` + the `authentication` config shape against THAT version (the auth-config keys have changed across releases). Verify ORK's dark-mode selector. If CSP/offline forbids the CDN, vendor the JS under `assets/`.

- [ ] **Step 3: Verify gating.** Logged-out: `curl -s -o /dev/null -w "%{http_code}\n" "http://localhost:19080/orkui/index.php?Route=Developer/index"` → `302`.

- [ ] **Step 4: Browser verification** (project rule — Chrome only to verify): log in as admin, open `Developer/index`, confirm Scalar renders Players + Auth, dark mode correct, and "try it" on `GET /players/{id}` returns a real player via the preloaded Bearer. Screenshot.

- [ ] **Step 5: Commit.**

```bash
git add orkui/controller/controller.Developer.php orkui/template/default/Developer_index.tpl
git commit -m "Enhancement: auth-gated Scalar developer portal (Developer/index)"
```

---

## Task 22: "Authorized API Developers" tool (table + admin CRUD UI)

**Files:** Create `db-migrations/2026-06-13-add-ork-api-developer.sql`, `orkui/template/default/Admin_apidevelopers.tpl`; Modify `orkui/controller/controller.AdminAjax.php`, `orkui/template/default/Admin_index.tpl`.

- [ ] **Step 1: Migration** — `db-migrations/2026-06-13-add-ork-api-developer.sql`:

```sql
-- Authorized API Developers allowlist — gates the v2 developer portal
-- (index.php?Route=Developer/index). ORK Admins are always allowed in code; this
-- table designates additional non-admin viewers. Key/PAT issuance is out of scope.
-- Re-runnable.
CREATE TABLE IF NOT EXISTS ork_api_developer (
    api_developer_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    mundane_id       INT UNSIGNED NOT NULL,
    granted_by       INT UNSIGNED NOT NULL,
    note             VARCHAR(255) NOT NULL DEFAULT '',
    granted_at       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (api_developer_id),
    UNIQUE KEY uniq_api_developer_mundane (mundane_id)
);
```

Apply + verify:
```bash
docker exec -i ork3-php8-db mariadb -u root -proot ork < db-migrations/2026-06-13-add-ork-api-developer.sql
docker exec ork3-php8-db mariadb -N -u root -proot ork -e "SHOW TABLES LIKE 'ork_api_developer';"
```

- [ ] **Step 2: AdminAjax `apidev` action** — add to `controller.AdminAjax.php`, mirroring the existing admin-gated `global()` pattern, using `Ork\Api\Db\Sql` is unavailable here (UI tier doesn't autoload Ork\Api) — use the existing inline escape idiom for `note` and integer casts for ids:

```php
    public function apidev($p = null)
    {
        header('Content-Type: application/json');
        if (!isset($this->session->user_id)) { echo json_encode(['status' => 5, 'error' => 'Not logged in.']); exit; }
        $uid = (int) $this->session->user_id;
        if (!Ork3::$Lib->authorization->HasAuthority($uid, AUTH_ADMIN, 0, AUTH_ADMIN)) { echo json_encode(['status' => 5, 'error' => 'Not authorized.']); exit; }

        $action = trim($p ?? '');
        global $DB;

        if ($action === 'list') {
            $DB->Clear();
            $rs = $DB->DataSet("SELECT d.api_developer_id, d.mundane_id, d.note, d.granted_at, m.persona
                FROM " . DB_PREFIX . "api_developer d LEFT JOIN " . DB_PREFIX . "mundane m ON m.mundane_id = d.mundane_id ORDER BY m.persona");
            $rows = [];
            if ($rs) { while ($rs->Next()) { $rows[] = ['id' => (int) $rs->api_developer_id, 'mundaneId' => (int) $rs->mundane_id, 'persona' => $rs->persona, 'note' => $rs->note, 'grantedAt' => $rs->granted_at]; } }
            echo json_encode(['status' => 0, 'developers' => $rows]); exit;
        }
        if ($action === 'add') {
            $mid = (int) ($_POST['MundaneId'] ?? 0);
            $note = substr(trim((string) ($_POST['Note'] ?? '')), 0, 255);
            $noteEsc = str_replace(['\\', "'"], ['\\\\', "''"], $note);
            if ($mid <= 0) { echo json_encode(['status' => 1, 'error' => 'Invalid player.']); exit; }
            $DB->Clear();
            $DB->Execute("INSERT IGNORE INTO " . DB_PREFIX . "api_developer (mundane_id, granted_by, note, granted_at) VALUES ($mid, $uid, '$noteEsc', NOW())");
            $DB->Clear();
            $rs = $DB->DataSet("SELECT d.api_developer_id, m.persona FROM " . DB_PREFIX . "api_developer d LEFT JOIN " . DB_PREFIX . "mundane m ON m.mundane_id = d.mundane_id WHERE d.mundane_id = $mid LIMIT 1");
            $id = 0; $persona = '';
            if ($rs && $rs->Next()) { $id = (int) $rs->api_developer_id; $persona = $rs->persona; }
            echo json_encode(['status' => 0, 'id' => $id, 'mundaneId' => $mid, 'persona' => $persona, 'note' => $note]); exit;
        }
        if ($action === 'remove') {
            $id = (int) ($_POST['Id'] ?? 0);
            if ($id <= 0) { echo json_encode(['status' => 1, 'error' => 'Invalid id.']); exit; }
            $DB->Clear();
            $DB->Execute("DELETE FROM " . DB_PREFIX . "api_developer WHERE api_developer_id = $id");
            echo json_encode(['status' => 0]); exit;
        }
        echo json_encode(['status' => 1, 'error' => 'Unknown action.']); exit;
    }
```

- [ ] **Step 3: Management template** — `Admin_apidevelopers.tpl`: global unscoped `kn-ac-results` player search (URL built with `&q=`, `tnFixedAcPosition(input,dropdown)` defined on the page, positioned before `classList.add('kn-ac-open')`), optional note field, "Add Developer" → `AdminAjax/apidev/add`, current-developers table from `AdminAjax/apidev/list`, "Remove" via `tnConfirm({...})` → `AdminAjax/apidev/remove`. Dark-mode pass. Mirror an existing admin tool template (e.g. Edit-Auths) for markup/JS conventions.

- [ ] **Step 4: Sidebar entry** — in `Admin_index.tpl`, inside the `ORK Management` `<ul>` near `Edit Auths`:

```html
        <li><a href='<?=UIR ?>Admin/apidevelopers'>Authorized API Developers</a></li>
```

Wire `Admin/apidevelopers` → renders `Admin_apidevelopers.tpl` mirroring an existing `Admin/<x>` tool method in `controller.Admin.php`.

- [ ] **Step 5: Curl-test list/add (admin session cookie) + verify search returns rows.**

```bash
JAR=$(mktemp)
curl -s -c "$JAR" -b "$JAR" --data-urlencode "username=admin" --data-urlencode "password=x" "http://localhost:19080/orkui/index.php?Route=Login/login" > /dev/null
MID=$(docker exec ork3-php8-db mariadb -N -u root -proot ork -e "SELECT mundane_id FROM ork_mundane WHERE active=1 AND LENGTH(persona)>0 ORDER BY mundane_id DESC LIMIT 1;")
curl -s -b "$JAR" -d "MundaneId=$MID&Note=plan-test" "http://localhost:19080/orkui/index.php?Route=AdminAjax/apidev/add"; echo
curl -s -b "$JAR" "http://localhost:19080/orkui/index.php?Route=AdminAjax/apidev/list"; echo
# Verify the player-search endpoint the template uses returns rows (project rule), built with &q=:
curl -s -b "$JAR" "http://localhost:19080/orkui/index.php?Route=SearchAjax/<the-search-action>&q=a" | head -c 200; echo
```
Expected: add `{"status":0...}`, list includes the developer, search returns rows.

- [ ] **Step 6: Browser verification.** As admin: open `Admin/apidevelopers`, add a developer via search, see the row, remove via `tnConfirm`, dark-mode check. Log in as that non-admin developer → `Developer/index` now renders the docs.

- [ ] **Step 7: Commit.**

```bash
git add db-migrations/2026-06-13-add-ork-api-developer.sql orkui/controller/controller.AdminAjax.php orkui/template/default/Admin_apidevelopers.tpl orkui/template/default/Admin_index.tpl
git diff --cached
git commit -m "Enhancement: Authorized API Developers admin tool + ork_api_developer allowlist"
```

---

## Task 23: SDLC — conventions doc, CLAUDE rule, pre-commit spec check

**Files:** Create `agent-instructions/api-v2-conventions.md`; Modify `.githooks/pre-commit`.

- [ ] **Step 1: Conventions reference** — `agent-instructions/api-v2-conventions.md` documenting: the 3-layer model (orkapi transport / system/lib/app pure services+DTOs / legacy untouched); the strangler rule (new logic in `system/lib/app/`, never back into `class.*`); **OpenAPI attributes live only in `orkapi/src/Schema` + controllers, never on DTOs**; resource/verb/status conventions (PATCH-only, 405 for PUT, 404 unknown resource, 400 malformed, 422 invalid); the success envelope (collections `{data,meta}`, items bare) + the `ApiError` enum; **stateless auth** (validate tokens via `AuthMiddleware`, never `IsAuthorized`, never start a session); the `Sql` escaping helper is mandatory for raw SQL and raw SQL in a service is allowed only for list/search (single-entity reads/writes delegate to legacy); the LegacyEnvelope mapper for legacy results; how to regenerate (`php bin/openapi-gen.php`) and that an endpoint can't merge without public attributes (pre-commit check); the deprecation convention (future: `Deprecation`/`Sunset` headers + `deprecated:true`); and a worked "add a new resource" checklist mirroring Player (Schema + DTO + Service + Controller(public ops) + route + tests + regen).

- [ ] **Step 2: Pre-commit spec freshness** — add to `.githooks/pre-commit` after the PSR-12 logic, preserving the Authorization.php guard:

```bash
# --- v2 OpenAPI spec freshness ---
if git diff --cached --name-only | grep -Eq '^(orkapi/src/|orkapi/openapi\.json)'; then
    if docker ps --format '{{.Names}}' | grep -q '^ork3-php8-app$'; then
        if ! docker exec ork3-php8-app php /var/www/ork.amtgard.com/bin/openapi-gen.php --check; then
            echo "ERROR: orkapi/openapi.json is stale. Run: php bin/openapi-gen.php, then stage it." >&2
            exit 1
        fi
    else
        echo "WARN: ork3-php8-app not running; OpenAPI freshness NOT enforced locally (CI enforces it — Phase 3)." >&2
    fi
fi
```

> The local hook is advisory when the container is down; the enforcing guarantee is the Phase-3 CI job. The conventions doc states this honestly.

- [ ] **Step 3: Verify the check.** `docker exec ork3-php8-app php /var/www/ork.amtgard.com/bin/openapi-gen.php --check` → `openapi.json is current.` (After editing an attribute without regenerating, it prints the stale error + exits 1.)

- [ ] **Step 4: Commit.**

```bash
git add agent-instructions/api-v2-conventions.md .githooks/pre-commit
git commit -m "Enhancement: API v2 SDLC — conventions doc + pre-commit OpenAPI freshness check"
```

---

## Phase 1 acceptance

- [ ] `bash orkapi/tests/run-all.sh` → exit 0 (all unit/service tests).
- [ ] `bash orkapi/tests/integration/sessions.sh` → MINT/VALIDATION/METHOD OK.
- [ ] `bash orkapi/tests/integration/routing.sh` → PING_OK + correct resource parse (no `index.php` misparse).
- [ ] `bash orkapi/tests/integration/players_read.sh` → SHOW/LIST/AUTH/NF/PUT405 OK.
- [ ] `bash orkapi/tests/integration/players_write.sh` → CREATE/UPDATE/MALFORMED/TEARDOWN OK.
- [ ] `curl http://localhost:19080/api/v2/openapi.json` → `openapi:3.1.0` with `/players`, `/players/{id}`, `/sessions` paths; `Player`/`ApiError`/`PageMeta`/`PlayerListResponse` schemas; `bearerAuth`.
- [ ] Developer portal renders Scalar for an admin + an allow-listed developer; denies others; dark mode correct (browser-verified).
- [ ] Authorized API Developers tool adds/removes developers (browser-verified); player search returns rows.
- [ ] `git log --oneline` shows one focused commit per task; `class.Authorization.php` never staged.

---

# Phase 2 — Parallel fan-out (separate plan, generated from the realized template)

After Phase 1, the Player vertical (Schema + pure DTO + Service + public-op Controller + routes + tests, all over the shared `BaseRestController` + `LegacyEnvelope` + `Sql` base) is the concrete template. Phase 2 gets its own plan generated from the **actual** files.

**Fan-out set (one worktree-isolated agent per resource):** Award, Event, Kingdom, Park, Unit, Attendance, Tournament, Report, Search, Heraldry, Calendar, Treasury, Map, Notification, Principality, Pronoun, DataSet.

**Per-resource shape:** (1) `{Resource}Schema` (transport, attributed, `required`/nullable/formats); (2) pure `{Resource}DTO` + `fromLegacy`/`toArray`; (3) `{Resource}Service` over the shared base (confirm legacy method names + which ops the resource supports — many are read-only: Report/Search expose only GET; resources without a legacy delete get no DELETE); (4) `Rest{Resource}Controller extends BaseRestController` (public ops only) + register in `routes.php`; (5) integration test (read/write/auth/errors); (6) regenerate `openapi.json`, confirm new paths/schemas, commit. Sub-resources (e.g. `/players/{id}/awards`) use `subresource()` on the owner controller. Apply the `{data,meta}` list envelope uniformly.

---

# Phase 3 — SDLC hardening (own small plan)

- CI job (not just local hook): `php bin/openapi-gen.php --check` **plus** structural validation of `openapi.json` against an OpenAPI 3.1 validator.
- Portal "legacy v1 vs v2" page (SOAP/JSON-RPC frozen; v2 is the path forward).
- One-line `MEMORY.md` entry for the API v2 architecture (respect the index size rule).
- Deprecation/Sunset header support + `deprecated:true` flagging when first needed.
- **Future auth phase (explicitly deferred):** Personal Access Token / API-key issuance + management + rate limiting, replacing the interim session-token reuse; token refresh/rotation contract surfaced to clients.
