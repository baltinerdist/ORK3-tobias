# Phase 4 — Hardening

Security tests generated from the route table, abuse controls tuned, usage dashboards, contract tests, UI review, and the go-live gate.

- Integration branch: `api-v2/phase-4` off merged Phase 3.
- 14 tasks, 2 waves. Tier per task.
- This is the first phase that runs the full Playwright suite.

## 1. Dependency graph

```
4A  H-01 H-02 H-03 H-04 H-05 H-06 H-07 H-08     (parallel)
4B  H-09 H-10 H-11 H-12  ->  H-13  ->  H-14      (H-13 after the rest; H-14 last)
```

## 2. Tasks

### Wave 4A

**H-01 Authentication matrix suite** · **Opus** · ~350
- Goal: a data-driven test that walks every operation in `generated/routes.v2.php` and asserts the boundary behaviour without a per-route test being written by hand.
- Files: `tests/Integration/Api/Security/AuthMatrixTest.php`, `tests/Support/RouteSampler.php` (builds a syntactically valid request for each route from its compiled parameter and body schemas, using ids from fixtures).
- Cases per route: no key (401 unless `public`); malformed key; unknown prefix; right prefix wrong secret; revoked, suspended, expired key; publishable key from a disallowed origin; key lacking the route's scope (403 `insufficient_scope`); Bearer without key; malformed, unknown and expired token; token of a player with an effective suspension and of a `penalty_box` player (403 `account_restricted`), and of an inactive (`active = 0`) player (accepted); a token past the absolute session age (401 `token_expired`); a secret key sent with an `Origin` header (403); a publishable key presented for an `admin:*` route (403); credentials in the query string (400); ten bad keys from one IP then a good one (429 from `AuthFailGuard`, no key lookup). Key lifecycle cases once, not per route: an acting key requested by an admin is unusable (`401 invalid_key`) until its owner confirms with password re-entry, a wrong password does not activate it, the requesting admin never receives key material, and a declined or lapsed request can never activate; an active acting key whose owner becomes restricted is refused on the next request; an `acts_as_owner` request leaves no `ork_session` row behind and does not reduce the owner's own sessions; a revoked key (by the admin or by the owner) fails on the very next request; a Bearer token works when the stored session row holds its digest (F-31), and presenting a stored digest as a token fails.
- Accept: zero routes skipped (the test fails if the sampler cannot build a request for a route); adding a route with no declared policy cannot pass the build, and this suite proves the declared one is enforced.
- Verify: `ENVIRONMENT=TEST php vendor/bin/phpunit -c phpunit.xml.dist --no-coverage tests/Integration/Api/Security/AuthMatrixTest.php`

**H-02 Authorization and object-reference suite** · **Opus** · ~400
- Files: `tests/Integration/Api/Security/AuthorizationMatrixTest.php`, `tests/Support/TwoKingdomFixture.php` (two kingdoms, a park in each, an officer of each level in each, a plain member in each, one ORK admin, one event, court, survey, qual set, unit and recommendation per kingdom).
- Cases: for every route whose policy is not `public` or `key`: the member of the other kingdom, the park officer of the other kingdom, and the kingdom officer of the other kingdom are refused (403 or 404 as the catalog says); the correct officer succeeds; child ids from the other kingdom under a valid parent path are 404, for every kind in `ApiFacts::child_scope`; for write routes, row counts are unchanged after a refusal; principality cases (parent-kingdom officer allowed downward, principality officer refused upward); a refused authenticated actor increments `authz.denied_burst`.
- Accept: the mapping from policy name to "who must be refused" lives in one table in the test so a new policy without an entry fails the suite; routes with policy `domain` and routes using fact references are listed individually by operation id, so a new one without an entry fails too.

**H-03 Visibility suite** · Sonnet · ~350
- Files: `tests/Integration/Api/Security/VisibilityTest.php`.
- Cases: for each person-level schema (taken from `generated/schemas.v2.php`: any schema with a non-public property), call a route that returns it as anonymous key, stranger, self, home officer, foreign officer and admin; assert the property set equals the set the tier table predicts; assert canary strings planted in the fixture (username, email, given name, surname, note text, dues amount, dietary flags, suspension reason, session token, password salt) never appear in a body unless the tier allows that property; a restricted fixture player is 404 on person-level `key` routes where the website hides them; no body at any tier contains a waiver file URL; an anonymous fixture survey shows no respondent identity at any tier, admin included.
- Accept: the suite enumerates schemas from the compiled file, so a new schema is covered automatically.

