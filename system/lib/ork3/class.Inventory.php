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

    private function writeAudit($item_id, $action, $mundane_id, $before, $after)
    {
        $this->audit->clear();
        $this->audit->item_id    = (int)$item_id;
        $this->audit->action     = $action;
        $this->audit->changed_by = (int)$mundane_id;
        $this->audit->changed_at = date('Y-m-d H:i:s');
        // yapo drops null fields from INSERT; '' clears the column instead of leaving it stale.
        $this->audit->before_json = $before === null ? '' : json_encode($before);
        $this->audit->after_json  = $after  === null ? '' : json_encode($after);
        $this->audit->save();
    }

    private function itemToArray()
    {
        return [
            'id'                => $this->item->id,
            'owner_type'        => $this->item->owner_type,
            'owner_id'          => $this->item->owner_id,
            'name'              => $this->item->name,
            'category'          => $this->item->category,
            'quantity'          => $this->item->quantity,
            'condition'         => $this->item->condition,
            'unit_value'        => $this->item->unit_value,
            'location'          => $this->item->location,
            'held_by'           => $this->item->held_by,
            'held_by_player_id' => $this->item->held_by_player_id,
            'acquired_date'     => $this->item->acquired_date,
            'notes'             => $this->item->notes,
            'removed_at'        => $this->item->removed_at,
            'removal_reason'    => $this->item->removal_reason,
            'removal_note'      => $this->item->removal_note,
            'deleted_at'        => $this->item->deleted_at,
        ];
    }

    /** Load an owned, non-deleted item into $this->item; false if not found / not owned. */
    private function loadOwnedItem($id, $owner_type, $owner_id)
    {
        $this->item->clear();
        $this->item->id = (int)$id;
        if (!$this->item->find() || $this->item->deleted_at !== null
            || (int)$this->item->owner_id !== (int)$owner_id
            || $this->item->owner_type !== $this->normType($owner_type)) {
            return false;
        }
        return true;
    }

    /** Create or edit. $data: owner_type, owner_id, [id], name, category, quantity, condition,
     *  unit_value, location, held_by, held_by_player_id, acquired_date, notes. */
    public function SaveItem($token, $data)
    {
        $mundane_id = $this->authFor($token, $data['owner_type'] ?? '', $data['owner_id'] ?? 0);
        if (!$mundane_id) { return NoAuthorization(); }

        $name      = trim((string)($data['name'] ?? ''));
        $cat       = (string)($data['category'] ?? '');
        $qty       = (int)($data['quantity'] ?? 0);
        $cond      = (string)($data['condition'] ?? 'good');
        $unitValue = round((float)($data['unit_value'] ?? 0), 2);
        $acquired  = (string)($data['acquired_date'] ?? '');

        if ($name === '')                  { return InvalidParameter('Name is required.'); }
        if (!$this->validCategory($cat))   { return InvalidParameter('Unknown category.'); }
        if ($qty < 1)                      { return InvalidParameter('Quantity must be at least 1.'); }
        if (!$this->validCondition($cond)) { return InvalidParameter('Unknown condition.'); }
        if ($acquired !== '' && !preg_match('/^\d{4}-\d{2}-\d{2}$/', $acquired)) {
            return InvalidParameter('Invalid acquired date.');
        }

        $isEdit = !empty($data['id']);
        $before = null;
        if ($isEdit) {
            if (!$this->loadOwnedItem($data['id'], $data['owner_type'], $data['owner_id'])) {
                return InvalidParameter('Item not found.');
            }
            $before = $this->itemToArray();
        } else {
            $this->item->clear();
            $this->item->owner_type = $this->normType($data['owner_type']);
            $this->item->owner_id   = (int)$data['owner_id'];
            $this->item->created_by = $mundane_id;
            $this->item->created_at = date('Y-m-d H:i:s');
            // new items start active
            $this->item->removal_reason = '';
            $this->item->removal_note   = '';
        }
        $this->item->name       = $name;
        $this->item->category   = $cat;
        $this->item->quantity   = $qty;
        $this->item->condition  = $cond;
        $this->item->unit_value = $unitValue;
        // yapo drops null fields; assign '' / 0 to clear an optional column rather than leave it stale.
        $this->item->location   = (string)($data['location'] ?? '');
        $this->item->held_by    = (string)($data['held_by'] ?? '');
        $this->item->held_by_player_id = (isset($data['held_by_player_id']) && (int)$data['held_by_player_id'] > 0)
            ? (int)$data['held_by_player_id'] : 0;
        $this->item->notes      = (string)($data['notes'] ?? '');
        // acquired_date is genuinely nullable in the schema; '' must become NULL.
        $this->item->acquired_date = $acquired !== '' ? $acquired : null;
        if ($isEdit) { $this->item->updated_at = date('Y-m-d H:i:s'); }
        $this->item->save();

        $id = (int)$this->item->id;
        $this->writeAudit($id, $isEdit ? 'edit' : 'create', $mundane_id, $before, $this->itemToArray());
        return Success(['Id' => $id]);
    }

    public function GetItem($token, $owner_type, $owner_id, $id)
    {
        if (!$this->authFor($token, $owner_type, $owner_id)) { return NoAuthorization(); }
        if (!$this->loadOwnedItem($id, $owner_type, $owner_id)) {
            return InvalidParameter('Item not found.');
        }
        return Success($this->itemToArray());
    }
}
