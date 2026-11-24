# Phase 3 — Write fan-out

Every mutation in the catalog. Uses the fan-out template in `02-phase-2-read-fanout.md` section 1, with the additions below.

- Integration branch: `api-v2/phase-3` off merged Phase 2.
- 27 tasks, 4 waves. Sonnet unless marked. Opus review after each wave (section 4).
- Tasks are dispatched in sub-tasks of at most five routes each (Phase 2 template section 1.9). The largest here: W-18 and W-20 (about 25 routes each, 5 dispatches), W-06, W-10, W-16 (3 to 4 each).
- The test database is disposable: tests create and change real rows through the domain. They never send real email (leave the mail config empty in the test environment) and never run `DROP` or `TRUNCATE`.

## 1. Additions to the template for write routes

1. **Delegate, do not re-implement.** A write handler validates, enforces policy, then calls the existing domain method with `Token => $ctx->token()` and ids from the validated path and body. Business rules stay in the domain.
2. **Result shape is explicit.** Choose `DomainResult::nested`, `::flat` or `::raw` per call after reading the domain method. `Player::AddAward` and everything built on `add_player_award` is `flat`.
3. **Status codes.** Create → 201 with `Location` and the created resource (re-read it; do not echo the request). Noun-named actions that create no addressable record (merges, moves, transfers, copies, batches, reconciliations, imports, resets) → 200 with the outcome (catalog section 0). Update → 200 with the resource. Delete, state-setting `PUT` with nothing to return → 204. Domain refusal because of state (already finalized, locked structure, retake cap) → 409 `conflict` with the domain's message as `detail`.
4. **Idempotency.** Routes the catalog marks "Idempotency required" set `x-ork-idempotent: required`. For event schedule batch and copy, pass the header value to the domain as its batch or request token.
5. **Concurrency.** Routes the catalog marks `If-Match` set `x-ork-if-match: true`; the handler parses the ETag, passes the expected version to the domain, and maps a stale result to 412 `stale_resource`.
6. **Actor fields.** Any "by whom" input of the legacy method (`SuspendedById`, `GivenById` when it means the actor, `created_by`, `RequestedBy`) is filled from the Principal. `given_by_id` on an award is a real attribute and stays an input.
7. **Scope of ids.** A child id in a path must belong to its parent (`note_id` to `player_id`, `occ` to `event_id`, `line_id` to `court_id`, `park_day_id` to `park_id`, `authorization_id` to the scope in the path): check with `ApiFacts` (`*_scope` or `child_scope`) through a fact reference in the route's policy, and answer 404 otherwise. If a needed kind is missing from `child_scope`, stop and report (1.6); never resolve ownership in the handler.
8. **Audit.** The kernel writes `request.write`. Where the legacy controller wrote a DangerAudit row itself (authorization grants, event staff), the handler calls the same domain audit method the model exposes, once, in the shared handler.
9. **Extra tests per write route** (in addition to template 1.4): unauthorized actor of another kingdom → 403 and no fixture-owned row changed (scope every count to fixture ids; parallel worktrees share the sandbox database); replay with the same idempotency key → one row; stale `If-Match` → 412 and no change; unknown body property → 422; oversize upload → 413; wrong MIME (sniffed) → 415.
10. **Cache busting.** If the domain method busts caches, nothing more is needed. A handler never flushes memcached wholesale.

## 2. Dependency graph

```
3A  W-01 … W-07          (need Phase 2 schemas)
3B  W-08 … W-14          (W-08 before the grants routes of others; W-10 before W-11, W-12)
3C  W-15 … W-21          (W-16 before W-17; W-18 before W-19; W-20 before W-21)
3D  W-22 … W-27          (W-27 last, serial)
```

Within a wave, an arrow means "start after": W-11 and W-12 start when W-10 is merged into the wave branch; W-17 after W-16; W-19 after W-18; W-21 after W-20.

## 3. Tasks

### Wave 3A

