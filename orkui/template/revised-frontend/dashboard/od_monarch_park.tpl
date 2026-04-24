<?php
/**
 * Monarch × Park (Sheriff/Baron/Duke/Prince) — full dashboard.
 * Expects: $ocData, $ocRole, $ocLevel, $ocScopeName, $park_id in scope.
 */
$officers         = $ocData['officers']         ?? [];
$recentAtt        = $ocData['recentAtt']        ?? [];
$recentAwards     = $ocData['recentAwards']     ?? [];
$upcomingEvents   = $ocData['upcomingEvents']   ?? [];
$topAttendees     = $ocData['topAttendees']     ?? [];
$attendanceTrend  = $ocData['attendanceTrend']  ?? [];

$parkInfo         = $ocData['parkInfo']         ?? [];
$parkStats        = $ocData['parkStats']        ?? [];
$peerageFromPark  = $ocData['peerageFromPark']  ?? [];
$knightCandidates = $ocData['knightCandidates'] ?? [];
$pendingRecs      = $ocData['pendingRecs']      ?? [];
$awardsByMonth    = $ocData['awardsByMonth']    ?? [];
$attendanceDow    = $ocData['attendanceDow']    ?? [];
$attendanceHeatmap= $ocData['attendanceHeatmap']?? [];
$voterEligibility = $ocData['voterEligibility'] ?? ['Active'=>0,'Eligible'=>0];
$awardDensity     = $ocData['awardDensity']     ?? ['AwardCount'=>0,'ActiveMembers'=>0,'PerMember'=>0];
$kingdomAvgDensity= (float)($ocData['kingdomAvgDensity'] ?? 0);
$parkDays         = $ocData['parkDays']         ?? [];
$recentTournaments= $ocData['recentTournaments']?? [];
$topRecommenders  = $ocData['topRecommenders']  ?? [];
$newcomers        = $ocData['newcomers']        ?? [];
$officersAtRisk   = $ocData['officersAtRisk']   ?? [];
$unsungMembers    = $ocData['unsungMembers']    ?? [];
$titleHoldersPark = $ocData['titleHoldersPark'] ?? [];
$recentCourts     = $ocData['recentCourts']     ?? [];

// Tier labels for tier-gated guidance
$parkTier   = (int)($parkInfo['ParkTier'] ?? 1);
$parkTitle  = $parkInfo['ParkTitle'] ?? 'Chapter';

$pctVoter = ($voterEligibility['Active'] ?? 0) > 0 ? round(100 * $voterEligibility['Eligible'] / $voterEligibility['Active']) : 0;
$densityVsAvg = $kingdomAvgDensity > 0 ? round(100 * ($awardDensity['PerMember'] ?? 0) / $kingdomAvgDensity) : 0;

$h = function($s){ return htmlspecialchars((string)$s); };
$csv = function($vals){ return htmlspecialchars(implode(',', array_map(function($v){return is_numeric($v)?$v:0;}, $vals))); };
$pipe = function($vals){ return htmlspecialchars(implode('|', array_map(function($v){ return str_replace('|','/', (string)$v); }, $vals))); };

// Map award tiers to park tiers (rough Amtgard cannon).
// Tier 1=Shire (Sheriff), 2=Barony (Baron), 3=Duchy (Duke), 4=Principality (Prince).
$tierAwardNames = [
	1 => ['Awards of Merit (Order I / lowest tier)', 'Park-recognitions only'],
	2 => ['Awards of Merit (Order I-II)', 'Most ladder awards'],
	3 => ['Awards of Merit (Order I-III)', 'Can grant most titles'],
	4 => ['Awards of Merit (Order I-IV)', 'All but kingdom-reserved peerage'],
];
$tierExplanation = $tierAwardNames[$parkTier] ?? ['Park-level awards only', 'Contact Kingdom Monarch for higher-tier recognitions'];
?>

