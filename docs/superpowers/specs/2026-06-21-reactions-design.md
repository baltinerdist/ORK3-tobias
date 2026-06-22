# Reactions System — Design

**Date:** 2026-06-21
**Branch:** `feature/social-features`
**Status:** Approved design, pending implementation plan

## Purpose

Add a small, tasteful **reactions** primitive to the ORK — a generic
"react to a thing" capability that any social surface can adopt without
new tables or new write code. v1 builds the primitive end-to-end and proves
it on two existing surfaces:

1. **Friends Activity Feed** items (awards earned + event RSVPs).
2. **Player profile Awards** rows.

Reactions are deliberately **generic** so a third consumer — Unit Feed posts
(Feature C, `entity_type = 'unit_post'`) — can adopt the exact same table,
lib, model, controller, and UI component with zero changes here. This spec
builds the shared primitive and the first two consumers; it does **not** build
`unit_post` reactions, but the `entity_type` registry already reserves it.

Reactions build directly on the two social foundations already shipped on this
branch:

- **Notifications** (`docs/superpowers/specs/2026-06-20-notifications-system-design.md`,
  `system/lib/ork3/class.Notification.php`) — reacting to someone else's entity
  fires a best-effort `reaction` notification to the owner, reusing the existing
  fan-out/snapshot delivery and bell UI.
- **Friends** (`docs/superpowers/specs/2026-06-20-friends-system-design.md`,
  `system/lib/ork3/class.Friendship.php`) — the activity feed is the primary
  reaction surface, so this spec augments `Friendship::GetActivityFeed` to emit
  a **stable entity id per feed item**.

In-app only. No email, no push, no real-time, no polling — reaction state
reflects page-load time (counts fetched server-side or on first paint).

## Decisions (locked)

- **One generic table, `ork_reaction`.** Polymorphic via
  `(entity_type, entity_id)`; never per-surface tables. This is the locked
  shared-primitive contract referenced by both this feature and the future
  Unit Feed feature so they stay byte-for-byte consistent.
- **Preset reaction set, honor/chivalry-themed, small (4).** Rendered as
  **FontAwesome 5.8.2 icons** (NOT native emoji) for cross-platform/dark-mode
  consistency — the live build pins FA `5.8.2`, so every glyph below is verified
  FA5-safe (FA6-only icons like `fa-hands-clapping`/`fa-shield` are forbidden).
  The set is a fixed registry in the lib:
  - `huzzah` — `fas fa-glass-cheers` "Huzzah"
  - `valor`  — `fas fa-fist-raised` "Valor"
  - `honor`  — `fas fa-shield-alt` "Honor"
  - `heart`  — `fas fa-heart` "Heart"
  A user may apply **multiple distinct** reactions to the same entity (one row
  per reaction key), but never the same reaction twice (unique constraint).
- **Toggle semantics.** Clicking a reaction the viewer already gave **removes**
  it (`Unreact`); clicking one they have not gives it (`React`). The bar is a
  per-key toggle, not a single-choice radio.
- **`entity_type` is a fixed, lib-owned registry** (an explicit allowlist
  table, §1.1). Unknown `entity_type` values are rejected at the lib boundary —
  the table is generic but the *accepted* types are closed.
- **Stable entity ids come from existing rows, no new id space.** Reactions key
  off ids that already exist:
  - `award` → `ork_awards.awards_id` (already rendered as `AwardsId` in
    `Playernew_index.tpl`).
  - `feed_award` → the same `ork_awards.awards_id` of the feed item's award.
  - `feed_rsvp` → `ork_event_rsvp.rsvp_id` of the feed item's RSVP.
  No new feed-item id table; the feed query is extended to surface these.
