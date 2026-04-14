<?php
// ---- Normalize controller data into clean local variables ----
$tournament        = $tournament        ?? [];
$brackets          = $brackets          ?? [];
$bracketData       = $bracket_data      ?? [];
$standingsData     = $standings_data    ?? [];
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
$tEventLabel  = $tournament_event_label ?? '';
$standingsPoints = $standings_points ?? [5,4,3,2,1,0,0,0];

$displayDate   = ($tDate && substr($tDate, 0, 10) !== '0000-00-00')
	? date('F j, Y', strtotime($tDate))
	: 'Date TBD';
$shortDate     = ($tDate && substr($tDate, 0, 10) !== '0000-00-00')
	? date('M j, Y', strtotime($tDate))
	: '—';

if (!function_exists('tnParticipantPills')) {
	function tnParticipantPills(array $p): string {
		$html = '';
		if (($p['WarriorCount'] ?? 0) > 0) {
			$wc = min((int)$p['WarriorCount'], 10);
			$html .= '<span class="tn-pill tn-pill-warrior" title="Order of the Warrior x' . (int)$p['WarriorCount'] . '">' . $wc . '</span>';
		}
		if (!empty($p['IsWarlord']))
			$html .= '<span class="tn-pill tn-pill-warlord" title="Warlord">W</span>';
		if (!empty($p['IsKnightSword']))
			$html .= '<span class="tn-pill tn-pill-knight" title="Knight of the Sword">K</span>';
		return $html ? '<span style="display:inline-flex;gap:3px;margin-left:4px;vertical-align:middle">' . $html . '</span>' : '';
	}
}
if (!function_exists('tnOrdinal')) {
	function tnOrdinal(int $n): string {
		$s = ['th','st','nd','rd'];
		$v = $n % 100;
		return $n . ($s[($v - 20) % 10] ?? $s[min($v, 3)] ?? 'th');
	}
}

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
.tn-bracket-card { border:1px solid #e2e8f0; border-radius:8px; margin-bottom:14px; overflow:hidden; border-left:4px solid #a0aec0; }
.tn-bracket-card[data-method="single"] { border-left-color:#276749; }
.tn-bracket-card[data-method="double"] { border-left-color:#2b6cb0; }
.tn-bracket-card[data-method="swiss"] { border-left-color:#d69e2e; }
.tn-bracket-card[data-method="round-robin"] { border-left-color:#9f7aea; }
.tn-bracket-card[data-method="ironman"] { border-left-color:#e53e3e; }
.tn-bracket-card[data-method="score"] { border-left-color:#718096; }
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
.tn-pill { display:inline-flex; align-items:center; justify-content:center; font-size:9px; font-weight:700; border-radius:10px; padding:1px 5px; line-height:1.4; letter-spacing:0.3px; flex-shrink:0; }
.tn-pill-warrior { background:#ebf8ff; color:#2b6cb0; border:1px solid #bee3f8; }
.tn-pill-warlord { background:#fff8e1; color:#b45309; border:1px solid #fcd34d; }
.tn-pill-knight  { background:#f0fff4; color:#276749; border:1px solid #9ae6b4; }
.tn-pill-complete { background:#f0fff4; color:#276749; border:1px solid #9ae6b4; font-size:11px; font-weight:600; padding:2px 8px; border-radius:10px; display:inline-flex; align-items:center; gap:4px; }
.tn-bracket-status { display:inline-flex; align-items:center; gap:4px; padding:2px 8px; border-radius:12px; font-size:11px; font-weight:600; line-height:1.4; }
.tn-bracket-status-setup { background:#edf2f7; color:#718096; }
.tn-bracket-status-active { background:#f0fff4; color:#276749; border:1px solid #c6f6d5; }
.tn-bracket-status-active i { animation: tn-pulse 1.5s ease-in-out infinite; }
@keyframes tn-pulse { 0%,100% { opacity:1; } 50% { opacity:0.4; } }
.tn-bracket-status-complete { background:#ebf8ff; color:#2b6cb0; border:1px solid #bee3f8; }
.tn-bracket-status-finalized { background:#faf5ff; color:#6b46c1; border:1px solid #e9d8fd; }
.tn-placement-list { list-style:none; padding:0; margin:0; }
.tn-placement-list li { display:flex; align-items:center; gap:8px; padding:5px 6px; border-bottom:1px solid #f0f4f8; }
.tn-placement-list li:last-child { border-bottom:none; }
.tn-placement-num { font-weight:700; color:#276749; min-width:34px; font-size:12px; flex-shrink:0; }
.tn-placement-spacer { height:6px; border-bottom:none !important; }
.tn-standings-spacer td { height:6px; padding:0; border-bottom:none !important; }
.tn-bout-pips { display:flex; gap:7px; justify-content:center; margin-top:8px; }
.tn-bout-pip { width:24px; height:24px; border-radius:50%; border:2px solid #cbd5e0; background:#fff; cursor:pointer; padding:0; transition:background .15s, border-color .15s, transform .1s; flex-shrink:0; }
.tn-bout-pip:hover { border-color:#718096; transform:scale(1.15); }
.tn-bout-pip.tn-pip-win  { background:#276749; border-color:#276749; }
.tn-bout-pip.tn-pip-loss { background:#e53e3e; border-color:#e53e3e; }
.tn-bout-score { text-align:center; font-size:13px; font-weight:700; color:#276749; margin-top:10px; min-height:18px; }
.tn-btn-danger { background:#fff; color:#e53e3e; border:1px solid #e53e3e; }
.tn-btn-danger:hover { background:#e53e3e; color:#fff; }
.tn-bracket-toggle { background:none; border:none; color:#a0aec0; cursor:pointer; padding:4px 6px; display:flex; align-items:center; flex-shrink:0; }
.tn-bracket-toggle:hover { color:#4a5568; }
.tn-bracket-toggle i { transition:transform .2s; }
.tn-bracket-card.tn-collapsed .tn-bracket-toggle i { transform:rotate(-90deg); }
.tn-bracket-card.tn-collapsed .tn-bracket-body { display:none; }
.tn-quickadd-row { display:flex; align-items:center; gap:8px; padding:5px 0; border-bottom:1px solid #f0f4f8; font-size:13px; }
.tn-quickadd-row:last-child { border-bottom:none; }
.tn-quickadd-name { flex:1; color:#4a5568; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
.tn-quickadd-row.tn-quickadd-done .tn-quickadd-name { color:#a0aec0; text-decoration:line-through; }
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
.tn-bv-wrap { overflow-x:auto; -webkit-overflow-scrolling:touch; padding-bottom:8px; }
.tn-bv-tree { display:flex; gap:0; align-items:stretch; min-width:max-content; position:relative; }
.tn-bv-round { display:flex; flex-direction:column; min-width:190px; padding:0 14px; }
.tn-bv-round-body { display:flex; flex-direction:column; justify-content:space-around; flex:1; }
.tn-bv-round-label { font-size:11px; font-weight:700; color:#a0aec0; text-transform:uppercase; letter-spacing:0.5px; text-align:center; margin-bottom:10px; padding-bottom:6px; border-bottom:1px solid #e2e8f0; }
.tn-bv-match { border:1px solid #e2e8f0; border-radius:7px; overflow:hidden; background:#fff; box-shadow:0 1px 3px rgba(0,0,0,0.05); margin:6px 0; position:relative; z-index:1; }
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
.tn-bv-reset-btn { position:absolute; top:4px; right:4px; background:none; border:none; padding:3px 5px; border-radius:4px; color:#cbd5e0; cursor:pointer; font-size:13px; line-height:1; opacity:0; transition:opacity .15s,color .15s,background .15s; }
.tn-bv-match:hover .tn-bv-reset-btn { opacity:1; }
.tn-bv-reset-btn:hover { color:#e53e3e; background:#fff5f5; }
.tn-bv-reset-btn.tn-bv-reset-confirm { opacity:1; color:#e53e3e; background:#fff5f5; font-weight:700; font-size:10px; border:1px solid #e53e3e; padding:2px 5px; border-radius:4px; white-space:nowrap; }
.tn-bv-reset-btn:disabled { opacity:.3; cursor:not-allowed; }
/* ── Ironman / King of the Hill tap-to-win view ── */
.tn-im-header { display:flex; align-items:center; justify-content:space-between; margin-bottom:14px; flex-wrap:wrap; gap:8px; }
.tn-im-fight-num { font-size:11px; font-weight:700; text-transform:uppercase; letter-spacing:0.6px; color:#718096; }
.tn-im-king-badge { display:flex; align-items:center; gap:6px; background:#f0fff4; border:1px solid #9ae6b4; border-radius:20px; padding:5px 12px; }
.tn-im-king-badge-crown { color:#d69e2e; font-size:13px; }
.tn-im-king-badge-label { font-size:10px; font-weight:700; text-transform:uppercase; color:#276749; letter-spacing:0.5px; }
.tn-im-king-badge-name { font-size:13px; font-weight:700; color:#1a202c; }
.tn-im-king-badge-streak { font-size:11px; font-weight:700; color:#276749; background:#c6f6d5; border-radius:10px; padding:1px 6px; }
.tn-im-grid { display:grid; grid-template-columns:repeat(auto-fill,minmax(110px,1fr)); gap:10px; margin-bottom:16px; }
.tn-im-card { border:2px solid #e2e8f0; border-radius:10px; padding:12px 8px 10px; background:#fff; text-align:center; position:relative; transition:border-color .15s,background .15s,transform .1s,box-shadow .15s; }
.tn-im-card.tn-im-card-king { border-color:#3182ce; background:#ebf8ff; } /* border-color overridden per-ring by JS */
.tn-im-card.tn-im-card-btn { cursor:pointer; }
.tn-im-card.tn-im-card-btn:hover { transform:translateY(-2px); box-shadow:0 4px 12px rgba(0,0,0,.12); }
.tn-im-card.tn-im-card-btn:active { transform:translateY(0); }
.tn-im-card.tn-im-card-btn.tn-im-card-king:hover { background:#bee3f8; }
.tn-im-card-crown { position:absolute; top:5px; right:7px; color:#d69e2e; font-size:11px; }
.tn-im-avatar { width:36px; height:36px; border-radius:8px; display:flex; align-items:center; justify-content:center; font-size:13px; font-weight:800; color:#fff; margin:0 auto 8px; }
.tn-im-card-name { font-size:11px; font-weight:700; color:#1a202c; line-height:1.2; word-break:break-word; margin-bottom:4px; text-transform:uppercase; letter-spacing:0.2px; }
.tn-im-card-wins { font-size:11px; color:#718096; }
.tn-im-card-wins i { font-size:10px; margin-right:2px; }
.tn-im-section-title { font-size:11px; font-weight:700; text-transform:uppercase; letter-spacing:0.5px; color:#718096; margin-bottom:8px; }
.tn-im-history { margin-top:4px; }
.tn-im-history-row { display:flex; justify-content:space-between; align-items:center; padding:5px 8px; border-radius:4px; font-size:12px; }
.tn-im-history-row:nth-child(odd) { background:#f7fafc; }
.tn-im-history-fight { color:#a0aec0; font-size:10px; font-weight:700; margin-right:8px; }
.tn-im-history-winner { font-weight:700; color:#276749; }
.tn-im-history-loser { color:#a0aec0; text-decoration:line-through; }
.tn-im-history-expand { padding:4px 8px; font-size:11px; color:#3182ce; cursor:pointer; font-weight:600; }
.tn-im-history-expand:hover { text-decoration:underline; }
.tn-im-qe-wrap { display:flex; align-items:center; gap:8px; background:#f7fafc; border:1px solid #e2e8f0; border-radius:8px; padding:6px 12px; }
.tn-im-qe-label { font-size:11px; font-weight:700; text-transform:uppercase; letter-spacing:0.5px; color:#718096; white-space:nowrap; }
.tn-im-qe-input { width:80px; padding:6px 10px; border:2px solid #e2e8f0; border-radius:6px; font-size:18px; font-weight:700; text-align:center; outline:none; transition:border-color .15s; }
.tn-im-qe-input:focus { border-color:#3182ce; }
.tn-im-qe-status { font-size:12px; flex:1; color:#718096; }
.tn-im-qe-status.ok { color:#276749; font-weight:600; }
.tn-im-qe-status.err { color:#e53e3e; font-weight:600; }
.tn-im-timer-bar { display:flex; align-items:center; gap:10px; margin-bottom:14px; background:#1a202c; border-radius:10px; padding:10px 16px; flex-wrap:wrap; }
.tn-im-timer-display { font-size:28px; font-weight:800; font-variant-numeric:tabular-nums; letter-spacing:1px; color:#fff; min-width:90px; }
.tn-im-timer-display.running { color:#68d391; }
.tn-im-timer-display.expired { color:#fc8181; }
.tn-im-timer-display.grace { color:#ed8936; animation:tn-grace-pulse 1s ease-in-out infinite; }
.tn-im-timer-bar.warning { animation:tn-bar-warn 1.2s ease-in-out infinite; }
@keyframes tn-bar-warn { 0%,100% { box-shadow:none; } 50% { box-shadow:0 0 0 4px rgba(229,62,62,0.35); } }
@keyframes tn-grace-pulse { 0%,100% { opacity:1; } 50% { opacity:.55; } }
.tn-im-timer-btn { padding:6px 16px; border-radius:6px; font-size:13px; font-weight:700; border:none; cursor:pointer; transition:background .15s; }
.tn-im-timer-btn.start { background:#276749; color:#fff; }
.tn-im-timer-btn.start:hover { background:#22543d; }
.tn-im-timer-btn.add { background:#2d3748; color:#a0aec0; }
.tn-im-timer-btn.add:hover { background:#4a5568; color:#fff; }
.tn-im-timer-btn.end { background:transparent; color:#fc8181; border:1px solid #fc8181; }
.tn-im-timer-btn.end:hover { background:#fc8181; color:#fff; }
.tn-im-timer-btn.pause { background:#2d3748; color:#ecc94b; border:1px solid #4a5568; }
.tn-im-timer-btn.pause:hover { background:#4a5568; color:#fefcbf; }
.tn-im-timer-display.paused { color:#ecc94b; }
.tn-im-timer-locked { font-size:11px; color:#a0aec0; margin-left:auto; }
.tn-im-rings-wrap { display:flex; flex-direction:column; gap:18px; }
.tn-im-ring { border:3px solid #e2e8f0; border-radius:12px; padding:14px 14px 10px; background:#fff; }
.tn-im-ring-header { display:flex; align-items:center; gap:8px; margin-bottom:12px; flex-wrap:wrap; }
.tn-im-card-blocked { opacity:0.38; cursor:not-allowed !important; pointer-events:none; }

.tn-bk-pills { display:flex; flex-wrap:wrap; gap:6px; margin-bottom:14px; }
.tn-bk-pill { padding:5px 14px; border-radius:20px; font-size:12px; font-weight:600; border:1px solid #e2e8f0; background:#fff; color:#718096; cursor:pointer; transition:background .15s,border-color .15s,color .15s; white-space:nowrap; }
.tn-bk-pill:hover { border-color:#276749; color:#276749; background:#f0fff4; }
.tn-bk-pill.tn-bk-pill-active { background:#276749; border-color:#276749; color:#fff; }
.tn-rr-round-body { display:flex; flex-wrap:wrap; gap:10px; padding:4px 0; }
.tn-rr-round-body .tn-bv-match { min-width:260px; flex:1 1 260px; margin:0; }
.tn-bv-round-nav { display:flex; align-items:center; gap:8px; margin-bottom:12px; flex-wrap:wrap; }
.tn-bv-round-btn { padding:4px 12px; border-radius:20px; font-size:12px; font-weight:600; border:1px solid #e2e8f0; background:#fff; color:#718096; cursor:pointer; }
.tn-bv-round-btn.active { background:#276749; color:#fff; border-color:#276749; }
.tn-bv-round-btn.tn-rr-complete:not(.active) { background:#3182ce; color:#fff; border-color:#2b6cb0; }
@keyframes tn-pill-pulse { 0%,100% { box-shadow:0 0 0 0 rgba(49,130,206,0); } 50% { box-shadow:0 0 0 5px rgba(49,130,206,0.38); } }
.tn-bv-round-btn.tn-rr-next-pulse { animation:tn-pill-pulse 1.4s ease-in-out 3; }
.tn-bv-round-section { }
.tn-bv-section-label { font-size:11px; font-weight:700; color:#718096; text-transform:uppercase; letter-spacing:0.5px; margin:14px 0 8px; padding-bottom:4px; border-bottom:1px solid #e2e8f0; }
.tn-bv-generate-bar { display:flex; align-items:center; gap:10px; padding:12px 14px; background:#f7fafc; border:1px dashed #e2e8f0; border-radius:8px; margin-bottom:14px; }
.tn-bv-status-badge { font-size:11px; font-weight:700; padding:2px 8px; border-radius:10px; }
.tn-bv-status-setup    { background:#e2e8f0; color:#718096; }
.tn-bv-status-active   { background:#bee3f8; color:#2b6cb0; }
.tn-bv-status-complete  { background:#c6f6d5; color:#276749; }
.tn-bv-status-finalized { background:#fefcbf; color:#744210; }
.tn-bv-empty { color:#a0aec0; font-size:13px; font-style:italic; padding:16px 0; text-align:center; }
.tn-bv-section-hdr { display:flex; align-items:center; gap:7px; padding:5px 12px; border-radius:5px; margin:14px 0 6px; font-size:11px; font-weight:700; text-transform:uppercase; letter-spacing:0.5px; }
.tn-bv-section-hdr.winners { border-left:3px solid #276749; background:#f0fff4; color:#276749; }
.tn-bv-section-hdr.losers { border-left:3px solid #d97706; background:#fffbeb; color:#b7791f; }
.tn-bv-section-hdr.grand-final { border-left:3px solid #6b46c1; background:#faf5ff; color:#6b46c1; }
.tn-gf-confirm-banner { background:#fefcbf; border:1px solid #ecc94b; border-radius:7px; padding:12px 16px; margin:0 0 12px; display:flex; align-items:center; justify-content:space-between; gap:12px; flex-wrap:wrap; }
.tn-gf-confirm-text { color:#744210; font-size:13px; display:flex; align-items:center; gap:7px; flex:1; }
.tn-gf-confirm-btns { display:flex; flex-direction:column; gap:6px; flex-shrink:0; }
.tn-gf-inline-btns { display:flex; flex-direction:column; gap:6px; justify-content:center; margin-left:10px; }
.tn-gf-confirm-yes { background:#38a169; color:#fff; border:none; border-radius:5px; padding:6px 13px; cursor:pointer; font-size:13px; font-weight:600; display:flex; align-items:center; gap:5px; }
.tn-gf-confirm-yes:hover { background:#2f855a; }
.tn-gf-confirm-no { background:#e53e3e; color:#fff; border:none; border-radius:5px; padding:6px 13px; cursor:pointer; font-size:13px; font-weight:600; display:flex; align-items:center; gap:5px; }
.tn-gf-confirm-no:hover { background:#c53030; }
.tn-bv-progress-info { font-size:11px; color:#a0aec0; }
.tn-bv-progress-info .tn-bv-pi-ready { color:#276749; font-weight:700; }
.tn-bv-bout-row { display:flex; align-items:center; gap:4px; padding:4px 10px 5px; justify-content:center; border-top:1px solid #e2e8f0; background:#f7fafc; }
.tn-bv-bout-dot { width:8px; height:8px; border-radius:50%; flex-shrink:0; }
.tn-bv-bout-dot.tn-bd-1 { background:#276749; }
.tn-bv-bout-dot.tn-bd-2 { background:#e53e3e; }
.tn-bv-tbd-label { font-size:10px; color:#a0aec0; font-style:italic; }
.tn-rr-standings { width:100%; border-collapse:collapse; font-size:12px; margin-top:18px; }
.tn-rr-standings caption { font-size:11px; font-weight:700; color:#718096; text-transform:uppercase; letter-spacing:0.4px; text-align:left; padding:0 0 6px; caption-side:top; }
.tn-rr-standings th { background:#f7fafc; padding:5px 10px; font-size:11px; font-weight:700; color:#718096; text-transform:uppercase; letter-spacing:0.4px; border-bottom:2px solid #e2e8f0; text-align:center; }
.tn-rr-standings th:nth-child(2) { text-align:left; }
.tn-rr-standings td { padding:6px 10px; border-bottom:1px solid #f0f4f8; color:#4a5568; text-align:center; }
.tn-rr-standings td:nth-child(2) { font-weight:600; color:#2d3748; text-align:left; }
.tn-rr-standings tr:last-child td { border-bottom:none; }
.tn-rr-standings .tn-rr-std-top td { background:#f0fff4; }

/* ================================================================
   ROUND ROBIN ENHANCEMENTS
   Prefix: tn-rr-  (round-robin specific additions)
   ================================================================ */

/* ── View Toggle (Rounds / Matrix) ── */
.tn-rr-view-toggle {
	display:inline-flex;
	border-radius:20px;
	overflow:hidden;
	border:1px solid #e2e8f0;
	background:#fff;
}
.tn-rr-view-toggle-btn {
	padding:4px 14px;
	font-size:12px;
	font-weight:600;
	color:#718096;
	background:#fff;
	border:none;
	cursor:pointer;
	transition:background .15s, color .15s;
	white-space:nowrap;
}
.tn-rr-view-toggle-btn:first-child { border-right:1px solid #e2e8f0; }
.tn-rr-view-toggle-btn:hover:not(.active) { background:#f7fafc; color:#4a5568; }
.tn-rr-view-toggle-btn.active { background:#276749; color:#fff; }

/* ── Cross-Table Matrix View ── */
.tn-rr-matrix-wrap {
	overflow-x:auto;
	-webkit-overflow-scrolling:touch;
	margin-top:12px;
	border:1px solid #e2e8f0;
	border-radius:8px;
	background:#fff;
}
.tn-rr-matrix {
	width:100%;
	border-collapse:separate;
	border-spacing:0;
	font-size:12px;
	min-width:400px;
}
.tn-rr-matrix th,
.tn-rr-matrix td {
	padding:6px 10px;
	text-align:center;
	border-bottom:1px solid #f0f4f8;
	border-right:1px solid #f0f4f8;
}
.tn-rr-matrix th:last-child,
.tn-rr-matrix td:last-child { border-right:none; }
.tn-rr-matrix tr:last-child td { border-bottom:none; }
.tn-rr-matrix thead th {
	position:sticky;
	top:0;
	z-index:3;
	background:#f7fafc;
	font-size:11px;
	font-weight:700;
	color:#718096;
	text-transform:uppercase;
	letter-spacing:0.3px;
	border-bottom:2px solid #e2e8f0;
	white-space:nowrap;
	max-width:80px;
	overflow:hidden;
	text-overflow:ellipsis;
}
.tn-rr-mx-player-col {
	position:sticky;
	left:0;
	z-index:2;
	background:#f7fafc;
	font-weight:600;
	color:#2d3748;
	text-align:left !important;
	white-space:nowrap;
	min-width:120px;
	border-right:2px solid #e2e8f0 !important;
}
.tn-rr-matrix thead th:first-child {
	position:sticky;
	left:0;
	z-index:4;
	border-right:2px solid #e2e8f0;
}
.tn-rr-mx-win { background:#f0fff4; color:#276749; font-weight:700; }
.tn-rr-mx-loss { background:#fff5f5; color:#e53e3e; font-weight:600; }
.tn-rr-mx-tie { background:#fefcbf; color:#744210; font-weight:600; }
.tn-rr-mx-self {
	background:#edf2f7; color:#cbd5e0; cursor:default; position:relative;
}
.tn-rr-mx-self::after {
	content:'';
	position:absolute;
	top:0; left:0; right:0; bottom:0;
	background:repeating-linear-gradient(-45deg, transparent, transparent 3px, rgba(0,0,0,0.04) 3px, rgba(0,0,0,0.04) 6px);
	pointer-events:none;
}
.tn-rr-mx-pending { color:#a0aec0; font-style:italic; }
.tn-rr-mx-cell-clickable { cursor:pointer; transition:background .12s, box-shadow .12s; }
.tn-rr-mx-cell-clickable:hover { box-shadow:inset 0 0 0 2px #276749; background:#f0fff4; }
.tn-rr-mx-avatar {
	width:20px; height:20px; border-radius:50%;
	display:inline-flex; align-items:center; justify-content:center;
	font-size:9px; font-weight:800; color:#fff; flex-shrink:0;
	vertical-align:middle; margin-right:4px;
}
.tn-rr-mx-avatar-sm { width:16px; height:16px; font-size:7px; margin-right:2px; }
.tn-rr-mx-col-header { vertical-align:bottom; padding:8px 6px !important; }
.tn-rr-mx-col-name { display:block; margin-top:3px; font-size:10px; }
.tn-rr-mx-player-name { vertical-align:middle; }
.tn-rr-mx-result { display:block; font-size:13px; line-height:1.2; }
.tn-rr-mx-bouts { display:block; font-size:9px; color:inherit; opacity:0.65; line-height:1; margin-top:1px; }
.tn-rr-mx-corner { min-width:120px; }

/* ── Enhanced Standings Table ── */
.tn-rr-standings-enhanced { width:100%; border-collapse:collapse; font-size:12px; margin-top:18px; }
.tn-rr-standings-enhanced caption {
	font-size:11px; font-weight:700; color:#718096;
	text-transform:uppercase; letter-spacing:0.4px;
	text-align:left; padding:0 0 6px; caption-side:top;
}
.tn-rr-standings-enhanced th {
	background:#f7fafc; padding:6px 10px; font-size:11px; font-weight:700;
	color:#718096; text-transform:uppercase; letter-spacing:0.4px;
	border-bottom:2px solid #e2e8f0; text-align:center;
}
.tn-rr-standings-enhanced td {
	padding:7px 10px; border-bottom:1px solid #f0f4f8;
	color:#4a5568; text-align:center; vertical-align:middle;
}
.tn-rr-standings-enhanced tr:last-child td { border-bottom:none; }
.tn-rr-std-col-player { text-align:left !important; }
.tn-rr-std-col-rank { width:44px; }
.tn-rr-std-col-progress { min-width:90px; }
.tn-rr-std-rank { text-align:center; }
.tn-rr-std-medal { font-size:16px; line-height:1; }
.tn-rr-std-player { text-align:left !important; }
.tn-rr-std-player-wrap { display:flex; align-items:center; gap:8px; }
.tn-rr-std-avatar {
	width:24px; height:24px; border-radius:50%;
	display:flex; align-items:center; justify-content:center;
	font-size:9px; font-weight:800; color:#fff; flex-shrink:0;
}
.tn-rr-std-name-wrap { display:flex; flex-direction:column; gap:1px; }
.tn-rr-std-name { font-weight:600; color:#2d3748; font-size:12px; }
.tn-rr-std-park { font-size:10px; color:#a0aec0; display:block; }
.tn-rr-std-w { color:#276749; font-weight:700; }
.tn-rr-std-l { color:#e53e3e; font-weight:600; }
.tn-rr-std-t { color:#744210; font-weight:600; }
.tn-rr-std-pts { font-weight:800; color:#1a202c; font-size:14px; }
.tn-rr-std-winpct { font-weight:700; color:#276749; font-size:11px; }
.tn-rr-std-bar {
	display:inline-flex; align-items:center; gap:6px;
}
.tn-rr-std-bar-track {
	width:50px; height:8px; background:#e2e8f0;
	border-radius:4px; overflow:hidden; flex-shrink:0;
}
.tn-rr-std-bar-fill {
	height:100%; border-radius:4px;
	background:linear-gradient(90deg, #38a169, #276749);
	transition:width .3s ease;
}
.tn-rr-std-bar-text { font-size:10px; color:#718096; font-weight:600; white-space:nowrap; }
.tn-rr-std-caption-progress { font-size:10px; color:#a0aec0; margin-left:8px; font-weight:400; }
.tn-rr-std-active td { background:#ebf8ff !important; box-shadow:inset 3px 0 0 #3182ce; }
.tn-rr-std-clickable tr { cursor:pointer; transition:background .12s; }
.tn-rr-std-clickable tr:hover td { background:#f7fafc; }

/* ── Overall Progress Bar ── */
.tn-rr-progress-wrap { margin:12px 0; }
.tn-rr-progress-bar {
	position:relative; width:100%; height:22px;
	background:#e2e8f0; border-radius:11px; overflow:hidden;
	box-shadow:inset 0 1px 2px rgba(0,0,0,0.06);
}
.tn-rr-progress-fill {
	height:100%; border-radius:11px;
	background:linear-gradient(90deg, #38a169 0%, #276749 100%);
	transition:width .4s ease; min-width:0;
}
.tn-rr-progress-label {
	position:absolute; top:0; left:0; right:0; bottom:0;
	display:flex; align-items:center; justify-content:center;
	font-size:11px; font-weight:700; color:#fff;
	text-shadow:0 1px 2px rgba(0,0,0,0.2); pointer-events:none;
}
.tn-rr-progress-bar.tn-rr-progress-low .tn-rr-progress-label {
	color:#4a5568; text-shadow:none;
}
.tn-rr-round-count {
	display:inline-block; font-size:9px; font-weight:700; color:#a0aec0;
	background:#f7fafc; border:1px solid #e2e8f0;
	padding:0 5px; border-radius:8px; margin-left:4px;
	vertical-align:middle; line-height:16px;
}
.tn-bv-round-btn.active .tn-rr-round-count {
	color:rgba(255,255,255,0.8); background:rgba(255,255,255,0.15); border-color:rgba(255,255,255,0.25);
}
.tn-bv-round-btn.tn-rr-complete:not(.active) .tn-rr-round-count {
	color:rgba(255,255,255,0.8); background:rgba(255,255,255,0.15); border-color:rgba(255,255,255,0.25);
}

/* ── Champion Banner sub-elements ── */
.tn-bv-champion-row { display:flex; align-items:center; gap:12px; }
.tn-bv-champion-trophy { font-size:32px; flex-shrink:0; }
.tn-bv-podium-rank { font-size:11px; font-weight:800; text-transform:uppercase; letter-spacing:0.3px; }
.tn-bv-podium-avatar {
	width:28px; height:28px; border-radius:50%;
	display:flex; align-items:center; justify-content:center;
	font-size:10px; font-weight:800; color:#fff; margin:4px auto;
}
.tn-bv-podium-name { font-size:12px; font-weight:700; color:#1a202c; text-align:center; }
.tn-bv-podium-park { font-size:10px; color:#718096; text-align:center; }
.tn-bv-podium-stats { font-size:10px; color:#276749; font-weight:600; text-align:center; margin-top:2px; }

/* ── Match Card Record Badge ── */
.tn-rr-card-record {
	font-size:9px; font-weight:600; color:#a0aec0;
	white-space:nowrap; flex-shrink:0; margin-left:4px;
}

/* ── Player Focus Mode ── */
.tn-rr-focus-active .tn-bv-match:not(.tn-rr-focus-match) {
	opacity:0.3; filter:grayscale(0.5); transition:opacity .2s, filter .2s;
}
.tn-rr-focus-active .tn-rr-focus-match {
	border-color:#3182ce;
	box-shadow:0 0 0 2px rgba(49,130,206,0.25), 0 2px 8px rgba(49,130,206,0.15);
	transition:border-color .2s, box-shadow .2s;
}
.tn-rr-focus-active .tn-rr-matrix tr:not(.tn-rr-focus-row) td:not(.tn-rr-mx-player-col) { opacity:0.3; }
.tn-rr-focus-active .tn-rr-standings-enhanced tbody tr:not(.tn-rr-std-active) { opacity:0.45; }
.tn-rr-focus-banner {
	display:flex; align-items:center; gap:8px;
	padding:8px 14px; background:#ebf8ff; border:1px solid #bee3f8;
	border-radius:8px; margin-bottom:12px;
	font-size:12px; color:#2b6cb0; font-weight:600;
}
.tn-rr-focus-banner-name { font-weight:800; color:#1a202c; }
.tn-rr-focus-banner-close {
	margin-left:auto; background:none; border:none;
	font-size:16px; color:#3182ce; cursor:pointer;
	padding:2px 6px; border-radius:4px; line-height:1;
	transition:background .12s, color .12s;
}
.tn-rr-focus-banner-close:hover { background:#bee3f8; color:#2b6cb0; }

/* ── Mobile Overrides ── */
@media (max-width: 768px) {
	.tn-rr-matrix th, .tn-rr-matrix td { padding:4px 6px; font-size:11px; }
	.tn-rr-mx-player-col { min-width:90px; font-size:11px; }
	.tn-rr-standings-enhanced th, .tn-rr-standings-enhanced td { padding:5px 6px; font-size:11px; }
	.tn-rr-std-bar-track { width:40px; }
	.tn-rr-focus-banner { flex-wrap:wrap; font-size:11px; }
	.tn-rr-progress-bar { height:18px; }
	.tn-rr-progress-label { font-size:10px; }
}
@media (max-width: 480px) {
	.tn-rr-matrix-wrap { position:relative; }
	.tn-rr-matrix-wrap::after {
		content:''; position:absolute; top:0; right:0; bottom:0; width:24px;
		background:linear-gradient(90deg, transparent, rgba(255,255,255,0.85));
		pointer-events:none; border-radius:0 8px 8px 0;
	}
	.tn-rr-matrix th, .tn-rr-matrix td { padding:4px 5px; font-size:10px; min-width:36px; }
	.tn-rr-mx-player-col { min-width:70px; font-size:10px; }
	.tn-rr-mx-cell-clickable { min-height:36px; min-width:36px; }
	.tn-rr-std-bar-track { width:32px; height:6px; }
	.tn-rr-std-winpct { font-size:10px; }
	.tn-rr-std-pts { font-size:12px; }
	.tn-rr-view-toggle { width:100%; }
	.tn-rr-view-toggle-btn { flex:1; text-align:center; padding:8px 12px; }
	.tn-rr-progress-bar { height:16px; border-radius:8px; }
	.tn-rr-progress-fill { border-radius:8px; }
	.tn-rr-progress-label { font-size:9px; }
	.tn-rr-focus-banner-close { padding:6px 10px; font-size:18px; }
}


/* -- Bracket Viz Enhancements -- */
.tn-bv-match-num { position:absolute; top:3px; left:6px; font-size:9px; font-weight:700; color:#a0aec0; letter-spacing:0.3px; z-index:2; }
.tn-bv-match.tn-bv-bye-match { border-style:dashed; border-color:#e2e8f0; background:#fafafa; opacity:0.7; }
.tn-bv-match.tn-bv-bye-match .tn-bv-slot { color:#cbd5e0; }
.tn-bv-bye-label { font-size:9px; color:#a0aec0; text-align:center; padding:2px 0; font-style:italic; border-top:1px dashed #e2e8f0; }
.tn-bv-match.tn-bv-next-playable { animation:tn-next-pulse 2s ease-in-out infinite; }
@keyframes tn-next-pulse { 0%,100% { box-shadow:0 0 0 0 rgba(39,103,73,0); } 50% { box-shadow:0 0 0 4px rgba(39,103,73,0.2); } }
.tn-bv-avatar { width:20px; height:20px; border-radius:50%; display:flex; align-items:center; justify-content:center; font-size:9px; font-weight:800; color:#fff; flex-shrink:0; line-height:1; }
.tn-bv-tooltip { position:fixed; background:#1a202c; color:#fff; padding:8px 12px; border-radius:6px; font-size:12px; line-height:1.4; z-index:2000; pointer-events:none; max-width:260px; box-shadow:0 4px 12px rgba(0,0,0,0.25); opacity:0; transition:opacity .15s; }
.tn-bv-tooltip.tn-bv-tooltip-show { opacity:1; }
.tn-bv-tooltip-name { font-weight:700; }
.tn-bv-tooltip-park { color:#a0aec0; font-size:11px; }
.tn-bv-tooltip-bouts { margin-top:4px; font-size:11px; color:#cbd5e0; }
.tn-bv-champion-banner { display:flex; align-items:center; gap:12px; padding:14px 18px; background:linear-gradient(135deg,#f6e05e 0%,#ecc94b 100%); border-radius:8px; margin-bottom:14px; box-shadow:0 2px 8px rgba(236,201,75,0.3); }
.tn-bv-champion-crown { font-size:28px; flex-shrink:0; }
.tn-bv-champion-info { flex:1; }
.tn-bv-champion-label { font-size:10px; font-weight:800; text-transform:uppercase; letter-spacing:1px; color:#744210; }
.tn-bv-champion-name { font-size:18px; font-weight:800; color:#1a202c; }
.tn-bv-champion-park { font-size:12px; color:#744210; }
.tn-bv-podium { display:flex; gap:8px; flex-wrap:wrap; }
.tn-bv-podium-card { display:flex; align-items:center; gap:8px; padding:6px 12px; border-radius:6px; font-size:12px; font-weight:600; }
.tn-bv-podium-1st { background:#fefcbf; color:#744210; border:1px solid #ecc94b; }
.tn-bv-podium-2nd { background:#e2e8f0; color:#4a5568; border:1px solid #cbd5e0; }
.tn-bv-podium-3rd { background:#fed7aa; color:#7b341e; border:1px solid #f6ad55; }
.tn-bv-podium-num { font-size:11px; font-weight:800; }
.tn-bv-zoom-controls { display:flex; align-items:center; gap:6px; margin-bottom:10px; }
.tn-bv-zoom-btn { width:28px; height:28px; border-radius:6px; border:1px solid #e2e8f0; background:#fff; color:#718096; cursor:pointer; display:flex; align-items:center; justify-content:center; font-size:14px; font-weight:700; transition:background .15s,color .15s; }
.tn-bv-zoom-btn:hover { background:#f0fff4; color:#276749; border-color:#276749; }
.tn-bv-zoom-level { font-size:11px; color:#a0aec0; min-width:36px; text-align:center; }
.tn-bv-section-hdr.tiebreaker-3rd { border-left:3px solid #dd6b20; background:#fffaf0; color:#c05621; }
.tn-bv-losers-compact .tn-bv-round { min-width:160px; padding:0 8px; }
.tn-bv-losers-compact .tn-bv-match { margin:3px 0; }
.tn-bv-losers-compact .tn-bv-slot { padding:4px 8px; font-size:12px; min-height:28px; }
.tn-bv-losers-compact .tn-bv-seed { width:16px; height:16px; font-size:8px; }
.tn-bv-losers-compact .tn-bv-avatar { width:16px; height:16px; font-size:7px; }
.tn-bv-losers-compact .tn-bv-round-label { font-size:10px; margin-bottom:6px; padding-bottom:4px; }

/* Responsive */
@media (max-width: 768px) {
	.tn-layout { flex-direction:column; }
	.tn-sidebar { width:100%; }
	.tn-hero-content { flex-direction:column; gap:12px; }
	.tn-stats-row { gap:8px; }
	.tn-stat-card { min-width:calc(50% - 4px); }
	.tn-field-row { grid-template-columns:1fr; }
	.tn-tab-nav { overflow-x:auto; -webkit-overflow-scrolling:touch; scroll-snap-type:x mandatory; }
	.tn-tab-btn { scroll-snap-align:start; }
	.tn-bv-round { min-width:150px; padding:0 8px; }
	.tn-rr-round-body .tn-bv-match { min-width:100%; flex:1 1 100%; }
	.tn-rr-standings th, .tn-rr-standings td { padding:5px 8px; font-size:12px; }
}
@media (max-width: 480px) {
	/* Hero */
	.tn-hero-icon { width:52px; height:52px; font-size:24px; }
	.tn-stat-value { font-size:clamp(1.1rem, 5vw, 1.6rem); }
	/* Buttons — approach 44px touch target */
	.tn-btn { padding:10px 16px; }
	.tn-btn-sm { padding:7px 12px; }
	/* Ironman grid — smaller min card width */
	.tn-im-grid { grid-template-columns:repeat(auto-fill,minmax(90px,1fr)); }
	.tn-im-avatar { width:44px; height:44px; font-size:14px; }
	.tn-im-qe-wrap { flex-wrap:wrap; }
	.tn-im-qe-input { width:60px; padding:8px 12px; font-size:16px; }
	/* Ring header — stack vertically */
	.tn-im-ring-header { flex-direction:column; align-items:flex-start; gap:10px; }
	/* Timer bar — stack buttons */
	.tn-im-timer-bar { flex-direction:column; align-items:flex-start; gap:8px; }
	.tn-im-timer-display { font-size:22px; min-width:unset; }
	.tn-im-timer-btn { padding:10px 16px; width:100%; text-align:center; }
	/* Bracket viz rounds narrower */
	.tn-bv-round { min-width:110px; }
	/* Bout pips — larger touch target */
	.tn-bout-pip { width:32px; height:32px; font-size:12px; }
	/* Participant remove button */
	.tn-remove-participant { padding:6px 10px; }
	/* Autocomplete dropdown shorter */
	.tn-ac-results { max-height:150px; }
	/* Modal padding tighter on small screens */
	.tn-modal-body { padding:14px; }
	.tn-modal-footer { padding:10px 14px; flex-wrap:wrap; }
	.tn-modal-footer .tn-btn { flex:1 1 auto; text-align:center; }
}
/* Touch devices — show hover-only elements always */
@media (hover:none) {
	.tn-bv-reset-btn { opacity:1 !important; }
	.tn-im-card.tn-im-card-btn:active { transform:translateY(-2px); box-shadow:0 4px 12px rgba(0,0,0,.12); }
	.tn-bout-pip:active { transform:scale(1.15); }
}
/* Landscape mobile — compress modal & hero height */
@media (max-height: 600px) and (orientation:landscape) {
	.tn-modal-body { max-height:70vh; }
	.tn-hero { padding:14px 12px; }
}
/* ── Check-in system ── */

/* ── Participant status menu ── */
.tn-status-wrap { position:relative; flex-shrink:0; }
.tn-status-btn { background:none; border:none; color:#a0aec0; cursor:pointer; padding:2px 5px; font-size:14px; line-height:1; }
.tn-status-btn:hover { color:#4a5568; }
.tn-status-menu { display:none; position:absolute; right:0; top:100%; background:#fff; border:1px solid #e2e8f0; border-radius:6px; box-shadow:0 4px 12px rgba(0,0,0,.12); z-index:50; min-width:150px; overflow:hidden; }
.tn-status-menu.tn-status-open { display:block; }
.tn-status-menu-item { padding:8px 14px; font-size:12px; font-weight:600; cursor:pointer; display:flex; align-items:center; gap:6px; border-bottom:1px solid #f0f4f8; white-space:nowrap; }
.tn-status-menu-item:last-child { border-bottom:none; }
.tn-status-menu-item:hover { background:#f7fafc; }
.tn-status-menu-item.tn-sm-active { color:#276749; }
.tn-status-menu-item .tn-sm-dot { width:8px; height:8px; border-radius:50%; flex-shrink:0; }
.tn-sm-dot-active { background:#38a169; }
.tn-sm-dot-absent { background:#a0aec0; }
.tn-sm-dot-withdrawn { background:#d69e2e; }
.tn-sm-dot-disqualified { background:#e53e3e; }
/* Visual states on participant row */
.tn-participant-list li.tn-pstatus-withdrawn span:not(.tn-participant-seed):not(.tn-status-wrap):not(.tn-status-btn) { text-decoration:line-through; color:#d69e2e; }
.tn-participant-list li.tn-pstatus-disqualified span:not(.tn-participant-seed):not(.tn-status-wrap):not(.tn-status-btn) { text-decoration:line-through; color:#e53e3e; }
.tn-pstatus-pill { font-size:9px; font-weight:700; padding:1px 6px; border-radius:10px; margin-left:4px; text-decoration:none !important; }
.tn-pstatus-pill-withdrawn { background:#fefcbf; color:#b45309; border:1px solid #fcd34d; }
.tn-pstatus-pill-disqualified { background:#fff5f5; color:#e53e3e; border:1px solid #fc8181; }

/* ── Bracket Preview Modal ── */

/* ── Quick Result Entry (inline on bracket viz) ── */
.tn-qr-bar { display:flex; align-items:center; gap:6px; padding:6px 10px; border-top:1px solid #e2e8f0; background:#f7fafc; }
.tn-qr-btn { padding:4px 10px; border-radius:5px; font-size:11px; font-weight:700; border:none; cursor:pointer; transition:background .15s; }
.tn-qr-btn-p1 { background:#276749; color:#fff; }
.tn-qr-btn-p1:hover { background:#22543d; }
.tn-qr-btn-p2 { background:#3182ce; color:#fff; }
.tn-qr-btn-p2:hover { background:#2b6cb0; }
.tn-qr-btn-tie { background:#e2e8f0; color:#4a5568; }
.tn-qr-btn-tie:hover { background:#cbd5e0; }
.tn-qr-more { font-size:11px; color:#3182ce; cursor:pointer; text-decoration:none; margin-left:auto; flex-shrink:0; }
.tn-qr-more:hover { text-decoration:underline; }
.tn-bv-match.tn-qr-expanded { border-color:#276749; box-shadow:0 2px 8px rgba(39,103,73,0.18); }

/* ── Bout Score Pill ── */
.tn-bout-score-pill { display:inline-flex; align-items:center; justify-content:center; font-size:10px; font-weight:800; padding:2px 8px; border-radius:10px; background:#c6f6d5; color:#276749; margin-top:2px; }

/* ── Round Status Badge ── */

/* ── Enhanced Seed Display ── */
.tn-seed-enhanced { width:24px; height:24px; background:linear-gradient(135deg,#276749,#38a169); color:#fff; border-radius:50%; display:flex; align-items:center; justify-content:center; font-size:10px; font-weight:800; flex-shrink:0; box-shadow:0 1px 3px rgba(0,0,0,0.12); transition:transform .15s,box-shadow .15s; }
.tn-dnd-list li[draggable='true']:hover .tn-seed-enhanced { transform:scale(1.1); box-shadow:0 2px 6px rgba(39,103,73,0.25); }
.tn-dnd-over .tn-seed-enhanced { background:linear-gradient(135deg,#d69e2e,#ecc94b); }

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
				<button class="tn-btn tn-btn-outline" style="color:#fff;border-color:rgba(255,255,255,0.4)" onclick="tnOpenEditTournamentModal()">
					<i class="fas fa-pencil-alt"></i> Edit
				</button>
				<button class="tn-btn tn-btn-outline" style="color:#fff;border-color:rgba(255,255,255,0.4)" onclick="tnOpenAddBracketModal()">
					<i class="fas fa-plus"></i> Add Bracket
				</button>
				<?php if ($totalMatches > 0): ?>
				<button class="tn-btn tn-btn-primary" style="background:#fff;color:#276749;font-weight:700" onclick="tnActivateTab('bracketviz')">
					<i class="fas fa-play"></i> Run Tourney
				</button>
				<?php endif; ?>
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
		<div class="tn-stat-value" id="tn-stat-participants"><?= $totalParticipants ?></div>
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
					<i class="fas fa-project-diagram"></i> Run Tournament
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
				<?php if ($totalBrackets > 1): ?>
				<div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:14px;gap:10px">
					<button class="tn-btn tn-btn-ghost tn-btn-sm" onclick="tnToggleAllBrackets()" id="tn-toggle-all-btn">
						<i class="fas fa-compress-alt"></i> <span>Collapse All</span>
					</button>
					<?php if ($canManage): ?>
					<button class="tn-btn tn-btn-primary tn-btn-sm" onclick="tnOpenAddBracketModal()">
						<i class="fas fa-plus"></i> Add Bracket
					</button>
					<?php endif; ?>
				</div>
				<?php elseif ($canManage): ?>
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
					<div class="tn-bracket-card" id="tn-bracket-<?= $bid ?>" data-method="<?= htmlspecialchars($b['Method']) ?>" data-status="<?= htmlspecialchars($b['Status'] ?: 'setup') ?>">
						<div class="tn-bracket-header">
							<button class="tn-bracket-toggle" onclick="tnToggleBracket(<?= $bid ?>)" title="Collapse/expand"><i class="fas fa-chevron-down"></i></button>
							<div style="flex:1">
								<div style="display:flex;align-items:center;gap:8px;flex-wrap:wrap">
							<h4 style="margin:0"><?= htmlspecialchars($styleLabelMap[$b['Style']] ?? $b['Style']) ?></h4>
							<?php
							$_bStatus = $b['Status'] ?? 'setup';
							if ($_bStatus === '' || $_bStatus === 'setup'):
							?>
							<span class="tn-bracket-status tn-bracket-status-setup"><i class="fas fa-cog"></i> Setup</span>
							<?php elseif ($_bStatus === 'active'): ?>
							<span class="tn-bracket-status tn-bracket-status-active"><i class="fas fa-circle" style="font-size:8px"></i> Live</span>
							<?php elseif ($_bStatus === 'complete'): ?>
							<span class="tn-bracket-status tn-bracket-status-complete"><i class="fas fa-check-circle"></i> Complete</span>
							<?php elseif ($_bStatus === 'finalized'): ?>
							<span class="tn-bracket-status tn-bracket-status-finalized"><i class="fas fa-lock"></i> Finalized</span>
							<?php endif; ?>
						</div>
								<div class="tn-bracket-meta">
									<span><i class="fas fa-project-diagram"></i> <?= htmlspecialchars($methodLabelMap[$b['Method']] ?? $b['Method']) ?></span>
									<?php if (($b['Participants'] ?? 'individual') === 'team'):
										$_teamIds = array_unique(array_column($pList, 'ParticipantId'));
										$_teamCount = count($_teamIds);
										$_memberCount = count($pList);
									?>
									<span title="Teams"><i class="fas fa-users" style="color:#3182ce"></i> <?= $_teamCount ?></span>
									<span title="Individual Members"><i class="fas fa-user" style="color:#805ad5"></i> <?= $_memberCount ?></span>
									<?php else: ?>
									<span title="Individual Participants"><i class="fas fa-user" style="color:#805ad5"></i> <?= count($pList) ?></span>
									<?php endif; ?>
									<?php if ((int)$b['Rings'] > 1): ?>
									<span><i class="fas fa-circle"></i> <?= (int)$b['Rings'] ?> rings</span>
									<?php endif; ?>
								</div>
								<div class="tn-bracket-meta">
									<?php $seedingLabels = ['warrior'=>'Orders of the Warrior','glicko2'=>'Performance Score','random-manual'=>'Random + Manual','glicko2-manual'=>'Performance + Manual']; ?>
									<?php if (isset($seedingLabels[$b['Seeding']])): ?>
									<span><i class="fas fa-random"></i> Seeding: <?= htmlspecialchars($seedingLabels[$b['Seeding']]) ?></span>
									<?php endif; ?>
								</div>
							</div>
							<?php if ($canManage): ?>
							<div style="display:flex;gap:6px;align-items:center;flex-wrap:wrap">
								<button class="tn-btn tn-btn-outline tn-btn-sm" onclick="tnOpenEditBracketModal(<?= $bid ?>, <?= htmlspecialchars(json_encode(['style'=>$b['Style'],'styleNote'=>$b['StyleNote'],'method'=>$b['Method'],'rings'=>(int)$b['Rings'],'participants'=>$b['Participants'],'seeding'=>$b['Seeding'],'durationMinutes'=>(int)($b['DurationMinutes']??0)]), ENT_QUOTES) ?>)">
									<i class="fas fa-pencil-alt"></i> Edit
								</button>
								<button class="tn-btn tn-btn-outline tn-btn-sm" onclick="tnCopyBracket(<?= $bid ?>, <?= $tid ?>)" title="Duplicate this bracket with its participants">
									<i class="fas fa-copy"></i> Copy
								</button>
								<?php if (($b['Participants'] ?? 'individual') === 'team'): ?>
								<button class="tn-btn tn-btn-outline tn-btn-sm" onclick="tnOpenAddTeamModal(<?= $bid ?>, <?= $tid ?>)">
									<i class="fas fa-users"></i> Add Team
								</button>
								<?php else: ?>
								<button class="tn-btn tn-btn-outline tn-btn-sm" onclick="tnOpenAddParticipantModal(<?= $bid ?>, <?= $tid ?>)">
									<i class="fas fa-user-plus"></i> Add Participant
								</button>
								<button class="tn-btn tn-btn-outline tn-btn-sm" onclick="tnOpenBulkAddModal(<?= $bid ?>, <?= $tid ?>)" title="Paste a list of aliases, one per line">
									<i class="fas fa-clipboard-list"></i> Paste Roster
								</button>
								<?php endif; ?>
								<?php if (count($pList) >= 2 && !in_array($b['Status'], ['complete', 'finalized'])): ?>
								<?php $_isRegen = $b['Status'] === 'active' && count($mList) > 0; ?>
								<button
									class="tn-btn tn-btn-primary tn-btn-sm<?= $_isRegen ? ' tn-regen-btn' : '' ?>"
									<?php if ($_isRegen): ?>data-bid="<?= $bid ?>" data-tid="<?= $tid ?>" data-match-count="<?= count($mList) ?>" onclick="tnRegenArm(this, event)"<?php else: ?>onclick="tnGenerateMatches(<?= $bid ?>, <?= $tid ?>)"<?php endif; ?>>
									<i class="fas fa-play"></i> <?= $_isRegen ? 'Re-generate' : 'Generate' ?>
								</button>
								<?php endif; ?>
								<button class="tn-btn tn-btn-danger tn-btn-sm" onclick="tnDeleteBracket(<?= $bid ?>, <?= $tid ?>)" title="Delete bracket">
									<i class="fas fa-times"></i>
								</button>
							</div>
							<?php endif; ?>
							<?php if (count($mList) > 0): ?>
							<button class="tn-btn tn-btn-primary tn-btn-sm" onclick="tnGoToBracket(<?= $bid ?>)" style="margin-left:auto">
								<i class="fas fa-play"></i> Run Tourney
							</button>
							<?php endif; ?>
						</div>
						<div class="tn-bracket-body">
							<?php if (count($pList) === 0): ?>
							<div class="tn-empty">No participants yet.</div>
							<?php elseif ($b['Status'] === 'complete' && !empty($standingsData[$bid])): ?>
<?php
	// Build lookup from ParticipantId -> full participant data (for pills + park)
	$_pLookup = [];
	foreach ($pList as $_part) { $_pLookup[(int)$_part['ParticipantId']] = $_part; }
	// Build competition-ranked placement rows with spacers for tied positions
	$_standings = $standingsData[$bid];
	$_plRows = [];
	$_plNum  = 1;
	$_i      = 0;
	while ($_i < count($_standings)) {
		$_j = $_i;
		while ($_j < count($_standings) && $_standings[$_j]['Points'] === $_standings[$_i]['Points'] && $_standings[$_j]['Losses'] === $_standings[$_i]['Losses']) $_j++;
		$_gs = $_j - $_i;
		for ($_k = $_i; $_k < $_j; $_k++) {
			$_plRows[] = ['type' => 'entry', 'pl' => $_plNum, 'data' => $_standings[$_k]];
		}
		if ($_gs > 1) for ($_k = 0; $_k < $_gs - 1; $_k++) $_plRows[] = ['type' => 'spacer'];
		$_plNum += $_gs;
		$_i = $_j;
	}
?>
							<ul class="tn-placement-list">
								<?php foreach ($_plRows as $_row): ?>
								<?php if ($_row['type'] === 'spacer'): ?>
								<li class="tn-placement-spacer" aria-hidden="true"></li>
								<?php else: $_pd = $_row['data']; $_pp = $_pLookup[(int)$_pd['ParticipantId']] ?? []; ?>
								<li>
									<span class="tn-placement-num"><?= tnOrdinal($_row['pl']) ?></span>
									<span style="flex:1"><?= htmlspecialchars($_pd['Alias'] ?? '—') ?><?= !empty($_pp) ? tnParticipantPills($_pp) : '' ?></span>
									<?php $_parkDisp = $_pp['ParkName'] ?? $_pd['ParkName'] ?? ''; ?>
									<?php if (!empty($_parkDisp)): ?>
									<span style="font-size:11px;color:#a0aec0"><?= htmlspecialchars($_parkDisp) ?></span>
									<?php endif; ?>
								</li>
								<?php endif; ?>
								<?php endforeach; ?>
							</ul>
							<?php else: ?>
<?php $isDnd = $canManage && in_array($b['Seeding'] ?? '', ['manual','random-manual']); ?>
							<ul class="tn-participant-list<?= $isDnd ? ' tn-dnd-list' : '' ?>"<?= $isDnd ? ' data-bracket-id="' . $bid . '"' : '' ?>>
								<?php foreach ($pList as $i => $p): ?>
								<?php $_pStatus = $p['Status'] ?? 'active'; $_pStatusClass = ($_pStatus !== 'active') ? ' tn-pstatus-' . htmlspecialchars($_pStatus) : ''; ?>
								<li class="<?= $_pStatusClass ?>"<?= $isDnd ? ' data-pid="' . (int)$p['ParticipantId'] . '"' : '' ?> data-participant-id="<?= (int)$p['ParticipantId'] ?>" data-status="<?= htmlspecialchars($_pStatus) ?>">
																		<?php if ($isDnd): ?><span class="tn-dnd-handle"><i class="fas fa-grip-lines"></i></span><?php endif; ?>
									<span class="<?= $isDnd ? 'tn-seed-enhanced' : 'tn-participant-seed' ?>"><?= $i + 1 ?></span>
									<span style="flex:1">
										<?php if (!empty($p['Persona'])): ?>
											<?php if ($p['MundaneId'] > 0): ?><a href="<?= UIR ?>Player/profile/<?= $p['MundaneId'] ?>" style="color:#276749;text-decoration:none"><?= htmlspecialchars($p['Alias'] ?: $p['Persona']) ?></a><?php else: ?><?= htmlspecialchars($p['Alias'] ?: $p['Persona']) ?><?php endif; ?>
											<?= tnParticipantPills($p) ?>
											<?php if ($p['Alias'] && $p['Alias'] !== $p['Persona']): ?>
												<span style="color:#a0aec0;font-size:11px">(<?= htmlspecialchars($p['Persona']) ?>)</span>
											<?php endif; ?>
										<?php else: ?>
											<?= htmlspecialchars($p['Alias'] ?: '—') ?><?= tnParticipantPills($p) ?>
										<?php endif; ?>
										<?php if ($_pStatus === 'withdrawn'): ?><span class="tn-pstatus-pill tn-pstatus-pill-withdrawn">WD</span><?php endif; ?>
										<?php if ($_pStatus === 'disqualified'): ?><span class="tn-pstatus-pill tn-pstatus-pill-disqualified">DQ</span><?php endif; ?>
																			</span>
									<?php if (!empty($p['ParkName'])): ?>
									<span style="font-size:11px;color:#a0aec0"><?= htmlspecialchars($p['ParkName']) ?></span>
									<?php endif; ?>
									<?php if ($canManage): ?>
									<span class="tn-status-wrap"><button class="tn-status-btn" onclick="tnToggleParticipantMenu(this)" title="Set status">&#8942;</button><div class="tn-status-menu"><div class="tn-status-menu-item<?= $_pStatus==='active'?' tn-sm-active':'' ?>" onclick="tnSetParticipantStatus(<?= (int)$p['ParticipantId'] ?>, 'active', <?= $bid ?>, this)"><span class="tn-sm-dot tn-sm-dot-active"></span>Active</div><div class="tn-status-menu-item<?= $_pStatus==='withdrawn'?' tn-sm-active':'' ?>" onclick="tnSetParticipantStatus(<?= (int)$p['ParticipantId'] ?>, 'withdrawn', <?= $bid ?>, this)"><span class="tn-sm-dot tn-sm-dot-withdrawn"></span>Withdrawn</div><div class="tn-status-menu-item<?= $_pStatus==='disqualified'?' tn-sm-active':'' ?>" onclick="tnSetParticipantStatus(<?= (int)$p['ParticipantId'] ?>, 'disqualified', <?= $bid ?>, this)"><span class="tn-sm-dot tn-sm-dot-disqualified"></span>Disqualified</div></div></span>
									<button class="tn-remove-participant" data-pid="<?= (int)$p['ParticipantId'] ?>" data-bid="<?= $bid ?>" data-tid="<?= $tid ?>" title="Remove participant" onclick="tnRemoveParticipant(this)">&times;</button>
									<?php endif; ?>
								</li>
								<?php endforeach; ?>
							</ul>
							<?php endif; ?>

							<?php if (count($mList) > 0): ?>
<?php $_isIronman = ($b['Method'] === 'ironman'); $_seqId = 'tn-seq-' . $bid; ?>
							<div style="margin-top:12px;border-top:1px solid #f0f4f8;padding-top:10px">
								<div style="display:flex;align-items:center;gap:6px<?= $_isIronman ? '' : ';margin-bottom:8px' ?>">
									<span style="font-size:12px;font-weight:700;color:#718096;text-transform:uppercase;letter-spacing:0.5px;flex:1"><?= $_isIronman ? 'Match Sequence' : 'Match Results' ?></span>
									<?php if ($_isIronman): ?>
									<button onclick="tnToggleSeq('<?= $_seqId ?>')" style="background:none;border:none;color:#a0aec0;cursor:pointer;padding:2px 5px;font-size:11px;line-height:1" title="Expand/collapse sequence">
										<i class="fas fa-chevron-down" id="<?= $_seqId ?>-icon" style="transform:rotate(-90deg);transition:transform .2s"></i>
									</button>
									<?php endif; ?>
								</div>
								<div id="<?= $_seqId ?>"<?= $_isIronman ? ' style="display:none;margin-top:8px"' : '' ?>>
								<table class="tn-table">
									<thead>
										<tr>
											<th><?= $_isIronman ? 'Fight' : 'Round' ?></th>
											<th>Participant 1</th>
											<th>Result</th>
											<th>Participant 2</th>
										</tr>
									</thead>
									<tbody>
										<?php foreach ($mList as $m): ?>
										<tr>
											<td style="color:#a0aec0"><?= $_isIronman ? '#' . htmlspecialchars($m['Match'] ?? '') : 'R' . htmlspecialchars($m['Round']) ?></td>
											<td><?php if ($m['Result'] === '1-wins'): ?><i class="fas fa-circle" style="color:#38a169;font-size:8px;margin-right:5px;vertical-align:middle"></i><?php endif; ?><?= htmlspecialchars($m['Participant1Alias'] ?? '—') ?></td>
											<td style="text-align:center;color:#718096"><?= htmlspecialchars($m['Result'] ?? '—') ?></td>
											<td><?php if ($m['Result'] === '2-wins'): ?><i class="fas fa-circle" style="color:#38a169;font-size:8px;margin-right:5px;vertical-align:middle"></i><?php endif; ?><?= htmlspecialchars($m['Participant2Alias'] ?? '—') ?></td>
										</tr>
										<?php endforeach; ?>
									</tbody>
								</table>
								</div>
							</div>
							<?php elseif (count($pList) > 0): ?>
							<div class="tn-empty" style="margin-top:10px;padding-top:10px;border-top:1px solid #f0f4f8">
								No matches generated yet. Use "Generate" to create the bracket draw.
							</div>
							<?php endif; ?>
						</div>
					</div>
					<?php endforeach; ?>
				<?php endif; ?>
			</div>

			<!-- Participants Tab -->
			<div class="tn-tab-panel" id="tn-tab-participants" style="display:none">
<?php
// Build merged distinct participant list across all brackets
$_distParts = [];
foreach ($bracketData as $_bid => $_bd) {
	$_bracketLabel = $styleLabelMap[$_bd['Bracket']['Style']] ?? $_bd['Bracket']['Style'];
	$_isComplete   = in_array($_bd['Bracket']['Status'] ?? '', ['complete', 'finalized']);
	$_stLookup     = [];
	foreach ($standingsData[$_bid] ?? [] as $_sr) $_stLookup[(int)$_sr['ParticipantId']] = $_sr;
	foreach ($_bd['Participants'] as $_p) {
		$_key = (int)$_p['MundaneId'] > 0 ? 'mid:' . (int)$_p['MundaneId'] : 'alias:' . strtolower(trim($_p['Alias']));
		$_entry = $_bracketLabel;
		if ($_isComplete && isset($_stLookup[(int)$_p['ParticipantId']])) {
			$_entry .= ' (' . tnOrdinal((int)$_stLookup[(int)$_p['ParticipantId']]['Rank']) . ')';
		}
		if (!isset($_distParts[$_key])) {
			$_distParts[$_key] = $_p;
			$_distParts[$_key]['_brackets'] = [$_entry];
		} else {
			$_distParts[$_key]['_brackets'][] = $_entry;
		}
	}
}
?>
				<?php if (empty($_distParts)): ?>
				<div class="tn-empty">No participants yet.</div>
				<?php else: ?>
				<table class="tn-table">
					<thead>
						<tr>
							<th>Alias</th>
							<th>Player</th>
							<th>Park</th>
							<th>Warriors</th>
							<th>Brackets</th>
						</tr>
					</thead>
					<tbody>
						<?php foreach ($_distParts as $_p): ?>
						<tr>
							<td style="font-weight:600"><?= htmlspecialchars($_p['Alias'] ?: '—') ?></td>
							<td>
								<?php if (!empty($_p['Persona']) && (int)$_p['MundaneId'] > 0): ?>
								<a href="<?= UIR ?>Player/profile/<?= (int)$_p['MundaneId'] ?>" style="color:#276749;text-decoration:none"><?= htmlspecialchars($_p['Persona']) ?></a>
								<?php elseif (!empty($_p['Persona'])): ?>
								<?= htmlspecialchars($_p['Persona']) ?>
								<?php else: ?><span style="color:#a0aec0">—</span><?php endif; ?>
							</td>
							<td style="color:#718096"><?= htmlspecialchars(!empty($_p['ParkName']) ? $_p['ParkName'] : '—') ?></td>
							<td><?= tnParticipantPills($_p) ?: '<span style="color:#a0aec0">—</span>' ?></td>
							<td style="color:#718096;font-size:12px"><?= htmlspecialchars(implode(', ', $_p['_brackets'])) ?></td>
						</tr>
						<?php endforeach; ?>
					</tbody>
				</table>
				<?php endif; ?>
			</div>

			<!-- Run Tournament Tab -->
			<div class="tn-tab-panel" id="tn-tab-bracketviz" style="display:none">
				<?php if ($totalBrackets === 0): ?>
				<div class="tn-bv-empty">No brackets yet.</div>
				<?php else: ?>
				<input type="hidden" id="tn-bv-bracket-select" value="<?= array_key_first($bracketData) ?? 0 ?>">
				<?php if ($totalBrackets > 1): ?>
				<div class="tn-bk-pills">
					<?php $bvFirst = true; foreach ($bracketData as $bvid => $bvd): $bvb = $bvd['Bracket']; ?>
					<button class="tn-bk-pill<?= $bvFirst ? ' tn-bk-pill-active' : '' ?>" data-bid="<?= $bvid ?>" onclick="tnBracketPillClick(this, <?= $bvid ?>)"><?= htmlspecialchars($styleLabelMap[$bvb['Style']] ?? $bvb['Style']) ?> &mdash; <?= htmlspecialchars($methodLabelMap[$bvb['Method']] ?? $bvb['Method']) ?></button>
					<?php $bvFirst = false; endforeach; ?>
				</div>
				<?php endif; ?>
				<div id="tn-bv-container"></div>
				<?php endif; ?>
			</div>

			<!-- Standings Tab -->
			<?php if (!empty($standingsData)): ?>
			<div class="tn-tab-panel" id="tn-tab-standings" style="display:none">
				<!-- Pills row + gear icon -->
				<div style="display:flex;align-items:center;justify-content:space-between;gap:10px;margin-bottom:4px">
					<div class="tn-bk-pills" style="flex:1;flex-wrap:wrap">
						<button class="tn-bk-pill tn-bk-pill-active" data-bid="leaderboard" onclick="tnStandingsPillClick(this,'leaderboard')">
							<i class="fas fa-trophy" style="margin-right:5px;color:#d69e2e"></i>Leaderboard
						</button>
						<?php foreach ($standingsData as $stBid => $stRows): $stB = $bracketData[$stBid]['Bracket'] ?? []; ?>
						<button class="tn-bk-pill" data-bid="<?= $stBid ?>" onclick="tnStandingsPillClick(this,<?= $stBid ?>)"><?= htmlspecialchars($styleLabelMap[$stB['Style']] ?? $stB['Style'] ?? '') ?> &mdash; <?= htmlspecialchars($methodLabelMap[$stB['Method']] ?? $stB['Method'] ?? '') ?></button>
						<?php endforeach; ?>
					</div>
					<?php if ($canManage): ?>
					<button class="tn-btn tn-btn-ghost tn-btn-sm" onclick="tnOpenConfigStandingsModal()" title="Configure standings points" style="padding:6px 10px;flex-shrink:0">
						<i class="fas fa-cog"></i>
					</button>
					<?php endif; ?>
				</div>

				<!-- Leaderboard section (default) -->
				<div class="tn-standings-section" data-stbid="leaderboard">
					<div style="margin-bottom:10px;font-size:12px;color:#718096">
						Points awarded by final bracket placement: <span id="tn-ldb-pts-summary" style="font-weight:600;color:#276749"></span>
					</div>
					<table class="tn-table" id="tn-leaderboard-table">
						<thead>
							<tr>
								<th onclick="tnSortTable('tn-leaderboard-table',0,true)" style="cursor:pointer">Rank</th>
								<th onclick="tnSortTable('tn-leaderboard-table',1,false)" style="cursor:pointer">Participant</th>
								<th onclick="tnSortTable('tn-leaderboard-table',2,false)" style="cursor:pointer">Park</th>
								<th onclick="tnSortTable('tn-leaderboard-table',3,true)" style="cursor:pointer;text-align:center">Brackets</th>
								<th onclick="tnSortTable('tn-leaderboard-table',4,true)" style="cursor:pointer;text-align:right">Total Pts</th>
							</tr>
						</thead>
						<tbody id="tn-leaderboard-body">
							<tr><td colspan="5" style="text-align:center;color:#a0aec0;padding:20px">Computing leaderboard…</td></tr>
						</tbody>
					</table>
				</div>

				<!-- Per-bracket standings sections -->
				<?php foreach ($standingsData as $stBid => $stRows): ?>
				<?php $_stBracket = $bracketData[$stBid]['Bracket'] ?? []; $_stIsIronman = (($_stBracket['Method'] ?? '') === 'ironman'); ?>
				<div class="tn-standings-section" data-stbid="<?= $stBid ?>" style="display:none">
					<?php if (empty($stRows)): ?>
					<div class="tn-empty">No standings yet.</div>
					<?php else: ?>
					<table class="tn-table" id="tn-standings-table-<?= $stBid ?>">
						<thead>
							<tr>
								<th style="cursor:pointer" onclick="tnSortTable('tn-standings-table-<?= $stBid ?>',0,true)">Rank</th>
								<th style="cursor:pointer" onclick="tnSortTable('tn-standings-table-<?= $stBid ?>',1,false)">Participant</th>
								<th style="cursor:pointer" onclick="tnSortTable('tn-standings-table-<?= $stBid ?>',2,false)">Park</th>
								<th style="cursor:pointer;text-align:center" onclick="tnSortTable('tn-standings-table-<?= $stBid ?>',3,true)">Wins</th>
								<?php if ($_stIsIronman): ?>
								<th style="cursor:pointer;text-align:center" onclick="tnSortTable('tn-standings-table-<?= $stBid ?>',4,true)">Max Streak</th>
								<th style="cursor:pointer;text-align:center" onclick="tnSortTable('tn-standings-table-<?= $stBid ?>',5,true)">Cur Streak</th>
								<th style="cursor:pointer;text-align:right" onclick="tnSortTable('tn-standings-table-<?= $stBid ?>',6,true)">Place Pts</th>
								<?php else: ?>
								<th style="cursor:pointer;text-align:center" onclick="tnSortTable('tn-standings-table-<?= $stBid ?>',4,true)">L</th>
								<th style="cursor:pointer;text-align:center" onclick="tnSortTable('tn-standings-table-<?= $stBid ?>',5,true)">T</th>
								<th style="cursor:pointer;text-align:center" onclick="tnSortTable('tn-standings-table-<?= $stBid ?>',6,true)">Byes</th>
								<th style="cursor:pointer;text-align:center" onclick="tnSortTable('tn-standings-table-<?= $stBid ?>',7,true)">Pts</th>
								<th style="cursor:pointer;text-align:right" onclick="tnSortTable('tn-standings-table-<?= $stBid ?>',8,true)">Place Pts</th>
								<?php endif; ?>
							</tr>
						</thead>
						<tbody>
							<?php
							$_stPrev = null;
							foreach ($stRows as $stRow):
								$_isTied    = $_stPrev !== null && $stRow['Rank'] === $_stPrev['Rank'];
								$_stRank    = (int)$stRow['Rank'];
								$_placePts  = ($_stRank >= 1 && $_stRank <= 8) ? (int)($standingsPoints[$_stRank - 1] ?? 0) : 0;
								if ($_stPrev !== null && $stRow['Rank'] !== $_stPrev['Rank'] && isset($_stTieCount) && $_stTieCount > 1):
									$_colspan = $_stIsIronman ? 7 : 9;
									for ($_si = 0; $_si < $_stTieCount - 1; $_si++): ?>
							<tr class="tn-standings-spacer"><td colspan="<?= $_colspan ?>"></td></tr>
								<?php endfor;
								endif;
								if ($_stPrev === null || $stRow['Rank'] !== $_stPrev['Rank']) $_stTieCount = 0;
								$_stTieCount++;
								$_stPrev = $stRow;
							?>
							<tr>
								<td style="color:#a0aec0;font-weight:700"><?= $_stRank ?></td>
								<td style="font-weight:600"><?= htmlspecialchars($stRow['Alias'] ?? '—') ?><?= tnParticipantPills($stRow) ?></td>
								<td style="color:#718096"><?= htmlspecialchars($stRow['ParkName'] ?? '') ?: '—' ?></td>
								<td style="text-align:center;color:#276749;font-weight:700"><?= (int)$stRow['Wins'] ?></td>
								<?php if ($_stIsIronman): ?>
								<td style="text-align:center;font-weight:700;color:#d69e2e"><?= (int)($stRow['MaxStreak'] ?? 0) ?></td>
								<td style="text-align:center;color:#276749"><?= (int)($stRow['CurrentStreak'] ?? 0) ?></td>
								<?php else: ?>
								<td style="text-align:center;color:#e53e3e"><?= (int)$stRow['Losses'] ?></td>
								<td style="text-align:center;color:#718096"><?= (int)$stRow['Ties'] ?></td>
								<td style="text-align:center;color:#a0aec0"><?= (int)$stRow['Byes'] ?></td>
								<td style="text-align:center;font-weight:800;color:#1a202c"><?= (int)$stRow['Points'] ?></td>
								<?php endif; ?>
								<td style="text-align:right;font-weight:800;color:#276749" data-place-rank="<?= $_stRank ?>"><?= $_placePts ?></td>
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
					<option value="warrior">Orders of the Warrior</option>
					<option value="glicko2">Performance Score</option>
					<option value="random-manual">Random + Manual Adjust</option>
					<option value="glicko2-manual">Performance + Manual Adjust</option>
				</select>
			</div>
			<div class="tn-field" id="tn-addbracket-duration-field" style="display:none">
				<label for="tn-addbracket-duration">Max Duration <span style="color:#a0aec0;font-size:11px;font-weight:400">(minutes, 0 = unlimited)</span></label>
				<input type="number" id="tn-addbracket-duration" value="0" min="0" max="480">
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
     Edit Bracket Modal
     ============================================= -->
<div class="tn-overlay" id="tn-editbracket-overlay">
	<div class="tn-modal-box" style="width:520px;max-width:calc(100vw - 40px)">
		<div class="tn-modal-header">
			<h3 class="tn-modal-title"><i class="fas fa-pencil-alt" style="margin-right:8px;color:#276749"></i>Edit Bracket</h3>
			<button class="tn-modal-close" id="tn-editbracket-close">&times;</button>
		</div>
		<div class="tn-modal-body">
			<div id="tn-editbracket-feedback" class="tn-feedback"></div>
			<input type="hidden" id="tn-editbracket-bid">
			<div class="tn-field-row">
				<div class="tn-field">
					<label for="tn-editbracket-style">Weapon Style <span style="color:#e53e3e">*</span></label>
					<select id="tn-editbracket-style">
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
					<label for="tn-editbracket-method">Format <span style="color:#e53e3e">*</span></label>
					<select id="tn-editbracket-method">
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
					<label for="tn-editbracket-participants">Participants</label>
					<select id="tn-editbracket-participants">
						<option value="individual">Individual</option>
						<option value="team">Team</option>
					</select>
				</div>
				<div class="tn-field">
					<label for="tn-editbracket-rings">Rings (concurrent)</label>
					<input type="number" id="tn-editbracket-rings" value="1" min="1" max="20">
				</div>
			</div>
			<div class="tn-field">
				<label for="tn-editbracket-seeding">Seeding</label>
				<select id="tn-editbracket-seeding">
					<option value="random">Random</option>
					<option value="manual">Manual</option>
					<option value="warrior">Orders of the Warrior</option>
					<option value="glicko2">Performance Score</option>
					<option value="random-manual">Random + Manual Adjust</option>
					<option value="glicko2-manual">Performance + Manual Adjust</option>
				</select>
			</div>
			<div class="tn-field" id="tn-editbracket-duration-field" style="display:none">
				<label for="tn-editbracket-duration">Max Duration <span style="color:#a0aec0;font-size:11px;font-weight:400">(minutes, 0 = unlimited)</span></label>
				<input type="number" id="tn-editbracket-duration" value="0" min="0" max="480">
			</div>
			<div class="tn-field">
				<label for="tn-editbracket-stylenote">Style Note <span style="color:#a0aec0;font-size:11px;font-weight:400">(optional)</span></label>
				<input type="text" id="tn-editbracket-stylenote" placeholder="e.g. No shields allowed, florentine only…" maxlength="255">
			</div>
		</div>
		<div class="tn-modal-footer">
			<button class="tn-btn tn-btn-ghost" id="tn-editbracket-cancel">Cancel</button>
			<button class="tn-btn tn-btn-primary" id="tn-editbracket-submit">
				<i class="fas fa-save"></i> Save Changes
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
		<div id="tn-quickadd-section" style="display:none;margin-top:0;border-top:1px solid #e2e8f0;padding:12px 20px 4px">
			<div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:8px">
				<div style="font-size:11px;font-weight:700;color:#718096;text-transform:uppercase;letter-spacing:0.5px">Quick Add from other brackets</div>
				<button id="tn-quickadd-addall" class="tn-btn tn-btn-outline tn-btn-sm" style="padding:2px 10px"><i class="fas fa-users"></i> Add All</button>
			</div>
			<div id="tn-quickadd-list" style="max-height:180px;overflow-y:auto"></div>
		</div>
		<div class="tn-modal-footer">
			<button class="tn-btn tn-btn-ghost" id="tn-addparticipant-cancel">Cancel</button>
			<button class="tn-btn tn-btn-primary" id="tn-addparticipant-submit">
				<i class="fas fa-user-plus"></i> Add Participant
			</button>
		</div>
	</div>
</div>

<!-- =============================================
     Bulk Add (Paste Roster) Modal — one alias per line
     ============================================= -->
<div class="tn-overlay" id="tn-bulkadd-overlay">
	<div class="tn-modal-box" style="width:520px;max-width:calc(100vw - 40px)">
		<div class="tn-modal-header">
			<h3 class="tn-modal-title"><i class="fas fa-clipboard-list" style="margin-right:8px;color:#276749"></i>Paste Roster</h3>
			<button class="tn-modal-close" id="tn-bulkadd-close">&times;</button>
		</div>
		<div class="tn-modal-body">
			<div id="tn-bulkadd-feedback" class="tn-feedback"></div>
			<input type="hidden" id="tn-bulkadd-bracket-id" value="">
			<input type="hidden" id="tn-bulkadd-tournament-id" value="<?= $tid ?>">
			<p style="margin:0 0 10px;font-size:12px;color:#718096;line-height:1.5">
				One fighter per line. Paste from a signup sheet or type as fast as you can.
				Fighters won't be linked to player profiles, but you can fix that later from the bracket card.
			</p>
			<div class="tn-field">
				<label for="tn-bulkadd-text">ALIASES <span style="color:#e53e3e">*</span></label>
				<textarea id="tn-bulkadd-text" rows="10" placeholder="Sir Galahad&#10;Morgana&#10;The Grey Wolf&#10;..." style="font-family:ui-monospace,Menlo,Consolas,monospace;font-size:13px;line-height:1.5"></textarea>
			</div>
			<div id="tn-bulkadd-progress" style="display:none;font-size:12px;color:#718096;margin-top:4px"></div>
		</div>
		<div class="tn-modal-footer">
			<button class="tn-btn tn-btn-ghost" id="tn-bulkadd-cancel">Cancel</button>
			<button class="tn-btn tn-btn-primary" id="tn-bulkadd-submit">
				<i class="fas fa-users"></i> Add All
			</button>
		</div>
	</div>
</div>
<?php endif; ?>

<!-- =============================================
     Add Team Modal (for team brackets)
     ============================================= -->
<?php if ($canManage): ?>
<div class="tn-overlay" id="tn-addteam-overlay">
	<div class="tn-modal-box" style="width:520px;max-width:calc(100vw - 40px)">
		<div class="tn-modal-header">
			<h3 class="tn-modal-title"><i class="fas fa-users" style="margin-right:8px;color:#3182ce"></i>Add Team</h3>
			<button class="tn-modal-close" id="tn-addteam-close">&times;</button>
		</div>
		<div class="tn-modal-body">
			<div id="tn-addteam-feedback" class="tn-feedback"></div>
			<input type="hidden" id="tn-addteam-bracket-id" value="">
			<input type="hidden" id="tn-addteam-tournament-id" value="<?= $tid ?>">
			<!-- Step 1: Team Name -->
			<div id="tn-addteam-step1">
				<div class="tn-field">
					<label for="tn-addteam-name">Team Name <span style="color:#e53e3e">*</span></label>
					<input type="text" id="tn-addteam-name" placeholder="Enter team name" maxlength="100">
				</div>
			</div>
			<!-- Step 2: Add Members (hidden until team name set) -->
			<div id="tn-addteam-step2" style="display:none">
				<div style="display:flex;align-items:center;gap:8px;margin-bottom:8px">
					<span style="font-size:13px;font-weight:700;color:#2d3748" id="tn-addteam-label"></span>
					<span style="font-size:11px;color:#a0aec0">&mdash; add members below</span>
				</div>
				<div id="tn-addteam-members" style="margin-bottom:12px"></div>
				<div class="tn-field" style="margin-bottom:0">
					<label>Add Member <span style="color:#a0aec0;font-size:11px;font-weight:400">(search by persona)</span></label>
					<div style="position:relative">
						<input type="text" id="tn-addteam-player-text" placeholder="Search by persona…" autocomplete="off">
						<div id="tn-addteam-player-results" class="tn-ac-results"></div>
					</div>
				</div>
			</div>
		</div>
		<!-- Quick add from other brackets -->
		<div id="tn-teamquickadd-section" style="display:none;margin-top:0;border-top:1px solid #e2e8f0;padding:12px 20px 4px">
			<div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:8px">
				<div style="font-size:11px;font-weight:700;color:#718096;text-transform:uppercase;letter-spacing:0.5px">Quick Add from other brackets</div>
			</div>
			<div id="tn-teamquickadd-list" style="max-height:180px;overflow-y:auto"></div>
		</div>
		<div class="tn-modal-footer">
			<button class="tn-btn tn-btn-ghost" id="tn-addteam-cancel">Cancel</button>
			<button class="tn-btn tn-btn-primary" id="tn-addteam-next">
				Next: Add Members <i class="fas fa-arrow-right"></i>
			</button>
			<button class="tn-btn tn-btn-primary" id="tn-addteam-submit" style="display:none">
				<i class="fas fa-check"></i> Save Team
			</button>
		</div>
	</div>
</div>
<?php endif; ?>


<!-- =============================================
     Configure Standings Modal
     ============================================= -->
<?php if ($canManage): ?>
<div class="tn-overlay" id="tn-configstandings-overlay">
	<div class="tn-modal-box" style="width:420px;max-width:calc(100vw - 40px)">
		<div class="tn-modal-header">
			<h3 class="tn-modal-title"><i class="fas fa-cog" style="margin-right:8px;color:#276749"></i>Configure Standings</h3>
			<button class="tn-modal-close" id="tn-cs-close">&times;</button>
		</div>
		<div class="tn-modal-body">
			<div id="tn-cs-feedback" class="tn-feedback"></div>
			<p style="font-size:13px;color:#718096;margin:0 0 16px">Points awarded for each final placement across all brackets.</p>
			<div style="display:grid;grid-template-columns:1fr 1fr;gap:10px">
				<?php
				$_ordinals = ['1st','2nd','3rd','4th','5th','6th','7th','8th'];
				foreach ($_ordinals as $_oi => $_oLabel):
				?>
				<div class="tn-field" style="margin:0">
					<label style="font-size:11px"><?= $_oLabel ?> Place</label>
					<input type="number" class="tn-cs-pts-input" data-idx="<?= $_oi ?>" min="0" max="999" value="<?= (int)($standingsPoints[$_oi] ?? 0) ?>" style="text-align:center">
				</div>
				<?php endforeach; ?>
			</div>
		</div>
		<div class="tn-modal-footer">
			<button class="tn-btn tn-btn-ghost" id="tn-cs-cancel">Cancel</button>
			<button class="tn-btn tn-btn-primary" id="tn-cs-submit">
				<i class="fas fa-save"></i> Save
			</button>
		</div>
	</div>
</div>
<?php endif; ?>


<!-- =============================================
     Edit Tournament Modal
     ============================================= -->
<?php if ($canManage): ?>
<div class="tn-overlay" id="tn-edittournament-overlay">
	<div class="tn-modal-box" style="width:520px;max-width:calc(100vw - 40px)">
		<div class="tn-modal-header">
			<h3 class="tn-modal-title"><i class="fas fa-pencil-alt" style="margin-right:8px;color:#276749"></i>Edit Tournament</h3>
			<button class="tn-modal-close" id="tn-edittournament-close">&times;</button>
		</div>
		<div class="tn-modal-body">
			<div id="tn-edittournament-feedback" class="tn-feedback"></div>
			<div class="tn-field">
				<label for="tn-et-name">NAME <span style="color:#e53e3e">*</span></label>
				<input type="text" id="tn-et-name" maxlength="120" placeholder="Tournament name">
			</div>
			<div class="tn-field">
				<label for="tn-et-description">ABOUT</label>
				<textarea id="tn-et-description" rows="4" placeholder="Description (optional)"></textarea>
			</div>
			<div style="display:flex;gap:14px">
				<div class="tn-field" style="flex:1">
					<label for="tn-et-date">DATE</label>
					<input type="date" id="tn-et-date">
				</div>
				<div class="tn-field" style="flex:1">
					<label for="tn-et-url">URL</label>
					<input type="url" id="tn-et-url" maxlength="255" placeholder="https://...">
				</div>
			</div>
			<div class="tn-field" style="position:relative">
				<label for="tn-et-park-text">HOST PARK</label>
				<input type="text" id="tn-et-park-text" autocomplete="off" placeholder="Search for a park...">
				<input type="hidden" id="tn-et-park-id" value="0">
				<input type="hidden" id="tn-et-kingdom-id" value="0">
				<div id="tn-et-park-results" class="kn-ac-results"></div>
				<div id="tn-et-kingdom-display" style="margin-top:4px;font-size:12px;color:#718096"></div>
			</div>
			<div class="tn-field" style="position:relative">
				<label>EVENT <span style="color:#a0aec0;font-weight:400">(optional)</span></label>
				<div style="display:flex;gap:8px;align-items:center">
					<input type="text" id="tn-et-event-text" autocomplete="off" placeholder="Search by event name..." style="flex:1">
					<button type="button" id="tn-et-event-clear" class="tn-btn tn-btn-ghost" style="padding:6px 10px;white-space:nowrap;font-size:12px">Clear</button>
				</div>
				<input type="hidden" id="tn-et-ecd-id" value="0">
				<div id="tn-et-event-results" class="kn-ac-results"></div>
			</div>
		</div>
		<div class="tn-modal-footer">
			<button class="tn-btn tn-btn-ghost" id="tn-edittournament-cancel">Cancel</button>
			<button class="tn-btn tn-btn-primary" id="tn-edittournament-submit">
				<i class="fas fa-save"></i> Save Changes
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
			<div style="background:#f7fafc;border:1px solid #e2e8f0;border-radius:8px;padding:14px 16px;margin-bottom:14px">
				<div style="display:flex;align-items:flex-start;justify-content:space-between;gap:12px">
					<div style="flex:1;text-align:center">
						<div id="tn-rr-p1-name" style="font-size:14px;font-weight:700;color:#1a202c">—</div>
						<div class="tn-bout-pips" id="tn-rr-pips-1">
							<button class="tn-bout-pip" type="button" data-side="1" data-idx="0"></button>
							<button class="tn-bout-pip" type="button" data-side="1" data-idx="1"></button>
							<button class="tn-bout-pip" type="button" data-side="1" data-idx="2"></button>
							<button class="tn-bout-pip" type="button" data-side="1" data-idx="3"></button>
							<button class="tn-bout-pip" type="button" data-side="1" data-idx="4"></button>
						</div>
					</div>
					<div style="font-size:12px;color:#a0aec0;font-weight:600;padding-top:4px;flex-shrink:0">vs</div>
					<div style="flex:1;text-align:center">
						<div id="tn-rr-p2-name" style="font-size:14px;font-weight:700;color:#1a202c">—</div>
						<div class="tn-bout-pips" id="tn-rr-pips-2">
							<button class="tn-bout-pip" type="button" data-side="2" data-idx="0"></button>
							<button class="tn-bout-pip" type="button" data-side="2" data-idx="1"></button>
							<button class="tn-bout-pip" type="button" data-side="2" data-idx="2"></button>
							<button class="tn-bout-pip" type="button" data-side="2" data-idx="3"></button>
							<button class="tn-bout-pip" type="button" data-side="2" data-idx="4"></button>
						</div>
					</div>
				</div>
				<div id="tn-rr-bout-score" class="tn-bout-score"></div>
				<div id="tn-rr-round-info" style="text-align:center;font-size:11px;color:#a0aec0;margin-top:4px"></div>
			</div>
			<div class="tn-field">
				<label for="tn-rr-result">RESULT <span style="color:#e53e3e">*</span></label>
				<select id="tn-rr-result">
					<option value="">— select —</option>
					<option value="1-wins" id="tn-rr-opt-p1wins">— wins</option>
					<option value="2-wins" id="tn-rr-opt-p2wins">— wins</option>
					<option value="tie">Tie</option>
					<option value="forfeit">Forfeit (P2 wins)</option>
					<option value="disqualified">Disqualified (P2 wins)</option>
				</select>
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
	uir:                  '<?= UIR ?>',
	httpService:          '<?= HTTP_SERVICE ?>',
	tournamentId:         <?= $tid ?>,
	kingdomId:            <?= $tKingdomId ?>,
	kingdomName:          <?= json_encode($tKingdomName) ?>,
	parkId:               <?= $tParkId ?>,
	parkName:             <?= json_encode($tParkName) ?>,
	tournamentName:       <?= json_encode($tName) ?>,
	tournamentDescription:<?= json_encode($tDescription) ?>,
	tournamentDate:       <?= json_encode(($tDate && substr($tDate,0,10) !== '0000-00-00') ? substr($tDate,0,10) : '') ?>,
	tournamentUrl:        <?= json_encode($tUrl) ?>,
	ecdId:                <?= $tECDId ?>,
	eventLabel:           <?= json_encode($tEventLabel) ?>,
	eventName:            <?= json_encode($tEventName) ?>,
	canManage:            <?= $canManage ? 'true' : 'false' ?>,
	loggedIn:             <?= $loggedIn ? 'true' : 'false' ?>,
	bracketData:          <?= json_encode($bracketData) ?>,
	methodLabels:         <?= json_encode($methodLabelMap) ?>,
	styleLabels:          <?= json_encode($styleLabelMap) ?>,
	standingsData:        <?= json_encode($standingsData) ?>,
	standingsPoints:      <?= json_encode($standingsPoints) ?>,
};
document.title = 'ORK 3: <?= htmlspecialchars($tName, ENT_QUOTES) ?>';
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

function tnToggleSeq(id) {
	var el   = document.getElementById(id);
	var icon = document.getElementById(id + '-icon');
	if (!el) return;
	var open = el.style.display === 'none';
	el.style.display = open ? '' : 'none';
	if (icon) icon.style.transform = open ? '' : 'rotate(-90deg)';
}

function tnToggleBracket(bid) {
	var card = document.getElementById('tn-bracket-' + bid);
	if (!card) return;
	card.classList.toggle('tn-collapsed');
	var key = 'tnCollapsed_' + TnConfig.tournamentId;
	var state = JSON.parse(sessionStorage.getItem(key) || '{}');
	state[bid] = card.classList.contains('tn-collapsed');
	sessionStorage.setItem(key, JSON.stringify(state));
}

function tnDeleteBracket(bid, tid) {
	if (!confirm('Are you sure you want to delete this bracket? If the bracket has match data associated to it, including a completed bracket, it will be completely wiped. This cannot be undone. Continue?')) return;
	var fd = new FormData();
	fd.append('BracketId', bid);
	fetch(TnConfig.uir + 'TournamentAjax/tournament/' + tid + '/deletebracket', { method:'POST', body:fd })
		.then(function(r) { return r.json(); })
		.then(function(d) {
			if (d && d.status === 0) {
				sessionStorage.setItem('tnOpenTab', 'brackets');
				window.location.reload();
			} else {
				alert((d && d.error) ? d.error : 'Failed to delete bracket.');
			}
		})
		.catch(function() { alert('Request failed. Please try again.'); });
}

// ---- Copy Bracket ----
function tnCopyBracket(bid, tid) {
	if (!confirm('Copy this bracket? This will duplicate the bracket settings and all participants into a new bracket.')) return;
	var fd = new FormData();
	fd.append('BracketId', bid);
	fetch(TnConfig.uir + 'TournamentAjax/tournament/' + tid + '/copybracket', { method:'POST', body:fd })
		.then(function(r) { return r.json(); })
		.then(function(d) {
			if (d && d.status === 0) {
				sessionStorage.setItem('tnOpenTab', 'brackets');
				window.location.reload();
			} else {
				alert((d && d.error) ? d.error : 'Failed to copy bracket.');
			}
		})
		.catch(function() { alert('Request failed. Please try again.'); });
}

// ---- Collapse/Expand All Brackets ----
function tnToggleAllBrackets() {
	var cards = document.querySelectorAll('.tn-bracket-card');
	if (!cards.length) return;
	// If any are expanded, collapse all; otherwise expand all
	var anyExpanded = false;
	cards.forEach(function(c) { if (!c.classList.contains('tn-collapsed')) anyExpanded = true; });
	var key = 'tnCollapsed_' + TnConfig.tournamentId;
	var state = {};
	cards.forEach(function(c) {
		var bid = c.id.replace('tn-bracket-', '');
		if (anyExpanded) {
			c.classList.add('tn-collapsed');
			state[bid] = true;
		} else {
			c.classList.remove('tn-collapsed');
			state[bid] = false;
		}
	});
	sessionStorage.setItem(key, JSON.stringify(state));
	// Update button label
	var btn = document.getElementById('tn-toggle-all-btn');
	if (btn) {
		var span = btn.querySelector('span');
		var icon = btn.querySelector('i');
		if (anyExpanded) {
			if (span) span.textContent = 'Expand All';
			if (icon) { icon.className = 'fas fa-expand-alt'; }
		} else {
			if (span) span.textContent = 'Collapse All';
			if (icon) { icon.className = 'fas fa-compress-alt'; }
		}
	}
}

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
					// Also update top-level stat card
					var topStat = document.getElementById('tn-stat-participants');
					if (topStat) topStat.textContent = Math.max(0, parseInt(topStat.textContent) - 1);
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

// ============================================================
// Standings: leaderboard computation + configure points modal
// ============================================================
function tnGetPlacePts(rank) {
	var sp = TnConfig.standingsPoints || [5,4,3,2,1,0,0,0];
	var idx = parseInt(rank) - 1;
	return (idx >= 0 && idx < sp.length) ? (sp[idx] || 0) : 0;
}

function tnComputeLeaderboard() {
	var sd   = TnConfig.standingsData || {};
	var bmap = TnConfig.bracketData   || {};
	var entries = {}; // key -> {Alias, MundaneId, Persona, ParkName, Points, BracketCount}
	for (var bid in sd) {
		if (!sd.hasOwnProperty(bid)) continue;
		var rows = sd[bid];
		var bLabel = '';
		if (bmap[bid] && bmap[bid].Bracket) {
			var br = bmap[bid].Bracket;
			var sl = (TnConfig.styleLabels || {})[br.Style] || br.Style || '';
			var ml = (TnConfig.methodLabels || {})[br.Method] || br.Method || '';
			bLabel = sl + (ml ? ' — ' + ml : '');
		}
		(rows || []).forEach(function(row) {
			var pts = tnGetPlacePts(row.Rank);
			var mid = parseInt(row.MundaneId) || 0;
			var key = mid > 0 ? 'mid:' + mid : 'alias:' + (row.Alias || '').toLowerCase().trim();
			if (!entries[key]) {
				entries[key] = { Alias: row.Alias || '', MundaneId: mid,
					Persona: row.Persona || '', ParkName: row.ParkName || '',
					Points: 0, BracketCount: 0, BracketLabels: [] };
			}
			entries[key].Points       += pts;
			entries[key].BracketCount++;
			entries[key].BracketLabels.push(bLabel || ('Bracket ' + bid));
		});
	}
	var list = Object.values(entries);
	list.sort(function(a, b) { return b.Points - a.Points || a.Alias.localeCompare(b.Alias); });
	var rank = 1;
	list.forEach(function(e, i) {
		if (i > 0 && list[i-1].Points !== e.Points) rank = i + 1;
		e.Rank = rank;
	});
	return list;
}

function tnRenderLeaderboard() {
	var tbody   = document.getElementById('tn-leaderboard-body');
	var summary = document.getElementById('tn-ldb-pts-summary');
	if (!tbody) return;
	var sp = TnConfig.standingsPoints || [5,4,3,2,1,0,0,0];
	if (summary) {
		var labels = ['1st','2nd','3rd','4th','5th','6th','7th','8th'];
		summary.textContent = labels.map(function(l,i){ return l+'='+sp[i]; }).filter(function(s,i){ return sp[i] > 0; }).join(', ');
	}
	var entries = tnComputeLeaderboard();
	if (!entries.length) {
		tbody.innerHTML = '<tr><td colspan="5" style="text-align:center;color:#a0aec0;padding:20px">No standings data yet.</td></tr>';
		return;
	}
	var rows = '';
	var prevRank = null;
	entries.forEach(function(e) {
		var rankCell = (e.Rank !== prevRank)
			? '<td style="color:#a0aec0;font-weight:700">' + e.Rank + '</td>'
			: '<td style="color:#e2e8f0;font-weight:700">' + e.Rank + '</td>';
		prevRank = e.Rank;
		var nameCell = e.MundaneId > 0
			? '<a href="' + TnConfig.uir + 'Player/profile/' + e.MundaneId + '" style="color:#276749;text-decoration:none;font-weight:600">' + tnEsc(e.Alias) + '</a>'
			: '<span style="font-weight:600">' + tnEsc(e.Alias) + '</span>';
		rows += '<tr>'
			+ rankCell
			+ '<td>' + nameCell + '</td>'
			+ '<td style="color:#718096">' + tnEsc(e.ParkName || '—') + '</td>'
			+ '<td style="text-align:center;color:#718096;font-size:12px">' + e.BracketCount + '</td>'
			+ '<td style="text-align:right;font-weight:800;color:#276749;font-size:15px">' + e.Points + '</td>'
			+ '</tr>';
	});
	tbody.innerHTML = rows;
}

document.addEventListener('DOMContentLoaded', function() {
	tnRenderLeaderboard();
});


// ---- Configure Standings Modal ----
(function() {
	if (!TnConfig.canManage) return;
	var OVERLAY = 'tn-configstandings-overlay';

	window.tnOpenConfigStandingsModal = function() {
		tnHideFeedback('tn-cs-feedback');
		// Pre-fill inputs from current TnConfig values
		document.querySelectorAll('.tn-cs-pts-input').forEach(function(inp) {
			var idx = parseInt(inp.dataset.idx);
			inp.value = (TnConfig.standingsPoints && TnConfig.standingsPoints[idx] !== undefined)
				? TnConfig.standingsPoints[idx] : 0;
		});
		tnOpenModal(OVERLAY);
	};

	['tn-cs-close','tn-cs-cancel'].forEach(function(id) {
		var el = document.getElementById(id);
		if (el) el.addEventListener('click', function() { tnCloseModal(OVERLAY); });
	});
	var ov = document.getElementById(OVERLAY);
	if (ov) ov.addEventListener('click', function(e) { if (e.target === ov) tnCloseModal(OVERLAY); });
	document.addEventListener('keydown', function(e) {
		if (e.key === 'Escape' && ov && ov.classList.contains('tn-open')) tnCloseModal(OVERLAY);
	});

	var submitBtn = document.getElementById('tn-cs-submit');
	if (submitBtn) {
		submitBtn.addEventListener('click', function() {
			var btn = this;
			var pts = [];
			document.querySelectorAll('.tn-cs-pts-input').forEach(function(inp) {
				pts.push(Math.max(0, parseInt(inp.value) || 0));
			});
			if (pts.length !== 8) { tnShowFeedback('tn-cs-feedback','Invalid input.',false); return; }
			btn.disabled = true;
			var fd = new FormData();
			fd.append('Points', JSON.stringify(pts));
			fetch(TnConfig.uir + 'TournamentAjax/tournament/' + TnConfig.tournamentId + '/savestandingspoints', {method:'POST',body:fd})
				.then(function(r) { return r.json(); })
				.then(function(d) {
					btn.disabled = false;
					if (d && d.status === 0) {
						TnConfig.standingsPoints = d.points || pts;
						tnRenderLeaderboard();
						// Re-render Place Pts columns on visible bracket standings
						tnUpdatePlacePtsCols();
						tnShowFeedback('tn-cs-feedback','Saved!',true);
						setTimeout(function() { tnCloseModal(OVERLAY); }, 600);
					} else {
						tnShowFeedback('tn-cs-feedback',(d&&d.error)?d.error:'Failed to save.',false);
					}
				})
				.catch(function() { btn.disabled=false; tnShowFeedback('tn-cs-feedback','Request failed.',false); });
		});
	}
})();

function tnUpdatePlacePtsCols() {
	// Update the PHP-rendered Place Pts cells in each bracket standings table
	// Cells have class tn-place-pts and data-rank attribute set below
	document.querySelectorAll('[data-place-rank]').forEach(function(el) {
		var rank = parseInt(el.dataset.placeRank) || 0;
		el.textContent = tnGetPlacePts(rank);
	});
}

<?php if ($canManage): ?>
// ---- Add Bracket Modal ----
(function() {
	var OVERLAY = 'tn-addbracket-overlay';
	var ADD_URL = TnConfig.uir + 'TournamentAjax/tournament/' + TnConfig.tournamentId + '/addbracket';

	window.tnOpenAddBracketModal = function() {
		tnHideFeedback('tn-addbracket-feedback');
		var d = document.getElementById('tn-addbracket-duration'); if (d) d.value = 0;
		var mSel = document.getElementById('tn-addbracket-method');
		var dFld = document.getElementById('tn-addbracket-duration-field');
		if (dFld && mSel) dFld.style.display = (mSel.value === 'ironman') ? '' : 'none';
		tnOpenModal(OVERLAY);
	};

	(function() {
		var mSel = document.getElementById('tn-addbracket-method');
		var dFld = document.getElementById('tn-addbracket-duration-field');
		function tnToggleAddDuration() { if (dFld) dFld.style.display = (mSel && mSel.value === 'ironman') ? '' : 'none'; }
		if (mSel) mSel.addEventListener('change', tnToggleAddDuration);
		tnToggleAddDuration();
	})();
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
			fd.append('DurationMinutes', document.getElementById('tn-addbracket-duration').value || 0);

			fetch(ADD_URL, { method:'POST', body:fd })
				.then(function(r) { return r.json(); })
				.then(function(d) {
					btn.disabled = false;
					if (d && d.status === 0) {
						tnShowFeedback('tn-addbracket-feedback', 'Bracket added!', true);
						setTimeout(function() { tnCloseModal(OVERLAY); sessionStorage.setItem('tnOpenTab','brackets'); window.location.reload(); }, 800);
					} else {
						tnShowFeedback('tn-addbracket-feedback', (d && d.error) ? d.error : 'Failed to add bracket.', false);
					}
				})
				.catch(function() { btn.disabled = false; tnShowFeedback('tn-addbracket-feedback', 'Request failed. Please try again.', false); });
		});
	}
})();

// ---- Edit Bracket Modal ----
(function() {
	var OVERLAY  = 'tn-editbracket-overlay';
	var EDIT_URL = TnConfig.uir + 'TournamentAjax/tournament/' + TnConfig.tournamentId + '/updatebracket';

	window.tnOpenEditBracketModal = function(bracketId, data) {
		tnHideFeedback('tn-editbracket-feedback');
		document.getElementById('tn-editbracket-bid').value = bracketId;
		document.getElementById('tn-editbracket-style').value        = data.style        || '';
		document.getElementById('tn-editbracket-method').value       = data.method       || 'single';
		document.getElementById('tn-editbracket-participants').value  = data.participants || 'individual';
		document.getElementById('tn-editbracket-rings').value         = data.rings        || 1;
		document.getElementById('tn-editbracket-seeding').value       = data.seeding      || 'random';
		document.getElementById('tn-editbracket-stylenote').value     = data.styleNote    || '';
		var _edur = document.getElementById('tn-editbracket-duration');
		var _edFld = document.getElementById('tn-editbracket-duration-field');
		if (_edur) _edur.value = data.durationMinutes || 0;
		if (_edFld) _edFld.style.display = (data.method === 'ironman') ? '' : 'none';
		tnOpenModal(OVERLAY);
	};

	(function() {
		var mSel = document.getElementById('tn-editbracket-method');
		var dFld = document.getElementById('tn-editbracket-duration-field');
		if (mSel) mSel.addEventListener('change', function() { if (dFld) dFld.style.display = (mSel.value === 'ironman') ? '' : 'none'; });
	})();
	['tn-editbracket-close', 'tn-editbracket-cancel'].forEach(function(id) {
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

	var submitBtn = document.getElementById('tn-editbracket-submit');
	if (submitBtn) {
		submitBtn.addEventListener('click', function() {
			var btn    = this;
			var style  = document.getElementById('tn-editbracket-style').value;
			var method = document.getElementById('tn-editbracket-method').value;
			if (!style || !method) { tnShowFeedback('tn-editbracket-feedback', 'Style and format are required.', false); return; }

			btn.disabled = true;
			var fd = new FormData();
			fd.append('BracketId',    document.getElementById('tn-editbracket-bid').value);
			fd.append('Style',        style);
			fd.append('Method',       method);
			fd.append('Participants', document.getElementById('tn-editbracket-participants').value);
			fd.append('Rings',        document.getElementById('tn-editbracket-rings').value);
			fd.append('Seeding',      document.getElementById('tn-editbracket-seeding').value);
			fd.append('StyleNote',    document.getElementById('tn-editbracket-stylenote').value);
			fd.append('DurationMinutes', document.getElementById('tn-editbracket-duration').value || 0);

			fetch(EDIT_URL, { method:'POST', body:fd })
				.then(function(r) { return r.json(); })
				.then(function(d) {
					btn.disabled = false;
					if (d && d.status === 0) {
						tnShowFeedback('tn-editbracket-feedback', 'Bracket updated!', true);
						setTimeout(function() { tnCloseModal(OVERLAY); sessionStorage.setItem('tnOpenTab','brackets'); window.location.reload(); }, 800);
					} else {
						tnShowFeedback('tn-editbracket-feedback', (d && d.error) ? d.error : 'Failed to update bracket.', false);
					}
				})
				.catch(function() { btn.disabled = false; tnShowFeedback('tn-editbracket-feedback', 'Request failed. Please try again.', false); });
		});
	}
})();

// Helper: position an autocomplete dropdown with fixed coords (breaks out of modal)
function tnFixedAcPosition(inputEl, dropdownEl) {
	var rect = inputEl.getBoundingClientRect();
	dropdownEl.style.position = 'fixed';
	dropdownEl.style.left     = rect.left + 'px';
	dropdownEl.style.width    = rect.width + 'px';
	dropdownEl.style.top      = (rect.bottom + 4) + 'px';
	dropdownEl.style.right    = '';
	dropdownEl.style.zIndex   = '9999';
}

// ---- Edit Tournament Modal ----
(function() {
	if (!TnConfig.canManage) return;
	var OVERLAY   = 'tn-edittournament-overlay';
	var parkTimer, eventTimer;

	window.tnOpenEditTournamentModal = function() {
		tnHideFeedback('tn-edittournament-feedback');
		var nameEl    = document.getElementById('tn-et-name');
		var descEl    = document.getElementById('tn-et-description');
		var dateEl    = document.getElementById('tn-et-date');
		var urlEl     = document.getElementById('tn-et-url');
		var parkTx    = document.getElementById('tn-et-park-text');
		var parkId    = document.getElementById('tn-et-park-id');
		var kId       = document.getElementById('tn-et-kingdom-id');
		var kDisp     = document.getElementById('tn-et-kingdom-display');
		var evTx      = document.getElementById('tn-et-event-text');
		var ecdEl     = document.getElementById('tn-et-ecd-id');
		if (nameEl)   nameEl.value  = TnConfig.tournamentName        || '';
		if (descEl)   descEl.value  = TnConfig.tournamentDescription || '';
		if (dateEl)   dateEl.value  = TnConfig.tournamentDate        || '';
		if (urlEl)    urlEl.value   = TnConfig.tournamentUrl         || '';
		if (parkTx)   parkTx.value  = TnConfig.parkName              || '';
		if (parkId)   parkId.value  = TnConfig.parkId                || 0;
		if (kId)      kId.value     = TnConfig.kingdomId             || 0;
		if (kDisp)    kDisp.textContent = TnConfig.kingdomName ? 'Kingdom: ' + TnConfig.kingdomName : '';
		if (evTx)     evTx.value    = TnConfig.eventLabel            || '';
		if (ecdEl)    ecdEl.value   = TnConfig.ecdId                 || 0;
		tnEtParkAcClose();
		tnEtEventAcClose();
		tnOpenModal(OVERLAY);
	};

	// ---- Park autocomplete ----
	var parkInput  = document.getElementById('tn-et-park-text');
	var parkIdEl   = document.getElementById('tn-et-park-id');
	var kIdEl      = document.getElementById('tn-et-kingdom-id');
	var kDispEl    = document.getElementById('tn-et-kingdom-display');
	var parkAcEl   = document.getElementById('tn-et-park-results');

	function tnEtParkAcClose() {
		if (parkAcEl) { parkAcEl.innerHTML = ''; parkAcEl.classList.remove('kn-ac-open'); }
	}
	function tnEtParkAcRender(parks) {
		if (!parkAcEl) return;
		parkAcEl.innerHTML = '';
		if (!parks || !parks.length) {
			parkAcEl.innerHTML = '<div class="kn-ac-item kn-ac-empty">No parks found</div>';
			if (parkInput) tnFixedAcPosition(parkInput, parkAcEl);
			parkAcEl.classList.add('kn-ac-open');
			return;
		}
		parks.forEach(function(pk) {
			var item = document.createElement('div');
			item.className = 'kn-ac-item';
			item.tabIndex = -1;
			var sub = pk.KingdomName ? ' <span style="color:#a0aec0;font-size:11px">(' + tnEsc(pk.KingdomName) + ')</span>' : '';
			item.innerHTML = tnEsc(pk.ParkName) + sub;
			item.addEventListener('mousedown', function(e) {
				e.preventDefault();
				if (parkInput) parkInput.value = pk.ParkName    || '';
				if (parkIdEl)  parkIdEl.value  = pk.ParkId      || 0;
				if (kIdEl)     kIdEl.value     = pk.KingdomId   || 0;
				if (kDispEl)   kDispEl.textContent = pk.KingdomName ? 'Kingdom: ' + pk.KingdomName : '';
				tnEtParkAcClose();
			});
			parkAcEl.appendChild(item);
		});
		if (parkInput) tnFixedAcPosition(parkInput, parkAcEl);
		parkAcEl.classList.add('kn-ac-open');
	}
	if (parkInput && parkAcEl) {
		parkInput.addEventListener('input', function() {
			var term = this.value.trim();
			if (parkIdEl) parkIdEl.value = '0';
			clearTimeout(parkTimer);
			if (term.length < 2) { tnEtParkAcClose(); return; }
			parkTimer = setTimeout(function() {
				fetch(TnConfig.uir + 'TournamentAjax/parksearch?q=' + encodeURIComponent(term))
					.then(function(r) { return r.json(); })
					.then(function(data) { tnEtParkAcRender(Array.isArray(data) ? data : []); })
					.catch(function() { tnEtParkAcClose(); });
			}, 280);
		});
		parkInput.addEventListener('blur', function() { setTimeout(tnEtParkAcClose, 200); });
	}

	// ---- Event autocomplete ----
	var evInput  = document.getElementById('tn-et-event-text');
	var evEcdEl  = document.getElementById('tn-et-ecd-id');
	var evAcEl   = document.getElementById('tn-et-event-results');
	var evClear  = document.getElementById('tn-et-event-clear');

	function tnEtEventAcClose() {
		if (evAcEl) { evAcEl.innerHTML = ''; evAcEl.classList.remove('kn-ac-open'); }
	}
	function tnEtEventAcRender(events) {
		if (!evAcEl) return;
		evAcEl.innerHTML = '';
		if (!events || !events.length) {
			evAcEl.innerHTML = '<div class="kn-ac-item kn-ac-empty">No events found</div>';
			if (evInput) tnFixedAcPosition(evInput, evAcEl);
			evAcEl.classList.add('kn-ac-open');
			return;
		}
		events.forEach(function(ev) {
			var item = document.createElement('div');
			item.className = 'kn-ac-item';
			item.tabIndex = -1;
			item.textContent = ev.Label || ev.EventName || '';
			item.addEventListener('mousedown', function(e) {
				e.preventDefault();
				if (evInput) evInput.value = ev.Label || ev.EventName || '';
				if (evEcdEl) evEcdEl.value = ev.EcdId || 0;
				tnEtEventAcClose();
			});
			evAcEl.appendChild(item);
		});
		if (evInput) tnFixedAcPosition(evInput, evAcEl);
		evAcEl.classList.add('kn-ac-open');
	}
	if (evInput && evAcEl) {
		evInput.addEventListener('input', function() {
			var term = this.value.trim();
			if (evEcdEl) evEcdEl.value = '0';
			clearTimeout(eventTimer);
			if (term.length < 2) { tnEtEventAcClose(); return; }
			eventTimer = setTimeout(function() {
				fetch(TnConfig.uir + 'TournamentAjax/eventsearch?q=' + encodeURIComponent(term))
					.then(function(r) { return r.json(); })
					.then(function(data) { tnEtEventAcRender(Array.isArray(data) ? data : []); })
					.catch(function() { tnEtEventAcClose(); });
			}, 280);
		});
		evInput.addEventListener('blur', function() { setTimeout(tnEtEventAcClose, 200); });
	}
	if (evClear) {
		evClear.addEventListener('click', function() {
			if (evInput)  evInput.value  = '';
			if (evEcdEl)  evEcdEl.value  = '0';
			tnEtEventAcClose();
		});
	}

	['tn-edittournament-close', 'tn-edittournament-cancel'].forEach(function(id) {
		var el = document.getElementById(id);
		if (el) el.addEventListener('click', function() { tnCloseModal(OVERLAY); });
	});
	var ov = document.getElementById(OVERLAY);
	if (ov) ov.addEventListener('click', function(e) { if (e.target === ov) tnCloseModal(OVERLAY); });
	document.addEventListener('keydown', function(e) {
		if (e.key === 'Escape' && ov && ov.classList.contains('tn-open')) tnCloseModal(OVERLAY);
	});

	var submitBtn = document.getElementById('tn-edittournament-submit');
	if (submitBtn) {
		submitBtn.addEventListener('click', function() {
			var btn  = this;
			var name = document.getElementById('tn-et-name').value.trim();
			if (!name) { tnShowFeedback('tn-edittournament-feedback', 'Name is required.', false); return; }
			btn.disabled = true;
			var fd = new FormData();
			fd.append('Name',                  name);
			fd.append('Description',           document.getElementById('tn-et-description').value.trim());
			fd.append('Url',                   document.getElementById('tn-et-url').value.trim());
			fd.append('When',                  document.getElementById('tn-et-date').value);
			fd.append('ParkId',                document.getElementById('tn-et-park-id').value   || 0);
			fd.append('KingdomId',             document.getElementById('tn-et-kingdom-id').value || 0);
			fd.append('EventCalendarDetailId', document.getElementById('tn-et-ecd-id').value    || 0);
			fetch(TnConfig.uir + 'TournamentAjax/tournament/' + TnConfig.tournamentId + '/updatetournament', { method: 'POST', body: fd })
				.then(function(r) { return r.json(); })
				.then(function(d) {
					btn.disabled = false;
					if (d && d.status === 0) {
						tnShowFeedback('tn-edittournament-feedback', 'Tournament updated!', true);
						setTimeout(function() { tnCloseModal(OVERLAY); window.location.reload(); }, 800);
					} else {
						tnShowFeedback('tn-edittournament-feedback', (d && d.error) ? d.error : 'Failed to save changes.', false);
					}
				})
				.catch(function() { btn.disabled = false; tnShowFeedback('tn-edittournament-feedback', 'Request failed. Please try again.', false); });
		});
	}
})();

// ---- Add Participant Modal ----
(function() {
	var OVERLAY      = 'tn-addparticipant-overlay';
	var playerTimer;
	var _addedCount  = 0;

	window.tnOpenAddParticipantModal = function(bracketId, tournamentId) {
		_addedCount = 0;
		document.getElementById('tn-addparticipant-bracket-id').value    = bracketId;
		document.getElementById('tn-addparticipant-tournament-id').value = tournamentId;
		document.getElementById('tn-addparticipant-alias').value         = '';
		document.getElementById('tn-addparticipant-player-text').value   = '';
		document.getElementById('tn-addparticipant-player-id').value     = '0';
		tnAcClose();
		tnHideFeedback('tn-addparticipant-feedback');
		tnBuildQuickAddList(bracketId, tournamentId);
		tnOpenModal(OVERLAY);
	};

	// Quick Add list — participants from other brackets not yet in target bracket
	function tnBuildQuickAddList(bracketId, tournamentId) {
		var section = document.getElementById('tn-quickadd-section');
		var panel   = document.getElementById('tn-quickadd-list');
		if (!section || !panel) return;
		panel.innerHTML = '';

		// Collect ParticipantIds already in the target bracket
		var inBracket = {};
		var bd = TnConfig.bracketData[bracketId];
		if (bd && bd.Participants) {
			bd.Participants.forEach(function(p) {
				inBracket['pid' + p.ParticipantId] = true;
				if (p.MundaneId > 0) inBracket['mid' + p.MundaneId] = true;
			});
		}

		// Gather candidates from all other brackets
		var candidates = [];
		var seen = {};
		for (var bid in TnConfig.bracketData) {
			if (parseInt(bid) === parseInt(bracketId)) continue;
			var bData = TnConfig.bracketData[bid];
			if (!bData || !bData.Participants) continue;
			bData.Participants.forEach(function(p) {
				var key = p.MundaneId > 0 ? ('mid' + p.MundaneId) : ('pid' + p.ParticipantId);
				if (!inBracket[key] && !seen[key]) {
					seen[key] = true;
					candidates.push(p);
				}
			});
		}

		if (candidates.length === 0) { section.style.display = 'none'; return; }
		section.style.display = '';

		// Wire Add All button
		var addAllBtn = document.getElementById('tn-quickadd-addall');
		if (addAllBtn) {
			addAllBtn.onclick = function() {
				var rows = document.querySelectorAll('#tn-quickadd-list .tn-quickadd-row:not(.tn-quickadd-done)');
				rows.forEach(function(row) {
					var btn = row.querySelector('button');
					if (btn && !btn.disabled) btn.click();
				});
			};
		}

		candidates.forEach(function(p) {
			var row = document.createElement('div');
			row.className = 'tn-quickadd-row';
			var nameEl = document.createElement('span');
			nameEl.className = 'tn-quickadd-name';
			nameEl.textContent = p.Alias || p.Persona || '—';
			if (p.Persona && p.Alias && p.Alias !== p.Persona) nameEl.title = p.Persona;
			var btn = document.createElement('button');
			btn.className = 'tn-btn tn-btn-outline tn-btn-sm';
			btn.style.cssText = 'padding:2px 10px;flex-shrink:0';
			btn.innerHTML = '<i class="fas fa-plus"></i> Add';
			btn.addEventListener('click', function() { tnQuickAdd(p, bracketId, tournamentId, row); });
			row.appendChild(nameEl);
			row.appendChild(btn);
			panel.appendChild(row);
		});
	}

	function tnQuickAdd(p, bracketId, tournamentId, rowEl) {
		var alias     = p.Alias || p.Persona || '';
		var mundaneId = p.MundaneId || 0;
		if (!alias) return;
		var qBtn = rowEl.querySelector('button');
		if (qBtn) qBtn.disabled = true;
		var fd = new FormData();
		fd.append('Alias', alias);
		fd.append('MundaneId', mundaneId);
		fd.append('TournamentId', tournamentId);
		fetch(TnConfig.uir + 'TournamentAjax/bracket/' + bracketId + '/addparticipant', {method:'POST', body:fd})
			.then(function(r){ return r.json(); })
			.then(function(d){
				if (d && d.status === 0) {
					_addedCount++;
					rowEl.classList.add('tn-quickadd-done');
					if (qBtn) { qBtn.innerHTML = '<i class="fas fa-check"></i>'; qBtn.disabled = true; }
					var card = document.getElementById('tn-bracket-' + bracketId);
					if (card) {
						var emptyEl = card.querySelector('.tn-bracket-body .tn-empty');
						if (emptyEl) emptyEl.remove();
						var ul = card.querySelector('.tn-participant-list');
						if (!ul) { ul = document.createElement('ul'); ul.className = 'tn-participant-list'; var body = card.querySelector('.tn-bracket-body'); if (body) body.insertBefore(ul, body.firstChild); }
						var num = ul.querySelectorAll('li').length + 1;
						var li  = document.createElement('li');
						li.innerHTML = '<span class="tn-participant-seed">' + num + '</span><span style="flex:1">' + tnEsc(alias) + '</span>' + (TnConfig.canManage ? '<button class="tn-remove-participant" data-pid="' + (d.participantId||0) + '" data-bid="' + bracketId + '" data-tid="' + TnConfig.tournamentId + '" title="Remove participant" onclick="tnRemoveParticipant(this)">&times;</button>' : '');
						ul.appendChild(li);
						var hdr = card.querySelector('.tn-bracket-header');
						if (hdr) hdr.querySelectorAll('span').forEach(function(s){ if(/\d+ participant/.test(s.textContent)) s.textContent = num + ' participant' + (num !== 1 ? 's' : ''); });
					}
				} else {
					if (qBtn) qBtn.disabled = false;
					tnShowFeedback('tn-addparticipant-feedback', (d && d.error) ? d.error : 'Failed to add.', false);
				}
			})
			.catch(function(){ if (qBtn) qBtn.disabled = false; tnShowFeedback('tn-addparticipant-feedback', 'Request failed.', false); });
	}

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

// ---- Add Team Modal (team brackets) ----
<?php if ($canManage): ?>
(function() {
	var OVERLAY = 'tn-addteam-overlay';
	var _teamMembers = [];   // [{MundaneId, Persona}]
	var _addedTeams  = 0;
	var _teamTimer;

	window.tnOpenAddTeamModal = function(bracketId, tournamentId) {
		_teamMembers = [];
		_addedTeams  = 0;
		document.getElementById('tn-addteam-bracket-id').value    = bracketId;
		document.getElementById('tn-addteam-tournament-id').value = tournamentId;
		document.getElementById('tn-addteam-name').value          = '';
		document.getElementById('tn-addteam-members').innerHTML   = '';
		tnHideFeedback('tn-addteam-feedback');
		// Show step 1, hide step 2
		document.getElementById('tn-addteam-step1').style.display  = '';
		document.getElementById('tn-addteam-step2').style.display  = 'none';
		document.getElementById('tn-addteam-next').style.display   = '';
		document.getElementById('tn-addteam-submit').style.display = 'none';
		document.getElementById('tn-teamquickadd-section').style.display = 'none';
		tnTeamAcClose();
		tnOpenModal(OVERLAY);
		setTimeout(function(){ document.getElementById('tn-addteam-name').focus(); }, 50);
	};

	// Collect mundane IDs already on teams in this bracket
	function tnGetAssignedMundaneIds(bracketId) {
		var assigned = {};
		var bd = TnConfig.bracketData[bracketId];
		if (bd && bd.Participants) {
			bd.Participants.forEach(function(p) {
				if (p.MundaneId > 0) assigned[p.MundaneId] = true;
			});
		}
		return assigned;
	}

	// Build quick-add list for team members (individuals from other brackets, minus already-assigned)
	function tnBuildTeamQuickAdd(bracketId) {
		var section = document.getElementById('tn-teamquickadd-section');
		var panel   = document.getElementById('tn-teamquickadd-list');
		if (!section || !panel) return;
		panel.innerHTML = '';

		var assigned = tnGetAssignedMundaneIds(bracketId);
		// Also exclude members already added to this team
		_teamMembers.forEach(function(m) { assigned[m.MundaneId] = true; });

		var candidates = [];
		var seen = {};
		for (var bid in TnConfig.bracketData) {
			var bData = TnConfig.bracketData[bid];
			if (!bData || !bData.Participants) continue;
			bData.Participants.forEach(function(p) {
				if (p.MundaneId > 0 && !assigned[p.MundaneId] && !seen[p.MundaneId]) {
					seen[p.MundaneId] = true;
					candidates.push(p);
				}
			});
		}

		if (candidates.length === 0) { section.style.display = 'none'; return; }
		section.style.display = '';

		candidates.forEach(function(p) {
			var row = document.createElement('div');
			row.className = 'tn-quickadd-row';
			row.dataset.mid = p.MundaneId;
			var nameEl = document.createElement('span');
			nameEl.className = 'tn-quickadd-name';
			nameEl.textContent = p.Persona || p.Alias || '—';
			var btn = document.createElement('button');
			btn.className = 'tn-btn tn-btn-outline tn-btn-sm';
			btn.style.cssText = 'padding:2px 10px;flex-shrink:0';
			btn.innerHTML = '<i class="fas fa-plus"></i> Add';
			btn.addEventListener('click', function() {
				tnAddTeamMember(p.MundaneId, p.Persona || p.Alias || '');
				row.classList.add('tn-quickadd-done');
				btn.innerHTML = '<i class="fas fa-check"></i>';
				btn.disabled = true;
			});
			row.appendChild(nameEl);
			row.appendChild(btn);
			panel.appendChild(row);
		});
	}

	function tnAddTeamMember(mundaneId, persona) {
		if (!mundaneId || mundaneId <= 0) return;
		// Deduplicate
		for (var i = 0; i < _teamMembers.length; i++) {
			if (_teamMembers[i].MundaneId == mundaneId) return;
		}
		_teamMembers.push({MundaneId: parseInt(mundaneId), Persona: persona});
		tnRenderTeamMembers();
		tnShowFeedback('tn-addteam-feedback', _teamMembers.length + ' member' + (_teamMembers.length !== 1 ? 's' : '') + ' added', true);
		// Disable matching quick-add row
		var qaRows = document.querySelectorAll('#tn-teamquickadd-list .tn-quickadd-row');
		qaRows.forEach(function(r) {
			if (r.dataset.mid == mundaneId) {
				r.classList.add('tn-quickadd-done');
				var b = r.querySelector('button');
				if (b) { b.innerHTML = '<i class="fas fa-check"></i>'; b.disabled = true; }
			}
		});
	}

	function tnRemoveTeamMember(mundaneId) {
		_teamMembers = _teamMembers.filter(function(m) { return m.MundaneId != mundaneId; });
		tnRenderTeamMembers();
		// Re-enable matching quick-add row
		var qaRows = document.querySelectorAll('#tn-teamquickadd-list .tn-quickadd-row');
		qaRows.forEach(function(r) {
			if (r.dataset.mid == mundaneId) {
				r.classList.remove('tn-quickadd-done');
				var b = r.querySelector('button');
				if (b) { b.innerHTML = '<i class="fas fa-plus"></i> Add'; b.disabled = false; }
			}
		});
	}

	function tnRenderTeamMembers() {
		var container = document.getElementById('tn-addteam-members');
		container.innerHTML = '';
		if (_teamMembers.length === 0) {
			container.innerHTML = '<div style="font-size:12px;color:#a0aec0;padding:4px 0">No members added yet</div>';
			return;
		}
		_teamMembers.forEach(function(m) {
			var tag = document.createElement('span');
			tag.style.cssText = 'display:inline-flex;align-items:center;gap:4px;background:#ebf8ff;color:#2b6cb0;border:1px solid #bee3f8;border-radius:12px;padding:3px 10px;font-size:12px;font-weight:600;margin:2px 4px 2px 0';
			tag.innerHTML = '<i class="fas fa-user" style="font-size:10px"></i> ' + tnEsc(m.Persona);
			var x = document.createElement('button');
			x.style.cssText = 'background:none;border:none;color:#2b6cb0;cursor:pointer;font-size:14px;line-height:1;padding:0 0 0 4px';
			x.innerHTML = '&times;';
			x.title = 'Remove';
			x.addEventListener('click', function() { tnRemoveTeamMember(m.MundaneId); });
			tag.appendChild(x);
			container.appendChild(tag);
		});
	}

	// Autocomplete for team member search
	var teamPlayerInput = document.getElementById('tn-addteam-player-text');
	var teamResultsEl   = document.getElementById('tn-addteam-player-results');

	function tnTeamAcClose() {
		if (!teamResultsEl) return;
		teamResultsEl.classList.remove('tn-ac-open');
		teamResultsEl.innerHTML = '';
	}

	function tnTeamAcRender(players) {
		teamResultsEl.innerHTML = '';
		var bracketId = document.getElementById('tn-addteam-bracket-id').value;
		var assigned = tnGetAssignedMundaneIds(bracketId);
		_teamMembers.forEach(function(m) { assigned[m.MundaneId] = true; });

		var filtered = (players || []).filter(function(pl) {
			var mid = pl.MundaneId || pl.mundane_id || 0;
			return mid > 0 && !assigned[mid];
		});

		if (!filtered.length) {
			teamResultsEl.innerHTML = '<div class="tn-ac-item tn-ac-empty">No players found</div>';
			teamResultsEl.classList.add('tn-ac-open');
			return;
		}
		filtered.forEach(function(pl) {
			var item = document.createElement('div');
			item.className = 'tn-ac-item';
			item.tabIndex = -1;
			var label = tnEsc(pl.Persona || pl.Name || '');
			var sub   = pl.KAbbr ? (' <span style="color:#a0aec0;font-size:11px">(' + tnEsc(pl.KAbbr) + (pl.PAbbr ? ':' + tnEsc(pl.PAbbr) : '') + ')</span>') : '';
			item.innerHTML = label + sub;
			item.addEventListener('mousedown', function(e) {
				e.preventDefault();
				var mid  = pl.MundaneId || pl.mundane_id || 0;
				var name = pl.Persona || pl.Name || '';
				tnAddTeamMember(mid, name);
				teamPlayerInput.value = '';
				tnTeamAcClose();
			});
			teamResultsEl.appendChild(item);
		});
		teamResultsEl.classList.add('tn-ac-open');
	}

	if (teamPlayerInput && teamResultsEl) {
		teamPlayerInput.addEventListener('input', function() {
			var term = this.value.trim();
			clearTimeout(_teamTimer);
			if (term.length < 2) { tnTeamAcClose(); return; }
			_teamTimer = setTimeout(function() {
				if (TnConfig.kingdomId > 0) {
					fetch(TnConfig.uir + 'KingdomAjax/playersearch/' + TnConfig.kingdomId + '&q=' + encodeURIComponent(term))
						.then(function(r) { return r.json(); })
						.then(function(data) { tnTeamAcRender(data); })
						.catch(function() { tnTeamAcClose(); });
				} else {
					fetch(TnConfig.httpService + 'Search/SearchService.php?Action=Search%2FPlayer&type=PERSONA&search=' + encodeURIComponent(term) + '&limit=10')
						.then(function(r) { return r.json(); })
						.then(function(data) { tnTeamAcRender(data.Players || data.Results || []); })
						.catch(function() { tnTeamAcClose(); });
				}
			}, 280);
		});
		teamPlayerInput.addEventListener('blur', function() { setTimeout(tnTeamAcClose, 200); });
	}

	// Next button: advance from step 1 (team name) to step 2 (add members)
	document.getElementById('tn-addteam-next').addEventListener('click', function() {
		var name = document.getElementById('tn-addteam-name').value.trim();
		if (!name) { tnShowFeedback('tn-addteam-feedback', 'Team name is required.', false); return; }
		document.getElementById('tn-addteam-step1').style.display  = 'none';
		document.getElementById('tn-addteam-step2').style.display  = '';
		document.getElementById('tn-addteam-next').style.display   = 'none';
		document.getElementById('tn-addteam-submit').style.display = '';
		document.getElementById('tn-addteam-label').textContent = name;
		tnHideFeedback('tn-addteam-feedback');
		tnRenderTeamMembers();
		var bracketId = document.getElementById('tn-addteam-bracket-id').value;
		tnBuildTeamQuickAdd(bracketId);
		setTimeout(function(){ if (teamPlayerInput) teamPlayerInput.focus(); }, 50);
	});

	// Submit: create team participant with Members array
	document.getElementById('tn-addteam-submit').addEventListener('click', function() {
		var btn          = this;
		var teamName     = document.getElementById('tn-addteam-name').value.trim();
		var bracketId    = document.getElementById('tn-addteam-bracket-id').value;
		var tournamentId = document.getElementById('tn-addteam-tournament-id').value;

		if (!teamName) { tnShowFeedback('tn-addteam-feedback', 'Team name is required.', false); return; }
		if (_teamMembers.length === 0) { tnShowFeedback('tn-addteam-feedback', 'Add at least one member to the team.', false); return; }

		btn.disabled = true;
		var fd = new FormData();
		fd.append('Alias', teamName);
		fd.append('MundaneId', 0);
		fd.append('TournamentId', tournamentId);
		fd.append('Members', JSON.stringify(_teamMembers));

		fetch(TnConfig.uir + 'TournamentAjax/bracket/' + bracketId + '/addparticipant', {method:'POST', body:fd})
			.then(function(r){ return r.json(); })
			.then(function(d){
				btn.disabled = false;
				if (d && d.status === 0) {
					_addedTeams++;
					tnShowFeedback('tn-addteam-feedback', 'Team "' + tnEsc(teamName) + '" saved! (' + _addedTeams + ' team' + (_addedTeams !== 1 ? 's' : '') + ' added) — add another or close when done.', true);
					// Update local bracketData so assigned IDs are tracked for subsequent adds
					if (TnConfig.bracketData[bracketId]) {
						if (!TnConfig.bracketData[bracketId].Participants) TnConfig.bracketData[bracketId].Participants = [];
						_teamMembers.forEach(function(m) {
							TnConfig.bracketData[bracketId].Participants.push({MundaneId: m.MundaneId, Persona: m.Persona, Alias: teamName, ParticipantId: d.participantId || 0});
						});
					}
					// Reset for next team
					_teamMembers = [];
					document.getElementById('tn-addteam-name').value = '';
					document.getElementById('tn-addteam-members').innerHTML = '';
					document.getElementById('tn-addteam-step1').style.display  = '';
					document.getElementById('tn-addteam-step2').style.display  = 'none';
					document.getElementById('tn-addteam-next').style.display   = '';
					document.getElementById('tn-addteam-submit').style.display = 'none';
					document.getElementById('tn-teamquickadd-section').style.display = 'none';
					setTimeout(function(){ document.getElementById('tn-addteam-name').focus(); }, 50);
				} else {
					tnShowFeedback('tn-addteam-feedback', (d && d.error) ? d.error : 'Failed to save team.', false);
				}
			})
			.catch(function(){
				btn.disabled = false;
				tnShowFeedback('tn-addteam-feedback', 'Request failed.', false);
			});
	});

	// Close/cancel handlers — reload if teams were added
	var teamOv = document.getElementById(OVERLAY);
	if (teamOv) {
		teamOv.addEventListener('click', function(e) {
			if (e.target === teamOv) {
				tnCloseModal(OVERLAY);
				if (_addedTeams > 0) { _addedTeams = 0; window.location.reload(); }
			}
		});
	}
	['tn-addteam-close','tn-addteam-cancel'].forEach(function(id) {
		var el = document.getElementById(id);
		if (el) el.addEventListener('click', function() {
			tnCloseModal(OVERLAY);
			if (_addedTeams > 0) { _addedTeams = 0; window.location.reload(); }
		});
	});
})();
<?php endif; ?>

// ============================================================
// Standings: bracket selector + sortable columns
// ============================================================
window.tnBracketPillClick = function(btn, bracketId) {
	document.querySelectorAll('.tn-bk-pills .tn-bk-pill').forEach(function(b) { b.classList.remove('tn-bk-pill-active'); });
	btn.classList.add('tn-bk-pill-active');
	var inp = document.getElementById('tn-bv-bracket-select');
	if (inp) inp.value = bracketId;
	tnRenderBracketViz(bracketId);
};

window.tnGoToBracket = function(bracketId) {
	tnActivateTab('bracketviz');
	var inp = document.getElementById('tn-bv-bracket-select');
	if (inp) inp.value = bracketId;
	document.querySelectorAll('#tn-tab-bracketviz .tn-bk-pill').forEach(function(b) {
		b.classList.toggle('tn-bk-pill-active', parseInt(b.dataset.bid) === bracketId);
	});
	tnRenderBracketViz(bracketId);
};

window.tnStandingsPillClick = function(btn, bracketId) {
	btn.closest('.tn-bk-pills').querySelectorAll('.tn-bk-pill').forEach(function(b) { b.classList.remove('tn-bk-pill-active'); });
	btn.classList.add('tn-bk-pill-active');
	tnShowStandings(bracketId);
};

window.tnShowStandings = function(bracketId) {
	var bid = String(bracketId);
	document.querySelectorAll('.tn-standings-section').forEach(function(s) {
		s.style.display = s.dataset.stbid === bid ? '' : 'none';
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
					var seedEl = item.querySelector('.tn-seed-enhanced') || item.querySelector('.tn-participant-seed'); if (seedEl) seedEl.textContent = idx + 1;
					newOrder.push(item.dataset.pid);
				});
				// Save new order
				var url = TnConfig.uir + 'TournamentAjax/bracket/' + bracketId + '/reorder';
				var fd  = new FormData();
				fd.append('Order', JSON.stringify(newOrder));
					fd.append('TournamentId', TnConfig.tournamentId);
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

	// Build pre-generate stats from TnConfig data
	var bd = TnConfig.bracketData[bracketId];
	if (!bd) { alert('Bracket data not found.'); return; }
	var bracket = bd.Bracket;
	var pCount  = (bd.Participants || []).length;
	var method  = bracket.Method || 'single';
	var methodLabel = TnConfig.methodLabels[method] || method;
	var styleLabel  = TnConfig.styleLabels[bracket.Style] || bracket.Style;
	var status  = bracket.Status || 'setup';
	var hasMatches = (bd.Matches || []).length > 0;

	// Calculate byes and rounds
	var byes = 0, rounds = 0;
	if (method === 'single' || method === 'double') {
		var slots = 1;
		while (slots < pCount) slots *= 2;
		byes = slots - pCount;
		rounds = Math.round(Math.log2(slots));
		if (method === 'double') rounds = rounds + ' WR + ' + ((rounds - 1) * 2) + ' LR + GF';
	} else if (method === 'swiss') {
		var rings = Math.max(1, parseInt(bracket.Rings) || 1);
		rounds = rings > 1 ? rings : Math.ceil(Math.log2(pCount));
	} else if (method === 'round-robin') {
		rounds = pCount % 2 === 0 ? pCount - 1 : pCount;
	}

	// Build confirmation message
	var msg = styleLabel + ' \u2014 ' + methodLabel + '\n\n';
	msg += '\u2022 Participants: ' + pCount + '\n';
	if (byes > 0) msg += '\u2022 First-round byes: ' + byes + '\n';
	if (rounds) msg += '\u2022 Rounds: ' + rounds + '\n';
	if (parseInt(bracket.Rings) > 1) msg += '\u2022 Concurrent rings: ' + bracket.Rings + '\n';
	msg += '\n';
	if (status === 'active' && hasMatches) {
		msg += '\u26a0\ufe0f WARNING: This bracket is currently ACTIVE with existing match data. Re-generating will DELETE all current matches and results.\n\n';
	}
	msg += 'Generate matches now?';

	if (!confirm(msg)) return;

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

	function tnRefreshAndRender(bracketId) {
		var tid = TnConfig.tournamentId;
		Promise.all([
			fetch(TnConfig.uir + 'TournamentAjax/bracket/' + bracketId + '/matches').then(function(r){ return r.json(); }),
			fetch(TnConfig.uir + 'TournamentAjax/tournament/' + tid + '/brackets').then(function(r){ return r.json(); })
		]).then(function(results) {
			var mData = results[0], bData = results[1];
			if (mData.status === 0 && TnConfig.bracketData[bracketId]) {
				TnConfig.bracketData[bracketId].Matches = mData.matches || [];
			}
			if (bData.status === 0 && bData.brackets && TnConfig.bracketData[bracketId]) {
				var br = bData.brackets.find(function(b) { return parseInt(b.BracketId) === parseInt(bracketId); });
				if (br) TnConfig.bracketData[bracketId].Bracket = br;
			}
			tnRenderBracketViz(bracketId);
		}).catch(function(){ tnRenderBracketViz(bracketId); });
	}

	window.tnRenderBracketViz = function(bracketId) {
		var container = document.getElementById('tn-bv-container');
		if (!container) return;
		container.innerHTML = '';
		tnBoutLabelShown = false;

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
			if (matches.length > 0) {
				var resolvable = matches.filter(function(m) { return parseInt(m.Participant1Id) > 0 && parseInt(m.Participant2Id) > 0; }).length;
				var resolved   = matches.filter(function(m) { return m.Result && m.Result !== ''; }).length;
				var ready      = resolvable - resolved;
				var progInfo = document.createElement('span');
				progInfo.className = 'tn-bv-progress-info';
				progInfo.innerHTML = resolved + '/' + resolvable + ' complete' + (ready > 0 ? ' &middot; <span class="tn-bv-pi-ready">' + ready + ' ready</span>' : '');
				bar.appendChild(progInfo);
			}
			if (participants.length >= 2 && method !== 'ironman') {
				var isRegenerate = matches.length > 0;
				var hasCompleted = isRegenerate && (typeof resolved !== 'undefined') && resolved > 0;
				var genBtn = document.createElement('button');
				genBtn.className = 'tn-btn tn-btn-primary tn-btn-sm';
				genBtn.innerHTML = '<i class="fas fa-play"></i> ' + (isRegenerate ? 'Regenerate' : 'Generate Matches');
				if (hasCompleted) {
					genBtn.disabled = true;
					genBtn.title = 'Cannot regenerate: ' + resolved + ' match' + (resolved === 1 ? '' : 'es') + ' already completed. Reset completed matches first.';
				} else {
					genBtn.onclick = function() { tnGenerateMatches(bracketId, TnConfig.tournamentId); };
				}
				bar.appendChild(genBtn);
			}
			container.appendChild(bar);
		}

		if (matches.length === 0 && method !== 'ironman') {
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
			renderElimTree(container, matches, pMap, method, bracketId);
		} else if (method === 'ironman') {
			renderIronmanView(container, matches, pMap, participants, bracketId);
		} else {
			renderRoundTable(container, matches, pMap, bracketId);
		}
	};

	// ── Elimination tree renderer ──
	function renderElimTree(container, matches, pMap, method, bracketId) {
		var wrap = document.createElement('div');
		wrap.className = 'tn-bv-wrap';
		container.appendChild(wrap);

		// Zoom controls
		var zoomLevel = 100;
		var zoomWrap = document.createElement('div');
		zoomWrap.className = 'tn-bv-zoom-controls';
		var zoomOut = document.createElement('button');
		zoomOut.className = 'tn-bv-zoom-btn'; zoomOut.innerHTML = '&minus;'; zoomOut.title = 'Zoom out';
		var zoomIn = document.createElement('button');
		zoomIn.className = 'tn-bv-zoom-btn'; zoomIn.innerHTML = '&plus;'; zoomIn.title = 'Zoom in';
		var zoomReset = document.createElement('button');
		zoomReset.className = 'tn-bv-zoom-btn'; zoomReset.innerHTML = '<i class="fas fa-compress-arrows-alt" style="font-size:11px"></i>'; zoomReset.title = 'Reset zoom';
		var zoomLabel = document.createElement('span');
		zoomLabel.className = 'tn-bv-zoom-level'; zoomLabel.textContent = '100%';
		function applyZoom() {
			zoomLabel.textContent = zoomLevel + '%';
			wrap.style.transform = 'scale(' + (zoomLevel / 100) + ')';
			wrap.style.transformOrigin = 'top left';
		}
		zoomOut.onclick = function() { zoomLevel = Math.max(40, zoomLevel - 10); applyZoom(); };
		zoomIn.onclick = function() { zoomLevel = Math.min(150, zoomLevel + 10); applyZoom(); };
		zoomReset.onclick = function() { zoomLevel = 100; applyZoom(); };
		zoomWrap.appendChild(zoomOut);
		zoomWrap.appendChild(zoomLabel);
		zoomWrap.appendChild(zoomIn);
		zoomWrap.appendChild(zoomReset);
		container.insertBefore(zoomWrap, wrap);

		// Separate sections: winners, losers, grand-final
		var sections = [
			{ key:'winners',     label:'Winners Bracket' },
			{ key:'losers',      label:'Second Chance Bracket' },
			{ key:'grand-final', label:'Grand Final' },
			
		];

		var hasSections = matches.some(function(m) { return m.BracketSide && m.BracketSide !== 'winners' && m.BracketSide !== 'tiebreaker-3rd'; });

		if (!hasSections) {
			// Single section
			renderSection(wrap, matches, pMap, null);
		} else {
			sections.forEach(function(s) {
				var sMatches = matches.filter(function(m) { var side = m.BracketSide || 'winners'; return side === s.key || (s.key === 'winners' && side === 'tiebreaker-3rd'); });
				if (!sMatches.length) return;
				var iconMap = {'winners':'fa-trophy','losers':'fa-shield-alt','grand-final':'fa-star','tiebreaker-3rd':'fa-medal'};
				var lbl = document.createElement('div');
				lbl.className = 'tn-bv-section-hdr ' + s.key;
				lbl.innerHTML = '<i class="fas ' + (iconMap[s.key] || 'fa-circle') + '"></i> ' + s.label;
				wrap.appendChild(lbl);
				if (s.key === 'losers') {
					var losersDiv = document.createElement('div');
					losersDiv.className = 'tn-bv-losers-compact';
					wrap.appendChild(losersDiv);
					renderSection(losersDiv, sMatches, pMap, s.key);
				} else {
					renderSection(wrap, sMatches, pMap, s.key);
				}
			});
		}

		// Champion / podium callout when bracket is complete/finalized
		var bd0 = TnConfig.bracketData[bracketId];
		var bracketSt = bd0 && bd0.Bracket ? (bd0.Bracket.Status || '') : '';
		if (bracketSt === 'complete' || bracketSt === 'finalized') {
			var finalMatches = matches.filter(function(m) {
				var side = m.BracketSide || 'winners';
				return side === 'grand-final' || (side === 'winners' && !hasSections);
			});
			if (!finalMatches.length) finalMatches = matches.filter(function(m){ return (m.BracketSide||'winners')==='winners'; });
			var maxFR = 0;
			finalMatches.forEach(function(m){ var rr = parseInt(m.Round)||0; if(rr>maxFR) maxFR=rr; });
			var finalMatch = finalMatches.filter(function(m){ return (parseInt(m.Round)||0)===maxFR && m.Result; })[0];
			if (finalMatch) {
				var champId = (finalMatch.Result==='1-wins') ? parseInt(finalMatch.Participant1Id) : (finalMatch.Result==='2-wins') ? parseInt(finalMatch.Participant2Id) : 0;
				var runnerUpId = (finalMatch.Result==='1-wins') ? parseInt(finalMatch.Participant2Id) : (finalMatch.Result==='2-wins') ? parseInt(finalMatch.Participant1Id) : 0;
				var champ = champId ? (pMap[champId]||null) : null;
				var runner = runnerUpId ? (pMap[runnerUpId]||null) : null;
				if (champ) {
					var championBanner = document.createElement('div');
					championBanner.className = 'tn-bv-champion-banner';
					var crownIcon = document.createElement('div');
					crownIcon.className = 'tn-bv-champion-crown';
					crownIcon.innerHTML = '<i class="fas fa-trophy" style="color:#744210;font-size:28px"></i>';
					championBanner.appendChild(crownIcon);
					var champInfo = document.createElement('div');
					champInfo.className = 'tn-bv-champion-info';
					champInfo.innerHTML = '<div class="tn-bv-champion-label">Champion</div><div class="tn-bv-champion-name">' + tnEscHtml(champ.Alias || champ.Persona || 'Unknown') + '</div>' + (champ.ParkName ? '<div class="tn-bv-champion-park">' + tnEscHtml(champ.ParkName) + '</div>' : '');
					championBanner.appendChild(champInfo);
					var podium = document.createElement('div');
					podium.className = 'tn-bv-podium';
					var podiumHtml = '<div class="tn-bv-podium-card tn-bv-podium-1st"><span class="tn-bv-podium-num">1st</span> ' + tnEscHtml(champ.Alias || champ.Persona || '?') + '</div>';
					if (runner) podiumHtml += '<div class="tn-bv-podium-card tn-bv-podium-2nd"><span class="tn-bv-podium-num">2nd</span> ' + tnEscHtml(runner.Alias || runner.Persona || '?') + '</div>';
					// 3rd/4th from tiebreaker-3rd match (single elim) or semifinal losers
					var tbMatch = matches.filter(function(m) { return m.BracketSide === 'tiebreaker-3rd' && m.Result; })[0];
					if (tbMatch) {
						var thirdId = (tbMatch.Result === '1-wins') ? parseInt(tbMatch.Participant1Id) : (tbMatch.Result === '2-wins') ? parseInt(tbMatch.Participant2Id) : 0;
						var fourthId = (tbMatch.Result === '1-wins') ? parseInt(tbMatch.Participant2Id) : (tbMatch.Result === '2-wins') ? parseInt(tbMatch.Participant1Id) : 0;
						var third = thirdId ? (pMap[thirdId] || null) : null;
						var fourth = fourthId ? (pMap[fourthId] || null) : null;
						if (third) podiumHtml += '<div class="tn-bv-podium-card tn-bv-podium-3rd"><span class="tn-bv-podium-num">3rd</span> ' + tnEscHtml(third.Alias || third.Persona || '?') + '</div>';
						if (fourth) podiumHtml += '<div class="tn-bv-podium-card" style="background:#f7fafc;color:#718096;border:1px solid #e2e8f0"><span class="tn-bv-podium-num">4th</span> ' + tnEscHtml(fourth.Alias || fourth.Persona || '?') + '</div>';
					}
					podium.innerHTML = podiumHtml;
					championBanner.appendChild(podium);
					wrap.insertBefore(championBanner, wrap.firstChild);
				}
			}
		}

		// ── Grand Final confirmation match banner + inline buttons ────────────
		// Show when: double-elim, GF round-1 decided with '2-wins' (LB winner won),
		// no confirmation match yet, and organizer hasn't already waived it.
		if (method === 'double' && TnConfig.canManage) {
			var bd = TnConfig.bracketData[bracketId];
			var bracketStatus = bd && bd.Bracket ? bd.Bracket.Status : '';
			var gfMatches = matches.filter(function(m) { return m.BracketSide === 'grand-final'; });
			var gfR1 = gfMatches.filter(function(m) { return parseInt(m.Round) === 1; });
			var gfR2 = gfMatches.filter(function(m) { return parseInt(m.Round) > 1; });
			if (gfR1.length === 1 && gfR1[0].Result === '2-wins' && gfR2.length === 0 && bracketStatus !== 'finalized') {
				var tid = TnConfig.tournamentId;

				var doConfirmYes = function() {
					var fd = new FormData();
					fd.append('BracketId', bracketId);
					fetch(TnConfig.uir + 'TournamentAjax/tournament/' + tid + '/confirmationmatch', { method:'POST', body:fd })
						.then(function(r) { return r.json(); })
						.then(function(d) {
							if (d.status === 0) {
								Promise.all([
									fetch(TnConfig.uir + 'TournamentAjax/bracket/' + bracketId + '/matches').then(function(r) { return r.json(); }),
									fetch(TnConfig.uir + 'TournamentAjax/tournament/' + tid + '/brackets').then(function(r) { return r.json(); }),
								]).then(function(results) {
									var mData = results[0], bData = results[1];
									if (mData.status === 0 && TnConfig.bracketData[bracketId]) TnConfig.bracketData[bracketId].Matches = mData.matches;
									if (bData.status === 0 && bData.brackets && TnConfig.bracketData[bracketId]) {
										var br = bData.brackets.find(function(b) { return parseInt(b.BracketId) === parseInt(bracketId); });
										if (br) TnConfig.bracketData[bracketId].Bracket = br;
									}
									tnRenderBracketViz(bracketId);
								}).catch(function(err) { alert('Refresh error: ' + err); });
							} else {
								alert('Error: ' + (d.error || 'Unknown error'));
							}
						}).catch(function(err) { alert('Request failed: ' + err); });
				};

				var doConfirmNo = function() {
					var fd = new FormData();
					fd.append('BracketId', bracketId);
					fetch(TnConfig.uir + 'TournamentAjax/tournament/' + tid + '/completebracket', { method:'POST', body:fd })
						.then(function(r) { return r.json(); })
						.then(function(d) {
							if (d.status === 0) {
								if (TnConfig.bracketData[bracketId] && TnConfig.bracketData[bracketId].Bracket) {
									TnConfig.bracketData[bracketId].Bracket.Status = 'finalized';
								}
								tnRenderBracketViz(bracketId);
							} else {
								alert('Error: ' + (d.error || 'Unknown error'));
							}
						}).catch(function(err) { alert('Request failed: ' + err); });
				};

				// Yellow banner above the bracket
				var banner = document.createElement('div');
				banner.className = 'tn-gf-confirm-banner';
				banner.innerHTML =
					'<div class="tn-gf-confirm-text"><i class="fas fa-exclamation-circle"></i> The Second Chance winner claimed the Grand Final — the champion may need to lose twice. Is a confirmation match required?</div>' +
					'<div class="tn-gf-confirm-btns">' +
						'<button class="tn-gf-confirm-yes"><i class="fas fa-check-circle"></i> Confirmation Match</button>' +
						'<button class="tn-gf-confirm-no"><i class="fas fa-times-circle"></i> Tournament Complete</button>' +
					'</div>';
				wrap.insertBefore(banner, wrap.firstChild);
				banner.querySelector('.tn-gf-confirm-yes').onclick = doConfirmYes;
				banner.querySelector('.tn-gf-confirm-no').onclick = doConfirmNo;

				// Inline stacked buttons to the right of the GF match card
				var gfBox = wrap.querySelector('[data-matchid="' + gfR1[0].MatchId + '"]');
				if (gfBox && gfBox.parentElement) {
					var btnCol = document.createElement('div');
					btnCol.className = 'tn-gf-inline-btns';
					btnCol.innerHTML =
						'<button class="tn-gf-confirm-yes"><i class="fas fa-check-circle"></i> Confirmation Match</button>' +
						'<button class="tn-gf-confirm-no"><i class="fas fa-times-circle"></i> Tournament Complete</button>';
					gfBox.parentElement.appendChild(btnCol);
					btnCol.querySelector('.tn-gf-confirm-yes').onclick = doConfirmYes;
					btnCol.querySelector('.tn-gf-confirm-no').onclick = doConfirmNo;
				}
			}
		}

		// ── Single-elim 3rd place tiebreaker banner ─────────────────────────────
		// Show when: single-elim, bracket complete, at least 2 rounds (semis exist),
		// no tiebreaker-3rd match yet, and bracket is not finalized.
		if (method === 'single' && TnConfig.canManage) {
			var bd2 = TnConfig.bracketData[bracketId];
			var bracketStatus2 = bd2 && bd2.Bracket ? bd2.Bracket.Status : '';
			var hasTiebreaker = matches.some(function(m) { return m.BracketSide === 'tiebreaker-3rd'; });
			var maxWRRound = 0;
			matches.forEach(function(m) {
				if ((m.BracketSide || 'winners') === 'winners') maxWRRound = Math.max(maxWRRound, parseInt(m.Round) || 0);
			});
			if (bracketStatus2 === 'complete' && !hasTiebreaker && maxWRRound >= 2) {
				var tid2 = TnConfig.tournamentId;

				var doTiebreakerYes = function() {
					var fd = new FormData();
					fd.append('BracketId', bracketId);
					fetch(TnConfig.uir + 'TournamentAjax/tournament/' + tid2 + '/tiebreakerfor3rd', { method:'POST', body:fd })
						.then(function(r) { return r.json(); })
						.then(function(d) {
							if (d.status === 0) {
								Promise.all([
									fetch(TnConfig.uir + 'TournamentAjax/bracket/' + bracketId + '/matches').then(function(r) { return r.json(); }),
									fetch(TnConfig.uir + 'TournamentAjax/tournament/' + tid2 + '/brackets').then(function(r) { return r.json(); }),
								]).then(function(results) {
									var mData = results[0], bData = results[1];
									if (mData.status === 0 && TnConfig.bracketData[bracketId]) TnConfig.bracketData[bracketId].Matches = mData.matches;
									if (bData.status === 0 && bData.brackets && TnConfig.bracketData[bracketId]) {
										var br = bData.brackets.find(function(b) { return parseInt(b.BracketId) === parseInt(bracketId); });
										if (br) TnConfig.bracketData[bracketId].Bracket = br;
									}
									tnRenderBracketViz(bracketId);
								}).catch(function(err) { alert('Refresh error: ' + err); });
							} else {
								alert('Error: ' + (d.error || 'Unknown error'));
							}
						}).catch(function(err) { alert('Request failed: ' + err); });
				};

				var doTiebreakerNo = function() {
					var fd = new FormData();
					fd.append('BracketId', bracketId);
					fetch(TnConfig.uir + 'TournamentAjax/tournament/' + tid2 + '/completebracket', { method:'POST', body:fd })
						.then(function(r) { return r.json(); })
						.then(function(d) {
							if (d.status === 0) {
								if (TnConfig.bracketData[bracketId] && TnConfig.bracketData[bracketId].Bracket) {
									TnConfig.bracketData[bracketId].Bracket.Status = 'finalized';
								}
								tnRenderBracketViz(bracketId);
							} else {
								alert('Error: ' + (d.error || 'Unknown error'));
							}
						}).catch(function(err) { alert('Request failed: ' + err); });
				};

				// Yellow banner above the bracket
				var tbBanner = document.createElement('div');
				tbBanner.className = 'tn-gf-confirm-banner';
				tbBanner.innerHTML =
					'<div class="tn-gf-confirm-text"><i class="fas fa-medal"></i> The bracket is complete — the two semifinal runners-up are tied for 3rd place. Is a tiebreaker match needed?</div>' +
					'<div class="tn-gf-confirm-btns">' +
						'<button class="tn-gf-confirm-yes"><i class="fas fa-check-circle"></i> Tiebreaker for 3rd</button>' +
						'<button class="tn-gf-confirm-no"><i class="fas fa-times-circle"></i> Tournament Complete</button>' +
					'</div>';
				wrap.insertBefore(tbBanner, wrap.firstChild);
				tbBanner.querySelector('.tn-gf-confirm-yes').onclick = doTiebreakerYes;
				tbBanner.querySelector('.tn-gf-confirm-no').onclick = doTiebreakerNo;
			}
		}
	}

	function tnDrawBracketConnectors(tree, rounds, maxRound) {
		if (maxRound < 2) return;
		requestAnimationFrame(function() {
			var treeRect = tree.getBoundingClientRect();
			if (!treeRect.width) return;

			var svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
			svg.style.cssText = 'position:absolute;top:0;left:0;width:100%;height:100%;pointer-events:none;overflow:visible;z-index:0';

			for (var r = 1; r < maxRound; r++) {
				var srcRound = (rounds[r] || []).slice().sort(function(a,b){ return (a.Order||0)-(b.Order||0); });
				var dstRound = (rounds[r+1] || []).slice().sort(function(a,b){ return (a.Order||0)-(b.Order||0); });
				for (var i = 0; i < srcRound.length; i += 2) {
					var m1   = srcRound[i];
					var m2   = srcRound[i+1] || null;
					var mDst = dstRound[Math.floor(i/2)] || null;
					if (!mDst) continue;
					var box1   = tree.querySelector('[data-matchid="' + m1.MatchId + '"]');
					var box2   = m2  ? tree.querySelector('[data-matchid="' + m2.MatchId  + '"]') : null;
					var boxDst = tree.querySelector('[data-matchid="' + mDst.MatchId + '"]');
					if (!box1 || !boxDst) continue;

					var r1   = box1.getBoundingClientRect();
					var rDst = boxDst.getBoundingClientRect();
					var x1   = r1.right   - treeRect.left;
					var y1   = r1.top     - treeRect.top  + r1.height / 2;
					var xDst = rDst.left  - treeRect.left;
					var yDst = rDst.top   - treeRect.top  + rDst.height / 2;
					var xMid = (x1 + xDst) / 2;

					var m1Resolved = m1.Result && m1.Result !== '';
					var m2Resolved = m2 && m2.Result && m2.Result !== '';

					if (box2) {
						var r2 = box2.getBoundingClientRect();
						var x2 = r2.right - treeRect.left;
						var y2 = r2.top - treeRect.top + r2.height / 2;
						var yMid = (y1 + y2) / 2;

						var color1 = m1Resolved ? '#48bb78' : '#cbd5e0';
						var p1 = document.createElementNS('http://www.w3.org/2000/svg', 'path');
						p1.setAttribute('d', 'M'+x1+','+y1+' C'+xMid+','+y1+' '+xMid+','+yMid+' '+xMid+','+yMid);
						p1.setAttribute('stroke', color1); p1.setAttribute('stroke-width', m1Resolved ? '2.5' : '1.5');
						p1.setAttribute('fill', 'none'); p1.setAttribute('stroke-linecap', 'round');
						svg.appendChild(p1);

						var color2 = m2Resolved ? '#48bb78' : '#cbd5e0';
						var p2 = document.createElementNS('http://www.w3.org/2000/svg', 'path');
						p2.setAttribute('d', 'M'+x2+','+y2+' C'+xMid+','+y2+' '+xMid+','+yMid+' '+xMid+','+yMid);
						p2.setAttribute('stroke', color2); p2.setAttribute('stroke-width', m2Resolved ? '2.5' : '1.5');
						p2.setAttribute('fill', 'none'); p2.setAttribute('stroke-linecap', 'round');
						svg.appendChild(p2);

						var colorC = (m1Resolved && m2Resolved) ? '#48bb78' : '#cbd5e0';
						var pC = document.createElementNS('http://www.w3.org/2000/svg', 'path');
						pC.setAttribute('d', 'M'+xMid+','+yMid+' C'+((xMid+xDst)/2)+','+yMid+' '+((xMid+xDst)/2)+','+yDst+' '+xDst+','+yDst);
						pC.setAttribute('stroke', colorC); pC.setAttribute('stroke-width', (m1Resolved && m2Resolved) ? '2.5' : '1.5');
						pC.setAttribute('fill', 'none'); pC.setAttribute('stroke-linecap', 'round');
						svg.appendChild(pC);
					} else {
						var colorS = m1Resolved ? '#48bb78' : '#cbd5e0';
						var pS = document.createElementNS('http://www.w3.org/2000/svg', 'path');
						pS.setAttribute('d', 'M'+x1+','+y1+' C'+xMid+','+y1+' '+xMid+','+yDst+' '+xDst+','+yDst);
						pS.setAttribute('stroke', colorS); pS.setAttribute('stroke-width', m1Resolved ? '2.5' : '1.5');
						pS.setAttribute('fill', 'none'); pS.setAttribute('stroke-linecap', 'round');
						svg.appendChild(pS);
					}
				}
			}
			tree.insertBefore(svg, tree.firstChild);
		});
	}
	function isMatchResettable(m, allMatches) {
		var bid = m.BracketId;
		var bd  = TnConfig.bracketData[bid];
		var method = bd && bd.Bracket ? bd.Bracket.Method : '';
		if (method !== 'single' && method !== 'double') return true;
		var p1 = parseInt(m.Participant1Id) || 0;
		var p2 = parseInt(m.Participant2Id) || 0;
		var r  = parseInt(m.Round);
		return !allMatches.some(function(dm) {
			if (parseInt(dm.Round) <= r) return false;
			if (!dm.Result) return false;
			var d1 = parseInt(dm.Participant1Id) || 0;
			var d2 = parseInt(dm.Participant2Id) || 0;
			return (p1 && (d1 === p1 || d2 === p1)) || (p2 && (d1 === p2 || d2 === p2));
		});
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
			if (rMatches.length === 0) continue; // Skip empty rounds (e.g. tiebreaker-3rd has only one round)
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
			} else if (r === maxRound - 2) {
				lbl.textContent = 'Quarterfinal';
			} else {
				lbl.textContent = 'Round ' + r;
			}
			col.appendChild(lbl);

			var body = document.createElement('div');
			body.className = 'tn-bv-round-body';
			rMatches.forEach(function(m) {
				body.appendChild(buildMatchBox(m, pMap, matches));
			});
			col.appendChild(body);
			tree.appendChild(col);
		}
		wrap.appendChild(tree);
		tnDrawBracketConnectors(tree, rounds, maxRound);
	}

	// Avatar color palette (stable per participant id)
	var _tnAvatarColors = ['#276749','#2b6cb0','#6b46c1','#c05621','#b83280','#2c7a7b','#744210','#2d3748','#9b2c2c','#1a365d'];
	function tnAvatarColor(pid) { return _tnAvatarColors[(parseInt(pid)||0) % _tnAvatarColors.length]; }
	function tnInitials(name) { if (!name) return '?'; var parts = name.trim().split(/\s+/); return parts.length > 1 ? (parts[0][0]+parts[parts.length-1][0]).toUpperCase() : name.substring(0,2).toUpperCase(); }

	// Tooltip singleton
	var _tnTooltipEl = null;
	function tnShowTooltip(e, html) {
		if (!_tnTooltipEl) { _tnTooltipEl = document.createElement('div'); _tnTooltipEl.className = 'tn-bv-tooltip'; document.body.appendChild(_tnTooltipEl); }
		_tnTooltipEl.innerHTML = html;
		_tnTooltipEl.classList.add('tn-bv-tooltip-show');
		var x = e.clientX + 12, y = e.clientY + 12;
		if (x + 260 > window.innerWidth) x = e.clientX - 270;
		if (y + 100 > window.innerHeight) y = e.clientY - 110;
		_tnTooltipEl.style.left = x + 'px'; _tnTooltipEl.style.top = y + 'px';
	}
	function tnHideTooltip() { if (_tnTooltipEl) _tnTooltipEl.classList.remove('tn-bv-tooltip-show'); }
	function tnEscHtml(s) { var d = document.createElement('div'); d.textContent = s; return d.innerHTML; }

	function buildMatchBox(m, pMap, sectionMatches) {
		var p1Id = parseInt(m.Participant1Id) || 0;
		var p2Id = parseInt(m.Participant2Id) || 0;
		var p1   = p1Id ? (pMap[p1Id] || null) : null;
		var p2   = p2Id ? (pMap[p2Id] || null) : null;
		var hasResult = m.Result && m.Result !== '';
		var isClickable = !hasResult && p1 && p2 && TnConfig.canManage;

		var isBye = (!p1Id && p2Id) || (p1Id && !p2Id) || (p1Id === -1 || p2Id === -1);

		var box = document.createElement('div');
		box.className = 'tn-bv-match';
		box.dataset.matchid = m.MatchId || '';
		if (isClickable) box.className += ' tn-bv-clickable';
		if (hasResult)   box.className += ' tn-bv-resolved';
		if (isBye && !hasResult) box.className += ' tn-bv-bye-match';
		if (!hasResult && p1 && p2) box.className += ' tn-bv-next-playable';

		// Match number badge
		if (m.MatchId) {
			var matchNum = document.createElement('span');
			matchNum.className = 'tn-bv-match-num';
			matchNum.textContent = '#' + m.MatchId;
			box.appendChild(matchNum);
		}
			if (m.BracketSide === 'tiebreaker-3rd') {
			var tbLabel = document.createElement('span');
			tbLabel.className = 'tn-bv-match-num';
			tbLabel.style.cssText = 'left:auto;right:6px;background:#dd6b20;color:#fff';
			tbLabel.textContent = '3rd Place';
			box.appendChild(tbLabel);
		}

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
				var awaitLabel = parseInt(m.Round) > 1 ? 'Awaiting Rd ' + (parseInt(m.Round) - 1) : 'TBD';
				slot.innerHTML = '<span class="tn-bv-seed">?</span><span class="tn-bv-tbd-label">' + awaitLabel + '</span>';
			} else {
				var displayName = info.p.Alias || info.p.Persona || '—';
				var av = document.createElement('span');
				av.className = 'tn-bv-avatar';
				av.style.background = tnAvatarColor(info.pid);
				av.textContent = tnInitials(displayName);
				slot.appendChild(av);

				var seed = document.createElement('span');
				seed.className = 'tn-bv-seed';
				seed.textContent = info.p.Seed || '?';
				slot.appendChild(seed);
				var name = document.createElement('span');
				name.textContent = displayName;
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

		// Bye auto-advance label
		if (isBye && !hasResult) {
			var byeLabel = document.createElement('div');
			byeLabel.className = 'tn-bv-bye-label';
			byeLabel.textContent = 'Auto-advance';
			box.appendChild(byeLabel);
		}

		// Tooltip on hover
		if (p1 || p2) {
			box.addEventListener('mouseenter', function(e) {
				var lines = [];
				[p1, p2].forEach(function(pp, idx) {
					if (!pp) return;
					var pName = pp.Alias || pp.Persona || 'Unknown';
					var pPark = pp.ParkName || '';
					lines.push('<div class="tn-bv-tooltip-name">' + (idx+1) + '. ' + tnEscHtml(pName) + '</div>');
					if (pPark) lines.push('<div class="tn-bv-tooltip-park">' + tnEscHtml(pPark) + '</div>');
				});
				if (hasResult) {
					var resultLabel = m.Result === '1-wins' ? 'Player 1 wins' : m.Result === '2-wins' ? 'Player 2 wins' : m.Result === 'tie' ? 'Tie' : m.Result;
					lines.push('<div class="tn-bv-tooltip-bouts">Result: ' + resultLabel + '</div>');
					try {
						var ba = (m.Bouts && m.Bouts !== '[]') ? JSON.parse(m.Bouts) : [];
						if (ba.length > 0) {
							var w1 = ba.filter(function(b){return b==='1'}).length;
							var w2 = ba.filter(function(b){return b==='2'}).length;
							lines.push('<div class="tn-bv-tooltip-bouts">Bouts: ' + w1 + '-' + w2 + '</div>');
						}
					} catch(ex){}
				}
				tnShowTooltip(e, lines.join(''));
			});
			box.addEventListener('mousemove', function(e) { if (_tnTooltipEl) tnShowTooltip(e, _tnTooltipEl.innerHTML); });
			box.addEventListener('mouseleave', tnHideTooltip);
		}

		if (hasResult) {
			var boutsArr = [];
			try { boutsArr = (m.Bouts && m.Bouts !== '[]') ? JSON.parse(m.Bouts) : []; } catch(e) {}
			if (boutsArr.length > 0) {
				var p1Bouts = 0, p2Bouts = 0;
				boutsArr.forEach(function(b) { if (b === '1') p1Bouts++; else if (b === '2') p2Bouts++; });
				var boutRow = document.createElement('div');
				boutRow.className = 'tn-bv-bout-row';
				// Bout score pill (winner-loser format)
				var winBouts = (m.Result === '1-wins') ? p1Bouts : p2Bouts;
				var loseBouts = (m.Result === '1-wins') ? p2Bouts : p1Bouts;
				var scorePill = document.createElement('span');
				scorePill.className = 'tn-bout-score-pill';
				scorePill.textContent = winBouts + '-' + loseBouts;
				scorePill.title = 'Bout score (winner-loser)';
				boutRow.appendChild(scorePill);
				// Also show bout dots
				boutsArr.forEach(function(b) {
					var dot = document.createElement('span');
					var winSide = (m.Result === '1-wins') ? '1' : '2';
					dot.className = 'tn-bv-bout-dot ' + (b === winSide ? 'tn-bd-1' : 'tn-bd-2');
					boutRow.appendChild(dot);
				});
				box.appendChild(boutRow);
			} else if (m.Score) {
				// Fallback: show Score field as a pill if no bouts recorded
				var scoreRow = document.createElement('div');
				scoreRow.className = 'tn-bv-bout-row';
				var scorePill = document.createElement('span');
				scorePill.className = 'tn-bout-score-pill';
				scorePill.textContent = m.Score;
				scorePill.title = 'Match score';
				scoreRow.appendChild(scorePill);
				box.appendChild(scoreRow);
			}
		}
		if (isClickable) {
			// Click on the match card opens quick result inline
			box.addEventListener('click', function(e) {
				// Don't toggle if clicking a button inside
				if (e.target.closest('.tn-qr-bar') || e.target.closest('.tn-bv-reset-btn')) return;
				var existing = box.querySelector('.tn-qr-bar');
				if (existing) {
					existing.remove();
					box.classList.remove('tn-qr-expanded');
					return;
				}
				// Close other expanded quick-result bars
				document.querySelectorAll('.tn-qr-bar').forEach(function(b) { b.remove(); });
				document.querySelectorAll('.tn-qr-expanded').forEach(function(b) { b.classList.remove('tn-qr-expanded'); });
				var qrBar = document.createElement('div');
				qrBar.className = 'tn-qr-bar';
				var p1Label = p1 ? (p1.Alias || p1.Persona || 'P1') : 'P1';
				var p2Label = p2 ? (p2.Alias || p2.Persona || 'P2') : 'P2';
				// Truncate names for button text
				var p1Short = p1Label.length > 8 ? p1Label.substring(0, 8) + '\u2026' : p1Label;
				var p2Short = p2Label.length > 8 ? p2Label.substring(0, 8) + '\u2026' : p2Label;
				var btn1 = document.createElement('button');
				btn1.className = 'tn-qr-btn tn-qr-btn-p1';
				btn1.textContent = p1Short + ' Wins';
				btn1.onclick = function(ev) { tnSubmitQuickResult(m.MatchId, '1-wins', ev); };
				var btn2 = document.createElement('button');
				btn2.className = 'tn-qr-btn tn-qr-btn-p2';
				btn2.textContent = p2Short + ' Wins';
				btn2.onclick = function(ev) { tnSubmitQuickResult(m.MatchId, '2-wins', ev); };
				var btnTie = document.createElement('button');
				btnTie.className = 'tn-qr-btn tn-qr-btn-tie';
				btnTie.textContent = 'Tie';
				btnTie.onclick = function(ev) { tnSubmitQuickResult(m.MatchId, 'tie', ev); };
				var moreLink = document.createElement('a');
				moreLink.className = 'tn-qr-more';
				moreLink.textContent = 'More Options';
				moreLink.onclick = function(ev) { ev.stopPropagation(); tnOpenRecordResult(m, p1, p2); };
				qrBar.appendChild(btn1);
				qrBar.appendChild(btn2);
				qrBar.appendChild(btnTie);
				qrBar.appendChild(moreLink);
				box.appendChild(qrBar);
				box.classList.add('tn-qr-expanded');
			});
		}

		if (hasResult && TnConfig.canManage) {
			var canReset = isMatchResettable(m, sectionMatches || []);
			var resetBtn = document.createElement('button');
			resetBtn.className = 'tn-bv-reset-btn';
			resetBtn.innerHTML = '&#9851;';
			resetBtn.title = canReset ? 'Reset this match' : 'Cannot reset: a later match has been played';
			if (!canReset) resetBtn.disabled = true;
			var tnResetConfirmed = false;
			var tnResetTimer = null;
			resetBtn.addEventListener('click', function(e) {
				e.stopPropagation();
				if (!tnResetConfirmed) {
					tnResetConfirmed = true;
					resetBtn.classList.add('tn-bv-reset-confirm');
					resetBtn.innerHTML = 'Confirm?';
					resetBtn.title = 'Click again to confirm reset';
					tnResetTimer = setTimeout(function() {
						tnResetConfirmed = false;
						resetBtn.classList.remove('tn-bv-reset-confirm');
						resetBtn.innerHTML = '&#9851;';
						resetBtn.title = 'Reset this match';
					}, 3000);
				} else {
					clearTimeout(tnResetTimer);
					resetBtn.disabled = true;
					var tid = TnConfig.tournamentId;
					var url = TnConfig.uir + 'TournamentAjax/match/' + m.MatchId + '/' + tid + '/reset';
					fetch(url, { method: 'POST' })
						.then(function(res) { return res.json(); })
						.then(function(d) {
							if (d && d.status === 0) {
								var sel = document.getElementById('tn-bv-bracket-select');
								var bid = sel ? parseInt(sel.value) : 0;
								if (bid && TnConfig.bracketData[bid]) {
									Promise.all([
										fetch(TnConfig.uir + 'TournamentAjax/bracket/' + bid + '/matches').then(function(r2) { return r2.json(); }),
										fetch(TnConfig.uir + 'TournamentAjax/tournament/' + tid + '/brackets').then(function(r2) { return r2.json(); })
									]).then(function(res2) {
										var md = res2[0], bd2 = res2[1];
										if (md && md.status === 0) TnConfig.bracketData[bid].Matches = md.matches;
										if (bd2 && bd2.status === 0 && bd2.brackets && TnConfig.bracketData[bid]) {
											var br = bd2.brackets.find(function(b) { return parseInt(b.BracketId) === parseInt(bid); });
											if (br) TnConfig.bracketData[bid].Bracket = br;
										}
										tnRenderBracketViz(bid);
									});
								}
							} else {
								alert((d && d.error) ? d.error : 'Reset failed.');
								resetBtn.disabled = false;
							}
						})
						.catch(function() { alert('Request failed.'); resetBtn.disabled = false; });
				}
			});
			box.appendChild(resetBtn);
		}
		return box;
	}

	// ── Ironman / King of the Hill renderer ──
	function getIronmanWinnerId(m) {
		if (m.Result === '1-wins' || m.Result === 'forfeit' || m.Result === 'disqualified') return parseInt(m.Participant1Id) || 0;
		if (m.Result === '2-wins') return parseInt(m.Participant2Id) || 0;
		return 0;
	}

	function computeIronmanStats(completedMatches, ringNumber) {
		// If ringNumber provided, filter to that ring only
		var filtered = (ringNumber != null)
			? completedMatches.filter(function(m){ return (parseInt(m.RingNumber)||1) === ringNumber; })
			: completedMatches;
		var wins = {}, maxStreak = {}, currentKingId = 0, currentStreak = 0;
		filtered.forEach(function(m) {
			var w = getIronmanWinnerId(m);
			if (!w) return;
			wins[w] = (wins[w] || 0) + 1;
			if (w === currentKingId) {
				currentStreak++;
			} else {
				currentKingId = w;
				currentStreak = 1;
			}
			if (!maxStreak[w] || currentStreak > maxStreak[w]) maxStreak[w] = currentStreak;
		});
		return { wins: wins, maxStreak: maxStreak, currentKingId: currentKingId, currentStreak: currentStreak };
	}

	function computeIronmanQueue(completedMatches, pMap, excludeIds) {
		var lastLossIdx = {}, appeared = {};
		completedMatches.forEach(function(m, idx) {
			var p1 = parseInt(m.Participant1Id) || 0;
			var p2 = parseInt(m.Participant2Id) || 0;
			if (p1) appeared[p1] = true;
			if (p2) appeared[p2] = true;
			var loser = 0;
			if (m.Result === '1-wins' || m.Result === 'forfeit' || m.Result === 'disqualified') loser = p2;
			else if (m.Result === '2-wins') loser = p1;
			if (loser) lastLossIdx[loser] = idx;
		});
		var ids = Object.keys(pMap).map(Number).filter(function(id) {
			return excludeIds.indexOf(id) === -1;
		});
		ids.sort(function(a, b) {
			var aFresh = !appeared[a], bFresh = !appeared[b];
			if (aFresh && bFresh) return (parseInt(pMap[a].Seed)||0) - (parseInt(pMap[b].Seed)||0);
			if (aFresh) return -1;
			if (bFresh) return 1;
			var aL = lastLossIdx[a] !== undefined ? lastLossIdx[a] : Infinity;
			var bL = lastLossIdx[b] !== undefined ? lastLossIdx[b] : Infinity;
			return aL - bL;
		});
		return ids;
	}

	// Ring color palette (border + label bg) for up to 8 rings
	var TN_RING_COLORS = ['','#3182ce','#38a169','#e53e3e','#805ad5','#dd6b20','#d69e2e','#d53f8c','#744210'];

	function renderIronmanView(container, matches, pMap, participants, bracketId) {
		var sorted    = matches.slice().sort(function(a,b){ return (parseInt(a.Order)||0)-(parseInt(b.Order)||0); });
		var completed = sorted.filter(function(m){ return m.Result && m.Result !== ''; });

		var seedSorted = participants.slice().sort(function(a,b){
			var an = parseInt(a.ParticipantNumber) || parseInt(a.Seed) || 0;
			var bn = parseInt(b.ParticipantNumber) || parseInt(b.Seed) || 0;
			return an - bn;
		});

		// ── Timer state ──
		var _timerKey   = 'tn_im_timer_' + bracketId;
		var _durationMs = (parseInt((TnConfig.bracketData[bracketId] && TnConfig.bracketData[bracketId].Bracket && TnConfig.bracketData[bracketId].Bracket.DurationMinutes) || 0)) * 60000;
		var _graceMs    = 10000;
		var _timerState = null;
		try { _timerState = JSON.parse(localStorage.getItem(_timerKey) || 'null'); } catch(e) {}
		var _timerActive  = false;
		var _timerExpired = false;
		var _inGrace      = false;
		var _timerPaused  = false;
		var _graceRemMs   = 0;
		var _timerRemMs   = _durationMs;
		if (_timerState && _timerState.startedAt) {
			var _elapsed = Date.now() - _timerState.startedAt;
			if (_timerState.endedAt) {
				_timerExpired = true; _timerRemMs = 0;
			} else if (_timerState.graceStartedAt) {
				var _graceElapsed = Date.now() - _timerState.graceStartedAt;
				if (_graceElapsed >= _graceMs) {
					_timerExpired = true; _timerRemMs = 0; _graceRemMs = 0;
				} else {
					_inGrace = true; _graceRemMs = _graceMs - _graceElapsed; _timerRemMs = 0;
				}
			} else if (_elapsed >= _durationMs && _durationMs > 0) {
				_inGrace = true; _graceRemMs = _graceMs; _timerRemMs = 0;
				_timerState.graceStartedAt = Date.now();
				try { localStorage.setItem(_timerKey, JSON.stringify(_timerState)); } catch(e) {}
			} else if (_timerState.pausedAt) {
				_timerPaused = true;
				_timerRemMs  = _timerState.pausedRemMs || 0;
			} else {
				_timerActive = true;
				_timerRemMs  = _durationMs > 0 ? Math.max(0, _durationMs - _elapsed) : Infinity;
			}
		}
		var _timerUnlocked = (_durationMs === 0) || _timerActive || _inGrace || _timerPaused;

		// ── Timer bar (single bar above all rings) ──
		if (_durationMs > 0) {
			var timerBar = document.createElement('div');
			timerBar.className = 'tn-im-timer-bar' + (_timerRemMs <= 15000 && _timerActive ? ' warning' : '');

			var timerDisplay = document.createElement('div');
			timerDisplay.className = 'tn-im-timer-display' + (_inGrace ? ' grace' : (_timerActive ? ' running' : (_timerExpired ? ' expired' : (_timerPaused ? ' paused' : ''))));
			function _fmtTime(ms) {
				if (ms === Infinity || ms < 0) ms = 0;
				var totalSec = Math.ceil(ms / 1000);
				var m = Math.floor(totalSec / 60), s = totalSec % 60;
				return (m < 10 ? '0' : '') + m + ':' + (s < 10 ? '0' : '') + s;
			}
			timerDisplay.textContent = _timerExpired ? 'ENDED' : (_inGrace ? 'FINISH RECORDING ' + _fmtTime(_graceRemMs) : (_timerPaused ? 'PAUSED ' + _fmtTime(_timerRemMs) : _fmtTime(_timerRemMs)));
			timerBar.appendChild(timerDisplay);

			if (!_timerActive && !_timerExpired && !_inGrace && TnConfig.canManage) {
				var startBtn = document.createElement('button');
				startBtn.className = 'tn-im-timer-btn start';
				if (_timerPaused) {
					startBtn.innerHTML = '<i class="fas fa-redo"></i> Restart';
					startBtn.onclick = function() {
						if (startBtn.dataset.confirming) {
							startBtn.disabled = true;
							var fd = new FormData();
							fd.append('TournamentId', TnConfig.tournamentId);
							fetch(TnConfig.uir + 'TournamentAjax/bracket/' + bracketId + '/clearmatches', { method: 'POST', body: fd })
								.then(function(r){ return r.json(); })
								.then(function(d){
									try { localStorage.setItem(_timerKey, JSON.stringify({ startedAt: Date.now(), endedAt: null })); } catch(e) {}
									tnRenderBracketViz(bracketId);
								})
								.catch(function(){ startBtn.disabled = false; alert('Error clearing results.'); });
						} else {
							startBtn.dataset.confirming = '1';
							startBtn.textContent = 'Confirm Restart?';
							startBtn.style.background = '#276749';
							setTimeout(function() {
								if (startBtn.parentNode) { delete startBtn.dataset.confirming; startBtn.innerHTML = '<i class="fas fa-redo"></i> Restart'; startBtn.style.background = ''; }
							}, 3000);
						}
					};
				} else {
					startBtn.innerHTML = '<i class="fas fa-play"></i> Start';
					startBtn.onclick = function() {
						var state = { startedAt: Date.now(), endedAt: null };
						try { localStorage.setItem(_timerKey, JSON.stringify(state)); } catch(e) {}
						tnRenderBracketViz(bracketId);
					};
				}
				timerBar.appendChild(startBtn);
			}

			if (_inGrace && TnConfig.canManage) {
				var graceNote = document.createElement('span');
				graceNote.className = 'tn-im-timer-locked';
				graceNote.style.color = '#ed8936';
				graceNote.innerHTML = '<i class="fas fa-hourglass-end"></i> Finish recording — bracket completes automatically';
				timerBar.appendChild(graceNote);
			}

			if (_timerActive && TnConfig.canManage) {
				var pauseBtn = document.createElement('button');
				pauseBtn.className = 'tn-im-timer-btn pause';
				pauseBtn.innerHTML = '<i class="fas fa-pause"></i> Pause';
				pauseBtn.onclick = function() {
					try {
						var s = JSON.parse(localStorage.getItem(_timerKey) || 'null') || {};
						var _nowRem = _durationMs > 0 ? Math.max(0, _durationMs - (Date.now() - (s.startedAt || Date.now()))) : 0;
						s.pausedAt  = Date.now();
						s.pausedRemMs = _nowRem;
						localStorage.setItem(_timerKey, JSON.stringify(s));
					} catch(e) {}
					tnRenderBracketViz(bracketId);
				};
				timerBar.appendChild(pauseBtn);

				var addBtn = document.createElement('button');
				addBtn.className = 'tn-im-timer-btn add';
				addBtn.textContent = '+1m';
				addBtn.onclick = function() {
					try {
						var s = JSON.parse(localStorage.getItem(_timerKey) || 'null') || {};
						s.startedAt = (s.startedAt || Date.now()) + 60000;
						localStorage.setItem(_timerKey, JSON.stringify(s));
					} catch(e) {}
					tnRenderBracketViz(bracketId);
				};
				timerBar.appendChild(addBtn);

				var endBtn = document.createElement('button');
				endBtn.className = 'tn-im-timer-btn end';
				endBtn.textContent = 'End Early';
				endBtn.onclick = function() {
					if (endBtn.dataset.confirming) {
						try {
							var s = JSON.parse(localStorage.getItem(_timerKey) || 'null') || {};
							s.endedAt = Date.now();
							localStorage.setItem(_timerKey, JSON.stringify(s));
						} catch(e) {}
						tnRenderBracketViz(bracketId);
					} else {
						endBtn.dataset.confirming = '1';
						endBtn.textContent = 'Confirm End?';
						endBtn.style.background = '#fc8181';
						endBtn.style.color = '#fff';
						setTimeout(function() {
							if (endBtn.parentNode) { delete endBtn.dataset.confirming; endBtn.textContent = 'End Early'; endBtn.style.background = ''; endBtn.style.color = ''; }
						}, 3000);
					}
				};
				timerBar.appendChild(endBtn);
			}

			if (_timerPaused && TnConfig.canManage) {
				var resumeBtn = document.createElement('button');
				resumeBtn.className = 'tn-im-timer-btn pause';
				resumeBtn.innerHTML = '<i class="fas fa-play"></i> Resume';
				resumeBtn.onclick = function() {
					try {
						var s = JSON.parse(localStorage.getItem(_timerKey) || 'null') || {};
						s.startedAt = Date.now() - (_durationMs - (s.pausedRemMs || 0));
						delete s.pausedAt;
						delete s.pausedRemMs;
						localStorage.setItem(_timerKey, JSON.stringify(s));
					} catch(e) {}
					tnRenderBracketViz(bracketId);
				};
				timerBar.appendChild(resumeBtn);

				var addBtnP = document.createElement('button');
				addBtnP.className = 'tn-im-timer-btn add';
				addBtnP.textContent = '+1m';
				addBtnP.onclick = function() {
					try {
						var s = JSON.parse(localStorage.getItem(_timerKey) || 'null') || {};
						s.pausedRemMs = Math.min((s.pausedRemMs || 0) + 60000, _durationMs);
						localStorage.setItem(_timerKey, JSON.stringify(s));
					} catch(e) {}
					tnRenderBracketViz(bracketId);
				};
				timerBar.appendChild(addBtnP);

				var endBtnP = document.createElement('button');
				endBtnP.className = 'tn-im-timer-btn end';
				endBtnP.textContent = 'End Early';
				endBtnP.onclick = function() {
					if (endBtnP.dataset.confirming) {
						try {
							var s = JSON.parse(localStorage.getItem(_timerKey) || 'null') || {};
							s.endedAt = Date.now();
							delete s.pausedAt;
							delete s.pausedRemMs;
							localStorage.setItem(_timerKey, JSON.stringify(s));
						} catch(e) {}
						tnRenderBracketViz(bracketId);
					} else {
						endBtnP.dataset.confirming = '1';
						endBtnP.textContent = 'Confirm End?';
						endBtnP.style.background = '#fc8181';
						endBtnP.style.color = '#fff';
						setTimeout(function() {
							if (endBtnP.parentNode) { delete endBtnP.dataset.confirming; endBtnP.textContent = 'End Early'; endBtnP.style.background = ''; endBtnP.style.color = ''; }
						}, 3000);
					}
				};
				timerBar.appendChild(endBtnP);
			}

			if (!_timerUnlocked && !_timerExpired) {
				var lockNote = document.createElement('span');
				lockNote.className = 'tn-im-timer-locked';
				lockNote.innerHTML = '<i class="fas fa-lock"></i> Start timer to record fights';
				timerBar.appendChild(lockNote);
			}

			container.appendChild(timerBar);

			// Live countdown tick (active or in grace)
			if (_timerActive || _inGrace) {
				if (window['_tnTimerInterval_'+bracketId]) clearInterval(window['_tnTimerInterval_'+bracketId]);
				window['_tnTimerInterval_'+bracketId] = setInterval(function() {
					var state = null;
					try { state = JSON.parse(localStorage.getItem(_timerKey) || 'null'); } catch(e) {}
					if (!state || !state.startedAt) { clearInterval(window['_tnTimerInterval_'+bracketId]); return; }
					if (state.endedAt) { clearInterval(window['_tnTimerInterval_'+bracketId]); tnRenderBracketViz(bracketId); return; }
					var now = Date.now();
					var elapsed = now - state.startedAt;
					var rem = _durationMs - elapsed;
					if (rem > 0) {
						timerDisplay.textContent = _fmtTime(rem);
						timerDisplay.className = 'tn-im-timer-display running';
						if (rem <= 15000) { timerBar.classList.add('warning'); } else { timerBar.classList.remove('warning'); }
					} else if (!state.graceStartedAt) {
						state.graceStartedAt = now;
						try { localStorage.setItem(_timerKey, JSON.stringify(state)); } catch(e) {}
						timerDisplay.textContent = 'FINISH RECORDING ' + _fmtTime(10000);
						timerDisplay.className = 'tn-im-timer-display grace';
					} else {
						var graceRem = 10000 - (now - state.graceStartedAt);
						if (graceRem > 0) {
							timerDisplay.textContent = 'FINISH RECORDING ' + _fmtTime(graceRem);
							timerDisplay.className = 'tn-im-timer-display grace';
						} else {
							// Grace expired — lock cells immediately, then auto-complete
							clearInterval(window['_tnTimerInterval_'+bracketId]);
							timerDisplay.textContent = 'ENDED';
							timerDisplay.className = 'tn-im-timer-display expired';
							container.querySelectorAll('.tn-im-card-btn').forEach(function(b) { b.disabled = true; b.style.opacity = '0.45'; b.style.cursor = 'not-allowed'; });
							container.querySelectorAll('.tn-im-qe-input').forEach(function(el) { el.disabled = true; });
							var fd = new FormData();
							fd.append('BracketId', bracketId);
							fetch(TnConfig.uir + 'TournamentAjax/tournament/' + TnConfig.tournamentId + '/completebracket', { method: 'POST', body: fd })
								.then(function() { tnRenderBracketViz(bracketId); })
								.catch(function() { tnRenderBracketViz(bracketId); });
						}
					}
				}, 500);
			}
		}

		// ── Determine ring count ──
		var ringCount = Math.max(1, Math.min(8, parseInt(
			(TnConfig.bracketData[bracketId] && TnConfig.bracketData[bracketId].Bracket &&
			 TnConfig.bracketData[bracketId].Bracket.Rings) || 1
		) || 1)); // inner || 1 guards against parseInt returning NaN

		// ── Compute per-ring stats and kings — single pass, results cached ──
		// ringStats[rn] = computeIronmanStats result for that ring
		// ringKings[rn] = display king (fight history first, then seed default)
		// allKingRing[pid] = ring that pid is the REAL (fight-based) king of
		// Cross-ring blocking only uses real kings, never the seed default, to
		// avoid blocking a person just because they happen to be the Nth seed.
		var ringStats  = {};
		var ringKings  = {};
		var allKingRing = {}; // pid => ring they are the real fight-history king of
		for (var ringIdx = 1; ringIdx <= ringCount; ringIdx++) {
			var _rs = computeIronmanStats(completed, ringIdx);
			ringStats[ringIdx] = _rs;
			var _realKingId = _rs.currentKingId;
			// allKingRing only tracks fight-history kings — never seed defaults
			if (_realKingId) allKingRing[_realKingId] = ringIdx;
			// Display king: real king if fights exist, otherwise Nth seed as visual default
			if (!_realKingId && seedSorted.length > 0) {
				_realKingId = parseInt(seedSorted[(ringIdx - 1) % seedSorted.length].ParticipantId) || 0;
			}
			ringKings[ringIdx] = _realKingId;
		}

		// Avatar color palette
		var _avatarColors = ['#e53e3e','#38a169','#3182ce','#d69e2e','#805ad5','#dd6b20','#00b5d8','#d53f8c','#2d3748','#319795'];

		// Build pNumMap once (shared across rings)
		var pNumMap = {};
		participants.forEach(function(participant) {
			var num = parseInt(participant.ParticipantNumber) || parseInt(participant.Seed) || 0;
			if (num) pNumMap[num] = parseInt(participant.ParticipantId) || 0;
		});

		// ── Rings wrapper ──
		var ringsWrap = document.createElement('div');
		ringsWrap.className = 'tn-im-rings-wrap';
		container.appendChild(ringsWrap);

		// ── Render each ring ──
		for (var ringNum = 1; ringNum <= ringCount; ringNum++) {
			(function(rNum) {
				var rStats     = ringStats[rNum]; // reuse cached stats from pre-pass
				var kingId     = ringKings[rNum];
				var rCompleted = completed.filter(function(m){ return (parseInt(m.RingNumber)||1) === rNum; });
				var fightNum   = rCompleted.length + 1;
				var ringColor  = TN_RING_COLORS[rNum] || '#718096';

				// Ring container
				var ringDiv = document.createElement('div');
				ringDiv.className = 'tn-im-ring';
				ringDiv.style.borderColor = ringColor;

				// Ring header: label + fight# + king badge
				var rHeader = document.createElement('div');
				rHeader.className = 'tn-im-ring-header';

				if (ringCount > 1) {
					var rLabel = document.createElement('span');
					rLabel.className = 'tn-im-ring-label';
					rLabel.style.cssText = 'background:' + ringColor + ';color:#fff;font-size:11px;font-weight:800;text-transform:uppercase;letter-spacing:0.8px;border-radius:6px;padding:3px 10px;';
					rLabel.textContent = 'Ring ' + rNum;
					rHeader.appendChild(rLabel);
				}

				var fightNumBadge = document.createElement('div');
				fightNumBadge.className = 'tn-im-fight-num';
				fightNumBadge.textContent = 'Fight #' + fightNum;
				rHeader.appendChild(fightNumBadge);

				// Quick-entry inline in header (between fight# and king badge)
				var qeInput = null;
				if (TnConfig.canManage && participants.length > 0 && _timerUnlocked) {
					var qeWrap = document.createElement('div');
					qeWrap.className = 'tn-im-qe-wrap';
					qeWrap.style.marginBottom = '0';
					if (ringCount > 1) qeWrap.style.borderColor = ringColor;

					var qeLabel = document.createElement('span');
					qeLabel.className = 'tn-im-qe-label';
					qeLabel.textContent = ringCount > 1 ? 'Ring ' + rNum + ' Winner #' : 'Winner #';
					qeWrap.appendChild(qeLabel);

					qeInput = document.createElement('input');
					qeInput.type = 'text';
					qeInput.inputMode = 'numeric';
					qeInput.className = 'tn-im-qe-input';
					qeInput.placeholder = '—';
					qeInput.autocomplete = 'off';
					qeWrap.appendChild(qeInput);

					var qeStatus = document.createElement('span');
					qeStatus.className = 'tn-im-qe-status';
					qeWrap.appendChild(qeStatus);

					// Show last winner for this ring after re-render
					var lastWinKey = '_tnLastWinner_' + bracketId + '_r' + rNum;
					if (window[lastWinKey]) {
						qeStatus.className = 'tn-im-qe-status ok';
						qeStatus.textContent = '\u2713 ' + window[lastWinKey] + ' — Fight #' + rCompleted.length + ' recorded';
						window[lastWinKey] = null;
					}

					qeInput.addEventListener('keydown', (function(ringN, statusEl, inputEl) {
						return function(e) {
							if (e.key !== 'Enter') return;
							e.preventDefault();
							var num = parseInt(inputEl.value.trim()) || 0;
							inputEl.value = '';
							if (!num || !pNumMap[num]) {
								statusEl.className = 'tn-im-qe-status err';
								statusEl.textContent = num ? 'No fighter #' + num : 'Enter a number';
								inputEl.focus();
								return;
							}
							var winnerId   = pNumMap[num];
							// Block if this fighter is the real king of a different ring
							if (allKingRing[winnerId] !== undefined && allKingRing[winnerId] !== ringN) {
								statusEl.className = 'tn-im-qe-status err';
								statusEl.textContent = 'Fighter #' + num + ' is King of Ring ' + allKingRing[winnerId];
								inputEl.focus();
								return;
							}
							var winnerName = pMap[winnerId] ? (pMap[winnerId].Alias || pMap[winnerId].Persona || '#' + num) : '#' + num;
							statusEl.className = 'tn-im-qe-status';
							statusEl.textContent = 'Recording\u2026';
							inputEl.disabled = true;
							var fd = new FormData();
							fd.append('WinnerId',     winnerId);
							fd.append('TournamentId', TnConfig.tournamentId);
							fd.append('RingNumber',   ringN);
							fetch(TnConfig.uir + 'TournamentAjax/bracket/' + bracketId + '/ironmanwin', {method:'POST', body:fd})
								.then(function(r){ return r.json(); })
								.then(function(d){
									if (d.status !== 0) {
										statusEl.className = 'tn-im-qe-status err';
										statusEl.textContent = d.error || 'Error';
										inputEl.disabled = false;
										inputEl.focus();
										return;
									}
									window['_tnLastWinner_' + bracketId + '_r' + ringN] = winnerName;
									tnRefreshAndRender(bracketId);
								})
								.catch(function(){
									statusEl.className = 'tn-im-qe-status err';
									statusEl.textContent = 'Network error';
									inputEl.disabled = false;
									inputEl.focus();
								});
						};
					})(rNum, qeStatus, qeInput));

					rHeader.appendChild(qeWrap);
				}

				if (kingId && pMap[kingId]) {
					var kName = pMap[kingId].Alias || pMap[kingId].Persona || '?';
					var kb = document.createElement('div');
					kb.className = 'tn-im-king-badge';
					kb.innerHTML = '<i class="fas fa-crown tn-im-king-badge-crown"></i>'
						+ '<span class="tn-im-king-badge-label">' + (ringCount > 1 ? 'King of Ring ' + rNum : 'King') + '</span>'
						+ '<span class="tn-im-king-badge-name">' + tnEsc(kName) + '</span>'
						+ (rStats.currentStreak > 1
							? '<span class="tn-im-king-badge-streak">' + rStats.currentStreak + '</span>'
							: '');
					rHeader.appendChild(kb);
				}
				ringDiv.appendChild(rHeader);
				// Auto-focus first ring's quick-entry
				if (rNum === 1 && qeInput) setTimeout(function(){ qeInput.focus(); }, 0);

				// Fighter grid
				var grid = document.createElement('div');
				grid.className = 'tn-im-grid';

				seedSorted.forEach(function(participant, idx) {
					var pid    = parseInt(participant.ParticipantId) || 0;
					var name   = participant.Alias || participant.Persona || '?';
					var wins   = rStats.wins[pid] || 0;
					var isKing = (pid === kingId);
					var color  = _avatarColors[idx % _avatarColors.length];
					var seedNum = parseInt(participant.ParticipantNumber) || parseInt(participant.Seed) || (idx + 1);

					// Blocked if this person is king of a DIFFERENT ring
					var isKingElsewhere = (!isKing && allKingRing[pid] !== undefined);

					var card = document.createElement('div');
					card.className = 'tn-im-card'
						+ (isKing ? ' tn-im-card-king' : '')
						+ (isKingElsewhere ? ' tn-im-card-blocked' : '');
					if (isKing) card.style.borderColor = ringColor;
					card.innerHTML = (isKing ? '<i class="fas fa-crown tn-im-card-crown"></i>' : '')
						+ (isKingElsewhere ? '<i class="fas fa-shield-alt tn-im-card-crown" style="color:#a0aec0" title="King of Ring ' + allKingRing[pid] + '"></i>' : '')
						+ '<div class="tn-im-avatar" style="background:' + color + '">' + seedNum + '</div>'
						+ '<div class="tn-im-card-name">' + tnEsc(name) + '</div>'
						+ '<div class="tn-im-card-wins"><i class="fas fa-trophy"></i> ' + wins + '</div>';

					if (TnConfig.canManage && pid && _timerUnlocked && !isKingElsewhere) {
						card.classList.add('tn-im-card-btn');
						(function(winnerId, ringN) {
							card.onclick = function() {
								if (card.dataset.pending) return;
								card.dataset.pending = '1';
								grid.style.opacity = '0.5';
								grid.style.pointerEvents = 'none';
								var fd = new FormData();
								fd.append('WinnerId',     winnerId);
								fd.append('TournamentId', TnConfig.tournamentId);
								fd.append('RingNumber',   ringN);
								fetch(TnConfig.uir + 'TournamentAjax/bracket/' + bracketId + '/ironmanwin', {method:'POST', body:fd})
									.then(function(r){ return r.json(); })
									.then(function(d){
										if (d.status !== 0) { alert('Error: ' + (d.error || 'Unknown')); }
										tnRefreshAndRender(bracketId);
									})
									.catch(function(){ tnRefreshAndRender(bracketId); });
							};
						})(pid, rNum);
					}
					grid.appendChild(card);
				});
				ringDiv.appendChild(grid);

				// Per-ring fight history
				if (rCompleted.length > 0) {
					var hTitle = document.createElement('div');
					hTitle.className = 'tn-im-section-title';
					hTitle.textContent = ringCount > 1 ? 'Ring ' + rNum + ' Fight History' : 'Fight History';
					ringDiv.appendChild(hTitle);

					var hList = document.createElement('div');
					hList.className = 'tn-im-history';
					var _allRows = rCompleted.slice().reverse().slice(0, 20);
					var _showMax = 2;
					_allRows.forEach(function(m, i) {
						var fNum  = rCompleted.length - i;
						var wId   = getIronmanWinnerId(m);
						var wName = pMap[wId] ? (pMap[wId].Alias || pMap[wId].Persona || '?') : '?';
						var row   = document.createElement('div');
						row.className = 'tn-im-history-row';
						if (i >= _showMax) row.style.display = 'none';
						row.innerHTML = '<span><span class="tn-im-history-fight">#' + fNum + '</span>'
							+ '<span class="tn-im-history-winner">' + tnEsc(wName) + '</span> won</span>';
						hList.appendChild(row);
					});
					if (_allRows.length > _showMax) {
						var _expandRow = document.createElement('div');
						_expandRow.className = 'tn-im-history-expand';
						_expandRow.innerHTML = '<span>&#9660; ' + (_allRows.length - _showMax) + ' more fights</span>';
						_expandRow.addEventListener('click', function() {
							hList.querySelectorAll('.tn-im-history-row').forEach(function(r) { r.style.display = ''; });
							_expandRow.remove();
						});
						hList.appendChild(_expandRow);
					}
					ringDiv.appendChild(hList);
				}

				ringsWrap.appendChild(ringDiv);
			})(ringNum);
		}
	}

	// ── Cross-table matrix view (Round Robin) ──
	function renderMatrixView(container, matches, pMap) {
		var participants = Object.keys(pMap).map(function(id) { return pMap[id]; });
		participants.sort(function(a, b) {
			var seedA = parseInt(a.Seed, 10) || 9999;
			var seedB = parseInt(b.Seed, 10) || 9999;
			if (seedA !== seedB) return seedA - seedB;
			var nameA = (a.Alias || a.Persona || '').toLowerCase();
			var nameB = (b.Alias || b.Persona || '').toLowerCase();
			return nameA < nameB ? -1 : nameA > nameB ? 1 : 0;
		});

		var matchLookup = {};
		matches.forEach(function(match) {
			if (match.Participant1Id && match.Participant2Id) {
				matchLookup[match.Participant1Id + '-' + match.Participant2Id] = match;
				matchLookup[match.Participant2Id + '-' + match.Participant1Id] = match;
			}
		});

		function displayName(p) { return p.Alias || p.Persona || 'Unknown'; }
		function truncate(str, max) { return str.length <= max ? str : str.substring(0, max) + '\u2026'; }

		function makeAvatar(pid, small) {
			var av = document.createElement('span');
			av.className = small ? 'tn-rr-mx-avatar tn-rr-mx-avatar-sm' : 'tn-rr-mx-avatar';
			av.style.backgroundColor = tnAvatarColor(pid);
			av.textContent = tnInitials(displayName(pMap[pid]));
			return av;
		}

		function boutScore(match, playerId) {
			if (!match.Bouts) return null;
			try {
				var bouts = JSON.parse(match.Bouts);
				if (!Array.isArray(bouts) || bouts.length === 0) return null;
				var isP1 = String(match.Participant1Id) === String(playerId);
				var wins = 0, losses = 0;
				bouts.forEach(function(b) {
					if (isP1) { if (b === '1') wins++; else if (b === '2') losses++; }
					else { if (b === '2') wins++; else if (b === '1') losses++; }
				});
				return wins + '-' + losses;
			} catch(e) { return null; }
		}

		function cellResult(match, rowPlayerId) {
			if (!match || !match.Result) return { code: 'pending', label: '\u00B7' };
			var result = match.Result;
			var isP1 = String(match.Participant1Id) === String(rowPlayerId);
			if (result === '1-wins') return isP1 ? { code: 'win', label: 'W' } : { code: 'loss', label: 'L' };
			if (result === '2-wins') return isP1 ? { code: 'loss', label: 'L' } : { code: 'win', label: 'W' };
			if (result === 'tie') return { code: 'tie', label: 'T' };
			if (result === 'forfeit' || result === 'disqualified') return isP1 ? { code: 'win', label: 'W' } : { code: 'loss', label: 'L' };
			return { code: 'pending', label: '\u00B7' };
		}

		var wrap = document.createElement('div');
		wrap.className = 'tn-rr-matrix-wrap';
		var table = document.createElement('table');
		table.className = 'tn-rr-matrix';

		var thead = document.createElement('thead');
		var headerRow = document.createElement('tr');
		var cornerTh = document.createElement('th');
		cornerTh.className = 'tn-rr-mx-corner';
		headerRow.appendChild(cornerTh);

		participants.forEach(function(p) {
			var th = document.createElement('th');
			th.className = 'tn-rr-mx-col-header';
			th.appendChild(makeAvatar(p.ParticipantId, true));
			var nameSpan = document.createElement('span');
			nameSpan.className = 'tn-rr-mx-col-name';
			nameSpan.textContent = truncate(displayName(p), 8);
			nameSpan.title = displayName(p);
			th.appendChild(nameSpan);
			headerRow.appendChild(th);
		});
		thead.appendChild(headerRow);
		table.appendChild(thead);

		var tbody = document.createElement('tbody');
		participants.forEach(function(rowP) {
			var row = document.createElement('tr');
			row.dataset.pid = rowP.ParticipantId;

			var rowTh = document.createElement('th');
			rowTh.className = 'tn-rr-mx-player-col';
			rowTh.appendChild(makeAvatar(rowP.ParticipantId, false));
			var rowNameSpan = document.createElement('span');
			rowNameSpan.className = 'tn-rr-mx-player-name';
			rowNameSpan.textContent = displayName(rowP);
			rowTh.appendChild(rowNameSpan);
			row.appendChild(rowTh);

			participants.forEach(function(colP) {
				var td = document.createElement('td');
				if (String(rowP.ParticipantId) === String(colP.ParticipantId)) {
					td.className = 'tn-rr-mx-self';
					td.textContent = '\u2014';
				} else {
					var key = rowP.ParticipantId + '-' + colP.ParticipantId;
					var matchObj = matchLookup[key] || null;
					var res = cellResult(matchObj, rowP.ParticipantId);
					td.className = 'tn-rr-mx-' + res.code;

					var resultSpan = document.createElement('span');
					resultSpan.className = 'tn-rr-mx-result';
					resultSpan.textContent = res.label;
					td.appendChild(resultSpan);

					if (matchObj && res.code !== 'pending') {
						var bs = boutScore(matchObj, rowP.ParticipantId);
						if (bs) {
							var boutSpan = document.createElement('span');
							boutSpan.className = 'tn-rr-mx-bouts';
							boutSpan.textContent = bs;
							td.appendChild(boutSpan);
						}
					}

					if (TnConfig.canManage && matchObj && matchObj.Participant1Id && matchObj.Participant2Id) {
						td.classList.add('tn-rr-mx-cell-clickable');
						(function(mObj) {
							td.addEventListener('click', function() {
								tnOpenRecordResult(mObj, pMap[mObj.Participant1Id], pMap[mObj.Participant2Id]);
							});
						})(matchObj);
					}
				}
				row.appendChild(td);
			});
			tbody.appendChild(row);
		});
		table.appendChild(tbody);
		wrap.appendChild(table);
		container.appendChild(wrap);
	}

	// ── Enhanced standings table (Round Robin) ──
	function renderEnhancedStandings(container, matches, pMap, onPlayerClick) {
		var pids = Object.keys(pMap);
		var totalPossible = pids.length > 1 ? (pids.length * (pids.length - 1)) / 2 : 0;
		var maxMatchesPerPlayer = pids.length > 1 ? pids.length - 1 : 0;
		var stats = {};
		pids.forEach(function(pid) { stats[pid] = { w: 0, l: 0, t: 0, played: 0 }; });

		var completedMatches = 0;
		matches.forEach(function(m) {
			if (!m.Result || m.Result === '') return;
			completedMatches++;
			var p1 = String(m.Participant1Id), p2 = String(m.Participant2Id);
			if (stats[p1]) stats[p1].played++;
			if (stats[p2]) stats[p2].played++;
			if (m.Result === '1-wins' || m.Result === 'forfeit' || m.Result === 'disqualified') {
				if (stats[p1]) stats[p1].w++;
				if (stats[p2]) stats[p2].l++;
			} else if (m.Result === '2-wins') {
				if (stats[p2]) stats[p2].w++;
				if (stats[p1]) stats[p1].l++;
			} else if (m.Result === 'tie') {
				if (stats[p1]) stats[p1].t++;
				if (stats[p2]) stats[p2].t++;
			}
		});

		var rows = [];
		pids.forEach(function(pid) {
			var s = stats[pid];
			var pts = s.w * 3 + s.t * 1;
			var pct = s.played > 0 ? (s.w / s.played) : 0;
			rows.push({ p: pid, w: s.w, l: s.l, t: s.t, played: s.played, pts: pts, pct: pct, totalPossible: maxMatchesPerPlayer });
		});
		rows.sort(function(a, b) {
			if (b.pts !== a.pts) return b.pts - a.pts;
			if (b.w !== a.w) return b.w - a.w;
			if (a.l !== b.l) return a.l - b.l;
			var nameA = (pMap[a.p] ? (pMap[a.p].Alias || pMap[a.p].Persona || '') : '').toLowerCase();
			var nameB = (pMap[b.p] ? (pMap[b.p].Alias || pMap[b.p].Persona || '') : '').toLowerCase();
			return nameA < nameB ? -1 : nameA > nameB ? 1 : 0;
		});
		rows.forEach(function(row, idx) {
			if (idx === 0) { row.rank = 1; }
			else {
				var prev = rows[idx - 1];
				row.rank = (row.pts === prev.pts && row.w === prev.w && row.l === prev.l && row.t === prev.t) ? prev.rank : idx + 1;
			}
		});

		var table = document.createElement('table');
		table.className = 'tn-rr-standings-enhanced';

		var caption = document.createElement('caption');
		caption.innerHTML = '<span style="font-weight:bold">Standings</span><span class="tn-rr-std-caption-progress">' + completedMatches + '/' + totalPossible + ' matches played</span>';
		table.appendChild(caption);

		var thead = document.createElement('thead');
		var hRow = document.createElement('tr');
		['Rank','Player','W','L','T','Pts','Win%','Progress'].forEach(function(col) {
			var th = document.createElement('th');
			th.textContent = col;
			th.className = 'tn-rr-std-col-' + col.toLowerCase().replace('%','pct');
			hRow.appendChild(th);
		});
		thead.appendChild(hRow);
		table.appendChild(thead);

		var tbody = document.createElement('tbody');
		tbody.className = 'tn-rr-std-clickable';
		var activePlayerId = null;
		var rowEls = {};

		rows.forEach(function(row) {
			var tr = document.createElement('tr');
			tr.dataset.participantId = row.p;
			rowEls[row.p] = tr;

			tr.addEventListener('click', function() {
				if (activePlayerId === row.p) {
					tr.classList.remove('tn-rr-std-active');
					activePlayerId = null;
					if (onPlayerClick) onPlayerClick(null);
				} else {
					if (activePlayerId && rowEls[activePlayerId]) rowEls[activePlayerId].classList.remove('tn-rr-std-active');
					tr.classList.add('tn-rr-std-active');
					activePlayerId = row.p;
					if (onPlayerClick) onPlayerClick(row.p);
				}
			});

			// Rank
			var tdRank = document.createElement('td');
			tdRank.className = 'tn-rr-std-rank';
			if (row.rank <= 3) {
				var medals = { 1: '\uD83E\uDD47', 2: '\uD83E\uDD48', 3: '\uD83E\uDD49' };
				tdRank.innerHTML = '<span class="tn-rr-std-medal">' + medals[row.rank] + '</span>';
			} else {
				tdRank.textContent = row.rank;
			}
			tr.appendChild(tdRank);

			// Player
			var tdPlayer = document.createElement('td');
			tdPlayer.className = 'tn-rr-std-player';
			var playerWrap = document.createElement('div');
			playerWrap.className = 'tn-rr-std-player-wrap';
			var pInfo = pMap[row.p];
			var dName = pInfo ? (pInfo.Alias || pInfo.Persona || 'Unknown') : 'Unknown';
			var avatar = document.createElement('div');
			avatar.className = 'tn-rr-std-avatar';
			avatar.style.backgroundColor = tnAvatarColor(row.p);
			avatar.textContent = tnInitials(dName);
			var nameWrap = document.createElement('div');
			nameWrap.className = 'tn-rr-std-name-wrap';
			var nameSpan = document.createElement('span');
			nameSpan.className = 'tn-rr-std-name';
			nameSpan.textContent = dName;
			nameWrap.appendChild(nameSpan);
			if (pInfo && pInfo.ParkName) {
				var parkSpan = document.createElement('small');
				parkSpan.className = 'tn-rr-std-park';
				parkSpan.textContent = pInfo.ParkName;
				nameWrap.appendChild(parkSpan);
			}
			playerWrap.appendChild(avatar);
			playerWrap.appendChild(nameWrap);
			tdPlayer.appendChild(playerWrap);
			tr.appendChild(tdPlayer);

			// W / L / T
			var tdW = document.createElement('td'); tdW.className = 'tn-rr-std-w'; tdW.textContent = row.w; tr.appendChild(tdW);
			var tdL = document.createElement('td'); tdL.className = 'tn-rr-std-l'; tdL.textContent = row.l; tr.appendChild(tdL);
			var tdT = document.createElement('td'); tdT.className = 'tn-rr-std-t'; tdT.textContent = row.t; tr.appendChild(tdT);

			// Pts
			var tdPts = document.createElement('td'); tdPts.className = 'tn-rr-std-pts'; tdPts.textContent = row.pts; tr.appendChild(tdPts);

			// Win%
			var tdPct = document.createElement('td'); tdPct.className = 'tn-rr-std-winpct';
			tdPct.textContent = (row.pct * 100).toFixed(1) + '%'; tr.appendChild(tdPct);

			// Progress bar
			var tdProgress = document.createElement('td');
			tdProgress.className = 'tn-rr-std-progress';
			var barOuter = document.createElement('div');
			barOuter.className = 'tn-rr-std-bar';
			var barTrack = document.createElement('div');
			barTrack.className = 'tn-rr-std-bar-track';
			var barFill = document.createElement('div');
			barFill.className = 'tn-rr-std-bar-fill';
			var barPct = row.totalPossible > 0 ? (row.played / row.totalPossible) * 100 : 0;
			barFill.style.width = barPct.toFixed(1) + '%';
			barTrack.appendChild(barFill);
			barOuter.appendChild(barTrack);
			var barText = document.createElement('span');
			barText.className = 'tn-rr-std-bar-text';
			barText.textContent = row.played + '/' + row.totalPossible;
			barOuter.appendChild(barText);
			tdProgress.appendChild(barOuter);
			tr.appendChild(tdProgress);

			tbody.appendChild(tr);
		});
		table.appendChild(tbody);
		container.appendChild(table);

		container._tnSetActivePlayer = function(pid) {
			if (activePlayerId && rowEls[activePlayerId]) rowEls[activePlayerId].classList.remove('tn-rr-std-active');
			activePlayerId = pid;
			if (pid && rowEls[pid]) rowEls[pid].classList.add('tn-rr-std-active');
		};

		return rows;
	}

	// ── Champion banner for Round Robin ──
	function renderRRChampionBanner(container, stdRows, pMap) {
		if (!stdRows || stdRows.length === 0) return;

		var banner = document.createElement('div');
		banner.className = 'tn-bv-champion-banner';

		var champRow = document.createElement('div');
		champRow.className = 'tn-bv-champion-row';
		var trophyEl = document.createElement('div');
		trophyEl.className = 'tn-bv-champion-trophy';
		trophyEl.innerHTML = '&#x1F3C6;';
		champRow.appendChild(trophyEl);

		var champInfo = document.createElement('div');
		champInfo.className = 'tn-bv-champion-info';
		var champLabel = document.createElement('div');
		champLabel.className = 'tn-bv-champion-label';
		champLabel.textContent = 'Champion';
		champInfo.appendChild(champLabel);

		var champ = stdRows[0];
		var champData = pMap[champ.p];
		var champName = champData ? (champData.Alias || champData.Persona || 'Unknown') : 'Unknown';
		var champNameEl = document.createElement('div');
		champNameEl.className = 'tn-bv-champion-name';
		champNameEl.textContent = champName;
		champInfo.appendChild(champNameEl);

		if (champData && champData.ParkName) {
			var champPark = document.createElement('div');
			champPark.className = 'tn-bv-champion-park';
			champPark.textContent = champData.ParkName;
			champInfo.appendChild(champPark);
		}
		champRow.appendChild(champInfo);
		banner.appendChild(champRow);

		var podium = document.createElement('div');
		podium.className = 'tn-bv-podium';
		var medals = [
			{ rank: 1, cls: 'tn-bv-podium-1st', label: '1st' },
			{ rank: 2, cls: 'tn-bv-podium-2nd', label: '2nd' },
			{ rank: 3, cls: 'tn-bv-podium-3rd', label: '3rd' }
		];
		medals.forEach(function(medal) {
			var player = null;
			for (var i = 0; i < stdRows.length; i++) {
				if (stdRows[i].rank === medal.rank) { player = stdRows[i]; break; }
			}
			if (!player) return;
			var card = document.createElement('div');
			card.className = 'tn-bv-podium-card ' + medal.cls;
			var rankBadge = document.createElement('div');
			rankBadge.className = 'tn-bv-podium-rank';
			rankBadge.textContent = medal.label;
			card.appendChild(rankBadge);
			var pData = pMap[player.p];
			var pName = pData ? (pData.Alias || pData.Persona || '?') : '?';
			var av = document.createElement('div');
			av.className = 'tn-bv-podium-avatar';
			av.style.backgroundColor = tnAvatarColor(player.p);
			av.textContent = tnInitials(pName);
			card.appendChild(av);
			var nameEl = document.createElement('div');
			nameEl.className = 'tn-bv-podium-name';
			nameEl.textContent = pName;
			card.appendChild(nameEl);
			if (pData && pData.ParkName) {
				var parkEl = document.createElement('div');
				parkEl.className = 'tn-bv-podium-park';
				parkEl.textContent = pData.ParkName;
				card.appendChild(parkEl);
			}
			var statsEl = document.createElement('div');
			statsEl.className = 'tn-bv-podium-stats';
			statsEl.textContent = player.w + 'W-' + player.l + 'L-' + player.t + 'T \u2022 ' + player.pts + ' pts';
			card.appendChild(statsEl);
			podium.appendChild(card);
		});
		banner.appendChild(podium);
		container.insertBefore(banner, container.firstChild);
	}

	// ── Enhance match card for Round Robin (add W-L record) ──
	function enhanceRRMatchCard(box, m, pMap, rrStats) {
		var slots = box.querySelectorAll('.tn-bv-slot');
		[{ pid: parseInt(m.Participant1Id) || 0, idx: 0 }, { pid: parseInt(m.Participant2Id) || 0, idx: 1 }].forEach(function(info) {
			if (!info.pid || info.idx >= slots.length) return;
			var st = rrStats[String(info.pid)];
			if (!st || st.played === 0) return;
			var slot = slots[info.idx];
			var badge = document.createElement('span');
			badge.className = 'tn-rr-card-record';
			badge.textContent = '(' + st.w + '-' + st.l + (st.t > 0 ? '-' + st.t : '') + ')';
			badge.title = st.w + 'W ' + st.l + 'L' + (st.t > 0 ? ' ' + st.t + 'T' : '');
			var pill = slot.querySelector('.tn-bv-result-pill');
			if (pill) slot.insertBefore(badge, pill);
			else slot.appendChild(badge);
		});
	}

	// ── Round-table renderer (Swiss / Round Robin) — Enhanced ──
	function renderRoundTable(container, matches, pMap, bracketId) {
		// Compute shared stats
		var pids = Object.keys(pMap);
		var totalPossible = pids.length > 1 ? (pids.length * (pids.length - 1)) / 2 : 0;
		var rrStats = {};
		pids.forEach(function(pid) { rrStats[pid] = { w: 0, l: 0, t: 0, played: 0 }; });
		var completedMatches = 0;
		matches.forEach(function(m) {
			if (!m.Result || m.Result === '') return;
			completedMatches++;
			var p1 = String(m.Participant1Id), p2 = String(m.Participant2Id);
			if (rrStats[p1]) rrStats[p1].played++;
			if (rrStats[p2]) rrStats[p2].played++;
			if (m.Result === '1-wins' || m.Result === 'forfeit' || m.Result === 'disqualified') {
				if (rrStats[p1]) rrStats[p1].w++; if (rrStats[p2]) rrStats[p2].l++;
			} else if (m.Result === '2-wins') {
				if (rrStats[p2]) rrStats[p2].w++; if (rrStats[p1]) rrStats[p1].l++;
			} else if (m.Result === 'tie') {
				if (rrStats[p1]) rrStats[p1].t++; if (rrStats[p2]) rrStats[p2].t++;
			}
		});

		// Group by round
		var rounds = {};
		var maxRound = 0;
		matches.forEach(function(m) {
			var r = parseInt(m.Round) || 1;
			if (!rounds[r]) rounds[r] = [];
			rounds[r].push(m);
			if (r > maxRound) maxRound = r;
		});

		// Header: view toggle
		var headerRow = document.createElement('div');
		headerRow.style.cssText = 'display:flex;align-items:center;gap:10px;margin-bottom:12px;flex-wrap:wrap';
		var viewToggle = document.createElement('div');
		viewToggle.className = 'tn-rr-view-toggle';
		var btnRounds = document.createElement('button');
		btnRounds.className = 'tn-rr-view-toggle-btn active';
		btnRounds.innerHTML = '<i class="fas fa-list" style="margin-right:5px"></i>Rounds';
		var btnMatrix = document.createElement('button');
		btnMatrix.className = 'tn-rr-view-toggle-btn';
		btnMatrix.innerHTML = '<i class="fas fa-th" style="margin-right:5px"></i>Matrix';
		viewToggle.appendChild(btnRounds);
		viewToggle.appendChild(btnMatrix);
		headerRow.appendChild(viewToggle);
		container.appendChild(headerRow);

		// Overall progress bar
		if (totalPossible > 0) {
			var progressWrap = document.createElement('div');
			progressWrap.className = 'tn-rr-progress-wrap';
			var progressBar = document.createElement('div');
			progressBar.className = 'tn-rr-progress-bar';
			var pctComplete = (completedMatches / totalPossible) * 100;
			if (pctComplete < 35) progressBar.classList.add('tn-rr-progress-low');
			var progressFill = document.createElement('div');
			progressFill.className = 'tn-rr-progress-fill';
			progressFill.style.width = pctComplete.toFixed(1) + '%';
			progressBar.appendChild(progressFill);
			var progressLabel = document.createElement('div');
			progressLabel.className = 'tn-rr-progress-label';
			progressLabel.textContent = completedMatches + ' of ' + totalPossible + ' matches complete (' + Math.round(pctComplete) + '%)';
			progressBar.appendChild(progressLabel);
			progressWrap.appendChild(progressBar);
			container.appendChild(progressWrap);
		}

		// Focus banner (hidden initially)
		var focusBanner = document.createElement('div');
		focusBanner.className = 'tn-rr-focus-banner';
		focusBanner.style.display = 'none';
		focusBanner.innerHTML = '<i class="fas fa-filter" style="font-size:11px"></i> Showing matches for <span class="tn-rr-focus-banner-name"></span>';
		var focusClose = document.createElement('button');
		focusClose.className = 'tn-rr-focus-banner-close';
		focusClose.innerHTML = '&times;';
		focusBanner.appendChild(focusClose);
		container.appendChild(focusBanner);

		var standingsContainer = null;
		var focusedPlayer = null;

		function setPlayerFocus(pid) {
			focusedPlayer = pid;
			if (pid) {
				container.classList.add('tn-rr-focus-active');
				var pInfo = pMap[pid];
				focusBanner.querySelector('.tn-rr-focus-banner-name').textContent = pInfo ? (pInfo.Alias || pInfo.Persona || '?') : '?';
				focusBanner.style.display = '';
				// Highlight matching match cards
				container.querySelectorAll('.tn-bv-match').forEach(function(card) {
					var mid = card.dataset.matchid;
					var m = matches.find(function(mm) { return String(mm.MatchId) === mid; });
					if (m && (String(m.Participant1Id) === String(pid) || String(m.Participant2Id) === String(pid))) {
						card.classList.add('tn-rr-focus-match');
					} else {
						card.classList.remove('tn-rr-focus-match');
					}
				});
				// Highlight matching matrix rows
				container.querySelectorAll('.tn-rr-matrix tbody tr').forEach(function(tr) {
					if (tr.dataset.pid === String(pid)) tr.classList.add('tn-rr-focus-row');
					else tr.classList.remove('tn-rr-focus-row');
				});
				if (standingsContainer && standingsContainer._tnSetActivePlayer) standingsContainer._tnSetActivePlayer(pid);
			} else {
				container.classList.remove('tn-rr-focus-active');
				focusBanner.style.display = 'none';
				container.querySelectorAll('.tn-rr-focus-match').forEach(function(el) { el.classList.remove('tn-rr-focus-match'); });
				container.querySelectorAll('.tn-rr-focus-row').forEach(function(el) { el.classList.remove('tn-rr-focus-row'); });
				if (standingsContainer && standingsContainer._tnSetActivePlayer) standingsContainer._tnSetActivePlayer(null);
			}
		}
		focusClose.onclick = function() { setPlayerFocus(null); };

		// ── Rounds view ──
		var roundsView = document.createElement('div');
		roundsView.className = 'tn-rr-rounds-view';

		var nav = document.createElement('div');
		nav.className = 'tn-bv-round-nav';
		var _savedRound = parseInt(sessionStorage.getItem('tnRRActiveRound_' + bracketId)) || 0;
		var _activeRound = (_savedRound >= 1 && _savedRound <= maxRound) ? _savedRound : 1;

		for (var r = 1; r <= maxRound; r++) {
			(function(round) {
				var btn = document.createElement('button');
				btn.className = 'tn-bv-round-btn' + (round === _activeRound ? ' active' : '');
				var rMatches = rounds[round] || [];
				var rDone = rMatches.filter(function(m) { return m.Result && m.Result !== ''; }).length;
				btn.textContent = 'Round ' + round + ' ';
				var countBadge = document.createElement('span');
				countBadge.className = 'tn-rr-round-count';
				countBadge.textContent = rDone + '/' + rMatches.length;
				btn.appendChild(countBadge);
				btn.dataset.round = round;
				btn.addEventListener('click', function() {
					nav.querySelectorAll('.tn-bv-round-btn').forEach(function(b) { b.classList.remove('active'); });
					btn.classList.add('active');
					roundsView.querySelectorAll('.tn-bv-round-section').forEach(function(s) {
						s.style.display = parseInt(s.dataset.round) === round ? '' : 'none';
					});
					sessionStorage.setItem('tnRRActiveRound_' + bracketId, round);
				});
				nav.appendChild(btn);
			})(r);
		}
		roundsView.appendChild(nav);

		for (var r = 1; r <= maxRound; r++) {
			(function(round) {
				var section = document.createElement('div');
				section.className = 'tn-bv-round-section';
				section.dataset.round = round;
				section.style.display = round === _activeRound ? '' : 'none';
				var body = document.createElement('div');
				body.className = 'tn-rr-round-body';
				var rMatches = (rounds[round] || []).sort(function(a,b) { return (a.Order||0)-(b.Order||0); });
				rMatches.forEach(function(m) {
					var box = buildMatchBox(m, pMap, matches);
					enhanceRRMatchCard(box, m, pMap, rrStats);
					body.appendChild(box);
				});
				section.appendChild(body);
				roundsView.appendChild(section);
			})(r);
		}

		// Mark complete rounds
		var firstIncomplete = -1;
		for (var rc = 1; rc <= maxRound; rc++) {
			var rcMatches = rounds[rc] || [];
			var allDone = rcMatches.length > 0 && rcMatches.every(function(m) { return m.Result && m.Result !== ''; });
			if (allDone) {
				var rcBtn = nav.querySelector('[data-round="' + rc + '"]');
				if (rcBtn) rcBtn.classList.add('tn-rr-complete');
			} else if (firstIncomplete === -1) {
				firstIncomplete = rc;
			}
		}
		if (firstIncomplete > 1) {
			var pulseBtn = nav.querySelector('[data-round="' + firstIncomplete + '"]');
			if (pulseBtn) pulseBtn.classList.add('tn-rr-next-pulse');
		}

		container.appendChild(roundsView);

		// ── Matrix view (hidden by default) ──
		var matrixView = document.createElement('div');
		matrixView.className = 'tn-rr-matrix-view';
		matrixView.style.display = 'none';
		renderMatrixView(matrixView, matches, pMap);
		container.appendChild(matrixView);

		// View toggle wiring
		btnRounds.onclick = function() {
			btnRounds.classList.add('active'); btnMatrix.classList.remove('active');
			roundsView.style.display = ''; matrixView.style.display = 'none';
			sessionStorage.setItem('tnRRView_' + bracketId, 'rounds');
		};
		btnMatrix.onclick = function() {
			btnMatrix.classList.add('active'); btnRounds.classList.remove('active');
			matrixView.style.display = ''; roundsView.style.display = 'none';
			sessionStorage.setItem('tnRRView_' + bracketId, 'matrix');
		};
		// Restore saved view
		var _savedView = sessionStorage.getItem('tnRRView_' + bracketId);
		if (_savedView === 'matrix') { btnMatrix.onclick(); }

		// ── Enhanced standings ──
		if (completedMatches > 0) {
			standingsContainer = document.createElement('div');
			var stdRows = renderEnhancedStandings(standingsContainer, matches, pMap, function(pid) {
				setPlayerFocus(pid);
			});
			container.appendChild(standingsContainer);

			// Champion banner (if bracket is complete/finalized)
			var bd0 = TnConfig.bracketData[bracketId];
			var bracketSt = bd0 && bd0.Bracket ? (bd0.Bracket.Status || '') : '';
			if (bracketSt === 'complete' || bracketSt === 'finalized') {
				renderRRChampionBanner(container, stdRows, pMap);
			}
		}
	}


		// Initialize on page load
	document.addEventListener('DOMContentLoaded', function() {
		// Restore bracket collapse state across reloads
		var collKey = 'tnCollapsed_' + TnConfig.tournamentId;
		var collState = JSON.parse(sessionStorage.getItem(collKey) || '{}');
		Object.keys(collState).forEach(function(bid) {
			if (collState[bid]) {
				var card = document.getElementById('tn-bracket-' + bid);
				if (card) card.classList.add('tn-collapsed');
			}
		});

		var tabToOpen = sessionStorage.getItem('tnOpenTab');
		if (tabToOpen) { sessionStorage.removeItem('tnOpenTab'); tnActivateTab(tabToOpen); }
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
	var tnBoutLabelShown = false;
	var bouts = [null, null, null, null, null]; // null | '1' | '2' per bout
	var p1Name = '—', p2Name = '—';

	// ---- Pip rendering ----
	function renderPips() {
		for (var i = 0; i < 5; i++) {
			var pip1 = document.querySelector('#tn-rr-pips-1 [data-idx="' + i + '"]');
			var pip2 = document.querySelector('#tn-rr-pips-2 [data-idx="' + i + '"]');
			if (!pip1 || !pip2) continue;
			pip1.className = 'tn-bout-pip';
			pip2.className = 'tn-bout-pip';
			if (bouts[i] === '1') { pip1.classList.add('tn-pip-win'); pip2.classList.add('tn-pip-loss'); }
			else if (bouts[i] === '2') { pip2.classList.add('tn-pip-win'); pip1.classList.add('tn-pip-loss'); }
		}
		updateScoreDisplay();
		updateResultFromBouts();
	}

	// ---- Score display ----
	function updateScoreDisplay() {
		var p1 = bouts.filter(function(b) { return b === '1'; }).length;
		var p2 = bouts.filter(function(b) { return b === '2'; }).length;
		var el = document.getElementById('tn-rr-bout-score');
		if (el) el.textContent = (p1 + p2 > 0) ? (p1 + ' – ' + p2) : '';
	}

	// ---- Auto-populate result dropdown from pip state ----
	function updateResultFromBouts() {
		var p1 = bouts.filter(function(b) { return b === '1'; }).length;
		var p2 = bouts.filter(function(b) { return b === '2'; }).length;
		var sel = document.getElementById('tn-rr-result');
		if (!sel || p1 + p2 === 0) return;
		if (p1 > p2)      sel.value = '1-wins';
		else if (p2 > p1) sel.value = '2-wins';
		else              sel.value = 'tie';
	}

	// ---- Pip click handler ----
	['tn-rr-pips-1','tn-rr-pips-2'].forEach(function(containerId) {
		var container = document.getElementById(containerId);
		if (!container) return;
		container.addEventListener('click', function(e) {
			var pip = e.target.closest('.tn-bout-pip');
			if (!pip) return;
			var side = pip.dataset.side; // '1' or '2'
			var idx  = parseInt(pip.dataset.idx, 10);
			bouts[idx] = (bouts[idx] === side) ? null : side; // toggle or set
			renderPips();
		});
	});

	// ---- Open modal ----
	window.tnOpenRecordResult = function(match, p1, p2) {
		bouts = [null, null, null, null, null];
		p1Name = p1 ? (p1.Alias || p1.Persona || '—') : '—';
		p2Name = p2 ? (p2.Alias || p2.Persona || '—') : '—';
		document.getElementById('tn-recordresult-match-id').value = match.MatchId;
		document.getElementById('tn-rr-p1-name').textContent = p1Name;
		document.getElementById('tn-rr-p2-name').textContent = p2Name;
		var opt1 = document.getElementById('tn-rr-opt-p1wins');
		var opt2 = document.getElementById('tn-rr-opt-p2wins');
		if (opt1) opt1.textContent = p1Name + ' wins';
		if (opt2) opt2.textContent = p2Name + ' wins';
		var _bid = match.BracketId, _bdata = TnConfig.bracketData[_bid], _method = _bdata && _bdata.Bracket ? _bdata.Bracket.Method : '';
		document.getElementById('tn-rr-round-info').textContent = _method === 'ironman'
			? 'Fight #' + (match.Match || '')
			: 'Round ' + match.Round + ', Match ' + (match.Match || '');
		document.getElementById('tn-rr-result').value = '';
		document.getElementById('tn-rr-bout-score').textContent = '';
		renderPips();
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
			var btn    = this;
			var matchId = document.getElementById('tn-recordresult-match-id').value;
			var tid     = document.getElementById('tn-recordresult-tournament-id').value;
			var result  = document.getElementById('tn-rr-result').value;
			var p1w     = bouts.filter(function(b) { return b === '1'; }).length;
			var p2w     = bouts.filter(function(b) { return b === '2'; }).length;
			var winnerW = (result === '2-wins') ? p2w : p1w;
			var loserW  = (result === '2-wins') ? p1w : p2w;
			var score   = (p1w + p2w > 0) ? (winnerW + '-' + loserW) : '';

			if (!result) { tnShowFeedback('tn-recordresult-feedback', 'Please select a result.', false); return; }

			var url = TnConfig.uir + 'TournamentAjax/match/' + matchId + '/' + tid;
			btn.disabled = true;
			var fd = new FormData();
			fd.append('Result', result);
			fd.append('Score',  score);
			fd.append('Bouts',  JSON.stringify(bouts.filter(function(b) { return b !== null; })));

			fetch(url, { method:'POST', body:fd })
				.then(function(r) { return r.json(); })
				.then(function(d) {
					btn.disabled = false;
					if (d && d.status === 0) {
						tnShowFeedback('tn-recordresult-feedback', 'Result saved!', true);
						setTimeout(function() {
							tnCloseModal(OVERLAY);
							var sel = document.getElementById('tn-bv-bracket-select');
							var bid = sel ? parseInt(sel.value) : 0;
							if (bid && TnConfig.bracketData[bid]) {
								Promise.all([
									fetch(TnConfig.uir + 'TournamentAjax/bracket/' + bid + '/matches').then(function(r) { return r.json(); }),
									fetch(TnConfig.uir + 'TournamentAjax/tournament/' + TnConfig.tournamentId + '/brackets').then(function(r) { return r.json(); })
								]).then(function(res2) {
									var md = res2[0], bd2 = res2[1];
									if (md && md.status === 0) TnConfig.bracketData[bid].Matches = md.matches;
									if (bd2 && bd2.status === 0 && bd2.brackets && TnConfig.bracketData[bid]) {
										var br = bd2.brackets.find(function(b) { return parseInt(b.BracketId) === parseInt(bid); });
										if (br) TnConfig.bracketData[bid].Bracket = br;
									}
									tnRenderBracketViz(bid);
								});
							}
						}, 400);
					} else {
						tnShowFeedback('tn-recordresult-feedback', (d && d.error) ? d.error : 'Failed to save result.', false);
					}
				})
				.catch(function() { btn.disabled = false; tnShowFeedback('tn-recordresult-feedback', 'Request failed.', false); });
		});
	}


window.tnToggleParticipantMenu = function(btn) {
	var menu = btn.parentNode.querySelector('.tn-status-menu');
	if (!menu) return;
	// Close all other open menus first
	document.querySelectorAll('.tn-status-menu.tn-status-open').forEach(function(m) {
		if (m !== menu) m.classList.remove('tn-status-open');
	});
	menu.classList.toggle('tn-status-open');
};

window.tnSetParticipantStatus = function(pid, status, bid, menuItemEl) {
	var fd = new FormData();
	fd.append('ParticipantId', pid);
	fd.append('Status', status);
	fd.append('TournamentId', TnConfig.tournamentId);
	fetch(TnConfig.uir + 'TournamentAjax/bracket/' + bid + '/updateparticipantstatus', {method:'POST', body:fd})
		.then(function(r) { if (!r.ok) throw new Error('HTTP ' + r.status); return r.json(); })
		.then(function(d) {
			if (d && d.status === 0) {
				var li = menuItemEl.closest('li');
				if (li) {
					// Clear all status classes
					['active','withdrawn','disqualified'].forEach(function(s) {
						li.classList.remove('tn-pstatus-' + s);
					});
					li.classList.remove('tn-checked');
					if (status !== 'active') li.classList.add('tn-pstatus-' + status);
					if (status === 'present') li.classList.add('tn-checked');
					li.dataset.status = status;


					// Update active indicator in menu
					var menu = menuItemEl.closest('.tn-status-menu');
					if (menu) {
						menu.querySelectorAll('.tn-status-menu-item').forEach(function(item) {
							item.classList.remove('tn-sm-active');
						});
						menuItemEl.classList.add('tn-sm-active');
					}

					// Update status pills
					li.querySelectorAll('.tn-pstatus-pill').forEach(function(pill) { pill.remove(); });
					var nameSpan = li.querySelector('span[style*="flex:1"]');
					if (nameSpan && status === 'withdrawn') {
						var pill = document.createElement('span');
						pill.className = 'tn-pstatus-pill tn-pstatus-pill-withdrawn';
						pill.textContent = 'WD';
						nameSpan.appendChild(pill);
					} else if (nameSpan && status === 'disqualified') {
						var pill = document.createElement('span');
						pill.className = 'tn-pstatus-pill tn-pstatus-pill-disqualified';
						pill.textContent = 'DQ';
						nameSpan.appendChild(pill);
					}
				}
				// Close the menu
				var menuWrap = menuItemEl.closest('.tn-status-menu');
				if (menuWrap) menuWrap.classList.remove('tn-status-open');
			} else {
				alert((d && d.error) ? d.error : 'Failed to update status.');
			}
		})
		.catch(function() { alert('Network error updating status.'); });
};

// Close status menus when clicking elsewhere
document.addEventListener('click', function(e) {
	if (!e.target.closest('.tn-status-wrap')) {
		document.querySelectorAll('.tn-status-menu.tn-status-open').forEach(function(m) {
			m.classList.remove('tn-status-open');
		});
	}
});

window.tnSubmitQuickResult = function(matchId, result, event) {
	if (event) event.stopPropagation();
	var tid = TnConfig.tournamentId;
	var fd = new FormData();
	fd.append('Result', result);
	fd.append('Score', '');
	fd.append('Bouts', '[]');

	fetch(TnConfig.uir + 'TournamentAjax/match/' + matchId + '/' + tid, {method:'POST', body:fd})
		.then(function(r) { return r.json(); })
		.then(function(d) {
			if (d && d.status === 0) {
				var sel = document.getElementById('tn-bv-bracket-select');
				var bid = sel ? parseInt(sel.value) : 0;
				if (bid && TnConfig.bracketData[bid]) {
					var _tid = TnConfig.tournamentId;
					Promise.all([
						fetch(TnConfig.uir + 'TournamentAjax/bracket/' + bid + '/matches').then(function(r) { return r.json(); }),
						fetch(TnConfig.uir + 'TournamentAjax/tournament/' + _tid + '/brackets').then(function(r) { return r.json(); })
					]).then(function(results) {
						var md = results[0], bd = results[1];
						if (md && md.status === 0) TnConfig.bracketData[bid].Matches = md.matches;
						if (bd && bd.status === 0 && bd.brackets && TnConfig.bracketData[bid]) {
							var br = bd.brackets.find(function(b) { return parseInt(b.BracketId) === parseInt(bid); });
							if (br) TnConfig.bracketData[bid].Bracket = br;
						}
						tnRenderBracketViz(bid);
					});
				}
			} else {
				alert((d && d.error) ? d.error : 'Failed to save result.');
			}
		})
		.catch(function() { alert('Network error recording result.'); });
};

})();
</script>

<!-- =====================================================================
     UX workflow layer.
     Each section is an independent, revertable feature. Remove a
     section by deleting its labeled block — every section is a
     self-contained function invocation that does not depend on the
     others. No shared state beyond TnConfig.
     ===================================================================== -->
<script>
(function(){
	'use strict';
	function $(id){ return document.getElementById(id); }
	function esc(s){ return String(s==null?'':s).replace(/[&<>"']/g, function(c){ return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]; }); }
	function openOv(id){ var el=$(id); if(el) el.classList.add('tn-open'); }
	function closeOv(id){ var el=$(id); if(el) el.classList.remove('tn-open'); }

	// ================================================================
	// TASK 11 · PASTE ROSTER
	// Bulk-adds participants one line at a time via the existing
	// TournamentAjax/bracket/{bid}/addparticipant endpoint. Shows inline
	// progress, single reload at the end.
	// ================================================================
	window.tnOpenBulkAddModal = function(bracketId, tournamentId){
		if (!TnConfig.canManage) return;
		$('tn-bulkadd-bracket-id').value    = bracketId;
		$('tn-bulkadd-tournament-id').value = tournamentId;
		$('tn-bulkadd-text').value = '';
		$('tn-bulkadd-feedback').style.display = 'none';
		$('tn-bulkadd-progress').style.display = 'none';
		$('tn-bulkadd-submit').disabled = false;
		openOv('tn-bulkadd-overlay');
		setTimeout(function(){ var t = $('tn-bulkadd-text'); if (t) t.focus(); }, 80);
	};
	function closeBulkAdd(){ closeOv('tn-bulkadd-overlay'); }
	['tn-bulkadd-close','tn-bulkadd-cancel'].forEach(function(id){
		var el = $(id); if (el) el.addEventListener('click', closeBulkAdd);
	});
	var _bulkOv = $('tn-bulkadd-overlay');
	if (_bulkOv) _bulkOv.addEventListener('click', function(e){ if (e.target === _bulkOv) closeBulkAdd(); });

	// ================================================================
	// TASK 13 · Pip majority → soft auto-commit
	// The Record Result modal already mirrors pip state to the result
	// dropdown. What it does not do is save without a button click.
	// When one fighter reaches mathematical majority (3+ of 5, or any
	// state where the other side can no longer tie), we start a 2s
	// visible countdown and auto-click the submit button. Any pip
	// click or a modal close cancels.
	// ================================================================
	(function(){
		var rrOverlay  = $('tn-recordresult-overlay');
		var scoreEl    = $('tn-rr-bout-score');
		if (!rrOverlay || !scoreEl) return;

		var commitTimer = null;
		var countdownTimer = null;
		var originalScoreHTML = '';

		function countWins(side){
			return document.querySelectorAll('#tn-rr-pips-' + side + ' .tn-pip-win').length;
		}

		function cancelCommit(){
			if (commitTimer){ clearTimeout(commitTimer); commitTimer = null; }
			if (countdownTimer){ clearInterval(countdownTimer); countdownTimer = null; }
			if (scoreEl.dataset.tnAutocommit === '1'){
				scoreEl.dataset.tnAutocommit = '';
				scoreEl.style.color = '';
				// let renderPips / updateScoreDisplay repaint naturally on the next click
			}
		}

		function startCommit(winnerLabel){
			cancelCommit();
			scoreEl.dataset.tnAutocommit = '1';
			scoreEl.style.color = '#276749';
			var remaining = 2;
			function paint(){
				scoreEl.innerHTML = '<strong>' + winnerLabel + '</strong> &middot; saving in ' + remaining + 's &middot; <a href="#" id="tn-rr-cancel-commit" style="color:#e53e3e;text-decoration:underline">cancel</a>';
				var c = $('tn-rr-cancel-commit');
				if (c) c.addEventListener('click', function(e){ e.preventDefault(); cancelCommit(); });
			}
			paint();
			countdownTimer = setInterval(function(){
				remaining--;
				if (remaining <= 0){ clearInterval(countdownTimer); countdownTimer = null; return; }
				paint();
			}, 1000);
			commitTimer = setTimeout(function(){
				commitTimer = null;
				scoreEl.dataset.tnAutocommit = '';
				scoreEl.style.color = '';
				var sb = $('tn-recordresult-submit');
				if (sb && !sb.disabled) sb.click();
			}, 2000);
		}

		function evaluate(){
			var p1 = countWins(1);
			var p2 = countWins(2);
			var total = p1 + p2;
			if (total === 0){ cancelCommit(); return; }
			// Mathematical majority of best-of-5: |p1-p2| greater than pips remaining
			var remaining = 5 - total;
			if (p1 > p2 && (p1 - p2) > remaining){
				var n1 = $('tn-rr-p1-name') ? $('tn-rr-p1-name').textContent : 'Player 1';
				startCommit(n1 + ' wins');
			} else if (p2 > p1 && (p2 - p1) > remaining){
				var n2 = $('tn-rr-p2-name') ? $('tn-rr-p2-name').textContent : 'Player 2';
				startCommit(n2 + ' wins');
			} else {
				cancelCommit();
			}
		}

		// Piggyback on pip clicks: the existing click handler fires first
		// (it was attached with addEventListener during IIFE init), then
		// our bubble-phase listener reads the freshly-painted pip classes.
		['tn-rr-pips-1','tn-rr-pips-2'].forEach(function(id){
			var el = $(id);
			if (!el) return;
			el.addEventListener('click', function(){
				setTimeout(evaluate, 0); // after existing handler completes
			});
		});

		// Closing the modal cancels any pending commit
		var mo = new MutationObserver(function(){
			if (!rrOverlay.classList.contains('tn-open')) cancelCommit();
		});
		mo.observe(rrOverlay, { attributes: true, attributeFilter: ['class'] });
	})();

	// ================================================================
	// TASK 12 · ARM-AND-FIRE Re-generate
	// Intercepts the re-generate button click when the bracket has
	// existing matches. First click "arms" the button (label swaps to
	// a red COMMIT state, 4s timeout). Second click within the window
	// runs the real tnGenerateMatches. Clicking anywhere else disarms.
	// ================================================================
	(function(){
		var armedBtn = null;
		var armedTimer = null;
		var armedOriginal = null;

		function disarm(){
			if (!armedBtn) return;
			armedBtn.innerHTML = armedOriginal;
			armedBtn.classList.remove('tn-btn-danger');
			armedBtn.classList.add('tn-btn-primary');
			armedBtn.removeAttribute('data-armed');
			armedBtn = null;
			if (armedTimer){ clearTimeout(armedTimer); armedTimer = null; }
		}

		window.tnRegenArm = function(btn, ev){
			if (ev) { ev.preventDefault(); ev.stopPropagation(); }
			if (!btn) return false;
			var bid = parseInt(btn.getAttribute('data-bid'), 10);
			var tid = parseInt(btn.getAttribute('data-tid'), 10);
			var n   = parseInt(btn.getAttribute('data-match-count'), 10) || 0;
			if (btn.getAttribute('data-armed') === '1'){
				// Second click — fire
				disarm();
				window.tnGenerateMatches(bid, tid);
				return false;
			}
			// First click — arm, show countdown
			if (armedBtn && armedBtn !== btn) disarm();
			armedBtn = btn;
			armedOriginal = btn.innerHTML;
			btn.classList.remove('tn-btn-primary');
			btn.classList.add('tn-btn-danger');
			btn.setAttribute('data-armed', '1');
			var remaining = 4;
			function render(){
				btn.innerHTML = '<i class="fas fa-exclamation-triangle"></i> Click to wipe ' + n + ' match' + (n===1?'':'es') + ' &middot; ' + remaining + 's';
			}
			render();
			var tick = function(){
				remaining--;
				if (remaining <= 0){ disarm(); return; }
				render();
				armedTimer = setTimeout(tick, 1000);
			};
			armedTimer = setTimeout(tick, 1000);
			return false;
		};

		// Click anywhere else disarms
		document.addEventListener('click', function(e){
			if (!armedBtn) return;
			if (e.target === armedBtn || armedBtn.contains(e.target)) return;
			disarm();
		}, true);
	})();

	var _bulkBtn = $('tn-bulkadd-submit');
	if (_bulkBtn) _bulkBtn.addEventListener('click', function(){
		var text = $('tn-bulkadd-text').value || '';
		var bid  = $('tn-bulkadd-bracket-id').value;
		var tid  = $('tn-bulkadd-tournament-id').value;
		var fb   = $('tn-bulkadd-feedback');
		var prog = $('tn-bulkadd-progress');
		var lines = text.split(/\r?\n/).map(function(l){ return l.trim(); }).filter(function(l){ return l.length > 0; });
		if (!lines.length){
			fb.className = 'tn-feedback tn-feedback-err';
			fb.textContent = 'Paste at least one alias.';
			fb.style.display = '';
			return;
		}
		_bulkBtn.disabled = true;
		fb.style.display = 'none';
		prog.style.display = '';
		var i = 0, ok = 0, fail = 0;
		function step(){
			if (i >= lines.length){
				prog.textContent = 'Done — added ' + ok + (fail ? ', ' + fail + ' failed' : '') + '.';
				setTimeout(function(){ closeBulkAdd(); window.location.reload(); }, fail ? 1400 : 500);
				return;
			}
			var alias = lines[i];
			prog.textContent = 'Adding ' + (i+1) + ' of ' + lines.length + ' — ' + alias;
			var fd = new FormData();
			fd.append('Alias', alias);
			fd.append('TournamentId', tid);
			fetch(TnConfig.uir + 'TournamentAjax/bracket/' + bid + '/addparticipant', { method:'POST', body: fd })
				.then(function(r){ return r.json(); })
				.then(function(d){ if (d && d.status === 0) ok++; else fail++; })
				.catch(function(){ fail++; })
				.finally(function(){ i++; step(); });
		}
		step();
	});

})();
</script>
