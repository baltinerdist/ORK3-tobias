<?php

class Controller_ScrollAjax extends Controller {

	/**
	 * Scale factor from 900x1200 preview canvas to 2550x3300 print canvas.
	 */
	const SCALE = 3.0;

	/**
	 * Print canvas dimensions (300 DPI letter size).
	 */
	const W = 2550;
	const H = 3300;

	/**
	 * Template definitions at print resolution.
	 */
	private static $TEMPLATES = [
		'A' => [
			'sigCount'  => 3,
			'title'     => ['x' => 1275, 'y' => 510,  'size' => 153, 'maxWidth' => 1983],
			'recipient' => ['x' => 1275, 'y' => 838,  'size' => 108, 'maxWidth' => 1983],
			'body'      => ['x' => 1275, 'y' => 1076, 'size' => 62,  'maxWidth' => 1927, 'lineHeight' => 91],
			'sigY'      => 2916,
			'heraldry'  => [
				'kingdom' => ['x' => 227,  'y' => 227,  'w' => 340, 'h' => 340],
				'park'    => ['x' => 1983, 'y' => 227,  'w' => 340, 'h' => 340],
				'player'  => ['x' => 1063, 'y' => 1983, 'w' => 425, 'h' => 425],
			],
		],
		'B' => [
			'sigCount'  => 2,
			'title'     => ['x' => 1275, 'y' => 453,  'size' => 136, 'maxWidth' => 1983],
			'recipient' => ['x' => 1275, 'y' => 753,  'size' => 96,  'maxWidth' => 1983],
			'body'      => ['x' => 1275, 'y' => 963,  'size' => 57,  'maxWidth' => 1927, 'lineHeight' => 85],
			'sigY'      => 2916,
			'heraldry'  => [
				'kingdom' => ['x' => 227,  'y' => 227,  'w' => 312, 'h' => 312],
				'park'    => ['x' => 2012, 'y' => 227,  'w' => 312, 'h' => 312],
				'player'  => ['x' => 1063, 'y' => 1927, 'w' => 425, 'h' => 425],
			],
		],
		'C' => [
			'sigCount'  => 2,
			'title'     => ['x' => 1275, 'y' => 397,  'size' => 125, 'maxWidth' => 1983],
			'recipient' => ['x' => 1275, 'y' => 668,  'size' => 91,  'maxWidth' => 1983],
			'body'      => ['x' => 1275, 'y' => 850,  'size' => 57,  'maxWidth' => 1927, 'lineHeight' => 85],
			'sigY'      => 2916,
			'heraldry'  => [
				'kingdom' => ['x' => 227,  'y' => 170,  'w' => 283, 'h' => 283],
				'park'    => ['x' => 2040, 'y' => 170,  'w' => 283, 'h' => 283],
				'player'  => ['x' => 1063, 'y' => 1870, 'w' => 425, 'h' => 425],
			],
		],
	];

	/**
	 * Color palettes.
	 */
	private static $PALETTES = [
		'classic' => ['bg' => [245, 230, 200], 'text' => [45, 27, 0],   'accent' => [139, 105, 20], 'border' => [107, 90, 50]],
		'royal'   => ['bg' => [238, 242, 249], 'text' => [26, 58, 107], 'accent' => [196, 151, 42], 'border' => [26, 58, 107]],
		'nature'   => ['bg' => [240, 230, 208], 'text' => [45, 80, 22],  'accent' => [184, 148, 42], 'border' => [45, 80, 22]],
		'crimson'  => ['bg' => [249, 240, 240], 'text' => [74, 16, 16],  'accent' => [139, 26, 26],  'border' => [107, 46, 46]],
		'obsidian' => ['bg' => [232, 228, 223], 'text' => [26, 26, 46],  'accent' => [112, 96, 64],  'border' => [61, 61, 80]],
		'white'    => ['bg' => [255, 255, 255], 'text' => [26, 26, 26],  'accent' => [85, 85, 85],   'border' => [153, 153, 153]],
	];

	/**
	 * Font file map (font key => filename).
	 */
	private static $FONTS = [
		// Blackletter / Gothic
		'UnifrakturMaguntia' => 'UnifrakturMaguntia-Book.ttf',
		'Grenze Gotisch'     => 'GrenzeGotisch-Regular.ttf',
		'Pirata One'         => 'PirataOne-Regular.ttf',
		'Germania One'       => 'GermaniaOne-Regular.ttf',
		// Medieval / Renaissance
		'MedievalSharp'      => 'MedievalSharp-Regular.ttf',
		'Metamorphous'       => 'Metamorphous-Regular.ttf',
		'Almendra'           => 'Almendra-Regular.ttf',
		'Eagle Lake'         => 'EagleLake-Regular.ttf',
		'Uncial Antiqua'     => 'UncialAntiqua-Regular.ttf',
		// Classical Serif
		'Cinzel'             => 'Cinzel-Regular.ttf',
		'Cinzel Decorative'  => 'CinzelDecorative-Regular.ttf',
		'EB Garamond'        => 'EBGaramond-Regular.ttf',
		'Cormorant Garamond' => 'CormorantGaramond-Regular.ttf',
		'Caudex'             => 'Caudex-Regular.ttf',
		'Sorts Mill Goudy'   => 'SortsMillGoudy-Regular.ttf',
		'Goudy Bookletter 1911' => 'GoudyBookletter1911.ttf',
		// Calligraphy / Script
		'Fondamento'         => 'Fondamento-Regular.ttf',
		'Jim Nightshade'     => 'JimNightshade-Regular.ttf',
		'Pinyon Script'      => 'PinyonScript-Regular.ttf',
		'Great Vibes'        => 'GreatVibes-Regular.ttf',
		'Tangerine'          => 'Tangerine-Regular.ttf',
	];

	// ================================================================
	//  POST /ScrollAjax/generate
	// ================================================================

