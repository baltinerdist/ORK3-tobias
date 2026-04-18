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

	function get_teams($tournament_id) {
		return ['Status' => 0, 'Detail' => []];
	}

	function create_team($request) {
		return $this->Tournament->CreateTeam($request);
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

	function auth_check($request) {
		return $this->Tournament->CheckAuth($request);
	}

	function get_standings($bracket_id) {
		return $this->Tournament->GetStandings(['BracketId' => $bracket_id]);
	}

	function get_player_history($mundane_id) {
		$report = $this->Report->GetPlayerTournamentHistory(['MundaneId' => $mundane_id]);
		$rows = is_array($report['Detail']) ? $report['Detail'] : [];
		if (empty($rows)) return [];

		$bracketStandings = [];
		foreach ($rows as &$row) {
			$bid = $row['BracketId'];
			if (!isset($bracketStandings[$bid])) {
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
