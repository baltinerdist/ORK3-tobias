<?php
	// ---- Normalize data into clean local variables ----
	$sgAward       = $award       ?? null;
	$sgPlayer      = $player      ?? null;
	$sgKingdomName = $kingdom_name ?? '';
	$sgParkName    = $park_name    ?? '';
	$sgKingdomHeraldry = $kingdom_heraldry_url ?? '';
	$sgParkHeraldry    = $park_heraldry_url    ?? '';
	$sgPlayerHeraldry  = $player_heraldry_url  ?? '';
	$sgSessionUserId   = (int)($session_user_id ?? 0);
	$sgCanGenerate     = !empty($can_generate);
	$sgPreloadOfficers = $preload_officers ?? array();
	$sgKingdomId       = (int)($kingdom_id ?? 0);
	$sgParkId          = (int)($park_id ?? 0);
	$sgIsOrkAdmin      = !empty($is_ork_admin);
	$sgSessionToken    = $session_token ?? '';

	// Determine auto-template from award type
	$sgAutoTemplate = 'B'; // default: Order/Award
	if ($sgAward) {
		$knightIds = [17, 18, 19, 20, 245];
		if (in_array((int)($sgAward['AwardId'] ?? 0), $knightIds)) {
			$sgAutoTemplate = 'A';
		} elseif (!empty($sgAward['IsTitle']) && $sgAward['IsTitle'] == 1) {
			$sgAutoTemplate = 'C';
		} elseif (!empty($sgAward['IsLadder']) && $sgAward['IsLadder'] == 1) {
			$sgAutoTemplate = 'B';
		}
	}

	// Determine best award display name
	$sgAwardName = '';
	if ($sgAward) {
		if (!empty($sgAward['KingdomAwardName'])) {
			$sgAwardName = $sgAward['KingdomAwardName'];
		} elseif (!empty($sgAward['CustomAwardName'])) {
			$sgAwardName = $sgAward['CustomAwardName'];
		} elseif (!empty($sgAward['Name'])) {
			$sgAwardName = $sgAward['Name'];
		}
	}

	// Build SgConfig JSON for JS
	$sgConfig = [
		'uir'              => UIR,
		'canGenerate'      => $sgCanGenerate,
		'autoTemplate'     => $sgAutoTemplate,
		'persona'          => $sgPlayer ? ($sgPlayer['Persona'] ?? '') : '',
		'awardName'        => $sgAwardName,
		'rank'             => $sgAward ? (int)($sgAward['Rank'] ?? 0) : 0,
		'date'             => $sgAward ? ($sgAward['Date'] ?? '') : '',
		'givenBy'          => $sgAward ? ($sgAward['GivenBy'] ?? '') : '',
		'parkName'         => $sgParkName,
		'kingdomName'      => $sgKingdomName,
		'kingdomHeraldry'  => $sgKingdomHeraldry,
		'parkHeraldry'     => $sgParkHeraldry,
		'playerHeraldry'   => $sgPlayerHeraldry,
		'isLadder'         => $sgAward ? (bool)($sgAward['IsLadder'] ?? false) : false,
		'isTitle'          => $sgAward ? (bool)($sgAward['IsTitle'] ?? false) : false,
		'mundaneId'        => $sgPlayer ? (int)($sgPlayer['MundaneId'] ?? 0) : 0,
		'awardsId'         => $sgAward ? (int)($sgAward['AwardsId'] ?? 0) : 0,
		'note'             => $sgAward ? ($sgAward['Note'] ?? '') : '',
		'httpService'      => HTTP_SERVICE,
		'parkId'           => $sgParkId,
		'kingdomId'        => $sgKingdomId,
		'preloadOfficers'  => $sgPreloadOfficers,
		'heraldryPlayerBase'  => HTTP_PLAYER_HERALDRY,
		'heraldryParkBase'    => HTTP_PARK_HERALDRY,
		'heraldryKingdomBase' => HTTP_KINGDOM_HERALDRY,
		'token'               => $sgSessionToken,
		'isOrkAdmin'          => $sgIsOrkAdmin,
		'artLicense'          => (class_exists('ScrollArtwork') ? ScrollArtwork::SCROLL_ARTWORK_LICENSE : ''),
	];
?>

<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Almendra&family=Caudex&family=Cinzel:wght@400;700&family=Cinzel+Decorative&family=Cormorant+Garamond:wght@400;700&family=EB+Garamond:ital,wght@0,400;0,700;1,400&family=Eagle+Lake&family=Fondamento&family=Germania+One&family=Goudy+Bookletter+1911&family=Great+Vibes&family=Grenze+Gotisch&family=Jim+Nightshade&family=MedievalSharp&family=Metamorphous&family=Pinyon+Script&family=Pirata+One&family=Sorts+Mill+Goudy&family=Tangerine:wght@700&family=Uncial+Antiqua&family=UnifrakturMaguntia&display=swap" rel="stylesheet">
<link rel="stylesheet" href="<?= HTTP_TEMPLATE ?>revised-frontend/style/revised.css?v=<?= filemtime(DIR_TEMPLATE . 'revised-frontend/style/revised.css') ?>">

<style>
/* ===========================
   Scroll Generator (sc-)
   =========================== */

/* ---- Hero Header ---- */
.sc-hero {
  position: relative;
  border-radius: 10px;
  overflow: hidden;
  margin-top: 3px;
  margin-bottom: 20px;
  background: linear-gradient(135deg, #44337a 0%, #553c9a 40%, #6b46c1 100%);
  min-height: 100px;
}
.sc-hero-content {
  position: relative;
  z-index: 1;
  display: flex;
  align-items: center;
  padding: 24px 30px;
  gap: 22px;
}
.sc-hero-icon {
  width: 64px;
  height: 64px;
  border-radius: 14px;
  background: rgba(255,255,255,0.12);
  border: 1px solid rgba(255,255,255,0.18);
  display: flex;
  align-items: center;
  justify-content: center;
  color: #fff;
  font-size: 26px;
  flex-shrink: 0;
}
.sc-hero-info {
  flex: 1;
  min-width: 0;
}
.sc-hero-title {
  font-size: 24px;
  font-weight: 700;
  color: #fff;
  margin: 0 0 4px;
  background: transparent;
  border: none;
  padding: 0;
  border-radius: 0;
  text-shadow: 0 1px 3px rgba(0,0,0,0.3);
}
.sc-hero-sub {
  font-size: 13px;
  color: rgba(255,255,255,0.65);
  margin: 0;
}
.sc-hero-sub strong {
  color: #fff;
  font-weight: 600;
}
.sc-hero-badges {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin-top: 8px;
}
.sc-hero-badge {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  background: rgba(255,255,255,0.12);
  border: 1px solid rgba(255,255,255,0.22);
  color: rgba(255,255,255,0.85);
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.05em;
  text-transform: uppercase;
  border-radius: 20px;
  padding: 3px 10px;
}

/* ---- Workspace layout ---- */
.sc-workspace {
  display: flex;
  gap: 24px;
  align-items: flex-start;
}
.sc-controls {
  flex: 1;
  min-width: 0;
}
.sc-preview-wrap {
  width: 380px;
  flex-shrink: 0;
  position: sticky;
  top: 20px;
}

/* ---- Section card ---- */
.sc-section {
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  margin-bottom: 16px;
  overflow: hidden;
}
.sc-section-title {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 12px 16px;
  cursor: pointer;
  user-select: none;
  background: #f7fafc;
  border-bottom: 1px solid #e2e8f0;
  transition: background 0.15s;
}
.sc-section-title:hover {
  background: #edf2f7;
}
.sc-section-title h3 {
  background: transparent;
  border: none;
  padding: 0;
  border-radius: 0;
  text-shadow: none;
  font-size: 11px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: #4a5568;
  margin: 0;
}
.sc-section-title .sc-chevron {
  font-size: 12px;
  color: #a0aec0;
  transition: transform 0.2s;
}
.sc-section.sc-collapsed .sc-chevron {
  transform: rotate(-90deg);
}
.sc-section-body {
  padding: 16px;
}
.sc-section.sc-collapsed .sc-section-body {
  display: none;
}

/* ---- Template cards ---- */
.sc-template-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 12px;
}
.sc-template-card {
  border: 2px solid #e2e8f0;
  border-radius: 8px;
  padding: 14px 10px 12px;
  text-align: center;
  cursor: pointer;
  transition: border-color 0.2s, box-shadow 0.2s, transform 0.1s;
  background: #fff;
}
.sc-template-card:hover {
  border-color: #90cdf4;
  box-shadow: 0 2px 8px rgba(66, 153, 225, 0.15);
}
.sc-template-card.sc-active {
  border-color: #3182ce;
  box-shadow: 0 0 0 3px rgba(49, 130, 206, 0.2);
  background: #ebf8ff;
}
.sc-template-card .sc-tpl-icon {
  font-size: 28px;
  margin-bottom: 6px;
  display: block;
}
.sc-template-card .sc-tpl-name {
  font-size: 13px;
  font-weight: 700;
  color: #2d3748;
  display: block;
  margin-bottom: 2px;
}
.sc-template-card .sc-tpl-desc {
  font-size: 11px;
  color: #718096;
  display: block;
}

/* ---- Form fields ---- */
.sc-field-group {
  margin-bottom: 14px;
}
.sc-field-group:last-child {
  margin-bottom: 0;
}
.sc-field-label {
  display: block;
  font-size: 11px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: #4a5568;
  margin-bottom: 4px;
}
.sc-field-label .sc-badge {
  display: inline-block;
  font-size: 10px;
  font-weight: 600;
  padding: 1px 6px;
  border-radius: 10px;
  margin-left: 6px;
  text-transform: none;
  letter-spacing: 0;
  vertical-align: middle;
}
.sc-badge-auto {
  background: #c6f6d5;
  color: #276749;
}
.sc-badge-manual {
  background: #fefcbf;
  color: #975a16;
}
.sc-input,
.sc-textarea,
.sc-select {
  width: 100%;
  padding: 8px 10px;
  border: 1px solid #cbd5e0;
  border-radius: 6px;
  font-size: 13px;
  color: #2d3748;
  background: #fff;
  transition: border-color 0.15s;
  box-sizing: border-box;
  font-family: inherit;
}
.sc-input:focus,
.sc-textarea:focus,
.sc-select:focus {
  outline: none;
  border-color: #3182ce;
  box-shadow: 0 0 0 3px rgba(49, 130, 206, 0.12);
}
.sc-textarea {
  min-height: 80px;
  resize: vertical;
  line-height: 1.5;
}
.sc-row-2 {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
}

/* ---- Regenerate body button ---- */
.sc-regen-btn {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  margin-top: 8px;
  padding: 5px 12px;
  font-size: 11px;
  font-weight: 600;
  color: #4299e1;
  background: #ebf8ff;
  border: 1px solid #bee3f8;
  border-radius: 5px;
  cursor: pointer;
  transition: background 0.15s;
}
.sc-regen-btn:hover {
  background: #bee3f8;
}

/* ---- Font dropdown + Palette swatches ---- */
.sc-font-preview {
  font-size: 13px;
}
.sc-palette-row {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
}
.sc-palette-swatch {
  width: 64px;
  height: 64px;
  border-radius: 8px;
  border: 3px solid #e2e8f0;
  cursor: pointer;
  transition: border-color 0.2s, box-shadow 0.2s, transform 0.1s;
  position: relative;
  overflow: hidden;
}
.sc-palette-swatch:hover {
  transform: scale(1.05);
}
.sc-palette-swatch.sc-active {
  border-color: #3182ce;
  box-shadow: 0 0 0 3px rgba(49, 130, 206, 0.25);
}
.sc-palette-swatch .sc-swatch-inner {
  display: block;
  width: 100%;
  height: 100%;
  border-radius: 5px;
}
.sc-palette-swatch .sc-swatch-check {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  font-size: 16px;
  color: #fff;
  text-shadow: 0 1px 3px rgba(0,0,0,0.5);
  display: none;
}
.sc-palette-swatch.sc-active .sc-swatch-check {
  display: block;
}
.sc-palette-label {
  font-size: 11px;
  color: #718096;
  text-align: center;
  margin-top: 4px;
}
.sc-palette-item {
  display: flex;
  flex-direction: column;
  align-items: center;
}

/* ---- Toggle switches ---- */
.sc-toggle-row {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 8px 0;
  border-bottom: 1px solid #f7fafc;
}
.sc-toggle-row:last-child {
  border-bottom: none;
}
.sc-toggle-switch {
  position: relative;
  width: 40px;
  height: 22px;
  flex-shrink: 0;
}
.sc-toggle-switch input {
  opacity: 0;
  width: 0;
  height: 0;
  position: absolute;
}
.sc-toggle-slider {
  position: absolute;
  cursor: pointer;
  top: 0; left: 0; right: 0; bottom: 0;
  background: #cbd5e0;
  border-radius: 22px;
  transition: background 0.2s;
}
.sc-toggle-slider:before {
  content: '';
  position: absolute;
  height: 16px;
  width: 16px;
  left: 3px;
  bottom: 3px;
  background: #fff;
  border-radius: 50%;
  transition: transform 0.2s;
}
.sc-toggle-switch input:checked + .sc-toggle-slider {
  background: #3182ce;
}
.sc-toggle-switch input:checked + .sc-toggle-slider:before {
  transform: translateX(18px);
}
.sc-toggle-preview {
  width: 36px;
  height: 36px;
  border-radius: 4px;
  overflow: hidden;
  flex-shrink: 0;
  background: #edf2f7;
  border: 1px solid #e2e8f0;
}
.sc-toggle-preview img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}
.sc-toggle-label {
  flex: 1;
  font-size: 13px;
  font-weight: 600;
  color: #2d3748;
}

/* ---- Signature fields ---- */
.sc-sig-pair {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
  margin-bottom: 10px;
}
.sc-sig-pair:last-child {
  margin-bottom: 0;
}

/* ---- Generate button ---- */
.sc-generate-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  width: 100%;
  padding: 12px 20px;
  font-size: 15px;
  font-weight: 700;
  color: #fff;
  background: linear-gradient(135deg, #3182ce, #2b6cb0);
  border: none;
  border-radius: 8px;
  cursor: pointer;
  transition: background 0.2s, box-shadow 0.2s;
  margin-top: 8px;
}
.sc-generate-btn:hover {
  background: linear-gradient(135deg, #2b6cb0, #2c5282);
  box-shadow: 0 4px 12px rgba(49, 130, 206, 0.3);
}
.sc-generate-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

/* ---- Preview panel ---- */
.sc-preview-panel {
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  overflow: hidden;
}
.sc-preview-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 10px 16px;
  background: #f7fafc;
  border-bottom: 1px solid #e2e8f0;
}
.sc-preview-header h3 {
  background: transparent;
  border: none;
  padding: 0;
  border-radius: 0;
  text-shadow: none;
  font-size: 11px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: #4a5568;
  margin: 0;
}
.sc-preview-header .sc-preview-size {
  font-size: 10px;
  color: #a0aec0;
}
.sc-preview-body {
  padding: 12px;
  background: #f0ebe3;
}
.sc-canvas-wrap {
  position: relative;
  width: 100%;
  /* 850:1100 = 8.5:11 US Letter aspect ratio */
  padding-bottom: 129.41%;
  background: #f5e6c8;
  border-radius: 4px;
  overflow: hidden;
  box-shadow: 0 2px 12px rgba(0,0,0,0.15);
}
.sc-canvas-wrap canvas {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  display: block;
}

/* ---- Download button (below preview) ---- */
.sc-download-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  width: 100%;
  padding: 10px 16px;
  font-size: 13px;
  font-weight: 700;
  color: #2d3748;
  background: #fff;
  border: none;
  border-top: 1px solid #e2e8f0;
  cursor: pointer;
  transition: background 0.15s;
}
.sc-download-btn:hover {
  background: #f7fafc;
}
.sc-download-btn:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}



/* ---- Autocomplete dropdown ---- */
.sc-ac-wrap { position: relative; }
.sc-ac-results {
  position: absolute;
  left: 0; right: 0;
  z-index: 300;
  margin-top: 4px;
  border: 1px solid #e2e8f0;
  border-radius: 6px;
  background: #fff;
  box-shadow: 0 4px 12px rgba(0,0,0,.12);
  max-height: 160px;
  overflow-y: auto;
  display: none;
}
.sc-ac-results.sc-ac-open { display: block; }
.sc-ac-item {
  padding: 8px 12px;
  font-size: 13px;
  cursor: pointer;
  color: #2d3748;
  border-bottom: 1px solid #f7fafc;
}
.sc-ac-item:last-child { border-bottom: none; }
.sc-ac-item:hover, .sc-ac-item.sc-ac-focused { background: #ebf4ff; color: #0891b2; }
.sc-ac-item small { display: block; font-size: 11px; color: #a0aec0; margin-top: 1px; }
.sc-ac-no-results { padding: 8px 12px; font-size: 13px; color: #a0aec0; font-style: italic; }

/* ---- Display As inline row ---- */
.sc-display-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
}

/* ---- Officer chips ---- */
.sc-officer-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin-bottom: 6px;
}
.sc-officer-chip {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 5px 10px;
  background: #f7fafc;
  border: 1px solid #e2e8f0;
  border-radius: 20px;
  font-size: 12px;
  color: #2d3748;
  cursor: pointer;
  transition: background 0.12s, border-color 0.12s;
  line-height: 1.3;
}
.sc-officer-chip span { color: #a0aec0; }
.sc-officer-chip:hover { background: #ebf4ff; border-color: #90cdf4; color: #0891b2; }
.sc-officer-chip.sc-selected { background: #ebf4ff; border-color: #90cdf4; color: #0891b2; font-weight: 600; }

/* ---- Heraldry loading spinner ---- */
.sc-toggle-row .sc-toggle-spinner {
  width: 16px;
  height: 16px;
  border: 2px solid #e2e8f0;
  border-top-color: #3182ce;
  border-radius: 50%;
  animation: sc-spin 0.6s linear infinite;
  flex-shrink: 0;
  display: none;
}
.sc-toggle-row.sc-loading .sc-toggle-spinner { display: block; }
.sc-toggle-row.sc-loading .sc-toggle-preview { opacity: 0.4; }
@keyframes sc-spin { to { transform: rotate(360deg); } }

/* ---- Toast notification ---- */
.sc-toast {
  position: fixed;
  bottom: 24px;
  right: 24px;
  z-index: 9999;
  background: #2d3748;
  color: #fff;
  padding: 12px 20px;
  border-radius: 8px;
  font-size: 13px;
  box-shadow: 0 4px 16px rgba(0,0,0,0.2);
  transform: translateY(20px);
  opacity: 0;
  transition: opacity 0.25s, transform 0.25s;
  pointer-events: none;
  max-width: 360px;
}
.sc-toast.sc-toast-warn {
  background: #c05621;
}
.sc-toast.sc-toast-visible {
  opacity: 1;
  transform: translateY(0);
  pointer-events: auto;
}

/* ---- Validation error styling ---- */
.sc-input.sc-invalid,
.sc-textarea.sc-invalid {
  border-color: #e53e3e;
  box-shadow: 0 0 0 3px rgba(229, 62, 62, 0.12);
}
.sc-field-error {
  font-size: 11px;
  color: #e53e3e;
  margin-top: 3px;
  display: none;
}
.sc-field-error.sc-visible { display: block; }

/* ---- Signature add/remove button ---- */
.sc-sig-actions {
  margin-top: 8px;
  text-align: center;
}
.sc-sig-toggle-btn {
  background: none;
  border: 1px dashed #cbd5e0;
  color: #718096;
  padding: 6px 14px;
  border-radius: 6px;
  cursor: pointer;
  font-size: 0.82rem;
  transition: all 0.2s ease;
}
.sc-sig-toggle-btn:hover {
  border-color: #a0aec0;
  color: #4a5568;
  background: #f7fafc;
}
.sc-sig-toggle-btn i {
  margin-right: 4px;
  font-size: 0.75rem;
}

/* ---- Smooth sig3 transition ---- */
.sc-sig-pair.sc-sig-animated {
  overflow: hidden;
  transition: max-height 0.25s ease, opacity 0.2s ease, margin 0.25s ease;
}
.sc-sig-pair.sc-sig-hidden {
  max-height: 0;
  opacity: 0;
  margin-bottom: 0;
  pointer-events: none;
}
.sc-sig-pair.sc-sig-visible {
  max-height: 120px;
  opacity: 1;
}


/* ---- Border style picker ---- */
.sc-border-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 8px;
}
.sc-border-card {
  border: 2px solid #e2e8f0;
  border-radius: 6px;
  background: #fff;
  cursor: pointer;
  padding: 6px;
  text-align: center;
  transition: border-color 0.15s, box-shadow 0.15s;
}
.sc-border-card:hover {
  border-color: #90cdf4;
}
.sc-border-card.sc-active {
  border-color: #3182ce;
  box-shadow: 0 0 0 2px rgba(49,130,206,0.15);
}
.sc-border-card canvas {
  width: 100%;
  height: 60px;
  display: block;
  border-radius: 3px;
}
.sc-border-card-label {
  font-size: 10px;
  font-weight: 600;
  color: #4a5568;
  margin-top: 4px;
  text-transform: uppercase;
  letter-spacing: 0.03em;
}
@media (max-width: 768px) {
  .sc-border-grid {
    grid-template-columns: repeat(2, 1fr);
  }
}
/* ---- Celtic knot options panel ---- */
.sc-celtic-opts {
  display: none;
  margin-top: 10px;
  padding: 12px 14px;
  background: #faf8f4;
  border: 1px solid #e2ddd4;
  border-radius: 6px;
}
.sc-celtic-opts.sc-visible { display: block; }
.sc-celtic-opts-title {
  font-size: 11px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: #6b5a32;
  margin-bottom: 10px;
}
.sc-celtic-row {
  display: flex;
  gap: 12px;
  margin-bottom: 8px;
}
.sc-celtic-row:last-child { margin-bottom: 0; }
.sc-celtic-field {
  flex: 1;
  min-width: 0;
}
.sc-celtic-field label {
  display: block;
  font-size: 11px;
  font-weight: 600;
  color: #4a5568;
  margin-bottom: 3px;
}
.sc-celtic-field input[type="range"] {
  width: 100%;
  accent-color: #8b6914;
}
.sc-celtic-field input[type="color"] {
  width: 32px;
  height: 26px;
  border: 1px solid #cbd5e0;
  border-radius: 4px;
  padding: 1px;
  cursor: pointer;
  vertical-align: middle;
}
.sc-celtic-val {
  display: inline-block;
  font-size: 11px;
  color: #718096;
  margin-left: 4px;
  min-width: 18px;
}
/* ---- Reset button ---- */
.sc-reset-btn {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  padding: 8px 16px;
  font-size: 12px;
  font-weight: 600;
  color: #718096;
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 6px;
  cursor: pointer;
  transition: background 0.15s, border-color 0.15s;
  margin-top: 8px;
}
.sc-reset-btn:hover {
  background: #f7fafc;
  border-color: #cbd5e0;
  color: #4a5568;
}

/* ---- Officer chips section label ---- */
.sc-officer-label {
  font-size: 10px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: #a0aec0;
  margin-bottom: 4px;
}

/* ---- Custom font picker ---- */
.sc-typo-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
}
.sc-font-picker {
  position: relative;
}
.sc-font-picker-label {
  display: flex;
  align-items: center;
  gap: 5px;
  font-size: 11px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: #4a5568;
  margin-bottom: 4px;
}
.sc-font-picker-label i {
  font-size: 10px;
  opacity: 1;
}
/* Color-coded font target icons */
.sc-font-picker-label i.sc-tc-title     { color: #805AD5; }
.sc-font-picker-label i.sc-tc-recipient { color: #3182CE; }
.sc-font-picker-label i.sc-tc-body      { color: #38A169; }
.sc-font-picker-label i.sc-tc-sig       { color: #DD6B20; }
/* Matching color-coded icons in Award Details */
.sc-field-label i.sc-tc-title     { color: #805AD5; opacity: 1; margin-right: 3px; font-size: 10px; }
.sc-field-label i.sc-tc-recipient { color: #3182CE; opacity: 1; margin-right: 3px; font-size: 10px; }
.sc-field-label i.sc-tc-body      { color: #38A169; opacity: 1; margin-right: 3px; font-size: 10px; }
.sc-field-label i.sc-tc-sig       { color: #DD6B20; opacity: 1; margin-right: 3px; font-size: 10px; }
.sc-font-picker-btn {
  display: flex;
  align-items: center;
  justify-content: space-between;
  width: 100%;
  padding: 8px 12px;
  border: 1px solid #cbd5e0;
  border-radius: 6px;
  background: #fff;
  cursor: pointer;
  transition: border-color 0.15s, box-shadow 0.15s;
  text-align: left;
}
.sc-font-picker-btn:hover {
  border-color: #90cdf4;
}
.sc-font-picker-btn.sc-fp-open {
  border-color: #3182ce;
  box-shadow: 0 0 0 3px rgba(49, 130, 206, 0.12);
  border-radius: 6px 6px 0 0;
}
.sc-font-picker-preview {
  flex: 1;
  min-width: 0;
  overflow: hidden;
}
.sc-font-picker-fname {
  font-size: 10px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  color: #a0aec0;
  display: block;
  margin-bottom: 1px;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
}
.sc-font-picker-sample {
  font-size: 17px;
  color: #2d3748;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  display: block;
  line-height: 1.4;
}
.sc-font-picker-arrow {
  color: #a0aec0;
  font-size: 10px;
  margin-left: 8px;
  flex-shrink: 0;
  transition: transform 0.15s;
}
.sc-font-picker-btn.sc-fp-open .sc-font-picker-arrow {
  transform: rotate(180deg);
}
.sc-font-picker-dropdown {
  position: absolute;
  left: 0; right: 0;
  z-index: 500;
  border: 1px solid #3182ce;
  border-top: none;
  border-radius: 0 0 8px 8px;
  background: #fff;
  box-shadow: 0 8px 24px rgba(0,0,0,0.15);
  max-height: 320px;
  overflow-y: auto;
  display: none;
}
.sc-font-picker-dropdown.sc-fp-open {
  display: block;
}
.sc-fp-group-label {
  font-size: 10px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: #a0aec0;
  padding: 10px 12px 4px;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  background: #f7fafc;
  position: sticky;
  top: 0;
  z-index: 1;
}
.sc-fp-item {
  padding: 7px 12px;
  cursor: pointer;
  transition: background 0.1s;
}
.sc-fp-item:hover {
  background: #ebf4ff;
}
.sc-fp-item.sc-fp-selected {
  background: #ebf8ff;
}
.sc-fp-item-name {
  font-size: 10px;
  font-weight: 600;
  color: #718096;
  display: block;
  margin-bottom: 1px;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
}
.sc-fp-item-sample {
  font-size: 16px;
  color: #2d3748;
  display: block;
  line-height: 1.3;
}
.sc-fp-item.sc-fp-selected .sc-fp-item-name {
  color: #3182ce;
}
@media (max-width: 768px) {
  .sc-typo-grid {
    grid-template-columns: 1fr;
  }
}

/* ---- Two-column side-by-side sections ---- */
.sc-two-col {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
  margin-bottom: 16px;
}
.sc-two-col > .sc-section {
  margin-bottom: 0;
}

/* ---- Download buttons row ---- */
.sc-btn-row {
  display: flex;
  gap: 8px;
  align-items: center;
  margin-top: 8px;
}
.sc-btn-row .sc-generate-btn {
  margin-top: 0;
  flex: 1;
}
.sc-btn-row .sc-reset-btn {
  margin-top: 0;
}

/* ---- Responsive ---- */
@media (max-width: 768px) {
  .sc-workspace {
    flex-direction: column-reverse;
  }
  .sc-preview-wrap {
    width: 100%;
    position: static;
  }
  .sc-controls {
    width: 100%;
  }
  .sc-template-grid {
    grid-template-columns: 1fr;
    gap: 8px;
  }
  .sc-template-card {
    display: flex;
    align-items: center;
    gap: 10px;
    text-align: left;
    padding: 10px 14px;
  }
  .sc-template-card .sc-tpl-icon {
    font-size: 22px;
    margin-bottom: 0;
  }
  .sc-row-2 {
    grid-template-columns: 1fr;
  }
  .sc-sig-pair {
    grid-template-columns: 1fr;
  }
  .sc-hero-content { flex-wrap: wrap; }
  .sc-hero-title { font-size: 20px; }
  .sc-hero-icon { width: 48px; height: 48px; font-size: 20px; border-radius: 10px; }
  .sc-two-col { grid-template-columns: 1fr; }
}

/* ---- Artwork section ---- */
.sc-artwork-slots-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
}
.sc-artwork-slot {
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  padding: 10px;
  background: #fff;
  display: flex;
  align-items: center;
  gap: 10px;
  transition: border-color 0.15s;
}
.sc-artwork-slot:hover {
  border-color: #90cdf4;
}
.sc-artwork-slot-thumb {
  width: 48px;
  height: 48px;
  border-radius: 6px;
  background: #f7fafc;
  border: 1px solid #e2e8f0;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #a0aec0;
  font-size: 18px;
  flex-shrink: 0;
  overflow: hidden;
}
.sc-artwork-slot-thumb img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}
.sc-artwork-slot-info {
  flex: 1;
  min-width: 0;
}
.sc-artwork-slot-label {
  font-size: 12px;
  font-weight: 700;
  color: #2d3748;
  display: block;
  margin-bottom: 1px;
}
.sc-artwork-slot-dims {
  font-size: 10px;
  color: #a0aec0;
  display: block;
}
.sc-artwork-slot-actions {
  display: flex;
  gap: 4px;
  flex-shrink: 0;
}
.sc-artwork-slot-btn {
  padding: 4px 10px;
  font-size: 11px;
  font-weight: 600;
  border-radius: 5px;
  cursor: pointer;
  border: 1px solid #e2e8f0;
  background: #f7fafc;
  color: #4a5568;
  transition: background 0.12s, border-color 0.12s;
}
.sc-artwork-slot-btn:hover {
  background: #edf2f7;
  border-color: #cbd5e0;
}
.sc-artwork-slot-btn.sc-btn-clear {
  color: #e53e3e;
  border-color: #fed7d7;
  background: #fff5f5;
  display: none;
}
.sc-artwork-slot-btn.sc-btn-clear:hover {
  background: #fed7d7;
}
.sc-artwork-slot.sc-has-artwork .sc-btn-clear {
  display: inline-block;
}
.sc-artwork-link-row {
  display: flex;
  gap: 8px;
  margin-top: 12px;
  flex-wrap: wrap;
}
.sc-artwork-link-btn {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  padding: 6px 12px;
  font-size: 11px;
  font-weight: 600;
  border: 1px dashed #cbd5e0;
  border-radius: 6px;
  background: none;
  color: #718096;
  cursor: pointer;
  transition: background 0.12s, border-color 0.12s, color 0.12s;
}
.sc-artwork-link-btn:hover {
  background: #f7fafc;
  border-color: #a0aec0;
  color: #4a5568;
}
.sc-artwork-link-btn.sc-admin-btn {
  border-color: #fbd38d;
  color: #975a16;
}
.sc-artwork-link-btn.sc-admin-btn:hover {
  background: #fefcbf;
}

/* ---- Artwork Modal ---- */
.sc-artwork-modal {
  display: none;
  position: fixed;
  top: 0; left: 0; right: 0; bottom: 0;
  z-index: 10000;
  background: rgba(0,0,0,0.5);
  align-items: center;
  justify-content: center;
  padding: 20px;
}
.sc-artwork-modal.sc-modal-open {
  display: flex;
}
.sc-artwork-modal-content {
  background: #fff;
  border-radius: 12px;
  max-width: 720px;
  width: 100%;
  max-height: 85vh;
  overflow-y: auto;
  box-shadow: 0 20px 60px rgba(0,0,0,0.3);
}
.sc-artwork-modal-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 16px 20px;
  border-bottom: 1px solid #e2e8f0;
  position: sticky;
  top: 0;
  background: #fff;
  z-index: 1;
  border-radius: 12px 12px 0 0;
}
.sc-artwork-modal-header h3 {
  background: transparent;
  border: none;
  padding: 0;
  border-radius: 0;
  text-shadow: none;
  font-size: 16px;
  font-weight: 700;
  color: #2d3748;
  margin: 0;
}
.sc-artwork-modal-header h4 {
  background: transparent;
  border: none;
  padding: 0;
  border-radius: 0;
  text-shadow: none;
  font-size: 12px;
  font-weight: 400;
  color: #a0aec0;
  margin: 2px 0 0;
}
.sc-artwork-modal-close {
  background: none;
  border: none;
  font-size: 20px;
  color: #a0aec0;
  cursor: pointer;
  padding: 4px 8px;
  border-radius: 4px;
  transition: background 0.12s;
}
.sc-artwork-modal-close:hover {
  background: #f7fafc;
  color: #4a5568;
}
.sc-artwork-modal-body {
  padding: 20px;
}
.sc-artwork-modal-footer {
  padding: 12px 20px;
  border-top: 1px solid #e2e8f0;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

/* ---- Artwork Grid (browse) ---- */
.sc-artwork-search-bar {
  display: flex;
  gap: 8px;
  margin-bottom: 16px;
}
.sc-artwork-search-bar input {
  flex: 1;
  padding: 8px 12px;
  border: 1px solid #cbd5e0;
  border-radius: 6px;
  font-size: 13px;
  color: #2d3748;
  background: #fff;
}
.sc-artwork-search-bar input:focus {
  outline: none;
  border-color: #3182ce;
  box-shadow: 0 0 0 3px rgba(49, 130, 206, 0.12);
}
.sc-artwork-search-btn {
  padding: 8px 14px;
  font-size: 12px;
  font-weight: 600;
  border: 1px solid #cbd5e0;
  border-radius: 6px;
  background: #f7fafc;
  color: #4a5568;
  cursor: pointer;
}
.sc-artwork-search-btn:hover {
  background: #edf2f7;
}
.sc-artwork-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 12px;
  min-height: 120px;
}
.sc-artwork-thumb {
  border: 2px solid #e2e8f0;
  border-radius: 8px;
  overflow: hidden;
  cursor: pointer;
  transition: border-color 0.15s, box-shadow 0.15s, transform 0.1s;
  background: #fff;
}
.sc-artwork-thumb:hover {
  border-color: #90cdf4;
  box-shadow: 0 2px 8px rgba(66, 153, 225, 0.15);
  transform: translateY(-1px);
}
.sc-artwork-thumb.sc-selected {
  border-color: #3182ce;
  box-shadow: 0 0 0 3px rgba(49, 130, 206, 0.2);
}
.sc-artwork-thumb-img {
  width: 100%;
  aspect-ratio: 1;
  object-fit: cover;
  display: block;
  background: #f7fafc;
}
.sc-artwork-thumb-info {
  padding: 6px 8px;
  border-top: 1px solid #f0f0f0;
}
.sc-artwork-thumb-name {
  font-size: 11px;
  font-weight: 700;
  color: #2d3748;
  display: block;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.sc-artwork-thumb-artist {
  font-size: 10px;
  color: #a0aec0;
  display: block;
}
.sc-artwork-empty-state {
  grid-column: 1 / -1;
  text-align: center;
  padding: 40px 20px;
  color: #a0aec0;
  font-size: 13px;
}
.sc-artwork-empty-state i {
  display: block;
  font-size: 28px;
  margin-bottom: 8px;
  opacity: 0.5;
}
.sc-artwork-pagination {
  display: flex;
  justify-content: center;
  align-items: center;
  gap: 12px;
  margin-top: 16px;
  font-size: 12px;
  color: #718096;
}
.sc-artwork-pagination button {
  padding: 6px 14px;
  font-size: 12px;
  font-weight: 600;
  border: 1px solid #cbd5e0;
  border-radius: 5px;
  background: #fff;
  color: #4a5568;
  cursor: pointer;
}
.sc-artwork-pagination button:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}
.sc-artwork-pagination button:hover:not(:disabled) {
  background: #f7fafc;
}

/* ---- Upload form ---- */
.sc-artwork-upload-form .sc-field-group {
  margin-bottom: 12px;
}
.sc-artwork-upload-form .sc-field-group:last-child {
  margin-bottom: 0;
}
.sc-artwork-license {
  max-height: 140px;
  overflow-y: auto;
  padding: 12px 14px;
  font-size: 11px;
  line-height: 1.6;
  color: #4a5568;
  background: #f7fafc;
  border: 1px solid #e2e8f0;
  border-radius: 6px;
  margin-bottom: 12px;
  white-space: pre-wrap;
}
.sc-artwork-upload-submit {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 10px 20px;
  font-size: 13px;
  font-weight: 700;
  color: #fff;
  background: linear-gradient(135deg, #3182ce, #2b6cb0);
  border: none;
  border-radius: 6px;
  cursor: pointer;
  transition: background 0.2s;
}
.sc-artwork-upload-submit:hover {
  background: linear-gradient(135deg, #2b6cb0, #2c5282);
}
.sc-artwork-upload-submit:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
.sc-artwork-file-info {
  font-size: 11px;
  color: #718096;
  margin-top: 4px;
}

/* ---- Status badges ---- */
.sc-artwork-status-badge {
  display: inline-block;
  font-size: 10px;
  font-weight: 700;
  padding: 2px 8px;
  border-radius: 10px;
  text-transform: uppercase;
  letter-spacing: 0.03em;
}
.sc-artwork-status-badge.sc-status-pending {
  background: #fefcbf;
  color: #975a16;
}
.sc-artwork-status-badge.sc-status-approved {
  background: #c6f6d5;
  color: #276749;
}
.sc-artwork-status-badge.sc-status-rejected {
  background: #fed7d7;
  color: #9b2c2c;
}

/* ---- Admin panel (in modal) ---- */
.sc-artwork-admin-item {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  padding: 12px 0;
  border-bottom: 1px solid #f0f0f0;
}
.sc-artwork-admin-item:last-child {
  border-bottom: none;
}
.sc-artwork-admin-thumb {
  width: 64px;
  height: 64px;
  border-radius: 6px;
  border: 1px solid #e2e8f0;
  flex-shrink: 0;
  overflow: hidden;
  background: #f7fafc;
}
.sc-artwork-admin-thumb img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}
.sc-artwork-admin-info {
  flex: 1;
  min-width: 0;
}
.sc-artwork-admin-name {
  font-size: 13px;
  font-weight: 700;
  color: #2d3748;
}
.sc-artwork-admin-meta {
  font-size: 11px;
  color: #a0aec0;
  margin-top: 2px;
}
.sc-artwork-admin-actions {
  display: flex;
  gap: 6px;
  margin-top: 6px;
}
.sc-artwork-admin-actions button {
  padding: 4px 12px;
  font-size: 11px;
  font-weight: 600;
  border-radius: 5px;
  cursor: pointer;
  border: 1px solid;
  transition: background 0.12s;
}
.sc-btn-approve {
  background: #c6f6d5;
  border-color: #9ae6b4;
  color: #276749;
}
.sc-btn-approve:hover {
  background: #9ae6b4;
}
.sc-btn-reject {
  background: #fed7d7;
  border-color: #feb2b2;
  color: #9b2c2c;
}
.sc-btn-reject:hover {
  background: #feb2b2;
}
.sc-artwork-reject-input {
  margin-top: 6px;
  display: none;
}
.sc-artwork-reject-input.sc-visible {
  display: flex;
  gap: 6px;
}
.sc-artwork-reject-input input {
  flex: 1;
  padding: 5px 8px;
  font-size: 12px;
  border: 1px solid #cbd5e0;
  border-radius: 5px;
}
.sc-artwork-reject-input button {
  padding: 5px 10px;
  font-size: 11px;
  font-weight: 600;
  background: #e53e3e;
  color: #fff;
  border: none;
  border-radius: 5px;
  cursor: pointer;
}

/* ---- My Uploads item ---- */
.sc-artwork-my-item {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 0;
  border-bottom: 1px solid #f0f0f0;
}
.sc-artwork-my-item:last-child {
  border-bottom: none;
}
.sc-artwork-my-thumb {
  width: 48px;
  height: 48px;
  border-radius: 6px;
  border: 1px solid #e2e8f0;
  flex-shrink: 0;
  overflow: hidden;
  background: #f7fafc;
}
.sc-artwork-my-thumb img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}
.sc-artwork-my-info {
  flex: 1;
  min-width: 0;
}
.sc-artwork-my-name {
  font-size: 12px;
  font-weight: 700;
  color: #2d3748;
}
.sc-artwork-my-meta {
  font-size: 10px;
  color: #a0aec0;
}
.sc-artwork-my-delete {
  padding: 4px 10px;
  font-size: 11px;
  font-weight: 600;
  color: #e53e3e;
  background: #fff5f5;
  border: 1px solid #fed7d7;
  border-radius: 5px;
  cursor: pointer;
}
.sc-artwork-my-delete:hover {
  background: #fed7d7;
}

/* ---- Artwork checkbox / agreement ---- */
.sc-artwork-agree-row {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-top: 8px;
}
.sc-artwork-agree-row input[type="checkbox"] {
  width: 16px;
  height: 16px;
  accent-color: #3182ce;
}
.sc-artwork-agree-row label {
  font-size: 12px;
  color: #4a5568;
  font-weight: 600;
}

/* ---- Artwork modal tabs ---- */
.sc-artwork-tabs {
  display: flex;
  gap: 0;
  border-bottom: 2px solid #e2e8f0;
  margin-bottom: 16px;
}
.sc-artwork-tab {
  padding: 8px 16px;
  font-size: 12px;
  font-weight: 700;
  color: #718096;
  cursor: pointer;
  border-bottom: 2px solid transparent;
  margin-bottom: -2px;
  background: none;
  border-top: none;
  border-left: none;
  border-right: none;
  transition: color 0.12s, border-color 0.12s;
}
.sc-artwork-tab:hover {
  color: #4a5568;
}
.sc-artwork-tab.sc-active {
  color: #3182ce;
  border-bottom-color: #3182ce;
}
.sc-artwork-tab-content {
  display: none;
}
.sc-artwork-tab-content.sc-active {
  display: block;
}

/* ---- Loading spinner ---- */
.sc-artwork-loading {
  text-align: center;
  padding: 30px;
  color: #a0aec0;
}
.sc-artwork-loading i {
  font-size: 20px;
  margin-bottom: 8px;
  display: block;
}

@media (max-width: 768px) {
  .sc-artwork-slots-grid {
    grid-template-columns: 1fr;
  }
  .sc-artwork-grid {
    grid-template-columns: repeat(2, 1fr);
  }
  .sc-artwork-modal-content {
    max-width: 100%;
    max-height: 95vh;
  }
}

/* ============ In-builder artwork (sc2-art) ============ */
/* Overlay layer injected inside .sc2-scroll; captured by html2canvas/print */
.sc2-art-layer { position: absolute; inset: 0; pointer-events: none; }
.sc2-art-img   { position: absolute; display: block; width: 100%; height: 100%;
                 object-fit: fill; }
/* per-zone positioning is set inline from the % table (Task 2 markup is empty;
   JS injects positioned imgs). Keep this layer above sc2 content for capture. */
.sc2-scroll .sc2-art-layer { z-index: 40; }

/* Panel control section */
.sc2-art-panel { margin-top: 14px; }
.sc2-art-panel h3 { background: transparent; border: none; padding: 0; margin: 0 0 8px;
                    border-radius: 0; text-shadow: none; font-size: 14px; font-weight: 700; }
.sc2-art-zonegrid { display: grid; grid-template-columns: 1fr 1fr; gap: 6px; }
.sc2-art-zonebtn { display: flex; align-items: center; gap: 6px; justify-content: space-between;
                   padding: 6px 8px; border: 1px solid #cbd5e0; border-radius: 6px;
                   background: #f7fafc; color: #2d3748; font-size: 12px; cursor: pointer;
                   text-align: left; }
.sc2-art-zonebtn:hover { border-color: #5a67d8; background: rgba(90,103,216,.10); }
.sc2-art-zonebtn.has-img { border-color: #38a169; background: rgba(56,161,105,.10); }
.sc2-art-zonebtn .sc2-art-dot { width: 8px; height: 8px; border-radius: 50%;
                   background: #cbd5e0; flex: 0 0 auto; }
.sc2-art-zonebtn.has-img .sc2-art-dot { background: #38a169; }

/* Modal */
.sc2-art-modal { position: fixed; inset: 0; z-index: 9000; display: none;
                 align-items: center; justify-content: center; background: rgba(0,0,0,.55); }
.sc2-art-modal.is-open { display: flex; }
.sc2-art-dialog { background: #fff; color: #1a202c; width: min(640px, 94vw);
                  max-height: 92vh; overflow: auto; border-radius: 10px;
                  box-shadow: 0 18px 50px rgba(0,0,0,.4); }
.sc2-art-head { display: flex; align-items: center; justify-content: space-between;
                padding: 14px 18px; border-bottom: 1px solid #e2e8f0; }
.sc2-art-head h2 { background: transparent; border: none; padding: 0; margin: 0;
                   border-radius: 0; text-shadow: none; font-size: 17px; }
.sc2-art-close { background: none; border: none; font-size: 22px; line-height: 1;
                 cursor: pointer; color: #4a5568; }
.sc2-art-body { padding: 18px; }
.sc2-art-tabs { display: flex; gap: 6px; margin-bottom: 14px; }
.sc2-art-tab { flex: 1; padding: 8px; border: 1px solid #cbd5e0; background: #f7fafc;
               border-radius: 6px; cursor: pointer; font-size: 13px; font-weight: 600;
               color: #2d3748; }
.sc2-art-tab.is-active { background: #5a67d8; border-color: #5a67d8; color: #fff; }
.sc2-art-pane { display: none; }
.sc2-art-pane.is-active { display: block; }

/* Browse grid */
.sc2-art-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; }
.sc2-art-card { border: 1px solid #e2e8f0; border-radius: 6px; padding: 6px; cursor: pointer;
                background: #fff; text-align: center; }
.sc2-art-card:hover { border-color: #5a67d8; }
.sc2-art-card img { width: 100%; height: 86px; object-fit: contain; }
.sc2-art-card span { display: block; font-size: 11px; margin-top: 4px; color: #4a5568;
                     overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }

/* Upload form */
.sc2-art-field { margin-bottom: 12px; }
.sc2-art-field label { display: block; font-size: 12px; font-weight: 600; margin-bottom: 4px;
                       color: #2d3748; }
.sc2-art-field input[type=text], .sc2-art-field textarea, .sc2-art-field select {
                 width: 100%; padding: 7px 9px; border: 1px solid #cbd5e0; border-radius: 6px;
                 font-size: 13px; box-sizing: border-box; }
.sc2-art-preview { max-width: 100%; max-height: 180px; display: none; margin: 8px 0;
                   border: 1px solid #e2e8f0; border-radius: 6px; }
.sc2-art-share { margin-top: 10px; padding-top: 10px; border-top: 1px dashed #cbd5e0; }
.sc2-art-share-reveal { display: none; margin-top: 10px; }
.sc2-art-share-reveal.is-open { display: block; }
/* Amtgard|Kingdom toggle */
.sc2-art-tier { display: inline-flex; border: 1px solid #cbd5e0; border-radius: 999px;
                overflow: hidden; }
.sc2-art-tier button { border: none; background: #f7fafc; color: #2d3748; padding: 6px 16px;
                       font-size: 12px; font-weight: 600; cursor: pointer; }
.sc2-art-tier button.is-active { background: #5a67d8; color: #fff; }
.sc2-art-license { font-size: 11px; line-height: 1.45; max-height: 120px; overflow: auto;
                   background: #f7fafc; border: 1px solid #e2e8f0; border-radius: 6px;
                   padding: 8px; margin: 8px 0; color: #2d3748; }
.sc2-art-foot { display: flex; align-items: center; justify-content: space-between;
                gap: 10px; padding: 14px 18px; border-top: 1px solid #e2e8f0; }
.sc2-art-status { font-size: 12px; }
.sc2-art-status.warn { color: #c05621; }
.sc2-art-status.err  { color: #c53030; }
.sc2-art-status.ok   { color: #2f855a; }
.sc2-art-btn { padding: 8px 16px; border-radius: 6px; border: 1px solid #5a67d8;
               background: #5a67d8; color: #fff; font-size: 13px; font-weight: 600;
               cursor: pointer; }
.sc2-art-btn[disabled] { opacity: .5; cursor: not-allowed; }
.sc2-art-btn.ghost { background: #fff; color: #4a5568; border-color: #cbd5e0; }

/* Dark mode */
html[data-theme="dark"] .sc2-art-zonebtn { background: #2d3748; border-color: #4a5568; color: #e2e8f0; }
html[data-theme="dark"] .sc2-art-zonebtn:hover { background: rgba(129,140,248,.18); border-color: #818cf8; }
html[data-theme="dark"] .sc2-art-zonebtn.has-img { background: rgba(56,161,105,.20); border-color: #38a169; }
html[data-theme="dark"] .sc2-art-dialog { background: #1a202c; color: #e2e8f0; }
html[data-theme="dark"] .sc2-art-head,
html[data-theme="dark"] .sc2-art-foot { border-color: #2d3748; }
html[data-theme="dark"] .sc2-art-head h2,
html[data-theme="dark"] .sc2-art-panel h3 { color: #e2e8f0; }
html[data-theme="dark"] .sc2-art-close { color: #a0aec0; }
html[data-theme="dark"] .sc2-art-tab,
html[data-theme="dark"] .sc2-art-tier button { background: #2d3748; border-color: #4a5568; color: #e2e8f0; }
html[data-theme="dark"] .sc2-art-tab.is-active,
html[data-theme="dark"] .sc2-art-tier button.is-active { background: #5a67d8; border-color: #5a67d8; color: #fff; }
html[data-theme="dark"] .sc2-art-card { background: #2d3748; border-color: #4a5568; }
html[data-theme="dark"] .sc2-art-card span { color: #a0aec0; }
html[data-theme="dark"] .sc2-art-field label { color: #e2e8f0; }
html[data-theme="dark"] .sc2-art-field input[type=text],
html[data-theme="dark"] .sc2-art-field textarea,
html[data-theme="dark"] .sc2-art-field select { background: #2d3748; border-color: #4a5568; color: #e2e8f0; }
html[data-theme="dark"] .sc2-art-license { background: #2d3748; border-color: #4a5568; color: #cbd5e0; }
html[data-theme="dark"] .sc2-art-btn.ghost { background: #2d3748; color: #e2e8f0; border-color: #4a5568; }
html[data-theme="dark"] .sc2-art-preview { border-color: #4a5568; }
html[data-theme="dark"] .sc2-art-share { border-color: #4a5568; }

/* ================================================================
   Style Family picker (Plan 1 redesign)
   ================================================================ */
.sc-section-family { border: 1px solid rgba(212, 175, 55, 0.4); border-radius: 6px; padding: 12px 14px; margin-bottom: 14px; background: linear-gradient(135deg, rgba(212,175,55,0.06), rgba(212,175,55,0)); }
.sc-family-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 10px; margin-top: 8px; }
.sc-family-card { border: 1px solid rgba(0,0,0,0.18); border-radius: 6px; cursor: pointer; overflow: hidden; transition: border-color 0.15s, transform 0.15s, box-shadow 0.15s; background: #fff; }
.sc-family-card:hover { transform: translateY(-1px); box-shadow: 0 3px 10px rgba(0,0,0,0.15); }
.sc-family-card.sc-selected { border-color: #d4af37; box-shadow: 0 0 0 2px #d4af37; }
.sc-family-preview { padding: 14px 12px; min-height: 70px; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 6px; }
.sc-family-title-sample { font-size: 18px; line-height: 1; text-align: center; }
.sc-family-swatches { display: flex; gap: 3px; }
.sc-family-swatches span { display: inline-block; width: 14px; height: 14px; border-radius: 2px; border: 1px solid rgba(0,0,0,0.18); }
.sc-family-meta { padding: 6px 10px; background: #f7f5ed; font-size: 12px; line-height: 1.3; }
.sc-family-meta strong { display: block; }
.sc-family-meta em { font-size: 10px; opacity: 0.65; font-style: normal; text-transform: uppercase; letter-spacing: 0.4px; }
html[data-theme="dark"] .sc-family-card { background: #1f1f1f; border-color: #444; }
html[data-theme="dark"] .sc-family-meta { background: #2a2a2a; color: #ddd; }
html[data-theme="dark"] .sc-family-card:hover { border-color: #888; }

/* Family preview canvas (right column, separate from legacy template canvas) */
.sc-family-preview-wrap { position: relative; margin: 14px 0; padding: 12px; background: #f5f1e6; border: 1px solid #d4af37; border-radius: 6px; }
.sc-family-preview-wrap h4 { margin: 0 0 8px; font-size: 13px; color: #5a4a0f; }
.sc-family-preview-wrap canvas { display: block; max-width: 100%; height: auto; border: 1px solid rgba(0,0,0,0.1); }
.sc-family-download-btn { display: inline-flex; align-items: center; gap: 6px; margin-top: 10px; padding: 8px 14px; background: #d4af37; color: #1a1a1a; border: none; border-radius: 4px; font-weight: 600; cursor: pointer; transition: background 0.15s; }
.sc-family-download-btn:hover { background: #b8961f; }
html[data-theme="dark"] .sc-family-preview-wrap { background: #2a2820; border-color: #d4af37; }
html[data-theme="dark"] .sc-family-preview-wrap h4 { color: #d4af37; }
</style>
<style id="sf-forge-styles">
/* ===== inlined: sf-tokens.css.part ===== */
/* ============================================================================
   THE LETTERED SCROLL — sf-tokens.css.part
   ----------------------------------------------------------------------------
   SINGLE SOURCE OF TRUTH for every CSS custom-property NAME used by the
   HTML/CSS/inline-SVG scroll renderer ("scroll-forge"). Every other partial
   (substrate, illumination, typography, heraldry/seal, print, families)
   references these names VERBATIM — no ad-hoc hex in component CSS except
   inside SVG <stop> definitions, which must still pull the same hue values.

   MEDIUM IS LOCKED: semantic HTML + CSS + inline SVG. No <canvas>, no tiled
   photo textures, no flat #ffd700, no pure #fff substrate.

   SCOPING CONTRACT (locked):
     • ALL palette / font / motif tokens are scoped to `.sc2-scroll` so the
       app's dark-mode theme can NEVER bleed into the vellum. The scroll always
       renders on its own light substrate regardless of `[data-theme]`.
     • The Google Fonts @import lives at the very top of THIS file (CSS spec:
       @import must precede all other rules) so the whole fleet shares one
       font request.
     • Per-family overrides live ONLY in `.sc2-scroll[data-family="<key>"]`
       blocks at the bottom of this file and RE-SET ONLY: the substrate trio,
       --ink-muted / --rubric (if shifted), the --gold* ramp, --border,
       --rule-fine, --initial-ground, --wax*, --ribbon-*, --escutcheon,
       --ff-title, and the --motif data hook. They MUST NOT touch z-index,
       layout, spacing, shadow helpers, or motion tokens.
     • `.sc2-export` and `@media print` may flatten texture/gilt tokens but
       NOTHING structural.

   The DEFAULT block below = the CRIMSON DECREE baseline (safe, neutral,
   warm parchment). Crimson Decree therefore needs no per-family override.
   ============================================================================ */

/* ── GOOGLE FONTS — one combined request for the whole renderer ───────────────
   Display faces (TITLES ONLY — blackletter/uncial are unreadable at body size):
     UnifrakturMaguntia, UnifrakturCook, Pirata One, Grenze Gotisch,
     MedievalSharp, Uncial Antiqua.
   Body / humanist / chancery / small-caps:
     EB Garamond (real bolds + italic), Cardo, IM Fell English (+SC + italic),
     Gentium Book Plus.
   SINGLE-WEIGHT TRAP (locked): UnifrakturMaguntia, UnifrakturCook, Pirata One,
   MedievalSharp, Uncial Antiqua are 400-ONLY — never request :wght@700 for
   them (silent Times fallback). Only Grenze Gotisch / EB Garamond / Cardo /
   Gentium Book Plus carry true bolds, requested below.                       */
@import url("https://fonts.googleapis.com/css2?family=Cardo:ital,wght@0,400;0,700;1,400&family=EB+Garamond:ital,wght@0,400;0,500;0,600;0,700;0,800;1,400;1,500;1,600&family=Gentium+Book+Plus:ital,wght@0,400;0,700;1,400;1,700&family=Grenze+Gotisch:wght@100;300;400;500;700;900&family=IM+Fell+English:ital@0;1&family=IM+Fell+English+SC&family=MedievalSharp&family=Pirata+One&family=Unifraktur+Cook:wght@700&family=UnifrakturMaguntia&family=Uncial+Antiqua&display=swap");

/* ============================================================================
   DEFAULT TOKEN SET  ·  baseline = CRIMSON DECREE
   Scoped to .sc2-scroll so dark-mode app chrome cannot reach the vellum.
   ============================================================================ */
.sc2-scroll {

  /* ── SUBSTRATE / VELLUM ──────────────────────────────────────────────── */
  --vellum:            #f4e8c8;   /* base parchment body                       */
  --vellum-hi:         #faf0d6;   /* lightest center (radial top-50%)          */
  --vellum-lo:         #ddc593;   /* aged edge                                 */
  --grime:             rgba(74,52,24,.35);   /* edge-grime vignette            */
  --foxing:            #b58f5b;   /* stain / foxing blobs (used 8–18% alpha)   */
  --ruling:            #9a8f78;   /* faint ruling + pricking lines             */
  --curl-shadow:       rgba(60,40,15,.35);   /* cast shadow under rolled curl  */

  /* ── INK ─────────────────────────────────────────────────────────────── */
  --ink:               #2a211a;   /* warm sepia body ink — NEVER #000          */
  --ink-muted:         #5c4632;   /* labels, intitulation, signature titles    */
  --rubric:            #7b1f2a;   /* vermilion: recipient name + notif opener  */

  /* ── GILDING (raised gold — always the gradient recipe, never flat) ────── */
  --gold:              #d4af37;   /* mid body gold                             */
  --gold-hi:           #fff4c2;   /* specular hotspot                          */
  --gold-deep:         #a9760a;   /* lower gold shade                          */
  --gold-shadow:       #6e4d08;   /* darkest gold stop                         */
  --gold-keyline:      #5a3d0c;   /* thin dark recess line — sells "raised"    */

  /* ── BORDER / FRAME ──────────────────────────────────────────────────── */
  --border:            #7b1f2a;   /* bar-border colour (family field colour)   */
  --rule-fine:         #6b4f2a;   /* hairline outer rule (brown ink)           */
  --initial-ground:    #6b1f2a;   /* drop-cap decorated-box ground             */

  /* ── ACCENT (secondary motif / filigree / cartouche tint) ──────────────
     Distinct from --border so families can carry a 2-colour scheme without
     re-purposing the field colour. Defaults to the gold mid-tone.           */
  --accent:            #b8862b;   /* secondary ornament accent                 */
  --accent-soft:       rgba(184,134,43,.28);  /* washed accent (filigree fill) */

  /* ── WAX SEAL ────────────────────────────────────────────────────────── */
  --wax:               #8c1d1b;   /* wax body (red = decree default)           */
  --wax-hi:            #c0392b;   /* upper-left catch-light                     */
  --wax-lo:            #5a0f0f;   /* pooled center / rim                        */
  --ribbon-a:          #7b1f2a;   /* livery colour ribbon tail                 */
  --ribbon-b:          #d4af37;   /* livery metal ribbon tail                  */

  /* ── HERALDRY ────────────────────────────────────────────────────────── */
  --escutcheon:        heater;    /* informational hook: clipPath id by family */
  --arms-rim:          var(--gold);
  --arms-keyline:      #3a2a12;

  /* ── TYPOGRAPHY — font stacks (families override --ff-title only) ───────
     ALWAYS carry serif fallbacks. Blackletter = TITLES ONLY.               */
  --ff-title:          "UnifrakturMaguntia","UnifrakturCook","Pirata One","Times New Roman",serif;
  --ff-title-grim:     "Grenze Gotisch","UnifrakturCook",serif;
  --ff-title-uncial:   "Uncial Antiqua","MedievalSharp",serif;
  --ff-title-rough:    "MedievalSharp","Uncial Antiqua",serif;
  --ff-title-press:    "Pirata One","UnifrakturCook","Times New Roman",serif;
  --ff-body:           "EB Garamond","Cardo","IM Fell English",Garamond,Georgia,serif;
  --ff-body-press:     "IM Fell English","EB Garamond",Georgia,serif;
  --ff-body-alt:       "Gentium Book Plus","Cardo","EB Garamond",Georgia,serif;
  --ff-smallcaps:      "IM Fell English SC","Cardo","EB Garamond",serif;
  --ff-sign:           "EB Garamond","Cardo","IM Fell English",serif;  /* render italic */
  --ff-versal:         "UnifrakturMaguntia","EB Garamond",serif;

  /* ── TYPE SCALE (clamped — fluid screen → print) ───────────────────────
     Centralised so typography partial never hard-codes sizes.             */
  --fs-invocation:     .95rem;
  --fs-title:          clamp(40px, 6vw, 84px);
  --fs-intitulation:   1rem;
  --fs-body:           clamp(15px, 1.15vw, 18px);
  --fs-grant:          clamp(17px, 1.4vw, 22px);
  --fs-datum:          1rem;
  --fs-attest:         clamp(1.2rem, 1.6vw, 1.35rem);
  --fs-versal:         4.2em;     /* float-fallback drop-cap size (≈3 lines)   */

  --ls-title:          .01em;     /* NEVER track blackletter wide              */
  --ls-intitulation:   .14em;     /* real small-caps tracking                  */
  --ls-invocation:     .06em;

  /* ── LAYOUT / GEOMETRY ─────────────────────────────────────────────────
     Portrait by default; landscape families flip --aspect to 11 / 8.5.    */
  --sheet-w:           min(760px, 92vw);
  --aspect:            8.5 / 11;
  --margin-frame:      7.5%;       /* sheet-edge → content inset                */
  --band-w:            40px;       /* decorated band width                      */
  --bar-w:             10px;       /* bar-border width                          */
  --rule-w:            .75px;      /* fine outer rule weight                    */
  --content-pad:       calc(var(--margin-frame) + var(--band-w));
  --corner-size:       72px;       /* corner-piece ornament footprint           */
  --curl-h:            28px;       /* rolled-curl strip height (ornate only)    */
  --deckle-rx:         6px;        /* deckle base rect corner radius            */

  /* ── VERTICAL RHYTHM / SPACING ─────────────────────────────────────────
     --line doubles as the ruling interval (substrate engineer reads it).   */
  --line:              1.62;
  --gap-section:       1.4rem;     /* between document parts                    */
  --gap-tight:         .65rem;
  --gap-loose:         2.2rem;
  --basdepage-extra:   1lh;        /* +1 line breathing room in the seal zone   */
  --title-optical-nudge: -2%;      /* optically centre the title block up ~2%   */

  /* ── SHADOW / DEPTH HELPERS ────────────────────────────────────────────
     Reusable composites so engineers never re-derive raised-gold shadows.  */
  --sheet-shadow:      0 18px 48px rgba(20,12,4,.45), 0 2px 6px rgba(20,12,4,.30);
  --shadow-emboss:     inset 0 1px 0 rgba(255,250,220,.65),
                       inset 0 -1px 1px rgba(60,40,10,.50);
  --gild-shadow:       0 0 0 .75px var(--gold-keyline);
  --gild-drop:         drop-shadow(0 1px 1px rgba(60,40,5,.50));
  --gild-text-drop:    drop-shadow(0 1px 0 var(--gold-hi))
                       drop-shadow(0 2px 2px rgba(40,20,0,.35));
  --rubric-shadow:     0 1px 0 rgba(255,250,235,.45);
  --seal-shadow:       0 6px 14px rgba(20,8,4,.45), 0 1px 2px rgba(20,8,4,.55);

  /* ── GILDING RECIPES (composite tokens — apply verbatim) ───────────────
     Gold is ALWAYS this gradient on any meaningful surface; never a flat
     var(--gold) fill on a large area.                                      */
  --gild-gradient:     linear-gradient(135deg,
                         var(--gold-shadow) 0%,
                         var(--gold)        18%,
                         var(--gold-hi)     38%,
                         var(--gold)        58%,
                         var(--gold-deep)   82%,
                         var(--gold-shadow) 100%);
  --gild-fill-shadow:  var(--shadow-emboss), var(--gild-shadow);
  --gild-text-stroke:  .75px var(--gold-keyline);

  /* ── MOTIF DATA HOOK ───────────────────────────────────────────────────
     String name read by the illumination engine to select the inline-SVG
     <pattern>/<path> motif. Families override this only.                   */
  --motif:             "decree-fleur";

  /* ── Z-INDEX (LOCKED STACK — families MUST NOT touch) ──────────────────
     All layers absolutely positioned inside .sc2-scroll (position:relative).
     Text NEVER sits under the band: .sc2-content padding ≥ --content-pad.  */
  --z-vellum:          0;   /* base + mottle + foxing                         */
  --z-ruling:          1;   /* faint ruling / pricking                        */
  --z-illum:           2;   /* border bands / corners                         */
  --z-edge:            3;   /* deckle mask on .sc2-scroll; vignette ::after   */
  --z-content:         4;   /* all text                                       */
  --z-crown:           5;   /* heraldry achievement                           */
  --z-seal:            6;   /* pendant wax seal                               */

  /* ── MOTION (LOCKED — families MUST NOT touch) ─────────────────────────── */
  --t-family:          240ms ease;                       /* recolour cross-fade */
  --t-seal:            320ms cubic-bezier(.2,.8,.2,1);   /* seal press          */
}

/* ============================================================================
   PER-FAMILY PALETTE HOOKS
   ----------------------------------------------------------------------------
   Each block RE-SETS ONLY palette / font / motif / escutcheon tokens.
   NO z-index, layout, spacing, shadow, or motion overrides here.
   The 10 family keys match the scroll-forge family-*.css.part files and the
   controller's family identities.
   ============================================================================ */

/* 1 · HIBERNIAN KNOTWORK — Insular vellum, false-gold/orpiment, Celtic interlace.
   Insular gold is intentionally cooler/greener "false gold" (orpiment). */
.sc2-scroll[data-family="hibernian_knotwork"] {
  --vellum:          #efe3c2;
  --vellum-hi:       #f7ecce;
  --vellum-lo:       #d2bb86;
  --foxing:          #a8895a;
  --ink:             #28231a;
  --ink-muted:       #4f4226;
  --rubric:          #8a2417;          /* insular red-lead */
  --gold:            #c9a227;          /* orpiment false-gold */
  --gold-hi:         #f3e08a;
  --gold-deep:       #94701a;
  --gold-shadow:     #5e4708;
  --gold-keyline:    #4a380a;
  --border:          #2f5d4a;          /* insular green field */
  --rule-fine:       #4a3c1c;
  --initial-ground:  #234d3c;          /* deep verdigris ground */
  --accent:          #b23a1f;          /* red-lead accent */
  --accent-soft:     rgba(178,58,31,.26);
  --wax:             #2f5d4a;
  --wax-hi:          #4f8a6f;
  --wax-lo:          #173024;
  --ribbon-a:        #2f5d4a;
  --ribbon-b:        #c9a227;
  --escutcheon:      heater;
  --ff-title:        var(--ff-title-uncial);
  --motif:           "celtic-interlace";
}

/* 2 · NORTHERN GOTHIC — cold grey-ivory vellum, steel gilt, Gothic tracery. */
.sc2-scroll[data-family="northern_gothic"] {
  --vellum:          #ece6d3;
  --vellum-hi:       #f5f0e0;
  --vellum-lo:       #cdc3a6;
  --grime:           rgba(40,44,52,.34);
  --foxing:          #9aa0a2;
  --ink:             #20242a;
  --ink-muted:       #45474c;
  --rubric:          #6e1622;          /* dark gothic red */
  --gold:            #c2a85a;          /* cool steel-gilt */
  --gold-hi:         #efe2a8;
  --gold-deep:       #8f7626;
  --gold-shadow:     #5b4a13;
  --gold-keyline:    #3c310e;
  --border:          #2b3340;          /* slate field */
  --rule-fine:       #3a3f48;
  --initial-ground:  #1f2a3a;          /* lapis-slate ground */
  --accent:          #5a6a7d;
  --accent-soft:     rgba(90,106,125,.28);
  --wax:             #2b3340;
  --wax-hi:          #4a576b;
  --wax-lo:          #161b22;
  --ribbon-a:        #2b3340;
  --ribbon-b:        #c2a85a;
  --escutcheon:      heater;
  --ff-title:        var(--ff-title-grim);
  --motif:           "gothic-tracery";
}

/* 3 · PROVENÇAL BESTIARY — warm honey vellum, bright gold, foliate rinceaux + drolleries. */
.sc2-scroll[data-family="provencal_bestiary"] {
  --vellum:          #f6ead0;
  --vellum-hi:       #fbf2dc;
  --vellum-lo:       #e2cb98;
  --foxing:          #c09760;
  --ink:             #2e2418;
  --ink-muted:       #5f4a2c;
  --rubric:          #9a2b22;          /* bestiary vermilion */
  --gold:            #d8b23e;
  --gold-hi:         #fff0bf;
  --gold-deep:       #ad7e10;
  --gold-shadow:     #71520a;
  --gold-keyline:    #5a3d0c;
  --border:          #3a6b4c;          /* foliage green */
  --rule-fine:       #5a431f;
  --initial-ground:  #1f4f8a;          /* lapis ground */
  --accent:          #b8472b;
  --accent-soft:     rgba(184,71,43,.26);
  --wax:             #3a6b4c;
  --wax-hi:          #5e9a73;
  --wax-lo:          #1f3a28;
  --ribbon-a:        #9a2b22;
  --ribbon-b:        #d8b23e;
  --escutcheon:      heater;
  --ff-title:        var(--ff-title);
  --motif:           "foliate-rinceaux";
}

/* 4 · CRIMSON DECREE — baseline (defaults above). Block kept for symmetry/explicitness. */
.sc2-scroll[data-family="crimson_decree"] {
  --border:          #7b1f2a;
  --initial-ground:  #6b1f2a;
  --wax:             #8c1d1b;
  --ribbon-a:        #7b1f2a;
  --ribbon-b:        #d4af37;
  --escutcheon:      heater;
  --ff-title:        var(--ff-title);
  --motif:           "decree-fleur";
}

/* 5 · FOREST REVERIE — fae charter, soft moss vellum, mossy gold, vine/leaf interlace, vesica arms. */
.sc2-scroll[data-family="forest_reverie"] {
  --vellum:          #eef0d6;
  --vellum-hi:       #f6f7e4;
  --vellum-lo:       #cdd2a6;
  --grime:           rgba(40,56,28,.30);
  --foxing:          #9bab6a;
  --ink:             #24301f;
  --ink-muted:       #46532f;
  --rubric:          #7a3b1f;          /* bark-russet rubric */
  --gold:            #c7b24a;          /* mossy gold */
  --gold-hi:         #efe7a0;
  --gold-deep:       #8f7c1e;
  --gold-shadow:     #5a4d10;
  --gold-keyline:    #3c340c;
  --border:          #3c6b3a;          /* forest green field */
  --rule-fine:       #4a5530;
  --initial-ground:  #2f5a36;          /* deep moss ground */
  --accent:          #7a8f3c;
  --accent-soft:     rgba(122,143,60,.28);
  --wax:             #3c6b3a;
  --wax-hi:          #5f9a55;
  --wax-lo:          #1f3a20;
  --ribbon-a:        #3c6b3a;
  --ribbon-b:        #c7b24a;
  --escutcheon:      vesica;           /* fae → pointed-oval arms */
  --ff-title:        var(--ff-title-rough);
  --motif:           "vine-interlace";
}

/* 6 · CHARRED EDICT — scorched vellum, ember rubric, smoke-stained, ash accents. */
.sc2-scroll[data-family="charred_edict"] {
  --vellum:          #d9c39a;          /* darker, smoke-tinged body */
  --vellum-hi:       #e7d4ab;
  --vellum-lo:       #9c7c4d;
  --grime:           rgba(28,18,10,.55);
  --foxing:          #6e4a26;
  --ink:             #221812;
  --ink-muted:       #4a3320;
  --rubric:          #b5341a;          /* ember red */
  --gold:            #c89a3a;          /* tarnished gold */
  --gold-hi:         #ecd089;
  --gold-deep:       #8a6210;
  --gold-shadow:     #4e3608;
  --gold-keyline:    #2e1f08;
  --border:          #3a221a;          /* charred brown field */
  --rule-fine:       #3a2616;
  --initial-ground:  #5a1f12;          /* burnt-sienna ground */
  --accent:          #d4541f;          /* ember accent */
  --accent-soft:     rgba(212,84,31,.30);
  --wax:             #3a221a;
  --wax-hi:          #7a4a2a;
  --wax-lo:          #1a0f0a;
  --ribbon-a:        #b5341a;
  --ribbon-b:        #c89a3a;
  --escutcheon:      heater;
  --ff-title:        var(--ff-title-rough);
  --motif:           "ember-scroll";
}

/* 7 · IMPERIAL EDICT — regal purple field, full burnished gold, acanthus, crown-the-title. */
.sc2-scroll[data-family="imperial_edict"] {
  --vellum:          #f4e9cc;
  --vellum-hi:       #fbf2da;
  --vellum-lo:       #ddc792;
  --foxing:          #b8945c;
  --ink:             #281f17;
  --ink-muted:       #534029;
  --rubric:          #7a1f3a;          /* imperial carmine */
  --gold:            #dcb63c;          /* burnished imperial gold */
  --gold-hi:         #fff3bd;
  --gold-deep:       #b07c12;
  --gold-shadow:     #74540a;
  --gold-keyline:    #5a3d0c;
  --border:          #4a2370;          /* tyrian purple field */
  --rule-fine:       #5a431f;
  --initial-ground:  #3a1a5c;          /* royal purple ground */
  --accent:          #6a3aa0;
  --accent-soft:     rgba(106,58,160,.26);
  --wax:             #4a2370;
  --wax-hi:          #7a4aa8;
  --wax-lo:          #281240;
  --ribbon-a:        #4a2370;
  --ribbon-b:        #dcb63c;
  --escutcheon:      heater;
  --ff-title:        var(--ff-title);
  --motif:           "imperial-acanthus";
}

/* 8 · SCHOLAR'S HAND — scholarly diploma, clean cream vellum, restrained gold,
   chancery hand, vesica seal of the academy. Quietest ornament of the set. */
.sc2-scroll[data-family="scholars_hand"] {
  --vellum:          #f3ecd8;
  --vellum-hi:       #faf4e3;
  --vellum-lo:       #ddd0ab;
  --foxing:          #b9a677;
  --ink:             #2b2419;
  --ink-muted:       #564a35;
  --rubric:          #6a3520;          /* sober sienna rubric */
  --gold:            #c9aa55;          /* restrained gilt */
  --gold-hi:         #efe2a6;
  --gold-deep:       #957521;
  --gold-shadow:     #5e4910;
  --gold-keyline:    #463509;
  --border:          #3a4a5e;          /* ink-blue field */
  --rule-fine:       #4a3c24;
  --initial-ground:  #2c3e54;          /* academic blue ground */
  --accent:          #7a6a45;
  --accent-soft:     rgba(122,106,69,.26);
  --wax:             #3a4a5e;
  --wax-hi:          #5e7088;
  --wax-lo:          #1e2a38;
  --ribbon-a:        #3a4a5e;
  --ribbon-b:        #c9aa55;
  --escutcheon:      vesica;           /* academy → vesica seal */
  --ff-title:        var(--ff-title-uncial);
  --motif:           "scholar-rule";
}

/* 9 · CRUSADER'S CHARTER — ecclesiastic charter, bleached vellum, cross-and-fleur,
   vesica ecclesiastic arms, sealing-wax green-on-gold. */
.sc2-scroll[data-family="crusaders_charter"] {
  --vellum:          #f1e8d0;
  --vellum-hi:       #f9f1da;
  --vellum-lo:       #d8c99e;
  --foxing:          #b09063;
  --ink:             #29231a;
  --ink-muted:       #524431;
  --rubric:          #8e1f24;          /* ecclesiastic red */
  --gold:            #d2b246;
  --gold-hi:         #f6ea9e;
  --gold-deep:       #a17c16;
  --gold-shadow:     #6a4f0c;
  --gold-keyline:    #4e3a0a;
  --border:          #8e1f24;          /* crusader cross-red field */
  --rule-fine:       #5a431f;
  --initial-ground:  #6a1418;          /* deep crimson ground */
  --accent:          #2f5a4a;          /* ecclesiastic green accent */
  --accent-soft:     rgba(47,90,74,.26);
  --wax:             #2f5a4a;
  --wax-hi:          #4f8a72;
  --wax-lo:          #173026;
  --ribbon-a:        #8e1f24;
  --ribbon-b:        #d2b246;
  --escutcheon:      vesica;           /* ecclesiastic → vesica arms */
  --ff-title:        var(--ff-title);
  --motif:           "cross-fleur";
}

/* 10 · ASTRAL CODEX — INVERTED substrate: deep night-blue "vellum", silver/gold
   star-grain, constellation tracery. The mottle becomes faint star-grain
   (substrate engineer reads --motif + the dark substrate trio). Rubrics shift
   to a luminous gold against the dark ground; ink lightens to bone. */
.sc2-scroll[data-family="astral_codex"] {
  --vellum:          #161a2e;          /* night-blue ground (inverted) */
  --vellum-hi:       #232a45;          /* lighter centre glow */
  --vellum-lo:       #0c0f1e;          /* deepest edge */
  --grime:           rgba(4,6,16,.55);
  --foxing:          #2a335a;          /* nebular mottle (cool) */
  --ruling:          #3a4470;          /* faint celestial ruling */
  --curl-shadow:     rgba(0,0,0,.55);
  --ink:             #e8e3d2;          /* bone ink on dark ground */
  --ink-muted:       #b3aecb;
  --rubric:          #e6c45a;          /* luminous gold rubric */
  --gold:            #e0c558;          /* bright celestial gold */
  --gold-hi:         #fff6cf;
  --gold-deep:       #ad8c1e;
  --gold-shadow:     #6e5510;
  --gold-keyline:    #2a200a;
  --border:          #1e2647;          /* deep indigo field */
  --rule-fine:       #c9b46a;          /* gilt rule reads on dark */
  --initial-ground:  #2a1e58;          /* amethyst ground */
  --accent:          #8a93e0;          /* starlight blue accent */
  --accent-soft:     rgba(138,147,224,.30);
  --wax:             #2a1e58;          /* amethyst wax */
  --wax-hi:          #5a4aa0;
  --wax-lo:          #150c30;
  --ribbon-a:        #2a1e58;
  --ribbon-b:        #e0c558;
  --escutcheon:      heater;
  --ff-title:        var(--ff-title-uncial);
  --motif:           "constellation-tracery";
}

/* ============================================================================
   EXPORT / PRINT TOKEN FLATTENING (texture/gilt only — never structural)
   ----------------------------------------------------------------------------
   background-clip:text + feDisplacementMap masks degrade in html2canvas and
   some PDF engines. The substrate / illumination / print partials read these
   flags & flattened equivalents; the names are declared here so they stay in
   ONE place. Actual rule application lives in sf-print.css.part.
   ============================================================================ */
.sc2-scroll.sc2-export,
@media print {
  .sc2-scroll {
    --deckle-mode:     baked;        /* swap feDisplacement mask → baked path  */
    --gild-text-mode:  flat;         /* gilt text → solid --gold + text-shadow */
    --gild-text-flat:  var(--gold);
    --gild-text-flat-shadow: 0 1px 0 var(--gold-keyline);
    --sheet-shadow:    none;         /* no drop shadow on the printed sheet     */
  }
}

/* ===== inlined: sf-substrate.css.part ===== */
/* ============================================================================
   THE LETTERED SCROLL — sf-substrate.css.part
   ----------------------------------------------------------------------------
   THE VELLUM / PARCHMENT SUBSTRATE. This is the bottom of the scroll's
   z-stack: the physical sheet itself — its warm body colour, its uneven
   aging, its fibrous skin, its stains and foxing, its grime-darkened edges,
   its torn deckle outline, and (at the highest intensity) the curled top &
   bottom of a rolled sheet.

   MEDIUM IS LOCKED: pure CSS + inline SVG filters. No <canvas>. No tiled
   photo textures (one inline-SVG feTurbulence data-URI is the ONLY raster-ish
   source, and it is generated, not a JPEG). Never #fff — the lightest the
   sheet ever gets is var(--vellum-hi).

   CONSUMES (defined in sf-tokens.css.part — never redeclared here):
     --vellum --vellum-hi --vellum-lo   substrate colour trio
     --grime                            edge-grime vignette colour (rgba)
     --foxing                           stain / foxing blob hue
     --ruling                           faint ruling + pricking line colour
     --curl-shadow                      cast shadow under a rolled curl
     --z-vellum --z-ruling --z-edge     z-index contract (0 / 1 / 3)
     --margin-frame                     inner content inset (for ruling rhythm)

   Families re-tint ONLY the trio + --foxing + --grime + --ruling via
   .sc2-scroll[data-family="…"] blocks in the tokens partial; this partial is
   family-agnostic and reads whatever those tokens resolve to. Astral Codex
   (dark substrate) therefore works with zero changes here — its mottle just
   reads as faint star-grain because its tokens invert.

   DEFENSIVE: every layer is an aria-hidden decorative element. If the markup
   omits .sc2-vellum / .sc2-edge / .sc2-ruling the sheet still shows a sane
   base (a fallback background is set on .sc2-scroll itself). If a browser
   lacks mask / mix-blend-mode support, the @supports guards degrade to a
   clean rounded rectangle on plain parchment rather than a black box.
   ============================================================================ */


/* ════════════════════════════════════════════════════════════════════════════
   0 · THE SHEET ITSELF  (.sc2-scroll)
   The substrate engineer owns ONLY the substrate concerns of this element:
   its fallback fill, its deckle mask, and its grime vignette (::after).
   Geometry / position:relative / aspect-ratio are owned by the layout layer;
   we defensively assert position:relative so our absolutely-positioned child
   layers anchor correctly even if loaded standalone.
   ════════════════════════════════════════════════════════════════════════════ */
.sc2-scroll {
	position: relative;            /* defensive anchor for absolute child layers */
	isolation: isolate;           /* contains mix-blend-mode to the sheet only   */

	/* Fallback substrate so the sheet is NEVER #fff / transparent even before
	   .sc2-vellum paints. Uses the same radial recipe at low fidelity.        */
	background-color: var(--vellum, #f4e8c8);
	background-image: radial-gradient(
		120% 140% at 50% 0%,
		var(--vellum-hi, #faf0d6) 0%,
		var(--vellum,    #f4e8c8) 45%,
		var(--vellum-lo, #ddc593) 100%
	);

	/* The physical sheet casts a soft drop shadow onto the felt stage. The
	   border-radius is the "machine-cut" baseline; the deckle mask below
	   chews it into an organic torn edge on capable browsers.                 */
	border-radius: 6px;
	box-shadow:
		0 1px 1px   rgba(0,0,0,.10),
		0 10px 24px rgba(40,28,10,.28),
		0 30px 60px rgba(40,28,10,.22);
}

/* ── DECKLE / TORN EDGE ──────────────────────────────────────────────────────
   The sheet's silhouette is masked by an SVG turbulence-displaced rounded rect
   (#sc2-deckle, defined in the inline <defs> at the bottom of this file). This
   replaces the crisp rectangle with a hand-torn deckle. Guarded by @supports:
   if mask is unavailable the sheet keeps its border-radius and reads fine.
   PRINT / EXPORT fallback (see §6) swaps to a flattened path-based mask because
   feDisplacementMap masks rasterize unreliably (html2canvas drops them).      */
@supports ((-webkit-mask: url(#x)) or (mask: url(#x))) {
	.sc2-scroll {
		/* Use the BAKED path deckle (defined in §6 as --sc2-deckle-baked) on
		   screen too. The live feDisplacementMap mask (#sc2-deckle) operates in
		   objectBoundingBox (0–1) units where scale="9" is enormous and shreds
		   the sheet edge — the baked path under-bites safely and renders
		   identically on screen, print, and html2canvas export.               */
		-webkit-mask: var(--sc2-deckle-baked);
		mask: var(--sc2-deckle-baked);
		-webkit-mask-size: 100% 100%;
		mask-size: 100% 100%;
		-webkit-mask-repeat: no-repeat;
		mask-repeat: no-repeat;
	}
}

/* ── EDGE-GRIME VIGNETTE  (.sc2-scroll::after) ───────────────────────────────
   Layer §2.2 of the substrate brief. A multiply-blended radial darkening +
   an inset box-shadow that grimes the four edges. Sits at the edge z-tier so
   it darkens substrate + ruling + foxing but stays BELOW the illumination
   band and all text. pointer-events:none so it never eats clicks.            */
.sc2-scroll::after {
	content: "";
	position: absolute;
	inset: 0;
	z-index: var(--z-edge, 3);
	pointer-events: none;
	border-radius: inherit;
	background: radial-gradient(
		135% 135% at 50% 45%,
		transparent 55%,
		var(--grime, rgba(74,52,24,.35)) 100%
	);
	box-shadow: inset 0 0 70px 14px var(--grime, rgba(74,52,24,.35));
	mix-blend-mode: multiply;
}
@supports not (mix-blend-mode: multiply) {
	.sc2-scroll::after { opacity: .55; }   /* graceful: just a soft vignette */
}


/* ════════════════════════════════════════════════════════════════════════════
   1 · VELLUM BODY  (.sc2-vellum)
   The substrate proper, painted bottom→top in a SINGLE element using a stacked
   background list plus one ::after for the SVG fibre mottle. Order per brief:
     (a) base radial body          (this element, last/bottom-most bg layer)
     (b) foxing / stain blobs      (this element, upper bg layers, multiply)
     (c) fibre mottle              (::after, feTurbulence data-URI, multiply)
   Edge-grime vignette is on .sc2-scroll::after (above) so it can darken these.
   ════════════════════════════════════════════════════════════════════════════ */
.sc2-vellum {
	position: absolute;
	inset: 0;
	z-index: var(--z-vellum, 0);
	pointer-events: none;
	border-radius: inherit;
	overflow: hidden;             /* keep mottle ::after inside the deckle      */

	/* Background list, TOP layer first (CSS paints first listed on top).
	   1) Foxing / stain blobs — 6 asymmetric, SCATTERED, never centered.
	      color-mix lets each blob carry its own low alpha off the single
	      --foxing hue; @supports fallback below for older engines.            */
	background-color: var(--vellum, #f4e8c8);
	background-image:
		radial-gradient(18px 22px at 18% 22%, color-mix(in srgb, var(--foxing,#b58f5b) 18%, transparent) 0%, transparent 70%),
		radial-gradient(26px 20px at 71% 14%, color-mix(in srgb, var(--foxing,#b58f5b) 13%, transparent) 0%, transparent 72%),
		radial-gradient(34px 30px at 44% 63%, color-mix(in srgb, var(--foxing,#b58f5b) 10%, transparent) 0%, transparent 75%),
		radial-gradient(22px 26px at 88% 79%, color-mix(in srgb, var(--foxing,#b58f5b) 15%, transparent) 0%, transparent 70%),
		radial-gradient(30px 24px at 9%  84%, color-mix(in srgb, var(--foxing,#b58f5b)  9%, transparent) 0%, transparent 74%),
		radial-gradient(16px 18px at 60% 38%, color-mix(in srgb, var(--foxing,#b58f5b) 11%, transparent) 0%, transparent 68%),
		/* base radial body — lightest at the top-center, aging toward edges */
		radial-gradient(
			120% 140% at 50% 0%,
			var(--vellum-hi, #faf0d6) 0%,
			var(--vellum,    #f4e8c8) 45%,
			var(--vellum-lo, #ddc593) 100%
		);
	background-repeat: no-repeat;
	background-blend-mode: multiply, multiply, multiply, multiply, multiply, multiply, normal;
}

/* Fallback for engines without color-mix(): plain semi-opaque foxing hue.
   The base radial body always survives because it's the last bg layer.       */
@supports not (background-color: color-mix(in srgb, red 50%, blue)) {
	.sc2-vellum {
		background-image:
			radial-gradient(18px 22px at 18% 22%, rgba(181,143,91,.18) 0%, transparent 70%),
			radial-gradient(26px 20px at 71% 14%, rgba(181,143,91,.13) 0%, transparent 72%),
			radial-gradient(34px 30px at 44% 63%, rgba(181,143,91,.10) 0%, transparent 75%),
			radial-gradient(22px 26px at 88% 79%, rgba(181,143,91,.15) 0%, transparent 70%),
			radial-gradient(30px 24px at 9%  84%, rgba(181,143,91,.09) 0%, transparent 74%),
			radial-gradient(16px 18px at 60% 38%, rgba(181,143,91,.11) 0%, transparent 68%),
			radial-gradient(120% 140% at 50% 0%, var(--vellum-hi,#faf0d6) 0%, var(--vellum,#f4e8c8) 45%, var(--vellum-lo,#ddc593) 100%);
	}
}

/* ── FIBRE MOTTLE  (.sc2-vellum::after) ──────────────────────────────────────
   The skin texture. An inline-SVG feTurbulence (fractalNoise, anisotropic
   baseFrequency with Y>X to mimic dermal fibre direction) baked as a data-URI
   background, multiply-blended at low opacity so it never muddies the ink.
   Because it is a data-URI it tiles seamlessly (stitchTiles) and needs no
   external request. opacity ~.5 per the brief.                               */
.sc2-vellum::after {
	content: "";
	position: absolute;
	inset: 0;
	pointer-events: none;
	mix-blend-mode: multiply;
	opacity: .5;
	background-image: url("data:image/svg+xml;utf8,\
<svg xmlns='http://www.w3.org/2000/svg' width='240' height='240'>\
<filter id='m' x='0' y='0' width='100%25' height='100%25'>\
<feTurbulence type='fractalNoise' baseFrequency='0.012 0.016' numOctaves='4' seed='7' stitchTiles='stitch' result='n'/>\
<feColorMatrix in='n' type='matrix' values='0 0 0 0 0.36  0 0 0 0 0.27  0 0 0 0 0.16  0 0 0 0.9 0'/>\
</filter>\
<rect width='100%25' height='100%25' filter='url(%23m)'/>\
</svg>");
	background-size: 240px 240px;
	background-repeat: repeat;
}
@supports not (mix-blend-mode: multiply) {
	.sc2-vellum::after { opacity: .22; }   /* avoid a flat grey wash */
}


/* ════════════════════════════════════════════════════════════════════════════
   2 · RULING + PRICKING  (.sc2-ruling)
   Faint horizontal guide-lines a scribe would rule before lettering, plus the
   column of pricked dots near the edge that those lines were struck between.
   Sits at z-ruling (1) — above vellum, below illumination & text. Only shown
   at intensity ≥ balanced (the markup/layout layer toggles via the
   [data-intensity] attribute; we provide the visual + the gate here).
   ════════════════════════════════════════════════════════════════════════════ */
.sc2-ruling {
	position: absolute;
	/* inset to roughly the writing block so ruling doesn't run under the band */
	inset: var(--margin-frame, 7.5%);
	z-index: var(--z-ruling, 1);
	pointer-events: none;
	opacity: .14;
	/* Horizontal ruling at the body line-height rhythm (~28px). The pricking
	   column is a second, narrow repeating-gradient pinned to the left edge.  */
	background-image:
		repeating-linear-gradient(
			to bottom,
			transparent 0,
			transparent 27px,
			var(--ruling, #9a8f78) 27px,
			var(--ruling, #9a8f78) 28px
		);
	background-repeat: no-repeat;
}
/* Pricking dots — a 1.2px dotted column just inside each vertical edge, struck
   at the same 28px interval as the ruling.                                    */
.sc2-ruling::before,
.sc2-ruling::after {
	content: "";
	position: absolute;
	top: 0;
	bottom: 0;
	width: 1.2px;
	background-image: radial-gradient(
		var(--ruling, #9a8f78) 0 .6px,
		transparent .7px
	);
	background-size: 1.2px 28px;
	background-repeat: repeat-y;
	opacity: .8;
}
.sc2-ruling::before { left:  -3px; }
.sc2-ruling::after  { right: -3px; }

/* Intensity gate: ruling is OFF for the lightest setting, ON otherwise.
   Defensive — works whether the attribute lives on .sc2-scroll or an ancestor.*/
.sc2-scroll[data-intensity="plain"]   .sc2-ruling,
.sc2-scroll[data-intensity="minimal"] .sc2-ruling { display: none; }


/* ════════════════════════════════════════════════════════════════════════════
   3 · ROLLED CURL  (.sc2-edge top & bottom strips)
   intensity = ornate ONLY. A thin gradient strip along the top and bottom long
   edges that reads as the sheet curling back on itself, with a shadow cast
   INWARD onto the body. .sc2-edge is the overlay element the markup places at
   z-edge; we paint its ::before (top curl) and ::after (bottom curl).
   ════════════════════════════════════════════════════════════════════════════ */
.sc2-edge {
	position: absolute;
	inset: 0;
	z-index: var(--z-edge, 3);
	pointer-events: none;
	border-radius: inherit;
}
/* Curls are hidden by default and only revealed at ornate intensity.         */
.sc2-edge::before,
.sc2-edge::after { content: none; }

.sc2-scroll[data-intensity="ornate"] .sc2-edge::before,
.sc2-scroll[data-intensity="ornate"] .sc2-edge::after {
	content: "";
	position: absolute;
	left: 0;
	right: 0;
	height: 28px;
	background: linear-gradient(
		to bottom,
		var(--vellum-hi, #faf0d6) 0%,
		var(--vellum,    #f4e8c8) 45%,
		var(--vellum-lo, #ddc593) 100%
	);
}
/* Top curl: rounded along its top long edge, shadow cast DOWN/inward.        */
.sc2-scroll[data-intensity="ornate"] .sc2-edge::before {
	top: 0;
	border-radius: 6px 6px 14px 14px / 6px 6px 22px 22px;
	box-shadow: 0 8px 14px var(--curl-shadow, rgba(60,40,15,.35));
}
/* Bottom curl: rounded along its bottom long edge, shadow cast UP/inward.    */
.sc2-scroll[data-intensity="ornate"] .sc2-edge::after {
	bottom: 0;
	border-radius: 14px 14px 6px 6px / 22px 22px 6px 6px;
	box-shadow: 0 -8px 14px var(--curl-shadow, rgba(60,40,15,.35));
}


/* ════════════════════════════════════════════════════════════════════════════
   4 · ASTRAL CODEX SAFETY NET
   The dark-substrate family inverts the trio in tokens, so multiply blending
   would crush the mottle to near-invisibility. Lighten the fibre + foxing on
   that family so the texture reads as faint star-grain on a night ground.
   Family detection is by data-family ONLY (no hard-coded colours here).
   ════════════════════════════════════════════════════════════════════════════ */
.sc2-scroll[data-family="astral_codex"] .sc2-vellum::after {
	mix-blend-mode: screen;
	opacity: .35;
}
.sc2-scroll[data-family="astral_codex"] .sc2-vellum {
	background-blend-mode: screen, screen, screen, screen, screen, screen, normal;
}
.sc2-scroll[data-family="astral_codex"]::after {
	/* grime over a dark sheet should ADD glow at the rim, not multiply to mud */
	mix-blend-mode: screen;
}


/* ════════════════════════════════════════════════════════════════════════════
   5 · REDUCED MOTION / DATA-SAVER COURTESY
   Nothing here animates, but if a UA hints at data-saving we drop the mottle
   data-URI paint (it's the only texture cost). The base radial + foxing keep
   the sheet convincing.
   ════════════════════════════════════════════════════════════════════════════ */
@media (prefers-reduced-data: reduce) {
	.sc2-vellum::after { background-image: none; opacity: 0; }
}


/* ════════════════════════════════════════════════════════════════════════════
   6 · PRINT / EXPORT FLATTENING
   feDisplacementMap masks rasterize unreliably (html2canvas drops them; some
   PDF engines wobble). For print AND for the explicit export-mode class we:
     • swap the deckle mask to a baked, flattened SVG <path> data-URI (jittered
       points, no live filter) so the torn edge survives rasterization;
     • drop mix-blend-mode reliance (print color management is inconsistent) by
       compositing the vignette with plain alpha;
     • keep the radial body + foxing + a low-cost mottle for fidelity.
   The .sc2-export class is applied by the export engineer just before capture.
   ════════════════════════════════════════════════════════════════════════════ */

/* Baked path deckle — a flattened, jittered rounded outline as a data-URI
   mask. ~52 points around the perimeter give a hand-torn read without any
   live SVG filter. Reused for both export class and print.                   */
.sc2-export .sc2-scroll,
.sc2-scroll.sc2-export {
	-webkit-mask: var(--sc2-deckle-baked);
	mask: var(--sc2-deckle-baked);
	-webkit-mask-size: 100% 100%;
	mask-size: 100% 100%;
}
.sc2-export .sc2-scroll::after,
.sc2-scroll.sc2-export::after {
	mix-blend-mode: normal;       /* print-safe: composite grime with alpha    */
	opacity: .9;
}
.sc2-export .sc2-vellum::after,
.sc2-scroll.sc2-export .sc2-vellum::after {
	mix-blend-mode: normal;
	opacity: .14;                 /* keep a whisper of grain, print-safe       */
}
.sc2-export .sc2-vellum,
.sc2-scroll.sc2-export .sc2-vellum {
	background-blend-mode: normal, normal, normal, normal, normal, normal, normal;
}

@media print {
	.sc2-scroll {
		/* Swap to the baked path mask; live filter masks wobble in PDF.      */
		-webkit-mask: var(--sc2-deckle-baked);
		mask: var(--sc2-deckle-baked);
		-webkit-mask-size: 100% 100%;
		mask-size: 100% 100%;
		/* A real sheet on white paper still wants a faint contact shadow.    */
		box-shadow: 0 2px 6px rgba(40,28,10,.18);
		-webkit-print-color-adjust: exact;
		print-color-adjust: exact;
	}
	.sc2-scroll::after {
		mix-blend-mode: normal;
		opacity: .9;
	}
	.sc2-vellum::after {
		mix-blend-mode: normal;
		opacity: .14;
	}
	.sc2-vellum {
		background-blend-mode: normal, normal, normal, normal, normal, normal, normal;
		-webkit-print-color-adjust: exact;
		print-color-adjust: exact;
	}
}

/* The baked deckle outline, declared as a token-style data-URI so both the
   export class and @media print reference one source. A rounded near-rect with
   ~13 jittered control points per long edge / ~10 per short edge, traced as a
   smooth path. It deliberately under-bites (small amplitude) so text margins
   stay safe even after rasterization.                                        */
.sc2-scroll {
	--sc2-deckle-baked: url("data:image/svg+xml;utf8,\
<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 1000 1294' preserveAspectRatio='none'>\
<path fill='%23fff' d='\
M14,20 L70,12 L150,18 L240,11 L330,17 L420,10 L510,16 L600,11 L690,17 L780,12 L860,18 L930,12 L986,20 \
L990,80 L984,180 L991,290 L985,400 L992,510 L984,620 L991,730 L985,840 L992,950 L984,1060 L991,1170 L986,1274 \
L930,1282 L850,1276 L760,1283 L670,1277 L580,1284 L490,1278 L400,1283 L310,1277 L220,1283 L140,1277 L70,1283 L14,1274 \
L10,1170 L17,1060 L9,950 L16,840 L8,730 L17,620 L9,510 L16,400 L8,290 L17,180 L9,80 Z'/>\
</svg>");
}


/* ════════════════════════════════════════════════════════════════════════════
   7 · INLINE SVG <defs> the substrate classes reference
   --------------------------------------------------------------------------
   These filters/masks must exist in the DOM for the LIVE (screen) deckle &
   any future filtered substrate effects. The markup engineer renders ONE copy
   per scroll inside <svg class="sc2-defs">. This block is the CANONICAL source
   for the substrate-owned defs; it is reproduced here as an HTML comment so the
   finalizer / markup engineer can paste it verbatim. (CSS cannot emit SVG, so
   it lives as documentation adjacent to the CSS that depends on it.)
   --------------------------------------------------------------------------
   <svg class="sc2-defs" aria-hidden="true" focusable="false"
        width="0" height="0" style="position:absolute;width:0;height:0;overflow:hidden">
     <defs>

       <!-- LIVE deckle: turbulence-displaced rounded rect. The mask is sized
            to the sheet via maskContentUnits/maskUnits=objectBoundingBox so it
            scales to any portrait/landscape sheet. -->
       <filter id="sc2-deckle-fx" x="-5%" y="-5%" width="110%" height="110%">
         <feTurbulence type="fractalNoise" baseFrequency="0.02 0.04"
                       numOctaves="3" seed="11" result="noise"/>
         <feDisplacementMap in="SourceGraphic" in2="noise" scale="9"
                            xChannelSelector="R" yChannelSelector="G"/>
       </filter>
       <mask id="sc2-deckle" maskUnits="objectBoundingBox"
             maskContentUnits="objectBoundingBox"
             x="0" y="0" width="1" height="1">
         <rect x="0.004" y="0.004" width="0.992" height="0.992" rx="0.008"
               fill="#fff" filter="url(#sc2-deckle-fx)"/>
       </mask>

     </defs>
   </svg>
   ════════════════════════════════════════════════════════════════════════════ */

/* ===== inlined: sf-illumination.css.part ===== */
/* ============================================================================
   THE LETTERED SCROLL — sf-illumination.css.part
   ----------------------------------------------------------------------------
   The ILLUMINATION layer (z-illum = 2): concentric border zones, the decorated
   band + illuminated corner pieces, the bas-de-page cartouche, the gilt-leaf
   treatment (gradient + highlight + dark keyline — NEVER flat #ffd700), the
   illuminated VERSAL drop-cap and its decorated initial box, rubrication
   helpers, and section rules / dividers.

   MEDIUM IS LOCKED: semantic HTML + CSS + inline SVG. The decorated band and
   corner ornament are painted with `mask`ed SVG data-URIs so the ornament
   COLOUR always tracks the shared tokens (--gold / --accent / --border) — no
   baked-in hex, fully themeable, fully dark-mode-safe because every token here
   is scoped under `.sc2-scroll` (which never inherits app theme).

   OWNERSHIP / NON-COLLISION:
     • This file owns: .sc2-illum, .sc2-border, the gilt-* utilities, the versal
       (.sc2-body first-letter + .sc2-versal box), .sc2-rubric, .sc2-rule,
       .sc2-flourish, .sc2-pilcrow, .sc2-band, .sc2-corner, .sc2-basdepage and
       the [data-family]/[data-motif] motif overrides for the BAND/corner only.
     • Substrate (sf-substrate) owns .sc2-vellum / .sc2-ruling / deckle / curl /
       the .sc2-scroll::after vignette — NOT touched here.
     • Heraldry (sf-heraldry) owns .sc2-arms* / .sc2-crown* / .sc2-seal* —
       NOT touched here.
     • Tokens (sf-tokens) owns every PALETTE custom-property NAME — referenced
       verbatim; this file invents ZERO palette hex outside SVG data-URI masks
       (which are monochrome WHITE shapes, recoloured by mask + token paint).

   TOKEN NAMES consumed from sf-tokens (verbatim): --margin-frame, --band-w,
   --bar-w, --rule-w, --corner-size, --gold, --gold-hi, --gold-deep,
   --gold-shadow, --gold-keyline, --gild-gradient, --shadow-emboss,
   --gild-shadow, --gild-drop, --border, --accent, --rule-fine,
   --initial-ground, --rubric, --rubric-shadow, --ff-versal, --fs-versal,
   --sheet-shadow, --z-illum, --t-family.  Composite gilt helpers below are
   DERIVED from those (no new palette hex).

   DEFENSIVE: every hook degrades gracefully if its element is absent. The band
   ornament is painted entirely in CSS, so the scroll reads as "illuminated"
   even if the markup engineer ships an empty <svg class="sc2-border">. `mask`,
   `mask-composite`, `color-mix`, and `background-clip:text` each have an
   @supports fallback so nothing floods solid or vanishes on older engines.

   We reset the global orkui h1–h6 pill on every heading we touch (the title is
   owned by the typography partial; here we guard the grant clause + versal).
   ============================================================================ */


/* ════════════════════════════════════════════════════════════════════════════
   0 · GILDING RECIPES  (reusable — typography & heraldry partials may reuse
       these utility classes / vars instead of re-deriving the stops)
   ──────────────────────────────────────────────────────────────────────────
   Gold is ALWAYS the gradient recipe: gradient + inner highlight + dark
   keyline + cast shadow. Two flavours: a FILL (bands, boxes, rims) and TEXT
   (title, versal). We reuse the canonical --gild-gradient declared in tokens,
   falling back to a locally-built ramp if a future tokens revision drops it.
   ════════════════════════════════════════════════════════════════════════ */
.sc2-scroll {
	/* Local fallback ramp — only used if tokens' --gild-gradient is absent. */
	--gild-gradient-local: linear-gradient(135deg,
		var(--gold-shadow) 0%,
		var(--gold)        18%,
		var(--gold-hi)     38%,
		var(--gold)        58%,
		var(--gold-deep)   82%,
		var(--gold-shadow) 100%);
	/* The gradient every gilt surface paints with. */
	--gilt-grad: var(--gild-gradient, var(--gild-gradient-local));
	/* Inner relief shadow stack that sells "raised metal leaf". */
	--gilt-relief:
		inset 0 1px 0   rgba(255,250,220,.65),
		inset 0 -1px 1px rgba(60,40,10,.50),
		0 0 0 .75px      var(--gold-keyline);
	--gilt-cast: drop-shadow(0 1px 1px rgba(60,40,5,.50));
}

/* Gilt FILL — bands, boxes, rims, rules. */
.sc2-gilt-fill {
	background: var(--gilt-grad);
	box-shadow: var(--gilt-relief);
	filter: var(--gilt-cast);
}

/* Gilt TEXT — title, versal, grant accent. background-clip:text. */
.sc2-gilt-text {
	background: var(--gilt-grad);
	-webkit-background-clip: text;
	background-clip: text;
	color: transparent;
	-webkit-text-fill-color: transparent;
	-webkit-text-stroke: .75px var(--gold-keyline);
	filter:
		drop-shadow(0 1px 0 var(--gold-hi))
		drop-shadow(0 2px 2px rgba(40,20,0,.35));
}

/* EXPORT / PRINT fallback — html2canvas & some PDF engines drop background-
   clip:text. Degrade gilt text to a solid gold with a keyline text-shadow. */
.sc2-export .sc2-gilt-text,
.sc2-scroll.sc2-export .sc2-gilt-text,
.sc2-export .sc2-title,
.sc2-export .sc2-versal {
	background: none !important;
	-webkit-text-fill-color: var(--gold) !important;
	color: var(--gold) !important;
	-webkit-text-stroke: 0 !important;
	text-shadow: 0 1px 0 var(--gold-keyline), 0 1px 2px rgba(40,20,0,.35) !important;
	filter: none !important;
}


/* ════════════════════════════════════════════════════════════════════════════
   1 · THE ILLUMINATION STAGE  (.sc2-illum)  — z-illum
   ──────────────────────────────────────────────────────────────────────────
   Sits between the ruling (z1) and the content (z4). It is purely decorative
   (aria-hidden in markup) and never intercepts clicks. It is inset so the
   border frames the TEXT block, leaving the deckled vellum edge bare outside.
   Derived geometry resolves the tokens' short names (--band-w/--bar-w/--rule-w)
   to local zone variables, with safe literal fallbacks if a token is missing.
   ════════════════════════════════════════════════════════════════════════ */
.sc2-illum {
	position: absolute;
	inset: 0;
	z-index: var(--z-illum, 2);
	pointer-events: none;
	border-radius: inherit;
	/* Derived geometry shared by every concentric zone below. */
	--frame-inset: var(--margin-frame, 7.5%);   /* sheet edge → frame   */
	--zone-rule:   var(--rule-w, .75px);         /* fine outer hairline  */
	--zone-bar:    var(--bar-w, 10px);           /* solid bar border     */
	--zone-band:   var(--band-w, 40px);          /* decorated ornament   */
	--zone-gap:    6px;                           /* breathing gaps       */
}

/* The decorated band + corner SVG fills the illum stage. Defensive: if the
   markup ships an empty <svg>, the CSS-painted band below still renders. */
.sc2-border {
	position: absolute;
	inset: 0;
	width: 100%;
	height: 100%;
	overflow: visible;
	pointer-events: none;
}
/* SVG gilt paths (markup engineer draws into <svg class="sc2-border">): any
   element marked .sc2-gild picks up the canonical gradient via SVG paint. */
.sc2-border .sc2-gild        { fill: var(--gold);  }
.sc2-border .sc2-gild-stroke { fill: none; stroke: var(--gold-keyline); stroke-width: .75; }
.sc2-border .sc2-field       { fill: var(--border); }
.sc2-border .sc2-accent      { fill: var(--accent); }


/* ════════════════════════════════════════════════════════════════════════════
   2 · CONCENTRIC BORDER ZONES (CSS-painted — robust even with no SVG)
   ──────────────────────────────────────────────────────────────────────────
   Outer → inner:
     (a) fine outer rule .......... .sc2-illum::before  (hairline brown ink)
     (b) solid bar border ......... .sc2-illum::after   (field colour / gilt)
     (c) decorated ornament band .. .sc2-band           (masked SVG motif)
     (d) inner gilt keyline ....... .sc2-band::before    (thin gold frame)
   Corner pieces are .sc2-corner elements (densest ornament) layered on top.
   ════════════════════════════════════════════════════════════════════════ */

/* (a) FINE OUTER RULE — 0.75px hairline just inside the deckled margin. */
.sc2-illum::before {
	content: "";
	position: absolute;
	inset: calc(var(--frame-inset) - var(--zone-gap));
	border: var(--zone-rule) solid var(--rule-fine);
	border-radius: 3px;
	opacity: .85;
}

/* (b) SOLID BAR BORDER — the heavy frame the text block hangs inside.
   Default = field colour; gilded families flip to gold via data-bar="gilt". */
.sc2-illum::after {
	content: "";
	position: absolute;
	inset: var(--frame-inset);
	border: var(--zone-bar) solid var(--border);
	border-radius: 2px;
	box-shadow:
		inset 0 0 0 1px rgba(0,0,0,.18),     /* inner recess line              */
		0 1px 2px rgba(40,24,6,.25);         /* faint lift off the vellum      */
}
/* Gilt-bar variant: families that want a metal frame add data-bar="gilt". */
.sc2-scroll[data-bar="gilt"] .sc2-illum::after,
.sc2-scroll.sc2-bar-gilt    .sc2-illum::after {
	border-color: var(--gold);
	background: var(--gilt-grad);
	background-clip: border-box;
	box-shadow: var(--gilt-relief);
}

/* (c) DECORATED ORNAMENT BAND — the soul of the illumination.
   A continuous ribbon of family motif, painted as a WHITE SVG shape inside a
   `mask`, then filled by the band's gilt `background` so the colour follows
   tokens. Lives just inside the solid bar. Two masks composite so only the
   BORDER frame (not the centre) keeps the ornament — the page interior stays
   clear for text. */
.sc2-band {
	position: absolute;
	inset: calc(var(--frame-inset) + var(--zone-bar) + var(--zone-gap));
	border: var(--zone-band) solid transparent;
	border-radius: 2px;
	/* The motif paint: the gilt wash so the ornament itself reads as metal. */
	background: var(--gilt-grad) border-box;
	/* Carve the ornament out of that gilt wash, keeping only the border frame. */
	-webkit-mask:
		var(--motif-mask, var(--motif-mask-default)) border-box,
		linear-gradient(#000 0 0) padding-box;        /* knock the centre out   */
	mask:
		var(--motif-mask, var(--motif-mask-default)) border-box,
		linear-gradient(#000 0 0) padding-box;
	-webkit-mask-composite: source-out;               /* keep border − padding  */
	mask-composite: subtract;
	-webkit-mask-repeat: repeat;
	mask-repeat: repeat;
	-webkit-mask-size: var(--motif-size, 38px 38px);
	mask-size: var(--motif-size, 38px 38px);
	filter: drop-shadow(0 1px 1px rgba(50,32,8,.35));
	opacity: .96;
}

/* (d) INNER GILT KEYLINE — a thin bright frame hugging the text block,
   separating ornament from the lettering. */
.sc2-band::before {
	content: "";
	position: absolute;
	inset: 1px;
	border: 1px solid var(--gold-keyline);
	border-radius: 1px;
	opacity: .55;
}

/* ════════════════════════════════════════════════════════════════════════════
   INTENSITY DIAL — plain / balanced / ornate VISIBLY restructure the frame.
   ──────────────────────────────────────────────────────────────────────────
   The border is the SVG .sc2-border inside .sc2-illum:
     .sc2-border__rule    fine outer line     .sc2-border__bar     heavy stroke
     .sc2-border__band    decorative inner    .sc2-border__corners gilt besants
   Selectors MUST use the plain|balanced|ornate values the panel + sf-app.js set
   (the old `restrained`/`minimal` names were never emitted → the dial was dead,
   and the old `.sc2-band`/`.sc2-corner` DIVS don't exist — markup is SVG groups).
     • plain    — thin single bar, no outer rule, no band, no corners, blank vellum.
     • balanced — heavier bar + fine outer rule (double frame) + inner band + ruling.
     • ornate   — thick bar + outer rule + band + corner besants + ruling + curls.
   ════════════════════════════════════════════════════════════════════════ */
/* Bar weight steps up with intensity. */
.sc2-scroll[data-intensity="plain"]    .sc2-border__bar { stroke-width: 4; }
.sc2-scroll[data-intensity="balanced"] .sc2-border__bar { stroke-width: 9; }
.sc2-scroll[data-intensity="ornate"]   .sc2-border__bar { stroke-width: 13; }
/* Fine outer rule (the double-frame read) — only the decorated tiers. */
.sc2-scroll[data-intensity="plain"] .sc2-border__rule { display: none; }
/* Decorative inner band line — hidden only when plain. */
.sc2-scroll[data-intensity="plain"] .sc2-border__band { display: none; }
/* The SECOND concentric band line is ornate-only (single line for balanced). */
.sc2-scroll:not([data-intensity="ornate"]) .sc2-border__band-inner { display: none; }
/* Corner besants — ornate ONLY: the clear top-tier tell. */
.sc2-scroll:not([data-intensity="ornate"]) .sc2-border__corners { display: none; }


/* ════════════════════════════════════════════════════════════════════════════
   3 · ILLUMINATED CORNER PIECES (.sc2-corner) — densest ornament
   ──────────────────────────────────────────────────────────────────────────
   Four heavier ornament clusters seated in the corners of the bar border.
   Markup ships <span class="sc2-corner sc2-corner--tl"></span> ×4 (or the SVG
   draws them); if absent, nothing breaks. Each is a gilt boss/knot painted with
   the same mask trick, rotated per corner so the motif reads "into" the page.
   Sized off the corner-size token (falls back to the band width).
   ════════════════════════════════════════════════════════════════════════ */
.sc2-corner {
	position: absolute;
	width:  var(--corner-size, calc(var(--zone-band) * 2));
	height: var(--corner-size, calc(var(--zone-band) * 2));
	background: var(--gilt-grad);
	-webkit-mask: var(--corner-mask, var(--corner-mask-default)) no-repeat center / contain;
	mask:         var(--corner-mask, var(--corner-mask-default)) no-repeat center / contain;
	filter: drop-shadow(0 1px 1px rgba(50,30,6,.45));
	pointer-events: none;
}
/* Seat each corner at the bar's outer corner, rotating the motif inward. */
.sc2-corner--tl { top: var(--frame-inset); left:  var(--frame-inset); transform: rotate(0deg);   transform-origin: top left; }
.sc2-corner--tr { top: var(--frame-inset); right: var(--frame-inset); transform: rotate(90deg);  transform-origin: top right; }
.sc2-corner--br { bottom: var(--frame-inset); right: var(--frame-inset); transform: rotate(180deg); transform-origin: bottom right; }
.sc2-corner--bl { bottom: var(--frame-inset); left:  var(--frame-inset); transform: rotate(270deg); transform-origin: bottom left; }
/* A small dark keyline boss under each corner reads as the recessed mount. */
.sc2-corner::after {
	content: "";
	position: absolute;
	inset: 22%;
	border: .75px solid var(--gold-keyline);
	border-radius: 50% 8% 50% 8%;
	opacity: .4;
}
.sc2-scroll[data-intensity="restrained"] .sc2-corner { display: none; }


/* ════════════════════════════════════════════════════════════════════════════
   4 · BAS-DE-PAGE CARTOUCHE (.sc2-basdepage) — bottom-margin drollery
   ──────────────────────────────────────────────────────────────────────────
   A wider ornament cluster in the bottom margin behind/around the seal zone.
   Ornate intensity only. The seal (heraldry partial) sits ON TOP at z-seal.
   ════════════════════════════════════════════════════════════════════════ */
.sc2-basdepage {
	position: absolute;
	left: 50%;
	bottom: calc(var(--frame-inset) * .42);
	transform: translateX(-50%);
	width: 46%;
	height: calc(var(--zone-band) * 1.4);
	background: var(--gilt-grad);
	-webkit-mask: var(--basdepage-mask, var(--basdepage-mask-default)) no-repeat center / contain;
	mask:         var(--basdepage-mask, var(--basdepage-mask-default)) no-repeat center / contain;
	opacity: .9;
	filter: drop-shadow(0 1px 1px rgba(50,30,6,.4));
	pointer-events: none;
}
.sc2-scroll:not([data-intensity="ornate"]) .sc2-basdepage { display: none; }


/* ════════════════════════════════════════════════════════════════════════════
   5 · ILLUMINATED VERSAL DROP-CAP + DECORATED INITIAL BOX
   ──────────────────────────────────────────────────────────────────────────
   The opening word of the body begins with a large illuminated initial.
   Preferred path: a dedicated <span class="sc2-versal">A</span> wrapper so we
   can place the decorated ground BEHIND the letter. Fallback path: ::first-
   letter on the first body paragraph (works with zero extra markup).
   ════════════════════════════════════════════════════════════════════════ */

/* --- Fallback (no wrapper): style the first letter of the first body <p>. --- */
.sc2-body > p:first-of-type::first-letter {
	font-family: var(--ff-versal);
	font-weight: 400;                 /* versal faces are 400-only — never 700  */
	font-size: var(--fs-versal, 4.2em);
	line-height: .82;
	float: left;
	margin: .04em .12em -.04em 0;
	padding: 0 .04em;
	color: var(--rubric);             /* default vermilion versal              */
	-webkit-text-stroke: .35px rgba(60,20,20,.4);
	text-shadow: 0 1px 0 rgba(255,250,235,.5);
}
/* DO NOT re-enable CSS `initial-letter` here. Chrome reports support for it but
   renders the drop-cap hugely when an explicit font-size is also present (the
   typography layer sets float + 3.2em): initial-letter:3 + that size => a ~600px
   glyph that inflates the paragraph and forces fitPage() to shrink the WHOLE
   scroll (the "giant versal" regression, hit on Astral Codex / Forest Reverie).
   The bounded float drop-cap above (and in sf-typography) is the only versal. */

/* --- Preferred (explicit wrapper): decorated initial box behind the letter. --- */
.sc2-versal {
	position: relative;
	float: left;
	display: inline-grid;
	place-items: center;
	width: 2.6em;
	height: 2.6em;
	margin: .06em .42em .04em 0;
	font-family: var(--ff-versal);
	font-weight: 400;
	font-size: calc(var(--fs-versal, 4.2em) * .9);
	line-height: 1;
	color: var(--gold-hi);
	/* Reset orkui global heading pill in case the letter is wrapped in an h*. */
	background: transparent;
	border: 0;
	padding: 0;
	border-radius: 0;
	text-shadow: 0 1px 1px rgba(0,0,0,.45);
	-webkit-text-stroke: .4px var(--gold-keyline);
	isolation: isolate;
}
/* Decorated ground panel (lapis/burgundy per family) BEHIND the letter. */
.sc2-versal::before {
	content: "";
	position: absolute;
	inset: 0;
	z-index: -1;
	border-radius: 3px;
	background:
		/* corner filigree highlights */
		radial-gradient(circle at 12% 12%, rgba(255,245,210,.55) 0 8%, transparent 9%),
		radial-gradient(circle at 88% 12%, rgba(255,245,210,.55) 0 8%, transparent 9%),
		radial-gradient(circle at 12% 88%, rgba(255,245,210,.55) 0 8%, transparent 9%),
		radial-gradient(circle at 88% 88%, rgba(255,245,210,.55) 0 8%, transparent 9%),
		/* the jewel-tone ground itself */
		radial-gradient(120% 120% at 30% 25%,
			color-mix(in srgb, var(--initial-ground) 78%, #fff 22%) 0%,
			var(--initial-ground) 55%,
			color-mix(in srgb, var(--initial-ground) 70%, #000 30%) 100%);
	box-shadow:
		inset 0 0 0 1px var(--gold-keyline),       /* dark keyline             */
		inset 0 0 0 2.5px var(--gold),             /* gilt inner frame         */
		inset 0 2px 5px rgba(0,0,0,.45),           /* recessed depth           */
		0 1px 2px rgba(20,12,4,.35);
}
/* Foliate sprig escaping top-left into the margin — ties initial → border. */
.sc2-versal::after {
	content: "";
	position: absolute;
	top: -28%;
	left: -22%;
	width: 70%;
	height: 70%;
	z-index: -1;
	background: var(--gold);
	-webkit-mask: var(--sprig-mask, var(--sprig-mask-default)) no-repeat center / contain;
	mask:         var(--sprig-mask, var(--sprig-mask-default)) no-repeat center / contain;
	opacity: .85;
	filter: drop-shadow(0 1px 1px rgba(50,30,6,.4));
	pointer-events: none;
}
/* Gilt versal variant (royal families) — letter becomes raised gold leaf. */
.sc2-scroll[data-versal="gilt"] .sc2-versal,
.sc2-versal.sc2-gilt-text {
	background: var(--gilt-grad);
	-webkit-background-clip: text;
	background-clip: text;
	color: transparent;
	-webkit-text-fill-color: transparent;
}
/* When the wrapper is present, neutralise the ::first-letter fallback so the
   two treatments never double up. */
.sc2-body:has(.sc2-versal) > p:first-of-type::first-letter {
	font-size: inherit;
	float: none;
	color: inherit;
	margin: 0;
	-webkit-text-stroke: 0;
	text-shadow: none;
}


/* ════════════════════════════════════════════════════════════════════════════
   6 · RUBRICATION  (vermilion — recipient name + notification opener ONLY)
   ════════════════════════════════════════════════════════════════════════ */
.sc2-rubric,
.sc2-content .sc2-rubric {
	color: var(--rubric);
	font-feature-settings: "smcp" 0;       /* keep rubric in lining, not smcp */
	text-shadow: var(--rubric-shadow, 0 1px 0 rgba(255,250,235,.45));
}
/* Optional small gilt pilcrow for section openers. */
.sc2-pilcrow::before {
	content: "\00B6\2002";                  /* ¶ + en-space                    */
	color: var(--gold);
	-webkit-text-stroke: .4px var(--gold-keyline);
	font-weight: 700;
}


/* ════════════════════════════════════════════════════════════════════════════
   7 · SECTION RULES, DIVIDERS & FLOURISHES
   ──────────────────────────────────────────────────────────────────────────
   Hand-inked dividers between movements of the document. A centred gilt rule
   with a lozenge node, and a leafy flourish for the grant clause.
   ════════════════════════════════════════════════════════════════════════ */
.sc2-rule {
	display: flex;
	align-items: center;
	justify-content: center;
	gap: .6em;
	margin: 1.15em auto;
	width: min(62%, 28em);
	color: var(--gold);
	pointer-events: none;
}
.sc2-rule::before,
.sc2-rule::after {
	content: "";
	flex: 1;
	height: 2px;
	border-radius: 2px;
	background: linear-gradient(90deg,
		transparent, var(--gold-deep), var(--gold), var(--gold-hi),
		var(--gold), var(--gold-deep), transparent);
	box-shadow: 0 .5px 0 rgba(255,250,220,.5), 0 1px 1px rgba(50,30,6,.35);
}
/* Centre node: a small gilt lozenge with a dark keyline. */
.sc2-rule__node,
.sc2-rule > i {
	flex: 0 0 auto;
	width: 11px;
	height: 11px;
	transform: rotate(45deg);
	background: var(--gilt-grad);
	box-shadow: var(--gilt-relief);
	border-radius: 2px;
}

/* Grant-clause flourish — a foliate sprig, centred, under the dispositive line. */
.sc2-flourish {
	display: block;
	width: clamp(120px, 28%, 220px);
	height: 22px;
	margin: .7em auto .2em;
	background: var(--gold);
	-webkit-mask: var(--flourish-mask, var(--flourish-mask-default)) no-repeat center / contain;
	mask:         var(--flourish-mask, var(--flourish-mask-default)) no-repeat center / contain;
	filter: drop-shadow(0 1px 1px rgba(50,30,6,.4));
	opacity: .9;
	pointer-events: none;
}


/* ════════════════════════════════════════════════════════════════════════════
   8 · MOTIF LIBRARY — reusable WHITE SVG data-URI masks (recoloured by tokens)
   ──────────────────────────────────────────────────────────────────────────
   Each motif is a tileable white shape. It is applied via `mask`, so the
   visible colour comes from the element's gilt `background` — fully themeable.
   These are the *defaults* (= Crimson Decree baseline); families below remap
   --motif-mask / --corner-mask. NO emoji, NO clip-art: every path is
   hand-vectored from a real manuscript motif.
   Tokens declared here: --motif-mask-default / --motif-size / --corner-mask-
   default / --basdepage-mask-default / --sprig-mask-default /
   --flourish-mask-default  (the live --motif-mask etc. default to these).
   ════════════════════════════════════════════════════════════════════════ */
.sc2-scroll {

	/* — DEFAULT BAND: running acanthus wave (Crimson Decree baseline) — */
	--motif-mask-default: url("data:image/svg+xml;utf8,\
<svg xmlns='http://www.w3.org/2000/svg' width='48' height='48' viewBox='0 0 48 48'>\
<path fill='%23fff' d='M0 24 C8 8 16 8 24 24 C32 40 40 40 48 24 L48 30 C40 46 32 46 24 30 C16 14 8 14 0 30 Z'/>\
<path fill='%23fff' d='M24 24 c3-7 9-9 13-5 -5 0-8 4-8 9z'/>\
<circle fill='%23fff' cx='6' cy='27' r='2.4'/><circle fill='%23fff' cx='42' cy='21' r='2.4'/>\
</svg>");
	--motif-mask: var(--motif-mask-default);
	--motif-size: 38px 38px;

	/* — DEFAULT CORNER: foliate boss with a central pellet — */
	--corner-mask-default: url("data:image/svg+xml;utf8,\
<svg xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'>\
<path fill='%23fff' d='M4 4 H30 C30 18 18 30 4 30 Z'/>\
<path fill='%23fff' d='M8 8 C28 8 34 14 34 34 C34 24 24 16 8 16z'/>\
<path fill='%23fff' d='M34 8 C46 8 56 18 56 30 C44 30 34 20 34 8z'/>\
<path fill='%23fff' d='M8 34 C8 46 18 56 30 56 C30 44 20 34 8 34z'/>\
<circle fill='%23fff' cx='17' cy='17' r='4.5'/>\
</svg>");
	--corner-mask: var(--corner-mask-default);

	/* — DEFAULT SPRIG: small leafy escape for the versal — */
	--sprig-mask-default: url("data:image/svg+xml;utf8,\
<svg xmlns='http://www.w3.org/2000/svg' width='40' height='40' viewBox='0 0 40 40'>\
<path fill='%23fff' d='M34 36 C20 32 8 22 6 6 C20 8 30 18 34 36z'/>\
<path fill='%23fff' d='M16 14 c-2-5-8-7-12-6 4 4 8 6 12 6z'/>\
<circle fill='%23fff' cx='6' cy='6' r='2.6'/>\
</svg>");
	--sprig-mask: var(--sprig-mask-default);

	/* — DEFAULT FLOURISH: symmetrical two-leaf swash with a centre node — */
	--flourish-mask-default: url("data:image/svg+xml;utf8,\
<svg xmlns='http://www.w3.org/2000/svg' width='220' height='22' viewBox='0 0 220 22'>\
<path fill='%23fff' d='M110 4 c-18 0-30 6-46 10 14 1 30-2 46-4 16 2 32 5 46 4 -16-4-28-10-46-10z'/>\
<path fill='%23fff' d='M64 14 c-14 4-30 2-42-4 14-1 30 0 42 4z'/>\
<path fill='%23fff' d='M156 14 c14 4 30 2 42-4 -14-1-30 0-42 4z'/>\
<circle fill='%23fff' cx='110' cy='11' r='4'/>\
</svg>");
	--flourish-mask: var(--flourish-mask-default);

	/* — DEFAULT BAS-DE-PAGE: wide foliate cartouche — */
	--basdepage-mask-default: url("data:image/svg+xml;utf8,\
<svg xmlns='http://www.w3.org/2000/svg' width='320' height='40' viewBox='0 0 320 40'>\
<path fill='%23fff' d='M160 6 C120 6 96 20 60 24 C96 30 130 24 160 18 C190 24 224 30 260 24 C224 20 200 6 160 6z'/>\
<path fill='%23fff' d='M60 24 C40 28 20 26 6 18 C24 16 44 18 60 24z'/>\
<path fill='%23fff' d='M260 24 C280 28 300 26 314 18 C296 16 276 18 260 24z'/>\
<circle fill='%23fff' cx='160' cy='13' r='5'/>\
</svg>");
	--basdepage-mask: var(--basdepage-mask-default);
}


/* ════════════════════════════════════════════════════════════════════════════
   9 · PER-FAMILY MOTIF OVERRIDES  (BAND + corner only — palette stays in
       sf-tokens). Selected by [data-family] AND mirrored by [data-motif] so
       the renderer can drive either hook. Each motif = a hand-vectored white
       shape recoloured by the family's gilt tokens.
   ════════════════════════════════════════════════════════════════════════ */

/* ── HIBERNIAN KNOTWORK · motif=interlace · corners=knot ──────────────────── */
.sc2-scroll[data-family="hibernian_knotwork"],
.sc2-scroll[data-motif="celtic-interlace"],
.sc2-scroll[data-motif="interlace"] {
	--motif-size: 40px 40px;
	--motif-mask: url("data:image/svg+xml;utf8,\
<svg xmlns='http://www.w3.org/2000/svg' width='40' height='40' viewBox='0 0 40 40'>\
<g fill='none' stroke='%23fff' stroke-width='5' stroke-linecap='round'>\
<path d='M0 8 C12 8 12 32 24 32 C36 32 36 8 48 8'/>\
<path d='M0 32 C12 32 12 8 24 8 C36 8 36 32 48 32'/>\
</g></svg>");
	--corner-mask: url("data:image/svg+xml;utf8,\
<svg xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'>\
<g fill='none' stroke='%23fff' stroke-width='6' stroke-linecap='round'>\
<path d='M10 10 C34 10 34 34 10 34 M10 10 C10 34 34 34 34 10 M34 10 C34 34 54 34 54 54'/>\
<circle cx='20' cy='20' r='9'/></g></svg>");
}

/* ── NORTHERN GOTHIC · motif=tracery · corners=crocket ───────────────────── */
.sc2-scroll[data-family="northern_gothic"],
.sc2-scroll[data-motif="gothic-tracery"],
.sc2-scroll[data-motif="tracery"] {
	--motif-size: 36px 44px;
	--motif-mask: url("data:image/svg+xml;utf8,\
<svg xmlns='http://www.w3.org/2000/svg' width='36' height='44' viewBox='0 0 36 44'>\
<path fill='%23fff' d='M18 2 L30 16 V42 H22 V24 A4 4 0 0 0 14 24 V42 H6 V16 Z'/>\
<path fill='%23fff' d='M18 6 a8 8 0 0 1 8 8 H10 a8 8 0 0 1 8-8z'/>\
<circle fill='%23fff' cx='18' cy='15' r='3'/></svg>");
	--corner-mask: url("data:image/svg+xml;utf8,\
<svg xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'>\
<path fill='%23fff' d='M8 56 V20 L24 6 L40 20 V56 H30 V30 a6 6 0 0 0-12 0 V56z'/>\
<path fill='%23fff' d='M24 6 c8 0 8-6 16-6 -4 6-2 10-16 10z'/>\
<path fill='%23fff' d='M40 20 c8 0 14 6 14 14 -8-2-14-6-14-14z'/></svg>");
}

/* ── PROVENÇAL BESTIARY · motif=foliate rinceaux · corners=beast ─────────── */
.sc2-scroll[data-family="provencal_bestiary"],
.sc2-scroll[data-motif="foliate-rinceaux"],
.sc2-scroll[data-motif="foliate"] {
	--motif-size: 44px 40px;
	--motif-mask: url("data:image/svg+xml;utf8,\
<svg xmlns='http://www.w3.org/2000/svg' width='44' height='40' viewBox='0 0 44 40'>\
<path fill='%23fff' d='M2 20 C10 6 18 6 22 20 C26 34 34 34 42 20 L42 26 C34 40 26 40 22 26 C18 12 10 12 2 26z'/>\
<path fill='%23fff' d='M22 20 c4-8 12-8 16-2 -6-2-12 0-16 2z'/>\
<path fill='%23fff' d='M22 20 c-4-8-12-8-16-2 6-2 12 0 16 2z'/>\
<circle fill='%23fff' cx='22' cy='20' r='3'/></svg>");
	--corner-mask: url("data:image/svg+xml;utf8,\
<svg xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'>\
<path fill='%23fff' d='M6 6 C30 6 44 18 44 44 C44 22 26 12 6 12z'/>\
<path fill='%23fff' d='M44 44 c10-4 16-14 14-26 -8 6-12 16-14 26z'/>\
<path fill='%23fff' d='M6 30 c-2 12 4 22 16 26 -6-10-10-18-16-26z'/>\
<circle fill='%23fff' cx='16' cy='16' r='5'/></svg>");
}

/* ── CRIMSON DECREE · motif=decree-fleur/acanthus · corners=boss (=DEFAULT) ─ */
.sc2-scroll[data-family="crimson_decree"],
.sc2-scroll[data-motif="decree-fleur"],
.sc2-scroll[data-motif="acanthus"] {
	--motif-mask: var(--motif-mask-default);
	--corner-mask: var(--corner-mask-default);
	--motif-size: 38px 38px;
}

/* ── FOREST REVERIE · motif=vine interlace · corners=leaf ────────────────── */
.sc2-scroll[data-family="forest_reverie"],
.sc2-scroll[data-motif="vine-interlace"],
.sc2-scroll[data-motif="vine"] {
	--motif-size: 42px 38px;
	--motif-mask: url("data:image/svg+xml;utf8,\
<svg xmlns='http://www.w3.org/2000/svg' width='42' height='38' viewBox='0 0 42 38'>\
<path fill='none' stroke='%23fff' stroke-width='3' stroke-linecap='round' d='M0 19 C10 8 16 8 21 19 C26 30 32 30 42 19'/>\
<path fill='%23fff' d='M11 12 c-3-5-9-6-11-3 4 5 8 6 11 3z'/>\
<path fill='%23fff' d='M31 26 c3 5 9 6 11 3 -4-5-8-6-11-3z'/>\
<path fill='%23fff' d='M21 19 c0-6 4-9 9-9 -3 4-5 7-9 9z'/></svg>");
	--corner-mask: url("data:image/svg+xml;utf8,\
<svg xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'>\
<path fill='none' stroke='%23fff' stroke-width='4' stroke-linecap='round' d='M6 6 C30 6 40 20 40 44'/>\
<path fill='%23fff' d='M6 6 c10-2 16 4 16 14 -8-2-13-7-16-14z'/>\
<path fill='%23fff' d='M40 44 c-2-10 4-16 14-16 -2 8-7 13-14 16z'/>\
<path fill='%23fff' d='M22 22 c8-2 14 2 16 10 -8 0-13-4-16-10z'/></svg>");
}

/* ── CHARRED EDICT · motif=ember-scroll · corners=char ───────────────────── */
.sc2-scroll[data-family="charred_edict"],
.sc2-scroll[data-motif="ember-scroll"],
.sc2-scroll[data-motif="ember"] {
	--motif-size: 36px 40px;
	--motif-mask: url("data:image/svg+xml;utf8,\
<svg xmlns='http://www.w3.org/2000/svg' width='36' height='40' viewBox='0 0 36 40'>\
<path fill='%23fff' d='M18 2 C24 12 30 16 30 26 a12 12 0 0 1-24 0 C6 16 12 12 18 2z'/>\
<path fill='%23fff' opacity='.7' d='M18 14 c3 5 6 7 6 12 a6 6 0 0 1-12 0 c0-5 3-7 6-12z'/>\
</svg>");
	--corner-mask: url("data:image/svg+xml;utf8,\
<svg xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'>\
<path fill='%23fff' d='M14 4 C26 18 38 22 38 38 a18 18 0 0 1-36 0 C2 24 8 16 14 4z'/>\
<path fill='%23fff' d='M42 28 c8 6 12 14 8 24 -8-2-12-12-8-24z'/></svg>");
}

/* ── IMPERIAL EDICT · motif=imperial-acanthus/meander · corners=eagle-key ── */
.sc2-scroll[data-family="imperial_edict"],
.sc2-scroll[data-motif="imperial-acanthus"],
.sc2-scroll[data-motif="laurel"] {
	--motif-size: 30px 30px;            /* Greek-key meander reads best tight   */
	--motif-mask: url("data:image/svg+xml;utf8,\
<svg xmlns='http://www.w3.org/2000/svg' width='30' height='30' viewBox='0 0 30 30'>\
<path fill='none' stroke='%23fff' stroke-width='4' d='M3 3 H27 V27 H9 V9 H21 V21 H15'/>\
</svg>");
	--corner-mask: url("data:image/svg+xml;utf8,\
<svg xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'>\
<path fill='none' stroke='%23fff' stroke-width='5' d='M6 6 H58 V58 M6 6 V20 H44 V44'/>\
<path fill='%23fff' d='M6 30 c10 0 16 6 16 16 C12 46 6 40 6 30z'/>\
<circle fill='%23fff' cx='14' cy='14' r='5'/></svg>");
}

/* ── SCHOLAR'S HAND · motif=diaper rule · corners=rosette (restrained) ───── */
.sc2-scroll[data-family="scholars_hand"],
.sc2-scroll[data-motif="scholar-rule"],
.sc2-scroll[data-motif="diaper"] {
	--motif-size: 28px 28px;
	--motif-mask: url("data:image/svg+xml;utf8,\
<svg xmlns='http://www.w3.org/2000/svg' width='28' height='28' viewBox='0 0 28 28'>\
<path fill='none' stroke='%23fff' stroke-width='2' d='M0 14 L14 0 L28 14 L14 28 Z'/>\
<circle fill='%23fff' cx='14' cy='14' r='2.5'/>\
<circle fill='%23fff' cx='0' cy='14' r='1.6'/><circle fill='%23fff' cx='28' cy='14' r='1.6'/>\
<circle fill='%23fff' cx='14' cy='0' r='1.6'/><circle fill='%23fff' cx='14' cy='28' r='1.6'/>\
</svg>");
	--corner-mask: url("data:image/svg+xml;utf8,\
<svg xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'>\
<g fill='%23fff'><circle cx='20' cy='20' r='6'/>\
<path d='M20 6 a14 14 0 0 1 0 28 a14 14 0 0 1 0-28z M20 10 a10 10 0 0 0 0 20 a10 10 0 0 0 0-20z'/>\
<path d='M20 0 v6 M20 34 v6 M0 20 h6 M34 20 h6'/></g></svg>");
}

/* ── CRUSADER'S CHARTER · motif=cross-fleur · corners=shield ─────────────── */
.sc2-scroll[data-family="crusaders_charter"],
.sc2-scroll[data-motif="cross-fleur"],
.sc2-scroll[data-motif="cross"] {
	--motif-size: 34px 34px;
	--motif-mask: url("data:image/svg+xml;utf8,\
<svg xmlns='http://www.w3.org/2000/svg' width='34' height='34' viewBox='0 0 34 34'>\
<path fill='%23fff' d='M14 3 H20 V14 H31 V20 H20 V31 H14 V20 H3 V14 H14 Z'/>\
<path fill='%23fff' d='M14 14 l3-3 3 3 -3 3z' opacity='.6'/></svg>");
	--corner-mask: url("data:image/svg+xml;utf8,\
<svg xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'>\
<path fill='%23fff' d='M14 6 H50 V34 C50 48 34 56 32 56 C30 56 14 48 14 34 Z'/>\
<path fill='%23fff' d='M28 16 H36 V24 H44 V32 H36 V44 H28 V32 H20 V24 H28 Z' opacity='.55'/></svg>");
}

/* ── ASTRAL CODEX · motif=constellation tracery · corners=celestial ─────── */
.sc2-scroll[data-family="astral_codex"],
.sc2-scroll[data-motif="constellation-tracery"],
.sc2-scroll[data-motif="star"] {
	--motif-size: 34px 34px;
	--motif-mask: url("data:image/svg+xml;utf8,\
<svg xmlns='http://www.w3.org/2000/svg' width='34' height='34' viewBox='0 0 34 34'>\
<path fill='%23fff' d='M17 2 L20 14 L32 17 L20 20 L17 32 L14 20 L2 17 L14 14 Z'/>\
<circle fill='%23fff' cx='5' cy='6' r='1.6'/><circle fill='%23fff' cx='29' cy='28' r='1.6'/>\
<circle fill='%23fff' cx='30' cy='5' r='1.1'/><circle fill='%23fff' cx='4' cy='29' r='1.1'/>\
</svg>");
	--corner-mask: url("data:image/svg+xml;utf8,\
<svg xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'>\
<path fill='%23fff' d='M18 4 L22 16 L34 20 L22 24 L18 36 L14 24 L2 20 L14 16 Z'/>\
<path fill='none' stroke='%23fff' stroke-width='2' d='M40 8 a20 20 0 0 1 16 16'/>\
<circle fill='%23fff' cx='46' cy='14' r='2.4'/><circle fill='%23fff' cx='54' cy='30' r='1.8'/>\
<circle fill='%23fff' cx='10' cy='44' r='1.8'/></svg>");
}

/* Astral Codex inverts to a dark ground — keep ornament reading as silver/gold
   over the night substrate (palette handled in tokens; here we lift opacity so
   the constellation band stays legible on the darker vellum). */
.sc2-scroll[data-family="astral_codex"] .sc2-band,
.sc2-scroll[data-family="astral_codex"] .sc2-corner { opacity: 1; }


/* ════════════════════════════════════════════════════════════════════════════
   10 · MOTION (subtle, respects reduced-motion) — a faint gilt shimmer on the
        band when the scroll is freshly rendered. Decorative only; off in
        export/print and for users who ask for less motion.
   ════════════════════════════════════════════════════════════════════════ */
@media (prefers-reduced-motion: no-preference) {
	.sc2-scroll:not(.sc2-export) .sc2-band {
		animation: sc2-gild-breathe 9s ease-in-out infinite alternate;
	}
}
@keyframes sc2-gild-breathe {
	from { filter: drop-shadow(0 1px 1px rgba(50,32,8,.35)) brightness(1); }
	to   { filter: drop-shadow(0 1px 1px rgba(50,32,8,.35)) brightness(1.06); }
}


/* ════════════════════════════════════════════════════════════════════════════
   11 · EXPORT / PRINT FLATTENING (structure untouched; only flatten texture)
   ──────────────────────────────────────────────────────────────────────────
   mask-composite & background-clip:text are unreliable in html2canvas / some
   PDF engines. In export/print we keep the bar + rule + ornament colour but
   drop the centre-knockout composite (which can render solid) and freeze
   animation. The gilt-text fallback above already handles title/versal.
   ════════════════════════════════════════════════════════════════════════ */
.sc2-export .sc2-band,
.sc2-scroll.sc2-export .sc2-band {
	-webkit-mask: var(--motif-mask, var(--motif-mask-default)) repeat;
	mask: var(--motif-mask, var(--motif-mask-default)) repeat;
	-webkit-mask-size: var(--motif-size, 38px 38px);
	mask-size: var(--motif-size, 38px 38px);
	-webkit-mask-composite: source-over;
	mask-composite: add;
	animation: none;
	border-color: transparent;
}

@media print {
	.sc2-band { animation: none; }
	/* Ensure ornament & gilt actually ink on paper. */
	.sc2-illum,
	.sc2-band,
	.sc2-corner,
	.sc2-versal,
	.sc2-rule,
	.sc2-flourish,
	.sc2-basdepage {
		-webkit-print-color-adjust: exact;
		print-color-adjust: exact;
	}
}


/* ════════════════════════════════════════════════════════════════════════════
   12 · DEFENSIVE GUARDS  (graceful degradation for missing data / old engines)
   ════════════════════════════════════════════════════════════════════════ */

/* If `mask` is unsupported, the band/corner backgrounds would flood as solid
   gold rectangles. Fall back to a tasteful solid gilt frame (still "illumined")
   instead of an ugly block. */
@supports not ((-webkit-mask: url("#x")) or (mask: url("#x"))) {
	.sc2-band {
		background: transparent;
		border-color: var(--gold);
		box-shadow: var(--gilt-relief);
	}
	.sc2-corner,
	.sc2-basdepage,
	.sc2-flourish,
	.sc2-versal::after { display: none; }
}

/* If color-mix is unsupported the versal ground falls back to the flat jewel
   tone (still framed in gold) rather than disappearing. */
@supports not (background: color-mix(in srgb, red, blue)) {
	.sc2-versal::before {
		background:
			radial-gradient(120% 120% at 30% 25%,
				var(--initial-ground), var(--initial-ground));
	}
}

/* Reduce the band/corner footprint on very small viewports so ornament never
   crowds the lettering on a phone. */
@media (max-width: 480px) {
	.sc2-illum { --zone-band: calc(var(--band-w, 40px) - 12px); }
	.sc2-corner {
		width:  calc(var(--corner-size, 72px) * .7);
		height: calc(var(--corner-size, 72px) * .7);
	}
	.sc2-basdepage { display: none; }
}

/* ===== inlined: sf-typography.css.part ===== */
/* ============================================================================
   THE LETTERED SCROLL — sf-typography.css.part
   ----------------------------------------------------------------------------
   THE TYPE SYSTEM for the HTML/CSS/inline-SVG scroll renderer ("scroll-forge").
   Owns ONLY typography: the lettered document inside `.sc2-content`.

   CONSUMES the token NAMES defined in sf-tokens.css.part VERBATIM
   (--ff-title, --ff-body, --ff-sign, --ink, --rubric, --gold*, the --fs-*
   scale, the --ls-* tracking). It does NOT re-declare palette/substrate/seal
   tokens and it NEVER touches z-index, layout geometry, or the border bands.

   The Google Fonts @import already lives at the TOP of sf-tokens.css.part
   (CSS spec: @import must precede all rules; one shared request for the fleet).
   This partial therefore does NOT re-import — a duplicate @import after other
   rules is silently dropped by the cascade and wastes a round-trip.

   HARD TYPE LAWS (locked by the design system):
     1. Display blackletter / uncial / Pirata are TITLES ONLY. They are
        unreadable as body copy and several are 400-weight only — never bolded.
     2. Body is humanist/chancery, JUSTIFIED, with real ligatures + old-style
        figures. Justify WITHOUT hyphenation is FORBIDDEN (rivers) — hyphens
        are always on for justified runs.
     3. The opening word of the body takes an illuminated VERSAL drop-cap.
     4. The recipient name + the proclamation opener are RUBRICATED (vermilion)
        — used on those two surfaces only.
     5. Ink is warm sepia (var(--ink)) — never #000.
     6. font-synthesis:none everywhere so a missing weight/italic fails to a
        real fallback face rather than a smeared synthetic.

   All selectors are scoped under `.sc2-scroll` so app dark-mode chrome cannot
   reach the lettered surface and global orkui rules cannot leak in.
   ============================================================================ */


/* ── 0 · BODY-FACE PER FAMILY ────────────────────────────────────────────────
   The token file overrides only --ff-title per family (per its scoping
   contract). Body voice still differs by family (Cardo for the Insular hands,
   IM Fell for the burnt/crusader charters, Gentium for the scholar). Those are
   font-stack-only nudges — squarely typography's domain, touching no palette,
   geometry, or z-index — so they live here, keyed off the same data-family
   hook, and fall back to the token default if a family is unknown.            */
.sc2-scroll[data-family="hibernian_knotwork"] { --ff-body: "Cardo","EB Garamond","IM Fell English",Garamond,Georgia,serif; }
.sc2-scroll[data-family="forest_reverie"]     { --ff-body: "Cardo","EB Garamond","IM Fell English",Garamond,Georgia,serif; }
.sc2-scroll[data-family="charred_edict"]      { --ff-body: "IM Fell English","EB Garamond",Garamond,Georgia,serif; }
.sc2-scroll[data-family="crusaders_charter"]  { --ff-body: "IM Fell English","EB Garamond",Garamond,Georgia,serif; }
.sc2-scroll[data-family="scholars_hand"]      { --ff-body: "Gentium Book Plus","Cardo","EB Garamond",Garamond,Georgia,serif; }


/* ── 1 · CONTENT FRAME · the only TEXT layer ─────────────────────────────────
   Inherited defaults for the whole lettered document. Width is constrained so
   justified measure stays readable (≈ 60–72ch); the substrate/border partials
   own the absolute positioning and z-order — we only set type behaviour.      */
.sc2-scroll .sc2-content {
	position: relative;
	color: var(--ink, #2a211a);
	font-family: var(--ff-body, "EB Garamond","Cardo",Garamond,Georgia,serif);
	font-size: var(--fs-body, clamp(15px, 1.15vw, 18px));
	line-height: 1.62;
	text-align: center;                 /* invocation/title/datum centre; body re-justifies */
	-webkit-font-smoothing: antialiased;
	-moz-osx-font-smoothing: grayscale;
	font-synthesis: none;               /* missing weight/italic → real fallback, not smear */
	font-kerning: normal;
	text-rendering: optimizeLegibility;
	font-variant-numeric: oldstyle-nums;
	font-feature-settings: "kern" 1, "liga" 1, "onum" 1;
	hanging-punctuation: first allow-end;
}

/* Reset the global orkui h1–h6 pill on EVERY heading inside the scroll
   (orkui.css gives all headings a grey box + border + text-shadow). We blanket
   reset here; the title re-applies its own gilt drop-shadows below. */
.sc2-scroll .sc2-content h1,
.sc2-scroll .sc2-content h2,
.sc2-scroll .sc2-content h3,
.sc2-scroll .sc2-content h4,
.sc2-scroll .sc2-content h5,
.sc2-scroll .sc2-content h6 {
	background: transparent;
	background-color: transparent;
	border: 0;
	padding: 0;
	margin: 0;
	border-radius: 0;
	text-shadow: none;
	box-shadow: none;
	font-weight: inherit;
	line-height: inherit;
}


/* ── 2 · INVOCATION · the opening salutation line ───────────────────────────
   Small, quiet, optically a breath before the title. Smallcaps face in a muted
   ink, gently tracked.                                                        */
.sc2-scroll .sc2-invocation {
	margin: 0 0 .55em;
	font-family: var(--ff-smallcaps, "IM Fell English SC","Cardo",serif);
	font-size: var(--fs-invocation, .95rem);
	font-style: normal;
	font-variant-caps: small-caps;
	font-feature-settings: "smcp" 1, "onum" 1, "liga" 1, "kern" 1;
	letter-spacing: var(--ls-invocation, .06em);
	line-height: 1.35;
	color: var(--ink-muted, #5c4632);
	text-align: center;
	text-wrap: balance;
}
/* A slim flourish rule under the invocation, drawn in ink — quiet, optional. */
.sc2-scroll .sc2-invocation::after {
	content: "";
	display: block;
	width: 2.4em;
	height: 1px;
	margin: .55em auto 0;
	background: linear-gradient(90deg, transparent, var(--ink-muted, #5c4632) 18%, var(--ink-muted, #5c4632) 82%, transparent);
	opacity: .45;
}


/* ── 3 · TITLE · the grand display name of the award ────────────────────────
   Display face per family (--ff-title), set as raised GILDING via the
   background-clip:text recipe. Blackletter is NEVER tracked wide. We re-apply
   the gilt drop-shadows the blanket heading-reset above stripped.            */
.sc2-scroll .sc2-title {
	margin: .12em auto .28em;
	max-width: 14ch;                    /* keep grand titles from sprawling      */
	font-family: var(--ff-title, "UnifrakturMaguntia","Pirata One","Times New Roman",serif);
	font-weight: 400;                   /* most display faces are 400-only       */
	font-size: var(--fs-title, clamp(40px, 6vw, 84px));
	line-height: 1.04;
	letter-spacing: var(--ls-title, .01em);
	text-align: center;
	text-wrap: balance;
	font-feature-settings: "liga" 1, "dlig" 1, "kern" 1;

	/* GILT TEXT recipe (raised gold; never flat). */
	background-image: linear-gradient(
		135deg,
		var(--gold-shadow, #6e4d08) 0%,
		var(--gold, #d4af37) 18%,
		var(--gold-hi, #fff4c2) 38%,
		var(--gold, #d4af37) 58%,
		var(--gold-deep, #a9760a) 82%,
		var(--gold-shadow, #6e4d08) 100%);
	-webkit-background-clip: text;
	background-clip: text;
	color: transparent;
	-webkit-text-fill-color: transparent;
	-webkit-text-stroke: .75px var(--gold-keyline, #5a3d0c);
	filter:
		drop-shadow(0 1px 0 var(--gold-hi, #fff4c2))
		drop-shadow(0 2px 2px rgba(40, 20, 0, .35));
	/* solid fallback colour beneath the clip, for engines without text-clip */
	-moz-text-fill-color: var(--gold, #d4af37);
}
/* Families whose title face carries a real bold may use 700; the rest stay 400.
   Grenze Gotisch (Imperial Edict, Crusader's Charter) is the only display face
   here with a true heavy weight — let it sit a touch bolder for gravitas. */
.sc2-scroll[data-family="imperial_edict"] .sc2-title,
.sc2-scroll[data-family="crusaders_charter"] .sc2-title {
	font-weight: 700;
}

/* Crimson / Northern blackletter wants a slightly tighter line + bigger ceiling. */
.sc2-scroll[data-family="crimson_decree"] .sc2-title,
.sc2-scroll[data-family="northern_gothic"] .sc2-title {
	line-height: 1.0;
	letter-spacing: 0;                  /* blackletter: never track */
}


/* ── 4 · INTITULATION · "by the grace of … the Kingdom of …" ────────────────
   Real small-caps (NEVER text-transform:uppercase — that destroys the
   letterforms). Muted ink, generous tracking, a register below the title.    */
.sc2-scroll .sc2-intitulation {
	margin: .1em auto 1.1em;
	max-width: 46ch;
	font-family: var(--ff-smallcaps, "IM Fell English SC","Cardo",serif);
	font-size: var(--fs-intitulation, 1rem);
	font-style: normal;
	font-variant-caps: small-caps;
	font-feature-settings: "smcp" 1, "c2sc" 0, "onum" 1, "liga" 1, "kern" 1;
	letter-spacing: var(--ls-intitulation, .14em);
	line-height: 1.5;
	color: var(--ink-muted, #5c4632);
	text-align: center;
	text-wrap: balance;
}
/* The realm name inside the intitulation may be lifted in colour for weight. */
.sc2-scroll .sc2-intitulation .sc2-realm {
	color: var(--ink, #2a211a);
	font-weight: 400;
}


/* ── 5 · BODY · the justified humanist prose, with the illuminated versal ───
   This is the heart of the "lettered by a person" illusion: a true justified
   measure, ligatures, old-style figures, and a drop-cap opening the first
   paragraph. Justify ALWAYS rides with hyphenation to kill rivers.           */
.sc2-scroll .sc2-body {
	margin: 0 auto 1.05em;
	max-width: 68ch;                    /* readable justified measure            */
	font-family: var(--ff-body, "EB Garamond","Cardo",Garamond,Georgia,serif);
	font-size: var(--fs-body, clamp(15px, 1.15vw, 18px));
	line-height: 1.62;
	color: var(--ink, #2a211a);
	text-align: justify;
	text-justify: inter-word;
	-webkit-hyphens: auto;
	hyphens: auto;
	-webkit-hyphenate-limit-before: 3;  /* avoid stubby leading hyphenations     */
	hyphenate-limit-chars: 6 3 3;
	orphans: 2;
	widows: 2;
	font-variant-ligatures: common-ligatures discretionary-ligatures contextual;
	font-variant-numeric: oldstyle-nums proportional-nums;
	font-feature-settings: "liga" 1, "dlig" 1, "clig" 1, "onum" 1, "kern" 1;
}
.sc2-scroll .sc2-body p {
	margin: 0 0 .7em;
}
.sc2-scroll .sc2-body p:last-child {
	margin-bottom: 0;
}
/* Subsequent paragraphs after the first get a traditional first-line indent;
   the versal paragraph is flush (the drop-cap is its indent). */
.sc2-scroll .sc2-body p + p {
	text-indent: 1.4em;
}

/* ── 5a · ILLUMINATED VERSAL · drop-cap on the body's first letter ──────────
   ONE technique: a FLOATED drop-cap at a bounded em size. We deliberately do
   NOT use CSS `initial-letter` — Chrome reports `CSS.supports('initial-letter')`
   as true but renders it incorrectly (it balloons the glyph when combined with
   a background/padding), which was the giant-versal bug. A plain float is
   100% reliable across engines and bounded by `font-size`, so the cap can never
   overrun the title. ~3 text lines tall (3.2em × 0.86 line-height). Default ink
   is vermilion (the rubricated versal); families may recolour + add a ground.  */
.sc2-scroll .sc2-body > p:first-of-type::first-letter {
	font-family: var(--ff-versal, "UnifrakturMaguntia","EB Garamond",serif);
	color: var(--rubric, #7b1f2a);
	-webkit-text-fill-color: var(--rubric, #7b1f2a);
	font-weight: 400;
	font-style: normal;
	text-transform: none;
	float: left;
	font-size: 3.2em;
	line-height: .86;
	padding: .02em .1em 0 .04em;
	margin: .06em .14em -.02em 0;
}

/* GILDED VERSAL variant — opt-in by adding .sc2-versal--gilt on .sc2-body.
   Re-letters the first glyph in raised gold instead of vermilion. */
.sc2-scroll .sc2-body.sc2-versal--gilt > p:first-of-type::first-letter {
	color: transparent;
	-webkit-text-fill-color: transparent;
	background-image: linear-gradient(
		135deg,
		var(--gold-shadow, #6e4d08) 0%,
		var(--gold, #d4af37) 20%,
		var(--gold-hi, #fff4c2) 42%,
		var(--gold, #d4af37) 62%,
		var(--gold-deep, #a9760a) 100%);
	-webkit-background-clip: text;
	background-clip: text;
	-webkit-text-stroke: .6px var(--gold-keyline, #5a3d0c);
	filter: drop-shadow(0 1px 0 var(--gold-hi, #fff4c2)) drop-shadow(0 1px 2px rgba(40,20,0,.3));
}


/* ── 6 · GRANT CLAUSE · the dispositive "we do hereby bestow …" ─────────────
   The pivot of the document. Centred, a half-step larger than body, with the
   award name carried in raised gold and the verb italicised for cadence.     */
.sc2-scroll .sc2-grant {
	margin: 1.1em auto;
	max-width: 52ch;
	font-family: var(--ff-body, "EB Garamond","Cardo",Garamond,Georgia,serif);
	font-size: var(--fs-grant, clamp(17px, 1.4vw, 22px));
	line-height: 1.5;
	color: var(--ink, #2a211a);
	text-align: center;
	text-wrap: balance;
	font-feature-settings: "liga" 1, "dlig" 1, "onum" 1, "kern" 1;
}
.sc2-scroll .sc2-grant em,
.sc2-scroll .sc2-grant .sc2-grant-verb {
	font-style: italic;
}
/* The award name inside the grant clause: raised gilt, a touch larger, in the
   display voice so it echoes the title. */
.sc2-scroll .sc2-grant .sc2-award {
	display: inline-block;
	font-family: var(--ff-title, "UnifrakturMaguntia","Pirata One",serif);
	font-weight: 400;
	font-size: 1.28em;
	line-height: 1.1;
	letter-spacing: var(--ls-title, .01em);
	background-image: linear-gradient(
		135deg,
		var(--gold-shadow, #6e4d08) 0%,
		var(--gold, #d4af37) 22%,
		var(--gold-hi, #fff4c2) 46%,
		var(--gold, #d4af37) 64%,
		var(--gold-deep, #a9760a) 100%);
	-webkit-background-clip: text;
	background-clip: text;
	color: transparent;
	-webkit-text-fill-color: transparent;
	-webkit-text-stroke: .5px var(--gold-keyline, #5a3d0c);
	filter: drop-shadow(0 1px 1px rgba(40,20,0,.3));
}
/* Award names that carry a real bold display face may go heavier to match the title. */
.sc2-scroll[data-family="imperial_edict"] .sc2-grant .sc2-award,
.sc2-scroll[data-family="crusaders_charter"] .sc2-grant .sc2-award {
	font-weight: 700;
}
/* A small gilt pilcrow may open a section — keep it subtle. */
.sc2-scroll .sc2-pilcrow {
	font-family: var(--ff-body, serif);
	color: var(--gold-deep, #a9760a);
	margin-right: .25em;
	font-style: normal;
}


/* ── 7 · RUBRICATION · vermilion runs (recipient + opener) ──────────────────
   Used on the two sanctioned surfaces only. The recipient name is the loudest
   rubric on the sheet: display-voice optional, vermilion, lightly letterspaced
   so it reads as the ceremonial focus.                                       */
.sc2-scroll .sc2-rubric,
.sc2-scroll .sc2-recipient {
	color: var(--rubric, #7b1f2a);
	-webkit-text-fill-color: var(--rubric, #7b1f2a);
	font-style: normal;
}
.sc2-scroll .sc2-recipient {
	font-family: var(--ff-body, "EB Garamond","Cardo",serif);
	font-weight: 600;
	font-size: 1.16em;
	letter-spacing: .015em;
	font-feature-settings: "liga" 1, "dlig" 1, "onum" 1, "kern" 1;
	white-space: nowrap;                /* keep the honoured name from breaking */
}
/* When the recipient is set as a standalone display flourish in the body. */
.sc2-scroll .sc2-recipient--display {
	display: block;
	margin: .15em auto .25em;
	font-family: var(--ff-title, "UnifrakturMaguntia",serif);
	font-weight: 400;
	font-size: clamp(24px, 3.2vw, 40px);
	letter-spacing: var(--ls-title, .01em);
	line-height: 1.1;
	white-space: normal;
	text-wrap: balance;
}


/* ── 8 · DATUM · "Given under our hand … in the year …" ─────────────────────
   Italic body. The date is WRITTEN OUT in the markup; we just letter it
   gracefully and keep it from overrunning.                                   */
.sc2-scroll .sc2-datum {
	margin: 1.1em auto .4em;
	max-width: 50ch;
	font-family: var(--ff-body, "EB Garamond","Cardo",serif);
	font-style: italic;
	font-size: var(--fs-datum, 1rem);
	line-height: 1.5;
	color: var(--ink-muted, #5c4632);
	text-align: center;
	text-wrap: balance;
	font-feature-settings: "liga" 1, "onum" 1, "kern" 1;
}


/* ── 9 · ATTESTATION · the chancery signatures & titles ─────────────────────
   Italic chancery, larger, with swashes where the face carries them. Each
   signatory is a block: a signed name on a ruled line, then a small-caps
   office line beneath.                                                       */
.sc2-scroll .sc2-attest {
	margin: 1.4em auto 0;
	display: flex;
	flex-wrap: wrap;
	gap: clamp(1.4em, 5vw, 3.2em);
	justify-content: center;
	align-items: flex-end;
	text-align: center;
}
.sc2-scroll .sc2-sig {
	min-width: 12em;
	max-width: 18em;
	flex: 0 1 auto;
}
/* The signed name — italic chancery hand. */
.sc2-scroll .sc2-sig-name {
	display: block;
	font-family: var(--ff-sign, "EB Garamond","Cardo","IM Fell English",serif);
	font-style: italic;
	font-weight: 400;
	font-size: var(--fs-attest, clamp(1.2rem, 1.6vw, 1.35rem));
	line-height: 1.15;
	color: var(--ink, #2a211a);
	letter-spacing: .005em;
	font-feature-settings: "liga" 1, "swsh" 1, "calt" 1, "kern" 1;
	padding: 0 .3em .14em;
	white-space: nowrap;
	overflow: hidden;
	text-overflow: ellipsis;
}
/* The ruled signature line beneath the name. */
.sc2-scroll .sc2-sig-rule {
	display: block;
	height: 1px;
	margin: 0 auto .42em;
	width: 100%;
	background: linear-gradient(90deg, transparent, var(--ink-muted, #5c4632) 12%, var(--ink-muted, #5c4632) 88%, transparent);
	opacity: .6;
}
/* The office / title line — small-caps, muted, the quiet authority beneath. */
.sc2-scroll .sc2-sig-title {
	display: block;
	font-family: var(--ff-smallcaps, "IM Fell English SC","Cardo",serif);
	font-variant-caps: small-caps;
	font-feature-settings: "smcp" 1, "onum" 1, "kern" 1;
	letter-spacing: .1em;
	font-size: .82rem;
	line-height: 1.3;
	color: var(--ink-muted, #5c4632);
	text-wrap: balance;
}
/* Optional realm line under the office (e.g. "of the Kingdom of …"). */
.sc2-scroll .sc2-sig-realm {
	display: block;
	font-family: var(--ff-body, serif);
	font-style: italic;
	font-size: .8rem;
	line-height: 1.3;
	color: var(--ink-muted, #5c4632);
	opacity: .85;
}


/* ── 10 · SHARED INLINE HELPERS ─────────────────────────────────────────────
   Small reusable inline classes the copy layer can sprinkle into runs without
   reaching for ad-hoc styles.                                                 */
.sc2-scroll .sc2-i        { font-style: italic; }
.sc2-scroll .sc2-sc       { font-variant-caps: small-caps; font-feature-settings: "smcp" 1, "onum" 1, "kern" 1; }
.sc2-scroll .sc2-nowrap   { white-space: nowrap; }
.sc2-scroll .sc2-ink      { color: var(--ink, #2a211a); -webkit-text-fill-color: var(--ink, #2a211a); }
.sc2-scroll .sc2-muted    { color: var(--ink-muted, #5c4632); -webkit-text-fill-color: var(--ink-muted, #5c4632); }
/* Inline gilt run (e.g. a date numeral or place name lifted in gold). */
.sc2-scroll .sc2-gilt {
	background-image: linear-gradient(135deg,
		var(--gold-shadow, #6e4d08) 0%, var(--gold, #d4af37) 25%,
		var(--gold-hi, #fff4c2) 50%, var(--gold, #d4af37) 70%, var(--gold-deep, #a9760a) 100%);
	-webkit-background-clip: text;
	background-clip: text;
	color: transparent;
	-webkit-text-fill-color: transparent;
	-webkit-text-stroke: .4px var(--gold-keyline, #5a3d0c);
}


/* ── 11 · DEFENSIVE EMPTY-STATE GUARDS ──────────────────────────────────────
   Be defensive about missing data: collapse empty document slots so an absent
   value never leaves a gilt drop-shadow, a stray ruled line, or vertical gaps.
   The copy layer fills these; if it cannot, they vanish cleanly.             */
.sc2-scroll .sc2-invocation:empty,
.sc2-scroll .sc2-intitulation:empty,
.sc2-scroll .sc2-grant:empty,
.sc2-scroll .sc2-datum:empty,
.sc2-scroll .sc2-body:empty { display: none; }
.sc2-scroll .sc2-title:empty {
	display: none;                      /* no empty gilt phantom */
}
.sc2-scroll .sc2-attest:empty { display: none; }
/* A signature block with no name is meaningless — drop it whole. */
.sc2-scroll .sc2-sig:not(:has(.sc2-sig-name)) { display: none; }
.sc2-scroll .sc2-sig .sc2-sig-name:empty { display: none; }
.sc2-scroll .sc2-sig .sc2-sig-name:empty + .sc2-sig-rule { display: none; }
.sc2-scroll .sc2-sig-title:empty,
.sc2-scroll .sc2-sig-realm:empty { display: none; }


/* ── 12 · ASTRAL CODEX · dark-substrate ink inversion ───────────────────────
   The only inverted family: a dark celestial vellum. Body ink must lighten to
   a warm parchment so the lettering reads. Palette tokens (--ink/--ink-muted/
   --rubric) are re-pointed by the token file's per-family block; this rule is
   a typographic SAFETY NET only — if the token override is ever absent, the
   text still reads against the dark ground. It touches font COLOUR only, no
   geometry or z-index.                                                       */
.sc2-scroll[data-family="astral_codex"] .sc2-content {
	color: var(--ink, #ece3cf);
}
.sc2-scroll[data-family="astral_codex"] .sc2-body,
.sc2-scroll[data-family="astral_codex"] .sc2-grant {
	color: var(--ink, #ece3cf);
}


/* ── 13 · EXPORT / PRINT TYPE FALLBACKS ─────────────────────────────────────
   background-clip:text degrades in html2canvas and some PDF engines (the text
   rasterises transparent → invisible). Under .sc2-export / @media print we
   FLATTEN every gilt-text surface to a solid gold fill + a keyline text-shadow
   so the lettering survives the raster. Structure/scale is untouched.        */
.sc2-scroll.sc2-export .sc2-title,
.sc2-scroll.sc2-export .sc2-grant .sc2-award,
.sc2-scroll.sc2-export .sc2-gilt,
.sc2-scroll.sc2-export .sc2-body.sc2-versal--gilt > p:first-of-type::first-letter {
	background-image: none;
	-webkit-background-clip: border-box;
	background-clip: border-box;
	color: var(--gold, #d4af37);
	-webkit-text-fill-color: var(--gold, #d4af37);
	-webkit-text-stroke: 0;
	filter: none;
	text-shadow:
		0 1px 0 var(--gold-keyline, #5a3d0c),
		0 0 1px var(--gold-shadow, #6e4d08);
}

@media print {
	.sc2-scroll .sc2-title,
	.sc2-scroll .sc2-grant .sc2-award,
	.sc2-scroll .sc2-gilt,
	.sc2-scroll .sc2-body.sc2-versal--gilt > p:first-of-type::first-letter {
		background-image: none !important;
		-webkit-background-clip: border-box !important;
		background-clip: border-box !important;
		color: var(--gold, #d4af37) !important;
		-webkit-text-fill-color: var(--gold, #d4af37) !important;
		-webkit-text-stroke: 0 !important;
		filter: none !important;
		text-shadow: 0 1px 0 var(--gold-keyline, #5a3d0c) !important;
	}
	/* Print should honour real colour for the ink + rubric — force it. */
	.sc2-scroll .sc2-content,
	.sc2-scroll .sc2-recipient,
	.sc2-scroll .sc2-rubric,
	.sc2-scroll .sc2-body > p:first-of-type::first-letter {
		-webkit-print-color-adjust: exact;
		print-color-adjust: exact;
	}
	/* Tighten body leading a hair for paged density; keep justify + hyphens. */
	.sc2-scroll .sc2-body {
		line-height: 1.5;
		orphans: 3;
		widows: 3;
	}
}


/* ── 14 · REDUCED-MOTION COURTESY ───────────────────────────────────────────
   If web-fonts fail to load, the serif fallbacks already carry the document
   and the clamps + max-ch measures absorb most FOUT reflow. Nothing animated
   lives in this partial, so reduced-motion is a no-op here by design
   (declared for auditability).                                               */
@media (prefers-reduced-motion: reduce) {
	.sc2-scroll .sc2-content * { transition: none !important; animation: none !important; }
}

/* ===== inlined: sf-heraldry-seal.css.part ===== */
/* ============================================================================
   THE LETTERED SCROLL — sf-heraldry-seal.css.part
   ----------------------------------------------------------------------------
   LAYER: HERALDRY (crowning / flanking arms) + the PENDANT WAX SEAL.
   Medium is LOCKED: semantic HTML + CSS + inline SVG. No <canvas>, no tiled
   photo textures, no flat #ffd700, no pure #fff substrate.

   This partial owns ONLY two DOM regions of the locked skeleton:

     <header class="sc2-crown">              ← heraldry achievement (z = --z-crown:5)
       <figure class="sc2-arms sc2-arms--kingdom">…<img>/<svg>…</figure>
       <figure class="sc2-arms sc2-arms--park">…<img>/<svg>…</figure>
     </header>
     <footer class="sc2-seal-wrap">          ← pendant wax seal + ribbon (z = --z-seal:6)
       <svg class="sc2-seal">…</svg>
     </footer>

   It REFERENCES (never redefines) the shared tokens authored in
   sf-tokens.css.part — verbatim names only:
     --gold --gold-hi --gold-deep --gold-shadow --gold-keyline
     --wax --wax-hi --wax-lo --ribbon-a --ribbon-b
     --arms-rim --arms-keyline --escutcheon --initial-ground
     --ink --ink-muted --rubric --vellum-hi --vellum-lo --ff-title --ff-smallcaps
     --z-crown --z-seal --t-seal
   plus the geometry tokens where they exist; each is used WITH a defensive
   fallback so this file degrades gracefully if loaded before / without the
   token partial.

   SCOPING: every rule is nested under `.sc2-scroll` so the app dark-mode theme
   can never bleed onto the vellum sheet, and so per-family
   `.sc2-scroll[data-family="…"]` token overrides flow through automatically.

   DEFENSIVE: heraldry and seal are OPTIONAL. Missing <img>, broken raster, an
   absent seal, or a single lone shield must never break layout — see the
   [hidden]/:empty/:has and .is-broken guards in §3.

   NO native title tooltips anywhere (data-tip only). NO gray h1–h6 pill: the
   legends are not headings, but we reset defensively anyway.
   ============================================================================ */


/* ════════════════════════════════════════════════════════════════════════════
   1.  HERALDRY — the achievement that crowns / flanks the title
   ════════════════════════════════════════════════════════════════════════════
   COMPOSITION (locked):
     • Kingdom arms = DEXTER (heraldic right = viewer's LEFT).
     • Park arms    = SINISTER (heraldic left = viewer's RIGHT).
     • The two figures FLANK the title on wide layouts and stack ABOVE it on
       narrow / portrait-tight layouts. The crown band sits in the top margin,
       optically a hair above the title block.
   Each <figure> is a self-contained "achievement": an escutcheon (shield)
   bearing the raster arms, a gilt rim, a fine dark keyline, and a soft cast
   shadow so the shield reads as a physical pressed-metal boss on the vellum,
   with a small small-caps legend (kingdom / park name) beneath.
   ──────────────────────────────────────────────────────────────────────────── */

.sc2-scroll .sc2-crown {
	position: relative;
	z-index: var(--z-crown, 5);
	display: flex;
	align-items: flex-start;      /* both shields share the top baseline         */
	justify-content: space-between;
	gap: clamp(12px, 4vw, 48px);
	padding: 0 clamp(8px, 3%, 28px);   /* breathe inside the band; never collide  */
	margin: 0 auto;
	width: 100%;
	pointer-events: none;          /* decorative; only the figures opt back in    */
}

/* A lone shield (only one of kingdom/park supplied) is centred so it never
   looks marooned in a corner. `.is-single` is the JS-set fallback for engines
   without :has() support. */
.sc2-scroll .sc2-crown:has(.sc2-arms:only-child),
.sc2-scroll .sc2-crown.is-single {
	justify-content: center;
}

/* ── the achievement figure ───────────────────────────────────────────────── */
.sc2-scroll .sc2-arms {
	position: relative;
	display: flex;
	flex-direction: column;
	align-items: center;
	gap: .55em;
	margin: 0;                     /* kill UA <figure> default margin             */
	flex: 0 0 auto;
	pointer-events: auto;          /* re-enable for the data-tip hover            */
	width: clamp(132px, 22%, 200px);  /* BIG & BOLD — the arms are the crowning mark */
	max-width: 44%;
	transition: transform var(--t-seal, 320ms cubic-bezier(.2,.8,.2,1));
	/* No drop-shadow: the arms sit flat on the vellum (a shadow would trace the
	   vellum-matched field patch as a rectangle, re-creating the "plaque" look). */
}

/* SYMMETRY: both shields are identical size on a shared top baseline,
   symmetric about the centred title — no per-side nudge. */

/* ── the escutcheon (shield) shell ────────────────────────────────────────────
   The raster arms live inside a heater-shield clip so any rectangular heraldry
   image reads as a proper shield. Families may swap the clip via --escutcheon
   (informational hook; JS sets the matching clipPath id on any inline SVG arms).
   The CSS heater clip-path below is the universal fallback used for the raster
   <img>. Forest Reverie / Scholar / Crusader use a vesica variant (§1b). */
/* BARE display — no gilt plaque. The field is just a vellum-matched patch that
   the arms multiply onto (see the img rule), so any WHITE in the heraldry image
   drops to the parchment. We multiply against THIS field's own background (same
   stacking context) because .sc2-page is transform-scaled and isolates blending
   from the page vellum — multiplying against the page directly would no-op. */
.sc2-scroll .sc2-arms .sc2-arms-field {
	position: relative;
	width: 100%;
	/* Fixed slot so BOTH shields render at the same visual size regardless of
	   their source image dimensions (sized by height below, centred in the slot). */
	aspect-ratio: 5 / 6;
	display: flex;
	align-items: center;
	justify-content: center;
	/* NO background patch. A transparent field means a transparent-PNG device sits
	   straight on the family's own ground (vellum / gules / void) — so there is no
	   "background square", on any family, without per-ground matching. */
	background: transparent;
}

/* the actual arms (raster OR inline svg) — same slot, contained → equal size */
.sc2-scroll .sc2-arms .sc2-arms-field > img,
.sc2-scroll .sc2-arms .sc2-arms-field > svg,
.sc2-scroll .sc2-arms .sc2-arms-field > image,
.sc2-scroll .sc2-arms .sc2-arms-field > picture {
	display: block;
	width: 100%;
	height: 100%;
	object-fit: contain;            /* whole device, centred, same slot for both     */
	mix-blend-mode: normal;
}

/* BARE-ARMS ENFORCEMENT — the white background is removed from the IMAGE DATA in
   JS (classifyArmsBg → transparent PNG), so the device just needs to sit bare on
   the ground. Neutralise every per-family treatment that would box or crop it:
   rim/frame (gilt rectangle "square thing"), ground-fill (e.g. Astral's navy,
   Crusaders' vellum — would show as a coloured rectangle), and clip (would crop a
   clean device). !important because family CSS is inlined AFTER this layer.
   Decorative crests ABOVE the arms (torse, coronet) are separate, left intact. */
.sc2-scroll .sc2-arms .sc2-arms-field,
.sc2-scroll .sc2-arms .sc2-arms-field > img,
.sc2-scroll .sc2-arms .sc2-arms-field > svg,
.sc2-scroll .sc2-arms .sc2-arms-field > image,
.sc2-scroll .sc2-arms .sc2-arms-field > picture {
	border: 0 !important;
	outline: 0 !important;
	box-shadow: none !important;
	background: transparent !important;
	clip-path: none !important;
	-webkit-clip-path: none !important;
}

/* (Removed the per-family vesica clip variant: the arms are now shown whole &
   bold on bare vellum for every family — no shield/oval silhouette clipping.) */

/* ── legend beneath the shield (kingdom / park name) ──────────────────────────
   Small-caps, muted ink. NOT a heading, but we reset the global h1–h6 pill
   defensively (orkui adds bg/border/shadow to every h-tag). */
.sc2-scroll .sc2-arms .sc2-arms__label {
	/* defensive heading-pill reset */
	background: transparent;
	border: 0;
	padding: 0;
	border-radius: 0;

	margin: 0;
	margin-top: .4em;
	min-height: 2.4em;             /* equal label slot keeps both shields on baseline */
	max-width: 14ch;
	text-align: center;
	font-family: var(--ff-smallcaps, "IM Fell English SC", "Cardo", serif);
	font-variant-caps: small-caps;
	font-feature-settings: "smcp" 1, "onum" 1, "kern" 1;
	letter-spacing: .08em;
	line-height: 1.12;
	font-size: clamp(.58rem, 1.05vw, .76rem);
	color: var(--ink, #2a211a);
	text-wrap: balance;
	overflow-wrap: anywhere;       /* never overflow the figure on a long name     */
	/* a hair of vellum highlight under the cap to tie the legend to the rim       */
	text-shadow: 0 1px 0 rgba(255, 250, 220, .45);
}

/* a small gilt fleuron divider above the legend — pure CSS, no glyph dependency */
.sc2-scroll .sc2-arms .sc2-arms__label::before {
	content: "";
	display: block;
	width: 38%;
	height: 2px;
	margin: 0 auto .4em;
	border-radius: 2px;
	background:
		linear-gradient(90deg,
			transparent 0%,
			var(--gold-deep, #a9760a) 22%,
			var(--gold-hi, #fff4c2) 50%,
			var(--gold-deep, #a9760a) 78%,
			transparent 100%);
	opacity: .9;
}

/* an optional muted sub-label (e.g. "Kingdom" / "Park") under the name */
.sc2-scroll .sc2-arms .sc2-arms-kicker {
	margin: -.1em 0 0;
	font-family: var(--ff-smallcaps, "IM Fell English SC", "Cardo", serif);
	font-variant-caps: all-small-caps;
	letter-spacing: .18em;
	font-size: clamp(.46rem, .8vw, .58rem);
	color: var(--ink-muted, #5c4632);
	opacity: .72;
}


/* ════════════════════════════════════════════════════════════════════════════
   2.  THE PENDANT WAX SEAL  (.sc2-seal-wrap + .sc2-seal-disc / .sc2-seal SVG)
   ════════════════════════════════════════════════════════════════════════════
   A real pressed-wax seal hangs in the bas-de-page beneath the attestation,
   built as a layered radial wax disc with:
     • molten radial-gradient body (catch-light upper-left, pooled centre/rim),
     • a raised milled rim with highlight + inner shadow,
     • an embossed sigil (the player's device / a heraldic charge / monogram),
     • ribbon tails in the livery colours hanging from behind the disc.
   The DISC + RIM + EMBOSS modelling is CSS so it themes instantly from the
   --wax* tokens; the SIGIL is provided by markup/JS as inline SVG or a tinted
   raster, and we frame + emboss it here.
   ──────────────────────────────────────────────────────────────────────────── */

.sc2-scroll .sc2-seal-wrap {
	position: relative;
	z-index: var(--z-seal, 6);
	display: flex;
	flex-direction: column;
	align-items: center;
	justify-content: center;
	/* hang slightly into the bottom margin so it overlaps the bas-de-page, the
	   way a pendant seal overlaps the foot of a real charter.                    */
	margin: clamp(10px, 2.4vw, 28px) auto 0;
	width: 100%;
	pointer-events: none;
}

/* ── RIBBON TAILS — behind the disc, two livery-coloured tails ──────────────── */
.sc2-scroll .sc2-seal-ribbon {
	position: relative;
	z-index: 0;
	display: flex;
	justify-content: center;
	width: clamp(96px, 17%, 168px);
	height: clamp(34px, 5vw, 54px);
	margin-bottom: calc(-1 * clamp(54px, 9vw, 92px));  /* tuck under the disc      */
	pointer-events: none;
	filter: drop-shadow(0 4px 5px rgba(40, 26, 8, .30));
}

.sc2-scroll .sc2-seal-ribbon .sc2-ribbon-tail {
	width: clamp(20px, 3.4vw, 34px);
	height: 100%;
	/* fishtail-notched bottom edge                                              */
	clip-path: polygon(0 0, 100% 0, 100% 80%, 50% 60%, 0 80%);
	-webkit-clip-path: polygon(0 0, 100% 0, 100% 80%, 50% 60%, 0 80%);
	box-shadow: inset 0 0 6px rgba(0, 0, 0, .22);
	border-radius: 1px;
}
.sc2-scroll .sc2-seal-ribbon .sc2-ribbon-tail--a {
	background:
		linear-gradient(100deg,
			rgba(255, 255, 255, .22) 0%,
			var(--ribbon-a, #7b1f2a) 30%,
			color-mix(in srgb, var(--ribbon-a, #7b1f2a) 78%, #000 22%) 100%);
	transform: rotate(-7deg) translateX(14%);
	transform-origin: top center;
}
.sc2-scroll .sc2-seal-ribbon .sc2-ribbon-tail--b {
	background:
		linear-gradient(80deg,
			rgba(255, 255, 255, .30) 0%,
			var(--ribbon-b, #d4af37) 32%,
			color-mix(in srgb, var(--ribbon-b, #d4af37) 72%, #5a3d0c 28%) 100%);
	transform: rotate(7deg) translateX(-14%);
	transform-origin: top center;
}

/* ── THE WAX DISC ─────────────────────────────────────────────────────────────
   A round pressed blob. We deliberately break it from a perfect circle with a
   slightly irregular border-radius so it reads as poured wax, not a button.   */
.sc2-scroll .sc2-seal-disc {
	position: relative;
	z-index: 1;
	width: clamp(96px, 15vw, 150px);
	aspect-ratio: 1 / 1;
	border-radius: 49% 51% 52% 48% / 50% 47% 53% 50%;  /* hand-poured silhouette  */
	/* molten body: catch-light upper-left, deep pooled centre + rim             */
	background:
		radial-gradient(120% 120% at 34% 30%,
			var(--wax-hi, #c0392b) 0%,
			var(--wax, #8c1d1b) 34%,
			color-mix(in srgb, var(--wax, #8c1d1b) 80%, #000 20%) 72%,
			var(--wax-lo, #5a0f0f) 100%);
	box-shadow:
		/* raised milled rim: bright top-left lip, dark bottom-right recess        */
		inset 0 3px 5px rgba(255, 255, 255, .26),
		inset 3px 4px 8px rgba(255, 200, 180, .14),
		inset -4px -5px 12px rgba(0, 0, 0, .50),
		inset 0 0 0 4px color-mix(in srgb, var(--wax-lo, #5a0f0f) 70%, transparent),
		/* the disc casts onto the vellum                                          */
		0 6px 10px rgba(40, 10, 8, .42),
		0 2px 3px rgba(40, 10, 8, .34);
	display: grid;
	place-items: center;
	pointer-events: auto;          /* allow the data-tip hover on the seal        */
	filter: saturate(1.04);
	transition: transform var(--t-seal, 320ms cubic-bezier(.2,.8,.2,1));
}

/* milled / scalloped rim notches around the disc edge (cog-pressed wax) */
.sc2-scroll .sc2-seal-disc::before {
	content: "";
	position: absolute;
	inset: 4%;
	border-radius: inherit;
	pointer-events: none;
	/* a ring of fine radial notches via conic stripes, masked to a thin annulus  */
	background:
		repeating-conic-gradient(
			from 0deg,
			rgba(0, 0, 0, .22) 0deg 2deg,
			rgba(255, 220, 200, .10) 2deg 4deg);
	-webkit-mask: radial-gradient(circle, transparent 0 78%, #000 80% 92%, transparent 94%);
	        mask: radial-gradient(circle, transparent 0 78%, #000 80% 92%, transparent 94%);
	opacity: .55;
	mix-blend-mode: overlay;
}

/* the recessed inner pan that the sigil is pressed into */
.sc2-scroll .sc2-seal-disc::after {
	content: "";
	position: absolute;
	inset: 18%;
	border-radius: 50%;
	pointer-events: none;
	box-shadow:
		inset 0 2px 4px rgba(0, 0, 0, .55),
		inset 0 -2px 3px rgba(255, 210, 190, .18);
	background:
		radial-gradient(circle at 40% 35%,
			color-mix(in srgb, var(--wax-hi, #c0392b) 50%, var(--wax, #8c1d1b)) 0%,
			var(--wax, #8c1d1b) 55%,
			var(--wax-lo, #5a0f0f) 100%);
}

/* ── THE EMBOSSED SIGIL ────────────────────────────────────────────────────────
   The device pressed into the wax. Supplied by markup/JS as one of:
     <div class="sc2-seal-sigil"><svg>…</svg></div>   (preferred — paths emboss)
     <div class="sc2-seal-sigil"><img …></div>        (raster device, tinted)
     <div class="sc2-seal-sigil" data-monogram="AK"></div>  (text fallback)
   We tint it to the wax body and apply a dual drop-shadow so it reads as raised
   relief stamped into the molten surface.                                      */
.sc2-scroll .sc2-seal-sigil {
	position: relative;
	z-index: 2;
	width: 58%;
	height: 58%;
	display: grid;
	place-items: center;
	pointer-events: none;
	/* monochrome-ize the device toward the wax, then emboss with a two-tone shadow */
	color: color-mix(in srgb, var(--wax-hi, #c0392b) 62%, var(--wax, #8c1d1b));
	filter:
		drop-shadow(0 -1px 0 rgba(0, 0, 0, .55))
		drop-shadow(0 1px 0 rgba(255, 215, 195, .30));
}

.sc2-scroll .sc2-seal-sigil > svg,
.sc2-scroll .sc2-seal-sigil > img {
	display: block;
	width: 100%;
	height: 100%;
	object-fit: contain;
}

/* inline SVG sigil: force every path to the embossing tint (overrides asset fills) */
.sc2-scroll .sc2-seal-sigil > svg,
.sc2-scroll .sc2-seal-sigil > svg * {
	fill: currentColor !important;
	stroke: color-mix(in srgb, var(--wax-lo, #5a0f0f) 70%, #000) !important;
	stroke-width: .4;
	vector-effect: non-scaling-stroke;
}

/* raster device: knock it down to the wax tone via blend + low opacity */
.sc2-scroll .sc2-seal-sigil > img {
	mix-blend-mode: multiply;
	opacity: .82;
	filter: sepia(.5) saturate(2) hue-rotate(-18deg) brightness(.85) contrast(1.05);
}

/* monogram text fallback when no device exists */
.sc2-scroll .sc2-seal-sigil[data-monogram]::before {
	content: attr(data-monogram);
	font-family: var(--ff-title, "UnifrakturMaguntia", "Pirata One", serif);
	font-size: clamp(1.4rem, 4.4vw, 2.6rem);
	line-height: 1;
	letter-spacing: -.02em;
	color: inherit;
	text-shadow:
		0 -1px 0 rgba(0, 0, 0, .55),
		0 1px 0 rgba(255, 215, 195, .30);
}

/* an optional pressed legend ring around the sigil (e.g. realm motto), if the
   markup delivers it as inline SVG <text> inside the disc. */
.sc2-scroll .sc2-seal-legend {
	position: absolute;
	inset: 0;
	z-index: 2;
	pointer-events: none;
	font-family: var(--ff-smallcaps, "IM Fell English SC", "Cardo", serif);
	fill: color-mix(in srgb, var(--wax-hi, #c0392b) 55%, var(--wax, #8c1d1b));
	letter-spacing: .12em;
	opacity: .8;
	filter:
		drop-shadow(0 -.5px 0 rgba(0, 0, 0, .5))
		drop-shadow(0 .5px 0 rgba(255, 215, 195, .25));
}

/* a small caption beneath the seal (e.g. "Sealed at <park>") — small-caps, muted */
.sc2-scroll .sc2-seal-caption {
	/* defensive heading-pill reset (in case it is wrapped in an h-tag) */
	background: transparent;
	border: 0;
	padding: 0;
	border-radius: 0;
	text-shadow: none;

	margin: .7em 0 0;
	text-align: center;
	font-family: var(--ff-smallcaps, "IM Fell English SC", "Cardo", serif);
	font-variant-caps: small-caps;
	letter-spacing: .1em;
	font-size: clamp(.56rem, 1vw, .72rem);
	color: var(--ink-muted, #5c4632);
	opacity: .85;
}

/* ── the <svg class="sc2-seal"> variant ───────────────────────────────────────
   If the seal is delivered as a single inline SVG (per the skeleton) rather
   than the CSS-disc DOM above, give it the same pendant placement, cast shadow,
   and irregular silhouette. The SVG carries its own radial wax gradients
   (pulling the same --wax* tokens through `stop-color:var(--wax)` in its
   <stop>s). */
.sc2-scroll svg.sc2-seal {
	position: relative;
	z-index: 1;
	display: block;
	width: clamp(96px, 15vw, 150px);
	height: auto;
	aspect-ratio: 1 / 1;
	margin: 0 auto;
	overflow: visible;
	pointer-events: auto;
	filter:
		drop-shadow(0 6px 10px rgba(40, 10, 8, .42))
		drop-shadow(0 2px 3px rgba(40, 10, 8, .34));
}


/* ════════════════════════════════════════════════════════════════════════════
   3.  DEFENSIVE / GRACEFUL DEGRADATION
   ════════════════════════════════════════════════════════════════════════════
   Heraldry + seal are OPTIONAL. None of these may break the document flow. */

/* hidden / empty regions collapse with no leftover spacing */
.sc2-scroll .sc2-crown[hidden],
.sc2-scroll .sc2-seal-wrap[hidden],
.sc2-scroll .sc2-arms[hidden] { display: none !important; }

.sc2-scroll .sc2-crown:empty,
.sc2-scroll .sc2-seal-wrap:empty { display: none; }

/* a single missing shield collapses without unbalancing the row (the :has rule
   in §1 re-centres the survivor). */
.sc2-scroll .sc2-arms:empty { display: none; }

/* broken raster arms: hide the img, fall back to the tinted shield field + a
   faint heraldic placeholder so the achievement frame still reads. JS adds
   .is-broken (or [data-broken]) on the img 'error' event. */
.sc2-scroll .sc2-arms .sc2-arms-field > img.is-broken,
.sc2-scroll .sc2-arms .sc2-arms-field > img[data-broken] { visibility: hidden; }

.sc2-scroll .sc2-arms.is-placeholder .sc2-arms-field {
	background-image:
		linear-gradient(135deg,
			var(--gold-shadow, #6e4d08) 0%, var(--gold, #d4af37) 20%,
			var(--gold-hi, #fff4c2) 40%, var(--gold, #d4af37) 60%,
			var(--gold-deep, #a9760a) 84%, var(--gold-shadow, #6e4d08) 100%),
		radial-gradient(circle at 50% 42%,
			var(--initial-ground, #6b1f2a) 0%,
			color-mix(in srgb, var(--initial-ground, #6b1f2a) 70%, #000 30%) 100%);
}

/* if the sigil layer is empty and carries no monogram, hide it so the disc is a
   plain pressed blob rather than an empty inner box. */
.sc2-scroll .sc2-seal-sigil:empty:not([data-monogram]) { display: none; }


/* ════════════════════════════════════════════════════════════════════════════
   4.  EXPORT / PRINT FALLBACKS  (.sc2-export and @media print)
   ════════════════════════════════════════════════════════════════════════════
   html2canvas + some PDF engines drop: color-mix(), mix-blend-mode, conic
   gradients, and certain mask/clip combinations. Provide flattened, faithful
   equivalents so the exported file matches the screen. NOTHING structural
   changes — only texture/blend tokens flatten. */

.sc2-scroll.sc2-export .sc2-seal-disc::before,
.sc2-scroll.sc2-export .sc2-seal-disc::after,
.sc2-scroll.sc2-export .sc2-arms .sc2-arms-field::before { mix-blend-mode: normal; }

/* milled-rim notch ring uses conic + mask → drop it on export (the rim shadows
   already sell the relief). */
.sc2-scroll.sc2-export .sc2-seal-disc::before { display: none; }

/* color-mix fallbacks: hard-code from the base tokens (these approximate the
   computed mixes used above). */
.sc2-scroll.sc2-export .sc2-ribbon-tail--a { background: var(--ribbon-a, #7b1f2a); }
.sc2-scroll.sc2-export .sc2-ribbon-tail--b { background: var(--ribbon-b, #d4af37); }
.sc2-scroll.sc2-export .sc2-seal-disc {
	background:
		radial-gradient(120% 120% at 34% 30%,
			var(--wax-hi, #c0392b) 0%,
			var(--wax, #8c1d1b) 38%,
			var(--wax-lo, #5a0f0f) 100%);
}
.sc2-scroll.sc2-export .sc2-seal-disc::after {
	background:
		radial-gradient(circle at 40% 35%,
			var(--wax-hi, #c0392b) 0%,
			var(--wax, #8c1d1b) 55%,
			var(--wax-lo, #5a0f0f) 100%);
}
.sc2-scroll.sc2-export .sc2-seal-sigil { color: var(--wax-lo, #5a0f0f); }
.sc2-scroll.sc2-export .sc2-seal-sigil > svg,
.sc2-scroll.sc2-export .sc2-seal-sigil > svg * {
	fill: var(--wax-lo, #5a0f0f) !important;
	stroke: #2a0606 !important;
}
.sc2-scroll.sc2-export .sc2-seal-sigil > img {
	mix-blend-mode: normal;
	opacity: .9;
}
.sc2-scroll.sc2-export .sc2-arms .sc2-arms-field { outline-color: var(--gold, #d4af37); }

@media print {
	.sc2-scroll .sc2-seal-disc::before { display: none; }
	.sc2-scroll .sc2-seal-disc::after,
	.sc2-scroll .sc2-arms .sc2-arms-field::before,
	.sc2-scroll .sc2-seal-sigil > img { mix-blend-mode: normal; }
	/* ensure wax/gilt actually ink on paper */
	.sc2-scroll .sc2-seal-disc,
	.sc2-scroll .sc2-arms .sc2-arms-field {
		-webkit-print-color-adjust: exact;
		        print-color-adjust: exact;
	}
}


/* ════════════════════════════════════════════════════════════════════════════
   5.  RESPONSIVE — narrow sheets stack the achievement above the title
   ════════════════════════════════════════════════════════════════════════════ */
@media (max-width: 540px) {
	.sc2-scroll .sc2-crown {
		gap: clamp(8px, 5vw, 20px);
		padding: 0 6px;
	}
	.sc2-scroll .sc2-arms { width: clamp(62px, 24vw, 96px); }
	.sc2-scroll .sc2-crown:not(.is-single) .sc2-arms--kingdom,
	.sc2-scroll .sc2-crown:not(.is-single) .sc2-arms--park { transform: none; }
	.sc2-scroll .sc2-seal-disc,
	.sc2-scroll svg.sc2-seal { width: clamp(86px, 30vw, 120px); }
}


/* ════════════════════════════════════════════════════════════════════════════
   6.  REDUCED MOTION  — nothing here animates by default, but disable the
   hover/press transitions for users who prefer reduced motion.
   ════════════════════════════════════════════════════════════════════════════ */
@media (prefers-reduced-motion: reduce) {
	.sc2-scroll .sc2-arms,
	.sc2-scroll .sc2-seal-disc,
	.sc2-scroll svg.sc2-seal { animation: none !important; transition: none !important; }
}

/* ===== inlined: sf-layout.css.part ===== */
/* ============================================================================
   THE LETTERED SCROLL — sf-layout.css.part   (THE LAYOUT LAYER)
   ----------------------------------------------------------------------------
   The substrate/illumination/typography/heraldry partials each declared that
   "geometry is owned by the layout layer." THIS is that layer. It owns ONLY
   the shell composition + the physical sheet's outer geometry — never palette,
   ornament, or type. Scoped to the `.sc2-forge` wrapper + the locked scroll
   hooks so it cannot leak into the legacy `sc-` builder beside it.

   Owns:
     • .sc2-forge          → the 2-column shell (control panel + felt stage).
     • .sc2-stage          → the "felt desk" the sheet rests on (backdrop).
     • .sc2-scroll OUTER    → sheet width (var(--sheet-w)) + min aspect-ratio +
                              the internal margin that the band/content live in.
     • .sc2-content/.sc2-crown/.sc2-seal-wrap flow padding (the parchment
       writing area inset from the illuminated border).

   It deliberately does NOT touch: the sheet's background/shadow/deckle
   (substrate), z-index stack (tokens), ornament (illumination/families), or
   text (typography). Geometry only.
   ============================================================================ */

/* ── THE SHELL ────────────────────────────────────────────────────────────────
   Panel (controls) on the left, felt stage (the scroll) on the right. Collapses
   to a single column on narrow screens. The panel is sticky so the controls
   stay in view while the (tall) scroll scrolls past on small screens.         */
.sc2-forge {
	display: grid;
	grid-template-columns: minmax(300px, 360px) minmax(0, 1fr);
	gap: 22px;
	align-items: start;
	margin: 18px 0 32px;
}
@media (max-width: 900px) {
	.sc2-forge {
		grid-template-columns: 1fr;
		gap: 16px;
	}
}

/* ── TOOLBOX COLLAPSED ────────────────────────────────────────────────────────
   The header chevron (#sc2PanelCollapse) minimises the WHOLE toolbox: the grid
   drops to a single column and the panel is removed from flow so the felt stage
   takes the full width (sf-app.js scheduleFit() then re-fits the sheet larger).
   A floating .sc2-panel-reopen tab (fixed-position, in sf-panel) restores it.
   Both hooks are set by bindPanelCollapse(): .is-panel-collapsed on the grid,
   .is-collapsed on the panel. Either one hides the panel — belt and braces.    */
.sc2-forge.is-panel-collapsed {
	grid-template-columns: 1fr;
}
.sc2-forge.is-panel-collapsed > .sc2-panel,
.sc2-forge .sc2-panel.is-collapsed {
	display: none;
}

/* The control panel column — sticky on wide screens so it tracks the sheet. */
.sc2-forge .sc2-panel {
	position: sticky;
	top: 14px;
	align-self: start;
	/* FIXED viewport height (not max-height): the two grid columns must be the
	   SAME height or a dark void opens below the shorter one. max-height fails
	   here because an auto grid row is still sized from the items' CONTENT, so
	   the row (and the taller stage) overshoots the capped panel. An explicit
	   height pins both columns to the viewport; the body (flex:1, min-height:0)
	   scrolls internally when the controls overflow. */
	height: calc(100vh - 28px);
	/* Lock the floor too: height + min-height both pinned, max-height absent, so
	   NO grid-track / flex / percentage pressure can ever shrink the toolbox
	   vertically. (The body, flex:1 + its own min-height:0, scrolls inside.) */
	min-height: calc(100vh - 28px);
	display: flex;
	flex-direction: column;
}
@media (max-width: 900px) {
	.sc2-forge .sc2-panel {
		position: static;
		height: auto;
		min-height: 0;
	}
}

/* ── THE FELT STAGE ───────────────────────────────────────────────────────────
   A muted "desk" the parchment rests on, so the lit sheet reads as a physical
   object. Dark-mode aware (the STAGE backdrop may darken — the SHEET never does,
   it carries its own vellum). Centres the sheet and gives it breathing room.   */
.sc2-forge .sc2-stage {
	display: flex;
	align-items: flex-start;
	justify-content: center;
	/* border-box so the fixed height below INCLUDES the padding — otherwise the
	   stage = height + 2×padding and overshoots the panel, reopening the void. */
	box-sizing: border-box;
	padding: clamp(18px, 3vw, 44px);
	border-radius: 12px;
	background:
		radial-gradient(120% 90% at 50% 0%, rgba(255,255,255,.05), transparent 60%),
		linear-gradient(160deg, #6b6258 0%, #564e45 48%, #433d36 100%);
	box-shadow: inset 0 1px 0 rgba(255,255,255,.06), inset 0 0 60px rgba(0,0,0,.35);
	min-height: 320px;
	overflow: hidden;
	/* The stage tracks the sticky panel and is capped to the viewport, then
	   STRETCHES to the grid row height. Without this the felt desk is sized by
	   the sheet's natural height (~1072px) while the panel is viewport-capped —
	   on any window shorter than the sheet a tall dark void opens BELOW the panel
	   in its grid column and reads as a "broken sidebar". Capping the stage means
	   fitScroll() (reads STAGE.clientHeight) shrinks the sheet to fit on short
	   windows; stretching means no void on tall windows either. */
	position: sticky;
	top: 14px;
	align-self: start;
	/* Same FIXED viewport height as the panel so the two columns match exactly
	   (no void either side). fitScroll() reads STAGE.clientHeight and scales the
	   sheet to fit, so a short window shrinks the preview rather than clipping. */
	height: calc(100vh - 28px);
}
@media (max-width: 900px) {
	.sc2-forge .sc2-stage {
		position: static;
		align-self: auto;
		height: auto;
		max-height: none;
	}
}
html[data-theme="dark"] .sc2-forge .sc2-stage,
.dark .sc2-forge .sc2-stage {
	background:
		radial-gradient(120% 90% at 50% 0%, rgba(255,255,255,.04), transparent 60%),
		linear-gradient(160deg, #2b2722 0%, #211d19 50%, #181512 100%);
}

/* ── THE PHYSICAL SHEET (outer geometry) ──────────────────────────────────────
   Width is capped to --sheet-w (tokens default min(760px,92vw)); aspect-ratio
   gives the sheet its letter proportion as a FLOOR while real content can push
   it taller (the proclamation must never be clipped). The internal padding is
   the writing area: it clears the illuminated border band so text never sits
   under the ornament (the locked z-stack rule).                               */
.sc2-forge .sc2-scroll {
	width: var(--sheet-w, min(760px, 92vw));
	max-width: 100%;
	box-sizing: border-box;
	/* FIXED Letter page: the sheet is a deterministic 8.5×11 rectangle, NEVER
	   content-grown. aspect-ratio (read from the shared --aspect token so screen
	   and print AGREE — sf-print.css.part reads the same var) sets the height
	   from the width; min-height:0 removes any floor. The existing fitScroll()
	   in sf-app.js.part scales the whole sheet to fit the stage — content fits
	   the fixed page, the page never grows to fit the content.                  */
	aspect-ratio: var(--aspect, 8.5 / 11);
	min-height: 0;
	/* No padding here: the writing-area inset is owned by .sc2-page's `inset`
	   (above) so the page group can be measured + scaled to fit precisely. */
	padding: 0;
	/* Clip every decorative layer (astral constellation, forest sprig, imperial
	   coronet, ornate curls, deckle) to the sheet so ornament can never paint
	   onto the felt stage. The deckle/curl edge is designed to sit inside the
	   margin, so clipping at the sheet edge is safe. */
	overflow: hidden;
}

/* Landscape orientation flips the proportion to a WIDE page (ratio 11/8.5 ≈
   1.294). The base rule's aspect-ratio reads --aspect, so flipping the token
   flips the shape automatically; the sheet also widens. No min-height floor. */
.sc2-forge .sc2-scroll[data-orientation="landscape"] {
	--aspect: 11 / 8.5;
	width: var(--sheet-w-land, min(1040px, 96vw));
}

/* ── WRITING-AREA FLOW ────────────────────────────────────────────────────────
   The decorative layers (vellum/ruling/illum/edge) are absolutely positioned
   fills (z 0–3). The flow children — crown (z5), content (z4), seal (z6) —
   stack in document order inside the padded writing area. We make the content
   the flexible middle so the seal sits at the foot and the crown crowns the
   title, on sheets of any height.                                            */
/* ── THE PAGE (flow group) ────────────────────────────────────────────────────
   crown + content + seal live inside .sc2-page, a single absolutely-positioned
   group filling the writing area (the sheet padding). sf-app.js fitPage()
   measures its natural height against the writing-area height and applies one
   transform:scale() so a long proclamation shrinks to FIT the fixed Letter page
   (content fits the page; the page never grows). transform-origin top center
   keeps the composition anchored under the crown. */
.sc2-forge .sc2-scroll > .sc2-page {
	position: absolute;
	inset: calc(var(--margin-frame, 34px) + var(--band-w, 26px));
	z-index: var(--z-content, 4);
	display: flex;
	flex-direction: column;
	transform-origin: top center;
	will-change: transform;
}
.sc2-forge .sc2-scroll > .sc2-page > .sc2-crown {
	position: relative;
	z-index: var(--z-crown, 5);
	flex: 0 0 auto;
	margin-bottom: clamp(8px, 1.6vw, 18px);
}
.sc2-forge .sc2-scroll > .sc2-page > .sc2-content {
	position: relative;
	z-index: var(--z-content, 4);
	flex: 1 1 auto;
	display: flex;
	flex-direction: column;
	gap: var(--gap-section, 1.15rem);
	justify-content: flex-start;
}
.sc2-forge .sc2-scroll > .sc2-page > .sc2-seal-wrap {
	position: relative;
	z-index: var(--z-seal, 6);
	flex: 0 0 auto;
}

/* The absolutely-positioned decorative layers must fill the padded box edge to
   edge (they live behind the writing area, not inside the padding). */
.sc2-forge .sc2-scroll > .sc2-vellum,
.sc2-forge .sc2-scroll > .sc2-ruling,
.sc2-forge .sc2-scroll > .sc2-edge,
.sc2-forge .sc2-scroll > .sc2-illum,
.sc2-forge .sc2-scroll > .sc2-curl {
	position: absolute;
	inset: 0;
	pointer-events: none;
}
/* Decorative layers sit BELOW the flow content (crown/content/seal) per the
   locked z-stack. Each is positioned, so without an explicit z-index it would
   form a stacking context above the auto-level content and hide the text. */
.sc2-forge .sc2-scroll > .sc2-vellum { z-index: var(--z-vellum, 0); }
.sc2-forge .sc2-scroll > .sc2-ruling { z-index: var(--z-ruling, 1); }
.sc2-forge .sc2-scroll > .sc2-illum  { z-index: var(--z-illum, 2); }
.sc2-forge .sc2-scroll > .sc2-edge   { z-index: var(--z-edge, 3); }
.sc2-forge .sc2-scroll > .sc2-curl   { z-index: var(--z-edge, 3); }

/* The defs SVG must never occupy layout space. */
.sc2-forge .sc2-scroll > .sc2-defs { position: absolute; width: 0; height: 0; }

/* ===== inlined: sf-panel.css.part ===== */
/* ============================================================================
   THE LETTERED SCROLL — sf-panel.css.part
   ----------------------------------------------------------------------------
   CONTROL-PANEL CHROME ONLY (.sc2-panel and the floating .sc2-panel-reopen).
   Raw CSS partial — inlined into a <style> block in Scroll_builder.tpl.

   SCOPING CONTRACT (locked):
     • EVERY rule is scoped under .sc2-panel / .sc2-forge / .sc2-panel-reopen.
       Nothing here may reach the legacy .sc- builder or the .sc2-scroll sheet
       (that vellum is owned by the other partials and tokenised to .sc2-scroll).
     • The panel defines its OWN neutral chrome tokens — it does NOT borrow the
       vellum palette tokens (those are warm parchment, wrong for tool chrome).
     • Dark mode: html[data-theme="dark"] .sc2-panel ... overrides every surface.
       Light mode is the default and mirrors the legacy builder's palette so the
       reinvented panel feels native (card #fff, subtle #f7fafc, borders #e2e8f0
       / #cbd5e0, text #2d3748, muted #718096/#a0aec0, accent #3182ce; dark bg
       ~#1f1f1f, cards #2a2a2a, borders #444, text #e8e8e8, muted #999).
     • NO native title attributes — hints render via the scoped [data-tip] CSS
       tooltip defined at the foot of this file.
   ============================================================================ */

/* ── PANEL CHROME TOKENS (neutral; light = default) ─────────────────────────
   Local to .sc2-panel / reopen tab so the app's dark theme overrides cleanly
   and nothing leaks to the vellum or the legacy builder.                      */
.sc2-panel,
.sc2-panel-reopen {
	--sf-bg:          #ffffff;   /* panel body background          */
	--sf-bg-sub:      #f7fafc;   /* subtle wells / heads           */
	--sf-bg-sub2:     #f8fafc;   /* faintest fill                  */
	--sf-card:        #ffffff;   /* swatch / field cards           */
	--sf-card-hover:  #f0f6ff;   /* card hover wash                */
	--sf-border:      #e2e8f0;   /* default hairline               */
	--sf-border-2:    #cbd5e0;   /* heavier border / inputs        */
	--sf-text:        #2d3748;   /* primary ink                    */
	--sf-text-soft:   #4a5568;   /* secondary ink                  */
	--sf-muted:       #718096;   /* muted labels                   */
	--sf-muted-2:     #a0aec0;   /* faintest captions              */
	--sf-accent:      #3182ce;   /* interactive accent             */
	--sf-accent-hi:   #ebf4ff;   /* accent wash                    */
	--sf-accent-edge: #90cdf4;   /* accent hover edge              */
	--sf-gold:        #b8862b;   /* heraldic gold (primary btn)    */
	--sf-gold-hi:     #d4af37;
	--sf-gold-lo:     #8b6914;
	--sf-gold-ink:    #1a1a1a;   /* text on gold                   */
	--sf-shadow:      rgba(45,55,72,.12);
	--sf-tip-bg:      #2d3748;   /* tooltip bubble                 */
	--sf-tip-text:    #f7fafc;
	--sf-radius:      10px;
	--sf-radius-sm:   6px;
}

/* ── PANEL SHELL ────────────────────────────────────────────────────────────
   Flex column; the layout layer sets a FIXED height (calc(100vh - 28px)). Head
   + foot stay put, body scrolls (flex:1; overflow:auto).
   NO max-height here: a percentage max-height resolves against the grid cell,
   which is coupled to the stage/row — so any transient that shrinks the cell
   (e.g. fitScroll during an illumination click) would clamp the panel down and
   the toolbox would "minimise itself". The fixed height owns sizing outright.  */
.sc2-panel {
	display: flex;
	flex-direction: column;
	min-height: 0;
	box-sizing: border-box;
	background: var(--sf-bg);
	color: var(--sf-text);
	border: 1px solid var(--sf-border);
	border-radius: var(--sf-radius);
	box-shadow: 0 1px 3px var(--sf-shadow);
	font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
	font-size: 14px;
	line-height: 1.45;
	overflow: hidden;
}
.sc2-panel *,
.sc2-panel *::before,
.sc2-panel *::after {
	box-sizing: border-box;
}

/* Constrain EVERY panel SVG — intrinsic size would blow up to ~360px. */
.sc2-panel svg,
.sc2-panel-reopen svg {
	width: 18px;
	height: 18px;
	display: block;
	flex: 0 0 auto;
}

/* ── HEADER (sticky feel; does not scroll) ──────────────────────────────── */
.sc2-panel__head {
	flex: 0 0 auto;
	display: flex;
	align-items: flex-start;
	justify-content: space-between;
	gap: 10px;
	padding: 14px 16px;
	background: var(--sf-bg-sub);
	border-bottom: 1px solid var(--sf-border);
}
.sc2-panel__brand {
	display: flex;
	align-items: center;
	gap: 11px;
	min-width: 0;
}
.sc2-panel__mark {
	width: 26px !important;
	height: 26px !important;
	color: var(--sf-gold);
	flex: 0 0 auto;
}
.sc2-panel__titles {
	min-width: 0;
}
.sc2-panel__title {
	margin: 0;
	font-size: 16px;
	font-weight: 700;
	letter-spacing: .2px;
	color: var(--sf-text);
	line-height: 1.2;
}
.sc2-panel__sub {
	margin: 1px 0 0;
	font-size: 12px;
	color: var(--sf-muted);
	line-height: 1.3;
}
.sc2-panel__collapse {
	flex: 0 0 auto;
	display: inline-flex;
	align-items: center;
	justify-content: center;
	width: 30px;
	height: 30px;
	padding: 0;
	background: transparent;
	border: 1px solid var(--sf-border);
	border-radius: var(--sf-radius-sm);
	color: var(--sf-muted);
	cursor: pointer;
	transition: background .15s, border-color .15s, color .15s;
}
.sc2-panel__collapse:hover {
	background: var(--sf-card-hover);
	border-color: var(--sf-accent-edge);
	color: var(--sf-accent);
}
.sc2-panel__collapse:focus-visible {
	outline: 2px solid var(--sf-accent);
	outline-offset: 2px;
}

/* ── BODY (the only scrolling region) ────────────────────────────────────── */
.sc2-panel__body {
	flex: 1 1 auto;
	min-height: 0;
	overflow-y: auto;
	overflow-x: hidden;
	padding: 16px;
	display: flex;
	flex-direction: column;
	gap: 18px;
	-webkit-overflow-scrolling: touch;
}
.sc2-panel__body::-webkit-scrollbar { width: 10px; }
.sc2-panel__body::-webkit-scrollbar-thumb {
	background: var(--sf-border-2);
	border-radius: 6px;
	border: 2px solid var(--sf-bg);
}
.sc2-panel__body::-webkit-scrollbar-track { background: transparent; }

/* ── HEADING PILL RESET (CRITICAL) ──────────────────────────────────────────
   orkui.css gives ALL h1–h6 a grey box + border + shadow. Every panel heading
   carries .sc2-h and depends on this reset.                                   */
.sc2-panel .sc2-h {
	background: transparent !important;
	background-color: transparent !important;
	border: none !important;
	padding: 0 !important;
	border-radius: 0 !important;
	text-shadow: none !important;
	box-shadow: none !important;
	margin: 0;
	font-weight: 700;
	color: inherit;
}

/* ── GROUPS (sections) ───────────────────────────────────────────────────── */
.sc2-group {
	display: flex;
	flex-direction: column;
	gap: 12px;
	padding: 14px;
	background: var(--sf-bg-sub2);
	border: 1px solid var(--sf-border);
	border-radius: var(--sf-radius);
}
.sc2-group__head {
	display: flex;
	align-items: center;
	gap: 8px;
}
.sc2-group__title {
	font-size: 12px;
	font-weight: 700;
	text-transform: uppercase;
	letter-spacing: .6px;
	color: var(--sf-text-soft);
}
.sc2-group__hint {
	display: inline-flex;
	align-items: center;
	justify-content: center;
	color: var(--sf-muted-2);
	cursor: help;
	flex: 0 0 auto;
}
.sc2-group__hint svg { width: 18px; height: 18px; }
.sc2-group__hint:hover { color: var(--sf-accent); }
.sc2-group__reset {
	margin-left: auto;
	padding: 3px 8px;
	font-size: 11px;
	font-weight: 600;
	background: transparent;
	border: 1px solid transparent;
	border-radius: 5px;
	color: var(--sf-accent);
	cursor: pointer;
	transition: background .15s, border-color .15s;
}
.sc2-group__reset:hover {
	background: var(--sf-accent-hi);
	border-color: var(--sf-accent-edge);
}
.sc2-group__reset:focus-visible {
	outline: 2px solid var(--sf-accent);
	outline-offset: 1px;
}

/* ── FAMILY PICKER (2-col selectable card grid) ──────────────────────────── */
.sc2-fam {
	display: grid;
	grid-template-columns: repeat(2, minmax(0, 1fr));
	gap: 10px;
}
.sc2-fam__swatch {
	position: relative;
	display: flex;
	flex-direction: column;
	align-items: stretch;
	gap: 7px;
	padding: 10px;
	text-align: left;
	background: var(--sf-card);
	border: 1px solid var(--sf-border-2);
	border-radius: var(--sf-radius-sm);
	cursor: pointer;
	transition: border-color .15s, box-shadow .15s, transform .12s, background .15s;
}
.sc2-fam__swatch:hover {
	border-color: var(--sf-accent-edge);
	box-shadow: 0 3px 10px var(--sf-shadow);
	transform: translateY(-1px);
}
.sc2-fam__swatch:focus-visible {
	outline: 2px solid var(--sf-accent);
	outline-offset: 2px;
}
.sc2-fam__swatch[aria-checked="true"] {
	border-color: var(--sf-gold);
	box-shadow: 0 0 0 2px var(--sf-gold), 0 3px 10px var(--sf-shadow);
	background: var(--sf-card);
}
.sc2-fam__chip {
	position: relative;
	display: flex;
	height: 30px;
	border-radius: 4px;
	overflow: hidden;
	border: 1px solid rgba(0,0,0,.12);
}
.sc2-fam__band {
	flex: 1 1 0;
	display: block;
	height: 100%;
}
/* Neutral placeholder bands — sf-app.js recolors these per family. */
.sc2-fam__band--1 { background: #d8c9a3; }
.sc2-fam__band--2 { background: #b8862b; }
.sc2-fam__band--3 { background: #6b4a2b; }
.sc2-fam__band--4 { background: #2d2017; }
.sc2-fam__check {
	position: absolute;
	top: 50%;
	left: 50%;
	width: 16px !important;
	height: 16px !important;
	transform: translate(-50%, -50%) scale(.6);
	color: #fff;
	opacity: 0;
	filter: drop-shadow(0 1px 2px rgba(0,0,0,.55));
	transition: opacity .15s, transform .15s;
	pointer-events: none;
}
.sc2-fam__swatch[aria-checked="true"] .sc2-fam__check {
	opacity: 1;
	transform: translate(-50%, -50%) scale(1);
}
.sc2-fam__label {
	font-size: 12.5px;
	font-weight: 600;
	color: var(--sf-text);
	line-height: 1.2;
}
.sc2-fam__motif {
	font-size: 10px;
	text-transform: uppercase;
	letter-spacing: .4px;
	color: var(--sf-muted-2);
	line-height: 1.2;
}

/* ── FIELDS (text / date / textarea) ─────────────────────────────────────── */
.sc2-field {
	display: flex;
	flex-direction: column;
	gap: 5px;
}
.sc2-field--2col {
	display: grid;
	grid-template-columns: 1fr 1fr;
	gap: 12px;
}
.sc2-field--2col > div {
	display: flex;
	flex-direction: column;
	gap: 5px;
	min-width: 0;
}
.sc2-field__lbl {
	font-size: 12px;
	font-weight: 600;
	color: var(--sf-text-soft);
}
.sc2-field__in {
	width: 100%;
	padding: 8px 10px;
	font-size: 13.5px;
	font-family: inherit;
	color: var(--sf-text);
	background: var(--sf-bg);
	border: 1px solid var(--sf-border-2);
	border-radius: var(--sf-radius-sm);
	transition: border-color .15s, box-shadow .15s;
}
.sc2-field__in::placeholder { color: var(--sf-muted-2); }
.sc2-field__in:hover { border-color: var(--sf-accent-edge); }
.sc2-field__in:focus {
	outline: none;
	border-color: var(--sf-accent);
	box-shadow: 0 0 0 3px var(--sf-accent-hi);
}
.sc2-field__in--date {
	min-height: 36px;
}
.sc2-field__ta {
	resize: vertical;
	min-height: 56px;
	line-height: 1.4;
}
.sc2-field__note {
	font-size: 11px;
	color: var(--sf-muted);
	line-height: 1.35;
}

/* ── AUTOCOMPLETE ────────────────────────────────────────────────────────────
   .kn-ac-results already has global styling in revised.css; only ensure the
   wrapper positions the dropdown and the dropdown spans the input width.       */
.sc2-ac {
	position: relative;
}
.sc2-panel .sc2-ac__results {
	left: 0;
	right: 0;
	width: 100%;
}

/* ── OPTIONS ─────────────────────────────────────────────────────────────── */
.sc2-opt {
	display: flex;
	flex-direction: column;
	gap: 7px;
}
.sc2-opt__lbl {
	font-size: 12px;
	font-weight: 600;
	color: var(--sf-text-soft);
}

/* Segmented control */
.sc2-seg {
	display: grid;
	grid-template-columns: repeat(2, 1fr);
	gap: 0;
	padding: 3px;
	background: var(--sf-bg-sub);
	border: 1px solid var(--sf-border);
	border-radius: 8px;
	/* Contain the visually-hidden radios (below) so focusing one on a label
	   click can't scroll the page to a far-off static position. */
	position: relative;
}
.sc2-seg--3 {
	grid-template-columns: repeat(3, 1fr);
}
.sc2-seg__in {
	position: absolute;
	top: 0;
	left: 0;
	width: 1px;
	height: 1px;
	margin: -1px;
	padding: 0;
	border: 0;
	overflow: hidden;
	clip: rect(0 0 0 0);
	white-space: nowrap;
}
.sc2-seg__pill {
	display: flex;
	align-items: center;
	justify-content: center;
	padding: 6px 8px;
	font-size: 12.5px;
	font-weight: 600;
	text-align: center;
	color: var(--sf-muted);
	background: transparent;
	border-radius: 6px;
	cursor: pointer;
	transition: background .15s, color .15s, box-shadow .15s;
	user-select: none;
}
.sc2-seg__pill:hover {
	color: var(--sf-text);
}
.sc2-seg__in:checked + .sc2-seg__pill {
	color: var(--sf-accent);
	background: var(--sf-bg);
	box-shadow: 0 1px 3px var(--sf-shadow);
}
.sc2-seg__in:focus-visible + .sc2-seg__pill {
	outline: 2px solid var(--sf-accent);
	outline-offset: 1px;
}

/* Switch (.sc2-opt--switch row) */
.sc2-opt--switch {
	display: block;
}
.sc2-switch {
	display: flex;
	align-items: flex-start;
	gap: 11px;
	cursor: pointer;
	/* Contain the visually-hidden checkbox so toggling it can't scroll the page. */
	position: relative;
}
.sc2-switch__in {
	position: absolute;
	top: 0;
	left: 0;
	width: 1px;
	height: 1px;
	margin: -1px;
	padding: 0;
	border: 0;
	overflow: hidden;
	clip: rect(0 0 0 0);
	white-space: nowrap;
}
.sc2-switch__track {
	position: relative;
	flex: 0 0 auto;
	width: 38px;
	height: 22px;
	margin-top: 1px;
	background: var(--sf-border-2);
	border-radius: 999px;
	transition: background .18s;
}
.sc2-switch__thumb {
	position: absolute;
	top: 2px;
	left: 2px;
	width: 18px;
	height: 18px;
	background: #fff;
	border-radius: 50%;
	box-shadow: 0 1px 2px rgba(0,0,0,.3);
	transition: transform .18s;
}
.sc2-switch__in:checked + .sc2-switch__track {
	background: var(--sf-accent);
}
.sc2-switch__in:checked + .sc2-switch__track .sc2-switch__thumb {
	transform: translateX(16px);
}
.sc2-switch__in:focus-visible + .sc2-switch__track {
	outline: 2px solid var(--sf-accent);
	outline-offset: 2px;
}
.sc2-switch__text {
	display: flex;
	flex-direction: column;
	gap: 1px;
	min-width: 0;
}
.sc2-switch__name {
	font-size: 13px;
	font-weight: 600;
	color: var(--sf-text);
	line-height: 1.25;
}
.sc2-switch__desc {
	font-size: 11px;
	color: var(--sf-muted);
	line-height: 1.3;
}

/* Wax-seal colour picker (round dots) */
.sc2-wax {
	display: flex;
	flex-wrap: wrap;
	gap: 9px;
	/* Contain the visually-hidden wax radios so focusing one can't scroll the page. */
	position: relative;
}
.sc2-wax__in {
	position: absolute;
	top: 0;
	left: 0;
	width: 1px;
	height: 1px;
	margin: -1px;
	padding: 0;
	border: 0;
	overflow: hidden;
	clip: rect(0 0 0 0);
	white-space: nowrap;
}
.sc2-wax__dot {
	position: relative;
	display: inline-flex;
	align-items: center;
	justify-content: center;
	width: 28px;
	height: 28px;
	border-radius: 50%;
	cursor: pointer;
	background: var(--sc2-wax-preview, #8c1d1b);
	box-shadow: inset 0 1px 1px rgba(255,255,255,.25), inset 0 -2px 3px rgba(0,0,0,.35);
	transition: transform .12s, box-shadow .12s;
}
.sc2-wax__dot:hover {
	transform: scale(1.08);
}
/* "Use family wax" — distinct multi-colour conic look. */
.sc2-wax__dot--family {
	background: conic-gradient(from 220deg,
		#8c1d1b 0deg, #b8862b 70deg, #1f4d2e 140deg,
		#1e3a6e 210deg, #43286e 280deg, #8c1d1b 360deg);
}
.sc2-wax__inner {
	display: block;
	width: 100%;
	height: 100%;
	border-radius: 50%;
	pointer-events: none;
}
.sc2-wax__in:checked + .sc2-wax__dot {
	box-shadow: 0 0 0 2px var(--sf-bg), 0 0 0 4px var(--sf-gold),
		inset 0 -2px 3px rgba(0,0,0,.35);
	transform: scale(1.06);
}
.sc2-wax__in:focus-visible + .sc2-wax__dot {
	box-shadow: 0 0 0 2px var(--sf-bg), 0 0 0 4px var(--sf-accent);
}

/* ── FOOTER / EXPORT RAIL (pinned; does not scroll) ──────────────────────── */
.sc2-panel__foot {
	flex: 0 0 auto;
	padding: 14px 16px;
	background: var(--sf-bg-sub);
	border-top: 1px solid var(--sf-border);
}
.sc2-panel__foot-note {
	margin: 8px 0 0;
	min-height: 1em;
	font-size: 11.5px;
	color: var(--sf-muted);
	line-height: 1.35;
	text-align: center;
}
.sc2-export {
	display: grid;
	grid-template-columns: 1fr 1fr;
	gap: 10px;
}
.sc2-export--locked {
	grid-template-columns: 1fr;
}

/* ── BUTTONS ─────────────────────────────────────────────────────────────── */
.sc2-btn {
	display: inline-flex;
	align-items: center;
	justify-content: center;
	gap: 8px;
	padding: 9px 14px;
	font-size: 13.5px;
	font-weight: 600;
	font-family: inherit;
	line-height: 1.1;
	border-radius: var(--sf-radius-sm);
	border: 1px solid transparent;
	cursor: pointer;
	transition: background .15s, border-color .15s, color .15s, box-shadow .15s, opacity .15s;
}
.sc2-btn svg { width: 18px; height: 18px; }
.sc2-btn:focus-visible {
	outline: 2px solid var(--sf-accent);
	outline-offset: 2px;
}
.sc2-btn:disabled,
.sc2-btn[aria-disabled="true"] {
	opacity: .6;
	cursor: not-allowed;
}

.sc2-btn--ghost {
	background: var(--sf-bg);
	border-color: var(--sf-border-2);
	color: var(--sf-text-soft);
}
.sc2-btn--ghost:not(:disabled):hover {
	background: var(--sf-card-hover);
	border-color: var(--sf-accent-edge);
	color: var(--sf-accent);
}

.sc2-btn--gold {
	color: var(--sf-gold-ink);
	background: linear-gradient(135deg, #e6c25a 0%, var(--sf-gold-hi) 45%, var(--sf-gold) 100%);
	border-color: var(--sf-gold-lo);
	box-shadow: 0 1px 3px rgba(0,0,0,.18);
}
.sc2-btn--gold:not(:disabled):hover {
	background: linear-gradient(135deg, #f0cd6a 0%, #e0bc46 45%, #c4922f 100%);
	box-shadow: 0 2px 7px rgba(140,100,20,.35);
}
.sc2-btn--gold:not(:disabled):active {
	transform: translateY(1px);
}

/* Loading spinner inside a button — hidden until JS adds .is-busy. */
.sc2-btn__spin {
	display: none;
	width: 15px;
	height: 15px;
	border: 2px solid rgba(0,0,0,.25);
	border-top-color: var(--sf-gold-ink);
	border-radius: 50%;
	animation: sc2-spin .7s linear infinite;
}
.sc2-btn.is-busy .sc2-btn__spin {
	display: inline-block;
}
.sc2-btn.is-busy {
	cursor: progress;
}
@keyframes sc2-spin {
	to { transform: rotate(360deg); }
}

/* ── FLOATING RE-OPEN TAB (visible only when panel collapsed) ────────────── */
.sc2-panel-reopen {
	position: fixed;
	top: 50%;
	left: 0;
	transform: translateY(-50%);
	z-index: 60;
	display: inline-flex;
	align-items: center;
	justify-content: center;
	width: 34px;
	height: 56px;
	padding: 0;
	background: var(--sf-bg);
	color: var(--sf-accent);
	border: 1px solid var(--sf-border);
	border-left: none;
	border-radius: 0 var(--sf-radius-sm) var(--sf-radius-sm) 0;
	box-shadow: 2px 2px 8px var(--sf-shadow);
	cursor: pointer;
	transition: background .15s, color .15s, width .15s;
}
.sc2-panel-reopen[hidden] {
	display: none;
}
.sc2-panel-reopen:hover {
	background: var(--sf-card-hover);
	width: 38px;
}
.sc2-panel-reopen:focus-visible {
	outline: 2px solid var(--sf-accent);
	outline-offset: 2px;
}

/* ── VISUALLY-HIDDEN UTILITY (scoped) ────────────────────────────────────── */
.sc2-panel .sc2-vh {
	position: absolute !important;
	width: 1px;
	height: 1px;
	margin: -1px;
	padding: 0;
	border: 0;
	overflow: hidden;
	clip: rect(0 0 0 0);
	white-space: nowrap;
}

/* ============================================================================
   CSS TOOLTIPS  ·  [data-tip]  (scoped under panel + reopen tab)
   No native title="". Instant appearance, dark bubble, high z-index.
   ============================================================================ */
.sc2-panel [data-tip],
.sc2-panel-reopen[data-tip] {
	position: relative;
}
.sc2-panel [data-tip]::after,
.sc2-panel-reopen[data-tip]::after {
	content: attr(data-tip);
	position: absolute;
	bottom: calc(100% + 8px);
	left: 50%;
	transform: translateX(-50%) translateY(3px);
	z-index: 200;
	min-width: max-content;
	max-width: 220px;
	width: max-content;
	padding: 6px 9px;
	font-size: 11.5px;
	font-weight: 500;
	line-height: 1.35;
	text-align: left;
	white-space: normal;
	color: var(--sf-tip-text);
	background: var(--sf-tip-bg);
	border-radius: 6px;
	box-shadow: 0 4px 14px rgba(0,0,0,.28);
	opacity: 0;
	pointer-events: none;
	transition: opacity .1s ease, transform .1s ease;
}
.sc2-panel [data-tip]::before,
.sc2-panel-reopen[data-tip]::before {
	content: "";
	position: absolute;
	bottom: calc(100% + 3px);
	left: 50%;
	z-index: 200;
	transform: translateX(-50%) translateY(3px);
	border: 5px solid transparent;
	border-top-color: var(--sf-tip-bg);
	opacity: 0;
	pointer-events: none;
	transition: opacity .1s ease, transform .1s ease;
}
.sc2-panel [data-tip]:hover::after,
.sc2-panel [data-tip]:focus-visible::after,
.sc2-panel-reopen[data-tip]:hover::after,
.sc2-panel-reopen[data-tip]:focus-visible::after,
.sc2-panel [data-tip]:hover::before,
.sc2-panel [data-tip]:focus-visible::before,
.sc2-panel-reopen[data-tip]:hover::before,
.sc2-panel-reopen[data-tip]:focus-visible::before {
	opacity: 1;
	transform: translateX(-50%) translateY(0);
}
/* Reopen tab sits at screen edge — float its tip to the right instead. */
.sc2-panel-reopen[data-tip]::after {
	bottom: auto;
	top: 50%;
	left: calc(100% + 8px);
	transform: translateY(-50%) translateX(-3px);
}
.sc2-panel-reopen[data-tip]::before {
	bottom: auto;
	top: 50%;
	left: calc(100% + 3px);
	transform: translateY(-50%) translateX(-3px);
	border-top-color: transparent;
	border-right-color: var(--sf-tip-bg);
}
.sc2-panel-reopen[data-tip]:hover::after,
.sc2-panel-reopen[data-tip]:focus-visible::after {
	transform: translateY(-50%) translateX(0);
}
.sc2-panel-reopen[data-tip]:hover::before,
.sc2-panel-reopen[data-tip]:focus-visible::before {
	transform: translateY(-50%) translateX(0);
}

/* ============================================================================
   DARK MODE  ·  html[data-theme="dark"] .sc2-panel …
   Mirrors the legacy builder's dark palette (bg ~#1f1f1f, cards #2a2a2a,
   borders #444, text #e8e8e8, muted #999).
   ============================================================================ */
html[data-theme="dark"] .sc2-panel,
html[data-theme="dark"] .sc2-panel-reopen {
	--sf-bg:          #1f1f1f;
	--sf-bg-sub:      #181818;
	--sf-bg-sub2:     #232323;
	--sf-card:        #2a2a2a;
	--sf-card-hover:  #323232;
	--sf-border:      #444444;
	--sf-border-2:    #555555;
	--sf-text:        #e8e8e8;
	--sf-text-soft:   #dddddd;
	--sf-muted:       #999999;
	--sf-muted-2:     #888888;
	--sf-accent:      #63b3ed;
	--sf-accent-hi:   rgba(99,179,237,.16);
	--sf-accent-edge: #4a90c2;
	--sf-shadow:      rgba(0,0,0,.5);
	--sf-tip-bg:      #0f0f0f;
	--sf-tip-text:    #e8e8e8;
}
html[data-theme="dark"] .sc2-panel {
	box-shadow: 0 1px 4px rgba(0,0,0,.55);
}
html[data-theme="dark"] .sc2-panel__mark {
	color: var(--sf-gold-hi);
}
html[data-theme="dark"] .sc2-fam__chip {
	border-color: rgba(255,255,255,.12);
}
html[data-theme="dark"] .sc2-fam__swatch[aria-checked="true"],
html[data-theme="dark"] .sc2-wax__in:checked + .sc2-wax__dot {
	border-color: var(--sf-gold-hi);
}
html[data-theme="dark"] .sc2-switch__thumb {
	background: #e8e8e8;
}
html[data-theme="dark"] .sc2-btn--gold {
	color: #1a1a1a;
	border-color: #6b5310;
}
html[data-theme="dark"] .sc2-btn__spin {
	border-color: rgba(0,0,0,.3);
	border-top-color: #1a1a1a;
}
html[data-theme="dark"] .sc2-panel__body::-webkit-scrollbar-thumb {
	border-color: var(--sf-bg);
}

/* ===== family: hibernian_knotwork ===== */
/* ============================================================================
   THE LETTERED SCROLL — family-hibernian_knotwork.css.part
   ----------------------------------------------------------------------------
   FAMILY : Hibernian Knotwork          KEY : hibernian_knotwork
   ROLE   : The ladder / order DEFAULT family.

   IDENTITY (locked brief):
     Insular / Lindisfarne register — older-than-medieval. A fae / woodland
     CHARTER lettered by an island scriptorium: a rounded UNCIAL title, a deep
     WOAD-BLUE field carrying ORPIMENT "false-gold" interlace (NO true gold —
     orpiment is the gilding of early Insular work), RED-LEAD (minium) rubrics,
     VERDIGRIS-green accents, and GREEN wax to signify a perpetual, evergreen
     grant. Two-stroke band knotwork on a consistent over/under grid ending in
     zoomorphic (animal-head) terminals; triskele spirals nest in the corner
     pieces. The versal sits inside a knotwork-framed initial box. The pendant
     seal is VESICA-eligible (pointed oval), older than the heater shield.

   SCOPING CONTRACT (obeyed verbatim — see sf-tokens.css.part):
     • Everything is nested under .sc2-scroll[data-family="hibernian_knotwork"].
     • This partial RE-SETS ONLY palette / font / motif / escutcheon tokens and
       adds family ORNAMENT selectors that bind to the LOCKED DOM hooks
       (.sc2-title, .sc2-versal, .sc2-illum, .sc2-border, .sc2-seal, …).
     • It NEVER touches z-index, sheet geometry, spacing rhythm, the shadow /
       gilt helper recipes, or the motion tokens.
     • It loads AFTER sf-tokens.css.part, so these palette values win over the
       baseline hooks for this family.

   "FALSE-GOLD" NOTE (locked): the shared --gold* ramp is re-tuned toward a warm
   mineral ORPIMENT yellow, NOT metallic leaf. The raised-gold helper still
   applies so the interlace reads as slightly-raised painted pigment, the way a
   carpet-page incipit was laid in — never burnished #ffd700.
   ============================================================================ */

.sc2-scroll[data-family="hibernian_knotwork"] {

  /* ── SUBSTRATE / VELLUM — cool, scraped island calf-skin ──────────────────
     Paler & a touch cooler than the warm Crimson court parchment; this is
     well-prepared, scraped vellum that has weathered damp island air.        */
  --vellum:            #ece0c0;   /* base calf body                            */
  --vellum-hi:         #f4ead0;   /* lightest scraped centre                   */
  --vellum-lo:         #cdba8e;   /* aged, handled edge                        */
  --grime:             rgba(50,46,24,.34);    /* cooler, olive-tinged grime    */
  --foxing:            #9c8a55;   /* olive foxing (damp-air mottle)            */
  --ruling:            #8a8266;   /* dry hard-point ruling, green-grey         */
  --curl-shadow:       rgba(38,46,28,.34);    /* green-shadowed curl           */

  /* ── INK — near-black iron-gall, the darkest body ink of the fleet ──────── */
  --ink:               #1c1810;   /* deep monastic iron-gall — never #000      */
  --ink-muted:         #4b4226;   /* olive-sepia: intitulation + sig titles    */
  --rubric:            #c1440e;   /* RED LEAD (minium) — hotter than vermilion */

  /* ── GILDING → ORPIMENT "false gold" (paint, not leaf) ────────────────────
     Re-tuned to a mineral orpiment yellow. The shared raised-gold recipe
     still applies (gradient + highlight + dark keyline) so the interlace
     reads as slightly-raised painted pigment, not burnished metal.           */
  --gold:              #e3b505;   /* orpiment mid                              */
  --gold-hi:           #f6e08a;   /* pale orpiment catch-light                 */
  --gold-deep:         #b8860b;   /* aged orpiment shade                       */
  --gold-shadow:       #6e4d08;   /* darkest mineral stop                      */
  --gold-keyline:      #5a3d08;   /* recess line — sells painted relief        */

  /* ── BORDER / FRAME — WOAD-BLUE field ─────────────────────────────────────
     The signature colour of Insular carpet pages. The decorated band rides a
     deep woad ground; the versal box matches it.                             */
  --border:            #2b4570;   /* woad field                                */
  --rule-fine:         #2b4570;   /* outer hairline in woad, not brown ink     */
  --initial-ground:    #2b4570;   /* versal box ground = woad to match band    */

  /* ── ACCENT — VERDIGRIS green (the second island pigment) ───────────────── */
  --accent:            #3a6b35;   /* verdigris / copper-green ornament         */
  --accent-soft:       rgba(58,107,53,.30);   /* washed verdigris filigree     */

  /* ── WAX SEAL — GREEN wax = a perpetual / evergreen grant ─────────────────
     Deep forest verdigris wax, never red. Catch-light stays cool & leafy.    */
  --wax:               #3c5a3c;   /* perpetual-green wax body                  */
  --wax-hi:            #6fa05a;   /* upper-left catch-light (leaf green)        */
  --wax-lo:            #203a22;   /* pooled, near-black green centre            */
  --ribbon-a:          #2b4570;   /* woad livery tail                          */
  --ribbon-b:          #3a6b35;   /* verdigris livery tail (NOT metal gold)    */

  /* ── HERALDRY — Insular arms read older as a VESICA, not a heater ───────── */
  --escutcheon:        vesica;    /* informational hook → vesica clipPath      */
  --arms-rim:          var(--accent);          /* verdigris rim, not gold       */
  --arms-keyline:      #1f2a14;   /* dark olive keyline                        */

  /* ── TYPOGRAPHY — rounded UNCIAL title, Cardo body, italic chancery sig ──
     Uncial sits large & open; never track a rounded display face wide or it
     loses the hand. Cardo is the humanist body; EB Garamond italic signs.    */
  --ff-title:          var(--ff-title-uncial); /* "Uncial Antiqua","MedievalSharp",serif */
  --ff-body:           "Cardo","EB Garamond","IM Fell English",Garamond,Georgia,serif;
  --ff-sign:           "EB Garamond","Cardo",serif;     /* rendered italic       */
  --ff-versal:         "Uncial Antiqua","Cardo",serif;  /* versal in uncial too  */
  --ls-title:          0;                                /* open, untracked uncial */

  /* ── MOTIF HOOK — read by the illumination engine to pick the SVG pattern ─ */
  --motif:             "insular-interlace";
}


/* ============================================================================
   FAMILY ORNAMENT SELECTORS
   Family character layered on top of the shared structure. These bind to the
   LOCKED DOM hooks and add Insular detail WITHOUT altering layout, spacing,
   or z-order.
   ============================================================================ */

/* ── TITLE: rounded uncial, painted in orpiment with a red-lead under-shadow ─
   Insular incipits were laid in as paint, not gilt leaf. We re-state the
   gilt-text idea locally so the under-shadow can be RED-LEAD rather than the
   default brown — that reads "painted on vellum", not "embossed metal".      */
.sc2-scroll[data-family="hibernian_knotwork"] .sc2-title {
  font-family: var(--ff-title);
  letter-spacing: var(--ls-title);
  line-height: .96;
  background: linear-gradient(
                176deg,
                var(--gold-hi)      0%,
                var(--gold)        34%,
                var(--gold-deep)   68%,
                var(--gold-shadow) 100%);
  -webkit-background-clip: text;
          background-clip: text;
  color: transparent;
  -webkit-text-stroke: .6px var(--gold-keyline);
  filter:
    drop-shadow(0 1px 0 var(--gold-hi))
    drop-shadow(0 2px 1px rgba(193,68,14,.30));  /* red-lead under-shadow */
}
/* Export / print: background-clip:text degrades in html2canvas + some PDF
   engines (see sf-tokens flattening flags). Fall back to solid orpiment. */
.sc2-scroll[data-family="hibernian_knotwork"].sc2-export .sc2-title {
  background: none;
  -webkit-text-fill-color: var(--gold);
  color: var(--gold);
  -webkit-text-stroke: .5px var(--gold-keyline);
  text-shadow: 0 1px 0 var(--gold-keyline);
  filter: none;
}

/* ── INVOCATION: quiet, reverent line above the great uncial title ──────────
   "Let it be known to all who walk beneath the greenwood…"                   */
.sc2-scroll[data-family="hibernian_knotwork"] .sc2-invocation {
  color: var(--ink-muted);
  font-style: italic;
  letter-spacing: var(--ls-invocation);
}

/* ── INTITULATION / SECTION OPENERS: red-lead small-caps ─────────────────── */
.sc2-scroll[data-family="hibernian_knotwork"] .sc2-intitulation {
  color: var(--rubric);
  letter-spacing: var(--ls-intitulation);
  font-feature-settings: "smcp" 1, "onum" 1;
}

/* ── RECIPIENT NAME RUBRIC: red-lead — the hottest mark on the sheet ──────── */
.sc2-scroll[data-family="hibernian_knotwork"] .sc2-rubric {
  color: var(--rubric);
}

/* ── VERSAL / DROP-CAP: uncial letter inside a WOAD knotwork initial box ─────
   Woad ground with a faint verdigris corner wash and an orpiment knot
   keyline; the versal itself in pale orpiment so it lifts off the blue.
   The illumination partial owns the box geometry — this only colours it.     */
.sc2-scroll[data-family="hibernian_knotwork"] .sc2-versal,
.sc2-scroll[data-family="hibernian_knotwork"] .sc2-body > p:first-of-type::first-letter {
  font-family: var(--ff-versal);
  color: var(--gold-hi);
  background:
    radial-gradient(120% 120% at 18% 14%, var(--accent-soft) 0%, transparent 46%),
    linear-gradient(135deg, #34507e 0%, var(--initial-ground) 60%, #213657 100%);
  border: 2px solid var(--gold);
  box-shadow:
    inset 0 0 0 1px var(--gold-keyline),
    inset 0 2px 6px rgba(0,0,0,.40),
    0 1px 2px rgba(0,0,0,.30);
  -webkit-text-stroke: .5px var(--gold-keyline);
  text-shadow: 0 1px 2px rgba(0,0,0,.45);
}

/* ── GRANT / DISPOSITIVE CLAUSE: olive-inked emphasis ─────────────────────── */
.sc2-scroll[data-family="hibernian_knotwork"] .sc2-grant {
  color: var(--ink);
  font-style: italic;
}

/* ── DATUM (date & place): muted olive small-caps, period form ────────────── */
.sc2-scroll[data-family="hibernian_knotwork"] .sc2-datum {
  color: var(--ink-muted);
  font-variant: small-caps;
  letter-spacing: .04em;
}

/* ── ATTESTATION / SIGNATURE: chancery italic, olive titles ───────────────── */
.sc2-scroll[data-family="hibernian_knotwork"] .sc2-attest {
  font-family: var(--ff-sign);
  font-style: italic;
  color: var(--ink);
}
.sc2-scroll[data-family="hibernian_knotwork"] .sc2-attest .sc2-sign-title {
  color: var(--ink-muted);
  font-variant: small-caps;
  letter-spacing: .05em;
}

/* ── ILLUMINATION BAND HOOKS — consumed by the inline-SVG <pattern>/<path> ───
   The illumination partial paints the band from these custom properties. We
   name the woad ground + orpiment strand + verdigris secondary so a two-stroke
   Insular interlace draws: woad field, orpiment band, dark keyline core for
   the consistent over/under reading, verdigris cross-strand for colour play.  */
.sc2-scroll[data-family="hibernian_knotwork"] .sc2-illum {
  --band-ground:    var(--border);        /* woad ground under the knot         */
  --band-strand:    var(--gold);          /* orpiment interlace strand          */
  --band-strand-hi: var(--gold-hi);       /* strand top-light                   */
  --band-keyline:   var(--gold-keyline);  /* dark recess between strands         */
  --band-second:    var(--accent);        /* verdigris secondary strand          */
}

/* Bar-border in woad with an orpiment hairline so the solid bar reads Insular
   rather than generic. */
.sc2-scroll[data-family="hibernian_knotwork"] .sc2-border .sc2-bar {
  fill: var(--border);
  stroke: var(--gold);
  stroke-width: .75;
}

/* Decorated band: TWO-STROKE knotwork = a fat orpiment strand carrying a dark
   keyline core, crossed over a thinner verdigris strand on the over/under
   grid. The illumination partial draws the path geometry; these style it. */
.sc2-scroll[data-family="hibernian_knotwork"] .sc2-border .sc2-knot-strand {
  fill: none;
  stroke: var(--gold);
  stroke-width: 6;
  stroke-linecap: round;
  stroke-linejoin: round;
}
.sc2-scroll[data-family="hibernian_knotwork"] .sc2-border .sc2-knot-core {
  fill: none;
  stroke: var(--gold-keyline);
  stroke-width: 1.4;
  stroke-linecap: round;
  stroke-linejoin: round;
}
.sc2-scroll[data-family="hibernian_knotwork"] .sc2-border .sc2-knot-second {
  fill: none;
  stroke: var(--accent);
  stroke-width: 3.4;
  stroke-linecap: round;
  stroke-linejoin: round;
}

/* Zoomorphic terminals — the animal-head ends of the interlace bands. */
.sc2-scroll[data-family="hibernian_knotwork"] .sc2-border .sc2-zoomorph {
  fill: var(--gold);
  stroke: var(--gold-keyline);
  stroke-width: 1;
}
.sc2-scroll[data-family="hibernian_knotwork"] .sc2-border .sc2-zoomorph-eye {
  fill: var(--rubric);   /* red-lead eye — the one hot dot in the band */
}

/* Corner pieces — densest ornament: triskele spirals nesting at each corner. */
.sc2-scroll[data-family="hibernian_knotwork"] .sc2-border .sc2-triskele {
  fill: none;
  stroke: var(--gold);
  stroke-width: 5;
  stroke-linecap: round;
}
.sc2-scroll[data-family="hibernian_knotwork"] .sc2-border .sc2-triskele-boss {
  fill: var(--accent);                  /* verdigris central boss */
  stroke: var(--gold-keyline);
  stroke-width: 1;
}

/* ── WAX SEAL — green perpetual wax, vesica sigil ──────────────────────────
   The heraldry/seal partial owns the seal geometry; this only colours the
   green wax body, its rim, and the slightly-raised orpiment sigil knot.      */
.sc2-scroll[data-family="hibernian_knotwork"] .sc2-seal .sc2-wax-body {
  fill: var(--wax);
}
.sc2-scroll[data-family="hibernian_knotwork"] .sc2-seal .sc2-wax-rim {
  stroke: var(--wax-lo);
}
.sc2-scroll[data-family="hibernian_knotwork"] .sc2-seal .sc2-wax-sigil {
  fill: none;
  stroke: var(--wax-lo);
  stroke-width: 2;
  filter: drop-shadow(0 1px 0 var(--wax-hi));  /* embossed catch-light */
}

/* ── RULING — Insular hard-point ruling reads cool, dry, faint ────────────── */
.sc2-scroll[data-family="hibernian_knotwork"] .sc2-ruling {
  opacity: .12;
}

/* ===== family: northern_gothic ===== */
/* ============================================================================
   THE LETTERED SCROLL — family-northern_gothic.css.part
   ----------------------------------------------------------------------------
   FAMILY: Northern Gothic  ·  key: northern_gothic
   ----------------------------------------------------------------------------
   THE CANONICAL "real medieval charter." A heavy royal decree: blackletter
   textura title in raised gilt, an iconic LAPIS bar border that sprouts
   marginal hedera (ivy) — wavy hairline tendrils carrying small cordate
   leaves alternating gold/green, dotted with gold spangles (besants). Dense
   foliate clusters in every corner. This is the auto-pick for TITLE awards.

   This partial OWNS the look of the scroll only when [data-family="northern_gothic"].
   It RE-SETS shared tokens (substrate trio, ink/rubric, full --gold ramp,
   --border lapis, --rule-fine, --initial-ground, --wax*, --ribbon-*,
   --escutcheon, --ff-title, --accent, the --motif hook) and adds
   family-specific ornament selectors. Per the scoping contract it MUST NOT
   touch z-index, layout, spacing, shadow helpers, or motion tokens — those
   stay owned by sf-tokens / the structural partials.
   ============================================================================ */

/* ===========================================================================
   1. TOKEN OVERRIDES  ·  scoped to the family so dark-mode can never reach in
   =========================================================================== */
.sc2-scroll[data-family="northern_gothic"] {

  /* ── SUBSTRATE / VELLUM ──────────────────────────────────────────────────
     A cool, well-prepared northern calf-skin: a touch greyer/cooler than the
     warm Crimson Decree baseline so the lapis border sings against it.       */
  --vellum:            #f3e7c6;
  --vellum-hi:         #faf0d6;
  --vellum-lo:         #d8bf8d;
  --grime:             rgba(46,38,22,.34);   /* cooler edge grime             */
  --foxing:            #a98a55;              /* used at 8–18% alpha            */
  --ruling:            #8d8369;              /* faint scribal ruling/pricking  */
  --curl-shadow:       rgba(40,32,14,.36);

  /* ── INK ─────────────────────────────────────────────────────────────────
     Near-black iron-gall, very dark for a formal charter — but NEVER #000.   */
  --ink:               #1c1810;
  --ink-muted:         #4a3a24;              /* labels / intitulation / titles */
  --rubric:            #b71c2a;              /* vivid vermilion rubric         */

  /* ── GILDING (raised gold — always the gradient recipe, never flat) ──────
     A rich, slightly deep medieval leaf-gold ramp.                          */
  --gold:              #d4af37;
  --gold-hi:           #fff4c2;
  --gold-deep:         #a9760a;
  --gold-shadow:       #6e4d08;
  --gold-keyline:      #5a3d0c;

  /* ── BORDER / FRAME — the signature LAPIS bar ────────────────────────────
     Lapis lazuli ultramarine: the most expensive medieval pigment, reserved
     for the grandest charters. This is what makes Northern Gothic read as a
     true royal decree on sight.                                              */
  --border:            #2a4b8d;
  --rule-fine:         #1d3666;              /* deep lapis hairline outer rule */
  --initial-ground:    #2a4b8d;             /* lapis ground behind the versal */

  /* ── ACCENT — the ivy GREEN that alternates with gold on the marginal vine */
  --accent:            #2e6b3a;              /* verdigris / sap-green leaf      */
  --accent-soft:       rgba(46,107,58,.26); /* washed green tendril fill       */

  /* Family-private hedera tokens (consumed only by the ornament selectors
     in §2 below — kept here so the whole palette lives in one block).        */
  --ng-lapis:          #2a4b8d;
  --ng-lapis-hi:       #4f74bf;             /* lapis catch-light / azurite      */
  --ng-lapis-lo:       #1b3263;             /* lapis recess                     */
  --ng-leaf-gold:      #d8b13f;
  --ng-leaf-green:     #2e6b3a;
  --ng-leaf-green-hi:  #4f9657;
  --ng-besant:         #e9c64a;             /* gold spangle dot                 */
  --ng-tendril:        #6e4d08;             /* hairline vine stroke (dark gold) */

  /* ── WAX SEAL — oxblood charter wax on a livery ribbon ───────────────────*/
  --wax:               #8c1d1b;
  --wax-hi:            #b73a2c;
  --wax-lo:            #54100f;
  --ribbon-a:          #2a4b8d;             /* lapis livery ribbon tail         */
  --ribbon-b:          #d4af37;             /* gilt metal ribbon tail           */

  /* ── HERALDRY ────────────────────────────────────────────────────────────
     Classic English heater shield for the canonical charter look.           */
  --escutcheon:        heater;
  --arms-rim:          var(--gold);
  --arms-keyline:      #16244a;             /* lapis-dark shield keyline        */

  /* ── TYPOGRAPHY — TITLE FACE ONLY (body/sign stay shared serifs) ─────────
     UnifrakturMaguntia = textura quadrata, the canonical charter blackletter.
     Single-weight trap respected: NEVER request a bold for it.              */
  --ff-title:          "UnifrakturMaguntia","UnifrakturCook","Pirata One","Times New Roman",serif;
  /* body (EB Garamond) + signature (EB Garamond italic) inherit shared
     stacks — no override needed; the brief specifies exactly those.         */

  /* ── MOTIF HOOK — the structural border partial reads this to switch the
     <pattern>/<path> set it paints into .sc2-border. Locked informational
     contract; value names this family's motif.                             */
  --motif:             "gothic-bar-ivy";
}

/* ===========================================================================
   2. FAMILY ORNAMENT  ·  the bar-and-ivy illumination
   ---------------------------------------------------------------------------
   The shared illumination partial provides the concentric zones (fine rule →
   bar border → decorated band → corner pieces → bas-de-page). Here we DRESS
   those zones for Northern Gothic: lapis bars that sprout a gilt/green hedera
   vine with besant spangles, and heavy foliate corner clusters.
   =========================================================================== */

/* --- 2a. The lapis BAR border gets dimensional pigment, not a flat fill ---
   A vertical lapis gradient (azurite highlight → ultramarine body → recess)
   sells hand-ground mineral pigment laid thick. A thin gilt keyline on the
   inner edge separates it from the vellum like real applied gold leaf.      */
.sc2-scroll[data-family="northern_gothic"] .sc2-illum .sc2-bar,
.sc2-scroll[data-family="northern_gothic"] .sc2-border .ng-bar {
  fill: var(--ng-lapis);
  --bar-grad: linear-gradient(
      90deg,
      var(--ng-lapis-lo)  0%,
      var(--ng-lapis)     22%,
      var(--ng-lapis-hi)  50%,
      var(--ng-lapis)     78%,
      var(--ng-lapis-lo) 100%);
  background: var(--bar-grad);
  box-shadow:
      inset 0 0 0 1px rgba(11,20,46,.55),                 /* recessed keyline */
      inset 0 1px 0 rgba(120,150,220,.45),                /* top catch-light  */
      inset 0 -1px 1px rgba(8,16,38,.55);                 /* bottom shade     */
}

/* SVG twin of the bar gradient for the inline <linearGradient id> the border
   SVG references (sf paints id="sc2-bar-grad" when --motif resolves here).   */
.sc2-scroll[data-family="northern_gothic"] .sc2-border .ng-bar-stop-0  { stop-color: var(--ng-lapis-lo); }
.sc2-scroll[data-family="northern_gothic"] .sc2-border .ng-bar-stop-1  { stop-color: var(--ng-lapis);    }
.sc2-scroll[data-family="northern_gothic"] .sc2-border .ng-bar-stop-2  { stop-color: var(--ng-lapis-hi); }
.sc2-scroll[data-family="northern_gothic"] .sc2-border .ng-bar-stop-3  { stop-color: var(--ng-lapis);    }
.sc2-scroll[data-family="northern_gothic"] .sc2-border .ng-bar-stop-4  { stop-color: var(--ng-lapis-lo); }

/* Thin applied-gold keyline running the inner edge of the lapis bar. */
.sc2-scroll[data-family="northern_gothic"] .sc2-border .ng-bar-gilt-rule {
  fill: none;
  stroke: url(#sc2-gild);
  stroke-width: 1.25;
  stroke-opacity: .9;
}

/* --- 2b. The marginal HEDERA (ivy) vine -----------------------------------
   Wavy hairline tendril stroked in dark gold; cordate (heart) leaves
   alternate gold and sap-green; gold besant spangles punctuate the line.
   These selectors style whatever <path>/<circle> nodes the border partial
   emits with these classes for the "gothic-bar-ivy" motif.                  */

/* the sinuous vine stroke itself — thin, hand-inked, slightly translucent */
.sc2-scroll[data-family="northern_gothic"] .sc2-border .ng-vine {
  fill: none;
  stroke: var(--ng-tendril);
  stroke-width: 1.3;
  stroke-linecap: round;
  stroke-linejoin: round;
  stroke-opacity: .85;
}
/* fine hairline branchlets feathering off the main vine */
.sc2-scroll[data-family="northern_gothic"] .sc2-border .ng-vine--hair {
  stroke-width: .8;
  stroke-opacity: .7;
}

/* cordate leaves — every other one gold, the rest green, both with a gilt
   keyline so they read as illuminated rather than printed.                  */
.sc2-scroll[data-family="northern_gothic"] .sc2-border .ng-leaf {
  stroke: var(--gold-keyline);
  stroke-width: .6;
  stroke-opacity: .55;
}
.sc2-scroll[data-family="northern_gothic"] .sc2-border .ng-leaf--gold {
  fill: var(--ng-leaf-gold);
}
.sc2-scroll[data-family="northern_gothic"] .sc2-border .ng-leaf--green {
  fill: var(--ng-leaf-green);
}
/* a slim raised midrib + highlighted lobe to give each leaf body */
.sc2-scroll[data-family="northern_gothic"] .sc2-border .ng-leaf-midrib {
  fill: none;
  stroke: var(--gold-keyline);
  stroke-width: .5;
  stroke-opacity: .4;
}
.sc2-scroll[data-family="northern_gothic"] .sc2-border .ng-leaf--green .ng-leaf-hi {
  fill: var(--ng-leaf-green-hi);
  opacity: .5;
}
.sc2-scroll[data-family="northern_gothic"] .sc2-border .ng-leaf--gold .ng-leaf-hi {
  fill: var(--gold-hi);
  opacity: .55;
}

/* gold besant spangles dotted along the vine — raised gilt beads */
.sc2-scroll[data-family="northern_gothic"] .sc2-border .ng-besant {
  fill: var(--ng-besant);
  stroke: var(--gold-keyline);
  stroke-width: .5;
  stroke-opacity: .65;
}
.sc2-scroll[data-family="northern_gothic"] .sc2-border .ng-besant-hi {
  fill: var(--gold-hi);
  opacity: .7;
}

/* --- 2c. Heavy foliate CORNER clusters ------------------------------------
   The densest ornament: a balled-up knot of acanthus/hedera at each corner,
   lapis ground with gilt foliage so the corners anchor the whole frame.     */
.sc2-scroll[data-family="northern_gothic"] .sc2-border .ng-corner {
  /* corner cluster wrapper — purely so transforms/opacity can target it */
  transform-box: fill-box;
}
.sc2-scroll[data-family="northern_gothic"] .sc2-border .ng-corner-ground {
  fill: var(--ng-lapis);
  stroke: var(--gold-keyline);
  stroke-width: 1;
  stroke-opacity: .8;
  filter: drop-shadow(0 1px 1px rgba(8,16,38,.5));
}
.sc2-scroll[data-family="northern_gothic"] .sc2-border .ng-corner-leaf {
  fill: url(#sc2-gild);                       /* gilt acanthus on lapis        */
  stroke: var(--gold-keyline);
  stroke-width: .5;
  stroke-opacity: .5;
}
.sc2-scroll[data-family="northern_gothic"] .sc2-border .ng-corner-leaf--green {
  fill: var(--ng-leaf-green);
}
.sc2-scroll[data-family="northern_gothic"] .sc2-border .ng-corner-boss {
  /* central gilded boss/jewel of the corner knot */
  fill: var(--ng-besant);
  stroke: var(--gold-keyline);
  stroke-width: .75;
  filter: drop-shadow(0 1px 1px rgba(40,20,0,.4));
}

/* ===========================================================================
   3. TITLE — raised gilt blackletter textura
   ---------------------------------------------------------------------------
   The grand display line. UnifrakturMaguntia in the LOCKED gilt-TEXT recipe:
   the gold gradient clipped to glyphs, dark keyline stroke, layered drop-
   shadows so the letters read as raised tooled gold leaf. Never tracked wide
   (blackletter must stay tight to remain legible).
   =========================================================================== */
.sc2-scroll[data-family="northern_gothic"] .sc2-title {
  /* reset the global orkui h1 grey pill — this heading is illuminated gold   */
  background: linear-gradient(
      135deg,
      var(--gold-shadow)  0%,
      var(--gold)        18%,
      var(--gold-hi)     38%,
      var(--gold)        58%,
      var(--gold-deep)   82%,
      var(--gold-shadow)100%);
  -webkit-background-clip: text;
          background-clip: text;
  color: transparent;
  -webkit-text-stroke: .75px var(--gold-keyline);
  border: none;
  padding: 0;
  border-radius: 0;
  text-shadow: none;
  filter:
      drop-shadow(0 1px 0 var(--gold-hi))
      drop-shadow(0 2px 2px rgba(40,20,0,.35));

  font-family: var(--ff-title);
  font-weight: 400;                /* UnifrakturMaguntia is 400-only          */
  letter-spacing: var(--ls-title); /* tight — never widen blackletter         */
  line-height: 1.04;
  text-align: center;
}

/* A thin vermilion underscore-rule beneath the title, the way a charter
   scribe would rule off the grand line from the body — drawn with the
   field's rubric so it ties title → border → seal together.                 */
.sc2-scroll[data-family="northern_gothic"] .sc2-title::after {
  content: "";
  display: block;
  width: 46%;
  height: 2px;
  margin: .42em auto 0;
  background:
      linear-gradient(90deg,
        transparent 0%,
        var(--rubric) 20%,
        var(--rubric) 80%,
        transparent 100%);
  opacity: .8;
}

/* ===========================================================================
   4. VERSAL DROP-CAP — illuminated initial on a LAPIS ground
   ---------------------------------------------------------------------------
   The opening word's first letter sits in a square lapis-ground initial box
   with a gilt keyline and corner besants — the hallmark of a textura charter.
   The letter itself is gilt; tiny white-line (bianchi girari) flourishes are
   suggested by the inner highlight.
   =========================================================================== */
.sc2-scroll[data-family="northern_gothic"] .sc2-body > p:first-of-type::first-letter,
.sc2-scroll[data-family="northern_gothic"] .sc2-versal {
  font-family: var(--ff-versal);
  font-weight: 400;
  color: transparent;
  background: linear-gradient(
      150deg,
      var(--gold-hi)    0%,
      var(--gold)      40%,
      var(--gold-deep) 78%,
      var(--gold-shadow)100%);
  -webkit-background-clip: text;
          background-clip: text;
  -webkit-text-stroke: .6px var(--gold-keyline);
}

/* the decorated initial BOX (rendered by typography partial as .sc2-versal-box) */
.sc2-scroll[data-family="northern_gothic"] .sc2-versal-box {
  background:
      /* corner besants suggested as tiny radial spangles */
      radial-gradient(circle at 10% 10%, var(--ng-besant) 0 2.2px, transparent 2.6px),
      radial-gradient(circle at 90% 10%, var(--ng-besant) 0 2.2px, transparent 2.6px),
      radial-gradient(circle at 10% 90%, var(--ng-besant) 0 2.2px, transparent 2.6px),
      radial-gradient(circle at 90% 90%, var(--ng-besant) 0 2.2px, transparent 2.6px),
      /* lapis ground with a subtle azurite catch-light upper-left */
      radial-gradient(120% 120% at 28% 22%,
        var(--ng-lapis-hi) 0%, var(--ng-lapis) 45%, var(--ng-lapis-lo) 100%);
  box-shadow:
      inset 0 0 0 1.5px var(--gold-keyline),              /* gilt keyline      */
      inset 0 0 0 2.5px rgba(255,244,194,.35),            /* inner gold glow   */
      0 1px 2px rgba(8,16,38,.45);                        /* slight lift       */
  border-radius: 2px;
}

/* ===========================================================================
   5. RUBRIC & SECTION ACCENTS
   ---------------------------------------------------------------------------
   The recipient's name and section openers in vermilion, per the manuscript
   rubrication convention. Intitulation small-caps tinted with lapis ink for
   the royal-decree register.
   =========================================================================== */
.sc2-scroll[data-family="northern_gothic"] .sc2-rubric,
.sc2-scroll[data-family="northern_gothic"] .sc2-recipient {
  color: var(--rubric);
}

/* the intitulation ("Know all by these presents…") opener — lapis small-caps,
   the grand cool counterpoint to the warm gilt title.                       */
.sc2-scroll[data-family="northern_gothic"] .sc2-intitulation {
  color: var(--ng-lapis);
  font-family: var(--ff-smallcaps);
  font-variant: small-caps;
  letter-spacing: var(--ls-intitulation);
}

/* the dispositive GRANT clause sits a hair larger, justified, with a small
   gilt paraph mark to open it (drawn by typography partial as ::before).    */
.sc2-scroll[data-family="northern_gothic"] .sc2-grant {
  color: var(--ink);
}
.sc2-scroll[data-family="northern_gothic"] .sc2-grant::before {
  color: var(--gold-deep);
}

/* ===========================================================================
   6. WAX SEAL — pendant oxblood charter seal on a lapis/gilt livery ribbon
   ---------------------------------------------------------------------------
   The seal partial draws the geometry; here we only tint the SVG fills via
   the family --wax* / --ribbon-* tokens already set in §1, plus a small
   embossed-sigil tint so the impressed device reads as struck wax.
   =========================================================================== */
.sc2-scroll[data-family="northern_gothic"] .sc2-seal .sc2-wax-body {
  fill: var(--wax);
}
.sc2-scroll[data-family="northern_gothic"] .sc2-seal .sc2-wax-rim {
  fill: var(--wax-lo);
}
.sc2-scroll[data-family="northern_gothic"] .sc2-seal .sc2-wax-hi {
  fill: var(--wax-hi);
  opacity: .55;
}
/* impressed sigil — darker pooled wax in the recesses of the device */
.sc2-scroll[data-family="northern_gothic"] .sc2-seal .sc2-wax-sigil {
  fill: var(--wax-lo);
  opacity: .85;
}
.sc2-scroll[data-family="northern_gothic"] .sc2-seal .sc2-ribbon--a {
  fill: var(--ribbon-a);
}
.sc2-scroll[data-family="northern_gothic"] .sc2-seal .sc2-ribbon--b {
  fill: var(--ribbon-b);
}

/* ===========================================================================
   7. INTENSITY MODULATION
   ---------------------------------------------------------------------------
   Honor the [data-intensity] hook without touching structural tokens.
   minimal  → mute the marginal ivy so only the lapis bar + corners remain.
   ornate   → richer foxing + fuller vine + gilt spangles at full strength.
   =========================================================================== */
.sc2-scroll[data-family="northern_gothic"][data-intensity="minimal"] .sc2-border .ng-vine,
.sc2-scroll[data-family="northern_gothic"][data-intensity="minimal"] .sc2-border .ng-leaf,
.sc2-scroll[data-family="northern_gothic"][data-intensity="minimal"] .sc2-border .ng-besant {
  opacity: .35;
}
.sc2-scroll[data-family="northern_gothic"][data-intensity="ornate"] .sc2-border .ng-besant {
  filter: drop-shadow(0 1px 1px rgba(40,20,0,.45));
}
.sc2-scroll[data-family="northern_gothic"][data-intensity="ornate"] .sc2-title {
  filter:
      drop-shadow(0 1px 0 var(--gold-hi))
      drop-shadow(0 2px 2px rgba(40,20,0,.4))
      drop-shadow(0 0 6px rgba(212,175,55,.18));   /* faint gilt aura         */
}

/* ===========================================================================
   8. EXPORT / PRINT FLATTENING
   ---------------------------------------------------------------------------
   Per the export contract, .sc2-export / @media print may flatten texture/gilt
   but NOTHING structural. Background-clip:text is unreliable in html2canvas,
   so under export we fall back to a solid gilt colour for the title/versal
   while keeping the keyline so the letters still read as gold.
   =========================================================================== */
.sc2-scroll[data-family="northern_gothic"].sc2-export .sc2-title,
.sc2-scroll[data-family="northern_gothic"].sc2-export .sc2-versal,
.sc2-scroll[data-family="northern_gothic"].sc2-export .sc2-body > p:first-of-type::first-letter {
  background: none;
  -webkit-background-clip: border-box;
          background-clip: border-box;
  color: var(--gold);
  -webkit-text-stroke: .6px var(--gold-keyline);
}

@media print {
  .sc2-scroll[data-family="northern_gothic"] .sc2-title,
  .sc2-scroll[data-family="northern_gothic"] .sc2-versal,
  .sc2-scroll[data-family="northern_gothic"] .sc2-body > p:first-of-type::first-letter {
    background: none;
    -webkit-background-clip: border-box;
            background-clip: border-box;
    color: var(--gold-deep);
    -webkit-text-stroke: .5px var(--gold-keyline);
    -webkit-print-color-adjust: exact;
            print-color-adjust: exact;
  }
  /* ensure the lapis bar + ivy keep their colour in PDF engines */
  .sc2-scroll[data-family="northern_gothic"] .sc2-illum .sc2-bar,
  .sc2-scroll[data-family="northern_gothic"] .sc2-border,
  .sc2-scroll[data-family="northern_gothic"] .sc2-seal {
    -webkit-print-color-adjust: exact;
            print-color-adjust: exact;
  }
}

/* ===== family: provencal_bestiary ===== */
/* ============================================================================
   THE LETTERED SCROLL — family-provencal_bestiary.css.part
   ----------------------------------------------------------------------------
   FAMILY: Provençal Bestiary   ·   key: provencal_bestiary
   IDENTITY: Southern-French Romanesque whimsy. Marginal grotesque beasts and
   clambering acanthus rinceaux, a larger creature cartouche in the bas-de-page,
   thick architectural foliate stems. Warm ivory vellum, vermilion (minium)
   rubric, oxblood wax, a heraldic azure field for the bar-border. A CHARTER OF
   SERVICE, warmly storied ("Be it known to all that…").

   CONTRACT (per sf-tokens.css.part):
     • RE-SET ONLY palette / font / motif tokens + add family ornament
       selectors, all scoped under .sc2-scroll[data-family="provencal_bestiary"].
     • MUST NOT touch z-index, layout geometry, spacing helpers, shadow recipes,
       or motion tokens — those stay shared.
     • No <canvas>, no tiled photo textures, no flat #ffd700, no #fff substrate.
     • All ornament is hand-vector inline-SVG via data-URI background hooks.
     • Dark-mode app chrome can never reach the sheet: tokens scoped to .sc2-scroll.
     • Global h1–h6 pill styling is reset by the shared typography partial; we
       only set face/fill on .sc2-title here, never re-introduce a box.
   ============================================================================ */

/* ============================================================================
   1. PALETTE / TOKEN OVERRIDES
   Warmer ivory vellum than the Crimson baseline; minium-vermilion rubric;
   azure heraldic bar-border; oxblood wax. Gold ramp kept warm/buttery so the
   Romanesque gilding reads as burnished leaf, not brass.
   ============================================================================ */
.sc2-scroll[data-family="provencal_bestiary"] {

  /* ── SUBSTRATE / VELLUM — warm southern ivory ─────────────────────────── */
  --vellum:            #f1e4bd;   /* base ivory parchment body                 */
  --vellum-hi:         #f8efce;   /* lightest center (radial top)              */
  --vellum-lo:         #d8c188;   /* sun-aged edge                            */
  --grime:             rgba(78,54,22,.32);    /* warm edge-grime vignette      */
  --foxing:            #bd8f4f;   /* tan foxing blobs (8–18% alpha in use)     */
  --ruling:            #9c8c63;   /* faint olive-brown ruling + pricking       */
  --curl-shadow:       rgba(64,44,16,.34);    /* cast shadow under rolled curl */

  /* substrate texture hooks read by sf-substrate.css.part */
  --mottle-tint:       #8a6a39;   /* warm tan fiber stain (feColorMatrix tgt)  */
  --foxing-pos:        16% 24%, 73% 12%, 41% 66%, 86% 81%, 28% 88%; /* hand-scattered */

  /* ── INK — deepest warm umber, never #000 ─────────────────────────────── */
  --ink:               #1c1810;   /* charter body ink                          */
  --ink-muted:         #5d4426;   /* labels, intitulation, signature titles    */
  --rubric:            #e34234;   /* minium vermilion: recipient + openers     */

  /* ── GILDING — burnished warm leaf (always the gradient recipe) ─────────── */
  --gold:              #d4af37;   /* mid body gold                             */
  --gold-hi:           #fff1a8;   /* brighter buttery specular for leaf sheen  */
  --gold-deep:         #b8860b;   /* dark goldenrod lower shade                */
  --gold-shadow:       #6f4d09;   /* darkest gold stop                        */
  --gold-keyline:      #5a3d0c;   /* thin dark recess line — sells "raised"    */

  /* ── BORDER / FRAME — heraldic azure field ────────────────────────────── */
  --border:            #3b5998;   /* azure bar-border (Provençal blue field)   */
  --rule-fine:         #5a4424;   /* warm-brown hairline outer rule            */
  --initial-ground:    #6b1f2a;   /* oxblood inhabited-initial ground          */

  /* ── ACCENT — vermilion secondary ornament (beasts/rinceaux highlights) ── */
  --accent:            #e34234;
  --accent-soft:       rgba(227,66,52,.24);   /* washed vermilion filigree      */

  /* family-private structural accents (consumed only by this file's SVG) */
  --pb-azure:          #3b5998;   /* architectural stem field                  */
  --pb-azure-hi:       #6f8fd0;   /* lit edge of a stem                        */
  --pb-azure-lo:       #243a66;   /* shaded core of a stem                     */
  --pb-leaf:           #4e7a3e;   /* sap-green acanthus                        */
  --pb-leaf-hi:        #79a866;
  --pb-beast:          #7a3b1c;   /* grotesque-beast body umber               */

  /* ── WAX SEAL — oxblood with azure/gold livery ribbon ─────────────────── */
  --wax:               #9e1b1b;   /* oxblood wax body                          */
  --wax-hi:            #cf4334;   /* upper-left catch-light                     */
  --wax-lo:            #5c0d0d;   /* pooled center / rim                        */
  --ribbon-a:          #3b5998;   /* azure livery ribbon tail                  */
  --ribbon-b:          #d4af37;   /* gold livery ribbon tail                   */
  --wax-sigil:         var(--gold);       /* embossed beast sigil in gilt       */
  --wax-sigil-shade:   var(--wax-lo);

  /* ── HERALDRY ─────────────────────────────────────────────────────────── */
  --escutcheon:        heater;    /* heater shield suits a Romanesque charter  */
  --arms-rim:          var(--gold);
  --arms-keyline:      #3a2a12;

  /* ── TYPOGRAPHY — Grenze Gotisch title / Gentium body / Cardo italic sig ─
     Grenze Gotisch carries true weights (600 wanted for the storied title).
     Body is Gentium Book Plus (humanist, ligatures + old-style figures).      */
  --ff-title:          "Grenze Gotisch","UnifrakturCook","Times New Roman",serif;
  --ff-body:           "Gentium Book Plus","Cardo","EB Garamond",Georgia,serif;
  --ff-smallcaps:      "IM Fell English SC","Cardo","Gentium Book Plus",serif;
  --ff-sign:           "Cardo","Gentium Book Plus","EB Garamond",serif;  /* render italic */
  --ff-versal:         "Grenze Gotisch","UnifrakturCook",serif;

  /* tighter, heavier display register for the storied charter title          */
  --ls-title:          .005em;
}

/* ============================================================================
   2. TITLE TREATMENT — Romanesque charter display
   Grenze Gotisch 600, warm leaf-gold gilt FILL (still a gradient, never flat).
   Storied, weighty, not spiky. Resets any global heading pill defensively.
   ============================================================================ */
.sc2-scroll[data-family="provencal_bestiary"] .sc2-title {
  font-family: var(--ff-title);
  font-weight: 600;
  letter-spacing: var(--ls-title);
  line-height: .96;
  /* defensive global h1–h6 pill reset (orkui.css adds a gray box) */
  background-color: transparent;
  border: none;
  padding: 0;
  border-radius: 0;
  /* warm leaf-gold gradient, family-tuned */
  background-image: linear-gradient(
                164deg,
                var(--gold-shadow)  0%,
                var(--gold)        20%,
                var(--gold-hi)     42%,
                var(--gold)        60%,
                var(--gold-deep)   84%,
                var(--gold-shadow)100%);
  -webkit-background-clip: text;
          background-clip: text;
  color: transparent;
  -webkit-text-stroke: .7px var(--gold-keyline);
  filter:
    drop-shadow(0 1px 0 var(--gold-hi))
    drop-shadow(0 2px 2px rgba(40,20,0,.34));
}

/* ============================================================================
   3. ILLUMINATED VERSAL — the inhabited initial (family hallmark)
   The opening word's drop-cap sits in an oxblood box over a clambering-acanthus
   ground (the Romanesque "inhabited initial"). We support BOTH the explicit
   .sc2-versal element and the CSS ::first-letter fallback.
   ============================================================================ */
.sc2-scroll[data-family="provencal_bestiary"] .sc2-versal,
.sc2-scroll[data-family="provencal_bestiary"] .sc2-body > p:first-of-type::first-letter {
  font-family: var(--ff-versal);
  font-weight: 600;
  color: var(--gold-hi);
  -webkit-text-stroke: .6px var(--gold-keyline);
  text-shadow:
    0 1px 0 var(--gold-deep),
    0 2px 3px rgba(30,12,4,.45);
}

/* Decorated initial BOX (when markup wraps the versal in .sc2-initial-box):
   oxblood ground + gilt keyline + an inhabited-acanthus SVG field. */
.sc2-scroll[data-family="provencal_bestiary"] .sc2-initial-box {
  background-color: var(--initial-ground);
  background-image: var(--pb-initial-ground);
  background-size: cover;
  background-position: center;
  border: 2px solid var(--gold);
  border-radius: 3px;
  box-shadow:
    inset 0 0 0 1px var(--gold-keyline),
    inset 0 2px 6px rgba(0,0,0,.4),
    0 1px 2px rgba(30,12,4,.4);
}

/* ============================================================================
   4. RUBRIC & SECTION REGISTER — minium vermilion, storied charter voice
   ============================================================================ */
.sc2-scroll[data-family="provencal_bestiary"] .sc2-invocation {
  color: var(--rubric);
  font-family: var(--ff-smallcaps);
  letter-spacing: var(--ls-invocation);
  font-variant: small-caps;
}
.sc2-scroll[data-family="provencal_bestiary"] .sc2-intitulation {
  color: var(--ink-muted);
  font-family: var(--ff-smallcaps);
  letter-spacing: var(--ls-intitulation);
  font-variant: small-caps;
}
/* The recipient name itself, when rubricated in the body. */
.sc2-scroll[data-family="provencal_bestiary"] .sc2-rubric,
.sc2-scroll[data-family="provencal_bestiary"] .sc2-recipient {
  color: var(--rubric);
  font-weight: 600;
}
/* Grant / dispositive clause keeps the warm body face. */
.sc2-scroll[data-family="provencal_bestiary"] .sc2-grant {
  font-family: var(--ff-body);
  color: var(--ink);
}
/* Signatures in Cardo italic chancery. */
.sc2-scroll[data-family="provencal_bestiary"] .sc2-attest,
.sc2-scroll[data-family="provencal_bestiary"] .sc2-attest .sc2-sign {
  font-family: var(--ff-sign);
  font-style: italic;
  color: var(--ink);
}

/* ============================================================================
   5. ILLUMINATION — Romanesque inhabited rinceaux band + corner bosses
   The shared .sc2-border SVG reads --motif for its repeating band body and
   --motif-corner for the corner cluster. We hand-vector both as data-URIs:
   clambering acanthus rinceaux with small grotesque beasts woven into the run,
   thick architectural azure stems, gilt buds, vermilion accents.
   ============================================================================ */

/* ── 5a. REPEATING BAND MOTIF — clambering acanthus rinceaux + marginal beast
   One seamless tile: a fat azure architectural S-stem sprouts sap-green
   acanthus lobes and gilt buds, with a small grotesque dragonet clambering
   through the foliage. Tiles horizontally without a seam. */
.sc2-scroll[data-family="provencal_bestiary"] {
  --motif: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='160' height='52' viewBox='0 0 160 52'%3E%3Cdefs%3E%3ClinearGradient id='pbStem' x1='0' y1='0' x2='0' y2='1'%3E%3Cstop offset='0' stop-color='%236f8fd0'/%3E%3Cstop offset='0.5' stop-color='%233b5998'/%3E%3Cstop offset='1' stop-color='%23243a66'/%3E%3C/linearGradient%3E%3ClinearGradient id='pbLeaf' x1='0' y1='0' x2='1' y2='1'%3E%3Cstop offset='0' stop-color='%2379a866'/%3E%3Cstop offset='1' stop-color='%234e7a3e'/%3E%3C/linearGradient%3E%3CradialGradient id='pbBud' cx='0.4' cy='0.35' r='0.7'%3E%3Cstop offset='0' stop-color='%23fff1a8'/%3E%3Cstop offset='0.55' stop-color='%23d4af37'/%3E%3Cstop offset='1' stop-color='%23b8860b'/%3E%3C/radialGradient%3E%3C/defs%3E%3Cg fill='none'%3E%3Cpath d='M0 38 C 26 38 26 14 52 14 C 78 14 78 38 104 38 C 130 38 130 14 160 14' stroke='url(%23pbStem)' stroke-width='6' stroke-linecap='round'/%3E%3Cpath d='M0 38 C 26 38 26 14 52 14 C 78 14 78 38 104 38 C 130 38 130 14 160 14' stroke='%23243a66' stroke-width='1' opacity='0.5'/%3E%3Cpath d='M52 14 C 48 4 40 2 36 8 C 44 8 48 12 52 14 Z' fill='url(%23pbLeaf)' stroke='%23335529' stroke-width='0.6'/%3E%3Cpath d='M52 14 C 56 4 64 2 68 8 C 60 8 56 12 52 14 Z' fill='url(%23pbLeaf)' stroke='%23335529' stroke-width='0.6'/%3E%3Cpath d='M104 38 C 100 48 92 50 88 44 C 96 44 100 40 104 38 Z' fill='url(%23pbLeaf)' stroke='%23335529' stroke-width='0.6'/%3E%3Cpath d='M104 38 C 108 48 116 50 120 44 C 112 44 108 40 104 38 Z' fill='url(%23pbLeaf)' stroke='%23335529' stroke-width='0.6'/%3E%3Ccircle cx='52' cy='14' r='3.4' fill='url(%23pbBud)' stroke='%235a3d0c' stroke-width='0.7'/%3E%3Ccircle cx='104' cy='38' r='3.4' fill='url(%23pbBud)' stroke='%235a3d0c' stroke-width='0.7'/%3E%3Cg transform='translate(22 26)'%3E%3Cpath d='M0 6 C -4 0 2 -6 8 -4 C 10 -8 16 -8 17 -3 C 22 -2 22 5 16 6 C 16 10 8 11 6 7 C 2 9 -2 9 0 6 Z' fill='%237a3b1c' stroke='%234a2410' stroke-width='0.7'/%3E%3Cpath d='M17 -3 C 21 -6 24 -4 23 0' fill='none' stroke='%237a3b1c' stroke-width='2' stroke-linecap='round'/%3E%3Ccircle cx='19' cy='-3' r='1' fill='%23e34234'/%3E%3Cpath d='M6 7 C 5 12 9 14 12 12' fill='none' stroke='%237a3b1c' stroke-width='1.6' stroke-linecap='round'/%3E%3C/g%3E%3Ccircle cx='130' cy='14' r='1.6' fill='%23e34234'/%3E%3Ccircle cx='26' cy='38' r='1.6' fill='%23e34234'/%3E%3C/g%3E%3C/svg%3E");
}

/* ── 5b. CORNER CLUSTER MOTIF — heavier acanthus boss with a coiled beast
   The densest ornament: a thick azure boss erupting acanthus, crowned by a
   gilt fruit, with a coiled grotesque biting its own foliage (Romanesque). */
.sc2-scroll[data-family="provencal_bestiary"] {
  --motif-corner: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='84' height='84' viewBox='0 0 84 84'%3E%3Cdefs%3E%3ClinearGradient id='pbcStem' x1='0' y1='0' x2='1' y2='1'%3E%3Cstop offset='0' stop-color='%236f8fd0'/%3E%3Cstop offset='0.5' stop-color='%233b5998'/%3E%3Cstop offset='1' stop-color='%23243a66'/%3E%3C/linearGradient%3E%3ClinearGradient id='pbcLeaf' x1='0' y1='0' x2='1' y2='1'%3E%3Cstop offset='0' stop-color='%2379a866'/%3E%3Cstop offset='1' stop-color='%234e7a3e'/%3E%3C/linearGradient%3E%3CradialGradient id='pbcFruit' cx='0.4' cy='0.35' r='0.75'%3E%3Cstop offset='0' stop-color='%23fff1a8'/%3E%3Cstop offset='0.55' stop-color='%23d4af37'/%3E%3Cstop offset='1' stop-color='%23b8860b'/%3E%3C/radialGradient%3E%3CradialGradient id='pbcBoss' cx='0.4' cy='0.35' r='0.8'%3E%3Cstop offset='0' stop-color='%236f8fd0'/%3E%3Cstop offset='1' stop-color='%23243a66'/%3E%3C/radialGradient%3E%3C/defs%3E%3Ccircle cx='14' cy='14' r='9' fill='url(%23pbcBoss)' stroke='%23243a66' stroke-width='1'/%3E%3Ccircle cx='11' cy='11' r='2.4' fill='%236f8fd0' opacity='0.8'/%3E%3Cpath d='M14 14 C 30 18 40 30 46 48 C 52 64 60 72 78 76' fill='none' stroke='url(%23pbcStem)' stroke-width='6' stroke-linecap='round'/%3E%3Cpath d='M28 22 C 24 12 16 10 12 16 C 22 16 26 18 28 22 Z' fill='url(%23pbcLeaf)' stroke='%23335529' stroke-width='0.7'/%3E%3Cpath d='M44 44 C 56 42 62 34 58 26 C 56 36 50 40 44 44 Z' fill='url(%23pbcLeaf)' stroke='%23335529' stroke-width='0.7'/%3E%3Cpath d='M52 60 C 42 66 40 76 48 80 C 46 70 48 64 52 60 Z' fill='url(%23pbcLeaf)' stroke='%23335529' stroke-width='0.7'/%3E%3Ccircle cx='46' cy='48' r='5' fill='url(%23pbcFruit)' stroke='%235a3d0c' stroke-width='0.8'/%3E%3Ccircle cx='44' cy='46' r='1.4' fill='%23fff1a8'/%3E%3Cg transform='translate(58 58)'%3E%3Cpath d='M0 8 C -6 2 0 -8 9 -6 C 13 -12 22 -10 22 -2 C 28 0 27 9 19 10 C 18 16 6 17 4 10 C -1 13 -3 12 0 8 Z' fill='%237a3b1c' stroke='%234a2410' stroke-width='0.8'/%3E%3Cpath d='M22 -2 C 26 -6 22 -12 16 -11' fill='none' stroke='%237a3b1c' stroke-width='2.4' stroke-linecap='round'/%3E%3Ccircle cx='20' cy='-4' r='1.2' fill='%23e34234'/%3E%3Cpath d='M4 10 C 2 18 10 20 14 16' fill='none' stroke='%237a3b1c' stroke-width='2' stroke-linecap='round'/%3E%3C/g%3E%3Ccircle cx='34' cy='30' r='2' fill='%23e34234'/%3E%3Ccircle cx='62' cy='44' r='2' fill='%23e34234'/%3E%3C/svg%3E");
}

/* ── 5c. INHABITED-INITIAL GROUND — acanthus field behind the versal box ── */
.sc2-scroll[data-family="provencal_bestiary"] {
  --pb-initial-ground: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'%3E%3Cdefs%3E%3ClinearGradient id='pbiLeaf' x1='0' y1='0' x2='1' y2='1'%3E%3Cstop offset='0' stop-color='%2379a866'/%3E%3Cstop offset='1' stop-color='%234e7a3e'/%3E%3C/linearGradient%3E%3C/defs%3E%3Crect width='64' height='64' fill='%236b1f2a'/%3E%3Cg opacity='0.85'%3E%3Cpath d='M8 56 C 20 50 18 36 30 30 C 42 24 40 12 52 8' fill='none' stroke='url(%23pbiLeaf)' stroke-width='3' stroke-linecap='round' opacity='0.7'/%3E%3Cpath d='M30 30 C 24 24 14 26 14 34 C 22 32 26 30 30 30 Z' fill='url(%23pbiLeaf)' opacity='0.85'/%3E%3Cpath d='M30 30 C 36 36 46 34 46 26 C 38 28 34 30 30 30 Z' fill='url(%23pbiLeaf)' opacity='0.85'/%3E%3Ccircle cx='52' cy='8' r='2.6' fill='%23d4af37'/%3E%3Ccircle cx='8' cy='56' r='2.6' fill='%23d4af37'/%3E%3Ccircle cx='44' cy='52' r='1.6' fill='%23e34234'/%3E%3Ccircle cx='18' cy='14' r='1.6' fill='%23e34234'/%3E%3C/g%3E%3C/svg%3E");
}

/* ============================================================================
   6. BAS-DE-PAGE DROLLERY — the larger bestiary creature cartouche
   The signature flourish of this family: a big grotesque beast (a manticore-ish
   drollery) lounging across a foliate baseline in the bottom margin, flanking
   the wax seal. Painted onto the explicit .sc2-basdepage element when present;
   else falls back to .sc2-illum::after at the foot so the family never loses
   its bestiary identity regardless of which markup ships.
   ============================================================================ */
.sc2-scroll[data-family="provencal_bestiary"] .sc2-basdepage,
.sc2-scroll[data-family="provencal_bestiary"] .sc2-illum::after {
  content: "";
  position: absolute;
  left: 50%;
  bottom: calc(var(--margin-frame, 7.5%) * 0.30);
  transform: translateX(-50%);
  width: clamp(150px, 34%, 280px);
  height: clamp(46px, 9%, 84px);
  z-index: var(--z-illum, 2);
  pointer-events: none;
  background-repeat: no-repeat;
  background-position: center bottom;
  background-size: contain;
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='280' height='90' viewBox='0 0 280 90'%3E%3Cdefs%3E%3ClinearGradient id='pbdBody' x1='0' y1='0' x2='0' y2='1'%3E%3Cstop offset='0' stop-color='%239a5128'/%3E%3Cstop offset='1' stop-color='%237a3b1c'/%3E%3C/linearGradient%3E%3ClinearGradient id='pbdScroll' x1='0' y1='0' x2='1' y2='0'%3E%3Cstop offset='0' stop-color='%23b8860b'/%3E%3Cstop offset='0.5' stop-color='%23fff1a8'/%3E%3Cstop offset='1' stop-color='%23b8860b'/%3E%3C/linearGradient%3E%3ClinearGradient id='pbdLeaf' x1='0' y1='0' x2='1' y2='1'%3E%3Cstop offset='0' stop-color='%2379a866'/%3E%3Cstop offset='1' stop-color='%234e7a3e'/%3E%3C/linearGradient%3E%3C/defs%3E%3Cpath d='M6 76 C 40 70 60 70 86 74 C 140 80 160 80 196 74 C 222 70 244 70 274 76' fill='none' stroke='url(%23pbdScroll)' stroke-width='3.4' stroke-linecap='round'/%3E%3Cpath d='M6 76 C -2 76 -2 66 8 66 C 4 70 6 74 6 76 Z' fill='url(%23pbdScroll)' stroke='%235a3d0c' stroke-width='0.6'/%3E%3Cpath d='M274 76 C 282 76 282 66 272 66 C 276 70 274 74 274 76 Z' fill='url(%23pbdScroll)' stroke='%235a3d0c' stroke-width='0.6'/%3E%3Cpath d='M40 72 C 30 60 16 60 14 70 C 26 66 34 68 40 72 Z' fill='url(%23pbdLeaf)' stroke='%23335529' stroke-width='0.6'/%3E%3Cpath d='M240 72 C 250 60 264 60 266 70 C 254 66 246 68 240 72 Z' fill='url(%23pbdLeaf)' stroke='%23335529' stroke-width='0.6'/%3E%3Cg transform='translate(112 18)'%3E%3Cpath d='M52 44 C 70 44 78 30 70 20 C 64 12 52 16 56 26 C 60 22 66 24 64 30 C 62 36 54 36 52 44 Z' fill='url(%23pbdBody)' stroke='%234a2410' stroke-width='0.8'/%3E%3Cpath d='M4 46 C -2 36 4 22 18 20 C 22 8 40 8 44 20 C 56 22 58 38 48 44 C 40 50 12 52 4 46 Z' fill='url(%23pbdBody)' stroke='%234a2410' stroke-width='1'/%3E%3Cpath d='M14 44 C 10 34 16 26 24 26' fill='none' stroke='%234a2410' stroke-width='0.7' opacity='0.6'/%3E%3Cpath d='M16 46 L 14 56 M26 47 L 25 57 M40 45 L 41 55' stroke='url(%23pbdBody)' stroke-width='3.2' stroke-linecap='round'/%3E%3Cpath d='M40 20 C 50 12 64 14 66 24 C 62 22 58 22 54 24 C 60 26 62 30 58 32 C 52 30 46 28 44 22 Z' fill='url(%23pbdBody)' stroke='%234a2410' stroke-width='0.9'/%3E%3Cpath d='M44 18 C 46 10 54 8 56 14 M48 16 C 50 8 58 8 60 13' fill='none' stroke='%239a5128' stroke-width='1.6' stroke-linecap='round'/%3E%3Ccircle cx='58' cy='23' r='1.5' fill='%23e34234'/%3E%3Cpath d='M42 26 C 46 30 52 30 56 27' fill='none' stroke='%23d4af37' stroke-width='1.6'/%3E%3C/g%3E%3C/svg%3E");
  filter: drop-shadow(0 1px 1px rgba(40,20,4,.4));
  opacity: .96;
}

/* When an explicit .sc2-basdepage exists, suppress the ::after fallback so the
   creature never double-renders. */
.sc2-scroll[data-family="provencal_bestiary"]:has(.sc2-basdepage) .sc2-illum::after {
  content: none;
}

/* ============================================================================
   7. WAX SEAL — oxblood, gilt pressed-beast sigil
   Tokens (§1) drive wax body / catch-light / ribbon. Here we paint the
   family-specific embossed sigil if the shared seal exposes .sc2-seal-emboss.
   ============================================================================ */
.sc2-scroll[data-family="provencal_bestiary"] .sc2-seal-emboss {
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='48' height='48' viewBox='0 0 48 48'%3E%3Cg fill='none' stroke='%235c0d0d' stroke-width='1.4' stroke-linecap='round'%3E%3Cpath d='M14 32 C 10 24 14 14 24 13 C 34 14 38 24 34 32 C 30 38 18 38 14 32 Z'/%3E%3Cpath d='M30 13 C 34 8 40 10 40 16'/%3E%3Cpath d='M18 33 C 16 38 22 40 26 37'/%3E%3Ccircle cx='30' cy='17' r='1'/%3E%3C/g%3E%3C/svg%3E");
  background-repeat: no-repeat;
  background-position: center;
  background-size: 62%;
}

/* ============================================================================
   8. INTENSITY HOOKS — minimal strips the marginal beasts back to plain
   rinceaux for legibility; ornate lets the corner cluster read a touch larger.
   Structural intensity stays shared; we only adjust this family's extras.
   ============================================================================ */
.sc2-scroll[data-family="provencal_bestiary"][data-intensity="minimal"] .sc2-basdepage,
.sc2-scroll[data-family="provencal_bestiary"][data-intensity="minimal"] .sc2-illum::after {
  display: none;
}
.sc2-scroll[data-family="provencal_bestiary"][data-intensity="ornate"] {
  --motif-corner-scale: 1.08;
}

/* ============================================================================
   9. PRINT / EXPORT — keep ornament crisp and un-dimmed.
   Data-URI SVG ornament rasterizes reliably in print / html2canvas; we only
   force the bas-de-page drollery and band to full opacity for export.
   ============================================================================ */
@media print {
  .sc2-scroll[data-family="provencal_bestiary"] .sc2-basdepage,
  .sc2-scroll[data-family="provencal_bestiary"] .sc2-illum::after {
    opacity: 1;
    -webkit-print-color-adjust: exact;
            print-color-adjust: exact;
  }
}
.sc2-export .sc2-scroll[data-family="provencal_bestiary"] .sc2-basdepage,
.sc2-export .sc2-scroll[data-family="provencal_bestiary"] .sc2-illum::after {
  opacity: 1;
}

/* ===== family: crimson_decree ===== */
/* ============================================================================
   THE LETTERED SCROLL — family-crimson_decree.css.part
   ----------------------------------------------------------------------------
   FAMILY: Crimson Decree   ·   KEY: crimson_decree
   ROLE:   System baseline + KNIGHT auto-pick. Royal decree, top-tier severity.

   "Know all by these presents… do by this Our charter and of Our certain
    knowledge award and proclaim…"

   THE LOOK
     A gules (heraldic crimson) field framed by a single gilt rule and
     restrained acanthus corners. The grand textura title sits beneath a Gothic
     pointed-arch tracery header. Vermilion rubric for the recipient's name.
     A deep sanguine wax seal pressed hard into the bas-de-page. Severe,
     authoritative, peerage-grade — the most formal scroll in the fleet.

   SCOPING CONTRACT (per sf-tokens.css.part — obeyed exactly)
     • This partial RE-SETS ONLY the permitted per-family tokens: the substrate
       trio, --ink / --ink-muted / --rubric, the --gold* ramp, --border,
       --rule-fine, --initial-ground, --accent*, --wax*, --ribbon-*,
       --escutcheon, --ff-title / --ff-versal / --ff-sign, and the --motif hook.
     • It MUST NOT touch z-index, layout, spacing, shadow helpers, motion, or
       the global type SCALE — those are owned by sf-tokens.css.part.
     • Crimson Decree is the spiritual default, but the spec hexes (a warmer,
       lighter, cleaner courtly vellum + darker ink than the generic baseline)
       are stated EXPLICITLY at family scope so the look is locked even if the
       shared baseline later drifts.
     • Component selectors reuse the locked composite tokens
       (--gild-gradient, --shadow-emboss, --gild-shadow, etc.) verbatim rather
       than re-deriving raised-gold shadows.

   Everything below is scoped to [data-family="crimson_decree"]; every ornament
   selector is nested under .sc2-scroll[data-family="crimson_decree"] so it can
   never leak into another family or into the app chrome / dark-mode panel.
   ============================================================================ */

/* ── TOKEN OVERRIDES ─────────────────────────────────────────────────────── */
.sc2-scroll[data-family="crimson_decree"] {

  /* ── SUBSTRATE / VELLUM — clean, formal, courtly parchment ─────────────
     Lighter & less mottled than the rustic families: a decree is fresh-pressed
     chancery vellum, not a weathered field-charter. */
  --vellum:            #f8f4e3;   /* base parchment body                       */
  --vellum-hi:         #fdf9ee;   /* lightest center (radial top)              */
  --vellum-lo:         #e7d9b4;   /* aged edge — restrained, not deep-tanned   */
  --grime:             rgba(74,40,28,.30);   /* edge-grime vignette (warm red) */
  --foxing:            #b98a5a;   /* stain / foxing blobs (used 8–18% alpha)   */
  --ruling:            #9c7d5a;   /* faint ruling + pricking (sanguine-brown)  */
  --curl-shadow:       rgba(70,28,24,.34);   /* cast shadow under rolled curl  */

  /* ── INK — near-black warm sepia; decree gravitas wants the darkest ink ── */
  --ink:               #1c1810;   /* body ink — NEVER #000, but the darkest    */
  --ink-muted:         #5a3526;   /* intitulation, signature titles (sanguine) */
  --rubric:            #7b1f2a;   /* vermilion gules: recipient name + openers */

  /* ── GILDING — bright courtly gold, single-rule gilt ───────────────────── */
  --gold:              #d4af37;
  --gold-hi:           #fff4c2;
  --gold-deep:         #a9760a;
  --gold-shadow:       #6e4d08;
  --gold-keyline:      #5a3d0c;

  /* ── BORDER / FRAME — the gules field colour ───────────────────────────── */
  --border:            #7b1f2a;   /* bar-border = heraldic gules               */
  --rule-fine:         #6e3a1e;   /* hairline outer rule (sanguine-brown ink)  */
  --initial-ground:    #6b1f2a;   /* drop-cap decorated-box ground (deep gules)*/

  /* ── ACCENT — secondary ornament reads as the same royal gules ─────────── */
  --accent:            #7b1f2a;
  --accent-soft:       rgba(123,31,42,.26);   /* washed gules (tracery fill)   */

  /* ── WAX SEAL — deep sanguine, pressed hard ────────────────────────────── */
  --wax:               #8c1d1b;   /* wax body                                  */
  --wax-hi:            #c0392b;   /* upper-left catch-light                     */
  --wax-lo:            #5a0f0f;   /* pooled center / rim                        */
  --ribbon-a:          #7b1f2a;   /* livery colour ribbon tail (gules)         */
  --ribbon-b:          #d4af37;   /* livery metal ribbon tail (or)             */

  /* ── HERALDRY — formal heater shield, gilt rim, dark keyline ───────────── */
  --escutcheon:        heater;    /* clipPath id hook (informational)          */
  --arms-rim:          var(--gold);
  --arms-keyline:      #3a1810;

  /* ── TYPOGRAPHY — grand textura blackletter title; humanist body ───────── */
  --ff-title:          "UnifrakturMaguntia","UnifrakturCook","Pirata One","Times New Roman",serif;
  --ff-sign:           "EB Garamond","Cardo","IM Fell English",serif; /* italic */
  --ff-versal:         "UnifrakturMaguntia","EB Garamond",serif;

  /* ── MOTIF HOOK — drives the illumination layer's pattern choice ───────── */
  --motif:             "gothic-tracery";
}

/* ============================================================================
   FAMILY ORNAMENT  ·  Gothic tracery cartouche, restrained acanthus corners,
   pointed-arch title header, deep-pressed sanguine seal.
   All nested under the family scope so nothing leaks.
   ============================================================================ */

/* ── TITLE — austere, monumental, gilt textura under a pointed arch ──────────
   The decree title is the most severe in the fleet: the locked gilt-text recipe
   (raised gold, never flat), the tightest tracking the spec permits, and a
   heavier sanguine drop so it reads as pressed into the gules header. */
.sc2-scroll[data-family="crimson_decree"] .sc2-title {
  font-family: var(--ff-title);
  letter-spacing: var(--ls-title);
  line-height: .96;
  /* Gilt-text recipe (locked) — reuse the shared gradient + stroke tokens */
  background: var(--gild-gradient);
  -webkit-background-clip: text;
          background-clip: text;
  color: transparent;
  -webkit-text-stroke: var(--gild-text-stroke);
  filter:
    drop-shadow(0 1px 0 var(--gold-hi))
    drop-shadow(0 2px 2px rgba(40,12,0,.38));
}

/* The pointed-arch tracery header sits ABOVE the title. The illumination layer
   injects an inline <svg class="sc2-arch"> as the title's leading sibling;
   here we give the arch its gilt stroke, gules tympanum wash, and spacing. */
.sc2-scroll[data-family="crimson_decree"] .sc2-arch {
  display: block;
  width: clamp(150px, 34%, 300px);
  margin: 0 auto .35rem;
  color: var(--gold);                 /* drives `stroke="currentColor"` */
  filter: drop-shadow(0 1px 1px rgba(60,24,8,.5));
}
.sc2-scroll[data-family="crimson_decree"] .sc2-arch .sc2-arch-stroke {
  fill: none;
  stroke: var(--gold);
  stroke-width: 2.25;
  stroke-linejoin: round;
}
.sc2-scroll[data-family="crimson_decree"] .sc2-arch .sc2-arch-tympanum {
  fill: var(--accent-soft);           /* faint gules wash in the arch field   */
}
.sc2-scroll[data-family="crimson_decree"] .sc2-arch .sc2-arch-cusp {
  fill: var(--gold);                  /* gilt trefoil cusps / finials          */
  stroke: var(--gold-keyline);
  stroke-width: .6;
}

/* ── INVOCATION — courtly small-caps proclamation opener, rubricated ───────── */
.sc2-scroll[data-family="crimson_decree"] .sc2-invocation {
  font-family: var(--ff-smallcaps);
  letter-spacing: var(--ls-invocation);
  color: var(--rubric);               /* rubricated "Know all by these presents" */
  text-transform: uppercase;
}

/* ── INTITULATION — small-caps gravitas, old-style figures ──────────────────── */
.sc2-scroll[data-family="crimson_decree"] .sc2-intitulation {
  font-family: var(--ff-smallcaps);
  letter-spacing: var(--ls-intitulation);
  color: var(--ink-muted);
  font-feature-settings: "smcp" 1, "onum" 1;
}

/* ── RECIPIENT NAME — the central rubric, vermilion, the eye's anchor ──────── */
.sc2-scroll[data-family="crimson_decree"] .sc2-rubric,
.sc2-scroll[data-family="crimson_decree"] .sc2-recipient {
  color: var(--rubric);
  text-shadow: var(--rubric-shadow);
  font-feature-settings: "onum" 1, "liga" 1;
}

/* ── BODY — justified humanist with ligatures & old-style figures ──────────── */
.sc2-scroll[data-family="crimson_decree"] .sc2-body {
  font-family: var(--ff-body);
  text-align: justify;
  text-justify: inter-word;
  hyphens: auto;
  font-feature-settings: "liga" 1, "onum" 1, "kern" 1;
}

/* ── ILLUMINATED VERSAL — gilt textura initial on a deep-gules ground box ────
   Whether the markup uses a floated .sc2-versal element OR ::first-letter, the
   same decorated-initial treatment applies: deep-gules ground, gilt double
   keyline, hot-gold letter. */
.sc2-scroll[data-family="crimson_decree"] .sc2-body > p:first-of-type::first-letter,
.sc2-scroll[data-family="crimson_decree"] .sc2-versal {
  font-family: var(--ff-versal);
  color: var(--gold-hi);
  -webkit-text-fill-color: var(--gold-hi);
  /* The decorated initial BOX: deep gules ground, gilt double keyline. */
  background:
    linear-gradient(135deg,
      color-mix(in srgb, var(--initial-ground) 88%, #000 12%) 0%,
      var(--initial-ground) 55%,
      color-mix(in srgb, var(--initial-ground) 78%, #000 22%) 100%);
  text-shadow:
    0 1px 0 var(--gold-shadow),
    0 0 6px rgba(255,238,180,.35);
  box-shadow:
    inset 0 0 0 1.5px var(--gold),
    inset 0 0 0 3px var(--initial-ground),
    inset 0 0 0 3.75px var(--gold-keyline),
    0 1px 2px rgba(40,12,0,.4);
}

/* ── GRANT / DISPOSITIVE CLAUSE — the operative words, centred chancery ─────── */
.sc2-scroll[data-family="crimson_decree"] .sc2-grant {
  font-family: var(--ff-body);
  font-style: italic;
  text-align: center;
  color: var(--ink);
  font-feature-settings: "onum" 1, "liga" 1;
}

/* ── DATUM (date & place) — period form, muted sanguine small-caps ──────────── */
.sc2-scroll[data-family="crimson_decree"] .sc2-datum {
  font-family: var(--ff-smallcaps);
  letter-spacing: .04em;
  color: var(--ink-muted);
  text-align: center;
  font-feature-settings: "smcp" 1, "onum" 1;
}

/* ── ATTESTATION / SIGNATURES — chancery italic over a gilt sig-rule ────────── */
.sc2-scroll[data-family="crimson_decree"] .sc2-attest {
  font-family: var(--ff-sign);
  font-style: italic;
  color: var(--ink);
}
.sc2-scroll[data-family="crimson_decree"] .sc2-attest .sc2-sigline {
  /* the ruled line a signatory's name rests upon — gilt, thin, hand-inked */
  border-top: 1px solid var(--gold-deep);
  box-shadow: 0 1px 0 rgba(255,244,194,.4);
}
.sc2-scroll[data-family="crimson_decree"] .sc2-attest .sc2-sigtitle {
  font-family: var(--ff-smallcaps);
  font-style: normal;
  letter-spacing: .12em;
  color: var(--ink-muted);
  text-transform: uppercase;
  font-feature-settings: "smcp" 1;
}

/* ── ILLUMINATION BORDER — single gilt rule + gules bar + acanthus corners ───
   Crimson Decree's frame is deliberately RESTRAINED: not a dense interlace
   band like Hibernian, but a clean heraldic bar in gules edged by one bright
   gilt rule, with ornament concentrated only at the corners (acanthus bosses).
   The illumination engineer draws the band geometry; these rules colour it. */
.sc2-scroll[data-family="crimson_decree"] .sc2-border .sc2-rule-fine {
  stroke: var(--gold);
  stroke-width: 1.25;
  fill: none;
  filter: drop-shadow(0 .5px .5px rgba(60,24,8,.55));
}
.sc2-scroll[data-family="crimson_decree"] .sc2-border .sc2-bar {
  /* the gules field bar */
  fill: var(--border);
  stroke: var(--gold-keyline);
  stroke-width: .5;
}
.sc2-scroll[data-family="crimson_decree"] .sc2-border .sc2-band {
  /* decorated band kept narrow & quiet — let the gules read as the field */
  fill: var(--accent-soft);
}

/* Acanthus corner clusters — gilt leaf with a sanguine core boss + gilt pip. */
.sc2-scroll[data-family="crimson_decree"] .sc2-border .sc2-corner-leaf {
  fill: var(--gold);
  stroke: var(--gold-keyline);
  stroke-width: .5;
  filter: var(--gild-drop);
}
.sc2-scroll[data-family="crimson_decree"] .sc2-border .sc2-corner-boss {
  fill: var(--initial-ground);        /* deep-gules central boss               */
  stroke: var(--gold);
  stroke-width: 1;
}
.sc2-scroll[data-family="crimson_decree"] .sc2-border .sc2-corner-boss-pip {
  fill: var(--gold-hi);               /* tiny gilt highlight pip on the boss   */
}

/* ── HERALDRY CROWN — heater shields flanking the title, gilt-rimmed ───────── */
.sc2-scroll[data-family="crimson_decree"] .sc2-arms {
  filter: drop-shadow(0 2px 3px rgba(40,12,0,.4));
}
.sc2-scroll[data-family="crimson_decree"] .sc2-arms img,
.sc2-scroll[data-family="crimson_decree"] .sc2-arms svg {
  border: 2.5px solid var(--arms-rim);
  outline: 1px solid var(--arms-keyline);
  box-shadow:
    inset 0 0 0 1px rgba(255,244,194,.5),
    0 1px 2px rgba(40,12,0,.35);
  background: var(--vellum-hi);
}

/* ── WAX SEAL — deep sanguine, pressed hard, gilt rim, livery ribbons ──────── */
.sc2-scroll[data-family="crimson_decree"] .sc2-seal {
  filter:
    drop-shadow(0 2px 3px rgba(30,6,6,.45))
    drop-shadow(0 0 1px rgba(0,0,0,.4));
}
.sc2-scroll[data-family="crimson_decree"] .sc2-seal .sc2-wax-body {
  fill: var(--wax);
}
.sc2-scroll[data-family="crimson_decree"] .sc2-seal .sc2-wax-rim {
  fill: none;
  stroke: var(--gold-deep);
  stroke-width: 2;
  filter: drop-shadow(0 1px 0 rgba(255,244,194,.45));
}
.sc2-scroll[data-family="crimson_decree"] .sc2-seal .sc2-wax-emboss {
  /* embossed sigil: lit upper-left, shadowed lower-right against pooled wax */
  fill: var(--wax-lo);
  filter:
    drop-shadow(-.5px -.5px .5px rgba(255,180,170,.5))
    drop-shadow(.5px .8px .8px rgba(0,0,0,.5));
}
.sc2-scroll[data-family="crimson_decree"] .sc2-seal .sc2-ribbon-a { fill: var(--ribbon-a); }
.sc2-scroll[data-family="crimson_decree"] .sc2-seal .sc2-ribbon-b { fill: var(--ribbon-b); }

/* ── EXPORT / PRINT — flatten gilt-text sheen to ink-safe gold; keep gules ───
   Under .sc2-export / @media print the renderer flattens texture/gilt
   (background-clip:text drops to transparent in html2canvas and some PDF
   engines). Fall the title back to a solid courtly gold + keyline shadow so
   PNG/PDF never lose the title. Structural tokens untouched. */
.sc2-scroll.sc2-export[data-family="crimson_decree"] .sc2-title {
  background: none;
  -webkit-text-fill-color: var(--gold);
  color: var(--gold);
  -webkit-text-stroke: 0;
  text-shadow: 0 1px 0 var(--gold-keyline);
  filter: drop-shadow(0 1px 1px rgba(40,12,0,.4));
}
@media print {
  .sc2-scroll[data-family="crimson_decree"] .sc2-title {
    background: none;
    -webkit-text-fill-color: var(--gold);
    color: var(--gold);
    -webkit-text-stroke: 0;
    text-shadow: 0 1px 0 var(--gold-keyline);
    filter: drop-shadow(0 1px 1px rgba(40,12,0,.4));
  }
}

/* ===== family: forest_reverie ===== */
/* ============================================================================
   THE LETTERED SCROLL  ·  FAMILY PARTIAL  ·  FOREST REVERIE
   key: forest_reverie
   ----------------------------------------------------------------------------
   "Let it be known to all who walk beneath the greenwood... that {their} name
   be sung at every hearth..."  (scrollCopy C)

   The gentlest, most lyrical family in the fleet. Where the decree families bark
   in vermilion and burnished gold and the gothic families cut cold geometry,
   Forest Reverie WHISPERS: a fae / woodland charter on soft moss-tinted vellum,
   lettered in a hand-carved MedievalSharp display, bordered not by rigid bands
   but by a hand-drawn LEAFY VINE (oak + hawthorn) that wanders, sends out
   tendrils, drops the odd acorn, and lets a tiny bird perch at the corners.
   A living sprig ESCAPES the illuminated initial box and trails into the margin.
   The seal is GREEN wax (verde = perpetual / evergreen). The bas-de-page is a
   soft meadow line rather than a cartouche.

   SCOPING CONTRACT (inherited from sf-tokens.css.part):
     • This file overrides ONLY palette / font / motif / escutcheon tokens and
       adds family-specific ORNAMENT selectors, all under
       .sc2-scroll[data-family="forest_reverie"].
     • It MUST NOT touch the z-index stack, layout geometry, spacing rhythm,
       shadow helper composites, or motion tokens — those stay shared.
     • The vellum is ALWAYS light here (a fae glade in morning, never dark);
       the app's dark-mode theme can never reach it (scoped to .sc2-scroll).

   MEDIUM IS LOCKED: HTML + CSS + inline SVG. No <canvas>, no tiled photos,
   no flat #ffd700, no #fff. The ornament here is intentionally SOFTER and less
   geometric than its siblings — fewer hard rules, more curve, more breath.
   ============================================================================ */

/* ============================================================================
   1 · PALETTE  ·  re-affirm + refine the moss/bark token ramp
   ----------------------------------------------------------------------------
   The brief's palette is authoritative and slightly warmer/greener than the
   baseline stub already living in sf-tokens.css.part. We re-set the ramp here
   so the family file is self-contained and reads as the single source of truth
   for this family's hues. Only palette / font / motif / escutcheon tokens — no
   structural overrides.
   ============================================================================ */
.sc2-scroll[data-family="forest_reverie"] {

  /* ── SUBSTRATE: soft moss-tinted vellum, a glade caught in morning light ── */
  --vellum:            #efe2bd;   /* warm green-gold parchment body            */
  --vellum-hi:         #f6edcb;   /* lightest centre — dappled light           */
  --vellum-lo:         #cdd2a6;   /* aged sage-green edge                       */
  --grime:             rgba(46,58,30,.30);   /* leaf-shadow edge vignette      */
  --foxing:            #9bab6a;   /* lichen / moss foxing (used 8–18% alpha)    */
  --ruling:            #8a9468;   /* faint sage ruling + pricking              */
  --curl-shadow:       rgba(44,52,24,.34);

  /* ── INK: deep loam-brown, never black ──────────────────────────────────── */
  --ink:               #2c1810;   /* dark bark body ink                        */
  --ink-muted:         #4a5530;   /* mossy labels / intitulation / sig titles  */
  --rubric:            #704214;   /* tenné / bark-russet rubric (warm brown)   */

  /* ── GILDING: SOFT mossy gold (orpiment-leaning, gentle, sun-on-leaf) ────── */
  --gold:              #d4a017;   /* soft woodland gold                        */
  --gold-hi:           #f0d27a;   /* warm specular — buttercup catch-light     */
  --gold-deep:         #9c7320;   /* lower shade                               */
  --gold-shadow:       #6a4f12;   /* darkest gold stop                         */
  --gold-keyline:      #5a3d0c;   /* dark recess line — sells "raised"         */

  /* ── BORDER / FRAME: bark brown field, vine grows on it ──────────────────── */
  --border:            #704214;   /* bark-brown bar-border                     */
  --rule-fine:         #4a5530;   /* sage-green hairline outer rule            */
  --initial-ground:    #43745a;   /* verdant initial-box ground                */

  /* ── ACCENT: verdant leaf-green for the secondary foliate ornament ───────── */
  --accent:            #43745a;   /* verdant green                            */
  --accent-soft:       rgba(67,116,90,.26);
  --accent-leaf-hi:    #6fae7e;   /* sunlit leaf highlight (family-local)      */
  --accent-leaf-lo:    #2f5a44;   /* shadowed leaf underside (family-local)    */
  --accent-berry:      #8a3b2a;   /* hawthorn berry / rowan red (family-local) */
  --accent-bark:       #5a3a1a;   /* twig / branch line (family-local)         */

  /* ── WAX SEAL: GREEN wax = perpetual / evergreen ────────────────────────── */
  --wax:               #3c5a3c;   /* evergreen wax body                        */
  --wax-hi:            #5e7d54;   /* upper-left moss catch-light               */
  --wax-lo:            #21381f;   /* pooled centre / rim                       */
  --ribbon-a:          #3c5a3c;   /* livery colour ribbon (forest green)       */
  --ribbon-b:          #d4a017;   /* livery metal ribbon (soft gold)          */

  /* ── HERALDRY: fae → pointed-oval (vesica) achievement ──────────────────── */
  --escutcheon:        vesica;
  --arms-rim:          var(--gold);
  --arms-keyline:      #2f3a1c;

  /* ── TYPOGRAPHY: hand-carved MedievalSharp title; Gentium body; Cardo sign ─ */
  --ff-title:          "MedievalSharp","Uncial Antiqua","Times New Roman",serif;
  --ff-body:           "Gentium Book Plus","Cardo","EB Garamond",Georgia,serif;
  --ff-sign:           "Cardo","Gentium Book Plus","EB Garamond",serif; /* italic */
  --ff-versal:         "MedievalSharp","Gentium Book Plus",serif;

  /* ── MOTIF DATA HOOK: read by illumination engine ───────────────────────── */
  --motif:             "vine-interlace";

  /* ── FAMILY-LOCAL TUNING (non-structural; cosmetic only) ─────────────────
     The greenwood hand is loose. We very slightly open the title tracking and
     soften the title weight feel — MedievalSharp is already hand-drawn, so we
     keep it gentle. These adjust ONLY type cosmetics, never layout boxes.   */
  --ls-title:          .015em;    /* a hair of air between carved letters       */
}

/* ============================================================================
   2 · TITLE  ·  hand-carved, soft, dappled gold
   ----------------------------------------------------------------------------
   MedievalSharp reads as carved into living wood. We let it breathe, give it a
   gentle dappled-light text-shadow rather than a hard emboss, and lean the gilt
   warm. Title only — never the body (display faces are unreadable at body size).
   ============================================================================ */
.sc2-scroll[data-family="forest_reverie"] .sc2-title {
  font-family: var(--ff-title);
  font-weight: 400;
  letter-spacing: var(--ls-title);
  line-height: 1.02;
  /* gilt text recipe (shared), warmed toward leaf-gold. Keep the shared gilt
     text-stroke (do NOT zero it) so the gold keyline reads against #efe2bd. */
  background: var(--gild-gradient);
  -webkit-background-clip: text;
          background-clip: text;
  color: transparent;
  -webkit-text-stroke: var(--gild-text-stroke);
  /* softer than siblings, but deepened toward dark loam so the moss-vellum gilt
     is no longer washed out against #efe2bd */
  filter:
    drop-shadow(0 1px 0 var(--gold-hi))
    drop-shadow(0 2px 3px rgba(34,40,18,.45));
}

/* The opening invocation reads like birdsong drifting in — gentle, sage-toned. */
.sc2-scroll[data-family="forest_reverie"] .sc2-invocation {
  color: var(--accent-leaf-lo);
  font-style: italic;
  letter-spacing: var(--ls-invocation);
}

/* Intitulation small-caps in mossy ink. */
.sc2-scroll[data-family="forest_reverie"] .sc2-intitulation {
  color: var(--ink-muted);
}

/* Recipient name / section openers in warm bark-russet rubric. */
.sc2-scroll[data-family="forest_reverie"] .sc2-body .sc2-rubric,
.sc2-scroll[data-family="forest_reverie"] .sc2-rubric,
.sc2-scroll[data-family="forest_reverie"] .sc2-grant strong {
  color: var(--rubric);
  text-shadow: var(--rubric-shadow);
}

/* Signatures in Cardo italic, mossy ink. */
.sc2-scroll[data-family="forest_reverie"] .sc2-attest {
  font-family: var(--ff-sign);
  font-style: italic;
  color: var(--ink-muted);
}

/* ============================================================================
   3 · SUBSTRATE FLAVOUR  ·  dappled greenwood light
   ----------------------------------------------------------------------------
   The shared substrate engine reads the family tokens; here we add ONLY a
   gentle family-local overlay — soft pools of leaf-filtered light & shade —
   layered over the shared vellum without disturbing its z-order. We attach it
   to .sc2-vellum's own ::after (the substrate partial reserves the element's
   primary background; this adds a single extra multiply wash that reads as
   sun through a canopy). Stays at --z-vellum (no z override).
   ============================================================================ */
.sc2-scroll[data-family="forest_reverie"] .sc2-vellum::after {
  content: "";
  position: absolute;
  inset: 0;
  pointer-events: none;
  /* scattered, asymmetric pools of canopy light (warm) + leaf shade (green) */
  background:
    radial-gradient(38% 30% at 22% 16%, rgba(240,210,122,.16), transparent 70%),
    radial-gradient(30% 26% at 78% 30%, rgba(67,116,90,.12),  transparent 72%),
    radial-gradient(34% 30% at 64% 74%, rgba(240,210,122,.12), transparent 72%),
    radial-gradient(26% 24% at 14% 82%, rgba(47,90,68,.12),    transparent 74%);
  mix-blend-mode: multiply;
  opacity: .9;
}

/* ============================================================================
   4 · ILLUMINATION  ·  the leafy vine border
   ----------------------------------------------------------------------------
   The defining ornament. Rather than the rigid decorated BAND the geometric
   families use, Forest Reverie runs a hand-drawn VINE along the frame: a
   meandering twig (--accent-bark) from which spring alternating oak & hawthorn
   leaves, the occasional acorn, and a berry cluster. It is intentionally a bit
   irregular — the leaves are not perfectly spaced — to read as inked by hand.

   Technique: the shared .sc2-border SVG is themed via currentColor + the gild
   gradient; here we supply the family's leaf/twig FILLS and a tiling vine
   <pattern>-style backing on .sc2-illum built from layered SVG data-URIs so the
   vine survives html2canvas/print (no feDisplacement dependence). The corner
   pieces get the densest cluster + a perched bird.
   ============================================================================ */

/* Frame colour hooks consumed by the shared border SVG (currentColor + accents) */
.sc2-scroll[data-family="forest_reverie"] .sc2-illum {
  color: var(--accent);                 /* foliate stroke currentColor          */
}
.sc2-scroll[data-family="forest_reverie"] .sc2-border .sc2-band-fill   { fill: var(--accent); }
.sc2-scroll[data-family="forest_reverie"] .sc2-border .sc2-leaf-hi     { fill: var(--accent-leaf-hi); }
.sc2-scroll[data-family="forest_reverie"] .sc2-border .sc2-leaf-lo     { fill: var(--accent-leaf-lo); }
.sc2-scroll[data-family="forest_reverie"] .sc2-border .sc2-twig        { stroke: var(--accent-bark); fill: none; }
.sc2-scroll[data-family="forest_reverie"] .sc2-border .sc2-berry       { fill: var(--accent-berry); }
.sc2-scroll[data-family="forest_reverie"] .sc2-border .sc2-acorn-cap   { fill: var(--accent-bark); }
.sc2-scroll[data-family="forest_reverie"] .sc2-border .sc2-acorn-nut   { fill: var(--gold-deep); }
.sc2-scroll[data-family="forest_reverie"] .sc2-border .sc2-gild        { fill: url(#sc2-gild); }

/* The bar-border itself: bark brown, hand-soft (slightly rounded, no hard gilt
   bar — this family wants warmth, not a hard rule). */
.sc2-scroll[data-family="forest_reverie"] .sc2-illum .sc2-bar {
  background: var(--border);
  box-shadow:
    inset 0 0 0 1px rgba(90,58,26,.55),
    inset 0 1px 0 rgba(240,210,122,.18);
  border-radius: 2px;
}

/* ── The wandering vine, drawn as layered inline-SVG data-URIs ──────────────
   Two layers: (1) a continuous twig that meanders along the band, (2) leaves &
   acorns springing off it. Built as background-image on .sc2-illum so it tiles
   along all four sides. Hand-vector oak/hawthorn motif — NO generic swirls. */
.sc2-scroll[data-family="forest_reverie"] .sc2-illum::before {
  content: "";
  position: absolute;
  inset: var(--margin-frame);
  z-index: 0;                            /* within .sc2-illum (--z-illum) only   */
  pointer-events: none;
  /* meandering oak-vine tile, repeated along the frame perimeter */
  background-image:
    url("data:image/svg+xml;utf8,\
<svg xmlns='http://www.w3.org/2000/svg' width='120' height='40' viewBox='0 0 120 40'>\
<path d='M0 28 C 18 12, 30 12, 44 26 S 78 40, 92 24 120 20 120 20' fill='none' stroke='%235a3a1a' stroke-width='2.2' stroke-linecap='round'/>\
<g fill='%2343745a'>\
<path d='M20 16 C 10 6, 24 2, 30 12 C 26 16, 22 18, 20 16 Z'/>\
<path d='M62 30 C 52 38, 50 24, 60 22 C 64 26, 66 30, 62 30 Z'/>\
<path d='M100 14 C 92 4, 106 2, 110 12 C 106 16, 102 16, 100 14 Z'/>\
</g>\
<g fill='%236fae7e'>\
<path d='M44 22 C 38 12, 50 10, 52 18 C 50 22, 46 24, 44 22 Z'/>\
<path d='M84 24 C 78 16, 90 14, 92 22 C 90 26, 86 26, 84 24 Z'/>\
</g>\
<g fill='%238a3b2a'><circle cx='34' cy='24' r='2.1'/><circle cx='38' cy='26' r='2.1'/><circle cx='36' cy='28' r='2.1'/></g>\
<g><ellipse cx='74' cy='30' rx='2.4' ry='3' fill='%239c7320'/><path d='M71.6 28 q2.4 -3 4.8 0 z' fill='%235a3a1a'/></g>\
</svg>");
  background-repeat: repeat;
  background-size: 120px 40px;
  /* keep the vine inside the band region: it shows only along the frame edges,
     masked to a hollow rectangle so the centre stays clear for text */
  -webkit-mask:
    linear-gradient(#000 0 0) padding-box,
    linear-gradient(#000 0 0);
  -webkit-mask-composite: xor;
          mask-composite: exclude;
  padding: var(--band-w);
  opacity: .92;
}

/* Corner clusters: a denser knot of leaves + a tiny perched bird, one per
   corner, drawn as four positioned inline-SVG nodes. The bird is the fae
   signature — small, hand-drawn, never an emoji. */
.sc2-scroll[data-family="forest_reverie"] .sc2-illum .sc2-corner {
  position: absolute;
  width: var(--corner-size);
  height: var(--corner-size);
  z-index: 1;
  pointer-events: none;
  background-repeat: no-repeat;
  background-position: center;
  background-size: contain;
  /* leaf cluster + perched bird */
  background-image:
    url("data:image/svg+xml;utf8,\
<svg xmlns='http://www.w3.org/2000/svg' width='72' height='72' viewBox='0 0 72 72'>\
<path d='M8 64 C 18 40, 30 30, 52 20' fill='none' stroke='%235a3a1a' stroke-width='2.4' stroke-linecap='round'/>\
<g fill='%2343745a'>\
<path d='M20 44 C 10 36, 26 30, 30 40 C 26 46, 22 48, 20 44 Z'/>\
<path d='M34 32 C 24 24, 40 18, 44 28 C 40 34, 36 36, 34 32 Z'/>\
</g>\
<g fill='%236fae7e'>\
<path d='M30 54 C 22 50, 30 40, 36 46 C 36 52, 34 56, 30 54 Z'/>\
<path d='M46 24 C 40 16, 52 12, 54 22 C 50 26, 48 26, 46 24 Z'/>\
</g>\
<g fill='%238a3b2a'><circle cx='14' cy='52' r='2'/><circle cx='17' cy='55' r='2'/></g>\
<g transform='translate(48 8)'>\
<path d='M0 8 C 2 0, 12 0, 14 6 C 18 6, 20 10, 14 12 C 12 18, 2 18, 0 12 C -4 12, -4 8, 0 8 Z' fill='%23704214'/>\
<circle cx='4' cy='7' r='1.3' fill='%23f6edcb'/>\
<path d='M14 7 l6 -2 -5 4 z' fill='%239c7320'/>\
</g>\
</svg>");
}
.sc2-scroll[data-family="forest_reverie"] .sc2-illum .sc2-corner--tl { top: var(--margin-frame); left:  var(--margin-frame); }
.sc2-scroll[data-family="forest_reverie"] .sc2-illum .sc2-corner--tr { top: var(--margin-frame); right: var(--margin-frame); transform: scaleX(-1); }
.sc2-scroll[data-family="forest_reverie"] .sc2-illum .sc2-corner--bl { bottom: var(--margin-frame); left:  var(--margin-frame); transform: scaleY(-1); }
.sc2-scroll[data-family="forest_reverie"] .sc2-illum .sc2-corner--br { bottom: var(--margin-frame); right: var(--margin-frame); transform: scale(-1,-1); }

/* ============================================================================
   5 · ILLUMINATED VERSAL  ·  the initial box + the ESCAPING SPRIG
   ----------------------------------------------------------------------------
   The opening word's first letter sits in a verdant decorated box (--initial-
   ground). The family signature: a living foliate SPRIG springs from the box
   and trails OUT into the left margin — a vine that has escaped its frame, as
   in fae marginalia. Drawn as a positioned inline-SVG that overflows the box.
   ============================================================================ */
.sc2-scroll[data-family="forest_reverie"] .sc2-body > p:first-of-type::first-letter,
.sc2-scroll[data-family="forest_reverie"] .sc2-versal {
  font-family: var(--ff-versal);
  color: var(--gold-hi);
  /* the box: verdant ground, gilt keyline, soft inner moss-shadow.
     Size is owned by the shared base/initial-letter rule — we set NO font-size
     here (invalid width/height on ::first-letter too). Bounded padding+margin
     keep the green ground hugging the glyph (~1.1–1.2× the letter), never a
     panel. */
  padding: .04em .12em;
  margin: .04em .12em 0 0;
  /* deepen the centre stop so the gold-hi letter stays legible on green */
  background:
    radial-gradient(120% 120% at 30% 20%, #3f7559 0%, var(--initial-ground) 52%, #1d4234 100%);
  box-shadow:
    inset 0 0 0 1px var(--gold-keyline),
    inset 0 2px 6px rgba(20,40,28,.55),
    0 1px 2px rgba(20,30,16,.40);
  /* darker text-shadow lifts the buttercup glyph off the moss ground */
  text-shadow:
    0 1px 1px rgba(12,28,18,.85),
    0 0 2px rgba(12,28,18,.55);
  border-radius: 4px;
}

/* The escaping sprig — overflows the versal box into the margin. It reads as a
   single hand-inked tendril with three leaves and a hawthorn berry, leaning out
   and upward like new growth. Family-local element .sc2-versal-sprig (markup
   engineer may include it; if absent this rule is harmlessly inert). */
.sc2-scroll[data-family="forest_reverie"] .sc2-body { position: relative; }
.sc2-scroll[data-family="forest_reverie"] .sc2-versal-sprig {
  position: absolute;
  top: -0.4em;
  left: -2.6em;
  width: 3.4em;
  height: 5.2em;
  z-index: 1;
  pointer-events: none;
  background-repeat: no-repeat;
  background-position: top left;
  background-size: contain;
  background-image:
    url("data:image/svg+xml;utf8,\
<svg xmlns='http://www.w3.org/2000/svg' width='68' height='104' viewBox='0 0 68 104'>\
<path d='M60 96 C 40 80, 34 56, 40 36 C 44 22, 34 12, 18 8' fill='none' stroke='%235a3a1a' stroke-width='2.6' stroke-linecap='round'/>\
<g fill='%2343745a'>\
<path d='M40 60 C 26 54, 30 38, 44 44 C 46 54, 48 64, 40 60 Z'/>\
<path d='M34 84 C 22 80, 28 64, 40 70 C 40 80, 42 88, 34 84 Z'/>\
</g>\
<g fill='%236fae7e'>\
<path d='M42 38 C 30 30, 40 16, 50 24 C 50 34, 50 42, 42 38 Z'/>\
</g>\
<g fill='%238a3b2a'><circle cx='16' cy='9' r='2.4'/><circle cx='12' cy='12' r='2.4'/><circle cx='17' cy='14' r='2.4'/></g>\
<circle cx='44' cy='52' r='1.6' fill='%23d4a017'/>\
</svg>");
  transform: rotate(-4deg);
}

/* ============================================================================
   6 · HERALDRY  ·  vesica (pointed-oval) fae achievement
   ----------------------------------------------------------------------------
   The escutcheon token is 'vesica' (set above). The shared heraldry engine
   clips the arms to a vesica piscis. Here we add the family's gentle gilt rim,
   a verdant ring, and a tiny leaf-cresting where other families crown with a
   coronet — the fae wear living green, not metal crowns.
   ============================================================================ */
.sc2-scroll[data-family="forest_reverie"] .sc2-arms {
  --arms-rim: var(--gold);
}
.sc2-scroll[data-family="forest_reverie"] .sc2-arms .sc2-arms-rim {
  /* soft gilt rim with a verdant inner keyline */
  filter:
    drop-shadow(0 1px 0 var(--gold-hi))
    drop-shadow(0 2px 3px rgba(20,40,24,.35));
}
.sc2-scroll[data-family="forest_reverie"] .sc2-arms .sc2-arms-ring {
  stroke: var(--accent);
  stroke-width: 2;
  fill: none;
  opacity: .85;
}
/* A modest leaf cresting above each shield (the fae "crown"). */
.sc2-scroll[data-family="forest_reverie"] .sc2-arms::before {
  content: "";
  position: absolute;
  left: 50%;
  top: -0.7em;
  width: 2.4em;
  height: 1.1em;
  transform: translateX(-50%);
  pointer-events: none;
  background-repeat: no-repeat;
  background-position: center bottom;
  background-size: contain;
  background-image:
    url("data:image/svg+xml;utf8,\
<svg xmlns='http://www.w3.org/2000/svg' width='48' height='22' viewBox='0 0 48 22'>\
<g fill='%2343745a'>\
<path d='M24 22 C 12 18, 8 6, 18 4 C 22 10, 24 16, 24 22 Z'/>\
<path d='M24 22 C 36 18, 40 6, 30 4 C 26 10, 24 16, 24 22 Z'/>\
</g>\
<g fill='%236fae7e'>\
<path d='M24 22 C 18 14, 20 4, 24 2 C 28 4, 30 14, 24 22 Z'/>\
</g>\
<circle cx='24' cy='3' r='2' fill='%23d4a017'/>\
</svg>");
}

/* ============================================================================
   7 · WAX SEAL  ·  evergreen wax (perpetual), gold ribbon
   ----------------------------------------------------------------------------
   Green wax = a vow that does not wither. The shared seal SVG reads --wax* and
   --ribbon-*; we add a moss-ring rim highlight and emboss a leaf sigil into the
   wax (in place of a crest), keeping the fae tone.
   ============================================================================ */
.sc2-scroll[data-family="forest_reverie"] .sc2-seal .sc2-wax-body {
  fill: var(--wax);
  filter:
    drop-shadow(0 2px 3px rgba(16,28,14,.5));
}
.sc2-scroll[data-family="forest_reverie"] .sc2-seal .sc2-wax-hi  { fill: var(--wax-hi); }
.sc2-scroll[data-family="forest_reverie"] .sc2-seal .sc2-wax-lo  { fill: var(--wax-lo); }

/* Embossed leaf sigil pressed into the green wax (family-local node). */
.sc2-scroll[data-family="forest_reverie"] .sc2-seal .sc2-seal-sigil {
  fill: var(--wax-lo);
  opacity: .9;
}
.sc2-scroll[data-family="forest_reverie"] .sc2-seal .sc2-seal-sigil-hi {
  fill: var(--wax-hi);
  opacity: .6;
}

/* If the markup uses a CSS-only seal fallback, theme it green + leaf-embossed. */
.sc2-scroll[data-family="forest_reverie"] .sc2-seal-wrap .sc2-seal--css {
  background:
    radial-gradient(120% 120% at 32% 26%, var(--wax-hi) 0%, var(--wax) 46%, var(--wax-lo) 100%);
  box-shadow:
    inset 0 2px 5px rgba(40,60,36,.55),
    inset 0 -3px 6px rgba(12,24,12,.6),
    0 6px 14px rgba(16,28,14,.45);
}
/* Leaf embossed into the CSS seal via a centred mask. */
.sc2-scroll[data-family="forest_reverie"] .sc2-seal-wrap .sc2-seal--css::after {
  content: "";
  position: absolute;
  inset: 22%;
  background:
    url("data:image/svg+xml;utf8,\
<svg xmlns='http://www.w3.org/2000/svg' width='40' height='40' viewBox='0 0 40 40'>\
<path d='M20 38 C 6 30, 4 12, 18 4 C 20 14, 22 26, 20 38 Z' fill='%2321381f'/>\
<path d='M20 38 C 34 30, 36 12, 22 4 C 20 14, 18 26, 20 38 Z' fill='%235e7d54'/>\
<path d='M20 6 L20 36' stroke='%2321381f' stroke-width='1.2'/>\
</svg>") center / contain no-repeat;
  opacity: .85;
}

/* Ribbon tails: forest green + soft gold, the fae livery. */
.sc2-scroll[data-family="forest_reverie"] .sc2-seal-wrap .sc2-ribbon-a { background: var(--ribbon-a); }
.sc2-scroll[data-family="forest_reverie"] .sc2-seal-wrap .sc2-ribbon-b { background: var(--ribbon-b); }
.sc2-scroll[data-family="forest_reverie"] .sc2-seal .sc2-ribbon-a-fill { fill: var(--ribbon-a); }
.sc2-scroll[data-family="forest_reverie"] .sc2-seal .sc2-ribbon-b-fill { fill: var(--ribbon-b); }

/* ============================================================================
   8 · BAS-DE-PAGE  ·  a soft meadow line (not a cartouche)
   ----------------------------------------------------------------------------
   Where the imperial / decree families anchor the foot with a heavy cartouche,
   Forest Reverie lays a gentle MEADOW LINE across the bottom margin: low grasses
   and a few wildflowers, hand-drawn, flanking the pendant seal. Lyrical, light.
   ============================================================================ */
.sc2-scroll[data-family="forest_reverie"] .sc2-seal-wrap::before {
  content: "";
  position: absolute;
  left: var(--content-pad);
  right: var(--content-pad);
  bottom: 0.2em;
  height: 1.6em;
  z-index: 0;
  pointer-events: none;
  background-repeat: repeat-x;
  background-position: bottom center;
  background-size: 160px 26px;
  opacity: .85;
  background-image:
    url("data:image/svg+xml;utf8,\
<svg xmlns='http://www.w3.org/2000/svg' width='160' height='26' viewBox='0 0 160 26'>\
<g stroke='%234a5530' stroke-width='1.6' stroke-linecap='round' fill='none'>\
<path d='M6 26 C 4 16, 8 12, 6 4'/>\
<path d='M10 26 C 12 18, 8 14, 12 8'/>\
<path d='M30 26 C 28 18, 32 14, 30 6'/>\
<path d='M34 26 C 36 18, 32 16, 36 10'/>\
<path d='M62 26 C 60 16, 64 12, 62 4'/>\
<path d='M90 26 C 92 18, 88 14, 92 8'/>\
<path d='M118 26 C 116 18, 120 14, 118 6'/>\
<path d='M122 26 C 124 18, 120 16, 124 10'/>\
<path d='M150 26 C 148 16, 152 12, 150 4'/>\
</g>\
<g>\
<circle cx='44' cy='6' r='2.6' fill='%23d4a017'/><circle cx='44' cy='6' r='1' fill='%23704214'/>\
<circle cx='104' cy='8' r='2.6' fill='%238a3b2a'/><circle cx='104' cy='8' r='1' fill='%23f6edcb'/>\
<circle cx='76' cy='4' r='2.4' fill='%236fae7e'/>\
</g>\
</svg>");
}

/* Add a touch more breathing room above the meadow/seal zone (uses shared
   token; does NOT redefine layout, only consumes the reserved extra line). */
.sc2-scroll[data-family="forest_reverie"] .sc2-seal-wrap {
  position: relative;
  margin-top: var(--basdepage-extra);
}

/* ============================================================================
   9 · GRANT / DATUM  ·  gentle woodland register cues
   ----------------------------------------------------------------------------
   The dispositive clause and the date-and-place read softly; we mark the grant
   clause with a sage drop-rule rather than a hard divider, and tint the datum
   in mossy muted ink.
   ============================================================================ */
.sc2-scroll[data-family="forest_reverie"] .sc2-grant {
  position: relative;
  color: var(--ink);
}
.sc2-scroll[data-family="forest_reverie"] .sc2-grant::before {
  content: "";
  display: block;
  width: 38%;
  height: 1px;
  margin: 0 auto var(--gap-tight);
  background:
    linear-gradient(90deg, transparent, var(--accent) 30%, var(--accent) 70%, transparent);
  opacity: .55;
}
.sc2-scroll[data-family="forest_reverie"] .sc2-datum {
  color: var(--ink-muted);
  font-style: italic;
}

/* ============================================================================
   10 · EXPORT / PRINT  ·  flatten gilt text, keep the green warmth
   ----------------------------------------------------------------------------
   background-clip:text degrades in html2canvas / some PDF engines. Under the
   shared export/print flags, fall back to a solid soft-gold title with a leaf-
   keyline shadow. We touch ONLY texture/gilt rendering — nothing structural.
   The vine, sprig, meadow and seal are all baked SVG data-URIs already, so they
   survive rasterisation without modification.
   ============================================================================ */
.sc2-scroll[data-family="forest_reverie"].sc2-export .sc2-title,
@media print {
  .sc2-scroll[data-family="forest_reverie"] .sc2-title {
    background: none;
    -webkit-text-fill-color: var(--gold);
    color: var(--gold);
    -webkit-text-stroke: 0;
    text-shadow:
      0 1px 0 var(--gold-keyline),
      0 2px 2px rgba(34,40,18,.3);
    filter: none;
  }
}

/* Under export, drop the multiply canopy wash to a flatter tint so html2canvas
   doesn't over-darken (blend modes rasterise unevenly). */
.sc2-scroll[data-family="forest_reverie"].sc2-export .sc2-vellum::after {
  mix-blend-mode: normal;
  opacity: .5;
}

/* ===== family: charred_edict ===== */
/* ============================================================================
   THE LETTERED SCROLL — families/family-charred_edict.css.part
   ----------------------------------------------------------------------------
   FAMILY:  Charred Edict   (data-family="charred_edict")
   ROLE:    A battle-scarred martial commendation / valor citation. Scorched,
            darker vellum; heavy foxing and burnt corners; the blackest
            blackletter title in the fleet (Grenze Gotisch 800); near-black
            sanguine wax; inky IM Fell English body. Register: grim, concise
            valor citation read aloud over a muster field.

   THROUGHLINE — this is the GRIM family. It is deliberately the LEAST
   ornamented of the ten: austerity reads as authority. Drama comes from the
   SUBSTRATE (scorch + soot + burnt corners) and the near-black type, NOT from
   foliate filigree. Every scrap of gilt is tarnished and fire-dulled.

   CONTRACT (locked — see sf-tokens.css.part header):
     • This partial RE-SETS ONLY the permitted family tokens (substrate trio,
       --ink / --ink-muted / --rubric, the --gold* ramp, --border, --rule-fine,
       --initial-ground, --accent[-soft], --wax*, --ribbon-*, --escutcheon,
       --arms-*, --ff-title and the body/sign/versal font aliases, --ls-title,
       and the --motif data hook). It MUST NOT touch z-index, layout, spacing,
       the shadow/gilding helper recipes, or the motion tokens.
     • Everything is scoped to .sc2-scroll[data-family="charred_edict"] so the
       app dark-mode theme can never bleed into the vellum, and so this family
       cannot leak onto its neighbours.
     • Family-specific ORNAMENT selectors (burn-bloom, soot, charred corners,
       austere single charcoal rule, iron-bracket corners) live in this file
       only — they bind to the locked sc2-* DOM hooks, never redefine geometry.
     • .sc2-export and @media print may flatten texture/gilt but NOTHING
       structural (§7).

   PALETTE (authoritative for this family):
     vellum #c2a672 / hi #d4ba85 / lo #8a6f44 · ink #1c1810 · rubric #5c0e1a
     gold(tarnished) #a98445 hi #d8b878 deep #7a5e30 keyline #4a3208
     border charcoal #3d2418 · accent sanguine #5c0e1a · initial-ground #3d2418
     wax #5c0e1a (near-black sanguine) lo #2a0808 · foxing(heavy) #6b4a28
     grime rgba(30,18,8,.5)
   ============================================================================ */


/* ============================================================================
   1. TOKEN OVERRIDES  —  scoped to the family
   ----------------------------------------------------------------------------
   These re-set the shared CSS variables to the Charred Edict palette. Because
   this family partial loads AFTER sf-tokens.css.part at equal specificity,
   these values win over the baseline per the locked load order.
   ============================================================================ */
.sc2-scroll[data-family="charred_edict"] {

	/* ── SUBSTRATE / VELLUM ──────────────────────────────────────────────────
	   Scorched, dirty parchment: noticeably darker & browner than the warm
	   Crimson baseline. The radial centre is the least-burnt patch; the edges
	   char toward near-soot. */
	--vellum:            #c2a672;   /* scorched parchment body                     */
	--vellum-hi:         #d4ba85;   /* least-burnt centre (tea-stained)            */
	--vellum-lo:         #8a6f44;   /* charred toward the edge                      */
	--grime:             rgba(30,18,8,.5);     /* heavy soot vignette (darker)     */
	--foxing:            #6b4a28;   /* HEAVY foxing / burn-bloom (used 10–22%)     */
	--ruling:            #6b5736;   /* faint scorched ruling line                   */
	--curl-shadow:       rgba(18,10,4,.5);     /* deep cast shadow on any curl     */

	/* ── INK ─────────────────────────────────────────────────────────────────
	   Iron-gall: the blackest body ink of the fleet, but never pure #000.
	   Muted titles/labels go a smoked brown so the hierarchy still reads. */
	--ink:               #1c1810;   /* near-black iron-gall body ink                */
	--ink-muted:         #4a3a26;   /* smoked brown — labels / signature titles     */
	--rubric:            #5c0e1a;   /* dried-blood sanguine (darker than vermilion)  */

	/* ── GILDING — TARNISHED / FIRE-DULLED ───────────────────────────────────
	   Minimal, dull leaf. Still uses the shared raised-gilt recipe (gradient +
	   highlight + keyline) but every stop is pulled down/greyed so it reads as
	   soot-dulled rather than fresh florin. */
	--gold:              #a98445;   /* dull tarnished mid                           */
	--gold-hi:           #d8b878;   /* muted specular (no bright hotspot)           */
	--gold-deep:         #7a5e30;   /* deep tarnish shade                          */
	--gold-shadow:       #4a3208;   /* sooty darkest stop                          */
	--gold-keyline:      #2a1c04;   /* charcoal recess line                        */

	/* ── BORDER / FRAME ──────────────────────────────────────────────────────
	   A single austere charcoal bar with only a thin tarnished-gold keyline —
	   no wide decorated foliate band. Grim. */
	--border:            #3d2418;   /* charred charcoal-brown bar                   */
	--rule-fine:         #2a1810;   /* near-black hairline outer rule               */
	--initial-ground:    #3d2418;   /* drop-cap box ground = the charred bar        */

	/* ── ACCENT (secondary) — sanguine, used sparingly ───────────────────────*/
	--accent:            #5c0e1a;   /* sanguine accent for the scant ornament       */
	--accent-soft:       rgba(92,14,26,.22);   /* washed sanguine fill             */

	/* ── WAX SEAL — near-black sanguine ──────────────────────────────────────
	   Almost-black blood-wax: very little catch-light, pooled black centre. */
	--wax:               #5c0e1a;   /* near-black sanguine wax body                 */
	--wax-hi:            #8a1f24;   /* dim upper-left catch-light                   */
	--wax-lo:            #2a0808;   /* black pooled centre / rim                    */
	--ribbon-a:          #3d2418;   /* charred ribbon tail (livery field)          */
	--ribbon-b:          #5c0e1a;   /* sanguine ribbon tail (livery accent)        */

	/* ── HERALDRY ────────────────────────────────────────────────────────────
	   War-shield: square-bottomed heater reads martial; rim goes dull-gold,
	   keyline near-black. */
	--escutcheon:        heater;             /* clipPath id hook                    */
	--arms-rim:          var(--gold);
	--arms-keyline:      #1c1208;

	/* ── TYPOGRAPHY ──────────────────────────────────────────────────────────
	   Title: Grenze Gotisch at its blackest (800) — heavy, condensed, martial
	   blackletter. Body: IM Fell English (inky, irregular hand-press
	   impression). Signatures: IM Fell English ITALIC. Only --ff-title is a
	   "palette" reset; the body/sign/versal aliases exist in tokens and are
	   re-pointed here so this family reads inky end-to-end. */
	--ff-title:          "Grenze Gotisch","UnifrakturCook","Times New Roman",serif;
	--ff-body:           "IM Fell English","EB Garamond",Georgia,serif;
	--ff-body-alt:       "IM Fell English","EB Garamond",Georgia,serif;
	--ff-smallcaps:      "IM Fell English SC","IM Fell English","Cardo",serif;
	--ff-sign:           "IM Fell English","EB Garamond",serif;   /* render italic */
	--ff-versal:         "Grenze Gotisch","IM Fell English",serif;

	/* Tighten title tracking — heavy condensed blackletter wants to MASS, not
	   spread. Still NEVER tracked wide. */
	--ls-title:          0em;

	/* ── DECORATION / MOTIF HOOK ─────────────────────────────────────────────
	   Read by the illumination engine. This family is "austere": minimal band
	   ornament, maximal scorch. */
	--motif:             "ember-scroll";
}


/* ============================================================================
   2. SUBSTRATE — extra scorch ON TOP of the shared vellum stack
   ----------------------------------------------------------------------------
   The shared substrate engine already paints base radial + foxing + soot
   mottle from the tokens above. Here we ADD only what is unique to "charred":
   a stronger, very-asymmetric burn-bloom wash biased to the corners (where a
   real sheet chars first), and a heavier soot fibre feel. We layer extra
   backgrounds on the family's vellum element WITHOUT re-declaring shared
   structure, so the shared engine keeps owning geometry.
   ============================================================================ */

/* Extra burn-bloom: large, deliberately asymmetric scorch clouds that hug the
   corners/edges. Multiply-blended so they DARKEN the parchment rather than
   paint over it — irregularity is throughline #1. */
.sc2-scroll[data-family="charred_edict"] .sc2-vellum::before {
	content: "";
	position: absolute;
	inset: 0;
	z-index: 0;
	pointer-events: none;
	mix-blend-mode: multiply;
	opacity: .9;
	background:
		radial-gradient(38% 30% at 6% 4%,   rgba(30,16,6,.55) 0%, rgba(30,16,6,0) 70%),
		radial-gradient(34% 28% at 96% 7%,  rgba(24,12,4,.48) 0%, rgba(24,12,4,0) 72%),
		radial-gradient(40% 34% at 4% 97%,  rgba(20,10,4,.52) 0%, rgba(20,10,4,0) 74%),
		radial-gradient(30% 26% at 92% 95%, rgba(28,14,5,.46) 0%, rgba(28,14,5,0) 70%),
		radial-gradient(26% 20% at 71% 14%, rgba(107,74,40,.30) 0%, rgba(107,74,40,0) 75%),
		radial-gradient(22% 18% at 18% 62%, rgba(107,74,40,.26) 0%, rgba(107,74,40,0) 78%),
		radial-gradient(18% 16% at 47% 41%, rgba(92,14,26,.10) 0%, rgba(92,14,26,0) 80%);
}

/* Faint, half-burnt ruling — grim & spare. (The shared engine still paints the
   line geometry from --ruling; we only knock its presence down for this
   family.) */
.sc2-scroll[data-family="charred_edict"] .sc2-ruling {
	opacity: .10;
}


/* ============================================================================
   3. EDGE — BURNT / CHARRED corners over the deckle
   ----------------------------------------------------------------------------
   The shared .sc2-edge owns the deckle mask + base vignette. We darken the
   vignette dramatically and add a charred-corner overlay so the sheet looks
   pulled from a fire. The inner box-shadow deepens the soot ring.
   ============================================================================ */
.sc2-scroll[data-family="charred_edict"] .sc2-edge {
	box-shadow:
		inset 0 0 90px 22px rgba(20,10,4,.5),     /* deep soot ring                */
		inset 0 0 30px  6px rgba(8,4,2,.35);      /* tight char close to the edge  */
}

/* Charred corners: four asymmetric near-black scorch blooms anchored to the
   corners, stronger than the substrate burn so the corners read as ACTUALLY
   burnt — not merely shadowed. */
.sc2-scroll[data-family="charred_edict"] .sc2-edge::after {
	content: "";
	position: absolute;
	inset: 0;
	pointer-events: none;
	mix-blend-mode: multiply;
	background:
		radial-gradient(circle at 0% 0%,     rgba(10,5,2,.62) 0%, rgba(10,5,2,0) 16%),
		radial-gradient(circle at 100% 0%,   rgba(10,5,2,.58) 0%, rgba(10,5,2,0) 15%),
		radial-gradient(circle at 0% 100%,   rgba(10,5,2,.60) 0%, rgba(10,5,2,0) 17%),
		radial-gradient(circle at 100% 100%, rgba(10,5,2,.56) 0%, rgba(10,5,2,0) 14%);
}


/* ============================================================================
   4. ILLUMINATION — AUSTERE single charcoal rule, no foliate band
   ----------------------------------------------------------------------------
   Charred Edict is the least-ornamented family by design. Instead of the wide
   decorated band it shows a stark double rule: a thick charred bar carrying a
   single thin tarnished-gold keyline. Grim, military, restrained. We bind to
   the shared illum hooks; if a sub-element doesn't exist on a given build the
   selector simply matches nothing (harmless).
   ============================================================================ */

/* Drive the border SVG strokes sooty wherever the engine reads currentColor. */
.sc2-scroll[data-family="charred_edict"] .sc2-border {
	color: var(--border);
}

/* Collapse the decorated band visually: keep the band element but render it as
   a flat charred bar (no pattern fill) framed by a thin tarnished keyline. */
.sc2-scroll[data-family="charred_edict"] .sc2-illum {
	--band-fill:    var(--border);
	--band-keyline: var(--gold);
}
.sc2-scroll[data-family="charred_edict"] .sc2-illum .sc2-band {
	background: var(--border);
	box-shadow:
		inset 0  0.75px 0 rgba(216,184,120,.35),   /* faint tarnished top keyline   */
		inset 0 -0.75px 0 rgba(0,0,0,.55),         /* hard charcoal bottom recess   */
		0 0 0 0.75px var(--gold-keyline);          /* near-black outer keyline      */
}

/* Suppress any pattern / filigree / rinceaux the shared illumination might
   paint — this family wants BARE bars. (No-ops if these elements are absent.) */
.sc2-scroll[data-family="charred_edict"] .sc2-illum .sc2-rinceaux,
.sc2-scroll[data-family="charred_edict"] .sc2-illum .sc2-filigree,
.sc2-scroll[data-family="charred_edict"] .sc2-illum .sc2-band-pattern {
	display: none;
}

/* Corner pieces: replace any dense knot/foliate cluster with a stark IRON
   BRACKET — a small tarnished-gold L-rule in each corner. Armoury, not garden. */
.sc2-scroll[data-family="charred_edict"] .sc2-illum .sc2-corner {
	background: none;
}
.sc2-scroll[data-family="charred_edict"] .sc2-illum .sc2-corner::before {
	content: "";
	position: absolute;
	width: 30px;
	height: 30px;
	border-color: var(--gold);
	border-style: solid;
	border-width: 0;
	opacity: .85;
	filter:
		drop-shadow(0 1px 0 var(--gold-hi))
		drop-shadow(0 1px 1px rgba(8,4,2,.6));
}
/* Orient each iron bracket to its corner. */
.sc2-scroll[data-family="charred_edict"] .sc2-illum .sc2-corner--tl::before { top: 6px;    left: 6px;    border-top-width: 2px;    border-left-width: 2px;    }
.sc2-scroll[data-family="charred_edict"] .sc2-illum .sc2-corner--tr::before { top: 6px;    right: 6px;   border-top-width: 2px;    border-right-width: 2px;   }
.sc2-scroll[data-family="charred_edict"] .sc2-illum .sc2-corner--bl::before { bottom: 6px; left: 6px;    border-bottom-width: 2px; border-left-width: 2px;    }
.sc2-scroll[data-family="charred_edict"] .sc2-illum .sc2-corner--br::before { bottom: 6px; right: 6px;   border-bottom-width: 2px; border-right-width: 2px;   }


/* ============================================================================
   5. TYPOGRAPHY — grim hierarchy
   ----------------------------------------------------------------------------
   Blackest title, inky justified body, sanguine rubric, italic signatures.
   The title gets a deliberately MINIMAL gilt — mostly dark iron-gall ink with
   only a thin tarnished sheen — so it reads "charcoal-on-vellum", not
   "treasure". Restraint IS the family.
   ============================================================================ */

/* Title: heavy Grenze Gotisch, near-black ink with only a whisper of tarnished
   gild via -webkit-text-stroke; massed, condensed, martial. */
.sc2-scroll[data-family="charred_edict"] .sc2-title {
	font-family: var(--ff-title);
	font-weight: 800;
	letter-spacing: var(--ls-title);
	color: var(--ink);
	/* No bright gilt fill — an inky face with a tarnished keyline edge and a
	   hard cast shadow, like soot-blackened relief lettering. */
	background: none;
	-webkit-text-fill-color: var(--ink);
	-webkit-text-stroke: .4px var(--gold-keyline);
	text-shadow:
		0 1px 0 var(--gold-deep),
		0 2px 2px rgba(8,4,2,.45);
}

/* A single sanguine accent rule under the title — a sword-cut underline, not a
   flourish. */
.sc2-scroll[data-family="charred_edict"] .sc2-title::after {
	content: "";
	display: block;
	width: 44%;
	height: 2px;
	margin: .35em auto 0;
	background: linear-gradient(90deg,
		rgba(92,14,26,0)  0%,
		var(--accent)     22%,
		var(--gold-deep)  50%,
		var(--accent)     78%,
		rgba(92,14,26,0)  100%);
	box-shadow: 0 1px 0 rgba(8,4,2,.5);
}

/* Invocation — smoked, restrained, italic. */
.sc2-scroll[data-family="charred_edict"] .sc2-invocation {
	font-family: var(--ff-body);
	color: var(--ink-muted);
	letter-spacing: var(--ls-invocation);
	font-style: italic;
}

/* Intitulation — smoked small-caps. */
.sc2-scroll[data-family="charred_edict"] .sc2-intitulation {
	font-family: var(--ff-smallcaps);
	color: var(--ink-muted);
}

/* Body: inky IM Fell English, justified, with real ligatures + old-style
   figures. The irregular IM Fell impression already reads "hand-pressed". */
.sc2-scroll[data-family="charred_edict"] .sc2-body,
.sc2-scroll[data-family="charred_edict"] .sc2-body p {
	font-family: var(--ff-body);
	color: var(--ink);
	text-align: justify;
	font-feature-settings: "liga" 1, "dlig" 1, "onum" 1, "kern" 1;
}

/* Recipient rubric — dried-blood sanguine, slightly heavier; the one warm note
   on an otherwise charcoal sheet. */
.sc2-scroll[data-family="charred_edict"] .sc2-rubric,
.sc2-scroll[data-family="charred_edict"] .sc2-recipient {
	color: var(--rubric);
	font-weight: 600;
	letter-spacing: .01em;
}

/* Grant / dispositive clause — slightly larger via the shared scale, still
   inky, martial. */
.sc2-scroll[data-family="charred_edict"] .sc2-grant {
	font-family: var(--ff-body);
	color: var(--ink);
}

/* Versal drop-cap: a charred initial box (the bar colour) with a tarnished-gold
   keyline and a near-black Grenze Gotisch letter — a branded iron stamp.
   Both the explicit .sc2-versal element and the ::first-letter float fallback
   are themed so whichever the engine uses, it reads charred. */
.sc2-scroll[data-family="charred_edict"] .sc2-versal,
.sc2-scroll[data-family="charred_edict"] .sc2-body > p:first-of-type::first-letter {
	font-family: var(--ff-versal);
	font-weight: 800;
	color: var(--gold-hi);
	-webkit-text-fill-color: var(--gold-hi);
	-webkit-text-stroke: .5px var(--gold-keyline);
	background:
		linear-gradient(150deg,
			var(--initial-ground) 0%,
			#2a1810               55%,
			#160c06               100%);
	box-shadow:
		inset 0  1px 0 rgba(216,184,120,.25),
		inset 0 -2px 4px rgba(0,0,0,.55),
		0 0 0 1px var(--gold-keyline),
		0 2px 4px rgba(8,4,2,.5);
}

/* Signatures: IM Fell English ITALIC, inky; titles beneath in smoked muted. */
.sc2-scroll[data-family="charred_edict"] .sc2-attest,
.sc2-scroll[data-family="charred_edict"] .sc2-sign {
	font-family: var(--ff-sign);
	font-style: italic;
	color: var(--ink);
}
.sc2-scroll[data-family="charred_edict"] .sc2-attest .sc2-sign-title,
.sc2-scroll[data-family="charred_edict"] .sc2-sign-title {
	font-style: normal;
	color: var(--ink-muted);
	letter-spacing: .04em;
}

/* Date & place — period form, smoked brown, quiet but set apart. */
.sc2-scroll[data-family="charred_edict"] .sc2-datum {
	font-family: var(--ff-body);
	color: var(--ink-muted);
	font-style: italic;
}


/* ============================================================================
   6. HERALDRY & SEAL
   ----------------------------------------------------------------------------
   War-shields with a dull-gold rim + near-black keyline; a near-black sanguine
   pressed wax seal with very little catch-light and a black pooled centre.
   ============================================================================ */

/* Arms: dull tarnished rim, sooty keyline, hard cast shadow so they sit on the
   scorched sheet like riveted metal. */
.sc2-scroll[data-family="charred_edict"] .sc2-arms {
	filter: drop-shadow(0 2px 3px rgba(8,4,2,.55));
}
.sc2-scroll[data-family="charred_edict"] .sc2-arms img,
.sc2-scroll[data-family="charred_edict"] .sc2-arms svg {
	box-shadow:
		0 0 0 2px var(--arms-rim),
		0 0 0 3px var(--arms-keyline),
		inset 0 0 12px rgba(8,4,2,.4);
}

/* Wax seal — near-black sanguine. The SVG <fill> hooks: */
.sc2-scroll[data-family="charred_edict"] .sc2-seal {
	filter:
		drop-shadow(0 3px 5px rgba(8,4,2,.6))
		drop-shadow(0 1px 0 rgba(138,31,36,.3));
}
.sc2-scroll[data-family="charred_edict"] .sc2-seal .sc2-wax-body {
	fill: var(--wax);
}
/* If the seal disc is rendered via CSS rather than SVG <fill>, this paints it
   with the same near-black sanguine radial: dim upper catch-light, deep pooled
   black centre, hard black rim. */
.sc2-scroll[data-family="charred_edict"] .sc2-seal-disc {
	background:
		radial-gradient(circle at 38% 32%,
			var(--wax-hi) 0%,
			var(--wax)    34%,
			var(--wax-lo) 78%,
			#160404       100%);
	box-shadow:
		inset 0  2px 3px rgba(138,31,36,.35),       /* dim upper catch-light         */
		inset 0 -3px 6px rgba(0,0,0,.7),            /* deep pooled-centre shadow     */
		0 0 0 1px rgba(8,4,2,.7),                   /* hard black rim                */
		0 4px 6px rgba(8,4,2,.55);                  /* cast shadow on the sheet      */
}
/* Embossed sigil highlight/recess for the pressed brand. */
.sc2-scroll[data-family="charred_edict"] .sc2-seal-sigil {
	color: var(--wax-lo);
	filter:
		drop-shadow(0 1px 0 rgba(138,31,36,.4))
		drop-shadow(0 -1px 0 rgba(0,0,0,.6));
}

/* Ribbon tails — charred field + sanguine accent, scorched at the cut ends. */
.sc2-scroll[data-family="charred_edict"] .sc2-ribbon--a { background: var(--ribbon-a); }
.sc2-scroll[data-family="charred_edict"] .sc2-ribbon--b { background: var(--ribbon-b); }
.sc2-scroll[data-family="charred_edict"] .sc2-ribbon {
	box-shadow: inset 0 0 6px rgba(8,4,2,.5);
}


/* ============================================================================
   7. EXPORT / PRINT FLATTENING  (texture/gilt only — never structural)
   ----------------------------------------------------------------------------
   html2canvas drops mix-blend-mode and several filters; PDF engines wobble on
   feDisplacement. Under .sc2-export / @media print we flatten the soot blends
   to plain dark washes so the scorched look survives the raster — WITHOUT
   touching structure (per the contract).
   ============================================================================ */
.sc2-scroll[data-family="charred_edict"].sc2-export .sc2-vellum::before,
.sc2-scroll[data-family="charred_edict"].sc2-export .sc2-edge::after {
	mix-blend-mode: normal;
	opacity: .55;
}
.sc2-scroll[data-family="charred_edict"].sc2-export .sc2-title {
	text-shadow: 0 1px 1px rgba(8,4,2,.5);
}

@media print {
	.sc2-scroll[data-family="charred_edict"] .sc2-vellum::before,
	.sc2-scroll[data-family="charred_edict"] .sc2-edge::after {
		mix-blend-mode: normal;
		opacity: .5;
	}
	/* Ensure the scorched substrate + soot vignette + charred bar actually ink
	   on paper. */
	.sc2-scroll[data-family="charred_edict"] .sc2-vellum,
	.sc2-scroll[data-family="charred_edict"] .sc2-edge,
	.sc2-scroll[data-family="charred_edict"] .sc2-illum .sc2-band {
		-webkit-print-color-adjust: exact;
		print-color-adjust: exact;
	}
}

/* ===== family: imperial_edict ===== */
/* ============================================================================
   THE LETTERED SCROLL — families/family-imperial_edict.css.part
   ----------------------------------------------------------------------------
   FAMILY:  Imperial Edict   (key: imperial_edict)
   ROLE:    The grandest royal family. Cathedral Gothic tracery, a coronet-
            crowned CENTERED kingdom achievement above the title, the brightest
            gilding in the fleet, heavy Carolingian acanthus bars, and a
            lapis-and-gold (azure + or) livery throughout. For the highest
            imperial honors — a charter that should read like an emperor's
            proclamation pressed under wax.

   CONTRACT (per sf-tokens.css.part scoping rules):
     • This file RE-SETS ONLY the tokens a family is permitted to override:
       substrate trio (+ grime/foxing/ruling tints), --ink-muted / --rubric,
       the full --gold* ramp, --accent(+soft), --border, --rule-fine,
       --initial-ground, --wax* / --ribbon-* / --escutcheon, --arms-*, and
       --ff-title. It DOES NOT touch z-index, layout/geometry, spacing, the
       shadow helpers, or motion tokens — those stay shared.
     • All rules are scoped under .sc2-scroll[data-family="imperial_edict"]
       so nothing leaks to other families or to the dark-mode app chrome.
     • Family-specific ORNAMENT selectors (tracery crown, coronet, acanthus
       corners, lapis fillets) are added on top of the shared structure; they
       never re-flow the document, only decorate the existing illumination /
       crown / seal layers.
     • Raw CSS only — no <style> wrapper. PHP/.tpl includes this verbatim.

   LIVERY (locked palette for this family):
       azure (lapis)  #2a4b8d   ·  field / border / initial-ground / ribbon-a
       or (gold)      #d4af37   ·  gilding mid · ribbon-b
       gules (rubric) #e34234   ·  vermilion rubrics + accent
       vellum         #f8f4e3   ·  brightest, palest parchment of the fleet
       wax            #8c1d1b   ·  imperial sealing-wax red
   ============================================================================ */

/* ── TOKEN OVERRIDES ─────────────────────────────────────────────────────────
   Imperial Edict uses the palest, most "official chancery" vellum of all the
   families — closer to fine bleached calf than the warm Crimson baseline — so
   the lapis + bright gold reads as cold, regal, expensive.                    */
.sc2-scroll[data-family="imperial_edict"] {

  /* SUBSTRATE — pale imperial calf. Lightest center, faint cool-amber edge.   */
  --vellum:            #f3eccf;
  --vellum-hi:         #fdf9ee;
  --vellum-lo:         #e4d3a3;
  --grime:             rgba(58,46,18,.30);     /* slightly lighter grime: kept pristine */
  --foxing:            #c2a268;                 /* warm honey foxing, used low alpha      */
  --ruling:            #8f8468;                 /* faint chancery ruling                  */
  --curl-shadow:       rgba(48,38,14,.34);

  /* INK — near-black brown body, the most formal/legible of the families.     */
  --ink:               #1c1810;
  --ink-muted:         #463a26;                 /* signature titles / intitulation        */
  --rubric:            #e34234;                 /* vermilion gules — recipient + openers   */

  /* GILDING — brightest, most lustrous ramp in the fleet (this is THE gold).
     Wider hi span + brighter hotspot so the cathedral tracery truly glints.   */
  --gold:              #d4af37;
  --gold-hi:           #fff4c2;
  --gold-deep:         #b8860b;
  --gold-shadow:       #7a560a;
  --gold-keyline:      #5a3d0c;

  /* ACCENT — secondary scheme is the vermilion gules, NOT the gold, so the
     two-colour azure/gules drollery work in the bas-de-page reads heraldic.   */
  --accent:            #e34234;
  --accent-soft:       rgba(227,66,52,.22);

  /* BORDER / FRAME — azure (lapis) field colour drives the bar + initial box. */
  --border:            #2a4b8d;
  --rule-fine:         #1d3563;                 /* deep lapis hairline outer rule          */
  --initial-ground:    #2a4b8d;                 /* lapis ground behind the gilt versal     */

  /* WAX SEAL — imperial sealing-wax red with a hot upper-left catch-light.     */
  --wax:               #8c1d1b;
  --wax-hi:            #c34233;
  --wax-lo:            #560f0e;

  /* LIVERY RIBBON — azure + or (the family's two metals/colours).            */
  --ribbon-a:          #2a4b8d;
  --ribbon-b:          #d4af37;

  /* HERALDRY — heater shield with a heavy gilt rim and a cold lapis keyline,
     to sit under the coronet.                                                 */
  --escutcheon:        heater;
  --arms-rim:          var(--gold);
  --arms-keyline:      #16203a;

  /* TYPOGRAPHY — title face is UnifrakturCook (heavy blackletter), the most
     architectural/condensed display in the fleet; tightened a hair so the
     long imperial titles fit two crowded gilt lines.                          */
  --ff-title:          "UnifrakturCook","UnifrakturMaguntia","Pirata One","Times New Roman",serif;
  --ls-title:          0em;                     /* never track blackletter wide            */

  /* MOTIF HOOK — informational; downstream SVG ornament keys off this name.    */
  --motif:             gothic-tracery;
}

/* ════════════════════════════════════════════════════════════════════════════
   FAMILY ORNAMENT — everything below DECORATES the shared layers; no re-flow.
   ════════════════════════════════════════════════════════════════════════════ */

/* ── DOUBLE LAPIS+GILT FILLET ────────────────────────────────────────────────
   Imperial gravitas wants a heavier frame than the shared single bar. We add a
   second, inner gilt fillet inboard of the lapis bar via the illumination
   layer's ::before, so the border reads outer-rule → lapis bar → gilt fillet →
   decorated band. Lives entirely on the decorative illum layer (z-illum).     */
.sc2-scroll[data-family="imperial_edict"] .sc2-illum::before {
  content: "";
  position: absolute;
  inset: calc(var(--margin-frame) * 0.62);
  pointer-events: none;
  border-radius: 2px;
  /* a thin raised gilt keyline sitting just inside the lapis bar */
  box-shadow:
    0 0 0 1.5px var(--gold-deep),
    0 0 0 3px   var(--gold),
    0 0 0 4px   var(--gold-hi),
    0 0 0 5px   var(--gold-keyline);
  /* a barely-there lapis wash so the gilt fillet glows against blue */
  background:
    linear-gradient(180deg,
      rgba(42,75,141,.10) 0%,
      rgba(42,75,141,0)   8%,
      rgba(42,75,141,0)   92%,
      rgba(42,75,141,.10) 100%);
}

/* The shared bar-border itself: render it as raised LAPIS, not flat — a cold
   stone bar with a top catch-light and a recessed bottom, framed in a gilt
   keyline so it reads as a champlevé enamel band.                            */
.sc2-scroll[data-family="imperial_edict"] .sc2-border .sc2-bar,
.sc2-scroll[data-family="imperial_edict"] .sc2-bar {
  fill: none;
  stroke: url(#sc2-lapis-imp);
}
.sc2-scroll[data-family="imperial_edict"] .sc2-bar--frame {
  filter:
    drop-shadow(0 1px 0 rgba(170,195,240,.55))      /* upper catch-light */
    drop-shadow(0 -1px 1px rgba(10,20,45,.55));      /* recessed lower    */
}

/* ── DECORATED BAND — Carolingian acanthus, gilt on lapis ────────────────────
   The shared band gets the family acanthus pattern fill + a gilt tone so the
   foliate scrollwork glints. (Pattern id is provided by the SVG layer; this
   only paints it and lifts it.)                                              */
.sc2-scroll[data-family="imperial_edict"] .sc2-band {
  fill: url(#sc2-acanthus-imp);
  filter: drop-shadow(0 1px 1px rgba(40,20,0,.45));
}

/* ── CORNER PIECES — heavy gilt acanthus bosses, the densest ornament ─────────
   Lift the four shared corner clusters with the locked gilt recipe + a lapis
   shadow so they pop off the band as raised metal.                           */
.sc2-scroll[data-family="imperial_edict"] .sc2-corner {
  fill: url(#sc2-gild);                /* shared SVG gilt gradient from tokens */
  stroke: var(--gold-keyline);
  stroke-width: 0.6;
  filter:
    drop-shadow(0 1px 0  var(--gold-hi))
    drop-shadow(0 2px 2px rgba(20,30,60,.5));
}

/* ── CROWN ZONE — coronet-crowned KINGDOM achievement, SHARED FLANK LAYOUT ────
   Imperial Edict honors the shared symmetric flank model: kingdom arms dexter,
   park arms sinister, EQUAL size on a shared top baseline (set in
   sf-heraldry-seal.css.part). This family adds ONLY the gilt coronet ornament
   on the kingdom figure — no column re-layout, no absolute park supporter, no
   per-shield size override (those broke cross-family heraldry symmetry).      */

/* Kingdom arms: shared size/baseline; we only lift it with a gilt glow and
   make it a positioning context for the coronet ::before. */
.sc2-scroll[data-family="imperial_edict"] .sc2-arms--kingdom {
  position: relative;
  z-index: 1;
  filter:
    drop-shadow(0 2px 3px rgba(15,22,45,.45))
    drop-shadow(0 0 1px var(--gold));
}
.sc2-scroll[data-family="imperial_edict"] .sc2-arms--kingdom img,
.sc2-scroll[data-family="imperial_edict"] .sc2-arms--kingdom .sc2-arms-img {
  border-radius: 3px;
  box-shadow:
    0 0 0 2px var(--gold-hi),
    0 0 0 3.5px var(--gold-deep),
    0 0 0 5px var(--arms-keyline);          /* gilt rim + lapis keyline */
}

/* Park arms: shared flank model — gilt rim to match, no size/position override. */
.sc2-scroll[data-family="imperial_edict"] .sc2-arms--park img,
.sc2-scroll[data-family="imperial_edict"] .sc2-arms--park .sc2-arms-img {
  box-shadow: 0 0 0 1.5px var(--gold), 0 0 0 2.5px var(--arms-keyline);
  border-radius: 2px;
}

/* The CORONET — a gilt imperial circlet sitting on the kingdom arms. Drawn with
   a SINGLE-layer white SVG data-URI mask (an openwork circlet of three fleur
   points + a banded base) over the gilt gradient bar — no mask-composite, so
   Chrome renders thin tracery rather than broken gold triangles. Injected via
   ::before on the kingdom figure so it needs no extra markup.                 */
.sc2-scroll[data-family="imperial_edict"] .sc2-arms--kingdom::before {
  content: "";
  position: absolute;
  left: 50%;
  top: -0.62em;
  transform: translateX(-50%);
  width: 116%;
  height: 0.78em;
  z-index: 2;
  pointer-events: none;
  /* circlet base: raised gilt bar */
  background:
    linear-gradient(135deg,
      var(--gold-shadow) 0%, var(--gold) 18%, var(--gold-hi) 38%,
      var(--gold) 58%, var(--gold-deep) 82%, var(--gold-shadow) 100%);
  filter: drop-shadow(0 2px 3px rgba(15,22,45,.45));
  /* single-layer white SVG silhouette of an imperial circlet: a banded base
     rail with three fleur-de-lis points rising from it (white = kept gold,
     transparent = vellum shows through as the negative tracery). */
  -webkit-mask: url("data:image/svg+xml,%3Csvg%20xmlns='http://www.w3.org/2000/svg'%20viewBox='0%200%20120%2044'%20preserveAspectRatio='none'%3E%3Cpath%20fill='%23fff'%20d='M4%2030h112v10H4z'/%3E%3Cpath%20fill='%23fff'%20d='M60%204c-3%206-9%208-9%2014%200%204%204%206%209%206s9-2%209-6c0-6-6-8-9-14zM18%2014c-2%205-7%206-7%2011%200%203%203%205%207%205s7-2%207-5c0-5-5-6-7-11zM102%2014c-2%205-7%206-7%2011%200%203%203%205%207%205s7-2%207-5c0-5-5-6-7-11z'/%3E%3C/svg%3E") no-repeat center / 100% 100%;
          mask: url("data:image/svg+xml,%3Csvg%20xmlns='http://www.w3.org/2000/svg'%20viewBox='0%200%20120%2044'%20preserveAspectRatio='none'%3E%3Cpath%20fill='%23fff'%20d='M4%2030h112v10H4z'/%3E%3Cpath%20fill='%23fff'%20d='M60%204c-3%206-9%208-9%2014%200%204%204%206%209%206s9-2%209-6c0-6-6-8-9-14zM18%2014c-2%205-7%206-7%2011%200%203%203%205%207%205s7-2%207-5c0-5-5-6-7-11zM102%2014c-2%205-7%206-7%2011%200%203%203%205%207%205s7-2%207-5c0-5-5-6-7-11z'/%3E%3C/svg%3E") no-repeat center / 100% 100%;
}

/* Jewel pips on the coronet circlet (gules + azure cabochons) — ::after. */
.sc2-scroll[data-family="imperial_edict"] .sc2-arms--kingdom::after {
  content: "";
  position: absolute;
  left: 50%;
  top: -0.30em;
  transform: translateX(-50%);
  width: 70%;
  height: 0.20em;
  z-index: 3;
  pointer-events: none;
  border-radius: 2px;
  background:
    radial-gradient(circle at 50% 50%, var(--accent) 0 38%, transparent 41%) 50% 50% / 22% 100% no-repeat,
    radial-gradient(circle at 50% 50%, var(--border) 0 38%, transparent 41%) 12% 50% / 18% 100% no-repeat,
    radial-gradient(circle at 50% 50%, var(--border) 0 38%, transparent 41%) 88% 50% / 18% 100% no-repeat;
  filter: drop-shadow(0 0 .5px rgba(0,0,0,.4));
}

/* MANTLING — only at ornate intensity: at ornate, widen the coronet circlet a
   touch so it reads richer. This is purely decorative and does NOT alter the
   kingdom figure's box, size, margin, or baseline — the shared symmetric flank
   layout (kingdom dexter / park sinister, equal size) is preserved.          */
.sc2-scroll[data-family="imperial_edict"][data-intensity="ornate"] .sc2-arms--kingdom::before {
  width: 124%;
}

/* ── TITLE — brightest gilt, cathedral presence ──────────────────────────────
   Use the locked gilt-text recipe but with a slightly heavier dark stroke so
   the dense UnifrakturCook letters stay crisp at imperial scale, and a faint
   lapis under-shadow so the gold reads as raised metal over blue ground.     */
.sc2-scroll[data-family="imperial_edict"] .sc2-title {
  background:
    linear-gradient(135deg,
      var(--gold-shadow) 0%, var(--gold) 32%, var(--gold-hi) 52%,
      var(--gold) 70%, var(--gold-deep) 100%);
  -webkit-background-clip: text;
          background-clip: text;
  color: transparent;
  -webkit-text-stroke: .85px var(--gold-keyline);
  filter:
    drop-shadow(0 1px 0 var(--gold-hi))
    drop-shadow(0 2px 2px rgba(20,30,60,.42));
  line-height: 0.92;
}

/* POINTED-ARCH TRACERY crowning the title — a Gothic gablet drawn in CSS,
   spanning the title block, gilt-on-lapis. Hung above the title via ::before
   on the content title (does not affect text flow; absolutely positioned).   */
.sc2-scroll[data-family="imperial_edict"] .sc2-title {
  position: relative;
}
.sc2-scroll[data-family="imperial_edict"] .sc2-title::before {
  content: "";
  position: absolute;
  left: 50%;
  top: -1.0em;
  transform: translateX(-50%);
  width: min(70%, 26ch);
  height: 1.1em;
  pointer-events: none;
  /* openwork pointed-arch gablet drawn as a SINGLE-layer white SVG silhouette
     mask over the gilt bar: an outer ogee arch, a pierced central quatrefoil
     oculus, and a small finial. The pierced negative space (transparent) shows
     vellum through, so it reads as thin gilt tracery — never a solid wedge.   */
  background:
    linear-gradient(180deg, var(--gold-hi), var(--gold) 40%, var(--gold-deep));
  -webkit-mask: url("data:image/svg+xml,%3Csvg%20xmlns='http://www.w3.org/2000/svg'%20viewBox='0%200%20240%2056'%20preserveAspectRatio='xMidYMax%20meet'%3E%3Cpath%20fill='%23fff'%20d='M120%200l5%2010-5%204-5-4z'/%3E%3Cpath%20fill='%23fff'%20fill-rule='evenodd'%20d='M120%2012c-30%200-58%2014-78%2030-10%208-22%2012-34%2012h224c-12%200-24-4-34-12-20-16-48-30-78-30zm0%208c-26%200-50%2012-67%2026H53c14-9%2034-18%2067-18s53%209%2067%2018h0c-17-14-41-26-67-26zm0%2010a9%209%200%201%200%200%2018%209%209%200%200%200%200-18zm0%204a5%205%200%201%201%200%2010%205%205%200%200%201%200-10z'/%3E%3Cpath%20fill='%23fff'%20d='M6%2052h228v4H6z'/%3E%3C/svg%3E") no-repeat center / contain;
          mask: url("data:image/svg+xml,%3Csvg%20xmlns='http://www.w3.org/2000/svg'%20viewBox='0%200%20240%2056'%20preserveAspectRatio='xMidYMax%20meet'%3E%3Cpath%20fill='%23fff'%20d='M120%200l5%2010-5%204-5-4z'/%3E%3Cpath%20fill='%23fff'%20fill-rule='evenodd'%20d='M120%2012c-30%200-58%2014-78%2030-10%208-22%2012-34%2012h224c-12%200-24-4-34-12-20-16-48-30-78-30zm0%208c-26%200-50%2012-67%2026H53c14-9%2034-18%2067-18s53%209%2067%2018h0c-17-14-41-26-67-26zm0%2010a9%209%200%201%200%200%2018%209%209%200%200%200%200-18zm0%204a5%205%200%201%201%200%2010%205%205%200%200%201%200-10z'/%3E%3Cpath%20fill='%23fff'%20d='M6%2052h228v4H6z'/%3E%3C/svg%3E") no-repeat center / contain;
  filter: drop-shadow(0 1px 1px rgba(20,30,60,.5));
}
/* A thin lapis springing-line under the tracery, tying it to the title. */
.sc2-scroll[data-family="imperial_edict"] .sc2-title::after {
  content: "";
  position: absolute;
  left: 50%;
  top: -0.18em;
  transform: translateX(-50%);
  width: min(90%, 32ch);
  height: 2px;
  pointer-events: none;
  background: linear-gradient(90deg,
    transparent, var(--border) 12%, var(--gold) 50%, var(--border) 88%, transparent);
  border-radius: 1px;
}

/* ── INVOCATION — small-cap arenga opener in lapis, gilt-bracketed ───────────
   "Forasmuch as…" / "Know all by these presents…" set in cool lapis caps to
   distinguish the imperial preamble from the warmer families.                */
.sc2-scroll[data-family="imperial_edict"] .sc2-invocation {
  color: var(--border);
  font-variant: small-caps;
  letter-spacing: var(--ls-invocation);
}
.sc2-scroll[data-family="imperial_edict"] .sc2-invocation::before,
.sc2-scroll[data-family="imperial_edict"] .sc2-invocation::after {
  content: "❦";                         /* aldus leaf — period printer's flower */
  color: var(--gold-deep);
  margin: 0 .55em;
  font-size: .9em;
  -webkit-text-stroke: .3px var(--gold-keyline);
}

/* ── INTITULATION — gilt small-caps "By the grace of…" line ─────────────────*/
.sc2-scroll[data-family="imperial_edict"] .sc2-intitulation {
  color: var(--ink-muted);
  font-variant: small-caps;
  letter-spacing: var(--ls-intitulation);
}

/* ── VERSAL DROP-CAP — gilt letter on a lapis-and-gold decorated box ─────────
   The decorated-initial ground is lapis (token), the letter is bright gilt,
   and we add a gilt acanthus corner spray and a champlevé inner keyline so it
   reads as a true illuminated versal, the costliest in the fleet.            */
.sc2-scroll[data-family="imperial_edict"] .sc2-versal,
.sc2-scroll[data-family="imperial_edict"] .sc2-body > p:first-of-type::first-letter {
  color: transparent;
  background:
    linear-gradient(135deg,
      var(--gold-shadow) 0%, var(--gold) 22%, var(--gold-hi) 46%,
      var(--gold) 66%, var(--gold-deep) 100%);
  -webkit-background-clip: text;
          background-clip: text;
  -webkit-text-stroke: .6px var(--gold-keyline);
  font-family: var(--ff-versal);
}
.sc2-scroll[data-family="imperial_edict"] .sc2-versal {
  position: relative;
  /* the decorated initial BOX: raised lapis ground, gilt rim, inset highlight */
  background-color: var(--initial-ground);
  border-radius: 3px;
  padding: .06em .12em;
  box-shadow:
    inset 0 1px 0 rgba(170,195,240,.45),
    inset 0 -2px 3px rgba(10,20,45,.6),
    0 0 0 1px  var(--gold-deep),
    0 0 0 2.5px var(--gold),
    0 0 0 3.5px var(--gold-hi),
    0 0 0 4.5px var(--gold-keyline),
    0 3px 5px rgba(15,22,45,.4);
}
/* Gilt acanthus tendril escaping top-left of the versal box into the margin —
   a single-layer white SVG acanthus leaf masked over the gilt gradient, so it
   reads as a crisp scrolled leaf rather than a radial-dot smudge. */
.sc2-scroll[data-family="imperial_edict"] .sc2-versal::after {
  content: "";
  position: absolute;
  left: -0.46em;
  top: -0.46em;
  width: 1.0em;
  height: 1.0em;
  pointer-events: none;
  background:
    linear-gradient(135deg,
      var(--gold-shadow) 0%, var(--gold) 30%, var(--gold-hi) 52%,
      var(--gold) 72%, var(--gold-deep) 100%);
  -webkit-mask: url("data:image/svg+xml,%3Csvg%20xmlns='http://www.w3.org/2000/svg'%20viewBox='0%200%2032%2032'%3E%3Cpath%20fill='%23fff'%20d='M30%2030C18%2030%208%2024%204%2012%202%207%202%203%202%202c1%200%205%200%2010%202%2012%204%2018%2014%2018%2026%200-6-3-12-9-16%205%201%2010%205%2013%2011%201-4%200-9-3-13%204%202%207%206%208%2011-1-7-5-13-11-16%208%201%2014%208%2014%2017%200%204%200%208%200%208z'/%3E%3C/svg%3E") no-repeat center / contain;
          mask: url("data:image/svg+xml,%3Csvg%20xmlns='http://www.w3.org/2000/svg'%20viewBox='0%200%2032%2032'%3E%3Cpath%20fill='%23fff'%20d='M30%2030C18%2030%208%2024%204%2012%202%207%202%203%202%202c1%200%205%200%2010%202%2012%204%2018%2014%2018%2026%200-6-3-12-9-16%205%201%2010%205%2013%2011%201-4%200-9-3-13%204%202%207%206%208%2011-1-7-5-13-11-16%208%201%2014%208%2014%2017%200%204%200%208%200%208z'/%3E%3C/svg%3E") no-repeat center / contain;
  filter: drop-shadow(0 1px 1px rgba(15,22,45,.5));
}

/* ── BODY — formal, dense, fully justified imperial chancery ─────────────────
   EB Garamond, justified, old-style figures + ligatures, a hair tighter than
   the baseline to fit the long arenga charters.                              */
.sc2-scroll[data-family="imperial_edict"] .sc2-body {
  font-family: var(--ff-body);
  text-align: justify;
  text-justify: inter-word;
  hyphens: auto;
  font-feature-settings: "liga" 1, "clig" 1, "onum" 1, "kern" 1;
  line-height: 1.58;
  color: var(--ink);
}
/* Recipient name + grant rubrics in vermilion gules, the imperial red. */
.sc2-scroll[data-family="imperial_edict"] .sc2-body .sc2-rubric,
.sc2-scroll[data-family="imperial_edict"] .sc2-grant .sc2-rubric,
.sc2-scroll[data-family="imperial_edict"] .sc2-recipient {
  color: var(--rubric);
  font-weight: 600;
}

/* ── GRANT / DISPOSITIVE CLAUSE — set off as the operative imperial sentence
   "…do by this Our charter… with all the honors, rights, and privileges
   thereunto belonging." Centered, slightly larger, lapis small-caps lead.    */
.sc2-scroll[data-family="imperial_edict"] .sc2-grant {
  font-family: var(--ff-body);
  text-align: center;
  font-size: var(--fs-grant);
  line-height: 1.5;
  color: var(--ink);
}
.sc2-scroll[data-family="imperial_edict"] .sc2-grant::first-line {
  font-variant: small-caps;
  letter-spacing: .04em;
  color: var(--border);
}

/* ── DATUM — "Given under Our hand and seal" line, written-out date ──────────*/
.sc2-scroll[data-family="imperial_edict"] .sc2-datum {
  font-family: var(--ff-body);
  font-style: italic;
  text-align: center;
  color: var(--ink-muted);
}

/* ── ATTESTATION — imperial signatures in chancery italic, lapis title rule ─ */
.sc2-scroll[data-family="imperial_edict"] .sc2-attest {
  font-family: var(--ff-sign);
}
.sc2-scroll[data-family="imperial_edict"] .sc2-attest .sc2-sign-name {
  font-style: italic;
  font-size: var(--fs-attest);
  color: var(--ink);
}
.sc2-scroll[data-family="imperial_edict"] .sc2-attest .sc2-sign-line {
  border-top: 1px solid var(--border);          /* lapis ruled signature line */
}
.sc2-scroll[data-family="imperial_edict"] .sc2-attest .sc2-sign-title {
  font-variant: small-caps;
  letter-spacing: .1em;
  color: var(--ink-muted);
}

/* ── WAX SEAL — pendant imperial seal, gilt rim, azure-and-or ribbon ─────────
   The shared seal SVG gets the family wax tokens automatically; here we lift
   the rim to bright gilt and tune the ribbon to the lapis+gold livery.       */
.sc2-scroll[data-family="imperial_edict"] .sc2-seal .sc2-wax-rim {
  fill: url(#sc2-gild);
  stroke: var(--gold-keyline);
  stroke-width: 0.5;
}
.sc2-scroll[data-family="imperial_edict"] .sc2-seal .sc2-wax-body {
  fill: url(#sc2-wax-imp);
}
.sc2-scroll[data-family="imperial_edict"] .sc2-seal .sc2-wax-sigil {
  /* embossed sigil: gilt highlight + dark recess, never flat */
  fill: var(--wax-hi);
  filter:
    drop-shadow(0 1px 0 rgba(0,0,0,.45))
    drop-shadow(0 -0.5px 0 rgba(255,210,180,.35));
  opacity: .9;
}
/* Livery ribbon tails: paired azure + or, the seal's pendant cords. */
.sc2-scroll[data-family="imperial_edict"] .sc2-seal-wrap .sc2-ribbon-a,
.sc2-scroll[data-family="imperial_edict"] .sc2-seal .sc2-ribbon-a {
  fill: var(--ribbon-a);
}
.sc2-scroll[data-family="imperial_edict"] .sc2-seal-wrap .sc2-ribbon-b,
.sc2-scroll[data-family="imperial_edict"] .sc2-seal .sc2-ribbon-b {
  fill: var(--ribbon-b);
}

/* ── SVG PAINT SOURCES this family expects in the scroll's <svg class="sc2-defs">
   The SVG/defs engineer must provide these ids (one per scroll). Documented
   here so the gradient stops stay locked to the family palette:

     <linearGradient id="sc2-lapis-imp">      enamel-blue bar
        0%   #16203a   ·  35% #2a4b8d  ·  55% #3a63b0  ·  100% #1d3563
     <pattern      id="sc2-acanthus-imp">     Carolingian acanthus scroll, gilt
     <radialGradient id="sc2-wax-imp">        imperial sealing wax
        0%   var(--wax-hi)  ·  55% var(--wax)  ·  100% var(--wax-lo)
   (sc2-gild is the SHARED gilt gradient defined in sf-tokens / defs.)
   These selectors degrade gracefully: if a paint id is absent the elements
   fall back to the flat token fills already set on the shared layers.        */

/* ── BAS-DE-PAGE DROLLERY — a small azure-and-gilt cartouche flanking the seal
   at ornate intensity, the imperial monogram frame. Pure-CSS lozenge.        */
.sc2-scroll[data-family="imperial_edict"][data-intensity="ornate"] .sc2-seal-wrap::before {
  content: "";
  position: absolute;
  left: 8%;
  bottom: 0.2em;
  width: clamp(34px, 7%, 60px);
  height: clamp(34px, 7%, 60px);
  pointer-events: none;
  transform: rotate(45deg);
  border-radius: 4px;
  background:
    linear-gradient(135deg, var(--border), #16203a);
  box-shadow:
    inset 0 0 0 2px var(--gold),
    inset 0 0 0 3px var(--gold-deep),
    0 0 0 1px var(--gold-keyline),
    0 2px 4px rgba(15,22,45,.4);
}
.sc2-scroll[data-family="imperial_edict"][data-intensity="ornate"] .sc2-seal-wrap::after {
  /* mirror lozenge on the right for symmetry */
  content: "";
  position: absolute;
  right: 8%;
  bottom: 0.2em;
  width: clamp(34px, 7%, 60px);
  height: clamp(34px, 7%, 60px);
  pointer-events: none;
  transform: rotate(45deg);
  border-radius: 4px;
  background:
    linear-gradient(135deg, var(--border), #16203a);
  box-shadow:
    inset 0 0 0 2px var(--gold),
    inset 0 0 0 3px var(--gold-deep),
    0 0 0 1px var(--gold-keyline),
    0 2px 4px rgba(15,22,45,.4);
}

/* ── EXPORT / PRINT FLATTENING ───────────────────────────────────────────────
   The coronet/tracery/acanthus are now built from SINGLE-layer white SVG
   data-URI masks (no mask-composite, no conic-gradient), which html2canvas and
   PDF print engines render correctly — so we no longer neutralize the masks
   (doing so would resurface the solid gilt-block bug). We keep ONLY the title
   filter simplification so the bright gilt stays readable on paper.          */
@media print {
  .sc2-scroll[data-family="imperial_edict"] .sc2-title {
    filter: drop-shadow(0 1px 0 var(--gold-hi));
  }
}

/* ===== family: scholars_hand ===== */
/* ============================================================================
   THE LETTERED SCROLL  ·  FAMILY PARTIAL  ·  SCHOLAR'S HAND
   key: scholars_hand
   ----------------------------------------------------------------------------
   "Whereas it is the ancient custom of this realm to honor with a fitting title
    those distinguished in craft and learning..."  (the arts-&-sciences register)

   A Renaissance HUMANIST DIPLOMA. Where the decree families bark in vermilion
   and burnished gold, and the gothic families cut cold tracery, Scholar's Hand
   speaks in the clean, lettered voice of the quattrocento scriptorium: a
   Florentine grant of a craft-title, restrained and elegant.

   The defining ornament is the bianchi girari — Italian WHITE-VINE: uncoloured
   (white) vine stems coiling in calm spirals against a quartered jewel ground of
   azure / vert / gules, peppered with little white trefoil dots. Gold is used
   SPARINGLY here (humanist, not royal). The rubric is BLUE (--rubric #2a4b8d) —
   the distinctive signature of this family, set apart from every vermilion
   sibling. The title is a cleaner Pirata One; the body is Cardo small-caps with
   old-style figures. The wax is a NATURAL / humble ochre, pressed into a VESICA
   (pointed-oval) seal. More whitespace, less ornament density than Crimson or
   Gothic — the look is breathing-room and learned restraint.

   SCOPING CONTRACT (inherited from sf-tokens.css.part):
     • This file overrides ONLY palette / font / motif / escutcheon tokens and
       adds family-specific ORNAMENT selectors, all under
       .sc2-scroll[data-family="scholars_hand"].
     • It MUST NOT touch the z-index stack, layout geometry, spacing rhythm,
       shadow helper composites, or motion tokens — those stay shared.
     • The vellum is ALWAYS the light humanist parchment here; the app's
       dark-mode theme can never reach it (scoped to .sc2-scroll, never
       html[data-theme]).
     • Component selectors reuse the locked composite tokens (--gild-gradient,
       --shadow-emboss, --gild-shadow, etc.) verbatim rather than re-deriving.

   MEDIUM IS LOCKED: HTML + CSS + inline SVG. No <canvas>, no tiled photos, no
   flat #ffd700, no #fff for surfaces. The white-vine motif is built as layered
   inline-SVG data-URIs so it survives html2canvas / print without filters.
   ============================================================================ */

/* ============================================================================
   1 · PALETTE  ·  the humanist scriptorium ramp + the white-vine grounds
   ----------------------------------------------------------------------------
   The brief's palette is authoritative. We re-set the ramp here so the family
   file is the single source of truth for these hues. Note the BLUE rubric and
   the three jewel WHITE-VINE GROUNDS (family-local tokens, used only by this
   file's ornament selectors). Only palette / font / motif / escutcheon tokens.
   ============================================================================ */
.sc2-scroll[data-family="scholars_hand"] {

  /* ── SUBSTRATE: clean, lightly-pressed humanist vellum (a fresh diploma) ── */
  --vellum:            #f8f4e3;   /* base parchment body                       */
  --vellum-hi:         #fdf9ee;   /* lightest centre — fresh-pressed sheet     */
  --vellum-lo:         #e7dcbc;   /* aged edge — restrained, never deep-tanned */
  --grime:             rgba(58,52,30,.24);   /* a quiet, scholarly edge wash   */
  --foxing:            #c2ad7e;   /* faint foxing (used 8–18% alpha)           */
  --ruling:            #9a8f78;   /* faint scriptorium ruling + pricking       */
  --curl-shadow:       rgba(58,48,24,.30);

  /* ── INK: warm scriptorium sepia, never black ──────────────────────────── */
  --ink:               #2a211a;   /* body ink                                  */
  --ink-muted:         #5a4a36;   /* intitulation / signature titles / labels  */
  --rubric:            #2a4b8d;   /* BLUE humanist rubric (NOT vermilion)      */

  /* ── GILDING: RESTRAINED gold — used sparingly, humanist not royal ──────── */
  --gold:              #d4af37;   /* mid body gold                             */
  --gold-hi:           #fff1a8;   /* specular hotspot                          */
  --gold-deep:         #a9760a;   /* lower gold shade                          */
  --gold-shadow:       #6e4d08;   /* darkest gold stop                         */
  --gold-keyline:      #5a3d0c;   /* thin dark recess line — sells "raised"    */

  /* ── BORDER / FRAME: vert (green) field, the white-vine grows upon it ───── */
  --border:            #0b6623;   /* humanist vert bar-border                  */
  --rule-fine:         #6b4f2a;   /* warm-brown hairline outer rule            */
  --initial-ground:    #27408b;   /* white-vine initial-box ground (azure)     */

  /* ── ACCENT: the azure register, echoing the blue rubric ────────────────── */
  --accent:            #2a4b8d;   /* secondary ornament accent (azure-blue)    */
  --accent-soft:       rgba(42,75,141,.22);   /* washed azure (cartouche fill) */

  /* ── WHITE-VINE GROUNDS (family-local) — the quartered bianchi-girari field
     azure / vert / gules, with WHITE vine stems + white trefoil dots.       */
  --wv-azure:          #27408b;   /* jewel ground — azure                      */
  --wv-vert:           #2e7d4f;   /* jewel ground — vert                       */
  --wv-gules:          #b22222;   /* jewel ground — gules                      */
  --wv-stem:           #f8f4e3;   /* uncoloured (white) vine stem & trefoils   */
  --wv-stem-shade:     #d9cfae;   /* faint shaded side of the white stem       */

  /* ── WAX SEAL: NATURAL / humble ochre (the unpretentious scholar's wax) ── */
  --wax:               #b98a3c;   /* natural wax body                          */
  --wax-hi:            #d4ad62;   /* upper-left catch-light                     */
  --wax-lo:            #7a5520;   /* pooled centre / rim                       */
  --ribbon-a:          #2a4b8d;   /* livery colour ribbon (azure)              */
  --ribbon-b:          #d4af37;   /* livery metal ribbon (restrained gold)     */

  /* ── HERALDRY: humanist → pointed-oval (vesica) achievement ─────────────── */
  --escutcheon:        vesica;
  --arms-rim:          var(--gold);
  --arms-keyline:      #2a2418;

  /* ── TYPOGRAPHY: a cleaner Pirata One title; Cardo body; Cardo italic sign ─
     Body is Cardo-led to carry small-caps + old-style figures cleanly.      */
  --ff-title:          var(--ff-title-press);  /* Pirata One — pressed, clean  */
  --ff-body:           "Cardo","EB Garamond","Gentium Book Plus",Georgia,serif;
  --ff-sign:           "Cardo","EB Garamond","Gentium Book Plus",serif; /* ital */
  --ff-versal:         "Cardo","EB Garamond",serif;

  /* ── MOTIF DATA HOOK: read by illumination engine ───────────────────────── */
  --motif:             "white-vine";

  /* ── FAMILY-LOCAL TUNING (non-structural; cosmetic type only) ────────────
     Pirata One is a touch playful; we give it a hair of air to read as a
     calm humanist display. Adjusts ONLY type cosmetics, never layout boxes.  */
  --ls-title:          .02em;
}

/* ============================================================================
   2 · TITLE  ·  a cleaner Pirata One, lightly gilt
   ----------------------------------------------------------------------------
   Pirata One reads as a confident humanist display. We keep the gilt restrained:
   the shared gilt-text recipe, but a quieter drop — this is a diploma, not a
   royal proclamation. Title only — never the body (display faces unreadable at
   body size).
   ============================================================================ */
.sc2-scroll[data-family="scholars_hand"] .sc2-title {
  font-family: var(--ff-title);
  font-weight: 400;
  letter-spacing: var(--ls-title);
  line-height: 1.0;
  /* gilt-text recipe (shared) — restrained drop, humanist not royal */
  background: var(--gild-gradient);
  -webkit-background-clip: text;
          background-clip: text;
  color: transparent;
  -webkit-text-stroke: var(--gild-text-stroke);
  filter:
    drop-shadow(0 1px 0 var(--gold-hi))
    drop-shadow(0 1px 2px rgba(42,33,26,.28));
}

/* The opening invocation: a calm humanist small-caps line, in the blue rubric —
   "Whereas it is the ancient custom of this realm..." set quietly apart. */
.sc2-scroll[data-family="scholars_hand"] .sc2-invocation {
  font-family: var(--ff-smallcaps);
  letter-spacing: var(--ls-invocation);
  color: var(--rubric);                 /* rubricated in BLUE — the signature  */
  text-transform: uppercase;
  font-feature-settings: "smcp" 1, "onum" 1;
}

/* Intitulation: Cardo small-caps with old-style figures, muted scriptorium ink. */
.sc2-scroll[data-family="scholars_hand"] .sc2-intitulation {
  font-family: var(--ff-smallcaps);
  letter-spacing: var(--ls-intitulation);
  color: var(--ink-muted);
  font-feature-settings: "smcp" 1, "onum" 1;
}

/* Recipient name & section openers in the BLUE humanist rubric. */
.sc2-scroll[data-family="scholars_hand"] .sc2-body .sc2-rubric,
.sc2-scroll[data-family="scholars_hand"] .sc2-rubric,
.sc2-scroll[data-family="scholars_hand"] .sc2-recipient,
.sc2-scroll[data-family="scholars_hand"] .sc2-grant strong {
  color: var(--rubric);
  text-shadow: var(--rubric-shadow);
  font-feature-settings: "onum" 1, "liga" 1;
}

/* ── BODY — justified humanist Cardo with ligatures & old-style figures ────── */
.sc2-scroll[data-family="scholars_hand"] .sc2-body {
  font-family: var(--ff-body);
  text-align: justify;
  text-justify: inter-word;
  hyphens: auto;
  font-feature-settings: "liga" 1, "onum" 1, "kern" 1;
}

/* ── GRANT / DISPOSITIVE CLAUSE — the operative title-grant, centred italic ── */
.sc2-scroll[data-family="scholars_hand"] .sc2-grant {
  font-family: var(--ff-body);
  font-style: italic;
  text-align: center;
  color: var(--ink);
  font-feature-settings: "onum" 1, "liga" 1;
}
.sc2-scroll[data-family="scholars_hand"] .sc2-grant__verb {
  font-family: var(--ff-smallcaps);
  font-style: normal;
  letter-spacing: .1em;
  text-transform: uppercase;
  color: var(--ink-muted);
  font-feature-settings: "smcp" 1;
}
.sc2-scroll[data-family="scholars_hand"] .sc2-grant__award {
  color: var(--rubric);                 /* the awarded title, in blue rubric   */
  font-style: normal;
}

/* ── DATUM (date & place) — humanist small-caps, old-style figures, muted ──── */
.sc2-scroll[data-family="scholars_hand"] .sc2-datum {
  font-family: var(--ff-smallcaps);
  letter-spacing: .04em;
  color: var(--ink-muted);
  text-align: center;
  font-style: italic;
  font-feature-settings: "smcp" 1, "onum" 1;
}

/* ── ATTESTATION / SIGNATURES — Cardo italic over a quiet sig-rule ─────────── */
.sc2-scroll[data-family="scholars_hand"] .sc2-attest,
.sc2-scroll[data-family="scholars_hand"] .sc2-sig__name {
  font-family: var(--ff-sign);
  font-style: italic;
  color: var(--ink);
}
.sc2-scroll[data-family="scholars_hand"] .sc2-sig__line {
  /* the ruled line a signatory's name rests upon — quiet brown ink, no gilt */
  border-top: 1px solid var(--rule-fine);
  box-shadow: 0 1px 0 rgba(253,249,238,.5);
}
.sc2-scroll[data-family="scholars_hand"] .sc2-sig__title {
  font-family: var(--ff-smallcaps);
  font-style: normal;
  letter-spacing: .12em;
  color: var(--ink-muted);
  text-transform: uppercase;
  font-feature-settings: "smcp" 1;
}

/* ============================================================================
   3 · SUBSTRATE FLAVOUR  ·  a clean, evenly-lit sheet
   ----------------------------------------------------------------------------
   Restraint is the brief. Rather than the dappled / mottled washes of the
   rustic families, Scholar's Hand adds only the faintest even tint pools so the
   sheet reads as a fresh, well-kept diploma. Attached to .sc2-vellum's own
   ::after (the substrate partial reserves the element's primary background);
   stays at --z-vellum (no z override).
   ============================================================================ */
.sc2-scroll[data-family="scholars_hand"] .sc2-vellum::after {
  content: "";
  position: absolute;
  inset: 0;
  pointer-events: none;
  background:
    radial-gradient(60% 50% at 50% 22%, rgba(253,249,238,.30), transparent 72%),
    radial-gradient(34% 28% at 84% 80%, rgba(194,173,126,.10), transparent 74%);
  mix-blend-mode: normal;
  opacity: .9;
}

/* ============================================================================
   4 · ILLUMINATION  ·  the white-vine (bianchi girari) border
   ----------------------------------------------------------------------------
   THE defining ornament. The shared .sc2-border SVG is themed via these fills;
   on top of it we lay the quattrocento WHITE-VINE band: quartered jewel grounds
   (azure / vert / gules, alternating along the frame) with WHITE vine stems
   coiling in calm spirals and little white trefoil dots scattered between.
   Built as layered inline-SVG data-URIs on .sc2-band so it survives
   html2canvas / print without filter dependence. Density is deliberately LOWER
   than Crimson / Gothic — more ground shows between the coils.
   ============================================================================ */

/* Frame colour hooks consumed by the shared border SVG. */
.sc2-scroll[data-family="scholars_hand"] .sc2-illum {
  color: var(--accent);                 /* foliate stroke currentColor          */
}
.sc2-scroll[data-family="scholars_hand"] .sc2-border .sc2-rule-fine {
  stroke: var(--gold-deep);             /* restrained: a single quiet gilt rule */
  stroke-width: 1;
  fill: none;
  filter: drop-shadow(0 .5px .5px rgba(58,40,12,.45));
}
.sc2-scroll[data-family="scholars_hand"] .sc2-border .sc2-bar {
  /* the vert field bar — a thin, calm humanist rule */
  fill: var(--border);
  stroke: var(--gold-keyline);
  stroke-width: .5;
}
.sc2-scroll[data-family="scholars_hand"] .sc2-border .sc2-band-fill {
  fill: var(--wv-azure);                /* default band ground if SVG asks      */
}

/* The bar-border element (if the markup uses a CSS bar rather than SVG): a thin
   vert rule, quiet inner gilt keyline — humanist restraint. */
.sc2-scroll[data-family="scholars_hand"] .sc2-illum .sc2-bar {
  background: var(--border);
  box-shadow:
    inset 0 0 0 1px rgba(11,102,35,.55),
    inset 0 1px 0 rgba(255,241,168,.14);
  border-radius: 1px;
}

/* ── The white-vine band, drawn as a layered inline-SVG data-URI ────────────
   The tile carries THREE quartered jewel grounds (azure + vert + gules) so that,
   repeated along the frame, the field reads as alternating azure / vert / gules
   cells. White (#f8f4e3) vine stems coil in spirals over the grounds with little
   white trefoil dots between. Laid on .sc2-band so it tiles along the frame. */
.sc2-scroll[data-family="scholars_hand"] .sc2-band,
.sc2-scroll[data-family="scholars_hand"] .sc2-illum .sc2-band {
  background-image:
    url("data:image/svg+xml;utf8,\
<svg xmlns='http://www.w3.org/2000/svg' width='120' height='40' viewBox='0 0 120 40'>\
<rect x='0' y='0' width='40' height='40' fill='%2327408b'/>\
<rect x='40' y='0' width='40' height='40' fill='%232e7d4f'/>\
<rect x='80' y='0' width='40' height='40' fill='%23b22222'/>\
<g fill='none' stroke='%23f8f4e3' stroke-width='2.6' stroke-linecap='round'>\
<path d='M2 20 C 2 8, 18 8, 18 20 C 18 32, 34 32, 34 20'/>\
<path d='M42 20 C 42 8, 58 8, 58 20 C 58 32, 74 32, 74 20'/>\
<path d='M82 20 C 82 8, 98 8, 98 20 C 98 32, 114 32, 114 20'/>\
</g>\
<g fill='%23f8f4e3'>\
<circle cx='10' cy='10' r='1.7'/><circle cx='7' cy='13' r='1.7'/><circle cx='13' cy='13' r='1.7'/>\
<circle cx='50' cy='10' r='1.7'/><circle cx='47' cy='13' r='1.7'/><circle cx='53' cy='13' r='1.7'/>\
<circle cx='90' cy='10' r='1.7'/><circle cx='87' cy='13' r='1.7'/><circle cx='93' cy='13' r='1.7'/>\
<circle cx='26' cy='30' r='1.5'/><circle cx='66' cy='30' r='1.5'/><circle cx='106' cy='30' r='1.5'/>\
</g>\
</svg>");
  background-repeat: repeat;
  background-size: 120px 40px;
  opacity: .96;
}

/* When the band is an SVG layer with discrete fill classes, theme them directly
   so the engine can paint the quartered grounds + white vine without the tile. */
.sc2-scroll[data-family="scholars_hand"] .sc2-border .sc2-band-azure { fill: var(--wv-azure); }
.sc2-scroll[data-family="scholars_hand"] .sc2-border .sc2-band-vert  { fill: var(--wv-vert);  }
.sc2-scroll[data-family="scholars_hand"] .sc2-border .sc2-band-gules { fill: var(--wv-gules); }
.sc2-scroll[data-family="scholars_hand"] .sc2-border .sc2-vine       { stroke: var(--wv-stem); fill: none; stroke-linecap: round; }
.sc2-scroll[data-family="scholars_hand"] .sc2-border .sc2-vine-shade { stroke: var(--wv-stem-shade); fill: none; }
.sc2-scroll[data-family="scholars_hand"] .sc2-border .sc2-trefoil    { fill: var(--wv-stem); }
.sc2-scroll[data-family="scholars_hand"] .sc2-border .sc2-gild       { fill: url(#sc2-gild); }

/* ── Corner pieces: a tighter white-vine knot on an azure ground roundel ────
   The corners get the densest spiral of the white vine — a small coiled knot
   over an azure quarter, ringed by a thin gilt keyline. Four positioned nodes;
   one inline-SVG, mirrored per corner. */
.sc2-scroll[data-family="scholars_hand"] .sc2-illum .sc2-corner {
  position: absolute;
  width: var(--corner-size);
  height: var(--corner-size);
  z-index: 1;
  pointer-events: none;
  background-repeat: no-repeat;
  background-position: center;
  background-size: contain;
  background-image:
    url("data:image/svg+xml;utf8,\
<svg xmlns='http://www.w3.org/2000/svg' width='72' height='72' viewBox='0 0 72 72'>\
<path d='M4 4 L40 4 C 40 24, 24 40, 4 40 Z' fill='%2327408b'/>\
<g fill='none' stroke='%23f8f4e3' stroke-width='2.6' stroke-linecap='round'>\
<path d='M10 10 C 26 10, 26 26, 14 26 C 8 26, 8 18, 14 18 C 18 18, 18 22, 16 22'/>\
<path d='M22 8 C 22 22, 8 22, 8 14'/>\
</g>\
<g fill='%23f8f4e3'>\
<circle cx='30' cy='12' r='1.7'/><circle cx='27' cy='15' r='1.7'/><circle cx='33' cy='15' r='1.7'/>\
<circle cx='12' cy='32' r='1.5'/>\
</g>\
<path d='M4 4 L40 4 C 40 24, 24 40, 4 40 Z' fill='none' stroke='%23a9760a' stroke-width='1'/>\
</svg>");
}
.sc2-scroll[data-family="scholars_hand"] .sc2-illum .sc2-corner--tl { top: var(--margin-frame); left:  var(--margin-frame); }
.sc2-scroll[data-family="scholars_hand"] .sc2-illum .sc2-corner--tr { top: var(--margin-frame); right: var(--margin-frame); transform: scaleX(-1); }
.sc2-scroll[data-family="scholars_hand"] .sc2-illum .sc2-corner--bl { bottom: var(--margin-frame); left:  var(--margin-frame); transform: scaleY(-1); }
.sc2-scroll[data-family="scholars_hand"] .sc2-illum .sc2-corner--br { bottom: var(--margin-frame); right: var(--margin-frame); transform: scale(-1,-1); }

/* ============================================================================
   5 · ILLUMINATED VERSAL  ·  the white-vine initial box (azure ground)
   ----------------------------------------------------------------------------
   The opening word's first letter sits in a deep AZURE box (--initial-ground
   #27408b) — the classic quattrocento white-vine initial. The letter is a calm
   gilt; a single white-vine tendril coils in the ground behind it. Whether the
   markup floats a .sc2-versal element OR uses ::first-letter, the same treatment
   applies. RESTRAINED: one keyline, no triple-gilt frame.
   ============================================================================ */
.sc2-scroll[data-family="scholars_hand"] .sc2-body > p:first-of-type::first-letter,
.sc2-scroll[data-family="scholars_hand"] .sc2-body[data-sc2-versal] > p:first-of-type::first-letter,
.sc2-scroll[data-family="scholars_hand"] .sc2-versal {
  font-family: var(--ff-versal);
  color: var(--gold-hi);
  -webkit-text-fill-color: var(--gold-hi);
  /* the azure box with a faint white-vine coil behind the letter */
  background:
    url("data:image/svg+xml;utf8,\
<svg xmlns='http://www.w3.org/2000/svg' width='60' height='60' viewBox='0 0 60 60'>\
<g fill='none' stroke='%23f8f4e3' stroke-width='2.4' stroke-linecap='round' opacity='0.5'>\
<path d='M8 50 C 8 30, 28 30, 28 48 C 28 56, 40 56, 40 44'/>\
<path d='M52 12 C 52 30, 34 30, 34 14 C 34 8, 44 8, 44 14'/>\
</g>\
</svg>") center / cover no-repeat,
    linear-gradient(135deg,
      color-mix(in srgb, var(--initial-ground) 86%, #000 14%) 0%,
      var(--initial-ground) 55%,
      color-mix(in srgb, var(--initial-ground) 78%, #000 22%) 100%);
  text-shadow:
    0 1px 0 var(--gold-shadow),
    0 0 5px rgba(255,241,168,.30);
  box-shadow:
    inset 0 0 0 1.25px var(--gold-deep),
    0 1px 2px rgba(28,24,16,.38);
  border-radius: 3px;
}

/* ============================================================================
   6 · HERALDRY  ·  vesica (pointed-oval) humanist achievement
   ----------------------------------------------------------------------------
   The escutcheon token is 'vesica' (set above) — the pointed oval used for
   scholarly / ecclesiastical seals, fitting the arts-&-sciences register. The
   shared heraldry engine clips the arms to a vesica; here we give it a quiet
   gilt rim and an azure inner ring (echoing the rubric), with NO coronet — the
   humanist achievement wears no crown.
   ============================================================================ */
.sc2-scroll[data-family="scholars_hand"] .sc2-arms {
  --arms-rim: var(--gold);
  filter: drop-shadow(0 1px 2px rgba(28,24,16,.32));
}
.sc2-scroll[data-family="scholars_hand"] .sc2-arms .sc2-arms-rim {
  filter:
    drop-shadow(0 1px 0 var(--gold-hi))
    drop-shadow(0 1px 2px rgba(28,24,16,.30));
}
.sc2-scroll[data-family="scholars_hand"] .sc2-arms .sc2-arms-ring {
  stroke: var(--accent);                /* azure inner ring — echoes rubric    */
  stroke-width: 1.5;
  fill: none;
  opacity: .85;
}
.sc2-scroll[data-family="scholars_hand"] .sc2-arms img,
.sc2-scroll[data-family="scholars_hand"] .sc2-arms svg {
  border: 2px solid var(--arms-rim);
  outline: 1px solid var(--arms-keyline);
  box-shadow:
    inset 0 0 0 1px rgba(255,241,168,.45),
    0 1px 2px rgba(28,24,16,.30);
  background: var(--vellum-hi);
}
.sc2-scroll[data-family="scholars_hand"] .sc2-arms__label {
  font-family: var(--ff-smallcaps);
  letter-spacing: .1em;
  color: var(--ink-muted);
  text-transform: uppercase;
  font-feature-settings: "smcp" 1;
}

/* ============================================================================
   7 · WAX SEAL  ·  natural / humble ochre wax in a VESICA
   ----------------------------------------------------------------------------
   No royal sanguine here: the scholar's wax is a natural ochre (#b98a3c),
   pressed into a pointed-oval (vesica) matrix rather than a disc. The shared
   seal SVG reads --wax* and --ribbon-*; we add a quiet rim and emboss a small
   open-book / quill sigil into the wax (the arts-&-sciences mark). Azure & gold
   ribbon tails carry the family livery, used sparingly.
   ============================================================================ */
.sc2-scroll[data-family="scholars_hand"] .sc2-seal,
.sc2-scroll[data-family="scholars_hand"] .sc2-seal-disc {
  filter:
    drop-shadow(0 2px 3px rgba(40,28,8,.40))
    drop-shadow(0 0 1px rgba(0,0,0,.35));
}
.sc2-scroll[data-family="scholars_hand"] .sc2-seal .sc2-wax-body { fill: var(--wax); }
.sc2-scroll[data-family="scholars_hand"] .sc2-seal .sc2-wax-hi   { fill: var(--wax-hi); }
.sc2-scroll[data-family="scholars_hand"] .sc2-seal .sc2-wax-lo   { fill: var(--wax-lo); }
.sc2-scroll[data-family="scholars_hand"] .sc2-seal .sc2-wax-rim {
  fill: none;
  stroke: var(--gold-deep);
  stroke-width: 1.5;
  filter: drop-shadow(0 1px 0 rgba(255,241,168,.4));
}
/* Embossed open-book / quill sigil pressed into the natural wax. */
.sc2-scroll[data-family="scholars_hand"] .sc2-seal .sc2-seal-sigil,
.sc2-scroll[data-family="scholars_hand"] .sc2-seal-sigil {
  fill: var(--wax-lo);
  filter:
    drop-shadow(-.5px -.5px .5px rgba(255,224,160,.45))
    drop-shadow(.5px .8px .8px rgba(0,0,0,.45));
}

/* If the markup uses a CSS-only seal fallback, theme it ochre + vesica-pinched. */
.sc2-scroll[data-family="scholars_hand"] .sc2-seal-wrap .sc2-seal--css {
  background:
    radial-gradient(120% 120% at 32% 26%, var(--wax-hi) 0%, var(--wax) 48%, var(--wax-lo) 100%);
  box-shadow:
    inset 0 2px 5px rgba(120,85,32,.5),
    inset 0 -3px 6px rgba(60,42,14,.55),
    0 6px 14px rgba(40,28,8,.42);
  /* pinch toward a vesica (pointed oval) via radius on the vertical axis */
  border-radius: 50% / 60%;
}
/* Open-book sigil embossed into the CSS seal via a centred mask. */
.sc2-scroll[data-family="scholars_hand"] .sc2-seal-wrap .sc2-seal--css::after {
  content: "";
  position: absolute;
  inset: 26%;
  background:
    url("data:image/svg+xml;utf8,\
<svg xmlns='http://www.w3.org/2000/svg' width='44' height='40' viewBox='0 0 44 40'>\
<g fill='none' stroke='%237a5520' stroke-width='2' stroke-linejoin='round'>\
<path d='M22 10 C 16 6, 8 6, 4 8 L4 32 C 8 30, 16 30, 22 34 Z'/>\
<path d='M22 10 C 28 6, 36 6, 40 8 L40 32 C 36 30, 28 30, 22 34 Z'/>\
<path d='M22 10 L22 34'/>\
</g>\
<path d='M30 4 L40 14' stroke='%237a5520' stroke-width='2' stroke-linecap='round'/>\
</svg>") center / contain no-repeat;
  opacity: .85;
}

/* Ribbon tails: azure + restrained gold, the scholar's livery. */
.sc2-scroll[data-family="scholars_hand"] .sc2-seal-wrap .sc2-ribbon-a,
.sc2-scroll[data-family="scholars_hand"] .sc2-ribbon-tail--a { background: var(--ribbon-a); }
.sc2-scroll[data-family="scholars_hand"] .sc2-seal-wrap .sc2-ribbon-b,
.sc2-scroll[data-family="scholars_hand"] .sc2-ribbon-tail--b { background: var(--ribbon-b); }
.sc2-scroll[data-family="scholars_hand"] .sc2-seal .sc2-ribbon-a-fill,
.sc2-scroll[data-family="scholars_hand"] .sc2-seal-ribbon .sc2-ribbon-a { fill: var(--ribbon-a); }
.sc2-scroll[data-family="scholars_hand"] .sc2-seal .sc2-ribbon-b-fill,
.sc2-scroll[data-family="scholars_hand"] .sc2-seal-ribbon .sc2-ribbon-b { fill: var(--ribbon-b); }

/* ============================================================================
   8 · BAS-DE-PAGE  ·  a quiet white-vine rule (not a heavy cartouche)
   ----------------------------------------------------------------------------
   Where the imperial / decree families anchor the foot with a heavy cartouche,
   Scholar's Hand lays a single SLIM white-vine rule across the foot margin: a
   short coil of the white vine on a faint azure wash, flanking the pendant
   vesica seal. Restraint and whitespace.
   ============================================================================ */
.sc2-scroll[data-family="scholars_hand"] .sc2-seal-wrap {
  position: relative;
  margin-top: var(--basdepage-extra);
}
.sc2-scroll[data-family="scholars_hand"] .sc2-seal-wrap::before {
  content: "";
  position: absolute;
  left: var(--content-pad);
  right: var(--content-pad);
  bottom: 0.25em;
  height: 1.1em;
  z-index: 0;
  pointer-events: none;
  background-repeat: repeat-x;
  background-position: bottom center;
  background-size: 140px 18px;
  opacity: .7;
  background-image:
    url("data:image/svg+xml;utf8,\
<svg xmlns='http://www.w3.org/2000/svg' width='140' height='18' viewBox='0 0 140 18'>\
<g fill='none' stroke='%232a4b8d' stroke-width='1.4' stroke-linecap='round' opacity='0.7'>\
<path d='M6 14 C 6 6, 22 6, 22 14 C 22 22, 38 22, 38 14'/>\
<path d='M46 14 C 46 6, 62 6, 62 14 C 62 22, 78 22, 78 14'/>\
<path d='M86 14 C 86 6, 102 6, 102 14 C 102 22, 118 22, 118 14'/>\
</g>\
<g fill='%232a4b8d' opacity='0.6'>\
<circle cx='14' cy='8' r='1.4'/><circle cx='54' cy='8' r='1.4'/><circle cx='94' cy='8' r='1.4'/>\
<circle cx='130' cy='10' r='1.4'/>\
</g>\
</svg>");
}

/* ============================================================================
   9 · GRANT DIVIDER  ·  a slim humanist drop-rule
   ----------------------------------------------------------------------------
   The dispositive clause is set off by a thin azure drop-rule rather than a hard
   divider — quiet, scholarly, in keeping with the restrained register.
   ============================================================================ */
.sc2-scroll[data-family="scholars_hand"] .sc2-grant {
  position: relative;
}
.sc2-scroll[data-family="scholars_hand"] .sc2-grant::before {
  content: "";
  display: block;
  width: 34%;
  height: 1px;
  margin: 0 auto var(--gap-tight);
  background:
    linear-gradient(90deg, transparent, var(--accent) 30%, var(--accent) 70%, transparent);
  opacity: .5;
}

/* ============================================================================
   10 · EXPORT / PRINT  ·  flatten gilt text, keep the humanist warmth
   ----------------------------------------------------------------------------
   background-clip:text degrades in html2canvas / some PDF engines. Under the
   shared export/print flags, fall the title back to a solid restrained gold
   with a quiet keyline shadow. We touch ONLY texture/gilt rendering — nothing
   structural. The white-vine band, corners, versal coil, bas-de-page rule and
   seal sigil are all baked SVG data-URIs already, so they survive rasterisation
   without modification.
   ============================================================================ */
.sc2-scroll.sc2-export[data-family="scholars_hand"] .sc2-title {
  background: none;
  -webkit-text-fill-color: var(--gold);
  color: var(--gold);
  -webkit-text-stroke: 0;
  text-shadow: 0 1px 0 var(--gold-keyline);
  filter: drop-shadow(0 1px 1px rgba(42,33,26,.32));
}
@media print {
  .sc2-scroll[data-family="scholars_hand"] .sc2-title {
    background: none;
    -webkit-text-fill-color: var(--gold);
    color: var(--gold);
    -webkit-text-stroke: 0;
    text-shadow: 0 1px 0 var(--gold-keyline);
    filter: drop-shadow(0 1px 1px rgba(42,33,26,.32));
  }
}

/* ===== family: crusaders_charter ===== */
/* ============================================================================
   THE LETTERED SCROLL — families/family-crusaders_charter.css.part
   ----------------------------------------------------------------------------
   FAMILY:  Crusader's Charter   (data-family="crusaders_charter")
   ROLE:    Letters-Patent of a martial knightly order — the peerage /
            knighting register. A formal accolade scroll granted to a new
            knight of the order: bold gules-and-argent livery bar border (the
            heraldic rule of tincture honoured), cross-pattée corner bosses,
            torse-flanked heater shields, a banderole (ribbon scroll) motto
            beneath the title, and a GREEN (charter / perpetual) pendant wax
            seal. Register: knightly accolade — Letters Patent of Knighthood.

   THROUGHLINE — MARTIAL HERALDRY, not a garden. Where Forest Reverie is
   foliate and Imperial Edict is imperial, Crusader's Charter is ARMOURY: the
   ornament vocabulary is the cross-pattée, the heater shield, the torse
   (wreath of livery colours), and the banderole. The two-colour gules+argent
   livery bar — alternating heraldic red and silver-white blocks — is the
   family's instant tell. The seal is GREEN on purpose: green wax meant a
   perpetual / standing grant (a charter in fee), which is exactly what a
   patent of knighthood is.

   CONTRACT (per sf-tokens.css.part — obeyed exactly):
     • RE-SETS ONLY the permitted per-family tokens: substrate trio (+
       grime/foxing/ruling), --ink / --ink-muted / --rubric, the --gold* ramp,
       --border, --rule-fine, --accent[-soft], --initial-ground, --wax* /
       --ribbon-*, --escutcheon, --arms-rim / --arms-keyline, the --ff-* font
       aliases, --ls-title, and the --motif data hook.
     • MUST NOT touch z-index, --sheet-*, spacing/--gap-*, the shadow/gild
       helper recipes, or the motion (--t-*) tokens — those stay shared.
     • Every rule is scoped under .sc2-scroll[data-family="crusaders_charter"]
       so the app dark-mode chrome can never bleed into the vellum and this
       family can never leak onto its neighbours.
     • Ornament selectors bind to the locked sc2-* DOM hooks only; they
       DECORATE the shared layers and never re-flow the document or redefine
       geometry. Raw CSS, no <style> wrapper.

   PALETTE (authoritative for this family):
     vellum #f4e8c8 / hi #faf0d6 / lo (derived warm tan)
     ink #1c1810 · rubric #8b0000 (gules)
     gold #d4af37 hi #fff4c2 deep #a9760a keyline #5a3d0c
     border / accent #8b0000 (gules) · initial-ground #8b0000
     wax #1e5631 (green=perpetual) hi #3a7a4e lo #103a1f
     ribbon-a #8b0000 (gules) · ribbon-b #f2f2f0 (argent)
   ============================================================================ */


/* ============================================================================
   1. TOKEN OVERRIDES  —  scoped to the family
   ----------------------------------------------------------------------------
   These re-set the shared CSS variables to the Crusader's Charter livery.
   This partial loads AFTER sf-tokens.css.part at equal specificity, so these
   values win over the baseline per the locked load order.
   ============================================================================ */
.sc2-scroll[data-family="crusaders_charter"] {

	/* ── SUBSTRATE / VELLUM ──────────────────────────────────────────────────
	   Warm, prepared chancery calf — a patent meant to be kept and displayed,
	   so it is clean and golden rather than scorched or weathered. The radial
	   centre is the palest catch; the edge ages to a soft saddle tan. */
	--vellum:            #f4e8c8;   /* base parchment body                        */
	--vellum-hi:         #faf0d6;   /* lightest centre (radial top)               */
	--vellum-lo:         #ddc79a;   /* aged saddle-tan edge                       */
	--grime:             rgba(74,46,20,.30);   /* edge-grime vignette (warm)      */
	--foxing:            #b58c54;   /* stain / foxing blobs (used 8–18% alpha)    */
	--ruling:            #9c8156;   /* faint chancery ruling + pricking           */
	--curl-shadow:       rgba(64,40,16,.34);   /* cast shadow under any curl      */

	/* ── INK ──────────────────────────────────────────────────────────────────
	   Near-black warm sepia for the legal text; the muted tone carries the
	   gules toward sanguine so titles/labels read martial, not merely brown. */
	--ink:               #1c1810;   /* body ink — NEVER #000, but the darkest     */
	--ink-muted:         #5a2a22;   /* intitulation / signature titles (sanguine) */
	--rubric:            #8b0000;   /* gules: knight's name + dispositive openers */

	/* ── GILDING — bright order-gold; the cross-pattée + bar keylines ramp ────
	   Honours: never a flat #ffd700 fill — always the shared raised-gilt recipe
	   (--gild-gradient / --gild-text-stroke / --gild-drop) on any meaningful
	   surface; the ramp below only re-tints those composites. */
	--gold:              #d4af37;   /* mid body gold                              */
	--gold-hi:           #fff4c2;   /* specular hotspot                           */
	--gold-deep:         #a9760a;   /* lower gold shade                           */
	--gold-shadow:       #6e4d08;   /* darkest gold stop                          */
	--gold-keyline:      #5a3d0c;   /* thin dark recess line — sells "raised"     */

	/* ── BORDER / FRAME — the gules of the livery bar ─────────────────────────
	   The bar alternates this gules with argent (see the bar ornament below);
	   the rule of tincture (metal never on metal, colour never on colour) is
	   honoured by always laying a gilt keyline BETWEEN the two. */
	--border:            #8b0000;   /* gules livery field                         */
	--rule-fine:         #6b2a18;   /* sanguine-brown hairline outer rule         */
	--initial-ground:    #8b0000;   /* drop-cap decorated-box ground = gules      */

	/* ── ACCENT (secondary) — reads as the same heraldic gules ───────────────*/
	--accent:            #8b0000;
	--accent-soft:       rgba(139,0,0,.24);    /* washed gules (banderole field)  */

	/* ── WAX SEAL — GREEN (charter / perpetual grant) ─────────────────────────
	   Green sealing wax marked a standing grant in fee — exactly a knighting
	   patent. Pressed hard, gilt-rimmed, with a hot upper-left catch-light. */
	--wax:               #1e5631;   /* green wax body                             */
	--wax-hi:            #3a7a4e;   /* upper-left catch-light                      */
	--wax-lo:            #103a1f;   /* pooled centre / rim                        */

	/* ── LIVERY RIBBON TAILS — gules + argent (the order's colours) ──────────*/
	--ribbon-a:          #8b0000;   /* gules ribbon tail                          */
	--ribbon-b:          #f2f2f0;   /* argent ribbon tail                         */

	/* ── HERALDRY — heater shield (the martial escutcheon), gilt rim ─────────
	   --escutcheon maps to the clipPath id hook #sc2-escutcheon-heater the
	   markup already provides; gilt rim, deep sanguine keyline. */
	--escutcheon:        heater;
	--arms-rim:          var(--gold);
	--arms-keyline:      #3a1410;

	/* ── TYPOGRAPHY ──────────────────────────────────────────────────────────
	   Title: UnifrakturMaguntia (the baseline --ff-title default — kept), the
	   grand textura of a formal patent. Body: EB Garamond (humanist chancery).
	   Signatures: EB Garamond ITALIC. The versal is textura to match the title. */
	--ff-title:          "UnifrakturMaguntia","UnifrakturCook","Pirata One","Times New Roman",serif;
	--ff-body:           "EB Garamond","Cardo","IM Fell English",Garamond,Georgia,serif;
	--ff-sign:           "EB Garamond","Cardo","IM Fell English",serif;   /* render italic */
	--ff-versal:         "UnifrakturMaguntia","EB Garamond",serif;
	--ls-title:          .01em;     /* never track blackletter wide               */

	/* ── MOTIF DATA HOOK ──────────────────────────────────────────────────────
	   Read by the illumination engine to pick the inline-SVG motif. */
	--motif:             "crusader-cross";
}


/* ============================================================================
   2. ILLUMINATION BORDER — gules+argent livery bar, cross-pattée corner bosses
   ----------------------------------------------------------------------------
   The border SVG (viewBox 0 0 850 1100) exposes:
     .sc2-border__rule    — the fine outer hairline rule
     .sc2-border__bar     — the bold field bar
     .sc2-border__band[data-sc2-band]    — the decorated band track
     .sc2-border__corners[data-sc2-corners] — the four corner ornament slots
   We colour the bar as a GULES+ARGENT alternation (the family tell), edge it
   in gilt to honour the rule of tincture, and drop a cross-pattée boss into
   each corner slot. We never redraw the band geometry — only paint it.
   ============================================================================ */

/* Drive any stroke="currentColor" geometry in the border to the gules field. */
.sc2-scroll[data-family="crusaders_charter"] .sc2-border {
	color: var(--border);
	filter: drop-shadow(0 1px 1px rgba(40,12,8,.35));
}

/* Fine outer rule — a single bright gilt hairline, raised. */
.sc2-scroll[data-family="crusaders_charter"] .sc2-border__rule {
	fill: none;
	stroke: var(--gold);
	stroke-width: 1.25;
	filter: drop-shadow(0 .5px .5px rgba(60,24,8,.5));
}

/* The BAR — bold gules ground. The argent halves of the livery alternation
   are painted as a repeating overlay on the band track (see [data-sc2-band]
   below); the bar itself carries the gules and the dark keyline that keeps
   metal off metal where argent meets gilt. */
.sc2-scroll[data-family="crusaders_charter"] .sc2-border__bar {
	fill: var(--border);
	stroke: var(--gold-keyline);
	stroke-width: .6;
}

/* LIVERY ALTERNATION — the gules+argent striped bar.
   The band track [data-sc2-band] runs the full frame; we fill it with a
   hard-edged repeating gradient that alternates gules and argent blocks,
   honouring the rule of tincture by inserting a thin gilt keyline at every
   colour↔metal join. This is the family's signature treatment. (SVG fills via
   `fill`; HTML strips via `background-image` — both declared so either build
   shows the livery.) */
.sc2-scroll[data-family="crusaders_charter"] .sc2-border__band[data-sc2-band] {
	fill: var(--border);
}
.sc2-scroll[data-family="crusaders_charter"] .sc2-border__band[data-sc2-band="top"],
.sc2-scroll[data-family="crusaders_charter"] .sc2-border__band[data-sc2-band="bottom"] {
	background-image: repeating-linear-gradient(90deg,
		var(--border)       0,    var(--border)       30px,
		var(--gold-deep)    30px, var(--gold-deep)    32px,
		var(--ribbon-b)     32px, var(--ribbon-b)     62px,
		var(--gold-deep)    62px, var(--gold-deep)    64px);
}
.sc2-scroll[data-family="crusaders_charter"] .sc2-border__band[data-sc2-band="left"],
.sc2-scroll[data-family="crusaders_charter"] .sc2-border__band[data-sc2-band="right"] {
	background-image: repeating-linear-gradient(180deg,
		var(--border)       0,    var(--border)       30px,
		var(--gold-deep)    30px, var(--gold-deep)    32px,
		var(--ribbon-b)     32px, var(--ribbon-b)     62px,
		var(--gold-deep)    62px, var(--gold-deep)    64px);
}

/* Fallback for builds where the band is an HTML strip rather than an SVG fill:
   carry the gilt top catch-light / sanguine recess / gilt keyline framing. */
.sc2-scroll[data-family="crusaders_charter"] .sc2-illum .sc2-border__band {
	background-color: var(--border);
	box-shadow:
		inset 0  .75px 0 rgba(255,244,194,.45),   /* gilt top catch-light        */
		inset 0 -.75px 0 rgba(40,12,8,.5),        /* sanguine bottom recess       */
		0 0 0 .75px var(--gold-keyline);          /* gilt outer keyline           */
}

/* CROSS-PATTÉE CORNER BOSSES — the four .sc2-border__corners slots.
   The defining motif: a gilt cross-pattée (arms flaring to the tips) on a
   gules disc boss. Painted SVG when present; the CSS fallback below synthesises
   the same cross from masks so it survives builds without the SVG glyph. */
.sc2-scroll[data-family="crusaders_charter"] .sc2-border__corners[data-sc2-corners] .sc2-cross-pattee,
.sc2-scroll[data-family="crusaders_charter"] .sc2-border__corners[data-sc2-corners] path {
	fill: var(--gold);
	stroke: var(--gold-keyline);
	stroke-width: .6;
	filter: var(--gild-drop);
}
.sc2-scroll[data-family="crusaders_charter"] .sc2-border__corners[data-sc2-corners] .sc2-cross-boss {
	fill: var(--initial-ground);      /* gules disc behind the cross            */
	stroke: var(--gold);
	stroke-width: 1;
}
.sc2-scroll[data-family="crusaders_charter"] .sc2-border__corners[data-sc2-corners] .sc2-cross-pip {
	fill: var(--gold-hi);             /* tiny gilt centre pip                    */
}

/* CSS-synthesised cross-pattée for the .sc2-illum corner slots (no-op if the
   SVG glyph already fills them). A gules disc carrying a gilt cross whose arms
   flare to the edge — built from four conic-masked flares around a centre. */
.sc2-scroll[data-family="crusaders_charter"] .sc2-illum .sc2-corner {
	background: none;
}
.sc2-scroll[data-family="crusaders_charter"] .sc2-illum .sc2-corner::before {
	content: "";
	position: absolute;
	width: 38px;
	height: 38px;
	border-radius: 50%;
	/* gules boss disc with a raised gilt rim */
	background:
		radial-gradient(circle at 38% 32%,
			color-mix(in srgb, var(--initial-ground) 82%, #fff 18%) 0%,
			var(--initial-ground) 46%,
			color-mix(in srgb, var(--initial-ground) 78%, #000 22%) 100%);
	box-shadow:
		inset 0 0 0 1.5px var(--gold),
		inset 0 0 0 2.6px var(--gold-keyline),
		0 1px 2px rgba(40,12,8,.45);
}
.sc2-scroll[data-family="crusaders_charter"] .sc2-illum .sc2-corner::after {
	content: "";
	position: absolute;
	width: 26px;
	height: 26px;
	pointer-events: none;
	/* gilt cross-pattée: two crossed bars whose ends flare via conic masks */
	background:
		linear-gradient(135deg,
			var(--gold-shadow) 0%, var(--gold) 28%, var(--gold-hi) 50%,
			var(--gold) 72%, var(--gold-deep) 100%);
	-webkit-mask:
		conic-gradient(from -45deg  at 50% 0,    #000 0 90deg, transparent 0) 50% 0    / 64% 50% no-repeat,
		conic-gradient(from 135deg  at 50% 100%, #000 0 90deg, transparent 0) 50% 100% / 64% 50% no-repeat,
		conic-gradient(from 45deg   at 0 50%,    #000 0 90deg, transparent 0) 0 50%    / 50% 64% no-repeat,
		conic-gradient(from -135deg at 100% 50%, #000 0 90deg, transparent 0) 100% 50% / 50% 64% no-repeat,
		linear-gradient(#000 0 0) 50% 50% / 38% 38% no-repeat;
	        mask:
		conic-gradient(from -45deg  at 50% 0,    #000 0 90deg, transparent 0) 50% 0    / 64% 50% no-repeat,
		conic-gradient(from 135deg  at 50% 100%, #000 0 90deg, transparent 0) 50% 100% / 64% 50% no-repeat,
		conic-gradient(from 45deg   at 0 50%,    #000 0 90deg, transparent 0) 0 50%    / 50% 64% no-repeat,
		conic-gradient(from -135deg at 100% 50%, #000 0 90deg, transparent 0) 100% 50% / 50% 64% no-repeat,
		linear-gradient(#000 0 0) 50% 50% / 38% 38% no-repeat;
	filter: drop-shadow(0 1px 1px rgba(40,12,8,.55));
}
/* Anchor each cross-pattée boss to its corner. */
.sc2-scroll[data-family="crusaders_charter"] .sc2-illum .sc2-corner--tl::before { top: 7px;     left: 7px;  }
.sc2-scroll[data-family="crusaders_charter"] .sc2-illum .sc2-corner--tr::before { top: 7px;     right: 7px; }
.sc2-scroll[data-family="crusaders_charter"] .sc2-illum .sc2-corner--bl::before { bottom: 7px;  left: 7px;  }
.sc2-scroll[data-family="crusaders_charter"] .sc2-illum .sc2-corner--br::before { bottom: 7px;  right: 7px; }
.sc2-scroll[data-family="crusaders_charter"] .sc2-illum .sc2-corner--tl::after  { top: 13px;    left: 13px; }
.sc2-scroll[data-family="crusaders_charter"] .sc2-illum .sc2-corner--tr::after  { top: 13px;    right: 13px;}
.sc2-scroll[data-family="crusaders_charter"] .sc2-illum .sc2-corner--bl::after  { bottom: 13px; left: 13px; }
.sc2-scroll[data-family="crusaders_charter"] .sc2-illum .sc2-corner--br::after  { bottom: 13px; right: 13px;}


/* ============================================================================
   2b. WRITING PANEL — argent/vellum card behind the prose (CONTRAST FIX)
   ----------------------------------------------------------------------------
   The gules livery is intentional and rich, but it reads dark and threatens to
   swallow the body prose (defect img6: body/intitulation/datum/signatures
   nearly invisible — dark ink on a dark-red read). Rather than dilute the
   gules, we seat the writing column on a light argent/vellum PARCHMENT CARD so
   the existing dark ink reads crisply, while the gules continues to show in the
   border, bar, corners and margins around it. ONE approach, applied once, here.

   The card is painted on .sc2-content's own ::before so it needs no new markup
   and never re-flows the document; .sc2-content is z-index:4 (above vellum/
   illum), so its children — title, body, grant, datum, signatures — all sit on
   the light ground. A gilt keyline + soft inner light frames it as an inlaid
   patent panel honouring the order-gold ramp. */
.sc2-scroll[data-family="crusaders_charter"] .sc2-content {
	position: relative;
}
.sc2-scroll[data-family="crusaders_charter"] .sc2-content::before {
	content: "";
	position: absolute;
	inset: -1.1em -1.4em;            /* bleed just past the text column edge      */
	z-index: -1;                      /* behind the prose, above the gules layers  */
	pointer-events: none;
	border-radius: 4px;
	/* warm argent/vellum parchment card */
	background:
		radial-gradient(120% 140% at 50% 0%,
			var(--vellum-hi) 0%,
			var(--vellum)    48%,
			color-mix(in srgb, var(--vellum) 88%, var(--vellum-lo) 12%) 100%);
	box-shadow:
		inset 0 0 0 1px rgba(255,244,194,.55),       /* inner gilt catch-light    */
		inset 0 0 0 2.25px var(--gold-deep),         /* gilt keyline frame        */
		inset 0 0 0 3px var(--gold-keyline),         /* dark recess sells "raised"*/
		0 1px 3px rgba(40,12,8,.30);                 /* lift off the gules ground */
}
/* No-color-mix fallback: flat warm vellum card. */
@supports not (background: color-mix(in srgb, red 50%, blue)) {
	.sc2-scroll[data-family="crusaders_charter"] .sc2-content::before {
		background: var(--vellum);
	}
}


/* ============================================================================
   3. TYPOGRAPHY — knightly accolade hierarchy
   ----------------------------------------------------------------------------
   Grand textura title carrying a BANDEROLE motto beneath it; gules invocation;
   gules knight's-name rubric; justified humanist body with a gules-grounded
   illuminated versal; centred dispositive accolade clause; italic signatures.
   ALL prose below sits on the light argent writing card (§2b), so the dark warm
   inks read crisply against parchment while the gules frames the page.
   ============================================================================ */

/* TITLE — grand gilt textura, the locked gilt-text recipe (raised gold, never
   flat), tightest tracking the spec permits, sanguine drop so it reads pressed
   into the patent. */
.sc2-scroll[data-family="crusaders_charter"] .sc2-title {
	font-family: var(--ff-title);
	letter-spacing: var(--ls-title);
	line-height: .96;
	position: relative;
	background: var(--gild-gradient);
	-webkit-background-clip: text;
	        background-clip: text;
	color: transparent;
	-webkit-text-fill-color: transparent;
	-webkit-text-stroke: var(--gild-text-stroke);
	filter:
		drop-shadow(0 1px 0 var(--gold-hi))
		drop-shadow(0 2px 2px rgba(40,12,8,.4));
}

/* BANDEROLE MOTTO — a ribbon scroll strip slung beneath the title.
   Built CSS-only via ::after on the title so it needs no new markup: a gules
   field strip with an argent-tinted top light, its short ends cut into
   swallow-tail forks (the classic banderole). The order's motto rides on the
   strip; the engine sets it through the --sc2-motto custom property when a
   motto exists, otherwise the strip shows as a blank ribbon ornament. */
.sc2-scroll[data-family="crusaders_charter"] .sc2-title::after {
	content: var(--sc2-motto, "");
	display: block;
	width: min(70%, 34ch);
	margin: .42em auto 0;
	padding: .18em 2.4em;
	box-sizing: border-box;
	font-family: var(--ff-body);
	font-style: italic;
	font-size: .30em;                 /* relative to the large title em          */
	letter-spacing: .16em;
	text-transform: uppercase;
	text-align: center;
	white-space: nowrap;
	overflow: hidden;
	text-overflow: ellipsis;
	color: var(--vellum-hi);
	-webkit-text-fill-color: var(--vellum-hi);
	-webkit-text-stroke: 0;
	/* the gules banderole field: argent-tinted top light → gules → sanguine */
	background:
		linear-gradient(180deg,
			color-mix(in srgb, var(--border) 70%, #fff 30%) 0%,
			var(--border) 28%,
			color-mix(in srgb, var(--border) 80%, #000 20%) 100%);
	box-shadow:
		inset 0  1px 0 rgba(255,255,255,.28),
		inset 0 -2px 3px rgba(40,12,8,.5),
		0 0 0 1px var(--gold-keyline),
		0 1px 2px rgba(40,12,8,.4);
	/* swallow-tail forked ends: notch a triangle out of each short edge */
	-webkit-clip-path: polygon(0 0, 6% 50%, 0 100%, 100% 100%, 94% 50%, 100% 0);
	        clip-path: polygon(0 0, 6% 50%, 0 100%, 100% 100%, 94% 50%, 100% 0);
}
/* Folded-back ribbon returns behind the banderole — a darker gules tab that
   reads as the scroll curling behind the title block. */
.sc2-scroll[data-family="crusaders_charter"] .sc2-title::before {
	content: "";
	position: absolute;
	left: 50%;
	bottom: -.10em;
	transform: translateX(-50%);
	width: min(78%, 38ch);
	height: .26em;
	z-index: -1;
	pointer-events: none;
	background:
		linear-gradient(180deg,
			color-mix(in srgb, var(--border) 78%, #000 22%),
			color-mix(in srgb, var(--border) 60%, #000 40%));
	box-shadow: 0 1px 2px rgba(40,12,8,.45);
	border-radius: 1px;
}

/* INVOCATION — the rubricated accolade opener ("Know all men by these presents
   that We, of Our grace, have girded with the belt of knighthood…"). */
.sc2-scroll[data-family="crusaders_charter"] .sc2-invocation {
	font-family: var(--ff-body);
	color: var(--rubric);
	letter-spacing: var(--ls-invocation);
	font-variant: small-caps;
	text-transform: uppercase;
}
/* Cross-pattée fleurons bracketing the invocation — the order's mark. */
.sc2-scroll[data-family="crusaders_charter"] .sc2-invocation::before,
.sc2-scroll[data-family="crusaders_charter"] .sc2-invocation::after {
	content: "✠";                     /* cross-pattée glyph                       */
	color: var(--gold-deep);
	margin: 0 .55em;
	font-size: .95em;
	-webkit-text-stroke: .3px var(--gold-keyline);
	vertical-align: -.02em;
}

/* INTITULATION — sanguine small-caps gravitas, old-style figures. */
.sc2-scroll[data-family="crusaders_charter"] .sc2-intitulation {
	font-family: var(--ff-body);
	color: var(--ink-muted);
	font-variant: small-caps;
	letter-spacing: var(--ls-intitulation);
	font-feature-settings: "smcp" 1, "onum" 1;
}

/* BODY — justified humanist chancery with ligatures + old-style figures. */
.sc2-scroll[data-family="crusaders_charter"] .sc2-body {
	font-family: var(--ff-body);
	color: var(--ink);
	text-align: justify;
	text-justify: inter-word;
	hyphens: auto;
	font-feature-settings: "liga" 1, "onum" 1, "kern" 1;
}

/* KNIGHT'S NAME — the central gules rubric, the eye's anchor. */
.sc2-scroll[data-family="crusaders_charter"] .sc2-rubric,
.sc2-scroll[data-family="crusaders_charter"] .sc2-recipient,
.sc2-scroll[data-family="crusaders_charter"] .sc2-body .sc2-rubric {
	color: var(--rubric);
	font-weight: 600;
	text-shadow: var(--rubric-shadow);
	font-feature-settings: "onum" 1, "liga" 1;
}

/* ILLUMINATED VERSAL — gilt textura initial on a gules ground box.
   Target the ::first-letter ONLY (the [data-sc2-versal] hook is on the whole
   first <p>; styling that paragraph would gild the entire body text). */
.sc2-scroll[data-family="crusaders_charter"] .sc2-body > p:first-of-type::first-letter {
	font-family: var(--ff-versal);
	color: var(--gold-hi);
	-webkit-text-fill-color: var(--gold-hi);
	background:
		linear-gradient(135deg,
			color-mix(in srgb, var(--initial-ground) 86%, #000 14%) 0%,
			var(--initial-ground) 54%,
			color-mix(in srgb, var(--initial-ground) 76%, #000 24%) 100%);
	text-shadow:
		0 1px 0 var(--gold-shadow),
		0 0 6px rgba(255,238,180,.35);
	box-shadow:
		inset 0 0 0 1.5px var(--gold),
		inset 0 0 0 3px   var(--initial-ground),
		inset 0 0 0 3.75px var(--gold-keyline),
		0 1px 2px rgba(40,12,8,.42);
}

/* GRANT / DISPOSITIVE CLAUSE — the operative accolade words, centred chancery
   ("…and do hereby admit and create him a Knight of this Order, with all the
   rights, honours, and dignities thereunto belonging."). */
.sc2-scroll[data-family="crusaders_charter"] .sc2-grant {
	font-family: var(--ff-body);
	font-style: italic;
	text-align: center;
	color: var(--ink);
	font-size: var(--fs-grant);
	font-feature-settings: "onum" 1, "liga" 1;
}
.sc2-scroll[data-family="crusaders_charter"] .sc2-grant .sc2-grant__verb {
	font-variant: small-caps;
	font-style: normal;
	letter-spacing: .06em;
	color: var(--rubric);
}
.sc2-scroll[data-family="crusaders_charter"] .sc2-grant .sc2-grant__award {
	color: var(--rubric);
	font-weight: 600;
}

/* DATUM — "Given under Our hand and seal", period form, sanguine italic. */
.sc2-scroll[data-family="crusaders_charter"] .sc2-datum {
	font-family: var(--ff-body);
	font-style: italic;
	letter-spacing: .03em;
	color: var(--ink-muted);
	text-align: center;
	font-feature-settings: "onum" 1;
}

/* ATTESTATION / SIGNATURES — chancery italic over a gilt sig-rule. */
.sc2-scroll[data-family="crusaders_charter"] .sc2-attest,
.sc2-scroll[data-family="crusaders_charter"] .sc2-sig {
	font-family: var(--ff-sign);
	font-style: italic;
	color: var(--ink);
}
.sc2-scroll[data-family="crusaders_charter"] .sc2-sig__name {
	font-style: italic;
	font-size: var(--fs-attest);
	color: var(--ink);
}
.sc2-scroll[data-family="crusaders_charter"] .sc2-sig__line {
	border-top: 1px solid var(--gold-deep);   /* gilt ruled signature line       */
	box-shadow: 0 1px 0 rgba(255,244,194,.4);
}
.sc2-scroll[data-family="crusaders_charter"] .sc2-sig__title {
	font-family: var(--ff-body);
	font-style: normal;
	font-variant: small-caps;
	letter-spacing: .12em;
	color: var(--ink-muted);
	text-transform: uppercase;
	font-feature-settings: "smcp" 1;
}


/* ============================================================================
   4. HERALDRY — torse-flanked heater shields
   ----------------------------------------------------------------------------
   The arms sit in heater shields (via the --escutcheon hook → the markup's
   #sc2-escutcheon-heater clipPath), each crowned by a TORSE: a twisted wreath
   of the two livery colours (gules + argent) draped over the top edge. Kingdom
   arms flank one side, park arms the other, per the shared crown layout.
   ============================================================================ */

.sc2-scroll[data-family="crusaders_charter"] .sc2-arms {
	position: relative;
	filter: drop-shadow(0 2px 3px rgba(40,12,8,.42));
}
/* Heater-clipped escutcheon with a gilt rim + sanguine keyline, on light
   vellum so the borne arms read crisp. */
.sc2-scroll[data-family="crusaders_charter"] .sc2-arms-field,
.sc2-scroll[data-family="crusaders_charter"] .sc2-arms img,
.sc2-scroll[data-family="crusaders_charter"] .sc2-arms svg {
	-webkit-clip-path: url(#sc2-escutcheon-heater);
	        clip-path: url(#sc2-escutcheon-heater);
	background: var(--vellum-hi);
	box-shadow:
		inset 0 0 0 1px rgba(255,244,194,.5),
		0 1px 2px rgba(40,12,8,.4);
}
/* Gilt rim tracing the heater outline (drawn by the markup's rim path). */
.sc2-scroll[data-family="crusaders_charter"] .sc2-arms .sc2-arms__rim {
	fill: none;
	stroke: var(--arms-rim);
	stroke-width: 2.5;
	filter: drop-shadow(0 0 1px var(--arms-keyline));
}

/* THE TORSE — a twisted wreath of gules + argent draped over each shield's top
   edge. CSS-only via ::before so it needs no extra markup: a repeating
   diagonal gules/argent twist (the heraldic torse), arched into a shallow bar
   that sits on the shield's chief. */
.sc2-scroll[data-family="crusaders_charter"] .sc2-arms::before {
	content: "";
	position: absolute;
	left: 50%;
	top: -0.34em;
	transform: translateX(-50%);
	width: 96%;
	height: 0.5em;
	z-index: 1;
	pointer-events: none;
	border-radius: .28em / .5em;
	/* the twist: alternating gules and argent diagonal segments */
	background:
		repeating-linear-gradient(58deg,
			var(--ribbon-a) 0,    var(--ribbon-a) 7px,
			var(--ribbon-b) 7px,  var(--ribbon-b) 14px);
	box-shadow:
		inset 0  1px 0 rgba(255,255,255,.4),
		inset 0 -1px 2px rgba(40,12,8,.5),
		0 0 0 .75px var(--gold-keyline),
		0 1px 2px rgba(40,12,8,.4);
}
/* Park arms ride a touch quieter as the supporter on the flank. */
.sc2-scroll[data-family="crusaders_charter"] .sc2-arms--park {
	opacity: .97;
}
/* ARMS LABEL — sits up near the crown, OVER the gules ground (outside the
   §2b writing card), so the base ink-dark label rule is unreadable here. Switch
   the label ink to argent/parchment with a gilt fleuron divider so it reads
   bright against the red. Defensive h-pill reset + fixed label slot per the
   shared label contract (a 1- vs 2-line caption must not shove a shield off
   the baseline). */
.sc2-scroll[data-family="crusaders_charter"] .sc2-arms__label {
	font-family: var(--ff-smallcaps, var(--ff-body));
	font-variant: small-caps;
	letter-spacing: .08em;
	/* Field is light vellum (not a gules ground): gules rubric reads strong &
	   on-theme; a faint light halo keeps it crisp over any foxing.            */
	color: var(--rubric);
	-webkit-text-fill-color: var(--rubric);
	text-align: center;
	max-width: 14ch;
	min-height: 2.4em;
	margin-top: .4em;
	text-wrap: balance;
	overflow-wrap: anywhere;
	text-shadow: 0 1px 0 rgba(255,248,225,.7);   /* legibility lift on vellum     */
	/* defensive reset of the global orkui h1–h6 grey pill, in case the markup
	   ever renders the label inside a heading element */
	background: transparent;
	border: none;
	padding: 0;
	border-radius: 0;
}
/* Gilt fleuron divider above the label. */
.sc2-scroll[data-family="crusaders_charter"] .sc2-arms__label::before {
	content: "❧";
	display: block;
	margin: 0 auto .1em;
	color: var(--gold);
	-webkit-text-fill-color: var(--gold);
	font-size: .82em;
	line-height: 1;
	text-shadow: 0 1px 0 var(--gold-keyline);
}


/* ============================================================================
   5. WAX SEAL — GREEN pendant seal (charter / perpetual), gules+argent ribbons
   ----------------------------------------------------------------------------
   Green wax signalled a standing grant in fee — the right register for a
   patent of knighthood. Pressed hard, gilt-rimmed, with a hot upper-left
   catch-light and a pooled dark-green centre. Ribbon tails are the order's
   gules + argent livery.
   ============================================================================ */

.sc2-scroll[data-family="crusaders_charter"] .sc2-seal-wrap {
	filter:
		drop-shadow(0 3px 5px rgba(8,24,12,.5))
		drop-shadow(0 0 1px rgba(0,0,0,.4));
}

/* The wax disc — SVG <fill> hook if present. */
.sc2-scroll[data-family="crusaders_charter"] .sc2-seal-disc .sc2-wax-body,
.sc2-scroll[data-family="crusaders_charter"] .sc2-seal .sc2-wax-body {
	fill: var(--wax);
}
.sc2-scroll[data-family="crusaders_charter"] .sc2-seal .sc2-wax-rim {
	fill: none;
	stroke: var(--gold-deep);
	stroke-width: 2;
	filter: drop-shadow(0 1px 0 rgba(255,244,194,.45));
}
/* CSS-rendered disc fallback: green radial with gilt rim + pooled-green centre. */
.sc2-scroll[data-family="crusaders_charter"] .sc2-seal-disc {
	background:
		radial-gradient(circle at 38% 32%,
			var(--wax-hi) 0%,
			var(--wax)    36%,
			var(--wax-lo) 80%,
			#0a2814       100%);
	box-shadow:
		inset 0  2px 3px rgba(120,200,150,.32),     /* hot upper catch-light      */
		inset 0 -3px 6px rgba(0,0,0,.55),           /* pooled-centre shadow       */
		0 0 0 1.5px var(--gold-deep),               /* gilt pressed rim           */
		0 0 0 2.25px var(--gold-keyline),
		0 4px 6px rgba(8,24,12,.5);                 /* cast shadow on the sheet   */
}

/* The pressed sigil — embossed: lit upper-left, shadowed lower-right against
   the pooled green wax. */
.sc2-scroll[data-family="crusaders_charter"] .sc2-seal-sigil {
	fill: var(--wax-lo);
	color: var(--wax-lo);
	filter:
		drop-shadow(-.5px -.5px .5px rgba(150,220,175,.5))
		drop-shadow(.5px .8px .8px rgba(0,0,0,.55));
}

/* RIBBON TAILS — gules + argent livery cords pendant from the seal. */
.sc2-scroll[data-family="crusaders_charter"] .sc2-ribbon-tail--a {
	background: var(--ribbon-a);
	fill: var(--ribbon-a);
}
.sc2-scroll[data-family="crusaders_charter"] .sc2-ribbon-tail--b {
	/* argent tail: a hair of grey shading so pure-white reads as folded silk */
	background: linear-gradient(180deg, var(--ribbon-b) 0%, #d7d7d2 100%);
	fill: var(--ribbon-b);
	box-shadow: inset 0 0 0 .75px rgba(40,12,8,.18);
}
.sc2-scroll[data-family="crusaders_charter"] .sc2-seal-ribbon {
	box-shadow: inset 0 0 6px rgba(8,24,12,.4);
}


/* ============================================================================
   6. EXPORT / PRINT FLATTENING  (texture/gilt only — never structural)
   ----------------------------------------------------------------------------
   html2canvas drops background-clip:text and mask/clip-path; some PDF engines
   wobble on conic-gradient masks and color-mix. Under .sc2-export / @media
   print we fall the gilt-text title back to a SOLID order-gold (so the title
   never vanishes), drop the mask-built cross-pattée to a plain gilt pip, and
   keep all LIVERY colours. Nothing structural is touched (per the contract).
   ============================================================================ */
.sc2-scroll.sc2-export[data-family="crusaders_charter"] .sc2-title,
.sc2-export .sc2-scroll[data-family="crusaders_charter"] .sc2-title {
	background: none;
	-webkit-text-fill-color: var(--gold);
	color: var(--gold);
	-webkit-text-stroke: 0;
	text-shadow: 0 1px 0 var(--gold-keyline);
	filter: drop-shadow(0 1px 1px rgba(40,12,8,.4));
}
.sc2-scroll.sc2-export[data-family="crusaders_charter"] .sc2-illum .sc2-corner::after,
.sc2-export .sc2-scroll[data-family="crusaders_charter"] .sc2-illum .sc2-corner::after {
	-webkit-mask: none;
	        mask: none;
	border-radius: 2px;             /* fall the masked cross to a small gilt pip */
	width: 16px;
	height: 16px;
}

@media print {
	.sc2-scroll[data-family="crusaders_charter"] .sc2-title {
		background: none;
		-webkit-text-fill-color: var(--gold);
		color: var(--gold);
		-webkit-text-stroke: 0;
		text-shadow: 0 1px 0 var(--gold-keyline);
		filter: drop-shadow(0 1px 1px rgba(40,12,8,.4));
	}
	.sc2-scroll[data-family="crusaders_charter"] .sc2-illum .sc2-corner::after {
		-webkit-mask: none;
		        mask: none;
		border-radius: 2px;
		width: 16px;
		height: 16px;
	}
	/* Ensure the livery bar, gules ground, and green seal actually ink. */
	.sc2-scroll[data-family="crusaders_charter"] .sc2-illum .sc2-border__band,
	.sc2-scroll[data-family="crusaders_charter"] .sc2-seal-disc,
	.sc2-scroll[data-family="crusaders_charter"] .sc2-arms-field {
		-webkit-print-color-adjust: exact;
		print-color-adjust: exact;
	}
}

/* ===== family: astral_codex ===== */
/* ============================================================================
   THE LETTERED SCROLL  ·  FAMILY PARTIAL  ·  ASTRAL CODEX
   key: astral_codex
   ----------------------------------------------------------------------------
   "Inscribed beneath the wheeling firmament, witnessed by the fixed stars and
    the wandering lights, this codex names {them} among the constellated..."

   The one DARK-SUBSTRATE family in the fleet. Where every sibling letters dark
   ink on light vellum, Astral Codex INVERTS the field: an indigo night-sky
   "vellum" — deep void at the edges shading to a faint violet dawn at centre —
   on which the text is set in LIGHT ink, the recipient's name rubricated in
   arcane amethyst, and the gilding reads as antique-gold leaf catching
   candlelight. Gilded star BESANTS (heraldic roundels-or = stars) and faint
   CONSTELLATION lines are scattered across the field; a ZODIAC GLYPH BAND runs
   the frame; and an alchemical SIGIL is pressed into a scholarly-blue wax seal.

   This family deliberately INVERTS the project's "never pure #fff" rule into its
   own dual: never pure #000 night — the void floor is indigo (#0a0a1f), never
   black. The light ink (#f0f0f0) is the inversion's counterpart to dark-vellum
   ink and is intentional, NOT a banned #fff.

   CRITICAL — DARK→PARCHMENT FLATTEN. A night-sky substrate cannot be printed or
   PNG-exported faithfully (printers can't lay down a full-bleed indigo, and
   html2canvas mishandles the blend-mode glow). So on @media print AND under the
   exporter's explicit `.sf-export-mode` class, this family is "transcribed to
   vellum": substrate swaps to warm parchment, ink swaps to dark sepia, and every
   pure-screen night-sky ornament (star besants, constellation glow, void mist)
   is GATED OFF — while the frame, zodiac band, gilding and seal survive. See §10.

   SCOPING CONTRACT (inherited from sf-tokens.css.part):
     • Overrides ONLY palette / font / motif / escutcheon tokens and adds
       family-specific ORNAMENT selectors, all under
       .sc2-scroll[data-family="astral_codex"].
     • MUST NOT touch the z-index stack, --sheet-*, spacing/--gap-*, shadow/gild
       helper recipes, or motion (--t-*) tokens — those stay shared.
     • Nothing is keyed off html[data-theme]: the scroll carries its own night,
       independent of the app's dark mode.

   MEDIUM IS LOCKED: HTML + CSS + inline SVG. No <canvas>, no tiled photos, no
   flat #ffd700 (gold is ALWAYS the antique-gold ramp / gild recipe).
   ============================================================================ */

/* ============================================================================
   1 · PALETTE  ·  the night-sky token ramp (+ a transcription-to-vellum swap)
   ----------------------------------------------------------------------------
   The substrate trio is the INVERTED case: --vellum is the deep void floor,
   --vellum-hi the faint violet glow toward centre, --vellum-lo the near-black
   outer void. The ink ramp is LIGHT (the inversion). The gold is antique leaf,
   the rubric an arcane amethyst, the wax scholarly blue.
   ============================================================================ */
.sc2-scroll[data-family="astral_codex"] {

	/* ── SUBSTRATE: indigo night-sky "vellum" (the dark inversion) ────────────
	   --vellum-hi is the CENTRE here (radial dawn glow); --vellum-lo the deep
	   outer void. Never pure #000 — the floor is indigo. */
	--vellum:            #0a0a1f;   /* base void-field body                       */
	--vellum-hi:         #14122e;   /* faint violet centre glow (radial)          */
	--vellum-lo:         #050510;   /* deepest outer void (edge)                  */
	--grime:             rgba(8,6,24,.55);    /* edge void-deepening vignette     */
	--foxing:            #2a2752;   /* nebular mottle (used at low alpha)         */
	--ruling:            #2c2a4e;   /* faint celestial ruling / pricking lines    */
	--curl-shadow:       rgba(2,2,10,.6);     /* cast shadow under any curl       */

	/* ── INK: LIGHT — the inversion's body ink (NOT a banned #fff) ──────────── */
	--ink:               #f0f0f0;   /* light star-ink body text                   */
	--ink-muted:         #b9b6d6;   /* muted lavender-grey labels / sig titles    */
	--rubric:            #c9a0ff;   /* arcane amethyst rubric — the name glows    */

	/* ── GILDING: antique gold leaf catching candlelight (always the ramp) ──── */
	--gold:              #b8860b;   /* antique body gold                          */
	--gold-hi:           #f0d890;   /* warm specular catch-light                  */
	--gold-deep:         #8a6914;   /* lower gold shade                           */
	--gold-shadow:       #4a3a08;   /* darkest gold stop                          */
	--gold-keyline:      #4a3a08;   /* dark recess line — sells "raised" on void  */

	/* ── BORDER / FRAME: deep amethyst-night field for the zodiac band ──────── */
	--border:            #3d1f4e;   /* arcane violet bar-border field             */
	--rule-fine:         #6a5a2a;   /* gilt-leaning hairline outer rule           */
	--initial-ground:    #3d1f4e;   /* drop-cap decorated-box ground (amethyst)   */

	/* ── ACCENT: the celestial gold/amethyst used for stars & constellations ── */
	--accent:            #b8860b;   /* secondary ornament accent (besant gold)    */
	--accent-soft:       rgba(184,134,11,.26);   /* washed gold (band fill)       */
	--accent-star:       #f0d890;   /* gilded star-besant core (family-local)     */
	--accent-star-rim:   #8a6914;   /* star-besant rim shade (family-local)       */
	--accent-constel:    rgba(201,160,255,.5);   /* constellation line (amethyst) */
	--accent-glow:       rgba(201,160,255,.28);  /* soft amethyst halo glow       */

	/* ── WAX SEAL: scholarly BLUE wax (the astronomer's seal) ───────────────── */
	--wax:               #2a3d63;   /* scholarly-blue wax body                    */
	--wax-hi:            #4a5d83;   /* upper-left catch-light                      */
	--wax-lo:            #16223c;   /* pooled centre / rim                        */
	--ribbon-a:          #2a3d63;   /* livery colour ribbon (scholar blue)        */
	--ribbon-b:          #b8860b;   /* livery metal ribbon (antique gold)         */

	/* ── HERALDRY: a celestial roundel achievement, gilt-rimmed ─────────────── */
	--escutcheon:        roundel;
	--arms-rim:          var(--gold);
	--arms-keyline:      #2a1c34;

	/* ── TYPOGRAPHY: MedievalSharp title (rough hand); EB Garamond body/sign ── */
	--ff-title:          var(--ff-title-rough);   /* → "MedievalSharp" stack      */
	--ff-body:           "EB Garamond","Cardo","IM Fell English",Garamond,Georgia,serif;
	--ff-sign:           "EB Garamond","Cardo","IM Fell English",serif; /* italic */
	--ff-versal:         "MedievalSharp","EB Garamond",serif;

	/* ── MOTIF DATA HOOK: read by illumination engine ───────────────────────── */
	--motif:             "celestial-zodiac";

	/* ── FAMILY-LOCAL TUNING (cosmetic only; never layout) ───────────────────
	   MedievalSharp is hand-carved; a hair of air reads as ink on starlit vellum. */
	--ls-title:          .015em;
}

/* ============================================================================
   2 · TITLE  ·  gilded display, glowing on the void
   ----------------------------------------------------------------------------
   On a dark field the title cannot rely on a cast shadow to read "raised" — the
   page behind it is already dark. Instead the gilt text gets a warm OUTER GLOW
   (an aureole of candlelit gold) plus the locked gild gradient + keyline stroke.
   Title only — display faces are unreadable at body size.
   ============================================================================ */
.sc2-scroll[data-family="astral_codex"] .sc2-title {
	font-family: var(--ff-title);
	font-weight: 400;
	letter-spacing: var(--ls-title);
	line-height: 1.0;
	/* gilt text recipe (shared) */
	background: var(--gild-gradient);
	-webkit-background-clip: text;
	        background-clip: text;
	color: transparent;
	-webkit-text-stroke: var(--gild-text-stroke);
	/* on the void: a candlelit aureole + a faint amethyst halo, no dark drop */
	filter:
		drop-shadow(0 1px 0 var(--gold-hi))
		drop-shadow(0 0 10px rgba(240,216,144,.35))
		drop-shadow(0 0 18px var(--accent-glow));
}

/* Invocation: the astronomer's opening, in muted amethyst small-caps. */
.sc2-scroll[data-family="astral_codex"] .sc2-invocation {
	font-family: var(--ff-smallcaps);
	letter-spacing: var(--ls-invocation);
	color: var(--rubric);
	text-transform: uppercase;
	text-shadow: 0 0 6px var(--accent-glow);
}

/* Intitulation small-caps in muted lavender-grey, old-style figures. */
.sc2-scroll[data-family="astral_codex"] .sc2-intitulation {
	font-family: var(--ff-smallcaps);
	letter-spacing: var(--ls-intitulation);
	color: var(--ink-muted);
	font-feature-settings: "smcp" 1, "onum" 1;
}

/* ============================================================================
   3 · BODY / RUBRIC  ·  light ink on the night-field
   ----------------------------------------------------------------------------
   Justified humanist body in the LIGHT ink. The recipient name rubric is the
   arcane amethyst and the only text that GLOWS — the eye's anchor in the dark.
   ============================================================================ */
.sc2-scroll[data-family="astral_codex"] .sc2-body {
	font-family: var(--ff-body);
	color: var(--ink);
	text-align: justify;
	text-justify: inter-word;
	hyphens: auto;
	font-feature-settings: "liga" 1, "onum" 1, "kern" 1;
}

/* Recipient name / section openers in amethyst rubric with an arcane halo. */
.sc2-scroll[data-family="astral_codex"] .sc2-rubric,
.sc2-scroll[data-family="astral_codex"] .sc2-body .sc2-rubric,
.sc2-scroll[data-family="astral_codex"] .sc2-grant__award,
.sc2-scroll[data-family="astral_codex"] .sc2-grant strong {
	color: var(--rubric);
	text-shadow:
		0 0 6px var(--accent-glow),
		0 0 14px rgba(201,160,255,.2);
	font-feature-settings: "onum" 1, "liga" 1;
}

/* ============================================================================
   4 · SUBSTRATE FLAVOUR  ·  the night sky (SCREEN-ONLY)
   ----------------------------------------------------------------------------
   The shared substrate engine reads the family --vellum* tokens to paint the
   indigo radial field. Here we layer the family signature ON TOP, all as a
   single extra overlay on .sc2-vellum::after so the z-order is untouched:
     • a soft nebular violet mist (low, asymmetric pools), and
     • a scatter of faint distant stars (tiny gilt/white points).
   This is PURE-SCREEN night ornament — §10 gates it off for print/export so the
   transcribed-to-vellum version stays clean parchment.
   ============================================================================ */
.sc2-scroll[data-family="astral_codex"] .sc2-vellum::after {
	content: "";
	position: absolute;
	inset: 0;
	pointer-events: none;
	/* nebular mist (screen-blend so it glows on the void) + a faint star dust */
	background-image:
		radial-gradient(40% 32% at 24% 18%, rgba(120,90,200,.18), transparent 70%),
		radial-gradient(34% 30% at 80% 28%, rgba(80,120,200,.12),  transparent 72%),
		radial-gradient(36% 34% at 66% 78%, rgba(150,100,210,.14),  transparent 72%),
		/* fine distant-star dust — a sparse hand-placed scatter, not a tile */
		radial-gradient(1.4px 1.4px at 14% 22%, rgba(240,240,255,.9), transparent 60%),
		radial-gradient(1.2px 1.2px at 38% 12%, rgba(240,216,144,.8), transparent 60%),
		radial-gradient(1px 1px   at 58% 30%, rgba(240,240,255,.7), transparent 60%),
		radial-gradient(1.6px 1.6px at 72% 16%, rgba(240,240,255,.85), transparent 60%),
		radial-gradient(1.2px 1.2px at 86% 40%, rgba(240,216,144,.75), transparent 60%),
		radial-gradient(1px 1px   at 22% 52%, rgba(240,240,255,.7), transparent 60%),
		radial-gradient(1.4px 1.4px at 48% 64%, rgba(240,240,255,.8), transparent 60%),
		radial-gradient(1.2px 1.2px at 78% 70%, rgba(240,216,144,.7), transparent 60%),
		radial-gradient(1px 1px   at 32% 84%, rgba(240,240,255,.7), transparent 60%),
		radial-gradient(1.5px 1.5px at 64% 90%, rgba(240,240,255,.8), transparent 60%);
	mix-blend-mode: screen;   /* glow ON the void rather than darken              */
	opacity: .95;
}

/* ── Gilded star-BESANTS + constellation lines (SCREEN-ONLY) ─────────────────
   The defining field ornament: larger heraldic roundels-or (besants) standing
   for named stars, joined by faint amethyst constellation lines. Drawn as one
   positioned inline-SVG data-URI on .sc2-illum::after so it sits in the illum
   layer (no z override) and survives without blend-mode dependence. Gated in §10.
   Coordinates trace a loose, asymmetric "constellation" — never a regular grid. */
.sc2-scroll[data-family="astral_codex"] .sc2-illum::after {
	content: "";
	position: absolute;
	inset: var(--margin-frame);
	z-index: 0;                       /* within --z-illum only                    */
	pointer-events: none;
	background-repeat: no-repeat;
	background-position: center;
	background-size: cover;
	background-image:
		url("data:image/svg+xml;utf8,\
<svg xmlns='http://www.w3.org/2000/svg' width='420' height='560' viewBox='0 0 420 560' preserveAspectRatio='none'>\
<g stroke='%23c9a0ff' stroke-width='1' stroke-opacity='.45' fill='none' stroke-linecap='round'>\
<path d='M70 90 L150 60 L230 120 L300 80'/>\
<path d='M340 200 L300 80'/>\
<path d='M90 300 L160 360 L120 440 L210 470'/>\
<path d='M210 470 L300 420 L360 480'/>\
<path d='M260 240 L340 200 L380 300'/>\
</g>\
<g fill='%23f0d890' stroke='%238a6914' stroke-width='.8'>\
<circle cx='70' cy='90' r='4.5'/><circle cx='150' cy='60' r='6'/>\
<circle cx='230' cy='120' r='4'/><circle cx='300' cy='80' r='5'/>\
<circle cx='340' cy='200' r='5.5'/><circle cx='380' cy='300' r='4'/>\
<circle cx='260' cy='240' r='4.5'/><circle cx='90' cy='300' r='5'/>\
<circle cx='160' cy='360' r='4'/><circle cx='120' cy='440' r='5.5'/>\
<circle cx='210' cy='470' r='6'/><circle cx='300' cy='420' r='4.5'/>\
<circle cx='360' cy='480' r='5'/>\
</g>\
<g fill='%23f0d890' fill-opacity='.5'>\
<circle cx='150' cy='60' r='11'/><circle cx='210' cy='470' r='11'/>\
<circle cx='340' cy='200' r='9'/><circle cx='120' cy='440' r='9'/>\
</g>\
</svg>");
	opacity: .9;
}

/* ============================================================================
   5 · ILLUMINATION BORDER  ·  the ZODIAC GLYPH band + star-pattern frame
   ----------------------------------------------------------------------------
   The frame's signature is a ZODIAC GLYPH BAND: zodiac sigils set in antique
   gold along a deep-amethyst field bar, edged by a gilt rule, with gilded star
   bosses at the corners (a star-pattern frame). The shared border SVG draws the
   geometry; these rules colour its parts and the band carries the glyph tile.
   The band fill + glyphs are BAKED data-URIs (print/export-safe).
   ============================================================================ */

/* Frame colour hooks consumed by the shared border SVG */
.sc2-scroll[data-family="astral_codex"] .sc2-illum {
	color: var(--gold);                          /* foliate currentColor → gild   */
}
.sc2-scroll[data-family="astral_codex"] .sc2-border .sc2-border__rule {
	stroke: var(--gold);
	stroke-width: 1.25;
	fill: none;
	filter: drop-shadow(0 0 2px rgba(240,216,144,.4));
}
.sc2-scroll[data-family="astral_codex"] .sc2-border .sc2-border__bar {
	/* the deep-amethyst field bar the zodiac glyphs ride on */
	fill: var(--border);
	stroke: var(--gold-keyline);
	stroke-width: .5;
}
.sc2-scroll[data-family="astral_codex"] .sc2-border .sc2-border__band {
	fill: var(--accent-soft);                    /* faint gold wash behind glyphs */
}
.sc2-scroll[data-family="astral_codex"] .sc2-border .sc2-border__band[data-sc2-band] {
	/* gilt glyph strokes within the band geometry */
	stroke: var(--gold);
	fill: var(--gold);
}
.sc2-scroll[data-family="astral_codex"] .sc2-border .sc2-border__corners[data-sc2-corners] {
	/* gilded star bosses at each corner of the star-pattern frame */
	fill: var(--gold);
	stroke: var(--gold-keyline);
	stroke-width: .6;
	filter: var(--gild-drop);
}

/* The deep-amethyst illum bar, candlelit-gilt edged (works on the void). */
.sc2-scroll[data-family="astral_codex"] .sc2-illum .sc2-bar {
	background: var(--border);
	box-shadow:
		inset 0 0 0 1px var(--gold-keyline),
		inset 0 1px 0 rgba(240,216,144,.16);
	border-radius: 2px;
}

/* ── The ZODIAC GLYPH BAND, drawn as a tiling inline-SVG along the frame ──────
   Antique-gold zodiac sigils (abstracted to clean glyph-strokes) march along a
   deep-amethyst band, separated by small star pips. Backed on .sc2-illum::before
   so it runs all four sides, masked to a hollow rectangle so the centre stays
   clear for text. Baked data-URI → survives html2canvas and print unmodified. */
.sc2-scroll[data-family="astral_codex"] .sc2-illum::before {
	content: "";
	position: absolute;
	inset: var(--margin-frame);
	z-index: 1;                       /* within --z-illum, above the field bar    */
	pointer-events: none;
	background-image:
		url("data:image/svg+xml;utf8,\
<svg xmlns='http://www.w3.org/2000/svg' width='240' height='40' viewBox='0 0 240 40'>\
<g fill='none' stroke='%23b8860b' stroke-width='2.2' stroke-linecap='round' stroke-linejoin='round'>\
<path d='M14 14 q-6 -8 -10 0 M24 14 q6 -8 10 0 M19 14 v12'/>\
<path d='M52 22 q-6 -10 6 -10 t6 10 q4 6 8 0 M52 22 q-2 6 4 6'/>\
<path d='M88 10 v20 M100 10 v20 M84 14 h20 M84 26 h20'/>\
<path d='M120 12 a8 8 0 1 0 .1 0 M126 12 a8 8 0 1 0 .1 0'/>\
<path d='M156 12 c-10 2 -10 14 0 16 M168 12 c10 2 10 14 0 16'/>\
<path d='M192 10 c-8 0 -12 8 -6 14 l8 8 M198 30 q4 -6 -2 -10'/>\
</g>\
<g fill='%23f0d890'>\
<circle cx='38' cy='20' r='1.6'/><circle cx='74' cy='20' r='1.6'/>\
<circle cx='110' cy='20' r='1.6'/><circle cx='142' cy='20' r='1.6'/>\
<circle cx='178' cy='20' r='1.6'/><circle cx='218' cy='20' r='1.6'/>\
</g>\
<g fill='none' stroke='%23b8860b' stroke-width='2.2' stroke-linecap='round'>\
<path d='M214 30 l6 -20 6 20 M216 22 h12'/>\
</g>\
</svg>");
	background-repeat: repeat;
	background-size: 240px 40px;
	/* show only along the frame edges (hollow-rect mask) so centre stays clear */
	-webkit-mask:
		linear-gradient(#000 0 0) padding-box,
		linear-gradient(#000 0 0);
	-webkit-mask-composite: xor;
	        mask-composite: exclude;
	padding: var(--band-w);
	opacity: .95;
}

/* ── Star bosses at the four corners (the star-pattern frame's nodes) ────────
   A gilded eight-point star pressed into each corner where the band turns.
   Family-local .sc2-corner nodes (markup may place them; inert if absent). */
.sc2-scroll[data-family="astral_codex"] .sc2-illum .sc2-corner {
	position: absolute;
	width: var(--corner-size);
	height: var(--corner-size);
	z-index: 2;
	pointer-events: none;
	background-repeat: no-repeat;
	background-position: center;
	background-size: contain;
	background-image:
		url("data:image/svg+xml;utf8,\
<svg xmlns='http://www.w3.org/2000/svg' width='72' height='72' viewBox='0 0 72 72'>\
<g transform='translate(36 36)'>\
<path d='M0 -26 L6 -6 26 0 6 6 0 26 -6 6 -26 0 -6 -6 Z' fill='%23f0d890' stroke='%238a6914' stroke-width='1'/>\
<path d='M0 -16 L11 -11 16 0 11 11 0 16 -11 11 -16 0 -11 -11 Z' fill='%23b8860b' fill-opacity='.55'/>\
<circle cx='0' cy='0' r='3.5' fill='%23f0d890'/>\
</g>\
</svg>");
	filter: drop-shadow(0 0 4px rgba(240,216,144,.4));
}
.sc2-scroll[data-family="astral_codex"] .sc2-illum .sc2-corner--tl { top: var(--margin-frame); left:  var(--margin-frame); }
.sc2-scroll[data-family="astral_codex"] .sc2-illum .sc2-corner--tr { top: var(--margin-frame); right: var(--margin-frame); }
.sc2-scroll[data-family="astral_codex"] .sc2-illum .sc2-corner--bl { bottom: var(--margin-frame); left:  var(--margin-frame); }
.sc2-scroll[data-family="astral_codex"] .sc2-illum .sc2-corner--br { bottom: var(--margin-frame); right: var(--margin-frame); }

/* ============================================================================
   6 · ILLUMINATED VERSAL  ·  amethyst night-box with an interior star-glow
   ----------------------------------------------------------------------------
   The opening word's first letter sits in a deep-amethyst decorated box lit by
   an interior star-glow, with a gilt double keyline. The letter is hot-gold.
   The body's first <p> is the versal (data-sc2-versal hook on .sc2-body).
   ============================================================================ */
.sc2-scroll[data-family="astral_codex"] .sc2-body > p:first-of-type::first-letter,
.sc2-scroll[data-family="astral_codex"] .sc2-body[data-sc2-versal] > p:first-of-type::first-letter,
.sc2-scroll[data-family="astral_codex"] .sc2-versal {
	font-family: var(--ff-versal);
	color: var(--gold-hi);
	-webkit-text-fill-color: var(--gold-hi);
	/* the box: amethyst night ground with an interior star-glow */
	background:
		radial-gradient(120% 120% at 30% 22%,
			color-mix(in srgb, var(--initial-ground) 70%, #6a4f9a 30%) 0%,
			var(--initial-ground) 52%,
			color-mix(in srgb, var(--initial-ground) 70%, #000 30%) 100%);
	text-shadow:
		0 1px 0 var(--gold-shadow),
		0 0 8px rgba(240,216,144,.4),
		0 0 14px var(--accent-glow);
	box-shadow:
		inset 0 0 0 1.5px var(--gold),
		inset 0 0 0 3px var(--initial-ground),
		inset 0 0 0 3.75px var(--gold-keyline),
		0 0 10px rgba(201,160,255,.25);
	border-radius: 3px;
	/* hug the (now sane, ~3-line) glyph so the amethyst ground reads as a tight
	   ground, not a panel — bounded padding only; NO font-size override here
	   (size discipline is inherited from the shared sf-typography versal rule). */
	padding: .04em .12em;
}

/* ============================================================================
   7 · GRANT / DATUM / ATTEST  ·  arcane register cues
   ----------------------------------------------------------------------------
   The dispositive clause reads as a centred incantation; the date-and-place in
   muted lavender small-caps; signatures in EB Garamond italic light-ink.
   ============================================================================ */
.sc2-scroll[data-family="astral_codex"] .sc2-grant {
	font-family: var(--ff-body);
	font-style: italic;
	text-align: center;
	color: var(--ink);
	font-feature-settings: "onum" 1, "liga" 1;
}
.sc2-scroll[data-family="astral_codex"] .sc2-grant__verb {
	color: var(--ink-muted);
}
.sc2-scroll[data-family="astral_codex"] .sc2-datum {
	font-family: var(--ff-smallcaps);
	letter-spacing: .04em;
	color: var(--ink-muted);
	text-align: center;
	font-feature-settings: "smcp" 1, "onum" 1;
}
.sc2-scroll[data-family="astral_codex"] .sc2-attest,
.sc2-scroll[data-family="astral_codex"] .sc2-sig {
	font-family: var(--ff-sign);
	font-style: italic;
	color: var(--ink);
}
.sc2-scroll[data-family="astral_codex"] .sc2-sig__line {
	/* the ruled line a signatory rests upon — gilt, faintly aglow on the void */
	border-top: 1px solid var(--gold-deep);
	box-shadow: 0 0 4px rgba(240,216,144,.3);
}
.sc2-scroll[data-family="astral_codex"] .sc2-sig__name {
	color: var(--ink);
}
.sc2-scroll[data-family="astral_codex"] .sc2-sig__title {
	font-family: var(--ff-smallcaps);
	font-style: normal;
	letter-spacing: .12em;
	color: var(--ink-muted);
	text-transform: uppercase;
	font-feature-settings: "smcp" 1;
}

/* ============================================================================
   8 · HERALDRY  ·  celestial roundel achievement
   ----------------------------------------------------------------------------
   The escutcheon token is 'roundel' (a star-disc rather than a heater). Here we
   give the arms a gilt rim with a candlelit aureole and a faint amethyst ring,
   readable against the void. The arms field keeps its own art; we theme the rim.
   ============================================================================ */
.sc2-scroll[data-family="astral_codex"] .sc2-arms,
.sc2-scroll[data-family="astral_codex"] .sc2-arms--kingdom,
.sc2-scroll[data-family="astral_codex"] .sc2-arms--park {
	filter:
		drop-shadow(0 1px 0 var(--gold-hi))
		drop-shadow(0 0 8px rgba(240,216,144,.35));
}
.sc2-scroll[data-family="astral_codex"] .sc2-arms img,
.sc2-scroll[data-family="astral_codex"] .sc2-arms svg,
.sc2-scroll[data-family="astral_codex"] .sc2-arms-field {
	border: 2.5px solid var(--arms-rim);
	outline: 1px solid var(--arms-keyline);
	box-shadow:
		inset 0 0 0 1px rgba(240,216,144,.5),
		0 0 10px rgba(201,160,255,.22);
	background: var(--vellum-hi);
}
/* On the void field the muted lavender-grey label sinks into the dark; switch
   the ink to the LIGHT star-ink so the caption reads under each shield, and let
   the gilt fleuron divider catch candlelight. Inherits the shared centered /
   small-caps / min-height-slot / h-pill-reset disciplines from the base
   sf-heraldry-seal rule; here we only correct ink + divider colour for the void. */
.sc2-scroll[data-family="astral_codex"] .sc2-arms__label {
	font-family: var(--ff-smallcaps);
	letter-spacing: .1em;
	color: var(--ink);                 /* light star-ink — legible on the void      */
	text-transform: uppercase;
	text-shadow: 0 0 6px rgba(10,10,31,.7);   /* faint void halo lifts it off field */
}
.sc2-scroll[data-family="astral_codex"] .sc2-arms__label::before {
	color: var(--gold-hi);             /* gilt fleuron divider, candlelit on void   */
}
/* A faint amethyst ring orbiting each shield (the celestial achievement). */
.sc2-scroll[data-family="astral_codex"] .sc2-arms .sc2-arms-ring {
	stroke: var(--rubric);
	stroke-width: 1.5;
	fill: none;
	opacity: .6;
}
/* The crown above the achievement reads as gilt with a star-glow. */
.sc2-scroll[data-family="astral_codex"] .sc2-crown {
	color: var(--gold);
	filter:
		drop-shadow(0 1px 0 var(--gold-hi))
		drop-shadow(0 0 6px rgba(240,216,144,.4));
}

/* ============================================================================
   9 · WAX SEAL  ·  scholarly-blue wax, an alchemical SIGIL pressed in
   ----------------------------------------------------------------------------
   The astronomer's seal: scholarly-blue wax with a gilt rim, livery ribbon
   tails in blue + gold, and an embossed ARCANE SIGIL (an alchemical/astral
   glyph) pressed into the wax. When no player device exists the markup carries
   a data-monogram on .sc2-seal-sigil; either way the sigil reads embossed.
   ============================================================================ */
.sc2-scroll[data-family="astral_codex"] .sc2-seal-disc {
	fill: var(--wax);
}
.sc2-scroll[data-family="astral_codex"] .sc2-seal-wrap {
	filter:
		drop-shadow(0 2px 4px rgba(6,10,24,.6))
		drop-shadow(0 0 2px rgba(0,0,0,.4));
}
.sc2-scroll[data-family="astral_codex"] .sc2-seal-disc .sc2-wax-body { fill: var(--wax); }
.sc2-scroll[data-family="astral_codex"] .sc2-seal-disc .sc2-wax-rim {
	fill: none;
	stroke: var(--gold-deep);
	stroke-width: 2;
	filter: drop-shadow(0 1px 0 rgba(240,216,144,.45));
}
.sc2-scroll[data-family="astral_codex"] .sc2-seal-disc .sc2-wax-hi { fill: var(--wax-hi); }
.sc2-scroll[data-family="astral_codex"] .sc2-seal-disc .sc2-wax-lo { fill: var(--wax-lo); }

/* The embossed arcane sigil: lit upper-left, shadowed lower-right in the wax. */
.sc2-scroll[data-family="astral_codex"] .sc2-seal-sigil {
	fill: var(--wax-lo);
	color: var(--wax-lo);                 /* drives currentColor glyph strokes    */
	filter:
		drop-shadow(-.5px -.5px .5px rgba(120,150,210,.55))
		drop-shadow(.5px .8px .8px rgba(0,0,0,.55));
}
.sc2-scroll[data-family="astral_codex"] .sc2-seal-sigil .sc2-seal-sigil-hi {
	fill: var(--wax-hi);
	opacity: .6;
}
/* Monogram fallback (no player device): centre the data-monogram in scholar
   blue, with the same embossed feel. */
.sc2-scroll[data-family="astral_codex"] .sc2-seal-sigil[data-monogram] {
	font-family: var(--ff-versal);
	fill: var(--wax-lo);
	-webkit-text-fill-color: var(--wax-lo);
}

/* Ribbon tails: scholar-blue + antique-gold livery. */
.sc2-scroll[data-family="astral_codex"] .sc2-seal-ribbon { fill: var(--ribbon-a); background: var(--ribbon-a); }
.sc2-scroll[data-family="astral_codex"] .sc2-ribbon-tail--a { fill: var(--ribbon-a); background: var(--ribbon-a); }
.sc2-scroll[data-family="astral_codex"] .sc2-ribbon-tail--b { fill: var(--ribbon-b); background: var(--ribbon-b); }

/* CSS-only seal fallback, themed scholar-blue with an embossed sigil. */
.sc2-scroll[data-family="astral_codex"] .sc2-seal-wrap .sc2-seal--css {
	background:
		radial-gradient(120% 120% at 32% 26%, var(--wax-hi) 0%, var(--wax) 46%, var(--wax-lo) 100%);
	box-shadow:
		inset 0 2px 5px rgba(60,80,130,.5),
		inset 0 -3px 6px rgba(8,14,30,.65),
		0 4px 12px rgba(6,10,24,.55);
}
.sc2-scroll[data-family="astral_codex"] .sc2-seal-wrap .sc2-seal--css::after {
	content: "";
	position: absolute;
	inset: 24%;
	background:
		url("data:image/svg+xml;utf8,\
<svg xmlns='http://www.w3.org/2000/svg' width='40' height='40' viewBox='0 0 40 40'>\
<g fill='none' stroke='%2316223c' stroke-width='1.6' stroke-linecap='round'>\
<circle cx='20' cy='20' r='13'/>\
<path d='M20 7 L20 33 M7 20 L33 20'/>\
<path d='M13 13 q7 -6 14 0 M13 27 q7 6 14 0'/>\
<circle cx='20' cy='20' r='3'/>\
</g>\
</svg>") center / contain no-repeat;
	opacity: .85;
}

/* ============================================================================
   10 · TRANSCRIPTION TO VELLUM  ·  print + .sf-export-mode flatten
   ----------------------------------------------------------------------------
   The dark night-sky cannot print and html2canvas mishandles the screen-blend
   glow. Both @media print AND the exporter's explicit .sf-export-mode class
   "transcribe the codex to vellum": warm parchment substrate, dark sepia ink,
   and every PURE-SCREEN night ornament (star dust, nebular mist, star besants,
   constellation glow) GATED OFF. The zodiac glyph band, the gilt frame, the
   corner star bosses and the seal sigil are baked data-URIs that survive —
   so the printed/exported scroll reads as a gilt-framed parchment diploma.

   Both selectors carry the SAME values so the PNG matches the print exactly.
   ============================================================================ */

/* — Substrate + ink swap (print path) — */
@media print {
	.sc2-scroll[data-family="astral_codex"] {
		--vellum:        #f4ead0;   /* warm parchment body                        */
		--vellum-hi:     #fbf3dd;   /* lightest centre                            */
		--vellum-lo:     #e2d2a8;   /* aged edge                                  */
		--ink:           #1c1810;   /* dark sepia body ink                        */
		--ink-muted:     #4a3a28;   /* muted sepia labels / sig titles            */
		--rubric:        #6a2f9a;   /* amethyst darkened to read on parchment     */
		--initial-ground:#3d1f4e;   /* keep the amethyst initial box              */
	}
}
/* — Substrate + ink swap (export path — MIRRORS the print values exactly) — */
.sc2-scroll.sf-export-mode[data-family="astral_codex"] {
	--vellum:        #f4ead0;
	--vellum-hi:     #fbf3dd;
	--vellum-lo:     #e2d2a8;
	--ink:           #1c1810;
	--ink-muted:     #4a3a28;
	--rubric:        #6a2f9a;
	--initial-ground:#3d1f4e;
}

/* — Gate OFF the pure-screen night-sky ornament + glows (print path) — */
@media print {
	.sc2-scroll[data-family="astral_codex"] .sc2-vellum::after,
	.sc2-scroll[data-family="astral_codex"] .sc2-illum::after {
		display: none !important;     /* star dust, nebular mist, star besants     */
	}
	/* drop the screen-only glows so text/title read as clean ink-on-parchment */
	.sc2-scroll[data-family="astral_codex"] .sc2-title {
		background: none;
		-webkit-text-fill-color: var(--gold);
		color: var(--gold);
		-webkit-text-stroke: 0;
		text-shadow: 0 1px 0 var(--gold-keyline);
		filter: drop-shadow(0 1px 1px rgba(40,30,4,.4));
	}
	.sc2-scroll[data-family="astral_codex"] .sc2-rubric,
	.sc2-scroll[data-family="astral_codex"] .sc2-body .sc2-rubric,
	.sc2-scroll[data-family="astral_codex"] .sc2-grant__award,
	.sc2-scroll[data-family="astral_codex"] .sc2-invocation,
	.sc2-scroll[data-family="astral_codex"] .sc2-arms__label {
		text-shadow: none;            /* drop the void-halo once on parchment      */
	}
}
/* — Gate OFF the pure-screen night-sky ornament + glows (export path) — */
.sc2-scroll.sf-export-mode[data-family="astral_codex"] .sc2-vellum::after,
.sc2-scroll.sf-export-mode[data-family="astral_codex"] .sc2-illum::after {
	display: none !important;
}
.sc2-scroll.sf-export-mode[data-family="astral_codex"] .sc2-title {
	background: none;
	-webkit-text-fill-color: var(--gold);
	color: var(--gold);
	-webkit-text-stroke: 0;
	text-shadow: 0 1px 0 var(--gold-keyline);
	filter: drop-shadow(0 1px 1px rgba(40,30,4,.4));
}
.sc2-scroll.sf-export-mode[data-family="astral_codex"] .sc2-rubric,
.sc2-scroll.sf-export-mode[data-family="astral_codex"] .sc2-body .sc2-rubric,
.sc2-scroll.sf-export-mode[data-family="astral_codex"] .sc2-grant__award,
.sc2-scroll.sf-export-mode[data-family="astral_codex"] .sc2-invocation,
.sc2-scroll.sf-export-mode[data-family="astral_codex"] .sc2-arms__label {
	text-shadow: none;
}

/* ===== inlined: sf-print.css.part ===== */
/* ============================================================================
   THE LETTERED SCROLL — sf-print.css.part
   ----------------------------------------------------------------------------
   PRINT / PDF + PNG-EXPORT layer for the HTML/CSS/inline-SVG scroll renderer.

   RESPONSIBILITIES (this file owns these and ONLY these):
     1. @media print — isolate the scroll. Hide ALL app + panel chrome so a
        browser "Print → Save as PDF" shows ONLY the lettered sheet, full-bleed,
        at correct US-Letter page size, with no UI, no felt backdrop, no shadows.
     2. @page setup — Letter, zero printer margin (the sheet supplies its own
        generous --margin-frame so the ornament breathes; we do NOT want the
        printer to add a second white margin around our vellum).
     3. .sf-export-mode — a class the PNG exporter toggles on <body> (or on the
        .sc2-app root) immediately before an html2canvas capture, then removes.
        It produces a pixel-faithful, chrome-free, animation-frozen capture and
        swaps the renderer's fragile screen-only effects (feDisplacementMap
        deckle mask, background-clip:text gilt) for flattened equivalents that
        rasterise reliably.

   WHAT THIS FILE DOES NOT TOUCH (other partials own these):
     • palette / font / motif TOKENS  → sf-tokens.css.part
     • substrate texture, screen deckle, foxing → sf-substrate.css.part
     • border bands, corners, versal, gilt recipes → sf-illumination.css.part
     • the lettered text hierarchy → sf-typography.css.part
     • heraldry achievement + wax seal → sf-heraldry-seal.css.part
   We only RE-POINT a small, well-known set of those at print/export time. Every
   selector here is defensive: if a hook is absent, the rule is simply inert.

   MEDIUM IS LOCKED: no <canvas>. Print + export must match the screen sheet.

   EXPORT-CLASS COMPATIBILITY (locked): the design spec names the capture class
   `.sc2-export`; this file's role brief names it `.sf-export-mode`. We honour
   BOTH so whichever the export engineer toggles, the flattening fires. They are
   listed together on every rule below.
   ============================================================================ */


/* ===========================================================================
   1 · COLOR FIDELITY — both print and screen-capture
   ---------------------------------------------------------------------------
   Browsers strip background colors/images when printing by default. The whole
   scroll IS its substrate + gilding backgrounds, so we MUST force them through.
   This is the single most important rule in the file: without it the sheet
   prints as white paper with black text — the exact "web certificate" failure
   the North Star forbids.
   =========================================================================== */
@media print {
	.sc2-app,
	.sc2-app * {
		-webkit-print-color-adjust: exact !important;   /* Chrome/Safari */
		print-color-adjust:         exact !important;   /* spec / Firefox */
		color-adjust:               exact !important;   /* legacy alias  */
	}
}


/* ===========================================================================
   2 · @page — US Letter, no printer margin
   ---------------------------------------------------------------------------
   Portrait by default. A landscape family (Imperial / Crusader / Astral may
   flip --aspect to 11/8.5) is handled by the orientation rules in §4. We zero
   the @page margin because the sheet provides its own internal --margin-frame;
   a printer margin would double it and shrink the vellum.
   =========================================================================== */
@page {
	size:   Letter portrait;
	margin: 0;
}
@page sc2-landscape {
	size:   Letter landscape;
	margin: 0;
}


/* ===========================================================================
   3 · @media print — ISOLATE THE SCROLL
   ---------------------------------------------------------------------------
   Strategy: blank the document, hide everything, then re-show ONLY the scroll
   subtree and lift the .sc2-scroll to fill the printable page. We avoid the
   brittle `body > * { display:none }` sledgehammer (it nukes ancestors the
   scroll needs) and instead hide named chrome + use visibility on the wrapper
   so the scroll's own stacking context survives intact.
   =========================================================================== */
@media print {

	/* -- 3a · neutralise the page itself ---------------------------------- */
	html,
	body {
		margin:            0 !important;
		padding:           0 !important;
		background:        #ffffff !important;  /* paper white AROUND the sheet only */
		width:             auto !important;
		height:            auto !important;
		min-height:        0 !important;
		overflow:          visible !important;
	}

	/* -- 3b · hide ALL app chrome unconditionally ------------------------- */
	/* Site shell (header/nav/footer/toolbars) + the scroll's own control panel
	   + any stage UI affordances. data-print="hide" is an opt-out hook any
	   sibling can set without us enumerating it.                            */
	.sc2-panel,
	.sc2-toolbar,
	.sc2-controls,
	.sc2-stage__ui,
	.sc2-zoombar,
	.sc2-export-bar,
	.sc2-tabs,
	.sc2-hint,
	.sc2-skip-print,
	[data-print="hide"],
	header.ork-header,
	#ork-header,
	.ork-nav, nav.navbar, .navbar,
	#sidebar, .sidebar,
	footer.ork-footer, #ork-footer,
	.breadcrumbs, .breadcrumb,
	.toast, .toast-stack, .modal-backdrop,
	#whats-new-modal, .whats-new-fab,
	.docs-fab, .help-fab,
	.skip-link {
		display:    none !important;
		visibility: hidden !important;
	}

	/* -- 3c · collapse the app wrappers so the scroll can fill the page --- */
	.sc2-app,
	.sc2-stage {
		display:           block !important;
		position:          static !important;
		margin:            0 !important;
		padding:           0 !important;
		border:            0 !important;
		width:             auto !important;
		max-width:         none !important;
		min-height:        0 !important;
		height:            auto !important;
		background:        #ffffff !important;  /* no gray felt in print */
		box-shadow:        none !important;
		overflow:          visible !important;
		gap:               0 !important;
		grid-template-columns: none !important; /* unwind any panel/stage grid */
	}

	/* -- 3d · the sheet fills the printable page, full-bleed ------------- */
	.sc2-scroll {
		position:          relative !important;
		margin:            0 auto !important;
		/* Letter portrait content area at margin:0. We size by WIDTH and let the
		   locked --aspect drive the height, so the ornament proportions that
		   read correctly on screen are preserved on paper.                   */
		width:             8.5in !important;
		max-width:         8.5in !important;
		min-width:         0 !important;
		height:            11in !important;
		/* keep aspect honest even if a UA ignores the explicit height */
		aspect-ratio:      var(--aspect, 8.5 / 11) !important;
		border-radius:     0 !important;        /* paper edge is the page edge */
		box-shadow:        none !important;     /* no drop shadow on paper */
		transform:         none !important;     /* drop any screen zoom/scale */
		zoom:              1 !important;
		break-inside:      avoid !important;
		page-break-inside: avoid !important;
		overflow:          hidden !important;   /* clip ornament to the sheet */
	}

	/* -- 3e · keep the felt backdrop's vignette/lift from leaking --------- */
	.sc2-stage::before,
	.sc2-stage::after {
		display: none !important;
	}
}


/* ===========================================================================
   4 · ORIENTATION — landscape families print landscape
   ---------------------------------------------------------------------------
   Bind the named @page box to the sheet when the renderer marks it landscape,
   and swap the in/in dimensions so the proportions hold.
   =========================================================================== */
@media print {
	.sc2-scroll[data-orientation="landscape"] {
		page:              sc2-landscape;
		width:             11in !important;
		max-width:         11in !important;
		height:            8.5in !important;
		aspect-ratio:      var(--aspect, 11 / 8.5) !important;
	}
}


/* ===========================================================================
   5 · PRINT/EXPORT FALLBACKS for fragile screen-only effects
   ---------------------------------------------------------------------------
   Two effects DO NOT survive rasterisation reliably and the locked spec
   mandates flattened swaps:
     (a) the deckle edge via #sc2-deckle (feTurbulence + feDisplacementMap mask)
         — html2canvas drops SVG-filter masks; some PDF engines wobble them.
         → swap to a BAKED, flattened <path> deckle mask data-URI (jittered
           points, no live filter).
     (b) gilt TEXT via background-clip:text — html2canvas renders it transparent
         (i.e. invisible). → swap to solid --gold + a keyline text-shadow.
   Both swaps apply to BOTH @media print AND the .sf-export-mode/.sc2-export
   capture class, so PDF and PNG match the screen.
   =========================================================================== */

/* ---- 5a · BAKED DECKLE MASK (flattened, no live SVG filter) -------------
   Irregular hand-torn vellum edge as a single data-URI mask. ~52 jittered
   anchor points around a Letter-proportioned rect, rounded corners implied by
   the wobble. White = keep, transparent = cut. preserveAspectRatio:none lets
   it stretch to the sheet box at any size. This deliberately AVOIDS a crisp
   rectangle (the "web certificate" tell).                                   */
:root {
	--sf-deckle-baked:
		url('data:image/svg+xml;utf8,\
<svg xmlns="http://www.w3.org/2000/svg" width="850" height="1100" viewBox="0 0 850 1100" preserveAspectRatio="none">\
<path fill="%23fff" d="\
M14,22 C40,9 70,16 96,11 C150,4 210,18 268,12 C330,6 392,19 452,11 \
C520,3 588,17 648,10 C706,5 760,16 808,9 C826,7 838,14 840,34 \
C835,90 845,150 838,212 C831,278 844,338 837,402 C830,470 843,530 836,596 \
C829,664 842,724 835,790 C828,860 841,920 834,988 C831,1028 840,1058 836,1080 \
C812,1093 778,1086 744,1091 C684,1099 622,1085 560,1092 C496,1099 432,1086 370,1092 \
C306,1098 244,1085 182,1091 C124,1097 70,1086 28,1090 C12,1092 6,1080 9,1056 \
C16,996 5,936 12,872 C19,804 6,744 13,678 C20,610 7,550 14,484 \
C21,416 8,356 15,290 C22,222 9,162 16,96 C20,56 7,40 14,22 Z"/>\
</svg>');
}

@media print {
	.sc2-scroll {
		-webkit-mask:         var(--sf-deckle-baked) center / 100% 100% no-repeat !important;
		        mask:         var(--sf-deckle-baked) center / 100% 100% no-repeat !important;
		-webkit-mask-mode:    alpha !important;
		        mask-mode:    alpha !important;
	}
}

.sf-export-mode .sc2-scroll,
.sc2-export .sc2-scroll,
.sc2-scroll.sf-export-mode,
.sc2-scroll.sc2-export {
	-webkit-mask:        var(--sf-deckle-baked) center / 100% 100% no-repeat !important;
	        mask:        var(--sf-deckle-baked) center / 100% 100% no-repeat !important;
	-webkit-mask-mode:   alpha !important;
	        mask-mode:   alpha !important;
}

/* ---- 5b · GILT TEXT fallback (background-clip:text → solid gold) --------
   background-clip:text captures as transparent in html2canvas and is unreliable
   in some print engines. Flatten title + versal to a solid gilt fill with a
   keyline shadow so the gold still reads "raised". We also re-assert the
   global orkui h1–h6 pill reset here, because the gray pill MUST never appear
   on the printed title.                                                      */
@media print {
	.sc2-title,
	.sc2-versal,
	.sc2-body > p:first-of-type::first-letter,
	.sc2-grant .sc2-award,
	.gilt-text {
		background:             none !important;
		-webkit-background-clip: border-box !important;
		        background-clip: border-box !important;
		-webkit-text-fill-color: var(--gold) !important;
		color:                  var(--gold) !important;
		-webkit-text-stroke:    0 !important;
		text-shadow:
			0 1px 0   var(--gold-hi),
			0 1px 1px var(--gold-keyline) !important;
		filter:                 none !important;  /* drop drop-shadow stacks */
	}

	/* global orkui h1–h6 pill reset — must survive into print */
	.sc2-scroll h1, .sc2-scroll h2, .sc2-scroll h3,
	.sc2-scroll h4, .sc2-scroll h5, .sc2-scroll h6,
	.sc2-title {
		background:    transparent !important;
		border:        0 !important;
		padding:       0 !important;
		border-radius: 0 !important;
		box-shadow:    none !important;
	}
}

.sf-export-mode .sc2-title,
.sf-export-mode .sc2-versal,
.sf-export-mode .sc2-body > p:first-of-type::first-letter,
.sf-export-mode .sc2-grant .sc2-award,
.sf-export-mode .gilt-text,
.sc2-export .sc2-title,
.sc2-export .sc2-versal,
.sc2-export .sc2-body > p:first-of-type::first-letter,
.sc2-export .sc2-grant .sc2-award,
.sc2-export .gilt-text {
	background:              none !important;
	-webkit-background-clip: border-box !important;
	        background-clip: border-box !important;
	-webkit-text-fill-color: var(--gold) !important;
	color:                  var(--gold) !important;
	-webkit-text-stroke:    0 !important;
	text-shadow:
		0 1px 0   var(--gold-hi),
		0 1px 1px var(--gold-keyline) !important;
	filter:                 none !important;
}


/* ===========================================================================
   6 · .sf-export-mode — PIXEL-FAITHFUL html2canvas CAPTURE
   ---------------------------------------------------------------------------
   The PNG exporter adds .sf-export-mode (and/or .sc2-export) to the app root
   for the duration of one capture. Goals:
     • the captured node = the bare sheet on a transparent/neutral ground,
       no chrome, no felt, no shadow, no zoom transform;
     • all motion frozen (animations spinning during capture cause tears);
     • deckle + gilt swapped to the flattened forms above;
     • lazy/async paints (web-font swap flashes, GPU compositing) calmed.
   We do NOT change layout, spacing, or token hues — only what html2canvas
   cannot reproduce.
   =========================================================================== */

/* 6a · strip chrome + felt during capture (mirror of the print isolation) */
.sf-export-mode .sc2-panel,
.sf-export-mode .sc2-toolbar,
.sf-export-mode .sc2-controls,
.sf-export-mode .sc2-stage__ui,
.sf-export-mode .sc2-export-bar,
.sf-export-mode [data-print="hide"],
.sc2-export .sc2-panel,
.sc2-export .sc2-toolbar,
.sc2-export .sc2-controls,
.sc2-export .sc2-stage__ui,
.sc2-export .sc2-export-bar,
.sc2-export [data-print="hide"] {
	display:    none !important;
	visibility: hidden !important;
}

.sf-export-mode .sc2-app,
.sf-export-mode .sc2-stage,
.sc2-export .sc2-app,
.sc2-export .sc2-stage {
	display:    block !important;
	position:   static !important;
	margin:     0 !important;
	padding:    0 !important;
	background: transparent !important;   /* let html2canvas backgroundColn fill */
	box-shadow: none !important;
	overflow:   visible !important;
	width:      auto !important;
	max-width:  none !important;
	grid-template-columns: none !important;
}

/* 6b · the sheet sits clean: no zoom transform, no drop shadow, square-ish lift
        removed (the deckle mask is the only edge treatment in capture).      */
.sf-export-mode .sc2-scroll,
.sc2-export .sc2-scroll {
	margin:        0 auto !important;
	transform:     none !important;        /* kill any screen zoom/scale */
	zoom:          1 !important;
	box-shadow:    none !important;        /* html2canvas mis-bleeds large blurs */
	border-radius: 0 !important;
	animation:     none !important;
}

/* 6c · FREEZE all motion + transitions during capture (prevents tearing). */
.sf-export-mode *,
.sf-export-mode *::before,
.sf-export-mode *::after,
.sc2-export *,
.sc2-export *::before,
.sc2-export *::after {
	animation-play-state: paused !important;
	animation:            none !important;
	transition:           none !important;
	scroll-behavior:      auto !important;
	will-change:          auto !important;
	caret-color:          transparent !important;
}

/* 6d · html2canvas cannot rasterise SVG <filter> effects (feTurbulence,
        feDisplacementMap, feGaussianBlur) — they vanish or smear. The substrate
        partial supplies the fiber mottle + foxing via stacked CSS gradients
        too, so we simply DISABLE the live-filter overlays during capture and
        rely on the gradient layers underneath. Result: a clean aged vellum,
        no missing-filter holes.                                              */
.sf-export-mode .sc2-vellum,
.sf-export-mode .sc2-vellum::before,
.sf-export-mode .sc2-vellum::after,
.sc2-export .sc2-vellum,
.sc2-export .sc2-vellum::before,
.sc2-export .sc2-vellum::after {
	filter: none !important;               /* drop url(#sc2-mottle) etc. */
}

/* Hide the offscreen filter-defs SVG so it can never paint a stray box. */
.sf-export-mode .sc2-defs,
.sc2-export .sc2-defs {
	position: absolute !important;
	width:    0 !important;
	height:   0 !important;
	overflow: hidden !important;
	opacity:  0 !important;
}

/* 6e · curls (intensity=ornate) cast inward shadows that html2canvas can
        halo; soften to a hard edge during capture.                          */
.sf-export-mode .sc2-edge,
.sc2-export .sc2-edge {
	box-shadow: none !important;
}

/* 6f · the wax seal's radial gilding survives, but its outer drop-shadow can
        bleed past the sheet in capture — clamp it to an inset-only relief.   */
.sf-export-mode .sc2-seal,
.sc2-export .sc2-seal {
	filter:     none !important;
	box-shadow: none !important;
}


/* ===========================================================================
   7 · SCREEN-ONLY GUARD for the export class
   ---------------------------------------------------------------------------
   .sf-export-mode may linger a frame after capture if the exporter's cleanup
   is async. Make sure that, ON SCREEN (not print), the chrome it hid comes back
   the instant the class is removed — handled by absence of the class — and that
   while present it does not visibly flash the page to white. We force a neutral
   capture ground only inside the class so the live UI is untouched.
   =========================================================================== */
@media screen {
	.sf-export-mode,
	.sc2-export {
		background: #cfc9bd !important;   /* neutral felt = html2canvas bg match */
	}
}


/* ===========================================================================
   8 · DARK-MODE SAFETY (chrome only)
   ---------------------------------------------------------------------------
   The scroll sheet always renders on its own light vellum (tokens scoped to
   .sc2-scroll). But if the app is in dark mode when the user prints, some UAs
   honour the dark page background. Force the AROUND-sheet area white in print
   regardless of theme, so we never get a dark page bleeding around the vellum.
   The sheet itself is untouched (its tokens win via scope + the §1 color-adjust
   force).
   =========================================================================== */
@media print {
	[data-theme="dark"] .sc2-app,
	[data-theme="dark"] .sc2-stage,
	html[data-theme="dark"],
	body[data-theme="dark"],
	.dark .sc2-app,
	.dark .sc2-stage {
		background: #ffffff !important;
		color:      var(--ink, #2a211a) !important;
	}
}


/* ===========================================================================
   9 · ACCESSIBILITY / MOTION — respect reduced motion at all times
   ---------------------------------------------------------------------------
   Not strictly print, but lives with motion control: users who ask for reduced
   motion get the frozen sheet too (no idle shimmer on gilt, no curl drift).
   =========================================================================== */
@media (prefers-reduced-motion: reduce) {
	.sc2-scroll *,
	.sc2-scroll *::before,
	.sc2-scroll *::after {
		animation-duration:  0.001ms !important;
		animation-iteration-count: 1 !important;
		transition-duration: 0.001ms !important;
	}
}

</style>

<!-- =============================================
     ZONE 1: Hero Header
     ============================================= -->
<div class="sc-hero">
  <div class="sc-hero-content">
    <div class="sc-hero-icon">
      <i class="fas fa-scroll"></i>
    </div>
    <div class="sc-hero-info">
      <h1 class="sc-hero-title">Scroll Generator</h1>
      <?php if ($sgPlayer): ?>
        <div class="sc-hero-sub">Creating scroll for <strong><?= htmlspecialchars($sgPlayer['Persona'] ?? '') ?></strong><?= $sgAwardName ? ' &mdash; ' . htmlspecialchars($sgAwardName) : '' ?></div>
      <?php else: ?>
        <div class="sc-hero-sub">Design and generate custom award scrolls</div>
      <?php endif; ?>
      <div class="sc-hero-badges">
        <?php if ($sgPlayer): ?>
          <?php if ($sgParkName): ?>
            <span class="sc-hero-badge"><i class="fas fa-campground" style="font-size:9px"></i> <?= htmlspecialchars($sgParkName) ?></span>
          <?php endif; ?>
          <?php if ($sgKingdomName): ?>
            <span class="sc-hero-badge"><i class="fas fa-chess-rook" style="font-size:9px"></i> <?= htmlspecialchars($sgKingdomName) ?></span>
          <?php endif; ?>
        <?php else: ?>
          <span class="sc-hero-badge"><i class="fas fa-info-circle" style="font-size:9px"></i> Standalone Mode</span>
        <?php endif; ?>
      </div>
    </div>
  </div>
</div>

<!-- =============================================
     ZONE 2: Workspace
     ============================================= -->

<!-- ============================================================
     SCROLL FORGE (v2) — new HTML/CSS/inline-SVG renderer.
     The SOLE scroll generator; the legacy sc- canvas builder is removed.
     ============================================================ -->
<div class="sc2-forge" id="sc2Forge">
<!-- ===== inlined: sf-ui.html.part ===== -->
<?php
	/* ============================================================================
	   THE LETTERED SCROLL — sf-ui.html.part   (PHP / ORK3 view)
	   ----------------------------------------------------------------------------
	   THE CONTROL PANEL (.sc2-panel) — UI chrome ONLY. SIBLING of the stage
	   (.sc2-stage), never a parent, so print/export can isolate the sheet.
	   Owns: family swatch picker, live text fields, option toggles, Export rail.

	   ORK3 renders this as PLAIN PHP (extract()+include), NOT Smarty. Controller
	   data is in scope ($player, $award, …) plus the $sg* locals from the backup
	   top. sf-app.js re-reads window.SgConfig at init, so these server seeds only
	   feed the initial paint.

	   HARD RULES honored: dark-mode-safe chrome (theme tokens in panel CSS; no
	   inline colours here); NO native title="" (hints use data-tip); global orkui
	   h1–h6 pill reset on every panel heading via .sc2-h; defensive defaults so a
	   missing award/player never paints a blank field or a raw ISO date.
	   ============================================================================ */

	$sfPersona     = ($sgPlayer && !empty($sgPlayer['Persona'])) ? $sgPlayer['Persona'] : 'the Bearer of this Scroll';
	$sfAwardName   = $sgAwardName ?: ($sgAward['Name'] ?? 'a Token of Esteem');
	$sfKingdomName = $sgKingdomName ?: 'the Kingdom';
	$sfParkName    = $sgParkName ?: 'Our realm';
	$sfNote        = $sgAward['Note'] ?? '';
	$sfGivenBy     = $sgAward['GivenBy'] ?? '';
	$sfDate        = $sgAward['Date'] ?? '';
	$sfCanGenerate = !empty($sgCanGenerate);

	if (!isset($h)) { $h = function ($s) { return htmlspecialchars((string)$s, ENT_QUOTES, 'UTF-8'); }; }

	// key | display label | one-word motif tag — JS overrides label/swatch from JSON
	$sfFamilies = [
		['hibernian_knotwork', 'Hibernian Knotwork', 'Celtic interlace'],
		['northern_gothic',    'Northern Gothic',    'Gothic tracery'],
		['provencal_bestiary', 'Provençal Bestiary', 'Foliate drollery'],
		['crimson_decree',     'Crimson Decree',     'Royal acanthus'],
		['forest_reverie',     'Forest Reverie',     'Fae rinceaux'],
		['charred_edict',      'Charred Edict',      'Scorched rule'],
		['imperial_edict',     'Imperial Edict',     'Laurel &amp; eagle'],
		['scholars_hand',      "Scholar's Hand",     'Plain diploma'],
		['crusaders_charter',  "Crusader's Charter", 'Cross &amp; chevron'],
		['astral_codex',       'Astral Codex',       'Star-grain'],
	];

	// key | label | preview hex ('' = family wax)
	$sfWaxes = [
		['family',  'Family',  ''],
		['crimson', 'Crimson', '#8c1d1b'],
		['oxblood', 'Oxblood', '#5a0f0f'],
		['forest',  'Forest',  '#1f4d2e'],
		['azure',   'Azure',   '#1e3a6e'],
		['violet',  'Violet',  '#43286e'],
		['gold',    'Gilt',    '#b8862b'],
		['sable',   'Sable',   '#241c15'],
	];
?>

<aside class="sc2-panel" id="sc2Panel" data-theme-scope aria-label="Scroll design controls">

	<!-- PANEL HEADER -->
	<header class="sc2-panel__head">
		<div class="sc2-panel__brand">
			<svg class="sc2-panel__mark" viewBox="0 0 32 32" aria-hidden="true" focusable="false">
				<path d="M7 5h15a3 3 0 0 1 3 3v16a3 3 0 0 0 3 3H10a3 3 0 0 1-3-3V5z"
				      fill="none" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/>
				<path d="M7 5a3 3 0 0 0-3 3 3 3 0 0 0 3 3h2V5H7zM22 27a3 3 0 0 0 3-3v-2h-2v5h-1z"
				      fill="currentColor" opacity=".55"/>
				<path d="M11 12h10M11 16h10M11 20h7" stroke="currentColor" stroke-width="1.3"
				      stroke-linecap="round" opacity=".7"/>
			</svg>
			<div class="sc2-panel__titles">
				<h2 class="sc2-h sc2-panel__title">Scroll Forge</h2>
				<p class="sc2-panel__sub">Letter an illuminated award scroll</p>
			</div>
		</div>
		<button type="button" class="sc2-panel__collapse" id="sc2PanelCollapse"
		        data-tip="Hide controls" aria-label="Hide controls" aria-expanded="true">
			<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false">
				<path d="M15 6l-6 6 6 6" fill="none" stroke="currentColor" stroke-width="2"
				      stroke-linecap="round" stroke-linejoin="round"/>
			</svg>
		</button>
	</header>

	<!-- Scrollable body so the export rail (footer) can stay pinned -->
	<div class="sc2-panel__body" id="sc2PanelBody">

		<!-- 1 · STYLE FAMILY (visual swatch grid; JS paints palettes from SC_FAMILIES) -->
		<section class="sc2-group" aria-labelledby="sc2GrpFamily">
			<div class="sc2-group__head">
				<h3 class="sc2-h sc2-group__title" id="sc2GrpFamily">Style Family</h3>
				<span class="sc2-group__hint" data-tip="The visual tradition: substrate tint, border motif, gilding, seal &amp; type pairing all shift per family.">
					<svg viewBox="0 0 20 20" aria-hidden="true" focusable="false"><circle cx="10" cy="10" r="8.2" fill="none" stroke="currentColor" stroke-width="1.4"/><path d="M10 9v5" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/><circle cx="10" cy="6" r="1.05" fill="currentColor"/></svg>
				</span>
			</div>

			<div class="sc2-fam" id="sc2FamilyGrid" role="radiogroup" aria-label="Scroll style family">
				<?php foreach ($sfFamilies as $fam): ?>
					<button type="button"
					        class="sc2-fam__swatch"
					        id="sc2Fam-<?= $h($fam[0]) ?>"
					        data-family="<?= $h($fam[0]) ?>"
					        role="radio"
					        aria-checked="false"
					        data-tip="<?= $fam[1] ?> — <?= $fam[2] ?>">
						<span class="sc2-fam__chip" aria-hidden="true" data-fam-chip="<?= $h($fam[0]) ?>">
							<i class="sc2-fam__band sc2-fam__band--1"></i>
							<i class="sc2-fam__band sc2-fam__band--2"></i>
							<i class="sc2-fam__band sc2-fam__band--3"></i>
							<i class="sc2-fam__band sc2-fam__band--4"></i>
							<svg class="sc2-fam__check" viewBox="0 0 24 24" aria-hidden="true" focusable="false">
								<path d="M5 12.5l4.2 4.2L19 6.5" fill="none" stroke="currentColor"
								      stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>
							</svg>
						</span>
						<span class="sc2-fam__label" data-fam-label="<?= $h($fam[0]) ?>"><?= $fam[1] ?></span>
						<span class="sc2-fam__motif" data-fam-motif="<?= $h($fam[0]) ?>"><?= $fam[2] ?></span>
					</button>
				<?php endforeach; ?>
			</div>
		</section>

		<!-- 2 · WORDING (live text fields; each input carries data-sc2-field="<bind>") -->
		<section class="sc2-group" aria-labelledby="sc2GrpWording">
			<div class="sc2-group__head">
				<h3 class="sc2-h sc2-group__title" id="sc2GrpWording">Wording</h3>
				<button type="button" class="sc2-group__reset" id="sc2WordingReset"
				        data-tip="Restore the auto-written proclamation from the award record">
					Restore auto-text
				</button>
			</div>

			<div class="sc2-field">
				<label class="sc2-field__lbl" for="sc2fPersona">Recipient</label>
				<input class="sc2-field__in" id="sc2fPersona" type="text"
				       data-sc2-field="persona"
				       value="<?= $h($sfPersona) ?>"
				       placeholder="the Bearer of this Scroll"
				       autocomplete="off" spellcheck="false">
				<small class="sc2-field__note">Rubricated in vermilion on the scroll.</small>
			</div>

			<div class="sc2-field">
				<label class="sc2-field__lbl" for="sc2fAward">Award title</label>
				<input class="sc2-field__in" id="sc2fAward" type="text"
				       data-sc2-field="awardName"
				       value="<?= $h($sfAwardName) ?>"
				       placeholder="a Token of Esteem"
				       autocomplete="off" spellcheck="false">
				<small class="sc2-field__note">Set in the grand display blackletter title.</small>
			</div>

			<div class="sc2-field sc2-field--2col">
				<div>
					<label class="sc2-field__lbl" for="sc2fKingdom">Kingdom</label>
					<input class="sc2-field__in" id="sc2fKingdom" type="text"
					       data-sc2-field="kingdomName"
					       value="<?= $h($sfKingdomName) ?>"
					       placeholder="the Kingdom"
					       autocomplete="off" spellcheck="false">
				</div>
				<div>
					<label class="sc2-field__lbl" for="sc2fPark">Park / place</label>
					<input class="sc2-field__in" id="sc2fPark" type="text"
					       data-sc2-field="parkName"
					       value="<?= $h($sfParkName) ?>"
					       placeholder="Our realm"
					       autocomplete="off" spellcheck="false">
				</div>
			</div>

			<div class="sc2-field">
				<label class="sc2-field__lbl" for="sc2fDate">Date granted</label>
				<input class="sc2-field__in sc2-field__in--date" id="sc2fDate" type="date"
				       data-sc2-field="date"
				       value="<?= $h($sfDate) ?>">
				<small class="sc2-field__note">Written out in full on the scroll (e.g. &ldquo;the twelfth day of May&rdquo;).</small>
			</div>

			<div class="sc2-field">
				<label class="sc2-field__lbl" for="sc2fReason">For / reason</label>
				<textarea class="sc2-field__in sc2-field__ta" id="sc2fReason" rows="2"
				          data-sc2-field="note"
				          placeholder="service to Our realm"
				          spellcheck="true"><?= $h($sfNote) ?></textarea>
				<small class="sc2-field__note">Woven into the narration. Blank &rarr; &ldquo;service to Our realm&rdquo;.</small>
			</div>

			<div class="sc2-field">
				<label class="sc2-field__lbl" for="sc2fGivenBy">Attested by</label>
				<!-- Giver search is GLOBAL/unscoped (project memory). JS wires the custom
				     kn-ac-results dropdown to SgConfig.httpService with &q= (never ?q=). -->
				<div class="sc2-ac">
					<input class="sc2-field__in" id="sc2fGivenBy" type="text"
					       data-sc2-field="givenBy"
					       value="<?= $h($sfGivenBy) ?>"
					       placeholder="signing officer&rsquo;s persona"
					       autocomplete="off" spellcheck="false"
					       aria-autocomplete="list" aria-controls="sc2GivenByAc">
					<ul class="kn-ac-results sc2-ac__results" id="sc2GivenByAc" role="listbox" aria-label="Officer search results"></ul>
				</div>
				<small class="sc2-field__note">Searches all realms &mdash; an officer abroad may attest.</small>
			</div>
		</section>

		<!-- 3 · OPTIONS (toggles drive data-* on .sc2-scroll or a token swap) -->
		<section class="sc2-group" aria-labelledby="sc2GrpOptions">
			<div class="sc2-group__head">
				<h3 class="sc2-h sc2-group__title" id="sc2GrpOptions">Presentation</h3>
			</div>

			<!-- Orientation -->
			<div class="sc2-opt">
				<span class="sc2-opt__lbl">Orientation</span>
				<div class="sc2-seg" role="radiogroup" aria-label="Orientation" data-sc2-seg="orientation">
					<input class="sc2-seg__in" type="radio" name="sc2Orientation" id="sc2OriPortrait" value="portrait" checked>
					<label class="sc2-seg__pill" for="sc2OriPortrait" data-tip="Tall sheet (8.5 &times; 11)">Portrait</label>
					<input class="sc2-seg__in" type="radio" name="sc2Orientation" id="sc2OriLandscape" value="landscape">
					<label class="sc2-seg__pill" for="sc2OriLandscape" data-tip="Wide sheet (11 &times; 8.5)">Landscape</label>
				</div>
			</div>

			<!-- Illumination intensity -->
			<div class="sc2-opt">
				<span class="sc2-opt__lbl">Illumination</span>
				<div class="sc2-seg sc2-seg--3" role="radiogroup" aria-label="Illumination intensity" data-sc2-seg="intensity">
					<input class="sc2-seg__in" type="radio" name="sc2Intensity" id="sc2IntPlain" value="plain">
					<label class="sc2-seg__pill" for="sc2IntPlain" data-tip="Restrained: bar border, no ruling, no curl">Plain</label>
					<input class="sc2-seg__in" type="radio" name="sc2Intensity" id="sc2IntBalanced" value="balanced" checked>
					<label class="sc2-seg__pill" for="sc2IntBalanced" data-tip="Decorated band, ruling &amp; pricking">Balanced</label>
					<input class="sc2-seg__in" type="radio" name="sc2Intensity" id="sc2IntOrnate" value="ornate">
					<label class="sc2-seg__pill" for="sc2IntOrnate" data-tip="Full: corner bosses, rolled curls, bas-de-page">Ornate</label>
				</div>
			</div>

			<!-- Heraldry on/off -->
			<div class="sc2-opt sc2-opt--switch">
				<label class="sc2-switch" for="sc2OptHeraldry">
					<input class="sc2-switch__in" type="checkbox" id="sc2OptHeraldry"
					       data-sc2-toggle="heraldry" checked>
					<span class="sc2-switch__track" aria-hidden="true"><span class="sc2-switch__thumb"></span></span>
					<span class="sc2-switch__text">
						<span class="sc2-switch__name">Heraldry</span>
						<span class="sc2-switch__desc">Kingdom &amp; park arms crowning the title</span>
					</span>
				</label>
			</div>

			<!-- Rolled curls on/off -->
			<div class="sc2-opt sc2-opt--switch">
				<label class="sc2-switch" for="sc2OptCurl">
					<input class="sc2-switch__in" type="checkbox" id="sc2OptCurl"
					       data-sc2-toggle="curl">
					<span class="sc2-switch__track" aria-hidden="true"><span class="sc2-switch__thumb"></span></span>
					<span class="sc2-switch__text">
						<span class="sc2-switch__name">Rolled curls</span>
						<span class="sc2-switch__desc">Top &amp; bottom of the sheet roll with cast shadow</span>
					</span>
				</label>
			</div>

			<!-- Wax seal colour -->
			<div class="sc2-opt">
				<span class="sc2-opt__lbl">Seal wax</span>
				<div class="sc2-wax" role="radiogroup" aria-label="Wax seal colour" data-sc2-seg="seal">
					<?php foreach ($sfWaxes as $wax): ?>
						<input class="sc2-wax__in" type="radio" name="sc2Seal"
						       id="sc2Wax-<?= $h($wax[0]) ?>" value="<?= $h($wax[0]) ?>"<?= $wax[0] === 'family' ? ' checked' : '' ?>>
						<label class="sc2-wax__dot<?= $wax[0] === 'family' ? ' sc2-wax__dot--family' : '' ?>"
						       for="sc2Wax-<?= $h($wax[0]) ?>"
						       data-tip="<?= $h($wax[1]) ?> wax"
						       <?= $wax[2] !== '' ? 'style="--sc2-wax-preview:' . $h($wax[2]) . '"' : '' ?>>
							<span class="sc2-wax__inner" aria-hidden="true"></span>
							<span class="sc2-vh"><?= $h($wax[1]) ?></span>
						</label>
					<?php endforeach; ?>
				</div>
				<small class="sc2-field__note">&ldquo;Family&rdquo; uses each style&rsquo;s liveried wax.</small>
			</div>
		</section>

		<section class="sc2-art-panel" id="sc2ArtPanel">
			<h3>Artwork</h3>
			<div class="sc2-art-zonegrid" id="sc2ArtZoneGrid">
				<button type="button" class="sc2-art-zonebtn" data-zone="full_border"><span>Full Border</span><span class="sc2-art-dot"></span></button>
				<button type="button" class="sc2-art-zonebtn" data-zone="border_top"><span>Top Border</span><span class="sc2-art-dot"></span></button>
				<button type="button" class="sc2-art-zonebtn" data-zone="border_bottom"><span>Bottom Border</span><span class="sc2-art-dot"></span></button>
				<button type="button" class="sc2-art-zonebtn" data-zone="border_left"><span>Left Border</span><span class="sc2-art-dot"></span></button>
				<button type="button" class="sc2-art-zonebtn" data-zone="border_right"><span>Right Border</span><span class="sc2-art-dot"></span></button>
				<button type="button" class="sc2-art-zonebtn" data-zone="top_graphic"><span>Top Graphic</span><span class="sc2-art-dot"></span></button>
				<button type="button" class="sc2-art-zonebtn" data-zone="center_image"><span>Center Image</span><span class="sc2-art-dot"></span></button>
				<button type="button" class="sc2-art-zonebtn" data-zone="watermark"><span>Watermark</span><span class="sc2-art-dot"></span></button>
			</div>
		</section>

	</div><!-- /.sc2-panel__body -->

	<!-- EXPORT RAIL (pinned footer); gated on $sfCanGenerate -->
	<footer class="sc2-panel__foot">
		<?php if ($sfCanGenerate): ?>
			<div class="sc2-export" id="sc2Export">
				<button type="button" class="sc2-btn sc2-btn--ghost" id="sc2ExportPrint"
				        data-tip="Open the print dialog — choose &ldquo;Save as PDF&rdquo; for a vector file">
					<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false">
						<path d="M7 9V4h10v5M7 18H5a2 2 0 0 1-2-2v-4a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2v4a2 2 0 0 1-2 2h-2M7 14h10v6H7z"
						      fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/>
					</svg>
					<span>Print / PDF</span>
				</button>
				<button type="button" class="sc2-btn sc2-btn--gold" id="sc2ExportPng"
				        data-tip="Render the scroll exactly as shown to a high-resolution PNG image">
					<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false">
						<path d="M4 5h16a1 1 0 0 1 1 1v12a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1z"
						      fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/>
						<circle cx="8.5" cy="9.5" r="1.6" fill="none" stroke="currentColor" stroke-width="1.5"/>
						<path d="M3 16l5-4 4 3 3-2 6 5" fill="none" stroke="currentColor" stroke-width="1.7"
						      stroke-linecap="round" stroke-linejoin="round"/>
					</svg>
					<span>Save PNG</span>
					<i class="sc2-btn__spin" aria-hidden="true"></i>
				</button>
			</div>
		<?php else: ?>
			<div class="sc2-export sc2-export--locked">
				<button type="button" class="sc2-btn sc2-btn--ghost" disabled aria-disabled="true"
				        data-tip="You don&rsquo;t have rights to generate this scroll. The preview is still yours to admire.">
					<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false">
						<path d="M7 11V8a5 5 0 0 1 10 0v3M6 11h12a1 1 0 0 1 1 1v7a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1v-7a1 1 0 0 1 1-1z"
						      fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/>
					</svg>
					<span>Export locked</span>
				</button>
			</div>
		<?php endif; ?>
		<p class="sc2-panel__foot-note" aria-live="polite" id="sc2ExportStatus"></p>
	</footer>

</aside><!-- /.sc2-panel -->

<!-- Floating re-open tab (visible only when the panel is collapsed) -->
<button type="button" class="sc2-panel-reopen" id="sc2PanelReopen"
        data-tip="Show controls" aria-label="Show controls" hidden>
	<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false">
		<path d="M9 6l6 6-6 6" fill="none" stroke="currentColor" stroke-width="2"
		      stroke-linecap="round" stroke-linejoin="round"/>
	</svg>
</button>

<!-- ===== end: sf-ui.html.part ===== -->

<!-- ===== inlined: sf-scroll-markup.html.part ===== -->
<?php
	/* ============================================================================
	   THE LETTERED SCROLL  ·  sf-scroll-markup.html.part   (PHP / ORK3 view)
	   ----------------------------------------------------------------------------
	   ORK3 renders this template as PLAIN PHP via extract()+include (NOT Smarty).
	   The controller's data is in scope as $player, $award, $kingdom_name, … and
	   the backup top of Scroll_builder.tpl normalizes them into $sg* locals +
	   $sgConfig. This fragment OWNS only the scroll markup + the data-* hooks the
	   client renderer (sf-app.js) binds to (it reads window.SgConfig live).

	   MEDIUM IS LOCKED: semantic HTML + CSS + inline SVG. No <canvas>.

	   BINDING STRATEGY (defensive, dual-source):
	     • Server-rendered seeds give a meaningful first paint (and the no-JS /
	       @media print path). Every value is guarded so a blank/missing datum
	       never paints an empty surface or a raw ISO date.
	     • Every dynamic surface ALSO carries data-sc2-bind="<key>" so sf-app.js
	       re-letters it live from window.SgConfig as the controls change.

	   PROJECT RULES honored: TAB indentation; NO native title="" tooltips (hints
	   use data-tip); the typography partial resets the global orkui h1 pill on
	   .sc2-title.
	   ============================================================================ */

	// ── Resolve safe server-side seeds (mirror of SgConfig; see integration contract) ──
	$sc2_persona      = ($sgPlayer && !empty($sgPlayer['Persona'])) ? $sgPlayer['Persona'] : 'the Bearer of this Scroll';
	$sc2_award        = $sgAwardName ?: ($sgAward['Name'] ?? 'a Token of Esteem');
	$sc2_kingdom      = $sgKingdomName ?: 'the Kingdom';
	$sc2_place        = $sgParkName ?: 'Our realm';
	$sc2_reason       = (!empty($sgAward['Note'])) ? $sgAward['Note'] : 'service to Our realm';
	$sc2_kingdom_arms = $sgKingdomHeraldry ?? '';
	$sc2_park_arms    = $sgParkHeraldry ?? '';
	$sc2_player_arms  = $sgPlayerHeraldry ?? '';
	$sc2_given_by     = $sgAward['GivenBy'] ?? '';

	// Officer seeds for the attestation. $sgPreloadOfficers is ordered
	// Monarch-then-Regent (Kingdom before Park); take the first two verbatim.
	// sf-app.js does the precise Role-based mapping live from SgConfig regardless.
	$sc2_off1_name = '';
	$sc2_off1_role = '';
	$sc2_off2_name = '';
	$sc2_off2_role = '';
	if (is_array($sgPreloadOfficers)) {
		if (isset($sgPreloadOfficers[0])) {
			$sc2_off1_name = $sgPreloadOfficers[0]['Persona'] ?? '';
			$sc2_off1_role = $sgPreloadOfficers[0]['Role'] ?? '';
		}
		if (isset($sgPreloadOfficers[1])) {
			$sc2_off2_name = $sgPreloadOfficers[1]['Persona'] ?? '';
			$sc2_off2_role = $sgPreloadOfficers[1]['Role'] ?? '';
		}
	}
	// Prefer the explicit giver as primary signer when no officer roster resolved.
	if ($sc2_off1_name === '') { $sc2_off1_name = $sc2_given_by ?: 'the Crown'; }
	if ($sc2_off1_role === '') { $sc2_off1_role = 'Sovereign of ' . $sc2_kingdom; }

	// Auto family pick (A=knight/crimson, C=title/northern, B/default=hibernian).
	$sc2_family = 'hibernian_knotwork';
	if (($sgAutoTemplate ?? 'B') === 'A')      { $sc2_family = 'crimson_decree'; }
	elseif (($sgAutoTemplate ?? 'B') === 'C')  { $sc2_family = 'northern_gothic'; }

	// Recipient monogram (first letter) for the wax sigil fallback.
	$sc2_monogram = mb_strtoupper(mb_substr($sc2_persona, 0, 1) ?: 'S');

	$h = function ($s) { return htmlspecialchars((string)$s, ENT_QUOTES, 'UTF-8'); };
?>

<main class="sc2-stage" id="sc2Stage" aria-label="Scroll preview">

	<article class="sc2-scroll"
	         id="sc2Scroll"
	         data-family="<?= $h($sc2_family) ?>"
	         data-orientation="portrait"
	         data-intensity="balanced"
	         lang="en"
	         aria-roledescription="award scroll"
	         aria-label="Illuminated award scroll for <?= $h($sc2_persona) ?>">

		<!-- ===================================================================
		     SVG DEFS — ONE per scroll. Filters, gradients, clipPaths, masks the
		     substrate / illumination / heraldry-seal partials reference by id.
		     The illumination/substrate JS may inject the family motif into
		     #sc2-defs-motif. aria-hidden: purely decorative.
		     =================================================================== -->
		<svg class="sc2-defs" width="0" height="0" aria-hidden="true" focusable="false"
		     style="position:absolute;width:0;height:0;overflow:hidden" data-sc2-defs>
			<defs>

				<!-- SUBSTRATE-OWNED DEFS (single source: sf-substrate.css.part §7).
				     The deckle filter+mask (#sc2-deckle-fx / #sc2-deckle) are authored
				     canonically by the substrate engineer; the finalizer injects them
				     immediately below. We do NOT redeclare — duplicate SVG ids break
				     url(#…) resolution. -->
				       <filter id="sc2-deckle-fx" x="-5%" y="-5%" width="110%" height="110%">
				         <feTurbulence type="fractalNoise" baseFrequency="0.02 0.04"
				                       numOctaves="3" seed="11" result="noise"/>
				         <feDisplacementMap in="SourceGraphic" in2="noise" scale="9"
				                            xChannelSelector="R" yChannelSelector="G"/>
				       </filter>
				       <mask id="sc2-deckle" maskUnits="objectBoundingBox"
				             maskContentUnits="objectBoundingBox"
				             x="0" y="0" width="1" height="1">
				         <rect x="0.004" y="0.004" width="0.992" height="0.992" rx="0.008"
				               fill="#fff" filter="url(#sc2-deckle-fx)"/>
				       </mask>

				<!-- Raised-gilding gradient (bands / boxes / rim) per locked recipe -->
				<linearGradient id="sc2-gild" x1="0%" y1="0%" x2="100%" y2="100%">
					<stop offset="0%"   stop-color="var(--gold-shadow)"/>
					<stop offset="35%"  stop-color="var(--gold)"/>
					<stop offset="55%"  stop-color="var(--gold-hi)"/>
					<stop offset="70%"  stop-color="var(--gold)"/>
					<stop offset="100%" stop-color="var(--gold-deep)"/>
				</linearGradient>

				<!-- Emboss / raised relief for corner bosses & seal sigil -->
				<filter id="sc2-emboss" x="-20%" y="-20%" width="140%" height="140%">
					<feGaussianBlur in="SourceAlpha" stdDeviation="1.2" result="blur"/>
					<feSpecularLighting in="blur" surfaceScale="3" specularConstant="0.9" specularExponent="18"
						lighting-color="#fff6d8" result="spec">
						<feDistantLight azimuth="225" elevation="55"/>
					</feSpecularLighting>
					<feComposite in="spec" in2="SourceAlpha" operator="in" result="specClip"/>
					<feComposite in="SourceGraphic" in2="specClip" operator="arithmetic" k1="0" k2="1" k3="1" k4="0"/>
				</filter>

				<!-- Wax radial body for the pendant seal -->
				<radialGradient id="sc2-wax" cx="38%" cy="34%" r="72%">
					<stop offset="0%"   stop-color="var(--wax-hi)"/>
					<stop offset="48%"  stop-color="var(--wax)"/>
					<stop offset="100%" stop-color="var(--wax-lo)"/>
				</radialGradient>

				<!-- Escutcheon (heater shield) clipPath for heraldry arms -->
				<clipPath id="sc2-escutcheon-heater" clipPathUnits="objectBoundingBox">
					<path d="M0.04,0.02 H0.96 V0.46
					         C0.96,0.74 0.78,0.92 0.50,1.00
					         C0.22,0.92 0.04,0.74 0.04,0.46 Z"/>
				</clipPath>
				<!-- Round/roundel device clip (used by some families & the seal device) -->
				<clipPath id="sc2-escutcheon-round" clipPathUnits="objectBoundingBox">
					<circle cx="0.5" cy="0.5" r="0.48"/>
				</clipPath>

				<!-- Per-family ornament motif injection point (illumination JS fills this) -->
				<g id="sc2-defs-motif" data-sc2-motif></g>

			</defs>
		</svg>

		<!-- ===================================================================
		     SUBSTRATE (z-vellum:0 + z-ruling:1) — owned by sf-substrate.css.part.
		     =================================================================== -->
		<div class="sc2-vellum" aria-hidden="true" data-sc2-vellum></div>
		<div class="sc2-ruling" aria-hidden="true" data-sc2-ruling></div>

		<!-- Rolled-curl strips (intensity=ornate only; CSS hides them otherwise) -->
		<div class="sc2-curl sc2-curl--top"    aria-hidden="true"></div>
		<div class="sc2-curl sc2-curl--bottom" aria-hidden="true"></div>

		<!-- ===================================================================
		     EDGE (z-edge:3) — deckle/curl/vignette overlay.
		     =================================================================== -->
		<div class="sc2-edge" aria-hidden="true" data-sc2-edge></div>

		<!-- ===================================================================
		     ILLUMINATION (z-illum:2) — concentric border zones + corners.
		     =================================================================== -->
		<div class="sc2-illum" aria-hidden="true" data-sc2-illum>
			<svg class="sc2-border"
			     viewBox="0 0 850 1100"
			     preserveAspectRatio="none"
			     xmlns="http://www.w3.org/2000/svg"
			     aria-hidden="true" focusable="false"
			     data-sc2-border>
				<rect class="sc2-border__rule" x="10" y="10" width="830" height="1080"
				      fill="none" stroke="var(--rule-fine)" stroke-width="0.75"/>
				<rect class="sc2-border__bar" x="24" y="24" width="802" height="1052"
				      fill="none" stroke="var(--border)" stroke-width="9"/>
				<!-- decorative inner band line(s). First line: balanced + ornate (CSS hides
				     for plain). Second concentric line: ornate ONLY (the richer frame). -->
				<g class="sc2-border__band"    data-sc2-band>
					<rect x="40" y="40" width="770" height="1020" rx="2"
					      fill="none" stroke="var(--gold-hi, #d4af37)" stroke-width="3"/>
					<rect class="sc2-border__band-inner" x="52" y="52" width="746" height="996" rx="2"
					      fill="none" stroke="var(--gold-hi, #d4af37)" stroke-width="1.25" opacity="0.85"/>
				</g>
				<!-- gilt corner besants on the inner band corners (ornate only) -->
				<g class="sc2-border__corners" data-sc2-corners>
					<g class="sc2-border__corner"><circle cx="46"  cy="46"   r="13" fill="var(--gold-hi, #d4af37)" stroke="var(--gold-deep, #9a7b1f)" stroke-width="1.5"/><circle cx="46"  cy="46"   r="5" fill="var(--border, #7c1d1d)"/></g>
					<g class="sc2-border__corner"><circle cx="804" cy="46"   r="13" fill="var(--gold-hi, #d4af37)" stroke="var(--gold-deep, #9a7b1f)" stroke-width="1.5"/><circle cx="804" cy="46"   r="5" fill="var(--border, #7c1d1d)"/></g>
					<g class="sc2-border__corner"><circle cx="804" cy="1054" r="13" fill="var(--gold-hi, #d4af37)" stroke="var(--gold-deep, #9a7b1f)" stroke-width="1.5"/><circle cx="804" cy="1054" r="5" fill="var(--border, #7c1d1d)"/></g>
					<g class="sc2-border__corner"><circle cx="46"  cy="1054" r="13" fill="var(--gold-hi, #d4af37)" stroke="var(--gold-deep, #9a7b1f)" stroke-width="1.5"/><circle cx="46"  cy="1054" r="5" fill="var(--border, #7c1d1d)"/></g>
				</g>
			</svg>
		</div>

		<!-- ===================================================================
		     PAGE — the flow group (crown + content + seal). Scaled as ONE unit
		     by sf-app.js fitPage() to fit the fixed Letter writing area, so a
		     long proclamation shrinks to fit instead of overflowing the deckle.
		     =================================================================== -->
		<div class="sc2-page" data-sc2-page>

		<!-- ===================================================================
		     CROWN (z-crown:5) — heraldic achievements flanking the title.
		     Kingdom arms = dexter (left), Park arms = sinister (right).
		     =================================================================== -->
		<header class="sc2-crown" data-sc2-crown>

			<!-- KINGDOM ARMS — dexter (heraldic right = viewer's left) -->
			<figure class="sc2-arms sc2-arms--kingdom" data-sc2-arms="kingdom"<?= $sc2_kingdom_arms === '' ? ' hidden' : '' ?>>
				<span class="sc2-arms-field">
					<img src="<?= $h($sc2_kingdom_arms) ?>"
					     alt="Arms of <?= $h($sc2_kingdom) ?>"
					     data-sc2-bind="kingdomHeraldry"
					     loading="lazy" decoding="async"
					     onerror="this.closest('.sc2-arms').classList.add('is-broken')">
				</span>
				<figcaption class="sc2-arms__label" data-sc2-bind="kingdomName"><?= $h($sc2_kingdom) ?></figcaption>
			</figure>

			<!-- PARK ARMS — sinister (heraldic left = viewer's right) -->
			<figure class="sc2-arms sc2-arms--park" data-sc2-arms="park"<?= $sc2_park_arms === '' ? ' hidden' : '' ?>>
				<span class="sc2-arms-field">
					<img src="<?= $h($sc2_park_arms) ?>"
					     alt="Arms of <?= $h($sc2_place) ?>"
					     data-sc2-bind="parkHeraldry"
					     loading="lazy" decoding="async"
					     onerror="this.closest('.sc2-arms').classList.add('is-broken')">
				</span>
				<figcaption class="sc2-arms__label" data-sc2-bind="parkName"><?= $h($sc2_place) ?></figcaption>
			</figure>

		</header>

		<!-- ===================================================================
		     CONTENT (z-content:4) — the ONLY text layer. Medieval document order.
		     =================================================================== -->
		<section class="sc2-content" data-sc2-content>

			<!-- INVOCATION -->
			<p class="sc2-invocation" data-sc2-bind="invocation">
				In the name of all that is honorable and true,
			</p>

			<!-- GRAND ILLUMINATED TITLE — the award name -->
			<h1 class="sc2-title" data-sc2-bind="awardName"><?= $h($sc2_award) ?></h1>

			<!-- INTITULATION — small-caps "We, X, Sovereign of Y" -->
			<p class="sc2-intitulation" data-sc2-bind="intitulation">
				Know all by these presents that We,
				<span class="sc2-rubric" data-sc2-bind="officer1Name"><?= $h($sc2_off1_name) ?></span>,
				<span data-sc2-bind="officer1Role"><?= $h($sc2_off1_role) ?></span><?php if ($sc2_off2_name !== ''): ?>, and
				<span class="sc2-rubric" data-sc2-bind="officer2Name"><?= $h($sc2_off2_name) ?></span><?php if ($sc2_off2_role !== ''): ?>,
				<span data-sc2-bind="officer2Role"><?= $h($sc2_off2_role) ?></span><?php endif; ?><?php endif; ?>,
				sovereigns of <span data-sc2-bind="kingdomName"><?= $h($sc2_kingdom) ?></span>,
			</p>

			<!-- BODY — justified; illuminated versal opens the first paragraph -->
			<div class="sc2-body" data-sc2-bind="narration">
				<p data-sc2-versal>Having weighed well the long and faithful labors of Our
				well-beloved
				<span class="sc2-rubric" data-sc2-bind="persona"><?= $h($sc2_persona) ?></span>,
				and finding <span data-sc2-bind="pronounThem">them</span> of singular merit in
				<span data-sc2-bind="reason"><?= $h($sc2_reason) ?></span>, We are moved to set
				down this Our charter for the lasting memory of the realm and the honor of all
				who come after.</p>
			</div>

			<!-- GRANT / DISPOSITIVE CLAUSE -->
			<p class="sc2-grant" data-sc2-bind="disposition">
				Do by this Our charter and of Our certain knowledge
				<strong class="sc2-grant__verb" data-sc2-bind="grantVerb">award and proclaim</strong>
				unto <span class="sc2-rubric" data-sc2-bind="persona"><?= $h($sc2_persona) ?></span>
				the <span class="sc2-grant__award" data-sc2-bind="awardName"><?= $h($sc2_award) ?></span>,
				with all the honors, rights, and privileges thereunto belonging, to be held and
				enjoyed throughout all Our lands.
			</p>

			<!-- DATUM — corroboration + date WRITTEN OUT + place -->
			<p class="sc2-datum" data-sc2-bind="dateClause">
				<span class="sc2-datum__corrob" data-sc2-bind="corroboration">Given under Our hand and seal</span>
				at <span class="sc2-datum__place" data-sc2-bind="parkName"><?= $h($sc2_place) ?></span>,
				<span class="sc2-datum__date" data-sc2-bind="dateWritten">in this present year of grace</span>.
			</p>

			<!-- ATTESTATION — chancery-italic signatures over a ruled line -->
			<div class="sc2-attest" data-sc2-attest>

				<div class="sc2-sig">
					<span class="sc2-sig-name" data-sc2-bind="officer1Name"><?= $h($sc2_off1_name) ?></span>
					<span class="sc2-sig-rule" aria-hidden="true"></span>
					<span class="sc2-sig-title" data-sc2-bind="officer1Role"><?= $h($sc2_off1_role) ?></span>
				</div>

				<div class="sc2-sig sc2-sig--second"<?= $sc2_off2_name === '' ? ' hidden' : '' ?> data-sc2-sig="second">
					<span class="sc2-sig-name" data-sc2-bind="officer2Name"><?= $h($sc2_off2_name) ?></span>
					<span class="sc2-sig-rule" aria-hidden="true"></span>
					<span class="sc2-sig-title" data-sc2-bind="officer2Role"><?= $h($sc2_off2_role) ?></span>
				</div>

			</div>

		</section>

		<!-- ===================================================================
		     SEAL (z-seal:6) — pendant wax seal + ribbon in the bas-de-page.
		     CSS-disc contract (hand-poured .sc2-seal-disc with recessed pan,
		     milled rim, embossed .sc2-seal-sigil); livery ribbon tails behind.
		     =================================================================== -->
		<footer class="sc2-seal-wrap" data-sc2-seal-wrap>

			<!-- Livery ribbon tails — behind the disc, in the realm's two colours -->
			<div class="sc2-seal-ribbon" aria-hidden="true">
				<span class="sc2-ribbon-tail sc2-ribbon-tail--a"></span>
				<span class="sc2-ribbon-tail sc2-ribbon-tail--b"></span>
			</div>

			<!-- The pressed-wax disc. data-tip (never native title) labels it. -->
			<div class="sc2-seal-disc" data-sc2-seal role="img"
			     aria-label="Pressed wax seal of <?= $h($sc2_kingdom) ?>"
			     data-tip="The seal of <?= $h($sc2_kingdom) ?>">
				<?php if ($sc2_player_arms !== ''): ?>
					<!-- Player device pressed into the wax. onerror → bare wax. -->
					<div class="sc2-seal-sigil" data-sc2-seal-sigil>
						<img src="<?= $h($sc2_player_arms) ?>"
						     alt="Device of <?= $h($sc2_persona) ?>"
						     data-sc2-bind="playerHeraldry"
						     loading="lazy" decoding="async"
						     onerror="this.closest('.sc2-seal-sigil').classList.add('is-broken')">
					</div>
				<?php else: ?>
					<!-- No device → embossed monogram from the recipient's initial. -->
					<div class="sc2-seal-sigil"
					     data-sc2-seal-sigil
					     data-monogram="<?= $h($sc2_monogram) ?>"
					     data-sc2-bind="playerHeraldry"></div>
				<?php endif; ?>
			</div>

			<!-- Where it was sealed — small-caps caption beneath the wax. -->
			<p class="sc2-seal-caption" data-sc2-bind="parkName">Sealed at <?= $h($sc2_place) ?></p>

		</footer>

		</div><!-- /.sc2-page -->

		<div class="sc2-art-layer" id="sc2ArtLayer" aria-hidden="true"></div>

	</article>

</main>

<!-- ===== end: sf-scroll-markup.html.part ===== -->

</div><!-- /.sc2-forge -->

<!-- ===== inlined: sf-ui.html.part [art-modal] ===== -->
<!-- ============================================================
     IN-BUILDER ARTWORK modal (sc2-art). Browse the shared library or
     upload your own image for any of the 8 fixed scroll zones.
     ============================================================ -->
<div class="sc2-art-modal" id="sc2ArtModal" role="dialog" aria-modal="true" aria-labelledby="sc2ArtTitle">
  <div class="sc2-art-dialog">
    <div class="sc2-art-head">
      <h2 id="sc2ArtTitle">Artwork — <span id="sc2ArtZoneLabel">Zone</span></h2>
      <button type="button" class="sc2-art-close" id="sc2ArtCloseX" aria-label="Close">&times;</button>
    </div>
    <div class="sc2-art-body">
      <div class="sc2-art-tabs">
        <button type="button" class="sc2-art-tab is-active" data-pane="browse">Browse Library</button>
        <button type="button" class="sc2-art-tab" data-pane="upload">Upload Your Own</button>
      </div>

      <!-- Browse pane -->
      <div class="sc2-art-pane is-active" data-pane="browse">
        <div class="sc2-art-grid" id="sc2ArtGrid"></div>
        <p class="sc2-art-status" id="sc2ArtBrowseStatus"></p>
      </div>

      <!-- Upload pane -->
      <div class="sc2-art-pane" data-pane="upload">
        <div class="sc2-art-field">
          <label for="sc2ArtFile">Choose an image (PNG, JPEG, or GIF; max 2 MB)</label>
          <input type="file" id="sc2ArtFile" accept="image/png,image/jpeg,image/gif">
        </div>
        <img class="sc2-art-preview" id="sc2ArtPreview" alt="Preview">

        <div class="sc2-art-share">
          <label><input type="checkbox" id="sc2ArtShareChk"> Share this with the Amtgard Graphics Library</label>
          <div class="sc2-art-share-reveal" id="sc2ArtShareReveal">
            <div class="sc2-art-field">
              <label>Is this design intended for Amtgard-wide use, or is it Kingdom-specific?</label>
              <div class="sc2-art-tier" id="sc2ArtTier" role="group" aria-label="Sharing tier">
                <button type="button" data-tier="global" class="is-active">Amtgard</button>
                <button type="button" data-tier="kingdom">Kingdom</button>
              </div>
              <p class="sc2-art-status" id="sc2ArtTierNote">Amtgard-wide submissions are reviewed by ORK admins.</p>
            </div>
            <div class="sc2-art-field">
              <label for="sc2ArtName">Name</label>
              <input type="text" id="sc2ArtName" maxlength="120" placeholder="e.g. Celtic knot border">
            </div>
            <div class="sc2-art-field">
              <label for="sc2ArtTags">Tags (comma-separated)</label>
              <input type="text" id="sc2ArtTags" maxlength="240" placeholder="e.g. celtic, border, gold">
            </div>
            <div class="sc2-art-field">
              <label for="sc2ArtCategory">Category (optional)</label>
              <select id="sc2ArtCategory"><option value="">— None —</option></select>
            </div>
            <div class="sc2-art-license" id="sc2ArtLicense"></div>
            <div class="sc2-art-field">
              <label><input type="checkbox" id="sc2ArtAgree"> I have read and agree to the license terms above.</label>
            </div>
            <div class="sc2-art-field">
              <label for="sc2ArtSigner">Type your full legal name as your electronic signature</label>
              <input type="text" id="sc2ArtSigner" maxlength="120" placeholder="Full legal name">
            </div>
          </div>
        </div>
      </div>
    </div>
    <div class="sc2-art-foot">
      <span class="sc2-art-status" id="sc2ArtFootStatus"></span>
      <span>
        <button type="button" class="sc2-art-btn ghost" id="sc2ArtClearBtn">Remove from Zone</button>
        <button type="button" class="sc2-art-btn" id="sc2ArtUseBtn" disabled>Use on My Scroll</button>
      </span>
    </div>
  </div>
</div>

<!-- ===== end: sf-ui.html.part [art-modal] ===== -->


<!-- ============================================================
     SCROLL FORGE data bootstrap. The legacy sc- builder was removed;
     these two server-emitted globals are all the new renderer carried
     over from it (family palette data + the scroll config).
     ============================================================ -->
<script id="sf-forge-data">
window.SC_FAMILIES = <?= file_get_contents(__DIR__ . '/scroll/families.json') ?>;
var SgConfig = <?= json_encode($sgConfig, JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS) ?>;
</script>

<!-- ============================================================
     SCROLL FORGE app bootstrap (new renderer JS).
     ============================================================ -->
<script id="sf-forge-app">
/* ============================================================================
   THE LETTERED SCROLL — sf-app.js.part
   ----------------------------------------------------------------------------
   Live application controller for the HTML/CSS/inline-SVG scroll renderer
   ("scroll-forge"). This partial is inlined RAW (no <script> wrapper) into
   orkui/template/revised-frontend/Scroll_builder.tpl by the finalizer.

   OWNS:
     • Two-way live binding: control-panel fields  ->  scroll text surfaces.
     • Family switching: writes [data-family] on .sc2-scroll and re-themes.
     • Heraldry: image href wiring + graceful fallback (kingdom/park/player).
     • Auto-fit: scales .sc2-scroll into .sc2-stage on resize / family change.
     • Export: window.print() (PDF) + PNG via window.html2canvas (lazy CDN),
       both honoring the .sf-export-mode class on .sc2-scroll.
     • Period proclamation copy assembly from SgConfig + live overrides.

   MEDIUM IS LOCKED: this script never touches <canvas>; it only mutates DOM
   text/attributes that the CSS + inline-SVG partials render.

   DEFENSIVE CONTRACT (locked):
     • IIFE guard is a CONFIG FLAG / feature check — NEVER getElementById at the
       top (external/inlined script may run before late modal markup exists).
     • Every DOM lookup is null-guarded; every SgConfig key is optional with a
       sane fallback (never a blank surface, never a raw ISO date).
     • Never throws if optional elements/data are missing.
     • No native title tooltips (UI uses data-tip elsewhere); this file adds
       none.
   ============================================================================ */
(function () {
	"use strict";

	/* ── 0. GUARD ────────────────────────────────────────────────────────────
	   Run only when the scroll-forge config is present. SgConfig is emitted by
	   the .tpl regardless of late modal markup, so it is a SAFE guard — unlike
	   getElementById, which would fail when this inlined script executes before
	   DOM nodes defined further down the template exist.                      */
	var SG = (typeof window !== "undefined" && window.SgConfig) ? window.SgConfig : null;
	if (!SG) { return; }

	/* Re-entrancy guard: the finalizer may inline this block more than once if
	   the template is edited carelessly. Initialize at most once.            */
	if (window.__SF_APP_BOOTED__) { return; }
	window.__SF_APP_BOOTED__ = true;

	/* ── 1. TINY DOM HELPERS (all null-safe) ─────────────────────────────── */
	function $(sel, root) {
		try { return (root || document).querySelector(sel); }
		catch (e) { return null; }
	}
	function $all(sel, root) {
		try { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); }
		catch (e) { return []; }
	}
	function on(el, evt, fn, opts) {
		if (el && el.addEventListener) { el.addEventListener(evt, fn, opts || false); }
	}
	function setText(el, txt) {
		if (el) { el.textContent = (txt == null ? "" : String(txt)); }
	}
	function setHTML(el, html) {
		if (el) { el.innerHTML = (html == null ? "" : String(html)); }
	}
	function attr(el, name, val) {
		if (!el) { return null; }
		if (typeof val === "undefined") { return el.getAttribute(name); }
		el.setAttribute(name, val == null ? "" : String(val));
		return val;
	}
	function addClass(el, c) { if (el && el.classList) { el.classList.add(c); } }
	function rmClass(el, c) { if (el && el.classList) { el.classList.remove(c); } }
	function hasClass(el, c) { return !!(el && el.classList && el.classList.contains(c)); }
	function val(el) {
		if (!el) { return ""; }
		return (typeof el.value === "string") ? el.value : "";
	}
	function pick(/* ...candidates */) {
		for (var i = 0; i < arguments.length; i++) {
			var v = arguments[i];
			if (v != null && String(v).trim() !== "") { return String(v).trim(); }
		}
		return "";
	}
	function debounce(fn, ms) {
		var t = null;
		return function () {
			var ctx = this, args = arguments;
			if (t) { clearTimeout(t); }
			t = setTimeout(function () { t = null; fn.apply(ctx, args); }, ms || 80);
		};
	}
	function esc(s) {
		return String(s == null ? "" : s)
			.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
			.replace(/"/g, "&quot;").replace(/'/g, "&#39;");
	}
	function dbg() {
		/* Debug -> browser console only (never error_log). Silent unless flag. */
		if (window.__SF_DEBUG__ && window.console && console.log) {
			try { console.log.apply(console, ["[scroll-forge]"].concat([].slice.call(arguments))); }
			catch (e) {}
		}
	}

	/* ── 1b. IN-BUILDER ARTWORK constants ────────────────────────────────────
	   Zone geometry as % of .sc2-scroll (derived from
	   ScrollArtwork::SLOT_DIMENSIONS / 2550x3300). License string is emitted
	   server-side into SgConfig.artLicense (see $sgConfig).                   */
	var ART_ZONES = {
		watermark:    { l:0,      t:0,      w:100,    h:100,    z:1, op:0.10, label:'Watermark' },
		full_border:  { l:0,      t:0,      w:100,    h:100,    z:2, op:1.00, label:'Full Border' },
		border_top:   { l:0,      t:0,      w:100,    h:12.121, z:3, op:1.00, label:'Top Border' },
		border_bottom:{ l:0,      t:87.879, w:100,    h:12.121, z:3, op:1.00, label:'Bottom Border' },
		border_left:  { l:0,      t:0,      w:11.765, h:100,    z:3, op:1.00, label:'Left Border' },
		border_right: { l:88.235, t:0,      w:11.765, h:100,    z:3, op:1.00, label:'Right Border' },
		top_graphic:  { l:34.314, t:1.515,  w:31.373, h:15.152, z:4, op:1.00, label:'Top Graphic' },
		center_image: { l:26.471, t:31.818, w:47.059, h:36.364, z:5, op:0.15, label:'Center Image' }
	};
	var ART_LICENSE = (SG && SG.artLicense) ? SG.artLicense : '';

	/* ── 2. ROOTS (resolved lazily so we never hard-fail at parse time) ───── */
	var APP = null, PANEL = null, STAGE = null, SCROLL = null;
	function resolveRoots() {
		APP = $(".sc2-app");
		PANEL = $(".sc2-panel");
		STAGE = $(".sc2-stage");
		SCROLL = $(".sc2-scroll");
		return !!SCROLL; /* the sheet is the one element we truly require */
	}

	/* ── 3. FAMILY MODEL ─────────────────────────────────────────────────── */
	var FAMILY_KEYS = [
		"hibernian_knotwork", "northern_gothic", "provencal_bestiary",
		"crimson_decree", "forest_reverie", "charred_edict",
		"imperial_edict", "scholars_hand", "crusaders_charter", "astral_codex"
	];
	function isFamilyKey(k) { return FAMILY_KEYS.indexOf(k) !== -1; }

	/* Knight award ids -> crimson_decree (matches legacy auto-pick logic).   */
	var KNIGHT_AWARD_IDS = [17, 18, 19, 20, 245];

	function families() {
		/* Reuse the SAME families JSON the legacy path inlines; never fork it. */
		var f = window.SC_FAMILIES;
		if (typeof f === "string") { try { f = JSON.parse(f); } catch (e) { f = null; } }
		return (f && typeof f === "object") ? f : {};
	}
	function familyMeta(key) {
		var all = families();
		return (all && all[key]) ? all[key] : null;
	}

	/* Resolve the initial family from explicit config, then award id, then the
	   A/B/C autoTemplate, then a safe order default.                         */
	function initialFamily() {
		var explicit = pick(SG.family, attr(SCROLL, "data-family"));
		if (isFamilyKey(explicit)) { return explicit; }

		var aid = parseInt(SG.awardsId, 10);
		if (!isNaN(aid) && KNIGHT_AWARD_IDS.indexOf(aid) !== -1) { return "crimson_decree"; }

		if (SG.isTitle === true) { return "northern_gothic"; }
		if (SG.isLadder === true) { return "hibernian_knotwork"; }

		switch (String(SG.autoTemplate || "").toUpperCase()) {
			case "A": return "crimson_decree";     /* knight  */
			case "C": return "northern_gothic";    /* title   */
			case "B": return "hibernian_knotwork"; /* order   */
			default:  return "hibernian_knotwork";
		}
	}

	/* ── 4. STATE (single source of truth for live text) ─────────────────── */
	var state = {
		family:      "hibernian_knotwork",
		orientation: pick(SG.orientation, attr(SCROLL, "data-orientation"), "portrait"),
		intensity:   pick(SG.intensity, attr(SCROLL, "data-intensity"), "balanced"),
		persona:     pick(SG.persona, "the Bearer of this Scroll"),
		awardName:   pick(SG.awardName, "a Token of Esteem"),
		rank:        parseInt(SG.rank, 10) || 0,
		date:        pick(SG.date, ""),                 /* YYYY-MM-DD */
		givenBy:     pick(SG.givenBy, firstOfficerName("Monarch"), firstOfficerName(), ""),
		givenByRole: pick(firstOfficerRole(SG.givenBy), "Crown"),
		parkName:    pick(SG.parkName, "Our realm"),
		kingdomName: pick(SG.kingdomName, "the Kingdom"),
		note:        pick(SG.note, "service to Our realm"),
		isTitle:     SG.isTitle === true,
		isLadder:    SG.isLadder === true,
		artwork:     {}   // zone -> { id?, url?, raw? }  (raw = data-URL for ephemeral uploads)
	};

	function firstOfficerName(roleSubstr) {
		var list = (SG.preloadOfficers && SG.preloadOfficers.length) ? SG.preloadOfficers : [];
		for (var i = 0; i < list.length; i++) {
			var o = list[i] || {};
			if (!roleSubstr) { if (o.Persona) { return o.Persona; } continue; }
			if (o.Role && String(o.Role).indexOf(roleSubstr) !== -1 && o.Persona) { return o.Persona; }
		}
		return "";
	}
	function firstOfficerRole(persona) {
		var list = (SG.preloadOfficers && SG.preloadOfficers.length) ? SG.preloadOfficers : [];
		for (var i = 0; i < list.length; i++) {
			var o = list[i] || {};
			if (persona && o.Persona === persona && o.Role) { return o.Role; }
		}
		var first = list[0] || {};
		return first.Role || "";
	}

	/* ── 5. DATE: write the date out in words (NEVER show raw ISO) ────────── */
	var MONTHS = ["January", "February", "March", "April", "May", "June", "July",
		"August", "September", "October", "November", "December"];

	function ordinal(n) {
		var s = ["th", "st", "nd", "rd"], v = n % 100;
		return n + (s[(v - 20) % 10] || s[v] || s[0]);
	}
	function ordinalWords(n) {
		var ONES = ["", "first", "second", "third", "fourth", "fifth", "sixth",
			"seventh", "eighth", "ninth", "tenth", "eleventh", "twelfth",
			"thirteenth", "fourteenth", "fifteenth", "sixteenth", "seventeenth",
			"eighteenth", "nineteenth", "twentieth"];
		var TENS = ["", "", "twentieth", "thirtieth"];
		var TENS_C = ["", "", "twenty", "thirty"];
		if (n <= 20) { return ONES[n] || ordinal(n); }
		var t = Math.floor(n / 10), o = n % 10;
		if (o === 0) { return TENS[t] || ordinal(n); }
		return (TENS_C[t] ? TENS_C[t] + "-" + (ONES[o] || "") : ordinal(n));
	}
	function parseISO(iso) {
		if (!iso) { return null; }
		var m = String(iso).match(/^(\d{4})-(\d{2})-(\d{2})/);
		if (!m) {
			var d = new Date(iso);
			return isNaN(d.getTime()) ? null : d;
		}
		var dt = new Date(parseInt(m[1], 10), parseInt(m[2], 10) - 1, parseInt(m[3], 10));
		return isNaN(dt.getTime()) ? null : dt;
	}
	function dateWrittenOut(iso) {
		var d = parseISO(iso) || new Date();
		var day = ordinalWords(d.getDate());
		var month = MONTHS[d.getMonth()] || "";
		var year = d.getFullYear();
		/* period register: "the {ordinal} day of {Month}, in the year of our
		   reckoning {year}". Capitalize the leading ordinal word.            */
		var dayCap = day.charAt(0).toUpperCase() + day.slice(1);
		return "the " + dayCap + " day of " + month +
			", in the year of our reckoning " + year;
	}
	function dateShort(iso) {
		var d = parseISO(iso) || new Date();
		return ordinal(d.getDate()) + " " + (MONTHS[d.getMonth()] || "") + " " + d.getFullYear();
	}

	/* ── 6. PROCLAMATION COPY (period register; subtle per-family tone) ───── */
	/* Tone profiles: register flips between royal decree, fae charter, and
	   scholarly diploma depending on the chosen family. Always defensive —
	   blanks resolve to sane period phrasing, never empty strings.           */
	var TONES = {
		crimson_decree:    "royal",
		imperial_edict:    "royal",
		northern_gothic:   "royal",
		crusaders_charter: "royal",
		charred_edict:     "royal",
		forest_reverie:    "fae",
		provencal_bestiary:"fae",
		hibernian_knotwork:"fae",
		astral_codex:      "scholar",
		scholars_hand:     "scholar"
	};
	function toneOf(key) { return TONES[key] || "royal"; }

	function grantVerb() {
		if (state.isTitle) { return "do confer and bestow"; }
		if (state.isLadder) { return "do advance and elevate"; }
		return "do grant and award";
	}

	function rankPhrase() {
		if (!state.rank || state.rank <= 0) { return ""; }
		return " of the " + ordinalWords(state.rank) + " rank";
	}

	function buildCopy() {
		var tone = toneOf(state.family);
		var persona = pick(state.persona, "the Bearer of this Scroll");
		var award = pick(state.awardName, "a Token of Esteem");
		var kingdom = pick(state.kingdomName, "the Kingdom");
		var park = pick(state.parkName, "Our realm");
		var note = pick(state.note, "service to Our realm");
		var giver = pick(state.givenBy, "the Crown");
		var giverRole = pick(state.givenByRole, "Crown");

		var c = {};

		/* INVOCATION — the opening flourish above the title.                  */
		if (tone === "fae") {
			c.invocation = "By leaf and by light, let it be sung —";
		} else if (tone === "scholar") {
			c.invocation = "Know all who read these letters —";
		} else {
			c.invocation = "Know all by these presents —";
		}

		/* TITLE — the award itself.                                          */
		c.title = award;

		/* INTITULATION — small-caps line of the granting authority.          */
		if (tone === "fae") {
			c.intitulation = "the Court and Conclave of " + kingdom;
		} else if (tone === "scholar") {
			c.intitulation = "the Fellowship and Faculty of " + kingdom;
		} else {
			c.intitulation = "the Crown and Realm of " + kingdom;
		}

		/* BODY — versal opens here. {persona} is rubricated (wrapped in a
		   <span class="sc2-rubric">).                                         */
		var personaSpan = '<span class="sc2-rubric">' + esc(persona) + "</span>";
		if (tone === "fae") {
			c.bodyHTML =
				"Hearken, gentlefolk and wanderers of the wood, for upon this leaf is " +
				"bound a true telling. Whereas " + personaSpan + " has walked among us with " +
				"open hand and steadfast heart, and whereas the deeds of the same — namely " +
				esc(note) + " — have not gone unmarked beneath the canopy of " +
				esc(park) + ", we are moved to set down this remembrance for all the seasons to come.";
		} else if (tone === "scholar") {
			c.bodyHTML =
				"Be it known and recorded that " + personaSpan + ", having demonstrated " +
				"diligence, learning, and merit in full measure, and whereas the works of the " +
				"same — namely " + esc(note) + " — have been examined and found worthy within " +
				"the halls of " + esc(park) + ", we do herein attest and certify the same.";
		} else {
			c.bodyHTML =
				"Be it known to all true folk of high and low estate that " + personaSpan +
				", having rendered unto " + esc(park) + " faithful and exemplary " +
				"service — namely " + esc(note) + " — and having borne themselves with honour " +
				"in the sight of the Crown, has merited the regard and gratitude of the Realm.";
		}

		/* GRANT — dispositive clause; award name accented.                    */
		var awardSpan = '<span class="sc2-grant-award">' + esc(award) + "</span>";
		c.grantHTML = "Wherefore We " + grantVerb() + " unto the same the honour of " +
			awardSpan + rankPhrase() + ", with all rights, styles, and privileges thereunto belonging.";

		/* DATUM — date written out + place, period form.                     */
		c.datum = "Given under our hand and seal at " + park + ", " +
			dateWrittenOut(state.date) + ".";

		/* ATTESTATION — signature name + title line.                          */
		c.signName = giver;
		c.signTitle = giverRole ? (giverRole + " of " + kingdom) : ("for " + kingdom);

		return c;
	}

	/* ── 7. RENDER COPY -> DOM ───────────────────────────────────────────── */
	function renderCopy() {
		if (!SCROLL) { return; }
		var c = buildCopy();
		setText($(".sc2-invocation", SCROLL), c.invocation);
		setText($(".sc2-title", SCROLL), c.title);
		setText($(".sc2-intitulation", SCROLL), c.intitulation);

		/* body uses the first <p> for the versal drop-cap; keep it as the
		   first-of-type paragraph so ::first-letter targets the right glyph. */
		var bodyWrap = $(".sc2-body", SCROLL);
		if (bodyWrap) {
			var p = $("p", bodyWrap);
			if (!p) { p = document.createElement("p"); bodyWrap.appendChild(p); }
			setHTML(p, c.bodyHTML);
		}

		setHTML($(".sc2-grant", SCROLL), c.grantHTML);
		setText($(".sc2-datum", SCROLL), c.datum);

		/* attestation: write the primary signer's name + title into the first
		   .sc2-sig block (markup/CSS contract: .sc2-sig__name / .sc2-sig__title
		   over a .sc2-sig__line). We populate sig #1 from the live copy and
		   leave any server-seeded sig #2 (a second officer) untouched. */
		var attest = $(".sc2-attest", SCROLL);
		if (attest) {
			var firstSig = $(".sc2-sig", attest);
			if (firstSig) {
				setText($(".sc2-sig-name", firstSig), c.signName);
				setText($(".sc2-sig-title", firstSig), c.signTitle);
			}
		}
	}

	/* ── 8. FAMILY APPLY ─────────────────────────────────────────────────── */
	function applyFamily(key, opts) {
		if (!isFamilyKey(key)) { key = "hibernian_knotwork"; }
		state.family = key;
		if (SCROLL) {
			attr(SCROLL, "data-family", key);
			/* orientation may be family-driven (landscape diplomas etc.).
			   Only adopt the family default when the caller did not ask us to
			   preserve the current orientation (keepOrientation).            */
			var keepOrient = !!(opts && opts.keepOrientation);
			var meta = familyMeta(key);
			if (!keepOrient && meta && meta.orientation) {
				state.orientation = (meta.orientation === "landscape") ? "landscape" : "portrait";
			}
			attr(SCROLL, "data-orientation", state.orientation);
			attr(SCROLL, "data-intensity", state.intensity);
		}
		/* re-letter (tone shifts) + re-fit (geometry may change) + reseat arms */
		renderCopy();
		wireHeraldry();
		scheduleFit();
		/* reflect active state in any family chooser chips/select */
		reflectFamilyControls(key);
		dbg("family ->", key, "tone", toneOf(key), "orient", state.orientation);
	}

	function reflectFamilyControls(key) {
		/* Family chooser is a radiogroup of .sc2-fam__swatch[data-family] buttons.
		   Reflect the active state via aria-checked (true on the match, false on
		   the rest); also toggle an is-active class for any CSS that wants it.   */
		$all(".sc2-fam__swatch[data-family]").forEach(function (el) {
			var isActive = (el.getAttribute("data-family") === key);
			if (el.classList) { el.classList.toggle("is-active", isActive); }
			el.setAttribute("aria-checked", isActive ? "true" : "false");
		});
	}

	/* Paint each family chip's 4 preview bands from its true palette so every
	   swatch previews its own family rather than the shared hardcoded fallback
	   in sf-panel.css.part. Static per chip — call once at init, NOT inside
	   applyFamily. Inline backgroundColor beats the panel CSS; the hardcoded
	   bands remain a no-JS fallback. Fully null-safe / guarded on SC_FAMILIES.  */
	function recolorFamilySwatches() {
		if (!window.SC_FAMILIES) { return; }
		var all = families();
		$all(".sc2-fam__swatch[data-family]").forEach(function (el) {
			var key = el.getAttribute("data-family");
			if (!key) { return; }
			var fam = all && all[key];
			var p = fam && fam.palette;
			if (!p) { return; }
			var bands = el.querySelectorAll ? el.querySelectorAll(".sc2-fam__band") : null;
			if (!bands || !bands.length) { return; }
			/* fixed order: band1 vellum bg, band2 gold, band3 accent (or border),
			   band4 wax. Guard each index so a short band list never throws.     */
			var colors = [p.bg, p.gold, (p.accent || p.border), p.wax];
			for (var i = 0; i < 4 && i < bands.length; i++) {
				if (bands[i] && colors[i]) { bands[i].style.backgroundColor = colors[i]; }
			}
		});
	}

	/* ── 9. HERALDRY (href wiring + graceful fallback) ───────────────────── */
	function padId(id, width) {
		var s = String(parseInt(id, 10) || 0);
		while (s.length < width) { s = "0" + s; }
		return s;
	}
	function reconstructHeraldry(kind) {
		/* Rebuild a heraldry URL from the *Base + padded id (used on toggle). */
		var base, id, w;
		if (kind === "kingdom") { base = SG.heraldryKingdomBase; id = SG.kingdomId; w = 4; }
		else if (kind === "park") { base = SG.heraldryParkBase; id = SG.parkId; w = 5; }
		else { base = SG.heraldryPlayerBase; id = SG.mundaneId; w = 6; }
		if (!base) { return ""; }
		return base + padId(id, w) + ".jpg";
	}
	function fallbackHeraldry(kind) {
		if (kind === "kingdom") {
			return (SG.heraldryKingdomBase || "") + "0000.jpg";
		} else if (kind === "park") {
			return (SG.heraldryParkBase || "") + "00000.jpg";
		}
		return (SG.heraldryPlayerBase || "") + "000000.jpg";
	}
	function setImageHref(node, url) {
		if (!node || !url) { return; }
		var tag = (node.tagName || "").toLowerCase();
		if (tag === "image") {
			try { node.setAttributeNS("http://www.w3.org/1999/xlink", "href", url); } catch (e) {}
			node.setAttribute("href", url);
		} else {
			node.setAttribute("src", url);
			node.setAttribute("alt", ""); /* decorative; no title tooltip */
		}
	}
	function wireOneArms(figSel, primaryUrl, kind) {
		var fig = $(figSel, SCROLL);
		if (!fig) { return; }
		var url = pick(primaryUrl, reconstructHeraldry(kind), fallbackHeraldry(kind));
		if (!url) { addClass(fig, "sc2-arms--empty"); return; }

		/* prefer an inline-SVG <image> (illumination layer draws the shield);
		   fall back to a plain <img> if the markup uses one.                  */
		var svgImg = fig.querySelector ? fig.querySelector("image") : null;
		var htmlImg = fig.querySelector ? fig.querySelector("img") : null;

		var applied = false;
		if (svgImg) { setImageHref(svgImg, url); applied = true; }
		if (htmlImg) {
			setImageHref(htmlImg, url);
			classifyArmsBg(htmlImg, fig);
			/* graceful fallback chain on error */
			htmlImg.onerror = (function (kindLocal, imgEl) {
				var stage = 0;
				return function () {
					stage++;
					if (stage === 1) {
						var r = reconstructHeraldry(kindLocal);
						if (r && r !== imgEl.getAttribute("src")) { imgEl.setAttribute("src", r); return; }
						stage++; /* fall through to fallback */
					}
					if (stage === 2) {
						var fb = fallbackHeraldry(kindLocal);
						if (fb && fb !== imgEl.getAttribute("src")) { imgEl.setAttribute("src", fb); return; }
					}
					imgEl.onerror = null;
					addClass(imgEl.closest ? imgEl.closest("figure") : null, "sc2-arms--empty");
				};
			})(kind, htmlImg);
			applied = true;
		}
		if (applied) { rmClass(fig, "sc2-arms--empty"); }
	}
	function wireHeraldry() {
		if (!SCROLL) { return; }
		wireOneArms(".sc2-arms--kingdom", SG.kingdomHeraldry, "kingdom");
		wireOneArms(".sc2-arms--park", SG.parkHeraldry, "park");
		/* optional player device in the seal / center */
		var sealDevice = $(".sc2-seal-device image", SCROLL) || $(".sc2-seal-device img", SCROLL);
		if (sealDevice) {
			var purl = pick(SG.playerHeraldry, reconstructHeraldry("player"), fallbackHeraldry("player"));
			setImageHref(sealDevice, purl);
		}
	}

	/* Remove a WHITE background from a raster device by editing the IMAGE DATA:
	   sample the corners; if it's a white-bg raster (no transparent corner + at
	   least two opaque-white corners — heater shields touch the TOP corners with
	   shield colour, white only at the bottom), repaint it with near-white pixels
	   turned transparent and swap in the result as a transparent PNG. The device
	   then sits on ANY family ground with no square, no patch, no clip, no blend
	   — and identically to a real transparent PNG, so it's consistent everywhere.
	   Same-origin canvas; on any failure (CORS taint / not decoded) we leave the
	   image untouched. Idempotent via the data-sf-dewhite marker. */
	function classifyArmsBg(img, fig) {
		if (!img) { return; }
		function run() {
			/* already de-whited (src is a data: URL) — don't reprocess. A family
			   switch re-wires the ORIGINAL http src, which correctly re-triggers
			   this (so the white never comes back). */
			if (img.src.lastIndexOf("data:", 0) === 0) { return; }
			try {
				var w = img.naturalWidth, h = img.naturalHeight;
				if (!w || !h) { return; }
				/* cheap corner probe first */
				var n = 10, sc = document.createElement("canvas");
				sc.width = n; sc.height = n;
				var sx = sc.getContext("2d");
				if (!sx) { return; }
				sx.drawImage(img, 0, 0, n, n);
				var sd = sx.getImageData(0, 0, n, n).data;
				var corners = [0, (n - 1) * 4, n * (n - 1) * 4, (n * n - 1) * 4];
				var white = 0, clear = 0;
				for (var i = 0; i < corners.length; i++) {
					var p = corners[i];
					if (sd[p + 3] < 28) { clear++; }
					else if (sd[p] > 238 && sd[p + 1] > 238 && sd[p + 2] > 238) { white++; }
				}
				if (!(clear === 0 && white >= 2)) { return; }   /* transparent/coloured → leave */
				/* white-bg → knock near-white pixels out to transparent, full-res */
				var cv = document.createElement("canvas");
				cv.width = w; cv.height = h;
				var cx = cv.getContext("2d");
				cx.drawImage(img, 0, 0);
				var id = cx.getImageData(0, 0, w, h), d = id.data;
				for (var j = 0; j < d.length; j += 4) {
					if (d[j] > 238 && d[j + 1] > 238 && d[j + 2] > 238) { d[j + 3] = 0; }
				}
				cx.putImageData(id, 0, 0);
				img.removeAttribute("crossorigin");
				img.src = cv.toDataURL("image/png");   /* src now data: → run() returns next time */
			} catch (e) { /* tainted/undecodable — leave the image as-is */ }
		}
		/* Trigger on EVERY src load + watch the src attribute. A family switch
		   re-wires the original http src (undoing the de-white); the load listener
		   AND the MutationObserver both catch that and re-process, so the white can
		   never persist on one shield while the other is clean. decode() covers the
		   `complete-but-not-decoded` race. Wired once per element (it's reused). */
		function trigger() {
			if (img.complete && img.naturalWidth) { run(); }
			else if (img.decode) { img.decode().then(run).catch(function () {}); }
		}
		if (!img.__sfDewhiteWired) {
			img.__sfDewhiteWired = true;
			on(img, "load", run);
			if (window.MutationObserver) {
				try {
					var mo = new MutationObserver(trigger);
					mo.observe(img, { attributes: true, attributeFilter: ["src"] });
				} catch (e) {}
			}
		}
		trigger();
	}

	/* Re-run de-whiting across all arms — idempotent (skips already-marked). Called
	   on a short delay after boot to catch any image not decoded when first wired. */
	function reclassifyArms() {
		if (!SCROLL) { return; }
		$all(".sc2-arms .sc2-arms-field > img", SCROLL).forEach(function (img) {
			var fig = img.closest ? img.closest(".sc2-arms") : null;
			if (fig) { classifyArmsBg(img, fig); }
		});
	}

	/* ── 10. AUTO-FIT (scale the sheet into the stage) ───────────────────── */
	var fitRAF = null;
	var fitTimer = null;
	function runFit() {
		if (fitRAF && window.cancelAnimationFrame) { try { window.cancelAnimationFrame(fitRAF); } catch (e) {} }
		fitRAF = null;
		if (fitTimer) { clearTimeout(fitTimer); fitTimer = null; }
		fitPage();
		fitScroll();
	}
	function scheduleFit() {
		/* Schedule via rAF (smooth) AND a setTimeout fallback. rAF is PAUSED in
		   background/hidden tabs, so a rAF-only scheduler would get stuck with
		   fitRAF never clearing (the page would never fit if it inits while
		   backgrounded). The timer guarantees the fit runs either way; whichever
		   fires first clears the other. */
		if (fitRAF || fitTimer) { return; }
		if (window.requestAnimationFrame) {
			fitRAF = window.requestAnimationFrame(runFit);
		}
		fitTimer = setTimeout(runFit, 80);
	}

	/* ── CONTENT-FIT ──────────────────────────────────────────────────────────
	   The sheet is a FIXED Letter page; a long proclamation would overflow the
	   writing area (and get clipped by overflow:hidden). fitPage() scales the
	   .sc2-page flow group down (never up) so the whole composition fits the
	   fixed page. It scales by HEIGHT (the limiting axis) about the top so the
	   crown stays put. Width also constrained so a wide line can't bleed.       */
	function fitPage() {
		if (!SCROLL) { return; }
		var page = $(".sc2-page", SCROLL);
		if (!page) { return; }
		/* Reset transform before measuring so each run measures honestly. */
		page.style.removeProperty("transform");
		/* The writing area is the .sc2-page box (fixed by its `inset`):
		   clientHeight = available height, scrollHeight = natural content height. */
		var availH = page.clientHeight || 1;
		var natH = page.scrollHeight || availH;
		var scale = Math.min(availH / natH, 1);   /* height is limiting; never upscale */
		if (!isFinite(scale) || scale <= 0) { scale = 1; }
		if (scale < 0.999) {
			/* Scale the fixed-width writing block about its TOP CENTRE. The box
			   keeps its writing-area width, so scaling shrinks it symmetrically —
			   the composition stays horizontally centred and anchored at the top
			   (crown stays put). NO width compensation: widening a left+right
			   anchored absolute box drifts it sideways under a centre origin. */
			page.style.transform = "scale(" + scale.toFixed(4) + ")";
		}
		dbg("fitPage", { availH: availH, natH: natH, scale: scale });
	}
	function fitScroll() {
		if (!STAGE || !SCROLL) { return; }
		/* During export we render at natural/print scale — never down-fit. */
		if (hasClass(SCROLL, "sf-export-mode")) {
			SCROLL.style.removeProperty("transform");
			return;
		}
		/* Reset transform to measure the sheet's natural size honestly. */
		SCROLL.style.transform = "none";

		var sw = SCROLL.offsetWidth || 1;
		var sh = SCROLL.offsetHeight || 1;

		/* available area inside the stage, minus a little breathing padding */
		var pad = 28;
		var aw = (STAGE.clientWidth || sw) - pad * 2;
		var ah = (STAGE.clientHeight || sh) - pad * 2;
		if (aw <= 0) { aw = sw; }
		if (ah <= 0) { ah = sh; }

		var scale = Math.min(aw / sw, ah / sh, 1); /* never upscale past 1:1 */
		if (!isFinite(scale) || scale <= 0) { scale = 1; }

		if (scale >= 0.999) {
			SCROLL.style.removeProperty("transform");
			SCROLL.style.removeProperty("transform-origin");
		} else {
			SCROLL.style.transformOrigin = "top center";
			SCROLL.style.transform = "scale(" + scale.toFixed(4) + ")";
		}
		/* expose the scale so the stage CSS can reserve scaled height if needed. */
		try { STAGE.style.setProperty("--sf-fit-scale", String(scale)); }
		catch (e) {}
		dbg("fit", { sw: sw, sh: sh, aw: aw, ah: ah, scale: scale });
	}

	/* ── 11. CONTROL BINDING (two-way: panel -> state -> scroll) ─────────── */
	/* The control panel (sf-ui.html.part) is the source of truth for selectors:
	     • text fields   -> [data-sc2-field="<stateKey>"]
	     • family swatch -> .sc2-fam__swatch[data-family]
	     • segmented     -> [data-sc2-seg="orientation|intensity|seal"] > input[radio]
	     • toggles       -> [data-sc2-toggle="heraldry|curl"] (checkbox)
	   No legacy data-sf-* / id-based hooks remain in the markup, so bind here.  */

	var liveUpdate = debounce(function () { renderCopy(); scheduleFit(); }, 60);

	/* Preset wax palettes for the seal group. Only --wax is authoritative; we
	   derive a light/dark pair so the SVG seal gradient still reads correctly
	   when a preset overrides the family wax. "family" removes the overrides.  */
	var WAX_PRESETS = {
		crimson: "#8c1d1b",
		oxblood: "#5a0f0f",
		forest:  "#1f4d2e",
		azure:   "#1e3a6e",
		violet:  "#43286e",
		gold:    "#b8862b",
		sable:   "#241c15"
	};
	function clampByte(n) { return n < 0 ? 0 : (n > 255 ? 255 : Math.round(n)); }
	function shiftHex(hex, amt) {
		var m = /^#?([0-9a-f]{6})$/i.exec(String(hex || ""));
		if (!m) { return hex; }
		var n = parseInt(m[1], 16);
		var r = clampByte(((n >> 16) & 0xff) + amt);
		var g = clampByte(((n >> 8) & 0xff) + amt);
		var b = clampByte((n & 0xff) + amt);
		var out = ((r << 16) | (g << 8) | b).toString(16);
		while (out.length < 6) { out = "0" + out; }
		return "#" + out;
	}
	function applySealWax(value) {
		if (!SCROLL) { return; }
		attr(SCROLL, "data-seal-wax", value || "family");
		if (value && value !== "family" && WAX_PRESETS[value]) {
			var base = WAX_PRESETS[value];
			try {
				SCROLL.style.setProperty("--wax", base);
				SCROLL.style.setProperty("--wax-hi", shiftHex(base, 40));
				SCROLL.style.setProperty("--wax-lo", shiftHex(base, -40));
			} catch (e) {}
		} else {
			/* "family" — drop inline overrides so the family CSS wax wins. */
			try {
				SCROLL.style.removeProperty("--wax");
				SCROLL.style.removeProperty("--wax-hi");
				SCROLL.style.removeProperty("--wax-lo");
			} catch (e) {}
		}
	}

	/* read the checked radio value within a [data-sc2-seg="<name>"] wrapper */
	function checkedSegValue(name) {
		var radios = $all('[data-sc2-seg="' + name + '"] input[type="radio"]');
		for (var i = 0; i < radios.length; i++) {
			if (radios[i].checked) { return radios[i].value; }
		}
		return "";
	}

	function bindControls() {
		/* ── text fields: live two-way binding via [data-sc2-field] ───────── */
		$all("[data-sc2-field]").forEach(function (el) {
			var key = el.getAttribute("data-sc2-field");
			if (!key) { return; }
			/* seed the field's value from state only when the markup left it
			   empty (never clobber a server-seeded value).                    */
			if (typeof el.value === "string" && el.value === "" && state[key] != null) {
				el.value = String(state[key]);
			}
			var handler = function () {
				var raw = val(el);
				state[key] = raw;
				/* keep givenByRole synced when the giver matches a known officer */
				if (key === "givenBy") {
					var role = firstOfficerRole(raw);
					if (role) { state.givenByRole = role; }
				}
				liveUpdate();
			};
			on(el, "input", handler);
			on(el, "change", handler);
		});

		/* ── family chooser: .sc2-fam__swatch[data-family] radiogroup ─────── */
		$all(".sc2-fam__swatch[data-family]").forEach(function (swatch) {
			on(swatch, "click", function (e) {
				if (e && e.preventDefault) { e.preventDefault(); }
				applyFamily(swatch.getAttribute("data-family"), { keepOrientation: false });
			});
		});

		/* ── orientation segmented radios ─────────────────────────────────── */
		$all('[data-sc2-seg="orientation"] input[type="radio"]').forEach(function (radio) {
			on(radio, "change", function () {
				if (!radio.checked) { return; }
				state.orientation = (radio.value === "landscape") ? "landscape" : "portrait";
				attr(SCROLL, "data-orientation", state.orientation);
				scheduleFit();
			});
		});

		/* ── intensity segmented radios (plain | balanced | ornate) ───────── */
		$all('[data-sc2-seg="intensity"] input[type="radio"]').forEach(function (radio) {
			on(radio, "change", function () {
				if (!radio.checked) { return; }
				var lvl = radio.value;
				/* markup + CSS key off plain/balanced/ornate verbatim */
				state.intensity = (["plain", "balanced", "ornate"].indexOf(lvl) !== -1) ? lvl : "balanced";
				attr(SCROLL, "data-intensity", state.intensity);
				scheduleFit();
			});
		});

		/* ── seal wax segmented radios ────────────────────────────────────── */
		$all('[data-sc2-seg="seal"] input[type="radio"]').forEach(function (radio) {
			on(radio, "change", function () {
				if (!radio.checked) { return; }
				applySealWax(radio.value);
			});
		});

		/* ── heraldry toggle ──────────────────────────────────────────────── */
		var heraldryToggle = $('[data-sc2-toggle="heraldry"]');
		if (heraldryToggle) {
			on(heraldryToggle, "change", function () {
				var on_ = !!heraldryToggle.checked;
				attr(SCROLL, "data-heraldry", on_ ? "on" : "off");
				var crown = $(".sc2-crown", SCROLL);
				if (crown) {
					if (on_) { crown.removeAttribute("hidden"); }
					else { crown.setAttribute("hidden", "hidden"); }
				}
			});
		}

		/* ── rolled-curl toggle ───────────────────────────────────────────── */
		var curlToggle = $('[data-sc2-toggle="curl"]');
		if (curlToggle) {
			on(curlToggle, "change", function () {
				attr(SCROLL, "data-curl", curlToggle.checked ? "on" : "off");
			});
		}

		/* ── wording reset: restore SgConfig-derived defaults ─────────────── */
		var wordingReset = $("#sc2WordingReset");
		if (wordingReset) {
			on(wordingReset, "click", function (e) {
				if (e && e.preventDefault) { e.preventDefault(); }
				resetWording();
			});
		}

		/* ── panel collapse / reopen ──────────────────────────────────────── */
		bindPanelCollapse();
	}

	/* Restore the auto-written copy from SgConfig (mirrors the boot() seeds),
	   re-populate the input fields, then re-render. Null-safe throughout.     */
	function resetWording() {
		state.persona     = pick(SG.persona, "the Bearer of this Scroll");
		state.awardName   = pick(SG.awardName, "a Token of Esteem");
		state.kingdomName = pick(SG.kingdomName, "the Kingdom");
		state.parkName    = pick(SG.parkName, "Our realm");
		state.date        = pick(SG.date, "");
		state.note        = pick(SG.note, "service to Our realm");
		state.givenBy     = pick(SG.givenBy, firstOfficerName("Monarch"), firstOfficerName(), "");
		state.givenByRole = pick(firstOfficerRole(SG.givenBy), "Crown");

		$all("[data-sc2-field]").forEach(function (el) {
			var key = el.getAttribute("data-sc2-field");
			if (key && typeof el.value === "string" && state[key] != null) {
				el.value = String(state[key]);
			}
		});
		renderCopy();
	}

	/* Reflect the initial state (from SgConfig/markup attrs) onto the option
	   controls so the panel matches the scroll on first paint. Only checks a
	   radio if one with the matching value exists; otherwise leaves the markup
	   default. Null-safe. */
	function syncOptionControls() {
		function checkSeg(name, value) {
			if (!value) { return; }
			var radio = $('[data-sc2-seg="' + name + '"] input[type="radio"][value="' + value + '"]');
			if (radio && !radio.checked) { radio.checked = true; }
		}
		checkSeg("orientation", state.orientation);
		checkSeg("intensity", state.intensity);

		/* heraldry/curl toggles drive the scroll attrs from their initial state */
		var heraldryToggle = $('[data-sc2-toggle="heraldry"]');
		if (heraldryToggle) {
			attr(SCROLL, "data-heraldry", heraldryToggle.checked ? "on" : "off");
			var crown = $(".sc2-crown", SCROLL);
			if (crown && !heraldryToggle.checked) { crown.setAttribute("hidden", "hidden"); }
		}
		var curlToggle = $('[data-sc2-toggle="curl"]');
		if (curlToggle) { attr(SCROLL, "data-curl", curlToggle.checked ? "on" : "off"); }

		/* seal wax starts at whatever radio is checked (markup default = family) */
		var seal = checkedSegValue("seal");
		if (seal) { applySealWax(seal); }
	}

	function bindPanelCollapse() {
		var panel = $("#sc2Panel");
		var forge = $("#sc2Forge");
		var collapseBtn = $("#sc2PanelCollapse");
		var reopenBtn = $("#sc2PanelReopen");
		/* The grid wrapper carries .is-panel-collapsed (drops to a single column +
		   hides the toolbox); the panel keeps .is-collapsed for any panel-local
		   styling. Toggling BOTH is what actually minimises the toolbox — without
		   the grid class the empty 360px track survives and the sheet can't grow. */
		if (collapseBtn) {
			on(collapseBtn, "click", function (e) {
				if (e && e.preventDefault) { e.preventDefault(); }
				if (panel) { addClass(panel, "is-collapsed"); }
				if (forge) { addClass(forge, "is-panel-collapsed"); }
				collapseBtn.setAttribute("aria-expanded", "false");
				if (reopenBtn) { reopenBtn.removeAttribute("hidden"); }
				scheduleFit();
			});
		}
		if (reopenBtn) {
			on(reopenBtn, "click", function (e) {
				if (e && e.preventDefault) { e.preventDefault(); }
				if (panel) { rmClass(panel, "is-collapsed"); }
				if (forge) { rmClass(forge, "is-panel-collapsed"); }
				if (collapseBtn) { collapseBtn.setAttribute("aria-expanded", "true"); }
				reopenBtn.setAttribute("hidden", "hidden");
				scheduleFit();
			});
		}
	}

	/* ── 12. EXPORT ──────────────────────────────────────────────────────── */
	function enterExportMode() {
		addClass(SCROLL, "sf-export-mode");
		/* legacy spec also reads .sc2-export for token flattening */
		addClass(SCROLL, "sc2-export");
		addClass(document.body, "sf-exporting");
		/* clear the SHEET auto-fit transform so the page captures at its true
		   Letter size (the @page / print CSS sizes the sheet to 8.5×11in). */
		SCROLL.style.removeProperty("transform");
		SCROLL.style.removeProperty("transform-origin");
		/* Re-fit the CONTENT (.sc2-page) against the export/print sheet box so a
		   long proclamation still fits the physical page — the scale is measured
		   fresh now that the sheet is at print dimensions, not screen px. */
		fitPage();
	}
	function exitExportMode() {
		rmClass(SCROLL, "sf-export-mode");
		rmClass(SCROLL, "sc2-export");
		rmClass(document.body, "sf-exporting");
		scheduleFit();
	}

	/* PDF: rely on @media print CSS (panel hidden, sheet at Letter size). */
	function exportPDF() {
		if (SG.canGenerate === false) { dbg("export gated server-side (canGenerate=false) — client print still allowed"); }
		if (!SCROLL) { return; }
		enterExportMode();
		var cleaned = false;
		var cleanup = function () {
			if (cleaned) { return; }
			cleaned = true;
			window.removeEventListener("afterprint", cleanup);
			exitExportMode();
		};
		window.addEventListener("afterprint", cleanup);
		/* give layout one tick to settle before invoking the print dialog */
		setTimeout(function () {
			try { window.print(); }
			catch (e) { dbg("print failed", e); cleanup(); return; }
			/* Safari/Firefox may not fire afterprint reliably — safety timer. */
			setTimeout(cleanup, 2000);
		}, 60);
	}

	var H2C_SRC = "https://cdnjs.cloudflare.com/ajax/libs/html2canvas/1.4.1/html2canvas.min.js";
	function ensureHtml2Canvas(cb) {
		if (window.html2canvas) { cb(window.html2canvas); return; }
		/* avoid double-injecting */
		if (window.__SF_H2C_LOADING__) {
			var tries = 0;
			var poll = setInterval(function () {
				tries++;
				if (window.html2canvas) { clearInterval(poll); cb(window.html2canvas); }
				else if (tries > 120) { clearInterval(poll); cb(null); }
			}, 50);
			return;
		}
		window.__SF_H2C_LOADING__ = true;
		var s = document.createElement("script");
		s.src = H2C_SRC;
		s.async = true;
		s.onload = function () { window.__SF_H2C_LOADING__ = false; cb(window.html2canvas || null); };
		s.onerror = function () { window.__SF_H2C_LOADING__ = false; cb(null); };
		(document.head || document.documentElement).appendChild(s);
	}

	function exportPNG(btn) {
		if (!SCROLL) { return; }
		if (btn) { btn.setAttribute("aria-busy", "true"); btn.disabled = true; }
		var restoreBtn = function () { if (btn) { btn.removeAttribute("aria-busy"); btn.disabled = false; } };

		ensureHtml2Canvas(function (h2c) {
			if (!h2c) {
				dbg("html2canvas unavailable — falling back to print");
				restoreBtn();
				exportPDF();
				return;
			}
			enterExportMode();
			/* allow webfonts + export-mode CSS to settle */
			var go = function () {
				var scale = Math.min(3, (window.devicePixelRatio || 1) * 2); /* crisp ~print */
				h2c(SCROLL, {
					backgroundColor: null,
					scale: scale,
					useCORS: true,
					allowTaint: false,
					logging: false,
					/* capture at the element's full natural box */
					width: SCROLL.offsetWidth,
					height: SCROLL.offsetHeight,
					windowWidth: document.documentElement.scrollWidth,
					windowHeight: document.documentElement.scrollHeight
				}).then(function (canvas) {
					exitExportMode();
					restoreBtn();
					triggerDownload(canvas);
				}).catch(function (err) {
					dbg("html2canvas error", err);
					exitExportMode();
					restoreBtn();
				});
			};
			if (document.fonts && document.fonts.ready && document.fonts.ready.then) {
				document.fonts.ready.then(function () { setTimeout(go, 80); });
			} else {
				setTimeout(go, 180);
			}
		});
	}

	function safeSlug(s, max) {
		return pick(s, "").replace(/[^\w\- ]+/g, "").replace(/\s+/g, "_").slice(0, max || 48);
	}
	function exportFileName(ext) {
		var who = safeSlug(state.persona, 48) || "scroll";
		var what = safeSlug(state.awardName, 48) || "award";
		return ("scroll_" + who + "_" + what + "." + ext).replace(/_+/g, "_").replace(/^_+/, "");
	}
	function triggerDownload(canvas) {
		var name = exportFileName("png");
		try {
			if (canvas.toBlob) {
				canvas.toBlob(function (blob) {
					if (!blob) { dataURLDownload(canvas, name); return; }
					var url = URL.createObjectURL(blob);
					clickLink(url, name);
					setTimeout(function () { URL.revokeObjectURL(url); }, 4000);
				}, "image/png");
			} else {
				dataURLDownload(canvas, name);
			}
		} catch (e) {
			dbg("download failed", e);
			dataURLDownload(canvas, name);
		}
	}
	function dataURLDownload(canvas, name) {
		try { clickLink(canvas.toDataURL("image/png"), name); }
		catch (e) { dbg("dataURL download failed", e); }
	}
	function clickLink(href, name) {
		var a = document.createElement("a");
		a.href = href;
		a.download = name;
		a.rel = "noopener";
		(document.body || document.documentElement).appendChild(a);
		a.click();
		setTimeout(function () { if (a.parentNode) { a.parentNode.removeChild(a); } }, 0);
	}

	/* ── 12b. IN-BUILDER ARTWORK: overlay renderer + modal shell ──────────────
	   The overlay layer lives inside .sc2-scroll so html2canvas / print capture
	   it automatically. Browse-library + upload/share handlers are added by
	   loadArtLibrary()/bindArtUpload() (Tasks 4 + 5).                          */
	var ART_LAYER = $('#sc2ArtLayer');
	var ART_MODAL = $('#sc2ArtModal');
	var artActiveZone = '';

	function artImgSrc(entry) { return entry ? (entry.raw || entry.url || '') : ''; }

	function renderArtwork() {
		if (!ART_LAYER) return;
		ART_LAYER.innerHTML = '';
		Object.keys(ART_ZONES).forEach(function (zone) {
			var entry = state.artwork[zone];
			var src = artImgSrc(entry);
			if (!src) return;
			var g = ART_ZONES[zone];
			var img = document.createElement('img');
			img.className = 'sc2-art-img';
			img.alt = '';
			img.src = src;
			img.style.left = g.l + '%';
			img.style.top = g.t + '%';
			img.style.width = g.w + '%';
			img.style.height = g.h + '%';
			img.style.zIndex = String(g.z);
			img.style.opacity = String(g.op);
			ART_LAYER.appendChild(img);
		});
		refreshArtZoneButtons();
	}

	function refreshArtZoneButtons() {
		var btns = document.querySelectorAll('.sc2-art-zonebtn');
		for (var i = 0; i < btns.length; i++) {
			var z = btns[i].getAttribute('data-zone');
			btns[i].classList.toggle('has-img', !!artImgSrc(state.artwork[z]));
		}
	}

	function openArtModal(zone) {
		artActiveZone = zone;
		var g = ART_ZONES[zone];
		var lbl = $('#sc2ArtZoneLabel'); if (lbl) lbl.textContent = g ? g.label : zone;
		artSwitchPane('browse');
		artResetUploadForm();
		loadArtLibrary(zone);          // defined in Task 4
		if (ART_MODAL) ART_MODAL.classList.add('is-open');
	}
	function closeArtModal() { if (ART_MODAL) ART_MODAL.classList.remove('is-open'); }

	function artSwitchPane(name) {
		var tabs = document.querySelectorAll('.sc2-art-tab');
		var panes = document.querySelectorAll('.sc2-art-pane');
		for (var i = 0; i < tabs.length; i++) tabs[i].classList.toggle('is-active', tabs[i].getAttribute('data-pane') === name);
		for (var j = 0; j < panes.length; j++) panes[j].classList.toggle('is-active', panes[j].getAttribute('data-pane') === name);
	}

	var ART_AJAX = SG.uir + 'ScrollArtworkAjax/';

	function loadArtLibrary(zone) {
		var grid = $('#sc2ArtGrid');
		var status = $('#sc2ArtBrowseStatus');
		if (!grid) return;
		grid.innerHTML = '';
		if (status) { status.textContent = 'Loading\u2026'; status.className = 'sc2-art-status'; }
		var url = ART_AJAX + 'browse&layout_location=' + encodeURIComponent(zone) + '&tier=&category_id=&page=1';
		fetch(url, { credentials: 'same-origin' })
			.then(function (r) { return r.json(); })
			.then(function (data) {
				var rows = (data && data.Artwork) || [];
				if (!rows.length) { if (status) { status.textContent = 'No shared graphics for this zone yet. Try \u201cUpload Your Own.\u201d'; status.className = 'sc2-art-status'; } return; }
				if (status) status.textContent = '';
				rows.forEach(function (row) {
					var card = document.createElement('div');
					card.className = 'sc2-art-card';
					var img = document.createElement('img');
					img.src = row.Url; img.alt = row.Name || '';
					var span = document.createElement('span');
					span.textContent = row.Name || '';
					card.appendChild(img); card.appendChild(span);
					on(card, 'click', function () { selectLibraryArt(zone, row); });
					grid.appendChild(card);
				});
			})
			.catch(function () { if (status) { status.textContent = 'Could not load the library.'; status.className = 'sc2-art-status err'; } });
	}

	function selectLibraryArt(zone, row) {
		state.artwork[zone] = { url: row.Url };
		renderArtwork();
		closeArtModal();
	}

	/* ── Task 5: Upload Your Own + opt-in Share ───────────────────────────── */
	var artUpload = { dataUrl: '', mime: '', name: '' };

	function artResetUploadForm() {
		artUpload = { dataUrl: '', mime: '', name: '' };
		var ids = ['sc2ArtFile', 'sc2ArtName', 'sc2ArtTags', 'sc2ArtSigner'];
		ids.forEach(function (id) { var el = $('#' + id); if (el) el.value = ''; });
		var prev = $('#sc2ArtPreview'); if (prev) { prev.style.display = 'none'; prev.src = ''; }
		var chk = $('#sc2ArtShareChk'); if (chk) chk.checked = false;
		var agree = $('#sc2ArtAgree'); if (agree) agree.checked = false;
		var reveal = $('#sc2ArtShareReveal'); if (reveal) reveal.classList.remove('is-open');
		var cat = $('#sc2ArtCategory'); if (cat) cat.value = '';
		artSetTier('global');
		var lic = $('#sc2ArtLicense'); if (lic) lic.textContent = ART_LICENSE;
		artSyncUseButton();
	}

	var artTier = 'global';
	var artHasKingdom = !!(SG.kingdomId && parseInt(SG.kingdomId, 10) !== 0);
	function artInitTier() {
		// Mirror Submit page: no kingdom -> disable Kingdom option; else label it with the kingdom name.
		var kBtn = document.querySelector('#sc2ArtTier button[data-tier="kingdom"]');
		if (kBtn) {
			if (!artHasKingdom) { kBtn.disabled = true; kBtn.style.opacity = '.5'; kBtn.style.cursor = 'not-allowed'; }
			else if (SG.kingdomName) { kBtn.textContent = SG.kingdomName; }
		}
	}
	function artSetTier(t) {
		var want = (t === 'kingdom' && artHasKingdom) ? 'kingdom' : 'global';
		artTier = want;
		var btns = document.querySelectorAll('#sc2ArtTier button');
		for (var i = 0; i < btns.length; i++) btns[i].classList.toggle('is-active', btns[i].getAttribute('data-tier') === artTier);
		var note = $('#sc2ArtTierNote');
		if (note) note.textContent = artTier === 'kingdom'
			? 'Kingdom-specific submissions are reviewed by your kingdom’s officers.'
			: 'Amtgard-wide submissions are reviewed by ORK admins.';
	}

	function artIsSharing() { var c = $('#sc2ArtShareChk'); return !!(c && c.checked); }

	function artSyncUseButton() {
		var btn = $('#sc2ArtUseBtn');
		if (!btn) return;
		var sharing = artIsSharing();
		btn.textContent = sharing ? 'Use & Submit to Library' : 'Use on My Scroll';
		var ok = !!artUpload.dataUrl;
		if (sharing) {
			var agree = $('#sc2ArtAgree'); var signer = $('#sc2ArtSigner');
			ok = ok && !!(agree && agree.checked) && !!(signer && signer.value.trim());
		}
		btn.disabled = !ok;
	}

	function bindArtUpload() {
		artInitTier();
		var file = $('#sc2ArtFile');
		if (file) on(file, 'change', function () {
			var f = file.files && file.files[0];
			if (!f) { artUpload = { dataUrl: '', mime: '', name: '' }; artSyncUseButton(); return; }
			if (f.size > 2097152) { artFoot('That image is larger than 2 MB.', 'err'); file.value = ''; return; }
			var fr = new FileReader();
			fr.onload = function () {
				artUpload.dataUrl = fr.result; artUpload.mime = f.type; artUpload.name = f.name;
				var prev = $('#sc2ArtPreview'); if (prev) { prev.src = fr.result; prev.style.display = 'block'; }
				artFoot('', '');
				artSyncUseButton();
			};
			fr.readAsDataURL(f);
		});

		var chk = $('#sc2ArtShareChk');
		if (chk) on(chk, 'change', function () {
			var reveal = $('#sc2ArtShareReveal'); if (reveal) reveal.classList.toggle('is-open', chk.checked);
			if (chk.checked) loadArtCategories();
			artSyncUseButton();
		});
		var tier = $('#sc2ArtTier');
		if (tier) on(tier, 'click', function (e) { var b = e.target.closest('button'); if (b) artSetTier(b.getAttribute('data-tier')); });
		var agree = $('#sc2ArtAgree'); if (agree) on(agree, 'change', artSyncUseButton);
		var signer = $('#sc2ArtSigner'); if (signer) on(signer, 'input', artSyncUseButton);

		var useBtn = $('#sc2ArtUseBtn'); if (useBtn) on(useBtn, 'click', artUseClicked);
	}

	function artFoot(msg, cls) {
		var el = $('#sc2ArtFootStatus'); if (!el) return;
		el.textContent = msg || ''; el.className = 'sc2-art-status' + (cls ? ' ' + cls : '');
	}

	var artCategoriesLoaded = false;
	function loadArtCategories() {
		if (artCategoriesLoaded) return;
		var sel = $('#sc2ArtCategory'); if (!sel) return;
		fetch(ART_AJAX + 'categories', { credentials: 'same-origin' })
			.then(function (r) { return r.json(); })
			.then(function (data) {
				var cats = (data && data.Categories) || [];   // verified key: data.Categories, items {CategoryId, Label}
				cats.forEach(function (c) {
					var opt = document.createElement('option');
					opt.value = c.CategoryId; opt.textContent = c.Label;
					sel.appendChild(opt);
				});
				artCategoriesLoaded = true;
			}).catch(function () {});
	}

	function artUseClicked() {
		if (!artUpload.dataUrl || !artActiveZone) return;
		var zone = artActiveZone;
		// Always place on the current scroll (ephemeral raw).
		state.artwork[zone] = { raw: artUpload.dataUrl };
		renderArtwork();

		if (!artIsSharing()) { closeArtModal(); return; }

		// Shared: also create a pending library row.
		var signer = ($('#sc2ArtSigner') || {}).value || '';
		var nm = ($('#sc2ArtName') || {}).value || artUpload.name || 'Untitled';
		var tags = ($('#sc2ArtTags') || {}).value || '';
		var cat = ($('#sc2ArtCategory') || {}).value || '';
		var b64 = String(artUpload.dataUrl).split(',')[1] || '';

		var fd = new FormData();
		fd.append('image', b64);
		fd.append('image_mime', artUpload.mime || 'image/png');
		fd.append('name', nm);
		fd.append('description', '');
		fd.append('tags', tags);
		fd.append('layout_location', zone);
		fd.append('license_signer_name', signer.trim());
		fd.append('visibility', artTier);
		fd.append('owner_kingdom_id', artTier === 'kingdom' ? String(parseInt(SG.kingdomId, 10) || 0) : '0');
		fd.append('category_id', cat);

		var btn = $('#sc2ArtUseBtn'); if (btn) btn.disabled = true;
		artFoot('Submitting to the library…', '');
		fetch(ART_AJAX + 'upload', { method: 'POST', body: fd, credentials: 'same-origin' })
			.then(function (r) { return r.json(); })
			.then(function (data) {
				if (data && data.Status === 0) {
					artFoot('Submitted! It will appear in the library after review.', 'ok');
					setTimeout(closeArtModal, 900);
				} else {
					artFoot((data && data.Message) ? data.Message : 'Submission failed, but the image is on your scroll.', 'err');
					if (btn) btn.disabled = false;
				}
			})
			.catch(function () { artFoot('Submission failed, but the image is on your scroll.', 'err'); if (btn) btn.disabled = false; });
	}

	function bindArtwork() {
		if (!ART_MODAL) return;
		var grid = $('#sc2ArtZoneGrid');
		if (grid) on(grid, 'click', function (e) {
			var b = e.target.closest ? e.target.closest('.sc2-art-zonebtn') : null;
			if (b && b.getAttribute('data-zone')) openArtModal(b.getAttribute('data-zone'));
		});
		var cx = $('#sc2ArtCloseX'); if (cx) on(cx, 'click', closeArtModal);
		on(ART_MODAL, 'click', function (e) { if (e.target === ART_MODAL) closeArtModal(); });
		var tabs = document.querySelectorAll('.sc2-art-tab');
		for (var i = 0; i < tabs.length; i++) on(tabs[i], 'click', function (e) { artSwitchPane(e.currentTarget.getAttribute('data-pane')); });
		var clr = $('#sc2ArtClearBtn'); if (clr) on(clr, 'click', function () {
			if (artActiveZone) { delete state.artwork[artActiveZone]; renderArtwork(); }
			closeArtModal();
		});
		bindArtUpload();   // defined in Task 5
		renderArtwork();
	}

	function bindExport() {
		/* Export rail buttons live in the panel footer (sf-ui.html.part):
		   #sc2ExportPrint -> Print/PDF, #sc2ExportPng -> Save PNG. They only
		   exist when the server gate ($sfCanGenerate) is true, so guard each.  */
		var printBtn = $("#sc2ExportPrint");
		if (printBtn) {
			on(printBtn, "click", function (e) { if (e && e.preventDefault) { e.preventDefault(); } exportPDF(); });
		}
		var pngBtn = $("#sc2ExportPng");
		if (pngBtn) {
			on(pngBtn, "click", function (e) { if (e && e.preventDefault) { e.preventDefault(); } exportPNG(pngBtn); });
		}
	}

	/* ── 13. BOOT ────────────────────────────────────────────────────────── */
	function boot() {
		if (!resolveRoots()) {
			dbg("no .sc2-scroll in DOM yet — scroll-forge inactive");
			return;
		}

		/* seed orientation/intensity from config before first paint */
		attr(SCROLL, "data-orientation", state.orientation);
		attr(SCROLL, "data-intensity", state.intensity);

		state.family = initialFamily();
		applyFamily(state.family, { keepOrientation: true });

		bindControls();
		bindExport();
		bindArtwork();
		syncOptionControls();

		/* responsive auto-fit */
		on(window, "resize", debounce(scheduleFit, 80));
		if (window.ResizeObserver && STAGE) {
			try {
				var ro = new ResizeObserver(debounce(scheduleFit, 60));
				ro.observe(STAGE);
			} catch (e) {}
		}
		/* re-fit once fonts load (metrics change -> height changes) */
		if (document.fonts && document.fonts.ready && document.fonts.ready.then) {
			document.fonts.ready.then(function () { scheduleFit(); });
		}

		renderCopy();
		wireHeraldry();
		/* belt-and-braces: re-classify once images have had a tick to decode, so a
		   white-bg shield never lingers unclipped (showing its white box) while its
		   neighbour is already clean. */
		setTimeout(reclassifyArms, 300);
		recolorFamilySwatches();
		scheduleFit();

		/* tiny public surface for debugging / external nudges (single
		   namespaced object — no other globals leaked).                       */
		window.ScrollForge = {
			setFamily: function (k) { applyFamily(k, { keepOrientation: false }); },
			refresh: function () { renderCopy(); scheduleFit(); },
			fit: scheduleFit,
			exportPDF: exportPDF,
			exportPNG: function () { exportPNG(null); },
			state: function () { var c = {}; for (var k in state) { if (state.hasOwnProperty(k)) { c[k] = state[k]; } } return c; }
		};

		dbg("booted", { family: state.family, orientation: state.orientation, intensity: state.intensity });
	}

	if (document.readyState === "loading") {
		document.addEventListener("DOMContentLoaded", boot);
	} else {
		/* DOM already parsed (script inlined late) — boot on next tick so any
		   sibling partials inlined after us have a chance to define markup.   */
		setTimeout(boot, 0);
	}
})();

</script>
