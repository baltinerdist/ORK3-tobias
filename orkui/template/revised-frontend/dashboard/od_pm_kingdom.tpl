<?php
$parkHealth      = $ocData['parkHealth'] ?? [];
$memberCounts    = $ocData['memberCounts'] ?? ['active'=>0,'newcomers'=>0,'lapsed'=>0];
$officersAtRisk  = $ocData['officersAtRisk'] ?? [];
$coverage        = $ocData['coverage'] ?? [];
$topAttendees    = $ocData['topAttendees'] ?? [];
$attendanceTrend = $ocData['attendanceTrend'] ?? [];
$upcomingEvents  = $ocData['upcomingEvents'] ?? [];

$ext              = $ocData['extended'] ?? [];
$approaching      = $ocData['approaching'] ?? [];
$losing           = $ocData['losing'] ?? [];
$weeklyBar        = $ocData['weeklyBar'] ?? [];
$dow              = $ocData['dow'] ?? [];
$parkWeekHeatmap  = $ocData['parkWeekHeatmap'] ?? ['parks'=>[],'weeks'=>[],'matrix'=>[]];
$parksByActive    = $ocData['parksByActive'] ?? [];
$tierDist         = $ocData['tierDistribution'] ?? [];
$newcomersList    = $ocData['newcomersList'] ?? [];
$lapsedList       = $ocData['lapsedList'] ?? [];
$growthMonthly    = $ocData['growthMonthly'] ?? [];
$missingEmail     = $ocData['missingEmail'] ?? [];
$missingWaiver    = $ocData['missingWaiver'] ?? [];
$suspendedList    = $ocData['suspendedList'] ?? [];
$recentModified   = $ocData['recentModified'] ?? [];
$officerTenure    = $ocData['officerTenure'] ?? [];
$vacantSeats      = $ocData['vacantSeats'] ?? [];
$topAttPark       = $ocData['topAttendeesPark'] ?? [];
$dupCredits       = $ocData['dupCredits'] ?? [];
$awardsSummary    = $ocData['awardsSummary'] ?? ['d30'=>0,'d90'=>0,'d365'=>0];
$pendingWaivers   = $ocData['pendingWaivers'] ?? [];
$awardDensity     = $ocData['awardDensity'] ?? [];
$parksNoMonarch   = $ocData['parksNoMonarch'] ?? [];
$parksNoRegent    = $ocData['parksNoRegent'] ?? [];
$parksNoPm        = $ocData['parksNoPm'] ?? [];
$parksNoChampion  = $ocData['parksNoChampion'] ?? [];
$parksNoGmr       = $ocData['parksNoGmr'] ?? [];
$upcomingTourn    = $ocData['upcomingTournaments'] ?? [];
$reportCountdown  = $ocData['reportCountdown'] ?? ['label'=>'—','date'=>'—','days'=>0];
$electionCountdown= $ocData['electionCountdown'] ?? ['label'=>'—','date'=>'—','days'=>0];

$activeMembers   = (int)($ext['active_members'] ?? $memberCounts['active'] ?? 0);
$activeParks     = (int)($ext['active_parks'] ?? count($parkHealth));
$officersSeated  = (int)($ext['officers_seated'] ?? count($coverage) * 0);
$officerSeatsPos = max(1,(int)($ext['officer_seats_possible'] ?? 1));
$officerCovPct   = (int)round(100 * min(1, $officersSeated / $officerSeatsPos));
$eligible        = (int)($ext['eligible_voters'] ?? 0);
$uniq6mo         = max(1,(int)($ext['unique_attendees_6mo'] ?? 1));
$eligiblePct     = (int)round(100 * min(1, $eligible / $uniq6mo));
$suspCount       = (int)($ext['suspended'] ?? 0) + (int)($ext['restricted'] ?? 0);

$dowLabels = 'Sun|Mon|Tue|Wed|Thu|Fri|Sat';
$dowValues = implode(',', array_map(function($d) use ($dow){ return (int)($dow[$d] ?? 0); }, [1,2,3,4,5,6,7]));
?>

<!-- AT A GLANCE -->
<div class="od-grid">
	<div class="od-stat-card"><div class="od-stat-num"><?= (int)$activeMembers ?></div><div class="od-stat-lbl">Active members</div></div>
	<div class="od-stat-card"><div class="od-stat-num"><?= (int)($memberCounts['newcomers'] ?? 0) ?></div><div class="od-stat-lbl">Newcomers (30d)</div></div>
	<div class="od-stat-card"><div class="od-stat-num"><?= (int)($memberCounts['lapsed'] ?? 0) ?></div><div class="od-stat-lbl">Lapsed (90d)</div></div>
	<div class="od-stat-card"><div class="od-stat-num"><?= (int)$eligible ?></div><div class="od-stat-lbl">Voter-eligible</div></div>
	<div class="od-stat-card"><div class="od-stat-num"><?= (int)$activeParks ?></div><div class="od-stat-lbl">Active chapters</div></div>
	<div class="od-stat-card"><div class="od-stat-num"><?= (int)$officersSeated ?></div><div class="od-stat-lbl">Officers seated</div></div>
	<div class="od-stat-card"><div class="od-stat-num"><?= (int)count($officersAtRisk) ?></div><div class="od-stat-lbl">Officers at risk</div></div>
	<div class="od-stat-card"><div class="od-stat-num"><?= (int)$suspCount ?></div><div class="od-stat-lbl">Suspended / restricted</div></div>
