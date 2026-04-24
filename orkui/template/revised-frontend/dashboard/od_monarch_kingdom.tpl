<?php
/**
 * Monarch × Kingdom — full dashboard.
 * Expects: $ocData, $ocRole, $ocLevel, $ocScopeName, $kingdom_id in scope.
 */
$officers         = $ocData['officers']         ?? [];
$recs             = $ocData['recommendations']  ?? [];
$parkHealth       = $ocData['parkHealth']       ?? [];
$officersAtRisk   = $ocData['officersAtRisk']   ?? [];
$upcomingEvents   = $ocData['upcomingEvents']   ?? [];
$topRecommenders  = $ocData['topRecommenders']  ?? [];
$recentAwards     = $ocData['recentAwards']     ?? [];

$chapterTiers     = $ocData['chapterTiers']     ?? [];
$chapterHeatmap   = $ocData['chapterHeatmap']   ?? [];
$activeByPark     = $ocData['activeByPark']     ?? [];
$kingdomStats     = $ocData['kingdomStats']     ?? [];
$knights          = $ocData['knights']          ?? [];
$knightCandidates = $ocData['knightCandidates'] ?? [];
$peerageRoster    = $ocData['peerageRoster']    ?? [];
$peerageMix       = $ocData['peerageMix']       ?? [];
$awardsByMonth    = $ocData['awardsByMonth']    ?? [];
$awardsByCategory = $ocData['awardsByCategory'] ?? [];
$officerTenure    = $ocData['officerTenure']    ?? [];
$officerHistory   = $ocData['officerHistory']   ?? [];
$attendanceTrend  = $ocData['attendanceTrend']  ?? [];
$growthYoY        = $ocData['growthYoY']        ?? [];
$dowBreakdown     = $ocData['dowBreakdown']     ?? [];
$tournaments      = $ocData['tournaments']      ?? [];
$recentTournaments= $ocData['recentTournaments']?? [];
$voterEligibility = $ocData['voterEligibility'] ?? ['Active'=>0,'Eligible'=>0];
$parkCoverage     = $ocData['parkCoverage']     ?? [];
$largestParks     = $ocData['largestParks']     ?? [];
$sleepyParks      = $ocData['sleepyParks']      ?? [];
$recentCourts     = $ocData['recentCourts']     ?? [];
$upcomingCourts   = $ocData['upcomingCourts']   ?? [];
$topUnits         = $ocData['topUnits']         ?? [];
$newMembers30d    = (int)($ocData['newMembers30d'] ?? 0);
$newMembers90d    = (int)($ocData['newMembers90d'] ?? 0);
$titleHolders     = $ocData['titleHolders']     ?? [];
$suspendedMembers = $ocData['suspendedMembers'] ?? [];
$aicom            = $ocData['aicomCountdown']   ?? ['Date'=>'','DaysUntil'=>0];
$coSignQueue      = $ocData['coSignQueue']      ?? [];
$topAttendees     = $ocData['topAttendees']     ?? [];
$parkMonarchs     = $ocData['monarchsInKingdom']?? [];
$vacantParkSeats  = (int)($ocData['vacantParkSeats'] ?? 0);
$givenAwards30d   = (int)($ocData['givenAwards30d'] ?? 0);

$officerSeats = ['Monarch','Regent','Prime Minister','Champion','GMR'];
$seated = [];
foreach ($officers as $o) { $seated[$o['OfficerRole']] = $o; }
$vacancies = 0; foreach ($officerSeats as $r) { if (empty($seated[$r])) $vacancies++; }

$pctVoter = ($voterEligibility['Active'] ?? 0) > 0 ? round(100 * $voterEligibility['Eligible'] / $voterEligibility['Active']) : 0;

// Helpers for chart data strings
$h = function($s){ return htmlspecialchars((string)$s); };
$csv = function($vals){ return htmlspecialchars(implode(',', array_map('intval', $vals))); };
$pipe = function($vals){ return htmlspecialchars(implode('|', array_map(function($v){ return str_replace('|','/', (string)$v); }, $vals))); };
?>

<!-- TOP: At-a-glance stat row -->
<div class="od-grid">
	<div class="od-stat-card"><div class="od-stat-num"><?= (int)count($officers) ?>/5</div><div class="od-stat-lbl">Kingdom seats filled</div></div>
	<div class="od-stat-card"><div class="od-stat-num"><?= (int)count($recs) ?></div><div class="od-stat-lbl">Recs pending</div></div>
	<div class="od-stat-card"><div class="od-stat-num"><?= (int)count($parkHealth) ?></div><div class="od-stat-lbl">Active chapters</div></div>
	<div class="od-stat-card"><div class="od-stat-num"><?= (int)($kingdomStats['ActiveMembers'] ?? 0) ?></div><div class="od-stat-lbl">Active members (90d)</div></div>
	<div class="od-stat-card"><div class="od-stat-num"><?= (int)($kingdomStats['Knights'] ?? 0) ?></div><div class="od-stat-lbl">Knights</div></div>
	<div class="od-stat-card"><div class="od-stat-num"><?= (int)$vacantParkSeats ?></div><div class="od-stat-lbl">Park seats vacant</div></div>
</div>

