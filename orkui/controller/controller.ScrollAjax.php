<?php

class Controller_ScrollAjax extends Controller {

	/**
	 * Scale factor from preview canvas to print canvas (300 DPI letter).
	 * Preview is 850x1100 portrait; print is 2550x3300. Landscape templates
	 * flip the axes but use the same scale.
	 */
	const SCALE = 3.0;

	/**
	 * Default print canvas dimensions (portrait).
	 */
	const DEFAULT_W = 2550;
	const DEFAULT_H = 3300;

	/**
	 * Legacy template key aliases (for old clients / saved scrolls).
	 */
	private static $TEMPLATE_ALIASES = [
		'A' => 'royal_decree',
		'B' => 'heraldic_shield',
		'C' => 'chancery_letter',
	];

	/**
	 * Template definitions at print resolution (preview * SCALE).
	 * Each entry mirrors the JS TEMPLATES object 1:1.
	 */
	private static $TEMPLATES = [
		// -----------------------------------------------------
		//  Royal Decree — ribbon title + corner heraldry + seal
		// -----------------------------------------------------
		'royal_decree' => [
			'orientation' => 'portrait',
			'previewW' => 850, 'previewH' => 1100,
			'printW' => 2550, 'printH' => 3300,
			'sigCount' => 3,
			'defaults' => ['ribbon'=>true,'dropCap'=>false,'waxSeal'=>true,'swords'=>false,'medallions'=>false,'laurel'=>false,'compass'=>false,'flourishes'=>true],
			'title'     => ['x' => 1275, 'y' => 780,  'size' => 156, 'maxWidth' => 1860],
			'recipient' => ['x' => 1275, 'y' => 1080, 'size' => 120, 'maxWidth' => 2040],
			'body'      => ['x' => 1275, 'y' => 1380, 'size' => 66,  'maxWidth' => 1920, 'lineHeight' => 96],
			'sigY' => 2790,
			'heraldry'  => [
				'kingdom' => ['x' => 240,  'y' => 240,  'w' => 345, 'h' => 345],
				'park'    => ['x' => 1965, 'y' => 240,  'w' => 345, 'h' => 345],
				'player'  => ['x' => 1065, 'y' => 1770, 'w' => 420, 'h' => 420],
			],
		],

		// -----------------------------------------------------
		//  Heraldic Shield — quartered shield centerpiece
		// -----------------------------------------------------
		'heraldic_shield' => [
			'orientation' => 'portrait',
			'previewW' => 850, 'previewH' => 1100,
			'printW' => 2550, 'printH' => 3300,
			'sigCount' => 2,
			'defaults' => ['ribbon'=>false,'dropCap'=>false,'waxSeal'=>false,'swords'=>false,'medallions'=>false,'laurel'=>false,'compass'=>false,'flourishes'=>false],
			'title'     => ['x' => 1275, 'y' => 1440, 'size' => 132, 'maxWidth' => 1980],
			'recipient' => ['x' => 1275, 'y' => 1680, 'size' => 96,  'maxWidth' => 1980],
			'body'      => ['x' => 1275, 'y' => 1890, 'size' => 57,  'maxWidth' => 1860, 'lineHeight' => 84],
			'sigY' => 2880,
			'heraldry' => null,
			'shield' => ['cx' => 1275, 'cy' => 720, 'size' => 870],
		],

		// -----------------------------------------------------
		//  Chancery Letter — left-aligned epistolary
		// -----------------------------------------------------
		'chancery_letter' => [
			'orientation' => 'portrait',
			'previewW' => 850, 'previewH' => 1100,
			'printW' => 2550, 'printH' => 3300,
			'sigCount' => 2,
			'defaults' => ['ribbon'=>false,'dropCap'=>false,'waxSeal'=>true,'swords'=>false,'medallions'=>true,'laurel'=>false,'compass'=>false,'flourishes'=>false],
			'title'     => ['x' => 510,  'y' => 465,  'size' => 120, 'maxWidth' => 1680],
			'recipient' => ['x' => 510,  'y' => 705,  'size' => 114, 'maxWidth' => 1680],
			'body'      => ['x' => 510,  'y' => 1020, 'size' => 57,  'maxWidth' => 1680, 'lineHeight' => 90],
			'sigY' => 2730,
			'heraldry' => null,
		],

		// -----------------------------------------------------
		//  Illuminated Manuscript — drop cap + margin medallions
		// -----------------------------------------------------
		'illuminated_ms' => [
			'orientation' => 'portrait',
			'previewW' => 850, 'previewH' => 1100,
			'printW' => 2550, 'printH' => 3300,
			'sigCount' => 2,
			'defaults' => ['ribbon'=>false,'dropCap'=>true,'waxSeal'=>false,'swords'=>false,'medallions'=>true,'laurel'=>false,'compass'=>false,'flourishes'=>true],
			'title'     => ['x' => 1275, 'y' => 480,  'size' => 156, 'maxWidth' => 2040],
			'recipient' => ['x' => 1275, 'y' => 750,  'size' => 96,  'maxWidth' => 2040],
			'body'      => ['x' => 720,  'y' => 1110, 'size' => 63,  'maxWidth' => 1470, 'lineHeight' => 102],
			'sigY' => 2850,
			'heraldry' => null,
		],

		// -----------------------------------------------------
		//  Battle Standard — LANDSCAPE combat award
		// -----------------------------------------------------
		'battle_standard' => [
			'orientation' => 'landscape',
			'previewW' => 1100, 'previewH' => 850,
			'printW' => 3300, 'printH' => 2550,
			'sigCount' => 2,
			'defaults' => ['ribbon'=>false,'dropCap'=>false,'waxSeal'=>false,'swords'=>true,'medallions'=>false,'laurel'=>false,'compass'=>false,'flourishes'=>false],
			'title'     => ['x' => 1650, 'y' => 510,  'size' => 174, 'maxWidth' => 2640],
			'recipient' => ['x' => 1650, 'y' => 840,  'size' => 120, 'maxWidth' => 2640],
			'body'      => ['x' => 1650, 'y' => 1170, 'size' => 63,  'maxWidth' => 2460, 'lineHeight' => 96],
			'sigY' => 2160,
			'heraldry' => [
				'kingdom' => ['x' => 270,  'y' => 1710, 'w' => 450, 'h' => 450],
				'park'    => ['x' => 2580, 'y' => 1710, 'w' => 450, 'h' => 450],
				'player'  => ['x' => 1425, 'y' => 1710, 'w' => 450, 'h' => 450],
			],
		],

		// -----------------------------------------------------
		//  Guild Charter — ribbon title + dual-column layout
		// -----------------------------------------------------
		'guild_charter' => [
			'orientation' => 'portrait',
			'previewW' => 850, 'previewH' => 1100,
			'printW' => 2550, 'printH' => 3300,
			'sigCount' => 2,
			'defaults' => ['ribbon'=>true,'dropCap'=>false,'waxSeal'=>true,'swords'=>false,'medallions'=>false,'laurel'=>false,'compass'=>false,'flourishes'=>false],
			'title'     => ['x' => 1275, 'y' => 600,  'size' => 132, 'maxWidth' => 2040],
			'recipient' => ['x' => 1275, 'y' => 960,  'size' => 102, 'maxWidth' => 2040],
			'body'      => ['x' => 390,  'y' => 1260, 'size' => 57,  'maxWidth' => 1140, 'lineHeight' => 84],
			'sigY' => 2280,
			'heraldry' => [
				'kingdom' => ['x' => 240,  'y' => 240, 'w' => 285, 'h' => 285],
				'park'    => ['x' => 2025, 'y' => 240, 'w' => 285, 'h' => 285],
				'player'  => ['x' => 1800, 'y' => 1290, 'w' => 540, 'h' => 540],
			],
		],

		// -----------------------------------------------------
		//  Arcane Grimoire — laurel wreath centerpiece
		// -----------------------------------------------------
		'arcane_grimoire' => [
			'orientation' => 'portrait',
			'previewW' => 850, 'previewH' => 1100,
			'printW' => 2550, 'printH' => 3300,
			'sigCount' => 2,
			'defaults' => ['ribbon'=>false,'dropCap'=>false,'waxSeal'=>false,'swords'=>false,'medallions'=>false,'laurel'=>true,'compass'=>true,'flourishes'=>true],
			'title'     => ['x' => 1275, 'y' => 780,  'size' => 132, 'maxWidth' => 1440],
			'recipient' => ['x' => 1275, 'y' => 1260, 'size' => 96,  'maxWidth' => 1980],
			'body'      => ['x' => 1275, 'y' => 1560, 'size' => 60,  'maxWidth' => 1860, 'lineHeight' => 90],
			'sigY' => 2790,
			'heraldry' => [
				'kingdom' => ['x' => 240,  'y' => 300, 'w' => 300, 'h' => 300],
				'park'    => ['x' => 2010, 'y' => 300, 'w' => 300, 'h' => 300],
			],
		],

		// -----------------------------------------------------
		//  Bardic Ballad — script fonts + drop cap
		// -----------------------------------------------------
		'bardic_ballad' => [
			'orientation' => 'portrait',
			'previewW' => 850, 'previewH' => 1100,
			'printW' => 2550, 'printH' => 3300,
			'sigCount' => 2,
			'defaults' => ['ribbon'=>false,'dropCap'=>true,'waxSeal'=>true,'swords'=>false,'medallions'=>false,'laurel'=>false,'compass'=>false,'flourishes'=>true],
			'title'     => ['x' => 1275, 'y' => 480,  'size' => 216, 'maxWidth' => 1860],
			'recipient' => ['x' => 1275, 'y' => 870,  'size' => 144, 'maxWidth' => 1860],
			'body'      => ['x' => 720,  'y' => 1290, 'size' => 60,  'maxWidth' => 1470, 'lineHeight' => 102],
			'sigY' => 2850,
			'heraldry' => [
				'kingdom' => ['x' => 240,  'y' => 240, 'w' => 285, 'h' => 285],
				'park'    => ['x' => 2025, 'y' => 240, 'w' => 285, 'h' => 285],
				'player'  => ['x' => 1065, 'y' => 2280, 'w' => 420, 'h' => 420],
			],
		],
	];

