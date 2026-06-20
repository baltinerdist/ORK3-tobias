<?php
	// Scroll Graphic Submissions — Library page.
	// Rendered by Controller_ScrollGraphics::index(); $sg_config injected.
	// Keys: uir, token, kingdomId, kingdomName, isOrkAdmin, isKingdomOfficer, canModerate
	$sg = $sg_config ?? array();
?>
<link rel="stylesheet" href="<?= HTTP_TEMPLATE ?>revised-frontend/style/scroll-graphics.css?v=<?= filemtime(DIR_TEMPLATE . 'revised-frontend/style/scroll-graphics.css') ?>">
<div class="sg-wrap">
  <nav class="sg-tabs">
    <a class="sg-tab active" href="<?= UIR ?>ScrollGraphics"><i class="fas fa-images"></i> Library</a>
    <a class="sg-tab" href="<?= UIR ?>ScrollGraphics/upload"><i class="fas fa-upload"></i> Submit a Graphic</a>
    <a class="sg-tab" href="<?= UIR ?>ScrollGraphics/mine"><i class="fas fa-folder"></i> My Submissions</a>
    <?php if (!empty($sg['canModerate'])): ?>
      <a class="sg-tab" href="<?= UIR ?>ScrollGraphics/moderate"><i class="fas fa-gavel"></i> Moderate</a>
    <?php endif; ?>
  </nav>
  <div class="sg-body">
    <aside class="sg-rail">
      <div class="sg-field">
        <label for="sg-search">Search</label>
        <input type="text" id="sg-search" placeholder="Name or tags" autocomplete="off">
      </div>
      <div class="sg-field">
        <label>Placement zone</label>
        <div id="sg-zone-filters"></div>
      </div>
      <div class="sg-field">
        <label>Category</label>
        <div id="sg-category-filters"><span class="sg-empty-mini">Loading&hellip;</span></div>
      </div>
      <div class="sg-field">
        <label>Tier</label>
        <label class="sg-radio"><input type="radio" name="sg-tier" value="all" checked> All</label>
        <label class="sg-radio"><input type="radio" name="sg-tier" value="global"> Amtgard</label>
        <label class="sg-radio"><input type="radio" name="sg-tier" value="kingdom"> My Kingdom</label>
      </div>
    </aside>
    <main class="sg-grid-wrap">
      <div id="sg-grid" class="sg-grid"></div>
      <div id="sg-pagination" class="sg-pagination" hidden>
        <button type="button" class="sg-pg-btn" id="sg-pg-prev"><i class="fas fa-chevron-left"></i> Prev</button>
        <span class="sg-pg-info" id="sg-pg-info">Page 1 of 1</span>
        <button type="button" class="sg-pg-btn" id="sg-pg-next">Next <i class="fas fa-chevron-right"></i></button>
      </div>
    </main>
  </div>
