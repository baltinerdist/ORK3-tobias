<?php
/**
 * Seed system-curated scroll family assets.
 *
 * For each family in families.json:
 *   1. Reads source SVGs from system/assets/scroll/families/<family_key>/<role>.svg
 *   2. Validates source is grayscale-with-alpha (rejects color-mixed; warns)
 *   3. Rasterizes to PNG via rsvg-convert (preferred) or inkscape (fallback)
 *      at print resolution (corners 450, edges 450x90, seals 720,
 *      initial_vines 600x240, drôleries 600x300)
 *   4. Channel-multiplies the grayscale to each role's tint token (border or gold)
 *      → writes pre-tinted variants as <role>__<token>.png
 *   5. Upserts a row in ork_scroll_artwork (system_owned=1) — when --db is passed
 *      and a DB connection is reachable
 *   6. Refreshes ATTRIBUTION.md from the SVG <desc> elements
 *
 * Usage:
 *   php system/scripts/seed-scroll-families.php                 # rasterize + tint, no DB
 *   php system/scripts/seed-scroll-families.php --db            # also upsert DB rows
 *   php system/scripts/seed-scroll-families.php --family <key>  # restrict to one family
 *
 * Idempotent. Re-running overwrites the tinted PNGs; the DB upsert is keyed
 * (family_key, asset_role).
 */

declare(strict_types=1);

const ROOT = __DIR__ . '/../..';
const FAMILIES_JSON = ROOT . '/orkui/template/revised-frontend/scroll/families.json';
const ASSETS_DIR = ROOT . '/system/assets/scroll/families';
const ATTRIBUTION_MD = ROOT . '/system/assets/scroll/ATTRIBUTION.md';

const ROLE_SPECS = [
	'frame_corner_nw' => ['w' => 450, 'h' => 450, 'tint' => 'border', 'required' => true],
	'frame_edge_top'  => ['w' => 450, 'h' =>  90, 'tint' => 'border', 'required' => true],
	'seal_stamp'      => ['w' => 720, 'h' => 720, 'tint' => 'gold',   'required' => true],
	'initial_vine'    => ['w' => 600, 'h' => 240, 'tint' => 'border', 'required' => false],
	'drolerie'        => ['w' => 600, 'h' => 300, 'tint' => 'border', 'required' => false],
];

// ---- CLI args ----
$opts = getopt('', ['db', 'family:']);
$useDb = isset($opts['db']);
$onlyFamily = $opts['family'] ?? null;

// ---- Locate rasterizer ----
$rsvg = trim((string)@shell_exec('command -v rsvg-convert 2>/dev/null'));
if ($rsvg === '') $rsvg = '/opt/homebrew/bin/rsvg-convert';
if (!is_file($rsvg) || !is_executable($rsvg)) {
	$inkscape = trim((string)@shell_exec('command -v inkscape 2>/dev/null'));
	if ($inkscape !== '') {
		$rsvg = $inkscape;
		$useInkscape = true;
	} else {
		fwrite(STDERR, "ERROR: neither rsvg-convert nor inkscape found in PATH\n");
		fwrite(STDERR, "Install one of:\n  brew install librsvg\n  brew install --cask inkscape\n");
		exit(1);
	}
}
$useInkscape = isset($useInkscape);

echo "rasterizer: $rsvg" . ($useInkscape ? " (inkscape mode)" : "") . "\n";

// ---- Load families ----
$families = json_decode((string)file_get_contents(FAMILIES_JSON), true);
if (!is_array($families)) { fwrite(STDERR, "Could not load families.json\n"); exit(1); }

// ---- Optional DB connection ----
$pdo = null;
if ($useDb) {
	$candidates = [
		// Docker host -> mariadb:24306 (per memory)
		['host' => '127.0.0.1', 'port' => 24306, 'user' => 'root', 'pass' => 'root'],
		// docker-compose default
		['host' => '127.0.0.1', 'port' => 19306, 'user' => 'ork',  'pass' => 'secret'],
		['host' => '127.0.0.1', 'port' => 19306, 'user' => 'root', 'pass' => 'root'],
	];
	foreach ($candidates as $c) {
		try {
			$pdo = new PDO("mysql:host={$c['host']};port={$c['port']};dbname=ork;charset=utf8mb4", $c['user'], $c['pass'], [
				PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
				PDO::ATTR_TIMEOUT => 2,
			]);
			echo "DB: connected to {$c['host']}:{$c['port']} as {$c['user']}\n";
			break;
		} catch (Throwable $e) { /* try next */ }
	}
	if (!$pdo) {
		fwrite(STDERR, "WARN: --db passed but no candidate DB connection succeeded; skipping upserts\n");
	}
}

