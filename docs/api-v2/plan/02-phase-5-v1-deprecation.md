# Phase 5 — v1 deprecation tooling

Makes v1 measurable and visibly deprecated without changing what it returns, removes the dead SOAP layer, and publishes the legacy reference and migration guide.

**No dates (decision U2, 2026-11-24).** v1 is marked deprecated at T0 with the `Deprecation` header and the docs, but there is no Sunset date or retirement schedule, and no `Sunset` header is sent. Everything here ships and is useful without a date: usage monitoring, key attribution, the freeze, the docs. Nothing in this phase may assume or display a retirement date; Phase 7 (deferred) owns that if one is ever set.

- Integration branch: `api-v1/deprecation` off merged Phase 4 (it can start in parallel with Phase 4 once Phase 3 is merged; only V-08 to V-10 need the final `v1-map.json`).
- 12 tasks, 2 waves. Sonnet unless marked.
- Hard rule for every task: no v1 response body changes for a request that worked before. V-01 lands first and guards the rest.

## 1. What "v1" means here

| Surface | Entry | Kept until |
|---|---|---|
| JSON-RPC bridge | `orkservice/Json/index.php?call=Class/Method` | No date (U2; Phase 7 deferred) |
| JSONService | `orkservice/{Search,Live,Weather,EraPhoenice}/…Service.php?Action=` | No date (U2); Search in any case stays until the web UI stops using it (X-05) |
| SOAP | `orkservice/<Svc>/<Svc>Service.php` (nusoap) | Removed now (V-07) |
| UI AJAX | `orkui/index.php?Route=…Ajax/…` | Not part of the retirement; internal to the website |

## 2. Dependency graph

```
5A  V-01, V-04  ->  V-02  ->  V-03 V-05 V-06     V-07 (after V-01, independent of the rest)
5B  V-08 V-09 V-10 V-11  ->  V-12
```

File ownership inside 5A: `system/lib/system/class.JsonServer.php` and `class.JSONService.php` are touched by V-02, V-03, V-05 and V-06. To avoid conflicts, V-02 first adds two seams and merges before the others start: `private function before_dispatch(string $class, string $method): ?array` (returns an error envelope to short-circuit, else null) and `private function after_dispatch(string $class, string $method, float $seconds, int $outcome): void`, each delegating to a new collaborator class `system/lib/system/class.V1Hooks.php`. V-03, V-05 and V-06 then only add methods to `V1Hooks` in separate files they own (`class.V1KeyCheck.php`, `class.V1Deprecation.php`, `class.V1FrozenMethods.php`) and register them in a one-line list each (the orchestrator resolves that list at merge).

## 3. Tasks

### Wave 5A

**V-01 v1 characterization suite** · **Opus** · ~450
- Goal: lock today's wire behaviour so later tasks cannot change it by accident.
- Files: `tests/Integration/V1/BridgeCharacterizationTest.php`, `tests/Integration/V1/JsonServiceCharacterizationTest.php`, `tests/fixtures/v1/*.json` (recorded envelopes with volatile values masked), `tests/Support/V1Harness.php` (invokes `JsonServer::RunServer` and `JSONService::Service` in-process with a faked `$_REQUEST`, capturing output and headers).
- Cover: the no-argument class list; `?list=`; `?describe=`; the five envelope shapes; the `Method0` flat form; bridge error codes 0 to 6 with their exact texts; `Trace` presence rules; numeric-check encoding of a digit string; and one success plus one failure call for each method in catalog section 21. JSONService: each registered operation's raw payload shape, the missing-parameter behaviour (error text followed by the payload), the reflection action.
- Accept: suite green on the untouched branch; fixtures reviewed by the orchestrator for accidental personal data (use fixture players only).

**V-02 v1 usage recording** · Sonnet · ~300 · after V-01, merges before V-03/05/06
- Files: `system/lib/system/class.JsonServer.php` (the two seams only), `system/lib/system/class.JSONService.php` (call `after_dispatch` equivalent), `system/lib/system/class.V1Hooks.php`, tests.
- Must: keep the existing `ork_api_tally` write untouched; additionally call `ApiUsage::record_call(1, $key_id, $client, 'Class/Method', $status, $ms)` with `$client` from `V1ClientLabel::resolve($_SERVER)`, where `$status` is 200 for a successful envelope and 400 for a bridge or domain error (so error rates are visible) and `$key_id` is 0 unless V-03 resolved a key; JSONService endpoints are recorded as `Search/Player` and so on; failures are swallowed.
- Accept: V-01 still green; a bridge call produces one row in each table.

