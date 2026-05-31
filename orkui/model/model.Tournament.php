<?php

class Model_Tournament extends Model {

	function __construct() {
		parent::__construct();
		$this->Report     = new APIModel('Report');
		$this->Tournament = new APIModel('Tournament');
	}

	function get_tournies($request) {
		return $this->Report->TournamentReport($request);
	}

	function create_tournament($request) {
		return $this->Tournament->CreateTournament($request);
	}

	function delete_tournament($request) {
		return $this->Tournament->DeleteTournament($request);
	}

	function update_tournament($request) {
		return $this->Tournament->UpdateTournament($request);
	}

	function add_bracket($request) {
		return $this->Tournament->AddBracket($request);
	}

	function update_bracket($request) {
		return $this->Tournament->UpdateBracket($request);
	}

	function add_participant($request) {
		return $this->Tournament->AddParticipant($request);
	}

	function get_brackets($tournament_id) {
		return $this->Tournament->GetBrackets(['TournamentId' => $tournament_id]);
	}

	function get_participants($request) {
		return $this->Tournament->GetParticipants($request);
	}

	function get_matches($request) {
		return $this->Tournament->GetMatches($request);
	}

	function remove_participant($request) {
		return $this->Tournament->RemoveParticipant($request);
	}

	function generate_matches($request) {
		return $this->Tournament->GenerateMatches($request);
	}

	function post_match_result($request) {
		return $this->Tournament->PostMatchResult($request);
	}

	function reset_match($request) {
		return $this->Tournament->ResetMatch($request);
	}

	function create_confirmation_match($request) {
		return $this->Tournament->CreateConfirmationMatch($request);
	}

	function create_tiebreaker_match($request) {
		return $this->Tournament->CreateTiebreakerMatch($request);
	}

	function create_round_robin_tiebreaker($request) {
		return $this->Tournament->CreateRoundRobinTiebreaker($request);
	}

	function decline_round_robin_tiebreaker($request) {
		return $this->Tournament->DeclineRoundRobinTiebreaker($request);
	}

	function record_ironman_win($request) {
		return $this->Tournament->RecordIronmanWin($request);
	}

	function complete_bracket($request) {
		return $this->Tournament->CompleteBracket($request);
	}

	function delete_bracket($request) {
		return $this->Tournament->DeleteBracket($request);
	}

	function clear_bracket_matches($request) {
		return $this->Tournament->ClearBracketMatches($request);
	}

	function pools_to_bracket($request) {
		return $this->Tournament->PoolsToBracket($request);
	}

	function auth_check($request) {
		return $this->Tournament->CheckAuth($request);
	}

	function save_standings_points($request) {
		return $this->Tournament->SaveStandingsPoints($request);
	}

	function reorder_seeds($request) {
		return $this->Tournament->ReorderSeeds($request);
	}

	function update_participant_status($request) {
		return $this->Tournament->UpdateParticipantStatus($request);
	}

	function update_alias($request) {
		return $this->Tournament->UpdateAlias($request);
	}

	function search_parks($query) {
		return $this->Tournament->SearchParks($query);
	}

	function search_events($query) {
		return $this->Tournament->SearchEvents($query);
	}

	function get_tournament_event_label($tournament_id) {
		return $this->Tournament->GetTournamentEventLabel($tournament_id);
	}

	function get_standings_points($tournament_id) {
		return $this->Tournament->GetStandingsPoints($tournament_id);
	}

	function get_standings($bracket_id) {
		return $this->Tournament->GetStandings(['BracketId' => $bracket_id]);
	}

	function get_reeves($request) {
		return $this->Tournament->GetReeves($request);
	}

	function add_reeve($request) {
		return $this->Tournament->AddReeve($request);
	}

	function remove_reeve($request) {
		return $this->Tournament->RemoveReeve($request);
	}

	function save_point_score($request) {
		return $this->Tournament->SavePointScore($request);
	}

	function add_points_round($request) {
		return $this->Tournament->AddPointsRound($request);
	}

	function get_point_standings($request) {
		return $this->Tournament->GetPointStandings($request);
	}

	function get_version($request) {
		return $this->Tournament->GetVersion($request);
	}

	function get_reeve_role($request) {
		return $this->Tournament->GetReeveRole($request);
	}

	function get_player_history($mundane_id) {
		$report = $this->Report->GetPlayerTournamentHistory(['MundaneId' => $mundane_id]);
		$rows = is_array($report['Detail']) ? $report['Detail'] : [];
		if (empty($rows)) return [];

		// Perf: memoize standings per BracketId so each bracket is fetched at most once.
		// GetStandings() issues 2-3 queries; remaining cost is O(distinct brackets) per
		// player history (the player appears once per bracket, so the memo only collapses
		// the rare same-bracket dup). A true O(1)-query path would need a batched
		// GetStandingsForBrackets([bid,...]) in class.Tournament.php (out of scope here).
		$bracketStandings = [];
		foreach ($rows as &$row) {
			$bid = $row['BracketId'];
			if (!array_key_exists($bid, $bracketStandings)) {
				$s = $this->Tournament->GetStandings(['BracketId' => $bid]);
				$bracketStandings[$bid] = is_array($s['Detail']) ? $s['Detail'] : [];
			}
			$row['Placement'] = null;
			foreach ($bracketStandings[$bid] as $s) {
				if ((int)$s['ParticipantId'] === (int)$row['ParticipantId']) {
					$row['Placement'] = (int)$s['Rank'];
					break;
				}
			}
		}
		unset($row);
		return $rows;
	}

}

?>