	/**
	 * Color palettes (6 legacy + 6 fantasy presets).
	 */
	private static $PALETTES = [
		'classic'     => ['bg' => [245, 230, 200], 'text' => [45, 27, 0],   'accent' => [139, 105, 20], 'border' => [107, 90, 50]],
		'royal'       => ['bg' => [238, 242, 249], 'text' => [26, 58, 107], 'accent' => [196, 151, 42], 'border' => [26, 58, 107]],
		'nature'      => ['bg' => [240, 230, 208], 'text' => [45, 80, 22],  'accent' => [184, 148, 42], 'border' => [45, 80, 22]],
		'crimson'     => ['bg' => [249, 240, 240], 'text' => [74, 16, 16],  'accent' => [139, 26, 26],  'border' => [107, 46, 46]],
		'obsidian'    => ['bg' => [232, 228, 223], 'text' => [26, 26, 46],  'accent' => [112, 96, 64],  'border' => [61, 61, 80]],
		'white'       => ['bg' => [255, 255, 255], 'text' => [26, 26, 26],  'accent' => [85, 85, 85],   'border' => [153, 153, 153]],
		'burgundy'    => ['bg' => [244, 232, 208], 'text' => [61, 16, 16],  'accent' => [184, 144, 42], 'border' => [92, 30, 30]],
		'forest'      => ['bg' => [238, 230, 200], 'text' => [26, 46, 24],  'accent' => [166, 122, 30], 'border' => [45, 74, 43]],
		'ink'         => ['bg' => [251, 244, 228], 'text' => [43, 24, 16],  'accent' => [139, 105, 20], 'border' => [61, 38, 18]],
		'illuminated' => ['bg' => [246, 235, 208], 'text' => [61, 16, 16],  'accent' => [201, 166, 58], 'border' => [74, 22, 22]],
		'sable'       => ['bg' => [232, 223, 196], 'text' => [26, 18, 8],   'accent' => [196, 151, 42], 'border' => [42, 31, 16]],
		'twilight'    => ['bg' => [228, 223, 235], 'text' => [42, 30, 74],  'accent' => [142, 107, 191], 'border' => [58, 42, 102]],
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

		// ---- Read artwork POST parameters ----
		$artwork_ids = [];
		$artwork_slots = ['full_border','border_left','border_right','border_top','border_bottom','center_image','watermark','top_graphic'];
		foreach ($artwork_slots as $slot) {
			$val = (int)($_POST['artwork_' . $slot] ?? 0);
			if ($val > 0) $artwork_ids[$slot] = $val;
		}

		// ---- Normalize legacy aliases + validate ----
		if (isset(self::$TEMPLATE_ALIASES[$template])) {
			$template = self::$TEMPLATE_ALIASES[$template];
		}
		if (!isset(self::$TEMPLATES[$template])) $template = 'heraldic_shield';
		if (!isset(self::$PALETTES[$palette]))   $palette  = 'classic';

		$tpl = self::$TEMPLATES[$template];
		$pal = self::$PALETTES[$palette];

		// ---- Canvas dimensions from template ----
		$w = $tpl['printW'] ?? self::DEFAULT_W;
		$h = $tpl['printH'] ?? self::DEFAULT_H;

		// ---- Decorative element toggles ----
		$elements = [
			'ribbon'     => ($_POST['el_ribbon']     ?? '0') === '1',
			'dropCap'    => ($_POST['el_dropCap']    ?? '0') === '1',
			'waxSeal'    => ($_POST['el_waxSeal']    ?? '0') === '1',
			'swords'     => ($_POST['el_swords']     ?? '0') === '1',
			'medallions' => ($_POST['el_medallions'] ?? '0') === '1',
			'laurel'     => ($_POST['el_laurel']     ?? '0') === '1',
			'compass'    => ($_POST['el_compass']    ?? '0') === '1',
			'flourishes' => ($_POST['el_flourishes'] ?? '0') === '1',
		];

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

		// ---- Load artwork images ----
		$artworkImages = [];
		if (!empty($artwork_ids)) {
			$sa = Ork3::$Lib->scrollartwork;
			foreach ($artwork_ids as $slot => $aid) {
				$result = $sa->get($aid);
				if (!isset($result['Artwork']) || $result['Artwork']['Status'] !== 'approved') continue;
				$artwork = $result['Artwork'];
				$filePath = DIR_SCROLL_ARTWORK . $artwork['FileName'];
				if (!file_exists($filePath)) continue;
				$artworkImages[$slot] = $filePath;
			}
		}

		// ---- Create image ----
		$img = @imagecreatetruecolor($w, $h);
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
		for ($nx = 0; $nx < $w; $nx += 12) {
			for ($ny = 0; $ny < $h; $ny += 12) {
				if (mt_rand(0, 1)) {
					imagefilledrectangle($img, $nx, $ny, $nx + 5, $ny + 5, $noiseColor);
				}
			}
		}

		// ---- Radial vignette ----
		$vignetteImg = imagecreatetruecolor($w, $h);
		imagefill($vignetteImg, 0, 0, imagecolorallocate($vignetteImg, 0, 0, 0));
		$vigCenterX = (int)($w / 2);
		$vigCenterY = (int)($h / 2);
		$vigRadius = (int)($w * 0.75);
		// Draw a white ellipse in center (will act as transparency mask)
		$vigWhite = imagecolorallocate($vignetteImg, 255, 255, 255);
		imagefilledellipse($vignetteImg, $vigCenterX, $vigCenterY, (int)($w * 0.4), (int)($w * 0.4), $vigWhite);
		// Apply as semi-transparent overlay
		imagecopymerge($img, $vignetteImg, 0, 0, 0, 0, $w, $h, 4); // 4% merge
		imagedestroy($vignetteImg);

		// ---- Artwork: watermark (below drawn border) ----
		if (isset($artworkImages['watermark'])) {
			$dims = ScrollArtwork::SLOT_DIMENSIONS['watermark'];
			$this->compositeArtwork($img, $artworkImages['watermark'], $dims['x'], $dims['y'], $dims['w'], $dims['h'], 10);
		}

		// ---- Draw border (double-line rectangle + corner ornaments) ----
		$this->drawBorder($img, $cBorder, $cAccent, $pal, $template, $borderStyle, $w, $h);

		// ---- Artwork: full_border + edge borders + top_graphic (above drawn border, below heraldry) ----
		if (isset($artworkImages['full_border'])) {
			$dims = ScrollArtwork::SLOT_DIMENSIONS['full_border'];
			$this->compositeArtwork($img, $artworkImages['full_border'], $dims['x'], $dims['y'], $dims['w'], $dims['h'], 100);
		}
		foreach (['border_left', 'border_right', 'border_top', 'border_bottom'] as $edgeSlot) {
			if (isset($artworkImages[$edgeSlot])) {
				$dims = ScrollArtwork::SLOT_DIMENSIONS[$edgeSlot];
				$this->compositeArtwork($img, $artworkImages[$edgeSlot], $dims['x'], $dims['y'], $dims['w'], $dims['h'], 100);
			}
		}
		if (isset($artworkImages['top_graphic'])) {
			$dims = ScrollArtwork::SLOT_DIMENSIONS['top_graphic'];
			$this->compositeArtwork($img, $artworkImages['top_graphic'], $dims['x'], $dims['y'], $dims['w'], $dims['h'], 100);
		}

		// ---- Build state bundle for content rendering ----
		$state = [
			'img' => $img, 'w' => $w, 'h' => $h,
			'template' => $template, 'tpl' => $tpl, 'pal' => $pal,
			'elements' => $elements,
			'fontFiles' => $fontFiles, 'useBuiltin' => $useBuiltinFont, 'bodyFontFile' => $bodyFontFile,
			'recipient' => $recipient, 'awardName' => $awardName, 'rank' => $rank, 'date' => $date,
			'givenBy' => $givenBy, 'park' => $park, 'kingdom' => $kingdom,
			'bodyText' => strlen($bodyText) ? $bodyText : $this->generateBodyText($recipient, $awardName, $rank, $date, $kingdom, $template, $park),
			'sigs' => [
				['name' => $sig1_name, 'role' => $sig1_role],
				['name' => $sig2_name, 'role' => $sig2_role],
				['name' => $sig3_name, 'role' => $sig3_role],
			],
			'sig2_visible' => $sig2_visible,
			'heraldry' => [
				'kingdom' => $heraldry_kingdom,
				'park'    => $heraldry_park,
				'player'  => $heraldry_player,
			],
			'artworkImages' => $artworkImages,
			'cBg' => $cBg, 'cText' => $cText, 'cAccent' => $cAccent, 'cBorder' => $cBorder,
		];

		// ---- Dispatch to template-specific content renderer ----
		$method = 'render_' . $template;
		if (method_exists($this, $method)) {
			$this->{$method}($state);
		} else {
			$this->renderContentDefault($state);
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
	 * Composite an artwork PNG onto the scroll canvas at the given position/size/opacity.
	 *
	 * @param resource $img        Destination GD image (the scroll canvas)
	 * @param string   $artworkPath  Absolute path to the artwork PNG file
	 * @param int      $x           X position on canvas
	 * @param int      $y           Y position on canvas
	 * @param int      $w           Target width on canvas
	 * @param int      $h           Target height on canvas
	 * @param int      $opacity     Opacity 0-100 (100 = fully opaque)
	 */
	private function compositeArtwork($img, $artworkPath, $x, $y, $w, $h, $opacity) {
		$src = @imagecreatefrompng($artworkPath);
		if (!$src) return;

		imagesavealpha($src, true);
		imagealphablending($src, true);

		// Create a resampled version at target dimensions
		$resized = imagecreatetruecolor($w, $h);
		imagealphablending($resized, false);
		imagesavealpha($resized, true);
		$transparent = imagecolorallocatealpha($resized, 0, 0, 0, 127);
		imagefill($resized, 0, 0, $transparent);
		imagealphablending($resized, true);

		imagecopyresampled(
			$resized, $src,
			0, 0,
			0, 0,
			$w, $h,
			imagesx($src), imagesy($src)
		);
		imagedestroy($src);

		// Composite onto canvas
		imagealphablending($img, true);
		if ($opacity >= 100) {
			imagecopy($img, $resized, $x, $y, 0, 0, $w, $h);
		} else {
			// imagecopymerge() destroys source alpha channel at partial opacity.
			// Instead, pre-multiply the source alpha by the desired opacity so that
			// transparent pixels in the artwork stay transparent.
			$opacityFactor = $opacity / 100.0;
			for ($py = 0; $py < $h; $py++) {
				for ($px = 0; $px < $w; $px++) {
					$rgba = imagecolorat($resized, $px, $py);
					$a = ($rgba >> 24) & 0x7F; // 0=opaque, 127=transparent
					// Scale the opaque portion by opacity factor
					$newAlpha = (int)(127 - (127 - $a) * $opacityFactor);
					$newAlpha = max(0, min(127, $newAlpha));
					$r = ($rgba >> 16) & 0xFF;
					$g = ($rgba >> 8) & 0xFF;
					$b = $rgba & 0xFF;
					$newColor = imagecolorallocatealpha($resized, $r, $g, $b, $newAlpha);
					imagesetpixel($resized, $px, $py, $newColor);
				}
			}
			imagealphablending($img, true);
			imagecopy($img, $resized, $x, $y, 0, 0, $w, $h);
		}
		imagedestroy($resized);
	}

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
	private function drawBorder($img, $cBorder, $cAccent, $pal, $template, $borderStyle, $w, $h) {
		$s = self::SCALE;

		if ($borderStyle === 'none') return;

		switch ($borderStyle) {
			case 'ornate':
				$this->drawBorderOrnate($img, $cBorder, $cAccent, $pal, $w, $h);
				break;
			case 'celtic':
				$this->drawBorderCeltic($img, $cBorder, $cAccent, $pal, $w, $h);
				break;
			case 'simple':
				$this->drawBorderSimple($img, $cBorder, $w, $h);
				break;
			case 'royal':
				$this->drawBorderRoyal($img, $cBorder, $cAccent, $pal, $w, $h);
				break;
			case 'rustic':
				$this->drawBorderRustic($img, $cBorder, $pal, $w, $h);
				break;
			case 'filigree':
				$this->drawBorderFiligree($img, $cBorder, $cAccent, $pal, $w, $h);
				break;
			case 'classic':
			default:
				$this->drawBorderClassic($img, $cBorder, $cAccent, $pal, $w, $h);
				break;
		}
	}

	private function drawBorderClassic($img, $cBorder, $cAccent, $pal, $w, $h) {
		$s = self::SCALE;
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

	private function drawBorderOrnate($img, $cBorder, $cAccent, $pal, $w, $h) {
		$s = self::SCALE;
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

	private function drawBorderCeltic($img, $cBorder, $cAccent, $pal, $w, $h) {
		$s = self::SCALE;
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

	private function drawBorderSimple($img, $cBorder, $w, $h) {
		$s = self::SCALE;
		imagesetthickness($img, (int)(2*$s));
		$o = (int)(32*$s);
		imagerectangle($img, $o, $o, $w-$o-1, $h-$o-1, $cBorder);
		imagesetthickness($img, 1);
	}

	private function drawBorderRoyal($img, $cBorder, $cAccent, $pal, $w, $h) {
		$s = self::SCALE;
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

	private function drawBorderRustic($img, $cBorder, $pal, $w, $h) {
		$s = self::SCALE;
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

	private function drawBorderFiligree($img, $cBorder, $cAccent, $pal, $w, $h) {
		$s = self::SCALE;
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

		// Normalize template alias
		if (isset(self::$TEMPLATE_ALIASES[$template])) $template = self::$TEMPLATE_ALIASES[$template];

		if ($template === 'royal_decree') {
			$text = 'To all and singular who shall see these presents, greetings. Be it known that by the right and authority vested in the Crown of ' . $kingdomRef . ', and in recognition of valor, honor, and service, We do hereby elevate ' . $persona . ' to the ' . $award . '.';
			if ($day && $monthName) {
				$text .= ' Given under Our hand this ' . $day . $suffix . ' day of ' . $monthName . ', in the year ' . $year;
				if (strlen($park)) $text .= ', at ' . $park;
				if (strlen($kingdom)) $text .= ', in the Kingdom of ' . $kingdom;
				$text .= '.';
			}
		} elseif ($template === 'chancery_letter') {
			$text = 'Be it proclaimed that ' . $persona . ' is hereby recognized and granted the title of ' . $award . ', with all rights, privileges, and responsibilities thereto pertaining, by the authority of the Crown of ' . $kingdomRef . '.';
			if ($day && $monthName) {
				$text .= ' Given this ' . $day . $suffix . ' day of ' . $monthName . ', ' . $year . '.';
			}
		} elseif ($template === 'illuminated_ms') {
			$text = 'Herein is set down, by ancient custom and with due reverence, that ' . $persona . ' has attained such mastery as to warrant the ' . $award . '. May this illumination stand as enduring testament to the skill and dedication that have brought forth this honor.';
			if ($day && $monthName) $text .= ' Inscribed this ' . $day . $suffix . ' day of ' . $monthName . ', ' . $year . '.';
		} elseif ($template === 'battle_standard') {
			$text = 'On the field of glory, ' . $persona . ' hath proven valor without question. By right of arms, and witnessed by comrades and foes alike, the ' . $award . ' is hereby conferred, that all who see this standard may know the measure of this warrior.';
			if ($day && $monthName) $text .= ' Declared upon the ' . $day . $suffix . ' day of ' . $monthName . ', ' . $year . '.';
		} elseif ($template === 'guild_charter') {
			$text = 'By the charter of this guild, and upon vote of its membership, ' . $persona . ' is hereby granted the ' . $award . ', with all rights and duties pertaining thereto. Let this record stand within the annals of our guild, a mark of service freely given and gratefully received.';
			if ($day && $monthName) $text .= ' Sealed the ' . $day . $suffix . ' day of ' . $monthName . ', ' . $year . '.';
		} elseif ($template === 'arcane_grimoire') {
			$text = 'Between the veils of mundane and mystery, ' . $persona . ' has walked with purpose, and has earned by study, by craft, and by right the ' . $award . '. May the light of this honor guide future steps, and may the laurel bind this moment to the long memory of the realm.';
			if ($day && $monthName) $text .= ' Conjured upon the ' . $day . $suffix . ' day of ' . $monthName . ', in the year of our reckoning ' . $year . '.';
		} elseif ($template === 'bardic_ballad') {
			$text = 'Let every hall and every hearth hear tell of ' . $persona . ', whose art has warmed our nights and whose voice has given shape to our joys and sorrows alike. In recognition of such grace, the ' . $award . ' is bestowed, that music and remembrance may ever follow.';
			if ($day && $monthName) $text .= ' Sung into record this ' . $day . $suffix . ' day of ' . $monthName . ', ' . $year . '.';
		} else {
			// Default: Order / Award (heraldic_shield)
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
	// ================================================================
	//  v2: Content helpers (mirror JS)
	// ================================================================

	private function scl($n) { return (int)round($n * self::SCALE); }

	private function computeSealInitials($kingdom) {
		$skip = ['the', 'kingdom', 'of'];
		$words = preg_split('/\s+/', $kingdom ?? '');
		$out = '';
		foreach ($words as $w) {
			if ($w !== '' && !in_array(mb_strtolower($w), $skip)) {
				$out .= mb_strtoupper(mb_substr($w, 0, 1));
			}
		}
		return $out;
	}

	private function rgba($img, $rgb, $alpha = 0) {
		return imagecolorallocatealpha($img, $rgb[0], $rgb[1], $rgb[2], $alpha);
	}

	// Parse "#rrggbb" hex string → [r,g,b]
	private function hex2rgb($hex) {
		$h = ltrim($hex ?? '', '#');
		if (strlen($h) !== 6) return [0, 0, 0];
		return [hexdec(substr($h, 0, 2)), hexdec(substr($h, 2, 2)), hexdec(substr($h, 4, 2))];
	}

	private function lighten($rgb, $amt) {
		return [
			(int)min(255, $rgb[0] + (255 - $rgb[0]) * $amt),
			(int)min(255, $rgb[1] + (255 - $rgb[1]) * $amt),
			(int)min(255, $rgb[2] + (255 - $rgb[2]) * $amt),
		];
	}

	private function darken($rgb, $amt) {
		return [
			(int)max(0, $rgb[0] * (1 - $amt)),
			(int)max(0, $rgb[1] * (1 - $amt)),
			(int)max(0, $rgb[2] * (1 - $amt)),
		];
	}

	private function mixRgb($a, $b, $amt) {
		return [
			(int)round($a[0] * (1 - $amt) + $b[0] * $amt),
			(int)round($a[1] * (1 - $amt) + $b[1] * $amt),
			(int)round($a[2] * (1 - $amt) + $b[2] * $amt),
		];
	}

	// --- Heraldry from spec block ---
	private function drawHeraldryFromSpec($state, $spec) {
		if (!$spec) return;
		if (!empty($spec['kingdom'])) $this->drawHeraldryImage($state['img'], $state['heraldry']['kingdom'], $spec['kingdom']);
		if (!empty($spec['park']))    $this->drawHeraldryImage($state['img'], $state['heraldry']['park'],    $spec['park']);
		if (!empty($spec['player']))  $this->drawHeraldryImage($state['img'], $state['heraldry']['player'],  $spec['player']);
	}

	// --- Title centered ---
	private function drawTitleCenter($state, $spec) {
		$text = strlen($state['awardName']) ? $state['awardName'] : 'Award Title';
		$this->drawCenteredText($state['img'], $text, $spec, $state['cAccent'], $state['fontFiles']['title'], $state['useBuiltin']);
	}

	// --- Title left-aligned ---
	private function drawTitleLeft($state, $spec) {
		$text = strlen($state['awardName']) ? $state['awardName'] : 'Award Title';
		$fontFile = $state['fontFiles']['title'];
		if ($state['useBuiltin'] || !$fontFile) {
			imagestring($state['img'], 5, $spec['x'], $spec['y'], $text, $state['cAccent']);
			return;
		}
		$size = $this->fitFontSize($fontFile, $text, $spec['size'], $spec['maxWidth']);
		imagettftext($state['img'], $size, 0, $spec['x'], $spec['y'] + $size, $state['cAccent'], $fontFile, $text);
	}

	// --- Recipient centered ---
	private function drawRecipientCenter($state, $spec) {
		$text = strlen($state['recipient']) ? $state['recipient'] : 'Recipient Name';
		$this->drawCenteredText($state['img'], $text, $spec, $state['cText'], $state['fontFiles']['recipient'], $state['useBuiltin']);
	}

	// --- Recipient left-aligned ---
	private function drawRecipientLeft($state, $spec) {
		$text = strlen($state['recipient']) ? $state['recipient'] : 'Recipient Name';
		$fontFile = $state['fontFiles']['recipient'];
		if ($state['useBuiltin'] || !$fontFile) {
			imagestring($state['img'], 5, $spec['x'], $spec['y'], $text, $state['cText']);
			return;
		}
		$size = $this->fitFontSize($fontFile, $text, $spec['size'], $spec['maxWidth']);
		imagettftext($state['img'], $size, 0, $spec['x'], $spec['y'] + $size, $state['cText'], $fontFile, $text);
	}

	// --- Body centered ---
	private function drawBodyCenter($state, $spec) {
		$this->drawWrappedText($state['img'], $state['bodyText'], $spec, $state['cText'], $state['fontFiles']['body'], $state['useBuiltin']);
	}

	// --- Body left-aligned (word wrap) ---
	private function drawBodyLeft($state, $spec, $overrideText = null) {
		$text = $overrideText ?? $state['bodyText'];
		$fontFile = $state['fontFiles']['body'];
		if ($state['useBuiltin'] || !$fontFile) {
			// Fallback: use built-in wrap
			$lines = $this->wordWrapString($text, (int)($spec['maxWidth'] / 9));
			$y = $spec['y'];
			foreach ($lines as $line) {
				imagestring($state['img'], 5, $spec['x'], $y, $line, $state['cText']);
				$y += 20;
			}
			return;
		}
		$words = explode(' ', $text);
		$line = '';
		$lines = [];
		foreach ($words as $word) {
			$test = $line . (strlen($line) ? ' ' : '') . $word;
			$box = imagettfbbox($spec['size'], 0, $fontFile, $test);
			$w = $box[2] - $box[0];
			if ($w > $spec['maxWidth'] && strlen($line)) {
				$lines[] = $line;
				$line = $word;
			} else {
				$line = $test;
			}
		}
		if (strlen($line)) $lines[] = $line;
		$y = $spec['y'] + $spec['size'];
		foreach ($lines as $ln) {
			imagettftext($state['img'], $spec['size'], 0, $spec['x'], $y, $state['cText'], $fontFile, $ln);
			$y += $spec['lineHeight'];
		}
	}

	// --- Body left-aligned with first-line indent (for drop cap) ---
	private function drawBodyLeftWithIndent($state, $spec, $indent, $text) {
		$fontFile = $state['fontFiles']['body'];
		if ($state['useBuiltin'] || !$fontFile) {
			$this->drawBodyLeft($state, $spec, $text);
			return;
		}
		$words = explode(' ', $text);
		$line = '';
		$lines = [];
		$isFirst = true;
		foreach ($words as $word) {
			$test = $line . (strlen($line) ? ' ' : '') . $word;
			$box = imagettfbbox($spec['size'], 0, $fontFile, $test);
			$w = $box[2] - $box[0];
			$cap = $isFirst ? ($spec['maxWidth'] - $indent) : $spec['maxWidth'];
			if ($w > $cap && strlen($line)) {
				$lines[] = $line;
				$line = $word;
				$isFirst = false;
			} else {
				$line = $test;
			}
		}
		if (strlen($line)) $lines[] = $line;
		$y = $spec['y'] + $spec['size'];
		foreach ($lines as $idx => $ln) {
			$x = $spec['x'] + ($idx === 0 ? $indent : 0);
			imagettftext($state['img'], $spec['size'], 0, $x, $y, $state['cText'], $fontFile, $ln);
			$y += $spec['lineHeight'];
		}
	}

	// --- Date / location line ---
	private function drawDateLine($state, $y) {
		$parts = [];
		$line = '';
		if (strlen($state['park']) || strlen($state['kingdom'])) {
			$line = 'Given at';
			if (strlen($state['park'])) $line .= ' ' . $state['park'];
			if (strlen($state['kingdom'])) $line .= (strlen($state['park']) ? ', ' : ' ') . $state['kingdom'];
		}
		if (!strlen($line)) return;
		$size = $this->scl(16);
		$color = imagecolorallocatealpha($state['img'], $state['pal']['text'][0], $state['pal']['text'][1], $state['pal']['text'][2], 51);
		$fontFile = $state['fontFiles']['body'];
		if ($state['useBuiltin'] || !$fontFile) {
			$this->drawBuiltinCentered($state['img'], $line, (int)($state['w'] / 2), $y, $color);
			return;
		}
		$box = imagettfbbox($size, 0, $fontFile, $line);
		$tw = $box[2] - $box[0];
		imagettftext($state['img'], $size, 0, (int)($state['w'] / 2) - (int)($tw / 2), $y + $size, $color, $fontFile, $line);
	}

	// --- Seal element (centered circle with initials) ---
	private function drawSealElement($state, $cx, $cy, $r) {
		$img = $state['img'];
		$pal = $state['pal'];
		$outer = imagecolorallocatealpha($img, $pal['accent'][0], $pal['accent'][1], $pal['accent'][2], 51);
		$inner = imagecolorallocatealpha($img, $pal['accent'][0], $pal['accent'][1], $pal['accent'][2], 76);
		$tick  = imagecolorallocatealpha($img, $pal['accent'][0], $pal['accent'][1], $pal['accent'][2], 64);
		imagesetthickness($img, $this->scl(2));
		imageellipse($img, $cx, $cy, $r * 2, $r * 2, $outer);
		imagesetthickness($img, $this->scl(1));
		imageellipse($img, $cx, $cy, (int)($r * 1.52), (int)($r * 1.52), $inner);
		for ($i = 0; $i < 12; $i++) {
			$ang = ($i / 12.0) * 2.0 * M_PI;
			imageline($img,
				(int)($cx + cos($ang) * $r), (int)($cy + sin($ang) * $r),
				(int)($cx + cos($ang) * $r * 1.16), (int)($cy + sin($ang) * $r * 1.16),
				$tick
			);
		}
		$initials = $this->computeSealInitials($state['kingdom']);
		if ($initials && !$state['useBuiltin']) {
			$font = $state['fontFiles']['body'] ?: $state['bodyFontFile'];
			$letter = imagecolorallocatealpha($img, $pal['accent'][0], $pal['accent'][1], $pal['accent'][2], 95);
			$sz = mb_strlen($initials) > 2 ? (int)($r * 0.56) : (int)($r * 0.72);
			$box = imagettfbbox($sz, 0, $font, $initials);
			$tw = $box[2] - $box[0];
			$th = $box[1] - $box[5];
			imagettftext($img, $sz, 0, $cx - (int)($tw / 2), $cy + (int)($th / 2), $letter, $font, $initials);
		}
		imagesetthickness($img, 1);
	}

	// --- Signature bar (horizontal) ---
	private function drawSignatureBar($state, $y, $sigCountMax) {
		$img = $state['img'];
		$pal = $state['pal'];
		$active = [0];
		if ($state['sig2_visible']) $active[] = 1;
		if ($sigCountMax >= 3) $active[] = 2;
		$n = count($active);
		$spacing = (int)($state['w'] / ($n + 1));
		$lineW = $this->scl(180);
		$lineY = $y + $this->scl(30);
		$lineC = imagecolorallocatealpha($img, $pal['text'][0], $pal['text'][1], $pal['text'][2], 51);
		$textC = imagecolorallocatealpha($img, $pal['text'][0], $pal['text'][1], $pal['text'][2], 0);
		$roleC = imagecolorallocatealpha($img, $pal['text'][0], $pal['text'][1], $pal['text'][2], 45);
		imagesetthickness($img, $this->scl(1));
		$fontSig = $state['fontFiles']['signatures'] ?: $state['bodyFontFile'];
		foreach ($active as $ai => $si) {
			$sigX = $spacing * ($ai + 1);
			imageline($img, $sigX - (int)($lineW / 2), $lineY, $sigX + (int)($lineW / 2), $lineY, $lineC);
			$tickH = $this->scl(3);
			imageline($img, $sigX - (int)($lineW / 2), $lineY - $tickH, $sigX - (int)($lineW / 2), $lineY + $tickH, $lineC);
			imageline($img, $sigX + (int)($lineW / 2), $lineY - $tickH, $sigX + (int)($lineW / 2), $lineY + $tickH, $lineC);
			$sig = $state['sigs'][$si] ?? ['name' => '', 'role' => ''];
			if ($sig['name'] && !$state['useBuiltin']) {
				$sz = $this->scl(18);
				$box = imagettfbbox($sz, 0, $fontSig, $sig['name']);
				$tw = $box[2] - $box[0];
				imagettftext($img, $sz, 0, $sigX - (int)($tw / 2), $y + $this->scl(8) + $sz, $textC, $fontSig, $sig['name']);
			}
			if ($sig['role'] && !$state['useBuiltin']) {
				$sz = $this->scl(14);
				$box = imagettfbbox($sz, 0, $fontSig, $sig['role']);
				$tw = $box[2] - $box[0];
				imagettftext($img, $sz, 0, $sigX - (int)($tw / 2), $y + $this->scl(48) + $sz, $roleC, $fontSig, $sig['role']);
			}
		}
		imagesetthickness($img, 1);
	}

	// --- Signature stack (vertical) ---
	private function drawSignatureStack($state, $x, $y, $sigCountMax, $align) {
		$img = $state['img'];
		$pal = $state['pal'];
		$active = [0];
		if ($state['sig2_visible']) $active[] = 1;
		if ($sigCountMax >= 3) $active[] = 2;
		$rowH = $this->scl(70);
		$lineW = $this->scl(180);
		$lineC = imagecolorallocatealpha($img, $pal['text'][0], $pal['text'][1], $pal['text'][2], 51);
		$textC = imagecolorallocatealpha($img, $pal['text'][0], $pal['text'][1], $pal['text'][2], 0);
		$roleC = imagecolorallocatealpha($img, $pal['text'][0], $pal['text'][1], $pal['text'][2], 45);
		imagesetthickness($img, $this->scl(1));
		$fontSig = $state['fontFiles']['signatures'] ?: $state['bodyFontFile'];
		foreach ($active as $i => $si) {
			$yy = $y + $i * $rowH;
			if ($align === 'right') { $x1 = $x - $lineW; $x2 = $x; $tx = $x; }
			elseif ($align === 'left') { $x1 = $x; $x2 = $x + $lineW; $tx = $x; }
			else { $x1 = $x - (int)($lineW / 2); $x2 = $x + (int)($lineW / 2); $tx = $x; }
			imageline($img, $x1, $yy + $this->scl(30), $x2, $yy + $this->scl(30), $lineC);
			$tickH = $this->scl(3);
			imageline($img, $x1, $yy + $this->scl(30) - $tickH, $x1, $yy + $this->scl(30) + $tickH, $lineC);
			imageline($img, $x2, $yy + $this->scl(30) - $tickH, $x2, $yy + $this->scl(30) + $tickH, $lineC);
			$sig = $state['sigs'][$si] ?? ['name' => '', 'role' => ''];
			if ($sig['name'] && !$state['useBuiltin']) {
				$sz = $this->scl(18);
				$box = imagettfbbox($sz, 0, $fontSig, $sig['name']);
				$tw = $box[2] - $box[0];
				$nx = $align === 'right' ? $tx - $tw : ($align === 'left' ? $tx : $tx - (int)($tw / 2));
				imagettftext($img, $sz, 0, $nx, $yy + $this->scl(8) + $sz, $textC, $fontSig, $sig['name']);
			}
			if ($sig['role'] && !$state['useBuiltin']) {
				$sz = $this->scl(14);
				$box = imagettfbbox($sz, 0, $fontSig, $sig['role']);
				$tw = $box[2] - $box[0];
				$rx = $align === 'right' ? $tx - $tw : ($align === 'left' ? $tx : $tx - (int)($tw / 2));
				imagettftext($img, $sz, 0, $rx, $yy + $this->scl(40) + $sz, $roleC, $fontSig, $sig['role']);
			}
		}
		imagesetthickness($img, 1);
	}

	// --- Center image artwork slot helper ---
	private function drawCenterImageSlot($state) {
		if (isset($state['artworkImages']['center_image'])) {
			$dims = ScrollArtwork::SLOT_DIMENSIONS['center_image'];
			$this->compositeArtwork($state['img'], $state['artworkImages']['center_image'], $dims['x'], $dims['y'], $dims['w'], $dims['h'], 15);
		}
	}

	// ================================================================
	//  v2: Decorative primitives
	// ================================================================

	// --- Ribbon banner ---
	private function drawRibbonBanner($state, $cx, $cy, $width, $height, $text, $fontFile, $textSize) {
		$img = $state['img'];
		$pal = $state['pal'];
		$x = $cx - (int)($width / 2);
		$y = $cy - (int)($height / 2);
		$notch = (int)($height * 0.4);
		$accent = $pal['accent'];
		$border = $pal['border'];
		$light = $this->lighten($accent, 0.25);
		$dark  = $this->darken($accent, 0.35);
		$fill = $this->rgba($img, $light);
		$darkFill = $this->rgba($img, $dark);
		$stroke = $this->rgba($img, $border);
		// Main body polygon
		$pts = [
			$x + $notch, $y,
			$x + $width - $notch, $y,
			$x + $width, $y + (int)($height / 2),
			$x + $width - $notch, $y + $height,
			$x + $notch, $y + $height,
			$x, $y + (int)($height / 2),
		];
		imagefilledpolygon($img, $pts, $fill);
		imagesetthickness($img, $this->scl(2));
		imagepolygon($img, $pts, $stroke);
		// Left fold tail
		$ptsL = [
			$x, $y + (int)($height / 2),
			$x - (int)($notch * 0.6), $y + (int)($height / 2) - (int)($notch * 0.35),
			$x - (int)($notch * 0.6), $y + (int)($height / 2) + (int)($notch * 0.35),
		];
		imagefilledpolygon($img, $ptsL, $darkFill);
		imagepolygon($img, $ptsL, $stroke);
		// Right fold tail
		$ptsR = [
			$x + $width, $y + (int)($height / 2),
			$x + $width + (int)($notch * 0.6), $y + (int)($height / 2) - (int)($notch * 0.35),
			$x + $width + (int)($notch * 0.6), $y + (int)($height / 2) + (int)($notch * 0.35),
		];
		imagefilledpolygon($img, $ptsR, $darkFill);
		imagepolygon($img, $ptsR, $stroke);
		imagesetthickness($img, 1);
		// Text (cream-colored) centered inside
		if ($text && !$state['useBuiltin'] && $fontFile) {
			$textColor = $this->rgba($img, $pal['bg']);
			$sz = $textSize;
			$box = imagettfbbox($sz, 0, $fontFile, $text);
			$tw = $box[2] - $box[0];
			$maxTextW = $width - $notch * 2 - $this->scl(20);
			while ($tw > $maxTextW && $sz > $this->scl(16)) {
				$sz -= $this->scl(2);
				$box = imagettfbbox($sz, 0, $fontFile, $text);
				$tw = $box[2] - $box[0];
			}
			$th = $box[1] - $box[5];
			imagettftext($img, $sz, 0, $cx - (int)($tw / 2), $cy + (int)($th / 2), $textColor, $fontFile, $text);
		}
	}

	// --- Drop cap ---
	private function drawDropCap($state, $letter, $x, $y, $size, $fontFile) {
		$img = $state['img'];
		$pal = $state['pal'];
		if (!$letter) return;
		$bg = $this->rgba($img, $this->lighten($pal['accent'], 0.7));
		$accent = $this->rgba($img, $pal['accent']);
		imagefilledrectangle($img, $x, $y, $x + $size, $y + $size, $bg);
		imagesetthickness($img, $this->scl(2));
		imagerectangle($img, $x, $y, $x + $size, $y + $size, $accent);
		// Inner gold rule
		$inner = imagecolorallocatealpha($img, $pal['accent'][0], $pal['accent'][1], $pal['accent'][2], 64);
		imagesetthickness($img, $this->scl(1));
		imagerectangle($img, $x + $this->scl(4), $y + $this->scl(4), $x + $size - $this->scl(4), $y + $size - $this->scl(4), $inner);
		// Corner dots
		$dot = $this->scl(3);
		imagefilledellipse($img, $x + $this->scl(6), $y + $this->scl(6), $dot * 2, $dot * 2, $accent);
		imagefilledellipse($img, $x + $size - $this->scl(6), $y + $this->scl(6), $dot * 2, $dot * 2, $accent);
		imagefilledellipse($img, $x + $this->scl(6), $y + $size - $this->scl(6), $dot * 2, $dot * 2, $accent);
		imagefilledellipse($img, $x + $size - $this->scl(6), $y + $size - $this->scl(6), $dot * 2, $dot * 2, $accent);
		// Letter
		if (!$state['useBuiltin'] && $fontFile) {
			$fs = (int)($size * 0.78);
			$box = imagettfbbox($fs, 0, $fontFile, $letter);
			$tw = $box[2] - $box[0];
			$th = $box[1] - $box[5];
			imagettftext($img, $fs, 0, $x + (int)(($size - $tw) / 2), $y + (int)(($size + $th) / 2), $accent, $fontFile, $letter);
		}
		imagesetthickness($img, 1);
	}

	// --- Quartered shield (simplified: big shield shape containing player heraldry) ---
	private function drawQuarteredShield($state, $cx, $cy, $size) {
		$img = $state['img'];
		$pal = $state['pal'];
		$halfW = (int)($size * 0.55);
		$topY = $cy - (int)($size * 0.55);
		$ptY = $cy + (int)($size * 0.75);
		// Shield polygon (approximated — true path with quadratic curves not available in GD)
		$pts = [
			$cx - $halfW, $topY,
			$cx + $halfW, $topY,
			$cx + $halfW, $cy + (int)($size * 0.1),
			$cx + (int)($halfW * 0.6), $cy + (int)($size * 0.3),
			$cx, $ptY,
			$cx - (int)($halfW * 0.6), $cy + (int)($size * 0.3),
			$cx - $halfW, $cy + (int)($size * 0.1),
		];
		$bgRgb = $this->lighten($pal['bg'], 0.15);
		$bgC = $this->rgba($img, $bgRgb);
		imagefilledpolygon($img, $pts, $bgC);
		// Clip + draw player heraldry (GD has no clip, so we draw heraldry in shield bounds)
		if (strlen($state['heraldry']['player'])) {
			$imgW = $halfW * 2;
			$imgH = $ptY - $topY;
			// Heraldry goes within the shield bounds (rough approximation; no true clip)
			$pos = ['x' => $cx - $halfW, 'y' => $topY, 'w' => $imgW, 'h' => $imgH];
			$this->drawHeraldryImage($img, $state['heraldry']['player'], $pos);
		}
		// Shield border (gold stroke)
		imagesetthickness($img, $this->scl(3));
		$strokeC = $this->rgba($img, $pal['accent']);
		imagepolygon($img, $pts, $strokeC);
		// Mini kingdom shield top-left
		if (strlen($state['heraldry']['kingdom'])) {
			$mini = (int)($size * 0.3);
			$mx = $cx - $halfW + (int)($mini * 0.1);
			$my = $topY - (int)($mini * 0.2);
			$this->drawMiniShield($state, $mx, $my, $mini, $state['heraldry']['kingdom']);
		}
		// Mini park shield top-right
		if (strlen($state['heraldry']['park'])) {
			$mini = (int)($size * 0.3);
			$mx = $cx + $halfW - (int)($mini * 1.1);
			$my = $topY - (int)($mini * 0.2);
			$this->drawMiniShield($state, $mx, $my, $mini, $state['heraldry']['park']);
		}
		imagesetthickness($img, 1);
	}

	private function drawMiniShield($state, $x, $y, $size, $url) {
		$img = $state['img'];
		$pal = $state['pal'];
		$halfW = (int)($size / 2);
		$pts = [
			$x, $y,
			$x + $size, $y,
			$x + $size, $y + (int)($size * 0.55),
			$x + $halfW + (int)($halfW * 0.5), $y + (int)($size * 0.85),
			$x + $halfW, $y + $size,
			$x + $halfW - (int)($halfW * 0.5), $y + (int)($size * 0.85),
			$x, $y + (int)($size * 0.55),
		];
		$bgC = $this->rgba($img, $this->lighten($pal['bg'], 0.1));
		imagefilledpolygon($img, $pts, $bgC);
		$this->drawHeraldryImage($img, $url, ['x' => $x, 'y' => $y, 'w' => $size, 'h' => $size]);
		imagesetthickness($img, $this->scl(2));
		imagepolygon($img, $pts, $this->rgba($img, $pal['accent']));
		imagesetthickness($img, 1);
	}

	// --- Wax seal (3D burgundy disc) ---
	private function drawWaxSealLarge($state, $cx, $cy, $r) {
		$img = $state['img'];
		$pal = $state['pal'];
		$wax = $this->mixRgb($pal['accent'], [92, 30, 30], 0.6);
		$waxHi = $this->lighten($wax, 0.4);
		$waxLo = $this->darken($wax, 0.45);
		// Drop shadow (offset darker disc)
		$shadow = imagecolorallocatealpha($img, 0, 0, 0, 70);
		imagefilledellipse($img, $cx + $this->scl(2), $cy + $this->scl(4), $r * 2, $r * 2, $shadow);
		// Outer disc (base wax color)
		imagefilledellipse($img, $cx, $cy, $r * 2, $r * 2, $this->rgba($img, $wax));
		// Highlight arc (lighter upper-left)
		imagefilledellipse($img, $cx - (int)($r * 0.25), $cy - (int)($r * 0.3), (int)($r * 1.4), (int)($r * 1.1), imagecolorallocatealpha($img, $waxHi[0], $waxHi[1], $waxHi[2], 70));
		// Pressed rim
		imagesetthickness($img, $this->scl(2));
		imageellipse($img, $cx, $cy, (int)($r * 1.84), (int)($r * 1.84), $this->rgba($img, $waxLo));
		// Radial ticks
		imagesetthickness($img, $this->scl(1));
		$tickC = imagecolorallocatealpha($img, $waxHi[0], $waxHi[1], $waxHi[2], 80);
		for ($i = 0; $i < 16; $i++) {
			$ang = ($i / 16.0) * 2.0 * M_PI;
			imageline($img,
				(int)($cx + cos($ang) * $r * 0.85), (int)($cy + sin($ang) * $r * 0.85),
				(int)($cx + cos($ang) * $r * 0.95), (int)($cy + sin($ang) * $r * 0.95),
				$tickC
			);
		}
		// Initials stamped
		$initials = $this->computeSealInitials($state['kingdom']);
		if ($initials && !$state['useBuiltin']) {
			$font = $state['fontFiles']['body'] ?: $state['bodyFontFile'];
			$sz = mb_strlen($initials) > 2 ? (int)($r * 0.56) : (int)($r * 0.78);
			$box = imagettfbbox($sz, 0, $font, $initials);
			$tw = $box[2] - $box[0];
			$th = $box[1] - $box[5];
			// Emboss: dark shadow underneath
			imagettftext($img, $sz, 0, $cx - (int)($tw / 2) + 2, $cy + (int)($th / 2) + 2, $this->rgba($img, $waxLo, 20), $font, $initials);
			imagettftext($img, $sz, 0, $cx - (int)($tw / 2), $cy + (int)($th / 2), $this->rgba($img, $waxHi, 30), $font, $initials);
		}
		imagesetthickness($img, 1);
	}

	// --- Crossed swords ---
	private function drawCrossedSwords($state, $cx, $cy, $size) {
		$img = $state['img'];
		$pal = $state['pal'];
		// Draw 2 swords: 45° clockwise and counter-clockwise
		// For simplicity, use polygons for blade + rect for crossbar + circle for pommel.
		$bladeSilver = imagecolorallocate($img, 200, 200, 205);
		$bladeDark   = imagecolorallocate($img, 120, 120, 128);
		$guardC      = $this->rgba($img, $pal['accent']);
		$pommelC     = $this->rgba($img, $this->lighten($pal['accent'], 0.2));
		$guardStroke = $this->rgba($img, $this->darken($pal['accent'], 0.4));
		$gripC       = imagecolorallocate($img, 74, 40, 24);
		for ($s = 0; $s < 2; $s++) {
			$sign = $s === 0 ? -1 : 1;
			$ang = $sign * M_PI / 4;
			$cosA = cos($ang); $sinA = sin($ang);
			// Transform (0,0)-relative points to (cx,cy)
			$tx = function($x, $y) use ($cx, $cy, $cosA, $sinA) {
				return [(int)($cx + $x * $cosA - $y * $sinA), (int)($cy + $x * $sinA + $y * $cosA)];
			};
			// Blade polygon
			$bladePts = [];
			foreach ([
				[-$this->scl(3), 0],
				[-$this->scl(3), -(int)($size * 0.7)],
				[0, -(int)($size * 0.78)],
				[$this->scl(3), -(int)($size * 0.7)],
				[$this->scl(3), 0],
			] as $pt) {
				$p = $tx($pt[0], $pt[1]);
				$bladePts[] = $p[0];
				$bladePts[] = $p[1];
			}
			imagefilledpolygon($img, $bladePts, $bladeSilver);
			imagesetthickness($img, $this->scl(1));
			imagepolygon($img, $bladePts, $bladeDark);
			// Crossbar (rect approximated via polygon)
			$gLen = (int)($size * 0.24);
			$gH = $this->scl(5);
			$guardPts = [];
			foreach ([
				[-(int)($gLen / 2), -(int)($gH / 2)],
				[(int)($gLen / 2), -(int)($gH / 2)],
				[(int)($gLen / 2), (int)($gH / 2)],
				[-(int)($gLen / 2), (int)($gH / 2)],
			] as $pt) {
				$p = $tx($pt[0], $pt[1]);
				$guardPts[] = $p[0];
				$guardPts[] = $p[1];
			}
			imagefilledpolygon($img, $guardPts, $guardC);
			imagepolygon($img, $guardPts, $guardStroke);
			// Grip
			$grLen = (int)($size * 0.18);
			$grPts = [];
			foreach ([
				[-$this->scl(2), $this->scl(3)],
				[$this->scl(2), $this->scl(3)],
				[$this->scl(2), $this->scl(3) + $grLen],
				[-$this->scl(2), $this->scl(3) + $grLen],
			] as $pt) {
				$p = $tx($pt[0], $pt[1]);
				$grPts[] = $p[0];
				$grPts[] = $p[1];
			}
			imagefilledpolygon($img, $grPts, $gripC);
			// Pommel
			$pm = $tx(0, $this->scl(3) + $grLen + $this->scl(4));
			imagefilledellipse($img, $pm[0], $pm[1], $this->scl(10), $this->scl(10), $pommelC);
			imageellipse($img, $pm[0], $pm[1], $this->scl(10), $this->scl(10), $guardStroke);
		}
		imagesetthickness($img, 1);
	}

	// --- Margin medallions ---
	private function drawMarginMedallions($state, $x, $startY, $spacing, $r) {
		$img = $state['img'];
		$pal = $state['pal'];
		$items = [];
		if (strlen($state['heraldry']['kingdom'])) $items[] = $state['heraldry']['kingdom'];
		if (strlen($state['heraldry']['park']))    $items[] = $state['heraldry']['park'];
		if (strlen($state['heraldry']['player']))  $items[] = $state['heraldry']['player'];
		foreach ($items as $i => $url) {
			$cy = $startY + $i * $spacing;
			// Draw heraldry clipped to circle (GD approx: draw square, then overlay ring)
			$this->drawHeraldryImage($img, $url, ['x' => $x - $r, 'y' => $cy - $r, 'w' => $r * 2, 'h' => $r * 2]);
			imagesetthickness($img, $this->scl(3));
			imageellipse($img, $x, $cy, $r * 2, $r * 2, $this->rgba($img, $pal['accent']));
			imagesetthickness($img, $this->scl(1));
			imageellipse($img, $x, $cy, (int)($r * 2 - $this->scl(8)), (int)($r * 2 - $this->scl(8)), imagecolorallocatealpha($img, $pal['accent'][0], $pal['accent'][1], $pal['accent'][2], 70));
		}
		imagesetthickness($img, 1);
	}

	// --- Ruled line ---
	private function drawRuledLine($state, $x1, $y1, $x2, $y2, $opacity) {
		$img = $state['img'];
		$pal = $state['pal'];
		$alpha = (int)(127 * (1 - $opacity));
		$c = imagecolorallocatealpha($img, $pal['accent'][0], $pal['accent'][1], $pal['accent'][2], $alpha);
		imagesetthickness($img, $this->scl(1));
		imageline($img, $x1, $y1, $x2, $y2, $c);
		$dotR = $this->scl(2);
		imagefilledellipse($img, $x1, $y1, $dotR * 2, $dotR * 2, $c);
		imagefilledellipse($img, $x2, $y2, $dotR * 2, $dotR * 2, $c);
		imagesetthickness($img, 1);
	}

	// --- Laurel wreath ---
	private function drawLaurelWreath($state, $cx, $cy, $outerR) {
		$img = $state['img'];
		$pal = $state['pal'];
		$leafC = imagecolorallocatealpha($img, $pal['accent'][0], $pal['accent'][1], $pal['accent'][2], 64);
		for ($side = 0; $side < 2; $side++) {
			$dir = $side === 0 ? -1 : 1;
			$leaves = 14;
			for ($i = 0; $i < $leaves; $i++) {
				$t = $i / ($leaves - 1);
				$ang = M_PI * 0.92 - $t * M_PI * 0.85;
				$lx = $cx + $dir * cos($ang) * $outerR;
				$ly = $cy - sin($ang) * $outerR;
				// Approximate leaf as small filled ellipse
				imagefilledellipse($img, (int)$lx, (int)$ly, (int)($outerR * 0.16), (int)($outerR * 0.06), $leafC);
			}
		}
		imagesetthickness($img, $this->scl(2));
		imageellipse($img, $cx, (int)($cy + $outerR * 0.9), (int)($outerR * 0.16), (int)($outerR * 0.16), imagecolorallocatealpha($img, $pal['accent'][0], $pal['accent'][1], $pal['accent'][2], 64));
		imagesetthickness($img, 1);
	}

	// --- Compass rose ---
	private function drawCompassRose($state, $cx, $cy, $r) {
		$img = $state['img'];
		$pal = $state['pal'];
		$c = imagecolorallocatealpha($img, $pal['accent'][0], $pal['accent'][1], $pal['accent'][2], 64);
		imagesetthickness($img, $this->scl(1));
		imageellipse($img, $cx, $cy, $r * 2, $r * 2, $c);
		imageellipse($img, $cx, $cy, (int)($r * 1.64), (int)($r * 1.64), $c);
		for ($i = 0; $i < 8; $i++) {
			$ang = ($i / 8.0) * 2.0 * M_PI - M_PI / 2;
			$long = ($i % 2 === 0);
			$pr = $long ? $r * 0.82 : $r * 0.45;
			$pts = [
				$cx, $cy,
				(int)($cx + cos($ang - 0.12) * $pr * 0.3), (int)($cy + sin($ang - 0.12) * $pr * 0.3),
				(int)($cx + cos($ang) * $pr), (int)($cy + sin($ang) * $pr),
				(int)($cx + cos($ang + 0.12) * $pr * 0.3), (int)($cy + sin($ang + 0.12) * $pr * 0.3),
			];
			imagefilledpolygon($img, $pts, $c);
		}
		imagefilledellipse($img, $cx, $cy, $this->scl(6), $this->scl(6), $this->rgba($img, $pal['accent']));
		imagesetthickness($img, 1);
	}

	// --- Fleur-de-lis (simplified: central pointed shape + band + base) ---
	private function drawFleurDeLis($state, $cx, $cy, $size) {
		$img = $state['img'];
		$pal = $state['pal'];
		$accent = $this->rgba($img, $pal['accent']);
		$dark = $this->rgba($img, $this->darken($pal['accent'], 0.4));
		// Central petal (diamond)
		$pts = [
			$cx, $cy - (int)($size * 0.5),
			$cx + (int)($size * 0.12), $cy - (int)($size * 0.15),
			$cx, $cy + (int)($size * 0.05),
			$cx - (int)($size * 0.12), $cy - (int)($size * 0.15),
		];
		imagefilledpolygon($img, $pts, $accent);
		imagepolygon($img, $pts, $dark);
		// Left petal
		$ptsL = [
			$cx - (int)($size * 0.25), $cy - (int)($size * 0.3),
			$cx - (int)($size * 0.42), $cy + (int)($size * 0.05),
			$cx - (int)($size * 0.1), $cy + (int)($size * 0.1),
			$cx - (int)($size * 0.05), $cy - (int)($size * 0.1),
		];
		imagefilledpolygon($img, $ptsL, $accent);
		imagepolygon($img, $ptsL, $dark);
		// Right petal
		$ptsR = [
			$cx + (int)($size * 0.25), $cy - (int)($size * 0.3),
			$cx + (int)($size * 0.42), $cy + (int)($size * 0.05),
			$cx + (int)($size * 0.1), $cy + (int)($size * 0.1),
			$cx + (int)($size * 0.05), $cy - (int)($size * 0.1),
		];
		imagefilledpolygon($img, $ptsR, $accent);
		imagepolygon($img, $ptsR, $dark);
		// Band
		imagefilledrectangle($img, $cx - (int)($size * 0.22), $cy + (int)($size * 0.08), $cx + (int)($size * 0.22), $cy + (int)($size * 0.14), $accent);
		imagerectangle($img, $cx - (int)($size * 0.22), $cy + (int)($size * 0.08), $cx + (int)($size * 0.22), $cy + (int)($size * 0.14), $dark);
	}

	// --- Corner flourish (approx vine + leaves) ---
	private function drawCornerFlourish($state, $cx, $cy, $size, $corner) {
		$img = $state['img'];
		$pal = $state['pal'];
		$sx = ($corner === 'tr' || $corner === 'br') ? -1 : 1;
		$sy = ($corner === 'bl' || $corner === 'br') ? -1 : 1;
		$c = imagecolorallocatealpha($img, $pal['accent'][0], $pal['accent'][1], $pal['accent'][2], 70);
		imagesetthickness($img, $this->scl(2));
		// Main vine (approximate quadratic with line segments)
		$segs = 8;
		$start = [$cx, $cy];
		$ctl   = [$cx + $sx * (int)($size * 0.3), $cy + $sy * (int)($size * 0.1)];
		$endP  = [$cx + $sx * (int)($size * 0.4), $cy + $sy * (int)($size * 0.35)];
		$prev = $start;
		for ($i = 1; $i <= $segs; $i++) {
			$t = $i / $segs;
			$u = 1 - $t;
			$px = (int)($u*$u*$start[0] + 2*$u*$t*$ctl[0] + $t*$t*$endP[0]);
			$py = (int)($u*$u*$start[1] + 2*$u*$t*$ctl[1] + $t*$t*$endP[1]);
			imageline($img, $prev[0], $prev[1], $px, $py, $c);
			$prev = [$px, $py];
		}
		// Secondary line to end curl
		$start2 = [$cx + $sx * (int)($size * 0.1), $cy + $sy * (int)($size * 0.05)];
		$endP2 = [$cx + $sx * (int)($size * 0.55), $cy + $sy * (int)($size * 0.25)];
		imageline($img, $start2[0], $start2[1], $endP2[0], $endP2[1], $c);
		// Leaves
		$leafSpots = [
			[$cx + $sx * (int)($size * 0.25), $cy + $sy * (int)($size * 0.2)],
			[$cx + $sx * (int)($size * 0.45), $cy + $sy * (int)($size * 0.45)],
			[$cx + $sx * (int)($size * 0.35), $cy + $sy * (int)($size * 0.7)],
		];
		foreach ($leafSpots as $p) {
			imagefilledellipse($img, $p[0], $p[1], $this->scl(16), $this->scl(7), $c);
		}
		imagesetthickness($img, 1);
	}

	// --- Ornamental rule ---
	private function drawOrnamentalRule($state, $cx, $cy, $width) {
		$img = $state['img'];
		$pal = $state['pal'];
		$c = imagecolorallocatealpha($img, $pal['accent'][0], $pal['accent'][1], $pal['accent'][2], 45);
		$half = (int)($width / 2);
		imagesetthickness($img, $this->scl(1));
		imageline($img, $cx - $half, $cy, $cx - $this->scl(24), $cy, $c);
		imageline($img, $cx + $this->scl(24), $cy, $cx + $half, $cy, $c);
		// Center fleur
		$this->drawFleurDeLis($state, $cx, $cy, $this->scl(26));
		// Endpoint diamonds
		$ed = $this->scl(4);
		imagefilledpolygon($img, [$cx - $half, $cy, $cx - $half + $this->scl(6), $cy - $ed, $cx - $half + $this->scl(10), $cy, $cx - $half + $this->scl(6), $cy + $ed], $c);
		imagefilledpolygon($img, [$cx + $half, $cy, $cx + $half - $this->scl(6), $cy - $ed, $cx + $half - $this->scl(10), $cy, $cx + $half - $this->scl(6), $cy + $ed], $c);
		imagesetthickness($img, 1);
	}

	// ================================================================
	//  v2: Default / per-template content renderers
	// ================================================================

	private function renderContentDefault($state) {
		$tpl = $state['tpl'];
		$this->drawHeraldryFromSpec($state, $tpl['heraldry']);
		$this->drawCenterImageSlot($state);
		$this->drawTitleCenter($state, $tpl['title']);
		$this->drawRecipientCenter($state, $tpl['recipient']);
		$this->drawBodyCenter($state, $tpl['body']);
		$this->drawDateLine($state, $tpl['sigY'] - $this->scl(45));
		$this->drawSealElement($state, (int)($state['w'] / 2), $tpl['sigY'] - $this->scl(95), $this->scl(50));
		$this->drawSignatureBar($state, $tpl['sigY'], $tpl['sigCount']);
	}

	// --- 1. Royal Decree ---
	private function render_royal_decree($state) {
		$tpl = $state['tpl'];
		$el  = $state['elements'];
		$w = $state['w']; $h = $state['h'];
		if ($el['flourishes']) {
			$this->drawCornerFlourish($state, $this->scl(70), $this->scl(70), $this->scl(90), 'tl');
			$this->drawCornerFlourish($state, $w - $this->scl(70), $this->scl(70), $this->scl(90), 'tr');
			$this->drawCornerFlourish($state, $this->scl(70), $h - $this->scl(70), $this->scl(90), 'bl');
			$this->drawCornerFlourish($state, $w - $this->scl(70), $h - $this->scl(70), $this->scl(90), 'br');
		}
		if ($el['ribbon']) {
			$this->drawRibbonBanner($state, (int)($w / 2), $this->scl(230), $this->scl(620), $this->scl(88),
				strlen($state['awardName']) ? $state['awardName'] : 'Award Title',
				$state['fontFiles']['title'], $this->scl(42));
		} else {
			$this->drawTitleCenter($state, $tpl['title']);
		}
		$this->drawOrnamentalRule($state, (int)($w / 2), $this->scl(325), $this->scl(440));
		$this->drawHeraldryFromSpec($state, $tpl['heraldry']);
		$this->drawCenterImageSlot($state);
		$this->drawRecipientCenter($state, $tpl['recipient']);
		$this->drawBodyCenter($state, $tpl['body']);
		$this->drawDateLine($state, $tpl['sigY'] - $this->scl(45));
		if ($el['waxSeal']) {
			$this->drawWaxSealLarge($state, $w - $this->scl(110), $h - $this->scl(130), $this->scl(54));
		}
		$this->drawSignatureBar($state, $tpl['sigY'], $tpl['sigCount']);
	}

	// --- 2. Heraldic Shield ---
	private function render_heraldic_shield($state) {
		$tpl = $state['tpl'];
		$w = $state['w']; $h = $state['h'];
		// Quartered shield dominates top
		$shield = $tpl['shield'] ?? ['cx' => (int)($w / 2), 'cy' => $this->scl(240), 'size' => $this->scl(290)];
		$this->drawQuarteredShield($state, $shield['cx'], $shield['cy'], $shield['size']);
		$this->drawCenterImageSlot($state);
		$this->drawTitleCenter($state, $tpl['title']);
		$this->drawDividerV2($state, (int)($w / 2), $tpl['title']['y'] + $tpl['title']['size'] + $this->scl(25), $this->scl(320), 0.55);
		$this->drawRecipientCenter($state, $tpl['recipient']);
		$this->drawBodyCenter($state, $tpl['body']);
		$this->drawDateLine($state, $tpl['sigY'] - $this->scl(45));
		$this->drawSealElement($state, (int)($w / 2), $tpl['sigY'] - $this->scl(95), $this->scl(46));
		$this->drawDividerV2($state, (int)($w / 2), $tpl['sigY'] - $this->scl(40), $this->scl(350), 0.4);
		$this->drawSignatureBar($state, $tpl['sigY'], $tpl['sigCount']);
	}

	// --- 3. Chancery Letter ---
	private function render_chancery_letter($state) {
		$tpl = $state['tpl'];
		$el = $state['elements'];
		$w = $state['w']; $h = $state['h'];
		// Margin medallions (right edge)
		if ($el['medallions']) {
			$this->drawMarginMedallions($state, $w - $this->scl(90), $this->scl(170), $this->scl(120), $this->scl(42));
		}
		// Opening phrase (small italic)
		if (!$state['useBuiltin'] && $state['fontFiles']['body']) {
			$italic = imagecolorallocatealpha($state['img'], $state['pal']['text'][0], $state['pal']['text'][1], $state['pal']['text'][2], 45);
			imagettftext($state['img'], $this->scl(16), 0, $this->scl(170), $this->scl(115) + $this->scl(16), $italic, $state['fontFiles']['body'], 'Let it be known —');
		}
		$this->drawTitleLeft($state, $tpl['title']);
		$this->drawRuledLine($state, $this->scl(170), $this->scl(215), $w - $this->scl(170), $this->scl(215), 0.45);
		$this->drawRecipientLeft($state, $tpl['recipient']);
		$this->drawRuledLine($state, $this->scl(170), $this->scl(310), $w - $this->scl(170), $this->scl(310), 0.35);
		$this->drawCenterImageSlot($state);
		$this->drawBodyLeft($state, $tpl['body']);
		$this->drawSignatureStack($state, $w - $this->scl(100), $tpl['sigY'], $tpl['sigCount'], 'right');
		if ($el['waxSeal']) {
			$this->drawWaxSealLarge($state, $this->scl(200), $tpl['sigY'] + $this->scl(40), $this->scl(54));
		}
	}

	// --- 4. Illuminated Manuscript ---
	private function render_illuminated_ms($state) {
		$tpl = $state['tpl'];
		$el = $state['elements'];
		$w = $state['w']; $h = $state['h'];
		if ($el['flourishes']) {
			$this->drawCornerFlourish($state, $this->scl(70), $this->scl(70), $this->scl(100), 'tl');
			$this->drawCornerFlourish($state, $w - $this->scl(70), $this->scl(70), $this->scl(100), 'tr');
			$this->drawCornerFlourish($state, $this->scl(70), $h - $this->scl(70), $this->scl(100), 'bl');
			$this->drawCornerFlourish($state, $w - $this->scl(70), $h - $this->scl(70), $this->scl(100), 'br');
		}
		$this->drawTitleCenter($state, $tpl['title']);
		$this->drawOrnamentalRule($state, (int)($w / 2), $this->scl(225), $this->scl(400));
		$this->drawRecipientCenter($state, $tpl['recipient']);
		$this->drawOrnamentalRule($state, (int)($w / 2), $this->scl(315), $this->scl(360));
		if ($el['medallions']) {
			$this->drawMarginMedallions($state, $this->scl(150), $this->scl(400), $this->scl(120), $this->scl(50));
		}
		$this->drawCenterImageSlot($state);
		// Body with optional drop cap
		$body = $state['bodyText'];
		if ($el['dropCap'] && strlen($body)) {
			$first = mb_strtoupper(mb_substr($body, 0, 1));
			$rest = ltrim(mb_substr($body, 1));
			$this->drawDropCap($state, $first, $tpl['body']['x'], $tpl['body']['y'], $this->scl(72), $state['fontFiles']['title']);
			$this->drawBodyLeftWithIndent($state, $tpl['body'], $this->scl(86), $rest);
		} else {
			$this->drawBodyLeft($state, $tpl['body']);
		}
		$this->drawDateLine($state, $tpl['sigY'] - $this->scl(45));
		$this->drawSealElement($state, (int)($w / 2), $tpl['sigY'] - $this->scl(95), $this->scl(48));
		$this->drawOrnamentalRule($state, (int)($w / 2), $tpl['sigY'] - $this->scl(35), $this->scl(400));
		$this->drawSignatureBar($state, $tpl['sigY'], $tpl['sigCount']);
	}

	// --- 5. Battle Standard ---
	private function render_battle_standard($state) {
		$tpl = $state['tpl'];
		$el = $state['elements'];
		$w = $state['w']; $h = $state['h'];
		if ($el['swords']) {
			$this->drawCrossedSwords($state, (int)($w / 2), $this->scl(105), $this->scl(95));
		}
		$this->drawTitleCenter($state, $tpl['title']);
		$this->drawOrnamentalRule($state, (int)($w / 2), $this->scl(240), $this->scl(520));
		$this->drawRecipientCenter($state, $tpl['recipient']);
		$this->drawDividerV2($state, (int)($w / 2), $this->scl(345), $this->scl(460), 0.5);
		$this->drawBodyCenter($state, $tpl['body']);
		$this->drawHeraldryFromSpec($state, $tpl['heraldry']);
		$this->drawCenterImageSlot($state);
		$this->drawDateLine($state, $tpl['sigY'] - $this->scl(20));
		$this->drawSignatureBar($state, $tpl['sigY'], $tpl['sigCount']);
	}

	// --- 6. Guild Charter ---
	private function render_guild_charter($state) {
		$tpl = $state['tpl'];
		$el = $state['elements'];
		$w = $state['w']; $h = $state['h'];
		if ($el['ribbon']) {
			$this->drawRibbonBanner($state, (int)($w / 2), $this->scl(205), $this->scl(620), $this->scl(82),
				strlen($state['awardName']) ? $state['awardName'] : 'Charter Title',
				$state['fontFiles']['title'], $this->scl(38));
		} else {
			$this->drawTitleCenter($state, $tpl['title']);
		}
		$this->drawHeraldryFromSpec($state, $tpl['heraldry']);
		$this->drawRecipientCenter($state, $tpl['recipient']);
		$this->drawDividerV2($state, (int)($w / 2), $this->scl(370), $this->scl(420), 0.4);
		// Column divider (vertical line between body and signatures)
		$divC = imagecolorallocatealpha($state['img'], $state['pal']['accent'][0], $state['pal']['accent'][1], $state['pal']['accent'][2], 80);
		imagesetthickness($state['img'], $this->scl(1));
		imageline($state['img'], $this->scl(530), $this->scl(405), $this->scl(530), $this->scl(920), $divC);
		imagesetthickness($state['img'], 1);
		$this->drawCenterImageSlot($state);
		$this->drawBodyLeft($state, $tpl['body']);
		$this->drawSignatureStack($state, $this->scl(665), $this->scl(660), $tpl['sigCount'], 'center');
		if ($el['waxSeal']) {
			$this->drawWaxSealLarge($state, $this->scl(665), $this->scl(870), $this->scl(50));
		}
	}

	// --- 7. Arcane Grimoire ---
	private function render_arcane_grimoire($state) {
		$tpl = $state['tpl'];
		$el = $state['elements'];
		$w = $state['w']; $h = $state['h'];
		if ($el['flourishes']) {
			$this->drawCornerFlourish($state, $this->scl(60), $this->scl(60), $this->scl(85), 'tl');
			$this->drawCornerFlourish($state, $w - $this->scl(60), $this->scl(60), $this->scl(85), 'tr');
			$this->drawCornerFlourish($state, $this->scl(60), $h - $this->scl(60), $this->scl(85), 'bl');
			$this->drawCornerFlourish($state, $w - $this->scl(60), $h - $this->scl(60), $this->scl(85), 'br');
		}
		if ($el['laurel']) {
			$this->drawLaurelWreath($state, (int)($w / 2), $this->scl(275), $this->scl(165));
		}
		$this->drawTitleCenter($state, $tpl['title']);
		$this->drawHeraldryFromSpec($state, $tpl['heraldry']);
		$this->drawOrnamentalRule($state, (int)($w / 2), $this->scl(380), $this->scl(420));
		$this->drawRecipientCenter($state, $tpl['recipient']);
		$this->drawCenterImageSlot($state);
		$this->drawBodyCenter($state, $tpl['body']);
		if ($el['compass']) {
			$this->drawCompassRose($state, (int)($w / 2), $tpl['sigY'] - $this->scl(85), $this->scl(56));
		} else {
			$this->drawSealElement($state, (int)($w / 2), $tpl['sigY'] - $this->scl(85), $this->scl(48));
		}
		$this->drawDateLine($state, $tpl['sigY'] - $this->scl(30));
		$this->drawOrnamentalRule($state, (int)($w / 2), $tpl['sigY'] - $this->scl(5), $this->scl(440));
		$this->drawSignatureBar($state, $tpl['sigY'], $tpl['sigCount']);
	}

	// --- 8. Bardic Ballad ---
	private function render_bardic_ballad($state) {
		$tpl = $state['tpl'];
		$el = $state['elements'];
		$w = $state['w']; $h = $state['h'];
		if ($el['flourishes']) {
			$this->drawCornerFlourish($state, $this->scl(70), $this->scl(70), $this->scl(95), 'tl');
			$this->drawCornerFlourish($state, $w - $this->scl(70), $this->scl(70), $this->scl(95), 'tr');
			$this->drawCornerFlourish($state, $this->scl(70), $h - $this->scl(70), $this->scl(95), 'bl');
			$this->drawCornerFlourish($state, $w - $this->scl(70), $h - $this->scl(70), $this->scl(95), 'br');
		}
		$this->drawTitleCenter($state, $tpl['title']);
		$this->drawOrnamentalRule($state, (int)($w / 2), $this->scl(230), $this->scl(380));
		$this->drawHeraldryFromSpec($state, $tpl['heraldry']);
		$this->drawRecipientCenter($state, $tpl['recipient']);
		$this->drawOrnamentalRule($state, (int)($w / 2), $this->scl(360), $this->scl(380));
		$this->drawCenterImageSlot($state);
		$body = $state['bodyText'];
		if ($el['dropCap'] && strlen($body)) {
			$first = mb_strtoupper(mb_substr($body, 0, 1));
			$rest = ltrim(mb_substr($body, 1));
			$this->drawDropCap($state, $first, $tpl['body']['x'], $tpl['body']['y'], $this->scl(62), $state['fontFiles']['title']);
			$this->drawBodyLeftWithIndent($state, $tpl['body'], $this->scl(78), $rest);
		} else {
			$this->drawBodyLeft($state, $tpl['body']);
		}
		if ($el['waxSeal']) {
			$this->drawWaxSealLarge($state, $w - $this->scl(115), $tpl['sigY'] - $this->scl(40), $this->scl(48));
		}
		$this->drawDateLine($state, $tpl['sigY'] - $this->scl(30));
		$this->drawSignatureBar($state, $tpl['sigY'], $tpl['sigCount']);
	}

	// --- Thin wrapper around existing drawDivider (takes $state instead of individual args) ---
	private function drawDividerV2($state, $cx, $cy, $width, $opacity) {
		$this->drawDivider($state['img'], $cx, $cy, $width, $state['pal'], $opacity);
	}


}