- **Reacting to your own entity is allowed** (no self-react block) but **never
  notifies** (don't notify yourself).
- **Cross-react notification is best-effort.** A `reaction` notification to the
  entity owner is fired after a successful `React`, wrapped defensively — a
  notification failure must never roll back or block the reaction write (same
  discipline as the award/friend hooks).
- **Counts are batch-fetched** for any list surface (`GetReactionsBulk`) to
  avoid N+1 — the feed renders ~30 items per page.

## Non-goals (v1)

- `unit_post` reactions (Feature C — primitive + registry slot reserved only).
- Reactions on comments, notes, units, kingdoms, parks, events themselves
  (only the two named surfaces ship; adding more = one registry entry + one
  reaction-bar include each, no schema/lib change).
- Reaction analytics / leaderboards / "most-reacted" reports.
- Real-time / polling / live count updates (page-load state only; the bar
  optimistically updates its own counts client-side after a toggle).
- Per-reaction permissions or moderation/removal of others' reactions.
- Notification fan-out for reactions beyond the single entity owner (no
  "X and 3 others reacted" rollup in v1; payload reserves room for it later).
- Retention/cleanup (rows kept indefinitely; cheap).

## Architecture overview

Follows the established three-layer pattern, mirroring the notifications and
friends stacks:

```
index.php?Route=ReactionAjax/action   (controller.ReactionAjax.php — JSON actions)
  → orkui/model/model.Reaction.php     (thin pass-through)
  → Ork3::$Lib->reaction               (system/lib/ork3/class.Reaction.php)
  → $DB / yapo on ork_reaction
```

There is **no** `controller.Reaction.php` UI page — reactions have no standalone
page; they are a component embedded in other surfaces (feed, profile awards).
The reaction-bar markup is a small reusable include rendered by the host
template; behavior is a single delegated handler in `revised.js`.

Person identity is `ork_mundane.mundane_id` throughout. Logged-in user is
`$this->session->user_id` in the controller; the reactor `mundane_id` is always
taken from the session, never from the request body.

## 1. Data model

### `ork_reaction`

One row per (entity, reactor, reaction-key). The single generic table — this is
the locked shared-primitive contract.

| column | type | purpose |
|---|---|---|
| `reaction_id` | int PK auto-inc | |
| `entity_type` | varchar(32), NOT NULL | registry key: `feed_award`, `feed_rsvp`, `award`, `unit_post` (reserved) |
| `entity_id` | int, NOT NULL | the underlying row id (awards_id / rsvp_id / …) |
| `mundane_id` | int, NOT NULL | the reactor |
| `reaction` | varchar(16), NOT NULL | preset key: `huzzah`/`valor`/`honor`/`heart` |
| `created_at` | datetime NOT NULL DEFAULT CURRENT_TIMESTAMP | |

- `UNIQUE KEY uniq_react (entity_type, entity_id, mundane_id, reaction)` —
  one row per (entity, reactor, key); makes `React` idempotent via
  `INSERT IGNORE` and lets the unique key absorb double-clicks.
- `KEY by_entity (entity_type, entity_id)` — the batched count fetch
  (`GetReactionsBulk` does one `IN (...)` over `entity_id` for a fixed type).
- `KEY by_reactor (mundane_id, entity_type)` — future "things I reacted to";
  also keeps the viewer's-own-reaction lookup cheap.

**Migration:** `db-migrations/2026-06-21-add-reaction.sql` — additive,
idempotent (`CREATE TABLE IF NOT EXISTS`), applied manually (no runner),
copying the style of `db-migrations/2026-06-20-add-friendship.sql`.

```sql
-- Reactions — generic polymorphic reaction primitive (shared by feed/profile
-- awards now; unit_post reserved for the Unit Feed feature).
-- Additive / non-destructive. Applied manually (no runner).
-- Design: docs/superpowers/specs/2026-06-21-reactions-design.md
CREATE TABLE IF NOT EXISTS `ork_reaction` (
  `reaction_id` int(11)     NOT NULL AUTO_INCREMENT,
  `entity_type` varchar(32) NOT NULL,
  `entity_id`   int(11)     NOT NULL,
  `mundane_id`  int(11)     NOT NULL,
  `reaction`    varchar(16) NOT NULL,
  `created_at`  datetime    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`reaction_id`),
  UNIQUE KEY `uniq_react` (`entity_type`, `entity_id`, `mundane_id`, `reaction`),
  KEY `by_entity` (`entity_type`, `entity_id`),
  KEY `by_reactor` (`mundane_id`, `entity_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 1.1 `entity_type` registry (lib-owned, explicit table)

The table is generic; the *accepted* `entity_type` values are a closed
allowlist held in `Reaction::$ENTITY_TYPES`. Each entry declares whether the
type resolves an **owner** (for the cross-react notification) and how.

| entity_type | source row | entity_id is | owner resolution (for notify) | ships v1 |
|---|---|---|---|---|
| `award` | `ork_awards` | `awards_id` | `ork_awards.mundane_id` (the recipient) | yes |
| `feed_award` | `ork_awards` | `awards_id` | `ork_awards.mundane_id` | yes |
| `feed_rsvp` | `ork_event_rsvp` | `rsvp_id` | `ork_event_rsvp.mundane_id` | yes |
| `unit_post` | (Unit Feed) | unit-post id | unit-post author mundane_id | **reserved — not built here** |

`award` and `feed_award` intentionally share the **same** `entity_id`
(`awards_id`) but are **distinct entity_types** so the two surfaces keep
independent count namespaces (a profile-awards reaction and a feed reaction to
the same award do not merge). Owner resolution for both reads
`ork_awards.mundane_id`. The lib's `ResolveOwner($type, $id)` switch is the only
place that maps a type to its owner query; an unmapped type returns `0` (no
notify, never an error).

## 2. Layers

### `system/lib/ork3/class.Reaction.php`

Auto-registers as `Ork3::$Lib->reaction` (startup.php scan; class extends
`Ork3`, constructor calls `parent::__construct()`). The **only** layer that
touches `$DB`/yapo for `ork_reaction`. Every raw query calls `$this->db->Clear()`
first (project rule). The reactor `mundane_id` is always passed in by the
controller from the session — the lib trusts it as the acting user and scopes
all writes to it.

Registries (private static):

```php
/** Preset reaction keys → {icon, label}. The closed reaction set.
 *  Icons are FontAwesome 5.8.2-safe (the live build pins FA 5.8.2). */
private static $REACTIONS = [
    'huzzah' => ['icon' => 'fas fa-glass-cheers', 'label' => 'Huzzah'],
    'valor'  => ['icon' => 'fas fa-fist-raised',  'label' => 'Valor'],
    'honor'  => ['icon' => 'fas fa-shield-alt',   'label' => 'Honor'],
    'heart'  => ['icon' => 'fas fa-heart',        'label' => 'Heart'],
];

/** Accepted entity types (the closed allowlist; unit_post reserved). */
private static $ENTITY_TYPES = ['award', 'feed_award', 'feed_rsvp', 'unit_post'];
```

Public methods:

- `GetPresets()` — returns `self::$REACTIONS` (ordered key→icon/label) so the
  controller/UI render the same canonical set without hardcoding it twice.
- `React($mundaneId, $entityType, $entityId, $reaction)` — validate:
  `$mundaneId > 0`, `$entityType` in `$ENTITY_TYPES`, `$entityId > 0`,
  `$reaction` in `$REACTIONS`. `INSERT IGNORE` the row (unique key makes a
  repeat no-op). On a *new* row (ROW_COUNT == 1) resolve the owner via
  `ResolveOwner` and, if the owner exists and `!= $mundaneId`, fire a
  best-effort `reaction` notification (§4). Returns
  `['Status'=>0|1, 'Error'=>?]`.
- `Unreact($mundaneId, $entityType, $entityId, $reaction)` — validate the same
  inputs, then `DELETE ... WHERE entity_type=? AND entity_id=? AND
  mundane_id=$mundaneId AND reaction=?`. Scoped to the reactor — a user can only
  delete their **own** reaction. No notification. Returns status tuple.
- `GetReactions($entityType, $entityId, $viewerId = 0)` — per-reaction counts
  for one entity plus the viewer's own selected keys. Returns:
  ```php
  ['Status'=>0,
   'Counts'=>['huzzah'=>3,'valor'=>0,'honor'=>1,'heart'=>0],  // every preset key, 0-filled
   'Mine'=>['huzzah'],                                         // viewer's keys, [] if not logged in
   'Total'=>4]
  ```
  Counts are 0-filled across the full preset set so the UI never has to merge.
- `GetReactionsBulk($entityType, array $entityIds, $viewerId = 0)` — the feed
  batcher. ONE grouped query over `entity_id IN (...)` (int-cast list) for the
  fixed `$entityType`, plus ONE query for the viewer's own rows over the same
  set. Returns a map keyed by `entity_id`, each value the same shape as
  `GetReactions` (with the 0-filled `Counts`/`Mine`/`Total`). Entities with no
  reactions still appear (0-filled) so the host can render an empty bar
  uniformly. Avoids N+1 over a 30-item feed page.

Private helpers:

- `ResolveOwner($entityType, $entityId)` — the only type→owner map. `award` /
  `feed_award` → `SELECT mundane_id FROM ork_awards WHERE awards_id = ?`;
  `feed_rsvp` → `SELECT mundane_id FROM ork_event_rsvp WHERE rsvp_id = ?`;
  `unit_post` → reserved (returns 0 until Feature C wires it); default → 0.
- `notifyOwner($reactorId, $ownerId, $entityType, $entityId, $reaction)` —
  best-effort `reaction` notification (§4), `try/catch (\Throwable)`-swallowed.

Note on the DB layer: this stack's `query()` does **not** apply `SetData()`
bindings (only `Execute()`/`DataSet()` consume `$this->Data`). Follow the
established file convention — int-cast all ids before interpolation, and
validate `$entityType`/`$reaction` against the static allowlists (so only known
fixed slugs ever reach SQL) before building the statement. `$DB->Clear()`
before every raw query, and confirm new-row inserts with `SELECT ROW_COUNT()`
(mirrors `Friendship::Accept` / `Notification::CreateBulk`).

### `orkui/model/model.Reaction.php`

Thin pass-through (`new APIModel('Reaction')`), forwarding to the lib (per the
architecture-layers rule: model is pass-through + transforms only). Methods
mirror the lib with snake_case names the controller calls:

- `react($mundaneId, $entityType, $entityId, $reaction)`
- `unreact($mundaneId, $entityType, $entityId, $reaction)`
- `get_reactions($entityType, $entityId, $viewerId = 0)`
- `get_reactions_bulk($entityType, array $entityIds, $viewerId = 0)`
- `get_presets()`

### `orkui/controller/controller.ReactionAjax.php`

`Controller_ReactionAjax extends Controller`. **Must be added to the
`$_skipTokenCheck` allow-list in `system/lib/system/class.Controller.php`**
(append `'Controller_ReactionAjax'` to the existing array at
`class.Controller.php:39` — same treatment as `NotificationAjax` /
`FriendAjax`), else the stale-session redirect fires on the AJAX call.

Each action: JSON header, auth-guard on `$this->session->user_id`
(`react`/`unreact` require login; `get`/`bulk` may run for guests with
`viewer_id = 0` so counts still render), sanitize input, call model, echo
`json_encode`. Return shape `{status:0,...}` / `{status:1,error:"..."}`
(PlayerAjax convention). A shared `guard()`/`respond()` preamble mirrors
`controller.FriendAjax.php`.

The reactor mundane_id is ALWAYS `(int)$this->session->user_id` — never read
from the body. `entity_type`/`entity_id`/`reaction` come from POST (write) or
GET (read); the lib re-validates `entity_type`/`reaction` against its
allowlists, so a forged value is rejected there.

## 3. AJAX endpoints

| endpoint | method | calls | notes |
|---|---|---|---|
| `ReactionAjax/react` | POST | `react(uid, type, id, reaction)` | login required; fires owner notify on new row |
| `ReactionAjax/unreact` | POST | `unreact(uid, type, id, reaction)` | login required; scoped to reactor's own row |
| `ReactionAjax/get` | GET | `get_reactions(type, id, uid)` | single entity; `uid`=0 for guests |
| `ReactionAjax/bulk` | POST | `get_reactions_bulk(type, ids[], uid)` | feed batch; `ids` = JSON array or `ids[]` form; capped (e.g. ≤200) |

All reactor identity from `session->user_id`. `bulk` accepts a single
`entity_type` plus a list of ids (one type per call — the feed issues one bulk
call for `feed_award` ids and one for `feed_rsvp` ids, or the host can render
both in one call per type). Response for `get`/`bulk` carries the 0-filled
`counts`, the viewer's `mine` array, and `total` per entity.

## 4. Notifications integration

One new type registered in `Notification::$DEFAULT_ICONS`
(`system/lib/ork3/class.Notification.php`, the static `$DEFAULT_ICONS` array):

- `reaction` → `fas fa-thumbs-up` (FA5.8.2-safe; the live build pins FontAwesome
  5.8.2, so FA6-only glyphs such as `fa-hands-clapping` must not be used).

Fired from `Reaction::React` **only on a newly-inserted row** and **only when**
the resolved owner exists and is not the reactor:

```
title:    "{persona} reacted with {label} to your {thing}"
            e.g. "Sir Roland reacted with Valor to your award"
body:     (optional) the award/event name when cheaply available, else ''
icon:     (defaulted by type)
link_url: award/feed_award → "?Route=Player/profile/{ownerId}"  (awards tab)
          feed_rsvp        → "?Route=Event/index"
payload:  json_encode(['entity_type'=>$type,'entity_id'=>$id,'reaction'=>$key,'from'=>$reactorId])
created_by: $reactorId
```

Delivered via `Ork3::$Lib->notification->Create(...)`, wrapped in
`try/catch (\Throwable)` and `isset(Ork3::$Lib->notification)`-guarded — a
notification failure NEVER blocks or rolls back the reaction write (same
discipline as the award/friend hooks). No bulk fan-out — a reaction notifies
exactly the one owner. `payload` reserves room for a future "X and N others"
rollup but v1 sends one notification per new reaction (de-dup is implicit: a
repeat React is an `INSERT IGNORE` no-op → ROW_COUNT 0 → no notify).

## 5. Surface 1 — Friends Activity Feed

The feed is built by `Friendship::GetActivityFeed($userId, $limit)`
(`system/lib/ork3/class.Friendship.php:551`) and rendered lazily by the
`loadFeed()` block in `revised.js` (~line 13324) into `#friendsFeed` on
`Friendnew_index.tpl`.

**Today** each feed item carries `Type` (`award`/`rsvp`), `Text`, `Icon`, `Ts`,
`Ago`, `LinkUrl` — but **no stable id**. This spec augments the feed so each
item carries a reaction target:

1. **`GetActivityFeed` change** — add the underlying id to each branch's SELECT
   and emit it on the item:
   - Awards branch: add `a.awards_id` → item gets
     `'EntityType' => 'feed_award', 'EntityId' => (int) awards_id`.
   - RSVP branch: add `rs.rsvp_id` → item gets
     `'EntityType' => 'feed_rsvp', 'EntityId' => (int) rsvp_id`.
   (Both ids already exist on rows the query joins; this is two extra SELECT
   columns + two array keys, no new tables.)
2. **`FriendAjax/feed` change** (`controller.FriendAjax.php::feed`, ~line 147) —
   pass `entity_type` + `entity_id` through to the JSON item:
   ```php
   'entity_type' => $it['EntityType'] ?? '',
   'entity_id'   => (int) ($it['EntityId'] ?? 0),
   ```
3. **`loadFeed()` change** (`revised.js`) — after building the item DOM, append
   the reusable reaction bar (§7) seeded with `data-entity-type` /
   `data-entity-id`. To avoid N+1, after rendering all items, collect the
   `feed_award` ids and the `feed_rsvp` ids and issue **one `ReactionAjax/bulk`
   call per type**, then paint each bar's counts/selected state from the map.
   (Feed is logged-in-only, so `viewer_id` is always the session user.)

The feed item link behavior is unchanged; the reaction bar is a sibling row
beneath the item text, not part of the click-through link (so clicking a
reaction does not navigate).

## 6. Surface 2 — Player profile Awards

Awards render in `Playernew_index.tpl` (`#pn-awards-table`, the `foreach
($filteredAwards as $detail)` loop ~line 1994). Each row already exposes
`$detail['AwardsId']` (the `ork_awards.awards_id` PK, used today for
edit/delete/revoke `data-awards-id`).

- Add a reaction bar to each award row (a new cell, or a sub-row beneath the
  award name) seeded `data-entity-type="award"
  data-entity-id="<?= (int)$detail['AwardsId'] ?>"`.
- **Batch the counts server-side at render** (not per-row Ajax): the controller
  (`controller.Player.php::profile`) collects all visible `awards_id`s and calls
  `Model_Reaction::get_reactions_bulk('award', $ids, $uid)` once, passing the
  map to the template as `$AwardReactions`. The template seeds each bar's
  initial counts/selected state from `$AwardReactions[$awardsId]` so the page
  paints reactions on first load with **zero** extra round-trips. Toggling a
  reaction then calls `ReactionAjax/react`/`unreact` and updates that one bar
  optimistically.
- `viewer_id` = `(int)$this->session->user_id` (0 for logged-out viewers, who
  see counts but get no `mine` state and cannot toggle — the bar renders
  read-only when `PnConfig.loggedIn` is false).

Reacting to your own award is allowed but never notifies (owner == reactor).

## 7. Reaction-bar UI component (reusable)

A single small component reused across the feed, profile awards, and (later)
unit posts. It is **markup + CSS + one delegated JS handler** — not a per-surface
reimplementation.

### Markup contract

Each bar is a container carrying its entity coordinates and a button per preset
key. Rendered by a shared PHP partial
(`template/shared/reactions/reaction_bar.tpl`, plain PHP per the .tpl rule) for
server-rendered surfaces, and by a matching JS builder for the feed (which
renders client-side):

```html
<div class="rx-bar" data-entity-type="award" data-entity-id="123">
  <button class="rx-btn" data-reaction="huzzah" aria-pressed="false">
    <i class="rx-icon fas fa-glass-cheers" aria-hidden="true"></i><span class="rx-count">3</span>
  </button>
  <button class="rx-btn" data-reaction="valor" aria-pressed="true"> … </button>
  <!-- honor, heart … -->
</div>
```

- The preset set (icon class + label per key) is emitted from
  `Reaction::GetPresets()` (single source of truth — never hardcode the FA icon
  classes/keys in the template or JS twice).
- A button with `aria-pressed="true"` and a `.rx-on` class is one the viewer has
  given; clicking toggles it.
- Zero-count buttons still render (faded) so all four keys are always offerable;
  the count span is hidden/blank at 0 to keep the bar quiet.
- Logged-out: bar renders read-only (`.rx-readonly`, no `aria-pressed`, clicks
  ignored) so guests still see counts.

### JS hook — `revised.js`

A new self-invoking section with a **`PnConfig` guard, never
`document.getElementById`** (the external script loads mid-page; bars defined
after the `<script src>` tag are not yet in the DOM):

```js
(function () {
  if (typeof PnConfig === 'undefined') return;   // config-flag guard, not getElementById
  // delegated click handler on document for `.rx-btn`
  // optimistic toggle: flip aria-pressed/.rx-on, ++/-- the count span,
  // then POST ReactionAjax/react|unreact; on {status:1} revert + tnToast(err)
  // helper paintBar(el, data) seeds a bar from a {counts,mine,total} payload
  // helper hydrateBulk(type, nodeList) → one ReactionAjax/bulk call → paintBar each
})();
```

- **Toggle is optimistic**: update the bar immediately, send the request, and
  revert on failure (surfacing the error via the existing `tnToast`, never a
  native `alert`).
- **No native `confirm()`** — reacting/unreacting is non-destructive and needs
  no confirmation; there is no `tnConfirm` flow here (un-reacting only removes
  the viewer's own reaction).
- The feed calls `hydrateBulk('feed_award', …)` / `hydrateBulk('feed_rsvp', …)`
  after painting items; profile awards are seeded server-side (§6) so they need
  no hydrate call.

### CSS — `script`/CSS sibling, dark-mode from the start

New `rx-` classes (in the reactions partial's companion stylesheet or the
existing revised CSS bundle). **Dark mode is the selector
`html[data-theme="dark"]`** (NOT `body.dark-mode`) — every `rx-` color,
border, and faded/zero state ships a dark override from the start. The bar must
be walked in dark mode on both surfaces before "done."

- **No native `title` tooltips** — the per-button label ("Huzzah", "Valor", …)
  uses the `data-tip` CSS pattern (wrap + stay on-screen; right-anchor if the
  bar sits in an Actions column on the awards table).
- Any heading introduced (none expected) would reset the global `h1–h6`
  gray-box style; the bar uses no headings.

## 8. Frontend conventions (apply to every new surface)

- **Dark mode from the start** — all `rx-` CSS uses `html[data-theme="dark"]`;
  walk the bar (default, hovered, selected, zero, read-only) in dark mode on the
  feed and the awards table before "done."
- **No native dialogs** — non-destructive toggle, no `confirm()`; errors via
  `tnToast`, never `alert()`.
- **No native tooltips** — `data-tip` for the reaction labels (wrap +
  on-screen; right-anchor in the awards Actions area).
- **revised.js IIFE guard** is `typeof PnConfig === 'undefined'` / a `PnConfig`
  flag — never `document.getElementById`.
- **Preset set rendered once** from `Reaction::GetPresets()` — keys/icon classes
  are never duplicated across PHP and JS.
- **`$DB->Clear()`** before every raw query in `class.Reaction.php`; int-cast
  ids and allowlist-validate `entity_type`/`reaction` before any interpolation.

## 9. Integration points (file-by-file)

| file | change |
|---|---|
| `db-migrations/2026-06-21-add-reaction.sql` | **new** — `ork_reaction` table |
| `system/lib/ork3/class.Reaction.php` | **new** — lib + registries |
| `orkui/model/model.Reaction.php` | **new** — pass-through |
| `orkui/controller/controller.ReactionAjax.php` | **new** — JSON actions |
| `system/lib/system/class.Controller.php` | add `'Controller_ReactionAjax'` to `$_skipTokenCheck` (line ~39) |
| `system/lib/ork3/class.Notification.php` | add `'reaction' => 'fas fa-thumbs-up'` (FA5.8.2-safe) to `$DEFAULT_ICONS` |
| `system/lib/ork3/class.Friendship.php` | `GetActivityFeed`: SELECT `a.awards_id` / `rs.rsvp_id`; emit `EntityType`/`EntityId` per item |
| `orkui/controller/controller.FriendAjax.php` | `feed()`: pass `entity_type`/`entity_id` into the JSON item |
| `orkui/controller/controller.Player.php` | `profile()`: bulk-fetch `award` reactions for visible awards_ids → `$AwardReactions` |
| `orkui/template/shared/reactions/reaction_bar.tpl` | **new** — shared plain-PHP partial |
| `orkui/template/revised-frontend/Playernew_index.tpl` | render the bar per award row, seeded from `$AwardReactions` |
| `orkui/template/revised-frontend/script/revised.js` | feed `loadFeed()` appends bars + `hydrateBulk`; new `rx-` toggle section (PnConfig-guarded); seed `PnConfig.loggedIn` if not already present |
| revised CSS bundle / reactions stylesheet | `rx-` styles + `html[data-theme="dark"]` overrides |

## 10. Testing

- Lib methods via the local curl-auth session pattern (login once, one cookie
  jar; single-device sessions). App container `ork3-php8-app`; 500s in
  `docker logs ork3-php8-app`.
- **React/Unreact lifecycle:** `React` inserts one row; a repeat `React`
  (same key) is an idempotent no-op (unique key, ROW_COUNT 0, no 2nd notify);
  `Unreact` removes only the viewer's own row; a different user's reaction on
  the same entity is untouched.
- **Multi-key:** a user can hold `huzzah`+`heart` on one entity simultaneously
  (two rows); counts reflect both.
- **Counts shape:** `GetReactions` returns every preset key 0-filled, the
  viewer's `Mine` set, and `Total`. `GetReactionsBulk` returns a map keyed by
  `entity_id` with the same shape; entities with zero reactions still appear
  0-filled; one query per type (verify no N+1 over a 30-item feed page).
- **entity_type allowlist:** a forged `entity_type` (e.g. `mundane`) is rejected
  at the lib boundary (Status 1), never hits SQL.
- **Auth scoping:** reactor is always `session->user_id`; a user cannot delete
  another user's reaction; guests (`viewer_id`=0) get counts but no `mine` and
  cannot toggle.
- **Notification:** reacting to someone else's award/feed item fires exactly one
  `reaction` notification to the owner on the new row; re-reacting (no-op) fires
  none; reacting to your **own** entity fires none; a forced notification
  failure does not roll back the reaction (best-effort discipline).
- **Feed entity ids:** `GetActivityFeed` items carry the correct
  `feed_award`/`feed_rsvp` `EntityType`+`EntityId`; the bar on a feed item
  reacts against the right underlying `awards_id`/`rsvp_id`.
- **Profile awards:** the awards table seeds counts server-side (no per-row
  Ajax on load); toggling updates the bar and persists across reload.
- **Dark-mode walk** of the reaction bar on both surfaces (default / selected /
  zero / read-only / hovered) before "done"; `data-tip` labels wrap and stay
  on-screen (right-anchored in the awards Actions column).
