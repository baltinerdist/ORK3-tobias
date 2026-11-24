# Traceability — inventory finding to v2 resolution

Every class of defect recorded in `docs/api-v2/inventory/` mapped to the v2 design element that removes it, the task that builds it, the test that proves it, and what happens to the v1 surface that still has it.

This file is written at the level of defect class and endpoint family. It contains no reproduction steps, parameters or method lists. The specifics, with severity, are in the local-only `inventory/SECURITY-FINDINGS.md`; the `SF-` ids below refer to it.

**Reading the last column.** "Floor S-nn" means the optional Phase 6 task that would close it on v1 if that phase is ever scheduled. "Retirement" means it remains on v1 until v1 is retired; retirement is deferred with no date (Phase 7, U2). Both cases are covered by the written v1 risk acceptance of 2026-11-24 (U1, overview header): no v1 hotfix is scheduled. "Removed V-07" means deleted in Phase 5. "F-31" means closed on v1 too by the scheduled session-token change (U8).

## 1. Authentication and identity

| # | Defect class (inventory) | Local id | v2 control | Built by | Proven by | v1 disposition |
|---|---|---|---|---|---|---|
| T-01 | No central authentication on the bridge; each method checks, or forgets to check, its own token (02, 03) | SF-H9 | Single boundary: `KeyAuth` → `BearerAuth` run before any handler; a route cannot be compiled without a declared policy | F-17, F-19, F-20 | H-01 | Retirement |
| T-02 | Internal authentication helpers are reachable as endpoints (03) | SF-C1, SF-C2 | No reflection dispatch. Sessions are created only by `POST /sessions`; auth-class helpers are never routed. New domain classes cannot become v1 endpoints (underscore rule + pinned whitelist + frozen list) | F-15, F-16, F-24, V-06 | `BridgeIsolationTest`, H-01 | Risk accepted (U1); Floor S-01 if Phase 6 is scheduled, else Retirement |
| T-03 | Token and privilege oracles; client-chosen subject for authority checks (03) | SF-H2 | `/me` and `/me/authorization-checks` act on the Principal only; no endpoint accepts a player id as "who is asking" | F-24 | H-02 | Floor S-01 |
| T-04 | `suspended` accounts keep working tokens (03) | SF-H11 | Account state checked at the boundary on every request, honouring the suspension end date; inactive players are not restricted | F-14, F-17, F-31 | H-01, F-31 tests | F-31 adds the same check to `IsAuthorized` (U8) |
| T-05 | Tokens in query strings; token echoed in an error detail (02, 03) | SF-H11 | Credentials only in headers; query credentials rejected; errors never echo input credentials | F-03, F-24 | H-01 | Retirement |
| T-06 | Session token storage; dual token store (03) | SF-H11, SF-H15, SF-M11 | API keys hashed with a pepper (fail-closed, rotatable). Session tokens stored as SHA-256 digests for v1 and v2 alike, including the vestigial mirror (U8); v2 adds an absolute session age (U16) and ends other sessions on a credential change; development dumps are scrubbed (E1) | F-11, F-17, F-25, F-31, W-01 | F-11, F-17, F-31 tests | F-31 |
| T-07 | No lockout or throttling on login and password reset; account-existence signals in error text (03) | SF-H8, SF-L6 | Per-IP (IPv6 /64), normalised per-username, per-key and site-wide login throttles, fail-closed; one generic failure including restricted accounts; password reset not ported in v2.0 (U17) | F-09, F-24, W-23 | H-05 | Floor S-06 |
| T-08 | Edge key is a shared secret enforced only at the CDN; origin trusts everything; no per-client identity (02, 03) | SF-M6 | In-app keys with identity, scopes, expiry, revocation, verified at the origin | F-11, F-17, F-22, F-23 | H-01 | V-03 validates in-app keys on v1; X-01 can require them |
| T-09 | Legacy third-party application scheme half-removed, with dead and broken paths (03) | SF-L1 | Replaced by admin-issued keys; not ported | F-11 | - | Floor S-01; tables kept (U10) |
| T-10 | Client label is self-declared and is the only usage identity (02) | SF-M6 | Usage attributed to the verified key; label kept as secondary dimension | F-12, F-20 | F-12 tests | V-02 |