<!-- ================================================================= -->
<!-- SECTION 1: Officer Roster & Activity                                -->
<!-- ================================================================= -->
<div class="od-section">
	<div class="od-section-head">
		<h3 class="od-section-title"><i class="fas fa-users-cog"></i> Officer Roster &amp; Activity</h3>
		<i class="fas fa-chevron-down od-section-caret"></i>
	</div>
	<div class="od-section-body">
		<div class="od-widget-row">
			<div class="od-widget">
				<div class="od-widget-head"><h3>Kingdom Officer Roster</h3></div>
				<div class="od-widget-body">
					<table class="od-table">
						<thead><tr><th>Office</th><th>Seated</th><th>Since</th></tr></thead>
						<tbody>
							<?php foreach ($officerSeats as $seat): $o = $seated[$seat] ?? null; ?>
								<tr class="<?= $o ? 'od-row-ok' : 'od-row-vacant' ?>">
									<td><?= $h($seat) ?></td>
									<td>
										<?php if ($o): ?>
											<a href="<?= UIR ?>Player/profile/<?= (int)($o['MundaneId'] ?? 0) ?>"><?= $h($o['Persona'] ?? '—') ?></a>
										<?php else: ?>
											<span class="od-pill od-pill-warn">VACANT</span>
										<?php endif; ?>
									</td>
									<td><?php $_m = $o['Modified'] ?? ''; echo ($o && $_m && strpos($_m, '0000-00-00') === false) ? $h(substr($_m,0,10)) : '—'; ?></td>
								</tr>
							<?php endforeach; ?>
						</tbody>
					</table>
				</div>
			</div>

			<div class="od-widget">
				<div class="od-widget-head">
					<h3>Officers at Attendance Risk</h3>
					<span class="od-subline">&lt; 4 of last 12 weeks</span>
				</div>
				<div class="od-widget-body">
					<?php if (empty($officersAtRisk)): ?>
						<div class="od-empty od-empty-ok"><i class="fas fa-check-circle"></i> All kingdom officers present.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Officer</th><th>Office</th><th>Consec.</th><th>Missed 12w</th></tr></thead>
							<tbody>
							<?php foreach ($officersAtRisk as $o): ?>
								<tr>
									<td><a href="<?= UIR ?>Player/profile/<?= (int)($o['MundaneId'] ?? 0) ?>"><?= $h($o['Persona'] ?? '—') ?></a></td>
									<td><?= $h($o['OfficerRole'] ?? '—') ?></td>
									<td><?= $h((string)($o['ConsecutiveMissed'] ?? 0)) ?></td>
									<td><?= (int)($o['TotalMissed12w'] ?? 0) ?></td>
								</tr>
							<?php endforeach; ?>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>
		</div>

		<div class="od-widget-row">
			<div class="od-widget od-widget-wide">
				<div class="od-widget-head"><h3>Officer Tenure (days in office)</h3></div>
				<div class="od-widget-body">
					<?php if (empty($officerTenure)): ?>
						<div class="od-empty">No tenure data.</div>
					<?php else: $vals = array_map(function($r){ return (int)$r['Days']; }, $officerTenure);
						$labs = array_map(function($r){ return ($r['Role'] === 'Prime Minister' ? 'PM' : $r['Role']); }, $officerTenure); ?>
						<svg class="od-chart od-chart-bar" data-orientation="horizontal"
							data-values="<?= $csv($vals) ?>"
							data-labels="<?= $pipe($labs) ?>"></svg>
					<?php endif; ?>
				</div>
			</div>
		</div>

		<div class="od-widget-row">
			<div class="od-widget">
				<div class="od-widget-head"><h3>Park Officer Coverage</h3>
					<span class="od-subline">5 seats per park</span>
				</div>
				<div class="od-widget-body">
					<?php if (empty($parkCoverage)): ?>
						<div class="od-empty">No chapter data.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="8">
							<thead><tr><th>Chapter</th><th>M</th><th>R</th><th>PM</th><th>C</th><th>G</th><th>Total</th></tr></thead>
							<tbody>
								<?php foreach ($parkCoverage as $pc): ?>
									<tr>
										<td><a href="<?= UIR ?>Park/profile/<?= (int)$pc['ParkId'] ?>"><?= $h($pc['ParkName']) ?></a></td>
										<td><?= $pc['HasMonarch']  ? '<span class="od-cov-yes">&check;</span>' : '<span class="od-cov-no">&times;</span>' ?></td>
										<td><?= $pc['HasRegent']   ? '<span class="od-cov-yes">&check;</span>' : '<span class="od-cov-no">&times;</span>' ?></td>
										<td><?= $pc['HasPm']       ? '<span class="od-cov-yes">&check;</span>' : '<span class="od-cov-no">&times;</span>' ?></td>
										<td><?= $pc['HasChampion'] ? '<span class="od-cov-yes">&check;</span>' : '<span class="od-cov-no">&times;</span>' ?></td>
										<td><?= $pc['HasGmr']      ? '<span class="od-cov-yes">&check;</span>' : '<span class="od-cov-no">&times;</span>' ?></td>
										<td><strong><?= (int)$pc['SeatCount'] ?></strong>/5</td>
									</tr>
								<?php endforeach; ?>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>

			<div class="od-widget">
				<div class="od-widget-head"><h3>Recent Officer Transitions</h3></div>
				<div class="od-widget-body">
					<?php if (empty($officerHistory)): ?>
						<div class="od-empty">No transition history logged.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="6">
							<thead><tr><th>Person</th><th>Office</th><th>Start</th><th>End</th></tr></thead>
							<tbody>
							<?php foreach ($officerHistory as $h2): ?>
								<tr>
									<td><?php if ($h2['MundaneId']): ?><a href="<?= UIR ?>Player/profile/<?= (int)$h2['MundaneId'] ?>"><?= $h($h2['Persona']) ?></a><?php else: ?>—<?php endif; ?></td>
									<td><?= $h($h2['Role']) ?><?php if ($h2['ParkId']): ?> <span class="od-subline">(<?= $h($h2['ParkName']) ?>)</span><?php endif; ?></td>
									<td><?= $h($h2['Start']) ?></td>
									<td><?= $h($h2['End'] ?: 'active') ?></td>
								</tr>
							<?php endforeach; ?>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>
		</div>
	</div>
