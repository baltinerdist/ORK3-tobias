<?php
/**
 * Voting module — DB and business logic.
 *
 * See docs/superpowers/specs/2026-05-07-voting-module-design.md
 *
 * The tally engine is exposed as a pure static method (Voting::tally_pure)
 * that takes an in-memory race definition + ballots so it can be unit-tested
 * without a database. The DB-backed Voting->tally() loads from the database
 * and delegates to tally_pure.
 */

class Voting extends Ork3 {

	public function __construct() {
		parent::__construct();
		// yapo bindings — guarded so the unit-test harness (which stubs Ork3) can include this file.
		if (isset($this->db)) {
			$this->Event       = new yapo($this->db, DB_PREFIX . 'voting_event');
			$this->Runner      = new yapo($this->db, DB_PREFIX . 'voting_runner');
			$this->Race        = new yapo($this->db, DB_PREFIX . 'voting_race');
			$this->Choice      = new yapo($this->db, DB_PREFIX . 'voting_choice');
			$this->Ballot      = new yapo($this->db, DB_PREFIX . 'voting_ballot');
			$this->ActiveBal   = new yapo($this->db, DB_PREFIX . 'voting_active_ballot');
			$this->Vote        = new yapo($this->db, DB_PREFIX . 'voting_vote');
			$this->Audit       = new yapo($this->db, DB_PREFIX . 'voting_audit');
			$this->Snap        = new yapo($this->db, DB_PREFIX . 'voting_eligibility_snapshot');
		}
	}

	// ════════════════════════════════════════════════════════════════════
	//                        VOTING RULES (per kingdom)
	// ════════════════════════════════════════════════════════════════════
	// Mirror of orkui/model/model.Reports.php::_voting_rules — kept here so
	// the class layer can resolve eligibility without depending on the model
	// layer. If/when the rules move to the DB, both copies should be replaced.

	private static $rules_by_kingdom = [
		14 => ['AttendanceRequired'=>7,'MonthsWindow'=>6,'MinMembershipMonths'=>0,'AttendanceMode'=>'count','ProvinceMode'=>false,'ActiveMemberThreshold'=>12,'AllKingdoms'=>true],
		31 => ['AttendanceRequired'=>6,'MonthsWindow'=>6,'MinMembershipMonths'=>6,'AttendanceMode'=>'weeks','ProvinceMode'=>false],
		3  => ['AttendanceRequired'=>6,'MonthsWindow'=>6,'MinMembershipMonths'=>6,'AttendanceMode'=>'weeks','ProvinceMode'=>false],
		17 => ['AttendanceRequired'=>6,'MonthsWindow'=>6,'MinMembershipMonths'=>6,'AttendanceMode'=>'count','ProvinceMode'=>true,'KingdomEventBonus'=>true],
		10 => ['AttendanceRequired'=>7,'MonthsWindow'=>6,'MinMembershipMonths'=>6,'AttendanceMode'=>'days','ProvinceMode'=>false,'MembershipMode'=>'first_attendance','WeekSnap'=>true],
		25 => ['AttendanceRequired'=>6,'MonthsWindow'=>6,'MinMembershipMonths'=>0,'AttendanceMode'=>'days','ProvinceMode'=>false,'WeekSnap'=>true],
		20 => ['AttendanceRequired'=>6,'MonthsWindow'=>6,'MinMembershipMonths'=>0,'AttendanceMode'=>'days','ProvinceMode'=>false,'ExcludeOnline'=>true,'WeekSnap'=>true],
		36 => ['AttendanceRequired'=>12,'MonthsWindow'=>0,'DaysWindow'=>180,'MinMembershipMonths'=>0,'AttendanceMode'=>'weeks','ProvinceMode'=>false,'MinAge'=>14],
		27 => ['AttendanceRequired'=>6,'MonthsWindow'=>6,'MinMembershipMonths'=>3,'AttendanceMode'=>'weeks','WeekOffset'=>6,'ProvinceMode'=>false],
		38 => ['AttendanceRequired'=>6,'MonthsWindow'=>6,'MinMembershipMonths'=>0,'AttendanceMode'=>'days','ProvinceMode'=>false,'WeekSnap'=>true],
		4  => ['AttendanceRequired'=>6,'MonthsWindow'=>6,'MinMembershipMonths'=>0,'AttendanceMode'=>'count','ProvinceMode'=>false,'HomeParkOnly'=>true,'KingdomEventBonus'=>true,'WeekSnap'=>true],
		6  => ['AttendanceRequired'=>6,'MonthsWindow'=>6,'MinMembershipMonths'=>6,'AttendanceMode'=>'weeks','WeekOffset'=>1,'ProvinceMode'=>false,'ActiveKnightThreshold'=>8],
		19 => ['AttendanceRequired'=>8,'MonthsWindow'=>6,'MinMembershipMonths'=>3,'AttendanceMode'=>'count','ProvinceMode'=>false,'MaxCreditsPerEvent'=>2,'MaxOutsideKingdomCredits'=>2],
		12 => ['AttendanceRequired'=>12,'MonthsWindow'=>6,'MinMembershipMonths'=>0,'AttendanceMode'=>'count','ProvinceMode'=>false,'ExcludeEvents'=>true,'WaiverAgeMonths'=>6],
		24 => ['AttendanceRequired'=>6,'MonthsWindow'=>6,'MinMembershipMonths'=>3,'AttendanceMode'=>'weeks','ProvinceMode'=>false,'ShowEventCount'=>true],
	];

	private static function voting_rules_for_kingdom($kingdom_id) {
		return self::$rules_by_kingdom[(int)$kingdom_id] ?? null;
	}

	private function resolve_kingdom_id($scope_type, $scope_id) {
		if ($scope_type === 'kingdom') return (int)$scope_id;
		if ($scope_type === 'park') {
			global $DB;
			$DB->Clear();
			$rs = $DB->DataSet("SELECT kingdom_id FROM " . DB_PREFIX . "park WHERE park_id = " . (int)$scope_id . " LIMIT 1");
			if ($rs && $rs->Next()) return (int)$rs->kingdom_id;
		}
		return 0;
	}

	private function check_eligibility_live($mundane_id, $scope_type, $scope_id) {
		$kingdom_id = $this->resolve_kingdom_id($scope_type, $scope_id);
		$rules = self::voting_rules_for_kingdom($kingdom_id);
		if ($rules === null) {
			return ['eligible' => false, 'provisional_possible' => false, 'rules' => []];
		}
		$report = new Report();
		$r = $report->GetVotingEligible(array_merge($rules, [
			'KingdomId' => $kingdom_id,
			'MundaneId' => (int)$mundane_id,
		]));
		$player = $r['Players'][0] ?? [];
		// "Provisional possible" = currently ineligible but only because of dues — i.e., they have enough
		// attendance but their membership status is the gating factor. The Reports check exposes
		// ActiveMember; if ActiveMember is null/false but other criteria are met, treat as provisional-possible.
		$eligible = !empty($player['VotingEligible']);
		$provisional_possible = !$eligible && !empty($player) && (
			!empty($player['AttendanceMet'] ?? false) ||
			(!empty($player['Days'] ?? 0) >= ($rules['AttendanceRequired'] ?? PHP_INT_MAX))
		);
		return [
			'eligible' => $eligible,
			'provisional_possible' => $provisional_possible,
			'rules' => $rules,
			'player' => $player,
		];
	}

	// ════════════════════════════════════════════════════════════════════
	//                        AUTHORIZATION HELPERS
	// ════════════════════════════════════════════════════════════════════

	private function user_can_run_in_scope($mundane_id, $scope_type, $scope_id) {
		if (!valid_id($mundane_id)) return false;
		$auth = Ork3::$Lib->authorization;
		if ($auth->HasAuthority($mundane_id, AUTH_ADMIN, 0, AUTH_ADMIN)) return true;
		$auth_type = $scope_type === 'kingdom' ? AUTH_KINGDOM : AUTH_PARK;
		return $auth->HasAuthority($mundane_id, $auth_type, (int)$scope_id, AUTH_EDIT);
	}

	private function user_is_runner_of_event($mundane_id, $voting_event_id) {
		if (!valid_id($mundane_id)) return false;
		$auth = Ork3::$Lib->authorization;
		if ($auth->HasAuthority($mundane_id, AUTH_ADMIN, 0, AUTH_ADMIN)) return true;
		// Explicit runner row?
		global $DB;
		$DB->Clear();
		$rs = $DB->DataSet("SELECT mundane_id FROM " . DB_PREFIX . "voting_runner WHERE voting_event_id = " . (int)$voting_event_id . " AND mundane_id = " . (int)$mundane_id . " LIMIT 1");
		if ($rs && $rs->Next()) return true;
		// Otherwise, sitting officer of the event scope.
		$DB->Clear();
		$ev = $DB->DataSet("SELECT scope_type, scope_id FROM " . DB_PREFIX . "voting_event WHERE voting_event_id = " . (int)$voting_event_id . " LIMIT 1");
		if (!$ev || !$ev->Next()) return false;
		return $this->user_can_run_in_scope($mundane_id, $ev->scope_type, $ev->scope_id);
	}

