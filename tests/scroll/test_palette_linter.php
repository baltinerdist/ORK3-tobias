<?php
require_once __DIR__ . '/lib/assert.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollPalette.php';

test_section('Palette schema');
$valid = [
	'bg' => '#F4E8C8', 'text' => '#1C1810', 'accent' => '#B71C2A',
	'border' => '#2A4B8D', 'gold' => '#D4AF37', 'gold_highlight' => '#FFF3B0',
	'wax' => '#7B1F2A', 'ground_a' => '#0B6623',
];
[$ok, $err] = ScrollPalette::validate($valid);
assert_true($ok, "valid 8-token palette accepted ($err)");

test_section('Rejects pure black ink');
[$ok, $err] = ScrollPalette::validate(array_merge($valid, ['text' => '#000000']));
assert_true(!$ok, "pure-black text rejected");

test_section('Rejects pure white bg');
[$ok, $err] = ScrollPalette::validate(array_merge($valid, ['bg' => '#FFFFFF']));
assert_true(!$ok, "pure-white bg rejected");

test_section('Rejects missing required tokens');
$missing = $valid; unset($missing['gold']);
[$ok, $err] = ScrollPalette::validate($missing);
assert_true(!$ok, "missing 'gold' rejected");

test_section('Hex-to-RGB conversion');
$rgb = ScrollPalette::hexToRgb('#D4AF37');
assert_equals([0xD4, 0xAF, 0x37], $rgb, "hex #D4AF37 → [212,175,55]");

test_section('Lighten/darken');
$light = ScrollPalette::lighten('#000000', 0.5);
assert_equals('#808080', $light, "lighten(#000, 0.5) → #808080");
$dark = ScrollPalette::darken('#FFFFFF', 0.5);
assert_equals('#808080', $dark, "darken(#FFF, 0.5) → #808080");

echo "\nALL PASS\n";
