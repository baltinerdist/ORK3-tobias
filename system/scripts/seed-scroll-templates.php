<?php

/**
 * seed-scroll-templates.php — starter templates + built-in pack artwork rows.
 *
 * Seeds:
 *   1. system_owned=1 ork_scroll_artwork rows for every entry in
 *      system/assets/scroll/packs/catalog.json (so the built-in packs are
 *      browsable in the artwork library). Idempotent: skips a pack whose
 *      file_name already exists as a system_owned row.
 *   2. Three shared starter templates (is_starter=1, kingdom_id NULL).
 *      Idempotent: deletes any starter of the same name, then re-creates it.
 *
 * Run inside the app container:
 *   docker exec -w /var/www/ork.amtgard.com ork3-php8-app php system/scripts/seed-scroll-templates.php
 */

// Bootstrap the ORK runtime so $DB + Ork3::$Lib are available (CLI-safe).
// Mirrors tests/scroll/test_moderation_authority.php.
chdir(__DIR__ . '/../../orkui');
if (!isset($_SERVER['HTTP_HOST'])) {
    $_SERVER['HTTP_HOST'] = 'localhost';
}
putenv('ENVIRONMENT=DEV');
require_once __DIR__ . '/../../startup.php';

// Packs live under system/, NOT the repo-root assets/ tree (there is no
// DIR_SCROLL_PACKS constant). catalog.json is read for row seeding only.
$packDir = __DIR__ . '/../assets/scroll/packs/';
$catalog = json_decode(file_get_contents($packDir . 'catalog.json'), true) ?: array();

global $DB;
$db = $DB;
$st = Ork3::$Lib->scrolltemplate;

// --- 1) built-in pack rows (system_owned=1); map catalog slot -> layout_location ---
$slotToLoc = array(
    'full_border'  => 'full_border',
    'border_side'  => 'border_left',
    'bg_image'     => 'watermark',
    'center_image' => 'center_image',
    'shield'       => 'top_graphic',
);
$packInserted = 0;
$packSkipped = 0;
foreach ($catalog as $a) {
    $loc = $slotToLoc[$a['slot'] ?? ''] ?? 'center_image';

    $db->Clear();
    $db->file_name = $a['file'];
    $exists = $db->DataSet("SELECT scroll_artwork_id FROM " . DB_PREFIX . "scroll_artwork WHERE file_name = :file_name AND system_owned = 1");
    if ($exists->Size() > 0) {
        $packSkipped++;
        continue;
    }

    $db->Clear();
    $db->uploader_mundane_id  = 0;
    $db->name                 = $a['name'] ?? basename($a['file']);
    $db->description          = '';
    $db->tags                 = implode(',', $a['tags'] ?? array());
    $db->layout_location      = $loc;
    $db->file_name            = $a['file'];
    $db->original_file_name   = basename($a['file']);
    $db->width                = (int)($a['width'] ?? 0);
    $db->height               = (int)($a['height'] ?? 0);
    $db->file_size            = 0;
    $db->license_signer_name  = 'Alona of Two Trees';
    $db->license_signed_at    = date('Y-m-d H:i:s');
    $db->status               = 'approved';
    $db->system_owned         = 1;
    $db->source_attribution   = $a['source'] ?? 'Alona of Two Trees';
    $db->source_license       = $a['license'] ?? 'CC';
    $cols = array(
        'uploader_mundane_id', 'name', 'description', 'tags', 'layout_location',
        'file_name', 'original_file_name', 'width', 'height', 'file_size',
        'license_signer_name', 'license_signed_at', 'status', 'system_owned',
        'source_attribution', 'source_license',
    );
    $ph = array_map(function ($c) {
        return ':' . $c;
    }, $cols);
    $db->Execute("INSERT INTO " . DB_PREFIX . "scroll_artwork (" . implode(', ', $cols) . ") VALUES (" . implode(', ', $ph) . ")");
    $packInserted++;
}

