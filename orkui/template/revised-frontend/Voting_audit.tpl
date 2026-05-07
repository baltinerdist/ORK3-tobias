<?php $rows = $rows ?? []; $voting_event_id = (int)($voting_event_id ?? 0); ?>
<style>
	.vta-wrap { max-width: 1100px; margin: 0 auto; padding: 24px 16px; }
	.vta-h1 { font-size:22px; font-weight:600; margin:0 0 14px 0; background:transparent;border:none;padding:0;border-radius:0;text-shadow:none; color:var(--vta-text,#1a202c); }
	.vta-table { width:100%; border-collapse: collapse; font-size:13px; background:var(--vta-card-bg,#fff); border:1px solid var(--vta-card-border,#e2e8f0); border-radius:8px; overflow:hidden; }
	.vta-table th, .vta-table td { padding:8px 12px; text-align:left; border-bottom:1px solid var(--vta-card-border,#e2e8f0); color:var(--vta-text,#1a202c); }
	.vta-table th { background:var(--vta-toggle-bg,#f7fafc); font-weight:600; font-size:12px; text-transform:uppercase; color:var(--vta-meta,#4a5568); }
	.vta-action-pill { display:inline-block; padding:2px 8px; background:#edf2f7; color:#4a5568; border-radius:999px; font-size:11px; font-weight:600; }
	.vta-detail { font-family:monospace; font-size:11px; color:var(--vta-meta,#718096); white-space:pre-wrap; word-break:break-all; max-width:500px; }
	@media (prefers-color-scheme: dark) {
		.vta-table { --vta-card-bg:#1a202c; --vta-card-border:#2d3748; --vta-text:#e2e8f0; --vta-meta:#a0aec0; --vta-toggle-bg:#2d3748; }
		.vta-h1 { color:#e2e8f0; }
	}
	body.dark-mode .vta-table { --vta-card-bg:#1a202c; --vta-card-border:#2d3748; --vta-text:#e2e8f0; --vta-meta:#a0aec0; --vta-toggle-bg:#2d3748; }
	body.dark-mode .vta-h1 { color:#e2e8f0; }
</style>
<div class="vta-wrap">
	<h1 class="vta-h1">Audit Log — Event #<?= $voting_event_id ?></h1>
	<table class="vta-table">
		<thead><tr><th>Time</th><th>Actor</th><th>Action</th><th>Detail</th></tr></thead>
		<tbody>
			<?php foreach ($rows as $r): ?>
				<tr>
					<td><?= htmlspecialchars($r['created_at']) ?></td>
					<td><?= htmlspecialchars(($r['persona'] ?: $r['username']) ?? '') ?></td>
					<td><span class="vta-action-pill"><?= htmlspecialchars($r['action']) ?></span></td>
					<td class="vta-detail"><?= htmlspecialchars($r['detail'] ?? '') ?></td>
				</tr>
			<?php endforeach; ?>
		</tbody>
	</table>
	<?php if (empty($rows)): ?>
		<div style="padding:30px;text-align:center;color:#718096;">No audit entries yet.</div>
	<?php endif; ?>
</div>
