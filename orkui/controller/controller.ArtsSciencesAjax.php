<?php

class Controller_ArtsSciencesAjax extends Controller {

	public function __construct($call = null, $id = null) {
		parent::__construct($call, $id);
		$this->load_model('ArtsSciences');
	}

	private function respond($payload) {
		header('Content-Type: application/json');
		echo json_encode($payload);
		exit;
	}

	private function bail_unauth($detail = 'Not logged in') {
		$this->respond(['status' => 5, 'error' => $detail]);
	}

	private function unwrap($r) {
		if (!isset($r['Status'])) return ['status' => 1, 'error' => 'Bad response'];
		if ($r['Status'] == 0) return ['status' => 0, 'result' => $r['Detail'] ?? null];
		return ['status' => (int)$r['Status'], 'error' => ($r['Error'] ?? 'Error') . ($r['Detail'] ? ': ' . (is_string($r['Detail']) ? $r['Detail'] : json_encode($r['Detail'])) : '')];
	}

	private function token() {
		return $this->session->token ?? '';
	}

	private function require_login() {
		if (!isset($this->session->user_id)) $this->bail_unauth();
	}

	// Route: ArtsSciencesAjax/create
	public function create() {
		$this->require_login();
		$kingdom_id = (int)($_POST['KingdomId'] ?? 0);
		if (!valid_id($kingdom_id)) $this->respond(['status' => 1, 'error' => 'KingdomId required']);
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
		$this->respond($this->unwrap($this->ArtsSciences->create_competition($req)));
	}

	// Route: ArtsSciencesAjax/kingdom/{kingdom_id}
	public function kingdom($p = null) {
		$this->require_login();
		$kingdom_id = (int) preg_replace('/[^0-9]/', '', $p ?? '');
		if (!valid_id($kingdom_id)) $this->respond(['status' => 1, 'error' => 'KingdomId required']);
		$this->respond($this->unwrap($this->ArtsSciences->list_competitions(['KingdomId' => $kingdom_id])));
	}