	public function generate($id = null) {
		// ---- Auth check ----
		if (!isset($this->session->user_id)) {
			header('Content-Type: application/json');
			echo json_encode(['status' => 5, 'error' => 'Not logged in']);
			exit;
		}

		// ---- Read POST parameters ----
		$template  = trim($_POST['template']  ?? 'B');
		$palette   = trim($_POST['palette']   ?? 'classic');
		$borderStyle = trim($_POST['borderStyle'] ?? 'classic');
		// Per-element font keys
		$fontKeyTitle      = trim($_POST['font_title']      ?? $_POST['font'] ?? 'MedievalSharp');
		$fontKeyRecipient  = trim($_POST['font_recipient']  ?? $_POST['font'] ?? 'MedievalSharp');
		$fontKeyBody       = trim($_POST['font_body']       ?? 'EB Garamond');
		$fontKeySignatures = trim($_POST['font_signatures'] ?? 'EB Garamond');
		$recipient = trim($_POST['recipient'] ?? '');
		$awardName = trim($_POST['awardName'] ?? '');
		$rank      = (int)($_POST['rank']     ?? 0);
		$date      = trim($_POST['date']      ?? '');
		$givenBy   = trim($_POST['givenBy']   ?? '');
		$park      = trim($_POST['park']      ?? '');
		$kingdom   = trim($_POST['kingdom']   ?? '');
		$bodyText  = trim($_POST['bodyText']  ?? '');

		$sig1_name = trim($_POST['sig1_name'] ?? '');
		$sig1_role = trim($_POST['sig1_role'] ?? '');
		$sig2_name = trim($_POST['sig2_name'] ?? '');
		$sig2_role = trim($_POST['sig2_role'] ?? '');
		$sig3_name = trim($_POST['sig3_name'] ?? '');
		$sig3_role = trim($_POST['sig3_role'] ?? '');
		$sig2_visible = ($_POST['sig2_visible'] ?? '1') === '1';

		$heraldry_kingdom = trim($_POST['heraldry_kingdom'] ?? '');
		$heraldry_park    = trim($_POST['heraldry_park']    ?? '');
		$heraldry_player  = trim($_POST['heraldry_player']  ?? '');

		// ---- Validate template / palette ----
		if (!isset(self::$TEMPLATES[$template])) $template = 'B';
		if (!isset(self::$PALETTES[$palette]))   $palette  = 'classic';

		$tpl = self::$TEMPLATES[$template];
		$pal = self::$PALETTES[$palette];

		// ---- Resolve per-element font paths ----
		$fontDir = DIR_ASSETS . 'scroll/fonts/';
		$fallbackFont = $fontDir . 'EBGaramond-Regular.ttf';

		$fontFiles = [];
		$fontKeys = [
			'title'      => $fontKeyTitle,
			'recipient'  => $fontKeyRecipient,
			'body'       => $fontKeyBody,
			'signatures' => $fontKeySignatures,
		];
		foreach ($fontKeys as $slot => $key) {
			$fontFiles[$slot] = null;
			if (isset(self::$FONTS[$key])) {
				$candidate = $fontDir . self::$FONTS[$key];
				if (file_exists($candidate)) {
					$fontFiles[$slot] = $candidate;
				}
			}
			if ($fontFiles[$slot] === null && file_exists($fallbackFont)) {
				$fontFiles[$slot] = $fallbackFont;
			}
		}
		$useBuiltinFont = ($fontFiles['title'] === null);
		$fontFile = $fontFiles['title'];
		$bodyFontFile = $fontFiles['body'] ?: $fontFiles['title'];

		// ---- Create image ----
		$img = @imagecreatetruecolor(self::W, self::H);
		if (!$img) {
			header('Content-Type: application/json');
			echo json_encode(['status' => 1, 'error' => 'Failed to generate scroll image']);
			exit;
		}

		// ---- Allocate colors ----
		$cBg     = imagecolorallocate($img, $pal['bg'][0],     $pal['bg'][1],     $pal['bg'][2]);
		$cText   = imagecolorallocate($img, $pal['text'][0],   $pal['text'][1],   $pal['text'][2]);
		$cAccent = imagecolorallocate($img, $pal['accent'][0], $pal['accent'][1], $pal['accent'][2]);
		$cBorder = imagecolorallocate($img, $pal['border'][0], $pal['border'][1], $pal['border'][2]);

		// ---- Fill background ----
		imagefill($img, 0, 0, $cBg);

		// ---- Noise texture overlay (5% opacity) ----
		$noiseColor = imagecolorallocatealpha($img, 0, 0, 0, 121); // ~5% opacity
		for ($nx = 0; $nx < self::W; $nx += 12) {
			for ($ny = 0; $ny < self::H; $ny += 12) {
				if (mt_rand(0, 1)) {
					imagefilledrectangle($img, $nx, $ny, $nx + 5, $ny + 5, $noiseColor);
				}
			}
		}

		// ---- Radial vignette ----
		$vignetteImg = imagecreatetruecolor(self::W, self::H);
		imagefill($vignetteImg, 0, 0, imagecolorallocate($vignetteImg, 0, 0, 0));
		$vigCenterX = (int)(self::W / 2);
		$vigCenterY = (int)(self::H / 2);
		$vigRadius = (int)(self::W * 0.75);
		// Draw a white ellipse in center (will act as transparency mask)
		$vigWhite = imagecolorallocate($vignetteImg, 255, 255, 255);
		imagefilledellipse($vignetteImg, $vigCenterX, $vigCenterY, (int)(self::W * 0.4), (int)(self::W * 0.4), $vigWhite);
		// Apply as semi-transparent overlay
		imagecopymerge($img, $vignetteImg, 0, 0, 0, 0, self::W, self::H, 4); // 4% merge
		imagedestroy($vignetteImg);

		// ---- Draw border (double-line rectangle + corner ornaments) ----
		$this->drawBorder($img, $cBorder, $cAccent, $pal, $template, $borderStyle);

		// ---- Draw heraldry ----
		$this->drawHeraldryImage($img, $heraldry_kingdom, $tpl['heraldry']['kingdom']);
		$this->drawHeraldryImage($img, $heraldry_park,    $tpl['heraldry']['park']);
		$this->drawHeraldryImage($img, $heraldry_player,  $tpl['heraldry']['player']);

		// ---- Title text (centered, accent color) ----
		$titleText = strlen($awardName) ? $awardName : 'Award Title';
		$this->drawCenteredText($img, $titleText, $tpl['title'], $cAccent, $fontFiles['title'], $useBuiltinFont);

		// Decorative divider above title (Template A only)
		$titleFontSize = $tpl['title']['size'];
		if ($template === 'A') {
			$this->drawDivider($img, (int)(self::W / 2), $tpl['title']['y'] - (int)(30 * self::SCALE), (int)(250 * self::SCALE), $pal, 0.6);
		}
		// Decorative divider below title
		$divider1Y = $tpl['title']['y'] + $titleFontSize + (int)(25 * self::SCALE);
		$this->drawDivider($img, (int)(self::W / 2), $divider1Y, (int)(250 * self::SCALE), $pal, 0.6);

		// ---- Recipient name (centered, text color) ----
		$recipientText = strlen($recipient) ? $recipient : 'Recipient Name';
		$this->drawCenteredText($img, $recipientText, $tpl['recipient'], $cText, $fontFiles['recipient'], $useBuiltinFont);

		// ---- Body text (word-wrapped, centered lines) ----
		$bodyContent = strlen($bodyText) ? $bodyText : $this->generateBodyText($recipient, $awardName, $rank, $date, $kingdom, $template, $park);
		$this->drawWrappedText($img, $bodyContent, $tpl['body'], $cText, $fontFiles['body'], $useBuiltinFont);

		// ---- Date / location line ----
		$dateLine = '';
		if (strlen($park) || strlen($kingdom)) {
			$dateLine = 'Given at';
			if (strlen($park)) {
				$dateLine .= ' ' . $park;
			}
			if (strlen($kingdom)) {
				$dateLine .= (strlen($park) ? ', ' : ' ') . $kingdom;
			}
		}
		if (strlen($dateLine)) {
			$dateSize = (int)($tpl['body']['size'] * 0.8);
			$dateY = $tpl['sigY'] - (int)(40 * self::SCALE);
			$dateColor = imagecolorallocatealpha($img, $pal['text'][0], $pal['text'][1], $pal['text'][2], 51); // ~60% opacity
			if (!$useBuiltinFont) {
				$box = imagettfbbox($dateSize, 0, ($fontFiles['body'] ?: $bodyFontFile), $dateLine);
				$dateW = $box[2] - $box[0];
				imagettftext($img, $dateSize, 0, (int)(self::W / 2) - (int)($dateW / 2), $dateY, $dateColor, ($fontFiles['body'] ?: $bodyFontFile), $dateLine);
			} else {
				$this->drawBuiltinCentered($img, $dateLine, self::W / 2, $dateY, $dateColor);
			}
		}

		// ---- Seal element ----
		$sealX = (int)(self::W / 2);
		$sealY = $tpl['sigY'] - (int)(100 * self::SCALE);
		// Outer circle (radius 50*3=150, 2px*3=6 thick)
		$sealOuterColor = imagecolorallocatealpha($img, $pal['accent'][0], $pal['accent'][1], $pal['accent'][2], 51); // 60% opacity
		imagesetthickness($img, (int)(2 * self::SCALE));
		imageellipse($img, $sealX, $sealY, 300, 300, $sealOuterColor);
		// Inner circle (radius 38*3=114, 1px*3=3 thick)
		$sealInnerColor = imagecolorallocatealpha($img, $pal['accent'][0], $pal['accent'][1], $pal['accent'][2], 76); // 40% opacity
		imagesetthickness($img, (int)(1 * self::SCALE));
		imageellipse($img, $sealX, $sealY, 228, 228, $sealInnerColor);
		// 12 radial tick marks (8px*3=24 long)
		$sealTickColor = imagecolorallocatealpha($img, $pal['accent'][0], $pal['accent'][1], $pal['accent'][2], 64); // 50% opacity
		imagesetthickness($img, (int)(1 * self::SCALE));
		for ($ti = 0; $ti < 12; $ti++) {
			$angle = ($ti / 12.0) * 2.0 * M_PI;
			$tx1 = $sealX + (int)(cos($angle) * 150);
			$ty1 = $sealY + (int)(sin($angle) * 150);
			$tx2 = $sealX + (int)(cos($angle) * 174);
			$ty2 = $sealY + (int)(sin($angle) * 174);
			imageline($img, $tx1, $ty1, $tx2, $ty2, $sealTickColor);
		}
		// Center initials (skip "The", "Kingdom", "of")
		if (strlen($kingdom) > 0 && !$useBuiltinFont) {
			$sealLetterColor = imagecolorallocatealpha($img, $pal['accent'][0], $pal['accent'][1], $pal['accent'][2], 95); // 25% opacity
			$skipWords = ['the', 'kingdom', 'of'];
			$words = preg_split('/\s+/', $kingdom);
			$initials = '';
			foreach ($words as $w) {
				if (!in_array(mb_strtolower($w), $skipWords)) {
					$initials .= mb_strtoupper(mb_substr($w, 0, 1));
				}
			}
			if (strlen($initials) > 0) {
				$sealFontSize = (int)((mb_strlen($initials) > 2 ? 28 : 36) * self::SCALE);
				$sealFont = $fontFiles['body'] ?: $bodyFontFile;
				$box = imagettfbbox($sealFontSize, 0, $sealFont, $initials);
				$slW = $box[2] - $box[0];
				$slH = $box[1] - $box[5];
				imagettftext($img, $sealFontSize, 0, $sealX - (int)($slW / 2), $sealY + (int)($slH / 2), $sealLetterColor, $sealFont, $initials);
			}
		}
		imagesetthickness($img, 1);

		// ---- Decorative divider above signatures ----
		$this->drawDivider($img, (int)(self::W / 2), $tpl['sigY'] - (int)(60 * self::SCALE), (int)(350 * self::SCALE), $pal, 0.4);

		// ---- Signature lines ----
		$allSigs = [
			['name' => $sig1_name, 'role' => $sig1_role],
			['name' => $sig2_name, 'role' => $sig2_role],
			['name' => $sig3_name, 'role' => $sig3_role],
		];
		// Build active sigs list: sig1 always, sig2 if visible, sig3 if template allows
		$sigs = [$allSigs[0]];
		if ($sig2_visible) $sigs[] = $allSigs[1];
		if ($tpl['sigCount'] >= 3) $sigs[] = $allSigs[2];
		$sigCount = count($sigs);
		$sigSpacing = (int)(self::W / ($sigCount + 1));
		$lineW     = (int)(180 * self::SCALE);
		$sigLineY  = $tpl['sigY'] + (int)(30 * self::SCALE);

		$sigTextColor  = imagecolorallocatealpha($img, $pal['text'][0], $pal['text'][1], $pal['text'][2], 0);   // 100% opacity
		$sigLineColor  = imagecolorallocatealpha($img, $pal['text'][0], $pal['text'][1], $pal['text'][2], 51);  // ~60% opacity
		$sigRoleColor  = imagecolorallocatealpha($img, $pal['text'][0], $pal['text'][1], $pal['text'][2], 45);  // ~65% opacity

		imagesetthickness($img, (int)(1 * self::SCALE));

		for ($si = 0; $si < $sigCount; $si++) {
			$sigX = $sigSpacing * ($si + 1);

			// Signature line
			imageline($img, $sigX - (int)($lineW / 2), $sigLineY, $sigX + (int)($lineW / 2), $sigLineY, $sigLineColor);

			// Serif ticks at endpoints (3px * 3 = 9px vertical)
			$tickH = (int)(3 * self::SCALE);
			imageline($img, $sigX - (int)($lineW / 2), $sigLineY - $tickH, $sigX - (int)($lineW / 2), $sigLineY + $tickH, $sigLineColor);
			imageline($img, $sigX + (int)($lineW / 2), $sigLineY - $tickH, $sigX + (int)($lineW / 2), $sigLineY + $tickH, $sigLineColor);

			// Name above line
			$sigName = $sigs[$si]['name'] ?? '';
			if (strlen($sigName)) {
				$nameSize = (int)($tpl['body']['size'] * 0.85);
				if (!$useBuiltinFont) {
					$box = imagettfbbox($nameSize, 0, ($fontFiles['signatures'] ?: $bodyFontFile), $sigName);
					$nameW = $box[2] - $box[0];
					$nameY = $tpl['sigY'] + (int)(8 * self::SCALE);
					imagettftext($img, $nameSize, 0, $sigX - (int)($nameW / 2), $nameY, $sigTextColor, ($fontFiles['signatures'] ?: $bodyFontFile), $sigName);
				} else {
					$this->drawBuiltinCentered($img, $sigName, $sigX, $tpl['sigY'] + (int)(8 * self::SCALE), $sigTextColor);
				}
			}

			// Role below line
			$sigRole = $sigs[$si]['role'] ?? '';
			if (strlen($sigRole)) {
				$roleSize = (int)($tpl['body']['size'] * 0.7);
				$roleY = $tpl['sigY'] + (int)(48 * self::SCALE);
				if (!$useBuiltinFont) {
					$box = imagettfbbox($roleSize, 0, ($fontFiles['signatures'] ?: $bodyFontFile), $sigRole);
					$roleW = $box[2] - $box[0];
					imagettftext($img, $roleSize, 0, $sigX - (int)($roleW / 2), $roleY, $sigRoleColor, ($fontFiles['signatures'] ?: $bodyFontFile), $sigRole);
				} else {
					$this->drawBuiltinCentered($img, $sigRole, $sigX, $roleY, $sigRoleColor);
				}
			}
		}

		imagesetthickness($img, 1);

		// ---- Output PNG ----
		$safeName  = preg_replace('/[^a-zA-Z0-9]/', '_', $recipient ?: 'scroll');
		$safeAward = preg_replace('/[^a-zA-Z0-9]/', '_', $awardName ?: 'award');
		$filename  = 'scroll_' . $safeName . '_' . $safeAward . '.png';

		header('Content-Type: image/png');
		header('Content-Disposition: attachment; filename="' . $filename . '"');
		imagepng($img);
		imagedestroy($img);
		exit;
	}

