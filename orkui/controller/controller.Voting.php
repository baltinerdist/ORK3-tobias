<?php

class Controller_Voting extends Controller {

	public function __construct($call = null, $id = null) {
		parent::__construct($call, $id);
		$this->load_model('Voting');
		$this->load_model('Park');
		$this->load_model('Kingdom');
		$this->load_model('Reports');
	}

	private function require_login() {
		if (!isset($this->session->user_id)) {
			header('Location: ' . UIR . 'Login/login/Voting/index');
			exit;
		}
	}

	private function user_can_run_in_scope($scope_type, $scope_id) {
		$uid = (int)($this->session->user_id ?? 0);
		if (!$uid) return false;
		$auth = Ork3::$Lib->authorization;
		if ($auth->HasAuthority($uid, AUTH_ADMIN, 0, AUTH_ADMIN)) return true;
		$type = $scope_type === 'kingdom' ? AUTH_KINGDOM : AUTH_PARK;
		return $auth->HasAuthority($uid, $type, (int)$scope_id, AUTH_EDIT);
	}

	private function user_is_runner_of_event($voting_event_id, $event_data = null) {
		$uid = (int)($this->session->user_id ?? 0);
		if (!$uid) return false;
		$auth = Ork3::$Lib->authorization;
		if ($auth->HasAuthority($uid, AUTH_ADMIN, 0, AUTH_ADMIN)) return true;
		if ($event_data === null) {
			$r = $this->Voting->get_event($voting_event_id);
			$event_data = $r['Event'] ?? null;
		}
		if (!$event_data) return false;
		// Explicit runner row?
		global $DB;
		$DB->Clear();
		$rs = $DB->DataSet("SELECT mundane_id FROM " . DB_PREFIX . "voting_runner WHERE voting_event_id = " . (int)$voting_event_id . " AND mundane_id = " . $uid . " LIMIT 1");
		if ($rs && $rs->Next()) return true;
		return $this->user_can_run_in_scope($event_data['scope_type'], $event_data['scope_id']);
	}

	// ─────────────────────── Listing ───────────────────────

	public function index($scope = null) {
		// $scope is "Kingdom_10" or "Park_5" — single arg from the routing system.
		$parts = explode('_', (string)$scope, 2);
		$scope_type = $parts[0] ?? '';
		$scope_id = (int)($parts[1] ?? 0);
		if (!in_array($scope_type, ['Kingdom', 'Park']) || !$scope_id) {
			$this->data['Error'] = 'Invalid scope.';
			$this->template = '../revised-frontend/Voting_index.tpl';
			return;
		}
		$st = strtolower($scope_type);
		$this->data['scope_type'] = $st;
		$this->data['scope_id'] = $scope_id;
		$this->data['scope_type_label'] = $scope_type;

		// Get scope title (kingdom/park name) for display.
		if ($st === 'kingdom') {
			$this->data['scope_name'] = $this->Kingdom->get_kingdom_name($scope_id) ?: "Kingdom #$scope_id";
			$this->data['scope_back_url'] = UIR . 'Kingdom/index/' . $scope_id;
		} else {
			$pi = $this->Park->get_park_info($scope_id);
			$this->data['scope_name'] = $pi['ParkInfo']['ParkName'] ?? "Park #$scope_id";
			$this->data['scope_back_url'] = UIR . 'Park/index/' . $scope_id;
		}

		$this->data['events'] = $this->Voting->list_for_scope($st, $scope_id);
		$this->data['can_create'] = $this->user_can_run_in_scope($st, $scope_id);

		$this->template = '../revised-frontend/Voting_index.tpl';
	}

	// ─────────────────────── Create / Edit ───────────────────────

