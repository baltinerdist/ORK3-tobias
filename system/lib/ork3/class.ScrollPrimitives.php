<?php

/**
 * Foundation drawing primitives for the scroll redesign — PHP/GD mirror.
 * Mirrors orkui/template/revised-frontend/scroll/scroll-primitives.js — keep in sync.
 *
 * All primitives consume palette tokens (never hard-coded hex).
 *
 * See: docs/superpowers/specs/2026-04-25-scroll-aesthetic-redesign-design.md
 */
class ScrollPrimitives {

	// ----------------------------------------------------------------------
	// Gilding gradient — fill a rect with multi-stop gold gradient.
	// Always use this for any "gold" element — never imagefill with a flat gold color.
	// ----------------------------------------------------------------------
	public static function fillGildedRect($img, int $x, int $y, int $w, int $h, string $gold, string $goldHi, float $angle = 2.356): void {
		$dark = ScrollPalette::darken($gold, 0.30);
		$stops = [
			[0.00, ScrollPalette::hexToRgb($dark)],
			[0.35, ScrollPalette::hexToRgb($gold)],
			[0.50, ScrollPalette::hexToRgb($goldHi)],
			[0.65, ScrollPalette::hexToRgb($gold)],
			[1.00, ScrollPalette::hexToRgb($dark)],
		];
		$cx = $x + $w / 2; $cy = $y + $h / 2;
		$dirx = cos($angle); $diry = sin($angle);
		$halfExtent = abs($dirx) * ($w / 2) + abs($diry) * ($h / 2);
		for ($yy = $y; $yy < $y + $h; $yy++) {
			for ($xx = $x; $xx < $x + $w; $xx++) {
				$proj = (($xx - $cx) * $dirx + ($yy - $cy) * $diry) / max(1, $halfExtent);
				$t = ($proj + 1) / 2;
				[$r, $g, $b] = self::lerpStops($stops, $t);
				$col = imagecolorallocate($img, $r, $g, $b);
				imagesetpixel($img, $xx, $yy, $col);
			}
		}
	}

	/**
	 * Filled circle with radial gilding gradient — for besants and small gold elements.
	 */
	public static function fillGildedCircle($img, int $cx, int $cy, int $r, string $gold, string $goldHi): void {
		$dark = ScrollPalette::darken($gold, 0.40);
		[$gr, $gg, $gb] = ScrollPalette::hexToRgb($gold);
		[$hr, $hg, $hb] = ScrollPalette::hexToRgb($goldHi);
		[$dr, $dg, $db] = ScrollPalette::hexToRgb($dark);
		for ($y = -$r; $y <= $r; $y++) {
			for ($x = -$r; $x <= $r; $x++) {
				$d = sqrt($x*$x + $y*$y);
				if ($d > $r) continue;
				$ox = $x + 2; $oy = $y + 2;
				$od = min(1, sqrt($ox*$ox + $oy*$oy) / max(1, $r + 2));
				if ($od < 0.4) {
					$f = $od / 0.4;
					$rr = (int)round($hr + ($gr - $hr) * $f);
					$gg2 = (int)round($hg + ($gg - $hg) * $f);
					$bb = (int)round($hb + ($gb - $hb) * $f);
				} else {
					$f = ($od - 0.4) / 0.6;
					$rr = (int)round($gr + ($dr - $gr) * $f);
					$gg2 = (int)round($gg + ($dg - $gg) * $f);
					$bb = (int)round($gb + ($db - $gb) * $f);
				}
				$col = imagecolorallocate($img, $rr, $gg2, $bb);
				imagesetpixel($img, $cx + $x, $cy + $y, $col);
			}
		}
	}

	private static function lerpStops(array $stops, float $t): array {
		$t = max(0, min(1, $t));
		for ($i = 0; $i < count($stops) - 1; $i++) {
			[$p0, $rgb0] = $stops[$i]; [$p1, $rgb1] = $stops[$i + 1];
			if ($t >= $p0 && $t <= $p1) {
				$f = ($p1 - $p0) > 0 ? ($t - $p0) / ($p1 - $p0) : 0;
				return [
					(int)round($rgb0[0] + ($rgb1[0] - $rgb0[0]) * $f),
					(int)round($rgb0[1] + ($rgb1[1] - $rgb0[1]) * $f),
					(int)round($rgb0[2] + ($rgb1[2] - $rgb0[2]) * $f),
				];
			}
		}
		return $stops[count($stops) - 1][1];
	}

