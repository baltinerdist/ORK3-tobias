<?php

class Controller_ArtsSciencesAjax extends Controller
{
    public function __construct($call = null, $id = null)
    {
        parent::__construct($call, $id);
        $this->load_model('ArtsSciences');
    }

    private function respond($payload)
    {
        header('Content-Type: application/json');
        echo json_encode($payload);
        exit;
    }

    private function bail_unauth($detail = 'Not logged in')
    {
        $this->respond(['status' => 5, 'error' => $detail]);
    }

    private function unwrap($r)
    {
        if (!isset($r['Status'])) {
            return ['status' => 1, 'error' => 'Bad response'];
        }
        if ($r['Status'] == 0) {
            return ['status' => 0, 'result' => $r['Detail'] ?? null];
        }
        // F59: null-coalesce Detail so a missing key never raises a PHP 8 "Undefined array key"
        // warning that would corrupt the JSON body. F62: only append Detail to the client-facing
        // message when it is a string; structured (non-string) Detail is internal implementation
        // state — route it to the error/audit log instead of leaking it to the client.
        $error  = $r['Error'] ?? 'Error';
        $detail = $r['Detail'] ?? null;
        if (is_string($detail) && $detail !== '') {
            $error .= ': ' . $detail;
        } elseif ($detail !== null) {
            error_log('AS_AUDIT.detail ' . json_encode(['error' => $r['Error'] ?? 'Error', 'detail' => $detail]));
        }
        return ['status' => (int)$r['Status'], 'error' => $error];
    }

    private function token()
    {
        return $this->session->token ?? '';
    }

    private function require_login()
    {
        if (!isset($this->session->user_id)) {
            $this->bail_unauth();
        }
    }

    // _csrfToken() is inherited (protected) from the base Controller so the emit side
    // (Controller_ArtsSciences / Kingdomnew A&S section -> window.AS_CSRF) and this
    // validation side read the exact same per-session token. Mirrors the CMS pattern.

