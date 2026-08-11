<?php
	// Scroll Graphic Submissions — Moderation page.
	// Rendered by Controller_ScrollGraphics::moderate(); $sg_config injected.
	// Keys: uir, token, kingdomId, kingdomName, isOrkAdmin, isKingdomOfficer, canModerate
	$sg = $sg_config ?? array();
?>
<link rel="stylesheet" href="<?= HTTP_TEMPLATE ?>revised-frontend/style/scroll-graphics.css?v=<?= filemtime(DIR_TEMPLATE . 'revised-frontend/style/scroll-graphics.css') ?>">
<style>
/* ScrollGraphics_moderate page-specific styles (shared shell in scroll-graphics.css) */
.sgm-section { margin: 0 0 32px; }
.sgm-section-head { display: flex; align-items: baseline; gap: 10px; margin: 0 0 14px; }
.sgm-section-head h2 {
	background: transparent; border: none; padding: 0; border-radius: 0; text-shadow: none;
	margin: 0; font-size: 1.25rem; font-weight: 700; color: #2d3748;
}
.sgm-scope-pill {
	font-size: 0.72rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.04em;
	padding: 3px 9px; border-radius: 999px; background: #e2e8f0; color: #4a5568;
}
.sgm-scope-pill.sgm-scope-global { background: #dbeafe; color: #1e40af; }
.sgm-scope-pill.sgm-scope-kingdom { background: #fef3c7; color: #92400e; }

.sgm-queue { display: flex; flex-direction: column; gap: 14px; }
.sc-artwork-loading, .sc-artwork-empty-state {
	display: flex; align-items: center; justify-content: center; gap: 10px;
	padding: 36px 16px; color: #718096; font-size: 0.95rem;
	border: 1px dashed #cbd5e0; border-radius: 10px; background: #f7fafc;
}
.sc-artwork-empty-state i, .sc-artwork-loading i { font-size: 1.2rem; }

.sc-artwork-admin-item {
	display: flex; gap: 16px; padding: 16px;
	border: 1px solid #e2e8f0; border-radius: 12px; background: #fff;
	box-shadow: 0 1px 3px rgba(0,0,0,0.06);
}
.sc-artwork-admin-thumb {
	flex: 0 0 120px; width: 120px; height: 120px;
	border: 1px solid #edf2f7; border-radius: 8px; overflow: hidden;
	background: #f7fafc url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='16' height='16'%3E%3Crect width='8' height='8' fill='%23eee'/%3E%3Crect x='8' y='8' width='8' height='8' fill='%23eee'/%3E%3C/svg%3E") repeat;
	display: flex; align-items: center; justify-content: center;
}
.sc-artwork-admin-thumb img { max-width: 100%; max-height: 100%; object-fit: contain; }
.sc-artwork-admin-info { flex: 1 1 auto; min-width: 0; display: flex; flex-direction: column; gap: 4px; }
.sc-artwork-admin-name { font-weight: 700; font-size: 1.05rem; color: #2d3748; }
.sc-artwork-admin-meta { font-size: 0.85rem; color: #718096; word-break: break-word; }
.sc-artwork-admin-badges { display: flex; flex-wrap: wrap; gap: 6px; margin: 2px 0; }
.sgm-tier-badge {
	font-size: 0.7rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.03em;
	padding: 2px 8px; border-radius: 999px;
}
.sgm-tier-badge.sgm-tier-global { background: #dbeafe; color: #1e40af; }
.sgm-tier-badge.sgm-tier-kingdom { background: #fef3c7; color: #92400e; }
.sgm-cat-badge {
	font-size: 0.7rem; font-weight: 600; padding: 2px 8px; border-radius: 999px;
	background: #edf2f7; color: #4a5568;
}
.sgm-license { font-size: 0.8rem; color: #718096; }
.sgm-license strong { color: #4a5568; font-weight: 600; }

.sc-artwork-admin-actions { display: flex; gap: 8px; margin-top: 8px; }
.sc-btn-approve, .sc-btn-reject {
	display: inline-flex; align-items: center; gap: 6px;
	padding: 7px 14px; border-radius: 8px; border: 1px solid transparent;
	font-size: 0.85rem; font-weight: 600; cursor: pointer;
}
.sc-btn-approve { background: #38a169; color: #fff; }
.sc-btn-approve:hover { background: #2f855a; }
.sc-btn-reject { background: #fff; color: #c53030; border-color: #fc8181; }
.sc-btn-reject:hover { background: #fff5f5; }

.sc-artwork-reject-input { display: none; gap: 8px; margin-top: 10px; }
.sc-artwork-reject-input.sc-visible { display: flex; }
.sc-artwork-reject-input input {
	flex: 1 1 auto; padding: 7px 10px; border: 1px solid #cbd5e0; border-radius: 8px; font-size: 0.85rem;
}
.sc-artwork-reject-input button {
	padding: 7px 14px; border-radius: 8px; border: none;
	background: #c53030; color: #fff; font-weight: 600; cursor: pointer;
}
.sc-artwork-reject-input button:hover { background: #9b2c2c; }

.sc-artwork-admin-pagination { display: none; align-items: center; justify-content: center; gap: 14px; margin-top: 14px; }
.sc-artwork-admin-pagination button {
	padding: 6px 14px; border: 1px solid #cbd5e0; border-radius: 8px;
	background: #fff; color: #2d3748; font-weight: 600; cursor: pointer;
}
.sc-artwork-admin-pagination button:disabled { opacity: 0.4; cursor: default; }

/* Manage Categories panel */
.sgm-cat-panel {
	border: 1px solid #e2e8f0; border-radius: 12px; background: #fff; padding: 18px;
	box-shadow: 0 1px 3px rgba(0,0,0,0.06);
}
.sgm-cat-list { display: flex; flex-direction: column; gap: 8px; margin: 0 0 18px; }
.sgm-cat-row {
	display: flex; align-items: center; gap: 12px; padding: 9px 12px;
	border: 1px solid #edf2f7; border-radius: 8px; background: #f7fafc;
}
.sgm-cat-row.sgm-cat-retired { opacity: 0.55; }
.sgm-cat-row-label { flex: 1 1 auto; font-weight: 600; color: #2d3748; }
.sgm-cat-row-sort { font-size: 0.8rem; color: #718096; }
.sgm-cat-row-status { font-size: 0.72rem; font-weight: 700; text-transform: uppercase; padding: 2px 8px; border-radius: 999px; }
.sgm-cat-row-status.on { background: #c6f6d5; color: #22543d; }
.sgm-cat-row-status.off { background: #fed7d7; color: #742a2a; }
.sgm-cat-row-actions { display: flex; gap: 6px; }
.sgm-cat-row-actions button {
	padding: 5px 11px; border-radius: 7px; border: 1px solid #cbd5e0; background: #fff;
	color: #2d3748; font-size: 0.8rem; font-weight: 600; cursor: pointer;
}
.sgm-cat-row-actions button.sgm-retire { color: #c53030; border-color: #fc8181; }
.sgm-cat-row-actions button.sgm-restore { color: #2f855a; border-color: #9ae6b4; }

.sgm-cat-form { display: flex; flex-wrap: wrap; gap: 12px; align-items: flex-end; border-top: 1px solid #edf2f7; padding-top: 16px; }
.sgm-cat-form .sgm-field { display: flex; flex-direction: column; gap: 4px; }
.sgm-cat-form label { font-size: 0.8rem; font-weight: 600; color: #4a5568; }
.sgm-cat-form input[type="text"], .sgm-cat-form input[type="number"] {
	padding: 7px 10px; border: 1px solid #cbd5e0; border-radius: 8px; font-size: 0.9rem;
}
.sgm-cat-form input[type="text"] { width: 220px; }
.sgm-cat-form input[type="number"] { width: 90px; }
.sgm-cat-form .sgm-check { display: flex; align-items: center; gap: 6px; font-size: 0.85rem; color: #4a5568; }
.sgm-cat-form .sgm-save-btn {
	padding: 8px 16px; border-radius: 8px; border: none; background: #3182ce; color: #fff;
	font-weight: 600; cursor: pointer;
}
.sgm-cat-form .sgm-save-btn:hover { background: #2b6cb0; }
.sgm-cat-form .sgm-cancel-btn {
	padding: 8px 14px; border-radius: 8px; border: 1px solid #cbd5e0; background: #fff;
	color: #4a5568; font-weight: 600; cursor: pointer;
}
.sgm-cat-form-title { width: 100%; font-weight: 700; color: #2d3748; margin: 0 0 4px; }

/* Toast */
#sgm-toast {
	position: fixed; left: 50%; bottom: 28px; transform: translateX(-50%) translateY(20px);
	background: #2d3748; color: #fff; padding: 11px 20px; border-radius: 10px;
	font-size: 0.9rem; box-shadow: 0 6px 20px rgba(0,0,0,0.25); opacity: 0;
	pointer-events: none; transition: opacity 0.2s, transform 0.2s; z-index: 9999; max-width: 90vw;
}
#sgm-toast.sgm-show { opacity: 1; transform: translateX(-50%) translateY(0); }
#sgm-toast.sgm-warn { background: #c53030; }

/* ---- Dark mode ---- */
html[data-theme="dark"] .sgm-section-head h2 { color: #e2e8f0; }
html[data-theme="dark"] .sgm-scope-pill { background: #2d3748; color: #cbd5e0; }
html[data-theme="dark"] .sgm-scope-pill.sgm-scope-global { background: #1e3a5f; color: #bfdbfe; }
html[data-theme="dark"] .sgm-scope-pill.sgm-scope-kingdom { background: #5a3a12; color: #fde68a; }
html[data-theme="dark"] .sc-artwork-loading,
html[data-theme="dark"] .sc-artwork-empty-state { background: #1a202c; border-color: #2d3748; color: #a0aec0; }
html[data-theme="dark"] .sc-artwork-admin-item { background: #1a202c; border-color: #2d3748; box-shadow: none; }
html[data-theme="dark"] .sc-artwork-admin-thumb { border-color: #2d3748; }
html[data-theme="dark"] .sc-artwork-admin-name { color: #e2e8f0; }
html[data-theme="dark"] .sc-artwork-admin-meta { color: #a0aec0; }
html[data-theme="dark"] .sgm-tier-badge.sgm-tier-global { background: #1e3a5f; color: #bfdbfe; }
html[data-theme="dark"] .sgm-tier-badge.sgm-tier-kingdom { background: #5a3a12; color: #fde68a; }
html[data-theme="dark"] .sgm-cat-badge { background: #2d3748; color: #cbd5e0; }
html[data-theme="dark"] .sgm-license { color: #a0aec0; }
html[data-theme="dark"] .sgm-license strong { color: #cbd5e0; }
html[data-theme="dark"] .sc-btn-reject { background: #1a202c; color: #fc8181; border-color: #9b2c2c; }
html[data-theme="dark"] .sc-btn-reject:hover { background: #2d2020; }
html[data-theme="dark"] .sc-artwork-reject-input input { background: #1a202c; border-color: #2d3748; color: #e2e8f0; }
html[data-theme="dark"] .sc-artwork-admin-pagination button { background: #1a202c; border-color: #2d3748; color: #e2e8f0; }
html[data-theme="dark"] .sgm-cat-panel { background: #1a202c; border-color: #2d3748; box-shadow: none; }
html[data-theme="dark"] .sgm-cat-row { background: #171c26; border-color: #2d3748; }
html[data-theme="dark"] .sgm-cat-row-label { color: #e2e8f0; }
html[data-theme="dark"] .sgm-cat-row-sort { color: #a0aec0; }
html[data-theme="dark"] .sgm-cat-row-actions button { background: #1a202c; border-color: #2d3748; color: #e2e8f0; }
html[data-theme="dark"] .sgm-cat-form { border-top-color: #2d3748; }
html[data-theme="dark"] .sgm-cat-form label { color: #cbd5e0; }
html[data-theme="dark"] .sgm-cat-form-title { color: #e2e8f0; }
html[data-theme="dark"] .sgm-cat-form input[type="text"],
html[data-theme="dark"] .sgm-cat-form input[type="number"] { background: #1a202c; border-color: #2d3748; color: #e2e8f0; }
html[data-theme="dark"] .sgm-cat-form .sgm-check { color: #cbd5e0; }
html[data-theme="dark"] .sgm-cat-form .sgm-cancel-btn { background: #1a202c; border-color: #2d3748; color: #cbd5e0; }
</style>

<div class="sg-wrap">
  <nav class="sg-tabs">
    <a class="sg-tab" href="<?= UIR ?>ScrollGraphics"><i class="fas fa-images"></i> Library</a>
    <a class="sg-tab" href="<?= UIR ?>ScrollGraphics/upload"><i class="fas fa-upload"></i> Submit a Graphic</a>
    <a class="sg-tab" href="<?= UIR ?>ScrollGraphics/mine"><i class="fas fa-folder"></i> My Submissions</a>
    <a class="sg-tab active" href="<?= UIR ?>ScrollGraphics/moderate"><i class="fas fa-gavel"></i> Moderate</a>
    <?php if (!empty($sg['canManage'])): ?>
      <a class="sg-tab" href="<?= UIR ?>ScrollGraphics/manage"><i class="fas fa-sliders-h"></i> Manage Library</a>
    <?php endif; ?>
  </nav>

  <div class="sg-body" style="display:block;">

    <?php if (!empty($sg['isOrkAdmin'])): ?>
      <section class="sgm-section" id="sgm-global-section">
        <div class="sgm-section-head">
          <h2>Global Submission Queue</h2>
          <span class="sgm-scope-pill sgm-scope-global">Amtgard-wide</span>
        </div>
        <div class="sgm-queue">
          <div id="sgm-global-list" class="sc-artwork-admin-list"></div>
          <div id="sgm-global-pagination" class="sc-artwork-admin-pagination">
            <button type="button"><i class="fas fa-chevron-left"></i> Prev</button>
            <span id="sgm-global-page-info">Page 1 of 1</span>
            <button type="button">Next <i class="fas fa-chevron-right"></i></button>
          </div>
        </div>
      </section>

      <section class="sgm-section" id="sgm-categories-section">
        <div class="sgm-section-head">
          <h2>Manage Categories</h2>
          <span class="sgm-scope-pill">Admin</span>
        </div>
        <div class="sgm-cat-panel">
          <div id="sgm-cat-list" class="sgm-cat-list"></div>
          <form class="sgm-cat-form" id="sgm-cat-form" autocomplete="off">
            <div class="sgm-cat-form-title" id="sgm-cat-form-title">Add a category</div>
            <input type="hidden" id="sgm-cat-id" value="0">
            <div class="sgm-field">
              <label for="sgm-cat-label">Label</label>
              <input type="text" id="sgm-cat-label" maxlength="120" placeholder="e.g. Heraldic">
            </div>
            <div class="sgm-field">
              <label for="sgm-cat-sort">Sort order</label>
              <input type="number" id="sgm-cat-sort" value="0" step="10">
            </div>
            <label class="sgm-check"><input type="checkbox" id="sgm-cat-active" checked> Active</label>
            <button type="submit" class="sgm-save-btn"><i class="fas fa-save"></i> Save</button>
            <button type="button" class="sgm-cancel-btn" id="sgm-cat-cancel" style="display:none;">Cancel</button>
          </form>
        </div>
      </section>
    <?php endif; ?>

    <?php if (!empty($sg['isKingdomOfficer'])): ?>
      <section class="sgm-section" id="sgm-kingdom-section">
        <div class="sgm-section-head">
          <h2><?= htmlspecialchars($sg['kingdomName'] ?? 'Kingdom') ?> Submission Queue</h2>
          <span class="sgm-scope-pill sgm-scope-kingdom">Kingdom</span>
        </div>
        <div class="sgm-queue">
          <div id="sgm-kingdom-list" class="sc-artwork-admin-list"></div>
          <div id="sgm-kingdom-pagination" class="sc-artwork-admin-pagination">
            <button type="button"><i class="fas fa-chevron-left"></i> Prev</button>
            <span id="sgm-kingdom-page-info">Page 1 of 1</span>
            <button type="button">Next <i class="fas fa-chevron-right"></i></button>
          </div>
        </div>
      </section>
    <?php endif; ?>

  </div>
</div>

<div id="sgm-toast"></div>

<script>
var SG = <?= json_encode($sg, JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS) ?>;
(function () {
  'use strict';

  var AJAX = SG.uir + 'ScrollArtworkAjax/';

  // ---- helpers ----
  function sgEscapeHtml(s) {
    if (s === null || s === undefined || s === '') return '';
    var d = document.createElement('div');
    d.textContent = String(s);
    return d.innerHTML;
  }
  function el(id) { return document.getElementById(id); }

  var _toastTimer = null;
  function sgToast(msg, kind) {
    var t = el('sgm-toast');
    if (!t) return;
    t.textContent = msg;
    t.className = (kind === 'warn') ? 'sgm-warn sgm-show' : 'sgm-show';
    if (_toastTimer) clearTimeout(_toastTimer);
    _toastTimer = setTimeout(function () { t.className = ''; }, 3200);
  }

  // ============================================================
  //  Moderation queue (scoped: global | kingdom)
  // ============================================================
  function Queue(scope, listId, pagId, pageInfoId) {
    this.scope = scope;
    this.listId = listId;
    this.pagId = pagId;
    this.pageInfoId = pageInfoId;
    this.page = 1;
  }

  Queue.prototype.load = function () {
    var self = this;
    var list = el(this.listId);
    if (list) list.innerHTML = '<div class="sc-artwork-loading"><i class="fas fa-spinner fa-spin"></i> Loading...</div>';
    fetch(AJAX + 'pending&scope=' + encodeURIComponent(this.scope) + '&page=' + this.page)
      .then(function (r) { return r.json(); })
      .then(function (data) { self.render(data); })
      .catch(function () {
        if (list) list.innerHTML = '<div class="sc-artwork-empty-state"><i class="fas fa-exclamation-triangle"></i>Failed to load pending artwork</div>';
      });
  };

  Queue.prototype.render = function (data) {
    var list = el(this.listId);
    if (!list) return;
    var items = (data && data.Artwork) || [];
    if (items.length === 0) {
      list.innerHTML = '<div class="sc-artwork-empty-state"><i class="fas fa-check-circle"></i>No pending artwork to review.</div>';
    } else {
      var html = '';
      for (var i = 0; i < items.length; i++) {
        var item = items[i];
        var isKingdom = (item.Visibility === 'kingdom');
        var tierClass = isKingdom ? 'sgm-tier-kingdom' : 'sgm-tier-global';
        var tierText = isKingdom ? 'Kingdom' : 'Amtgard';

        html += '<div class="sc-artwork-admin-item" data-id="' + item.ArtworkId + '">';
        html += '<div class="sc-artwork-admin-thumb"><img src="' + sgEscapeHtml(item.Url || '') + '" alt="' + sgEscapeHtml(item.Name || '') + '" loading="lazy"></div>';
        html += '<div class="sc-artwork-admin-info">';
        html += '<div class="sc-artwork-admin-name">' + sgEscapeHtml(item.Name || 'Untitled') + '</div>';

        html += '<div class="sc-artwork-admin-badges">';
        html += '<span class="sgm-tier-badge ' + tierClass + '">' + tierText + '</span>';
        if (item.CategoryLabel) { html += '<span class="sgm-cat-badge">' + sgEscapeHtml(item.CategoryLabel) + '</span>'; }
        html += '</div>';

        html += '<div class="sc-artwork-admin-meta">Submitted by ' + sgEscapeHtml(item.UploaderPersona || 'Unknown') +
                ' — ' + sgEscapeHtml(item.LayoutLocation || '') +
                ' — ' + (item.Width || '?') + ' × ' + (item.Height || '?') + 'px</div>';
        if (item.Description) html += '<div class="sc-artwork-admin-meta">' + sgEscapeHtml(item.Description) + '</div>';
        if (item.Tags) html += '<div class="sc-artwork-admin-meta">Tags: ' + sgEscapeHtml(item.Tags) + '</div>';

        if (item.LicenseSignerName) {
          html += '<div class="sgm-license"><strong>License signed by</strong> ' + sgEscapeHtml(item.LicenseSignerName);
          if (item.LicenseSignedAt) html += ' on ' + sgEscapeHtml(item.LicenseSignedAt);
          html += '</div>';
        }

        html += '<div class="sc-artwork-admin-actions">';
        html += '<button type="button" class="sc-btn-approve" data-act="approve" data-id="' + item.ArtworkId + '"><i class="fas fa-check"></i> Approve</button>';
        html += '<button type="button" class="sc-btn-reject" data-act="show-reject"><i class="fas fa-times"></i> Reject</button>';
        html += '</div>';
        html += '<div class="sc-artwork-reject-input">';
        html += '<input type="text" placeholder="Reason for rejection..." maxlength="500">';
        html += '<button type="button" data-act="reject" data-id="' + item.ArtworkId + '">Reject</button>';
        html += '</div>';
        html += '</div></div>';
      }
      list.innerHTML = html;
    }

    // Pagination
    var pagEl = el(this.pagId);
    var pageInfo = el(this.pageInfoId);
    var total = parseInt(data && data.Total, 10) || 0;
    var perPage = parseInt(data && data.PerPage, 10) || 20;
    var page = parseInt(data && data.Page, 10) || 1;
    this.page = page;
    var totalPages = Math.max(1, Math.ceil(total / perPage));
    if (total > perPage && pagEl) {
      pagEl.style.display = 'flex';
      if (pageInfo) pageInfo.textContent = 'Page ' + page + ' of ' + totalPages;
      var btns = pagEl.querySelectorAll('button');
      if (btns[0]) btns[0].disabled = (page <= 1);
      if (btns[1]) btns[1].disabled = (page >= totalPages);
    } else if (pagEl) {
      pagEl.style.display = 'none';
    }
  };

  Queue.prototype.emptyIfDone = function (list) {
    if (list && !list.querySelector('.sc-artwork-admin-item')) {
      list.innerHTML = '<div class="sc-artwork-empty-state"><i class="fas fa-check-circle"></i>No pending artwork to review.</div>';
    }
  };

  Queue.prototype.approve = function (artworkId, btnEl) {
    var self = this;
    if (!SG.token) { sgToast('Not authorized', 'warn'); return; }
    var fd = new FormData();
    fd.append('artwork_id', artworkId);
    fetch(AJAX + 'approve', { method: 'POST', body: fd })
      .then(function (r) { return r.json(); })
      .then(function (data) {
        if (data.Status === 0) {
          sgToast('Artwork approved');
          var row = btnEl.closest('.sc-artwork-admin-item');
          if (row) row.remove();
          self.emptyIfDone(el(self.listId));
        } else {
          sgToast(data.Message || 'Approval failed', 'warn');
        }
      })
      .catch(function () { sgToast('Approval failed', 'warn'); });
  };

  Queue.prototype.showReject = function (btnEl) {
    var item = btnEl.closest('.sc-artwork-admin-item');
    if (!item) return;
    var rejectRow = item.querySelector('.sc-artwork-reject-input');
    if (rejectRow) {
      rejectRow.classList.toggle('sc-visible');
      var inp = rejectRow.querySelector('input');
      if (inp && rejectRow.classList.contains('sc-visible')) inp.focus();
    }
  };

  Queue.prototype.reject = function (artworkId, btnEl) {
    var self = this;
    var row = btnEl.closest('.sc-artwork-reject-input');
    var input = row ? row.querySelector('input') : null;
    var reason = input ? input.value.trim() : '';
    if (!reason) { sgToast('Please enter a reason for rejection', 'warn'); return; }
    if (!SG.token) { sgToast('Not authorized', 'warn'); return; }
    var fd = new FormData();
    fd.append('artwork_id', artworkId);
    fd.append('reason', reason);
    fetch(AJAX + 'reject', { method: 'POST', body: fd })
      .then(function (r) { return r.json(); })
      .then(function (data) {
        if (data.Status === 0) {
          sgToast('Artwork rejected');
          var item = btnEl.closest('.sc-artwork-admin-item');
          if (item) item.remove();
          self.emptyIfDone(el(self.listId));
        } else {
          sgToast(data.Message || 'Rejection failed', 'warn');
        }
      })
      .catch(function () { sgToast('Rejection failed', 'warn'); });
  };

  Queue.prototype.wire = function () {
    var self = this;
    var list = el(this.listId);
    if (list) {
      list.addEventListener('click', function (e) {
        var btn = e.target.closest('button[data-act]');
        if (!btn) return;
        var act = btn.getAttribute('data-act');
        if (act === 'approve') self.approve(btn.getAttribute('data-id'), btn);
        else if (act === 'show-reject') self.showReject(btn);
        else if (act === 'reject') self.reject(btn.getAttribute('data-id'), btn);
      });
    }
    var pagEl = el(this.pagId);
    if (pagEl) {
      var btns = pagEl.querySelectorAll('button');
      if (btns[0]) btns[0].addEventListener('click', function () {
        if (self.page > 1) { self.page--; self.load(); }
      });
      if (btns[1]) btns[1].addEventListener('click', function () {
        self.page++; self.load();
      });
    }
  };

  // ============================================================
  //  Manage Categories
  // ============================================================
  function loadCategories() {
    var host = el('sgm-cat-list');
    if (!host) return;
    host.innerHTML = '<div class="sc-artwork-loading"><i class="fas fa-spinner fa-spin"></i> Loading...</div>';
    fetch(AJAX + 'categories')
      .then(function (r) { return r.json(); })
      .then(function (data) {
        var cats = (data && data.Categories) || [];
        if (cats.length === 0) {
          host.innerHTML = '<div class="sc-artwork-empty-state"><i class="fas fa-folder-open"></i>No categories yet.</div>';
          return;
        }
        var html = '';
        for (var i = 0; i < cats.length; i++) {
          var c = cats[i];
          var active = (parseInt(c.Active, 10) === 1) || c.Active === true || c.Active === '1';
          html += '<div class="sgm-cat-row' + (active ? '' : ' sgm-cat-retired') + '" ' +
                  'data-id="' + sgEscapeHtml(c.CategoryId) + '" ' +
                  'data-label="' + sgEscapeHtml(c.Label) + '" ' +
                  'data-sort="' + sgEscapeHtml(c.SortOrder) + '" ' +
                  'data-active="' + (active ? '1' : '0') + '">';
          html += '<span class="sgm-cat-row-label">' + sgEscapeHtml(c.Label || '') + '</span>';
          html += '<span class="sgm-cat-row-sort">sort ' + sgEscapeHtml(c.SortOrder) + '</span>';
          html += '<span class="sgm-cat-row-status ' + (active ? 'on' : 'off') + '">' + (active ? 'Active' : 'Retired') + '</span>';
          html += '<span class="sgm-cat-row-actions">';
          html += '<button type="button" data-act="edit"><i class="fas fa-pen"></i> Edit</button>';
          if (active) {
            html += '<button type="button" class="sgm-retire" data-act="retire"><i class="fas fa-ban"></i> Retire</button>';
          } else {
            html += '<button type="button" class="sgm-restore" data-act="restore"><i class="fas fa-undo"></i> Restore</button>';
          }
          html += '</span>';
          html += '</div>';
        }
        host.innerHTML = html;
      })
      .catch(function () {
        host.innerHTML = '<div class="sc-artwork-empty-state"><i class="fas fa-exclamation-triangle"></i>Failed to load categories</div>';
      });
  }

  function saveCategory(categoryId, label, sortOrder, active, onDone) {
    if (!SG.token) { sgToast('Not authorized', 'warn'); return; }
    var fd = new FormData();
    fd.append('category_id', categoryId);
    fd.append('label', label);
    fd.append('sort_order', sortOrder);
    fd.append('active', active ? '1' : '0');
    fetch(AJAX + 'save_category', { method: 'POST', body: fd })
      .then(function (r) { return r.json(); })
      .then(function (data) {
        if (data.Status === 0) {
          sgToast('Category saved');
          if (onDone) onDone();
          loadCategories();
        } else {
          sgToast(data.Message || 'Save failed', 'warn');
        }
      })
      .catch(function () { sgToast('Save failed', 'warn'); });
  }

  function resetCatForm() {
    el('sgm-cat-id').value = '0';
    el('sgm-cat-label').value = '';
    el('sgm-cat-sort').value = '0';
    el('sgm-cat-active').checked = true;
    el('sgm-cat-form-title').textContent = 'Add a category';
    var cancel = el('sgm-cat-cancel');
    if (cancel) cancel.style.display = 'none';
  }

  function editCatRow(row) {
    el('sgm-cat-id').value = row.getAttribute('data-id');
    el('sgm-cat-label').value = row.getAttribute('data-label') || '';
    el('sgm-cat-sort').value = row.getAttribute('data-sort') || '0';
    el('sgm-cat-active').checked = (row.getAttribute('data-active') === '1');
    el('sgm-cat-form-title').textContent = 'Edit category';
    var cancel = el('sgm-cat-cancel');
    if (cancel) cancel.style.display = 'inline-block';
    el('sgm-cat-label').focus();
  }

  function wireCategories() {
    var list = el('sgm-cat-list');
    if (list) {
      list.addEventListener('click', function (e) {
        var btn = e.target.closest('button[data-act]');
        if (!btn) return;
        var row = btn.closest('.sgm-cat-row');
        if (!row) return;
        var act = btn.getAttribute('data-act');
        if (act === 'edit') {
          editCatRow(row);
        } else if (act === 'retire') {
          saveCategory(row.getAttribute('data-id'), row.getAttribute('data-label') || '', row.getAttribute('data-sort') || '0', false);
        } else if (act === 'restore') {
          saveCategory(row.getAttribute('data-id'), row.getAttribute('data-label') || '', row.getAttribute('data-sort') || '0', true);
        }
      });
    }

    var form = el('sgm-cat-form');
    if (form) {
      form.addEventListener('submit', function (e) {
        e.preventDefault();
        var label = el('sgm-cat-label').value.trim();
        if (!label) { sgToast('Please enter a label', 'warn'); return; }
        var sortRaw = parseInt(el('sgm-cat-sort').value, 10);
        var sort = isNaN(sortRaw) ? 0 : sortRaw;
        saveCategory(el('sgm-cat-id').value || '0', label, sort, el('sgm-cat-active').checked, resetCatForm);
      });
    }
    var cancel = el('sgm-cat-cancel');
    if (cancel) cancel.addEventListener('click', resetCatForm);
  }

  // ============================================================
  function init() {
    if (SG.isOrkAdmin) {
      var globalQueue = new Queue('global', 'sgm-global-list', 'sgm-global-pagination', 'sgm-global-page-info');
      globalQueue.wire();
      globalQueue.load();

      wireCategories();
      loadCategories();
    }
    if (SG.isKingdomOfficer) {
      var kingdomQueue = new Queue('kingdom', 'sgm-kingdom-list', 'sgm-kingdom-pagination', 'sgm-kingdom-page-info');
      kingdomQueue.wire();
      kingdomQueue.load();
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
</script>
