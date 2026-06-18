<?php
/* -----------------------------------------------
   Admin_awards.tpl — Award Management
   Dedicated Admin sub-page (catalog + teaching drawer)
   Pre-process template data
   ----------------------------------------------- */
$kid         = (int)($kingdom_id ?? 0);
$kingdomName = htmlspecialchars($KingdomInfo['KingdomName'] ?? $kingdom_name ?? '');
$entityLabel = htmlspecialchars(!empty($IsPrinz) ? 'Principality' : 'Kingdom');
$uir         = UIR;

$hasHeraldry = !empty($kingdom_info['Info']['KingdomInfo']['HasHeraldry']);
$heraldryUrl = $hasHeraldry
    ? ($kingdom_info['HeraldryUrl']['Url'] ?? (HTTP_KINGDOM_HERALDRY . '0000.jpg'))
    : HTTP_KINGDOM_HERALDRY . '0000.jpg';

$adminAwards  = is_array($AdminAwards ?? null) ? $AdminAwards : [];
$systemAwards = is_array($SystemAwards ?? null) ? $SystemAwards : [];
$canEdit      = !empty($CanManageKingdom);
?>
<link rel="stylesheet" href="<?= HTTP_TEMPLATE ?>revised-frontend/style/revised.css?v=<?= filemtime(DIR_TEMPLATE . 'revised-frontend/style/revised.css') ?>">

<!-- =============================================
     AW STYLES (aw- prefix)
     ============================================= -->