	// ----------------------------------------------------------------------
	// Parchment texture — base + radial vignette + foxing.
	// ----------------------------------------------------------------------
	public static function applyParchment($img, int $w, int $h, string $bg, string $groundA, string $agingPreset = 'balanced'): void {
		// 1. base
		[$br, $bgg, $bb] = ScrollPalette::hexToRgb($bg);
		$baseCol = imagecolorallocate($img, $br, $bgg, $bb);
		imagefilledrectangle($img, 0, 0, $w - 1, $h - 1, $baseCol);

		// 2. radial vignette to groundA (sampled per-block to keep it tractable at 3300×2550)
		[$gr, $gg, $gb] = ScrollPalette::hexToRgb($groundA);
		$alpha = ['light' => 0.25, 'balanced' => 0.40, 'heavy' => 0.55][$agingPreset] ?? 0.40;
		$cx = $w / 2; $cy = $h / 2;
		$rInner = min($w, $h) * 0.4;
		$rOuter = max($w, $h) * 0.7;
		// Use per-pixel only at preview scale; at print scale (3×) use 4×4 blocks for speed.
		$step = $w > 1500 ? 4 : 1;
		for ($y = 0; $y < $h; $y += $step) {
			for ($x = 0; $x < $w; $x += $step) {
				$d = sqrt(($x - $cx) ** 2 + ($y - $cy) ** 2);
				if ($d <= $rInner) continue;
				$f = min(1, ($d - $rInner) / ($rOuter - $rInner)) * $alpha;
				$rgb = imagecolorat($img, $x, $y);
				$pr = ($rgb >> 16) & 0xFF; $pg = ($rgb >> 8) & 0xFF; $pb = $rgb & 0xFF;
				$nr = (int)round($pr * (1 - $f) + $gr * $f);
				$ng = (int)round($pg * (1 - $f) + $gg * $f);
				$nb = (int)round($pb * (1 - $f) + $gb * $f);
				$col = imagecolorallocate($img, $nr, $ng, $nb);
				if ($step === 1) {
					imagesetpixel($img, $x, $y, $col);
				} else {
					imagefilledrectangle($img, $x, $y, min($w-1, $x+$step-1), min($h-1, $y+$step-1), $col);
				}
			}
		}

		// 3. fiber noise — sparse horizontal lines
		$noiseCol = imagecolorallocatealpha($img, 101, 79, 40, 110);
		$lineStep = $w > 1500 ? 6 : 2;
		for ($y = 0; $y < $h; $y += $lineStep) imageline($img, 0, $y, $w - 1, $y, $noiseCol);

		// 4. foxing
		$density = ['light' => 12, 'balanced' => 35, 'heavy' => 70][$agingPreset] ?? 35;
		mt_srand($w * 7919 + $h * 6151);
		for ($i = 0; $i < $density; $i++) {
			$x = mt_rand(0, $w - 1); $y = mt_rand(0, $h - 1);
			$r = max(1, (int)(1 + mt_rand(0, 25) / 10));
			$col = mt_rand(0, 1)
				? imagecolorallocatealpha($img, 92, 63, 26, 90)
				: imagecolorallocatealpha($img, 107, 69, 35, 90);
			imagefilledellipse($img, $x, $y, $r * 2, $r * 2, $col);
		}
	}

	// ----------------------------------------------------------------------
	// Stub frame — ink rules + 4 corner gilded besants.
	// Plan 2 replaces with drawFrameFamily using curated assets.
	// ----------------------------------------------------------------------
	public static function drawStubFrame($img, int $w, int $h, array $palette): void {
		$inset = (int)round(28 * $w / 480);
		[$tr, $tg, $tb] = ScrollPalette::hexToRgb($palette['text']);
		$inkCol = imagecolorallocate($img, $tr, $tg, $tb);
		imagerectangle($img, $inset, $inset, $w - $inset, $h - $inset, $inkCol);
		imagerectangle($img, $inset + 4, $inset + 4, $w - $inset - 4, $h - $inset - 4, $inkCol);

		$r = max(4, (int)round(7 * $w / 480));
		foreach ([[$inset, $inset], [$w - $inset, $inset], [$inset, $h - $inset], [$w - $inset, $h - $inset]] as [$cx, $cy]) {
			self::fillGildedCircle($img, $cx, $cy, $r, $palette['gold'], $palette['gold_highlight']);
		}
	}
}
