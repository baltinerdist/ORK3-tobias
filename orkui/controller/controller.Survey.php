<?php

/**
 * Controller_Survey — survey module page routes (spec §5, §7).
 *
 * Route=Survey/index[/Kingdom|Park/{id}]  survey list for a scope
 * Route=Survey/build/{id}                 builder
 * Route=Survey/take/{id}[/preview]        runner
 * Route=Survey/s/{slug}                   runner, resolved by share slug
 * Route=Survey/results/{id}               reporting
 * Route=Survey/export/{id}?filters=<json> CSV download
 *
 * Every structural mutation lives in Controller_SurveyAjax; this controller
 * only renders pages and gates them with Model_Survey::can_manage().
 */
class Controller_Survey extends Controller
{
    public function __construct($call = null, $id = null)
    {
        parent::__construct($call, $id);
        $this->load_model('Survey');
        // Every survey page posts to SurveyAjax, whose mutations require this
        // token in X-CSRF-Token (the templates hand it to SvConfig.csrf).
        $this->data['SurveyCsrf'] = $this->Survey->csrf_token();
    }

    private function uid(): int
    {
        return isset($this->session->user_id) ? (int) $this->session->user_id : 0;
    }

    // -----------------------------------------------------------------------
    // index — manageable surveys list, optionally scoped to one org
    // Route: Survey/index, Survey/index/Kingdom/17, Survey/index/Park/1049
    // -----------------------------------------------------------------------
    public function index($scope = null)
    {
        $uid = $this->uid();

        $parts     = explode('/', trim((string) $scope, '/'));
        $scopeType = null;
        $scopeId   = null;
        if (isset($parts[0]) && in_array($parts[0], ['Kingdom', 'Park'], true)) {
            $scopeType = strtolower($parts[0]);
            $scopeId   = (int) preg_replace('/[^0-9]/', '', $parts[1] ?? '');
        }

        $scopes = $this->Survey->manageable_scopes($uid);
        if (empty($scopes)) {
            $this->no_authorization('', 'You do not have permission to manage any surveys.');
            return;
        }

        // The picker list (manageable_scopes) only carries active kingdoms/parks,
        // so deriving the label from it left a blank scope chip for a retired org
        // or a hand-typed/bookmarked scope. scope_name() answers from
        // ork_kingdom/ork_park regardless of active.
        $scopeName = 'All of Amtgard';
        if ($scopeType !== null) {
            $scopeName = $this->Survey->scope_name($scopeType, $scopeId);
            if ($scopeName === '') {
                $scopeName = ucfirst($scopeType) . ' not found';
            }
        }

        $this->data['Surveys']    = $this->Survey->list_manageable($uid, $scopeType, $scopeId);
        $this->data['Scopes']     = $scopes;
        $this->data['ScopeType']  = $scopeType;
        $this->data['ScopeId']    = $scopeId;
        $this->data['ScopeName']  = $scopeName;
        $this->data['IsOrkAdmin'] = $this->Survey->is_ork_admin($uid);
    }

    // -----------------------------------------------------------------------
    // build — survey builder
    // Route: Survey/build/{id}
    // -----------------------------------------------------------------------
    public function build($id = null)
    {
        $uid      = $this->uid();
        $surveyId = (int) preg_replace('/[^0-9]/', '', (string) $id);

        $row = $this->Survey->get_row($surveyId);
        if ($row === null) {
            $this->data['Error'] = 'Survey not found.';
            return;
        }
        if (!$this->Survey->can_manage($uid, $row)) {
            $this->no_authorization('', 'You do not have permission to manage this survey.');
            return;
        }

        $result = $this->Survey->get($surveyId);
        if ((int) ($result['Status'] ?? 1) !== 0) {
            $this->data['Error'] = $result['Error'] ?? 'Survey not found.';
            return;
        }

        $this->data['Survey']   = $result;
        $this->data['SurveyId'] = $surveyId;
    }

    // -----------------------------------------------------------------------
    // take — survey runner
    // Route: Survey/take/{id}, Survey/take/{id}/preview
    // -----------------------------------------------------------------------
    public function take($p = null)
    {
        $uid = $this->uid();
        if ($uid <= 0) {
            $this->no_authorization('Survey/take/' . ltrim((string) $p, '/'));
            return;
        }

        $parts    = explode('/', trim((string) $p, '/'));
        $surveyId = (int) preg_replace('/[^0-9]/', '', $parts[0] ?? '');
        $preview  = isset($parts[1]) && $parts[1] === 'preview';

        $row = $this->Survey->get_row($surveyId);
        if ($row === null) {
            $this->data['Error'] = 'Survey not found.';
            return;
        }
        $canManage = $this->Survey->can_manage($uid, $row);
        if ($preview && !$canManage) {
            $this->no_authorization('', 'You do not have permission to preview this survey.');
            return;
        }

        $this->data['SurveyId']   = $surveyId;
        $this->data['IsPreview']  = $preview;
        $this->data['CanManage']  = $canManage;
    }