	// ================================================================
	//  Private helpers
	// ================================================================

	/**
	 * Draw decorative divider (diamond-line-diamond motif).
	 */
	private function drawDivider($img, $cx, $cy, $width, $pal, $opacity) {
		// opacity: 0.0-1.0 => alpha: 127-0
		$alpha = (int)(127 * (1 - $opacity));
		$color = imagecolorallocatealpha($img, $pal['accent'][0], $pal['accent'][1], $pal['accent'][2], $alpha);

		// Left line
		imagesetthickness($img, (int)(1 * self::SCALE));
		imageline($img, $cx - (int)($width / 2), $cy, $cx - (int)(8 * self::SCALE), $cy, $color);
		// Right line
		imageline($img, $cx + (int)(8 * self::SCALE), $cy, $cx + (int)($width / 2), $cy, $color);

		// Center diamond (18px tall at print scale => 5*3=15 half-height, 6*3=18 half-width)
		$dh = (int)(5 * self::SCALE);
		$dw = (int)(6 * self::SCALE);
		$diamondPts = [$cx, $cy - $dh, $cx + $dw, $cy, $cx, $cy + $dh, $cx - $dw, $cy];
		imagefilledpolygon($img, $diamondPts, $color);

		// Endpoint dots (radius 2*3=6)
		$dotR = (int)(2 * self::SCALE);
		imagefilledellipse($img, $cx - (int)($width / 2), $cy, $dotR * 2, $dotR * 2, $color);
		imagefilledellipse($img, $cx + (int)($width / 2), $cy, $dotR * 2, $dotR * 2, $color);

		imagesetthickness($img, 1);
	}

