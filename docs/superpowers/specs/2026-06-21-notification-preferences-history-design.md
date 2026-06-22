# Notification Preferences + History — Design

**Date:** 2026-06-21
**Branch:** `feature/social-features`
**Status:** Approved design, pending implementation plan

## Purpose

Two user-facing extensions to the existing Notifications system
(`docs/superpowers/specs/2026-06-20-notifications-system-design.md`), both pure
add-ons — **no new social graph, no new notification source**:

1. **Per-type preferences** — a user can mute/unmute each notification *type*
   (`award`, `rec_status`, `announcement`, `friend_request`, `friend_accept`,
   `event_reminder`, `event` (new-event alerts), `reaction`, `unit_announcement`,
   …). A muted
   type simply produces **no row** for that user at fan-out time (`Create` /
   `CreateBulk` / `CreateBulkOnce`), so muted users never see, count, or persist
   the notification.
2. **History page** — a full `Notifications/index` page (logged-in only) listing
   **all** of the user's notifications including read and dismissed, paginated,
   filterable by type, with per-item actions (mark read / dismiss / open) and a
   "mark all read". Linked from the bell dropdown's new "See all" footer.

Everything stays in-app only (no email/push/polling), consistent with the
foundation spec.

## Decisions (locked)

- **Preference storage = a small `ork_notification_pref` table**, keyed
  `(mundane_id, type, enabled)`, **default = enabled (opt-out model)**. Absence of
  a row means "enabled" — we only persist *mutes* (and explicit re-enables).
  Rationale: types are an open, growing set; an opt-out model means new types are
  on by default for everyone with zero backfill, and the table stays tiny (only
  users who muted something have rows). Mirrors the EAV-ish "store the exception"
  habit elsewhere in the app.
- **Suppression happens in the lib at fan-out time**, inside
  `class.Notification.php` (`Create`, `CreateBulk`, `CreateBulkOnce`) — the single
  `$DB` layer. We filter the recipient set against muted prefs **before** the
  insert, so a muted user gets no row at all (no count, no history, no panel item).
  This is the only correct place: it covers every current and future caller for
  free (award triggers, announcement composer, event reminders, friend events)
  without each call site re-implementing the check.
- **Some types are NON-muteable** and are exempt from the preference check:
  `announcement` (officer/admin broadcasts — kingdom/park business a member is
  expected to receive) and any future `system`/`admin` critical type. Justification:
  these are authority-gated, low-volume, and often operationally important (event
  cancellations, rules changes); letting members silently opt out of their own
  kingdom's official announcements defeats the purpose of the composer. The
  non-muteable set is a hard-coded allow-list constant in the lib
  (`$ALWAYS_ON`), and the preferences UI hides/locks those rows so a user is never
  shown a toggle that does nothing.
- **Preferences UI surface = a settings panel reached from the bell dropdown** via
  a gear icon in the panel header (next to "Mark all read"), opening a bespoke
  `np-` namespaced modal overlay (same self-contained pattern as the existing
  Announcement Composer `nc-` overlay in `default.theme`). Chosen over bolting it
  onto a player design tab because (a) the notifications surface already lives in
  global chrome (`default.theme`) and is where the user's mental model of
  "notifications" lives, (b) it needs no per-page wiring, and (c) it is reachable
  from every page. The same modal is also linked from the History page header so
  the two features cross-link.
- **History page = a real controller page** `Notifications/index` rendering a
  plain-PHP template, server-rendering page 1, with type-filter + paging via a new
  `NotificationAjax/history` endpoint. Reuses the existing `mark_read` / `dismiss`
  endpoints unchanged for per-item actions.
- **Pagination = limit/offset** (simple, page-numbered), 25 rows/page. Notification
  volume per user is low; no need for the 500-row cluster/infinite-scroll machinery
  used by Recs Manager.

## Non-goals (v1)

