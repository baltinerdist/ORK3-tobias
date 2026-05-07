<?php

class Controller_VotingAjax extends Controller {

	public function __construct($call = null, $id = null) {
		parent::__construct($call, $id);
		$this->load_model('Voting');
		header('Content-Type: application/json');
	}

	private function fail($msg, $detail = '') {
		echo json_encode(['status' => 1, 'error' => $msg, 'detail' => $detail]);
		exit;
	}

	private function ok($payload = []) {
		echo json_encode(array_merge(['status' => 0], $payload));
		exit;
	}

	private function require_login() {
		if (!isset($this->session->user_id)) $this->fail('Not logged in.');
	}

	private function user_can_run_in_scope($scope_type, $scope_id) {
		$uid = (int)($this->session->user_id ?? 0);
		if (!$uid) return false;
		$auth = Ork3::$Lib->authorization;
		if ($auth->HasAuthority($uid, AUTH_ADMIN, 0, AUTH_ADMIN)) return true;
		$type = $scope_type === 'kingdom' ? AUTH_KINGDOM : AUTH_PARK;
		return $auth->HasAuthority($uid, $type, (int)$scope_id, AUTH_EDIT);
	}

	private function user_is_runner_of_event($voting_event_id) {
		$uid = (int)($this->session->user_id ?? 0);
		if (!$uid) return false;
		$auth = Ork3::$Lib->authorization;
		if ($auth->HasAuthority($uid, AUTH_ADMIN, 0, AUTH_ADMIN)) return true;
		global $DB;
		$DB->Clear();
		$rs = $DB->DataSet("SELECT 1 FROM " . DB_PREFIX . "voting_runner WHERE voting_event_id = " . (int)$voting_event_id . " AND mundane_id = " . $uid . " LIMIT 1");
		if ($rs && $rs->Next()) return true;
		$DB->Clear();
		$rs = $DB->DataSet("SELECT scope_type, scope_id FROM " . DB_PREFIX . "voting_event WHERE voting_event_id = " . (int)$voting_event_id . " LIMIT 1");
		if (!$rs || !$rs->Next()) return false;
		return $this->user_can_run_in_scope($rs->scope_type, $rs->scope_id);
	}

	// ──────────────────── Race / candidate adders (used by edit page) ────────────────────

	public function add_race($voting_event_id = null) {
		$this->require_login();
		$voting_event_id = (int)$voting_event_id;
		$req = [
			'Token' => $this->session->token,
			'VotingEventId' => $voting_event_id,
			'RaceType' => $this->request->RaceType,
			'VotingMode' => $this->request->VotingMode,
			'Title' => $this->request->Title,
			'Rationale' => $this->request->Rationale,
			'PositionId' => $this->request->PositionId,
			'AllowAbstain' => !empty($this->request->AllowAbstain) ? 1 : 0,
			'AllowNoneOfAbove' => !empty($this->request->AllowNoneOfAbove) ? 1 : 0,
			'NotaCountsAs' => $this->request->NotaCountsAs,
			'IsNonBinding' => !empty($this->request->IsNonBinding) ? 1 : 0,
			'DisplayOrder' => (int)$this->request->DisplayOrder,
		];
		$r = $this->Voting->add_race($req);
		if (($r['Status'] ?? 1) != 0) $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
		$this->ok(['voting_race_id' => $r['Id']]);
	}

	public function add_candidate($voting_race_id = null) {
		$this->require_login();
		$r = $this->Voting->add_candidate([
			'Token' => $this->session->token,
			'VotingRaceId' => (int)$voting_race_id,
			'CandidateMundaneId' => (int)$this->request->CandidateMundaneId,
		]);
		if (($r['Status'] ?? 1) != 0) $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
		$this->ok(['voting_choice_id' => $r['Id']]);
	}

	public function add_option($voting_race_id = null) {
		$this->require_login();
		$r = $this->Voting->add_option([
			'Token' => $this->session->token,
			'VotingRaceId' => (int)$voting_race_id,
			'Label' => $this->request->Label,
		]);
		if (($r['Status'] ?? 1) != 0) $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
		$this->ok(['voting_choice_id' => $r['Id']]);
	}

	public function open_event($voting_event_id = null) {
		$this->require_login();
		$r = $this->Voting->open_event([
			'Token' => $this->session->token,
			'VotingEventId' => (int)$voting_event_id,
		]);
		if (($r['Status'] ?? 1) != 0) $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
		$this->ok();
	}

