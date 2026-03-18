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
	
	function add_bracket($request) {
		return $this->Tournament->AddBracket($request);
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

	function get_standings($bracket_id) {
		return $this->Tournament->GetStandings(['BracketId' => $bracket_id]);
	}

}

?>
