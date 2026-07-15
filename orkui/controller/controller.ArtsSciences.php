<?php

class Controller_ArtsSciences extends Controller
{
    public function __construct($call = null, $id = null)
    {
        parent::__construct($call, $id);
        $this->load_model('Kingdom');
        $this->load_model('Award');
    }

    public function index($kingdom_id = null)
    {
        // F3: require login — kills anonymous kingdom enumeration.
        $uid = (int)($this->session->user_id ?? 0);
        if ($uid <= 0) {
            header('Location: ' . UIR . 'Login/login');
            exit;
        }

        $kingdom_id = (int) preg_replace('/[^0-9]/', '', (string)$kingdom_id);
        if (!$kingdom_id) {
            header('Location: ' . UIR);
            exit;
        }

        // F34: drop stale cached kingdom identity when switching kingdoms (mirror Controller_Kingdom).
        if (($this->session->kingdom_id ?? null) != $kingdom_id) {
            unset($this->session->kingdom_name);
            unset($this->session->park_id);
            unset($this->session->park_name);
        }
        $this->session->kingdom_id = $kingdom_id;
        if (!isset($this->session->kingdom_name)) {
            $this->session->kingdom_name = $this->Kingdom->get_kingdom_name($kingdom_id);
        }
        $kn = $this->session->kingdom_name;

        $this->template = '../revised-frontend/ArtsSciences_index.tpl';
        $this->data['page_title']     = 'A&S Competitions — ' . $kn;
        $this->data['kingdom_id']     = $kingdom_id;
        $this->data['kingdom_name']   = $kn;
        $this->data['menu']['kingdom'] = ['url' => UIR . 'Kingdom/profile/' . $kingdom_id, 'display' => $kn];
        $this->data['menu']['as']     = ['url' => UIR . 'ArtsSciences/index/' . $kingdom_id, 'display' => 'Arts &amp; Sciences'];

        $this->data['can_manage'] = $uid > 0 && Ork3::$Lib->authorization->HasAuthority($uid, AUTH_KINGDOM, $kingdom_id, AUTH_EDIT);

        // CSRF token for A&S mutating fetch() calls.
        $this->data['AsCsrf'] = $this->_csrfToken();

        $resp = $this->ArtsSciences->list_competitions(['KingdomId' => $kingdom_id, 'Token' => $this->session->token]);
        $this->data['competitions'] = (isset($resp['Status']) && $resp['Status'] == 0) ? ($resp['Detail'] ?? []) : [];
    }

