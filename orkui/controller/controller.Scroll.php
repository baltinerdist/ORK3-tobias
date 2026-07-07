<?php

class Controller_Scroll extends Controller
{
    public function __construct($call = null, $id = null)
    {
        parent::__construct($call, $id);

        $this->load_model('Player');
        $this->load_model('Kingdom');
        $this->load_model('Park');

        $this->data['menu']['scroll'] = array( 'url' => UIR.'Scroll/builder', 'display' => 'Scroll Generator' );
        $this->data['page_title'] = 'Scroll Generator';
    }

    public function index($id = null)
    {
        header('Location: ' . UIR . 'Scroll/builder');
        exit;
    }

    /**
     * Scroll Administration surface: manage templates for every tier the logged-in
     * user administers (Amtgard-wide / Kingdom / Park). Officer/admin gated.
     */
    public function admin($id = null)
    {
        if (!isset($this->session->user_id)) {
            header('Location: ' . UIR . 'Login');
            exit;
        }
        $this->template = '../revised-frontend/Scroll_admin.tpl';

        // Resolve the LOGGED-IN user's own park + kingdom (mirrors builder()).
        $org             = $this->resolveOrg((int)$this->session->user_id);
        $userParkId      = $org['parkId'];
        $userParkName    = $org['parkName'];
        $userKingdomId   = $org['kingdomId'];
        $userKingdomName = $org['kingdomName'];

        $mid = (int)Ork3::$Lib->authorization->IsAuthorized($this->session->token);
        $isAdmin          = Ork3::$Lib->authorization->HasAuthority($mid, AUTH_ADMIN, 0, AUTH_EDIT);
        $isKingdomOfficer = $userKingdomId > 0 && Ork3::$Lib->authorization->HasAuthority($mid, AUTH_KINGDOM, $userKingdomId, AUTH_EDIT);
        $isParkOfficer    = $userParkId > 0 && Ork3::$Lib->authorization->HasAuthority($mid, AUTH_PARK, $userParkId, AUTH_EDIT);

        if (!$isAdmin && !$isKingdomOfficer && !$isParkOfficer) {
            header('Location: ' . UIR . 'Scroll/builder');
            exit;
        }

        $this->data['sa_config'] = array(
            'uir'              => UIR,
            'token'            => $this->session->token ?? '',
            'userKingdomId'    => $userKingdomId,
            'userKingdomName'  => $userKingdomName,
            'userParkId'       => $userParkId,
            'userParkName'     => $userParkName,
            'isAdmin'          => $isAdmin ? 1 : 0,
            'isKingdomOfficer' => $isKingdomOfficer ? 1 : 0,
            'isParkOfficer'    => $isParkOfficer ? 1 : 0,
            'packBase'         => str_replace('/assets/', '/system/assets/scroll/packs/', HTTP_ASSETS),
            'libBase'          => HTTP_SCROLL_ARTWORK,
        );

        // Only include a section for a tier the user actually manages.
        $sections = array();
        if ($isAdmin) {
            $sections['global'] = Ork3::$Lib->scrolltemplate->listForScope('global', 0, 0)['Templates'] ?? array();
        }
        if ($isKingdomOfficer) {
            $sections['kingdom'] = Ork3::$Lib->scrolltemplate->listForScope('kingdom', $userKingdomId, 0)['Templates'] ?? array();
        }
        if ($isParkOfficer) {
            $sections['park'] = Ork3::$Lib->scrolltemplate->listForScope('park', 0, $userParkId)['Templates'] ?? array();
        }
        $this->data['sa_sections'] = $sections;

        // Preview modal: a plausible filled scroll using a random ladder award name.
        $awards = Ork3::$Lib->award->GetAwardList(array('IsLadder' => 'Ladder'))['Awards'] ?? array();
        if (empty($awards)) {
            $awards = Ork3::$Lib->award->GetAwardList(array())['Awards'] ?? array();
        }
        $awardName = 'Order of the Example';
        if (!empty($awards)) {
            $pick = $awards[array_rand($awards)];
            $pickName = trim($pick['AwardName'] ?? $pick['Name'] ?? '');
            $awardName = $pickName !== '' ? $pickName : $awardName;
        }
        $rank = mt_rand(1, 5);
        $tokens = array(
            'PlayerName' => 'Sir Example',
            'AwardName'  => $awardName,
            'Kingdom'    => $userKingdomName,
            'Park'       => $userParkName,
            'Date'       => date('F j, Y'),
            'GivenBy'    => 'Their Excellency',
            'Reason'     => 'For valorous service to the realm.',
            'RankNum'    => (string)$rank,
            'RankNumXth' => $this->rankOrdinal($rank),
            'RankWord'   => $this->rankWord($rank),
        );
        $kingdomHeraldry = $userKingdomId > 0
            ? (Ork3::$Lib->heraldry->GetHeraldryUrl(array('Type' => 'Kingdom', 'Id' => $userKingdomId))['Url'] ?? '')
            : '';
        $parkHeraldry = $userParkId > 0
            ? (Ork3::$Lib->heraldry->GetHeraldryUrl(array('Type' => 'Park', 'Id' => $userParkId))['Url'] ?? '')
            : '';
        $this->data['sa_preview'] = array(
            'tokens'   => $tokens,
            'heraldry' => array(
                'kingdom' => $kingdomHeraldry,
                'park'    => $parkHeraldry,
                'player'  => HTTP_PLAYER_HERALDRY . '000000.jpg',
            ),
        );

        // Clear stale PDO bindings after auth checks + lib reads.
        global $DB;
        $DB->Clear();
    }

