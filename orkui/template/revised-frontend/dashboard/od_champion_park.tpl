<?php
	// Champion × Park dashboard
	$tourneys            = $ocData['tournaments'] ?? [];
	$recentTourneys      = $ocData['recentTourneys'] ?? [];
	$knightsInPark       = (int)($ocData['knightsInPark'] ?? 0);
	$knightsByOrder      = $ocData['knightsByOrder'] ?? [];
	$knightCandidates    = $ocData['knightCandidates'] ?? [];
	$tourneysByMonth     = $ocData['tourneysByMonth'] ?? [];
	$fighterRoster       = $ocData['fighterRoster'] ?? [];
	$dayOfWeek           = $ocData['dayOfWeek'] ?? [];
	$attendanceHeatmap   = $ocData['attendanceHeatmap'] ?? ['rows'=>[], 'rowLabels'=>[], 'colLabels'=>[]];
	$newcomerFighters    = $ocData['newcomerFighters'] ?? [];
	$peerageMix          = $ocData['peerageMix'] ?? [];
	$warriorLadder       = $ocData['warriorLadder'] ?? [];
	$martialAwardsRecent = $ocData['martialAwardsRecent'] ?? [];
	$tourneyCounts       = $ocData['tourneyCounts'] ?? ['Past'=>0,'Upcoming'=>0,'Recent90'=>0];
	$topAttendees        = $ocData['topAttendees'] ?? [];
	$attendanceTrend     = $ocData['attendanceTrend'] ?? [];
	$upE                 = $ocData['upcomingEvents'] ?? [];
	$activeFighters      = (int)($ocData['activeFighters'] ?? 0);
	$recentTourneyCount  = (int)($ocData['recentTourneyCount'] ?? 0);

	$matrixToAttr = function($rows) {
		return implode(';', array_map(function($r) { return implode(',', array_map('intval', $r)); }, $rows));
	};
