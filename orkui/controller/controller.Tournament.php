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
				if ($r['Status'] == 0) {
					$this->request->clear('Tournament_worksheet');
				} else if($r['Status'] == 5) {
					header( 'Location: '.UIR.'Login/login/Tournament/worksheet' );
				} else {
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
				switch ($post) {
					case 'create':
						$r = $this->Tournament->create_tournament(array(
								'Token' => $this->session->token,
								'KingdomId' => $this->request->Tournament_create->MundaneId,
								'ParkId' => $this->request->Tournament_create->ParkId,
								'EventCalendarDetailId' => $this->request->Tournament_create->EventCalendarDetailId,
								'Name' => $this->request->Tournament_create->Name,
								'Description' => $this->request->Tournament_create->Description,
								'Url' => $this->request->Tournament_create->Url,
								'When' => $this->request->Tournament_create->When,
							));
						break;
				}
				if ($r['Status'] == 0) {
					$this->request->clear('Tournament_create');
//					$this->data['Message'] = "Player is ".($this->request->Tournament_create->Ban?"banned.":"free.");
				} else if($r['Status'] == 5) {
					header( 'Location: '.UIR.'Login/login/Tournament/create' );
				} else {
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
			global $DB;
			$_ecd = (int)$tournament['EventCalendarDetailId'];
			$DB->Clear();
			$_elr = $DB->query(
				'SELECT k.abbreviation AS kabbr, p.abbreviation AS pabbr, d.event_start '
				. 'FROM ork_event_calendardetail d '
				. 'LEFT JOIN ork_event e ON e.event_id = d.event_id '
				. 'LEFT JOIN ork_kingdom k ON k.kingdom_id = e.kingdom_id '
				. 'LEFT JOIN ork_park p ON p.park_id = e.park_id '
				. "WHERE d.event_calendardetail_id = $_ecd"
			);
			if ($_elr && $_elr->next()) {
				$_abbr = '';
				if ($_elr->kabbr) $_abbr = $_elr->kabbr;
				if ($_elr->pabbr) $_abbr .= ($_abbr ? ':' : '') . $_elr->pabbr;
				$_ds = ($_elr->event_start && substr($_elr->event_start, 0, 10) !== '0000-00-00')
					? date('m/d/Y', strtotime($_elr->event_start)) : '';
				$_lbl = $tournament['EventName'] ?? '';
				if ($_abbr) $_lbl .= ' ' . $_abbr;
				if ($_ds)   $_lbl .= ' - ' . $_ds;
				$this->data['tournament_event_label'] = $_lbl;
			} else {
				$this->data['tournament_event_label'] = $tournament['EventName'] ?? '';
			}
		}

		// Load standings points config (direct query, bypasses TournamentReport cache)
		global $DB;
		$DB->Clear();
		$_spRow = $DB->query('SELECT standings_points FROM ork_tournament WHERE tournament_id = ' . $tournament_id);
		$_spDefault = [5,4,3,2,1,0,0,0];
		if ($_spRow && $_spRow->next() && !empty($_spRow->standings_points)) {
			$_spParsed = json_decode($_spRow->standings_points, true);
			$this->data['standings_points'] = (is_array($_spParsed) && count($_spParsed) === 8) ? $_spParsed : $_spDefault;
		} else {
			$this->data['standings_points'] = $_spDefault;
		}

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
		$this->data['CanManageTournament'] = $canManage;
		$this->data['LoggedIn']            = isset($this->session->user_id);

		// Load brackets
		$bracketsResult = $this->Tournament->get_brackets($tournament_id);
		$brackets       = $bracketsResult['Detail'] ?? [];
		$this->data['brackets'] = $brackets;

		// Load per-bracket participants and matches
		$bracketData       = [];
		$totalParticipants = 0;
		$totalMatches      = 0;
		foreach ($brackets as $b) {
			$bid   = (int)$b['BracketId'];
			$parts = $this->Tournament->get_participants(['TournamentId' => $tournament_id, 'BracketId' => $bid]);
			$mtchs = $this->Tournament->get_matches(['TournamentId' => $tournament_id, 'BracketId' => $bid]);
			$pList = $parts['Detail'] ?? [];
			$mList = $mtchs['Detail'] ?? [];
			$bracketData[$bid] = [
				'Bracket'      => $b,
				'Participants' => $pList,
				'Matches'      => $mList,
			];
			$totalParticipants += count($pList);
			$totalMatches      += count($mList);
		}
		// Compute distinct participant count (by MundaneId, or alias for unlinked)
		$_seen = [];
		foreach ($bracketData as $_bd) {
			foreach ($_bd['Participants'] as $_p) {
				$_key = (int)$_p['MundaneId'] > 0 ? 'mid:' . (int)$_p['MundaneId'] : 'alias:' . strtolower(trim($_p['Alias']));
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