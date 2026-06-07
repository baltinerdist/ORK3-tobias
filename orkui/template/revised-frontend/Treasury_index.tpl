<?php
/* -----------------------------------------------------------------
   Treasury — officer-only per-org financial ledger (Kingdom/Park)
   Plain-PHP template (extract()+include). All CSS/JS inlined, `tr-`
   prefixed. Dark-mode via global --ork-* vars + html[data-theme=dark].
   Variables (from controller.Treasury::render):
     $owner_type, $owner_id, $categories, $org_name, $has_opening,
     $summary, $ledger, $reconciliations, $series
   ----------------------------------------------------------------- */
$uir = UIR;

// Flatten the grouped category map (key => label) for the filter dropdown + JS.
$catFlat = [];
foreach ((array)$categories as $grp => $items) {
    foreach ((array)$items as $k => $lbl) {
        $catFlat[$k] = $lbl;
    }
}

$ajaxBase = $uir . 'TreasuryAjax/handle/' . $owner_type . '/' . $owner_id . '/';
$fmt      = fn($n) => '$' . number_format((float)$n, 2);

// Defensive defaults (controller already supplies these, but render must never fatal).
$summary         = is_array($summary ?? null) ? $summary : ['CurrentBalance' => 0, 'TotalIn' => 0, 'TotalOut' => 0, 'ByCategory' => []];
$ledger          = is_array($ledger ?? null) ? $ledger : ['Rows' => [], 'Total' => 0];
$reconciliations = is_array($reconciliations ?? null) ? $reconciliations : [];
$series          = is_array($series ?? null) ? $series : [];
$summary += ['CurrentBalance' => 0, 'TotalIn' => 0, 'TotalOut' => 0, 'ByCategory' => []];
?>
<script src="https://code.highcharts.com/highcharts.js"></script>
<style>
/* =====================================================
   Treasury tool — .tr-* (light defaults; dark via --ork-* + overrides)
   ===================================================== */
.tr-wrap { max-width: 1100px; margin: 0 auto; padding: 16px 16px 48px; color: var(--ork-text); }

/* Hero heading — reset the global h1-h6 gray-box */
.tr-hero { margin: 4px 0 18px; }
.tr-hero h1 {
    background: transparent; border: none; padding: 0; border-radius: 0; text-shadow: none;
    margin: 0; font-size: 1.55rem; font-weight: 700; color: var(--ork-text);
}
.tr-hero .tr-hero-sub { color: var(--ork-text-muted); font-size: 0.9rem; margin-top: 2px; }

/* First-run banner */
.tr-firstrun {
    background: var(--ork-alert-info-bg); border: 1px solid var(--ork-alert-info-border);
    color: var(--ork-alert-info-text); border-radius: 10px; padding: 16px 18px; margin-bottom: 18px;
    display: flex; align-items: center; justify-content: space-between; gap: 16px; flex-wrap: wrap;
}
.tr-firstrun p { margin: 0; font-size: 0.92rem; }

