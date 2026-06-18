<?php
	$unsung           = $ocData['unsungMembers']          ?? [];
	$recentAwards     = $ocData['recentAwards']           ?? [];
	$topAttendees     = $ocData['topAttendees']           ?? [];
	$activePlayers    = (int)($ocData['activePlayers']    ?? 0);
	$awardsPerMember  = (float)($ocData['awardsPerMember']?? 0);
	$parkRecs         = $ocData['parkRecs']               ?? [];
	$parkPeerage      = $ocData['parkPeerage']            ?? [];
	$parkCats         = $ocData['parkAwardCategories']    ?? [];
	$parkTrend        = $ocData['parkBestowalTrend']      ?? [];
	$parkVsKingdom    = $ocData['parkVsKingdom']          ?? ['ParkRatio'=>0,'KingdomAvg'=>0];
	$parkLadder       = $ocData['parkLadderHolders']      ?? [];
	$parkTopBestowers = $ocData['parkTopBestowers']       ?? [];
	$parkTopRec       = $ocData['parkTopRecommenders']    ?? [];
	$parkRecogCov     = $ocData['parkRecognitionCov']     ?? ['Total'=>0,'Recognized'=>0,'Percent'=>0];
	$parkFresh        = $ocData['parkRecognitionFresh']   ?? [0,0,0,0];
	$parkStalled      = $ocData['parkLadderStalled']      ?? [];
	$parkCand         = $ocData['parkPeerageCandidates']  ?? [];
	$parkAttNoAward   = $ocData['parkAttendeeNoAward']    ?? [];
	$parkRecsByMe     = $ocData['parkRecsByMe']           ?? [];

	$parkPeerageCount = count($parkPeerage);
?>

<!-- =====================================================
     Top stat cards
===================================================== -->
<div class="od-grid">
	<div class="od-stat-card"><div class="od-stat-num"><?= count($unsung) ?></div><div class="od-stat-lbl">Unsung park members</div></div>
	<div class="od-stat-card"><div class="od-stat-num"><?= count($parkRecs) ?></div><div class="od-stat-lbl">Open recommendations</div></div>
	<div class="od-stat-card"><div class="od-stat-num"><?= count($recentAwards) ?></div><div class="od-stat-lbl">Awards (90d)</div></div>
	<div class="od-stat-card"><div class="od-stat-num"><?= $activePlayers ?></div><div class="od-stat-lbl">Active members</div></div>
	<div class="od-stat-card"><div class="od-stat-num"><?= number_format($awardsPerMember, 2) ?></div><div class="od-stat-lbl">Awards / member</div></div>
	<div class="od-stat-card"><div class="od-stat-num"><?= $parkPeerageCount ?></div><div class="od-stat-lbl">Peerage holders</div></div>
</div>

<!-- =====================================================
     SECTION: Recognition Pipeline