**W-01 Players write I (create, profile, credentials, milestones, dietary)** · ~450
- Rows: section 3 `POST /players`, `PATCH /players/{id}`, `PUT /players/{id}/credentials`, milestones writes, `PUT …/dietary-preferences`; section 2 `PUT /me/email`.
- Files: `PlayerWriteResource.php`; schemas `PlayerCreateInput`, `PlayerProfileInput`, `CredentialsInput`, `MilestoneInput`, `DietaryPreferencesInput`.
- Special: `UpdatePlayer` is one large method; the handler builds its request from an explicit per-route allow-list of fields and never forwards unknown keys. Profile fields carry `x-ork-writable`; the handler rejects a field above the actor's tier with 403 naming the field. Passwords: min 10 chars, never logged, never echoed; self-change requires `current_password` verified with `ApiDataAccount::verify_password` (never `Authorize`, which would create a session and can evict the player's devices); the credentials route uses the login throttle bucket; after a successful username or password change, every other session of that player is destroyed (`DestroySessionsForUser` with `KeepCurrent`), and an officer changing another player's password destroys all of that player's sessions. Dietary save passes `$ctx->actorId()` as the player id after the `self` policy.

**W-02 Players write II (moderation)** · ~400
- Rows: `PUT …/active`, `/restriction`, `/suspension`, `/ban`, `/waiver`; `POST …/merges`, `…/moves`; `PUT …/classes/reconciled-credits`; `POST /kingdoms/{id}/waiver-resets`, `/parks/{id}/waiver-resets`.
- Files: `PlayerModerationResource.php`; input schemas.
- Special: merge and move require both sides' authority (two policy entries with `all`); merge is idempotency-required and returns 409 when the source no longer exists. The waiver route passes `WaiverUrl` as `''`, re-encodes images through `UploadReader` (W-14), accepts PDF only when the bytes start with `%PDF-`, and returns only the `waivered` flag, never a file URL (overview 6.2; storage issue in Phase 6 S-10).

**W-03 Player awards** · **Opus** · ~400
- Rows: section 3 award writes.
- Files: `PlayerAwardsWriteResource.php`; schemas `AwardGrantInput`, `AwardUpdateInput`, `AwardRevocationInput`, `AwardReconciliationInput`.
- Special (why Opus): the flat-status trap and cross-path double grants. Grant uses `DomainResult::flat`; when `recommendation_id` is supplied the handler calls the same court reconciliation and cluster-resolution sequence the website's grant action performs, by way of a new domain method `ApiDataAwards::grant_with_reconciliation(array $grant, int $actor_id, string $token): array` in `class.ApiDataAwards.php` so the orchestration is not in the transport tier. `kingdom_award_id` must belong to the recipient's kingdom family.

**W-04 Dues** · ~250
- Rows: `POST /players/{id}/dues`, `PUT …/dues/{dues_id}/revocation`. Files: `PlayerDuesWriteResource.php`; schemas. Uses `Player::AddDues` and `RevokeDues` only (the `ork_dues` path).

**W-05 Attendance write** · ~450
- Rows: section 9 writes.
- Files: `AttendanceWriteResource.php`; schemas `AttendanceInput`, `AttendanceLinkInput`, `SignInInput`.
- Special: `attendance.scope` reads the scope from the validated body (exactly one of `park_id`, `kingdom_id`, `occurrence_id`); for PATCH and DELETE the scope comes from `ApiFacts::attendance_scope`. Link tokens are 48 hex characters by schema, named `link_token` in paths and in the create response (never `token`, lint PA-03 and SC-03). `POST /attendance` is idempotency-required because mobile clients retry.

**W-06 Kingdoms write** · ~450
- Rows: section 4 writes except authorizations and waiver-resets.
- Files: `KingdomsWriteResource.php`; schemas.
- Special: configuration PATCH accepts only documented key names (enum in the schema), each with its own value schema; values are stored in the existing JSON-quoted form; officer role is an enum; `PUT /active` maps to retire or restore.

**W-07 Parks write** · ~400
- Rows: section 5 writes except authorizations and waiver-resets. Files: `ParksWriteResource.php`; schemas. Merge and transfer are admin and idempotency-required.

### Wave 3B