// ---- Process each family ----
$attribRows = [];
$counts = ['rasterized' => 0, 'tinted' => 0, 'db_upserted' => 0, 'skipped' => 0, 'warnings' => 0];

foreach ($families as $familyKey => $family) {
	if ($onlyFamily !== null && $familyKey !== $onlyFamily) continue;
	$familyDir = ASSETS_DIR . '/' . $familyKey;
	if (!is_dir($familyDir)) {
		echo "SKIP $familyKey: no asset dir at $familyDir\n";
		$counts['skipped']++;
		continue;
	}
	echo "\n=== $familyKey ===\n";

	foreach (ROLE_SPECS as $role => $spec) {
		$svgPath = "$familyDir/$role.svg";
		if (!is_file($svgPath)) {
			if ($spec['required']) {
				echo "  – $role.svg: not present (optional → skip)\n";
			}
			continue;
		}

		// Validate grayscale-with-alpha
		$svg = (string)file_get_contents($svgPath);
		$validation = validate_grayscale_svg($svg);
		if ($validation !== true) {
			fwrite(STDERR, "  WARN $role.svg: $validation\n");
			$counts['warnings']++;
		}

		// Rasterize source to grayscale PNG (alpha preserved)
		$rasterPath = "$familyDir/$role.png";
		$ok = rasterize_svg($rsvg, $svgPath, $rasterPath, $spec['w'], $spec['h'], $useInkscape);
		if (!$ok) {
			fwrite(STDERR, "  FAIL $role.svg → PNG rasterization failed\n");
			continue;
		}
		$counts['rasterized']++;

		// Channel-multiply to tint token color
		$tintToken = $spec['tint'];
		$tintHex = $family['palette'][$tintToken] ?? null;
		if ($tintHex === null) {
			fwrite(STDERR, "  WARN $role: family $familyKey has no palette token '$tintToken'; using #888888 fallback\n");
			$tintHex = '#888888';
			$counts['warnings']++;
		}
		$tintedPath = "$familyDir/{$role}__{$tintToken}.png";
		channel_multiply_png($rasterPath, $tintedPath, $tintHex);
		$counts['tinted']++;
		echo "  ✓ $role → " . basename($tintedPath) . " (tint $tintHex)\n";

		// Pull attribution from SVG <desc>
		$desc = '';
		if (preg_match('#<desc[^>]*>(.*?)</desc>#s', $svg, $m)) {
			$desc = trim(strip_tags($m[1]));
		}
		$license = 'CC0';
		if (preg_match('/license:\s*([^,\.\n]+)/i', $desc, $m)) $license = trim($m[1]);

		$attribRows[] = [
			'family' => $familyKey,
			'role'   => $role,
			'file'   => "families/$familyKey/{$role}__{$tintToken}.png",
			'attribution' => $desc,
			'license' => $license,
		];

		// DB upsert
		if ($pdo) {
			$relPath = "families/$familyKey/{$role}__{$tintToken}.png";
			$stat = stat($tintedPath);
			[$pngW, $pngH] = getimagesize($tintedPath);
			$existing = $pdo->prepare("SELECT scroll_artwork_id FROM ork_scroll_artwork WHERE family_key = ? AND asset_role = ?");
			$existing->execute([$familyKey, $role]);
			$id = $existing->fetchColumn();

			if ($id) {
				$upd = $pdo->prepare("UPDATE ork_scroll_artwork SET file_name=?, original_file_name=?, width=?, height=?, file_size=?, tint_mode='channel_multiply', source_attribution=?, source_license=?, status='approved', system_owned=1 WHERE scroll_artwork_id=?");
				$upd->execute([$relPath, "$role.svg", $pngW, $pngH, $stat['size'], $desc, $license, $id]);
			} else {
				$ins = $pdo->prepare("INSERT INTO ork_scroll_artwork (uploader_mundane_id, name, description, layout_location, file_name, original_file_name, width, height, file_size, license_signer_name, license_signed_at, status, system_owned, family_key, asset_role, tint_mode, source_attribution, source_license) VALUES (0, ?, ?, ?, ?, ?, ?, ?, ?, 'system', NOW(), 'approved', 1, ?, ?, 'channel_multiply', ?, ?)");
				$ins->execute([
					"$familyKey: $role",
					$desc ?: "Curated $role for $familyKey",
					role_to_layout($role),
					$relPath,
					"$role.svg",
					$pngW, $pngH, $stat['size'],
					$familyKey, $role,
					$desc, $license,
				]);
			}
			$counts['db_upserted']++;
		}
	}
}

