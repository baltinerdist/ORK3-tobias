<?php

class Controller_ArtsSciences extends Controller {

	public function __construct($call = null, $id = null) {
		parent::__construct($call, $id);
		$this->load_model('Kingdom');
		$this->load_model('Award');
	}

	public function index($kingdom_id = null) {
		$kingdom_id = (int) preg_replace('/[^0-9]/', '', (string)$kingdom_id);
		if (!$kingdom_id) {
			header('Location: ' . UIR);
			exit;
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

		$uid = (int)($this->session->user_id ?? 0);
		$this->data['can_manage'] = $uid > 0 && Ork3::$Lib->authorization->HasAuthority($uid, AUTH_KINGDOM, $kingdom_id, AUTH_EDIT);

		$resp = $this->ArtsSciences->list_competitions(['KingdomId' => $kingdom_id]);
		$this->data['competitions'] = (isset($resp['Status']) && $resp['Status'] == 0) ? ($resp['Detail'] ?? []) : [];
	}

	public function competition($competition_id = null) {
		$competition_id = (int) preg_replace('/[^0-9]/', '', (string)$competition_id);
		if (!$competition_id) { header('Location: ' . UIR); exit; }

		$comp = $this->ArtsSciences->get_competition(['CompetitionId' => $competition_id]);
		if (!isset($comp['Status']) || $comp['Status'] != 0) { header('Location: ' . UIR); exit; }
		$competition = $comp['Detail'];
		$kingdom_id = (int)$competition['KingdomId'];
		$this->session->kingdom_id = $kingdom_id;
		if (!isset($this->session->kingdom_name)) {
			$this->session->kingdom_name = $this->Kingdom->get_kingdom_name($kingdom_id);
		}
		$kn = $this->session->kingdom_name;

		$this->template = '../revised-frontend/ArtsSciences_competition.tpl';
		$this->data['page_title']    = $competition['Name'];
		$this->data['kingdom_id']    = $kingdom_id;
		$this->data['kingdom_name']  = $kn;
		$this->data['menu']['kingdom']     = ['url' => UIR . 'Kingdom/profile/' . $kingdom_id, 'display' => $kn];
		$this->data['menu']['as']          = ['url' => UIR . 'ArtsSciences/index/' . $kingdom_id, 'display' => 'Arts &amp; Sciences'];
		$this->data['menu']['competition'] = ['url' => UIR . 'ArtsComp/' . $competition_id, 'display' => htmlspecialchars($competition['Name'], ENT_QUOTES)];

		$uid     = (int)($this->session->user_id ?? 0);
		$isAdmin = $uid > 0 && Ork3::$Lib->authorization->HasAuthority($uid, AUTH_KINGDOM, $kingdom_id, AUTH_EDIT);
		$results = $this->ArtsSciences->compute_results(['CompetitionId' => $competition_id]);
		$bundle  = (isset($results['Status']) && $results['Status'] == 0) ? ($results['Detail'] ?? null) : null;

		$isJudge = false;
		$selfJudgeId = null;
		if ($uid > 0) {
			$jr = $this->ArtsSciences->get_judges(['CompetitionId' => $competition_id]);
			$judges = (isset($jr['Status']) && $jr['Status'] == 0) ? ($jr['Detail'] ?? []) : [];
			foreach ($judges as $j) {
				if ((int)($j['MundaneId'] ?? 0) === $uid) { $isJudge = true; $selfJudgeId = (int)$j['JudgeId']; break; }
			}
		}

		$this->data['competition']     = $competition;
		$this->data['can_manage']      = $isAdmin;
		$this->data['is_judge']        = $isJudge;
		$this->data['self_judge_id']   = $selfJudgeId;
		$this->data['results_bundle']  = $bundle;

		// Award option HTML for the in-judging recommendation form (only fetched when
		// the current user can use it — judges or admins). Cached server-side per kingdom.
		$this->data['rec_award_options_html'] = ($isJudge || $isAdmin)
			? (string)$this->Award->fetch_award_option_list($kingdom_id, 'Awards')
			: '';
	}

	public function csv($competition_id = null) {
		$competition_id = (int) preg_replace('/[^0-9]/', '', (string)$competition_id);
		if (!$competition_id) { http_response_code(404); exit; }

		$includeFeedback = !empty($this->request->IncludeFeedback);

		$comp = $this->ArtsSciences->get_competition(['CompetitionId' => $competition_id]);
		if (!isset($comp['Status']) || $comp['Status'] != 0) { http_response_code(404); exit; }
		$competition = $comp['Detail'];
		$kingdom_id  = (int)$competition['KingdomId'];

		$uid = (int)($this->session->user_id ?? 0);
		if (!Ork3::$Lib->authorization->HasAuthority($uid, AUTH_KINGDOM, $kingdom_id, AUTH_EDIT)) {
			http_response_code(403); echo 'Forbidden'; exit;
		}

		$results = $this->ArtsSciences->compute_results(['CompetitionId' => $competition_id]);
		if (!isset($results['Status']) || $results['Status'] != 0) { http_response_code(500); exit; }
		$bundle = $results['Detail'];

		$criteria = $bundle['Criteria'];
		$entries  = $bundle['Entries'];
		$scoresResp = $this->ArtsSciences->get_scores(['CompetitionId' => $competition_id]);
		$rawScores  = (isset($scoresResp['Status']) && $scoresResp['Status'] == 0) ? ($scoresResp['Detail'] ?? []) : [];
		$judgesResp = $this->ArtsSciences->get_judges(['CompetitionId' => $competition_id]);
		$judges     = (isset($judgesResp['Status']) && $judgesResp['Status'] == 0) ? ($judgesResp['Detail'] ?? []) : [];
		$judgeById = [];
		foreach ($judges as $j) $judgeById[$j['JudgeId']] = $j;

		$filename = 'as-results-' . $competition_id . '-' . date('Ymd-His') . '.csv';
		header('Content-Type: text/csv; charset=utf-8');
		header('Content-Disposition: attachment; filename="' . $filename . '"');
		$out = fopen('php://output', 'w');

		$header = ['Entry #', 'Title', 'Participant', 'Novice', 'Field/Category', 'Aggregate', 'Judge Count', 'Effective Count'];
		foreach ($criteria as $c) $header[] = 'Avg ' . $c['Name'];
		fputcsv($out, $header);

		// Group rawScores per entry/criterion
		$avgByEntryCriterion = [];
		foreach ($rawScores as $s) {
			$avgByEntryCriterion[$s['EntryId']][$s['CriterionId']][] = $s['Score'];
		}

		foreach ($entries as $e) {
			$row = [
				$e['EntryNumber'] ?? '',
				$e['Title'],
				$e['Persona'],
				$e['IsNovice'] ? 'Yes' : 'No',
				$e['TaxonomyName'],
				$e['Aggregate'] !== null ? round((float)$e['Aggregate'], 3) : '',
				$e['JudgeCount'],
				$e['EffectiveCount'],
			];
			foreach ($criteria as $c) {
				$arr = $avgByEntryCriterion[$e['EntryId']][$c['CriterionId']] ?? [];
				$row[] = $arr ? round(array_sum($arr) / count($arr), 3) : '';
			}
			fputcsv($out, $row);
		}

		if ($includeFeedback) {
			fputcsv($out, []);
			fputcsv($out, ['--- Judge Feedback ---']);
			fputcsv($out, ['Entry #', 'Title', 'Participant', 'Judge', 'Criterion', 'Score', 'Feedback']);
			foreach ($entries as $e) {
				foreach ($rawScores as $s) {
					if ($s['EntryId'] !== $e['EntryId']) continue;
					$crit = null;
					foreach ($criteria as $c) if ($c['CriterionId'] === $s['CriterionId']) { $crit = $c; break; }
					$j = $judgeById[$s['JudgeId']] ?? null;
					fputcsv($out, [
						$e['EntryNumber'] ?? '',
						$e['Title'],
						$e['Persona'],
						$j['Persona'] ?? ('Judge #' . $s['JudgeId']),
						$crit['Name'] ?? ('Criterion #' . $s['CriterionId']),
						$s['Score'],
						$s['Feedback'] ?? '',
					]);
				}
			}
		}

		fclose($out);
		exit;
	}
}
