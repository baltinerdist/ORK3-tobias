# Phase 2 — Read fan-out

Every read endpoint in the catalog, built by applying one template per resource family. Starts after gate F-30.

- Integration branch: `api-v2/phase-2` off the merged Phase 1.
- 23 tasks (R-00 to R-22), 3 waves, Sonnet unless marked. One worktree per task.
- After each wave: orchestrator merges, runs `php tools/api-spec/build.php`, commits the generated files once, runs the full API test directories, then an Opus review (section 4).

## 1. Fan-out task template

This template is the brief for every R- and W- task. The task entry supplies only what differs: catalog rows, files, new queries, special rules.

### 1.1 Inputs the implementer reads first

1. `orkservice/Api/README.md` (how to add an endpoint).
2. The reference resource: `orkservice/Api/src/V2/Resources/PlayersResource.php`, its schemas, `class.ApiDataPlayers.php`, `tests/Integration/Api/V2/PlayersTest.php`.
3. The catalog rows named in the task (`01-resource-catalog.md`), and catalog section 0 for the operation id rule, the canonical path and query parameter names, and the action-response rule.
4. The source domain methods named in those rows: read the method body and note its real parameter keys, return shape (nested status, flat status or raw) and any side effect.
5. `02-phase-1-foundation.md` sections 1 and 3.

### 1.2 Files a family task owns

| File | Rule |
|---|---|
| `orkservice/Api/src/V2/Resources/<Family>Resource.php` | Handlers only. Split into `<Family><Part>Resource.php` when a file would pass 400 lines |
| `orkservice/Api/src/V2/Schemas/<Name>.php` | One class per schema, attributes only |
| `system/lib/ork3/class.ApiData<Family>.php` | Only when the row says "new query". snake_case public methods, bound parameters, no auth logic |
| `tests/Integration/Api/V2/<Family>Test.php` | Extends `ApiTestCase` |
| `tests/Support/<X>Fixture.php` | Reuse existing fixtures; add a new one only if none fits, never edit another task's fixture |

Schema names are prefixed with the family noun (`KingdomAward`, `CourtNote`) so that parallel tasks cannot create the same class name; the only unprefixed schemas are the shared ones R-00 creates under `src/V2/Schemas/Shared/`, which every family reuses and none edits.

A family task never edits: the kernel, policies, `ApiFacts`, `src/V2/OpenApi.php` (tags, shared parameters and problem responses are all pre-declared by F-16), `src/V2/Schemas/Shared/`, another family's files, any legacy domain class, any generated file. If it needs one of those changed, it stops and reports (1.6).

### 1.3 Steps

1. For each catalog row write the handler method with the full attribute set required by `04-standards.md` section 2 (summary, description, tag, operation id, parameters, request body, responses with examples, `x-ork-scope`, `x-ork-policy`, `x-ork-cost`, `x-ork-cache` when the row says cache, `x-ork-replaces` from the `←` list).
2. Write the response schema classes. Every property has a description, a type, an example and `x-ork-visibility`. Start from the tiers in the catalog row; anything not listed there is `public` only if the matching website page shows it to a logged-out visitor, otherwise the stricter tier.
3. Handler body, in this order: read validated input from `$request->params` and `$request->input`; call the domain (`$ctx->domain(X::class)->Method([... 'Token' => $ctx->token()])`), never passing a request value as a viewer or caller id, and passing free text into a legacy (non-`Api*`) method only when the PR quotes the line that binds it (taint rule, overview 6.1; integers, enums and schema-validated dates are always fine); wrap with the correct `DomainResult` shape and `->orThrow()`; map the domain's PascalCase keys to the schema's snake_case in a private `map*()` method; return `Result::ok/collection` with the right `Subject`.
4. Unbounded collections: add a keyset method to the family's `ApiData` class: `x_page(<filters>, int $limit, ?array $after): array` returning `['items' => [...], 'next' => ?array]`, ordered by a unique, indexed key, fetching `limit + 1` rows. Run `EXPLAIN` and paste it in the PR description.
5. Draft, hidden and restricted objects: apply the catalog's rule and return 404 through the policy or `Problem` (`not_found`), never a filtered 200 that reveals existence.
6. Tests (1.4).
7. Run the verification commands (1.5) and fill in the PR description (1.7).