**H-04 Injection and validation fuzz suite** · Sonnet · ~300
- Files: `tests/Integration/Api/Security/InjectionTest.php`.
- Cases: for every string and date parameter of every route (path, query, body), send a fixed corpus (quote characters, comment markers, UNION fragments, backslashes, `%` and `_`, null bytes, 10 kB strings, invalid UTF-8, array-for-scalar, scalar-for-array); assert the status is 2xx, 400, 404 or 422 and never 5xx; assert no database error was recorded during the call (hook the query error collector in the test bootstrap); assert the response never contains `SQL`, `syntax` or a table prefix. Also: JSON nested past depth 32, duplicate keys, 65 KiB bodies, integers past 2^63 and path ids past 4294967295, negative and zero ids, Unicode look-alikes and combining characters in usernames and search text, `sort` values outside the enum; multipart uploads that are SVG, a polyglot (valid image header with appended script), a JPEG carrying GPS EXIF (stored copy has none), and a PDF without the `%PDF-` header.
- Accept: runs under five minutes; any 5xx is a failed build. Optional, recorded in the PR: one run of an OpenAPI-driven scanner (OWASP ZAP API scan, exact version at least 14 days old) against the local stack with a test key, findings triaged.

**H-05 Limits and lockout** · Sonnet · ~300
- Files: `tests/Integration/Api/Security/RateLimitTest.php`, `orkservice/Api/src/RateLimit/Limits.php` (tuning only).
- Cases: anonymous per-IP limit; per-key limit; per-IP sub-limit inside a publishable key; daily quota; cost classes (one cost-25 call consumes 25); login lockout and back-off per username and per IP, including that a correct password during lockout is still refused, that case, accent and trailing-space variants of a username share the bucket, and that addresses in one IPv6 /64 share the per-IP bucket; per-key and site-wide login-failure counters raise their alert; self-registration bucket; site-wide upstream caps and the report and explorer semaphores (`503 busy`); headers present; limiter store failure fails open and logs for ordinary buckets and fails closed (503) for login, self-registration and failed authentication.
- Accept: values match overview 6.4; a short table in the PR description records measured behaviour.

**H-06 Usage dashboards** · Sonnet · ~450
- Files: `orkui/template/revised-frontend/AdminApi_usage.tpl`, additions to `controller.AdminApi.php` (`usage`, `usageajax`) and `model.AdminApi.php`, link from `AdminApi_keys.tpl`.
- Must: overall view (calls, 4xx, 5xx, 429, latency buckets rendered as approximate p50/p95, v1 versus v2 split) for 24 hours, 7, 30 and 90 days; per-key view (same, plus top endpoints, last seen, last client label, daily quota use); per-endpoint table; all tables DataTables; charts follow the site's existing chart approach on admin pages and are legible in both themes; dates human-readable; no native dialogs; tooltips `data-tip`.
- Accept: dark-mode checklist walked; mobile width checked with the iframe harness; numbers reconcile with a direct `SELECT` on `ork_api_usage` for one key.

**H-07 Needs-attention panel** · Sonnet · ~250
- Files: section in `AdminApi_usage.tpl`, `ApiUsage::attention_items(): array` (new method, same class file; the only edit to `class.ApiUsage.php` in this phase).
- Rules: keys with a 5xx rate over 2% or a 4xx rate over 30% in 24 hours; keys within 10% of their daily quota; keys expiring within 14 days; keys unused for 90 days; keys with origin or IP denials; `acts_as_owner` keys whose owner lost authority or became restricted; acting-key requests still pending after 3 days (they lapse at 7); rotation grace periods ending within 48 hours; any `key.secret_in_browser` event (rotate that key); login-failure alerts per key and site-wide; actors with `authz.denied_burst` above 20 in an hour (possible id-walking or a compromised account); actors whose `request.read_sensitive` count in 24 hours is more than ten times their 30-day daily median; a paid upstream at 80% of its site-wide daily cap.
- Accept: each rule has a fixture-backed test.

