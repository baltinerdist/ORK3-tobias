<?php

/**
 * Matte gilding contract (plan Task 5).
 * The title's fill must be matte layered ink (currentColor) roughened by the
 * #sc2-handink displacement filter — NOT the retired specular gradient
 * (background-clip:text + transparent text-fill, the "WordArt tell").
 */
require_once __DIR__ . '/lib/assert.php';

$root  = __DIR__ . '/../..';
$typo  = file_get_contents("$root/orkui/template/revised-frontend/scroll-forge/sf-typography.css.part");
$markup = file_get_contents("$root/orkui/template/revised-frontend/scroll-forge/sf-scroll-markup.html.part");
$tpl   = file_get_contents("$root/orkui/template/revised-frontend/Scroll_builder.tpl");

// Extract the primary `.sc2-scroll .sc2-title {` declaration block.
$start = strpos($typo, ".sc2-scroll .sc2-title {");
assert_true($start !== false, 'primary .sc2-title block found in sf-typography');
$end = strpos($typo, '}', $start);
$titleBlock = substr($typo, $start, $end - $start + 1);

test_section('Title fill is matte hand-inked, not gradient');
assert_true(strpos($titleBlock, 'url(#sc2-handink)') !== false, '.sc2-title uses the #sc2-handink filter');
assert_true(strpos($titleBlock, '-webkit-text-fill-color: transparent') === false, 'no transparent text-fill in .sc2-title block');
assert_true(strpos($titleBlock, 'background-clip: text') === false, 'no background-clip:text in .sc2-title block');
assert_true(strpos($titleBlock, 'background-image: linear-gradient') === false, 'no gradient fill in .sc2-title block');
assert_true(strpos($titleBlock, 'currentColor') !== false, '.sc2-title text-fill is currentColor (matte)');

test_section('Hand-ink displacement filter def present');
assert_true(strpos($markup, 'id="sc2-handink"') !== false, '#sc2-handink filter in markup part');
assert_true(strpos($markup, 'feDisplacementMap') !== false, 'filter uses feDisplacementMap');
assert_true(strpos($tpl, 'id="sc2-handink"') !== false, '#sc2-handink inlined into tpl');
assert_true(strpos($tpl, 'url(#sc2-handink)') !== false, 'title filter reference inlined into tpl');

echo "\nALL PASS\n";
