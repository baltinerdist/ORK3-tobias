<?php

class Controller_ScrollArtworkAjax extends Controller {

	/**
	 * The ScrollArtwork backend instance.
	 * Loaded automatically by startup.php as Ork3::$Lib->scrollartwork.
	 */
	private $sa;

	public function __construct($call = null, $id = null) {
		parent::__construct($call, $id);
		$this->sa = Ork3::$Lib->scrollartwork;
	}

	// ================================================================
	//  Helpers
	// ================================================================

	/**
	 * Send a JSON response and exit.
	 */
	private function json_response($data) {
		header('Content-Type: application/json');
		echo json_encode($data);
		exit;
	}

	/**
	 * Require a logged-in user. Returns user_id or exits with JSON error.
	 */
	private function require_login() {
		if (!isset($this->session->user_id)) {
			$this->json_response(array('Status' => 5, 'Message' => 'Not logged in.'));
		}
		return (int)$this->session->user_id;
	}

	/**
	 * Require admin authority (AUTH_ADMIN + AUTH_EDIT).
	 * Returns mundane_id or exits with JSON error.
	 */
	private function require_admin() {
		$user_id = $this->require_login();

		$mundane_id = Ork3::$Lib->authorization->IsAuthorized($this->session->token);
		if ($mundane_id <= 0) {
			$this->json_response(array('Status' => 5, 'Message' => 'Authorization failed.'));
		}

		if (!Ork3::$Lib->authorization->HasAuthority($mundane_id, AUTH_ADMIN, 0, AUTH_EDIT)) {
			$this->json_response(array('Status' => 5, 'Message' => 'Admin privileges required.'));
		}

		return $mundane_id;
	}

	/**
	 * Kingdoms the given user may moderate (their session kingdom if they
	 * hold AUTH_KINGDOM edit authority there). Returns an array of ids.
	 */
	private function moderatable_kingdom_ids($mundane_id) {
		$ids = array();
		$kid = isset($this->session->kingdom_id) ? (int)$this->session->kingdom_id : 0;
		if ($kid > 0 && Ork3::$Lib->authorization->HasAuthority($mundane_id, AUTH_KINGDOM, $kid, AUTH_EDIT)) {
			$ids[] = $kid;
		}
		global $DB;
		$DB->Clear();
		return $ids;
	}

	// ================================================================
	//  POST /ScrollArtworkAjax/upload
	// ================================================================

	/**
	 * Upload new scroll artwork.
	 *
	 * POST params: image (base64), image_mime, name, description, tags,
	 *              layout_location, license_signer_name
	 *
	 * Returns JSON: {Status, ArtworkId, Message}
	 */
	public function upload($id = null) {
		$this->require_login();

		$request = array(
			'Token'             => $this->session->token,
			'Image'             => $_POST['image'] ?? '',
			'ImageMimeType'     => trim($_POST['image_mime'] ?? ''),
			'Name'              => trim($_POST['name'] ?? ''),
			'Description'       => trim($_POST['description'] ?? ''),
			'Tags'              => trim($_POST['tags'] ?? ''),
			'LayoutLocation'    => trim($_POST['layout_location'] ?? ''),
			'LicenseSignerName' => trim($_POST['license_signer_name'] ?? ''),
			'Visibility'        => trim($_POST['visibility'] ?? 'global'),
			'OwnerKingdomId'    => (int)($_POST['owner_kingdom_id'] ?? 0),
			'CategoryId'        => (int)($_POST['category_id'] ?? 0),
		);

		// Default OwnerKingdomId to the submitter's kingdom for provenance.
		if ($request['OwnerKingdomId'] <= 0 && isset($this->session->kingdom_id)) {
			$request['OwnerKingdomId'] = (int)$this->session->kingdom_id;
		}

		$result = $this->sa->upload($request);

		$response = array(
			'Status' => isset($result['Status']['Status']) ? $result['Status']['Status'] : (isset($result['Status']) ? $result['Status'] : 1),
			'Message' => '',
		);

		// Check for success (Status array with Status=0 means success in ORK3)
		if (is_array($result['Status']) && isset($result['Status']['Status']) && $result['Status']['Status'] == 0) {
			$response['Status'] = 0;
			$response['ArtworkId'] = $result['ArtworkId'] ?? 0;
			$response['Message'] = 'Artwork uploaded successfully. It will be visible after admin approval.';
		} else {
			// Extract error detail from the Status structure
			$response['Message'] = '';
			if (is_array($result['Status'])) {
				$response['Status'] = $result['Status']['Status'] ?? 1;
				$response['Message'] = $result['Status']['Detail'] ?? $result['Status']['Error'] ?? 'Upload failed.';
			}
		}

		$this->json_response($response);
	}