	/**
	 * Draw decorative border matching the selected borderStyle.
	 */
	private function drawBorder($img, $cBorder, $cAccent, $pal, $template = 'B', $borderStyle = 'classic') {
		$w = self::W;
		$h = self::H;
		$s = self::SCALE;

		if ($borderStyle === 'none') return;

		switch ($borderStyle) {
			case 'ornate':
				$this->drawBorderOrnate($img, $cBorder, $cAccent, $pal);
				break;
			case 'celtic':
				$this->drawBorderCeltic($img, $cBorder, $cAccent, $pal);
				break;
			case 'simple':
				$this->drawBorderSimple($img, $cBorder);
				break;
			case 'royal':
				$this->drawBorderRoyal($img, $cBorder, $cAccent, $pal);
				break;
			case 'rustic':
				$this->drawBorderRustic($img, $cBorder, $pal);
				break;
			case 'filigree':
				$this->drawBorderFiligree($img, $cBorder, $cAccent, $pal);
				break;
			case 'classic':
			default:
				$this->drawBorderClassic($img, $cBorder, $cAccent, $pal);
				break;
		}
	}

	private function drawBorderClassic($img, $cBorder, $cAccent, $pal) {
		$w = self::W; $h = self::H; $s = self::SCALE;
		imagesetthickness($img, (int)(4*$s));
		$o = (int)(28*$s);
		imagerectangle($img, $o, $o, $w-$o-1, $h-$o-1, $cBorder);
		imagesetthickness($img, (int)(2*$s));
		$i = (int)(36*$s);
		imagerectangle($img, $i, $i, $w-$i-1, $h-$i-1, $cBorder);
		// Corner ornaments
		$cornerSize = (int)(65*$s);
		$corners = [
			[(int)(30*$s), (int)(30*$s), 1, 1],
			[$w-(int)(30*$s), (int)(30*$s), -1, 1],
			[(int)(30*$s), $h-(int)(30*$s), 1, -1],
			[$w-(int)(30*$s), $h-(int)(30*$s), -1, -1],
		];
		foreach ($corners as $c) {
			$cx=$c[0]; $cy=$c[1]; $dx=$c[2]; $dy=$c[3];
			$points = [
				$cx+$dx*(int)(11*$s), $cy,
				$cx+$dx*(int)(20*$s), $cy+$dy*(int)(9*$s),
				$cx+$dx*(int)(11*$s), $cy+$dy*(int)(18*$s),
				$cx+$dx*(int)(2*$s),  $cy+$dy*(int)(9*$s),
			];
			imagefilledpolygon($img, $points, $cAccent);
			$innerPts = [
				$cx+$dx*(int)(11*$s), $cy+$dy*(int)(2*$s),
				$cx+$dx*(int)(16*$s), $cy+$dy*(int)(9*$s),
				$cx+$dx*(int)(11*$s), $cy+$dy*(int)(16*$s),
				$cx+$dx*(int)(6*$s),  $cy+$dy*(int)(9*$s),
			];
			imagesetthickness($img, (int)(1*$s));
			imagepolygon($img, $innerPts, $cAccent);
			imagesetthickness($img, (int)(2.5*$s));
			imageline($img, $cx, $cy+$dy*$cornerSize, $cx, $cy, $cAccent);
			imageline($img, $cx, $cy, $cx+$dx*$cornerSize, $cy, $cAccent);
		}
		imagesetthickness($img, (int)(2*$s));
		$midX = (int)($w/2);
		$arcSpan = (int)(60*$s);
		imageline($img, $midX-$arcSpan, (int)(22*$s), $midX, (int)(12*$s), $cAccent);
		imageline($img, $midX, (int)(12*$s), $midX+$arcSpan, (int)(22*$s), $cAccent);
		imageline($img, $midX-$arcSpan, $h-(int)(22*$s), $midX, $h-(int)(12*$s), $cAccent);
		imageline($img, $midX, $h-(int)(12*$s), $midX+$arcSpan, $h-(int)(22*$s), $cAccent);
		$sideColor = imagecolorallocatealpha($img, $pal['border'][0], $pal['border'][1], $pal['border'][2], 89);
		imagesetthickness($img, (int)(1*$s));
		$topY=(int)(80*$s); $botY=$h-(int)(80*$s);
		$lx1=(int)(36*$s); $lx2=(int)(40*$s);
		imageline($img, $lx1, $topY, $lx1, $botY, $sideColor);
		imageline($img, $lx2, $topY, $lx2, $botY, $sideColor);
		imageline($img, $w-$lx1, $topY, $w-$lx1, $botY, $sideColor);
		imageline($img, $w-$lx2, $topY, $w-$lx2, $botY, $sideColor);
		imagesetthickness($img, 1);
	}

