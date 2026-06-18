<?php
	// Champion × Kingdom dashboard
	$tourneys            = $ocData['tournaments'] ?? [];
	$recentTourneys      = $ocData['recentTourneys'] ?? [];
	$knightsByOrder      = $ocData['knightsByOrder'] ?? [];
	$peerageDist         = $ocData['peerageDist'] ?? [];
	$knightCandidates    = $ocData['knightCandidates'] ?? [];
	$squireCandidates    = $ocData['squireCandidates'] ?? [];
	$maaCandidates       = $ocData['maaCandidates'] ?? [];
	$pageCandidates      = $ocData['pageCandidates'] ?? [];
	$lordsPageCandidates = $ocData['lordsPageCandidates'] ?? [];
	$warriorLadder       = $ocData['warriorLadder'] ?? [];
	$warlordCandidates   = $ocData['warlordCandidates'] ?? [];
	$tourneysByPark      = $ocData['tourneysByPark'] ?? [];
	$tourneysByStatus    = $ocData['tourneysByStatus'] ?? [];
	$tourneysByMonth     = $ocData['tourneysByMonth'] ?? [];
	$tourneyFormatMix    = $ocData['tourneyFormatMix'] ?? [];
	$crownQuals          = $ocData['crownQuals'] ?? [];
	$nextCrown           = $ocData['nextCrownCountdown'] ?? null;
	$fightersByPark      = $ocData['fightersByPark'] ?? [];
	$tourneyHeatmap      = $ocData['tourneyHeatmap'] ?? ['rows'=>[], 'rowLabels'=>[], 'colLabels'=>[]];
	$fighterHeatmap      = $ocData['fighterHeatmap'] ?? ['rows'=>[], 'rowLabels'=>[], 'colLabels'=>[]];
	$parkChampCoverage   = $ocData['parkChampCoverage'] ?? [];
	$topFighters         = $ocData['topFighters'] ?? [];
	$martialAwardsRecent = $ocData['martialAwardsRecent'] ?? [];
	$newlyKnighted       = $ocData['newlyKnighted'] ?? [];
	$parkKnightDensity   = $ocData['parkKnightDensity'] ?? [];
	$activeByWeek        = $ocData['activeByWeek'] ?? [];
	$parksWithoutChampList = $ocData['parksWithoutChampionList'] ?? [];
	$activeFighters      = (int)($ocData['activeFighters'] ?? 0);
	$knightsTotal        = (int)($ocData['knightsTotal'] ?? 0);
	$upE                 = $ocData['upcomingEvents'] ?? [];

	// Helper: matrix -> "r1c1,r1c2;r2c1,..."
	$matrixToAttr = function($rows) {
		return implode(';', array_map(function($r) { return implode(',', array_map('intval', $r)); }, $rows));
	};
	// Approximate activity %: active fighters out of all active mundanes in kingdom (capped at 100).
	$activityPct = $activeFighters > 0 ? min(100, (int)round(($activeFighters / max(1, $activeFighters + count($parksWithoutChampList) * 2)) * 100)) : 0;