<!-- TOP: At-a-glance stat row -->
<div class="od-grid">
	<div class="od-stat-card"><div class="od-stat-num"><?= (int)count($officers) ?>/5</div><div class="od-stat-lbl">Park officers seated</div></div>
	<div class="od-stat-card"><div class="od-stat-num"><?= (int)count($recentAtt) ?></div><div class="od-stat-lbl">Unique attendees (90d)</div></div>
	<div class="od-stat-card"><div class="od-stat-num"><?= (int)count($recentAwards) ?></div><div class="od-stat-lbl">Awards given (90d)</div></div>
	<div class="od-stat-card"><div class="od-stat-num"><?= (int)count($upcomingEvents) ?></div><div class="od-stat-lbl">Upcoming events</div></div>
	<div class="od-stat-card"><div class="od-stat-num"><?= (int)($parkStats['KnightsHere'] ?? 0) ?></div><div class="od-stat-lbl">Knights at park</div></div>
	<div class="od-stat-card"><div class="od-stat-num"><?= (int)($voterEligibility['Eligible'] ?? 0) ?></div><div class="od-stat-lbl">Voter-eligible</div></div>
</div>

<!-- ================================================================= -->
<!-- SECTION 1: Roster & Officers                                        -->
<!-- ================================================================= -->
<div class="od-section">
	<div class="od-section-head">
		<h3 class="od-section-title"><i class="fas fa-user-tie"></i> Roster &amp; Officers</h3>
		<i class="fas fa-chevron-down od-section-caret"></i>
	</div>
	<div class="od-section-body">
		<div class="od-widget-row">
			<div class="od-widget">
				<div class="od-widget-head"><h3>Park Officer Roster</h3></div>
				<div class="od-widget-body">
					<?php if (empty($officers)): ?>
						<div class="od-empty">No park officers listed.</div>
					<?php else:
						$parkSeats = ['Monarch','Regent','Prime Minister','Champion','GMR'];
						$seated = [];
						foreach ($officers as $o) { $seated[$o['OfficerRole']] = $o; } ?>
						<table class="od-table">
							<thead><tr><th>Office</th><th>Seated</th><th>Since</th></tr></thead>
							<tbody>
								<?php foreach ($parkSeats as $seat): $o = $seated[$seat] ?? null; ?>
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
					<?php endif; ?>
				</div>
			</div>

			<div class="od-widget">
				<div class="od-widget-head"><h3>Officers at Risk</h3>
					<span class="od-subline">&lt; 4 attendances in 12 weeks</span>
				</div>
				<div class="od-widget-body">
					<?php if (empty($officersAtRisk)): ?>
						<div class="od-empty od-empty-ok"><i class="fas fa-check-circle"></i> Every officer present.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Officer</th><th>Office</th><th>Missed 12w</th></tr></thead>
							<tbody>
							<?php foreach ($officersAtRisk as $o): ?>
								<tr>
									<td><a href="<?= UIR ?>Player/profile/<?= (int)($o['MundaneId'] ?? 0) ?>"><?= $h($o['Persona']) ?></a></td>
									<td><?= $h($o['OfficerRole']) ?></td>
									<td><?= (int)$o['TotalMissed12w'] ?></td>
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
				<div class="od-widget-head"><h3>Peerage from this Park</h3></div>
				<div class="od-widget-body">
					<?php if (empty($peerageFromPark)): ?>
						<div class="od-empty">No peers here yet.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="6">
							<thead><tr><th>Peer</th><th>Peerage</th><th>Since</th></tr></thead>
							<tbody>
								<?php foreach ($peerageFromPark as $p): ?>
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
				<div class="od-widget-head"><h3>Park Title Holders</h3></div>
				<div class="od-widget-body">
					<?php if (empty($titleHoldersPark)): ?>
						<div class="od-empty">No titled members.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Player</th><th>Title</th><th>Date</th></tr></thead>
							<tbody>
								<?php foreach ($titleHoldersPark as $t): ?>
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
		</div>
	</div>
</div>

