<?php

/**
 * Family-driven scroll renderer.
 *
 * Renders an award scroll PNG using a family definition from families.json
 * combined with foundation primitives (parchment, gilding, stub frame).
 *
 * Plan 1 ships a canonical layout that exercises all foundation primitives
 * with family-correct palette + fonts. Plan 3 splits this into 10 family-specific
 * render_<key> methods; for now all families share the same canonical layout.
 *
 * Mirrors orkui/template/revised-frontend/scroll/scroll-families.js.
 *
 * Usage:
 *   $img = imagecreatetruecolor($w, $h);
 *   ScrollFamilyRenderer::render($img, $w, $h, $state, $family);
 *   imagepng($img); imagedestroy($img);
 */
class ScrollFamilyRenderer {

	/** Absolute path to TTF font directory. */
	const FONT_DIR = '/var/www/ork.amtgard.com/assets/scroll/fonts/';

	/** Path to families.json (one source of truth). */
	const FAMILIES_JSON = '/var/www/ork.amtgard.com/orkui/template/revised-frontend/scroll/families.json';

	private static ?array $FAMILIES = null;

	public static function families(): array {
		if (self::$FAMILIES === null) {
			$path = self::FAMILIES_JSON;
			if (!file_exists($path)) throw new \RuntimeException("families.json missing: $path");
			self::$FAMILIES = json_decode(file_get_contents($path), true);
			if (!is_array(self::$FAMILIES)) throw new \RuntimeException('families.json failed to decode');
		}
		return self::$FAMILIES;
	}

	/**
	 * @param resource|\GdImage $img
	 * @param array $state    { awardName, recipient, bodyText?, date?, signatures?, motto?, decorationIntensity?, family, forPrint?, kingdomHeraldry?, parkHeraldry?, playerHeraldry? }
	 * @param array $family   the loaded families.json entry; will receive 'key' if not already set
	 */
	public static function render($img, int $w, int $h, array $state, array $family): void {
		$key = $family['key'] ?? $state['family'] ?? 'northern_gothic';
		$family['key'] = $key;

		// Plan 3 dispatches to render_<key>; Plan 1 uses canonical for all.
		$method = "render_$key";
		if (method_exists(self::class, $method)) {
			self::$method($img, $w, $h, $state, $family);
		} else {
			self::renderCanonical($img, $w, $h, $state, $family);
		}
	}

	/** Map family_key → seal stamp kind (for embossed wax seal). */
	const SEAL_KIND = [
		'hibernian_knotwork' => 'knotwork',
		'northern_gothic'    => 'lion',
		'provencal_bestiary' => 'rabbit',
		'crimson_decree'     => 'crown',
		'forest_reverie'     => 'oak_leaf',
		'charred_edict'      => 'broken_sword',
		'imperial_edict'     => 'eagle',
		'scholars_hand'      => 'quill',
		'crusaders_charter'  => 'fleur',
		'astral_codex'       => 'pentagram',
	];

	/** Map family_key → drôlerie kind (for families with marginal grotesques). */
	const DROLERIE_KIND = [
		'northern_gothic'    => 'hare_jousts_snail',
		'provencal_bestiary' => 'rabbit_lute',
	];

