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
		);

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
		$layout_location = trim($_GET['layout_location'] ?? '');
		$page = max(1, (int)($_GET['page'] ?? 1));
		$per_page = max(1, min(100, (int)($_GET['per_page'] ?? 12)));

		$result = $this->sa->browse($layout_location, $page, $per_page);

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
		$query = trim($_GET['query'] ?? '');
		$layout_location = trim($_GET['layout_location'] ?? '');
		$page = max(1, (int)($_GET['page'] ?? 1));
		$per_page = max(1, min(100, (int)($_GET['per_page'] ?? 12)));

		$result = $this->sa->search($query, $layout_location, $page, $per_page);

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
	 * Get pending artwork for admin review.
	 * Admin only (AUTH_ADMIN + AUTH_EDIT).
	 *
	 * GET params: page (default 1), per_page (default 20)
	 *
	 * Returns JSON: {Artwork: [...], Total, Page, PerPage, Status}
	 */
	public function pending($id = null) {
		$this->require_admin();

		$page = max(1, (int)($_GET['page'] ?? 1));
		$per_page = max(1, min(100, (int)($_GET['per_page'] ?? 20)));

		$result = $this->sa->get_pending($page, $per_page);

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
	 * Approve a pending artwork.
	 * Admin only (AUTH_ADMIN + AUTH_EDIT).
	 *
	 * POST params: artwork_id
	 *
	 * Returns JSON: {Status, Message}
	 */
	public function approve($id = null) {
		$this->require_admin();

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
	 * Reject a pending artwork with a reason.
	 * Admin only (AUTH_ADMIN + AUTH_EDIT).
	 *
	 * POST params: artwork_id, reason
	 *
	 * Returns JSON: {Status, Message}
	 */
	public function reject($id = null) {
		$this->require_admin();

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
