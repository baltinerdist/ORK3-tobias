<?php
	// --- ingest data keys with safe defaults ---
	$recs              = $ocData['recommendations']      ?? [];
	$unsung            = $ocData['unsungMembers']        ?? [];
	$awardDensity      = $ocData['awardDensity']         ?? [];
	$topRecommenders   = $ocData['topRecommenders']      ?? [];
	$recentAwards      = $ocData['recentAwards']         ?? [];
	$parksWithoutRegent= $ocData['parksWithoutRegent']   ?? [];
	$recsCosign        = $ocData['recsAwaitingCosign']   ?? [];
	$recAgeBuckets     = $ocData['recAgeBuckets']        ?? [0,0,0,0];
	$bestowalTrend     = $ocData['bestowalTrend']        ?? [];
	$peerageRoster     = $ocData['peerageRoster']        ?? [];
	$ladderDist        = $ocData['ladderDistribution']   ?? [];
	$recsByMe          = $ocData['recsByMe']             ?? [];
	$ladderStalled     = $ocData['ladderStalled']        ?? [];
	$peerageCand       = $ocData['peerageCandidates']    ?? [];
	$longTenured       = $ocData['longTenuredNoPeerage'] ?? [];
	$attNoAward        = $ocData['attendeeNoAward']      ?? [];
	$awardCats         = $ocData['awardCategories']      ?? [];
	$topAwardNames     = $ocData['topAwardNames']        ?? [];
	$recogCov          = $ocData['recognitionCoverage']  ?? ['Total'=>0,'Recognized'=>0,'Percent'=>0];
	$densityMatrix     = $ocData['densityMatrix']        ?? [];
	$catalogInv        = $ocData['catalogInventory']     ?? [];
	$attSpark          = $ocData['attendanceSpark']      ?? [];
	$parkRecent        = $ocData['parkRecentBestowals']  ?? [];
	$dormantParks      = $ocData['dormantParks']         ?? [];
	$bestowalsFeed     = $ocData['recentBestowalsFeed']  ?? [];
	$currentTitles     = $ocData['currentTitles']        ?? [];
	$parkRegentCount   = (int)($ocData['parkRegentCount']?? 0);
	$topBestowers      = $ocData['topBestowers']         ?? [];
	$awardsThisTerm    = (int)($ocData['awardsThisTerm'] ?? 0);

	// Derived
	$openRecCount      = count($recs);
	$unsungCount       = count($unsung);
	$parksTotal        = count($densityMatrix);
	$lowDensityCount   = 0;
	foreach ($densityMatrix as $d) { if ((float)$d['Ratio'] < 0.10 && (int)$d['Active180'] > 5) $lowDensityCount++; }
	$knightCount = 0;
	foreach ($peerageRoster as $p) { if (in_array($p['Peerage'], ['Knight','Master','Paragon'])) $knightCount += (int)$p['Count']; }
?>

<!-- =====================================================
     Top stat cards: at-a-glance
===================================================== -->
<div class="od-grid">
	<div class="od-stat-card"><div class="od-stat-num"><?= $openRecCount ?></div><div class="od-stat-lbl">Pending recommendations</div></div>
	<div class="od-stat-card"><div class="od-stat-num"><?= $unsungCount ?></div><div class="od-stat-lbl">Unsung active members</div></div>
	<div class="od-stat-card"><div class="od-stat-num"><?= $awardsThisTerm ?></div><div class="od-stat-lbl">Awards bestowed (90d)</div></div>
	<div class="od-stat-card"><div class="od-stat-num"><?= $lowDensityCount ?></div><div class="od-stat-lbl">Chapters w/ low density</div></div>
	<div class="od-stat-card"><div class="od-stat-num"><?= $knightCount ?></div><div class="od-stat-lbl">Peerage in kingdom</div></div>
	<div class="od-stat-card"><div class="od-stat-num"><?= (int)$recogCov['Percent'] ?>%</div><div class="od-stat-lbl">Active members recognized</div></div>
</div>

<!-- =====================================================
     SECTION: Award Recommendation Pipeline