### 1.4 Required tests per route

| Case | Assertion |
|---|---|
| Happy path per tier that changes the output | Status, envelope, schema validity (the harness validates against the compiled schema), tiered fields present or absent |
| Generic boundary cases: no key (unless `public`), key without the scope, missing actor where the policy needs one, credentials in the query, unknown body key | One `assertBoundary(<operationId>, …)` call per route (F-28 harness); do not hand-write these |
| Cross-tenant actor | 403, or 404 where the catalog says hidden |
| Unknown id | 404 |
| Invalid parameter (type, range, unknown query key is ignored, unknown body key is 422) | 422 with `errors[].field` |
| Collections | second page via cursor; `limit` above 200 rejected; tampered cursor 400 |
| Cacheable routes | `Cache-Control: public` (policy `public`) or `private, max-age` (policy `key`) without an actor, `private, no-store` with one; `If-None-Match` → 304 in every case |
| Read purity | rows owned by the test's own fixtures in the tables the legacy method was known to touch are unchanged after the call (only where the catalog notes a side effect). Count with a `WHERE` on fixture ids, never whole-table counts: parallel worktrees share the sandbox database |
| Leak canary | the raw response does not contain the fixture player's username, email, real name or note text unless the tier allows it |
| Child ids | a child id that exists but belongs to another parent is 404 under this parent's path |
| Restricted player | person-level routes follow the website's logged-out rule for a restricted fixture player |

### 1.5 Verification commands (worktree)

```sh
ENVIRONMENT=TEST php ../../vendor/bin/phpunit -c phpunit.xml.dist --no-coverage --cache-directory=<scratch> tests/Integration/Api/V2/<Family>Test.php
ENVIRONMENT=TEST php ../../vendor/bin/phpunit -c phpunit.xml.dist --no-coverage --cache-directory=<scratch> tests/Unit/Api
php tools/api-spec/build.php --check        # run a plain build first, then --check, expect clean
../../node_modules/.bin/redocly lint orkservice/Api/spec/openapi.v2.json
sh tools/api-spec/gates.sh                   # no SQL in orkservice/Api, no escape shim, 8.1 syntax
curl -s 'http://localhost:19080/.worktrees/<wt>/orkservice/Api/index.php?_path=/v2/<one public route>' | head -c 600
```

### 1.6 Stop conditions (report to the orchestrator instead of improvising)

- A needed policy, fact resolver, scope or error code does not exist.
- The domain method's behaviour contradicts the catalog row (different auth, different shape, a write on a read path).
- A row cannot be implemented without editing a legacy domain class.
- The page-parity check suggests a field is more or less visible on the site than the catalog says.

### 1.7 PR description

Routes implemented (operation ids); new queries with `EXPLAIN`; visibility decisions with the page they were checked against; deviations from the catalog (must be none, or approved); test command output tail.

### 1.8 Definition of done

All catalog rows of the task respond; tests in 1.4 exist and pass; the four gates in 1.5 are clean; no file outside 1.2 is modified; generated files are not committed.

### 1.9 Dispatch size

The sizes in the task entries are for the whole task and assume the `assertBoundary` helper. A route costs roughly 60 to 80 changed lines (attribute block, handler, mapping, tests) and a response schema 40 to 80, so most family tasks are larger than one implementer dispatch should be. The orchestrator therefore dispatches a task as sequential sub-tasks `<ID>.1`, `<ID>.2`, … of at most five catalog rows (or about 400 changed lines) each, in the task's one worktree and branch, each sub-task ending in its own commit and its own diff review. Sub-tasks share the task's file ownership, so they never run in parallel with each other; tasks still run in parallel with other tasks. Task ids, counts and the dependency graph are unchanged. Expected splits are noted in the task entries as `(n dispatches)`; the orchestrator adjusts by row count.

---

## 2. Dependency graph