</div>

<!-- ================================================================= -->
<!-- SECTION 2: Awards & Recognition                                     -->
<!-- ================================================================= -->
<div class="od-section">
	<div class="od-section-head">
		<h3 class="od-section-title"><i class="fas fa-trophy"></i> Awards &amp; Recognition</h3>
		<i class="fas fa-chevron-down od-section-caret"></i>
	</div>
	<div class="od-section-body">
		<div class="od-widget-row">
			<div class="od-widget">
				<div class="od-widget-head">
					<h3>Co-Sign Queue</h3>
					<a class="od-link" href="<?= UIR ?>Reports/recommendations/<?= (int)$kingdom_id ?>">All recs<i class="fas fa-arrow-right"></i></a>
				</div>
				<div class="od-widget-body">
					<?php if (empty($coSignQueue)): ?>
						<div class="od-empty">No recommendations queued.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="6">
							<thead><tr><th>Player</th><th>Award</th><th>Seconds</th><th>Logged</th></tr></thead>
							<tbody>
								<?php foreach ($coSignQueue as $c): ?>
									<tr>
										<td><a href="<?= UIR ?>Player/profile/<?= (int)$c['MundaneId'] ?>"><?= $h($c['Persona']) ?></a></td>
										<td><?= $h($c['Award']) ?></td>
										<td><span class="od-pill <?= (int)$c['Seconds'] > 0 ? 'od-pill-ok' : 'od-pill-warn' ?>"><?= (int)$c['Seconds'] ?></span></td>
										<td><?= $h(substr($c['Date'] ?? '', 0, 10)) ?></td>
									</tr>
								<?php endforeach; ?>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>

			<div class="od-widget">
				<div class="od-widget-head"><h3>Pending Recommendations</h3></div>
				<div class="od-widget-body">
					<?php if (empty($recs)): ?>
						<div class="od-empty">No pending recommendations.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="6">
							<thead><tr><th>Player</th><th>Award</th><th>By</th></tr></thead>
							<tbody>
								<?php foreach ($recs as $r): ?>
									<tr>
										<td><a href="<?= UIR ?>Player/profile/<?= (int)($r['MundaneId'] ?? 0) ?>"><?= $h($r['Persona'] ?? '—') ?></a></td>
										<td><?= $h($r['Award'] ?? '—') ?></td>
										<td><?= $h($r['RecommendedBy'] ?? '—') ?></td>
									</tr>
								<?php endforeach; ?>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>
		</div>

		<div class="od-widget-row">
			<div class="od-widget">
				<div class="od-widget-head"><h3>Awards by Category (12mo)</h3></div>
				<div class="od-widget-body">
					<?php if (empty($awardsByCategory)): ?>
						<div class="od-empty">No awards in last 12 months.</div>
					<?php else: $vals = array_map(function($r){return (int)$r['Count'];},$awardsByCategory);
						$labs = array_map(function($r){return $r['Category'];},$awardsByCategory); ?>
						<svg class="od-chart od-chart-donut"
							data-values="<?= $csv($vals) ?>"
							data-labels="<?= $pipe($labs) ?>"
							data-center-label="Awards"></svg>
					<?php endif; ?>
				</div>
			</div>

			<div class="od-widget">
				<div class="od-widget-head"><h3>Peerage Mix</h3></div>
				<div class="od-widget-body">
					<?php if (empty($peerageMix)): ?>
						<div class="od-empty">No peerage records.</div>
					<?php else: $vals = array_map(function($r){return (int)$r['Count'];},$peerageMix);
						$labs = array_map(function($r){return $r['Peerage'];},$peerageMix); ?>
						<svg class="od-chart od-chart-donut"
							data-values="<?= $csv($vals) ?>"
							data-labels="<?= $pipe($labs) ?>"
							data-center-label="Peers"></svg>
					<?php endif; ?>
				</div>
			</div>
		</div>

		<div class="od-widget-row">
			<div class="od-widget od-widget-wide">
				<div class="od-widget-head"><h3>Awards Bestowed Monthly (12mo)</h3></div>
				<div class="od-widget-body">
					<?php if (empty($awardsByMonth)): ?>
						<div class="od-empty">No award activity this year.</div>
					<?php else: $vals = array_map(function($r){return (int)$r['Count'];},$awardsByMonth);
						$labs = array_map(function($r){return substr($r['Month'], 5);},$awardsByMonth); ?>
						<svg class="od-chart od-chart-bar"
							data-values="<?= $csv($vals) ?>"
							data-labels="<?= $pipe($labs) ?>"></svg>
					<?php endif; ?>
				</div>
			</div>
		</div>

		<div class="od-widget-row">
			<div class="od-widget">
				<div class="od-widget-head"><h3>Knighting Candidates</h3>
					<span class="od-subline">Squires · Pages · Men-At-Arms</span>
				</div>
				<div class="od-widget-body">
					<?php if (empty($knightCandidates)): ?>
						<div class="od-empty">No squires pending.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="6">
							<thead><tr><th>Player</th><th>Belt</th><th>Since</th></tr></thead>
							<tbody>
								<?php foreach ($knightCandidates as $k): ?>
									<tr>
										<td><a href="<?= UIR ?>Player/profile/<?= (int)$k['MundaneId'] ?>"><?= $h($k['Persona']) ?></a></td>
										<td><?= $h($k['Peerage']) ?></td>
										<td><?= $h($k['Since']) ?></td>
									</tr>
								<?php endforeach; ?>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>

			<div class="od-widget">
				<div class="od-widget-head"><h3>Knights of the Kingdom</h3></div>
				<div class="od-widget-body">
					<?php if (empty($knights)): ?>
						<div class="od-empty">No knights recorded.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="6">
							<thead><tr><th>Knight</th><th>Order</th><th>Knighted</th></tr></thead>
							<tbody>
								<?php foreach ($knights as $k): ?>
									<tr>
										<td><a href="<?= UIR ?>Player/profile/<?= (int)$k['MundaneId'] ?>"><?= $h($k['Persona']) ?></a></td>
										<td><?= $h($k['Order']) ?></td>
										<td><?= $h($k['Knighted']) ?></td>
									</tr>
								<?php endforeach; ?>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>
		</div>

		<div class="od-widget-row">
			<div class="od-widget">
				<div class="od-widget-head"><h3>Peerage Roster</h3>
					<span class="od-subline">Knights · Masters · Paragon</span>
				</div>
				<div class="od-widget-body">
					<?php if (empty($peerageRoster)): ?>
						<div class="od-empty">No peerage records.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="6">
							<thead><tr><th>Peer</th><th>Peerage</th><th>Since</th></tr></thead>
							<tbody>
								<?php foreach ($peerageRoster as $p): ?>
									<tr>
										<td><a href="<?= UIR ?>Player/profile/<?= (int)$p['MundaneId'] ?>"><?= $h($p['Persona']) ?></a></td>
										<td><?= $h($p['Peerage']) ?></td>
										<td><?= $h($p['Since']) ?></td>
									</tr>
								<?php endforeach; ?>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>

			<div class="od-widget">
				<div class="od-widget-head"><h3>Top Recommenders (6mo)</h3></div>
				<div class="od-widget-body">
					<?php if (empty($topRecommenders)): ?>
						<div class="od-empty">No recommendations logged.</div>
					<?php else: $vals = array_map(function($r){return (int)$r['RecCount'];},$topRecommenders);
						$labs = array_map(function($r){return $r['Persona'];},$topRecommenders); ?>
						<svg class="od-chart od-chart-bar" data-orientation="horizontal"
							data-values="<?= $csv($vals) ?>"
							data-labels="<?= $pipe($labs) ?>"></svg>
					<?php endif; ?>
				</div>
			</div>
		</div>

		<div class="od-widget-row">
			<div class="od-widget od-widget-wide">
				<div class="od-widget-head">
					<h3>Recent Awards Feed</h3>
					<span class="od-subline"><?= $givenAwards30d ?> awards in last 30 days</span>
				</div>
				<div class="od-widget-body">
					<?php if (empty($recentAwards)): ?>
						<div class="od-empty">No recent awards.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="8">
							<thead><tr><th>Player</th><th>Award</th><th>Park</th><th>Date</th></tr></thead>
							<tbody>
								<?php foreach ($recentAwards as $a): ?>
									<tr>
										<td><a href="<?= UIR ?>Player/profile/<?= (int)($a['MundaneId'] ?? 0) ?>"><?= $h($a['Persona'] ?? '—') ?></a></td>
										<td><?= $h($a['Award'] ?? '—') ?></td>
										<td><a href="<?= UIR ?>Park/profile/<?= (int)($a['ParkId'] ?? 0) ?>"><?= $h($a['ParkName'] ?? '—') ?></a></td>
										<td><?= $h(substr($a['AwardDate'] ?? '',0,10)) ?></td>
									</tr>
								<?php endforeach; ?>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>
		</div>

		<div class="od-widget-row">
			<div class="od-widget">
				<div class="od-widget-head"><h3>Kingdom Title Holders</h3></div>
				<div class="od-widget-body">
					<?php if (empty($titleHolders)): ?>
						<div class="od-empty">No kingdom titles bestowed.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="6">
							<thead><tr><th>Player</th><th>Title</th><th>Since</th></tr></thead>
							<tbody>
								<?php foreach ($titleHolders as $t): ?>
									<tr>
										<td><a href="<?= UIR ?>Player/profile/<?= (int)$t['MundaneId'] ?>"><?= $h($t['Persona']) ?></a></td>
										<td><?= $h($t['Title']) ?></td>
										<td><?= $h(substr($t['Date'] ?? '', 0, 10)) ?></td>
									</tr>
								<?php endforeach; ?>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>

			<div class="od-widget">
				<div class="od-widget-head"><h3>Recent &amp; Upcoming Courts</h3></div>
				<div class="od-widget-body">
					<?php if (empty($recentCourts) && empty($upcomingCourts)): ?>
						<div class="od-empty">No court records yet.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="6">
							<thead><tr><th>Court</th><th>Park</th><th>Date</th><th>Status</th></tr></thead>
							<tbody>
								<?php foreach ($upcomingCourts as $c): ?>
									<tr><td><?= $h($c['Name']) ?></td><td><?= $h($c['ParkName'] ?? '—') ?></td><td><?= $h($c['Date']) ?></td><td><span class="od-pill od-pill-ok"><?= $h($c['Status']) ?></span></td></tr>
								<?php endforeach; ?>
								<?php foreach ($recentCourts as $c): ?>
									<tr><td><?= $h($c['Name']) ?></td><td><?= $h($c['ParkName'] ?? '—') ?></td><td><?= $h($c['Date']) ?></td><td><span class="od-pill"><?= $h($c['Status']) ?></span></td></tr>
								<?php endforeach; ?>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>
		</div>
	</div>