<!-- ================================================================= -->
<!-- SECTION 2: Awards Powers                                            -->
<!-- ================================================================= -->
<div class="od-section">
	<div class="od-section-head">
		<h3 class="od-section-title"><i class="fas fa-medal"></i> Awards Powers</h3>
		<i class="fas fa-chevron-down od-section-caret"></i>
	</div>
	<div class="od-section-body">
		<div class="od-widget-row">
			<div class="od-widget od-widget-wide">
				<div class="od-widget-head">
					<h3>Tier-Gated Award Authority</h3>
					<span class="od-subline"><?= $h($parkTitle) ?> · Tier <?= $parkTier ?></span>
				</div>
				<div class="od-widget-body">
					<p style="margin:0 0 10px 0;font-size:13px;color:#555;">
						As the seated <?= $h($ocRole) ?> of a <strong><?= $h($parkTitle) ?></strong> (tier <?= $parkTier ?>),
						your award-bestowal authority is shaped by park tier. Higher-tier parks can directly bestow more of the kingdom's orders;
						lower-tier chapters route requests through the kingdom monarch.
					</p>
					<ul style="margin:0 0 10px 16px;font-size:13px;color:#333;">
						<?php foreach ($tierExplanation as $line): ?>
							<li><?= $h($line) ?></li>
						<?php endforeach; ?>
					</ul>
					<p class="od-subline" style="font-style:italic;">Award picker UI in the Bestow Award workflow will filter to eligible awards.</p>
				</div>
			</div>
		</div>

		<div class="od-widget-row">
			<div class="od-widget">
				<div class="od-widget-head"><h3>Pending Recommendations</h3></div>
				<div class="od-widget-body">
					<?php if (empty($pendingRecs)): ?>
						<div class="od-empty">No open recommendations.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="6">
							<thead><tr><th>Player</th><th>Award</th><th>By</th></tr></thead>
							<tbody>
								<?php foreach ($pendingRecs as $r): ?>
									<tr>
										<td><a href="<?= UIR ?>Player/profile/<?= (int)$r['MundaneId'] ?>"><?= $h($r['Persona']) ?></a></td>
										<td><?= $h($r['Award']) ?></td>
										<td><?= $h($r['By']) ?></td>
									</tr>
								<?php endforeach; ?>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>

			<div class="od-widget">
				<div class="od-widget-head"><h3>Knighting Candidates</h3></div>
				<div class="od-widget-body">
					<?php if (empty($knightCandidates)): ?>
						<div class="od-empty">No squires pending.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
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
		</div>

		<div class="od-widget-row">
			<div class="od-widget">
				<div class="od-widget-head"><h3>Recent Awards Given</h3></div>
				<div class="od-widget-body">
					<?php if (empty($recentAwards)): ?>
						<div class="od-empty">No recent awards.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="6">
							<thead><tr><th>Player</th><th>Award</th><th>Date</th></tr></thead>
							<tbody>
								<?php foreach ($recentAwards as $a): ?>
									<tr>
										<td><a href="<?= UIR ?>Player/profile/<?= (int)($a['MundaneId'] ?? 0) ?>"><?= $h($a['Persona'] ?? '—') ?></a></td>
										<td><?= $h($a['Award'] ?? '—') ?></td>
										<td><?= $h(substr($a['AwardDate'] ?? '',0,10)) ?></td>
									</tr>
								<?php endforeach; ?>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>

			<div class="od-widget">
				<div class="od-widget-head"><h3>Award Density vs Kingdom Avg</h3></div>
				<div class="od-widget-body">
					<svg class="od-chart od-chart-ring"
						data-value="<?= min(200, $densityVsAvg) ?>"
						data-max="200"
						data-display="<?= (int)$densityVsAvg ?>%"
						data-label="of kingdom avg"></svg>
					<div style="text-align:center;font-size:12px;color:#666;margin-top:6px;">
						<?= number_format($awardDensity['PerMember'] ?? 0, 2) ?> awards/member (park) vs
						<?= number_format($kingdomAvgDensity, 2) ?> (kingdom)
					</div>
				</div>
			</div>
		</div>

		<div class="od-widget-row">
			<div class="od-widget od-widget-wide">
				<div class="od-widget-head"><h3>Awards Given Monthly (12mo)</h3></div>
				<div class="od-widget-body">
					<?php if (empty($awardsByMonth)): ?>
						<div class="od-empty">No award activity.</div>
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
				<div class="od-widget-head"><h3>Top Recommenders (12mo)</h3></div>
				<div class="od-widget-body">
					<?php if (empty($topRecommenders)): ?>
						<div class="od-empty">No recommendations logged.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Recommender</th><th>Count</th></tr></thead>
							<tbody>
								<?php foreach ($topRecommenders as $r): ?>
									<tr>
										<td><a href="<?= UIR ?>Player/profile/<?= (int)$r['MundaneId'] ?>"><?= $h($r['Persona']) ?></a></td>
										<td><?= (int)$r['RecCount'] ?></td>
									</tr>
								<?php endforeach; ?>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>

			<div class="od-widget">
				<div class="od-widget-head"><h3>Unsung Members</h3>
					<span class="od-subline">Attend often, rarely awarded</span>
				</div>
				<div class="od-widget-body">
					<?php if (empty($unsungMembers)): ?>
						<div class="od-empty">No unsung heroes right now.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Player</th><th>Last award</th><th>Att 90d</th></tr></thead>
							<tbody>
								<?php foreach ($unsungMembers as $u): ?>
									<tr>
										<td><a href="<?= UIR ?>Player/profile/<?= (int)$u['MundaneId'] ?>"><?= $h($u['Persona']) ?></a></td>
										<td><?= $h($u['LastAward']) ?></td>
										<td><?= (int)$u['Attendance90'] ?></td>
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
<!-- SECTION 3: Events & Attendance                                      -->
<!-- ================================================================= -->
<div class="od-section">
	<div class="od-section-head">
		<h3 class="od-section-title"><i class="fas fa-calendar-alt"></i> Events &amp; Attendance</h3>
		<i class="fas fa-chevron-down od-section-caret"></i>
	</div>
	<div class="od-section-body">
		<div class="od-widget-row">
			<div class="od-widget">
				<div class="od-widget-head"><h3>Upcoming Park Events</h3></div>
				<div class="od-widget-body">
					<?php if (empty($upcomingEvents)): ?>
						<div class="od-empty">No upcoming events.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="6">
							<thead><tr><th>Event</th><th>Date</th></tr></thead>
							<tbody>
								<?php foreach ($upcomingEvents as $e): ?>
									<tr><td><?= $h($e['Name'] ?? '—') ?></td>
										<td><?= $h(substr($e['StartDate'] ?? '',0,10)) ?></td>
									</tr>
								<?php endforeach; ?>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>

			<div class="od-widget">
				<div class="od-widget-head"><h3>Park Days Schedule</h3></div>
				<div class="od-widget-body">
					<?php if (empty($parkDays)): ?>
						<div class="od-empty">No park days configured.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Day</th><th>Time</th><th>Purpose</th></tr></thead>
							<tbody>
								<?php foreach ($parkDays as $d): ?>
									<tr>
										<td><?= $h($d['WeekDay']) ?></td>
										<td><?= $h($d['Time']) ?></td>
										<td><?= $h($d['Purpose']) ?></td>
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
				<div class="od-widget-head"><h3>Top Attendees (90d)</h3></div>
				<div class="od-widget-body">
					<?php if (empty($topAttendees)): ?>
						<div class="od-empty">No attendance this period.</div>
					<?php else: $vals = array_map(function($r){return (int)$r['AttendCount'];},$topAttendees);
						$labs = array_map(function($r){return $r['Persona'];},$topAttendees); ?>
						<svg class="od-chart od-chart-bar" data-orientation="horizontal"
							data-values="<?= $csv($vals) ?>"
							data-labels="<?= $pipe($labs) ?>"></svg>
					<?php endif; ?>
				</div>
			</div>

			<div class="od-widget">
				<div class="od-widget-head"><h3>Attendance by Day of Week</h3></div>
				<div class="od-widget-body">
					<?php if (empty($attendanceDow)): ?>
						<div class="od-empty">No attendance logged.</div>
					<?php else: $vals = array_map(function($r){return (int)$r['Count'];},$attendanceDow);
						$labs = array_map(function($r){return $r['Day'];},$attendanceDow); ?>
						<svg class="od-chart od-chart-bar"
							data-values="<?= $csv($vals) ?>"
							data-labels="<?= $pipe($labs) ?>"></svg>
					<?php endif; ?>
				</div>
			</div>
		</div>

		<div class="od-widget-row">
			<div class="od-widget od-widget-wide">
				<div class="od-widget-head"><h3>Attendance Heatmap (6 weeks × day)</h3></div>
				<div class="od-widget-body">
					<?php if (empty($attendanceHeatmap['Matrix'])): ?>
						<div class="od-empty">Not enough data for heatmap.</div>
					<?php else:
						$matStr = implode(';', array_map(function($row){return implode(',', $row);}, $attendanceHeatmap['Matrix']));
						$colsStr = implode('|', $attendanceHeatmap['Cols']);
						$rowsStr = implode('|', $attendanceHeatmap['Rows']); ?>
						<svg class="od-chart od-chart-heatmap"
							data-matrix="<?= $h($matStr) ?>"
							data-cols="<?= $h($colsStr) ?>"
							data-rows="<?= $h($rowsStr) ?>"></svg>
					<?php endif; ?>
				</div>
			</div>
		</div>

		<div class="od-widget-row">
			<div class="od-widget od-widget-wide">
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
		</div>

		<div class="od-widget-row">
			<div class="od-widget">
				<div class="od-widget-head"><h3>Newcomers (last 60 days)</h3></div>
				<div class="od-widget-body">
					<?php if (empty($newcomers)): ?>
						<div class="od-empty">No new faces recently.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Player</th><th>First visit</th><th>Visits</th></tr></thead>
							<tbody>
								<?php foreach ($newcomers as $n): ?>
									<tr>
										<td><a href="<?= UIR ?>Player/profile/<?= (int)$n['MundaneId'] ?>"><?= $h($n['Persona']) ?></a></td>
										<td><?= $h($n['FirstAttendance']) ?></td>
										<td><?= (int)$n['VisitCount'] ?></td>
									</tr>
								<?php endforeach; ?>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>

			<div class="od-widget">
				<div class="od-widget-head"><h3>Voter Eligibility</h3></div>
				<div class="od-widget-body">
					<svg class="od-chart od-chart-ring"
						data-value="<?= (int)($voterEligibility['Eligible'] ?? 0) ?>"
						data-max="<?= (int)max(1, $voterEligibility['Active'] ?? 1) ?>"
						data-display="<?= $pctVoter ?>%"
						data-label="of active eligible"></svg>
					<div style="text-align:center;font-size:12px;color:#666;margin-top:6px;">
						<?= (int)$voterEligibility['Eligible'] ?> of <?= (int)$voterEligibility['Active'] ?> active
					</div>
				</div>
			</div>
		</div>

		<div class="od-widget-row">
			<div class="od-widget">
				<div class="od-widget-head"><h3>Recent Tournaments</h3></div>
				<div class="od-widget-body">
					<?php if (empty($recentTournaments)): ?>
						<div class="od-empty">No tournaments hosted recently.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Tournament</th><th>Status</th><th>Date</th></tr></thead>
							<tbody>
								<?php foreach ($recentTournaments as $t): ?>
									<tr>
										<td><?= $h($t['Name']) ?></td>
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
				<div class="od-widget-head"><h3>Recent Courts</h3></div>
				<div class="od-widget-body">
					<?php if (empty($recentCourts)): ?>
						<div class="od-empty">No courts held yet.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Court</th><th>Date</th><th>Status</th></tr></thead>
							<tbody>
								<?php foreach ($recentCourts as $c): ?>
									<tr>
										<td><?= $h($c['Name']) ?></td>
										<td><?= $h($c['Date']) ?></td>
										<td><span class="od-pill"><?= $h($c['Status']) ?></span></td>
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
<!-- SECTION 4: Quick Actions                                            -->
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
						<a class="od-link-card" href="<?= UIR ?>Park/profile/<?= (int)$park_id ?>/recommend"><i class="fas fa-scroll"></i><span>Propose Rec</span></a>
						<a class="od-link-card" href="<?= UIR ?>Park/profile/<?= (int)$park_id ?>/attendance"><i class="fas fa-clipboard-check"></i><span>Record Attendance</span></a>
						<a class="od-link-card" href="<?= UIR ?>Event/create/<?= (int)$park_id ?>"><i class="fas fa-calendar-plus"></i><span>Schedule Event</span></a>
						<a class="od-link-card" href="<?= UIR ?>Park/profile/<?= (int)$park_id ?>/gather"><i class="fas fa-campground"></i><span>Record Park Gather</span></a>
						<a class="od-link-card" href="<?= UIR ?>Park/profile/<?= (int)$park_id ?>/awards"><i class="fas fa-medal"></i><span>Bestow Award</span></a>
						<a class="od-link-card" href="<?= UIR ?>Court/create/<?= (int)($parkInfo['KingdomId'] ?? 0) ?>/<?= (int)$park_id ?>"><i class="fas fa-gavel"></i><span>Hold Court</span></a>
					</div>
				</div>
			</div>
		</div>
	</div>
