<?php
/**
 * Curated family asset verification.
 *
 * For every family directory that ships SVG sources, this test verifies the
 * companion pre-tinted PNG variants exist + are non-zero, then renders the
 * family at print scale via the asset-first path and via a forced procedural
 * path, asserting the asset render is at least as data-rich as procedural
 * (byte length grows once curated assets are in place).
 *
 * Families without SVG sources are skipped (procedural-only families remain valid).
 */
require_once __DIR__ . '/lib/assert.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollPalette.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollPrimitives.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollDecoration.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollFamilyRenderer.php';

$families = json_decode(file_get_contents(__DIR__ . '/../../orkui/template/revised-frontend/scroll/families.json'), true);
$assetsRoot = __DIR__ . '/../../system/assets/scroll/families';
$out = __DIR__ . '/snapshots';
if (!is_dir($out)) mkdir($out, 0777, true);

$ROLE_TINTS = [
	'frame_corner_nw' => 'border',
	'frame_edge_top'  => 'border',
	'seal_stamp'      => 'gold',
	'initial_vine'    => 'border',
	'drolerie'        => 'border',
];
$REQUIRED_ROLES = ['frame_corner_nw', 'frame_edge_top', 'seal_stamp'];

$curatedFamilies = [];
foreach ($families as $key => $fam) {
	$dir = "$assetsRoot/$key";
	if (!is_dir($dir)) continue;
	// A family is "curated" iff it has all required SVG sources.
	$hasAll = true;
	foreach ($REQUIRED_ROLES as $role) {
		if (!is_file("$dir/$role.svg")) { $hasAll = false; break; }
	}
	if ($hasAll) $curatedFamilies[] = $key;
}

if (empty($curatedFamilies)) {
	test_section('Curated asset verification — no curated families yet, nothing to verify');
	echo "  (no families have all required SVG sources; this test is a no-op)\n";
	echo "\nALL PASS (vacuous)\n";
	exit(0);
}

test_section('Pre-tinted PNG variants exist for every curated family');
foreach ($curatedFamilies as $key) {
	$dir = "$assetsRoot/$key";
	foreach ($ROLE_TINTS as $role => $token) {
		$svg = "$dir/$role.svg";
		if (!is_file($svg)) continue; // optional roles
		$pngPath = "$dir/{$role}__{$token}.png";
		assert_file_exists_msg($pngPath, "$key/$role: tinted PNG present");
		assert_true(filesize($pngPath) > 100, "$key/$role tinted PNG > 100 bytes");
	}
}

test_section('Curated render produces at least as much pixel data as procedural');
// Pick the first curated family for the byte-length comparison.
$key = $curatedFamilies[0];
$fam = $families[$key]; $fam['key'] = $key;
$state = [
	'family' => $key,
	'awardName' => 'Decretum Curatum',
	'recipient' => 'Sir Aldric of Whitethorn',
	'signatures' => [['name' => 'Aelinora', 'role' => 'Grand Duchess']],
	'decorationIntensity' => 'balanced',
];

// Asset-first path (familyKey populated by renderCanonical from $fam['key']).
$img1 = imagecreatetruecolor(2550, 3300);
ScrollFamilyRenderer::render($img1, 2550, 3300, $state, $fam);
$assetPath = "$out/curated-$key-asset.png";
imagepng($img1, $assetPath);
imagedestroy($img1);
$assetBytes = filesize($assetPath);

// Procedural path: clear $fam['key'] so dispatch falls through.
$famNoKey = $fam; unset($famNoKey['key']);
$state2 = $state; $state2['family'] = '__procedural_only__'; // unknown key → renderCanonical default
$img2 = imagecreatetruecolor(2550, 3300);
ScrollFamilyRenderer::render($img2, 2550, 3300, $state2, $famNoKey);
$procPath = "$out/curated-$key-procedural.png";
imagepng($img2, $procPath);
imagedestroy($img2);
$procBytes = filesize($procPath);

assert_true($assetBytes >= $procBytes,
	"asset render ({$assetBytes} B) >= procedural baseline ({$procBytes} B) — curated assets contribute pixel data");

echo "\nALL PASS — verified " . count($curatedFamilies) . " curated families\n";
