<?php
/* -----------------------------------------------------------------
   Inventory — officer-only per-org durable-goods register (Kingdom/Park).
   Plain-PHP template (extract()+include). All CSS/JS inlined, `inv-`
   prefixed. Dark-mode via global --ork-* vars + html[data-theme=dark].
   Mirrors Treasury_index.tpl. Variables (from controller.Inventory::render):
     $owner_type, $owner_id, $categories, $removal_reasons, $conditions,
     $org_name, $kingdom_id, $summary, $items
   ----------------------------------------------------------------- */
$uir      = UIR;
$ajaxBase = $uir . 'InventoryAjax/handle/' . $owner_type . '/' . $owner_id . '/';
$fmt      = fn($n) => '$' . number_format((float)$n, 2);
$condLabels = ['new' => 'New', 'good' => 'Good', 'fair' => 'Fair', 'poor' => 'Poor', 'needs_repair' => 'Needs Repair'];

// Defensive defaults (controller supplies these, but render must never fatal).
$summary = is_array($summary ?? null) ? $summary : [];
$summary += ['TotalValue' => 0, 'TotalUnits' => 0, 'LineItems' => 0, 'NeedsRepair' => 0, 'ByCategory' => [], 'ByCondition' => []];
$items   = is_array($items ?? null) ? $items : ['Rows' => [], 'Total' => 0];
$categories      = (array)($categories ?? []);
$removal_reasons = (array)($removal_reasons ?? []);
?>
<script src="https://code.highcharts.com/highcharts.js"></script>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/flatpickr/dist/flatpickr.min.css">
<script src="https://cdn.jsdelivr.net/npm/flatpickr"></script>
<style>
/* =====================================================
   Inventory tool — .inv-* (light defaults; dark via --ork-* + overrides)
   ===================================================== */
.inv-wrap { max-width: 1100px; margin: 0 auto; padding: 16px 16px 48px; color: var(--ork-text); }

/* Hero heading — reset the global h1-h6 gray-box */
.inv-hero { margin: 4px 0 18px; }
.inv-hero h1 {
    background: transparent; border: none; padding: 0; border-radius: 0; text-shadow: none;
    margin: 0; font-size: 1.55rem; font-weight: 700; color: var(--ork-text);
}
.inv-hero .inv-hero-sub { color: var(--ork-text-muted); font-size: 0.9rem; margin-top: 2px; }

