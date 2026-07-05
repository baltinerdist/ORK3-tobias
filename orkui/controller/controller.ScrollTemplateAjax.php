<?php

class Controller_ScrollTemplateAjax extends Controller
{
    /**
     * The ScrollTemplate backend instance.
     * Loaded automatically by startup.php as Ork3::$Lib->scrolltemplate.
     */
    private $st;

    public function __construct($call = null, $id = null)
    {
        parent::__construct($call, $id);
        $this->st = Ork3::$Lib->scrolltemplate;
    }

    // ================================================================
    //  Helpers
    // ================================================================

    /**
     * Send a JSON response and exit.
     */
    private function json_response($data)
    {
        header('Content-Type: application/json');
        echo json_encode($data);
        exit;
    }

    /**
     * Require a logged-in user. Returns user_id or exits with JSON error.
     */
    private function require_login()
    {
        if (!isset($this->session->user_id)) {
            $this->json_response(array('Status' => 5, 'Message' => 'Not logged in.'));
        }
        return (int)$this->session->user_id;
    }

    /**
     * Resolve the authenticated user's mundane id (auth subject).
     */
    private function mundane()
    {
        return (int)Ork3::$Lib->authorization->IsAuthorized($this->session->token ?? '');
    }

    /**
     * Gate: kingdom officer (AUTH_KINGDOM/AUTH_EDIT) over $kingdom_id, or ORK
     * admin (AUTH_ADMIN) for shared starters (kingdom_id null). Returns the
     * mundane_id or exits with a JSON error.
     */
    private function require_kingdom_edit($kingdom_id)
    {
        $mundane_id = $this->mundane();
        if ($mundane_id <= 0) {
            $this->json_response(array('Status' => 5, 'Message' => 'Authorization failed.'));
        }
        $ok = $kingdom_id
            ? Ork3::$Lib->authorization->HasAuthority($mundane_id, AUTH_KINGDOM, (int)$kingdom_id, AUTH_EDIT)
            : Ork3::$Lib->authorization->HasAuthority($mundane_id, AUTH_ADMIN, 0, AUTH_EDIT);
        if (!$ok) {
            $this->json_response(array('Status' => 5, 'Message' => 'Kingdom officer privileges required.'));
        }
        return $mundane_id;
    }

    /**
     * Resolve the kingdom-id set a heraldry picker may search within.
     * - template kingdom_id > 0: officer (or admin) over that kingdom -> the
     *   kingdom + its child principalities (GetFamilyKingdomIds).
     * - template kingdom_id 0 (shared starter): ORK admins only, global.
     * Returns array('global'=>bool, 'ids'=>int[]) or null when unauthorized.
     */
    private function heraldryScope($kingdomId)
    {
        $mid = $this->mundane();
        if ($mid <= 0) {
            return null;
        }
        $isAdmin = Ork3::$Lib->authorization->HasAuthority($mid, AUTH_ADMIN, 0, AUTH_EDIT);
        if ($kingdomId > 0) {
            if ($isAdmin || Ork3::$Lib->authorization->HasAuthority($mid, AUTH_KINGDOM, $kingdomId, AUTH_EDIT)) {
                return array('global' => false, 'ids' => array_map('intval', Ork3::$Lib->kingdom->GetFamilyKingdomIds($kingdomId)));
            }
            return null;
        }
        return $isAdmin ? array('global' => true, 'ids' => array()) : null;
    }

    /** All active kingdom ids (for global admin park search). */
    private function allKingdomIds()
    {
        $ids = array();
        foreach (Ork3::$Lib->kingdom->GetKingdoms(array())['Kingdoms'] ?? array() as $k) {
            $ids[] = (int)$k['KingdomId'];
        }
        return $ids;
    }

    // ================================================================
    //  GET /ScrollTemplateAjax/heraldrykingdoms&kingdom_id=
    //  Scoped kingdom list (id, name, heraldry url) for the picker.
    // ================================================================
    public function heraldrykingdoms($id = null)
    {
        $this->require_login();
        $scope = $this->heraldryScope((int)($_GET['kingdom_id'] ?? 0));
        if ($scope === null) {
            $this->json_response(array('Status' => 5, 'Kingdoms' => array()));
        }
        $rows = array();
        foreach (Ork3::$Lib->kingdom->GetKingdoms(array())['Kingdoms'] ?? array() as $k) {
            $kid = (int)$k['KingdomId'];
            if (!$scope['global'] && !in_array($kid, $scope['ids'], true)) {
                continue;
            }
            $rows[] = array(
                'id'   => $kid,
                'name' => $k['KingdomName'],
                'url'  => Ork3::$Lib->heraldry->GetHeraldryUrl(array('Type' => 'Kingdom', 'Id' => $kid))['Url'],
            );
        }
        usort($rows, function ($a, $b) {
            return strcasecmp($a['name'], $b['name']);
        });
        $this->json_response(array('Status' => 0, 'Kingdoms' => $rows));
    }

    // ================================================================
    //  GET /ScrollTemplateAjax/heraldryparks&kingdom_id=&q=
    //  Scoped park name-search (id, name, kingdom, heraldry url).
    // ================================================================
    public function heraldryparks($id = null)
    {
        $this->require_login();
        $q = trim($_GET['q'] ?? '');
        $scope = $this->heraldryScope((int)($_GET['kingdom_id'] ?? 0));
        if ($scope === null) {
            $this->json_response(array('Status' => 5, 'Parks' => array()));
        }
        $ids = $scope['global'] ? $this->allKingdomIds() : $scope['ids'];
        if (!count($ids)) {
            $this->json_response(array('Status' => 0, 'Parks' => array()));
        }
        $rows = array();
        foreach (Ork3::$Lib->kingdom->GetParks(array('KingdomIds' => $ids))['Parks'] ?? array() as $p) {
            $name = $p['Name'] ?? '';
            if ($q !== '' && stripos($name, $q) === false) {
                continue;
            }
            $pid = (int)($p['ParkId'] ?? 0);
            $rows[] = array(
                'id'      => $pid,
                'name'    => $name,
                'kingdom' => $p['KingdomName'] ?? ($p['Kingdom'] ?? ''),
                'url'     => Ork3::$Lib->heraldry->GetHeraldryUrl(array('Type' => 'Park', 'Id' => $pid))['Url'],
            );
            if (count($rows) >= 20) {
                break;
            }
        }
        $this->json_response(array('Status' => 0, 'Parks' => $rows));
    }