- Email / push / digest delivery of any kind. Preferences govern in-app rows only.
- Per-scope or per-sender granularity (e.g. "mute announcements from Park X but not
  Kingdom Y") — type-level only.
- Snooze / quiet-hours / frequency caps.
- A "mute this specific thread" affordance on individual items.
- Retention/cleanup of history rows (kept indefinitely, same as foundation).
- Bulk dismiss on the history page (per-item dismiss + mark-all-read only).

## Architecture overview

Same three-layer pattern as the foundation:

```
Preferences read/write + suppression
  index.php?Route=NotificationAjax/{prefs|set_prefs}
    → orkui/controller/controller.NotificationAjax.php   (Controller_NotificationAjax)
    → orkui/model/model.Notification.php                 (thin pass-through)
    → Ork3::$Lib->notification                           (class.Notification.php)
    → $DB / yapo on ork_notification_pref + suppression filter on ork_notification

History page
  index.php?Route=Notifications/index
    → orkui/controller/controller.Notifications.php       (NEW, Controller_Notifications)
    → model.Notification.php → Ork3::$Lib->notification    (GetHistory / CountHistory)
  index.php?Route=NotificationAjax/history  (filter + paging)
```

Note the controller-name split mirroring Friends: the **page** controller is
`Controller_Notifications` (plural, route `Notifications/index`), the **JSON**
controller stays `Controller_NotificationAjax` (already on the allow-list). No new
Ajax *controller* is introduced — only new *actions* on the existing one — so the
`$_skipTokenCheck` list does not change, but this is called out below as a
checklist item to confirm.

## 1. Data model

### `ork_notification_pref` (NEW)

One row **only when a user has set a non-default preference for a type**. Absence =
enabled.

| column | type | purpose |
|---|---|---|
| `pref_id` | int PK auto-inc | |
| `mundane_id` | int, NOT NULL | the user |
| `type` | varchar(32), NOT NULL | notification type slug (matches `ork_notification.type`) |
| `enabled` | tinyint(1), NOT NULL, default 1 | 0 = muted, 1 = explicitly enabled |
| `updated_at` | datetime, NOT NULL, default CURRENT_TIMESTAMP | audit / last toggle |

**Indexes:**
- `UNIQUE KEY uniq_user_type (mundane_id, type)` — upsert target; one pref per
  (user, type). Also serves the suppression read.

**Suppression read** uses `WHERE mundane_id IN (...) AND type = '<type>' AND
enabled = 0` against this unique key — the only users filtered are those with an
explicit mute row, so the scan is bounded by mute count, not recipient count.

**Migration:** `db-migrations/2026-06-21-add-notification-pref.sql` — copy the
style of `db-migrations/2026-06-20-add-notification.sql` and
`2026-03-22-add-whats-new-seen.sql`: additive, idempotent (`CREATE TABLE IF NOT
EXISTS`, `ADD COLUMN/INDEX IF NOT EXISTS`), applied manually (no runner).

```sql
CREATE TABLE IF NOT EXISTS `ork_notification_pref` (
  `pref_id` int(11) NOT NULL AUTO_INCREMENT,
  `mundane_id` int(11) NOT NULL,
  `type` varchar(32) NOT NULL,
  `enabled` tinyint(1) NOT NULL DEFAULT 1,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`pref_id`),
  UNIQUE KEY `uniq_user_type` (`mundane_id`, `type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### `ork_notification` (UNCHANGED)

No schema change. History queries reuse existing columns and add **one new index**
to cover the unfiltered history scan (the foundation's `recipient_panel` index has
`dismissed_at` in the middle, so it does not cover history which includes dismissed
rows). Add in the same migration file:

```sql
ALTER TABLE `ork_notification`
  ADD INDEX IF NOT EXISTS `recipient_history` (`mundane_id`, `created_at`);
```

This index covers `GetHistory` ordering (`WHERE mundane_id = X [AND type = ?] ORDER
BY created_at DESC`).

## 2. Layers

### `system/lib/ork3/class.Notification.php` (extended)

Add the canonical type registry, the non-muteable allow-list, the suppression
helper, the preference CRUD, and the history methods. Every new method calls
`$this->db->Clear()` before any raw `Execute`/`query`/`DataSet` (hard rule), and
all write/read methods scope by `$mundaneId` so a user only touches their own rows.

New constants / static maps (add near `$DEFAULT_ICONS`):

```php
/** Canonical muteable type registry → human label (drives the prefs UI). */
private static $TYPE_LABELS = [
    'award'             => 'Awards you receive',
    'rec_status'        => 'Recommendation status updates',
    'friend_request'    => 'Friend requests',
    'friend_accept'     => 'Friend request accepted',
    'event_reminder'    => 'Upcoming event reminders',
    'event'             => 'New events near you',
    'reaction'          => 'Reactions to your activity',
    'unit_announcement' => 'Company / household announcements',
];

/** Types a user can NEVER mute (authority-gated, operationally important). */
private static $ALWAYS_ON = ['announcement', 'system', 'admin'];
```

New methods:

- `GetMuteableTypes()` → `array` — returns `[ ['type'=>..,'label'=>..,'icon'=>..],
  ... ]` from `$TYPE_LABELS` + `ResolveIcon`. Drives the prefs UI; the controller
  merges in the user's current state.
- `GetPrefs($mundaneId)` → `['Status'=>0,'Prefs'=>[type => bool enabled]]` —
  reads `ork_notification_pref` for the user; every muteable type defaults to
  `true` (enabled) unless an explicit `enabled=0` row exists. `$DB->Clear()` first.
- `SetPref($mundaneId, $type, $enabled)` → `['Status'=>0|1,'Error'=>?]` —
  upsert one (user, type) row. Rejects types in `$ALWAYS_ON` (returns Status 1)
  and types not in `$TYPE_LABELS` (unknown). Uses
  `INSERT ... ON DUPLICATE KEY UPDATE enabled = VALUES(enabled), updated_at =
  NOW()` against `uniq_user_type`. `$DB->Clear()` first; parameterized via
  `SetData`/`Execute` (or strict int/`(int)$enabled` interpolation per file
  convention).
- `SetPrefs($mundaneId, array $typeEnabledMap)` → bulk save the whole panel in one
  transaction-ish loop (each is an idempotent upsert); skips `$ALWAYS_ON`.
- `private FilterMutedRecipients(array $mundaneIds, $type)` → `int[]` — the
  suppression core. If `$type` is in `$ALWAYS_ON`, returns the list unchanged.
  Otherwise reads the muted set
  (`SELECT mundane_id FROM ork_notification_pref WHERE enabled = 0 AND type =
  '<safeType>' AND mundane_id IN (<intlist>)`), and returns the input minus those
  ids. `$DB->Clear()` first; `$type` sanitized to `[A-Za-z0-9_]` before
  interpolation (same approach as `CreateBulkOnce`).
- `GetHistory($mundaneId, array $filters = [], $limit = 25, $offset = 0)` →
  `['Status'=>0,'Notifications'=>[...]]` — like `GetForMundane` but **includes
  read AND dismissed rows**, supports `$filters['type']` (validated against
  `$TYPE_LABELS` + `$ALWAYS_ON`; ignored if unknown), and returns the same item
  shape plus `'Dismissed' => (bool)`, `'CreatedAt'`, `'Ago'`. `LIMIT`/`OFFSET` are
  int-cast. Ordered `created_at DESC, notification_id DESC`. `$DB->Clear()` first.
- `CountHistory($mundaneId, array $filters = [])` → `int` — `COUNT(*)` with the
  same optional type filter, for pagination math. `$DB->Clear()` first.

**Suppression wiring inside existing methods (the load-bearing change):**

- `Create($mundaneId, $type, $fields)` — before building the yapo row, call
  `FilterMutedRecipients([$mundaneId], $type)`; if it comes back empty, **return a
  success no-op** `['Status'=>0,'Suppressed'=>true]` (NOT an error — a muted send
  succeeded by design and must never break the award/rec save, which is
  best-effort).
- `CreateBulk($mundaneIds, $type, $fields)` — replace the normalized `$ids` with
  `FilterMutedRecipients($ids, $type)` immediately after dedupe/normalization and
  before the chunked INSERT. Zero remaining → existing `['Status'=>0,'Count'=>0]`.
- `CreateBulkOnce(...)` — apply `FilterMutedRecipients` to `$remaining` after the
  dedupe-by-payload step, before delegating to `CreateBulk` (so it composes; the
  `CreateBulk` call would filter again harmlessly, but filter once here to keep the
  Skipped/Count accounting accurate).

### `orkui/model/model.Notification.php` (extended)

Thin pass-throughs, one per new lib method (same style as existing forwarders):

```php
public function get_muteable_types()                 { return $this->Notification->GetMuteableTypes(); }
public function get_prefs($mundaneId)                { return $this->Notification->GetPrefs($mundaneId); }
public function set_pref($mundaneId, $type, $on)     { return $this->Notification->SetPref($mundaneId, $type, $on); }
public function set_prefs($mundaneId, array $map)    { return $this->Notification->SetPrefs($mundaneId, $map); }
public function get_history($mundaneId, array $filters = [], $limit = 25, $offset = 0) {
    return $this->Notification->GetHistory($mundaneId, $filters, $limit, $offset);
}
public function count_history($mundaneId, array $filters = []) {
    return $this->Notification->CountHistory($mundaneId, $filters);
}
```

### `orkui/controller/controller.Notifications.php` (NEW — page controller)

`Controller_Notifications extends Controller`. **Not** an Ajax controller — it
renders the history page. Pattern mirrors `Controller_Friend`:

- `index($action = null)` — signature must match `Controller::index($action =
  null)` (the Reflection dispatcher fatals on incompatible overrides — same gotcha
  noted in `controller.Friend.php`). Auth-guard: if
  `(int)$this->session->user_id <= 0` → `header('Location:
  index.php?Route=Login'); exit;`. Loads `Notification` model, reads optional
  `?type=` filter and `?page=`, fetches page 1 server-side via `get_history` +
  `count_history`, sets `$this->data['Notifications']`, `['Filter']`, `['Page']`,
  `['PageCount']`, `['Types']` (from `get_muteable_types`, for the filter
  dropdown), `['Uid']`, and `$this->template =
  '../revised-frontend/Notificationsnew_index.tpl'`.

### `orkui/controller/controller.NotificationAjax.php` (extended)

Add three actions, all reusing the existing private `guard()` (JSON header + auth
on `$this->session->user_id`), `{status:0,...}` / `{status:1,error}` convention,
each ending in `exit;`:

- `prefs()` — `GET` → returns the muteable type registry merged with the user's
  current state: `{status:0, types:[{type,label,icon,enabled}]}`. Reads
  `get_muteable_types()` + `get_prefs($uid)`.
- `set_prefs()` — `POST` → accepts `prefs[<type>]=0|1` (or a JSON `prefs` blob),
  validates each against the muteable registry (silently drops `$ALWAYS_ON` and
  unknown types — the lib also rejects them), calls `set_prefs($uid, $map)`,
  returns `{status:0}`.
- `history()` — `GET` → `type` (optional), `page` (1-based), returns
  `{status:0, items:[...], page, page_count, total}`. Computes
  `offset = (page-1)*25`, calls `get_history` + `count_history`. Item shape matches
  the bell `list` action plus `dismissed:bool`.

**No new Ajax controller class**, so the `$_skipTokenCheck` allow-list in
`system/lib/system/class.Controller.php` already covers `Controller_NotificationAjax`
(line 49). **Checklist confirm during implementation: do NOT add
`Controller_Notifications` (the page controller) to `$_skipTokenCheck`** — it is a
normal page and should keep the stale-session protection. (Only Ajax controllers go
on that list.)

## 3. AJAX endpoints

| Route | Method | Auth | Returns |
|---|---|---|---|
| `NotificationAjax/prefs` | GET | logged-in (self) | `{status:0, types:[{type,label,icon,enabled}]}` |
| `NotificationAjax/set_prefs` | POST | logged-in (self) | `{status:0}` / `{status:1,error}` |
| `NotificationAjax/history` | GET | logged-in (self) | `{status:0, items, page, page_count, total}` |
| `NotificationAjax/list` | GET | logged-in (self) | *(existing)* bell panel items |
| `NotificationAjax/mark_read` | POST | logged-in (self) | *(existing)* reused by history page |
| `NotificationAjax/dismiss` | POST | logged-in (self) | *(existing)* reused by history page |

All scoped to `session->user_id`; no cross-user mutation is possible because every
lib method filters by `$mundaneId`.

## 4. Integration points

- **`class.Notification.php` fan-out methods** — `Create` / `CreateBulk` /
  `CreateBulkOnce` gain the `FilterMutedRecipients` call. This is the single
  enforcement point; award triggers (`class.Award.php`), the announcement composer
  (`NotificationAjax/send`, type `announcement` → exempt), event notifications
  (new-event alerts fired as type `event` in `class.Event.php`; `event_reminder`
  is registered for muting but not yet fired anywhere — see §5), and friend events
  (`friend_request` / `friend_accept`) all inherit suppression with no change.
- **Bell dropdown header** (`orkui/template/default/default.theme`, the
  `.nav-notif-head` block, currently `Notifications` title + `Mark all read`
  button) — add a **gear button** (`np-gear`, `data-tip="Notification settings"`)
  that opens the prefs modal, and a **footer "See all" link** below
  `#nav-notif-list` → `href="<?=UIR?>Notifications/index"`. Both gated by the
  existing `$this->__session->token != null` block.
- **Prefs modal** — a new self-contained `np-` overlay block in `default.theme`
  (modeled byte-for-byte on the `nc-` Announcement Composer overlay already there:
  `.np-overlay`/`.np-overlay.np-open`/`.np-modal`, dark-mode `var(--ork-*)`
  fallbacks). Its open/close + load/save JS lives in the
  `$this->__session->token != null` script block — **guarded by a server-emitted
  truthy flag, never `document.getElementById`** (revised.js IIFE rule); since this
  inline script is already inside the logged-in `<?php if ... ?>`, the guard is the
  PHP conditional itself, and the public open function is assigned to `window.`
  (same as `notifToggle`). On open: lazy `GET prefs`, render a list of
  toggle rows; on save: `POST set_prefs`. No native `confirm()`/`alert()` — none
  needed (toggles save directly; a "Saved" inline note suffices).
- **History page template** `Notificationsnew_index.tpl` (NEW, in
  `orkui/template/revised-frontend/`) — reuses the **Reports framing**
  (`revised.css` + `reports.css`, `.rp-root`/`.rp-header`/`--rp-*` vars) exactly
  like `Friendnew_index.tpl`, for instant dark-mode + header/card styling.

## 5. Frontend conventions

- **`.tpl` is PLAIN PHP** — `Notificationsnew_index.tpl` uses
  `<?php ?>`/`<?= ?>` and `htmlspecialchars()`; never Smarty `{$var}`/`{if}`/
  `{foreach}`. Top-of-file `<?php /* vars: $Notifications, $Filter, $Page,
  $PageCount, $Types, $Uid */ ?>` doc block, then closures for item rendering (same
  shape as `Friendnew_index.tpl`'s `$fr_avatar`).
- **Dark mode from the start** — every new rule (`np-*` modal, history page) uses
  `var(--ork-*)` tokens and explicit `html[data-theme="dark"]` overrides where a
  hard color is unavoidable. Verify the prefs modal AND history page in dark mode
  before "done" (per the dark-mode checklist: modal header, ghost/cancel buttons,
  toggles, filter dropdown, empty state).
- **Heading reset** — any `h1`/`h2` in the history page or prefs modal that is not
  meant to carry the global orkui.css gray box MUST reset
  `background:transparent;border:none;padding:0;border-radius:0;text-shadow:...`.
  The Reports `.rp-header-title` already does this; reuse that class rather than a
  bare `<h1>`.
- **`data-tip` tooltips, never native `title`** — the gear button, per-item
  actions, and the dismiss X use `data-tip` (wrapping, on-screen: `white-space:
  normal; width:max-content; max-width:240px`; right-anchor the Actions-column tip
  on the history table).
- **`tnConfirm()` not native dialogs** — if a destructive affordance is added
  later (e.g. "clear history"), it must use `tnConfirm({title,body,confirmLabel,
  danger,onConfirm})`. v1 has no destructive action, so none is needed.
- **Toggle UI** — segmented/checkbox toggles in the prefs modal must be
  dark-mode-styled (the checklist calls out segmented toggles specifically); use
  the app's existing `.pn-` switch styling if present, else a clearly-styled
  checkbox with visible state in both themes.
- **No jQuery-UI autocomplete / player search** is involved in this feature.

## 6. Testing

Exercise via the local curl-auth session pattern (login once, one cookie jar; app
enforces single-device sessions — login + all calls in one block). Container
`ork3-php8-app`; HTTP 500s surface in `docker logs ork3-php8-app`.

- **Preferences round-trip:** `GET NotificationAjax/prefs` → all muteable types
  default `enabled:true`, `$ALWAYS_ON` types absent. `POST set_prefs` muting
  `award` → `GET prefs` shows `award:false`; `ork_notification_pref` has one row
  `enabled=0`. Re-enable → row flips to `enabled=1` (upsert, not duplicate).
- **Suppression:** with `award` muted for user A, grant A an award →
  `UnreadCount(A)` does **not** increment and no `ork_notification` row exists for
  A (the award save itself still succeeds — confirm best-effort no-op). Unmute →
  next award produces a row. Bulk: mute `event` for A, fan-out a new-event
  notification (type `event`) to a kingdom including A → A gets no row, others do
  (`CreateBulk` Count excludes A). **Note:** `event_reminder` suppression is not
  end-to-end testable yet — no code fires that type today; verify the muteable
  registry/UI handles it, defer the fan-out test until a reminder source ships.
- **Non-muteable:** attempt `set_prefs` with `announcement:0` → lib returns
  Status 1 / controller drops it; an `announcement` fan-out still reaches that user.
- **History:** `GET history` returns read AND dismissed rows (unlike `list`);
  `type` filter narrows correctly; paging math (`page`, `page_count`, `total`) is
  correct across >25 rows; per-item `mark_read`/`dismiss` reuse works and persists.
- **Auth scoping:** user B cannot read/mutate A's prefs or history (every call is
  scoped to `session->user_id`; no id is accepted from the request body).
- **Index coverage:** `EXPLAIN` the history query uses `recipient_history`; the
  suppression read uses `uniq_user_type`.
- **Dark-mode walk** of the prefs modal, the bell gear/See-all additions, and the
  full history page (header, filter, rows, empty state, pager) before "done."
- **Plain-PHP lint:** confirm `Notificationsnew_index.tpl` contains no Smarty
  tokens (`grep -nE '\{\$|\{if|\{foreach'` returns nothing).
