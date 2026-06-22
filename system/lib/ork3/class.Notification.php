<?php

/**
 * Notification — in-app notifications, one row per recipient (fan-out).
 *
 * Auto-registers as Ork3::$Lib->notification (startup.php scan).
 * This is the ONLY layer that touches $DB / yapo for ork_notification.
 * Every raw query calls $this->db->Clear() first.
 *
 * Design: docs/superpowers/specs/2026-06-20-notifications-system-design.md
 */
class Notification extends Ork3
{
    /** Default FontAwesome icon per notification type, used when none supplied. */
    private static $DEFAULT_ICONS = [
        'award'          => 'fas fa-award',
        'rec_status'     => 'fas fa-clipboard-check',
        'announcement'   => 'fas fa-bullhorn',
        'friend_request' => 'fas fa-user-plus',
        'friend_accept'  => 'fas fa-user-check',
        'event'          => 'fas fa-calendar-plus',
        'event_reminder' => 'fas fa-clock',
    ];

    public function __construct()
    {
        parent::__construct();
        $this->notification = new yapo($this->db, DB_PREFIX . 'notification');
    }

    /**
     * Resolve the icon to store: explicit value wins, else per-type default,
     * else a generic bell.
     */
    private function ResolveIcon($type, $icon)
    {
        if (is_string($icon) && $icon !== '') {
            // Allowlist: FA classes are only letters, digits, spaces, hyphens,
            // underscores. Reject anything else (defense-in-depth — the value is
            // rendered as a CSS class string) and fall back to the type default.
            if (preg_match('/^[A-Za-z0-9 _-]+$/', $icon)) {
                // FA5 renders nothing for a bare "fa-foo" class — ensure a family
                // token (fas/far/fal/fab/fad) is present, defaulting to solid.
                if (!preg_match('/\bfa[srlbd]\b/', $icon)) {
                    $icon = 'fas ' . $icon;
                }
                return $icon;
            }
        }
        return self::$DEFAULT_ICONS[$type] ?? 'fas fa-bell';
    }

    /**
     * Create a single notification for one recipient.
     *
     * @param int    $mundaneId recipient
     * @param string $type      award | rec_status | announcement
     * @param array  $fields    title, body, icon, link_url, payload, created_by
     * @return array Status tuple: ['Status' => 0|1, 'Error' => ?, 'NotificationId' => ?]
     */
    public function Create($mundaneId, $type, array $fields)
    {
        $mundaneId = (int) $mundaneId;
        $type = (string) $type;
        $title = isset($fields['title']) ? (string) $fields['title'] : '';

        if ($mundaneId <= 0 || $type === '' || $title === '') {
            return ['Status' => 1, 'Error' => 'mundane_id, type and title are required'];
        }

        // yapo drops null fields — store '' to keep nullable columns clearable.
        $this->notification->clear();
        $this->notification->mundane_id = $mundaneId;
        $this->notification->type       = $type;
        $this->notification->title      = $title;
        $this->notification->body       = isset($fields['body']) && $fields['body'] !== null ? (string) $fields['body'] : '';
        $this->notification->icon       = $this->ResolveIcon($type, $fields['icon'] ?? null);
        $this->notification->link_url   = isset($fields['link_url']) && $fields['link_url'] !== null ? (string) $fields['link_url'] : '';
        $this->notification->payload    = isset($fields['payload']) && $fields['payload'] !== null ? (string) $fields['payload'] : '';
        if (isset($fields['created_by']) && (int) $fields['created_by'] > 0) {
            $this->notification->created_by = (int) $fields['created_by'];
        }
        $this->notification->save();

        // yapo save() runs on its own YapoCore handle and, after insert, re-Finds
        // the row and populates the primary key on the object — read the new id
        // from there (NOT $this->db->GetLastInsertId(), which is a different handle).
        $newId = (int) $this->notification->notification_id;
        if ($newId <= 0) {
            // Insert did not yield a valid id (silent save failure / re-find miss).
            return ['Status' => 1, 'Error' => 'Insert did not return a valid id'];
        }
        return ['Status' => 0, 'NotificationId' => $newId];
    }