// ---- Refresh ATTRIBUTION.md ----
update_attribution_md($attribRows);

// ---- Report ----
echo "\n=== summary ===\n";
foreach ($counts as $k => $v) echo "  $k: $v\n";
echo "\nDone.\n";

// =========================================================================
//  helpers
// =========================================================================

function rasterize_svg(string $rasterizer, string $svg, string $out, int $w, int $h, bool $useInkscape): bool {
	$svgArg = escapeshellarg($svg);
	$outArg = escapeshellarg($out);
	if ($useInkscape) {
		$cmd = "$rasterizer --export-type=png --export-filename=$outArg --export-width=$w --export-height=$h $svgArg 2>&1";
	} else {
		$cmd = "$rasterizer -w $w -h $h -o $outArg $svgArg 2>&1";
	}
	$output = []; $rc = 0;
	exec($cmd, $output, $rc);
	if ($rc !== 0) {
		fwrite(STDERR, "rasterize failed: " . implode("\n", $output) . "\n");
		return false;
	}
	return is_file($out) && filesize($out) > 0;
}

/**
 * Channel-multiply: output_R = (gray/255) * target_R; same G, B; preserve alpha.
 * Source PNG should be grayscale-with-alpha (R==G==B). For non-grayscale sources
 * we use luminance (0.299R + 0.587G + 0.114B) so the result is still defensible.
 */
function channel_multiply_png(string $srcPath, string $dstPath, string $tintHex): void {
	$src = imagecreatefrompng($srcPath);
	if (!$src) throw new RuntimeException("Could not load $srcPath");
	imagealphablending($src, false);
	imagesavealpha($src, true);
	$w = imagesx($src); $h = imagesy($src);

	[$tr, $tg, $tb] = hex_to_rgb($tintHex);

	$dst = imagecreatetruecolor($w, $h);
	imagealphablending($dst, false);
	imagesavealpha($dst, true);
	$transparent = imagecolorallocatealpha($dst, 0, 0, 0, 127);
	imagefilledrectangle($dst, 0, 0, $w, $h, $transparent);

	for ($y = 0; $y < $h; $y++) {
		for ($x = 0; $x < $w; $x++) {
			$rgba = imagecolorat($src, $x, $y);
			$a = ($rgba >> 24) & 0x7F;        // 0=opaque, 127=transparent in GD
			if ($a === 127) continue;          // fully transparent — leave dst transparent
			$r = ($rgba >> 16) & 0xFF;
			$g = ($rgba >> 8) & 0xFF;
			$b = $rgba & 0xFF;
			// Use luminance (handles both pure-grayscale and lightly-mixed sources).
			$lum = (int)round(0.299 * $r + 0.587 * $g + 0.114 * $b);
			$nr = (int)round($lum / 255 * $tr);
			$ng = (int)round($lum / 255 * $tg);
			$nb = (int)round($lum / 255 * $tb);
			$col = imagecolorallocatealpha($dst, $nr, $ng, $nb, $a);
			imagesetpixel($dst, $x, $y, $col);
		}
	}
	imagepng($dst, $dstPath, 6);
	imagedestroy($src); imagedestroy($dst);
}

/**
 * Validate that an SVG is grayscale-with-alpha (luminance-only).
 * Strategy: scan all fill="..." and stroke="..." attributes and CSS color
 * property values; reject if any is a non-grayscale color.
 * Returns true on pass, or a string error message on fail.
 *
 * Tolerates: #000, #FFF, named "black"/"white"/"none"/"transparent",
 * grayscale hex (R==G==B in normalized form), opacity attrs, gradients
 * referencing only grayscale stops.
 */
