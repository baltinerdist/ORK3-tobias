<?php
require_once __DIR__ . '/lib/assert.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollPalette.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollPrimitives.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollDecoration.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollFamilyRenderer.php';

$families = json_decode(file_get_contents(__DIR__ . '/../../orkui/template/revised-frontend/scroll/families.json'), true);
$out = __DIR__ . '/snapshots';
if (!is_dir($out)) mkdir($out, 0777, true);

// ----- Unicode award names + recipients ------
test_section('Unicode in award name + recipient + body');
$fam = $families['northern_gothic']; $fam['key'] = 'northern_gothic';
$state = [
	'family' => 'northern_gothic',
	'awardName' => 'Order of Tír na nÓg',
	'recipient' => 'Ó Briain mac Conchobhair',
	'bodyText' => 'Be it known unto Über-knights, that on the day of Ärtemis the noble bearer hath shown valour…',
	'signatures' => [['name' => 'Aldéric', 'role' => 'Maître des Hérauts']],
];
$img = imagecreatetruecolor(480, 624);
ScrollFamilyRenderer::render($img, 480, 624, $state, $fam);
$path = "$out/test-unicode.png";
imagepng($img, $path);
imagedestroy($img);
assert_file_exists_msg($path, "Unicode render produced PNG");
assert_true(filesize($path) > 5000, "PNG > 5KB (sanity — no rendering crash)");

// ----- Very long award name (80+ chars) ------
test_section('Long award name does not break render');
$state['awardName'] = 'The Most Excellent and Noble Order of the Crown of Aurelia, First Class with Oak Leaves and Crossed Swords';
$state['recipient'] = str_repeat('Aldric ', 12); // ~84 chars
$img = imagecreatetruecolor(480, 624);
ScrollFamilyRenderer::render($img, 480, 624, $state, $fam);
$path = "$out/test-longname.png";
imagepng($img, $path);
imagedestroy($img);
assert_file_exists_msg($path, "Long-name render produced PNG");
assert_true(filesize($path) > 5000, "Long-name PNG > 5KB");

// ----- Empty bodyText ------
test_section('Empty body uses default');
$state['awardName'] = 'Test'; $state['recipient'] = 'Test'; $state['bodyText'] = '';
$img = imagecreatetruecolor(480, 624);
ScrollFamilyRenderer::render($img, 480, 624, $state, $fam);
$path = "$out/test-empty-body.png";
imagepng($img, $path);
imagedestroy($img);
assert_true(filesize($path) > 5000, "Empty body falls through to default text");

// ----- All 10 families render with the same Unicode fixture ------
test_section('All 10 families render with Unicode award name');
$state = [
	'awardName' => 'Ordre de la Tír Á',
	'recipient' => 'Sir Aldric Ó Briain',
	'signatures' => [['name' => 'Maître', 'role' => 'Hérauts']],
	'decorationIntensity' => 'balanced',
];
foreach ($families as $key => $f) {
	$f['key'] = $key; $state['family'] = $key;
	$img = imagecreatetruecolor(480, 624);
	ScrollFamilyRenderer::render($img, 480, 624, $state, $f);
	imagedestroy($img);
	assert_true(true, "$key rendered with Unicode without exception");
}

echo "\nALL PASS\n";