    /**
     * Fan-out: create the same notification for many recipients in one bulk INSERT.
     *
     * @param int[]  $mundaneIds recipients (deduped, positive ints only)
     * @param string $type
     * @param array  $fields     title, body, icon, link_url, payload, created_by
     * @return array ['Status' => 0|1, 'Error' => ?, 'Count' => int]
     */
    public function CreateBulk(array $mundaneIds, $type, array $fields)
    {
        $type  = (string) $type;
        $title = isset($fields['title']) ? (string) $fields['title'] : '';

        // Normalize recipients: positive ints, unique.
        $ids = [];
        foreach ($mundaneIds as $mid) {
            $mid = (int) $mid;
            if ($mid > 0) {
                $ids[$mid] = true;
            }
        }
        $ids = array_keys($ids);

        if ($type === '' || $title === '') {
            return ['Status' => 1, 'Error' => 'type and title are required'];
        }
        if (count($ids) === 0) {
            return ['Status' => 0, 'Count' => 0];
        }

        $icon      = $this->ResolveIcon($type, $fields['icon'] ?? null);
        $body      = isset($fields['body']) && $fields['body'] !== null ? (string) $fields['body'] : '';
        $linkUrl   = isset($fields['link_url']) && $fields['link_url'] !== null ? (string) $fields['link_url'] : '';
        $payload   = isset($fields['payload']) && $fields['payload'] !== null ? (string) $fields['payload'] : '';
        $createdBy = isset($fields['created_by']) && (int) $fields['created_by'] > 0 ? (int) $fields['created_by'] : null;

        // Chunk the fan-out: a single all-recipients multi-row INSERT can exceed
        // max_allowed_packet / the PDO placeholder limit on large kingdoms/global
        // sends and fail silently (Execute() discards the PDO result). Insert in
        // bounded batches and VERIFY each one actually wrote its rows.
        $cols      = '(mundane_id, type, title, body, icon, link_url, payload, created_by, created_at)';
        $batches   = array_chunk($ids, 500);
        $expected  = count($ids);
        $totalInserted = 0;

        foreach ($batches as $batch) {
            // Per-row parameterized placeholders, re-indexed from 0 each batch so
            // the keys stay unique within this single statement. Keeps the
            // SQL-injection-safe SetData/Execute binding (no string interpolation
            // of values).
            $rows = [];
            $data = [];
            $i = 0;
            foreach ($batch as $mid) {
                $rows[] = "(:m{$i}, :t{$i}, :ti{$i}, :b{$i}, :ic{$i}, :lu{$i}, :pl{$i}, :cb{$i}, NOW())";
                $data[":m{$i}"]  = $mid;
                $data[":t{$i}"]  = $type;
                $data[":ti{$i}"] = $title;
                $data[":b{$i}"]  = $body;
                $data[":ic{$i}"] = $icon;
                $data[":lu{$i}"] = $linkUrl;
                $data[":pl{$i}"] = $payload;
                $data[":cb{$i}"] = $createdBy; // null binds as SQL NULL (allowed: created_by is nullable)
                $i++;
            }

            $sql = 'INSERT INTO ' . DB_PREFIX . "notification {$cols} VALUES " . implode(', ', $rows);

            $this->db->Clear();
            $this->db->SetData($data);
            $this->db->Execute($sql);
            $this->db->Clear();

            // The Yapo stack exposes no affected-rows accessor (Execute() discards
            // the PDOStatement), so confirm the write with ROW_COUNT(), which
            // reports the affected rows of the immediately-preceding statement on
            // this same connection. DataSet() does not pre-fetch — advance first.
            $affected = 0;
            $r = $this->db->query('SELECT ROW_COUNT() AS n');
            if ($r !== false && $r->next()) {
                $affected = (int) $r->n;
            }
            $this->db->Clear();

            if ($affected < count($batch)) {
                // A batch under-wrote: stop and report exactly how far we got
                // rather than falsely claiming success for the whole fan-out.
                return [
                    'Status' => 1,
                    'Error'  => 'Bulk insert failed (wrote ' . ($totalInserted + $affected) . ' of ' . $expected . ')',
                    'Count'  => $totalInserted + $affected,
                ];
            }

            $totalInserted += $affected;
        }

        return ['Status' => 0, 'Count' => $totalInserted];
    }

