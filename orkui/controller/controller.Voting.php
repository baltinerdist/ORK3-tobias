<?php

class Controller_Voting extends Controller
{
    public function __construct($call = null, $id = null)
    {
        parent::__construct($call, $id);
        $this->load_model('Voting');
        $this->load_model('Park');
        $this->load_model('Kingdom');
        $this->load_model('Reports');
        $this->data['VotingCsrf'] = $this->_csrfToken();
    }

    private function require_login()
    {
        if (!isset($this->session->user_id)) {
            header('Location: ' . UIR . 'Login/login/Voting/index');
            exit;
        }
    }

    // ─────────────────────── Listing ───────────────────────

    public function index($scope = null)
    {
        // $scope is "Kingdom_10" or "Park_5" — single arg from the routing system.
        $parsed = Model_Voting::parse_scope($scope);
        if ($parsed === null) {
            $this->data['Error'] = 'Invalid scope.';
            $this->template = '../revised-frontend/Voting_index.tpl';
            return;
        }
        $st = $parsed['type'];
        $scope_id = $parsed['id'];
        $this->data['scope_type'] = $st;
        $this->data['scope_id'] = $scope_id;
        $this->data['scope_type_label'] = $parsed['label'];

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
        $this->data['can_create'] = $this->Voting->user_can_run_in_scope((int)$this->session->user_id, $st, $scope_id);

        $this->template = '../revised-frontend/Voting_index.tpl';
    }

    // ─────────────────────── Create / Edit ───────────────────────

    public function create($scope = null)
    {
        $this->require_login();
        $parsed = Model_Voting::parse_scope($scope);
        if ($parsed === null) {
            header('Location: ' . UIR);
            exit;
        }
        $st = $parsed['type'];
        $scope_id = $parsed['id'];
        if (!$this->Voting->user_can_run_in_scope((int)$this->session->user_id, $st, $scope_id)) {
            header('Location: ' . UIR);
            exit;
        }
        $this->data['scope_type'] = $st;
        $this->data['scope_id'] = $scope_id;
        $this->data['scope_type_label'] = $parsed['label'];
        if ($st === 'kingdom') {
            $this->data['scope_name'] = $this->Kingdom->get_kingdom_name($scope_id) ?: "Kingdom #$scope_id";
        } else {
            $pi = $this->Park->get_park_info($scope_id);
            $this->data['scope_name'] = $pi['ParkInfo']['ParkName'] ?? "Park #$scope_id";
        }

        // Form submit.
        if (!empty($this->request->Action) && $this->request->Action === 'create_event') {
            if (!hash_equals($this->_csrfToken(), (string)($this->request->csrf_token ?? ''))) {
                $this->data['Error'] = 'Invalid or expired request token. Reload and try again.';
                $this->template = '../revised-frontend/Voting_create.tpl';
                return;
            }
            $req = [
                'Token' => $this->session->token,
                'EventType' => $this->request->EventType,
                'ScopeType' => $st,
                'ScopeId' => $scope_id,
                'Title' => $this->request->Title,
                'Description' => $this->request->Description,
                'StartDate' => $this->request->StartDate,
                'EndDate' => $this->request->EndDate,
                'HideResultsFromCandidateRunners' => !empty($this->request->HideResultsFromCandidateRunners) ? 1 : 0,
                'AllowProvisional' => !empty($this->request->AllowProvisional) ? 1 : 0,
            ];
            $r = $this->Voting->create_event($req);
            if (($r['Status'] ?? 1) == 0) {
                header('Location: ' . UIR . 'Voting/edit/' . $r['Detail']);
                exit;
            } else {
                $this->data['Error'] = ($r['Error'] ?? 'Error') . ': ' . ($r['Detail'] ?? '');
            }
        }

        $roll = $this->Voting->eligible_roll($st, $scope_id);
        $this->data['elig_summary'] = [
            'count'     => (int)$roll['count'],
            'is_default' => (bool)$roll['is_default'],
            'rule_line' => Voting::rule_summary_line($roll['rules'], $roll['is_default']),
        ];
        $this->template = '../revised-frontend/Voting_create.tpl';
    }

    public function edit($voting_event_id = null)
    {
        $this->require_login();
        $voting_event_id = (int)$voting_event_id;
        $r = $this->Voting->get_event($voting_event_id);
        if (($r['Status'] ?? 1) != 0) {
            header('Location: ' . UIR);
            exit;
        }
        $event = $r['Event'];
        if (!$this->Voting->user_is_runner_of_event((int)$this->session->user_id, $voting_event_id, $event)) {
            header('Location: ' . UIR . 'Voting/results/' . $voting_event_id);
            exit;
        }
        if (!empty($event['reopened_by_mundane_id'])) {
            $event['reopened_by_persona'] = $this->Voting->reopened_by_persona($event['reopened_by_mundane_id']);
        }
        $this->data['event'] = $event;
        $this->data['voting_event_id'] = $voting_event_id;
        $this->data['can_edit'] = ($event['status'] === 'draft');
        $this->data['can_reopen'] = ($event['status'] === 'open');
        $roll = $this->Voting->eligible_roll($event['scope_type'], (int)$event['scope_id']);
        $this->data['elig_summary'] = [
            'count'     => (int)$roll['count'],
            'is_default' => (bool)$roll['is_default'],
            'rule_line' => Voting::rule_summary_line($roll['rules'], $roll['is_default']),
        ];
        $this->template = '../revised-frontend/Voting_edit.tpl';
    }

    // ─────────────────────── Voter ballot ───────────────────────

