# Unit Feed + Unit Announcements — Design

**Date:** 2026-06-21
**Branch:** `feature/social-features`
**Status:** Approved design, pending implementation plan

## Purpose

Give units (`ork_unit` — the existing first-class orgs with members + managers)
a social presence: a **wall of posts** on the unit profile, **reactions** on each
post, and a **"this unit" audience** in the existing announcement composer that
fans out to the unit's roster via the Notifications foundation.

This is the third consumer feature in the social batch shipping on this branch.
It builds directly on three already-designed systems and does NOT redefine any
of them:

- **Notifications** (`docs/superpowers/specs/2026-06-20-notifications-system-design.md`,
  `class.Notification.php`, `controller.NotificationAjax.php`): the unit
  announcement audience is a new branch of the existing `NotificationAjax/send`
  composer; reaction notifications reuse `Create`.
- **Shared Reactions primitive** (locked contract, see below; the sibling
  Reactions feature on this branch owns `class.Reaction.php` /
  `ork_reaction`): unit posts are reactable via `entity_type = 'unit_post'`.
  This spec **consumes** that contract — it does not create the reaction table
  or lib.
- **Unit model** (`class.Unit.php`, `model.Unit.php`, `controller.Unit.php`,
  `template/default/Unit_index.tpl`): posting/management authority is grounded
  in the real membership (`ork_unit_mundane`) and management (`ork_authorization`
  with `AUTH_UNIT`/`AUTH_CREATE`) model.

In-app only. No email, no push, no real-time, no polling — the feed and
reactions reflect page-load / on-action state, consistent with the Notifications
design.

## Shared Reactions primitive (consumed, NOT defined here)

> **Single source of truth:** the reaction table, the `class.Reaction.php` method
> signatures, the preset set, and the `entity_type` allowlist are defined
> authoritatively in `docs/superpowers/specs/2026-06-21-reactions-design.md`.
> This feature **consumes** that contract and writes **no reaction code**. Do not
> re-derive signatures from the summary below — read the Reactions spec. The
> summary here is orientation only.

This feature depends on the Reactions feature's `class.Reaction.php` +
`ork_reaction` (the locked generic primitive). Orientation:

- Generic table `ork_reaction` keyed `(entity_type, entity_id, mundane_id,
  reaction)`; unit posts plug in with `entity_type = 'unit_post'`,
  `entity_id = post_id` (`'unit_post'` is already in the Reactions spec's
  `$ENTITY_TYPES` allowlist).
- Read methods carry a **`$viewerId`** so the bar can show the viewer's own
  selected state: `GetReactions($entityType, $entityId, $viewerId = 0)` and
  `GetReactionsBulk($entityType, array $entityIds, $viewerId = 0)` → map keyed by
  `entity_id`. Write methods: `React($uid,$type,$id,$reaction)` /
  `Unreact($uid,$type,$id,$reaction)`. Presets (icon + label per key) come from
  `Reaction::GetPresets()` — never hardcode them here.
- Preset set + glyphs are owned by the Reactions spec (FontAwesome 5.8.2 icons,
  not emoji). This feature renders whatever `GetPresets()` returns.
- Reacting to someone else's `unit_post` fires a best-effort `reaction`
  notification to the **post author** (`ork_unit_post.author_mundane_id` is the
  owner the Reaction lib resolves); never blocks the reaction write.

## Decisions (locked during brainstorming)

- **Who may post: active roster members + unit managers.** Posting is restricted
  to people on the unit — an active row in `ork_unit_mundane`
  (`active = 'Active'`) OR a unit manager
  (`HasAuthority($uid, AUTH_UNIT, $unitId, AUTH_CREATE)`). Managers are always
  eligible even if their roster row lapsed. Mirrors the existing eligibility
  helpers `Unit::_active_member_roles()` and the manager-set computation in
  `controller.Unit.php` (`$_manager_ids` from
  `$Unit['Authorizations']['Authorizations']`).
- **Who may edit/delete: the author + unit managers.** A member edits/soft-deletes
  their own post; a manager can soft-delete (moderate) any post in their unit.
  Managers cannot *edit* another member's wording (delete-only moderation) — edit
  is author-only.