    /**
     * Recent, non-dismissed notifications for a recipient, newest-first.
     * Returns both a raw created_at and a human relative-time "Ago" string so the
     * controller can render either.
     *
     * @return array ['Status' => 0, 'Notifications' => [ ... ]]
     */
    public function GetForMundane($mundaneId, $limit = 15)
    {
        $mundaneId = (int) $mundaneId;
        $limit = (int) $limit;
        if ($limit <= 0) {
            $limit = 15;
        }
        if ($mundaneId <= 0) {
            return ['Status' => 0, 'Notifications' => []];
        }

        $this->db->Clear();
        $r = $this->db->query(
            'SELECT notification_id, type, title, body, icon, link_url, read_at, created_at'
            . ' FROM ' . DB_PREFIX . 'notification'
            . " WHERE mundane_id = {$mundaneId} AND dismissed_at IS NULL"
            . " ORDER BY created_at DESC, notification_id DESC LIMIT {$limit}"
        );

        $out = [];
        // YapoDb::DataSet() does NOT reliably pre-fetch the first row, so always
        // drive iteration with while($r->next()).
        if ($r !== false) {
            while ($r->next()) {
                $out[] = [
                    'NotificationId' => (int) $r->notification_id,
                    'Type'           => $r->type,
                    'Title'          => $r->title,
                    'Body'           => $r->body,
                    'Icon'           => $this->ResolveIcon($r->type, $r->icon),
                    'LinkUrl'        => $r->link_url,
                    'Read'           => ($r->read_at !== null),
                    'CreatedAt'      => $r->created_at,
                    'Ago'            => $this->RelativeTime($r->created_at),
                ];
            }
        }

        return ['Status' => 0, 'Notifications' => $out];
    }

    /**
     * Count unread, non-dismissed notifications for the badge.
     *
     * @return int
     */
    public function UnreadCount($mundaneId)
    {
        $mundaneId = (int) $mundaneId;
        if ($mundaneId <= 0) {
            return 0;
        }

        $this->db->Clear();
        $r = $this->db->query(
            'SELECT COUNT(*) AS n FROM ' . DB_PREFIX . 'notification'
            . " WHERE mundane_id = {$mundaneId} AND read_at IS NULL AND dismissed_at IS NULL"
        );
        // DataSet() does not reliably pre-fetch — advance to the row before reading.
        if ($r !== false && $r->next()) {
            return (int) $r->n;
        }
        return 0;
    }

    /**
     * Mark notifications read for a recipient. $ids = specific notification_ids,
     * or null = every currently-unread row for the user. Scoped to $mundaneId so a
     * user can only mutate their own rows.
     *
     * @return array ['Status' => 0]
     */
    public function MarkRead($mundaneId, $ids = null)
    {
        $mundaneId = (int) $mundaneId;
        if ($mundaneId <= 0) {
            return ['Status' => 1, 'Error' => 'Invalid recipient'];
        }

        $idClause = '';
        if ($ids !== null) {
            $clean = [];
            foreach ((array) $ids as $id) {
                $id = (int) $id;
                if ($id > 0) {
                    $clean[$id] = true;
                }
            }
            $clean = array_keys($clean);
            if (count($clean) === 0) {
                return ['Status' => 0]; // nothing to do
            }
            $idClause = ' AND notification_id IN (' . implode(',', $clean) . ')';
        }

        $this->db->Clear();
        $this->db->Execute(
            'UPDATE ' . DB_PREFIX . 'notification SET read_at = NOW()'
            . " WHERE mundane_id = {$mundaneId} AND read_at IS NULL{$idClause}"
        );
        $this->db->Clear();

        return ['Status' => 0];
    }

    /**
     * Dismiss (hide from panel) a single notification. Scoped to $mundaneId so a
     * user can only dismiss their own rows. Row persists for history.
     *
     * @return array ['Status' => 0|1, 'Error' => ?]
     */
    public function Dismiss($mundaneId, $notificationId)
    {
        $mundaneId = (int) $mundaneId;
        $notificationId = (int) $notificationId;
        if ($mundaneId <= 0 || $notificationId <= 0) {
            return ['Status' => 1, 'Error' => 'Invalid request'];
        }

        $this->db->Clear();
        $this->db->Execute(
            'UPDATE ' . DB_PREFIX . 'notification SET dismissed_at = NOW()'
            . " WHERE notification_id = {$notificationId} AND mundane_id = {$mundaneId} AND dismissed_at IS NULL"
        );
        $this->db->Clear();

        return ['Status' => 0];
    }

