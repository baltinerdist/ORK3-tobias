<?php

/**
 * ScrollTemplate — slot-based scroll template store.
 *
 * Mirrors class.ScrollArtwork.php: extends Ork3 (auto-registered as
 * Ork3::$Lib->scrolltemplate by startup.php's convention scan), shares the one
 * global Yapo handle via $this->db, and returns the global Success()/InvalidParameter()
 * envelope (NOT Errors::). Row columns are read as property access ($r->col).
 */
class ScrollTemplate extends Ork3
{
    public function __construct()
    {
        parent::__construct();
    }

    /**
     * Replace {Token} placeholders in $text using $map. Unknown tokens are left
     * verbatim so the UI can flag them. Keys are case-sensitive. Pure/static.
     */
    public static function resolveTokens($text, array $map)
    {
        return preg_replace_callback('/\{([A-Za-z][A-Za-z0-9]*)\}/', function ($m) use ($map) {
            return array_key_exists($m[1], $map) ? $map[$m[1]] : $m[0];
        }, (string)$text);
    }

    /**
     * Create a template. Returns ['Status'=>Success(), 'TemplateId'=>int] or
     * ['Status'=>InvalidParameter(...)].
     */
    public function create($req)
    {
        $name = trim($req['Name'] ?? '');
        if ($name === '') {
            return array('Status' => InvalidParameter(null, 'Name is required.'));
        }
        $orientation = in_array($req['Orientation'] ?? '', array('portrait', 'landscape'), true) ? $req['Orientation'] : 'portrait';
        $bgType = in_array($req['BgType'] ?? '', array('color', 'texture', 'image'), true) ? $req['BgType'] : 'color';

        $this->db->Clear();
        $this->db->kingdom_id  = ($req['KingdomId'] ?? null) ? (int)$req['KingdomId'] : null;
        $this->db->name        = $name;
        $this->db->orientation = $orientation;
        $this->db->bg_type     = $bgType;
        $this->db->bg_value    = (string)($req['BgValue'] ?? '#ffffff');
        $this->db->slots       = json_encode(array_values($req['Slots'] ?? array()));
        $this->db->zones       = json_encode(array_values($req['Zones'] ?? array()));
        $this->db->is_starter  = !empty($req['IsStarter']) ? 1 : 0;
        $this->db->created_by  = (int)($req['CreatedBy'] ?? 0);
        $cols = array('kingdom_id', 'name', 'orientation', 'bg_type', 'bg_value', 'slots', 'zones', 'is_starter', 'created_by');
        $ph = array_map(function ($c) {
            return ':' . $c;
        }, $cols);
        $sql = "INSERT INTO " . DB_PREFIX . "scroll_template (" . implode(', ', $cols) . ") VALUES (" . implode(', ', $ph) . ")";
        $this->db->Execute($sql);
        return array('Status' => Success(), 'TemplateId' => (int)$this->db->GetLastInsertId());
    }

    /**
     * Fetch a template by id. slots/zones are decoded to arrays.
     */
    public function get($id)
    {
        $this->db->Clear();
        $this->db->scroll_template_id = (int)$id;
        $sql = "SELECT * FROM " . DB_PREFIX . "scroll_template WHERE scroll_template_id = :scroll_template_id";
        $r = $this->db->DataSet($sql);
        if ($r->Size() > 0 && $r->Next()) {
            return array('Template' => $this->format_row($r), 'Status' => Success());
        }
        return array('Status' => InvalidParameter(null, 'Template not found.'));
    }

    /**
     * Shared starters (is_starter=1) plus the given kingdom's active templates.
     */
    public function listForKingdom($kingdomId)
    {
        $this->db->Clear();
        $this->db->kingdom_id = (int)$kingdomId;
        $sql = "SELECT * FROM " . DB_PREFIX . "scroll_template
			WHERE status = 'active' AND (is_starter = 1 OR kingdom_id = :kingdom_id)
			ORDER BY is_starter DESC, name ASC";
        $r = $this->db->DataSet($sql);
        $out = array();
        while ($r->Next()) {
            $out[] = $this->format_row($r);
        }
        return array('Templates' => $out, 'Status' => Success());
    }

    /**
     * Update an existing template's editable fields.
     */
    public function update($id, $req)
    {
        $this->db->Clear();
        $this->db->scroll_template_id = (int)$id;
        $this->db->name        = trim($req['Name'] ?? '');
        $this->db->orientation = in_array($req['Orientation'] ?? '', array('portrait', 'landscape'), true) ? $req['Orientation'] : 'portrait';
        $this->db->bg_type     = in_array($req['BgType'] ?? '', array('color', 'texture', 'image'), true) ? $req['BgType'] : 'color';
        $this->db->bg_value    = (string)($req['BgValue'] ?? '#ffffff');
        $this->db->slots       = json_encode(array_values($req['Slots'] ?? array()));
        $this->db->zones       = json_encode(array_values($req['Zones'] ?? array()));
        $sql = "UPDATE " . DB_PREFIX . "scroll_template SET name = :name, orientation = :orientation,
			bg_type = :bg_type, bg_value = :bg_value, slots = :slots, zones = :zones
			WHERE scroll_template_id = :scroll_template_id";
        $this->db->Execute($sql);
        return array('Status' => Success());
    }

    /**
     * Soft delete: archive the template.
     */
    public function delete($id)
    {
        $this->db->Clear();
        $this->db->scroll_template_id = (int)$id;
        $sql = "UPDATE " . DB_PREFIX . "scroll_template SET status = 'archived' WHERE scroll_template_id = :scroll_template_id";
        $this->db->Execute($sql);
        return array('Status' => Success());
    }

    /**
     * Normalize a DB row into the public shape (slots/zones decoded).
     */
    private function format_row($r)
    {
        return array(
            'scroll_template_id' => (int)$r->scroll_template_id,
            'kingdom_id'  => $r->kingdom_id !== null ? (int)$r->kingdom_id : null,
            'name'        => $r->name,
            'orientation' => $r->orientation,
            'bg_type'     => $r->bg_type,
            'bg_value'    => $r->bg_value,
            'slots'       => json_decode($r->slots ?? '[]', true) ?: array(),
            'zones'       => json_decode($r->zones ?? '[]', true) ?: array(),
            'is_starter'  => (int)$r->is_starter,
        );
    }
}
