# Shortcut Links (`/me/…` vanity redirects) — Design

**Date:** 2026-06-30
**Status:** Approved design, ready for implementation plan

## Summary

Let players, kingdoms, parks, and units generate short, shareable links to their
public profiles, served from the domain root under `/me/`:

```
ork.amtgard.com/me/tobias   →  302  →  .../index.php?Route=Player/profile/46193
```

Every entity automatically has a **derived default** link (type-prefix + id) that
always works with zero storage. Owners (and ORK admins) may additionally claim a
**custom stub** that overrides the default. One custom stub per entity; changing it
instantly releases the old one for reuse.

`me/tobias` is just an example of a custom stub one player chose — it is **not** a
per-user naming pattern. The universal pattern is the derived form below.

## Goals

- A clean, memorable URL per entity, shareable off-platform.
- Zero-config defaults: every Player/Kingdom/Park/Unit resolves immediately.
- Opt-in custom stubs owned by the entity's controller, with live availability
  feedback before saving.
- Strict, abuse-resistant validation; custom stubs can never shadow a derived link.

## Non-Goals

- No redirect history / grace-period redirects for released stubs (a released stub
  is immediately claimable by anyone).
- No analytics / click counting (YAGNI; can be added later).
- No bulk admin management screen in v1 (per-entity card only; ORK admins use the
  same per-entity card via their override authority).

## URL & Resolution Flow

### Web-server rewrite (infra change, deployed with the code)

The app lives under `/orkui/`; production currently runs `RewriteEngine Off`. We add
a scoped rule that maps the bare `/me/{stub}` path to the existing query-string router:

```apache
RewriteEngine On
RewriteRule ^me/([A-Za-z0-9_-]+)/?$ /orkui/index.php?Route=Me/go/$1 [L,QSA]
```

This is the only infrastructure change. Everything else is application code.

### Resolver

A new lightweight `Controller_Me` with a single action `go($stub)`. It performs **no
raw DB work** — it delegates resolution to the model/lib layer (see Backend Layer) and
only issues the HTTP redirect or renders the not-found view.

Resolution order:

1. **Derived default** — if `$stub` matches `^(pl|k|p|u)\d+$`, decode the prefix to a
   type and the digits to an id:
   - `pl` → Player → `Player/profile/{id}`
   - `k`  → Kingdom → `Kingdom/profile/{id}`
   - `p`  → Park → `Park/profile/{id}`
   - `u`  → Unit → `Unit/index/{id}`

   The `pl` alternative is listed before `p` so the longer player prefix wins. The
   target entity is verified to exist/active before redirecting; if not, fall through
   to the not-found view. Derived links need **zero storage** and are checked first.
2. **Custom stub** — otherwise look up `ork_shortlink.slug` (lowercased). On hit,
   redirect to the stored entity's canonical profile (verifying it still exists/active).
3. **Miss / deleted entity** — render a friendly "shortcut link not found" view (a
   styled page with a player/org search box), not a raw 404.

### Redirect status code

All redirects use **302 (temporary)**, including derived ones, so that releasing and
reassigning a custom stub can never be defeated by a browser/proxy caching a `301`
permanently. The cost (no permanent-redirect SEO consolidation) is irrelevant for an
internal record-keeping app.

### Canonical targets

| Type    | Prefix | Canonical route          |
|---------|--------|--------------------------|
| Player  | `pl`   | `Player/profile/{id}`    |
| Kingdom | `k`    | `Kingdom/profile/{id}`   |
| Park    | `p`    | `Park/profile/{id}`      |
| Unit    | `u`    | `Unit/index/{id}`        |

## Data Model

One migration in `db-migrations/` (e.g. `2026-06-30-shortcut-links`), one table.
**Only custom stubs are stored** — derived defaults never touch this table.

```sql
CREATE TABLE IF NOT EXISTS `ork_shortlink` (
  `shortlink_id` int(11)      NOT NULL AUTO_INCREMENT,
  `slug`         varchar(30)  NOT NULL,
  `entity_type`  enum('player','kingdom','park','unit') NOT NULL,
  `entity_id`    int(11)      NOT NULL,
  `created_by`   int(11)      NOT NULL,        -- mundane_id who last set it
  `created`      timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `modified`     timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`shortlink_id`),
  UNIQUE KEY `uq_slug` (`slug`),                       -- global slug uniqueness
  UNIQUE KEY `uq_entity` (`entity_type`, `entity_id`)  -- one custom stub per entity
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
```

(MyISAM + latin1 to match existing ORK tables.)

### Behavior that falls out of the schema

- **One stub per entity** — enforced by `uq_entity`. Setting a stub for an entity that
  already has one is an **UPDATE of `slug` on the same row**, not a new row.
- **Releasing on change** — because it's an in-place `slug` update, the previous slug is
  instantly free for anyone (no history kept), matching the intended behavior.
- **No collisions** — `uq_slug` plus the validation rules below guarantee a custom slug
  is globally unique and can never equal a derived link.

