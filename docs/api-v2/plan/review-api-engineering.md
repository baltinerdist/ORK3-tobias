# API engineering review of the v2 plan

**Reviewer lens:** REST and HTTP semantics, OpenAPI 3.1 and codegen, versioning, client integration, docs explorer, self-documenting pipeline, task executability.
**Date:** 2026-11-23, against `refactor/api-reconstruction`. A Security reviewer edited the same files at the same time; where our lanes met, this review aligned with their text rather than overwriting it.

## Verdict

The architecture is sound and unusually well grounded: compiled routes from attributes, one boundary, a closed policy vocabulary, typed presentation and a measured v1 retirement. It was not executable as written. Several lint rules contradicted the catalog they were meant to enforce, the drift gate would have failed permanently after the first hook-formatted commit, the CI job could not install the lockfile, and parallel fan-out tasks would have collided on shared files and names. Those are fixed in the plan. The remaining gaps are a handful of policies the closed vocabulary cannot express (handed to the Security reviewer and orchestrator) and three product questions for the user.

Counts: 6 blockers, 13 major, 19 minor. Applied: 6 blockers, 12 major (one partly), 19 minor. Left open: 1 major (part), plus the recommendations in section 4.

## 1. Blockers

| # | Finding | Evidence | Change made |
|---|---|---|---|
| B1 | The pre-commit hook runs php-cs-fixer after the spec build, and `orkservice/Api/generated/` is not excluded, so `routes.v2.php` and `schemas.v2.php` are reformatted after generation and every later `--check` reports drift | `.php-cs-fixer.dist.php` excludes list; hook `format_php` | `04-standards.md` section 4 (exclude the directory, deterministic `var_export` output); F-16 Must; F-27 Also + Accept (an immediate `--check` after a hook commit must be clean) |
| B2 | Gates were skipped exactly where fan-out work happens: worktrees have no `vendor/` or `node_modules/`, the hook "skips with a notice" when swagger-php is missing, and `npx --no-install redocly` cannot find the binary | memory: worktrees use `../../vendor`; hook skip rule | `04-standards.md` section 3 (build resolves the autoloader from the main checkout via `git rev-parse --git-common-dir`, prints which); section 4 skip rule; F-27; Phase 1 commands table and Phase 2 template 1.5 use `../../node_modules/.bin/redocly` |
| B3 | The CI workflow as specified cannot run. `composer.lock` already contains `symfony/string` 8.1 (PHP ≥ 8.4.1) and an infection adapter needing 8.3, and `composer.json` requires `ext-redis`, so a PHP 8.3 runner fails `composer install`. `tests/bootstrap.php` loads `startup.php`, which opens PDO eagerly, so "unit, no database needed" fails. Redocly CLI has no breaking-change diff command | `composer.lock`, `composer.json`, `tests/bootstrap.php:60`, `system/lib/Yapo2/class.YapoMysql.php:22` | `04-standards.md` section 5 rewritten (PHP 8.4 with redis/memcached extensions, `npm ci --ignore-scripts`, separate `phpunit.api-unit.xml.dist`, `oasdiff breaking` pinned); F-01 adds `orkservice/Api/autoload.php` (no startup) and the DB-free unit bootstrap; D3 rationale corrected |
| B4 | Lint rules contradicted the catalog, so correct tasks would fail the build: PA-03 denies a parameter named `token` but link routes are `/{token}`; SC-03 denies a `token` property but link creation returns one; MAP-01 allowed each v1 method once, but the catalog maps `GetAuthorizations`, `UpdatePlayer` and `GetPlayerRoster` to several operations; OP-09 forbade caching tiered schemas while F-28 and the catalog cache tiered reads; RS-01 required an envelope on every 200, but CSV, ICS, XLSX and `/openapi.json` are streams | `04-standards.md` section 3 vs catalog rows | Catalog section 0 (`link_token` canonical name); PA-03 untouched, SC-03 note; MAP-01 rewritten (method → list of operations); OP-09 rewritten; RS-01 + new `x-ork-stream` extension; route entry 3.9 gains `stream`; OP-04/OP-07 adjusted for optional-key public routes |
| B5 | DOC-02 required every change to bump `info.version` "relative to the committed spec": every parallel task would edit the same constant, and on task branches (generated files deliberately uncommitted) there is no committed spec to compare with | `04-standards.md` DOC-02; template 1.8 | DOC-02 rewritten: orchestrator owns the constant, `2.0.0` until T0, bump enforced by the CI `breaking` job after T0. `--check` semantics clarified (files on disk; what it proves on a task branch) |
| B6 | Parallel waves collided on shared files and names: every family needs a tag and shared parameters in `OpenApi.php`; R-02 returns `ParkSummary` created by R-03 in the same wave; park and kingdom officers share `Officer`; `AuthorizationGrant` was created by both R-09 and W-08; unprefixed schema names and free-form operation ids (`listOfficers` in two tasks) only collide at the wave merge | Phase 2 section 2 and task file lists | F-16 now delivers a complete `OpenApi.php` (servers, all tags, all shared parameters, Problem schema, envelope synthesis, `BatchItemResult`); new task **R-00 Shared schemas** (serial, start of 2A; Phase 2 is 23 tasks, total 124); family-prefixed schema names (template 1.2, standards section 3); mechanical operation-id rule (catalog section 0); W-08 reuses `AuthorizationGrant` |

