# Phase 6 — v1 security floor (OPTIONAL, unscheduled: risk accepted 2026-11-24)

**This phase is not scheduled.** On 2026-11-24 the maintainer accepted the v1 exposure in writing (overview header and section 12, decision U1): the critical and high v1 findings stay open until v1 is retired or a later decision schedules this phase. No v1 hotfix is planned. The phase is kept intact and ready to run, so it can start within a day if the decision changes.

- 10 tasks (S-01 to S-10), 2 waves; not scheduled.

Nothing in Phases 1 to 5 or 7 depends on it, and neither v2 GA (H-14) nor publishing the plan waits on it. If it is never run, the same issues are closed only when v1 is retired, and v1 retirement is itself deferred (Phase 7, U2).

## 1. Why it is on the table

v2 fixes every finding by construction, but v1 stays reachable with no retirement date (U2), and the announcement, the migration guide and the `Deprecation` headers will draw attention to it. The inventory found issues on v1 that do not need an account to abuse. The local-only file `docs/api-v2/inventory/SECURITY-FINDINGS.md` ranks them; its "Floor list" section names the exact methods and actions for each task below. That detail is deliberately not repeated here.

## 2. The decision

| Option | What happens | Consumer impact |
|---|---|---|
| A. Critical subset **now**, independent of the v2 timeline (recommended by the security review; not chosen, risk accepted 2026-11-24) | S-01 (fast path first, see S-01), S-03 limited to the two anonymous paths, the notes part of S-02 and S-04, S-07 content type and escaping only, S-10, then S-09. This matches "Suggested order" items 1 to 5 in the local findings file | None expected: the affected methods and files have no recorded consumer traffic (confirm with the tally in S-09) |
| B. Full floor before go-live | All ten tasks | Some v1 responses lose fields or need a login; consumers named in the catalog that display those fields are affected and must be told first |
| C. Full floor after go-live, before the "Keyed" stage | As B, later | As B |
| D. Do nothing (**chosen 2026-11-24**, with the risk accepted in writing) | Exposure remains until v1 is retired, which has no date | None |

Severity classes involved (counts are in the local file): credential and session helpers reachable without credentials; writes with no authentication; SQL built from request strings on anonymous paths; anonymous reads of data the website gates; cost endpoints with no gate; missing brute-force controls; missing CSRF and verb checks on the website's own AJAX; personal documents stored as static files.

## 3. Constraints specific to this phase