===================================================== -->
<div class="od-section">
	<div class="od-section-head">
		<h3 class="od-section-title"><i class="fas fa-scroll"></i> Award Recommendation Pipeline</h3>
		<i class="fas fa-chevron-down od-section-caret"></i>
	</div>
	<div class="od-section-body">

		<div class="od-widget-row">
			<div class="od-widget od-widget-wide">
				<div class="od-widget-head"><h3>Open Recommendations</h3>
					<a class="od-link" href="<?= UIR ?>Reports/recommendations/<?= (int)$kingdom_id ?>">Full queue<i class="fas fa-arrow-right"></i></a>
				</div>
				<div class="od-widget-body">
					<?php if (empty($recs)): ?>
						<div class="od-empty">No open recommendations.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Player</th><th>Award</th><th>Recommender</th><th>Date</th></tr></thead>
							<tbody>
								<?php foreach ($recs as $r): ?>
									<tr>
										<td><a href="<?= UIR ?>Player/profile/<?= (int)($r['MundaneId'] ?? 0) ?>"><?= htmlspecialchars($r['Persona'] ?? '—') ?></a></td>
										<td><?= htmlspecialchars($r['Award'] ?? '—') ?></td>
										<td><?= htmlspecialchars($r['RecommendedBy'] ?? '—') ?></td>
										<td><?= htmlspecialchars(substr($r['Date'] ?? '',0,10)) ?></td>
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
				<div class="od-widget-head"><h3>Pipeline Age</h3>
					<span class="od-subline">How old is the queue?</span>
				</div>
				<div class="od-widget-body">
					<?php $total = array_sum($recAgeBuckets); if ($total <= 0): ?>
						<div class="od-empty">No open recommendations.</div>
					<?php else: ?>
						<svg class="od-chart od-chart-donut"
							data-values="<?= implode(',', array_map('intval',$recAgeBuckets)) ?>"
							data-labels="&lt;=30d|31-90d|91-180d|&gt;180d"
							data-center-label="Open"></svg>
					<?php endif; ?>
				</div>
			</div>

			<div class="od-widget">
				<div class="od-widget-head"><h3>Awaiting Monarch Co-Sign</h3>
					<span class="od-subline">Open &gt;30 days</span>
				</div>
				<div class="od-widget-body">
					<?php if (empty($recsCosign)): ?>
						<div class="od-empty od-empty-ok"><i class="fas fa-check-circle"></i> Nothing stale.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Player</th><th>Award</th><th>Age</th></tr></thead>
							<tbody>
								<?php foreach ($recsCosign as $r): ?>
									<tr>
										<td><a href="<?= UIR ?>Player/profile/<?= (int)$r['MundaneId'] ?>"><?= htmlspecialchars($r['Persona']) ?></a></td>
										<td><?= htmlspecialchars($r['Award'] ?? '—') ?></td>
										<td><span class="od-pill <?= (int)$r['AgeDays'] > 180 ? 'od-pill-warn' : '' ?>"><?= (int)$r['AgeDays'] ?>d</span></td>
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
				<div class="od-widget-head"><h3>Recommendations I've Written</h3></div>
				<div class="od-widget-body">
					<?php if (empty($recsByMe)): ?>
						<div class="od-empty">You haven't written a recommendation yet.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Player</th><th>Award</th><th>Date</th><th>Status</th></tr></thead>
							<tbody>
								<?php foreach ($recsByMe as $r): ?>
									<tr>
										<td><a href="<?= UIR ?>Player/profile/<?= (int)$r['MundaneId'] ?>"><?= htmlspecialchars($r['Persona']) ?></a></td>
										<td><?= htmlspecialchars($r['Award'] ?? '—') ?></td>
										<td><?= htmlspecialchars(substr($r['Date'] ?? '',0,10)) ?></td>
										<td><span class="od-pill <?= $r['Status']==='open' ? 'od-pill-ok' : '' ?>"><?= htmlspecialchars($r['Status']) ?></span></td>
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
					<?php else:
						$vals = array_map(fn($r) => (int)$r['RecCount'], $topRecommenders);
						$labs = array_map(fn($r) => $r['Persona'] ?? '—', $topRecommenders);
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
		<h3 class="od-section-title"><i class="fas fa-user-clock"></i> Unsung Members &amp; Candidates</h3>
		<i class="fas fa-chevron-down od-section-caret"></i>
	</div>
	<div class="od-section-body">

		<div class="od-widget-row">
			<div class="od-widget od-widget-wide">
				<div class="od-widget-head"><h3>Unsung Active Members</h3>
					<span class="od-subline">Attending, no award in 12+ months</span>
				</div>
				<div class="od-widget-body">
					<?php if (empty($unsung)): ?>
						<div class="od-empty od-empty-ok"><i class="fas fa-check-circle"></i> Everyone active has been recognized recently.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Player</th><th>Chapter</th><th>Last award</th><th>Attendance (90d)</th></tr></thead>
							<tbody>
								<?php foreach ($unsung as $u): ?>
									<tr>
										<td><a href="<?= UIR ?>Player/profile/<?= (int)($u['MundaneId'] ?? 0) ?>"><?= htmlspecialchars($u['Persona'] ?? '—') ?></a></td>
										<td><?= htmlspecialchars($u['ParkName'] ?? '—') ?></td>
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
				<div class="od-widget-head"><h3>Peerage Candidates</h3>
					<span class="od-subline">No peerage, heavy attendance</span>
				</div>
				<div class="od-widget-body">
					<?php if (empty($peerageCand)): ?>
						<div class="od-empty">No candidates surfacing yet.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Player</th><th>Chapter</th><th>Att. (180d)</th></tr></thead>
							<tbody>
							<?php foreach ($peerageCand as $c): ?>
								<tr><td><a href="<?= UIR ?>Player/profile/<?= (int)$c['MundaneId'] ?>"><?= htmlspecialchars($c['Persona']) ?></a></td>
									<td><?= htmlspecialchars($c['ParkName'] ?? '—') ?></td>
									<td><?= (int)$c['Attend180'] ?></td></tr>
							<?php endforeach; ?>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>

			<div class="od-widget">
				<div class="od-widget-head"><h3>Ladder Stalled 2+ Years</h3>
					<span class="od-subline">Attending but not advancing</span>
				</div>
				<div class="od-widget-body">
					<?php if (empty($ladderStalled)): ?>
						<div class="od-empty od-empty-ok"><i class="fas fa-check-circle"></i> No stalled ladders.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Player</th><th>Award</th><th>Rank</th><th>Since</th></tr></thead>
							<tbody>
							<?php foreach ($ladderStalled as $s): ?>
								<tr><td><a href="<?= UIR ?>Player/profile/<?= (int)$s['MundaneId'] ?>"><?= htmlspecialchars($s['Persona']) ?></a></td>
									<td><?= htmlspecialchars($s['Award'] ?? '—') ?></td>
									<td><?= (int)$s['CurrentRank'] ?></td>
									<td><?= htmlspecialchars($s['LastRankDate']) ?></td></tr>
							<?php endforeach; ?>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>
		</div>

		<div class="od-widget-row">
			<div class="od-widget">
				<div class="od-widget-head"><h3>Long-Tenured, No Peerage</h3>
					<span class="od-subline">Member for 5+ years</span>
				</div>
				<div class="od-widget-body">
					<?php if (empty($longTenured)): ?>
						<div class="od-empty">No matches.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Player</th><th>Chapter</th><th>Member since</th></tr></thead>
							<tbody>
							<?php foreach ($longTenured as $p): ?>
								<tr><td><a href="<?= UIR ?>Player/profile/<?= (int)$p['MundaneId'] ?>"><?= htmlspecialchars($p['Persona']) ?></a></td>
									<td><?= htmlspecialchars($p['ParkName'] ?? '—') ?></td>
									<td><?= htmlspecialchars($p['MemberSince']) ?></td></tr>
							<?php endforeach; ?>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>

			<div class="od-widget">
				<div class="od-widget-head"><h3>Top Attendees, No Recent Award</h3>
					<span class="od-subline">Prime recommendation targets</span>
				</div>
				<div class="od-widget-body">
					<?php if (empty($attNoAward)): ?>
						<div class="od-empty">No data.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="5">
							<thead><tr><th>Player</th><th>Chapter</th><th>Credits 90d</th><th>Last award</th></tr></thead>
							<tbody>
							<?php foreach ($attNoAward as $p): ?>
								<tr><td><a href="<?= UIR ?>Player/profile/<?= (int)$p['MundaneId'] ?>"><?= htmlspecialchars($p['Persona']) ?></a></td>
									<td><?= htmlspecialchars($p['ParkName'] ?? '—') ?></td>
									<td><?= (int)$p['Credits90'] ?></td>
									<td><?= htmlspecialchars($p['LastAward']) ?></td></tr>
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
     SECTION: Distribution & Density