</div>

<!-- ========= SECTION: MEMBERS & ELIGIBILITY ========= -->
<div class="od-section">
	<div class="od-section-head">
		<h3 class="od-section-title"><i class="fas fa-users"></i> Members &amp; Eligibility</h3>
		<i class="fas fa-chevron-down od-section-caret"></i>
	</div>
	<div class="od-section-body">
		<div class="od-widget-row">
			<div class="od-widget">
				<div class="od-widget-head"><h3>Voter-eligibility rate</h3><span class="od-subline">Of unique 6-month attendees</span></div>
				<div class="od-widget-body">
					<svg class="od-chart od-chart-ring" data-value="<?= (int)$eligible ?>" data-max="<?= (int)$uniq6mo ?>" data-display="<?= (int)$eligiblePct ?>%" data-label="Eligible"></svg>
					<div style="text-align:center;font-size:12px;color:#666;margin-top:6px;"><?= (int)$eligible ?> of <?= (int)$uniq6mo ?> attendees cleared the 6-credit/6-mo bar</div>
				</div>
			</div>
			<div class="od-widget">
				<div class="od-widget-head"><h3>Officer coverage</h3><span class="od-subline">Seats filled kingdom-wide</span></div>
				<div class="od-widget-body">
					<svg class="od-chart od-chart-ring" data-value="<?= (int)$officersSeated ?>" data-max="<?= (int)$officerSeatsPos ?>" data-display="<?= (int)$officerCovPct ?>%" data-label="Filled"></svg>
					<div style="text-align:center;font-size:12px;color:#666;margin-top:6px;"><?= (int)$officersSeated ?> of <?= (int)$officerSeatsPos ?> possible seats filled</div>
				</div>
			</div>
			<div class="od-widget">
				<div class="od-widget-head"><h3>Member growth (12mo)</h3><span class="od-subline">Unique attendees / month</span></div>
				<div class="od-widget-body">
					<?php if (empty($growthMonthly)): ?><div class="od-empty">No data.</div>
					<?php else: $gv = array_map(function($r){return (int)$r['Unique'];}, $growthMonthly); ?>
						<svg class="od-spark" viewBox="0 0 240 48" preserveAspectRatio="none" data-values="<?= htmlspecialchars(implode(',', $gv)) ?>"></svg>
						<div style="display:flex;justify-content:space-between;font-size:11px;color:#888;margin-top:4px;">
							<span><?= htmlspecialchars($growthMonthly[0]['Month'] ?? '') ?></span>
							<span>Peak: <?= max($gv) ?></span>
							<span><?= htmlspecialchars(end($growthMonthly)['Month'] ?? '') ?></span>
						</div>
					<?php endif; ?>
				</div>
			</div>
		</div>

		<div class="od-widget-row">
			<div class="od-widget">
				<div class="od-widget-head"><h3>Members approaching eligibility</h3><span class="od-subline">3-5 credits in 6mo</span></div>
				<div class="od-widget-body">
					<?php if (empty($approaching)): ?><div class="od-empty">No one currently within reach.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Player</th><th>Chapter</th><th>Credits</th><th>Needs</th></tr></thead>
							<tbody>
							<?php foreach ($approaching as $p): ?>
								<tr>
									<td><a href="<?= UIR ?>Player/profile/<?= (int)$p['MundaneId'] ?>"><?= htmlspecialchars($p['Persona']) ?></a></td>
									<td><a href="<?= UIR ?>Park/profile/<?= (int)$p['ParkId'] ?>"><?= htmlspecialchars($p['ParkName']) ?></a></td>
									<td><?= (int)$p['Credits'] ?></td>
									<td><span class="od-pill od-pill-warn"><?= (int)$p['Needed'] ?> more</span></td>
								</tr>
							<?php endforeach; ?>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>
			<div class="od-widget">
				<div class="od-widget-head"><h3>At risk of losing eligibility</h3><span class="od-subline">6mo-eligible, quiet past 3mo</span></div>
				<div class="od-widget-body">
					<?php if (empty($losing)): ?><div class="od-empty od-empty-ok"><i class="fas fa-check-circle"></i> Eligible members are all active.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Player</th><th>Chapter</th><th>6mo</th><th>3mo</th><th>Last</th></tr></thead>
							<tbody>
							<?php foreach ($losing as $p): ?>
								<tr>
									<td><a href="<?= UIR ?>Player/profile/<?= (int)$p['MundaneId'] ?>"><?= htmlspecialchars($p['Persona']) ?></a></td>
									<td><a href="<?= UIR ?>Park/profile/<?= (int)$p['ParkId'] ?>"><?= htmlspecialchars($p['ParkName']) ?></a></td>
									<td><?= (int)$p['C6'] ?></td>
									<td><?= (int)$p['C3'] ?></td>
									<td><?= htmlspecialchars($p['LastAttended']) ?></td>
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
				<div class="od-widget-head"><h3>Recent newcomers</h3><span class="od-subline">First-ever credit within 30d</span></div>
				<div class="od-widget-body">
					<?php if (empty($newcomersList)): ?><div class="od-empty">No new attendees recently.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Player</th><th>Chapter</th><th>First gather</th><th>Visits</th></tr></thead>
							<tbody>
							<?php foreach ($newcomersList as $n): ?>
								<tr>
									<td><a href="<?= UIR ?>Player/profile/<?= (int)$n['MundaneId'] ?>"><?= htmlspecialchars($n['Persona']) ?></a></td>
									<td><a href="<?= UIR ?>Park/profile/<?= (int)$n['ParkId'] ?>"><?= htmlspecialchars($n['ParkName']) ?></a></td>
									<td><?= htmlspecialchars($n['FirstAttendance']) ?></td>
									<td><?= (int)$n['Visits'] ?></td>
								</tr>
							<?php endforeach; ?>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>
			<div class="od-widget">
				<div class="od-widget-head"><h3>Lapsed members</h3><span class="od-subline">Active 90-365d ago, silent since</span></div>
				<div class="od-widget-body">
					<?php if (empty($lapsedList)): ?><div class="od-empty od-empty-ok"><i class="fas fa-check-circle"></i> No lapsed members.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Player</th><th>Chapter</th><th>Last seen</th></tr></thead>
							<tbody>
							<?php foreach ($lapsedList as $n): ?>
								<tr>
									<td><a href="<?= UIR ?>Player/profile/<?= (int)$n['MundaneId'] ?>"><?= htmlspecialchars($n['Persona']) ?></a></td>
									<td><a href="<?= UIR ?>Park/profile/<?= (int)$n['ParkId'] ?>"><?= htmlspecialchars($n['ParkName']) ?></a></td>
									<td><?= htmlspecialchars($n['LastAttended']) ?></td>
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
				<div class="od-widget-head"><h3>Suspended &amp; restricted</h3></div>
				<div class="od-widget-body">
					<?php if (empty($suspendedList)): ?><div class="od-empty od-empty-ok"><i class="fas fa-check-circle"></i> No active suspensions.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Player</th><th>Status</th><th>Since</th><th>Until</th><th>Reason</th></tr></thead>
							<tbody>
							<?php foreach ($suspendedList as $s): ?>
								<tr>
									<td><a href="<?= UIR ?>Player/profile/<?= (int)$s['MundaneId'] ?>"><?= htmlspecialchars($s['Persona']) ?></a></td>
									<td><?php
										$pills = [];
										if ($s['Suspended']) $pills[] = '<span class="od-pill od-pill-warn">Suspended</span>';
										if ($s['Restricted']) $pills[] = '<span class="od-pill od-pill-warn">Restricted</span>';
										echo implode(' ', $pills); ?></td>
									<td><?= htmlspecialchars($s['Since']) ?></td>
									<td><?= htmlspecialchars($s['Until']) ?></td>
									<td><?= htmlspecialchars($s['Reason']) ?></td>
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

