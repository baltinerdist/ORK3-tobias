<?php
class Controller_ScrollGraphics extends Controller {
	public function __construct($call = null, $id = null) {
		parent::__construct($call, $id);
		// Login-gate the whole module (Reports pattern)
		if (!isset($this->session->user_id)) {
			header('Location: ' . UIR . 'Login');
			exit;
		}
		$this->load_model('Player');
		$this->data['page_title'] = 'Scroll Graphic Submissions';
	}

	private function inject_config() {
		$uid = (int)$this->session->user_id;
		$is_admin = Ork3::$Lib->authorization->HasAuthority($uid, AUTH_ADMIN, 0, AUTH_EDIT);
		$kid = isset($this->session->kingdom_id) ? (int)$this->session->kingdom_id : 0;
		$is_kingdom_officer = $kid > 0 && Ork3::$Lib->authorization->HasAuthority($uid, AUTH_KINGDOM, $kid, AUTH_EDIT);
		global $DB; $DB->Clear();
		$this->data['sg_config'] = array(
			'uir'             => UIR,
			'token'           => isset($this->session->token) ? $this->session->token : '',
			'kingdomId'       => $kid,
			'kingdomName'     => isset($this->session->kingdom_name) ? $this->session->kingdom_name : '',
			'isOrkAdmin'      => $is_admin ? 1 : 0,
			'isKingdomOfficer'=> $is_kingdom_officer ? 1 : 0,
			'canModerate'     => ($is_admin || $is_kingdom_officer) ? 1 : 0,
		);
	}

	public function index($id = null)    { $this->inject_config(); $this->template = '../revised-frontend/ScrollGraphics_index.tpl'; }
	public function upload($id = null)   { $this->inject_config(); $this->template = '../revised-frontend/ScrollGraphics_upload.tpl'; }
	public function mine($id = null)     { $this->inject_config(); $this->template = '../revised-frontend/ScrollGraphics_mine.tpl'; }
	public function moderate($id = null) {
		$this->inject_config();
		if (empty($this->data['sg_config']['canModerate'])) { header('Location: ' . UIR . 'ScrollGraphics'); exit; }
		$this->template = '../revised-frontend/ScrollGraphics_moderate.tpl';
	}
}