===================================================== -->
<div class="od-section">
	<div class="od-section-head">
		<h3 class="od-section-title"><i class="fas fa-scroll"></i> Recommendations &amp; Pipeline</h3>
		<i class="fas fa-chevron-down od-section-caret"></i>
	</div>
	<div class="od-section-body">

		<div class="od-widget-row">
			<div class="od-widget od-widget-wide">
				<div class="od-widget-head"><h3>Open Recommendations for Park Members</h3></div>
				<div class="od-widget-body">
					<?php if (empty($parkRecs)): ?>
						<div class="od-empty">No open recommendations for this chapter.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Player</th><th>Award</th><th>Recommender</th><th>Date</th></tr></thead>
							<tbody>
							<?php foreach ($parkRecs as $r): ?>
								<tr><td><a href="<?= UIR ?>Player/profile/<?= (int)$r['MundaneId'] ?>"><?= htmlspecialchars($r['Persona']) ?></a></td>
									<td><?= htmlspecialchars($r['Award'] ?? '—') ?></td>
									<td><?= htmlspecialchars($r['RecommendedBy'] ?? '—') ?></td>
									<td><?= htmlspecialchars(substr($r['Date'] ?? '',0,10)) ?></td></tr>
							<?php endforeach; ?>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>
		</div>

		<div class="od-widget-row">
			<div class="od-widget">
				<div class="od-widget-head"><h3>Recommendations I've Written</h3></div>
				<div class="od-widget-body">
					<?php if (empty($parkRecsByMe)): ?>
						<div class="od-empty">You haven't written a recommendation yet.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Player</th><th>Award</th><th>Date</th><th>Status</th></tr></thead>
							<tbody>
							<?php foreach ($parkRecsByMe as $r): ?>
								<tr><td><a href="<?= UIR ?>Player/profile/<?= (int)$r['MundaneId'] ?>"><?= htmlspecialchars($r['Persona']) ?></a></td>
									<td><?= htmlspecialchars($r['Award'] ?? '—') ?></td>
									<td><?= htmlspecialchars(substr($r['Date'] ?? '',0,10)) ?></td>
									<td><span class="od-pill <?= $r['Status']==='open' ? 'od-pill-ok' : '' ?>"><?= htmlspecialchars($r['Status']) ?></span></td></tr>
							<?php endforeach; ?>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>

			<div class="od-widget">
				<div class="od-widget-head"><h3>Top Recommenders (park, 6mo)</h3></div>
				<div class="od-widget-body">
					<?php if (empty($parkTopRec)): ?>
						<div class="od-empty">No recommendations logged.</div>
					<?php else:
						$vals = array_map(fn($r) => (int)$r['Count'], $parkTopRec);
						$labs = array_map(fn($r) => $r['Persona'], $parkTopRec);
					?>
						<svg class="od-chart od-chart-bar" data-orientation="horizontal"
							data-values="<?= htmlspecialchars(implode(',', $vals)) ?>"
							data-labels="<?= htmlspecialchars(implode('|', $labs)) ?>"></svg>
					<?php endif; ?>
				</div>
			</div>
		</div>
	</div>
</div>

<!-- =====================================================
     SECTION: Unsung & Candidates