<!-- ========= SECTION: CHAPTERS & COVERAGE ========= -->
<div class="od-section">
	<div class="od-section-head">
		<h3 class="od-section-title"><i class="fas fa-map-marked-alt"></i> Chapters &amp; Coverage</h3>
		<i class="fas fa-chevron-down od-section-caret"></i>
	</div>
	<div class="od-section-body">
		<div class="od-widget-row">
			<div class="od-widget od-widget-wide">
				<div class="od-widget-head"><h3>Chapter attendance matrix</h3>
					<a class="od-link" href="<?= UIR ?>Reports/attendance/<?= (int)$kingdom_id ?>">Full report<i class="fas fa-arrow-right"></i></a>
				</div>
				<div class="od-widget-body">
					<?php if (empty($parkHealth)): ?><div class="od-empty">No chapter data.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="8">
							<thead><tr><th>Chapter</th><th>Tier</th><th>Monthly avg</th><th>Active members</th><th>Last attendance</th></tr></thead>
							<tbody>
							<?php foreach ($parkHealth as $p): ?>
								<tr>
									<td><a href="<?= UIR ?>Park/profile/<?= (int)$p['ParkId'] ?>"><?= htmlspecialchars($p['ParkName']) ?></a></td>
									<td><?= htmlspecialchars($p['ParkType'] ?? '—') ?></td>
									<td><?= number_format((float)$p['MonthlyAvg'], 1) ?></td>
									<td><?= (int)$p['ActiveMembers'] ?></td>
									<td><?= htmlspecialchars($p['LastAttendance']) ?></td>
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
				<div class="od-widget-head"><h3>Parks by active members (90d)</h3></div>
				<div class="od-widget-body">
					<?php if (empty($parksByActive)): ?><div class="od-empty">No data.</div>
					<?php else:
						$vals = implode(',', array_map(function($p){ return (int)$p['Count']; }, $parksByActive));
						$lbls = implode('|', array_map(function($p){ return htmlspecialchars($p['ParkName'], ENT_QUOTES); }, $parksByActive));
					?>
						<svg class="od-chart od-chart-bar" data-orientation="horizontal" style="height:<?= 26 * count($parksByActive) + 8 ?>px" data-values="<?= $vals ?>" data-labels="<?= $lbls ?>"></svg>
					<?php endif; ?>
				</div>
			</div>
			<div class="od-widget">
				<div class="od-widget-head"><h3>Chapter tier distribution</h3></div>
				<div class="od-widget-body">
					<?php if (empty($tierDist)): ?><div class="od-empty">No data.</div>
					<?php else:
						$v = implode(',', array_map(function($t){ return (int)$t['Count']; }, $tierDist));
						$l = implode('|', array_map(function($t){ return htmlspecialchars($t['Tier'], ENT_QUOTES); }, $tierDist));
					?>
						<svg class="od-chart od-chart-donut" data-values="<?= $v ?>" data-labels="<?= $l ?>" data-center-label="Chapters"></svg>
					<?php endif; ?>
				</div>
			</div>
		</div>

		<div class="od-widget-row">
			<div class="od-widget od-widget-wide">
				<div class="od-widget-head"><h3>Park officer coverage</h3><span class="od-subline">Core seats per active chapter</span></div>
				<div class="od-widget-body">
					<?php if (empty($coverage)): ?><div class="od-empty">No chapter data.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="8">
							<thead><tr><th>Chapter</th><th>Monarch</th><th>Regent</th><th>PM</th><th>Champion</th><th>GMR</th><th>Total</th></tr></thead>
							<tbody>
							<?php foreach ($coverage as $c):
								$tick = '<i class="fas fa-check od-cov-yes"></i>';
								$cross = '<i class="fas fa-minus od-cov-no"></i>';
							?>
								<tr>
									<td><a href="<?= UIR ?>Park/profile/<?= (int)$c['ParkId'] ?>"><?= htmlspecialchars($c['ParkName']) ?></a></td>
									<td><?= $c['HasMonarch']  ? $tick : $cross ?></td>
									<td><?= $c['HasRegent']   ? $tick : $cross ?></td>
									<td><?= $c['HasPm']       ? $tick : $cross ?></td>
									<td><?= $c['HasChampion'] ? $tick : $cross ?></td>
									<td><?= $c['HasGmr']      ? $tick : $cross ?></td>
									<td><strong><?= (int)$c['SeatCount'] ?>/5</strong></td>
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
				<div class="od-widget-head"><h3>Parks without Monarch</h3></div>
				<div class="od-widget-body">
					<?php if (empty($parksNoMonarch)): ?><div class="od-empty od-empty-ok"><i class="fas fa-check-circle"></i> All covered.</div>
					<?php else: ?>
						<ul style="margin:0;padding-left:16px;font-size:13px;max-height:160px;overflow:auto;">
						<?php foreach ($parksNoMonarch as $p): ?><li><a href="<?= UIR ?>Park/profile/<?= (int)$p['ParkId'] ?>"><?= htmlspecialchars($p['ParkName']) ?></a></li><?php endforeach; ?>
						</ul>
					<?php endif; ?>
				</div>
			</div>
			<div class="od-widget">
				<div class="od-widget-head"><h3>Parks without Regent</h3></div>
				<div class="od-widget-body">
					<?php if (empty($parksNoRegent)): ?><div class="od-empty od-empty-ok"><i class="fas fa-check-circle"></i> All covered.</div>
					<?php else: ?>
						<ul style="margin:0;padding-left:16px;font-size:13px;max-height:160px;overflow:auto;">
						<?php foreach ($parksNoRegent as $p): ?><li><a href="<?= UIR ?>Park/profile/<?= (int)$p['ParkId'] ?>"><?= htmlspecialchars($p['ParkName']) ?></a></li><?php endforeach; ?>
						</ul>
					<?php endif; ?>
				</div>
			</div>
			<div class="od-widget">
				<div class="od-widget-head"><h3>Parks without PM</h3></div>
				<div class="od-widget-body">
					<?php if (empty($parksNoPm)): ?><div class="od-empty od-empty-ok"><i class="fas fa-check-circle"></i> All covered.</div>
					<?php else: ?>
						<ul style="margin:0;padding-left:16px;font-size:13px;max-height:160px;overflow:auto;">
						<?php foreach ($parksNoPm as $p): ?><li><a href="<?= UIR ?>Park/profile/<?= (int)$p['ParkId'] ?>"><?= htmlspecialchars($p['ParkName']) ?></a></li><?php endforeach; ?>
						</ul>
					<?php endif; ?>
				</div>
			</div>
			<div class="od-widget">
				<div class="od-widget-head"><h3>Parks without Champion</h3></div>
				<div class="od-widget-body">
					<?php if (empty($parksNoChampion)): ?><div class="od-empty od-empty-ok"><i class="fas fa-check-circle"></i> All covered.</div>
					<?php else: ?>
						<ul style="margin:0;padding-left:16px;font-size:13px;max-height:160px;overflow:auto;">
						<?php foreach ($parksNoChampion as $p): ?><li><a href="<?= UIR ?>Park/profile/<?= (int)$p['ParkId'] ?>"><?= htmlspecialchars($p['ParkName']) ?></a></li><?php endforeach; ?>
						</ul>
					<?php endif; ?>
				</div>
			</div>
			<div class="od-widget">
				<div class="od-widget-head"><h3>Parks without GMR</h3></div>
				<div class="od-widget-body">
					<?php if (empty($parksNoGmr)): ?><div class="od-empty od-empty-ok"><i class="fas fa-check-circle"></i> All covered.</div>
					<?php else: ?>
						<ul style="margin:0;padding-left:16px;font-size:13px;max-height:160px;overflow:auto;">
						<?php foreach ($parksNoGmr as $p): ?><li><a href="<?= UIR ?>Park/profile/<?= (int)$p['ParkId'] ?>"><?= htmlspecialchars($p['ParkName']) ?></a></li><?php endforeach; ?>
						</ul>
					<?php endif; ?>
				</div>
			</div>
		</div>
	</div>