- Every change is checked against the V-01 characterization suite. A fixture may change only where the task says the behaviour is being closed on purpose, and each such change is listed in the PR description.
- No edit to `class.Authorization.php`. Method-level blocks are applied in the bridge, before the class is instantiated. (Phase 1 task F-31 is the plan's single sanctioned change to that file, for session-token hashing and the suspension check; it is scheduled independently of this phase.)
- Fixes to legacy domain methods on whitelisted classes must not add public methods (the frozen list from V-06 would refuse them anyway).
- Field and login changes follow the rules of unmerged PR #552 (`feature/api-security`), which is the prior art for S-02 and S-04. Port from that branch; do not redesign.

## 4. Dependency graph

```
6A  S-01 S-02 S-03 S-04 S-05 S-10     (parallel; S-01 and S-02 both hook the bridge through V1Hooks collaborators; S-10 is independent of the bridge)
6B  S-06 S-07 S-08  ->  S-09
```

Requires Phase 5 tasks V-01, V-02 and V-06 (the hook seams, the frozen list, and the regression net). If Phase 6 is chosen before Phase 5 has run, run those three tasks first, except for the S-01 fast path and S-10, which need neither.

## 5. Tasks

**S-01 Bridge deny list and dispatch order** · **Opus** · ~300
- Goal: remove from v1 the methods that must never have been endpoints, and close the dispatch-order and introspection gaps.
- Files: `system/lib/system/class.V1DenyList.php` (registered through `V1Hooks`), `orkservice/Json/v1-methods.frozen.php` (entries removed), `class.JsonServer.php` (whitelist and frozen-list check moved ahead of instantiation; `describe` given the same check), tests.
- Source of the list: SECURITY-FINDINGS "Floor list FL-1" (helpers and internal methods) and "FL-2" (unauthenticated writes with no legitimate remote caller).
- Accept: each listed call answers the bridge's standard restricted-method envelope; the class constructor is not run for refused calls; V-01 fixtures unchanged for every method in catalog section 21.
- Fast path (for option A, ahead of Phase 5): a hard-coded, case-insensitive deny array for the FL-1 entries on the authentication classes, checked in `JsonServer::RunServer` for `call` and `describe` before any class is instantiated, answering the existing restricted-method envelope, with one unit test per entry and one proving a listed consumer method (catalog section 21) still dispatches. About 60 lines, Opus review, deployable on its own. The full S-01 later moves the array into `V1DenyList` unchanged.

**S-02 Bridge read guard** · Sonnet · ~400
- Goal: bring anonymous v1 reads to website parity.
- Files: port `system/lib/ork3/class.ApiGuard.php` from `feature/api-security` as `system/lib/ork3/class.V1Guard.php` with underscore-named public methods; hook `prepare` and `filter` through `V1Hooks`; port `tests/Integration/ApiGuardTest.php`.
- Scope: the gate and filter tables of that branch, plus the additions in "Floor list FL-3".
- Accept: the ported test passes; the PR lists every v1 method whose anonymous output changed.

**S-03 String-built SQL on anonymous paths** · **Opus** · ~350
- Goal: replace request-derived string interpolation with bound parameters or integer casts in the methods named in "Floor list FL-4".
- Files: the named methods in the legacy domain classes (edits inside existing method bodies only; no signature or return-shape change).
- Accept: V-01 fixtures byte-identical for normal input; the H-04 corpus run against the v1 harness for these methods produces no database error.

**S-04 Website AJAX personal-data gates** · Sonnet · ~300
- Goal: the AJAX actions in "Floor list FL-5" require the same login and authority as the page that shows the data.
- Files: the named controller actions; gates implemented by calling model methods (controllers stay free of domain calls).
- Accept: a test per action for anonymous, unrelated logged-in player, and authorised officer.

**S-05 Website AJAX write protection** · Sonnet · ~400
- Goal: POST-only and CSRF-checked mutations across the AJAX controllers, without touching each action by hand.
- Files: `system/lib/system/class.Controller.php` (a `_csrfToken()` helper matching the existing CMS convention and a constructor check: for controllers whose name ends in `Ajax`, any request that is not `GET` must carry a valid `X-CSRF-Token`; actions listed in "Floor list FL-6" are additionally refused on `GET`), the shell emits the token as a JS global, one `$.ajaxPrefilter` and one `fetch` wrapper add the header for same-origin requests; session cookie gains `SameSite=Lax`.
- Note: the shell and its script live under `template/default/`. This is infrastructure shared by every page, not a feature entry point. Decisions U6 and U18 approved only the two specific shell edits in F-33; this change needs its own agreement from the maintainer when the phase is scheduled.
- Accept: every existing e2e spec passes; a cross-site form post to a mutating action is refused.

**S-06 Login and reset throttling on v1** · Sonnet · ~250
- Files: `system/lib/system/class.V1LoginThrottle.php` using the Phase 1 `Limiter`; hooked for the login and reset methods only.
- Must: the v2 login limits (overview 5.3 and 6.4, including username normalisation and fail-closed behaviour); for password reset, 5 per hour per IP and 3 per day per account; the refused response is the existing failure envelope so clients need no change.

**S-07 JSONService hardening** · Sonnet · ~200
- Files: `system/lib/system/class.JSONService.php`.
- Must: set the JSON content type; escape reflected values in the reflection action; stop after a validation error. The last item changes a documented quirk, so it is applied only to operations whose handler would fail anyway without the parameter (list in "Floor list FL-7").

**S-08 Cost endpoints on v1** · Sonnet · ~200
- Goal: the methods in "Floor list FL-8" require a valid session and share the v2 per-actor daily caps.
- Note: one of them is called by browser clients today (catalog section 21); those callers will need to log in. List the affected clients in the PR.

**S-09 Review and consumer impact** · **Opus**
- Checklist: V-01 diff reviewed line by line; for every changed behaviour, the tally shows either no consumer traffic or a named consumer who has been told; the adversarial-review skill run against the v1 entry points; the local findings file updated with the status of each item.

**S-10 Waiver files out of the public web root** · Sonnet · ~300
- Goal: waiver images and PDFs are served only to someone with authority over the player, never as plain static files (specifics in "Floor list FL-9" in the local findings file).
- Files: a migration-free change: `config.dist.php`, `config.dev.php`, `config.test.php` (the waiver directory constant moved outside the served tree, with the README table updated); `bin/move-waivers.php` (one-off: moves existing files, idempotent, dry-run by default); a new model-backed action `PlayerAjax/waiver/{id}` that streams the file after the same authority check as `SetWaiver` (park edit authority over the player's home park, cascading); the website places that link waivers use the new action instead of the file URL (FL-9 lists how to find them); `nginx.ork3.config` gains a backstop rule answering 404 for the old directory (FL-9); tests.
- Must: no change to the waiver upload flow other than the directory; PDF waivers are only stored when the bytes start with `%PDF-`; the streaming action sends `Content-Disposition: attachment`, `X-Content-Type-Options: nosniff` and `Cache-Control: private, no-store`.
- Accept: an anonymous request and an unrelated logged-in player get 404 for a known waiver; the home park officer gets the file; after `bin/move-waivers.php` the old URL answers 404 in a rebuilt image. The production move is a runbook step for the person who deploys (agents do not touch production files).