    public function event($voting_event_id = null)
    {
        $this->require_login();
        $voting_event_id = (int)$voting_event_id;
        $r = $this->Voting->get_event($voting_event_id);
        if (($r['Status'] ?? 1) != 0) {
            $this->data['Error'] = 'Event not found.';
            $this->template = '../revised-frontend/Voting_event.tpl';
            return;
        }
        $event = $r['Event'];
        // Hide withdrawn choices from the voter UI (they remain in results display).
        $event = Model_Voting::strip_withdrawn_choices($event);

        // Check eligibility.
        $elig = $this->Voting->eligibility_check([
            'Token' => $this->session->token,
            'VotingEventId' => $voting_event_id,
        ]);
        $this->data['eligibility'] = $elig;

        // Look up the voter's currently-active ballot for this event (vote-change UX).
        $uid = (int)$this->session->user_id;
        $active = $this->Voting->active_ballot_for_voter($voting_event_id, $uid);
        $this->data['active_ballot'] = $active;

        // Prior per-race votes, for pre-populating the ballot on a vote-change visit.
        $this->data['active_votes'] = $active
            ? $this->Voting->active_ballot_votes((int)$active['voting_ballot_id'])
            : [];

        // Pending revote: voter has an active ballot but is missing votes for some races
        // (Resume->Discard cleared their per-race votes).
        $pending_race_ids = [];
        if ($active) {
            $pending_race_ids = $this->Voting->pending_revote_race_ids($active['voting_ballot_id'], array_column($event['races'], 'voting_race_id'));
        }
        $this->data['pending_revote'] = !empty($pending_race_ids) && $active;
        $this->data['pending_race_ids'] = $pending_race_ids;

        // If pending revote, narrow visible races to just the pending ones; the cast endpoint
        // merges in the voter's prior un-impacted race votes when forming the new ballot.
        if (!empty($pending_race_ids) && $active) {
            $pending_set = array_flip($pending_race_ids);
            $event['races'] = array_values(array_filter($event['races'], fn ($r) => isset($pending_set[(int)$r['voting_race_id']])));
        }
        $this->data['event'] = $event;
        $this->data['voting_event_id'] = $voting_event_id;

        $this->template = '../revised-frontend/Voting_event.tpl';
    }

    // ─────────────────────── Runner dashboard ───────────────────────

    public function runner($voting_event_id = null)
    {
        $this->require_login();
        $voting_event_id = (int)$voting_event_id;
        // Lazy scheduler (no cron in this repo): auto-open due drafts, release provisional
        // ballots that now qualify, and auto-close events past end_date — so the dashboard a
        // runner opens is always current. cycle_event_status() is a full system-wide sweep, so
        // rate-limit it to at most once per 45s window (across all dashboard traffic) via a
        // short-TTL cache flag; a memcache miss (e.g. no cache server) falls back to running it.
        $swept = Ork3::$Lib->ghettocache->get('Voting.cycle_event_status', 'sweep', 45);
        if ($swept === false) {
            $this->Voting->cycle_event_status();
            Ork3::$Lib->ghettocache->cache('Voting.cycle_event_status', 'sweep', 1);
        }
        $r = $this->Voting->get_event($voting_event_id);
        if (($r['Status'] ?? 1) != 0) {
            header('Location: ' . UIR);
            exit;
        }
        $event = $r['Event'];
        if (!$this->Voting->user_is_runner_of_event((int)$this->session->user_id, $voting_event_id, $event)) {
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
        $this->data['counts'] = $this->Voting->ballot_counts($voting_event_id);

        // Provisional ballots awaiting release (runner review panel, finding 24). Only
        // meaningful pre-publish; the template gates on status open/closed.
        $this->data['provisional_ballots'] = $this->Voting->provisional_ballots($voting_event_id);

        // Live electorate size for turnout (pre-publish shows a live estimate; post-publish the
        // frozen figure on the event is authoritative).
        if (!empty($event['eligible_count'])) {
            $this->data['eligible_count'] = (int)$event['eligible_count'];
        } else {
            $this->data['eligible_count'] = (int)$this->Voting->eligible_count($event['scope_type'], (int)$event['scope_id']);
        }

        // Delegate Runner (finding 35): who may add/remove, and the current delegate list.
        $this->data['can_delegate'] = $this->data['is_admin']
            || $this->Voting->user_can_run_in_scope((int)$this->session->user_id, strtolower($event['scope_type']), (int)$event['scope_id']);
        $this->data['delegates'] = $this->Voting->list_delegates($voting_event_id);

        $this->template = '../revised-frontend/Voting_runner.tpl';
    }

    // ─────────────────────── Public results ───────────────────────

    public function results($voting_event_id = null)
    {
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

    public function audit($voting_event_id = null)
    {
        $this->require_login();
        $voting_event_id = (int)$voting_event_id;
        $uid = (int)$this->session->user_id;
        if (!$this->Voting->user_is_runner_of_event($uid, $voting_event_id)) {
            header('Location: ' . UIR . 'Voting/results/' . $voting_event_id);
            exit;
        }
        $is_admin = Ork3::$Lib->authorization->HasAuthority($uid, AUTH_ADMIN, 0, AUTH_ADMIN);
        $this->data['is_admin'] = $is_admin;
        $this->data['rows'] = $this->Voting->audit_log($voting_event_id, 500, !$is_admin);
        $this->data['voting_event_id'] = $voting_event_id;
        $this->template = '../revised-frontend/Voting_audit.tpl';
    }
}
