<?php

class ScrollArtwork extends Ork3 {

	/**
	 * License agreement text that uploaders must accept.
	 */
	const SCROLL_ARTWORK_LICENSE = 'By uploading this artwork, I certify that I am the original creator or have obtained explicit permission from the creator to distribute this work. I grant Amtgard a non-exclusive, royalty-free license to use, display, and distribute this artwork within the Online Record Keeper (ORK) scroll generation system. This artwork may be used by any ORK user to create award scrolls. I understand that I may request removal of my artwork at any time by contacting an administrator.';

	/**
	 * Artwork slot dimension specifications at 300 DPI (2550x3300 page).
	 * Each entry: [width, height, x_position, y_position]
	 */
	const SLOT_DIMENSIONS = array(
		'full_border'   => array('w' => 2550, 'h' => 3300, 'x' => 0,    'y' => 0),
		'border_left'   => array('w' => 300,  'h' => 3300, 'x' => 0,    'y' => 0),
		'border_right'  => array('w' => 300,  'h' => 3300, 'x' => 2250, 'y' => 0),
		'border_top'    => array('w' => 2550, 'h' => 400,  'x' => 0,    'y' => 0),
		'border_bottom' => array('w' => 2550, 'h' => 400,  'x' => 0,    'y' => 2900),
		'center_image'  => array('w' => 1200, 'h' => 1200, 'x' => 675,  'y' => 1050),
		'watermark'     => array('w' => 2550, 'h' => 3300, 'x' => 0,    'y' => 0),
		'top_graphic'   => array('w' => 800,  'h' => 500,  'x' => 875,  'y' => 50),
	);

	/**
	 * Valid layout location values (matches ENUM in ork_scroll_artwork table).
	 */
	const VALID_LOCATIONS = array(
		'full_border', 'border_left', 'border_right', 'border_top',
		'border_bottom', 'center_image', 'watermark', 'top_graphic'
	);

	/**
	 * Maximum raw image upload size in bytes (2 MB).
	 */
	const MAX_UPLOAD_BYTES = 2097152;

	/**
	 * Maximum base64-encoded upload size (~2 MB raw = ~2730000 base64 chars).
	 */
	const MAX_UPLOAD_BASE64 = 2730000;

	public function __construct() {
		parent::__construct();
	}

	/**
	 * Upload a new scroll artwork image.
	 *
	 * @param array $request Keys: Token, Image, ImageMimeType, Name, Description,
	 *                       Tags, LayoutLocation, LicenseSignerName
	 * @return array Status response with ArtworkId on success
	 */
	public function upload($request) {
		$notices = '';

		// Auth: must be logged in
		$mundane_id = Ork3::$Lib->authorization->IsAuthorized($request['Token']);
		if ($mundane_id <= 0) {
			return array('Status' => NoAuthorization());
		}

		// Validate required fields
		$name = trim($request['Name'] ?? '');
		$layout_location = trim($request['LayoutLocation'] ?? '');
		$license_signer = trim($request['LicenseSignerName'] ?? '');
		$image_data = $request['Image'] ?? '';
		$mime_type = $request['ImageMimeType'] ?? '';

		if (strlen($name) === 0) {
			return array('Status' => InvalidParameter(null, 'Name is required.'));
		}
		if (strlen($name) > 150) {
			return array('Status' => InvalidParameter(null, 'Name must be 150 characters or fewer.'));
		}
		if (!in_array($layout_location, self::VALID_LOCATIONS)) {
			return array('Status' => InvalidParameter(null, 'Invalid layout location.'));
		}
		if (strlen($license_signer) === 0) {
			return array('Status' => InvalidParameter(null, 'License signer name is required.'));
		}
		if (strlen($license_signer) > 200) {
			return array('Status' => InvalidParameter(null, 'License signer name must be 200 characters or fewer.'));
		}

		// Validate image data
		if (strlen($image_data) === 0) {
			return array('Status' => InvalidParameter(null, 'Image data is required.'));
		}
		if (strlen($image_data) > self::MAX_UPLOAD_BASE64) {
			return array('Status' => InvalidParameter(null, 'Image must be no larger than 2 MB.'));
		}

		// Validate mime type
		if (!Common::supported_mime_types($mime_type) || Common::is_pdf_mime_type($mime_type)) {
			return array('Status' => InvalidParameter(null, 'Images must be PNG, JPEG, or GIF format.'));
		}

		// Decode and validate the image
		$raw = base64_decode($image_data, true);
		if ($raw === false || strlen($raw) > self::MAX_UPLOAD_BYTES) {
			return array('Status' => InvalidParameter(null, 'Image could not be decoded or exceeds size limit.'));
		}

		$gd = @imagecreatefromstring($raw);
		if ($gd === false) {
			return array('Status' => InvalidParameter(null, 'Image could not be processed. Ensure it is a valid PNG, JPEG, or GIF.'));
		}

		$width = imagesx($gd);
		$height = imagesy($gd);

		// Optional fields
		$description = trim($request['Description'] ?? '');
		if (strlen($description) > 65535) {
			$description = substr($description, 0, 65535);
		}
		$tags = trim($request['Tags'] ?? '');
		if (strlen($tags) > 500) {
			$tags = substr($tags, 0, 500);
		}

		// Determine original file name from mime type
		$ext_map = array(
			'IMAGE/PNG' => 'png',
			'IMAGE/JPEG' => 'jpg',
			'IMAGE/GIF' => 'gif',
		);
		$original_ext = $ext_map[strtoupper($mime_type)] ?? 'png';
		$original_file_name = preg_replace('/[^a-zA-Z0-9_\-\.]/', '_', $name) . '.' . $original_ext;

		// Insert DB record first to get the auto-increment ID
		$now = date('Y-m-d H:i:s');

		$this->db->Clear();
		$this->db->uploader_mundane_id = $mundane_id;
		$this->db->name = $name;
		$this->db->description = $description;
		$this->db->tags = $tags;
		$this->db->layout_location = $layout_location;
		$this->db->file_name = 'pending'; // placeholder until we know the ID
		$this->db->original_file_name = $original_file_name;
		$this->db->width = $width;
		$this->db->height = $height;
		$this->db->file_size = strlen($raw);
		$this->db->license_signer_name = $license_signer;
		$this->db->license_signed_at = $now;
		$this->db->status = 'pending';
		$this->db->created_at = $now;

		$sql = "INSERT INTO " . DB_PREFIX . "scroll_artwork
			(uploader_mundane_id, name, description, tags, layout_location,
			 file_name, original_file_name, width, height, file_size,
			 license_signer_name, license_signed_at, status, created_at)
			VALUES
			(:uploader_mundane_id, :name, :description, :tags, :layout_location,
			 :file_name, :original_file_name, :width, :height, :file_size,
			 :license_signer_name, :license_signed_at, :status, :created_at)";

		$this->db->Execute($sql);
		$artwork_id = $this->db->GetLastInsertId();

		if (!$artwork_id) {
			imagedestroy($gd);
			return array('Status' => InvalidParameter(null, 'Failed to create artwork record.'));
		}

		// Build file name: {artwork_id}_{slot}.png
		$file_name = $artwork_id . '_' . $layout_location . '.png';

		// Ensure directory exists
		if (!is_dir(DIR_SCROLL_ARTWORK)) {
			@mkdir(DIR_SCROLL_ARTWORK, 0755, true);
		}

		// Convert to PNG with transparency support
		$dest_path = DIR_SCROLL_ARTWORK . $file_name;
		imagealphablending($gd, false);
		imagesavealpha($gd, true);
		imagepng($gd, $dest_path);
		imagedestroy($gd);

		// Update the DB record with the real file name
		$this->db->Clear();
		$this->db->file_name = $file_name;
		$this->db->artwork_id = $artwork_id;
		$sql = "UPDATE " . DB_PREFIX . "scroll_artwork
			SET file_name = :file_name
			WHERE scroll_artwork_id = :artwork_id";
		$this->db->Execute($sql);

		return array(
			'ArtworkId' => $artwork_id,
			'Status' => Success()
		);
	}

