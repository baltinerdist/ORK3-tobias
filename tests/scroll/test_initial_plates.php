<?php

/**
 * Illuminated initial plates (plan Task 6) — source-contract checks.
 *
 * The versal plate is a decorative-leading float injected by
 * applyVersalPlate(); the versal LETTER comes from the narration text
 * (the [data-sc2-versal] paragraph's textContent), never the persona name.
 * Includes the no-`initial-letter` regression sweep across ALL css parts
 * (comments stripped first — the warning comments legitimately mention it).
 */
require_once __DIR__ . '/lib/assert.php';

$root  = __DIR__ . '/../..';
$forge = "$root/orkui/template/revised-frontend/scroll-forge";
$app   = file_get_contents("$forge/sf-app.js.part");
$illum = file_get_contents("$forge/sf-illumination.css.part");

test_section('applyVersalPlate defined, letter sourced from narration text');
assert_true(strpos($app, 'function applyVersalPlate') !== false, 'applyVersalPlate defined');
$fnPos = strpos($app, 'function applyVersalPlate');
$fnEnd = strpos($app, 'function ', $fnPos + 10);
$fnBody = substr($app, $fnPos, ($fnEnd !== false ? $fnEnd : strlen($app)) - $fnPos);
assert_true(strpos($fnBody, 'data-sc2-versal') !== false, 'plate targets the versal paragraph');
assert_true(strpos($fnBody, 'textContent') !== false, 'letter read from the paragraph textContent (narration)');
assert_true(strpos($fnBody, 'state.persona') === false, 'letter NOT derived from state.persona');
assert_true(strpos($fnBody, '/system/assets/scroll/forge/alphabets/') !== false, 'alphabet asset path referenced');

test_section('applyVersalPlate wired into renderCopy and applyFamily');
$rcPos = strpos($app, 'function renderCopy');
$rcEnd = strpos($app, 'function ', $rcPos + 10);
$rcBody = substr($app, $rcPos, $rcEnd - $rcPos);
assert_true(strpos($rcBody, 'applyVersalPlate') !== false, 'renderCopy calls applyVersalPlate');
$afPos = strpos($app, 'function applyFamily');
$afEnd = strpos($app, 'function reflectFamilyControls');
$afBody = substr($app, $afPos, $afEnd - $afPos);
assert_true(strpos($afBody, 'applyVersalPlate') !== false, 'applyFamily calls applyVersalPlate');

test_section('Plate CSS contract (sf-illumination.css.part)');
assert_true(strpos($illum, '.sc2-versal-plate') !== false, 'plate CSS present');
assert_true(preg_match('/\.sc2-versal-plate\s*\{[^}]*float:\s*left/s', $illum) === 1, 'plate floats left');
assert_true(strpos($illum, '.sc2-versal-plate--tint') !== false, 'tint variant present');
assert_true(preg_match('/\.sc2-versal-plate--tint\s*\{[^}]*mask:\s*var\(--plate-src\)/s', $illum) === 1, 'tint variant mask-tints via --plate-src');
assert_true(strpos($illum, '[data-versal-plate="on"]') !== false, 'first-letter reset hook present');

test_section('Regression sweep: NO initial-letter declaration in ANY css part');
$cssParts = array_merge(glob("$forge/*.css.part"), glob("$forge/families/*.css.part"));
assert_true(count($cssParts) > 10, 'css part glob found the parts (' . count($cssParts) . ')');
foreach ($cssParts as $p) {
    $css = file_get_contents($p);
    $css = preg_replace('#/\*.*?\*/#s', '', $css);   // comments may WARN about it
    assert_true(strpos($css, 'initial-letter') === false, basename($p) . ': no initial-letter declaration');
}

test_section('Fixture alphabet assets');
assert_file_exists_msg("$root/system/assets/scroll/forge/alphabets/_fixture/A.png", 'fixture A.png');
assert_file_exists_msg("$root/system/assets/scroll/forge/alphabets/_fixture/T.png", 'fixture T.png');

echo "\nALL PASS\n";
