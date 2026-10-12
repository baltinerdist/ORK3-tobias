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

        // F6: resolve the caller's OWN judge_id via the lib (mundane_id -> judge_id), which is
        // never redacted even under anonymous judging. Scanning get_judges() for a MundaneId
        // match misdetected real judges because that column is null when scores are blind.
        $selfJudgeId = (int)$this->ArtsSciences->self_judge_id($this->session->token, $competition_id);
        $isJudge     = $selfJudgeId > 0;

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
        $this->data['self_judge_id']     = $isJudge ? $selfJudgeId : null;
        // F15: this server-computed bundle also seeds the JS global INITIAL_RESULTS_BUNDLE so the
        // first Results-tab activation renders without a second (client-side) compute round-trip.
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

        // F9: award winners section — export the winners compute_results already produced so the
        // CSV agrees with the on-screen award table. This is an admin export (HasAuthority gate
        // above), so identities are unredacted; reuse the $csvSafe formula-injection guard.
        $awardResults = $bundle['Awards'] ?? [];
        if ($awardResults) {
            $entryNumberById = [];
            foreach ($entries as $e) {
                $entryNumberById[$e['EntryId']] = $e['EntryNumber'] ?? '';
            }
            fputcsv($out, []);
            fputcsv($out, ['--- Award Winners ---']);
            fputcsv($out, ['Award', 'Entry #', 'Title', 'Participant', 'Aggregate', 'Warnings']);
            foreach ($awardResults as $ar) {
                $a       = $ar['Award'];
                $winners = $ar['Winners'] ?? [];
                $warnText = '';
                foreach ($ar['Warnings'] ?? [] as $wn) {
                    $warnText .= ($warnText === '' ? '' : ' ') . (string)($wn['message'] ?? '');
                }
                if (!$winners) {
                    fputcsv($out, [
                        $csvSafe($a['Name']),
                        '',
                        'No qualifying winner yet.',
                        '',
                        '',
                        $csvSafe($warnText),
                    ]);
                    continue;
                }
                foreach ($winners as $wi => $win) {
                    $agg = ($win['Aggregate'] === null) ? '' : round((float)$win['Aggregate'], 3);
                    fputcsv($out, [
                        $csvSafe($a['Name']),
                        ($win['EntryId'] !== null) ? ($entryNumberById[$win['EntryId']] ?? '') : '',
                        $csvSafe($win['Title'] ?? ''),
                        $csvSafe($win['Persona'] ?? ''),
                        $agg,
                        // Warnings are per-award; emit on the first winner row only to avoid repeats.
                        $wi === 0 ? $csvSafe($warnText) : '',
                    ]);
                }
            }
        }

        fclose($out);
        exit;
    }

    // #41: printable per-entry judge score sheet — a blank paper rubric for judging at the table.
    // Self-contained print HTML (no layout chrome), built and echoed like csv(). Officer-gated;
    // the artisan is hidden when the competition runs blind (anonymous judging).
    public function sheet($competition_id = null)
    {
        $competition_id = (int) preg_replace('/[^0-9]/', '', (string)$competition_id);
        if (!$competition_id) {
            http_response_code(404);
            exit;
        }
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
        // Reuse the computed bundle: entries are already blind-redacted + status-filtered (#39),
        // and criteria carry the rubric. We ignore any scores — this is a blank sheet.
        $results = $this->ArtsSciences->compute_results(['Token' => $this->session->token, 'CompetitionId' => $competition_id]);
        if (!isset($results['Status']) || $results['Status'] != 0) {
            http_response_code(500);
            exit;
        }
        $bundle   = $results['Detail'];
        $criteria = $bundle['Criteria'] ?? [];
        $entries  = $bundle['Entries'] ?? [];
        $anon     = !empty($competition['AnonymousJudging']);

        $trim = function ($n) {
            return rtrim(rtrim(number_format((float)$n, 2), '0'), '.');
        };
        $min   = $trim($competition['ScoringMin'] ?? 0);
        $max   = $trim($competition['ScoringMax'] ?? 5);
        $inc   = $trim($competition['ScoringIncrement'] ?? 0.5);
        $scale = $min . '&ndash;' . $max . ' (step ' . $inc . ')';
        $h     = function ($s) {
            return htmlspecialchars((string)$s, ENT_QUOTES, 'UTF-8');
        };

        header('Content-Type: text/html; charset=utf-8');
        echo '<!doctype html><html><head><meta charset="utf-8">';
        echo '<title>Judge Score Sheet &mdash; ' . $h($competition['Name']) . '</title><style>';
        echo 'body{font:13px/1.4 Georgia,serif;color:#111;margin:24px;}';
        echo 'h1{font-size:18px;margin:0 0 2px;} .sub{color:#555;font-size:12px;margin-bottom:10px;}';
        echo '.jline{margin:6px 0 16px;font-size:12px;} .jline span{display:inline-block;border-bottom:1px solid #999;min-width:220px;}';
        echo '.entry{border:1px solid #bbb;border-radius:6px;padding:12px 14px;margin:0 0 14px;page-break-inside:avoid;}';
        echo '.entry h2{font-size:15px;margin:0 0 2px;} .meta{color:#555;font-size:12px;margin-bottom:8px;}';
        echo 'table{width:100%;border-collapse:collapse;} th,td{border:1px solid #ccc;padding:6px 8px;text-align:left;vertical-align:top;font-size:12px;}';
        echo 'th{background:#f2f2f2;font-size:11px;text-transform:uppercase;letter-spacing:.03em;}';
        echo '.scorebox{width:70px;text-align:center;color:#999;} .cmt{color:#bbb;}';
        echo '.tot{margin-top:6px;font-size:12px;color:#333;}';
        echo '@media print{body{margin:0;} .noprint{display:none;} .entry{border-color:#999;}}';
        echo '</style></head><body>';
        echo '<div class="noprint" style="font:12px sans-serif;margin-bottom:12px;color:#555">';
        echo 'Use your browser\'s Print (Ctrl/Cmd+P) to print or save as PDF.</div>';
        echo '<h1>' . $h($competition['Name']) . ' &mdash; Judge Score Sheet</h1>';
        echo '<div class="sub">Scale ' . $scale . ($anon ? ' &middot; <strong>Blind judging</strong> (entrant identity withheld)' : '') . '</div>';
        echo '<div class="jline">Judge: <span>&nbsp;</span> &nbsp; Field(s): <span>&nbsp;</span></div>';

        if (empty($entries)) {
            echo '<p>No active entries to judge yet.</p>';
        }
        foreach ($entries as $e) {
            $num   = $e['EntryNumber'] ?? '';
            $title = $e['Title'] ?? 'Untitled Entry';
            $cat   = $e['TaxonomyName'] ?? '';
            $who   = $anon ? 'Anonymous (blind)' : ($e['Persona'] ?? '&mdash;');
            echo '<div class="entry">';
            echo '<h2>' . ($num !== '' ? '#' . $h($num) . ' &mdash; ' : '') . $h($title) . '</h2>';
            echo '<div class="meta">' . ($cat !== '' ? $h($cat) . ' &middot; ' : '') . 'Artisan: ' . $h($who) . '</div>';
            echo '<table><thead><tr><th style="width:230px">Criterion</th><th style="width:56px">Weight</th><th style="width:104px">Scale</th><th style="width:60px">Score</th><th>Comments</th></tr></thead><tbody>';
            foreach ($criteria as $c) {
                echo '<tr><td>' . $h($c['Name']);
                if (!empty($c['Description'])) {
                    echo '<br><span style="color:#777;font-size:11px">' . $h($c['Description']) . '</span>';
                }
                echo '</td><td>' . $trim($c['Weight'] ?? 1) . '&times;</td><td>' . $scale . '</td>';
                echo '<td class="scorebox">____</td><td class="cmt">&nbsp;</td></tr>';
            }
            echo '</tbody></table>';
            echo '<div class="tot">Overall / weighted total: __________ &nbsp;&nbsp; Notes to entrant: ______________________________</div>';
            echo '</div>';
        }
        echo '</body></html>';
        exit;
    }
}