	/**
	 * Canonical per-family layout. Each family renders through this with its own
	 * palette/fonts + frame kind + seal kind + optional historiated initial + optional drôlerie.
	 *
	 * Family-specific render_<key> methods (Plan 3) can override this with bespoke layouts
	 * (e.g., Imperial Edict's axial-symmetric tympanum, Crimson Decree's gold-ground panel).
	 */
	public static function renderCanonical($img, int $w, int $h, array $state, array $family): void {
		$pal = $family['palette'];
		$fonts = self::resolveFonts($family['fonts']);
		$scale = $w / 480; // preview baseline
		$key = $family['key'] ?? 'northern_gothic';
		$decoration = $family['decoration'] ?? [];
		$forPrint = !empty($state['forPrint']);

		// 1. parchment foundation (or dark celestial for Astral Codex on screen; print uses parchment)
		ScrollPrimitives::applyParchment($img, $w, $h, $pal['bg'], $pal['ground_a'], $state['decorationIntensity'] ?? 'balanced');

		// 1b. Astral Codex: star field on the dark ground (only when not in print mode)
		if ($key === 'astral_codex' && !$forPrint) {
			ScrollDecoration::drawStarField($img, $w, $h, $pal);
		}

		// 1c. Charred Edict: aging filter stack
		if ($key === 'charred_edict' || ($state['decorationIntensity'] ?? '') === 'heavy') {
			ScrollDecoration::applyBurntEdge($img, $w, $h, $key === 'charred_edict' ? 0.6 : 0.3);
		}
		if ($key === 'charred_edict') {
			ScrollDecoration::applyFoldCreases($img, $w, $h);
		}

		// 2. family-specific frame (was stubFrame in Plan 1; Plan 2 procedural per-family)
		$frameKind = $family['frame'] ?? 'gothic_ivy';
		ScrollDecoration::drawFrame($img, $w, $h, $pal, $frameKind);

		// 3. title (centered, top quarter)
		[$ar, $ag, $ab] = ScrollPalette::hexToRgb($pal['accent']);
		$accentCol = imagecolorallocate($img, $ar, $ag, $ab);
		self::drawCenteredText($img, $state['awardName'] ?? 'Untitled', (int)($w / 2), (int)(110 * $scale), max(20, (int)(38 * $scale)), $fonts['title'], $accentCol);

		// 4. subtitle ("It is hereby proclaimed")
		[$tr, $tg, $tb] = ScrollPalette::hexToRgb($pal['text']);
		$textCol = imagecolorallocate($img, $tr, $tg, $tb);
		self::drawCenteredText($img, 'It is hereby proclaimed', (int)($w / 2), (int)(140 * $scale), max(8, (int)(14 * $scale)), $fonts['subtitle'], $textCol);

		// 5. recipient
		self::drawCenteredText($img, $state['recipient'] ?? '—', (int)($w / 2), (int)(170 * $scale), max(12, (int)(22 * $scale)), $fonts['subtitle'], $textCol);

		// 6. ornamental rule (palette.accent thin line, 280px wide centered)
		$ruleY = (int)(195 * $scale);
		imagefilledrectangle($img, (int)($w/2 - 140 * $scale), $ruleY, (int)($w/2 + 140 * $scale), $ruleY + max(1, (int)(1 * $scale)), $accentCol);

		// 7. Historiated initial (for families that decoration list it)
		$body = $state['bodyText'] ?? self::defaultBody();
		$bodyX = (int)(60 * $scale);
		$bodyY = (int)(230 * $scale);
		$bodyW = $w - (int)(120 * $scale);
		$bodyLineH = max(10, (int)(18 * $scale));
		$bodySize = max(8, (int)(13 * $scale));

		if (in_array('historiated_initial', $decoration, true) && trim($body) !== '') {
			$initialW = max(40, (int)(76 * $scale));
			$initialH = max(50, (int)(94 * $scale));
			$letter = mb_strtoupper(mb_substr(trim($body), 0, 1)) ?: 'B';
			ScrollDecoration::drawHistoriatedInitial($img, [
				'x' => $bodyX, 'y' => $bodyY - (int)(8 * $scale),
				'w' => $initialW, 'h' => $initialH,
				'letter' => $letter,
				'palette' => $pal,
				'font' => $fonts['title'],
			]);
			// Body wraps past the initial for the first 5 lines
			$indent = $initialW + (int)(12 * $scale);
			self::wrapAndDrawText(
				$img, mb_substr($body, 1),
				$bodyX + $indent, $bodyY + (int)(2 * $scale),
				$bodyW - $indent, $bodyLineH,
				$bodySize, $fonts['body'], $textCol,
				5 // first 5 lines indented
			);
			// Remaining body below the initial — find approximate continuation by counting lines
			self::wrapAndDrawText(
				$img, '', // placeholder; the simple line-counter doesn't continue past the indented region
				$bodyX, $bodyY + $initialH + (int)(8 * $scale),
				$bodyW, $bodyLineH,
				$bodySize, $fonts['body'], $textCol
			);
		} else {
			// 7b. body block (left-aligned, wrapped) — no historiated initial
			self::wrapAndDrawText(
				$img, $body,
				$bodyX, $bodyY,
				$bodyW, $bodyLineH,
				$bodySize, $fonts['body'], $textCol
			);
		}

		// 7c. drôlerie bas-de-page (for families that use one)
		if (in_array('drolerie', $decoration, true) && isset(self::DROLERIE_KIND[$key])) {
			$drW = max(60, (int)(96 * $scale)); $drH = max(28, (int)(40 * $scale));
			$drX = (int)($w / 2 + 10 * $scale); $drY = $h - (int)(155 * $scale);
			ScrollDecoration::drawDrolerie($img, $drX, $drY, $drW, $drH, $pal, self::DROLERIE_KIND[$key]);
		}

		// 7d. banderole motto (Provençal Bestiary)
		if (in_array('banderole', $decoration, true)) {
			ScrollDecoration::drawBanderole($img, [
				'cx' => (int)($w / 2),
				'cy' => (int)(190 * $scale),
				'w' => (int)(280 * $scale),
				'h' => (int)(36 * $scale),
				'text' => $state['motto'] ?? 'Honos Virtutis Praemium',
				'palette' => $pal,
				'font' => $fonts['subtitle'],
			]);
		}

		// 8. signatures (bottom-left)
		$sigCount = (int)($family['sigCount'] ?? 2);
		[$br, $bgg, $bb] = ScrollPalette::hexToRgb($pal['border']);
		$borderCol = imagecolorallocate($img, $br, $bgg, $bb);
		$sigY = $h - (int)(110 * $scale);
		for ($i = 0; $i < $sigCount; $i++) {
			$y = $sigY + ($i * (int)(32 * $scale));
			$sig = $state['signatures'][$i] ?? ['name' => '', 'role' => ''];
			imageline($img, (int)(60 * $scale), $y, (int)(220 * $scale), $y, $textCol);
			$name = $sig['name'] ?? '';
			$role = $sig['role'] ?? '';
			if ($name !== '') {
				imagettftext($img, max(10, (int)(18 * $scale)), 0, (int)(72 * $scale), $y - max(2, (int)(4 * $scale)), $borderCol, $fonts['signatures'], $name);
			}
			if ($role !== '') {
				imagettftext($img, max(7, (int)(10 * $scale)), 0, (int)(60 * $scale), $y + max(8, (int)(14 * $scale)), $textCol, $fonts['body'], $role);
			}
		}

		// 9. embossed wax seal at φ from bottom-right (Imperial Edict + Astral Codex centered instead)
		$phi = 0.382;
		$sealKind = self::SEAL_KIND[$key] ?? 'fleur';
		if ($key === 'imperial_edict' || $key === 'astral_codex') {
			$sx = (int)($w / 2);
			$sy = $h - (int)(95 * $scale);
		} else {
			$sx = (int)($w * (1 - $phi * 0.4));
			$sy = (int)($h * (1 - $phi * 0.4));
		}
		ScrollDecoration::drawWaxSealEmboss($img, [
			'cx' => $sx, 'cy' => $sy,
			'r' => max(16, (int)(36 * $scale)),
			'palette' => $pal,
			'stampKind' => $sealKind,
		]);

		// 10. date (top-right)
		$dateText = $state['date'] ?? self::todayLatin();
		$bbox = imagettfbbox(max(8, (int)(11 * $scale)), 0, $fonts['date'], $dateText);
		$tw = $bbox[2] - $bbox[0];
		imagettftext($img, max(8, (int)(11 * $scale)), 0, $w - (int)(60 * $scale) - $tw, (int)(56 * $scale), $textCol, $fonts['date'], $dateText);
	}

