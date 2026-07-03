<?php

/**
 * ScrollTemplate CRUD round-trip against the real dev DB.
 *
 * Boots the full ORK runtime (copies the bootstrap block from
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

test_section('ScrollTemplate CRUD');
$lib = Ork3::$Lib->scrolltemplate;

$res = $lib->create(array(
    'KingdomId' => null, 'Name' => 'Test Starter', 'Orientation' => 'portrait',
    'BgType' => 'color', 'BgValue' => '#ffffff',
    'Slots' => array(array('location' => 'full_border', 'x' => 0, 'y' => 0, 'w' => 100, 'h' => 100, 'source_type' => 'pack', 'source_ref' => 'borders/scroll_border.png')),
    'Zones' => array(array('key' => 'recipient', 'label' => 'Recipient', 'text' => '{PlayerName}', 'font' => 'Cinzel', 'size' => 48)),
    'IsStarter' => 1, 'CreatedBy' => 1,
));
assert_equals(0, $res['Status']['Status'] ?? -1, 'create ok');   // Success() has Status==0
$id = $res['TemplateId'];
assert_true($id > 0, "got template id $id");

$got = $lib->get($id);
assert_equals('Test Starter', $got['Template']['name'], 'name round-trips');
assert_equals('full_border', $got['Template']['slots'][0]['location'], 'slots JSON round-trips');
assert_equals('{PlayerName}', $got['Template']['zones'][0]['text'], 'zones JSON round-trips');

$list = $lib->listForKingdom(999999);
assert_true(count(array_filter($list['Templates'], fn ($t) => $t['scroll_template_id'] == $id)) === 1, 'starter appears for any kingdom');

$upd = $lib->update($id, array(
    'Name' => 'Renamed Starter', 'Orientation' => 'landscape',
    'BgType' => 'color', 'BgValue' => '#eeeeee',
    'Slots' => array(), 'Zones' => array(),
));
assert_equals(0, $upd['Status']['Status'] ?? -1, 'update ok');
$got2 = $lib->get($id);
assert_equals('Renamed Starter', $got2['Template']['name'], 'name updated');
assert_equals('landscape', $got2['Template']['orientation'], 'orientation updated');

$lib->delete($id);
$after = $lib->listForKingdom(999999);
assert_true(count(array_filter($after['Templates'], fn ($t) => $t['scroll_template_id'] == $id)) === 0, 'archived template drops out of list');

echo "\nALL PASS\n";