/* Summary cards */
.tr-cards { display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; margin-bottom: 18px; }
.tr-card {
    background: var(--ork-card-bg); border: 1px solid var(--ork-border);
    border-radius: 10px; padding: 14px 16px;
}
.tr-card-lbl { font-size: 0.74rem; text-transform: uppercase; letter-spacing: .04em; color: var(--ork-text-muted); margin-bottom: 6px; }
.tr-card-val { font-size: 1.4rem; font-weight: 700; color: var(--ork-text); }
.tr-card.tr-card-in  .tr-card-val { color: #2f855a; }
.tr-card.tr-card-out .tr-card-val { color: #c53030; }
html[data-theme="dark"] .tr-card.tr-card-in  .tr-card-val { color: #9ae6b4; }
html[data-theme="dark"] .tr-card.tr-card-out .tr-card-val { color: #feb2b2; }

/* Charts */
.tr-charts { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; margin-bottom: 18px; }
.tr-chart-card {
    background: var(--ork-card-bg); border: 1px solid var(--ork-border);
    border-radius: 10px; padding: 8px 12px 12px;
}
.tr-chart-card .tr-chart-title { font-size: 0.8rem; font-weight: 600; color: var(--ork-text-secondary); margin: 4px 2px 6px; }

/* Toolbar */
.tr-toolbar { display: flex; flex-wrap: wrap; gap: 8px; align-items: center; margin-bottom: 12px; }
.tr-toolbar input[type="text"], .tr-toolbar select {
    background: var(--ork-input-bg); border: 1px solid var(--ork-input-border); color: var(--ork-text);
    border-radius: 6px; padding: 6px 10px; font-size: 0.85rem;
}
.tr-toolbar input[type="text"] { width: 130px; }
.tr-toolbar .tr-spacer { flex: 1 1 auto; }

/* Buttons */
.tr-btn {
    display: inline-block; padding: 7px 14px; border-radius: 6px; border: 1px solid var(--ork-border-dark);
    background: var(--ork-bg-secondary); color: var(--ork-text); font-size: 0.85rem; font-weight: 600;
    cursor: pointer; text-decoration: none; line-height: 1.2;
}
.tr-btn:hover { background: var(--ork-bg-tertiary); }
.tr-btn.tr-btn-primary { background: #4338ca; border-color: #4338ca; color: #fff; }
.tr-btn.tr-btn-primary:hover { background: #3730a3; }
html[data-theme="dark"] .tr-btn.tr-btn-primary { background: #6366f1; border-color: #6366f1; }
html[data-theme="dark"] .tr-btn.tr-btn-primary:hover { background: #818cf8; }

/* Ledger table */
.tr-ledger { width: 100%; border-collapse: collapse; background: var(--ork-card-bg); border: 1px solid var(--ork-border); border-radius: 10px; overflow: hidden; }
.tr-ledger thead th {
    text-align: left; font-size: 0.72rem; text-transform: uppercase; letter-spacing: .03em;
    color: var(--ork-text-muted); background: var(--ork-bg-secondary);
    padding: 9px 12px; border-bottom: 1px solid var(--ork-border);
}
.tr-ledger tbody td { padding: 9px 12px; font-size: 0.86rem; color: var(--ork-text); border-bottom: 1px solid var(--ork-border); }
.tr-ledger tbody tr:last-child td { border-bottom: none; }
.tr-ledger .tr-num { text-align: right; font-variant-numeric: tabular-nums; }
.tr-ledger .tr-empty td { text-align: center; color: var(--ork-text-muted); padding: 22px 12px; font-style: italic; }
.tr-link { background: none; border: none; color: var(--ork-link); cursor: pointer; font-size: 0.82rem; padding: 0 2px; }
.tr-link:hover { text-decoration: underline; }

/* Pager */
.tr-pager { display: flex; gap: 6px; align-items: center; justify-content: flex-end; margin-top: 12px; font-size: 0.85rem; color: var(--ork-text-muted); }
.tr-pager button {
    background: var(--ork-bg-secondary); border: 1px solid var(--ork-border); color: var(--ork-text);
    border-radius: 6px; padding: 4px 10px; cursor: pointer; font-size: 0.82rem;
}
.tr-pager button:disabled { opacity: .45; cursor: default; }

@media (max-width: 820px) {
    .tr-cards { grid-template-columns: repeat(2, 1fr); }
    .tr-charts { grid-template-columns: 1fr; }
}
</style>

<div class="tr-wrap" id="tr-app"
     data-ajax="<?= htmlspecialchars($ajaxBase) ?>"
     data-hasopening="<?= $has_opening ? '1' : '0' ?>">

    <div class="tr-hero">
        <h1>Treasury &mdash; <?= htmlspecialchars($org_name ?? '') ?></h1>
        <div class="tr-hero-sub"><?= $owner_type === 'park' ? 'Park' : 'Kingdom' ?> financial ledger</div>
    </div>

    <?php if (!$has_opening): ?>
    <div class="tr-firstrun" id="tr-firstrun">
        <p>Set your starting balance to begin. Enter the current real-world balance and the date it&rsquo;s accurate as of.</p>
        <button class="tr-btn tr-btn-primary" id="tr-set-opening" type="button">Set Opening Balance</button>
    </div>
    <?php endif; ?>

    <div class="tr-cards">
        <div class="tr-card">
            <div class="tr-card-lbl">Current Balance</div>
            <div class="tr-card-val" id="tr-bal"><?= $fmt($summary['CurrentBalance']) ?></div>
        </div>
        <div class="tr-card tr-card-in">
            <div class="tr-card-lbl">Total In</div>
            <div class="tr-card-val" id="tr-in"><?= $fmt($summary['TotalIn']) ?></div>
        </div>
        <div class="tr-card tr-card-out">
            <div class="tr-card-lbl">Total Out</div>
            <div class="tr-card-val" id="tr-out"><?= $fmt($summary['TotalOut']) ?></div>
        </div>
        <div class="tr-card">
            <div class="tr-card-lbl">Entries</div>
            <div class="tr-card-val" id="tr-count"><?= (int)$ledger['Total'] ?></div>
        </div>
    </div>

    <div class="tr-charts">
        <div class="tr-chart-card">
            <div class="tr-chart-title">Balance Over Time</div>
            <div id="tr-chart-balance" style="height:240px"></div>
        </div>
        <div class="tr-chart-card">
            <div class="tr-chart-title">By Category</div>
            <div id="tr-chart-cats" style="height:240px"></div>
        </div>
    </div>

    <div class="tr-toolbar">
        <input type="text" id="tr-f-from" placeholder="From" autocomplete="off">
        <input type="text" id="tr-f-to" placeholder="To" autocomplete="off">
        <select id="tr-f-cat">
            <option value="">All categories</option>
            <?php foreach ($catFlat as $k => $lbl): ?>
            <option value="<?= htmlspecialchars($k) ?>"><?= htmlspecialchars($lbl) ?></option>
            <?php endforeach; ?>
        </select>
        <select id="tr-f-dir">
            <option value="">In &amp; Out</option>
            <option value="credit">In</option>
            <option value="debit">Out</option>
        </select>
        <span class="tr-spacer"></span>
        <button class="tr-btn tr-btn-primary" id="tr-add" type="button">+ Add Entry</button>
        <button class="tr-btn" id="tr-reconcile" type="button">Reconcile</button>
        <a class="tr-btn" id="tr-export" href="<?= htmlspecialchars($ajaxBase) ?>export">Export CSV</a>
    </div>

    <table class="tr-ledger" id="tr-ledger">
        <thead>
            <tr>
                <th>Date</th><th>Category</th><th>Method</th><th>Description</th><th>Counterparty</th>
                <th class="tr-num">In</th><th class="tr-num">Out</th><th class="tr-num">Balance</th><th></th>
            </tr>
        </thead>
        <tbody id="tr-ledger-body"><!-- rendered by JS (Task 9) --></tbody>
    </table>
    <div class="tr-pager" id="tr-pager"></div>
</div>

<script>
window.TrConfig = {
    ajax:           '<?= $ajaxBase ?>',
    ownerType:      '<?= $owner_type === 'park' ? 'park' : 'kingdom' ?>',
    ownerId:        <?= (int)$owner_id ?>,
    categories:     <?= json_encode($catFlat) ?>,
    categoryGroups: <?= json_encode($categories) ?>,
    hasOpening:     <?= $has_opening ? 'true' : 'false' ?>,
    series:         <?= json_encode($series) ?>,
    byCategory:     <?= json_encode($summary['ByCategory']) ?>,
    initialLedger:  <?= json_encode($ledger) ?>
};
</script>
