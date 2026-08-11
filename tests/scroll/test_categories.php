<?php
/**
 * Scroll Graphic Submissions — category read API.
 *
 * Verifies ScrollArtwork::list_categories(true) returns the active, seeded
 * thematic categories in sort order with the PascalCase shape the front-end
 * consumes. Needs only the DB (no session token).
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

// list_categories(true) returns only active, sorted by sort_order then label.
$res = $sa->list_categories(true);
assert_true(isset($res['Categories']) && is_array($res['Categories']), 'Categories key present');
assert_true(count($res['Categories']) >= 9, 'at least 9 seeded categories');
assert_equals('heraldic', $res['Categories'][0]['Slug'], 'first category is heraldic by sort_order');
assert_true(isset($res['Categories'][0]['CategoryId']), 'category has CategoryId');
assert_true(isset($res['Categories'][0]['Label']), 'category has Label');

echo "test_categories OK\n";