</div>

<!-- ========= SECTION: ATTENDANCE & ACTIVITY ========= -->
<div class="od-section">
	<div class="od-section-head">
		<h3 class="od-section-title"><i class="fas fa-chart-line"></i> Attendance &amp; Activity</h3>
		<i class="fas fa-chevron-down od-section-caret"></i>
	</div>
	<div class="od-section-body">
		<div class="od-widget-row">
			<div class="od-widget">
				<div class="od-widget-head"><h3>Kingdom attendance trend (12w)</h3></div>
				<div class="od-widget-body">
					<?php if (empty($attendanceTrend)): ?><div class="od-empty">No data.</div>
					<?php else: $vals = array_map(function($w){ return (int)$w['UniquePlayers']; }, $attendanceTrend); ?>
						<svg class="od-spark" viewBox="0 0 240 48" preserveAspectRatio="none" data-values="<?= htmlspecialchars(implode(',', $vals)) ?>"></svg>
						<div style="display:flex;justify-content:space-between;font-size:11px;color:#888;margin-top:4px;">
							<span><?= htmlspecialchars($attendanceTrend[0]['WeekStart'] ?? '') ?></span>
							<span>Peak: <?= max($vals) ?></span>
							<span><?= htmlspecialchars(end($attendanceTrend)['WeekStart'] ?? '') ?></span>
						</div>
					<?php endif; ?>
				</div>
			</div>
			<div class="od-widget">
				<div class="od-widget-head"><h3>Weekly attendance (12w)</h3><span class="od-subline">Total credits per week</span></div>
				<div class="od-widget-body">
					<?php if (empty($weeklyBar)): ?><div class="od-empty">No data.</div>
					<?php else:
						$vals = implode(',', array_map(function($w){ return (int)$w['Credits']; }, $weeklyBar));
						$lbls = implode('|', array_map(function($w){ return substr($w['WeekStart'],5); }, $weeklyBar));
					?>
						<svg class="od-chart od-chart-bar" data-values="<?= $vals ?>" data-labels="<?= $lbls ?>"></svg>
					<?php endif; ?>
				</div>
			</div>
		</div>

		<div class="od-widget-row">
			<div class="od-widget">
				<div class="od-widget-head"><h3>Activity by day-of-week</h3><span class="od-subline">Last 6 months</span></div>
				<div class="od-widget-body">
					<?php if (!array_sum($dow)): ?><div class="od-empty">No data.</div>
					<?php else: ?>
						<svg class="od-chart od-chart-bar" data-values="<?= $dowValues ?>" data-labels="<?= $dowLabels ?>"></svg>
					<?php endif; ?>
				</div>
			</div>
			<div class="od-widget">
				<div class="od-widget-head"><h3>Awards trailing window</h3><span class="od-subline">Awards given</span></div>
				<div class="od-widget-body">
					<div style="display:grid;grid-template-columns:repeat(3,1fr);gap:6px;text-align:center;">
						<div class="od-stat-card"><div class="od-stat-num"><?= (int)$awardsSummary['d30'] ?></div><div class="od-stat-lbl">30d</div></div>
						<div class="od-stat-card"><div class="od-stat-num"><?= (int)$awardsSummary['d90'] ?></div><div class="od-stat-lbl">90d</div></div>
						<div class="od-stat-card"><div class="od-stat-num"><?= (int)$awardsSummary['d365'] ?></div><div class="od-stat-lbl">1 year</div></div>
					</div>
				</div>
			</div>
		</div>

		<div class="od-widget-row">
			<div class="od-widget od-widget-wide">
				<div class="od-widget-head"><h3>Park × week attendance heatmap</h3><span class="od-subline">Top 12 chapters, last 12 weeks</span></div>
				<div class="od-widget-body">
					<?php if (empty($parkWeekHeatmap['parks'])): ?><div class="od-empty">No data.</div>
					<?php else:
						$m = implode(';', array_map(function($r){ return implode(',', $r); }, $parkWeekHeatmap['matrix']));
						$cols = implode('|', array_map(function($w){ return substr($w,5); }, $parkWeekHeatmap['weeks']));
						$rows = implode('|', array_map(function($p){ return htmlspecialchars($p, ENT_QUOTES); }, $parkWeekHeatmap['parks']));
					?>
						<svg class="od-chart od-chart-heatmap" data-matrix="<?= $m ?>" data-cols="<?= $cols ?>" data-rows="<?= $rows ?>"></svg>
					<?php endif; ?>
				</div>
			</div>
		</div>

		<div class="od-widget-row">
			<div class="od-widget">
				<div class="od-widget-head"><h3>Top attendees (kingdom, 90d)</h3></div>
				<div class="od-widget-body">
					<?php if (empty($topAttendees)): ?><div class="od-empty">No data.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Player</th><th>Credits</th></tr></thead>
							<tbody>
							<?php foreach ($topAttendees as $p): ?>
								<tr>
									<td><a href="<?= UIR ?>Player/profile/<?= (int)$p['MundaneId'] ?>"><?= htmlspecialchars($p['Persona']) ?></a></td>
									<td><?= (int)$p['AttendCount'] ?></td>
								</tr>
							<?php endforeach; ?>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>
			<div class="od-widget">
				<div class="od-widget-head"><h3>Top attendees by chapter</h3></div>
				<div class="od-widget-body">
					<?php if (empty($topAttPark)): ?><div class="od-empty">No data.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Player</th><th>Chapter</th><th>Credits</th></tr></thead>
							<tbody>
							<?php foreach ($topAttPark as $p): ?>
								<tr>
									<td><a href="<?= UIR ?>Player/profile/<?= (int)$p['MundaneId'] ?>"><?= htmlspecialchars($p['Persona']) ?></a></td>
									<td><a href="<?= UIR ?>Park/profile/<?= (int)$p['ParkId'] ?>"><?= htmlspecialchars($p['ParkName']) ?></a></td>
									<td><?= (int)$p['Count'] ?></td>
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
				<div class="od-widget-head"><h3>Cross-chapter duplicate credit audit</h3><span class="od-subline">Same player credited at multiple parks in one 3-week window</span></div>
				<div class="od-widget-body">
					<?php if (empty($dupCredits)): ?><div class="od-empty od-empty-ok"><i class="fas fa-check-circle"></i> No duplicate-credit audit hits.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Player</th><th>Parks</th><th>#</th><th>Most recent</th></tr></thead>
							<tbody>
							<?php foreach ($dupCredits as $d): ?>
								<tr>
									<td><a href="<?= UIR ?>Player/profile/<?= (int)$d['MundaneId'] ?>"><?= htmlspecialchars($d['Persona']) ?></a></td>
									<td><?= htmlspecialchars($d['ParksList']) ?></td>
									<td><?= (int)$d['Parks'] ?></td>
									<td><?= htmlspecialchars($d['LastDate']) ?></td>
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