	// ──────────────────── Cast ballot ────────────────────

	public function cast($voting_event_id = null) {
		$this->require_login();
		$votes = $this->request->Votes;
		// Smarty's request mechanism may have different shapes; accept JSON-encoded fallback.
		if (!is_array($votes) && is_string($votes)) {
			$votes = json_decode($votes, true);
		}
		if (!is_array($votes) && isset($_POST['Votes'])) {
			$decoded = json_decode($_POST['Votes'], true);
			if (is_array($decoded)) $votes = $decoded;
		}
		if (!is_array($votes)) $votes = [];

		$r = $this->Voting->cast_ballot([
			'Token' => $this->session->token,
			'VotingEventId' => (int)$voting_event_id,
			'Votes' => $votes,
		]);
		if (($r['Status'] ?? 1) != 0) $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
		$this->ok(['voting_ballot_id' => $r['Id']]);
	}

	public function external_ballot($voting_event_id = null) {
		$this->require_login();
		$voting_event_id = (int)$voting_event_id;
		if (!$this->user_is_runner_of_event($voting_event_id)) $this->fail('Not authorized to enter external ballots.');
		$voter_id = (int)$this->request->VoterMundaneId;
		if (!$voter_id) $this->fail('Voter required.');

		$votes = $this->request->Votes;
		if (!is_array($votes) && is_string($votes)) $votes = json_decode($votes, true);
		if (!is_array($votes) && isset($_POST['Votes'])) {
			$decoded = json_decode($_POST['Votes'], true);
			if (is_array($decoded)) $votes = $decoded;
		}
		if (!is_array($votes)) $votes = [];

		$r = $this->Voting->cast_ballot([
			'Token' => $this->session->token,
			'VotingEventId' => $voting_event_id,
			'VoterMundaneId' => $voter_id,
			'EnteredByRunnerId' => (int)$this->session->user_id,
			'Votes' => $votes,
		]);
		if (($r['Status'] ?? 1) != 0) $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
		$this->ok(['voting_ballot_id' => $r['Id']]);
	}

	// ──────────────────── Tally / banner / publish ────────────────────

