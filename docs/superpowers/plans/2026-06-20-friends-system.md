# Friends System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a mutual-friends social graph to the ORK plus three consumers (activity feed, friends-attending-event, recommend-a-friend), building on the existing notifications foundation.

**Architecture:** Standard three-layer ORK pattern — `controller.Friend*.php` (UI + JSON AJAX) → `model.Friendship.php` (thin pass-through) → `Ork3::$Lib->friendship` (`class.Friendship.php`, the only layer touching `$DB`/yapo). Two new tables (`ork_friendship`, `ork_friend_block`). Friend requests/acceptances fire best-effort notifications through the already-shipped `Ork3::$Lib->notification`.

**Tech Stack:** PHP 8 / MySQL (MariaDB), yapo data layer, Docker (`docker-compose.php8.yml`, app at `http://localhost:19080/orkui/`), vanilla JS (`revised.js`), plain-PHP `.tpl` templates.

**Spec:** `docs/superpowers/specs/2026-06-20-friends-system-design.md`

---

## Testing methodology (read first)

This codebase has **no unit-test harness**. Verification follows the established
ORK convention (see `reference_local_curl_auth_session.md` / the notifications
spec):

1. **Lint** every PHP file you touch: `php -l <file>` → expect `No syntax errors detected`.
2. **Curl-auth integration** against the running Docker app. Login once into a
   single cookie jar (the app enforces single-device sessions, so login + all
   test calls must run in ONE shell block):

```bash
# Local curl-auth session helper (one cookie jar; login + calls in one block).
JAR=/tmp/ork_cj.txt; BASE=http://localhost:19080/orkui/index.php
rm -f "$JAR"
curl -s -c "$JAR" -b "$JAR" "$BASE?Route=Login/login" \
  --data-urlencode 'username=<a-known-local-username>' \
  --data-urlencode 'password=anything' >/dev/null
# now reuse "$JAR" for authenticated calls in this SAME block:
curl -s -c "$JAR" -b "$JAR" "$BASE?Route=FriendAjax/status&target=2"
```

3. App container is `ork3-php8-app`; HTTP 500s surface in `docker logs ork3-php8-app`.
4. **DB checks** run inside the DB container. Use the existing DB init/connection
   the project already uses; a quick row check pattern:

```bash
docker exec ork3-php8-app php -r '$p=new PDO("mysql:host=db;dbname=ork","ork","ork");
 foreach($p->query("SELECT * FROM ork_friendship")->fetchAll(PDO::FETCH_ASSOC) as $r){print_r($r);}'
```
(Adjust DSN/creds to the project's actual local values — check `agent-instructions/claude.md` if the above differs.)

Each task's "verify" steps below use these mechanisms instead of a unit framework.

**Editing PHP — normalize-first rule:** before a multi-line Edit on an existing
PHP file, run `awk '/^\t/{c++} END{print c+0}' <file>` — `0` = clean (use Edit
directly); non-zero = tab-indented, first run
`php tools/php-cs-fixer.phar fix --config=.php-cs-fixer.dist.php <file>` then Edit.
New files: write space-indented (PSR-12); the pre-commit hook reformats anyway.

**Commit discipline:** stage files **explicitly** (never `git add -A`/`.`).
Never stage `class.Authorization.php`, `CLAUDE.md`, or `agent-instructions/`.
Run `git diff --cached` before each commit (concurrent-session safety).

---

## File map

**Create:**
- `db-migrations/2026-06-20-add-friendship.sql` — two tables, idempotent.
- `system/lib/ork3/class.Friendship.php` — relationship lib (`Ork3::$Lib->friendship`).
- `orkui/model/model.Friendship.php` — pass-through.
- `orkui/controller/controller.FriendAjax.php` — JSON actions.
- `orkui/controller/controller.Friend.php` — "My Friends" hub page.
- `orkui/template/revised-frontend/Friendnew_index.tpl` — hub (3 tabs).

**Modify:**
- `system/lib/ork3/class.Notification.php` — register `friend_request`/`friend_accept` icons.
- `system/lib/system/class.Controller.php` — add `Controller_FriendAjax` to `$_skipTokenCheck`.
- `orkui/controller/controller.Player.php` — pass friend status + visibility flag to profile.
- `orkui/template/revised-frontend/Playernew_index.tpl` — friend button + friends section.
- `orkui/controller/controller.Event.php` — friend-filtered RSVP list for the widget.
- `orkui/template/revised-frontend/Eventnew_index.tpl` — "friends attending" widget.
- `orkui/template/revised-frontend/script/revised.js` — friend button + hub JS.
- `orkui/template/default/style/orkui.css` — friend UI styles (dark-mode aware).

---

## Task 1: Database migration

**Files:**
- Create: `db-migrations/2026-06-20-add-friendship.sql`

- [ ] **Step 1: Write the migration** (copy the idempotent style of `db-migrations/2026-06-20-add-notification.sql`)

```sql
-- Friends system — mutual friendship graph + directional block list.
-- Additive / non-destructive. Applied manually (no runner).
-- Design: docs/superpowers/specs/2026-06-20-friends-system-design.md

-- One row per relationship, canonically ordered (mundane_lo < mundane_hi) so a
-- pair can never duplicate. status: pending|accepted. requested_by records who
-- initiated (direction for pending). Decline/cancel/unfriend DELETE the row.
CREATE TABLE IF NOT EXISTS `ork_friendship` (
  `friendship_id` int(11) NOT NULL AUTO_INCREMENT,
  `mundane_lo`    int(11) NOT NULL,
  `mundane_hi`    int(11) NOT NULL,
  `status`        enum('pending','accepted') NOT NULL DEFAULT 'pending',
  `requested_by`  int(11) NOT NULL,
  `requested_at`  datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `responded_at`  datetime DEFAULT NULL,
  PRIMARY KEY (`friendship_id`),
  UNIQUE KEY `uniq_pair` (`mundane_lo`, `mundane_hi`),
  KEY `by_lo` (`mundane_lo`, `status`),
  KEY `by_hi` (`mundane_hi`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Directional block: blocker prevents blocked from sending them a request.
-- Orthogonal to friendship (does NOT unfriend or hide anything).
CREATE TABLE IF NOT EXISTS `ork_friend_block` (
  `block_id`   int(11) NOT NULL AUTO_INCREMENT,
  `blocker_id` int(11) NOT NULL,
  `blocked_id` int(11) NOT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`block_id`),
  UNIQUE KEY `uniq_block` (`blocker_id`, `blocked_id`),
  KEY `by_blocked` (`blocked_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

- [ ] **Step 2: Apply it to the local DB**

Run (adjust DSN/creds to local values if different):
```bash
docker exec -i ork3-php8-app sh -c 'mysql -h db -uork -pork ork' < db-migrations/2026-06-20-add-friendship.sql
```
Expected: no error (and re-running is a no-op via `IF NOT EXISTS`).

- [ ] **Step 3: Verify the tables exist**

```bash
docker exec ork3-php8-app sh -c 'mysql -h db -uork -pork ork -e "SHOW TABLES LIKE \"ork_friend%\"; DESCRIBE ork_friendship;"'
```
Expected: both `ork_friendship` and `ork_friend_block` listed; columns match the DDL.

- [ ] **Step 4: Commit**

```bash
git add db-migrations/2026-06-20-add-friendship.sql
git commit -m "Friends: add ork_friendship + ork_friend_block migration"
```

---

## Task 2: Register friend notification icons

**Files:**
- Modify: `system/lib/ork3/class.Notification.php` (the `$DEFAULT_ICONS` map near line 15)

- [ ] **Step 1: Add the two friend types to `$DEFAULT_ICONS`**

Change the map from:
```php
    private static $DEFAULT_ICONS = [
        'award'        => 'fas fa-award',
        'rec_status'   => 'fas fa-clipboard-check',
        'announcement' => 'fas fa-bullhorn',
    ];
```
to:
```php
    private static $DEFAULT_ICONS = [
        'award'          => 'fas fa-award',
        'rec_status'     => 'fas fa-clipboard-check',
        'announcement'   => 'fas fa-bullhorn',
        'friend_request' => 'fas fa-user-plus',
        'friend_accept'  => 'fas fa-user-check',
    ];
```

- [ ] **Step 2: Lint**

Run: `php -l system/lib/ork3/class.Notification.php`
Expected: `No syntax errors detected`

- [ ] **Step 3: Commit**

```bash
git add system/lib/ork3/class.Notification.php
git commit -m "Friends: register friend_request/friend_accept notification icons"
```

---

## Task 3: Friendship lib — `class.Friendship.php`

**Files:**
- Create: `system/lib/ork3/class.Friendship.php`

- [ ] **Step 1: Write the full lib class**

```php
<?php

/**
 * Friendship — mutual friend graph + directional block list.
 *
 * Auto-registers as Ork3::$Lib->friendship (startup.php scan).
 * The ONLY layer that touches $DB/yapo for ork_friendship / ork_friend_block.
 * Every raw query calls $this->db->Clear() first (project rule).
 *
 * Canonical ordering: a relationship is stored once with mundane_lo < mundane_hi;
 * requested_by records who initiated. Decline/cancel/unfriend DELETE the row, so
 * only 'pending' and 'accepted' rows ever exist. Block is a separate, directional
 * table that ONLY gates incoming requests (never unfriends, never hides).
 *
 * Friend request/accept fire best-effort notifications via Ork3::$Lib->notification
 * (swallowed on failure — must never break the relationship write).
 *
 * Design: docs/superpowers/specs/2026-06-20-friends-system-design.md
 */
class Friendship extends Ork3
{
    public function __construct()
    {
        parent::__construct();
    }

    /** Canonical [lo, hi] for a pair (always lo < hi). */
    private function pair($a, $b)
    {
        $a = (int) $a;
        $b = (int) $b;
        return $a < $b ? [$a, $b] : [$b, $a];
    }

    /** Persona display name for a mundane (for notification titles). '' if unknown. */
    private function persona($mundaneId)
    {
        $mundaneId = (int) $mundaneId;
        if ($mundaneId <= 0) {
            return '';
        }
        $this->db->Clear();
        $r = $this->db->query(
            'SELECT persona FROM ' . DB_PREFIX . "mundane WHERE mundane_id = {$mundaneId} LIMIT 1"
        );
        if ($r !== false && $r->next()) {
            return (string) $r->persona;
        }
        return '';
    }

    /** True if $blockerId has blocked $blockedId. */
    private function isBlocked($blockerId, $blockedId)
    {
        $blockerId = (int) $blockerId;
        $blockedId = (int) $blockedId;
        $this->db->Clear();
        $r = $this->db->query(
            'SELECT 1 FROM ' . DB_PREFIX . 'friend_block'
            . " WHERE blocker_id = {$blockerId} AND blocked_id = {$blockedId} LIMIT 1"
        );
        return ($r !== false && $r->next());
    }

    /**
     * Send a friend request from $fromId to $toId.
     * Fails if: self, either missing, already pending/friends, or target blocked sender.
     * @return array ['Status'=>0|1, 'Error'=>?]
     */
    public function Request($fromId, $toId)
    {
        $fromId = (int) $fromId;
        $toId   = (int) $toId;
        if ($fromId <= 0 || $toId <= 0 || $fromId === $toId) {
            return ['Status' => 1, 'Error' => 'Invalid request'];
        }
        // Target blocked the sender → silently refuse (do not leak block state).
        if ($this->isBlocked($toId, $fromId)) {
            return ['Status' => 1, 'Error' => 'Unable to send request'];
        }

        list($lo, $hi) = $this->pair($fromId, $toId);

        // Existing edge? (pending or accepted) → no duplicate.
        $this->db->Clear();
        $r = $this->db->query(
            'SELECT status FROM ' . DB_PREFIX . 'friendship'
            . " WHERE mundane_lo = {$lo} AND mundane_hi = {$hi} LIMIT 1"
        );
        if ($r !== false && $r->next()) {
            $existing = (string) $r->status;
            if ($existing === 'accepted') {
                return ['Status' => 1, 'Error' => 'Already friends'];
            }
            return ['Status' => 1, 'Error' => 'A request is already pending'];
        }

        $this->db->Clear();
        $this->db->Execute(
            'INSERT INTO ' . DB_PREFIX . 'friendship (mundane_lo, mundane_hi, status, requested_by, requested_at)'
            . " VALUES ({$lo}, {$hi}, 'pending', {$fromId}, NOW())"
        );
        $this->db->Clear();

        $this->notifyRequest($fromId, $toId);
        return ['Status' => 0];
    }

    /**
     * Accept a request that $otherId sent to $userId.
     * Only flips the row if the pending request was requested_by $otherId.
     * @return array ['Status'=>0|1, 'Error'=>?]
     */
    public function Accept($userId, $otherId)
    {
        $userId  = (int) $userId;
        $otherId = (int) $otherId;
        if ($userId <= 0 || $otherId <= 0 || $userId === $otherId) {
            return ['Status' => 1, 'Error' => 'Invalid request'];
        }
        list($lo, $hi) = $this->pair($userId, $otherId);

        $this->db->Clear();
        $this->db->Execute(
            'UPDATE ' . DB_PREFIX . 'friendship SET status = \'accepted\', responded_at = NOW()'
            . " WHERE mundane_lo = {$lo} AND mundane_hi = {$hi}"
            . " AND status = 'pending' AND requested_by = {$otherId}"
        );
        $this->db->Clear();

        // Confirm it actually flipped (ROW_COUNT on this connection).
        $affected = 0;
        $r = $this->db->query('SELECT ROW_COUNT() AS n');
        if ($r !== false && $r->next()) {
            $affected = (int) $r->n;
        }
        $this->db->Clear();
        if ($affected < 1) {
            return ['Status' => 1, 'Error' => 'No matching request to accept'];
        }

        $this->notifyAccept($userId, $otherId);
        return ['Status' => 0];
    }

    /** Decline an incoming pending request (requested_by $otherId). */
    public function Decline($userId, $otherId)
    {
        return $this->deletePending($userId, $otherId, (int) $otherId);
    }

    /** Cancel your own outgoing pending request (requested_by $userId). */
    public function Cancel($userId, $otherId)
    {
        return $this->deletePending($userId, $otherId, (int) $userId);
    }

    /** Shared pending-delete keyed on which side initiated. */
    private function deletePending($userId, $otherId, $requestedBy)
    {
        $userId  = (int) $userId;
        $otherId = (int) $otherId;
        if ($userId <= 0 || $otherId <= 0 || $userId === $otherId) {
            return ['Status' => 1, 'Error' => 'Invalid request'];
        }
        list($lo, $hi) = $this->pair($userId, $otherId);
        $requestedBy = (int) $requestedBy;

        $this->db->Clear();
        $this->db->Execute(
            'DELETE FROM ' . DB_PREFIX . 'friendship'
            . " WHERE mundane_lo = {$lo} AND mundane_hi = {$hi}"
            . " AND status = 'pending' AND requested_by = {$requestedBy}"
        );
        $this->db->Clear();
        return ['Status' => 0];
    }

    /** Remove an accepted friendship (either direction). */
    public function Unfriend($userId, $otherId)
    {
        $userId  = (int) $userId;
        $otherId = (int) $otherId;
        if ($userId <= 0 || $otherId <= 0 || $userId === $otherId) {
            return ['Status' => 1, 'Error' => 'Invalid request'];
        }
        list($lo, $hi) = $this->pair($userId, $otherId);

        $this->db->Clear();
        $this->db->Execute(
            'DELETE FROM ' . DB_PREFIX . 'friendship'
            . " WHERE mundane_lo = {$lo} AND mundane_hi = {$hi} AND status = 'accepted'"
        );
        $this->db->Clear();
        return ['Status' => 0];
    }

    /** Block $targetId from requesting $userId (idempotent). Does NOT unfriend. */
    public function Block($userId, $targetId)
    {
        $userId   = (int) $userId;
        $targetId = (int) $targetId;
        if ($userId <= 0 || $targetId <= 0 || $userId === $targetId) {
            return ['Status' => 1, 'Error' => 'Invalid request'];
        }
        $this->db->Clear();
        $this->db->Execute(
            'INSERT IGNORE INTO ' . DB_PREFIX . 'friend_block (blocker_id, blocked_id, created_at)'
            . " VALUES ({$userId}, {$targetId}, NOW())"
        );
        $this->db->Clear();
        return ['Status' => 0];
    }

    /** Remove a block. */
    public function Unblock($userId, $targetId)
    {
        $userId   = (int) $userId;
        $targetId = (int) $targetId;
        if ($userId <= 0 || $targetId <= 0) {
            return ['Status' => 1, 'Error' => 'Invalid request'];
        }
        $this->db->Clear();
        $this->db->Execute(
            'DELETE FROM ' . DB_PREFIX . 'friend_block'
            . " WHERE blocker_id = {$userId} AND blocked_id = {$targetId}"
        );
        $this->db->Clear();
        return ['Status' => 0];
    }

    /**
     * Relationship state of $otherId relative to $userId, for button rendering.
     * @return array ['Status'=>0, 'State'=>'none'|'pending_out'|'pending_in'|'friends',
     *                'BlockedByMe'=>bool]
     */
    public function GetStatus($userId, $otherId)
    {
        $userId  = (int) $userId;
        $otherId = (int) $otherId;
        $state = 'none';
        if ($userId > 0 && $otherId > 0 && $userId !== $otherId) {
            list($lo, $hi) = $this->pair($userId, $otherId);
            $this->db->Clear();
            $r = $this->db->query(
                'SELECT status, requested_by FROM ' . DB_PREFIX . 'friendship'
                . " WHERE mundane_lo = {$lo} AND mundane_hi = {$hi} LIMIT 1"
            );
            if ($r !== false && $r->next()) {
                if ((string) $r->status === 'accepted') {
                    $state = 'friends';
                } elseif ((int) $r->requested_by === $userId) {
                    $state = 'pending_out';
                } else {
                    $state = 'pending_in';
                }
            }
        }
        return [
            'Status'      => 0,
            'State'       => $state,
            'BlockedByMe' => ($userId > 0 && $otherId > 0) ? $this->isBlocked($userId, $otherId) : false,
        ];
    }

    /** True if the two are accepted friends. */
    public function AreFriends($a, $b)
    {
        $a = (int) $a;
        $b = (int) $b;
        if ($a <= 0 || $b <= 0 || $a === $b) {
            return false;
        }
        list($lo, $hi) = $this->pair($a, $b);
        $this->db->Clear();
        $r = $this->db->query(
            'SELECT 1 FROM ' . DB_PREFIX . 'friendship'
            . " WHERE mundane_lo = {$lo} AND mundane_hi = {$hi} AND status = 'accepted' LIMIT 1"
        );
        return ($r !== false && $r->next());
    }

    /** Flat array of accepted-friend mundane_ids for $userId. */
    public function GetFriendIds($userId)
    {
        $userId = (int) $userId;
        $ids = [];
        if ($userId <= 0) {
            return $ids;
        }
        $this->db->Clear();
        $r = $this->db->query(
            'SELECT IF(mundane_lo = ' . $userId . ', mundane_hi, mundane_lo) AS fid'
            . ' FROM ' . DB_PREFIX . 'friendship'
            . " WHERE status = 'accepted' AND (mundane_lo = {$userId} OR mundane_hi = {$userId})"
        );
        if ($r !== false) {
            while ($r->next()) {
                $ids[] = (int) $r->fid;
            }
        }
        return $ids;
    }

    /**
     * Accepted friends of $userId with display fields, persona-sorted.
     * @return array ['Status'=>0, 'Friends'=>[ {MundaneId,Persona,ParkAbbr,KingdomAbbr,HasImage,HasHeraldry} ]]
     */
    public function GetFriends($userId, $limit = null, $offset = 0)
    {
        $userId = (int) $userId;
        if ($userId <= 0) {
            return ['Status' => 0, 'Friends' => []];
        }
        $lim = '';
        if ($limit !== null && (int) $limit > 0) {
            $lim = ' LIMIT ' . (int) $limit . ' OFFSET ' . max(0, (int) $offset);
        }
        $this->db->Clear();
        $r = $this->db->query(
            'SELECT m.mundane_id, m.persona, m.has_image, m.has_heraldry,'
            . ' p.abbreviation AS park_abbr, k.abbreviation AS kingdom_abbr'
            . ' FROM ' . DB_PREFIX . 'friendship f'
            . ' JOIN ' . DB_PREFIX . 'mundane m'
            . "   ON m.mundane_id = IF(f.mundane_lo = {$userId}, f.mundane_hi, f.mundane_lo)"
            . ' LEFT JOIN ' . DB_PREFIX . 'park p ON p.park_id = m.park_id'
            . ' LEFT JOIN ' . DB_PREFIX . 'kingdom k ON k.kingdom_id = m.kingdom_id'
            . " WHERE f.status = 'accepted' AND (f.mundane_lo = {$userId} OR f.mundane_hi = {$userId})"
            . ' ORDER BY m.persona ASC' . $lim
        );
        $out = [];
        if ($r !== false) {
            while ($r->next()) {
                $out[] = [
                    'MundaneId'   => (int) $r->mundane_id,
                    'Persona'     => (string) $r->persona,
                    'ParkAbbr'    => (string) $r->park_abbr,
                    'KingdomAbbr' => (string) $r->kingdom_abbr,
                    'HasImage'    => (int) $r->has_image,
                    'HasHeraldry' => (int) $r->has_heraldry,
                ];
            }
        }
        return ['Status' => 0, 'Friends' => $out];
    }

    /** Count accepted friends of $userId. */
    public function CountFriends($userId)
    {
        $userId = (int) $userId;
        if ($userId <= 0) {
            return 0;
        }
        $this->db->Clear();
        $r = $this->db->query(
            'SELECT COUNT(*) AS n FROM ' . DB_PREFIX . 'friendship'
            . " WHERE status = 'accepted' AND (mundane_lo = {$userId} OR mundane_hi = {$userId})"
        );
        if ($r !== false && $r->next()) {
            return (int) $r->n;
        }
        return 0;
    }

    /**
     * Incoming pending requests for $userId (someone else requested them).
     * @return array ['Status'=>0, 'Requests'=>[ {MundaneId,Persona,ParkAbbr,KingdomAbbr,HasImage,RequestedAt} ]]
     */
    public function GetPendingIncoming($userId)
    {
        $userId = (int) $userId;
        if ($userId <= 0) {
            return ['Status' => 0, 'Requests' => []];
        }
        $this->db->Clear();
        $r = $this->db->query(
            'SELECT f.requested_by AS mundane_id, f.requested_at,'
            . ' m.persona, m.has_image, m.has_heraldry,'
            . ' p.abbreviation AS park_abbr, k.abbreviation AS kingdom_abbr'
            . ' FROM ' . DB_PREFIX . 'friendship f'
            . ' JOIN ' . DB_PREFIX . 'mundane m ON m.mundane_id = f.requested_by'
            . ' LEFT JOIN ' . DB_PREFIX . 'park p ON p.park_id = m.park_id'
            . ' LEFT JOIN ' . DB_PREFIX . 'kingdom k ON k.kingdom_id = m.kingdom_id'
            . " WHERE f.status = 'pending' AND f.requested_by <> {$userId}"
            . " AND (f.mundane_lo = {$userId} OR f.mundane_hi = {$userId})"
            . ' ORDER BY f.requested_at DESC'
        );
        $out = [];
        if ($r !== false) {
            while ($r->next()) {
                $out[] = [
                    'MundaneId'   => (int) $r->mundane_id,
                    'Persona'     => (string) $r->persona,
                    'ParkAbbr'    => (string) $r->park_abbr,
                    'KingdomAbbr' => (string) $r->kingdom_abbr,
                    'HasImage'    => (int) $r->has_image,
                    'HasHeraldry' => (int) $r->has_heraldry,
                    'RequestedAt' => (string) $r->requested_at,
                ];
            }
        }
        return ['Status' => 0, 'Requests' => $out];
    }

    /** Best-effort: notify $toId that $fromId sent a request. Swallows failure. */
    private function notifyRequest($fromId, $toId)
    {
        try {
            if (!isset(Ork3::$Lib->notification)) {
                return;
            }
            $persona = $this->persona($fromId);
            $who = $persona !== '' ? $persona : 'Someone';
            Ork3::$Lib->notification->Create((int) $toId, 'friend_request', [
                'title'      => $who . ' sent you a friend request',
                'body'       => 'Visit your Friends page to accept or decline.',
                'link_url'   => '?Route=Friend/index',
                'payload'    => json_encode(['from' => (int) $fromId]),
                'created_by' => (int) $fromId,
            ]);
        } catch (\Throwable $e) {
            // Swallow — notifications never break the relationship write.
        }
    }

    /** Best-effort: notify $otherId that $userId accepted their request. */
    private function notifyAccept($userId, $otherId)
    {
        try {
            if (!isset(Ork3::$Lib->notification)) {
                return;
            }
            $persona = $this->persona($userId);
            $who = $persona !== '' ? $persona : 'Someone';
            Ork3::$Lib->notification->Create((int) $otherId, 'friend_accept', [
                'title'      => $who . ' accepted your friend request',
                'body'       => 'You are now friends on the ORK.',
                'link_url'   => '?Route=Player/profile/' . (int) $userId,
                'payload'    => json_encode(['from' => (int) $userId]),
                'created_by' => (int) $userId,
            ]);
        } catch (\Throwable $e) {
            // Swallow.
        }
    }
}
```

- [ ] **Step 2: Lint**

Run: `php -l system/lib/ork3/class.Friendship.php`
Expected: `No syntax errors detected`

- [ ] **Step 3: Confirm auto-registration**

The startup scan registers `Ork3::$Lib->friendship`. Verify with a quick probe:
```bash
docker exec ork3-php8-app php -r 'require "/var/www/ork.amtgard.com/system/startup.php";
 var_dump(isset(Ork3::$Lib->friendship));'
```
Expected: `bool(true)`. (If the bootstrap path/usage differs, instead verify via the curl test in Task 5 once the controller exists.)

- [ ] **Step 4: Commit**

```bash
git add system/lib/ork3/class.Friendship.php
git commit -m "Friends: relationship lib (request/accept/block + reads)"
```

> NOTE for executor: verify `ork_park.abbreviation` / `ork_kingdom.abbreviation`
> column names against `ork.sql` before relying on the join aliases above; if the
> abbreviation column has a different name, adjust the SELECTs (the recon used
> `KingdomAbbr`/`ParkAbbr` shapes from `Model_Event::get_rsvp_list`, so the
> columns exist — confirm exact names).

---

## Task 4: Pass-through model — `model.Friendship.php`

**Files:**
- Create: `orkui/model/model.Friendship.php`

- [ ] **Step 1: Write the model**

```php
<?php

/**
 * Model_Friendship — thin pass-through to Ork3::$Lib->friendship.
 * No DB/SQL here; forwards to the lib (single source of $DB access).
 * Design: docs/superpowers/specs/2026-06-20-friends-system-design.md
 */
class Model_Friendship extends Model
{
    function __construct()
    {
        parent::__construct();
        $this->Friendship = new APIModel('Friendship');
    }

    function request($fromId, $toId)        { return $this->Friendship->Request($fromId, $toId); }
    function accept($userId, $otherId)      { return $this->Friendship->Accept($userId, $otherId); }
    function decline($userId, $otherId)     { return $this->Friendship->Decline($userId, $otherId); }
    function cancel($userId, $otherId)      { return $this->Friendship->Cancel($userId, $otherId); }
    function unfriend($userId, $otherId)    { return $this->Friendship->Unfriend($userId, $otherId); }
    function block($userId, $targetId)      { return $this->Friendship->Block($userId, $targetId); }
    function unblock($userId, $targetId)    { return $this->Friendship->Unblock($userId, $targetId); }
    function get_status($userId, $otherId)  { return $this->Friendship->GetStatus($userId, $otherId); }
    function are_friends($a, $b)            { return $this->Friendship->AreFriends($a, $b); }
    function get_friend_ids($userId)        { return $this->Friendship->GetFriendIds($userId); }
    function get_friends($userId, $limit = null, $offset = 0) { return $this->Friendship->GetFriends($userId, $limit, $offset); }
    function count_friends($userId)         { return $this->Friendship->CountFriends($userId); }
    function get_pending_incoming($userId)  { return $this->Friendship->GetPendingIncoming($userId); }
}
```

- [ ] **Step 2: Lint**

Run: `php -l orkui/model/model.Friendship.php`
Expected: `No syntax errors detected`

- [ ] **Step 3: Commit**

```bash
git add orkui/model/model.Friendship.php
git commit -m "Friends: pass-through model"
```

---

## Task 5: AJAX controller — `controller.FriendAjax.php` + skip-token registration

**Files:**
- Create: `orkui/controller/controller.FriendAjax.php`
- Modify: `system/lib/system/class.Controller.php` (the `$_skipTokenCheck` array, ~line 40-51)

- [ ] **Step 1: Register the controller in `$_skipTokenCheck`**

In `system/lib/system/class.Controller.php`, add `'Controller_FriendAjax',`
to the array immediately after `'Controller_NotificationAjax',`:
```php
            'Controller_NotificationAjax',
            'Controller_FriendAjax',
        ]);
```

- [ ] **Step 2: Write the AJAX controller** (note `list`/`pending`/`feed` deferred to later tasks; create the action-mutation + status surface now)

```php
<?php

/**
 * Controller_FriendAjax — JSON AJAX surface for the friend graph.
 *
 * Routes: index.php?Route=FriendAjax/{action}
 *   request/accept/decline/cancel/unfriend/block/unblock → relationship mutations
 *   status  → relationship state for one target (drives button re-render)
 *   list    → a user's friends (FRIENDS-ONLY visibility gate)
 *   pending → your incoming requests
 *   feed    → friends' activity feed (awards + RSVPs)
 *
 * All actions scoped to $this->session->user_id. Registered in $_skipTokenCheck
 * (class.Controller.php). Response: {status:0,...} | {status:1,error:"..."}.
 * Design: docs/superpowers/specs/2026-06-20-friends-system-design.md
 */
class Controller_FriendAjax extends Controller
{
    /** Shared JSON + auth preamble. Returns int user_id, or null (already responded). */
    private function guard()
    {
        header('Content-Type: application/json');
        if (!isset($this->session->user_id) || (int) $this->session->user_id <= 0) {
            echo json_encode(['status' => 1, 'error' => 'Not logged in']);
            exit;
        }
        return (int) $this->session->user_id;
    }

    /** Read the target/other mundane id from POST/GET. */
    private function targetId()
    {
        return (int) ($_POST['target'] ?? $_GET['target'] ?? $_POST['id'] ?? $_GET['id'] ?? 0);
    }

    /** Map a lib status tuple to the JSON response and exit. */
    private function respond(array $res)
    {
        if ((int) ($res['Status'] ?? 1) !== 0) {
            echo json_encode(['status' => 1, 'error' => ($res['Error'] ?? 'Action failed')]);
            exit;
        }
        echo json_encode(['status' => 0]);
        exit;
    }

    public function request()
    {
        $uid = $this->guard();
        $this->load_model('Friendship');
        $this->respond($this->Friendship->request($uid, $this->targetId()));
    }

    public function accept()
    {
        $uid = $this->guard();
        $this->load_model('Friendship');
        $this->respond($this->Friendship->accept($uid, $this->targetId()));
    }

    public function decline()
    {
        $uid = $this->guard();
        $this->load_model('Friendship');
        $this->respond($this->Friendship->decline($uid, $this->targetId()));
    }

    public function cancel()
    {
        $uid = $this->guard();
        $this->load_model('Friendship');
        $this->respond($this->Friendship->cancel($uid, $this->targetId()));
    }

    public function unfriend()
    {
        $uid = $this->guard();
        $this->load_model('Friendship');
        $this->respond($this->Friendship->unfriend($uid, $this->targetId()));
    }

    public function block()
    {
        $uid = $this->guard();
        $this->load_model('Friendship');
        $this->respond($this->Friendship->block($uid, $this->targetId()));
    }

    public function unblock()
    {
        $uid = $this->guard();
        $this->load_model('Friendship');
        $this->respond($this->Friendship->unblock($uid, $this->targetId()));
    }

    /** GET FriendAjax/status&target=N → {status:0, state, blocked_by_me} */
    public function status()
    {
        $uid = $this->guard();
        $this->load_model('Friendship');
        $res = $this->Friendship->get_status($uid, $this->targetId());
        echo json_encode([
            'status'        => 0,
            'state'         => $res['State'] ?? 'none',
            'blocked_by_me' => (bool) ($res['BlockedByMe'] ?? false),
        ]);
        exit;
    }
}
```

- [ ] **Step 3: Lint both files**

Run: `php -l orkui/controller/controller.FriendAjax.php && php -l system/lib/system/class.Controller.php`
Expected: `No syntax errors detected` for both.

- [ ] **Step 4: Curl-verify the full lifecycle** (two users — use two known local usernames; user A's mundane_id = `$A`, user B = `$B`)

Run the curl-auth block (login as A, request B; login as B, status A should be `pending_in`, accept; status both `friends`; unfriend; block):
```bash
JAR=/tmp/cjA.txt; BASE=http://localhost:19080/orkui/index.php; rm -f "$JAR"
curl -s -c "$JAR" -b "$JAR" "$BASE?Route=Login/login" --data-urlencode 'username=<A>' --data-urlencode 'password=x' >/dev/null
echo "A requests B:"; curl -s -c "$JAR" -b "$JAR" "$BASE?Route=FriendAjax/request" --data "target=<B_id>"
echo; echo "A status of B (expect pending_out):"; curl -s -c "$JAR" -b "$JAR" "$BASE?Route=FriendAjax/status&target=<B_id>"

JARB=/tmp/cjB.txt; rm -f "$JARB"
curl -s -c "$JARB" -b "$JARB" "$BASE?Route=Login/login" --data-urlencode 'username=<B>' --data-urlencode 'password=x' >/dev/null
echo; echo "B status of A (expect pending_in):"; curl -s -c "$JARB" -b "$JARB" "$BASE?Route=FriendAjax/status&target=<A_id>"
echo; echo "B accepts A:"; curl -s -c "$JARB" -b "$JARB" "$BASE?Route=FriendAjax/accept" --data "target=<A_id>"
echo; echo "B status of A (expect friends):"; curl -s -c "$JARB" -b "$JARB" "$BASE?Route=FriendAjax/status&target=<A_id>"
```
Expected JSON: request `{"status":0}`, A→B `pending_out`, B→A `pending_in`, accept `{"status":0}`, then `friends`. Confirm a `friend_request` row landed for B and `friend_accept` for A:
```bash
docker exec ork3-php8-app sh -c 'mysql -h db -uork -pork ork -e "SELECT mundane_id,type,title FROM ork_notification WHERE type LIKE \"friend%\" ORDER BY notification_id DESC LIMIT 4;"'
```

- [ ] **Step 5: Commit**

```bash
git add orkui/controller/controller.FriendAjax.php system/lib/system/class.Controller.php
git commit -m "Friends: AJAX controller (mutations + status) + skip-token registration"
```

---

## Task 6: `list` + `pending` AJAX (friends-only gate)

**Files:**
- Modify: `orkui/controller/controller.FriendAjax.php`

- [ ] **Step 1: Add `list` and `pending` actions** (append inside the class, before the closing brace)

```php
    /**
     * GET FriendAjax/list&owner=N → {status:0, friends:[...]}
     * FRIENDS-ONLY gate: only the owner, or a confirmed friend of the owner, may
     * see the list. Everyone else gets an empty, unrevealing response.
     */
    public function list()
    {
        $uid = $this->guard();
        $owner = (int) ($_GET['owner'] ?? $_POST['owner'] ?? $uid);
        if ($owner <= 0) {
            $owner = $uid;
        }
        $this->load_model('Friendship');

        $allowed = ($owner === $uid) || $this->Friendship->are_friends($uid, $owner);
        if (!$allowed) {
            // Hide both list and count from non-friends.
            echo json_encode(['status' => 0, 'friends' => [], 'visible' => false]);
            exit;
        }

        $res = $this->Friendship->get_friends($owner);
        echo json_encode(['status' => 0, 'visible' => true, 'friends' => ($res['Friends'] ?? [])]);
        exit;
    }

    /** GET FriendAjax/pending → {status:0, requests:[...]} (your incoming requests) */
    public function pending()
    {
        $uid = $this->guard();
        $this->load_model('Friendship');
        $res = $this->Friendship->get_pending_incoming($uid);
        echo json_encode(['status' => 0, 'requests' => ($res['Requests'] ?? [])]);
        exit;
    }
```

- [ ] **Step 2: Lint**

Run: `php -l orkui/controller/controller.FriendAjax.php`
Expected: `No syntax errors detected`

- [ ] **Step 3: Curl-verify the friends-only gate** (using the friended A/B from Task 5, and a third unrelated user C)

```bash
# B (friend of A) can see A's list; C (not a friend) gets visible:false, empty.
echo "B lists A (expect visible:true with B in it):"
curl -s -c "$JARB" -b "$JARB" "$BASE?Route=FriendAjax/list&owner=<A_id>"
JARC=/tmp/cjC.txt; rm -f "$JARC"
curl -s -c "$JARC" -b "$JARC" "$BASE?Route=Login/login" --data-urlencode 'username=<C>' --data-urlencode 'password=x' >/dev/null
echo; echo "C lists A (expect visible:false, empty):"
curl -s -c "$JARC" -b "$JARC" "$BASE?Route=FriendAjax/list&owner=<A_id>"
```
Expected: B sees `visible:true` and a non-empty `friends`; C sees `{"status":0,"visible":false,"friends":[]}`.

- [ ] **Step 4: Commit**

```bash
git add orkui/controller/controller.FriendAjax.php
git commit -m "Friends: list (friends-only gate) + pending AJAX"
```

---

## Task 7: Profile friend button — controller wiring

**Files:**
- Modify: `orkui/controller/controller.Player.php` (the `profile($id)` method, ~line 279-367)

- [ ] **Step 1: Compute friend state in `profile()`** — after the existing `$uid` is read (~line 297), add:

```php
        // ---- Friends: button state + friends-section visibility ----------
        $this->data['FriendState']   = 'none';   // none|pending_out|pending_in|friends
        $this->data['FriendBlocked'] = false;
        $this->data['FriendsVisible'] = false;    // can the viewer see this profile's friends list?
        $this->data['FriendCount']    = 0;
        if ($uid > 0) {
            $this->load_model('Friendship');
            if ($uid !== (int) $id) {
                $st = $this->Friendship->get_status($uid, (int) $id);
                $this->data['FriendState']   = $st['State'] ?? 'none';
                $this->data['FriendBlocked'] = (bool) ($st['BlockedByMe'] ?? false);
            }
            $this->data['FriendsVisible'] = ($uid === (int) $id)
                || $this->Friendship->are_friends($uid, (int) $id);
            if ($this->data['FriendsVisible']) {
                $this->data['FriendCount'] = $this->Friendship->count_friends((int) $id);
            }
        }
```

> Executor: confirm the exact insertion point — `profile()` starts ~line 279,
> `$uid` is set ~line 297, `$this->data['LoggedIn']` ~line 367. Place this block
> after `$uid` exists and before the template render. Use `load_model('Friendship')`
> exactly once.

- [ ] **Step 2: Lint** (normalize-first if tab-indented)

Run: `awk '/^\t/{c++} END{print c+0}' orkui/controller/controller.Player.php`
If non-zero: `php tools/php-cs-fixer.phar fix --config=.php-cs-fixer.dist.php orkui/controller/controller.Player.php` first.
Then: `php -l orkui/controller/controller.Player.php` → `No syntax errors detected`.

- [ ] **Step 3: Verify the profile page still renders** (no fatal)

```bash
curl -s -c "$JAR" -b "$JAR" "$BASE?Route=Player/profile/<B_id>" -o /dev/null -w "%{http_code}\n"
```
Expected: `200`. Check `docker logs ork3-php8-app` shows no new errors.

- [ ] **Step 4: Commit**

```bash
git add orkui/controller/controller.Player.php
git commit -m "Friends: profile controller passes friend state + visibility"
```

---

## Task 8: Profile friend button + friends section — template

**Files:**
- Modify: `orkui/template/revised-frontend/Playernew_index.tpl`

> Reminder: `.tpl` is PLAIN PHP (`<?php ?>` / `<?= ?>`), NOT Smarty. Variables from
> the controller's `$this->data` are `extract()`ed, so `$FriendState`, `$Player`,
> `$LoggedIn`, `$uid` etc. are available as locals. Verify available var names by
> reading the top of the existing template before editing.

- [ ] **Step 1: Add the friend button to the profile header** — locate the header/persona action area (next to existing profile-header buttons) and insert (gate on logged-in and not-self; the viewed id is the profile's mundane id — confirm its local var name, e.g. `$Player['MundaneId']` or `$id`):

```php
<?php
// Friend button — only for logged-in viewers looking at someone else's profile.
$__viewedId = (int)($Player['MundaneId'] ?? 0);
$__loggedIn = !empty($LoggedIn) && !empty($uid);
if ($__loggedIn && (int)$uid !== $__viewedId && $__viewedId > 0):
    $__state = $FriendState ?? 'none';
    $__blocked = !empty($FriendBlocked);
?>
  <div class="friend-btn-wrap" id="friendBtnWrap" data-target="<?= $__viewedId ?>" data-state="<?= htmlspecialchars($__blocked ? 'blocked' : $__state) ?>">
    <?php // The actual button markup is rendered/managed by friendRenderButton() in revised.js ?>
  </div>
<?php endif; ?>
```

- [ ] **Step 2: Add the friends section** — alongside the existing Units/Awards tabs/panels, gated on `$FriendsVisible`:

```php
<?php if (!empty($FriendsVisible)): ?>
  <section class="profile-friends" id="profileFriends" data-owner="<?= (int)($Player['MundaneId'] ?? 0) ?>">
    <h3 class="profile-friends-h">Friends<?= isset($FriendCount) ? ' (' . (int)$FriendCount . ')' : '' ?></h3>
    <div class="profile-friends-list" id="profileFriendsList">
      <span class="muted">Loading…</span>
    </div>
  </section>
<?php endif; ?>
```
(The list is lazy-filled by `friendLoadProfileList()` in revised.js via `FriendAjax/list`.)

- [ ] **Step 3: Verify render** (logged-in, viewing another player)

```bash
curl -s -c "$JAR" -b "$JAR" "$BASE?Route=Player/profile/<B_id>" | grep -c 'friendBtnWrap'
```
Expected: `1`. For a non-friend's profile, confirm the friends section is absent:
```bash
curl -s -c "$JARC" -b "$JARC" "$BASE?Route=Player/profile/<A_id>" | grep -c 'profileFriends'
```
Expected: `0` (C is not A's friend → hide both).

- [ ] **Step 4: Commit**

```bash
git add orkui/template/revised-frontend/Playernew_index.tpl
git commit -m "Friends: profile friend button + friends section markup"
```

---

## Task 9: Friend button + profile-list JS

**Files:**
- Modify: `orkui/template/revised-frontend/script/revised.js`

> Reminder: revised.js loads mid-page (external `<script src>`). NEVER guard an
> IIFE on `document.getElementById(...)` — modal/section HTML defined after the
> script tag isn't in the DOM yet. Use a config flag or defer to event delegation /
> `DOMContentLoaded`. Use `tnConfirm()` for unfriend/block — never native confirm().

- [ ] **Step 1: Add the friend button module** (append a new IIFE section, using event delegation so it works regardless of load order)

```javascript
/* ===== Friends: profile button + friends list ===== */
(function () {
  function postFriend(action, target) {
    return fetch('index.php?Route=FriendAjax/' + action, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: 'target=' + encodeURIComponent(target),
      credentials: 'same-origin'
    }).then(function (r) { return r.json(); });
  }

  // Renders the button(s) inside #friendBtnWrap from a state string.
  function friendRenderButton(wrap) {
    var target = wrap.getAttribute('data-target');
    var state = wrap.getAttribute('data-state');
    var html = '';
    if (state === 'blocked') {
      html = '<button class="btn friend-action" data-act="unblock" data-target="' + target + '">Blocked &mdash; Unblock</button>';
    } else if (state === 'friends') {
      html = '<div class="friend-menu"><button class="btn friend-toggle">Friends ▾</button>' +
             '<div class="friend-menu-pop"><button class="friend-action" data-act="unfriend" data-target="' + target + '">Unfriend</button>' +
             '<button class="friend-action" data-act="block" data-target="' + target + '">Block</button></div></div>';
    } else if (state === 'pending_out') {
      html = '<button class="btn friend-action" data-act="cancel" data-target="' + target + '">Request Pending</button>';
    } else if (state === 'pending_in') {
      html = '<button class="btn btn-primary friend-action" data-act="accept" data-target="' + target + '">Accept</button>' +
             '<button class="btn friend-action" data-act="decline" data-target="' + target + '">Decline</button>';
    } else {
      html = '<button class="btn btn-primary friend-action" data-act="request" data-target="' + target + '">Add Friend</button>';
    }
    wrap.innerHTML = html;
  }

  function refreshState(wrap, target) {
    fetch('index.php?Route=FriendAjax/status&target=' + encodeURIComponent(target), { credentials: 'same-origin' })
      .then(function (r) { return r.json(); })
      .then(function (d) {
        wrap.setAttribute('data-state', d.blocked_by_me ? 'blocked' : (d.state || 'none'));
        friendRenderButton(wrap);
      });
  }

  function doAction(act, target, wrap) {
    postFriend(act, target).then(function (d) {
      if (d && d.status === 0) {
        refreshState(wrap, target);
      } else if (d && d.error) {
        if (window.tnToast) { window.tnToast(d.error); } // fall back silently if no toast
      }
    });
  }

  // Delegated click handler — survives mid-page script load.
  document.addEventListener('click', function (e) {
    var btn = e.target.closest ? e.target.closest('.friend-action') : null;
    if (!btn) { return; }
    var wrap = btn.closest('#friendBtnWrap') || btn.closest('.friend-btn-wrap');
    var act = btn.getAttribute('data-act');
    var target = btn.getAttribute('data-target');
    if (!act || !target) { return; }

    if (act === 'unfriend' || act === 'block') {
      var label = act === 'unfriend' ? 'Remove this friend?' : 'Block this person from sending you requests?';
      if (window.tnConfirm) {
        window.tnConfirm({
          title: act === 'unfriend' ? 'Unfriend' : 'Block',
          body: label,
          confirmLabel: act === 'unfriend' ? 'Unfriend' : 'Block',
          danger: true,
          onConfirm: function () { if (wrap) { doAction(act, target, wrap); } }
        });
      } else {
        if (wrap) { doAction(act, target, wrap); }
      }
      return;
    }
    if (wrap) { doAction(act, target, wrap); }
  });

  // Initial render of any friend button on the page.
  function initFriendButtons() {
    var wraps = document.querySelectorAll('.friend-btn-wrap, #friendBtnWrap');
    for (var i = 0; i < wraps.length; i++) { friendRenderButton(wraps[i]); }
    // Lazy-load the profile friends list, if present.
    var sec = document.getElementById('profileFriends');
    if (sec) { friendLoadProfileList(sec); }
  }

  function friendLoadProfileList(sec) {
    var owner = sec.getAttribute('data-owner');
    var list = document.getElementById('profileFriendsList');
    if (!list) { return; }
    fetch('index.php?Route=FriendAjax/list&owner=' + encodeURIComponent(owner), { credentials: 'same-origin' })
      .then(function (r) { return r.json(); })
      .then(function (d) {
        if (!d || !d.friends || !d.friends.length) {
          list.innerHTML = '<span class="muted">No friends yet.</span>';
          return;
        }
        var h = '';
        d.friends.forEach(function (f) {
          h += '<a class="friend-chip" href="index.php?Route=Player/profile/' + f.MundaneId + '">' +
               (f.Persona ? f.Persona.replace(/[<>&]/g, '') : 'Unknown') +
               (f.KingdomAbbr ? ' <span class="friend-chip-sub">' + f.KingdomAbbr + '</span>' : '') + '</a>';
        });
        list.innerHTML = h;
      });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initFriendButtons);
  } else {
    initFriendButtons();
  }
})();
```

- [ ] **Step 2: Verify in the browser** (Claude-in-Chrome, after implementation — per project rule, Chrome is for post-implementation verification only)

Log in, open another player's profile. Expected: "Add Friend" button renders. Click → becomes "Request Pending". On the other account, the button shows Accept/Decline. Walk the menu in dark mode (next task adds styles).

- [ ] **Step 3: Commit**

```bash
git add orkui/template/revised-frontend/script/revised.js
git commit -m "Friends: profile button + friends-list JS (delegated, tnConfirm)"
```

---

## Task 10: Friend UI styles (dark-mode aware)

**Files:**
- Modify: `orkui/template/default/style/orkui.css`

> Dark mode selector is `html[data-theme="dark"]` (NOT body.dark-mode). Any heading
> inside a card/section must reset the global h1–h6 gray-box style.

- [ ] **Step 1: Append friend styles**

```css
/* ===== Friends ===== */
.friend-btn-wrap { display: inline-block; }
.friend-menu { position: relative; display: inline-block; }
.friend-menu-pop {
  display: none; position: absolute; right: 0; top: 100%; z-index: 50;
  background: #fff; border: 1px solid #ccc; border-radius: 6px; min-width: 140px;
  box-shadow: 0 4px 14px rgba(0,0,0,.15);
}
.friend-menu:hover .friend-menu-pop, .friend-menu.open .friend-menu-pop { display: block; }
.friend-menu-pop .friend-action {
  display: block; width: 100%; text-align: left; padding: 8px 12px;
  background: none; border: none; cursor: pointer; color: #222;
}
.friend-menu-pop .friend-action:hover { background: #f2f2f2; }

.profile-friends { margin-top: 1rem; }
.profile-friends-h {
  background: transparent; border: none; padding: 0; border-radius: 0;
  text-shadow: none; font-size: 1.1rem; margin: 0 0 .5rem;
}
.profile-friends-list { display: flex; flex-wrap: wrap; gap: .5rem; }
.friend-chip {
  display: inline-flex; align-items: center; gap: .35rem;
  padding: .3rem .6rem; border: 1px solid #ddd; border-radius: 999px;
  background: #fafafa; text-decoration: none; color: #222; font-size: .9rem;
}
.friend-chip:hover { background: #f0f0f0; }
.friend-chip-sub { color: #888; font-size: .8rem; }

/* Dark mode */
html[data-theme="dark"] .friend-menu-pop { background: #2a2a2a; border-color: #444; }
html[data-theme="dark"] .friend-menu-pop .friend-action { color: #eee; }
html[data-theme="dark"] .friend-menu-pop .friend-action:hover { background: #383838; }
html[data-theme="dark"] .friend-chip { background: #2a2a2a; border-color: #444; color: #eee; }
html[data-theme="dark"] .friend-chip:hover { background: #353535; }
html[data-theme="dark"] .friend-chip-sub { color: #aaa; }
```

- [ ] **Step 2: Verify dark + light** (Claude-in-Chrome): the button, the Friends ▾ menu, and friend chips render correctly in both themes; no gray box on the section heading.

- [ ] **Step 3: Commit**

```bash
git add orkui/template/default/style/orkui.css
git commit -m "Friends: profile button + chip styles (dark-mode aware)"
```

---

## Task 11: My Friends hub — controller + template

**Files:**
- Create: `orkui/controller/controller.Friend.php`
- Create: `orkui/template/revised-frontend/Friendnew_index.tpl`

- [ ] **Step 1: Write the hub controller**

```php
<?php

/**
 * Controller_Friend — "My Friends" hub (logged-in only).
 * Renders Friendnew_index.tpl with three tabs: Friends / Requests / Activity Feed.
 * First tab data is loaded server-side; tab switches + paging use FriendAjax.
 * Design: docs/superpowers/specs/2026-06-20-friends-system-design.md
 */
class Controller_Friend extends Controller
{
    public function index()
    {
        $uid = isset($this->session->user_id) ? (int) $this->session->user_id : 0;
        if ($uid <= 0) {
            // Not logged in → bounce to login (match app convention for gated pages).
            header('Location: index.php?Route=Login');
            exit;
        }

        $this->load_model('Friendship');
        $friends = $this->Friendship->get_friends($uid);
        $pending = $this->Friendship->get_pending_incoming($uid);

        $this->data['Friends']      = $friends['Friends'] ?? [];
        $this->data['Requests']     = $pending['Requests'] ?? [];
        $this->data['FriendCount']  = $this->Friendship->count_friends($uid);
        $this->data['RequestCount'] = count($this->data['Requests']);
        $this->data['Uid']          = $uid;

        $this->template = '../revised-frontend/Friendnew_index.tpl';
    }
}
```

> Executor: confirm the gated-page redirect + `$this->template` assignment match
> the pattern in `controller.Player.php::profile()` (it sets
> `$this->template = '../revised-frontend/Playernew_index.tpl';`). Mirror exactly.

- [ ] **Step 2: Write the hub template** (plain PHP; tabs + lazy feed)

```php
<?php /* My Friends hub — plain PHP template. Vars: $Friends, $Requests, $FriendCount, $RequestCount, $Uid */ ?>
<div class="friends-hub">
  <h1 class="friends-hub-h">My Friends</h1>

  <div class="friends-tabs" role="tablist">
    <button class="friends-tab active" data-tab="friends">Friends (<?= (int)$FriendCount ?>)</button>
    <button class="friends-tab" data-tab="requests">Requests<?= $RequestCount > 0 ? ' (' . (int)$RequestCount . ')' : '' ?></button>
    <button class="friends-tab" data-tab="feed">Activity</button>
  </div>

  <div class="friends-panel" id="tab-friends">
    <?php if (empty($Friends)): ?>
      <p class="muted">You haven't added any friends yet. Visit a player's profile to send a request.</p>
    <?php else: ?>
      <div class="friends-grid">
        <?php foreach ($Friends as $f): ?>
          <div class="friend-card">
            <a class="friend-card-name" href="index.php?Route=Player/profile/<?= (int)$f['MundaneId'] ?>"><?= htmlspecialchars($f['Persona']) ?></a>
            <span class="friend-card-sub"><?= htmlspecialchars(trim(($f['ParkAbbr'] ?? '') . ' ' . ($f['KingdomAbbr'] ?? ''))) ?></span>
            <button class="btn friend-recommend" data-target="<?= (int)$f['MundaneId'] ?>" data-name="<?= htmlspecialchars($f['Persona']) ?>">Recommend</button>
          </div>
        <?php endforeach; ?>
      </div>
    <?php endif; ?>
  </div>

  <div class="friends-panel" id="tab-requests" hidden>
    <?php if (empty($Requests)): ?>
      <p class="muted">No pending friend requests.</p>
    <?php else: ?>
      <div class="friends-grid">
        <?php foreach ($Requests as $r): ?>
          <div class="friend-card" data-target="<?= (int)$r['MundaneId'] ?>">
            <a class="friend-card-name" href="index.php?Route=Player/profile/<?= (int)$r['MundaneId'] ?>"><?= htmlspecialchars($r['Persona']) ?></a>
            <span class="friend-card-sub"><?= htmlspecialchars(trim(($r['ParkAbbr'] ?? '') . ' ' . ($r['KingdomAbbr'] ?? ''))) ?></span>
            <div class="friend-card-actions">
              <button class="btn btn-primary friend-action" data-act="accept" data-target="<?= (int)$r['MundaneId'] ?>">Accept</button>
              <button class="btn friend-action" data-act="decline" data-target="<?= (int)$r['MundaneId'] ?>">Decline</button>
            </div>
          </div>
        <?php endforeach; ?>
      </div>
    <?php endif; ?>
  </div>

  <div class="friends-panel" id="tab-feed" hidden>
    <div id="friendsFeed"><span class="muted">Loading activity…</span></div>
  </div>
</div>
```

- [ ] **Step 3: Lint controller + verify the page loads**

Run: `php -l orkui/controller/controller.Friend.php`
Then: `curl -s -c "$JAR" -b "$JAR" "$BASE?Route=Friend/index" -o /dev/null -w "%{http_code}\n"` → `200`.

- [ ] **Step 4: Commit**

```bash
git add orkui/controller/controller.Friend.php orkui/template/revised-frontend/Friendnew_index.tpl
git commit -m "Friends: My Friends hub (controller + tabs template)"
```

---

## Task 12: Hub JS (tabs + requests) and styles

**Files:**
- Modify: `orkui/template/revised-frontend/script/revised.js`
- Modify: `orkui/template/default/style/orkui.css`

- [ ] **Step 1: Add hub tab JS** (append a new IIFE; reuses the delegated `.friend-action` handler from Task 9 for Accept/Decline)

```javascript
/* ===== Friends hub: tabs + lazy feed ===== */
(function () {
  function initHub() {
    var hub = document.querySelector('.friends-hub');
    if (!hub) { return; }
    var tabs = hub.querySelectorAll('.friends-tab');
    var feedLoaded = false;
    for (var i = 0; i < tabs.length; i++) {
      tabs[i].addEventListener('click', function () {
        var name = this.getAttribute('data-tab');
        tabs.forEach ? tabs.forEach(clear) : Array.prototype.forEach.call(tabs, clear);
        this.classList.add('active');
        ['friends', 'requests', 'feed'].forEach(function (n) {
          var p = document.getElementById('tab-' + n);
          if (p) { p.hidden = (n !== name); }
        });
        if (name === 'feed' && !feedLoaded) { feedLoaded = true; loadFeed(); }
      });
    }
    function clear(t) { t.classList.remove('active'); }
  }

  function loadFeed() {
    var box = document.getElementById('friendsFeed');
    if (!box) { return; }
    fetch('index.php?Route=FriendAjax/feed', { credentials: 'same-origin' })
      .then(function (r) { return r.json(); })
      .then(function (d) {
        if (!d || !d.items || !d.items.length) {
          box.innerHTML = '<span class="muted">No recent friend activity.</span>';
          return;
        }
        var h = '';
        d.items.forEach(function (it) {
          h += '<div class="feed-item"><i class="' + (it.icon || 'fas fa-bell') + '"></i>' +
               '<span class="feed-text">' + (it.text || '').replace(/[<>]/g, '') + '</span>' +
               '<span class="feed-ago">' + (it.ago || '') + '</span></div>';
        });
        box.innerHTML = h;
      });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initHub);
  } else {
    initHub();
  }
})();
```

- [ ] **Step 2: Append hub styles** (dark-mode aware)

```css
/* ===== Friends hub ===== */
.friends-hub { max-width: 900px; margin: 1rem auto; }
.friends-hub-h { background: transparent; border: none; padding: 0; border-radius: 0; text-shadow: none; }
.friends-tabs { display: flex; gap: .25rem; border-bottom: 1px solid #ddd; margin-bottom: 1rem; }
.friends-tab { background: none; border: none; padding: .6rem 1rem; cursor: pointer; color: #555; border-bottom: 2px solid transparent; }
.friends-tab.active { color: #222; border-bottom-color: #555; font-weight: 600; }
.friends-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)); gap: .75rem; }
.friend-card { border: 1px solid #ddd; border-radius: 8px; padding: .75rem; display: flex; flex-direction: column; gap: .35rem; }
.friend-card-name { font-weight: 600; text-decoration: none; color: #222; }
.friend-card-sub { color: #888; font-size: .85rem; }
.friend-card-actions { display: flex; gap: .4rem; margin-top: .25rem; }
.feed-item { display: flex; align-items: center; gap: .6rem; padding: .5rem 0; border-bottom: 1px solid #eee; }
.feed-text { flex: 1; }
.feed-ago { color: #999; font-size: .8rem; }

html[data-theme="dark"] .friends-tabs { border-bottom-color: #444; }
html[data-theme="dark"] .friends-tab { color: #aaa; }
html[data-theme="dark"] .friends-tab.active { color: #eee; border-bottom-color: #888; }
html[data-theme="dark"] .friend-card { border-color: #444; }
html[data-theme="dark"] .friend-card-name { color: #eee; }
html[data-theme="dark"] .friend-card-sub { color: #aaa; }
html[data-theme="dark"] .feed-item { border-bottom-color: #383838; }
```

- [ ] **Step 3: Verify** (Claude-in-Chrome): `Friend/index` shows three tabs; switching to Requests shows incoming requests with Accept/Decline (delegated handler from Task 9 fires); Activity lazy-loads (will be empty until Task 13). Dark-mode walk.

- [ ] **Step 4: Commit**

```bash
git add orkui/template/revised-frontend/script/revised.js orkui/template/default/style/orkui.css
git commit -m "Friends: hub tabs JS + styles (dark-mode aware)"
```

---

## Task 13: Activity feed — lib query + AJAX

**Files:**
- Modify: `system/lib/ork3/class.Friendship.php` (add `GetActivityFeed`)
- Modify: `orkui/model/model.Friendship.php` (add pass-through)
- Modify: `orkui/controller/controller.FriendAjax.php` (add `feed` action)

- [ ] **Step 1: Add `GetActivityFeed` to the lib** (append before the private notify methods)

```php
    /**
     * Activity feed for $userId's friends: awards earned + 'going' RSVPs, merged
     * newest-first. Returns pre-rendered text + icon + relative time (display is dumb).
     * @return array ['Status'=>0, 'Items'=>[ {Type,Text,Icon,Ts,Ago,LinkUrl} ]]
     */
    public function GetActivityFeed($userId, $limit = 30)
    {
        $userId = (int) $userId;
        $limit  = (int) $limit > 0 ? (int) $limit : 30;
        $ids = $this->GetFriendIds($userId);
        if (count($ids) === 0) {
            return ['Status' => 0, 'Items' => []];
        }
        $in = implode(',', array_map('intval', $ids));
        $items = [];

        // --- Awards earned (ork_awards.date) ---
        $this->db->Clear();
        $r = $this->db->query(
            'SELECT a.mundane_id, a.date AS ts, a.at_event_id,'
            . ' m.persona, aw.name AS award_name'
            . ' FROM ' . DB_PREFIX . 'awards a'
            . ' JOIN ' . DB_PREFIX . 'mundane m ON m.mundane_id = a.mundane_id'
            . ' LEFT JOIN ' . DB_PREFIX . 'award aw ON aw.award_id = a.award_id'
            . " WHERE a.mundane_id IN ({$in}) AND a.date IS NOT NULL"
            . ' ORDER BY a.date DESC LIMIT ' . $limit
        );
        if ($r !== false) {
            while ($r->next()) {
                $name = (string) $r->award_name;
                $items[] = [
                    'Type'    => 'award',
                    'Text'    => ((string) $r->persona) . ' received ' . ($name !== '' ? $name : 'an award'),
                    'Icon'    => 'fas fa-award',
                    'Ts'      => (string) $r->ts,
                    'LinkUrl' => '?Route=Player/profile/' . (int) $r->mundane_id,
                ];
            }
        }

        // --- Event RSVPs ('going'), keyed to an occurrence (event_calendardetail) ---
        $this->db->Clear();
        $r = $this->db->query(
            'SELECT rs.mundane_id, rs.modified AS ts, m.persona,'
            . ' e.name AS event_name, cd.event_start'
            . ' FROM ' . DB_PREFIX . 'event_rsvp rs'
            . ' JOIN ' . DB_PREFIX . 'mundane m ON m.mundane_id = rs.mundane_id'
            . ' JOIN ' . DB_PREFIX . 'event_calendardetail cd ON cd.event_calendardetail_id = rs.event_calendardetail_id'
            . ' JOIN ' . DB_PREFIX . 'event e ON e.event_id = cd.event_id'
            . " WHERE rs.mundane_id IN ({$in}) AND rs.status = 'going'"
            . ' ORDER BY rs.modified DESC LIMIT ' . $limit
        );
        if ($r !== false) {
            while ($r->next()) {
                $ev = (string) $r->event_name;
                $items[] = [
                    'Type'    => 'rsvp',
                    'Text'    => ((string) $r->persona) . ' is going to ' . ($ev !== '' ? $ev : 'an event'),
                    'Icon'    => 'fas fa-calendar-check',
                    'Ts'      => (string) $r->ts,
                    'LinkUrl' => '?Route=Event/index',
                ];
            }
        }

        // Merge newest-first, attach relative time, cap to $limit.
        usort($items, function ($a, $b) {
            return strcmp($b['Ts'], $a['Ts']);
        });
        $items = array_slice($items, 0, $limit);
        foreach ($items as &$it) {
            $it['Ago'] = $this->relTime($it['Ts']);
        }
        unset($it);

        return ['Status' => 0, 'Items' => $items];
    }

    /** Compact relative-time (mirrors Notification::RelativeTime). */
    private function relTime($ts)
    {
        if (!$ts || $ts === '0000-00-00 00:00:00' || $ts === '0000-00-00') {
            return '';
        }
        $then = strtotime($ts);
        if ($then === false) {
            return '';
        }
        $diff = max(0, time() - $then);
        if ($diff < 86400) {
            return 'today';
        }
        $days = (int) floor($diff / 86400);
        if ($days < 7) {
            return $days . ($days === 1 ? ' day ago' : ' days ago');
        }
        if ($days < 30) {
            $w = (int) floor($days / 7);
            return $w . ($w === 1 ? ' week ago' : ' weeks ago');
        }
        if ($days < 365) {
            $mo = (int) floor($days / 30);
            return $mo . ($mo === 1 ? ' month ago' : ' months ago');
        }
        $y = (int) floor($days / 365);
        return $y . ($y === 1 ? ' year ago' : ' years ago');
    }
```

> Executor: `ork_awards` is the GRANT table (plural); `ork_award` is the catalog
> (singular). Confirm `ork_awards.date` / `at_event_id` and `ork_event_rsvp`
> columns against `ork.sql` + the recon notes before relying on them. Custom-named
> awards may have a `custom_name`; using catalog `name` is acceptable for v1.

- [ ] **Step 2: Add model pass-through** — in `orkui/model/model.Friendship.php`:

```php
    function get_activity_feed($userId, $limit = 30) { return $this->Friendship->GetActivityFeed($userId, $limit); }
```

- [ ] **Step 3: Add the `feed` AJAX action** — in `controller.FriendAjax.php`:

```php
    /** GET FriendAjax/feed → {status:0, items:[{type,text,icon,ago,link_url}]} */
    public function feed()
    {
        $uid = $this->guard();
        $this->load_model('Friendship');
        $res = $this->Friendship->get_activity_feed($uid, 30);
        $items = [];
        foreach (($res['Items'] ?? []) as $it) {
            $items[] = [
                'type'     => $it['Type'],
                'text'     => $it['Text'],
                'icon'     => $it['Icon'],
                'ago'      => $it['Ago'] ?? '',
                'link_url' => $it['LinkUrl'] ?? '',
            ];
        }
        echo json_encode(['status' => 0, 'items' => $items]);
        exit;
    }
```

- [ ] **Step 4: Lint all three**

Run: `php -l system/lib/ork3/class.Friendship.php && php -l orkui/model/model.Friendship.php && php -l orkui/controller/controller.FriendAjax.php`
Expected: all `No syntax errors detected`.

- [ ] **Step 5: Curl-verify the feed** (as user A, who is now friends with B; B should have at least one award or RSVP — seed one if needed)

```bash
curl -s -c "$JAR" -b "$JAR" "$BASE?Route=FriendAjax/feed"
```
Expected: `{"status":0,"items":[...]}` with B's awards/RSVPs, newest-first; empty `items` if B has none (and empty if A has no friends).

- [ ] **Step 6: Commit**

```bash
git add system/lib/ork3/class.Friendship.php orkui/model/model.Friendship.php orkui/controller/controller.FriendAjax.php
git commit -m "Friends: activity feed (awards + RSVPs merged newest-first)"
```

---

## Task 14: Friends attending an event

**Files:**
- Modify: `orkui/controller/controller.Event.php` (the action that builds `RsvpData`, ~line 290)
- Modify: `orkui/template/revised-frontend/Eventnew_index.tpl`

- [ ] **Step 1: Compute the friends-attending subset in the controller** — where the controller assembles `$this->data['RsvpData'][$detail_id]` (uses `Model_Event::get_rsvp_list`), intersect attendees with the viewer's friends:

```php
        // Friends attending: intersect this occurrence's RSVP list with the
        // viewer's friends (login-gated). Only personas of confirmed friends.
        $uid = isset($this->session->user_id) ? (int) $this->session->user_id : 0;
        if ($uid > 0) {
            $this->load_model('Friendship');
            $friendIds = array_flip($this->Friendship->get_friend_ids($uid)); // O(1) lookup
            // For each occurrence's RSVP list already fetched into $rsvpList:
            //   $rsvpList = $this->Model_Event->get_rsvp_list($detail_id); (existing call)
            $friendsGoing = [];
            foreach ($rsvpList as $att) {
                if (isset($friendIds[(int) $att['MundaneId']]) && ($att['Status'] ?? '') === 'going') {
                    $friendsGoing[] = ['MundaneId' => (int) $att['MundaneId'], 'Persona' => $att['Persona']];
                }
            }
            $this->data['RsvpData'][$detail_id]['FriendsGoing'] = $friendsGoing;
        }
```

> Executor: adapt to the controller's ACTUAL loop variables. The recon confirms
> `Model_Event::get_rsvp_list($detail_id)` returns rows with `MundaneId`, `Persona`,
> `Status`. Locate where `RsvpData` is built (~line 290 in `controller.Event.php`)
> and attach `FriendsGoing` per occurrence. `get_rsvp_list` may currently be called
> only when `$can_manage` — if so, call it (or reuse its data) for the friends
> intersection regardless of manage rights, but expose ONLY friends' personas to
> the viewer (never the full list to a non-manager).

- [ ] **Step 2: Render the widget in the template** — in `Eventnew_index.tpl`, near each occurrence's RSVP area:

```php
<?php
$__fg = $RsvpData[$detail_id]['FriendsGoing'] ?? [];
if (!empty($__fg)):
?>
  <div class="friends-going" data-tip="Friends of yours who RSVP'd 'going'">
    <i class="fas fa-user-friends"></i>
    <?= count($__fg) ?> friend<?= count($__fg) === 1 ? '' : 's' ?> going:
    <?php
      $__names = array_map(function ($f) {
        return '<a href="index.php?Route=Player/profile/' . (int)$f['MundaneId'] . '">' . htmlspecialchars($f['Persona']) . '</a>';
      }, array_slice($__fg, 0, 8));
      echo implode(', ', $__names);
      if (count($__fg) > 8) { echo ' +' . (count($__fg) - 8) . ' more'; }
    ?>
  </div>
<?php endif; ?>
```

> Confirm the loop variable for the current occurrence id in the template (it
> renders `RsvpData` keyed by `$detail_id` — match the existing variable name).

- [ ] **Step 3: Add styles** (append to orkui.css)

```css
.friends-going { margin: .5rem 0; font-size: .9rem; color: #444; display: flex; align-items: center; gap: .4rem; flex-wrap: wrap; }
.friends-going a { color: #2a5db0; text-decoration: none; }
.friends-going a:hover { text-decoration: underline; }
html[data-theme="dark"] .friends-going { color: #ccc; }
html[data-theme="dark"] .friends-going a { color: #8ab4f8; }
```

- [ ] **Step 4: Lint + verify**

Run: `awk '/^\t/{c++} END{print c+0}' orkui/controller/controller.Event.php` (normalize if non-zero), then `php -l orkui/controller/controller.Event.php`.
Verify (Claude-in-Chrome or curl): open an event where a friend has RSVP'd 'going' → "N friends going: …" appears; a viewer with no friends attending sees nothing.

- [ ] **Step 5: Commit**

```bash
git add orkui/controller/controller.Event.php orkui/template/revised-frontend/Eventnew_index.tpl orkui/template/default/style/orkui.css
git commit -m "Friends: 'friends attending' widget on event pages"
```

---

## Task 15: Recommend a friend (reuse existing recs path)

**Files:**
- Modify: `orkui/template/revised-frontend/script/revised.js` (wire the hub "Recommend" button)

**Approach:** the Friends hub friend cards already render a `.friend-recommend`
button (Task 11) carrying `data-target` (recipient mundane_id) + `data-name`. The
lowest-risk, DRY path is to **deep-link to the recipient's existing profile
recommendation flow** — the route `Player/profile/{id}` already hosts the
`addrecommendation` action and its form. v1 routes the click there with an
intent flag rather than duplicating the recommendation modal.

- [ ] **Step 1: Wire the Recommend button** (append to the hub IIFE or add a small delegated handler)

```javascript
/* ===== Friends: recommend-a-friend shortcut ===== */
(function () {
  document.addEventListener('click', function (e) {
    var btn = e.target.closest ? e.target.closest('.friend-recommend') : null;
    if (!btn) { return; }
    var target = btn.getAttribute('data-target');
    if (!target) { return; }
    // Deep-link to the recipient's profile and auto-open its recommendation form.
    window.location.href = 'index.php?Route=Player/profile/' + encodeURIComponent(target) + '#recommend';
  });
})();
```

- [ ] **Step 2: Auto-open the recommendation form on `#recommend`** — confirm the profile already has a recommendation form/modal (the `addrecommendation` action exists). If there is an existing "Recommend for Award" trigger button on the profile, add a tiny hook in revised.js to click/open it when the hash is `#recommend`:

```javascript
(function () {
  function openRecOnHash() {
    if (window.location.hash !== '#recommend') { return; }
    // Match the profile's existing recommend trigger (confirm selector on the
    // profile template — e.g. #recommendBtn or .open-recommend). Adjust selector.
    var trigger = document.getElementById('recommendBtn') || document.querySelector('.open-recommend');
    if (trigger) { trigger.click(); }
  }
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', openRecOnHash);
  } else {
    openRecOnHash();
  }
})();
```

> Executor: read `Playernew_index.tpl` to find the EXACT existing recommend
> trigger selector and use it. If the profile has no dedicated trigger (the form
> is always visible), scroll it into view instead of `.click()`. Do NOT build a
> new recommendation form — reuse the existing `addrecommendation` path entirely.

- [ ] **Step 3: Verify** (Claude-in-Chrome): from `Friend/index`, click Recommend on a friend → lands on their profile with the recommendation form open/focused, recipient pre-set (it's their profile). Submit a test rec; confirm a row in `ork_recommendations`:

```bash
docker exec ork3-php8-app sh -c 'mysql -h db -uork -pork ork -e "SELECT recommendations_id,mundane_id,recommended_by_id,award_id FROM ork_recommendations ORDER BY recommendations_id DESC LIMIT 3;"'
```

- [ ] **Step 4: Commit**

```bash
git add orkui/template/revised-frontend/script/revised.js
git commit -m "Friends: recommend-a-friend shortcut from the hub (reuses recs flow)"
```

---

## Task 16: Navigation entry + final polish

**Files:**
- Modify: `orkui/template/default/default.theme` (add a "Friends" link near the notification bell / user menu)

- [ ] **Step 1: Add a Friends nav link** — in `default.theme`, inside the authenticated `#controls` area (gated by `$this->__session->token != null`, mirroring the bell), add:

```php
<?php if ($this->__session->token != null): ?>
  <a class="control-link friends-nav" href="index.php?Route=Friend/index" data-tip="My Friends">
    <i class="fas fa-user-friends"></i>
  </a>
<?php endif; ?>
```

> Executor: match the exact markup/placement convention of the existing bell in
> `#controls`. Confirm the session-gate variable name used there.

- [ ] **Step 2: Full dark-mode + lifecycle walk** (Claude-in-Chrome). Verify, in BOTH themes:
  - Profile: Add Friend → Pending → (other account) Accept → Friends ▾ menu → Unfriend / Block (via `tnConfirm`).
  - Non-friend profile shows NO friends section and NO count.
  - Hub: all three tabs; Requests Accept/Decline; Activity feed renders awards + RSVPs.
  - Event page: "friends attending" widget.
  - Recommend shortcut lands on the profile rec flow.
  - Notification bell shows `friend_request` / `friend_accept` with correct icons.

- [ ] **Step 3: Confirm no stray debug, no native dialogs, no native `title` tooltips** in the new code:

```bash
grep -rn "confirm(\|alert(\|console.log\|title=" orkui/template/revised-frontend/Friendnew_index.tpl orkui/controller/controller.Friend*.php | grep -v data-tip
```
Expected: no native `confirm(`/`alert(`, no leftover `console.log`, no native `title=` (use `data-tip`).

- [ ] **Step 4: Lint the theme + commit**

```bash
php -l orkui/template/default/default.theme  # if it's a PHP-parsable theme; otherwise skip
git add orkui/template/default/default.theme
git commit -m "Friends: navigation entry + final polish pass"
```

---

## Self-review checklist (run before declaring the plan done)

- [ ] **Spec coverage:** mutual graph (T1,T3), anyone-can-request (T3 `Request`), block=request-gate-only (T3 `Block`/`isBlocked`, never unfriends), hide-both visibility (T6 `list` gate, T7-T8 section gate), delete-on-decline/cancel/unfriend (T3), notifications integration (T2 icons, T3 notify methods), button states (T8-T9), hub (T11-T12), feed awards+RSVPs no level-ups (T13), friends-attending (T14), recommend (T15). ✓
- [ ] **No level-up code anywhere** (explicitly out of scope). ✓
- [ ] **Type/name consistency:** lib methods (`Request`/`Accept`/…/`GetActivityFeed`) ↔ model snake_case pass-throughs ↔ controller calls. JSON keys (`state`, `blocked_by_me`, `friends`, `requests`, `items`) ↔ JS readers. ✓
- [ ] **Every new PHP file linted; every mutation curl-verified; dark-mode walked.** ✓
- [ ] **Commit hygiene:** explicit staging, `git diff --cached` before commit, never stage Authorization.php/CLAUDE.md. ✓
```