## 2. Authorization

| # | Defect class | Local id | v2 control | Built by | Proven by | v1 disposition |
|---|---|---|---|---|---|---|
| T-11 | Domain methods that trust a caller-supplied actor id or have no check; gates living only in UI controllers (04, 05, 06, 07) | SF-H1, SF-M3 | `PolicyEngine` before every handler; handlers pass the Principal's actor; policy vocabulary covers court, survey, qual-test and calendar predicates that used to be controller-only | F-18, all R-/W- tasks | H-02 | Floor S-01 for bridge-reachable ones; UI-only ones are already gated by their controllers |
| T-12 | Unauthenticated writes reachable remotely (04, 05) | SF-H1 | Every mutating route requires a key, an actor, a scope and a policy; build fails otherwise | F-19 lint, W- tasks | H-01, H-02 | Floor S-01 |
| T-13 | Caller-supplied privilege and visibility flags (viewer id, admin flag, include-drafts, requested-by) (04, 05, 06) | SF-H4 | Such fields do not exist in v2 schemas; `additionalProperties: false`; values derived from the Principal | F-05, R-05, R-08, R-15 | H-02, review checklist item | Floor S-02 |
| T-14 | Login-only writes with no authority over the target (06) | SF-H7 | Not ported (treasury accounts, legacy tournament, game); unit awards go through the player award route with recipient-scope authority | W-09, catalog 20 | H-02 | Floor S-01 |
| T-15 | Authority checked against the wrong scope (05) | SF-H7 | Policies name the target resource explicitly (`player.officer(player)`) | F-18, W-03 | H-02 | Retirement |
| T-16 | Granting authority: missing audit on add; role escalation not constrained (03, 08) | SF-M5 | One shared grants handler, role enum, cannot exceed own role, audited on add and remove | W-08 | W-08 tests | Retirement |
| T-17 | Mass-assignment style inputs (officer roles from arbitrary keys, configuration by row id, one god-method update) (08) | SF-M7 | Closed request schemas; officer role enum in the path; configuration by allow-listed key name; split player update routes with per-field write tiers | F-05, W-01, W-06 | W-01, W-06 tests | Retirement |
| T-18 | Cross-kingdom qualification side effect; answer-check oracle; attempt detail gated only in the controller (07) | SF-M2 | Server-bound attempts, budgeted checks, home-kingdom rule, `qualtest.attempt` policy | W-21, R-18 | W-21 tests | UI-only today; unchanged |
| T-19 | Destructive admin maintenance on the same anonymous URL as everything else; unvalidated identifiers (06) | SF-H9 | Not ported: admin maintenance and server-health operations stay in the Admin UI only, so no key can reach them (decision E2) | catalog 20 | H-01 (no extra routes) | Retirement |

## 3. Data exposure

