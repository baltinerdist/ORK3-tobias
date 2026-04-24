<?php
$memberCounts    = $ocData['memberCounts'] ?? ['active'=>0,'newcomers'=>0,'lapsed'=>0,'eligible'=>0];
$newcomers       = $ocData['newcomers'] ?? [];
$officers        = $ocData['officers']  ?? [];
$approaching     = $ocData['approaching'] ?? [];
$losing          = $ocData['losing'] ?? [];
$topAttendees    = $ocData['topAttendees'] ?? [];
$attendanceTrend = $ocData['attendanceTrend'] ?? [];
$upcomingEvents  = $ocData['upcomingEvents'] ?? [];

$ext             = $ocData['extended'] ?? [];
$weeklyBar       = $ocData['weeklyBar'] ?? [];
$dow             = $ocData['dow'] ?? [];
$dowWeekHeatmap  = $ocData['dowWeekHeatmap'] ?? ['days'=>[],'weeks'=>[],'matrix'=>[]];
$growthMonthly   = $ocData['growthMonthly'] ?? [];
$missingEmail    = $ocData['missingEmail'] ?? [];
$missingWaiver   = $ocData['missingWaiver'] ?? [];
$suspendedList   = $ocData['suspendedList'] ?? [];
$recentModified  = $ocData['recentModified'] ?? [];
$parkdays        = $ocData['parkdays'] ?? [];
$topAttEver      = $ocData['topAttendeesEver'] ?? [];
$neverAttended   = $ocData['neverAttended'] ?? [];
$retention       = $ocData['retentionCohorts'] ?? ['0-30'=>0,'31-90'=>0,'91-365'=>0,'365+'=>0];
$pendingWaivers  = $ocData['pendingWaivers'] ?? [];
$upcomingTourn   = $ocData['upcomingTourn'] ?? [];
$reportCountdown = $ocData['reportCountdown'] ?? ['label'=>'—','date'=>'—','days'=>0];
$electionCountdown = $ocData['electionCountdown'] ?? ['label'=>'—','date'=>'—','days'=>0];

$activeMembers  = (int)($ext['active_members'] ?? $memberCounts['active'] ?? 0);
$totalMembers   = (int)($ext['total_members']  ?? 0);
$activePct      = $totalMembers > 0 ? (int)round(100 * min(1, $activeMembers / $totalMembers)) : 0;
$officersSeated = (int)($ext['officers_seated'] ?? 0);
$officerCovPct  = (int)round(100 * min(1, $officersSeated / 5));

$eligible = (int)($memberCounts['eligible'] ?? 0);

$dowLabels = 'Sun|Mon|Tue|Wed|Thu|Fri|Sat';
$dowValues = implode(',', array_map(function($d) use ($dow){ return (int)($dow[$d] ?? 0); }, [1,2,3,4,5,6,7]));
?>