</div>

<!-- ================================================================= -->
<!-- SECTION 3: Chapters & Parks                                         -->
<!-- ================================================================= -->
<div class="od-section">
	<div class="od-section-head">
		<h3 class="od-section-title"><i class="fas fa-map-marked-alt"></i> Chapters &amp; Parks</h3>
		<i class="fas fa-chevron-down od-section-caret"></i>
	</div>
	<div class="od-section-body">
		<div class="od-widget-row">
			<div class="od-widget od-widget-wide">
				<div class="od-widget-head"><h3>Chapter Health Snapshot</h3>
					<a class="od-link" href="<?= UIR ?>Reports/attendance/<?= (int)$kingdom_id ?>">Full attendance<i class="fas fa-arrow-right"></i></a>
				</div>
				<div class="od-widget-body">
					<?php if (empty($parkHealth)): ?>
						<div class="od-empty">Chapter data unavailable.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="8">
							<thead><tr><th>Chapter</th><th>Tier</th><th>Monthly avg</th><th>Active (90d)</th><th>Last attended</th></tr></thead>
							<tbody>
								<?php foreach ($parkHealth as $p): ?>
									<tr>
										<td><a href="<?= UIR ?>Park/profile/<?= (int)($p['ParkId'] ?? 0) ?>"><?= $h($p['ParkName'] ?? '—') ?></a></td>
										<td><?= $h($p['ParkType'] ?? '—') ?></td>
										<td><?= number_format((float)($p['MonthlyAvg'] ?? 0), 1) ?></td>
										<td><?= (int)($p['ActiveMembers'] ?? 0) ?></td>
										<td><?= $h($p['LastAttendance'] ?? '—') ?></td>
									</tr>
								<?php endforeach; ?>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>
		</div>

		<div class="od-widget-row">
			<div class="od-widget">
				<div class="od-widget-head"><h3>Chapter Tier Distribution</h3></div>
				<div class="od-widget-body">
					<?php if (empty($chapterTiers)): ?>
						<div class="od-empty">No tier data.</div>
					<?php else: $vals = array_map(function($r){return (int)$r['Count'];},$chapterTiers);
						$labs = array_map(function($r){return $r['Title'];},$chapterTiers); ?>
						<svg class="od-chart od-chart-donut"
							data-values="<?= $csv($vals) ?>"
							data-labels="<?= $pipe($labs) ?>"
							data-center-label="Chapters"></svg>
					<?php endif; ?>
				</div>
			</div>

			<div class="od-widget">
				<div class="od-widget-head"><h3>Largest Active Parks (90d)</h3></div>
				<div class="od-widget-body">
					<?php if (empty($largestParks)): ?>
						<div class="od-empty">No attendance data.</div>
					<?php else: $vals = array_map(function($r){return (int)$r['Unique'];},$largestParks);
						$labs = array_map(function($r){return $r['Name'];},$largestParks); ?>
						<svg class="od-chart od-chart-bar" data-orientation="horizontal"
							data-values="<?= $csv($vals) ?>"
							data-labels="<?= $pipe($labs) ?>"></svg>
					<?php endif; ?>
				</div>
			</div>
		</div>

		<div class="od-widget-row">
			<div class="od-widget od-widget-wide">
				<div class="od-widget-head"><h3>Chapter Attendance Heatmap</h3>
					<span class="od-subline">Top 8 chapters · last 8 weeks · unique players</span>
				</div>
				<div class="od-widget-body">
					<?php if (empty($chapterHeatmap['Matrix'])): ?>
						<div class="od-empty">Not enough data for heatmap.</div>
					<?php else:
						$matStr = implode(';', array_map(function($row){return implode(',', $row);}, $chapterHeatmap['Matrix']));
						$colsStr = implode('|', $chapterHeatmap['Cols']);
						$rowsStr = implode('|', $chapterHeatmap['Rows']); ?>
						<svg class="od-chart od-chart-heatmap"
							data-matrix="<?= $h($matStr) ?>"
							data-cols="<?= $h($colsStr) ?>"
							data-rows="<?= $h($rowsStr) ?>"></svg>
					<?php endif; ?>
				</div>
			</div>
		</div>

		<div class="od-widget-row">
			<div class="od-widget">
				<div class="od-widget-head"><h3>Park Monarchs (Sheriffs/Barons/Princes)</h3></div>
				<div class="od-widget-body">
					<?php if (empty($parkMonarchs)): ?>
						<div class="od-empty">No active chapters.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="8">
							<thead><tr><th>Chapter</th><th>Tier</th><th>Seated</th></tr></thead>
							<tbody>
								<?php foreach ($parkMonarchs as $pm): ?>
									<tr class="<?= $pm['MundaneId'] ? '' : 'od-row-vacant' ?>">
										<td><a href="<?= UIR ?>Park/profile/<?= (int)$pm['ParkId'] ?>"><?= $h($pm['ParkName']) ?></a></td>
										<td><?= $h($pm['ParkTitle']) ?></td>
										<td>
											<?php if ($pm['MundaneId']): ?>
												<a href="<?= UIR ?>Player/profile/<?= (int)$pm['MundaneId'] ?>"><?= $h($pm['Persona']) ?></a>
											<?php else: ?>
												<span class="od-pill od-pill-warn">VACANT</span>
											<?php endif; ?>
										</td>
									</tr>
								<?php endforeach; ?>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>

			<div class="od-widget">
				<div class="od-widget-head"><h3>Sleepy Parks</h3>
					<span class="od-subline">No attendance &gt; 30d</span>
				</div>
				<div class="od-widget-body">
					<?php if (empty($sleepyParks)): ?>
						<div class="od-empty od-empty-ok"><i class="fas fa-check-circle"></i> Every active park has recent attendance.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="6">
							<thead><tr><th>Chapter</th><th>Last attended</th></tr></thead>
							<tbody>
								<?php foreach ($sleepyParks as $s): ?>
									<tr>
										<td><a href="<?= UIR ?>Park/profile/<?= (int)$s['ParkId'] ?>"><?= $h($s['Name']) ?></a></td>
										<td><?= $h($s['LastAttendance']) ?></td>
									</tr>
								<?php endforeach; ?>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>
		</div>

		<div class="od-widget-row">
			<div class="od-widget">
				<div class="od-widget-head"><h3>Top Companies &amp; Households</h3></div>
				<div class="od-widget-body">
					<?php if (empty($topUnits)): ?>
						<div class="od-empty">No units tracked.</div>
					<?php else: $vals = array_map(function($r){return (int)$r['Members'];},$topUnits);
						$labs = array_map(function($r){return $r['Name'];},$topUnits); ?>
						<svg class="od-chart od-chart-bar" data-orientation="horizontal"
							data-values="<?= $csv($vals) ?>"
							data-labels="<?= $pipe($labs) ?>"></svg>
					<?php endif; ?>
				</div>
			</div>

			<div class="od-widget">
				<div class="od-widget-head"><h3>Active Members by Park</h3></div>
				<div class="od-widget-body">
					<?php if (empty($activeByPark)): ?>
						<div class="od-empty">No data.</div>
					<?php else: $vals = array_map(function($r){return (int)$r['ActiveCount'];},$activeByPark);
						$labs = array_map(function($r){return $r['Name'];},$activeByPark); ?>
						<svg class="od-chart od-chart-bar" data-orientation="horizontal"
							data-values="<?= $csv($vals) ?>"
							data-labels="<?= $pipe($labs) ?>"></svg>
					<?php endif; ?>
				</div>
			</div>
		</div>
	</div>