    // POST-only CSRF gate. Reads the token from the X-CSRF-Token header (preferred) or a
    // csrf_token POST field and compares with hash_equals. GET reads never call this.
    private function require_csrf()
    {
        if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
            return;
        }
        $sent = $_SERVER['HTTP_X_CSRF_TOKEN'] ?? $_POST['csrf_token'] ?? '';
        if (!is_string($sent) || !hash_equals($this->_csrfToken(), $sent)) {
            $this->respond(['status' => 9, 'error' => 'Invalid or expired request token']);
        }
    }

    // F16: persist a destructive-action audit record. Unlike logtrace() (a no-op unless the
    // global TRACE flag is on, and even then only buffered in-memory for the request), this
    // writes to the PHP error log via error_log(), which survives in every real deployment so
    // the security team can grep the trail. Prefixed for easy filtering.
    private function audit_destructive(array $fields)
    {
        $record = array_merge([
            'ts'         => date('c'),
            'ip'         => $_SERVER['REMOTE_ADDR'] ?? '',
            'user_id'    => (int)($this->session->user_id ?? 0),
        ], $fields);
        error_log('AS_AUDIT.destructive ' . json_encode($record));
    }

    // Route: ArtsSciencesAjax/create
    public function create()
    {
        $this->require_login();
        $this->require_csrf();
        $kingdom_id = (int)($_POST['KingdomId'] ?? 0);
        if (!valid_id($kingdom_id)) {
            $this->respond(['status' => 1, 'error' => 'KingdomId required']);
        }
        $req = [
            'Token'             => $this->token(),
            'KingdomId'         => $kingdom_id,
            'EventId'           => $_POST['EventId'] ?? null,
            'Name'              => trim($_POST['Name'] ?? 'Untitled Competition'),
            'Description'       => $_POST['Description'] ?? '',
            'CompetitionDate'   => $_POST['CompetitionDate'] ?? null,
            'EntriesDueAt'      => $_POST['EntriesDueAt']    ?? null,
            'JudgingStartsAt'   => $_POST['JudgingStartsAt'] ?? null,
            'JudgingEndsAt'     => $_POST['JudgingEndsAt']   ?? null,
            'StartDateTime'     => $_POST['StartDateTime']    ?? null,
            'EndDateTime'       => $_POST['EndDateTime']      ?? null,
            'JudgingDeadline'   => $_POST['JudgingDeadline']  ?? null,
            'ScoringMin'        => $_POST['ScoringMin']       ?? 0,
            'ScoringMax'        => $_POST['ScoringMax']       ?? 5,
            'ScoringDefault'    => $_POST['ScoringDefault']   ?? 3,
            'ScoringIncrement'  => $_POST['ScoringIncrement'] ?? 0.5,
            'AggregationMethod' => $_POST['AggregationMethod'] ?? 'average',
            'AnonymousJudging'  => !empty($_POST['AnonymousJudging']) ? 1 : 0,
            'Status'            => $_POST['Status'] ?? 'draft',
        ];
        // F40: idempotency guard — a rapid duplicate submit of the same
        // (KingdomId, Name, CompetitionDate) within a few seconds returns the prior
        // result instead of creating a second identical competition.
        $sig = md5($kingdom_id . '|' . $req['Name'] . '|' . ($req['CompetitionDate'] ?? ''));
        $now = microtime(true);
        $last = $this->session->as_create_guard ?? null;
        if (is_array($last) && ($last['sig'] ?? '') === $sig
            && ($now - ($last['at'] ?? 0)) < 4 && !empty($last['result'])) {
            $this->respond($last['result']);
        }
        $result = $this->unwrap($this->ArtsSciences->create_competition($req));
        if ((int)($result['status'] ?? 1) === 0) {
            $this->session->as_create_guard = ['sig' => $sig, 'at' => $now, 'result' => $result];
        }
        $this->respond($result);
    }

    // Route: ArtsSciencesAjax/kingdom/{kingdom_id}
    public function kingdom($p = null)
    {
        $this->require_login();
        $kingdom_id = (int) preg_replace('/[^0-9]/', '', $p ?? '');
        if (!valid_id($kingdom_id)) {
            $this->respond(['status' => 1, 'error' => 'KingdomId required']);
        }
        // F60: pass Token so the lib auth gate (IsAuthorized) resolves the caller instead of
        // failing closed on an empty token and returning an empty/broken competition list.
        $this->respond($this->unwrap($this->ArtsSciences->list_competitions([
            'Token'     => $this->token(),
            'KingdomId' => $kingdom_id,
        ])));
    }

    // Route: ArtsSciencesAjax/future_events/{kingdom_id}
    // Returns events for the kingdom with at least one calendar detail dated today or later.
    public function future_events($p = null)
    {
        $this->require_login();
        $kingdom_id = (int) preg_replace('/[^0-9]/', '', $p ?? '');
        if (!valid_id($kingdom_id)) {
            $this->respond(['status' => 1, 'error' => 'KingdomId required']);
        }
        // F35: SQL now lives in class.ArtsSciences::FutureEvents (kingdom AUTH_EDIT gated);
        // no inline $DB here.
        $this->respond($this->unwrap($this->ArtsSciences->future_events([
            'Token'     => $this->token(),
            'KingdomId' => $kingdom_id,
        ])));
    }

    // Route: ArtsSciencesAjax/my_entries
    // Returns the caller's OWN recent A&S entries (EntryId, CompetitionName, CompetitionDate,
    // Title, TaxonomyName, Status, Shareable). GET read; the lib scopes rows to the caller via
    // Token, so no competition/kingdom auth gate is needed here.
    public function my_entries($p = null)
    {
        $this->require_login();
        $this->respond($this->unwrap($this->ArtsSciences->get_my_entries($this->token())));
    }

    // Route: ArtsSciencesAjax/my_entry_results/{entry_id}
    // Opt-in results view for one of the caller's OWN entries. The lib enforces ownership +
    // closed status + the competition's share_with_entrants setting and keeps judge identity
    // blind; the action just authenticates and forwards.
    public function my_entry_results($p = null)
    {
        $this->require_login();
        $entry_id = (int) preg_replace('/[^0-9]/', '', $p ?? '');
        if (!valid_id($entry_id)) {
            $this->respond(['status' => 1, 'error' => 'Invalid entry id']);
        }
        $this->respond($this->unwrap($this->ArtsSciences->get_my_entry_results($this->token(), $entry_id)));
    }

    // Route: ArtsSciencesAjax/comp/{competition_id}/{action}
    public function comp($p = null)
    {
        $this->require_login();
        $this->require_csrf();
        $parts = explode('/', $p ?? '');
        $competition_id = (int) preg_replace('/[^0-9]/', '', $parts[0] ?? '');
        $action = strtolower(trim($parts[1] ?? ''));
        if (!valid_id($competition_id)) {
            $this->respond(['status' => 1, 'error' => 'Invalid competition id']);
        }

        $req = ['Token' => $this->token(), 'CompetitionId' => $competition_id];

        // F16: audit destructive dispatches (user, action, target ids) BEFORE they run.
        $destructive = [
            'delete', 'taxonomy.delete', 'criterion.delete', 'participant.delete',
            'judge.delete', 'entry.delete', 'award.delete', 'rec.delete',
            'preset.load_taxonomy', 'preset.load_award',
        ];
        if (in_array($action, $destructive, true)) {
            $targets = [];
            foreach (['TaxonomyId','CriterionId','ParticipantId','JudgeId','EntryId',
                      'AwardId','RecommendationsId','PresetId'] as $tk) {
                if (isset($_POST[$tk])) {
                    $targets[$tk] = (int)$_POST[$tk];
                }
            }
            $this->audit_destructive([
                'action'         => $action,
                'competition_id' => $competition_id,
                'targets'        => $targets,
            ]);
        }

        switch ($action) {
            // Competition itself
            case 'update':
                foreach (['Name','Description','StartDateTime','EndDateTime','JudgingDeadline',
                          'CompetitionDate','EntriesDueAt','JudgingStartsAt','JudgingEndsAt',
                          'ScoringMin','ScoringMax','ScoringDefault','ScoringIncrement',
                          'AggregationMethod','Status','ParkId','EventId'] as $k) {
                    if (array_key_exists($k, $_POST)) {
                        $req[$k] = $_POST[$k];
                    }
                }
                if (array_key_exists('AnonymousJudging', $_POST)) {
                    $req['AnonymousJudging'] = !empty($_POST['AnonymousJudging']);
                }
                $this->respond($this->unwrap($this->ArtsSciences->update_competition($req)));
                return;
            case 'delete':
                $this->respond($this->unwrap($this->ArtsSciences->delete_competition($req)));
                return;
            case 'get':
                $this->respond($this->unwrap($this->ArtsSciences->get_competition($req)));

                // Taxonomy
                return;
            case 'taxonomy.list':
                $this->respond($this->unwrap($this->ArtsSciences->get_taxonomy($req)));
                return;
            case 'taxonomy.save':
                $req['TaxonomyId']  = $_POST['TaxonomyId']  ?? null;
                $req['ParentId']    = $_POST['ParentId']    ?? null;
                $req['Name']        = $_POST['Name']        ?? '';
                $req['Description'] = $_POST['Description'] ?? '';
                if (array_key_exists('Active', $_POST)) {
                    $req['Active'] = $_POST['Active'];
                }
                $this->respond($this->unwrap($this->ArtsSciences->save_taxonomy($req)));
                return;
            case 'taxonomy.delete':
                $req['TaxonomyId'] = $_POST['TaxonomyId'] ?? 0;
                $this->respond($this->unwrap($this->ArtsSciences->delete_taxonomy($req)));
                return;
            case 'taxonomy.reorder':
                $tree = json_decode($_POST['Tree'] ?? '[]', true);
                $req['Tree'] = is_array($tree) ? $tree : [];
                $this->respond($this->unwrap($this->ArtsSciences->reorder_taxonomy($req)));

                // Criteria
                return;
            case 'criterion.list':
                $this->respond($this->unwrap($this->ArtsSciences->get_criteria($req)));
                return;
            case 'criterion.save':
                foreach (['CriterionId','Name','Description','Weight','SortOrder'] as $k) {
                    if (array_key_exists($k, $_POST)) {
                        $req[$k] = $_POST[$k];
                    }
                }
                $this->respond($this->unwrap($this->ArtsSciences->save_criterion($req)));
                return;
            case 'criterion.delete':
                $req['CriterionId'] = $_POST['CriterionId'] ?? 0;
                $this->respond($this->unwrap($this->ArtsSciences->delete_criterion($req)));

                // Participants
                return;
            case 'participant.list':
                $this->respond($this->unwrap($this->ArtsSciences->get_participants($req)));
                return;
            case 'participant.save':
                foreach (['ParticipantId','MundaneId','Persona','ParkId','IsNovice','Notes'] as $k) {
                    if (array_key_exists($k, $_POST)) {
                        $req[$k] = $_POST[$k];
                    }
                }
                $this->respond($this->unwrap($this->ArtsSciences->save_participant($req)));
                return;
            case 'participant.delete':
                $req['ParticipantId'] = $_POST['ParticipantId'] ?? 0;
                $this->respond($this->unwrap($this->ArtsSciences->delete_participant($req)));

                // Judges
                return;
            case 'judge.list':
                $this->respond($this->unwrap($this->ArtsSciences->get_judges($req)));
                return;
            case 'judge.save':
                foreach (['JudgeId','MundaneId','Persona','FieldTaxonomyId'] as $k) {
                    if (array_key_exists($k, $_POST)) {
                        $req[$k] = $_POST[$k];
                    }
                }
                if (array_key_exists('FieldTaxonomyIds', $_POST)) {
                    $req['FieldTaxonomyIds'] = $_POST['FieldTaxonomyIds'];
                }
                $this->respond($this->unwrap($this->ArtsSciences->save_judge($req)));
                return;
            case 'judge.delete':
                $req['JudgeId'] = $_POST['JudgeId'] ?? 0;
                $this->respond($this->unwrap($this->ArtsSciences->delete_judge($req)));

                // Entries
                return;
            case 'entry.list':
                // F20: optional pagination — forward Offset/Limit when present; the lib honors
                // them and falls back to its default window when absent (unchanged behavior).
                foreach (['Offset','Limit'] as $k) {
                    if (array_key_exists($k, $_GET)) {
                        $req[$k] = $_GET[$k];
                    }
                    if (array_key_exists($k, $_POST)) {
                        $req[$k] = $_POST[$k];
                    }
                }
                $this->respond($this->unwrap($this->ArtsSciences->get_entries($req)));
                return;
            case 'entry.save':
                foreach (['EntryId','ParticipantId','TaxonomyId','Title','Description','Documentation','EntryNumber'] as $k) {
                    if (array_key_exists($k, $_POST)) {
                        $req[$k] = $_POST[$k];
                    }
                }
                $this->respond($this->unwrap($this->ArtsSciences->save_entry($req)));
                return;
            case 'entry.delete':
                $req['EntryId'] = $_POST['EntryId'] ?? 0;
                $this->respond($this->unwrap($this->ArtsSciences->delete_entry($req)));

                // Scores
                return;
            case 'score.list':
                // F20: Offset/Limit joined to the existing EntryId/JudgeId filters — forwarded
                // to the lib GetScores when present, otherwise its default window (unchanged).
                foreach (['EntryId','JudgeId','Offset','Limit'] as $k) {
                    if (array_key_exists($k, $_GET)) {
                        $req[$k] = $_GET[$k];
                    }
                }
                foreach (['EntryId','JudgeId','Offset','Limit'] as $k) {
                    if (array_key_exists($k, $_POST)) {
                        $req[$k] = $_POST[$k];
                    }
                }
                $this->respond($this->unwrap($this->ArtsSciences->get_scores($req)));
                return;
            case 'score.save':
                foreach (['EntryId','JudgeId','CriterionId','Score','Feedback'] as $k) {
                    if (array_key_exists($k, $_POST)) {
                        $req[$k] = $_POST[$k];
                    }
                }
                $this->respond($this->unwrap($this->ArtsSciences->save_score($req)));

                // Awards
                return;
            case 'award.list':
                $this->respond($this->unwrap($this->ArtsSciences->get_awards($req)));
                return;
            case 'award.save':
                foreach (['AwardId','Name','Description','AwardType','FieldTaxonomyId','TopN','MinDistinctFields','MinDistinctCategories','NoviceOnly','SortOrder'] as $k) {
                    if (array_key_exists($k, $_POST)) {
                        $req[$k] = $_POST[$k];
                    }
                }
                if (array_key_exists('Rules', $_POST)) {
                    $req['Rules'] = $_POST['Rules'];
                }
                $this->respond($this->unwrap($this->ArtsSciences->save_award($req)));
                return;
            case 'award.delete':
                $req['AwardId'] = $_POST['AwardId'] ?? 0;
                $this->respond($this->unwrap($this->ArtsSciences->delete_award($req)));
                return;
            case 'award.preview':
                $req['Rules'] = $_POST['Rules'] ?? '[]';
                $this->respond($this->unwrap($this->ArtsSciences->preview_award($req)));

                // Award recommendations from the judging form
                return;
            case 'rec.context':
                $req['EntryId'] = $_POST['EntryId'] ?? $_GET['EntryId'] ?? 0;
                $this->respond($this->unwrap($this->ArtsSciences->get_rec_context($req)));
                return;
            case 'rec.save':
                foreach (['EntryId','KingdomAwardId','Rank','Reason'] as $k) {
                    if (array_key_exists($k, $_POST)) {
                        $req[$k] = $_POST[$k];
                    }
                }
                $this->respond($this->unwrap($this->ArtsSciences->save_rec($req)));
                return;
            case 'rec.delete':
                $req['RecommendationsId'] = $_POST['RecommendationsId'] ?? 0;
                $this->respond($this->unwrap($this->ArtsSciences->delete_rec($req)));

                // Results
                return;
            case 'results':
                $this->respond($this->unwrap($this->ArtsSciences->compute_results($req)));

                // Presets (competition-scoped: snapshot from / load into this competition)
                return;
            case 'preset.save_taxonomy':
                $req['KingdomId']  = $_POST['KingdomId']  ?? 0;
                $req['PresetId']   = $_POST['PresetId']   ?? 0;
                $req['Name']       = $_POST['Name']       ?? '';
                $req['Description'] = $_POST['Description'] ?? '';
                $this->respond($this->unwrap($this->ArtsSciences->save_taxonomy_preset($req)));
                return;
            case 'preset.save_award':
                $req['KingdomId']  = $_POST['KingdomId']  ?? 0;
                $req['PresetId']   = $_POST['PresetId']   ?? 0;
                $req['Name']       = $_POST['Name']       ?? '';
                $req['Description'] = $_POST['Description'] ?? '';
                $this->respond($this->unwrap($this->ArtsSciences->save_award_preset($req)));
                return;
            case 'preset.preview':
                $req['PresetId'] = $_POST['PresetId'] ?? 0;
                $req['Type']     = $_POST['Type']     ?? 'taxonomy';
                $this->respond($this->unwrap($this->ArtsSciences->preview_load_preset($req)));
                return;
            case 'preset.load_taxonomy':
                $req['PresetId'] = $_POST['PresetId'] ?? 0;
                $this->respond($this->unwrap($this->ArtsSciences->load_taxonomy_preset($req)));
                return;
            case 'preset.load_award':
                $req['PresetId'] = $_POST['PresetId'] ?? 0;
                $this->respond($this->unwrap($this->ArtsSciences->load_award_preset($req)));
                return;
        }
        $this->respond(['status' => 1, 'error' => 'Unknown action: ' . $action]);
    }


    // Player search with proximity ranking: rows that match the competition's park
    // surface first, then the kingdom, then everyone else. Always returns up to 15 results.
    // URL: index.php?Route=ArtsSciencesAjax/playersearch/{kingdom_id}&q=…&park_id=…
    public function playersearch($p = null)
    {
        $this->require_login();
        $parts = explode('/', $p ?? '');
        $kingdom_id = (int)preg_replace('/[^0-9]/', '', $parts[0] ?? '');
        $park_id    = (int)preg_replace('/[^0-9]/', '', $_GET['park_id'] ?? '');
        $q = trim($_GET['q'] ?? '');
        if (strlen($q) < 2) {
            $this->respond([]);
        }
        // F35 / F47: SQL (with corrected escape order + kingdom-family scoping) now lives in
        // class.ArtsSciences::PlayerSearch (kingdom AUTH_EDIT gated); no inline $DB here.
        $r = $this->ArtsSciences->player_search([
            'Token'     => $this->token(),
            'KingdomId' => $kingdom_id,
            'ParkId'    => $park_id,
            'Query'     => $q,
        ]);
        // This endpoint returns a bare row array (not the {status,...} envelope) to match the
        // kn-ac autocomplete contract; unwrap the class result and emit just the rows.
        $u = $this->unwrap($r);
        $this->respond((int)($u['status'] ?? 1) === 0 && is_array($u['result'] ?? null) ? $u['result'] : []);
    }

    // Route: ArtsSciencesAjax/preset/{kingdom_id}/{action}
    //   action = list | get | delete
    //   POST: Type=taxonomy|award, PresetId (for get/delete)
    public function preset($p = null)
    {
        $this->require_login();
        $this->require_csrf();
        $parts = explode('/', $p ?? '');
        $kingdom_id = (int) preg_replace('/[^0-9]/', '', $parts[0] ?? '');
        $action     = strtolower(trim($parts[1] ?? ''));
        if (!valid_id($kingdom_id)) {
            $this->respond(['status' => 1, 'error' => 'KingdomId required']);
        }
        $req = [
            'Token'     => $this->token(),
            'KingdomId' => $kingdom_id,
            'Type'      => $_POST['Type'] ?? $_GET['Type'] ?? 'taxonomy',
        ];
        // F16: audit destructive preset dispatch before it runs.
        if ($action === 'delete') {
            $this->audit_destructive([
                'action'    => 'preset.delete',
                'kingdom_id' => $kingdom_id,
                'preset_id' => (int)($_POST['PresetId'] ?? 0),
            ]);
        }
        switch ($action) {
            case 'list':
                $this->respond($this->unwrap($this->ArtsSciences->list_presets($req)));
                return;
            case 'get':
                $req['PresetId'] = (int)($_POST['PresetId'] ?? $_GET['PresetId'] ?? 0);
                $this->respond($this->unwrap($this->ArtsSciences->get_preset($req)));
                return;
            case 'delete':
                $req['PresetId'] = (int)($_POST['PresetId'] ?? 0);
                $this->respond($this->unwrap($this->ArtsSciences->delete_preset($req)));
                return;
        }
        $this->respond(['status' => 1, 'error' => 'Unknown preset action: ' . $action]);
    }

}