    public function competition($competition_id = null)
    {
        // F3: require login — kills anonymous competition enumeration.
        $uid = (int)($this->session->user_id ?? 0);
        if ($uid <= 0) {
            header('Location: ' . UIR . 'Login/login');
            exit;
        }

        $competition_id = (int) preg_replace('/[^0-9]/', '', (string)$competition_id);
        if (!$competition_id) {
            header('Location: ' . UIR);
            exit;
        }

        $comp = $this->ArtsSciences->get_competition(['CompetitionId' => $competition_id, 'Token' => $this->session->token]);
        if (!isset($comp['Status']) || $comp['Status'] != 0) {
            header('Location: ' . UIR);
            exit;
        }
        $competition = $comp['Detail'];
        $kingdom_id = (int)$competition['KingdomId'];

        // F34: drop stale cached kingdom identity when switching kingdoms (mirror Controller_Kingdom).
        if (($this->session->kingdom_id ?? null) != $kingdom_id) {
            unset($this->session->kingdom_name);
            unset($this->session->park_id);
            unset($this->session->park_name);
        }
        $this->session->kingdom_id = $kingdom_id;
        if (!isset($this->session->kingdom_name)) {
            $this->session->kingdom_name = $this->Kingdom->get_kingdom_name($kingdom_id);
        }
        $kn = $this->session->kingdom_name;

        $this->template = '../revised-frontend/ArtsSciences_competition.tpl';
        // F36: escape competition name used as the page <title> (stored XSS vector).
        $this->data['page_title']    = htmlspecialchars($competition['Name'], ENT_QUOTES);
        $this->data['kingdom_id']    = $kingdom_id;
        $this->data['kingdom_name']  = $kn;
        $this->data['menu']['kingdom']     = ['url' => UIR . 'Kingdom/profile/' . $kingdom_id, 'display' => $kn];
        $this->data['menu']['as']          = ['url' => UIR . 'ArtsSciences/index/' . $kingdom_id, 'display' => 'Arts &amp; Sciences'];
        $this->data['menu']['competition'] = ['url' => UIR . 'ArtsComp/' . $competition_id, 'display' => htmlspecialchars($competition['Name'], ENT_QUOTES)];

        $isAdmin = $uid > 0 && Ork3::$Lib->authorization->HasAuthority($uid, AUTH_KINGDOM, $kingdom_id, AUTH_EDIT);

        // Determine judge status. Pass the viewer Token so the class can resolve the
        // caller's privilege (a judge is privileged and therefore receives unredacted
        // identity, allowing self-identification even under anonymous judging).
        $isJudge = false;
        $selfJudgeId = null;
        $jr = $this->ArtsSciences->get_judges(['Token' => $this->session->token, 'CompetitionId' => $competition_id]);
        $judges = (isset($jr['Status']) && $jr['Status'] == 0) ? ($jr['Detail'] ?? []) : [];
        foreach ($judges as $j) {
            if ((int)($j['MundaneId'] ?? 0) === $uid) {
                $isJudge = true;
                $selfJudgeId = (int)$j['JudgeId'];
                break;
            }
        }

        // F3: publish results ONLY when the competition is closed OR the viewer is an
        // admin/judge; otherwise the template renders a "not yet published" state.
        $status = strtolower((string)($competition['Status'] ?? ''));
        $bundle = null;
        if ($status === 'closed' || $isAdmin || $isJudge) {
            $results = $this->ArtsSciences->compute_results(['Token' => $this->session->token, 'CompetitionId' => $competition_id]);
            $bundle  = (isset($results['Status']) && $results['Status'] == 0) ? ($results['Detail'] ?? null) : null;
        }

        $this->data['competition']       = $competition;
        $this->data['can_manage']        = $isAdmin;
        $this->data['is_judge']          = $isJudge;
        $this->data['self_judge_id']     = $selfJudgeId;
        $this->data['results_bundle']    = $bundle;
        $this->data['anonymous_judging'] = (int)($competition['AnonymousJudging'] ?? 0);

        // CSRF token for A&S mutating fetch() calls.
        $this->data['AsCsrf'] = $this->_csrfToken();

        // Award option HTML for the in-judging recommendation form (only fetched when
        // the current user can use it — judges or admins). Cached server-side per kingdom.
        $this->data['rec_award_options_html'] = ($isJudge || $isAdmin)
            ? (string)$this->Award->fetch_award_option_list($kingdom_id, 'Awards')
            : '';
    }