function validate_grayscale_svg(string $svg) {
	$findings = [];

	// Hex colors
	if (preg_match_all('/#([0-9a-fA-F]{3,8})\b/', $svg, $m)) {
		foreach ($m[1] as $hex) {
			if (strlen($hex) === 8 || strlen($hex) === 4) {
				// RGBA hex: drop alpha bytes
				$hex = strlen($hex) === 8 ? substr($hex, 0, 6) : substr($hex, 0, 3);
			}
			if (strlen($hex) === 3) {
				$r = hexdec($hex[0] . $hex[0]); $g = hexdec($hex[1] . $hex[1]); $b = hexdec($hex[2] . $hex[2]);
			} else {
				$r = hexdec(substr($hex, 0, 2)); $g = hexdec(substr($hex, 2, 2)); $b = hexdec(substr($hex, 4, 2));
			}
			if (!($r === $g && $g === $b)) {
				$findings[] = sprintf('non-grayscale color #%s (rgb %d,%d,%d)', $hex, $r, $g, $b);
			}
		}
	}

	// rgb() / rgba() functional values
	if (preg_match_all('/rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)/', $svg, $m, PREG_SET_ORDER)) {
		foreach ($m as $match) {
			$r = (int)$match[1]; $g = (int)$match[2]; $b = (int)$match[3];
			if (!($r === $g && $g === $b)) $findings[] = sprintf('non-grayscale rgb(%d,%d,%d)', $r, $g, $b);
		}
	}

	// Named colors (allow only grayscale-equivalent names)
	$allowed = ['black', 'white', 'gray', 'grey', 'none', 'transparent', 'currentColor', 'inherit'];
	if (preg_match_all('/(?:fill|stroke|stop-color|color)="([^"]+)"/', $svg, $m)) {
		foreach ($m[1] as $val) {
			$val = trim($val);
			if ($val === '' || $val[0] === '#' || str_starts_with($val, 'rgb') || str_starts_with($val, 'url(')) continue;
			if (!in_array(strtolower($val), array_map('strtolower', $allowed), true)) {
				$findings[] = "non-grayscale named color: $val";
			}
		}
	}

	if (empty($findings)) return true;
	return implode('; ', array_unique($findings));
}

function hex_to_rgb(string $hex): array {
	$h = ltrim($hex, '#');
	if (strlen($h) === 3) $h = $h[0].$h[0].$h[1].$h[1].$h[2].$h[2];
	return [hexdec(substr($h, 0, 2)), hexdec(substr($h, 2, 2)), hexdec(substr($h, 4, 2))];
}

function role_to_layout(string $role): string {
	// Map role → layout_location enum value (ENUM has limited set; pick best fit).
	return match ($role) {
		'frame_corner_nw', 'frame_edge_top' => 'full_border',
		'seal_stamp' => 'top_graphic',
		'initial_vine' => 'border_left',
		'drolerie' => 'border_bottom',
		default => 'full_border',
	};
}

function update_attribution_md(array $rows): void {
	if (!is_file(ATTRIBUTION_MD)) return;
	$existing = (string)file_get_contents(ATTRIBUTION_MD);

	// Build section
	$lines = [];
	$lines[] = "## Curated family asset attribution";
	$lines[] = "";
	$lines[] = "Each row lists a system-owned, palette-tinted asset committed under";
	$lines[] = "`system/assets/scroll/families/<family>/`. Sources listed are the";
	$lines[] = "manuscript or open-content references the SVG was *informed by*; the";
	$lines[] = "SVG path data itself is original procedural geometry committed as";
	$lines[] = "CC0 by the ORK project unless otherwise noted in the row's License.";
	$lines[] = "";
	$lines[] = "| Family | Role | File | Source / informed by | License |";
	$lines[] = "|---|---|---|---|---|";
	usort($rows, fn($a, $b) => strcmp($a['family'] . '|' . $a['role'], $b['family'] . '|' . $b['role']));
	foreach ($rows as $r) {
		$attr = $r['attribution'] !== '' ? str_replace('|', '\\|', $r['attribution']) : '_(procedural, no external reference)_';
		$lines[] = "| {$r['family']} | {$r['role']} | `{$r['file']}` | $attr | {$r['license']} |";
	}
	$section = implode("\n", $lines) . "\n";

	$marker = "## Curated family asset attribution";
	if (strpos($existing, $marker) !== false) {
		$updated = preg_replace('/## Curated family asset attribution.*$/s', $section, $existing);
	} else {
		$updated = rtrim($existing) . "\n\n" . $section;
	}
	file_put_contents(ATTRIBUTION_MD, $updated);
	echo "ATTRIBUTION.md updated (" . count($rows) . " asset rows)\n";
}
