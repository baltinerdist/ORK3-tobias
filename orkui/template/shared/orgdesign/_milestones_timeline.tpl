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
		<?php $_odMsIdx = 0; ?>
		<?php foreach ($_odMs as $_ms): ?>
		<div class="od-timeline-row<?= !empty($_ms['IsDerived']) ? ' od-ms-derived' : '' ?><?= $_odMsIdx >= 8 ? ' od-ms-collapsed' : '' ?>">
			<div class="od-timeline-dot">
				<i class="fas <?= htmlspecialchars(preg_replace('/[^a-z0-9-]/', '', (string)($_ms['Icon'] ?? 'fa-star')) ?: 'fa-star') ?>"></i>
			</div>
			<div class="od-timeline-content">
				<span class="od-timeline-date"><?= !empty($_ms['MilestoneDate']) && $_ms['MilestoneDate'] !== '0000-00-00' ? date('M j, Y', strtotime($_ms['MilestoneDate'])) : '' ?></span>
				<span class="od-timeline-desc"><?= htmlspecialchars((string)($_ms['Description'] ?? '')) ?></span>
			</div>
		</div>
		<?php $_odMsIdx++; ?>
		<?php endforeach; ?>
	</div>
	<?php if (count($_odMs) > 8): ?>
	<button type="button" class="od-ms-more-btn" data-od-ms-more aria-expanded="false"><i class="fas fa-chevron-down" aria-hidden="true"></i> Show all <?= count($_odMs) ?> milestones</button>
	<script>
	/* Self-contained toggle: orgdesign.js only loads for managers, but this
	   section renders for anonymous visitors too, so wire the button here. */
	(function () {
		var btns = document.querySelectorAll('[data-od-ms-more]');
		for (var i = 0; i < btns.length; i++) {
			(function (btn) {
				try {
					if (btn.getAttribute('data-od-ms-bound') === '1') { return; }
					btn.setAttribute('data-od-ms-bound', '1');
					btn.addEventListener('click', function () {
						try {
							var tl = btn.previousElementSibling;
							if (!tl || !tl.classList || !tl.classList.contains('od-timeline')) {
								var sec = btn.closest ? btn.closest('.od-about-section') : null;
								tl = sec ? sec.querySelector('.od-timeline') : null;
							}
							if (!tl) { return; }
							tl.classList.add('od-ms-expanded');
							btn.setAttribute('aria-expanded', 'true');
							btn.style.display = 'none';
						} catch (e) {}
					});
				} catch (e) {}
			})(btns[i]);
		}
	})();
	</script>
	<?php endif; ?>
	<?php elseif ($_odCanMng): ?>
	<div class="od-timeline-empty">
		No milestones yet. <a href="#" onclick="event.preventDefault();odOpenDesignModal('milestones')">Add the first one</a> — founding date, charter dates, notable events.
	</div>
	<?php endif; ?>
</div>
