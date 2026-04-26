<?php

/**
 * Family-specific decorative primitives — frames, seal stamps, historiated initials,
 * drôleries, banderoles, aging filters. Procedural GD draws (no external assets, no
 * SVG rasterizer required). Each family has its own visual signature here.
 *
 * Mirrors orkui/template/revised-frontend/scroll/scroll-decoration.js where applicable.
 *
 * Methods are organized by primitive:
 *   drawFrame($img, $w, $h, $palette, $frameKind)         — dispatches to drawFrame_<kind>
 *   drawSealStamp($img, $cx, $cy, $r, $palette, $kind)    — dispatches to drawSealStamp_<kind>
 *   drawHistoriatedInitial($img, $opts)                   — 3-zone parameterized
 *   drawBanderole($img, $opts)                            — curling ribbon banner
 *   drawDrolerie($img, $x, $y, $w, $h, $palette, $kind)   — marginal grotesque
 *   applyBurntEdge($img, $w, $h, $intensity)              — Charred Edict
 *   applyFoldCreases($img, $w, $h)                        — Charred Edict
 *   drawHeraldryMedallion($img, $cx, $cy, $r, $imgPath, $palette)
 *   drawStarField($img, $w, $h, $palette)                 — Astral Codex
 *
 * All hex colors come from the family palette token (never hard-coded).
 */
class ScrollDecoration {

	const FRAME_INSET = 28; // preview-pixel inset; scaled by caller

	// ================================================================
	//  Frames
	// ================================================================

	public static function drawFrame($img, int $w, int $h, array $palette, string $kind): void {
		$method = 'drawFrame_' . $kind;
		if (method_exists(self::class, $method)) {
			self::$method($img, $w, $h, $palette);
		} else {
			self::drawFrame_gothic_ivy($img, $w, $h, $palette);
		}
	}

	/** Northern Gothic — running ivy with gilded besants at corners + midpoints. */
	public static function drawFrame_gothic_ivy($img, int $w, int $h, array $palette): void {
		$scale = $w / 480;
		$inset = (int)(self::FRAME_INSET * $scale);
		[$tr, $tg, $tb] = ScrollPalette::hexToRgb($palette['text']);
		[$bgr, $bgg, $bgb] = ScrollPalette::hexToRgb($palette['border']); // ivy green
		$ink = imagecolorallocatealpha($img, $tr, $tg, $tb, 70);
		$ivy = imagecolorallocate($img, $bgr, $bgg, $bgb);

		// Inner ink rules (double)
		imagerectangle($img, $inset + (int)(4 * $scale), $inset + (int)(4 * $scale), $w - $inset - (int)(4 * $scale), $h - $inset - (int)(4 * $scale), $ink);

		// Running ivy: top + bottom + left + right edges with sine waves
		$amp = max(2, (int)(4 * $scale));
		$step = max(8, (int)(16 * $scale));
		// Top
		for ($x = $inset; $x < $w - $inset; $x += 2) {
			$y = $inset - (int)(($amp) * sin(($x - $inset) * 2 * M_PI / $step / 2));
			imagesetpixel($img, $x, $y, $ivy);
			imagesetpixel($img, $x, $y - 1, $ivy);
		}
		// Bottom
		for ($x = $inset; $x < $w - $inset; $x += 2) {
			$y = $h - $inset + (int)(($amp) * sin(($x - $inset) * 2 * M_PI / $step / 2));
			imagesetpixel($img, $x, $y, $ivy);
			imagesetpixel($img, $x, $y + 1, $ivy);
		}
		// Left
		for ($y = $inset; $y < $h - $inset; $y += 2) {
			$x = $inset - (int)(($amp) * sin(($y - $inset) * 2 * M_PI / $step / 2));
			imagesetpixel($img, $x, $y, $ivy);
			imagesetpixel($img, $x - 1, $y, $ivy);
		}
		// Right
		for ($y = $inset; $y < $h - $inset; $y += 2) {
			$x = $w - $inset + (int)(($amp) * sin(($y - $inset) * 2 * M_PI / $step / 2));
			imagesetpixel($img, $x, $y, $ivy);
			imagesetpixel($img, $x + 1, $y, $ivy);
		}

		// Ivy leaves at regular intervals
		$leafStep = max(20, (int)(36 * $scale));
		$leafR = max(3, (int)(5 * $scale));
		for ($x = $inset + $leafStep; $x < $w - $inset; $x += $leafStep) {
			self::drawIvyLeaf($img, $x, $inset - (int)(8 * $scale), $leafR, $ivy, 'down');
			self::drawIvyLeaf($img, $x, $h - $inset + (int)(8 * $scale), $leafR, $ivy, 'up');
		}
		for ($y = $inset + $leafStep; $y < $h - $inset; $y += $leafStep) {
			self::drawIvyLeaf($img, $inset - (int)(8 * $scale), $y, $leafR, $ivy, 'right');
			self::drawIvyLeaf($img, $w - $inset + (int)(8 * $scale), $y, $leafR, $ivy, 'left');
		}

		// Gilded besants at 4 corners
		foreach ([[$inset, $inset], [$w - $inset, $inset], [$inset, $h - $inset], [$w - $inset, $h - $inset]] as [$cx, $cy]) {
			ScrollPrimitives::fillGildedCircle($img, $cx, $cy, max(5, (int)(9 * $scale)), $palette['gold'], $palette['gold_highlight']);
		}
		// Midpoint besants on edges (smaller)
		$mr = max(3, (int)(5 * $scale));
		ScrollPrimitives::fillGildedCircle($img, $w / 2, $inset, $mr, $palette['gold'], $palette['gold_highlight']);
		ScrollPrimitives::fillGildedCircle($img, $w / 2, $h - $inset, $mr, $palette['gold'], $palette['gold_highlight']);
		ScrollPrimitives::fillGildedCircle($img, $inset, $h / 2, $mr, $palette['gold'], $palette['gold_highlight']);
		ScrollPrimitives::fillGildedCircle($img, $w - $inset, $h / 2, $mr, $palette['gold'], $palette['gold_highlight']);
	}

	private static function drawIvyLeaf($img, int $cx, int $cy, int $r, int $color, string $dir): void {
		// Simple rounded teardrop pointing in $dir
		$pts = [];
		switch ($dir) {
			case 'down':  $pts = [$cx, $cy + $r, $cx - $r, $cy - $r/2, $cx, $cy - $r, $cx + $r, $cy - $r/2]; break;
			case 'up':    $pts = [$cx, $cy - $r, $cx - $r, $cy + $r/2, $cx, $cy + $r, $cx + $r, $cy + $r/2]; break;
			case 'left':  $pts = [$cx - $r, $cy, $cx + $r/2, $cy - $r, $cx + $r, $cy, $cx + $r/2, $cy + $r]; break;
			case 'right': $pts = [$cx + $r, $cy, $cx - $r/2, $cy - $r, $cx - $r, $cy, $cx - $r/2, $cy + $r]; break;
		}
		imagefilledpolygon($img, array_map('intval', $pts), 4, $color);
	}