<style>
/* Hero */
.aw-hero {
    position: relative; border-radius: 10px; overflow: hidden;
    margin-bottom: 20px; margin-top: 3px; min-height: 120px;
    background: linear-gradient(135deg, #44337a 0%, #2d3748 60%, #1a202c 100%);
}
.aw-hero-bg {
    position: absolute; top: -10px; left: -10px; right: -10px; bottom: -10px;
    background-size: cover; background-position: center; opacity: 0.12; filter: blur(6px);
}
.aw-hero-content {
    position: relative; z-index: 1; display: flex; align-items: center;
    padding: 24px 28px; gap: 18px;
}
.aw-heraldry-frame {
    width: 56px; height: 56px; border-radius: 12px; overflow: hidden;
    border: 2px solid rgba(255,255,255,0.25); flex-shrink: 0; background: rgba(255,255,255,0.08);
}
.aw-heraldry-frame img {
    width: 100%; height: 100%; object-fit: cover; display: block;
    border: none; padding: 0; margin: 0; max-width: none;
}
.aw-hero-info { flex: 1; min-width: 0; }
.aw-hero-title {
    font-size: 22px; font-weight: 700; color: #fff; margin: 0 0 4px;
    background: transparent; border: none; padding: 0; border-radius: 0;
    text-shadow: 0 1px 3px rgba(0,0,0,0.4);
}
.aw-hero-sub { font-size: 13px; color: rgba(255,255,255,0.6); }
.aw-hero-back {
    display: inline-flex; align-items: center; gap: 6px;
    color: rgba(255,255,255,0.7); font-size: 12px; text-decoration: none;
    transition: color 0.15s;
}
.aw-hero-back:hover { color: #fff; }

/* Layout */
.aw-layout { max-width: 1100px; margin: 0 auto; }

/* Toolbar */
.aw-toolbar {
    display: flex; gap: 10px; align-items: center; flex-wrap: wrap;
    margin-bottom: 18px;
}
.aw-search-wrap { position: relative; flex: 1; min-width: 200px; }
.aw-search-wrap i {
    position: absolute; left: 11px; top: 50%; transform: translateY(-50%);
    color: #a0aec0; font-size: 13px; pointer-events: none;
}
.aw-search {
    width: 100%; padding: 9px 12px 9px 32px; border: 1px solid #cbd5e0;
    border-radius: 8px; font-size: 13px; background: #fff; box-sizing: border-box;
}
/* Segmented filter */
.aw-seg {
    display: inline-flex; border: 1px solid #cbd5e0; border-radius: 8px;
    overflow: hidden; background: #fff;
}
.aw-seg button {
    border: none; background: transparent; padding: 9px 16px; font-size: 12px;
    font-weight: 600; color: #4a5568; cursor: pointer; transition: all 0.15s;
    border-right: 1px solid #e2e8f0;
}
.aw-seg button:last-child { border-right: none; }
.aw-seg button.aw-seg-active { background: #6b46c1; color: #fff; }

/* Buttons */
.aw-btn {
    display: inline-flex; align-items: center; gap: 6px;
    padding: 9px 16px; border-radius: 8px; font-size: 12px; font-weight: 600;
    cursor: pointer; border: none; transition: all 0.15s; white-space: nowrap;
}
.aw-btn-primary { background: #6b46c1; color: #fff; }
.aw-btn-primary:hover { background: #553c9a; }
.aw-btn-danger { background: #e53e3e; color: #fff; }
.aw-btn-danger:hover { background: #c53030; }
.aw-btn-outline {
    background: transparent; color: #4a5568; border: 1.5px solid #cbd5e0;
}
.aw-btn-outline:hover { border-color: #b794f4; color: #6b46c1; }
.aw-btn-sm { padding: 6px 12px; font-size: 11px; }

/* Catalog groups */
.aw-group { margin-bottom: 12px; border: 1px solid #e2e8f0; border-radius: 10px; overflow: hidden; background: #fff; }
.aw-group-hdr {
    display: flex; align-items: flex-start; gap: 12px; padding: 14px 18px;
    cursor: pointer; background: #f7fafc; user-select: none; transition: background 0.15s;
}
.aw-group-hdr:hover { background: #edf2f7; }
.aw-group-chev { color: #a0aec0; font-size: 13px; margin-top: 3px; transition: transform 0.18s; flex-shrink: 0; }
.aw-group.aw-collapsed .aw-group-chev { transform: rotate(-90deg); }
.aw-group-meta { flex: 1; min-width: 0; }
.aw-group-name {
    font-size: 14px; font-weight: 700; color: #2d3748;
    background: transparent; border: none; padding: 0; border-radius: 0; text-shadow: none;
    display: inline; margin: 0;
}
.aw-group-count {
    display: inline-block; margin-left: 8px; font-size: 11px; font-weight: 600;
    color: #6b46c1; background: #faf5ff; border-radius: 10px; padding: 1px 8px;
}
.aw-group-blurb { font-size: 12px; color: #718096; margin-top: 3px; line-height: 1.4; }
.aw-group-body { display: block; }
.aw-group.aw-collapsed .aw-group-body { display: none; }

/* Award rows */
.aw-row {
    display: flex; align-items: center; gap: 10px; padding: 11px 18px;
    border-top: 1px solid #edf2f7; cursor: pointer; transition: background 0.12s;
}
.aw-row:hover { background: #faf5ff; }
.aw-row-name { font-size: 13px; font-weight: 600; color: #2d3748; flex: 1; min-width: 0; }
.aw-row.aw-row-disabled .aw-row-name { color: #a0aec0; text-decoration: line-through; }
.aw-badge {
    display: inline-block; font-size: 10px; font-weight: 700; text-transform: uppercase;
    letter-spacing: 0.03em; padding: 2px 7px; border-radius: 8px;
}
.aw-badge-title { background: #fefcbf; color: #975a16; }
.aw-badge-ladder { background: #c6f6d5; color: #276749; }
.aw-badge-disabled { background: #fed7d7; color: #c53030; }
.aw-row-chev { color: #cbd5e0; font-size: 12px; }
.aw-group-empty { padding: 16px 18px; font-size: 12px; color: #a0aec0; border-top: 1px solid #edf2f7; }

/* Catalog empty */
.aw-empty { padding: 40px; text-align: center; color: #a0aec0; font-size: 14px; }

/* Drawer (slide-over) */
.aw-scrim {
    display: none; position: fixed; inset: 0; z-index: 2900;
    background: rgba(0,0,0,0.4); opacity: 0; transition: opacity 0.2s;
}
.aw-scrim.aw-open { display: block; opacity: 1; }
.aw-drawer {
    position: fixed; top: 48px; right: 0; bottom: 0; width: 480px; max-width: 100vw;
    z-index: 3000; background: #fff; box-shadow: -8px 0 32px rgba(0,0,0,0.18);
    transform: translateX(100%); transition: transform 0.24s ease;
    display: flex; flex-direction: column;
}
.aw-drawer.aw-open { transform: translateX(0); }
.aw-drawer-header {
    padding: 18px 22px; border-bottom: 1px solid #e2e8f0;
    display: flex; align-items: flex-start; justify-content: space-between; gap: 10px;
}
.aw-drawer-title {
    font-size: 17px; font-weight: 700; color: #2d3748; margin: 0;
    background: transparent; border: none; padding: 0; border-radius: 0; text-shadow: none;
}
.aw-drawer-eyebrow { font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.05em; color: #6b46c1; margin-bottom: 4px; }
.aw-drawer-close {
    background: none; border: none; font-size: 22px; color: #a0aec0;
    cursor: pointer; padding: 2px 8px; border-radius: 4px; line-height: 1;
}
.aw-drawer-close:hover { color: #e53e3e; background: #fff5f5; }
.aw-drawer-body { padding: 18px 22px; overflow-y: auto; flex: 1; }
.aw-drawer-footer {
    padding: 14px 22px; border-top: 1px solid #e2e8f0;
    display: flex; gap: 8px; align-items: center; flex-wrap: wrap;
}
.aw-drawer-footer .aw-footer-spacer { flex: 1; }

/* "What this is" explainer */
.aw-explainer {
    background: #faf5ff; border: 1px solid #e9d8fd; border-radius: 8px;
    padding: 12px 14px; font-size: 13px; color: #553c9a; line-height: 1.5; margin-bottom: 16px;
}
.aw-explainer strong { color: #44337a; }

/* Fields */
.aw-field { margin-bottom: 14px; }
.aw-field > label {
    display: block; font-size: 12px; font-weight: 600; color: #4a5568; margin-bottom: 4px;
}
.aw-field input[type="text"], .aw-field input[type="number"], .aw-field select {
    width: 100%; padding: 9px 11px; border: 1px solid #cbd5e0; border-radius: 7px;
    font-size: 13px; background: #fff; box-sizing: border-box;
}
.aw-field input[type="number"] { width: 110px; }
.aw-field-help { font-size: 11px; color: #a0aec0; margin-top: 4px; line-height: 1.4; }
.aw-field-grid { display: flex; gap: 14px; }
.aw-field-grid .aw-field { flex: 1; }

/* Reference-only badge */
.aw-ref-badge {
    display: inline-flex; align-items: center; gap: 5px; font-size: 10px; font-weight: 700;
    text-transform: uppercase; letter-spacing: 0.03em; color: #b7791f; background: #fefcbf;
    border-radius: 8px; padding: 2px 8px; margin-left: 6px; vertical-align: middle;
}

/* Toggle row */
.aw-toggle-row {
    display: flex; align-items: center; gap: 10px; padding: 10px 0;
    border-top: 1px solid #edf2f7; border-bottom: 1px solid #edf2f7; margin: 16px 0;
}
.aw-toggle-row label { font-size: 13px; font-weight: 600; color: #2d3748; margin: 0; cursor: pointer; }
.aw-toggle-row input[type="checkbox"] { width: 16px; height: 16px; cursor: pointer; }

/* Precedence pointer */
.aw-pointer {
    font-size: 12px; color: #718096; background: #f7fafc; border-radius: 7px;
    padding: 10px 12px; line-height: 1.5; margin-bottom: 16px;
}
.aw-pointer strong { color: #4a5568; }

/* Did-you-know callout */
.aw-dyk {
    display: flex; gap: 10px; align-items: flex-start;
    background: #ebf8ff; border: 1px solid #bee3f8; border-radius: 8px;
    padding: 12px 14px; font-size: 12px; color: #2c5282; line-height: 1.5;
}
.aw-dyk-icon { font-size: 16px; flex-shrink: 0; }

/* Add-flow segmented help */
.aw-add-help {
    font-size: 12px; color: #718096; background: #f7fafc; border-radius: 7px;
    padding: 9px 12px; margin-bottom: 14px; line-height: 1.4;
}

/* Alias picker (ported pattern) */
.aw-alias-wrap { position: relative; }
.aw-alias-trigger {
    width: 100%; text-align: left; display: flex; align-items: center; justify-content: space-between;
    padding: 9px 11px; border: 1px solid #cbd5e0; border-radius: 7px; background: #fff;
    font-size: 13px; color: #2d3748; cursor: pointer;
}
.aw-alias-trigger .aw-alias-label-text { color: #a0aec0; }
.aw-alias-trigger.aw-has-val .aw-alias-label-text { color: #2d3748; font-weight: 600; }
.aw-alias-dropdown {
    position: absolute; left: 0; right: 0; top: calc(100% + 4px); z-index: 50;
    background: #fff; border: 1px solid #cbd5e0; border-radius: 8px;
    box-shadow: 0 6px 20px rgba(0,0,0,0.12); overflow: hidden;
}
.aw-alias-search {
    width: 100%; padding: 9px 11px; border: none; border-bottom: 1px solid #e2e8f0;
    font-size: 13px; box-sizing: border-box; outline: none;
}
.aw-alias-list { max-height: 220px; overflow-y: auto; }
.aw-alias-item { padding: 8px 11px; font-size: 13px; color: #2d3748; cursor: pointer; }
.aw-alias-item:hover { background: #faf5ff; }
.aw-alias-empty { padding: 10px 11px; font-size: 12px; color: #a0aec0; }

/* In-product confirm dialog */
.aw-confirm {
    position: fixed; top: 50%; left: 50%; transform: translate(-50%, -50%);
    z-index: 3600; background: #fff; border-radius: 12px; width: 400px; max-width: 92vw;
    box-shadow: 0 20px 60px rgba(0,0,0,0.3); padding: 22px 24px;
}
.aw-confirm-title {
    font-size: 16px; font-weight: 700; color: #2d3748; margin: 0 0 10px;
    background: transparent; border: none; padding: 0; border-radius: 0; text-shadow: none;
}
.aw-confirm-body { font-size: 13px; color: #4a5568; line-height: 1.5; margin: 0 0 18px; }
.aw-confirm-actions { display: flex; gap: 8px; justify-content: flex-end; }
html[data-theme="dark"] .aw-confirm { background: #2d3748; }
html[data-theme="dark"] .aw-confirm-title { color: #e2e8f0; }
html[data-theme="dark"] .aw-confirm-body { color: #cbd5e0; }

/* Feedback toast */
.aw-toast {
    position: fixed; bottom: 20px; right: 20px; z-index: 4000;
    padding: 11px 18px; border-radius: 8px; font-size: 13px; font-weight: 600;
    color: #fff; box-shadow: 0 4px 16px rgba(0,0,0,0.2);
    transform: translateY(80px); opacity: 0; transition: all 0.3s; pointer-events: none;
}
.aw-toast.aw-toast-show { transform: translateY(0); opacity: 1; }
.aw-toast-success { background: #38a169; }
.aw-toast-error { background: #e53e3e; }

/* data-tip CSS tooltips (no native title) */
.aw-tip { position: relative; }
.aw-tip[data-tip]:hover::after {
    content: attr(data-tip); position: absolute; bottom: calc(100% + 6px); left: 0;
    background: #2d3748; color: #fff; font-size: 11px; font-weight: 500;
    padding: 6px 9px; border-radius: 6px; z-index: 5000;
    white-space: normal; width: max-content; max-width: 240px; line-height: 1.4;
    box-shadow: 0 4px 12px rgba(0,0,0,0.2);
}

/* DARK MODE */
html[data-theme="dark"] .aw-search,
html[data-theme="dark"] .aw-seg,
html[data-theme="dark"] .aw-group,
html[data-theme="dark"] .aw-drawer,
html[data-theme="dark"] .aw-alias-trigger,
html[data-theme="dark"] .aw-alias-dropdown,
html[data-theme="dark"] .aw-field input,
html[data-theme="dark"] .aw-field select { background: #2d3748; color: #e2e8f0; border-color: #4a5568; }
html[data-theme="dark"] .aw-group-hdr { background: #252d3a; }
html[data-theme="dark"] .aw-group-hdr:hover { background: #2d3748; }
html[data-theme="dark"] .aw-group-name,
html[data-theme="dark"] .aw-row-name,
html[data-theme="dark"] .aw-drawer-title,
html[data-theme="dark"] .aw-toggle-row label,
html[data-theme="dark"] .aw-alias-trigger,
html[data-theme="dark"] .aw-alias-item { color: #e2e8f0; }
html[data-theme="dark"] .aw-row { border-color: #3a4554; }
html[data-theme="dark"] .aw-row:hover,
html[data-theme="dark"] .aw-alias-item:hover { background: #353f50; }
html[data-theme="dark"] .aw-seg button { color: #cbd5e0; border-color: #4a5568; }
html[data-theme="dark"] .aw-btn-outline { color: #cbd5e0; border-color: #4a5568; }
html[data-theme="dark"] .aw-explainer { background: #322659; border-color: #553c9a; color: #d6bcfa; }
html[data-theme="dark"] .aw-explainer strong { color: #e9d8fd; }
html[data-theme="dark"] .aw-pointer,
html[data-theme="dark"] .aw-add-help { background: #252d3a; color: #a0aec0; }
html[data-theme="dark"] .aw-pointer strong { color: #cbd5e0; }
html[data-theme="dark"] .aw-dyk { background: #1c3a52; border-color: #2c5282; color: #bee3f8; }
html[data-theme="dark"] .aw-field > label,
html[data-theme="dark"] .aw-field-help { color: #a0aec0; }
html[data-theme="dark"] .aw-toggle-row { border-color: #3a4554; }
html[data-theme="dark"] .aw-alias-search { background: #2d3748; color: #e2e8f0; border-color: #4a5568; }
</style>

<!-- =============================================
     HERO
     ============================================= -->
<div class="aw-hero">
    <div class="aw-hero-bg" style="background-image: url('<?= htmlspecialchars($heraldryUrl) ?>')"></div>
    <div class="aw-hero-content">
        <div class="aw-heraldry-frame">
            <img src="<?= htmlspecialchars($heraldryUrl) ?>" alt="<?= $kingdomName ?>">
        </div>
        <div class="aw-hero-info">
            <a href="<?= $uir ?>Admin/kingdom/<?= $kid ?>" class="aw-hero-back"><i class="fas fa-arrow-left"></i> Back to <?= $entityLabel ?> Admin</a>
            <h1 class="aw-hero-title">Award Management</h1>
            <div class="aw-hero-sub"><?= $kingdomName ?> &mdash; <?= $entityLabel ?></div>
        </div>
    </div>
</div>

<div class="aw-layout">

    <!-- Toolbar -->
    <div class="aw-toolbar">
        <div class="aw-search-wrap">
            <i class="fas fa-search"></i>
            <input type="text" class="aw-search" id="aw-search" placeholder="Search awards by name&hellip;" autocomplete="off">
        </div>
        <div class="aw-seg" id="aw-status-seg">
            <button data-status="active" class="aw-seg-active">Active</button>
            <button data-status="disabled">Disabled</button>
            <button data-status="all">All</button>
        </div>
        <?php if ($canEdit): ?>
        <button class="aw-btn aw-btn-primary" id="aw-add-btn"><i class="fas fa-plus"></i> Add Award</button>
        <?php endif; ?>
    </div>

    <!-- Catalog (built by JS) -->
    <div id="aw-catalog"></div>

</div><!-- /.aw-layout -->

<!-- =============================================
     DRAWER SCRIM + DRAWER
     ============================================= -->
<div class="aw-scrim" id="aw-scrim"></div>

<!-- EDIT / TEACHING DRAWER -->
<div class="aw-drawer" id="aw-edit-drawer" role="dialog" aria-label="Award details">
    <div class="aw-drawer-header">
        <div>
            <div class="aw-drawer-eyebrow" id="aw-edit-eyebrow">Award</div>
            <h2 class="aw-drawer-title" id="aw-edit-title">Award</h2>
        </div>
        <button class="aw-drawer-close" data-close-drawer="aw-edit-drawer">&times;</button>
    </div>
    <div class="aw-drawer-body">
        <div class="aw-explainer" id="aw-edit-explainer"></div>

        <input type="hidden" id="aw-edit-kaid">
        <input type="hidden" id="aw-edit-tclass"><!-- passthrough; precedence moved out -->

        <div class="aw-field">
            <label>Display name</label>
            <input type="text" id="aw-edit-name" autocomplete="off">
            <div class="aw-field-help">Rename for your <?= strtolower($entityLabel) ?>; the underlying system award stays linked.</div>
        </div>

        <div class="aw-field-grid">
            <div class="aw-field">
                <label>Per reign <span class="aw-ref-badge aw-tip" data-tip="The system does not block awards based on this number. It is shown for reference only.">Reference only</span></label>
                <input type="number" id="aw-edit-reign" min="0" value="0">
            </div>
            <div class="aw-field">
                <label>Per month <span class="aw-ref-badge aw-tip" data-tip="The system does not block awards based on this number. It is shown for reference only.">Reference only</span></label>
                <input type="number" id="aw-edit-month" min="0" value="0">
            </div>
        </div>
        <div class="aw-field-help" style="margin-top:-6px;margin-bottom:14px">These limits are <strong>not enforced</strong> &mdash; the system will not prevent granting beyond them.</div>

        <div class="aw-toggle-row">
            <input type="checkbox" id="aw-edit-istitle">
            <label for="aw-edit-istitle">Confers a title?</label>
        </div>

        <div class="aw-pointer">
            Where this ranks among titles is set in <strong>Order of Precedence</strong> (coming soon).
        </div>

        <div class="aw-dyk">
            <span class="aw-dyk-icon">&#128161;</span>
            <div><strong>Did you know?</strong> To change who can <em>grant</em> this award, go to Officers &rarr; Permissions. Ladder rungs &amp; the Master capstone are configured by the system.</div>
        </div>
    </div>
    <?php if ($canEdit): ?>
    <div class="aw-drawer-footer">
        <button class="aw-btn aw-btn-primary" id="aw-edit-save"><i class="fas fa-save"></i> Save</button>
        <button class="aw-btn aw-btn-outline" id="aw-edit-toggle-status"></button>
        <div class="aw-footer-spacer"></div>
        <button class="aw-btn aw-btn-danger aw-btn-sm" id="aw-edit-delete"><i class="fas fa-trash"></i> Delete</button>
    </div>
    <?php endif; ?>
</div>

<!-- ADD DRAWER -->
<div class="aw-drawer" id="aw-add-drawer" role="dialog" aria-label="Add award">
    <div class="aw-drawer-header">
        <div>
            <div class="aw-drawer-eyebrow">New</div>
            <h2 class="aw-drawer-title">Add Award</h2>
        </div>
        <button class="aw-drawer-close" data-close-drawer="aw-add-drawer">&times;</button>
    </div>
    <div class="aw-drawer-body">
        <div class="aw-seg" id="aw-add-seg" style="display:flex;margin-bottom:14px">
            <button data-mode="alias" class="aw-seg-active" style="flex:1">Award Alias</button>
            <button data-mode="custom" style="flex:1">Kingdom-Specific</button>
        </div>

        <div class="aw-add-help" id="aw-add-help-alias">Search existing awards/titles to add a <?= strtolower($entityLabel) ?> variation.</div>
        <div class="aw-add-help" id="aw-add-help-custom" style="display:none">Create an award given only in your <?= strtolower($entityLabel) ?>.</div>

        <input type="hidden" id="aw-add-awardid" value="0">

        <!-- Alias picker (hidden in custom mode) -->
        <div class="aw-field" id="aw-add-picker-field">
            <label>System award</label>
            <div class="aw-alias-wrap">
                <button type="button" class="aw-alias-trigger" id="aw-add-alias-trigger">
                    <span class="aw-alias-label-text" id="aw-add-alias-label">Select a system award&hellip;</span>
                    <i class="fas fa-chevron-down" style="font-size:11px;opacity:.5"></i>
                </button>
                <div class="aw-alias-dropdown" id="aw-add-alias-dropdown" style="display:none">
                    <input type="text" class="aw-alias-search" id="aw-add-alias-search" placeholder="Search awards&hellip;" autocomplete="off">
                    <div class="aw-alias-list" id="aw-add-alias-list"></div>
                </div>
            </div>
        </div>

        <div class="aw-field">
            <label>Name</label>
            <input type="text" id="aw-add-name" autocomplete="off" placeholder="e.g. Order of the Warrior">
        </div>

        <div class="aw-field-grid">
            <div class="aw-field">
                <label>Per reign <span class="aw-ref-badge aw-tip" data-tip="The system does not block awards based on this number. It is shown for reference only.">Reference only</span></label>
                <input type="number" id="aw-add-reign" min="0" value="0">
            </div>
            <div class="aw-field">
                <label>Per month <span class="aw-ref-badge aw-tip" data-tip="The system does not block awards based on this number. It is shown for reference only.">Reference only</span></label>
                <input type="number" id="aw-add-month" min="0" value="0">
            </div>
        </div>

        <div class="aw-toggle-row">
            <input type="checkbox" id="aw-add-istitle">
            <label for="aw-add-istitle">Confers a title?</label>
        </div>
    </div>
    <div class="aw-drawer-footer">
        <button class="aw-btn aw-btn-primary" id="aw-add-save"><i class="fas fa-plus"></i> Add Award</button>
        <button class="aw-btn aw-btn-outline" data-close-drawer="aw-add-drawer">Cancel</button>
    </div>
</div>

<!-- In-product confirm dialog (no native confirm/alert) -->
<div class="aw-scrim" id="aw-confirm-scrim" style="z-index:3500"></div>
<div class="aw-confirm" id="aw-confirm" role="dialog" aria-label="Confirm" style="display:none">
    <h3 class="aw-confirm-title" id="aw-confirm-title">Confirm</h3>
    <p class="aw-confirm-body" id="aw-confirm-body"></p>
    <div class="aw-confirm-actions">
        <button class="aw-btn aw-btn-outline" id="aw-confirm-cancel">Cancel</button>
        <button class="aw-btn aw-btn-danger" id="aw-confirm-ok">Confirm</button>
    </div>
</div>

<!-- Toast -->
<div class="aw-toast" id="aw-toast"></div>

<!-- =============================================
     DATA CONTRACT
     ============================================= -->
<script>
var AwConfig = {
  kid: <?= (int)($kingdom_id ?? 0) ?>,
  uir: '<?= UIR ?>',
  awards: <?= json_encode($AdminAwards ?? [], JSON_HEX_TAG | JSON_HEX_AMP) ?>,
  systemAwards: <?= json_encode($SystemAwards ?? [], JSON_HEX_TAG | JSON_HEX_AMP) ?>,
  canEdit: <?= !empty($CanManageKingdom) ? 'true' : 'false' ?>
};
</script>

<!-- =============================================
     JAVASCRIPT
     ============================================= -->
<script>
(function() {
    // IIFE guard MUST use a config flag (not getElementById). This is a manager-only admin sub-page.
    if (!AwConfig.canEdit) return;
    var BASE_URL = AwConfig.uir + 'KingdomAjax/kingdom/' + AwConfig.kid + '/';

    /* ---- Toast ---- */
    var toastTimer = null;
    function awToast(msg, isErr) {
        var el = document.getElementById('aw-toast');
        if (!el) return;
        el.textContent = msg;
        el.className = 'aw-toast aw-toast-' + (isErr ? 'error' : 'success') + ' aw-toast-show';
        clearTimeout(toastTimer);
        toastTimer = setTimeout(function() { el.classList.remove('aw-toast-show'); }, 3000);
    }

    /* ---- In-product confirm (no native confirm/alert).
            Use a global tnConfirm if the app provides one; otherwise this page's own dialog. ---- */
    function tnConfirm(opts) {
        if (typeof window.tnConfirm === 'function' && window.tnConfirm !== tnConfirm) {
            return window.tnConfirm(opts);
        }
        var scrim = document.getElementById('aw-confirm-scrim');
        var box = document.getElementById('aw-confirm');
        var okBtn = document.getElementById('aw-confirm-ok');
        var cancelBtn = document.getElementById('aw-confirm-cancel');
        document.getElementById('aw-confirm-title').textContent = opts.title || 'Confirm';
        document.getElementById('aw-confirm-body').textContent = opts.body || '';
        okBtn.textContent = opts.confirmLabel || 'Confirm';
        okBtn.className = 'aw-btn ' + (opts.danger ? 'aw-btn-danger' : 'aw-btn-primary');
        function close() {
            scrim.classList.remove('aw-open');
            box.style.display = 'none';
            okBtn.onclick = null; cancelBtn.onclick = null; scrim.onclick = null;
        }
        okBtn.onclick = function() { close(); if (opts.onConfirm) opts.onConfirm(); };
        cancelBtn.onclick = close;
        scrim.onclick = close;
        scrim.classList.add('aw-open');
        box.style.display = 'block';
    }

    /* ---- POST helper (mirrors kaPost contract: r.status===0 ok) ---- */
    function awPost(action, data, onOk) {
        var fd = new FormData();
        Object.keys(data).forEach(function(k) { fd.append(k, data[k]); });
        return fetch(BASE_URL + action, { method: 'POST', body: fd })
            .then(function(r) { return r.json(); })
            .then(function(r) {
                if (r.status === 0) { onOk(r); }
                else { awToast(r.error || 'An error occurred.', true); }
            })
            .catch(function() { awToast('Request failed. Please try again.', true); });
    }

    /* ---- Award classifier (ported from Admin_kingdom.tpl classifyAward) ---- */
    function classifyAward(aw) {
        var sysName = aw.AwardName || aw.KingdomAwardName || '';
        if (aw.AwardId === 0) return 'Kingdom-Specific';
        if (sysName === 'Custom Award') return 'Kingdom-Specific';
        if (aw.IsLadder) return 'Ladder Awards (Orders)';
        if (sysName === 'Defender' || sysName === 'Master') return 'Noble Titles';
        if (sysName === 'Weaponmaster') return 'Offices & Other';
        // Peerage may be absent from the contract — fall back to name "Knight of ..."
        if (aw.Peerage === 'Knight' || /^knight of\b/i.test(sysName)) return 'Knighthoods';
        if (aw.Peerage === 'Paragon') return 'Paragons';
        if (aw.Peerage === 'Master' || (aw.IsTitle && aw.TitleClass === 10)) return 'Masterhoods';
        if (['Squire', 'Man-At-Arms', 'Page', 'Lords-Page'].indexOf(aw.Peerage) >= 0 || sysName === 'Apprentice') return 'Associate Titles';
        if ((aw.IsTitle && aw.TitleClass >= 30) || sysName === 'Esquire') return 'Noble Titles';
        return 'Offices & Other';
    }

    var GROUP_ORDER = [
        'Ladder Awards (Orders)', 'Knighthoods', 'Masterhoods', 'Paragons',
        'Noble Titles', 'Associate Titles', 'Kingdom-Specific', 'Offices & Other'
    ];
    var GROUP_BLURB = {
        'Ladder Awards (Orders)': 'rank-based; climb rungs toward a Master',
        'Knighthoods': 'the knightly peerages',
        'Masterhoods': 'master-level peerages and capstones',
        'Paragons': 'the highest recognitions of skill',
        'Noble Titles': 'court / land titles',
        'Associate Titles': 'squire / page / man-at-arms paths',
        'Kingdom-Specific': 'custom to your kingdom',
        'Offices & Other': 'offices and everything else'
    };

    /* ---- Per-group "What this is" explainer text ---- */
    var ENTITY_LC = <?= json_encode(strtolower($entityLabel)) ?>;
    function explainerFor(group, aw) {
        if (group === 'Ladder Awards (Orders)' || aw.IsLadder) {
            return '<strong>Ladder award.</strong> Players climb rungs of this order over time, progressing toward a Master-level capstone. The rungs and capstone are configured by the system.';
        }
        if (group === 'Kingdom-Specific' || aw.AwardId === 0) {
            return '<strong>Kingdom-specific award.</strong> This award exists only in your ' + ENTITY_LC + ' and is not tied to a shared system award. You control its name and how it is used.';
        }
        if (group === 'Offices & Other') {
            return '<strong>Office or other recognition.</strong> Use this for offices and miscellaneous recognitions that do not fit the title or ladder structures.';
        }
        if (aw.IsTitle) {
            return '<strong>Title.</strong> Granting this award confers a title on the recipient. Where it ranks among other titles is set in Order of Precedence.';
        }
        return '<strong>Award.</strong> A ' + ENTITY_LC + ' variation of a shared system award. Renaming it here does not change the underlying linked award.';
    }

    /* ---- Build catalog ---- */
    var awards = AwConfig.awards || [];
    var awardsById = {};
    awards.forEach(function(a) { awardsById[String(a.KingdomAwardId)] = a; });

    var catalog = document.getElementById('aw-catalog');

    function badgesHtml(aw) {
        var h = '';
        if (aw.IsTitle) h += '<span class="aw-badge aw-badge-title">Title</span>';
        if (aw.IsLadder) h += '<span class="aw-badge aw-badge-ladder">Ladder</span>';
        return h;
    }

    function renderCatalog() {
        var groups = {};
        GROUP_ORDER.forEach(function(g) { groups[g] = []; });
        awards.forEach(function(aw) {
            var g = classifyAward(aw);
            if (!groups[g]) groups[g] = [];
            groups[g].push(aw);
        });

        catalog.innerHTML = '';
        var anyRendered = false;

        GROUP_ORDER.forEach(function(groupName) {
            var items = groups[groupName];
            if (!items || !items.length) return;
            anyRendered = true;

            var groupEl = document.createElement('div');
            groupEl.className = 'aw-group';
            groupEl.dataset.group = groupName;

            var hdr = document.createElement('div');
            hdr.className = 'aw-group-hdr';
            hdr.innerHTML =
                '<i class="fas fa-chevron-down aw-group-chev"></i>' +
                '<div class="aw-group-meta">' +
                    '<h3 class="aw-group-name">' + escHtml(groupName) + '</h3>' +
                    '<span class="aw-group-count" data-count></span>' +
                    '<div class="aw-group-blurb">' + escHtml(GROUP_BLURB[groupName] || '') + '</div>' +
                '</div>';
            hdr.addEventListener('click', function() { groupEl.classList.toggle('aw-collapsed'); });
            groupEl.appendChild(hdr);

            var body = document.createElement('div');
            body.className = 'aw-group-body';

            items.forEach(function(aw) {
                var disabled = (parseInt(aw.Disabled, 10) === 1) ? 1 : 0;
                var row = document.createElement('div');
                row.className = 'aw-row' + (disabled ? ' aw-row-disabled' : '');
                row.dataset.kaid = aw.KingdomAwardId;
                row.dataset.disabled = disabled;
                row.dataset.name = (aw.KingdomAwardName || '').toLowerCase();
                row.dataset.group = groupName;
                row.innerHTML =
                    '<span class="aw-row-name">' + escHtml(aw.KingdomAwardName || '') + '</span>' +
                    badgesHtml(aw) +
                    (disabled ? '<span class="aw-badge aw-badge-disabled">Disabled</span>' : '') +
                    '<i class="fas fa-chevron-right aw-row-chev"></i>';
                row.onclick = function() { openEditDrawer(aw.KingdomAwardId); };
                body.appendChild(row);
            });

            // Empty-after-filter placeholder
            var emptyEl = document.createElement('div');
            emptyEl.className = 'aw-group-empty';
            emptyEl.style.display = 'none';
            emptyEl.textContent = 'No awards match the current filter.';
            body.appendChild(emptyEl);

            groupEl.appendChild(body);
            catalog.appendChild(groupEl);
        });

        if (!anyRendered) {
            catalog.innerHTML = '<div class="aw-empty">No awards configured yet.</div>';
        }
        applyFilter();
    }

    function escHtml(s) {
        return String(s == null ? '' : s)
            .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
    }

    /* ---- Filtering (status segment + search) ---- */
    var curStatus = 'active';
    var curSearch = '';

    function rowMatches(row) {
        var d = row.dataset.disabled;
        if (curStatus === 'active' && d === '1') return false;
        if (curStatus === 'disabled' && d !== '1') return false;
        if (curSearch && row.dataset.name.indexOf(curSearch) === -1) return false;
        return true;
    }

    function applyFilter() {
        document.querySelectorAll('.aw-group').forEach(function(groupEl) {
            var shown = 0;
            groupEl.querySelectorAll('.aw-row').forEach(function(row) {
                var ok = rowMatches(row);
                row.style.display = ok ? '' : 'none';
                if (ok) shown++;
            });
            // update count to reflect active filter
            var countEl = groupEl.querySelector('[data-count]');
            if (countEl) countEl.textContent = '(' + shown + ')';
            // empty placeholder + hide group entirely if nothing matches
            var emptyEl = groupEl.querySelector('.aw-group-empty');
            if (emptyEl) emptyEl.style.display = shown === 0 ? '' : 'none';
            groupEl.style.display = shown === 0 ? 'none' : '';
        });
    }

    // Search box
    var searchInp = document.getElementById('aw-search');
    if (searchInp) {
        var searchTimer = null;
        searchInp.addEventListener('input', function() {
            var v = this.value.trim().toLowerCase();
            clearTimeout(searchTimer);
            searchTimer = setTimeout(function() { curSearch = v; applyFilter(); }, 80);
        });
    }
    // Status segment
    var statusSeg = document.getElementById('aw-status-seg');
    if (statusSeg) {
        statusSeg.addEventListener('click', function(e) {
            var btn = e.target.closest('button[data-status]');
            if (!btn) return;
            curStatus = btn.dataset.status;
            statusSeg.querySelectorAll('button').forEach(function(b) { b.classList.remove('aw-seg-active'); });
            btn.classList.add('aw-seg-active');
            applyFilter();
        });
    }

    /* ---- Drawer open/close helpers ---- */
    function openDrawer(id) {
        document.getElementById('aw-scrim').classList.add('aw-open');
        document.getElementById(id).classList.add('aw-open');
    }
    function closeDrawers() {
        document.getElementById('aw-scrim').classList.remove('aw-open');
        document.querySelectorAll('.aw-drawer').forEach(function(d) { d.classList.remove('aw-open'); });
    }
    document.getElementById('aw-scrim').addEventListener('click', closeDrawers);
    document.querySelectorAll('[data-close-drawer]').forEach(function(b) {
        b.addEventListener('click', closeDrawers);
    });
    document.addEventListener('keydown', function(e) { if (e.key === 'Escape') closeDrawers(); });

    /* ---- EDIT / TEACHING DRAWER ---- */
    var elName = document.getElementById('aw-edit-name');
    var elReign = document.getElementById('aw-edit-reign');
    var elMonth = document.getElementById('aw-edit-month');
    var elIsTitle = document.getElementById('aw-edit-istitle');
    var elTClass = document.getElementById('aw-edit-tclass');
    var elKaid = document.getElementById('aw-edit-kaid');
    var elTitle = document.getElementById('aw-edit-title');
    var elEyebrow = document.getElementById('aw-edit-eyebrow');
    var elExplainer = document.getElementById('aw-edit-explainer');
    var elToggleStatus = document.getElementById('aw-edit-toggle-status');

    function openEditDrawer(kaid) {
        var aw = awardsById[String(kaid)];
        if (!aw) return;
        var group = classifyAward(aw);
        elKaid.value = aw.KingdomAwardId;
        elTitle.textContent = aw.KingdomAwardName || 'Award';
        elEyebrow.textContent = group;
        elExplainer.innerHTML = explainerFor(group, aw);
        if (elName) elName.value = aw.KingdomAwardName || '';
        if (elReign) elReign.value = (aw.ReignLimit != null ? aw.ReignLimit : 0);
        if (elMonth) elMonth.value = (aw.MonthLimit != null ? aw.MonthLimit : 0);
        if (elIsTitle) elIsTitle.checked = (parseInt(aw.IsTitle, 10) === 1);
        if (elTClass) elTClass.value = (aw.TitleClass != null ? aw.TitleClass : 0);
        if (elToggleStatus) {
            var dis = parseInt(aw.Disabled, 10) === 1;
            elToggleStatus.innerHTML = dis
                ? '<i class="fas fa-check-circle"></i> Enable'
                : '<i class="fas fa-ban"></i> Disable';
        }
        openDrawer('aw-edit-drawer');
    }

    if (AwConfig.canEdit) {
        // Save
        var saveBtn = document.getElementById('aw-edit-save');
        if (saveBtn) saveBtn.addEventListener('click', function() {
            var kaid = parseInt(elKaid.value, 10);
            var name = elName.value.trim();
            if (!name) { awToast('Display name is required.', true); return; }
            saveBtn.disabled = true;
            awPost('setaward', {
                KingdomAwardId: kaid,
                KingdomAwardName: name,
                ReignLimit: elReign.value,
                MonthLimit: elMonth.value,
                IsTitle: elIsTitle.checked ? 1 : 0,
                TitleClass: elTClass.value
            }, function() {
                saveBtn.disabled = false;
                // update local model + row
                var aw = awardsById[String(kaid)];
                if (aw) {
                    aw.KingdomAwardName = name;
                    aw.ReignLimit = elReign.value;
                    aw.MonthLimit = elMonth.value;
                    aw.IsTitle = elIsTitle.checked ? 1 : 0;
                    // TitleClass is a hidden passthrough (not editable here), but keep the
                    // local model in sync with what was sent so classifyAward stays correct.
                    aw.TitleClass = parseInt(elTClass.value, 10) || 0;
                }
                refreshRow(kaid);
                elTitle.textContent = name;
                awToast('Award saved!');
            }).then(function() { saveBtn.disabled = false; });
        });

        // Disable / Enable toggle
        if (elToggleStatus) elToggleStatus.addEventListener('click', function() {
            var kaid = parseInt(elKaid.value, 10);
            var aw = awardsById[String(kaid)];
            if (!aw) return;
            var newDisabled = parseInt(aw.Disabled, 10) === 1 ? 0 : 1;
            elToggleStatus.disabled = true;
            awPost('setawardstatus', { KingdomAwardId: kaid, Disabled: newDisabled }, function() {
                aw.Disabled = newDisabled;
                elToggleStatus.innerHTML = newDisabled
                    ? '<i class="fas fa-check-circle"></i> Enable'
                    : '<i class="fas fa-ban"></i> Disable';
                refreshRow(kaid);
                awToast(newDisabled ? 'Award disabled.' : 'Award enabled.');
            }).then(function() { elToggleStatus.disabled = false; });
        });

        // Delete
        var delBtn = document.getElementById('aw-edit-delete');
        if (delBtn) delBtn.addEventListener('click', function() {
            var kaid = parseInt(elKaid.value, 10);
            var aw = awardsById[String(kaid)];
            var nm = aw ? aw.KingdomAwardName : 'this award';
            tnConfirm({
                title: 'Delete Award',
                body: 'Delete award "' + nm + '"? This cannot be undone.',
                confirmLabel: 'Delete',
                danger: true,
                onConfirm: function() {
                    awPost('deleteaward', { KingdomAwardId: kaid }, function() {
                        delete awardsById[String(kaid)];
                        awards = awards.filter(function(a) { return String(a.KingdomAwardId) !== String(kaid); });
                        AwConfig.awards = awards;
                        var row = document.querySelector('.aw-row[data-kaid="' + kaid + '"]');
                        if (row && row.parentNode) row.parentNode.removeChild(row);
                        applyFilter();
                        closeDrawers();
                        awToast('Award deleted.');
                    });
                }
            });
        });
    }

    /* ---- Rebuild a single row in place after edit ---- */
    function refreshRow(kaid) {
        var aw = awardsById[String(kaid)];
        var row = document.querySelector('.aw-row[data-kaid="' + kaid + '"]');
        if (!aw || !row) return;
        var disabled = parseInt(aw.Disabled, 10) === 1 ? 1 : 0;
        row.className = 'aw-row' + (disabled ? ' aw-row-disabled' : '');
        row.dataset.disabled = disabled;
        row.dataset.name = (aw.KingdomAwardName || '').toLowerCase();
        row.innerHTML =
            '<span class="aw-row-name">' + escHtml(aw.KingdomAwardName || '') + '</span>' +
            badgesHtml(aw) +
            (disabled ? '<span class="aw-badge aw-badge-disabled">Disabled</span>' : '') +
            '<i class="fas fa-chevron-right aw-row-chev"></i>';
        row.onclick = function() { openEditDrawer(kaid); };
        applyFilter();
    }

    /* ---- ADD FLOW ---- */
    if (AwConfig.canEdit) {
        var addBtn = document.getElementById('aw-add-btn');
        var addMode = 'alias';
        var addPickerField = document.getElementById('aw-add-picker-field');
        var addAwardIdInp = document.getElementById('aw-add-awardid');
        var addNameInp = document.getElementById('aw-add-name');
        var addReign = document.getElementById('aw-add-reign');
        var addMonth = document.getElementById('aw-add-month');
        var addIsTitle = document.getElementById('aw-add-istitle');
        var addAliasLabel = document.getElementById('aw-add-alias-label');
        var addAliasTrigger = document.getElementById('aw-add-alias-trigger');
        var helpAlias = document.getElementById('aw-add-help-alias');
        var helpCustom = document.getElementById('aw-add-help-custom');

        function resetAddForm() {
            addMode = 'alias';
            setAddMode('alias');
            addAwardIdInp.value = '0';
            addNameInp.value = '';
            addReign.value = '0';
            addMonth.value = '0';
            addIsTitle.checked = false;
            if (addAliasLabel) { addAliasLabel.textContent = 'Select a system award…'; }
            if (addAliasTrigger) addAliasTrigger.classList.remove('aw-has-val');
        }

        function setAddMode(mode) {
            addMode = mode;
            document.querySelectorAll('#aw-add-seg button').forEach(function(b) {
                b.classList.toggle('aw-seg-active', b.dataset.mode === mode);
            });
            if (mode === 'custom') {
                addPickerField.style.display = 'none';
                helpAlias.style.display = 'none';
                helpCustom.style.display = '';
                addAwardIdInp.value = '0';
            } else {
                addPickerField.style.display = '';
                helpAlias.style.display = '';
                helpCustom.style.display = 'none';
            }
        }

        if (addBtn) addBtn.addEventListener('click', function() {
            resetAddForm();
            openDrawer('aw-add-drawer');
        });

        var addSeg = document.getElementById('aw-add-seg');
        if (addSeg) addSeg.addEventListener('click', function(e) {
            var b = e.target.closest('button[data-mode]');
            if (b) setAddMode(b.dataset.mode);
        });

        // Alias picker dropdown (ported pattern)
        var aDropdown = document.getElementById('aw-add-alias-dropdown');
        var aSearch = document.getElementById('aw-add-alias-search');
        var aList = document.getElementById('aw-add-alias-list');
        var sysAwards = AwConfig.systemAwards || [];
        var aliasOpen = false;

        function buildAliasList(filter) {
            if (!aList) return;
            aList.innerHTML = '';
            var lc = (filter || '').toLowerCase(), count = 0;
            sysAwards.forEach(function(sa) {
                if (lc && (sa.Name || '').toLowerCase().indexOf(lc) === -1) return;
                var div = document.createElement('div');
                div.className = 'aw-alias-item';
                div.textContent = sa.Name;
                div.addEventListener('click', function() { selectAlias(sa.AwardId, sa.Name); });
                aList.appendChild(div);
                count++;
            });
            if (!count) {
                var empty = document.createElement('div');
                empty.className = 'aw-alias-empty';
                empty.textContent = 'No matching awards';
                aList.appendChild(empty);
            }
        }
        function selectAlias(id, name) {
            addAwardIdInp.value = id;
            if (addAliasLabel) addAliasLabel.textContent = name;
            if (addAliasTrigger) addAliasTrigger.classList.add('aw-has-val');
            if (addNameInp && !addNameInp.value.trim()) addNameInp.value = name;
            closeAlias();
        }
        function openAlias() {
            if (!aDropdown || aliasOpen) return;
            aliasOpen = true; aDropdown.style.display = '';
            buildAliasList('');
            if (aSearch) { aSearch.value = ''; aSearch.focus(); }
        }
        function closeAlias() { if (!aDropdown) return; aliasOpen = false; aDropdown.style.display = 'none'; }
        if (addAliasTrigger) addAliasTrigger.addEventListener('click', function(e) {
            e.preventDefault();
            aliasOpen ? closeAlias() : openAlias();
        });
        if (aSearch) {
            aSearch.addEventListener('input', function() { buildAliasList(this.value); });
            aSearch.addEventListener('keydown', function(e) { if (e.key === 'Escape') closeAlias(); });
        }
        document.addEventListener('click', function(e) {
            if (aliasOpen && addAliasTrigger && aDropdown &&
                !addAliasTrigger.contains(e.target) && !aDropdown.contains(e.target)) closeAlias();
        });

        // Save new award
        var addSave = document.getElementById('aw-add-save');
        if (addSave) addSave.addEventListener('click', function() {
            var name = addNameInp.value.trim();
            var awardId = parseInt(addAwardIdInp.value || '0', 10);
            if (addMode === 'alias' && !awardId) { awToast('Please select a system award.', true); return; }
            if (!name) { awToast('Award name is required.', true); return; }
            addSave.disabled = true;
            awPost('setaward', {
                KingdomAwardId: 0,
                AwardId: addMode === 'alias' ? awardId : 0,
                KingdomAwardName: name,
                ReignLimit: addReign.value,
                MonthLimit: addMonth.value,
                IsTitle: addIsTitle.checked ? 1 : 0,
                TitleClass: 0
            }, function() {
                awToast('Award added!');
                setTimeout(function() { location.reload(); }, 800);
            }).then(function() { addSave.disabled = false; });
        });
    }

    // Initial render. This is a manager-only page (the controller redirects non-editors),
    // so the canEdit guard above always passes here.
    renderCatalog();
})();
</script>
