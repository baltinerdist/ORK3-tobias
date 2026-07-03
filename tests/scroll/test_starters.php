<?php

/**
 * Starter-template seeding assertion.
 *
 * listForKingdom(0) must surface the seeded shared starters (is_starter=1,
 * kingdom_id NULL) for any kingdom. Asserts 3 starters, each with a non-empty
 * slots + zones payload (proves the seeder ran and the JSON round-trips).
 *
 * Boots the full ORK runtime (bootstrap block copied from
 * test_moderation_authority.php) so $DB + Ork3::$Lib->scrolltemplate are live.
 */
require_once __DIR__ . '/lib/assert.php';

// Bootstrap the ORK runtime so $DB + Ork3::$Lib are available (CLI-safe).
chdir(__DIR__ . '/../../orkui');
if (!isset($_SERVER['HTTP_HOST'])) {
    $_SERVER['HTTP_HOST'] = 'localhost';
}
putenv('ENVIRONMENT=DEV');
require_once __DIR__ . '/../../startup.php';

test_section('Starter templates');
$lib = Ork3::$Lib->scrolltemplate;

$list = $lib->listForKingdom(0);
assert_equals(0, $list['Status']['Status'] ?? -1, 'listForKingdom ok');

$starters = array_values(array_filter($list['Templates'], fn ($t) => (int)$t['is_starter'] === 1));
assert_equals(3, count($starters), 'exactly 3 shared starters');

foreach ($starters as $t) {
    $name = $t['name'];
    assert_true(is_array($t['slots']) && count($t['slots']) > 0, "starter '$name' has non-empty slots");
    assert_true(is_array($t['zones']) && count($t['zones']) > 0, "starter '$name' has non-empty zones");
}

echo "\nALL PASS\n";