<!-- AT-A-GLANCE -->
<div class="od-grid">
	<div class="od-stat-card"><div class="od-stat-num"><?= (int)$activeMembers ?></div><div class="od-stat-lbl">Active members</div></div>
	<div class="od-stat-card"><div class="od-stat-num"><?= (int)$eligible ?></div><div class="od-stat-lbl">Voter-eligible</div></div>
	<div class="od-stat-card"><div class="od-stat-num"><?= (int)($memberCounts['newcomers'] ?? 0) ?></div><div class="od-stat-lbl">Newcomers (30d)</div></div>
	<div class="od-stat-card"><div class="od-stat-num"><?= (int)($memberCounts['lapsed'] ?? 0) ?></div><div class="od-stat-lbl">Lapsed (90d)</div></div>
	<div class="od-stat-card"><div class="od-stat-num"><?= (int)$officersSeated ?>/5</div><div class="od-stat-lbl">Officers seated</div></div>
	<div class="od-stat-card"><div class="od-stat-num"><?= (int)($ext['attendance_30d'] ?? 0) ?></div><div class="od-stat-lbl">Credits (30d)</div></div>
	<div class="od-stat-card"><div class="od-stat-num"><?= (int)($ext['awards_90d'] ?? 0) ?></div><div class="od-stat-lbl">Awards (90d)</div></div>
	<div class="od-stat-card"><div class="od-stat-num"><?= (int)($ext['events_upcoming'] ?? 0) ?></div><div class="od-stat-lbl">Upcoming events</div></div>
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
				<div class="od-widget-head"><h3>Active-member rate</h3><span class="od-subline">Of all park records</span></div>
				<div class="od-widget-body">
					<svg class="od-chart od-chart-ring" data-value="<?= (int)$activeMembers ?>" data-max="<?= max(1,(int)$totalMembers) ?>" data-display="<?= (int)$activePct ?>%" data-label="Active"></svg>
					<div style="text-align:center;font-size:12px;color:#666;margin-top:6px;"><?= (int)$activeMembers ?> active of <?= (int)$totalMembers ?> total</div>
				</div>
			</div>
			<div class="od-widget">
				<div class="od-widget-head"><h3>Officer seats filled</h3></div>
				<div class="od-widget-body">
					<svg class="od-chart od-chart-ring" data-value="<?= (int)$officersSeated ?>" data-max="5" data-display="<?= (int)$officersSeated ?>/5" data-label="Seats"></svg>
					<div style="text-align:center;font-size:12px;color:#666;margin-top:6px;"><?= (int)$officerCovPct ?>% of core roles filled</div>
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
				<div class="od-widget-head"><h3>Member tenure cohorts</h3><span class="od-subline">How long members have been park-signed</span></div>
				<div class="od-widget-body">
					<?php $rv = array_values($retention); if (array_sum($rv) === 0): ?>
						<div class="od-empty">No park-member-since data.</div>
					<?php else: ?>
						<svg class="od-chart od-chart-donut" data-values="<?= implode(',', $rv) ?>" data-labels="0-30d|31-90d|91-365d|365+d" data-center-label="Members"></svg>
					<?php endif; ?>
				</div>
			</div>
			<div class="od-widget">
				<div class="od-widget-head"><h3>Members approaching eligibility</h3><span class="od-subline">3-5 credits in 6mo</span></div>
				<div class="od-widget-body">
					<?php if (empty($approaching)): ?><div class="od-empty">No one within reach.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Player</th><th>Credits</th><th>Needs</th></tr></thead>
							<tbody>
							<?php foreach ($approaching as $p): ?>
								<tr>
									<td><a href="<?= UIR ?>Player/profile/<?= (int)$p['MundaneId'] ?>"><?= htmlspecialchars($p['Persona']) ?></a></td>
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
				<div class="od-widget-head"><h3>At risk of losing eligibility</h3><span class="od-subline">Eligible but quiet past 3mo</span></div>
				<div class="od-widget-body">
					<?php if (empty($losing)): ?><div class="od-empty od-empty-ok"><i class="fas fa-check-circle"></i> Eligible members all active.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Player</th><th>6mo</th><th>3mo</th><th>Last</th></tr></thead>
							<tbody>
							<?php foreach ($losing as $p): ?>
								<tr>
									<td><a href="<?= UIR ?>Player/profile/<?= (int)$p['MundaneId'] ?>"><?= htmlspecialchars($p['Persona']) ?></a></td>
									<td><?= (int)$p['Credits6mo'] ?></td>
									<td><?= (int)$p['Credits3mo'] ?></td>
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
				<div class="od-widget-head"><h3>Recent newcomers</h3></div>
				<div class="od-widget-body">
					<?php if (empty($newcomers)): ?><div class="od-empty">No new attendees in the last 30 days.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Player</th><th>First gather</th><th>Visits</th></tr></thead>
							<tbody>
							<?php foreach ($newcomers as $n): ?>
								<tr>
									<td><a href="<?= UIR ?>Player/profile/<?= (int)$n['MundaneId'] ?>"><?= htmlspecialchars($n['Persona']) ?></a></td>
									<td><?= htmlspecialchars($n['FirstAttendance']) ?></td>
									<td><?= (int)$n['VisitCount'] ?></td>
								</tr>
							<?php endforeach; ?>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>
			<div class="od-widget">
				<div class="od-widget-head"><h3>All-time top attendees</h3></div>
				<div class="od-widget-body">
					<?php if (empty($topAttEver)): ?><div class="od-empty">No data.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Player</th><th>Credits</th><th>Last</th></tr></thead>
							<tbody>
							<?php foreach ($topAttEver as $p): ?>
								<tr>
									<td><a href="<?= UIR ?>Player/profile/<?= (int)$p['MundaneId'] ?>"><?= htmlspecialchars($p['Persona']) ?></a></td>
									<td><?= (int)$p['Count'] ?></td>
									<td><?= htmlspecialchars($p['LastDate']) ?></td>
								</tr>
							<?php endforeach; ?>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>
			<div class="od-widget">
				<div class="od-widget-head"><h3>Members who never attended</h3><span class="od-subline">On the roster but no credits</span></div>
				<div class="od-widget-body">
					<?php if (empty($neverAttended)): ?><div class="od-empty od-empty-ok"><i class="fas fa-check-circle"></i> Everyone's engaged.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Player</th><th>Member since</th></tr></thead>
							<tbody>
							<?php foreach ($neverAttended as $n): ?>
								<tr>
									<td><a href="<?= UIR ?>Player/profile/<?= (int)$n['MundaneId'] ?>"><?= htmlspecialchars($n['Persona']) ?></a></td>
									<td><?= htmlspecialchars($n['Since']) ?></td>
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
				<div class="od-widget-head"><h3>Suspended / restricted</h3></div>
				<div class="od-widget-body">
					<?php if (empty($suspendedList)): ?><div class="od-empty od-empty-ok"><i class="fas fa-check-circle"></i> None.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Player</th><th>Status</th><th>Since</th><th>Until</th></tr></thead>
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