	/** Hibernian Knotwork — Insular interlace. */
	public static function drawFrame_insular_knot($img, int $w, int $h, array $palette): void {
		$scale = $w / 480;
		$inset = (int)(self::FRAME_INSET * $scale);
		[$br, $bg, $bb] = ScrollPalette::hexToRgb($palette['border']);
		$col = imagecolorallocate($img, $br, $bg, $bb);
		[$ar, $ag, $ab] = ScrollPalette::hexToRgb($palette['accent']);
		$accent = imagecolorallocate($img, $ar, $ag, $ab);

		// Knot band along all 4 sides — interlocking arcs
		$band = max(8, (int)(14 * $scale));
		$step = max(12, (int)(20 * $scale));

		// Helper: draw an interlocked-loop tile
		$tile = function(int $cx, int $cy, int $size, int $col1, int $col2) use ($img) {
			$r = (int)($size * 0.4);
			imagearc($img, $cx, $cy, $size, $size, 0, 360, $col1);
			imagearc($img, $cx, $cy, $size, $size, 30, 60, $col2);
			imagearc($img, $cx, $cy, $size, $size, 120, 150, $col2);
			imagefilledellipse($img, $cx, $cy, max(2, (int)$size/4), max(2, (int)$size/4), $col2);
		};

		// Top & bottom bands
		for ($x = $inset + $step / 2; $x < $w - $inset; $x += $step) {
			$tile((int)$x, $inset - $band / 2, $band, $col, $accent);
			$tile((int)$x, $h - $inset + $band / 2, $band, $col, $accent);
		}
		// Left & right bands
		for ($y = $inset + $step / 2; $y < $h - $inset; $y += $step) {
			$tile($inset - $band / 2, (int)$y, $band, $col, $accent);
			$tile($w - $inset + $band / 2, (int)$y, $band, $col, $accent);
		}

		// Triskele corners
		foreach ([[$inset - $band, $inset - $band], [$w - $inset + $band, $inset - $band], [$inset - $band, $h - $inset + $band], [$w - $inset + $band, $h - $inset + $band]] as [$cx, $cy]) {
			self::drawTriskele($img, (int)$cx, (int)$cy, max(8, (int)(14 * $scale)), $palette);
		}
	}

	private static function drawTriskele($img, int $cx, int $cy, int $r, array $palette): void {
		[$ar, $ag, $ab] = ScrollPalette::hexToRgb($palette['accent']);
		[$br, $bg, $bb] = ScrollPalette::hexToRgb($palette['border']);
		$a = imagecolorallocate($img, $ar, $ag, $ab);
		$b = imagecolorallocate($img, $br, $bg, $bb);
		// 3 spirals at 120° offsets
		for ($k = 0; $k < 3; $k++) {
			$angle = $k * 2 * M_PI / 3;
			$ox = (int)($cx + cos($angle) * $r * 0.4);
			$oy = (int)($cy + sin($angle) * $r * 0.4);
			imagefilledellipse($img, $ox, $oy, max(4, $r / 3), max(4, $r / 3), $k % 2 ? $a : $b);
		}
		imagefilledellipse($img, $cx, $cy, max(3, (int)($r / 4)), max(3, (int)($r / 4)), $a);
	}

	/** Provençal Bestiary — asymmetric ivy, heavy on left + top, light right + bottom. */
	public static function drawFrame_asymmetric_ivy_grotesque($img, int $w, int $h, array $palette): void {
		$scale = $w / 480;
		$inset = (int)(self::FRAME_INSET * $scale);
		[$bgr, $bgg, $bgb] = ScrollPalette::hexToRgb($palette['border']);
		$ivy = imagecolorallocate($img, $bgr, $bgg, $bgb);
		[$ar, $ag, $ab] = ScrollPalette::hexToRgb($palette['accent']);
		$accent = imagecolorallocate($img, $ar, $ag, $ab);

		// Heavy left + top: dense ivy with leaves
		$step = max(8, (int)(14 * $scale));
		for ($y = $inset; $y < $h - $inset; $y += 2) {
			$x = $inset - (int)((6 * $scale) * sin($y * M_PI / $step));
			imagesetpixel($img, $x, $y, $ivy);
			imagesetpixel($img, $x - 1, $y, $ivy);
			imagesetpixel($img, $x - 2, $y, $ivy);
		}
		for ($x = $inset; $x < $w - $inset; $x += 2) {
			$y = $inset - (int)((6 * $scale) * sin($x * M_PI / $step));
			imagesetpixel($img, $x, $y, $ivy);
			imagesetpixel($img, $x, $y - 1, $ivy);
			imagesetpixel($img, $x, $y - 2, $ivy);
		}

		// Light right + bottom: thinner ink line
		[$tr, $tg, $tb] = ScrollPalette::hexToRgb($palette['text']);
		$ink = imagecolorallocatealpha($img, $tr, $tg, $tb, 70);
		imageline($img, $w - $inset, $inset, $w - $inset, $h - $inset, $ink);
		imageline($img, $inset, $h - $inset, $w - $inset, $h - $inset, $ink);

		// Leaves on heavy edges
		$leafStep = max(20, (int)(28 * $scale));
		for ($y = $inset + $leafStep; $y < $h - $inset; $y += $leafStep) {
			self::drawIvyLeaf($img, $inset - (int)(10 * $scale), $y, max(4, (int)(6 * $scale)), $ivy, 'right');
			imagefilledellipse($img, $inset - (int)(14 * $scale), $y - $leafStep / 2, max(3, (int)(4 * $scale)), max(3, (int)(4 * $scale)), $accent);
		}
		for ($x = $inset + $leafStep; $x < $w - $inset; $x += $leafStep) {
			self::drawIvyLeaf($img, $x, $inset - (int)(10 * $scale), max(4, (int)(6 * $scale)), $ivy, 'down');
		}
	}

	/** Crimson Decree — Gothic arch frame. */
	public static function drawFrame_gothic_arch($img, int $w, int $h, array $palette): void {
		$scale = $w / 480;
		$inset = (int)(self::FRAME_INSET * $scale);
		[$ar, $ag, $ab] = ScrollPalette::hexToRgb($palette['accent']);
		$accent = imagecolorallocate($img, $ar, $ag, $ab);
		// Outer accent stroke (the "arch" line — pointed at top)
		$archTop = (int)($inset * 1.2);
		$pts = [
			$inset, $h - $inset,
			$inset, $archTop * 2,
			$w / 2, $archTop,         // pointed apex
			$w - $inset, $archTop * 2,
			$w - $inset, $h - $inset,
		];
		imagepolygon($img, array_map('intval', $pts), count($pts) / 2, $accent);
		// Inner gilded line
		$pts2 = [
			$inset + 4, $h - $inset - 4,
			$inset + 4, $archTop * 2 + 4,
			$w / 2, $archTop + 6,
			$w - $inset - 4, $archTop * 2 + 4,
			$w - $inset - 4, $h - $inset - 4,
		];
		[$gr, $gg, $gb] = ScrollPalette::hexToRgb($palette['gold']);
		$goldCol = imagecolorallocate($img, $gr, $gg, $gb);
		imagepolygon($img, array_map('intval', $pts2), count($pts2) / 2, $goldCol);

		// Gilded fleurs at 4 corners
		foreach ([[$inset, $h - $inset], [$w - $inset, $h - $inset], [(int)($w / 2 - 12 * $scale), $archTop + 4], [(int)($w / 2 + 12 * $scale), $archTop + 4]] as [$cx, $cy]) {
			self::drawFleurDeLis($img, (int)$cx, (int)$cy, max(6, (int)(10 * $scale)), $palette['gold'], $palette['gold_highlight']);
		}
	}