</div>

<!-- ================================================================= -->
<!-- SECTION 4: Events, Tournaments & Ceremonies                         -->
<!-- ================================================================= -->
<div class="od-section">
	<div class="od-section-head">
		<h3 class="od-section-title"><i class="fas fa-flag"></i> Events, Tournaments &amp; Ceremonies</h3>
		<i class="fas fa-chevron-down od-section-caret"></i>
	</div>
	<div class="od-section-body">
		<div class="od-widget-row">
			<div class="od-widget">
				<div class="od-widget-head"><h3>Upcoming Kingdom Events</h3></div>
				<div class="od-widget-body">
					<?php if (empty($upcomingEvents)): ?>
						<div class="od-empty">No scheduled events.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="6">
							<thead><tr><th>Event</th><th>Chapter</th><th>Date</th></tr></thead>
							<tbody>
								<?php foreach ($upcomingEvents as $e): ?>
									<tr>
										<td><?= $h($e['Name'] ?? '—') ?></td>
										<td><a href="<?= UIR ?>Park/profile/<?= (int)($e['ParkId'] ?? 0) ?>"><?= $h($e['ParkName'] ?? '—') ?></a></td>
										<td><?= $h(substr($e['StartDate'] ?? '', 0, 10)) ?></td>
									</tr>
								<?php endforeach; ?>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>

			<div class="od-widget">
				<div class="od-widget-head"><h3>Upcoming Tournaments</h3></div>
				<div class="od-widget-body">
					<?php if (empty($tournaments)): ?>
						<div class="od-empty">No upcoming tournaments.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="6">
							<thead><tr><th>Tournament</th><th>Chapter</th><th>Date</th></tr></thead>
							<tbody>
								<?php foreach ($tournaments as $t): ?>
									<tr>
										<td><?= $h($t['Name']) ?></td>
										<td><?= $h($t['ParkName'] ?? '—') ?></td>
										<td><?= $h(substr($t['Date'] ?? '', 0, 10)) ?></td>
									</tr>
								<?php endforeach; ?>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>
		</div>

		<div class="od-widget-row">
			<div class="od-widget">
				<div class="od-widget-head"><h3>Recent Tournament Results</h3></div>
				<div class="od-widget-body">
					<?php if (empty($recentTournaments)): ?>
						<div class="od-empty">No recent tournaments.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="6">
							<thead><tr><th>Tournament</th><th>Chapter</th><th>Status</th><th>Date</th></tr></thead>
							<tbody>
								<?php foreach ($recentTournaments as $t): ?>
									<tr>
										<td><?= $h($t['Name']) ?></td>
										<td><?= $h($t['ParkName'] ?? '—') ?></td>
										<td><span class="od-pill <?= $t['Status'] === 'complete' ? 'od-pill-ok' : 'od-pill-warn' ?>"><?= $h($t['Status']) ?></span></td>
										<td><?= $h(substr($t['Date'] ?? '', 0, 10)) ?></td>
									</tr>
								<?php endforeach; ?>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>

			<div class="od-widget">
				<div class="od-widget-head"><h3>AICOM Countdown</h3>
					<span class="od-subline">All-Interkingdom Conference of Monarchs</span>
				</div>
				<div class="od-widget-body">
					<div style="display:flex;flex-direction:column;align-items:center;justify-content:center;padding:22px 12px;gap:6px;">
						<div style="font-size:48px;font-weight:700;color:#5d3fb8;line-height:1;"><?= (int)$aicom['DaysUntil'] ?></div>
						<div style="font-size:11px;text-transform:uppercase;letter-spacing:.1em;color:#888;">days until AICOM</div>
						<div style="font-size:12px;color:#666;margin-top:4px;"><?= $h($aicom['Date']) ?></div>
					</div>
				</div>
			</div>
		</div>

		<div class="od-widget-row">
			<div class="od-widget od-widget-wide od-widget-soon">
				<div class="od-widget-head"><h3>Crown Cycle State Machine</h3></div>
				<div class="od-widget-body">
					<div style="display:flex;align-items:center;justify-content:space-around;padding:14px 6px;flex-wrap:wrap;gap:12px;">
						<?php $states = ['Declarations','Ballot','Vote','Quals','Coronation']; foreach ($states as $i => $s): ?>
							<div style="display:flex;flex-direction:column;align-items:center;gap:4px;">
								<div style="width:34px;height:34px;border-radius:50%;background:<?= $i === 0 ? '#5d3fb8' : '#eee' ?>;color:<?= $i === 0 ? '#fff' : '#999' ?>;display:flex;align-items:center;justify-content:center;font-weight:700;"><?= $i + 1 ?></div>
								<div style="font-size:11px;color:#666;"><?= $h($s) ?></div>
							</div>
							<?php if ($i < count($states) - 1): ?><div style="flex:1;height:2px;background:#eee;min-width:20px;"></div><?php endif; ?>
						<?php endforeach; ?>
					</div>
					<p class="od-soon-note" style="margin-top:12px;">Current phase tracking &amp; qualification progress integration coming soon.</p>
				</div>
			</div>
		</div>
	</div>
