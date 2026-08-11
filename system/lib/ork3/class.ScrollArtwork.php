<?php

class ScrollArtwork extends Ork3
{
    /**
     * License agreement text that uploaders must accept.
     */
    public const SCROLL_ARTWORK_LICENSE = 'By uploading this artwork, I certify that I am the original creator or have obtained explicit permission from the creator to distribute this work. I grant Amtgard a non-exclusive, royalty-free license to use, display, and distribute this artwork within the Online Record Keeper (ORK) scroll generation system. This artwork may be used by any ORK user to create award scrolls. I understand that I may request removal of my artwork at any time by contacting an administrator.';

    /**
     * Artwork slot dimension specifications at 300 DPI (2550x3300 page).
     * Each entry: [width, height, x_position, y_position]
     */
    public const SLOT_DIMENSIONS = array(
        'full_border'  => array('w' => 2550, 'h' => 3300, 'x' => 0,   'y' => 0),
        'border_side'  => array('w' => 300,  'h' => 3300, 'x' => 0,   'y' => 0),
        'center_image' => array('w' => 1200, 'h' => 1200, 'x' => 675, 'y' => 1050),
        'background'   => array('w' => 2550, 'h' => 3300, 'x' => 0,   'y' => 0),
    );

    /**
     * Valid layout location values (matches ENUM in ork_scroll_artwork table).
     */
    public const VALID_LOCATIONS = array(
        'full_border', 'border_side', 'center_image', 'background'
    );

    /**
     * Maximum raw image upload size in bytes (2 MB).
     */
    public const MAX_UPLOAD_BYTES = 2097152;

    /**
     * Maximum base64-encoded upload size (~2 MB raw = ~2730000 base64 chars).
     */
    public const MAX_UPLOAD_BASE64 = 2730000;

    public function __construct()
    {
        parent::__construct();
    }