	private static function drawFleurDeLis($img, int $cx, int $cy, int $r, string $gold, string $goldHi): void {
		[$gR, $gG, $gB] = ScrollPalette::hexToRgb($gold);
		$col = imagecolorallocate($img, $gR, $gG, $gB);
		// Three lobes: center spike + 2 side curls
		$pts = [
			$cx, $cy - $r,
			$cx + (int)($r * 0.6), $cy + (int)($r * 0.2),
			$cx + (int)($r * 0.3), $cy + (int)($r * 0.6),
			$cx, $cy + $r,
			$cx - (int)($r * 0.3), $cy + (int)($r * 0.6),
			$cx - (int)($r * 0.6), $cy + (int)($r * 0.2),
		];
		imagefilledpolygon($img, array_map('intval', $pts), 6, $col);
		// Cross-band
		imagefilledrectangle($img, $cx - (int)($r * 0.7), $cy + (int)($r * 0.2), $cx + (int)($r * 0.7), $cy + (int)($r * 0.4), $col);
	}

	/** Forest Reverie — organic vine that breaks the frame line. */
	public static function drawFrame_organic_vine($img, int $w, int $h, array $palette): void {
		$scale = $w / 480;
		$inset = (int)(self::FRAME_INSET * $scale);
		[$bgr, $bgg, $bgb] = ScrollPalette::hexToRgb($palette['border']);
		$vine = imagecolorallocate($img, $bgr, $bgg, $bgb);
		[$ar, $ag, $ab] = ScrollPalette::hexToRgb($palette['accent']);
		$leaf = imagecolorallocate($img, $ar, $ag, $ab);

		// Sinuous vine on left + right edges, breaking out of frame
		$breakOut = (int)(8 * $scale);
		for ($y = $inset; $y < $h - $inset; $y += 2) {
			$amp = ($y - $inset) / max(1, ($h - 2 * $inset));
			$x1 = $inset - (int)(($breakOut * 2) * sin($y * M_PI / (40 * $scale)));
			$x2 = $w - $inset + (int)(($breakOut * 2) * sin($y * M_PI / (40 * $scale)));
			imagefilledellipse($img, $x1, $y, 2, 2, $vine);
			imagefilledellipse($img, $x2, $y, 2, 2, $vine);
		}

		// Leaves at intervals
		$leafStep = max(30, (int)(48 * $scale));
		for ($y = $inset + 20; $y < $h - $inset; $y += $leafStep) {
			$x1 = $inset - (int)(($breakOut * 2) * sin($y * M_PI / (40 * $scale)));
			$x2 = $w - $inset + (int)(($breakOut * 2) * sin($y * M_PI / (40 * $scale)));
			self::drawIvyLeaf($img, $x1 - (int)(8 * $scale), $y, max(4, (int)(7 * $scale)), $leaf, 'left');
			self::drawIvyLeaf($img, $x2 + (int)(8 * $scale), $y, max(4, (int)(7 * $scale)), $leaf, 'right');
		}

		// Top + bottom: simpler horizontal vine
		for ($x = $inset; $x < $w - $inset; $x += 2) {
			$y1 = $inset - (int)(($breakOut) * sin($x * M_PI / (30 * $scale)));
			$y2 = $h - $inset + (int)(($breakOut) * sin($x * M_PI / (30 * $scale)));
			imagefilledellipse($img, $x, $y1, 2, 2, $vine);
			imagefilledellipse($img, $x, $y2, 2, 2, $vine);
		}
	}

	/** Charred Edict — minimal frame, mostly relying on burnt edge. */
	public static function drawFrame_minimal_burnt($img, int $w, int $h, array $palette): void {
		$scale = $w / 480;
		$inset = (int)(self::FRAME_INSET * $scale);
		[$tr, $tg, $tb] = ScrollPalette::hexToRgb($palette['text']);
		$ink = imagecolorallocatealpha($img, $tr, $tg, $tb, 80);
		// Single thin ink rule
		imagerectangle($img, $inset, $inset, $w - $inset, $h - $inset, $ink);
	}

	/** Imperial Edict — jeweled cabochon border. */
	public static function drawFrame_jeweled_cabochon($img, int $w, int $h, array $palette): void {
		$scale = $w / 480;
		$inset = (int)(self::FRAME_INSET * $scale);
		[$tr, $tg, $tb] = ScrollPalette::hexToRgb($palette['text']);
		$ink = imagecolorallocate($img, $tr, $tg, $tb);
		imagerectangle($img, $inset, $inset, $w - $inset, $h - $inset, $ink);

		// Gold-leaf top third
		ScrollPrimitives::fillGildedRect($img, $inset, $inset, $w - 2 * $inset, (int)(($h - 2 * $inset) * 0.18), $palette['gold'], $palette['gold_highlight'], M_PI / 2);

		// Jeweled cabochons alternating around the border
		[$ar, $ag, $ab] = ScrollPalette::hexToRgb($palette['accent']);
		[$br, $bg, $bb] = ScrollPalette::hexToRgb($palette['border']);
		$ruby = imagecolorallocate($img, $ar, $ag, $ab);
		$lapis = imagecolorallocate($img, $br, $bg, $bb);

		$gemR = max(3, (int)(5 * $scale));
		$gemStep = max(20, (int)(30 * $scale));
		// Top
		for ($x = $inset + $gemStep / 2, $i = 0; $x < $w - $inset; $x += $gemStep, $i++) {
			imagefilledellipse($img, (int)$x, $inset, $gemR * 2, $gemR * 2, $i % 2 ? $ruby : $lapis);
			imagearc($img, (int)$x, $inset, $gemR * 2 + 2, $gemR * 2 + 2, 0, 360, imagecolorallocate($img, 90, 73, 17));
		}
		// Bottom
		for ($x = $inset + $gemStep / 2, $i = 0; $x < $w - $inset; $x += $gemStep, $i++) {
			imagefilledellipse($img, (int)$x, $h - $inset, $gemR * 2, $gemR * 2, $i % 2 ? $ruby : $lapis);
			imagearc($img, (int)$x, $h - $inset, $gemR * 2 + 2, $gemR * 2 + 2, 0, 360, imagecolorallocate($img, 90, 73, 17));
		}
		// Left
		for ($y = $inset + $gemStep / 2, $i = 0; $y < $h - $inset; $y += $gemStep, $i++) {
			imagefilledellipse($img, $inset, (int)$y, $gemR * 2, $gemR * 2, $i % 2 ? $ruby : $lapis);
		}
		// Right
		for ($y = $inset + $gemStep / 2, $i = 0; $y < $h - $inset; $y += $gemStep, $i++) {
			imagefilledellipse($img, $w - $inset, (int)$y, $gemR * 2, $gemR * 2, $i % 2 ? $ruby : $lapis);
		}
	}

