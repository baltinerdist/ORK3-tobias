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
<div class="sc-workspace">

  <!-- ============ Controls (left panel) ============ -->
  <div class="sc-controls">

    <!-- SECTION: Template (hidden for now — may return later) -->
    <div class="sc-section" id="sc-sec-template" style="display:none">
      <div class="sc-section-title" onclick="sgToggleSection('sc-sec-template')">
        <h3><i class="fas fa-layer-group" style="margin-right:6px;opacity:0.5"></i>Template</h3>
        <i class="fas fa-chevron-down sc-chevron"></i>
      </div>
      <div class="sc-section-body">
        <div class="sc-template-grid">
          <div class="sc-template-card" data-template="A" id="sc-tpl-a">
            <span class="sc-tpl-icon"><i class="fas fa-shield-alt"></i></span>
            <div>
              <span class="sc-tpl-name">Knight / Peerage</span>
              <span class="sc-tpl-desc">Knighthood and peerage orders</span>
            </div>
          </div>
          <div class="sc-template-card" data-template="B" id="sc-tpl-b">
            <span class="sc-tpl-icon"><i class="fas fa-medal"></i></span>
            <div>
              <span class="sc-tpl-name">Order / Award</span>
              <span class="sc-tpl-desc">Ladder awards and grants</span>
            </div>
          </div>
          <div class="sc-template-card" data-template="C" id="sc-tpl-c">
            <span class="sc-tpl-icon"><i class="fas fa-crown"></i></span>
            <div>
              <span class="sc-tpl-name">Title / Office</span>
              <span class="sc-tpl-desc">Titles and office appointments</span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- SECTION: Award Details -->
    <div class="sc-section" id="sc-sec-details">
      <div class="sc-section-title" onclick="sgToggleSection('sc-sec-details')">
        <h3><i class="fas fa-file-alt" style="margin-right:6px;opacity:0.5"></i>Award Details</h3>
        <i class="fas fa-chevron-down sc-chevron"></i>
      </div>
      <div class="sc-section-body">
        <div class="sc-field-group">
          <label class="sc-field-label" for="sc-award-name"><i class="fas fa-heading sc-tc-title"></i>Award Name</label>
          <input type="text" class="sc-input" id="sc-award-name" value="<?= htmlspecialchars($sgAwardName) ?>" placeholder="Enter award name">
          <div class="sc-field-error" id="sc-err-award">Award name is required</div>
        </div>

        <div class="sc-display-row">
          <div class="sc-field-group sc-ac-wrap">
            <label class="sc-field-label" for="sc-recipient"><i class="fas fa-user sc-tc-recipient"></i>Recipient Persona</label>
            <input type="text" class="sc-input" id="sc-recipient" value="<?= htmlspecialchars($sgPlayer['Persona'] ?? '') ?>" placeholder="Search or enter persona…" autocomplete="off">
            <input type="hidden" id="sc-recipient-id" value="<?= (int)($sgPlayer['MundaneId'] ?? 0) ?>">
            <div class="sc-field-error" id="sc-err-recipient">Recipient is required</div>
            <div class="sc-ac-results" id="sc-recipient-results"></div>
          </div>
          <div class="sc-field-group">
            <label class="sc-field-label" for="sc-recipient-display">Display As</label>
            <input type="text" class="sc-input" id="sc-recipient-display" value="<?= htmlspecialchars($sgPlayer['Persona'] ?? '') ?>" placeholder="Name on scroll">
          </div>
        </div>

        <div class="sc-row-2">
          <div class="sc-field-group">
            <label class="sc-field-label" for="sc-rank">Rank</label>
            <input type="number" class="sc-input" id="sc-rank" value="<?= (int)($sgAward['Rank'] ?? 0) ?>" min="0" max="99" placeholder="0">
          </div>
          <div class="sc-field-group">
            <label class="sc-field-label" for="sc-date">Date</label>
            <input type="date" class="sc-input" id="sc-date" value="<?= htmlspecialchars($sgAward['Date'] ?? date('Y-m-d')) ?>">
          </div>
        </div>

        <div class="sc-field-group">
          <label class="sc-field-label" for="sc-body-text">
            <i class="fas fa-align-left sc-tc-body"></i>Body Text
            <span class="sc-badge sc-badge-auto" id="sc-body-badge"><i class="fas fa-magic" style="font-size:9px;margin-right:3px"></i>Auto</span>
          </label>
          <textarea class="sc-textarea" id="sc-body-text" rows="4" placeholder="Scroll body text will be auto-generated..."></textarea>
          <button type="button" class="sc-regen-btn" id="sc-regen-body" title="Regenerate from template">
            <i class="fas fa-sync-alt"></i> Regenerate
          </button>
        </div>
        <div class="sc-row-2">
          <div class="sc-field-group">
            <label class="sc-field-label" for="sc-park">Park</label>
            <input type="text" class="sc-input" id="sc-park" value="<?= htmlspecialchars($sgParkName) ?>" placeholder="Park name">
          </div>
          <div class="sc-field-group">
            <label class="sc-field-label" for="sc-kingdom">Kingdom</label>
            <input type="text" class="sc-input" id="sc-kingdom" value="<?= htmlspecialchars($sgKingdomName) ?>" placeholder="Kingdom name">
          </div>
        </div>

        <div class="sc-field-group">
          <label class="sc-field-label"><i class="fas fa-pen-fancy sc-tc-sig"></i>Given By</label>
          <?php if (!empty($sgPreloadOfficers)): ?>
          <div class="sc-officer-label">Quick Select</div>
          <div class="sc-officer-chips" id="sc-givenby-officer-chips">
            <?php foreach ($sgPreloadOfficers as $officer): ?>
            <button type="button" class="sc-officer-chip"
                    data-id="<?= (int)$officer['MundaneId'] ?>"
                    data-name="<?= htmlspecialchars($officer['Persona']) ?>">
              <?= htmlspecialchars($officer['Persona']) ?> <span>(<?= htmlspecialchars($officer['Role']) ?>)</span>
            </button>
            <?php endforeach; ?>
          </div>
          <?php endif; ?>
          <div class="sc-display-row">
            <div class="sc-field-group sc-ac-wrap">
              <label class="sc-field-label" for="sc-given-by" style="font-size:10px;color:#a0aec0;font-weight:400;text-transform:none;letter-spacing:0">Search or type name</label>
              <input type="text" class="sc-input" id="sc-given-by" value="<?= htmlspecialchars($sgAward['GivenBy'] ?? '') ?>" placeholder="Search or enter persona…" autocomplete="off">
              <input type="hidden" id="sc-given-by-id" value="">
              <div class="sc-ac-results" id="sc-givenby-results"></div>
            </div>
            <div class="sc-field-group">
              <label class="sc-field-label" for="sc-given-by-display">Display As</label>
              <input type="text" class="sc-input" id="sc-given-by-display" value="<?= htmlspecialchars($sgAward['GivenBy'] ?? '') ?>" placeholder="Name on scroll">
            </div>
          </div>
        </div>

      </div>
    </div>

    <!-- SECTION: Typography -->
    <div class="sc-section" id="sc-sec-typography">
      <div class="sc-section-title" onclick="sgToggleSection('sc-sec-typography')">
        <h3><i class="fas fa-font" style="margin-right:6px;opacity:0.5"></i>Typography</h3>
        <i class="fas fa-chevron-down sc-chevron"></i>
      </div>
      <div class="sc-section-body">
        <div class="sc-typo-grid">
          <div class="sc-font-picker" data-target="title">
            <label class="sc-font-picker-label"><i class="fas fa-heading sc-tc-title"></i> Award Title</label>
            <button type="button" class="sc-font-picker-btn" data-target="title">
              <div class="sc-font-picker-preview">
                <span class="sc-font-picker-fname">MedievalSharp</span>
                <span class="sc-font-picker-sample" style="font-family:'MedievalSharp',cursive">Order of the Warrior</span>
              </div>
              <i class="fas fa-chevron-down sc-font-picker-arrow"></i>
            </button>
            <div class="sc-font-picker-dropdown" data-target="title"></div>
          </div>

          <div class="sc-font-picker" data-target="recipient">
            <label class="sc-font-picker-label"><i class="fas fa-user sc-tc-recipient"></i> Recipient Name</label>
            <button type="button" class="sc-font-picker-btn" data-target="recipient">
              <div class="sc-font-picker-preview">
                <span class="sc-font-picker-fname">MedievalSharp</span>
                <span class="sc-font-picker-sample" style="font-family:'MedievalSharp',cursive">Order of the Warrior</span>
              </div>
              <i class="fas fa-chevron-down sc-font-picker-arrow"></i>
            </button>
            <div class="sc-font-picker-dropdown" data-target="recipient"></div>
          </div>

          <div class="sc-font-picker" data-target="body">
            <label class="sc-font-picker-label"><i class="fas fa-align-left sc-tc-body"></i> Body Text</label>
            <button type="button" class="sc-font-picker-btn" data-target="body">
              <div class="sc-font-picker-preview">
                <span class="sc-font-picker-fname">EB Garamond</span>
                <span class="sc-font-picker-sample" style="font-family:'EB Garamond',serif">Order of the Warrior</span>
              </div>
              <i class="fas fa-chevron-down sc-font-picker-arrow"></i>
            </button>
            <div class="sc-font-picker-dropdown" data-target="body"></div>
          </div>

          <div class="sc-font-picker" data-target="signatures">
            <label class="sc-font-picker-label"><i class="fas fa-pen-fancy sc-tc-sig"></i> Signatures</label>
            <button type="button" class="sc-font-picker-btn" data-target="signatures">
              <div class="sc-font-picker-preview">
                <span class="sc-font-picker-fname">EB Garamond</span>
                <span class="sc-font-picker-sample" style="font-family:'EB Garamond',serif">Order of the Warrior</span>
              </div>
              <i class="fas fa-chevron-down sc-font-picker-arrow"></i>
            </button>
            <div class="sc-font-picker-dropdown" data-target="signatures"></div>
          </div>

        </div>
      </div>
    </div>

    <!-- Colors & Effects + Heraldry side-by-side -->
    <div class="sc-two-col">

    <!-- SECTION: Colors & Effects -->
    <div class="sc-section" id="sc-sec-visual">
      <div class="sc-section-title" onclick="sgToggleSection('sc-sec-visual')">
        <h3><i class="fas fa-palette" style="margin-right:6px;opacity:0.5"></i>Colors &amp; Effects</h3>
        <i class="fas fa-chevron-down sc-chevron"></i>
      </div>
      <div class="sc-section-body">
        <div class="sc-field-group">
          <label class="sc-field-label">Color Palette</label>
          <div class="sc-palette-row">
            <div class="sc-palette-item">
              <div class="sc-palette-swatch sc-active" data-palette="classic">
                <span class="sc-swatch-inner" style="background:linear-gradient(135deg,#f5e6c8,#e8d5a8)"></span>
                <i class="fas fa-check sc-swatch-check"></i>
              </div>
              <span class="sc-palette-label">Classic</span>
            </div>
            <div class="sc-palette-item">
              <div class="sc-palette-swatch" data-palette="royal">
                <span class="sc-swatch-inner" style="background:linear-gradient(135deg,#eef2f9,#d4dff0)"></span>
                <i class="fas fa-check sc-swatch-check"></i>
              </div>
              <span class="sc-palette-label">Royal</span>
            </div>
            <div class="sc-palette-item">
              <div class="sc-palette-swatch" data-palette="nature">
                <span class="sc-swatch-inner" style="background:linear-gradient(135deg,#f0e6d0,#ddd4b8)"></span>
                <i class="fas fa-check sc-swatch-check"></i>
              </div>
              <span class="sc-palette-label">Nature</span>
            </div>
            <div class="sc-palette-item">
              <div class="sc-palette-swatch" data-palette="crimson">
                <span class="sc-swatch-inner" style="background:linear-gradient(135deg,#f9f0f0,#e8d0d0)"></span>
                <i class="fas fa-check sc-swatch-check"></i>
              </div>
              <span class="sc-palette-label">Crimson</span>
            </div>
            <div class="sc-palette-item">
              <div class="sc-palette-swatch" data-palette="obsidian">
                <span class="sc-swatch-inner" style="background:linear-gradient(135deg,#e8e4df,#d0ccc5)"></span>
                <i class="fas fa-check sc-swatch-check"></i>
              </div>
              <span class="sc-palette-label">Obsidian</span>
            </div>
            <div class="sc-palette-item">
              <div class="sc-palette-swatch" data-palette="white">
                <span class="sc-swatch-inner" style="background:linear-gradient(135deg,#ffffff,#f0f0f0);border:1px solid #e2e8f0"></span>
                <i class="fas fa-check sc-swatch-check" style="color:#333;text-shadow:none"></i>
              </div>
              <span class="sc-palette-label">White</span>
            </div>
          </div>
        </div>

        <div class="sc-field-group" style="margin-top:12px">
          <label class="sc-field-label">Border Style</label>
          <div class="sc-border-grid" id="sc-border-grid">
            <div class="sc-border-card sc-active" data-border="classic">
              <canvas width="170" height="120" id="sc-bp-classic"></canvas>
              <div class="sc-border-card-label">Classic</div>
            </div>
            <div class="sc-border-card" data-border="ornate">
              <canvas width="170" height="120" id="sc-bp-ornate"></canvas>
              <div class="sc-border-card-label">Ornate</div>
            </div>
            <div class="sc-border-card" data-border="celtic">
              <canvas width="170" height="120" id="sc-bp-celtic"></canvas>
              <div class="sc-border-card-label">Celtic</div>
            </div>
            <div class="sc-border-card" data-border="simple">
              <canvas width="170" height="120" id="sc-bp-simple"></canvas>
              <div class="sc-border-card-label">Simple</div>
            </div>
            <div class="sc-border-card" data-border="royal">
              <canvas width="170" height="120" id="sc-bp-royal"></canvas>
              <div class="sc-border-card-label">Royal</div>
            </div>
            <div class="sc-border-card" data-border="rustic">
              <canvas width="170" height="120" id="sc-bp-rustic"></canvas>
              <div class="sc-border-card-label">Rustic</div>
            </div>
            <div class="sc-border-card" data-border="filigree">
              <canvas width="170" height="120" id="sc-bp-filigree"></canvas>
              <div class="sc-border-card-label">Filigree</div>
            </div>
            <div class="sc-border-card" data-border="none">
              <canvas width="170" height="120" id="sc-bp-none"></canvas>
              <div class="sc-border-card-label">None</div>
            </div>
          </div>

          <!-- Celtic knot options (visible only when celtic border selected) -->
          <div class="sc-celtic-opts" id="sc-celtic-opts">
            <div class="sc-celtic-opts-title"><i class="fas fa-bezier-curve" style="margin-right:5px;opacity:0.6"></i>Celtic Knot Options</div>
            <div class="sc-celtic-row">
              <div class="sc-celtic-field">
                <label>Strand Thickness <span class="sc-celtic-val" id="sc-celtic-strand-val">4</span></label>
                <input type="range" id="sc-celtic-strand" min="2" max="8" value="4" step="1">
              </div>
              <div class="sc-celtic-field">
                <label>Outline Thickness <span class="sc-celtic-val" id="sc-celtic-outline-val">1</span></label>
                <input type="range" id="sc-celtic-outline" min="0" max="4" value="1" step="0.5">
              </div>
            </div>
            <div class="sc-celtic-row">
              <div class="sc-celtic-field">
                <label>Strand Color <input type="color" id="sc-celtic-fill" value="#8b6914"></label>
              </div>
              <div class="sc-celtic-field">
                <label>Outline Color <input type="color" id="sc-celtic-stroke" value="#6b5a32"></label>
              </div>
            </div>
          </div>
        </div>

      </div>
    </div>

    <!-- SECTION: Heraldry -->
    <div class="sc-section" id="sc-sec-heraldry">
      <div class="sc-section-title" onclick="sgToggleSection('sc-sec-heraldry')">
        <h3><i class="fas fa-shield-alt" style="margin-right:6px;opacity:0.5"></i>Heraldry</h3>
        <i class="fas fa-chevron-down sc-chevron"></i>
      </div>
      <div class="sc-section-body">
        <div class="sc-toggle-row">
          <label class="sc-toggle-switch">
            <input type="checkbox" id="sc-herald-kingdom" <?= $sgKingdomHeraldry ? 'checked' : '' ?>>
            <span class="sc-toggle-slider"></span>
          </label>
          <div class="sc-toggle-preview">
            <?php if ($sgKingdomHeraldry): ?>
            <img src="<?= htmlspecialchars($sgKingdomHeraldry) ?>" alt="Kingdom heraldry">
            <?php endif; ?>
          </div>
          <span class="sc-toggle-label">Kingdom Heraldry</span>
          <span class="sc-toggle-spinner"></span>
        </div>

        <div class="sc-toggle-row">
          <label class="sc-toggle-switch">
            <input type="checkbox" id="sc-herald-park" <?= $sgParkHeraldry ? 'checked' : '' ?>>
            <span class="sc-toggle-slider"></span>
          </label>
          <div class="sc-toggle-preview">
            <?php if ($sgParkHeraldry): ?>
            <img src="<?= htmlspecialchars($sgParkHeraldry) ?>" alt="Park heraldry">
            <?php endif; ?>
          </div>
          <span class="sc-toggle-label">Park Heraldry</span>
          <span class="sc-toggle-spinner"></span>
        </div>

        <div class="sc-toggle-row">
          <label class="sc-toggle-switch">
            <input type="checkbox" id="sc-herald-player" <?= $sgPlayerHeraldry ? 'checked' : '' ?>>
            <span class="sc-toggle-slider"></span>
          </label>
          <div class="sc-toggle-preview">
            <?php if ($sgPlayerHeraldry): ?>
            <img src="<?= htmlspecialchars($sgPlayerHeraldry) ?>" alt="Player heraldry">
            <?php endif; ?>
          </div>
          <span class="sc-toggle-label">Player Heraldry</span>
          <span class="sc-toggle-spinner"></span>
        </div>
      </div>
    </div>

    </div><!-- /sc-two-col -->

    <!-- SECTION: Artwork -->
    <div class="sc-section" id="sc-sec-artwork">
      <div class="sc-section-title" onclick="sgToggleSection('sc-sec-artwork')">
        <h3><i class="fas fa-palette" style="margin-right:6px;opacity:0.5"></i>Artwork</h3>
        <i class="fas fa-chevron-down sc-chevron"></i>
      </div>
      <div class="sc-section-body">
        <div class="sc-artwork-slots-grid" id="sc-artwork-slots">
          <!-- Slot cards rendered by JS -->
        </div>
        <div class="sc-artwork-link-row">
          <button type="button" class="sc-artwork-link-btn" onclick="sgArtworkDownloadGuide()" title="Download a template guide showing artwork slot positions and dimensions">
            <i class="fas fa-ruler-combined"></i> Template Guide
          </button>
          <?php if ($sgSessionUserId > 0): ?>
          <button type="button" class="sc-artwork-link-btn" onclick="sgArtworkOpenMyUploads()">
            <i class="fas fa-images"></i> My Uploads
          </button>
          <?php endif; ?>
          <?php if ($sgIsOrkAdmin): ?>
          <button type="button" class="sc-artwork-link-btn sc-admin-btn" onclick="sgArtworkOpenAdmin()">
            <i class="fas fa-check-circle"></i> Pending Approval
          </button>
          <?php endif; ?>
        </div>
      </div>
    </div>

    <!-- SECTION: Signatures -->
    <div class="sc-section" id="sc-sec-signatures">
      <div class="sc-section-title" onclick="sgToggleSection('sc-sec-signatures')">
        <h3><i class="fas fa-pen-fancy" style="margin-right:6px;opacity:0.5"></i>Signatures</h3>
        <i class="fas fa-chevron-down sc-chevron"></i>
      </div>
      <div class="sc-section-body" id="sc-sig-body">
        <div class="sc-sig-pair" id="sc-sig-1">
          <div class="sc-field-group">
            <label class="sc-field-label" for="sc-sig1-name">Name</label>
            <input type="text" class="sc-input sc-sig-name" id="sc-sig1-name" value="<?= htmlspecialchars($sgAward['GivenBy'] ?? '') ?>" placeholder="Signature name">
          </div>
          <div class="sc-field-group">
            <label class="sc-field-label" for="sc-sig1-role">Role</label>
            <input type="text" class="sc-input sc-sig-role" id="sc-sig1-role" value="Monarch" placeholder="Title or role">
          </div>
        </div>
        <div class="sc-sig-pair sc-sig-animated sc-sig-visible" id="sc-sig-2">
          <div class="sc-field-group">
            <label class="sc-field-label" for="sc-sig2-name">Name</label>
            <input type="text" class="sc-input sc-sig-name" id="sc-sig2-name" placeholder="Signature name">
          </div>
          <div class="sc-field-group">
            <label class="sc-field-label" for="sc-sig2-role">Role</label>
            <input type="text" class="sc-input sc-sig-role" id="sc-sig2-role" value="Regent" placeholder="Title or role">
          </div>
        </div>
        <div class="sc-sig-pair sc-sig-animated sc-sig-hidden" id="sc-sig-3">
          <div class="sc-field-group">
            <label class="sc-field-label" for="sc-sig3-name">Name</label>
            <input type="text" class="sc-input sc-sig-name" id="sc-sig3-name" placeholder="Signature name">
          </div>
          <div class="sc-field-group">
            <label class="sc-field-label" for="sc-sig3-role">Role</label>
            <input type="text" class="sc-input sc-sig-role" id="sc-sig3-role" placeholder="Title or role">
          </div>
        </div>
        <div class="sc-sig-actions">
          <button type="button" class="sc-sig-toggle-btn" id="sc-add-sig-btn" onclick="sgToggleSig2()">
            <i class="fas fa-plus" id="sc-sig-toggle-icon"></i> <span id="sc-sig-toggle-label">Add Second Signature</span>
          </button>
        </div>
      </div>
    </div>

    <!-- Generate / Download + Reset -->
    <div class="sc-btn-row">
      <button type="button" class="sc-generate-btn" id="sc-download-btn">
        <i class="fas fa-download"></i> Download Scroll as PNG
      </button>
      <button type="button" class="sc-reset-btn" id="sc-reset-btn" title="Reset all fields to defaults">
        <i class="fas fa-undo"></i> Reset
      </button>
    </div>

  </div><!-- /sc-controls -->

  <!-- ============ Preview (right panel) ============ -->
  <div class="sc-preview-wrap">
    <div class="sc-preview-panel">
      <div class="sc-preview-header">
        <h3><i class="fas fa-eye" style="margin-right:6px;opacity:0.5"></i>Preview</h3>
        <span class="sc-preview-size">8.5&Prime; &times; 11&Prime;</span>
      </div>
      <div class="sc-preview-body">
        <div class="sc-canvas-wrap">
          <canvas id="sc-canvas" width="850" height="1100"></canvas>
        </div>
      </div>
      <button type="button" class="sc-download-btn" id="sc-download-btn-2">
        <i class="fas fa-download"></i> Download PNG
      </button>
    </div>
  </div><!-- /sc-preview-wrap -->