===================================================== -->
<div class="od-section">
	<div class="od-section-head">
		<h3 class="od-section-title"><i class="fas fa-chart-pie"></i> Distribution &amp; Density</h3>
		<i class="fas fa-chevron-down od-section-caret"></i>
	</div>
	<div class="od-section-body">

		<div class="od-widget-row">
			<div class="od-widget">
				<div class="od-widget-head"><h3>Award Category Mix (12mo)</h3></div>
				<div class="od-widget-body">
					<?php if (empty($awardCats)): ?>
						<div class="od-empty">No awards bestowed in window.</div>
					<?php else:
						$vals = array_map(fn($r) => (int)$r['Count'], $awardCats);
						$labs = array_map(fn($r) => $r['Category'], $awardCats);
						$total = array_sum($vals);
					?>
						<svg class="od-chart od-chart-donut"
							data-values="<?= htmlspecialchars(implode(',', $vals)) ?>"
							data-labels="<?= htmlspecialchars(implode('|', $labs)) ?>"
							data-center-label="Total"></svg>
					<?php endif; ?>
				</div>
			</div>

			<div class="od-widget">
				<div class="od-widget-head"><h3>Peerage Roster</h3>
					<span class="od-subline">Active kingdom members</span>
				</div>
				<div class="od-widget-body">
					<?php if (empty($peerageRoster)): ?>
						<div class="od-empty">No peerage data.</div>
					<?php else:
						$vals = array_map(fn($r) => (int)$r['Count'], $peerageRoster);
						$labs = array_map(fn($r) => $r['Peerage'], $peerageRoster);
					?>
						<svg class="od-chart od-chart-pie"
							data-values="<?= htmlspecialchars(implode(',', $vals)) ?>"
							data-labels="<?= htmlspecialchars(implode('|', $labs)) ?>"></svg>
					<?php endif; ?>
				</div>
			</div>

			<div class="od-widget">
				<div class="od-widget-head"><h3>Recognition Coverage</h3>
					<span class="od-subline">Active members w/ &ge;1 award</span>
				</div>
				<div class="od-widget-body">
					<svg class="od-chart od-chart-ring"
						data-value="<?= (float)$recogCov['Percent'] ?>"
						data-max="100"
						data-display="<?= (float)$recogCov['Percent'] ?>%"
						data-label="Recognized"></svg>
					<div style="text-align:center;font-size:12px;color:var(--ork-text-secondary);margin-top:4px;">
						<?= (int)$recogCov['Recognized'] ?> of <?= (int)$recogCov['Total'] ?>
					</div>
				</div>
			</div>
		</div>

		<div class="od-widget-row">
			<div class="od-widget od-widget-wide">
				<div class="od-widget-head"><h3>Bestowal Trend (12 months)</h3></div>
				<div class="od-widget-body">
					<?php if (empty($bestowalTrend)): ?>
						<div class="od-empty">No data.</div>
					<?php else:
						$vals = array_map(fn($m) => (int)$m['Count'], $bestowalTrend);
						$labs = array_map(fn($m) => substr($m['Month'],5,2), $bestowalTrend);
					?>
						<svg class="od-chart od-chart-bar"
							data-values="<?= htmlspecialchars(implode(',', $vals)) ?>"
							data-labels="<?= htmlspecialchars(implode('|', $labs)) ?>"></svg>
					<?php endif; ?>
				</div>
			</div>
		</div>

		<div class="od-widget-row">
			<div class="od-widget od-widget-wide">
				<div class="od-widget-head"><h3>Awards Bestowed Per Chapter (90d)</h3></div>
				<div class="od-widget-body">
					<?php if (empty($parkRecent)): ?>
						<div class="od-empty">No chapter data.</div>
					<?php else:
						$vals = array_map(fn($r) => (int)$r['Count'], $parkRecent);
						$labs = array_map(fn($r) => $r['ParkName'], $parkRecent);
					?>
						<svg class="od-chart od-chart-bar" data-orientation="horizontal"
							data-values="<?= htmlspecialchars(implode(',', $vals)) ?>"
							data-labels="<?= htmlspecialchars(implode('|', $labs)) ?>"></svg>
					<?php endif; ?>
				</div>
			</div>
		</div>

		<div class="od-widget-row">
			<div class="od-widget od-widget-wide">
				<div class="od-widget-head"><h3>Density Matrix (180d)</h3>
					<span class="od-subline">Awards per active member</span>
				</div>
				<div class="od-widget-body">
					<?php if (empty($densityMatrix)): ?>
						<div class="od-empty">No chapter data.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="8">
							<thead><tr><th>Chapter</th><th>Awards 180d</th><th>Distinct recipients</th><th>Active 180d</th><th>Ratio</th></tr></thead>
							<tbody>
								<?php foreach ($densityMatrix as $d): ?>
									<tr>
										<td><a href="<?= UIR ?>Park/profile/<?= (int)$d['ParkId'] ?>"><?= htmlspecialchars($d['ParkName']) ?></a></td>
										<td><?= (int)$d['Awards180'] ?></td>
										<td><?= (int)$d['Recipients'] ?></td>
										<td><?= (int)$d['Active180'] ?></td>
										<td><strong><?= number_format((float)$d['Ratio'], 2) ?></strong></td>
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
				<div class="od-widget-head"><h3>Top Award Titles Bestowed (12mo)</h3></div>
				<div class="od-widget-body">
					<?php if (empty($topAwardNames)): ?>
						<div class="od-empty">No awards logged.</div>
					<?php else:
						$vals = array_map(fn($r) => (int)$r['Count'], $topAwardNames);
						$labs = array_map(fn($r) => $r['Award'], $topAwardNames);
					?>
						<svg class="od-chart od-chart-bar" data-orientation="horizontal"
							data-values="<?= htmlspecialchars(implode(',', $vals)) ?>"
							data-labels="<?= htmlspecialchars(implode('|', $labs)) ?>"></svg>
					<?php endif; ?>
				</div>
			</div>

			<div class="od-widget">
				<div class="od-widget-head"><h3>Ladder Rank Distribution</h3></div>
				<div class="od-widget-body">
					<?php if (empty($ladderDist)): ?>
						<div class="od-empty">No ladder data.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="6">
							<thead><tr><th>Award</th><th>Rank</th><th>Holders</th></tr></thead>
							<tbody>
							<?php foreach ($ladderDist as $ld): ?>
								<tr><td><?= htmlspecialchars($ld['Award']) ?></td>
									<td><span class="od-pill">R<?= (int)$ld['Rank'] ?></span></td>
									<td><?= (int)$ld['Count'] ?></td></tr>
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
     SECTION: Chapter Coverage