<!-- ========= SECTION: OFFICERS ========= -->
<div class="od-section">
	<div class="od-section-head">
		<h3 class="od-section-title"><i class="fas fa-user-shield"></i> Park Officers</h3>
		<i class="fas fa-chevron-down od-section-caret"></i>
	</div>
	<div class="od-section-body">
		<div class="od-widget-row">
			<div class="od-widget od-widget-wide">
				<div class="od-widget-head"><h3>Officer roster</h3></div>
				<div class="od-widget-body">
					<?php if (empty($officers)): ?><div class="od-empty">No officers seated.</div>
					<?php else: ?>
						<table class="od-table od-table-compact">
							<thead><tr><th>Officer</th><th>Role</th><th>Seated</th></tr></thead>
							<tbody>
							<?php foreach ($officers as $o): ?>
								<tr>
									<td><a href="<?= UIR ?>Player/profile/<?= (int)$o['MundaneId'] ?>"><?= htmlspecialchars($o['Persona']) ?></a></td>
									<td><?= htmlspecialchars($o['OfficerRole']) ?></td>
									<td><?= htmlspecialchars($o['Modified'] ? substr($o['Modified'],0,10) : '—') ?></td>
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

<!-- ========= SECTION: ATTENDANCE ========= -->
<div class="od-section">
	<div class="od-section-head">
		<h3 class="od-section-title"><i class="fas fa-chart-line"></i> Attendance</h3>
		<i class="fas fa-chevron-down od-section-caret"></i>
	</div>
	<div class="od-section-body">
		<div class="od-widget-row">
			<div class="od-widget">
				<div class="od-widget-head"><h3>Park attendance trend (12w)</h3></div>
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
				<div class="od-widget-head"><h3>Top attendees (90d)</h3></div>
				<div class="od-widget-body">
					<?php if (empty($topAttendees)): ?><div class="od-empty">No attendance.</div>
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
		</div>

		<div class="od-widget-row">
			<div class="od-widget od-widget-wide">
				<div class="od-widget-head"><h3>Day-of-week × week heatmap</h3><span class="od-subline">Last 12 weeks</span></div>
				<div class="od-widget-body">
					<?php if (empty($dowWeekHeatmap['weeks'])): ?><div class="od-empty">No data.</div>
					<?php else:
						$m = implode(';', array_map(function($r){ return implode(',', $r); }, $dowWeekHeatmap['matrix']));
						$cols = implode('|', array_map(function($w){ return substr($w,5); }, $dowWeekHeatmap['weeks']));
						$rows = implode('|', $dowWeekHeatmap['days']);
					?>
						<svg class="od-chart od-chart-heatmap" data-matrix="<?= $m ?>" data-cols="<?= $cols ?>" data-rows="<?= $rows ?>"></svg>
					<?php endif; ?>
				</div>
			</div>
		</div>
	</div>
</div>

