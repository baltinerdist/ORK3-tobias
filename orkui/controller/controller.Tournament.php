<?php
class Controller_Tournament extends Controller {


	public function __construct($call=null, $id=null) {
		parent::__construct($call, $id);
		
		$this->load_model('Park');
		$this->load_model('Kingdom');
		
		if (isset($this->session->park_id)) {
			$park_info = $this->Park->get_park_info($this->session->park_id);
			$this->session->park_name = $park_info['ParkInfo']['ParkName'];
			$this->data['menu']['park'] = array( 'url' => UIR.'Park/index/'.$this->session->park_id, 'display' => $this->session->park_name );
		}
		
		if (isset($park_info)) {
			$this->session->kingdom_id   = $park_info['KingdomInfo']['KingdomId'];
			$this->session->kingdom_name = $park_info['KingdomInfo']['KingdomName'];
			$this->data['menu']['kingdom'] = array( 'url' => UIR.'Kingdom/profile/'.$this->session->kingdom_id, 'display' => $this->session->kingdom_name );
		}
		$this->data['kingdom_id'] = $this->session->kingdom_id;
		$this->data['park_id'] = $this->session->park_id;
		$this->data['kingdom_name'] = $this->session->kingdom_name;
		
		if (isset($this->request->park_name)) {
			$this->session->park_name = $this->request->park_name;
		}
		$this->data['park_name'] = $this->session->park_name;
	
		$_uid = isset($this->session->user_id) ? (int)$this->session->user_id : 0;
		if ($_uid > 0 && Ork3::$Lib->authorization->HasAuthority($_uid, AUTH_PARK, (int)$this->session->park_id, AUTH_EDIT)) {
			$this->data['menu']['admin'] = array( 'url' => UIR.'Admin/park/'.$this->session->park_id, 'display' => 'Admin Panel <i class="fas fa-cog"></i>', 'no-crumb' => 'no-crumb' );
			$this->data['menulist']['admin'] = array(
					array( 'url' => UIR.'Tournament/profile/'.$id, 'display' => 'Tournament' ),
					array( 'url' => UIR.'Admin/park/'.$this->session->park_id, 'display' => 'Park' ),
					array( 'url' => UIR.'Admin/kingdom/'.$this->session->kingdom_id, 'display' => 'Kingdom' )
				);
		}
		//$this->data['menu']['event'] = array( 'url' => UIR.'Park/index/'.$this->session->park_id, 'display' => $this->session->park_name );
	}
	
	public function worksheet($tournament_id) {
		if (strlen($this->request->Action) > 0) {
			$this->request->save('Tournament_worksheet', true);
			if (!isset($this->session->user_id)) {
				header( 'Location: '.UIR.'Login/login/Tournament/worksheet' );
			} else {
				$r = null;
				switch ($this->request->Action) {
					case 'addbracket':
						$r = $this->Tournament->add_bracket(array(
								'Token' => $this->session->token,
								'TournamentId' => $tournament_id,
								'Style' => $this->request->Tournament_worksheet->Style,
								'StyleNote' => $this->request->Tournament_worksheet->StyleNote,
								'Method' => $this->request->Tournament_worksheet->Method,
								'Rings' => $this->request->Tournament_worksheet->Rings,
								'Participants' => $this->request->Tournament_worksheet->Participants,
								'Seeding' => $this->request->Tournament_worksheet->Seeding,
							));
						break;
				}
				if (isset($r) && $r['Status'] == 0) {
					$this->request->clear('Tournament_worksheet');
				} else if(isset($r) && $r['Status'] == 5) {
					header( 'Location: '.UIR.'Login/login/Tournament/worksheet' );
				} else if (isset($r)) {
					$this->data['Error'] = $r['Error'].':<p>'.$r['Detail'];
				}
			}
		}
		$this->data['tournament_id'] = $tournament_id;
		$this->data['brackets'] = $this->Tournament->get_brackets($tournament_id);
	}
	
