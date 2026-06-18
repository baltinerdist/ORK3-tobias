<?php
	$parksNoGmr         = (int)($ocData['parksNoGmr']   ?? 0);
	$parkGmrSeats       = (int)($ocData['parkGmrSeats'] ?? 0);
	$certifiedReeves    = (int)($ocData['certifiedReeves'] ?? 0);
	$activeReeves       = (int)($ocData['activeReeves'] ?? 0);
	$roster             = $ocData['reeveRoster']        ?? [];
	$reevesPerPark      = $ocData['reevesPerPark']      ?? [];
	$recentReeveAwards  = $ocData['recentReeveAwards']  ?? [];
	$reeveAwardTrend    = $ocData['reeveAwardTrend']    ?? [];
	$upcomingEvents     = $ocData['upcomingEvents']     ?? [];
	$upcomingTourneys   = $ocData['upcomingTournaments']?? [];
	$parkCoverage       = $ocData['parkCoverage']       ?? [];
	$parkCoveragePct    = (int)($ocData['parkCoveragePct'] ?? 0);
	$parkCoverageTotal  = (int)($ocData['parkCoverageTotal'] ?? 0);
	$parkCoverageSeated = (int)($ocData['parkCoverageSeated'] ?? 0);
	$heat               = $ocData['reeveHeatmap']       ?? ['Parks' => [], 'Quarters' => []];
	$parksNoGmrList     = $ocData['parksNoGmrList']     ?? [];

	// Active-reeve engagement: % of certified reeves who attended in the last 90d.
	$engagementPct = $certifiedReeves > 0 ? (int)round(($activeReeves / $certifiedReeves) * 100) : 0;

	// Chart prep: reeves-per-park (top 12, horizontal bar).
	$rpTop = array_slice($reevesPerPark, 0, 12);
	$rpLabels = array_map(function($r){ return $r['ParkName']; }, $rpTop);
	$rpValues = array_map(function($r){ return (int)$r['ReeveCount']; }, $rpTop);

	// Trend sparkline: reeve awards per quarter.
	$trendVals = array_map(function($q){ return (int)$q['Count']; }, $reeveAwardTrend);

	// Coverage donut: seated vs vacant parks.
	$coverageSegs   = [$parkCoverageSeated, max(0, $parkCoverageTotal - $parkCoverageSeated)];
	$coverageLabels = ['Seated','Vacant'];
