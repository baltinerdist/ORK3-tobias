# Notifications System — Design

**Date:** 2026-06-20
**Branch:** `feature/social-features`
**Status:** Approved design, pending implementation plan

## Purpose

Establish the foundation of an in-product Notifications system for the ORK — the
plumbing that future social features (friend requests, comments, follows) will
hang off of. v1 ships with two real notification sources to prove the foundation
end-to-end: **awards/recommendations** (automatic, server-side) and a generic
**announcement** type (officer/admin-composed).

This is in-app only. No email, no push, no real-time, no polling — the badge
reflects state at page-load time (notifications are occasional; nobody needs
sub-page-load freshness).

## Non-goals (v1)

- Real-time or polling delivery (websockets, Memcache heartbeat, toast-on-arrival).
- Toast/snackbar primitive (none exists today; not needed for this surface).
- A dedicated "all notifications" history page (the schema supports adding one
  later for free; not built now).
- Retention/cleanup job (rows kept indefinitely in v1).
- Per-type re-rendering or localization (we snapshot rendered content).

## Architecture overview

Follows the established three-layer pattern:

```
index.php?Route=NotificationAjax/action
  → orkui/controller/controller.NotificationAjax.php   (Controller_NotificationAjax)
  → orkui/model/model.Notification.php                 (thin pass-through)
  → Ork3::$Lib->notification                           (system/lib/ork3/class.Notification.php)
  → $DB / yapo on ork_notification
```

The bell UI lives in the global chrome (`orkui/template/default/default.theme`,
inside `#controls`), modeled on the existing What's New modal wiring.

## 1. Data model

One table, `ork_notification`, **fanned out one row per recipient** (an
announcement to a kingdom = one bulk insert of N rows). This keeps per-user
`read`/`dismissed` flags trivial and consistent across all notification types.

| column | type | purpose |
|---|---|---|
| `notification_id` | PK auto-inc | |
| `mundane_id` | int, indexed | recipient |
| `type` | varchar | `award`, `rec_status`, `announcement` — drives icon/styling, future grouping |
| `title` | varchar | **snapshot** — rendered headline |
| `body` | text, null | **snapshot** — optional longer text |
| `icon` | varchar, null | **snapshot** — FontAwesome class (defaulted per type if null) |
| `link_url` | varchar, null | **snapshot** — click target |
| `payload` | json/text, null | future use (e.g. `{"award_id":123}`); **not read by v1 UI** |
| `read_at` | datetime, null | null = unread (drives badge count) |
| `dismissed_at` | datetime, null | null = visible in panel |
| `created_by` | int, null | sender mundane_id (null for system/award); audit |
| `created_at` | datetime, indexed | newest-first ordering |

**Index:** `(mundane_id, dismissed_at, created_at)` covers the panel query and the
unread-count query.

**Migration:** `db-migrations/2026-06-20-add-notification.sql` (copy the style of
`db-migrations/2026-03-22-add-whats-new-seen.sql`; applied manually — no runner).

### Content storage decision (hybrid)

Render from the **denormalized snapshot** columns (`title`/`body`/`icon`/`link_url`)
— display is dumb and robust against later data changes or deletes, and adding a
new source needs no UI render code. Keep `type` + nullable `payload` so future
social features can group ("3 people commented") or render richer without a schema
change. v1 UI never reads `payload`.

## 2. Layers

### `system/lib/ork3/class.Notification.php`

Auto-registers as `Ork3::$Lib->notification` (startup.php scan). The **only** place
with `$DB`/yapo work; every method calls `$DB->Clear()` first. Methods:

- `Create($mundaneId, $type, array $fields)` — single insert; `$fields` =
  title/body/icon/link_url/payload/created_by.
- `CreateBulk(array $mundaneIds, $type, array $fields)` — fan-out, one bulk insert.
- `GetForMundane($mundaneId, $limit = 15)` — recent non-dismissed, newest-first.
- `UnreadCount($mundaneId)` — `COUNT(*) WHERE read_at IS NULL AND dismissed_at IS NULL`.
- `MarkRead($mundaneId, $ids = null)` — `$ids` array, or null = all unread for user.
- `Dismiss($mundaneId, $notificationId)` — sets `dismissed_at`; scoped to user.

All write methods scope by `$mundaneId` so a user can only mutate their own rows.

### `orkui/model/model.Notification.php`