	public function create($post=null) {
		if (strlen($post) > 0) {
			$this->request->save('Tournament_create', true);
			if (!isset($this->session->user_id)) {
				header( 'Location: '.UIR.'Login/login/Tournament/create' );
			} else {
				$r = null;
				switch ($post) {
					case 'create':
						$r = $this->Tournament->create_tournament(array(
								'Token' => $this->session->token,
								'KingdomId' => $this->request->Tournament_create->KingdomId,
								'ParkId' => $this->request->Tournament_create->ParkId,
								'EventCalendarDetailId' => $this->request->Tournament_create->EventCalendarDetailId,
								'Name' => $this->request->Tournament_create->Name,
								'Description' => $this->request->Tournament_create->Description,
								'Url' => $this->request->Tournament_create->Url,
								'When' => $this->request->Tournament_create->When,
							));
						break;
				}
				if (isset($r) && $r['Status'] == 0) {
					$this->request->clear('Tournament_create');
				} else if(isset($r) && $r['Status'] == 5) {
					header( 'Location: '.UIR.'Login/login/Tournament/create' );
				} else if (isset($r)) {
					$this->data['Error'] = $r['Error'].':<p>'.$r['Detail'];
				}
			}
		}
		$this->data['KingdomId'] = $this->request->KingdomId;
		$this->data['ParkId'] = $this->request->ParkId;
		$this->data['EventCalendarDetailId'] = $this->request->EventCalendarDetailId;
		if ($this->request->exists('Tournament_create')) {
			$this->data['Tournament_create'] = $this->request->Tournament_create->Request;
			$this->data['KingdomId'] = $this->request->Tournament_create->KingdomId;
			$this->data['ParkId'] = $this->request->Tournament_create->ParkId;
			$this->data['EventCalendarDetailId'] = $this->request->Tournament_create->EventCalendarDetailId;
		}
		$this->data['Tournaments'] = $this->Tournament->get_tournies(array(
				'KingdomId' => $this->data['KingdomId'],
				'ParkId' =>  $this->data['ParkId'],
				'EventCalendarDetailId' =>  $this->data['EventCalendarDetailId']
			));
	}