	/** Scholar's Hand — Renaissance white-vine bianchi girari. Tri-color vertical bands flank the body. */
	public static function drawFrame_renaissance_white_vine($img, int $w, int $h, array $palette): void {
		$scale = $w / 480;
		$inset = (int)(self::FRAME_INSET * $scale);
		$bandW = max(6, (int)(10 * $scale));

		// Tri-color band on left + right
		$colors = [$palette['border'], $palette['accent'], $palette['ground_a']];
		foreach ([0, 1, 2] as $i) {
			$rgb = ScrollPalette::hexToRgb($colors[$i]);
			$c = imagecolorallocatealpha($img, $rgb[0], $rgb[1], $rgb[2], 40);
			imagefilledrectangle($img, $inset + $i * $bandW, $inset, $inset + ($i + 1) * $bandW, $h - $inset, $c);
			imagefilledrectangle($img, $w - $inset - ($i + 1) * $bandW, $inset, $w - $inset - $i * $bandW, $h - $inset, $c);
		}

		// White-vine scrollwork (overlay)
		$bgRgb = ScrollPalette::hexToRgb($palette['bg']);
		$white = imagecolorallocatealpha($img, $bgRgb[0], $bgRgb[1], $bgRgb[2], 30);
		$step = max(12, (int)(22 * $scale));
		for ($y = $inset + $step / 2; $y < $h - $inset; $y += $step) {
			imagearc($img, (int)($inset + $bandW * 1.5), (int)$y, $bandW * 2, $bandW * 2, 0, 180, $white);
			imagearc($img, (int)($w - $inset - $bandW * 1.5), (int)$y, $bandW * 2, $bandW * 2, 180, 360, $white);
		}

		// Gilded disks at corners
		foreach ([[$inset, $inset], [$w - $inset, $inset], [$inset, $h - $inset], [$w - $inset, $h - $inset]] as [$cx, $cy]) {
			ScrollPrimitives::fillGildedCircle($img, $cx, $cy, max(3, (int)(5 * $scale)), $palette['gold'], $palette['gold_highlight']);
		}
	}

	/** Crusader's Charter — Romanesque round arch + stripes. */
	public static function drawFrame_romanesque_arch($img, int $w, int $h, array $palette): void {
		$scale = $w / 480;
		$inset = (int)(self::FRAME_INSET * $scale);
		[$ar, $ag, $ab] = ScrollPalette::hexToRgb($palette['accent']);
		$accent = imagecolorallocate($img, $ar, $ag, $ab);

		// Round arch at top — two columns + semicircle
		$archTop = (int)(120 * $scale);
		$colW = max(4, (int)(8 * $scale));
		// Left column
		imagefilledrectangle($img, $inset, $archTop, $inset + $colW, $h - $inset, $accent);
		// Right column
		imagefilledrectangle($img, $w - $inset - $colW, $archTop, $w - $inset, $h - $inset, $accent);
		// Top: half-ellipse (round arch)
		imagearc($img, (int)($w / 2), $archTop, $w - 2 * $inset, ($archTop - $inset) * 2, 180, 360, $accent);

		// Inner gilded line
		[$gr, $gg, $gb] = ScrollPalette::hexToRgb($palette['gold']);
		$goldCol = imagecolorallocate($img, $gr, $gg, $gb);
		imagearc($img, (int)($w / 2), $archTop + 2, $w - 2 * $inset - 6, ($archTop - $inset) * 2 - 6, 180, 360, $goldCol);

		// Bottom rule
		imageline($img, $inset, $h - $inset, $w - $inset, $h - $inset, $accent);

		// Jeweled cross at top center
		self::drawJeweledCross($img, (int)($w / 2), $archTop - (int)(20 * $scale), max(8, (int)(14 * $scale)), $palette);
	}

	private static function drawJeweledCross($img, int $cx, int $cy, int $r, array $palette): void {
		[$gr, $gg, $gb] = ScrollPalette::hexToRgb($palette['gold']);
		$gold = imagecolorallocate($img, $gr, $gg, $gb);
		$thick = max(2, (int)($r / 4));
		// Vertical bar
		imagefilledrectangle($img, $cx - $thick, $cy - $r, $cx + $thick, $cy + $r, $gold);
		// Horizontal bar
		imagefilledrectangle($img, $cx - (int)($r * 0.7), $cy - $thick, $cx + (int)($r * 0.7), $cy + $thick, $gold);
		// Center jewel
		[$ar, $ag, $ab] = ScrollPalette::hexToRgb($palette['accent']);
		imagefilledellipse($img, $cx, $cy, $thick * 2, $thick * 2, imagecolorallocate($img, $ar, $ag, $ab));
	}

	/** Astral Codex — star pattern margins. */
	public static function drawFrame_astral_star_pattern($img, int $w, int $h, array $palette): void {
		$scale = $w / 480;
		$inset = (int)(self::FRAME_INSET * $scale);
		[$br, $bg, $bb] = ScrollPalette::hexToRgb($palette['border']);
		$violet = imagecolorallocate($img, $br, $bg, $bb);

		// Outer rectangle in violet
		imagerectangle($img, $inset, $inset, $w - $inset, $h - $inset, $violet);

		// Stars (silver) along edges
		$starCol = imagecolorallocate($img, 192, 192, 192);
		$starStep = max(20, (int)(28 * $scale));
		for ($x = $inset + $starStep / 2; $x < $w - $inset; $x += $starStep) {
			self::drawStar($img, (int)$x, $inset, max(3, (int)(5 * $scale)), $starCol);
			self::drawStar($img, (int)$x, $h - $inset, max(3, (int)(5 * $scale)), $starCol);
		}
		for ($y = $inset + $starStep / 2; $y < $h - $inset; $y += $starStep) {
			self::drawStar($img, $inset, (int)$y, max(3, (int)(5 * $scale)), $starCol);
			self::drawStar($img, $w - $inset, (int)$y, max(3, (int)(5 * $scale)), $starCol);
		}
	}

	private static function drawStar($img, int $cx, int $cy, int $r, int $color): void {
		// Simple 5-point star
		$pts = [];
		for ($i = 0; $i < 10; $i++) {
			$angle = -M_PI / 2 + $i * M_PI / 5;
			$rr = $i % 2 === 0 ? $r : (int)($r * 0.4);
			$pts[] = (int)($cx + cos($angle) * $rr);
			$pts[] = (int)($cy + sin($angle) * $rr);
		}
		imagefilledpolygon($img, $pts, 10, $color);
	}

