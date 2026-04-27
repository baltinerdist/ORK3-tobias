<?php
/**
 * Verify heraldry medallions composite into the new family render.
 *
 * Builds a small synthetic heraldry PNG (a teal disc with a cross), passes it
 * via state.kingdomHeraldry / state.playerHeraldry / state.parkHeraldry, renders
 * a family, and asserts the resulting scroll has teal-ish pixels at each
 * expected medallion position. Confirms the renderer (a) honors the state keys,
 * (b) loads local PNG sources, and (c) places medallions where Plan v1.5 puts
 * them: kingdom top-left, player top-right, park bottom-center.
 */
require_once __DIR__ . '/lib/assert.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollPalette.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollPrimitives.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollDecoration.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollFamilyRenderer.php';

$out = __DIR__ . '/snapshots';
if (!is_dir($out)) mkdir($out, 0777, true);

// --- Build a synthetic teal heraldry PNG (256×256) ---
$heraldry = imagecreatetruecolor(256, 256);
imagealphablending($heraldry, false); imagesavealpha($heraldry, true);
$tx = imagecolorallocatealpha($heraldry, 0, 0, 0, 127);
imagefilledrectangle($heraldry, 0, 0, 256, 256, $tx);
imagealphablending($heraldry, true);
$teal = imagecolorallocate($heraldry, 0, 200, 200);
imagefilledellipse($heraldry, 128, 128, 220, 220, $teal);
$ink = imagecolorallocate($heraldry, 20, 20, 20);
imagefilledrectangle($heraldry, 120, 60, 136, 196, $ink);
imagefilledrectangle($heraldry, 70, 120, 186, 136, $ink);
$heraldryPath = "$out/_test_heraldry.png";
imagepng($heraldry, $heraldryPath);
imagedestroy($heraldry);

$families = json_decode(file_get_contents(__DIR__ . '/../../orkui/template/revised-frontend/scroll/families.json'), true);
$fam = $families['northern_gothic']; $fam['key'] = 'northern_gothic';

$state = [
	'family' => 'northern_gothic',
	'awardName' => 'Test',
	'recipient' => 'Test Recipient',
	'kingdomHeraldry' => $heraldryPath,
	'parkHeraldry'    => $heraldryPath,
	'playerHeraldry'  => $heraldryPath,
];

$w = 480; $h = 624;
$img = imagecreatetruecolor($w, $h);
ScrollFamilyRenderer::render($img, $w, $h, $state, $fam);
$snapshot = "$out/test-heraldry-medallions.png";
imagepng($img, $snapshot);

test_section('Heraldry medallions composite at the three expected positions');

$scale   = $w / 480;
$r       = max(16, (int)(22 * $scale));
$rPlayer = max(14, (int)(18 * $scale));
$y       = (int)(56 * $scale);
// Probe slightly off-center to skip the cross ink at the disc origin.
$points = [
	'kingdom (top-left)'   => [(int)(46 * $scale) + $r + (int)($r * 0.4), $y + (int)($r * 0.4)],
	'park    (top-right)'  => [$w - (int)(46 * $scale) - $r + (int)($r * 0.4), $y + (int)($r * 0.4)],
	'player  (bot-center)' => [(int)($w / 2) + (int)($rPlayer * 0.3), $h - (int)(160 * $scale) + (int)($rPlayer * 0.3)],
];

foreach ($points as $name => [$cx, $cy]) {
	$rgb = imagecolorat($img, $cx, $cy);
	$r_ = ($rgb >> 16) & 0xFF; $g_ = ($rgb >> 8) & 0xFF; $b_ = $rgb & 0xFF;
	$tealLike = ($g_ > 100 && $b_ > 100 && $r_ < 100);
	assert_true($tealLike, "$name medallion shows heraldry pixels (rgb $r_,$g_,$b_)");
}

test_section('Empty heraldry state leaves the renderer unchanged');
$stateNo = ['family' => 'northern_gothic', 'awardName' => 'Test', 'recipient' => 'Test'];
$img2 = imagecreatetruecolor($w, $h);
ScrollFamilyRenderer::render($img2, $w, $h, $stateNo, $fam);
$rgb = imagecolorat($img2, (int)(46 * $scale) + $r + (int)($r * 0.4), $y + (int)($r * 0.4));
$r_ = ($rgb >> 16) & 0xFF; $g_ = ($rgb >> 8) & 0xFF; $b_ = $rgb & 0xFF;
$tealLike = ($g_ > 100 && $b_ > 100 && $r_ < 100);
assert_true(!$tealLike, "without state.kingdomHeraldry, top-left has no heraldry (rgb $r_,$g_,$b_)");
imagedestroy($img2);

imagedestroy($img);
@unlink($heraldryPath);
echo "\nALL PASS — snapshot at $snapshot\n";
