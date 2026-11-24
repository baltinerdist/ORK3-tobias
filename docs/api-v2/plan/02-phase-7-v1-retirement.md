# Phase 7 — v1 freeze and retirement (DEFERRED, not scheduled)

**Deferred (decision U2, 2026-11-24).** v1 is deprecated at T0 (Phase 5) but has no Sunset date and no retirement schedule. Nothing in this phase is built or switched on until a later decision sets a retirement date. It stays documented as the future path: the staged design below, and the measured criteria that Phase 5's usage monitoring (V-02, V-10) already reports on.

Operational more than constructional. Each stage is switched on by configuration, announced in advance, and gated on measured criteria. T0 is the day v2 is declared generally available (gate H-14 passed and keys issued to the named consumers).

- 8 tasks, 3 waves; not scheduled.
- Absolute dates would be set by the maintainer when retirement is decided. Until `ORK_API_V1_SUNSET_DATE` exists and is set (X-02), nothing emits a date.

## 1. Stages

The "Earliest" column is the proposed spacing from the day a retirement decision is taken (written as T0-relative because that was the original plan); it is not a schedule.

| Stage | Earliest | Switch | Effect on v1 |
|---|---|---|---|
| Deprecated | T0 | `ORK_API_V1_DEPRECATION_DATE` | `Deprecation` header only (Phase 5; already in force from T0) |
| Frozen | T0 | frozen method list (V-06) | No new methods; security fixes only |
| Keyed | T0 + 6 months | `ORK_API_V1_REQUIRE_KEY=1` | Non-browser callers without a valid in-app key are refused |
| Brown-outs | T0 + 6 months onward | `ORK_API_V1_BROWNOUTS` schedule | Announced windows in which v1 answers "gone" |
| Read-only | T0 + 9 months | `ORK_API_V1_READONLY=1` | Mutating methods answer "retired" |
| Sunset | T0 + 12 months | `ORK_API_V1_SUNSET_DATE` (header announcing the date, X-02), then removal | Bridge and JSONService entry points answer 410, then are deleted |

## 2. Criteria

A stage is entered only when its criteria hold on the retirement dashboard (V-10) and the user confirms.

| Stage | Criteria |
|---|---|
| Keyed | Every named consumer (mORK, jsork, Listmancer, BlackspireWaiver, IdP, felfrost.ca) holds a key and sends it on at least 95% of its v1 calls for 14 days. Unkeyed non-browser traffic is under 5% of v1 calls. The outreach notice went out at least 60 days earlier |
| Read-only | v1 mutating calls are under 1% of all API mutations for 30 days. Every v1 mutating method with traffic in the last 90 days has a v2 successor in use by its caller |
| Sunset | (1) Every v1 method with traffic in the last 90 days has a successor (parity report). (2) Each named consumer makes at least 99% of its calls on v2 for 30 days. (3) Third-party v1 traffic is under 1% of total API calls for 30 consecutive days. (4) First-party v1 traffic (`ORK-Web`) is zero for 14 days, which requires X-05. (5) Old mORK versions still on v1 are below an agreed share of sessions, or the app has shipped a forced-upgrade notice. (6) At least three brown-outs have run without an unresolved consumer escalation |

If a criterion is not met at the calendar date, the stage slips and the `Sunset` header is updated at least 30 days before the previous date. A date already announced is never brought forward.

## 3. Dependency graph

```
7A  X-01 X-02 X-03          (build the switches once retirement is decided; they need Phase 5)
7B  X-04 X-05               (X-05 must complete before Sunset criterion 4 can be met)
7C  X-06  ->  X-07  ->  X-08
```

## 4. Tasks

### Wave 7A (built only after a retirement decision; switches stay off until each stage's criteria hold)

**X-01 Key-required switch** · Sonnet · ~200
- Files: `system/lib/system/class.V1KeyRequired.php` (through `V1Hooks`), tests.
- Must: when `ORK_API_V1_REQUIRE_KEY` is on, a request without a valid in-app key is refused with HTTP 401 and the bridge error envelope (`ClassCode 7`), except: requests labelled first-party by `V1ClientLabel`, and requests from a browser origin (an `Origin` header is present) until the read-only stage. JSONService endpoints follow the same rule. Both exemptions rest on headers any client can send, so the Keyed stage pushes consumers to migrate; it is not a security control and is not a substitute for Phase 6.
- Accept: V-01 green with the switch off; tests for each exemption with it on.