/* Summary cards */
.inv-cards { display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; margin-bottom: 18px; }
.inv-card {
    background: var(--ork-card-bg); border: 1px solid var(--ork-border);
    border-radius: 10px; padding: 14px 16px;
}
.inv-card-lbl { font-size: 0.74rem; text-transform: uppercase; letter-spacing: .04em; color: var(--ork-text-muted); margin-bottom: 6px; }
.inv-card-val { font-size: 1.4rem; font-weight: 700; color: var(--ork-text); }
.inv-card.inv-card-repair .inv-card-val { color: #c05621; }
html[data-theme="dark"] .inv-card.inv-card-repair .inv-card-val { color: #f6ad55; }

/* Charts */
.inv-charts { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; margin-bottom: 18px; }
.inv-chart-card {
    background: var(--ork-card-bg); border: 1px solid var(--ork-border);
    border-radius: 10px; padding: 8px 12px 12px;
}
.inv-chart-card .inv-chart-title { font-size: 0.8rem; font-weight: 600; color: var(--ork-text-secondary); margin: 4px 2px 6px; }

/* Toolbar */
.inv-toolbar { display: flex; flex-wrap: wrap; gap: 8px; align-items: center; margin-bottom: 12px; }
.inv-toolbar input[type="text"], .inv-toolbar select {
    background: var(--ork-input-bg); border: 1px solid var(--ork-input-border); color: var(--ork-text);
    border-radius: 6px; padding: 6px 10px; font-size: 0.85rem;
}
.inv-toolbar input[type="text"] { width: 150px; }
.inv-toolbar .inv-spacer { flex: 1 1 auto; }

/* Buttons */
.inv-btn {
    display: inline-block; padding: 7px 14px; border-radius: 6px; border: 1px solid var(--ork-border-dark);
    background: var(--ork-bg-secondary); color: var(--ork-text); font-size: 0.85rem; font-weight: 600;
    cursor: pointer; text-decoration: none; line-height: 1.2;
}
.inv-btn:hover { background: var(--ork-bg-tertiary); }
.inv-btn.inv-btn-primary { background: #4338ca; border-color: #4338ca; color: #fff; }
.inv-btn.inv-btn-primary:hover { background: #3730a3; }
html[data-theme="dark"] .inv-btn.inv-btn-primary { background: #6366f1; border-color: #6366f1; }
html[data-theme="dark"] .inv-btn.inv-btn-primary:hover { background: #818cf8; }

/* Item table */
.inv-table { width: 100%; border-collapse: collapse; background: var(--ork-card-bg); border: 1px solid var(--ork-border); border-radius: 10px; overflow: hidden; }
.inv-table thead th {
    text-align: left; font-size: 0.72rem; text-transform: uppercase; letter-spacing: .03em;
    color: var(--ork-text-muted); background: var(--ork-bg-secondary);
    padding: 9px 12px; border-bottom: 1px solid var(--ork-border); white-space: nowrap;
}
.inv-table thead th[data-sort] { cursor: pointer; user-select: none; }
.inv-table thead th[data-sort]:hover { color: var(--ork-text); }
.inv-table thead th .inv-sort-ind { font-size: 0.7rem; opacity: .7; }
.inv-table tbody td { padding: 9px 12px; font-size: 0.86rem; color: var(--ork-text); border-bottom: 1px solid var(--ork-border); vertical-align: top; }
.inv-table tbody tr:last-child td { border-bottom: none; }
.inv-table .inv-num { text-align: right; font-variant-numeric: tabular-nums; }
.inv-table .inv-empty-row td { text-align: center; color: var(--ork-text-muted); padding: 22px 12px; font-style: italic; }
.inv-link { background: none; border: none; color: var(--ork-link); cursor: pointer; font-size: 0.82rem; padding: 0 2px; }
.inv-link:hover { text-decoration: underline; }
.inv-link.inv-link-quiet { color: var(--ork-text-muted); }
.inv-link.inv-link-quiet:hover { color: var(--ork-text); }

/* Empty state */
.inv-empty {
    background: var(--ork-card-bg); border: 1px solid var(--ork-border); border-radius: 10px;
    padding: 28px 16px; text-align: center; color: var(--ork-text-muted); font-style: italic;
}

/* Pager */
.inv-pager { display: flex; gap: 6px; align-items: center; justify-content: flex-end; margin-top: 12px; font-size: 0.85rem; color: var(--ork-text-muted); }
.inv-pager button {
    background: var(--ork-bg-secondary); border: 1px solid var(--ork-border); color: var(--ork-text);
    border-radius: 6px; padding: 4px 10px; cursor: pointer; font-size: 0.82rem;
}
.inv-pager button:disabled { opacity: .45; cursor: default; }

/* Condition badge ("Needs Repair") + removed-reason badge */
.inv-badge {
    display: inline-block; font-size: 0.68rem; font-weight: 700; text-transform: uppercase; letter-spacing: .03em;
    border-radius: 999px; padding: 2px 8px;
}
.inv-badge-repair { background: #fed7aa; color: #9c4221; }
html[data-theme="dark"] .inv-badge-repair { background: #7b341e; color: #fbd38d; }
.inv-badge-reason { background: #e2e8f0; color: #4a5568; }
html[data-theme="dark"] .inv-badge-reason { background: #2d3748; color: #cbd5e0; }
.inv-reason-note { display: block; color: var(--ork-text-muted); font-size: 0.76rem; margin-top: 3px; }

/* Modal (in-product; no native dialogs) */
.inv-modal-overlay {
    position: fixed; inset: 0; background: rgba(15, 23, 42, .55);
    display: none; align-items: flex-start; justify-content: center;
    z-index: 10000; padding: 40px 16px; overflow-y: auto;
}
.inv-modal-overlay.inv-open { display: flex; }
.inv-modal {
    background: var(--ork-card-bg); color: var(--ork-text);
    border: 1px solid var(--ork-border); border-radius: 12px;
    width: 100%; max-width: 560px; box-shadow: 0 12px 40px rgba(0,0,0,.35);
}
.inv-modal-head {
    display: flex; align-items: center; justify-content: space-between;
    padding: 14px 18px; border-bottom: 1px solid var(--ork-border);
}
.inv-modal-head h2 {
    background: transparent; border: none; padding: 0; border-radius: 0; text-shadow: none;
    margin: 0; font-size: 1.05rem; font-weight: 700; color: var(--ork-text);
}
.inv-modal-close { background: none; border: none; color: var(--ork-text-muted); font-size: 1.3rem; cursor: pointer; line-height: 1; padding: 0 2px; }
.inv-modal-close:hover { color: var(--ork-text); }
.inv-modal-body { padding: 16px 18px; }
.inv-modal-foot { display: flex; gap: 8px; justify-content: flex-end; padding: 12px 18px 16px; border-top: 1px solid var(--ork-border); }

/* Form fields */
.inv-field { margin-bottom: 13px; }
.inv-field-row { display: flex; gap: 12px; }
.inv-field-row > .inv-field { flex: 1 1 0; margin-bottom: 13px; }
.inv-label { display: block; font-size: 0.76rem; font-weight: 600; color: var(--ork-text-secondary); margin-bottom: 5px; text-transform: uppercase; letter-spacing: .03em; }
.inv-input, .inv-select, .inv-textarea {
    width: 100%; box-sizing: border-box;
    background: var(--ork-input-bg); border: 1px solid var(--ork-input-border); color: var(--ork-text);
    border-radius: 6px; padding: 8px 10px; font-size: 0.88rem; font-family: inherit;
}
.inv-textarea { resize: vertical; min-height: 56px; }
.inv-input:focus, .inv-select:focus, .inv-textarea:focus { outline: none; border-color: #6366f1; box-shadow: 0 0 0 2px rgba(99,102,241,.25); }
.inv-field-err { color: #c53030; font-size: 0.78rem; margin-top: 5px; display: none; }
html[data-theme="dark"] .inv-field-err { color: #feb2b2; }
.inv-field.inv-has-err .inv-input, .inv-field.inv-has-err .inv-select { border-color: #c53030; }
.inv-field.inv-has-err .inv-field-err { display: block; }

/* Segmented control (condition) */
.inv-seg { display: inline-flex; flex-wrap: wrap; border: 1px solid var(--ork-input-border); border-radius: 7px; overflow: hidden; }
.inv-seg button {
    background: var(--ork-input-bg); color: var(--ork-text-secondary); border: none;
    padding: 7px 13px; font-size: 0.82rem; font-weight: 600; cursor: pointer;
    border-right: 1px solid var(--ork-input-border); line-height: 1.2;
}
.inv-seg button:last-child { border-right: none; }
.inv-seg button.inv-seg-on { background: #4338ca; color: #fff; }
html[data-theme="dark"] .inv-seg button.inv-seg-on { background: #6366f1; }

/* Held-by player-search autocomplete (scoped) — absolute within a relative field, above modal */
.inv-ac-wrap { position: relative; }
.inv-ac-results {
    position: absolute; left: 0; right: 0; top: 100%; z-index: 10001;
    margin-top: 4px; max-height: 220px; overflow-y: auto; display: none;
    background: var(--ork-card-bg); border: 1px solid var(--ork-input-border);
    border-radius: 6px; box-shadow: 0 6px 18px rgba(0,0,0,.28);
}
.inv-ac-results.inv-ac-open { display: block; }
.inv-ac-item { padding: 8px 11px; font-size: 0.84rem; cursor: pointer; color: var(--ork-text); border-bottom: 1px solid var(--ork-border); }
.inv-ac-item:last-child { border-bottom: none; }
.inv-ac-item:hover, .inv-ac-item.inv-ac-focused { background: rgba(99,102,241,.16); }
.inv-ac-item.inv-ac-empty { color: var(--ork-text-muted); cursor: default; }
.inv-ac-item .inv-ac-meta { color: var(--ork-text-muted); font-size: 0.72rem; }

/* tnConfirm fallback dialog (when Tournament helper not present) */
.inv-confirm-box { max-width: 420px; }
.inv-confirm-box .inv-modal-body { font-size: 0.9rem; color: var(--ork-text); }

@media (max-width: 820px) {
    .inv-cards { grid-template-columns: repeat(2, 1fr); }
    .inv-charts { grid-template-columns: 1fr; }
}
</style>

<div class="inv-wrap" id="inv-app"
     data-ajax="<?= htmlspecialchars($ajaxBase) ?>"
     data-kingdom="<?= (int)$kingdom_id ?>">

    <div class="inv-hero">
        <h1>Inventory &mdash; <?= htmlspecialchars($org_name ?? '') ?></h1>
        <div class="inv-hero-sub"><?= $owner_type === 'park' ? 'Park' : 'Kingdom' ?> equipment &amp; goods register</div>
    </div>

    <div class="inv-cards">
        <div class="inv-card">
            <div class="inv-card-lbl">Total Value</div>
            <div class="inv-card-val" id="inv-total-value"><?= $fmt($summary['TotalValue']) ?></div>
        </div>
        <div class="inv-card">
            <div class="inv-card-lbl">Total Units</div>
            <div class="inv-card-val" id="inv-total-units"><?= (int)$summary['TotalUnits'] ?></div>
        </div>
        <div class="inv-card">
            <div class="inv-card-lbl">Line Items</div>
            <div class="inv-card-val" id="inv-line-items"><?= (int)$summary['LineItems'] ?></div>
        </div>
        <div class="inv-card inv-card-repair">
            <div class="inv-card-lbl">Needs Repair</div>
            <div class="inv-card-val" id="inv-needs-repair"><?= (int)$summary['NeedsRepair'] ?></div>
        </div>
    </div>

    <div class="inv-charts">
        <div class="inv-chart-card">
            <div class="inv-chart-title">Value by Category</div>
            <div id="inv-chart-category" style="height:240px"></div>
        </div>
        <div class="inv-chart-card">
            <div class="inv-chart-title">Items by Condition</div>
            <div id="inv-chart-condition" style="height:240px"></div>
        </div>
    </div>

    <div class="inv-toolbar">
        <input type="text" id="inv-f-q" placeholder="Search name&hellip;" autocomplete="off">
        <select id="inv-f-cat">
            <option value="">All categories</option>
            <?php foreach ($categories as $k => $lbl): ?>
            <option value="<?= htmlspecialchars($k) ?>"><?= htmlspecialchars($lbl) ?></option>
            <?php endforeach; ?>
        </select>
        <select id="inv-f-cond">
            <option value="">Any condition</option>
            <?php foreach ($condLabels as $k => $lbl): ?>
            <option value="<?= htmlspecialchars($k) ?>"><?= htmlspecialchars($lbl) ?></option>
            <?php endforeach; ?>
        </select>
        <select id="inv-f-status">
            <option value="active">Active</option>
            <option value="removed">Removed</option>
        </select>
        <span class="inv-spacer"></span>
        <button class="inv-btn inv-btn-primary" id="inv-add" type="button">+ Add Item</button>
        <a class="inv-btn" id="inv-export" href="<?= htmlspecialchars($ajaxBase) ?>export">Export CSV</a>
    </div>

    <table class="inv-table" id="inv-table">
        <thead>
            <tr>
                <th data-sort="name">Name</th>
                <th data-sort="category">Category</th>
                <th class="inv-num" data-sort="quantity">Qty</th>
                <th data-sort="condition">Condition</th>
                <th class="inv-num" data-sort="unit_value">Unit Value</th>
                <th class="inv-num" data-sort="total_value">Total Value</th>
                <th data-sort="location">Location</th>
                <th>Held By</th>
                <th></th>
            </tr>
        </thead>
        <tbody id="inv-table-body"><!-- rendered by JS --></tbody>
    </table>
    <div class="inv-empty" id="inv-empty" style="display:none">No items yet &mdash; add your first item.</div>
    <div class="inv-pager" id="inv-pager"></div>
</div>

<!-- Add / Edit item modal (built/populated by JS) -->
<div class="inv-modal-overlay" id="inv-item-overlay" aria-hidden="true">
    <div class="inv-modal" role="dialog" aria-modal="true" aria-labelledby="inv-item-title">
        <div class="inv-modal-head">
            <h2 id="inv-item-title">Add Item</h2>
            <button class="inv-modal-close" type="button" data-inv-close aria-label="Close">&times;</button>
        </div>
        <form id="inv-item-form" autocomplete="off">
            <div class="inv-modal-body">
                <input type="hidden" name="id" id="inv-i-id" value="">
                <div class="inv-field-row">
                    <div class="inv-field" style="flex:2 1 0;">
                        <label class="inv-label" for="inv-i-name">Name</label>
                        <input class="inv-input" type="text" id="inv-i-name" name="name" maxlength="160" placeholder="e.g. Boffer longsword">
                        <div class="inv-field-err" data-err="name">A name is required.</div>
                    </div>
                    <div class="inv-field">
                        <label class="inv-label" for="inv-i-quantity">Quantity</label>
                        <input class="inv-input" type="number" min="1" step="1" id="inv-i-quantity" name="quantity" value="1">
                        <div class="inv-field-err" data-err="quantity">Quantity must be at least 1.</div>
                    </div>
                </div>
                <div class="inv-field">
                    <label class="inv-label" for="inv-i-category">Category</label>
                    <select class="inv-select" id="inv-i-category" name="category"></select>
                    <div class="inv-field-err" data-err="category">Choose a category.</div>
                </div>
                <div class="inv-field">
                    <label class="inv-label">Condition</label>
                    <div class="inv-seg" id="inv-i-cond-seg"></div>
                    <input type="hidden" name="condition" id="inv-i-condition" value="good">
                </div>
                <div class="inv-field-row">
                    <div class="inv-field">
                        <label class="inv-label" for="inv-i-unit-value">Unit Value</label>
                        <input class="inv-input" type="number" step="0.01" min="0" id="inv-i-unit-value" name="unit_value" placeholder="0.00">
                    </div>
                    <div class="inv-field">
                        <label class="inv-label" for="inv-i-acquired">Acquired Date</label>
                        <input class="inv-input" type="text" id="inv-i-acquired" name="acquired_date" placeholder="Select date">
                    </div>
                </div>
                <div class="inv-field">
                    <label class="inv-label" for="inv-i-location">Location</label>
                    <input class="inv-input" type="text" id="inv-i-location" name="location" maxlength="160" placeholder="e.g. Kingdom shed">
                </div>
                <div class="inv-field inv-ac-wrap" id="inv-i-heldby-field">
                    <label class="inv-label" for="inv-i-heldby">Held By</label>
                    <input class="inv-input" type="text" id="inv-i-heldby" name="held_by" maxlength="160" placeholder="Holder name, or search players&hellip;" autocomplete="off">
                    <input type="hidden" id="inv-i-heldby-player-id" name="held_by_player_id" value="0">
                    <div class="inv-ac-results" id="inv-i-heldby-results"></div>
                </div>
                <div class="inv-field">
                    <label class="inv-label" for="inv-i-notes">Notes</label>
                    <textarea class="inv-textarea" id="inv-i-notes" name="notes" maxlength="1000" placeholder="Anything else worth recording?"></textarea>
                </div>
                <div class="inv-field-err" data-err="_form" style="text-align:center;"></div>
            </div>
            <div class="inv-modal-foot">
                <button class="inv-btn" type="button" data-inv-close>Cancel</button>
                <button class="inv-btn inv-btn-primary" type="submit" id="inv-i-save">Save Item</button>
            </div>
        </form>
    </div>
</div>

<!-- Remove-from-inventory modal (reason + optional note) -->
<div class="inv-modal-overlay" id="inv-remove-overlay" aria-hidden="true">
    <div class="inv-modal inv-confirm-box" role="dialog" aria-modal="true" aria-labelledby="inv-remove-title">
        <div class="inv-modal-head">
            <h2 id="inv-remove-title">Remove from Inventory</h2>
            <button class="inv-modal-close" type="button" data-inv-remove-close aria-label="Close">&times;</button>
        </div>
        <form id="inv-remove-form" autocomplete="off">
            <div class="inv-modal-body">
                <input type="hidden" name="id" id="inv-r-id" value="">
                <p style="margin:0 0 14px;color:var(--ork-text-muted);font-size:0.85rem;">
                    Mark this item as no longer owned by the org. It moves to the Removed list
                    and is excluded from active totals (the record and its audit trail are kept).
                </p>
                <div class="inv-field">
                    <label class="inv-label" for="inv-r-reason">Reason</label>
                    <select class="inv-select" id="inv-r-reason" name="removal_reason">
                        <option value="">Select a reason&hellip;</option>
                        <?php foreach ($removal_reasons as $k => $lbl): ?>
                        <option value="<?= htmlspecialchars($k) ?>"><?= htmlspecialchars($lbl) ?></option>
                        <?php endforeach; ?>
                    </select>
                    <div class="inv-field-err" data-err="removal_reason">Choose a reason for removal.</div>
                </div>
                <div class="inv-field">
                    <label class="inv-label" for="inv-r-note">Note <span style="font-weight:400;text-transform:none;letter-spacing:0;color:var(--ork-text-muted);">(optional)</span></label>
                    <textarea class="inv-textarea" id="inv-r-note" name="removal_note" maxlength="1000" placeholder="e.g. damaged at June war, disposed of on-site"></textarea>
                </div>
                <div class="inv-field-err" data-err="_form" style="text-align:center;"></div>
            </div>
            <div class="inv-modal-foot">
                <button class="inv-btn" type="button" data-inv-remove-close>Cancel</button>
                <button class="inv-btn inv-btn-primary" type="submit" id="inv-r-save"
                        style="background:#c53030;border-color:#c53030;">Remove Item</button>
            </div>
        </form>
    </div>
</div>

<script>
window.InvConfig = {
    ajax:            '<?= $ajaxBase ?>',
    uir:             '<?= UIR ?>',
    ownerType:       '<?= $owner_type === 'park' ? 'park' : 'kingdom' ?>',
    ownerId:         <?= (int)$owner_id ?>,
    kingdomId:       <?= (int)($kingdom_id ?? 0) ?>,
    categories:      <?= json_encode($categories) ?>,
    removalReasons:  <?= json_encode($removal_reasons) ?>,
    conditionLabels: <?= json_encode($condLabels) ?>,
    summary:         <?= json_encode($summary) ?>,
    initialItems:    <?= json_encode($items) ?>
};
</script>

<script>
/* =====================================================
   Inventory — item render, add/edit modal, held-by playersearch.
   Exposes window.InvApp so later sections (remove/restore/delete, charts)
   can trigger refreshes via InvApp / the 'inv:datachanged' event.
   ===================================================== */
(function () {
    'use strict';

    var app = document.getElementById('inv-app');
    if (!app) { return; }
    var cfg = window.InvConfig || {};

    var body  = document.getElementById('inv-table-body');
    var table = document.getElementById('inv-table');
    var empty = document.getElementById('inv-empty');
    var pager = document.getElementById('inv-pager');
    var state = { page: 1, per: 25, q: '', category: '', condition: '', status: 'active', sort: 'name', dir: 'asc' };

    /* ---- helpers ---- */
    var money = function (n) { return '$' + (Number(n) || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 }); };
    function escapeHtml(s) {
        return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
            return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
        });
    }
    function condLabel(c) { return (cfg.conditionLabels && cfg.conditionLabels[c]) || c || ''; }
    function catLabel(c) { return (cfg.categories && cfg.categories[c]) || c || ''; }
    // "2026-06-07 12:34:56" -> "Jun 7, 2026" (date-only, parsed as local so no TZ drift).
    function fmtDate(s) {
        if (!s) { return ''; }
        var m = String(s).match(/^(\d{4})-(\d{2})-(\d{2})/);
        if (!m) { return String(s); }
        var d = new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]));
        return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
    }
    function postForm(action, data) {
        var fd = new URLSearchParams();
        Object.keys(data).forEach(function (k) { fd.append(k, data[k] == null ? '' : data[k]); });
        return fetch(cfg.ajax + action, {
            method: 'POST', credentials: 'same-origin',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: fd.toString()
        }).then(function (r) { return r.json(); });
    }

    /* ---- in-product confirm (tnConfirm if Tournament helper is loaded; else local fallback) ---- */
    function invConfirm(opts) {
        if (typeof window.tnConfirm === 'function') { window.tnConfirm(opts); return; }
        var ov = document.createElement('div');
        ov.className = 'inv-modal-overlay inv-open';
        ov.innerHTML =
            '<div class="inv-modal inv-confirm-box" role="dialog" aria-modal="true">' +
            '<div class="inv-modal-head"><h2></h2>' +
            '<button class="inv-modal-close" type="button" data-c="x" aria-label="Close">&times;</button></div>' +
            '<div class="inv-modal-body"></div>' +
            '<div class="inv-modal-foot">' +
            '<button class="inv-btn" type="button" data-c="cancel"></button>' +
            '<button class="inv-btn" type="button" data-c="ok"></button></div></div>';
        ov.querySelector('h2').textContent = opts.title || 'Confirm';
        ov.querySelector('.inv-modal-body').textContent = opts.body || '';
        var okBtn = ov.querySelector('[data-c="ok"]');
        var cancelBtn = ov.querySelector('[data-c="cancel"]');
        okBtn.textContent = opts.confirmLabel || 'Confirm';
        cancelBtn.textContent = opts.cancelLabel || 'Cancel';
        okBtn.className = 'inv-btn ' + (opts.danger ? 'inv-btn-danger' : 'inv-btn-primary');
        if (opts.danger) { okBtn.style.background = '#c53030'; okBtn.style.borderColor = '#c53030'; okBtn.style.color = '#fff'; }
        function close() { if (ov.parentNode) { ov.parentNode.removeChild(ov); } }
        ov.addEventListener('click', function (e) {
            var c = e.target.getAttribute && e.target.getAttribute('data-c');
            if (e.target === ov || c === 'x' || c === 'cancel') { close(); }
            else if (c === 'ok') { close(); if (typeof opts.onConfirm === 'function') { opts.onConfirm(); } }
        });
        document.body.appendChild(ov);
        okBtn.focus();
    }

    /* ---- item rendering ---- */
    function heldByCell(r) {
        var name = escapeHtml(r.HeldBy || '');
        if (name && r.HeldByPlayerId && r.HeldByPlayerId > 0) {
            return '<a href="' + cfg.uir + 'Playernew/index/' + r.HeldByPlayerId + '">' + name + '</a>';
        }
        return name;
    }
    function conditionCell(r) {
        if (r.Condition === 'needs_repair') {
            return '<span class="inv-badge inv-badge-repair">Needs Repair</span>';
        }
        return escapeHtml(condLabel(r.Condition));
    }
    function actionCell(r) {
        if (state.status === 'removed') {
            return '<button class="inv-link" type="button" data-restore="' + r.Id + '">Restore</button> ' +
                '<button class="inv-link inv-link-quiet" type="button" data-del="' + r.Id + '">Delete</button>';
        }
        return '<button class="inv-link" type="button" data-edit="' + r.Id + '">Edit</button> ' +
            '<button class="inv-link" type="button" data-remove="' + r.Id + '">Remove</button> ' +
            '<button class="inv-link inv-link-quiet" type="button" data-del="' + r.Id + '">Delete</button>';
    }

    function renderRows(d) {
        d = d || {};
        body.innerHTML = '';
        var rows = d.Rows || [];
        var removed = state.status === 'removed';
        if (!rows.length) {
            // Empty state replaces the table entirely.
            table.style.display = 'none';
            empty.style.display = '';
            empty.textContent = removed ? 'No removed items.' : 'No items yet — add your first item.';
            pager.innerHTML = '';
            return;
        }
        table.style.display = '';
        empty.style.display = 'none';
        rows.forEach(function (r) {
            var tr = document.createElement('tr');
            var nameCell = escapeHtml(r.Name || '');
            if (removed && (r.RemovalReason || r.RemovedAt)) {
                if (r.RemovalReason) {
                    var rlabel = (cfg.removalReasons && cfg.removalReasons[r.RemovalReason]) || r.RemovalReason;
                    nameCell += ' <span class="inv-badge inv-badge-reason">' + escapeHtml(rlabel) + '</span>';
                }
                if (r.RemovedAt) { nameCell += '<span class="inv-reason-note">Removed ' + escapeHtml(fmtDate(r.RemovedAt)) + '</span>'; }
                if (r.RemovalNote) { nameCell += '<span class="inv-reason-note">' + escapeHtml(r.RemovalNote) + '</span>'; }
            }
            tr.innerHTML =
                '<td>' + nameCell + '</td>' +
                '<td>' + escapeHtml(catLabel(r.Category)) + '</td>' +
                '<td class="inv-num">' + (Number(r.Quantity) || 0) + '</td>' +
                '<td>' + conditionCell(r) + '</td>' +
                '<td class="inv-num">' + money(r.UnitValue) + '</td>' +
                '<td class="inv-num">' + money(r.TotalValue) + '</td>' +
                '<td>' + escapeHtml(r.Location || '') + '</td>' +
                '<td>' + heldByCell(r) + '</td>' +
                '<td style="white-space:nowrap;">' + actionCell(r) + '</td>';
            body.appendChild(tr);
        });
        renderPager(d);
        updateSortIndicators();
    }

    function renderPager(d) {
        pager.innerHTML = '';
        var total = d.Total || 0, per = d.Per || state.per, page = d.Page || state.page;
        var pages = Math.max(1, Math.ceil(total / per));
        if (total === 0) { return; }
        var prev = document.createElement('button');
        prev.type = 'button'; prev.textContent = 'Prev'; prev.disabled = page <= 1;
        prev.addEventListener('click', function () { if (state.page > 1) { state.page--; loadItems(); } });
        var info = document.createElement('span');
        info.textContent = 'Page ' + page + ' of ' + pages + ' · ' + total + ' item' + (total === 1 ? '' : 's');
        var next = document.createElement('button');
        next.type = 'button'; next.textContent = 'Next'; next.disabled = page >= pages;
        next.addEventListener('click', function () { if (state.page < pages) { state.page++; loadItems(); } });
        pager.appendChild(prev); pager.appendChild(info); pager.appendChild(next);
    }

    function updateSortIndicators() {
        Array.prototype.forEach.call(table.querySelectorAll('thead th[data-sort]'), function (th) {
            var ind = th.querySelector('.inv-sort-ind');
            if (ind) { ind.parentNode.removeChild(ind); }
            if (th.getAttribute('data-sort') === state.sort) {
                var span = document.createElement('span');
                span.className = 'inv-sort-ind';
                span.textContent = state.dir === 'asc' ? ' ▲' : ' ▼';
                th.appendChild(span);
            }
        });
    }

    function itemsQuery(extra) {
        var q = new URLSearchParams({
            page: state.page, per: state.per, q: state.q, category: state.category,
            condition: state.condition, status: state.status, sort: state.sort, dir: state.dir
        });
        if (extra) { Object.keys(extra).forEach(function (k) { q.set(k, extra[k]); }); }
        return q.toString();
    }

    function loadItems() {
        // cfg.ajax already ends in '?Route=...'; append params with '&' (a 2nd '?' breaks routing).
        return fetch(cfg.ajax + 'items&' + itemsQuery(), { credentials: 'same-origin' })
            .then(function (r) { return r.json(); })
            .then(function (j) { if (j.status === 0) { renderRows(j.detail); } return j; });
    }

    /* Refresh the four summary cards (Total Value / Units / Line Items / Needs Repair). */
    function loadSummary() {
        return fetch(cfg.ajax + 'summary&category=' + encodeURIComponent(state.category) +
                '&condition=' + encodeURIComponent(state.condition) + '&q=' + encodeURIComponent(state.q),
                { credentials: 'same-origin' })
            .then(function (r) { return r.json(); })
            .then(function (j) {
                if (j.status !== 0 || !j.detail) { return j; }
                var s = j.detail;
                var setTxt = function (id, val) { var el = document.getElementById(id); if (el) { el.textContent = val; } };
                setTxt('inv-total-value', money(s.TotalValue));
                setTxt('inv-total-units', Number(s.TotalUnits) || 0);
                setTxt('inv-line-items', Number(s.LineItems) || 0);
                setTxt('inv-needs-repair', Number(s.NeedsRepair) || 0);
                cfg.summary = s;
                return j;
            });
    }

    /* Reload everything affected by a CRUD operation; charts listen for inv:datachanged. */
    function refreshAll() {
        return Promise.all([loadItems(), loadSummary()]).then(function () {
            app.dispatchEvent(new CustomEvent('inv:datachanged', { bubbles: true }));
        });
    }

    /* ---- filters + sort ---- */
    function bindFilters() {
        var qIn   = document.getElementById('inv-f-q');
        var catSel = document.getElementById('inv-f-cat');
        var condSel = document.getElementById('inv-f-cond');
        var statSel = document.getElementById('inv-f-status');
        var qTimer = null;
        if (qIn) {
            qIn.addEventListener('input', function () {
                clearTimeout(qTimer);
                qTimer = setTimeout(function () { state.q = qIn.value.trim(); state.page = 1; loadItems(); loadSummary(); }, 250);
            });
        }
        if (catSel)  { catSel.addEventListener('change', function () { state.category = catSel.value; state.page = 1; loadItems(); loadSummary(); }); }
        if (condSel) { condSel.addEventListener('change', function () { state.condition = condSel.value; state.page = 1; loadItems(); loadSummary(); }); }
        if (statSel) { statSel.addEventListener('change', function () { state.status = statSel.value === 'removed' ? 'removed' : 'active'; state.page = 1; loadItems(); }); }

        // Sortable headers.
        Array.prototype.forEach.call(table.querySelectorAll('thead th[data-sort]'), function (th) {
            th.addEventListener('click', function () {
                var key = th.getAttribute('data-sort');
                if (state.sort === key) { state.dir = state.dir === 'asc' ? 'desc' : 'asc'; }
                else { state.sort = key; state.dir = 'asc'; }
                state.page = 1; loadItems();
            });
        });

        // Keep the export link in sync with active filters.
        var exp = document.getElementById('inv-export');
        if (exp) {
            exp.addEventListener('click', function () {
                exp.href = cfg.ajax + 'export&' + itemsQuery({ page: 1, per: 100000 });
            });
        }
    }

    /* =====================================================
       Add / Edit item modal
       ===================================================== */
    var overlay   = document.getElementById('inv-item-overlay');
    var form      = document.getElementById('inv-item-form');
    var titleEl   = document.getElementById('inv-item-title');
    var catSelect = document.getElementById('inv-i-category');
    var condSeg   = document.getElementById('inv-i-cond-seg');
    var condHidden = document.getElementById('inv-i-condition');
    var acqInput  = document.getElementById('inv-i-acquired');
    var fpAcq     = null;

    /* Held-by player-picker (scoped player search inside the modal). */
    var heldByInput = document.getElementById('inv-i-heldby');
    var heldById    = document.getElementById('inv-i-heldby-player-id');
    var heldByRes   = document.getElementById('inv-i-heldby-results');
    var heldByTimer = null;

    function closeHeldByResults() { if (heldByRes) { heldByRes.classList.remove('inv-ac-open'); heldByRes.innerHTML = ''; } }
    function runHeldBySearch() {
        if (heldById) { heldById.value = '0'; }   // typing free-text invalidates a prior pick
        var term = heldByInput.value.trim();
        if (term.length < 2) { closeHeldByResults(); return; }
        clearTimeout(heldByTimer);
        heldByTimer = setTimeout(function () {
            // UIR already ends in '?Route='; query params use '&' (a 2nd '?' empties $_GET['q']).
            var url = cfg.uir + 'KingdomAjax/playersearch/' + (cfg.kingdomId || 0) +
                '&scope=own&include_inactive=1&q=' + encodeURIComponent(term);
            fetch(url, { credentials: 'same-origin' })
                .then(function (r) { return r.json(); })
                .then(function (data) {
                    if (!Array.isArray(data) || !data.length) {
                        heldByRes.innerHTML = '<div class="inv-ac-item inv-ac-empty">No players found</div>';
                        heldByRes.classList.add('inv-ac-open');
                        return;
                    }
                    heldByRes.innerHTML = data.map(function (p) {
                        var meta = (p.KAbbr || '') + (p.PAbbr ? ':' + p.PAbbr : '');
                        return '<div class="inv-ac-item" tabindex="-1" data-id="' + p.MundaneId +
                            '" data-name="' + encodeURIComponent(p.Persona || '') + '">' +
                            escapeHtml(p.Persona || '') + ' <span class="inv-ac-meta">(' + escapeHtml(meta) + ')</span>' +
                            (p.Active === 0 ? ' <span class="inv-ac-meta">&mdash; inactive</span>' : '') + '</div>';
                    }).join('');
                    heldByRes.classList.add('inv-ac-open');
                })
                .catch(function () { closeHeldByResults(); });
        }, 250);
    }
    function chooseHeldBy(item) {
        if (!item) { return; }
        heldByInput.value = decodeURIComponent(item.getAttribute('data-name') || '');
        if (heldById) { heldById.value = item.getAttribute('data-id') || '0'; }
        closeHeldByResults();
    }
    function heldByKeyNav(e) {
        if (!heldByRes) { return; }
        var items = heldByRes.querySelectorAll('.inv-ac-item[data-id]');
        if (!items.length) { return; }
        var cur = heldByRes.querySelector('.inv-ac-item.inv-ac-focused');
        var idx = -1;
        for (var i = 0; i < items.length; i++) { if (items[i] === cur) { idx = i; break; } }
        if (e.key === 'ArrowDown') { e.preventDefault(); if (cur) { cur.classList.remove('inv-ac-focused'); } idx = Math.min(idx + 1, items.length - 1); items[idx].classList.add('inv-ac-focused'); items[idx].scrollIntoView({ block: 'nearest' }); }
        else if (e.key === 'ArrowUp') { e.preventDefault(); if (cur) { cur.classList.remove('inv-ac-focused'); } idx = Math.max(idx - 1, 0); items[idx].classList.add('inv-ac-focused'); items[idx].scrollIntoView({ block: 'nearest' }); }
        else if (e.key === 'Enter' && cur) { e.preventDefault(); chooseHeldBy(cur); }
        else if (e.key === 'Escape') { closeHeldByResults(); }
    }

    /* Build the category <select> (flat key=>label map). */
    function buildCategoryOptions() {
        if (!catSelect) { return; }
        var cats = cfg.categories || {};
        catSelect.innerHTML = '<option value="">Select…</option>';
        Object.keys(cats).forEach(function (k) {
            var opt = document.createElement('option');
            opt.value = k; opt.textContent = cats[k];
            catSelect.appendChild(opt);
        });
    }

    /* Build the condition segmented control. */
    function buildConditionSeg() {
        if (!condSeg) { return; }
        var labels = cfg.conditionLabels || {};
        condSeg.innerHTML = '';
        Object.keys(labels).forEach(function (k) {
            var b = document.createElement('button');
            b.type = 'button'; b.setAttribute('data-cond', k); b.textContent = labels[k];
            condSeg.appendChild(b);
        });
    }
    function setCondition(cond) {
        cond = cond || 'good';
        condHidden.value = cond;
        Array.prototype.forEach.call(condSeg.querySelectorAll('button'), function (b) {
            b.classList.toggle('inv-seg-on', b.getAttribute('data-cond') === cond);
        });
    }

    function clearErrors() {
        Array.prototype.forEach.call(form.querySelectorAll('.inv-field.inv-has-err'), function (f) { f.classList.remove('inv-has-err'); });
        var fe = form.querySelector('[data-err="_form"]');
        if (fe) { fe.textContent = ''; fe.style.display = 'none'; }
    }
    function markError(field, msg) {
        if (field === '_form') {
            var fe = form.querySelector('[data-err="_form"]');
            if (fe) { fe.textContent = msg; fe.style.display = 'block'; }
            return;
        }
        var errEl = form.querySelector('[data-err="' + field + '"]');
        if (errEl) {
            if (msg) { errEl.textContent = msg; }
            var wrap = errEl.closest('.inv-field');
            if (wrap) { wrap.classList.add('inv-has-err'); }
        }
    }

    function openModal(isEdit) {
        clearErrors();
        titleEl.textContent = isEdit ? 'Edit Item' : 'Add Item';
        document.getElementById('inv-i-save').textContent = isEdit ? 'Save Changes' : 'Save Item';
        overlay.classList.add('inv-open');
        overlay.setAttribute('aria-hidden', 'false');
        if (!fpAcq && window.flatpickr) {
            fpAcq = flatpickr(acqInput, { dateFormat: 'Y-m-d', altInput: true, altFormat: 'F j, Y', allowInput: false });
        }
    }
    function closeModal() {
        overlay.classList.remove('inv-open');
        overlay.setAttribute('aria-hidden', 'true');
        closeHeldByResults();
    }

    function resetForm() {
        form.reset();
        document.getElementById('inv-i-id').value = '';
        document.getElementById('inv-i-quantity').value = '1';
        setCondition('good');
        if (heldByInput) { heldByInput.value = ''; }
        if (heldById) { heldById.value = '0'; }
        if (fpAcq) { fpAcq.clear(); } else { acqInput.value = ''; }
        closeHeldByResults();
        clearErrors();
    }

    function fillForm(e) {
        document.getElementById('inv-i-id').value = e.id || '';
        document.getElementById('inv-i-name').value = e.name || '';
        catSelect.value = e.category || '';
        document.getElementById('inv-i-quantity').value = (e.quantity != null) ? e.quantity : 1;
        setCondition(e.condition || 'good');
        document.getElementById('inv-i-unit-value').value = (e.unit_value != null && e.unit_value !== '') ? Number(e.unit_value).toFixed(2) : '';
        document.getElementById('inv-i-location').value = e.location || '';
        heldByInput.value = e.held_by || '';
        if (heldById) { heldById.value = (parseInt(e.held_by_player_id || 0, 10) > 0) ? String(parseInt(e.held_by_player_id, 10)) : '0'; }
        document.getElementById('inv-i-notes').value = e.notes || '';
        var d = e.acquired_date || '';
        // Normalize a 'YYYY-MM-DD HH:MM:SS' value down to the date part.
        if (d && d.length >= 10) { d = d.slice(0, 10); }
        if (fpAcq) { if (d) { fpAcq.setDate(d, true); } else { fpAcq.clear(); } }
        else { acqInput.value = d; }
    }

    function openAdd() {
        resetForm();
        openModal(false);
    }

    function openEdit(id) {
        resetForm();
        openModal(true);
        fetch(cfg.ajax + 'getitem&id=' + encodeURIComponent(id), { credentials: 'same-origin' })
            .then(function (r) { return r.json(); })
            .then(function (j) {
                if (j.status === 0 && j.detail) { fillForm(j.detail); }
                else { markError('_form', (j.error || 'Could not load this item.')); }
            });
    }

    function submitItem(ev) {
        ev.preventDefault();
        clearErrors();
        var id     = document.getElementById('inv-i-id').value;
        var isEdit = !!id;
        var data = {
            name:              document.getElementById('inv-i-name').value.trim(),
            category:          catSelect.value,
            quantity:          document.getElementById('inv-i-quantity').value,
            condition:         condHidden.value,
            unit_value:        document.getElementById('inv-i-unit-value').value || '0',
            location:          document.getElementById('inv-i-location').value,
            held_by:           heldByInput.value,
            held_by_player_id: heldById ? (heldById.value || '0') : '0',
            acquired_date:     acqInput.value || (fpAcq && fpAcq.input ? fpAcq.input.value : ''),
            notes:             document.getElementById('inv-i-notes').value
        };

        // Client-side guards mirroring the lib's validation (server re-validates regardless).
        var ok = true;
        if (data.name === '')                          { markError('name'); ok = false; }
        if (!data.category)                            { markError('category'); ok = false; }
        if (!(parseInt(data.quantity, 10) >= 1))       { markError('quantity'); ok = false; }
        if (!ok) { return; }

        var saveBtn = document.getElementById('inv-i-save');
        saveBtn.disabled = true;
        var action = isEdit ? 'edititem' : 'additem';
        if (isEdit) { data.id = id; }
        postForm(action, data).then(function (j) {
            saveBtn.disabled = false;
            if (j.status === 0) {
                closeModal();
                if (!isEdit) { state.page = 1; }
                refreshAll();
            } else {
                markError('_form', j.error || 'Could not save this item.');
            }
        }).catch(function () {
            saveBtn.disabled = false;
            markError('_form', 'Network error — please try again.');
        });
    }

    /* =====================================================
       Remove / restore / delete flows
       ----------------------------------------------------
       Remove  : opens a modal (required reason + optional note) → POST removeitem.
       Restore : tnConfirm → POST restoreitem (shown when the status filter = Removed).
       Delete  : danger tnConfirm → POST deleteitem (quiet mis-entry correction).
       ===================================================== */
    var removeOverlay = document.getElementById('inv-remove-overlay');
    var removeForm    = document.getElementById('inv-remove-form');
    var removeIdEl    = document.getElementById('inv-r-id');
    var removeReason  = document.getElementById('inv-r-reason');
    var removeNote    = document.getElementById('inv-r-note');

    function clearRemoveErrors() {
        if (!removeForm) { return; }
        Array.prototype.forEach.call(removeForm.querySelectorAll('.inv-field.inv-has-err'), function (f) { f.classList.remove('inv-has-err'); });
        var fe = removeForm.querySelector('[data-err="_form"]');
        if (fe) { fe.textContent = ''; fe.style.display = 'none'; }
    }
    function markRemoveError(field, msg) {
        if (!removeForm) { return; }
        if (field === '_form') {
            var fe = removeForm.querySelector('[data-err="_form"]');
            if (fe) { fe.textContent = msg; fe.style.display = 'block'; }
            return;
        }
        var errEl = removeForm.querySelector('[data-err="' + field + '"]');
        if (errEl) {
            if (msg) { errEl.textContent = msg; }
            var wrap = errEl.closest('.inv-field');
            if (wrap) { wrap.classList.add('inv-has-err'); }
        }
    }
    function closeRemoveModal() {
        if (!removeOverlay) { return; }
        removeOverlay.classList.remove('inv-open');
        removeOverlay.setAttribute('aria-hidden', 'true');
    }
    function removeItem(id) {
        if (!removeOverlay) { return; }
        clearRemoveErrors();
        if (removeForm) { removeForm.reset(); }
        if (removeIdEl) { removeIdEl.value = id; }
        if (removeReason) { removeReason.value = ''; }
        if (removeNote) { removeNote.value = ''; }
        removeOverlay.classList.add('inv-open');
        removeOverlay.setAttribute('aria-hidden', 'false');
        if (removeReason) { removeReason.focus(); }
    }
    function submitRemove(ev) {
        ev.preventDefault();
        clearRemoveErrors();
        var id     = removeIdEl ? removeIdEl.value : '';
        var reason = removeReason ? removeReason.value : '';
        var note   = removeNote ? removeNote.value : '';
        if (!reason) { markRemoveError('removal_reason'); return; }   // block submit with no reason

        var saveBtn = document.getElementById('inv-r-save');
        if (saveBtn) { saveBtn.disabled = true; }
        postForm('removeitem', { id: id, removal_reason: reason, removal_note: note }).then(function (j) {
            if (saveBtn) { saveBtn.disabled = false; }
            if (j.status === 0) { closeRemoveModal(); refreshAll(); }
            else { markRemoveError('_form', j.error || 'Could not remove this item.'); }
        }).catch(function () {
            if (saveBtn) { saveBtn.disabled = false; }
            markRemoveError('_form', 'Network error — please try again.');
        });
    }
    function bindRemoveModal() {
        if (!removeOverlay) { return; }
        Array.prototype.forEach.call(removeOverlay.querySelectorAll('[data-inv-remove-close]'), function (b) {
            b.addEventListener('click', closeRemoveModal);
        });
        removeOverlay.addEventListener('click', function (e) { if (e.target === removeOverlay) { closeRemoveModal(); } });
        document.addEventListener('keydown', function (e) {
            if (e.key === 'Escape' && removeOverlay.classList.contains('inv-open')) { closeRemoveModal(); }
        });
        if (removeForm) { removeForm.addEventListener('submit', submitRemove); }
        // Clear the reason error as soon as a reason is chosen.
        if (removeReason) {
            removeReason.addEventListener('change', function () {
                if (removeReason.value) {
                    var wrap = removeReason.closest('.inv-field');
                    if (wrap) { wrap.classList.remove('inv-has-err'); }
                }
            });
        }
    }
    function restoreItem(id) {
        invConfirm({
            title: 'Restore item',
            body: 'Return this item to active inventory?',
            confirmLabel: 'Restore',
            onConfirm: function () {
                postForm('restoreitem', { id: id }).then(function (j) {
                    if (j.status === 0) { refreshAll(); }
                    else { invConfirm({ title: 'Restore failed', body: (j.error || 'Could not restore this item.'), confirmLabel: 'OK', cancelLabel: 'Close' }); }
                });
            }
        });
    }
    function deleteItem(id) {
        invConfirm({
            title: 'Delete entry',
            body: 'This removes a mis-entered item entirely. Use “Remove from Inventory” for items the org disposed of.',
            confirmLabel: 'Delete',
            danger: true,
            onConfirm: function () {
                postForm('deleteitem', { id: id }).then(function (j) {
                    if (j.status === 0) { refreshAll(); }
                    else { invConfirm({ title: 'Delete failed', body: (j.error || 'Could not delete this item.'), confirmLabel: 'OK', cancelLabel: 'Close' }); }
                });
            }
        });
    }

    /* ---- wiring ---- */
    function bindModal() {
        buildCategoryOptions();
        buildConditionSeg();
        setCondition('good');

        var addBtn = document.getElementById('inv-add');
        if (addBtn) { addBtn.addEventListener('click', openAdd); }

        // Condition segmented control.
        condSeg.addEventListener('click', function (e) {
            var b = e.target.closest('button[data-cond]'); if (b) { setCondition(b.getAttribute('data-cond')); }
        });

        // Held-by scoped player search.
        if (heldByInput) {
            heldByInput.addEventListener('input', runHeldBySearch);
            heldByInput.addEventListener('keydown', heldByKeyNav);
        }
        if (heldByRes) {
            heldByRes.addEventListener('click', function (e) {
                var item = e.target.closest('.inv-ac-item[data-id]');
                if (item) { chooseHeldBy(item); }
            });
        }
        // Close the player dropdown on an outside click.
        document.addEventListener('click', function (e) {
            if (heldByRes && !heldByRes.contains(e.target) && e.target !== heldByInput) { closeHeldByResults(); }
        });

        // Close handlers.
        Array.prototype.forEach.call(overlay.querySelectorAll('[data-inv-close]'), function (b) {
            b.addEventListener('click', closeModal);
        });
        overlay.addEventListener('click', function (e) { if (e.target === overlay) { closeModal(); } });
        document.addEventListener('keydown', function (e) {
            if (e.key === 'Escape' && overlay.classList.contains('inv-open')) { closeModal(); }
        });
        form.addEventListener('submit', submitItem);
    }

    /* Delegated row action buttons. */
    body.addEventListener('click', function (e) {
        var ed = e.target.closest('[data-edit]');
        if (ed) { openEdit(ed.getAttribute('data-edit')); return; }
        var rm = e.target.closest('[data-remove]');
        if (rm) { removeItem(rm.getAttribute('data-remove')); return; }
        var rs = e.target.closest('[data-restore]');
        if (rs) { restoreItem(rs.getAttribute('data-restore')); return; }
        var dl = e.target.closest('[data-del]');
        if (dl) { deleteItem(dl.getAttribute('data-del')); }
    });

    /* ---- public surface for later sections (charts/auto-refresh) ---- */
    window.InvApp = {
        loadItems: loadItems,
        loadSummary: loadSummary,
        refreshAll: refreshAll,
        money: money,
        confirm: invConfirm,
        postForm: postForm,
        state: state
    };

    /* ---- init ---- */
    bindFilters();
    bindModal();
    bindRemoveModal();
    if (cfg.initialItems && cfg.initialItems.Rows) { renderRows(cfg.initialItems); }
    else { loadItems(); }
    updateSortIndicators();
})();
</script>

<script>
/* =====================================================
   Inventory — charts + live auto-refresh heartbeat
   • Value by Category : donut/pie from cfg.summary.ByCategory (key → value),
     labelled via cfg.categories.
   • Items by Condition: column chart from cfg.summary.ByCondition (cond → count),
     labelled via cfg.conditionLabels, in fixed order (new → needs_repair).
   Both re-render after any CRUD by listening for the 'inv:datachanged' event
   (dispatched by InvApp.refreshAll, which has already refetched the summary
   into cfg.summary). A cheap `rev` poll (every ~25s + on focus) refetches
   items + summary when the server-side data changes — paused while a modal is
   open or the tab is hidden. Dark-mode-aware via the isDark() pattern.
   ===================================================== */
(function () {
    'use strict';

    var app = document.getElementById('inv-app');
    if (!app) { return; }
    var cfg = window.InvConfig || {};
    var InvApp = window.InvApp || {};

    /* Fixed condition order for the column chart (matches the lib's FIELD() sort). */
    var COND_ORDER = ['new', 'good', 'fair', 'poor', 'needs_repair'];
    /* Per-condition colours (green → amber → red as condition worsens). */
    var COND_COLORS = {
        'new': '#2f855a', 'good': '#38a169', 'fair': '#d69e2e',
        'poor': '#dd6b20', 'needs_repair': '#c53030'
    };
    /* Distinct slices for the category donut. */
    var CAT_PALETTE = ['#4338ca', '#6366f1', '#0891b2', '#0d9488', '#7c3aed',
        '#db2777', '#ea580c', '#ca8a04', '#16a34a', '#475569'];

    function isDark() {
        return document.documentElement.getAttribute('data-theme') === 'dark';
    }
    function tooltipOpts() {
        var dark = isDark();
        return {
            backgroundColor: dark ? '#1e293b' : undefined,
            borderColor:     dark ? '#334155' : undefined,
            style:           { color: dark ? '#e2e8f0' : '#333333' }
        };
    }
    function axisColors() {
        var dark = isDark();
        return {
            label: dark ? '#94a3b8' : '#666666',
            line:  dark ? '#334155' : '#e5e7eb',
            grid:  dark ? '#293548' : '#f0f0f0'
        };
    }
    function money(n) {
        return '$' + (Number(n) || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    }
    function catLabel(k) { return (cfg.categories && cfg.categories[k]) || k; }
    function condLabel(k) { return (cfg.conditionLabels && cfg.conditionLabels[k]) || k; }

    var catChart  = null;
    var condChart = null;

    /* ---- Value by Category (donut) ---- */
    function renderCategoryChart(byCategory) {
        if (typeof Highcharts === 'undefined') { return; }
        byCategory = byCategory || {};
        var data = [];
        Object.keys(byCategory).forEach(function (key) {
            var val = Math.abs(Number(byCategory[key]) || 0);
            if (val <= 0) { return; }
            data.push({ name: catLabel(key), y: val, color: CAT_PALETTE[data.length % CAT_PALETTE.length] });
        });
        var hostEl = document.getElementById('inv-chart-category');
        if (!hostEl) { return; }

        if (!data.length) {
            if (catChart) { catChart.destroy(); catChart = null; }
            hostEl.innerHTML = '<div style="height:100%;display:flex;align-items:center;justify-content:center;color:var(--ork-text-muted);font-size:0.85rem;">No item value yet.</div>';
            return;
        }

        var dark = isDark();
        if (catChart) {
            catChart.update({ tooltip: tooltipOpts() }, false);
            catChart.series[0].update({ dataLabels: { style: { color: dark ? '#e2e8f0' : '#333333' } } }, false);
            catChart.series[0].setData(data, false);
            catChart.redraw();
            return;
        }

        catChart = new Highcharts.Chart({
            chart: { renderTo: 'inv-chart-category', type: 'pie', backgroundColor: 'transparent', style: { fontFamily: 'inherit' } },
            title: { text: null },
            series: [{
                name: 'Value', data: data, innerSize: '55%',
                dataLabels: {
                    enabled: true,
                    formatter: function () { return this.point.name + ': ' + money(this.y); },
                    style: { color: dark ? '#e2e8f0' : '#333333', fontSize: '11px', textOutline: 'none' }
                }
            }],
            legend: { enabled: false },
            credits: { enabled: false },
            tooltip: Object.assign({
                headerFormat: '',
                pointFormatter: function () { return '<b>' + this.name + '</b>: ' + money(this.y); }
            }, tooltipOpts())
        });
    }

    /* ---- Items by Condition (column) ---- */
    function renderConditionChart(byCondition) {
        if (typeof Highcharts === 'undefined') { return; }
        byCondition = byCondition || {};
        var categories = COND_ORDER.map(condLabel);
        var data = COND_ORDER.map(function (k) {
            return { y: Number(byCondition[k]) || 0, color: COND_COLORS[k] || '#4338ca' };
        });
        var ax = axisColors();
        var hostEl = document.getElementById('inv-chart-condition');
        if (!hostEl) { return; }

        var anyData = data.some(function (p) { return p.y > 0; });
        if (!anyData) {
            if (condChart) { condChart.destroy(); condChart = null; }
            hostEl.innerHTML = '<div style="height:100%;display:flex;align-items:center;justify-content:center;color:var(--ork-text-muted);font-size:0.85rem;">No items yet.</div>';
            return;
        }

        if (condChart) {
            condChart.update({ tooltip: tooltipOpts() }, false);
            condChart.xAxis[0].update({ categories: categories }, false);
            condChart.series[0].setData(data, false);
            condChart.redraw();
            return;
        }

        condChart = new Highcharts.Chart({
            chart: { renderTo: 'inv-chart-condition', type: 'column', backgroundColor: 'transparent', style: { fontFamily: 'inherit' } },
            title: { text: null },
            xAxis: {
                categories: categories,
                lineColor: ax.line, tickColor: ax.line,
                labels: { style: { color: ax.label, fontSize: '11px' } }
            },
            yAxis: {
                title: { text: null }, gridLineColor: ax.grid, allowDecimals: false, min: 0,
                labels: { style: { color: ax.label, fontSize: '11px' } }
            },
            plotOptions: { column: { borderRadius: 2, borderWidth: 0, maxPointWidth: 56, colorByPoint: true, pointPadding: 0.05, groupPadding: 0.08 } },
            series: [{ name: 'Items', data: data }],
            legend: { enabled: false },
            credits: { enabled: false },
            tooltip: Object.assign({
                headerFormat: '<b>{point.key}</b><br/>',
                pointFormatter: function () { return 'Items: <b>' + (Number(this.y) || 0) + '</b>'; }
            }, tooltipOpts())
        });
    }

    function renderAll() {
        var s = cfg.summary || {};
        renderCategoryChart(s.ByCategory || {});
        renderConditionChart(s.ByCondition || {});
    }

    /* Refetch the summary the charts depend on, then re-render. InvApp.loadSummary
       already updates cfg.summary on a datachanged cycle, but refetch here too so
       the charts are correct even if this section loads independently. */
    function refetchAndRender() {
        var st = InvApp.state || {};
        var url = cfg.ajax + 'summary&category=' + encodeURIComponent(st.category || '') +
            '&condition=' + encodeURIComponent(st.condition || '') + '&q=' + encodeURIComponent(st.q || '');
        fetch(url, { credentials: 'same-origin' })
            .then(function (r) { return r.json(); })
            .then(function (j) {
                if (j.status === 0 && j.detail) { cfg.summary = j.detail; }
                renderAll();
            })
            .catch(function () { renderAll(); });
    }

    /* Re-theme charts when dark mode is toggled (re-render picks up colours). */
    var themeObserver = new MutationObserver(function (muts) {
        for (var i = 0; i < muts.length; i++) {
            if (muts[i].attributeName === 'data-theme') { renderAll(); break; }
        }
    });
    themeObserver.observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme'] });

    /* =====================================================
       Live auto-refresh: poll a cheap revision token; only refetch on a real change.
       ===================================================== */
    var INV_POLL_MS = 25000;
    var lastRev = null;
    var pollTimer = null;
    function anyModalOpen() { return !!document.querySelector('.inv-modal-overlay.inv-open'); }
    function syncRevision() {
        return fetch(cfg.ajax + 'rev', { credentials: 'same-origin' })
            .then(function (r) { return r.json(); })
            .then(function (j) { if (j.status === 0 && j.detail) { lastRev = j.detail.Rev; } })
            .catch(function () {});
    }
    function checkRevision() {
        if (document.hidden || anyModalOpen()) { return; }   // don't refetch under an open editor or hidden tab
        fetch(cfg.ajax + 'rev', { credentials: 'same-origin' })
            .then(function (r) { return r.json(); })
            .then(function (j) {
                if (j.status !== 0 || !j.detail) { return; }
                if (lastRev === null) { lastRev = j.detail.Rev; return; }
                if (j.detail.Rev !== lastRev && !anyModalOpen()) {
                    lastRev = j.detail.Rev;
                    if (InvApp.refreshAll) { InvApp.refreshAll(); }   // reloads items + summary, then fires inv:datachanged
                }
            })
            .catch(function () {});
    }
    function startPolling() {
        if (pollTimer) { return; }
        pollTimer = setInterval(checkRevision, INV_POLL_MS);
        document.addEventListener('visibilitychange', function () { if (!document.hidden) { checkRevision(); } });
        window.addEventListener('focus', checkRevision);
        syncRevision();   // establish the baseline from the server-rendered initial state
    }

    /* ---- wiring ---- */
    // Charts re-render whenever a CRUD op (add/edit/remove/restore/delete or a
    // poll-triggered refresh) fires inv:datachanged. refetchAndRender re-reads the
    // summary so the charts are correct even if this section loaded independently.
    app.addEventListener('inv:datachanged', refetchAndRender);

    /* ---- init ---- */
    renderAll();
    startPolling();
})();
</script>