?>
		<!-- At-a-glance -->
		<div class="od-grid">
			<div class="od-stat-card"><div class="od-stat-num"><?= $activeFighters ?></div><div class="od-stat-lbl">Active fighters (90d)</div></div>
			<div class="od-stat-card"><div class="od-stat-num"><?= (int)count($tourneys) ?></div><div class="od-stat-lbl">Upcoming tourneys</div></div>
			<div class="od-stat-card"><div class="od-stat-num"><?= $recentTourneyCount ?></div><div class="od-stat-lbl">Tourneys (90d)</div></div>
			<div class="od-stat-card"><div class="od-stat-num"><?= $knightsInPark ?></div><div class="od-stat-lbl">Knights at park</div></div>
			<div class="od-stat-card"><div class="od-stat-num"><?= (int)count($knightCandidates) ?></div><div class="od-stat-lbl">Knight candidates</div></div>
			<div class="od-stat-card"><div class="od-stat-num"><?= (int)count($newcomerFighters) ?></div><div class="od-stat-lbl">New fighters (60d)</div></div>
		</div>

		<!-- ============================================================ -->
		<!-- SECTION 1: Fighters -->
		<!-- ============================================================ -->
		<div class="od-section">
			<div class="od-section-head">
				<h3 class="od-section-title"><i class="fas fa-running"></i> Fighters</h3>
				<i class="fas fa-chevron-down od-section-caret"></i>
			</div>
			<div class="od-section-body">
				<div class="od-widget-row">
					<div class="od-widget od-widget-wide">
						<div class="od-widget-head"><h3>Park Fighter Roster (90d)</h3>
							<span class="od-subline">Sorted by attendance credits</span>
						</div>
						<div class="od-widget-body">
							<?php if (empty($fighterRoster)): ?><div class="od-empty">No attendance recorded in the last 90 days.</div>
							<?php else: ?>
								<table class="od-table od-table-compact" data-od-paginate="10">
									<thead><tr><th>Player</th><th>Credits</th><th>First seen (90d)</th><th>Last seen</th></tr></thead>
									<tbody>
									<?php foreach ($fighterRoster as $f): ?>
										<tr>
											<td><a href="<?= UIR ?>Player/profile/<?= (int)$f['MundaneId'] ?>"><?= htmlspecialchars($f['Persona']) ?></a></td>
											<td><?= (int)$f['Credits'] ?></td>
											<td><?= htmlspecialchars($f['FirstSeen']) ?></td>
											<td><?= htmlspecialchars($f['LastSeen']) ?></td>
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
							<?php if (empty($topAttendees)): ?><div class="od-empty">No attendance.</div>
							<?php else: ?>
								<table class="od-table od-table-compact" data-od-paginate="5">
									<thead><tr><th>Player</th><th>Credits</th></tr></thead>
									<tbody>
									<?php foreach ($topAttendees as $p): ?>
										<tr><td><a href="<?= UIR ?>Player/profile/<?= (int)($p['MundaneId'] ?? 0) ?>"><?= htmlspecialchars($p['Persona'] ?? '—') ?></a></td>
											<td><?= (int)($p['AttendCount'] ?? 0) ?></td></tr>
									<?php endforeach; ?>
									</tbody>
								</table>
							<?php endif; ?>
						</div>
					</div>

					<div class="od-widget">
						<div class="od-widget-head"><h3>New Fighters (60d)</h3><span class="od-subline">First-ever attendance at this park</span></div>
						<div class="od-widget-body">
							<?php if (empty($newcomerFighters)): ?><div class="od-empty">No new fighters recently.</div>
							<?php else: ?>
								<table class="od-table od-table-compact" data-od-paginate="5">
									<thead><tr><th>Player</th><th>First seen</th><th>Credits</th></tr></thead>
									<tbody>
									<?php foreach ($newcomerFighters as $n): ?>
										<tr>
											<td><a href="<?= UIR ?>Player/profile/<?= (int)$n['MundaneId'] ?>"><?= htmlspecialchars($n['Persona']) ?></a></td>
											<td><?= htmlspecialchars($n['FirstSeen']) ?></td>
											<td><?= (int)$n['Credits'] ?></td>
										</tr>
									<?php endforeach; ?>
									</tbody>
								</table>
							<?php endif; ?>
						</div>
					</div>

					<div class="od-widget">
						<div class="od-widget-head"><h3>Practice Trend (12w)</h3></div>
						<div class="od-widget-body">
							<?php if (empty($attendanceTrend)): ?><div class="od-empty">No data.</div>
							<?php else:
								$vals = array_map(function($w){ return (int)($w['UniquePlayers'] ?? 0); }, $attendanceTrend);
							?>
								<svg class="od-spark" viewBox="0 0 240 48" preserveAspectRatio="none"
									data-values="<?= htmlspecialchars(implode(',', $vals)) ?>"></svg>
								<div style="display:flex;justify-content:space-between;font-size:11px;color:#888;margin-top:4px;">
									<span><?= htmlspecialchars($attendanceTrend[0]['WeekStart'] ?? '') ?></span>
									<span>Peak: <?= max($vals) ?></span>
									<span><?= htmlspecialchars(end($attendanceTrend)['WeekStart'] ?? '') ?></span>
								</div>
							<?php endif; ?>
						</div>
					</div>
				</div>

				<div class="od-widget-row">
					<div class="od-widget">
						<div class="od-widget-head"><h3>Practice by Day of Week</h3></div>
						<div class="od-widget-body">
							<?php if (empty($dayOfWeek)): ?><div class="od-empty">No data.</div>
							<?php else:
								$vals = array_map(function($r){ return (int)$r['Count']; }, $dayOfWeek);
								$lbls = array_map(function($r){ return $r['Day']; }, $dayOfWeek);
							?>
								<svg class="od-chart od-chart-bar"
									data-values="<?= htmlspecialchars(implode(',',$vals)) ?>"
									data-labels="<?= htmlspecialchars(implode('|',$lbls)) ?>"></svg>
							<?php endif; ?>
						</div>
					</div>

					<div class="od-widget od-widget-wide">
						<div class="od-widget-head"><h3>Practice Attendance Heatmap (DOW × weeks)</h3></div>
						<div class="od-widget-body">
							<?php if (empty($attendanceHeatmap['rows'])): ?><div class="od-empty">No attendance in the last 10 weeks.</div>
							<?php else: ?>
								<svg class="od-chart od-chart-heatmap"
									data-matrix="<?= htmlspecialchars($matrixToAttr($attendanceHeatmap['rows'])) ?>"
									data-rows="<?= htmlspecialchars(implode('|', $attendanceHeatmap['rowLabels'])) ?>"
									data-cols="<?= htmlspecialchars(implode('|', $attendanceHeatmap['colLabels'])) ?>"></svg>
							<?php endif; ?>
						</div>
					</div>
				</div>
			</div>
		</div>

		<!-- ============================================================ -->
		<!-- SECTION 2: Tournaments -->
		<!-- ============================================================ -->
		<div class="od-section">
			<div class="od-section-head">
				<h3 class="od-section-title"><i class="fas fa-trophy"></i> Tournaments</h3>
				<i class="fas fa-chevron-down od-section-caret"></i>
			</div>
			<div class="od-section-body">
				<div class="od-widget-row">
					<div class="od-widget">
						<div class="od-widget-head"><h3>Upcoming Park Tourneys</h3></div>
						<div class="od-widget-body">
							<?php if (empty($tourneys)): ?><div class="od-empty">None on calendar.</div>
							<?php else: ?>
								<table class="od-table od-table-compact" data-od-paginate="5">
									<thead><tr><th>Tournament</th><th>Date</th></tr></thead>
									<tbody>
										<?php foreach ($tourneys as $t): ?>
											<tr><td><?= htmlspecialchars($t['Name'] ?? '—') ?></td><td><?= htmlspecialchars(substr($t['Date'] ?? '',0,10)) ?></td></tr>
										<?php endforeach; ?>
									</tbody>
								</table>
							<?php endif; ?>
						</div>
					</div>

					<div class="od-widget">
						<div class="od-widget-head"><h3>Past Tourneys</h3></div>
						<div class="od-widget-body">
							<?php if (empty($recentTourneys)): ?><div class="od-empty">No historical tourneys logged.</div>
							<?php else: ?>
								<table class="od-table od-table-compact" data-od-paginate="5">
									<thead><tr><th>Tournament</th><th>Date</th><th>Status</th></tr></thead>
									<tbody>
										<?php foreach ($recentTourneys as $t): ?>
											<tr><td><?= htmlspecialchars($t['Name']) ?></td>
												<td><?= htmlspecialchars($t['Date']) ?></td>
												<td><span class="od-badge"><?= htmlspecialchars($t['Status']) ?></span></td></tr>
										<?php endforeach; ?>
									</tbody>
								</table>
							<?php endif; ?>
						</div>
					</div>

					<div class="od-widget">
						<div class="od-widget-head"><h3>Tourney Counts</h3></div>
						<div class="od-widget-body">
							<?php
								$tcVals = [(int)$tourneyCounts['Upcoming'], (int)$tourneyCounts['Recent90'], max(0, (int)$tourneyCounts['Past'] - (int)$tourneyCounts['Recent90'])];
								$tcLbls = ['Upcoming','Recent (90d)','Older'];
							?>
							<svg class="od-chart od-chart-donut"
								data-values="<?= htmlspecialchars(implode(',',$tcVals)) ?>"
								data-labels="<?= htmlspecialchars(implode('|',$tcLbls)) ?>"
								data-center-label="Tourneys"></svg>
						</div>
					</div>
				</div>

				<div class="od-widget-row">
					<div class="od-widget od-widget-wide">
						<div class="od-widget-head"><h3>Tournaments by Month (12 mo)</h3></div>
						<div class="od-widget-body">
							<?php if (empty($tourneysByMonth)): ?><div class="od-empty">No data.</div>
							<?php else:
								$vals = array_map(function($r){ return (int)$r['Count']; }, $tourneysByMonth);
								$lbls = array_map(function($r){ return substr($r['Month'],5); }, $tourneysByMonth);
							?>
								<svg class="od-chart od-chart-bar"
									data-values="<?= htmlspecialchars(implode(',',$vals)) ?>"
									data-labels="<?= htmlspecialchars(implode('|',$lbls)) ?>"></svg>
							<?php endif; ?>
						</div>
					</div>
				</div>
			</div>
		</div>

		<!-- ============================================================ -->
		<!-- SECTION 3: Knighting & peerage -->
		<!-- ============================================================ -->
		<div class="od-section">
			<div class="od-section-head">
				<h3 class="od-section-title"><i class="fas fa-shield-alt"></i> Knighting &amp; Peerage</h3>
				<i class="fas fa-chevron-down od-section-caret"></i>
			</div>
			<div class="od-section-body">
				<div class="od-widget-row">
					<div class="od-widget">
						<div class="od-widget-head"><h3>Knights by Order (Park)</h3></div>
						<div class="od-widget-body">
							<?php if (empty($knightsByOrder)): ?><div class="od-empty">No knights at this park.</div>
							<?php else:
								$vals = array_map(function($r){ return (int)$r['Count']; }, $knightsByOrder);
								$lbls = array_map(function($r){ return str_replace('Knight of the ', '', $r['Name']); }, $knightsByOrder);
							?>
								<svg class="od-chart od-chart-donut"
									data-values="<?= htmlspecialchars(implode(',',$vals)) ?>"
									data-labels="<?= htmlspecialchars(implode('|',$lbls)) ?>"
									data-center-label="Knights"></svg>
							<?php endif; ?>
						</div>
					</div>

					<div class="od-widget">
						<div class="od-widget-head"><h3>Peerage Mix (Park)</h3></div>
						<div class="od-widget-body">
							<?php if (empty($peerageMix)): ?><div class="od-empty">No peerage data.</div>
							<?php else:
								$vals = array_map(function($r){ return (int)$r['Count']; }, $peerageMix);
								$lbls = array_map(function($r){ return $r['Peerage']; }, $peerageMix);
							?>
								<svg class="od-chart od-chart-pie"
									data-values="<?= htmlspecialchars(implode(',',$vals)) ?>"
									data-labels="<?= htmlspecialchars(implode('|',$lbls)) ?>"></svg>
							<?php endif; ?>
						</div>
					</div>

					<div class="od-widget">
						<div class="od-widget-head"><h3>Order of the Warrior</h3></div>
						<div class="od-widget-body">
							<?php if (empty($warriorLadder)): ?><div class="od-empty">No ladder entries.</div>
							<?php else:
								$buckets = array_fill(1, 10, 0);
								foreach ($warriorLadder as $r) { $rk = (int)$r['Rank']; if ($rk >= 1 && $rk <= 10) $buckets[$rk] = (int)$r['Count']; }
								$vals = array_values($buckets);
								$lbls = ['1','2','3','4','5','6','7','8','9','10'];
							?>
								<svg class="od-chart od-chart-bar"
									data-values="<?= htmlspecialchars(implode(',',$vals)) ?>"
									data-labels="<?= htmlspecialchars(implode('|',$lbls)) ?>"></svg>
							<?php endif; ?>
						</div>
					</div>
				</div>

				<div class="od-widget-row">
					<div class="od-widget od-widget-wide">
						<div class="od-widget-head"><h3>Local Knight Candidates</h3></div>
						<div class="od-widget-body">
							<?php if (empty($knightCandidates)): ?><div class="od-empty">No candidates at this park.</div>
							<?php else: ?>
								<table class="od-table od-table-compact" data-od-paginate="6">
									<thead><tr><th>Player</th><th>Tracks held</th><th>Last track awarded</th></tr></thead>
									<tbody>
									<?php foreach ($knightCandidates as $c): ?>
										<tr>
											<td><a href="<?= UIR ?>Player/profile/<?= (int)$c['MundaneId'] ?>"><?= htmlspecialchars($c['Persona']) ?></a></td>
											<td><?= htmlspecialchars($c['Tracks'] ?? '—') ?></td>
											<td><?= htmlspecialchars($c['LastDate']) ?></td>
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
						<div class="od-widget-head"><h3>Recent Martial Awards</h3></div>
						<div class="od-widget-body">
							<?php if (empty($martialAwardsRecent)): ?><div class="od-empty">No martial awards in last 12 months.</div>
							<?php else: ?>
								<table class="od-table od-table-compact" data-od-paginate="6">
									<thead><tr><th>Date</th><th>Player</th><th>Award</th><th>Rank</th></tr></thead>
									<tbody>
									<?php foreach ($martialAwardsRecent as $m): ?>
										<tr>
											<td><?= htmlspecialchars($m['Date']) ?></td>
											<td><a href="<?= UIR ?>Player/profile/<?= (int)$m['MundaneId'] ?>"><?= htmlspecialchars($m['Persona']) ?></a></td>
											<td><?= htmlspecialchars($m['Award']) ?></td>
											<td><?= ((int)$m['Rank']) > 0 ? (int)$m['Rank'] : '—' ?></td>
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

		<!-- ============================================================ -->
		<!-- SECTION 4: Events -->
		<!-- ============================================================ -->
		<div class="od-section">
			<div class="od-section-head">
				<h3 class="od-section-title"><i class="fas fa-calendar-alt"></i> Events &amp; Practice</h3>
				<i class="fas fa-chevron-down od-section-caret"></i>
			</div>
			<div class="od-section-body">
				<div class="od-widget-row">
					<div class="od-widget od-widget-wide">
						<div class="od-widget-head"><h3>Upcoming Park Events</h3></div>
						<div class="od-widget-body">
							<?php if (empty($upE)): ?><div class="od-empty">None.</div>
							<?php else: ?>
								<table class="od-table od-table-compact" data-od-paginate="5">
									<thead><tr><th>Event</th><th>Date</th></tr></thead>
									<tbody>
									<?php foreach ($upE as $e): ?>
										<tr><td><?= htmlspecialchars($e['Name'] ?? '—') ?></td>
											<td><?= htmlspecialchars(substr($e['StartDate'] ?? '',0,10)) ?></td></tr>
									<?php endforeach; ?>
									</tbody>
								</table>
							<?php endif; ?>
						</div>
					</div>
				</div>

				<div class="od-widget-row">
					<div class="od-widget od-widget-soon">
						<div class="od-widget-head"><h3>Battle Games</h3></div>
						<div class="od-widget-body"><ul class="od-soon-list"><li><i class="fas fa-fist-raised"></i> Battle-game schedule &amp; log — coming soon.</li></ul></div>
					</div>
					<div class="od-widget od-widget-soon">
						<div class="od-widget-head"><h3>Weapon-check Log</h3></div>
						<div class="od-widget-body"><ul class="od-soon-list"><li><i class="fas fa-clipboard-check"></i> Per-fighter weapon-check records — coming soon.</li></ul></div>
					</div>
					<div class="od-widget od-widget-soon">
						<div class="od-widget-head"><h3>Loaner Gear</h3></div>
						<div class="od-widget-body"><ul class="od-soon-list"><li><i class="fas fa-box"></i> Loaner inventory &amp; check-out — coming soon.</li></ul></div>
					</div>
				</div>
			</div>
		</div>

		<!-- ============================================================ -->
		<!-- SECTION 5: Quick actions + tools -->
		<!-- ============================================================ -->
		<div class="od-section">
			<div class="od-section-head">
				<h3 class="od-section-title"><i class="fas fa-bolt"></i> Quick Actions</h3>
				<i class="fas fa-chevron-down od-section-caret"></i>
			</div>
			<div class="od-section-body">
				<div class="od-widget-row">
					<div class="od-widget od-widget-wide">
						<div class="od-widget-head"><h3>Park Champion Actions</h3></div>
						<div class="od-widget-body">
							<div class="od-links-grid">
								<a class="od-link-card" href="<?= UIR ?>Park/enterattendance/<?= (int)$park_id ?>"><i class="fas fa-check-square"></i><span>Record practice</span></a>
								<a class="od-link-card" href="<?= UIR ?>Tournametnew"><i class="fas fa-plus-circle"></i><span>Schedule tourney</span></a>
								<a class="od-link-card" href="<?= UIR ?>Park/profile/<?= (int)$park_id ?>"><i class="fas fa-map-marker-alt"></i><span>Park profile</span></a>
								<a class="od-link-card" href="<?= UIR ?>Reports/attendance/<?= (int)$park_id ?>"><i class="fas fa-running"></i><span>Attendance report</span></a>
							</div>
						</div>
					</div>
				</div>
			</div>
		</div>

		<div class="od-section od-section-closed">
			<div class="od-section-head">
				<h3 class="od-section-title"><i class="fas fa-book"></i> Tools &amp; References</h3>
				<i class="fas fa-chevron-down od-section-caret"></i>
			</div>
			<div class="od-section-body">
				<div class="od-widget-row">
					<div class="od-widget od-widget-wide">
						<div class="od-widget-head"><h3>Park Champion References</h3></div>
						<div class="od-widget-body">
							<div class="od-links-grid">
								<a class="od-link-card" href="https://amtgard.com/rules/" target="_blank" rel="noopener"><i class="fas fa-gavel"></i><span>Rules of Play</span></a>
								<a class="od-link-card" href="https://amtgard.com/doku/doku.php?id=category:weapon_specs" target="_blank" rel="noopener"><i class="fas fa-clipboard-check"></i><span>Weapon-check procedure</span></a>
								<a class="od-link-card" href="https://amtgard.com/doku/doku.php?id=category:champion" target="_blank" rel="noopener"><i class="fas fa-user-shield"></i><span>Champion handbook</span></a>
							</div>
						</div>
					</div>
				</div>
			</div>
		</div>
