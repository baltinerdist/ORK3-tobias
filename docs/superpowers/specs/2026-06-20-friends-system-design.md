# Friends System — Design

**Date:** 2026-06-20
**Branch:** `feature/social-features`
**Status:** Approved design, pending implementation plan

## Purpose

Add a mutual-friends social graph to the ORK and prove its value with three
downstream features. Friends build directly on the Notifications foundation
shipped 2026-06-20 (`docs/superpowers/specs/2026-06-20-notifications-system-design.md`):
friend requests and acceptances are new notification sources, reusing the
existing fan-out/snapshot delivery.

v1 ships the relationship graph end-to-end plus three consumers that demonstrate
what the graph unlocks:

1. **Friend activity feed** — friends' awards earned + event RSVPs, newest-first.
2. **"Friends attending this event"** — on event pages.
3. **Recommend a friend** — one-tap award recommendation from the friends hub.

In-app only. No email, no push, no real-time. Notifications about friend
activity reflect page-load state via the existing bell.

## Decisions (locked during brainstorming)

- **Relationship model: mutual friends.** A requests, B accepts; both become
  friends. Consent-gated.
- **Anyone can request anyone.** No park/kingdom scoping on requests (consistent
  with the unit-add / award-giver global searches). Blocking is the per-person
  escape hatch.
- **Block = one-way request gate ONLY.** When A blocks B, B can no longer send A
  a friend request. Block does **not** unfriend, does **not** hide either
  person's profile, and does **not** affect the feed or any other visibility.
  It is orthogonal to friendship.
- **Friend list & count are fully private to non-friends.** Only confirmed
  friends (and the owner) see the friend list OR the count. Non-friends see
  nothing — no list, no number.
- **Decline / cancel / unfriend delete the relationship row.** No tombstone;
  repeat-request spam is handled by Block. Only `pending` and `accepted` rows
  ever exist in `ork_friendship`.
- **Feed sources v1: awards + RSVPs only. Level-ups dropped.**
  `ork_class_reconciliation` stores only the *current* level with no
  timestamp/history, so a time-ordered "leveled up" event is not cleanly
  derivable. Awards (`ork_awards.date`) and RSVPs (`ork_event_rsvp`) are both
  timestamped and feed-ready. Level-ups are deferred (would need a new
  level-change history table — its own future project).

## Non-goals (v1)

- One-way "follow" relationships (mutual only).
- Real-time / polling / toast delivery (badge reflects page-load state, per the
  notifications design).
- Direct messaging (the graph is a prerequisite; DMs are a separate future
  project).
- Privacy gating of profile data to friends-only (contact info, belt, etc.).
- Friend-of-friend "people you may know" suggestions.
- Mutual-friends indicator on profiles ("you both know X").
- Level-up feed source (see Decisions).
- Friend-scoped leaderboards / comparison.

## Architecture overview

Follows the established three-layer pattern, mirroring the notifications stack:

```
index.php?Route=Friend/action          (controller.Friend.php — UI pages)
index.php?Route=FriendAjax/action      (controller.FriendAjax.php — JSON actions)
  → orkui/model/model.Friendship.php   (thin pass-through)
  → Ork3::$Lib->friendship             (system/lib/ork3/class.Friendship.php)
  → $DB / yapo on ork_friendship + ork_friend_block
```

Person identity is `ork_mundane.mundane_id` throughout. Logged-in user is
`$this->session->user_id` in controllers; lib service calls resolve a mundane_id
from `$this->session->token` via `authorization->IsAuthorized` where a token is
required.

## 1. Data model

### `ork_friendship`

One row per relationship, canonically ordered so a pair can never duplicate.

| column | type | purpose |
|---|---|---|
| `friendship_id` | int PK auto-inc | |
| `mundane_lo` | int, NOT NULL | the smaller of the two mundane_ids |
| `mundane_hi` | int, NOT NULL | the larger of the two mundane_ids |
| `status` | enum(`pending`,`accepted`) NOT NULL | |
| `requested_by` | int, NOT NULL | who sent the request (direction for `pending`) |
| `requested_at` | datetime NOT NULL DEFAULT CURRENT_TIMESTAMP | |
| `responded_at` | datetime, null | set when accepted |

