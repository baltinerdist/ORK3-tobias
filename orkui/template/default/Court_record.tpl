<?php
/**
 * Record Court — the catch-up pass (spec §5). Reachable from the court hero
 * only when a plan is published; reads back the paper Court Record sheet in
 * screen form, in the same column order: # · check · x · Recipient · Award ·
 * Rank · Given by · PTL. This file carries the shell + top strip (Task 6);
 * Task 7 fills #cp-rec-rows with the per-row controls and walk-on row.
 *
 * Deliberately a separate file from Court_detail.tpl (already ~4,700 lines)
 * even though it reuses the same cp- visual language, so the two surfaces
 * read as one tool without becoming one unmanageable file.
 */
$court          = $Court          ?? [];
$courtAwards    = $CourtAwards    ?? [];
$giverOptions   = $GiverOptions   ?? ['default' => null, 'pills' => []];
$upcomingEvents = $UpcomingEvents ?? [];
$courtMode      = $CourtMode      ?? 'run';
$error          = $Error          ?? '';

$courtId = (int)($court['CourtId'] ?? 0);
$courtSt = $court['Status'] ?? 'draft';

$statusLabel      = ['draft' => 'Draft', 'published' => 'Published', 'complete' => 'Complete'];
$statusBadgeClass = ['draft' => 'cp-badge-draft', 'published' => 'cp-badge-published', 'complete' => 'cp-badge-complete'];

// Initial staged-safeguard count (spec §5.3), computed from the same CourtAwards
// payload the JS globals below carry — every mark is a real server write the
// moment it happens (spec §5), so this count is exact at render time. The
// server render defaults to "plan" phrasing (mirrors Court_detail.tpl's own
// comment on this); cpUpdateStagedIndicator() normalizes it to the true mode
// on load, same idiom as the planner.
$initialStagedCount = 0;
foreach ($courtAwards as $__a) {
    if (($__a['Status'] ?? '') === 'staged') {
        $initialStagedCount++;
    }
}
unset($__a);
?>
<link rel="stylesheet" href="<?= HTTP_TEMPLATE ?>default/style/court-planner.css?v=<?= filemtime(DIR_TEMPLATE . 'default/style/court-planner.css') ?>">
<link rel="stylesheet" href="<?= HTTP_TEMPLATE ?>revised-frontend/style/rank-pill.css?v=<?= filemtime(DIR_TEMPLATE . 'revised-frontend/style/rank-pill.css') ?>">
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/flatpickr/dist/flatpickr.min.css">
<script src="https://cdn.jsdelivr.net/npm/flatpickr"></script>
<style>
/* Page-specific rules only — the shell, hero, buttons, badges, modals,
   autocomplete, tracking icons, toast, mode badge, staged-count indicator and
   Finalize/Complete modal all come from the shared
   default/style/court-planner.css (linked below), which Court_detail.tpl
   also links. Nothing in this block should duplicate a cp-* rule that already
   lives there. */

/* ---- Record Court top strip (spec §5: "top strip — court date, event, and
   default giver — edited through the new update_court endpoint"). The court's
   own date, event link, and recorder are the persisted, update_court-backed
   fields (0.1/0.7); this strip surfaces them as inline edit-in-place controls
   instead of a modal, since correcting them IS the catch-up pass. ---- */
