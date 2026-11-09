<?php
/**
 * Scroll Graphic Submissions — upload() tier/category persistence +
 * visibility-aware browse().
 *
 * The upload assertions require a valid logged-in session token (TEST_TOKEN);
 * when none is supplied (the common case in this harness) they SKIP with a
 * notice. The real round-trip is exercised via curl in a later unit (EU3).
 */
require_once __DIR__ . '/lib/assert.php';

// Bootstrap the ORK runtime so $DB + Ork3::$Lib are available (CLI-safe).
chdir(__DIR__ . '/../../orkui');
if (!isset($_SERVER['HTTP_HOST'])) {
    $_SERVER['HTTP_HOST'] = 'localhost';
}
putenv('ENVIRONMENT=DEV');
require_once __DIR__ . '/../../startup.php';

$sa = Ork3::$Lib->scrollartwork;

$token = getenv('TEST_TOKEN');
if (!$token) {
    echo "  ~ SKIP: TEST_TOKEN not set — upload/browse tier round-trip deferred to curl (EU3).\n";
    echo "test_submission_tiers OK (skipped token-dependent assertions)\n";
    exit(0);
}

// A 1x1 transparent PNG, base64 (no data: prefix).
$png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

$res = $sa->upload(array(
    'Token' => $token, 'Name' => 'Test Kingdom Border', 'LayoutLocation' => 'border_left',
    'LicenseSignerName' => 'Test User', 'Image' => $png, 'ImageMimeType' => 'image/png',
    'Visibility' => 'kingdom', 'OwnerKingdomId' => 1, 'CategoryId' => 1,
));
assert_true(isset($res['ArtworkId']) && $res['ArtworkId'] > 0, 'upload returned ArtworkId');

$got = $sa->get($res['ArtworkId']);
assert_equals('kingdom', $got['Artwork']['Visibility'], 'visibility stored');
assert_equals(1, intval($got['Artwork']['OwnerKingdomId']), 'owner_kingdom_id stored');
assert_equals(1, intval($got['Artwork']['CategoryId']), 'category_id stored');

// Approve it so it becomes browsable (needs an admin token = same TEST_TOKEN in dev).
$sa->approve(array('Token' => $token, 'ArtworkId' => $res['ArtworkId']));

// Global browse from a different kingdom must NOT see the kingdom-1 upload.
$b = $sa->browse('', 1, 50, array('ViewerKingdomId' => 2, 'Tier' => 'all'));
$ids = array_map(function ($a) {
    return $a['ArtworkId'];
}, $b['Artwork']);
assert_true(!in_array($res['ArtworkId'], $ids), 'kingdom-1 private hidden from kingdom-2 viewer');

// Same upload IS visible to a kingdom-1 viewer (once approved).
$b1 = $sa->browse('', 1, 50, array('ViewerKingdomId' => 1, 'Tier' => 'all'));
$ids1 = array_map(function ($a) {
    return $a['ArtworkId'];
}, $b1['Artwork']);
assert_true(in_array($res['ArtworkId'], $ids1), 'kingdom-1 private visible to kingdom-1 viewer');

echo "test_submission_tiers OK\n";