?>
		<div class="od-grid">
			<div class="od-stat-card"><div class="od-stat-num"><?= $parkGmrSeats ?></div><div class="od-stat-lbl">Park GMRs seated</div></div>
			<div class="od-stat-card"><div class="od-stat-num"><?= $parksNoGmr ?></div><div class="od-stat-lbl">Parks without GMR</div></div>
			<div class="od-stat-card"><div class="od-stat-num"><?= $certifiedReeves ?></div><div class="od-stat-lbl">Certified reeves <span class="od-subline" style="font-size:10px">(proxy: Reeve awards)</span></div></div>
			<div class="od-stat-card"><div class="od-stat-num"><?= $activeReeves ?></div><div class="od-stat-lbl">Active reeves (90d attend)</div></div>
			<div class="od-stat-card"><div class="od-stat-num"><?= $engagementPct ?>%</div><div class="od-stat-lbl">Reeve engagement rate</div></div>
			<div class="od-stat-card"><div class="od-stat-num">0</div><div class="od-stat-lbl">Rulings this term <span class="od-subline" style="font-size:10px">(coming soon)</span></div></div>
		</div>

		<!-- ====== Section 1: GMR Coverage & Reeve Population ====== -->
		<div class="od-section">
			<div class="od-section-head">
				<h3 class="od-section-title"><i class="fas fa-shield-alt"></i> GMR Coverage &amp; Reeve Population</h3>
				<i class="fas fa-chevron-down od-section-caret"></i>
			</div>
			<div class="od-section-body">
				<div class="od-widget-row">
					<div class="od-widget">
						<div class="od-widget-head"><h3>Park GMR Coverage</h3></div>
						<div class="od-widget-body">
							<svg class="od-chart od-chart-ring"
							     data-value="<?= $parkCoveragePct ?>"
							     data-max="100"
							     data-display="<?= $parkCoveragePct ?>%"
							     data-label="Parks with GMR"></svg>
							<div style="text-align:center;font-size:12px;color:#666;margin-top:4px;">
								<?= $parkCoverageSeated ?> of <?= $parkCoverageTotal ?> active parks seated
							</div>
						</div>
					</div>
					<div class="od-widget">
						<div class="od-widget-head"><h3>Seat Status Breakdown</h3></div>
						<div class="od-widget-body">
							<?php if ($parkCoverageTotal > 0): ?>
								<svg class="od-chart od-chart-donut"
								     data-values="<?= htmlspecialchars(implode(',', $coverageSegs)) ?>"
								     data-labels="<?= htmlspecialchars(implode('|', $coverageLabels)) ?>"
								     data-center-label="Parks"></svg>
							<?php else: ?>
								<div class="od-empty">No active parks in kingdom.</div>
							<?php endif; ?>
						</div>
					</div>
					<div class="od-widget">
						<div class="od-widget-head"><h3>Certified vs Active</h3></div>
						<div class="od-widget-body">
							<svg class="od-chart od-chart-ring"
							     data-value="<?= $engagementPct ?>"
							     data-max="100"
							     data-display="<?= $engagementPct ?>%"
							     data-label="Active in 90d"></svg>
							<div style="text-align:center;font-size:12px;color:#666;margin-top:4px;">
								<?= $activeReeves ?> of <?= $certifiedReeves ?> proxied reeves recently active
							</div>
						</div>
					</div>
				</div>

				<div class="od-widget-row">
					<div class="od-widget od-widget-wide">
						<div class="od-widget-head">
							<h3>Parks Without a GMR</h3>
							<span class="od-subline">Active chapters with a vacant Park GMR seat</span>
						</div>
						<div class="od-widget-body">
							<?php if (empty($parksNoGmrList)): ?>
								<div class="od-empty od-empty-ok"><i class="fas fa-check-circle"></i> All active chapters have a GMR seated.</div>
							<?php else: ?>
								<table class="od-table od-table-compact" data-od-paginate="8">
									<thead><tr><th>Park</th><th style="text-align:right;">Action</th></tr></thead>
									<tbody>
									<?php foreach ($parksNoGmrList as $p): ?>
										<tr>
											<td><a href="<?= UIR ?>Park/profile/<?= (int)$p['ParkId'] ?>"><?= htmlspecialchars($p['ParkName']) ?></a></td>
											<td style="text-align:right;"><span class="od-pill od-pill-warn">VACANT</span></td>
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
						<div class="od-widget-head">
							<h3>Park GMR Coverage Detail</h3>
							<span class="od-subline">Seated GMRs by chapter</span>
						</div>
						<div class="od-widget-body">
							<?php if (empty($parkCoverage)): ?>
								<div class="od-empty">No active parks in kingdom.</div>
							<?php else: ?>
								<table class="od-table od-table-compact" data-od-paginate="8">
									<thead><tr><th>Park</th><th>GMR</th><th>Seated since</th><th>Status</th></tr></thead>
									<tbody>
									<?php foreach ($parkCoverage as $c): ?>
										<tr>
											<td><a href="<?= UIR ?>Park/profile/<?= (int)$c['ParkId'] ?>"><?= htmlspecialchars($c['ParkName']) ?></a></td>
											<td>
												<?php if ($c['GmrMundane']): ?>
													<a href="<?= UIR ?>Player/profile/<?= (int)$c['GmrMundane'] ?>"><?= htmlspecialchars($c['GmrPersona'] ?? '—') ?></a>
												<?php else: ?>
													<span style="color:#999">—</span>
												<?php endif; ?>
											</td>
											<td><?= htmlspecialchars($c['SeatedSince'] ?? '—') ?></td>
											<td><?= $c['GmrMundane']
												? '<span class="od-pill od-pill-ok">SEATED</span>'
												: '<span class="od-pill od-pill-warn">VACANT</span>' ?></td>
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

		<!-- ====== Section 2: Reeve Roster & Distribution ====== -->
		<div class="od-section">
			<div class="od-section-head">
				<h3 class="od-section-title"><i class="fas fa-users"></i> Reeve Roster &amp; Distribution</h3>
				<i class="fas fa-chevron-down od-section-caret"></i>
			</div>
			<div class="od-section-body">
				<div class="od-widget-row">
					<div class="od-widget od-widget-wide">
						<div class="od-widget-head">
							<h3>Reeves per Park <span class="od-subline" style="font-weight:normal">(top 12)</span></h3>
						</div>
						<div class="od-widget-body">
							<?php if (empty($rpValues) || array_sum($rpValues) === 0): ?>
								<div class="od-empty">No reeve-award data found in kingdom.</div>
							<?php else: ?>
								<svg class="od-chart od-chart-bar"
								     data-orientation="horizontal"
								     data-values="<?= htmlspecialchars(implode(',', $rpValues)) ?>"
								     data-labels="<?= htmlspecialchars(implode('|', $rpLabels)) ?>"></svg>
							<?php endif; ?>
						</div>
					</div>
				</div>

				<div class="od-widget-row">
					<div class="od-widget od-widget-wide">
						<div class="od-widget-head">
							<h3>Kingdom Reeve Roster</h3>
							<a class="od-link" href="<?= UIR ?>Reports/reeve/<?= (int)$kingdom_id ?>">Full reeve report<i class="fas fa-arrow-right"></i></a>
						</div>
						<div class="od-widget-body">
							<?php if (empty($roster)): ?>
								<div class="od-empty">No reeve-qualified players found. (Proxy uses awards matching "Reeve" — kingdom may use a different term.)</div>
							<?php else: ?>
								<p class="od-subline" style="margin:0 0 8px 0;font-size:11px;color:#888;font-style:italic;">Proxy: players holding any kingdom award matching "Reeve" (e.g. Reeve's Qualified, Paragon Reeve). No formal cert-list table yet.</p>
								<table class="od-table od-table-compact" data-od-paginate="10">
									<thead><tr><th>Player</th><th>Park</th><th>Most recent reeve award</th><th>Awarded</th></tr></thead>
									<tbody>
									<?php foreach ($roster as $r): ?>
										<tr>
											<td><a href="<?= UIR ?>Player/profile/<?= (int)$r['MundaneId'] ?>"><?= htmlspecialchars($r['Persona'] ?? '—') ?></a></td>
											<td><?php if ($r['ParkId']): ?><a href="<?= UIR ?>Park/profile/<?= (int)$r['ParkId'] ?>"><?= htmlspecialchars($r['ParkName']) ?></a><?php else: ?>—<?php endif; ?></td>
											<td><?= htmlspecialchars($r['AwardName'] ?? '—') ?></td>
											<td><?= htmlspecialchars($r['LastAwardDate']) ?></td>
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
						<div class="od-widget-head"><h3>Recent Reeve Awards</h3></div>
						<div class="od-widget-body">
							<?php if (empty($recentReeveAwards)): ?>
								<div class="od-empty">No recent reeve awards logged.</div>
							<?php else: ?>
								<table class="od-table od-table-compact" data-od-paginate="5">
									<thead><tr><th>Player</th><th>Award</th><th>Date</th></tr></thead>
									<tbody>
									<?php foreach ($recentReeveAwards as $a): ?>
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
					<div class="od-widget">
						<div class="od-widget-head"><h3>Reeve Award Trend (8 quarters)</h3></div>
						<div class="od-widget-body">
							<?php if (empty($trendVals) || array_sum($trendVals) === 0): ?>
								<div class="od-empty">Not enough data for trend.</div>
							<?php else: ?>
								<svg class="od-spark" viewBox="0 0 240 48" preserveAspectRatio="none" data-values="<?= htmlspecialchars(implode(',', $trendVals)) ?>"></svg>
								<div style="display:flex;justify-content:space-between;font-size:11px;color:#888;margin-top:4px;">
									<span><?= htmlspecialchars($reeveAwardTrend[0]['Quarter'] ?? '') ?></span>
									<span>Peak: <?= max($trendVals) ?></span>
									<span><?= htmlspecialchars(end($reeveAwardTrend)['Quarter'] ?? '') ?></span>
								</div>
							<?php endif; ?>
						</div>
					</div>
				</div>

				<?php if (!empty($heat['Parks']) && !empty($heat['Quarters'])): ?>
				<div class="od-widget-row">
					<div class="od-widget od-widget-wide">
						<div class="od-widget-head">
							<h3>Reeve-Award Density Heatmap</h3>
							<span class="od-subline">Parks × last <?= count($heat['Quarters']) ?> quarters</span>
						</div>
						<div class="od-widget-body">
							<?php
								$rows = [];
								$rowLabels = [];
								foreach ($heat['Parks'] as $p) {
									$rowLabels[] = $p['ParkName'];
									$row = [];
									foreach ($heat['Quarters'] as $q) {
										$row[] = (int)($p['Cells'][$q] ?? 0);
									}
									$rows[] = implode(',', $row);
								}
								$matrix = implode(';', $rows);
								$cols = implode('|', $heat['Quarters']);
								$rLabels = implode('|', $rowLabels);
							?>
							<svg class="od-chart od-chart-heatmap"
							     data-matrix="<?= htmlspecialchars($matrix) ?>"
							     data-cols="<?= htmlspecialchars($cols) ?>"
							     data-rows="<?= htmlspecialchars($rLabels) ?>"></svg>
						</div>
					</div>
				</div>
				<?php endif; ?>
			</div>
		</div>

		<!-- ====== Section 3: Event Coverage & Assignments ====== -->
		<div class="od-section">
			<div class="od-section-head">
				<h3 class="od-section-title"><i class="fas fa-calendar-check"></i> Event Coverage &amp; Assignments</h3>
				<i class="fas fa-chevron-down od-section-caret"></i>
			</div>
			<div class="od-section-body">
				<div class="od-widget-row">
					<div class="od-widget">
						<div class="od-widget-head"><h3>Upcoming Kingdom Events</h3><span class="od-subline">Need reeve coverage</span></div>
						<div class="od-widget-body">
							<?php if (empty($upcomingEvents)): ?>
								<div class="od-empty">No scheduled kingdom events.</div>
							<?php else: ?>
								<table class="od-table od-table-compact" data-od-paginate="5">
									<thead><tr><th>Event</th><th>Chapter</th><th>Start</th></tr></thead>
									<tbody>
									<?php foreach ($upcomingEvents as $e): ?>
										<tr>
											<td><?= htmlspecialchars($e['Name'] ?? '—') ?></td>
											<td><?php if ($e['ParkId']): ?><a href="<?= UIR ?>Park/profile/<?= (int)$e['ParkId'] ?>"><?= htmlspecialchars($e['ParkName']) ?></a><?php else: ?>—<?php endif; ?></td>
											<td><?= htmlspecialchars(substr($e['StartDate'] ?? '', 0, 10)) ?></td>
										</tr>
									<?php endforeach; ?>
									</tbody>
								</table>
							<?php endif; ?>
						</div>
					</div>
					<div class="od-widget">
						<div class="od-widget-head"><h3>Upcoming Tournaments</h3><span class="od-subline">Reeves required</span></div>
						<div class="od-widget-body">
							<?php if (empty($upcomingTourneys)): ?>
								<div class="od-empty">No scheduled tournaments.</div>
							<?php else: ?>
								<table class="od-table od-table-compact" data-od-paginate="5">
									<thead><tr><th>Tournament</th><th>Chapter</th><th>When</th><th>Status</th></tr></thead>
									<tbody>
									<?php foreach ($upcomingTourneys as $t): ?>
										<tr>
											<td><?= htmlspecialchars($t['Name'] ?? '—') ?></td>
											<td><?php if ($t['ParkId']): ?><a href="<?= UIR ?>Park/profile/<?= (int)$t['ParkId'] ?>"><?= htmlspecialchars($t['ParkName']) ?></a><?php else: ?>—<?php endif; ?></td>
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
						<div class="od-widget-head"><h3>Event Reeve Assignment Heatmap</h3></div>
						<div class="od-widget-body">
							<p class="od-subline" style="font-size:12px;">Coming soon: a week-by-event grid showing reeve staffing ratios (head reeve, line reeves, list reeves) vs entrants. Flags events that are understaffed or overcommitted. Will consume a future <code>ork_event_reeve_assignment</code> table.</p>
						</div>
					</div>
					<div class="od-widget od-widget-soon">
						<div class="od-widget-head"><h3>Coverage Gaps</h3></div>
						<div class="od-widget-body">
							<p class="od-subline" style="font-size:12px;">Coming soon: events and tournaments within the next 30 days that have zero confirmed reeves assigned. Will surface immediate recruitment needs with one-click "assign me" actions.</p>
						</div>
					</div>
				</div>
			</div>
		</div>

		<!-- ====== Section 4: Certifications & Training (stubs) ====== -->
		<div class="od-section">
			<div class="od-section-head">
				<h3 class="od-section-title"><i class="fas fa-graduation-cap"></i> Certifications &amp; Training</h3>
				<i class="fas fa-chevron-down od-section-caret"></i>
			</div>
			<div class="od-section-body">
				<div class="od-widget-row">
					<div class="od-widget od-widget-soon">
						<div class="od-widget-head"><h3>Certification Expiration Cohort</h3></div>
						<div class="od-widget-body">
							<p class="od-subline" style="font-size:12px;">Coming soon: a bar chart bucketing reeves by months-until-expiration (0-3, 3-6, 6-12, 12+). Requires formal <code>ork_reeve_certification</code> schema with issued/expires dates. Right now we can only see the most recent reeve award date as a proxy.</p>
						</div>
					</div>
					<div class="od-widget od-widget-soon">
						<div class="od-widget-head"><h3>Upcoming Reeve Tests</h3></div>
						<div class="od-widget-body">
							<p class="od-subline" style="font-size:12px;">Coming soon: scheduled testing sessions (Crown Quals prep, V9 playtest drills, corpora refreshers) with enrollment counts. Will pull from a future <code>ork_reeve_test</code> calendar.</p>
						</div>
					</div>
					<div class="od-widget od-widget-soon">
						<div class="od-widget-head"><h3>Tier Progression</h3></div>
						<div class="od-widget-body">
							<p class="od-subline" style="font-size:12px;">Coming soon: donut breakdown of Apprentice / Journeyman / Master / Paragon reeves (per-corpora variation). Today we only have "Paragon Reeve" as a named award; other tiers need a schema.</p>
						</div>
					</div>
				</div>

				<div class="od-widget-row">
					<div class="od-widget od-widget-soon">
						<div class="od-widget-head"><h3>Crown Quals Countdown</h3></div>
						<div class="od-widget-body">
							<p class="od-subline" style="font-size:12px;">Coming soon: days-until-Crown-Quals ring chart with link to the testing roster and head-reeve slate.</p>
						</div>
					</div>
					<div class="od-widget od-widget-soon">
						<div class="od-widget-head"><h3>Training Attendance</h3></div>
						<div class="od-widget-body">
							<p class="od-subline" style="font-size:12px;">Coming soon: sparkline of attendees at recent kingdom reeve trainings, plus a list of parks that haven't hosted a rules clinic in 6+ months.</p>
						</div>
					</div>
				</div>
			</div>
		</div>

		<!-- ====== Section 5: Rulings / Incidents / Errata (all stubs) ====== -->
		<div class="od-section od-section-closed">
			<div class="od-section-head">
				<h3 class="od-section-title"><i class="fas fa-gavel"></i> Rulings, Incidents &amp; Errata</h3>
				<i class="fas fa-chevron-down od-section-caret"></i>
			</div>
			<div class="od-section-body">
				<div class="od-widget-row">
					<div class="od-widget od-widget-soon">
						<div class="od-widget-head"><h3>Open Rulings Queue</h3></div>
						<div class="od-widget-body">
							<p class="od-subline" style="font-size:12px;">Coming soon: pending rulings awaiting GMR publication, with age-in-queue warnings. Will back to a future <code>ork_ruling</code> table with status (draft/published/superseded) and affected-corpora tags.</p>
						</div>
					</div>
					<div class="od-widget od-widget-soon">
						<div class="od-widget-head"><h3>Rulings Log</h3></div>
						<div class="od-widget-body">
							<p class="od-subline" style="font-size:12px;">Coming soon: a searchable log of published kingdom rulings with tags, affected rule sections, and a "canon / one-off" toggle. Will be the first formal rulings archive in ORK3.</p>
						</div>
					</div>
				</div>

				<div class="od-widget-row">
					<div class="od-widget od-widget-soon">
						<div class="od-widget-head"><h3>Errata Publishing History</h3></div>
						<div class="od-widget-body">
							<p class="od-subline" style="font-size:12px;">Coming soon: timeline of corpora/errata publications with diff links. Scoped per-kingdom (for kingdom errata) and per-corpora (for playtests).</p>
						</div>
					</div>
					<div class="od-widget od-widget-soon">
						<div class="od-widget-head"><h3>Open Appeals</h3></div>
						<div class="od-widget-body">
							<p class="od-subline" style="font-size:12px;">Coming soon: appeals of on-field rulings currently awaiting GMR adjudication. Tracks appellant, event, and deadline to rule.</p>
						</div>
					</div>
					<div class="od-widget od-widget-soon">
						<div class="od-widget-head"><h3>Incident Reports</h3></div>
						<div class="od-widget-body">
							<p class="od-subline" style="font-size:12px;">Coming soon: safety / conduct incident intake with severity tags, follow-up status, and anonymous-witness option. GMR is the custodian.</p>
						</div>
					</div>
					<div class="od-widget od-widget-soon">
						<div class="od-widget-head"><h3>Conflict-of-Interest Registry</h3></div>
						<div class="od-widget-body">
							<p class="od-subline" style="font-size:12px;">Coming soon: standing COI disclosures so reeves self-recuse from events/appeals where they have a conflict.</p>
						</div>
					</div>
				</div>
			</div>
		</div>

		<!-- ====== Section 6: Quick Actions ====== -->
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
								<a class="od-link-card" href="<?= UIR ?>Reports/reeve/<?= (int)$kingdom_id ?>"><i class="fas fa-list-check"></i><span>Reeve report</span></a>
								<a class="od-link-card" href="<?= UIR ?>Reports/attendance/<?= (int)$kingdom_id ?>"><i class="fas fa-chart-line"></i><span>Kingdom attendance</span></a>
								<a class="od-link-card" href="<?= UIR ?>Kingdom/profile/<?= (int)$kingdom_id ?>"><i class="fas fa-crown"></i><span>Kingdom profile</span></a>
								<a class="od-link-card" href="<?= UIR ?>Admin/kingdom/<?= (int)$kingdom_id ?>"><i class="fas fa-cog"></i><span>Kingdom admin</span></a>
								<a class="od-link-card od-link-card-disabled" href="#" onclick="return false;" style="opacity:0.55;"><i class="fas fa-gavel"></i><span>Log a ruling <small>(soon)</small></span></a>
								<a class="od-link-card od-link-card-disabled" href="#" onclick="return false;" style="opacity:0.55;"><i class="fas fa-exclamation-triangle"></i><span>Record incident <small>(soon)</small></span></a>
								<a class="od-link-card od-link-card-disabled" href="#" onclick="return false;" style="opacity:0.55;"><i class="fas fa-user-check"></i><span>Certify reeve <small>(soon)</small></span></a>
								<a class="od-link-card od-link-card-disabled" href="#" onclick="return false;" style="opacity:0.55;"><i class="fas fa-calendar-plus"></i><span>Schedule reeve test <small>(soon)</small></span></a>
							</div>
						</div>
					</div>
				</div>
			</div>
		</div>

		<!-- ====== Section 7: References (closed) ====== -->
		<div class="od-section od-section-closed">
			<div class="od-section-head">
				<h3 class="od-section-title"><i class="fas fa-book"></i> Tools &amp; References</h3>
				<i class="fas fa-chevron-down od-section-caret"></i>
			</div>
			<div class="od-section-body">
				<div class="od-widget-row">
					<div class="od-widget od-widget-wide">
						<div class="od-widget-head"><h3>Rulebooks &amp; Playtest</h3></div>
						<div class="od-widget-body">
							<div class="od-links-grid">
								<a class="od-link-card" href="https://amtgard.com/rules" target="_blank" rel="noopener"><i class="fas fa-scroll"></i><span>Rules of Play</span></a>
								<a class="od-link-card" href="https://amtgard.com/rules/corpora" target="_blank" rel="noopener"><i class="fas fa-book-dead"></i><span>Corpora (reeve section)</span></a>
								<a class="od-link-card" href="https://amtgard.com/rules/reeve-handbook" target="_blank" rel="noopener"><i class="fas fa-user-shield"></i><span>Reeve handbook</span></a>
								<a class="od-link-card" href="https://amtgard.com/rules/v9" target="_blank" rel="noopener"><i class="fas fa-flask"></i><span>V9 playtest rules</span></a>
								<a class="od-link-card od-link-card-disabled" href="#" onclick="return false;" style="opacity:0.55;"><i class="fas fa-archive"></i><span>Rulings archive <small>(soon)</small></span></a>
							</div>
						</div>
					</div>
				</div>
			</div>
		</div>