	/**
	 * Get a single artwork record by ID.
	 *
	 * @param int $artwork_id
	 * @return array Artwork record with URL, or error status
	 */
	public function get($artwork_id) {
		$artwork_id = intval($artwork_id);
		if ($artwork_id <= 0) {
			return array('Status' => InvalidParameter(null, 'Invalid artwork ID.'));
		}

		$this->db->Clear();
		$this->db->artwork_id = $artwork_id;
		$sql = "SELECT sa.*, m.persona as uploader_persona
			FROM " . DB_PREFIX . "scroll_artwork sa
			LEFT JOIN " . DB_PREFIX . "mundane m ON m.mundane_id = sa.uploader_mundane_id
			WHERE sa.scroll_artwork_id = :artwork_id";
		$r = $this->db->DataSet($sql);

		if ($r->Size() > 0 && $r->Next()) {
			return array(
				'Artwork' => $this->format_artwork_row($r),
				'Status' => Success()
			);
		}

		return array('Status' => InvalidParameter(null, 'Artwork not found.'));
	}

	/**
	 * Browse approved artwork for a given layout location, paginated.
	 *
	 * @param string $layout_location  Slot type to filter by (or empty for all)
	 * @param int    $page             Page number (1-based)
	 * @param int    $per_page         Items per page (default 20, max 100)
	 * @return array Paginated list of approved artwork with total count
	 */
	public function browse($layout_location = '', $page = 1, $per_page = 20) {
		$page = max(1, intval($page));
		$per_page = max(1, min(100, intval($per_page)));
		$offset = ($page - 1) * $per_page;

		$where = " WHERE sa.status = 'approved'";
		$layout_location = trim($layout_location);
		if (strlen($layout_location) > 0 && in_array($layout_location, self::VALID_LOCATIONS)) {
			$where .= " AND sa.layout_location = :layout_location";
		}

		// Get total count
		$this->db->Clear();
		if (strlen($layout_location) > 0 && in_array($layout_location, self::VALID_LOCATIONS)) {
			$this->db->layout_location = $layout_location;
		}
		$count_sql = "SELECT COUNT(*) as total FROM " . DB_PREFIX . "scroll_artwork sa" . $where;
		$cr = $this->db->DataSet($count_sql);
		$total = ($cr->Size() > 0 && $cr->Next()) ? intval($cr->total) : 0;

		// Get page of results
		$this->db->Clear();
		if (strlen($layout_location) > 0 && in_array($layout_location, self::VALID_LOCATIONS)) {
			$this->db->layout_location = $layout_location;
		}
		$sql = "SELECT sa.*, m.persona as uploader_persona
			FROM " . DB_PREFIX . "scroll_artwork sa
			LEFT JOIN " . DB_PREFIX . "mundane m ON m.mundane_id = sa.uploader_mundane_id
			" . $where . "
			ORDER BY sa.created_at DESC
			LIMIT " . (int)$per_page . " OFFSET " . (int)$offset . "";
		$r = $this->db->DataSet($sql);

		$artwork = array();
		while ($r->Next()) {
			$artwork[] = $this->format_artwork_row($r);
		}

		return array(
			'Artwork' => $artwork,
			'Total' => $total,
			'Page' => $page,
			'PerPage' => $per_page,
			'Status' => Success()
		);
	}