	public function tally($voting_event_id = null) {
		$voting_event_id = (int)$voting_event_id;
		// Pre-publish: runner-only with officer-on-ballot suppression.
		// Post-publish: anyone can see (use the public results page; we still allow authenticated reads for consistency).
		global $DB;
		$DB->Clear();
		$rs = $DB->DataSet("SELECT status, hide_results_from_candidate_runners, anonymous_to_runner FROM " . DB_PREFIX . "voting_event WHERE voting_event_id = " . $voting_event_id);
		if (!$rs || !$rs->Next()) $this->fail('Event not found.');
		$status = $rs->status;
		$hide = (int)$rs->hide_results_from_candidate_runners;

		if (in_array($status, ['open', 'closed'])) {
			$this->require_login();
			if (!$this->user_is_runner_of_event($voting_event_id)) $this->fail('Not authorized.');
			$uid = (int)$this->session->user_id;
			$is_admin = Ork3::$Lib->authorization->HasAuthority($uid, AUTH_ADMIN, 0, AUTH_ADMIN);
			if ($hide && !$is_admin) {
				$DB->Clear();
				$rs2 = $DB->DataSet("SELECT 1 FROM " . DB_PREFIX . "voting_choice c
					JOIN " . DB_PREFIX . "voting_race r USING (voting_race_id)
					WHERE r.voting_event_id = " . $voting_event_id . " AND c.candidate_mundane_id = " . $uid . " LIMIT 1");
				if ($rs2 && $rs2->Next()) {
					http_response_code(403);
					$this->fail('You are a candidate in this event; results are not visible to you until publication.');
				}
			}
			$tally = $this->Voting->tally($voting_event_id);
			$this->ok(['tally' => $tally, 'event_status' => $status]);
		}
		// Published / unpublished — defer to public reader (which gates on status='published').
		$r = $this->Voting->tally_public($voting_event_id);
		if (($r['Status'] ?? 1) != 0) $this->fail($r['Error'] ?? 'Failed');
		$this->ok(['tally' => $r['Tally'], 'event_status' => $status]);
	}

	public function banner($mundane_id = null) {
		$this->require_login();
		$mundane_id = (int)$mundane_id;
		// Only allow self or admin.
		$uid = (int)$this->session->user_id;
		if ($mundane_id !== $uid && !Ork3::$Lib->authorization->HasAuthority($uid, AUTH_ADMIN, 0, AUTH_ADMIN)) {
			$this->fail('Not authorized.');
		}
		$events = $this->Voting->active_for_voter($mundane_id);
		// Filter to those without an active ballot.
		$pending = array_values(array_filter($events, fn($e) => empty($e['active_ballot_id'])));
		$this->ok(['events' => $pending]);
	}

	public function release_provisional($voting_ballot_id = null) {
		$this->require_login();
		$r = $this->Voting->release_provisional([
			'Token' => $this->session->token,
			'VotingBallotId' => (int)$voting_ballot_id,
			'Reason' => $this->request->Reason,
		]);
		if (($r['Status'] ?? 1) != 0) $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
		$this->ok();
	}

	public function resolve_tie($voting_race_id = null) {
		$this->require_login();
		$r = $this->Voting->resolve_tie([
			'Token' => $this->session->token,
			'VotingRaceId' => (int)$voting_race_id,
			'WinnerChoiceId' => (int)$this->request->WinnerChoiceId,
			'Note' => $this->request->Note,
		]);
		if (($r['Status'] ?? 1) != 0) $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
		$this->ok();
	}

	public function publish($voting_event_id = null) {
		$this->require_login();
		$r = $this->Voting->publish([
			'Token' => $this->session->token,
			'VotingEventId' => (int)$voting_event_id,
		]);
		if (($r['Status'] ?? 1) != 0) $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
		$this->ok();
	}

	public function unpublish($voting_event_id = null) {
		$this->require_login();
		$r = $this->Voting->unpublish([
			'Token' => $this->session->token,
			'VotingEventId' => (int)$voting_event_id,
		]);
		if (($r['Status'] ?? 1) != 0) $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
		$this->ok();
	}

	// ──────────────────── Player searches (kn-ac-results format) ────────────────────

	public function candidate_search($scope_type = null, $scope_id = null) {
		$this->require_login();
		$q = trim($this->request->q ?? '');
		if (strlen($q) < 2) $this->ok(['results' => []]);
		global $DB;
		$DB->Clear();
		$like = '%' . str_replace(['%', '_'], ['\\%', '\\_'], $q) . '%';
		$bind = [];
		// Scope filter (kingdom or park).
		$scope_clause = '';
		if (strtolower($scope_type) === 'kingdom') {
			$scope_clause = " AND m.kingdom_id = " . (int)$scope_id;
		} else if (strtolower($scope_type) === 'park') {
			$scope_clause = " AND m.park_id = " . (int)$scope_id;
		}
		$sql = "SELECT m.mundane_id, m.username, m.persona, m.given_name, m.surname
			FROM " . DB_PREFIX . "mundane m
			WHERE (m.username LIKE ? OR m.persona LIKE ? OR CONCAT(m.given_name,' ',m.surname) LIKE ?)
			" . $scope_clause . "
			LIMIT 12";
		$rs = $DB->DataSet($sql, [$like, $like, $like]);
		$results = [];
		while ($rs && $rs->Next()) {
			$display = $rs->persona ?: trim($rs->given_name . ' ' . $rs->surname);
			$results[] = [
				'value' => (int)$rs->mundane_id,
				'label' => $display . ' (' . $rs->username . ')',
				'display' => $display,
				'username' => $rs->username,
			];
		}
		$this->ok(['results' => $results]);
	}

	public function voter_search($voting_event_id = null) {
		$this->require_login();
		$voting_event_id = (int)$voting_event_id;
		if (!$this->user_is_runner_of_event($voting_event_id)) $this->fail('Not authorized.');
		// Scope from event.
		global $DB;
		$DB->Clear();
		$rs = $DB->DataSet("SELECT scope_type, scope_id FROM " . DB_PREFIX . "voting_event WHERE voting_event_id = " . $voting_event_id . " LIMIT 1");
		if (!$rs || !$rs->Next()) $this->fail('Event not found.');
		$st = $rs->scope_type;
		$sid = (int)$rs->scope_id;
		// Reuse candidate_search semantics, but route through the same search.
		$_GET['q'] = $this->request->q;
		$this->candidate_search(ucfirst($st), $sid);
	}
}
