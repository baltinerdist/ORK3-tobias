<?php

/**
 * Title flourish plates (plan Task 8) — source-contract checks.
 *
 * The grand title is wrapped in a titleblock flanked by two flourish spans;
 * composeFlourish(key) inlines ornament.flourish.file (SVG, currentColor)
 * into both, the post span mirrored via CSS transform. mode "none" (or plain
 * intensity) leaves both spans empty.
 */
require_once __DIR__ . '/lib/assert.php';

$root   = __DIR__ . '/../..';
$markup = file_get_contents("$root/orkui/template/revised-frontend/scroll-forge/sf-scroll-markup.html.part");
$app    = file_get_contents("$root/orkui/template/revised-frontend/scroll-forge/sf-app.js.part");
$typo   = file_get_contents("$root/orkui/template/revised-frontend/scroll-forge/sf-typography.css.part");
$tpl    = file_get_contents("$root/orkui/template/revised-frontend/Scroll_builder.tpl");

test_section('Titleblock markup: flourish spans flank the title h1');
assert_true(strpos($markup, 'data-sc2-titleblock') !== false, 'titleblock attr present in part');
assert_true(strpos($tpl, 'data-sc2-titleblock') !== false, 'titleblock inlined into tpl');
assert_true(preg_match('/data-sc2-flourish="pre"/', $markup) === 1, 'pre flourish span present');
assert_true(preg_match('/data-sc2-flourish="post"/', $markup) === 1, 'post flourish span present');
$blockPos = strpos($markup, 'data-sc2-titleblock');
$prePos   = strpos($markup, 'data-sc2-flourish="pre"');
$titlePos = strpos($markup, 'class="sc2-title"');
$postPos  = strpos($markup, 'data-sc2-flourish="post"');
assert_true($titlePos !== false, 'title h1 present');
assert_true(
    $blockPos < $prePos && $prePos < $titlePos && $titlePos < $postPos,
    'order: titleblock < pre < title < post'
);
assert_true(
    preg_match('/<h1 class="sc2-title" data-sc2-bind="awardName"/', $markup) === 1,
    'title keeps its awardName binding'
);
assert_true(
    preg_match('/sc2-flourish--pre[^>]*aria-hidden="true"/', $markup) === 1
    || preg_match('/aria-hidden="true"[^>]*sc2-flourish--pre/', $markup) === 1,
    'pre flourish is aria-hidden'
);

test_section('composeFlourish exists, reuses fetchSvg, wired into applyFamily');
assert_true(strpos($app, 'function composeFlourish') !== false, 'composeFlourish defined');
$applyPos  = strpos($app, 'function applyFamily');
$applyEnd  = strpos($app, 'function reflectFamilyControls');
$applyBody = substr($app, $applyPos, $applyEnd - $applyPos);
assert_true(strpos($applyBody, 'composeFlourish') !== false, 'applyFamily calls composeFlourish');
$cfPos  = strpos($app, 'function composeFlourish');
$cfEnd  = strpos($app, "\n\tfunction ", $cfPos + 10);   /* next TOP-LEVEL fn */
$cfBody = substr($app, $cfPos, ($cfEnd !== false ? $cfEnd : strlen($app)) - $cfPos);
assert_true(strpos($cfBody, 'fetchSvg') !== false, 'composeFlourish reuses fetchSvg (shared ORN_CACHE)');
assert_true(strpos($cfBody, 'flourish') !== false, 'composeFlourish reads ornament.flourish');
assert_true(substr_count($app, 'var ORN_CACHE') === 1, 'exactly one ORN_CACHE (no duplicate helper)');
assert_true(substr_count($app, 'function fetchSvg') === 1, 'exactly one fetchSvg (no duplicate helper)');

test_section('Typography CSS styles the flourish spans');
assert_true(strpos($typo, '.sc2-flourish') !== false, 'flourish CSS present');
assert_true(preg_match('/\.sc2-flourish\s*\{[^}]*display:\s*block/s', $typo) === 1, 'flourish display block');
assert_true(preg_match('/\.sc2-flourish\s*\{[^}]*color:\s*var\(--accent/s', $typo) === 1, 'flourish tinted var(--accent)');
assert_true(preg_match('/sc2-flourish--post[^{]*\{[^}]*scale\(-1,\s*-1\)/s', $typo) === 1, 'post flourish mirrored');
assert_true(strpos($tpl, '.sc2-flourish') !== false, 'flourish CSS inlined into tpl');

test_section('Fixture flourish asset');
$fx = "$root/system/assets/scroll/forge/flourishes/_fixture.svg";
assert_file_exists_msg($fx, 'fixture flourish svg');
assert_true(strpos(file_get_contents($fx), 'currentColor') !== false, 'fixture is currentColor-tintable');

test_section('No family manifest points at the fixture');
$fams = json_decode(file_get_contents("$root/orkui/template/revised-frontend/scroll/families.json"), true);
assert_true(is_array($fams), 'families.json parses');
foreach ($fams as $key => $fam) {
    if ($key[0] === '_') {
        continue;
    }
    $fl = $fam['ornament']['flourish'] ?? null;
    assert_true(is_array($fl) && isset($fl['mode']), "$key: flourish block present");
    if (($fl['mode'] ?? 'none') !== 'none') {
        assert_true(strpos((string)($fl['file'] ?? ''), '_fixture') === false, "$key: not pointing at fixture");
    }
}

echo "\nALL PASS\n";
