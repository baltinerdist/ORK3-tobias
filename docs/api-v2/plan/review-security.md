# Security review of the ORK API v2 plan

**Reviewer role:** application security (API security, OWASP API Top 10, authentication and authorization design, key and token management, multi-tenant authorization, privacy, abuse prevention, secure SDLC).
**Date:** 2026-11-23. **Branch:** `refactor/api-reconstruction`.
**Method:** read every plan file, the inventory and the local findings file; checked the claims that matter against code at `HEAD` (the committed authentication class, the JSON bridge and its entry point, the gate facade, nginx, the session and tally migrations, the waiver and media paths in the player class, configuration, the shared page shell). Read-only: no logins, no requests against any server, no application code changed. An API-engineering reviewer edited the same files at the same time; where their change already closed a point, it is credited below.

This file is written to be publishable. Specific v1 methods, paths and file locations for open issues are only in the git-excluded `inventory/SECURITY-FINDINGS.md`.

## 1. Verdict

The v2 design is sound at its core: one compiled route table, one authentication step, a named policy on every route, a presenter that only emits declared fields, bound parameters, and no cookies. Those choices remove most of v1's defect classes by construction, and the plan traces them honestly.

The weaknesses were at the edges of that core, in the new mechanisms v2 adds: a key mode that let any admin impersonate any player, a per-request actor session that was really a standing token v1 would also accept, ownership checks for nested ids that the contract could not express, per-IP controls that depend on an edge setting the plan treated as optional, and login throttling that the database collation could bypass. All of those are now fixed in the plan.

The largest risk is not in v2 at all. An anonymous v1 path can produce a working session for any account, admins included, and the plan's default was to leave v1 alone until retirement, about a year after v2 ships. **The recommendation is to deploy the small bridge deny list (Phase 6, S-01 fast path) now, independent of v2, and not to publish this plan until it is out.** The plan blocked GA and publication on an explicit answer (U1). *Update 2026-11-24: the maintainer accepted the v1 exposure in writing instead; the blocks are replaced by that recorded acceptance (section 6).*

## 2. Findings and changes

Severity is the impact if the plan had been built as written, or, for v1 items, the exposure the plan's decisions leave in place. "Applied" means the plan files now say what to build and how to test it.

### Critical

