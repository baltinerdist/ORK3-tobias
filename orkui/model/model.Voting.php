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
    public function add_delegate($request)
    {
        return $this->Voting->AddDelegate($request);
    }
    public function remove_delegate($request)
    {
        return $this->Voting->RemoveDelegate($request);
    }
    public function resolve_no_majority($request)
    {
        return $this->Voting->ResolveNoMajority($request);
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

    public function eligible_count($scope_type, $scope_id)
    {
        return $this->Voting->compute_eligible_count($scope_type, (int)$scope_id);
    }

    // Parse a "Kingdom_10"/"Park_5" scope string into its parts, or null if malformed.
    // Shared by the Voting controllers (index/create in controller.Voting.php;
    // candidate_search/eligibility_roster in VotingAjax are a follow-up).
    // Returns ['type' => 'kingdom', 'label' => 'Kingdom', 'id' => 10].
    public static function parse_scope($scope)
    {
        $parts = explode('_', (string)$scope, 2);
        $label = $parts[0] ?? '';
        $id    = (int)($parts[1] ?? 0);
        if (!in_array($label, ['Kingdom', 'Park'], true) || $id <= 0) {
            return null;
        }
        return ['type' => strtolower($label), 'label' => $label, 'id' => $id];
    }

    // Remove withdrawn choices from an event's races for voter-facing display (they remain
    // in results). Shared by the ballot views: event() in controller.Voting.php and
    // external_ballot_form in VotingAjax (a follow-up caller). Pure array transform.
    public static function strip_withdrawn_choices($event)
    {
        if (empty($event['races']) || !is_array($event['races'])) {
            return $event;
        }
        foreach ($event['races'] as &$_race) {
            if (!empty($_race['choices'])) {
                $_race['choices'] = array_values(array_filter($_race['choices'], fn ($c) => empty($c['withdrawn_at'])));
            }
        }
        unset($_race);
        return $event;
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
    public function event_id_for_race($voting_race_id)
    {
        return $this->Voting->event_id_for_race($voting_race_id);
    }
    public function event_id_for_choice($voting_choice_id)
    {
        return $this->Voting->event_id_for_choice($voting_choice_id);
    }
    public function event_id_for_ballot($voting_ballot_id)
    {
        return $this->Voting->event_id_for_ballot($voting_ballot_id);
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
    public function active_ballot_votes($voting_ballot_id)
    {
        return $this->Voting->active_ballot_votes($voting_ballot_id);
    }
    public function pending_revote_race_ids($voting_ballot_id, array $race_ids)
    {
        return $this->Voting->pending_revote_race_ids($voting_ballot_id, $race_ids);
    }
    public function ballot_counts($voting_event_id)
    {
        return $this->Voting->ballot_counts($voting_event_id);
    }
    public function runner_eligibility_preview($voting_event_id, $voter_mundane_id)
    {
        return $this->Voting->runner_eligibility_preview($voting_event_id, $voter_mundane_id);
    }
    public function external_ballots_roster($voting_event_id)
    {
        return $this->Voting->external_ballots_roster($voting_event_id);
    }
    public function paper_replacement_notices($voter_mundane_id)
    {
        return $this->Voting->paper_replacement_notices($voter_mundane_id);
    }
    public function ack_paper_notice($voter_mundane_id, $voting_ballot_id)
    {
        return $this->Voting->ack_paper_notice($voter_mundane_id, $voting_ballot_id);
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
    public function list_delegates($voting_event_id)
    {
        return $this->Voting->ListDelegates($voting_event_id);
    }
}