	// ================================================================
	//  GET /ScrollArtworkAjax/categories
	// ================================================================

	/**
	 * List active artwork categories for dropdowns/filters.
	 * Login required.
	 *
	 * Returns JSON: {Categories: [...], Status}
	 */
	public function categories($id = null) {
		$this->require_login();
		$result = $this->sa->list_categories(true);
		$this->json_response(array('Categories' => $result['Categories'] ?? array(), 'Status' => 0));
	}

	// ================================================================
	//  GET /ScrollArtworkAjax/browse
	// ================================================================

	/**
	 * Browse approved artwork, optionally filtered by layout location.
	 *
	 * GET params: layout_location (optional), page (default 1), per_page (default 12)
	 *
	 * Returns JSON: {Artwork: [...], Total, Page, PerPage, Status}
	 */
	public function browse($id = null) {
		$this->require_login();

		$layout_location = trim($_GET['layout_location'] ?? '');
		$page = max(1, (int)($_GET['page'] ?? 1));
		$per_page = max(1, min(100, (int)($_GET['per_page'] ?? 12)));

		$opts = array(
			'ViewerKingdomId' => isset($this->session->kingdom_id) ? (int)$this->session->kingdom_id : 0,
			'Tier'            => in_array($_GET['tier'] ?? 'all', array('all', 'global', 'kingdom')) ? $_GET['tier'] : 'all',
			'CategoryId'      => (int)($_GET['category_id'] ?? 0),
		);

		$result = $this->sa->browse($layout_location, $page, $per_page, $opts);

		$this->json_response(array(
			'Artwork' => $result['Artwork'] ?? array(),
			'Total'   => $result['Total'] ?? 0,
			'Page'    => $result['Page'] ?? $page,
			'PerPage' => $result['PerPage'] ?? $per_page,
			'Status'  => 0,
		));
	}

	// ================================================================
	//  GET /ScrollArtworkAjax/search
	// ================================================================

	/**
	 * Search approved artwork by name/tags.
	 *
	 * GET params: query, layout_location (optional), page (default 1), per_page (default 12)
	 *
	 * Returns JSON: {Artwork: [...], Total, Page, PerPage, Query, Status}
	 */
	public function search($id = null) {
		$this->require_login();

		$query = trim($_GET['query'] ?? '');
		$layout_location = trim($_GET['layout_location'] ?? '');
		$page = max(1, (int)($_GET['page'] ?? 1));
		$per_page = max(1, min(100, (int)($_GET['per_page'] ?? 12)));

		$opts = array(
			'ViewerKingdomId' => isset($this->session->kingdom_id) ? (int)$this->session->kingdom_id : 0,
			'Tier'            => in_array($_GET['tier'] ?? 'all', array('all', 'global', 'kingdom')) ? $_GET['tier'] : 'all',
			'CategoryId'      => (int)($_GET['category_id'] ?? 0),
		);

		$result = $this->sa->search($query, $layout_location, $page, $per_page, $opts);

		$this->json_response(array(
			'Artwork' => $result['Artwork'] ?? array(),
			'Total'   => $result['Total'] ?? 0,
			'Page'    => $result['Page'] ?? $page,
			'PerPage' => $result['PerPage'] ?? $per_page,
			'Query'   => $result['Query'] ?? $query,
			'Status'  => 0,
		));
	}

	// ================================================================
	//  GET /ScrollArtworkAjax/pending
	// ================================================================

