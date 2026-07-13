<?php

class Controller_VotingAjax extends Controller
{
    public function __construct($call = null, $id = null)
    {
        parent::__construct($call, $id);
        $this->load_model('Voting');
        header('Content-Type: application/json');
        $this->_csrf_gate($call);
    }

    /**
     * CSRF + method gate. Any action NOT on the GET read-allowlist must be a POST
     * carrying a valid X-CSRF-Token header (window.VOTING_CSRF). New mutation
     * actions are auto-protected — do not add them here. Reject GET-triggered mutations.
     */
    private function _csrf_gate($call)
    {
        $read_actions = ['tally', 'banner', 'candidate_search', 'voter_search', 'preview_resume'];
        $action = strtolower((string)$call);
        if (in_array($action, $read_actions, true)) {
            return;
        }
        if (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'POST') {
            http_response_code(405);
            $this->fail('This action must be submitted as POST.');
        }
        $sent = $_SERVER['HTTP_X_CSRF_TOKEN'] ?? ($this->request->csrf_token ?? '');
        if (!is_string($sent) || !hash_equals($this->_csrfToken(), $sent)) {
            http_response_code(419);
            $this->fail('Invalid or expired request token. Reload the page and try again.');
        }
    }

    private function fail($msg, $detail = '')
    {
        echo json_encode(['status' => 1, 'error' => $msg, 'detail' => $detail]);
        exit;
    }

    private function ok($payload = [])
    {
        echo json_encode(array_merge(['status' => 0], $payload));
        exit;
    }

    private function require_login()
    {
        if (!isset($this->session->user_id)) {
            $this->fail('Not logged in.');
        }
    }

    // ──────────────────── Race / candidate adders (used by edit page) ────────────────────

    public function add_race($voting_event_id = null)
    {
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
        if (($r['Status'] ?? 1) != 0) {
            $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
        }
        $this->ok(['voting_race_id' => $r['Detail']]);
    }

    public function add_candidate($voting_race_id = null)
    {
        $this->require_login();
        $r = $this->Voting->add_candidate([
            'Token' => $this->session->token,
            'VotingRaceId' => (int)$voting_race_id,
            'CandidateMundaneId' => (int)$this->request->CandidateMundaneId,
        ]);
        if (($r['Status'] ?? 1) != 0) {
            $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
        }
        $this->ok(['voting_choice_id' => $r['Detail']]);
    }

    public function add_option($voting_race_id = null)
    {
        $this->require_login();
        $r = $this->Voting->add_option([
            'Token' => $this->session->token,
            'VotingRaceId' => (int)$voting_race_id,
            'Label' => $this->request->Label,
        ]);
        if (($r['Status'] ?? 1) != 0) {
            $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
        }
        $this->ok(['voting_choice_id' => $r['Detail']]);
    }

    public function remove_choice($voting_choice_id = null)
    {
        $this->require_login();
        $r = $this->Voting->remove_choice([
            'Token' => $this->session->token,
            'VotingChoiceId' => (int)$voting_choice_id,
        ]);
        if (($r['Status'] ?? 1) != 0) {
            $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
        }
        $this->ok(['voting_choice_id' => $r['Detail']]);
    }

    public function open_event($voting_event_id = null)
    {
        $this->require_login();
        $r = $this->Voting->open_event([
            'Token' => $this->session->token,
            'VotingEventId' => (int)$voting_event_id,
        ]);
        if (($r['Status'] ?? 1) != 0) {
            $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
        }
        $this->ok();
    }

    // ──────────────────── Cast ballot ────────────────────

    public function cast($voting_event_id = null)
    {
        $this->require_login();
        $votes = $this->request->Votes;
        // Smarty's request mechanism may have different shapes; accept JSON-encoded fallback.
        if (!is_array($votes) && is_string($votes)) {
            $votes = json_decode($votes, true);
        }
        if (!is_array($votes) && isset($_POST['Votes'])) {
            $decoded = json_decode($_POST['Votes'], true);
            if (is_array($decoded)) {
                $votes = $decoded;
            }
        }
        if (!is_array($votes)) {
            $votes = [];
        }

        $r = $this->Voting->cast_ballot([
            'Token' => $this->session->token,
            'VotingEventId' => (int)$voting_event_id,
            'Votes' => $votes,
        ]);
        if (($r['Status'] ?? 1) != 0) {
            $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
        }
        $this->ok(['voting_ballot_id' => $r['Detail']]);
    }