**X-02 Sunset header and brown-out scheduler** · Sonnet · ~250
- Files: `system/lib/system/class.V1Sunset.php`, `system/lib/system/class.V1Brownout.php`, the `ORK_API_V1_SUNSET_DATE` constant in the three config files and the README table, tests.
- Must, Sunset: when `ORK_API_V1_SUNSET_DATE` is set, every bridge and JSONService response also carries `Sunset: <HTTP-date>` (RFC 8594) and nginx's v1 `Access-Control-Expose-Headers` gains `Sunset`; empty means no header. Phase 5 deliberately sends no `Sunset` (U2).
- Must, brown-outs: `ORK_API_V1_BROWNOUTS` is a comma list of ISO-8601 intervals in UTC; inside an interval every v1 call answers HTTP 410 with the bridge error envelope, text "The v1 API is being retired. See <migration URL>", plus the usual deprecation headers and `Retry-After` set to the interval end. First-party traffic is exempt. Usage is still recorded (status 410) so the dashboard shows who was hit.

**X-03 Readiness report** · Sonnet · ~250
- Files: `bin/api-v1-readiness` (CLI printing each criterion in section 2 with its current value and pass or fail; exit code 0 only when the named stage's criteria all pass), reuse `ApiUsage::v1_readiness`.
- Accept: output matches the dashboard for the same window.

### Wave 7B

**X-04 Read-only switch** · Sonnet · ~250
- Files: `orkservice/Json/v1-methods.mutating.php` (generated list: frozen methods classified as mutating by the inventory's Effect column, reviewed by Opus), `system/lib/system/class.V1ReadOnly.php`, tests.
- Must: with the switch on, a listed method answers HTTP 410 with the bridge envelope and a successor link; the login, session and logout methods stay available until Sunset.

**X-05 Website search off JSONService** · Sonnet, split into three sub-tasks by area · ~400 each
- Goal: the website's own autocomplete and search calls stop using `orkservice/Search/SearchService.php`.
- Approach: a single `SearchAjax` controller action family backed by `Model_Search` (the scoped search the CRM pages already use), then a mechanical rewrite of the call sites found by `grep -rn "SearchService.php" orkui/`. Sites in `revised-frontend` are rewritten. Sites that exist only in `template/default/` pages are listed for the user: each is either a page still in use (it gets the rewrite as a bug-level change, with the user's agreement, since it adds nothing new) or a dead page (left alone and allowed to break at Sunset).
- Rules: every rewritten picker keeps its scoping (`&q=` not `?q=`, the three deliberate global searches stay global), is curl-tested, and uses the `kn-ac-results` pattern where it is touched in the CRM.
- Accept: the dashboard shows zero `ORK-Web` v1 calls for 14 days.

### Wave 7C (at Sunset, after criteria and user confirmation)

**X-06 Sunset responder** · Sonnet · ~150
- Files: `orkservice/Json/index.php` and the four JSONService entry files replaced by a static responder: HTTP 410, `application/problem+json`, a link to the migration guide. nginx keeps routing to them.
- Keep for six months so late callers get a clear answer instead of a 404.

**X-07 Code removal** · Sonnet · ~300 (deletions)
- Delete: `system/lib/system/class.JsonServer.php`, `class.JSONService.php`, the `V1*` hook classes, the JSONService registration files, `JSONModel` if unused, the v1 frozen and mutating lists, the V-01 fixtures. Remove the `ork_api_tally` write; keep the table for history. Before removing it, repoint the first-party reader of that table (`Report::GetApiUsage`, used by the Platform Trends page through `orkui/model/model.Recap.php`) to `ork_api_usage` through an `ApiUsage` method, or that page silently freezes at the sunset date. The `ork_application` and `ork_application_auth` tables are kept (decision U10); no drop migration.
- After removal the bridge name-rule convention is obsolete; update `BridgeIsolationTest` to assert the bridge is gone, and note in `agent-instructions/api-v2-standard.md` that the underscore rule remains as house style for non-endpoint domain methods.
- Accept: full test suite and e2e green; `grep -rn "orkservice/Json" .` finds only the responder and documentation.

**X-08 Close-out** · **Opus**
- Update the legacy reference page to "retired", archive the migration guide, record the final timeline in the release notes source (`orkui/whats_new_content.php`), remove the Cloudflare rules that only existed for v1 (runbook item for the human with access), and mark every row of `03-traceability.md` as closed.