```
2A  R-00  ->  R-01 … R-08    (R-00 serial first; then independent)
2B  R-09 … R-16    (independent of each other)
2C  R-17 … R-22    (independent)
```

The shared schemas (`PlayerSummary`, `ParkSummary`, `KingdomSummary`, `UnitSummary`, `EventSummary`, `OccurrenceSummary`, `Officer`, `AuthorizationGrant`) are created by R-00 before any other Phase 2 task starts, because tasks in the same wave return each other's summaries (a kingdom's parks are `ParkSummary`, park and kingdom officers share `Officer`). They are read-only for every later task. 2B and 2C wait for the previous wave only so its review findings are fixed before more code copies its patterns.

## 3. Tasks

Sizes are changed lines including tests. Catalog references are to `01-resource-catalog.md`.

### Wave 2A

**R-00 Shared schemas** · Sonnet · ~300 · serial, before R-01 to R-08
- Files: `src/V2/Schemas/Shared/{PlayerSummary,ParkSummary,KingdomSummary,UnitSummary,EventSummary,OccurrenceSummary,Officer,AuthorizationGrant}.php`, `tests/Unit/Api/Spec/SharedSchemasTest.php`.
- Must: attributes only; every property with description, type, example and visibility. `PlayerSummary`: id, persona, park and kingdom ids and names, active; suspended and banned flags `officer`; no username. `Officer`: role (enum), player id, persona `public`; given name, surname, email `officer`; no username. `AuthorizationGrant`: officer-tier fields only. `EventSummary` and `OccurrenceSummary` carry no draft flag; times follow the instant versus wall-clock rule (04-standards, agent text section 3).
- Accept: the build compiles them with zero lint errors; a unit test asserts each property set and tier against this list. No routes.

**R-01 Reference data** · ~300
- Rows: section 1 reference routes and `GET /awards`.
- Files: `ReferenceResource.php`; schemas `AttendanceClass`, `ClassLevel`, `Pronoun`, `PrideFlag`, `ScheduleCategory`, `VotingRuleSet`, `SurveyQuestionType`, `Award`; `class.ApiDataReference.php` (`pronoun_list(): array`, `award_catalog(?bool $is_ladder, ?bool $is_title): array`).
- Special: do not call `Award::GetAwardList` or `Pronoun::GetPronounList`; both are replaced by the new queries above. All routes `public`, cached.

**R-02 Kingdoms read** · ~400
- Rows: section 4 GET routes except players, events, calendar, events.ics, authorizations.
- Files: `KingdomsResource.php`; schemas `Kingdom`, `KingdomConfigurationPublic`, `KingdomParkTitle`, `KingdomAward`, `KingdomAwardOptionGroup` (reuses `KingdomSummary`, `ParkSummary`, `Officer` from R-00); `class.ApiDataKingdoms.php` (`kingdom_award_list(int $kingdom_id, ?bool $is_ladder, ?bool $is_title): array`, `public_configuration(int $kingdom_id): array`).
- Special: the public configuration is an allow-list constant in the handler (attendance and dues periods, colour, online-attendance flag, recommendation-public flag, qual-test enable flags); every other configuration row is omitted. (2 dispatches)

**R-03 Parks read** · ~400
- Rows: section 5 GET routes except players, events, calendar, authorizations.
- Files: `ParksResource.php`; schemas `Park`, `ParkDay`, `ParkNearbyDay`, `ParkMapLocation` (reuses `ParkSummary`, `Officer`); `class.ApiDataParks.php` (`nearby_park_days(float $lat, float $lng, float $distance_km, string $from, string $to, int $limit): array` using `DB_PREFIX`, bound parameters, result cached 300 s keyed by rounded inputs).
- Special: `lat` −90..90, `lng` −180..180, `distance_km` ≤ 500, `from`..`to` ≤ 31 days, `limit` ≤ 100. Park day times are wall-clock (`format: time`), never converted. (2 dispatches)

**R-04 Units read** · ~250
- Rows: section 6 GET routes except authorizations.
- Files: `UnitsResource.php`; schemas `Unit`, `UnitMember` (reuses `UnitSummary`, `PlayerSummary`); `class.ApiDataUnits.php` (`member_list(int $unit_id): array`).