| # | Defect class | Local id | v2 control | Built by | Proven by | v1 disposition |
|---|---|---|---|---|---|---|
| T-20 | Anonymous reads of officer notes, dues, dietary data (04, 08) | SF-C4, SF-H3 | Officer or self policies; `players:sensitive` scope; tiered schemas | F-28, R-09 | H-02, H-03 | Floor S-02, S-04 |
| T-21 | Usernames, real names, emails, suspension and ban flags in anonymous responses (02, 04, 05, 06) | SF-H3 | No username property in public schemas; names by the `player.real_name` rule; email officer tier; flags officer tier | F-06, R-02, R-03, R-08, R-11 | H-03 | Floor S-02 |
| T-22 | Per-player lookups by id without being that player (RSVPs, sign-in, last class, preferences) (04, 05) | SF-H3 | Moved under `/me/…`; no player id parameter | R-10, R-22, W-12 | H-02 | Floor S-02 |
| T-23 | Raw `SELECT *` style payloads carrying columns nobody intended to publish (04) | SF-H3 | Presenter emits declared properties only | F-06 | H-03 canary | Retirement |
| T-24 | Draft events visible through read, search, calendar, schedule, feed and weather paths (05, 06) | SF-H5 | One visibility rule applied to every event route; new published-only queries for calendar, ICS and weather; hidden → 404 | R-05, R-06, R-07 | R-05 tests, H-02 | Floor S-02 |
| T-25 | Visibility enforced only in controllers (calendar items, hidden recommendations, court line masking) (05, 06) | SF-M3 | Policies call the domain predicate; lists filtered by the domain with the Principal as viewer | F-18, R-06, R-15, R-16 | H-02 | UI already gates; bridge does not expose these classes |
| T-26 | Kingdom configuration rows exposed wholesale (05) | SF-M4 | Public allow-list; full view needs kingdom authority | R-02 | R-02 tests | Floor S-02 |
| T-27 | Operational telemetry and admin reports readable anonymously (02, 04) | SF-H3 | `admin` policy | R-21 | H-01 | Floor S-08 |
| T-28 | Explorer and report columns (dues, waiver) visible to any login; any-kingdom scope (06) | SF-M4 | Column-level tiers; restricted criteria for scope officers only | R-20 | R-20 tests | UI behaviour unchanged (raise with user if desired) |
| T-29 | Error responses carrying buffered output, SQL text or request dumps (02) | SF-H9, SF-M10 | Problem bodies are fixed-shape; details go to the log by request id | F-03 | H-04 | Retirement |
| T-30 | Public static survey images for unpublished surveys (07) | SF-M3 | Documented behaviour; images are served only by unguessable URL. Not changed by v2 | - | - | Accepted; listed for the user |
| T-31 | Live feed granularity allows re-identification at very small parks (05) | SF-M4 | Unchanged by design decision of 2026-08-23; noted | R-07 | - | Accepted; listed for the user |

## 4. Injection and input handling

| # | Defect class | Local id | v2 control | Built by | Proven by | v1 disposition |
|---|---|---|---|---|---|---|
| T-32 | SQL assembled from request strings behind a no-op escape function, some on anonymous paths (01, 04, 05, 06) | SF-C3 | v2 never calls those methods; replacements are new bound-parameter queries; grep gate bans the shim in new code; typed validation before the handler | F-05, F-27 gates, R-01, R-06, R-08, R-11 | H-04 | Floor S-03 |
| T-33 | No type or range validation; JSON bodies ignored; everything is a string (02) | SF-M10 | Compiled-schema validation; JSON bodies; typed output | F-05, F-06 | H-04, H-10 | Retirement |
| T-34 | Server fetches a caller-supplied URL during image upload (06) | SF-H12 | Uploads are multipart bytes only; legacy URL inputs always empty; images re-encoded; outbound-fetch gate covers `class.Api*.php` | W-14, F-27 | W-14 tests, H-04 | Floor S-01 (remove the URL input) |
| T-35 | Reflected input and missing content type on the registration-based service; validation errors do not stop execution (02) | SF-H13, SF-M9 | Not applicable to v2 (single emitter, fixed content types, validation short-circuits) | F-03, F-05 | H-04 | Floor S-07 |
| T-36 | CSV exports not checked for formula injection (07) | SF-L5 | Cell prefix escaping in every CSV stream | R-15, R-17 | export tests | Raise with user for the website exports |

## 5. Protocol, integrity and behaviour