- **Post visibility: public-readable, posting restricted.** Anyone who can view
  the unit profile sees the feed (units are already public via
  `Unit/index/{id}`). Only eligible members compose. Rationale: units are public
  orgs; a recruiting/identity wall is more useful when visible, and gating
  *reading* would duplicate the profile's existing public posture for no benefit.
  Reacting still requires login (no anonymous reactions — enforced by the
  Reaction lib's `$uid` gate).
- **Soft delete only.** `deleted_at` tombstone; deleted posts vanish from the
  feed but the row (and its reactions) persist for audit. No hard delete in v1.
- **Edit window: unlimited, flagged.** An edited post sets `edited_at` and the UI
  shows an "edited" marker. No time limit (keeps it simple; abuse is handled by
  manager moderation).
- **Unit announcements = NEW notification type `unit_announcement`.** Distinct
  from the officer/admin `announcement` so recipients can tell a unit post-blast
  from a kingdom/park officer broadcast, and so a future per-type grouping can
  treat them separately. Icon: `fas fa-users-rectangle` (falls back to the
  Notification lib's allowlist/default). Gated on unit-management authority.
- **Announcement audience = active roster member mundane_ids.** Resolved in the
  lib (architecture rule: `$DB` lives in the lib, not the controller), mirroring
  `Notification::GetRecipientsForScope` for the existing scopes.
- **No new feed/aggregation tables.** Posts live in one new table; reactions live
  in the shared `ork_reaction`; the feed is a paginated query over
  `ork_unit_post` plus a single batched `GetReactionsBulk` call.

## Non-goals (v1)

- Comments / threaded replies on posts (reactions only; comments are a future
  project — the Notification `type`/`payload` already supports a future
  "N people commented" group).
- Rich media / image attachments / link unfurls in posts (plain text + the
  composer's safe-link affordance only).
- Pinned posts, post pinning, or post categories/tags.
- Cross-posting a unit post to the friend activity feed (the Friends feed sources
  stay awards + RSVPs per its spec; not extended here).
- Notifying members on *every* new wall post (only the explicit "Notify Members"
  announcement fans out; ordinary posts do not spam the bell).
- Editing another member's post text (manager moderation is delete-only).
- Real-time/polling refresh of the feed.
- Reaction-set definition (owned by the Reactions feature).

## Architecture overview

Follows the established three-layer pattern, mirroring the notifications/friends
stacks:

```
index.php?Route=Unit/index/{id}            (controller.Unit.php — profile page, feed panel)
index.php?Route=UnitFeedAjax/{action}      (controller.UnitFeedAjax.php — JSON post CRUD + feed)
index.php?Route=NotificationAjax/send      (existing — gains a 'unit' audience branch)
  → orkui/model/model.UnitPost.php         (thin pass-through)
  → Ork3::$Lib->unitpost                   (system/lib/ork3/class.UnitPost.php)
  → $DB / yapo on ork_unit_post
  + Ork3::$Lib->reaction                   (shared — entity_type 'unit_post')
  + Ork3::$Lib->notification               (shared — 'unit_announcement', 'reaction')
```

Person identity is `ork_mundane.mundane_id` throughout. Logged-in user is
`$this->session->user_id` in controllers; lib service methods that mutate take
the acting `$uid` and re-verify eligibility themselves.

## 1. Data model

### `ork_unit_post`

One row per wall post. Soft-deleted, edit-flagged.

| column | type | purpose |
|---|---|---|
| `post_id` | int PK auto-inc | also the reaction `entity_id` (`entity_type='unit_post'`) |
| `unit_id` | int, NOT NULL | owning unit (`ork_unit.unit_id`) |
| `author_mundane_id` | int, NOT NULL | poster (`ork_mundane.mundane_id`) |
| `body` | text, NOT NULL | post text (plain; rendered escaped) |
| `created_at` | datetime NOT NULL DEFAULT CURRENT_TIMESTAMP | newest-first ordering |
| `edited_at` | datetime, null | set on edit; null = never edited |
| `deleted_at` | datetime, null | soft-delete tombstone; null = visible |

- `KEY by_unit_live (unit_id, deleted_at, created_at)` — covers the feed query
  (`WHERE unit_id = ? AND deleted_at IS NULL ORDER BY created_at DESC`).
- `KEY by_author (author_mundane_id)` — author's-own lookups / future "my posts".

**Migration:** `db-migrations/2026-06-21-add-unit-post.sql` — additive +
idempotent (`CREATE TABLE IF NOT EXISTS`, charset `utf8mb4`/`utf8mb4_unicode_ci`
matching the `2026-03-16-utf8mb4-conversion.sql` posture), applied manually (no
runner), copying the style of `db-migrations/2026-06-20-add-notification.sql`.
**No `ork_reaction` DDL here** — that table is created by the Reactions feature's
migration; this feature only references it.

## 2. Layers

### `system/lib/ork3/class.UnitPost.php`

Auto-registers as `Ork3::$Lib->unitpost` (startup.php scan). The **only** layer
that touches `$DB`/yapo for `ork_unit_post`. Every raw query calls
`$this->db->Clear()` first (project rule). Construct a
`yapo($this->db, DB_PREFIX . 'unit_post')` handle in `__construct`, matching
`class.Notification.php`.

**Eligibility helpers** (private, ground authority in the real model):

- `_isActiveMember($uid, $unitId)` — true if an `ork_unit_mundane` row exists with
  `mundane_id = $uid`, `unit_id = $unitId`, `active = 'Active'`. (Mirrors
  `Unit::_active_member_roles`.)
- `_isManager($uid, $unitId)` —
  `Ork3::$Lib->authorization->HasAuthority($uid, AUTH_UNIT, $unitId, AUTH_CREATE)`.
- `CanPost($uid, $unitId)` — `_isActiveMember || _isManager`.

**Write methods** (each re-verifies the acting `$uid`; never trust the caller):

- `CreatePost($uid, $unitId, $body)` — gate on `CanPost`; trim + reject empty +
  cap length (e.g. 4000 chars); insert with `author_mundane_id = $uid`. Returns
  `['Status'=>0,'PostId'=>N]` / `['Status'=>1,'Error'=>...]`. Reads the new id
  from `$this->unitpost->post_id` after `save()` (the Notification-lib pattern —
  NOT `GetLastInsertId()`). **Ordinary posts do not notify** (per non-goals).
- `EditPost($uid, $postId, $body)` — load the row; allow only when
  `author_mundane_id === $uid` and `deleted_at IS NULL`; update `body` + set
  `edited_at = NOW()`.
- `DeletePost($uid, $postId)` — load the row; allow when `author_mundane_id === $uid`
  **OR** `_isManager($uid, $row.unit_id)` (manager moderation); set
  `deleted_at = NOW()` (soft). Idempotent if already deleted.

**Read methods:**

- `GetFeed($unitId, $limit = 20, $offset = 0)` — non-deleted posts for the unit,
  newest-first, paginated. Joins `ork_mundane` for `author` persona/park + the
  heraldry/avatar fields used elsewhere on the profile. Returns rows with
  `PostId, AuthorMundaneId, AuthorPersona, AuthorAvatar, Body, CreatedAt,
  Ago, Edited(bool)`. Reactions are NOT fetched here — the controller batches
  them with one `Reaction::GetReactionsBulk('unit_post', $postIds, $viewerId)` to
  avoid N+1 (pass the viewer so each bar shows the viewer's own selected state). Uses `while($r->next())` iteration (DataSet does not pre-fetch — same
  gotcha as the Notification lib).
- `GetPost($postId)` — single non-deleted post (re-render after create/edit).
- `GetActiveMemberIds($unitId)` — flat array of active-roster mundane_ids
  (`ork_unit_mundane.active = 'Active'`), for the announcement fan-out. This is
  the unit analogue of `Notification::GetRecipientsForScope` and lives in the
  lib for the same architectural reason.
- `CountPosts($unitId)` — non-deleted count (feed "load more" / stat).

`RelativeTime()` — reuse the same private helper shape as `class.Notification.php`
(or factor it out; v1 may copy it to keep the lib self-contained, matching the
existing per-lib duplication).

### `orkui/model/model.UnitPost.php`

Thin pass-through (`new APIModel('UnitPost')`), forwarding to the lib, per the
architecture-layers rule (model = pass-through + transforms only). Mirrors
`model.Notification.php`.

### `orkui/controller/controller.UnitFeedAjax.php`

`Controller_UnitFeedAjax extends Controller`. **Must be added to the
`$_skipTokenCheck` allow-list in `system/lib/system/class.Controller.php`** (same
as `NotificationAjax` / `FriendAjax`), else the stale-session redirect fires on
these AJAX calls.

Shared preamble `guard()` returning the int `user_id` (copy
`Controller_NotificationAjax::guard()` exactly — JSON header, logged-in check,
`exit`). Each action: sanitize input, call the model, echo `json_encode`.
Response convention `{status:0,...}` / `{status:1,error}` (PlayerAjax / Notification
convention).

- `feed` — **public read, NO login required** (visibility decision). `unit_id`,
  `offset`. Calls `GetFeed`, then `Reaction::GetReactionsBulk('unit_post', ids)`,
  merges reaction summaries onto each item, and includes a `can_post` flag
  (computed from the session user via `CanPost`) and per-item `can_edit` /
  `can_delete` flags so the client renders the right affordances. Because this is
  the one unauthenticated action, it must NOT use `guard()` for the read path —
  it resolves the optional viewer id defensively (`(int)($session->user_id ?? 0)`).
- `create` — `guard()`; `unit_id`, `body` → `CreatePost`. Returns the rendered
  new post (via `GetPost` + a fresh reaction summary).
- `edit` — `guard()`; `post_id`, `body` → `EditPost`.
- `delete` — `guard()`; `post_id` → `DeletePost`.

Reaction toggling on a post goes through the **Reactions feature's own AJAX
endpoint** (`ReactionAjax/...` with `entity_type=unit_post`), not duplicated here.

### `orkui/controller/controller.Unit.php` (existing — extended)

`index($unit_id)` already computes everything needed to gate the feed UI:
`$this->data['CanEdit']`, `$this->data['IsManager']`, `$this->data['IsRosterMember']`,
and the manager set. Add:

- `$this->data['CanPost'] = ($_uid > 0) && ($_is_member || $this->data['IsManager']);`
  (reuse the already-computed `$_is_member` at line ~245 and `IsManager` at ~246).
- `$this->data['CanNotifyMembers'] = $this->data['IsManager'];` — gate for the
  unit "Notify Members" button (management-only, matching the announcement
  authority decision; officers do not get a unit-blast button — that is a
  kingdom/park concern via the existing scopes).
- Seed the first feed page server-side for a fast first paint (optional but
  preferred): `$this->data['UnitFeed'] = Ork3::$Lib->unitpost->GetFeed($unit_id, 20, 0)`
  plus its batched reactions — OR render an empty shell and lazy-load via
  `UnitFeedAjax/feed` on first view. Recommend **server-seed page 1, lazy-load
  "load more"** (cheap, avoids a flash of empty feed). Keep all `$DB` in the lib;
  the controller calls the lib via the model, not raw SQL.

No new UI controller is needed — the feed lives on the existing profile.

## 3. AJAX endpoints

| endpoint | auth | calls | notes |
|---|---|---|---|
| `UnitFeedAjax/feed` | **public** (optional viewer) | `GetFeed` + `Reaction::GetReactionsBulk` | paginated; returns `can_post` + per-item `can_edit`/`can_delete` |
| `UnitFeedAjax/create` | logged-in + `CanPost` (in lib) | `CreatePost` | returns rendered new post |
| `UnitFeedAjax/edit` | logged-in + author (in lib) | `EditPost` | sets `edited_at` |
| `UnitFeedAjax/delete` | logged-in + author\|manager (in lib) | `DeletePost` | soft delete |
| `NotificationAjax/send` | logged-in + **unit manager** | `GetActiveMemberIds` → `CreateBulk('unit_announcement', …)` | NEW `scope=unit` branch (see §4) |
| `ReactionAjax/*` (Reactions feature) | logged-in | `React`/`Unreact` | `entity_type=unit_post`; owned by Reactions feature |

All mutating endpoints re-verify the acting user in the **lib**, not just the
controller (defense in depth — controller flags are UI hints).

## 4. Unit announcements — extend `NotificationAjax/send`

The composer (`ncOpenComposer(scope, scopeId, label)` in
`template/revised-frontend/script/revised.js`, modal chrome in `default.theme`,
`nc-` namespace) is **already fully generic** — it posts `scope` + `scope_id` to
`NotificationAjax/send`. No JS rewrite needed; the unit "Notify Members" button
just calls `ncOpenComposer('unit', <unitId>, '<unit name> members')`, exactly as
Park calls `ncOpenComposer('park', <id>, '<name>')` at
`Parknew_index.tpl:276`.

`Controller_NotificationAjax::send()` gains a `'unit'` branch alongside
`global|kingdom|park`:

1. Add `'unit'` to the `in_array($scope, [...], true)` audience allowlist.
2. **Authority gate:** require unit management —
   `Ork3::$Lib->authorization->HasAuthority($uid, AUTH_UNIT, $scopeId, AUTH_CREATE)`.
   (Unit managers hold `AUTH_UNIT`/`AUTH_CREATE`; this matches every write path
   in `class.Unit.php`. No `AUTH_EDIT` fallback — unit auth is create-grained.)
3. **Recipient resolution:** the model exposes
   `get_active_member_ids($scopeId)` → `UnitPost::GetActiveMemberIds`, returning
   active-roster mundane_ids. (Kept in the `UnitPost` lib so all unit-roster SQL
   stays in one place; `Notification` stays org-scope-only.)
4. **Fan-out:** `CreateBulk($recipients, 'unit_announcement', [...])`, with
   `created_by = $uid`, the composer title/body, the sanitized link
   (existing scheme allowlist applies), and `icon = null` (lib resolves the
   `unit_announcement` default).

Register the new type in `Notification::$DEFAULT_ICONS`:
`'unit_announcement' => 'fas fa-users-rectangle'`.

Notification creation is best-effort and never blocks; the composer already
reports the recipient count back to the sender via `navInfoDialog`.

## 5. Reaction notifications on unit posts

When a user reacts to a `unit_post`, the **Reactions feature's** `React()` fires a
best-effort `reaction` notification to the post's owner. The owner is resolved by
the Reaction lib from the entity (`entity_type='unit_post'`,
`entity_id=post_id`) → `ork_unit_post.author_mundane_id`. This spec only
guarantees that `ork_unit_post.author_mundane_id` is the authoritative owner
column the Reaction lib reads; it does NOT implement the notification (owned by
Reactions). Reacting to your own post does not self-notify.

## 6. Frontend — `template/default/Unit_index.tpl` (feed panel)

The profile is a hero + `pn-layout` (sidebar + `pn-main`). The current `pn-main`
holds the Members roster (`un-section-header` + `un-roster-card`). Add a **Feed
section** inside `pn-main`, above or below the roster (recommend above — it is
the social focal point), as a sibling `un-section-header` + card.

**Remember `Unit_index.tpl` is PLAIN PHP** (`extract()`+`include`) — use
`<?php ?>`/`<?= ?>`, never Smarty `{$var}`/`{if}`/`{foreach}`. The file already
follows this (e.g. `<?php foreach ($_members as $_m) { ?>`).

Composer + list:

- **Compose box** rendered only when `$CanPost`: a textarea + Post button.
  Submits to `UnitFeedAjax/create` via fetch; on success, prepend the returned
  rendered post to the list and clear the box.
- **Post list**: server-seeded page 1 (from `$UnitFeed`), each post = author
  avatar + persona (link to `Player/profile/{id}`) + relative time + "edited"
  marker + body (escaped) + a **reaction bar** (the Reactions feature's shared
  render: the preset pills with counts + the viewer's active state). A "Load
  more" button pages via `UnitFeedAjax/feed&offset=N`.
- **Per-post actions** (Edit / Delete) shown per the `can_edit` / `can_delete`
  flags. Delete uses **`tnConfirm({title,body,confirmLabel,danger:true,onConfirm})`** —
  never native `confirm()`. Edit swaps the body for an inline textarea + Save.
- **Empty state**: "No posts yet." (+ "Be the first to post." when `$CanPost`).

**"Notify Members" button** in the hero actions, rendered only when
`$CanNotifyMembers`, mirroring the Park button:

```php
<?php if (!empty($CanNotifyMembers)): ?>
  <button class="pn-btn pn-btn-outline"
    onclick="ncOpenComposer('unit', <?= (int)$_unit_id ?>, <?= htmlspecialchars(json_encode(($_name ?? 'this unit') . ' members'), ENT_QUOTES) ?>)">
    <i class="fas fa-bullhorn"></i> Notify Members
  </button>
<?php endif; ?>
```

The composer chrome is global (logged-in `default.theme`), so it is present;
`ncOpenComposer` no-ops safely if absent.

## 7. Frontend conventions (apply to every new surface)

- **Dark mode from the start** — all new CSS uses the
  `html[data-theme="dark"]` selector (NOT `body.dark-mode`). Walk the compose
  box, post cards, reaction bar, edit-inline state, empty state, and the
  composer modal in dark mode before "done." Pre-flight: modal headers (orkui.css
  `h1–h6` gray-box leak), ghost/cancel buttons, textarea placeholders,
  the "edited"/relative-time muted text.
- **Heading reset** — any heading inside the feed card/section header must reset
  the global `h1–h6` gray-box style
  (`background:transparent; border:none; padding:0; border-radius:0`).
- **No native dialogs** — `tnConfirm()` for the delete confirmation.
- **No native tooltips** — use the `data-tip` CSS pattern (wrap + stay
  on-screen) for any icon-button hints; do NOT copy the existing inline
  `title="..."` attributes elsewhere in `Unit_index.tpl` (those predate the
  rule — new work uses `data-tip`).
- **JS** follows the bespoke open/close-function convention. The feed JS may live
  in `revised.js` (loaded by `Unit_index.tpl` at line ~1016) or inline in the
  template; if added to `revised.js`, **guard the IIFE on a config flag (e.g. a
  `UnConfig`/`PnConfig`-style object emitted by the template), NEVER
  `document.getElementById`** (the external script loads mid-page; the feed
  markup is defined after the `<script src>` tag and is not yet in the DOM at
  IIFE-eval time). `ncOpenComposer` is already a `window.*` function reachable
  from the inline `onclick`.
- **Safe links** in the announcement composer use the existing `NotificationAjax/send`
  scheme allowlist (`^(https?://|/|\?Route=)`); no new link handling.
- **`$DB->Clear()`** before every raw `Execute`/`DataSet` in `class.UnitPost.php`
  (stale PDO bindings → silent failures).

## 8. Testing

Lib + AJAX exercised via the local curl-auth session pattern (login once, one
cookie jar; app enforces single-device sessions, so login + all test calls in one
block).

- **Eligibility:** an active member can `create`; a retired/non-member cannot
  (lib rejects, not just the UI). A manager whose roster row lapsed can still
  post. A logged-out request to `create` is rejected; to `feed` succeeds
  (public read).
- **Lifecycle:** create → appears in `feed` newest-first → edit sets `edited_at`
  + the marker shows → author delete soft-removes (gone from feed, row +
  `deleted_at` persist) → manager can delete another member's post; a
  non-manager non-author cannot.
- **Reactions:** react to a `unit_post` (via the Reactions endpoint) → count +
  viewer-state reflect in the next `feed`; `GetReactionsBulk` returns one map
  keyed by `post_id` (no N+1); reacting to someone else's post fires a `reaction`
  notification to the author (best-effort), self-react does not.
- **Unit announcement:** a manager's `NotificationAjax/send` with `scope=unit` +
  `scope_id` fans out a `unit_announcement` to exactly the active roster
  (`GetActiveMemberIds`), returns the count, and each recipient sees the bell
  item with the `fa-users-rectangle` icon; a non-manager member is rejected by
  the authority gate; an empty roster returns `count:0` without error.
- **Auth scoping:** a user cannot edit/delete a post in a unit they don't manage
  and didn't author; `scope=unit` send is rejected without `AUTH_UNIT`/`AUTH_CREATE`.
- **Conventions:** dark-mode walk of compose box, post cards, reaction bar, edit
  state, empty state, and the composer modal; delete uses `tnConfirm`; no native
  `title`/`confirm`; IIFE guarded on a config flag, not `getElementById`.