===================================================== -->
<div class="od-section">
	<div class="od-section-head">
		<h3 class="od-section-title"><i class="fas fa-user-clock"></i> Unsung &amp; Candidates</h3>
		<i class="fas fa-chevron-down od-section-caret"></i>
	</div>
	<div class="od-section-body">

		<div class="od-widget-row">
			<div class="od-widget od-widget-wide">
				<div class="od-widget-head"><h3>Unsung Park Members</h3></div>
				<div class="od-widget-body">
					<?php if (empty($unsung)): ?>
						<div class="od-empty od-empty-ok"><i class="fas fa-check-circle"></i> Park recognition looks healthy.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Player</th><th>Last award</th><th>Attendance (90d)</th></tr></thead>
							<tbody>
								<?php foreach ($unsung as $u): ?>
									<tr>
										<td><a href="<?= UIR ?>Player/profile/<?= (int)$u['MundaneId'] ?>"><?= htmlspecialchars($u['Persona'] ?? '—') ?></a></td>
										<td><?= htmlspecialchars($u['LastAward'] ?? 'never') ?></td>
										<td><?= (int)($u['Attendance90'] ?? 0) ?></td>
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
				<div class="od-widget-head"><h3>Top Attendees (90d)</h3>
					<span class="od-subline">Potential award candidates</span>
				</div>
				<div class="od-widget-body">
					<?php if (empty($topAttendees)): ?>
						<div class="od-empty">No attendance.</div>
					<?php else:
						$vals = array_map(fn($r) => (int)($r['AttendCount'] ?? 0), $topAttendees);
						$labs = array_map(fn($r) => $r['Persona'] ?? '—', $topAttendees);
					?>
						<svg class="od-chart od-chart-bar" data-orientation="horizontal"
							data-values="<?= htmlspecialchars(implode(',', $vals)) ?>"
							data-labels="<?= htmlspecialchars(implode('|', $labs)) ?>"></svg>
					<?php endif; ?>
				</div>
			</div>

			<div class="od-widget">
				<div class="od-widget-head"><h3>Attendees, No Recent Award</h3>
					<span class="od-subline">5+ credits, no award 12mo</span>
				</div>
				<div class="od-widget-body">
					<?php if (empty($parkAttNoAward)): ?>
						<div class="od-empty od-empty-ok"><i class="fas fa-check-circle"></i> Nothing overdue.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Player</th><th>Credits 90d</th><th>Last award</th></tr></thead>
							<tbody>
							<?php foreach ($parkAttNoAward as $p): ?>
								<tr><td><a href="<?= UIR ?>Player/profile/<?= (int)$p['MundaneId'] ?>"><?= htmlspecialchars($p['Persona']) ?></a></td>
									<td><?= (int)$p['Credits90'] ?></td>
									<td><?= htmlspecialchars($p['LastAward']) ?></td></tr>
							<?php endforeach; ?>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>
		</div>

		<div class="od-widget-row">
			<div class="od-widget">
				<div class="od-widget-head"><h3>Park Peerage Candidates</h3>
					<span class="od-subline">12+ attendance (180d), no peerage</span>
				</div>
				<div class="od-widget-body">
					<?php if (empty($parkCand)): ?>
						<div class="od-empty">No candidates yet.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Player</th><th>Att. 180d</th><th>First award</th></tr></thead>
							<tbody>
							<?php foreach ($parkCand as $c): ?>
								<tr><td><a href="<?= UIR ?>Player/profile/<?= (int)$c['MundaneId'] ?>"><?= htmlspecialchars($c['Persona']) ?></a></td>
									<td><?= (int)$c['Attend180'] ?></td>
									<td><?= htmlspecialchars($c['FirstAward']) ?></td></tr>
							<?php endforeach; ?>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>

			<div class="od-widget">
				<div class="od-widget-head"><h3>Ladder Stalled (park)</h3>
					<span class="od-subline">No rank change 2+ yrs</span>
				</div>
				<div class="od-widget-body">
					<?php if (empty($parkStalled)): ?>
						<div class="od-empty od-empty-ok"><i class="fas fa-check-circle"></i> No stalled ladders.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Player</th><th>Award</th><th>Rank</th></tr></thead>
							<tbody>
							<?php foreach ($parkStalled as $s): ?>
								<tr><td><a href="<?= UIR ?>Player/profile/<?= (int)$s['MundaneId'] ?>"><?= htmlspecialchars($s['Persona']) ?></a></td>
									<td><?= htmlspecialchars($s['Award'] ?? '—') ?></td>
									<td><span class="od-pill">R<?= (int)$s['CurrentRank'] ?></span></td></tr>
							<?php endforeach; ?>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>
		</div>
	</div>
</div>

<!-- =====================================================
     SECTION: Distribution & Trends