	/**
	 * Get pending artwork for review. Tier-aware: ORK admins get the global
	 * queue (default), kingdom officers get their kingdom's queue. The scope
	 * may be forced via the `scope` GET param ('global'|'kingdom'); a
	 * non-admin requesting the global queue gets Status:5.
	 *
	 * GET params: scope (optional), page (default 1), per_page (default 20)
	 *
	 * Returns JSON: {Artwork: [...], Total, Page, PerPage, Status}
	 */
	public function pending($id = null) {
		$mundane_id = Ork3::$Lib->authorization->IsAuthorized($this->session->token ?? '');
		if ($mundane_id <= 0) {
			$this->json_response(array('Status' => 5, 'Message' => 'Not authorized.'));
		}
		$is_admin = Ork3::$Lib->authorization->HasAuthority($mundane_id, AUTH_ADMIN, 0, AUTH_EDIT);
		global $DB;
		$DB->Clear();

		$scope = ($_GET['scope'] ?? ($is_admin ? 'global' : 'kingdom'));
		$page = max(1, (int)($_GET['page'] ?? 1));
		$per_page = max(1, min(100, (int)($_GET['per_page'] ?? 20)));

		if ($scope === 'global') {
			if (!$is_admin) {
				$this->json_response(array('Status' => 5, 'Message' => 'Admin privileges required.'));
			}
			$result = $this->sa->get_pending($page, $per_page, array('Scope' => 'global'));
		} else {
			$kingdom_ids = $this->moderatable_kingdom_ids($mundane_id);
			if (count($kingdom_ids) === 0) {
				$this->json_response(array('Status' => 5, 'Message' => 'No kingdom moderation authority.'));
			}
			$result = $this->sa->get_pending($page, $per_page, array('Scope' => 'kingdom', 'KingdomIds' => $kingdom_ids));
		}

		$this->json_response(array(
			'Artwork' => $result['Artwork'] ?? array(),
			'Total'   => $result['Total'] ?? 0,
			'Page'    => $result['Page'] ?? $page,
			'PerPage' => $result['PerPage'] ?? $per_page,
			'Status'  => 0,
		));
	}

	// ================================================================
	//  POST /ScrollArtworkAjax/approve
	// ================================================================

	/**
	 * Approve a pending artwork. Tier-aware authorization is handled by the
	 * lib (ORK admin for global rows, kingdom officer for kingdom rows).
	 *
	 * POST params: artwork_id
	 *
	 * Returns JSON: {Status, Message}
	 */
	public function approve($id = null) {
		$this->require_login();

		$artwork_id = (int)($_POST['artwork_id'] ?? 0);
		if ($artwork_id <= 0) {
			$this->json_response(array('Status' => 1, 'Message' => 'Invalid artwork ID.'));
		}

		$request = array(
			'Token'     => $this->session->token,
			'ArtworkId' => $artwork_id,
		);

		$result = $this->sa->approve($request);

		if (is_array($result['Status']) && isset($result['Status']['Status']) && $result['Status']['Status'] == 0) {
			$this->json_response(array('Status' => 0, 'Message' => 'Artwork approved.'));
		} else {
			$detail = '';
			if (is_array($result['Status'])) {
				$detail = $result['Status']['Detail'] ?? $result['Status']['Error'] ?? 'Approval failed.';
			}
			$this->json_response(array('Status' => 1, 'Message' => $detail));
		}
	}

	// ================================================================
	//  POST /ScrollArtworkAjax/reject
	// ================================================================

	/**
	 * Reject a pending artwork with a reason. Tier-aware authorization is
	 * handled by the lib (ORK admin for global rows, kingdom officer for
	 * kingdom rows).
	 *
	 * POST params: artwork_id, reason
	 *
	 * Returns JSON: {Status, Message}
	 */
	public function reject($id = null) {
		$this->require_login();

		$artwork_id = (int)($_POST['artwork_id'] ?? 0);
		$reason = trim($_POST['reason'] ?? '');

		if ($artwork_id <= 0) {
			$this->json_response(array('Status' => 1, 'Message' => 'Invalid artwork ID.'));
		}
		if (strlen($reason) === 0) {
			$this->json_response(array('Status' => 1, 'Message' => 'Rejection reason is required.'));
		}

		$request = array(
			'Token'     => $this->session->token,
			'ArtworkId' => $artwork_id,
			'Reason'    => $reason,
		);

		$result = $this->sa->reject($request);

		if (is_array($result['Status']) && isset($result['Status']['Status']) && $result['Status']['Status'] == 0) {
			$this->json_response(array('Status' => 0, 'Message' => 'Artwork rejected.'));
		} else {
			$detail = '';
			if (is_array($result['Status'])) {
				$detail = $result['Status']['Detail'] ?? $result['Status']['Error'] ?? 'Rejection failed.';
			}
			$this->json_response(array('Status' => 1, 'Message' => $detail));
		}
	}

	// ================================================================
	//  GET /ScrollArtworkAjax/my_uploads
	// ================================================================