	private function user_is_candidate_in_event($mundane_id, $voting_event_id) {
		if (!valid_id($mundane_id)) return false;
		global $DB;
		$DB->Clear();
		$rs = $DB->DataSet("SELECT 1 FROM " . DB_PREFIX . "voting_choice c
			JOIN " . DB_PREFIX . "voting_race r USING (voting_race_id)
			WHERE r.voting_event_id = " . (int)$voting_event_id . "
			  AND c.candidate_mundane_id = " . (int)$mundane_id . "
			LIMIT 1");
		return $rs && $rs->Next();
	}

	// ════════════════════════════════════════════════════════════════════
	//                              AUDIT
	// ════════════════════════════════════════════════════════════════════

	private function audit($voting_event_id, $action, $detail = null, $actor_mundane_id = null) {
		global $DB;
		$DB->Clear();
		$DB->Execute(
			"INSERT INTO " . DB_PREFIX . "voting_audit (voting_event_id, actor_mundane_id, action, detail, created_at) VALUES (?, ?, ?, ?, NOW())",
			[(int)$voting_event_id, $actor_mundane_id !== null ? (int)$actor_mundane_id : null, (string)$action, $detail !== null ? json_encode($detail) : null]
		);
		$DB->Clear();
	}

	// ════════════════════════════════════════════════════════════════════
	//                          EVENT / RACE CRUD
	// ════════════════════════════════════════════════════════════════════

	public function CreateEvent($request) {
		$mundane_id = Ork3::$Lib->authorization->IsAuthorized($request['Token']);
		if (!valid_id($mundane_id)) return NoAuthorization();

		$scope_type = $request['ScopeType'] ?? null;
		$scope_id   = (int)($request['ScopeId'] ?? 0);
		$event_type = $request['EventType'] ?? null;
		if (!in_array($scope_type, ['kingdom','park']) || !$scope_id) return InvalidParameter();
		if (!in_array($event_type, ['election','althing'])) return InvalidParameter();
		if (!$this->user_can_run_in_scope($mundane_id, $scope_type, $scope_id)) return NoAuthorization();

		$this->Event->clear();
		$this->Event->event_type = $event_type;
		$this->Event->scope_type = $scope_type;
		$this->Event->scope_id   = $scope_id;
		$this->Event->title      = trim($request['Title'] ?? '');
		$this->Event->description = $request['Description'] ?? '';
		$this->Event->start_date = $request['StartDate'];
		$this->Event->end_date   = $request['EndDate'];
		$this->Event->anonymous_to_runner = !empty($request['AnonymousToRunner']) ? 1 : 0;
		$this->Event->hide_results_from_candidate_runners = !empty($request['HideResultsFromCandidateRunners']) ? 1 : 0;
		$this->Event->allow_provisional = !empty($request['AllowProvisional']) ? 1 : 0;
		$this->Event->status = 'draft';
		$this->Event->created_by_mundane_id = $mundane_id;
		$this->Event->save();

		$voting_event_id = $this->Event->voting_event_id;
		$this->audit($voting_event_id, 'event_created', ['title' => $this->Event->title], $mundane_id);
		return Success($voting_event_id);
	}

	public function UpdateEvent($request) {
		$mundane_id = Ork3::$Lib->authorization->IsAuthorized($request['Token']);
		if (!valid_id($mundane_id)) return NoAuthorization();
		$voting_event_id = (int)($request['VotingEventId'] ?? 0);
		if (!$voting_event_id) return InvalidParameter();
		if (!$this->user_is_runner_of_event($mundane_id, $voting_event_id)) return NoAuthorization();

		$this->Event->clear();
		$this->Event->voting_event_id = $voting_event_id;
		if (!$this->Event->find()) return InvalidParameter();
		if ($this->Event->status !== 'draft') return ProcessingError('', 'Only draft events can be edited.');

		$diff = [];
		foreach (['Title' => 'title', 'Description' => 'description', 'StartDate' => 'start_date', 'EndDate' => 'end_date',
				 'AnonymousToRunner' => 'anonymous_to_runner', 'HideResultsFromCandidateRunners' => 'hide_results_from_candidate_runners',
				 'AllowProvisional' => 'allow_provisional'] as $k => $col) {
			if (array_key_exists($k, $request)) {
				$old = $this->Event->$col;
				$new = (in_array($col, ['anonymous_to_runner','hide_results_from_candidate_runners','allow_provisional'])) ? (!empty($request[$k]) ? 1 : 0) : $request[$k];
				if ((string)$old !== (string)$new) { $diff[$col] = ['from' => $old, 'to' => $new]; $this->Event->$col = $new; }
			}
		}
		if (!empty($diff)) {
			$this->Event->save();
			$this->audit($voting_event_id, 'event_updated', $diff, $mundane_id);
		}
		return Success($voting_event_id);
	}

	public function AddRace($request) {
		$mundane_id = Ork3::$Lib->authorization->IsAuthorized($request['Token']);
		if (!valid_id($mundane_id)) return NoAuthorization();
		$voting_event_id = (int)($request['VotingEventId'] ?? 0);
		if (!$voting_event_id) return InvalidParameter();
		if (!$this->user_is_runner_of_event($mundane_id, $voting_event_id)) return NoAuthorization();

		$this->Event->clear();
		$this->Event->voting_event_id = $voting_event_id;
		if (!$this->Event->find()) return InvalidParameter();
		if ($this->Event->status !== 'draft') return ProcessingError('', 'Cannot add races after event is open.');

		$race_type = $request['RaceType'] ?? null;
		if (!in_array($race_type, ['position','yesno','multichoice'])) return InvalidParameter();

		$voting_mode = $request['VotingMode'] ?? 'plurality';
		if ($race_type === 'yesno') $voting_mode = 'majority';
		if ($race_type === 'multichoice') $voting_mode = 'plurality';

		$this->Race->clear();
		$this->Race->voting_event_id = $voting_event_id;
		$this->Race->race_type = $race_type;
		$this->Race->voting_mode = $voting_mode;
		$this->Race->title = trim($request['Title'] ?? '');
		$this->Race->rationale = $request['Rationale'] ?? '';
		$this->Race->position_id = (int)($request['PositionId'] ?? 0) ?: null;
		$this->Race->allow_abstain = !empty($request['AllowAbstain']) ? 1 : 0;
		$this->Race->allow_none_of_above = !empty($request['AllowNoneOfAbove']) ? 1 : 0;
		$this->Race->nota_counts_as = in_array($request['NotaCountsAs'] ?? null, ['no','abstain']) ? $request['NotaCountsAs'] : null;
		$this->Race->is_non_binding = !empty($request['IsNonBinding']) ? 1 : 0;
		$this->Race->display_order = (int)($request['DisplayOrder'] ?? 0);
		$this->Race->save();

		$voting_race_id = $this->Race->voting_race_id;

		// For yesno races, auto-create the Yes and No choices.
		if ($race_type === 'yesno') {
			foreach (['Yes', 'No'] as $i => $label) {
				$this->Choice->clear();
				$this->Choice->voting_race_id = $voting_race_id;
				$this->Choice->label = $label;
				$this->Choice->display_order = $i;
				$this->Choice->save();
			}
		}

		$this->audit($voting_event_id, 'race_created', ['race_id' => $voting_race_id, 'title' => $this->Race->title, 'race_type' => $race_type], $mundane_id);
		return Success($voting_race_id);
	}

	public function AddCandidate($request) {
		$mundane_id = Ork3::$Lib->authorization->IsAuthorized($request['Token']);
		if (!valid_id($mundane_id)) return NoAuthorization();
		$voting_race_id = (int)($request['VotingRaceId'] ?? 0);
		$candidate_mundane_id = (int)($request['CandidateMundaneId'] ?? 0);
		if (!$voting_race_id || !valid_id($candidate_mundane_id)) return InvalidParameter();

		$this->Race->clear();
		$this->Race->voting_race_id = $voting_race_id;
		if (!$this->Race->find()) return InvalidParameter();
		if ($this->Race->race_type !== 'position') return InvalidParameter();
		if (!$this->user_is_runner_of_event($mundane_id, $this->Race->voting_event_id)) return NoAuthorization();

		$this->Event->clear();
		$this->Event->voting_event_id = $this->Race->voting_event_id;
		$this->Event->find();
		if ($this->Event->status !== 'draft') return ProcessingError('', 'Cannot add candidates after event is open.');

		// Snapshot the candidate's name into the label.
		$mundane = new yapo($this->db, DB_PREFIX . 'mundane');
		$mundane->mundane_id = $candidate_mundane_id;
		if (!$mundane->find()) return InvalidParameter();
		$label = trim(($mundane->persona ?: ($mundane->given_name . ' ' . $mundane->surname)));

		$this->Choice->clear();
		$this->Choice->voting_race_id = $voting_race_id;
		$this->Choice->candidate_mundane_id = $candidate_mundane_id;
		$this->Choice->label = $label ?: ('Mundane #' . $candidate_mundane_id);
		// Append to end.
		global $DB;
		$DB->Clear();
		$rs = $DB->DataSet("SELECT MAX(display_order) AS maxo FROM " . DB_PREFIX . "voting_choice WHERE voting_race_id = " . $voting_race_id);
		$next_order = ($rs && $rs->Next()) ? ((int)$rs->maxo + 1) : 0;
		$this->Choice->display_order = $next_order;
		$this->Choice->save();

		$this->audit($this->Race->voting_event_id, 'candidate_added',
			['race_id' => $voting_race_id, 'candidate_mundane_id' => $candidate_mundane_id, 'label' => $this->Choice->label],
			$mundane_id);
		return Success($this->Choice->voting_choice_id);
	}

	public function AddOption($request) {
		$mundane_id = Ork3::$Lib->authorization->IsAuthorized($request['Token']);
		if (!valid_id($mundane_id)) return NoAuthorization();
		$voting_race_id = (int)($request['VotingRaceId'] ?? 0);
		$label = trim($request['Label'] ?? '');
		if (!$voting_race_id || $label === '') return InvalidParameter();

		$this->Race->clear();
		$this->Race->voting_race_id = $voting_race_id;
		if (!$this->Race->find()) return InvalidParameter();
		if ($this->Race->race_type !== 'multichoice') return InvalidParameter();
		if (!$this->user_is_runner_of_event($mundane_id, $this->Race->voting_event_id)) return NoAuthorization();

		$this->Event->clear();
		$this->Event->voting_event_id = $this->Race->voting_event_id;
		$this->Event->find();
		if ($this->Event->status !== 'draft') return ProcessingError('', 'Cannot add options after event is open.');

		global $DB;
		$DB->Clear();
		$rs = $DB->DataSet("SELECT MAX(display_order) AS maxo FROM " . DB_PREFIX . "voting_choice WHERE voting_race_id = " . $voting_race_id);
		$next_order = ($rs && $rs->Next()) ? ((int)$rs->maxo + 1) : 0;

		$this->Choice->clear();
		$this->Choice->voting_race_id = $voting_race_id;
		$this->Choice->label = $label;
		$this->Choice->display_order = $next_order;
		$this->Choice->save();
		return Success($this->Choice->voting_choice_id);
	}

	public function RemoveChoice($request) {
		$mundane_id = Ork3::$Lib->authorization->IsAuthorized($request['Token']);
		if (!valid_id($mundane_id)) return NoAuthorization();
		$voting_choice_id = (int)($request['VotingChoiceId'] ?? 0);
		if (!$voting_choice_id) return InvalidParameter();

		$this->Choice->clear();
		$this->Choice->voting_choice_id = $voting_choice_id;
		if (!$this->Choice->find()) return InvalidParameter();
		$voting_race_id = (int)$this->Choice->voting_race_id;
		$candidate_mundane_id = $this->Choice->candidate_mundane_id ? (int)$this->Choice->candidate_mundane_id : null;
		$label = $this->Choice->label;

		$this->Race->clear();
		$this->Race->voting_race_id = $voting_race_id;
		if (!$this->Race->find()) return InvalidParameter();
		$voting_event_id = (int)$this->Race->voting_event_id;
		if (!$this->user_is_runner_of_event($mundane_id, $voting_event_id)) return NoAuthorization();

		$this->Event->clear();
		$this->Event->voting_event_id = $voting_event_id;
		$this->Event->find();
		if ($this->Event->status !== 'draft') return ProcessingError('', 'Choices can only be removed while the event is in draft.');

		// Yes/No race choices are auto-created and required; never let a runner delete them.
		if ($this->Race->race_type === 'yesno') return ProcessingError('', 'Yes/No choices cannot be removed.');

		global $DB;
		if ($this->choice_has_votes($voting_choice_id)) {
			// Soft-withdraw: preserve row + votes for results display; runner picks Keep/Discard at Resume.
			$DB->Clear();
			$DB->Execute("UPDATE " . DB_PREFIX . "voting_choice SET withdrawn_at = NOW(), withdrawn_by_mundane_id = " . (int)$mundane_id . " WHERE voting_choice_id = " . $voting_choice_id);
			$DB->Clear();
			$this->audit($voting_event_id, 'candidate_withdrawn',
				['race_id' => $voting_race_id, 'choice_id' => $voting_choice_id, 'candidate_mundane_id' => $candidate_mundane_id, 'label' => $label],
				$mundane_id);
			return Success($voting_choice_id);
		}

		$DB->Clear();
		$DB->Execute("DELETE FROM " . DB_PREFIX . "voting_choice WHERE voting_choice_id = " . $voting_choice_id);
		$DB->Clear();

		$this->audit($voting_event_id, 'candidate_removed',
			['race_id' => $voting_race_id, 'choice_id' => $voting_choice_id, 'candidate_mundane_id' => $candidate_mundane_id, 'label' => $label],
			$mundane_id);
		return Success($voting_choice_id);
	}

	public function OpenEvent($request) {
		$mundane_id = Ork3::$Lib->authorization->IsAuthorized($request['Token']);
		if (!valid_id($mundane_id)) return NoAuthorization();
		$voting_event_id = (int)($request['VotingEventId'] ?? 0);
		if (!$voting_event_id) return InvalidParameter();
		if (!$this->user_is_runner_of_event($mundane_id, $voting_event_id)) return NoAuthorization();

		$this->Event->clear();
		$this->Event->voting_event_id = $voting_event_id;
		if (!$this->Event->find()) return InvalidParameter();
		if ($this->Event->status !== 'draft') return ProcessingError('', 'Event is not in draft.');

		// Validate every race has at least one choice (position) or 2+ choices (multichoice).
		global $DB;
		$DB->Clear();
		$rs = $DB->DataSet("SELECT r.voting_race_id, r.race_type, r.title, COUNT(c.voting_choice_id) AS n
			FROM " . DB_PREFIX . "voting_race r LEFT JOIN " . DB_PREFIX . "voting_choice c USING (voting_race_id)
			WHERE r.voting_event_id = " . $voting_event_id . " GROUP BY r.voting_race_id");
		$errors = [];
		while ($rs && $rs->Next()) {
			$min = $rs->race_type === 'multichoice' ? 2 : 1;
			if ((int)$rs->n < $min) $errors[] = "Race '{$rs->title}' needs at least $min choice(s).";
		}
		if (!empty($errors)) return ProcessingError(implode(' ', $errors), 'Cannot open event');

		$this->Event->status = 'open';
		$this->Event->save();
		$this->audit($voting_event_id, 'event_updated', ['status' => 'open'], $mundane_id);
		return Success($voting_event_id);
	}

	// ════════════════════════════════════════════════════════════════════
	//                        REOPEN / EDIT / RESUME
	// ════════════════════════════════════════════════════════════════════

	private function race_has_votes($voting_race_id) {
		global $DB;
		$DB->Clear();
		$rs = $DB->DataSet("SELECT 1 FROM " . DB_PREFIX . "voting_vote v
			JOIN " . DB_PREFIX . "voting_ballot b ON b.voting_ballot_id = v.voting_ballot_id
			WHERE v.voting_race_id = " . (int)$voting_race_id . "
			  AND b.superseded_by_ballot_id IS NULL
			LIMIT 1");
		return $rs && $rs->Next();
	}

	private function choice_has_votes($voting_choice_id) {
		global $DB;
		$DB->Clear();
		$rs = $DB->DataSet("SELECT 1 FROM " . DB_PREFIX . "voting_vote v
			JOIN " . DB_PREFIX . "voting_ballot b ON b.voting_ballot_id = v.voting_ballot_id
			WHERE v.voting_choice_id = " . (int)$voting_choice_id . "
			  AND b.superseded_by_ballot_id IS NULL
			LIMIT 1");
		return $rs && $rs->Next();
	}

	private function event_has_votes($voting_event_id) {
		global $DB;
		$DB->Clear();
		$rs = $DB->DataSet("SELECT 1 FROM " . DB_PREFIX . "voting_ballot
			WHERE voting_event_id = " . (int)$voting_event_id . "
			  AND superseded_by_ballot_id IS NULL
			LIMIT 1");
		return $rs && $rs->Next();
	}

	public function ReopenEvent($request) {
		$mundane_id = Ork3::$Lib->authorization->IsAuthorized($request['Token']);
		if (!valid_id($mundane_id)) return NoAuthorization();
		$voting_event_id = (int)($request['VotingEventId'] ?? 0);
		if (!$voting_event_id) return InvalidParameter();
		if (!$this->user_is_runner_of_event($mundane_id, $voting_event_id)) return NoAuthorization();

		$this->Event->clear();
		$this->Event->voting_event_id = $voting_event_id;
		if (!$this->Event->find()) return InvalidParameter();
		if ($this->Event->status !== 'open') return ProcessingError('', 'Only open events can be reopened.');

		$has_votes = $this->event_has_votes($voting_event_id);
		if ($has_votes && empty($request['Confirm'])) {
			return ProcessingError('confirm_required', 'Changing the configuration of this voting event may invalidate current votes. Continue?');
		}

		$this->Event->status = 'draft';
		$this->Event->reopened_at = date('Y-m-d H:i:s');
		$this->Event->reopened_by_mundane_id = $mundane_id;
		$this->Event->save();

		$this->audit($voting_event_id, 'event_reopened', ['had_votes' => $has_votes ? 1 : 0], $mundane_id);
		return Success($voting_event_id);
	}

	public function EditRace($request) {
		$mundane_id = Ork3::$Lib->authorization->IsAuthorized($request['Token']);
		if (!valid_id($mundane_id)) return NoAuthorization();
		$voting_race_id = (int)($request['VotingRaceId'] ?? 0);
		if (!$voting_race_id) return InvalidParameter();

		$this->Race->clear();
		$this->Race->voting_race_id = $voting_race_id;
		if (!$this->Race->find()) return InvalidParameter();
		if (!$this->user_is_runner_of_event($mundane_id, $this->Race->voting_event_id)) return NoAuthorization();

		$this->Event->clear();
		$this->Event->voting_event_id = $this->Race->voting_event_id;
		$this->Event->find();
		if ($this->Event->status !== 'draft') return ProcessingError('', 'Race wording can only be edited while the event is in draft.');

		$new_title = isset($request['Title']) ? trim($request['Title']) : null;
		$new_rat   = $request['Rationale'] ?? null;
		$has_votes = $this->race_has_votes($voting_race_id);

		$diff = [];
		if ($new_title !== null && $new_title !== '' && $new_title !== $this->Race->title) {
			if ($has_votes && (string)$this->Race->original_title === '') {
				$this->Race->original_title = $this->Race->title;
			}
			$diff['title'] = ['from' => $this->Race->title, 'to' => $new_title];
			$this->Race->title = $new_title;
		}
		if ($new_rat !== null && $new_rat !== $this->Race->rationale) {
			if ($has_votes && (string)$this->Race->original_rationale === '') {
				$this->Race->original_rationale = $this->Race->rationale;
			}
			$diff['rationale'] = ['from' => $this->Race->rationale, 'to' => $new_rat];
			$this->Race->rationale = $new_rat;
		}
		if (empty($diff)) return Success($voting_race_id);

		$this->Race->save();
		$this->audit($this->Race->voting_event_id, 'race_wording_edited',
			array_merge(['race_id' => $voting_race_id, 'had_votes' => $has_votes ? 1 : 0], $diff), $mundane_id);
		return Success($voting_race_id);
	}

	public function EditChoice($request) {
		$mundane_id = Ork3::$Lib->authorization->IsAuthorized($request['Token']);
		if (!valid_id($mundane_id)) return NoAuthorization();
		$voting_choice_id = (int)($request['VotingChoiceId'] ?? 0);
		$new_label = trim($request['Label'] ?? '');
		if (!$voting_choice_id || $new_label === '') return InvalidParameter();

		$this->Choice->clear();
		$this->Choice->voting_choice_id = $voting_choice_id;
		if (!$this->Choice->find()) return InvalidParameter();

		$this->Race->clear();
		$this->Race->voting_race_id = $this->Choice->voting_race_id;
		if (!$this->Race->find()) return InvalidParameter();
		if ($this->Race->race_type !== 'multichoice') return ProcessingError('', 'Only multichoice option labels are editable.');
		if (!$this->user_is_runner_of_event($mundane_id, $this->Race->voting_event_id)) return NoAuthorization();

		$this->Event->clear();
		$this->Event->voting_event_id = $this->Race->voting_event_id;
		$this->Event->find();
		if ($this->Event->status !== 'draft') return ProcessingError('', 'Option labels can only be edited while the event is in draft.');

		if ($new_label === $this->Choice->label) return Success($voting_choice_id);

		if ($this->choice_has_votes($voting_choice_id) && (string)$this->Choice->original_label === '') {
			$this->Choice->original_label = $this->Choice->label;
		}
		$old_label = $this->Choice->label;
		$this->Choice->label = $new_label;
		$this->Choice->save();

		$this->audit($this->Race->voting_event_id, 'choice_label_edited',
			['choice_id' => $voting_choice_id, 'race_id' => (int)$this->Race->voting_race_id, 'from' => $old_label, 'to' => $new_label], $mundane_id);
		return Success($voting_choice_id);
	}

	public function RestoreChoice($request) {
		$mundane_id = Ork3::$Lib->authorization->IsAuthorized($request['Token']);
		if (!valid_id($mundane_id)) return NoAuthorization();
		$voting_choice_id = (int)($request['VotingChoiceId'] ?? 0);
		if (!$voting_choice_id) return InvalidParameter();

		$this->Choice->clear();
		$this->Choice->voting_choice_id = $voting_choice_id;
		if (!$this->Choice->find()) return InvalidParameter();
		$this->Race->clear();
		$this->Race->voting_race_id = $this->Choice->voting_race_id;
		$this->Race->find();
		if (!$this->user_is_runner_of_event($mundane_id, $this->Race->voting_event_id)) return NoAuthorization();

		$this->Event->clear();
		$this->Event->voting_event_id = $this->Race->voting_event_id;
		$this->Event->find();
		if ($this->Event->status !== 'draft') return ProcessingError('', 'Choices can only be restored while the event is in draft.');

		if (!$this->Choice->withdrawn_at) return Success($voting_choice_id);
		global $DB;
		$DB->Clear();
		$DB->Execute("UPDATE " . DB_PREFIX . "voting_choice SET withdrawn_at = NULL, withdrawn_by_mundane_id = NULL WHERE voting_choice_id = " . (int)$voting_choice_id);
		$DB->Clear();

		$this->audit($this->Race->voting_event_id, 'candidate_restored',
			['choice_id' => $voting_choice_id, 'race_id' => (int)$this->Race->voting_race_id, 'label' => $this->Choice->label], $mundane_id);
		return Success($voting_choice_id);
	}

	public function RemoveRace($request) {
		$mundane_id = Ork3::$Lib->authorization->IsAuthorized($request['Token']);
		if (!valid_id($mundane_id)) return NoAuthorization();
		$voting_race_id = (int)($request['VotingRaceId'] ?? 0);
		if (!$voting_race_id) return InvalidParameter();

		$this->Race->clear();
		$this->Race->voting_race_id = $voting_race_id;
		if (!$this->Race->find()) return InvalidParameter();
		if (!$this->user_is_runner_of_event($mundane_id, $this->Race->voting_event_id)) return NoAuthorization();

		$this->Event->clear();
		$this->Event->voting_event_id = $this->Race->voting_event_id;
		$this->Event->find();
		if ($this->Event->status !== 'draft') return ProcessingError('', 'Races can only be removed while the event is in draft.');

		if ($this->race_has_votes($voting_race_id)) {
			return ProcessingError('', 'This race has votes. Remove its choices individually, then choose Discard at Resume.');
		}

		$voting_event_id = (int)$this->Race->voting_event_id;
		$title = $this->Race->title;
		global $DB;
		$DB->Clear();
		$DB->Execute("DELETE FROM " . DB_PREFIX . "voting_race WHERE voting_race_id = " . (int)$voting_race_id);
		$DB->Clear();

		$this->audit($voting_event_id, 'race_removed', ['race_id' => $voting_race_id, 'title' => $title], $mundane_id);
		return Success($voting_race_id);
	}

	public function PreviewResume($voting_event_id) {
		$voting_event_id = (int)$voting_event_id;
		if (!$voting_event_id) return ['impacts' => [], 'requires_decision' => false];
		global $DB;

		$DB->Clear();
		$rs = $DB->DataSet("SELECT voting_event_id, status, reopened_at FROM " . DB_PREFIX . "voting_event WHERE voting_event_id = " . $voting_event_id);
		if (!$rs || !$rs->Next()) return ['impacts' => [], 'requires_decision' => false];
		if ($rs->status !== 'draft' || !$rs->reopened_at) return ['impacts' => [], 'requires_decision' => false];
		$reopened_at = $rs->reopened_at;

		$impacts = [];

		$DB->Clear();
		$rs = $DB->DataSet("SELECT c.voting_choice_id, c.voting_race_id, c.label,
				r.title AS race_title,
				(SELECT COUNT(*) FROM " . DB_PREFIX . "voting_vote v
				 JOIN " . DB_PREFIX . "voting_ballot b ON b.voting_ballot_id = v.voting_ballot_id
				 WHERE v.voting_choice_id = c.voting_choice_id AND b.superseded_by_ballot_id IS NULL) AS vote_count
			FROM " . DB_PREFIX . "voting_choice c
			JOIN " . DB_PREFIX . "voting_race r USING (voting_race_id)
			WHERE r.voting_event_id = " . $voting_event_id . "
			  AND c.withdrawn_at IS NOT NULL");
		while ($rs && $rs->Next()) {
			$impacts[] = ['kind' => 'choice_withdrawn',
				'race_id' => (int)$rs->voting_race_id, 'race_title' => $rs->race_title,
				'choice_id' => (int)$rs->voting_choice_id, 'label' => $rs->label,
				'vote_count' => (int)$rs->vote_count];
		}

		$DB->Clear();
		$rs = $DB->DataSet("SELECT c.voting_choice_id, c.voting_race_id, c.original_label, c.label, r.title AS race_title,
				(SELECT COUNT(*) FROM " . DB_PREFIX . "voting_vote v
				 JOIN " . DB_PREFIX . "voting_ballot b ON b.voting_ballot_id = v.voting_ballot_id
				 WHERE v.voting_choice_id = c.voting_choice_id AND b.superseded_by_ballot_id IS NULL) AS vote_count
			FROM " . DB_PREFIX . "voting_choice c
			JOIN " . DB_PREFIX . "voting_race r USING (voting_race_id)
			WHERE r.voting_event_id = " . $voting_event_id . "
			  AND c.original_label IS NOT NULL");
		while ($rs && $rs->Next()) {
			$impacts[] = ['kind' => 'choice_label_edited',
				'race_id' => (int)$rs->voting_race_id, 'race_title' => $rs->race_title,
				'choice_id' => (int)$rs->voting_choice_id, 'from' => $rs->original_label, 'to' => $rs->label,
				'vote_count' => (int)$rs->vote_count];
		}

		$DB->Clear();
		$rs = $DB->DataSet("SELECT r.voting_race_id, r.title, r.rationale, r.original_title, r.original_rationale
			FROM " . DB_PREFIX . "voting_race r
			WHERE r.voting_event_id = " . $voting_event_id . "
			  AND (r.original_title IS NOT NULL OR r.original_rationale IS NOT NULL)");
		while ($rs && $rs->Next()) {
			$impacts[] = ['kind' => 'race_wording_edited',
				'race_id' => (int)$rs->voting_race_id, 'race_title' => $rs->title,
				'original_title' => $rs->original_title, 'current_title' => $rs->title,
				'original_rationale' => $rs->original_rationale, 'current_rationale' => $rs->rationale];
		}

		// Choices added during reopen on a race that already has votes from the pre-reopen window.
		$DB->Clear();
		$rs = $DB->DataSet("SELECT c.voting_choice_id, c.voting_race_id, c.label, r.title AS race_title
			FROM " . DB_PREFIX . "voting_choice c
			JOIN " . DB_PREFIX . "voting_race r USING (voting_race_id)
			WHERE r.voting_event_id = " . $voting_event_id . "
			  AND c.withdrawn_at IS NULL
			  AND c.original_label IS NULL
			  AND EXISTS (
			  	SELECT 1 FROM " . DB_PREFIX . "voting_vote v
				JOIN " . DB_PREFIX . "voting_ballot b ON b.voting_ballot_id = v.voting_ballot_id
				WHERE v.voting_race_id = c.voting_race_id
				  AND b.superseded_by_ballot_id IS NULL
				  AND b.submitted_at < '" . addslashes($reopened_at) . "'
			  )
			  AND NOT EXISTS (
			  	SELECT 1 FROM " . DB_PREFIX . "voting_vote v2
				WHERE v2.voting_choice_id = c.voting_choice_id
			  )");
		while ($rs && $rs->Next()) {
			$impacts[] = ['kind' => 'choice_added',
				'race_id' => (int)$rs->voting_race_id, 'race_title' => $rs->race_title,
				'choice_id' => (int)$rs->voting_choice_id, 'label' => $rs->label];
		}

		return ['impacts' => $impacts, 'requires_decision' => !empty($impacts)];
	}

	public function ResumeEvent($request) {
		$mundane_id = Ork3::$Lib->authorization->IsAuthorized($request['Token']);
		if (!valid_id($mundane_id)) return NoAuthorization();
		$voting_event_id = (int)($request['VotingEventId'] ?? 0);
		$decision = $request['Decision'] ?? '';
		if (!$voting_event_id) return InvalidParameter();
		if (!$this->user_is_runner_of_event($mundane_id, $voting_event_id)) return NoAuthorization();

		$this->Event->clear();
		$this->Event->voting_event_id = $voting_event_id;
		if (!$this->Event->find()) return InvalidParameter();
		if ($this->Event->status !== 'draft' || !$this->Event->reopened_at) {
			return ProcessingError('', 'Event is not in a reopened state.');
		}
		if (strtotime($this->Event->end_date) < time()) {
			return ProcessingError('', 'Voting end date is in the past — update End Date before resuming.');
		}

		$preview = $this->PreviewResume($voting_event_id);
		$requires = !empty($preview['requires_decision']);

		if ($requires && !in_array($decision, ['keep', 'discard'], true)) {
			return ProcessingError('decision_required', 'Choose Keep or Discard.');
		}

		global $DB;
		if ($requires && $decision === 'discard') {
			$impacted_race_ids = [];
			foreach ($preview['impacts'] as $imp) {
				$impacted_race_ids[(int)$imp['race_id']] = true;
			}
			$ids = array_keys($impacted_race_ids);
			$DB->Clear();
			$DB->Execute("START TRANSACTION");
			if (!empty($ids)) {
				$in = implode(',', array_map('intval', $ids));
				$DB->Clear();
				$DB->Execute("DELETE FROM " . DB_PREFIX . "voting_vote WHERE voting_race_id IN ({$in})");
				$DB->Clear();
				$DB->Execute("DELETE FROM " . DB_PREFIX . "voting_choice WHERE voting_race_id IN ({$in}) AND withdrawn_at IS NOT NULL");
				$DB->Clear();
				$DB->Execute("UPDATE " . DB_PREFIX . "voting_race SET original_title = NULL, original_rationale = NULL WHERE voting_race_id IN ({$in})");
				$DB->Clear();
				$DB->Execute("UPDATE " . DB_PREFIX . "voting_choice SET original_label = NULL WHERE voting_race_id IN ({$in})");
				$DB->Clear();
			}
			$DB->Execute("UPDATE " . DB_PREFIX . "voting_event SET status = 'open', reopened_at = NULL, reopened_by_mundane_id = NULL WHERE voting_event_id = " . $voting_event_id);
			$DB->Clear();
			$DB->Execute("COMMIT");
			$DB->Clear();
			$this->audit($voting_event_id, 'event_resumed_discard',
				['impact_count' => count($preview['impacts']), 'impacted_races' => $ids], $mundane_id);
		} else {
			$DB->Clear();
			$DB->Execute("UPDATE " . DB_PREFIX . "voting_event SET status = 'open', reopened_at = NULL, reopened_by_mundane_id = NULL WHERE voting_event_id = " . $voting_event_id);
			$DB->Clear();
			$this->audit($voting_event_id, 'event_resumed_keep',
				['impact_count' => count($preview['impacts'])], $mundane_id);
		}
		return Success($voting_event_id);
	}

		// ════════════════════════════════════════════════════════════════════
	//                        BALLOT CASTING
	// ════════════════════════════════════════════════════════════════════

	/**
	 * CastBallot. Required: Token, VotingEventId, Votes (array of per-race vote arrays).
	 * Optional: VoterMundaneId (for runner-entered external ballots), EnteredByRunnerId.
	 *
	 * Vote item shape (one entry per race the voter is voting in):
	 *   ['VotingRaceId' => N, 'ChoiceIds' => [N|null, ...], 'IsAbstain' => 0|1, 'IsNoneOfAbove' => 0|1]
	 *   - IRV: ChoiceIds is an ordered array ([first_pref_id, second_pref_id, ...]).
	 *   - Single-select: ChoiceIds is an array with exactly one element (or empty for abstain/NOTA).
	 */
	public function CastBallot($request) {
		$actor_mundane_id = Ork3::$Lib->authorization->IsAuthorized($request['Token']);
		if (!valid_id($actor_mundane_id)) return NoAuthorization();

		$voting_event_id = (int)($request['VotingEventId'] ?? 0);
		if (!$voting_event_id) return InvalidParameter();

		$voter_mundane_id = (int)($request['VoterMundaneId'] ?? $actor_mundane_id);
		$entered_by_runner_id = isset($request['EnteredByRunnerId']) ? (int)$request['EnteredByRunnerId'] : null;
		$is_runner_entry = $voter_mundane_id !== $actor_mundane_id;

		if ($is_runner_entry) {
			if (!$this->user_is_runner_of_event($actor_mundane_id, $voting_event_id)) return NoAuthorization();
			$entered_by_runner_id = $actor_mundane_id;
		}

		$this->Event->clear();
		$this->Event->voting_event_id = $voting_event_id;
		if (!$this->Event->find()) return InvalidParameter();
		if ($this->Event->status !== 'open') return ProcessingError('', 'Voting is not open.');
		if (strtotime($this->Event->end_date) < time()) return ProcessingError('', 'Voting has closed.');

		// Eligibility check.
		$elig = $this->check_eligibility_live($voter_mundane_id, $this->Event->scope_type, $this->Event->scope_id);
		$is_provisional = 0;
		if (!$elig['eligible']) {
			if (!empty($this->Event->allow_provisional) && $elig['provisional_possible']) {
				$is_provisional = 1;
			} else {
				return ProcessingError('', 'Not eligible to vote in this event.');
			}
		}

		// Load races + choices for validation.
		global $DB;
		$DB->Clear();
		$rs = $DB->DataSet("SELECT r.voting_race_id, r.race_type, r.voting_mode, r.allow_abstain, r.allow_none_of_above,
			(SELECT COUNT(*) FROM " . DB_PREFIX . "voting_choice WHERE voting_race_id = r.voting_race_id) AS choice_count
			FROM " . DB_PREFIX . "voting_race r WHERE r.voting_event_id = " . $voting_event_id);
		$races_by_id = [];
		while ($rs && $rs->Next()) {
			$races_by_id[(int)$rs->voting_race_id] = [
				'race_type' => $rs->race_type, 'voting_mode' => $rs->voting_mode,
				'allow_abstain' => (int)$rs->allow_abstain, 'allow_none_of_above' => (int)$rs->allow_none_of_above,
				'choice_count' => (int)$rs->choice_count,
			];
		}

		// Validate every vote item.
		$votes_in = $request['Votes'] ?? [];
		if (!is_array($votes_in) || empty($votes_in)) return ProcessingError('', 'No votes submitted.');
		foreach ($votes_in as $vi) {
			$rid = (int)($vi['VotingRaceId'] ?? 0);
			if (!isset($races_by_id[$rid])) return ProcessingError('', 'Invalid race in submission.');
			$cfg = $races_by_id[$rid];
			$abst = !empty($vi['IsAbstain']);
			$nota = !empty($vi['IsNoneOfAbove']);
			if ($abst && empty($cfg['allow_abstain'])) return ProcessingError('', 'Abstain not allowed for race.');
			// Single-candidate position races render as confidence votes; the voter UI sends 'No' as IsNoneOfAbove,
			// and the tally treats NOTA→No when no explicit 'No' choice exists. Bypass the allow_none_of_above
			// check for that runtime-converted case.
			$is_single_cand_position = ($cfg['race_type'] === 'position' && $cfg['choice_count'] === 1);
			if ($nota && empty($cfg['allow_none_of_above']) && !$is_single_cand_position) return ProcessingError('', 'None-of-the-above not allowed for race.');
		}

		// ── Open transaction with FOR UPDATE on the active_ballot pointer (deadlock-safe).
		$DB->Clear();
		$DB->Execute("START TRANSACTION");
		$DB->Clear();
		$rs = $DB->DataSet("SELECT voting_ballot_id FROM " . DB_PREFIX . "voting_active_ballot
			WHERE voting_event_id = " . $voting_event_id . " AND voter_mundane_id = " . $voter_mundane_id . " FOR UPDATE");
		$prior_ballot_id = ($rs && $rs->Next()) ? (int)$rs->voting_ballot_id : null;

		// Insert new ballot row.
		$this->Ballot->clear();
		$this->Ballot->voting_event_id = $voting_event_id;
		$this->Ballot->voter_mundane_id = $voter_mundane_id;
		$this->Ballot->is_provisional = $is_provisional;
		$this->Ballot->entered_by_runner_id = $entered_by_runner_id;
		$this->Ballot->submitted_at = date('Y-m-d H:i:s');
		$this->Ballot->save();
		$new_ballot_id = (int)$this->Ballot->voting_ballot_id;

		// Insert vote rows.
		foreach ($votes_in as $vi) {
			$rid = (int)$vi['VotingRaceId'];
			$cfg = $races_by_id[$rid];
			$abst = !empty($vi['IsAbstain']) ? 1 : 0;
			$nota = !empty($vi['IsNoneOfAbove']) ? 1 : 0;

			if ($abst || $nota) {
				$this->Vote->clear();
				$this->Vote->voting_ballot_id = $new_ballot_id;
				$this->Vote->voting_race_id = $rid;
				$this->Vote->is_abstain = $abst;
				$this->Vote->is_none_of_above = $nota;
				$this->Vote->save();
				continue;
			}

			$cids = $vi['ChoiceIds'] ?? [];
			if (!is_array($cids)) $cids = [];

			if ($cfg['race_type'] === 'position' && $cfg['voting_mode'] === 'irv') {
				// IRV: one row per rank.
				$rank = 1;
				foreach ($cids as $cid) {
					if (!valid_id($cid)) continue;
					$this->Vote->clear();
					$this->Vote->voting_ballot_id = $new_ballot_id;
					$this->Vote->voting_race_id = $rid;
					$this->Vote->voting_choice_id = (int)$cid;
					$this->Vote->rank = $rank++;
					$this->Vote->save();
				}
			} else {
				// Single-select.
				$cid = $cids[0] ?? null;
				if (!valid_id($cid)) continue;
				$this->Vote->clear();
				$this->Vote->voting_ballot_id = $new_ballot_id;
				$this->Vote->voting_race_id = $rid;
				$this->Vote->voting_choice_id = (int)$cid;
				$this->Vote->save();
			}
		}

		// If the prior ballot has votes for races NOT in this submission, carry them forward
		// (supports partial-revote after Resume->Discard: voter only fills impacted races).
		$included_race_ids = array_map(function($vi){ return (int)$vi['VotingRaceId']; }, $votes_in);
		if ($prior_ballot_id && !empty($included_race_ids)) {
			$included_in = implode(',', array_unique(array_map('intval', $included_race_ids)));
			$DB->Clear();
			$rs2 = $DB->DataSet("SELECT voting_race_id, voting_choice_id, `rank`, is_abstain, is_none_of_above
				FROM " . DB_PREFIX . "voting_vote
				WHERE voting_ballot_id = " . (int)$prior_ballot_id . "
				  AND voting_race_id NOT IN ({$included_in})");
			$carry = [];
			while ($rs2 && $rs2->Next()) {
				$carry[] = ['voting_race_id' => (int)$rs2->voting_race_id,
					'voting_choice_id' => $rs2->voting_choice_id !== null ? (int)$rs2->voting_choice_id : null,
					'rank' => $rs2->rank !== null ? (int)$rs2->rank : null,
					'is_abstain' => (int)$rs2->is_abstain, 'is_none_of_above' => (int)$rs2->is_none_of_above];
			}
			foreach ($carry as $row) {
				$this->Vote->clear();
				$this->Vote->voting_ballot_id = $new_ballot_id;
				$this->Vote->voting_race_id = $row['voting_race_id'];
				if ($row['voting_choice_id'] !== null) $this->Vote->voting_choice_id = $row['voting_choice_id'];
				if ($row['rank'] !== null) $this->Vote->rank = $row['rank'];
				$this->Vote->is_abstain = $row['is_abstain'];
				$this->Vote->is_none_of_above = $row['is_none_of_above'];
				$this->Vote->save();
			}
		}

		// Mark prior ballot superseded.
		$action = 'ballot_cast';
		if ($prior_ballot_id) {
			$DB->Clear();
			$DB->Execute("UPDATE " . DB_PREFIX . "voting_ballot SET superseded_by_ballot_id = " . $new_ballot_id . " WHERE voting_ballot_id = " . $prior_ballot_id);
			$action = 'ballot_changed';
		}
		if ($is_runner_entry) {
			$action = $prior_ballot_id ? 'ballot_replaced_by_paper' : 'ballot_runner_entered';
		}

		// Eligibility snapshot at submit time.
		$DB->Clear();
		$DB->Execute("INSERT INTO " . DB_PREFIX . "voting_eligibility_snapshot
			(voting_event_id, mundane_id, eligible, was_provisional, source_rules, evaluated_at)
			VALUES (?, ?, ?, ?, ?, NOW())
			ON DUPLICATE KEY UPDATE eligible = VALUES(eligible), source_rules = VALUES(source_rules), evaluated_at = NOW()",
			[$voting_event_id, $voter_mundane_id, $elig['eligible'] ? 1 : 0, $is_provisional, json_encode($elig['rules'])]);

		// Flip the active-ballot pointer.
		$DB->Clear();
		$DB->Execute("INSERT INTO " . DB_PREFIX . "voting_active_ballot (voting_event_id, voter_mundane_id, voting_ballot_id) VALUES (?, ?, ?)
			ON DUPLICATE KEY UPDATE voting_ballot_id = VALUES(voting_ballot_id)",
			[$voting_event_id, $voter_mundane_id, $new_ballot_id]);

		$DB->Clear();
		$DB->Execute("COMMIT");
		$DB->Clear();

		$this->audit($voting_event_id, $action,
			['ballot_id' => $new_ballot_id, 'voter_mundane_id' => $voter_mundane_id, 'is_provisional' => $is_provisional, 'prior_ballot_id' => $prior_ballot_id],
			$actor_mundane_id);

		return Success($new_ballot_id);
	}

	// ════════════════════════════════════════════════════════════════════
	//                       PROVISIONAL LIFECYCLE
	// ════════════════════════════════════════════════════════════════════

	public function ReleaseProvisionalManual($request) {
		$mundane_id = Ork3::$Lib->authorization->IsAuthorized($request['Token']);
		if (!valid_id($mundane_id)) return NoAuthorization();
		$voting_ballot_id = (int)($request['VotingBallotId'] ?? 0);
		$reason = trim($request['Reason'] ?? '');
		if (!$voting_ballot_id || $reason === '') return InvalidParameter();

		$this->Ballot->clear();
		$this->Ballot->voting_ballot_id = $voting_ballot_id;
		if (!$this->Ballot->find()) return InvalidParameter();
		if (!$this->user_is_runner_of_event($mundane_id, $this->Ballot->voting_event_id)) return NoAuthorization();
		if (!$this->Ballot->is_provisional) return ProcessingError('', 'Ballot is not provisional.');

		$this->Ballot->is_provisional = 0;
		$this->Ballot->provisional_released_at = date('Y-m-d H:i:s');
		$this->Ballot->provisional_released_by_mundane_id = $mundane_id;
		$this->Ballot->save();

		$this->audit($this->Ballot->voting_event_id, 'provisional_released_runner',
			['ballot_id' => $voting_ballot_id, 'reason' => $reason], $mundane_id);
		return Success($voting_ballot_id);
	}

	public function reevaluate_provisional_for_player($mundane_id) {
		if (!valid_id($mundane_id)) return;
		global $DB;
		$DB->Clear();
		$rs = $DB->DataSet("SELECT b.voting_ballot_id, b.voting_event_id, e.scope_type, e.scope_id
			FROM " . DB_PREFIX . "voting_ballot b
			JOIN " . DB_PREFIX . "voting_event e USING (voting_event_id)
			WHERE b.voter_mundane_id = " . (int)$mundane_id . "
			  AND b.is_provisional = 1
			  AND b.superseded_by_ballot_id IS NULL
			  AND e.status = 'open'");
		$pending = [];
		while ($rs && $rs->Next()) {
			$pending[] = ['ballot_id' => (int)$rs->voting_ballot_id, 'event_id' => (int)$rs->voting_event_id,
				'scope_type' => $rs->scope_type, 'scope_id' => (int)$rs->scope_id];
		}
		foreach ($pending as $p) {
			$elig = $this->check_eligibility_live($mundane_id, $p['scope_type'], $p['scope_id']);
			if ($elig['eligible']) {
				$DB->Clear();
				$DB->Execute("UPDATE " . DB_PREFIX . "voting_ballot SET is_provisional = 0, provisional_released_at = NOW() WHERE voting_ballot_id = " . $p['ballot_id']);
				$this->audit($p['event_id'], 'provisional_released_system', ['ballot_id' => $p['ballot_id'], 'mundane_id' => $mundane_id]);
			}
		}
	}

	public function sweep_provisional_eligibility() {
		global $DB;
		$DB->Clear();
		$rs = $DB->DataSet("SELECT DISTINCT b.voter_mundane_id
			FROM " . DB_PREFIX . "voting_ballot b
			JOIN " . DB_PREFIX . "voting_event e USING (voting_event_id)
			WHERE b.is_provisional = 1 AND b.superseded_by_ballot_id IS NULL AND e.status = 'open'");
		$ids = [];
		while ($rs && $rs->Next()) $ids[] = (int)$rs->voter_mundane_id;
		foreach ($ids as $mid) $this->reevaluate_provisional_for_player($mid);
	}

	public function cycle_event_status() {
		global $DB;
		// draft → open
		$DB->Clear();
		$DB->Execute("UPDATE " . DB_PREFIX . "voting_event SET status = 'open' WHERE status = 'draft' AND reopened_at IS NULL AND start_date <= NOW() AND end_date > NOW()");
		// open → closed
		$DB->Clear();
		$rs = $DB->DataSet("SELECT voting_event_id FROM " . DB_PREFIX . "voting_event WHERE status = 'open' AND end_date <= NOW()");
		$to_close = [];
		while ($rs && $rs->Next()) $to_close[] = (int)$rs->voting_event_id;
		foreach ($to_close as $eid) {
			$this->sweep_provisional_eligibility(); // final sweep
			$DB->Clear();
			$DB->Execute("UPDATE " . DB_PREFIX . "voting_event SET status = 'closed' WHERE voting_event_id = " . $eid);
			$this->audit($eid, 'event_updated', ['status' => 'closed', 'auto' => true]);
		}
	}

	// ════════════════════════════════════════════════════════════════════
	//                        TALLY (DB-BACKED)
	// ════════════════════════════════════════════════════════════════════

	public function tally($voting_event_id) {
		global $DB;
		$voting_event_id = (int)$voting_event_id;
		// Load races + choices.
		$DB->Clear();
		$rs = $DB->DataSet("SELECT * FROM " . DB_PREFIX . "voting_race WHERE voting_event_id = " . $voting_event_id . " ORDER BY display_order, voting_race_id");
		$races = [];
		while ($rs && $rs->Next()) {
			$races[(int)$rs->voting_race_id] = [
				'voting_race_id' => (int)$rs->voting_race_id,
				'race_type' => $rs->race_type, 'voting_mode' => $rs->voting_mode,
				'title' => $rs->title, 'rationale' => $rs->rationale,
				'allow_abstain' => (int)$rs->allow_abstain, 'allow_none_of_above' => (int)$rs->allow_none_of_above,
				'nota_counts_as' => $rs->nota_counts_as, 'is_non_binding' => (int)$rs->is_non_binding,
				'tie_resolved_winner_choice_id' => $rs->tie_resolved_winner_choice_id ? (int)$rs->tie_resolved_winner_choice_id : null,
				'tie_resolution_note' => $rs->tie_resolution_note,
				'choices' => [],
			];
		}
		if (empty($races)) return [];

		$DB->Clear();
		$rs = $DB->DataSet("SELECT c.* FROM " . DB_PREFIX . "voting_choice c
			JOIN " . DB_PREFIX . "voting_race r USING (voting_race_id)
			WHERE r.voting_event_id = " . $voting_event_id . " ORDER BY c.display_order, c.voting_choice_id");
		while ($rs && $rs->Next()) {
			$rid = (int)$rs->voting_race_id;
			if (!isset($races[$rid])) continue;
			$races[$rid]['choices'][] = [
				'id' => (int)$rs->voting_choice_id,
				'label' => $rs->label,
				'candidate_mundane_id' => $rs->candidate_mundane_id ? (int)$rs->candidate_mundane_id : null,
				'is_yes' => (strcasecmp($rs->label, 'Yes') === 0) ? 1 : 0,
				'is_no'  => (strcasecmp($rs->label, 'No')  === 0) ? 1 : 0,
			];
		}

		// Load votes for active, non-provisional ballots only.
		$DB->Clear();
		$rs = $DB->DataSet("SELECT v.voting_race_id, v.voting_ballot_id, v.voting_choice_id, v.rank, v.is_abstain, v.is_none_of_above
			FROM " . DB_PREFIX . "voting_vote v
			JOIN " . DB_PREFIX . "voting_active_ballot ab ON ab.voting_ballot_id = v.voting_ballot_id
			JOIN " . DB_PREFIX . "voting_ballot b ON b.voting_ballot_id = v.voting_ballot_id
			WHERE ab.voting_event_id = " . $voting_event_id . " AND b.is_provisional = 0");
		$votes_by_race_ballot = [];
		while ($rs && $rs->Next()) {
			$rid = (int)$rs->voting_race_id;
			$bid = (int)$rs->voting_ballot_id;
			$votes_by_race_ballot[$rid][$bid][] = [
				'choice_id' => $rs->voting_choice_id ? (int)$rs->voting_choice_id : null,
				'rank' => $rs->rank ? (int)$rs->rank : null,
				'is_abstain' => (int)$rs->is_abstain,
				'is_nota' => (int)$rs->is_none_of_above,
			];
		}

		// Build per-race result.
		$results = [];
		foreach ($races as $rid => $race) {
			$ballots = [];
			foreach (($votes_by_race_ballot[$rid] ?? []) as $bid => $vrows) {
				$ballots[] = ['votes' => $vrows];
			}
			$result = self::tally_pure($race, $ballots);
			// Honor manual tie resolution.
			if ($race['tie_resolved_winner_choice_id'] && in_array($result['outcome'], ['tie', 'tie_at_elimination', 'tie_at_final'])) {
				$result['outcome'] = 'win_resolved';
				$result['winner_choice_id'] = $race['tie_resolved_winner_choice_id'];
				$result['tie_resolution_note'] = $race['tie_resolution_note'];
			}
			$results[$rid] = ['race' => $race, 'result' => $result, 'ballot_count' => count($ballots)];
		}
		return $results;
	}

	public function ResolveTie($request) {
		$mundane_id = Ork3::$Lib->authorization->IsAuthorized($request['Token']);
		if (!valid_id($mundane_id)) return NoAuthorization();
		$voting_race_id = (int)($request['VotingRaceId'] ?? 0);
		$winner_choice_id = (int)($request['WinnerChoiceId'] ?? 0);
		$note = trim($request['Note'] ?? '');
		if (!$voting_race_id || !$winner_choice_id || $note === '') return InvalidParameter();

		$this->Race->clear();
		$this->Race->voting_race_id = $voting_race_id;
		if (!$this->Race->find()) return InvalidParameter();
		if (!$this->user_is_runner_of_event($mundane_id, $this->Race->voting_event_id)) return NoAuthorization();

		// Sanity-check the winner is actually a choice in this race.
		global $DB;
		$DB->Clear();
		$rs = $DB->DataSet("SELECT 1 FROM " . DB_PREFIX . "voting_choice WHERE voting_choice_id = " . $winner_choice_id . " AND voting_race_id = " . $voting_race_id);
		if (!$rs || !$rs->Next()) return InvalidParameter();

		$this->Race->tie_resolved_winner_choice_id = $winner_choice_id;
		$this->Race->tie_resolution_note = $note;
		$this->Race->tie_resolution_at = date('Y-m-d H:i:s');
		$this->Race->tie_resolved_by_mundane_id = $mundane_id;
		$this->Race->save();

		$this->audit($this->Race->voting_event_id, 'tie_resolved',
			['race_id' => $voting_race_id, 'winner' => $winner_choice_id, 'note' => $note], $mundane_id);
		return Success($voting_race_id);
	}

	public function Publish($request) {
		$mundane_id = Ork3::$Lib->authorization->IsAuthorized($request['Token']);
		if (!valid_id($mundane_id)) return NoAuthorization();
		$voting_event_id = (int)($request['VotingEventId'] ?? 0);
		if (!$voting_event_id) return InvalidParameter();
		if (!$this->user_is_runner_of_event($mundane_id, $voting_event_id)) return NoAuthorization();

		$this->Event->clear();
		$this->Event->voting_event_id = $voting_event_id;
		if (!$this->Event->find()) return InvalidParameter();
		if (!in_array($this->Event->status, ['closed', 'unpublished'])) {
			return ProcessingError('', 'Event must be closed before publish.');
		}

		// Gate: no unresolved ties.
		$tally = $this->tally($voting_event_id);
		foreach ($tally as $rid => $row) {
			$out = $row['result']['outcome'] ?? null;
			$tie_resolved = $row['race']['tie_resolved_winner_choice_id'] ?? null;
			if (in_array($out, ['tie', 'tie_at_elimination', 'tie_at_final']) && !$tie_resolved) {
				return ProcessingError('', 'Cannot publish: ' . $row['race']['title'] . ' has an unresolved tie.');
			}
		}

		$this->Event->status = 'published';
		$this->Event->published_at = date('Y-m-d H:i:s');
		$this->Event->published_by_mundane_id = $mundane_id;
		$this->Event->tally_snapshot = json_encode($tally);
		$this->Event->save();

		$this->audit($voting_event_id, 'results_published', null, $mundane_id);
		return Success($voting_event_id);
	}

	public function Unpublish($request) {
		$mundane_id = Ork3::$Lib->authorization->IsAuthorized($request['Token']);
		if (!valid_id($mundane_id)) return NoAuthorization();
		$voting_event_id = (int)($request['VotingEventId'] ?? 0);
		if (!$voting_event_id) return InvalidParameter();
		if (!$this->user_is_runner_of_event($mundane_id, $voting_event_id)) return NoAuthorization();

		$this->Event->clear();
		$this->Event->voting_event_id = $voting_event_id;
		if (!$this->Event->find()) return InvalidParameter();
		if ($this->Event->status !== 'published') return ProcessingError('', 'Event is not published.');

		$this->Event->status = 'unpublished';
		$this->Event->save();
		$this->audit($voting_event_id, 'results_unpublished', null, $mundane_id);
		return Success($voting_event_id);
	}

	// ════════════════════════════════════════════════════════════════════
	//                            READS
	// ════════════════════════════════════════════════════════════════════

	public function GetEvent($request) {
		$voting_event_id = (int)($request['VotingEventId'] ?? 0);
		if (!$voting_event_id) return InvalidParameter();
		global $DB;
		$DB->Clear();
		$rs = $DB->DataSet("SELECT * FROM " . DB_PREFIX . "voting_event WHERE voting_event_id = " . $voting_event_id);
		if (!$rs || !$rs->Next()) return ProcessingError('', 'Event not found.');
		$ev = (array)$rs;
		// Strip yapo internals.
		$ev = array_filter($ev, fn($k) => !str_starts_with((string)$k, '_'), ARRAY_FILTER_USE_KEY);

		$DB->Clear();
		$rs = $DB->DataSet("SELECT * FROM " . DB_PREFIX . "voting_race WHERE voting_event_id = " . $voting_event_id . " ORDER BY display_order, voting_race_id");
		$races = [];
		while ($rs && $rs->Next()) {
			$row = (array)$rs;
			$races[(int)$row['voting_race_id']] = array_merge($row, ['choices' => []]);
		}
		$DB->Clear();
		$rs = $DB->DataSet("SELECT c.* FROM " . DB_PREFIX . "voting_choice c
			JOIN " . DB_PREFIX . "voting_race r USING (voting_race_id)
			WHERE r.voting_event_id = " . $voting_event_id . " ORDER BY c.display_order, c.voting_choice_id");
		while ($rs && $rs->Next()) {
			$row = (array)$rs;
			if (isset($races[(int)$row['voting_race_id']])) $races[(int)$row['voting_race_id']]['choices'][] = $row;
		}
		$ev['races'] = array_values($races);
		return ['Status' => 0, 'Event' => $ev];
	}

	public function ListEventsForScope($request) {
		$scope_type = $request['ScopeType'] ?? null;
		$scope_id = (int)($request['ScopeId'] ?? 0);
		if (!in_array($scope_type, ['kingdom','park']) || !$scope_id) return InvalidParameter();
		global $DB;
		$DB->Clear();
		$rs = $DB->DataSet("SELECT voting_event_id, event_type, title, status, start_date, end_date, anonymous_to_runner
			FROM " . DB_PREFIX . "voting_event
			WHERE scope_type = '" . mysql_real_escape_string($scope_type) . "' AND scope_id = " . $scope_id . "
			ORDER BY start_date DESC, voting_event_id DESC LIMIT 50");
		$events = [];
		while ($rs && $rs->Next()) $events[] = (array)$rs;
		return ['Status' => 0, 'Events' => $events];
	}

	public function CountActiveEvents($request) {
		$scope_type = $request['ScopeType'] ?? null;
		$scope_id = (int)($request['ScopeId'] ?? 0);
		if (!in_array($scope_type, ['kingdom','park']) || !$scope_id) return InvalidParameter();
		global $DB;
		$DB->Clear();
		$rs = $DB->DataSet("SELECT COUNT(*) AS n FROM " . DB_PREFIX . "voting_event
			WHERE scope_type = '" . mysql_real_escape_string($scope_type) . "' AND scope_id = " . $scope_id . "
			  AND status IN ('open','closed')");
		$n = ($rs && $rs->Next()) ? (int)$rs->n : 0;
		return ['Status' => 0, 'Count' => $n];
	}

	public function ActiveEventsForVoter($request) {
		$mundane_id = (int)($request['MundaneId'] ?? 0);
		if (!valid_id($mundane_id)) return InvalidParameter();
		// Find the voter's kingdom + park; only events in those scopes are relevant.
		global $DB;
		$DB->Clear();
		$rs = $DB->DataSet("SELECT kingdom_id, park_id FROM " . DB_PREFIX . "mundane WHERE mundane_id = " . $mundane_id . " LIMIT 1");
		if (!$rs || !$rs->Next()) return ['Status' => 0, 'Events' => []];
		$kid = (int)$rs->kingdom_id;
		$pid = (int)$rs->park_id;

		$DB->Clear();
		$rs = $DB->DataSet("SELECT e.voting_event_id, e.event_type, e.title, e.scope_type, e.scope_id, e.end_date,
			ab.voting_ballot_id AS active_ballot_id
			FROM " . DB_PREFIX . "voting_event e
			LEFT JOIN " . DB_PREFIX . "voting_active_ballot ab
				ON ab.voting_event_id = e.voting_event_id AND ab.voter_mundane_id = " . $mundane_id . "
			WHERE e.status = 'open'
			  AND ((e.scope_type = 'kingdom' AND e.scope_id = " . $kid . ")
			       OR (e.scope_type = 'park' AND e.scope_id = " . $pid . "))
			ORDER BY e.end_date ASC LIMIT 20");
		$events = [];
		while ($rs && $rs->Next()) $events[] = (array)$rs;

		// Annotate each entry with pending_revote / pending_race_count for partial-revote banners.
		if (!empty($events)) {
			$ids = array_filter(array_map(function($e){ return (int)($e['voting_event_id'] ?? 0); }, $events));
			if (!empty($ids)) {
				$in = implode(',', array_map('intval', $ids));
				$voter_id = (int)$mundane_id;
				$DB->Clear();
				$rs2 = $DB->DataSet("SELECT e.voting_event_id,
						(SELECT COUNT(*) FROM " . DB_PREFIX . "voting_race r WHERE r.voting_event_id = e.voting_event_id) AS total_races,
						(SELECT COUNT(DISTINCT v.voting_race_id)
						 FROM " . DB_PREFIX . "voting_active_ballot ab
						 JOIN " . DB_PREFIX . "voting_vote v ON v.voting_ballot_id = ab.voting_ballot_id
						 WHERE ab.voting_event_id = e.voting_event_id AND ab.voter_mundane_id = " . $voter_id . ") AS voted_races
					FROM " . DB_PREFIX . "voting_event e
					WHERE e.voting_event_id IN ({$in})");
				$counts = [];
				while ($rs2 && $rs2->Next()) {
					$counts[(int)$rs2->voting_event_id] = ['total' => (int)$rs2->total_races, 'voted' => (int)$rs2->voted_races];
				}
				foreach ($events as &$e) {
					$eid = (int)($e['voting_event_id'] ?? 0);
					if (!isset($counts[$eid])) { continue; }
					$voted = $counts[$eid]['voted']; $total = $counts[$eid]['total'];
					$has_active = !empty($e['active_ballot_id']);
					$e['pending_revote'] = ($has_active && $voted < $total) ? 1 : 0;
					$e['pending_race_count'] = max(0, $total - $voted);
				}
				unset($e);
			}
		}
		return ['Status' => 0, 'Events' => $events];
	}

	public function GetTallyPublic($request) {
		// Public read of tally_snapshot — no auth required, but only for published events.
		$voting_event_id = (int)($request['VotingEventId'] ?? 0);
		if (!$voting_event_id) return InvalidParameter();
		global $DB;
		$DB->Clear();
		$rs = $DB->DataSet("SELECT status, tally_snapshot, title, event_type, scope_type, scope_id, start_date, end_date FROM " . DB_PREFIX . "voting_event WHERE voting_event_id = " . $voting_event_id);
		if (!$rs || !$rs->Next()) return ProcessingError('', 'Not found.');
		if ($rs->status !== 'published') return ProcessingError($rs->status, 'Not published.');
		return [
			'Status' => 0,
			'Event' => ['title' => $rs->title, 'event_type' => $rs->event_type, 'scope_type' => $rs->scope_type, 'scope_id' => (int)$rs->scope_id, 'start_date' => $rs->start_date, 'end_date' => $rs->end_date],
			'Tally' => json_decode($rs->tally_snapshot, true) ?: [],
		];
	}

	public function GetEligibilityCheck($request) {
		// Used by the voter ballot page to render eligibility status before showing the ballot.
		$mundane_id = Ork3::$Lib->authorization->IsAuthorized($request['Token']);
		if (!valid_id($mundane_id)) return NoAuthorization();
		$voting_event_id = (int)($request['VotingEventId'] ?? 0);
		if (!$voting_event_id) return InvalidParameter();
		global $DB;
		$DB->Clear();
		$rs = $DB->DataSet("SELECT scope_type, scope_id, allow_provisional FROM " . DB_PREFIX . "voting_event WHERE voting_event_id = " . $voting_event_id);
		if (!$rs || !$rs->Next()) return ProcessingError('', 'Event not found.');
		$elig = $this->check_eligibility_live($mundane_id, $rs->scope_type, $rs->scope_id);
		return [
			'Status' => 0,
			'Eligible' => $elig['eligible'],
			'ProvisionalPossible' => $elig['provisional_possible'],
			'AllowProvisional' => (int)$rs->allow_provisional,
		];
	}

	// ════════════════════════════════════════════════════════════════════
	//                          PURE TALLY ENGINE
	// ════════════════════════════════════════════════════════════════════

	public static function tally_pure(array $race, array $ballots): array {
		if ($race['race_type'] === 'yesno') {
			return self::tally_confidence($race, $ballots);
		}
		if ($race['race_type'] === 'position' && count($race['choices']) === 1) {
			return self::tally_confidence($race, $ballots);
		}
		if ($race['race_type'] === 'multichoice') {
			return self::tally_plurality($race, $ballots);
		}
		switch ($race['voting_mode']) {
			case 'plurality': return self::tally_plurality($race, $ballots);
			case 'majority':  return self::tally_majority($race, $ballots);
			case 'irv':       return self::tally_irv($race, $ballots);
		}
		return ['outcome' => 'error', 'error' => 'unknown voting mode'];
	}

	private static function tally_confidence(array $race, array $ballots): array {
		$yes_id = null; $no_id = null;
		foreach ($race['choices'] as $c) {
			if (!empty($c['is_yes']) || strcasecmp($c['label'], 'Yes') === 0) $yes_id = $c['id'];
			if (!empty($c['is_no'])  || strcasecmp($c['label'], 'No')  === 0) $no_id  = $c['id'];
		}
		if ($yes_id === null && count($race['choices']) > 0) $yes_id = $race['choices'][0]['id'];

		$yes = 0; $no = 0; $abstain = 0; $nota = 0;
		foreach ($ballots as $b) {
			foreach ($b['votes'] as $v) {
				if (!empty($v['is_abstain'])) { $abstain++; break; }
				if (!empty($v['is_nota']))    { $nota++; break; }
				if ($v['choice_id'] === $yes_id) { $yes++; break; }
				if ($v['choice_id'] === $no_id)  { $no++; break; }
			}
		}
		if (!empty($race['allow_none_of_above']) && $nota > 0 && !empty($race['nota_counts_as'])) {
			if ($race['nota_counts_as'] === 'no')      $no += $nota;
			if ($race['nota_counts_as'] === 'abstain') $abstain += $nota;
			$nota = 0;
		}
		// Single-candidate position confidence: there is no explicit 'No' choice in the DB,
		// so the voter UI represents 'No' as a NOTA vote. Always count those as No.
		if ($no_id === null && $nota > 0) {
			$no += $nota;
			$nota = 0;
		}
		$outcome = 'tie';
		if ($yes > $no) $outcome = 'pass';
		else if ($no > $yes) $outcome = 'fail';
		return [
			'outcome' => $outcome,
			'yes' => $yes, 'no' => $no, 'abstain' => $abstain, 'nota' => $nota,
			'denominator' => $yes + $no,
			'tie' => $outcome === 'tie' ? true : null,
		];
	}

	private static function tally_plurality(array $race, array $ballots): array {
		$counts = [];
		foreach ($race['choices'] as $c) $counts[$c['id']] = 0;
		$abstain = 0; $nota = 0;
		foreach ($ballots as $b) {
			foreach ($b['votes'] as $v) {
				if (!empty($v['is_abstain'])) { $abstain++; break; }
				if (!empty($v['is_nota']))    { $nota++; break; }
				if ($v['choice_id'] !== null && isset($counts[$v['choice_id']])) {
					$counts[$v['choice_id']]++;
					break;
				}
			}
		}
		$max = empty($counts) ? 0 : max($counts);
		$top = [];
		foreach ($counts as $id => $n) if ($n === $max && $max > 0) $top[] = $id;
		if (count($top) === 1) {
			return ['outcome' => 'win', 'winner_choice_id' => $top[0],
				'counts' => $counts, 'abstain' => $abstain, 'nota' => $nota, 'tie' => null];
		}
		if ($max === 0) {
			return ['outcome' => 'no_votes', 'winner_choice_id' => null,
				'counts' => $counts, 'abstain' => $abstain, 'nota' => $nota, 'tie' => null];
		}
		sort($top);
		return ['outcome' => 'tie', 'winner_choice_id' => null,
			'counts' => $counts, 'abstain' => $abstain, 'nota' => $nota, 'tie' => $top];
	}

	private static function tally_majority(array $race, array $ballots): array {
		$plur = self::tally_plurality($race, $ballots);
		if ($plur['outcome'] === 'tie') return $plur;
		if ($plur['outcome'] === 'no_votes') return $plur;
		$total_choice_votes = array_sum($plur['counts']);
		$winner_count = $plur['counts'][$plur['winner_choice_id']];
		if ($total_choice_votes > 0 && $winner_count * 2 > $total_choice_votes) {
			return $plur;
		}
		return [
			'outcome' => 'no_majority',
			'winner_choice_id' => null,
			'counts' => $plur['counts'],
			'abstain' => $plur['abstain'],
			'nota' => $plur['nota'],
			'tie' => null,
		];
	}

	private static function tally_irv(array $race, array $ballots): array {
		$sequences = [];
		$abstained = 0;
		foreach ($ballots as $b) {
			$ranked = [];
			foreach ($b['votes'] as $v) {
				if (!empty($v['is_abstain']) || !empty($v['is_nota'])) continue;
				if ($v['rank'] === null || $v['choice_id'] === null) continue;
				$ranked[] = ['rank' => (int)$v['rank'], 'choice_id' => $v['choice_id']];
			}
			if (empty($ranked)) {
				$abstained++;
				continue;
			}
			usort($ranked, fn($a, $b) => $a['rank'] - $b['rank']);
			$sequences[] = array_values(array_map(fn($r) => $r['choice_id'], $ranked));
		}

		$candidates = array_map(fn($c) => $c['id'], $race['choices']);
		$eliminated = [];
		$rounds = [];

		while (true) {
			$counts = array_fill_keys(array_diff($candidates, $eliminated), 0);
			$exhausted_this_round = 0;
			$active_total = 0;
			foreach ($sequences as $seq) {
				$head = null;
				foreach ($seq as $cid) {
					if (!in_array($cid, $eliminated)) { $head = $cid; break; }
				}
				if ($head === null) continue;
				$counts[$head]++;
				$active_total++;
			}

			$max = empty($counts) ? 0 : max($counts);
			$winners = [];
			foreach ($counts as $cid => $n) if ($n === $max && $max > 0) $winners[] = $cid;
			$majority_threshold = intdiv($active_total, 2) + 1;

			if (count($winners) === 1 && $counts[$winners[0]] >= $majority_threshold) {
				$rounds[] = ['round' => count($rounds) + 1, 'counts' => $counts, 'eliminated' => null,
					'winner' => $winners[0], 'exhausted_this_round' => $exhausted_this_round];
				return ['outcome' => 'win', 'winner_choice_id' => $winners[0], 'rounds' => $rounds, 'tie' => null, 'abstained' => $abstained];
			}

			if (count($counts) === 1) {
				$only = array_key_first($counts);
				$rounds[] = ['round' => count($rounds) + 1, 'counts' => $counts, 'eliminated' => null,
					'winner' => $only, 'exhausted_this_round' => $exhausted_this_round];
				return ['outcome' => 'win', 'winner_choice_id' => $only, 'rounds' => $rounds, 'tie' => null, 'abstained' => $abstained];
			}

			if (count($counts) === 2 && count($winners) === 2 && $counts[$winners[0]] === $counts[$winners[1]]) {
				$rounds[] = ['round' => count($rounds) + 1, 'counts' => $counts, 'eliminated' => null,
					'tie' => $winners, 'exhausted_this_round' => $exhausted_this_round];
				sort($winners);
				return ['outcome' => 'tie_at_final', 'winner_choice_id' => null, 'rounds' => $rounds, 'tie' => $winners, 'abstained' => $abstained];
			}

			$min = min($counts);
			$lowest = [];
			foreach ($counts as $cid => $n) if ($n === $min) $lowest[] = $cid;
			if (count($lowest) > 1) {
				$rounds[] = ['round' => count($rounds) + 1, 'counts' => $counts, 'eliminated' => null,
					'tie' => $lowest, 'exhausted_this_round' => $exhausted_this_round];
				sort($lowest);
				return ['outcome' => 'tie_at_elimination', 'winner_choice_id' => null, 'rounds' => $rounds, 'tie' => $lowest, 'abstained' => $abstained];
			}

			$rounds[] = ['round' => count($rounds) + 1, 'counts' => $counts,
				'eliminated' => $lowest[0], 'exhausted_this_round' => $exhausted_this_round];
			$eliminated[] = $lowest[0];
		}
	}
}