.cp-rec-topstrip { display: flex; flex-wrap: wrap; align-items: flex-end; gap: 16px; background: #fff; border: 1px solid #e2e8f0; border-radius: 8px; padding: 14px 16px; margin-bottom: 16px; }
.cp-rec-strip-field { flex: 1 1 200px; min-width: 160px; }
.cp-rec-strip-field label { display: block; font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: .4px; color: #718096; margin-bottom: 4px; }
.cp-rec-strip-field input,
.cp-rec-strip-field select { width: 100%; padding: 8px 10px; border: 1px solid #cbd5e0; border-radius: 5px; font-size: 14px; box-sizing: border-box; min-height: 38px; }
.cp-rec-strip-status { flex: 0 0 auto; font-size: 12px; color: #718096; min-width: 70px; padding-bottom: 9px; }
.cp-rec-strip-status.cp-rec-strip-saved { color: #276749; font-weight: 600; }
.cp-rec-strip-status.cp-rec-strip-error { color: #c53030; font-weight: 600; }
html[data-theme="dark"] .cp-rec-topstrip { background: #161b22; border-color: #2d3748; }
html[data-theme="dark"] .cp-rec-strip-field label { color: #97a3b4; }
html[data-theme="dark"] .cp-rec-strip-field input,
html[data-theme="dark"] .cp-rec-strip-field select { background: #1f2733; border-color: #2d3748; color: #e2e8f0; }
html[data-theme="dark"] .cp-rec-strip-status { color: #97a3b4; }
html[data-theme="dark"] .cp-rec-strip-status.cp-rec-strip-saved { color: #68d391; }
html[data-theme="dark"] .cp-rec-strip-status.cp-rec-strip-error { color: #fc8181; }

/* Lean hero-actions row for this view (no heraldry, fewer buttons than the planner). */
.cp-rec-hero-actions { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }

/* Placeholder container Task 7 fills with per-row Given/Skipped/— controls,
   Given-by chips, rank pills, citation editors, and the walk-on row. */
#cp-rec-rows:empty::before {
    content: 'Rows load here once Task 7 ships.';
    display: block;
    padding: 30px 16px;
    text-align: center;
    color: #a0aec0;
    font-size: 13px;
    border: 1px dashed #cbd5e0;
    border-radius: 8px;
}
html[data-theme="dark"] #cp-rec-rows:empty::before { color: #718096; border-color: #2d3748; }

@media (max-width: 600px) {
    .cp-rec-topstrip { flex-direction: column; align-items: stretch; gap: 12px; padding: 14px; }
    .cp-rec-strip-field { flex: 1 1 auto; min-width: 0; }
    /* House rule: >=44px hit area via padding, not larger glyphs. .cp-field's base
       8px vertical padding leaves these at ~38px on a 14px input; pad up, don't
       just embiggen the text. This is the one fix of the original three that
       does NOT propagate to court-planner.css: .cp-rec-strip-field doesn't
       exist on Court_detail.tpl, so there is nothing there to fix. The other
       two (.cp-si-btn, .cp-back) are shared classes and now live in
       court-planner.css's own 600px block instead of being duplicated here. */
    .cp-rec-strip-field input,
    .cp-rec-strip-field select { min-height: 44px; padding-top: 12px; padding-bottom: 12px; box-sizing: border-box; }
    .cp-rec-strip-status { padding-bottom: 0; }
    .cp-rec-hero-actions { width: 100%; }
    .cp-rec-hero-actions > a,
    .cp-rec-hero-actions > button { flex: 1 1 auto; min-height: 44px; justify-content: center; }
}
</style>

<?php if ($error): ?>
<div style="padding:24px">
    <div class="cp-error-box">
        <i class="fas fa-exclamation-circle"></i> <?= htmlspecialchars($error) ?>
    </div>
</div>
<?php else: ?>

<div class="cp-page" style="padding-top:0;padding-bottom:0;margin-bottom:0">

    <div class="cp-hero-back-row">
        <a class="cp-back" href="<?= UIR ?>Court/detail/<?= $courtId ?>" style="color:#4a5568">
            <i class="fas fa-arrow-left"></i> Back to Planner
        </a>
    </div>

    <!-- Hero: name, date, mode badge — a lean read-only summary. The editable
         date/event/recorder live in the top strip below (spec §5). -->
    <div class="cp-hero" id="cp-hero">
        <div class="cp-hero-content">
            <div class="cp-hero-info">
                <div class="cp-hero-supertitle">
                    <?php if (($court['ParkId'] ?? 0) > 0 && !empty($court['ParkName'])): ?>
                    <?= htmlspecialchars($court['ParkName']) ?> &bull;
                    <?php endif; ?>
                    <?= htmlspecialchars($court['KingdomName'] ?? '') ?>
                </div>
                <h1 class="cp-hero-name"><?= htmlspecialchars($court['Name'] ?? '') ?></h1>
                <div class="cp-hero-meta">
                    <?php if (!empty($court['CourtDate'])): ?>
                    <span><i class="fas fa-calendar"></i><?= date('l, F j, Y', strtotime($court['CourtDate'])) ?></span>
                    <?php endif; ?>
                    <?php if (!empty($court['EventName'])): ?>
                    <span><i class="fas fa-flag"></i><?= htmlspecialchars($court['EventName']) ?></span>
                    <?php endif; ?>
                </div>
            </div>
            <div class="cp-hero-actions">
                <div class="cp-rec-hero-actions">
                    <span class="cp-badge <?= $statusBadgeClass[$courtSt] ?? 'cp-badge-draft' ?>" id="cp-rec-status-badge">
                        <?= $statusLabel[$courtSt] ?? $courtSt ?>
                    </span>
                    <?php if (in_array($courtSt, ['published', 'complete'], true)): ?>
                    <span class="cp-mode-badge <?= $courtMode === 'plan' ? 'cp-mode-plan' : 'cp-mode-run' ?>" id="cp-rec-mode-badge">
                        <i class="fas fa-<?= $courtMode === 'plan' ? 'clipboard-list' : 'bullhorn' ?>"></i>
                        <?= $courtMode === 'plan' ? 'Plan' : 'Run at Court' ?>
                    </span>
                    <?php endif; ?>
                </div>
                <?php if ($courtSt !== 'complete'): ?>
                <button class="cp-btn-primary" onclick="cpOpenCompleteModal()" data-tip="Nothing reaches the permanent record until this runs">
                    <i class="fas fa-stamp"></i> Finalize &amp; Complete
                </button>
                <?php endif; ?>
            </div>
        </div>
    </div>

    <!-- Top strip (spec §5): court date, event, and recorder — the same three
         fields 0.1/0.7 made editable via CourtAjax/update_court, surfaced here
         as inline edit-in-place controls rather than the planner's modal. -->
    <div class="cp-rec-topstrip" id="cp-rec-topstrip">
        <div class="cp-rec-strip-field">
            <label for="cp-rec-date">Court Date</label>
            <input type="text" id="cp-rec-date" placeholder="Select a date…" autocomplete="off"
                   <?= $courtSt === 'complete' ? 'disabled' : '' ?>>
        </div>
        <?php if (!empty($upcomingEvents)): ?>
        <div class="cp-rec-strip-field">
            <label for="cp-rec-event">Event</label>
            <select id="cp-rec-event" onchange="cpRecSaveField({EventCalendarDetailId: this.value})"
                    <?= $courtSt === 'complete' ? 'disabled' : '' ?>>
                <option value="0">&mdash; None &mdash;</option>
                <?php foreach ($upcomingEvents as $ev): ?>
                <option value="<?= (int)$ev['EventCalendarDetailId'] ?>"
                    <?= ((int)$ev['EventCalendarDetailId'] === (int)($court['EventCalendarDetailId'] ?? 0)) ? 'selected' : '' ?>>
                    <?= htmlspecialchars($ev['Name']) ?><?= $ev['EventStart'] ? ' (' . date('M j', strtotime($ev['EventStart'])) . ')' : '' ?>
                </option>
                <?php endforeach; ?>
            </select>
        </div>
        <?php endif; ?>
        <div class="cp-rec-strip-field">
            <label for="cp-rec-recorder-text">Recorder <span style="font-weight:400;text-transform:none;letter-spacing:0"> — who records this court's grants</span></label>
            <div class="cp-ac-wrap">
                <input type="text" id="cp-rec-recorder-text" placeholder="Search player name…" autocomplete="off"
                       value="<?= htmlspecialchars($court['RecorderPersona'] ?? '') ?>"
                       oninput="cpAcSearch(this,'cp-rec-recorder-ac','cp-rec-recorder-id',cpRecRecorderPick)"
                       onblur="cpRecRecorderBlur()"
                       <?= $courtSt === 'complete' ? 'disabled' : '' ?>>
                <div class="cp-ac-dropdown" id="cp-rec-recorder-ac"></div>
            </div>
            <input type="hidden" id="cp-rec-recorder-id" value="<?= (int)($court['RecorderMundaneId'] ?? 0) ?>">
        </div>
        <span class="cp-rec-strip-status" id="cp-rec-strip-status" role="status" aria-live="polite"></span>
    </div>

    <!-- Unfinalized-staged safeguard indicator (spec §5.3) — same idiom as the
         planner's #cp-staged-indicator, reused so the running total is visible
         while marking (Task 7 calls cpUpdateStagedIndicator() as rows are
         marked; every mark is a real server write the moment it happens). -->
    <div class="cp-staged-indicator<?= ($initialStagedCount > 0 && $courtSt !== 'complete') ? ' show' : '' ?>" id="cp-staged-indicator" role="status" aria-live="polite">
        <i class="fas fa-hourglass-half cp-si-icon"></i>
        <span class="cp-si-text"><strong><span id="cp-staged-count-n"><?= $initialStagedCount ?></span> grant<span id="cp-staged-count-s"><?= $initialStagedCount === 1 ? '' : 's' ?></span> staged</strong>, not yet finalized — Finalize to record them in the player registry.</span>
        <button class="cp-si-btn" onclick="cpOpenCompleteModal()"><i class="fas fa-stamp"></i> Finalize &amp; Complete</button>
    </div>

    <!-- Task 7 fills this with the per-row Given/Skipped/— controls (same
         column order as the paper: # · check · x · Recipient · Award · Rank ·
         Given by · PTL) and the walk-on inline row. -->
    <div id="cp-rec-rows"></div>

</div>

<!-- Finalize & Complete modal — identical flow to the planner's (spec §6.6). -->
<div class="cp-overlay" id="cp-complete-modal">
    <div class="cp-modal cp-modal-sm" role="dialog" aria-modal="true" aria-labelledby="cp-complete-modal-title">
        <div class="cp-modal-header">
            <h3 id="cp-complete-modal-title"><i class="fas fa-stamp" style="margin-right:8px;color:#276749"></i>Complete Court</h3>
            <button class="cp-modal-close" onclick="cpCloseCompleteModal()" aria-label="Close">&times;</button>
        </div>
        <div class="cp-modal-body">
            <p class="cp-modal-lead" id="cp-complete-lead"></p>
            <div class="cp-complete-opts" id="cp-complete-opts"></div>
            <div class="cp-complete-fail" id="cp-complete-fail"></div>
        </div>
        <div class="cp-modal-footer">
            <button class="cp-btn-outline" onclick="cpCloseCompleteModal()">Go Back</button>
        </div>
    </div>
</div>

<?php endif; ?>
<?php if (!$error): ?>
<script>
(function() {
    var uir      = '<?= UIR ?>';
    var courtId  = <?= $courtId ?>;
    var kidId    = <?= (int)($court['KingdomId'] ?? 0) ?>;
    var courtStatus = <?= json_encode($courtSt) ?>;

    // Same JS globals Court_detail.tpl emits, so Tasks 7-10 reuse its idioms
    // rather than inventing new ones. courtId is exported explicitly — a
    // sibling file once left this off and every later call site that reached
    // for window.courtId silently posted CourtId=undefined.
    window.courtId     = courtId;
    var courtAwards     = window.courtAwards = <?= json_encode($courtAwards) ?>;
    var courtMeta        = window.courtMeta   = {
        name: <?= json_encode($court['Name'] ?? '') ?>,
        date: <?= json_encode($court['CourtDate'] ?? '') ?>,
        eventId: <?= (int)($court['EventCalendarDetailId'] ?? 0) ?>,
        eventName: <?= json_encode($court['EventName'] ?? '') ?>,
        recorderId: <?= (int)($court['RecorderMundaneId'] ?? 0) ?>,
        recorderPersona: <?= json_encode($court['RecorderPersona'] ?? '') ?>
    };
    var cpGiverOptions = window.cpGiverOptions = <?= json_encode($giverOptions) ?>;
    var cpMode          = window.cpMode        = <?= json_encode($courtMode) ?>;
    var cpStagedCount    = window.cpStagedCount = <?= $initialStagedCount ?>;

    // ---- Utilities (mirrors Court_detail.tpl's own copies) ----
    function esc(s) {
        return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
    }
    window.esc = esc;
    function gid(id) { return document.getElementById(id); }

    function cpGlobalError(msg) {
        var t = document.createElement('div');
        t.className = 'cp-toast';
        t.setAttribute('role', 'alert');
        t.setAttribute('aria-live', 'assertive');
        t.textContent = msg || 'Something went wrong. Please try again.';
        document.body.appendChild(t);
        setTimeout(function() { t.remove(); }, 5000);
    }
    window.cpGlobalError = cpGlobalError;

    // Non-blocking message/confirm dialogs — no native alert()/confirm()/prompt()
    // anywhere; those freeze in-app browser automation.
    function cpAlert(msg, title) {
        if (typeof tnConfirm === 'function') tnConfirm({ title: title || 'Court Planner', body: msg, confirmLabel: 'OK' });
        else cpGlobalError(msg);
    }
    window.cpAlert = cpAlert;

    function cpFallbackConfirm(opts) {
        opts = opts || {};
        var ov = document.createElement('div');
        ov.className = 'cp-overlay';
        ov.style.display = 'flex';
        ov.setAttribute('role', 'dialog');
        ov.setAttribute('aria-modal', 'true');
        ov.innerHTML =
            '<div class="cp-modal cp-modal-sm">' +
              '<div class="cp-modal-header"><h3>' + esc(opts.title || 'Confirm') + '</h3>' +
                '<button class="cp-modal-close" type="button" aria-label="Close" data-cp-cancel>&times;</button></div>' +
              '<div class="cp-modal-body"><p class="cp-modal-lead">' + esc(opts.body || '') + '</p></div>' +
              '<div class="cp-modal-footer">' +
                '<button class="cp-btn-outline" type="button" data-cp-cancel>' + esc(opts.cancelLabel || 'Cancel') + '</button>' +
                '<button class="cp-btn-primary" type="button" data-cp-ok' + (opts.danger ? ' style="background:#c53030"' : '') + '>' + esc(opts.confirmLabel || 'OK') + '</button>' +
              '</div>' +
            '</div>';
        function close() { ov.remove(); }
        ov.addEventListener('click', function(e) {
            if (e.target === ov || e.target.closest('[data-cp-cancel]')) { close(); return; }
            if (e.target.closest('[data-cp-ok]')) { close(); if (typeof opts.onConfirm === 'function') opts.onConfirm(); }
        });
        document.body.appendChild(ov);
        var okBtn = ov.querySelector('[data-cp-ok]');
        if (okBtn) setTimeout(function() { okBtn.focus(); }, 30);
    }
    function cpConfirm(opts) {
        if (typeof tnConfirm === 'function') tnConfirm(opts);
        else cpFallbackConfirm(opts);
    }
    window.cpConfirm = cpConfirm;

    function post(url, fd, silent) {
        return fetch(uir + url, {
            method: 'POST', body: fd,
            headers: { 'X-Requested-With': 'XMLHttpRequest' }
        }).then(function(r) {
            if (!r.ok) throw new Error('HTTP ' + r.status);
            return r.json();
        }).catch(function(err) {
            if (!silent) cpGlobalError('Could not reach the server. Please check your connection and try again.');
            return { status: -1, error: 'Request failed. Please try again.', _postFailed: true };
        });
    }
    window.cpPost = post;

    // ---- Scroll lock (identical idiom to Court_detail.tpl) ----
    var cpPrevRootOverflow = null;
    function cpSyncScrollLock() {
        var open = false;
        document.querySelectorAll('.cp-overlay[id]').forEach(function(o) {
            if (o.style.display === 'flex') open = true;
        });
        var root = document.documentElement;
        if (open) {
            if (cpPrevRootOverflow === null) {
                cpPrevRootOverflow = root.style.overflowY;
                root.style.overflowY = 'hidden';
            }
        } else if (cpPrevRootOverflow !== null) {
            root.style.overflowY = cpPrevRootOverflow;
            cpPrevRootOverflow = null;
        }
    }

    // ---- Autocomplete (identical idiom to Court_detail.tpl's cpAcSearch, plus
    // an optional onPick callback so a strip field can auto-save on pick — the
    // hidden id clears on every keystroke, so saving on blur alone would post
    // a stale/empty id before the click that fills it back in ever lands). ----
    function cpPositionAc(input, drop) {
        var vv = window.visualViewport;
        var vh = vv ? vv.height : window.innerHeight;
        var vw = vv ? vv.width  : window.innerWidth;
        var r  = input.getBoundingClientRect();
        drop.style.width   = r.width + 'px';
        drop.style.display = 'block';
        var dh = drop.offsetHeight;
        var dw = drop.offsetWidth || r.width;
        var top = r.bottom + 2;
        if (top + dh > vh - 8) top = r.top - dh - 2;
        var left = r.left;
        if (left + dw > vw - 8) left = vw - dw - 8;
        drop.style.top  = Math.max(8, top)  + 'px';
        drop.style.left = Math.max(8, left) + 'px';
        cpAcBind(drop);
    }
    var cpAcOpenDrop = null;
    function cpAcDismiss(e) {
        if (e && e.target && cpAcOpenDrop && e.target.nodeType === 1 &&
            (e.target === cpAcOpenDrop || cpAcOpenDrop.contains(e.target))) return;
        if (cpAcOpenDrop) cpAcOpenDrop.style.display = 'none';
        cpAcUnbind();
    }
    function cpAcBind(drop) {
        if (cpAcOpenDrop === drop) return;
        cpAcUnbind();
        cpAcOpenDrop = drop;
        window.addEventListener('scroll', cpAcDismiss, true);
        window.addEventListener('resize', cpAcDismiss);
        if (window.visualViewport) {
            window.visualViewport.addEventListener('resize', cpAcDismiss);
            window.visualViewport.addEventListener('scroll', cpAcDismiss);
        }
    }
    function cpAcUnbind() {
        if (!cpAcOpenDrop) return;
        cpAcOpenDrop = null;
        window.removeEventListener('scroll', cpAcDismiss, true);
        window.removeEventListener('resize', cpAcDismiss);
        if (window.visualViewport) {
            window.visualViewport.removeEventListener('resize', cpAcDismiss);
            window.visualViewport.removeEventListener('scroll', cpAcDismiss);
        }
    }
    function cpHideAcDropdowns(except) {
        document.querySelectorAll('.cp-ac-dropdown').forEach(function(d) {
            if (except && d.parentElement && d.parentElement.contains(except)) return;
            d.style.display = 'none';
            if (!except) d.innerHTML = '';
        });
        if (cpAcOpenDrop && cpAcOpenDrop.style.display === 'none') cpAcUnbind();
    }

    var cpAcTimer = null;
    // Scoped to this court's own kingdom (KingdomAjax/playersearch/{kidId}), never
    // the session's — the recorder search must find players in the COURT's kingdom.
    window.cpAcSearch = function(input, dropdownId, hiddenId, onPick) {
        var q = input.value.trim();
        var drop = gid(dropdownId);
        gid(hiddenId).value = '';
        if (q.length < 2) { drop.style.display = 'none'; drop.innerHTML = ''; if (cpAcOpenDrop === drop) cpAcUnbind(); return; }
        clearTimeout(cpAcTimer);
        cpAcTimer = setTimeout(function() {
            fetch(uir + 'KingdomAjax/playersearch/' + kidId + '&q=' + encodeURIComponent(q))
            .then(function(r) { return r.json(); })
            .then(function(data) {
                drop.innerHTML = '';
                if (!data || !data.length) {
                    drop.innerHTML = '<div class="cp-ac-item" style="color:#a0aec0;cursor:default">No players found</div>';
                    cpPositionAc(input, drop);
                    drop.style.display = 'block';
                    return;
                }
                data.slice(0, 12).forEach(function(p) {
                    var div = document.createElement('div');
                    div.className = 'cp-ac-item';
                    div.innerHTML = esc(p.Persona) + ' <span style="color:#a0aec0;font-size:11px">(' + esc(p.KAbbr || '') + ':' + esc(p.PAbbr || '') + ')</span>';
                    div.addEventListener('click', function() {
                        input.value = p.Persona;
                        gid(hiddenId).value = p.MundaneId;
                        drop.style.display = 'none';
                        if (cpAcOpenDrop === drop) cpAcUnbind();
                        if (typeof onPick === 'function') onPick(p);
                    });
                    drop.appendChild(div);
                });
                cpPositionAc(input, drop);
                drop.style.display = 'block';
            })
            .catch(function() { drop.style.display = 'none'; if (cpAcOpenDrop === drop) cpAcUnbind(); });
        }, 200);
    };

    // ---- Top strip: date / event / recorder, each posting to CourtAjax/update_court
    // (spec §5, §3 0.1). Partial by design — only the changed field is sent, and a
    // save where nothing actually differs still reports success (Court::updateCourt
    // reads the row back rather than trusting changed-row count), so this never
    // raises an error toast for a no-op save. ----
    window.cpRecSaveField = function(fields) {
        var status = gid('cp-rec-strip-status');
        var fd = new FormData();
        fd.append('CourtId', courtId);
        Object.keys(fields).forEach(function(k) { fd.append(k, fields[k]); });
        if (status) { status.textContent = 'Saving…'; status.className = 'cp-rec-strip-status'; }
        post('CourtAjax/update_court', fd, true).then(function(d) {
            if (d.status === 0) {
                if ('CourtDate' in fields) courtMeta.date = fields.CourtDate;
                if ('EventCalendarDetailId' in fields) courtMeta.eventId = parseInt(fields.EventCalendarDetailId, 10) || 0;
                if ('RecorderMundaneId' in fields) courtMeta.recorderId = parseInt(fields.RecorderMundaneId, 10) || 0;
                if (status) {
                    status.textContent = 'Saved';
                    status.className = 'cp-rec-strip-status cp-rec-strip-saved';
                    setTimeout(function() { if (status.textContent === 'Saved') status.textContent = ''; }, 2500);
                }
            } else if (status) {
                status.textContent = d.error || 'Could not save.';
                status.className = 'cp-rec-strip-status cp-rec-strip-error';
            }
        });
    };

    window.cpRecRecorderPick = function(p) {
        cpRecSaveField({ RecorderMundaneId: p.MundaneId });
    };
    // cpAcSearch clears the hidden id on every keystroke (see comment above), so a
    // blur that merely follows a touch-then-leave of the prefilled box must not post
    // 0 and clear the recorder. Only save-to-clear when the box was deliberately
    // emptied; a typed-but-unpicked value is left untouched, same rule the planner's
    // Edit Details modal uses for this exact field.
    window.cpRecRecorderBlur = function() {
        var id  = gid('cp-rec-recorder-id').value;
        var txt = gid('cp-rec-recorder-text').value.trim();
        if (!id && !txt) {
            cpRecSaveField({ RecorderMundaneId: 0 });
        }
    };

    var cpRecFp = flatpickr('#cp-rec-date', {
        dateFormat: 'Y-m-d', altInput: true, altFormat: 'F j, Y', allowInput: true,
        onClose: function(selectedDates, dateStr) {
            if (dateStr !== (courtMeta.date || '')) {
                cpRecSaveField({ CourtDate: dateStr });
            }
        }
    });
    cpRecFp.setDate(courtMeta.date || null, false);

    // ---- Complete-court modal (identical flow to Court_detail.tpl's, spec §6.6) ----
    window.cpOpenCompleteModal = function() {
        var unresolved = 0, staged = 0;
        courtAwards.forEach(function(a) {
            if (a.Status === 'planned' || a.Status === 'announced') unresolved++;
            else if (a.Status === 'staged') staged++;
        });
        var lead = gid('cp-complete-lead');
        var opts = gid('cp-complete-opts');
        var fail = gid('cp-complete-fail');
        fail.style.display = 'none'; fail.innerHTML = '';
        opts.innerHTML = '';
        if (unresolved > 0) {
            lead.innerHTML = '<strong>' + unresolved + '</strong> award' + (unresolved === 1 ? ' is' : 's are') +
                ' still unresolved (not granted or skipped)' +
                (staged > 0 ? ', and <strong>' + staged + '</strong> grant' + (staged === 1 ? ' is' : 's are') + ' staged to finalize' : '') +
                '. How would you like to complete this court?';
            opts.innerHTML =
                '<div class="cp-complete-opt cp-co-danger" onclick="cpDoFinalize(1)"><i class="fas fa-forward"></i><div>' +
                    '<div class="cp-co-title">Skip Remaining Awards</div>' +
                    '<div class="cp-co-desc">Mark the ' + unresolved + ' unresolved award' + (unresolved === 1 ? '' : 's') + ' as skipped, then finalize the staged grants and complete.</div></div></div>' +
                '<div class="cp-complete-opt cp-co-neutral" onclick="cpDoFinalize(0)"><i class="fas fa-check"></i><div>' +
                    '<div class="cp-co-title">Leave As-Is and Close</div>' +
                    '<div class="cp-co-desc">Finalize the staged grants and complete. Unresolved awards are left untouched and resurface on the next court.</div></div></div>';
        } else if (staged > 0) {
            lead.innerHTML = 'Finalize <strong>' + staged + '</strong> staged grant' + (staged === 1 ? '' : 's') +
                ' and complete this court? This records ' + (staged === 1 ? 'it' : 'them') + ' in the player registry.';
            opts.innerHTML =
                '<div class="cp-complete-opt cp-co-primary" onclick="cpDoFinalize(0)"><i class="fas fa-stamp"></i><div>' +
                    '<div class="cp-co-title">Finalize &amp; Complete</div>' +
                    '<div class="cp-co-desc">Commit ' + staged + ' staged grant' + (staged === 1 ? '' : 's') + ' to the permanent record and mark the court complete.</div></div></div>';
        } else {
            lead.innerHTML = 'There are no staged grants or unresolved awards. Mark this court complete?';
            opts.innerHTML =
                '<div class="cp-complete-opt cp-co-primary" onclick="cpDoFinalize(0)"><i class="fas fa-check"></i><div>' +
                    '<div class="cp-co-title">Complete Court</div>' +
                    '<div class="cp-co-desc">Close out this court.</div></div></div>';
        }
        gid('cp-complete-modal').style.display = 'flex';
        cpSyncScrollLock();
    };
    window.cpCloseCompleteModal = function() {
        var m = gid('cp-complete-modal'); if (m) m.style.display = 'none';
        cpSyncScrollLock();
    };
    window.cpDoFinalize = function(skipRemaining) {
        var opts = gid('cp-complete-opts');
        function lockOpts(on) {
            opts.querySelectorAll('.cp-complete-opt').forEach(function(o) {
                o.style.pointerEvents = on ? 'none' : '';
                o.style.opacity = on ? '.6' : '';
            });
        }
        lockOpts(true);
        var fd = new FormData();
        fd.append('CourtId', courtId);
        fd.append('SkipRemaining', skipRemaining ? 1 : 0);
        post('CourtAjax/finalize_court', fd).then(function(d) {
            if (d._postFailed) { lockOpts(false); return; }
            if (d.status !== 0) {
                var f = gid('cp-complete-fail');
                f.textContent = d.error || 'Could not finalize.';
                f.style.display = 'block';
                lockOpts(false);
                return;
            }
            var dupes = (d.duplicates || []).length;
            if (d.completed) {
                if (dupes) {
                    cpAlert(dupes + ' award line' + (dupes === 1 ? ' was' : 's were') +
                        ' skipped because the same recipient, award and rank had already been ' +
                        'granted by another line in this court — the honor is recorded once.',
                        'Duplicate lines skipped');
                }
                location.reload();
                return;
            }
            var f = gid('cp-complete-fail');
            var msg = '<strong>' + (d.committed || 0) + ' grant' + (d.committed === 1 ? '' : 's') + ' recorded</strong>' +
                (dupes ? ', ' + dupes + ' duplicate line' + (dupes === 1 ? '' : 's') + ' skipped' : '') + ', but ' +
                (d.failed ? d.failed.length : 0) + ' could not be committed and remain staged:';
            msg += '<ul style="margin:6px 0 0;padding-left:18px">';
            (d.failed || []).forEach(function(fl) {
                var a = courtAwards.find(function(x) { return String(x.CourtAwardId) === String(fl.court_award_id); });
                var who = a ? (a.Persona + ' — ' + a.AwardName) : ('Award #' + fl.court_award_id);
                msg += '<li>' + esc(who) + ': ' + esc(fl.error || 'error') + '</li>';
            });
            msg += '</ul>';
            f.innerHTML = msg;
            f.style.display = 'block';
            lockOpts(false);
        });
    };

    // Same idiom as Court_detail.tpl: normalizes the staged-safeguard banner's
    // wording to the current mode on load, and gives Task 7 a ready call site
    // to update the running total as rows are marked Given/Skipped.
    window.cpUpdateStagedIndicator = function(count) {
        cpStagedCount = window.cpStagedCount = count;
        var ind = gid('cp-staged-indicator');
        if (!ind) return;
        var txt = ind.querySelector('.cp-si-text');
        var btn = ind.querySelector('.cp-si-btn');
        var plural = count === 1 ? '' : 's';
        if (txt) {
            if (cpMode === 'plan') {
                txt.innerHTML = '<strong>' + count + ' grant' + plural + ' staged</strong>, not yet finalized — ' +
                    'Finalize to record them in the player registry.';
            } else {
                txt.innerHTML = '<strong>' + count + ' to record on Complete</strong> — ' +
                    'these grants are written to the player registry when you complete this court.';
            }
        }
        if (btn) {
            btn.innerHTML = cpMode === 'plan'
                ? '<i class="fas fa-stamp"></i> Finalize &amp; Complete'
                : '<i class="fas fa-check"></i> Complete Court';
        }
        ind.classList.toggle('show', count > 0 && courtStatus !== 'complete');
    };
    cpUpdateStagedIndicator(cpStagedCount);

    // Close dropdowns on outside click; close the complete modal on backdrop
    // click / Escape (same idiom as Court_detail.tpl).
    document.addEventListener('click', function(e) { cpHideAcDropdowns(e.target); });
    var cpModal = gid('cp-complete-modal');
    if (cpModal) {
        cpModal.addEventListener('click', function(e) {
            if (e.target !== this) return;
            this.style.display = 'none';
            cpHideAcDropdowns();
            cpSyncScrollLock();
        });
    }
    document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape') {
            var m = gid('cp-complete-modal'); if (m) m.style.display = 'none';
            cpHideAcDropdowns();
            cpSyncScrollLock();
        }
    });
})();
</script>
<?php endif; ?>