**V-03 v1 honours in-app keys when presented** · Sonnet · ~250
- Files: `system/lib/system/class.V1KeyCheck.php`, registration line, tests.
- Must: if `X-Ork-Key` starts with `ork_`, verify it with `ApiKey::verify_key`; valid → attribute usage to the key and apply its per-minute limit; invalid, revoked, suspended or expired → HTTP 401 and the bridge error envelope with a new `ClassCode 7` and text `Invalid API key`. A request with no key, or with a legacy edge key value, behaves exactly as before.
- Accept: V-01 green; new tests for the three paths. This is what makes the Cloudflare rule for `ork_`-prefixed keys safe (runbook F-25).

**V-04 First-party client label** · Sonnet · ~120 · may run alongside V-01; V-02 depends on it
- Goal: tell the website's own search calls apart from third-party traffic without editing any page or script (nothing under `template/default/` is touched).
- Files: `system/lib/system/class.V1ClientLabel.php` (`public static function resolve(array $server): string`), `tests/Unit/V1ClientLabelTest.php`.
- Must: return `ORK-Web` when the request carries `Sec-Fetch-Site: same-origin`, or, failing that header, when the `Referer` host equals the request host; otherwise return the existing label (`X-ORK-Client` or `User-Agent` through `ork_session_client_label()`). The label is telemetry only: both headers can be forged by any non-browser client. The Phase 7 exemptions that use it (X-01, X-02) are therefore migration pressure, not access control, and must never be the only thing standing in front of a security fix. The existing `ork_api_tally` label is not changed; only the new `ork_api_usage` row uses this resolver.
- Accept: unit cases for each branch; after V-02, web UI searches appear in `ork_api_usage` under client `ORK-Web`.

**V-05 Deprecation headers** · Sonnet · ~250
- Files: `system/lib/system/class.V1Deprecation.php`, registration line, tests.
- Must: when `ORK_API_V1_DEPRECATION_DATE` is set (at T0), every bridge and JSONService response carries `Deprecation: @<unix time>` (RFC 9745) and `Link: <…/orkui/index.php?Route=ApiDocs/migration>; rel="deprecation"; type="text/html"`. No `Sunset` header is emitted and no Sunset constant is read (decision U2; deferred Phase 7, X-02, adds it if a date is ever set). When `generated/v1-map.json` has exactly one successor operation for the called method, add `Link: <…/api/v2/…>; rel="successor-version"` (the path template from the spec); when it has several (a v1 method split across v2 routes), link to that method's anchor on the migration page instead. Headers only; bodies untouched. The CORS preflight in nginx gains `Access-Control-Expose-Headers: Deprecation, Link` for the existing locations.
- Accept: V-01 green with the constant empty and with it set (headers asserted separately); no response carries `Sunset`.

**V-06 Frozen method list** · **Opus** · ~300
- Goal: from now on, a new public method on a whitelisted class is not a v1 endpoint.
- Files: `orkservice/Json/v1-methods.frozen.php` (generated once by `tools/api-spec/freeze-v1.php`: for each of the 25 whitelisted classes, every public method that passes the current name rule, lower-cased), `system/lib/system/class.V1FrozenMethods.php`, registration line, `tests/Unit/V1FrozenMethodsTest.php`.
- Must: a call is allowed only if `strtolower(class/method)` is in the frozen list (after stripping the trailing `0`); otherwise answer exactly what the bridge answers today for a non-existent method. The list is behaviour-preserving on the day it is generated: it contains everything callable today, including the methods that should never have been callable. Removing entries is Phase 6 or Phase 7 work, not this task. (If Phase 6 option A has already shipped its bridge deny list, generate the frozen list after it, so the denied methods are not re-listed.) `?list=` and `?describe=` output is unchanged.
- Accept: V-01 green; a test adds a public method to a fixture whitelisted class and proves it is refused; the test from F-15 is extended to assert the frozen file is not regenerated accidentally (its hash is pinned in the test and changing it requires editing the test).