	public function create($scope = null) {
		$this->require_login();
		$parts = explode('_', (string)$scope, 2);
		$scope_type = $parts[0] ?? '';
		$scope_id = (int)($parts[1] ?? 0);
		if (!in_array($scope_type, ['Kingdom', 'Park']) || !$scope_id) {
			header('Location: ' . UIR);
			exit;
		}
		$st = strtolower($scope_type);
		if (!$this->user_can_run_in_scope($st, $scope_id)) {
			header('Location: ' . UIR);
			exit;
		}
		$this->data['scope_type'] = $st;
		$this->data['scope_id'] = $scope_id;
		$this->data['scope_type_label'] = $scope_type;
		if ($st === 'kingdom') {
			$this->data['scope_name'] = $this->Kingdom->get_kingdom_name($scope_id) ?: "Kingdom #$scope_id";
		} else {
			$pi = $this->Park->get_park_info($scope_id);
			$this->data['scope_name'] = $pi['ParkInfo']['ParkName'] ?? "Park #$scope_id";
		}

		// Form submit.
		if (!empty($this->request->Action) && $this->request->Action === 'create_event') {
			$req = [
				'Token' => $this->session->token,
				'EventType' => $this->request->EventType,
				'ScopeType' => $st,
				'ScopeId' => $scope_id,
				'Title' => $this->request->Title,
				'Description' => $this->request->Description,
				'StartDate' => $this->request->StartDate,
				'EndDate' => $this->request->EndDate,
				'AnonymousToRunner' => !empty($this->request->AnonymousToRunner) ? 1 : 0,
				'HideResultsFromCandidateRunners' => !empty($this->request->HideResultsFromCandidateRunners) ? 1 : 0,
				'AllowProvisional' => !empty($this->request->AllowProvisional) ? 1 : 0,
			];
			$r = $this->Voting->create_event($req);
			if (($r['Status'] ?? 1) == 0) {
				header('Location: ' . UIR . 'Voting/edit/' . $r['Id']);
				exit;
			} else {
				$this->data['Error'] = ($r['Error'] ?? 'Error') . ': ' . ($r['Detail'] ?? '');
			}
		}

		$this->template = '../revised-frontend/Voting_create.tpl';
	}

	public function edit($voting_event_id = null) {
		$this->require_login();
		$voting_event_id = (int)$voting_event_id;
		$r = $this->Voting->get_event($voting_event_id);
		if (($r['Status'] ?? 1) != 0) { header('Location: ' . UIR); exit; }
		$event = $r['Event'];
		if (!$this->user_is_runner_of_event($voting_event_id, $event)) {
			header('Location: ' . UIR . 'Voting/results/' . $voting_event_id);
			exit;
		}
		$this->data['event'] = $event;
		$this->data['voting_event_id'] = $voting_event_id;
		$this->data['can_edit'] = ($event['status'] === 'draft');
		$this->template = '../revised-frontend/Voting_edit.tpl';
	}

	// ─────────────────────── Voter ballot ───────────────────────