| # | Defect class | Local id | v2 control | Built by | Proven by | v1 disposition |
|---|---|---|---|---|---|---|
| T-37 | Accidental endpoints: every public method of a whitelisted class is callable, including statics and helpers; name-shape rule is case-fooled (02, all domain sections) | SF-H9 | Compiled route table is the only dispatch path | F-04, F-16 | H-01 (no extra routes) | V-06 freezes; Floor S-01 trims |
| T-38 | Class instantiated before the whitelist check; introspection skips the whitelist (02) | SF-H9 | No class or method names in v2 requests | F-04 | - | Floor S-01 |
| T-39 | Reads with side effects (suspension sweep, reminder notifications, mark-as-read, presence write, start marker) (04, 06, 07, 08) | SF-M1 | `GET` never writes; side effects became explicit `POST`/`PUT` routes or scheduled jobs | R-11, R-16, R-17, R-22, W-25 | read-purity tests | Legacy paths unchanged until retirement |
| T-40 | Inconsistent envelopes (five on the bridge, seven in UI AJAX); errors as HTTP 200 (01, 02, 08) | SF-M10 | One success envelope, RFC 9457 errors, real status codes | F-03, F-08 | H-10 | Retirement |
| T-41 | `JSON_NUMERIC_CHECK` corrupts digit strings (02) | SF-M10 | Schema-typed output | F-06 | F-06 tests | Retirement |
| T-42 | No verb discipline; reads as POST, writes reachable by GET (08) | SF-H10 | Router binds method and path; 405 otherwise | F-04 | H-01 | Floor S-05 (website AJAX) |
| T-43 | No CSRF protection on most website AJAX writes; no SameSite (08) | SF-H10 | v2 uses no cookies, so CSRF does not apply; the new admin pages use a synchronizer token | F-22 | F-22 tests | Floor S-05 |
| T-44 | Optimistic concurrency and idempotency exist only in two modules, in bespoke forms (06, 08) | - | `ETag`/`If-Match` on court lines and schedule items; `Idempotency-Key` on all retry-prone writes | F-13, W-11, W-16, W-17 | W- tests | Unchanged |
| T-45 | Non-atomic finalize with orchestration in a controller; blind toggle for tracking status (06, 08) | - | Orchestration in a domain method, per-line idempotent results; explicit status value | W-16, W-17 | W-17 tests | Unchanged |
| T-46 | Pagination missing on unbounded lists (04) | - | Keyset pagination with new queries | F-28, R-09, R-11, R-13 | template tests | Retirement |
| T-47 | No cache headers; shared server caches keyed without viewer role (02, 04) | - | Explicit `Cache-Control`/`ETag`; public caching only without a token; tiered responses never served from shared caches | F-20, R-11 | H-09 | Retirement |
| T-48 | Broken and dead methods (award edit, treasury stubs, legacy tournament, game, principality stubs, commented-out methods still referenced) (05, 06) | SF-L1 | Not ported, or replaced by corrected domain methods where the feature is wanted (award catalogue) | W-26, catalog 20 | - | Floor S-01 denies them; else Retirement |
| T-49 | Dead SOAP layer: entry files fatal, stubs for an unrelated project (01) | SF-L2 | Deleted | V-07 | V-12 | Removed V-07 |
| T-50 | Stale-session handling returns an HTML redirect to JSON callers on some controllers (08) | SF-L4 | v2: 401 problem with a code | F-17 | H-01 | Raise with user (website behaviour) |

## 6. Abuse, cost and operations