**V-07 SOAP removal** · Sonnet · ~200 (mostly deletions)
- Delete: every nusoap entry file `orkservice/<Svc>/<Svc>Service.php` for the 20 dead services, their `.registration.php`, `.definitions.php`, `.test.php`, `.testrig.*`, `index.html`; `orkservice/BarcodeService/`; `orkservice/Common.SOAP.php` after removing its `require` from `orkservice/Json/index.php` and the four JSONService entry files.
- Keep: `orkservice/Common.definitions.php`; every `*.function.php` that any live file or test requires (`grep -rn "Service.function.php"` first; `tests/Integration/AuthorizationAddTest.php` requires the Authorization one); the four JSONService directories; `orkservice/Map/charticon.php`; `orkservice/svcutil.php`.
- nginx: add `location ~ ^/orkservice/(Attendance|Authorization|Award|Banner|BarcodeService|Calendar|DataSet|Event|Heraldry|Kingdom|Map|Notification|Park|Player|Principality|Pronoun|Report|Tournament|Treasury|Unit)/[A-Za-z]+Service\.php$ { return 410; }` placed before the generic PHP location (Map's `charticon.php` does not match the pattern).
- Accept: full existing test suite green; V-01 green; `grep -rn soap_server orkservice` returns nothing; the bootstrap and every model that includes a service file still load.

### Wave 5B

**V-08 Legacy v1 reference page** · Sonnet · ~350
- Files: `orkui/template/revised-frontend/ApiDocs_legacy.tpl`, `controller.ApiDocs.php::legacy`, `orkui/model/model.ApiDocs.php` (loads the frozen list and the map file), `docs/api/v1-reference.md` (hand-written part: request shape, parameter binding, the five envelopes, status codes inside HTTP 200, authentication, the JSONService shape).
- Must: the page renders the hand-written reference (through `GuideDoc::render`, as the admin guide does) followed by a DataTables list of v1 methods limited to those with recorded traffic or a v2 successor, each with its successor link and a "deprecated" pill; a banner stating that v1 is deprecated, giving the deprecation date when set, and saying that no retirement date has been set. No method that is not already publicly documented or observed in consumer traffic is listed.
- Accept: dark mode and mobile checked; the page contains no parameter-level detail for methods without a successor.

**V-09 Migration guide** · Sonnet · ~350
- Files: `docs/api/v2-migration.md`, `orkui/template/revised-frontend/ApiDocs_migration.tpl`, `controller.ApiDocs.php::migration`.
- Content: getting a key (admin-issued, U7; acting keys need the owner's confirmation); logging in and reusing an existing token (warn that calling v1 `Authorization/Authorize` with a `Token` rotates it and so breaks the same token on v2; clients migrating call by call should verify with v2 `GET /me`, which never rotates); time fields (instants in UTC, event and park times as offset-free local times, where v1 returned server-local strings); the envelope and error model with before and after examples; status codes; naming; pagination; field differences (decision U11, website parity): for every consumer-facing v1 method in catalog section 21, a table of each v1 field, its v2 property (or "removed"), and the tier needed to see it (usernames, emails, real names, dues and waiver flags now need a logged-in officer, and so on), with the reason; suspended players' tokens are refused on v1 and v2 (F-31); idempotency for writes; rate limits; the docs explorer needs an ORK login (U9); per-consumer notes for the named apps (which calls they make today, from catalog section 21, and the v2 equivalents); the deprecation status (v1 is deprecated; no retirement date has been set, and any future date would be announced under Phase 7's notice rules); the full mapping table rendered from `v1-map.json`.
- Accept: every v1 call in catalog section 21 appears in the rendered table, and each of those methods has its field-difference table.

**V-10 v1 usage and readiness dashboard** · Sonnet · ~400
- Files: `orkui/template/revised-frontend/AdminApi_v1.tpl`, additions to `controller.AdminApi.php` and `model.AdminApi.php`, `ApiUsage::v1_readiness(int $days): array` (new method).
- Shows: v1 calls by client and by key over 30 and 90 days; share of total API calls; methods with traffic but no successor; per named consumer, the percentage of calls on v2; first-party (`ORK-Web`) versus third-party; each Phase 7 criterion shown as information with its current number (no stage is scheduled, U2, so the page shows measurements, not a countdown).
- Accept: numbers reconcile with SQL on `ork_api_usage`; DataTables, dark mode, `data-tip`.

**V-11 Consumer outreach kit** · Sonnet · ~200 (documents)
- Files: `docs/api/consumer-outreach.md`: per consumer (mORK, jsork, Listmancer, BlackspireWaiver, the IdP, felfrost.ca, and the other self-identified clients listed in catalog section 21) the methods they call and volumes (from the tally), the suggested key type and scopes, the message template announcing deprecation (without a retirement date, U2), the field differences that affect them (U11), and a checklist for issuing their key.
- Accept: reviewed by the user before anything is sent. Agents send nothing.

**V-12 Review gate** · **Opus**
- Checklist: V-01 green on the merged branch; a byte comparison of the five most-called methods against the mirror before and after; `Deprecation` header present only when configured and `Sunset` never sent; usage rows carry key attribution; the frozen list equals today's callable set (diff against a fresh dry run of the generator); SOAP URLs answer 410 in a rebuilt image; legacy and migration pages contain no sensitive method detail.