	public function event($voting_event_id = null) {
		$this->require_login();
		$voting_event_id = (int)$voting_event_id;
		$r = $this->Voting->get_event($voting_event_id);
		if (($r['Status'] ?? 1) != 0) {
			$this->data['Error'] = 'Event not found.';
			$this->template = '../revised-frontend/Voting_event.tpl';
			return;
		}
		$event = $r['Event'];
		$this->data['event'] = $event;
		$this->data['voting_event_id'] = $voting_event_id;

		// Check eligibility.
		$elig = $this->Voting->eligibility_check([
			'Token' => $this->session->token,
			'VotingEventId' => $voting_event_id,
		]);
		$this->data['eligibility'] = $elig;

		// Look up the voter's currently-active ballot for this event (vote-change UX).
		global $DB;
		$DB->Clear();
		$uid = (int)$this->session->user_id;
		$rs = $DB->DataSet("SELECT b.* FROM " . DB_PREFIX . "voting_active_ballot ab
			JOIN " . DB_PREFIX . "voting_ballot b USING (voting_ballot_id)
			WHERE ab.voting_event_id = " . $voting_event_id . " AND ab.voter_mundane_id = " . $uid . " LIMIT 1");
		$active = ($rs && $rs->Next()) ? (array)$rs : null;
		$this->data['active_ballot'] = $active;

		$this->template = '../revised-frontend/Voting_event.tpl';
	}

	// ─────────────────────── Runner dashboard ───────────────────────

	public function runner($voting_event_id = null) {
		$this->require_login();
		$voting_event_id = (int)$voting_event_id;
		$r = $this->Voting->get_event($voting_event_id);
		if (($r['Status'] ?? 1) != 0) { header('Location: ' . UIR); exit; }
		$event = $r['Event'];
		if (!$this->user_is_runner_of_event($voting_event_id, $event)) {
			header('Location: ' . UIR . 'Voting/results/' . $voting_event_id);
			exit;
		}

		$this->data['event'] = $event;
		$this->data['voting_event_id'] = $voting_event_id;
		$this->data['is_admin'] = Ork3::$Lib->authorization->HasAuthority((int)$this->session->user_id, AUTH_ADMIN, 0, AUTH_ADMIN);

		// Officer-on-ballot suppression check.
		$is_candidate = false;
		foreach ($event['races'] as $race) {
			foreach ($race['choices'] as $c) {
				if (!empty($c['candidate_mundane_id']) && (int)$c['candidate_mundane_id'] === (int)$this->session->user_id) {
					$is_candidate = true;
					break 2;
				}
			}
		}
		$pre_publish = in_array($event['status'], ['open', 'closed']);
		$this->data['suppress_results'] = $is_candidate && !empty($event['hide_results_from_candidate_runners']) && !$this->data['is_admin'] && $pre_publish;

		// Counts.
		global $DB;
		$DB->Clear();
		$rs = $DB->DataSet("SELECT
			SUM(CASE WHEN b.is_provisional = 0 THEN 1 ELSE 0 END) AS counted,
			SUM(CASE WHEN b.is_provisional = 1 THEN 1 ELSE 0 END) AS provisional,
			COUNT(*) AS total
			FROM " . DB_PREFIX . "voting_active_ballot ab
			JOIN " . DB_PREFIX . "voting_ballot b USING (voting_ballot_id)
			WHERE ab.voting_event_id = " . $voting_event_id);
		if ($rs && $rs->Next()) {
			$this->data['counts'] = ['counted' => (int)$rs->counted, 'provisional' => (int)$rs->provisional, 'total' => (int)$rs->total];
		} else {
			$this->data['counts'] = ['counted' => 0, 'provisional' => 0, 'total' => 0];
		}

		$this->template = '../revised-frontend/Voting_runner.tpl';
	}

	// ─────────────────────── Public results ───────────────────────

	public function results($voting_event_id = null) {
		$voting_event_id = (int)$voting_event_id;
		$r = $this->Voting->tally_public($voting_event_id);
		if (($r['Status'] ?? 1) != 0) {
			$this->data['Error'] = 'Results not yet published.';
			$this->template = '../revised-frontend/Voting_results.tpl';
			return;
		}
		$this->data['voting_event_id'] = $voting_event_id;
		$this->data['event'] = $r['Event'];
		$this->data['tally'] = $r['Tally'];
		$this->template = '../revised-frontend/Voting_results.tpl';
	}

	public function audit($voting_event_id = null) {
		$this->require_login();
		$voting_event_id = (int)$voting_event_id;
		$uid = (int)$this->session->user_id;
		if (!Ork3::$Lib->authorization->HasAuthority($uid, AUTH_ADMIN, 0, AUTH_ADMIN)) {
			header('Location: ' . UIR);
			exit;
		}
		global $DB;
		$DB->Clear();
		$rs = $DB->DataSet("SELECT a.*, m.username, m.persona FROM " . DB_PREFIX . "voting_audit a
			LEFT JOIN " . DB_PREFIX . "mundane m ON m.mundane_id = a.actor_mundane_id
			WHERE a.voting_event_id = " . $voting_event_id . " ORDER BY a.created_at DESC, a.voting_audit_id DESC LIMIT 500");
		$rows = [];
		while ($rs && $rs->Next()) $rows[] = (array)$rs;
		$this->data['rows'] = $rows;
		$this->data['voting_event_id'] = $voting_event_id;
		$this->template = '../revised-frontend/Voting_audit.tpl';
	}
}
