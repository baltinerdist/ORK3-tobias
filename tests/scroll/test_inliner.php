<?php

/**
 * Inliner integrity: every .part file's content must appear verbatim inside
 * Scroll_builder.tpl, and running the inliner must be idempotent.
 */
require_once __DIR__ . '/lib/assert.php';

$root  = __DIR__ . '/../..';
$tpl   = "$root/orkui/template/revised-frontend/Scroll_builder.tpl";
$parts = "$root/orkui/template/revised-frontend/scroll-forge";

test_section('Inliner tool exists');
assert_file_exists_msg("$root/tools/scroll_forge_inline.py", 'tools/scroll_forge_inline.py present');

test_section('Inliner runs clean and is idempotent');
exec("python3 " . escapeshellarg("$root/tools/scroll_forge_inline.py") . " 2>&1", $out1, $rc1);
assert_true($rc1 === 0, 'first inliner run exits 0 (' . implode(' / ', array_slice($out1, -3)) . ')');
$hashA = md5_file($tpl);
exec("python3 " . escapeshellarg("$root/tools/scroll_forge_inline.py") . " 2>&1", $out2, $rc2);
assert_true($rc2 === 0, 'second inliner run exits 0');
$hashB = md5_file($tpl);
assert_true($hashA === $hashB, 'inliner is idempotent (tpl unchanged on second run)');

test_section('Every part is inlined verbatim');
$tplSrc = file_get_contents($tpl);
foreach (glob("$parts/*.part") as $p) {
    $body = trim(file_get_contents($p));
    // Compare a distinctive 200-char slice from the middle of each part.
    $mid = substr($body, (int)(strlen($body) / 2), 200);
    assert_true(strpos($tplSrc, $mid) !== false, basename($p) . ' midslice found in tpl');
}
foreach (glob("$parts/families/*.css.part") as $p) {
    $body = trim(file_get_contents($p));
    $mid = substr($body, (int)(strlen($body) / 2), 200);
    assert_true(strpos($tplSrc, $mid) !== false, basename($p) . ' midslice found in tpl');
}

echo "\nALL PASS\n";
