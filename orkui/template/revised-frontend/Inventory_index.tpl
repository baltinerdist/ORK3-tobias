<?php
$uir = UIR;
$ajaxBase = $uir . 'InventoryAjax/handle/' . $owner_type . '/' . $owner_id . '/';
$fmt = fn($n) => '$' . number_format((float)$n, 2);
$condLabels = ['new' => 'New', 'good' => 'Good', 'fair' => 'Fair', 'poor' => 'Poor', 'needs_repair' => 'Needs Repair'];
?>
<script src="https://code.highcharts.com/highcharts.js"></script>
<style>
/* inv- prefixed; dark-mode via [data-theme=dark] selectors */
.inv-wrap { max-width: 1100px; margin: 0 auto; padding: 16px; }
.inv-hero h1 { background: transparent; border: none; padding: 0; border-radius: 0; text-shadow: none; }
.inv-cards { display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; margin: 12px 0; }
.inv-card { background:#fff; border:1px solid #e5e7eb; border-radius:10px; padding:14px; }
.inv-card-lbl { font-size:12px; color:#64748b; text-transform:uppercase; letter-spacing:.04em; }
.inv-card-val { font-size:22px; font-weight:700; margin-top:4px; }
[data-theme="dark"] .inv-card { background:#1e293b; border-color:#334155; color:#e2e8f0; }
[data-theme="dark"] .inv-card-lbl { color:#94a3b8; }
.inv-charts { display:grid; grid-template-columns:1fr 1fr; gap:12px; margin:12px 0; }
.inv-num { text-align:right; }
/* ...table, toolbar, modal, segmented control, badges — mirror Treasury_index.tpl... */
</style>

<div class="inv-wrap" id="inv-app"
     data-ajax="<?= htmlspecialchars($ajaxBase) ?>"
     data-kingdom="<?= (int)$kingdom_id ?>">
  <div class="inv-hero"><h1>Inventory — <?= htmlspecialchars($org_name) ?></h1></div>

  <div class="inv-cards">
    <div class="inv-card"><div class="inv-card-lbl">Total Value</div>
      <div class="inv-card-val" id="inv-total-value"><?= $fmt($summary['TotalValue']) ?></div></div>
    <div class="inv-card"><div class="inv-card-lbl">Total Units</div>
      <div class="inv-card-val" id="inv-total-units"><?= (int)$summary['TotalUnits'] ?></div></div>
    <div class="inv-card"><div class="inv-card-lbl">Line Items</div>
      <div class="inv-card-val" id="inv-line-items"><?= (int)$summary['LineItems'] ?></div></div>
    <div class="inv-card"><div class="inv-card-lbl">Needs Repair</div>
      <div class="inv-card-val" id="inv-needs-repair"><?= (int)$summary['NeedsRepair'] ?></div></div>
  </div>

  <div class="inv-charts">
    <div id="inv-chart-category" style="height:260px"></div>
    <div id="inv-chart-condition" style="height:260px"></div>
  </div>

  <div class="inv-toolbar">
    <input type="text" id="inv-f-q" placeholder="Search name…">
    <select id="inv-f-cat"><option value="">All categories</option>
      <?php foreach ($categories as $k => $lbl): ?><option value="<?= $k ?>"><?= htmlspecialchars($lbl) ?></option><?php endforeach; ?>
    </select>
    <select id="inv-f-cond"><option value="">Any condition</option>
      <?php foreach ($condLabels as $k => $lbl): ?><option value="<?= $k ?>"><?= htmlspecialchars($lbl) ?></option><?php endforeach; ?>
    </select>
    <select id="inv-f-status"><option value="active">Active</option><option value="removed">Removed</option></select>
    <button class="inv-btn" id="inv-add">+ Add Item</button>
    <a class="inv-btn" id="inv-export" href="<?= htmlspecialchars($ajaxBase) ?>export">Export CSV</a>
  </div>

  <table class="inv-table" id="inv-table">
    <thead><tr>
      <th data-sort="name">Name</th><th data-sort="category">Category</th>
      <th class="inv-num" data-sort="quantity">Qty</th><th data-sort="condition">Condition</th>
      <th class="inv-num" data-sort="unit_value">Unit Value</th><th class="inv-num" data-sort="total_value">Total Value</th>
      <th data-sort="location">Location</th><th>Held By</th><th></th>
    </tr></thead>
    <tbody id="inv-table-body"><!-- rendered by JS --></tbody>
  </table>
  <div class="inv-empty" id="inv-empty" style="display:none">No items yet — add your first item.</div>
  <div class="inv-pager" id="inv-pager"></div>
</div>

<script>
window.InvConfig = {
  ajax: '<?= $ajaxBase ?>',
  kingdomId: <?= (int)$kingdom_id ?>,
  categories: <?= json_encode($categories) ?>,
  removalReasons: <?= json_encode($removal_reasons) ?>,
  conditionLabels: <?= json_encode($condLabels) ?>,
  summary: <?= json_encode($summary) ?>,
  initialItems: <?= json_encode($items) ?>
};
</script>