<!-- ========= SECTION: EVENTS & PARK DAYS ========= -->
<div class="od-section">
	<div class="od-section-head">
		<h3 class="od-section-title"><i class="fas fa-calendar-alt"></i> Events &amp; Park Days</h3>
		<i class="fas fa-chevron-down od-section-caret"></i>
	</div>
	<div class="od-section-body">
		<div class="od-widget-row">
			<div class="od-widget">
				<div class="od-widget-head"><h3>Recurring park days</h3></div>
				<div class="od-widget-body">
					<?php if (empty($parkdays)): ?><div class="od-empty">No park days scheduled.</div>
					<?php else: ?>
						<table class="od-table od-table-compact">
							<thead><tr><th>When</th><th>Purpose</th><th>Description</th></tr></thead>
							<tbody>
							<?php foreach ($parkdays as $pd):
								$when = htmlspecialchars($pd['WeekDay']);
								if ($pd['Recurrence'] === 'week-of-month' && $pd['WeekOfMonth']) $when = $pd['WeekOfMonth'].' '.$when;
								if ($pd['Time']) $when .= ' @ '.substr($pd['Time'],0,5);
							?>
								<tr>
									<td><?= $when ?></td>
									<td><?= htmlspecialchars($pd['Purpose']) ?></td>
									<td><?= htmlspecialchars($pd['Description']) ?></td>
								</tr>
							<?php endforeach; ?>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>
			<div class="od-widget">
				<div class="od-widget-head"><h3>Upcoming events</h3></div>
				<div class="od-widget-body">
					<?php if (empty($upcomingEvents)): ?><div class="od-empty">No scheduled events.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Event</th><th>Date</th></tr></thead>
							<tbody>
							<?php foreach ($upcomingEvents as $e): ?>
								<tr>
									<td><?= htmlspecialchars($e['Name']) ?></td>
									<td><?= htmlspecialchars(substr($e['StartDate'],0,10)) ?></td>
								</tr>
							<?php endforeach; ?>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>
			<div class="od-widget">
				<div class="od-widget-head"><h3>Upcoming tournaments</h3></div>
				<div class="od-widget-body">
					<?php if (empty($upcomingTourn)): ?><div class="od-empty">No upcoming tournaments.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Tournament</th><th>Date</th></tr></thead>
							<tbody>
							<?php foreach ($upcomingTourn as $t): ?>
								<tr>
									<td><?= htmlspecialchars($t['Name']) ?></td>
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

<!-- ========= SECTION: DEADLINES ========= -->
<div class="od-section">
	<div class="od-section-head">
		<h3 class="od-section-title"><i class="fas fa-calendar-check"></i> Deadlines</h3>
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
				<div class="od-widget-head"><h3>Pending waivers</h3></div>
				<div class="od-widget-body">
					<?php if (empty($pendingWaivers)): ?><div class="od-empty od-empty-ok"><i class="fas fa-check-circle"></i> Nothing pending.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Signer</th><th>Signed</th></tr></thead>
							<tbody>
							<?php foreach ($pendingWaivers as $w): ?>
								<tr>
									<td><a href="<?= UIR ?>Player/profile/<?= (int)$w['MundaneId'] ?>"><?= htmlspecialchars($w['Persona']) ?></a></td>
									<td><?= htmlspecialchars($w['SignedAt']) ?></td>
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

<!-- ========= SECTION: QUICK ACTIONS ========= -->
<div class="od-section">
	<div class="od-section-head">
		<h3 class="od-section-title"><i class="fas fa-bolt"></i> Quick Actions</h3>
		<i class="fas fa-chevron-down od-section-caret"></i>
	</div>
	<div class="od-section-body">
		<div class="od-widget-row">
			<div class="od-widget od-widget-wide">
				<div class="od-widget-head"><h3>Jump to</h3></div>
				<div class="od-widget-body">
					<div class="od-links-grid">
						<a class="od-link-card" href="<?= UIR ?>Attendance/index"><i class="fas fa-clipboard-check"></i><span>Take attendance</span></a>
						<a class="od-link-card" href="<?= UIR ?>Member/new"><i class="fas fa-user-plus"></i><span>Add a member</span></a>
						<a class="od-link-card" href="<?= UIR ?>Reports/voting/<?= (int)($kingdom_id ?? 0) ?>"><i class="fas fa-vote-yea"></i><span>Voting eligibility</span></a>
						<a class="od-link-card" href="<?= UIR ?>Reports/attendance/<?= (int)($kingdom_id ?? 0) ?>"><i class="fas fa-chart-line"></i><span>Kingdom attendance</span></a>
						<a class="od-link-card" href="<?= UIR ?>Park/profile/<?= (int)$park_id ?>"><i class="fas fa-map-marked-alt"></i><span>Park profile</span></a>
						<a class="od-link-card" href="<?= UIR ?>Admin/park/<?= (int)$park_id ?>"><i class="fas fa-cog"></i><span>Park admin</span></a>
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
				<div class="od-widget-head"><h3>Recently modified records</h3><span class="od-subline">Last 30d</span></div>
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
