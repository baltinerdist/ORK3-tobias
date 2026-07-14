<?php
	$voting_event_id = (int)($voting_event_id ?? 0);
	$event = $event ?? null;
	$tally = $tally ?? [];
?>
<link rel="stylesheet" href="<?= HTTP_TEMPLATE ?>default/style/reports.css?v=<?= filemtime(__DIR__ . '/../default/style/reports.css') ?>">
<style>
	.rp-root.vt-root { --rp-accent-dark:#2c5282; --rp-accent:#3182ce; --rp-accent-mid:#4299e1; }
	html[data-theme="dark"] .rp-root.vt-root { --rp-accent-dark:#1a365d; --rp-border:#4a5568; --rp-bg-light:#2d3748; --rp-text:#e2e8f0; --rp-text-body:#cbd5e0; --rp-text-muted:#a0aec0; }
	.vtp-wrap { padding: 16px; }
	.vtp-sub { color:var(--vtp-meta,#718096); font-size:13px; margin-bottom: 18px; }
	.vtp-card { background:var(--vtp-card-bg,#fff); border:1px solid var(--vtp-card-border,#e2e8f0); border-radius:10px; padding:20px; margin-bottom:14px; }
	.vtp-race-title { font-size:18px; font-weight:600; color:var(--vtp-text,#1a202c); margin-bottom:6px; }
	.vtp-bar { display:flex; align-items:center; gap:10px; margin-bottom: 6px; font-size:13px; }
	.vtp-bar-label { flex: 0 0 200px; color:var(--vtp-text,#1a202c); }
	.vtp-bar-track { flex:1; height:22px; background:var(--vtp-toggle-bg,#edf2f7); border-radius:4px; }
	.vtp-bar-fill { height:100%; background:#3182ce; border-radius:4px; }
	.vtp-bar-fill.vtp-yes { background:#48bb78; }
	.vtp-bar-fill.vtp-no { background:#e53e3e; }
	.vtp-bar-fill.vtp-winner { background:#48bb78; }
	.vtp-bar-count { flex: 0 0 90px; text-align:right; font-weight:600; color:var(--vtp-text,#1a202c); }
	.vtp-winner-banner { display:inline-block; padding:6px 14px; background:#c6f6d5; color:#22543d; font-weight:600; border-radius:8px; font-size:14px; margin-top:8px; }
	.vtp-tie-banner { display:inline-block; padding:6px 14px; background:#fed7d7; color:#742a2a; font-weight:600; border-radius:8px; font-size:14px; margin-top:8px; }
	.vtp-confidence-pass { display:inline-block; padding:6px 14px; background:#c6f6d5; color:#22543d; font-weight:600; border-radius:8px; font-size:14px; margin-top:8px; }
	.vtp-confidence-fail { display:inline-block; padding:6px 14px; background:#fed7d7; color:#742a2a; font-weight:600; border-radius:8px; font-size:14px; margin-top:8px; }
	.vtp-poll-tag { display:inline-block; padding:2px 10px; background:#fefcbf; color:#744210; font-weight:600; font-size:11px; border-radius:999px; text-transform:uppercase; margin-left:6px; }
	.vtp-error { padding: 28px 20px; background:var(--vtp-card-bg,#fff); border:1px solid var(--vtp-card-border,#e2e8f0); border-radius:10px; text-align:center; color:var(--vtp-text,#1a202c); }
	.vtp-irv-rounds { background:var(--vtp-toggle-bg,#f7fafc); border-radius:8px; padding:14px; margin-top:10px; }
	.vtp-irv-round { padding:8px 0; border-bottom:1px solid var(--vtp-card-border,#e2e8f0); }
	.vtp-irv-round:last-child { border-bottom:none; }
	.vtp-irv-round-head { font-weight:600; color:var(--vtp-text,#1a202c); margin-bottom:6px; }
	.vtp-rationale { color:var(--vtp-meta,#718096); margin-bottom: 10px; font-size:13px; }
	html[data-theme="dark"] .vtp-card, html[data-theme="dark"] .vtp-error { --vtp-card-bg:#1a202c; --vtp-card-border:#2d3748; --vtp-text:#e2e8f0; --vtp-meta:#a0aec0; --vtp-toggle-bg:#2d3748; }
	html[data-theme="dark"] .vtp-h1, html[data-theme="dark"] .vtp-race-title { color:#e2e8f0; }
	html[data-theme="dark"] .vtp-sub { color:#a0aec0; }
	html[data-theme="dark"] .vtp-bar-label, html[data-theme="dark"] .vtp-bar-count { color:#e2e8f0; }
</style>

<div class="rp-root vt-root">
	<?php if (!empty($Error) || !$event): ?>
		<div class="rp-header">
			<div class="rp-header-left"><div class="rp-header-icon-title">
				<i class="fas fa-vote-yea rp-header-icon"></i>
				<h1 class="rp-header-title">Voting Results</h1>
			</div></div>
		</div>
		<div class="rp-not-supported">
			<i class="fas fa-info-circle"></i>
			<h3>Results not available</h3>
			<p>This event has either not been published or has been temporarily withdrawn.</p>
		</div>
	<?php else: ?>
		<div class="rp-header">
			<div class="rp-header-left">
				<div class="rp-header-icon-title">
					<i class="fas <?= $event['event_type'] === 'election' ? 'fa-vote-yea' : 'fa-comments' ?> rp-header-icon"></i>
					<h1 class="rp-header-title"><?= htmlspecialchars($event['title']) ?></h1>
				</div>
				<div class="rp-header-scope">
					<span class="rp-scope-chip" style="cursor:default;"><?= htmlspecialchars(ucfirst($event['event_type'])) ?></span>
					<span class="rp-scope-chip" style="cursor:default;"><i class="fas fa-check-circle"></i> Published</span>
					<span class="rp-scope-chip" style="cursor:default;"><i class="fas fa-clock"></i> Closed <?= date('M j, Y g:i A', strtotime($event['end_date'])) ?></span>
				</div>
			</div>
		</div>
		<div class="rp-context">
			<i class="fas fa-info-circle rp-context-icon"></i>
			<span>Final tally of all counted ballots. Provisional ballots that were never released to count are excluded.</span>
			<?php $ec = (int)($event['eligible_count'] ?? 0); $bc = (int)($event['ballots_cast'] ?? 0); ?>
			<?php if ($ec > 0): ?>
				<span style="margin-left:12px;"><strong><?= $bc ?></strong> of <strong><?= $ec ?></strong> eligible voters cast a counted ballot (<strong><?= round($bc / $ec * 100) ?>%</strong> turnout).</span>
			<?php endif; ?>
		</div>

<div class="vtp-wrap">

		<?php
		$render_choice_label_results = function($cid) use (&$choices_by_id) {
			$c = $choices_by_id[$cid] ?? null;
			if (!$c) return '#' . htmlspecialchars((string)$cid);
			$out = htmlspecialchars($c['label']);
			if (!empty($c['withdrawn_at'])) {
				$out = '<span class="vtp-poll-tag" style="background:#feebc8;color:#7c2d12;font-size:10px;margin-right:4px;">withdrawn</span>' . $out;
			}
			if (!empty($c['original_label'])) {
				$out .= ' <span class="vtp-poll-tag" style="background:#e9d8fd;color:#44337a;font-size:10px;" data-tip="Originally: '.htmlspecialchars($c['original_label'], ENT_QUOTES).'">edited</span>';
			}
			return $out;
		};
		foreach ($tally as $rid => $row):
			$race = $row['race'];
			$result = $row['result'];
			$choices = $race['choices'] ?? [];
			$choices_by_id = [];
			foreach ($choices as $c) $choices_by_id[$c['id']] = $c;
		?>
			<div class="vtp-card">
				<div class="vtp-race-title">
					<?= htmlspecialchars($race['title']) ?>
					<?php if (!empty($race['original_title'])): ?><span class="vtp-poll-tag" style="background:#e9d8fd;color:#44337a;" data-tip="Originally: <?= htmlspecialchars($race['original_title'], ENT_QUOTES) ?>">edited</span><?php endif; ?>
					<?php if ($race['race_type'] === 'position' && count($choices) === 1): ?><span class="vtp-poll-tag" style="background:#bee3f8;color:#2a4365;">Confidence</span><?php endif; ?>
					<?php if (!empty($race['is_non_binding'])): ?><span class="vtp-poll-tag">Poll — non-binding</span><?php endif; ?>
				</div>
				<?php if (!empty($race['rationale'])): ?>
					<div class="vtp-rationale"><?= nl2br(htmlspecialchars($race['rationale'])) ?></div>
				<?php endif; ?>

				<?php if (in_array($result['outcome'], ['pass','fail','tie'])):
					$total = ($result['yes']??0) + ($result['no']??0) + ($result['abstain']??0) + ($result['nota']??0);
				?>
					<div class="vtp-bar"><div class="vtp-bar-label">Yes</div>
						<div class="vtp-bar-track"><div class="vtp-bar-fill vtp-yes" style="width:<?= $total > 0 ? round((($result['yes']??0)/$total)*100) : 0 ?>%"></div></div>
						<div class="vtp-bar-count"><?= (int)($result['yes']??0) ?></div></div>
					<div class="vtp-bar"><div class="vtp-bar-label">No</div>
						<div class="vtp-bar-track"><div class="vtp-bar-fill vtp-no" style="width:<?= $total > 0 ? round((($result['no']??0)/$total)*100) : 0 ?>%"></div></div>
						<div class="vtp-bar-count"><?= (int)($result['no']??0) ?></div></div>
					<?php if (!empty($result['abstain'])): ?>
						<div class="vtp-bar"><div class="vtp-bar-label">Abstain</div>
							<div class="vtp-bar-track"><div class="vtp-bar-fill" style="width:<?= $total > 0 ? round((($result['abstain'])/$total)*100) : 0 ?>%;background:#a0aec0;"></div></div>
							<div class="vtp-bar-count"><?= (int)$result['abstain'] ?></div></div>
					<?php endif; ?>

					<?php if ($result['outcome'] === 'pass'): ?>
						<div class="vtp-confidence-pass"><i class="fas fa-check"></i> <?= $race['race_type'] === 'yesno' ? 'Passed' : 'Confidence Affirmed' ?></div>
					<?php elseif ($result['outcome'] === 'fail'): ?>
						<div class="vtp-confidence-fail"><i class="fas fa-times"></i> <?= $race['race_type'] === 'yesno' ? 'Failed' : 'No Confidence' ?></div>
					<?php else: ?>
						<div class="vtp-tie-banner"><i class="fas fa-equals"></i> Tied — runner has not yet resolved.</div>
					<?php endif; ?>
					<?php if (!empty($result['denominator_basis'])): ?>
						<div class="vtp-rationale">Majority of <?= $result['denominator_basis'] === 'ballots_cast' ? 'all ballots cast' : 'choice votes' ?> — <?= (int)$result['denominator'] ?> counted<?php if (isset($result['winner_share'])): ?>, leader held <?= $result['winner_share'] ?>%<?php endif; ?>.</div>
					<?php endif; ?>

				<?php elseif (!empty($result['rounds']) && is_array($result['rounds'])): ?>
					<div class="vtp-irv-rounds">
						<?php foreach ($result['rounds'] as $i => $rd): ?>
							<div class="vtp-irv-round">
								<div class="vtp-irv-round-head">
									Round <?= (int)$rd['round'] ?>
									<?php if (!empty($rd['eliminated'])): ?>
										— eliminated: <?= $render_choice_label_results($rd['eliminated']) ?>
									<?php elseif (!empty($rd['winner'])): ?>
										— <strong>winner: <?= $render_choice_label_results($rd['winner']) ?></strong>
									<?php elseif (!empty($rd['tie'])): ?>
										— <strong>tie</strong>
									<?php endif; ?>
								</div>
								<?php $rdTotal = array_sum($rd['counts'] ?? []); ?>
								<?php foreach (($rd['counts'] ?? []) as $cid => $n): ?>
									<div class="vtp-bar"><div class="vtp-bar-label"><?= $render_choice_label_results($cid) ?></div>
										<div class="vtp-bar-track"><div class="vtp-bar-fill <?= !empty($rd['winner']) && $rd['winner'] == $cid ? 'vtp-winner' : '' ?>" style="width:<?= $rdTotal > 0 ? round(($n/$rdTotal)*100) : 0 ?>%"></div></div>
										<div class="vtp-bar-count"><?= (int)$n ?></div></div>
								<?php endforeach; ?>
								<?php if (!empty($rd['exhausted_this_round'])): ?>
									<div style="font-size:11px;color:#718096;margin-top:4px;"><?= (int)$rd['exhausted_this_round'] ?> ballot(s) exhausted this round</div>
								<?php endif; ?>
							</div>
						<?php endforeach; ?>
					</div>
					<?php if ($result['outcome'] === 'win'):
						$winner_label_html = $render_choice_label_results($result['winner_choice_id']); ?>
						<div class="vtp-winner-banner"><i class="fas fa-trophy"></i> Winner: <?= $winner_label_html ?></div>
						<?php if (isset($result['winner_votes'])): ?>
							<div class="vtp-rationale">Won <?= (int)$result['winner_votes'] ?> of <?= (int)$result['total_ballots'] ?> ballots cast (<?= $result['winner_share_total'] ?>%)<?= empty($result['winner_is_overall_majority']) ? ' — majority of continuing ballots' : '' ?>.</div>
						<?php endif; ?>
					<?php elseif ($result['outcome'] === 'win_resolved'): ?>
						<div class="vtp-winner-banner"><i class="fas fa-gavel"></i> Tie resolved: <?= $render_choice_label_results($result['winner_choice_id']) ?></div>
					<?php else: ?>
						<div class="vtp-tie-banner"><i class="fas fa-equals"></i> <?php $o = $result['outcome']; echo htmlspecialchars(['no_votes' => 'No votes cast', 'no_majority' => 'No majority', 'tie' => 'Tied — runner has not yet resolved.', 'tie_at_final' => 'Final-round tie', 'tie_at_elimination' => 'Elimination tie'][$o] ?? ucfirst(str_replace('_', ' ', $o))); ?></div>
					<?php endif; ?>

				<?php else:
					// Plurality / majority
					$counts = $result['counts'] ?? [];
					$grand = array_sum($counts) + ($result['abstain'] ?? 0) + ($result['nota'] ?? 0);
					foreach ($counts as $cid => $n):
						$is_winner = !empty($result['winner_choice_id']) && (int)$result['winner_choice_id'] === (int)$cid;
				?>
					<div class="vtp-bar"><div class="vtp-bar-label"><?= $render_choice_label_results($cid) ?></div>
						<div class="vtp-bar-track"><div class="vtp-bar-fill <?= $is_winner ? 'vtp-winner' : '' ?>" style="width:<?= $grand > 0 ? round(($n/$grand)*100) : 0 ?>%"></div></div>
						<div class="vtp-bar-count"><?= (int)$n ?></div></div>
				<?php endforeach;
					if (!empty($result['abstain'])): ?>
						<div class="vtp-bar"><div class="vtp-bar-label">Abstain</div>
							<div class="vtp-bar-track"><div class="vtp-bar-fill" style="width:<?= $grand > 0 ? round(($result['abstain']/$grand)*100) : 0 ?>%;background:#a0aec0;"></div></div>
							<div class="vtp-bar-count"><?= (int)$result['abstain'] ?></div></div>
				<?php endif;
					if ($result['outcome'] === 'win'): ?>
						<div class="vtp-winner-banner"><i class="fas fa-trophy"></i> Winner: <?= $render_choice_label_results($result['winner_choice_id']) ?></div>
						<?php if (!empty($result['natural_top_choice_id']) && (int)$result['natural_top_choice_id'] !== (int)$result['winner_choice_id']): ?>
							<div class="vtp-rationale">Top vote-getter <em><?= $render_choice_label_results($result['natural_top_choice_id']) ?></em> was withdrawn and is not eligible to win.</div>
						<?php endif; ?>
					<?php elseif ($result['outcome'] === 'win_resolved'): ?>
						<div class="vtp-winner-banner"><i class="fas fa-gavel"></i> Tie resolved: <?= $render_choice_label_results($result['winner_choice_id']) ?></div>
					<?php else: ?>
						<div class="vtp-tie-banner"><i class="fas fa-equals"></i> <?php $o = $result['outcome']; echo htmlspecialchars(['no_votes' => 'No votes cast', 'no_majority' => 'No majority', 'tie' => 'Tied — runner has not yet resolved.', 'tie_at_final' => 'Final-round tie', 'tie_at_elimination' => 'Elimination tie'][$o] ?? ucfirst(str_replace('_', ' ', $o))); ?></div>
				<?php endif;
					if (!empty($result['denominator_basis'])): ?>
						<div class="vtp-rationale">Majority of <?= $result['denominator_basis'] === 'ballots_cast' ? 'all ballots cast' : 'choice votes' ?> — <?= (int)$result['denominator'] ?> counted<?php if (isset($result['winner_share'])): ?>, leader held <?= $result['winner_share'] ?>%<?php endif; ?>.</div>
					<?php endif; endif; ?>
			</div>
		<?php endforeach; ?>
</div><!-- /vtp-wrap -->
	<?php endif; ?>
</div><!-- /rp-root -->