    public function builder($id = null)
    {
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

        // Slot-based template renderer data (populated below when a player resolves).
        $this->data['templates']         = array();
        $this->data['token_map']         = array();
        $this->data['heraldry']          = array('kingdom' => '', 'park' => '', 'player' => '');
        $this->data['player_kingdom_id'] = 0;
        $this->data['current_award_id']  = 0;   // base ork_award.award_id being granted (for template tag matching)
        // Built-in art packs live under system/assets/scroll/packs/ (served directly from docroot).
        $this->data['pack_base'] = str_replace('/assets/', '/system/assets/scroll/packs/', HTTP_ASSETS);
        // Uploaded library artwork is served directly by file name from the artwork tree.
        $this->data['lib_base']  = HTTP_SCROLL_ARTWORK;

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
                    global $DB;
                    $DB->Clear();
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

                // Token map keys off the RECIPIENT's kingdom, but the template PICKER is
                // scoped to the logged-in GRANTER's own org (global + their kingdom + park).
                $this->data['player_kingdom_id'] = $kingdom_id;
                $granterOrg = $this->resolveOrg($uid);
                $this->data['templates'] = Ork3::$Lib->scrolltemplate
                    ->visibleTo($granterOrg['kingdomId'], $granterOrg['parkId'])['Templates'] ?? array();

                $award = $this->data['award'];
                $award_name = '';
                if (is_array($award)) {
                    $award_name = trim($award['CustomAwardName'] ?? '') !== ''
                        ? $award['CustomAwardName']
                        : (trim($award['KingdomAwardName'] ?? '') !== ''
                            ? $award['KingdomAwardName']
                            : ($award['Name'] ?? ''));
                }
                $award_date = (is_array($award) && !empty($award['Date']) && strtotime($award['Date']) !== false)
                    ? date('F j, Y', strtotime($award['Date']))
                    : date('F j, Y');
                $award_rank = (is_array($award) && isset($award['Rank'])) ? (int)$award['Rank'] : 0;
                $this->data['token_map'] = array(
                    'PlayerName' => $player['Persona'] ?? '',
                    'AwardName'  => $award_name,
                    'Kingdom'    => $this->data['kingdom_name'],
                    'Park'       => $this->data['park_name'],
                    'Date'       => $award_date,
                    'GivenBy'    => is_array($award) ? ($award['GivenBy'] ?? '') : '',
                    'Reason'     => is_array($award) ? ($award['Note'] ?? '') : '',
                    'RankNum'    => $award_rank > 0 ? (string)$award_rank : '',
                    'RankNumXth' => $award_rank > 0 ? $this->rankOrdinal($award_rank) : '',
                    'RankWord'   => $award_rank > 0 ? $this->rankWord($award_rank) : '',
                );
                $this->data['heraldry'] = array(
                    'kingdom' => $this->data['kingdom_heraldry_url'],
                    'park'    => $this->data['park_heraldry_url'],
                    'player'  => $this->data['player_heraldry_url'],
                );
                $this->data['current_award_id'] = is_array($award) ? (int)($award['AwardId'] ?? 0) : 0;

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

    public function design($id = null)
    {
        $this->template = '../revised-frontend/Scroll_design.tpl';

        $parts      = explode('/', $id ?? '');
        $kingdomId  = isset($parts[0]) ? (int)$parts[0] : 0;
        $templateId = isset($parts[1]) ? (int)$parts[1] : 0;

        // Kingdom-officer gate (mirrors the scroll AJAX siblings' session-token auth).
        // ORK admins may design for any kingdom and for shared starters (kingdom 0).
        $mid = (int)Ork3::$Lib->authorization->IsAuthorized($this->session->token);
        $isAdmin = ($mid > 0 && Ork3::$Lib->authorization->HasAuthority($mid, AUTH_ADMIN, 0, AUTH_EDIT));
        $this->data['authorized'] = $isAdmin
            || ($mid > 0 && $kingdomId > 0 && Ork3::$Lib->authorization->HasAuthority($mid, AUTH_KINGDOM, $kingdomId, AUTH_EDIT));
        $this->data['is_admin'] = $isAdmin;

        $this->data['kingdom_id'] = $kingdomId;
        // NOTE: 'template' is a RESERVED View variable (the include path); using it as a
        // data key is dropped by extract(EXTR_SKIP). Use 'edit_template' instead.
        $this->data['edit_template'] = $templateId ? (Ork3::$Lib->scrolltemplate->get($templateId)['Template'] ?? null) : null;
        $this->data['templates']  = Ork3::$Lib->scrolltemplate->listForKingdom($kingdomId)['Templates'] ?? array();

        // Built-in art-pack catalog + base URL live under system/assets/scroll/packs/ (matches builder()).
        $this->data['pack_catalog'] = json_decode(@file_get_contents(DIR_SYSTEM . 'assets/scroll/packs/catalog.json'), true) ?: array();
        $this->data['pack_base']    = str_replace('/assets/', '/system/assets/scroll/packs/', HTTP_ASSETS);

        // Ladder awards (base ork_award, kingdom-independent) for tagging a template.
        $this->data['ladder_awards'] = Ork3::$Lib->award->GetAwardList(array('IsLadder' => 'Ladder'))['Awards'] ?? array();

        // Preview the "Recipient's kingdom" role with this template's own kingdom arms.
        $kingdomHeraldry = $kingdomId > 0
            ? Ork3::$Lib->heraldry->GetHeraldryUrl(array('Type' => 'Kingdom', 'Id' => $kingdomId))['Url']
            : '';
        $this->data['heraldry']      = array('kingdom' => $kingdomHeraldry, 'park' => '', 'player' => '');
        $this->data['session_token'] = isset($this->session->token) ? $this->session->token : '';

        // Resolve the logged-in user's own park + kingdom for the scope selector.
        $org             = $this->resolveOrg((int)$this->session->user_id);
        $userParkId      = $org['parkId'];
        $userParkName    = $org['parkName'];
        $userKingdomId   = $org['kingdomId'];
        $userKingdomName = $org['kingdomName'];

        // COPY MODE: seed the designer from an existing template but flag a copy so the
        // JS drops the real id + prefixes the name; leave the normal edit path untouched.
        $this->data['is_copy'] = false;
        if (!empty($_GET['copy'])) {
            $copySrc = Ork3::$Lib->scrolltemplate->get((int)$_GET['copy'])['Template'] ?? null;
            if ($copySrc) {
                $this->data['edit_template'] = $copySrc;
                $this->data['is_copy'] = true;
            }
        }

        // Scope preselect: explicit ?scope= wins, else the edited template's own
        // visibility, else default to kingdom.
        $scopeParam = isset($_GET['scope']) ? (string)$_GET['scope'] : '';
        $editTpl    = $this->data['edit_template'] ?? null;
        $preselect  = in_array($scopeParam, array('global', 'kingdom', 'park'), true)
            ? $scopeParam
            : ((is_array($editTpl) && !empty($editTpl['visibility'])) ? $editTpl['visibility'] : 'kingdom');

        $this->data['sa_scope'] = array(
            'allowGlobal'     => $isAdmin ? 1 : 0,
            'allowKingdom'    => ($mid > 0 && $kingdomId > 0 && Ork3::$Lib->authorization->HasAuthority($mid, AUTH_KINGDOM, $kingdomId, AUTH_EDIT)) ? 1 : 0,
            'allowPark'       => ($userParkId > 0 && Ork3::$Lib->authorization->HasAuthority($mid, AUTH_PARK, $userParkId, AUTH_EDIT)) ? 1 : 0,
            'userParkId'      => $userParkId,
            'userParkName'    => $userParkName,
            'userKingdomId'   => $userKingdomId,
            'userKingdomName' => $userKingdomName,
            'preselect'       => $preselect,
        );

        // Clear stale PDO bindings after auth checks + lib reads.
        global $DB;
        $DB->Clear();
    }

    /**
     * Resolve a mundane's own park + kingdom from their player record.
     * Mirrors builder()'s player->park->kingdom derivation.
     */
    private function resolveOrg($mundaneId)
    {
        $out = array('parkId' => 0, 'parkName' => '', 'kingdomId' => 0, 'kingdomName' => '');
        $mundaneId = (int)$mundaneId;
        if ($mundaneId <= 0) {
            return $out;
        }
        $player = $this->Player->fetch_player($mundaneId);
        if (!$player) {
            return $out;
        }
        $parkId = (int)($player['ParkId'] ?? 0);
        if (valid_id($parkId)) {
            $out['parkId'] = $parkId;
            $parkInfo = $this->Park->get_park_info($parkId);
            if ($parkInfo && isset($parkInfo['ParkInfo'])) {
                $out['parkName']    = $parkInfo['ParkInfo']['ParkName'] ?? '';
                $out['kingdomId']   = (int)($parkInfo['KingdomInfo']['KingdomId'] ?? 0);
                $out['kingdomName'] = $parkInfo['KingdomInfo']['KingdomName'] ?? '';
            }
        }
        return $out;
    }

    // 3 -> "3rd" (11th/12th/13th handled)
    private function rankOrdinal($n)
    {
        $n = (int)$n;
        $mod100 = $n % 100;
        if ($mod100 >= 11 && $mod100 <= 13) {
            return $n . 'th';
        }
        switch ($n % 10) {
            case 1:
                return $n . 'st';
            case 2:
                return $n . 'nd';
            case 3:
                return $n . 'rd';
            default:
                return $n . 'th';
        }
    }

    // 3 -> "third"; ranks past twentieth fall back to the ordinal-number form
    private function rankWord($n)
    {
        $words = array(
            1 => 'first', 2 => 'second', 3 => 'third', 4 => 'fourth', 5 => 'fifth',
            6 => 'sixth', 7 => 'seventh', 8 => 'eighth', 9 => 'ninth', 10 => 'tenth',
            11 => 'eleventh', 12 => 'twelfth', 13 => 'thirteenth', 14 => 'fourteenth',
            15 => 'fifteenth', 16 => 'sixteenth', 17 => 'seventeenth', 18 => 'eighteenth',
            19 => 'nineteenth', 20 => 'twentieth',
        );
        $n = (int)$n;
        return isset($words[$n]) ? $words[$n] : $this->rankOrdinal($n);
    }
}