	/**
	 * Resolve family.fonts.*_php keys to absolute TTF paths.
	 * Returns an assoc array keyed by slot (title, subtitle, body, signatures, date).
	 */
	private static function resolveFonts(array $fontsConfig): array {
		// Parse $FONTS map directly from controller source (avoids loading the full Controller class hierarchy).
		static $fontMap = null;
		if ($fontMap === null) {
			$src = file_get_contents('/var/www/ork.amtgard.com/orkui/controller/controller.ScrollAjax.php');
			$fontMap = [];
			if (preg_match('/private static \$FONTS = \[(.*?)\];/s', $src, $m)) {
				preg_match_all("/'([^']+)'\s*=>\s*'([^']+)'/", $m[1], $entries, PREG_SET_ORDER);
				foreach ($entries as $e) $fontMap[$e[1]] = $e[2];
			}
		}

		$fallback = self::FONT_DIR . 'EBGaramond-Regular.ttf';
		$out = [];
		foreach (['title','subtitle','body','signatures','date'] as $slot) {
			$key = $fontsConfig["{$slot}_php"] ?? 'EB Garamond';
			$file = $fontMap[$key] ?? 'EBGaramond-Regular.ttf';
			$path = self::FONT_DIR . $file;
			$out[$slot] = file_exists($path) ? $path : $fallback;
		}
		return $out;
	}

