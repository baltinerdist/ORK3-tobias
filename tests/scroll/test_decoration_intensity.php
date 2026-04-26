<?php
require_once __DIR__ . '/lib/assert.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollPalette.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollPrimitives.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollDecoration.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollFamilyRenderer.php';

$families = json_decode(file_get_contents(__DIR__ . '/../../orkui/template/revised-frontend/scroll/families.json'), true);
$fam = $families['northern_gothic']; $fam['key'] = 'northern_gothic';
$out = __DIR__ . '/snapshots';
if (!is_dir($out)) mkdir($out, 0777, true);

test_section('Decoration intensity changes pixel character');
$darkPixCount = function (string $path): int {
	$img = imagecreatefrompng($path);
	$w = imagesx($img); $h = imagesy($img);
	$count = 0;
	// Sample every 4th pixel
	for ($y = 0; $y < $h; $y += 4) {
		for ($x = 0; $x < $w; $x += 4) {
			$rgb = imagecolorat($img, $x, $y);
			$r = ($rgb >> 16) & 0xFF;
			if ($r < 0xC0) $count++;
		}
	}
	imagedestroy($img);
	return $count;
};

$counts = [];
foreach (['light', 'balanced', 'heavy'] as $intensity) {
	$state = [
		'family' => 'northern_gothic',
		'awardName' => 'Test', 'recipient' => 'Test',
		'decorationIntensity' => $intensity,
	];
	$img = imagecreatetruecolor(480, 624);
	ScrollFamilyRenderer::render($img, 480, 624, $state, $fam);
	$path = "$out/test-intensity-$intensity.png";
	imagepng($img, $path);
	imagedestroy($img);
	$counts[$intensity] = $darkPixCount($path);
}

assert_true($counts['heavy'] > $counts['balanced'], "heavy ({$counts['heavy']}) > balanced ({$counts['balanced']}) dark pixels");
assert_true($counts['balanced'] > $counts['light'], "balanced ({$counts['balanced']}) > light ({$counts['light']}) dark pixels");

test_section('Astral Codex print substitute swaps dark bg to parchment');
$astralFam = $families['astral_codex']; $astralFam['key'] = 'astral_codex';
$state = ['family' => 'astral_codex', 'awardName' => 'T', 'recipient' => 'T'];

// Screen mode: dark bg
$img = imagecreatetruecolor(480, 624);
ScrollFamilyRenderer::render($img, 480, 624, $state, $astralFam);
$rgb = imagecolorat($img, 240, 312);
$r = ($rgb >> 16) & 0xFF;
assert_true($r < 80, "screen mode: center is dark celestial (r=$r)");
imagedestroy($img);

// Print mode: simulate the controller's Astral substitute
$astralPrint = $astralFam;
$astralPrint['palette']['bg'] = '#F4E8C8';
$astralPrint['palette']['text'] = '#1C1810';
$state['forPrint'] = true;
$img = imagecreatetruecolor(480, 624);
ScrollFamilyRenderer::render($img, 480, 624, $state, $astralPrint);
$rgb = imagecolorat($img, 240, 312);
$r = ($rgb >> 16) & 0xFF;
assert_true($r > 200, "print mode: center is parchment cream (r=$r)");
imagedestroy($img);

echo "\nALL PASS\n";
