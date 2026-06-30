<?php

class ShortLink extends Ork3
{
    /** entity_type => derived-stub prefix */
    private const PREFIX = [
        'player'  => 'pl',
        'kingdom' => 'k',
        'park'    => 'p',
        'unit'    => 'u',
    ];

    /**
     * entity_type => [table, id column, active guard column or null]
     * Table names include the ork_ prefix (matching DB_PREFIX = 'ork_').
     */
    private const ENTITY = [
        'player'  => ['ork_mundane',  'mundane_id',  'active'],
        'kingdom' => ['ork_kingdom',  'kingdom_id',  null],
        'park'    => ['ork_park',     'park_id',     null],
        'unit'    => ['ork_unit',     'unit_id',     'active'],
    ];

    private const RESERVED = [
        'me', 'admin', 'login', 'logout', 'api', 'assets',
        'orkui', 'orkservice', 'index', 'profile', 'search', 'home', 'about',
    ];

    public function __construct()
    {
        parent::__construct();
        $this->shortlink = new yapo($this->db, DB_PREFIX . 'shortlink');
    }

    /**
     * Validate + normalize a candidate custom slug.
     *
     * @return array ['ok' => bool, 'reason' => string, 'slug' => string]
     */
    public function ValidateSlug($slug)
    {
        $slug = strtolower(trim((string)$slug));
        if ($slug === '') {
            return ['ok' => false, 'reason' => 'Enter a shortcut.', 'slug' => $slug];
        }
        // 3–30 chars; must start with a letter; only letters, digits, hyphen, underscore
        if (!preg_match('/^[a-z][a-z0-9_-]{2,29}$/', $slug)) {
            return [
                'ok'     => false,
                'reason' => '3–30 characters: start with a letter; letters, numbers, hyphen, underscore only.',
                'slug'   => $slug,
            ];
        }
        // Reserved derived-stub pattern: pl123, k5, p42, u999
        if (preg_match('/^(pl|k|p|u)\d+$/', $slug)) {
            return [
                'ok'     => false,
                'reason' => 'That looks like a default ID link and is reserved.',
                'slug'   => $slug,
            ];
        }
        if (in_array($slug, self::RESERVED, true)) {
            return ['ok' => false, 'reason' => 'That word is reserved.', 'slug' => $slug];
        }
        return ['ok' => true, 'reason' => '', 'slug' => $slug];
    }

    /**
     * Return the always-on derived stub for an entity, e.g. "pl46193".
     *
     * @return string  '' if type is unknown
     */
    public function DerivedStub($type, $id)
    {
        $type = strtolower($type);
        return isset(self::PREFIX[$type]) ? self::PREFIX[$type] . (int)$id : '';
    }

    /**
     * Resolve a stub to ['type' => ..., 'id' => ...] or false.
     * Derived stubs (pl|k|p|u + digits) are resolved first;
     * custom slugs are looked up in the DB.
     *
     * @return array|false
     */
    public function Resolve($stub)
    {
        $stub = strtolower(trim((string)$stub));
        if ($stub === '') {
            return false;
        }
        // Derived default pattern (pl before p so alternation is unambiguous)
        if (preg_match('/^(pl|k|p|u)(\d+)$/', $stub, $m)) {
            $byPrefix = array_flip(self::PREFIX);
            $type     = $byPrefix[$m[1]];
            $id       = (int)$m[2];
            return $this->EntityExists($type, $id) ? ['type' => $type, 'id' => $id] : false;
        }
        // Custom slug lookup
        $safe = mysql_real_escape_string($stub);
        $sql  = "SELECT entity_type, entity_id FROM " . DB_PREFIX . "shortlink"
              . " WHERE slug = '" . $safe . "' LIMIT 1";
        $r = $this->db->query($sql);
        if ($r !== false && $r->size() > 0 && $r->next()) {
            $type = $r->entity_type;
            $id   = (int)$r->entity_id;
            return $this->EntityExists($type, $id) ? ['type' => $type, 'id' => $id] : false;
        }
        return false;
    }

