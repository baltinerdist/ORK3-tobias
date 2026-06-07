<?php

class Inventory extends Ork3
{
    public static $CATEGORIES = [
        'weapons'         => 'Weapons',
        'armor'           => 'Armor',
        'shields'         => 'Shields',
        'garb_regalia'    => 'Garb / Regalia',
        'banners'         => 'Banners / Heraldry',
        'tentage'         => 'Pavilions / Tentage',
        'archery_siege'   => 'Archery / Siege',
        'event_equipment' => 'Event Equipment',
        'electronics'     => 'Electronics / AV',
        'inventory_other' => 'Other',
    ];

    public static $REMOVAL_REASONS = [
        'sold'          => 'Sold',
        'donated'       => 'Donated / Gifted',
        'unrepairable'  => 'Damaged Beyond Repair',
        'lost'          => 'Lost / Stolen',
        'consumed'      => 'Consumed / Used Up',
        'transferred'   => 'Transferred to Another Org',
        'removal_other' => 'Other',
    ];

    public static $CONDITIONS = ['new', 'good', 'fair', 'poor', 'needs_repair'];

    public function __construct()
    {
        parent::__construct();
        $this->item  = new yapo($this->db, DB_PREFIX . 'inventory_item');
        $this->audit = new yapo($this->db, DB_PREFIX . 'inventory_audit');
    }

    /** Resolve auth; returns mundane_id (>0) or 0 if unauthorized for this org. */
    private function authFor($token, $owner_type, $owner_id)
    {
        $owner_type = ($owner_type === 'park') ? 'park' : 'kingdom';
        $authType   = ($owner_type === 'park') ? AUTH_PARK : AUTH_KINGDOM;
        $mundane_id = Ork3::$Lib->authorization->IsAuthorized($token);
        if ($mundane_id > 0 && Ork3::$Lib->authorization->HasAuthority($mundane_id, $authType, (int)$owner_id, AUTH_EDIT)) {
            return (int)$mundane_id;
        }
        return 0;
    }

    private function normType($t) { return ($t === 'park') ? 'park' : 'kingdom'; }

    private function validCategory($cat) { return isset(self::$CATEGORIES[$cat]); }
    private function validReason($r)     { return isset(self::$REMOVAL_REASONS[$r]); }
    private function validCondition($c)   { return in_array($c, self::$CONDITIONS, true); }

    /** Display name of the org (park/kingdom) by id; also returns KingdomId for player-search scope. */
    public function GetOwnerName($token, $owner_type, $owner_id)
    {
        if (!$this->authFor($token, $owner_type, $owner_id)) { return NoAuthorization(); }
        global $DB;
        $owner_type = $this->normType($owner_type);
        $owner_id = (int)$owner_id;
        $DB->Clear();
        $name = '';
        $kingdom_id = $owner_id;
        if ($owner_type === 'park') {
            $rs = $DB->DataSet("SELECT name, kingdom_id FROM " . DB_PREFIX . "park WHERE park_id=$owner_id LIMIT 1");
            if ($rs && $rs->Next()) { $name = $rs->name; $kingdom_id = (int)$rs->kingdom_id; }
        } else {
            $rs = $DB->DataSet("SELECT name FROM " . DB_PREFIX . "kingdom WHERE kingdom_id=$owner_id LIMIT 1");
            if ($rs && $rs->Next()) { $name = $rs->name; }
        }
        return Success(['Name' => $name, 'KingdomId' => (int)$kingdom_id]);
    }

    /** Cheap change-signal for polling: COUNT/MAX over items (no full scan). */
    public function GetRevision($token, $owner_type, $owner_id)
    {
        if (!$this->authFor($token, $owner_type, $owner_id)) { return NoAuthorization(); }
        global $DB;
        $owner_type = $this->normType($owner_type);
        $owner_id = (int)$owner_id;
        $DB->Clear();
        $rs = $DB->DataSet("SELECT COUNT(*) n, COALESCE(MAX(id),0) mx,
            COALESCE(UNIX_TIMESTAMP(MAX(GREATEST(created_at, COALESCE(updated_at, created_at),
              COALESCE(removed_at, created_at), COALESCE(deleted_at, created_at)))),0) ts
            FROM " . DB_PREFIX . "inventory_item WHERE owner_type='$owner_type' AND owner_id=$owner_id");
        $n = 0; $mx = 0; $ts = 0;
        if ($rs && $rs->Next()) { $n = (int)$rs->n; $mx = (int)$rs->mx; $ts = (int)$rs->ts; }
        return Success(['Rev' => $n . '-' . $mx . '-' . $ts]);
    }

    /** Summary over ACTIVE items: total value, total units, line items, # needs repair,
     *  value-by-category, count-by-condition. $filters narrows the same way GetItems does
     *  (category, condition, q) but NOT status — summary is always over active items. */
    public function GetSummary($token, $owner_type, $owner_id, $filters = [])
    {
        global $DB;
        if (!$this->authFor($token, $owner_type, $owner_id)) { return NoAuthorization(); }
        $owner_type = $this->normType($owner_type); $owner_id = (int)$owner_id;
        $where = "owner_type='$owner_type' AND owner_id=$owner_id AND deleted_at IS NULL AND removed_at IS NULL";
        if (!empty($filters['category']))  { $where .= " AND category = '" . addslashes($filters['category']) . "'"; }
        if (!empty($filters['condition'])) { $where .= " AND `condition` = '" . addslashes($filters['condition']) . "'"; }
        if (!empty($filters['q']))         { $where .= " AND name LIKE '%" . addslashes($filters['q']) . "%'"; }

        $DB->Clear();
        $rs = $DB->DataSet("SELECT
            COALESCE(SUM(quantity * unit_value),0) AS total_value,
            COALESCE(SUM(quantity),0)              AS total_units,
            COUNT(*)                               AS line_items,
            COALESCE(SUM(CASE WHEN `condition`='needs_repair' THEN 1 ELSE 0 END),0) AS needs_repair
            FROM " . DB_PREFIX . "inventory_item WHERE $where");
        $tv = 0.0; $tu = 0; $li = 0; $nr = 0;
        if ($rs && $rs->Next()) {
            $tv = (float)$rs->total_value; $tu = (int)$rs->total_units;
            $li = (int)$rs->line_items;    $nr = (int)$rs->needs_repair;
        }

        $DB->Clear();
        $rs2 = $DB->DataSet("SELECT category, COALESCE(SUM(quantity * unit_value),0) AS v
            FROM " . DB_PREFIX . "inventory_item WHERE $where GROUP BY category");
        $byCat = [];
        while ($rs2 && $rs2->Next()) { $byCat[$rs2->category] = round((float)$rs2->v, 2); }

        $DB->Clear();
        $rs3 = $DB->DataSet("SELECT `condition` AS c, COUNT(*) AS n
            FROM " . DB_PREFIX . "inventory_item WHERE $where GROUP BY `condition`");
        $byCond = [];
        while ($rs3 && $rs3->Next()) { $byCond[$rs3->c] = (int)$rs3->n; }

        return Success([
            'TotalValue'  => round($tv, 2),
            'TotalUnits'  => $tu,
            'LineItems'   => $li,
            'NeedsRepair' => $nr,
            'ByCategory'  => $byCat,
            'ByCondition' => $byCond,
        ]);
    }
}