	/**
	 * Search approved artwork by name/tags within an optional layout location.
	 *
	 * @param string $query            Search query
	 * @param string $layout_location  Optional slot filter
	 * @param int    $page             Page number (1-based)
	 * @param int    $per_page         Items per page
	 * @return array Paginated search results
	 */
	public function search($query, $layout_location = '', $page = 1, $per_page = 20) {
		$page = max(1, intval($page));
		$per_page = max(1, min(100, intval($per_page)));
		$offset = ($page - 1) * $per_page;

		$search_term = trim($query);
		if (strlen($search_term) === 0) {
			return $this->browse($layout_location, $page, $per_page);
		}
		$like_term = '%' . $search_term . '%';

		$where = " WHERE sa.status = 'approved' AND (sa.name LIKE :search_name OR sa.tags LIKE :search_tags)";
		$layout_location = trim($layout_location);
		$has_location = (strlen($layout_location) > 0 && in_array($layout_location, self::VALID_LOCATIONS));
		if ($has_location) {
			$where .= " AND sa.layout_location = :layout_location";
		}

		// Get total count
		$this->db->Clear();
		$this->db->search_name = $like_term;
		$this->db->search_tags = $like_term;
		if ($has_location) {
			$this->db->layout_location = $layout_location;
		}
		$count_sql = "SELECT COUNT(*) as total FROM " . DB_PREFIX . "scroll_artwork sa" . $where;
		$cr = $this->db->DataSet($count_sql);
		$total = ($cr->Size() > 0 && $cr->Next()) ? intval($cr->total) : 0;

		// Get page of results
		$this->db->Clear();
		$this->db->search_name = $like_term;
		$this->db->search_tags = $like_term;
		if ($has_location) {
			$this->db->layout_location = $layout_location;
		}
		$sql = "SELECT sa.*, m.persona as uploader_persona
			FROM " . DB_PREFIX . "scroll_artwork sa
			LEFT JOIN " . DB_PREFIX . "mundane m ON m.mundane_id = sa.uploader_mundane_id
			" . $where . "
			ORDER BY sa.created_at DESC
			LIMIT " . (int)$per_page . " OFFSET " . (int)$offset . "";
		$r = $this->db->DataSet($sql);

		$artwork = array();
		while ($r->Next()) {
			$artwork[] = $this->format_artwork_row($r);
		}

		return array(
			'Artwork' => $artwork,
			'Total' => $total,
			'Page' => $page,
			'PerPage' => $per_page,
			'Query' => $search_term,
			'Status' => Success()
		);
	}

	/**
	 * Get pending artwork for admin review, paginated.
	 *
	 * @param int $page     Page number (1-based)
	 * @param int $per_page Items per page
	 * @return array Paginated list of pending artwork with uploader persona
	 */
	public function get_pending($page = 1, $per_page = 20) {
		$page = max(1, intval($page));
		$per_page = max(1, min(100, intval($per_page)));
		$offset = ($page - 1) * $per_page;

		// Get total count
		$this->db->Clear();
		$count_sql = "SELECT COUNT(*) as total FROM " . DB_PREFIX . "scroll_artwork WHERE status = 'pending'";
		$cr = $this->db->DataSet($count_sql);
		$total = ($cr->Size() > 0 && $cr->Next()) ? intval($cr->total) : 0;

		// Get page of results
		$this->db->Clear();
		$sql = "SELECT sa.*, m.persona as uploader_persona
			FROM " . DB_PREFIX . "scroll_artwork sa
			LEFT JOIN " . DB_PREFIX . "mundane m ON m.mundane_id = sa.uploader_mundane_id
			WHERE sa.status = 'pending'
			ORDER BY sa.created_at ASC
			LIMIT " . (int)$per_page . " OFFSET " . (int)$offset . "";
		$r = $this->db->DataSet($sql);

		$artwork = array();
		while ($r->Next()) {
			$artwork[] = $this->format_artwork_row($r);
		}

		return array(
			'Artwork' => $artwork,
			'Total' => $total,
			'Page' => $page,
			'PerPage' => $per_page,
			'Status' => Success()
		);
	}

	/**
	 * Approve a pending artwork. Requires admin authority.
	 *
	 * @param array $request Keys: Token, ArtworkId
	 * @return array Status response
	 */
	public function approve($request) {
		$mundane_id = Ork3::$Lib->authorization->IsAuthorized($request['Token']);
		if ($mundane_id <= 0 || !Ork3::$Lib->authorization->HasAuthority($mundane_id, AUTH_ADMIN, 0, AUTH_EDIT)) {
			return array('Status' => NoAuthorization());
		}

		$artwork_id = intval($request['ArtworkId']);
		if ($artwork_id <= 0) {
			return array('Status' => InvalidParameter(null, 'Invalid artwork ID.'));
		}

		// Verify artwork exists and is pending
		$this->db->Clear();
		$this->db->artwork_id = $artwork_id;
		$sql = "SELECT scroll_artwork_id, status FROM " . DB_PREFIX . "scroll_artwork WHERE scroll_artwork_id = :artwork_id";
		$r = $this->db->DataSet($sql);
		if ($r->Size() <= 0 || !$r->Next()) {
			return array('Status' => InvalidParameter(null, 'Artwork not found.'));
		}
		if ($r->status !== 'pending') {
			return array('Status' => InvalidParameter(null, 'Artwork is not in pending status.'));
		}

		// Update status
		$now = date('Y-m-d H:i:s');
		$this->db->Clear();
		$this->db->status = 'approved';
		$this->db->approved_by = $mundane_id;
		$this->db->approved_at = $now;
		$this->db->artwork_id = $artwork_id;
		$sql = "UPDATE " . DB_PREFIX . "scroll_artwork
			SET status = :status, approved_by_mundane_id = :approved_by, approved_at = :approved_at
			WHERE scroll_artwork_id = :artwork_id";
		$this->db->Execute($sql);

		return array('Status' => Success());
	}