Thin pass-through (`new APIModel('Notification')`), forwarding to the lib.

### `orkui/controller/controller.NotificationAjax.php`

`Controller_NotificationAjax extends Controller`. **Must be added to the
`$_skipTokenCheck` allow-list in `system/lib/system/class.Controller.php`** (else
the stale-session redirect logic fires on AJAX). Each method: set JSON header,
auth-guard on `$this->session->user_id`, read/sanitize input, call model, echo
`json_encode`. Return shape: `{status: 0, ...}` on success, `{status: 1, error}`
on failure (matching PlayerAjax convention).

## 3. AJAX endpoints

- `NotificationAjax/list` → `GetForMundane(user_id)` as JSON (icon, title, body,
  link_url, relative time, read flag, id).
- `NotificationAjax/mark_read` → `MarkRead(user_id, ids|all)`.
- `NotificationAjax/dismiss` → `Dismiss(user_id, id)`.
- `NotificationAjax/send` → announcement composer submit. **Auth-gated by audience:**
  global requires `AUTH_ADMIN`; a kingdom/park audience requires
  `HasAuthority(user_id, AUTH_KINGDOM|AUTH_PARK, scopeId, AUTH_ADMIN/EDIT)`.
  Resolves recipient mundane_ids for the audience, then `CreateBulk`.

All writes except `send` are scoped to `session->user_id`. `send` is gated by the
audience-authority check.

## 4. Bell UI — `default.theme`, inside `#controls`

Gated by `$this->__session->token != null`.

- **Bell icon + unread-count badge.**
- **Render strategy:** unread **count** queried **inline at page render** (tiny
  indexed query against the new index, in the existing inline-`$DB->DataSet`
  style used for persona/home-park — remember `$DB->Clear()`). The **list is
  lazy-fetched** via `NotificationAjax/list` the first time the bell opens, so
  every page load stays cheap (count only).
- **Dropdown panel:** newest-first non-dismissed items; each = icon + title +
  body + relative time, clickable → `link_url`. Per-item dismiss **X**.
  "Mark all read" action. Empty state: "You're all caught up."
- **Read-on-reading:** opening the dropdown fires `mark_read` for the unread items
  shown → badge clears. Items remain in the panel until explicitly dismissed.
- **Conventions:** dark-mode overrides from the start (`html[data-theme="dark"]`);
  `data-tip` CSS tooltips, never native `title`; `tnFixedAcPosition`-style fixed
  positioning not needed (dropdown is in chrome, not a modal). JS helper added to
  the theme / `revised.js` following the bespoke open/close-function convention.

## 5. Announcement composer (generic source)

- **"Notify Members" button** on Kingdom/Park management surfaces, plus an admin
  global equivalent.
- Bespoke modal (copy the What's New / email-prompt overlay pattern): **title**,
  **body**, optional **link**. Audience is **inferred from launch context** (this
  park / this kingdom / global for admin) — not a free picker in v1.
- Submits to `NotificationAjax/send`.

## 6. Award / rec triggers (automatic source)

Hook existing server-side flows in `system/lib/ork3/class.Award.php`:

- **Award granted to a player** → `Notification::Create` for the recipient:
  "You received {award}", link to their awards. `type = award`.
- **Recommendation status change** (approved / awarded) → notify the recommender.
  `type = rec_status`.

Notification creation is best-effort and must never block or fail the underlying
award/rec save (wrap defensively).

If scope needs trimming, "award granted" alone is an acceptable v1 floor with
"rec status" as a fast follow.

## 7. Decisions

- **Retention:** keep all rows (including dismissed) indefinitely. Cheap; enables a
  future history page for free.
- **No toast, no polling.** Badge reflects page-load state only.
- **Fan-out on send** (one row per recipient) rather than broadcast + read-state
  table — simpler flags, fine for occasional, MySQL-cheap bulk inserts.

## Testing

- Lib methods exercised via the local curl-auth session pattern (login once, one
  cookie jar; app enforces single-device sessions).
- Verify: create (single + bulk) → unread count → list → mark read clears badge →
  dismiss hides from panel but row persists → auth scoping (user can't mutate
  another user's rows; non-officer can't `send` to a kingdom).
- Award trigger verified by granting an award and confirming the recipient row.
- Dark-mode walk of bell + dropdown + composer modal before "done."