===================================================== -->
<div class="od-section">
	<div class="od-section-head">
		<h3 class="od-section-title"><i class="fas fa-chart-pie"></i> Distribution &amp; Trends</h3>
		<i class="fas fa-chevron-down od-section-caret"></i>
	</div>
	<div class="od-section-body">

		<div class="od-widget-row">
			<div class="od-widget">
				<div class="od-widget-head"><h3>Recognition Coverage</h3>
					<span class="od-subline">% of active w/ &ge;1 award</span>
				</div>
				<div class="od-widget-body">
					<svg class="od-chart od-chart-ring"
						data-value="<?= (float)$parkRecogCov['Percent'] ?>"
						data-max="100"
						data-display="<?= (float)$parkRecogCov['Percent'] ?>%"
						data-label="Recognized"></svg>
					<div style="text-align:center;font-size:12px;color:var(--ork-text-secondary);margin-top:4px;">
						<?= (int)$parkRecogCov['Recognized'] ?> of <?= (int)$parkRecogCov['Total'] ?>
					</div>
				</div>
			</div>

			<div class="od-widget">
				<div class="od-widget-head"><h3>Recognition Freshness</h3>
					<span class="od-subline">Last award age</span>
				</div>
				<div class="od-widget-body">
					<?php if (array_sum($parkFresh) <= 0): ?>
						<div class="od-empty">No members.</div>
					<?php else: ?>
						<svg class="od-chart od-chart-donut"
							data-values="<?= htmlspecialchars(implode(',', array_map('intval',$parkFresh))) ?>"
							data-labels="&lt;=6mo|6-12mo|&gt;12mo|Never"
							data-center-label="Members"></svg>
					<?php endif; ?>
				</div>
			</div>

			<div class="od-widget">
				<div class="od-widget-head"><h3>Award Category Mix (12mo)</h3></div>
				<div class="od-widget-body">
					<?php if (empty($parkCats)): ?>
						<div class="od-empty">No awards in window.</div>
					<?php else:
						$vals = array_map(fn($r) => (int)$r['Count'], $parkCats);
						$labs = array_map(fn($r) => $r['Category'], $parkCats);
					?>
						<svg class="od-chart od-chart-pie"
							data-values="<?= htmlspecialchars(implode(',', $vals)) ?>"
							data-labels="<?= htmlspecialchars(implode('|', $labs)) ?>"></svg>
					<?php endif; ?>
				</div>
			</div>
		</div>

		<div class="od-widget-row">
			<div class="od-widget od-widget-wide">
				<div class="od-widget-head"><h3>Bestowal Trend (12 months)</h3></div>
				<div class="od-widget-body">
					<?php if (empty($parkTrend)): ?>
						<div class="od-empty">No data.</div>
					<?php else:
						$vals = array_map(fn($m) => (int)$m['Count'], $parkTrend);
						$labs = array_map(fn($m) => substr($m['Month'],5,2), $parkTrend);
					?>
						<svg class="od-chart od-chart-bar"
							data-values="<?= htmlspecialchars(implode(',', $vals)) ?>"
							data-labels="<?= htmlspecialchars(implode('|', $labs)) ?>"></svg>
					<?php endif; ?>
				</div>
			</div>
		</div>

		<div class="od-widget-row">
			<div class="od-widget">
				<div class="od-widget-head"><h3>Park vs Kingdom Density (90d)</h3>
					<span class="od-subline">Awards per active member</span>
				</div>
				<div class="od-widget-body">
					<?php
						$vals = [ (float)$parkVsKingdom['ParkRatio'], (float)$parkVsKingdom['KingdomAvg'] ];
					?>
					<svg class="od-chart od-chart-bar"
						data-values="<?= htmlspecialchars(implode(',', $vals)) ?>"
						data-labels="Park|Kingdom"></svg>
				</div>
			</div>

			<div class="od-widget">
				<div class="od-widget-head"><h3>Top Bestowers (12mo)</h3></div>
				<div class="od-widget-body">
					<?php if (empty($parkTopBestowers)): ?>
						<div class="od-empty">No data.</div>
					<?php else:
						$vals = array_map(fn($r) => (int)$r['Count'], $parkTopBestowers);
						$labs = array_map(fn($r) => $r['Persona'], $parkTopBestowers);
					?>
						<svg class="od-chart od-chart-bar" data-orientation="horizontal"
							data-values="<?= htmlspecialchars(implode(',', $vals)) ?>"
							data-labels="<?= htmlspecialchars(implode('|', $labs)) ?>"></svg>
					<?php endif; ?>
				</div>
			</div>
		</div>
	</div>
</div>

<!-- =====================================================
     SECTION: Roster
