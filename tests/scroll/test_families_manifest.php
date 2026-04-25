<?php
require_once __DIR__ . '/lib/assert.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollPalette.php';

$path = __DIR__ . '/../../orkui/template/revised-frontend/scroll/families.json';
assert_file_exists_msg($path, 'families.json exists');
$json = json_decode(file_get_contents($path), true);
assert_true(is_array($json), 'parses as JSON');

$expected = ['hibernian_knotwork','northern_gothic','provencal_bestiary','crimson_decree','forest_reverie','charred_edict','imperial_edict','scholars_hand','crusaders_charter','astral_codex'];
test_section('All 10 families present');
foreach ($expected as $k) {
	assert_true(isset($json[$k]), "family $k present");
}

test_section('Per-family schema');
foreach ($expected as $k) {
	$f = $json[$k];
	foreach (['name','period','mood','palette','fonts','frame','decoration','layout','sigCount','orientation_default'] as $req) {
		assert_true(isset($f[$req]), "$k.$req present");
	}
	foreach (['title','subtitle','body','signatures','date'] as $slot) {
		assert_true(isset($f['fonts'][$slot]), "$k.fonts.$slot present");
		assert_true(isset($f['fonts']["{$slot}_php"]), "$k.fonts.{$slot}_php present");
	}
}

test_section('All palettes pass linter');
foreach ($expected as $k) {
	[$ok, $err] = ScrollPalette::validate($json[$k]['palette']);
	assert_true($ok, "$k palette valid ($err)");
}

test_section('All font_php values map to existing TTFs');
// Parse $FONTS map directly out of the controller source — avoids requiring the full MVC class hierarchy.
$src = file_get_contents(__DIR__ . '/../../orkui/controller/controller.ScrollAjax.php');
preg_match('/private static \$FONTS = \[(.*?)\];/s', $src, $m);
assert_true(isset($m[1]), 'parsed $FONTS block from controller');
preg_match_all("/'([^']+)'\s*=>\s*'([^']+)'/", $m[1], $entries, PREG_SET_ORDER);
$fonts = [];
foreach ($entries as $e) $fonts[$e[1]] = $e[2];
assert_true(count($fonts) > 0, 'extracted ' . count($fonts) . ' font entries');

$fontDir = __DIR__ . '/../../assets/scroll/fonts/';
foreach ($expected as $k) {
	foreach (['title','subtitle','body','signatures','date'] as $slot) {
		$key = $json[$k]['fonts']["{$slot}_php"];
		assert_true(isset($fonts[$key]), "$k.fonts.{$slot}_php '$key' is in \$FONTS map");
		assert_true(file_exists($fontDir . $fonts[$key]), "$k.fonts.{$slot}_php → " . $fonts[$key] . " exists on disk");
	}
}

echo "\nALL PASS\n";