- `UNIQUE KEY uniq_pair (mundane_lo, mundane_hi)` — one edge per pair.
- `KEY by_lo (mundane_lo, status)` and `KEY by_hi (mundane_hi, status)` — so a
  user's friends/pending can be fetched from either side without a full scan.

**Canonical ordering:** the lib always sorts the two ids before read/write
(`mundane_lo = min`, `mundane_hi = max`); `requested_by` records who initiated.

### `ork_friend_block`

Directional, orthogonal to friendship.

| column | type | purpose |
|---|---|---|
| `block_id` | int PK auto-inc | |
| `blocker_id` | int, NOT NULL | the user who blocked |
| `blocked_id` | int, NOT NULL | the user who is blocked from requesting |
| `created_at` | datetime NOT NULL DEFAULT CURRENT_TIMESTAMP | |

- `UNIQUE KEY uniq_block (blocker_id, blocked_id)`.
- `KEY by_blocked (blocked_id)` — request guard checks "did the target block me?".

**Migration:** `db-migrations/2026-06-20-add-friendship.sql`, copying the style of
`db-migrations/2026-06-20-add-notification.sql` (additive, idempotent, applied
manually — no runner).

## 2. Layers

### `system/lib/ork3/class.Friendship.php`

Auto-registers as `Ork3::$Lib->friendship` (startup.php scan). The **only** layer
that touches `$DB`/yapo for `ork_friendship` / `ork_friend_block`. Every method
calls `$DB->Clear()` first (per project rule). All writes scope to / validate the
acting user so a user can only mutate their own relationships.

Write methods:

- `Request($fromId, $toId)` — validate: not self, both active, no existing edge
  (pending or accepted), and target has **not** blocked `$fromId`. Insert
  `pending` with `requested_by = $fromId`. On success fire a `friend_request`
  notification to `$toId` (best-effort). Returns status tuple.
- `Accept($userId, $otherId)` — flip the pending edge to `accepted` + set
  `responded_at`, but ONLY where the pending row was `requested_by = $otherId`
  (you can only accept a request someone sent *you*). Fire `friend_accept`
  notification to `$otherId`.
- `Decline($userId, $otherId)` — delete the pending edge where
  `requested_by = $otherId` (declining an incoming request).
- `Cancel($userId, $otherId)` — delete the pending edge where
  `requested_by = $userId` (withdrawing your own outgoing request).
- `Unfriend($userId, $otherId)` — delete the `accepted` edge for the pair.
- `Block($userId, $targetId)` — insert into `ork_friend_block`
  (`blocker_id=$userId`, `blocked_id=$targetId`); idempotent. Does NOT touch
  `ork_friendship` (per spec — block is request-gate only).
- `Unblock($userId, $targetId)` — delete the block row.

Read methods:

- `GetStatus($userId, $otherId)` — single source of truth for button rendering.
  Returns one of: `none`, `pending_out` (you requested them), `pending_in` (they
  requested you), `friends`, plus a boolean `blocked_by_me`. Does NOT reveal
  whether the *other* user blocked *you* (a request simply fails for that case).
- `GetFriends($userId, $limit = null, $offset = 0)` — accepted friends with
  persona/park/kingdom/heraldry for display.
- `GetFriendIds($userId)` — flat array of accepted-friend mundane_ids (for feed
  + attending intersection).
- `GetPendingIncoming($userId)` — pending edges where `requested_by != $userId`
  (the Requests inbox).
- `CountFriends($userId)`.
- `AreFriends($a, $b)`.

### `orkui/model/model.Friendship.php`

Thin pass-through (`new APIModel('Friendship')`), forwarding to the lib (per the
architecture-layers rule: model is pass-through + transforms only).

### `orkui/controller/controller.FriendAjax.php`