===================================================== -->
<div class="od-section">
	<div class="od-section-head">
		<h3 class="od-section-title"><i class="fas fa-map"></i> Chapter Coverage</h3>
		<i class="fas fa-chevron-down od-section-caret"></i>
	</div>
	<div class="od-section-body">

		<div class="od-widget-row">
			<div class="od-widget">
				<div class="od-widget-head"><h3>Chapter Regent Coverage</h3></div>
				<div class="od-widget-body">
					<?php
						$parksTotalCount = $parksTotal ?: count($awardDensity);
						$coverage = $parksTotalCount > 0 ? round(100.0 * $parkRegentCount / $parksTotalCount, 1) : 0;
					?>
					<svg class="od-chart od-chart-ring"
						data-value="<?= (float)$coverage ?>"
						data-max="100"
						data-display="<?= (int)$parkRegentCount ?>/<?= (int)$parksTotalCount ?>"
						data-label="Chapters w/ Regent"></svg>
				</div>
			</div>

			<div class="od-widget">
				<div class="od-widget-head"><h3>Parks Without Regent</h3></div>
				<div class="od-widget-body">
					<?php if (empty($parksWithoutRegent)): ?>
						<div class="od-empty od-empty-ok"><i class="fas fa-check-circle"></i> Every chapter has a Regent.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="6">
							<thead><tr><th>Park</th></tr></thead>
							<tbody>
							<?php foreach ($parksWithoutRegent as $p): ?>
								<tr><td><a href="<?= UIR ?>Park/profile/<?= (int)$p['ParkId'] ?>"><?= htmlspecialchars($p['ParkName']) ?></a></td></tr>
							<?php endforeach; ?>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>
		</div>

		<div class="od-widget-row">
			<div class="od-widget od-widget-wide">
				<div class="od-widget-head"><h3>Dormant Parks (no awards 90d)</h3>
					<span class="od-subline">Active attendance but silent court</span>
				</div>
				<div class="od-widget-body">
					<?php if (empty($dormantParks)): ?>
						<div class="od-empty od-empty-ok"><i class="fas fa-check-circle"></i> No dormant chapters.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="6">
							<thead><tr><th>Park</th><th>Last award</th><th>Active (90d)</th></tr></thead>
							<tbody>
							<?php foreach ($dormantParks as $d): ?>
								<tr><td><a href="<?= UIR ?>Park/profile/<?= (int)$d['ParkId'] ?>"><?= htmlspecialchars($d['ParkName']) ?></a></td>
									<td><?= htmlspecialchars($d['LastAward']) ?></td>
									<td><?= (int)$d['Active90'] ?></td></tr>
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
     SECTION: Recent Activity