	/**
	 * Reject a pending artwork. Requires admin authority.
	 *
	 * @param array $request Keys: Token, ArtworkId, Reason
	 * @return array Status response
	 */
	public function reject($request) {
		$mundane_id = Ork3::$Lib->authorization->IsAuthorized($request['Token']);
		if ($mundane_id <= 0 || !Ork3::$Lib->authorization->HasAuthority($mundane_id, AUTH_ADMIN, 0, AUTH_EDIT)) {
			return array('Status' => NoAuthorization());
		}

		$artwork_id = intval($request['ArtworkId']);
		if ($artwork_id <= 0) {
			return array('Status' => InvalidParameter(null, 'Invalid artwork ID.'));
		}

		$reason = trim($request['Reason'] ?? '');
		if (strlen($reason) === 0) {
			return array('Status' => InvalidParameter(null, 'Rejection reason is required.'));
		}
		if (strlen($reason) > 500) {
			$reason = substr($reason, 0, 500);
		}

		// Verify artwork exists and is pending
		$this->db->Clear();
		$this->db->artwork_id = $artwork_id;
		$sql = "SELECT scroll_artwork_id, status FROM " . DB_PREFIX . "scroll_artwork WHERE scroll_artwork_id = :artwork_id";
		$r = $this->db->DataSet($sql);
		if ($r->Size() <= 0 || !$r->Next()) {
			return array('Status' => InvalidParameter(null, 'Artwork not found.'));
		}
		if ($r->status !== 'pending') {
			return array('Status' => InvalidParameter(null, 'Artwork is not in pending status.'));
		}

		// Update status
		$this->db->Clear();
		$this->db->status = 'rejected';
		$this->db->reason = $reason;
		$this->db->rejected_by = $mundane_id;
		$this->db->artwork_id = $artwork_id;
		$sql = "UPDATE " . DB_PREFIX . "scroll_artwork
			SET status = :status, rejection_reason = :reason, approved_by_mundane_id = :rejected_by
			WHERE scroll_artwork_id = :artwork_id";
		$this->db->Execute($sql);

		return array('Status' => Success());
	}

	/**
	 * Get all uploads by a specific user, any status, paginated.
	 *
	 * @param int $mundane_id  User ID
	 * @param int $page        Page number (1-based)
	 * @param int $per_page    Items per page
	 * @return array Paginated list of user's artwork
	 */
	public function get_user_uploads($mundane_id, $page = 1, $per_page = 20) {
		$mundane_id = intval($mundane_id);
		if ($mundane_id <= 0) {
			return array('Status' => InvalidParameter(null, 'Invalid user ID.'));
		}

		$page = max(1, intval($page));
		$per_page = max(1, min(100, intval($per_page)));
		$offset = ($page - 1) * $per_page;

		// Get total count
		$this->db->Clear();
		$this->db->mundane_id = $mundane_id;
		$count_sql = "SELECT COUNT(*) as total FROM " . DB_PREFIX . "scroll_artwork WHERE uploader_mundane_id = :mundane_id";
		$cr = $this->db->DataSet($count_sql);
		$total = ($cr->Size() > 0 && $cr->Next()) ? intval($cr->total) : 0;

		// Get page of results
		$this->db->Clear();
		$this->db->mundane_id = $mundane_id;
		$sql = "SELECT sa.*, m.persona as uploader_persona
			FROM " . DB_PREFIX . "scroll_artwork sa
			LEFT JOIN " . DB_PREFIX . "mundane m ON m.mundane_id = sa.uploader_mundane_id
			WHERE sa.uploader_mundane_id = :mundane_id
			ORDER BY sa.created_at DESC
			LIMIT " . (int)$per_page . " OFFSET " . (int)$offset . "";
		$r = $this->db->DataSet($sql);

		$artwork = array();
		while ($r->Next()) {
			$artwork[] = $this->format_artwork_row($r);
		}

		return array(
			'Artwork' => $artwork,
			'Total' => $total,
			'Page' => $page,
			'PerPage' => $per_page,
			'Status' => Success()
		);
	}

	/**
	 * Delete an artwork record and its file. Allowed by the uploader or an admin.
	 *
	 * @param array $request Keys: Token, ArtworkId
	 * @return array Status response
	 */
	public function delete($request) {
		$mundane_id = Ork3::$Lib->authorization->IsAuthorized($request['Token']);
		if ($mundane_id <= 0) {
			return array('Status' => NoAuthorization());
		}

		$artwork_id = intval($request['ArtworkId']);
		if ($artwork_id <= 0) {
			return array('Status' => InvalidParameter(null, 'Invalid artwork ID.'));
		}

		// Fetch the artwork record
		$this->db->Clear();
		$this->db->artwork_id = $artwork_id;
		$sql = "SELECT scroll_artwork_id, uploader_mundane_id, file_name
			FROM " . DB_PREFIX . "scroll_artwork WHERE scroll_artwork_id = :artwork_id";
		$r = $this->db->DataSet($sql);

		if ($r->Size() <= 0 || !$r->Next()) {
			return array('Status' => InvalidParameter(null, 'Artwork not found.'));
		}

		// Authorization: must be uploader or admin
		$is_uploader = (intval($r->uploader_mundane_id) === $mundane_id);
		$is_admin = Ork3::$Lib->authorization->HasAuthority($mundane_id, AUTH_ADMIN, 0, AUTH_EDIT);
		if (!$is_uploader && !$is_admin) {
			return array('Status' => NoAuthorization());
		}

		// Delete the file from disk
		$file_path = DIR_SCROLL_ARTWORK . $r->file_name;
		if (file_exists($file_path)) {
			unlink($file_path);
		}

		// Delete the DB record
		$this->db->Clear();
		$this->db->artwork_id = $artwork_id;
		$sql = "DELETE FROM " . DB_PREFIX . "scroll_artwork WHERE scroll_artwork_id = :artwork_id";
		$this->db->Execute($sql);

		return array('Status' => Success());
	}