    // -----------------------------------------------------------------------
    // s — runner resolved by share slug
    // Route: Survey/s/{slug}
    // -----------------------------------------------------------------------
    public function s($slug = null)
    {
        $uid = $this->uid();
        if ($uid <= 0) {
            $this->no_authorization('Survey/s/' . ltrim((string) $slug, '/'));
            return;
        }

        $row = $this->Survey->get_by_slug((string) $slug);
        if ($row === null) {
            $this->data['Error'] = 'Survey not found.';
            return;
        }

        $this->data['SurveyId']  = (int) $row['survey_id'];
        $this->data['IsPreview'] = false;
        $this->data['CanManage'] = $this->Survey->can_manage($uid, $row);
        $this->template          = 'Survey_take.tpl';
    }

    // -----------------------------------------------------------------------
    // results — reporting
    // Route: Survey/results/{id}
    // -----------------------------------------------------------------------
    public function results($id = null)
    {
        $uid      = $this->uid();
        $surveyId = (int) preg_replace('/[^0-9]/', '', (string) $id);

        $row = $this->Survey->get_row($surveyId);
        if ($row === null) {
            $this->data['Error'] = 'Survey not found.';
            return;
        }
        if (!$this->Survey->can_manage($uid, $row)) {
            $this->no_authorization('', 'You do not have permission to view results for this survey.');
            return;
        }

        $result = $this->Survey->get($surveyId);

        // The kingdom filter offers only kingdoms that actually appear in this
        // survey's responses, with counts (#33) — not every kingdom the viewer
        // manages. scope_type/scope_id are kept as aliases of kingdom_id so the
        // existing template keeps rendering until it reads kingdom_id/count.
        $kingdoms = [];
        foreach ($this->Survey->kingdoms_present($surveyId) as $k) {
            $k['scope_type'] = 'kingdom';
            $k['scope_id']   = (int) $k['kingdom_id'];
            $kingdoms[]      = $k;
        }

        $this->data['SurveyId']  = $surveyId;
        $this->data['Survey']    = $result;
        $this->data['Kingdoms']  = $kingdoms;
        $this->data['Questions'] = $result['Questions'] ?? [];
    }

    // -----------------------------------------------------------------------
    // export — CSV download of the filtered rows
    // Route: Survey/export/{id}?filters=<json>
    // -----------------------------------------------------------------------
    public function export($id = null)
    {
        $uid      = $this->uid();
        $surveyId = (int) preg_replace('/[^0-9]/', '', (string) $id);

        $row = $this->Survey->get_row($surveyId);
        if ($row === null) {
            $this->data['Error'] = 'Survey not found.';
            return;
        }
        if (!$this->Survey->can_manage($uid, $row)) {
            if ($uid > 0) {
                // A CSV route should not answer 200 with an HTML page to a scripted client.
                http_response_code(403);
            }
            $this->no_authorization('', 'You do not have permission to export this survey.');
            return;
        }

        $filters = [];
        if (isset($_GET['filters'])) {
            $decoded = json_decode((string) $_GET['filters'], true);
            $filters = is_array($decoded) ? $decoded : [];
        }
        $filters = $this->Survey->normalize_filters($filters);

        // Audit every export that can carry identity or demographics (#6); an
        // anonymous-only export carries neither.
        if ($filters['consent'] !== 'anonymous') {
            $this->Survey->log_activity($surveyId, 'export', $filters);
        }

        header('Content-Type: text/csv; charset=utf-8');
        header('Content-Disposition: attachment; filename="survey-' . $surveyId . '.csv"');
        header('Cache-Control: no-cache, must-revalidate');
        header('X-Content-Type-Options: nosniff');

        // Stream each 500-row batch as it is built (#42) rather than holding
        // the whole file in memory. Drop any output buffers first so flush()
        // actually reaches the client and stray buffered output cannot
        // corrupt the CSV. Release the session lock too, so a long export does
        // not block the viewer's other tabs.
        while (ob_get_level() > 0) {
            ob_end_clean();
        }
        session_write_close();
        $this->Survey->csv_stream($surveyId, $filters, function (string $chunk): void {
            echo $chunk;
            flush();
        });
        exit();
    }
}