===================================================== -->
<div class="od-section">
	<div class="od-section-head">
		<h3 class="od-section-title"><i class="fas fa-shield-alt"></i> Peerage &amp; Ladder Roster</h3>
		<i class="fas fa-chevron-down od-section-caret"></i>
	</div>
	<div class="od-section-body">

		<div class="od-widget-row">
			<div class="od-widget">
				<div class="od-widget-head"><h3>Peerage from this Park</h3></div>
				<div class="od-widget-body">
					<?php if (empty($parkPeerage)): ?>
						<div class="od-empty">No peerage members in this park.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="6">
							<thead><tr><th>Player</th><th>Peerage</th><th>Since</th></tr></thead>
							<tbody>
							<?php foreach ($parkPeerage as $p): ?>
								<tr><td><a href="<?= UIR ?>Player/profile/<?= (int)$p['MundaneId'] ?>"><?= htmlspecialchars($p['Persona']) ?></a></td>
									<td><span class="od-pill"><?= htmlspecialchars($p['Peerage']) ?></span></td>
									<td><?= htmlspecialchars($p['PeerageDate']) ?></td></tr>
							<?php endforeach; ?>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>

			<div class="od-widget">
				<div class="od-widget-head"><h3>Ladder-Award Holders</h3>
					<span class="od-subline">Current rank per ladder</span>
				</div>
				<div class="od-widget-body">
					<?php if (empty($parkLadder)): ?>
						<div class="od-empty">No ladder data.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="6">
							<thead><tr><th>Player</th><th>Award</th><th>Rank</th></tr></thead>
							<tbody>
							<?php foreach ($parkLadder as $l): ?>
								<tr><td><a href="<?= UIR ?>Player/profile/<?= (int)$l['MundaneId'] ?>"><?= htmlspecialchars($l['Persona']) ?></a></td>
									<td><?= htmlspecialchars($l['Award'] ?? '—') ?></td>
									<td><span class="od-pill">R<?= (int)$l['Rank'] ?></span></td></tr>
							<?php endforeach; ?>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>
		</div>
	</div>
</div>

<!-- =====================================================
     SECTION: Activity feed
===================================================== -->
<div class="od-section">
	<div class="od-section-head">
		<h3 class="od-section-title"><i class="fas fa-stream"></i> Recent Park Awards</h3>
		<i class="fas fa-chevron-down od-section-caret"></i>
	</div>
	<div class="od-section-body">
		<div class="od-widget-row">
			<div class="od-widget od-widget-wide">
				<div class="od-widget-head"><h3>Recent Park Awards Feed</h3></div>
				<div class="od-widget-body">
					<?php if (empty($recentAwards)): ?>
						<div class="od-empty">No recent awards.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="6">
							<thead><tr><th>Player</th><th>Award</th><th>Date</th></tr></thead>
							<tbody>
							<?php foreach ($recentAwards as $a): ?>
								<tr><td><a href="<?= UIR ?>Player/profile/<?= (int)$a['MundaneId'] ?>"><?= htmlspecialchars($a['Persona']) ?></a></td>
									<td><?= htmlspecialchars($a['Award'] ?? '—') ?></td>
									<td><?= htmlspecialchars(substr($a['AwardDate'] ?? '',0,10)) ?></td></tr>
							<?php endforeach; ?>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>
		</div>
	</div>
</div>

<!-- =====================================================
     SECTION: Quick actions (closed)
===================================================== -->
<div class="od-section od-section-closed">
	<div class="od-section-head">
		<h3 class="od-section-title"><i class="fas fa-tools"></i> Quick Actions</h3>
		<i class="fas fa-chevron-down od-section-caret"></i>
	</div>
	<div class="od-section-body">
		<div class="od-widget-row">
			<div class="od-widget od-widget-wide">
				<div class="od-widget-head"><h3>Quick Links</h3></div>
				<div class="od-widget-body">
					<div class="od-links-grid">
						<a class="od-link-card" href="<?= UIR ?>Park/profile/<?= (int)$park_id ?>"><i class="fas fa-shield-alt"></i><span>Park profile</span></a>
						<a class="od-link-card" href="<?= UIR ?>Reports/attendance/<?= (int)$park_id ?>"><i class="fas fa-user-check"></i><span>Park attendance</span></a>
						<a class="od-link-card" href="<?= UIR ?>Kingdomaward/list/<?= (int)($kingdom_id ?? 0) ?>"><i class="fas fa-book"></i><span>Kingdom award catalog</span></a>
					</div>
				</div>
			</div>
		</div>

		<div class="od-widget-row">
			<div class="od-widget od-widget-soon">
				<div class="od-widget-head"><h3>Coming soon</h3></div>
				<div class="od-widget-body">
					<ul class="od-soon-list">
						<li><i class="fas fa-pen-nib"></i> Inline propose-a-recommendation</li>
						<li><i class="fas fa-palette"></i> Park A&amp;S night calendar</li>
						<li><i class="fas fa-trophy"></i> Park bardic/craft competition log</li>
					</ul>
				</div>
			</div>
		</div>
	</div>
</div>
