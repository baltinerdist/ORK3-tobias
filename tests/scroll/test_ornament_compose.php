<?php

/** Ornament composer source-contract checks. */
require_once __DIR__ . '/lib/assert.php';

$root   = __DIR__ . '/../..';
$markup = file_get_contents("$root/orkui/template/revised-frontend/scroll-forge/sf-scroll-markup.html.part");
$app    = file_get_contents("$root/orkui/template/revised-frontend/scroll-forge/sf-app.js.part");
$illum  = file_get_contents("$root/orkui/template/revised-frontend/scroll-forge/sf-illumination.css.part");
$tpl    = file_get_contents("$root/orkui/template/revised-frontend/Scroll_builder.tpl");

test_section('Ornament container in markup, inside .sc2-illum after the border svg');
assert_true(strpos($markup, 'data-sc2-ornament') !== false, 'container attr present in part');
assert_true(strpos($tpl, 'data-sc2-ornament') !== false, 'container inlined into tpl');
$illumPos  = strpos($markup, 'data-sc2-illum');
$borderPos = strpos($markup, 'data-sc2-border');
$ornPos    = strpos($markup, 'data-sc2-ornament');
assert_true($illumPos < $borderPos && $borderPos < $ornPos, 'order: illum < border < ornament');

test_section('Composer exists and is wired into applyFamily');
assert_true(strpos($app, 'function composeOrnament') !== false, 'composeOrnament defined');
$applyPos = strpos($app, 'function applyFamily');
$applyEnd = strpos($app, 'function reflectFamilyControls');
$applyBody = substr($app, $applyPos, $applyEnd - $applyPos);
assert_true(strpos($applyBody, 'composeOrnament') !== false, 'applyFamily calls composeOrnament');

test_section('CSS layer contract');
assert_true(strpos($illum, '.sc2-ornament') !== false, 'ornament CSS present');
assert_true(strpos($illum, 'var(--z-illum)') !== false, 'uses z token');
assert_true(preg_match('/\.sc2-ornament[^}]*pointer-events:\s*none/s', $illum) === 1, 'pointer-events none');

test_section('Fixture assets');
assert_file_exists_msg("$root/system/assets/scroll/forge/families/_fixture/corner_nw.svg", 'fixture corner');
assert_file_exists_msg("$root/system/assets/scroll/forge/families/_fixture/edge_top.svg", 'fixture edge');
assert_true(strpos(file_get_contents("$root/system/assets/scroll/forge/families/_fixture/corner_nw.svg"), 'currentColor') !== false, 'fixture is currentColor-tintable');

echo "\nALL PASS\n";