## 2. Major

| # | Finding | Change made |
|---|---|---|
| M1 | "RFC 3339 in UTC" for all times would shift every event, schedule item and park-day time: ORK stores no time zone for parks or events (no tz column anywhere; server zone is `America/Chicago`), so these are wall-clock values, not instants | D5, overview section 7 Types; standards agent text section 3 (instants vs `local-date-time`/`time`); F-05 formats; F-06 conversion rule; R-00, R-03, R-05 notes; migration guide (V-09) |
| M2 | Caching keyed on "no `Authorization` header" leaks tiered data for `acts_as_owner` secret keys, which have an actor without that header; `Vary` omitted `Authorization`; Cloudflare ignores `Vary` other than `Accept-Encoding` | Overview section 7 Caching (actor-based rule, `Vary` incl. `Authorization`, 304 on private responses too), aligned with the Security reviewer's concurrent `key` → `private` change; F-20; OP-09; template 1.4; F-25 runbook (no edge cache rule on `/api/v2/*`) |
| M3 | Idempotency ran before the policy check and stored all 4xx: a refused caller created records and could observe replays, and a 403/429 would be replayed after the cause cleared | Middleware order 3.10 (presence check before policy, record after); overview flow diagram; F-13 (request-hash definition, which outcomes are stored, record deleted on 5xx/429) |
| M4 | `If-Match` versions existed only as a response header, so `GET /courts/{id}/lines` (a list, no single-line GET) gave clients no version to send | Catalog section 11; conventions Concurrency row; standards (`etag` property); R-05, R-16, W-16 |
| M5 | `/{entity}/{id}/heraldry` as a templated first segment collides with every `/players/…` route in the router and gives generators an untyped `entity` argument | Catalog section 12 (five concrete routes per row, one shared handler, per-entity policy mapping); R-22; W-14 |
| M6 | Path parameters were inconsistent (`{id}`, `{occ}`, `{pid}`, `{qid}`, `{iid}`; `note_id` and `item_id` each meaning two different things), which makes shared component parameters impossible and generated signatures inconsistent | Catalog section 0 canonical-name table; new lint PA-04; F-16 declares them all |
| M7 | Most fan-out tasks are two to five times the ~400-line budget (R-05 about 15 routes, W-18 and W-20 about 25), mostly because the per-route negative test matrix is hand-written | Template 1.9 dispatch rule (sequential sub-tasks of ≤ 5 rows in one worktree; ids and counts unchanged); `ApiTestCase::assertBoundary` in F-28 replaces three hand-written rows of 1.4; F-16 split into two dispatches; overview section 11; Phase 3 header lists the largest |
| M8 | Several routes need policies the closed vocabulary cannot express: a policy that depends on the body (unit active toggle), two alternative scopes (`/admin/permissions`), nested `any`/`all` (player merge), a kingdom-config-dependent public listing (`GET /recommendations`), `Banner::canEditBanner` | **Partly applied:** units split into `PUT`/`DELETE /units/{id}/retirement`; `/admin/permissions` narrowed to admin (officers use the scoped lists); heraldry policy mapped per entity. **Left for the Security reviewer and orchestrator** (policy vocabulary is their lane): `GET /recommendations` public-when-allowed, banner rule, merge nesting. R-15 and W-14 will hit the stop condition until these are settled |
| M9 | Envelope and error model were underspecified for codegen: no envelope components (tasks would hand-write one per schema), Problem `type` undefined, `code` not an enum, `errors[].field` format inconsistent between F-03 and F-05 | F-16 (envelope synthesis, Problem schema with generated `code` enum, fixed `type` URI); overview Error body and Envelope rows; F-05 field format; standards item 7 |
| M10 | Response `required`/nullable semantics undefined; the Presenter rule ("emit null only if nullable, else omit") makes generated clients unsound | Standards section 3 rules; lint SC-05; F-06 Must |
| M11 | Read-purity and "no row changed" assertions used whole-table counts while parallel worktrees share the sandbox database | Template 1.4; Phase 3 item 9 |
| M12 | Explorer: with an absolute production `servers` URL and server selection off, Try-it on staging or a dev box would call production; F-26's acceptance needs F-24 and F-25 but the DAG had only F-19; RapiDoc 9.3.8's OpenAPI 3.1 rendering is unverified (superseded: the pin is now 12.3.0, decision U13, and the render check stays); RapiDoc does not render `x-ork-*`, so "the docs state the real rule" was not true | F-26 (`server-url` from page origin, `_path` fallback, 3.1 rendering check with stop condition, dependencies); DAG 1F; F-16 generated "Access" line in every description; overview section 10 |
| M13 | Three roster surfaces for one dataset (`/kingdoms/{id}/players`, `/parks/{id}/players`, `/reports/rosters/players`) | `/reports/rosters/players` removed; `← Report/GetPlayerRoster` moved to the scoped rosters; section 21 mapping updated |