// --- 2) starter templates (delete existing starters by name, re-insert) ---
function sc_slot($loc, $x, $y, $w, $h, $type, $ref)
{
    return array('location' => $loc, 'x' => $x, 'y' => $y, 'w' => $w, 'h' => $h, 'source_type' => $type, 'source_ref' => $ref, 'fit' => 'contain');
}
function sc_zone($k, $l, $t, $f, $s, $mn, $mx, $al, $x, $y, $w, $h)
{
    return array('key' => $k, 'label' => $l, 'text' => $t, 'font' => $f, 'size' => $s, 'min' => $mn, 'max' => $mx, 'align' => $al, 'color' => '#1a1a1a', 'inherit_color' => false, 'x' => $x, 'y' => $y, 'w' => $w, 'h' => $h, 'autoscale' => true);
}

$starters = array(
    array('Illuminated Border (Portrait)', 'portrait', 'color', '#fdfcf7',
        array(sc_slot('full_border', 2, 2, 96, 96, 'pack', 'borders/scroll_border.png')),
        array(
            sc_zone('salutation', 'Salutation', 'Amtgard and {Kingdom} present', 'EB Garamond', 22, 14, 26, 'center', 14, 12, 72, 8),
            sc_zone('recipient', 'Recipient', '{PlayerName}', 'Cinzel', 54, 28, 60, 'center', 10, 22, 80, 12),
            sc_zone('award', 'Award', '{AwardName}', 'Cinzel Decorative', 40, 22, 48, 'center', 12, 38, 76, 10),
            sc_zone('body', 'Body', 'for {Reason}', 'EB Garamond', 24, 12, 28, 'center', 16, 52, 68, 18),
            sc_zone('date', 'Date', 'Done this {Date}', 'EB Garamond', 18, 12, 22, 'center', 16, 74, 68, 8),
            sc_zone('signature', 'Signature', '{GivenBy}', 'Great Vibes', 30, 16, 36, 'center', 20, 84, 60, 8),
        )),
    array('Rose Trellis (Portrait)', 'portrait', 'texture', 'brown_tea_stained.png',
        array(sc_slot('full_border', 1, 1, 98, 98, 'pack', 'borders/rose_border.png')),
        array(
            sc_zone('recipient', 'Recipient', '{PlayerName}', 'Almendra', 52, 28, 58, 'center', 12, 24, 76, 12),
            sc_zone('award', 'Award', '{AwardName}', 'MedievalSharp', 40, 22, 46, 'center', 14, 40, 72, 10),
            sc_zone('body', 'Body', 'for {Reason}', 'EB Garamond', 22, 12, 26, 'center', 18, 54, 64, 16),
            sc_zone('date', 'Date', 'the {Date}', 'EB Garamond', 18, 12, 22, 'left', 14, 80, 40, 10),
        )),
    array('Corner Shields (Landscape)', 'landscape', 'color', '#ffffff',
        array(
            sc_slot('top_graphic', 3, 4, 16, 22, 'heraldry', 'kingdom'),
            sc_slot('top_graphic', 81, 4, 16, 22, 'heraldry', 'park'),
            sc_slot('center_image', 35, 55, 30, 40, 'pack', 'orders/dragon/gold_dragon.png'),
        ),
        array(
            sc_zone('body', 'Body', 'In recognition of your service, you, {PlayerName}, shall forever be known as', 'EB Garamond', 22, 12, 26, 'center', 20, 10, 60, 14),
            sc_zone('award', 'Award', '{AwardName}', 'Cinzel', 34, 20, 40, 'center', 25, 26, 50, 10),
            sc_zone('date', 'Date', 'Done this {Date}', 'EB Garamond', 18, 12, 22, 'center', 25, 40, 50, 8),
        )),
);
foreach ($starters as $s) {
    $db->Clear();
    $db->name = $s[0];
    $db->Execute("DELETE FROM " . DB_PREFIX . "scroll_template WHERE is_starter = 1 AND name = :name");
    $st->create(array(
        'KingdomId'   => null,
        'Name'        => $s[0],
        'Orientation' => $s[1],
        'BgType'      => $s[2],
        'BgValue'     => $s[3],
        'Slots'       => $s[4],
        'Zones'       => $s[5],
        'IsStarter'   => 1,
        'CreatedBy'   => 0,
    ));
}

echo "seeded pack rows: " . $packInserted . " inserted, " . $packSkipped . " skipped (" . count($catalog) . " in catalog); starters: " . count($starters) . "\n";
