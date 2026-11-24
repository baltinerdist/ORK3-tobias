# Phase 1 — Foundation

Builds the shared kernel, the key system, session-token hashing at rest, the spec pipeline, the docs explorer, the two shared-shell edits and one fully worked reference resource. Nothing in Phases 2 and 3 starts until the review gate F-30 passes.

- Integration branch: `api-v2/phase-1` off `refactor/api-reconstruction`. Exception: F-31 is a single focused PR against `master` (it changes v1 too and ships on its own); the orchestrator merges `master` into the phase branch once it lands.
- 33 tasks (F-01 to F-33), 6 waves. Tasks inside a wave run in parallel, each in its own worktree; file ownership is exclusive per task.
- Model tier is Sonnet unless the task says Opus. Size is the expected changed lines including tests.

## 1. Rules every task brief must repeat

1. Code under `orkservice/Api/` contains no SQL, no `$DB`, no `DB_PREFIX`, no `Ork3::$Lib->…->db`. New SQL goes in the `system/lib/ork3/class.Api*.php` file the task owns, with bound parameters (`$DB->Clear(); $DB->name = $v; $DB->DataSet('… :name')`) or `(int)` casts. `mysql_real_escape_string` is forbidden.
2. Yapo gotchas apply to every domain class: `Clear()` before raw `Execute`/`DataSet`; `DataSet()` needs `->Next()`; assign `''` not `null`; a failed query does not return false, so check `SQLSTATE`; transactions are on `YapoMysql`; `lastInsertId() == 0` does not mean duplicate key, read back by the unique value.
3. Every public method on a new `system/lib/ork3/class.Api*.php` class has an underscore in its name (`find_by_prefix`). Constructors do no I/O.
4. Runtime code must parse and run on PHP 8.1: no `readonly class`, no DNF or standalone `true`/`false`/`null` types, no constants in traits, no `#[\SensitiveParameter]`. Readonly properties, enums, first-class callable syntax and `new` in attribute arguments are fine.
5. Never edit, stage or commit `system/lib/ork3/class.Authorization.php`; the only exception is F-31, done by the procedure in its entry. Never add a class to the whitelist in `orkservice/Json/index.php`.
6. Stage explicit paths, run `git diff --cached`, never `git add -A`, never `git stash`. Commit with `ORK_API_SPEC_STAGE=0` once F-27 exists so generated files stay out of task branches.
7. Tests never log in as or reuse the sessions of `heraldsbridge` or `admin`. Use fixtures (`seedSession`, `seedApiKey`).
8. UI work: `orkui/template/revised-frontend/` only (F-33 alone edits `orkui/template/default/default.theme`, a documented exception, overview D24); `.tpl` files are plain PHP; dark mode via `html[data-theme="dark"]` with existing `--ork-*` tokens; no native `confirm`/`alert`/`prompt`; tooltips `data-tip`; tables DataTables (`columnDefs` string targets are bare class names); player pickers use the `kn-ac-results` dropdown positioned with `tnPositionAcFixed()` in modals; dates human-readable (Flatpickr `altInput`).

## 2. Commands

| Purpose | Main checkout | Worktree `.worktrees/<wt>` |
|---|---|---|
| PHPUnit, one path | `ENVIRONMENT=TEST php vendor/bin/phpunit -c phpunit.xml.dist --no-coverage <path>` | `ENVIRONMENT=TEST php ../../vendor/bin/phpunit -c phpunit.xml.dist --no-coverage --cache-directory=<scratch> <path>` |
| PHP 8.1 syntax | `docker exec ork3-php8-app php -l /var/www/ork.amtgard.com/<file>` | `docker exec ork3-php8-app php -l /var/www/ork.amtgard.com/.worktrees/<wt>/<file>` |
| Build spec | `php tools/api-spec/build.php` | same |
| Check spec | `php tools/api-spec/build.php --check` | same |
| Lint spec | `npx --no-install redocly lint orkservice/Api/spec/openapi.v2.json` | `../../node_modules/.bin/redocly lint orkservice/Api/spec/openapi.v2.json` (the worktree has no `node_modules`) |
| Call the API before nginx is rebuilt | `curl -si 'http://localhost:19080/orkservice/Api/index.php?_path=/v2/ping'` | `curl -si 'http://localhost:19080/.worktrees/<wt>/orkservice/Api/index.php?_path=/v2/ping'` |
| Apply a migration | `docker exec -i ork3-php8-db mariadb -u root -proot ork < db-migrations/<file>.sql`, the same against the sandbox DB, then `php tools/ork-db/cli.php drift-check --strict` | same |

`_path` is a development fallback honoured only when `ENVIRONMENT` is `DEV` or `TEST`. Do not run `bin/run-ork-db-checks.sh` (it redeploys the sandbox).

## 3. Interface contract

F-02 creates these files with exactly these signatures. Later tasks implement bodies and may add private members, but may not change a public signature without the orchestrator amending this section.

### 3.1 HTTP primitives (`orkservice/Api/src/Kernel/`)

```php
namespace Ork\Api\Kernel;

final class Request
{
    public function __construct(
        public readonly string $method,      // upper-case
        public readonly string $path,        // e.g. "/v2/players/12", no query string
        public readonly array $query,        // raw
        public readonly array $headers,      // lower-case names => string
        public readonly string $rawBody,
        public readonly array $files,        // $_FILES shape
        public readonly string $clientIp,    // REMOTE_ADDR only
        public readonly string $requestId    // 26-char ULID
    ) {}
    public static function fromGlobals(): self;
    public function header(string $name): ?string;
    public array $params = [];               // validated path params (typed)
    public array $input = [];                // validated query + body (typed)
    public ?array $route = null;             // matched entry of routes.v2.php 'ops'
}

final class Response
{
    public function __construct(public int $status, public array $headers = [], public ?string $body = null) {}
    public static function json(mixed $payload, int $status = 200, array $headers = []): self;
    public static function noContent(array $headers = []): self;
    public static function stream(string $contentType, callable $emit, array $headers = []): self;
    public function withHeader(string $name, string $value): self;
}

final class Problem extends \RuntimeException
{
    public function __construct(
        public readonly int $status,
        public readonly string $errorCode,   // from ErrorCodes
        string $title,
        public readonly ?string $detail = null,
        public readonly array $errors = [],  // [['field' => 'body.park_id', 'code' => 'required', 'message' => '…']]
        public readonly array $headers = []
    ) { parent::__construct($title); }
    public function toArray(string $requestId): array;
}

final class ErrorCodes { /* string constants; closed list, section 3.7 */ }

interface Middleware { public function handle(Request $request, callable $next): Response; }

final class Kernel
{
    /** @param Middleware[] $middleware */
    public function __construct(array $routes, array $schemas, array $middleware, callable $handlerFactory) {}
    public function handle(Request $request): Response;   // never throws
}
```

### 3.2 Principal and context (`src/Auth/`, `src/Kernel/`)

```php
namespace Ork\Api\Auth;

final class Principal
{
    public function __construct(
        public readonly ?array $key,          // ork_api_key row or null
        public readonly int $actorId,         // 0 = no actor
        public readonly string $actorVia,     // 'none' | 'session' | 'service_key'
        public readonly ?string $sessionToken,
        public readonly array $scopes         // effective scopes after 5.2 rules
    ) {}
    public function hasKey(): bool;
    public function hasActor(): bool;
    public function hasScope(string $scope): bool;
    public function keyId(): int;
}

final class Scopes { public const ALL = [/* overview 5.4 */]; public const PUBLISHABLE_FORBIDDEN = ['admin:read', 'admin:write', 'idp:integration']; public const ACTS_AS_OWNER_FORBIDDEN = ['admin:write']; }

namespace Ork\Api\Kernel;

final class Context
{
    public function __construct(public readonly Request $request, public readonly \Ork\Api\Auth\Principal $principal) {}
    public function actorId(): int;
    public function token(): string;                       // session token to hand to domain methods; '' if none
    public function domain(string $class): object;         // new $class() for a system/lib/ork3 class
    public function tierFor(Subject $subject): string;     // highest Tier the principal holds for the subject
}
```

### 3.3 Results, presenter, visibility

```php
namespace Ork\Api\Kernel;

final class Subject
{
    public static function none(): self;
    public static function player(int $playerId): self;    // home park/kingdom resolved lazily via ApiFacts
    public static function park(int $parkId): self;
    public static function kingdom(int $kingdomId): self;
    public static function event(int $eventId): self;
    public static function unit(int $unitId): self;
}

final class Tier { public const PUBLIC='public', AUTHENTICATED='authenticated', SELF='self', OFFICER='officer', ADMIN='admin'; }

final class Result
{
    public static function ok(array $data, string $schema, ?Subject $subject = null): self;
    /** @param array<int,array> $items; $subjectOf maps an item to its Subject (null = Subject::none) */
    public static function collection(array $items, string $schema, ?string $nextCursor = null, ?callable $subjectOf = null, array $meta = []): self;
    public static function created(array $data, string $schema, string $location, ?Subject $subject = null): self;
    public static function noContent(): self;
    public static function stream(string $contentType, callable $emit, string $filename = ''): self;
    public function withEtag(string $etag): self;
}

final class Presenter
{
    public function __construct(array $schemas) {}
    /** Emits only declared properties, cast to the declared type, filtered by tier. */
    public function present(array $data, string $schema, string $viewerTier, array $ruleFacts = []): array;
}

final class DomainResult
{
    public static function nested(mixed $r): self;   // ['Status' => ['Status' => int, 'Error', 'Detail'], …payload]
    public static function flat(mixed $r): self;     // ['Status' => int, 'Error', 'Detail', …]   (e.g. AddAward)
    public static function raw(mixed $r): self;      // payload or null/false
    public function isOk(): bool;
    public function payload(): mixed;
    public function detail(): mixed;                 // Success() detail (new ids)
    public function orThrow(): self;                 // maps status to Problem (3.8)
}

final class Cursor
{
    /** base64url(json) + HMAC over position, operation id and a hash of the normalised filters and sort */
    public static function encode(array $position, string $operationId, array $filters): string;
    public static function decode(string $cursor, string $operationId, array $filters): array; // throws Problem 400 invalid_cursor on tamper or mismatch
}
```

Handlers always have this shape and are only ever reached through the compiled route table:

```php
public function get(Request $request, Context $ctx): Result
```

### 3.4 Policy (`src/Policy/`)

```php
namespace Ork\Api\Policy;

final class Decision
{
    public static function allow(): self;
    public static function deny(string $errorCode = 'forbidden'): self;      // -> 403
    public static function notFound(): self;                                 // -> 404
    public static function unauthenticated(string $errorCode = 'actor_required'): self; // -> 401
}

interface Policy
{
    public const NAME = '';
    /** $args are resolved from the route's x-ork-policy (path./query./body. references already substituted). */
    public function decide(\Ork\Api\Auth\Principal $principal, array $args, \Ork\Api\Kernel\Request $request): Decision;
}

final class PolicyEngine
{
    public function __construct(PolicyRegistry $registry) {}
    public function enforce(array $routePolicy, \Ork\Api\Auth\Principal $p, \Ork\Api\Kernel\Request $r): void; // throws Problem
}
```

