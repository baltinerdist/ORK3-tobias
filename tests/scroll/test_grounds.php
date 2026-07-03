<?php

/**
 * Real grounds (plan Task 4): parchment tile / ivory / white.
 * Static contract checks: ground <img> in the markup part (ordered before the
 * vellum layer), applyGround defined + wired into applyFamily, substrate CSS
 * carries the .sc2-ground layer + ivory/white clean-sheet overrides, and the
 * grounds asset dir has its sourcing README.
 */
require_once __DIR__ . '/lib/assert.php';

$root   = __DIR__ . '/../..';
$markup = file_get_contents("$root/orkui/template/revised-frontend/scroll-forge/sf-scroll-markup.html.part");
$app    = file_get_contents("$root/orkui/template/revised-frontend/scroll-forge/sf-app.js.part");
$sub    = file_get_contents("$root/orkui/template/revised-frontend/scroll-forge/sf-substrate.css.part");

test_section('Ground element present and ordered before vellum');
assert_true(strpos($markup, 'data-sc2-ground') !== false, 'ground img in markup');
assert_true(strpos($markup, 'data-sc2-ground') < strpos($markup, 'data-sc2-vellum'), 'ground before vellum');

test_section('applyGround wired');
assert_true(strpos($app, 'function applyGround') !== false, 'applyGround defined');
$applyPos = strpos($app, 'function applyFamily');
$applyEnd = strpos($app, 'function reflectFamilyControls');
assert_true(strpos(substr($app, $applyPos, $applyEnd - $applyPos), 'applyGround') !== false, 'applyFamily calls applyGround');

test_section('Ground CSS');
assert_true(strpos($sub, '.sc2-ground') !== false, 'ground CSS present');
assert_true(strpos($sub, '[data-ground="white"]') !== false, 'white ground rules present');
assert_true(strpos($sub, '[data-ground="ivory"]') !== false, 'ivory ground rules present');

assert_file_exists_msg("$root/system/assets/scroll/forge/grounds/README.md", 'grounds README');
echo "\nALL PASS\n";