	/** Astral Codex — star field (background). */
	public static function drawStarField($img, int $w, int $h, array $palette): void {
		mt_srand($w * 5413 + $h * 6271);
		$starCol = imagecolorallocate($img, 220, 220, 240);
		for ($i = 0; $i < 80; $i++) {
			$x = mt_rand(0, $w - 1); $y = mt_rand(0, $h - 1);
			$r = mt_rand(0, 100) > 80 ? 2 : 1;
			imagefilledellipse($img, $x, $y, $r * 2, $r * 2, $starCol);
		}
	}

	// ================================================================
	//  Seal stamps (10 designs, family-keyed)
	// ================================================================

	public static function drawSealStamp($img, int $cx, int $cy, int $r, array $palette, string $kind): void {
		$method = 'drawSealStamp_' . $kind;
		if (method_exists(self::class, $method)) {
			self::$method($img, $cx, $cy, $r, $palette);
		} else {
			self::drawSealStamp_fleur($img, $cx, $cy, $r, $palette);
		}
	}

	public static function drawSealStamp_lion($img, int $cx, int $cy, int $r, array $palette): void {
		[$gr, $gg, $gb] = ScrollPalette::hexToRgb($palette['gold']);
		$gold = imagecolorallocate($img, $gr, $gg, $gb);
		// Stylized lion silhouette — body + head + mane circles
		imagefilledellipse($img, $cx + (int)($r * 0.1), $cy + (int)($r * 0.2), (int)($r * 1.0), (int)($r * 0.7), $gold);
		imagefilledellipse($img, $cx - (int)($r * 0.4), $cy - (int)($r * 0.2), (int)($r * 0.6), (int)($r * 0.55), $gold);
		// Mane — radial spikes
		for ($k = 0; $k < 8; $k++) {
			$angle = M_PI + $k * M_PI / 7;
			$x = (int)($cx - $r * 0.4 + cos($angle) * $r * 0.45);
			$y = (int)($cy - $r * 0.2 + sin($angle) * $r * 0.45);
			imagefilledellipse($img, $x, $y, max(3, (int)($r * 0.18)), max(3, (int)($r * 0.18)), $gold);
		}
	}

	public static function drawSealStamp_fleur($img, int $cx, int $cy, int $r, array $palette): void {
		self::drawFleurDeLis($img, $cx, $cy, $r, $palette['gold'], $palette['gold_highlight']);
	}

	public static function drawSealStamp_crown($img, int $cx, int $cy, int $r, array $palette): void {
		[$gr, $gg, $gb] = ScrollPalette::hexToRgb($palette['gold']);
		$gold = imagecolorallocate($img, $gr, $gg, $gb);
		// Crown band + 3 spikes
		imagefilledrectangle($img, $cx - $r, $cy + (int)($r * 0.2), $cx + $r, $cy + (int)($r * 0.5), $gold);
		// Three spikes
		$pts = [
			$cx - $r, $cy + (int)($r * 0.2),
			$cx - (int)($r * 0.7), $cy - (int)($r * 0.4),
			$cx - (int)($r * 0.3), $cy + (int)($r * 0.2),
			$cx, $cy - (int)($r * 0.7),
			$cx + (int)($r * 0.3), $cy + (int)($r * 0.2),
			$cx + (int)($r * 0.7), $cy - (int)($r * 0.4),
			$cx + $r, $cy + (int)($r * 0.2),
		];
		imagefilledpolygon($img, array_map('intval', $pts), 7, $gold);
		// Jewels
		[$ar, $ag, $ab] = ScrollPalette::hexToRgb($palette['accent']);
		$jewel = imagecolorallocate($img, $ar, $ag, $ab);
		imagefilledellipse($img, $cx - (int)($r * 0.7), $cy - (int)($r * 0.3), max(3, (int)($r * 0.18)), max(3, (int)($r * 0.18)), $jewel);
		imagefilledellipse($img, $cx, $cy - (int)($r * 0.55), max(3, (int)($r * 0.2)), max(3, (int)($r * 0.2)), $jewel);
		imagefilledellipse($img, $cx + (int)($r * 0.7), $cy - (int)($r * 0.3), max(3, (int)($r * 0.18)), max(3, (int)($r * 0.18)), $jewel);
	}

	public static function drawSealStamp_oak_leaf($img, int $cx, int $cy, int $r, array $palette): void {
		[$gr, $gg, $gb] = ScrollPalette::hexToRgb($palette['gold']);
		$gold = imagecolorallocate($img, $gr, $gg, $gb);
		// Leaf shape with lobed edges
		$pts = [];
		for ($i = 0; $i < 16; $i++) {
			$angle = -M_PI / 2 + $i * 2 * M_PI / 16;
			$rr = $r * (0.6 + 0.4 * abs(sin($i * M_PI / 4)));
			$pts[] = (int)($cx + cos($angle) * $rr);
			$pts[] = (int)($cy + sin($angle) * $rr);
		}
		imagefilledpolygon($img, $pts, 16, $gold);
		// Central vein
		[$br, $bg, $bb] = ScrollPalette::hexToRgb($palette['border']);
		$vein = imagecolorallocate($img, $br, $bg, $bb);
		imageline($img, $cx, $cy - $r, $cx, $cy + $r, $vein);
	}

	public static function drawSealStamp_broken_sword($img, int $cx, int $cy, int $r, array $palette): void {
		[$gr, $gg, $gb] = ScrollPalette::hexToRgb($palette['gold']);
		$gold = imagecolorallocate($img, $gr, $gg, $gb);
		// Hilt cross + broken blade
		imagefilledrectangle($img, $cx - (int)($r * 0.5), $cy - (int)($r * 0.1), $cx + (int)($r * 0.5), $cy + (int)($r * 0.1), $gold);
		imagefilledrectangle($img, $cx - (int)($r * 0.05), $cy - (int)($r * 0.3), $cx + (int)($r * 0.05), $cy + (int)($r * 0.3), $gold);
		// Blade going down-left, broken
		imagefilledrectangle($img, $cx - (int)($r * 0.1), $cy + (int)($r * 0.3), $cx + (int)($r * 0.1), $cy + (int)($r * 0.6), $gold);
		// Jagged break
		$pts = [
			$cx - (int)($r * 0.1), $cy + (int)($r * 0.6),
			$cx + (int)($r * 0.1), $cy + (int)($r * 0.6),
			$cx, $cy + (int)($r * 0.7),
			$cx - (int)($r * 0.05), $cy + (int)($r * 0.65),
		];
		imagefilledpolygon($img, array_map('intval', $pts), 4, $gold);
	}