## 3. Minor (all applied)

| # | Finding | Change made |
|---|---|---|
| m1 | Date windows named `start`/`end` in some rows, `from`/`to` in others; `distance` vs `distance_km` | Catalog section 0 shared query names; kingdom calendar and parks nearby rows; R-03 |
| m2 | Unknown query parameters undefined (browser libraries add `_=`) | F-05; overview Filtering row |
| m3 | PATCH semantics undefined | Standards item 6; overview Updates row |
| m4 | Array query parameter serialization undefined | Standards item 5; lint PA-05 |
| m5 | Mixed lists (calendar entries, search hits) would need `oneOf`, which neither the Presenter nor the viewer then pinned handled well | Standards section 3; lint SC-06; R-08 `SearchHit` with `kind` |
| m6 | Cursors not bound to operation or filters | 3.3 `Cursor` signatures; F-08 |
| m7 | 201 vs 200 for noun-named actions (`/merges`, `/copies`) unclear | Catalog section 0; Phase 3 item 3 |
| m8 | `.redocly.yaml` is the legacy config name; ruleset unspecified | F-19 |
| m9 | `POST /sessions` 201 had no `Location` (RS-01) and no `no-store` | Catalog section 2 |
| m10 | `/me/notifications` and `/units` unbounded without `pg`; no rule for uncapped domain lists | Catalog rows and section 0 rule |
| m11 | `PATCH /attendance/sign-ins/{id}` is an own-row route outside `/me` | Now `PATCH /me/attendance/{attendance_id}` |
| m12 | No mechanism for deprecating a v2 operation | `x-ork-sunset` extension; route entry; F-20 headers; overview Versioning |
| m13 | `security: []` on public routes means generated clients never send a key (and lose the higher limit) | Standards item 4 (`[[], ['orkKey' => []]]`); OP-04/OP-07 |
| m14 | V-05 `successor-version` link undefined when a v1 method has several successors | V-05 |
| m15 | X-07 removes the `ork_api_tally` write, but the Platform Trends page reads that table through `Report::GetApiUsage` | X-07 |
| m16 | Migration guide missed two traps: v1 `Authorize` with a token rotates the token v2 is using; time fields change meaning | V-09 content |
| m17 | F-29's dry run would create `ReferenceResource.php`, which R-01 owns | F-29 (throwaway worktree, never merged) |
| m18 | Nothing proved the spec is actually usable by a generator | H-10 codegen smoke (`openapi-typescript` + `tsc --noEmit`) |
| m19 | D3 said swagger-php could run in the 8.1 containers; the lockfile makes that false | D3 |

