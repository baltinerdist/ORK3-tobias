<?php
$_uid = isset($this->__session->user_id) ? (int)$this->__session->user_id : 0;
if ($_uid <= 0) { header('Location: ' . UIR . 'Login'); exit; }
$kingdom_id   = (int)($kingdom_id ?? 0);
$kingdom_name = $kingdom_name ?? 'Unknown';
?>
<!-- DataTables CDN -->
<link rel="stylesheet" href="https://cdn.datatables.net/1.13.8/css/jquery.dataTables.min.css">
<link rel="stylesheet" href="https://cdn.datatables.net/buttons/2.4.2/css/buttons.dataTables.min.css">
<link rel="stylesheet" href="https://cdn.datatables.net/fixedheader/3.4.0/css/fixedHeader.dataTables.min.css">
<link rel="stylesheet" href="https://cdn.datatables.net/fixedcolumns/4.3.0/css/fixedColumns.dataTables.min.css">
<link rel="stylesheet" href="<?=HTTP_TEMPLATE?>default/style/reports.css">

<script src="https://cdn.datatables.net/1.13.8/js/jquery.dataTables.min.js"></script>
<script src="https://cdn.datatables.net/buttons/2.4.2/js/dataTables.buttons.min.js"></script>
<script src="https://cdn.datatables.net/buttons/2.4.2/js/buttons.csv.js"></script>
<script src="https://cdn.datatables.net/buttons/2.4.2/js/buttons.print.js"></script>
<script src="https://cdn.datatables.net/fixedheader/3.4.0/js/dataTables.fixedHeader.min.js"></script>
<script src="https://cdn.datatables.net/fixedcolumns/4.3.0/js/dataTables.fixedColumns.min.js"></script>

<style>
/* ── Slice & Dice — sd- prefix ─────────────────────────── */

/* Dataset selector */
.sd-dataset-bar { display: flex; gap: 12px; padding: 16px 20px; border-bottom: 2px solid var(--rp-border); }
.sd-dataset-btn {
    flex: 1; display: flex; align-items: center; justify-content: center; gap: 8px;
    padding: 14px 16px; border: 2px solid var(--rp-border); border-radius: 8px;
    background: #fff; color: var(--rp-text-muted); font-size: 14px; font-weight: 600;
    cursor: pointer; transition: border-color 0.15s, background 0.15s, color 0.15s;
}
.sd-dataset-btn:hover { border-color: var(--rp-accent-mid); color: var(--rp-text); }
.sd-dataset-btn.sd-active {
    border-color: var(--rp-accent); background: rgba(67,56,202,0.06); color: var(--rp-accent);
}

