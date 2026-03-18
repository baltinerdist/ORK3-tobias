<?php
// ---- Normalize controller data into clean local variables ----
$tournament        = $tournament        ?? [];
$brackets          = $brackets          ?? [];
$bracketData       = $bracket_data      ?? [];
$totalBrackets     = (int)($TotalBrackets     ?? 0);
$totalParticipants = (int)($TotalParticipants ?? 0);
$totalMatches      = (int)($TotalMatches      ?? 0);
$canManage         = !empty($CanManageTournament);
$loggedIn          = !empty($LoggedIn);

$tid          = (int)($tournament['TournamentId']          ?? 0);
$tName        = $tournament['Name']                        ?? 'Tournament';
$tDescription = trim($tournament['Description']            ?? '');
$tUrl         = trim($tournament['Url']                    ?? '');
$tDate        = $tournament['DateTime']                    ?? '';
$tKingdomId   = (int)($tournament['KingdomId']             ?? 0);
$tKingdomName = $tournament['KingdomName']                 ?? '';
$tParkId      = (int)($tournament['ParkId']                ?? 0);
$tParkName    = $tournament['ParkName']                    ?? '';
$tEventName   = $tournament['EventName']                   ?? '';
$tECDId       = (int)($tournament['EventCalendarDetailId'] ?? 0);

$displayDate   = ($tDate && substr($tDate, 0, 10) !== '0000-00-00')
	? date('F j, Y', strtotime($tDate))
	: 'Date TBD';
$shortDate     = ($tDate && substr($tDate, 0, 10) !== '0000-00-00')
	? date('M j, Y', strtotime($tDate))
	: '—';

// Style label map for display
$styleLabelMap = [
	'Single Sword'    => 'Single Sword',
	'Florentine'      => 'Florentine',
	'Sword and Shield'=> 'Sword & Shield',
	'Great Weapon'    => 'Great Weapon',
	'Missile'         => 'Missile',
	'Other'           => 'Open',
	'Jugging'         => 'Jugging',
	'Battlegame'      => 'Battlegame',
	'Quest'           => 'Quest',
];
$methodLabelMap = [
	'single'      => 'Single Elimination',
	'double'      => 'Double Elimination',
	'swiss'       => 'Swiss',
	'round-robin' => 'Round Robin',
	'ironman'     => 'Ironman',
	'score'       => 'Score',
];

// Unique styles across all brackets for hero badges
$heroStyles = [];
foreach ($brackets as $b) {
	$heroStyles[$b['Style']] = true;
}
$heroStyles = array_keys($heroStyles);
?>

<link rel="stylesheet" href="<?= HTTP_TEMPLATE ?>revised-frontend/style/revised.css?v=<?= filemtime(DIR_TEMPLATE . 'revised-frontend/style/revised.css') ?>">