### 3.5 Domain support classes (`system/lib/ork3/`)

Return arrays, never objects. All methods snake_case.

```php
class ApiKey extends Ork3 {
    public static function parse_key(string $presented): ?array;          // ['type','env','prefix'] or null
    public static function hash_key(string $presented): string;           // HMAC-SHA256 hex with ORK_API_KEY_PEPPER
    public function issue_key(array $spec, int $actor_id): array;         // ['ok','error','key' (once),'record']; refuses acts_as_owner (use request_owner_key)
    public function request_owner_key(array $spec, int $actor_id): array; // acts_as_owner: 'pending' row, no secret generated; ['ok','error','record'] (overview 5.2)
    public function confirm_owner_key(int $id, int $owner_id): array;     // owner only, caller has verified the owner's password; generates the secret; ['ok','error','key' (once),'record']
    public function decline_owner_key(int $id, int $owner_id, string $reason): array;
    public function list_owner_keys(int $owner_id): array;                // pending and active acts_as_owner keys owned by this player, no key material
    public function expire_pending_requests(int $days = 7): int;          // daily job: pending requests older than $days become revoked ('request_expired')
    public function verify_key(string $presented): ?array;                // record with computed 'state': active|suspended|revoked|expired; null on a wrong secret whatever the state, and for any pending row; re-hashes a hash_version-1 row under the current pepper
    public function find_by_id(int $id): ?array;
    public function find_by_prefix(string $prefix): ?array;
    public function list_keys(array $filters, int $limit, int $after_id): array;
    public function update_key(int $id, array $changes, int $actor_id): array;
    public function set_status(int $id, string $status, string $reason, int $actor_id): array;
    public function rotate_key(int $id, int $grace_days, int $actor_id): array;
    public function touch_last_used(int $id, string $client): void;       // at most once per 60 s per key
}
class ApiUsage extends Ork3 {
    public function record_call(int $api_version, int $key_id, string $client, string $endpoint, int $status, int $ms): void;
    public function calls_today(int $key_id): int;
    public function usage_summary(array $filters): array;
    public function usage_by_endpoint(array $filters, int $limit): array;
    public function usage_by_key(array $filters, int $limit): array;
    public function usage_by_client(array $filters, int $limit): array;
}
class ApiAudit extends Ork3 {
    public function write_event(string $event, array $fields): void;      // never throws
    public function list_events(array $filters, int $limit, int $before_id): array;
    public function purge_expired(int $days = 400, int $ip_truncate_days = 90): int; // retention, overview 6.6
}
class ApiIdempotency extends Ork3 {
    public function begin_request(int $key_id, int $actor_id, string $operation, string $idem_key, string $request_hash): array; // ['state' => new|replay|in_progress|mismatch, 'id', 'status', 'body']
    public function complete_request(int $id, int $status, string $body): void;
    public function purge_expired(int $hours = 24): int;
}
class ApiFacts extends Ork3 {
    public function account_state(int $player_id): ?array;       // active, suspended, suspended_until, penalty_box, restricted_now (bool: penalty_box, or suspended and suspended_until empty or not past), park_id, kingdom_id
    public function session_meta(string $token): ?array;         // created (for the absolute age check), user_agent; bound by SessionTokenDigest::digest_token($token), no slide
    public function player_scope(int $player_id): ?array;        // park_id, kingdom_id, restricted, show_given, show_surname, show_email
    public function park_scope(int $park_id): ?array;            // kingdom_id, active
    public function kingdom_scope(int $kingdom_id): ?array;      // parent_kingdom_id, active
    public function unit_scope(int $unit_id): ?array;
    public function event_scope(int $event_id): ?array;          // kingdom_id, park_id, unit_id, owner_player_id, status
    public function occurrence_scope(int $occurrence_id): ?array;// event_id + event_scope fields
    public function attendance_scope(int $attendance_id): ?array;// player_id, park_id, kingdom_id, event_id, occurrence_id
    public function award_row_scope(int $awards_id): ?array;     // player_id
    public function note_scope(int $note_id): ?array;            // player_id
    public function dues_scope(int $dues_id): ?array;            // player_id
    public function court_scope(int $court_id): ?array;          // kingdom_id, park_id, status
    public function court_child_scope(string $kind, int $id): ?array; // kind: line|note|artisan -> court_id
    public function recommendation_scope(int $rec_id): ?array;   // recipient_id, author_id, kingdom_id, park_id
    public function calendar_item_scope(int $item_id): ?array;   // kingdom_id, park_id, officer_only, locals_only
    public function qual_scope(string $kind, int $id): ?array;   // kind: question|set|attempt -> kingdom_id (+ owner for attempt)
    public function bonus_credit_scope(int $id): ?array;
    /** Parent ids of a nested row, null when unknown. kind: milestone (player_id) | park_day (park_id) | unit_member (unit_id) |
     *  grant (scope type + id) | schedule_item (event_id, occurrence_id) | event_staff (event_id, occurrence_id) |
     *  rec_second (rec_id, author_id) | attendance_link (scope type + id, event_id) | survey_page | survey_question | survey_image (survey_id) |
     *  kingdom_award (kingdom_id) | bonus_category (scope type + id) | notification (player_id) */
    public function child_scope(string $kind, int $id): ?array;
}
class ApiActorSession extends Ork3 {
    public function begin_actor_session(array $key_record): string; // ephemeral ork_session row for the owner (overview 5.2); stores the digest, returns the raw token; '' when the owner cannot act
    public function end_actor_session(string $token): void;          // deletes that row by digest; called from the kernel's finally
    public function purge_stale(): int;                              // deletes ApiKey/% rows past expiry (crashed requests)
}
class SessionTokenDigest {                                           // created by F-31; not whitelisted on the bridge; no I/O
    public static function digest_token(string $token): string;      // lower-case hex SHA-256 of the presented token; the only way any code turns a token into its stored form
}
```

Every reader or writer of `ork_session.token` (the auth class after F-31, `ApiFacts`, `ApiActorSession`, tests and fixtures) goes through `SessionTokenDigest::digest_token`. Code never compares a presented token with the column directly and never returns the column's value to a client.

### 3.6 Policy vocabulary (complete; fan-out tasks may not add to it)

`public`, `key`, `authenticated`, `self`, `self_or_officer`, `player.officer`, `park`, `kingdom`, `event`, `unit`, `org`, `unit.officer`, `event.cap`, `attendance.scope`, `court.manage`, `court.scope`, `calendar_item.manage`, `calendar_item.view`, `survey.manage`, `survey.create`, `survey.results`, `qualtest.manage`, `qualtest.attempt`, `domain`, `link_token`, `admin`. Semantics are in `01-resource-catalog.md` section 0. A route may combine two with `all` or `any`:

```php
x: ['ork-policy' => ['any' => [['name' => 'self', 'player' => 'path.player_id'], ['name' => 'admin']]]]
```

Argument values are literals, references `path.<name>`, `query.<name>`, `body.<name>`, or a fact reference `{'fact': <kind>, 'id': <reference>, 'field': <name>}` that `PolicyEngine` resolves through the matching `ApiFacts` `*_scope` or `child_scope` method (an unknown row is `Decision::notFound()`). Fact references are how "own row" rules and child-to-parent checks are expressed, so a handler never makes an ownership decision.

### 3.7 Error codes

`bad_request`, `credentials_in_query`, `invalid_cursor`, `unsupported_media_type`, `payload_too_large`, `key_required`, `invalid_key`, `key_revoked`, `key_expired`, `key_suspended`, `origin_not_allowed`, `ip_not_allowed`, `invalid_token`, `token_expired`, `actor_required`, `invalid_credentials`, `account_restricted`, `insufficient_scope`, `forbidden`, `not_found`, `method_not_allowed`, `conflict`, `stale_resource`, `precondition_required`, `validation_failed`, `idempotency_key_required`, `idempotency_key_reuse`, `idempotency_in_progress`, `rate_limited`, `quota_exceeded`, `busy`, `timeout`, `internal_error`, `unavailable`, `gone`.

### 3.8 Domain status mapping (`DomainResult::orThrow`)

| Domain status | HTTP | code |
|---|---|---|
| 0 | - | ok |
| 1 unimplemented / unknown | 500 | `internal_error` |
| 2 bad token | 401 | `invalid_token` |
| 3 processing error | 409 | `conflict` (handler may override to 422) |
| 4 invalid parameter | 422 | `validation_failed` (domain `Error` text becomes `detail`) |
| 5 no authorization | 403 | `forbidden` |
| 6 deprecated | 410 | `gone` |

The handler picks `nested`, `flat` or `raw` explicitly for each call. There is no auto-detection: misreading the flat award status caused double grants in the past.

### 3.9 Compiled route entry (`generated/routes.v2.php`)

```php
return [
  'api_version' => '2.0.0',
  'static'  => ['GET /v2/ping' => 3],                               // method + exact path => op index
  'dynamic' => ['GET' => [['#^/v2/players/(\d+)$#', ['player_id'], 12]]],
  'ops' => [12 => [
     'id' => 'getPlayer', 'handler' => ['Ork\\Api\\V2\\Resources\\PlayersResource', 'get'],
     'scope' => 'players:read', 'policy' => ['name' => 'key'], 'cost' => 1,
     'cache' => 60,                      // seconds, or null
     'idempotency' => 'none',            // none | optional | required
     'if_match' => false, 'max_body' => 65536, 'body_types' => ['application/json'],
     'params' => [/* schema */], 'query' => [/* schema */], 'body' => null,
     'response' => ['schema' => 'Player', 'collection' => false],   // or ['stream' => 'text/csv'] for x-ork-stream
     'replaces' => ['Player/GetPlayer'],
     'deprecated' => false, 'sunset' => null,   // from deprecated: true + x-ork-sunset
  ]],
];
```

### 3.10 Middleware order (assembled in F-20)

`RequestId` → `ErrorBoundary` → `SecurityHeaders` → `Cors` → `BodyLimits` → `RouteMatch` → `AuthFailGuard` (per-IP failed-authentication bucket checked before any key or token lookup; every 401 increments it) → `KeyAuth` → `BearerAuth` (including `begin_actor_session` for `acts_as_owner` keys) → `RateLimit` → `ScopeCheck` → `InputValidation` → `Preconditions` (header presence only: `Idempotency-Key` → 400, `If-Match` → 428) → `PolicyCheck` → `Idempotency` (begin / replay / mismatch / in-progress) → handler → `Present` → `CacheHeaders` → (finally) `end_actor_session` when one was begun, `UsageRecorder`, `WriteAudit` (also writes `request.read_sensitive`, overview 6.6).

Idempotency records are opened only after the policy allowed the request, so a refused caller never creates one and cannot observe a replay, and a 403 that later becomes allowed is not frozen into the record.

### 3.11 Tables (migration F-07)