**H-08 Performance pass** · **Opus** · ~300
- Do: measure kernel overhead (target under 10 ms beyond `startup.php`), route-table and schema-table load cost under opcache, the ten most-called operations at fixture scale and against the local mirror with `EXPLAIN` for every `ApiData*` query that orders or filters on an unindexed column; propose indexes as migrations only where a query scans more than 10,000 rows; confirm the route regex list stays under 2 ms for the last route.
- Output: findings and patches; any index migration is classified and noted for "deploy before code".

### Wave 4B

**H-09 Caching conformance** · Sonnet · ~250
- Files: `tests/Integration/Api/Security/CachingTest.php`.
- Cases: every route with `cache` set and policy `public` sends `public, max-age`, `ETag`, `Vary`; every route with `cache` and policy `key` sends `private, max-age` and never `public`; the same route with a Bearer token sends `private, no-store`; no route without `cache` is ever `public`; a tiered response is never served from a shared server-side cache entry (call as officer, then as anonymous, compare).

**H-10 Contract conformance** · Sonnet · ~300
- Files: `tests/Integration/Api/ContractConformanceTest.php`, `tests/Support/OpenApiResponseValidator.php` (validates a response body against the OpenAPI component schema, reusing the kernel validator in strict mode).
- Cases: every operation's success response and one error response validate against the published document; every documented example validates against its schema; every `x-ork-replaces` entry names a method that exists in the frozen v1 list (after V-06) or the current callable set.
- Codegen smoke (dev-only, no new runtime dependency; approved tooling, decision E4): `openapi-typescript` at the exact version pinned in `package.json` devDependencies by F-01 generates types from `openapi.v2.json` with no warnings, and `tsc --noEmit` compiles a ten-line client that calls `getPlayer`, `listPlayerAttendance` (following `links.next`) and `createPlayerNote`, and narrows on `Problem.code`. This catches what lint cannot: anonymous schemas, duplicated names, unusable envelopes. Record the command in `tools/api-spec/README.md`.

**H-11 End-to-end browser tests** · Sonnet · ~350
- Files: `tests/e2e/api-admin-keys.spec.ts`, `tests/e2e/api-docs.spec.ts`.
- Files also: `tests/e2e/api-owner-keys.spec.ts`.
- Flows: admin issues a key, sees it once, edits scopes, rotates, suspends, revokes; a non-admin is redirected; admin requests an acting key for a test player and sees no key material, the player gets the notification, confirms on `Route=ApiKeyOwner` with their password, sees the key once, then revokes it; a wrong password leaves the request pending; explorer loads in light and dark for a logged-in player, lists the tags, Try-it on a public route succeeds, and the page and its spec redirect to login when logged out; the Resources dropdown shows the docs link logged in and not logged out; no third-party request on the key pages, the owner page and the explorer; legacy and migration pages render.
- Rules: run serially, dedicated test accounts only, through the worktree proxy on `127.0.0.1:19081` when run from a worktree.

**H-12 UI review** · Sonnet (three reviewers) · no code size target
- Run the `layers-review` and `mobile-review` skills and the dark-mode checklist over `AdminApi_keys.tpl`, `AdminApi_usage.tpl`, `ApiKeyOwner_index.tpl`, `ApiDocs_*.tpl` and the F-33 change to `default.theme`; fix every finding.

**H-13 Adversarial review** · **Opus** · after 4A and H-09 to H-12
- Run the `adversarial-review` skill against the merged API tier with the brief: bypass the boundary, read a field above your tier, act as another player, exhaust a cost endpoint, make a read write, find a route the matrix suites did not exercise. Fix all confirmed findings; add a regression test for each.

**H-14 Go-live gate** · **Opus** · serial, last
- Walk the final acceptance checklist below. Anything unchecked blocks general availability.

## 3. Final acceptance checklist