	private function drawBorderOrnate($img, $cBorder, $cAccent, $pal) {
		$w = self::W; $h = self::H; $s = self::SCALE;
		imagesetthickness($img, (int)(5*$s));
		$o=(int)(22*$s);
		imagerectangle($img, $o, $o, $w-$o-1, $h-$o-1, $cBorder);
		$midColor = imagecolorallocatealpha($img, $pal['accent'][0], $pal['accent'][1], $pal['accent'][2], 76);
		imagesetthickness($img, (int)(1*$s));
		$m=(int)(30*$s);
		imagerectangle($img, $m, $m, $w-$m-1, $h-$m-1, $midColor);
		imagesetthickness($img, (int)(2*$s));
		$i=(int)(36*$s);
		imagerectangle($img, $i, $i, $w-$i-1, $h-$i-1, $cBorder);
		// Corner flourishes — diamond + dots
		$corners = [
			[(int)(24*$s),(int)(24*$s),1,1],
			[$w-(int)(24*$s),(int)(24*$s),-1,1],
			[(int)(24*$s),$h-(int)(24*$s),1,-1],
			[$w-(int)(24*$s),$h-(int)(24*$s),-1,-1],
		];
		foreach ($corners as $c) {
			$cx=$c[0]; $cy=$c[1]; $dx=$c[2]; $dy=$c[3];
			$pts = [
				$cx+$dx*(int)(14*$s), $cy+$dy*(int)(4*$s),
				$cx+$dx*(int)(22*$s), $cy+$dy*(int)(14*$s),
				$cx+$dx*(int)(14*$s), $cy+$dy*(int)(24*$s),
				$cx+$dx*(int)(6*$s),  $cy+$dy*(int)(14*$s),
			];
			imagefilledpolygon($img, $pts, $cAccent);
			imagesetthickness($img, (int)(2*$s));
			imageline($img, $cx, $cy+$dy*(int)(80*$s), $cx, $cy, $cAccent);
			imageline($img, $cx, $cy, $cx+$dx*(int)(80*$s), $cy, $cAccent);
			imagefilledellipse($img, $cx+$dx*(int)(35*$s), $cy+$dy*(int)(6*$s), (int)(6*$s), (int)(6*$s), $cAccent);
			imagefilledellipse($img, $cx+$dx*(int)(6*$s), $cy+$dy*(int)(35*$s), (int)(6*$s), (int)(6*$s), $cAccent);
		}
		// Center crests
		imagesetthickness($img, (int)(2*$s));
		$midX=(int)($w/2); $arcSpan=(int)(80*$s);
		imageline($img, $midX-$arcSpan, (int)(20*$s), $midX, (int)(10*$s), $cAccent);
		imageline($img, $midX, (int)(10*$s), $midX+$arcSpan, (int)(20*$s), $cAccent);
		imageline($img, $midX, (int)(8*$s), $midX, (int)(20*$s), $cAccent);
		imageline($img, $midX-$arcSpan, $h-(int)(20*$s), $midX, $h-(int)(10*$s), $cAccent);
		imageline($img, $midX, $h-(int)(10*$s), $midX+$arcSpan, $h-(int)(20*$s), $cAccent);
		// Side triple lines
		$sideColor = imagecolorallocatealpha($img, $pal['border'][0], $pal['border'][1], $pal['border'][2], 95);
		imagesetthickness($img, (int)(1*$s));
		$topY=(int)(90*$s); $botY=$h-(int)(90*$s);
		for ($si=0; $si<3; $si++) {
			$sx=(int)((38+$si*3)*$s);
			imageline($img, $sx, $topY, $sx, $botY, $sideColor);
			imageline($img, $w-$sx, $topY, $w-$sx, $botY, $sideColor);
		}
		imagesetthickness($img, 1);
	}

