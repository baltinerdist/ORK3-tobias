<?php

/** Ornament manifest schema validation for all families. */
require_once __DIR__ . '/lib/assert.php';

$path = __DIR__ . '/../../orkui/template/revised-frontend/scroll/families.json';
$data = json_decode(file_get_contents($path), true);
assert_true(is_array($data), 'families.json parses');

$GROUNDS = ['parchment', 'ivory', 'white'];
$FRAMES  = ['none', 'svg', 'scan'];
$root    = __DIR__ . '/../..';

test_section('Every family has a valid ornament block');
foreach ($data as $key => $fam) {
    if ($key === '_motifs') {
        continue;
    }
    assert_true(isset($fam['ornament']), "$key: ornament block present");
    $o = $fam['ornament'];
    assert_true(in_array($o['ground']['type'] ?? '', $GROUNDS, true), "$key: ground.type valid");
    assert_true(in_array($o['frame']['mode'] ?? '', $FRAMES, true), "$key: frame.mode valid");
    assert_true(isset($o['initials']['set']), "$key: initials.set present");
    assert_true(isset($o['flourish']['mode']), "$key: flourish.mode present");
    // Referenced asset paths must exist on disk (web path → repo path).
    if (($o['frame']['mode'] ?? 'none') !== 'none') {
        $dir = $root . ($o['frame']['dir'] ?? '');
        $ext = $o['frame']['mode'] === 'svg' ? 'svg' : 'png';
        assert_true(is_file("$dir/corner_nw.$ext"), "$key: frame corner_nw.$ext exists");
        assert_true(is_file("$dir/edge_top.$ext"), "$key: frame edge_top.$ext exists");
    }
    if (!empty($o['ground']['tile'])) {
        assert_true(is_file($root . $o['ground']['tile']), "$key: ground tile exists");
    }
}

test_section('_motifs block is well-formed');
assert_true(isset($data['_motifs']['map']) && is_array($data['_motifs']['map']), '_motifs.map is an object');
assert_true(isset($data['_motifs']['dir']), '_motifs.dir present');
foreach ($data['_motifs']['map'] as $needle => $stem) {
    assert_true($needle === strtolower($needle), "motif key '$needle' is lowercase");
    assert_true(
        is_file($root . rtrim($data['_motifs']['dir'], '/') . "/$stem.png"),
        "motif asset $stem.png exists"
    );
}

echo "\nALL PASS\n";