`Controller_FriendAjax extends Controller`. **Must be added to the
`$_skipTokenCheck` allow-list in `system/lib/system/class.Controller.php`** (same
as `NotificationAjax`). Each action: JSON header, auth-guard on
`$this->session->user_id`, sanitize input, call model, echo `json_encode`.
Return shape `{status:0,...}` / `{status:1,error}` (PlayerAjax convention).

Actions: `request`, `accept`, `decline`, `cancel`, `unfriend`, `block`,
`unblock`, `status` (relationship state for a target), `list` (friends list —
**friends-only gate**: returns rows only if the viewer is the owner or a
confirmed friend of the owner), `pending` (your incoming requests), `feed`
(paginated activity feed).

### `orkui/controller/controller.Friend.php`

`Controller_Friend extends Controller`. Renders the **My Friends hub**
(`Friend/index`) — a logged-in-only page with three tabs (Friends / Requests /
Activity Feed). Loads the first tab server-side; tab switches and pagination use
`FriendAjax`.

## 3. AJAX endpoints

| endpoint | calls | notes |
|---|---|---|
| `FriendAjax/request` | `Request(uid, target)` | fails silently-safe if target blocked uid |
| `FriendAjax/accept` | `Accept(uid, other)` | |
| `FriendAjax/decline` | `Decline(uid, other)` | |
| `FriendAjax/cancel` | `Cancel(uid, other)` | |
| `FriendAjax/unfriend` | `Unfriend(uid, other)` | |
| `FriendAjax/block` | `Block(uid, target)` | |
| `FriendAjax/unblock` | `Unblock(uid, target)` | |
| `FriendAjax/status` | `GetStatus(uid, target)` | drives button re-render after an action |
| `FriendAjax/list` | `GetFriends(ownerId)` | friends-only gate enforced in controller |
| `FriendAjax/pending` | `GetPendingIncoming(uid)` | Requests tab |
| `FriendAjax/feed` | feed query (see §6) | paginated |

All scoped to `session->user_id`. `list` additionally enforces the friends-only
visibility rule against the requested `ownerId`.

## 4. Notifications integration

Two new types registered in `Notification::$DEFAULT_ICONS`:

- `friend_request` → `fas fa-user-plus`: title "*{persona}* sent you a friend
  request", `link_url` → `Friend/index` (Requests tab). Fired from
  `Friendship::Request`.
- `friend_accept` → `fas fa-user-check`: title "*{persona}* accepted your friend
  request", `link_url` → the accepter's profile. Fired from `Friendship::Accept`.

Both via `Ork3::$Lib->notification->Create(...)`, wrapped defensively — a
notification failure must never roll back or block the friendship write (same
discipline as the award/rec hooks in `class.Award.php`).

## 5. Profile surfacing — `Playernew_index.tpl`

Profile is rendered by `controller.Player.php::profile($id)`. Viewed player is
`$id`; logged-in user is `$uid = (int)$this->session->user_id`; self-vs-other is
already computed (`$uid === (int)$id`).

- **Friend button** in the profile header, gated `LoggedIn && $uid !== $id`.
  States driven by `GetStatus($uid, $id)`:
  - `none` → **Add Friend** (→ `request`)
  - `pending_out` → **Request Pending** (→ `cancel`)
  - `pending_in` → **Respond ▾** (Accept → `accept`, Decline → `decline`)
  - `friends` → **Friends ▾** (Unfriend → `unfriend`, Block → `block`)
  - `blocked_by_me` → **Blocked** (Unblock → `unblock`); takes visual precedence.
- **Friends section** (a tab/panel alongside the existing Units/Awards/Notes
  tabs): rendered **only** when the viewer is the owner OR a confirmed friend of
  the owner. Non-friends: the section and its count are entirely absent
  (hide-both rule). The controller computes the visibility flag via
  `AreFriends($uid, $id)` (or `$uid === $id`) and passes it to the template.

Button actions go through `FriendAjax`; on success the button re-renders from a
fresh `FriendAjax/status`. Confirmations (unfriend/block) use `tnConfirm()` —
never native `confirm()`. No native `title` tooltips — use the `data-tip`
pattern.

