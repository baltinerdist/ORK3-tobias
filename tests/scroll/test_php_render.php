<?php
require_once __DIR__ . '/lib/assert.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollPalette.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollPrimitives.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollFamilyRenderer.php';

$families = json_decode(file_get_contents(__DIR__ . '/../../orkui/template/revised-frontend/scroll/families.json'), true);
$out = __DIR__ . '/snapshots';
if (!is_dir($out)) mkdir($out, 0777, true);

test_section('Render all 10 families to PNG (preview scale)');
foreach ($families as $key => $fam) {
	$fam['key'] = $key;
	$state = [
		'family' => $key,
		'awardName' => $fam['name'],
		'recipient' => 'Sir Aldric of Whitethorn',
		'signatures' => [
			['name' => 'Aelinora', 'role' => 'Grand Duchess'],
			['name' => 'Brennus', 'role' => 'Master of Heralds'],
		],
		'decorationIntensity' => 'balanced',
	];
	$img = imagecreatetruecolor(480, 624);
	ScrollFamilyRenderer::render($img, 480, 624, $state, $fam);
	$path = "$out/plan1-$key.png";
	imagepng($img, $path);
	imagedestroy($img);
	assert_file_exists_msg($path, "$key rendered");
	assert_true(filesize($path) > 5000, "$key PNG > 5KB (sanity)");
}

echo "\nALL PASS — 10 family PNGs in tests/scroll/snapshots/\n";