<!-- ========= SECTION: OFFICERS AT RISK ========= -->
<div class="od-section">
	<div class="od-section-head">
		<h3 class="od-section-title"><i class="fas fa-user-shield"></i> Officers</h3>
		<i class="fas fa-chevron-down od-section-caret"></i>
	</div>
	<div class="od-section-body">
		<div class="od-widget-row">
			<div class="od-widget">
				<div class="od-widget-head"><h3>Officers at attendance risk</h3></div>
				<div class="od-widget-body">
					<?php if (empty($officersAtRisk)): ?><div class="od-empty od-empty-ok"><i class="fas fa-check-circle"></i> No officers at risk this cycle.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Officer</th><th>Office</th><th>Missed (28d)</th><th>Total (12w)</th></tr></thead>
							<tbody>
							<?php foreach ($officersAtRisk as $o): ?>
								<tr>
									<td><a href="<?= UIR ?>Player/profile/<?= (int)$o['MundaneId'] ?>"><?= htmlspecialchars($o['Persona']) ?></a></td>
									<td><?= htmlspecialchars($o['OfficerRole']) ?></td>
									<td><?= htmlspecialchars((string)$o['ConsecutiveMissed']) ?></td>
									<td><?= (int)$o['TotalMissed12w'] ?></td>
								</tr>
							<?php endforeach; ?>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>
			<div class="od-widget">
				<div class="od-widget-head"><h3>Kingdom-level vacancies</h3></div>
				<div class="od-widget-body">
					<?php if (empty($vacantSeats)): ?><div class="od-empty">No data.</div>
					<?php else: ?>
						<table class="od-table od-table-compact">
							<thead><tr><th>Seat</th><th>Status</th></tr></thead>
							<tbody>
							<?php foreach ($vacantSeats as $v): ?>
								<tr<?= $v['Vacant'] ? ' class="od-row-vacant"' : '' ?>>
									<td><?= htmlspecialchars($v['Role']) ?></td>
									<td><?= $v['Vacant'] ? '<span class="od-pill od-pill-warn">Vacant</span>' : '<span class="od-pill od-pill-ok">Seated</span>' ?></td>
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
				<div class="od-widget-head"><h3>Officer tenure log</h3><span class="od-subline">Days since last seat change</span></div>
				<div class="od-widget-body">
					<?php if (empty($officerTenure)): ?><div class="od-empty">No data.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="10">
							<thead><tr><th>Officer</th><th>Role</th><th>Where</th><th>Since</th><th>Days</th></tr></thead>
							<tbody>
							<?php foreach ($officerTenure as $t): ?>
								<tr>
									<td><a href="<?= UIR ?>Player/profile/<?= (int)$t['MundaneId'] ?>"><?= htmlspecialchars($t['Persona']) ?></a></td>
									<td><?= htmlspecialchars($t['Role']) ?></td>
									<td><?php if ($t['ParkId']>0): ?><a href="<?= UIR ?>Park/profile/<?= (int)$t['ParkId'] ?>"><?= htmlspecialchars($t['ParkName']) ?></a><?php else: ?>Kingdom<?php endif; ?></td>
									<td><?= htmlspecialchars($t['Modified']) ?></td>
									<td><?= (int)$t['DaysSeated'] ?></td>
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