**R-05 Events read** · **Opus** · ~450
- Rows: section 7 GET routes for events, occurrences, schedule, embed, staff, rsvp-counts, copy-sources; `GET /events/nearby`; `GET /kingdoms/{id}/events`, `/parks/{id}/events`, `/kingdoms/{id}/event-templates`.
- Files: `EventsResource.php`, `EventOccurrencesResource.php`; schemas `Event`, `EventOccurrence`, `EventOccurrenceDetail`, `EventScheduleItem` (with `etag`), `EventStaffMember`, `EventRsvpCounts`, `EventEmbed` (reuses `EventSummary`, `OccurrenceSummary`); `class.ApiDataEvents.php` (`event_page(array $filters, bool $include_drafts_for_ids, array $manageable_event_ids, int $limit, ?array $after): array`, `can_view_event(int $event_id, int $actor_id): bool`).
- Special (why Opus): one draft rule used everywhere. An event is visible when published, or when the actor is the creator, an ORK admin, or passes `EventPlanning::CanManageEventDetail`. Implement it once as `EventVisibility` (a private helper class in the resource namespace calling domain predicates) and apply it to every route including schedule and occurrences. No draft flag exists in any schema. Occurrence and schedule start and end are wall-clock `local-date-time` values. (3 dispatches: events and lists; occurrences; schedule, staff, embed, RSVP counts)

**R-06 Calendar, ICS, calendar items** · ~350
- Rows: section 8 GET routes; `GET /kingdoms/{id}/calendar`, `/parks/{id}/calendar`, `/kingdoms/{id}/events.ics`.
- Files: `CalendarResource.php`; schemas `CalendarEntry`, `CalendarItem`; `class.ApiDataCalendar.php` (`range_entries(string $from, string $to, ?int $kingdom_id, ?int $park_id): array`, `published_events_for_ics(int $kingdom_id): array`).
- Special: dates validated by schema then bound; published events only; the ICS route returns `Result::stream('text/calendar', …)` with an ETag from the newest modification time and escapes text per RFC 5545. Calendar feeds pass the Principal's actor and admin flag to `GetKingdomCalendarFeed`; nothing viewer-related comes from the request.

**R-07 Weather, Era Phoenice, Live** · ~300
- Rows: section 15.
- Files: `WeatherResource.php`, `EraResource.php`, `LiveResource.php`; schemas as needed; `class.ApiDataWeather.php` only if the upcoming-events reader needs a published filter the engine lacks (it does: add `upcoming_published_events(int $days): array`).
- Special: the two archive routes are `authenticated`, cost 5 and 25; coordinates rounded to 2 decimals before the cache lookup; a per-actor daily cap of 50 archive fetches enforced through the limiter's cost bucket, plus the site-wide daily cap `ORK_API_WEATHER_ARCHIVE_DAILY_GLOBAL` counted only on upstream fetches (cache hits are free).

**R-08 Search and player search** · ~350
- Rows: section 14; `GET /players` (section 3).
- Files: `SearchResource.php`; method `list` added to a new `PlayerSearchResource.php` (not the reference `PlayersResource.php`); schemas `SearchHit` (flat, `kind` enum), `SearchLocationHit` (reuses `PlayerSummary`).
- Special: call `SearchService::ScopedPlayerSearch` and `UniversalSearch` only; the legacy `Player` search method is not used by v2. The caller id argument is `$ctx->actorId()`.

### Wave 2B

**R-09 Players read II** · ~450
- Rows: section 3 GET routes not built in F-28 or R-08: awards, awards/revoked, awards/reconciliation, classes, milestones, ladder-progress, officer-roles, beltline, voting-eligibility, authorizations, dues, dues/standing, dietary-preferences.
- Files: `PlayerRecordsResource.php`, `PlayerPrivateResource.php`; schemas `PlayerAward`, `PlayerClass`, `PlayerMilestone`, `PlayerLadderProgress`, `PlayerDuesEntry`, `PlayerDuesStanding`, `PlayerDietaryPreferences` (reuses `AuthorizationGrant` from R-00); extend nothing: new file `class.ApiDataPlayerRecords.php` (`awards_page(int $player_id, int $limit, ?array $after): array`, `dues_list(int $player_id, bool $include_revoked): array`, `authorization_list(int $player_id): array`). (3 dispatches)