	public static function drawSealStamp_eagle($img, int $cx, int $cy, int $r, array $palette): void {
		[$gr, $gg, $gb] = ScrollPalette::hexToRgb($palette['gold']);
		$gold = imagecolorallocate($img, $gr, $gg, $gb);
		// Body
		imagefilledellipse($img, $cx, $cy + (int)($r * 0.1), (int)($r * 0.4), (int)($r * 0.6), $gold);
		// Wings — two triangles
		$leftWing = [
			$cx, $cy,
			$cx - $r, $cy - (int)($r * 0.3),
			$cx - (int)($r * 0.7), $cy + (int)($r * 0.2),
		];
		$rightWing = [
			$cx, $cy,
			$cx + $r, $cy - (int)($r * 0.3),
			$cx + (int)($r * 0.7), $cy + (int)($r * 0.2),
		];
		imagefilledpolygon($img, array_map('intval', $leftWing), 3, $gold);
		imagefilledpolygon($img, array_map('intval', $rightWing), 3, $gold);
		// Head
		imagefilledellipse($img, $cx, $cy - (int)($r * 0.4), (int)($r * 0.3), (int)($r * 0.3), $gold);
	}

	public static function drawSealStamp_pentagram($img, int $cx, int $cy, int $r, array $palette): void {
		[$gr, $gg, $gb] = ScrollPalette::hexToRgb($palette['gold']);
		$gold = imagecolorallocate($img, $gr, $gg, $gb);
		// 5-pointed star + circle
		imagearc($img, $cx, $cy, $r * 2, $r * 2, 0, 360, $gold);
		// Star
		$pts = [];
		for ($i = 0; $i < 5; $i++) {
			$angle = -M_PI / 2 + $i * 4 * M_PI / 5;
			$pts[] = (int)($cx + cos($angle) * $r * 0.85);
			$pts[] = (int)($cy + sin($angle) * $r * 0.85);
		}
		// Connect 0→2→4→1→3→0 to draw a pentagram
		$order = [0, 2, 4, 1, 3, 0];
		for ($i = 0; $i < 5; $i++) {
			$a = $order[$i] * 2; $b = $order[$i + 1] * 2;
			imageline($img, $pts[$a], $pts[$a + 1], $pts[$b], $pts[$b + 1], $gold);
		}
	}

	public static function drawSealStamp_quill($img, int $cx, int $cy, int $r, array $palette): void {
		[$gr, $gg, $gb] = ScrollPalette::hexToRgb($palette['gold']);
		$gold = imagecolorallocate($img, $gr, $gg, $gb);
		// Quill: angled tapered line + plume
		$pts = [
			$cx - (int)($r * 0.7), $cy + (int)($r * 0.7),
			$cx + (int)($r * 0.5), $cy - (int)($r * 0.5),
			$cx + (int)($r * 0.7), $cy - (int)($r * 0.3),
			$cx - (int)($r * 0.5), $cy + (int)($r * 0.9),
		];
		imagefilledpolygon($img, array_map('intval', $pts), 4, $gold);
		// Plume tip
		imagefilledellipse($img, $cx + (int)($r * 0.6), $cy - (int)($r * 0.4), max(4, (int)($r * 0.25)), max(4, (int)($r * 0.25)), $gold);
	}

	public static function drawSealStamp_knotwork($img, int $cx, int $cy, int $r, array $palette): void {
		self::drawTriskele($img, $cx, $cy, $r, $palette);
		[$br, $bg, $bb] = ScrollPalette::hexToRgb($palette['border']);
		imagearc($img, $cx, $cy, $r * 2, $r * 2, 0, 360, imagecolorallocate($img, $br, $bg, $bb));
	}

	public static function drawSealStamp_rabbit($img, int $cx, int $cy, int $r, array $palette): void {
		[$gr, $gg, $gb] = ScrollPalette::hexToRgb($palette['gold']);
		$gold = imagecolorallocate($img, $gr, $gg, $gb);
		// Rabbit body + head + ears
		imagefilledellipse($img, $cx, $cy + (int)($r * 0.2), (int)($r * 0.7), (int)($r * 0.5), $gold);
		imagefilledellipse($img, $cx - (int)($r * 0.4), $cy - (int)($r * 0.1), (int)($r * 0.3), (int)($r * 0.3), $gold);
		// Long ears
		imagefilledellipse($img, $cx - (int)($r * 0.55), $cy - (int)($r * 0.55), (int)($r * 0.15), (int)($r * 0.4), $gold);
		imagefilledellipse($img, $cx - (int)($r * 0.25), $cy - (int)($r * 0.6), (int)($r * 0.15), (int)($r * 0.4), $gold);
	}

	// ================================================================
	//  Historiated initial — 3-zone parameterized
	// ================================================================

	public static function drawHistoriatedInitial($img, array $opts): void {
		$x = (int)$opts['x']; $y = (int)$opts['y'];
		$w = (int)$opts['w']; $h = (int)$opts['h'];
		$letter = (string)($opts['letter'] ?? 'B');
		$pal = $opts['palette'];
		$fontPath = $opts['font'] ?? '';

		$cornerSq = (int)round($w * 0.22);
		[$ar, $ag, $ab] = ScrollPalette::hexToRgb($pal['accent']);
		$accentCol = imagecolorallocate($img, $ar, $ag, $ab);
		// Zone 1: corner squares (NW + SE accent; NE + SW gold)
		imagefilledrectangle($img, $x, $y, $x + $cornerSq, $y + $cornerSq, $accentCol);
		imagefilledrectangle($img, $x + $w - $cornerSq, $y + $h - $cornerSq, $x + $w, $y + $h, $accentCol);
		ScrollPrimitives::fillGildedRect($img, $x + $w - $cornerSq, $y, $cornerSq, $cornerSq, $pal['gold'], $pal['gold_highlight']);
		ScrollPrimitives::fillGildedRect($img, $x, $y + $h - $cornerSq, $cornerSq, $cornerSq, $pal['gold'], $pal['gold_highlight']);

		// Zone 2: inner border-color field with diaper
		$innerInset = 4;
		[$br, $bg, $bb] = ScrollPalette::hexToRgb($pal['border']);
		$bordCol = imagecolorallocate($img, $br, $bg, $bb);
		imagefilledrectangle($img, $x + $innerInset, $y + $innerInset, $x + $w - $innerInset, $y + $h - $innerInset, $bordCol);
		[$bgR, $bgG, $bgB] = ScrollPalette::hexToRgb($pal['bg']);
		$diaperCol = imagecolorallocatealpha($img, $bgR, $bgG, $bgB, 95);
		for ($dy = 0; $dy < $h; $dy += 6) {
			imageline($img, $x + $innerInset, $y + $innerInset + $dy, $x + $w - $innerInset, $y + $innerInset + $dy + 6, $diaperCol);
		}

		// Zone 3: white-vine letter (palette.bg colored)
		if ($fontPath && file_exists($fontPath) && trim($letter) !== '') {
			$bgCol = imagecolorallocate($img, $bgR, $bgG, $bgB);
			$size = (int)round($h * 0.55);
			$bbox = imagettfbbox($size, 0, $fontPath, $letter);
			if ($bbox !== false) {
				$tw = $bbox[2] - $bbox[0]; $th = $bbox[1] - $bbox[7];
				$tx = $x + (int)(($w - $tw) / 2) - $bbox[0];
				$ty = $y + (int)(($h + $th) / 2);
				imagettftext($img, $size, 0, $tx, $ty, $bgCol, $fontPath, $letter);
			}
		}
	}

	// ================================================================
	//  Banderole — curling ribbon with text along curve
	// ================================================================