</div>

<!-- ================================================================= -->
<!-- SECTION 5: Insights & Trends                                        -->
<!-- ================================================================= -->
<div class="od-section">
	<div class="od-section-head">
		<h3 class="od-section-title"><i class="fas fa-chart-line"></i> Insights &amp; Trends</h3>
		<i class="fas fa-chevron-down od-section-caret"></i>
	</div>
	<div class="od-section-body">
		<div class="od-widget-row">
			<div class="od-widget">
				<div class="od-widget-head"><h3>Voter Eligibility</h3></div>
				<div class="od-widget-body">
					<svg class="od-chart od-chart-ring"
						data-value="<?= (int)($voterEligibility['Eligible'] ?? 0) ?>"
						data-max="<?= (int)max(1, $voterEligibility['Active'] ?? 1) ?>"
						data-display="<?= $pctVoter ?>%"
						data-label="of active eligible"></svg>
					<div style="text-align:center;font-size:12px;color:#666;margin-top:6px;">
						<?= (int)$voterEligibility['Eligible'] ?> of <?= (int)$voterEligibility['Active'] ?> active members
					</div>
				</div>
			</div>

			<div class="od-widget">
				<div class="od-widget-head"><h3>Attendance Trend (12 weeks)</h3></div>
				<div class="od-widget-body">
					<?php if (empty($attendanceTrend)): ?>
						<div class="od-empty">No data.</div>
					<?php else: $vals = array_map(function($w){return (int)$w['UniquePlayers'];},$attendanceTrend); ?>
						<svg class="od-spark" viewBox="0 0 240 48" preserveAspectRatio="none" data-values="<?= $csv($vals) ?>"></svg>
						<div style="display:flex;justify-content:space-between;font-size:11px;color:#888;margin-top:4px;">
							<span><?= $h($attendanceTrend[0]['WeekStart'] ?? '') ?></span>
							<span>Peak: <?= max($vals) ?></span>
							<span><?= $h(end($attendanceTrend)['WeekStart'] ?? '') ?></span>
						</div>
					<?php endif; ?>
				</div>
			</div>

			<div class="od-widget">
				<div class="od-widget-head"><h3>Growth Year-over-Year</h3></div>
				<div class="od-widget-body">
					<?php if (empty($growthYoY)): ?>
						<div class="od-empty">No data.</div>
					<?php else: $vals = array_map(function($r){return (int)$r['Unique'];},$growthYoY);
						$labs = array_map(function($r){return (string)$r['Year'];},$growthYoY); ?>
						<svg class="od-chart od-chart-bar"
							data-values="<?= $csv($vals) ?>"
							data-labels="<?= $pipe($labs) ?>"></svg>
					<?php endif; ?>
				</div>
			</div>
		</div>

		<div class="od-widget-row">
			<div class="od-widget od-widget-wide">
				<div class="od-widget-head"><h3>Attendance by Day of Week (180d)</h3></div>
				<div class="od-widget-body">
					<?php if (empty($dowBreakdown)): ?>
						<div class="od-empty">No attendance logged.</div>
					<?php else: $vals = array_map(function($r){return (int)$r['Count'];},$dowBreakdown);
						$labs = array_map(function($r){return $r['Day'];},$dowBreakdown); ?>
						<svg class="od-chart od-chart-bar"
							data-values="<?= $csv($vals) ?>"
							data-labels="<?= $pipe($labs) ?>"></svg>
					<?php endif; ?>
				</div>
			</div>
		</div>

		<div class="od-widget-row">
			<div class="od-widget">
				<div class="od-widget-head"><h3>Top Attendees (90d)</h3></div>
				<div class="od-widget-body">
					<?php if (empty($topAttendees)): ?>
						<div class="od-empty">No attendance this period.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="8">
							<thead><tr><th>Player</th><th>Credits</th></tr></thead>
							<tbody>
								<?php foreach ($topAttendees as $p): ?>
									<tr><td><a href="<?= UIR ?>Player/profile/<?= (int)($p['MundaneId'] ?? 0) ?>"><?= $h($p['Persona'] ?? '—') ?></a></td>
										<td><?= (int)($p['AttendCount'] ?? 0) ?></td>
									</tr>
								<?php endforeach; ?>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>

			<div class="od-widget">
				<div class="od-widget-head"><h3>New Members</h3></div>
				<div class="od-widget-body">
					<div style="display:flex;justify-content:space-around;align-items:center;padding:14px 6px;">
						<div style="text-align:center;">
							<div style="font-size:34px;font-weight:700;color:#5d3fb8;"><?= (int)$newMembers30d ?></div>
							<div style="font-size:10px;text-transform:uppercase;color:#888;letter-spacing:.08em;">Last 30 days</div>
						</div>
						<div style="text-align:center;">
							<div style="font-size:34px;font-weight:700;color:#8b6cff;"><?= (int)$newMembers90d ?></div>
							<div style="font-size:10px;text-transform:uppercase;color:#888;letter-spacing:.08em;">Last 90 days</div>
						</div>
					</div>
				</div>
			</div>

			<div class="od-widget">
				<div class="od-widget-head"><h3>Suspended Members</h3></div>
				<div class="od-widget-body">
					<?php if (empty($suspendedMembers)): ?>
						<div class="od-empty od-empty-ok"><i class="fas fa-check-circle"></i> No active suspensions.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Player</th><th>Until</th></tr></thead>
							<tbody>
								<?php foreach ($suspendedMembers as $s): ?>
									<tr>
										<td><a href="<?= UIR ?>Player/profile/<?= (int)$s['MundaneId'] ?>"><?= $h($s['Persona']) ?></a></td>
										<td><?= $h($s['Until']) ?></td>
									</tr>
								<?php endforeach; ?>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>
		</div>
	</div>
