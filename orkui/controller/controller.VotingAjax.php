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
		$this->ok(['voting_race_id' => $r['Detail']]);
	}

	public function add_candidate($voting_race_id = null) {
		$this->require_login();
		$r = $this->Voting->add_candidate([
			'Token' => $this->session->token,
			'VotingRaceId' => (int)$voting_race_id,
			'CandidateMundaneId' => (int)$this->request->CandidateMundaneId,
		]);
		if (($r['Status'] ?? 1) != 0) $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
		$this->ok(['voting_choice_id' => $r['Detail']]);
	}

	public function add_option($voting_race_id = null) {
		$this->require_login();
		$r = $this->Voting->add_option([
			'Token' => $this->session->token,
			'VotingRaceId' => (int)$voting_race_id,
			'Label' => $this->request->Label,
		]);
		if (($r['Status'] ?? 1) != 0) $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
		$this->ok(['voting_choice_id' => $r['Detail']]);
	}

	public function remove_choice($voting_choice_id = null) {
		$this->require_login();
		$r = $this->Voting->remove_choice([
			'Token' => $this->session->token,
			'VotingChoiceId' => (int)$voting_choice_id,
		]);
		if (($r['Status'] ?? 1) != 0) $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
		$this->ok(['voting_choice_id' => $r['Detail']]);
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
		$this->ok(['voting_ballot_id' => $r['Detail']]);
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
		$this->ok(['voting_ballot_id' => $r['Detail']]);
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
		$pending = array_values(array_filter($events, fn($e) => empty($e['active_ballot_id']) || !empty($e['pending_revote'])));
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

	public function candidate_search($scope = null) {
		$this->require_login();
		// $scope is "Kingdom_10" or "Park_5" — single arg from the route system (4-part URLs collapse to one).
		$parts = explode('_', (string)$scope, 2);
		$scope_type = $parts[0] ?? '';
		$scope_id = (int)($parts[1] ?? 0);
		if (!in_array($scope_type, ['Kingdom', 'Park']) || !$scope_id) { $this->ok(['results' => []]); }

		// q can come from $_GET (e.g. "&q=foo"), or from $this->request->q if Smarty parsed it.
		$q = trim($_GET['q'] ?? ($this->request->q ?? ''));
		if (strlen($q) < 2) { $this->ok(['results' => []]); }

		global $DB;
		// Inline LIKE escape — same pattern as KingdomAjax/playersearch (yapo's DataSet does not support `?` bindings).
		$term = str_replace(["'", '%', '_', '\\'], ["''", '\\%', '\\_', '\\\\'], $q);

		// Scope: park-level pages search the park's players first, then fall back to the parent kingdom's players.
		// Kingdom-level pages stay within the kingdom. Never bleed across kingdoms by default.
		$kingdom_id = 0;
		$park_id = 0;
		if ($scope_type === 'Kingdom') {
			$kingdom_id = $scope_id;
		} else { // Park
			$park_id = $scope_id;
			$DB->Clear();
			$rs = $DB->DataSet("SELECT kingdom_id FROM " . DB_PREFIX . "park WHERE park_id = " . $park_id . " LIMIT 1");
			if ($rs && $rs->Next()) $kingdom_id = (int)$rs->kingdom_id;
		}
		if (!$kingdom_id) { $this->ok(['results' => []]); }

		$park_priority = $park_id > 0
			? "(CASE WHEN m.park_id = {$park_id} THEN 0 ELSE 1 END), "
			: '';

		$sql = "SELECT m.mundane_id, m.username, m.persona, m.given_name, m.surname,
				k.abbreviation AS k_abbr, p.abbreviation AS p_abbr,
				m.kingdom_id, m.park_id
			FROM " . DB_PREFIX . "mundane m
			LEFT JOIN " . DB_PREFIX . "kingdom k ON k.kingdom_id = m.kingdom_id
			LEFT JOIN " . DB_PREFIX . "park p ON p.park_id = m.park_id
			WHERE m.suspended = 0 AND m.active = 1
			  AND m.kingdom_id = {$kingdom_id}
			  AND (m.persona    LIKE '%{$term}%'
			    OR m.given_name LIKE '%{$term}%'
			    OR m.surname    LIKE '%{$term}%'
			    OR m.username   LIKE '%{$term}%')
			ORDER BY {$park_priority}(m.persona LIKE '{$term}%') DESC, m.persona
			LIMIT 15";

		$DB->Clear();
		$rs = $DB->DataSet($sql);
		$results = [];
		while ($rs && $rs->Next()) {
			$display = $rs->persona ?: trim(($rs->given_name ?? '') . ' ' . ($rs->surname ?? ''));
			if ($display === '') $display = $rs->username;
			$loc = trim(($rs->k_abbr ?? '') . ($rs->p_abbr ? ':' . $rs->p_abbr : ''));
			$label = $display . ' (' . $rs->username . ')' . ($loc !== '' ? ' [' . $loc . ']' : '');
			$results[] = [
				'value'    => (int)$rs->mundane_id,
				'label'    => $label,
				'display'  => $display,
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
		// Reuse candidate_search — single combined-arg signature.
		$this->candidate_search(ucfirst($rs->scope_type) . '_' . (int)$rs->scope_id);
	}

	public function reopen_event($voting_event_id = null) {
		$this->require_login();
		$r = $this->Voting->reopen_event([
			'Token' => $this->session->token,
			'VotingEventId' => (int)$voting_event_id,
			'Confirm' => !empty($this->request->Confirm) ? 1 : 0,
		]);
		if (($r['Status'] ?? 1) != 0) $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
		$this->ok();
	}

	public function preview_resume($voting_event_id = null) {
		$this->require_login();
		$voting_event_id = (int)$voting_event_id;
		if (!$this->user_is_runner_of_event($voting_event_id)) $this->fail('Not authorized.');
		$preview = $this->Voting->preview_resume($voting_event_id);
		$this->ok($preview);
	}

	public function resume_event($voting_event_id = null) {
		$this->require_login();
		$r = $this->Voting->resume_event([
			'Token' => $this->session->token,
			'VotingEventId' => (int)$voting_event_id,
			'Decision' => $this->request->Decision,
		]);
		if (($r['Status'] ?? 1) != 0) $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
		$this->ok();
	}

	public function edit_race($voting_race_id = null) {
		$this->require_login();
		$r = $this->Voting->edit_race([
			'Token' => $this->session->token,
			'VotingRaceId' => (int)$voting_race_id,
			'Title' => $this->request->Title,
			'Rationale' => $this->request->Rationale,
		]);
		if (($r['Status'] ?? 1) != 0) $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
		$this->ok();
	}

	public function edit_choice($voting_choice_id = null) {
		$this->require_login();
		$r = $this->Voting->edit_choice([
			'Token' => $this->session->token,
			'VotingChoiceId' => (int)$voting_choice_id,
			'Label' => $this->request->Label,
		]);
		if (($r['Status'] ?? 1) != 0) $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
		$this->ok();
	}

	public function restore_choice($voting_choice_id = null) {
		$this->require_login();
		$r = $this->Voting->restore_choice([
			'Token' => $this->session->token,
			'VotingChoiceId' => (int)$voting_choice_id,
		]);
		if (($r['Status'] ?? 1) != 0) $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
		$this->ok();
	}

	public function remove_race($voting_race_id = null) {
		$this->require_login();
		$r = $this->Voting->remove_race([
			'Token' => $this->session->token,
			'VotingRaceId' => (int)$voting_race_id,
		]);
		if (($r['Status'] ?? 1) != 0) $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
		$this->ok();
	}


	public function edit_event($voting_event_id = null) {
		$this->require_login();
		$req = ['Token' => $this->session->token, 'VotingEventId' => (int)$voting_event_id];
		foreach (['Title','Description','StartDate','EndDate'] as $k) {
			if (isset($this->request->$k)) $req[$k] = $this->request->$k;
		}
		foreach (['AnonymousToRunner','HideResultsFromCandidateRunners','AllowProvisional'] as $k) {
			if (isset($this->request->$k)) $req[$k] = !empty($this->request->$k) ? 1 : 0;
		}
		$r = $this->Voting->update_event($req);
		if (($r['Status'] ?? 1) != 0) $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
		$this->ok();
	}

	public function edit_race_settings($voting_race_id = null) {
		$this->require_login();
		$req = ['Token' => $this->session->token, 'VotingRaceId' => (int)$voting_race_id];
		if (isset($this->request->VotingMode)) $req['VotingMode'] = $this->request->VotingMode;
		if (isset($this->request->NotaCountsAs)) $req['NotaCountsAs'] = $this->request->NotaCountsAs;
		foreach (['AllowAbstain','AllowNoneOfAbove','IsNonBinding'] as $k) {
			if (isset($this->request->$k)) $req[$k] = !empty($this->request->$k) ? 1 : 0;
		}
		$r = $this->Voting->edit_race_settings($req);
		if (($r['Status'] ?? 1) != 0) $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
		$this->ok();
	}

}
