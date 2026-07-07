<?php

/**
 * ScrollTemplate CRUD + 3-tier visibility scoping round-trip against the real dev DB.
 *
 * Boots the full ORK runtime (copies the bootstrap block from
 * test_moderation_authority.php) so $DB + Ork3::$Lib->scrolltemplate are live.
 *
 * Covers: global (starter) / kingdom / park create + read semantics, visibleTo()
 * (global+kingdom+park union with 0-id guards), listForScope() (one tier), and
 * update() re-scoping (promote a kingdom template to a global starter).
 */
require_once __DIR__ . '/lib/assert.php';

// Bootstrap the ORK runtime so $DB + Ork3::$Lib are available (CLI-safe).
chdir(__DIR__ . '/../../orkui');
if (!isset($_SERVER['HTTP_HOST'])) {
    $_SERVER['HTTP_HOST'] = 'localhost';
}
putenv('ENVIRONMENT=DEV');
require_once __DIR__ . '/../../startup.php';

test_section('ScrollTemplate CRUD + scoping');
$lib = Ork3::$Lib->scrolltemplate;

// Improbable test scope ids so we never collide with real rows.
$KID = 987654;
$PID = 876543;

$has = function ($list, $tid) {
    return count(array_filter($list['Templates'], function ($t) use ($tid) {
        return $t['scroll_template_id'] == $tid;
    })) === 1;
};

$slots = array(array('location' => 'full_border', 'x' => 0, 'y' => 0, 'w' => 100, 'h' => 100, 'source_type' => 'pack', 'source_ref' => 'borders/scroll_border.png'));
$zones = array(array('key' => 'recipient', 'label' => 'Recipient', 'text' => '{PlayerName}', 'font' => 'Cinzel', 'size' => 48));

// ---- 1) GLOBAL (Amtgard-wide starter) --------------------------------------
$res = $lib->create(array(
    'KingdomId' => null, 'Visibility' => 'global', 'Name' => 'Test Starter',
    'Orientation' => 'portrait', 'BgType' => 'color', 'BgValue' => '#ffffff',
    'Slots' => $slots, 'Zones' => $zones, 'CreatedBy' => 1,
));
assert_equals(0, $res['Status']['Status'] ?? -1, 'global create ok');
$gid = $res['TemplateId'];
assert_true($gid > 0, "got global template id $gid");

$got = $lib->get($gid);
assert_equals('Test Starter', $got['Template']['name'], 'name round-trips');
assert_equals('full_border', $got['Template']['slots'][0]['location'], 'slots JSON round-trips');
assert_equals('{PlayerName}', $got['Template']['zones'][0]['text'], 'zones JSON round-trips');
assert_equals('global', $got['Template']['visibility'], 'global visibility persisted');
assert_equals(null, $got['Template']['kingdom_id'], 'global has NULL kingdom_id');
assert_equals(null, $got['Template']['park_id'], 'global has NULL park_id');
assert_equals(1, $got['Template']['is_starter'], 'global derives is_starter=1');

$list = $lib->listForKingdom(999999);
assert_true($has($list, $gid), 'starter appears for any kingdom (listForKingdom)');

// ---- 2) KINGDOM template ---------------------------------------------------
$kres = $lib->create(array(
    'KingdomId' => $KID, 'Visibility' => 'kingdom', 'Name' => 'Kingdom Tpl',
    'Orientation' => 'portrait', 'BgType' => 'color', 'BgValue' => '#ffffff',
    'Slots' => $slots, 'Zones' => $zones, 'CreatedBy' => 1,
));
assert_equals(0, $kres['Status']['Status'] ?? -1, 'kingdom create ok');
$kid = $kres['TemplateId'];
$kgot = $lib->get($kid);
assert_equals('kingdom', $kgot['Template']['visibility'], 'kingdom visibility persisted');
assert_equals($KID, $kgot['Template']['kingdom_id'], 'kingdom_id persisted');
assert_equals(null, $kgot['Template']['park_id'], 'kingdom has NULL park_id');
assert_equals(0, $kgot['Template']['is_starter'], 'kingdom derives is_starter=0');