    /**
     * Resolve active recipient mundane_ids for an announcement audience.
     * Keeps recipient-set SQL in the lib (architecture: $DB lives here, not in the
     * controller). Authority to target a scope is enforced by the CONTROLLER before
     * calling this — this method only resolves the id set.
     *
     * @param string $scope   'global' | 'kingdom' | 'park'
     * @param int    $scopeId kingdom_id or park_id (ignored for global)
     * @return int[] active recipient mundane_ids
     */
    public function GetRecipientsForScope($scope, $scopeId = 0)
    {
        $scope = (string) $scope;
        $scopeId = (int) $scopeId;

        if ($scope === 'park') {
            if ($scopeId <= 0) {
                return [];
            }
            $where = "park_id = {$scopeId} AND active = 1";
        } elseif ($scope === 'kingdom') {
            if ($scopeId <= 0) {
                return [];
            }
            $where = "kingdom_id = {$scopeId} AND active = 1";
        } elseif ($scope === 'global') {
            $where = 'active = 1';
        } else {
            return [];
        }

        $this->db->Clear();
        $r = $this->db->query(
            'SELECT mundane_id FROM ' . DB_PREFIX . 'mundane WHERE ' . $where
        );

        $ids = [];
        if ($r !== false) {
            while ($r->next()) {
                $ids[] = (int) $r->mundane_id;
            }
        }
        return $ids;
    }

    /**
     * Resolve active recipient mundane_ids for a kingdom AND its child
     * principalities (the "family"). Used for kingdom-scoped event notifications,
     * which intentionally fan out to the whole family.
     *
     * @param int $kingdomId parent kingdom_id
     * @return int[] active recipient mundane_ids across the family
     */
    public function GetRecipientsForFamilyKingdom($kingdomId)
    {
        $kingdomId = (int) $kingdomId;
        if ($kingdomId <= 0) {
            return [];
        }

        // Resolve family ids (parent + child principalities); fall back to the
        // parent alone if the kingdom helper is unavailable.
        $familyIds = [];
        if (isset(Ork3::$Lib->kingdom) && method_exists(Ork3::$Lib->kingdom, 'GetFamilyKingdomIds')) {
            $resolved = Ork3::$Lib->kingdom->GetFamilyKingdomIds($kingdomId);
            if (is_array($resolved)) {
                foreach ($resolved as $kid) {
                    $kid = (int) $kid;
                    if ($kid > 0) {
                        $familyIds[$kid] = true;
                    }
                }
            }
        }
        if (count($familyIds) === 0) {
            $familyIds[$kingdomId] = true;
        }
        $familyIds = array_keys($familyIds);

        // int-cast every id (no string interpolation of untrusted values).
        $inList = implode(',', array_map('intval', $familyIds));

        $this->db->Clear();
        $r = $this->db->query(
            'SELECT mundane_id FROM ' . DB_PREFIX . 'mundane'
            . " WHERE kingdom_id IN ({$inList}) AND active = 1"
        );

        $ids = [];
        if ($r !== false) {
            while ($r->next()) {
                $ids[] = (int) $r->mundane_id;
            }
        }
        return $ids;
    }