<style>
/* ---- Tournament Profile (tn-) ---- */
:root { --tn-accent: #276749; --tn-accent-light: #f0fff4; }

/* Hero */
.tn-hero { position:relative; background:linear-gradient(135deg,#1a202c 0%,#2d3748 100%); color:#fff; padding:28px 24px 22px; border-radius:0 0 12px 12px; margin-bottom:0; overflow:hidden; }
.tn-hero-bg { position:absolute; inset:0; background-size:cover; background-position:center; opacity:0.12; pointer-events:none; }
.tn-hero-content { position:relative; display:flex; align-items:flex-start; gap:18px; flex-wrap:wrap; }
.tn-hero-icon { width:72px; height:72px; background:rgba(255,255,255,0.1); border-radius:12px; display:flex; align-items:center; justify-content:center; font-size:32px; flex-shrink:0; border:2px solid rgba(255,255,255,0.18); }
.tn-hero-center { flex:1; min-width:0; }
.tn-hero-center h1 { background:transparent!important; border:none!important; padding:0!important; border-radius:0!important; text-shadow:0 2px 8px rgba(0,0,0,0.35)!important; font-size:1.8rem; font-weight:800; color:#fff; margin:0 0 6px; line-height:1.15; }
.tn-breadcrumb { font-size:12px; color:rgba(255,255,255,0.6); margin-bottom:6px; }
.tn-breadcrumb a { color:rgba(255,255,255,0.75); text-decoration:none; }
.tn-breadcrumb a:hover { color:#fff; }
.tn-breadcrumb span { margin:0 5px; }
.tn-hero-badges { display:flex; flex-wrap:wrap; gap:6px; margin-top:8px; }
.tn-badge { display:inline-flex; align-items:center; gap:4px; padding:3px 9px; border-radius:20px; font-size:11px; font-weight:600; }
.tn-badge-style  { background:rgba(255,255,255,0.15); color:#fff; border:1px solid rgba(255,255,255,0.25); }
.tn-badge-date   { background:rgba(39,103,73,0.6); color:#9ae6b4; border:1px solid rgba(39,103,73,0.5); }
.tn-badge-event  { background:rgba(49,130,206,0.4); color:#bee3f8; border:1px solid rgba(49,130,206,0.4); }
.tn-hero-right { flex-shrink:0; display:flex; align-items:flex-start; }
.tn-hero-actions { display:flex; flex-direction:column; gap:8px; }

/* Stats row */
.tn-stats-row { display:flex; gap:12px; padding:14px 0; flex-wrap:wrap; }
.tn-stat-card { flex:1; min-width:120px; background:#fff; border:1px solid #e2e8f0; border-radius:10px; padding:14px 12px; text-align:center; box-shadow:0 1px 3px rgba(0,0,0,0.04); }
.tn-stat-card-link { cursor:pointer; transition:box-shadow 0.15s, border-color 0.15s; }
.tn-stat-card-link:hover { border-color:#276749; box-shadow:0 2px 8px rgba(39,103,73,0.12); }
.tn-stat-icon { font-size:18px; color:#a0aec0; margin-bottom:4px; }
.tn-stat-value { font-size:1.6rem; font-weight:800; color:#1a202c; line-height:1; }
.tn-stat-sub { font-size:11px; color:#718096; margin-top:2px; }
.tn-stat-label { font-size:11px; color:#718096; margin-top:4px; text-transform:uppercase; letter-spacing:0.5px; font-weight:600; }

/* Layout */
.tn-layout { display:flex; gap:18px; align-items:flex-start; }
.tn-sidebar { width:264px; flex-shrink:0; display:flex; flex-direction:column; gap:12px; }
.tn-main { flex:1; min-width:0; }

/* Card */
.tn-card { background:#fff; border:1px solid #e2e8f0; border-radius:10px; padding:16px; box-shadow:0 1px 3px rgba(0,0,0,0.04); }
.tn-card h4 { margin:0 0 10px; font-size:13px; font-weight:700; color:#4a5568; display:flex; align-items:center; gap:6px; background:transparent!important; border:none!important; padding:0!important; border-radius:0!important; text-shadow:none!important; }
.tn-detail-row { display:flex; align-items:flex-start; gap:8px; padding:5px 0; font-size:13px; color:#4a5568; border-bottom:1px solid #f0f4f8; }
.tn-detail-row:last-child { border-bottom:none; }
.tn-detail-icon { width:16px; color:#a0aec0; flex-shrink:0; margin-top:2px; text-align:center; }
.tn-detail-text { flex:1; word-break:break-word; }
.tn-detail-text a { color:#276749; text-decoration:none; }
.tn-detail-text a:hover { text-decoration:underline; }

/* Tabs */
.tn-tabs { background:#fff; border:1px solid #e2e8f0; border-radius:10px; box-shadow:0 1px 3px rgba(0,0,0,0.05); overflow:hidden; }
.tn-tab-nav { list-style:none; margin:0; padding:0; display:flex; border-bottom:1px solid #e2e8f0; overflow-x:auto; }
.tn-tab-nav li { padding:11px 16px; font-size:13px; font-weight:600; color:#718096; cursor:pointer; border-bottom:2px solid transparent; white-space:nowrap; display:flex; align-items:center; gap:5px; }
.tn-tab-nav li:hover { color:#276749; background:#f7fafc; }
.tn-tab-active { color:#276749!important; border-bottom-color:#276749!important; background:#fff!important; }
.tn-tab-count { font-size:11px; color:#a0aec0; }
.tn-tab-panel { padding:16px 18px; }

/* Bracket cards */
.tn-bracket-card { border:1px solid #e2e8f0; border-radius:8px; margin-bottom:14px; overflow:hidden; }
.tn-bracket-card:last-child { margin-bottom:0; }
.tn-bracket-header { background:#f7fafc; padding:12px 14px; display:flex; align-items:center; gap:10px; border-bottom:1px solid #e2e8f0; }
.tn-bracket-header h4 { margin:0; font-size:14px; font-weight:700; color:#1a202c; background:transparent!important; border:none!important; padding:0!important; border-radius:0!important; text-shadow:none!important; }
.tn-bracket-meta { font-size:12px; color:#718096; display:flex; gap:10px; flex-wrap:wrap; margin-top:3px; }
.tn-bracket-meta span { display:inline-flex; align-items:center; gap:3px; }
.tn-bracket-body { padding:12px 14px; }
.tn-participant-list { list-style:none; margin:0; padding:0; }
.tn-participant-list li { display:flex; align-items:center; gap:8px; padding:5px 0; font-size:13px; color:#4a5568; border-bottom:1px solid #f0f4f8; }
.tn-participant-list li:last-child { border-bottom:none; }
.tn-participant-seed { width:20px; height:20px; background:#e2e8f0; border-radius:50%; display:flex; align-items:center; justify-content:center; font-size:10px; font-weight:700; color:#718096; flex-shrink:0; }
.tn-empty { color:#a0aec0; font-size:13px; font-style:italic; padding:8px 0; }
.tn-remove-participant { background:none; border:none; color:#cbd5e0; cursor:pointer; font-size:15px; padding:0 2px; line-height:1; flex-shrink:0; }
.tn-remove-participant:hover { color:#e53e3e; }
.tn-bracket-actions { display:flex; gap:8px; margin-top:10px; padding-top:10px; border-top:1px solid #f0f4f8; }

/* Buttons */
.tn-btn { display:inline-flex; align-items:center; gap:5px; padding:7px 14px; border-radius:6px; font-size:13px; font-weight:600; border:none; cursor:pointer; transition:background 0.15s; }
.tn-btn-primary { background:#276749; color:#fff; }
.tn-btn-primary:hover { background:#1e4e36; }
.tn-btn-outline { background:transparent; color:#276749; border:1px solid #276749; }
.tn-btn-outline:hover { background:#f0fff4; }
.tn-btn-ghost { background:transparent; color:#718096; border:1px solid #e2e8f0; }
.tn-btn-ghost:hover { background:#f7fafc; }
.tn-btn-sm { padding:4px 10px; font-size:12px; }
.tn-btn:disabled { opacity:0.6; cursor:not-allowed; }

/* Tables */
.tn-table { width:100%; border-collapse:collapse; font-size:13px; }
.tn-table th { background:#f7fafc; padding:8px 10px; text-align:left; font-size:11px; font-weight:700; color:#718096; text-transform:uppercase; letter-spacing:0.5px; border-bottom:2px solid #e2e8f0; }
.tn-table td { padding:8px 10px; border-bottom:1px solid #f0f4f8; color:#4a5568; }
.tn-table tr:last-child td { border-bottom:none; }

/* Modals */
.tn-overlay { position:fixed; inset:0; background:rgba(0,0,0,0.5); display:flex; align-items:center; justify-content:center; z-index:1100; opacity:0; pointer-events:none; transition:opacity 0.2s; }
.tn-overlay.tn-open { opacity:1; pointer-events:auto; }
.tn-overlay .tn-modal-box { background:#fff; border-radius:12px; box-shadow:0 20px 60px rgba(0,0,0,0.3); max-height:90vh; display:flex; flex-direction:column; transform:translateY(8px); transition:transform 0.2s, opacity 0.2s; opacity:0; }
.tn-overlay.tn-open .tn-modal-box { transform:translateY(0); opacity:1; }
.tn-modal-header { display:flex; align-items:center; justify-content:space-between; padding:16px 20px; border-bottom:1px solid #e2e8f0; flex-shrink:0; }
.tn-modal-title { font-size:16px; font-weight:700; color:#1a202c; margin:0; background:transparent!important; border:none!important; padding:0!important; border-radius:0!important; text-shadow:none!important; }
.tn-modal-close { background:none; border:none; font-size:22px; color:#a0aec0; cursor:pointer; line-height:1; padding:0 4px; }
.tn-modal-close:hover { color:#4a5568; }
.tn-modal-body { padding:20px; overflow-y:auto; flex:1; }
.tn-modal-footer { padding:14px 20px; border-top:1px solid #e2e8f0; display:flex; align-items:center; justify-content:flex-end; gap:10px; flex-shrink:0; }
.tn-field { display:flex; flex-direction:column; gap:4px; margin-bottom:14px; }
.tn-field label { font-size:12px; font-weight:700; color:#4a5568; text-transform:uppercase; letter-spacing:0.4px; }
.tn-field input, .tn-field select, .tn-field textarea { width:100%; padding:8px 10px; border:1px solid #e2e8f0; border-radius:6px; font-size:13px; color:#1a202c; box-sizing:border-box; }
.tn-field input:focus, .tn-field select:focus, .tn-field textarea:focus { outline:none; border-color:#276749; box-shadow:0 0 0 2px rgba(39,103,73,0.12); }
.tn-feedback { font-size:13px; font-weight:600; margin-bottom:12px; display:none; }
.tn-feedback-err { color:#c53030; }
.tn-feedback-ok  { color:#276749; }
.tn-field-row { display:grid; grid-template-columns:1fr 1fr; gap:12px; }

/* Bracket visualization */
.tn-bv-wrap { overflow-x:auto; padding-bottom:8px; }
.tn-bv-tree { display:flex; gap:0; align-items:flex-start; min-width:max-content; }
.tn-bv-round { display:flex; flex-direction:column; min-width:190px; padding:0 14px; }
.tn-bv-round-label { font-size:11px; font-weight:700; color:#a0aec0; text-transform:uppercase; letter-spacing:0.5px; text-align:center; margin-bottom:10px; padding-bottom:6px; border-bottom:1px solid #e2e8f0; }
.tn-bv-match { border:1px solid #e2e8f0; border-radius:7px; overflow:hidden; background:#fff; box-shadow:0 1px 3px rgba(0,0,0,0.05); margin:6px 0; }
.tn-bv-match.tn-bv-clickable { cursor:pointer; border-color:#276749; }
.tn-bv-match.tn-bv-clickable:hover { box-shadow:0 2px 8px rgba(39,103,73,0.18); background:#f0fff4; }
.tn-bv-match.tn-bv-resolved { border-color:#c6f6d5; background:#f0fff4; }
.tn-bv-slot { display:flex; align-items:center; gap:6px; padding:7px 10px; font-size:13px; min-height:34px; }
.tn-bv-slot:first-child { border-bottom:1px solid #e2e8f0; }
.tn-bv-slot.tn-bv-winner { font-weight:700; color:#276749; }
.tn-bv-slot.tn-bv-loser  { color:#a0aec0; text-decoration:line-through; }
.tn-bv-slot.tn-bv-bye    { color:#cbd5e0; font-style:italic; font-size:12px; }
.tn-bv-seed { width:18px; height:18px; border-radius:50%; background:#e2e8f0; display:flex; align-items:center; justify-content:center; font-size:9px; font-weight:700; color:#718096; flex-shrink:0; }
.tn-bv-result-pill { font-size:10px; font-weight:700; padding:1px 6px; border-radius:10px; background:#c6f6d5; color:#276749; margin-left:auto; flex-shrink:0; }
.tn-bv-tbl { width:100%; border-collapse:collapse; font-size:13px; }
.tn-bv-tbl th { background:#f7fafc; padding:7px 10px; font-size:11px; font-weight:700; color:#718096; text-transform:uppercase; letter-spacing:0.4px; border-bottom:2px solid #e2e8f0; }
.tn-bv-tbl td { padding:7px 10px; border-bottom:1px solid #f0f4f8; color:#4a5568; }
.tn-bv-tbl tr:last-child td { border-bottom:none; }
.tn-bv-tbl tr.tn-bv-clickable:hover td { background:#f0fff4; cursor:pointer; }
.tn-bv-round-nav { display:flex; align-items:center; gap:8px; margin-bottom:12px; flex-wrap:wrap; }
.tn-bv-round-btn { padding:4px 12px; border-radius:20px; font-size:12px; font-weight:600; border:1px solid #e2e8f0; background:#fff; color:#718096; cursor:pointer; }
.tn-bv-round-btn.active { background:#276749; color:#fff; border-color:#276749; }
.tn-bv-round-section { }
.tn-bv-section-label { font-size:11px; font-weight:700; color:#718096; text-transform:uppercase; letter-spacing:0.5px; margin:14px 0 8px; padding-bottom:4px; border-bottom:1px solid #e2e8f0; }
.tn-bv-generate-bar { display:flex; align-items:center; gap:10px; padding:12px 14px; background:#f7fafc; border:1px dashed #e2e8f0; border-radius:8px; margin-bottom:14px; }
.tn-bv-status-badge { font-size:11px; font-weight:700; padding:2px 8px; border-radius:10px; }
.tn-bv-status-setup    { background:#e2e8f0; color:#718096; }
.tn-bv-status-active   { background:#bee3f8; color:#2b6cb0; }
.tn-bv-status-complete { background:#c6f6d5; color:#276749; }
.tn-bv-empty { color:#a0aec0; font-size:13px; font-style:italic; padding:16px 0; text-align:center; }

/* Responsive */
@media (max-width: 768px) {
	.tn-layout { flex-direction:column; }
	.tn-sidebar { width:100%; }
	.tn-hero-content { flex-direction:column; gap:12px; }
	.tn-stats-row { gap:8px; }
	.tn-stat-card { min-width:calc(50% - 4px); }
	.tn-field-row { grid-template-columns:1fr; }
}
/* DnD reorder */
.tn-dnd-over { background:#f0fff4!important; outline:2px dashed #276749; border-radius:6px; }
.tn-dnd-handle { color:#cbd5e0; margin-right:4px; cursor:grab; font-size:11px; }

/* Autocomplete dropdown */
.tn-ac-results { display:none; position:absolute; top:100%; left:0; right:0; background:#fff; border:1px solid #e2e8f0; border-top:none; border-radius:0 0 6px 6px; box-shadow:0 4px 12px rgba(0,0,0,.1); z-index:20; max-height:200px; overflow-y:auto; }
.tn-ac-results.tn-ac-open { display:block; }
.tn-ac-item { padding:8px 12px; cursor:pointer; font-size:13px; border-bottom:1px solid #f0f4f8; }
.tn-ac-item:last-child { border-bottom:none; }
.tn-ac-item:hover, .tn-ac-item:focus { background:#f7fafc; outline:none; }
.tn-ac-item.tn-ac-empty { color:#a0aec0; cursor:default; }
</style>

<!-- =============================================
     ZONE 1: Hero
     ============================================= -->
<div class="tn-hero">
	<div class="tn-hero-content">
		<!-- Trophy icon -->
		<div class="tn-hero-icon">
			<i class="fas fa-trophy" style="color:#f6e05e"></i>
		</div>

		<!-- Name / breadcrumb / badges -->
		<div class="tn-hero-center">
			<div class="tn-breadcrumb">
				<?php if ($tKingdomId > 0): ?>
					<a href="<?= UIR ?>Kingdom/index/<?= $tKingdomId ?>"><i class="fas fa-crown" style="font-size:10px"></i> <?= htmlspecialchars($tKingdomName) ?></a>
					<span>/</span>
				<?php endif; ?>
				<?php if ($tParkId > 0): ?>
					<a href="<?= UIR ?>Park/index/<?= $tParkId ?>"><?= htmlspecialchars($tParkName) ?></a>
					<span>/</span>
				<?php endif; ?>
				<?php if (!empty($tEventName)): ?>
					<span><?= htmlspecialchars($tEventName) ?></span>
					<span>/</span>
				<?php endif; ?>
				<span style="color:rgba(255,255,255,0.5)">Tournament</span>
			</div>

			<h1><?= htmlspecialchars($tName) ?></h1>

			<div class="tn-hero-badges">
				<span class="tn-badge tn-badge-date">
					<i class="fas fa-calendar-alt"></i> <?= htmlspecialchars($shortDate) ?>
				</span>
				<?php foreach ($heroStyles as $style): ?>
					<span class="tn-badge tn-badge-style"><?= htmlspecialchars($styleLabelMap[$style] ?? $style) ?></span>
				<?php endforeach; ?>
				<?php if (!empty($tEventName)): ?>
					<span class="tn-badge tn-badge-event"><i class="fas fa-flag"></i> <?= htmlspecialchars($tEventName) ?></span>
				<?php endif; ?>
			</div>
		</div>

		<!-- Action buttons -->
		<?php if ($canManage): ?>
		<div class="tn-hero-right">
			<div class="tn-hero-actions">
				<button class="tn-btn tn-btn-outline" style="color:#fff;border-color:rgba(255,255,255,0.4)" onclick="tnOpenAddBracketModal()">
					<i class="fas fa-plus"></i> Add Bracket
				</button>
			</div>
		</div>
		<?php endif; ?>
	</div>
</div>

<!-- =============================================
     ZONE 2: Stats Row
     ============================================= -->
<div class="tn-stats-row">
	<div class="tn-stat-card<?= $totalBrackets > 0 ? ' tn-stat-card-link' : '' ?>"<?= $totalBrackets > 0 ? ' onclick="tnActivateTab(\'brackets\')"' : '' ?>>
		<div class="tn-stat-icon"><i class="fas fa-sitemap"></i></div>
		<div class="tn-stat-value"><?= $totalBrackets ?></div>
		<div class="tn-stat-label">Bracket<?= $totalBrackets != 1 ? 's' : '' ?></div>
	</div>
	<div class="tn-stat-card<?= $totalParticipants > 0 ? ' tn-stat-card-link' : '' ?>"<?= $totalParticipants > 0 ? ' onclick="tnActivateTab(\'participants\')"' : '' ?>>
		<div class="tn-stat-icon"><i class="fas fa-users"></i></div>
		<div class="tn-stat-value"><?= $totalParticipants ?></div>
		<div class="tn-stat-label">Participant<?= $totalParticipants != 1 ? 's' : '' ?></div>
	</div>
	<div class="tn-stat-card">
		<div class="tn-stat-icon"><i class="fas fa-swords"></i></div>
		<div class="tn-stat-value"><?= $totalMatches ?></div>
		<div class="tn-stat-label">Match<?= $totalMatches != 1 ? 'es' : '' ?></div>
	</div>
	<div class="tn-stat-card">
		<div class="tn-stat-icon"><i class="fas fa-calendar-alt"></i></div>
		<?php if ($tDate && substr($tDate, 0, 10) !== '0000-00-00'): ?>
			<div class="tn-stat-value" style="font-size:1.1rem"><?= date('M j', strtotime($tDate)) ?></div>
			<div class="tn-stat-sub"><?= date('Y', strtotime($tDate)) ?></div>
		<?php else: ?>
			<div class="tn-stat-value">&mdash;</div>
		<?php endif; ?>
		<div class="tn-stat-label">Date</div>
	</div>
</div>

<!-- =============================================
     ZONE 3: Sidebar + Main
     ============================================= -->
<div class="tn-layout">

	<!-- ---- Sidebar ---- -->
	<aside class="tn-sidebar">

		<!-- Tournament details -->
		<div class="tn-card">
			<h4><i class="fas fa-info-circle"></i> Details</h4>
			<div class="tn-detail-row">
				<span class="tn-detail-icon"><i class="fas fa-calendar-alt"></i></span>
				<span class="tn-detail-text"><?= htmlspecialchars($displayDate) ?></span>
			</div>
			<?php if ($tParkId > 0): ?>
			<div class="tn-detail-row">
				<span class="tn-detail-icon"><i class="fas fa-map-marker-alt"></i></span>
				<span class="tn-detail-text"><a href="<?= UIR ?>Park/index/<?= $tParkId ?>"><?= htmlspecialchars($tParkName) ?></a></span>
			</div>
			<?php elseif ($tKingdomId > 0): ?>
			<div class="tn-detail-row">
				<span class="tn-detail-icon"><i class="fas fa-crown"></i></span>
				<span class="tn-detail-text"><a href="<?= UIR ?>Kingdom/index/<?= $tKingdomId ?>"><?= htmlspecialchars($tKingdomName) ?></a></span>
			</div>
			<?php endif; ?>
			<?php if (!empty($tEventName)): ?>
			<div class="tn-detail-row">
				<span class="tn-detail-icon"><i class="fas fa-flag"></i></span>
				<span class="tn-detail-text"><?= htmlspecialchars($tEventName) ?></span>
			</div>
			<?php endif; ?>
			<?php if (!empty($tUrl)): ?>
			<div class="tn-detail-row">
				<span class="tn-detail-icon"><i class="fas fa-globe"></i></span>
				<span class="tn-detail-text"><a href="<?= htmlspecialchars($tUrl) ?>" target="_blank" rel="noopener noreferrer"><?= htmlspecialchars($tUrl) ?></a></span>
			</div>
			<?php endif; ?>
		</div>

		<!-- Bracket summary -->
		<?php if ($totalBrackets > 0): ?>
		<div class="tn-card">
			<h4><i class="fas fa-sitemap"></i> Brackets</h4>
			<ul class="tn-participant-list">
				<?php foreach ($brackets as $i => $b): ?>
				<li style="cursor:pointer" onclick="tnActivateTab('brackets');tnScrollToBracket(<?= (int)$b['BracketId'] ?>)">
					<span class="tn-participant-seed"><?= $i + 1 ?></span>
					<span>
						<strong><?= htmlspecialchars($styleLabelMap[$b['Style']] ?? $b['Style']) ?></strong>
						<span style="color:#a0aec0;font-size:11px;margin-left:4px"><?= htmlspecialchars($methodLabelMap[$b['Method']] ?? $b['Method']) ?></span>
					</span>
				</li>
				<?php endforeach; ?>
			</ul>
		</div>
		<?php endif; ?>

	</aside>

	<!-- ---- Main Tabbed Content ---- -->
	<div class="tn-main">
		<div class="tn-tabs">

			<ul class="tn-tab-nav" id="tn-tab-nav">
				<li data-tntab="about" class="tn-tab-active" onclick="tnActivateTab('about')">
					<i class="fas fa-info-circle"></i> About
				</li>
				<li data-tntab="brackets" onclick="tnActivateTab('brackets')">
					<i class="fas fa-sitemap"></i> Brackets
					<span class="tn-tab-count">(<?= $totalBrackets ?>)</span>
				</li>
				<li data-tntab="participants" onclick="tnActivateTab('participants')">
					<i class="fas fa-users"></i> Participants
					<span class="tn-tab-count">(<?= $totalParticipants ?>)</span>
				</li>
				<li data-tntab="bracketviz" onclick="tnActivateTab('bracketviz')">
					<i class="fas fa-project-diagram"></i> Bracket View
				</li>
				<?php if (!empty($standingsData)): ?>
				<li data-tntab="standings" onclick="tnActivateTab('standings')">
					<i class="fas fa-medal"></i> Standings
				</li>
				<?php endif; ?>
			</ul>

			<!-- About Tab -->
			<div class="tn-tab-panel" id="tn-tab-about">
				<?php if (!empty($tDescription)): ?>
				<div style="font-size:14px;line-height:1.6;color:#4a5568;margin-bottom:14px">
					<?= nl2br(htmlspecialchars($tDescription)) ?>
				</div>
				<?php else: ?>
				<div class="tn-empty">No description provided.</div>
				<?php endif; ?>

				<?php if (!empty($tUrl)): ?>
				<div style="margin-top:12px">
					<a href="<?= htmlspecialchars($tUrl) ?>" target="_blank" rel="noopener noreferrer" class="tn-btn tn-btn-outline tn-btn-sm">
						<i class="fas fa-external-link-alt"></i> Tournament Website
					</a>
				</div>
				<?php endif; ?>
			</div>

			<!-- Brackets Tab -->
			<div class="tn-tab-panel" id="tn-tab-brackets" style="display:none">
				<?php if ($canManage): ?>
				<div style="display:flex;justify-content:flex-end;margin-bottom:14px">
					<button class="tn-btn tn-btn-primary tn-btn-sm" onclick="tnOpenAddBracketModal()">
						<i class="fas fa-plus"></i> Add Bracket
					</button>
				</div>
				<?php endif; ?>

				<?php if ($totalBrackets === 0): ?>
				<div class="tn-empty">No brackets yet.<?= $canManage ? ' Use "Add Bracket" to create one.' : '' ?></div>
				<?php else: ?>
					<?php foreach ($bracketData as $bid => $bd): ?>
					<?php $b = $bd['Bracket']; $pList = $bd['Participants']; $mList = $bd['Matches']; ?>
					<div class="tn-bracket-card" id="tn-bracket-<?= $bid ?>">
						<div class="tn-bracket-header">
							<div style="flex:1">
								<h4><?= htmlspecialchars($styleLabelMap[$b['Style']] ?? $b['Style']) ?></h4>
								<div class="tn-bracket-meta">
									<span><i class="fas fa-project-diagram"></i> <?= htmlspecialchars($methodLabelMap[$b['Method']] ?? $b['Method']) ?></span>
									<span><i class="fas fa-users"></i> <?= htmlspecialchars(ucfirst($b['Participants'])) ?></span>
									<?php if ((int)$b['Rings'] > 0): ?>
									<span><i class="fas fa-circle"></i> <?= (int)$b['Rings'] ?> ring<?= (int)$b['Rings'] != 1 ? 's' : '' ?></span>
									<?php endif; ?>
									<span><i class="fas fa-random"></i> Seeding: <?= htmlspecialchars(str_replace('-', ' ', $b['Seeding'])) ?></span>
									<span style="color:#a0aec0"><?= count($pList) ?> participant<?= count($pList) != 1 ? 's' : '' ?></span>
									<?php if (count($mList) > 0): ?>
									<span style="color:#a0aec0"><?= count($mList) ?> match<?= count($mList) != 1 ? 'es' : '' ?></span>
									<?php endif; ?>
								</div>
							</div>
							<?php if ($canManage): ?>
							<div style="display:flex;gap:6px;align-items:center;flex-wrap:wrap">
								<button class="tn-btn tn-btn-outline tn-btn-sm" onclick="tnOpenAddParticipantModal(<?= $bid ?>, <?= $tid ?>)">
									<i class="fas fa-user-plus"></i> Add Participant
								</button>
								<?php if (count($pList) >= 2): ?>
								<button class="tn-btn tn-btn-primary tn-btn-sm" onclick="tnGenerateMatches(<?= $bid ?>, <?= $tid ?>)">
									<i class="fas fa-play"></i> Generate
								</button>
								<?php endif; ?>
							</div>
							<?php endif; ?>
						</div>
						<div class="tn-bracket-body">
							<?php if (count($pList) === 0): ?>
							<div class="tn-empty">No participants yet.</div>
							<?php else: ?>
<?php $isDnd = $canManage && in_array($b['Seeding'] ?? '', ['manual','random-manual']); ?>
							<ul class="tn-participant-list<?= $isDnd ? ' tn-dnd-list' : '' ?>"<?= $isDnd ? ' data-bracket-id="' . $bid . '"' : '' ?>>
								<?php foreach ($pList as $i => $p): ?>
								<li<?= $isDnd ? ' data-pid="' . (int)$p['ParticipantId'] . '"' : '' ?>>
									<?php if ($isDnd): ?><span class="tn-dnd-handle"><i class="fas fa-grip-lines"></i></span><?php endif; ?>
									<span class="tn-participant-seed"><?= $i + 1 ?></span>
									<span style="flex:1">
										<?php if (!empty($p['Persona'])): ?>
											<?php if ($p['MundaneId'] > 0): ?><a href="<?= UIR ?>Playernew/index/<?= $p['MundaneId'] ?>" style="color:#276749;text-decoration:none"><?= htmlspecialchars($p['Alias'] ?: $p['Persona']) ?></a><?php else: ?><?= htmlspecialchars($p['Alias'] ?: $p['Persona']) ?><?php endif; ?>
											<?php if ($p['Alias'] && $p['Alias'] !== $p['Persona']): ?>
												<span style="color:#a0aec0;font-size:11px">(<?= htmlspecialchars($p['Persona']) ?>)</span>
											<?php endif; ?>
										<?php else: ?>
											<?= htmlspecialchars($p['Alias'] ?: '—') ?>
										<?php endif; ?>
									</span>
									<?php if (!empty($p['ParkName'])): ?>
									<span style="font-size:11px;color:#a0aec0"><?= htmlspecialchars($p['ParkName']) ?></span>
									<?php endif; ?>
									<?php if ($canManage): ?>
									<button class="tn-remove-participant" data-pid="<?= (int)$p['ParticipantId'] ?>" data-bid="<?= $bid ?>" data-tid="<?= $tournament_id ?>" title="Remove participant" onclick="tnRemoveParticipant(this)">&times;</button>
									<?php endif; ?>
								</li>
								<?php endforeach; ?>
							</ul>
							<?php endif; ?>

							<?php if (count($mList) > 0): ?>
							<div style="margin-top:12px;border-top:1px solid #f0f4f8;padding-top:10px">
								<div style="font-size:12px;font-weight:700;color:#718096;text-transform:uppercase;letter-spacing:0.5px;margin-bottom:8px">Match Results</div>
								<table class="tn-table">
									<thead>
										<tr>
											<th>Round</th>
											<th>Participant 1</th>
											<th>Result</th>
											<th>Participant 2</th>
										</tr>
									</thead>
									<tbody>
										<?php foreach ($mList as $m): ?>
										<tr>
											<td style="color:#a0aec0">R<?= htmlspecialchars($m['Round']) ?></td>
											<td><?= htmlspecialchars($m['Participant1Alias'] ?? '—') ?></td>
											<td style="text-align:center;color:#718096"><?= htmlspecialchars($m['Result'] ?? '—') ?></td>
											<td><?= htmlspecialchars($m['Participant2Alias'] ?? '—') ?></td>
										</tr>
										<?php endforeach; ?>
									</tbody>
								</table>
							</div>
							<?php elseif (count($pList) > 0): ?>
							<div class="tn-empty" style="margin-top:10px;padding-top:10px;border-top:1px solid #f0f4f8">
								No matches generated yet. Bracket generation coming in a future update.
							</div>
							<?php endif; ?>
						</div>
					</div>
					<?php endforeach; ?>
				<?php endif; ?>
			</div>

			<!-- Participants Tab -->
			<div class="tn-tab-panel" id="tn-tab-participants" style="display:none">
				<?php if ($totalParticipants === 0): ?>
				<div class="tn-empty">No participants yet.</div>
				<?php else: ?>
				<?php foreach ($bracketData as $bid => $bd): ?>
				<?php $b = $bd['Bracket']; $pList = $bd['Participants']; if (empty($pList)) continue; ?>
				<div style="margin-bottom:20px">
					<div style="font-size:12px;font-weight:700;color:#718096;text-transform:uppercase;letter-spacing:0.5px;margin-bottom:8px">
						<?= htmlspecialchars($styleLabelMap[$b['Style']] ?? $b['Style']) ?> — <?= htmlspecialchars($methodLabelMap[$b['Method']] ?? $b['Method']) ?>
					</div>
					<table class="tn-table">
						<thead>
							<tr>
								<th>#</th>
								<th>Alias</th>
								<th>Player</th>
								<th>Park</th>
							</tr>
						</thead>
						<tbody>
							<?php foreach ($pList as $i => $p): ?>
							<tr>
								<td style="color:#a0aec0;width:32px"><?= $i + 1 ?></td>
								<td><?= htmlspecialchars($p['Alias'] ?: '—') ?></td>
								<td>
									<?php if (!empty($p['Persona']) && $p['MundaneId'] > 0): ?>
									<a href="<?= UIR ?>Playernew/index/<?= (int)$p['MundaneId'] ?>" style="color:#276749;text-decoration:none"><?= htmlspecialchars($p['Persona']) ?></a>
									<?php elseif (!empty($p['Persona'])): ?>
									<?= htmlspecialchars($p['Persona']) ?>
									<?php else: ?>
									<span style="color:#a0aec0">—</span>
									<?php endif; ?>
								</td>
								<td style="color:#718096"><?= htmlspecialchars($p['ParkName'] ?? '—') ?></td>
							</tr>
							<?php endforeach; ?>
						</tbody>
					</table>
				</div>
				<?php endforeach; ?>
				<?php endif; ?>
			</div>

			<!-- Bracket View Tab -->
			<div class="tn-tab-panel" id="tn-tab-bracketviz" style="display:none">
				<?php if ($totalBrackets === 0): ?>
				<div class="tn-bv-empty">No brackets yet.</div>
				<?php else: ?>
				<?php if ($totalBrackets > 1): ?>
				<div style="margin-bottom:14px;display:flex;align-items:center;gap:10px">
					<label style="font-size:12px;font-weight:700;color:#4a5568;text-transform:uppercase;letter-spacing:0.5px">Bracket:</label>
					<select id="tn-bv-bracket-select" onchange="tnRenderBracketViz(parseInt(this.value))" style="padding:5px 8px;border:1px solid #e2e8f0;border-radius:6px;font-size:13px">
						<?php foreach ($bracketData as $bvid => $bvd): $bvb = $bvd['Bracket']; ?>
						<option value="<?= $bvid ?>"><?= htmlspecialchars($styleLabelMap[$bvb['Style']] ?? $bvb['Style']) ?> &#x2014; <?= htmlspecialchars($methodLabelMap[$bvb['Method']] ?? $bvb['Method']) ?></option>
						<?php endforeach; ?>
					</select>
				</div>
				<?php endif; ?>
				<div id="tn-bv-container"></div>
				<?php endif; ?>
			</div>

			<!-- Standings Tab -->
			<?php if (!empty($standingsData)): ?>
			<div class="tn-tab-panel" id="tn-tab-standings" style="display:none">
				<?php if (count($standingsData) > 1): ?>
				<div style="margin-bottom:14px;display:flex;align-items:center;gap:10px">
					<label style="font-size:12px;font-weight:700;color:#4a5568;text-transform:uppercase;letter-spacing:0.5px">Bracket:</label>
					<select id="tn-st-bracket-select" onchange="tnShowStandings(parseInt(this.value))" style="padding:5px 8px;border:1px solid #e2e8f0;border-radius:6px;font-size:13px">
						<?php foreach ($standingsData as $stBid => $stRows): $stB = $bracketData[$stBid]['Bracket'] ?? []; ?>
						<option value="<?= $stBid ?>"><?= htmlspecialchars($styleLabelMap[$stB['Style']] ?? $stB['Style'] ?? '') ?> &#x2014; <?= htmlspecialchars($methodLabelMap[$stB['Method']] ?? $stB['Method'] ?? '') ?></option>
						<?php endforeach; ?>
					</select>
				</div>
				<?php endif; ?>
				<?php foreach ($standingsData as $stBid => $stRows): ?>
				<div class="tn-standings-section" data-stbid="<?= $stBid ?>" <?= array_key_first($standingsData) !== $stBid ? 'style="display:none"' : '' ?>>
					<?php if (empty($stRows)): ?>
					<div class="tn-empty">No standings yet.</div>
					<?php else: ?>
					<table class="tn-table" id="tn-standings-table-<?= $stBid ?>">
						<thead>
							<tr>
								<th style="cursor:pointer" onclick="tnSortTable('tn-standings-table-<?= $stBid ?>',0,true)">Rank</th>
								<th style="cursor:pointer" onclick="tnSortTable('tn-standings-table-<?= $stBid ?>',1,false)">Participant</th>
								<th style="cursor:pointer" onclick="tnSortTable('tn-standings-table-<?= $stBid ?>',2,false)">Park</th>
								<th style="cursor:pointer;text-align:center" onclick="tnSortTable('tn-standings-table-<?= $stBid ?>',3,true)">W</th>
								<th style="cursor:pointer;text-align:center" onclick="tnSortTable('tn-standings-table-<?= $stBid ?>',4,true)">L</th>
								<th style="cursor:pointer;text-align:center" onclick="tnSortTable('tn-standings-table-<?= $stBid ?>',5,true)">T</th>
								<th style="cursor:pointer;text-align:center" onclick="tnSortTable('tn-standings-table-<?= $stBid ?>',6,true)">Byes</th>
								<th style="cursor:pointer;text-align:right" onclick="tnSortTable('tn-standings-table-<?= $stBid ?>',7,true)">Pts</th>
							</tr>
						</thead>
						<tbody>
							<?php foreach ($stRows as $stRow): ?>
							<tr>
								<td style="color:#a0aec0;font-weight:700"><?= (int)$stRow['Rank'] ?></td>
								<td style="font-weight:600"><?= htmlspecialchars($stRow['Alias'] ?? '—') ?></td>
								<td style="color:#718096"><?= htmlspecialchars($stRow['ParkName'] ?? '—') ?></td>
								<td style="text-align:center;color:#276749;font-weight:700"><?= (int)$stRow['Wins'] ?></td>
								<td style="text-align:center;color:#e53e3e"><?= (int)$stRow['Losses'] ?></td>
								<td style="text-align:center;color:#718096"><?= (int)$stRow['Ties'] ?></td>
								<td style="text-align:center;color:#a0aec0"><?= (int)$stRow['Byes'] ?></td>
								<td style="text-align:right;font-weight:800;color:#1a202c"><?= (int)$stRow['Points'] ?></td>
							</tr>
							<?php endforeach; ?>
						</tbody>
					</table>
					<?php endif; ?>
				</div>
				<?php endforeach; ?>
			</div>
			<?php endif; ?>

		</div><!-- /.tn-tabs -->
	</div><!-- /.tn-main -->

</div><!-- /.tn-layout -->


<?php if ($canManage): ?>
<!-- =============================================
     Add Bracket Modal
     ============================================= -->
<div class="tn-overlay" id="tn-addbracket-overlay">
	<div class="tn-modal-box" style="width:520px;max-width:calc(100vw - 40px)">
		<div class="tn-modal-header">
			<h3 class="tn-modal-title"><i class="fas fa-sitemap" style="margin-right:8px;color:#276749"></i>Add Bracket</h3>
			<button class="tn-modal-close" id="tn-addbracket-close">&times;</button>
		</div>
		<div class="tn-modal-body">
			<div id="tn-addbracket-feedback" class="tn-feedback"></div>
			<div class="tn-field-row">
				<div class="tn-field">
					<label for="tn-addbracket-style">Weapon Style <span style="color:#e53e3e">*</span></label>
					<select id="tn-addbracket-style">
						<option value="Single Sword">Single Sword</option>
						<option value="Florentine">Florentine</option>
						<option value="Sword and Shield">Sword &amp; Shield</option>
						<option value="Great Weapon">Great Weapon</option>
						<option value="Missile">Missile</option>
						<option value="Jugging">Jugging</option>
						<option value="Battlegame">Battlegame</option>
						<option value="Quest">Quest</option>
						<option value="Other">Other / Open</option>
					</select>
				</div>
				<div class="tn-field">
					<label for="tn-addbracket-method">Format <span style="color:#e53e3e">*</span></label>
					<select id="tn-addbracket-method">
						<option value="single">Single Elimination</option>
						<option value="double">Double Elimination</option>
						<option value="swiss">Swiss</option>
						<option value="round-robin">Round Robin</option>
						<option value="ironman">Ironman</option>
						<option value="score">Score</option>
					</select>
				</div>
			</div>
			<div class="tn-field-row">
				<div class="tn-field">
					<label for="tn-addbracket-participants">Participants</label>
					<select id="tn-addbracket-participants">
						<option value="individual">Individual</option>
						<option value="team">Team</option>
					</select>
				</div>
				<div class="tn-field">
					<label for="tn-addbracket-rings">Rings (concurrent)</label>
					<input type="number" id="tn-addbracket-rings" value="1" min="1" max="20">
				</div>
			</div>
			<div class="tn-field">
				<label for="tn-addbracket-seeding">Seeding</label>
				<select id="tn-addbracket-seeding">
					<option value="random">Random</option>
					<option value="manual">Manual</option>
					<option value="glicko2">Performance Score</option>
					<option value="random-manual">Random + Manual Adjust</option>
					<option value="glicko2-manual">Performance + Manual Adjust</option>
				</select>
			</div>
			<div class="tn-field">
				<label for="tn-addbracket-stylenote">Style Note <span style="color:#a0aec0;font-size:11px;font-weight:400">(optional)</span></label>
				<input type="text" id="tn-addbracket-stylenote" placeholder="e.g. No shields allowed, florentine only…" maxlength="255">
			</div>
		</div>
		<div class="tn-modal-footer">
			<button class="tn-btn tn-btn-ghost" id="tn-addbracket-cancel">Cancel</button>
			<button class="tn-btn tn-btn-primary" id="tn-addbracket-submit">
				<i class="fas fa-plus"></i> Add Bracket
			</button>
		</div>
	</div>
</div>

<!-- =============================================
     Add Participant Modal
     ============================================= -->
<div class="tn-overlay" id="tn-addparticipant-overlay">
	<div class="tn-modal-box" style="width:480px;max-width:calc(100vw - 40px)">
		<div class="tn-modal-header">
			<h3 class="tn-modal-title"><i class="fas fa-user-plus" style="margin-right:8px;color:#276749"></i>Add Participant</h3>
			<button class="tn-modal-close" id="tn-addparticipant-close">&times;</button>
		</div>
		<div class="tn-modal-body">
			<div id="tn-addparticipant-feedback" class="tn-feedback"></div>
			<input type="hidden" id="tn-addparticipant-bracket-id" value="">
			<input type="hidden" id="tn-addparticipant-tournament-id" value="<?= $tid ?>">
			<div class="tn-field">
				<label>Player <span style="color:#a0aec0;font-size:11px;font-weight:400">(search to auto-fill name)</span></label>
				<div style="position:relative">
					<input type="text" id="tn-addparticipant-player-text" placeholder="Search by persona…" autocomplete="off">
					<input type="hidden" id="tn-addparticipant-player-id" value="0">
					<div id="tn-addparticipant-player-results" class="tn-ac-results"></div>
				</div>
			</div>
			<div class="tn-field">
				<label for="tn-addparticipant-alias">Alias / Fighter Name <span style="color:#e53e3e">*</span></label>
				<input type="text" id="tn-addparticipant-alias" placeholder="Name as it appears in the bracket" maxlength="100">
			</div>
		</div>
		<div class="tn-modal-footer">
			<button class="tn-btn tn-btn-ghost" id="tn-addparticipant-cancel">Cancel</button>
			<button class="tn-btn tn-btn-primary" id="tn-addparticipant-submit">
				<i class="fas fa-user-plus"></i> Add Participant
			</button>
		</div>
	</div>
</div>
<?php endif; ?>


<!-- =============================================
     Record Result Modal
     ============================================= -->
<div class="tn-overlay" id="tn-recordresult-overlay">
	<div class="tn-modal-box" style="width:460px;max-width:calc(100vw - 40px)">
		<div class="tn-modal-header">
			<h3 class="tn-modal-title"><i class="fas fa-check-circle" style="margin-right:8px;color:#276749"></i>Record Result</h3>
			<button class="tn-modal-close" id="tn-recordresult-close">&times;</button>
		</div>
		<div class="tn-modal-body">
			<div id="tn-recordresult-feedback" class="tn-feedback"></div>
			<input type="hidden" id="tn-recordresult-match-id" value="">
			<input type="hidden" id="tn-recordresult-tournament-id" value="<?= $tid ?>">
			<div style="background:#f7fafc;border:1px solid #e2e8f0;border-radius:8px;padding:12px 14px;margin-bottom:14px">
				<div style="display:flex;align-items:center;justify-content:space-between;gap:10px">
					<div id="tn-rr-p1-name" style="font-size:14px;font-weight:700;color:#1a202c;flex:1;text-align:center">—</div>
					<div style="font-size:12px;color:#a0aec0;font-weight:600">vs</div>
					<div id="tn-rr-p2-name" style="font-size:14px;font-weight:700;color:#1a202c;flex:1;text-align:center">—</div>
				</div>
				<div id="tn-rr-round-info" style="text-align:center;font-size:11px;color:#a0aec0;margin-top:6px"></div>
			</div>
			<div class="tn-field">
				<label for="tn-rr-result">Result <span style="color:#e53e3e">*</span></label>
				<select id="tn-rr-result">
					<option value="">— select —</option>
					<option value="1-wins">Player 1 Wins</option>
					<option value="2-wins">Player 2 Wins</option>
					<option value="tie">Tie</option>
					<option value="forfeit">Forfeit (P2 wins)</option>
					<option value="disqualified">Disqualified (P2 wins)</option>
				</select>
			</div>
			<div class="tn-field">
				<label for="tn-rr-score">Score <span style="color:#a0aec0;font-size:11px;font-weight:400">(optional)</span></label>
				<input type="text" id="tn-rr-score" placeholder="e.g. 3-1" maxlength="50">
			</div>
		</div>
		<div class="tn-modal-footer">
			<button class="tn-btn tn-btn-ghost" id="tn-recordresult-cancel">Cancel</button>
			<button class="tn-btn tn-btn-primary" id="tn-recordresult-submit">
				<i class="fas fa-check"></i> Save Result
			</button>
		</div>
	</div>
</div>


<!-- =============================================
     Config + Scripts
     ============================================= -->
<script>
var TnConfig = {
	uir:          '<?= UIR ?>',
	httpService:  '<?= HTTP_SERVICE ?>',
	tournamentId: <?= $tid ?>,
	kingdomId:    <?= $tKingdomId ?>,
	canManage:    <?= $canManage ? 'true' : 'false' ?>,
	loggedIn:     <?= $loggedIn ? 'true' : 'false' ?>,
	bracketData:  <?= json_encode($bracketData) ?>,
	methodLabels: <?= json_encode($methodLabelMap) ?>,
	styleLabels:  <?= json_encode($styleLabelMap) ?>,
};
</script>

<script src="<?= HTTP_TEMPLATE ?>revised-frontend/script/revised.js?v=<?= filemtime(__DIR__ . '/script/revised.js') ?>"></script>

<script>
// ---- Tab switching ----
function tnActivateTab(name) {
	document.querySelectorAll('#tn-tab-nav li').forEach(function(li) {
		li.classList.toggle('tn-tab-active', li.dataset.tntab === name);
	});
	document.querySelectorAll('.tn-tab-panel').forEach(function(p) {
		p.style.display = p.id === 'tn-tab-' + name ? '' : 'none';
	});
}

function tnScrollToBracket(bracketId) {
	var el = document.getElementById('tn-bracket-' + bracketId);
	if (el) { setTimeout(function() { el.scrollIntoView({behavior:'smooth',block:'start'}); }, 80); }
}

// ---- Modal helpers ----
function tnEsc(s) { return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;'); }

function tnRemoveParticipant(btn) {
	if (!confirm('Remove this participant?')) return;
	var pid = btn.dataset.pid;
	var bid = btn.dataset.bid;
	var tid = btn.dataset.tid;
	var fd = new FormData();
	fd.append('ParticipantId', pid);
	fd.append('TournamentId',  tid);
	fetch(TnConfig.uir + 'TournamentAjax/bracket/' + bid + '/removeparticipant', {method:'POST', body:fd})
		.then(function(r){ return r.json(); })
		.then(function(r){
			if (r.status === 0) {
				var li = btn.closest('li');
				var ul = li.parentNode;
				li.remove();
				ul.querySelectorAll('li').forEach(function(item, i) {
					var seed = item.querySelector('.tn-participant-seed');
					if (seed) seed.textContent = i + 1;
				});
				var card = document.getElementById('tn-bracket-' + bid);
				if (card) {
					var remaining = ul.querySelectorAll('li').length;
					card.querySelectorAll('span').forEach(function(s) {
						if (/\d+ participant/.test(s.textContent)) s.textContent = remaining + ' participant' + (remaining !== 1 ? 's' : '');
					});
				}
			} else {
				alert('Error: ' + (r.error || 'Could not remove participant.'));
			}
		})
		.catch(function(){ alert('Network error removing participant.'); });
}
function tnOpenModal(id) {
	var ov = document.getElementById(id);
	if (ov) ov.classList.add('tn-open');
}
function tnCloseModal(id) {
	var ov = document.getElementById(id);
	if (ov) ov.classList.remove('tn-open');
}
function tnShowFeedback(elId, msg, ok) {
	var el = document.getElementById(elId);
	if (!el) return;
	el.textContent = msg;
	el.className = 'tn-feedback ' + (ok ? 'tn-feedback-ok' : 'tn-feedback-err');
	el.style.display = 'block';
}
function tnHideFeedback(elId) {
	var el = document.getElementById(elId);
	if (el) el.style.display = 'none';
}

<?php if ($canManage): ?>
// ---- Add Bracket Modal ----
(function() {
	var OVERLAY = 'tn-addbracket-overlay';
	var ADD_URL = TnConfig.uir + 'TournamentAjax/tournament/' + TnConfig.tournamentId + '/addbracket';

	window.tnOpenAddBracketModal = function() {
		tnHideFeedback('tn-addbracket-feedback');
		tnOpenModal(OVERLAY);
	};

	['tn-addbracket-close','tn-addbracket-cancel'].forEach(function(id) {
		var el = document.getElementById(id);
		if (el) el.addEventListener('click', function() { tnCloseModal(OVERLAY); });
	});

	var ov = document.getElementById(OVERLAY);
	if (ov) {
		ov.addEventListener('click', function(e) { if (e.target === ov) tnCloseModal(OVERLAY); });
	}

	document.addEventListener('keydown', function(e) {
		if (e.key === 'Escape' && ov && ov.classList.contains('tn-open')) tnCloseModal(OVERLAY);
	});

	var submitBtn = document.getElementById('tn-addbracket-submit');
	if (submitBtn) {
		submitBtn.addEventListener('click', function() {
			var btn   = this;
			var style = document.getElementById('tn-addbracket-style').value;
			var method = document.getElementById('tn-addbracket-method').value;
			if (!style || !method) { tnShowFeedback('tn-addbracket-feedback', 'Style and format are required.', false); return; }

			btn.disabled = true;
			var fd = new FormData();
			fd.append('Style',        style);
			fd.append('Method',       method);
			fd.append('Participants', document.getElementById('tn-addbracket-participants').value);
			fd.append('Rings',        document.getElementById('tn-addbracket-rings').value);
			fd.append('Seeding',      document.getElementById('tn-addbracket-seeding').value);
			fd.append('StyleNote',    document.getElementById('tn-addbracket-stylenote').value);

			fetch(ADD_URL, { method:'POST', body:fd })
				.then(function(r) { return r.json(); })
				.then(function(d) {
					btn.disabled = false;
					if (d && d.status === 0) {
						tnShowFeedback('tn-addbracket-feedback', 'Bracket added!', true);
						setTimeout(function() { tnCloseModal(OVERLAY); window.location.reload(); }, 800);
					} else {
						tnShowFeedback('tn-addbracket-feedback', (d && d.error) ? d.error : 'Failed to add bracket.', false);
					}
				})
				.catch(function() { btn.disabled = false; tnShowFeedback('tn-addbracket-feedback', 'Request failed. Please try again.', false); });
		});
	}
})();

// ---- Add Participant Modal ----
(function() {
	var OVERLAY      = 'tn-addparticipant-overlay';
	var playerTimer;
	var _addedCount  = 0;

	window.tnOpenAddParticipantModal = function(bracketId, tournamentId) {
		document.getElementById('tn-addparticipant-bracket-id').value    = bracketId;
		document.getElementById('tn-addparticipant-tournament-id').value = tournamentId;
		document.getElementById('tn-addparticipant-alias').value         = '';
		document.getElementById('tn-addparticipant-player-text').value   = '';
		document.getElementById('tn-addparticipant-player-id').value     = '0';
		tnAcClose();
		tnHideFeedback('tn-addparticipant-feedback');
		tnOpenModal(OVERLAY);
	};

	// Backdrop click — also reload if participants were added
	var ov = document.getElementById(OVERLAY);
	if (ov) {
		ov.addEventListener('click', function(e) {
			if (e.target === ov) {
				tnCloseModal(OVERLAY);
				if (_addedCount > 0) { _addedCount = 0; window.location.reload(); }
			}
		});
	}

	// Player autocomplete — kingdom-scoped first, global SOAP fallback
	var playerInput = document.getElementById('tn-addparticipant-player-text');
	var playerIdEl  = document.getElementById('tn-addparticipant-player-id');
	var resultsEl   = document.getElementById('tn-addparticipant-player-results');

	function tnAcClose() {
		if (!resultsEl) return;
		resultsEl.classList.remove('tn-ac-open');
		resultsEl.innerHTML = '';
	}

	function tnAcRender(players) {
		resultsEl.innerHTML = '';
		if (!players || !players.length) {
			resultsEl.innerHTML = '<div class="tn-ac-item tn-ac-empty">No players found</div>';
			resultsEl.classList.add('tn-ac-open');
			return;
		}
		players.forEach(function(pl) {
			var item = document.createElement('div');
			item.className = 'tn-ac-item';
			item.tabIndex = -1;
			var label = tnEsc(pl.Persona || pl.Name || '');
			var sub   = pl.KAbbr ? (' <span style="color:#a0aec0;font-size:11px">(' + tnEsc(pl.KAbbr) + (pl.PAbbr ? ':' + tnEsc(pl.PAbbr) : '') + ')</span>') : '';
			item.innerHTML = label + sub;
			item.addEventListener('mousedown', function(e) {
				e.preventDefault();
				var name = pl.Persona || pl.Name || '';
				playerInput.value = name;
				playerIdEl.value  = pl.MundaneId || pl.mundane_id || 0;
				// Always auto-fill alias (user can adjust)
				var aliasEl = document.getElementById('tn-addparticipant-alias');
				if (aliasEl) { aliasEl.value = name; }
				tnAcClose();
			});
			resultsEl.appendChild(item);
		});
		resultsEl.classList.add('tn-ac-open');
	}

	if (playerInput && resultsEl) {
		playerInput.addEventListener('input', function() {
			var term = this.value.trim();
			playerIdEl.value = '0';
			clearTimeout(playerTimer);
			if (term.length < 2) { tnAcClose(); return; }
			playerTimer = setTimeout(function() {
				if (TnConfig.kingdomId > 0) {
					// Kingdom-scoped search (same endpoint as award modals)
					var url = TnConfig.uir + 'KingdomAjax/playersearch/' + TnConfig.kingdomId + '&q=' + encodeURIComponent(term);
					fetch(url)
						.then(function(r) { return r.json(); })
						.then(function(data) { tnAcRender(data); })
						.catch(function(err) {
							console.error('[AddParticipant] kingdom search failed:', err);
							tnAcClose();
						});
				} else {
					// Fallback: global SOAP persona search
					var url = TnConfig.httpService + 'Search/SearchService.php?Action=Search%2FPlayer&type=PERSONA&search=' + encodeURIComponent(term) + '&limit=10';
					fetch(url)
						.then(function(r) { return r.json(); })
						.then(function(data) { tnAcRender(data.Players || data.Results || []); })
						.catch(function(err) {
							console.error('[AddParticipant] global search failed:', err);
							tnAcClose();
						});
				}
			}, 280);
		});
		playerInput.addEventListener('blur', function() {
			setTimeout(tnAcClose, 200);
		});
	}

	function tnResetAddParticipantForm() {
		document.getElementById('tn-addparticipant-alias').value       = '';
		document.getElementById('tn-addparticipant-player-text').value = '';
		document.getElementById('tn-addparticipant-player-id').value   = '0';
		tnAcClose();
		if (playerInput) { setTimeout(function() { playerInput.focus(); }, 50); }
	}

	// Reload on close if participants were added
	['tn-addparticipant-close','tn-addparticipant-cancel'].forEach(function(id) {
		var el = document.getElementById(id);
		if (el) el.addEventListener('click', function() {
			tnCloseModal(OVERLAY);
			if (_addedCount > 0) { _addedCount = 0; window.location.reload(); }
		});
	});

	// Submit
	var submitBtn = document.getElementById('tn-addparticipant-submit');
	if (submitBtn) {
		submitBtn.addEventListener('click', function() {
			var btn          = this;
			var alias        = document.getElementById('tn-addparticipant-alias').value.trim();
			var bracketId    = document.getElementById('tn-addparticipant-bracket-id').value;
			var tournamentId = document.getElementById('tn-addparticipant-tournament-id').value;
			var mundaneId    = document.getElementById('tn-addparticipant-player-id').value;

			if (!alias) { tnShowFeedback('tn-addparticipant-feedback', 'Alias is required.', false); return; }

			var ADD_URL = TnConfig.uir + 'TournamentAjax/bracket/' + bracketId + '/addparticipant';
			btn.disabled = true;
			var fd = new FormData();
			fd.append('Alias',        alias);
			fd.append('MundaneId',    mundaneId);
			fd.append('TournamentId', tournamentId);

			fetch(ADD_URL, { method:'POST', body:fd })
				.then(function(r) { return r.json(); })
				.then(function(d) {
					btn.disabled = false;
					if (d && d.status === 0) {
						_addedCount++;
						tnShowFeedback('tn-addparticipant-feedback', 'Added! (' + _addedCount + ' so far) Keep adding, or close when done.', true);
						// Update bracket card DOM in-place
						var card = document.getElementById('tn-bracket-' + bracketId);
						if (card) {
							var emptyEl = card.querySelector('.tn-bracket-body .tn-empty');
							if (emptyEl) emptyEl.remove();
							var ul = card.querySelector('.tn-participant-list');
							if (!ul) {
								ul = document.createElement('ul');
								ul.className = 'tn-participant-list';
								var body = card.querySelector('.tn-bracket-body');
								if (body) body.insertBefore(ul, body.firstChild);
							}
							var num = ul.querySelectorAll('li').length + 1;
							var li = document.createElement('li');
							li.innerHTML = '<span class="tn-participant-seed">' + num + '</span><span style="flex:1">' + tnEsc(alias) + '</span>' + (TnConfig.canManage ? '<button class="tn-remove-participant" data-pid="' + (d.participantId || 0) + '" data-bid="' + bracketId + '" data-tid="' + TnConfig.tournamentId + '" title="Remove participant" onclick="tnRemoveParticipant(this)">&times;</button>' : '');
							ul.appendChild(li);
							var hdr = card.querySelector('.tn-bracket-header');
							if (hdr) { hdr.querySelectorAll('span').forEach(function(s) { if (/\d+ participant/.test(s.textContent)) s.textContent = num + ' participant' + (num !== 1 ? 's' : ''); }); }
						}
						tnResetAddParticipantForm();
					} else {
						console.error('[AddParticipant] server error:', d);
						tnShowFeedback('tn-addparticipant-feedback', (d && d.error) ? d.error : 'Failed to add participant.', false);
					}
				})
				.catch(function(err) {
					btn.disabled = false;
					console.error('[AddParticipant] fetch failed:', err);
					tnShowFeedback('tn-addparticipant-feedback', 'Request failed. Please try again.', false);
				});
		});
	}
})();
<?php endif; ?>

// ============================================================
// Standings: bracket selector + sortable columns
// ============================================================
window.tnShowStandings = function(bracketId) {
	document.querySelectorAll('.tn-standings-section').forEach(function(s) {
		s.style.display = parseInt(s.dataset.stbid) === bracketId ? '' : 'none';
	});
};

window.tnSortTable = function(tableId, colIndex, numeric) {
	var tbl = document.getElementById(tableId);
	if (!tbl) return;
	var tbody = tbl.querySelector('tbody');
	var rows = Array.prototype.slice.call(tbody.querySelectorAll('tr'));
	var asc = tbl.dataset.sortCol == colIndex && tbl.dataset.sortDir !== 'asc';
	tbl.dataset.sortCol = colIndex;
	tbl.dataset.sortDir = asc ? 'asc' : 'desc';
	rows.sort(function(a, b) {
		var av = a.cells[colIndex] ? a.cells[colIndex].textContent.trim() : '';
		var bv = b.cells[colIndex] ? b.cells[colIndex].textContent.trim() : '';
		if (numeric) { av = parseFloat(av) || 0; bv = parseFloat(bv) || 0; return asc ? av - bv : bv - av; }
		return asc ? av.localeCompare(bv) : bv.localeCompare(av);
	});
	rows.forEach(function(r) { tbody.appendChild(r); });
	// update sort icons
	tbl.querySelectorAll('th').forEach(function(th, i) {
		th.style.color = i === colIndex ? '#276749' : '';
	});
};

// ============================================================
// Phase 7: Drag-and-drop seed reorder
// ============================================================
(function() {
	var dragSrc = null;

	function initDnd(list, bracketId) {
		var items = list.querySelectorAll('li[data-pid]');
		items.forEach(function(li) {
			li.setAttribute('draggable', 'true');
			li.style.cursor = 'grab';

			li.addEventListener('dragstart', function(e) {
				dragSrc = li;
				e.dataTransfer.effectAllowed = 'move';
				li.style.opacity = '0.5';
			});
			li.addEventListener('dragend', function() {
				li.style.opacity = '';
				list.querySelectorAll('li[data-pid]').forEach(function(i) { i.classList.remove('tn-dnd-over'); });
			});
			li.addEventListener('dragover', function(e) {
				e.preventDefault();
				e.dataTransfer.dropEffect = 'move';
				if (li !== dragSrc) li.classList.add('tn-dnd-over');
			});
			li.addEventListener('dragleave', function() { li.classList.remove('tn-dnd-over'); });
			li.addEventListener('drop', function(e) {
				e.preventDefault();
				li.classList.remove('tn-dnd-over');
				if (!dragSrc || dragSrc === li) return;
				// Insert dragSrc before this element
				var allItems = Array.prototype.slice.call(list.querySelectorAll('li[data-pid]'));
				var srcIdx = allItems.indexOf(dragSrc);
				var dstIdx = allItems.indexOf(li);
				if (srcIdx < dstIdx) list.insertBefore(dragSrc, li.nextSibling);
				else                 list.insertBefore(dragSrc, li);
				// Update seed number badges
				var newOrder = [];
				list.querySelectorAll('li[data-pid]').forEach(function(item, idx) {
					item.querySelector('.tn-participant-seed').textContent = idx + 1;
					newOrder.push(item.dataset.pid);
				});
				// Save new order
				var url = TnConfig.uir + 'TournamentAjax/bracket/' + bracketId + '/reorder';
				var fd  = new FormData();
				fd.append('Order', JSON.stringify(newOrder));
				fetch(url, { method:'POST', body:fd }).then(function(r) { return r.json(); }).then(function(d) {
					if (!d || d.status !== 0) console.warn('Reorder save failed', d);
				}).catch(function(e) { console.warn('Reorder error', e); });
			});
		});
	}

	document.addEventListener('DOMContentLoaded', function() {
		document.querySelectorAll('.tn-dnd-list').forEach(function(list) {
			var bracketId = parseInt(list.dataset.bracketId);
			initDnd(list, bracketId);
		});
	});
})();

// ============================================================
// Bracket Generation
// ============================================================
window.tnGenerateMatches = function(bracketId, tournamentId) {
	if (!TnConfig.canManage) return;
	if (!confirm('Generate matches for this bracket? Any existing matches will be replaced.')) return;

	var url = TnConfig.uir + 'TournamentAjax/tournament/' + tournamentId + '/generate';
	var fd  = new FormData();
	fd.append('BracketId', bracketId);

	fetch(url, { method:'POST', body:fd })
		.then(function(r) { return r.json(); })
		.then(function(d) {
			if (d && d.status === 0) {
				window.location.reload();
			} else {
				alert((d && d.error) ? d.error : 'Failed to generate matches.');
			}
		})
		.catch(function() { alert('Request failed. Please try again.'); });
};

// ============================================================
// Bracket Visualization
// ============================================================
(function() {
	// Find first bracket id with matches, or first bracket
	function firstBracketId() {
		var bd = TnConfig.bracketData;
		// prefer one with matches
		for (var bid in bd) {
			if (bd.hasOwnProperty(bid) && bd[bid].Matches && bd[bid].Matches.length > 0) return parseInt(bid);
		}
		for (var bid in bd) { if (bd.hasOwnProperty(bid)) return parseInt(bid); }
		return 0;
	}

	window.tnRenderBracketViz = function(bracketId) {
		var container = document.getElementById('tn-bv-container');
		if (!container) return;
		container.innerHTML = '';

		var bd = TnConfig.bracketData[bracketId];
		if (!bd) { container.innerHTML = '<div class="tn-bv-empty">Bracket not found.</div>'; return; }

		var bracket      = bd.Bracket;
		var matches      = bd.Matches  || [];
		var participants = bd.Participants || [];
		var method       = bracket.Method;

		// Participant lookup by id
		var pMap = {};
		participants.forEach(function(p) { pMap[p.ParticipantId] = p; });

		// Generate button bar
		if (TnConfig.canManage) {
			var bar = document.createElement('div');
			bar.className = 'tn-bv-generate-bar';
			var statusBadge = document.createElement('span');
			statusBadge.className = 'tn-bv-status-badge tn-bv-status-' + (bracket.Status || 'setup');
			statusBadge.textContent = (bracket.Status || 'setup').charAt(0).toUpperCase() + (bracket.Status || 'setup').slice(1);
			bar.appendChild(statusBadge);
			var label = document.createElement('span');
			label.style.cssText = 'font-size:13px;color:#4a5568;flex:1';
			label.textContent = (TnConfig.styleLabels[bracket.Style] || bracket.Style) + ' — ' + (TnConfig.methodLabels[bracket.Method] || bracket.Method);
			bar.appendChild(label);
			if (participants.length >= 2) {
				var genBtn = document.createElement('button');
				genBtn.className = 'tn-btn tn-btn-primary tn-btn-sm';
				genBtn.innerHTML = '<i class="fas fa-play"></i> ' + (matches.length > 0 ? 'Regenerate' : 'Generate Matches');
				genBtn.onclick = function() { tnGenerateMatches(bracketId, TnConfig.tournamentId); };
				bar.appendChild(genBtn);
			}
			container.appendChild(bar);
		}

		if (matches.length === 0) {
			var empty = document.createElement('div');
			empty.className = 'tn-bv-empty';
			empty.textContent = participants.length < 2
				? 'Add at least 2 participants to generate a bracket.'
				: 'No matches yet. Click "Generate Matches" to build the bracket.';
			container.appendChild(empty);
			return;
		}

		// Route to correct renderer
		if (method === 'single' || method === 'double') {
			renderElimTree(container, matches, pMap, method);
		} else {
			renderRoundTable(container, matches, pMap);
		}
	};

	// ── Elimination tree renderer ──
	function renderElimTree(container, matches, pMap, method) {
		var wrap = document.createElement('div');
		wrap.className = 'tn-bv-wrap';
		container.appendChild(wrap);

		// Separate sections: winners, losers, grand-final
		var sections = [
			{ key:'winners',     label:'Winners Bracket' },
			{ key:'losers',      label:'Losers Bracket' },
			{ key:'grand-final', label:'Grand Final' },
		];

		var hasSections = matches.some(function(m) { return m.BracketSide && m.BracketSide !== 'winners'; });

		if (!hasSections) {
			// Single section
			renderSection(wrap, matches, pMap, null);
		} else {
			sections.forEach(function(s) {
				var sMatches = matches.filter(function(m) { return (m.BracketSide || 'winners') === s.key; });
				if (!sMatches.length) return;
				var lbl = document.createElement('div');
				lbl.className = 'tn-bv-section-label';
				lbl.textContent = s.label;
				wrap.appendChild(lbl);
				renderSection(wrap, sMatches, pMap, s.key);
			});
		}
	}

	function renderSection(wrap, matches, pMap, side) {
		// Group by round
		var rounds = {};
		var maxRound = 0;
		matches.forEach(function(m) {
			var r = parseInt(m.Round) || 1;
			if (!rounds[r]) rounds[r] = [];
			rounds[r].push(m);
			if (r > maxRound) maxRound = r;
		});

		var tree = document.createElement('div');
		tree.className = 'tn-bv-tree';

		for (var r = 1; r <= maxRound; r++) {
			var rMatches = (rounds[r] || []).sort(function(a,b) { return (a.Order||0)-(b.Order||0); });
			var col = document.createElement('div');
			col.className = 'tn-bv-round';
			var lbl = document.createElement('div');
			lbl.className = 'tn-bv-round-label';
			if (side === 'grand-final') {
				lbl.textContent = 'Grand Final';
			} else if (maxRound === 1) {
				lbl.textContent = 'Final';
			} else if (r === maxRound) {
				lbl.textContent = 'Final';
			} else if (r === maxRound - 1) {
				lbl.textContent = 'Semifinal';
			} else {
				lbl.textContent = 'Round ' + r;
			}
			col.appendChild(lbl);

			rMatches.forEach(function(m) {
				col.appendChild(buildMatchBox(m, pMap));
			});
			tree.appendChild(col);
		}
		wrap.appendChild(tree);
	}

	function buildMatchBox(m, pMap) {
		var p1Id = parseInt(m.Participant1Id) || 0;
		var p2Id = parseInt(m.Participant2Id) || 0;
		var p1   = p1Id ? (pMap[p1Id] || null) : null;
		var p2   = p2Id ? (pMap[p2Id] || null) : null;
		var hasResult = m.Result && m.Result !== '';
		var isClickable = !hasResult && p1 && p2 && TnConfig.canManage;

		var box = document.createElement('div');
		box.className = 'tn-bv-match';
		if (isClickable) box.className += ' tn-bv-clickable';
		if (hasResult)   box.className += ' tn-bv-resolved';

		[
			{ pid:p1Id, p:p1, slot:1 },
			{ pid:p2Id, p:p2, slot:2 },
		].forEach(function(info) {
			var slot = document.createElement('div');
			slot.className = 'tn-bv-slot';

			if (hasResult) {
				var w = (m.Result === '1-wins' && info.slot === 1) || (m.Result === '2-wins' && info.slot === 2);
				if (w) slot.classList.add('tn-bv-winner');
				else   slot.classList.add('tn-bv-loser');
			}

			if (!info.pid) {
				slot.classList.add('tn-bv-bye');
				slot.innerHTML = '<span class="tn-bv-seed">—</span><span>Bye</span>';
			} else if (!info.p) {
				slot.innerHTML = '<span class="tn-bv-seed">?</span><span style="color:#a0aec0">TBD</span>';
			} else {
				var seed = document.createElement('span');
				seed.className = 'tn-bv-seed';
				seed.textContent = info.p.Seed || '?';
				slot.appendChild(seed);
				var name = document.createElement('span');
				name.textContent = info.p.Alias || info.p.Persona || '—';
				slot.appendChild(name);
				if (hasResult && info.slot === 1 && (m.Result === '1-wins')) {
					var pill = document.createElement('span');
					pill.className = 'tn-bv-result-pill';
					pill.textContent = 'W';
					slot.appendChild(pill);
				} else if (hasResult && info.slot === 2 && (m.Result === '2-wins')) {
					var pill = document.createElement('span');
					pill.className = 'tn-bv-result-pill';
					pill.textContent = 'W';
					slot.appendChild(pill);
				}
			}
			box.appendChild(slot);
		});

		if (hasResult && m.Score) {
			var scoreEl = document.createElement('div');
			scoreEl.style.cssText = 'font-size:10px;color:#718096;text-align:center;padding:3px 8px;border-top:1px solid #e2e8f0;background:#f7fafc';
			scoreEl.textContent = m.Score;
			box.appendChild(scoreEl);
		}

		if (isClickable) {
			box.addEventListener('click', function() {
				tnOpenRecordResult(m, p1, p2);
			});
		}
		return box;
	}

	// ── Round-table renderer (Swiss / Round Robin / Ironman) ──
	function renderRoundTable(container, matches, pMap) {
		var rounds = {};
		var maxRound = 0;
		matches.forEach(function(m) {
			var r = parseInt(m.Round) || 1;
			if (!rounds[r]) rounds[r] = [];
			rounds[r].push(m);
			if (r > maxRound) maxRound = r;
		});

		// Round nav buttons
		var nav = document.createElement('div');
		nav.className = 'tn-bv-round-nav';
		var activeRound = 1;

		for (var r = 1; r <= maxRound; r++) {
			(function(round) {
				var btn = document.createElement('button');
				btn.className = 'tn-bv-round-btn' + (round === 1 ? ' active' : '');
				btn.textContent = 'Round ' + round;
				btn.dataset.round = round;
				btn.addEventListener('click', function() {
					nav.querySelectorAll('.tn-bv-round-btn').forEach(function(b) { b.classList.remove('active'); });
					btn.classList.add('active');
					container.querySelectorAll('.tn-bv-round-section').forEach(function(s) {
						s.style.display = parseInt(s.dataset.round) === round ? '' : 'none';
					});
				});
				nav.appendChild(btn);
			})(r);
		}
		container.appendChild(nav);

		for (var r = 1; r <= maxRound; r++) {
			var section = document.createElement('div');
			section.className = 'tn-bv-round-section';
			section.dataset.round = r;
			section.style.display = r === 1 ? '' : 'none';

			var tbl = document.createElement('table');
			tbl.className = 'tn-bv-tbl';
			tbl.innerHTML = '<thead><tr><th>#</th><th>Participant 1</th><th>Result</th><th>Participant 2</th><th>Score</th></tr></thead>';
			var tbody = document.createElement('tbody');

			var rMatches = (rounds[r] || []).sort(function(a,b) { return (a.Order||0)-(b.Order||0); });
			rMatches.forEach(function(m) {
				var p1 = parseInt(m.Participant1Id) ? (pMap[m.Participant1Id] || null) : null;
				var p2 = parseInt(m.Participant2Id) ? (pMap[m.Participant2Id] || null) : null;
				var hasResult = m.Result && m.Result !== '';
				var isClickable = !hasResult && p1 && p2 && TnConfig.canManage;

				var tr = document.createElement('tr');
				if (isClickable) tr.className = 'tn-bv-clickable';
				tr.innerHTML =
					'<td style="color:#a0aec0">' + (m.Match||m.Order||'') + '</td>' +
					'<td style="font-weight:' + (hasResult && m.Result==='1-wins'?'700':'400') + ';color:' + (hasResult && m.Result==='1-wins'?'#276749':'inherit') + '">' + (p1 ? (p1.Alias||p1.Persona||'—') : (parseInt(m.Participant1Id)?'TBD':'Bye')) + '</td>' +
					'<td style="text-align:center;color:#718096">' + (m.Result || '—') + '</td>' +
					'<td style="font-weight:' + (hasResult && m.Result==='2-wins'?'700':'400') + ';color:' + (hasResult && m.Result==='2-wins'?'#276749':'inherit') + '">' + (p2 ? (p2.Alias||p2.Persona||'—') : (parseInt(m.Participant2Id)?'TBD':'Bye')) + '</td>' +
					'<td style="color:#a0aec0">' + (m.Score||'') + '</td>';

				if (isClickable) {
					tr.addEventListener('click', function() { tnOpenRecordResult(m, p1, p2); });
				}
				tbody.appendChild(tr);
			});
			tbl.appendChild(tbody);
			section.appendChild(tbl);
			container.appendChild(section);
		}
	}

	// Initialize on page load
	document.addEventListener('DOMContentLoaded', function() {
		var firstId = firstBracketId();
		if (firstId) tnRenderBracketViz(firstId);
	});

	// Also render when tab is clicked
	var origActivate = window.tnActivateTab;
	window.tnActivateTab = function(name) {
		origActivate(name);
		if (name === 'bracketviz') {
			var sel = document.getElementById('tn-bv-bracket-select');
			var bid = sel ? parseInt(sel.value) : firstBracketId();
			if (bid) tnRenderBracketViz(bid);
		}
	};
})();

// ============================================================
// Record Result Modal
// ============================================================
(function() {
	var OVERLAY = 'tn-recordresult-overlay';
	var currentMatch = null;

	window.tnOpenRecordResult = function(match, p1, p2) {
		currentMatch = match;
		document.getElementById('tn-recordresult-match-id').value = match.MatchId;
		document.getElementById('tn-rr-p1-name').textContent = p1 ? (p1.Alias || p1.Persona || '—') : '—';
		document.getElementById('tn-rr-p2-name').textContent = p2 ? (p2.Alias || p2.Persona || '—') : '—';
		document.getElementById('tn-rr-round-info').textContent = 'Round ' + match.Round + ', Match ' + (match.Match || '');
		document.getElementById('tn-rr-result').value = '';
		document.getElementById('tn-rr-score').value = '';
		tnHideFeedback('tn-recordresult-feedback');
		tnOpenModal(OVERLAY);
	};

	['tn-recordresult-close','tn-recordresult-cancel'].forEach(function(id) {
		var el = document.getElementById(id);
		if (el) el.addEventListener('click', function() { tnCloseModal(OVERLAY); });
	});

	var ov = document.getElementById(OVERLAY);
	if (ov) ov.addEventListener('click', function(e) { if (e.target === ov) tnCloseModal(OVERLAY); });

	var submitBtn = document.getElementById('tn-recordresult-submit');
	if (submitBtn) {
		submitBtn.addEventListener('click', function() {
			var btn       = this;
			var matchId   = document.getElementById('tn-recordresult-match-id').value;
			var tid       = document.getElementById('tn-recordresult-tournament-id').value;
			var result    = document.getElementById('tn-rr-result').value;
			var score     = document.getElementById('tn-rr-score').value;

			if (!result) { tnShowFeedback('tn-recordresult-feedback', 'Please select a result.', false); return; }

			var url = TnConfig.uir + 'TournamentAjax/match/' + matchId + '/' + tid;
			btn.disabled = true;
			var fd = new FormData();
			fd.append('Result', result);
			fd.append('Score',  score);

			fetch(url, { method:'POST', body:fd })
				.then(function(r) { return r.json(); })
				.then(function(d) {
					btn.disabled = false;
					if (d && d.status === 0) {
						tnShowFeedback('tn-recordresult-feedback', 'Result saved!', true);
						setTimeout(function() { tnCloseModal(OVERLAY); window.location.reload(); }, 700);
					} else {
						tnShowFeedback('tn-recordresult-feedback', (d && d.error) ? d.error : 'Failed to save result.', false);
					}
				})
				.catch(function() { btn.disabled = false; tnShowFeedback('tn-recordresult-feedback', 'Request failed.', false); });
		});
	}
})();
</script>