**W-08 Authorization grants (shared)** · **Opus** · ~400
- Rows: the `authorizations` routes of kingdoms, parks, events, units; `/admin/global-admins`; `GET /admin/permissions`.
- Files: `AuthorizationGrantsResource.php` (one handler class registering routes for each scope type), schema `AuthorizationGrantInput` (reuses `AuthorizationGrant` from R-00); `class.ApiDataGrants.php` (`grant_list(string $type, int $id): array` with officer-tier fields only).
- Special (why Opus): privilege management. Role is an enum (`edit`, `create`); `admin` role is only accepted on the global-admins route under the `admin` policy; adding uses `Authorization::AddAuthorization` with the session token so the domain's own check runs; the handler writes the DangerAudit row for add (the legacy add path does not) through `Model`-equivalent domain call `Ork3::$Lib->dangeraudit->audit(...)`; removal goes through `RemoveAuthorization`. A caller can never grant a role above their own on that scope: test it.

**W-09 Units write** · ~400
- Rows: section 6 writes. Files: `UnitsWriteResource.php`; schemas.
- Special: `PUT /retirement` calls `RetireUnit` and `DELETE /retirement` calls `RestoreUnit`, nothing else. The unit award route is not ported: awards to a unit's members go through the player award route, which checks authority over the recipient.

**W-10 Events write I** · ~450
- Rows: `POST /events`, `PATCH`/`DELETE /events/{id}`, `PUT …/status`, occurrence create, patch, delete, `current`.
- Files: `EventsWriteResource.php`; schemas `EventInput`, `OccurrenceInput`, `FeeInput`, `LinkInput`.
- Special: owner scope is exactly one of `kingdom_id`, `park_id`, `unit_id`, or personal. Personal events set the owner to the actor; a body `owner_player_id` does not exist. Unit events need `unit(create)`. Link URLs: http, https or mailto by schema.

**W-11 Events write II (schedule, staff)** · ~450 · after W-10
- Rows: schedule item create, patch, delete, batches, copies; staff add and remove.
- Files: `EventScheduleWriteResource.php`, `EventStaffWriteResource.php`; schemas `ScheduleItemInput`, `ScheduleBatchInput`, `StaffInput`.
- Special: item PATCH and DELETE require `If-Match` (the item's modified time, passed as the domain's `Seen`); batch size capped at the domain's `ScheduleBatchMaxOps`; meal items need the `feast` capability.

**W-12 RSVPs, event attendance, reconciliation** · ~350 · after W-10
- Rows: `PUT`/`DELETE …/rsvps/me`, `DELETE …/rsvps/{player_id}`, `POST …/attendance`, `POST …/attendance/reconciliations`.
- Files: `EventRsvpWriteResource.php`; schemas.
- Special: the self routes always act on the Principal; status is validated with `Event::IsAllowedRsvpStatus`.

**W-13 Calendar items** · ~250
- Rows: section 8 writes. Files: `CalendarItemsWriteResource.php`; schema `CalendarItemInput` (colour as `^#[0-9a-fA-F]{6}$`).

**W-14 Media writes** · ~450
- Rows: section 12 writes, as concrete per-entity routes (five per catalog row, one shared handler method per row); `PUT /players/{id}/waiver` image part coordinated with W-02 (W-02 owns the route; W-14 provides `UploadReader`).
- Files: `MediaWriteResource.php`, `orkservice/Api/src/V2/Support/UploadReader.php` (reads one multipart file, enforces size, sniffs MIME with `finfo`, returns bytes and type); schemas.
- Special: no URL input anywhere, and the legacy `*Url` request fields are always set to `''` when calling the domain; `UploadReader` decodes every image with GD and re-encodes it (PNG stays PNG, everything else becomes JPEG), which strips EXIF including GPS and defeats polyglots; SVG and any type `finfo` does not report as JPEG, PNG, GIF or WebP is 415; bytes are handed to the domain as the base64 field it expects; the legacy remove path that misses PNG files gets a new domain method `ApiDataMedia::remove_player_heraldry_files(int $player_id): void` called after the domain remove.

### Wave 3C