</div><!-- /sc-workspace -->

<script src="<?= HTTP_ASSETS ?>scroll/celticknot.js?v=<?= filemtime(DIR_ASSETS . "scroll/celticknot.js") ?>"></script>

<!-- Toast notification -->
<div class="sc-toast" id="sc-toast"></div>

<!-- =============================================
     Artwork Modals
     ============================================= -->

<!-- Browse/Upload Modal -->
<div class="sc-artwork-modal" id="sc-artwork-browse-modal">
  <div class="sc-artwork-modal-content">
    <div class="sc-artwork-modal-header">
      <div>
        <h3 id="sc-artwork-browse-title">Browse Artwork</h3>
        <h4 id="sc-artwork-browse-subtitle">Select artwork for this slot</h4>
      </div>
      <button class="sc-artwork-modal-close" onclick="sgArtworkCloseBrowse()">&times;</button>
    </div>
    <div class="sc-artwork-modal-body">
      <div class="sc-artwork-tabs">
        <button class="sc-artwork-tab sc-active" data-tab="browse" onclick="sgArtworkSwitchTab(this, 'browse')">Browse</button>
        <button class="sc-artwork-tab" data-tab="upload" onclick="sgArtworkSwitchTab(this, 'upload')">Upload New</button>
      </div>

      <!-- Browse tab -->
      <div class="sc-artwork-tab-content sc-active" id="sc-artwork-tab-browse">
        <div class="sc-artwork-search-bar">
          <input type="text" id="sc-artwork-search-input" placeholder="Search by name or tags..." autocomplete="off">
          <button type="button" class="sc-artwork-search-btn" onclick="sgArtworkSearch()"><i class="fas fa-search"></i></button>
        </div>
        <div class="sc-artwork-grid" id="sc-artwork-browse-grid">
          <div class="sc-artwork-empty-state">
            <i class="fas fa-palette"></i>
            Loading artwork...
          </div>
        </div>
        <div class="sc-artwork-pagination" id="sc-artwork-browse-pagination" style="display:none">
          <button type="button" onclick="sgArtworkBrowsePrev()"><i class="fas fa-chevron-left"></i> Prev</button>
          <span id="sc-artwork-browse-page-info">Page 1</span>
          <button type="button" onclick="sgArtworkBrowseNext()">Next <i class="fas fa-chevron-right"></i></button>
        </div>
      </div>

      <!-- Upload tab -->
      <div class="sc-artwork-tab-content" id="sc-artwork-tab-upload">
        <div class="sc-artwork-upload-form">
          <div class="sc-field-group">
            <label class="sc-field-label" for="sc-artwork-file">Image File <span style="color:#e53e3e">*</span></label>
            <input type="file" class="sc-input" id="sc-artwork-file" accept="image/png,image/jpeg,image/gif">
            <div class="sc-artwork-file-info" id="sc-artwork-file-info">PNG or JPEG. See template guide for recommended dimensions.</div>
          </div>
          <div class="sc-field-group">
            <label class="sc-field-label" for="sc-artwork-upload-name">Name <span style="color:#e53e3e">*</span></label>
            <input type="text" class="sc-input" id="sc-artwork-upload-name" placeholder="A descriptive name for this artwork" maxlength="150">
          </div>
          <div class="sc-field-group">
            <label class="sc-field-label" for="sc-artwork-upload-desc">Description</label>
            <textarea class="sc-textarea" id="sc-artwork-upload-desc" rows="2" placeholder="Brief description (optional)" maxlength="500"></textarea>
          </div>
          <div class="sc-field-group">
            <label class="sc-field-label" for="sc-artwork-upload-tags">Tags <span style="color:#a0aec0;font-weight:400;text-transform:none">(comma-separated)</span></label>
            <input type="text" class="sc-input" id="sc-artwork-upload-tags" placeholder="e.g. floral, celtic, border" maxlength="500">
          </div>
          <div class="sc-field-group">
            <label class="sc-field-label">Artwork Slot</label>
            <input type="text" class="sc-input" id="sc-artwork-upload-slot" readonly style="background:#f7fafc;color:#718096">
          </div>
          <div class="sc-field-group">
            <label class="sc-field-label">License Agreement</label>
            <div class="sc-artwork-license">AMTGARD SCROLL ARTWORK LICENSE

By uploading artwork to the ORK Scroll Artwork Repository, you grant to Amtgard, Inc. and all Amtgard players a perpetual, worldwide, non-exclusive, royalty-free license to use, display, reproduce, and incorporate the uploaded artwork solely for the purpose of generating award scrolls through the ORK system.

You represent and warrant that:
1. You are the original creator of this artwork, or have obtained all necessary rights and permissions to grant this license.
2. The artwork does not infringe upon the intellectual property rights of any third party.
3. You understand this artwork will be made available to other Amtgard players for use in their scroll designs.

This license does not transfer ownership of the artwork. You retain all other rights to your work. Amtgard may remove artwork at any time at its discretion.

By typing your full legal name below, you acknowledge that this constitutes a legally binding digital signature indicating your agreement to these terms.</div>
          </div>
          <div class="sc-field-group">
            <label class="sc-field-label" for="sc-artwork-signer">Full Legal Name <span style="color:#e53e3e">*</span></label>
            <input type="text" class="sc-input" id="sc-artwork-signer" placeholder="Type your full legal name as a digital signature" maxlength="200">
          </div>
          <div class="sc-artwork-agree-row">
            <input type="checkbox" id="sc-artwork-agree">
            <label for="sc-artwork-agree">I agree to the terms above</label>
          </div>
          <div style="margin-top:12px">
            <button type="button" class="sc-artwork-upload-submit" id="sc-artwork-upload-btn" onclick="sgArtworkUpload()">
              <i class="fas fa-upload"></i> Upload Artwork
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</div>

<!-- My Uploads Modal -->
<div class="sc-artwork-modal" id="sc-artwork-myuploads-modal">
  <div class="sc-artwork-modal-content">
    <div class="sc-artwork-modal-header">
      <h3>My Uploads</h3>
      <button class="sc-artwork-modal-close" onclick="sgArtworkCloseMyUploads()">&times;</button>
    </div>
    <div class="sc-artwork-modal-body">
      <div id="sc-artwork-myuploads-list">
        <div class="sc-artwork-loading"><i class="fas fa-spinner fa-spin"></i> Loading...</div>
      </div>
      <div class="sc-artwork-pagination" id="sc-artwork-myuploads-pagination" style="display:none">
        <button type="button" onclick="sgArtworkMyUploadsPrev()"><i class="fas fa-chevron-left"></i> Prev</button>
        <span id="sc-artwork-myuploads-page-info">Page 1</span>
        <button type="button" onclick="sgArtworkMyUploadsNext()">Next <i class="fas fa-chevron-right"></i></button>
      </div>
    </div>
  </div>
</div>

<!-- Admin Approval Modal -->
<div class="sc-artwork-modal" id="sc-artwork-admin-modal">
  <div class="sc-artwork-modal-content">
    <div class="sc-artwork-modal-header">
      <h3>Pending Artwork Approval</h3>
      <button class="sc-artwork-modal-close" onclick="sgArtworkCloseAdmin()">&times;</button>
    </div>
    <div class="sc-artwork-modal-body">
      <div id="sc-artwork-admin-list">
        <div class="sc-artwork-loading"><i class="fas fa-spinner fa-spin"></i> Loading...</div>
      </div>
      <div class="sc-artwork-pagination" id="sc-artwork-admin-pagination" style="display:none">
        <button type="button" onclick="sgArtworkAdminPrev()"><i class="fas fa-chevron-left"></i> Prev</button>
        <span id="sc-artwork-admin-page-info">Page 1</span>
        <button type="button" onclick="sgArtworkAdminNext()">Next <i class="fas fa-chevron-right"></i></button>
      </div>
    </div>
  </div>
</div>

<!-- =============================================
     JavaScript
     ============================================= -->