	public static function drawBanderole($img, array $opts): void {
		$cx = (int)$opts['cx']; $cy = (int)$opts['cy'];
		$w = (int)$opts['w']; $h = (int)$opts['h'];
		$text = (string)($opts['text'] ?? '');
		$pal = $opts['palette'];
		$fontPath = $opts['font'] ?? '';

		[$gr, $gg, $gb] = ScrollPalette::hexToRgb($pal['gold']);
		$ribbon = imagecolorallocate($img, $gr, $gg, $gb);
		$darkRgb = ScrollPalette::hexToRgb(ScrollPalette::darken($pal['gold'], 0.4));
		$darkRibbon = imagecolorallocate($img, $darkRgb[0], $darkRgb[1], $darkRgb[2]);

		// Single-curl banderole as filled polygon (top arc + bottom arc + tail flips)
		$pts = [];
		$samples = 24;
		for ($i = 0; $i <= $samples; $i++) {
			$f = $i / $samples;
			$x = (int)($cx - $w / 2 + $w * $f);
			$y = (int)($cy + sin($f * M_PI) * (-$h * 0.4));
			$pts[] = $x; $pts[] = $y;
		}
		// Right tail flip
		$pts[] = $cx + (int)($w / 2) + (int)($h * 0.3); $pts[] = $cy + (int)($h * 0.7);
		$pts[] = $cx + (int)($w / 2) - (int)($h * 0.1); $pts[] = $cy + (int)($h * 0.6);
		// Bottom arc returning
		for ($i = $samples; $i >= 0; $i--) {
			$f = $i / $samples;
			$x = (int)($cx - $w / 2 + $w * $f);
			$y = (int)($cy + sin($f * M_PI) * ($h * 0.3) + $h * 0.4);
			$pts[] = $x; $pts[] = $y;
		}
		// Left tail flip
		$pts[] = $cx - (int)($w / 2) + (int)($h * 0.1); $pts[] = $cy + (int)($h * 0.6);
		$pts[] = $cx - (int)($w / 2) - (int)($h * 0.3); $pts[] = $cy + (int)($h * 0.7);

		imagefilledpolygon($img, $pts, count($pts) / 2, $ribbon);
		imagepolygon($img, $pts, count($pts) / 2, $darkRibbon);

		// Text along the gentle midline
		if ($fontPath && file_exists($fontPath) && trim($text) !== '') {
			[$tr, $tg, $tb] = ScrollPalette::hexToRgb($pal['text']);
			$textCol = imagecolorallocate($img, $tr, $tg, $tb);
			$size = (int)round($h * 0.32);
			$bbox = imagettfbbox($size, 0, $fontPath, $text);
			if ($bbox !== false) {
				$tw = $bbox[2] - $bbox[0];
				imagettftext($img, $size, 0, $cx - $tw / 2, $cy + (int)($h * 0.10), $textCol, $fontPath, $text);
			}
		}
	}

	// ================================================================
	//  Wax seal emboss with ribbon tails + family stamp
	// ================================================================

	public static function drawWaxSealEmboss($img, array $opts): void {
		$cx = (int)$opts['cx']; $cy = (int)$opts['cy']; $r = (int)$opts['r'];
		$pal = $opts['palette'];
		$stampKind = $opts['stampKind'] ?? 'fleur';

		// Ribbon tails (drawn first, behind disc)
		$wax = ScrollPalette::hexToRgb($pal['wax']);
		$waxDark = ScrollPalette::hexToRgb(ScrollPalette::darken($pal['wax'], 0.3));
		$ribbonCol = imagecolorallocate($img, ($wax[0] + $waxDark[0]) >> 1, ($wax[1] + $waxDark[1]) >> 1, ($wax[2] + $waxDark[2]) >> 1);

		$leftRibbon = [
			$cx - (int)($r * 0.3), $cy + (int)($r * 0.8),
			$cx - (int)($r * 1.0), $cy + (int)($r * 1.6),
			$cx - (int)($r * 0.6), $cy + (int)($r * 1.7),
			$cx - (int)($r * 0.1), $cy + (int)($r * 0.9),
		];
		$rightRibbon = [
			$cx + (int)($r * 0.3), $cy + (int)($r * 0.8),
			$cx + (int)($r * 1.0), $cy + (int)($r * 1.6),
			$cx + (int)($r * 0.6), $cy + (int)($r * 1.7),
			$cx + (int)($r * 0.1), $cy + (int)($r * 0.9),
		];
		imagefilledpolygon($img, array_map('intval', $leftRibbon), 4, $ribbonCol);
		imagefilledpolygon($img, array_map('intval', $rightRibbon), 4, $ribbonCol);

		// Wax disc with radial gradient
		$lightWax = ScrollPalette::hexToRgb(ScrollPalette::lighten($pal['wax'], 0.35));
		$darkWax = ScrollPalette::hexToRgb(ScrollPalette::darken($pal['wax'], 0.45));
		for ($dy = -$r; $dy <= $r; $dy++) {
			for ($dx = -$r; $dx <= $r; $dx++) {
				$d = sqrt($dx * $dx + $dy * $dy);
				if ($d > $r) continue;
				$ox = $dx + (int)($r * 0.3); $oy = $dy + (int)($r * 0.3);
				$od = min(1, sqrt($ox * $ox + $oy * $oy) / max(1, $r));
				if ($od < 0.5) {
					$f = $od / 0.5;
					$cr = (int)round($lightWax[0] + ($wax[0] - $lightWax[0]) * $f);
					$cg = (int)round($lightWax[1] + ($wax[1] - $lightWax[1]) * $f);
					$cb = (int)round($lightWax[2] + ($wax[2] - $lightWax[2]) * $f);
				} else {
					$f = ($od - 0.5) / 0.5;
					$cr = (int)round($wax[0] + ($darkWax[0] - $wax[0]) * $f);
					$cg = (int)round($wax[1] + ($darkWax[1] - $wax[1]) * $f);
					$cb = (int)round($wax[2] + ($darkWax[2] - $wax[2]) * $f);
				}
				imagesetpixel($img, $cx + $dx, $cy + $dy, imagecolorallocate($img, $cr, $cg, $cb));
			}
		}

		// Embossed family-specific stamp
		self::drawSealStamp($img, $cx, $cy, (int)($r * 0.7), $pal, $stampKind);
	}

	// ================================================================
	//  Drôleries (marginal grotesques)
	// ================================================================

