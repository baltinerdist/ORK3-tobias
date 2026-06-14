# ORK API Rehabilitation (v2) — Design

**Date:** 2026-06-13
**Branch:** `refactor/api-reconstruction`
**Status:** Approved design → implementation planning

## Goal

Rehabilitate the ORK API from an inconsistent, undocumented, non-standard collection of
surfaces into a clean, versioned, self-documenting REST API conforming to the OpenAPI 3.1
standard, accessible through an auth-gated developer portal, with an SDLC that keeps the
documentation current via Claude.

The six concrete end-state goals:

1. The ORK API layer is fully converted to REST.
2. The ORK API conforms to the latest OpenAPI standard (3.1).
3. The ORK API is self-documenting (spec generated from code).
4. The ORK API is accessible through an auth-gated developer section using a well-performing
   FOSS documentation display tool (Scalar).
5. The ORK API is versioned so existing implementations keep working (legacy = v1, untouched),
   while v2 is fully ready for consumers to adopt.
6. The ORK SDLC, particularly through Claude, keeps the API current — rules + tooling ensure
   docs never drift, and fill any gaps self-documentation can't cover.

## Current State (why this is needed)

The codebase has **three overlapping API surfaces over the same core**, none documented or
standardized:

- **SOAP** (`orkservice/<Name>/`, nusoap) — the nominal "official" API. Each service is split
  into `.definitions` (WSDL types), `.registration` (`$server->register('Service.Method', …)`),
  and `.function` stubs. `svcutil.php` even carries a commented-out
  `die("SOAP endpoint is deprecated")`.
- **JSON-RPC bridge** (`orkservice/Json/index.php` → `system/lib/system/class.JsonServer.php`) —
  exposes 19 service classes via `?call=Class/Method`. Clever (reflection + static analysis to
  derive parameters; `?describe=` / `?list=` introspection) but **RPC, not REST**, with an ad-hoc
  `{Result, Status, Code}` envelope.
- **UI AJAX** (`orkui/controller/*Ajax.php`) — a third JSON surface using session auth; not part
  of the exported API.

The real business logic lives in `system/lib/ork3/class.*.php`. Critically, **that layer is
already transport-shaped**, which is the core structural problem this design addresses:

- Methods take a `$request` **array with `Token` embedded** → the domain layer knows about auth tokens.
- They call `Ork3::$Lib->authorization->IsAuthorized($request['Token'])` **inside every method** →
  auth is scattered across hundreds of methods instead of enforced once at the boundary.
- They return `Success($detail)` / `{Status,Code,Detail}` **envelopes** → the core emits a wire format.

There is **no versioning, no OpenAPI/Swagger, no formal documentation, and no developer portal.**

## Architectural Approach

We do **not** drop a thin REST adapter directly on top of `class.*` — that would build an
adapter-over-adapter and make v2 inherit v1's leaks (token-in-payload, per-method auth,
envelope-shaped returns). Instead we introduce a **transport-agnostic application-service layer
as the seam**, and bind the REST transport to it. This is the **strangler-fig** pattern: the new
seam wraps the old logic, new transports bind to the seam, and logic migrates into the seam over
time. It is incremental and safe — legacy SOAP/RPC keep working untouched.

### Layers

| Layer | Location | Role |
|---|---|---|
| **REST transport** | `orkapi/` (new top-level) | Router, auth middleware (resolve caller → `Identity`), `Rest{Resource}Controller`s carrying swagger-php attributes, the Scalar developer portal |
| **Application services (the contract)** | `system/lib/app/` (new, PSR-4) | Typed services (`PlayerService::getPlayer(int $id, Identity $caller): PlayerDTO`), DTOs, typed exceptions. **No token strings, no envelopes.** Initially delegates to legacy. |
| **Legacy domain** | `system/lib/ork3/class.*.php` | **Untouched.** Strangled over time. |
| **Legacy transports** | `orkservice/` (SOAP + JSON-RPC) | **Untouched** = de-facto v1; nothing breaks. |

