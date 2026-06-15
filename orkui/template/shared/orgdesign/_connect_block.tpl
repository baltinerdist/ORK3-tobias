<?php
/**
 * Shared "Connect" social pills block (sidebar).
 *
 * Plain-PHP include. Expects in scope:
 *   $ctx['social_links'] : array slug => url (already filtered to non-empty)
 *   $ctx['can_manage']   : bool
 *   $OD_SOCIAL_PLATFORMS : platform metadata map (from _helpers.php)
 *
 * The manager "edit"/"+ Add" affordances open the design modal on its About
 * panel via the global odOpenDesignModal() defined in orgdesign.js.
 */
$_odSocial   = isset($ctx['social_links']) && is_array($ctx['social_links']) ? $ctx['social_links'] : [];
$_odCanMng   = !empty($ctx['can_manage']);
$_odPlatforms = isset($OD_SOCIAL_PLATFORMS) && is_array($OD_SOCIAL_PLATFORMS) ? $OD_SOCIAL_PLATFORMS : [];

// Keep only platforms we know how to render, preserving the canonical order.
$_odVisible = [];
foreach ($_odPlatforms as $_slug => $_meta) {
    $_u = trim((string)($_odSocial[$_slug] ?? ''));
    if ($_u !== '') {
        $_odVisible[$_slug] = $_u;
    }
}

if (!empty($_odVisible) || $_odCanMng):
?>
<div class="od-connect-block">
	<div class="od-connect-subhead">
		<span><i class="fas fa-share-alt"></i> Connect</span>
		<?php if ($_odCanMng): ?>
		<button class="od-connect-edit" type="button" onclick="odOpenDesignModal('about')" data-tip="Edit social links"><i class="fas fa-pencil-alt"></i></button>
		<?php endif; ?>
	</div>
	<?php if (!empty($_odVisible)): ?>
	<div class="od-connect-pills">
		<?php foreach ($_odVisible as $_slug => $_url):
			$_meta = $_odPlatforms[$_slug];
		?>
		<a class="od-connect-pill" href="<?= htmlspecialchars($_url) ?>" target="_blank" rel="noopener noreferrer" data-tip="<?= htmlspecialchars($_meta['label']) ?>">
			<i class="<?= $_meta['icon'] ?>"></i>
		</a>
		<?php endforeach; ?>
	</div>
	<?php elseif ($_odCanMng): ?>
	<a href="#" class="od-connect-empty" onclick="event.preventDefault();odOpenDesignModal('about')">+ Add</a>
	<?php endif; ?>
</div>
<?php endif; ?>