</div>

<!-- ================================================================= -->
<!-- SECTION 5: Park Info (closed by default)                            -->
<!-- ================================================================= -->
<div class="od-section od-section-closed">
	<div class="od-section-head">
		<h3 class="od-section-title"><i class="fas fa-info-circle"></i> Park Info</h3>
		<i class="fas fa-chevron-down od-section-caret"></i>
	</div>
	<div class="od-section-body">
		<div class="od-widget-row">
			<div class="od-widget od-widget-wide">
				<div class="od-widget-head"><h3>Park at a Glance</h3></div>
				<div class="od-widget-body">
					<?php if (empty($parkInfo)): ?>
						<div class="od-empty">No park info available.</div>
					<?php else: ?>
						<table class="od-table od-table-compact">
							<tbody>
								<tr><td><strong>Name</strong></td><td><?= $h($parkInfo['Name']) ?></td></tr>
								<tr><td><strong>Title</strong></td><td><?= $h($parkInfo['ParkTitle']) ?> (tier <?= (int)$parkInfo['ParkTier'] ?>)</td></tr>
								<tr><td><strong>Kingdom</strong></td><td><a href="<?= UIR ?>Kingdom/profile/<?= (int)$parkInfo['KingdomId'] ?>"><?= $h($parkInfo['KingdomName']) ?></a></td></tr>
								<tr><td><strong>Location</strong></td><td><?= $h(trim(($parkInfo['City'] ?? '') . ', ' . ($parkInfo['Province'] ?? ''), ', ')) ?></td></tr>
								<tr><td><strong>Total members</strong></td><td><?= (int)($parkStats['TotalMembers'] ?? 0) ?></td></tr>
								<tr><td><strong>Tournaments hosted</strong></td><td><?= (int)($parkStats['TournamentsHosted'] ?? 0) ?></td></tr>
								<tr><td><strong>Awards given (12mo)</strong></td><td><?= (int)($parkStats['AwardsGiven12mo'] ?? 0) ?></td></tr>
								<tr><td><strong>Min attendance / period</strong></td><td><?= (int)($parkInfo['MinAttendance'] ?? 0) ?> / <?= (int)($parkInfo['PeriodLength'] ?? 0) ?> month(s)</td></tr>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>
		</div>
	</div>
</div>