	private function drawBorderCeltic($img, $cBorder, $cAccent, $pal) {
		$w = self::W; $h = self::H; $s = self::SCALE;
		$m = (int)(30*$s);
		imagesetthickness($img, (int)(3*$s));
		imagerectangle($img, $m, $m, $w-$m-1, $h-$m-1, $cBorder);
		imagesetthickness($img, (int)(1*$s));
		imagerectangle($img, $m+(int)(6*$s), $m+(int)(6*$s), $w-$m-(int)(6*$s)-1, $h-$m-(int)(6*$s)-1, $cBorder);
		// Knotwork corners — interlocking circles
		$knotR = (int)(22*$s);
		$corners = [[$m,$m,1,1],[$w-$m,$m,-1,1],[$m,$h-$m,1,-1],[$w-$m,$h-$m,-1,-1]];
		imagesetthickness($img, (int)(2*$s));
		foreach ($corners as $c) {
			$cx=$c[0]; $cy=$c[1]; $dx=$c[2]; $dy=$c[3];
			imagearc($img, $cx+$dx*$knotR, $cy, $knotR*2, $knotR*2, 0, 360, $cAccent);
			imagearc($img, $cx, $cy+$dy*$knotR, $knotR*2, $knotR*2, 0, 360, $cAccent);
			imagefilledellipse($img, $cx+$dx*(int)($knotR/2), $cy+$dy*(int)($knotR/2), (int)(8*$s), (int)(8*$s), $cAccent);
		}
		imagesetthickness($img, 1);
	}

	private function drawBorderSimple($img, $cBorder) {
		$w = self::W; $h = self::H; $s = self::SCALE;
		imagesetthickness($img, (int)(2*$s));
		$o = (int)(32*$s);
		imagerectangle($img, $o, $o, $w-$o-1, $h-$o-1, $cBorder);
		imagesetthickness($img, 1);
	}

	private function drawBorderRoyal($img, $cBorder, $cAccent, $pal) {
		$w = self::W; $h = self::H; $s = self::SCALE;
		imagesetthickness($img, (int)(7*$s));
		$o=(int)(20*$s);
		imagerectangle($img, $o, $o, $w-$o-1, $h-$o-1, $cAccent);
		imagesetthickness($img, (int)(1*$s));
		$i1=(int)(28*$s);
		imagerectangle($img, $i1, $i1, $w-$i1-1, $h-$i1-1, $cBorder);
		$i2=(int)(14*$s);
		imagerectangle($img, $i2, $i2, $w-$i2-1, $h-$i2-1, $cBorder);
		// Corner dots + fleur shapes
		$corners = [[$o,$o,1,1],[$w-$o,$o,-1,1],[$o,$h-$o,1,-1],[$w-$o,$h-$o,-1,-1]];
		foreach ($corners as $c) {
			$cx=$c[0]; $cy=$c[1]; $dx=$c[2]; $dy=$c[3];
			imagefilledellipse($img, $cx+$dx*(int)(12*$s), $cy+$dy*(int)(12*$s), (int)(10*$s), (int)(10*$s), $cAccent);
			imagefilledellipse($img, $cx+$dx*(int)(25*$s), $cy+$dy*(int)(4*$s), (int)(5*$s), (int)(5*$s), $cAccent);
			imagefilledellipse($img, $cx+$dx*(int)(4*$s), $cy+$dy*(int)(25*$s), (int)(5*$s), (int)(5*$s), $cAccent);
			imagesetthickness($img, (int)(2*$s));
			imageline($img, $cx+$dx*(int)(8*$s), $cy+$dy*(int)(8*$s), $cx+$dx*(int)(8*$s), $cy+$dy*(int)(50*$s), $cAccent);
			imageline($img, $cx+$dx*(int)(8*$s), $cy+$dy*(int)(8*$s), $cx+$dx*(int)(50*$s), $cy+$dy*(int)(8*$s), $cAccent);
		}
		// Crown arch top/bottom
		imagesetthickness($img, (int)(2.5*$s));
		$midX=(int)($w/2);
		$arcSpan=(int)(90*$s);
		imageline($img, $midX-$arcSpan, (int)(16*$s), $midX-(int)(20*$s), (int)(12*$s), $cAccent);
		imageline($img, $midX-(int)(20*$s), (int)(12*$s), $midX, (int)(8*$s), $cAccent);
		imageline($img, $midX, (int)(8*$s), $midX+(int)(20*$s), (int)(12*$s), $cAccent);
		imageline($img, $midX+(int)(20*$s), (int)(12*$s), $midX+$arcSpan, (int)(16*$s), $cAccent);
		imagefilledellipse($img, $midX, (int)(8*$s), (int)(8*$s), (int)(8*$s), $cAccent);
		imageline($img, $midX-$arcSpan, $h-(int)(16*$s), $midX-(int)(20*$s), $h-(int)(12*$s), $cAccent);
		imageline($img, $midX-(int)(20*$s), $h-(int)(12*$s), $midX, $h-(int)(8*$s), $cAccent);
		imageline($img, $midX, $h-(int)(8*$s), $midX+(int)(20*$s), $h-(int)(12*$s), $cAccent);
		imageline($img, $midX+(int)(20*$s), $h-(int)(12*$s), $midX+$arcSpan, $h-(int)(16*$s), $cAccent);
		imagefilledellipse($img, $midX, $h-(int)(8*$s), (int)(8*$s), (int)(8*$s), $cAccent);
		imagesetthickness($img, 1);
	}

