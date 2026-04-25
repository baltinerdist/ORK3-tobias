<?php
require_once __DIR__ . '/lib/assert.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollPalette.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollPrimitives.php';

// ------------------------------------------------------------------
test_section('Gilding gradient horizontal');
$img = imagecreatetruecolor(100, 20);
ScrollPrimitives::fillGildedRect($img, 0, 0, 100, 20, '#D4AF37', '#FFF3B0', 0); // 0 = horizontal
$rgb = imagecolorat($img, 50, 10);
$r = ($rgb >> 16) & 0xFF; $g = ($rgb >> 8) & 0xFF; $b = $rgb & 0xFF;
assert_true($r > 200 && $g > 200, "center is highlight-bright (rgb=$r,$g,$b)");

$rgb = imagecolorat($img, 1, 10);
$r2 = ($rgb >> 16) & 0xFF;
assert_true($r2 < 200, "left edge is darkened (r=$r2)");
imagedestroy($img);

// ------------------------------------------------------------------
test_section('Gilded circle');
$img = imagecreatetruecolor(40, 40);
$bg = imagecolorallocate($img, 244, 232, 200);
imagefilledrectangle($img, 0, 0, 39, 39, $bg);
ScrollPrimitives::fillGildedCircle($img, 20, 20, 12, '#D4AF37', '#FFF3B0');
$rgb = imagecolorat($img, 20, 20);
$r = ($rgb >> 16) & 0xFF; $g = ($rgb >> 8) & 0xFF;
assert_true($r > 100 && $g > 100, "center of circle is non-parchment ($r,$g)");
$rgb = imagecolorat($img, 0, 0);
$r2 = ($rgb >> 16) & 0xFF;
assert_equals(244, $r2, "outside circle stays parchment");
imagedestroy($img);

// ------------------------------------------------------------------
test_section('Parchment texture — base + vignette');
$img = imagecreatetruecolor(480, 624);
ScrollPrimitives::applyParchment($img, 480, 624, '#F4E8C8', '#0B6623', 'balanced');
$rgb = imagecolorat($img, 240, 312);
$r = ($rgb >> 16) & 0xFF;
assert_true($r > 220, "center near parchment cream (r=$r)");
$rgb = imagecolorat($img, 5, 5);
$r2 = ($rgb >> 16) & 0xFF;
assert_true($r2 < $r, "corner darker than center (r=$r2 < $r)");
imagedestroy($img);

// ------------------------------------------------------------------
test_section('Parchment foxing density scales with preset');
$img1 = imagecreatetruecolor(480, 624);
$img2 = imagecreatetruecolor(480, 624);
ScrollPrimitives::applyParchment($img1, 480, 624, '#F4E8C8', '#0B6623', 'light');
ScrollPrimitives::applyParchment($img2, 480, 624, '#F4E8C8', '#0B6623', 'heavy');
$dark1 = $dark2 = 0;
for ($i = 0; $i < 1000; $i++) {
	$x = (int)(($i * 1009) % 480); $y = (int)(($i * 1013) % 624);
	$rgb1 = imagecolorat($img1, $x, $y); $rgb2 = imagecolorat($img2, $x, $y);
	if ((($rgb1 >> 16) & 0xFF) < 0xC0) $dark1++;
	if ((($rgb2 >> 16) & 0xFF) < 0xC0) $dark2++;
}
assert_true($dark2 > $dark1, "heavy aging has more dark pixels ($dark2 > $dark1)");
imagedestroy($img1); imagedestroy($img2);

// ------------------------------------------------------------------
test_section('Stub frame');
$img = imagecreatetruecolor(480, 624);
$bg = imagecolorallocate($img, 244, 232, 200); imagefilledrectangle($img, 0, 0, 479, 623, $bg);
$pal = ['bg'=>'#F4E8C8','text'=>'#1C1810','accent'=>'#B71C2A','border'=>'#2A4B8D','gold'=>'#D4AF37','gold_highlight'=>'#FFF3B0','wax'=>'#7B1F2A','ground_a'=>'#0B6623'];
ScrollPrimitives::drawStubFrame($img, 480, 624, $pal);
$rgb = imagecolorat($img, 28, 28);
$r = ($rgb >> 16) & 0xFF; $g = ($rgb >> 8) & 0xFF; $b = $rgb & 0xFF;
assert_true($r > 100 && $g > 80 && $b < 200, "corner shows besant (rgb=$r,$g,$b)");
imagedestroy($img);

echo "\nALL PASS\n";