**R-10 Attendance reads** · ~350
- Rows: section 9 GET routes; `GET /events/{id}/occurrences/{occ}/attendance`; `GET /me/attendance/last-class`.
- Files: `AttendanceReadResource.php`; schemas `AttendanceEntry`, `AttendanceLink`, `AttendanceLinkInfo`, `ParkAverages`.
- Special: `note` is officer tier; the sign-in lookup takes the actor only.

**R-11 Rosters and officer reports** · **Opus** · ~450
- Rows: section 13 table rows for rosters, officer-directory, voting-eligible, player-status-reconciliation, ladder-grid; `GET /kingdoms/{id}/players`, `/parks/{id}/players`.
- Files: `RostersResource.php`; schemas `RosterPlayer`, `DuesPaidEntry`, `OfficerDirectoryEntry`, `VotingEligiblePlayer`; `class.ApiDataRosters.php` (`roster_page(string $scope_type, int $scope_id, array $filters, int $limit, ?array $after): array`, `officer_directory(?int $kingdom_id): array`).
- Special (why Opus): these are the densest PII surfaces. The roster is a new query with no write (the suspension sweep moves to a job in W-25). Names use the `player.real_name` rule; emails are officer or admin only; responses for different tiers must never share a cache entry (do not use ghettocache here).

**R-12 Aggregate reports A** · ~400
- Rows: section 13 list from `active-kingdoms` through `new-player-attendance`, plus `active-players`.
- Files: `ReportsAttendanceResource.php`; one schema per report.
- Special: thin wrappers over the named `Report` methods; date ranges capped at 366 days by schema; `active-players` drops dues and waiver flags below officer tier; any report whose domain method echoes SQL or request dumps in an error detail must have that detail replaced with a generic message in the handler. Every public report route (this task and R-13) caches its result server-side for its `cache` seconds keyed by the normalised validated parameters (memcached, one entry per parameter set, public tier only), declares `x-ork-cost: 5`, and takes a slot from the site-wide report semaphore (F-09) on a cache miss; `503 busy` when none is free.

**R-13 Aggregate reports B** · ~400
- Rows: section 13 list from `class-masters` through `tournaments`, plus `park-distance-matrix`.
- Files: `ReportsAwardsResource.php`; schemas per report; `class.ApiDataReports.php` (`player_awards_page(...)`).

**R-14 Recap** · ~250
- Rows: section 13 recap routes. Files: `RecapResource.php`; schemas `RecapWeek`, `RecapKingdom`, `TrendSeries`. Stored recap only (`ReadWeeklyRecap`, `GetWeeklyRecapForKingdom`, series readers); never the live compute or the analytics fetch.

**R-15 Recommendations read** · **Opus** · ~400
- Rows: section 10 GET routes.
- Files: `RecommendationsReadResource.php`; schemas `Recommendation`, `RecommendationSecond`, `RecommendationGroup`.
- Special (why Opus): viewer identity. Pass `Token => $ctx->token()` and never a `RequestedBy` from input; when the kingdom has not made recommendations public the route needs an actor; single lookups use `RecommendationVisibility::canSeeRecId` and return 404; seconds are fetched only after the parent passes visibility; the CSV export escapes cells starting with `=`, `+`, `-`, `@`.

**R-16 Courts read** · ~400
- Rows: section 11 GET routes.
- Files: `CourtsReadResource.php`, `CourtReportsResource.php`; schemas `Court`, `CourtLine`, `CourtNote`, `CourtArtisan`, `CourtState`, `CourtReport`.
- Special: `getCourtAwards($court_id, $ctx->actorId())` so masking applies; `GET /courts` does not call the notifier; each `CourtLine` carries `etag` = `"rv-<row_version>"` in the body; `/state` uses the state hash as ETag and writes nothing. (2 dispatches)