## 4. Recommendations not applied

- **Possible missing endpoints** (for W-27's parity sweep to confirm against the tally rather than add now): a date-window `GET /occurrences?from=&to=&kingdom_id=` (today `/events?from=&to=` mixes event and occurrence semantics, and calendar-style clients want dated occurrences); `GET /players/{player_id}/units` if the profile's unit memberships are used by mORK or jsork.
- **Endpoints that arguably should not be on a key-authenticated API:** `/admin/maintenance/table-optimizations`, `/admin/maintenance/log-purges`, `/admin/health/processes`. D17's reasoning for key lifecycle applies to them too (a leaked admin key should not reach maintenance). See question Q1.
- **Username availability** needs an actor, but self-registration happens before an account exists. A sub-resource under the link (`GET /self-registration-links/{link_token}/username-availability`) would fit; it is an enumeration question, so it is left to the Security reviewer.
- **Occurrence page bundle** (`GET /events/{event_id}/occurrences/{occurrence_id}` wrapping `GetOccurrencePageData`) is shaped for one web page. Acceptable for v2.0; prefer leaner sub-resources when it is next touched.
- **`X-ORK-Client`** should be described once in `info.description` as the recommended client label (`<App>/<version> (<platform>)`), not as a per-operation parameter. Small enough for F-16 to pick up.
- The per-task size estimates in the task entries still read low. The dispatch rule (template 1.9) makes that harmless; the orchestrator should plan wall-clock time by route count, not by those numbers.

## 5. Cross-lane notes for the Security reviewer

- Policy vocabulary gaps in M8 (recommendations public listing, banner rule, nested `any`/`all` for merges, `include_revoked` on bonus credits) need a decision before R-15, R-19 and W-14 dispatch.
- The `key`-policy caching change you made and the actor-based rule here are now consistent in overview section 7, F-20, OP-09 and template 1.4. Please keep them in step if you change either.

## 6. Open questions for the user

| # | Question | Default if unanswered |
|---|---|---|
| Q1 | Should admin maintenance operations (table optimisation, log purge, process list) be callable through API keys at all, or stay in the Admin UI only? | Keep them in the catalog as planned; recommendation is UI only |
| Q2 | Event, schedule and park-day times are treated as wall-clock times in the park's own zone, emitted without an offset. Is that how officers enter them, and do you want a per-park or per-kingdom time zone later so the API can emit true instants? | Offset-free local times; no time zone work |
| Q3 | Two dev-only tools are added: `oasdiff` (CI breaking-change check) and `openapi-typescript` (codegen smoke test). Acceptable? | Add them, pinned, dev and CI only |

## 7. Decisions applied (2026-11-24)

The maintainer answered this review's questions and the plan-wide decisions on 2026-11-24 (overview section 12). Effect on this review:

| Item | Decision | Where applied |
|---|---|---|
| Q1 admin maintenance operations | Admin UI only, not in v2 (E2) | Catalog sections 19 and 20; R-21 and W-26 trimmed; traceability T-19 |
| Q2 event, schedule and park-day times | Confirmed park-local, emitted without offset (E3); per-park time zone (defaulting from the kingdom) recorded as a future item, after which UTC fields can be added | Overview section 7 Types row and section 12 |
| Q3 dev tooling | `oasdiff` and `openapi-typescript` approved, pinned, dev/CI only (E4) | F-01 `package.json`; `04-standards.md` section 5; H-10 |
| M12 explorer viewer | RapiDoc pinned to 12.3.0 (U13), 3.1 render check and stop condition kept; theming via RapiDoc 12's CSS variables | Overview D19 and section 10; F-01; F-26 |
| Explorer access | The explorer and `openapi.json` need an ORK login (U9), as a speed bump only | Overview D20 and section 10; catalog section 1; F-24; F-26; F-25 runbook (no edge exception for the spec) |
| B3 CI | Actions enabled on the fork and upstream; CI is the enforcing gate (U5) | `04-standards.md` sections 4 and 5; overview 11.1; H-14 |