**Surface**
- [ ] Every catalog row exists in `routes.v2.php` with the catalogued scope and policy; no extra routes.
- [ ] `parity-report.md`: every v1 method with traffic has a successor or a "not ported" reason.

**Boundary**
- [ ] H-01, H-02, H-03, H-04, H-05, H-09, H-10 green.
- [ ] Every finding in `review-security.md` marked applied is present in the merged code, or re-opened with a reason.
- [ ] No handler reads identity or privilege from input (grep for the legacy field names in `orkservice/Api/src/V2`).
- [ ] No SQL under `orkservice/Api/`; no escape shim in `class.Api*.php`; every `Api*` public method has an underscore; whitelist unchanged (`BridgeIsolationTest`).
- [ ] All API files pass the PHP 8.1 syntax check.

**Keys and monitoring**
- [ ] Keys are hashed with the pepper; the full key appears nowhere in the database, logs or audit rows (search the test database after the e2e run).
- [ ] Rotation, suspension, revocation and expiry take effect within 60 seconds.
- [ ] Production pepper and cursor secret are set, at least 32 random bytes, and differ from every dev and staging value; the fail-closed check has been seen to refuse with a deliberately bad value on staging.
- [ ] Every active `acts_as_owner` key has `owner_confirmed_at` set, a non-empty IP list, an expiry within 365 days and no `admin:write`; no pending request is older than 7 days; no audit row, log line or admin-facing response contains acting-key material.
- [ ] Usage rows exist for 2xx, 4xx, 5xx and 429 responses; dashboards reconcile.

**Documentation**
- [ ] `build.php --check` clean; Redocly lint clean; CI workflow green on the integration branch, with GitHub Actions enabled and the `api.yml` jobs required on both `baltinerdist/ORK3-tobias` and `amtgard/ORK3` (U5).
- [ ] Explorer shows every tag; examples present; legacy and migration pages render (placeholders until Phase 5 are acceptable only if Phase 5 is scheduled before announcement).
- [ ] Explorer, `Route=ApiDocs/spec` and `GET /v2/openapi.json` refuse logged-out and token-less callers; both send `noindex` (U9). RapiDoc is the vendored 12.3.0 file and its SRI hash matches (U13).
- [ ] The shared-shell edits (F-33) are the only change under `template/default/`; the Resources link shows for logged-in players only; key pages, the owner confirmation page and the explorer load no third-party script.
- [ ] `agent-instructions/api-v2-standard.md` present; memory index line added.

**Operations**
- [ ] Migrations classified; drift check clean; "migration before code" noted for deploy.
- [ ] nginx location tested in a rebuilt image; edge runbook handed to the upstream `amtgard/ORK3` infrastructure maintainer (U12).
- [ ] **Origin ingress restricted to Cloudflare (or authenticated origin pulls on), confirmed in writing by the upstream `amtgard/ORK3` infrastructure maintainer.** Without it per-IP limits and login throttling can be bypassed; GA does not proceed.
- [ ] Incident runbook (F-25) delivered, including the development-dump scrub (decision E1) for whoever produces the dump.
- [ ] F-31 deployed to production in order (code, then migration); every `ork_session` row holds a 64-character digest; v1 login, `WhoAmI` and v2 Bearer authentication verified afterwards with a test account.
- [ ] Production constants documented: pepper, cursor secret, docs key, kill switch.
- [ ] Kill switch verified: `ORK_API_V2_ENABLED=0` returns 503 and v1 is unaffected.

**v1 unaffected**
- [ ] The existing unit and integration suites pass unchanged.
- [ ] Manual check of the five most-called v1 methods and the four JSONService endpoints against the mirror: byte-identical bodies before and after the branch (the Phase 5 characterization suite automates this later).

**Decisions recorded**
- [ ] Overview section 12 records U1 to U18 and E1 to E4 (2026-11-24), and N1 and N2 have been confirmed or changed by the maintainer.
- [ ] The v1 risk acceptance (U1) is on record in the overview header; it replaces the earlier publication gate and U1 block, so Phase 6 is not a GA condition.
- [ ] v1 deprecation configured for T0 (`ORK_API_V1_DEPRECATION_DATE`) with no `Sunset` header anywhere on v1 (U2).