// ---- 3) PARK template ------------------------------------------------------
$pres = $lib->create(array(
    'KingdomId' => $KID, 'ParkId' => $PID, 'Visibility' => 'park', 'Name' => 'Park Tpl',
    'Orientation' => 'portrait', 'BgType' => 'color', 'BgValue' => '#ffffff',
    'Slots' => $slots, 'Zones' => $zones, 'CreatedBy' => 1,
));
assert_equals(0, $pres['Status']['Status'] ?? -1, 'park create ok');
$pid = $pres['TemplateId'];
$pgot = $lib->get($pid);
assert_equals('park', $pgot['Template']['visibility'], 'park visibility persisted');
assert_equals($KID, $pgot['Template']['kingdom_id'], "park stores park's kingdom_id");
assert_equals($PID, $pgot['Template']['park_id'], 'park_id persisted');
assert_equals(0, $pgot['Template']['is_starter'], 'park derives is_starter=0');

// ---- visibleTo(): global + kingdom + park union ----------------------------
$vis = $lib->visibleTo($KID, $PID);
assert_true($has($vis, $gid), 'visibleTo includes global');
assert_true($has($vis, $kid), 'visibleTo includes own kingdom template');
assert_true($has($vis, $pid), 'visibleTo includes own park template');

// A different context sees only global (0/other ids must not match NULL scopes).
$visOther = $lib->visibleTo($KID + 1, $PID + 1);
assert_true($has($visOther, $gid), 'other context still sees global');
assert_true(!$has($visOther, $kid), 'other context does NOT see foreign kingdom template');
assert_true(!$has($visOther, $pid), 'other context does NOT see foreign park template');

// 0 kingdom/park ids must not leak NULL-scoped rows.
$visZero = $lib->visibleTo(0, 0);
assert_true($has($visZero, $gid), 'visibleTo(0,0) sees global');
assert_true(!$has($visZero, $kid), 'visibleTo(0,0) does NOT match kingdom NULL guard');
assert_true(!$has($visZero, $pid), 'visibleTo(0,0) does NOT match park NULL guard');

// ---- listForScope(): exactly one tier --------------------------------------
$g = $lib->listForScope('global', 0, 0);
assert_true($has($g, $gid) && !$has($g, $kid) && !$has($g, $pid), 'listForScope global = global only');
$k = $lib->listForScope('kingdom', $KID, 0);
assert_true($has($k, $kid) && !$has($k, $gid) && !$has($k, $pid), 'listForScope kingdom = kingdom only');
$p = $lib->listForScope('park', 0, $PID);
assert_true($has($p, $pid) && !$has($p, $gid) && !$has($p, $kid), 'listForScope park = park only');

// ---- update(): re-scope (promote kingdom template to a global starter) -----
$upd = $lib->update($kid, array(
    'Visibility' => 'global', 'KingdomId' => null, 'Name' => 'Promoted Starter',
    'Orientation' => 'landscape', 'BgType' => 'color', 'BgValue' => '#eeeeee',
    'Slots' => array(), 'Zones' => array(),
));
assert_equals(0, $upd['Status']['Status'] ?? -1, 'update ok');
$kgot2 = $lib->get($kid);
assert_equals('Promoted Starter', $kgot2['Template']['name'], 'name updated');
assert_equals('landscape', $kgot2['Template']['orientation'], 'orientation updated');
assert_equals('global', $kgot2['Template']['visibility'], 're-scoped to global');
assert_equals(null, $kgot2['Template']['kingdom_id'], 'promote clears kingdom_id');
assert_equals(1, $kgot2['Template']['is_starter'], 'promote sets is_starter=1');

// ---- delete(): archived rows drop out of listings --------------------------
foreach (array($gid, $kid, $pid) as $tid) {
    $lib->delete($tid);
}
$after = $lib->visibleTo($KID, $PID);
assert_true(!$has($after, $gid) && !$has($after, $kid) && !$has($after, $pid), 'archived templates drop out of visibleTo');

echo "\nALL PASS\n";
