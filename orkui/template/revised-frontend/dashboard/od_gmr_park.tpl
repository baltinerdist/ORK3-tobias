<?php
	$parkReeves       = (int)($ocData['parkReeveCount']    ?? 0);
	$parkActiveReeves = (int)($ocData['parkActiveReeves']  ?? 0);
	$roster           = $ocData['parkReeveRoster']         ?? [];
	$recentAwards     = $ocData['parkRecentReeveAwd']      ?? [];
	$upcomingEvents   = $ocData['parkUpcomingEvents']      ?? [];
	$upcomingTourneys = $ocData['parkUpcomingTourneys']    ?? [];
	$attTrend         = $ocData['parkAttendanceTrend']     ?? [];
	$officers         = $ocData['officers']                ?? [];

	$engagementPct = $parkReeves > 0 ? (int)round(($parkActiveReeves / $parkReeves) * 100) : 0;

	// Count upcoming events+tournaments in next 30 days as a "reeves needed" hint.
	$in30 = 0; $cutoff = strtotime('+30 days');
	foreach ($upcomingEvents as $e) { if (!empty($e['StartDate']) && strtotime($e['StartDate']) <= $cutoff) { $in30++; } }
	foreach ($upcomingTourneys as $t) { if (!empty($t['DateTime']) && strtotime($t['DateTime']) <= $cutoff) { $in30++; } }

	$currentGmr = null;
	foreach ($officers as $o) { if (($o['OfficerRole'] ?? '') === 'GMR') { $currentGmr = $o; break; } }