	/**
	 * Generate a template guide PNG showing all 8 artwork slot positions
	 * with labels, dimensions, overlap zones, z-order badges, and a legend.
	 *
	 * @return array Contains base64-encoded PNG image data
	 */
	public function generate_template_guide() {
			// ============================================================
			//  Scroll Artwork Template Guide — Professional Wireframe
			//  Page at 2550x3300, canvas 3150x3900 (300px margin for annotations)
			// ============================================================

			$page_w = 2550;
			$page_h = 3300;
			$margin  = 300;
			$canvas_w = $page_w + $margin * 2;
			$canvas_h = $page_h + $margin * 2;

			$img = imagecreatetruecolor($canvas_w, $canvas_h);
			imagealphablending($img, true);
			imagesavealpha($img, true);

			// Font setup
			$fontDir = DIR_ASSETS . 'scroll/fonts/';
			$fontBold = $fontDir . 'Cinzel-Regular.ttf';
			$fontBody = $fontDir . 'EBGaramond-Regular.ttf';
			$useTTF   = file_exists($fontBold) && file_exists($fontBody);

			// ---- Colors ----
			$cCanvas     = imagecolorallocate($img, 245, 243, 240);
			$cPageBg     = imagecolorallocate($img, 255, 255, 255);
			$cPageBorder = imagecolorallocate($img, 160, 160, 160);
			$cBlack      = imagecolorallocate($img, 30, 30, 30);
			$cDarkGray   = imagecolorallocate($img, 80, 80, 80);
			$cMidGray    = imagecolorallocate($img, 140, 140, 140);
			$cWhite      = imagecolorallocate($img, 255, 255, 255);

			// Distinct per-slot colors
			$sc = array(
				'watermark'     => array('fill' => imagecolorallocatealpha($img, 160, 160, 210, 105), 'line' => imagecolorallocate($img, 100, 100, 160)),
				'full_border'   => array('fill' => imagecolorallocatealpha($img, 180, 180, 180, 105), 'line' => imagecolorallocate($img, 120, 120, 120)),
				'border_top'    => array('fill' => imagecolorallocatealpha($img,  76, 175,  80,  80), 'line' => imagecolorallocate($img,  46, 125,  50)),
				'border_bottom' => array('fill' => imagecolorallocatealpha($img, 255, 152,   0,  80), 'line' => imagecolorallocate($img, 200, 120,   0)),
				'border_left'   => array('fill' => imagecolorallocatealpha($img, 229,  57,  53,  80), 'line' => imagecolorallocate($img, 180,  40,  40)),
				'border_right'  => array('fill' => imagecolorallocatealpha($img,  30, 136, 229,  80), 'line' => imagecolorallocate($img,  20, 100, 180)),
				'top_graphic'   => array('fill' => imagecolorallocatealpha($img,   0, 150, 136,  80), 'line' => imagecolorallocate($img,   0, 120, 110)),
				'center_image'  => array('fill' => imagecolorallocatealpha($img, 156,  39, 176,  70), 'line' => imagecolorallocate($img, 120,  30, 140)),
			);

			// Fill canvas background
			imagefilledrectangle($img, 0, 0, $canvas_w - 1, $canvas_h - 1, $cCanvas);

			// Draw page rectangle
			imagefilledrectangle($img, $margin, $margin, $margin + $page_w - 1, $margin + $page_h - 1, $cPageBg);
			imagesetthickness($img, 3);
			imagerectangle($img, $margin, $margin, $margin + $page_w - 1, $margin + $page_h - 1, $cPageBorder);
			imagesetthickness($img, 1);

			// ============================================================
			//  Draw slots in z-order (back to front)
			// ============================================================

			$z_order = array('watermark', 'full_border', 'border_top', 'border_bottom', 'border_left', 'border_right', 'top_graphic', 'center_image');

			foreach ($z_order as $slot) {
				$dim = self::SLOT_DIMENSIONS[$slot];
				$x1 = $margin + $dim['x'];
				$y1 = $margin + $dim['y'];
				$x2 = $x1 + $dim['w'] - 1;
				$y2 = $y1 + $dim['h'] - 1;

				if ($slot === 'watermark') {
					// Dotted outline inset 15px — subtle, shows full-page coverage
					$this->draw_dashed_rect($img, $x1 + 15, $y1 + 15, $x2 - 15, $y2 - 15, $sc[$slot]['line'], 30, 15);
				} elseif ($slot === 'full_border') {
					// Dashed outline inset 6px, thicker — distinguishable from watermark
					imagesetthickness($img, 3);
					$this->draw_dashed_rect($img, $x1 + 6, $y1 + 6, $x2 - 6, $y2 - 6, $sc[$slot]['line'], 20, 8);
					imagesetthickness($img, 1);
				} else {
					// Concrete slots: hatched fill + solid border
					// Hatch direction matches slot orientation for visual clarity
					if ($slot === 'border_left' || $slot === 'border_right') {
						for ($hx = $x1; $hx <= $x2; $hx += 8) imageline($img, $hx, $y1, $hx, $y2, $sc[$slot]['fill']);
					} elseif ($slot === 'border_top' || $slot === 'border_bottom') {
						for ($hy = $y1; $hy <= $y2; $hy += 8) imageline($img, $x1, $hy, $x2, $hy, $sc[$slot]['fill']);
					} else {
						// Diagonal hatch for center_image and top_graphic
						for ($d = -($y2 - $y1); $d <= ($x2 - $x1); $d += 12) {
							imageline($img, max($x1, $x1 + $d), max($y1, $y1 - $d), min($x2, $x1 + $d + ($y2 - $y1)), min($y2, $y1 - $d + ($x2 - $x1)), $sc[$slot]['fill']);
						}
					}
					// Solid border — thicker for non-edge slots
					$bw = ($slot === 'center_image' || $slot === 'top_graphic') ? 4 : 3;
					imagesetthickness($img, $bw);
					imagerectangle($img, $x1, $y1, $x2, $y2, $sc[$slot]['line']);
					imagesetthickness($img, 1);
				}
			}

			// ============================================================
			//  Corner overlap indicators (where edge borders intersect)
			// ============================================================
			$cOverlap = imagecolorallocatealpha($img, 255, 200, 0, 70);
			$cOverlapLine = imagecolorallocate($img, 200, 160, 0);
			$overlaps = array(
				array(0, 0, 300, 400),        // top-left
				array(2250, 0, 300, 400),     // top-right
				array(0, 2900, 300, 400),     // bottom-left
				array(2250, 2900, 300, 400),  // bottom-right
			);
			foreach ($overlaps as $oz) {
				$ox1 = $margin + $oz[0]; $oy1 = $margin + $oz[1];
				$ox2 = $ox1 + $oz[2] - 1; $oy2 = $oy1 + $oz[3] - 1;
				// Crosshatch fill
				for ($d = 0; $d < $oz[2] + $oz[3]; $d += 10) {
					imageline($img, max($ox1, $ox1 + $d - $oz[3]), max($oy1, $oy1 + $d - $oz[2]), min($ox2, $ox1 + $d), min($oy2, $oy1 + $d), $cOverlap);
				}
				imagesetthickness($img, 2);
				imagerectangle($img, $ox1, $oy1, $ox2, $oy2, $cOverlapLine);
				imagesetthickness($img, 1);
			}

			// ============================================================
			//  Content Safe Zone (dotted rectangle)
			// ============================================================
			$safe_x1 = $margin + 340; $safe_y1 = $margin + 440;
			$safe_x2 = $margin + 2210; $safe_y2 = $margin + 2860;
			$cSafe = imagecolorallocate($img, 180, 200, 180);
			imagesetthickness($img, 2);
			$this->draw_dashed_rect($img, $safe_x1, $safe_y1, $safe_x2, $safe_y2, $cSafe, 15, 8);
			imagesetthickness($img, 1);

			if (!$useTTF) {
				// Fallback with built-in fonts
				$title = 'SCROLL ARTWORK TEMPLATE GUIDE (2550x3300 @ 300 DPI)';
				imagestring($img, 5, intval(($canvas_w - strlen($title) * imagefontwidth(5)) / 2), 10, $title, $cBlack);
				ob_start(); imagepng($img); $png_data = ob_get_clean(); imagedestroy($img);
				return array('ImageData' => base64_encode($png_data), 'Width' => $canvas_w, 'Height' => $canvas_h, 'MimeType' => 'image/png', 'Status' => Success());
			}

			// ============================================================
			//  Labels with TTF fonts
			// ============================================================

			// Title bar
			$titleSize = 42;
			$title = 'SCROLL ARTWORK TEMPLATE GUIDE';
			$tBox = imagettfbbox($titleSize, 0, $fontBold, $title);
			$tW = $tBox[2] - $tBox[0];
			$tX = intval(($canvas_w - $tW) / 2);
			imagefilledrectangle($img, $tX - 20, 15, $tX + $tW + 20, 70, $cBlack);
			imagettftext($img, $titleSize, 0, $tX, 62, $cWhite, $fontBold, $title);

			// Subtitle
			$sub = 'Print Resolution: 2550 x 3300 px  |  300 DPI  |  8.5" x 11" Letter';
			$sBox = imagettfbbox(24, 0, $fontBody, $sub);
			$sW = $sBox[2] - $sBox[0];
			imagettftext($img, 24, 0, intval(($canvas_w - $sW) / 2), 102, $cDarkGray, $fontBody, $sub);

			// ---- Per-slot labels (horizontal slots) ----
			$labels = array(
				'border_top'    => array('TOP BORDER',      '2550 x 400',                                 'Z3', 1800, 200),
				'top_graphic'   => array('TOP GRAPHIC',     '800 x 500',                                  'Z4', $page_w / 2, 380),
				'watermark'     => array('WATERMARK',       '2550 x 3300  |  Full page  |  10% opacity',  'Z1', 500, 800),
				'full_border'   => array('FULL BORDER',     '2550 x 3300  |  Full page frame  |  100%',   'Z2', 2050, 700),
				'center_image'  => array('CENTER IMAGE',    '1200 x 1200  |  15% opacity',                'Z5', $page_w / 2, 1650),
				'border_bottom' => array('BOTTOM BORDER',   '2550 x 400',                                 'Z3', $page_w / 2, 3100),
			);

			foreach ($labels as $slot => $lbl) {
				$lx = $margin + $lbl[3];
				$ly = $margin + $lbl[4];
				$nameSize = 32;
				$dimSize = 22;

				$nBox = imagettfbbox($nameSize, 0, $fontBold, $lbl[0]);
				$nW = $nBox[2] - $nBox[0];
				$dBox = imagettfbbox($dimSize, 0, $fontBody, $lbl[1]);
				$dW = $dBox[2] - $dBox[0];
				$boxW = max($nW, $dW) + 30;
				$boxH = $nameSize + $dimSize + 28;

				$bx1 = $lx - intval($boxW / 2);
				$by1 = $ly - intval($boxH / 2);
				$bx2 = $bx1 + $boxW;
				$by2 = $by1 + $boxH;

				// White background box with colored border
				imagefilledrectangle($img, $bx1, $by1, $bx2, $by2, $cWhite);
				imagesetthickness($img, 2);
				imagerectangle($img, $bx1, $by1, $bx2, $by2, $sc[$slot]['line']);
				imagesetthickness($img, 1);

				// Slot name
				imagettftext($img, $nameSize, 0, $lx - intval($nW / 2), $by1 + $nameSize + 8, $sc[$slot]['line'], $fontBold, $lbl[0]);
				// Dimensions
				imagettftext($img, $dimSize, 0, $lx - intval($dW / 2), $by2 - 8, $cDarkGray, $fontBody, $lbl[1]);
				// Z-order badge
				$this->draw_z_badge($img, $bx1 - 8, $by1 - 8, $lbl[2], $sc[$slot]['line'], $cWhite, $fontBold);
			}

			// Left/Right border labels (vertical text)
			foreach (array('border_left' => 150, 'border_right' => 2400) as $slot => $cx) {
				$dim = self::SLOT_DIMENSIONS[$slot];
				$lx = $margin + $cx;
				$ly = $margin + 1650;
				$name = strtoupper(str_replace('border_', '', $slot));
				imagettftext($img, 28, 90, $lx + 14, $ly + 80, $sc[$slot]['line'], $fontBold, $name);
				imagettftext($img, 20, 90, $lx + 14, $ly + 240, $sc[$slot]['line'], $fontBody, $dim['w'] . ' x ' . $dim['h']);
				$this->draw_z_badge($img, $lx - 24, $ly - 250, 'Z3', $sc[$slot]['line'], $cWhite, $fontBold);
			}

			// Content safe zone label
			$csLabel = 'CONTENT SAFE ZONE';
			$csBox = imagettfbbox(26, 0, $fontBold, $csLabel);
			$csW = $csBox[2] - $csBox[0];
			$csX = intval(($safe_x1 + $safe_x2 - $csW) / 2);
			$csY = $safe_y2 - 30;
			imagefilledrectangle($img, $csX - 10, $csY - 30, $csX + $csW + 10, $csY + 8, $cWhite);
			imagettftext($img, 26, 0, $csX, $csY, $cSafe, $fontBold, $csLabel);
			$csSub = 'Title, Body Text, Heraldry, Signatures render here';
			$csSubBox = imagettfbbox(18, 0, $fontBody, $csSub);
			$csSubW = $csSubBox[2] - $csSubBox[0];
			imagettftext($img, 18, 0, intval(($safe_x1 + $safe_x2 - $csSubW) / 2), $csY + 24, $cMidGray, $fontBody, $csSub);

			// Corner overlap labels
			$olPositions = array(
				array($margin + 40, $margin + 415),
				array($margin + 2310, $margin + 415),
				array($margin + 40, $margin + 2895),
				array($margin + 2310, $margin + 2895),
			);
			foreach ($olPositions as $op) {
				imagettftext($img, 16, 0, $op[0], $op[1], $cOverlapLine, $fontBody, 'OVERLAP');
			}

			// ============================================================
			//  Dimension annotations (in the margins)
			// ============================================================
			$cDim = imagecolorallocate($img, 100, 100, 100);

			// Page width (top margin)
			$this->draw_dimension_line($img, $margin, $margin - 50, $margin + $page_w, $margin - 50, $cDim, true);
			$wL = '2550 px (8.5")';
			$wLBox = imagettfbbox(20, 0, $fontBody, $wL);
			imagettftext($img, 20, 0, $margin + intval(($page_w - ($wLBox[2] - $wLBox[0])) / 2), $margin - 60, $cDim, $fontBody, $wL);

			// Page height (right margin)
			$this->draw_dimension_line($img, $margin + $page_w + 50, $margin, $margin + $page_w + 50, $margin + $page_h, $cDim, false);
			imagettftext($img, 20, 90, $margin + $page_w + 80, $margin + intval($page_h / 2) + 80, $cDim, $fontBody, '3300 px (11")');

			// Left border width (left margin)
			$this->draw_dimension_line($img, $margin - 50, $margin + 500, $margin - 50, $margin + 800, $cDim, false);
			imagettftext($img, 16, 90, $margin - 80, $margin + 700, $cDim, $fontBody, '300 px');
			imageline($img, $margin - 50, $margin + 650, $margin, $margin + 650, $cDim);

			// Top border height (left margin)
			$this->draw_dimension_line($img, $margin - 160, $margin, $margin - 160, $margin + 400, $cDim, false);
			imagettftext($img, 16, 90, $margin - 190, $margin + 260, $cDim, $fontBody, '400 px');

			// ============================================================
			//  Legend (below the page)
			// ============================================================
			$legY = $margin + $page_h + 50;
			imagettftext($img, 26, 0, $margin, $legY, $cBlack, $fontBold, 'LEGEND  -  Render Order (back to front)');

			$legItems = array(
				array('watermark',   'Z1  Watermark - full page, 10% opacity (behind everything)'),
				array('full_border', 'Z2  Full Border - full page frame overlay, 100% opacity'),
				array('border_top',  'Z3  Edge Borders (top / bottom / left / right) - over drawn border, 100%'),
				array('top_graphic', 'Z4  Top Center Graphic - above borders, below title, 100%'),
				array('center_image','Z5  Center Image - behind text, above heraldry, 15% opacity'),
			);
			$ly = $legY + 40;
			foreach ($legItems as $li) {
				imagefilledrectangle($img, $margin + 10, $ly, $margin + 50, $ly + 22, $sc[$li[0]]['line']);
				imagettftext($img, 18, 0, $margin + 62, $ly + 20, $cDarkGray, $fontBody, $li[1]);
				$ly += 32;
			}
			// Overlap swatch
			imagefilledrectangle($img, $margin + 10, $ly, $margin + 50, $ly + 22, $cOverlapLine);
			imagettftext($img, 18, 0, $margin + 62, $ly + 20, $cDarkGray, $fontBody, 'Corner Overlap Zones - where edge borders intersect (both layers render)');

			// ---- Output ----
			ob_start(); imagepng($img); $png_data = ob_get_clean(); imagedestroy($img);

			return array(
				'ImageData' => base64_encode($png_data),
				'Width' => $canvas_w,
				'Height' => $canvas_h,
				'MimeType' => 'image/png',
				'Status' => Success()
			);
		}