The REST layer stays thin — the difference from the rejected approach is *what it is thin over*:
a clean contract we own, not the leaky RPC shape.

### Request flow

```
HTTP  →  /api/v2/{resource}/{id}/...            (orkapi/ front controller)
        ↓ RestRouter        parse verb + path → resource + id + subresource
        ↓ AuthMiddleware    Bearer/session token → Identity (resolved caller, once)
        ↓ Rest{Resource}Controller   thin; swagger-php attributes live here
        ↓ {Resource}Service (system/lib/app/)   typed params + Identity → DTO | throws
        ↓ class.{Resource}.php   EXISTING logic, untouched (delegated to, strangled over time)
        ↑ ResponseEnvelope  DTO → REST JSON + correct HTTP status code; exceptions → status codes
```

### Auth model

- Auth is a **boundary concern**: `AuthMiddleware` resolves the caller into an `Identity` value
  object once. Services enforce `AUTH_*` scopes via the `Identity`, not via a token string in a
  payload.
- **Credential/key issuance (PAT / API keys) is out of scope today.** Scalar's "try it" console
  and live v2 calls reuse the **existing token / session mechanism** for now. Dedicated credential
  issuance is a clearly-marked future phase.

### Self-documentation (code-first)

- Each controller method and each DTO carries **PHP 8 attributes** via `zircote/swagger-php`
  (`#[OA\Get]`, `#[OA\Response]`, `#[OA\Schema]`, …).
- `bin/openapi-gen.php` scans the `orkapi/` + DTO tree → emits **`openapi.json` (OpenAPI 3.1)**,
  served at `GET /api/v2/openapi.json` (cached).
- Because the spec is generated from real DTOs and controller attributes, **it cannot drift from
  the code**. This is the literal mechanism for "self-documenting."