    /**
     * Upload a new scroll artwork image.
     *
     * @param array $request Keys: Token, Image, ImageMimeType, Name, Description,
     *                       Tags, LayoutLocation, LicenseSignerName
     * @return array Status response with ArtworkId on success
     */
    public function upload($request)
    {
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

        // Sharing tier + category (new). Tiers: global | kingdom | park.
        $visibility = in_array($request['Visibility'] ?? 'global', array('global', 'kingdom', 'park'), true)
            ? $request['Visibility'] : 'global';
        $owner_kingdom_id = intval($request['OwnerKingdomId'] ?? 0);
        $owner_park_id = intval($request['OwnerParkId'] ?? 0);
        if ($visibility === 'kingdom' && $owner_kingdom_id <= 0) {
            return array('Status' => InvalidParameter(null, 'Kingdom-specific submissions require a kingdom.'));
        }
        if ($visibility === 'park' && $owner_park_id <= 0) {
            return array('Status' => InvalidParameter(null, 'Park-specific submissions require a park.'));
        }
        if ($visibility !== 'park') {
            $owner_park_id = 0; // only park tier carries a park owner
        }
        if ($visibility === 'global') {
            $owner_kingdom_id = 0; // global rows are Amtgard-wide, no owner
        }
        $category_id = intval($request['CategoryId'] ?? 0);
        if ($category_id > 0) {
            $this->db->Clear();
            $this->db->category_id = $category_id;
            $cchk = $this->db->DataSet("SELECT category_id FROM " . DB_PREFIX . "scroll_artwork_category WHERE category_id = :category_id AND active = 1");
            if ($cchk->Size() <= 0) {
                $category_id = 0; // ignore invalid/retired
            }
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
        $this->db->visibility = $visibility;

        // Build the column list dynamically so nullable FKs are omitted when null.
        // (yapo drops null-bound params; omitting the column lets SQL DEFAULT NULL stand.)
        $cols = array(
            'uploader_mundane_id', 'name', 'description', 'tags', 'layout_location',
            'file_name', 'original_file_name', 'width', 'height', 'file_size',
            'license_signer_name', 'license_signed_at', 'status', 'created_at', 'visibility'
        );
        if ($owner_kingdom_id > 0) {
            $cols[] = 'owner_kingdom_id';
            $this->db->owner_kingdom_id = $owner_kingdom_id;
        }
        if ($owner_park_id > 0) {
            $cols[] = 'owner_park_id';
            $this->db->owner_park_id = $owner_park_id;
        }
        if ($category_id > 0) {
            $cols[] = 'category_id';
            $this->db->category_id = $category_id;
        }
        $placeholders = array_map(function ($c) {
            return ':' . $c;
        }, $cols);
        $sql = "INSERT INTO " . DB_PREFIX . "scroll_artwork (" . implode(', ', $cols) . ")
			VALUES (" . implode(', ', $placeholders) . ")";

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
    public function get($artwork_id)
    {
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
    public function browse($layout_location = '', $page = 1, $per_page = 20, $opts = array())
    {
        $page = max(1, intval($page));
        $per_page = max(1, min(100, intval($per_page)));
        $offset = ($page - 1) * $per_page;
        $viewer_kingdom_id = intval($opts['ViewerKingdomId'] ?? 0);
        $tier = $opts['Tier'] ?? 'all'; // all | global | kingdom | park
        $category_id = intval($opts['CategoryId'] ?? 0);

        $viewer_park_id = intval($opts['ViewerParkId'] ?? 0);

        // Visibility clause: approved global to everyone; approved kingdom/park only to that scope.
        $vis = "sa.status = 'approved' AND (sa.visibility = 'global'";
        if ($viewer_kingdom_id > 0) {
            $vis .= " OR (sa.visibility = 'kingdom' AND sa.owner_kingdom_id = " . (int)$viewer_kingdom_id . ")";
        }
        if ($viewer_park_id > 0) {
            $vis .= " OR (sa.visibility = 'park' AND sa.owner_park_id = " . (int)$viewer_park_id . ")";
        }
        $vis .= ")";
        if ($tier === 'global') {
            $vis = "sa.status = 'approved' AND sa.visibility = 'global'";
        }
        if ($tier === 'kingdom' && $viewer_kingdom_id > 0) {
            $vis = "sa.status = 'approved' AND sa.visibility = 'kingdom' AND sa.owner_kingdom_id = " . (int)$viewer_kingdom_id;
        }
        if ($tier === 'park' && $viewer_park_id > 0) {
            $vis = "sa.status = 'approved' AND sa.visibility = 'park' AND sa.owner_park_id = " . (int)$viewer_park_id;
        }

        $filters = "";
        $this->db->Clear();
        $layout_location = trim($layout_location);
        if (strlen($layout_location) > 0 && in_array($layout_location, self::VALID_LOCATIONS)) {
            $filters .= " AND sa.layout_location = :layout_location";
            $this->db->layout_location = $layout_location;
        }
        if ($category_id > 0) {
            $filters .= " AND sa.category_id = :category_id";
            $this->db->category_id = $category_id;
        }

        $base = "FROM " . DB_PREFIX . "scroll_artwork sa
			LEFT JOIN " . DB_PREFIX . "mundane m ON m.mundane_id = sa.uploader_mundane_id
			LEFT JOIN " . DB_PREFIX . "scroll_artwork_category c ON c.category_id = sa.category_id
			WHERE " . $vis . $filters;

        $sql = "SELECT sa.*, m.persona AS uploader_persona, c.label AS category_label
			" . $base . " ORDER BY sa.created_at DESC
			LIMIT " . (int)$per_page . " OFFSET " . (int)$offset;
        $r = $this->db->DataSet($sql);
        $artwork = array();
        while ($r->Next()) {
            $artwork[] = $this->format_artwork_row($r);
        }

        // Bound :layout_location/:category_id persist across the COUNT (no Clear between).
        $cr = $this->db->DataSet("SELECT COUNT(*) AS total " . $base);
        $total = ($cr->Size() > 0 && $cr->Next()) ? intval($cr->total) : 0;

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
    public function search($query, $layout_location = '', $page = 1, $per_page = 20, $opts = array())
    {
        $page = max(1, intval($page));
        $per_page = max(1, min(100, intval($per_page)));
        $offset = ($page - 1) * $per_page;

        $search_term = trim($query);
        if (strlen($search_term) === 0) {
            return $this->browse($layout_location, $page, $per_page, $opts);
        }
        $like_term = '%' . $search_term . '%';

        $viewer_kingdom_id = intval($opts['ViewerKingdomId'] ?? 0);
        $tier = $opts['Tier'] ?? 'all'; // all | global | kingdom | park
        $category_id = intval($opts['CategoryId'] ?? 0);

        $viewer_park_id = intval($opts['ViewerParkId'] ?? 0);

        // Visibility clause: approved global to everyone; approved kingdom/park only to that scope.
        $vis = "sa.status = 'approved' AND (sa.visibility = 'global'";
        if ($viewer_kingdom_id > 0) {
            $vis .= " OR (sa.visibility = 'kingdom' AND sa.owner_kingdom_id = " . (int)$viewer_kingdom_id . ")";
        }
        if ($viewer_park_id > 0) {
            $vis .= " OR (sa.visibility = 'park' AND sa.owner_park_id = " . (int)$viewer_park_id . ")";
        }
        $vis .= ")";
        if ($tier === 'global') {
            $vis = "sa.status = 'approved' AND sa.visibility = 'global'";
        }
        if ($tier === 'kingdom' && $viewer_kingdom_id > 0) {
            $vis = "sa.status = 'approved' AND sa.visibility = 'kingdom' AND sa.owner_kingdom_id = " . (int)$viewer_kingdom_id;
        }
        if ($tier === 'park' && $viewer_park_id > 0) {
            $vis = "sa.status = 'approved' AND sa.visibility = 'park' AND sa.owner_park_id = " . (int)$viewer_park_id;
        }

        $this->db->Clear();
        $filters = " AND (sa.name LIKE :q OR sa.tags LIKE :q)";
        $this->db->q = $like_term;
        $layout_location = trim($layout_location);
        if (strlen($layout_location) > 0 && in_array($layout_location, self::VALID_LOCATIONS)) {
            $filters .= " AND sa.layout_location = :layout_location";
            $this->db->layout_location = $layout_location;
        }
        if ($category_id > 0) {
            $filters .= " AND sa.category_id = :category_id";
            $this->db->category_id = $category_id;
        }

        $base = "FROM " . DB_PREFIX . "scroll_artwork sa
			LEFT JOIN " . DB_PREFIX . "mundane m ON m.mundane_id = sa.uploader_mundane_id
			LEFT JOIN " . DB_PREFIX . "scroll_artwork_category c ON c.category_id = sa.category_id
			WHERE " . $vis . $filters;

        $sql = "SELECT sa.*, m.persona AS uploader_persona, c.label AS category_label
			" . $base . " ORDER BY sa.created_at DESC
			LIMIT " . (int)$per_page . " OFFSET " . (int)$offset;
        $r = $this->db->DataSet($sql);
        $artwork = array();
        while ($r->Next()) {
            $artwork[] = $this->format_artwork_row($r);
        }

        $cr = $this->db->DataSet("SELECT COUNT(*) AS total " . $base);
        $total = ($cr->Size() > 0 && $cr->Next()) ? intval($cr->total) : 0;

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
    public function get_pending($page = 1, $per_page = 20, $opts = array())
    {
        $page = max(1, intval($page));
        $per_page = max(1, min(100, intval($per_page)));
        $offset = ($page - 1) * $per_page;
        $scope = $opts['Scope'] ?? 'global'; // 'global' | 'kingdom' | 'park'
        $kingdom_ids = $opts['KingdomIds'] ?? array(); // ints, for 'kingdom' scope
        $park_ids = $opts['ParkIds'] ?? array(); // ints, for 'park' scope

        if ($scope === 'kingdom') {
            $kingdom_ids = array_values(array_filter(array_map('intval', $kingdom_ids), function ($x) {
                return $x > 0;
            }));
            if (count($kingdom_ids) === 0) {
                return array('Artwork' => array(), 'Total' => 0, 'Page' => $page, 'PerPage' => $per_page, 'Status' => Success());
            }
            $where = "sa.status = 'pending' AND sa.visibility = 'kingdom' AND sa.owner_kingdom_id IN (" . implode(',', $kingdom_ids) . ")";
        } elseif ($scope === 'park') {
            $park_ids = array_values(array_filter(array_map('intval', $park_ids), function ($x) {
                return $x > 0;
            }));
            if (count($park_ids) === 0) {
                return array('Artwork' => array(), 'Total' => 0, 'Page' => $page, 'PerPage' => $per_page, 'Status' => Success());
            }
            $where = "sa.status = 'pending' AND sa.visibility = 'park' AND sa.owner_park_id IN (" . implode(',', $park_ids) . ")";
        } else {
            $where = "sa.status = 'pending' AND sa.visibility = 'global'";
        }

        $base = "FROM " . DB_PREFIX . "scroll_artwork sa
			LEFT JOIN " . DB_PREFIX . "mundane m ON m.mundane_id = sa.uploader_mundane_id
			LEFT JOIN " . DB_PREFIX . "scroll_artwork_category c ON c.category_id = sa.category_id
			WHERE " . $where;

        $this->db->Clear();
        $sql = "SELECT sa.*, m.persona AS uploader_persona, c.label AS category_label
			" . $base . " ORDER BY sa.created_at ASC
			LIMIT " . (int)$per_page . " OFFSET " . (int)$offset;
        $r = $this->db->DataSet($sql);
        $artwork = array();
        while ($r->Next()) {
            $artwork[] = $this->format_artwork_row($r);
        }
        $cr = $this->db->DataSet("SELECT COUNT(*) AS total " . $base);
        $total = ($cr->Size() > 0 && $cr->Next()) ? intval($cr->total) : 0;

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
    public function approve($request)
    {
        $mundane_id = Ork3::$Lib->authorization->IsAuthorized($request['Token']);
        if ($mundane_id <= 0) {
            return array('Status' => NoAuthorization());
        }

        $artwork_id = intval($request['ArtworkId']);
        if ($artwork_id <= 0) {
            return array('Status' => InvalidParameter(null, 'Invalid artwork ID.'));
        }

        // Load the row first (need visibility/owner_kingdom_id to authorize by tier).
        $this->db->Clear();
        $this->db->artwork_id = $artwork_id;
        $sql = "SELECT scroll_artwork_id, status, visibility, owner_kingdom_id, owner_park_id
			FROM " . DB_PREFIX . "scroll_artwork WHERE scroll_artwork_id = :artwork_id";
        $r = $this->db->DataSet($sql);
        if ($r->Size() <= 0 || !$r->Next()) {
            return array('Status' => InvalidParameter(null, 'Artwork not found.'));
        }
        $visibility = $r->visibility;
        $owner_kingdom_id = $r->owner_kingdom_id;
        $owner_park_id = $r->owner_park_id;
        $status = $r->status;

        if (!$this->can_moderate($mundane_id, $visibility, $owner_kingdom_id, $owner_park_id)) {
            return array('Status' => NoAuthorization());
        }
        if ($status !== 'pending') {
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
    public function reject($request)
    {
        $mundane_id = Ork3::$Lib->authorization->IsAuthorized($request['Token']);
        if ($mundane_id <= 0) {
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

        // Load the row first (need visibility/owner_kingdom_id to authorize by tier).
        $this->db->Clear();
        $this->db->artwork_id = $artwork_id;
        $sql = "SELECT scroll_artwork_id, status, visibility, owner_kingdom_id, owner_park_id
			FROM " . DB_PREFIX . "scroll_artwork WHERE scroll_artwork_id = :artwork_id";
        $r = $this->db->DataSet($sql);
        if ($r->Size() <= 0 || !$r->Next()) {
            return array('Status' => InvalidParameter(null, 'Artwork not found.'));
        }
        $visibility = $r->visibility;
        $owner_kingdom_id = $r->owner_kingdom_id;
        $owner_park_id = $r->owner_park_id;
        $status = $r->status;

        if (!$this->can_moderate($mundane_id, $visibility, $owner_kingdom_id, $owner_park_id)) {
            return array('Status' => NoAuthorization());
        }
        if ($status !== 'pending') {
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
    public function get_user_uploads($mundane_id, $page = 1, $per_page = 20, $status = '')
    {
        $mundane_id = intval($mundane_id);
        if ($mundane_id <= 0) {
            return array('Status' => InvalidParameter(null, 'Invalid user ID.'));
        }

        $page = max(1, intval($page));
        $per_page = max(1, min(100, intval($per_page)));
        $offset = ($page - 1) * $per_page;

        // Optional status filter (pending|approved|rejected); empty/invalid = no filter.
        $status_filter = in_array($status, array('pending', 'approved', 'rejected'), true) ? $status : '';
        $status_clause = ($status_filter !== '') ? " AND sa.status = :status" : "";

        // Get total count
        $this->db->Clear();
        $this->db->mundane_id = $mundane_id;
        if ($status_filter !== '') {
            $this->db->status = $status_filter;
        }
        $count_sql = "SELECT COUNT(*) as total FROM " . DB_PREFIX . "scroll_artwork sa WHERE sa.uploader_mundane_id = :mundane_id" . $status_clause;
        $cr = $this->db->DataSet($count_sql);
        $total = ($cr->Size() > 0 && $cr->Next()) ? intval($cr->total) : 0;

        // Get page of results
        $this->db->Clear();
        $this->db->mundane_id = $mundane_id;
        if ($status_filter !== '') {
            $this->db->status = $status_filter;
        }
        $sql = "SELECT sa.*, m.persona as uploader_persona
			FROM " . DB_PREFIX . "scroll_artwork sa
			LEFT JOIN " . DB_PREFIX . "mundane m ON m.mundane_id = sa.uploader_mundane_id
			WHERE sa.uploader_mundane_id = :mundane_id" . $status_clause . "
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
    public function delete($request)
    {
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
        $sql = "SELECT scroll_artwork_id, uploader_mundane_id, file_name, source_kind
			FROM " . DB_PREFIX . "scroll_artwork WHERE scroll_artwork_id = :artwork_id";
        $r = $this->db->DataSet($sql);

        if ($r->Size() <= 0 || !$r->Next()) {
            return array('Status' => InvalidParameter(null, 'Artwork not found.'));
        }

        // Built-in pack assets are Amtgard-wide and must not be hard-deleted.
        if (($r->source_kind ?? 'upload') === 'pack') {
            return array('Status' => InvalidParameter(null, 'Built-in assets cannot be deleted.'));
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
     * Generate a template guide PNG illustrating the four canonical artwork
     * placement zones on a portrait US-Letter page: Full Border, Side Border,
     * Floating Image, and Background.
     *
     * @return array Contains base64-encoded PNG image data
     */
    public function generate_template_guide()
    {
        // ============================================================
        //  Scroll Artwork Template Guide — four canonical zones
        //  Page at 2550x3300, canvas has a margin for annotations.
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
        $cPageBorder = imagecolorallocate($img, 160, 160, 160);
        $cBlack      = imagecolorallocate($img, 30, 30, 30);
        $cDarkGray   = imagecolorallocate($img, 80, 80, 80);
        $cMidGray    = imagecolorallocate($img, 140, 140, 140);
        $cWhite      = imagecolorallocate($img, 255, 255, 255);

        // Distinct per-zone colors (fill + outline)
        $zc = array(
            'background'   => array('fill' => imagecolorallocatealpha($img, 160, 160, 210, 110), 'line' => imagecolorallocate($img, 100, 100, 160)),
            'full_border'  => array('fill' => imagecolorallocatealpha($img, 180, 180, 180, 105), 'line' => imagecolorallocate($img, 120, 120, 120)),
            'border_side'  => array('fill' => imagecolorallocatealpha($img, 229, 57, 53, 80), 'line' => imagecolorallocate($img, 180, 40, 40)),
            'center_image' => array('fill' => imagecolorallocatealpha($img, 156, 39, 176, 70), 'line' => imagecolorallocate($img, 120, 30, 140)),
        );

        // Fill canvas background
        imagefilledrectangle($img, 0, 0, $canvas_w - 1, $canvas_h - 1, $cCanvas);

        // ---- BACKGROUND zone: subtle full-page fill behind everything ----
        $bgDim = self::SLOT_DIMENSIONS['background'];
        $bg_x1 = $margin + $bgDim['x'];
        $bg_y1 = $margin + $bgDim['y'];
        $bg_x2 = $bg_x1 + $bgDim['w'] - 1;
        $bg_y2 = $bg_y1 + $bgDim['h'] - 1;
        imagefilledrectangle($img, $bg_x1, $bg_y1, $bg_x2, $bg_y2, $zc['background']['fill']);

        // Page outline drawn over the background fill
        imagesetthickness($img, 3);
        imagerectangle($img, $margin, $margin, $margin + $page_w - 1, $margin + $page_h - 1, $cPageBorder);
        imagesetthickness($img, 1);

        // ---- FULL BORDER zone: rectangular frame around the page edge ----
        $fbDim = self::SLOT_DIMENSIONS['full_border'];
        $fb_x1 = $margin + $fbDim['x'];
        $fb_y1 = $margin + $fbDim['y'];
        $fb_x2 = $fb_x1 + $fbDim['w'] - 1;
        $fb_y2 = $fb_y1 + $fbDim['h'] - 1;
        imagesetthickness($img, 4);
        $this->draw_dashed_rect($img, $fb_x1 + 40, $fb_y1 + 40, $fb_x2 - 40, $fb_y2 - 40, $zc['full_border']['line'], 26, 14);
        imagesetthickness($img, 1);

        // ---- SIDE BORDER zone: a single vertical edge strip ----
        $sbDim = self::SLOT_DIMENSIONS['border_side'];
        $sb_x1 = $margin + $sbDim['x'];
        $sb_y1 = $margin + $sbDim['y'];
        $sb_x2 = $sb_x1 + $sbDim['w'] - 1;
        $sb_y2 = $sb_y1 + $sbDim['h'] - 1;
        for ($hx = $sb_x1; $hx <= $sb_x2; $hx += 8) {
            imageline($img, $hx, $sb_y1, $hx, $sb_y2, $zc['border_side']['fill']);
        }
        imagesetthickness($img, 3);
        imagerectangle($img, $sb_x1, $sb_y1, $sb_x2, $sb_y2, $zc['border_side']['line']);
        imagesetthickness($img, 1);

        // ---- FLOATING IMAGE zone: a box near the center ----
        $ciDim = self::SLOT_DIMENSIONS['center_image'];
        $ci_x1 = $margin + $ciDim['x'];
        $ci_y1 = $margin + $ciDim['y'];
        $ci_x2 = $ci_x1 + $ciDim['w'] - 1;
        $ci_y2 = $ci_y1 + $ciDim['h'] - 1;
        for ($d = -($ci_y2 - $ci_y1); $d <= ($ci_x2 - $ci_x1); $d += 12) {
            imageline($img, max($ci_x1, $ci_x1 + $d), max($ci_y1, $ci_y1 - $d), min($ci_x2, $ci_x1 + $d + ($ci_y2 - $ci_y1)), min($ci_y2, $ci_y1 - $d + ($ci_x2 - $ci_x1)), $zc['center_image']['fill']);
        }
        imagesetthickness($img, 4);
        imagerectangle($img, $ci_x1, $ci_y1, $ci_x2, $ci_y2, $zc['center_image']['line']);
        imagesetthickness($img, 1);

        if (!$useTTF) {
            // Fallback with built-in bitmap fonts
            $title = 'SCROLL ARTWORK TEMPLATE GUIDE (2550x3300 @ 300 DPI)';
            imagestring($img, 5, intval(($canvas_w - strlen($title) * imagefontwidth(5)) / 2), 10, $title, $cBlack);
            imagestring($img, 5, $margin + 60, $margin + 60, 'FULL BORDER  2550 x 3300', $zc['full_border']['line']);
            imagestring($img, 5, $sb_x1 + 8, $margin + 700, 'SIDE BORDER  300 x 3300', $zc['border_side']['line']);
            imagestring($img, 5, $ci_x1 + 20, $ci_y1 + 20, 'FLOATING IMAGE  1200 x 1200', $zc['center_image']['line']);
            imagestring($img, 4, $ci_x1 + 20, $ci_y1 + 44, 'Can be placed anywhere on the scroll.', $cDarkGray);
            imagestring($img, 5, $margin + 60, $margin + $page_h - 90, 'BACKGROUND  2550 x 3300  (full page)', $zc['background']['line']);
            ob_start();
            imagepng($img);
            $png_data = ob_get_clean();
            imagedestroy($img);
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
        $sub = 'Print Resolution: 2550 x 3300 px  |  300 DPI  |  8.5" x 11" Letter (Portrait)';
        $sBox = imagettfbbox(24, 0, $fontBody, $sub);
        $sW = $sBox[2] - $sBox[0];
        imagettftext($img, 24, 0, intval(($canvas_w - $sW) / 2), 102, $cDarkGray, $fontBody, $sub);

        // ---- Boxed labels for the full-page / floating zones ----
        // Each entry: [name, dimension text, offset_x from page, offset_y from page]
        $labels = array(
            'background'   => array('BACKGROUND',     '2550 x 3300  |  Full page, opacity-adjustable', 560, 260),
            'full_border'  => array('FULL BORDER',    '2550 x 3300  |  Rectangular frame',             1780, 260),
            'center_image' => array('FLOATING IMAGE', '1200 x 1200',                                   intval($page_w / 2), 1620),
        );

        foreach ($labels as $zone => $lbl) {
            $lx = $margin + $lbl[2];
            $ly = $margin + $lbl[3];
            $nameSize = 32;
            $dimSize = 22;

            $nBox = imagettfbbox($nameSize, 0, $fontBold, $lbl[0]);
            $nW = $nBox[2] - $nBox[0];
            $dBox = imagettfbbox($dimSize, 0, $fontBody, $lbl[1]);
            $dW = $dBox[2] - $dBox[0];
            $boxW = max($nW, $dW) + 30;
            $boxH = $nameSize + $dimSize + 28;

            $lbx1 = $lx - intval($boxW / 2);
            $lby1 = $ly - intval($boxH / 2);
            $lbx2 = $lbx1 + $boxW;
            $lby2 = $lby1 + $boxH;

            // White background box with colored border
            imagefilledrectangle($img, $lbx1, $lby1, $lbx2, $lby2, $cWhite);
            imagesetthickness($img, 2);
            imagerectangle($img, $lbx1, $lby1, $lbx2, $lby2, $zc[$zone]['line']);
            imagesetthickness($img, 1);

            // Zone name
            imagettftext($img, $nameSize, 0, $lx - intval($nW / 2), $lby1 + $nameSize + 8, $zc[$zone]['line'], $fontBold, $lbl[0]);
            // Dimensions
            imagettftext($img, $dimSize, 0, $lx - intval($dW / 2), $lby2 - 8, $cDarkGray, $fontBody, $lbl[1]);

            // Extra guidance beneath the Floating Image box
            if ($zone === 'center_image') {
                $guide = 'Can be placed anywhere on the scroll.';
                $gBox = imagettfbbox($dimSize, 0, $fontBody, $guide);
                $gW = $gBox[2] - $gBox[0];
                imagettftext($img, $dimSize, 0, $lx - intval($gW / 2), $lby2 + $dimSize + 12, $cMidGray, $fontBody, $guide);
            }
        }

        // ---- SIDE BORDER label (vertical text along the strip) ----
        imagettftext($img, 30, 90, $sb_x1 + 190, $margin + 1980, $zc['border_side']['line'], $fontBold, 'SIDE BORDER');
        imagettftext($img, 20, 90, $sb_x1 + 245, $margin + 1980, $zc['border_side']['line'], $fontBody, '300 x 3300  |  Edge strip');

        // ---- Output ----
        ob_start();
        imagepng($img);
        $png_data = ob_get_clean();
        imagedestroy($img);

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
    private function draw_dashed_rect($img, $x1, $y1, $x2, $y2, $color, $dash_len = 10, $gap_len = 5)
    {
        $this->draw_dashed_line($img, $x1, $y1, $x2, $y1, $color, $dash_len, $gap_len); // top
        $this->draw_dashed_line($img, $x1, $y2, $x2, $y2, $color, $dash_len, $gap_len); // bottom
        $this->draw_dashed_line($img, $x1, $y1, $x1, $y2, $color, $dash_len, $gap_len); // left
        $this->draw_dashed_line($img, $x2, $y1, $x2, $y2, $color, $dash_len, $gap_len); // right
    }

    /**
     * Draw a dashed line (horizontal or vertical).
     */
    private function draw_dashed_line($img, $x1, $y1, $x2, $y2, $color, $dash_len, $gap_len)
    {
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
    private function draw_z_badge($img, $x, $y, $label, $bgColor, $textColor, $font)
    {
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
    private function draw_dimension_line($img, $x1, $y1, $x2, $y2, $color, $horizontal = true)
    {
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

    // ---- Categories (admin-managed thematic taxonomy) ----

    /**
     * List thematic categories.
     *
     * @param bool $active_only  When true, only return active categories.
     * @return array Categories list with Status.
     */
    public function list_categories($active_only = true)
    {
        $this->db->Clear();
        $where = $active_only ? "WHERE active = 1" : "";
        $sql = "SELECT category_id, slug, label, sort_order, active
			FROM " . DB_PREFIX . "scroll_artwork_category
			" . $where . "
			ORDER BY sort_order ASC, label ASC";
        $r = $this->db->DataSet($sql);
        $cats = array();
        while ($r->Next()) {
            $cats[] = array(
                'CategoryId' => intval($r->category_id),
                'Slug'       => $r->slug,
                'Label'      => $r->label,
                'SortOrder'  => intval($r->sort_order),
                'Active'     => intval($r->active),
            );
        }
        return array('Categories' => $cats, 'Status' => Success());
    }

    /**
     * Create or update a thematic category. Requires ORK admin authority.
     *
     * @param array $request Keys: Token, CategoryId (0=new), Label, SortOrder, Active
     * @return array Status response with CategoryId (and Slug on create).
     */
    public function save_category($request)
    {
        $mundane_id = Ork3::$Lib->authorization->IsAuthorized($request['Token']);
        if ($mundane_id <= 0 || !Ork3::$Lib->authorization->HasAuthority($mundane_id, AUTH_ADMIN, 0, AUTH_EDIT)) {
            $this->db->Clear();
            return array('Status' => NoAuthorization());
        }
        $this->db->Clear(); // clear stale bindings from HasAuthority

        $label = trim($request['Label'] ?? '');
        if (strlen($label) === 0 || strlen($label) > 120) {
            return array('Status' => InvalidParameter(null, 'Label is required (max 120 chars).'));
        }
        $sort_order = intval($request['SortOrder'] ?? 0);
        $active = !empty($request['Active']) ? 1 : 0;
        $category_id = intval($request['CategoryId'] ?? 0);

        if ($category_id > 0) {
            $this->db->Clear();
            $this->db->label = $label;
            $this->db->sort_order = $sort_order;
            $this->db->active = $active;
            $this->db->category_id = $category_id;
            $sql = "UPDATE " . DB_PREFIX . "scroll_artwork_category
				SET label = :label, sort_order = :sort_order, active = :active
				WHERE category_id = :category_id";
            $this->db->Execute($sql);
            return array('CategoryId' => $category_id, 'Status' => Success());
        }

        // New: derive a slug from the label, ensure uniqueness.
        $base_slug = preg_replace('/[^a-z0-9]+/', '_', strtolower($label));
        $base_slug = trim($base_slug, '_');
        if ($base_slug === '') {
            $base_slug = 'category';
        }
        $slug = $base_slug;
        $n = 2;
        while (true) {
            $this->db->Clear();
            $this->db->slug = $slug;
            $chk = $this->db->DataSet("SELECT category_id FROM " . DB_PREFIX . "scroll_artwork_category WHERE slug = :slug");
            if ($chk->Size() <= 0) {
                break;
            }
            $slug = $base_slug . '_' . $n;
            $n++;
        }

        $this->db->Clear();
        $this->db->slug = $slug;
        $this->db->label = $label;
        $this->db->sort_order = $sort_order;
        $this->db->active = $active;
        $sql = "INSERT INTO " . DB_PREFIX . "scroll_artwork_category (slug, label, sort_order, active)
			VALUES (:slug, :label, :sort_order, :active)";
        $this->db->Execute($sql);
        return array('CategoryId' => $this->db->GetLastInsertId(), 'Slug' => $slug, 'Status' => Success());
    }

    /**
     * Determine whether a moderator may act on a row given its tier.
     * ORK admins moderate global rows; AUTH_KINGDOM officers moderate their
     * kingdom's rows; AUTH_PARK officers moderate their park's rows. Clears
     * stale auth-ORM bindings before returning.
     *
     * @param int    $mundane_id
     * @param string $visibility        'global' | 'kingdom' | 'park'
     * @param int    $owner_kingdom_id
     * @param int    $owner_park_id
     * @return bool
     */
    private function can_moderate($mundane_id, $visibility, $owner_kingdom_id, $owner_park_id = 0)
    {
        if (Ork3::$Lib->authorization->HasAuthority($mundane_id, AUTH_ADMIN, 0, AUTH_EDIT)) {
            $this->db->Clear();
            return true;
        }
        if ($visibility === 'kingdom' && intval($owner_kingdom_id) > 0
            && Ork3::$Lib->authorization->HasAuthority($mundane_id, AUTH_KINGDOM, intval($owner_kingdom_id), AUTH_EDIT)) {
            $this->db->Clear();
            return true;
        }
        if ($visibility === 'park' && intval($owner_park_id) > 0
            && Ork3::$Lib->authorization->HasAuthority($mundane_id, AUTH_PARK, intval($owner_park_id), AUTH_EDIT)) {
            $this->db->Clear();
            return true;
        }
        $this->db->Clear();
        return false;
    }

    /**
     * Format a result set row into a standardized artwork array.
     *
     * @param YapoResultSet $r  Result set positioned at current row
     * @return array Formatted artwork record
     */
    private function format_artwork_row($r)
    {
        // Pack (built-in) rows are served from the packs asset tree; uploads from
        // the artwork upload dir. HTTP_ASSETS ends in '/assets/' in every env.
        $source_kind = isset($r->source_kind) ? $r->source_kind : 'upload';
        if ($source_kind === 'pack') {
            $pack_base = str_replace('/assets/', '/system/assets/scroll/packs/', HTTP_ASSETS);
            $url = $pack_base . $r->file_name;
        } else {
            $url = HTTP_SCROLL_ARTWORK . $r->file_name;
        }
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
            'Url' => $url,
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
            'Visibility' => isset($r->visibility) ? $r->visibility : 'global',
            'OwnerKingdomId' => (isset($r->owner_kingdom_id) && $r->owner_kingdom_id) ? intval($r->owner_kingdom_id) : null,
            'OwnerParkId' => (isset($r->owner_park_id) && $r->owner_park_id) ? intval($r->owner_park_id) : null,
            'SourceKind' => $source_kind,
            'SystemOwned' => (isset($r->system_owned) && $r->system_owned) ? 1 : 0,
            'CategoryId' => (isset($r->category_id) && $r->category_id) ? intval($r->category_id) : null,
            'CategoryLabel' => isset($r->category_label) ? $r->category_label : null,
            'SlotDimensions' => self::SLOT_DIMENSIONS[$r->layout_location] ?? null,
        );
    }

    /**
     * Edit an existing artwork row's metadata (and, for user rows, its scope).
     *
     * Gates on can_moderate for the CURRENT scope. If the request changes the
     * scope (visibility/owner), it also requires authority on the TARGET scope.
     * Pack (built-in) rows: name/description/tags/category_id/layout_location are
     * editable; file_name/status are NOT, and the scope stays global/admin-only.
     *
     * @param array $request Keys: Token, ArtworkId, Name, Description, Tags,
     *   CategoryId, LayoutLocation, Visibility, OwnerKingdomId, OwnerParkId
     * @return array Status response
     */
    public function update_metadata($request)
    {
        $mundane_id = Ork3::$Lib->authorization->IsAuthorized($request['Token'] ?? '');
        if ($mundane_id <= 0) {
            return array('Status' => NoAuthorization());
        }
        $artwork_id = intval($request['ArtworkId'] ?? 0);
        if ($artwork_id <= 0) {
            return array('Status' => InvalidParameter(null, 'Invalid artwork ID.'));
        }

        // Load the current row (scope needed to authorize).
        $this->db->Clear();
        $this->db->artwork_id = $artwork_id;
        $sql = "SELECT scroll_artwork_id, source_kind, visibility, owner_kingdom_id, owner_park_id
            FROM " . DB_PREFIX . "scroll_artwork WHERE scroll_artwork_id = :artwork_id";
        $r = $this->db->DataSet($sql);
        if ($r->Size() <= 0 || !$r->Next()) {
            return array('Status' => InvalidParameter(null, 'Artwork not found.'));
        }
        $source_kind = $r->source_kind ?? 'upload';
        $cur_vis = $r->visibility;
        $cur_kid = intval($r->owner_kingdom_id);
        $cur_pid = intval($r->owner_park_id);

        // Authorize on the CURRENT scope.
        if (!$this->can_moderate($mundane_id, $cur_vis, $cur_kid, $cur_pid)) {
            return array('Status' => NoAuthorization());
        }

        // Validate the common metadata fields.
        $name = trim($request['Name'] ?? '');
        if (strlen($name) === 0) {
            return array('Status' => InvalidParameter(null, 'Name is required.'));
        }
        if (strlen($name) > 150) {
            return array('Status' => InvalidParameter(null, 'Name must be 150 characters or fewer.'));
        }
        $description = trim($request['Description'] ?? '');
        if (strlen($description) > 65535) {
            $description = substr($description, 0, 65535);
        }
        $tags = trim($request['Tags'] ?? '');
        if (strlen($tags) > 500) {
            $tags = substr($tags, 0, 500);
        }
        $layout_location = trim($request['LayoutLocation'] ?? '');
        if (!in_array($layout_location, self::VALID_LOCATIONS, true)) {
            return array('Status' => InvalidParameter(null, 'Invalid layout location.'));
        }

        // Category (optional; must be an active category or it is cleared).
        $category_id = intval($request['CategoryId'] ?? 0);
        if ($category_id > 0) {
            $this->db->Clear();
            $this->db->category_id = $category_id;
            $cchk = $this->db->DataSet("SELECT category_id FROM " . DB_PREFIX . "scroll_artwork_category WHERE category_id = :category_id AND active = 1");
            if ($cchk->Size() <= 0) {
                $category_id = 0;
            }
        }

        // Derive the TARGET scope. Pack rows stay global (admin-only, no re-scope).
        if ($source_kind === 'pack') {
            $vis = 'global';
            $new_kid = 0;
            $new_pid = 0;
        } else {
            $vis = in_array($request['Visibility'] ?? $cur_vis, array('global', 'kingdom', 'park'), true)
                ? $request['Visibility'] : $cur_vis;
            $new_kid = intval($request['OwnerKingdomId'] ?? 0);
            $new_pid = intval($request['OwnerParkId'] ?? 0);
            if ($vis === 'global') {
                $new_kid = 0;
                $new_pid = 0;
            } elseif ($vis === 'kingdom') {
                if ($new_kid <= 0) {
                    return array('Status' => InvalidParameter(null, 'Kingdom-specific artwork requires a kingdom.'));
                }
                $new_pid = 0;
            } else { // park
                if ($new_pid <= 0 || $new_kid <= 0) {
                    return array('Status' => InvalidParameter(null, 'Park-specific artwork requires a park and its kingdom.'));
                }
            }
            // Re-scope: require authority on the TARGET scope too.
            $rescoped = ($vis !== $cur_vis || $new_kid !== $cur_kid || $new_pid !== $cur_pid);
            if ($rescoped && !$this->can_moderate($mundane_id, $vis, $new_kid, $new_pid)) {
                return array('Status' => NoAuthorization());
            }
        }

        // Persist. Interpolate literal NULL for unused owner/category columns
        // (yapo drops null-bound params, so a bound NULL would leave the old
        // value in place). All interpolated values are (int)-cast and safe.
        $kid_sql = $new_kid > 0 ? (int)$new_kid : 'NULL';
        $pid_sql = $new_pid > 0 ? (int)$new_pid : 'NULL';
        $cat_sql = $category_id > 0 ? (int)$category_id : 'NULL';
        $this->db->Clear();
        $this->db->name = $name;
        $this->db->description = $description;
        $this->db->tags = $tags;
        $this->db->layout_location = $layout_location;
        $this->db->visibility = $vis;
        $this->db->artwork_id = $artwork_id;
        $sql = "UPDATE " . DB_PREFIX . "scroll_artwork SET
            name = :name, description = :description, tags = :tags,
            layout_location = :layout_location, visibility = :visibility,
            owner_kingdom_id = " . $kid_sql . ", owner_park_id = " . $pid_sql . ",
            category_id = " . $cat_sql . "
            WHERE scroll_artwork_id = :artwork_id";
        $this->db->Execute($sql);

        return array('Status' => Success(), 'ArtworkId' => $artwork_id);
    }

    /**
     * All statuses (pending+approved+rejected) for exactly one tier, for the
     * management tool:
     *   'global'  -> visibility='global'
     *   'kingdom' -> visibility='kingdom' AND owner_kingdom_id=:kid
     *   'park'    -> visibility='park'    AND owner_park_id=:pid
     * Pending rows first, then newest.
     *
     * @return array {Artwork:[...], Status}
     */
    public function list_for_scope($tier, $kingdomId, $parkId)
    {
        $tier = in_array($tier, array('global', 'kingdom', 'park'), true) ? $tier : 'global';
        $this->db->Clear();
        if ($tier === 'kingdom') {
            $kid = (int)$kingdomId;
            if ($kid <= 0) {
                return array('Artwork' => array(), 'Status' => Success());
            }
            $this->db->owner_kingdom_id = $kid;
            $where = "sa.visibility = 'kingdom' AND sa.owner_kingdom_id = :owner_kingdom_id";
        } elseif ($tier === 'park') {
            $pid = (int)$parkId;
            if ($pid <= 0) {
                return array('Artwork' => array(), 'Status' => Success());
            }
            $this->db->owner_park_id = $pid;
            $where = "sa.visibility = 'park' AND sa.owner_park_id = :owner_park_id";
        } else {
            $where = "sa.visibility = 'global'";
        }
        $sql = "SELECT sa.*, m.persona AS uploader_persona, c.label AS category_label
            FROM " . DB_PREFIX . "scroll_artwork sa
            LEFT JOIN " . DB_PREFIX . "mundane m ON m.mundane_id = sa.uploader_mundane_id
            LEFT JOIN " . DB_PREFIX . "scroll_artwork_category c ON c.category_id = sa.category_id
            WHERE " . $where . "
            ORDER BY (sa.status = 'pending') DESC, sa.created_at DESC";
        $r = $this->db->DataSet($sql);
        $out = array();
        while ($r->Next()) {
            $out[] = $this->format_artwork_row($r);
        }
        return array('Artwork' => $out, 'Status' => Success());
    }

}
