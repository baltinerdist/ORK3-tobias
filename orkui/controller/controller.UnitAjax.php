<?php

require_once(DIR_CONTROLLER . 'trait.OrgDesignAjax.php');
require_once(DIR_CONTROLLER . 'trait.OrgSocialReveal.php');

/**
 * AJAX endpoints for the Unit "About" customization tools (Mask II).
 *
 * Mirrors Controller_KingdomAjax / Controller_ParkAjax: a single path-routed
 * method (`unit`) dispatches `{unitId}/{action}` to the standardized
 * camelCase actions savedesign / addmilestone / deletemilestone, using the
 * shared OrgDesignAjax trait so all three orgs share one parse -> whitelist ->
 * delegate -> JSON-encode flow (including the ProfanityFilter error branch the
 * old Controller_Unit handlers were missing).
 */
class Controller_UnitAjax extends Controller
{
    use OrgDesignAjax;
    use OrgSocialReveal;

    public function unit($p = null)
    {
        header('Content-Type: application/json');
        $parts   = explode('/', $p ?? '');
        $unit_id = (int)preg_replace('/[^0-9]/', '', $parts[0] ?? '');
        $action  = $parts[1] ?? '';

        // Social link reveal is for anonymous visitors too; it has its own
        // anti-harvest gate (session token, origin, bot UA, rate limit).
        if ($action === 'socialreveal') {
            $this->load_model('Unit');
            $this->org_social_reveal($this->Unit, 'unit_design_social_link', 'unit', $unit_id);
        }

        if (!isset($this->session->user_id)) {
            echo json_encode(['status' => 5, 'error' => 'Not logged in']);
            exit;
        }

        if (!valid_id($unit_id)) {
            echo json_encode(['status' => 1, 'error' => 'Invalid unit ID']);
            exit;
        }

        $this->load_model('Unit');

        if ($action === 'savedesign') {
            $this->org_save_design(
                $this->Unit,
                'set_unit_design',
                'UnitId',
                $unit_id,
                $this->Unit->unit_design_save_fields()
            );
        } elseif ($action === 'addmilestone') {
            $this->org_add_milestone($this->Unit, 'add_unit_milestone', 'UnitId', $unit_id);
        } elseif ($action === 'updatemilestone') {
            $this->org_update_milestone($this->Unit, 'update_unit_milestone', 'UnitId', $unit_id);
        } elseif ($action === 'deletemilestone') {
            $this->org_delete_milestone($this->Unit, 'delete_unit_milestone', 'UnitId', $unit_id);
        } else {
            echo json_encode(['status' => 1, 'error' => 'Unknown action']);
        }
        exit;
    }

    public function __construct($call = null, $id = null)
    {
        parent::__construct();
    }

    public function banner($p = null)
    {
        header('Content-Type: application/json');

        if (!isset($this->session->user_id)) {
            echo json_encode(['status' => 5, 'error' => 'Not logged in']);
            exit;
        }

        $params  = explode('/', $p ?? '');
        $unit_id = (int)preg_replace('/[^0-9]/', '', $params[0] ?? '');
        $action  = $params[1] ?? '';

        if (!valid_id($unit_id)) {
            echo json_encode(['status' => 1, 'error' => 'Invalid Unit ID.']);
            exit;
        }

        $this->load_model('Banner');
        $this->Banner->handle_ajax(
            'Unit',
            $action,
            $unit_id,
            $this->session->token,
            $_POST,
            $_FILES,
        );
    }
}