- A curated **overlay** (descriptions/examples/prose that attributes can't cleanly express) is
  merged in at generation time. Overlay is the exception, not the rule.

### Versioning & coexistence

- Path-based versioning: `/api/v2/...` is the new surface.
- Legacy SOAP + JSON-RPC stay exactly as they are = de-facto **v1**; existing consumers are
  unaffected (Goal 5). We do not retrofit OpenAPI onto v1.
- A future `/api/v3` would be a parallel tree, not a rewrite.

### Standard REST semantics

- `GET` → 200 / 404; `POST` → 201; `PUT`/`PATCH` → 200; `DELETE` → 204.
- Validation failures → 422; auth → 401 (unauthenticated) / 403 (unauthorized); server → 500.
- One consistent error envelope: `{ "error": { "code": "...", "message": "...", "details": ... } }`.
- Resource naming is plural-noun, lowercase (`/players`, `/awards`, `/events`).

### Developer portal + "Authorized API Developers" tool

- **Portal:** new route (`Developer/index`) renders a template embedding **Scalar** pointed at
  `/api/v2/openapi.json`. Dark-mode compatible (standing project rule).
- **Gate:** visible only to logged-in users who are **ORK Admins (always)** OR present in a new
  allowlist table `ork_api_developer`.
- **Allowlist tool:** new admin surface (sidebar entry in `Admin_index.tpl`) backed by
  `ork_api_developer` (`mundane_id, granted_by, granted_at, note`). Add-developer uses the
  **global unscoped** player-search pattern (`kn-ac-results`) — designating a developer is
  inherently cross-kingdom, consistent with the documented unit-member / award-giver search
  exceptions. URL built with `&q=`, dropdown positioned via `tnFixedAcPosition`, curl-tested to
  return rows. Removal uses `tnConfirm()` (no native dialogs).

### Claude SDLC to keep docs current (Goal 6)

- **Reference doc** in `agent-instructions/` codifying v2 REST conventions: resource naming, verb
  mapping, the error envelope, attribute requirements, the service/DTO seam pattern, and the
  strangler-fig rule (new logic goes in `system/lib/app/`, never back into `class.*`).
- **`.githooks` / CI check:** regenerate `openapi.json` and **fail the commit if a v2 endpoint
  lacks required attributes or the spec fails OpenAPI 3.1 validation** — an endpoint cannot merge
  undocumented.
- **CLAUDE rule:** when adding/changing a v2 endpoint, update its swagger-php attributes and
  regenerate the spec; use the overlay only for what attributes can't express.

## Component Inventory (new code)

**`orkapi/` (new top-level tier)**
- Front controller + `RestRouter` (verb + path → resource/id/subresource).
- `AuthMiddleware` + `Identity` value object.
- `ResponseEnvelope` / error mapping (DTO ↔ JSON, exception ↔ HTTP status).
- `BaseRestController` + one `Rest{Resource}Controller` per resource (swagger-php attributes).
- Scalar portal template + assets.
- `bin/openapi-gen.php` + cached `openapi.json` endpoint.

**`system/lib/app/` (new application-service layer, PSR-4)**
- `Identity` (caller identity + scope checks).
- One `{Resource}Service` per resource (typed methods, delegate to legacy initially).
- DTO classes per resource (attributed for schema generation).
- Typed exception hierarchy (NotFound, Validation, Unauthorized, Forbidden, Conflict, …).

**Data + admin**
- Migration: `ork_api_developer` table.
- `controller.Developer.php` (portal) + gate logic.
- Authorized-API-Developers admin tool (template + AJAX + `Admin_index.tpl` sidebar entry).

**SDLC**
- `agent-instructions/` REST-conventions reference.
- `.githooks` / CI spec-generation-and-validation check.
- CLAUDE rule entry.

## Sequencing

### Phase 1 — Foundation + Player pilot
Build the full vertical slice once, end-to-end, to establish the reference template:
`orkapi/` router, `AuthMiddleware` + `Identity`, response/error envelope, `BaseRestController` +
attribute conventions, `PlayerService` + Player DTOs (strangler over `class.Player`),
`bin/openapi-gen.php`, Scalar portal, `ork_api_developer` migration + Authorized-Developers tool.
Player **reads first** (`GET /players/{id}`, `GET /players`), then **writes**
(`POST`, `PATCH`, `DELETE`), all under test.

### Phase 2 — Parallel fan-out
One agent per remaining resource, each following the Player template (service + DTOs + controller +
attributes + tests): Award, Event, Kingdom, Park, Unit, Attendance, Tournament, Report, Search,
Heraldry, Calendar, Treasury, Map, Notification, Principality, Pronoun, DataSet.

### Phase 3 — SDLC hardening
Claude conventions reference, CI/`.githooks` spec gen-and-validate check, CLAUDE rule, and
legacy-vs-v2 documentation.

## Decisions Locked

- **OpenAPI 3.1** (not 3.0).
- **`zircote/swagger-php`** as the attribute→spec generator.
- **Scalar** as the FOSS docs UI.
- **Code-first** documentation (spec generated from attributes + DTOs; overlay for the rest).
- **Application-service seam (strangler fig)** — not a thin adapter over `class.*`, not a full
  domain rewrite.
- **Pilot (Player) → parallel fan-out** rollout.
- **Path-based versioning** (`/api/v2/`); legacy untouched as v1.
- **Auth at the boundary** via `Identity`; **credential/key issuance deferred** (out of scope today).
- Developer portal gated to **ORK Admins + `ork_api_developer` allowlist**.

## Out of Scope (today)

- API key / Personal Access Token issuance and management (future phase; v2 reuses existing
  token/session auth for now).
- Retrofitting OpenAPI onto the legacy SOAP/JSON-RPC surfaces.
- Rewriting `class.*` business logic into a pure domain layer (strangled incrementally instead).
- OAuth2 third-party app registration.

## Testing Strategy

- Each application service is unit-tested independently of transport (typed in, typed out).
- Each REST controller is integration-tested over HTTP (status codes, envelope shape, auth gating).
- The generated `openapi.json` is validated against OpenAPI 3.1 in CI.
- Player pilot is curl-tested end-to-end (auth, reads, writes, error paths) before fan-out begins.
- Authorized-Developers player search is curl-tested to return rows before "done" (project rule).