| # | Defect class | Local id | v2 control | Built by | Proven by | v1 disposition |
|---|---|---|---|---|---|---|
| T-51 | Third-party cost endpoints callable without limit (geocoding, analytics, face service, weather archive by coordinates) (04, 05) | SF-H6 | Login required, cost class 25, per-actor daily caps, result caching; analytics and face service not exposed | W-23, R-07 | H-05 | Floor S-08 |
| T-52 | Heavy queries with no rate limit, with disabled or absent caching (04, 05, 06) | SF-H6 | Cost classes, per-key and per-IP limits, new cached nearby query, explorer single-flight and timeouts preserved | F-09, R-03, R-20 | H-05, H-08 | Retirement |
| T-53 | No rate limiting on the service at all; the one limiter keys on an address that was the proxy (03) | SF-M6 | Limiter on every request; client address from the web server's trusted-proxy handling only, valid only once origin ingress is restricted to the CDN (GA precondition) | F-09, F-25, H-14 | H-05, H-14 | S-06 for login; otherwise Retirement |
| T-54 | Wildcard CORS on every response; preflight cannot carry `Authorization` or non-POST verbs (02, 03) | SF-M6 | CORS decided in PHP per key; origin allow-lists for publishable keys; no credentials mode | F-10, F-25 | F-10 tests | Unchanged for v1 (required by existing browser clients) |
| T-55 | No usage monitoring beyond an anonymous daily tally of one surface (02, 03) | - | `ork_api_usage` for v1 and v2, by key, client, endpoint, status class, latency bucket; dashboards | F-12, F-20, H-06, V-02, V-10 | H-06 | V-02 |
| T-56 | Audit trails are per-module and lose the actor for non-session callers (03) | SF-M5 | Boundary resolves the actor the same way for every credential; `ork_api_audit` for key lifecycle and every write | F-12, F-20 | F-20 tests | Retirement |
| T-57 | No API documentation beyond one page; no way to know what clients call (02) | - | Generated OpenAPI, explorer, legacy reference, migration guide, mapping generated from code | F-16, F-26, V-08, V-09 | H-10, H-11 | - |
| T-58 | Layering gate absent on this branch; docs and edge config can drift from code (03) | - | Grep gates in the spec check; CI workflow; runbook kept beside the nginx config | F-27, F-25 | CI | - |
| T-59 | Environment-dependent weakening of an admin check; filter that fails open; hard-coded table prefixes (05, 06, 07) | SF-L3 | New code uses `DB_PREFIX`; no environment-conditional authorization in v2 | review checklist | H-13 | Raise with user |
| T-60 | Runtime and toolchain PHP versions differ (03) | - | 8.1 syntax gate in the hook and CI; generator is dev-only | F-27 | CI | Separate project: container PHP 8.3/8.4 upgrade (U4) |
| T-61 | Personal documents stored as plain static files (security review) | SF-H14 | v2 never emits a document URL; uploads re-encoded; documents served only through an authority check | W-02, W-14 | H-03 | Floor S-10 |
| T-62 | Sessions never expire while used; credential changes and resets leave other sessions alive (security review) | SF-M11 | Absolute session age on v2 (U16); other sessions ended on a credential change; reset not ported (U17) | F-17, W-01, W-23 | H-01, W-01 tests | Unchanged (F-31 does not change sliding expiry); website behaviour unchanged |
| T-63 | Live credentials present in database copies outside production (security review) | SF-H15 | Key hashes useless without the production pepper; session tokens stored as digests (F-31); the developers' dump excludes session rows and blanks token, password-verifier and IdP-token columns (decision E1, runbook for the dump producer) | F-11, F-25, F-31 | H-14 checklist | F-31 and the dump scrub (apply to v1 equally) |
| T-64 | Third-party script on pages that show or accept credentials (security review) | SF-M12 | Key reveal never stored, `no-store`, `frame-ancestors 'none'; connect-src 'self'`; the shell skips its tag manager and analytics on the key pages, the owner confirmation page and the explorer (U18) | F-22, F-23, F-26, F-32, F-33 | H-11 | Website login page unchanged |

## 6a. Risks introduced by v2 itself

Each new mechanism is a new attack surface. These rows trace the design controls the security review added for them (`review-security.md`).

