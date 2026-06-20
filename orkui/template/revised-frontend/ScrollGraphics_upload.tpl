<?php
	// Scroll Graphic Submissions — Submit (upload) page.
	// Rendered by Controller_ScrollGraphics::upload(); $sg_config injected.
	// Keys: uir, token, kingdomId, kingdomName, isOrkAdmin, isKingdomOfficer, canModerate
	$sg = $sg_config ?? array();
?>
<link rel="stylesheet" href="<?= HTTP_TEMPLATE ?>revised-frontend/style/scroll-graphics.css?v=<?= filemtime(DIR_TEMPLATE . 'revised-frontend/style/scroll-graphics.css') ?>">
<style>
/* ---- Submit page specific styles (page-local; shared bits live in scroll-graphics.css) ---- */
.sgu-layout { display: flex; gap: 28px; align-items: flex-start; flex-wrap: wrap; }
.sgu-col { flex: 1 1 320px; min-width: 280px; }
.sgu-section-title {
	font-size: 13px; font-weight: 700; text-transform: uppercase; letter-spacing: .04em;
	color: #4a5568; margin: 0 0 10px;
	background: transparent; border: none; padding: 0; border-radius: 0; text-shadow: none;
}
.sgu-textarea {
	width: 100%; box-sizing: border-box; padding: 8px 10px; font: inherit;
	border: 1px solid #cbd5e0; border-radius: 6px; background: #fff; color: #2d3748; resize: vertical;
}
.sgu-textarea::placeholder { color: #a0aec0; }
.sgu-textarea:focus { outline: none; border-color: #5a67d8; box-shadow: 0 0 0 2px rgba(90,103,216,.18); }
.sgu-select {
	width: 100%; box-sizing: border-box; padding: 8px 10px; font: inherit;
	border: 1px solid #cbd5e0; border-radius: 6px; background: #fff; color: #2d3748; cursor: pointer;
}
.sgu-select:focus { outline: none; border-color: #5a67d8; box-shadow: 0 0 0 2px rgba(90,103,216,.18); }
.sgu-file {
	width: 100%; box-sizing: border-box; padding: 7px 8px; font: inherit;
	border: 1px solid #cbd5e0; border-radius: 6px; background: #fff; color: #2d3748;
}
.sgu-file-info { font-size: 12px; color: #718096; margin-top: 6px; }

/* ---- Wireframe diagram ---- */
.sgu-wire-wrap { display: flex; gap: 16px; align-items: flex-start; flex-wrap: wrap; }
.sgu-wire {
	position: relative; width: 232px; height: 300px; flex: 0 0 auto;
	border: 2px solid #4a5568; border-radius: 4px; background: #fdfcf7;
	box-shadow: 0 4px 14px rgba(0,0,0,.12);
}
.sgu-zone {
	position: absolute; box-sizing: border-box; cursor: pointer;
	border: 1px dashed #a0aec0; background: rgba(90,103,216,.04);
	display: flex; align-items: center; justify-content: center; text-align: center;
	font-size: 9px; line-height: 1.1; color: #4a5568; padding: 2px;
	transition: background .12s, border-color .12s;
}
.sgu-zone:hover { background: rgba(90,103,216,.16); border-color: #5a67d8; }
.sgu-zone.is-active {
	background: rgba(90,103,216,.30); border: 2px solid #5a67d8; color: #2d3748; font-weight: 700; z-index: 5;
}
/* Layout of the 8 zones inside the 232x300 box (percentages). */
.sgu-z-border_top    { top: 0;   left: 13%; right: 13%; height: 13%; }
.sgu-z-border_bottom { bottom: 0; left: 13%; right: 13%; height: 13%; }
.sgu-z-border_left   { top: 13%; bottom: 13%; left: 0; width: 13%; }
.sgu-z-border_right  { top: 13%; bottom: 13%; right: 0; width: 13%; }
.sgu-z-top_graphic   { top: 16%; left: 30%; right: 30%; height: 16%; }
.sgu-z-center_image  { top: 38%; left: 26%; right: 26%; height: 30%; }
.sgu-z-watermark     { top: 72%; left: 22%; right: 22%; height: 18%; }
.sgu-z-full_border {
	/* full-page; sits behind, click target is a thin labeled strip along top-left corner via z-index */
	top: 13%; left: 13%; width: 18%; height: 10%; border-style: solid; border-color: #cbd5e0;
}
.sgu-wire-side { flex: 1 1 200px; min-width: 200px; }
.sgu-dim-readout {
	border: 1px solid #cbd5e0; border-radius: 6px; padding: 10px 12px; background: #f7fafc;
	font-size: 13px; color: #2d3748; margin-bottom: 10px;
}
.sgu-dim-readout strong { display: block; margin-bottom: 4px; }
.sgu-dim-readout .sgu-dim-px { font-family: ui-monospace, Menlo, monospace; color: #5a67d8; font-weight: 700; }
.sgu-guide-link { font-size: 13px; }

/* ---- Tier toggle (segmented) ---- */
.sgu-seg { display: inline-flex; border: 1px solid #cbd5e0; border-radius: 8px; overflow: hidden; }
.sgu-seg-btn {
	font: inherit; font-weight: 600; padding: 8px 22px; border: none; cursor: pointer;
	background: #fff; color: #4a5568; border-right: 1px solid #cbd5e0;
}
.sgu-seg-btn:last-child { border-right: none; }
.sgu-seg-btn.is-active { background: #5a67d8; color: #fff; }
.sgu-seg-btn:disabled { opacity: .45; cursor: not-allowed; }
.sgu-tier-note { font-size: 12px; color: #718096; margin-top: 8px; }

/* ---- License box + signature ---- */
.sgu-license {
	white-space: pre-wrap; font-size: 12px; line-height: 1.5; color: #4a5568;
	border: 1px solid #e2e8f0; border-radius: 6px; background: #f7fafc;
	padding: 12px 14px; max-height: 180px; overflow-y: auto;
}
.sgu-agree-row { display: flex; align-items: center; gap: 8px; margin-top: 12px; font-size: 14px; color: #2d3748; }
.sgu-agree-row input { margin: 0; cursor: pointer; }
.sgu-req { color: #e53e3e; }

/* ---- Submit button + inline status ---- */
.sgu-submit {
	font: inherit; font-weight: 700; padding: 11px 26px; border: none; border-radius: 8px;
	background: #5a67d8; color: #fff; cursor: pointer; display: inline-flex; align-items: center; gap: 8px;
}
.sgu-submit:hover { background: #4c56c0; }
.sgu-submit:disabled { opacity: .6; cursor: not-allowed; }
.sgu-status { margin-top: 12px; font-size: 14px; min-height: 1.2em; }
.sgu-status.is-warn { color: #c05621; }
.sgu-status.is-ok { color: #2f855a; }

/* ---- Dark mode ---- */
html[data-theme="dark"] .sgu-section-title { color: #a0aec0; }
html[data-theme="dark"] .sgu-textarea,
html[data-theme="dark"] .sgu-select,
html[data-theme="dark"] .sgu-file {
	background: #2d3748; color: #e2e8f0; border-color: #4a5568;
}
html[data-theme="dark"] .sgu-textarea::placeholder { color: #718096; }
html[data-theme="dark"] .sgu-file-info { color: #718096; }
html[data-theme="dark"] .sgu-wire { background: #1a202c; border-color: #718096; }
html[data-theme="dark"] .sgu-zone { border-color: #4a5568; color: #a0aec0; background: rgba(129,140,248,.06); }
html[data-theme="dark"] .sgu-zone:hover { background: rgba(129,140,248,.2); border-color: #818cf8; }
html[data-theme="dark"] .sgu-zone.is-active { background: rgba(129,140,248,.34); border-color: #818cf8; color: #e2e8f0; }
html[data-theme="dark"] .sgu-z-full_border { border-color: #4a5568; }
html[data-theme="dark"] .sgu-dim-readout { background: #2d3748; border-color: #4a5568; color: #e2e8f0; }
html[data-theme="dark"] .sgu-dim-readout .sgu-dim-px { color: #a3bffa; }
html[data-theme="dark"] .sgu-seg { border-color: #4a5568; }
html[data-theme="dark"] .sgu-seg-btn { background: #2d3748; color: #a0aec0; border-right-color: #4a5568; }
html[data-theme="dark"] .sgu-seg-btn.is-active { background: #5a67d8; color: #fff; }
html[data-theme="dark"] .sgu-tier-note { color: #718096; }
html[data-theme="dark"] .sgu-license { background: #2d3748; border-color: #4a5568; color: #cbd5e0; }
html[data-theme="dark"] .sgu-agree-row { color: #e2e8f0; }
html[data-theme="dark"] .sgu-status.is-warn { color: #f6ad55; }
html[data-theme="dark"] .sgu-status.is-ok { color: #68d391; }
</style>

<div class="sg-wrap">
  <nav class="sg-tabs">
    <a class="sg-tab" href="<?= UIR ?>ScrollGraphics"><i class="fas fa-images"></i> Library</a>
    <a class="sg-tab active" href="<?= UIR ?>ScrollGraphics/upload"><i class="fas fa-upload"></i> Submit a Graphic</a>
    <a class="sg-tab" href="<?= UIR ?>ScrollGraphics/mine"><i class="fas fa-folder"></i> My Submissions</a>
    <?php if (!empty($sg['canModerate'])): ?>
      <a class="sg-tab" href="<?= UIR ?>ScrollGraphics/moderate"><i class="fas fa-gavel"></i> Moderate</a>
    <?php endif; ?>
  </nav>

  <div class="sgu-layout">
    <!-- LEFT: file + placement wireframe -->
    <div class="sgu-col">
      <h3 class="sgu-section-title">1 &middot; Your Image</h3>
      <div class="sg-field">
        <label for="sgu-file">Image file <span class="sgu-req">*</span></label>
        <input type="file" class="sgu-file" id="sgu-file" accept="image/png,image/jpeg,image/gif">
        <div class="sgu-file-info" id="sgu-file-info">PNG, JPEG or GIF. 2&nbsp;MB max. See the placement guide for exact target dimensions.</div>
      </div>

      <h3 class="sgu-section-title">2 &middot; Placement Zone <span class="sgu-req">*</span></h3>
      <div class="sgu-wire-wrap">
        <div class="sgu-wire" id="sgu-wire" role="group" aria-label="Scroll placement zones">
          <div class="sgu-zone sgu-z-full_border"    data-zone="full_border">Full Border</div>
          <div class="sgu-zone sgu-z-border_top"      data-zone="border_top" >Top Border</div>
          <div class="sgu-zone sgu-z-border_bottom"   data-zone="border_bottom">Bottom Border</div>
          <div class="sgu-zone sgu-z-border_left"     data-zone="border_left">Left</div>
          <div class="sgu-zone sgu-z-border_right"    data-zone="border_right">Right</div>
          <div class="sgu-zone sgu-z-top_graphic"     data-zone="top_graphic">Top Graphic</div>
          <div class="sgu-zone sgu-z-center_image"    data-zone="center_image">Center Image</div>
          <div class="sgu-zone sgu-z-watermark"       data-zone="watermark"  >Watermark</div>
        </div>
        <div class="sgu-wire-side">
          <div class="sgu-dim-readout" id="sgu-dim-readout">
            <strong>No zone selected</strong>
            <span>Click a region on the scroll to choose where this graphic will sit.</span>
          </div>
          <a class="sgu-guide-link" href="<?= UIR ?>ScrollArtworkAjax/template_guide" target="_blank" rel="noopener">
            <i class="fas fa-download"></i> Download placement guide
          </a>
        </div>
      </div>
    </div>

    <!-- RIGHT: details + tier + license + submit -->
    <div class="sgu-col">
      <h3 class="sgu-section-title">3 &middot; Details</h3>
      <div class="sg-field">
        <label for="sgu-name">Name <span class="sgu-req">*</span></label>
        <input type="text" id="sgu-name" placeholder="A descriptive name for this graphic" maxlength="150" autocomplete="off">
      </div>
      <div class="sg-field">
        <label for="sgu-desc">Description</label>
        <textarea class="sgu-textarea" id="sgu-desc" rows="2" placeholder="Brief description (optional)" maxlength="500"></textarea>
      </div>
      <div class="sg-field">
        <label for="sgu-tags">Tags <span style="font-weight:400;text-transform:none;color:#a0aec0">(comma-separated)</span></label>
        <input type="text" id="sgu-tags" placeholder="e.g. floral, celtic, border" maxlength="500" autocomplete="off">
      </div>
      <div class="sg-field">
        <label for="sgu-category">Category</label>
        <select class="sgu-select" id="sgu-category">
          <option value="">Uncategorized</option>
        </select>
      </div>

      <h3 class="sgu-section-title">4 &middot; Scope</h3>
      <div class="sg-field">
        <label>Is this design intended for Amtgard-wide use, or is it Kingdom-specific?</label>
        <div class="sgu-seg" id="sgu-tier-seg" role="group" aria-label="Submission tier">
          <button type="button" class="sgu-seg-btn is-active" id="sgu-tier-global" data-tier="global">Amtgard</button>
          <button type="button" class="sgu-seg-btn" id="sgu-tier-kingdom" data-tier="kingdom">Kingdom</button>
        </div>
        <input type="hidden" id="sgu-visibility" value="global">
        <div class="sgu-tier-note">
          Amtgard-wide is reviewed by ORK admins &middot; Kingdom-specific is reviewed by your kingdom's officers.
        </div>
      </div>

      <h3 class="sgu-section-title">5 &middot; License &amp; Signature</h3>
      <div class="sg-field">
        <div class="sgu-license">AMTGARD SCROLL ARTWORK LICENSE

By uploading artwork to the ORK Scroll Artwork Repository, you grant to Amtgard, Inc. and all Amtgard players a perpetual, worldwide, non-exclusive, royalty-free license to use, display, reproduce, and incorporate the uploaded artwork solely for the purpose of generating award scrolls through the ORK system.

You represent and warrant that:
1. You are the original creator of this artwork, or have obtained all necessary rights and permissions to grant this license.
2. The artwork does not infringe upon the intellectual property rights of any third party.
3. You understand this artwork will be made available to other Amtgard players for use in their scroll designs.

This license does not transfer ownership of the artwork. You retain all other rights to your work. Amtgard may remove artwork at any time at its discretion.

By typing your full legal name below, you acknowledge that this constitutes a legally binding digital signature indicating your agreement to these terms.</div>
      </div>
      <div class="sg-field">
        <label for="sgu-signer">Full legal name <span class="sgu-req">*</span></label>
        <input type="text" id="sgu-signer" placeholder="Type your full legal name as a digital signature" maxlength="200" autocomplete="off">
      </div>
      <div class="sgu-agree-row">
        <input type="checkbox" id="sgu-agree">
        <label for="sgu-agree">I agree to the terms above</label>
      </div>

      <div style="margin-top:18px">
        <button type="button" class="sgu-submit" id="sgu-submit-btn">
          <i class="fas fa-upload"></i> Submit for Review
        </button>
        <div class="sgu-status" id="sgu-status" role="status" aria-live="polite"></div>
      </div>
    </div>
  </div>
</div>

<script>
var SG = <?= json_encode($sg, JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS) ?>;
(function () {
  'use strict';

  var AJAX = SG.uir + 'ScrollArtworkAjax/';

  // JS copy of SLOT_DIMENSIONS (target output px per zone).
  var SLOT_DIMENSIONS = {
    full_border:   { w: 2550, h: 3300, label: 'Full Border' },
    border_left:   { w: 300,  h: 3300, label: 'Left Border' },
    border_right:  { w: 300,  h: 3300, label: 'Right Border' },
    border_top:    { w: 2550, h: 400,  label: 'Top Border' },
    border_bottom: { w: 2550, h: 400,  label: 'Bottom Border' },
    center_image:  { w: 1200, h: 1200, label: 'Center Image' },
    watermark:     { w: 2550, h: 3300, label: 'Watermark' },
    top_graphic:   { w: 800,  h: 500,  label: 'Top Graphic' }
  };

  var _zone = '';

  function el(id) { return document.getElementById(id); }

  function sgEscapeHtml(s) {
    if (s === null || s === undefined) return '';
    var d = document.createElement('div');
    d.textContent = String(s);
    return d.innerHTML;
  }

  function setStatus(msg, kind) {
    var s = el('sgu-status');
    if (!s) return;
    s.className = 'sgu-status' + (kind ? ' is-' + kind : '');
    s.textContent = msg || '';
  }

  // ---- Wireframe zone selection ----
  function selectZone(zone) {
    _zone = zone;
    var zones = document.querySelectorAll('.sgu-zone');
    for (var i = 0; i < zones.length; i++) {
      zones[i].classList.toggle('is-active', zones[i].getAttribute('data-zone') === zone);
    }
    var dim = SLOT_DIMENSIONS[zone];
    var host = el('sgu-dim-readout');
    if (host && dim) {
      host.innerHTML = '<strong>' + sgEscapeHtml(dim.label) + '</strong>' +
        '<span>Target output size: <span class="sgu-dim-px">' + dim.w + ' &times; ' + dim.h + ' px</span></span>';
    }
  }

  function initWireframe() {
    var wire = el('sgu-wire');
    if (!wire) return;
    wire.addEventListener('click', function (e) {
      var t = e.target;
      while (t && t !== wire && !t.getAttribute('data-zone')) { t = t.parentNode; }
      if (t && t.getAttribute && t.getAttribute('data-zone')) {
        selectZone(t.getAttribute('data-zone'));
      }
    });
  }

  // ---- Categories ----
  function loadCategories() {
    fetch(AJAX + 'categories')
      .then(function (r) { return r.json(); })
      .then(function (data) {
        var sel = el('sgu-category');
        if (!sel) return;
        var cats = (data && data.Categories) || [];
        for (var i = 0; i < cats.length; i++) {
          var opt = document.createElement('option');
          opt.value = cats[i].CategoryId;
          opt.textContent = cats[i].Label;
          sel.appendChild(opt);
        }
      })
      .catch(function () { /* non-fatal: select keeps just Uncategorized */ });
  }

  // ---- Tier toggle ----
  function initTier() {
    var seg = el('sgu-tier-seg');
    var kingdomBtn = el('sgu-tier-kingdom');
    var hidden = el('sgu-visibility');
    if (!seg || !hidden) return;

    // No kingdom -> disable the Kingdom option, force global.
    if (!SG.kingdomId || parseInt(SG.kingdomId, 10) === 0) {
      if (kingdomBtn) { kingdomBtn.disabled = true; }
    } else if (kingdomBtn && SG.kingdomName) {
      kingdomBtn.textContent = sgEscapeHtml(SG.kingdomName);
    }

    seg.addEventListener('click', function (e) {
      var btn = e.target.closest ? e.target.closest('.sgu-seg-btn') : null;
      if (!btn || btn.disabled) return;
      var tier = btn.getAttribute('data-tier');
      var btns = seg.querySelectorAll('.sgu-seg-btn');
      for (var i = 0; i < btns.length; i++) {
        btns[i].classList.toggle('is-active', btns[i] === btn);
      }
      hidden.value = tier;
    });
  }

  // ---- Submit (ported from sgArtworkUpload) ----
  function sgArtworkUpload() {
    var fileEl = el('sgu-file');
    var nameEl = el('sgu-name');
    var descEl = el('sgu-desc');
    var tagsEl = el('sgu-tags');
    var catEl = el('sgu-category');
    var signerEl = el('sgu-signer');
    var agreeEl = el('sgu-agree');
    var visEl = el('sgu-visibility');
    var btn = el('sgu-submit-btn');

    var file = fileEl && fileEl.files[0];
    var name = nameEl ? nameEl.value.trim() : '';
    var signer = signerEl ? signerEl.value.trim() : '';
    var agreed = agreeEl ? agreeEl.checked : false;
    var visibility = (visEl && visEl.value === 'kingdom') ? 'kingdom' : 'global';

    if (!file) { setStatus('Please select an image file.', 'warn'); return; }
    if (file.size > 2097152) { setStatus('Image must be 2 MB or smaller (' + Math.round(file.size / 1024) + ' KB selected).', 'warn'); return; }
    if (!_zone) { setStatus('Please click a placement zone on the scroll diagram.', 'warn'); return; }
    if (!name) { setStatus('Please enter a name for the graphic.', 'warn'); return; }
    if (!signer) { setStatus('Please type your full legal name.', 'warn'); return; }
    if (!agreed) { setStatus('Please agree to the license terms.', 'warn'); return; }
    if (!SG.token) { setStatus('You must be logged in to submit a graphic.', 'warn'); return; }

    if (btn) { btn.disabled = true; btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Submitting...'; }
    setStatus('', '');

    var reader = new FileReader();
    reader.onload = function () {
      var base64 = reader.result.split(',')[1] || '';
      var mimeType = file.type || 'image/png';

      var ownerKingdomId = (visibility === 'kingdom') ? (parseInt(SG.kingdomId, 10) || 0) : 0;
      var categoryId = (catEl && catEl.value) ? catEl.value : '';

      var fd = new FormData();
      fd.append('image', base64);
      fd.append('image_mime', mimeType);
      fd.append('name', name);
      fd.append('description', descEl ? descEl.value.trim() : '');
      fd.append('tags', tagsEl ? tagsEl.value.trim() : '');
      fd.append('layout_location', _zone);
      fd.append('license_signer_name', signer);
      fd.append('visibility', visibility);
      fd.append('owner_kingdom_id', String(ownerKingdomId));
      fd.append('category_id', categoryId);

      fetch(AJAX + 'upload', { method: 'POST', body: fd })
        .then(function (r) { return r.json(); })
        .then(function (data) {
          if (data.Status === 0) {
            setStatus('Submitted! Redirecting to your submissions...', 'ok');
            window.location.href = SG.uir + 'ScrollGraphics/mine';
          } else {
            setStatus(data.Message || 'Submission failed.', 'warn');
            if (btn) { btn.disabled = false; btn.innerHTML = '<i class="fas fa-upload"></i> Submit for Review'; }
          }
        })
        .catch(function (err) {
          setStatus('Submission failed: ' + (err && err.message ? err.message : 'network error'), 'warn');
          if (btn) { btn.disabled = false; btn.innerHTML = '<i class="fas fa-upload"></i> Submit for Review'; }
        });
    };
    reader.readAsDataURL(file);
  }

  function init() {
    initWireframe();
    initTier();
    loadCategories();
    var btn = el('sgu-submit-btn');
    if (btn) { btn.addEventListener('click', sgArtworkUpload); }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
</script>