    public function csv($competition_id = null)
    {
        $competition_id = (int) preg_replace('/[^0-9]/', '', (string)$competition_id);
        if (!$competition_id) {
            http_response_code(404);
            exit;
        }

        $includeFeedback = !empty($this->request->IncludeFeedback);

        $comp = $this->ArtsSciences->get_competition(['CompetitionId' => $competition_id, 'Token' => $this->session->token]);
        if (!isset($comp['Status']) || $comp['Status'] != 0) {
            http_response_code(404);
            exit;
        }
        $competition = $comp['Detail'];
        $kingdom_id  = (int)$competition['KingdomId'];

        $uid = (int)($this->session->user_id ?? 0);
        if (!Ork3::$Lib->authorization->HasAuthority($uid, AUTH_KINGDOM, $kingdom_id, AUTH_EDIT)) {
            http_response_code(403);
            echo 'Forbidden';
            exit;
        }

        $results = $this->ArtsSciences->compute_results(['Token' => $this->session->token, 'CompetitionId' => $competition_id]);
        if (!isset($results['Status']) || $results['Status'] != 0) {
            http_response_code(500);
            exit;
        }
        $bundle = $results['Detail'];

        $criteria = $bundle['Criteria'];
        $entries  = $bundle['Entries'];

        // F43: neutralize CSV formula / DDE injection — prefix any cell that begins with
        // a formula trigger (= + - @) or a control char (tab/CR/LF) with a single quote.
        $csvSafe = function ($v) {
            $s = (string)$v;
            if ($s !== '' && preg_match('/^[=+\-@\t\r\n]/', $s)) {
                $s = "'" . $s;
            }
            return $s;
        };

        $filename = 'as-results-' . $competition_id . '-' . date('Ymd-His') . '.csv';
        header('Content-Type: text/csv; charset=utf-8');
        header('Content-Disposition: attachment; filename="' . $filename . '"');
        $out = fopen('php://output', 'w');

        $header = ['Entry #', 'Title', 'Participant', 'Novice', 'Field/Category', 'Aggregate', 'Judge Count', 'Effective Count'];
        foreach ($criteria as $c) {
            $header[] = 'Avg ' . $c['Name'];
        }
        fputcsv($out, $header);

        // F45: reuse the per-criterion averages ComputeResults already computed instead
        // of a separate get_scores() round trip for the main results table.
        foreach ($entries as $e) {
            $row = [
                $e['EntryNumber'] ?? '',
                $csvSafe($e['Title']),
                $csvSafe($e['Persona']),
                $e['IsNovice'] ? 'Yes' : 'No',
                $csvSafe($e['TaxonomyName']),
                $e['Aggregate'] !== null ? round((float)$e['Aggregate'], 3) : '',
                $e['JudgeCount'],
                $e['EffectiveCount'],
            ];
            $critAvgs = $e['CriterionAverages'] ?? [];
            foreach ($criteria as $c) {
                $cid = $c['CriterionId'];
                $row[] = (isset($critAvgs[$cid]) && $critAvgs[$cid] !== null) ? round((float)$critAvgs[$cid], 3) : '';
            }
            fputcsv($out, $row);
        }

        if ($includeFeedback) {
            // Raw per-judge scores + judge identities are only needed for the feedback
            // section, so fetch them lazily here (F45).
            $scoresResp = $this->ArtsSciences->get_scores(['Token' => $this->session->token, 'CompetitionId' => $competition_id]);
            $rawScores  = (isset($scoresResp['Status']) && $scoresResp['Status'] == 0) ? ($scoresResp['Detail'] ?? []) : [];
            $judgesResp = $this->ArtsSciences->get_judges(['Token' => $this->session->token, 'CompetitionId' => $competition_id]);
            $judges     = (isset($judgesResp['Status']) && $judgesResp['Status'] == 0) ? ($judgesResp['Detail'] ?? []) : [];

            // F44: pre-group scores by entry and index judges/criteria by id ONCE, then
            // iterate linearly (was O(entries × scores × criteria)).
            $judgeById = [];
            foreach ($judges as $j) {
                $judgeById[$j['JudgeId']] = $j;
            }
            $critById = [];
            foreach ($criteria as $c) {
                $critById[$c['CriterionId']] = $c;
            }
            $scoresByEntry = [];
            foreach ($rawScores as $s) {
                $scoresByEntry[$s['EntryId']][] = $s;
            }

            fputcsv($out, []);
            fputcsv($out, ['--- Judge Feedback ---']);
            fputcsv($out, ['Entry #', 'Title', 'Participant', 'Judge', 'Criterion', 'Score', 'Feedback']);
            foreach ($entries as $e) {
                foreach ($scoresByEntry[$e['EntryId']] ?? [] as $s) {
                    $crit = $critById[$s['CriterionId']] ?? null;
                    $j    = $judgeById[$s['JudgeId']] ?? null;
                    fputcsv($out, [
                        $e['EntryNumber'] ?? '',
                        $csvSafe($e['Title']),
                        $csvSafe($e['Persona']),
                        $csvSafe($j['Persona'] ?? ('Judge #' . $s['JudgeId'])),
                        $crit['Name'] ?? ('Criterion #' . $s['CriterionId']),
                        $s['Score'],
                        $csvSafe($s['Feedback'] ?? ''),
                    ]);
                }
            }
        }

        fclose($out);
        exit;
    }
}