<!-- ========= SECTION: REPORTS & DEADLINES ========= -->
<div class="od-section">
	<div class="od-section-head">
		<h3 class="od-section-title"><i class="fas fa-calendar-check"></i> Reports &amp; Deadlines</h3>
		<i class="fas fa-chevron-down od-section-caret"></i>
	</div>
	<div class="od-section-body">
		<div class="od-widget-row">
			<div class="od-widget">
				<div class="od-widget-head"><h3>Next quarterly report</h3></div>
				<div class="od-widget-body">
					<div style="text-align:center;padding:8px;">
						<div style="font-size:40px;font-weight:800;color:#5d3fb8;line-height:1;"><?= (int)$reportCountdown['days'] ?></div>
						<div style="font-size:11px;color:#888;text-transform:uppercase;letter-spacing:0.06em;margin-top:4px;">days until <?= htmlspecialchars($reportCountdown['label']) ?></div>
						<div style="font-size:13px;color:#666;margin-top:6px;"><?= htmlspecialchars($reportCountdown['date']) ?></div>
					</div>
				</div>
			</div>
			<div class="od-widget">
				<div class="od-widget-head"><h3>Next election window</h3></div>
				<div class="od-widget-body">
					<div style="text-align:center;padding:8px;">
						<div style="font-size:40px;font-weight:800;color:#5d3fb8;line-height:1;"><?= (int)$electionCountdown['days'] ?></div>
						<div style="font-size:11px;color:#888;text-transform:uppercase;letter-spacing:0.06em;margin-top:4px;">days to <?= htmlspecialchars($electionCountdown['label']) ?></div>
						<div style="font-size:13px;color:#666;margin-top:6px;"><?= htmlspecialchars($electionCountdown['date']) ?></div>
					</div>
				</div>
			</div>
			<div class="od-widget">
				<div class="od-widget-head"><h3>Waivers awaiting verification</h3></div>
				<div class="od-widget-body">
					<?php if (empty($pendingWaivers)): ?><div class="od-empty od-empty-ok"><i class="fas fa-check-circle"></i> No pending waivers.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Signer</th><th>Chapter</th><th>Signed</th></tr></thead>
							<tbody>
							<?php foreach ($pendingWaivers as $w): ?>
								<tr>
									<td><a href="<?= UIR ?>Player/profile/<?= (int)$w['MundaneId'] ?>"><?= htmlspecialchars($w['Persona']) ?></a></td>
									<td><?php if ($w['ParkId']>0): ?><a href="<?= UIR ?>Park/profile/<?= (int)$w['ParkId'] ?>"><?= htmlspecialchars($w['ParkName']) ?></a><?php else: ?>—<?php endif; ?></td>
									<td><?= htmlspecialchars($w['SignedAt']) ?></td>
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
				<div class="od-widget-head"><h3>Upcoming kingdom events</h3></div>
				<div class="od-widget-body">
					<?php if (empty($upcomingEvents)): ?><div class="od-empty">No scheduled events.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Event</th><th>Chapter</th><th>Date</th></tr></thead>
							<tbody>
							<?php foreach ($upcomingEvents as $e): ?>
								<tr>
									<td><?= htmlspecialchars($e['Name']) ?></td>
									<td><a href="<?= UIR ?>Park/profile/<?= (int)$e['ParkId'] ?>"><?= htmlspecialchars($e['ParkName']) ?></a></td>
									<td><?= htmlspecialchars(substr($e['StartDate'],0,10)) ?></td>
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
				<div class="od-widget-head"><h3>Upcoming tournaments</h3></div>
				<div class="od-widget-body">
					<?php if (empty($upcomingTourn)): ?><div class="od-empty">No upcoming tournaments.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Tournament</th><th>Chapter</th><th>Date</th></tr></thead>
							<tbody>
							<?php foreach ($upcomingTourn as $t): ?>
								<tr>
									<td><?= htmlspecialchars($t['Name']) ?></td>
									<td><a href="<?= UIR ?>Park/profile/<?= (int)$t['ParkId'] ?>"><?= htmlspecialchars($t['ParkName']) ?></a></td>
									<td><?= htmlspecialchars($t['Date']) ?></td>
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