</div>

<!-- ================================================================= -->
<!-- SECTION 6: Quick Actions                                            -->
<!-- ================================================================= -->
<div class="od-section">
	<div class="od-section-head">
		<h3 class="od-section-title"><i class="fas fa-bolt"></i> Quick Actions</h3>
		<i class="fas fa-chevron-down od-section-caret"></i>
	</div>
	<div class="od-section-body">
		<div class="od-widget-row">
			<div class="od-widget od-widget-wide">
				<div class="od-widget-body">
					<div class="od-links-grid">
						<a class="od-link-card" href="<?= UIR ?>Reports/recommendations/<?= (int)$kingdom_id ?>"><i class="fas fa-scroll"></i><span>Co-Sign Queue</span></a>
						<a class="od-link-card" href="<?= UIR ?>Kingdom/profile/<?= (int)$kingdom_id ?>/officers"><i class="fas fa-users-cog"></i><span>Manage Officers</span></a>
						<a class="od-link-card" href="<?= UIR ?>Reports/attendance/<?= (int)$kingdom_id ?>"><i class="fas fa-clipboard-list"></i><span>Attendance Report</span></a>
						<a class="od-link-card" href="<?= UIR ?>Kingdom/profile/<?= (int)$kingdom_id ?>/awards"><i class="fas fa-medal"></i><span>Bestow Award</span></a>
						<a class="od-link-card" href="<?= UIR ?>Event/create"><i class="fas fa-calendar-plus"></i><span>Schedule Event</span></a>
						<a class="od-link-card" href="<?= UIR ?>Court/create/<?= (int)$kingdom_id ?>"><i class="fas fa-gavel"></i><span>Call Court of Honor</span></a>
						<a class="od-link-card" href="<?= UIR ?>Reports/voting/<?= (int)$kingdom_id ?>"><i class="fas fa-vote-yea"></i><span>Export Voter Roll</span></a>
						<a class="od-link-card" href="<?= UIR ?>Kingdom/profile/<?= (int)$kingdom_id ?>"><i class="fas fa-crown"></i><span>Kingdom Profile</span></a>
					</div>
				</div>
			</div>
		</div>
	</div>
