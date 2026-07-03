<?php

/**
 * Award motif slot (plan Task 7) — source-contract checks.
 *
 * The motif slot is a duotone, family-ink-tinted emblem in the bas-de-page,
 * chosen by substring-matching state.awardName against SC_FAMILIES._motifs.map.
 * NOTE: the defs <g> already owns data-sc2-motif — the slot attribute is
 * data-sc2-motif-slot exactly.
 */
require_once __DIR__ . '/lib/assert.php';

$root   = __DIR__ . '/../..';
$markup = file_get_contents("$root/orkui/template/revised-frontend/scroll-forge/sf-scroll-markup.html.part");
$app    = file_get_contents("$root/orkui/template/revised-frontend/scroll-forge/sf-app.js.part");
$seal   = file_get_contents("$root/orkui/template/revised-frontend/scroll-forge/sf-heraldry-seal.css.part");
$tpl    = file_get_contents("$root/orkui/template/revised-frontend/Scroll_builder.tpl");

test_section('Motif slot in markup, inside the seal footer before the ribbon');
assert_true(strpos($markup, 'data-sc2-motif-slot') !== false, 'slot attr present in part');
assert_true(strpos($tpl, 'data-sc2-motif-slot') !== false, 'slot inlined into tpl');
$wrapPos   = strpos($markup, 'data-sc2-seal-wrap');
$slotPos   = strpos($markup, 'data-sc2-motif-slot');
$ribbonPos = strpos($markup, 'sc2-seal-ribbon');
assert_true($wrapPos !== false && $ribbonPos !== false, 'seal footer landmarks present');
assert_true($wrapPos < $slotPos && $slotPos < $ribbonPos, 'order: seal-wrap < motif-slot < seal-ribbon');
assert_true(preg_match('/data-sc2-motif-slot[^>]*\bhidden\b/', $markup) === 1, 'slot ships hidden by default');

test_section('composeMotif exists and is wired into applyFamily + renderCopy');
assert_true(strpos($app, 'function composeMotif') !== false, 'composeMotif defined');
$applyPos  = strpos($app, 'function applyFamily');
$applyEnd  = strpos($app, 'function reflectFamilyControls');
$applyBody = substr($app, $applyPos, $applyEnd - $applyPos);
assert_true(strpos($applyBody, 'composeMotif') !== false, 'applyFamily calls composeMotif');
$rcPos  = strpos($app, 'function renderCopy');
$rcEnd  = strpos($app, 'function applyFamily');
$rcBody = substr($app, $rcPos, $rcEnd - $rcPos);
assert_true(strpos($rcBody, 'composeMotif') !== false, 'renderCopy calls composeMotif');
assert_true(strpos($app, '_motifs') !== false, 'composeMotif reads SC_FAMILIES._motifs');

test_section('Heraldry-seal CSS: duotone mask-tinted motif art');
assert_true(strpos($seal, '.sc2-motif') !== false, 'motif CSS present');
assert_true(strpos($seal, '.sc2-motif__art') !== false, 'motif art CSS present');
assert_true(preg_match('/\.sc2-motif__art[^}]*mask:\s*var\(--motif-src\)/s', $seal) === 1, 'mask tint uses var(--motif-src)');
assert_true(preg_match('/\.sc2-motif\s*\{[^}]*var\(--z-illum\)/s', $seal) === 1, 'motif uses z-illum token');
assert_true(preg_match('/\.sc2-motif\s*\{[^}]*pointer-events:\s*none/s', $seal) === 1, 'pointer-events none');

test_section('_motifs.map seeded and every mapped PNG exists');
$fams = json_decode(file_get_contents("$root/orkui/template/revised-frontend/scroll/families.json"), true);
assert_true(is_array($fams), 'families.json parses');
$map = $fams['_motifs']['map'] ?? null;
assert_true(is_array($map) && count($map) > 0, '_motifs.map is non-empty');
assert_true(($map['flame'] ?? '') === '_fixture_flame', 'flame -> _fixture_flame seeded');
$dir = rtrim($fams['_motifs']['dir'] ?? '', '/');
foreach ($map as $needle => $stem) {
    assert_true($needle === strtolower($needle), "motif key '$needle' is lowercase");
    assert_true(is_file($root . "$dir/$stem.png"), "motif asset $stem.png exists");
}

test_section('Fixture asset');
assert_file_exists_msg("$root/system/assets/scroll/forge/motifs/_fixture_flame.png", 'fixture motif PNG');

echo "\nALL PASS\n";