    public function external_ballot($voting_event_id = null)
    {
        $this->require_login();
        $voting_event_id = (int)$voting_event_id;
        if (!$this->Voting->user_is_runner_of_event((int)$this->session->user_id, $voting_event_id)) {
            $this->fail('Not authorized to enter external ballots.');
        }
        $voter_id = (int)$this->request->VoterMundaneId;
        if (!$voter_id) {
            $this->fail('Voter required.');
        }

        $votes = $this->request->Votes;
        if (!is_array($votes) && is_string($votes)) {
            $votes = json_decode($votes, true);
        }
        if (!is_array($votes) && isset($_POST['Votes'])) {
            $decoded = json_decode($_POST['Votes'], true);
            if (is_array($decoded)) {
                $votes = $decoded;
            }
        }
        if (!is_array($votes)) {
            $votes = [];
        }

        $r = $this->Voting->cast_ballot([
            'Token' => $this->session->token,
            'VotingEventId' => $voting_event_id,
            'VoterMundaneId' => $voter_id,
            'EnteredByRunnerId' => (int)$this->session->user_id,
            'Votes' => $votes,
        ]);
        if (($r['Status'] ?? 1) != 0) {
            $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
        }
        $this->ok(['voting_ballot_id' => $r['Detail']]);
    }

    // ──────────────────── Tally / banner / publish ────────────────────

    public function tally($voting_event_id = null)
    {
        $voting_event_id = (int)$voting_event_id;
        // Pre-publish: runner-only with officer-on-ballot suppression.
        // Post-publish: anyone can see (use the public results page; we still allow authenticated reads for consistency).
        $gate = $this->Voting->tally_gate_info($voting_event_id);
        if (!$gate) {
            $this->fail('Event not found.');
        }
        $status = $gate['status'];
        $hide = (int)$gate['hide'];

        if (in_array($status, ['open', 'closed'])) {
            $this->require_login();
            if (!$this->Voting->user_is_runner_of_event((int)$this->session->user_id, $voting_event_id)) {
                $this->fail('Not authorized.');
            }
            $uid = (int)$this->session->user_id;
            $is_admin = Ork3::$Lib->authorization->HasAuthority($uid, AUTH_ADMIN, 0, AUTH_ADMIN);
            if ($hide && !$is_admin) {
                if ($this->Voting->user_is_candidate_in_event($uid, $voting_event_id)) {
                    http_response_code(403);
                    $this->fail('You are a candidate in this event; results are not visible to you until publication.');
                }
            }
            $tally = $this->Voting->tally($voting_event_id);
            $this->ok(['tally' => $tally, 'event_status' => $status]);
        }
        // Published / unpublished — defer to public reader (which gates on status='published').
        $r = $this->Voting->tally_public($voting_event_id);
        if (($r['Status'] ?? 1) != 0) {
            $this->fail($r['Error'] ?? 'Failed');
        }
        $this->ok(['tally' => $r['Tally'], 'event_status' => $status]);
    }

    public function banner($mundane_id = null)
    {
        $this->require_login();
        $mundane_id = (int)$mundane_id;
        // Only allow self or admin.
        $uid = (int)$this->session->user_id;
        if ($mundane_id !== $uid && !Ork3::$Lib->authorization->HasAuthority($uid, AUTH_ADMIN, 0, AUTH_ADMIN)) {
            $this->fail('Not authorized.');
        }
        $events = $this->Voting->active_for_voter($mundane_id);
        // Filter to those without an active ballot.
        $pending = array_values(array_filter($events, fn ($e) => empty($e['active_ballot_id']) || !empty($e['pending_revote'])));
        $this->ok(['events' => $pending]);
    }

    public function release_provisional($voting_ballot_id = null)
    {
        $this->require_login();
        $r = $this->Voting->release_provisional([
            'Token' => $this->session->token,
            'VotingBallotId' => (int)$voting_ballot_id,
            'Reason' => $this->request->Reason,
        ]);
        if (($r['Status'] ?? 1) != 0) {
            $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
        }
        $this->ok();
    }

    public function resolve_tie($voting_race_id = null)
    {
        $this->require_login();
        $r = $this->Voting->resolve_tie([
            'Token' => $this->session->token,
            'VotingRaceId' => (int)$voting_race_id,
            'WinnerChoiceId' => (int)$this->request->WinnerChoiceId,
            'Note' => $this->request->Note,
        ]);
        if (($r['Status'] ?? 1) != 0) {
            $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
        }
        $this->ok();
    }