```sql
CREATE TABLE IF NOT EXISTS ork_api_key (
  api_key_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  key_prefix CHAR(12) NOT NULL,
  key_type ENUM('publishable','secret') NOT NULL,
  environment ENUM('live','test') NOT NULL DEFAULT 'live',
  secret_hash CHAR(64) NOT NULL DEFAULT '',   -- '' while an acts_as_owner request is pending (no secret exists yet)
  hash_version TINYINT UNSIGNED NOT NULL DEFAULT 1,  -- which pepper produced secret_hash (rotation, overview 5.1)
  name VARCHAR(100) NOT NULL,
  description VARCHAR(500) NOT NULL DEFAULT '',
  owner_mundane_id INT UNSIGNED NOT NULL,
  contact_email VARCHAR(165) NOT NULL DEFAULT '',
  scopes TEXT NOT NULL,                       -- JSON array
  acts_as_owner TINYINT(1) NOT NULL DEFAULT 0,
  allowed_origins TEXT NOT NULL,              -- JSON array, '[]' = any
  allowed_ips TEXT NOT NULL,                  -- JSON array of CIDR, '[]' = any
  rate_per_minute INT UNSIGNED NOT NULL DEFAULT 0,   -- 0 = tier default
  quota_per_day INT UNSIGNED NOT NULL DEFAULT 0,
  status ENUM('pending','active','suspended','revoked') NOT NULL DEFAULT 'active',  -- 'pending' = acts_as_owner request awaiting owner confirmation
  owner_confirmed_at DATETIME NULL,           -- set when the owner confirms an acts_as_owner key (F-32); NULL for every other key
  expires_at DATETIME NULL,
  rotated_from_id INT UNSIGNED NOT NULL DEFAULT 0,
  created_by INT UNSIGNED NOT NULL,
  created_at DATETIME NOT NULL,
  revoked_by INT UNSIGNED NOT NULL DEFAULT 0,
  revoked_at DATETIME NULL,
  status_reason VARCHAR(255) NOT NULL DEFAULT '',
  last_used_at DATETIME NULL,
  last_client VARCHAR(40) NOT NULL DEFAULT '',
  PRIMARY KEY (api_key_id), UNIQUE KEY uq_prefix (key_prefix),
  KEY ix_owner (owner_mundane_id), KEY ix_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS ork_api_usage (
  day DATE NOT NULL, api_version TINYINT UNSIGNED NOT NULL, api_key_id INT UNSIGNED NOT NULL DEFAULT 0,
  client VARCHAR(40) NOT NULL DEFAULT '', endpoint VARCHAR(96) NOT NULL,
  calls INT UNSIGNED NOT NULL DEFAULT 0, errors_4xx INT UNSIGNED NOT NULL DEFAULT 0,
  errors_5xx INT UNSIGNED NOT NULL DEFAULT 0, limited_429 INT UNSIGNED NOT NULL DEFAULT 0,
  ms_total BIGINT UNSIGNED NOT NULL DEFAULT 0, ms_max INT UNSIGNED NOT NULL DEFAULT 0,
  b_lt100 INT UNSIGNED NOT NULL DEFAULT 0, b_lt300 INT UNSIGNED NOT NULL DEFAULT 0,
  b_lt1000 INT UNSIGNED NOT NULL DEFAULT 0, b_lt3000 INT UNSIGNED NOT NULL DEFAULT 0, b_ge3000 INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (day, api_version, api_key_id, client, endpoint),
  KEY ix_key_day (api_key_id, day), KEY ix_day_version (day, api_version)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS ork_api_audit (
  api_audit_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, created_at DATETIME NOT NULL,
  event VARCHAR(40) NOT NULL, api_key_id INT UNSIGNED NOT NULL DEFAULT 0,
  actor_mundane_id INT UNSIGNED NOT NULL DEFAULT 0, operation VARCHAR(96) NOT NULL DEFAULT '',
  target VARCHAR(190) NOT NULL DEFAULT '', status SMALLINT NOT NULL DEFAULT 0,
  request_id CHAR(26) NOT NULL DEFAULT '', ip VARCHAR(45) NOT NULL DEFAULT '', detail TEXT NOT NULL,
  PRIMARY KEY (api_audit_id), KEY ix_created (created_at), KEY ix_key (api_key_id, created_at),
  KEY ix_actor (actor_mundane_id, created_at), KEY ix_event (event, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS ork_api_idempotency (
  api_idempotency_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  api_key_id INT UNSIGNED NOT NULL, actor_mundane_id INT UNSIGNED NOT NULL DEFAULT 0,
  operation VARCHAR(96) NOT NULL, idem_key_hash CHAR(64) NOT NULL, request_hash CHAR(64) NOT NULL,
  state ENUM('in_progress','done') NOT NULL DEFAULT 'in_progress',
  response_status SMALLINT NOT NULL DEFAULT 0, response_body MEDIUMTEXT NOT NULL, created_at DATETIME NOT NULL,
  PRIMARY KEY (api_idempotency_id),
  UNIQUE KEY uq_request (api_key_id, actor_mundane_id, operation, idem_key_hash), KEY ix_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

Audit events: `key.issued`, `key.requested` (acts_as_owner request created), `key.owner_confirmed`, `key.owner_declined`, `key.request_expired`, `key.rotated`, `key.updated`, `key.suspended`, `key.resumed`, `key.revoked` (detail records whether the admin or the owner revoked), `key.secret_in_browser`, `request.write`, `request.read_sensitive`, `auth.denied_burst`, `auth.login_failed`, `auth.login_locked`, `authz.denied_burst`, `origin.denied`, `quota.upstream_exhausted`. Burst and failure events are aggregated per minute per (event, key, IP or username bucket), not written per request.

Responses that carry a credential (`POST /sessions`, `POST /me/sessions/current/rotate`) are never stored in `ork_api_idempotency`, and a stored body is capped at 64 KiB (for a larger response only the status and `Location` are stored, and a replay answers with that status and an empty body). Database copies leaving production clear this table (overview 6.7).

### 3.12 Configuration constants

Added to `config.dist.php`, `config.dev.php`, `config.test.php` with the existing `define('X', getenv('X') ?: '<default>')` pattern, and to the README table. Production `config.php` is outside the repo; F-25's runbook lists them.

| Constant | Purpose | Dev/test default |
|---|---|---|
| `ORK_API_KEY_PEPPER` | HMAC pepper for key hashes. Outside `DEV`/`TEST`, a value that is empty, under 32 bytes or equal to the dev default makes key verification answer 503 and `bin/api-key` refuse to run (fail closed) | fixed non-secret dev string |
| `ORK_API_KEY_PEPPER_PREVIOUS` | Previous pepper during rotation (`hash_version` 1 rows verify against it and are re-hashed) | empty |
| `ORK_API_CURSOR_SECRET` | HMAC for cursors; same fail-closed rule as the pepper (cursors then answer 400) | fixed dev string |
| `ORK_API_SESSION_MAX_AGE_DAYS` | Absolute session age accepted on v2 (U16); 0 = off | 180 |
| `ORK_API_GEOCODE_DAILY_GLOBAL`, `ORK_API_WEATHER_ARCHIVE_DAILY_GLOBAL` | Site-wide daily caps on paid upstreams (overview 6.4) | 500 / 1000 |
| `ORK_API_V2_ENABLED` | Kill switch; `0` answers 503 | `1` |
| `ORK_API_DOCS_KEY` | Publishable docs key shown to the explorer | empty (Try-it for public calls is keyless in dev) |
| `ORK_API_V1_DEPRECATION_DATE` | Phase 5 `Deprecation` header on v1; empty = header off. Set at T0 (U2). There is no Sunset constant in Phases 1 to 5: it belongs to deferred Phase 7 (X-02) | empty |

---

## 4. Dependency graph

```
1A  F-01 -> F-02          F-31 (independent; own PR against master, starts first because F-14 and F-15 use its digest helper)
1B  F-03 F-04 F-05 F-06 F-07 F-08 F-09 F-10            (all need F-02)
1C  F-11 F-12 F-13 (need F-07)   F-14 F-15 (need F-07, F-31)   F-16 (needs F-02)   F-33 (independent)
1D  F-17 (F-11,F-14,F-15)  F-18 (F-14)  F-19 (F-16)  F-21 (F-11)  F-22 (F-11,F-12,F-15)  F-32 (F-11,F-12,F-15,F-33)
1E  F-20 (F-03..F-06,F-08..F-10,F-12,F-13,F-17,F-18)   F-23 (F-22,F-33)   F-25 (F-01)
1F  F-24 (F-20,F-19)  F-26 (F-24,F-25,F-33)  F-27 (F-19)  F-28 (F-20,F-19)  F-29 (F-19, F-28 for the dry run)  ->  F-30 (all)
```

## 5. Tasks

### Wave 1A (F-01 then F-02; F-31 in parallel on its own branch)

**F-01 Scaffold and toolchain** · Sonnet · ~250 lines
- Goal: directory skeleton, autoloader, front controller stub, dev dependencies, test wiring.
- Create: `orkservice/Api/index.php`, `orkservice/Api/autoload.php` (PSR-4 `Ork\Api\` → `orkservice/Api/src/` only; no I/O, no `startup.php`; used by the spec build and the DB-free unit suite), `orkservice/Api/bootstrap.php` (requires `autoload.php`, `startup.php` and `orkservice/Common.definitions.php`; sets its own error and exception handlers; never starts a session), `phpunit.api-unit.xml.dist` + `tests/Unit/Api/bootstrap.php` (loads `autoload.php` and the test config constants only; kernel unit tests must pass under both this config and `phpunit.xml.dist`), `orkservice/Api/src/.gitkeep`, `orkservice/Api/generated/.gitkeep`, `orkservice/Api/spec/.gitkeep`, `tools/api-spec/README.md`, `tests/Unit/Api/.gitkeep`, `tests/Integration/Api/.gitkeep`.
- Modify: `composer.json` (`require-dev` `zircote/swagger-php: ^5.8`), `package.json` (`devDependencies`: `@redocly/cli` and `openapi-typescript` (for H-10; approved dev/CI-only tooling, decision E4), each an exact version at least 14 days old on the day of the task; `dependencies`: `rapidoc: 12.3.0` exact, decision U13), `tests/bootstrap.php` (require `orkservice/Api/bootstrap.php`), `config.dist.php`, `config.dev.php`, `config.test.php` (3.12), README table.
- `index.php` behaviour: for `OPTIONS` answer the CORS preflight and exit before loading `startup.php`; otherwise build `Request::fromGlobals()` (path from `REQUEST_URI` when it starts with `/api/`, else from `_path` when `ENVIRONMENT` is DEV or TEST, else 404), run the Kernel, emit.
- Accept: `composer install` succeeds on the host; `php -l` of both files passes in the 8.1 container; requesting the dev URL returns a JSON 404 problem (kernel not wired yet is acceptable as a hard-coded response).
- Verify: syntax command; `curl -si '…/orkservice/Api/index.php?_path=/v2/ping'`.

**F-02 Contract classes** · Sonnet · ~350 lines
- Goal: create every class and interface in section 3.1 to 3.4 with the exact signatures, bodies throwing `\LogicException('not implemented')` where a later task owns them, plus `ErrorCodes` (3.7) and `Scopes`.
- Create: `orkservice/Api/src/Kernel/{Request,Response,Problem,ErrorCodes,Middleware,Kernel,Context,Subject,Tier,Result,Presenter,DomainResult,Cursor}.php`, `src/Auth/{Principal,Scopes}.php`, `src/Policy/{Decision,Policy,PolicyEngine,PolicyRegistry}.php`.
- Accept: `tests/Unit/Api/ContractTest.php` reflects over the classes and asserts each public signature in section 3 exists; all files pass the 8.1 syntax check.
- Verify: PHPUnit on `tests/Unit/Api/ContractTest.php`.

**F-31 Session tokens hashed at rest, and the suspension check in `IsAuthorized`** · **Opus** · ~400 · independent; one focused PR against `master` (decision U8, overview D23)
- Goal: `ork_session` stores a SHA-256 digest of each session token instead of the token; the vestigial `ork_mundane.token` mirror stops holding a usable token; `IsAuthorized` refuses an effectively suspended account. Clients notice nothing: the token they receive and send is the same opaque 32-hex string.
- Files: `system/lib/ork3/class.Authorization.php` (the one sanctioned edit of this file in the plan), `system/lib/ork3/class.SessionTokenDigest.php` (new, section 3.5; static methods only, no constructor work, not whitelisted), `db-migrations/<date>-session-token-digest.sql` and its entry in `migration-classification.json5`, `tests/Integration/SessionTokenDigestTest.php`, `tests/Integration/AuthorizationSuspendedTest.php`, and any existing fixture that seeds `ork_session` directly (switched to the digest).
- Must, storage: every write of a token to `ork_session` stores `SessionTokenDigest::digest_token($token)` (`CreateSession`, `RotateSession`); every lookup binds the digest (`ValidateSessionByToken`, `RotateSession`, `WhoAmI`, `DestroySession`, `DestroySessionsForUser`, the `current` comparison in `ListSessionsForToken`, LRU eviction); the per-request token memo is keyed by digest, so eviction, which only sees stored values, still invalidates it; no code path reads the column and returns it to a client (where a response used the stored value, it uses the token generated in that call). The existing format check stays first: a presented token must be exactly 32 hex characters before any lookup, so a stored 64-character digest can never be presented as a token.
- Must, transition: deploy order is code first, migration second (overview 11.1). Until the migration has run, a lookup accepts the digest or, for a stored value that is exactly 32 characters, the presented token itself (dual read), and a row found by the raw form is rewritten to its digest on that hit. The PR notes a one-line follow-up to remove the dual read 30 days after the migration (the sliding session lifetime); this task does not make it.
- Migration: read the real column definitions first (`SHOW CREATE TABLE`); widen `ork_session.token` and `ork_mundane.token` to hold 64 characters if needed; then `UPDATE … SET token = SHA2(token, 256) WHERE CHAR_LENGTH(token) = 32` on both tables. Idempotent: digests are 64 characters and are never re-hashed. Applied to both local databases, then `drift-check --strict`.
- Must, `ork_mundane.token` mirror: `persistVestigialToken` writes the digest (and `token_expires` as today, which the admin last-login report reads); the clear-on-logout statements match the digest. The random placeholder that player creation writes into this column is not a session token; hashing it is harmless.
- Must, suspension: `IsAuthorized_h` returns 0 for `penalty_box = 1` or an effective suspension (`suspended = 1` and `suspended_until` empty, `'0000-00-00'`, or today or later), the same rule as overview 5.2 and `ApiFacts::account_state.restricted_now`; `active = 0` is not a restriction; the memo entry is dropped when refusing.
- Must, nothing else changes: no change to the password comparisons, login messages, sliding expiry, IdP token storage or any public method signature, and no new public method on the auth class.
- v1 consumers: tokens are opaque, so `Authorize`, `WhoAmI`, `DestroySession` and every method taking `Token` behave as before for callers, and existing sessions survive the migration because their rows are hashed in place. The one intended behaviour change is that a suspended player's token stops working on v1, as it already does at the v2 boundary; the PR lists it for the consumer notes (V-09, V-11).
- Commit procedure (the deliberate override of the pre-commit hook, which normally unstages this file):
  1. Work in a dedicated worktree created from `master` (`git worktree add .worktrees/session-token-digest -b security/session-token-digest master`). The maintainer's local login bypass exists only in the main checkout's working tree, so it is absent here. Never copy the file from the main checkout.
  2. Before staging, prove the bypass is absent: `git diff master -- system/lib/ork3/class.Authorization.php` shows no change to either password comparison in the login path, and only the hunks this entry describes.
  3. Stage explicit paths only and read `git diff --cached` in full; `git diff --cached --stat` lists exactly this task's files.
  4. Commit with `git commit --no-verify`; the hook would otherwise unstage the file (its formatter is skipped too, which is wanted: the file must not be reformatted). The commit message states that the hook was bypassed on purpose for decision U8.
  5. Verify with `git show --stat HEAD` and `git show HEAD -- system/lib/ork3/class.Authorization.php`; any unexpected hunk means reset and redo.
  6. Open one focused PR (`Bugfix:` prefix) containing nothing else; an Opus reviewer reads the auth-class diff line by line before merge.
  7. After merge, the maintainer re-applies their local bypass to the main checkout if they still want it; agents never touch that copy.
- Accept: tests prove (a) after login the stored value is the digest and the returned token works; (b) a session row created before the migration works during the transition and is rewritten to its digest on use; (c) after the migration every row is 64 characters and the old tokens still validate; (d) presenting a stored digest as a token is refused; (e) `RotateSession`, `DestroySession`, `DestroySessionsForUser` and `ListSessionsForToken` (including `current`) work with digests; (f) eviction at the cap of six still invalidates the memo; (g) `IsAuthorized` refuses a suspended player with an empty or future `suspended_until`, accepts a past one, and accepts `active = 0`; (h) the migration is idempotent. Login-related tests run in this clean worktree; the existing unit and integration suites pass.

### Wave 1B (parallel, after F-02)

**F-03 HTTP primitives and error boundary** · Sonnet · ~350
- Files: bodies of `Request`, `Response`, `Problem`; new `src/Kernel/Emitter.php`, `src/Kernel/Middleware/{RequestId,ErrorBoundary}.php`; tests `tests/Unit/Api/Kernel/{RequestTest,ResponseTest,ProblemTest,ErrorBoundaryTest}.php`.
- Must: `fromGlobals` lower-cases header names, reads `Authorization` from `HTTP_AUTHORIZATION`, takes `clientIp` from `REMOTE_ADDR` only, rejects query parameters named `token`, `Token`, `key`, `x-ork-key` with `400 credentials_in_query`. `Response::json` encodes with `JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR` and never `JSON_NUMERIC_CHECK`. `ErrorBoundary` converts `Problem` to `application/problem+json`, any other `Throwable` to a 500 with code `internal_error` and no message leakage, logging the original with the request id.
- Accept: tests cover each rule; a thrown `\Error` yields a body with only `type,title,status,code,request_id`.

**F-04 Router** · Sonnet · ~250
- Files: `src/Kernel/Router.php`, `src/Kernel/Middleware/RouteMatch.php`, `tests/Unit/Api/Kernel/RouterTest.php` (uses a fixture route table in the 3.9 shape).
- Must: static lookup first, then the per-method regex list; `HEAD` falls back to `GET`; unknown path → 404 `not_found`; known path with another method → 405 with `Allow`; trailing slash is not equivalent (404); integer path params are cast to int only when they are 1 to 10 digits and within 1..4294967295, otherwise 404 (no float overflow, no id 0).
- Accept: 12+ table-driven cases including regex-meta characters in paths and a path longer than 2,000 bytes (404).

**F-05 Schema validator** · Sonnet · ~400
- Files: `src/Kernel/Validation/SchemaValidator.php`, `src/Kernel/Middleware/InputValidation.php`, `tests/Unit/Api/Kernel/SchemaValidatorTest.php`.
- Supported keywords (the only ones the linter allows in request schemas): `type` (string, integer, number, boolean, array, object, and `[T, 'null']`), `enum`, `const`, `format` (`date`, `date-time`, `local-date-time` (`YYYY-MM-DDTHH:MM[:SS]`, no offset), `time` (`HH:MM`), `email`, `uri` restricted to http/https/mailto, `int32`, `int64`), `pattern` limited to the subset PCRE and ECMA-262 agree on (no lookbehind, no possessive quantifiers, no `\A`/`\z`; the linter checks), `minimum`, `maximum`, `minLength`, `maxLength`, `pattern`, `minItems`, `maxItems`, `uniqueItems`, `items`, `properties`, `required`, `additionalProperties: false`, `default`.
- Must: query and path strings are coerced to the declared type (`"12"` → 12, `"true"` → true, comma lists → arrays when `items` is declared); body values are never coerced; unknown body properties fail; unknown query parameters are ignored (browser libraries add cache-busters such as `_=`), except the credential names that F-03 rejects; every failure becomes one entry in `Problem::errors` whose `field` is the location plus a dotted path (`path.player_id`, `query.limit`, `body.items[2].name`, `header.idempotency-key`); all failures reported, not just the first.
- Accept: 40+ cases; a 64 KiB body validates in under 5 ms.

**F-06 Presenter and visibility** · Sonnet · ~350 · Opus reviews at F-30
- Files: bodies of `Presenter`, `Subject`, `Tier`; `src/Kernel/Visibility/{RuleRegistry,Rules/PlayerRealName,Rules/PlayerEmail}.php`; `tests/Unit/Api/Kernel/PresenterTest.php`.
- Must: output contains exactly the schema's declared properties that the viewer tier may see; undeclared input keys are dropped; a property hidden by tier is omitted (never `null`); a visible declared key missing from the input is emitted as `null` when the schema marks it nullable, and otherwise is a contract bug: throw in DEV/TEST, log and omit in production (lint SC-05 makes every `public` property `required`); `date-time` values are converted from the server time zone (`date_default_timezone_get()`) to UTC with `Z`, while `local-date-time`, `date` and `time` values pass through unchanged (standards section 3 of the agent text); values are cast to the declared type (a string property holding `"00123"` stays a string; an integer property holding `"12"` becomes 12); nested objects and arrays recurse; tier order `public < authenticated < self/officer < admin` with `self` and `officer` independent (a viewer may hold both); named rules receive `ruleFacts` and return bool.
- Accept: tests include a PII canary (input carries `password_salt`, `token`, `UserName`; none appear in output for any tier unless declared).

**F-07 Migration and key fixture** · Sonnet · ~220
- Files: `db-migrations/<commit-date>-api-v2-core.sql` (3.11, idempotent), entry in `tools/ork-db/manifests/migration-classification.json5` (`"class": "S", "render": "full"`), `tests/Support/ApiKeyFixture.php` (`seedApiKey(PDO, array $overrides): array` returning the full key and row; `cleanup()`), registration in `tests/bootstrap.php`.
- Accept: migration applies twice without error on both databases; `php tools/ork-db/cli.php drift-check --strict` shows no new failure (the known local catalog-hash failure on `ork_class` is pre-existing and must not be "fixed").

**F-08 Cursor codec and DomainResult** · Sonnet · ~250
- Files: bodies of `Cursor`, `DomainResult`; tests `tests/Unit/Api/Kernel/{CursorTest,DomainResultTest}.php`.
- Must: cursor = base64url of JSON plus a 16-byte HMAC with `ORK_API_CURSOR_SECRET`; tampering → 400 `invalid_cursor`. The signed payload includes the operation id and a hash of the normalised filter and sort parameters, so a cursor replayed against another endpoint or with changed filters is 400 `invalid_cursor` rather than a silently wrong page (signatures in 3.3). `DomainResult` implements 3.8 for the three shapes, including `Success()` detail extraction and `null`/`false` handling in `raw`. Domain `Error`/`Detail` text becomes a problem `detail` only after sanitising: dropped entirely (generic text instead, original logged with the request id) when it contains a newline, `<`, `DB_PREFIX`, a SQL keyword followed by whitespace (`SELECT`, `FROM`, `WHERE`, `INSERT`, `UPDATE`), `Array (` or a 32-hex token; otherwise truncated to 200 characters. Some legacy methods put SQL text or request dumps in that field.
- Accept: the flat/nested distinction is tested with the real shapes copied from `Player::AddAward` and `Kingdom::GetKingdomDetails` returns.

**F-09 Rate limiter** · Sonnet · ~300
- Files: `src/RateLimit/{Limiter,Store,MemcachedStore,ArrayStore,Limits,Semaphore}.php`, `src/Kernel/Middleware/{RateLimit,AuthFailGuard}.php`, `tests/Unit/Api/RateLimit/LimiterTest.php`.
- Must: fixed one-minute windows keyed `rl:{bucket}:{id}:{minute}` using memcached `increment` with a 120 s TTL (reuse the `Memcached` instance on `Ork3::$Lib->ghettocache->memcache`); buckets and defaults from overview 6.4 held in `Limits`; cost-weighted consumption; daily quota check via `ApiUsage::calls_today` cached 60 s; headers `RateLimit-Limit/Remaining/Reset`; 429 `rate_limited` with `Retry-After`; store failure → allow and log once per minute, except the buckets marked fail-closed in overview 6.4 (login, self-registration, failed authentication), which answer 503 `unavailable`. IP bucket ids: IPv4 as is, IPv6 truncated to its /64. Username bucket ids: the resolved player id when known, else `sha256` of the trimmed, lower-cased, accent-folded (`Normalizer` NFKD, combining marks removed) username. Also: the `auth_fail` bucket used by `AuthFailGuard` (3.10); the per-key and site-wide login-failure counters (overview 5.3); site-wide daily upstream counters (`ORK_API_GEOCODE_DAILY_GLOBAL`, `ORK_API_WEATHER_ARCHIVE_DAILY_GLOBAL`); and a `Semaphore` (memcached `add`-based slots with a 30 s lease) used for the site-wide report and explorer concurrency limits, `503 busy` when no slot is free.
- Accept: deterministic tests on `ArrayStore` with an injected clock; a test proves two keys do not share a bucket and that the per-IP sub-limit inside a publishable key applies; `Bob`, `bob ` and `BÖB` share one username bucket; two addresses in the same IPv6 /64 share a bucket; the login bucket answers 503 when the store throws.

**F-10 CORS, security headers, body limits** · Sonnet · ~250
- Files: `src/Kernel/Middleware/{Cors,SecurityHeaders,BodyLimits}.php`, a `Cors::preflight()` static used by `index.php`, tests.
- Must: implement overview 6.5 exactly; `BodyLimits` enforces `max_body` and `body_types` from the route (413, 415), parses JSON with depth 32 (400 `bad_request` on malformed), and exposes multipart files only on routes that declare `multipart/form-data`.
- Accept: tests for wildcard, matching origin, non-matching origin with a publishable key (403), no `Access-Control-Allow-Origin` on a secret-key response, `Strict-Transport-Security` present, absence of `Access-Control-Allow-Credentials` in every case.

### Wave 1C (parallel)

**F-11 ApiKey domain class** · Sonnet · ~400 · needs F-07
- Files: `system/lib/ork3/class.ApiKey.php`, `tests/Integration/Api/ApiKeyTest.php`.
- Must: key format from overview 5.1; prefix generated until unique; `verify_key` parses, loads by prefix, compares with `hash_equals`, computes state (revoked > suspended > expired > active) and never returns `secret_hash`; `issue_key` validates scopes against `Scopes::ALL`, forbids `Scopes::PUBLISHABLE_FORBIDDEN` on publishable keys, requires the owner to exist and be unrestricted, and for any `admin:*` scope requires the owner to be an ORK admin (`AuthorizationGate::check`); `issue_key` refuses `acts_as_owner`. Acting keys (overview 5.2) go through `request_owner_key`, which requires a secret key, a non-empty `allowed_ips`, an `expires_at` within 365 days and no `Scopes::ACTS_AS_OWNER_FORBIDDEN` scope, writes a `pending` row with an empty `secret_hash` and a `key.requested` audit row, and returns no key material whoever the caller is (the CLI included). `confirm_owner_key` succeeds only for the owner (`$owner_id === owner_mundane_id`), only on a `pending` row younger than 7 days, and only when the owner is not `restricted_now`; it generates the secret, stores its hash, sets `status = 'active'` and `owner_confirmed_at`, writes `key.owner_confirmed`, and returns the key once. Password verification is the caller's job (F-32 calls `ApiDataAccount::verify_password` first). `decline_owner_key` (owner only) revokes a pending row (`key.owner_declined`); `expire_pending_requests` revokes stale ones (`key.request_expired`). `update_key` on an active acting key accepts only narrowing changes (fewer scopes, fewer IP ranges or origins, an earlier expiry) and refuses anything else; `rotate_key` on an acting key creates the successor through `request_owner_key` and leaves the old key active until the successor is confirmed, after which the grace period starts. `verify_key` returns null (caller answers `invalid_key`) on a wrong secret before looking at state, verifies `hash_version` 1 rows against `ORK_API_KEY_PEPPER_PREVIOUS` and re-hashes them, and fails closed under the pepper rule in 3.12; `rotate_key` copies settings, links `rotated_from_id`, sets the old key's `expires_at`; every mutation writes `ApiAudit::write_event` with before and after minus key material.
- Accept: tests for each rule, plus: the stored row never contains the secret; verifying with a wrong secret and a right prefix fails, and fails identically for a revoked key; a revoked key with the right secret reports `revoked`; `issue_key` with `acts_as_owner` is refused; a requested acting key has no usable secret and `verify_key` rejects anything presented for its prefix; only the owner can confirm it, a confirmation after 7 days or by a restricted owner fails, and a declined or lapsed request can never be confirmed; rotating an acting key leaves the old one working until the successor is confirmed; widening an active acting key is refused and narrowing it works; a publishable key cannot hold `admin:read`; a row hashed with the previous pepper verifies once and is stored with the current one; with the dev pepper and `ENVIRONMENT` unset, verification refuses.

**F-12 ApiUsage and ApiAudit** · Sonnet · ~350 · needs F-07
- Files: `system/lib/ork3/class.ApiUsage.php`, `system/lib/ork3/class.ApiAudit.php`, `bin/api-maintenance.php`, `tests/Integration/Api/{ApiUsageTest,ApiAuditTest}.php`.
- Must: `record_call` is one `INSERT … ON DUPLICATE KEY UPDATE` with bucket increments, swallows all errors, sanitises `endpoint` to `[A-Za-z0-9_./:-]` and 96 chars, labels `client` with `ork_session_client_label()`. `write_event` JSON-encodes `detail` after removing any key matching the DangerAudit redaction list plus `authorization`, `xorkkey`, `secrethash`, `idempotencykey`, `currentpassword`, `newpassword`. Burst events (3.11) are aggregated in memcached per minute and flushed as one row with a count. `purge_expired` implements the retention in overview 6.6 and is called from `bin/api-maintenance.php` (new, daily: audit purge, idempotency purge, `ApiActorSession::purge_stale`, `ApiKey::expire_pending_requests`; the last two are skipped with a notice while their classes are absent on the branch).
- Accept: concurrent-safe upsert test (two calls, one row, calls = 2); readers return typed arrays.

**F-13 Idempotency and preconditions** · Sonnet · ~350 · needs F-07
- Files: `system/lib/ork3/class.ApiIdempotency.php`, `src/Kernel/Middleware/{Preconditions,Idempotency}.php` (two middlewares at the positions in 3.10), tests (integration for the class, unit for the middlewares with a fake).
- Must: `required` routes without the header → 400 `idempotency_key_required`; key 8 to 128 visible ASCII chars; the request hash is SHA-256 over method, the matched path, the canonical JSON of the validated body (keys sorted) or the raw bytes for multipart; same key + same request hash → stored response (status, body and the `Location`/`ETag` headers) replayed with `Idempotent-Replayed: true`; same key + different hash → 422 `idempotency_key_reuse`; in-progress → 409 `idempotency_in_progress` with `Retry-After: 1`; stored outcomes are the handler's own: 2xx, and 409/410/422 raised by the handler or `DomainResult::orThrow`; on 5xx, 429 or any exception the record is deleted so the client can retry with the same key; routes with `if_match` and no `If-Match` → 428. Expose `$request->header('if-match')` parsing helper `Preconditions::etagMatches`.
- Accept: replay test proves the handler ran once.

**F-14 ApiFacts** · Sonnet · ~400 · needs F-07 (for test DB state only) and F-31 (digest helper)
- Files: `system/lib/ork3/class.ApiFacts.php`, `tests/Integration/Api/ApiFactsTest.php` (reuse existing fixtures: `PlayerProfileFixture`, `CourtFixture`, `EventPlanningFixture`, `SurveyOrgFixture`).
- Must: every method in 3.5, one bound-parameter query each, per-request memo, `null` for unknown ids, integer and boolean typing of results. Read the real column names from the tables (`SHOW CREATE TABLE`) before writing each query. `account_state.restricted_now` follows overview 5.2 exactly (`penalty_box`, or `suspended` with `suspended_until` empty, `'0000-00-00'` or today or later); `active` is reported but never makes `restricted_now` true. `session_meta` reads `ork_session` by the bound digest (`SessionTokenDigest::digest_token`, F-31) without updating it; during F-31's transition window it also accepts a 32-character stored value equal to the presented token, exactly as F-31's dual read does. `child_scope` covers every kind listed in its doc comment with one `match` arm and one query each; an unknown kind throws `\InvalidArgumentException` (a programming error, not a 404).
- Accept: one test per method for hit and miss; for `child_scope`, one hit and one miss per kind; `restricted_now` cases for a past, a future and an empty `suspended_until`, and for `active = 0`.

**F-15 Actor sessions and bridge isolation tests** · Sonnet · ~300 · needs F-07, F-31
- Files: `system/lib/ork3/class.ApiActorSession.php`, `system/lib/ork3/class.ApiDataAccount.php` (created here with only `verify_password(int $player_id, string $password): bool`, described in F-24; F-24 owns the file afterwards), `tests/Integration/Api/ApiActorSessionTest.php`, `tests/Unit/Api/BridgeIsolationTest.php`.
- Must: `begin_actor_session` returns `''` when the key is not `acts_as_owner` or `ApiFacts::account_state(owner).restricted_now` is true; otherwise it generates `bin2hex(random_bytes(16))`, inserts one `ork_session` row directly with bound parameters (`mundane_id` = owner, `token` = `SessionTokenDigest::digest_token(<generated>)`, `created` = `last_seen` = now, `expires` = now + 300 s, `user_agent` = `ApiKey/<prefix>`, `ip` = `REMOTE_ADDR`), reads it back by that digest (Yapo swallows insert errors), and returns the raw generated token. It never calls `Authorization::CreateSession`: that path evicts the owner's least-recently-used device sessions at the cap of 6 and writes the sign-in tally. `end_actor_session` deletes the row by digest; `purge_stale` deletes rows with `user_agent LIKE 'ApiKey/%'` and `expires < NOW()`. `BridgeIsolationTest` asserts (a) the whitelist array in `orkservice/Json/index.php` equals the 25 known names, (b) for every class in `system/lib/ork3/class.Api*.php` no public method name passes the bridge's name rule in any capitalisation (i.e. every public method contains `_`), (c) no `Api*` class is in the whitelist.
- Accept: tests pass; the isolation test fails when a camelCase public method is added to an `Api*` class (prove with a temporary local edit, not committed); an owner already holding six sessions keeps all six after `begin_actor_session` and `end_actor_session`; the token is not valid after `end_actor_session`; the stored row holds the digest, never the returned token; a restricted owner gets `''`.

**F-16 Spec generator core** · **Opus** · ~600, dispatched as two sequential sub-tasks in one worktree (F-16.1 scanner, compilers and determinism; F-16.2 `OpenApi.php`, envelope synthesis and the access line) · needs F-02
- Files: `tools/api-spec/build.php`, `tools/api-spec/src/{Scanner,RouteCompiler,SchemaCompiler,SpecWriter}.php`, `orkservice/Api/src/V2/OpenApi.php` (the `#[OA\Info]`, servers, tags, security schemes `orkKey` (apiKey header `X-Ork-Key`) and `bearer`, shared parameters and the shared problem responses `Problem400…Problem503`, envelope helpers), `tests/Unit/Api/Spec/CompilerTest.php` with fixture resources under `tests/fixtures/api-spec/`.
- `OpenApi.php` is complete on day one, so no fan-out task ever edits it (it is the one file every task would otherwise touch):
  - `servers`: one entry, `https://ork.amtgard.com/api` (spec paths start with `/v2/`). The explorer overrides it with the page's own origin (F-26), so Try-it on staging or a dev box never calls production.
  - Tags, one per catalog family, each with a description: Meta, Reference, Sessions, Me, Account, Players, Player awards, Player records, Kingdoms, Parks, Units, Events, Calendar, Attendance, Recommendations, Courts, Media, Reports, Recap, Explorers, Search, Weather, Era Phoenice, Live, Surveys, Qualification tests, Bonus credits, IdP, Admin.
  - Shared path parameters for every canonical name in catalog section 0 (`PlayerId` for `player_id`, `OccurrenceId`, `LinkToken`, …), plus `Limit` (default 50, 1 to 200), `Cursor`, `IdempotencyKey`, `IfMatch`, `IfNoneMatch`.
  - `Problem` schema with `code` as an `enum` generated from `ErrorCodes` (so generated clients get the closed list), and the fixed `type` URI `https://ork.amtgard.com/api/v2/problems/<code>`; `title` is fixed per code, `detail` varies per occurrence.
  - Envelope synthesis: a response attribute refers to `<Name>Envelope` or `<Name>ListEnvelope`, and the `SpecWriter` creates those components from the data schema `<Name>`. Single: `{data: <Name>, meta?: object, links: {self}}`. List: `{data: <Name>[], meta: {next_cursor: string|null, count?: integer}, links: {self, next: string|null}}`, with `links` as paths from the server root (`/api/v2/…`). No volatile value (request id, timestamps of the call) is ever in a body, so a weak ETag over the body is stable.
  - Shared schemas `BatchItemResult` (`{id, status: ok|noop|duplicate|error, code?, detail?}`) for every per-item batch outcome (recommendation batches, court finalize, question imports, schedule batches).
- Must: scan `orkservice/Api/src/V2` with swagger-php, force `openapi: 3.1.0`, write `orkservice/Api/spec/openapi.v2.json` with stable key order and a trailing newline; compile `generated/routes.v2.php` (3.9) taking the handler from each operation's source context, and `generated/schemas.v2.php` (per component schema: properties with type, format, nullable, `x-ork-visibility`, nested refs resolved); compile `generated/v1-map.json` from `x-ork-replaces` (method → sorted list of operation ids). Output is deterministic (two runs are byte-identical); the PHP outputs are plain `var_export`-style arrays that php-cs-fixer never touches (F-27 excludes the directory). `info.version` comes from a constant in `OpenApi.php`. The build never loads `startup.php`; it uses `orkservice/Api/autoload.php` and the vendor fallback in `04-standards.md` section 3. Because most viewers do not render `x-` extensions, the `SpecWriter` appends a generated line to every operation description, e.g. "Access: scope `players:sensitive`; policy officer with edit authority over the player's home park; cost 1; cached 60 s without a login", so the published page states the rule the router enforces.
- Accept: the fixture resource compiles to the expected arrays; the runtime never needs swagger-php (grep: no `OpenApi\` use outside attributes); the build runs on host PHP and prints the versions it used.

**F-33 Shared-shell edits: docs link and third-party-script flag** · Sonnet · ~120 · independent (decisions U6 and U18, overview D24)
- Goal: the two decided edits to the live site shell, and nothing else under `template/default/`.
- Files: `orkui/template/default/default.theme`; the one place the shell reads controller data from, only if the flag needs plumbing there; a test that renders the shell with and without the flag and logged in and out.
- Documented exception: this is the only task allowed to change `orkui/template/default/`. The PR description says the change was decided on 2026-11-24 (U6, U18) because `default.theme` is the live shell every page uses, not a legacy entry point, and that the "no entry points in `template/default/`" rule otherwise stands.
- Must, link (U6): one "API documentation" item in the header bar's Resources dropdown, linking to `Route=ApiDocs`, rendered only when a player is logged in (the same logged-in test the shell already uses for its account menu); logged-out visitors see no change.
- Must, flag (U18): a controller-set value `suppress_third_party_scripts` (boolean, default false) in the data the shell already receives. When true, the shell omits the tag-manager head snippet, the gtag block, the CDN analytics beacon and the tag-manager `noscript` iframe; nothing else changes. Pages that do not set it render exactly as today. A comment beside the guarded blocks names the flag and the pages that use it (F-22/F-23 key pages, F-26 explorer, F-32 owner confirmation); F-29 adds one line about it to `orkservice/Api/README.md`.
- Accept: a logged-in page shows the link and a logged-out page does not; a page with the flag makes no request to a third-party host (network panel) and a page without it is unchanged (rendered HTML identical apart from the link for logged-in viewers); the new menu item checked in both themes.

### Wave 1D (parallel)

**F-17 Authenticators** · Sonnet · ~400 · needs F-11, F-14, F-15
- Files: `src/Auth/{KeyAuthenticator,BearerAuthenticator,PrincipalFactory}.php`, `src/Kernel/Middleware/{KeyAuth,BearerAuth,ScopeCheck}.php`, `tests/Integration/Api/AuthTest.php`.
- Must: implement overview 5.2 exactly. Key states map to 401 `invalid_key`, `key_revoked`, `key_expired`, 403 `key_suspended`; origin and IP allow-lists enforced (403). Bearer: 32 hex chars else 401 `invalid_token`; resolve with `Ork3::$Lib->authorization->IsAuthorized($token)`; then `ApiFacts::account_state`, rejecting `restricted_now` with 403 `account_restricted` (an inactive player is not restricted); then, when `ORK_API_SESSION_MAX_AGE_DAYS` > 0, `ApiFacts::session_meta` and 401 `token_expired` for a session created longer ago. Bearer without key → 401 `key_required`. `acts_as_owner` keys get the actor from `ApiActorSession::begin_actor_session` (the kernel ends it in `finally`); an `acts_as_owner` key with a Bearer token as well is 400 `bad_request`. A secret key presented with an `Origin` header → 403 `origin_not_allowed` plus a `key.secret_in_browser` event. `admin:*` scopes are dropped from the effective set unless the actor is an ORK admin on this request. Responses to 401 carry `WWW-Authenticate: Bearer` or `X-Ork-Key` as appropriate. `ScopeCheck` → 403 `insufficient_scope` naming the scope.
- Accept: matrix test over the six Principal rows of overview 5.2 plus each failure state, including: suspended with a future `suspended_until` refused, with a past one accepted; `penalty_box` refused; `active = 0` accepted; a session older than the maximum age refused; a secret key with `Origin` refused. Login-related assertions run in a clean worktree (the main checkout carries a local password bypass).

**F-18 Policy engine and policies** · Sonnet · ~450 · **Opus review before merge** · needs F-14
- Files: bodies of `PolicyEngine`, `PolicyRegistry`; `src/Policy/Policies/*.php` (one class per name in 3.6); `src/Kernel/Middleware/PolicyCheck.php`; `tests/Integration/Api/PolicyTest.php`.
- Must: authority only through `Ork3::$Lib->authorizationgate->check()`; facts only through `ApiFacts` or the named existing domain predicates (`Court::canManage`, `EventPlanning::CanManageEventDetail`, `CalendarItem::CanSee`, `Survey::canManage/canCreate/resultsAccess`, `QualTest::canManage`); unknown resource → `Decision::notFound()`; missing actor where one is needed → `unauthenticated`; `all`/`any` combinators; fact references (3.6) resolved before the policy runs, with an unknown row → `notFound`; the `key` policy, when its arguments name a player, returns `notFound` for a restricted player where the website hides that player from logged-out visitors (overview 6.2); every denial for an authenticated actor increments the `authz.denied_burst` counter; the registry exposes `names()` for the linter.
- Accept: for each policy a cross-tenant test (officer of kingdom A against a resource of kingdom B is denied) and a positive test; a fact-reference test where the path parent and the child's real parent differ (404); a principality test (officer of the parent kingdom allowed on the principality's park, officer of the principality refused on the parent's park unless the domain grants it).

**F-19 Spec linter and check mode** · Sonnet · ~350 · needs F-16
- Files: `tools/api-spec/src/Linter.php`, `--check` in `build.php`, `redocly.yaml` (Redocly CLI's current config name; `extends: [recommended-strict]`, with `operation-4xx-response` and `no-invalid-media-type-examples` as errors and `info-license` off), `tests/Unit/Api/Spec/LinterTest.php`.
- Must: implement every rule in `04-standards.md` section 3; `--check` rebuilds to a temp dir and fails (exit 1, readable diff summary) when lint fails or any generated file differs from the file on disk; exit 2 on tool errors.
- Accept: one failing fixture per lint rule.

**F-21 Key CLI** · Sonnet · ~200 · needs F-11
- Files: `bin/api-key` (PHP CLI: `issue`, `request-acting`, `list`, `revoke`, `rotate`; refuses to run under a web SAPI; prints a key once, except for acting keys), `tests/Integration/Api/ApiKeyCliTest.php`.
- Must: `issue` refuses `--acts-as-owner`; `request-acting` calls `ApiKey::request_owner_key` and prints only the request id and prefix (the owner confirms in-app, F-32); `rotate` of an acting key prints the successor request, never key material.
- Accept: `bin/api-key issue --name "dev" --type secret --owner <id> --scopes public,account` prints a key that `verify_key` accepts; `request-acting` output contains no secret and the row is `pending`.

**F-22 Admin keys backend** · Sonnet · ~400 · needs F-11, F-12, F-15
- Files: `orkui/controller/controller.AdminApi.php` (`keys`, `keysajax`), `orkui/model/model.AdminApi.php` (the only place that touches `ApiKey`, `ApiUsage`, `ApiAudit`), `tests/Integration/Api/AdminApiControllerTest.php`.
- Must: every action requires `has_authority($uid, AUTH_ADMIN, 0, AUTH_ADMIN)`; `keysajax/{issue|request|update|rotate|suspend|resume|revoke|list|audit|ownersearch}` (`request` creates an acting-key request through `ApiKey::request_owner_key` and returns the record with no key material; `issue` with `acts_as_owner` is refused); mutations require `REQUEST_METHOD === 'POST'` and a per-session CSRF token (`bin2hex(random_bytes(32))` stored on the session, sent as `X-CSRF-Token`, compared with `hash_equals`); responses `{status:0,…}` / `{status:1,error}` / `{status:5}`; route arguments past the third segment arrive as one string and are split in the controller; session via `$this->session->user_id`; owner search goes through `Model_Search::scoped_player_search` with global scope and `&q=`. Step-up (overview 5.5): `issue`, `request`, `rotate`, and an `update` that adds scopes, origins or IPs require a `keysajax/stepup` POST with the admin's password within the last 10 minutes (`ApiDataAccount::verify_password`, timestamp on the PHP session, 5 attempts per 15 minutes, then refused); otherwise `{status:5, error:'step_up_required'}`. Every response is `Cache-Control: no-store`; the pages send `frame-ancestors 'none'; connect-src 'self'` and set the shell's third-party-script flag (F-33). Issue, acting-key request, rotate and revoke send the owner an in-app notification through the existing `Notification` domain class (no email); the request notification links to `Route=ApiKeyOwner` (F-32).
- Accept: tests for the gate, the verb rule, the CSRF rule, the step-up rule (missing, expired, wrong password) and one happy path per action; an acting-key request for another owner returns a `pending` record and no key material, and `issue` with `acts_as_owner` is refused.

**F-32 Owner confirmation of acting keys** · Sonnet · ~400 · needs F-11, F-12, F-15 (`verify_password`), F-33 (the shell flag)
- Goal: the page where a player confirms, declines or revokes the `acts_as_owner` keys an admin requested for them (overview 5.2 and 5.5, decisions U7 and U15).
- Files: `orkui/controller/controller.ApiKeyOwner.php` (`index`, `ajax`), `orkui/model/model.ApiKeyOwner.php` (the only place that touches `ApiKey` for this page), `orkui/template/revised-frontend/ApiKeyOwner_index.tpl`, `tests/Integration/Api/ApiKeyOwnerControllerTest.php`.
- Must: any logged-in player (session via `$this->session->user_id`; logged out → the login page with a return route); lists only keys the viewer owns (`ApiKey::list_owner_keys`): pending requests (name, requesting admin, scopes in plain words, IP ranges, expiry, request date and lapse date) and active acting keys (the same plus last used); `ajax/{confirm|decline|revoke}` are POST-only with the CSRF rule of F-22; `confirm` requires the owner's password in the same request (`ApiDataAccount::verify_password`; 5 attempts per 15 minutes per player, then refused), then calls `ApiKey::confirm_owner_key` and returns the key once in a `Cache-Control: no-store` response, shown with the same once-only reveal behaviour as F-23 (copy button, "I have stored this key", then removed from the DOM and every JS variable, never written to browser storage); `decline` takes an optional reason; `revoke` (active key, no password needed) calls `ApiKey::set_status` with the owner as actor and notifies the requesting admin; a restricted owner sees the list but cannot confirm; the page sets the shell's third-party-script flag (F-33) and sends `frame-ancestors 'none'; connect-src 'self'`; `.rp-*` shell, dark mode, `data-tip`, no native dialogs (rule 8).
- Accept: tests for: another player's key id is 404; confirm without a password or with a wrong one leaves the row `pending`; confirm with the right password activates it and returns key material exactly once (a second confirm fails); confirm after the 7-day lapse fails; decline and revoke write their audit rows; a restricted owner cannot confirm; GET on the ajax actions is refused. Browser check through the worktree proxy with dedicated test accounts in both themes, with no third-party request in the network panel.

### Wave 1E

**F-20 Kernel assembly, usage recorder, write audit** · Sonnet · ~400 · Opus reviews at F-30
- Files: body of `Kernel`, `Context`; `src/Kernel/Middleware/{Present,CacheHeaders,UsageRecorder,WriteAudit}.php`; `src/Kernel/KernelFactory.php`; wire `index.php`; `tests/Integration/Api/KernelTest.php` with a fixture route table and fixture resource.
- Must: order exactly as 3.10; `ORK_API_V2_ENABLED` off → 503 `unavailable`; `Present` computes `tierFor(subject)` per item, with `Context::tierFor` memoised per request by (actor, home park id) so a page of 200 players costs one authority check per distinct park; shared caching (`public`) is allowed only on routes whose policy is `public` (overview section 7), `key`-policy routes with `cache` get `private, max-age`; `ApiActorSession::end_actor_session` runs in `finally` whenever a session was begun, even after an exception; `CacheHeaders` applies overview section 7: `public, max-age` only when the route has `cache`, its policy is `public`, **and the Principal has no actor** (an `acts_as_owner` secret key has an actor without sending `Authorization`, so testing the header is not enough), weak ETag = sha1 of body on every 200 JSON GET, `If-None-Match` → 304 on public and private responses alike, `Vary: Accept-Encoding, Origin, X-Ork-Key, Authorization`; routes marked deprecated get `Deprecation`, `Sunset` and `Link rel="successor-version"`; `UsageRecorder` always runs (including for 4xx and 5xx) with `endpoint` = operation id or `unmatched`; `WriteAudit` writes `request.write` for every non-GET with a matched route and `request.read_sensitive` for the reads listed in overview 6.6 (route scope `players:sensitive` or `admin:read`, export and explorer routes, or any 2xx whose presented tier was `officer` or `admin` for a person-level schema); `Ork-Api-Version` header on all responses.
- Accept: end-to-end test through `Kernel::handle` for 200, 304, 401, 403, 404, 405, 422, 429 and a handler exception; the usage row exists for each.

**F-23 Admin keys UI** · Sonnet · ~450 · needs F-22, F-33 (the shell flag)
- Files: `orkui/template/revised-frontend/AdminApi_keys.tpl` (page, modals, script), one card link added to `orkui/template/revised-frontend/Admin_index.tpl`.
- Must: `.rp-*` tool-page shell; DataTables grid; issue/edit modal with scope checkbox groups; once-only key reveal modal with copy button and an explicit "I have stored this key" confirmation before it closes, after which the key is removed from the DOM and every JS variable (never written to browser storage); a password step-up modal when the backend answers `step_up_required`; an "acts as its owner" option for any owner which, when ticked, forces a secret key, requires IP ranges and an expiry within 365 days, hides `admin:write`, explains that the owner must confirm with their password and will be the only one to see the key, and on submit shows "request sent" with no reveal modal; a "pending owner confirmation" status pill; edit of an active acting key offers narrowing only; in-product confirmation dialog for revoke and suspend (no native dialogs); owner picker per rule 8; status pills and all colours through `--ork-*` tokens with dark overrides; headings reset against the global `orkui.css` pill style.
- Accept: dark-mode checklist walked in both themes with computed-style checks; verified through the worktree proxy on `127.0.0.1:19081` with a dedicated admin test account; the network panel shows no request to a third-party host on the page.

**F-25 nginx, staging and edge runbook** · Sonnet · ~150
- Files: `nginx.ork3.config`, `staging/nginx-ork-staging.conf`, `ops/nginx/README.md` (new "API v2" section).
- nginx block (no regex captures, because of the production capture bug noted in the file):
  ```nginx
  location ^~ /api/v2/ {
      add_header X-Content-Type-Options nosniff always;   # also stops inheritance of the server-level ACAO *
      client_max_body_size 6m;
      include fastcgi_params;
      fastcgi_param SCRIPT_FILENAME $document_root/orkservice/Api/index.php;
      fastcgi_param SCRIPT_NAME /orkservice/Api/index.php;
      fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
  }
  location = /api { return 302 /orkui/index.php?Route=ApiDocs; }
  ```
  PHP owns CORS for this location, including OPTIONS.
- Audience (decision U12): the runbook is handed to the upstream `amtgard/ORK3` infrastructure maintainer, who applies it; v2 GA waits on their written confirmation that origin ingress is Cloudflare-only (H-14). Agents change no edge rule.
- Runbook content: skip the browser challenge for `/api/v2/*` (the origin authenticates and rate limits); extend the "Allow CORS preflight" rule to `/api/v2/*`; add an edge rate-limit rule as an outer guard; `/api/v2/openapi.json` needs no edge rule of its own (the origin requires a key and a login for it, U9); leave the existing `X-Ork-Key` skip rules for `/orkservice/*` in place until v1 retirement; add a rule that lets `X-Ork-Key` values starting with `ork_` through to v1 only after V-03 ships (the origin then validates them); restrict origin ingress to Cloudflare ranges (or enable authenticated origin pulls) so forwarding headers cannot be forged, and report back whether it is done: this is a GA precondition in H-14 because nginx trusts `CF-Connecting-IP` from the host-proxy range, so every per-IP limit, login throttling included, depends on it; no "Cache Everything" or other edge cache rule anywhere on `/api/v2/*`, because Cloudflare ignores `Vary` other than `Accept-Encoding` and would serve one key's or one origin's response (including its `Access-Control-Allow-Origin`) to another; the nginx config is baked into the image, so the location goes live at the next blue/green rebuild; list of new config constants, how to generate the pepper and cursor secret (`openssl rand -base64 48`), and the pepper rotation steps (set `ORK_API_KEY_PEPPER_PREVIOUS`, deploy, wait until no `hash_version` 1 rows are used, clear it).
- Incident section of the runbook (no edge access needed): **leaked key** (suspend in the Admin UI, read its usage and `ork_api_audit` rows by key id for the exposure window, rotate, tell the owner); **compromised player or officer account** (`DELETE` all sessions through the admin session tools or `DestroySessionsForUser`, review `request.write` and `request.read_sensitive` rows by actor, revoke keys they own); **database copy leaving production** (decision E1, for whoever produces the dump: the developers' copy of the nightly backup excludes `ork_session` rows and blanks `ork_mundane.token`, the password-verifier columns (`ork_credential`, and any password hash on `ork_mundane`), the IdP access and refresh tokens in `ork_idp_auth`, `ork_api_key.secret_hash` and `ork_api_idempotency` bodies; production disaster-recovery backups stay intact; local login then works through test accounts only); **audit shipping** (send the PHP error log and the `ork_api_audit` stream to storage the application user cannot modify).
- Accept: `nginx -t` passes in a rebuilt local image; `curl -si http://localhost:19080/api/v2/ping` reaches PHP after the rebuild.

### Wave 1F

**F-24 Meta, sessions and me** · Sonnet · ~450 · needs F-20, F-19
- Files: `src/V2/Resources/{MetaResource,SessionsResource,MeResource}.php`, `src/V2/Schemas/{ApiRoot,Session,Me,SessionEntry,Authorization}.php`, `system/lib/ork3/class.ApiDataAccount.php` (created by F-15 with `verify_password`; login throttle bookkeeping is in the limiter; this class holds only what needs SQL, e.g. own authorizations with scope names), `tests/Integration/Api/V2/{MetaTest,SessionsTest,MeTest}.php`.
- Scope: catalog section 1 (`/`, `/ping`, `/openapi.json`) and section 2 rows for sessions, `/me`, `/me/sessions*`, `/me/authorizations`, `/me/authorization-checks`.
- Must: login failure is always 401 `invalid_credentials` with identical body and timing padding to a 300 ms floor, including a correct password on a restricted account; the per-username, per-IP, per-key and site-wide login buckets from overview 5.3 and 6.4 are consumed before the credential check and a refused attempt never reaches it; the domain is always called with `Token` absent (the legacy method rotates a token when one is present); a `client` beginning with `ApiKey/` is 422; the session label is `<client> via <key prefix>`; `ApiDataAccount::verify_password(int $player_id, string $password): bool` checks a password without creating a session (through the committed `Authorization::KeyExists` with the player's salt and upper-cased username, the same inputs the login uses) for W-01 and the F-22 step-up; the token is returned only in the response body, never echoed in errors, and the response is `no-store`; `GET /me/sessions` never includes a token; `/openapi.json` streams the committed file with ETag, requires a key and a Bearer token (policy `authenticated`, any player; decision U9), is never `public`-cached, and sends `X-Robots-Tag: noindex`.
- Accept: tests per route for success, wrong scope, missing actor; login tests run in a clean worktree and cover: the same body and status for unknown user, wrong password and restricted account; lockout after five failures with case and whitespace variants of the username; a correct password during lockout still refused; `verify_password` leaves `ork_session` unchanged.

**F-26 Docs explorer** · Sonnet · ~400 · needs F-24 (the `/openapi.json` and `/ping` routes), F-25 (the nginx location, rebuilt locally) and F-33 (the shell flag); the page itself can be built after F-19, but its acceptance cannot pass before those three merge
- Files: `orkui/controller/controller.ApiDocs.php` (`index`, `spec`, `legacy`, `migration`; the last two render placeholders until Phase 5), `orkui/template/revised-frontend/ApiDocs_index.tpl`, `orkui/template/revised-frontend/script/vendor/rapidoc-12.3.0-min.js` (copied from `node_modules/rapidoc/dist/rapidoc-min.js`; record its SHA-384 in the template comment and load it with `integrity`), `package.json` script `copy-rapidoc`, card link on `Admin_index.tpl` (coordinate with F-23: F-23 owns that file; F-26 hands its one-line link to the orchestrator to apply at merge).
- Access (decision U9): every action of `controller.ApiDocs.php` requires an ORK login (any logged-in player; logged out → the login page with a return route), sends `X-Robots-Tag: noindex` and a `<meta name="robots" content="noindex">`, and sets the shell's third-party-script flag (F-33). `spec` streams the committed `orkservice/Api/spec/openapi.v2.json` to the logged-in viewer (same-origin, so the page needs no key or token to load the spec). The PR states plainly that this is a speed bump against drive-by scanning, not a security control.
- Must: `<rapi-doc spec-url=<Route=ApiDocs/spec> render-style="read" allow-spec-url-load="false" allow-spec-file-load="false" allow-server-selection="false" persist-auth="false" api-key-name="X-Ork-Key" api-key-location="header" allow-try="true">`; `api-key-value` = `ORK_API_DOCS_KEY` when set; theming for RapiDoc 12: map the page's computed `--ork-*` tokens onto RapiDoc's CSS custom properties on the `rapi-doc` element (`--background`, `--foreground`, `--primary`, the `--sidebar-*` group, `--font-sans`, `--font-mono`) and set its `color-scheme` attribute to `light` or `dark` from `html[data-theme="dark"]`, re-applied by a `MutationObserver` on `html[data-theme]`; a banner explains that Try-it calls live data and how to get a key; never print the session token into the page; the controller sends `Content-Security-Policy: frame-ancestors 'none'; connect-src 'self'`, so a pasted key can only be sent to this origin; `server-url` set to the page's own origin + `/api` (so Try-it on staging or a dev box calls that box, not the production URL in `servers`). The attribute names above come from the 9.x line and the attribute API changed in later majors: confirm each one, and the CSS variable names, against the 12.3.0 documentation before use, and stop and report if one has no equivalent.
- OpenAPI 3.1 rendering check (kept as a safeguard although 3.1 support arrived in 11.0): render a fixture spec containing `type: ['string', 'null']`, `const`, `examples` and `format: binary`, and record how each displays. If any is wrong or crashes the viewer, stop and report to the orchestrator with screenshots; the fallback options (a 3.0-downgraded copy emitted by the `SpecWriter` for the viewer only, or a different pinned viewer) are an orchestrator decision, not the implementer's.
- Accept: page renders the spec in light and dark; logged out, the page and `Route=ApiDocs/spec` redirect to login and `GET /v2/openapi.json` without a Bearer token is 401; Try-it on `GET /v2/ping` works; no request leaves the page to a third-party host (network panel), which proves the F-33 flag is honoured.

**F-27 Hook, CI and gates** · Sonnet · ~300 · needs F-19
- Files: `.githooks/pre-commit` (new step 1c), `.githooks/pre-push` (create if absent), `.github/workflows/api.yml`, `tools/api-spec/gates.sh`, `tools/api-spec/sql-gate.php` (gate 5, with fixtures under `tests/fixtures/api-spec/sql-gate/` and a unit test: one passing and one failing file per rule).
- Must: implement `04-standards.md` sections 4 and 5 exactly, including `ORK_API_SPEC_STAGE=0` and the skip-with-notice behaviour when php or vendor is missing.
- Also: add `->exclude('orkservice/Api/generated')` to `.php-cs-fixer.dist.php` (04-standards section 4); `gates.sh` and the hook resolve `vendor/` and `node_modules/.bin/redocly` from the main checkout when run inside `.worktrees/<wt>`.
- Accept: staging a resource file with a missing description blocks the commit; staging a correct one regenerates and stages the four outputs, and an immediate `build.php --check` is clean (proves the formatter did not touch them); the same commit attempted inside a worktree runs the gates rather than skipping them; with `ORK_API_SPEC_STAGE=0` nothing is staged but lint still runs.

**F-28 Reference resource: Players (profile, attendance, notes)** · **Opus** · ~450
- Files: `src/V2/Resources/PlayersResource.php`, `src/V2/Schemas/{Player,PlayerAttendanceEntry,PlayerNote,PlayerNoteInput}.php`, `system/lib/ork3/class.ApiDataPlayers.php` (`attendance_page(int $player_id, int $limit, ?array $after): array`), `tests/Integration/Api/V2/PlayersTest.php`, `tests/Support/ApiTestCase.php` (shared harness: `call(method, path, opts)` through `Kernel::handle`, seeds key + session, asserts response against the compiled schema; plus `assertBoundary(string $operationId, array $pathParams, ?array $body = null)`, which reads the compiled route and runs the generic cases in one call: no key, key without the route's scope, missing actor where the policy needs one, credentials in the query, unknown body property. Fan-out tasks call it once per route instead of hand-writing those cases).
- Scope: `GET /players/{player_id}`, `GET /players/{player_id}/attendance`, and the five notes routes from catalog section 3.
- Must: this is the template every fan-out task copies, so it demonstrates each pattern once: public read with tiered fields and a named rule; keyset pagination; an officer-only sub-resource; a write with domain delegation (`DomainResult::nested(...)->orThrow()`); `x-ork-replaces`; caching on the profile read; a parity audit note in the PR description comparing each public field with `Playernew_index.tpl` as rendered logged out.
- Accept: tests for each tier (anonymous key, authenticated stranger, self, home-park officer, other-kingdom officer, admin); notes are 403 for everyone but officers and 404 for an unknown player; a note id belonging to another player under this player's path is 404 (fact reference); a restricted player follows the website's logged-out rule for the profile and attendance; the profile response never contains a waiver URL; reading notes writes one `request.read_sensitive` row; attendance pages are stable across an insert between pages.

**F-29 Standards and agent instructions** · Sonnet · ~200
- Files: `agent-instructions/api-v2-standard.md` (text from `04-standards.md` section 2), section added to `agent-instructions/github-copilot-agent-instructions.md`, `orkservice/Api/README.md` (how to add an endpoint, in ten steps, pointing at F-28 as the example; plus one line on the shell's `suppress_third_party_scripts` flag from F-33 for any future page that reveals or accepts a key).
- Not in the repo: the orchestrator adds the memory index line and memory file from `04-standards.md` section 6 to the user's auto-memory and offers the local rule file from section 7.
- Accept: a Sonnet agent given only `orkservice/Api/README.md` and the catalog row for `GET /reference/class-levels` produces a passing endpoint (this is the dry run for the fan-out template; record any gap and fix the README). The dry run happens in a throwaway worktree after F-28 merges and is never merged: `ReferenceResource.php` belongs to R-01.

**F-30 Foundation review gate** · **Opus** (serial)
- Review checklist: every signature in section 3 intact; no SQL under `orkservice/Api/`; no `mysql_real_escape_string` in `class.Api*.php`; `BridgeIsolationTest` green; all files pass the 8.1 syntax check; `build.php --check` clean; Redocly lint clean; the middleware order test; a manual read of F-06, F-09, F-11, F-15, F-17, F-18, F-20 for fail-open paths (pepper and cursor secret fail closed, login buckets fail closed, the actor session always ended, no tier above `public` reachable without a policy decision); the `acts_as_owner` rules in overview 5.2 enforced on request, confirmation, update and rotate, with no path that returns acting-key material to anyone but the owner; F-31 merged to `master` and into the phase branch, with every `ork_session` reader and writer going through `SessionTokenDigest`; F-33's flag honoured on every key page and the explorer, and no other change under `template/default/`; kernel overhead measured on `GET /v2/ping` and `GET /v2/players/{id}` (target: under 10 ms added to the startup cost).
- Smoke: issue a key with the CLI, log in, read a player as stranger and as officer, add and delete a note, replay a write with the same idempotency key, exceed the rate limit, request an acting key as an admin and confirm it as its owner (test accounts), load the explorer in both themes logged in and confirm it redirects logged out.
- Output: a findings list; every finding is fixed (by a Sonnet task in its own worktree) and re-reviewed before Phase 2 starts.