<!-- ========= SECTION: AWARDS DENSITY ========= -->
<div class="od-section od-section-closed">
	<div class="od-section-head">
		<h3 class="od-section-title"><i class="fas fa-medal"></i> Awards Density</h3>
		<i class="fas fa-chevron-down od-section-caret"></i>
	</div>
	<div class="od-section-body">
		<div class="od-widget-row">
			<div class="od-widget od-widget-wide">
				<div class="od-widget-head"><h3>Awards per chapter (1yr)</h3></div>
				<div class="od-widget-body">
					<?php if (empty($awardDensity)): ?><div class="od-empty">No data.</div>
					<?php else:
						$vals = implode(',', array_map(function($p){ return (int)$p['Count']; }, $awardDensity));
						$lbls = implode('|', array_map(function($p){ return htmlspecialchars($p['ParkName'], ENT_QUOTES); }, $awardDensity));
					?>
						<svg class="od-chart od-chart-bar" data-orientation="horizontal" style="height:<?= 26 * count($awardDensity) + 8 ?>px" data-values="<?= $vals ?>" data-labels="<?= $lbls ?>"></svg>
					<?php endif; ?>
				</div>
			</div>
		</div>
	</div>
</div>

<!-- ========= SECTION: QUICK ACTIONS ========= -->
<div class="od-section">
	<div class="od-section-head">
		<h3 class="od-section-title"><i class="fas fa-bolt"></i> Quick Actions &amp; Tools</h3>
		<i class="fas fa-chevron-down od-section-caret"></i>
	</div>
	<div class="od-section-body">
		<div class="od-widget-row">
			<div class="od-widget od-widget-wide">
				<div class="od-widget-head"><h3>Jump to</h3></div>
				<div class="od-widget-body">
					<div class="od-links-grid">
						<a class="od-link-card" href="<?= UIR ?>Reports/voting/<?= (int)$kingdom_id ?>"><i class="fas fa-vote-yea"></i><span>Voting eligibility</span></a>
						<a class="od-link-card" href="<?= UIR ?>Reports/attendance/<?= (int)$kingdom_id ?>"><i class="fas fa-chart-line"></i><span>Kingdom attendance</span></a>
						<a class="od-link-card" href="<?= UIR ?>Reports/recommendations/<?= (int)$kingdom_id ?>"><i class="fas fa-medal"></i><span>Recommendations</span></a>
						<a class="od-link-card" href="<?= UIR ?>Admin/kingdom/<?= (int)$kingdom_id ?>"><i class="fas fa-cog"></i><span>Kingdom admin</span></a>
						<a class="od-link-card" href="<?= UIR ?>Member/new"><i class="fas fa-user-plus"></i><span>Add a member</span></a>
						<a class="od-link-card" href="<?= UIR ?>Attendance/index"><i class="fas fa-clipboard-check"></i><span>Attendance entry</span></a>
						<a class="od-link-card" href="<?= UIR ?>Kingdom/profile/<?= (int)$kingdom_id ?>"><i class="fas fa-crown"></i><span>Kingdom profile</span></a>
						<a class="od-link-card" href="<?= UIR ?>Reports/officers/<?= (int)$kingdom_id ?>"><i class="fas fa-user-shield"></i><span>Officer roster</span></a>
					</div>
				</div>
			</div>
		</div>
	</div>