### Wave 2C

**R-17 Surveys read** · ~450
- Rows: section 16 GET routes (definition group reads, link preview, respondent reads, results, rows, export, credit status, activity) and `GET /me/surveys/available`.
- Files: `SurveysReadResource.php`, `SurveyResultsResource.php`; schemas mirroring the domain rows in snake_case.
- Special: `GET /surveys/{id}/definition` must not insert the start marker (that becomes `POST /surveys/{id}/starts` in W-19); results go through `Survey::resultsAccess` then `SurveyReport::resultsFor` with the returned access object; rows and export set the actor so the audit row is written; never select the edit-key columns; for a survey configured as anonymous, respondent identity (player id, persona, name, and any free-text field the domain marks identifying) is absent from results, rows and exports for every tier including admin, with a test per route; CSV export cells are formula-escaped as in R-15.

**R-18 Qualification tests read** · ~450
- Rows: section 17 GET routes.
- Files: `QualTestsReadResource.php`; schemas `QualConfig`, `QualQuestion`, `QualQuestionWithKey` (manager only), `QualSet`, `QualAttempt`, `QualAttemptDetail`, `QualResult`.
- Special: two distinct question schemas so the answer key cannot leak by tier mistake; attempt detail for non-managers strips correctness on missed questions unless the kingdom's config allows it (same rule as the controller today).

**R-19 Bonus credits read** · ~300
- Rows: section 18 GET routes. Files: `BonusCreditsReadResource.php`; schemas `BonusCreditCategory`, `BonusCredit`, `BonusAllowance`, `BonusGranter`.
- Special: every domain call receives `$ctx->actorId()`; `include_revoked` requires `player.officer(edit)` checked in the handler through `PolicyEngine`.

**R-20 Explorers and State of Amtgard** · **Opus** · ~450
- Rows: section 13 explorer and State of Amtgard rows.
- Files: `ExplorersResource.php`, `StateOfAmtgardResource.php`; schemas `ExplorerRegistry`, `ExplorerQuery` (tree as a recursive schema with depth and leaf limits matching the domain constants), `ExplorerResult`.
- Special: keep the domain's limits (single-flight lock, 10 s timeout, 5,000 rows) and add the site-wide explorer semaphore (F-09, 4 slots); map busy → 429 with `Retry-After`, no free site-wide slot → 503 `busy`, timeout → 503; restricted criteria only when `IsScopeOfficer`; dues and waiver columns are omitted from the registry and rejected in `Columns` for non-officers; the export is a stream.

**R-21 Admin reads** · ~400
- Rows: section 19 GET routes.
- Files: `AdminReadResource.php`, `AdminUsageResource.php`; schemas per route.
- Special: `admin` policy on everything; audit-log `limit` ≤ 200. The server-health reads (database status, process list, weather health) are not in v2 (decision E2; catalog section 20).

**R-22 Me extras and media reads** · ~300
- Rows: section 2 notifications GET, `/me/rsvps`, `/me/dues-notice`; section 12 GET heraldry (five concrete routes, one per entity, sharing one handler method).
- Files: `MeExtrasResource.php`, `MediaReadResource.php`; schemas `Notification`, `UpcomingRsvp`, `DuesNotice`, `HeraldryInfo`.
- Special: reading notifications never marks them read.

## 4. Opus wave review checklist

1. Catalog conformance: every row of the wave exists with the stated scope and policy (diff the compiled route table against the catalog).
2. No handler reads a viewer, caller or privilege value from input.
3. Every schema property has a visibility tier; spot-check five per family against the website page.
4. No call to a method the catalog marks as replaced by a new query.
5. New queries: bound parameters, indexed ordering, `EXPLAIN` attached, no `SELECT *`. Taint rule: every free-text value passed into a legacy method has the binding line quoted in the PR.
6. Draft, hidden and restricted objects answer 404.
7. Tests cover 1.4; the leak canary exists for person-level schemas.
8. Gates clean on the merged branch; generated files regenerated by the orchestrator only.
