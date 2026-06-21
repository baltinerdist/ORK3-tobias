<?php /* My Friends hub — plain PHP template.
   Vars: $Friends, $Requests (incoming), $Sent (outgoing), $FriendCount, $RequestCount, $SentCount, $Uid
   Reuses the Reports framing (reports.css + .rp-root/.rp-header + --rp-* vars) for header + card + dark mode.

   $fr_avatar(): photo → heraldry → monogram fallback. $fr_loc(): "Park · Kingdom". */
$fr_avatar = static function (array $p) {
    $url = $p['Avatar'] ?? '';
    if ($url !== '') {
        return '<span class="fr-avatar"><img src="' . htmlspecialchars($url) . '" alt="" loading="lazy"></span>';
    }
    return '<span class="fr-avatar fr-avatar-mono">' . htmlspecialchars($p['Initial'] ?? '?') . '</span>';
};
$fr_loc = static function (array $p) {
    // Full park name (recognizable) + kingdom abbreviation (compact, fits one line).
    $parts = array_filter([$p['ParkName'] ?? '', $p['KingdomAbbr'] ?? ''], static fn ($s) => trim((string)$s) !== '');
    return htmlspecialchars(implode(' · ', $parts));
};
?>
<link rel="stylesheet" href="<?= HTTP_TEMPLATE ?>revised-frontend/style/revised.css?v=<?= filemtime(__DIR__ . '/style/revised.css') ?>">
<link rel="stylesheet" href="<?= HTTP_TEMPLATE ?>default/style/reports.css?v=<?= @filemtime(__DIR__ . '/../default/style/reports.css') ?: '1' ?>">
<div class="rp-root friends-hub">
  <div class="rp-header">
    <div class="rp-header-left">
      <div class="rp-header-icon-title">
        <i class="fas fa-user-friends rp-header-icon"></i>
        <h1 class="rp-header-title">My Friends</h1>
      </div>
      <div class="rp-header-scope">
        <span class="rp-scope-chip"><span class="rp-scope-chip-label">Friends</span> <?= (int)$FriendCount ?></span>
        <?php if ((int)$RequestCount > 0): ?>
          <span class="rp-scope-chip"><span class="rp-scope-chip-label">Incoming</span> <?= (int)$RequestCount ?></span>
        <?php endif; ?>
      </div>
    </div>
  </div>

  <div class="friends-body">
  <div class="friends-tabs" role="tablist">
    <button class="friends-tab active" data-tab="friends">Friends (<?= (int)$FriendCount ?>)</button>
    <button class="friends-tab" data-tab="requests">Requests<?= ((int)$RequestCount + (int)$SentCount) > 0 ? ' (' . ((int)$RequestCount + (int)$SentCount) . ')' : '' ?></button>
    <button class="friends-tab" data-tab="feed">Activity</button>
  </div>

  <!-- Friends -->
  <div class="friends-panel" id="tab-friends">
    <?php if (empty($Friends)): ?>
      <p class="muted">You haven't added any friends yet. Visit a player's profile to send a request.</p>
    <?php else: ?>
      <div class="fr-grid">
        <?php foreach ($Friends as $f): $fid = (int)$f['MundaneId']; ?>
          <div class="fr-card">
            <a class="fr-main" href="index.php?Route=Player/profile/<?= $fid ?>">
              <?= $fr_avatar($f) ?>
              <span class="fr-meta">
                <span class="fr-name"><?= htmlspecialchars($f['Persona']) ?></span>
                <span class="fr-loc"><?= $fr_loc($f) ?></span>
                <?php if (!empty($f['Since'])): ?>
                  <span class="fr-since"><i class="far fa-clock"></i> Friends since <?= htmlspecialchars($f['Since']) ?></span>
                <?php endif; ?>
              </span>
            </a>
            <div class="fr-actions">
              <button class="pn-btn pn-btn-primary pn-btn-sm friend-recommend" data-target="<?= $fid ?>" data-name="<?= htmlspecialchars($f['Persona']) ?>"><i class="fas fa-award"></i> Recommend</button>
              <div class="friend-menu">
                <button class="pn-btn pn-btn-ghost pn-btn-sm friend-toggle" aria-label="More actions"><i class="fas fa-ellipsis-h"></i></button>
                <div class="friend-menu-pop">
                  <a class="friend-menu-link" href="index.php?Route=Player/profile/<?= $fid ?>">View profile</a>
                  <button class="friend-action" data-act="unfriend" data-target="<?= $fid ?>">Unfriend</button>
                  <button class="friend-action" data-act="block" data-target="<?= $fid ?>">Block</button>
                </div>
              </div>
            </div>
          </div>
        <?php endforeach; ?>
      </div>
    <?php endif; ?>
  </div>

  <!-- Requests: Incoming + Sent -->
  <div class="friends-panel" id="tab-requests" hidden>
    <?php if (empty($Requests) && empty($Sent)): ?>
      <p class="muted">No pending friend requests.</p>
    <?php else: ?>
      <?php if (!empty($Requests)): ?>
        <h3 class="fr-section-h">Incoming <span class="fr-section-n"><?= (int)$RequestCount ?></span></h3>
        <div class="fr-grid">
          <?php foreach ($Requests as $r): $rid = (int)$r['MundaneId']; ?>
            <div class="fr-card" data-card="<?= $rid ?>">
              <a class="fr-main" href="index.php?Route=Player/profile/<?= $rid ?>">
                <?= $fr_avatar($r) ?>
                <span class="fr-meta">
                  <span class="fr-name"><?= htmlspecialchars($r['Persona']) ?></span>
                  <span class="fr-loc"><?= $fr_loc($r) ?></span>
                </span>
              </a>
              <div class="fr-actions">
                <button class="pn-btn pn-btn-primary pn-btn-sm friend-action" data-act="accept" data-target="<?= $rid ?>">Accept</button>
                <button class="pn-btn pn-btn-secondary pn-btn-sm friend-action" data-act="decline" data-target="<?= $rid ?>">Decline</button>
              </div>
            </div>
          <?php endforeach; ?>
        </div>
      <?php endif; ?>

      <?php if (!empty($Sent)): ?>
        <h3 class="fr-section-h">Sent <span class="fr-section-n"><?= (int)$SentCount ?></span></h3>
        <div class="fr-grid">
          <?php foreach ($Sent as $s): $sid = (int)$s['MundaneId']; ?>
            <div class="fr-card" data-card="<?= $sid ?>">
              <a class="fr-main" href="index.php?Route=Player/profile/<?= $sid ?>">
                <?= $fr_avatar($s) ?>
                <span class="fr-meta">
                  <span class="fr-name"><?= htmlspecialchars($s['Persona']) ?></span>
                  <span class="fr-loc"><?= $fr_loc($s) ?></span>
                </span>
              </a>
              <div class="fr-actions">
                <span class="fr-pending-badge"><i class="far fa-clock"></i> Pending</span>
                <button class="pn-btn pn-btn-secondary pn-btn-sm friend-action" data-act="cancel" data-target="<?= $sid ?>">Cancel</button>
              </div>
            </div>
          <?php endforeach; ?>
        </div>
      <?php endif; ?>
    <?php endif; ?>
  </div>

  <!-- Activity feed -->
  <div class="friends-panel" id="tab-feed" hidden>
    <div id="friendsFeed"><span class="muted">Loading activity…</span></div>
  </div>
  </div><!-- /.friends-body -->
</div><!-- /.rp-root -->

<!-- Friends hub behavior (tabs, requests, feed, card actions) lives in revised.js. -->
<script src="<?= HTTP_TEMPLATE ?>revised-frontend/script/revised.js?v=<?= filemtime(__DIR__ . '/script/revised.js') ?>"></script>
