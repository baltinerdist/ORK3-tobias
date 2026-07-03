<?php

require_once __DIR__ . '/lib/assert.php';
$root = __DIR__ . '/../..';
$fams = json_decode(file_get_contents("$root/orkui/template/revised-frontend/scroll/families.json"), true);

test_section('Hibernian Knotwork ships a real SVG frame');
$f = $fams['hibernian_knotwork']['ornament']['frame'];
assert_true($f['mode'] === 'svg', 'frame mode svg');
$dir = $root . $f['dir'];
foreach (['corner_nw', 'edge_top', 'medallion'] as $piece) {
    assert_file_exists_msg("$dir/$piece.svg", "hibernian $piece.svg");
    $svg = file_get_contents("$dir/$piece.svg");
    assert_true(strpos($svg, 'currentColor') !== false, "$piece tintable (currentColor)");
    assert_true(substr_count($svg, '<path') >= 6, "$piece is real interlace (≥6 paths), not a stub");
}

test_section('Attribution present');
$attr = file_get_contents("$root/system/assets/scroll/forge/ATTRIBUTION.md");
assert_true(strpos($attr, 'hibernian_knotwork') !== false, 'hibernian attributed');

echo "\nALL PASS\n";
