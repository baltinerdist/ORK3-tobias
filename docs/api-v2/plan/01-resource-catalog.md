# ORK API v2 — Resource Catalog

Base path `/api/v2`. Paths in the tables omit the version: the OpenAPI path is `/v2` + the table path (`/players/{player_id}` is `/v2/players/{player_id}` in the spec, with `servers[0].url` = `https://ork.amtgard.com/api`). This file is the contract the fan-out tasks implement. A task may not add, rename or re-scope an endpoint without the orchestrator updating this file first.

## 0. How to read the tables

- **Scope**: the key scope the route requires (`-` means `public`, no key needed).
- **Policy**: evaluated by `PolicyEngine` before the handler. Vocabulary (defined in `02-phase-1-foundation.md` section 3.6):

| Policy | Meaning |
|---|---|
| `public` | no credentials required |
| `key` | any valid app key; no actor needed (person-level public data). When the route names a player, a restricted player follows the website's logged-out rule (404 where the site hides them). A publishable key is extractable, so treat `key` data as public in exposure terms |
| `authenticated` | a valid actor |
| `self(p)` | actor is player `p`; `p` may be a fact reference such as `fact attendance.player_id` (the owner of the row in the path, resolved through `ApiFacts`; Phase 1 section 3.6) |
| `self_or_officer(p)` | actor is `p`, or has edit authority over `p`'s home park or kingdom, or is ORK admin |
| `player.officer(p, edit\|create)` | park-level authority of that role over `p`'s home park (cascades to kingdom and admin) |
| `park(id, role)` / `kingdom(id, role)` / `event(id, role)` / `unit(id, role)` | `AuthorizationGate::check` on that scope; role is `edit`, `create` or `admin` |
| `org(type, id, role)` | the same, for routes where the scope type is a parameter |
| `unit.officer(id)` | `HasUnitOfficerAuthority` |
| `event.cap(event, occurrence, cap)` | `EventPlanning::CanManageEventDetail` with cap `manage`, `attendance`, `schedule`, `feast`, `create` or `edit` |
| `attendance.scope` | authority over the park, kingdom or event named in the validated body (same rule as `AttendanceAuthority`) |
| `court.manage(court)` | `Court::canManage` on the court's own kingdom and park; child ids (line, note, artisan) are resolved to their court first |
| `court.scope(kingdom, park)` | `Court::canManage` on a scope, for list and create |
| `calendar_item.manage(item)` / `calendar_item.view(item)` | create authority on the item's park or kingdom / `CalendarItem::CanSee` |
| `survey.manage(survey)` | `Survey::canManage` on the row's own scope; child ids resolved to their survey first |
| `survey.create(scope)` / `survey.results(survey)` | `Survey::canCreate` / `Survey::resultsAccess` |
| `qualtest.manage(kingdom)` | `QualTest::canManage`; question, set and attempt ids resolved to their kingdom first |
| `qualtest.attempt(attempt)` | attempt owner or `qualtest.manage` |
| `domain` | actor required; the domain method receives the actor id and enforces its own rule (BonusCredit family, recommendation moderation). The handler must pass the Principal's actor, never a request value. Each `domain` route needs its own entry in H-02's refusal table and a cross-tenant negative test, and its PR quotes the domain check it relies on |
| `link_token` | possession of the capability token in the path |
| `admin` | global ORK admin |

- **Vis** (response visibility tiers used by the schema): `P` public, `A` authenticated, `S` self, `O` officer, `AD` admin. "P; O: x, y" means the object is public and fields x and y are officer tier.
- **Source**: domain method(s) the handler calls. "new query" means a new bound-parameter method in the family's `ApiData*` class, either because none exists or because the legacy one builds SQL from strings, has side effects, or is unbounded.
- `←` lists the v1 methods the operation replaces (becomes `x-ork-replaces`). One v1 method may be replaced by several operations (for example `Player/UpdatePlayer` by the profile PATCH and the waiver PUT); `v1-map.json` then maps it to the list.
- Unbounded collections are cursor-paginated (`pg`). A collection without `pg` must have a hard cap enforced by its query (state it in the description); if the domain method returns an uncapped list, that is a stop condition, not a silent `pg`. Cacheable public reads are marked `cache N` (seconds).
- Draft events, hidden recommendations and hidden calendar items return `404` to callers who may not see them.

**Operation ids** are camelCase, unique, stable once published, and derived mechanically from method and path so that parallel tasks cannot collide: verb + the PascalCase nouns of every non-parameter segment, singular where the segment is followed by an id parameter.

| Method and shape | Verb | Example |
|---|---|---|
| GET collection | `list` | GET `/kingdoms/{kingdom_id}/officers` → `listKingdomOfficers` |
| GET item or singleton | `get` | GET `/players/{player_id}` → `getPlayer`; GET `/me` → `getMe` |
| POST to a collection (creates) | `create` | POST `/courts/{court_id}/lines` → `createCourtLine` |
| PATCH | `update` | PATCH `/parks/{park_id}` → `updatePark` |
| PUT on a state or singleton sub-resource | `set` | PUT `/players/{player_id}/active` → `setPlayerActive` |
| DELETE | `delete` | DELETE `/players/{player_id}/notes/{note_id}` → `deletePlayerNote` |
| POST action segment | the action | POST `/courts/{court_id}/finalize` → `finalizeCourt` |

When the derivation is awkward the task proposes an id in its PR; the orchestrator's wave build fails on duplicates (lint OP-01), never silently renames.

**Path parameter names.** Every path parameter is a `$ref` to one shared component parameter declared in `OpenApi.php` (task F-16), so a name means exactly one thing across the API. The tables below use some shorthand; the canonical names are:

| Shorthand in tables | Canonical parameter | Notes |
|---|---|---|
| `{player_id}`, `{kingdom_id}`, `{park_id}`, `{unit_id}`, `{event_id}`, `{court_id}`, `{line_id}`, `{artisan_id}`, `{milestone_id}`, `{dues_id}`, `{park_day_id}`, `{kingdom_award_id}`, `{award_id}`, `{notification_id}`, `{granter_id}`, `{second_id}`, `{staff_id}` | unchanged | integer ids |
| `{occ}` | `occurrence_id` | `event_calendardetail_id` |
| `{rec_id}` | `recommendation_id` | |
| `{awards_id}` | `player_award_id` | a row of `ork_awards` |
| `{note_id}` under `/players` | `note_id` | under `/courts` it is `court_note_id` |
| `{item_id}` under `…/schedule` | `schedule_item_id` | under `/calendar-items` it is `calendar_item_id` |
| `{member_id}` under `/units` | `unit_member_id` | |
| `{id}` / `{authorization_id}` under any `…/authorizations` and `/admin/global-admins` | `authorization_id` | |
| `{link_id}` | `attendance_link_id` | |
| `{token}` | `link_token` | `token` is a denied parameter name (lint PA-03); capability tokens are not credentials |
| `{id}` under `/surveys`, `{pid}`, `{qid}` under `/survey-questions`, `{iid}` | `survey_id`, `survey_page_id`, `survey_question_id`, `survey_image_id` | |
| `{qid}` under `/qual-questions` and `…/library`, `{set_id}`, `{attempt_id}` | `qual_question_id`, `qual_set_id`, `qual_attempt_id` | |
| `{id}` under `/bonus-credit-categories`, `{category_id}`, `{id}` under `/bonus-credits` | `bonus_credit_category_id`, `bonus_credit_category_id`, `bonus_credit_id` | |
| `{role}`, `{type}`, `{kind}`, `{section}`, `{series}` | unchanged | string enums declared on the shared parameter |
| `{slug}`, `{username}`, `{key_prefix}`, `{week_start}`, `{date}` | unchanged | pattern-bound strings (`{week_start}` and `{date}` are `format: date`) |

