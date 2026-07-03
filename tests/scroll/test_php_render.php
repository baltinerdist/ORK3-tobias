<?php

require_once __DIR__ . '/lib/assert.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollPalette.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollPrimitives.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollDecoration.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollFamilyRenderer.php';

$families = json_decode(file_get_contents(__DIR__ . '/../../orkui/template/revised-frontend/scroll/families.json'), true);
$out = __DIR__ . '/snapshots';
if (!is_dir($out)) {
    mkdir($out, 0777, true);
}

test_section('Render all 10 families to PNG (preview scale 480×624)');
foreach ($families as $key => $fam) {
    if ($key[0] === '_') {
        continue;
    } // reserved manifest metadata (e.g. _motifs)
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
    assert_file_exists_msg($path, "$key rendered (preview)");
    assert_true(filesize($path) > 5000, "$key preview PNG > 5KB");
}

test_section('Render Northern Gothic at print scale 2550×3300 (300 DPI)');
$fam = $families['northern_gothic'];
$fam['key'] = 'northern_gothic';
$state = [
    'family' => 'northern_gothic',
    'awardName' => 'Decretum Imperiale',
    'recipient' => 'Sir Aldric of Whitethorn',
    'signatures' => [['name' => 'Aelinora', 'role' => 'Grand Duchess']],
    'decorationIntensity' => 'balanced',
];
$start = microtime(true);
$img = imagecreatetruecolor(2550, 3300);
ScrollFamilyRenderer::render($img, 2550, 3300, $state, $fam);
$elapsed = microtime(true) - $start;
imagepng($img, "$out/plan1-print-northern_gothic.png");
imagedestroy($img);
assert_file_exists_msg("$out/plan1-print-northern_gothic.png", "print-scale rendered");
assert_true(filesize("$out/plan1-print-northern_gothic.png") > 50000, "print PNG > 50KB");
echo "  ⏱  print-scale render took " . number_format($elapsed, 2) . "s\n";

echo "\nALL PASS — snapshots in tests/scroll/snapshots/\n";
