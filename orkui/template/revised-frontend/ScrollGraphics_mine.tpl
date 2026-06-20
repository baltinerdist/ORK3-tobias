<?php
    // Scroll Graphic Submissions — My Submissions page.
    // Rendered by Controller_ScrollGraphics::mine(); $sg_config injected.
    // Keys: uir, token, kingdomId, kingdomName, isOrkAdmin, isKingdomOfficer, canModerate
    $sg = $sg_config ?? array();
?>
<link rel="stylesheet" href="<?= HTTP_TEMPLATE ?>revised-frontend/style/scroll-graphics.css?v=<?= filemtime(DIR_TEMPLATE . 'revised-frontend/style/scroll-graphics.css') ?>">
<style>
/* ---- My Submissions page-specific styles ---- */
.sg-mine-wrap {
  padding: 0;
}
.sg-mine-toolbar {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 20px;
  flex-wrap: wrap;
}
.sg-mine-toolbar label {
  font-size: .85rem;
  font-weight: 600;
  color: #555;
}
.sg-mine-filter {
  padding: 6px 10px;
  border: 1px solid #ccc;
  border-radius: 6px;
  font-size: .85rem;
  background: #fff;
  color: #222;
}
.sg-mine-list {
  display: flex;
  flex-direction: column;
  gap: 12px;
}
.sg-mine-item {
  display: flex;
  align-items: flex-start;
  gap: 14px;
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 10px;
  padding: 14px;
  transition: box-shadow .15s;
}
.sg-mine-item:hover {
  box-shadow: 0 3px 10px rgba(0,0,0,.1);
}
.sg-mine-thumb {
  width: 90px;
  height: 70px;
  flex-shrink: 0;
  border-radius: 6px;
  overflow: hidden;
  background: #f0f0f0;
  display: flex;
  align-items: center;
  justify-content: center;
}
.sg-mine-thumb img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.sg-mine-info {
  flex: 1 1 auto;
  min-width: 0;
}
.sg-mine-name {
  font-weight: 700;
  font-size: .95rem;
  color: #222;
  margin-bottom: 4px;
  display: flex;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;
}
.sg-mine-meta {
  font-size: .8rem;
  color: #666;
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
  margin-top: 4px;
}
.sg-mine-meta-item {
  display: flex;
  align-items: center;
  gap: 4px;
}
.sg-mine-rejection {
  margin-top: 8px;
  padding: 8px 12px;
  background: #fff5f5;
  border-left: 3px solid #e53e3e;
  border-radius: 0 6px 6px 0;
  font-size: .82rem;
  color: #c53030;
}
.sg-mine-actions {
  flex-shrink: 0;
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 8px;
}
.sg-mine-delete-btn {
  background: #fed7d7;
  color: #c53030;
  border: 1px solid #fc8181;
  border-radius: 6px;
  padding: 6px 14px;
  font-size: .82rem;
  font-weight: 600;
  cursor: pointer;
  display: flex;
  align-items: center;
  gap: 6px;
  transition: background .15s, color .15s;
}
.sg-mine-delete-btn:hover {
  background: #fc8181;
  color: #fff;
}
/* Status badges */
.sg-status-pending {
  background: #fefcbf;
  color: #744210;
  border: 1px solid #f6e05e;
  border-radius: 4px;
  padding: 1px 8px;
  font-size: .75rem;
  font-weight: 600;
  text-transform: capitalize;
}
.sg-status-approved {
  background: #c6f6d5;
  color: #22543d;
  border: 1px solid #68d391;
  border-radius: 4px;
  padding: 1px 8px;
  font-size: .75rem;
  font-weight: 600;
  text-transform: capitalize;
}
.sg-status-rejected {
  background: #fed7d7;
  color: #822727;
  border: 1px solid #fc8181;
  border-radius: 4px;
  padding: 1px 8px;
  font-size: .75rem;
  font-weight: 600;
  text-transform: capitalize;
}
.sg-mine-pagination {
  display: none;
  align-items: center;
  gap: 14px;
  justify-content: center;
  margin-top: 24px;
}
.sg-mine-pagination.active { display: flex; }
.sg-mine-pg-btn {
  background: #edf2f7;
  border: 1px solid #cbd5e0;
  border-radius: 6px;
  padding: 6px 16px;
  cursor: pointer;
  font-size: .85rem;
  transition: background .15s;
}
.sg-mine-pg-btn:disabled { opacity: .45; cursor: not-allowed; }
.sg-mine-pg-btn:not(:disabled):hover { background: #e2e8f0; }
.sg-mine-pg-info { font-size: .85rem; color: #555; }

/* ---- Inline confirm modal ---- */
.sg-confirm-backdrop {
  display: none;
  position: fixed;
  inset: 0;
  background: rgba(0,0,0,.45);
  z-index: 9000;
  align-items: center;
  justify-content: center;
}
.sg-confirm-backdrop.active { display: flex; }
.sg-confirm-box {
  background: #fff;
  border-radius: 12px;
  padding: 28px 32px;
  max-width: 380px;
  width: 90%;
  box-shadow: 0 8px 32px rgba(0,0,0,.2);
}
.sg-confirm-title {
  font-size: 1.05rem;
  font-weight: 700;
  color: #1a202c;
  margin: 0 0 10px;
}
.sg-confirm-body {
  font-size: .9rem;
  color: #4a5568;
  margin: 0 0 22px;
}
.sg-confirm-buttons {
  display: flex;
  gap: 10px;
  justify-content: flex-end;
}
.sg-confirm-cancel {
  background: #edf2f7;
  border: 1px solid #cbd5e0;
  border-radius: 7px;
  padding: 8px 18px;
  font-size: .88rem;
  cursor: pointer;
  color: #2d3748;
}
.sg-confirm-cancel:hover { background: #e2e8f0; }
.sg-confirm-ok {
  background: #e53e3e;
  border: 1px solid #c53030;
  border-radius: 7px;
  padding: 8px 18px;
  font-size: .88rem;
  font-weight: 700;
  cursor: pointer;
  color: #fff;
}
.sg-confirm-ok:hover { background: #c53030; }

/* ---- Dark mode ---- */
html[data-theme="dark"] .sg-mine-toolbar label { color: #a0aec0; }
html[data-theme="dark"] .sg-mine-filter {
  background: #2d3748;
  border-color: #4a5568;
  color: #e2e8f0;
}
html[data-theme="dark"] .sg-mine-item {
  background: #2d3748;
  border-color: #4a5568;
}
html[data-theme="dark"] .sg-mine-item:hover { box-shadow: 0 3px 12px rgba(0,0,0,.35); }
html[data-theme="dark"] .sg-mine-thumb { background: #1a202c; }
html[data-theme="dark"] .sg-mine-name { color: #e2e8f0; }
html[data-theme="dark"] .sg-mine-meta { color: #a0aec0; }
html[data-theme="dark"] .sg-mine-rejection {
  background: rgba(229,62,62,.12);
  border-left-color: #fc8181;
  color: #fc8181;
}
html[data-theme="dark"] .sg-mine-delete-btn {
  background: rgba(229,62,62,.15);
  color: #fc8181;
  border-color: #c53030;
}
html[data-theme="dark"] .sg-mine-delete-btn:hover {
  background: #c53030;
  color: #fff;
}
html[data-theme="dark"] .sg-status-pending {
  background: rgba(246,224,94,.12);
  color: #f6e05e;
  border-color: #744210;
}
html[data-theme="dark"] .sg-status-approved {
  background: rgba(72,187,120,.12);
  color: #68d391;
  border-color: #276749;
}
html[data-theme="dark"] .sg-status-rejected {
  background: rgba(229,62,62,.12);
  color: #fc8181;
  border-color: #822727;
}
html[data-theme="dark"] .sg-mine-pg-btn {
  background: #2d3748;
  border-color: #4a5568;
  color: #e2e8f0;
}
html[data-theme="dark"] .sg-mine-pg-btn:not(:disabled):hover { background: #4a5568; }
html[data-theme="dark"] .sg-mine-pg-info { color: #a0aec0; }
html[data-theme="dark"] .sg-confirm-box {
  background: #2d3748;
  box-shadow: 0 8px 32px rgba(0,0,0,.55);
}
html[data-theme="dark"] .sg-confirm-title { color: #e2e8f0; }
html[data-theme="dark"] .sg-confirm-body { color: #a0aec0; }
html[data-theme="dark"] .sg-confirm-cancel {
  background: #4a5568;
  border-color: #718096;
  color: #e2e8f0;
}
html[data-theme="dark"] .sg-confirm-cancel:hover { background: #718096; }
</style>

<!-- Inline confirm modal (no native confirm() per project rules) -->
<div class="sg-confirm-backdrop" id="sg-confirm-backdrop" role="dialog" aria-modal="true" aria-labelledby="sg-confirm-title-text">
  <div class="sg-confirm-box">
    <div class="sg-confirm-title" id="sg-confirm-title-text"></div>
    <div class="sg-confirm-body" id="sg-confirm-body-text"></div>
    <div class="sg-confirm-buttons">
      <button type="button" class="sg-confirm-cancel" id="sg-confirm-cancel">Cancel</button>
      <button type="button" class="sg-confirm-ok" id="sg-confirm-ok">Delete</button>
    </div>
  </div>
</div>

<div class="sg-wrap">
  <nav class="sg-tabs">
    <a class="sg-tab" href="<?= UIR ?>ScrollGraphics"><i class="fas fa-images"></i> Library</a>
    <a class="sg-tab" href="<?= UIR ?>ScrollGraphics/upload"><i class="fas fa-upload"></i> Submit a Graphic</a>
    <a class="sg-tab active" href="<?= UIR ?>ScrollGraphics/mine"><i class="fas fa-folder"></i> My Submissions</a>
    <?php if (!empty($sg['canModerate'])): ?>
      <a class="sg-tab" href="<?= UIR ?>ScrollGraphics/moderate"><i class="fas fa-gavel"></i> Moderate</a>
    <?php endif; ?>
  </nav>

  <div class="sg-body" style="flex-direction:column; padding: 20px;">
    <div class="sg-mine-wrap">
      <div class="sg-mine-toolbar">
        <label for="sg-mine-status-filter">Filter by status:</label>
        <select class="sg-mine-filter" id="sg-mine-status-filter">
          <option value="">All statuses</option>
          <option value="pending">Pending</option>
          <option value="approved">Approved</option>
          <option value="rejected">Rejected</option>
        </select>
      </div>

      <div class="sg-mine-list" id="sg-mine-list">
        <div class="sg-empty"><i class="fas fa-spinner fa-spin"></i> Loading&hellip;</div>
      </div>

      <div class="sg-mine-pagination" id="sg-mine-pagination">
        <button type="button" class="sg-mine-pg-btn" id="sg-mine-pg-prev">
          <i class="fas fa-chevron-left"></i> Prev
        </button>
        <span class="sg-mine-pg-info" id="sg-mine-pg-info">Page 1 of 1</span>
        <button type="button" class="sg-mine-pg-btn" id="sg-mine-pg-next">
          Next <i class="fas fa-chevron-right"></i>
        </button>
      </div>
    </div>
  </div>
</div>

<script>
var SG = <?= json_encode($sg, JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS) ?>;
(function () {
  'use strict';

  var AJAX = SG.uir + 'ScrollArtworkAjax/';
  var sgMinePage = 1;

  // ---- helpers ----
  function sgEscapeHtml(s) {
    if (!s) return '';
    var d = document.createElement('div');
    d.textContent = String(s);
    return d.innerHTML;
  }

  function el(id) { return document.getElementById(id); }

  // ---- inline confirm modal (no native confirm() per project rules) ----
  var _confirmCallback = null;

  function sgConfirm(opts) {
    var backdrop = el('sg-confirm-backdrop');
    var titleEl  = el('sg-confirm-title-text');
    var bodyEl   = el('sg-confirm-body-text');
    var okBtn    = el('sg-confirm-ok');
    if (!backdrop) return;

    if (titleEl) titleEl.textContent = opts.title || 'Confirm';
    if (bodyEl)  bodyEl.textContent  = opts.body  || '';
    if (okBtn)   okBtn.textContent   = opts.confirmLabel || 'Confirm';
    _confirmCallback = opts.onConfirm || null;
    backdrop.classList.add('active');
  }

  function sgConfirmClose() {
    var backdrop = el('sg-confirm-backdrop');
    if (backdrop) backdrop.classList.remove('active');
    _confirmCallback = null;
  }

  // ---- toast ----
  function sgToast(msg, type) {
    var t = document.createElement('div');
    t.textContent = msg;
    t.style.cssText = 'position:fixed;bottom:24px;right:24px;z-index:9999;' +
      'padding:10px 18px;border-radius:8px;font-size:.88rem;font-weight:600;' +
      'box-shadow:0 4px 14px rgba(0,0,0,.25);pointer-events:none;transition:opacity .4s;' +
      'background:' + (type === 'warn' ? '#e53e3e' : '#38a169') + ';color:#fff;';
    document.body.appendChild(t);
    setTimeout(function () {
      t.style.opacity = '0';
      setTimeout(function () { document.body.removeChild(t); }, 450);
    }, 2600);
  }

  // ---- load my uploads ----
  function sgArtworkLoadMyUploads() {
    var list = el('sg-mine-list');
    if (list) list.innerHTML = '<div class="sg-empty"><i class="fas fa-spinner fa-spin"></i> Loading&hellip;</div>';
    var statusFilter = el('sg-mine-status-filter');
    var status = statusFilter ? statusFilter.value : '';
    var url = AJAX + 'my_uploads?page=' + sgMinePage;
    if (status) url += '&status=' + encodeURIComponent(status);

    fetch(url)
      .then(function (r) { return r.json(); })
      .then(function (data) { sgArtworkRenderMyUploads(data); })
      .catch(function () {
        var list = el('sg-mine-list');
        if (list) list.innerHTML = '<div class="sg-empty"><i class="fas fa-exclamation-triangle"></i> Failed to load uploads.</div>';
      });
  }

  // ---- render my uploads ----
  function sgArtworkRenderMyUploads(data) {
    var list = el('sg-mine-list');
    if (!list) return;

    var items = (data && data.Artwork) || [];

    if (items.length === 0) {
      list.innerHTML = '<div class="sg-empty"><i class="fas fa-images"></i> You have not uploaded any artwork yet.</div>';
    } else {
      var html = '';
      for (var i = 0; i < items.length; i++) {
        var item = items[i];
        var rawStatus   = (item.Status || 'pending').toLowerCase();
        var statusLabel = rawStatus.charAt(0).toUpperCase() + rawStatus.slice(1);
        var isKingdom   = (item.Visibility === 'kingdom');
        var tierLabel   = isKingdom ? 'Kingdom' : 'Global';
        var tierClass   = isKingdom ? 'sg-badge-kingdom' : 'sg-badge-global';

        html += '<div class="sg-mine-item" data-id="' + parseInt(item.ArtworkId, 10) + '">';

        // Thumbnail
        html += '<div class="sg-mine-thumb">';
        if (item.Url) {
          html += '<img src="' + sgEscapeHtml(item.Url) + '" alt="' + sgEscapeHtml(item.Name || 'Artwork') + '" loading="lazy">';
        } else {
          html += '<i class="fas fa-image" style="font-size:2rem;color:#ccc;"></i>';
        }
        html += '</div>';

        // Info column
        html += '<div class="sg-mine-info">';

        // Name row with status badge
        html += '<div class="sg-mine-name">';
        html += sgEscapeHtml(item.Name || 'Untitled');
        html += ' <span class="sg-status-' + sgEscapeHtml(rawStatus) + '">' + sgEscapeHtml(statusLabel) + '</span>';
        html += ' <span class="sg-badge ' + tierClass + '">' + sgEscapeHtml(tierLabel) + '</span>';
        html += '</div>';

        // Meta row
        html += '<div class="sg-mine-meta">';
        if (item.CategoryLabel) {
          html += '<span class="sg-mine-meta-item"><i class="fas fa-tag"></i> ' + sgEscapeHtml(item.CategoryLabel) + '</span>';
        }
        if (item.LayoutLocation) {
          html += '<span class="sg-mine-meta-item"><i class="fas fa-map-marker-alt"></i> ' + sgEscapeHtml(item.LayoutLocation) + '</span>';
        }
        if (item.Width || item.Height) {
          html += '<span class="sg-mine-meta-item"><i class="fas fa-expand-alt"></i> ' +
            sgEscapeHtml(String(item.Width || '?')) + ' &times; ' + sgEscapeHtml(String(item.Height || '?')) + 'px</span>';
        }
        html += '</div>';

        // Rejection reason
        if (rawStatus === 'rejected' && item.RejectionReason) {
          html += '<div class="sg-mine-rejection"><i class="fas fa-exclamation-circle"></i> ' +
            sgEscapeHtml(item.RejectionReason) + '</div>';
        }

        html += '</div>'; // .sg-mine-info

        // Actions column
        html += '<div class="sg-mine-actions">';
        html += '<button type="button" class="sg-mine-delete-btn" onclick="sgArtworkDelete(' +
          parseInt(item.ArtworkId, 10) + ', this)">';
        html += '<i class="fas fa-trash"></i> Withdraw</button>';
        html += '</div>';

        html += '</div>'; // .sg-mine-item
      }
      list.innerHTML = html;
    }

    // Pagination
    var pagEl   = el('sg-mine-pagination');
    var pageInfo = el('sg-mine-pg-info');
    var total    = parseInt(data && data.Total, 10)   || 0;
    var perPage  = parseInt(data && data.PerPage, 10) || 20;
    var page     = parseInt(data && data.Page, 10)    || 1;
    var totalPages = Math.max(1, Math.ceil(total / perPage));
    sgMinePage = page;

    if (pagEl) {
      if (total > perPage) {
        pagEl.classList.add('active');
        if (pageInfo) pageInfo.textContent = 'Page ' + page + ' of ' + totalPages;
        var prev = el('sg-mine-pg-prev');
        var next = el('sg-mine-pg-next');
        if (prev) prev.disabled = (page <= 1);
        if (next) next.disabled = (page >= totalPages);
      } else {
        pagEl.classList.remove('active');
      }
    }
  }

  // ---- delete (uses inline confirm, not native confirm()) ----
  window.sgArtworkDelete = function (artworkId, btnEl) {
    if (!SG.token) { sgToast('You must be logged in', 'warn'); return; }

    sgConfirm({
      title: 'Withdraw artwork?',
      body: 'This will permanently delete the artwork and cannot be undone.',
      confirmLabel: 'Delete',
      onConfirm: function () {
        if (btnEl) btnEl.disabled = true;
        var fd = new FormData();
        fd.append('artwork_id', artworkId);
        fetch(AJAX + 'delete', { method: 'POST', body: fd })
          .then(function (r) { return r.json(); })
          .then(function (data) {
            if (data.Status === 0) {
              sgToast('Artwork deleted');
              // Remove row from the list immediately
              var row = document.querySelector('.sg-mine-item[data-id="' + parseInt(artworkId, 10) + '"]');
              if (row) row.remove();
              // Reload to get accurate pagination counts
              sgArtworkLoadMyUploads();
            } else {
              sgToast(data.Message || 'Delete failed', 'warn');
              if (btnEl) btnEl.disabled = false;
            }
          })
          .catch(function () {
            sgToast('Delete failed', 'warn');
            if (btnEl) btnEl.disabled = false;
          });
      }
    });
  };

  // ---- init ----
  function init() {
    // Confirm modal buttons
    var cancelBtn = el('sg-confirm-cancel');
    var okBtn     = el('sg-confirm-ok');
    var backdrop  = el('sg-confirm-backdrop');

    if (cancelBtn) cancelBtn.addEventListener('click', sgConfirmClose);
    if (okBtn) {
      okBtn.addEventListener('click', function () {
        sgConfirmClose();
        if (typeof _confirmCallback === 'function') { _confirmCallback(); }
      });
    }
    if (backdrop) {
      backdrop.addEventListener('click', function (e) {
        if (e.target === backdrop) sgConfirmClose();
      });
    }

    // Status filter
    var statusFilter = el('sg-mine-status-filter');
    if (statusFilter) {
      statusFilter.addEventListener('change', function () {
        sgMinePage = 1;
        sgArtworkLoadMyUploads();
      });
    }

    // Pagination
    var prev = el('sg-mine-pg-prev');
    var next = el('sg-mine-pg-next');
    if (prev) prev.addEventListener('click', function () {
      if (sgMinePage > 1) { sgMinePage--; sgArtworkLoadMyUploads(); }
    });
    if (next) next.addEventListener('click', function () {
      sgMinePage++;
      sgArtworkLoadMyUploads();
    });

    sgArtworkLoadMyUploads();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
</script>