    public function publish($voting_event_id = null)
    {
        $this->require_login();
        $r = $this->Voting->publish([
            'Token' => $this->session->token,
            'VotingEventId' => (int)$voting_event_id,
        ]);
        if (($r['Status'] ?? 1) != 0) {
            $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
        }
        $this->ok();
    }

    public function unpublish($voting_event_id = null)
    {
        $this->require_login();
        $r = $this->Voting->unpublish([
            'Token' => $this->session->token,
            'VotingEventId' => (int)$voting_event_id,
        ]);
        if (($r['Status'] ?? 1) != 0) {
            $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
        }
        $this->ok();
    }

    // ──────────────────── Player searches (kn-ac-results format) ────────────────────

    public function candidate_search($scope = null)
    {
        $this->require_login();
        // $scope is "Kingdom_10" or "Park_5" — single arg from the route system (4-part URLs collapse to one).
        $parts = explode('_', (string)$scope, 2);
        $scope_type = $parts[0] ?? '';
        $scope_id = (int)($parts[1] ?? 0);
        if (!in_array($scope_type, ['Kingdom', 'Park']) || !$scope_id) {
            $this->ok(['results' => []]);
        }

        // IDOR gate: only scope officers OR delegated runners of an event in this scope may
        // enumerate players (delegated runners aren't officers, so user_can_run_in_scope alone
        // would wrongly block the legitimate voter_search / candidate-add flows).
        if (!$this->Voting->user_can_manage_voting_in_scope((int)$this->session->user_id, strtolower($scope_type), (int)$scope_id)) {
            $this->ok(['results' => []]);
        }

        // q can come from $_GET (e.g. "&q=foo"), or from $this->request->q if Smarty parsed it.
        $q = trim($_GET['q'] ?? ($this->request->q ?? ''));
        if (strlen($q) < 2) {
            $this->ok(['results' => []]);
        }

        $rows = $this->Voting->search_players_in_scope($scope_type, $scope_id, $q);
        $results = [];
        foreach ($rows as $row) {
            $display = $row['persona'] ?: trim(($row['given_name'] ?? '') . ' ' . ($row['surname'] ?? ''));
            if ($display === '') {
                $display = $row['username'];
            }
            $loc = trim(($row['k_abbr'] ?? '') . (!empty($row['p_abbr']) ? ':' . $row['p_abbr'] : ''));
            $label = $display . ' (' . $row['username'] . ')' . ($loc !== '' ? ' [' . $loc . ']' : '');
            $results[] = [
                'value'    => (int)$row['mundane_id'],
                'label'    => $label,
                'display'  => $display,
                'username' => $row['username'],
            ];
        }
        $this->ok(['results' => $results]);
    }

    public function voter_search($voting_event_id = null)
    {
        $this->require_login();
        $voting_event_id = (int)$voting_event_id;
        if (!$this->Voting->user_is_runner_of_event((int)$this->session->user_id, $voting_event_id)) {
            $this->fail('Not authorized.');
        }
        // Scope from event.
        $scope = $this->Voting->event_scope($voting_event_id);
        if (!$scope) {
            $this->fail('Event not found.');
        }
        // Reuse candidate_search — single combined-arg signature.
        $this->candidate_search(ucfirst($scope['scope_type']) . '_' . (int)$scope['scope_id']);
    }

    // Admin-only voter->choice reveal. Writes an admin_voter_choice_view audit row.
    // POST + X-CSRF-Token enforced by the constructor gate (not a read action).
    public function voter_choices($voting_event_id = null)
    {
        $this->require_login();
        $voting_event_id = (int)$voting_event_id;
        $uid = (int)$this->session->user_id;
        if (!Ork3::$Lib->authorization->HasAuthority($uid, AUTH_ADMIN, 0, AUTH_ADMIN)) {
            $this->fail('Only ORK administrators may reveal an individual ballot.');
        }
        $voter_id = (int)$this->request->VoterMundaneId;
        if (!$voter_id) {
            $this->fail('Voter required.');
        }
        $choices = $this->Voting->voter_choices($voting_event_id, $voter_id, $uid);
        $this->ok(['choices' => $choices]);
    }

