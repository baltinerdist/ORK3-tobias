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
     * Relationship id-sets for $userId, for cheap O(1) badge/button rendering of a
     * roster (e.g. an event RSVP / attendance list). Uses at most 3 queries: the
     * accepted-friend ids (GetFriendIds) plus pending-outgoing and pending-incoming
     * other-side ids derived from light SELECTs.
     *
     * @return array ['FriendIds'=>int[], 'PendingOutIds'=>int[], 'PendingInIds'=>int[]]
     */
    public function GetRelationshipSets($userId)
    {
        $userId = (int) $userId;
        $out = ['FriendIds' => [], 'PendingOutIds' => [], 'PendingInIds' => []];
        if ($userId <= 0) {
            return $out;
        }

        // Accepted friends (reuses the existing helper — 1 query).
        $out['FriendIds'] = $this->GetFriendIds($userId);

        // Pending outgoing: requests this user initiated → other side's id.
        $this->db->Clear();
        $r = $this->db->query(
            'SELECT IF(mundane_lo = ' . $userId . ', mundane_hi, mundane_lo) AS oid'
            . ' FROM ' . DB_PREFIX . 'friendship'
            . " WHERE status = 'pending' AND requested_by = {$userId}"
            . " AND (mundane_lo = {$userId} OR mundane_hi = {$userId})"
        );
        if ($r !== false) {
            while ($r->next()) {
                $out['PendingOutIds'][] = (int) $r->oid;
            }
        }

        // Pending incoming: requests someone else initiated → requester's id.
        $this->db->Clear();
        $r = $this->db->query(
            'SELECT requested_by AS oid'
            . ' FROM ' . DB_PREFIX . 'friendship'
            . " WHERE status = 'pending' AND requested_by <> {$userId}"
            . " AND (mundane_lo = {$userId} OR mundane_hi = {$userId})"
        );
        if ($r !== false) {
            while ($r->next()) {
                $out['PendingInIds'][] = (int) $r->oid;
            }
        }

        return $out;
    }

    /**
     * Accepted friends of $userId with display fields, persona-sorted.
     * @return array ['Status'=>0, 'Friends'=>[ {MundaneId,Persona,ParkAbbr,KingdomAbbr,HasImage,HasHeraldry} ]]
     */
    /**
     * Best avatar URL for a player: profile photo, else heraldry, else '' (the UI
     * renders a monogram when empty). Mirrors the player-image / heraldry URL
     * conventions in class.Player.php / class.Heraldry.php.
     */
    private function avatarUrl($mundaneId, $hasImage, $hasHeraldry, $modified = '')
    {
        $mundaneId = (int) $mundaneId;
        if ($mundaneId <= 0) {
            return '';
        }
        $name = sprintf('%06d', $mundaneId);
        if ($hasImage && defined('HTTP_PLAYER_IMAGE') && defined('DIR_PLAYER_IMAGE')) {
            $ext  = file_exists(DIR_PLAYER_IMAGE . $name . '.png') ? 'png' : 'jpg';
            $bust = $modified !== '' ? ('?' . strtotime($modified)) : '';
            return HTTP_PLAYER_IMAGE . $name . '.' . $ext . $bust;
        }
        if ($hasHeraldry && defined('HTTP_PLAYER_HERALDRY') && defined('DIR_PLAYER_HERALDRY')) {
            $ext = file_exists(DIR_PLAYER_HERALDRY . $name . '.png') ? 'png' : 'jpg';
            return HTTP_PLAYER_HERALDRY . $name . '.' . $ext;
        }
        return '';
    }

    /** First letter of a persona for the monogram fallback. */
    private function initial($persona)
    {
        $persona = trim((string) $persona);
        return $persona === '' ? '?' : strtoupper(mb_substr($persona, 0, 1));
    }

    /** "May 2026"-style label from a datetime; '' if unknown. */
    private function sinceLabel($ts)
    {
        if (!$ts || $ts === '0000-00-00 00:00:00') {
            return '';
        }
        $t = strtotime($ts);
        return $t ? date('M Y', $t) : '';
    }

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
            'SELECT m.mundane_id, m.persona, m.has_image, m.has_heraldry, m.modified,'
            . ' p.abbreviation AS park_abbr, p.name AS park_name,'
            . ' k.abbreviation AS kingdom_abbr, k.name AS kingdom_name,'
            . ' f.responded_at AS since'
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
                $persona = (string) $r->persona;
                $out[] = [
                    'MundaneId'   => (int) $r->mundane_id,
                    'Persona'     => $persona,
                    'Initial'     => $this->initial($persona),
                    'ParkAbbr'    => (string) $r->park_abbr,
                    'KingdomAbbr' => (string) $r->kingdom_abbr,
                    'ParkName'    => (string) $r->park_name,
                    'KingdomName' => (string) $r->kingdom_name,
                    'HasImage'    => (int) $r->has_image,
                    'HasHeraldry' => (int) $r->has_heraldry,
                    'Avatar'      => $this->avatarUrl((int) $r->mundane_id, (int) $r->has_image, (int) $r->has_heraldry, (string) $r->modified),
                    'Since'       => $this->sinceLabel((string) $r->since),
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
            . ' m.persona, m.has_image, m.has_heraldry, m.modified,'
            . ' p.abbreviation AS park_abbr, p.name AS park_name,'
            . ' k.abbreviation AS kingdom_abbr, k.name AS kingdom_name'
            . ' FROM ' . DB_PREFIX . 'friendship f'
            . ' JOIN ' . DB_PREFIX . 'mundane m ON m.mundane_id = f.requested_by'
            . ' LEFT JOIN ' . DB_PREFIX . 'park p ON p.park_id = m.park_id'
            . ' LEFT JOIN ' . DB_PREFIX . 'kingdom k ON k.kingdom_id = m.kingdom_id'
            . " WHERE f.status = 'pending' AND f.requested_by <> {$userId}"
            . " AND (f.mundane_lo = {$userId} OR f.mundane_hi = {$userId})"
            . ' ORDER BY f.requested_at DESC'
        );
        return ['Status' => 0, 'Requests' => $this->collectRequestRows($r)];
    }

    /**
     * Outgoing pending requests for $userId (requests THEY sent that are awaiting
     * the other person's response). Same row shape as GetPendingIncoming so the UI
     * can render both with one card partial.
     *
     * @return array ['Status'=>0, 'Requests'=>[ {MundaneId,Persona,...,RequestedAt} ]]
     */
    public function GetPendingOutgoing($userId)
    {
        $userId = (int) $userId;
        if ($userId <= 0) {
            return ['Status' => 0, 'Requests' => []];
        }
        $this->db->Clear();
        $r = $this->db->query(
            'SELECT IF(f.mundane_lo = ' . $userId . ', f.mundane_hi, f.mundane_lo) AS mundane_id, f.requested_at,'
            . ' m.persona, m.has_image, m.has_heraldry, m.modified,'
            . ' p.abbreviation AS park_abbr, p.name AS park_name,'
            . ' k.abbreviation AS kingdom_abbr, k.name AS kingdom_name'
            . ' FROM ' . DB_PREFIX . 'friendship f'
            . ' JOIN ' . DB_PREFIX . 'mundane m ON m.mundane_id = IF(f.mundane_lo = ' . $userId . ', f.mundane_hi, f.mundane_lo)'
            . ' LEFT JOIN ' . DB_PREFIX . 'park p ON p.park_id = m.park_id'
            . ' LEFT JOIN ' . DB_PREFIX . 'kingdom k ON k.kingdom_id = m.kingdom_id'
            . " WHERE f.status = 'pending' AND f.requested_by = {$userId}"
            . " AND (f.mundane_lo = {$userId} OR f.mundane_hi = {$userId})"
            . ' ORDER BY f.requested_at DESC'
        );
        return ['Status' => 0, 'Requests' => $this->collectRequestRows($r)];
    }

    /** Build the shared request-card row array from a result set (incoming/outgoing). */
    private function collectRequestRows($r)
    {
        $out = [];
        if ($r !== false) {
            while ($r->next()) {
                $persona = (string) $r->persona;
                $out[] = [
                    'MundaneId'   => (int) $r->mundane_id,
                    'Persona'     => $persona,
                    'Initial'     => $this->initial($persona),
                    'ParkAbbr'    => (string) $r->park_abbr,
                    'KingdomAbbr' => (string) $r->kingdom_abbr,
                    'ParkName'    => (string) $r->park_name,
                    'KingdomName' => (string) $r->kingdom_name,
                    'HasImage'    => (int) $r->has_image,
                    'HasHeraldry' => (int) $r->has_heraldry,
                    'Avatar'      => $this->avatarUrl((int) $r->mundane_id, (int) $r->has_image, (int) $r->has_heraldry, (string) $r->modified),
                    'RequestedAt' => (string) $r->requested_at,
                ];
            }
        }
        return $out;
    }

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