	// Route: ArtsSciencesAjax/future_events/{kingdom_id}
	// Returns events for the kingdom with at least one calendar detail dated today or later.
	public function future_events($p = null) {
		$this->require_login();
		$kingdom_id = (int) preg_replace('/[^0-9]/', '', $p ?? '');
		if (!valid_id($kingdom_id)) $this->respond(['status' => 1, 'error' => 'KingdomId required']);
		global $DB;
		$DB->Clear();
		$kid = (int)$kingdom_id;
		$rs = $DB->DataSet("
			SELECT e.event_id AS EventId, e.name AS Name, MIN(d.event_start) AS NextDate
			FROM " . DB_PREFIX . "event e
			INNER JOIN " . DB_PREFIX . "event_calendardetail d ON d.event_id = e.event_id
			WHERE e.kingdom_id = {$kid}
			  AND d.event_start >= CURDATE()
			GROUP BY e.event_id, e.name
			ORDER BY NextDate ASC
			LIMIT 100
		");
		$out = [];
		if ($rs && $rs->Size() > 0) {
			while ($rs->Next()) {
				$out[] = [
					'EventId'  => (int)$rs->EventId,
					'Name'     => $rs->Name,
					'NextDate' => $rs->NextDate,
				];
			}
		}
		$this->respond(['status' => 0, 'result' => $out]);
	}

	// Route: ArtsSciencesAjax/comp/{competition_id}/{action}
	public function comp($p = null) {
		$this->require_login();
		$parts = explode('/', $p ?? '');
		$competition_id = (int) preg_replace('/[^0-9]/', '', $parts[0] ?? '');
		$action = strtolower(trim($parts[1] ?? ''));
		if (!valid_id($competition_id)) $this->respond(['status' => 1, 'error' => 'Invalid competition id']);

		$req = ['Token' => $this->token(), 'CompetitionId' => $competition_id];

		switch ($action) {
			// Competition itself
			case 'update':
				foreach (['Name','Description','StartDateTime','EndDateTime','JudgingDeadline',
				          'CompetitionDate','EntriesDueAt','JudgingStartsAt','JudgingEndsAt',
				          'ScoringMin','ScoringMax','ScoringDefault','ScoringIncrement',
				          'AggregationMethod','Status','ParkId','EventId'] as $k) {
					if (array_key_exists($k, $_POST)) $req[$k] = $_POST[$k];
				}
				if (array_key_exists('AnonymousJudging', $_POST)) $req['AnonymousJudging'] = !empty($_POST['AnonymousJudging']);
				$this->respond($this->unwrap($this->ArtsSciences->update_competition($req)));
			case 'delete':
				$this->respond($this->unwrap($this->ArtsSciences->delete_competition($req)));
			case 'get':
				$this->respond($this->unwrap($this->ArtsSciences->get_competition($req)));

			// Taxonomy
			case 'taxonomy.list':
				$this->respond($this->unwrap($this->ArtsSciences->get_taxonomy($req)));
			case 'taxonomy.save':
				$req['TaxonomyId']  = $_POST['TaxonomyId']  ?? null;
				$req['ParentId']    = $_POST['ParentId']    ?? null;
				$req['Name']        = $_POST['Name']        ?? '';
				$req['Description'] = $_POST['Description'] ?? '';
				if (array_key_exists('Active', $_POST)) $req['Active'] = $_POST['Active'];
				$this->respond($this->unwrap($this->ArtsSciences->save_taxonomy($req)));
			case 'taxonomy.delete':
				$req['TaxonomyId'] = $_POST['TaxonomyId'] ?? 0;
				$this->respond($this->unwrap($this->ArtsSciences->delete_taxonomy($req)));
			case 'taxonomy.reorder':
				$tree = json_decode($_POST['Tree'] ?? '[]', true);
				$req['Tree'] = is_array($tree) ? $tree : [];
				$this->respond($this->unwrap($this->ArtsSciences->reorder_taxonomy($req)));

			// Criteria
			case 'criterion.list':
				$this->respond($this->unwrap($this->ArtsSciences->get_criteria($req)));
			case 'criterion.save':
				foreach (['CriterionId','Name','Description','Weight','SortOrder'] as $k) if (array_key_exists($k, $_POST)) $req[$k] = $_POST[$k];
				$this->respond($this->unwrap($this->ArtsSciences->save_criterion($req)));
			case 'criterion.delete':
				$req['CriterionId'] = $_POST['CriterionId'] ?? 0;
				$this->respond($this->unwrap($this->ArtsSciences->delete_criterion($req)));

			// Participants
			case 'participant.list':
				$this->respond($this->unwrap($this->ArtsSciences->get_participants($req)));
			case 'participant.save':
				foreach (['ParticipantId','MundaneId','Persona','ParkId','IsNovice','Notes'] as $k) if (array_key_exists($k, $_POST)) $req[$k] = $_POST[$k];
				$this->respond($this->unwrap($this->ArtsSciences->save_participant($req)));
			case 'participant.delete':
				$req['ParticipantId'] = $_POST['ParticipantId'] ?? 0;
				$this->respond($this->unwrap($this->ArtsSciences->delete_participant($req)));

			// Judges
			case 'judge.list':
				$this->respond($this->unwrap($this->ArtsSciences->get_judges($req)));
			case 'judge.save':
				foreach (['JudgeId','MundaneId','Persona','FieldTaxonomyId'] as $k) if (array_key_exists($k, $_POST)) $req[$k] = $_POST[$k];
				if (array_key_exists('FieldTaxonomyIds', $_POST)) $req['FieldTaxonomyIds'] = $_POST['FieldTaxonomyIds'];
				$this->respond($this->unwrap($this->ArtsSciences->save_judge($req)));
			case 'judge.delete':
				$req['JudgeId'] = $_POST['JudgeId'] ?? 0;
				$this->respond($this->unwrap($this->ArtsSciences->delete_judge($req)));

			// Entries
			case 'entry.list':
				$this->respond($this->unwrap($this->ArtsSciences->get_entries($req)));
			case 'entry.save':
				foreach (['EntryId','ParticipantId','TaxonomyId','Title','Description','Documentation','EntryNumber'] as $k) if (array_key_exists($k, $_POST)) $req[$k] = $_POST[$k];
				$this->respond($this->unwrap($this->ArtsSciences->save_entry($req)));
			case 'entry.delete':
				$req['EntryId'] = $_POST['EntryId'] ?? 0;
				$this->respond($this->unwrap($this->ArtsSciences->delete_entry($req)));

			// Scores
			case 'score.list':
				foreach (['EntryId','JudgeId'] as $k) if (array_key_exists($k, $_GET))  $req[$k] = $_GET[$k];
				foreach (['EntryId','JudgeId'] as $k) if (array_key_exists($k, $_POST)) $req[$k] = $_POST[$k];
				$this->respond($this->unwrap($this->ArtsSciences->get_scores($req)));
			case 'score.save':
				foreach (['EntryId','JudgeId','CriterionId','Score','Feedback'] as $k) if (array_key_exists($k, $_POST)) $req[$k] = $_POST[$k];
				$this->respond($this->unwrap($this->ArtsSciences->save_score($req)));

			// Awards
			case 'award.list':
				$this->respond($this->unwrap($this->ArtsSciences->get_awards($req)));
			case 'award.save':
				foreach (['AwardId','Name','Description','AwardType','FieldTaxonomyId','TopN','MinDistinctFields','MinDistinctCategories','NoviceOnly','SortOrder'] as $k) {
					if (array_key_exists($k, $_POST)) $req[$k] = $_POST[$k];
				}
				if (array_key_exists('Rules', $_POST)) $req['Rules'] = $_POST['Rules'];
				$this->respond($this->unwrap($this->ArtsSciences->save_award($req)));
			case 'award.delete':
				$req['AwardId'] = $_POST['AwardId'] ?? 0;
				$this->respond($this->unwrap($this->ArtsSciences->delete_award($req)));
			case 'award.preview':
				$req['Rules'] = $_POST['Rules'] ?? '[]';
				$this->respond($this->unwrap($this->ArtsSciences->preview_award($req)));

			// Results
			case 'results':
				$this->respond($this->unwrap($this->ArtsSciences->compute_results($req)));

			// Presets (competition-scoped: snapshot from / load into this competition)
			case 'preset.save_taxonomy':
				$req['KingdomId']  = $_POST['KingdomId']  ?? 0;
				$req['PresetId']   = $_POST['PresetId']   ?? 0;
				$req['Name']       = $_POST['Name']       ?? '';
				$req['Description']= $_POST['Description']?? '';
				$this->respond($this->unwrap($this->ArtsSciences->save_taxonomy_preset($req)));
			case 'preset.save_award':
				$req['KingdomId']  = $_POST['KingdomId']  ?? 0;
				$req['PresetId']   = $_POST['PresetId']   ?? 0;
				$req['Name']       = $_POST['Name']       ?? '';
				$req['Description']= $_POST['Description']?? '';
				$this->respond($this->unwrap($this->ArtsSciences->save_award_preset($req)));
			case 'preset.preview':
				$req['PresetId'] = $_POST['PresetId'] ?? 0;
				$req['Type']     = $_POST['Type']     ?? 'taxonomy';
				$this->respond($this->unwrap($this->ArtsSciences->preview_load_preset($req)));
			case 'preset.load_taxonomy':
				$req['PresetId'] = $_POST['PresetId'] ?? 0;
				$this->respond($this->unwrap($this->ArtsSciences->load_taxonomy_preset($req)));
			case 'preset.load_award':
				$req['PresetId'] = $_POST['PresetId'] ?? 0;
				$this->respond($this->unwrap($this->ArtsSciences->load_award_preset($req)));
		}
		$this->respond(['status' => 1, 'error' => 'Unknown action: ' . $action]);
	}


	// Player search with proximity ranking: rows that match the competition's park
	// surface first, then the kingdom, then everyone else. Always returns up to 15 results.
	// URL: ArtsSciencesAjax/playersearch/{kingdom_id}?q=…&park_id=…
	public function playersearch($p = null) {
		$this->require_login();
		$parts = explode('/', $p ?? '');
		$kingdom_id = (int)preg_replace('/[^0-9]/', '', $parts[0] ?? '');
		$park_id    = (int)preg_replace('/[^0-9]/', '', $_GET['park_id'] ?? '');
		$q = trim($_GET['q'] ?? '');
		if (strlen($q) < 2) { $this->respond([]); }
		global $DB;
		$DB->Clear();
		$qLike = "%" . str_replace(['%','_'], ['',''], $q) . "%";
		$qLikeEsc = mysql_real_escape_string($qLike);
		$kid = max(0, $kingdom_id);
		$pid = max(0, $park_id);
		// Bucket each row by proximity so a single ORDER BY pushes closer matches up.
		$rankExpr = "(CASE
			WHEN {$pid} > 0 AND p.park_id    = {$pid} THEN 1
			WHEN {$kid} > 0 AND p.kingdom_id = {$kid} THEN 2
			ELSE 3
		END)";
		$sql = "SELECT m.mundane_id AS MundaneId, m.persona AS Persona,
		               p.kingdom_id AS KingdomId, p.park_id AS ParkId,
		               p.name AS ParkName, k.name AS KingdomName,
		               {$rankExpr} AS Bucket
				FROM " . DB_PREFIX . "mundane m
				LEFT JOIN " . DB_PREFIX . "park    p ON p.park_id    = m.park_id
				LEFT JOIN " . DB_PREFIX . "kingdom k ON k.kingdom_id = p.kingdom_id
				WHERE m.persona LIKE '{$qLikeEsc}'
				  AND m.suspended = 0
				  AND m.active    = 1
				ORDER BY Bucket ASC, m.persona ASC
				LIMIT 15";
		$rs = $DB->DataSet($sql);
		$out = [];
		if ($rs && $rs->Size() > 0) {
			while ($rs->Next()) {
				$bucket = (int)$rs->Bucket;
				$out[] = [
					'MundaneId'   => (int)$rs->MundaneId,
					'Persona'     => $rs->Persona,
					'KingdomId'   => (int)$rs->KingdomId,
					'ParkId'      => (int)$rs->ParkId,
					'ParkName'    => $rs->ParkName,
					'KingdomName' => $rs->KingdomName,
					'Scope'       => $bucket === 1 ? 'park' : ($bucket === 2 ? 'kingdom' : 'other'),
				];
			}
		}
		$this->respond($out);
	}