**Query parameter names** are shared too: date windows are always `from` and `to` (`format: date`), distances `distance_km`, coordinates `lat`/`lng`, id lists `ids` (comma-separated, `style: form, explode: false`, `maxItems` declared).

**Action responses.** A noun-named action segment that does not create a retrievable record (`/merges`, `/moves`, `/transfers`, `/copies`, `/reconciliations`, `/imports`, `/waiver-resets`, `/stats-resets`, `/batches`, `/revocations`) answers `200` with the outcome (or `202` where stated), not `201`. `201` + `Location` is only for a new addressable resource.

---

## 1. Meta and reference — tasks F-24, R-01

| Method and path | Scope | Policy | Notes |
|---|---|---|---|
| GET `/` | - | public | API root: version, links to docs and spec. cache 300 |
| GET `/ping` | - | public | Liveness; no DB. `no-store` |
| GET `/openapi.json` | account | authenticated | The committed spec file, for any logged-in player (decision U9: a speed bump against drive-by scanning, not a security control; the spec is assumed public knowledge). ETag, never shared-cached, `X-Robots-Tag: noindex`. The explorer loads the same file through the session-gated `Route=ApiDocs/spec` |
| GET `/reference/attendance-classes` | - | public | `Attendance::GetClasses`. cache 3600. ← Attendance/GetClasses |
| GET `/reference/class-levels` | - | public | `ClassLevel` thresholds. cache 86400 |
| GET `/reference/pronouns` | - | public | new query (int-cast ids). cache 86400 |
| GET `/reference/pride-flags` | - | public | `pride_gradients.php`. cache 86400 |
| GET `/reference/schedule-categories` | - | public | `EventPlanning::ScheduleCategories`. cache 86400 |
| GET `/reference/voting-rules` | - | public | `VotingRules::allRules`. cache 3600 |
| GET `/reference/survey-question-types` | - | public | `SurveyTypes` catalogue. cache 3600 |
| GET `/awards` | - | public | Global award catalogue; new query (legacy list query is broken). cache 3600. ← Award/GetAwardList |

## 2. Sessions and the current player — tasks F-24, R-22, W-23, W-25

| Method and path | Scope | Policy | Notes |
|---|---|---|---|
| POST `/sessions` | account | key | Body `username`, `password`, optional `client`. 201 `{token, expires_at, player_id}` with `Location: /api/v2/me/sessions/current` and `Cache-Control: no-store`. Generic failure. Login throttle. `Authorization::Authorize` credential branch. ← Authorization/Authorize |
| GET `/me` | account | authenticated | Player id, persona, home park and kingdom, session expiry, client label, key scopes. Never rotates. ← Authorization/WhoAmI |
| GET `/me/sessions` | account | authenticated | `ListSessionsForToken`. Vis S |
| POST `/me/sessions/current/rotate` | account | authenticated | `RotateSession`; returns the new token once |
| DELETE `/me/sessions/current` | account | authenticated | `DestroySession`. ← Authorization/DestroySession |
| DELETE `/me/sessions` | account | authenticated | `?except=current`; `DestroySessionsForUser` |
| GET `/me/authorizations` | account | authenticated | The actor's own grants. ← Authorization/GetAuthorizations (self use) |
| POST `/me/authorization-checks` | account | authenticated | Body `type`, `id`, `role`; actor from token only. ← AuthorizationGate/HasAuthority |
| PUT `/me/email` | account | authenticated | `Player::SaveOwnEmail` |
| GET `/me/notifications` | account | authenticated | pg. `Notification::GetForUser`, `CountUnread` in `meta.unread`. Pure read |
| POST `/me/notifications/read` | account | authenticated | `MarkAllRead` (explicit, never on GET) |
| DELETE `/me/notifications/{notification_id}` | account | authenticated | `Dismiss` (owner-filtered) |
| DELETE `/me/notifications` | account | authenticated | `DismissAll` |
| GET `/me/rsvps` | account | authenticated | `Event::GetUpcomingRsvps` for the actor. ← Event/GetUpcomingRsvps |
| GET `/me/attendance/last-class` | account | authenticated | `Attendance::GetPlayerLastClass` for the actor |
| GET `/me/dues-notice` | account | authenticated | `DuesNotice::classify` over `GetDuesStanding` |
| GET `/me/surveys/available` | surveys:respond | authenticated | `SurveyResponse::availableFor` |
| ~~POST `/password-resets`~~ | - | - | **Not in v2.0** (decision U17, 2026-11-24; security review). The legacy reset is weak (short temporary password emailed inside a link, sessions left alive); clients send players to the website's reset page. A token-based reset can be added later as a new operation. Listed in section 20 |
| GET `/usernames/{username}/availability` | account | authenticated | `Player::CheckUsernameAvailable`. 30/hour per actor |
| POST `/idp/claims` | idp:integration | key (secret) | `IdpIntegration::BeginClaimOrkMail` |
| POST `/idp/claims/verify` | idp:integration | key (secret) | `IdpIntegration::ValidateClaimOrkCode` |
| GET `/geocode` | account | authenticated | `?address=`. cost 25, 20/day per actor, cached. ← Map/Geocode |

## 3. Players — tasks F-28 (profile, attendance, notes), R-08, R-09, W-01 to W-04

