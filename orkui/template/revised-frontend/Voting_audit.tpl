<?php $rows = $rows ?? []; $voting_event_id = (int)($voting_event_id ?? 0); ?>
<link rel="stylesheet" href="<?= HTTP_TEMPLATE ?>default/style/reports.css?v=<?= filemtime(__DIR__ . '/../default/style/reports.css') ?>">
<style>
	.rp-root.vt-root { --rp-accent-dark:#2c5282; --rp-accent:#3182ce; --rp-accent-mid:#4299e1; }
	html[data-theme="dark"] .rp-root.vt-root { --rp-accent-dark:#1a365d; --rp-border:#4a5568; --rp-bg-light:#2d3748; --rp-text:#e2e8f0; --rp-text-body:#cbd5e0; --rp-text-muted:#a0aec0; }
	.vta-wrap { padding: 16px; }
	.vta-table { width:100%; border-collapse: collapse; font-size:13px; background:var(--vta-card-bg,#fff); border:1px solid var(--vta-card-border,#e2e8f0); border-radius:8px; overflow:hidden; }
	.vta-table th, .vta-table td { padding:8px 12px; text-align:left; border-bottom:1px solid var(--vta-card-border,#e2e8f0); color:var(--vta-text,#1a202c); }
	.vta-table th { background:var(--vta-toggle-bg,#f7fafc); font-weight:600; font-size:12px; text-transform:uppercase; color:var(--vta-meta,#4a5568); }
	.vta-action-pill { display:inline-block; padding:2px 8px; background:#edf2f7; color:#4a5568; border-radius:999px; font-size:11px; font-weight:600; }
	.vta-detail { font-family:monospace; font-size:11px; color:var(--vta-meta,#718096); white-space:pre-wrap; word-break:break-all; max-width:500px; }
	html[data-theme="dark"] .vta-table { --vta-card-bg:#1a202c; --vta-card-border:#2d3748; --vta-text:#e2e8f0; --vta-meta:#a0aec0; --vta-toggle-bg:#2d3748; }
	html[data-theme="dark"] .vta-h1 { color:#e2e8f0; }
</style>
<div class="rp-root vt-root">
	<div class="rp-header">
		<div class="rp-header-left">
			<div class="rp-header-icon-title">
				<i class="fas fa-clipboard-list rp-header-icon"></i>
				<h1 class="rp-header-title">Audit Log</h1>
			</div>
			<div class="rp-header-scope">
				<a class="rp-scope-chip" href="<?= UIR ?>Voting/runner/<?= (int)$voting_event_id ?>"><i class="fas fa-arrow-left"></i> Back to Runner Dashboard</a>
				<span class="rp-scope-chip" style="cursor:default;">Event #<?= (int)$voting_event_id ?></span>
			</div>
		</div>
	</div>

<div class="vta-wrap">
	<table class="vta-table">
		<thead><tr><th>Time</th><th>Actor</th><th>Action</th><th>Detail</th></tr></thead>
		<tbody>
			<?php
			$action_labels = [
				'event_created' => 'Event created',
				'event_updated' => 'Event updated',
				'event_reopened' => 'Configuration reopened',
				'event_resumed_keep' => 'Voting resumed (kept votes)',
				'event_resumed_discard' => 'Voting resumed (discarded impacted votes)',
				'race_created' => 'Race added',
				'race_removed' => 'Race removed',
				'race_wording_edited' => 'Race wording edited',
				'candidate_added' => 'Candidate/option added',
				'candidate_removed' => 'Candidate/option removed',
				'candidate_withdrawn' => 'Candidate/option withdrawn',
				'candidate_restored' => 'Candidate/option restored',
				'choice_label_edited' => 'Option label edited',
				'ballot_cast' => 'Ballot cast',
				'ballot_changed' => 'Ballot changed',
				'ballot_runner_entered' => 'Runner entered ballot',
				'ballot_replaced_by_paper' => 'Ballot replaced by runner',
				'provisional_released_runner' => 'Provisional released by runner',
				'provisional_released_system' => 'Provisional released (eligibility)',
			];
			foreach ($rows as $r):
				$action_pretty = $action_labels[$r['action']] ?? $r['action'];
			?>
				<tr>
					<td><?= htmlspecialchars($r['created_at']) ?></td>
					<td><?= htmlspecialchars(($r['persona'] ?: $r['username']) ?? '') ?></td>
					<td><span class="vta-action-pill" data-tip="<?= htmlspecialchars($r['action'], ENT_QUOTES) ?>"><?= htmlspecialchars($action_pretty) ?></span></td>
					<td class="vta-detail"><?= htmlspecialchars($r['detail'] ?? '') ?></td>
				</tr>
			<?php endforeach; ?>
		</tbody>
	</table>
	<?php if (empty($rows)): ?>
		<div style="padding:30px;text-align:center;color:#718096;">No audit entries yet.</div>
	<?php endif; ?>
</div>
</div><!-- /rp-root -->