    /**
     * Fan-out exactly once per ($type, $dedupeKey) recipient: any recipient who
     * already has a notification of this type whose payload contains $dedupeKey is
     * skipped, so re-runs (e.g. a cron that fires twice) never double-notify.
     *
     * $dedupeKey is a short, collision-resistant string (e.g. "evt:123:7d") that
     * MUST also be embedded in $fields['payload'] by the caller so the LIKE match
     * can find it.
     *
     * @param int[]  $mundaneIds recipients
     * @param string $type
     * @param array  $fields     title, body, icon, link_url, payload, created_by
     * @param string $dedupeKey  short marker also present in $fields['payload']
     * @return array ['Status' => 0|1, 'Error' => ?, 'Count' => int, 'Skipped' => int]
     */
    public function CreateBulkOnce(array $mundaneIds, $type, array $fields, $dedupeKey)
    {
        $type      = (string) $type;
        $dedupeKey = (string) $dedupeKey;

        // Normalize recipients: positive ints, unique.
        $ids = [];
        foreach ($mundaneIds as $mid) {
            $mid = (int) $mid;
            if ($mid > 0) {
                $ids[$mid] = true;
            }
        }
        $ids = array_keys($ids);

        if ($type === '' || $dedupeKey === '') {
            return ['Status' => 1, 'Error' => 'type and dedupeKey are required', 'Count' => 0, 'Skipped' => 0];
        }
        if (count($ids) === 0) {
            return ['Status' => 0, 'Count' => 0, 'Skipped' => 0];
        }

        // Find recipients who already have this dedupeKey for this type, and drop
        // them from the send set. NOTE: this DB layer's query() does NOT apply
        // SetData() bindings (only Execute()/DataSet() consume $this->Data) — the
        // file's established SELECT pattern is direct interpolation of safe values.
        // $type and $dedupeKey are app-controlled (type is a fixed slug; dedupeKey
        // is "evt:{int}:{label}"); sanitize to a strict charset before interpolating.
        $safeType = preg_replace('/[^A-Za-z0-9_]/', '', $type);
        $safeKey  = preg_replace('/[^A-Za-z0-9:_-]/', '', (string) $dedupeKey);
        $inList = implode(',', array_map('intval', $ids));
        $this->db->Clear();
        $r = $this->db->query(
            'SELECT mundane_id FROM ' . DB_PREFIX . 'notification'
            . " WHERE type = '{$safeType}' AND payload LIKE '%{$safeKey}%'"
            . " AND mundane_id IN ({$inList})"
        );
        $already = [];
        if ($r !== false) {
            while ($r->next()) {
                $already[(int) $r->mundane_id] = true;
            }
        }
        $this->db->Clear();

        $remaining = [];
        foreach ($ids as $mid) {
            if (!isset($already[$mid])) {
                $remaining[] = $mid;
            }
        }
        $skipped = count($ids) - count($remaining);

        if (count($remaining) === 0) {
            return ['Status' => 0, 'Count' => 0, 'Skipped' => $skipped];
        }

        $result = $this->CreateBulk($remaining, $type, $fields);
        $inserted = isset($result['Count']) ? (int) $result['Count'] : 0;
        if (isset($result['Status']) && (int) $result['Status'] !== 0) {
            return [
                'Status'  => 1,
                'Error'   => $result['Error'] ?? 'Bulk insert failed',
                'Count'   => $inserted,
                'Skipped' => $skipped,
            ];
        }

        return ['Status' => 0, 'Count' => $inserted, 'Skipped' => $skipped];
    }

    /**
     * Human relative-time string from a 'Y-m-d H:i:s' timestamp.
     */
    private function RelativeTime($ts)
    {
        if ($ts === null || $ts === '' || $ts === '0000-00-00 00:00:00') {
            return '';
        }
        $then = strtotime($ts);
        if ($then === false) {
            return '';
        }
        $diff = time() - $then;
        if ($diff < 0) {
            $diff = 0;
        }

        if ($diff < 60) {
            return 'just now';
        }
        $mins = (int) floor($diff / 60);
        if ($mins < 60) {
            return $mins . ($mins === 1 ? ' minute ago' : ' minutes ago');
        }
        $hours = (int) floor($diff / 3600);
        if ($hours < 24) {
            return $hours . ($hours === 1 ? ' hour ago' : ' hours ago');
        }
        $days = (int) floor($diff / 86400);
        if ($days < 7) {
            return $days . ($days === 1 ? ' day ago' : ' days ago');
        }
        if ($days < 30) {
            $weeks = (int) floor($days / 7);
            return $weeks . ($weeks === 1 ? ' week ago' : ' weeks ago');
        }
        if ($days < 365) {
            $months = (int) floor($days / 30);
            return $months . ($months === 1 ? ' month ago' : ' months ago');
        }
        $years = (int) floor($days / 365);
        return $years . ($years === 1 ? ' year ago' : ' years ago');
    }
}