<script>
var SgConfig = <?= json_encode($sgConfig, JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS) ?>;
</script>
<script>
(function() {
  if (typeof SgConfig === 'undefined') return;

  // ============================================================
  //  Toast notification helper
  // ============================================================
  function sgToast(msg, type) {
    var el = document.getElementById('sc-toast');
    if (!el) return;
    el.className = 'sc-toast' + (type === 'warn' ? ' sc-toast-warn' : '');
    el.textContent = msg;
    el.classList.add('sc-toast-visible');
    clearTimeout(sgToast._timer);
    sgToast._timer = setTimeout(function() {
      el.classList.remove('sc-toast-visible');
    }, 4000);
  }

  // ============================================================
  //  Section collapse localStorage persistence
  // ============================================================
  var SC_COLLAPSE_KEY = 'sg_collapsed_sections';
  function sgSaveCollapseState() {
    var sections = document.querySelectorAll('.sc-section');
    var collapsed = [];
    for (var i = 0; i < sections.length; i++) {
      if (sections[i].classList.contains('sc-collapsed')) {
        collapsed.push(sections[i].id);
      }
    }
    try { localStorage.setItem(SC_COLLAPSE_KEY, JSON.stringify(collapsed)); } catch(e) {}
  }
  function sgRestoreCollapseState() {
    try {
      var raw = localStorage.getItem(SC_COLLAPSE_KEY);
      if (!raw) return;
      var collapsed = JSON.parse(raw);
      for (var i = 0; i < collapsed.length; i++) {
        var sec = document.getElementById(collapsed[i]);
        if (sec) sec.classList.add('sc-collapsed');
      }
    } catch(e) {}
  }

  // ============================================================
  //  Template Definitions
  // ============================================================
  var TEMPLATES = {
    A: {
      name: 'Knight / Peerage',
      sigCount: 3,
      title:     { x: 425, y: 170, size: 51, maxWidth: 661 },
      recipient: { x: 425, y: 279, size: 36, maxWidth: 661 },
      body:      { x: 425, y: 359, size: 21, maxWidth: 642, lineHeight: 30 },
      sigY: 972,
      heraldry: {
        kingdom: { x: 76, y: 76, w: 113, h: 113 },
        park:    { x: 661, y: 76, w: 113, h: 113 },
        player:  { x: 354, y: 661, w: 142, h: 142 }
      }
    },
    B: {
      name: 'Order / Award',
      sigCount: 2,
      title:     { x: 425, y: 151, size: 45, maxWidth: 661 },
      recipient: { x: 425, y: 251, size: 32, maxWidth: 661 },
      body:      { x: 425, y: 321, size: 19, maxWidth: 642, lineHeight: 28 },
      sigY: 972,
      heraldry: {
        kingdom: { x: 76, y: 76, w: 104, h: 104 },
        park:    { x: 671, y: 76, w: 104, h: 104 },
        player:  { x: 354, y: 642, w: 142, h: 142 }
      }
    },
    C: {
      name: 'Title / Office',
      sigCount: 2,
      title:     { x: 425, y: 132, size: 42, maxWidth: 661 },
      recipient: { x: 425, y: 223, size: 30, maxWidth: 661 },
      body:      { x: 425, y: 283, size: 19, maxWidth: 642, lineHeight: 28 },
      sigY: 972,
      heraldry: {
        kingdom: { x: 76, y: 57, w: 94, h: 94 },
        park:    { x: 680, y: 57, w: 94, h: 94 },
        player:  { x: 354, y: 623, w: 142, h: 142 }
      }
    }
  };

  // ============================================================
  //  Color Palettes
  // ============================================================
  var PALETTES = {
    classic:  { bg: '#f5e6c8', text: '#2d1b00', accent: '#8b6914', border: '#6b5a32' },
    royal:    { bg: '#eef2f9', text: '#1a3a6b', accent: '#c4972a', border: '#1a3a6b' },
    nature:   { bg: '#f0e6d0', text: '#2d5016', accent: '#b8942a', border: '#2d5016' },
    crimson:  { bg: '#f9f0f0', text: '#4a1010', accent: '#8b1a1a', border: '#6b2e2e' },
    obsidian: { bg: '#e8e4df', text: '#1a1a2e', accent: '#706040', border: '#3d3d50' },
    white:    { bg: '#ffffff', text: '#1a1a1a', accent: '#555555', border: '#999999' }
  };

  // ============================================================
  //  Font catalog (grouped for dropdown rendering)
  // ============================================================
  var SC_FONTS = [
    { group: 'Blackletter / Gothic', fonts: [
      { value: 'UnifrakturMaguntia', family: "'UnifrakturMaguntia', cursive" },
      { value: 'Grenze Gotisch',     family: "'Grenze Gotisch', cursive" },
      { value: 'Pirata One',         family: "'Pirata One', system-ui" },
      { value: 'Germania One',       family: "'Germania One', cursive" }
    ]},
    { group: 'Medieval / Renaissance', fonts: [
      { value: 'MedievalSharp',  family: "'MedievalSharp', cursive" },
      { value: 'Metamorphous',   family: "'Metamorphous', cursive" },
      { value: 'Almendra',       family: "'Almendra', serif" },
      { value: 'Eagle Lake',     family: "'Eagle Lake', cursive" },
      { value: 'Uncial Antiqua', family: "'Uncial Antiqua', cursive" }
    ]},
    { group: 'Classical Serif', fonts: [
      { value: 'Cinzel',             family: "'Cinzel', serif" },
      { value: 'Cinzel Decorative',  family: "'Cinzel Decorative', cursive" },
      { value: 'EB Garamond',        family: "'EB Garamond', serif" },
      { value: 'Cormorant Garamond', family: "'Cormorant Garamond', serif" },
      { value: 'Caudex',             family: "'Caudex', serif" },
      { value: 'Sorts Mill Goudy',   family: "'Sorts Mill Goudy', serif" },
      { value: 'Goudy Bookletter 1911', family: "'Goudy Bookletter 1911', serif" }
    ]},
    { group: 'Calligraphy / Script', fonts: [
      { value: 'Fondamento',    family: "'Fondamento', cursive" },
      { value: 'Jim Nightshade', family: "'Jim Nightshade', cursive" },
      { value: 'Pinyon Script', family: "'Pinyon Script', cursive" },
      { value: 'Great Vibes',   family: "'Great Vibes', cursive" },
      { value: 'Tangerine',     family: "'Tangerine', cursive" }
    ]}
  ];

  // Build a flat lookup: fontValue -> family string
  var SC_FONT_FAMILY = {};
  for (var gi = 0; gi < SC_FONTS.length; gi++) {
    for (var fi = 0; fi < SC_FONTS[gi].fonts.length; fi++) {
      SC_FONT_FAMILY[SC_FONTS[gi].fonts[fi].value] = SC_FONTS[gi].fonts[fi].family;
    }
  }

  var SC_FONT_SAMPLE = 'Order of the Warrior';

  // ============================================================
  //  State
  // ============================================================
  var sgState = {
    template:   SgConfig.autoTemplate || 'B',
    palette:    'classic',
    borderStyle: 'classic',
    celtic: { strandSize: 4, outlineWidth: 1, fillColor: '#8b6914', strokeColor: '#6b5a32' },
    fonts: {
      title:      'MedievalSharp',
      recipient:  'MedievalSharp',
      body:       'EB Garamond',
      signatures: 'EB Garamond'
    },
    recipient:  SgConfig.persona || '',
    recipientDisplay: SgConfig.persona || '',
    awardName:  SgConfig.awardName || '',
    rank:       SgConfig.rank || 0,
    date:       SgConfig.date || '',
    givenBy:    SgConfig.givenBy || '',
    givenByDisplay: SgConfig.givenBy || '',
    park:       SgConfig.parkName || '',
    kingdom:    SgConfig.kingdomName || '',
    bodyText:   '',
    bodyMode:   'auto', // 'auto' or 'manual'
    heraldry: {
      kingdom: !!SgConfig.kingdomHeraldry,
      park:    !!SgConfig.parkHeraldry,
      player:  !!SgConfig.playerHeraldry
    },
    heraldryUrls: {
      kingdom: SgConfig.kingdomHeraldry || '',
      park:    SgConfig.parkHeraldry || '',
      player:  SgConfig.playerHeraldry || ''
    },
    signatures: [
      { name: SgConfig.givenBy || '', role: 'Monarch' },
      { name: '', role: 'Regent' },
      { name: '', role: '' }
    ]
  };

  // Artwork state — each slot is null or {id: N, url: '...'}
  sgState.artwork = {
    watermark: null, full_border: null, border_left: null, border_right: null,
    border_top: null, border_bottom: null, center_image: null, top_graphic: null
  };

  // Artwork slot definitions
  // HTML escape helper to prevent XSS in innerHTML
  function sgEscapeHtml(s) {
    if (!s) return '';
    var d = document.createElement('div');
    d.textContent = String(s);
    return d.innerHTML;
  }

  var ARTWORK_SLOTS = {
    watermark:     { label: 'Page Watermark',     w: 2550, h: 3300, pw: 850, ph: 1100, desc: 'Full-page semi-transparent background' },
    full_border:   { label: 'Full Border',        w: 2550, h: 3300, pw: 850, ph: 1100, desc: 'Complete page frame overlay' },
    border_left:   { label: 'Left Border',        w: 300,  h: 3300, pw: 100, ph: 1100, desc: 'Left edge decorative strip' },
    border_right:  { label: 'Right Border',       w: 300,  h: 3300, pw: 100, ph: 1100, desc: 'Right edge decorative strip' },
    border_top:    { label: 'Top Border',         w: 2550, h: 400,  pw: 850, ph: 133,  desc: 'Top edge decorative strip' },
    border_bottom: { label: 'Bottom Border',      w: 2550, h: 400,  pw: 850, ph: 133,  desc: 'Bottom edge decorative strip' },
    center_image:  { label: 'Center Image',       w: 1200, h: 1200, pw: 400, ph: 400,  desc: 'Semi-transparent body area graphic' },
    top_graphic:   { label: 'Top Center Graphic', w: 800,  h: 500,  pw: 267, ph: 167,  desc: 'Decorative element above title' }
  };

  // Canvas positions for each artwork slot (preview resolution)
  var ARTWORK_POSITIONS = {
    watermark:     { x: 0,   y: 0,   w: 850, h: 1100, alpha: 0.10 },
    full_border:   { x: 0,   y: 0,   w: 850, h: 1100, alpha: 1.0 },
    border_left:   { x: 0,   y: 0,   w: 100, h: 1100, alpha: 1.0 },
    border_right:  { x: 750, y: 0,   w: 100, h: 1100, alpha: 1.0 },
    border_top:    { x: 0,   y: 0,   w: 850, h: 133,  alpha: 1.0 },
    border_bottom: { x: 0,   y: 967, w: 850, h: 133,  alpha: 1.0 },
    top_graphic:   { x: 292, y: 17,  w: 267, h: 167,  alpha: 1.0 },
    center_image:  { x: 225, y: 350, w: 400, h: 400,  alpha: 0.15 }
  };

  // Artwork slot rendering order (defines z-order within categories)
  var ARTWORK_SLOT_KEYS = ['watermark', 'full_border', 'border_left', 'border_right', 'border_top', 'border_bottom', 'center_image', 'top_graphic'];

  // Image cache for artwork
  var sgArtworkImages = {};
  var sgArtworkImagesLoading = {};
  for (var _ak in ARTWORK_SLOTS) { sgArtworkImages[_ak] = null; sgArtworkImagesLoading[_ak] = false; }

  // Image cache for heraldry
  var sgImages = { kingdom: null, park: null, player: null };
  var sgImagesLoading = { kingdom: false, park: false, player: false };

  // ============================================================
  //  Helper: Load an image and cache it
  // ============================================================
  function sgLoadImage(key, url, cb) {
    if (!url) { sgImages[key] = null; if (cb) cb(); return; }
    if (sgImages[key] && sgImages[key].src === url) { if (cb) cb(); return; }
    sgImagesLoading[key] = true;
    var img = new Image();
    img.crossOrigin = 'anonymous';
    img.onload = function() {
      sgImages[key] = img;
      sgImagesLoading[key] = false;
      if (cb) cb();
    };
    img.onerror = function() {
      sgImages[key] = null;
      sgImagesLoading[key] = false;
      if (cb) cb();
    };
    img.src = url;
  }

  // ============================================================
  //  Helper: Build heraldry URL from base + zero-padded ID
  // ============================================================
  function sgBuildHeraldryUrl(base, padLen, entityId) {
    if (!base || !entityId || entityId === '0' || entityId === 0) return '';
    var padded = String(entityId);
    while (padded.length < padLen) padded = '0' + padded;
    return base + padded + '.jpg';
  }

  // ============================================================
  //  Helper: Update heraldry toggle preview thumbnail
  // ============================================================
  function sgUpdateHeraldryPreview(toggleId, url) {
    var toggle = document.getElementById(toggleId);
    if (!toggle) return;
    var row = toggle.closest('.sc-toggle-row');
    if (!row) return;
    var preview = row.querySelector('.sc-toggle-preview');
    if (!preview) return;
    if (url) {
      var img = preview.querySelector('img');
      if (img) {
        img.src = url;
      } else {
        img = document.createElement('img');
        img.src = url;
        img.alt = 'Heraldry';
        preview.appendChild(img);
      }
    } else {
      var existing = preview.querySelector('img');
      if (existing) existing.remove();
    }
  }

  // ============================================================
  //  Helper: Load heraldry when a toggle is switched on
  // ============================================================
  function sgLoadHeraldryForToggle(cfg) {
    function clearSpinner() {
      var toggle = document.getElementById(cfg.id);
      if (toggle) {
        var row = toggle.closest('.sc-toggle-row');
        if (row) row.classList.remove('sc-loading');
      }
    }
    // If already loaded and cached, just re-render
    if (sgImages[cfg.key]) {
      clearSpinner();
      sgRender();
      return;
    }

    // Try to build a URL from the current IDs
    var entityId = 0;
    if (cfg.idKey === 'mundaneId') {
      entityId = parseInt((document.getElementById('sc-recipient-id') || {}).value || '0', 10) || SgConfig.mundaneId || 0;
    } else if (cfg.idKey === 'parkId') {
      entityId = SgConfig.parkId || 0;
    } else if (cfg.idKey === 'kingdomId') {
      entityId = SgConfig.kingdomId || 0;
    }

    var url = sgBuildHeraldryUrl(cfg.base, cfg.padLen, entityId);
    if (!url) {
      // No ID available — use the URL from SgConfig if we have one
      url = sgState.heraldryUrls[cfg.key] || '';
    }
    if (!url) {
      sgRender();
      return;
    }

    // Store the URL and update thumbnail
    sgState.heraldryUrls[cfg.key] = url;
    sgUpdateHeraldryPreview(cfg.id, url);

    // Load the image — try .jpg first, fall back to .png
    sgLoadImage(cfg.key, url, function() {
      if (!sgImages[cfg.key] && url.indexOf('.jpg') > -1) {
        // .jpg failed, try .png
        var pngUrl = url.replace(/\.jpg$/, '.png');
        sgState.heraldryUrls[cfg.key] = pngUrl;
        sgUpdateHeraldryPreview(cfg.id, pngUrl);
        sgLoadImage(cfg.key, pngUrl, function() {
          clearSpinner();
          if (!sgImages[cfg.key]) {
            sgToast('Heraldry image not found for ' + cfg.key, 'warn');
          }
          sgRender();
        });
      } else {
        clearSpinner();
        sgRender();
      }
    });
  }

  // ============================================================
  //  Helper: Word-wrap text on canvas
  // ============================================================
  function sgWrapText(ctx, text, x, y, maxWidth, lineHeight) {
    var words = text.split(' ');
    var line = '';
    var lines = [];
    for (var i = 0; i < words.length; i++) {
      var testLine = line + (line ? ' ' : '') + words[i];
      var metrics = ctx.measureText(testLine);
      if (metrics.width > maxWidth && line !== '') {
        lines.push(line);
        line = words[i];
      } else {
        line = testLine;
      }
    }
    if (line) lines.push(line);
    for (var j = 0; j < lines.length; j++) {
      ctx.fillText(lines[j], x, y + j * lineHeight);
    }
    return lines.length;
  }

  // ============================================================
  //  Helper: Generate body text
  // ============================================================
  function sgGenerateBodyText() {
    var persona = sgState.recipientDisplay || sgState.recipient || 'the recipient';
    var award = sgState.awardName || 'this honor';
    var rank = sgState.rank;
    var dateStr = sgState.date;
    var kingdom = sgState.kingdom;
    var park = sgState.park;
    var tplKey = sgState.template || 'B';

    // Parse date for fancy format
    var day = 0, suffix = 'th', monthName = '', year = '';
    if (dateStr) {
      var parts = dateStr.split('-');
      if (parts.length === 3) {
        var months = ['January','February','March','April','May','June',
                      'July','August','September','October','November','December'];
        day = parseInt(parts[2], 10);
        suffix = 'th';
        if (day === 1 || day === 21 || day === 31) suffix = 'st';
        else if (day === 2 || day === 22) suffix = 'nd';
        else if (day === 3 || day === 23) suffix = 'rd';
        monthName = months[parseInt(parts[1], 10) - 1] || '';
        year = parts[0];
      }
    }

    var text = '';
    if (tplKey === 'A') {
      // Knight / Peerage
      text = 'To all and singular who shall see these presents, greetings. Be it known that by the right and authority vested in the Crown of ' + (kingdom || 'the Kingdom') + ', and in recognition of valor, honor, and service, We do hereby elevate ' + persona + ' to the ' + award + '.';
      if (day && monthName) {
        text += ' Given under Our hand this ' + day + suffix + ' day of ' + monthName + ', in the year ' + year;
        if (park) text += ', at ' + park;
        if (kingdom) text += ', in the Kingdom of ' + kingdom;
        text += '.';
      }
    } else if (tplKey === 'C') {
      // Title / Office
      text = 'Be it proclaimed that ' + persona + ' is hereby recognized and granted the title of ' + award + ', with all rights, privileges, and responsibilities thereto pertaining, by the authority of the Crown of ' + (kingdom || 'the Kingdom') + '.';
      if (day && monthName) {
        text += ' Given this ' + day + suffix + ' day of ' + monthName + ', ' + year + '.';
      }
    } else {
      // Template B: Order / Award
      text = 'Let it be known to all that ' + persona + ', having demonstrated worth and dedication, is hereby granted the ' + award;
      if (rank && rank > 0) {
        var ordinal = rank + 'th';
        if (rank === 1 || rank === 21 || rank === 31) ordinal = rank + 'st';
        else if (rank === 2 || rank === 22) ordinal = rank + 'nd';
        else if (rank === 3 || rank === 23) ordinal = rank + 'rd';
        text += ', ' + ordinal + ' rank';
      }
      text += ', by the authority of the Crown of ' + (kingdom || 'the Kingdom') + '.';
      if (day && monthName) {
        text += ' Done this ' + day + suffix + ' day of ' + monthName + ', ' + year + '.';
      }
    }

    return text;
  }

  // ============================================================
  //  Canvas: Draw decorative border (multiple styles)
  // ============================================================
  var BORDER_STYLES = {
    classic: 'Classic', ornate: 'Ornate', celtic: 'Celtic', simple: 'Simple',
    royal: 'Royal', rustic: 'Rustic', filigree: 'Filigree', none: 'None'
  };

  function sgDrawBorder(ctx, w, h, palette, template, borderStyle) {
    var colors = PALETTES[palette] || PALETTES.classic;
    var style = borderStyle || 'classic';
    if (style === 'none') return;
    ctx.save();
    if (style === 'classic') sgDrawBorderClassic(ctx, w, h, colors);
    else if (style === 'ornate') sgDrawBorderOrnate(ctx, w, h, colors);
    else if (style === 'celtic') sgDrawBorderCeltic(ctx, w, h, colors);
    else if (style === 'simple') sgDrawBorderSimple(ctx, w, h, colors);
    else if (style === 'royal') sgDrawBorderRoyal(ctx, w, h, colors);
    else if (style === 'rustic') sgDrawBorderRustic(ctx, w, h, colors);
    else if (style === 'filigree') sgDrawBorderFiligree(ctx, w, h, colors);
    ctx.restore();
  }

  // ---- Classic: double border + diamond corners ----
  function sgDrawBorderClassic(ctx, w, h, c) {
    ctx.strokeStyle = c.border; ctx.lineWidth = 4;
    ctx.strokeRect(28, 28, w-56, h-56);
    ctx.lineWidth = 2; ctx.strokeRect(36, 36, w-72, h-72);
    var corners = [[30,30],[w-30,30],[30,h-30],[w-30,h-30]];
    ctx.lineWidth = 2.5; ctx.strokeStyle = c.accent;
    for (var ci = 0; ci < corners.length; ci++) {
      var cx = corners[ci][0], cy = corners[ci][1];
      var dx = (ci%2===0)?1:-1, dy = (ci<2)?1:-1;
      ctx.beginPath();
      ctx.moveTo(cx, cy+dy*65); ctx.quadraticCurveTo(cx+dx*6, cy+dy*8, cx, cy);
      ctx.quadraticCurveTo(cx+dx*8, cy+dy*6, cx+dx*65, cy); ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(cx+dx*11, cy); ctx.lineTo(cx+dx*20, cy+dy*9);
      ctx.lineTo(cx+dx*11, cy+dy*18); ctx.lineTo(cx+dx*2, cy+dy*9);
      ctx.closePath(); ctx.fillStyle = c.accent; ctx.fill();
      ctx.beginPath();
      ctx.moveTo(cx+dx*11, cy+dy*2); ctx.lineTo(cx+dx*16, cy+dy*9);
      ctx.lineTo(cx+dx*11, cy+dy*16); ctx.lineTo(cx+dx*6, cy+dy*9);
      ctx.closePath(); ctx.lineWidth = 1; ctx.stroke(); ctx.lineWidth = 2.5;
    }
    ctx.lineWidth = 2;
    ctx.beginPath(); ctx.moveTo(w/2-60,22); ctx.quadraticCurveTo(w/2-30,6,w/2,12);
    ctx.quadraticCurveTo(w/2+30,6,w/2+60,22); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(w/2-60,h-22); ctx.quadraticCurveTo(w/2-30,h-6,w/2,h-12);
    ctx.quadraticCurveTo(w/2+30,h-6,w/2+60,h-22); ctx.stroke();
    ctx.lineWidth = 1; ctx.globalAlpha = 0.3; ctx.strokeStyle = c.border;
    ctx.beginPath(); ctx.moveTo(36,80); ctx.lineTo(36,h-80); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(40,80); ctx.lineTo(40,h-80); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(w-36,80); ctx.lineTo(w-36,h-80); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(w-40,80); ctx.lineTo(w-40,h-80); ctx.stroke();
  }

  // ---- Ornate: triple border + flourish corners + center crests ----
  function sgDrawBorderOrnate(ctx, w, h, c) {
    ctx.strokeStyle = c.border; ctx.lineWidth = 5;
    ctx.strokeRect(22, 22, w-44, h-44);
    ctx.save(); ctx.globalAlpha = 0.4; ctx.strokeStyle = c.accent; ctx.lineWidth = 1;
    ctx.strokeRect(30, 30, w-60, h-60); ctx.restore();
    ctx.strokeStyle = c.border; ctx.lineWidth = 2;
    ctx.strokeRect(36, 36, w-72, h-72);
    var corners = [[24,24],[w-24,24],[24,h-24],[w-24,h-24]];
    ctx.strokeStyle = c.accent; ctx.fillStyle = c.accent;
    for (var ci = 0; ci < corners.length; ci++) {
      var cx = corners[ci][0], cy = corners[ci][1];
      var dx = (ci%2===0)?1:-1, dy = (ci<2)?1:-1;
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(cx, cy+dy*80);
      ctx.bezierCurveTo(cx+dx*4, cy+dy*40, cx+dx*15, cy+dy*15, cx, cy);
      ctx.bezierCurveTo(cx+dx*15, cy+dy*15, cx+dx*40, cy+dy*4, cx+dx*80, cy);
      ctx.stroke();
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.moveTo(cx+dx*8, cy+dy*55);
      ctx.bezierCurveTo(cx+dx*14, cy+dy*30, cx+dx*20, cy+dy*20, cx+dx*12, cy+dy*12);
      ctx.bezierCurveTo(cx+dx*20, cy+dy*20, cx+dx*30, cy+dy*14, cx+dx*55, cy+dy*8);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(cx+dx*14, cy+dy*4); ctx.lineTo(cx+dx*22, cy+dy*14);
      ctx.lineTo(cx+dx*14, cy+dy*24); ctx.lineTo(cx+dx*6, cy+dy*14);
      ctx.closePath(); ctx.fill();
      ctx.beginPath(); ctx.arc(cx+dx*35, cy+dy*6, 3, 0, Math.PI*2); ctx.fill();
      ctx.beginPath(); ctx.arc(cx+dx*6, cy+dy*35, 3, 0, Math.PI*2); ctx.fill();
    }
    ctx.lineWidth = 2;
    ctx.beginPath(); ctx.moveTo(w/2-80,20); ctx.quadraticCurveTo(w/2-40,2,w/2,10);
    ctx.quadraticCurveTo(w/2+40,2,w/2+80,20); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(w/2,8); ctx.lineTo(w/2,20); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(w/2-80,h-20); ctx.quadraticCurveTo(w/2-40,h-2,w/2,h-10);
    ctx.quadraticCurveTo(w/2+40,h-2,w/2+80,h-20); ctx.stroke();
    ctx.lineWidth = 1; ctx.globalAlpha = 0.25; ctx.strokeStyle = c.border;
    for (var si = 0; si < 3; si++) {
      var sx = 38 + si*3;
      ctx.beginPath(); ctx.moveTo(sx, 90); ctx.lineTo(sx, h-90); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(w-sx, 90); ctx.lineTo(w-sx, h-90); ctx.stroke();
    }
  }

  // ---- Celtic: knotwork corners + braided edges ----
  // Cache the celtic knot pattern so it doesn't regenerate every render
  var _celticCache = null;
  function sgDrawBorderCeltic(ctx, w, h, c) {
    var ck = sgState.celtic;
    // Knot grid sizing — fit a band around each edge
    var cellSz = 10;        // cell size in preview pixels
    var strSz  = ck.strandSize;
    var margin = 16;        // inset from canvas edge

    // How many cells fit along each axis (must be even)
    var hCols = Math.floor((w - margin * 2) / cellSz);
    if (hCols % 2) hCols--;
    var hRows = 4; // band height in cells (must be even)

    var vRows = Math.floor((h - margin * 2) / cellSz);
    if (vRows % 2) vRows--;
    var vCols = 4; // band width in cells (must be even)

    // Generate closed-border patterns (cached)
    var cacheKey = w + 'x' + h;
    if (!_celticCache || _celticCache.key !== cacheKey) {
      _celticCache = {
        key: cacheKey,
        hBreaks: CelticKnot.symmetricRandomPattern(hRows, hCols, 0.25),
        vBreaks: CelticKnot.symmetricRandomPattern(vRows, vCols, 0.25)
      };
    }

    var bandH = hRows * cellSz; // pixel height of horizontal band
    var bandW = vCols * cellSz; // pixel width of vertical band

    // Center the bands within the available space
    var hOffX = margin + ((w - margin * 2) - hCols * cellSz) / 2;
    var vOffY = margin + ((h - margin * 2) - vRows * cellSz) / 2;

    var opts = {
      cellSize: cellSz,
      stringSize: strSz,
      strokeWidth: ck.outlineWidth,
      fillColor: ck.fillColor,
      strokeColor: ck.strokeColor
    };

    // Top band
    CelticKnot.render(ctx, Object.assign({}, opts, {
      rows: hRows, columns: hCols,
      breaks: _celticCache.hBreaks,
      offsetX: hOffX, offsetY: margin
    }));

    // Bottom band
    CelticKnot.render(ctx, Object.assign({}, opts, {
      rows: hRows, columns: hCols,
      breaks: _celticCache.hBreaks,
      offsetX: hOffX, offsetY: h - margin - bandH
    }));

    // Left band
    CelticKnot.render(ctx, Object.assign({}, opts, {
      rows: vRows, columns: vCols,
      breaks: _celticCache.vBreaks,
      offsetX: margin, offsetY: vOffY
    }));

    // Right band
    CelticKnot.render(ctx, Object.assign({}, opts, {
      rows: vRows, columns: vCols,
      breaks: _celticCache.vBreaks,
      offsetX: w - margin - bandW, offsetY: vOffY
    }));
  }

  // ---- Simple: clean single thin rule ----
  function sgDrawBorderSimple(ctx, w, h, c) {
    ctx.strokeStyle = c.border; ctx.lineWidth = 2;
    ctx.strokeRect(32, 32, w-64, h-64);
  }

  // ---- Royal: thick gilded frame + fleur-de-lis corners ----
  function sgDrawBorderRoyal(ctx, w, h, c) {
    ctx.strokeStyle = c.accent; ctx.lineWidth = 7;
    ctx.strokeRect(20, 20, w-40, h-40);
    ctx.strokeStyle = c.border; ctx.lineWidth = 1;
    ctx.strokeRect(28, 28, w-56, h-56);
    ctx.strokeRect(14, 14, w-28, h-28);
    ctx.fillStyle = c.accent; ctx.strokeStyle = c.accent;
    var corners = [[20,20],[w-20,20],[20,h-20],[w-20,h-20]];
    for (var ci = 0; ci < corners.length; ci++) {
      var cx = corners[ci][0], cy = corners[ci][1];
      var dx = (ci%2===0)?1:-1, dy = (ci<2)?1:-1;
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(cx+dx*8, cy+dy*8);
      ctx.bezierCurveTo(cx+dx*2, cy+dy*30, cx+dx*18, cy+dy*35, cx+dx*8, cy+dy*50);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(cx+dx*8, cy+dy*8);
      ctx.bezierCurveTo(cx+dx*30, cy+dy*2, cx+dx*35, cy+dy*18, cx+dx*50, cy+dy*8);
      ctx.stroke();
      ctx.beginPath(); ctx.arc(cx+dx*12, cy+dy*12, 5, 0, Math.PI*2); ctx.fill();
      ctx.beginPath(); ctx.arc(cx+dx*25, cy+dy*4, 2.5, 0, Math.PI*2); ctx.fill();
      ctx.beginPath(); ctx.arc(cx+dx*4, cy+dy*25, 2.5, 0, Math.PI*2); ctx.fill();
    }
    ctx.lineWidth = 2.5;
    ctx.beginPath();
    ctx.moveTo(w/2-90,16); ctx.quadraticCurveTo(w/2-45,-4,w/2-20,12);
    ctx.quadraticCurveTo(w/2,2,w/2+20,12); ctx.quadraticCurveTo(w/2+45,-4,w/2+90,16);
    ctx.stroke();
    ctx.beginPath(); ctx.arc(w/2, 8, 4, 0, Math.PI*2); ctx.fill();
    ctx.beginPath();
    ctx.moveTo(w/2-90,h-16); ctx.quadraticCurveTo(w/2-45,h+4,w/2-20,h-12);
    ctx.quadraticCurveTo(w/2,h-2,w/2+20,h-12); ctx.quadraticCurveTo(w/2+45,h+4,w/2+90,h-16);
    ctx.stroke();
    ctx.beginPath(); ctx.arc(w/2, h-8, 4, 0, Math.PI*2); ctx.fill();
  }

  // ---- Rustic: hand-drawn rough double line ----
  function sgDrawBorderRustic(ctx, w, h, c) {
    ctx.strokeStyle = c.border;
    function wobblyRect(x, y, rw, rh, wobble) {
      var segs = 40;
      function edge(getXY) {
        ctx.beginPath();
        for (var i = 0; i <= segs; i++) {
          var pt = getXY(i / segs);
          if (i === 0) ctx.moveTo(pt[0], pt[1]); else ctx.lineTo(pt[0], pt[1]);
        }
        ctx.stroke();
      }
      edge(function(t){return [x+rw*t, y+Math.sin(t*segs*1.7)*wobble];});
      edge(function(t){return [x+rw*t, y+rh+Math.sin(t*segs*1.3+2)*wobble];});
      edge(function(t){return [x+Math.sin(t*segs*1.5+1)*wobble, y+rh*t];});
      edge(function(t){return [x+rw+Math.sin(t*segs*1.9+3)*wobble, y+rh*t];});
    }
    ctx.lineWidth = 3; wobblyRect(26, 26, w-52, h-52, 1.5);
    ctx.lineWidth = 1.5; ctx.globalAlpha = 0.5; wobblyRect(34, 34, w-68, h-68, 1.2);
    ctx.globalAlpha = 0.6; ctx.lineWidth = 2;
    var corners = [[30,30],[w-30,30],[30,h-30],[w-30,h-30]];
    for (var ci = 0; ci < corners.length; ci++) {
      var cx = corners[ci][0], cy = corners[ci][1];
      var dx = (ci%2===0)?1:-1, dy = (ci<2)?1:-1;
      ctx.beginPath(); ctx.moveTo(cx+dx*4,cy+dy*4); ctx.lineTo(cx+dx*18,cy+dy*18); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(cx+dx*18,cy+dy*4); ctx.lineTo(cx+dx*4,cy+dy*18); ctx.stroke();
    }
  }

  // ---- Filigree: delicate scrollwork + vine corners ----
  function sgDrawBorderFiligree(ctx, w, h, c) {
    ctx.strokeStyle = c.border; ctx.lineWidth = 1.5;
    ctx.strokeRect(28, 28, w-56, h-56);
    ctx.strokeStyle = c.accent; ctx.lineWidth = 1.5; ctx.fillStyle = c.accent;
    var corners = [[28,28],[w-28,28],[28,h-28],[w-28,h-28]];
    for (var ci = 0; ci < corners.length; ci++) {
      var cx = corners[ci][0], cy = corners[ci][1];
      var dx = (ci%2===0)?1:-1, dy = (ci<2)?1:-1;
      ctx.beginPath();
      ctx.moveTo(cx, cy+dy*70);
      ctx.bezierCurveTo(cx+dx*3, cy+dy*45, cx+dx*12, cy+dy*20, cx+dx*6, cy+dy*6);
      ctx.bezierCurveTo(cx+dx*20, cy+dy*12, cx+dx*45, cy+dy*3, cx+dx*70, cy);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(cx+dx*6, cy+dy*6);
      ctx.bezierCurveTo(cx+dx*16, cy+dy*16, cx+dx*22, cy+dy*10, cx+dx*18, cy+dy*4);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(cx+dx*6, cy+dy*6);
      ctx.bezierCurveTo(cx+dx*16, cy+dy*16, cx+dx*10, cy+dy*22, cx+dx*4, cy+dy*18);
      ctx.stroke();
      for (var li = 0; li < 3; li++) {
        ctx.beginPath(); ctx.ellipse(cx+dx*(15+li*16), cy+dy*(2-li*0.5), 4, 2, dx*dy*0.6, 0, Math.PI*2); ctx.fill();
        ctx.beginPath(); ctx.ellipse(cx+dx*(2-li*0.5), cy+dy*(15+li*16), 2, 4, dx*dy*0.6, 0, Math.PI*2); ctx.fill();
      }
    }
    ctx.globalAlpha = 0.6;
    ctx.beginPath(); ctx.moveTo(w/2-40, 26); ctx.quadraticCurveTo(w/2, 14, w/2+40, 26); ctx.stroke();
    ctx.beginPath(); ctx.ellipse(w/2, 20, 5, 3, 0, 0, Math.PI*2); ctx.fill();
    ctx.beginPath(); ctx.moveTo(w/2-40, h-26); ctx.quadraticCurveTo(w/2, h-14, w/2+40, h-26); ctx.stroke();
    ctx.beginPath(); ctx.ellipse(w/2, h-20, 5, 3, 0, 0, Math.PI*2); ctx.fill();
  }

  // ============================================================
  //  Canvas: Draw decorative divider (diamond-line-diamond motif)
  // ============================================================
  function sgDrawDivider(ctx, cx, cy, width, color, opacity) {
    ctx.save();
    ctx.globalAlpha = opacity;
    ctx.strokeStyle = color;
    ctx.fillStyle = color;
    ctx.lineWidth = 1;
    // Left line
    ctx.beginPath();
    ctx.moveTo(cx - width / 2, cy);
    ctx.lineTo(cx - 8, cy);
    ctx.stroke();
    // Right line
    ctx.beginPath();
    ctx.moveTo(cx + 8, cy);
    ctx.lineTo(cx + width / 2, cy);
    ctx.stroke();
    // Center diamond
    ctx.beginPath();
    ctx.moveTo(cx, cy - 5);
    ctx.lineTo(cx + 6, cy);
    ctx.lineTo(cx, cy + 5);
    ctx.lineTo(cx - 6, cy);
    ctx.closePath();
    ctx.fill();
    // Endpoint dots
    ctx.beginPath();
    ctx.arc(cx - width / 2, cy, 2, 0, Math.PI * 2);
    ctx.fill();
    ctx.beginPath();
    ctx.arc(cx + width / 2, cy, 2, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }

  // ============================================================
  //  Canvas: Main render
  // ============================================================
  // ============================================================
  //  Helper: Draw a single artwork slot on canvas
  // ============================================================
  function sgDrawArtworkSlot(ctx, slotKey) {
    if (!sgState.artwork[slotKey] || !sgArtworkImages[slotKey]) return;
    var pos = ARTWORK_POSITIONS[slotKey];
    if (!pos) return;
    ctx.save();
    ctx.globalAlpha = pos.alpha;
    ctx.drawImage(sgArtworkImages[slotKey], pos.x, pos.y, pos.w, pos.h);
    ctx.restore();
  }

  // ============================================================
  //  Helper: Load artwork image for a slot
  // ============================================================
  function sgLoadArtworkImage(slotKey, url, cb) {
    if (!url) { sgArtworkImages[slotKey] = null; if (cb) cb(); return; }
    if (sgArtworkImages[slotKey] && sgArtworkImages[slotKey].src === url) { if (cb) cb(); return; }
    sgArtworkImagesLoading[slotKey] = true;
    var img = new Image();
    img.crossOrigin = 'anonymous';
    img.onload = function() {
      sgArtworkImages[slotKey] = img;
      sgArtworkImagesLoading[slotKey] = false;
      if (cb) cb();
    };
    img.onerror = function() {
      sgArtworkImages[slotKey] = null;
      sgArtworkImagesLoading[slotKey] = false;
      if (cb) cb();
    };
    img.src = url;
  }

  function sgRender() {
    var canvas = document.getElementById('sc-canvas');
    if (!canvas) return;
    var ctx = canvas.getContext('2d');
    var w = canvas.width;
    var h = canvas.height;
    var tpl = TEMPLATES[sgState.template] || TEMPLATES.B;
    var pal = PALETTES[sgState.palette] || PALETTES.classic;
    // Per-element fonts accessed via sgState.fonts.*

    // ---- Clear & fill background ----
    ctx.clearRect(0, 0, w, h);
    ctx.fillStyle = pal.bg;
    ctx.fillRect(0, 0, w, h);

    // Subtle parchment texture (pre-rendered offscreen canvas, drawn once)
    if (!sgRender._noiseCanvas) {
      var nc = document.createElement('canvas');
      nc.width = w; nc.height = h;
      var nctx = nc.getContext('2d');
      nctx.fillStyle = '#000';
      for (var tx = 0; tx < w; tx += 4) {
        for (var ty = 0; ty < h; ty += 4) {
          if (Math.random() > 0.5) nctx.fillRect(tx, ty, 2, 2);
        }
      }
      sgRender._noiseCanvas = nc;
    }
    ctx.save();
    ctx.globalAlpha = 0.05;
    ctx.drawImage(sgRender._noiseCanvas, 0, 0);
    ctx.restore();

    // Radial vignette
    var grad = ctx.createRadialGradient(w / 2, h / 2, w * 0.2, w / 2, h / 2, w * 0.75);
    grad.addColorStop(0, 'rgba(0,0,0,0)');
    grad.addColorStop(1, 'rgba(0,0,0,0.04)');
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, w, h);

    // ---- Artwork: watermark (behind everything) ----
    sgDrawArtworkSlot(ctx, 'watermark');

    // ---- Draw border ----
    sgDrawBorder(ctx, w, h, sgState.palette, sgState.template, sgState.borderStyle);

    // ---- Artwork: full border + edge borders + top graphic (over drawn border, before heraldry) ----
    sgDrawArtworkSlot(ctx, 'full_border');
    sgDrawArtworkSlot(ctx, 'border_left');
    sgDrawArtworkSlot(ctx, 'border_right');
    sgDrawArtworkSlot(ctx, 'border_top');
    sgDrawArtworkSlot(ctx, 'border_bottom');
    sgDrawArtworkSlot(ctx, 'top_graphic');

    // ---- Draw heraldry images ----
    var heraldryPositions = tpl.heraldry;
    if (sgState.heraldry.kingdom && sgImages.kingdom) {
      var kp = heraldryPositions.kingdom;
      ctx.save();
      ctx.globalAlpha = 0.95;
      ctx.drawImage(sgImages.kingdom, kp.x, kp.y, kp.w, kp.h);
      ctx.restore();
    }
    if (sgState.heraldry.park && sgImages.park) {
      var pp = heraldryPositions.park;
      ctx.save();
      ctx.globalAlpha = 0.95;
      ctx.drawImage(sgImages.park, pp.x, pp.y, pp.w, pp.h);
      ctx.restore();
    }
    if (sgState.heraldry.player && sgImages.player) {
      var plp = heraldryPositions.player;
      ctx.save();
      ctx.globalAlpha = 0.95;
      ctx.drawImage(sgImages.player, plp.x, plp.y, plp.w, plp.h);
      ctx.restore();
    }

    // ---- Artwork: center image (semi-transparent behind text) ----
    sgDrawArtworkSlot(ctx, 'center_image');

    // ---- Title text ----
    ctx.textAlign = 'center';
    ctx.textBaseline = 'top';
    ctx.fillStyle = pal.accent;
    var titleFont = sgState.fonts.title;
    ctx.font = (titleFont === 'EB Garamond' ? 'bold ' : '') + tpl.title.size + 'px ' + titleFont;
    var titleText = sgState.awardName || 'Award Title';
    // Scale down if too wide
    var titleFontSize = tpl.title.size;
    while (ctx.measureText(titleText).width > tpl.title.maxWidth && titleFontSize > 20) {
      titleFontSize -= 2;
      ctx.font = (titleFont === 'EB Garamond' ? 'bold ' : '') + titleFontSize + 'px ' + titleFont;
    }
    ctx.fillText(titleText, tpl.title.x, tpl.title.y);

    // Decorative divider above title (Template A only)
    if (sgState.template === 'A') {
      sgDrawDivider(ctx, tpl.title.x, tpl.title.y - 30, 250, pal.accent, 0.6);
    }
    // Decorative divider below title
    sgDrawDivider(ctx, tpl.title.x, tpl.title.y + titleFontSize + 25, 250, pal.accent, 0.6);

    // ---- Recipient name ----
    ctx.fillStyle = pal.text;
    var recipFont = sgState.fonts.recipient;
    ctx.font = '' + tpl.recipient.size + 'px ' + recipFont;
    var recipientText = sgState.recipientDisplay || sgState.recipient || 'Recipient Name';
    var recipFontSize = tpl.recipient.size;
    while (ctx.measureText(recipientText).width > tpl.recipient.maxWidth && recipFontSize > 16) {
      recipFontSize -= 2;
      ctx.font = '' + recipFontSize + 'px ' + recipFont;
    }
    ctx.fillText(recipientText, tpl.recipient.x, tpl.recipient.y);

    // ---- Body text (word-wrapped) ----
    ctx.fillStyle = pal.text;
    ctx.font = '' + tpl.body.size + 'px ' + sgState.fonts.body;
    ctx.textAlign = 'center';
    var bodyText = sgState.bodyText || sgGenerateBodyText();
    sgWrapText(ctx, bodyText, tpl.body.x, tpl.body.y, tpl.body.maxWidth, tpl.body.lineHeight);

    // ---- Date / Location line ----
    var dateLine = '';
    if (sgState.park || sgState.kingdom) {
      dateLine = 'Given at';
      if (sgState.park) {
        dateLine += ' ' + sgState.park;
      }
      if (sgState.kingdom) {
        dateLine += (sgState.park ? ', ' : ' ') + sgState.kingdom;
      }
    }
    if (dateLine) {
      ctx.font = '' + Math.round(tpl.body.size * 0.8) + 'px ' + sgState.fonts.body;
      ctx.fillStyle = pal.text;
      ctx.globalAlpha = 0.6;
      ctx.textAlign = 'center';
      ctx.fillText(dateLine, w / 2, tpl.sigY - 40);
      ctx.globalAlpha = 1.0;
    }

    // ---- Seal element ----
    var sealX = w / 2;
    var sealY = tpl.sigY - 100;
    // Outer circle
    ctx.save();
    ctx.strokeStyle = pal.accent;
    ctx.globalAlpha = 0.6;
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.arc(sealX, sealY, 50, 0, Math.PI * 2);
    ctx.stroke();
    // Inner circle
    ctx.globalAlpha = 0.4;
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.arc(sealX, sealY, 38, 0, Math.PI * 2);
    ctx.stroke();
    // 12 radial tick marks
    ctx.globalAlpha = 0.5;
    ctx.lineWidth = 1;
    for (var ti = 0; ti < 12; ti++) {
      var angle = (ti / 12) * Math.PI * 2;
      var tx1 = sealX + Math.cos(angle) * 50;
      var ty1 = sealY + Math.sin(angle) * 50;
      var tx2 = sealX + Math.cos(angle) * 58;
      var ty2 = sealY + Math.sin(angle) * 58;
      ctx.beginPath();
      ctx.moveTo(tx1, ty1);
      ctx.lineTo(tx2, ty2);
      ctx.stroke();
    }
    // Center initials (skip "The", "Kingdom", "of")
    var sealInitials = (sgState.kingdom || '').split(/\s+/).filter(function(w) {
      return !(/^(the|kingdom|of)$/i.test(w));
    }).map(function(w) { return w.charAt(0).toUpperCase(); }).join('');
    if (sealInitials) {
      ctx.globalAlpha = 0.25;
      ctx.fillStyle = pal.accent;
      var sealFontSize = sealInitials.length > 2 ? 28 : 36;
      ctx.font = sealFontSize + 'px ' + sgState.fonts.body;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(sealInitials, sealX, sealY);
    }
    ctx.restore();

    // ---- Decorative divider above signatures ----
    sgDrawDivider(ctx, w / 2, tpl.sigY - 60, 350, pal.accent, 0.4);

    // ---- Signature lines ----
    // Build list of active signature indices based on visibility
    var activeSigs = [0]; // sig1 always visible
    if (sgSig2Visible) activeSigs.push(1);
    if (tpl.sigCount >= 3) activeSigs.push(2);
    var sigCount = activeSigs.length;
    var sigSpacing = w / (sigCount + 1);
    ctx.strokeStyle = pal.text;
    ctx.fillStyle = pal.text;
    ctx.lineWidth = 1;
    ctx.globalAlpha = 0.6;

    for (var ai = 0; ai < sigCount; ai++) {
      var si = activeSigs[ai];
      var sigX = sigSpacing * (ai + 1);
      var lineW = 180;
      var sigLineY = tpl.sigY + 30;

      // Signature line
      ctx.beginPath();
      ctx.moveTo(sigX - lineW / 2, sigLineY);
      ctx.lineTo(sigX + lineW / 2, sigLineY);
      ctx.stroke();

      // Serif ticks at endpoints (3px vertical)
      ctx.beginPath();
      ctx.moveTo(sigX - lineW / 2, sigLineY - 3);
      ctx.lineTo(sigX - lineW / 2, sigLineY + 3);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(sigX + lineW / 2, sigLineY - 3);
      ctx.lineTo(sigX + lineW / 2, sigLineY + 3);
      ctx.stroke();

      // Name above line
      ctx.globalAlpha = 1.0;
      ctx.font = 'italic ' + Math.round(tpl.body.size * 0.85) + 'px ' + sgState.fonts.signatures;
      ctx.textAlign = 'center';
      var sigName = sgState.signatures[si] ? sgState.signatures[si].name : '';
      if (sigName) {
        ctx.fillText(sigName, sigX, tpl.sigY + 8);
      }

      // Role below line
      ctx.globalAlpha = 0.65;
      ctx.font = '' + Math.round(tpl.body.size * 0.7) + 'px ' + sgState.fonts.signatures;
      var sigRole = sgState.signatures[si] ? sgState.signatures[si].role : '';
      if (sigRole) {
        ctx.fillText(sigRole, sigX, tpl.sigY + 48);
      }
      ctx.globalAlpha = 0.6;
    }

    ctx.globalAlpha = 1.0;
  }

  // ============================================================
  //  Section toggle
  // ============================================================
  window.sgToggleSection = function(id) {
    var sec = document.getElementById(id);
    if (sec) {
      sec.classList.toggle('sc-collapsed');
      sgSaveCollapseState();
    }
  };

  // ============================================================
  //  Update body text & badge
  // ============================================================
  function sgUpdateBodyBadge() {
    var badge = document.getElementById('sc-body-badge');
    if (!badge) return;
    if (sgState.bodyMode === 'auto') {
      badge.className = 'sc-badge sc-badge-auto';
      badge.innerHTML = '<i class="fas fa-magic" style="font-size:9px;margin-right:3px"></i>Auto';
    } else {
      badge.className = 'sc-badge sc-badge-manual';
      badge.innerHTML = '<i class="fas fa-pen" style="font-size:9px;margin-right:3px"></i>Manual';
    }
  }

  function sgSetAutoBody() {
    var text = sgGenerateBodyText();
    sgState.bodyText = text;
    var el = document.getElementById('sc-body-text');
    if (el) el.value = text;
    sgState.bodyMode = 'auto';
    sgUpdateBodyBadge();
  }

  // ============================================================
  //  Update signature visibility based on template
  // ============================================================
  // Track whether user has manually toggled sig2
  var sgSig2Visible = true;  // default: visible

  function sgUpdateSigVisibility() {
    var tpl = TEMPLATES[sgState.template] || TEMPLATES.B;
    var sig2 = document.getElementById('sc-sig-2');
    var sig3 = document.getElementById('sc-sig-3');

    // Sig2: user-controlled toggle
    if (sig2) {
      if (sgSig2Visible) {
        sig2.classList.remove('sc-sig-hidden');
        sig2.classList.add('sc-sig-visible');
      } else {
        sig2.classList.remove('sc-sig-visible');
        sig2.classList.add('sc-sig-hidden');
      }
    }

    // Sig3: template-driven (peerage gets 3 sigs)
    if (sig3) {
      if (tpl.sigCount >= 3) {
        sig3.classList.remove('sc-sig-hidden');
        sig3.classList.add('sc-sig-visible');
      } else {
        sig3.classList.remove('sc-sig-visible');
        sig3.classList.add('sc-sig-hidden');
      }
    }

    // Update toggle button label
    sgUpdateSigToggleBtn();
  }

  function sgUpdateSigToggleBtn() {
    var icon = document.getElementById('sc-sig-toggle-icon');
    var label = document.getElementById('sc-sig-toggle-label');
    if (!icon || !label) return;
    if (sgSig2Visible) {
      icon.className = 'fas fa-minus';
      label.textContent = 'Remove Second Signature';
    } else {
      icon.className = 'fas fa-plus';
      label.textContent = 'Add Second Signature';
    }
  }

  window.sgToggleSig2 = function() {
    sgSig2Visible = !sgSig2Visible;
    sgUpdateSigVisibility();
    sgRender();
  };

  // ============================================================
  //  Template card selection
  // ============================================================
  function sgSelectTemplate(key) {
    sgState.template = key;
    var cards = document.querySelectorAll('.sc-template-card');
    for (var i = 0; i < cards.length; i++) {
      cards[i].classList.remove('sc-active');
      if (cards[i].getAttribute('data-template') === key) {
        cards[i].classList.add('sc-active');
      }
    }
    sgUpdateSigVisibility();
    if (sgState.bodyMode === 'auto') sgSetAutoBody();
    sgRender();
  }

  // ============================================================
  //  Palette selection
  // ============================================================
  function sgSelectPalette(key) {
    sgState.palette = key;
    var swatches = document.querySelectorAll('.sc-palette-swatch');
    for (var i = 0; i < swatches.length; i++) {
      swatches[i].classList.remove('sc-active');
      if (swatches[i].getAttribute('data-palette') === key) {
        swatches[i].classList.add('sc-active');
      }
    }
    sgSyncCelticOptsFromPalette();
    sgRenderBorderPreviews();
    sgRender();
  }

  // ============================================================
  //  Download handler — POST to server for 300 DPI output,
  //  fall back to client-side canvas export if server fails
  // ============================================================
  function sgTriggerDownload(blob, filename) {
    var url = URL.createObjectURL(blob);
    var a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    setTimeout(function() { URL.revokeObjectURL(url); }, 5000);
  }

  function sgDownloadFilename() {
    var safeName = (sgState.recipientDisplay || sgState.recipient || 'scroll').replace(/[^a-zA-Z0-9]/g, '_');
    var safeAward = (sgState.awardName || 'award').replace(/[^a-zA-Z0-9]/g, '_');
    return 'scroll_' + safeName + '_' + safeAward + '.png';
  }

  function sgDownloadCanvas() {
    var canvas = document.getElementById('sc-canvas');
    if (!canvas) return;
    canvas.toBlob(function(blob) {
      sgTriggerDownload(blob, sgDownloadFilename());
    }, 'image/png');
  }

    // ============================================================
  //  Validation helper
  // ============================================================
  function sgValidate() {
    var valid = true;
    var invalids = document.querySelectorAll('.sc-invalid');
    for (var i = 0; i < invalids.length; i++) invalids[i].classList.remove('sc-invalid');
    var errors = document.querySelectorAll('.sc-field-error');
    for (var i = 0; i < errors.length; i++) errors[i].classList.remove('sc-visible');

    var recipientEl = document.getElementById('sc-recipient');
    var recipientDisplay = document.getElementById('sc-recipient-display');
    var recipientVal = (recipientDisplay && recipientDisplay.value.trim()) || (recipientEl && recipientEl.value.trim()) || '';
    if (!recipientVal) {
      if (recipientEl) recipientEl.classList.add('sc-invalid');
      var errR = document.getElementById('sc-err-recipient');
      if (errR) errR.classList.add('sc-visible');
      valid = false;
    }

    var awardEl = document.getElementById('sc-award-name');
    var awardVal = awardEl ? awardEl.value.trim() : '';
    if (!awardVal) {
      if (awardEl) awardEl.classList.add('sc-invalid');
      var errA = document.getElementById('sc-err-award');
      if (errA) errA.classList.add('sc-visible');
      valid = false;
    }

    if (!valid) {
      sgToast('Please fill in the required fields', 'warn');
      var detailsSec = document.getElementById('sc-sec-details');
      if (detailsSec && detailsSec.classList.contains('sc-collapsed')) {
        detailsSec.classList.remove('sc-collapsed');
        sgSaveCollapseState();
      }
    }
    return valid;
  }

  function sgDownload() {
    if (!sgValidate()) return;

    var btn = document.getElementById('sc-download-btn');
    var btn2 = document.getElementById('sc-download-btn-2');
    if (btn) { btn.disabled = true; btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Generating…'; }
    if (btn2) { btn2.disabled = true; }

    var fd = new FormData();
    fd.append('template', sgState.template);
    fd.append('palette', sgState.palette);
    fd.append('borderStyle', sgState.borderStyle);
    fd.append('celtic_strandSize', sgState.celtic.strandSize);
    fd.append('celtic_outlineWidth', sgState.celtic.outlineWidth);
    fd.append('celtic_fillColor', sgState.celtic.fillColor);
    fd.append('celtic_strokeColor', sgState.celtic.strokeColor);
    fd.append('font_title', sgState.fonts.title);
    fd.append('font_recipient', sgState.fonts.recipient);
    fd.append('font_body', sgState.fonts.body);
    fd.append('font_signatures', sgState.fonts.signatures);
    fd.append('recipient', sgState.recipientDisplay || sgState.recipient);
    fd.append('awardName', sgState.awardName);
    fd.append('rank', sgState.rank);
    fd.append('date', sgState.date);
    fd.append('givenBy', sgState.givenByDisplay || sgState.givenBy);
    fd.append('park', sgState.park);
    fd.append('kingdom', sgState.kingdom);
    fd.append('bodyText', sgState.bodyText || sgGenerateBodyText());
    fd.append('sig1_name', sgState.signatures[0] ? sgState.signatures[0].name : '');
    fd.append('sig1_role', sgState.signatures[0] ? sgState.signatures[0].role : '');
    fd.append('sig2_visible', sgSig2Visible ? '1' : '0');
    fd.append('sig2_name', sgSig2Visible && sgState.signatures[1] ? sgState.signatures[1].name : '');
    fd.append('sig2_role', sgSig2Visible && sgState.signatures[1] ? sgState.signatures[1].role : '');
    fd.append('sig3_name', sgState.signatures[2] ? sgState.signatures[2].name : '');
    fd.append('sig3_role', sgState.signatures[2] ? sgState.signatures[2].role : '');
    fd.append('heraldry_kingdom', sgState.heraldry.kingdom ? (sgState.heraldryUrls.kingdom || SgConfig.kingdomHeraldry) : '');
    fd.append('heraldry_park', sgState.heraldry.park ? (sgState.heraldryUrls.park || SgConfig.parkHeraldry) : '');
    fd.append('heraldry_player', sgState.heraldry.player ? (sgState.heraldryUrls.player || SgConfig.playerHeraldry) : '');

    // Artwork slot IDs
    var artworkSlotKeys = ['full_border','border_left','border_right','border_top','border_bottom','center_image','watermark','top_graphic'];
    for (var _ai = 0; _ai < artworkSlotKeys.length; _ai++) {
      var _akey = artworkSlotKeys[_ai];
      fd.append('artwork_' + _akey, sgState.artwork[_akey] ? sgState.artwork[_akey].id : '');
    }

    fetch(SgConfig.uir + 'ScrollAjax/generate', { method: 'POST', body: fd })
      .then(function(response) {
        if (!response.ok) throw new Error('Server returned ' + response.status);
        return response.blob();
      })
      .then(function(blob) {
        sgTriggerDownload(blob, sgDownloadFilename());
      })
      .catch(function(err) {
        console.warn('Server-side scroll generation failed, using canvas fallback:', err);
        sgToast('Server generation unavailable — downloading preview resolution instead', 'warn');
        sgDownloadCanvas();
      })
      .finally(function() {
        if (btn) { btn.disabled = false; btn.innerHTML = '<i class="fas fa-download"></i> Download Scroll as PNG'; }
        if (btn2) { btn2.disabled = false; }
      });
  }

  // ============================================================
  //  Read all field values into state
  // ============================================================
  function sgReadFields() {
    sgState.recipient = (document.getElementById('sc-recipient-display') || {}).value || (document.getElementById('sc-recipient') || {}).value || '';
    sgState.recipientDisplay = (document.getElementById('sc-recipient-display') || {}).value || '';
    sgState.awardName = (document.getElementById('sc-award-name') || {}).value || '';
    sgState.rank      = parseInt((document.getElementById('sc-rank') || {}).value || '0', 10);
    sgState.date      = (document.getElementById('sc-date') || {}).value || '';
    sgState.givenBy   = (document.getElementById('sc-given-by-display') || {}).value || (document.getElementById('sc-given-by') || {}).value || '';
    sgState.givenByDisplay = (document.getElementById('sc-given-by-display') || {}).value || '';
    sgState.park      = (document.getElementById('sc-park') || {}).value || '';
    sgState.kingdom   = (document.getElementById('sc-kingdom') || {}).value || '';
    // Font state is managed by font pickers, not read from a single field

    // Heraldry toggles
    sgState.heraldry.kingdom = !!(document.getElementById('sc-herald-kingdom') || {}).checked;
    sgState.heraldry.park    = !!(document.getElementById('sc-herald-park') || {}).checked;
    sgState.heraldry.player  = !!(document.getElementById('sc-herald-player') || {}).checked;

    // Signatures
    for (var s = 0; s < 3; s++) {
      var nameEl = document.getElementById('sc-sig' + (s + 1) + '-name');
      var roleEl = document.getElementById('sc-sig' + (s + 1) + '-role');
      sgState.signatures[s] = {
        name: nameEl ? nameEl.value : '',
        role: roleEl ? roleEl.value : ''
      };
    }
  }

  // ============================================================
  //  Celtic knot options
  // ============================================================
  function sgToggleCelticOpts(show) {
    var panel = document.getElementById('sc-celtic-opts');
    if (panel) {
      if (show) panel.classList.add('sc-visible');
      else panel.classList.remove('sc-visible');
    }
  }

  function sgSyncCelticOptsFromPalette() {
    var pal = PALETTES[sgState.palette] || PALETTES.classic;
    sgState.celtic.fillColor = pal.accent;
    sgState.celtic.strokeColor = pal.border;
    var fillEl = document.getElementById('sc-celtic-fill');
    var strokeEl = document.getElementById('sc-celtic-stroke');
    if (fillEl) fillEl.value = pal.accent;
    if (strokeEl) strokeEl.value = pal.border;
  }

  function sgBindCelticOpts() {
    var strandEl  = document.getElementById('sc-celtic-strand');
    var outlineEl = document.getElementById('sc-celtic-outline');
    var fillEl    = document.getElementById('sc-celtic-fill');
    var strokeEl  = document.getElementById('sc-celtic-stroke');
    var strandVal  = document.getElementById('sc-celtic-strand-val');
    var outlineVal = document.getElementById('sc-celtic-outline-val');

    if (strandEl) strandEl.addEventListener('input', function() {
      sgState.celtic.strandSize = parseFloat(this.value);
      if (strandVal) strandVal.textContent = this.value;
      sgRender();
    });
    if (outlineEl) outlineEl.addEventListener('input', function() {
      sgState.celtic.outlineWidth = parseFloat(this.value);
      if (outlineVal) outlineVal.textContent = this.value;
      sgRender();
    });
    if (fillEl) fillEl.addEventListener('input', function() {
      sgState.celtic.fillColor = this.value;
      sgRender();
    });
    if (strokeEl) strokeEl.addEventListener('input', function() {
      sgState.celtic.strokeColor = this.value;
      sgRender();
    });
  }

  // ============================================================
  //  Event binding
  // ============================================================
  function sgBindEvents() {
    // Template cards
    var tplCards = document.querySelectorAll('.sc-template-card');
    for (var i = 0; i < tplCards.length; i++) {
      (function(card) {
        card.addEventListener('click', function() {
          sgSelectTemplate(card.getAttribute('data-template'));
        });
      })(tplCards[i]);
    }

    // Palette swatches
    var swatches = document.querySelectorAll('.sc-palette-swatch');
    for (var j = 0; j < swatches.length; j++) {
      (function(swatch) {
        swatch.addEventListener('click', function() {
          sgSelectPalette(swatch.getAttribute('data-palette'));
        });
      })(swatches[j]);
    }

    // All text/number/date inputs: blur -> update state -> re-render
    var fieldIds = [
      'sc-recipient', 'sc-recipient-display', 'sc-award-name', 'sc-rank', 'sc-date',
      'sc-given-by', 'sc-given-by-display', 'sc-park', 'sc-kingdom',
      'sc-sig1-name', 'sc-sig1-role', 'sc-sig2-name', 'sc-sig2-role',
      'sc-sig3-name', 'sc-sig3-role'
    ];
    for (var f = 0; f < fieldIds.length; f++) {
      (function(fid) {
        var el = document.getElementById(fid);
        if (!el) return;
        el.addEventListener('blur', function() {
          sgReadFields();
          if (sgState.bodyMode === 'auto') sgSetAutoBody();
          sgRender();
        });
        // Also render on Enter key
        el.addEventListener('keydown', function(e) {
          if (e.keyCode === 13) {
            e.preventDefault();
            el.blur();
          }
        });
      })(fieldIds[f]);
    }

    // Border style picker
    var borderGrid = document.getElementById('sc-border-grid');
    if (borderGrid) {
      borderGrid.addEventListener('click', function(e) {
        var card = e.target.closest ? e.target.closest('.sc-border-card') : null;
        if (!card) return;
        var style = card.getAttribute('data-border');
        if (!style) return;
        sgState.borderStyle = style;
        var allCards = borderGrid.querySelectorAll('.sc-border-card');
        for (var i = 0; i < allCards.length; i++) allCards[i].classList.remove('sc-active');
        card.classList.add('sc-active');
        sgToggleCelticOpts(style === 'celtic');
        sgRender();
      });
    }

    // Celtic knot option controls
    sgBindCelticOpts();

    // Font pickers — initialize all 4 custom font picker dropdowns
    sgInitFontPickers();


    // Body text textarea: typing switches to manual
    var bodyEl = document.getElementById('sc-body-text');
    if (bodyEl) {
      bodyEl.addEventListener('input', function() {
        sgState.bodyText = bodyEl.value;
        if (sgState.bodyMode !== 'manual') {
          sgState.bodyMode = 'manual';
          sgUpdateBodyBadge();
        }
        sgRender();
      });
    }

    // Regenerate body button
    var regenBtn = document.getElementById('sc-regen-body');
    if (regenBtn) {
      regenBtn.addEventListener('click', function() {
        if (sgState.bodyMode === 'manual') {
          if (!confirm('This will overwrite your custom body text with auto-generated text. Continue?')) return;
        }
        sgReadFields();
        sgState.bodyMode = 'auto';
        sgSetAutoBody();
        sgRender();
      });
    }

    // Heraldry toggles — load image on toggle-on, update preview thumbnail
    var heraldryMap = [
      { id: 'sc-herald-kingdom', key: 'kingdom', padLen: 4, base: SgConfig.heraldryKingdomBase, idKey: 'kingdomId' },
      { id: 'sc-herald-park',    key: 'park',    padLen: 5, base: SgConfig.heraldryParkBase,    idKey: 'parkId' },
      { id: 'sc-herald-player',  key: 'player',  padLen: 6, base: SgConfig.heraldryPlayerBase,  idKey: 'mundaneId' }
    ];
    for (var h = 0; h < heraldryMap.length; h++) {
      (function(cfg) {
        var el = document.getElementById(cfg.id);
        if (!el) return;
        el.addEventListener('change', function() {
          sgState.heraldry[cfg.key] = el.checked;
          if (el.checked) {
            var row = el.closest('.sc-toggle-row');
            if (row) row.classList.add('sc-loading');
            var origCb = sgLoadHeraldryForToggle;
            // Wrap to clear spinner when done
            sgLoadHeraldryForToggle._afterLoad = function() {
              if (row) row.classList.remove('sc-loading');
            };
            sgLoadHeraldryForToggle(cfg);
          } else {
            sgRender();
          }
        });
      })(heraldryMap[h]);
    }

    // Download buttons
    var dl1 = document.getElementById('sc-download-btn');
    var dl2 = document.getElementById('sc-download-btn-2');
    if (dl1) dl1.addEventListener('click', sgDownload);
    if (dl2) dl2.addEventListener('click', sgDownload);

    // Reset button
    var resetBtn = document.getElementById('sc-reset-btn');
    if (resetBtn) {
      resetBtn.addEventListener('click', function() {
        if (!confirm('Reset all fields to their defaults?')) return;
        // Reset state
        sgState.template = SgConfig.autoTemplate || 'B';
        sgState.palette = 'classic';
        sgState.borderStyle = 'classic';
        sgState.celtic = { strandSize: 4, outlineWidth: 1, fillColor: '#8b6914', strokeColor: '#6b5a32' };
        sgToggleCelticOpts(false);
        sgState.fonts = { title: 'MedievalSharp', recipient: 'MedievalSharp', body: 'EB Garamond', signatures: 'EB Garamond' };
        sgState.recipient = SgConfig.persona || '';
        sgState.recipientDisplay = SgConfig.persona || '';
        sgState.awardName = SgConfig.awardName || '';
        sgState.rank = SgConfig.rank || 0;
        sgState.date = SgConfig.date || '';
        sgState.givenBy = SgConfig.givenBy || '';
        sgState.givenByDisplay = SgConfig.givenBy || '';
        sgState.park = SgConfig.parkName || '';
        sgState.kingdom = SgConfig.kingdomName || '';
        sgState.bodyMode = 'auto';
        sgState.heraldry = { kingdom: !!SgConfig.kingdomHeraldry, park: !!SgConfig.parkHeraldry, player: !!SgConfig.playerHeraldry };
        sgState.heraldryUrls = { kingdom: SgConfig.kingdomHeraldry || '', park: SgConfig.parkHeraldry || '', player: SgConfig.playerHeraldry || '' };
        sgState.signatures = [
          { name: SgConfig.givenBy || '', role: 'Monarch' },
          { name: '', role: 'Regent' },
          { name: '', role: '' }
        ];

        // Reset form elements
        var fields = {
          'sc-recipient': SgConfig.persona || '',
          'sc-recipient-display': SgConfig.persona || '',
          'sc-award-name': SgConfig.awardName || '',
          'sc-rank': SgConfig.rank || 0,
          'sc-date': SgConfig.date || new Date().toISOString().slice(0,10),
          'sc-given-by': SgConfig.givenBy || '',
          'sc-given-by-display': SgConfig.givenBy || '',
          'sc-park': SgConfig.parkName || '',
          'sc-kingdom': SgConfig.kingdomName || '',
          'sc-sig1-name': SgConfig.givenBy || '',
          'sc-sig1-role': 'Monarch',
          'sc-sig2-name': '',
          'sc-sig2-role': 'Regent',
          'sc-sig3-name': '',
          'sc-sig3-role': ''
        };
        for (var fid in fields) {
          var el = document.getElementById(fid);
          if (el) el.value = fields[fid];
        }

        // Reset font pickers
        sgUpdateAllFontPickers();


        // Reset heraldry toggles
        var hk = document.getElementById('sc-herald-kingdom');
        var hp = document.getElementById('sc-herald-park');
        var hpl = document.getElementById('sc-herald-player');
        if (hk) hk.checked = sgState.heraldry.kingdom;
        if (hp) hp.checked = sgState.heraldry.park;
        if (hpl) hpl.checked = sgState.heraldry.player;

        // Reset sig2 visibility
        sgSig2Visible = true;

        // Reset border picker
        var borderCards = document.querySelectorAll('.sc-border-card');
        for (var i = 0; i < borderCards.length; i++) {
          borderCards[i].classList.remove('sc-active');
          if (borderCards[i].getAttribute('data-border') === 'classic') borderCards[i].classList.add('sc-active');
        }

        // Reset celtic knot controls
        var ckStrand = document.getElementById('sc-celtic-strand');
        var ckOutline = document.getElementById('sc-celtic-outline');
        var ckFill = document.getElementById('sc-celtic-fill');
        var ckStroke = document.getElementById('sc-celtic-stroke');
        if (ckStrand) { ckStrand.value = 4; document.getElementById('sc-celtic-strand-val').textContent = '4'; }
        if (ckOutline) { ckOutline.value = 1; document.getElementById('sc-celtic-outline-val').textContent = '1'; }
        if (ckFill) ckFill.value = '#8b6914';
        if (ckStroke) ckStroke.value = '#6b5a32';
        _celticCache = null;

        // Reset palette + template
        sgSelectPalette('classic');
        sgSelectTemplate(sgState.template);

        // Clear validation errors
        var invalids = document.querySelectorAll('.sc-invalid');
        for (var i = 0; i < invalids.length; i++) invalids[i].classList.remove('sc-invalid');
        var errors = document.querySelectorAll('.sc-field-error');
        for (var i = 0; i < errors.length; i++) errors[i].classList.remove('sc-visible');

        // Reset artwork slots
        for (var _rk in ARTWORK_SLOTS) {
          sgState.artwork[_rk] = null;
          sgArtworkImages[_rk] = null;
        }
        sgRenderArtworkSlots();

        // Deselect officer chips
        var chips = document.querySelectorAll('.sc-officer-chip');
        for (var i = 0; i < chips.length; i++) chips[i].classList.remove('sc-selected');

        sgSetAutoBody();
        sgRender();
        sgToast('All fields reset to defaults');
      });
    }

    // Clear validation on field input
    var validatedFieldMap = { 'sc-recipient': 'sc-err-recipient', 'sc-award-name': 'sc-err-award' };
    for (var fid in validatedFieldMap) {
      (function(fieldId, errId) {
        var el = document.getElementById(fieldId);
        if (!el) return;
        el.addEventListener('input', function() {
          el.classList.remove('sc-invalid');
          var errEl = document.getElementById(errId);
          if (errEl) errEl.classList.remove('sc-visible');
        });
      })(fid, validatedFieldMap[fid]);
    }
  }

  // ============================================================
  //  Autocomplete helpers
  // ============================================================
  var SEARCH_URL = SgConfig.httpService + 'Search/SearchService.php';
  var SG_DEBOUNCE = 250;

  function sgAcKeyNav(inputEl, resultsEl) {
    inputEl.addEventListener('keydown', function(e) {
      var items = resultsEl.querySelectorAll('.sc-ac-item');
      if (!items.length) return;
      var focused = resultsEl.querySelector('.sc-ac-focused');
      var idx = -1;
      for (var i = 0; i < items.length; i++) { if (items[i] === focused) { idx = i; break; } }
      if (e.keyCode === 40) { // down
        e.preventDefault();
        if (focused) focused.classList.remove('sc-ac-focused');
        idx = (idx + 1) % items.length;
        items[idx].classList.add('sc-ac-focused');
        items[idx].scrollIntoView({ block: 'nearest' });
      } else if (e.keyCode === 38) { // up
        e.preventDefault();
        if (focused) focused.classList.remove('sc-ac-focused');
        idx = idx <= 0 ? items.length - 1 : idx - 1;
        items[idx].classList.add('sc-ac-focused');
        items[idx].scrollIntoView({ block: 'nearest' });
      } else if (e.keyCode === 13) { // enter
        if (focused) { e.preventDefault(); focused.click(); }
      } else if (e.keyCode === 27) { // escape
        resultsEl.classList.remove('sc-ac-open');
      }
    });
  }

  function sgBuildAcItems(data) {
    var html = '';
    for (var i = 0; i < data.length; i++) {
      var d = data[i];
      var persona = d.Persona || d.UserName || '';
      var parkName = d.ParkName || '';
      var kingdomName = d.KingdomName || '';
      var sub = parkName ? parkName + (kingdomName ? ', ' + kingdomName : '') : kingdomName;
      html += '<div class="sc-ac-item" data-id="' + (d.MundaneId || '') + '" data-name="' + encodeURIComponent(persona) + '" data-park="' + encodeURIComponent(parkName) + '" data-kingdom="' + encodeURIComponent(kingdomName) + '" data-parkid="' + (d.ParkId || '0') + '" data-kingdomid="' + (d.KingdomId || '0') + '">';
      html += persona;
      if (sub) html += '<small>' + sub + '</small>';
      html += '</div>';
    }
    return html;
  }

  // ============================================================
  //  Recipient Persona autocomplete
  // ============================================================
  var recipientTimer;
  function sgBindRecipientAc() {
    var input = document.getElementById('sc-recipient');
    var hiddenId = document.getElementById('sc-recipient-id');
    var displayAs = document.getElementById('sc-recipient-display');
    var results = document.getElementById('sc-recipient-results');
    if (!input || !results) return;

    input.addEventListener('input', function() {
      clearTimeout(recipientTimer);
      if (hiddenId) hiddenId.value = '';
      var term = this.value.trim();
      if (term.length < 2) { results.classList.remove('sc-ac-open'); return; }
      recipientTimer = setTimeout(function() {
        var url = SEARCH_URL + '?Action=Search%2FPlayer&type=all&search=' + encodeURIComponent(term) + '&limit=10';
        fetch(url).then(function(r) { return r.json(); }).then(function(data) {
          if (!data || !data.length) {
            results.innerHTML = '<div class="sc-ac-no-results">No players found</div>';
          } else {
            results.innerHTML = sgBuildAcItems(data);
          }
          results.classList.add('sc-ac-open');
        }).catch(function() {});
      }, SG_DEBOUNCE);
    });

    results.addEventListener('click', function(e) {
      var item = e.target.closest ? e.target.closest('.sc-ac-item') : null;
      if (!item) return;
      var persona = decodeURIComponent(item.dataset.name);
      input.value = persona;
      if (hiddenId) hiddenId.value = item.dataset.id;
      if (displayAs) displayAs.value = persona;
      results.classList.remove('sc-ac-open');
      sgOnRecipientSelected(item);
    });

    sgAcKeyNav(input, results);

    // Close on outside click
    document.addEventListener('click', function(e) {
      if (e.target !== input && !results.contains(e.target)) {
        results.classList.remove('sc-ac-open');
      }
    });
  }

  // ============================================================
  //  When a recipient is selected: prepopulate Park, Kingdom,
  //  Given By, heraldry, and officer chips
  // ============================================================
  function sgOnRecipientSelected(item) {
    var parkName = decodeURIComponent(item.dataset.park || '');
    var kingdomName = decodeURIComponent(item.dataset.kingdom || '');
    var parkId = item.dataset.parkid || '0';
    var kingdomId = item.dataset.kingdomid || '0';
    var mundaneId = item.dataset.id || '0';

    // Update Park & Kingdom fields
    var parkEl = document.getElementById('sc-park');
    var kingdomEl = document.getElementById('sc-kingdom');
    if (parkEl && parkName) parkEl.value = parkName;
    if (kingdomEl && kingdomName) kingdomEl.value = kingdomName;

    // Store IDs for heraldry resolution
    SgConfig.mundaneId = parseInt(mundaneId, 10) || 0;
    SgConfig.parkId    = parseInt(parkId, 10) || 0;
    SgConfig.kingdomId = parseInt(kingdomId, 10) || 0;

    // Auto-load all three heraldry types, enable toggles, update previews
    var heraldryToLoad = [
      { key: 'player',  toggleId: 'sc-herald-player',  base: SgConfig.heraldryPlayerBase,  padLen: 6, entityId: mundaneId },
      { key: 'park',    toggleId: 'sc-herald-park',     base: SgConfig.heraldryParkBase,    padLen: 5, entityId: parkId },
      { key: 'kingdom', toggleId: 'sc-herald-kingdom',  base: SgConfig.heraldryKingdomBase, padLen: 4, entityId: kingdomId }
    ];

    var loadsPending = 0;
    for (var i = 0; i < heraldryToLoad.length; i++) {
      (function(cfg) {
        var url = sgBuildHeraldryUrl(cfg.base, cfg.padLen, cfg.entityId);
        if (!url) return;

        // Enable the toggle and update preview
        sgState.heraldry[cfg.key] = true;
        sgState.heraldryUrls[cfg.key] = url;
        var toggle = document.getElementById(cfg.toggleId);
        if (toggle) toggle.checked = true;
        sgUpdateHeraldryPreview(cfg.toggleId, url);

        // Load the image (try .jpg, fall back to .png)
        loadsPending++;
        sgImages[cfg.key] = null; // clear stale cache
        sgLoadImage(cfg.key, url, function() {
          if (!sgImages[cfg.key] && url.indexOf('.jpg') > -1) {
            var pngUrl = url.replace(/\.jpg$/, '.png');
            sgState.heraldryUrls[cfg.key] = pngUrl;
            sgUpdateHeraldryPreview(cfg.toggleId, pngUrl);
            sgLoadImage(cfg.key, pngUrl, function() {
              loadsPending--;
              if (loadsPending <= 0) sgRender();
            });
          } else {
            loadsPending--;
            if (loadsPending <= 0) sgRender();
          }
        });
      })(heraldryToLoad[i]);
    }

    // Update state and render
    sgReadFields();
    if (sgState.bodyMode === 'auto') sgSetAutoBody();
    if (loadsPending <= 0) sgRender();
  }

  // ============================================================
  //  Fetch officer data for dynamic officer chips
  // ============================================================
  function sgFetchOfficers(parkId, kingdomId) {
    // For now officers are preloaded from PHP. Dynamic fetch would require
    // an AJAX endpoint. Officer chips remain as server-rendered.
  }

  // ============================================================
  //  Given By: officer chip handlers
  // ============================================================
  function sgBindOfficerChips() {
    var chipsContainer = document.getElementById('sc-givenby-officer-chips');
    if (!chipsContainer) return;

    chipsContainer.addEventListener('click', function(e) {
      var chip = e.target.closest ? e.target.closest('.sc-officer-chip') : null;
      if (!chip) return;

      // Deselect all, select this one
      var allChips = chipsContainer.querySelectorAll('.sc-officer-chip');
      for (var i = 0; i < allChips.length; i++) allChips[i].classList.remove('sc-selected');
      chip.classList.add('sc-selected');

      // Set given by fields
      var givenByInput = document.getElementById('sc-given-by');
      var givenById = document.getElementById('sc-given-by-id');
      var givenByDisplay = document.getElementById('sc-given-by-display');
      if (givenByInput) givenByInput.value = chip.dataset.name;
      if (givenById) givenById.value = chip.dataset.id;
      if (givenByDisplay) givenByDisplay.value = chip.dataset.name;

      // Close any open autocomplete
      var results = document.getElementById('sc-givenby-results');
      if (results) results.classList.remove('sc-ac-open');

      // Update state and render
      sgReadFields();
      if (sgState.bodyMode === 'auto') sgSetAutoBody();
      sgRender();
    });
  }

  // ============================================================
  //  Given By autocomplete
  // ============================================================
  var givenByTimer;
  function sgBindGivenByAc() {
    var input = document.getElementById('sc-given-by');
    var hiddenId = document.getElementById('sc-given-by-id');
    var displayAs = document.getElementById('sc-given-by-display');
    var results = document.getElementById('sc-givenby-results');
    if (!input || !results) return;

    input.addEventListener('input', function() {
      clearTimeout(givenByTimer);
      if (hiddenId) hiddenId.value = '';
      // Deselect officer chips
      var chips = document.querySelectorAll('#sc-givenby-officer-chips .sc-officer-chip');
      for (var i = 0; i < chips.length; i++) chips[i].classList.remove('sc-selected');

      var term = this.value.trim();
      if (term.length < 2) { results.classList.remove('sc-ac-open'); return; }
      givenByTimer = setTimeout(function() {
        var url = SEARCH_URL + '?Action=Search%2FPlayer&type=all&search=' + encodeURIComponent(term) + '&kingdom_id=' + (SgConfig.kingdomId || '') + '&limit=6';
        fetch(url).then(function(r) { return r.json(); }).then(function(data) {
          if (!data || !data.length) {
            results.innerHTML = '<div class="sc-ac-no-results">No players found</div>';
          } else {
            results.innerHTML = sgBuildAcItems(data);
          }
          results.classList.add('sc-ac-open');
        }).catch(function() {});
      }, SG_DEBOUNCE);
    });

    results.addEventListener('click', function(e) {
      var item = e.target.closest ? e.target.closest('.sc-ac-item') : null;
      if (!item) return;
      var persona = decodeURIComponent(item.dataset.name);
      input.value = persona;
      if (hiddenId) hiddenId.value = item.dataset.id;
      if (displayAs) displayAs.value = persona;
      results.classList.remove('sc-ac-open');
      // Deselect officer chips
      var chips = document.querySelectorAll('#sc-givenby-officer-chips .sc-officer-chip');
      for (var i = 0; i < chips.length; i++) chips[i].classList.remove('sc-selected');
      sgReadFields();
      if (sgState.bodyMode === 'auto') sgSetAutoBody();
      sgRender();
    });

    sgAcKeyNav(input, results);

    // Close on outside click
    document.addEventListener('click', function(e) {
      if (e.target !== input && !results.contains(e.target)) {
        results.classList.remove('sc-ac-open');
      }
    });
  }

  // ============================================================
  //  Font picker: build dropdown HTML, bind open/close/select
  // ============================================================
  function sgBuildFontDropdownHtml(selectedValue) {
    var html = '';
    for (var gi = 0; gi < SC_FONTS.length; gi++) {
      var grp = SC_FONTS[gi];
      html += '<div class="sc-fp-group-label">' + grp.group + '</div>';
      for (var fi = 0; fi < grp.fonts.length; fi++) {
        var f = grp.fonts[fi];
        var sel = (f.value === selectedValue) ? ' sc-fp-selected' : '';
        html += '<div class="sc-fp-item' + sel + '" data-value="' + f.value + '">';
        html += '<span class="sc-fp-item-name">' + f.value + '</span>';
        html += '<span class="sc-fp-item-sample" style="font-family:' + f.family + '">' + f.value + ' \u2014 ' + SC_FONT_SAMPLE + '</span>';
        html += '</div>';
      }
    }
    return html;
  }

  function sgUpdatePickerBtn(target) {
    var fontVal = sgState.fonts[target];
    var family = SC_FONT_FAMILY[fontVal] || "'MedievalSharp', cursive";
    var picker = document.querySelector('.sc-font-picker[data-target="' + target + '"]');
    if (!picker) return;
    var nameEl = picker.querySelector('.sc-font-picker-fname');
    var sampleEl = picker.querySelector('.sc-font-picker-sample');
    if (nameEl) nameEl.textContent = fontVal;
    if (sampleEl) {
      sampleEl.textContent = SC_FONT_SAMPLE;
      sampleEl.style.fontFamily = family;
    }
  }

  function sgUpdateAllFontPickers() {
    var targets = ['title', 'recipient', 'body', 'signatures'];
    for (var i = 0; i < targets.length; i++) {
      sgUpdatePickerBtn(targets[i]);
    }
  }

  function sgInitFontPickers() {
    var pickers = document.querySelectorAll('.sc-font-picker');
    for (var i = 0; i < pickers.length; i++) {
      (function(picker) {
        var target = picker.dataset.target;
        var btn = picker.querySelector('.sc-font-picker-btn');
        var dropdown = picker.querySelector('.sc-font-picker-dropdown');
        if (!btn || !dropdown || !target) return;

        // Populate dropdown
        dropdown.innerHTML = sgBuildFontDropdownHtml(sgState.fonts[target]);

        // Toggle open/close on button click
        btn.addEventListener('click', function(e) {
          e.stopPropagation();
          var isOpen = btn.classList.contains('sc-fp-open');
          // Close all other open pickers first
          sgCloseAllFontPickers();
          if (!isOpen) {
            btn.classList.add('sc-fp-open');
            dropdown.classList.add('sc-fp-open');
            // Refresh dropdown selected state
            dropdown.innerHTML = sgBuildFontDropdownHtml(sgState.fonts[target]);
            // Scroll selected item into view
            var selItem = dropdown.querySelector('.sc-fp-selected');
            if (selItem) selItem.scrollIntoView({ block: 'nearest' });
          }
        });

        // Select font on item click
        dropdown.addEventListener('click', function(e) {
          var item = e.target.closest ? e.target.closest('.sc-fp-item') : null;
          if (!item) return;
          var val = item.dataset.value;
          sgState.fonts[target] = val;
          sgUpdatePickerBtn(target);
          sgCloseAllFontPickers();
          sgRender();
        });
      })(pickers[i]);
    }

    // Close all pickers on outside click
    document.addEventListener('click', function() {
      sgCloseAllFontPickers();
    });

    // Prevent dropdown clicks from bubbling to document
    var dropdowns = document.querySelectorAll('.sc-font-picker-dropdown');
    for (var d = 0; d < dropdowns.length; d++) {
      dropdowns[d].addEventListener('click', function(e) {
        e.stopPropagation();
      });
    }
  }

  function sgCloseAllFontPickers() {
    var btns = document.querySelectorAll('.sc-font-picker-btn.sc-fp-open');
    for (var i = 0; i < btns.length; i++) btns[i].classList.remove('sc-fp-open');
    var dds = document.querySelectorAll('.sc-font-picker-dropdown.sc-fp-open');
    for (var i = 0; i < dds.length; i++) dds[i].classList.remove('sc-fp-open');
  }

  // ============================================================
  //  Artwork: Render slot cards in the section
  // ============================================================
  function sgRenderArtworkSlots() {
    var container = document.getElementById('sc-artwork-slots');
    if (!container) return;
    var html = '';
    var slotOrder = ['watermark', 'full_border', 'border_left', 'border_right', 'border_top', 'border_bottom', 'center_image', 'top_graphic'];
    for (var i = 0; i < slotOrder.length; i++) {
      var key = slotOrder[i];
      var slot = ARTWORK_SLOTS[key];
      var artwork = sgState.artwork[key];
      var hasArt = artwork && artwork.url;
      html += '<div class="sc-artwork-slot' + (hasArt ? ' sc-has-artwork' : '') + '" data-slot="' + key + '">';
      html += '<div class="sc-artwork-slot-thumb">';
      if (hasArt) {
        html += '<img src="' + artwork.url + '" alt="' + slot.label + '">';
      } else {
        html += '<i class="fas fa-image"></i>';
      }
      html += '</div>';
      html += '<div class="sc-artwork-slot-info">';
      html += '<span class="sc-artwork-slot-label">' + slot.label + '</span>';
      html += '<span class="sc-artwork-slot-dims">' + slot.w + ' \u00d7 ' + slot.h + 'px</span>';
      html += '</div>';
      html += '<div class="sc-artwork-slot-actions">';
      html += '<button type="button" class="sc-artwork-slot-btn" onclick="sgArtworkOpenBrowse(\'' + key + '\')"><i class="fas fa-search"></i></button>';
      html += '<button type="button" class="sc-artwork-slot-btn sc-btn-clear" onclick="sgArtworkClearSlot(\'' + key + '\')" title="Remove artwork"><i class="fas fa-times"></i></button>';
      html += '</div></div>';
    }
    container.innerHTML = html;
  }

  // ============================================================
  //  Artwork: Browse modal
  // ============================================================
  var _artworkBrowseSlot = '';
  var _artworkBrowsePage = 1;
  var _artworkBrowseQuery = '';

  window.sgArtworkOpenBrowse = function(slotKey) {
    _artworkBrowseSlot = slotKey;
    _artworkBrowsePage = 1;
    _artworkBrowseQuery = '';
    var slot = ARTWORK_SLOTS[slotKey];
    var titleEl = document.getElementById('sc-artwork-browse-title');
    var subtitleEl = document.getElementById('sc-artwork-browse-subtitle');
    if (titleEl) titleEl.textContent = 'Browse: ' + (slot ? slot.label : slotKey);
    if (subtitleEl) subtitleEl.textContent = (slot ? slot.desc + ' — ' + slot.w + ' \u00d7 ' + slot.h + 'px recommended' : '');
    var searchInput = document.getElementById('sc-artwork-search-input');
    if (searchInput) searchInput.value = '';
    var uploadSlot = document.getElementById('sc-artwork-upload-slot');
    if (uploadSlot) uploadSlot.value = (slot ? slot.label : slotKey);

    // Reset to browse tab
    sgArtworkSwitchTab(null, 'browse');

    // Reset upload form fields
    sgArtworkResetUploadForm();

    var modal = document.getElementById('sc-artwork-browse-modal');
    if (modal) modal.classList.add('sc-modal-open');
    sgArtworkLoadBrowse();
  };

  window.sgArtworkCloseBrowse = function() {
    var modal = document.getElementById('sc-artwork-browse-modal');
    if (modal) modal.classList.remove('sc-modal-open');
  };

  window.sgArtworkSwitchTab = function(btn, tabId) {
    var tabs = document.querySelectorAll('#sc-artwork-browse-modal .sc-artwork-tab');
    for (var i = 0; i < tabs.length; i++) {
      tabs[i].classList.remove('sc-active');
      if (tabs[i].getAttribute('data-tab') === tabId) tabs[i].classList.add('sc-active');
    }
    var contents = document.querySelectorAll('#sc-artwork-browse-modal .sc-artwork-tab-content');
    for (var j = 0; j < contents.length; j++) {
      contents[j].classList.remove('sc-active');
    }
    var target = document.getElementById('sc-artwork-tab-' + tabId);
    if (target) target.classList.add('sc-active');
  };

  function sgArtworkLoadBrowse() {
    var grid = document.getElementById('sc-artwork-browse-grid');
    if (grid) grid.innerHTML = '<div class="sc-artwork-loading"><i class="fas fa-spinner fa-spin"></i> Loading...</div>';
    var url = SgConfig.uir + 'ScrollArtworkAjax/';
    if (_artworkBrowseQuery) {
      url += 'search?query=' + encodeURIComponent(_artworkBrowseQuery) + '&layout_location=' + encodeURIComponent(_artworkBrowseSlot) + '&page=' + _artworkBrowsePage;
    } else {
      url += 'browse?layout_location=' + encodeURIComponent(_artworkBrowseSlot) + '&page=' + _artworkBrowsePage;
    }
    fetch(url)
      .then(function(r) { return r.json(); })
      .then(function(data) {
        sgArtworkRenderBrowseGrid(data);
      })
      .catch(function(err) {
        if (grid) grid.innerHTML = '<div class="sc-artwork-empty-state"><i class="fas fa-exclamation-triangle"></i>Failed to load artwork</div>';
      });
  }

  function sgArtworkRenderBrowseGrid(data) {
    var grid = document.getElementById('sc-artwork-browse-grid');
    if (!grid) return;
    var items = data.Artwork || [];
    if (items.length === 0) {
      grid.innerHTML = '<div class="sc-artwork-empty-state"><i class="fas fa-palette"></i>No artwork found' + (_artworkBrowseQuery ? ' for "' + sgEscapeHtml(_artworkBrowseQuery) + '"' : '') + '. Try uploading some!</div>';
    } else {
      var html = '';
      var currentId = sgState.artwork[_artworkBrowseSlot] ? sgState.artwork[_artworkBrowseSlot].id : 0;
      for (var i = 0; i < items.length; i++) {
        var item = items[i];
        var isSelected = (parseInt(item.ArtworkId) === currentId);
        html += '<div class="sc-artwork-thumb' + (isSelected ? ' sc-selected' : '') + '" data-id="' + item.ArtworkId + '" data-url="' + sgEscapeHtml(item.Url || '') + '" onclick="sgArtworkSelectFromBrowse(this)">';
        html += '<img class="sc-artwork-thumb-img" src="' + sgEscapeHtml(item.Url || '') + '" alt="' + sgEscapeHtml(item.Name || '') + '" loading="lazy">';
        html += '<div class="sc-artwork-thumb-info">';
        html += '<span class="sc-artwork-thumb-name">' + sgEscapeHtml(item.Name || 'Untitled') + '</span>';
        html += '<span class="sc-artwork-thumb-artist">' + sgEscapeHtml(item.UploaderPersona || 'Unknown') + '</span>';
        html += '</div></div>';
      }
      grid.innerHTML = html;
    }
    // Pagination
    var pagEl = document.getElementById('sc-artwork-browse-pagination');
    var pageInfo = document.getElementById('sc-artwork-browse-page-info');
    var total = parseInt(data.Total || 0);
    var perPage = parseInt(data.PerPage || 12);
    var page = parseInt(data.Page || 1);
    var totalPages = Math.max(1, Math.ceil(total / perPage));
    if (total > perPage && pagEl) {
      pagEl.style.display = 'flex';
      if (pageInfo) pageInfo.textContent = 'Page ' + page + ' of ' + totalPages;
      var btns = pagEl.querySelectorAll('button');
      if (btns[0]) btns[0].disabled = (page <= 1);
      if (btns[1]) btns[1].disabled = (page >= totalPages);
    } else if (pagEl) {
      pagEl.style.display = 'none';
    }
  }

  window.sgArtworkSelectFromBrowse = function(el) {
    var id = parseInt(el.getAttribute('data-id'));
    var url = el.getAttribute('data-url');
    if (!id || !url) return;
    sgState.artwork[_artworkBrowseSlot] = { id: id, url: url };
    sgLoadArtworkImage(_artworkBrowseSlot, url, function() {
      sgRender();
    });
    sgRenderArtworkSlots();
    sgArtworkCloseBrowse();
    sgToast('Artwork selected for ' + (ARTWORK_SLOTS[_artworkBrowseSlot] ? ARTWORK_SLOTS[_artworkBrowseSlot].label : _artworkBrowseSlot));
  };

  window.sgArtworkSearch = function() {
    var input = document.getElementById('sc-artwork-search-input');
    _artworkBrowseQuery = input ? input.value.trim() : '';
    _artworkBrowsePage = 1;
    sgArtworkLoadBrowse();
  };

  window.sgArtworkBrowsePrev = function() {
    if (_artworkBrowsePage > 1) { _artworkBrowsePage--; sgArtworkLoadBrowse(); }
  };
  window.sgArtworkBrowseNext = function() {
    _artworkBrowsePage++;
    sgArtworkLoadBrowse();
  };

  window.sgArtworkClearSlot = function(slotKey) {
    sgState.artwork[slotKey] = null;
    sgArtworkImages[slotKey] = null;
    sgRenderArtworkSlots();
    sgRender();
  };

  // ============================================================
  //  Artwork: Upload
  // ============================================================
  function sgArtworkResetUploadForm() {
    var fields = ['sc-artwork-file', 'sc-artwork-upload-name', 'sc-artwork-upload-desc', 'sc-artwork-upload-tags', 'sc-artwork-signer'];
    for (var i = 0; i < fields.length; i++) {
      var el = document.getElementById(fields[i]);
      if (el) el.value = '';
    }
    var agree = document.getElementById('sc-artwork-agree');
    if (agree) agree.checked = false;
    var fileInfo = document.getElementById('sc-artwork-file-info');
    if (fileInfo) fileInfo.textContent = 'PNG or JPEG. See template guide for recommended dimensions.';
  }

  window.sgArtworkUpload = function() {
    var fileEl = document.getElementById('sc-artwork-file');
    var nameEl = document.getElementById('sc-artwork-upload-name');
    var descEl = document.getElementById('sc-artwork-upload-desc');
    var tagsEl = document.getElementById('sc-artwork-upload-tags');
    var signerEl = document.getElementById('sc-artwork-signer');
    var agreeEl = document.getElementById('sc-artwork-agree');
    var btn = document.getElementById('sc-artwork-upload-btn');

    var file = fileEl && fileEl.files[0];
    var name = nameEl ? nameEl.value.trim() : '';
    var signer = signerEl ? signerEl.value.trim() : '';
    var agreed = agreeEl ? agreeEl.checked : false;

    if (!file) { sgToast('Please select an image file', 'warn'); return; }
    if (file.size > 2097152) { sgToast('Image must be 2MB or smaller (' + Math.round(file.size / 1024) + 'KB selected)', 'warn'); return; }
    if (!name) { sgToast('Please enter a name for the artwork', 'warn'); return; }
    if (!signer) { sgToast('Please type your full legal name', 'warn'); return; }
    if (!agreed) { sgToast('Please agree to the license terms', 'warn'); return; }
    if (!SgConfig.token) { sgToast('You must be logged in to upload artwork', 'warn'); return; }

    if (btn) { btn.disabled = true; btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Uploading...'; }

    var reader = new FileReader();
    reader.onload = function() {
      var base64 = reader.result.split(',')[1] || '';
      var mimeType = file.type || 'image/png';

      var fd = new FormData();
      fd.append('image', base64);
      fd.append('image_mime', mimeType);
      fd.append('name', name);
      fd.append('description', descEl ? descEl.value.trim() : '');
      fd.append('tags', tagsEl ? tagsEl.value.trim() : '');
      fd.append('layout_location', _artworkBrowseSlot);
      fd.append('license_signer_name', signer);

      fetch(SgConfig.uir + 'ScrollArtworkAjax/upload', { method: 'POST', body: fd })
        .then(function(r) { return r.json(); })
        .then(function(data) {
          if (data.Status === 0) {
            sgToast('Artwork uploaded! It will be available after admin approval.');
            sgArtworkResetUploadForm();
            sgArtworkSwitchTab(null, 'browse');
          } else {
            sgToast(data.Message || 'Upload failed', 'warn');
          }
        })
        .catch(function(err) {
          sgToast('Upload failed: ' + err.message, 'warn');
        })
        .finally(function() {
          if (btn) { btn.disabled = false; btn.innerHTML = '<i class="fas fa-upload"></i> Upload Artwork'; }
        });
    };
    reader.readAsDataURL(file);
  };

  // Enter key in search bar triggers search
  (function() {
    // Deferred binding — called after DOM ready
    function bindArtworkSearchEnter() {
      var searchInput = document.getElementById('sc-artwork-search-input');
      if (searchInput) {
        searchInput.addEventListener('keydown', function(e) {
          if (e.keyCode === 13) { e.preventDefault(); sgArtworkSearch(); }
        });
      }
    }
    // Will be called from sgInit
    window._sgBindArtworkSearchEnter = bindArtworkSearchEnter;
  })();

  // ============================================================
  //  Artwork: Template Guide download
  // ============================================================
  window.sgArtworkDownloadGuide = function() {
    window.open(SgConfig.uir + 'ScrollArtworkAjax/template_guide', '_blank');
  };

  // ============================================================
  //  Artwork: My Uploads modal
  // ============================================================
  var _artworkMyUploadsPage = 1;

  window.sgArtworkOpenMyUploads = function() {
    _artworkMyUploadsPage = 1;
    var modal = document.getElementById('sc-artwork-myuploads-modal');
    if (modal) modal.classList.add('sc-modal-open');
    sgArtworkLoadMyUploads();
  };

  window.sgArtworkCloseMyUploads = function() {
    var modal = document.getElementById('sc-artwork-myuploads-modal');
    if (modal) modal.classList.remove('sc-modal-open');
  };

  function sgArtworkLoadMyUploads() {
    var list = document.getElementById('sc-artwork-myuploads-list');
    if (list) list.innerHTML = '<div class="sc-artwork-loading"><i class="fas fa-spinner fa-spin"></i> Loading...</div>';
    fetch(SgConfig.uir + 'ScrollArtworkAjax/my_uploads?page=' + _artworkMyUploadsPage)
      .then(function(r) { return r.json(); })
      .then(function(data) {
        sgArtworkRenderMyUploads(data);
      })
      .catch(function(err) {
        if (list) list.innerHTML = '<div class="sc-artwork-empty-state"><i class="fas fa-exclamation-triangle"></i>Failed to load uploads</div>';
      });
  }

  function sgArtworkRenderMyUploads(data) {
    var list = document.getElementById('sc-artwork-myuploads-list');
    if (!list) return;
    var items = data.Artwork || [];
    if (items.length === 0) {
      list.innerHTML = '<div class="sc-artwork-empty-state"><i class="fas fa-images"></i>You have not uploaded any artwork yet.</div>';
    } else {
      var html = '';
      for (var i = 0; i < items.length; i++) {
        var item = items[i];
        var statusClass = 'sc-status-' + (item.Status || 'pending').toLowerCase();
        var statusText = (item.Status || 'Pending');
        html += '<div class="sc-artwork-my-item" data-id="' + item.ArtworkId + '">';
        html += '<div class="sc-artwork-my-thumb"><img src="' + sgEscapeHtml(item.Url || '') + '" alt="' + sgEscapeHtml(item.Name || '') + '" loading="lazy"></div>';
        html += '<div class="sc-artwork-my-info">';
        html += '<div class="sc-artwork-my-name">' + sgEscapeHtml(item.Name || 'Untitled') + ' <span class="sc-artwork-status-badge ' + statusClass + '">' + sgEscapeHtml(statusText) + '</span></div>';
        html += '<div class="sc-artwork-my-meta">' + sgEscapeHtml(item.LayoutLocation || '') + ' — ' + (item.Width || '?') + ' \u00d7 ' + (item.Height || '?') + 'px</div>';
        html += '</div>';
        html += '<button type="button" class="sc-artwork-my-delete" onclick="sgArtworkDelete(' + item.ArtworkId + ', this)"><i class="fas fa-trash"></i></button>';
        html += '</div>';
      }
      list.innerHTML = html;
    }
    // Pagination
    var pagEl = document.getElementById('sc-artwork-myuploads-pagination');
    var pageInfo = document.getElementById('sc-artwork-myuploads-page-info');
    var total = parseInt(data.Total || 0);
    var perPage = parseInt(data.PerPage || 20);
    var page = parseInt(data.Page || 1);
    var totalPages = Math.max(1, Math.ceil(total / perPage));
    if (total > perPage && pagEl) {
      pagEl.style.display = 'flex';
      if (pageInfo) pageInfo.textContent = 'Page ' + page + ' of ' + totalPages;
      var btns = pagEl.querySelectorAll('button');
      if (btns[0]) btns[0].disabled = (page <= 1);
      if (btns[1]) btns[1].disabled = (page >= totalPages);
    } else if (pagEl) {
      pagEl.style.display = 'none';
    }
  }

  window.sgArtworkMyUploadsPrev = function() {
    if (_artworkMyUploadsPage > 1) { _artworkMyUploadsPage--; sgArtworkLoadMyUploads(); }
  };
  window.sgArtworkMyUploadsNext = function() {
    _artworkMyUploadsPage++;
    sgArtworkLoadMyUploads();
  };

  window.sgArtworkDelete = function(artworkId, btnEl) {
    if (!confirm('Delete this artwork? This cannot be undone.')) return;
    if (!SgConfig.token) { sgToast('You must be logged in', 'warn'); return; }
    var fd = new FormData();
    fd.append('artwork_id', artworkId);
    fetch(SgConfig.uir + 'ScrollArtworkAjax/delete', { method: 'POST', body: fd })
      .then(function(r) { return r.json(); })
      .then(function(data) {
        if (data.Status === 0) {
          sgToast('Artwork deleted');
          // Remove from any slots using this artwork
          for (var sk in sgState.artwork) {
            if (sgState.artwork[sk] && sgState.artwork[sk].id === artworkId) {
              sgState.artwork[sk] = null;
              sgArtworkImages[sk] = null;
            }
          }
          sgRenderArtworkSlots();
          sgRender();
          sgArtworkLoadMyUploads();
        } else {
          sgToast(data.Message || 'Delete failed', 'warn');
        }
      })
      .catch(function(err) {
        sgToast('Delete failed', 'warn');
      });
  };

  // ============================================================
  //  Artwork: Admin Approval modal
  // ============================================================
  var _artworkAdminPage = 1;

  window.sgArtworkOpenAdmin = function() {
    _artworkAdminPage = 1;
    var modal = document.getElementById('sc-artwork-admin-modal');
    if (modal) modal.classList.add('sc-modal-open');
    sgArtworkLoadAdmin();
  };

  window.sgArtworkCloseAdmin = function() {
    var modal = document.getElementById('sc-artwork-admin-modal');
    if (modal) modal.classList.remove('sc-modal-open');
  };

  function sgArtworkLoadAdmin() {
    var list = document.getElementById('sc-artwork-admin-list');
    if (list) list.innerHTML = '<div class="sc-artwork-loading"><i class="fas fa-spinner fa-spin"></i> Loading...</div>';
    fetch(SgConfig.uir + 'ScrollArtworkAjax/pending?page=' + _artworkAdminPage)
      .then(function(r) { return r.json(); })
      .then(function(data) {
        sgArtworkRenderAdmin(data);
      })
      .catch(function(err) {
        if (list) list.innerHTML = '<div class="sc-artwork-empty-state"><i class="fas fa-exclamation-triangle"></i>Failed to load pending artwork</div>';
      });
  }

  function sgArtworkRenderAdmin(data) {
    var list = document.getElementById('sc-artwork-admin-list');
    if (!list) return;
    var items = data.Artwork || [];
    if (items.length === 0) {
      list.innerHTML = '<div class="sc-artwork-empty-state"><i class="fas fa-check-circle"></i>No pending artwork to review.</div>';
    } else {
      var html = '';
      for (var i = 0; i < items.length; i++) {
        var item = items[i];
        html += '<div class="sc-artwork-admin-item" data-id="' + item.ArtworkId + '">';
        html += '<div class="sc-artwork-admin-thumb"><img src="' + sgEscapeHtml(item.Url || '') + '" alt="' + sgEscapeHtml(item.Name || '') + '" loading="lazy"></div>';
        html += '<div class="sc-artwork-admin-info">';
        html += '<div class="sc-artwork-admin-name">' + sgEscapeHtml(item.Name || 'Untitled') + '</div>';
        html += '<div class="sc-artwork-admin-meta">' + sgEscapeHtml(item.UploaderPersona || 'Unknown') + ' — ' + sgEscapeHtml(item.LayoutLocation || '') + ' — ' + (item.Width || '?') + ' \u00d7 ' + (item.Height || '?') + 'px</div>';
        if (item.Description) html += '<div class="sc-artwork-admin-meta" style="color:#4a5568">' + sgEscapeHtml(item.Description) + '</div>';
        if (item.Tags) html += '<div class="sc-artwork-admin-meta">Tags: ' + sgEscapeHtml(item.Tags) + '</div>';
        html += '<div class="sc-artwork-admin-actions">';
        html += '<button type="button" class="sc-btn-approve" onclick="sgArtworkApprove(' + item.ArtworkId + ', this)"><i class="fas fa-check"></i> Approve</button>';
        html += '<button type="button" class="sc-btn-reject" onclick="sgArtworkShowReject(this)"><i class="fas fa-times"></i> Reject</button>';
        html += '</div>';
        html += '<div class="sc-artwork-reject-input">';
        html += '<input type="text" placeholder="Reason for rejection..." maxlength="500">';
        html += '<button type="button" onclick="sgArtworkReject(' + item.ArtworkId + ', this)">Reject</button>';
        html += '</div>';
        html += '</div></div>';
      }
      list.innerHTML = html;
    }
    // Pagination
    var pagEl = document.getElementById('sc-artwork-admin-pagination');
    var pageInfo = document.getElementById('sc-artwork-admin-page-info');
    var total = parseInt(data.Total || 0);
    var perPage = parseInt(data.PerPage || 20);
    var page = parseInt(data.Page || 1);
    var totalPages = Math.max(1, Math.ceil(total / perPage));
    if (total > perPage && pagEl) {
      pagEl.style.display = 'flex';
      if (pageInfo) pageInfo.textContent = 'Page ' + page + ' of ' + totalPages;
      var btns = pagEl.querySelectorAll('button');
      if (btns[0]) btns[0].disabled = (page <= 1);
      if (btns[1]) btns[1].disabled = (page >= totalPages);
    } else if (pagEl) {
      pagEl.style.display = 'none';
    }
  }

  window.sgArtworkAdminPrev = function() {
    if (_artworkAdminPage > 1) { _artworkAdminPage--; sgArtworkLoadAdmin(); }
  };
  window.sgArtworkAdminNext = function() {
    _artworkAdminPage++;
    sgArtworkLoadAdmin();
  };

  window.sgArtworkApprove = function(artworkId, btnEl) {
    if (!SgConfig.token) { sgToast('Not authorized', 'warn'); return; }
    var fd = new FormData();
    fd.append('artwork_id', artworkId);
    fetch(SgConfig.uir + 'ScrollArtworkAjax/approve', { method: 'POST', body: fd })
      .then(function(r) { return r.json(); })
      .then(function(data) {
        if (data.Status === 0) {
          sgToast('Artwork approved');
          var row = btnEl.closest('.sc-artwork-admin-item');
          if (row) row.remove();
          // Check if list is empty now
          var list = document.getElementById('sc-artwork-admin-list');
          if (list && !list.querySelector('.sc-artwork-admin-item')) {
            list.innerHTML = '<div class="sc-artwork-empty-state"><i class="fas fa-check-circle"></i>No pending artwork to review.</div>';
          }
        } else {
          sgToast(data.Message || 'Approval failed', 'warn');
        }
      })
      .catch(function(err) {
        sgToast('Approval failed', 'warn');
      });
  };

  window.sgArtworkShowReject = function(btnEl) {
    var item = btnEl.closest('.sc-artwork-admin-item');
    if (!item) return;
    var rejectRow = item.querySelector('.sc-artwork-reject-input');
    if (rejectRow) rejectRow.classList.toggle('sc-visible');
  };

  window.sgArtworkReject = function(artworkId, btnEl) {
    var row = btnEl.closest('.sc-artwork-reject-input');
    var input = row ? row.querySelector('input') : null;
    var reason = input ? input.value.trim() : '';
    if (!reason) { sgToast('Please enter a reason for rejection', 'warn'); return; }
    if (!SgConfig.token) { sgToast('Not authorized', 'warn'); return; }
    var fd = new FormData();
    fd.append('artwork_id', artworkId);
    fd.append('reason', reason);
    fetch(SgConfig.uir + 'ScrollArtworkAjax/reject', { method: 'POST', body: fd })
      .then(function(r) { return r.json(); })
      .then(function(data) {
        if (data.Status === 0) {
          sgToast('Artwork rejected');
          var item = btnEl.closest('.sc-artwork-admin-item');
          if (item) item.remove();
          var list = document.getElementById('sc-artwork-admin-list');
          if (list && !list.querySelector('.sc-artwork-admin-item')) {
            list.innerHTML = '<div class="sc-artwork-empty-state"><i class="fas fa-check-circle"></i>No pending artwork to review.</div>';
          }
        } else {
          sgToast(data.Message || 'Rejection failed', 'warn');
        }
      })
      .catch(function(err) {
        sgToast('Rejection failed', 'warn');
      });
  };

  // ============================================================
  //  Init
  // ============================================================
  // Render border style preview thumbnails
  function sgRenderBorderPreviews() {
    var styles = ['classic','ornate','celtic','simple','royal','rustic','filigree','none'];
    for (var i = 0; i < styles.length; i++) {
      var cvs = document.getElementById('sc-bp-' + styles[i]);
      if (!cvs) continue;
      var pc = cvs.getContext('2d');
      var pw = cvs.width, ph = cvs.height;
      pc.clearRect(0, 0, pw, ph);
      var previewPal = PALETTES[sgState.palette] || PALETTES.classic;
      pc.fillStyle = previewPal.bg;
      pc.fillRect(0, 0, pw, ph);
      if (styles[i] !== 'none') {
        pc.save();
        pc.scale(pw / 850, ph / 1100);
        sgDrawBorder(pc, 850, 1100, sgState.palette, sgState.template, styles[i]);
        pc.restore();
      } else {
        pc.fillStyle = '#a0aec0'; pc.font = '11px sans-serif';
        pc.textAlign = 'center'; pc.textBaseline = 'middle';
        pc.fillText('No Border', pw/2, ph/2);
      }
    }
  }

  function sgInit() {
    // Select initial template
    sgSelectTemplate(sgState.template);

    // Load heraldry images
    var loadCount = 0;
    var totalLoads = 3;
    function onImageReady() {
      loadCount++;
      if (loadCount >= totalLoads) sgRender();
    }
    sgLoadImage('kingdom', SgConfig.kingdomHeraldry || '', onImageReady);
    sgLoadImage('park',    SgConfig.parkHeraldry || '',    onImageReady);
    sgLoadImage('player',  SgConfig.playerHeraldry || '',  onImageReady);

    // Generate initial body text
    sgSetAutoBody();

    // Restore collapsed section state from localStorage
    sgRestoreCollapseState();

    // Bind events
    sgBindEvents();

    // Bind autocomplete and officer chips
    sgBindRecipientAc();
    sgBindGivenByAc();
    sgBindOfficerChips();

    // Render artwork slot cards
    sgRenderArtworkSlots();

    // Bind artwork search enter key
    if (window._sgBindArtworkSearchEnter) window._sgBindArtworkSearchEnter();

    // Close artwork modals on backdrop click or ESC
    var artworkModals = document.querySelectorAll('.sc-artwork-modal');
    for (var mi = 0; mi < artworkModals.length; mi++) {
      (function(modal) {
        modal.addEventListener('click', function(e) {
          if (e.target === modal) modal.classList.remove('sc-modal-open');
        });
      })(artworkModals[mi]);
    }
    document.addEventListener('keydown', function(e) {
      if (e.keyCode === 27) {
        var openModals = document.querySelectorAll('.sc-artwork-modal.sc-modal-open');
        for (var i = 0; i < openModals.length; i++) openModals[i].classList.remove('sc-modal-open');
      }
    });

    // Render border preview thumbnails
    sgRenderBorderPreviews();

    // Initial render (after fonts are ready)
    if (document.fonts && document.fonts.ready) {
      document.fonts.ready.then(function() {
        sgRender();
      });
    } else {
      // Fallback: render after a short delay
      setTimeout(sgRender, 300);
    }
  }

  // Kick off
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', sgInit);
  } else {
    sgInit();
  }

})();
</script>