	/**
	 * Get artwork uploaded by the logged-in user.
	 *
	 * GET params: page (default 1), per_page (default 20)
	 *
	 * Returns JSON: {Artwork: [...], Total, Page, PerPage, Status}
	 */
	public function my_uploads($id = null) {
		$user_id = $this->require_login();

		$page = max(1, (int)($_GET['page'] ?? 1));
		$per_page = max(1, min(100, (int)($_GET['per_page'] ?? 20)));

		$mundane_id = Ork3::$Lib->authorization->IsAuthorized($this->session->token);
		if ($mundane_id <= 0) {
			$this->json_response(array('Status' => 5, 'Message' => 'Authorization failed.'));
		}

		$result = $this->sa->get_user_uploads($mundane_id, $page, $per_page);

		$this->json_response(array(
			'Artwork' => $result['Artwork'] ?? array(),
			'Total'   => $result['Total'] ?? 0,
			'Page'    => $result['Page'] ?? $page,
			'PerPage' => $result['PerPage'] ?? $per_page,
			'Status'  => 0,
		));
	}

	// ================================================================
	//  POST /ScrollArtworkAjax/delete
	// ================================================================

	/**
	 * Delete an artwork. Allowed by uploader or admin.
	 *
	 * POST params: artwork_id
	 *
	 * Returns JSON: {Status, Message}
	 */
	public function delete($id = null) {
		$this->require_login();

		$artwork_id = (int)($_POST['artwork_id'] ?? 0);
		if ($artwork_id <= 0) {
			$this->json_response(array('Status' => 1, 'Message' => 'Invalid artwork ID.'));
		}

		$request = array(
			'Token'     => $this->session->token,
			'ArtworkId' => $artwork_id,
		);

		$result = $this->sa->delete($request);

		if (is_array($result['Status']) && isset($result['Status']['Status']) && $result['Status']['Status'] == 0) {
			$this->json_response(array('Status' => 0, 'Message' => 'Artwork deleted.'));
		} else {
			$detail = '';
			if (is_array($result['Status'])) {
				$detail = $result['Status']['Detail'] ?? $result['Status']['Error'] ?? 'Delete failed.';
			}
			$this->json_response(array('Status' => 1, 'Message' => $detail));
		}
	}

	// ================================================================
	//  POST /ScrollArtworkAjax/save_category
	// ================================================================

	/**
	 * Create or update a thematic artwork category.
	 * Admin only (AUTH_ADMIN + AUTH_EDIT).
	 * Retiring a category = save with active=0 (no hard delete).
	 *
	 * POST params: category_id (0 = create), label, sort_order, active
	 *
	 * Returns JSON: {Status, CategoryId, Message}
	 */
	public function save_category($id = null) {
		$this->require_admin();

		$request = array(
			'Token'      => $this->session->token,
			'CategoryId' => (int)($_POST['category_id'] ?? 0),
			'Label'      => trim($_POST['label'] ?? ''),
			'SortOrder'  => (int)($_POST['sort_order'] ?? 0),
			'Active'     => !empty($_POST['active']) ? 1 : 0,
		);

		$result = $this->sa->save_category($request);

		if (is_array($result['Status']) && isset($result['Status']['Status']) && $result['Status']['Status'] == 0) {
			$this->json_response(array('Status' => 0, 'CategoryId' => $result['CategoryId'] ?? 0, 'Message' => 'Category saved.'));
		}

		$detail = is_array($result['Status']) ? ($result['Status']['Detail'] ?? $result['Status']['Error'] ?? 'Save failed.') : 'Save failed.';
		$this->json_response(array('Status' => 1, 'Message' => $detail));
	}

	// ================================================================
	//  GET /ScrollArtworkAjax/template_guide
	// ================================================================

	/**
	 * Download the template guide PNG showing all artwork slot positions.
	 *
	 * Returns: image/png binary download (not JSON).
	 */
	public function template_guide($id = null) {
		$result = $this->sa->generate_template_guide();

		if (!is_array($result) || !isset($result['ImageData'])) {
			header('Content-Type: application/json');
			echo json_encode(array('Status' => 1, 'Message' => 'Failed to generate template guide.'));
			exit;
		}

		$png_data = base64_decode($result['ImageData']);
		if ($png_data === false) {
			header('Content-Type: application/json');
			echo json_encode(array('Status' => 1, 'Message' => 'Failed to decode template guide image.'));
			exit;
		}

		header('Content-Type: image/png');
		header('Content-Disposition: attachment; filename="scroll_artwork_template_guide.png"');
		header('Content-Length: ' . strlen($png_data));
		echo $png_data;
		exit;
	}

}

?>