    // ================================================================
    //  GET /ScrollTemplateAjax/heraldryresolve&type=&eid=
    //  Resolve a single entity's heraldry url (used after a player pick,
    //  reusing KingdomAjax/playersearch for the search itself).
    // ================================================================
    public function heraldryresolve($id = null)
    {
        $this->require_login();
        $type = ucfirst(strtolower(trim($_GET['type'] ?? '')));
        $eid  = (int)($_GET['eid'] ?? 0);
        if (!in_array($type, array('Kingdom', 'Park', 'Player'), true) || $eid <= 0) {
            $this->json_response(array('Status' => 1, 'Url' => ''));
        }
        $url = Ork3::$Lib->heraldry->GetHeraldryUrl(array('Type' => $type, 'Id' => $eid))['Url'];
        $this->json_response(array('Status' => 0, 'Url' => $url));
    }

    // ================================================================
    //  GET /ScrollTemplateAjax/list?kingdom_id=
    // ================================================================

    /**
     * List shared starters + the given kingdom's active templates.
     *
     * GET params: kingdom_id
     *
     * Returns JSON: {Status, Templates}
     */
    public function list($id = null)
    {
        $this->require_login();
        $result = $this->st->listForKingdom((int)($_GET['kingdom_id'] ?? 0));
        $this->json_response(array('Status' => 0, 'Templates' => $result['Templates'] ?? array()));
    }

    // ================================================================
    //  GET /ScrollTemplateAjax/load?id=
    // ================================================================

    /**
     * Load a single template by id.
     *
     * GET params: id
     *
     * Returns JSON: {Status, Template}
     */
    public function load($id = null)
    {
        $this->require_login();
        $result = $this->st->get((int)($_GET['id'] ?? 0));
        if (($result['Status']['Status'] ?? 1) != 0) {
            $this->json_response(array('Status' => 1, 'Message' => 'Not found.'));
        }
        $this->json_response(array('Status' => 0, 'Template' => $result['Template']));
    }

    // ================================================================
    //  POST /ScrollTemplateAjax/save
    // ================================================================

    /**
     * Create (no id) or update (id present) a template. Requires AUTH_KINGDOM
     * edit authority over the target kingdom; shared starters require AUTH_ADMIN.
     *
     * POST body (JSON): id?, kingdom_id, name, orientation, bg_type, bg_value,
     *                   slots, zones, is_starter
     *
     * Returns JSON: {Status, TemplateId}
     */
    public function save($id = null)
    {
        $this->require_login();
        $body = json_decode(file_get_contents('php://input'), true) ?: array();
        $kingdom_id = ($body['kingdom_id'] ?? null) ? (int)$body['kingdom_id'] : null;
        $mundane_id = $this->require_kingdom_edit($kingdom_id);

        $request = array(
            'KingdomId'   => $kingdom_id,
            'Name'        => $body['name'] ?? '',
            'Orientation' => $body['orientation'] ?? 'portrait',
            'BgType'      => $body['bg_type'] ?? 'color',
            'BgValue'     => $body['bg_value'] ?? '#ffffff',
            'Slots'       => $body['slots'] ?? array(),
            'Zones'       => $body['zones'] ?? array(),
            'AwardKeys'   => $body['award_keys'] ?? array(),
            'IsStarter'   => !empty($body['is_starter']) ? 1 : 0,
            'CreatedBy'   => $mundane_id,
        );

        if (!empty($body['id'])) {
            $this->st->update((int)$body['id'], $request);
            $this->json_response(array('Status' => 0, 'TemplateId' => (int)$body['id']));
        }

        $result = $this->st->create($request);
        if (is_array($result['Status'] ?? null) && ($result['Status']['Status'] ?? 1) == 0) {
            $this->json_response(array('Status' => 0, 'TemplateId' => $result['TemplateId'] ?? 0));
        }

        $detail = is_array($result['Status'] ?? null)
            ? ($result['Status']['Detail'] ?? $result['Status']['Error'] ?? 'Save failed.')
            : 'Save failed.';
        $this->json_response(array('Status' => 1, 'Message' => $detail));
    }

    // ================================================================
    //  POST /ScrollTemplateAjax/remove
    // ================================================================

    /**
     * Soft-delete (archive) a template. Requires the same authority as the
     * template's owning kingdom (or AUTH_ADMIN for shared starters).
     *
     * POST body (JSON): id
     *
     * Returns JSON: {Status}
     */
    public function remove($id = null)
    {
        $this->require_login();
        $body = json_decode(file_get_contents('php://input'), true) ?: array();
        $template_id = (int)($body['id'] ?? 0);

        $existing = $this->st->get($template_id);
        if (($existing['Status']['Status'] ?? 1) != 0) {
            $this->json_response(array('Status' => 1, 'Message' => 'Not found.'));
        }
        $kingdom_id = $existing['Template']['kingdom_id'] ?? null;
        $this->require_kingdom_edit($kingdom_id);

        $this->st->delete($template_id);
        $this->json_response(array('Status' => 0));
    }

}