	// Route: ArtsSciencesAjax/preset/{kingdom_id}/{action}
	//   action = list | get | delete
	//   POST: Type=taxonomy|award, PresetId (for get/delete)
	public function preset($p = null) {
		$this->require_login();
		$parts = explode('/', $p ?? '');
		$kingdom_id = (int) preg_replace('/[^0-9]/', '', $parts[0] ?? '');
		$action     = strtolower(trim($parts[1] ?? ''));
		if (!valid_id($kingdom_id)) $this->respond(['status' => 1, 'error' => 'KingdomId required']);
		$req = [
			'Token'     => $this->token(),
			'KingdomId' => $kingdom_id,
			'Type'      => $_POST['Type'] ?? $_GET['Type'] ?? 'taxonomy',
		];
		switch ($action) {
			case 'list':
				$this->respond($this->unwrap($this->ArtsSciences->list_presets($req)));
			case 'get':
				$req['PresetId'] = (int)($_POST['PresetId'] ?? $_GET['PresetId'] ?? 0);
				$this->respond($this->unwrap($this->ArtsSciences->get_preset($req)));
			case 'delete':
				$req['PresetId'] = (int)($_POST['PresetId'] ?? 0);
				$this->respond($this->unwrap($this->ArtsSciences->delete_preset($req)));
		}
		$this->respond(['status' => 1, 'error' => 'Unknown preset action: ' . $action]);
	}

}