	public function profile($tournament_id) {
		$this->template = '../revised-frontend/Tournametnew_index.tpl';
		$tournament_id  = (int)preg_replace('/[^0-9]/', '', $tournament_id ?? '');

		if (!valid_id($tournament_id)) {
			header('Location: ' . UIR . 'Tournament/create');
			exit;
		}

		// Fetch tournament record via TournamentReport (accepts TournamentId filter)
		$tr         = $this->Tournament->get_tournies(['TournamentId' => $tournament_id]);
		$tournament = $tr['Tournaments'][0] ?? null;
		if (!$tournament) {
			header('Location: ' . UIR . 'Tournament/create');
			exit;
		}
		$this->data['tournament'] = $tournament;

		// Build formatted event label for Edit modal pre-fill
		$this->data['tournament_event_label'] = '';
		if (valid_id($tournament['EventCalendarDetailId'])) {
			$_elr = $this->Tournament->get_tournament_event_label($tournament_id);
			$this->data['tournament_event_label'] = $_elr['Detail'] ?? ($tournament['EventName'] ?? '');
		}

		// Load standings points config (bypasses TournamentReport cache)
		$_spr = $this->Tournament->get_standings_points($tournament_id);
		$this->data['standings_points'] = $_spr['Detail'] ?? [5,4,3,2,1,0,0,0];

		// Auth: kingdom > park level edit
		$_uid      = isset($this->session->user_id) ? (int)$this->session->user_id : 0;
		$canManage = false;
		if ($_uid > 0) {
			if (valid_id($tournament['KingdomId'])) {
				$canManage = Ork3::$Lib->authorization->HasAuthority($_uid, AUTH_KINGDOM, (int)$tournament['KingdomId'], AUTH_EDIT);
			}
			if (!$canManage && valid_id($tournament['ParkId'])) {
				$canManage = Ork3::$Lib->authorization->HasAuthority($_uid, AUTH_PARK, (int)$tournament['ParkId'], AUTH_EDIT);
			}
		}
		// Resolve this user's tournament-scoped reeve role (organizer / bracket_runner / null)
		$isOrganizerReeve = false;
		$isBracketRunner  = false;
		if ($_uid > 0 && isset($this->session->token)) {
			$_rr   = $this->Tournament->get_reeve_role([
				'Token'        => $this->session->token,
				'TournamentId' => $tournament_id,
			]);
			$_role = $_rr['Detail']['Role'] ?? null;
			$isOrganizerReeve = ($_role === 'organizer');
			$isBracketRunner  = ($_role === 'bracket_runner');
		}

		// Organizer reeves get full manage rights so existing manage UI lights up.
		if ($isOrganizerReeve) $canManage = true;

		$this->data['CanManageTournament'] = $canManage;
		$this->data['IsOrganizerReeve']    = $isOrganizerReeve;
		$this->data['IsBracketRunner']     = $isBracketRunner;
		$this->data['CanManageReeves']     = $canManage; // edit-auth OR organizer reeve (folded into $canManage above)
		$this->data['LoggedIn']            = isset($this->session->user_id);

		// Reeve list for initial server render (only meaningful for managers)
		$this->data['Reeves'] = [];
		if ($canManage && isset($this->session->token)) {
			$_reeves = $this->Tournament->get_reeves([
				'Token'        => $this->session->token,
				'TournamentId' => $tournament_id,
			]);
			$this->data['Reeves'] = $_reeves['Detail'] ?? [];
		}

		// Load brackets
		$bracketsResult = $this->Tournament->get_brackets($tournament_id);
		$brackets       = $bracketsResult['Detail'] ?? [];
		$this->data['brackets'] = $brackets;

		// Spectator state: any bracket currently 'active'; a spectator is a non-staff
		// viewer of a live tournament (not manager, not bracket runner, has an active bracket).
		$hasActiveBracket = false;
		foreach ($brackets as $_b) {
			if (($_b['Status'] ?? '') === 'active') { $hasActiveBracket = true; break; }
		}
		$this->data['HasActiveBracket'] = $hasActiveBracket;
		$this->data['Spectator']        = (!$canManage && !$isBracketRunner && $hasActiveBracket);

		// Load all participants and matches for the tournament in one query each,
		// then partition by bracket_id in PHP (avoids 2N per-bracket round-trips).
		$allParts = $this->Tournament->get_participants(['TournamentId' => $tournament_id]);
		$allMtchs = $this->Tournament->get_matches(['TournamentId' => $tournament_id]);
		$partsByBracket = [];
		foreach (($allParts['Detail'] ?? []) as $_p) {
			$partsByBracket[(int)$_p['BracketId']][] = $_p;
		}
		$mtchsByBracket = [];
		foreach (($allMtchs['Detail'] ?? []) as $_m) {
			$mtchsByBracket[(int)$_m['BracketId']][] = $_m;
		}

		// Load per-bracket participants and matches
		$bracketData       = [];
		$totalParticipants = 0;
		$totalMatches      = 0;
		foreach ($brackets as $b) {
			$bid   = (int)$b['BracketId'];
			$pList = $partsByBracket[$bid] ?? [];
			$mList = $mtchsByBracket[$bid] ?? [];
			$bracketData[$bid] = [
				'Bracket'      => $b,
				'Participants' => $pList,
				'Matches'      => $mList,
			];
			$totalParticipants += count($pList);
			$totalMatches      += count($mList);
		}
		// Compute distinct participant count (by MundaneId/alias for individual brackets,
		// or by ParticipantId for team brackets — a team counts as one participant)
		$_seen = [];
		foreach ($bracketData as $_bd) {
			$_isTeam = (($_bd['Bracket']['Participants'] ?? 'individual') === 'team');
			foreach ($_bd['Participants'] as $_p) {
				$_key = $_isTeam
					? 'pid:' . (int)$_p['ParticipantId']
					: ((int)$_p['MundaneId'] > 0 ? 'mid:' . (int)$_p['MundaneId'] : 'alias:' . strtolower(trim($_p['Alias'])));
				$_seen[$_key] = true;
			}
		}
		$this->data['bracket_data']      = $bracketData;
		$this->data['TotalBrackets']     = count($brackets);
		$this->data['TotalParticipants'] = count($_seen);
		$this->data['TotalMatches']      = $totalMatches;

		// Load standings per bracket (only meaningful when matches exist)
		$standingsData = [];
		foreach ($brackets as $b) {
			$bid = (int)$b['BracketId'];
			if (!empty($bracketData[$bid]['Matches'])) {
				$sr = $this->Tournament->get_standings($bid);
				$standingsData[$bid] = $sr['Detail'] ?? [];
			}
		}
		$this->data['standings_data'] = $standingsData;

		// Breadcrumb / nav menu
		if (valid_id($tournament['KingdomId'])) {
			$this->data['menu']['kingdom'] = [
				'url'     => UIR . 'Kingdom/profile/' . $tournament['KingdomId'],
				'display' => $tournament['KingdomName'],
			];
		}
		if (valid_id($tournament['ParkId'])) {
			$this->data['menu']['park'] = [
				'url'     => UIR . 'Park/profile/' . $tournament['ParkId'],
				'display' => $tournament['ParkName'],
			];
		}
		$this->data['menu']['tournament'] = [
			'url'     => UIR . 'Tournament/profile/' . $tournament_id,
			'display' => $tournament['Name'],
		];
	}

}
?>