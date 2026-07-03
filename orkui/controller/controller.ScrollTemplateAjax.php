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