	private static function drawCenteredText($img, string $text, int $cx, int $y, int $size, string $fontPath, int $color): void {
		if (!file_exists($fontPath) || trim($text) === '') return;
		$bbox = imagettfbbox($size, 0, $fontPath, $text);
		$w = $bbox[2] - $bbox[0];
		imagettftext($img, $size, 0, $cx - intdiv($w, 2) - $bbox[0], $y, $color, $fontPath, $text);
	}

	/**
	 * Wrap text and draw line by line. Optional $lineLimit caps how many lines render
	 * (used for the "first N lines past the historiated initial" pattern).
	 */
	private static function wrapAndDrawText($img, string $text, int $x, int $y, int $maxW, int $lineH, int $size, string $fontPath, int $color, int $lineLimit = 0): void {
		if (!file_exists($fontPath) || trim($text) === '') return;
		$words = preg_split('/\s+/', $text);
		$line = '';
		$linesDrawn = 0;
		foreach ($words as $word) {
			$test = $line === '' ? $word : "$line $word";
			$bbox = imagettfbbox($size, 0, $fontPath, $test);
			if ($bbox === false) continue;
			if (($bbox[2] - $bbox[0]) > $maxW) {
				if ($line !== '') {
					imagettftext($img, $size, 0, $x, $y, $color, $fontPath, $line);
					$linesDrawn++;
					if ($lineLimit > 0 && $linesDrawn >= $lineLimit) return;
				}
				$y += $lineH; $line = $word;
			} else {
				$line = $test;
			}
		}
		if ($line !== '' && ($lineLimit === 0 || $linesDrawn < $lineLimit)) {
			imagettftext($img, $size, 0, $x, $y, $color, $fontPath, $line);
		}
	}

	private static function defaultBody(): string {
		return 'Be it known to all who behold this proclamation, that on the day herein recorded, the bearer hereof has been recognized for valor, counsel, and faithful service. Let it stand witness across the realm.';
	}

	private static function todayLatin(): string {
		$y = (int)date('Y');
		$map = [['M',1000],['CM',900],['D',500],['CD',400],['C',100],['XC',90],['L',50],['XL',40],['X',10],['IX',9],['V',5],['IV',4],['I',1]];
		$s = '';
		foreach ($map as [$v, $n]) while ($y >= $n) { $s .= $v; $y -= $n; }
		return "Anno Domini $s";
	}
}
