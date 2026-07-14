<?php

class Model_Voting extends Model
{
    public function __construct()
    {
        parent::__construct();
        $this->Voting = new APIModel('Voting');
    }

    // ── Event / race CRUD ──────────────────────────────────────────────

    public function create_event($request)
    {
        return $this->Voting->CreateEvent($request);
    }
    public function update_event($request)
    {
        return $this->Voting->UpdateEvent($request);
    }
    public function add_race($request)
    {
        return $this->Voting->AddRace($request);
    }
    public function add_candidate($request)
    {
        return $this->Voting->AddCandidate($request);
    }
    public function add_option($request)
    {
        return $this->Voting->AddOption($request);
    }
    public function remove_choice($request)
    {
        return $this->Voting->RemoveChoice($request);
    }
    public function open_event($request)
    {
        return $this->Voting->OpenEvent($request);
    }
    public function reopen_event($request)
    {
        return $this->Voting->ReopenEvent($request);
    }
    public function edit_race($request)
    {
        return $this->Voting->EditRace($request);
    }
    public function edit_choice($request)
    {
        return $this->Voting->EditChoice($request);
    }
    public function restore_choice($request)
    {
        return $this->Voting->RestoreChoice($request);
    }
    public function remove_race($request)
    {
        return $this->Voting->RemoveRace($request);
    }
    public function edit_race_settings($request)
    {
        return $this->Voting->EditRaceSettings($request);
    }
    public function preview_resume($voting_event_id)
    {
        return $this->Voting->PreviewResume($voting_event_id);
    }
    public function resume_event($request)
    {
        return $this->Voting->ResumeEvent($request);
    }

    // ── Voter / runner ─────────────────────────────────────────────────

    public function cast_ballot($request)
    {
        return $this->Voting->CastBallot($request);
    }
    public function release_provisional($request)
    {
        return $this->Voting->ReleaseProvisionalManual($request);
    }
    public function resolve_tie($request)
    {
        return $this->Voting->ResolveTie($request);
    }
    public function publish($request)
    {
        return $this->Voting->Publish($request);
    }
    public function unpublish($request)
    {
        return $this->Voting->Unpublish($request);
    }
    public function close_event($request)
    {
        return $this->Voting->CloseEvent($request);
    }
    public function cycle_event_status()
    {
        return $this->Voting->cycle_event_status();
    }
    public function reevaluate_provisional_for_player($mundane_id)
    {
        return $this->Voting->reevaluate_provisional_for_player($mundane_id);
    }

    // ── Reads ──────────────────────────────────────────────────────────

    public function get_event($voting_event_id)
    {
        return $this->Voting->GetEvent(['VotingEventId' => $voting_event_id]);
    }

    public function tally($voting_event_id)
    {
        return $this->Voting->tally($voting_event_id);
    }

    public function tally_public($voting_event_id)
    {
        return $this->Voting->GetTallyPublic(['VotingEventId' => $voting_event_id]);
    }

    public function eligibility_check($request)
    {
        return $this->Voting->GetEligibilityCheck($request);
    }

    public function eligible_roll($scope_type, $scope_id)
    {
        return $this->Voting->compute_eligible_roll($scope_type, (int)$scope_id);
    }

    public function list_for_scope($scope_type, $scope_id)
    {
        $r = $this->Voting->ListEventsForScope(['ScopeType' => $scope_type, 'ScopeId' => $scope_id]);
        return $r['Events'] ?? [];
    }

    public function count_active($scope_type, $scope_id)
    {
        $r = $this->Voting->CountActiveEvents(['ScopeType' => $scope_type, 'ScopeId' => $scope_id]);
        return (int)($r['Count'] ?? 0);
    }

    public function active_for_voter($mundane_id)
    {
        $r = $this->Voting->ActiveEventsForVoter(['MundaneId' => $mundane_id]);
        return $r['Events'] ?? [];
    }

    // ── Authorization / dashboard reads (lib pass-throughs) ─────────────

    public function user_can_run_in_scope($mundane_id, $scope_type, $scope_id)
    {
        return $this->Voting->user_can_run_in_scope($mundane_id, $scope_type, $scope_id);
    }
    public function user_can_manage_voting_in_scope($mundane_id, $scope_type, $scope_id)
    {
        return $this->Voting->user_can_manage_voting_in_scope($mundane_id, $scope_type, $scope_id);
    }
    public function user_is_runner_of_event($mundane_id, $voting_event_id, $event_data = null)
    {
        return $this->Voting->user_is_runner_of_event($mundane_id, $voting_event_id, $event_data);
    }
    public function user_is_candidate_in_event($mundane_id, $voting_event_id)
    {
        return $this->Voting->user_is_candidate_in_event($mundane_id, $voting_event_id);
    }
    public function voter_choices($voting_event_id, $voter_mundane_id, $viewer_mundane_id)
    {
        return $this->Voting->voter_choices($voting_event_id, $voter_mundane_id, $viewer_mundane_id);
    }
    public function reopened_by_persona($mundane_id)
    {
        return $this->Voting->reopened_by_persona($mundane_id);
    }
    public function active_ballot_for_voter($voting_event_id, $voter_mundane_id)
    {
        return $this->Voting->active_ballot_for_voter($voting_event_id, $voter_mundane_id);
    }
    public function pending_revote_race_ids($voting_ballot_id, array $race_ids)
    {
        return $this->Voting->pending_revote_race_ids($voting_ballot_id, $race_ids);
    }
    public function ballot_counts($voting_event_id)
    {
        return $this->Voting->ballot_counts($voting_event_id);
    }
    public function provisional_ballots($voting_event_id)
    {
        return $this->Voting->provisional_ballots($voting_event_id);
    }
    public function audit_log($voting_event_id, $limit = 500, $redact_voters = false)
    {
        return $this->Voting->audit_log($voting_event_id, $limit, $redact_voters);
    }
    public function tally_gate_info($voting_event_id)
    {
        return $this->Voting->tally_gate_info($voting_event_id);
    }
    public function search_players_in_scope($scope_type, $scope_id, $q, $limit = 15)
    {
        return $this->Voting->search_players_in_scope($scope_type, $scope_id, $q, $limit);
    }
    public function event_scope($voting_event_id)
    {
        return $this->Voting->event_scope($voting_event_id);
    }
}