</div>

<!-- ========= SECTION: MUNDANE-RECORD QUALITY (closed) ========= -->
<div class="od-section od-section-closed">
	<div class="od-section-head">
		<h3 class="od-section-title"><i class="fas fa-database"></i> Mundane-Record Quality</h3>
		<i class="fas fa-chevron-down od-section-caret"></i>
	</div>
	<div class="od-section-body">
		<div class="od-widget-row">
			<div class="od-widget">
				<div class="od-widget-head"><h3>Members missing email</h3></div>
				<div class="od-widget-body">
					<?php if (empty($missingEmail)): ?><div class="od-empty od-empty-ok"><i class="fas fa-check-circle"></i> All records complete.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Player</th></tr></thead>
							<tbody>
							<?php foreach ($missingEmail as $m): ?>
								<tr><td><a href="<?= UIR ?>Player/profile/<?= (int)$m['MundaneId'] ?>"><?= htmlspecialchars($m['Persona']) ?></a></td></tr>
							<?php endforeach; ?>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>
			<div class="od-widget">
				<div class="od-widget-head"><h3>Members without waiver</h3></div>
				<div class="od-widget-body">
					<?php if (empty($missingWaiver)): ?><div class="od-empty od-empty-ok"><i class="fas fa-check-circle"></i> All waivers on file.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Player</th></tr></thead>
							<tbody>
							<?php foreach ($missingWaiver as $m): ?>
								<tr><td><a href="<?= UIR ?>Player/profile/<?= (int)$m['MundaneId'] ?>"><?= htmlspecialchars($m['Persona']) ?></a></td></tr>
							<?php endforeach; ?>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>
			<div class="od-widget">
				<div class="od-widget-head"><h3>Recently modified records</h3><span class="od-subline">Audit trail, last 30d</span></div>
				<div class="od-widget-body">
					<?php if (empty($recentModified)): ?><div class="od-empty">No activity.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Player</th><th>Modified</th></tr></thead>
							<tbody>
							<?php foreach ($recentModified as $m): ?>
								<tr>
									<td><a href="<?= UIR ?>Player/profile/<?= (int)$m['MundaneId'] ?>"><?= htmlspecialchars($m['Persona']) ?></a></td>
									<td><?= htmlspecialchars($m['Modified']) ?></td>
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