**W-15 Recommendations write** · **Opus** · ~450
- Rows: section 10 writes.
- Files: `RecommendationsWriteResource.php`; schemas `RecommendationInput`, `SecondInput`, `RecommendationBatchInput`, `ClusterResolutionInput`.
- Special: the requested Monarchy Only level is capped by the domain; the cluster-resolution route enforces `org(recipient scope, create)` in the policy layer before calling the domain method; every per-id batch result reports `ok` or an error code; operations on a recommendation the actor cannot see return 404.

**W-16 Courts write I (courts, lines, notes, artisans)** · ~450
- Rows: section 11 writes except stage, unstage, skip, pass-to-local, bulk staging, prepopulation, finalize.
- Files: `CourtsWriteResource.php`, `CourtLinesWriteResource.php`; schemas; `class.ApiDataCourts.php` (`set_tracking_status(int $line_id, string $kind, int $status): bool`, `touch_presence(int $court_id, int $actor_id): array`).
- Special: every line mutation requires `If-Match: "rv-<n>"` (the value clients read from the line's `etag` property); every line in a mutation response carries its new `etag`; writes are refused with 409 on a completed court; `add` validates that the award belongs to the court's kingdom and that a referenced recommendation is usable (`canUseRecForLine`); citations drawn from hidden recommendations are rejected with 422 as the controller does today.

**W-17 Courts write II (staging and finalize)** · **Opus** · ~400 · after W-16
- Rows: stage, unstage, skip, pass-to-local, `staging/bulk`, `prepopulations`, `finalize`.
- Files: `CourtRunResource.php`; adds `finalize_court(int $court_id, int $actor_id, string $token, bool $skip_remaining): array` to `class.ApiDataCourts.php` (coordinate: W-17 owns the file after W-16 merges).
- Special: finalize reproduces the controller's sequence (commit each staged line, resolve recommendation clusters, mark finalized) inside the domain class; it is idempotency-required and also safe to re-run without the key because each line is claimed atomically; the response lists every line with `ok`, `noop`, `duplicate` or `error`; `completed` is false when any line failed, and the HTTP status is still 200 because partial success is the documented outcome.

**W-18 Surveys write I (definition)** · ~450
- Rows: section 16 definition and structure writes, image upload, markdown preview.
- Files: `SurveysWriteResource.php`, `SurveyStructureWriteResource.php`; schemas.
- Special: set the actor on the domain object (`setActor`) so activity rows are written; `survey.manage` resolves page, question and image ids to their survey; structure routes map the lock error to 409; status transitions map the domain's transition error to 409; `DELETE …/responses` requires `?confirm=true` unless `dry_run`.

**W-19 Surveys write II (respondent, credit)** · ~400 · after W-18
- Rows: `POST …/starts`, `PUT …/draft`, `POST …/responses`, `PUT …/responses/mine`, credit routes.
- Files: `SurveyRespondResource.php`, `SurveyCreditResource.php`; schemas.
- Special: consent and anonymity are decided by the domain; the handler passes nothing identifying beyond the actor id; submit is idempotency-required; after a successful write call the model-equivalent cache bust the controller calls today (expose it through a domain method if it only exists in the UI model).

**W-20 Qualification tests write I (manage)** · ~450
- Rows: section 17 config, managers, questions, library copy, reports clear, stats reset, sets, retake resets.
- Files: `QualTestsManageResource.php`, `QualSetsResource.php`; schemas.
- Special: kingdom for question, set and attempt ids comes from `ApiFacts::qual_scope`, never the request; library copy checks the source kingdom's sharing flag; import capped at 200.

**W-21 Qualification tests write II (taking)** · **Opus** · ~400 · after W-20
- Rows: `POST …/attempts`, `POST /qual-attempts/{id}/answers`, `POST /qual-attempts/{id}/checks`, `POST /qual-questions/{qid}/reports`.
- Files: `QualTakeResource.php`; `class.ApiDataQualAttempts.php` (`open_attempt(int $player_id, int $kingdom_id, string $type, array $question_ids): array`, `load_open_attempt(int $attempt_token_id): ?array`, `close_attempt(...)`), plus a migration `…-api-v2-qual-open-attempts.sql` for a small `ork_qual_open_attempt` table (id, player, kingdom, type, question ids JSON, checks used, created, expires) with a manifest entry.
- Special (why Opus): design-sensitive. An attempt binds the served question ids to the player; submit accepts answers only for those ids, consumes the retake atomically (`tryConsumeRetake`), scores, records, and syncs the qualification only when the player's home kingdom is in the test kingdom's family (closing the cross-kingdom flag issue); the check route works only inside an open attempt and within its budget.

### Wave 3D

**W-22 Bonus credits write** · ~400
- Rows: section 18 writes. Files: `BonusCreditsWriteResource.php`; schemas. Every call passes `$ctx->actorId()`; grant is idempotency-required.

**W-23 Account flows** · ~400
- Rows: `GET /usernames/{username}/availability`, self-registration routes, `GET /geocode`. `POST /password-resets` is not built in v2.0 (decision U17, 2026-11-24: website only; a token-based reset is a future item): the legacy reset emails a short temporary password in a link and leaves sessions alive, and wrapping it would add a second way to trigger that flow.
- Files: `AccountFlowsResource.php`, `GeocodeResource.php`; schemas.
- Special: strict per-IP buckets (fail closed, overview 6.4); self-registration never returns a session and refuses a `client`-style label; geocode results cached by normalised address for 30 days in memcached, 20 per actor per day, and the site-wide `ORK_API_GEOCODE_DAILY_GLOBAL` cap counted on upstream calls only. When the future token-based reset is scheduled, it is a new task: 202 with the same body and a fixed minimum duration whatever happened, per-IP and per-account buckets, a single-use random token with a 30-minute expiry, and all sessions ended on completion.

**W-24 IdP integration** · ~250
- Rows: `/idp/claims`, `/idp/claims/verify`. Files: `IdpResource.php`; schemas. Requires a secret key with `idp:integration`; no actor.

**W-25 Notifications writes and side-effect jobs** · ~350
- Rows: section 2 notification writes.
- Files: `MeNotificationsWriteResource.php`; `bin/notify-unrecorded-courts.php` (runs the court reminder that used to fire on page load, once a day per scope), `bin/clear-expired-suspensions.php` (the sweep that used to run inside the roster read); `class.ApiDataJobs.php` for the job queries.
- Special: the jobs are additive. The legacy read paths keep their side effects until Phase 6 or retirement, so behaviour for the website does not change.

**W-26 Admin writes and award catalogue** · ~300
- Rows: section 19 writes.
- Files: `AdminWriteResource.php`, `AwardCatalogWriteResource.php`; `class.ApiDataAwardCatalog.php` (`create_award`, `update_award`, `delete_award` with a reference check before delete).
- Special: the global-admin grants reuse the shared grants handler (W-08). Admin maintenance writes (table optimisation, log purge, weather cache refresh) are not in v2 (decision E2; catalog section 20), so this task has none.

**W-27 Mapping completeness and parity sweep** · **Opus** · serial, last
- Goal: every v1 method with traffic has a v2 successor or an explicit "not ported" entry.
- Do: query `ork_api_tally` for methods with any calls in the last 60 days; compare with `generated/v1-map.json` and catalog section 20; for each gap either add `x-ork-replaces` to the right operation, or add a row to section 20 with a reason, or raise a new endpoint proposal to the user.
- Output: `docs/api-v2/plan/parity-report.md` (counts only, no sensitive detail) and updated attributes.
- Accept: zero unexplained methods.

## 4. Opus wave review checklist (in addition to Phase 2 section 4)

1. No write route trusts an actor, viewer or privilege field from the body.
2. Every route with a cross-tenant risk has the negative test and it asserts no row changed.
3. Flat versus nested status handling verified against the domain source for each call.
4. Idempotency and `If-Match` markers match the catalog.
5. Destructive routes (merge, clear results, delete) are idempotency-required or confirm-gated and audited.
6. Upload routes: size, MIME sniffing, no URL fetch.
7. No handler performs multi-step domain orchestration; such sequences live in an `ApiData*` method.
8. New migrations classified; drift check clean.