	/**
	 * Draw a dashed rectangle on a GD image.
	 */
	private function draw_dashed_rect($img, $x1, $y1, $x2, $y2, $color, $dash_len = 10, $gap_len = 5) {
		$this->draw_dashed_line($img, $x1, $y1, $x2, $y1, $color, $dash_len, $gap_len); // top
		$this->draw_dashed_line($img, $x1, $y2, $x2, $y2, $color, $dash_len, $gap_len); // bottom
		$this->draw_dashed_line($img, $x1, $y1, $x1, $y2, $color, $dash_len, $gap_len); // left
		$this->draw_dashed_line($img, $x2, $y1, $x2, $y2, $color, $dash_len, $gap_len); // right
	}

	/**
	 * Draw a dashed line (horizontal or vertical).
	 */
	private function draw_dashed_line($img, $x1, $y1, $x2, $y2, $color, $dash_len, $gap_len) {
		$is_horizontal = ($y1 === $y2);
		$total = $is_horizontal ? abs($x2 - $x1) : abs($y2 - $y1);
		$step = $dash_len + $gap_len;
		$pos = 0;
		while ($pos < $total) {
			$end = min($pos + $dash_len, $total);
			if ($is_horizontal) {
				$sx = $x1 + $pos;
				$ex = $x1 + $end;
				imageline($img, $sx, $y1, $ex, $y1, $color);
			} else {
				$sy = $y1 + $pos;
				$ey = $y1 + $end;
				imageline($img, $x1, $sy, $x1, $ey, $color);
			}
			$pos += $step;
		}
	}