    /**
     * Return the current custom slug for an entity, or null if it is on the derived default.
     *
     * @return string|null
     */
    public function GetStubFor($type, $id)
    {
        $type = strtolower($type);
        $safe = mysql_real_escape_string($type);
        $sql  = "SELECT slug FROM " . DB_PREFIX . "shortlink"
              . " WHERE entity_type = '" . $safe . "' AND entity_id = " . (int)$id
              . " LIMIT 1";
        $r = $this->db->query($sql);
        if ($r !== false && $r->size() > 0 && $r->next()) {
            return $r->slug;
        }
        return null;
    }

    /**
     * Check whether a slug is available for the given entity.
     * The entity's own current slug counts as available (it already "owns" it).
     *
     * @return array ['available' => bool, 'reason' => string]
     */
    public function CheckAvailability($slug, $type, $id)
    {
        $v = $this->ValidateSlug($slug);
        if (!$v['ok']) {
            return ['available' => false, 'reason' => $v['reason']];
        }
        $slug = $v['slug'];
        $safe = mysql_real_escape_string($slug);
        $sql  = "SELECT entity_type, entity_id FROM " . DB_PREFIX . "shortlink"
              . " WHERE slug = '" . $safe . "' LIMIT 1";
        $r = $this->db->query($sql);
        if ($r !== false && $r->size() > 0 && $r->next()) {
            $ownedBySelf = (strtolower($r->entity_type) === strtolower($type)
                && (int)$r->entity_id === (int)$id);
            if (!$ownedBySelf) {
                return ['available' => false, 'reason' => 'That shortcut is already taken.'];
            }
        }
        return ['available' => true, 'reason' => 'Available'];
    }

    /**
     * Upsert the single custom stub for an entity.
     * Returns Success($slug) on success, InvalidParameter on bad input,
     * ProcessingError if the DB write cannot be confirmed.
     *
     * @return array
     */
    public function SetStub($type, $id, $slug, $mundaneId)
    {
        $type = strtolower($type);
        if (!isset(self::ENTITY[$type]) || !valid_id($id)) {
            return InvalidParameter(null, 'Unknown entity.');
        }
        $avail = $this->CheckAvailability($slug, $type, $id);
        if (!$avail['available']) {
            return InvalidParameter(null, $avail['reason']);
        }
        // Normalize (CheckAvailability already validated; re-normalize for the write)
        $slug = $this->ValidateSlug($slug)['slug'];

        // Clean upsert: find the existing row and update in place, or insert a fresh one
        $this->shortlink->clear();
        $this->shortlink->entity_type = $type;
        $this->shortlink->entity_id   = (int)$id;
        if ($this->shortlink->find()) {
            // Row exists — update slug and auditor in place (PK already loaded by find)
            $this->shortlink->slug       = $slug;
            $this->shortlink->created_by = (int)$mundaneId;
            $this->shortlink->save();
        } else {
            // No row yet — insert
            $this->shortlink->clear();
            $this->shortlink->entity_type = $type;
            $this->shortlink->entity_id   = (int)$id;
            $this->shortlink->slug        = $slug;
            $this->shortlink->created_by  = (int)$mundaneId;
            $this->shortlink->save();
        }

        // Read-back confirmation — lastInsertId() is unreliable under PDO ERRMODE_WARNING
        $confirm = $this->GetStubFor($type, $id);
        if ($confirm !== $slug) {
            return ProcessingError(null, 'Shortcut could not be saved. Try again.');
        }
        return Success($slug);
    }

    /**
     * Remove an entity's custom stub, reverting it to the derived default.
     *
     * @return array Success()
     */
    public function ReleaseStub($type, $id)
    {
        $type = strtolower($type);
        $this->shortlink->clear();
        $this->shortlink->entity_type = $type;
        $this->shortlink->entity_id   = (int)$id;
        if ($this->shortlink->find()) {
            $this->shortlink->delete();
        }
        return Success();
    }

    /**
     * Lightweight existence (and optional active) check for a resolution target.
     *
     * @return bool
     */
    private function EntityExists($type, $id)
    {
        if (!isset(self::ENTITY[$type]) || !valid_id($id)) {
            return false;
        }
        [$table, $idCol, $activeCol] = self::ENTITY[$type];
        $sql = "SELECT $idCol FROM $table WHERE $idCol = " . (int)$id;
        if ($activeCol !== null) {
            $sql .= " AND $activeCol = 1";
        }
        $sql .= " LIMIT 1";
        $r = $this->db->query($sql);
        return ($r !== false && $r->size() > 0);
    }
}