	private function drawBorderRustic($img, $cBorder, $pal) {
		$w = self::W; $h = self::H; $s = self::SCALE;
		imagesetthickness($img, (int)(3*$s));
		$o=(int)(26*$s);
		imagerectangle($img, $o, $o, $w-$o-1, $h-$o-1, $cBorder);
		$sideColor = imagecolorallocatealpha($img, $pal['border'][0], $pal['border'][1], $pal['border'][2], 64);
		imagesetthickness($img, (int)(1.5*$s));
		$i=(int)(34*$s);
		imagerectangle($img, $i, $i, $w-$i-1, $h-$i-1, $sideColor);
		// Corner X marks
		imagesetthickness($img, (int)(2*$s));
		$xColor = imagecolorallocatealpha($img, $pal['border'][0], $pal['border'][1], $pal['border'][2], 51);
		$corners = [[(int)(30*$s),(int)(30*$s),1,1],[$w-(int)(30*$s),(int)(30*$s),-1,1],
			[(int)(30*$s),$h-(int)(30*$s),1,-1],[$w-(int)(30*$s),$h-(int)(30*$s),-1,-1]];
		foreach ($corners as $c) {
			$cx=$c[0]; $cy=$c[1]; $dx=$c[2]; $dy=$c[3];
			imageline($img, $cx+$dx*(int)(4*$s), $cy+$dy*(int)(4*$s), $cx+$dx*(int)(18*$s), $cy+$dy*(int)(18*$s), $xColor);
			imageline($img, $cx+$dx*(int)(18*$s), $cy+$dy*(int)(4*$s), $cx+$dx*(int)(4*$s), $cy+$dy*(int)(18*$s), $xColor);
		}
		imagesetthickness($img, 1);
	}

	private function drawBorderFiligree($img, $cBorder, $cAccent, $pal) {
		$w = self::W; $h = self::H; $s = self::SCALE;
		imagesetthickness($img, (int)(1.5*$s));
		$o = (int)(28*$s);
		imagerectangle($img, $o, $o, $w-$o-1, $h-$o-1, $cBorder);
		// Corner vine lines
		$corners = [[$o,$o,1,1],[$w-$o,$o,-1,1],[$o,$h-$o,1,-1],[$w-$o,$h-$o,-1,-1]];
		imagesetthickness($img, (int)(1.5*$s));
		foreach ($corners as $c) {
			$cx=$c[0]; $cy=$c[1]; $dx=$c[2]; $dy=$c[3];
			imageline($img, $cx, $cy+$dy*(int)(70*$s), $cx+$dx*(int)(6*$s), $cy+$dy*(int)(6*$s), $cAccent);
			imageline($img, $cx+$dx*(int)(6*$s), $cy+$dy*(int)(6*$s), $cx+$dx*(int)(70*$s), $cy, $cAccent);
			// Spiral hints
			imageline($img, $cx+$dx*(int)(6*$s), $cy+$dy*(int)(6*$s), $cx+$dx*(int)(18*$s), $cy+$dy*(int)(4*$s), $cAccent);
			imageline($img, $cx+$dx*(int)(6*$s), $cy+$dy*(int)(6*$s), $cx+$dx*(int)(4*$s), $cy+$dy*(int)(18*$s), $cAccent);
			// Leaf dots
			for ($li=0; $li<3; $li++) {
				imagefilledellipse($img, $cx+$dx*(int)((15+$li*16)*$s), $cy+$dy*(int)(2*$s), (int)(8*$s), (int)(4*$s), $cAccent);
				imagefilledellipse($img, $cx+$dx*(int)(2*$s), $cy+$dy*(int)((15+$li*16)*$s), (int)(4*$s), (int)(8*$s), $cAccent);
			}
		}
		// Top/bottom center leaf
		$midX=(int)($w/2);
		$leafColor = imagecolorallocatealpha($img, $pal['accent'][0], $pal['accent'][1], $pal['accent'][2], 51);
		imageline($img, $midX-(int)(40*$s), (int)(26*$s), $midX, (int)(18*$s), $leafColor);
		imageline($img, $midX, (int)(18*$s), $midX+(int)(40*$s), (int)(26*$s), $leafColor);
		imagefilledellipse($img, $midX, (int)(20*$s), (int)(10*$s), (int)(6*$s), $leafColor);
		imageline($img, $midX-(int)(40*$s), $h-(int)(26*$s), $midX, $h-(int)(18*$s), $leafColor);
		imageline($img, $midX, $h-(int)(18*$s), $midX+(int)(40*$s), $h-(int)(26*$s), $leafColor);
		imagefilledellipse($img, $midX, $h-(int)(20*$s), (int)(10*$s), (int)(6*$s), $leafColor);
		imagesetthickness($img, 1);
	}

	/**
	 * Fetch a remote heraldry image and draw it onto the canvas.
	 */
	private function drawHeraldryImage($img, $url, $pos) {
		if (!strlen($url)) return;

		// SSRF protection: only allow http/https and restrict to known heraldry paths
		$parsed = parse_url($url);
		if (!$parsed || !isset($parsed['scheme']) || !in_array($parsed['scheme'], ['http', 'https'], true)) return;
		$serverHost = $_SERVER['HTTP_HOST'] ?? '';
		if (!isset($parsed['host']) || ($parsed['host'] !== $serverHost && $parsed['host'] !== 'localhost')) return;
		if (!isset($parsed['path']) || strpos($parsed['path'], '/assets/heraldry/') === false) return;

		$ctx = stream_context_create([
			'http' => ['timeout' => 5, 'ignore_errors' => true],
		]);

		$data = @file_get_contents($url, false, $ctx);
		if ($data === false) return;

		$src = @imagecreatefromstring($data);
		if (!$src) return;

		// Resample to target size with alpha channel preserved
		$resized = imagecreatetruecolor($pos['w'], $pos['h']);
		imagealphablending($resized, false);
		imagesavealpha($resized, true);
		$transparent = imagecolorallocatealpha($resized, 0, 0, 0, 127);
		imagefill($resized, 0, 0, $transparent);
		imagealphablending($resized, true);
		imagecopyresampled(
			$resized, $src,
			0, 0,
			0, 0,
			$pos['w'], $pos['h'],
			imagesx($src), imagesy($src)
		);
		imagedestroy($src);

		// Composite onto canvas preserving source alpha
		imagealphablending($img, true);
		imagecopy($img, $resized, $pos['x'], $pos['y'], 0, 0, $pos['w'], $pos['h']);
		imagedestroy($resized);
	}

	/**
	 * Draw centered text (title or recipient), auto-shrinking if too wide.
	 * $bold = true for title text.
	 */
	private function drawCenteredText($img, $text, $spec, $color, $fontFile, $useBuiltin) {
		if ($useBuiltin) {
			$this->drawBuiltinCentered($img, $text, $spec['x'], $spec['y'], $color);
			return;
		}

		$fontSize = $this->fitFontSize($fontFile, $text, $spec['size'], $spec['maxWidth']);
		$box  = imagettfbbox($fontSize, 0, $fontFile, $text);
		$txtW = $box[2] - $box[0];
		$x    = $spec['x'] - (int)($txtW / 2);
		$y    = $spec['y'] + $fontSize; // imagettftext uses baseline

		imagettftext($img, $fontSize, 0, $x, $y, $color, $fontFile, $text);
	}

