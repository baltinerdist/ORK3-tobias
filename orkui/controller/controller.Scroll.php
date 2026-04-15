<?php

class Controller_Scroll extends Controller {

	public function __construct($call=null, $id=null) {
		parent::__construct($call, $id);

		$this->load_model('Player');
		$this->load_model('Kingdom');
		$this->load_model('Park');

		$this->data['menu']['scroll'] = array( 'url' => UIR.'Scroll/builder', 'display' => 'Scroll Generator' );
		$this->data['page_title'] = 'Scroll Generator';
	}

	public function index($id = null) {
		header('Location: ' . UIR . 'Scroll/builder');
		exit;
	}

	public function builder($id = null) {
		$this->template = '../revised-frontend/Scroll_builder.tpl';

		$params = explode('/', $id ?? '');
		$mundane_id = isset($params[0]) && (int)$params[0] > 0 ? (int)$params[0] : 0;
		$awards_id  = isset($params[1]) && (int)$params[1] > 0 ? (int)$params[1] : 0;

		$uid = isset($this->session->user_id) ? (int)$this->session->user_id : 0;

		// Defaults
		$this->data['award']                = null;
		$this->data['player']               = null;
		$this->data['kingdom_name']         = '';
		$this->data['park_name']            = '';
		$this->data['kingdom_heraldry_url'] = '';
		$this->data['park_heraldry_url']    = '';
		$this->data['player_heraldry_url']  = '';
		$this->data['session_user_id']      = $uid;
		$this->data['can_generate']         = false;
		$this->data['kingdom_id']           = 0;
		$this->data['park_id']              = 0;
		$this->data['preload_officers']     = array();
		$this->data['is_ork_admin']         = false;
		$this->data['session_token']        = isset($this->session->token) ? $this->session->token : '';

		if ($mundane_id > 0) {
			// Fetch the player record
			$player = $this->Player->fetch_player($mundane_id);
			if ($player) {
				$this->data['player'] = $player;

				// Player heraldry
				$this->data['player_heraldry_url'] = ($player['HasHeraldry'] > 0)
					? $player['Heraldry']
					: HTTP_PLAYER_HERALDRY . '000000.jpg';

				// Park / Kingdom info from the player's park
				$park_id    = (int)($player['ParkId'] ?? 0);
				$kingdom_id = 0;

				if (valid_id($park_id)) {
					$park_info = $this->Park->get_park_info($park_id);
					if ($park_info && isset($park_info['ParkInfo'])) {
						$this->data['park_name']    = $park_info['ParkInfo']['ParkName'] ?? '';
						$kingdom_id                 = (int)($park_info['KingdomInfo']['KingdomId'] ?? 0);
						$this->data['kingdom_name'] = $park_info['KingdomInfo']['KingdomName'] ?? '';
					}

					// Park heraldry
					$park_details = $this->Park->get_park_details($park_id);
					if ($park_details && isset($park_details['Heraldry']['Url'])) {
						$this->data['park_heraldry_url'] = $park_details['Heraldry']['Url'];
					}
				}

				// Kingdom heraldry
				if (valid_id($kingdom_id)) {
					$kingdom_info = $this->Kingdom->get_kingdom_shortinfo($kingdom_id);
					if ($kingdom_info && isset($kingdom_info['HeraldryUrl']['Url'])) {
						$this->data['kingdom_heraldry_url'] = $kingdom_info['HeraldryUrl']['Url'];
					}
				}

				$this->data['kingdom_id'] = $kingdom_id;
				$this->data['park_id']    = $park_id;

				// Preload Kingdom and Park Monarch/Regent for GivenBy officer chips
				$preloadOfficers = array();
				$token = isset($this->session->token) ? $this->session->token : '';
				if (valid_id($kingdom_id) && $token) {
					$kingdomOfficers = $this->Kingdom->get_officers($kingdom_id, $token);
					if (is_array($kingdomOfficers)) {
						foreach ($kingdomOfficers as $officer) {
							if (in_array($officer['OfficerRole'], array('Monarch', 'Regent')) && $officer['MundaneId'] > 0) {
								$preloadOfficers[] = array('MundaneId' => $officer['MundaneId'], 'Persona' => $officer['Persona'], 'Role' => 'Kingdom ' . $officer['OfficerRole']);
							}
						}
					}
				}
				if (valid_id($park_id) && $token) {
					$parkOfficers = $this->Park->get_officers($park_id, $token);
					if (is_array($parkOfficers)) {
						foreach ($parkOfficers as $officer) {
							if (in_array($officer['OfficerRole'], array('Monarch', 'Regent')) && $officer['MundaneId'] > 0) {
								$preloadOfficers[] = array('MundaneId' => $officer['MundaneId'], 'Persona' => $officer['Persona'], 'Role' => 'Park ' . $officer['OfficerRole']);
							}
						}
					}
				}
				$this->data['preload_officers'] = $preloadOfficers;

				// Auth check: own awards, park officer, or kingdom officer
				if ($uid > 0) {
					$isOwnAward    = ($uid === $mundane_id);
					$isParkOfficer = valid_id($park_id)
						&& Ork3::$Lib->authorization->HasAuthority($uid, AUTH_PARK, $park_id, AUTH_EDIT);
					$isKingdomOfficer = valid_id($kingdom_id)
						&& Ork3::$Lib->authorization->HasAuthority($uid, AUTH_KINGDOM, $kingdom_id, AUTH_EDIT);

					$this->data['can_generate'] = $isOwnAward || $isParkOfficer || $isKingdomOfficer;

					// Check ORK admin for artwork moderation
					$this->data['is_ork_admin'] = Ork3::$Lib->authorization->HasAuthority($uid, AUTH_ADMIN, 0, AUTH_EDIT);

					// Clear stale PDO bindings after auth checks
					global $DB; $DB->Clear();
				}

				// Find the specific award by AwardsId
				if ($awards_id > 0) {
					$awards_result = $this->Player->fetch_player_details($mundane_id);
					if (is_array($awards_result) && isset($awards_result['Awards'])) {
						foreach ($awards_result['Awards'] as $aw) {
							if ((int)$aw['AwardsId'] === $awards_id) {
								$this->data['award'] = $aw;
								break;
							}
						}
					}
				}

				// Breadcrumbs
				if (valid_id($kingdom_id)) {
					$this->data['menu']['kingdom'] = array(
						'url'     => UIR . 'Kingdom/profile/' . $kingdom_id,
						'display' => $this->data['kingdom_name']
					);
				}
				if (valid_id($park_id)) {
					$this->data['menu']['park'] = array(
						'url'     => UIR . 'Park/profile/' . $park_id,
						'display' => $this->data['park_name']
					);
				}
				$this->data['menu']['player'] = array(
					'url'     => UIR . 'Player/profile/' . $mundane_id,
					'display' => $player['Persona'] ?? 'Player'
				);
				$this->data['menu']['scroll'] = array(
					'url'     => UIR . 'Scroll/builder/' . $mundane_id . '/' . $awards_id,
					'display' => 'Scroll Generator'
				);
				$this->data['page_title'] = 'Scroll Generator — ' . ($player['Persona'] ?? 'Player');
			}
		}
	}

}
