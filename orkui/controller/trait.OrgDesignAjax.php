<?php

/**
 * Shared handlers for the org-design / milestone AJAX endpoints used by the
 * Kingdom, Park, and Unit "About" customization tools (Mask II).
 *
 * The parse -> whitelist -> delegate -> JSON-encode flow (including the
 * ProfanityFilter error-shape branch) was duplicated verbatim across
 * Controller_KingdomAjax, Controller_ParkAjax, and (with one missing branch)
 * Controller_Unit. This trait is the single source of truth; each *Ajax
 * controller supplies only what differs: its model object, the org id field
 * name (KingdomId / ParkId / UnitId), the org id value, and the save-field
 * list -- which it reads from its model, NOT from a literal of its own.
 *
 * Validation rules are deliberately absent here: they belong to the domain
 * (system/lib/ork3/trait.OrgDesign.php), which owns the length, date, and
 * profanity checks. These handlers marshal params and render the answer.
 *
 * Every method echoes the standard JSON response and exits, matching the
 * pre-refactor behavior exactly.
 */
trait OrgDesignAjax
{
    /**
     * Echo the standard JSON result for a design-save or milestone-add call,
     * promoting a ProfanityFilter rejection to the {status,error,field} shape
     * (error = the raw filter message, field = the offending field name).
     *
     * @param array      $r     The model response (Status/Error/Detail).
     * @param array|null $extra Extra keys to merge into a success ({status:0}) response.
     */
    private function org_design_emit(array $r, ?array $extra = null): void
    {
        require_once(DIR_LIB . 'ork3/class.ProfanityFilter.php');
        $isProf = ($r['Status'] != 0 && ($r['Error'] ?? '') === ProfanityFilter::ERROR_MESSAGE);
        if ($r['Status'] == 0) {
            echo json_encode(['status' => 0] + (array)$extra);
        } elseif ($isProf) {
            echo json_encode(['status' => $r['Status'], 'error' => $r['Error'], 'field' => $r['Detail'] ?? '']);
        } else {
            echo json_encode([
                'status' => $r['Status'],
                'error'  => rtrim(($r['Error'] ?? 'Error') . ': ' . ($r['Detail'] ?? ''), ': '),
                'field'  => $r['Detail'] ?? '',
            ]);
        }
        exit;
    }

    /**
     * Save an org's About/design config.
     *
     * @param object $model       The loaded org model (e.g. $this->Kingdom).
     * @param string $modelMethod Pass-through method name (set_kingdom_design ...).
     * @param string $idField     Org id key for the payload (KingdomId/ParkId/UnitId).
     * @param int    $orgId       Org id value.
     * @param array  $whitelist   Fields this org accepts, from <model>_design_save_fields().
     */
    protected function org_save_design(object $model, string $modelMethod, string $idField, int $orgId, array $whitelist): void
    {
        $payload = ['Token' => $this->session->token, $idField => $orgId];
        foreach ($whitelist as $f) {
            if (array_key_exists($f, $_POST)) {
                $payload[$f] = (string)$_POST[$f];
            }
        }
        $r = $model->$modelMethod($payload);
        $this->org_design_emit($r);
    }

    /**
     * Add a custom milestone to an org.
     *
     * @param object $model       The loaded org model.
     * @param string $modelMethod Pass-through method name (add_kingdom_milestone ...).
     * @param string $idField     Org id key for the payload.
     * @param int    $orgId       Org id value.
     */
    protected function org_add_milestone(object $model, string $modelMethod, string $idField, int $orgId): void
    {
        // Description/date/icon rules live in the domain (AddDesignMilestone),
        // which also applies the length + profanity checks a controller copy
        // would miss. Marshal the params and let it answer.
        $r = $model->$modelMethod([
            'Token'         => $this->session->token,
            $idField        => $orgId,
            'Icon'          => trim($_POST['Icon']          ?? ''),
            'Description'   => trim($_POST['Description']   ?? ''),
            'MilestoneDate' => trim($_POST['MilestoneDate'] ?? ''),
        ]);
        $this->org_design_emit($r, ['milestoneId' => (int)($r['Detail'] ?? 0)]);
    }

    /**
     * Update an existing custom milestone on an org.
     *
     * @param object $model       The loaded org model.
     * @param string $modelMethod Pass-through method name (update_kingdom_milestone ...).
     * @param string $idField     Org id key for the payload.
     * @param int    $orgId       Org id value.
     */
    protected function org_update_milestone(object $model, string $modelMethod, string $idField, int $orgId): void
    {
        // Same as org_add_milestone: UpdateDesignMilestone owns the rules.
        $r = $model->$modelMethod([
            'Token'         => $this->session->token,
            $idField        => $orgId,
            'MilestoneId'   => (int)($_POST['MilestoneId'] ?? 0),
            'Icon'          => trim($_POST['Icon']          ?? ''),
            'Description'   => trim($_POST['Description']   ?? ''),
            'MilestoneDate' => trim($_POST['MilestoneDate'] ?? ''),
        ]);
        $this->org_design_emit($r);
    }

    /**
     * Delete a custom milestone from an org.
     *
     * @param object $model       The loaded org model.
     * @param string $modelMethod Pass-through method name (delete_kingdom_milestone ...).
     * @param string $idField     Org id key for the payload.
     * @param int    $orgId       Org id value.
     */
    protected function org_delete_milestone(object $model, string $modelMethod, string $idField, int $orgId): void
    {
        $milestone_id = (int)($_POST['MilestoneId'] ?? 0);
        if (!valid_id($milestone_id)) {
            echo json_encode(['status' => 1, 'error' => 'Invalid milestone ID.', 'field' => '']);
            exit;
        }
        $r = $model->$modelMethod([
            'Token'       => $this->session->token,
            $idField      => $orgId,
            'MilestoneId' => $milestone_id,
        ]);
        $this->org_design_emit($r);
    }
}