?>
		<div class="od-grid">
			<div class="od-stat-card"><div class="od-stat-num"><?= $parkReeves ?></div><div class="od-stat-lbl">Park reeves <span class="od-subline" style="font-size:10px">(proxy)</span></div></div>
			<div class="od-stat-card"><div class="od-stat-num"><?= $parkActiveReeves ?></div><div class="od-stat-lbl">Active reeves (90d)</div></div>
			<div class="od-stat-card"><div class="od-stat-num"><?= $engagementPct ?>%</div><div class="od-stat-lbl">Engagement rate</div></div>
			<div class="od-stat-card"><div class="od-stat-num"><?= $in30 ?></div><div class="od-stat-lbl">Events/tournaments next 30d</div></div>
		</div>

		<!-- ====== Section 1: Park Reeves ====== -->
		<div class="od-section">
			<div class="od-section-head">
				<h3 class="od-section-title"><i class="fas fa-users"></i> Park Reeves</h3>
				<i class="fas fa-chevron-down od-section-caret"></i>
			</div>
			<div class="od-section-body">
				<div class="od-widget-row">
					<div class="od-widget">
						<div class="od-widget-head"><h3>Reeve Engagement</h3></div>
						<div class="od-widget-body">
							<svg class="od-chart od-chart-ring"
							     data-value="<?= $engagementPct ?>"
							     data-max="100"
							     data-display="<?= $engagementPct ?>%"
							     data-label="Active / Qualified"></svg>
							<div style="text-align:center;font-size:12px;color:#666;margin-top:4px;">
								<?= $parkActiveReeves ?> of <?= $parkReeves ?> attended in 90 days
							</div>
						</div>
					</div>
					<div class="od-widget">
						<div class="od-widget-head"><h3>Seated Park GMR</h3></div>
						<div class="od-widget-body">
							<?php if ($currentGmr): ?>
								<div style="text-align:center;padding:18px 0;">
									<div style="font-size:16px;font-weight:600;">
										<a href="<?= UIR ?>Player/profile/<?= (int)$currentGmr['MundaneId'] ?>"><?= htmlspecialchars($currentGmr['Persona'] ?? '—') ?></a>
									</div>
									<div class="od-subline" style="font-size:12px;margin-top:4px;">
										Seated since <?= isset($currentGmr['Modified']) && strpos((string)$currentGmr['Modified'],'0000-00-00') === false ? htmlspecialchars(substr((string)$currentGmr['Modified'], 0, 10)) : '—' ?>
									</div>
									<div style="margin-top:10px;"><span class="od-pill od-pill-ok">SEATED</span></div>
								</div>
							<?php else: ?>
								<div class="od-empty"><i class="fas fa-exclamation-triangle"></i> No Park GMR seated.</div>
							<?php endif; ?>
						</div>
					</div>
					<div class="od-widget">
						<div class="od-widget-head"><h3>Park Attendance (12w)</h3><span class="od-subline">Proxy for reeve activity</span></div>
						<div class="od-widget-body">
							<?php if (empty($attTrend)): ?>
								<div class="od-empty">No attendance data.</div>
							<?php else: $vals = array_map(function($w){ return (int)($w['UniquePlayers'] ?? 0); }, $attTrend); ?>
								<svg class="od-spark" viewBox="0 0 240 48" preserveAspectRatio="none" data-values="<?= htmlspecialchars(implode(',', $vals)) ?>"></svg>
								<div style="display:flex;justify-content:space-between;font-size:11px;color:#888;margin-top:4px;">
									<span><?= htmlspecialchars($attTrend[0]['WeekStart'] ?? '') ?></span>
									<span>Peak: <?= max($vals) ?></span>
									<span><?= htmlspecialchars(end($attTrend)['WeekStart'] ?? '') ?></span>
								</div>
							<?php endif; ?>
						</div>
					</div>
				</div>

				<div class="od-widget-row">
					<div class="od-widget od-widget-wide">
						<div class="od-widget-head">
							<h3>Park Reeve Roster</h3>
							<a class="od-link" href="<?= UIR ?>Reports/reeve/<?= (int)($kingdom_id ?? 0) ?>">Full reeve report<i class="fas fa-arrow-right"></i></a>
						</div>
						<div class="od-widget-body">
							<?php if (empty($roster)): ?>
								<div class="od-empty">No reeve-qualified players found at this park. (Proxy: awards matching "Reeve".)</div>
							<?php else: ?>
								<p class="od-subline" style="margin:0 0 8px 0;font-size:11px;color:#888;font-style:italic;">Proxy: home-park players holding any kingdom award matching "Reeve".</p>
								<table class="od-table od-table-compact" data-od-paginate="8">
									<thead><tr><th>Player</th><th>Most recent reeve award</th><th>Awarded</th><th>Last seen at park</th></tr></thead>
									<tbody>
									<?php foreach ($roster as $r): ?>
										<tr>
											<td><a href="<?= UIR ?>Player/profile/<?= (int)$r['MundaneId'] ?>"><?= htmlspecialchars($r['Persona'] ?? '—') ?></a></td>
											<td><?= htmlspecialchars($r['AwardName'] ?? '—') ?></td>
											<td><?= htmlspecialchars($r['LastAwardDate']) ?></td>
											<td><?= htmlspecialchars($r['LastAttendance']) ?></td>
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

		<!-- ====== Section 2: Event Coverage ====== -->
		<div class="od-section">
			<div class="od-section-head">
				<h3 class="od-section-title"><i class="fas fa-calendar-check"></i> Event &amp; Tournament Coverage</h3>
				<i class="fas fa-chevron-down od-section-caret"></i>
			</div>
			<div class="od-section-body">
				<div class="od-widget-row">
					<div class="od-widget">
						<div class="od-widget-head"><h3>Upcoming Park Events</h3></div>
						<div class="od-widget-body">
							<?php if (empty($upcomingEvents)): ?>
								<div class="od-empty">No scheduled park events.</div>
							<?php else: ?>
								<table class="od-table od-table-compact" data-od-paginate="5">
									<thead><tr><th>Event</th><th>Start</th></tr></thead>
									<tbody>
									<?php foreach ($upcomingEvents as $e): ?>
										<tr>
											<td><?= htmlspecialchars($e['Name'] ?? '—') ?></td>
											<td><?= htmlspecialchars(substr($e['StartDate'] ?? '', 0, 10)) ?></td>
										</tr>
									<?php endforeach; ?>
									</tbody>
								</table>
							<?php endif; ?>
						</div>
					</div>
					<div class="od-widget">
						<div class="od-widget-head"><h3>Upcoming Park Tournaments</h3></div>
						<div class="od-widget-body">
							<?php if (empty($upcomingTourneys)): ?>
								<div class="od-empty">No scheduled tournaments.</div>
							<?php else: ?>
								<table class="od-table od-table-compact" data-od-paginate="5">
									<thead><tr><th>Tournament</th><th>When</th><th>Status</th></tr></thead>
									<tbody>
									<?php foreach ($upcomingTourneys as $t): ?>
										<tr>
											<td><?= htmlspecialchars($t['Name'] ?? '—') ?></td>
											<td><?= htmlspecialchars(substr($t['DateTime'] ?? '', 0, 10)) ?></td>
											<td><span class="od-pill"><?= htmlspecialchars($t['Status'] ?? '—') ?></span></td>
										</tr>
									<?php endforeach; ?>
									</tbody>
								</table>
							<?php endif; ?>
						</div>
					</div>
				</div>

				<div class="od-widget-row">
					<div class="od-widget od-widget-soon">
						<div class="od-widget-head"><h3>Event Reeve Coverage Status</h3></div>
						<div class="od-widget-body">
							<p class="od-subline" style="font-size:12px;">Coming soon: ratio of confirmed reeves to expected entrants per upcoming park event. Flags any event with fewer than 1 reeve per 8 fighters as at-risk.</p>
						</div>
					</div>
					<div class="od-widget od-widget-soon">
						<div class="od-widget-head"><h3>Next Gather Reeve Need</h3></div>
						<div class="od-widget-body">
							<p class="od-subline" style="font-size:12px;">Coming soon: at-a-glance "how many reeves are we short for next park day?" meter with signup link. Needs a weekly reeve signup workflow.</p>
						</div>
					</div>
				</div>
			</div>
		</div>

		<!-- ====== Section 3: Recent Activity ====== -->
		<div class="od-section">
			<div class="od-section-head">
				<h3 class="od-section-title"><i class="fas fa-medal"></i> Recent Reeve Activity</h3>
				<i class="fas fa-chevron-down od-section-caret"></i>
			</div>
			<div class="od-section-body">
				<div class="od-widget-row">
					<div class="od-widget od-widget-wide">
						<div class="od-widget-head"><h3>Recent Reeve Awards (Park)</h3></div>
						<div class="od-widget-body">
							<?php if (empty($recentAwards)): ?>
								<div class="od-empty">No recent reeve awards.</div>
							<?php else: ?>
								<table class="od-table od-table-compact" data-od-paginate="6">
									<thead><tr><th>Player</th><th>Award</th><th>Date</th></tr></thead>
									<tbody>
									<?php foreach ($recentAwards as $a): ?>
										<tr>
											<td><a href="<?= UIR ?>Player/profile/<?= (int)$a['MundaneId'] ?>"><?= htmlspecialchars($a['Persona'] ?? '—') ?></a></td>
											<td><?= htmlspecialchars($a['Award'] ?? '—') ?></td>
											<td><?= htmlspecialchars($a['Date']) ?></td>
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

		<!-- ====== Section 4: Rulings & Reporting (stubs) ====== -->
		<div class="od-section od-section-closed">
			<div class="od-section-head">
				<h3 class="od-section-title"><i class="fas fa-gavel"></i> Rulings &amp; Reporting</h3>
				<i class="fas fa-chevron-down od-section-caret"></i>
			</div>
			<div class="od-section-body">
				<div class="od-widget-row">
					<div class="od-widget od-widget-soon">
						<div class="od-widget-head"><h3>Recent Rulings at Park</h3></div>
						<div class="od-widget-body">
							<p class="od-subline" style="font-size:12px;">Coming soon: rulings issued at this park (by Park GMR or visiting Kingdom GMR) with affected rule section. Backed by future <code>ork_ruling</code> schema.</p>
						</div>
					</div>
					<div class="od-widget od-widget-soon">
						<div class="od-widget-head"><h3>Park Incident Log</h3></div>
						<div class="od-widget-body">
							<p class="od-subline" style="font-size:12px;">Coming soon: park-scoped safety / conduct incidents with follow-up status. Visible only to appropriate officer scope.</p>
						</div>
					</div>
					<div class="od-widget od-widget-soon">
						<div class="od-widget-head"><h3>Cert-List Submission</h3></div>
						<div class="od-widget-body">
							<svg class="od-chart od-chart-ring" data-value="0" data-max="100" data-display="—" data-label="Submitted"></svg>
							<p class="od-subline" style="font-size:12px;text-align:center;margin-top:4px;">Coming soon: quarterly park-reeve cert list submission status to Kingdom GMR.</p>
						</div>
					</div>
				</div>
			</div>
		</div>

		<!-- ====== Section 5: Quick Actions & References ====== -->
		<div class="od-section">
			<div class="od-section-head">
				<h3 class="od-section-title"><i class="fas fa-bolt"></i> Quick Actions</h3>
				<i class="fas fa-chevron-down od-section-caret"></i>
			</div>
			<div class="od-section-body">
				<div class="od-widget-row">
					<div class="od-widget od-widget-wide">
						<div class="od-widget-head"><h3>Links &amp; Tools</h3></div>
						<div class="od-widget-body">
							<div class="od-links-grid">
								<a class="od-link-card" href="<?= UIR ?>Reports/reeve/<?= (int)($kingdom_id ?? 0) ?>"><i class="fas fa-list-check"></i><span>Reeve report (kingdom)</span></a>
								<a class="od-link-card" href="<?= UIR ?>Park/profile/<?= (int)($park_id ?? 0) ?>"><i class="fas fa-tree"></i><span>Park profile</span></a>
								<a class="od-link-card" href="<?= UIR ?>Reports/attendance/<?= (int)($kingdom_id ?? 0) ?>"><i class="fas fa-chart-line"></i><span>Attendance report</span></a>
								<a class="od-link-card od-link-card-disabled" href="#" onclick="return false;" style="opacity:0.55;"><i class="fas fa-gavel"></i><span>Log ruling <small>(soon)</small></span></a>
								<a class="od-link-card od-link-card-disabled" href="#" onclick="return false;" style="opacity:0.55;"><i class="fas fa-exclamation-triangle"></i><span>Report incident <small>(soon)</small></span></a>
								<a class="od-link-card od-link-card-disabled" href="#" onclick="return false;" style="opacity:0.55;"><i class="fas fa-paper-plane"></i><span>Submit cert list <small>(soon)</small></span></a>
							</div>
						</div>
					</div>
				</div>
			</div>
		</div>

		<div class="od-section od-section-closed">
			<div class="od-section-head">
				<h3 class="od-section-title"><i class="fas fa-book"></i> References</h3>
				<i class="fas fa-chevron-down od-section-caret"></i>
			</div>
			<div class="od-section-body">
				<div class="od-widget-row">
					<div class="od-widget od-widget-wide">
						<div class="od-widget-head"><h3>Rulebooks</h3></div>
						<div class="od-widget-body">
							<div class="od-links-grid">
								<a class="od-link-card" href="https://amtgard.com/rules" target="_blank" rel="noopener"><i class="fas fa-scroll"></i><span>Rules of Play</span></a>
								<a class="od-link-card" href="https://amtgard.com/rules/corpora" target="_blank" rel="noopener"><i class="fas fa-book-dead"></i><span>Corpora</span></a>
								<a class="od-link-card" href="https://amtgard.com/rules/reeve-handbook" target="_blank" rel="noopener"><i class="fas fa-user-shield"></i><span>Reeve handbook</span></a>
							</div>
						</div>
					</div>
				</div>
			</div>
		</div>