		/**
	 * Draw a small z-order badge (circle with label like "Z1").
	 */
	private function draw_z_badge($img, $x, $y, $label, $bgColor, $textColor, $font) {
		$r = 22;
		imagefilledellipse($img, $x, $y, $r * 2, $r * 2, $bgColor);
		imageellipse($img, $x, $y, $r * 2, $r * 2, $bgColor);
		$box = imagettfbbox(14, 0, $font, $label);
		$tw = $box[2] - $box[0];
		imagettftext($img, 14, 0, $x - intval($tw / 2), $y + 6, $textColor, $font, $label);
	}

	/**
	 * Draw a dimension annotation line with end-caps (serif bars).
	 */
	private function draw_dimension_line($img, $x1, $y1, $x2, $y2, $color, $horizontal = true) {
		imageline($img, $x1, $y1, $x2, $y2, $color);
		if ($horizontal) {
			// Vertical end caps
			imageline($img, $x1, $y1 - 10, $x1, $y1 + 10, $color);
			imageline($img, $x2, $y2 - 10, $x2, $y2 + 10, $color);
		} else {
			// Horizontal end caps
			imageline($img, $x1 - 10, $y1, $x1 + 10, $y1, $color);
			imageline($img, $x2 - 10, $y2, $x2 + 10, $y2, $color);
		}
	}

