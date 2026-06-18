<?php
/**
 * Officer Dashboard Panel
 * Shared between Kingdomnew and Parknew profile templates.
 *
 * Expects in parent scope:
 *   $OfficerContext = [
 *     'IsOfficer' => bool,
 *     'Role'      => 'Monarch'|'Prime Minister'|'Regent'|'Champion'|'Guildmaster of Reeves',
 *     'Level'     => 'kingdom'|'park',
 *     'AllOfficesHeld' => array of ['Role' => ..., 'Level' => ..., 'KingdomId' => .., 'ParkId' => ..],
 *     'ScopeName' => string (kingdom or park name),
 *     'TermStartDate' => 'YYYY-MM-DD' or null,
 *     'Data' => role-specific payload (see controller.Kingdom.php / controller.Park.php)
 *   ]
 *   $kingdom_id, $park_id, $kingdom_name, $park_name (as applicable per level)
 */

if (empty($OfficerContext) || empty($OfficerContext['IsOfficer'])) { return; }

$ocRole   = $OfficerContext['Role']  ?? '';
$ocLevel  = $OfficerContext['Level'] ?? '';
$ocData   = $OfficerContext['Data']  ?? [];
$ocScopeName = $OfficerContext['ScopeName'] ?? '';
$ocAllOffices = $OfficerContext['AllOfficesHeld'] ?? [];
$ocTermStart  = $OfficerContext['TermStartDate'] ?? null;

$roleShort = [
    'Monarch'         => 'Monarch',
    'Prime Minister'  => 'PM',
    'Regent'          => 'Regent',
    'Champion'        => 'Champion',
    'GMR' => 'GMR',
];
$roleIcon = [
    'Monarch'         => 'fa-crown',
    'Prime Minister'  => 'fa-scroll',
    'Regent'          => 'fa-palette',
    'Champion'        => 'fa-shield',
    'GMR' => 'fa-gavel',
];
$ocRoleShort = $roleShort[$ocRole] ?? $ocRole;
$ocRoleIcon  = $roleIcon[$ocRole]  ?? 'fa-star';
$ocLevelLabel = $ocLevel === 'kingdom' ? 'Kingdom' : 'Park';

// Term-progress computation (if term start known)
$termInfo = null;
if ($ocTermStart) {
    $termLenMonths = 6; // sensible default; kingdoms can override later
    $start = strtotime($ocTermStart);
    $end   = strtotime("+{$termLenMonths} months", $start);
    $now   = time();
    $totalDays = max(1, (int)(($end - $start) / 86400));
    $elapsed   = max(0, (int)(($now - $start) / 86400));
    $remaining = max(0, (int)(($end - $now) / 86400));
    $pct       = min(100, max(0, (int)round(100 * $elapsed / $totalDays)));
    $termInfo = [
        'start'     => $ocTermStart,
        'end'       => date('Y-m-d', $end),
        'elapsed'   => $elapsed,
        'remaining' => $remaining,
        'pct'       => $pct,
    ];
}
?>

<div class="od-dashboard">

	<!-- Header card: role, scope, term progress -->
	<div class="od-header-card">
		<div class="od-header-main">
			<div class="od-header-icon"><i class="fas <?= htmlspecialchars($ocRoleIcon) ?>"></i></div>
			<div class="od-header-text">
				<div class="od-header-eyebrow"><?= htmlspecialchars($ocLevelLabel) ?> Office</div>
				<div class="od-header-title">You are <?= htmlspecialchars($ocRole) ?> of <?= htmlspecialchars($ocScopeName) ?></div>
				<?php if (count($ocAllOffices) > 1): ?>
					<div class="od-header-sub">Also holding:
						<?php $others = array_filter($ocAllOffices, function($o) use ($ocRole, $ocLevel) {
							return !($o['Role'] === $ocRole && $o['Level'] === $ocLevel);
						});
						$bits = array_map(function($o) {
							$lvl = $o['Level'] === 'kingdom' ? 'Kingdom' : 'Park';
							return htmlspecialchars($lvl . ' ' . $o['Role']);
						}, $others);
						echo implode(' · ', $bits);
						?>
					</div>
				<?php endif; ?>
			</div>
		</div>
		<?php if ($termInfo): ?>
			<div class="od-term-progress">
				<div class="od-term-label">
					<span>Term progress</span>
					<span><?= $termInfo['remaining'] ?> days remaining</span>
				</div>
				<div class="od-term-bar"><div class="od-term-bar-fill" style="width: <?= (int)$termInfo['pct'] ?>%"></div></div>
				<div class="od-term-range">
					<span><?= htmlspecialchars($termInfo['start']) ?></span>
					<span>~<?= htmlspecialchars($termInfo['end']) ?></span>
				</div>
			</div>
		<?php endif; ?>
	</div>

	<?php
	$__ofcRole  = $ocRole;
	$__ofcLevel = $ocLevel;
	$__ofcMap = [
		'Monarch|kingdom'        => 'od_monarch_kingdom.tpl',
		'Monarch|park'           => 'od_monarch_park.tpl',
		'Prime Minister|kingdom' => 'od_pm_kingdom.tpl',
		'Prime Minister|park'    => 'od_pm_park.tpl',
		'Regent|kingdom'         => 'od_regent_kingdom.tpl',
		'Regent|park'            => 'od_regent_park.tpl',
		'Champion|kingdom'       => 'od_champion_kingdom.tpl',
		'Champion|park'          => 'od_champion_park.tpl',
		'GMR|kingdom'            => 'od_gmr_kingdom.tpl',
		'GMR|park'               => 'od_gmr_park.tpl',
	];
	$__ofcKey = $__ofcRole . '|' . $__ofcLevel;
	if (isset($__ofcMap[$__ofcKey])) {
		include __DIR__ . '/dashboard/' . $__ofcMap[$__ofcKey];
	} else {
	?>
		<div class="od-widget-row">
			<div class="od-widget od-widget-soon">
				<div class="od-widget-head"><h3>Dashboard not yet available</h3></div>
				<div class="od-widget-body">
					<p class="od-soon-note">No dashboard has been built yet for this office (<?= htmlspecialchars($ocRole) ?> / <?= htmlspecialchars($ocLevel) ?>).</p>
				</div>
			</div>
		</div>
	<?php } ?>