?>
		<!-- At-a-glance -->
		<div class="od-grid">
			<div class="od-stat-card"><div class="od-stat-num"><?= (int)count($tourneys) ?></div><div class="od-stat-lbl">Upcoming tourneys</div></div>
			<div class="od-stat-card"><div class="od-stat-num"><?= $activeFighters ?></div><div class="od-stat-lbl">Active fighters (90d)</div></div>
			<div class="od-stat-card"><div class="od-stat-num"><?= $knightsTotal ?></div><div class="od-stat-lbl">Knights in kingdom</div></div>
			<div class="od-stat-card"><div class="od-stat-num"><?= (int)count($knightCandidates) ?></div><div class="od-stat-lbl">Knight candidates</div></div>
			<div class="od-stat-card"><div class="od-stat-num"><?= (int)($ocData['parksWithoutChampion'] ?? 0) ?></div><div class="od-stat-lbl">Parks w/out Champion</div></div>
			<div class="od-stat-card">
				<div class="od-stat-num"><?= $nextCrown ? (int)$nextCrown['DaysUntil'] : '—' ?></div>
				<div class="od-stat-lbl"><?= $nextCrown ? 'Days to next Crown Qual' : 'No upcoming Crown Qual' ?></div>
			</div>
		</div>

		<!-- ============================================================ -->
		<!-- SECTION 1: Tournaments -->
		<!-- ============================================================ -->
		<div class="od-section">
			<div class="od-section-head">
				<h3 class="od-section-title"><i class="fas fa-trophy"></i> Tournaments</h3>
				<i class="fas fa-chevron-down od-section-caret"></i>
			</div>
			<div class="od-section-body">
				<div class="od-widget-row">
					<div class="od-widget od-widget-wide">
						<div class="od-widget-head"><h3>Upcoming Kingdom Tournaments</h3>
							<a class="od-link" href="<?= UIR ?>Reports/tournaments/<?= (int)$kingdom_id ?>">All tournaments<i class="fas fa-arrow-right"></i></a>
						</div>
						<div class="od-widget-body">
							<?php if (empty($tourneys)): ?><div class="od-empty">No kingdom tournaments on calendar.</div>
							<?php else: ?>
								<table class="od-table od-table-compact" data-od-paginate="5">
									<thead><tr><th>Tournament</th><th>Date</th><th>Park</th></tr></thead>
									<tbody>
										<?php foreach ($tourneys as $t): ?>
											<tr>
												<td><?= htmlspecialchars($t['Name'] ?? '—') ?></td>
												<td><?= htmlspecialchars(substr($t['Date'] ?? '',0,10)) ?></td>
												<td><?= htmlspecialchars($t['ParkName'] ?? '—') ?></td>
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
						<div class="od-widget-head"><h3>Recently Completed Tourneys</h3></div>
						<div class="od-widget-body">
							<?php if (empty($recentTourneys)): ?><div class="od-empty">No recent tournaments logged.</div>
							<?php else: ?>
								<table class="od-table od-table-compact" data-od-paginate="5">
									<thead><tr><th>Tournament</th><th>Date</th><th>Park</th><th>Status</th></tr></thead>
									<tbody>
										<?php foreach ($recentTourneys as $t): ?>
											<tr>
												<td><?= htmlspecialchars($t['Name']) ?></td>
												<td><?= htmlspecialchars($t['Date']) ?></td>
												<td><a href="<?= UIR ?>Park/profile/<?= (int)$t['ParkId'] ?>"><?= htmlspecialchars($t['ParkName'] ?? '—') ?></a></td>
												<td><span class="od-badge"><?= htmlspecialchars($t['Status']) ?></span></td>
											</tr>
										<?php endforeach; ?>
									</tbody>
								</table>
							<?php endif; ?>
						</div>
					</div>

					<div class="od-widget">
						<div class="od-widget-head"><h3>Tournament Status Mix</h3></div>
						<div class="od-widget-body">
							<?php if (empty($tourneysByStatus)): ?><div class="od-empty">No tournament data.</div>
							<?php else:
								$vals = array_map(function($r){ return (int)$r['Count']; }, $tourneysByStatus);
								$lbls = array_map(function($r){ return ucfirst($r['Status']); }, $tourneysByStatus);
							?>
								<svg class="od-chart od-chart-donut"
									data-values="<?= htmlspecialchars(implode(',',$vals)) ?>"
									data-labels="<?= htmlspecialchars(implode('|',$lbls)) ?>"
									data-center-label="Tourneys"></svg>
							<?php endif; ?>
						</div>
					</div>
				</div>

				<div class="od-widget-row">
					<div class="od-widget">
						<div class="od-widget-head"><h3>Tourneys by Month (12 mo)</h3></div>
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

					<div class="od-widget">
						<div class="od-widget-head"><h3>Tourney Format Mix</h3><span class="od-subline">Inferred from name</span></div>
						<div class="od-widget-body">
							<?php if (empty($tourneyFormatMix)): ?><div class="od-empty">No data.</div>
							<?php else:
								$vals = array_map(function($r){ return (int)$r['Count']; }, $tourneyFormatMix);
								$lbls = array_map(function($r){ return $r['Format']; }, $tourneyFormatMix);
							?>
								<svg class="od-chart od-chart-pie"
									data-values="<?= htmlspecialchars(implode(',',$vals)) ?>"
									data-labels="<?= htmlspecialchars(implode('|',$lbls)) ?>"></svg>
							<?php endif; ?>
						</div>
					</div>

					<div class="od-widget">
						<div class="od-widget-head"><h3>Most Active Tourney Parks</h3></div>
						<div class="od-widget-body">
							<?php if (empty($tourneysByPark)): ?><div class="od-empty">No tourneys last 12 months.</div>
							<?php else:
								$vals = array_map(function($r){ return (int)$r['Count']; }, $tourneysByPark);
								$lbls = array_map(function($r){ return (string)$r['ParkName']; }, $tourneysByPark);
							?>
								<svg class="od-chart od-chart-bar" data-orientation="horizontal"
									data-values="<?= htmlspecialchars(implode(',',$vals)) ?>"
									data-labels="<?= htmlspecialchars(implode('|',$lbls)) ?>"></svg>
							<?php endif; ?>
						</div>
					</div>
				</div>

				<div class="od-widget-row">
					<div class="od-widget od-widget-wide">
						<div class="od-widget-head"><h3>Tournament Schedule Heatmap (parks × weeks)</h3></div>
						<div class="od-widget-body">
							<?php if (empty($tourneyHeatmap['rows'])): ?><div class="od-empty">No tourneys in the last 10 weeks.</div>
							<?php else: ?>
								<svg class="od-chart od-chart-heatmap"
									data-matrix="<?= htmlspecialchars($matrixToAttr($tourneyHeatmap['rows'])) ?>"
									data-rows="<?= htmlspecialchars(implode('|', $tourneyHeatmap['rowLabels'])) ?>"
									data-cols="<?= htmlspecialchars(implode('|', $tourneyHeatmap['colLabels'])) ?>"></svg>
							<?php endif; ?>
						</div>
					</div>
				</div>

				<div class="od-widget-row">
					<div class="od-widget">
						<div class="od-widget-head"><h3>Crown Qualification Status</h3></div>
						<div class="od-widget-body">
							<?php if (empty($crownQuals)): ?>
								<div class="od-empty">No Crown-related tournaments found in the last 180 days.</div>
							<?php else: ?>
								<table class="od-table od-table-compact" data-od-paginate="5">
									<thead><tr><th>Tournament</th><th>Date</th><th>Park</th><th>Status</th></tr></thead>
									<tbody>
									<?php foreach ($crownQuals as $c): ?>
										<tr>
											<td><?= htmlspecialchars($c['Name']) ?></td>
											<td><?= htmlspecialchars($c['Date']) ?></td>
											<td><?= htmlspecialchars($c['ParkName'] ?? '—') ?></td>
											<td><span class="od-badge"><?= htmlspecialchars($c['Status']) ?></span></td>
										</tr>
									<?php endforeach; ?>
									</tbody>
								</table>
							<?php endif; ?>
						</div>
					</div>

					<div class="od-widget">
						<div class="od-widget-head"><h3>Next Crown Qual</h3></div>
						<div class="od-widget-body">
							<?php if (!$nextCrown): ?>
								<div class="od-empty">No Crown Qual on calendar.</div>
							<?php else:
								$days = max(0, (int)$nextCrown['DaysUntil']);
								$max  = max(60, $days);
								$display = $days === 0 ? 'Today' : ($days.'d');
							?>
								<svg class="od-chart od-chart-ring"
									data-value="<?= (int)($max - $days) ?>"
									data-max="<?= (int)$max ?>"
									data-display="<?= htmlspecialchars($display) ?>"
									data-label="until Crown Qual"></svg>
								<div style="text-align:center;margin-top:6px;font-size:12px;">
									<strong><?= htmlspecialchars($nextCrown['Name']) ?></strong><br>
									<span style="color:#888;"><?= htmlspecialchars($nextCrown['Date']) ?>
									<?php if (!empty($nextCrown['ParkName'])): ?> · <?= htmlspecialchars($nextCrown['ParkName']) ?><?php endif; ?>
									</span>
								</div>
							<?php endif; ?>
						</div>
					</div>
				</div>
			</div>
		</div>

		<!-- ============================================================ -->
		<!-- SECTION 2: Knighting tracks -->
		<!-- ============================================================ -->
		<div class="od-section">
			<div class="od-section-head">
				<h3 class="od-section-title"><i class="fas fa-shield-alt"></i> Knighting Tracks</h3>
				<i class="fas fa-chevron-down od-section-caret"></i>
			</div>
			<div class="od-section-body">
				<div class="od-widget-row">
					<div class="od-widget">
						<div class="od-widget-head"><h3>Knights by Order</h3></div>
						<div class="od-widget-body">
							<?php if (empty($knightsByOrder)): ?><div class="od-empty">No knights recorded.</div>
							<?php else:
								$vals = array_map(function($r){ return (int)$r['Count']; }, $knightsByOrder);
								$lbls = array_map(function($r){
									$n = $r['Name'] ?? '';
									$n = str_replace('Knight of the ', '', $n);
									return $n;
								}, $knightsByOrder);
							?>
								<svg class="od-chart od-chart-donut"
									data-values="<?= htmlspecialchars(implode(',',$vals)) ?>"
									data-labels="<?= htmlspecialchars(implode('|',$lbls)) ?>"
									data-center-label="Knights"></svg>
							<?php endif; ?>
						</div>
					</div>

					<div class="od-widget">
						<div class="od-widget-head"><h3>Peerage Distribution</h3></div>
						<div class="od-widget-body">
							<?php if (empty($peerageDist)): ?><div class="od-empty">No peerage awards.</div>
							<?php else:
								$vals = array_map(function($r){ return (int)$r['Count']; }, $peerageDist);
								$lbls = array_map(function($r){ return $r['Peerage']; }, $peerageDist);
							?>
								<svg class="od-chart od-chart-pie"
									data-values="<?= htmlspecialchars(implode(',',$vals)) ?>"
									data-labels="<?= htmlspecialchars(implode('|',$lbls)) ?>"></svg>
							<?php endif; ?>
						</div>
					</div>

					<div class="od-widget">
						<div class="od-widget-head"><h3>Newly Knighted (last 12 mo)</h3></div>
						<div class="od-widget-body">
							<?php if (empty($newlyKnighted)): ?>
								<div class="od-empty">No new knights in the last year.</div>
							<?php else: ?>
								<table class="od-table od-table-compact" data-od-paginate="5">
									<thead><tr><th>Player</th><th>Order</th><th>Date</th></tr></thead>
									<tbody>
									<?php foreach ($newlyKnighted as $k): ?>
										<tr>
											<td><a href="<?= UIR ?>Player/profile/<?= (int)$k['MundaneId'] ?>"><?= htmlspecialchars($k['Persona']) ?></a></td>
											<td><?= htmlspecialchars(str_replace('Knight of the ', '', $k['Award'])) ?></td>
											<td><?= htmlspecialchars($k['Date']) ?></td>
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
						<div class="od-widget-head"><h3>Knight Candidates (all tracks)</h3>
							<span class="od-subline">Track holders without knighthood</span>
						</div>
						<div class="od-widget-body">
							<?php if (empty($knightCandidates)): ?><div class="od-empty">No candidates tracked.</div>
							<?php else: ?>
								<table class="od-table od-table-compact" data-od-paginate="8">
									<thead><tr><th>Player</th><th>Park</th><th>Tracks held</th><th>Last track</th></tr></thead>
									<tbody>
									<?php foreach ($knightCandidates as $c): ?>
										<tr>
											<td><a href="<?= UIR ?>Player/profile/<?= (int)$c['MundaneId'] ?>"><?= htmlspecialchars($c['Persona']) ?></a></td>
											<td><?= $c['ParkId'] ? '<a href="'.UIR.'Park/profile/'.(int)$c['ParkId'].'">'.htmlspecialchars($c['ParkName'] ?? '—').'</a>' : '—' ?></td>
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
					<div class="od-widget">
						<div class="od-widget-head"><h3>Squire Track</h3></div>
						<div class="od-widget-body">
							<?php if (empty($squireCandidates)): ?><div class="od-empty">None.</div>
							<?php else: ?>
								<table class="od-table od-table-compact" data-od-paginate="5">
									<thead><tr><th>Squire</th><th>Since</th></tr></thead>
									<tbody>
									<?php foreach ($squireCandidates as $c): ?>
										<tr>
											<td><a href="<?= UIR ?>Player/profile/<?= (int)$c['MundaneId'] ?>"><?= htmlspecialchars($c['Persona']) ?></a></td>
											<td><?= htmlspecialchars($c['Date']) ?></td>
										</tr>
									<?php endforeach; ?>
									</tbody>
								</table>
							<?php endif; ?>
						</div>
					</div>

					<div class="od-widget">
						<div class="od-widget-head"><h3>Man-at-Arms Track</h3></div>
						<div class="od-widget-body">
							<?php if (empty($maaCandidates)): ?><div class="od-empty">None.</div>
							<?php else: ?>
								<table class="od-table od-table-compact" data-od-paginate="5">
									<thead><tr><th>Man-at-Arms</th><th>Since</th></tr></thead>
									<tbody>
									<?php foreach ($maaCandidates as $c): ?>
										<tr>
											<td><a href="<?= UIR ?>Player/profile/<?= (int)$c['MundaneId'] ?>"><?= htmlspecialchars($c['Persona']) ?></a></td>
											<td><?= htmlspecialchars($c['Date']) ?></td>
										</tr>
									<?php endforeach; ?>
									</tbody>
								</table>
							<?php endif; ?>
						</div>
					</div>

					<div class="od-widget">
						<div class="od-widget-head"><h3>Page Track</h3></div>
						<div class="od-widget-body">
							<?php if (empty($pageCandidates)): ?><div class="od-empty">None.</div>
							<?php else: ?>
								<table class="od-table od-table-compact" data-od-paginate="5">
									<thead><tr><th>Page</th><th>Since</th></tr></thead>
									<tbody>
									<?php foreach ($pageCandidates as $c): ?>
										<tr>
											<td><a href="<?= UIR ?>Player/profile/<?= (int)$c['MundaneId'] ?>"><?= htmlspecialchars($c['Persona']) ?></a></td>
											<td><?= htmlspecialchars($c['Date']) ?></td>
										</tr>
									<?php endforeach; ?>
									</tbody>
								</table>
							<?php endif; ?>
						</div>
					</div>

					<div class="od-widget">
						<div class="od-widget-head"><h3>Lord's Page Track</h3></div>
						<div class="od-widget-body">
							<?php if (empty($lordsPageCandidates)): ?><div class="od-empty">None.</div>
							<?php else: ?>
								<table class="od-table od-table-compact" data-od-paginate="5">
									<thead><tr><th>Lord's Page</th><th>Since</th></tr></thead>
									<tbody>
									<?php foreach ($lordsPageCandidates as $c): ?>
										<tr>
											<td><a href="<?= UIR ?>Player/profile/<?= (int)$c['MundaneId'] ?>"><?= htmlspecialchars($c['Persona']) ?></a></td>
											<td><?= htmlspecialchars($c['Date']) ?></td>
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
						<div class="od-widget-head"><h3>Order of the Warrior Ladder</h3><span class="od-subline">10th Order = Warlord</span></div>
						<div class="od-widget-body">
							<?php if (empty($warriorLadder)): ?><div class="od-empty">No ladder entries.</div>
							<?php else:
								// Always 1..10
								$buckets = array_fill(1, 10, 0);
								foreach ($warriorLadder as $r) { $rk = (int)$r['Rank']; if ($rk >= 1 && $rk <= 10) $buckets[$rk] = (int)$r['Count']; }
								$vals = array_values($buckets);
								$lbls = ['1st','2nd','3rd','4th','5th','6th','7th','8th','9th','10th'];
							?>
								<svg class="od-chart od-chart-bar"
									data-values="<?= htmlspecialchars(implode(',',$vals)) ?>"
									data-labels="<?= htmlspecialchars(implode('|',$lbls)) ?>"></svg>
							<?php endif; ?>
						</div>
					</div>

					<div class="od-widget">
						<div class="od-widget-head"><h3>Warlord Candidates</h3><span class="od-subline">5th+ Order, not yet Warlord</span></div>
						<div class="od-widget-body">
							<?php if (empty($warlordCandidates)): ?><div class="od-empty">No one within reach.</div>
							<?php else: ?>
								<table class="od-table od-table-compact" data-od-paginate="5">
									<thead><tr><th>Player</th><th>Park</th><th>Top Order</th><th>To 10th</th></tr></thead>
									<tbody>
									<?php foreach ($warlordCandidates as $c): ?>
										<tr>
											<td><a href="<?= UIR ?>Player/profile/<?= (int)$c['MundaneId'] ?>"><?= htmlspecialchars($c['Persona']) ?></a></td>
											<td><?= $c['ParkId'] ? htmlspecialchars($c['ParkName'] ?? '—') : '—' ?></td>
											<td><?= (int)$c['TopRank'] ?></td>
											<td><?= (int)$c['Remaining'] ?></td>
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
							<?php if (empty($martialAwardsRecent)): ?><div class="od-empty">No martial awards in last 180 days.</div>
							<?php else: ?>
								<table class="od-table od-table-compact" data-od-paginate="8">
									<thead><tr><th>Date</th><th>Player</th><th>Park</th><th>Award</th><th>Rank</th></tr></thead>
									<tbody>
									<?php foreach ($martialAwardsRecent as $m): ?>
										<tr>
											<td><?= htmlspecialchars($m['Date']) ?></td>
											<td><a href="<?= UIR ?>Player/profile/<?= (int)$m['MundaneId'] ?>"><?= htmlspecialchars($m['Persona']) ?></a></td>
											<td><?= $m['ParkId'] ? htmlspecialchars($m['ParkName'] ?? '—') : '—' ?></td>
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
		<!-- SECTION 3: Chapters & coverage -->
		<!-- ============================================================ -->
		<div class="od-section">
			<div class="od-section-head">
				<h3 class="od-section-title"><i class="fas fa-map-marked-alt"></i> Chapters &amp; Coverage</h3>
				<i class="fas fa-chevron-down od-section-caret"></i>
			</div>
			<div class="od-section-body">
				<div class="od-widget-row">
					<div class="od-widget">
						<div class="od-widget-head"><h3>Parks Without Champion</h3></div>
						<div class="od-widget-body">
							<?php if (empty($parksWithoutChampList)): ?>
								<div class="od-empty od-empty-ok"><i class="fas fa-check-circle"></i> Every chapter has a Champion.</div>
							<?php else: ?>
								<table class="od-table od-table-compact" data-od-paginate="5">
									<thead><tr><th>Park</th></tr></thead>
									<tbody>
									<?php foreach ($parksWithoutChampList as $p): ?>
										<tr><td><a href="<?= UIR ?>Park/profile/<?= (int)$p['ParkId'] ?>"><?= htmlspecialchars($p['ParkName']) ?></a></td></tr>
									<?php endforeach; ?>
									</tbody>
								</table>
							<?php endif; ?>
						</div>
					</div>

					<div class="od-widget">
						<div class="od-widget-head"><h3>Park Champion Coverage</h3></div>
						<div class="od-widget-body">
							<?php
							$cnt = count($parkChampCoverage);
							$covered = 0;
							foreach ($parkChampCoverage as $c) { if ($c['HasChampion']) $covered++; }
							$pct = $cnt > 0 ? round($covered / $cnt * 100) : 0;
							?>
							<svg class="od-chart od-chart-ring"
								data-value="<?= $covered ?>"
								data-max="<?= max(1, $cnt) ?>"
								data-display="<?= $pct ?>%"
								data-label="of parks have a Champion"></svg>
							<div style="text-align:center;margin-top:6px;font-size:12px;color:#888;">
								<?= $covered ?> of <?= $cnt ?> active chapters
							</div>
						</div>
					</div>

					<div class="od-widget">
						<div class="od-widget-head"><h3>Fighter Activity Ratio</h3></div>
						<div class="od-widget-body">
							<svg class="od-chart od-chart-ring"
								data-value="<?= $activityPct ?>"
								data-max="100"
								data-display="<?= $activityPct ?>%"
								data-label="active-fighter proxy"></svg>
							<div style="text-align:center;margin-top:6px;font-size:11px;color:#888;">
								<?= $activeFighters ?> active fighters, 90-day window
							</div>
						</div>
					</div>
				</div>

				<div class="od-widget-row">
					<div class="od-widget od-widget-wide">
						<div class="od-widget-head"><h3>Fighter Count per Park (90d)</h3></div>
						<div class="od-widget-body">
							<?php if (empty($fightersByPark)): ?><div class="od-empty">No attendance data.</div>
							<?php else:
								$vals = array_map(function($r){ return (int)$r['Fighters']; }, $fightersByPark);
								$lbls = array_map(function($r){ return (string)$r['ParkName']; }, $fightersByPark);
							?>
								<svg class="od-chart od-chart-bar" data-orientation="horizontal"
									data-values="<?= htmlspecialchars(implode(',',$vals)) ?>"
									data-labels="<?= htmlspecialchars(implode('|',$lbls)) ?>"></svg>
							<?php endif; ?>
						</div>
					</div>
				</div>

				<div class="od-widget-row">
					<div class="od-widget od-widget-wide">
						<div class="od-widget-head"><h3>Fighter Activity Heatmap (parks × weeks)</h3></div>
						<div class="od-widget-body">
							<?php if (empty($fighterHeatmap['rows'])): ?><div class="od-empty">No attendance in the last 10 weeks.</div>
							<?php else: ?>
								<svg class="od-chart od-chart-heatmap"
									data-matrix="<?= htmlspecialchars($matrixToAttr($fighterHeatmap['rows'])) ?>"
									data-rows="<?= htmlspecialchars(implode('|', $fighterHeatmap['rowLabels'])) ?>"
									data-cols="<?= htmlspecialchars(implode('|', $fighterHeatmap['colLabels'])) ?>"></svg>
							<?php endif; ?>
						</div>
					</div>
				</div>

				<div class="od-widget-row">
					<div class="od-widget od-widget-wide">
						<div class="od-widget-head"><h3>Knight Density per Park</h3></div>
						<div class="od-widget-body">
							<?php if (empty($parkKnightDensity)): ?><div class="od-empty">No knights localized to parks.</div>
							<?php else:
								$vals = array_map(function($r){ return (int)$r['Knights']; }, $parkKnightDensity);
								$lbls = array_map(function($r){ return (string)$r['ParkName']; }, $parkKnightDensity);
							?>
								<svg class="od-chart od-chart-bar" data-orientation="horizontal"
									data-values="<?= htmlspecialchars(implode(',',$vals)) ?>"
									data-labels="<?= htmlspecialchars(implode('|',$lbls)) ?>"></svg>
							<?php endif; ?>
						</div>
					</div>
				</div>
			</div>
		</div>

		<!-- ============================================================ -->
		<!-- SECTION 4: Fighters & performance -->
		<!-- ============================================================ -->
		<div class="od-section">
			<div class="od-section-head">
				<h3 class="od-section-title"><i class="fas fa-running"></i> Fighters &amp; Performance</h3>
				<i class="fas fa-chevron-down od-section-caret"></i>
			</div>
			<div class="od-section-body">
				<div class="od-widget-row">
					<div class="od-widget">
						<div class="od-widget-head"><h3>Top Active Fighters (90d)</h3></div>
						<div class="od-widget-body">
							<?php if (empty($topFighters)): ?><div class="od-empty">No attendance data.</div>
							<?php else: ?>
								<table class="od-table od-table-compact" data-od-paginate="5">
									<thead><tr><th>Player</th><th>Park</th><th>Credits</th></tr></thead>
									<tbody>
									<?php foreach ($topFighters as $p): ?>
										<tr>
											<td><a href="<?= UIR ?>Player/profile/<?= (int)$p['MundaneId'] ?>"><?= htmlspecialchars($p['Persona']) ?></a></td>
											<td><?= $p['ParkId'] ? htmlspecialchars($p['ParkName']) : '—' ?></td>
											<td><?= (int)$p['AttendCount'] ?></td>
										</tr>
									<?php endforeach; ?>
									</tbody>
								</table>
							<?php endif; ?>
						</div>
					</div>

					<div class="od-widget">
						<div class="od-widget-head"><h3>Active Fighters Trend (12 wk)</h3></div>
						<div class="od-widget-body">
							<?php if (empty($activeByWeek)): ?><div class="od-empty">No data.</div>
							<?php else:
								$vals = array_map(function($w){ return (int)$w['Fighters']; }, $activeByWeek);
							?>
								<svg class="od-spark" viewBox="0 0 240 48" preserveAspectRatio="none"
									data-values="<?= htmlspecialchars(implode(',', $vals)) ?>"></svg>
								<div style="display:flex;justify-content:space-between;font-size:11px;color:#888;margin-top:4px;">
									<span><?= htmlspecialchars($activeByWeek[0]['WeekStart'] ?? '') ?></span>
									<span>Peak: <?= max($vals) ?></span>
									<span><?= htmlspecialchars(end($activeByWeek)['WeekStart'] ?? '') ?></span>
								</div>
							<?php endif; ?>
						</div>
					</div>
				</div>
			</div>
		</div>

		<!-- ============================================================ -->
		<!-- SECTION 5: Events -->
		<!-- ============================================================ -->
		<div class="od-section">
			<div class="od-section-head">
				<h3 class="od-section-title"><i class="fas fa-calendar-alt"></i> Events &amp; Schedule</h3>
				<i class="fas fa-chevron-down od-section-caret"></i>
			</div>
			<div class="od-section-body">
				<div class="od-widget-row">
					<div class="od-widget od-widget-wide">
						<div class="od-widget-head"><h3>Upcoming Kingdom Events</h3></div>
						<div class="od-widget-body">
							<?php if (empty($upE)): ?><div class="od-empty">No scheduled events.</div>
							<?php else: ?>
								<table class="od-table od-table-compact" data-od-paginate="5">
									<thead><tr><th>Event</th><th>Chapter</th><th>Date</th></tr></thead>
									<tbody>
									<?php foreach ($upE as $e): ?>
										<tr>
											<td><?= htmlspecialchars($e['Name'] ?? '—') ?></td>
											<td><a href="<?= UIR ?>Park/profile/<?= (int)($e['ParkId'] ?? 0) ?>"><?= htmlspecialchars($e['ParkName'] ?? '—') ?></a></td>
											<td><?= htmlspecialchars(substr($e['StartDate'] ?? '',0,10)) ?></td>
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
						<div class="od-widget-head"><h3>Battle games</h3></div>
						<div class="od-widget-body"><ul class="od-soon-list"><li><i class="fas fa-fist-raised"></i> Battle-game scheduling &amp; results — coming soon.</li></ul></div>
					</div>
					<div class="od-widget od-widget-soon">
						<div class="od-widget-head"><h3>Class battles</h3></div>
						<div class="od-widget-body"><ul class="od-soon-list"><li><i class="fas fa-users"></i> Class-specific battles register — coming soon.</li></ul></div>
					</div>
					<div class="od-widget od-widget-soon">
						<div class="od-widget-head"><h3>Weapon-check calendar</h3></div>
						<div class="od-widget-body"><ul class="od-soon-list"><li><i class="fas fa-clipboard-check"></i> Weapon-check scheduling — coming soon.</li></ul></div>
					</div>
				</div>
			</div>
		</div>

		<!-- ============================================================ -->
		<!-- SECTION 6: Quick actions + tools (closed by default) -->
		<!-- ============================================================ -->
		<div class="od-section">
			<div class="od-section-head">
				<h3 class="od-section-title"><i class="fas fa-bolt"></i> Quick Actions</h3>
				<i class="fas fa-chevron-down od-section-caret"></i>
			</div>
			<div class="od-section-body">
				<div class="od-widget-row">
					<div class="od-widget od-widget-wide">
						<div class="od-widget-head"><h3>Champion Quick Actions</h3></div>
						<div class="od-widget-body">
							<div class="od-links-grid">
								<a class="od-link-card" href="<?= UIR ?>Reports/tournaments/<?= (int)$kingdom_id ?>"><i class="fas fa-trophy"></i><span>Tournament results</span></a>
								<a class="od-link-card" href="<?= UIR ?>Reports/knights/<?= (int)$kingdom_id ?>"><i class="fas fa-shield"></i><span>Knighting tracks</span></a>
								<a class="od-link-card" href="<?= UIR ?>Reports/attendance/<?= (int)$kingdom_id ?>"><i class="fas fa-running"></i><span>Fighter participation</span></a>
								<a class="od-link-card" href="<?= UIR ?>Tournametnew"><i class="fas fa-plus-circle"></i><span>New tournament</span></a>
								<a class="od-link-card" href="<?= UIR ?>Kingdom/members/<?= (int)$kingdom_id ?>"><i class="fas fa-users"></i><span>Roster</span></a>
								<a class="od-link-card" href="<?= UIR ?>Reports/recommendations/<?= (int)$kingdom_id ?>"><i class="fas fa-medal"></i><span>Recommend martial award</span></a>
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
						<div class="od-widget-head"><h3>Champion References</h3></div>
						<div class="od-widget-body">
							<div class="od-links-grid">
								<a class="od-link-card" href="https://amtgard.com/rules/" target="_blank" rel="noopener"><i class="fas fa-gavel"></i><span>Rules of Play</span></a>
								<a class="od-link-card" href="https://amtgard.com/handbook/" target="_blank" rel="noopener"><i class="fas fa-book-reader"></i><span>Corpora / Handbook</span></a>
								<a class="od-link-card" href="https://amtgard.com/doku/doku.php?id=category:weapon_specs" target="_blank" rel="noopener"><i class="fas fa-clipboard-check"></i><span>Weapon-check standards</span></a>
								<a class="od-link-card" href="https://amtgard.com/doku/doku.php?id=category:peerage" target="_blank" rel="noopener"><i class="fas fa-shield"></i><span>Knight track reference</span></a>
							</div>
						</div>
					</div>
				</div>
			</div>
		</div>