## 6. My Friends hub — `Friend/index`

Logged-in-only page, three tabs:

- **Friends** — `GetFriends(uid)`: persona, park/kingdom, heraldry/avatar, link
  to profile. Each row carries a **Recommend** action (see §7) and a manage
  affordance (unfriend/block via `tnConfirm`).
- **Requests** — `GetPendingIncoming(uid)`: incoming requests with Accept /
  Decline buttons; badge count in the tab label.
- **Activity Feed** — see below.

### Activity Feed query

Friends-scoped, two sources merged and sorted newest-first, paginated:

1. **Awards earned** — `ork_awards` rows where `mundane_id IN (GetFriendIds)`,
   carrying `date`, `award`/`kingdomaward` name, `given_by_id`, `at_event_id`.
   Renders "*{friend}* received *{award}*".
2. **Event RSVPs** — `ork_event_rsvp` (status `going`) joined to
   `event_calendardetail` where `mundane_id IN (GetFriendIds)`, carrying
   `modified` (when they RSVP'd) and `event_start` / event name. Renders
   "*{friend}* is going to *{event}*".

Empty friend set → empty feed (skip the IN-query). Merge in PHP, sort by the
relevant timestamp DESC, page with limit/offset. No new feed tables — both
sources already exist.

## 7. Recommend a friend

Reuses the existing recommendation path end-to-end — **no new recs logic**:

- `Player::AddAwardRecommendation($request)` (`class.Player.php:2307`) via
  `Model_Player::add_player_recommendation`, route
  `Player/profile/{id}/addrecommendation`. Params: `Token` (recommender resolved
  from it), `MundaneId` (recipient = the friend), `AwardId`/`KingdomAwardId`,
  `Rank`, `Reason`.
- In the Friends hub, each friend row's **Recommend** action opens the existing
  recommendation form/modal pre-filled with that friend as the recipient and
  submits through the existing path. The friends list simply provides a faster
  on-ramp to a flow players already use from profiles.

## 8. Frontend conventions (apply to every new surface)

- **Dark mode from the start** — all CSS uses `html[data-theme="dark"]`; walk the
  button states, hub tabs, feed, and attending widget in dark mode before
  "done." (Pre-flight: modal headers, ghost buttons, labels, placeholders.)
- **Heading reset** — any heading inside a hub card/panel must reset the global
  `h1–h6` gray-box style (`background:transparent; border:none; padding:0;
  border-radius:0`).
- **No native dialogs** — `tnConfirm()` for unfriend/block confirmations.
- **No native tooltips** — `data-tip` CSS tooltips (wrap + stay on-screen).
- **Player search** for finding people to friend reuses the existing
  `kn-ac-results` dropdown pattern (NOT jQuery UI autocomplete); requests are
  global/unscoped so no kingdom scoping needed, but URLs still build with `&q=`.
- JS follows the bespoke open/close-function convention; in `revised.js`, guard
  IIFEs on a config flag, never `getElementById`.

## 9. Testing

- Lib methods via the local curl-auth session pattern (login once, one cookie
  jar; single-device sessions).
- Lifecycle: request → target sees `pending_in` + gets a `friend_request`
  notification → accept → both `friends` + requester gets `friend_accept` →
  unfriend removes the edge. Decline/cancel delete the pending row.
- Block: blocked user's `request` fails; block does NOT unfriend an existing
  friendship and does NOT change profile/feed visibility.
- Canonical ordering: `Request(A→B)` then `Request(B→A)` cannot create a second
  edge (unique constraint + min/max sort).
- Auth scoping: a user cannot accept/decline a request not addressed to them,
  cannot unfriend a pair they're not in, cannot `list` a non-friend's friends.
- Friends-only visibility: non-friend gets neither list nor count from `list`
  and sees no Friends section on the profile.
- Feed: awards + RSVPs from friends only, sorted newest-first, empty set safe.
- Attending: only the viewer's friends appear in the event widget.
- Dark-mode walk of all new surfaces before "done."
```