	/**
	 * Format a result set row into a standardized artwork array.
	 *
	 * @param YapoResultSet $r  Result set positioned at current row
	 * @return array Formatted artwork record
	 */
	private function format_artwork_row($r) {
		return array(
			'ArtworkId' => intval($r->scroll_artwork_id),
			'UploaderMundaneId' => intval($r->uploader_mundane_id),
			'UploaderPersona' => $r->uploader_persona ?? '',
			'Name' => $r->name,
			'Description' => $r->description ?? '',
			'Tags' => $r->tags ?? '',
			'LayoutLocation' => $r->layout_location,
			'FileName' => $r->file_name,
			'OriginalFileName' => $r->original_file_name,
			'Url' => HTTP_SCROLL_ARTWORK . $r->file_name,
			'Width' => intval($r->width),
			'Height' => intval($r->height),
			'FileSize' => intval($r->file_size),
			'LicenseSignerName' => $r->license_signer_name,
			'LicenseSignedAt' => $r->license_signed_at,
			'Status' => $r->status,
			'ApprovedByMundaneId' => $r->approved_by_mundane_id ? intval($r->approved_by_mundane_id) : null,
			'ApprovedAt' => $r->approved_at,
			'RejectionReason' => $r->rejection_reason,
			'CreatedAt' => $r->created_at,
			'SlotDimensions' => self::SLOT_DIMENSIONS[$r->layout_location] ?? null,
		);
	}

}

?>