	/**
	 * Shrink font size until text fits within maxWidth.
	 */
	private function fitFontSize($fontFile, $text, $maxSize, $maxWidth) {
		$size = $maxSize;
		$minSize = (int)($maxSize * 0.3);
		while ($size > $minSize) {
			$box = imagettfbbox($size, 0, $fontFile, $text);
			$w = $box[2] - $box[0];
			if ($w <= $maxWidth) break;
			$size -= 2;
		}
		return $size;
	}

	/**
	 * Draw word-wrapped body text, centered per line.
	 */
	private function drawWrappedText($img, $text, $spec, $color, $fontFile, $useBuiltin) {
		$fontSize   = $spec['size'];
		$maxWidth   = $spec['maxWidth'];
		$lineHeight = $spec['lineHeight'];
		$centerX    = $spec['x'];
		$startY     = $spec['y'];

		if ($useBuiltin) {
			// Rough word-wrap with built-in font (font 5 is ~9px wide)
			$charWidth = 9;
			$maxChars  = (int)($maxWidth / $charWidth);
			$lines     = $this->wordWrapString($text, $maxChars);
			$y = $startY;
			foreach ($lines as $line) {
				$this->drawBuiltinCentered($img, $line, $centerX, $y, $color);
				$y += 20; // built-in font line height
			}
			return;
		}

		// Split into words and measure for wrapping
		$words = explode(' ', $text);
		$lines = [];
		$line  = '';
		foreach ($words as $word) {
			$testLine = $line . (strlen($line) ? ' ' : '') . $word;
			$box = imagettfbbox($fontSize, 0, $fontFile, $testLine);
			$testW = $box[2] - $box[0];
			if ($testW > $maxWidth && strlen($line)) {
				$lines[] = $line;
				$line = $word;
			} else {
				$line = $testLine;
			}
		}
		if (strlen($line)) $lines[] = $line;

		// Draw each line centered
		$y = $startY + $fontSize; // baseline offset
		foreach ($lines as $ln) {
			$box = imagettfbbox($fontSize, 0, $fontFile, $ln);
			$lnW = $box[2] - $box[0];
			$x   = $centerX - (int)($lnW / 2);
			imagettftext($img, $fontSize, 0, $x, $y, $color, $fontFile, $ln);
			$y += $lineHeight;
		}
	}

	/**
	 * Fallback: draw text centered using GD built-in font 5.
	 */
	private function drawBuiltinCentered($img, $text, $cx, $cy, $color) {
		$font = 5;
		$fw   = imagefontwidth($font);
		$fh   = imagefontheight($font);
		$tw   = $fw * strlen($text);
		$x    = (int)($cx - $tw / 2);
		imagestring($img, $font, $x, $cy, $text, $color);
	}

	/**
	 * Simple word-wrap for built-in font fallback.
	 */
	private function wordWrapString($text, $maxChars) {
		$words = explode(' ', $text);
		$lines = [];
		$line  = '';
		foreach ($words as $word) {
			$testLine = $line . (strlen($line) ? ' ' : '') . $word;
			if (strlen($testLine) > $maxChars && strlen($line)) {
				$lines[] = $line;
				$line = $word;
			} else {
				$line = $testLine;
			}
		}
		if (strlen($line)) $lines[] = $line;
		return $lines;
	}

	/**
	 * Generate default body text (mirrors JS sgGenerateBodyText).
	 */
	private function generateBodyText($recipient, $awardName, $rank, $date, $kingdom, $template = 'B', $park = '') {
		$persona = strlen($recipient) ? $recipient : 'the recipient';
		$award   = strlen($awardName) ? $awardName : 'this honor';
		$kingdomRef = strlen($kingdom) ? $kingdom : 'the Kingdom';

		// Parse date
		$day = 0; $suffix = 'th'; $monthName = ''; $year = '';
		if (strlen($date)) {
			$parts = explode('-', $date);
			if (count($parts) === 3) {
				$months = ['January','February','March','April','May','June',
				           'July','August','September','October','November','December'];
				$day = (int)$parts[2];
				$suffix = 'th';
				if ($day === 1 || $day === 21 || $day === 31) $suffix = 'st';
				elseif ($day === 2 || $day === 22) $suffix = 'nd';
				elseif ($day === 3 || $day === 23) $suffix = 'rd';
				$monthIdx = (int)$parts[1] - 1;
				$monthName = ($monthIdx >= 0 && $monthIdx < 12) ? $months[$monthIdx] : '';
				$year = $parts[0];
			}
		}

		if ($template === 'A') {
			// Knight / Peerage
			$text = 'To all and singular who shall see these presents, greetings. Be it known that by the right and authority vested in the Crown of ' . $kingdomRef . ', and in recognition of valor, honor, and service, We do hereby elevate ' . $persona . ' to the ' . $award . '.';
			if ($day && $monthName) {
				$text .= ' Given under Our hand this ' . $day . $suffix . ' day of ' . $monthName . ', in the year ' . $year;
				if (strlen($park)) $text .= ', at ' . $park;
				if (strlen($kingdom)) $text .= ', in the Kingdom of ' . $kingdom;
				$text .= '.';
			}
		} elseif ($template === 'C') {
			// Title / Office
			$text = 'Be it proclaimed that ' . $persona . ' is hereby recognized and granted the title of ' . $award . ', with all rights, privileges, and responsibilities thereto pertaining, by the authority of the Crown of ' . $kingdomRef . '.';
			if ($day && $monthName) {
				$text .= ' Given this ' . $day . $suffix . ' day of ' . $monthName . ', ' . $year . '.';
			}
		} else {
			// Template B: Order / Award
			$text = 'Let it be known to all that ' . $persona . ', having demonstrated worth and dedication, is hereby granted the ' . $award;
			if ($rank > 0) {
				$ordSuffix = 'th';
				if ($rank === 1 || $rank === 21 || $rank === 31) $ordSuffix = 'st';
				elseif ($rank === 2 || $rank === 22) $ordSuffix = 'nd';
				elseif ($rank === 3 || $rank === 23) $ordSuffix = 'rd';
				$text .= ', ' . $rank . $ordSuffix . ' rank';
			}
			$text .= ', by the authority of the Crown of ' . $kingdomRef . '.';
			if ($day && $monthName) {
				$text .= ' Done this ' . $day . $suffix . ' day of ' . $monthName . ', ' . $year . '.';
			}
		}

		return $text;
	}
}