## Backend Layer

All DB access lives in **`system/lib/ork3/class.ShortLink.php`** (yapo-backed). The
controller(s) and `orkui/model/` are thin pass-throughs with **no raw `$DB`** — per the
project's architecture-layers rule. Follow the `$DB->Clear()`-before-write convention.

### `class.ShortLink.php` methods

- `Resolve($stub)` → returns `['type'=>…, 'id'=>…]` or false. Implements the derived /
  custom / miss order above, including the existence/active check on the target entity.
- `CheckAvailability($slug)` → validates format + checks `uq_slug` not taken (excluding
  the caller's own current stub when editing). Returns available/taken + reason.
- `SetStub($entityType, $entityId, $slug, $mundaneId)` → validates, enforces authority,
  upserts the single row for that entity.
- `GetStubFor($entityType, $entityId)` → current custom slug (or null → caller uses the
  derived default for display).
- `ReleaseStub($entityType, $entityId)` → deletes the entity's custom stub row (revert
  to derived default).

### Validation (all centralized in the lib class)

- Lowercased before all checks and storage (case-insensitive).
- Format: `^[a-z][a-z0-9_-]{2,29}$` (3–30 chars, must start with a letter; letters,
  digits, hyphen, underscore).
- Reject anything matching the reserved default pattern `^(pl|k|p|u)\d+$` — a custom
  stub can never shadow a derived link.
- Reject a reserved-word list: `me, admin, login, logout, api, assets, orkui,
  orkservice, index, profile, search, home, about` (extendable).

### Authority (enforced server-side on every write)

Uses the existing `Ork3::$Lib->authorization->HasAuthority` gates, same ones that guard
editing each profile:

- **Player** — self only (the logged-in mundane editing their own profile).
- **Park** — `AUTH_PARK` over the park.
- **Kingdom** — `AUTH_KINGDOM` over the kingdom.
- **Unit** — unit manager of that unit.
- **ORK site admin** — `AUTH_ADMIN`, may set any of the above (support path).

### Controller / model wiring

- `orkui/controller/controller.Me.php` — `Controller_Me::go($stub)`: calls
  `Ork3::$Lib->shortlink->Resolve()` (via the model pass-through), then
  `header('Location: …', true, 302)` or renders the not-found view.
- `orkui/controller/controller.ShortLinkAjax.php` — `check` (live availability) and
  `save` actions for the management UI; each re-derives the acting `mundane_id` from the
  session (`$this->session->user_id`) and re-checks authority via the lib layer. May
  alternatively be folded into the existing per-entity Ajax controllers if that fits the
  surrounding code better; the lib-layer boundary is the firm requirement.
- `orkui/model/model.ShortLink.php` — thin pass-through to the lib class (and any cache
  busting if profile caches embed the stub).

## Management UI

A small **"Shortcut Link"** card added to each entity's existing edit/management surface
(Player profile edit page; Kingdom/Park/Unit management pages). The card:

- Shows the current live short URL — the custom stub if set, otherwise the derived
  default (`me/pl46193`, `me/k17`, …) — with a **copy-to-clipboard** button.
- Provides an input rendered with a static `ork.amtgard.com/me/` prefix, a **debounced
  live availability check** (AJAX → `ShortLinkAjax/check`) showing green ✓ available /
  red ✗ taken with the reason, and a **Save** button (→ `ShortLinkAjax/save`).
- Optionally a "Reset to default" affordance (→ `ReleaseStub`).
- Must be **dark-mode compatible** (`html[data-theme="dark"]`), use **in-product
  tooltips** (`data-tip`, never native `title`), and **no native `confirm()`/`alert()`**
  (use `tnConfirm()` if any confirmation is needed) — per project conventions.

## Error Handling

- Invalid stub format / reserved / taken → availability check returns a clear reason;
  save is rejected server-side with the same validation (never trust the client).
- Stub resolves to a deleted/inactive entity → not-found view, and (optionally) the
  stale row is ignored. We do not auto-delete on resolve in v1.
- Unauthorized save attempt → `NoAuthorization()`, no DB write.
- Concurrent claim of the same slug → `uq_slug` makes the second write fail; surface as
  "that link was just taken."

## Testing

- **Lib unit-level (manual/curl):** validation matrix (good/bad/reserved/pattern-shadow
  cases); derived resolution for all four prefixes incl. `pl` vs `p` precedence; custom
  resolution; set → change → old-slug-now-free; authority denials per entity type.
- **Routing:** rewrite maps `/me/{stub}` to `Me/go`; 302 Location header correct for
  derived and custom; not-found view renders for misses and deleted targets.
- **UI:** live availability check (available / taken / invalid), save round-trip, copy
  button, reset-to-default; dark-mode walk of the card on all four surfaces.

## Open / Deferred

- Click analytics — deferred.
- Bulk admin management screen — deferred (per-entity card covers v1, incl. admin
  override).
- Reserved-word list is a starting set; easy to extend in the lib class.