</div>

<!-- ================================================================= -->
<!-- SECTION 7: Tools & References (closed by default)                   -->
<!-- ================================================================= -->
<div class="od-section od-section-closed">
	<div class="od-section-head">
		<h3 class="od-section-title"><i class="fas fa-tools"></i> Tools &amp; References</h3>
		<i class="fas fa-chevron-down od-section-caret"></i>
	</div>
	<div class="od-section-body">
		<div class="od-widget-row">
			<div class="od-widget od-widget-wide">
				<div class="od-widget-body">
					<div class="od-links-grid">
						<a class="od-link-card" href="https://amtgard.com/corpora/" target="_blank" rel="noopener"><i class="fas fa-book"></i><span>Corpora</span></a>
						<a class="od-link-card" href="<?= UIR ?>Award/list/<?= (int)$kingdom_id ?>"><i class="fas fa-list"></i><span>Award Criteria</span></a>
						<a class="od-link-card" href="<?= UIR ?>Kingdom/officers/<?= (int)$kingdom_id ?>/export"><i class="fas fa-file-export"></i><span>Roster Export</span></a>
						<a class="od-link-card" href="<?= UIR ?>Admin/kingdom/<?= (int)$kingdom_id ?>"><i class="fas fa-cog"></i><span>Kingdom Admin</span></a>
						<a class="od-link-card" href="<?= UIR ?>Reports/growth/<?= (int)$kingdom_id ?>"><i class="fas fa-chart-area"></i><span>Growth Report</span></a>
						<a class="od-link-card" href="<?= UIR ?>Reports/peerage/<?= (int)$kingdom_id ?>"><i class="fas fa-crown"></i><span>Peerage Report</span></a>
					</div>
				</div>
			</div>
		</div>
	</div>
</div>
