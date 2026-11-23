<?php
/**
 * Shared "Connect" social pills block (sidebar).
 *
 * Plain-PHP include. Expects in scope:
 *   $ctx['social_platforms'] : slug => true for each platform the org links to
 *                              (from the public read's SocialPlatforms: NO urls)
 *   $ctx['social_reveal']    : ['url' => reveal endpoint, 'token' => session token]
 *   $ctx['can_manage']       : bool
 *   $OD_SOCIAL_PLATFORMS     : platform metadata map (from _helpers.php)
 *
 * Anti-harvest: the pills carry no URL. A click POSTs the platform + this
 * session's reveal token to the org's socialreveal endpoint
 * (trait.OrgSocialReveal), which checks origin, bot UA, token and a rate limit
 * before answering with the one URL; the script then opens it in a new tab.
 * Scrapers reading the HTML or following hrefs get nothing.
 *
 * The manager "edit"/"+ Add" affordances open the design modal on its About
 * panel via the global odOpenDesignModal() defined in orgdesign.js.
 */
$_odSocialSet = isset($ctx['social_platforms']) && is_array($ctx['social_platforms']) ? $ctx['social_platforms'] : [];
$_odReveal    = isset($ctx['social_reveal']) && is_array($ctx['social_reveal']) ? $ctx['social_reveal'] : [];
$_odCanMng    = !empty($ctx['can_manage']);
$_odPlatforms = isset($OD_SOCIAL_PLATFORMS) && is_array($OD_SOCIAL_PLATFORMS) ? $OD_SOCIAL_PLATFORMS : [];

// Keep only platforms we know how to render, preserving the canonical order.
$_odVisible = [];
foreach ($_odPlatforms as $_slug => $_meta) {
    if (!empty($_odSocialSet[$_slug])) {
        $_odVisible[] = $_slug;
    }
}

if (!empty($_odVisible) || $_odCanMng):
?>
<div class="od-connect-block"<?php if (!empty($_odVisible)): ?> data-od-reveal-url="<?= htmlspecialchars((string)($_odReveal['url'] ?? '')) ?>" data-od-reveal-token="<?= htmlspecialchars((string)($_odReveal['token'] ?? '')) ?>"<?php endif; ?>>
	<div class="od-connect-subhead">
		<span><i class="fas fa-share-alt"></i> Connect</span>
		<?php if ($_odCanMng): ?>
		<button class="od-connect-edit" type="button" onclick="odOpenDesignModal('about')" data-tip="Edit social links" aria-label="Edit social links"><i class="fas fa-pencil-alt" aria-hidden="true"></i></button>
		<?php endif; ?>
	</div>
	<?php if (!empty($_odVisible)): ?>
	<div class="od-connect-pills">
		<?php foreach ($_odVisible as $_slug):
			$_meta = $_odPlatforms[$_slug];
		?>
		<a class="od-connect-pill" href="#" role="button" rel="nofollow" data-od-social="<?= htmlspecialchars($_slug) ?>" data-tip="<?= htmlspecialchars($_meta['label']) ?>" aria-label="<?= htmlspecialchars($_meta['label']) ?> (opens in a new tab)">
			<i class="<?= $_meta['icon'] ?>" aria-hidden="true"></i>
		</a>
		<?php endforeach; ?>
	</div>
	<script>
	/* Social link reveal (one handler per page, delegated). */
	(function () {
		if (window.odSocialRevealBound) return;
		window.odSocialRevealBound = true;
		var revealed = {};
		function flash(a, msg) {
			var tip = a.getAttribute('data-tip');
			a.setAttribute('data-tip', msg);
			a.classList.add('od-connect-pill-err');
			setTimeout(function () { a.setAttribute('data-tip', tip); a.classList.remove('od-connect-pill-err'); }, 3500);
		}
		function go(win, url) {
			if (win) { try { win.opener = null; } catch (e) {} win.location.replace(url); }
			else { window.location.href = url; }
		}
		document.addEventListener('click', function (e) {
			var a = e.target.closest ? e.target.closest('a[data-od-social]') : null;
			if (!a) return;
			var box = a.closest('[data-od-reveal-url]');
			if (!box) return;
			e.preventDefault();
			var slug = a.getAttribute('data-od-social');
			var key = box.getAttribute('data-od-reveal-url') + '#' + slug;
			// Open the tab inside the click so popup blockers allow it, then point it at the link.
			var win = window.open('', '_blank');
			if (revealed[key]) { go(win, revealed[key]); return; }
			if (a.getAttribute('aria-busy') === 'true') { if (win) win.close(); return; }
			a.setAttribute('aria-busy', 'true');
			var fd = new FormData();
			fd.append('Platform', slug);
			fd.append('RevealToken', box.getAttribute('data-od-reveal-token') || '');
			fetch(box.getAttribute('data-od-reveal-url'), {
				method: 'POST', body: fd, credentials: 'same-origin',
				headers: { 'X-Requested-With': 'XMLHttpRequest' }
			}).then(function (r) { return r.json(); }).then(function (j) {
				a.removeAttribute('aria-busy');
				if (j && j.status === 0 && /^https:\/\//i.test(j.url || '')) {
					revealed[key] = j.url;
					go(win, j.url);
				} else {
					if (win) win.close();
					flash(a, (j && j.error) || 'Could not open that link. Reload and try again.');
				}
			}).catch(function () {
				a.removeAttribute('aria-busy');
				if (win) win.close();
				flash(a, 'Could not open that link. Reload and try again.');
			});
		});
	})();
	</script>
	<?php elseif ($_odCanMng): ?>
	<a href="#" class="od-connect-empty" onclick="event.preventDefault();odOpenDesignModal('about')">+ Add</a>
	<?php endif; ?>
</div>
<?php endif; ?>