| # | v2 mechanism | Risk | Control | Built by | Proven by |
|---|---|---|---|---|---|
| N-01 | `acts_as_owner` keys | An admin (or a compromised admin account) mints a key that impersonates any player and survives a password reset; a standing unscoped session that v1 also accepts; the owner's own device sessions evicted | Admin creates only an inactive request; activation needs the owner's password on the owner's own page, and the secret is shown only to the owner (U7×U15); secret, IP-locked, expiring, no `admin:write`; widening refused; ephemeral per-request session row created without the LRU path; owner notified | F-11, F-15, F-17, F-22, F-32 | F-11, F-15, F-32 tests, H-01 |
| N-02 | Publishable keys | Treated as a credential although extractable; admin routes reachable with a stolen admin token and any browser key | `PUBLISHABLE_FORBIDDEN` includes all `admin:*` and `idp:integration`; `key` data treated as public; bulk controls | F-11, F-09 | H-01, H-05 |
| N-03 | Secret keys | Used from a browser and leaked | No CORS header on secret-key responses; `Origin` present → 403 and a needs-attention item | F-10, F-17, H-07 | F-10, H-01 tests |
| N-04 | Key pepper | Missing or default pepper in production; no rotation path | Fail closed outside DEV/TEST; `hash_version` and previous-pepper rotation | F-11, F-25 | F-11 tests, H-14 |
| N-05 | Shared caching | Edge cache serving key-gated responses to keyless or revoked callers | Shared caching only on `public` policy routes; `key` routes `private` | F-20, F-25 | H-09 |
| N-06 | Nested ids and "own row" rules | BOLA through a child id under a parent the caller controls | `ApiFacts::child_scope` and policy fact references; per-kind tests | F-14, F-18 | H-02 |
| N-07 | `domain` policy routes | Authorization delegated to legacy code | Individual entries in H-02's refusal table; PR quotes the domain check | F-18, fan-out | H-02 |
| N-08 | Reuse of legacy domain methods | String-built legacy SQL reached through a new route | Taint rule (typed values only unless binding shown); SQL interpolation gate for new classes | fan-out, F-27 | H-04, gate 5 |
| N-09 | Login endpoint | Credential stuffing with rotated IPs and an extracted key; username-variant bypass; limiter outage | Per-key and site-wide failure budgets, normalised username bucket, IPv6 /64, fail-closed buckets, origin lockdown | F-09, F-24, F-25 | H-05, H-14 |
| N-10 | Audit and idempotency storage | PII and credentials retained indefinitely; tampering | Retention and IP truncation; credential-bearing responses never stored; shipping to append-only storage | F-12, F-13, F-25 | F-12 tests |
| N-11 | Sensitive reads | A compromised officer account harvesting notes and personal data unnoticed | `request.read_sensitive` audit rows and anomaly items | F-20, H-07 | H-07 tests |
| N-12 | Admin key UI | CSRF, clickjacking, a hijacked admin session minting keys | CSRF token, POST-only, step-up password within 10 minutes, `frame-ancestors 'none'`, no third-party scripts | F-22, F-23, F-33 | F-22 tests, H-11 |
| N-13 | Owner confirmation page | A player tricked into confirming a key, CSRF on confirm, the revealed key read by page script | POST-only with CSRF token; password re-entry in the confirming request; request details (requesting admin, scopes, IP ranges, expiry) shown before confirming; 7-day lapse; owner can revoke at any time; no third-party scripts, `connect-src 'self'`, `no-store` | F-32, F-33 | F-32 tests, H-11 |
| N-14 | Session-token hashing transition (F-31) | Everyone logged out by a wrong deploy order; the dual read letting a stored value be presented as a token | Code before migration; dual read only for 32-character stored values while every presented token must be 32 hex, so a 64-character digest is never accepted; idempotent migration; follow-up removal of the dual read | F-31 | F-31 tests, H-14 |

## 7. Findings v2 deliberately does not change

| Item | Why | Where it is raised |
|---|---|---|
| v1 sliding session expiry | F-31 changes storage and the suspension check only; v2 adds its own absolute age (U16) | Overview 6.7 |
| v1 critical and high findings | Accepted in writing (U1, 2026-11-24); Phase 6 kept ready, unscheduled | Overview header, Phase 6 |
| Admin maintenance and server-health operations | Admin UI only (E2) | T-19, catalog section 20 |
| Password reset weaknesses | Website flow; v2 does not port it | Overview U17 |
| Public static survey images | Product behaviour; unguessable URLs | T-30 |
| Live feed granularity | Product decision of 2026-08-23 | T-31 |
| Website AJAX defects (CSRF, verbs, anonymous personal-data actions) | Out of v2's scope; the website keeps its controllers | Phase 6 tasks S-04, S-05 |
| Website explorer columns visible to any login | Product behaviour on the website | T-28 |