| # | Finding | Change made | Status |
|---|---|---|---|
| C-1 | **v1 critical exposure left for a year.** The local findings rank anonymous session issuance and credential-store writes as critical (account takeover of any player, admins included). U1 defaulted to "not scheduled", option A waited for Phase 5 tooling, and nothing tied GA or publication of the plan to it. The ORK source is public, so the plan's defect classes are a reading guide | Overview header: publication gate. Overview U1: recommendation "now", and GA plus publication blocked until U1 is answered explicitly. Phase 6: option A redefined as "now, independent of v2" and aligned with the findings file's critical subset (it previously named fewer tasks than the findings file); new S-01 fast path (about 60 lines in the bridge, no Phase 5 prerequisite). H-14: U1 needs an explicit answer; publication gate checked. Traceability T-02 wording generalised | Applied in the plan. 2026-11-24: risk accepted in writing (U1); Phase 6 kept ready, unscheduled; the publication gate and the H-14 U1 block are replaced by the recorded acceptance |
| C-2 | **`acts_as_owner` was an impersonation primitive.** Any ORK admin could issue a key naming any player as owner with `acts_as_owner`, which acts as that player (an admin owner's key could carry admin scopes). It survives the victim's password change and gives a compromised admin account a persistent backdoor | Overview 5.2: self-issued only (`created_by` equals owner), secret key, mandatory IP allow-list, expiry within 365 days, never `admin:write`, owner notified. Enforced in `ApiKey` on issue, update and rotate (F-11), surfaced in the UI (F-23), tested (F-11, H-01), checked at go-live (H-14). U15 asks whether to keep the mode at all | Applied |

### High

| # | Finding | Change made | Status |
|---|---|---|---|
| H-1 | **The `acts_as_owner` session was a standing, unscoped token.** It reused `CreateSession`, which yields a 30-day sliding session that v1 also accepts with none of the key's scope, IP or revocation limits, and which evicts the owner's least-recently-used device sessions at the cap of six | Contract 3.5: `ApiActorSession::begin_actor_session` / `end_actor_session` / `purge_stale`. A dedicated `ork_session` row per request (5-minute expiry), inserted directly without the eviction path, deleted in the kernel's `finally` (3.10, F-15, F-20), stale rows purged daily. Tests prove the owner keeps all six sessions | Applied |
| H-2 | **Per-IP controls depend on the edge.** nginx accepts `CF-Connecting-IP` from the host-proxy range, so any request that reaches the origin around the CDN chooses its own client address, defeating per-IP limits and login throttling. The plan listed "restrict origin ingress" only as a runbook line | Overview 6.4 and threat model; F-25 asks for confirmation back; H-14 makes it a GA precondition; U12 default updated | Applied (the edge change is the user's, U12) |
| H-3 | **Nested ids and "own row" rules could not be expressed.** `ApiFacts` had resolvers for some child ids but not for about a dozen nested ids the catalog uses (milestones, park days, unit members, grants, schedule items, staff, recommendation seconds, attendance links, survey pages, questions and images, kingdom awards, notification rows), and policy arguments could only reference request values, so "own row" checks would land in handlers. Implementers would either stop or improvise BOLA checks | Contract 3.5: `ApiFacts::child_scope(kind, id)`. Contract 3.6: fact references in policy arguments, resolved by `PolicyEngine`, unknown row = 404. Overview 6.1 rule; catalog `self(p)` semantics and the sign-in and attendance-link rows; Phase 3 rule 7; Phase 2 test table; H-02 per-kind cases | Applied |
| H-4 | **Shared caching of key-gated responses.** The CDN does not honour `Vary` on custom headers, so a `public` cached copy of a `key`-policy response would be served to keyless callers, revoked keys and other origins, skipping the key check, limits and usage recording | The co-reviewer had already changed OP-09 and the F-25 runbook. This review aligned overview section 7, F-20 and H-09: shared caching only on `public`-policy routes, `key` routes `private, max-age` | Applied (joint) |
| H-5 | **Personal documents as static files (new finding).** Waiver images and PDFs are written under the public assets tree with predictable names, and v2's waiver upload would keep writing them there; the PDF branch stores whatever bytes the caller labels as PDF | New Phase 6 task S-10 (move out of the web root, serve through an authority check, backstop rule); W-02 validates PDFs and never returns a URL; catalog player profile: no waiver URL at any tier; H-03 asserts it; SC-03 bans `waiver_url`; local finding SF-H14 and floor list FL-9 | Applied |
| H-6 | **Login throttling was bypassable and leaky.** The per-username bucket would key on the raw string while the column collation ignores case, accents and trailing spaces; IPv6 was bucketed per address; the limiter failed open for login; there was no per-key or site-wide failure budget (an extracted publishable key plus rotating addresses is the standard stuffing setup); a correct password on a restricted account produced a distinct answer | Overview 5.3 and 6.4; F-09 (normalised username bucket, IPv6 /64, fail-closed login, self-registration and failed-auth buckets, per-key and site-wide counters); F-24 (generic failure for restricted accounts, buckets consumed before the credential check, `Token` never passed to the legacy login); H-05 cases; H-07 alerts | Applied |
| H-7 | **Live credentials in database copies.** The disposable test database is a nightly production backup; it carries every live session token in clear, IdP tokens and password verifiers, on developer machines. v2 tokens are the same tokens | Overview 6.7; F-25 runbook (clear these in the dump step); H-14 item; U8 recommendation strengthened; local finding SF-H15 | Plan applied; the remediation is an operational step for whoever produces the backup |
| H-8 | **Publishable keys could hold admin scopes.** Only `admin:write` was forbidden, so a stolen admin token plus any extractable browser key reached admin reads | `Scopes::PUBLISHABLE_FORBIDDEN` = `admin:read`, `admin:write`, `idp:integration` (overview 5.2, contract 3.2, F-11, H-01) | Applied |

### Medium

| # | Finding | Change made | Status |
|---|---|---|---|
| M-1 | Account-state rule wrong in both directions: F-17 refused "inactive" players (who can log in to the website) and treated `suspended` without its end date, which matters once the expiry sweep becomes a job; "banned" was undefined | Overview 5.2: `penalty_box`, or suspended with `suspended_until` empty or not past; `active = 0` is not a restriction. `ApiFacts::account_state.restricted_now` (F-14), F-15, F-17, H-01 | Applied |
| M-2 | `POST /password-resets` wrapped the legacy reset, which emails a short time-derived temporary password inside a link and ends no sessions | Not ported in v2.0; catalog row struck through and listed in section 20; W-23 rewritten; U17 added with the shape of a token-based reset if wanted later | Applied |
| M-3 | Secret keys usable from browsers: secret-key responses sent `Access-Control-Allow-Origin: *` | No CORS header on secret-key responses; a secret key with an `Origin` header is refused and raises `key.secret_in_browser` (overview 5.2, 6.5, F-10, F-17, H-07) | Applied |
| M-4 | Pepper: a dev default could reach production silently; no rotation; a wrong secret could reveal a key's state | Fail closed outside DEV/TEST, `hash_version` column and previous-pepper rotation, `invalid_key` regardless of state, runbook generation and rotation steps (overview 5.1, 3.11, 3.12, F-11, F-25, H-14) | Applied |
| M-5 | Audit covered writes only; no sensitive-read trail, no aggregated security signals, no retention, no statement about tamper resistance. Compromised officer accounts have happened before; reads are where that abuse shows | `request.read_sensitive`, burst and failure events, 400-day retention with IP truncation at 90 days, shipping to storage the app cannot write (overview 6.6, 3.11, F-12, F-20, F-25, H-07 anomaly rules) | Applied |
| M-6 | Legacy-method reuse: many catalog rows call legacy domain methods; the escape shim is a no-op, so any free text forwarded to one that builds SQL from strings reopens injection | Taint rule (overview 6.1, Phase 2 step 3, review checklists) and gate 5, a tokenizer check against string-built SQL in new `class.Api*.php` files (04-standards, F-27) | Applied |
| M-7 | Bulk exposure of person-level `key` data: an extracted publishable key and 100,000 calls a day can pull attendance histories (where and when named people play); restricted-player handling was unspecified | Cost 5 without an actor, per-IP daily cap inside a key, restricted-player parity in the `key` policy (overview 6.2, 6.4, catalog section 0, F-18, F-28, H-03); U3 default annotated | Applied |
| M-8 | Cost and capacity: heavy anonymous reports could be cache-busted by varying parameters; no site-wide cap on paid upstreams; explorers limited per player only | Server-side result cache and cost 5 for public reports, site-wide report and explorer semaphores, daily global caps on geocoding and weather archive (overview 6.4, F-09, R-07, R-12, R-20, H-05) | Applied |
| M-9 | Admin key management lacked step-up and page hardening; the owner of a key was never told | Password step-up within 10 minutes for issue, rotate, scope widening and `acts_as_owner`; `no-store`; key purged from the DOM; `frame-ancestors 'none'`; owner notification (overview 5.5, F-22, F-23) | Applied |
| M-10 | The shared shell loads a tag manager and analytics on every page, so third-party script would run on the page that reveals a key once and the page where keys are pasted | Recorded in F-23 and F-26; U18 asks for one shell conditional to skip them on those pages; CSP `connect-src 'self'` follows if approved | Applied 2026-11-24: U18 approved; F-33 adds the shell flag, set by the key pages, the owner confirmation page and the explorer |
| M-11 | Sessions never expire while used, and credential changes end no other sessions; W-01 verified the current password by running the login, which creates a session and can evict devices | Absolute session age on v2 (U16, `ORK_API_SESSION_MAX_AGE_DAYS`); `ApiDataAccount::verify_password` without side effects (F-15, F-24); other sessions ended after a credential change (W-01) | Applied |
| M-12 | Survey anonymity in rows and exports was left to "the domain" | Identity absent for anonymous surveys at every tier including admin, with tests; CSV escaping (overview 6.2, R-17, H-03) | Applied |
| M-13 | Routes with policy `domain` delegate authorization to legacy code but had no individual negative tests | Each gets its own H-02 entry and the PR quotes the domain check (catalog section 0, overview 6.1, H-02) | Applied |
| M-14 | Upload hardening: no re-encoding (EXIF GPS on player photos), SVG and polyglots not addressed, legacy URL inputs not explicitly blanked, outbound-fetch gate did not cover the domain classes | Re-encode through GD, SVG refused, `*Url` fields always empty, gate 3 extended (overview 6.3, W-02, W-14, 04-standards, H-04) | Applied |
| M-15 | Domain error text (known to carry SQL or request dumps in some methods) became the problem `detail` verbatim | Sanitised or replaced, original logged by request id (F-08) | Applied |
| M-16 | No written threat model, so tests could not be checked against actors | Overview 6.0: assets, nine actors, threats and controls | Applied |

### Low

| # | Finding | Change made | Status |
|---|---|---|---|
| L-1 | Path ids could overflow to floats or be 0 | Router: 1 to 4,294,967,295, otherwise 404 (overview 6.3, F-04) | Applied |
| L-2 | Bad keys and tokens cost a database lookup before any limit | `AuthFailGuard` per-IP bucket ahead of key lookup (3.10, F-09, H-01) | Applied |
| L-3 | Idempotency records could store credential-bearing responses and unbounded bodies | Never stored for credential responses; 64 KiB cap (3.11). The co-reviewer separately moved idempotency after the policy check | Applied |
| L-4 | CI supply chain | Read-only token permissions, SHA-pinned actions, no `pull_request_target`, lockfile installs, SRI check of the vendored viewer (04-standards section 5) | Applied |
| L-5 | Identity and secret deny lists in the linter were short | PA-03 and SC-03 extended, with reviewed exceptions (04-standards) | Applied |
| L-6 | The first-party client label was described as never used for access, but the Phase 7 exemptions rest on it and on `Origin`, both forgeable | V-04 and X-01 now say the Keyed stage is migration pressure, not a control | Applied |
| L-7 | HSTS absent; error caching unspecified | HSTS and `no-store` on errors (overview 6.5, F-10) | Applied |
| L-8 | Tier computed per item would run one authority check per row | Memoised per (actor, home park) (overview 6.2, F-20) | Applied |
| L-9 | Login response leaves no room for a second factor | Note in overview 5.3 (a `202` challenge can be added without a major version) | Applied |
| L-10 | Session label did not record which app created it | `<client> via <key prefix>`; `ApiKey/` labels reserved (overview 5.3, F-24) | Applied |
| L-11 | Key format has no checksum, so leaked keys cannot be recognised offline with low false positives | Not changed. Suggestion: register `ork_pk_`/`ork_sk_` as a custom secret-scanning pattern on the GitHub organisation | Left (cheap follow-up) |
| L-12 | Capability tokens in URL paths (attendance links, self-registration) appear in access logs | Not changed: they expire, they are meant to be shared, and access logs are operator-only. Noted for the runbook audience | Accepted |
| L-13 | Tokens are not bound to the key that minted them | Not changed: publishable keys are extractable, so binding adds little; the session label now records the key | Left |

**Counts:** 2 critical, 8 high, 16 medium, 13 low (39). Fully applied: 2 critical, 8 high (one of them, H-7, needs an operational step to take effect), 15 medium, 10 low. Partly applied: M-10 (waits on U18; applied after U18 was approved on 2026-11-24). Left or accepted with a reason: L-11, L-12, L-13.

## 3. What did not change, and why

- **Token hashing at rest** stays U8. It needs a deliberate commit of the excluded authentication class. The review recommends scheduling it, because one read of the session table (a copy, a backup, or an injection on v1) is every live account. *Update 2026-11-24: scheduled as task F-31 (Phase 1, Opus, one focused PR with a documented hook-override procedure).*
- **Audit tamper resistance** can only be improved operationally (separate storage, table grants); the plan says so.
- **Website AJAX** (CSRF, verbs) remains Phase 6 S-05, outside v2's scope, as planned.

## 4. Changes to the open decisions

| Decision | Before | Now |
|---|---|---|
| U1 | Not scheduled | Recommend option A now. Default stays "not scheduled", but GA and publication of the plan are blocked until the user answers explicitly |
| U3 | Key required, no login | Same default, with the bulk controls and restricted-player parity; text notes that a key does not make data private |
| U8 | Not done | Same default; the review recommends scheduling it |
| U12 | Runbook delivered | Same, but origin-ingress restriction must be confirmed before GA |
| U14 | Allow | Allow, with server-side result caching and the report concurrency limit |
| U15 (new) | | Keep `acts_as_owner`, restricted |
| U16 (new) | | Absolute session age on v2, default 180 days |
| U17 (new) | | Password reset not in v2.0 |
| U18 (new) | | Third-party scripts on key pages: not changed until the user agrees to a shell conditional |

## 5. Open questions for the user

1. **U1, now.** Will you ship the S-01 fast path (anonymous session issuance and credential-store helpers refused at the bridge) and the rest of option A ahead of v2? Until you answer, the plan blocks GA and publication. The details are in the local findings file, items 1 to 6 of "Suggested order".
2. **Backups.** Can the nightly copy used for local development drop session tokens, IdP tokens and password verifiers (SF-H15)? This is independent of v2 and closes a live exposure on every machine that holds a copy.
3. **U12.** Who can confirm, or set up, that the origin only accepts traffic from the CDN?
4. **U8.** Will you schedule the one-off commit to hash session tokens at rest and add the suspension check inside the authentication class?
5. **U15 to U18.** Accept the defaults (keep restricted `acts_as_owner`; 180-day session age on v2; no password reset in v2.0; no shell change for third-party scripts), or choose otherwise.

## 6. Decisions applied (2026-11-24)

The maintainer answered the open questions on 2026-11-24 (overview section 12). Effect on this review:

| Question or finding | Decision | Where applied |
|---|---|---|
| 1. U1, now (C-1) | **Risk accepted in writing.** No v1 hotfix; Phase 6 optional and unscheduled. The v1 critical and high findings stay open until v1 retirement or a later decision | Overview header (replaces the publication gate) and section 8; H-14 checklist; Phase 6 header; traceability reading note |
| 2. Backups (H-7, SF-H15) | The developers' copy of the nightly backup excludes `ork_session` rows and blanks token, password-hash and IdP-token columns; production DR backups unchanged (E1). A step for whoever produces the dump | Overview 6.7 and 11.1; F-25 runbook; traceability T-63 |
| 3. U12 | Runbook handed to the upstream `amtgard/ORK3` infrastructure maintainer; GA waits on their written confirmation that origin ingress is Cloudflare-only | F-25; H-14; overview 11.1 |
| 4. U8 | **Scheduled**: F-31 hashes session tokens at rest (with a migration for existing rows and the `ork_mundane.token` mirror) and adds the suspension check to `IsAuthorized` | Overview D23, 6.7; Phase 1 F-31; traceability T-04, T-06, N-14 |
| 5. U15 to U18 | U15 kept, restricted; U16 180 days; U17 website only (token-based reset is a future item); U18 approved (F-33) | Overview 5.2, 5.3, 5.5, 6.5 |
| C-2 and U7 | Keys stay admin-issued (U7). Reconciled with U15: an admin creates an acting key only as an inactive request; it activates when the owner confirms in-app with password re-entry, and the secret is shown only to the owner. All U15 restrictions kept | Overview 5.2 and 5.5; F-11, F-21, F-22, F-23, new F-32; H-01, H-07, H-11, H-14; traceability N-01, N-13 |
| U9 | Explorer and `openapi.json` require an ORK login; `noindex`. A speed bump, not a control; the spec is still assumed public | Overview D20, section 10; F-24, F-26 |
| U2 | v1 deprecated at T0 with no Sunset date; Phase 7 deferred. The v1 exposure is therefore open-ended, which the U1 acceptance covers | Overview section 8; Phases 5 and 7 |

New question raised by the reconciliation (overview N1): who should receive an acting key's secret. The plan's default is the owner only, because owner activation protects nothing if the requesting admin also holds the key.

