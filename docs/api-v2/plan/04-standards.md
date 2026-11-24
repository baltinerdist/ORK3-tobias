# Self-documenting API standard

The exact texts and specifications that make documentation a precondition of an endpoint existing. Tasks F-19, F-27 and F-29 implement this file; they do not reinterpret it.

## 1. Approach and justification

**Code-first, attributes on the handler, compiled into the router.**

- Library: `zircote/swagger-php`, constraint `^5.8`, in `require-dev`. It reads PHP 8 attributes, emits OpenAPI 3.1, and its 5.x line supports PHP 7.4 through 8.5, so the same tool runs on the host (PHP 8.2+ per `composer.json`, 8.5 on the maintainer's machine) and in CI. (It is not installed in the 8.1 containers: the committed lockfile already needs PHP 8.4.1; see overview D3.) The 6.x and 7.x lines need PHP 8.2 and are revisited in the separate container-upgrade project (overview U4); v2 stays 8.1-compatible until then.
- Production never loads the library. Attributes are inert metadata until reflected, and nothing in the runtime reflects them. Runtime reads `orkservice/Api/generated/routes.v2.php` and `schemas.v2.php`, which are plain arrays.
- PHP 8.1 compatibility of the annotated source: attribute syntax (8.0) and `new` inside attribute arguments (8.1) are all that is used. The hook and CI run `php -l` under 8.1 on every API file.
- Why not a hand-written spec: it drifts, and the project has no one whose job is to keep YAML in step. Why not spec-first with generated stubs: the route, the policy and the validation would still be written twice.
- The strongest property comes from the compile step, not from the library: the router dispatches only what the compiler emitted, so a handler without complete documentation has no route.

Alternatives rejected: PHPDoc annotations (weaker tooling, no nesting checks); a custom attribute set (re-implements schema modelling); runtime reflection of attributes (needs the library in production and costs time per request).

## 2. The standard

The following is the full content of `agent-instructions/api-v2-standard.md`.

```markdown
# ORK API v2 standard

Applies to everything under `orkservice/Api/` and every `system/lib/ork3/class.Api*.php` file.
An endpoint that does not meet this standard does not exist: the router is compiled from the
documentation attributes, and the build refuses incomplete ones.

## 1. Where things go

| What | Where | May contain |
|---|---|---|
| Handler | `orkservice/Api/src/V2/Resources/<Family>Resource.php` | Input mapping, one or more domain calls, output mapping. No SQL, no `$DB`, no business rules, no authorization logic beyond choosing a `Subject` |
| Schema | `orkservice/Api/src/V2/Schemas/<Name>.php` | Attributes only |
| New query or orchestration | `system/lib/ork3/class.ApiData<Family>.php` | SQL with bound parameters; public methods snake_case with an underscore |
| Tests | `tests/Integration/Api/V2/<Family>Test.php` | Extends `ApiTestCase` |

Never add a public method to a class listed in `orkservice/Json/index.php`. Never add a class to that list.
Never read identity or privilege from the request: the actor is `$ctx->actorId()`, the token is `$ctx->token()`.

## 2. Every operation declares

1. `path`, HTTP method attribute, `operationId` (camelCase verbNoun, unique, never renamed after release).
2. `summary` (one line, imperative) and `description` (what it returns or changes, who may call it, side effects, limits).
3. `tags`: exactly one, from the list in `orkservice/Api/src/V2/OpenApi.php`.
4. `security`: explicit. `[[], ['orkKey' => []]]` for public (no credential needed; a key, when sent, raises the rate limit, so generated clients should send it if configured), `[['orkKey' => []]]` for key-only, `[['orkKey' => [], 'bearer' => []]]` when an actor is needed.
5. Every path, query and header parameter with `description`, `schema` and, for query parameters, bounds (`minimum`, `maximum`, `maxLength`, `enum`). Path parameters are `$ref`s to the shared parameters in `OpenApi.php` (names fixed in the catalog, section 0). Array query parameters declare `style: form, explode: false` (comma-separated) and `maxItems`.
6. A request body schema for `POST`, `PUT`, `PATCH`, with `additionalProperties: false`, descriptions and at least one example. `PATCH` bodies have no `required` list: an absent property is left unchanged, `null` clears a nullable property, and any other value replaces it (merge semantics on the top level only; nested objects are replaced whole).
7. Responses: the success response with a schema reference and an example; and each error it can return, by reference to the shared problem responses (401, 403, 404, 409, 412, 422, 428, 429 as applicable). JSON success bodies are always an envelope (`<Name>Envelope` or `<Name>ListEnvelope`, synthesized by the build from the data schema; never hand-written). Non-JSON responses (CSV, ICS, XLSX, plain-text exports, and `/openapi.json` itself) set `x-ork-stream: true` and declare their media type with `schema: {type: string}` (`format: binary` for XLSX).
8. Extensions:
   - `x-ork-scope`: one scope from `Ork\Api\Auth\Scopes::ALL`, or `public`.
   - `x-ork-policy`: a policy from the registry with its arguments, or `any`/`all` of several.
   - `x-ork-cost`: 1, 5 or 25.
   - `x-ork-cache`: seconds, only on `GET` routes whose response is identical for every viewer without a token.
   - `x-ork-idempotent`: `required` or `optional`, on retry-prone writes.
   - `x-ork-if-match`: `true` where the resource carries a version.
   - `x-ork-replaces`: the v1 `Class/Method` names this operation supersedes, if any.
   - `x-ork-stream`: `true` on operations whose success body is not a JSON envelope.
   - `x-ork-sunset`: an RFC 3339 date, only together with `deprecated: true`; the kernel then sends `Deprecation`, `Sunset` and a `Link rel="successor-version"` header on that operation.

## 3. Every response schema property declares

`description`, `type` (and `format` where relevant), `example`, nullability, and `x-ork-visibility`:
`public`, `authenticated`, `self`, `officer`, `admin`, or a named rule. A property is `public` only if the
website shows the same value to a logged-out visitor. When unsure, choose the stricter tier and say so in the PR.

`required` and nullability are separate decisions, and generated clients depend on both:
- A `public` property is listed in `required` (always present; `null` only if declared nullable as `type: [T, 'null']`).
- A property above `public` is never in `required`: it is omitted, not nulled, when the viewer's tier hides it.
- Enums are lower-case snake_case strings. Clients must tolerate unknown enum values and unknown properties (say so in
  the tag description); adding either is an additive change.
- No `oneOf`, `anyOf`, `allOf` or `not` in v2.0 schemas. A mixed list (calendar entries, search hits) is one flat schema
  with a `kind` enum and kind-specific properties declared nullable.
- Times: instants (created, modified, expiry, last used) are `format: date-time`, emitted in UTC with `Z`, converted
  from the server time zone by the Presenter. Wall-clock times people entered for a place (event and occurrence start
  and end, schedule items, park days) are not instants: emit them as `format: local-date-time`
  (`YYYY-MM-DDTHH:MM:SS`, no offset) or `format: time` (`HH:MM`), exactly as stored, and never convert them.
- Resources that take `If-Match` carry their current version in the body as `etag`, so list responses are usable.
- Schema names are PascalCase, unique, and prefixed with the family noun unless the schema is one of the shared ones
  in `src/V2/Schemas/Shared/` (`PlayerSummary`, `ParkSummary`, `Officer`, …): `CourtReport`, not `Report`.

Request schemas may use only the keywords the kernel validator supports (see `orkservice/Api/README.md`).

## 4. Behaviour rules

- `GET` never writes. A read that needs a side effect is two routes.
- Lists that can grow without bound are cursor-paginated through a keyset query.
- Objects the caller may not know exist answer 404.
- Domain results are unwrapped with the explicit `DomainResult::nested`, `::flat` or `::raw`.
- Errors are thrown as `Problem` with a code from `ErrorCodes`. Never echo, never `die`, never return an error inside a 200.
- No server-side fetch of a caller-supplied URL. No credentials in URLs.
- Changing a released operation: additive only (new optional parameter, new property). Anything else is a new
  operation; the old one gets `deprecated: true` and stays at least six months.

## 5. Before you commit

    php tools/api-spec/build.php            # regenerates the spec and the compiled tables
    php tools/api-spec/build.php --check    # must exit 0
    npx --no-install redocly lint orkservice/Api/spec/openapi.v2.json
    sh tools/api-spec/gates.sh
    ENVIRONMENT=TEST php vendor/bin/phpunit -c phpunit.xml.dist --no-coverage tests/Unit/Api tests/Integration/Api/V2/<Family>Test.php

The pre-commit hook runs the build and stages the generated files when API sources are staged. CI runs the
check on every pull request. Do not edit anything under `orkservice/Api/generated/` or `orkservice/Api/spec/` by hand.
The in-app explorer reads the committed spec, so there is no separate documentation step.

## 6. Review checklist

- [ ] Catalog row exists (`docs/api-v2/plan/01-resource-catalog.md`) and matches scope and policy.
- [ ] No identity or privilege field in any request schema.
- [ ] Every property has a visibility tier; person-level data checked against the page.
- [ ] Tests: happy path per tier, missing key, missing scope, missing actor, cross-tenant, unknown id, invalid input.
- [ ] New SQL uses bound parameters and has an `EXPLAIN` in the PR.
- [ ] Free text passed into a legacy (non-`Api*`) method: the PR quotes the line that binds it.
- [ ] Child ids under a parent path are checked through a fact reference in the policy, not in the handler.
- [ ] Generated files regenerated, not hand-edited.
```

## 3. Lint rules (implemented by `tools/api-spec/src/Linter.php`)

Each rule has an id, used in error output and in the linter's tests. All are errors; there are no warnings.

| Id | Rule |
|---|---|
| OP-01 | Operation has `operationId`, unique across the document, matching `^[a-z][A-Za-z0-9]+$` |
| OP-02 | `summary` present, at most 80 characters; `description` present, at least 40 characters |
| OP-03 | Exactly one tag, and the tag is declared in `OpenApi.php` |
| OP-04 | `security` is explicitly present; an entry that is an empty requirement (`[]`, "no credential") is allowed only with `x-ork-policy: public`, where the value is exactly `[[], ['orkKey' => []]]` |
| OP-05 | `x-ork-scope` present and in `Scopes::ALL` or `public` |
| OP-06 | `x-ork-policy` present; every policy name exists in `PolicyRegistry::names()`; every `path.`/`query.`/`body.` reference resolves to a declared parameter or body property |
| OP-07 | Consistency: policy `public` ⇔ scope `public` ⇔ `security` contains the empty requirement. Any policy other than `public`, `key`, `link_token` requires the `bearer` security requirement |
| OP-08 | `x-ork-cost` is 1, 5 or 25 |
| OP-09 | `x-ork-cache` only on `GET` and only with policy `public` or `key` (`key` routes are cached `private` only, overview section 7). Tiered response schemas are allowed: a cacheable variant is only ever emitted for a Principal with no actor, whose tier is always `public` (F-20) |
| OP-10 | Non-GET operations: no `x-ork-cache`; scope is not `public` unless policy is `link_token` |
| OP-11 | Path matches `^/v2/[a-z0-9{}_./-]+$`, parameters are snake_case, no trailing slash, no verbs from a deny list (`get`, `list`, `create`, `update`, `delete`, `set`, `do`) as a path segment |
| OP-12 | Handler method exists, is public, and has the signature `(Request, Context): Result` |
| PA-01 | Every parameter has `description` and `schema`; path parameters are `required` and typed integer or a pattern-bound string |
| PA-02 | Numeric query parameters have `minimum` and `maximum`; string query parameters have `maxLength` or `enum`; `limit` parameters cap at 200 |
| PA-03 | No parameter or body property is named (case- and separator-insensitive) `token`, `key`, `api_key`, `session`, `password_salt`, `requested_by`, `caller_user_id`, `caller_id`, `viewer_id`, `actor_id`, `user_id`, `by_whom_id`, `created_by`, `entered_by`, `suspended_by_id`, `owner_player_id`, `is_admin`, `admin`, `include_drafts`, `include_hidden`, `as_user`, `impersonate`, `mundane_id` (deny list held in the linter). Reviewed exceptions are listed in the linter with a reason, the same way as SC-03 (for example `password` and `current_password` on the credentials and login inputs, `given_by_id` on award inputs, where it is a real attribute and not the actor) |
| PA-04 | Every path parameter is a `$ref` to a shared parameter in `#/components/parameters`, and the same name never maps to two different shared parameters (canonical names: catalog section 0) |
| PA-05 | Array query parameters declare `style: form`, `explode: false` and `maxItems` |
| RB-01 | `POST`/`PUT`/`PATCH` with a body declare a schema with `additionalProperties: false` and at least one example |
| RB-02 | Request schemas use only validator-supported keywords |
| RB-03 | Upload routes declare `multipart/form-data` and a `max_body` no larger than 6 MiB |
| RS-01 | At least one 2xx response; 200 and 201 JSON responses reference a synthesized envelope schema (`<Name>Envelope` / `<Name>ListEnvelope`); operations with `x-ork-stream: true` instead declare a non-JSON media type with a string schema; 201 documents `Location` |
| RS-02 | Declared error responses are references to the shared problem responses; any operation with a non-public policy declares 401 and 403; any with a path parameter declares 404; any with a body declares 422 |
| RS-03 | `x-ork-idempotent: required` operations declare the `Idempotency-Key` header parameter and 409; `x-ork-if-match` operations declare `If-Match`, 412 and 428 |
| SC-01 | Every schema property has `description`, `type` and `example` (or the schema has an object-level example covering it) |
| SC-02 | Every property of a schema used in a response has `x-ork-visibility` with a known tier or rule |
| SC-03 | No response schema declares a property named `username`, `password`, `password_salt`, `password_expires`, `token`, `xtoken`, `secret_hash`, `access_token`, `refresh_token`, `appauthkey`, `code_hash`, `edit_key`, `waiver_url` unless the property is listed in the linter's reviewed exceptions (currently: `token` on the `Session` schema only). Capability tokens returned when an attendance or self-registration link is created are named `link_token`, which is not on the list |
| SC-04 | Schema names are PascalCase and unique; no inline anonymous object schemas in responses |
| SC-05 | In response schemas, every `public` property is in `required` and every property above `public` is not |
| SC-06 | No `oneOf`, `anyOf`, `allOf` or `not` anywhere; nullability only as `type: [T, 'null']`; enum values match `^[a-z0-9_]+$` |
| DOC-01 | Every public method on a class under `src/V2/Resources` either has an operation attribute or is listed as a private helper by being non-public (a public method with no attribute is an error) |
| DOC-02 | `info.version` matches `^2\.\d+\.\d+$`. The version constant in `OpenApi.php` is owned by the orchestrator, never by a task: it stays `2.0.0` until general availability (T0), and after T0 the orchestrator bumps the minor version once per merged change set that adds operations or properties. The bump requirement is enforced by the CI `breaking` job against the base branch, not by the local build (a task branch has no stable "previous spec" to compare with) |
| MAP-01 | Each `x-ork-replaces` entry matches `^[A-Za-z]+/[A-Za-z0-9]+$` and is not repeated within one operation. A v1 method may be listed by several operations; `v1-map.json` maps each method to the sorted list of its operation ids |

`--check` additionally fails when the regenerated `openapi.v2.json`, `routes.v2.php`, `schemas.v2.php` or `v1-map.json` differ from the files on disk. In CI and on the integration branch the files on disk are the committed ones. On a task branch (generated files deliberately not committed) the task runs a plain build first, so `--check` there proves lint passes and the build is deterministic, which is all a task branch can prove.

`build.php` never loads `startup.php` (no database, no `Ork3::$Lib`). It loads Composer's autoloader from `vendor/autoload.php`, and when that is absent (a worktree under `.worktrees/`) from the main checkout, located with `git rev-parse --path-format=absolute --git-common-dir` + `/../vendor/autoload.php`; it prints which one it used. The hook and `gates.sh` resolve `vendor/` and `node_modules/.bin/redocly` the same way, so the gates also run inside worktrees.

`tools/api-spec/gates.sh` (grep and syntax gates):

1. `grep -rnE '\$DB|DB_PREFIX|->DataSet\(|->Execute\(|SELECT |INSERT |UPDATE |DELETE FROM' orkservice/Api/src` returns nothing.
2. `grep -rn 'mysql_real_escape_string' system/lib/ork3/class.Api*.php orkservice/Api` returns nothing.
3. `grep -rnE 'file_get_contents\(\s*\$|curl_init|fopen\(\s*\$|Common::url_exists|exif_imagetype\(\s*\$' orkservice/Api/src system/lib/ork3/class.Api*.php` returns nothing, except lines in `system/lib/ork3/class.ApiDataGeocode.php` and `class.ApiDataWeather.php`, which may call their fixed upstream hosts only (no outbound fetch of a caller-supplied URL anywhere).
4. `php -l` on every file under `orkservice/Api` and every `system/lib/ork3/class.Api*.php`, using the 8.1 container when it is running (`docker exec ork3-php8-app php -l …`), otherwise the host PHP with a notice. CI always uses 8.1.
5. `php tools/api-spec/sql-gate.php system/lib/ork3/class.Api*.php`: a tokenizer check that fails when a string passed to `DataSet`, `Execute`, `query` or `prepare` is built by concatenation or interpolation with anything other than `DB_PREFIX`, an `(int)` cast, `intval(...)`, or a class constant. Identifiers that must vary (sort columns) come from a `match` over an enum and are class constants. Part of F-27.

## 4. Pre-commit hook step

Added to `.githooks/pre-commit` as step 1c, after the JS test step and before the PHP formatter. The generated PHP must **not** be formatted: F-27 adds `->exclude('orkservice/Api/generated')` to `.php-cs-fixer.dist.php` (the hook's `--path-mode=intersection` honours it). Otherwise the fixer rewrites `routes.v2.php` and `schemas.v2.php` after the build and every later `--check` reports drift. The generator itself writes deterministic `var_export`-style arrays.

```
Trigger:  any staged path matching
          ^orkservice/Api/src/ | ^orkservice/Api/generated/ | ^orkservice/Api/spec/ | ^tools/api-spec/ |
          ^system/lib/ork3/class\.Api.*\.php$
Skip with a notice (commit continues) when: php is not on PATH, or vendor/zircote/swagger-php is missing
          both in this checkout and in the main checkout (worktree fallback, section 3) (message: run `composer install`).
Run:      sh tools/api-spec/gates.sh                       -> block on failure
          php tools/api-spec/build.php                      -> block on lint failure (prints rule ids)
          npx --no-install redocly lint <spec>              -> block on failure; skip with a notice if node_modules is missing
Stage:    unless ORK_API_SPEC_STAGE=0, `git add` the four generated files when the build changed them.
          With ORK_API_SPEC_STAGE=0 (used on fan-out task branches) nothing is staged; the build still must pass.
Never:    touch files that are only partially staged; modify any file outside the generated set.
```

`.githooks/pre-push` (created by F-27 if absent) runs `php tools/api-spec/build.php --check` over the pushed tree when the pushed range touches the trigger paths, and blocks on failure. With `ORK_API_SPEC_STAGE=0` it lints only (task branches carry no generated files, so a drift check would always fail there). It is a local early warning; the enforcing gate is CI (section 5, decision U5).

## 5. CI check

`.github/workflows/api.yml`, on `pull_request` and on pushes to `master`, when the trigger paths or the workflow file change.

| Job | Runner setup | Steps | Fails when |
|---|---|---|---|
| `spec` | PHP 8.4 (`shivammathur/setup-php`, extensions `redis`, `memcached`), `composer install --no-interaction --no-progress`, Node 22, `npm ci --ignore-scripts` | `php tools/api-spec/build.php --check`; `npx --no-install redocly lint orkservice/Api/spec/openapi.v2.json`; gates 1 to 3 and 5 | Lint error, drift, gate hit |
| `php81` | PHP 8.1 | `php -l` over `orkservice/Api` and `system/lib/ork3/class.Api*.php` | Any syntax error |
| `unit` | as `spec` | `php vendor/bin/phpunit -c phpunit.api-unit.xml.dist --no-coverage` (bootstrap `tests/Unit/Api/bootstrap.php`, which loads only `orkservice/Api/autoload.php` and the test config constants, never `startup.php`; no database) | Test failure |
| `breaking` | `oasdiff` (approved dev/CI-only tooling, decision E4) pinned by exact version (release at least 14 days old), via its Docker image by digest or its GitHub Action by commit SHA | `oasdiff breaking <base spec> <PR spec> --fail-on ERR`; fails unless the PR carries the label `api-breaking-approved`. Also fails when operations or properties were added and `info.version` did not move (after T0 only; DOC-02) | Unapproved breaking change |

Why these choices: the committed `composer.lock` already contains packages that need PHP 8.4.1 or later (`symfony/string` 8.1), so a PHP 8.3 runner cannot `composer install` it, and `composer.json` requires `ext-redis`. The shared `tests/bootstrap.php` loads `startup.php`, which opens a PDO connection eagerly, so the API unit suite needs its own bootstrap to run without a database. Redocly CLI has no breaking-change diff command; `oasdiff` is the maintained tool for that. `npm ci --ignore-scripts` skips the FullCalendar copy and esbuild steps in `postinstall`, which the spec job does not need.

Workflow hardening: `permissions: contents: read` at the top level; triggers `pull_request` and `push` only (never `pull_request_target`); every third-party action pinned by full commit SHA with the version in a comment; no repository secrets used by any job; `composer install` from the committed `composer.lock` and `npm ci` from `package-lock.json`, never an update; RapiDoc's vendored file checked against the SHA-384 recorded in F-26 by a step in the `spec` job.

The repository has no CI today. Decision U5 (2026-11-24): GitHub Actions is enabled on both `baltinerdist/ORK3-tobias` and `amtgard/ORK3`, and CI is the enforcing drift and validation gate. The workflow file is delivered by F-27; the repository admins of each enable Actions and mark the four jobs as required checks on the default branch (overview 11.1; checked at H-14). Database-backed integration suites stay local for now (they need the sandbox database); adding a MariaDB service container to CI is a follow-up, not part of this plan.

## 6. Memory

**Line to add to the memory index** (`MEMORY.md`, under "Architecture & DB gotchas"):

```
- **API v2 is self-documenting or it does not exist:** handlers in `orkservice/Api/src/V2` carry OpenAPI attributes; the router is compiled from them (`php tools/api-spec/build.php`); never hand-edit `generated/` or `spec/`; new SQL goes in `class.ApiData*.php` with snake_case methods; never add a public method to a JSON-whitelisted class. [api v2](reference_api_v2_standard.md)
```

**Memory file** `reference_api_v2_standard.md`:

```markdown
---
name: reference-api-v2-standard
description: How to add or change an ORK API v2 endpoint — attributes are mandatory, the router is compiled from them, generated files are never hand-edited, and where SQL may live
metadata:
  type: reference
---

API v2 lives in `orkservice/Api/` (transport, no SQL) and `system/lib/ork3/class.Api*.php` (SQL).
The standard is `agent-instructions/api-v2-standard.md`; the worked example is
`orkservice/Api/src/V2/Resources/PlayersResource.php`; the endpoint contract is
`docs/api-v2/plan/01-resource-catalog.md`.

**Rules that bite:**
- No attribute, no route. `php tools/api-spec/build.php` compiles `routes.v2.php`, `schemas.v2.php`,
  `openapi.v2.json`, `v1-map.json`. `--check` is what the hook and CI run. Never hand-edit those four files;
  on a merge conflict in them, rebuild.
- Every operation declares `x-ork-scope` and `x-ork-policy`; every response property declares
  `x-ork-visibility`. The linter rejects a request field that looks like identity or privilege
  (`requested_by`, `viewer_id`, `include_drafts`, ...). The actor is always `$ctx->actorId()`.
- New queries go in `class.ApiData<Family>.php`, bound parameters, public methods snake_case with an
  underscore. Never add a public method to a class in `orkservice/Json/index.php` (it would become a v1 endpoint).
- `DomainResult::flat` for anything built on `add_player_award`; `::nested` for the usual `Status` object.
- Runtime is PHP 8.1: no readonly classes, DNF types, or trait constants.
- Fan-out branches commit with `ORK_API_SPEC_STAGE=0`; the orchestrator regenerates once per wave.
- Auth-sensitive tests (login) run in a clean worktree: the main checkout has the local password bypass.

**Why:** v1 exposed every public method of 25 classes by reflection, with authorization left to each method.
v2 makes the documented contract the only thing that can be routed.
```

## 7. Claude rule

The project keeps no committed `CLAUDE.md`; the memory index is the standing guidance, and the mechanical gates (hook, CI, compiled router) are the enforcement. For agents working in this checkout, the orchestrator also offers this local, uncommitted, path-scoped rule file, `.claude/rules/api-v2.md`:

```markdown
---
paths:
  - "orkservice/Api/**"
  - "system/lib/ork3/class.Api*.php"
  - "tools/api-spec/**"
  - "tests/Integration/Api/**"
  - "tests/Unit/Api/**"
---

When you add or change anything under these paths:

1. Read `agent-instructions/api-v2-standard.md` first. It is binding.
2. Find the catalog row in `docs/api-v2/plan/01-resource-catalog.md`. If there is none, stop and ask; do not invent endpoints, scopes or policies.
3. Write the OpenAPI attributes before the handler body. An operation needs summary, description, tag, security,
   parameters, request and response schemas with examples, `x-ork-scope`, `x-ork-policy`, `x-ork-cost`, and
   `x-ork-visibility` on every response property.
4. Never read identity or privilege from input. Never put SQL under `orkservice/Api/`.
5. Run `php tools/api-spec/build.php && php tools/api-spec/build.php --check`, the Redocly lint,
   `sh tools/api-spec/gates.sh`, and the family's tests. Report their output. Do not claim done without it.
6. Never hand-edit `orkservice/Api/generated/*` or `orkservice/Api/spec/*`.
7. Never stage `system/lib/ork3/class.Authorization.php` (the plan's one exception is task F-31, done only by its documented procedure); never `git add -A`.
```

It is not committed (the pre-PR safety check already excludes Claude configuration from commits). If the user later decides to commit project rules, this file can be committed unchanged.

## 8. Addition to `agent-instructions/github-copilot-agent-instructions.md`

Append under "Architecture":

```markdown
### API v2 (`orkservice/Api/`)
- REST API at `/api/v2`, described by `orkservice/Api/spec/openapi.v2.json`, which is generated. Do not edit it.
- Endpoints are PHP methods with OpenAPI attributes in `orkservice/Api/src/V2/Resources/`. The router is compiled from
  those attributes by `php tools/api-spec/build.php`; an endpoint without complete attributes does not route.
- Follow `agent-instructions/api-v2-standard.md` for every change under `orkservice/Api/` or `system/lib/ork3/class.Api*.php`.
- The JSON bridge (`orkservice/Json/`) and the `…Service.php?Action=` endpoints are v1: deprecated and frozen. Do not add to them.
```

## 9. Attribute example (the shape every handler follows)

```php
#[OA\Get(
    path: '/v2/players/{player_id}/notes',
    operationId: 'listPlayerNotes',
    summary: 'List officer notes on a player',
    description: 'Returns the notes officers have recorded about the player. Only officers with edit authority '
        . 'over the player\'s home park (or its kingdom) and ORK admins may call this. Notes are never public.',
    tags: ['Players'],
    security: [['orkKey' => [], 'bearer' => []]],
    parameters: [new OA\Parameter(ref: '#/components/parameters/PlayerId')],
    responses: [
        new OA\Response(response: 200, description: 'The notes, newest first',
            content: new OA\JsonContent(ref: '#/components/schemas/PlayerNoteListEnvelope')),
        new OA\Response(response: 401, ref: '#/components/responses/Problem401'),
        new OA\Response(response: 403, ref: '#/components/responses/Problem403'),
        new OA\Response(response: 404, ref: '#/components/responses/Problem404'),
        new OA\Response(response: 429, ref: '#/components/responses/Problem429'),
    ],
    x: [
        'ork-scope' => 'players:sensitive',
        'ork-policy' => ['name' => 'player.officer', 'player' => 'path.player_id', 'role' => 'edit'],
        'ork-cost' => 1,
    ]
)]
public function listNotes(Request $request, Context $ctx): Result
{
    $playerId = $request->params['player_id'];
    $rows = DomainResult::raw($ctx->domain(\Player::class)->GetNotes(['MundaneId' => $playerId]))->payload() ?? [];
    return Result::collection(array_map([$this, 'mapNote'], $rows), 'PlayerNote', null,
        static fn (): Subject => Subject::player($playerId));
}
```
