<?php

/**
 * Palette schema, validator, and color utilities for the scroll redesign.
 * Required tokens: bg, text, accent, border, gold, gold_highlight, wax, ground_a.
 * Forbidden values: pure black or pure white in any token (real ink/parchment colors only).
 *
 * See: docs/superpowers/specs/2026-04-25-scroll-aesthetic-redesign-design.md
 */
class ScrollPalette {

	const REQUIRED_TOKENS = ['bg', 'text', 'accent', 'border', 'gold', 'gold_highlight', 'wax', 'ground_a'];
	const FORBIDDEN = ['#000000', '#FFFFFF', '#000', '#FFF'];

	/** @return array{0:bool, 1:string} */
	public static function validate(array $palette): array {
		foreach (self::REQUIRED_TOKENS as $t) {
			if (!isset($palette[$t])) return [false, "missing required token: $t"];
			$v = strtoupper(trim($palette[$t]));
			if (!preg_match('/^#[0-9A-F]{3}([0-9A-F]{3})?$/', $v)) {
				return [false, "token $t is not a valid hex color: {$palette[$t]}"];
			}
			if (in_array($v, array_map('strtoupper', self::FORBIDDEN), true)) {
				return [false, "token $t may not be pure black or pure white: {$palette[$t]}"];
			}
		}
		return [true, ''];
	}

	/** @return array{0:int, 1:int, 2:int} */
	public static function hexToRgb(string $hex): array {
		$h = ltrim($hex, '#');
		if (strlen($h) === 3) $h = $h[0].$h[0].$h[1].$h[1].$h[2].$h[2];
		return [hexdec(substr($h, 0, 2)), hexdec(substr($h, 2, 2)), hexdec(substr($h, 4, 2))];
	}

	public static function lighten(string $hex, float $pct): string {
		[$r, $g, $b] = self::hexToRgb($hex);
		$r = min(255, (int)round($r + (255 - $r) * $pct));
		$g = min(255, (int)round($g + (255 - $g) * $pct));
		$b = min(255, (int)round($b + (255 - $b) * $pct));
		return sprintf('#%02X%02X%02X', $r, $g, $b);
	}

	public static function darken(string $hex, float $pct): string {
		[$r, $g, $b] = self::hexToRgb($hex);
		$r = max(0, (int)round($r * (1 - $pct)));
		$g = max(0, (int)round($g * (1 - $pct)));
		$b = max(0, (int)round($b * (1 - $pct)));
		return sprintf('#%02X%02X%02X', $r, $g, $b);
	}
}