/* Filters */
.sd-filters { padding: 16px 20px; border-bottom: 2px solid var(--rp-border); }
.sd-filters-grid { display: flex; gap: 12px; flex-wrap: wrap; }
.sd-filter-group { flex: 1; min-width: 180px; }
.sd-filter-group label { display: block; font-size: 11px; color: var(--rp-text-body); margin-bottom: 4px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px; }
.sd-filter-group select,
.sd-filter-group input[type="text"],
.sd-filter-group input[type="date"] {
    width: 100%; padding: 8px 10px; border: 1px solid #cbd5e0; border-radius: 6px;
    font-size: 13px; color: var(--rp-text); background: #fff; box-sizing: border-box;
}
.sd-filter-group select:focus,
.sd-filter-group input:focus { border-color: var(--rp-accent-mid); outline: none; box-shadow: 0 0 0 2px rgba(99,102,241,0.15); }
.sd-filters-footer { display: flex; justify-content: space-between; align-items: center; margin-top: 10px; }
.sd-filters-hint { font-size: 12px; color: var(--rp-text-muted); }
.sd-btn-clear {
    padding: 6px 14px; border-radius: 6px; background: #edf2f7; color: var(--rp-text-body);
    font-size: 12px; cursor: pointer; border: none; font-weight: 600;
}
.sd-btn-clear:hover { background: #e2e8f0; }

/* Player autocomplete */
.sd-ac-wrap { position: relative; }
.sd-ac-results {
    position: absolute; top: 100%; left: 0; right: 0; z-index: 100;
    background: #fff; border: 1px solid #cbd5e0; border-radius: 0 0 6px 6px;
    max-height: 200px; overflow-y: auto; display: none; box-shadow: 0 4px 12px rgba(0,0,0,0.1);
}
.sd-ac-results.kn-ac-open { display: block; }
.sd-ac-item { padding: 8px 10px; cursor: pointer; font-size: 13px; border-bottom: 1px solid #f1f3f5; }
.sd-ac-item:hover { background: rgba(67,56,202,0.06); }

/* Pivot config */
.sd-pivot-bar { display: flex; gap: 12px; align-items: flex-end; padding: 16px 20px; border-bottom: 2px solid var(--rp-border); }
.sd-pivot-group { flex: 1; }
.sd-pivot-group label { display: block; font-size: 11px; color: var(--rp-text-body); margin-bottom: 4px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px; }
.sd-pivot-group select { width: 100%; padding: 8px 10px; border: 1px solid #cbd5e0; border-radius: 6px; font-size: 13px; color: var(--rp-text); background: #fff; }
.sd-btn-run {
    padding: 10px 24px; background: var(--rp-accent); color: #fff; border: none;
    border-radius: 6px; font-size: 13px; font-weight: 700; cursor: pointer;
    white-space: nowrap; transition: background 0.15s;
}
.sd-btn-run:hover { background: var(--rp-accent-mid); }
.sd-btn-run:disabled { opacity: 0.5; cursor: not-allowed; }

/* Results */
.sd-results { padding: 16px 20px; display: none; }
.sd-results.sd-visible { display: block; }
.sd-results-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; }
.sd-results-meta { font-size: 12px; color: var(--rp-text-muted); }
.sd-results-meta strong { color: var(--rp-text); }
.sd-results-actions { display: flex; gap: 8px; }
.sd-export-btn {
    padding: 5px 12px; border: 1px solid var(--rp-border); border-radius: 4px;
    font-size: 11px; color: var(--rp-text-body); background: #fff; cursor: pointer;
    font-weight: 600;
}
.sd-export-btn:hover { background: #f7fafc; border-color: var(--rp-accent-mid); }
.sd-pivot-cell { color: var(--rp-accent); cursor: pointer; text-decoration: underline; font-weight: 500; }
.sd-pivot-cell:hover { color: var(--rp-accent-mid); }
.sd-total-row td { font-weight: 700; background: var(--rp-bg-light) !important; }
.sd-total-col { font-weight: 600; background: var(--rp-bg-light) !important; }
.sd-hint { font-size: 12px; color: var(--rp-text-muted); font-style: italic; margin-top: 10px; }
.sd-empty { text-align: center; padding: 40px 20px; color: var(--rp-text-muted); font-size: 14px; }
.sd-warning { padding: 10px 16px; background: #fffbeb; border: 1px solid #f59e0b; border-radius: 6px; font-size: 13px; color: #92400e; margin-bottom: 12px; }

/* Drill-down modal */
.sd-overlay {
    position: fixed; inset: 0; background: rgba(0,0,0,0.5); z-index: 9998;
    display: none; align-items: center; justify-content: center;
}
.sd-overlay.sd-visible { display: flex; }
.sd-modal {
    background: #fff; border-radius: 10px; width: 90%; max-width: 900px; max-height: 80vh;
    display: flex; flex-direction: column; box-shadow: 0 20px 60px rgba(0,0,0,0.3);
}
.sd-modal-header {
    display: flex; justify-content: space-between; align-items: center;
    padding: 14px 20px; background: var(--rp-accent-dark); color: #fff;
    border-radius: 10px 10px 0 0; font-weight: 600; font-size: 14px;
}
.sd-modal-close { cursor: pointer; font-size: 20px; line-height: 1; opacity: 0.7; background: none; border: none; color: #fff; }
.sd-modal-close:hover { opacity: 1; }
.sd-modal-body { padding: 16px 20px; overflow-y: auto; flex: 1; }

/* DataTables overrides scoped to sd-results */
.sd-results .dataTables_wrapper { font-size: 13px; }
.sd-results table.dataTable thead th { background: var(--rp-bg-light); font-weight: 600; font-size: 12px; }
.sd-results table.dataTable tbody td { font-size: 13px; }
.sd-modal-body .dataTables_wrapper { font-size: 13px; }
.sd-modal-body table.dataTable thead th { background: var(--rp-bg-light); }

/* Section labels */
.sd-section-label {
    font-size: 11px; text-transform: uppercase; letter-spacing: 1px;
    color: var(--rp-text-muted); font-weight: 600; margin-bottom: 10px;
}

/* Loading spinner */
.sd-loading { text-align: center; padding: 40px; color: var(--rp-text-muted); }
.sd-loading::after {
    content: ''; display: inline-block; width: 20px; height: 20px;
    border: 2px solid var(--rp-border); border-top-color: var(--rp-accent);
    border-radius: 50%; animation: sd-spin 0.6s linear infinite;
    vertical-align: middle; margin-left: 8px;
}
@keyframes sd-spin { to { transform: rotate(360deg); } }
</style>

<div class="rp-root">

    <!-- Header -->
    <div class="rp-header">
        <div class="rp-header-left">
            <div class="rp-header-icon-title">
                <span class="rp-header-icon">&#x1F50D;</span>
                <h2 class="rp-header-title">Slice &amp; Dice Explorer</h2>
            </div>
            <div class="rp-header-scope">
                <span class="rp-scope-chip"><?= htmlspecialchars($kingdom_name) ?></span>
            </div>
        </div>
    </div>

    <!-- Dataset selector -->
    <div class="sd-dataset-bar">
        <div class="sd-section-label" style="align-self:center;margin:0;margin-right:8px;">Dataset</div>
        <button class="sd-dataset-btn" data-dataset="awards">&#x1F3C6; Awards</button>
        <button class="sd-dataset-btn" data-dataset="attendance">&#x1F4CB; Attendance</button>
        <button class="sd-dataset-btn" data-dataset="players">&#x1F464; Players</button>
    </div>

    <!-- Filters (populated by JS based on dataset) -->
    <div class="sd-filters" id="sd-filters" style="display:none;">
        <div class="sd-section-label">Filters</div>
        <div class="sd-filters-grid" id="sd-filters-grid"></div>
        <div class="sd-filters-footer">
            <span class="sd-filters-hint">Filters stack as AND &mdash; each narrows the results further</span>
            <button class="sd-btn-clear" id="sd-btn-clear">Clear All</button>
        </div>
    </div>

    <!-- Pivot config -->
    <div class="sd-pivot-bar" id="sd-pivot-bar" style="display:none;">
        <div class="sd-pivot-group">
            <label>Rows</label>
            <select id="sd-pivot-row"></select>
        </div>
        <div class="sd-pivot-group">
            <label>Columns</label>
            <select id="sd-pivot-col"></select>
        </div>
        <div class="sd-pivot-group">
            <label>Aggregate</label>
            <select id="sd-pivot-agg"></select>
        </div>
        <button class="sd-btn-run" id="sd-btn-run" disabled>Run Report</button>
    </div>

    <!-- Results area -->
    <div class="sd-results" id="sd-results">
        <div class="sd-results-header">
            <div class="sd-results-meta" id="sd-results-meta"></div>
            <div class="sd-results-actions">
                <button class="sd-export-btn" id="sd-btn-csv">CSV</button>
                <button class="sd-export-btn" id="sd-btn-print">Print</button>
            </div>
        </div>
        <div id="sd-table-wrap"></div>
        <div class="sd-hint">Click any <span style="color:var(--rp-accent);text-decoration:underline">linked number</span> to see the underlying records</div>
    </div>

    <!-- Empty state -->
    <div class="sd-empty" id="sd-empty" style="display:none;">No records match your filters. Try broadening your search.</div>

</div>

<!-- Drill-down modal -->
<div class="sd-overlay" id="sd-overlay">
    <div class="sd-modal">
        <div class="sd-modal-header">
            <span id="sd-modal-title">Drill-Down</span>
            <button class="sd-modal-close" id="sd-modal-close">&times;</button>
        </div>
        <div class="sd-modal-body">
            <table id="sd-drill-table" class="display" style="width:100%"></table>
        </div>
    </div>
</div>

<script>
/* ── Slice & Dice Explorer JS ─────────────────────────── */
(function() {
    var SD_KINGDOM_ID = <?= $kingdom_id ?>;
    var SD_PARKS      = <?= $parks_json ?>;
    var SD_CLASSES    = <?= $classes_json ?>;
    var SD_AWARDS     = <?= $awards_json ?>;
    var UIR_JS        = '<?= UIR ?>';

    var currentDataset = null;
    var currentRecords = [];
    var currentMeta    = null;
    var pivotTable     = null;
    var drillTable     = null;
    var playerTimer    = null;
    var DEBOUNCE_MS    = 250;

    /* ── Helpers ── */
    function gid(id) { return document.getElementById(id); }
    function escHtml(s) { var d = document.createElement('div'); d.appendChild(document.createTextNode(s)); return d.innerHTML; }
    function valid_id(v) { return v && parseInt(v, 10) > 0; }

    /* ── Dataset selection ── */
    var datasetBtns = document.querySelectorAll('.sd-dataset-btn');
    for (var i = 0; i < datasetBtns.length; i++) {
        datasetBtns[i].addEventListener('click', function() {
            var ds = this.getAttribute('data-dataset');
            if (ds === currentDataset) return;
            currentDataset = ds;
            for (var j = 0; j < datasetBtns.length; j++) datasetBtns[j].classList.remove('sd-active');
            this.classList.add('sd-active');
            buildFilters(ds);
            gid('sd-filters').style.display = '';
            gid('sd-pivot-bar').style.display = '';
            gid('sd-results').classList.remove('sd-visible');
            gid('sd-empty').style.display = 'none';
            gid('sd-btn-run').disabled = false;
            currentRecords = [];
            currentMeta = null;
            if (pivotTable) { pivotTable.destroy(); pivotTable = null; gid('sd-table-wrap').innerHTML = ''; }
        });
    }

    /* ── Build filter UI per dataset ── */
    function buildFilters(ds) {
        var grid = gid('sd-filters-grid');
        grid.innerHTML = '';
        var html = '';

        // Park filter (all datasets)
        html += '<div class="sd-filter-group"><label>Park</label><select id="sd-f-park"><option value="">All Parks</option>';
        for (var i = 0; i < SD_PARKS.length; i++) html += '<option value="' + SD_PARKS[i].park_id + '">' + escHtml(SD_PARKS[i].name) + '</option>';
        html += '</select></div>';

        if (ds === 'awards') {
            html += '<div class="sd-filter-group"><label>Award Type</label><select id="sd-f-awardtype"><option value="">All Types</option><option value="ladder">Ladder</option><option value="title">Title</option><option value="nonladder">Non-Ladder</option></select></div>';
            html += '<div class="sd-filter-group"><label>Specific Award</label><select id="sd-f-award"><option value="">All Awards</option>';
            for (var i = 0; i < SD_AWARDS.length; i++) html += '<option value="' + SD_AWARDS[i].kingdomaward_id + '" data-type="' + SD_AWARDS[i].type + '">' + escHtml(SD_AWARDS[i].name) + '</option>';
            html += '</select></div>';
        }

        if (ds === 'attendance') {
            html += '<div class="sd-filter-group"><label>Class</label><select id="sd-f-class"><option value="">All Classes</option>';
            for (var i = 0; i < SD_CLASSES.length; i++) html += '<option value="' + SD_CLASSES[i].class_id + '">' + escHtml(SD_CLASSES[i].name) + '</option>';
            html += '</select></div>';
            html += '<div class="sd-filter-group"><label>Type</label><select id="sd-f-eventtype"><option value="all">All</option><option value="events">Events Only</option><option value="regular">Regular Only</option></select></div>';
        }

        if (ds === 'players') {
            html += '<div class="sd-filter-group"><label>Status</label><select id="sd-f-active"><option value="all">All</option><option value="active">Active</option><option value="inactive">Inactive</option></select></div>';
            html += '<div class="sd-filter-group"><label>Waiver</label><select id="sd-f-waiver"><option value="all">All</option><option value="waivered">Waivered</option><option value="unwaivered">Unwaivered</option></select></div>';
        }

        if (ds !== 'players') {
            // Player autocomplete
            html += '<div class="sd-filter-group"><label>Player</label><div class="sd-ac-wrap">'
                + '<input type="text" id="sd-f-player-text" placeholder="Search by persona..." autocomplete="off" />'
                + '<input type="hidden" id="sd-f-player-id" value="" />'
                + '<div class="sd-ac-results" id="sd-f-player-results"></div>'
                + '</div></div>';

            // Date range
            html += '<div class="sd-filter-group"><label>Date Start</label><input type="date" id="sd-f-datestart" /></div>';
            html += '<div class="sd-filter-group"><label>Date End</label><input type="date" id="sd-f-dateend" /></div>';
        }

        grid.innerHTML = html;

        // Award type cascading filter
        if (ds === 'awards') {
            var atEl = gid('sd-f-awardtype');
            if (atEl) {
                atEl.addEventListener('change', function() {
                    var type = this.value;
                    var sel = gid('sd-f-award');
                    var opts = sel.querySelectorAll('option[data-type]');
                    for (var k = 0; k < opts.length; k++) {
                        opts[k].style.display = (!type || opts[k].getAttribute('data-type') === type) ? '' : 'none';
                    }
                    if (sel.selectedOptions[0] && sel.selectedOptions[0].style.display === 'none') sel.value = '';
                });
            }
        }

        // Player autocomplete wiring
        if (ds !== 'players') {
            var ptxt = gid('sd-f-player-text');
            if (ptxt) {
                ptxt.addEventListener('input', function() {
                    gid('sd-f-player-id').value = '';
                    var term = this.value.trim();
                    if (term.length < 3) { gid('sd-f-player-results').classList.remove('kn-ac-open'); return; }
                    clearTimeout(playerTimer);
                    playerTimer = setTimeout(function() {
                        var url = UIR_JS + 'KingdomAjax/playersearch/' + SD_KINGDOM_ID + '&include_inactive=1&q=' + encodeURIComponent(term);
                        fetch(url).then(function(r) { return r.json(); }).then(function(data) {
                            var el = gid('sd-f-player-results');
                            el.innerHTML = (data && data.length)
                                ? data.map(function(p) {
                                    return '<div class="sd-ac-item" data-id="' + p.MundaneId + '" data-name="' + encodeURIComponent(p.Persona) + '">'
                                        + escHtml(p.Persona) + ' <span style="color:#a0aec0;font-size:11px">(' + escHtml(p.PAbbr || '') + ')</span>'
                                        + (p.Active === 0 ? ' <span style="color:#c53030;font-size:10px;font-weight:600">(Inactive)</span>' : '')
                                        + '</div>';
                                }).join('')
                                : '<div class="sd-ac-item" style="color:#a0aec0;cursor:default">No players found</div>';
                            el.classList.add('kn-ac-open');
                        });
                    }, DEBOUNCE_MS);
                });
                gid('sd-f-player-results').addEventListener('click', function(e) {
                    var item = e.target.closest('.sd-ac-item[data-id]');
                    if (!item) return;
                    gid('sd-f-player-text').value = decodeURIComponent(item.dataset.name);
                    gid('sd-f-player-id').value = item.dataset.id;
                    this.classList.remove('kn-ac-open');
                });
            }
        }

        // Populate pivot dropdowns
        updatePivotOptions(ds);
    }

    /* ── Pivot dropdown population ── */
    var DIMENSIONS = {
        awards:     { park: 'Park', award: 'Award Name', award_type: 'Award Type', player: 'Player', year: 'Year', month: 'Month' },
        attendance: { park: 'Park', player: 'Player', class_played: 'Class', year: 'Year', month: 'Month', day_of_week: 'Day of Week', event_type: 'Event vs Regular' },
        players:    { park: 'Park', active_status: 'Active/Inactive', waiver_status: 'Waivered/Unwaivered', year_joined: 'Year Joined' }
    };
    var AGGREGATES = {
        awards:     { count: 'Count', count_distinct_players: 'Unique Players', max_rank: 'Max Rank', avg_rank: 'Avg Rank' },
        attendance: { count: 'Count', count_distinct_players: 'Unique Players', count_distinct_dates: 'Unique Dates', avg_credits: 'Avg Credits/Player' },
        players:    { count: 'Count', count_active: 'Count Active', count_waivered: 'Count Waivered' }
    };

    function updatePivotOptions(ds) {
        var dims = DIMENSIONS[ds] || {};
        var aggs = AGGREGATES[ds] || {};
        var rowSel = gid('sd-pivot-row');
        var colSel = gid('sd-pivot-col');
        var aggSel = gid('sd-pivot-agg');
        rowSel.innerHTML = ''; colSel.innerHTML = ''; aggSel.innerHTML = '';
        var keys = Object.keys(dims);
        for (var i = 0; i < keys.length; i++) {
            rowSel.innerHTML += '<option value="' + keys[i] + '">' + escHtml(dims[keys[i]]) + '</option>';
            colSel.innerHTML += '<option value="' + keys[i] + '">' + escHtml(dims[keys[i]]) + '</option>';
        }
        if (keys.length > 1) colSel.selectedIndex = 1;
        var akeys = Object.keys(aggs);
        for (var i = 0; i < akeys.length; i++) {
            aggSel.innerHTML += '<option value="' + akeys[i] + '">' + escHtml(aggs[akeys[i]]) + '</option>';
        }
    }

    /* ── Collect filter values ── */
    function collectFilters() {
        var f = { dataset: currentDataset };
        var parkEl = gid('sd-f-park');
        if (parkEl) f.park_id = parkEl.value;
        if (currentDataset === 'awards') {
            var atEl = gid('sd-f-awardtype'); if (atEl) f.award_type = atEl.value;
            var awEl = gid('sd-f-award');     if (awEl) f.award_id = awEl.value;
        }
        if (currentDataset === 'attendance') {
            var clEl = gid('sd-f-class');     if (clEl) f.class_id = clEl.value;
            var evEl = gid('sd-f-eventtype'); if (evEl) f.event_filter = evEl.value;
        }
        if (currentDataset === 'players') {
            var acEl = gid('sd-f-active'); if (acEl) f.active_status = acEl.value;
            var waEl = gid('sd-f-waiver'); if (waEl) f.waiver_status = waEl.value;
        }
        if (currentDataset !== 'players') {
            var plEl = gid('sd-f-player-id'); if (plEl) f.player_id = plEl.value;
            var dsEl = gid('sd-f-datestart'); if (dsEl) f.date_start = dsEl.value;
            var deEl = gid('sd-f-dateend');   if (deEl) f.date_end = deEl.value;
        }
        return f;
    }

    /* ── Run Report (AJAX fetch) ── */
    gid('sd-btn-run').addEventListener('click', function() {
        if (!currentDataset) return;
        var btn = this;
        btn.disabled = true;
        btn.textContent = 'Loading...';

        var filters = collectFilters();
        var body = Object.keys(filters).map(function(k) {
            return encodeURIComponent(k) + '=' + encodeURIComponent(filters[k] || '');
        }).join('&');

        fetch(UIR_JS + 'ReportsAjax/slicedice', {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: body
        })
        .then(function(r) { return r.json(); })
        .then(function(data) {
            btn.disabled = false;
            btn.textContent = 'Run Report';
            if (data.status !== 0) {
                alert('Error: ' + (data.error || 'Unknown error'));
                return;
            }
            currentRecords = data.records;
            currentMeta = data.meta;
            if (currentRecords.length === 0) {
                gid('sd-results').classList.remove('sd-visible');
                gid('sd-empty').style.display = '';
                return;
            }
            gid('sd-empty').style.display = 'none';
            renderPivot();
        })
        .catch(function(err) {
            btn.disabled = false;
            btn.textContent = 'Run Report';
            console.error('[SliceDice] fetch error:', err);
            alert('Network error — check your connection and try again.');
        });
    });

    /* ── Pivot engine ── */
    function pivotData(records, rowKey, colKey, aggType) {
        var rowSet = {}, colSet = {};
        for (var i = 0; i < records.length; i++) {
            var rv = String(records[i][rowKey] != null ? records[i][rowKey] : 'Unknown');
            var cv = String(records[i][colKey] != null ? records[i][colKey] : 'Unknown');
            rowSet[rv] = true;
            colSet[cv] = true;
        }
        var rows = Object.keys(rowSet).sort();
        var cols = Object.keys(colSet).sort();
        var rowIdx = {}, colIdx = {};
        for (var i = 0; i < rows.length; i++) rowIdx[rows[i]] = i;
        for (var i = 0; i < cols.length; i++) colIdx[cols[i]] = i;

        // Accumulators
        var cells = [];
        for (var r = 0; r < rows.length; r++) {
            cells[r] = [];
            for (var c = 0; c < cols.length; c++) {
                cells[r][c] = { sum: 0, count: 0, max: null, set: {} };
            }
        }

        for (var i = 0; i < records.length; i++) {
            var rec = records[i];
            var ri = rowIdx[String(rec[rowKey] != null ? rec[rowKey] : 'Unknown')];
            var ci = colIdx[String(rec[colKey] != null ? rec[colKey] : 'Unknown')];
            var cell = cells[ri][ci];

            if (aggType === 'count') {
                cell.count++;
            } else if (aggType === 'count_distinct_players') {
                cell.set[rec.player_id] = true;
            } else if (aggType === 'count_distinct_dates') {
                cell.set[rec.date] = true;
            } else if (aggType === 'max_rank') {
                var rank = parseFloat(rec.rank) || 0;
                if (cell.max === null || rank > cell.max) cell.max = rank;
            } else if (aggType === 'avg_rank') {
                cell.sum += parseFloat(rec.rank) || 0;
                cell.count++;
            } else if (aggType === 'avg_credits') {
                cell.sum += parseFloat(rec.credits) || 0;
                cell.set[rec.player_id] = true;
            } else if (aggType === 'count_active') {
                if (rec.active_status === 'Active') cell.sum = (cell.sum || 0) + 1;
            } else if (aggType === 'count_waivered') {
                if (rec.waiver_status === 'Waivered') cell.sum = (cell.sum || 0) + 1;
            }
        }

        // Resolve final values
        var matrix = [];
        var rowTotals = [];
        var colTotals = new Array(cols.length);
        for (var c = 0; c < cols.length; c++) colTotals[c] = 0;
        var grandTotal = 0;

        for (var r = 0; r < rows.length; r++) {
            matrix[r] = [];
            rowTotals[r] = 0;
            for (var c = 0; c < cols.length; c++) {
                var cell = cells[r][c];
                var val = 0;
                if (aggType === 'count') val = cell.count;
                else if (aggType === 'count_distinct_players' || aggType === 'count_distinct_dates') val = Object.keys(cell.set).length;
                else if (aggType === 'max_rank') val = cell.max || 0;
                else if (aggType === 'avg_rank') val = cell.count > 0 ? Math.round((cell.sum / cell.count) * 100) / 100 : 0;
                else if (aggType === 'avg_credits') {
                    var nPlayers = Object.keys(cell.set).length;
                    val = nPlayers > 0 ? Math.round((cell.sum / nPlayers) * 100) / 100 : 0;
                }
                else if (aggType === 'count_active' || aggType === 'count_waivered') val = cell.sum || 0;
                matrix[r][c] = val;
                rowTotals[r] += val;
                colTotals[c] += val;
                grandTotal += val;
            }
        }

        return { rows: rows, cols: cols, matrix: matrix, rowTotals: rowTotals, colTotals: colTotals, grandTotal: grandTotal };
    }

    /* ── Render pivot into DataTable ── */
    function renderPivot() {
        var rowKey = gid('sd-pivot-row').value;
        var colKey = gid('sd-pivot-col').value;
        var aggType = gid('sd-pivot-agg').value;

        if (rowKey === colKey) {
            alert('Row and Column dimensions must be different.');
            return;
        }

        var pivot = pivotData(currentRecords, rowKey, colKey, aggType);
        var dims = currentMeta ? currentMeta.dimensions : DIMENSIONS[currentDataset];
        var rowLabel = dims[rowKey] || rowKey;

        // Warning for large datasets
        var warnHtml = '';
        if (currentRecords.length >= 10000) {
            warnHtml = '<div class="sd-warning">Large dataset (' + currentRecords.length.toLocaleString() + ' records). Consider narrowing filters for faster results.</div>';
        }

        // Build results meta
        gid('sd-results-meta').innerHTML = '<strong>' + currentRecords.length.toLocaleString() + '</strong> records &middot; '
            + pivot.rows.length + ' ' + escHtml(rowLabel) + (pivot.rows.length !== 1 ? 's' : '') + ' &times; ' + pivot.cols.length + ' columns';

        // Build table HTML
        var tableHtml = warnHtml + '<table id="sd-pivot-table" class="display" style="width:100%"><thead><tr><th>' + escHtml(rowLabel) + '</th>';
        for (var c = 0; c < pivot.cols.length; c++) {
            tableHtml += '<th>' + escHtml(String(pivot.cols[c])) + '</th>';
        }
        tableHtml += '<th class="sd-total-col">Total</th></tr></thead><tbody>';

        for (var r = 0; r < pivot.rows.length; r++) {
            tableHtml += '<tr><td><strong>' + escHtml(String(pivot.rows[r])) + '</strong></td>';
            for (var c = 0; c < pivot.cols.length; c++) {
                var v = pivot.matrix[r][c];
                if (v > 0) {
                    tableHtml += '<td><span class="sd-pivot-cell" data-row="' + escHtml(String(pivot.rows[r])) + '" data-col="' + escHtml(String(pivot.cols[c])) + '">' + v + '</span></td>';
                } else {
                    tableHtml += '<td style="color:#cbd5e0">0</td>';
                }
            }
            tableHtml += '<td class="sd-total-col">' + pivot.rowTotals[r] + '</td></tr>';
        }

        // Totals row
        tableHtml += '</tbody><tfoot><tr class="sd-total-row"><td><strong>Total</strong></td>';
        for (var c = 0; c < pivot.cols.length; c++) {
            tableHtml += '<td>' + pivot.colTotals[c] + '</td>';
        }
        tableHtml += '<td class="sd-total-col">' + pivot.grandTotal + '</td></tr></tfoot></table>';

        gid('sd-table-wrap').innerHTML = tableHtml;

        if (pivotTable) { pivotTable.destroy(); pivotTable = null; }
        pivotTable = $('#sd-pivot-table').DataTable({
            paging: false,
            searching: false,
            info: false,
            scrollX: true,
            fixedColumns: { left: 1 },
            order: [],
            dom: 'Bfrtip',
            buttons: [
                { extend: 'csv', filename: 'SliceDice_' + currentDataset, exportOptions: { columns: ':visible' } },
                { extend: 'print', exportOptions: { columns: ':visible' } }
            ]
        });

        gid('sd-results').classList.add('sd-visible');

        // Wire export buttons
        gid('sd-btn-csv').onclick = function() { pivotTable.button(0).trigger(); };
        gid('sd-btn-print').onclick = function() { pivotTable.button(1).trigger(); };
    }

    /* ── Re-pivot on dropdown change (no re-fetch) ── */
    gid('sd-pivot-row').addEventListener('change', function() { if (currentRecords.length) renderPivot(); });
    gid('sd-pivot-col').addEventListener('change', function() { if (currentRecords.length) renderPivot(); });
    gid('sd-pivot-agg').addEventListener('change', function() { if (currentRecords.length) renderPivot(); });

    /* ── Drill-down ── */
    gid('sd-table-wrap').addEventListener('click', function(e) {
        var cell = e.target.closest('.sd-pivot-cell');
        if (!cell) return;
        var rowVal = cell.dataset.row;
        var colVal = cell.dataset.col;
        var rowKey = gid('sd-pivot-row').value;
        var colKey = gid('sd-pivot-col').value;

        var filtered = currentRecords.filter(function(rec) {
            return String(rec[rowKey] != null ? rec[rowKey] : 'Unknown') === rowVal && String(rec[colKey] != null ? rec[colKey] : 'Unknown') === colVal;
        });

        gid('sd-modal-title').textContent = rowVal + ' \u00D7 ' + colVal + ' (' + filtered.length + ' records)';

        // Determine columns based on dataset
        var dtCols = [];
        if (currentDataset === 'awards') {
            dtCols = [
                { data: 'player', title: 'Player' },
                { data: 'award', title: 'Award' },
                { data: 'rank', title: 'Rank', className: 'dt-center' },
                { data: 'date', title: 'Date' },
                { data: 'park', title: 'Park' }
            ];
        } else if (currentDataset === 'attendance') {
            dtCols = [
                { data: 'player', title: 'Player' },
                { data: 'class_played', title: 'Class' },
                { data: 'date', title: 'Date' },
                { data: 'credits', title: 'Credits', className: 'dt-center' },
                { data: 'park', title: 'Park' },
                { data: 'event_name', title: 'Event' }
            ];
        } else if (currentDataset === 'players') {
            dtCols = [
                { data: 'player', title: 'Persona' },
                { data: 'given_name', title: 'Given Name' },
                { data: 'park', title: 'Park' },
                { data: 'active_status', title: 'Active' },
                { data: 'waiver_status', title: 'Waivered' },
                { data: 'year_joined', title: 'Year Joined' }
            ];
        }

        if (drillTable) { drillTable.destroy(); drillTable = null; }
        gid('sd-drill-table').innerHTML = '';
        drillTable = $('#sd-drill-table').DataTable({
            data: filtered,
            columns: dtCols,
            pageLength: 25,
            scrollX: true,
            dom: 'Bfrtip',
            buttons: [
                { extend: 'csv', filename: 'SliceDice_drilldown', exportOptions: { columns: ':visible' } }
            ],
            order: [[0, 'asc']]
        });

        gid('sd-overlay').classList.add('sd-visible');
    });

    /* ── Modal close ── */
    gid('sd-modal-close').addEventListener('click', function() { gid('sd-overlay').classList.remove('sd-visible'); });
    gid('sd-overlay').addEventListener('click', function(e) { if (e.target === this) this.classList.remove('sd-visible'); });

    /* ── Clear filters ── */
    gid('sd-btn-clear').addEventListener('click', function() {
        if (currentDataset) buildFilters(currentDataset);
    });

})();
</script>