	public static function drawDrolerie($img, int $x, int $y, int $w, int $h, array $palette, string $kind = 'hare_jousts_snail'): void {
		[$br, $bg, $bb] = ScrollPalette::hexToRgb($palette['border']);
		$col = imagecolorallocate($img, $br, $bg, $bb);
		$dark = imagecolorallocate($img, max(0, $br - 60), max(0, $bg - 60), max(0, $bb - 60));

		switch ($kind) {
			case 'hare_jousts_snail':
				// Hare on left
				imagefilledellipse($img, $x + (int)($w * 0.2), $y + (int)($h * 0.65), (int)($w * 0.18), (int)($h * 0.30), $col);
				// Ears
				imagefilledellipse($img, $x + (int)($w * 0.15), $y + (int)($h * 0.3), (int)($w * 0.04), (int)($h * 0.25), $col);
				imagefilledellipse($img, $x + (int)($w * 0.22), $y + (int)($h * 0.3), (int)($w * 0.04), (int)($h * 0.25), $col);
				// Lance (left-to-right)
				imageline($img, $x + (int)($w * 0.3), $y + (int)($h * 0.5), $x + (int)($w * 0.7), $y + (int)($h * 0.4), $dark);
				// Snail on right
				imagefilledellipse($img, $x + (int)($w * 0.85), $y + (int)($h * 0.75), (int)($w * 0.15), (int)($h * 0.18), $col);
				imageellipse($img, $x + (int)($w * 0.85), $y + (int)($h * 0.65), (int)($w * 0.18), (int)($w * 0.18), $dark);
				imageellipse($img, $x + (int)($w * 0.85), $y + (int)($h * 0.65), (int)($w * 0.10), (int)($w * 0.10), $dark);
				// Snail's lance
				imageline($img, $x + (int)($w * 0.7), $y + (int)($h * 0.55), $x + (int)($w * 0.4), $y + (int)($h * 0.4), $dark);
				break;

			case 'rabbit_lute':
			default:
				imagefilledellipse($img, $x + (int)($w * 0.5), $y + (int)($h * 0.65), (int)($w * 0.2), (int)($h * 0.3), $col);
				imagefilledellipse($img, $x + (int)($w * 0.4), $y + (int)($h * 0.4), (int)($w * 0.1), (int)($h * 0.15), $col);
				// Ears
				imagefilledellipse($img, $x + (int)($w * 0.36), $y + (int)($h * 0.2), (int)($w * 0.03), (int)($h * 0.18), $col);
				imagefilledellipse($img, $x + (int)($w * 0.44), $y + (int)($h * 0.2), (int)($w * 0.03), (int)($h * 0.18), $col);
				// Lute body
				imagefilledellipse($img, $x + (int)($w * 0.7), $y + (int)($h * 0.55), (int)($w * 0.15), (int)($h * 0.2), $dark);
				break;
		}
	}

	// ================================================================
	//  Burnt edge + fold creases (Charred Edict aging)
	// ================================================================

	public static function applyBurntEdge($img, int $w, int $h, float $intensity = 0.6): void {
		$cx = $w / 2; $cy = $h / 2;
		$rInner = min($w, $h) * (1 - $intensity * 0.5);
		$rOuter = max($w, $h) * 0.7;
		$step = $w > 1500 ? 4 : 1;
		for ($y = 0; $y < $h; $y += $step) {
			for ($x = 0; $x < $w; $x += $step) {
				$d = sqrt(($x - $cx) ** 2 + ($y - $cy) ** 2);
				if ($d <= $rInner) continue;
				$f = min(1, ($d - $rInner) / ($rOuter - $rInner));
				$rgb = imagecolorat($img, $x, $y);
				$pr = ($rgb >> 16) & 0xFF; $pg = ($rgb >> 8) & 0xFF; $pb = $rgb & 0xFF;
				$mul = (1 - $f * 0.85);
				$nr = (int)round($pr * $mul); $ng = (int)round($pg * $mul); $nb = (int)round($pb * $mul);
				$col = imagecolorallocate($img, $nr, $ng, $nb);
				if ($step === 1) imagesetpixel($img, $x, $y, $col);
				else imagefilledrectangle($img, $x, $y, min($w - 1, $x + $step - 1), min($h - 1, $y + $step - 1), $col);
			}
		}
		// Irregular bites — deterministic seeded
		mt_srand($w * 1009 + $h * 1013);
		$dark = imagecolorallocate($img, 18, 10, 4);
		for ($i = 0; $i < 60; $i++) {
			$side = $i % 4;
			$t = mt_rand() / mt_getrandmax();
			if ($side === 0) { $bx = (int)($w * $t); $by = 0; }
			elseif ($side === 1) { $bx = $w; $by = (int)($h * $t); }
			elseif ($side === 2) { $bx = (int)($w * $t); $by = $h; }
			else { $bx = 0; $by = (int)($h * $t); }
			$br = (int)(8 + mt_rand(0, 24)) * max(1, (int)($w / 480));
			imagefilledellipse($img, $bx, $by, $br * 2, $br * 2, $dark);
		}
	}

	public static function applyFoldCreases($img, int $w, int $h): void {
		$creaseCol = imagecolorallocatealpha($img, 60, 36, 24, 110);
		imageline($img, (int)($w / 3), 0, (int)($w / 3), $h, $creaseCol);
		imageline($img, (int)($w * 2 / 3), 0, (int)($w * 2 / 3), $h, $creaseCol);
		$lightCrease = imagecolorallocatealpha($img, 60, 36, 24, 117);
		imageline($img, 0, (int)($h / 2), $w, (int)($h / 2), $lightCrease);
	}

	// ================================================================
	//  Heraldry medallion — gilded ring around circular-cropped heraldry
	// ================================================================

	public static function drawHeraldryMedallion($img, int $cx, int $cy, int $r, ?string $imagePath, array $palette): void {
		// Outer gilded ring
		ScrollPrimitives::fillGildedCircle($img, $cx, $cy, $r + max(2, (int)($r * 0.15)), $palette['gold'], $palette['gold_highlight']);
		// Inner area: parchment-toned
		[$bgr, $bgg, $bgb] = ScrollPalette::hexToRgb($palette['bg']);
		$bgCol = imagecolorallocate($img, $bgr, $bgg, $bgb);
		imagefilledellipse($img, $cx, $cy, $r * 2, $r * 2, $bgCol);

		// Heraldry image, circularly cropped
		if ($imagePath && file_exists($imagePath)) {
			$src = @imagecreatefromstring(@file_get_contents($imagePath));
			if ($src !== false) {
				$sw = imagesx($src); $sh = imagesy($src);
				$diam = $r * 2;
				$tmp = imagecreatetruecolor($diam, $diam);
				imagealphablending($tmp, false); imagesavealpha($tmp, true);
				$transparent = imagecolorallocatealpha($tmp, 0, 0, 0, 127);
				imagefilledrectangle($tmp, 0, 0, $diam, $diam, $transparent);
				imagecopyresampled($tmp, $src, 0, 0, 0, 0, $diam, $diam, $sw, $sh);
				// Mask: copy only pixels inside the circle
				for ($yy = 0; $yy < $diam; $yy++) {
					for ($xx = 0; $xx < $diam; $xx++) {
						$dx = $xx - $r; $dy = $yy - $r;
						if ($dx * $dx + $dy * $dy <= $r * $r) {
							$rgb = imagecolorat($tmp, $xx, $yy);
							imagesetpixel($img, $cx - $r + $xx, $cy - $r + $yy, $rgb);
						}
					}
				}
				imagedestroy($tmp); imagedestroy($src);
			}
		}
	}
}