</div>
<script>
var SG = <?= json_encode($sg, JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS) ?>;
(function () {
  'use strict';

  var AJAX = SG.uir + 'ScrollArtworkAjax/';
  var BUILDER_URL = '<?= UIR ?>Scroll/builder';

  // The 8 placement zones (VALID_LOCATIONS), with friendly labels.
  var ZONES = [
    { value: 'full_border',    label: 'Full Border' },
    { value: 'border_left',    label: 'Left Border' },
    { value: 'border_right',   label: 'Right Border' },
    { value: 'border_top',     label: 'Top Border' },
    { value: 'border_bottom',  label: 'Bottom Border' },
    { value: 'center_image',   label: 'Center Image' },
    { value: 'watermark',      label: 'Watermark' },
    { value: 'top_graphic',    label: 'Top Graphic' }
  ];

  var PER_PAGE = 12;
  var sgPage = 1;
  var sgSearchTimer = null;

  // ---- helpers ----
  function sgEscapeHtml(s) {
    if (!s) return '';
    var d = document.createElement('div');
    d.textContent = String(s);
    return d.innerHTML;
  }

  function el(id) { return document.getElementById(id); }

  function checkedValues(container) {
    var out = [];
    if (!container) return out;
    var boxes = container.querySelectorAll('input[type="checkbox"]:checked');
    for (var i = 0; i < boxes.length; i++) { out.push(boxes[i].value); }
    return out;
  }

  function selectedTier() {
    var r = document.querySelector('input[name="sg-tier"]:checked');
    return r ? r.value : 'all';
  }

  function searchTerm() {
    var s = el('sg-search');
    return s ? s.value.trim() : '';
  }

  // ---- render the static zone checkboxes ----
  function renderZoneFilters() {
    var host = el('sg-zone-filters');
    if (!host) return;
    var html = '';
    for (var i = 0; i < ZONES.length; i++) {
      html += '<label class="sg-check"><input type="checkbox" class="sg-zone-cb" value="' +
        sgEscapeHtml(ZONES[i].value) + '"> ' + sgEscapeHtml(ZONES[i].label) + '</label>';
    }
    host.innerHTML = html;
  }

  // ---- load categories ----
  function loadCategories() {
    fetch(AJAX + 'categories')
      .then(function (r) { return r.json(); })
      .then(function (data) {
        var host = el('sg-category-filters');
        if (!host) return;
        var cats = (data && data.Categories) || [];
        if (cats.length === 0) {
          host.innerHTML = '<span class="sg-empty-mini">No categories</span>';
          return;
        }
        var html = '';
        for (var i = 0; i < cats.length; i++) {
          html += '<label class="sg-check"><input type="checkbox" class="sg-cat-cb" value="' +
            sgEscapeHtml(cats[i].CategoryId) + '"> ' + sgEscapeHtml(cats[i].Label) + '</label>';
        }
        host.innerHTML = html;
        wireFilter(host);
      })
      .catch(function () {
        var host = el('sg-category-filters');
        if (host) host.innerHTML = '<span class="sg-empty-mini">Failed to load categories</span>';
      });
  }

  // ---- build URL + load grid ----
  function sgLibLoad() {
    var grid = el('sg-grid');
    if (grid) {
      grid.innerHTML = '<div class="sg-empty"><i class="fas fa-spinner fa-spin"></i>Loading&hellip;</div>';
    }

    var zones = checkedValues(el('sg-zone-filters')).join(',');
    var cats = checkedValues(el('sg-category-filters')).join(',');
    var tier = selectedTier();
    var q = searchTerm();

    var params = [];
    params.push('layout_location=' + encodeURIComponent(zones));
    params.push('tier=' + encodeURIComponent(tier));
    params.push('category_id=' + encodeURIComponent(cats));
    params.push('page=' + sgPage);

    var url;
    if (q) {
      url = AJAX + 'search?query=' + encodeURIComponent(q) + '&' + params.join('&');
    } else {
      url = AJAX + 'browse?' + params.join('&');
    }

    fetch(url)
      .then(function (r) { return r.json(); })
      .then(function (data) { renderGrid(data); })
      .catch(function () {
        if (grid) {
          grid.innerHTML = '<div class="sg-empty"><i class="fas fa-exclamation-triangle"></i>Failed to load artwork.</div>';
        }
        renderPagination(0, 1);
      });
  }

  // ---- render grid (ported from sgArtworkRenderBrowseGrid) ----
  function renderGrid(data) {
    var grid = el('sg-grid');
    if (!grid) return;
    var items = (data && data.Artwork) || [];
    var q = searchTerm();

    if (items.length === 0) {
      grid.innerHTML = '<div class="sg-empty"><i class="fas fa-palette"></i>No artwork found' +
        (q ? ' for "' + sgEscapeHtml(q) + '"' : '') + '.</div>';
    } else {
      var html = '';
      for (var i = 0; i < items.length; i++) {
        var item = items[i];
        var isKingdom = (item.Visibility === 'kingdom');
        var badgeClass = isKingdom ? 'sg-badge-kingdom' : 'sg-badge-global';
        var badgeText = isKingdom ? 'Kingdom' : 'Global';
        var url = sgEscapeHtml(item.Url || '');
        var name = sgEscapeHtml(item.Name || 'Untitled');
        var artist = sgEscapeHtml(item.UploaderPersona || 'Unknown');
        var cat = sgEscapeHtml(item.CategoryLabel || '');

        html += '<div class="sg-card">';
        html += '<img class="sg-card-thumb" src="' + url + '" alt="' + name + '" loading="lazy">';
        html += '<div class="sg-card-body">';
        html += '<span class="sg-card-name">' + name + '</span>';
        html += '<span class="sg-card-artist">' + artist + '</span>';
        html += '<div class="sg-card-meta">';
        html += '<span class="sg-badge ' + badgeClass + '">' + badgeText + '</span>';
        if (cat) { html += '<span class="sg-card-cat">' + cat + '</span>'; }
        html += '</div>';
        html += '</div>';
        html += '<a class="sg-card-use" href="' + BUILDER_URL + '"><i class="fas fa-pen-nib"></i> Use in builder</a>';
        html += '</div>';
      }
      grid.innerHTML = html;
    }

    var total = parseInt(data && data.Total, 10) || 0;
    var perPage = parseInt(data && data.PerPage, 10) || PER_PAGE;
    var page = parseInt(data && data.Page, 10) || 1;
    sgPage = page;
    renderPagination(total, perPage);
  }

  // ---- pagination (ported) ----
  function renderPagination(total, perPage) {
    var pag = el('sg-pagination');
    var info = el('sg-pg-info');
    var prev = el('sg-pg-prev');
    var next = el('sg-pg-next');
    if (!pag) return;

    perPage = perPage || PER_PAGE;
    var totalPages = Math.max(1, Math.ceil(total / perPage));

    if (total > perPage) {
      pag.hidden = false;
      if (info) info.textContent = 'Page ' + sgPage + ' of ' + totalPages;
      if (prev) prev.disabled = (sgPage <= 1);
      if (next) next.disabled = (sgPage >= totalPages);
    } else {
      pag.hidden = true;
    }
  }

  // ---- wire filters ----
  function wireFilter(container) {
    if (!container) return;
    container.addEventListener('change', function () {
      sgPage = 1;
      sgLibLoad();
    });
  }

  function init() {
    renderZoneFilters();
    wireFilter(el('sg-zone-filters'));

    // Tier radios
    var radios = document.querySelectorAll('input[name="sg-tier"]');
    for (var i = 0; i < radios.length; i++) {
      radios[i].addEventListener('change', function () { sgPage = 1; sgLibLoad(); });
    }

    // Debounced search (300ms)
    var search = el('sg-search');
    if (search) {
      search.addEventListener('input', function () {
        if (sgSearchTimer) { clearTimeout(sgSearchTimer); }
        sgSearchTimer = setTimeout(function () { sgPage = 1; sgLibLoad(); }, 300);
      });
    }

    // Pagination buttons
    var prev = el('sg-pg-prev');
    var next = el('sg-pg-next');
    if (prev) prev.addEventListener('click', function () {
      if (sgPage > 1) { sgPage--; sgLibLoad(); }
    });
    if (next) next.addEventListener('click', function () {
      sgPage++; sgLibLoad();
    });

    loadCategories();
    sgLibLoad();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
</script>