| Method and path | Scope | Policy | Notes |
|---|---|---|---|
| GET `/players` | players:read | key | `?q=` (min 2 chars) `&scope=&kingdom_id=&park_id=&include_inactive=`; limit ≤ 50. `SearchService::ScopedPlayerSearch`. Persona-level output. Real-name and username matching only when the actor is officer or admin. ← SearchService/Player, ScopedPlayerSearch, Search/Player |
| POST `/players` | players:write | park(body.park_id, create) | `Player::CreatePlayer`. Idempotency required. ← Player/CreatePlayer |
| GET `/players/{player_id}` | players:read | key | `GetPlayer` + `GetPlayerProfileDetails`. Vis P: id, persona, home park and kingdom, active, heraldry and image URLs, about fields. Rule `player.real_name`: given name, surname. O/S: other name, email, waiver flag, restricted, suspension detail. Never: username to non-officers, password metadata, a waiver image URL (any tier). ← Player/GetPlayer |
| PATCH `/players/{player_id}` | players:write | self_or_officer | Profile fields. Each writable property declares `x-ork-writable: self\|officer\|admin`; a field above the actor's tier is 403. `UpdatePlayer` (profile path only) |
| PUT `/players/{player_id}/credentials` | players:write | self_or_officer | Username or password. Self must send `current_password`. Login throttle bucket |
| PUT `/players/{player_id}/active` | players:write | player.officer(edit) | `Report::SetPlayerActiveStatus` |
| PUT `/players/{player_id}/restriction` | players:write | player.officer(edit) | `SetRestriction` |
| PUT `/players/{player_id}/suspension` | players:write | kingdom(player's kingdom, edit) | `SetPlayerSuspension`; the suspending actor is the Principal |
| PUT `/players/{player_id}/ban` | admin:write | admin | `SetBan` |
| PUT `/players/{player_id}/waiver` | players:write | player.officer(edit) | `SetWaiver`; multipart for the image |
| POST `/players/{player_id}/merges` | players:write | admin, or officer of both players | Body `from_player_id`. Idempotency required. `MergePlayer` |
| POST `/players/{player_id}/moves` | players:write | park(source, create) and park(target, create) | Body `park_id`. `MovePlayer` |
| GET `/players/{player_id}/attendance` | attendance:read | key | pg. new query (keyset on date, id). Vis P: date, park, kingdom, event, class, credits, online. O: note, entered by, entry method. ← Player/AttendanceForPlayer, GetPlayerAttendanceList |
| GET `/players/{player_id}/awards` | players:read | key | pg. new query. Vis P incl. note (shown on the public profile). O: revocation fields. ← Player/AwardsForPlayer, Search/PlayerAward |
| GET `/players/{player_id}/awards/revoked` | players:sensitive | self_or_officer | `GetRevokedAwardsForPlayer` |
| POST `/players/{player_id}/awards` | awards:write | player.officer(create) | `AddAward`. Read the FLAT status. Idempotency required. ← Player/AddAward |
| PATCH `/players/{player_id}/awards/{awards_id}` | awards:write | player.officer(create) | `UpdateAward` |
| DELETE `/players/{player_id}/awards/{awards_id}` | awards:write | player.officer(create) | `RemoveAward` |
| PUT `/players/{player_id}/awards/{awards_id}/revocation` | awards:write | player.officer(create) | `RevokeAward`; DELETE = `ReactivateAward` |
| POST `/players/{player_id}/awards/revocations` | awards:write | player.officer(edit) | `RevokeAllAwards` |
| PUT `/players/{player_id}/awards/{awards_id}/reconciliation` | awards:write | player.officer(edit) | `ReconcileAward` |
| GET `/players/{player_id}/awards/reconciliation` | awards:write | player.officer(edit) | `GetReconcilePageData` |
| GET `/players/{player_id}/classes` | players:read | key | `GetPlayerClasses`. cache 60 (keyless not allowed). ← Player/GetPlayerClasses |
| PUT `/players/{player_id}/classes/reconciled-credits` | players:write | player.officer(edit) | `SetPlayerReconciledCredits` |
| GET `/players/{player_id}/milestones` | players:read | key | `GetPlayerMilestones` + `GetCustomMilestones`. ← Player/GetPlayerMilestones |
| POST/PATCH/DELETE `/players/{player_id}/milestones[/{milestone_id}]` | players:write | self(player_id) | Custom milestones |
| GET `/players/{player_id}/ladder-progress` | players:read | key | `GetLadderProgress` |
| GET `/players/{player_id}/officer-roles` | players:sensitive | self_or_officer | `GetOfficerRoles` |
| GET `/players/{player_id}/beltline` | players:read | authenticated | `GetBeltlineForPlayer` |
| GET `/players/{player_id}/voting-eligibility` | players:read | key | `?kingdom_id=`. `Report::GetVotingEligibleForPlayer` (badge fields only) |
| GET `/players/{player_id}/authorizations` | players:sensitive | self_or_officer | new query. ← Authorization/GetAuthorizations (other players) |
| GET `/players/{player_id}/notes` | players:sensitive | player.officer(edit) | Vis O. `Player::GetNotes` |
| POST `/players/{player_id}/notes` | players:sensitive | player.officer(edit) | `AddNote` |
| PATCH/DELETE `/players/{player_id}/notes/{note_id}` | players:sensitive | player.officer(edit) | `EditNote` / `RemoveNote`; the note must belong to the player |
| DELETE `/players/{player_id}/notes` | players:sensitive | player.officer(edit) | `ClearNotes` |
| GET `/players/{player_id}/dues` | players:sensitive | self_or_officer | new query (bound). Vis S/O |
| GET `/players/{player_id}/dues/standing` | players:sensitive | self_or_officer | `GetDuesStanding` |
| POST `/players/{player_id}/dues` | dues:write | player.officer(edit) | `AddDues`. Idempotency required |
| PUT `/players/{player_id}/dues/{dues_id}/revocation` | dues:write | player.officer(edit) | `RevokeDues` |
| GET `/players/{player_id}/dietary-preferences` | players:sensitive | self(player_id) | `GetDietaryPreferences` |
| PUT `/players/{player_id}/dietary-preferences` | players:write | self(player_id) | `SaveDietaryPreferences` with the actor's id |
| POST `/parks/{park_id}/self-registration-links` | players:write | park(create) | `CreateSelfRegLink` |
| GET `/self-registration-links/{token}` | - | link_token | `ValidateSelfRegLink` |
| POST `/self-registration-links/{token}/registrations` | - | link_token | `SelfRegister`. 5/hour per IP. Idempotency required. Does not return a session; the client logs in |

## 4. Kingdoms and principalities — tasks R-02, W-06, W-08

A principality is a kingdom with `parent_kingdom_id`. There is no separate resource.

| Method and path | Scope | Policy | Notes |
|---|---|---|---|
| GET `/kingdoms` | - | public | `?q=&active=`. `Kingdom::GetKingdoms`. cache 300. ← Kingdom/GetKingdoms, Search/Kingdom |
| POST `/kingdoms` | admin:write | admin | `CreateKingdom`; `parent_kingdom_id` makes a principality (parent set checked) |
| GET `/kingdoms/{kingdom_id}` | - | public | Short info + details. Configuration limited to an allow-list of public keys. cache 300. ← Kingdom/GetKingdomShortInfo, GetKingdomDetails |
| PATCH `/kingdoms/{kingdom_id}` | org:write | kingdom(edit) | `SetKingdomDetails` |
| PUT `/kingdoms/{kingdom_id}/parent` | admin:write | admin | `SetKingdomParent` |
| PUT `/kingdoms/{kingdom_id}/active` | admin:write | admin | Body `active: bool`. `RetireKingdom` / `RestoreKingdom` |
| GET `/kingdoms/{kingdom_id}/configuration` | org:write | kingdom(edit) | Full configuration |
| PATCH `/kingdoms/{kingdom_id}/configuration` | org:write | kingdom(edit) | Body keyed by configuration *key name* from a documented allow-list; no client-supplied row ids. Busts only that kingdom's cache keys |
| GET `/kingdoms/{kingdom_id}/principalities` | - | public | `GetPrincipalities`. ← Kingdom/GetPrincipalities |
| GET `/kingdoms/{kingdom_id}/parks` | - | public | `GetParks`. cache 300. ← Kingdom/GetParks |
| GET/PUT `/kingdoms/{kingdom_id}/park-titles` | - / org:write | public / kingdom(edit) | `GetKingdomParkTitles` / `SetKingdomParkTitles` |
| GET `/kingdoms/{kingdom_id}/officers` | - | public | Vis P: role, player id, persona. O: given name, surname, email. Never username. ← Kingdom/GetOfficers |
| PUT/DELETE `/kingdoms/{kingdom_id}/officers/{role}` | org:write | kingdom(edit) | `SetOfficer` / `VacateOfficer`; role from an enum |
| GET `/kingdoms/{kingdom_id}/authorizations` | org:write | kingdom(create) | new query. Vis O. ← Kingdom/GetKingdomAuthorizations |
| POST/DELETE `/kingdoms/{kingdom_id}/authorizations[/{authorization_id}]` | org:write | kingdom(create) | Shared grants handler (W-08); writes the audit row in the domain call |
| GET `/kingdoms/{kingdom_id}/awards` | - | public | Kingdom award catalogue; new query. cache 300. ← Kingdom/GetAwardList |
| POST/PATCH/DELETE `/kingdoms/{kingdom_id}/awards[/{kingdom_award_id}]` | org:write | kingdom(create) | `Kingdom::CreateAward/EditAward/RemoveAward` |
| GET `/kingdoms/{kingdom_id}/award-options` | - | public | `Award::GetAwardOptionGroups` (data, not HTML). cache 300 |
| GET `/kingdoms/{kingdom_id}/players` | reports:read | key | pg. Roster; new query, no write on read. Vis P: id, persona, park, last sign-in, officer roles. rule `player.real_name` for names. ← Report/GetPlayerRoster |
| GET `/kingdoms/{kingdom_id}/events` | - | public | pg by window. Published only unless the actor can manage |
| GET `/kingdoms/{kingdom_id}/calendar` | - | public | `?from=&to=`. Events + calendar items; item visibility from the actor. `GetKingdomCalendarFeed` with Principal-derived arguments |
| GET `/kingdoms/{kingdom_id}/events.ics` | - | public | `text/calendar`, published only (new query), ETag, cache 900 |
| GET `/kingdoms/{kingdom_id}/voting-rules` | - | public | `VotingRules::rulesForKingdom` |
| GET `/kingdoms/{kingdom_id}/event-templates` | events:write | authenticated | `GetEventTemplatesForKingdom` |
| PUT `/kingdoms/{kingdom_id}/recommendation-visibility` | org:write | kingdom(edit) | `SetAwardRecsPublic` |
| POST `/kingdoms/{kingdom_id}/waiver-resets` | players:write | kingdom(edit) | `Player::ResetWaivers` |

## 5. Parks and map — tasks R-03, W-07, W-08

| Method and path | Scope | Policy | Notes |
|---|---|---|---|
| GET `/parks` | - | public | `?q=&kingdom_id=&exclude_kingdom_id=`. `SearchService::Park`. ← Search/Park |
| GET `/parks/nearby` | - | public | `?lat=&lng=&distance_km=&from=&to=`. new query with result cache 300. cost 5. ← Park/PlayAmtgard |
| GET `/map/parks` | - | public | `?kingdom_id=`. `Map::GetParkLocations`. cache 300 |
| POST `/parks` | org:write | kingdom(body.kingdom_id, create) | `CreatePark` |
| GET `/parks/{park_id}` | - | public | Short info + details (meeting place data is public on the site). cache 300. ← Park/GetParkShortInfo, GetParkDetails |
| PATCH `/parks/{park_id}` | org:write | park(edit) | `SetParkDetails` |
| PUT `/parks/{park_id}/active` | org:write | kingdom(park's kingdom, edit) | `RetirePark` / `RestorePark` |
| POST `/parks/{park_id}/merges` | admin:write | admin | `MergeParks`. Idempotency required |
| POST `/parks/{park_id}/transfers` | admin:write | admin | `TransferPark` |
| GET `/parks/{park_id}/days` | - | public | `GetParkDays`. cache 300. ← Park/GetParkDays |
| POST/PATCH/DELETE `/parks/{park_id}/days[/{park_day_id}]` | org:write | park(edit) | `AddParkDay/EditParkDay/RemoveParkDay` |
| GET `/parks/{park_id}/officers` | - | public | As kingdom officers. ← Park/GetOfficers |
| PUT/DELETE `/parks/{park_id}/officers/{role}` | org:write | park(edit) | `SetOfficer` / `VacateOfficer` |
| GET/POST/DELETE `/parks/{park_id}/authorizations[/{id}]` | org:write | park(create) | Shared grants handler. ← Park/GetParkAuthorizations |
| GET `/parks/{park_id}/players` | reports:read | key | pg. Roster as kingdoms. ← Report/GetPlayerRoster |
| GET `/parks/{park_id}/events` | - | public | Published only unless manager |
| GET `/parks/{park_id}/calendar` | - | public | As kingdom calendar |
| POST `/parks/{park_id}/waiver-resets` | players:write | park(edit) | `ResetWaivers` |

## 6. Units — tasks R-04, W-09

| Method and path | Scope | Policy | Notes |
|---|---|---|---|
| GET `/units` | - | public | pg. `?q=&kingdom_id=&park_id=`. ← Search/Unit |
| GET `/units/activity` | - | public | `?ids=` (≤ 25). `GetUnitActivityCounts`. cache 300 |
| POST `/units` | org:write | admin | `CreateUnit` |
| GET `/units/{unit_id}` | - | public | `GetUnit`. ← Unit/GetUnit |
| PATCH `/units/{unit_id}` | org:write | unit(create) | `SetUnit` |
| PUT `/units/{unit_id}/retirement` | org:write | unit(create) | No body. `RetireUnit`. (Split from a single `active` toggle so each operation has one static policy) |
| DELETE `/units/{unit_id}/retirement` | org:write | unit.officer | `RestoreUnit` |
| PUT `/units/{unit_id}/type` | org:write | unit(create) | `household` or `company` |
| GET `/units/{unit_id}/members` | - | public | Persona-level |
| POST `/units/{unit_id}/members` | org:write | unit(create) | `AddMember` |
| PATCH/DELETE `/units/{unit_id}/members/{member_id}` | org:write | unit(create) | `SetMember`, `RetireMember`, `RemoveMember` |
| POST `/units/{unit_id}/claims` | org:write | authenticated | `ClaimUnit` (domain checks leader role) |
| PUT `/units/{unit_id}/owner` | org:write | unit(create) | `TransferOwnership` |
| POST `/units/{unit_id}/merges` | org:write | unit(create) on both | `MergeUnits`. Idempotency required |
| GET/POST/DELETE `/units/{unit_id}/authorizations[/{id}]` | org:write | unit(create) | Shared grants handler |

## 7. Events, occurrences, schedule, staff, RSVPs — tasks R-05, W-10, W-11, W-12

`{occ}` is the occurrence id (`event_calendardetail_id`). Every route under an event first checks the occurrence belongs to the event.

| Method and path | Scope | Policy | Notes |
|---|---|---|---|
| GET `/events` | - | public | pg. `?q=&kingdom_id=&park_id=&unit_id=&from=&to=`. new query. Drafts only for actors who can manage them; there is no draft flag. ← SearchService/Event, Event/GetEvents |
| GET `/events/nearby` | - | authenticated | `Event::PlayAmtgard`. cost 5 |
| GET `/events/copy-sources` | events:write | org(scope from query, create) | `ListCopySourceEvents`, drafts filtered |
| POST `/events` | events:write | org(owner scope, create); personal events: self; unit events: unit(create) | `CreateEvent`, or `CreateEventWithCopy` when `copy_from` is present. Idempotency required |
| GET `/events/{event_id}` | - | public | Draft → 404 unless manager. Creator id is O. ← Event/GetEvent |
| PATCH `/events/{event_id}` | events:write | event(edit) | `SetEvent` |
| DELETE `/events/{event_id}` | events:write | event(create) | `DeleteEvent` |
| PUT `/events/{event_id}/status` | events:write | event.cap(manage) | `draft` or `published`. `SetEventStatus` |
| GET `/events/{event_id}/occurrences` | - | public | `GetEventDetails` behind the draft rule. cache 60. ← Event/GetEventDetails |
| POST `/events/{event_id}/occurrences` | events:write | event(create) | `CreateEventDetails` |
| GET `/occurrences/{occ}` | - | public | Lookup by occurrence id. ← Event/GetEventDetail, Search/CalendarDetail |
| GET `/events/{event_id}/occurrences/{occ}` | - | public | Page bundle (`GetOccurrencePageData` with Principal-derived viewer). Staff list: role and persona P; capability flags O |
| PATCH `/events/{event_id}/occurrences/{occ}` | events:write | event.cap(manage) | `SetEventDetails`, fees, links, type |
| DELETE `/events/{event_id}/occurrences/{occ}` | events:write | event(create) | `DeleteEventDetail` |
| PUT `/events/{event_id}/occurrences/{occ}/current` | events:write | event(create) | `SetCurrent` |
| GET `…/occurrences/{occ}/schedule` | - | public | Published events only; staff see the manage view. ETag per item |
| POST `…/schedule` | events:write | event.cap(schedule or feast) | `AddEventSchedule`. Idempotency → request token |
| PATCH/DELETE `…/schedule/{item_id}` | events:write | event.cap(schedule or feast) | `If-Match` required (item modified time) |
| POST `…/schedule/batches` | events:write | event.cap(schedule) | `ApplyScheduleOps`. Idempotency required → batch token |
| GET `…/schedule/copy-sources` | events:write | event.cap(schedule) | `ListScheduleCopySources` |
| POST `…/schedule/copies` | events:write | event.cap(schedule) | `CopyScheduleInto`. Idempotency required → request token |
| GET `/events/{event_id}/embed` | - | public | `EventEmbed::GetPublishedScheduleEmbed`. `Access-Control-Allow-Origin: *`. cache 300 |
| GET `…/occurrences/{occ}/staff` | - | public | Role and persona P; flags O |
| POST `…/staff`, DELETE `…/staff/{staff_id}` | events:write | event.cap(create) | `AddEventStaff` / `RemoveEventStaff` |
| GET `/occurrences/rsvp-counts` | - | public | `?ids=` (≤ 100). `GetRsvpCountsBatch`. cache 60 |
| GET `…/occurrences/{occ}/rsvps` | events:write | event.cap(manage or attendance) | Named list incl. waiver flag. `GetRsvpList` |
| PUT/DELETE `…/occurrences/{occ}/rsvps/me` | rsvps:write | authenticated | `SetRsvp` / `WithdrawRsvp` for the actor. The response includes the actor's status and counts |
| DELETE `…/occurrences/{occ}/rsvps/{player_id}` | events:write | event.cap(manage or attendance) | `RemoveRsvp` |
| GET `…/occurrences/{occ}/dietary-summary` | events:write | event.cap(feast) | `GetDietarySummaryForOccurrence`; rows flagged anonymous lose player id and persona |
| GET `…/occurrences/{occ}/attendance` | attendance:read | key | `Report::AttendanceForEvent`. ← Report/AttendanceForEvent |
| POST `…/occurrences/{occ}/attendance` | attendance:write | event.cap(attendance) | Add attendance at the event |
| POST `…/occurrences/{occ}/attendance/reconciliations` | attendance:write | event(create) | `ReconcilePastAttendance`. Idempotency required |
| GET/POST/DELETE `/events/{event_id}/authorizations[/{id}]` | events:write | event(create) | Shared grants handler |

## 8. Calendar and calendar items — tasks R-06, W-13

| Method and path | Scope | Policy | Notes |
|---|---|---|---|
| GET `/calendar` | - | public | `?from=&to=` (max 366 days) `&kingdom_id=&park_id=`. new query, bound dates, published only. cache 300. ← Calendar/Next |
| GET `/calendar-items/{item_id}` | - | calendar_item.view | 404 when hidden |
| POST `/calendar-items` | events:write | org(body scope, create) | `CreateCalendarItem` |
| PATCH/DELETE `/calendar-items/{item_id}` | events:write | calendar_item.manage | `UpdateCalendarItem` / `DeleteCalendarItem` |

## 9. Attendance — tasks R-10, W-05

| Method and path | Scope | Policy | Notes |
|---|---|---|---|
| GET `/parks/{park_id}/attendance` | attendance:read | key | `?date=`. `Report::AttendanceForDate`. O: note. ← Report/AttendanceForDate |
| GET `/parks/{park_id}/attendance/dates` | - | public | `Report::GetAttendanceDates` |
| GET `/parks/{park_id}/attendance/adjacent-dates` | - | public | `?date=`. `GetAdjacentParkDates` |
| GET `/parks/{park_id}/attendance/recent-attendees` | attendance:read | key | `RecentParkAttendees`. ← Report/RecentParkAttendees |
| GET `/parks/{park_id}/attendance/field-count` | - | public | `GetParkFieldCountToday`. cache 60 |
| GET `/parks/{park_id}/attendance/averages` | - | public | `?type=`. cache 600 |
| GET `/parks/{park_id}/day-type` | - | public | `?date=`. `GetParkDayTypeForDate` |
| POST `/attendance` | attendance:write | attendance.scope | `AddAttendance`. Idempotency required. ← Attendance/AddAttendance |
| PATCH `/attendance/{attendance_id}` | attendance:write | attendance.scope (of the row) | `SetAttendance` |
| DELETE `/attendance/{attendance_id}` | attendance:write | attendance.scope (of the row) | `RemoveAttendance`. ← Attendance/RemoveAttendance |
| GET `/attendance-links` | attendance:write | org(scope from query, edit) or event staff | `GetAttendanceLinks` |
| POST `/attendance-links` | attendance:write | org(body scope, edit) or event staff | `CreateAttendanceLink` |
| DELETE `/attendance-links/{link_id}` | attendance:write | as create, with the scope taken from the link row (`child_scope('attendance_link')`), never from the request | `DeleteAttendanceLink` |
| GET `/attendance-links/by-token/{token}` | - | link_token | `GetAttendanceLinkInfo` |
| POST `/attendance-links/by-token/{token}/sign-ins` | attendance:write | authenticated | `UseAttendanceLink` for the actor |
| GET `/attendance-links/by-token/{token}/sign-ins/me` | attendance:read | authenticated | `GetExistingSignin` for the actor only |
| PATCH `/me/attendance/{attendance_id}` | attendance:write | self(fact attendance.player_id) | `UpdateSelfSigninClass`; the ownership check is the policy's fact reference (404 when the row is not the actor's), not handler code |

## 10. Recommendations — tasks R-15, W-15

Viewer is always the Principal. `RecommendationVisibility` filters every list and lookup.

| Method and path | Scope | Policy | Notes |
|---|---|---|---|
| GET `/recommendations` | recommendations:read | authenticated (public when the kingdom has made recommendations public) | pg. `?kingdom_id=\|park_id=\|player_id=&include_dismissed=`. `PlayerAwardRecommendationsPage`. ← Report/PlayerAwardRecommendations |
| GET `/recommendations/count` | recommendations:read | authenticated | `PlayerAwardRecommendationsCount` |
| GET `/recommendations/deleted` | recommendations:read | org(scope, create) | `DeletedAwardRecommendations` |
| GET `/recommendations/peers` | recommendations:read | authenticated | `GetPeerAwardRecommendations` |
| GET `/recommendations/export.csv` | recommendations:read | court.scope | CSV stream; formula-prefix cells escaped |
| POST `/recommendations` | recommendations:write | authenticated | `AddAwardRecommendation`; level capped by the domain |
| GET `/recommendations/{rec_id}` | recommendations:read | authenticated | 404 when hidden |
| PATCH `/recommendations/{rec_id}` | recommendations:write | domain | Reason; author only |
| DELETE `/recommendations/{rec_id}` | recommendations:write | domain | Soft delete |
| POST `/recommendations/{rec_id}/restore` | recommendations:write | domain | |
| PUT/DELETE `/recommendations/{rec_id}/snooze` | recommendations:write | domain | |
| PUT `/recommendations/{rec_id}/visibility` | recommendations:write | domain | `SetRecommendationMonarchyOnly` |
| POST `/recommendations/{rec_id}/pass-to-local` | recommendations:write | domain | |
| GET `/recommendations/{rec_id}/seconds` | recommendations:read | authenticated | Only when the actor can see the recommendation |
| POST `/recommendations/{rec_id}/seconds` | recommendations:write | authenticated | |
| PATCH/DELETE `/recommendations/{rec_id}/seconds/{second_id}` | recommendations:write | domain | |
| POST `/recommendations/batches` | recommendations:write | court.scope | Per-id results |
| POST `/recommendations/cluster-resolutions` | recommendations:write | org(recipient scope, create) | `ResolveRecommendationCluster` |

## 11. Courts — tasks R-16, W-16, W-17

| Method and path | Scope | Policy | Notes |
|---|---|---|---|
| GET `/courts` | courts:read | court.scope | `?kingdom_id=&park_id=&include_park_courts=`. Pure read |
| GET `/courts/unrecorded`, `/courts/stalled` | courts:read | court.scope | Pure reads; the reminder notifications move to a scheduled job |
| POST `/courts` | courts:write | court.scope | `createCourt` |
| GET `/courts/{court_id}` | courts:read | court.manage | Court + lines + notes; hidden recommendation text masked for the actor |
| PATCH `/courts/{court_id}` | courts:write | court.manage | `updateCourt` |
| PUT `/courts/{court_id}/status` | courts:write | court.manage | `draft` or `published`; `complete` only through finalize |
| PUT `/courts/{court_id}/mode` | courts:write | court.manage | `run` or `plan` |
| POST `/courts/{court_id}/printed` | courts:write | court.manage | |
| GET `/courts/{court_id}/state` | courts:read | court.manage | ETag = state hash; `If-None-Match` → 304. Pure read |
| PUT `/courts/{court_id}/presence` | courts:write | court.manage | Heartbeat for the multi-manager roster (was a side effect of the poll) |
| GET/POST `/courts/{court_id}/lines` | courts:read / courts:write | court.manage | Each line carries its version in the body as `etag` (`"rv-<n>"`, the exact value a client sends in `If-Match`); a single-line response also sends it as the `ETag` header |
| PATCH/DELETE `/courts/{court_id}/lines/{line_id}` | courts:write | court.manage | `If-Match` required → 412 when stale |
| PUT `…/lines/{line_id}/status` | courts:write | court.manage | `If-Match` required |
| PUT `/courts/{court_id}/lines/order` | courts:write | court.manage | |
| PUT `…/lines/{line_id}/tracking/{kind}` | courts:write | court.manage | `kind` = scroll or regalia; body `status` 0, 1 or 2 (explicit value; replaces the cycling toggle; new domain method) |
| POST `…/lines/{line_id}/stage`, DELETE `…/stage` | courts:write | court.manage | `If-Match` required |
| POST `…/lines/{line_id}/skip` | courts:write | court.manage | `If-Match` required |
| POST `…/lines/{line_id}/pass-to-local` | courts:write | court.manage | |
| POST/DELETE `…/lines/{line_id}/artisans[/{artisan_id}]` | courts:write | court.manage | |
| GET/POST/PATCH/DELETE `/courts/{court_id}/notes[/{note_id}]` | courts:write | court.manage | |
| POST `/courts/{court_id}/staging/bulk` | courts:write | court.manage | |
| POST `/courts/{court_id}/prepopulations` | courts:write | court.manage | |
| POST `/courts/{court_id}/finalize` | courts:write | court.manage | Idempotency required. 200 with per-line `ok`, `noop`, `duplicate` or `error` and `completed`. Orchestration in the domain (`ApiDataCourts::finalize_court`) |
| GET `/court-reports` | - | public | Completed courts only. cache 300 |
| GET `/court-reports/{court_id}` | - | public | Given, non-revoked awards; hidden citations suppressed |

## 12. Heraldry, banners, images — tasks R-22, W-14

`{entity}` is shorthand, not a path template. Each row below is published as five concrete paths, one per entity, with the entity's own id parameter and its own operation id (`/players/{player_id}/heraldry` → `getPlayerHeraldry`, `/parks/{park_id}/heraldry` → `getParkHeraldry`, and so on), all routed to one shared handler method per row. A templated first segment would collide with every other `/players/…` route in the router and gives code generators an untyped `entity` argument. The entity edit authority in the policy column is, per entity: players `any[self, player.officer(edit)]`, parks `park(edit)`, kingdoms `kingdom(edit)`, units `unit(create)`, events `event(edit)`.

| Method and path | Scope | Policy | Notes |
|---|---|---|---|
| GET `/{entity}/{id}/heraldry` | - | public | `{has_heraldry, url}`. ← Heraldry/GetHeraldryUrl |
| PUT `/{entity}/{id}/heraldry` | media:write | entity edit authority (self for players) | multipart `file`, 465 kB cap, MIME sniffed. No URL input |
| DELETE `/{entity}/{id}/heraldry` | media:write | as PUT | |
| PUT `/{entity}/{id}/banner` | media:write | `Banner::canEditBanner` rule | multipart, 1 MiB |
| PATCH `/{entity}/{id}/banner` | media:write | as PUT | offsets, logo, vignette |
| DELETE `/{entity}/{id}/banner` | media:write | as PUT | |
| POST `/{entity}/{id}/banner/copies` | media:write | edit on source and target | |
| PUT/DELETE `/players/{player_id}/image` | media:write | player.officer(edit) or self | ← Player/SetImage |

## 13. Reports, recap, explorers — tasks R-11 to R-14, R-20

Public aggregates (`-`, `public`, cached 600 unless noted). Each maps to the `Report` method of the same name.

`GET /reports/active-kingdoms` · `/reports/top-parks` · `/reports/kingdoms/{kingdom_id}/park-averages` · `/park-monthly-averages` · `/extended-park-averages` · `/reports/distinct-player-stats` · `/reports/monthly-chart` · `/reports/attendance-summary` · `/reports/event-attendance` · `/reports/park-attendance` · `/reports/new-player-attendance` · `/reports/class-masters` · `/reports/crown-qualified` · `/reports/guilds` · `/reports/heraldry` · `/reports/reeve-qualified` · `/reports/corpora-qualified` · `/reports/closest-parks` · `/reports/unit-summary` · `/reports/player-awards` (pg) · `/reports/custom-awards` · `/reports/beltline` · `/reports/tournaments`

← Report/Guilds, UnitSummary, GetKingdomParkAverages, GetActiveKingdomsSummary, GetTopParksByAttendance, ClassMasters and the rest by name.

| Method and path | Scope | Policy | Notes |
|---|---|---|---|
| GET `/reports/active-players` | reports:read | key | Persona-level. O: dues and waiver flags. cost 5. ← Report/GetActivePlayers |
| GET `/reports/park-distance-matrix` | reports:read | authenticated | cost 25 |
| GET `/reports/rosters/authorizations` | reports:read | org(scope, edit) | |
| GET `/reports/rosters/dues-paid` | reports:read | org(scope, edit) | `ork_dues` source |
| GET `/reports/officer-directory` | reports:read | key | Roles and personas P; names and emails O/AD |
| GET `/reports/voting-eligible` | reports:read | org(scope, edit) | cost 5 |
| GET `/reports/player-status-reconciliation` | reports:read | org(scope, edit) | |
| GET `/reports/ladder-grid` | reports:read | authenticated | |
| GET `/recap/weeks`, `/recap/{week_start}`, `/recap/{week_start}/kingdoms[/{kingdom_id}]`, `/recap/trends/{series}` | - | public | Stored recap only. cache 900. Writers are jobs, not endpoints |
| GET `/reports/population/registry` | explorers:run | authenticated | Restricted criteria only for scope officers |
| POST `/reports/population/query` | explorers:run | authenticated | cost 25; single-flight lock → 429; timeout → 503. Dues and waiver columns O |
| POST `/reports/population/exports` | explorers:run | authenticated | `.xlsx` stream |
| GET `/reports/awards/registry`, POST `/reports/awards/query` | explorers:run | authenticated | cost 25; same limits |
| GET `/reports/state-of-amtgard/bootstrap`, `/reports/state-of-amtgard/{section}` | reports:read | authenticated | 12-month range cap. cost 5 |

## 14. Search — task R-08

| Method and path | Scope | Policy | Notes |
|---|---|---|---|
| GET `/search` | - | public | `?q=&focus=&kingdom_id=&park_id=&include_inactive=`. `UniversalSearch` with the caller id taken from the Principal. Persona-level |
| GET `/search/locations` | - | public | `?q=&date=`. `SearchService::Location` |

Entity search lives on the collections: `/players?q=`, `/parks?q=`, `/kingdoms?q=`, `/units?q=`, `/events?q=`.

## 15. Weather, Era Phoenice, Live — task R-07

| Method and path | Scope | Policy | Notes |
|---|---|---|---|
| GET `/weather/summary`, `/weather/play`, `/weather/upcoming-events`, `/weather/freshness`, `/weather/severities` | - | public | Cache-only reads. Upcoming events filtered to published. cache 300 |
| GET `/parks/{park_id}/weather` | - | public | `?date=`. Cache-only read |
| GET `/parks/{park_id}/weather/archive` | attendance:read | authenticated | May fetch upstream. cost 5 |
| GET `/weather/archive` | attendance:read | authenticated | `?lat=&lng=&date=`; coordinates rounded to 2 decimals for caching. cost 25, daily cap |
| GET `/era-phoenice/today`, `/era-phoenice/dates/{date}`, `/era-phoenice/holidays` | - | public | cache 300 / 86400 |
| GET `/live/stats`, `/live/recent` | - | public | cache 30 / 10 |

## 16. Surveys — tasks R-17, W-18, W-19

Paths as proposed in inventory section 07, with these fixed rules: every `{survey_id}`, page, question and image id is resolved to its survey and checked with `survey.manage`; respondent routes use `authenticated` and the domain's eligibility; results use `survey.results`, which returns the lens the report must apply.

| Group | Routes | Scope | Policy |
|---|---|---|---|
| Definition | GET/POST `/surveys`, GET/PATCH/DELETE `/surveys/{id}`, POST `/surveys/{id}/clone`, PUT `/surveys/{id}/status`, DELETE `/surveys/{id}/responses` (`?dry_run=`), GET `/survey-scopes`, GET `/surveys/{id}/event-options`, GET `/surveys/{id}/activity` | surveys:read / surveys:write | survey.create or survey.manage |
| Structure | POST `/surveys/{id}/pages`, PUT `/surveys/{id}/pages/order`, PATCH/DELETE `/survey-pages/{pid}`, POST `/survey-pages/{pid}/questions`, PUT `/survey-pages/{pid}/questions/order`, PATCH/DELETE `/survey-questions/{qid}`, POST `/survey-questions/{qid}/duplicate`, POST `/survey-questions/{qid}/moves`, PUT `/survey-questions/{qid}/options/{role}`, POST `/surveys/{id}/images` (multipart), DELETE `/survey-images/{iid}`, POST `/survey-markdown-previews` | surveys:write | survey.manage |
| Link preview | GET `/surveys/by-slug/{slug}/preview` | - | public (title, audience, credit, close date only) |
| Respondent | GET `/surveys/{id}/definition` (pure read), POST `/surveys/{id}/starts` (records the start marker), GET `/surveys/{id}/eligibility`, PUT `/surveys/{id}/draft`, POST `/surveys/{id}/responses` (Idempotency required), PUT `/surveys/{id}/responses/mine` | surveys:respond | authenticated |
| Results | GET `/surveys/{id}/results`, GET `/surveys/{id}/results/kingdoms` | surveys:read | survey.results |
| Rows and export | GET `/surveys/{id}/responses` (pg, audited), GET `/surveys/{id}/export.csv` (`?format=raw\|analysis\|codebook`, audited) | surveys:read | survey.manage |
| Credit | GET/PUT/DELETE `/surveys/{id}/credit`, POST `/surveys/{id}/credit/reconciliations` | surveys:write | domain (`SurveyCredit` checks the grantor) |

## 17. Qualification tests — tasks R-18, W-20, W-21

`{type}` is `reeve` or `corpora`. Base `/kingdoms/{kingdom_id}/qual-tests/{type}`.

| Group | Routes | Scope | Policy |
|---|---|---|---|
| Config and managers | GET/PUT `…/config`, GET `…/managers`, PUT/DELETE `…/managers/{player_id}` | qualtests:manage | qualtest.manage |
| Questions | GET/POST `…/questions`, GET/PATCH `/qual-questions/{qid}`, POST `/qual-questions/{qid}/duplicate`, PATCH `…/questions/status` (bulk), POST `…/questions/imports` (≤ 200), POST `/qual-questions/{qid}/stats-resets` | qualtests:manage | qualtest.manage |
| Library | GET `…/library`, POST `…/library/{qid}/copies` | qualtests:manage | qualtest.manage (destination) + source kingdom shares |
| Sets | GET/POST `…/sets`, PATCH/DELETE `/qual-sets/{set_id}`, PUT/DELETE `/qual-sets/{set_id}/questions/{qid}`, POST `/qual-sets/{set_id}/publish`, GET `/qual-sets/{set_id}/export.txt`, GET `…/preview` | qualtests:manage | qualtest.manage (kingdom from the set) |
| Reports on questions | POST `/qual-questions/{qid}/reports` (any player), GET/DELETE `/qual-questions/{qid}/reports` (manager) | qualtests:take / qualtests:manage | authenticated / qualtest.manage |
| Taking | POST `…/attempts` (issues an attempt bound to the served questions), POST `/qual-attempts/{attempt_id}/answers` (submit once; consumes a retake atomically), GET `/qual-attempts/{attempt_id}` | qualtests:take | authenticated; qualtest.attempt for reads |
| Results | GET `/players/{player_id}/qual-results`, GET `/players/{player_id}/qual-attempts`, GET `…/results` (manager report), DELETE `…/retakes[/{player_id}]` | qualtests:take / qualtests:manage | self_or manager / qualtest.manage |
| Qualified lists | `/reports/reeve-qualified`, `/reports/corpora-qualified` (section 13) | - | public |

The per-question answer check is not ported as an open oracle. `POST /qual-attempts/{attempt_id}/checks` checks one question inside the actor's own open attempt, counts against a per-attempt budget equal to the question count, and is only available when the kingdom's config enables open-book feedback.

## 18. Bonus credits — tasks R-19, W-22

| Routes | Scope | Policy |
|---|---|---|
| GET `/bonus-credit-categories` (`?scope_type=&scope_id=&archived=`), POST `/bonus-credit-categories`, POST `/bonus-credit-categories/{id}/archive`, `/restore` | credits:read / credits:write | domain |
| GET `/bonus-credit-categories/{id}/credits`, `/allowance`, `/adoptions` | credits:read | domain (`adoptions`: admin) |
| PUT/DELETE `/kingdoms/{kingdom_id}/bonus-credit-adoptions/{category_id}` | credits:write | domain |
| GET/PUT `/kingdoms/{kingdom_id}/bonus-credit-outside-setting` | credits:read / credits:write | domain |
| GET/POST/DELETE `/kingdoms/{kingdom_id}/bonus-credit-granters[/{granter_id}]` | credits:write | domain |
| GET `/players/{player_id}/bonus-credits` | credits:read | key; `include_revoked` needs player.officer(edit) |
| POST `/players/{player_id}/bonus-credits` | credits:write | domain. Idempotency required |
| PATCH/DELETE `/bonus-credits/{id}` | credits:write | domain |

Source-category and source-grant methods stay internal and are never routed.

## 19. Admin — tasks R-21, W-26

All `admin` policy unless stated. Key lifecycle is deliberately absent (Admin UI only). So are the Admin maintenance and server-health operations (table optimisation, log purge, process list, database status, weather health and cache refresh): decision E2 of 2026-11-24 keeps them in the Admin UI only, listed in section 20.

| Method and path | Scope | Notes |
|---|---|---|
| GET `/admin/api-usage`, `/admin/api-usage/keys/{key_prefix}`, `/admin/api-usage/v1` | admin:read | `ApiUsage` readers. ← Report/GetApiUsage |
| GET `/admin/app-versions` | admin:read | ← Report/GetCommunityAppVersions |
| GET `/admin/api-audit` | admin:read | pg |
| GET `/admin/audit-log`, `/admin/audit-log/methods` | admin:read | pg, `limit` ≤ 200 |
| GET `/admin/dashboard-stats`, `/admin/release-utilization` | admin:read | cost 25, cached |
| GET `/admin/reports/inactive-kingdoms`, `/inactive-parks`, `/park-activity`, `/new-player-attendance-by-kingdom` | admin:read | |
| GET/POST/DELETE `/admin/global-admins[/{authorization_id}]` | admin:write | Shared grants handler |
| GET `/admin/permissions` | admin:read | `?scope_type=&scope_id=`. Admin only; kingdom, park, event and unit officers use the scoped `…/authorizations` lists (one scope per operation) |
| POST/PATCH/DELETE `/awards[/{award_id}]` | admin:write | Global catalogue; new domain methods (the legacy edit never persists) |

## 20. Not ported

| v1 surface | Why |
|---|---|
| `Game/*`, `Tournament/*` writes, `DataSet` | Legacy or broken; deprecated module |
| `Treasury` ledger, accounts, last-dues removal | Unfinished; dues are `ork_dues` (section 3) |
| `Principality/*` | Folded into kingdoms |
| Application registration (`RegisterApplication` family), `XSiteAuthorize` | Replaced by admin-issued keys |
| Session and credential helper methods on the auth class | Never endpoints; sessions go through section 2 |
| Password reset (`Authorization/ResetPassword`) | Not in v2.0; website only until a token-based reset exists (decision U17; future item) |
| Admin maintenance and server health (table optimisation, log purge, the process list, database status, weather health and the weather cache refresh) | Admin UI only (decision E2, 2026-11-24): a leaked admin key must not reach maintenance, by the same reasoning as D17 for key lifecycle |
| Static and helper methods exposed by accident (maps, id lists, text folding, SQL fragment builders, cache busters) | Not API |
| `GetAwardOptionListHtml`, HTML row and panel actions | Presentation; data equivalents exist |
| Face lookup and enrolment | Third-party biometric call; out of scope |
| Recap store and replace, analytics fetch | Job-only (`bin/compute-weekly-recap.php`) |
| Banner dismissals, What's New, viewer preferences, nav helpers | UI plumbing |
| Standalone park geocode | Happens on park update |
| Sitemap, QR image | Not API (QR is rendered client-side from the link URL) |

---

## 21. v1 to v2 mapping for methods consumers use

Derived from `ork_api_tally` (2026-09-25 onward) for the named consumers. After Phase 3 the same table is generated from `x-ork-replaces` and shown on the migration page; this copy is the planning baseline.

| v1 call | Used by | v2 |
|---|---|---|
| Authorization/Authorize | mORK, Listmancer, BlackspireWaiver | POST `/sessions` |
| Authorization/WhoAmI | Listmancer | GET `/me` |
| Authorization/DestroySession | Listmancer | DELETE `/me/sessions/current` |
| Authorization/GetAuthorizations | mORK, BlackspireWaiver | GET `/me/authorizations` (own); GET `/players/{id}/authorizations` (officer) |
| Player/GetPlayer | mORK, jsork, Listmancer, BlackspireWaiver | GET `/players/{id}` |
| Player/GetPlayerClasses | mORK, jsork, Listmancer | GET `/players/{id}/classes` |
| Player/AttendanceForPlayer | mORK, jsork | GET `/players/{id}/attendance` (paginated) |
| Player/AwardsForPlayer | mORK, jsork | GET `/players/{id}/awards` (paginated) |
| Player/UpdatePlayer | mORK, BlackspireWaiver | PATCH `/players/{id}`; PUT `/players/{id}/waiver` |
| Player/CreatePlayer | BlackspireWaiver | POST `/players` |
| Player/SetImage | mORK | PUT `/players/{id}/image` |
| SearchService/Player, Search/Player | mORK, jsork, Listmancer, web UI | GET `/players?q=` |
| SearchService/Event, Search/Event | mORK, jsork, felfrost.ca | GET `/events?q=` |
| Event/GetEventDetails | mORK, felfrost.ca | GET `/events/{id}/occurrences` |
| Search/CalendarDetail | web UI | GET `/occurrences/{occ}` |
| Attendance/AddAttendance | mORK | POST `/attendance` |
| Attendance/RemoveAttendance | mORK | DELETE `/attendance/{id}` |
| Report/AttendanceForDate | jsork, mORK | GET `/parks/{id}/attendance?date=` |
| Report/AttendanceForEvent | mORK | GET `/events/{id}/occurrences/{occ}/attendance` |
| Report/RecentParkAttendees | mORK | GET `/parks/{id}/attendance/recent-attendees` |
| Report/GetPlayerRoster | jsork | GET `/kingdoms/{id}/players` or `/parks/{id}/players` (paginated) |
| Report/Guilds, Report/UnitSummary, Report/ClassMasters | mORK, jsork | GET `/reports/guilds`, `/reports/unit-summary`, `/reports/class-masters` |
| Kingdom/GetKingdoms | mORK, jsork, Listmancer | GET `/kingdoms` |
| Kingdom/GetKingdomDetails | mORK, jsork | GET `/kingdoms/{id}` |
| Kingdom/GetParks | mORK, jsork, BlackspireWaiver | GET `/kingdoms/{id}/parks` |
| Kingdom/GetOfficers, Park/GetOfficers | BlackspireWaiver | GET `/kingdoms/{id}/officers`, `/parks/{id}/officers` |
| Park/GetParkShortInfo, Park/GetParkDetails | mORK, Listmancer | GET `/parks/{id}` |
| Park/GetParkDays | mORK, felfrost.ca | GET `/parks/{id}/days` |
| Search/Kingdom, Search/Park, Search/Unit, Search/Location | web UI | GET `/kingdoms?q=`, `/parks?q=`, `/units?q=`, `/search/locations` |
| Map/Geocode | browser clients | GET `/geocode` (login required) |
| Park/PlayAmtgard | browser clients | GET `/parks/nearby` |
| Heraldry/GetHeraldryUrl | browser clients | GET `/{entity}/{id}/heraldry` |
| IdpIntegration/BeginClaimOrkMail, ValidateClaimOrkCode | IdP | POST `/idp/claims`, `/idp/claims/verify` |
| Live/*, Weather/*, EraPhoenice/* | embeds, web UI | `/live/*`, `/weather/*`, `/era-phoenice/*` |

Behaviour differences a consumer will notice (also in the migration guide, which lists the field differences method by method, decision U11): real HTTP status codes; one envelope; snake_case; pagination on attendance and awards; a key on every call that is not aggregate or reference data; usernames, emails, real names, dues and waiver flags only for a logged-in officer; drafts invisible to non-managers; no credentials in URLs.

Other self-identified clients present in the tally (to be contacted in Phase 5, task V-11): NineBlades.ca, SR Award Scribe, Field Marshal, AmtBot, FORK, Court of Blades and Banners, larpstats.com, ORK-Signin-Bot, SkyPainter, CASIA, AmtgardIDP.
