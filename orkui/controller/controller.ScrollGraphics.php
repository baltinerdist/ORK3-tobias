<?php

class Controller_ScrollGraphics extends Controller
{
    public function __construct($call = null, $id = null)
    {
        parent::__construct($call, $id);
        // Login-gate the whole module (Reports pattern)
        if (!isset($this->session->user_id)) {
            header('Location: ' . UIR . 'Login');
            exit;
        }
        $this->load_model('Player');
        $this->data['page_title'] = 'Scroll Graphic Submissions';
    }

    private function inject_config()
    {
        $uid = (int)$this->session->user_id;
        $is_admin = Ork3::$Lib->authorization->HasAuthority($uid, AUTH_ADMIN, 0, AUTH_EDIT);
        $kid = isset($this->session->kingdom_id) ? (int)$this->session->kingdom_id : 0;
        $kname = isset($this->session->kingdom_name) ? $this->session->kingdom_name : '';
        $pid = (int)($this->session->park_id ?? 0);
        $pname = $this->session->park_name ?? '';
        // session->park_id isn't reliably populated on this module's pages; resolve the user's
        // own park (and its kingdom, if missing) from their player record.
        if ($pid <= 0) {
            $player = $this->Player->fetch_player($uid);
            $ppark = $player ? (int)($player['ParkId'] ?? 0) : 0;
            if (valid_id($ppark)) {
                $pid = $ppark;
                $this->load_model('Park');
                $parkInfo = $this->Park->get_park_info($ppark);
                if ($parkInfo && isset($parkInfo['ParkInfo'])) {
                    $pname = $parkInfo['ParkInfo']['ParkName'] ?? $pname;
                    if ($kid <= 0) {
                        $kid = (int)($parkInfo['KingdomInfo']['KingdomId'] ?? 0);
                    }
                    if ($kname === '') {
                        $kname = $parkInfo['KingdomInfo']['KingdomName'] ?? '';
                    }
                }
            }
        }
        $is_kingdom_officer = $kid > 0 && Ork3::$Lib->authorization->HasAuthority($uid, AUTH_KINGDOM, $kid, AUTH_EDIT);
        $is_park_officer = $pid > 0 && Ork3::$Lib->authorization->HasAuthority($uid, AUTH_PARK, $pid, AUTH_EDIT);
        global $DB;
        $DB->Clear();
        $this->data['sg_config'] = array(
            'uir'             => UIR,
            'token'           => isset($this->session->token) ? $this->session->token : '',
            'kingdomId'       => $kid,
            'kingdomName'     => $kname,
            'parkId'          => $pid,
            'parkName'        => $pname,
            'isOrkAdmin'      => $is_admin ? 1 : 0,
            'isKingdomOfficer' => $is_kingdom_officer ? 1 : 0,
            'isParkOfficer'   => $is_park_officer ? 1 : 0,
            'canModerate'     => ($is_admin || $is_kingdom_officer) ? 1 : 0,
            'canManage'       => ($is_admin || $is_kingdom_officer || $is_park_officer) ? 1 : 0,
        );
    }

    public function index($id = null)
    {
        $this->inject_config();
        $this->template = '../revised-frontend/ScrollGraphics_index.tpl';
    }
    public function upload($id = null)
    {
        $this->inject_config();
        $this->template = '../revised-frontend/ScrollGraphics_upload.tpl';
    }
    public function mine($id = null)
    {
        $this->inject_config();
        $this->template = '../revised-frontend/ScrollGraphics_mine.tpl';
    }
    public function moderate($id = null)
    {
        $this->inject_config();
        if (empty($this->data['sg_config']['canModerate'])) {
            header('Location: ' . UIR . 'ScrollGraphics');
            exit;
        }
        $this->template = '../revised-frontend/ScrollGraphics_moderate.tpl';
    }

    public function manage($id = null)
    {
        $this->inject_config();
        $sg = $this->data['sg_config'];
        if (empty($sg['canManage'])) {
            header('Location: ' . UIR . 'ScrollGraphics');
            exit;
        }

        // One section per tier the user holds EDIT authority over.
        // My Park -> My Kingdom -> Amtgard-Wide (order applied in the template).
        $sections = array();
        if (!empty($sg['isParkOfficer'])) {
            $r = Ork3::$Lib->scrollartwork->list_for_scope('park', 0, (int)$sg['parkId']);
            $sections['park'] = $r['Artwork'] ?? array();
        }
        if (!empty($sg['isKingdomOfficer'])) {
            $r = Ork3::$Lib->scrollartwork->list_for_scope('kingdom', (int)$sg['kingdomId'], 0);
            $sections['kingdom'] = $r['Artwork'] ?? array();
        }
        if (!empty($sg['isOrkAdmin'])) {
            $r = Ork3::$Lib->scrollartwork->list_for_scope('global', 0, 0);
            $sections['global'] = $r['Artwork'] ?? array();
        }

        $cats = Ork3::$Lib->scrollartwork->list_categories(true);
        $this->data['sg_manage'] = array(
            'sections'   => $sections,
            'categories' => $cats['Categories'] ?? array(),
            'layouts'    => array('full_border', 'border_side', 'center_image', 'background'),
        );

        global $DB;
        $DB->Clear();
        $this->template = '../revised-frontend/ScrollGraphics_manage.tpl';
    }
}
