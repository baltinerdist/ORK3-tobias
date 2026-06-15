<?php
/**
 * Shared Milestones timeline section (About tab).
 *
 * Plain-PHP include. Expects in scope:
 *   $ctx['milestones'] : array of visible, already-ordered milestone rows, each
 *                        with keys IsDerived, Icon, MilestoneDate, Description
 *   $ctx['can_manage'] : bool
 *
 * Derived milestones (IsDerived) render with a distinct dot/desc style via the
 * .od-ms-derived modifier. Manager affordances open the design modal's
 * Milestones panel through odOpenDesignModal().
 *
 * NOTE: the caller decides whether to render this section at all (e.g. only when
 * the new About design is enabled AND there are milestones or the viewer can
 * manage). This partial assumes that gate already passed.
 */
$_odMs     = isset($ctx['milestones']) && is_array($ctx['milestones']) ? $ctx['milestones'] : [];
$_odCanMng = !empty($ctx['can_manage']);
$_odHasMs  = count($_odMs) > 0;
?>
<div class="od-about-section od-timeline-section">
	<div class="od-about-section-head">
		<h3 class="od-timeline-heading"><i class="fas fa-stream"></i> Milestones</h3>
		<?php if ($_odCanMng): ?>
		<button class="od-about-edit-btn" type="button" onclick="odOpenDesignModal('milestones')" data-tip="Manage milestones">
			<i class="fas fa-pencil-alt"></i> Manage
		</button>
		<?php endif; ?>
	</div>
	<?php if ($_odHasMs): ?>
	<div class="od-timeline">
		<?php foreach ($_odMs as $_ms): ?>
		<div class="od-timeline-row<?= !empty($_ms['IsDerived']) ? ' od-ms-derived' : '' ?>">
			<div class="od-timeline-dot">
				<i class="fas <?= htmlspecialchars(preg_replace('/[^a-z0-9-]/', '', (string)($_ms['Icon'] ?? 'fa-star')) ?: 'fa-star') ?>"></i>
			</div>
			<div class="od-timeline-content">
				<span class="od-timeline-date"><?= !empty($_ms['MilestoneDate']) && $_ms['MilestoneDate'] !== '0000-00-00' ? date('M j, Y', strtotime($_ms['MilestoneDate'])) : '' ?></span>
				<span class="od-timeline-desc"><?= htmlspecialchars((string)($_ms['Description'] ?? '')) ?></span>
			</div>
		</div>
		<?php endforeach; ?>
	</div>
	<?php elseif ($_odCanMng): ?>
	<div class="od-timeline-empty">
		No milestones yet. <a href="#" onclick="event.preventDefault();odOpenDesignModal('milestones')">Add the first one</a> — founding date, charter dates, notable events.
	</div>
	<?php endif; ?>
</div>