    public function reopen_event($voting_event_id = null)
    {
        $this->require_login();
        $voting_event_id = (int)$voting_event_id;
        if (!$this->Voting->user_is_runner_of_event((int)$this->session->user_id, $voting_event_id)) {
            $this->fail('Not authorized.');
        }
        $r = $this->Voting->reopen_event([
            'Token' => $this->session->token,
            'VotingEventId' => (int)$voting_event_id,
            'Confirm' => !empty($this->request->Confirm) ? 1 : 0,
        ]);
        if (($r['Status'] ?? 1) != 0) {
            $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
        }
        $this->ok();
    }

    public function preview_resume($voting_event_id = null)
    {
        $this->require_login();
        $voting_event_id = (int)$voting_event_id;
        if (!$this->Voting->user_is_runner_of_event((int)$this->session->user_id, $voting_event_id)) {
            $this->fail('Not authorized.');
        }
        $preview = $this->Voting->preview_resume($voting_event_id);
        $this->ok($preview);
    }

    public function resume_event($voting_event_id = null)
    {
        $this->require_login();
        $r = $this->Voting->resume_event([
            'Token' => $this->session->token,
            'VotingEventId' => (int)$voting_event_id,
            'Decision' => $this->request->Decision,
        ]);
        if (($r['Status'] ?? 1) != 0) {
            $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
        }
        $this->ok();
    }

    public function edit_race($voting_race_id = null)
    {
        $this->require_login();
        $r = $this->Voting->edit_race([
            'Token' => $this->session->token,
            'VotingRaceId' => (int)$voting_race_id,
            'Title' => $this->request->Title,
            'Rationale' => $this->request->Rationale,
        ]);
        if (($r['Status'] ?? 1) != 0) {
            $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
        }
        $this->ok();
    }

    public function edit_choice($voting_choice_id = null)
    {
        $this->require_login();
        $r = $this->Voting->edit_choice([
            'Token' => $this->session->token,
            'VotingChoiceId' => (int)$voting_choice_id,
            'Label' => $this->request->Label,
        ]);
        if (($r['Status'] ?? 1) != 0) {
            $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
        }
        $this->ok();
    }

    public function restore_choice($voting_choice_id = null)
    {
        $this->require_login();
        $r = $this->Voting->restore_choice([
            'Token' => $this->session->token,
            'VotingChoiceId' => (int)$voting_choice_id,
        ]);
        if (($r['Status'] ?? 1) != 0) {
            $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
        }
        $this->ok();
    }

    public function remove_race($voting_race_id = null)
    {
        $this->require_login();
        $r = $this->Voting->remove_race([
            'Token' => $this->session->token,
            'VotingRaceId' => (int)$voting_race_id,
        ]);
        if (($r['Status'] ?? 1) != 0) {
            $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
        }
        $this->ok();
    }


    public function edit_event($voting_event_id = null)
    {
        $this->require_login();
        $req = ['Token' => $this->session->token, 'VotingEventId' => (int)$voting_event_id];
        foreach (['Title','Description','StartDate','EndDate'] as $k) {
            if (isset($this->request->$k)) {
                $req[$k] = $this->request->$k;
            }
        }
        foreach (['AnonymousToRunner','HideResultsFromCandidateRunners','AllowProvisional'] as $k) {
            if (isset($this->request->$k)) {
                $req[$k] = !empty($this->request->$k) ? 1 : 0;
            }
        }
        $r = $this->Voting->update_event($req);
        if (($r['Status'] ?? 1) != 0) {
            $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
        }
        $this->ok();
    }

    public function edit_race_settings($voting_race_id = null)
    {
        $this->require_login();
        $req = ['Token' => $this->session->token, 'VotingRaceId' => (int)$voting_race_id];
        if (isset($this->request->VotingMode)) {
            $req['VotingMode'] = $this->request->VotingMode;
        }
        if (isset($this->request->NotaCountsAs)) {
            $req['NotaCountsAs'] = $this->request->NotaCountsAs;
        }
        foreach (['AllowAbstain','AllowNoneOfAbove','IsNonBinding'] as $k) {
            if (isset($this->request->$k)) {
                $req[$k] = !empty($this->request->$k) ? 1 : 0;
            }
        }
        $r = $this->Voting->edit_race_settings($req);
        if (($r['Status'] ?? 1) != 0) {
            $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
        }
        $this->ok();
    }

}
