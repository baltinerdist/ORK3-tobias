<?php

class Model_Voting extends Model {

	function __construct() {
		parent::__construct();
		$this->Voting = new APIModel('Voting');
	}

	// ── Event / race CRUD ──────────────────────────────────────────────

	function create_event($request)        { return $this->Voting->CreateEvent($request); }
	function update_event($request)        { return $this->Voting->UpdateEvent($request); }
	function add_race($request)            { return $this->Voting->AddRace($request); }
	function add_candidate($request)       { return $this->Voting->AddCandidate($request); }
	function add_option($request)          { return $this->Voting->AddOption($request); }
	function open_event($request)          { return $this->Voting->OpenEvent($request); }

	// ── Voter / runner ─────────────────────────────────────────────────

	function cast_ballot($request)         { return $this->Voting->CastBallot($request); }
	function release_provisional($request) { return $this->Voting->ReleaseProvisionalManual($request); }
	function resolve_tie($request)         { return $this->Voting->ResolveTie($request); }
	function publish($request)             { return $this->Voting->Publish($request); }
	function unpublish($request)           { return $this->Voting->Unpublish($request); }

	// ── Reads ──────────────────────────────────────────────────────────

	function get_event($voting_event_id) {
		return $this->Voting->GetEvent(['VotingEventId' => $voting_event_id]);
	}

	function tally($voting_event_id) {
		return $this->Voting->tally($voting_event_id);
	}

	function tally_public($voting_event_id) {
		return $this->Voting->GetTallyPublic(['VotingEventId' => $voting_event_id]);
	}

	function eligibility_check($request) {
		return $this->Voting->GetEligibilityCheck($request);
	}

	function list_for_scope($scope_type, $scope_id) {
		$r = $this->Voting->ListEventsForScope(['ScopeType' => $scope_type, 'ScopeId' => $scope_id]);
		return $r['Events'] ?? [];
	}

	function count_active($scope_type, $scope_id) {
		$r = $this->Voting->CountActiveEvents(['ScopeType' => $scope_type, 'ScopeId' => $scope_id]);
		return (int)($r['Count'] ?? 0);
	}

	function active_for_voter($mundane_id) {
		$r = $this->Voting->ActiveEventsForVoter(['MundaneId' => $mundane_id]);
		return $r['Events'] ?? [];
	}
}
