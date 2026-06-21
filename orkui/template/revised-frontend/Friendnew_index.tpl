<?php /* My Friends hub — plain PHP template. Vars: $Friends, $Requests, $FriendCount, $RequestCount, $Uid
   Reuses the Reports framing (reports.css + .rp-root/.rp-header + --rp-* vars) for header + card + dark mode. */ ?>
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
          <span class="rp-scope-chip"><span class="rp-scope-chip-label">Requests</span> <?= (int)$RequestCount ?></span>
        <?php endif; ?>
      </div>
    </div>
  </div>

  <div class="friends-body">
  <div class="friends-tabs" role="tablist">
    <button class="friends-tab active" data-tab="friends">Friends (<?= (int)$FriendCount ?>)</button>
    <button class="friends-tab" data-tab="requests">Requests<?= $RequestCount > 0 ? ' (' . (int)$RequestCount . ')' : '' ?></button>
    <button class="friends-tab" data-tab="feed">Activity</button>
  </div>

  <div class="friends-panel" id="tab-friends">
    <?php if (empty($Friends)): ?>
      <p class="muted">You haven't added any friends yet. Visit a player's profile to send a request.</p>
    <?php else: ?>
      <div class="friends-grid">
        <?php foreach ($Friends as $f): ?>
          <div class="friend-card">
            <a class="friend-card-name" href="index.php?Route=Player/profile/<?= (int)$f['MundaneId'] ?>"><?= htmlspecialchars($f['Persona']) ?></a>
            <span class="friend-card-sub"><?= htmlspecialchars(trim(($f['ParkAbbr'] ?? '') . ' ' . ($f['KingdomAbbr'] ?? ''))) ?></span>
            <button class="pn-btn pn-btn-white pn-btn-sm friend-recommend" data-target="<?= (int)$f['MundaneId'] ?>" data-name="<?= htmlspecialchars($f['Persona']) ?>"><i class="fas fa-award"></i> Recommend</button>
          </div>
        <?php endforeach; ?>
      </div>
    <?php endif; ?>
  </div>

  <div class="friends-panel" id="tab-requests" hidden>
    <?php if (empty($Requests)): ?>
      <p class="muted">No pending friend requests.</p>
    <?php else: ?>
      <div class="friends-grid">
        <?php foreach ($Requests as $r): ?>
          <div class="friend-card" data-target="<?= (int)$r['MundaneId'] ?>">
            <a class="friend-card-name" href="index.php?Route=Player/profile/<?= (int)$r['MundaneId'] ?>"><?= htmlspecialchars($r['Persona']) ?></a>
            <span class="friend-card-sub"><?= htmlspecialchars(trim(($r['ParkAbbr'] ?? '') . ' ' . ($r['KingdomAbbr'] ?? ''))) ?></span>
            <div class="friend-card-actions">
              <button class="pn-btn pn-btn-primary pn-btn-sm friend-action" data-act="accept" data-target="<?= (int)$r['MundaneId'] ?>">Accept</button>
              <button class="pn-btn pn-btn-ghost pn-btn-sm friend-action" data-act="decline" data-target="<?= (int)$r['MundaneId'] ?>">Decline</button>
            </div>
          </div>
        <?php endforeach; ?>
      </div>
    <?php endif; ?>
  </div>

  <div class="friends-panel" id="tab-feed" hidden>
    <div id="friendsFeed"><span class="muted">Loading activity…</span></div>
  </div>
  </div><!-- /.friends-body -->
</div><!-- /.rp-root -->