===================================================== -->
<div class="od-section">
	<div class="od-section-head">
		<h3 class="od-section-title"><i class="fas fa-stream"></i> Recent Activity</h3>
		<i class="fas fa-chevron-down od-section-caret"></i>
	</div>
	<div class="od-section-body">

		<div class="od-widget-row">
			<div class="od-widget od-widget-wide">
				<div class="od-widget-head"><h3>Recent Bestowals Feed (60d)</h3></div>
				<div class="od-widget-body">
					<?php if (empty($bestowalsFeed)): ?>
						<div class="od-empty">No recent bestowals.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="6">
							<thead><tr><th>Player</th><th>Award</th><th>Given by</th><th>Chapter</th><th>Date</th></tr></thead>
							<tbody>
							<?php foreach ($bestowalsFeed as $a): ?>
								<tr><td><a href="<?= UIR ?>Player/profile/<?= (int)$a['MundaneId'] ?>"><?= htmlspecialchars($a['Persona']) ?></a></td>
									<td><?= htmlspecialchars($a['Award'] ?? '—') ?></td>
									<td><?= htmlspecialchars($a['GivenBy'] ?? '—') ?></td>
									<td><?= htmlspecialchars($a['ParkName'] ?? '—') ?></td>
									<td><?= htmlspecialchars(substr($a['AwardDate'] ?? '',0,10)) ?></td></tr>
							<?php endforeach; ?>
							</tbody>
						</table>
					<?php endif; ?>
				</div>
			</div>
		</div>

		<div class="od-widget-row">
			<div class="od-widget">
				<div class="od-widget-head"><h3>Top Bestowers (12mo)</h3>
					<span class="od-subline">Who is giving the awards?</span>
				</div>
				<div class="od-widget-body">
					<?php if (empty($topBestowers)): ?>
						<div class="od-empty">No data.</div>
					<?php else:
						$vals = array_map(fn($r) => (int)$r['Count'], $topBestowers);
						$labs = array_map(fn($r) => $r['Persona'], $topBestowers);
					?>
						<svg class="od-chart od-chart-bar" data-orientation="horizontal"
							data-values="<?= htmlspecialchars(implode(',', $vals)) ?>"
							data-labels="<?= htmlspecialchars(implode('|', $labs)) ?>"></svg>
					<?php endif; ?>
				</div>
			</div>

			<div class="od-widget">
				<div class="od-widget-head"><h3>Kingdom Attendance Pulse</h3>
					<span class="od-subline">Unique attendees per week, 12w</span>
				</div>
				<div class="od-widget-body">
					<?php if (empty($attSpark)): ?>
						<div class="od-empty">No attendance.</div>
					<?php else: ?>
						<svg class="od-spark" viewBox="0 0 240 48" preserveAspectRatio="none"
							data-values="<?= htmlspecialchars(implode(',', array_map('intval', $attSpark))) ?>"></svg>
						<div style="display:flex;justify-content:space-between;font-size:11px;color:var(--ork-text-secondary);margin-top:4px;">
							<span>12w ago</span>
							<span>Peak: <?= (int)max($attSpark) ?></span>
							<span>now</span>
						</div>
					<?php endif; ?>
				</div>
			</div>
		</div>

		<div class="od-widget-row">
			<div class="od-widget od-widget-wide">
				<div class="od-widget-head"><h3>Current Titles Held</h3>
					<span class="od-subline">Active title-award holders</span>
				</div>
				<div class="od-widget-body">
					<?php if (empty($currentTitles)): ?>
						<div class="od-empty">No titles currently held.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="6">
							<thead><tr><th>Player</th><th>Title</th><th>Since</th></tr></thead>
							<tbody>
							<?php foreach ($currentTitles as $t): ?>
								<tr><td><a href="<?= UIR ?>Player/profile/<?= (int)$t['MundaneId'] ?>"><?= htmlspecialchars($t['Persona']) ?></a></td>
									<td><?= htmlspecialchars($t['Title']) ?></td>
									<td><?= htmlspecialchars($t['DateGiven']) ?></td></tr>
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
     SECTION: Quick Actions & Tools (closed)
