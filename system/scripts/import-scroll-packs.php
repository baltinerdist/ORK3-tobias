<?php

/**
 * import-scroll-packs.php — import the built-in art-pack catalog into the
 * uploaded-artwork library (ork_scroll_artwork) as Amtgard-wide (global) rows.
 *
 * Each catalog entry becomes one source_kind='pack' row (system_owned=1,
 * status='approved', visibility='global'). Idempotent:
 *
 *   - A row with source_kind='pack' AND file_name=<item.file> already exists
 *     -> skip.
 *   - A legacy system_owned=1 row with that file_name exists (seeded by the old
 *     seed-scroll-templates.php path, source_kind defaulted to 'upload' by the
 *     park-scope migration) -> ADOPT it: flip source_kind to 'pack' and refresh
 *     metadata. Counts as imported (migrated), no duplicate created.
 *   - Otherwise -> INSERT a fresh pack row.
 *
 * Run inside the app container:
 *   docker exec -w /var/www/ork.amtgard.com ork3-php8-app php system/scripts/import-scroll-packs.php
 */

// Bootstrap the ORK runtime so $DB + Ork3::$Lib are available (CLI-safe).
// Mirrors seed-scroll-templates.php.
chdir(__DIR__ . '/../../orkui');
if (!isset($_SERVER['HTTP_HOST'])) {
    $_SERVER['HTTP_HOST'] = 'localhost';
}
putenv('ENVIRONMENT=DEV');
require_once __DIR__ . '/../../startup.php';

$catalogPath = DIR_SYSTEM . 'assets/scroll/packs/catalog.json';
$catalog = json_decode(file_get_contents($catalogPath), true) ?: array();

// Map catalog slot -> ork_scroll_artwork.layout_location ENUM.
$slotToLoc = array(
    'full_border'  => 'full_border',
    'border_side'  => 'border_side',
    'center_image' => 'center_image',
    'bg_image'     => 'background',
);

global $DB;
$db = $DB;

$inserted = 0;
$migrated = 0;
$skipped = 0;

foreach ($catalog as $a) {
    $file = $a['file'] ?? '';
    if ($file === '') {
        continue;
    }
    $loc = $slotToLoc[$a['slot'] ?? ''] ?? 'center_image';
    $name = $a['name'] ?? basename($file);
    $tags = implode(',', $a['tags'] ?? array());
    $width = (int)($a['width'] ?? 0);
    $height = (int)($a['height'] ?? 0);
    $source = $a['source'] ?? 'Alona of Two Trees';
    $license = $a['license'] ?? 'CC';
    $now = date('Y-m-d H:i:s');

    // (1) already a pack row for this file? -> skip (idempotency key).
    $db->Clear();
    $db->file_name = $file;
    $existsPack = $db->DataSet("SELECT scroll_artwork_id FROM " . DB_PREFIX . "scroll_artwork
        WHERE source_kind = 'pack' AND file_name = :file_name");
    if ($existsPack->Size() > 0) {
        $skipped++;
        continue;
    }

    // (2) legacy system_owned row for this file? -> adopt (migrate) it.
    $db->Clear();
    $db->file_name = $file;
    $legacy = $db->DataSet("SELECT scroll_artwork_id FROM " . DB_PREFIX . "scroll_artwork
        WHERE system_owned = 1 AND file_name = :file_name");
    if ($legacy->Size() > 0 && $legacy->Next()) {
        $id = (int)$legacy->scroll_artwork_id;
        $db->Clear();
        $db->id = $id;
        $db->name = $name;
        $db->tags = $tags;
        $db->layout_location = $loc;
        $db->original_file_name = basename($file);
        $db->width = $width;
        $db->height = $height;
        $db->license_signer_name = $source;
        $db->source_attribution = $source;
        $db->source_license = $license;
        $db->Execute("UPDATE " . DB_PREFIX . "scroll_artwork SET
            source_kind = 'pack', system_owned = 1, status = 'approved',
            visibility = 'global', owner_kingdom_id = NULL, owner_park_id = NULL,
            name = :name, tags = :tags, layout_location = :layout_location,
            original_file_name = :original_file_name, width = :width, height = :height,
            license_signer_name = :license_signer_name, source_attribution = :source_attribution,
            source_license = :source_license
            WHERE scroll_artwork_id = :id");
        $migrated++;
        continue;
    }

    // (3) fresh insert.
    $db->Clear();
    $db->uploader_mundane_id  = 0;
    $db->name                 = $name;
    $db->description          = '';
    $db->tags                 = $tags;
    $db->layout_location      = $loc;
    $db->file_name            = $file;
    $db->original_file_name   = basename($file);
    $db->width                = $width;
    $db->height               = $height;
    $db->file_size            = 0;
    $db->license_signer_name  = $source;
    $db->license_signed_at    = $now;
    $db->status               = 'approved';
    $db->visibility           = 'global';
    $db->system_owned         = 1;
    $db->source_kind          = 'pack';
    $db->source_attribution   = $source;
    $db->source_license       = $license;
    $db->created_at           = $now;
    $cols = array(
        'uploader_mundane_id', 'name', 'description', 'tags', 'layout_location',
        'file_name', 'original_file_name', 'width', 'height', 'file_size',
        'license_signer_name', 'license_signed_at', 'status', 'visibility',
        'system_owned', 'source_kind', 'source_attribution', 'source_license', 'created_at',
    );
    $ph = array_map(function ($c) {
        return ':' . $c;
    }, $cols);
    $db->Execute("INSERT INTO " . DB_PREFIX . "scroll_artwork (" . implode(', ', $cols) . ")
        VALUES (" . implode(', ', $ph) . ")");
    $inserted++;
}

echo "import-scroll-packs: imported " . ($inserted + $migrated)
    . " (" . $inserted . " inserted, " . $migrated . " migrated from legacy system_owned), "
    . "skipped " . $skipped . " (already pack); "
    . count($catalog) . " catalog entries.\n";