<style>
/* Officer Dashboard — scoped to .od- prefix; dark-mode compat via [data-theme="dark"] */
.od-dashboard { display: flex; flex-direction: column; gap: 18px; padding: 6px 0 40px; }
.od-header-card {
	display: flex; flex-direction: column; gap: 14px;
	padding: 18px 22px; border: 1px solid #ccc; border-radius: 10px;
	background: linear-gradient(135deg, rgba(255,255,255,0.85), rgba(245,245,248,0.85));
	box-shadow: 0 2px 6px rgba(0,0,0,0.04);
}
.od-header-main { display: flex; align-items: center; gap: 18px; }
.od-header-icon {
	width: 56px; height: 56px; min-width: 56px;
	display: flex; align-items: center; justify-content: center;
	background: linear-gradient(135deg, #e9d6ff, #c5a8ff); border-radius: 14px;
	font-size: 26px; color: #4a1a99;
}
.od-header-text { flex: 1; min-width: 0; }
.od-header-eyebrow { font-size: 11px; text-transform: uppercase; letter-spacing: 0.1em; color: #777; }
.od-header-title {
	font-size: 20px; font-weight: 600; color: #222; margin-top: 2px;
	/* Must reset global h-like styling — .od-header-title is a <div>, safe */
}
.od-header-sub { font-size: 12px; color: #555; margin-top: 4px; }
.od-term-progress { display: flex; flex-direction: column; gap: 6px; }
.od-term-label { display: flex; justify-content: space-between; font-size: 12px; color: #555; }
.od-term-bar { height: 8px; background: #eee; border-radius: 4px; overflow: hidden; border: 1px solid #ddd; }
.od-term-bar-fill { height: 100%; background: linear-gradient(90deg, #5d3fb8, #8b6cff); transition: width 0.4s ease; }
.od-term-range { display: flex; justify-content: space-between; font-size: 11px; color: #888; }

.od-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 12px; }
.od-stat-card {
	background: #fff; border: 1px solid #e1e1e6; border-radius: 10px;
	padding: 16px 14px; text-align: center;
	box-shadow: 0 1px 3px rgba(0,0,0,0.04);
}
.od-stat-num { font-size: 28px; font-weight: 700; color: #333; line-height: 1.1; }
.od-stat-lbl { font-size: 11px; color: #666; text-transform: uppercase; letter-spacing: 0.05em; margin-top: 6px; }

.od-widget-row { display: grid; grid-template-columns: repeat(auto-fit, minmax(340px, 1fr)); gap: 14px; }
.od-widget {
	background: #fff; border: 1px solid #e1e1e6; border-radius: 10px;
	display: flex; flex-direction: column; overflow: hidden;
	box-shadow: 0 1px 3px rgba(0,0,0,0.04);
}
.od-widget-wide { grid-column: 1 / -1; }
.od-widget-head {
	display: flex; align-items: center; justify-content: space-between; gap: 12px;
	padding: 12px 16px; border-bottom: 1px solid #eee; background: #fafbfc;
}
.od-widget-head h3 {
	font-size: 14px; font-weight: 600; color: #333; margin: 0;
	/* Reset global h1-h6 styling */
	background: transparent; border: none; padding: 0; border-radius: 0; text-shadow: none;
}
.od-subline { font-size: 11px; color: #888; font-style: italic; }
.od-widget-body { padding: 12px 16px; flex: 1; }
.od-widget-soon { background: #fbf8ff; border-color: #e0d5f4; }
.od-widget-soon .od-widget-head { background: #f3ebff; border-bottom-color: #e0d5f4; }

.od-link { display: inline-flex; align-items: center; gap: 6px; color: #5d3fb8; text-decoration: none; font-size: 12px; font-weight: 600; }
.od-link:hover { color: #442a8c; text-decoration: underline; }
.od-link i { font-size: 10px; }

.od-table { width: 100%; border-collapse: collapse; font-size: 13px; }
.od-table thead th {
	text-align: left; padding: 6px 8px; color: #555; font-weight: 600;
	border-bottom: 1px solid #eee; font-size: 11px; text-transform: uppercase; letter-spacing: 0.04em;
	/* Reset global th styling */
	background: transparent; text-shadow: none;
}
.od-table tbody td { padding: 8px; border-bottom: 1px solid #f3f3f5; color: #333; }
.od-table tbody tr:last-child td { border-bottom: none; }
.od-table tbody tr:hover { background: rgba(93, 63, 184, 0.04); }
.od-table-compact thead th, .od-table-compact tbody td { padding: 5px 8px; font-size: 12.5px; }
.od-table a { color: #5d3fb8; text-decoration: none; }
.od-table a:hover { text-decoration: underline; }
.od-row-vacant td { background: #fff8e6; }
.od-row-vacant td:first-child { font-weight: 600; }

.od-pill { display: inline-block; padding: 2px 8px; border-radius: 10px; font-size: 10px; font-weight: 700; text-transform: uppercase; }
.od-pill-warn { background: #fde8c4; color: #8a5a00; }
.od-pill-ok { background: #d1f0d9; color: #1f6a36; }

.od-empty { padding: 18px; text-align: center; color: #999; font-size: 13px; font-style: italic; }
.od-empty-ok { color: #1f6a36; background: #f0fbf4; border-radius: 6px; font-style: normal; }
.od-empty-ok i { margin-right: 6px; }

.od-links-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(140px, 1fr)); gap: 8px; }
.od-link-card {
	display: flex; flex-direction: column; align-items: center; gap: 6px;
	padding: 14px 10px; background: #fafbfc; border: 1px solid #e1e1e6; border-radius: 8px;
	color: #444; text-decoration: none; font-size: 12px; text-align: center;
	transition: all 0.12s ease;
}
.od-link-card:hover { border-color: #5d3fb8; color: #5d3fb8; background: #f5f0ff; text-decoration: none; }
.od-link-card i { font-size: 18px; color: #5d3fb8; }

.od-soon-list { list-style: none; padding: 0; margin: 0; }
.od-soon-list li { padding: 8px 6px; display: flex; align-items: center; gap: 10px; color: #666; font-size: 13px; border-bottom: 1px dashed #e5dff2; }
.od-soon-list li:last-child { border-bottom: none; }
.od-soon-list i { color: #8b6cff; width: 18px; text-align: center; }
.od-soon-note { color: #555; font-size: 13px; margin: 0 0 10px 0; line-height: 1.45; }
.od-soon-note code { background: #f0ebf8; padding: 1px 5px; border-radius: 3px; color: #442a8c; font-size: 12px; }

/* Dark mode */
html[data-theme="dark"] .od-header-card {
	background: linear-gradient(135deg, var(--ork-card-bg), var(--ork-bg-secondary));
	border-color: var(--ork-border); color: var(--ork-text);
}
html[data-theme="dark"] .od-header-icon { background: linear-gradient(135deg, #3a2168, #5d3fb8); color: #d6c5ff; }
html[data-theme="dark"] .od-header-title { color: var(--ork-text); }
html[data-theme="dark"] .od-header-eyebrow { color: var(--ork-text-secondary); }
html[data-theme="dark"] .od-header-sub { color: var(--ork-text-secondary); }
html[data-theme="dark"] .od-term-label { color: var(--ork-text-secondary); }
html[data-theme="dark"] .od-term-bar { background: var(--ork-bg-tertiary); border-color: var(--ork-border); }
html[data-theme="dark"] .od-term-range { color: var(--ork-text-muted, #888); }

html[data-theme="dark"] .od-stat-card { background: var(--ork-card-bg); border-color: var(--ork-border); }
html[data-theme="dark"] .od-stat-num { color: var(--ork-text); }
html[data-theme="dark"] .od-stat-lbl { color: var(--ork-text-secondary); }

html[data-theme="dark"] .od-widget { background: var(--ork-card-bg); border-color: var(--ork-border); }
html[data-theme="dark"] .od-widget-head { background: var(--ork-bg-secondary); border-bottom-color: var(--ork-border); }
html[data-theme="dark"] .od-widget-head h3 { color: var(--ork-text); }
html[data-theme="dark"] .od-widget-soon { background: #1e1830; border-color: #3a2e56; }
html[data-theme="dark"] .od-widget-soon .od-widget-head { background: #251d3b; border-bottom-color: #3a2e56; }

html[data-theme="dark"] .od-table thead th { color: var(--ork-text-secondary); border-bottom-color: var(--ork-border); }
html[data-theme="dark"] .od-table tbody td { color: var(--ork-text); border-bottom-color: var(--ork-border); }
html[data-theme="dark"] .od-table tbody tr:hover { background: rgba(139, 108, 255, 0.08); }
html[data-theme="dark"] .od-table a { color: #b197ff; }
html[data-theme="dark"] .od-row-vacant td { background: rgba(255, 180, 60, 0.08); }

html[data-theme="dark"] .od-empty { color: var(--ork-text-secondary); }
html[data-theme="dark"] .od-empty-ok { color: #8cd9a4; background: rgba(80, 190, 120, 0.08); }

html[data-theme="dark"] .od-link-card { background: var(--ork-bg-secondary); border-color: var(--ork-border); color: var(--ork-text); }
html[data-theme="dark"] .od-link-card:hover { background: #2a1f4a; color: #b197ff; border-color: #5d3fb8; }
html[data-theme="dark"] .od-link-card i { color: #b197ff; }

html[data-theme="dark"] .od-soon-list li { color: var(--ork-text-secondary); border-bottom-color: #3a2e56; }
html[data-theme="dark"] .od-soon-note { color: var(--ork-text-secondary); }
html[data-theme="dark"] .od-soon-note code { background: #2a1f4a; color: #b197ff; }
html[data-theme="dark"] .od-link { color: #b197ff; }
html[data-theme="dark"] .od-link:hover { color: #d6c5ff; }

/* Collapsible section groups */
.od-section { display: flex; flex-direction: column; gap: 10px; margin-top: 18px; }
.od-section-head {
	display: flex; align-items: center; justify-content: space-between; gap: 10px;
	padding: 8px 14px; background: linear-gradient(135deg, #eae0ff, #d6c5ff);
	border: 1px solid #c5a8ff; border-radius: 8px;
	cursor: pointer; user-select: none;
	transition: all 0.12s ease;
}
.od-section-head:hover { background: linear-gradient(135deg, #dfd1ff, #c9b3ff); }
.od-section-title {
	font-size: 13px; font-weight: 700; color: #4a1a99;
	text-transform: uppercase; letter-spacing: 0.08em;
	display: flex; align-items: center; gap: 8px;
	background: transparent; border: none; padding: 0; border-radius: 0; text-shadow: none;
	margin: 0;
}
.od-section-title i { font-size: 15px; }
.od-section-caret { transition: transform 0.18s ease; color: #6a3db8; }
.od-section.od-section-closed .od-section-body { display: none; }
.od-section.od-section-closed .od-section-caret { transform: rotate(-90deg); }
.od-section-body { display: flex; flex-direction: column; gap: 12px; padding-top: 4px; }
.od-section-desc { font-size: 11px; color: #666; font-style: italic; }

html[data-theme="dark"] .od-section-head { background: linear-gradient(135deg, #2a1f4a, #3a2e56); border-color: #4a3e76; }
html[data-theme="dark"] .od-section-head:hover { background: linear-gradient(135deg, #332654, #44366a); }
html[data-theme="dark"] .od-section-title { color: #d6c5ff; }
html[data-theme="dark"] .od-section-caret { color: #b197ff; }
html[data-theme="dark"] .od-section-desc { color: var(--ork-text-secondary); }

/* Chart primitives — pure SVG, painted by JS */
.od-chart { display: block; width: 100%; max-width: 100%; }
.od-chart-bar { height: 140px; }
.od-chart-donut, .od-chart-pie { height: 180px; }
.od-chart-ring { height: 120px; }
.od-chart-heatmap { min-height: 80px; }
.od-chart-stack { height: 180px; }

.od-chart-bar-rect { fill: #5d3fb8; transition: fill 0.15s; }
.od-chart-bar-rect:hover { fill: #8b6cff; }
.od-chart-bar-label { font-size: 10px; fill: #666; text-anchor: middle; }
.od-chart-bar-value { font-size: 10px; fill: #333; font-weight: 600; text-anchor: middle; }
.od-chart-axis { stroke: #ddd; stroke-width: 1; }

.od-chart-slice { transition: transform 0.2s; transform-origin: center; }
.od-chart-slice:hover { transform: scale(1.03); }
.od-chart-center-val { font-size: 22px; font-weight: 700; fill: #333; text-anchor: middle; }
.od-chart-center-lbl { font-size: 10px; fill: #666; text-anchor: middle; text-transform: uppercase; letter-spacing: 0.05em; }
.od-chart-legend { display: flex; flex-wrap: wrap; gap: 8px 14px; margin-top: 8px; font-size: 11px; color: #555; }
.od-chart-legend-dot { display: inline-block; width: 10px; height: 10px; border-radius: 2px; margin-right: 5px; vertical-align: middle; }

.od-chart-ring-track { fill: none; stroke: #eee; stroke-width: 10; }
.od-chart-ring-fill  { fill: none; stroke: #5d3fb8; stroke-width: 10; stroke-linecap: round; transition: stroke-dashoffset 0.5s; }
.od-chart-ring-text  { font-size: 20px; font-weight: 700; fill: #333; text-anchor: middle; dominant-baseline: central; }
.od-chart-ring-sub   { font-size: 10px; fill: #777; text-anchor: middle; text-transform: uppercase; }

.od-heatmap-cell { stroke: #fff; stroke-width: 2; }
.od-heatmap-label { font-size: 9px; fill: #888; }

html[data-theme="dark"] .od-chart-bar-rect { fill: #8b6cff; }
html[data-theme="dark"] .od-chart-bar-rect:hover { fill: #b197ff; }
html[data-theme="dark"] .od-chart-bar-label { fill: var(--ork-text-secondary); }
html[data-theme="dark"] .od-chart-bar-value { fill: var(--ork-text); }
html[data-theme="dark"] .od-chart-axis { stroke: var(--ork-border); }
html[data-theme="dark"] .od-chart-center-val { fill: var(--ork-text); }
html[data-theme="dark"] .od-chart-center-lbl { fill: var(--ork-text-secondary); }
html[data-theme="dark"] .od-chart-legend { color: var(--ork-text-secondary); }
html[data-theme="dark"] .od-chart-ring-track { stroke: var(--ork-border); }
html[data-theme="dark"] .od-chart-ring-fill  { stroke: #b197ff; }
html[data-theme="dark"] .od-chart-ring-text  { fill: var(--ork-text); }
html[data-theme="dark"] .od-chart-ring-sub   { fill: var(--ork-text-secondary); }
html[data-theme="dark"] .od-heatmap-cell { stroke: var(--ork-card-bg); }
html[data-theme="dark"] .od-heatmap-label { fill: var(--ork-text-secondary); }

/* Pagination controls */
.od-pager { display: flex; align-items: center; justify-content: space-between; gap: 10px; padding: 6px 10px 0; margin-top: 4px; font-size: 12px; color: #666; border-top: 1px dashed #eee; }
.od-pager-info { font-variant-numeric: tabular-nums; }
.od-pager-btns { display: inline-flex; gap: 4px; }
.od-pager-btn {
	padding: 3px 9px; border: 1px solid #ddd; border-radius: 4px; background: #fafbfc;
	color: #444; cursor: pointer; font-size: 11px; line-height: 1.4;
	transition: all 0.12s ease;
}
.od-pager-btn:hover:not(:disabled) { background: #5d3fb8; color: #fff; border-color: #5d3fb8; }
.od-pager-btn:disabled { opacity: 0.35; cursor: default; }

/* Sparkline */
.od-spark { display: block; width: 100%; height: 48px; }
.od-spark-path { stroke: #5d3fb8; stroke-width: 2; fill: none; }
.od-spark-fill { fill: rgba(93, 63, 184, 0.12); }
.od-spark-dot { fill: #5d3fb8; }
.od-spark-label { font-size: 11px; fill: #888; }

/* Coverage cell marks */
.od-cov-yes { color: #1f6a36; }
.od-cov-no  { color: #c44; }

/* Collapsible */
.od-collapse-toggle { font-size: 11px; color: #5d3fb8; cursor: pointer; text-transform: uppercase; letter-spacing: 0.04em; user-select: none; }
.od-collapse-toggle:hover { text-decoration: underline; }
.od-collapsed .od-widget-body { display: none; }

html[data-theme="dark"] .od-pager { color: var(--ork-text-secondary); border-top-color: var(--ork-border); }
html[data-theme="dark"] .od-pager-btn { background: var(--ork-bg-secondary); border-color: var(--ork-border); color: var(--ork-text); }
html[data-theme="dark"] .od-pager-btn:hover:not(:disabled) { background: #5d3fb8; color: #fff; border-color: #5d3fb8; }
html[data-theme="dark"] .od-spark-path { stroke: #b197ff; }
html[data-theme="dark"] .od-spark-fill { fill: rgba(177, 151, 255, 0.2); }
html[data-theme="dark"] .od-spark-dot  { fill: #b197ff; }
html[data-theme="dark"] .od-spark-label { fill: var(--ork-text-secondary); }
html[data-theme="dark"] .od-cov-yes { color: #8cd9a4; }
html[data-theme="dark"] .od-cov-no  { color: #ff9090; }
html[data-theme="dark"] .od-collapse-toggle { color: #b197ff; }

@media (max-width: 720px) {
	.od-header-main { flex-direction: column; align-items: flex-start; }
	.od-widget-row { grid-template-columns: 1fr; }
}
</style>

<script>
(function() {
	function initPagination(root) {
		var tables = root.querySelectorAll('table.od-table[data-od-paginate]');
		tables.forEach(function(tbl) {
			if (tbl.dataset.odPaginated === '1') return;
			var size = parseInt(tbl.dataset.odPaginate, 10) || 5;
			var tbody = tbl.tBodies[0];
			if (!tbody) return;
			var rows = Array.prototype.slice.call(tbody.rows);
			if (rows.length <= size) return;  // no pagination needed

			var pages = Math.ceil(rows.length / size);
			var cur = 0;

			var pager = document.createElement('div');
			pager.className = 'od-pager';
			pager.innerHTML =
				'<span class="od-pager-info"></span>' +
				'<span class="od-pager-btns">' +
					'<button type="button" class="od-pager-btn" data-dir="first">&laquo;</button>' +
					'<button type="button" class="od-pager-btn" data-dir="prev">&lsaquo; Prev</button>' +
					'<button type="button" class="od-pager-btn" data-dir="next">Next &rsaquo;</button>' +
					'<button type="button" class="od-pager-btn" data-dir="last">&raquo;</button>' +
				'</span>';
			tbl.parentNode.insertBefore(pager, tbl.nextSibling);

			var info = pager.querySelector('.od-pager-info');

			function render() {
				rows.forEach(function(r, i) {
					r.style.display = (i >= cur * size && i < (cur + 1) * size) ? '' : 'none';
				});
				var start = cur * size + 1;
				var end = Math.min(rows.length, (cur + 1) * size);
				info.textContent = start + '–' + end + ' of ' + rows.length;
				pager.querySelector('[data-dir="first"]').disabled = cur === 0;
				pager.querySelector('[data-dir="prev"]').disabled  = cur === 0;
				pager.querySelector('[data-dir="next"]').disabled  = cur >= pages - 1;
				pager.querySelector('[data-dir="last"]').disabled  = cur >= pages - 1;
			}
			pager.addEventListener('click', function(e) {
				var d = e.target.getAttribute && e.target.getAttribute('data-dir');
				if (!d) return;
				if (d === 'first') cur = 0;
				else if (d === 'last') cur = pages - 1;
				else if (d === 'prev') cur = Math.max(0, cur - 1);
				else if (d === 'next') cur = Math.min(pages - 1, cur + 1);
				render();
			});
			tbl.dataset.odPaginated = '1';
			render();
		});
	}

	function drawSparklines(root) {
		root.querySelectorAll('svg.od-spark[data-values]').forEach(function(svg) {
			if (svg.dataset.drawn === '1') return;
			var raw = svg.dataset.values || '';
			var vals = raw.split(',').map(function(v) { return parseFloat(v) || 0; });
			if (!vals.length) return;
			var W = svg.clientWidth || 240;
			var H = svg.clientHeight || 48;
			var max = Math.max.apply(null, vals);
			var min = Math.min.apply(null, vals);
			var range = max - min || 1;
			var step = vals.length > 1 ? W / (vals.length - 1) : 0;
			var pts = vals.map(function(v, i) {
				var x = Math.round(i * step);
				var y = Math.round(H - ((v - min) / range) * (H - 8) - 4);
				return x + ',' + y;
			});
			var ns = 'http://www.w3.org/2000/svg';
			var pathPoly = document.createElementNS(ns, 'polygon');
			pathPoly.setAttribute('class', 'od-spark-fill');
			pathPoly.setAttribute('points', '0,' + H + ' ' + pts.join(' ') + ' ' + W + ',' + H);
			var pathLine = document.createElementNS(ns, 'polyline');
			pathLine.setAttribute('class', 'od-spark-path');
			pathLine.setAttribute('points', pts.join(' '));
			svg.appendChild(pathPoly);
			svg.appendChild(pathLine);
			// final dot
			var lastPt = pts[pts.length - 1].split(',');
			var dot = document.createElementNS(ns, 'circle');
			dot.setAttribute('class', 'od-spark-dot');
			dot.setAttribute('cx', lastPt[0]);
			dot.setAttribute('cy', lastPt[1]);
			dot.setAttribute('r', 3);
			svg.appendChild(dot);
			svg.dataset.drawn = '1';
		});
	}

	function initCollapsibles(root) {
		root.querySelectorAll('.od-collapse-toggle').forEach(function(t) {
			if (t.dataset.bound === '1') return;
			t.dataset.bound = '1';
			t.addEventListener('click', function() {
				var w = t.closest('.od-widget');
				if (!w) return;
				w.classList.toggle('od-collapsed');
				t.textContent = w.classList.contains('od-collapsed') ? 'Expand' : 'Collapse';
			});
		});
	}

	
	function drawBarCharts(root) {
		root.querySelectorAll('svg.od-chart-bar[data-values]').forEach(function(svg) {
			if (svg.dataset.drawn === '1') return;
			var vals = (svg.dataset.values || '').split(',').map(function(v){return parseFloat(v)||0;});
			var labels = (svg.dataset.labels || '').split('|');
			var orientation = svg.dataset.orientation || 'vertical';
			var W = svg.clientWidth || 300;
			var H = parseInt(getComputedStyle(svg).height) || 140;
			svg.setAttribute('viewBox', '0 0 ' + W + ' ' + H);
			var ns = 'http://www.w3.org/2000/svg';
			var max = Math.max.apply(null, vals.concat(1));
			if (orientation === 'horizontal') {
				var rowH = (H - 10) / vals.length;
				var labelW = 90;
				vals.forEach(function(v, i) {
					var y = 5 + i * rowH;
					var bh = rowH - 4;
					var bw = Math.max(1, (v / max) * (W - labelW - 40));
					var lbl = document.createElementNS(ns, 'text');
					lbl.setAttribute('x', 4); lbl.setAttribute('y', y + bh / 2 + 3);
					lbl.setAttribute('class', 'od-chart-bar-label');
					lbl.setAttribute('text-anchor', 'start');
					lbl.textContent = labels[i] || '';
					svg.appendChild(lbl);
					var rect = document.createElementNS(ns, 'rect');
					rect.setAttribute('x', labelW); rect.setAttribute('y', y);
					rect.setAttribute('width', bw); rect.setAttribute('height', bh);
					rect.setAttribute('rx', 2);
					rect.setAttribute('class', 'od-chart-bar-rect');
					svg.appendChild(rect);
					var vlbl = document.createElementNS(ns, 'text');
					vlbl.setAttribute('x', labelW + bw + 5);
					vlbl.setAttribute('y', y + bh / 2 + 3);
					vlbl.setAttribute('text-anchor', 'start');
					vlbl.setAttribute('class', 'od-chart-bar-value');
					vlbl.textContent = v;
					svg.appendChild(vlbl);
				});
			} else {
				var colW = W / vals.length;
				var chartH = H - 30;
				vals.forEach(function(v, i) {
					var bh = Math.max(1, (v / max) * chartH);
					var bw = colW * 0.7;
					var x = i * colW + (colW - bw) / 2;
					var y = chartH - bh + 8;
					var rect = document.createElementNS(ns, 'rect');
					rect.setAttribute('x', x); rect.setAttribute('y', y);
					rect.setAttribute('width', bw); rect.setAttribute('height', bh);
					rect.setAttribute('rx', 2);
					rect.setAttribute('class', 'od-chart-bar-rect');
					svg.appendChild(rect);
					if (labels[i]) {
						var l = document.createElementNS(ns, 'text');
						l.setAttribute('x', x + bw/2); l.setAttribute('y', H - 6);
						l.setAttribute('class', 'od-chart-bar-label');
						l.textContent = labels[i];
						svg.appendChild(l);
					}
					var vv = document.createElementNS(ns, 'text');
					vv.setAttribute('x', x + bw/2); vv.setAttribute('y', y - 2);
					vv.setAttribute('class', 'od-chart-bar-value');
					vv.textContent = v;
					svg.appendChild(vv);
				});
			}
			svg.dataset.drawn = '1';
		});
	}

	function polarToCart(cx, cy, r, angle) {
		return [cx + r * Math.cos(angle), cy + r * Math.sin(angle)];
	}
	function sliceArcPath(cx, cy, r, ir, start, end) {
		var ns = 'http://www.w3.org/2000/svg';
		var p0 = polarToCart(cx, cy, r, start);
		var p1 = polarToCart(cx, cy, r, end);
		var p2 = polarToCart(cx, cy, ir, end);
		var p3 = polarToCart(cx, cy, ir, start);
		var large = (end - start) > Math.PI ? 1 : 0;
		return 'M '+p0[0]+' '+p0[1]+
		       ' A '+r+' '+r+' 0 '+large+' 1 '+p1[0]+' '+p1[1]+
		       ' L '+p2[0]+' '+p2[1]+
		       ' A '+ir+' '+ir+' 0 '+large+' 0 '+p3[0]+' '+p3[1]+' Z';
	}

	function drawDonuts(root) {
		var palette = ['#5d3fb8','#8b6cff','#b197ff','#d6c5ff','#ff9090','#8cd9a4','#ffb84d','#4dc2d9','#f57ec5','#a5b8c9'];
		root.querySelectorAll('svg.od-chart-donut[data-values], svg.od-chart-pie[data-values]').forEach(function(svg) {
			if (svg.dataset.drawn === '1') return;
			var isPie = svg.classList.contains('od-chart-pie');
			var vals = (svg.dataset.values || '').split(',').map(function(v){return parseFloat(v)||0;});
			var labels = (svg.dataset.labels || '').split('|');
			var centerLbl = svg.dataset.centerLabel || '';
			var total = vals.reduce(function(a,b){return a+b;}, 0);
			if (total <= 0) return;
			var W = svg.clientWidth || 300;
			var H = parseInt(getComputedStyle(svg).height) || 180;
			svg.setAttribute('viewBox', '0 0 ' + W + ' ' + H);
			var ns = 'http://www.w3.org/2000/svg';
			var cx = W/2, cy = H/2;
			var r = Math.min(W, H) / 2 - 8;
			var ir = isPie ? 0 : r * 0.55;
			var angle = -Math.PI / 2;
			vals.forEach(function(v, i) {
				if (v <= 0) return;
				var sweep = (v / total) * 2 * Math.PI;
				var path = document.createElementNS(ns, 'path');
				path.setAttribute('d', sliceArcPath(cx, cy, r, ir, angle, angle + sweep));
				path.setAttribute('fill', palette[i % palette.length]);
				path.setAttribute('class', 'od-chart-slice');
				svg.appendChild(path);
				angle += sweep;
			});
			if (!isPie && centerLbl) {
				var v = document.createElementNS(ns, 'text');
				v.setAttribute('x', cx); v.setAttribute('y', cy - 4);
				v.setAttribute('class', 'od-chart-center-val');
				v.textContent = total;
				svg.appendChild(v);
				var l = document.createElementNS(ns, 'text');
				l.setAttribute('x', cx); l.setAttribute('y', cy + 12);
				l.setAttribute('class', 'od-chart-center-lbl');
				l.textContent = centerLbl;
				svg.appendChild(l);
			}
			// Legend sibling
			var wrap = svg.parentNode;
			if (wrap && !wrap.querySelector('.od-chart-legend')) {
				var leg = document.createElement('div');
				leg.className = 'od-chart-legend';
				labels.forEach(function(lbl, i) {
					if (!lbl) return;
					var s = document.createElement('span');
					s.innerHTML = '<span class="od-chart-legend-dot" style="background:' + palette[i % palette.length] + '"></span>' + lbl + ' (' + vals[i] + ')';
					leg.appendChild(s);
				});
				wrap.appendChild(leg);
			}
			svg.dataset.drawn = '1';
		});
	}

	function drawRings(root) {
		root.querySelectorAll('svg.od-chart-ring[data-value]').forEach(function(svg) {
			if (svg.dataset.drawn === '1') return;
			var v = parseFloat(svg.dataset.value) || 0;
			var max = parseFloat(svg.dataset.max) || 100;
			var label = svg.dataset.label || '';
			var W = svg.clientWidth || 180;
			var H = parseInt(getComputedStyle(svg).height) || 120;
			svg.setAttribute('viewBox', '0 0 ' + W + ' ' + H);
			var ns = 'http://www.w3.org/2000/svg';
			var cx = W/2, cy = H/2, r = Math.min(W, H)/2 - 10;
			var track = document.createElementNS(ns, 'circle');
			track.setAttribute('cx', cx); track.setAttribute('cy', cy); track.setAttribute('r', r);
			track.setAttribute('class', 'od-chart-ring-track');
			svg.appendChild(track);
			var fill = document.createElementNS(ns, 'circle');
			fill.setAttribute('cx', cx); fill.setAttribute('cy', cy); fill.setAttribute('r', r);
			fill.setAttribute('class', 'od-chart-ring-fill');
			fill.setAttribute('transform', 'rotate(-90 ' + cx + ' ' + cy + ')');
			var circ = 2 * Math.PI * r;
			fill.setAttribute('stroke-dasharray', circ);
			var pct = Math.max(0, Math.min(1, v / max));
			fill.setAttribute('stroke-dashoffset', circ * (1 - pct));
			svg.appendChild(fill);
			var t = document.createElementNS(ns, 'text');
			t.setAttribute('x', cx); t.setAttribute('y', cy - 4);
			t.setAttribute('class', 'od-chart-ring-text');
			t.textContent = svg.dataset.display || (Math.round(pct * 100) + '%');
			svg.appendChild(t);
			if (label) {
				var sub = document.createElementNS(ns, 'text');
				sub.setAttribute('x', cx); sub.setAttribute('y', cy + 12);
				sub.setAttribute('class', 'od-chart-ring-sub');
				sub.textContent = label;
				svg.appendChild(sub);
			}
			svg.dataset.drawn = '1';
		});
	}

	function drawHeatmaps(root) {
		root.querySelectorAll('svg.od-chart-heatmap[data-matrix]').forEach(function(svg) {
			if (svg.dataset.drawn === '1') return;
			var rows = (svg.dataset.matrix || '').split(';').map(function(r){return r.split(',').map(function(v){return parseFloat(v)||0;});});
			var colLabels = (svg.dataset.cols || '').split('|');
			var rowLabels = (svg.dataset.rows || '').split('|');
			if (!rows.length || !rows[0].length) return;
			var W = svg.clientWidth || 400;
			var cellH = 22;
			var labelW = 70, topH = 18;
			var H = rows.length * cellH + topH + 6;
			svg.setAttribute('viewBox', '0 0 ' + W + ' ' + H);
			svg.style.height = H + 'px';
			var ns = 'http://www.w3.org/2000/svg';
			var max = 1;
			rows.forEach(function(r){r.forEach(function(v){if (v > max) max = v;});});
			var cellW = (W - labelW - 6) / rows[0].length;
			colLabels.forEach(function(cl, j) {
				var t = document.createElementNS(ns, 'text');
				t.setAttribute('x', labelW + j * cellW + cellW/2);
				t.setAttribute('y', 12);
				t.setAttribute('class', 'od-heatmap-label');
				t.setAttribute('text-anchor', 'middle');
				t.textContent = cl || '';
				svg.appendChild(t);
			});
			rows.forEach(function(r, i) {
				var rl = document.createElementNS(ns, 'text');
				rl.setAttribute('x', 0); rl.setAttribute('y', topH + i * cellH + cellH/2 + 3);
				rl.setAttribute('class', 'od-heatmap-label');
				rl.setAttribute('text-anchor', 'start');
				rl.textContent = rowLabels[i] || '';
				svg.appendChild(rl);
				r.forEach(function(v, j) {
					var op = max > 0 ? v / max : 0;
					var cell = document.createElementNS(ns, 'rect');
					cell.setAttribute('x', labelW + j * cellW);
					cell.setAttribute('y', topH + i * cellH);
					cell.setAttribute('width', cellW - 1);
					cell.setAttribute('height', cellH - 1);
					cell.setAttribute('fill', 'rgba(93, 63, 184,' + Math.max(0.05, op) + ')');
					cell.setAttribute('class', 'od-heatmap-cell');
					var tt = document.createElementNS(ns, 'title');
					tt.textContent = (rowLabels[i] || '') + ' / ' + (colLabels[j] || '') + ': ' + v;
					cell.appendChild(tt);
					svg.appendChild(cell);
				});
			});
			svg.dataset.drawn = '1';
		});
	}

	function initSections(root) {
		root.querySelectorAll('.od-section-head').forEach(function(h) {
			if (h.dataset.bound === '1') return;
			h.dataset.bound = '1';
			h.addEventListener('click', function() {
				var s = h.closest('.od-section');
				if (s) s.classList.toggle('od-section-closed');
			});
		});
	}

	function initAll() {
		var roots = document.querySelectorAll('.od-dashboard');
		roots.forEach(function(r) {
			initPagination(r);
			drawSparklines(r);
			drawBarCharts(r);
			drawDonuts(r);
			drawRings(r);
			drawHeatmaps(r);
			initCollapsibles(r);
			initSections(r);
		});
	}

	if (document.readyState === 'loading') {
		document.addEventListener('DOMContentLoaded', initAll);
	} else {
		initAll();
	}
	// Re-init on tab-switch (dashboard is inside a hidden panel at page-load for some users)
	setTimeout(initAll, 200);
	setTimeout(initAll, 800);
})();
</script>