===================================================== -->
<div class="od-section od-section-closed">
	<div class="od-section-head">
		<h3 class="od-section-title"><i class="fas fa-tools"></i> Quick Actions &amp; Catalog</h3>
		<i class="fas fa-chevron-down od-section-caret"></i>
	</div>
	<div class="od-section-body">

		<div class="od-widget-row">
			<div class="od-widget od-widget-wide">
				<div class="od-widget-head"><h3>Quick Links</h3></div>
				<div class="od-widget-body">
					<div class="od-links-grid">
						<a class="od-link-card" href="<?= UIR ?>Reports/recommendations/<?= (int)$kingdom_id ?>"><i class="fas fa-scroll"></i><span>Full recommendations queue</span></a>
						<a class="od-link-card" href="<?= UIR ?>Reports/awards/<?= (int)$kingdom_id ?>"><i class="fas fa-medal"></i><span>Kingdom award report</span></a>
						<a class="od-link-card" href="<?= UIR ?>Reports/attendance/<?= (int)$kingdom_id ?>"><i class="fas fa-user-check"></i><span>Attendance report</span></a>
						<a class="od-link-card" href="<?= UIR ?>Kingdomaward/list/<?= (int)$kingdom_id ?>"><i class="fas fa-book"></i><span>Kingdom award catalog</span></a>
						<a class="od-link-card" href="<?= UIR ?>Admin/kingdom/<?= (int)$kingdom_id ?>"><i class="fas fa-cog"></i><span>Kingdom admin</span></a>
					</div>
				</div>
			</div>
		</div>

		<div class="od-widget-row">
			<div class="od-widget od-widget-wide">
				<div class="od-widget-head"><h3>Kingdom Award Catalog Inventory</h3>
					<span class="od-subline">Top 12 by lifetime bestowal</span>
				</div>
				<div class="od-widget-body">
					<?php if (empty($catalogInv)): ?>
						<div class="od-empty">No catalog entries.</div>
					<?php else: ?>
						<table class="od-table od-table-compact" data-od-paginate="6">
							<thead><tr><th>Award</th><th>Type</th><th>Reign limit</th><th>Month limit</th><th>Bestowed</th></tr></thead>
							<tbody>
							<?php foreach ($catalogInv as $c): ?>
								<tr>
									<td><?= htmlspecialchars($c['Name']) ?></td>
									<td>
										<?php
											$t = [];
											if ((int)$c['IsTitle']) $t[] = 'Title';
											if ((int)$c['IsLadder']) $t[] = 'Ladder';
											if (!$t) $t[] = 'Merit';
											echo htmlspecialchars(implode(' / ', $t));
										?>
									</td>
									<td><?= (int)$c['ReignLimit'] ?: '—' ?></td>
									<td><?= (int)$c['MonthLimit'] ?: '—' ?></td>
									<td><strong><?= (int)$c['Bestowed'] ?></strong></td>
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
				<div class="od-widget-head"><h3>Coming soon</h3></div>
				<div class="od-widget-body">
					<ul class="od-soon-list">
						<li><i class="fas fa-handshake"></i> One-click co-sign on pending recommendations</li>
						<li><i class="fas fa-gavel"></i> Courts of Honor scheduler</li>
						<li><i class="fas fa-palette"></i> A&amp;S competition calendar &amp; results</li>
						<li><i class="fas fa-hourglass-half"></i> Dragonmaster / major award countdowns</li>
					</ul>
				</div>
			</div>
		</div>
	</div>
</div>
