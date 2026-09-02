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

/* ---- Row list (spec §5.1) — per-row marks, same column order as the printed
   Sheet 2: # · Recipient · Award · Rank · [mark] · Given by · PTL. The paper's
   separate check/x columns collapse into one three-state control here. Every
   mark is a real server write the moment it's made (CourtAjax/grant_award,
   skip_award, unstage_award) — nothing here batches client-side. ---- */
.cp-rec-toolbar { display: flex; align-items: center; gap: 12px; flex-wrap: wrap; margin-bottom: 14px; }
.cp-rec-toolbar-hint { flex: 1 1 240px; font-size: 12px; color: #718096; }
/* House rule: no interactive target under 44px, checked at 390 AND 768 — not just
   the <=600px stacked layout. .cp-btn-primary's own padding lands at ~31px, so
   this must not be gated behind the mobile media query below. */
#cp-rec-bulk-btn { min-height: 44px; }
.cp-rec-empty { padding: 30px 16px; text-align: center; color: #a0aec0; font-size: 13px; border: 1px dashed #cbd5e0; border-radius: 8px; }
html[data-theme="dark"] .cp-rec-empty { color: #718096; border-color: #2d3748; }

.cp-rec-list { border: 1px solid #e2e8f0; border-radius: 8px; overflow: hidden; background: #fff; }
.cp-rec-row { display: flex; align-items: center; gap: 10px; padding: 10px 14px; border-bottom: 1px solid #edf2f7; }
.cp-rec-row:last-child { border-bottom: none; }
.cp-rec-row-header { background: #f7fafc; font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: .04em; color: #718096; }
.cp-rec-c-label { display: none; }
.cp-rec-c-num { flex: 0 0 26px; color: #a0aec0; font-size: 12px; }
.cp-rec-row-header .cp-rec-c-num { color: #718096; }
/* Fix round 1 / Finding 1: mark control sits right after # — same position as
   the paper's ✓/✕ columns (cpSheetRecord in Court_detail.tpl: # · ✓ · ✕ ·
   Recipient · Award · Rank · Given by · PTL). DOM order carries the visual
   order here (no flex `order` trick), so the header row and each data row's
   markup were both moved, not just this rule. */
.cp-rec-c-mark { flex: 0 0 auto; }
.cp-rec-c-recip { flex: 1 1 180px; min-width: 0; font-weight: 600; color: #1a202c; }
.cp-rec-park { font-size: 11px; color: #718096; font-weight: 400; margin-left: 4px; }
.cp-rec-c-award { flex: 1 1 200px; min-width: 0; }
.cp-rec-c-rank { flex: 0 0 84px; }
.cp-rec-c-giver { flex: 0 0 130px; font-size: 13px; color: #4a5568; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.cp-rec-c-ptl { flex: 0 0 30px; text-align: center; color: #718096; }
.cp-rec-row.cp-rec-row-given { background: #f0fff4; }
.cp-rec-row.cp-rec-row-skipped { background: #fff5f5; opacity: .8; }

.cp-rec-seg { display: inline-flex; border: 1px solid #cbd5e0; border-radius: 6px; overflow: hidden; }
.cp-rec-seg-btn { background: #fff; border: none; border-right: 1px solid #e2e8f0; padding: 0 12px; min-height: 44px; font-size: 12px; font-weight: 600; color: #4a5568; cursor: pointer; }
.cp-rec-seg-btn:last-child { border-right: none; }
.cp-rec-seg-btn:hover:not(:disabled) { background: #f7fafc; }
.cp-rec-seg-btn:disabled { cursor: not-allowed; opacity: .5; }
.cp-rec-row[data-mark="given"] .cp-rec-seg-given { background: #276749; color: #fff; }
.cp-rec-row[data-mark="skipped"] .cp-rec-seg-skipped { background: #c53030; color: #fff; }
.cp-rec-row[data-mark="none"] .cp-rec-seg-none { background: #edf2f7; color: #2d3748; }

/* ---- Given-by chip + rank chip (Task 8) — the row-level controls that open the
   two shared floating popovers below. Unconditional 44px (not gated behind
   pointer:coarse or the 600px block) — these are called out by name in the house
   mobile rules as the risk on this page, so the hit area is padding-driven and
   present at every width, checked at both 390 and 768. ---- */
.cp-rec-giver-chip { background: #edf2f7; border: 1px solid #cbd5e0; color: #2d3748; padding: 4px 10px; border-radius: 14px; font-size: 12px; font-weight: 600; cursor: pointer; max-width: 100%; min-height: 44px; box-sizing: border-box; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.cp-rec-giver-chip:hover:not(:disabled) { background: #e2e8f0; }
.cp-rec-giver-chip:disabled { cursor: not-allowed; opacity: .6; }
.cp-rec-giver-chip.cp-rec-chip-custom { background: #ebf8ff; border-color: #90cdf4; color: #2b6cb0; }
.cp-rec-rank-chip { cursor: pointer; min-height: 44px; box-sizing: border-box; display: inline-flex; align-items: center; }
.cp-rec-rank-chip:disabled { cursor: not-allowed; opacity: .6; }

/* Shared floating popover (giver + rank) — same fixed-position idiom as
   Court_detail.tpl's #cp-note-popup, positioned next to the chip that opened it. */
.cp-rec-pop { display: none; position: fixed; background: #fff; border: 1px solid #cbd5e0; border-radius: 8px; padding: 12px; width: 270px; max-width: calc(100vw - 20px); box-shadow: 0 6px 20px rgba(0,0,0,.18); z-index: 1150; }
.cp-rec-pop-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 8px; }
.cp-rec-pop-title { font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: .5px; color: #718096; }
.cp-rec-pop-close { background: none; border: none; color: #718096; cursor: pointer; font-size: 16px; line-height: 1; padding: 10px; margin: -10px; min-width: 44px; min-height: 44px; display: inline-flex; align-items: center; justify-content: center; }
.cp-rec-pop-close:hover { color: #2d3748; }
/* Popover pills get the same unconditional 44px — they're the giver/rank quick-picks
   called out by name in the house mobile rules. */
#cp-rec-giver-pop .cp-giver-pill,
#cp-rec-rank-pop .cp-rank-pill { min-height: 44px; box-sizing: border-box; display: inline-flex; align-items: center; justify-content: center; }
/* The rank digits (1..12) are narrow single/double-character labels — height alone
   isn't enough of a hit area, so give them an explicit minimum width too. */
#cp-rec-rank-pop .cp-rank-pill { min-width: 44px; padding-left: 0; padding-right: 0; }
.cp-rec-pop-apply-btn { display: none; align-items: center; justify-content: center; gap: 6px; width: 100%; margin-top: 10px; background: #edf2f7; border: 1px solid #cbd5e0; color: #2c5282; padding: 8px 10px; border-radius: 6px; font-size: 12px; font-weight: 600; cursor: pointer; min-height: 44px; box-sizing: border-box; }
.cp-rec-pop-apply-btn:hover { background: #e2e8f0; }
.cp-rec-pop-apply-btn.show { display: flex; }

html[data-theme="dark"] .cp-rec-list { background: #161b22; border-color: #2d3748; }
html[data-theme="dark"] .cp-rec-row { border-color: #22272e; }
html[data-theme="dark"] .cp-rec-row-header { background: #1a202c; color: #97a3b4; }
html[data-theme="dark"] .cp-rec-c-num { color: #718096; }
html[data-theme="dark"] .cp-rec-c-recip { color: #e2e8f0; }
html[data-theme="dark"] .cp-rec-park,
html[data-theme="dark"] .cp-rec-c-giver,
html[data-theme="dark"] .cp-rec-toolbar-hint { color: #97a3b4; }
html[data-theme="dark"] .cp-rec-row.cp-rec-row-given { background: rgba(39,103,73,.18); }
html[data-theme="dark"] .cp-rec-row.cp-rec-row-skipped { background: rgba(197,48,48,.14); }
html[data-theme="dark"] .cp-rec-seg { border-color: #2d3748; }
html[data-theme="dark"] .cp-rec-seg-btn { background: #1f2733; border-color: #2d3748; color: #cbd5e0; }
html[data-theme="dark"] .cp-rec-seg-btn:hover:not(:disabled) { background: #2d3748; }
html[data-theme="dark"] .cp-rec-row[data-mark="given"] .cp-rec-seg-given { background: #276749; color: #fff; }
html[data-theme="dark"] .cp-rec-row[data-mark="skipped"] .cp-rec-seg-skipped { background: #9b2c2c; color: #fff; }
html[data-theme="dark"] .cp-rec-row[data-mark="none"] .cp-rec-seg-none { background: #2d3748; color: #e2e8f0; }

html[data-theme="dark"] .cp-rec-giver-chip { background: #1f2733; border-color: #2d3748; color: #e2e8f0; }
html[data-theme="dark"] .cp-rec-giver-chip:hover:not(:disabled) { background: #2d3748; }
html[data-theme="dark"] .cp-rec-giver-chip.cp-rec-chip-custom { background: rgba(43,108,176,.22); border-color: #2b6cb0; color: #90cdf4; }
html[data-theme="dark"] .cp-rec-pop { background: #161b22; border-color: #2d3748; box-shadow: 0 6px 20px rgba(0,0,0,.5); }
html[data-theme="dark"] .cp-rec-pop-title { color: #97a3b4; }
html[data-theme="dark"] .cp-rec-pop-close { color: #718096; }
html[data-theme="dark"] .cp-rec-pop-close:hover { color: #e2e8f0; }
html[data-theme="dark"] .cp-rec-pop-apply-btn { background: #1f2733; border-color: #2d3748; color: #90cdf4; }
html[data-theme="dark"] .cp-rec-pop-apply-btn:hover { background: #2d3748; }

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

    /* Row list collapses to stacked cards — a table/flex-row layout at this width
       either overflows horizontally or forces sub-44px controls; neither is
       acceptable per the house mobile rules. */
    .cp-rec-toolbar { flex-direction: column; align-items: stretch; }
    #cp-rec-bulk-btn { justify-content: center; }
    .cp-rec-row-header { display: none; }
    .cp-rec-row { flex-wrap: wrap; row-gap: 8px; }
    .cp-rec-c-num { flex: 0 0 auto; }
    .cp-rec-c-recip,
    .cp-rec-c-award,
    .cp-rec-c-rank,
    .cp-rec-c-giver { flex: 1 1 100%; }
    .cp-rec-c-label { display: block; font-size: 10px; font-weight: 700; text-transform: uppercase; letter-spacing: .04em; color: #a0aec0; margin-bottom: 2px; }
    html[data-theme="dark"] .cp-rec-c-label { color: #718096; }
    .cp-rec-c-mark { flex: 1 1 100%; }
    .cp-rec-seg { width: 100%; }
    .cp-rec-seg-btn { flex: 1 1 33%; }
    .cp-rec-c-ptl { flex: 1 1 100%; text-align: left; display: flex; align-items: center; gap: 6px; }
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

    <!-- Per-row marks (spec §5.1) — same column order as the printed Sheet 2
         (# · check · x · Recipient · Award · Rank · Given by · PTL), with the
         paper's separate check/x columns collapsed into one three-state
         control. Every mark is a real server write the moment it's made
         (grant_award/skip_award/unstage_award) — nothing here batches
         client-side, so a recorder who closes the laptop mid-pass loses
         nothing. Walk-ons (Task 10) land below this list. -->
    <div id="cp-rec-rows">
        <div class="cp-rec-toolbar">
            <button type="button" class="cp-btn-primary" id="cp-rec-bulk-btn" onclick="cpRecMarkAllGiven()"
                    <?= $courtSt !== 'published' ? 'disabled' : '' ?>>
                <i class="fas fa-check-double"></i> Mark all remaining Given
            </button>
            <span class="cp-rec-toolbar-hint">Stages every still-planned award as Given under the default giver. Mark the exceptions — Skipped, or anything unusual — first, then use this for the rest. Safe to click again after adding walk-ons; it only ever touches rows still planned.</span>
        </div>

        <?php if (empty($courtAwards)): ?>
        <div class="cp-rec-empty">No awards on this court's plan.</div>
        <?php else: ?>
        <div class="cp-rec-list" id="cp-rec-list">
            <div class="cp-rec-row cp-rec-row-header" aria-hidden="true">
                <span class="cp-rec-c cp-rec-c-num">#</span>
                <span class="cp-rec-c cp-rec-c-mark">Mark</span>
                <span class="cp-rec-c cp-rec-c-recip">Recipient</span>
                <span class="cp-rec-c cp-rec-c-award">Award</span>
                <span class="cp-rec-c cp-rec-c-rank">Rank</span>
                <span class="cp-rec-c cp-rec-c-giver">Given by</span>
                <span class="cp-rec-c cp-rec-c-ptl">PTL</span>
            </div>
            <?php
            $canMark = $courtSt === 'published';
            foreach ($courtAwards as $__i => $aw):
                $caid = (int)($aw['CourtAwardId'] ?? 0);
                $mark = in_array($aw['Status'] ?? '', ['given', 'staged'], true) ? 'given'
                      : (($aw['Status'] ?? '') === 'cancelled' ? 'skipped' : 'none');
                $rowClass = $mark === 'given' ? ' cp-rec-row-given' : ($mark === 'skipped' ? ' cp-rec-row-skipped' : '');
                ?>
            <div class="cp-rec-row<?= $rowClass ?>" data-caid="<?= $caid ?>" data-rowversion="<?= (int)($aw['RowVersion'] ?? 0) ?>" data-mark="<?= $mark ?>">
                <span class="cp-rec-c cp-rec-c-num"><?= $__i + 1 ?></span>
                <span class="cp-rec-c cp-rec-c-mark cp-rec-seg" role="group" aria-label="Mark <?= htmlspecialchars($aw['Persona'] ?? 'this award') ?> — <?= htmlspecialchars($aw['AwardName'] ?? '') ?>">
                    <button type="button" class="cp-rec-seg-btn cp-rec-seg-given" aria-pressed="<?= $mark === 'given' ? 'true' : 'false' ?>" onclick="cpRecMark(<?= $caid ?>,'given')" <?= $canMark ? '' : 'disabled' ?>>Given</button>
                    <button type="button" class="cp-rec-seg-btn cp-rec-seg-skipped" aria-pressed="<?= $mark === 'skipped' ? 'true' : 'false' ?>" onclick="cpRecMark(<?= $caid ?>,'skipped')" <?= $canMark ? '' : 'disabled' ?>>Skipped</button>
                    <button type="button" class="cp-rec-seg-btn cp-rec-seg-none" aria-pressed="<?= $mark === 'none' ? 'true' : 'false' ?>" onclick="cpRecMark(<?= $caid ?>,'none')" data-tip="Clear this mark" <?= $canMark ? '' : 'disabled' ?>>&mdash;</button>
                </span>
                <span class="cp-rec-c cp-rec-c-recip">
                    <span class="cp-rec-c-label">Recipient</span>
                    <?= htmlspecialchars($aw['Persona'] ?? '') ?><?php if (!empty($aw['ParkAbbrev'])): ?> <span class="cp-rec-park"><?= htmlspecialchars($aw['ParkAbbrev']) ?></span><?php endif; ?>
                </span>
                <span class="cp-rec-c cp-rec-c-award">
                    <span class="cp-rec-c-label">Award</span>
                    <?= htmlspecialchars($aw['AwardName'] ?? '') ?>
                </span>
                <span class="cp-rec-c cp-rec-c-rank">
                    <span class="cp-rec-c-label">Rank</span>
                    <?php if (!empty($aw['IsLadder'])):
                        $initRank = (int)($aw['Rank'] ?? 0) > 0 ? (int)$aw['Rank'] : 1;
                    ?>
                    <button type="button" class="ladder-rank cp-rec-rank-chip" id="cp-rec-rank-chip-<?= $caid ?>"
                            data-lvl="<?= min($initRank, 10) ?>" data-rank="<?= $initRank ?>"
                            data-award="<?= htmlspecialchars($aw['AwardName'] ?? '') ?>"
                            onclick="cpRecOpenRankPop(<?= $caid ?>, this)" data-tip="Change the rank granted"
                            <?= $canMark ? '' : 'disabled' ?>>Rank <?= $initRank ?></button>
                    <?php else: ?>&mdash;<?php endif; ?>
                </span>
                <span class="cp-rec-c cp-rec-c-giver">
                    <span class="cp-rec-c-label">Given by</span>
                    <?php
                    $rowGiverId = (int)($aw['GivenByMundaneId'] ?? 0);
                    $rowGiverPersona = $rowGiverId > 0 ? $aw['GivenByPersona'] : ($giverOptions['default']['persona'] ?? '');
                    $rowGiverId = $rowGiverId > 0 ? $rowGiverId : (int)($giverOptions['default']['mundane_id'] ?? 0);
                    ?>
                    <button type="button" class="cp-rec-giver-chip" id="cp-rec-giver-chip-<?= $caid ?>"
                            data-mundane-id="<?= $rowGiverId ?>" data-persona="<?= htmlspecialchars($rowGiverPersona) ?>"
                            onclick="cpRecOpenGiverPop(<?= $caid ?>, this)" data-tip="Change who gave this award"
                            <?= $canMark ? '' : 'disabled' ?>><?= htmlspecialchars($rowGiverPersona !== '' ? $rowGiverPersona : '—') ?></button>
                </span>
                <span class="cp-rec-c cp-rec-c-ptl">
                    <span class="cp-rec-c-label">PTL</span>
                    <?php if (!empty($aw['PassToLocal'])): ?><i class="fas fa-arrow-down" data-tip="Pass to Local" aria-label="Pass to Local"></i><?php else: ?>&mdash;<?php endif; ?>
                </span>
            </div>
            <?php endforeach;
unset($__i, $aw, $caid, $mark, $rowClass); ?>
        </div>
        <?php endif; ?>
    </div>

</div>

<!-- Given-by popover (Task 8) — a single shared floating panel, not one per row (22+
     rows would mean 22+ copies of the giver pills + search). Reuses cpGiverOptions'
     pills/search idiom from the grant modal's .cp-giver-pill / .cp-ac-* chrome (shared
     court-planner.css), positioned fixed next to the chip that opened it (same idiom as
     Court_detail.tpl's #cp-note-popup). "Apply to the rest below" lives here too — it
     acts on whichever row is currently open, and only updates rows below it in the
     list; it never marks a row. -->
<div class="cp-rec-pop" id="cp-rec-giver-pop" role="dialog" aria-modal="false" aria-labelledby="cp-rec-giver-pop-title">
    <div class="cp-rec-pop-header">
        <span class="cp-rec-pop-title" id="cp-rec-giver-pop-title">Given by</span>
        <button type="button" class="cp-rec-pop-close" onclick="cpRecGiverPopClose()" aria-label="Close">&times;</button>
    </div>
    <div class="cp-giver-pills" id="cp-rec-giver-pop-pills"></div>
    <div class="cp-ac-wrap">
        <input type="text" id="cp-rec-giver-pop-text" placeholder="Search for another giver…" autocomplete="off"
               oninput="cpRecGiverPopInput(this)">
        <div class="cp-ac-dropdown" id="cp-rec-giver-pop-ac"></div>
    </div>
    <input type="hidden" id="cp-rec-giver-pop-caid" value="0">
    <input type="hidden" id="cp-rec-giver-pop-hidden" value="0">
    <button type="button" class="cp-rec-pop-apply-btn" id="cp-rec-apply-rest-btn" onclick="cpRecApplyRest()">
        <i class="fas fa-arrow-down"></i> Apply to the rest below
    </button>
</div>

<!-- Rank popover (Task 8) — same shared-floating-panel idiom, reusing the ad-hoc
     modal's .cp-rank-pill / .ladder-rank chrome (shared court-planner.css). Non-ladder
     rows never get a rank control (getCourtAwards' IsLadder gate on the PHP side). -->
<div class="cp-rec-pop" id="cp-rec-rank-pop" role="dialog" aria-modal="false" aria-labelledby="cp-rec-rank-pop-title">
    <div class="cp-rec-pop-header">
        <span class="cp-rec-pop-title" id="cp-rec-rank-pop-title">Rank</span>
        <button type="button" class="cp-rec-pop-close" onclick="cpRecRankPopClose()" aria-label="Close">&times;</button>
    </div>
    <div class="cp-rank-pills" id="cp-rec-rank-pop-pills"></div>
    <input type="hidden" id="cp-rec-rank-pop-caid" value="0">
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

    // Informational toast (calm navy, .cp-toast-info) — distinct from cpGlobalError's
    // alarming red — for the S5 optimistic-lock "this row changed" notice (spec §0.4):
    // nothing failed, another recorder just got there first. Same idiom as
    // Court_detail.tpl's own cpNotice(), which is local to ITS IIFE and not exported —
    // this view needs its own copy.
    function cpNotice(msg) {
        var t = document.createElement('div');
        t.className = 'cp-toast cp-toast-info';
        t.setAttribute('role', 'status');
        t.setAttribute('aria-live', 'polite');
        t.textContent = msg || '';
        document.body.appendChild(t);
        setTimeout(function() { t.remove(); }, 4000);
    }
    window.cpNotice = cpNotice;

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

    // ---- Per-row marks (spec §5.1) ----
    // Task 9 still owns cpRecCitationFor (a stub for now). cpRecGiverFor/cpRecRankFor
    // are the real thing: cpRecMark reads whatever the officer left in cpRecGivers/
    // cpRecRanks (populated below from the server's per-row GivenByMundaneId/Rank, and
    // updated live by the giver/rank popovers) — never re-derives the court default at
    // mark time, so a chip the officer changed sticks even if they never touch it again.
    window.cpRecCitationFor = function(caid) {
        var a = courtAwards.find(function(x) { return String(x.CourtAwardId) === String(caid); });
        return a ? (a.PublicComment || '') : '';
    };

    // ---- Given-by chip + "apply to the rest below" (spec §5, Task 8) ----
    // caid (string, matches data-caid) -> {id, persona}. Seeded from the row's own
    // persisted GivenByMundaneId/GivenByPersona (Task 8 added these to getCourtAwards())
    // when the row was already staged/given by someone other than the default — e.g. a
    // page reload after a partial pass must not silently repaint every row back to the
    // default giver. Everything else seeds from the court's default giver, exactly like
    // the printed sheet pre-prints it.
    var cpRecGivers = {};
    courtAwards.forEach(function(a) {
        var hasOwn = a.GivenByMundaneId && a.GivenByMundaneId > 0;
        cpRecGivers[a.CourtAwardId] = {
            id: hasOwn ? a.GivenByMundaneId : ((cpGiverOptions && cpGiverOptions.default) ? cpGiverOptions.default.mundane_id : 0),
            persona: hasOwn ? a.GivenByPersona : ((cpGiverOptions && cpGiverOptions.default) ? cpGiverOptions.default.persona : '')
        };
    });
    window.cpRecGiverFor = function(caid) {
        var g = cpRecGivers[caid];
        return g ? (g.id || 0) : 0;
    };

    // caid (string) -> rank. Ladder rows only (non-ladder rows have no chip and are
    // never marked with a rank — grant_award still gets Rank=0 for them via cpRecMark's
    // FormData, same as before).
    var cpRecRanks = {};
    courtAwards.forEach(function(a) {
        if (a.IsLadder) cpRecRanks[a.CourtAwardId] = a.Rank > 0 ? a.Rank : 1;
    });
    window.cpRecRankFor = function(caid) {
        return cpRecRanks[caid] || 0;
    };

    function cpRecIsDefaultGiver(mundaneId) {
        return !!(cpGiverOptions && cpGiverOptions.default && String(cpGiverOptions.default.mundane_id) === String(mundaneId));
    }

    // Updates the map AND the visible chip together — every write path (pill pick,
    // search pick, apply-to-rest) funnels through this so the two can't drift.
    function cpRecSetGiverChip(caid, mundaneId, persona) {
        cpRecGivers[caid] = { id: mundaneId, persona: persona };
        var chip = gid('cp-rec-giver-chip-' + caid);
        if (!chip) return;
        chip.textContent = persona || '—';
        chip.dataset.mundaneId = mundaneId;
        chip.dataset.persona = persona;
        // Faint-default vs write-in, same idea as the printed sheet: a chip that still
        // matches the court default looks like the rest of the row; one that deviates
        // is visually called out so the recorder can see at a glance which rows they
        // touched.
        chip.classList.toggle('cp-rec-chip-custom', !cpRecIsDefaultGiver(mundaneId));
    }

    function cpRecSetRankChip(caid, rank) {
        cpRecRanks[caid] = rank;
        var chip = gid('cp-rec-rank-chip-' + caid);
        if (!chip) return;
        chip.textContent = 'Rank ' + rank;
        chip.dataset.rank = rank;
        chip.dataset.lvl = Math.min(rank, 10);
    }

    // Every .cp-rec-row that comes AFTER the given row in DOM order (the row list's
    // markup order IS its display order — same convention the mark-column comment
    // above relies on). "Apply to the rest below" only ever touches these; it never
    // looks upward and never touches the row itself twice.
    function cpRecRowsBelow(row) {
        var out = [];
        var el = row && row.nextElementSibling;
        while (el) {
            if (el.classList && el.classList.contains('cp-rec-row')) out.push(el);
            el = el.nextElementSibling;
        }
        return out;
    }

    // Shared positioning for both popovers — identical idiom to Court_detail.tpl's
    // cpShowNote(): fixed, flips above the anchor if it would run off the bottom of
    // the viewport, clamped to stay on-screen horizontally. Works the same whether the
    // anchor sits in a normally-flowing row or (at <=600px) a stacked card.
    function cpRecPositionPop(pop, anchor) {
        pop.style.display = 'block';
        var r  = anchor.getBoundingClientRect();
        var pw = pop.offsetWidth;
        var ph = pop.offsetHeight;
        // clientWidth/clientHeight (not window.innerWidth/innerHeight) — those include
        // the scrollbar gutter, which let the popover's right edge land a few px past
        // the actual visible content area on a page tall enough to scroll (caught at
        // 768px width during Task 8's own mobile check).
        var vh = document.documentElement.clientHeight;
        var vw = document.documentElement.clientWidth;
        var top = r.bottom + 6;
        if (top + ph > vh - 10) top = r.top - ph - 6;
        var left = r.left;
        if (left + pw > vw - 10) left = vw - pw - 10;
        pop.style.top  = Math.max(10, top)  + 'px';
        pop.style.left = Math.max(10, left) + 'px';
    }

    // ---- Given-by popover ----
    var cpRecGiverPopCaid = 0;
    function cpRecBuildGiverPopPills(activeId) {
        var wrap = gid('cp-rec-giver-pop-pills');
        if (!wrap) return;
        wrap.innerHTML = '';
        var list = [];
        if (cpGiverOptions && cpGiverOptions.default) list.push(cpGiverOptions.default);
        if (cpGiverOptions && cpGiverOptions.pills) cpGiverOptions.pills.forEach(function(p) { list.push(p); });
        if (!list.length) { wrap.style.display = 'none'; return; }
        wrap.style.display = 'flex';
        list.forEach(function(g) {
            var btn = document.createElement('button');
            btn.type = 'button';
            btn.className = 'cp-giver-pill' + (String(g.mundane_id) === String(activeId) ? ' active' : '');
            btn.innerHTML = esc(g.persona) + ' <span class="cp-giver-role">' + esc(g.role || '') + '</span>';
            btn.onclick = function() { cpRecGiverPopPick(g.mundane_id, g.persona); };
            wrap.appendChild(btn);
        });
    }
    function cpRecGiverPopPick(mundaneId, persona) {
        if (!cpRecGiverPopCaid) return;
        cpRecSetGiverChip(cpRecGiverPopCaid, mundaneId, persona);
        cpRecBuildGiverPopPills(mundaneId);
        var acDrop = gid('cp-rec-giver-pop-ac');
        if (acDrop) { acDrop.style.display = 'none'; acDrop.innerHTML = ''; }
        gid('cp-rec-giver-pop-text').value = '';
    }
    window.cpRecOpenGiverPop = function(caid, chip) {
        cpRecGiverPopCaid = caid;
        gid('cp-rec-giver-pop-caid').value = caid;
        var cur = cpRecGivers[caid] || {};
        cpRecBuildGiverPopPills(cur.id);
        var txt = gid('cp-rec-giver-pop-text');
        if (txt) txt.value = '';
        var acDrop = gid('cp-rec-giver-pop-ac');
        if (acDrop) { acDrop.style.display = 'none'; acDrop.innerHTML = ''; }
        var row = chip.closest('.cp-rec-row');
        var below = cpRecRowsBelow(row);
        var applyBtn = gid('cp-rec-apply-rest-btn');
        if (applyBtn) {
            applyBtn.classList.toggle('show', below.length > 0);
            applyBtn.innerHTML = '<i class="fas fa-arrow-down"></i> Apply to the ' + below.length +
                ' row' + (below.length === 1 ? '' : 's') + ' below';
        }
        cpRecPositionPop(gid('cp-rec-giver-pop'), chip);
    };
    window.cpRecGiverPopClose = function() {
        var p = gid('cp-rec-giver-pop'); if (p) p.style.display = 'none';
        var acDrop = gid('cp-rec-giver-pop-ac'); if (acDrop) { acDrop.style.display = 'none'; acDrop.innerHTML = ''; }
        cpRecGiverPopCaid = 0;
    };
    // Wraps the page's shared cpAcSearch (scoped to this court's kingdom, &q=, custom
    // dropdown — house rules) with a pick callback that routes through the same
    // cpRecGiverPopPick() the quick-pick pills use.
    window.cpRecGiverPopInput = function(input) {
        cpAcSearch(input, 'cp-rec-giver-pop-ac', 'cp-rec-giver-pop-hidden', function(p) {
            cpRecGiverPopPick(p.MundaneId, p.Persona);
        });
    };
    // "Apply to the rest below" — updates every row below the currently-open one to
    // the giver just picked for THIS row. Deliberately calls cpRecSetGiverChip() only
    // (never cpRecMark/cpRecPost): the giver reaches the database the same way it
    // always does, when that row is individually marked Given.
    window.cpRecApplyRest = function() {
        if (!cpRecGiverPopCaid) return;
        var cur = cpRecGivers[cpRecGiverPopCaid];
        if (!cur) return;
        var row = document.querySelector('.cp-rec-row[data-caid="' + cpRecGiverPopCaid + '"]');
        if (!row) return;
        var below = cpRecRowsBelow(row);
        below.forEach(function(r) {
            cpRecSetGiverChip(r.getAttribute('data-caid'), cur.id, cur.persona);
        });
        cpNotice('Applied "' + cur.persona + '" as the giver for ' + below.length +
            ' row' + (below.length === 1 ? '' : 's') + ' below. Nothing was marked.');
        cpRecGiverPopClose();
    };

    // ---- Rank popover (ladder rows only) ----
    var cpRecRankPopCaid = 0;
    // Same zodiac-award heuristic as the ad-hoc modal's cpBuildAdhocRankPills().
    function cpRecMaxRank(awardName) {
        return /zodiac/i.test(awardName || '') ? 12 : 10;
    }
    function cpRecBuildRankPopPills(awardName, activeRank) {
        var wrap = gid('cp-rec-rank-pop-pills');
        if (!wrap) return;
        var maxRank = cpRecMaxRank(awardName);
        var html = '';
        for (var i = 1; i <= maxRank; i++) {
            html += '<button type="button" class="ladder-rank cp-rank-pill' + (i === activeRank ? ' cp-rank-pill-selected' : '') +
                '" data-lvl="' + Math.min(i, 10) + '" data-rank="' + i + '" onclick="cpRecRankPopPick(' + i + ')">' + i + '</button>';
        }
        wrap.innerHTML = html;
    }
    window.cpRecOpenRankPop = function(caid, chip) {
        cpRecRankPopCaid = caid;
        gid('cp-rec-rank-pop-caid').value = caid;
        var rank = cpRecRanks[caid] || 1;
        cpRecBuildRankPopPills(chip.dataset.award, rank);
        cpRecPositionPop(gid('cp-rec-rank-pop'), chip);
    };
    window.cpRecRankPopPick = function(rank) {
        if (!cpRecRankPopCaid) return;
        cpRecSetRankChip(cpRecRankPopCaid, rank);
        var wrap = gid('cp-rec-rank-pop-pills');
        if (wrap) {
            wrap.querySelectorAll('.cp-rank-pill').forEach(function(p) {
                p.classList.toggle('cp-rank-pill-selected', String(p.dataset.rank) === String(rank));
            });
        }
    };
    window.cpRecRankPopClose = function() {
        var p = gid('cp-rec-rank-pop'); if (p) p.style.display = 'none';
        cpRecRankPopCaid = 0;
    };
    // Dismiss either popover on an outside click — mousedown so it fires before the
    // click that might be opening a DIFFERENT chip's popover.
    document.addEventListener('mousedown', function(e) {
        var giverPop = gid('cp-rec-giver-pop');
        if (giverPop && giverPop.style.display !== 'none' &&
            !e.target.closest('#cp-rec-giver-pop') && !e.target.closest('.cp-rec-giver-chip')) {
            cpRecGiverPopClose();
        }
        var rankPop = gid('cp-rec-rank-pop');
        if (rankPop && rankPop.style.display !== 'none' &&
            !e.target.closest('#cp-rec-rank-pop') && !e.target.closest('.cp-rec-rank-chip')) {
            cpRecRankPopClose();
        }
    });

    // caid -> in-flight XHR guard, so a fast double-click (or a stuck network
    // request) can't fire two writes for the same row.
    var cpRecInFlight = {};

    function cpRecSetRowUi(row, state) {
        row.dataset.mark = state;
        row.classList.remove('cp-rec-row-given', 'cp-rec-row-skipped');
        if (state === 'given') row.classList.add('cp-rec-row-given');
        else if (state === 'skipped') row.classList.add('cp-rec-row-skipped');
        row.querySelectorAll('.cp-rec-seg-btn').forEach(function(btn) {
            var btnState = btn.classList.contains('cp-rec-seg-given') ? 'given'
                         : btn.classList.contains('cp-rec-seg-skipped') ? 'skipped' : 'none';
            btn.setAttribute('aria-pressed', btnState === state ? 'true' : 'false');
        });
    }

    // cpRecPost handles the shared response contract for grant_award/skip_award/
    // unstage_award: status 9 = another recorder changed this row first (S5
    // optimistic lock, spec §0.4) — show the non-destructive notice and leave the
    // row exactly as it was, never clobber it. status 0 = the write landed; patch
    // the row's visual state and bump its row_version so the NEXT mark on this row
    // (Given -> Skipped -> — are all just re-marks) threads the fresh token.
    window.cpRecPost = function(url, fd, row, state) {
        var caid = row.getAttribute('data-caid');
        if (cpRecInFlight[caid]) return;
        cpRecInFlight[caid] = true;
        row.querySelectorAll('.cp-rec-seg-btn').forEach(function(b) { b.disabled = true; });
        post(url, fd).then(function(d) {
            delete cpRecInFlight[caid];
            var canMark = courtStatus === 'published';
            row.querySelectorAll('.cp-rec-seg-btn').forEach(function(b) { b.disabled = !canMark; });
            if (d && d.status === 9) {
                cpNotice('This row changed — reload to see the latest.');
                return;
            }
            if (d && d.status === 0) {
                var newVersion = (parseInt(row.getAttribute('data-rowversion'), 10) || 0) + 1;
                row.setAttribute('data-rowversion', newVersion);
                cpRecSetRowUi(row, state);
                var a = courtAwards.find(function(x) { return String(x.CourtAwardId) === String(caid); });
                if (a) {
                    a.RowVersion = newVersion;
                    a.Status = state === 'given' ? 'staged' : (state === 'skipped' ? 'cancelled' : 'planned');
                }
                if (typeof d.staged_count !== 'undefined') cpUpdateStagedIndicator(d.staged_count);
            } else if (!d._postFailed) {
                cpAlert(d.error || 'Could not save this mark.');
            }
        });
    };

    // Given -> stage, Skipped -> skip, — -> unstage. All three already exist and all
    // three are pre-finalize, so any of them can be undone by pressing another.
    window.cpRecMark = function(caid, state) {
        var row = document.querySelector('.cp-rec-row[data-caid="' + caid + '"]');
        if (!row) return;
        var current = row.getAttribute('data-mark') || 'none';
        // Clearing to "-" is NOT a single endpoint: unstage_award only clears a
        // STAGED row (its WHERE requires status='staged' — it refuses a cancelled
        // one, by design, same as grant_award refuses staging a cancelled row
        // directly). A currently-Skipped row is cleared the same way Court_detail.tpl's
        // "Un-skip" does it: set_award_status(Status=planned), which (like skip_award)
        // guards only against 'given'. Discovered via fix-round Finding 2's own
        // repair: before unstage_award honestly reported failure, a stale "-" click
        // on a Skipped row silently no-op'd server-side while the client showed it
        // as cleared anyway — the same class of desync, just single-recorder instead
        // of cross-recorder.
        if (state === 'none' && current === 'none') return; // already clear — nothing to do
        var url;
        var fd = new FormData();
        fd.append('CourtAwardId', caid);
        fd.append('RowVersion', row.getAttribute('data-rowversion') || '');
        if (state === 'given') {
            url = 'CourtAjax/grant_award';
            fd.append('GivenById', cpRecGiverFor(caid));
            fd.append('PublicComment', cpRecCitationFor(caid));
            fd.append('Rank', cpRecRankFor(caid));
        } else if (state === 'skipped') {
            url = 'CourtAjax/skip_award';
        } else if (current === 'skipped') {
            url = 'CourtAjax/set_award_status';
            fd.append('Status', 'planned');
        } else {
            url = 'CourtAjax/unstage_award';
        }
        cpRecPost(url, fd, row, state);
    };

    // ---- "Mark all remaining Given" (spec §5, the old Record All Grants,
    // relabelled) — the only bulk action. There is no "stage all marked" button:
    // bulk_record_grants is a set-based UPDATE ... WHERE status = 'planned' that
    // already writes staged server-side, over whatever is still planned right
    // now — so it stays live and clicking it again after walk-ons land catches
    // them too. Rows are never silently defaulted to Given; this button is the
    // one explicit, visible way that happens. Reloads on success so row states
    // come back from the server rather than being guessed client-side. ----
    window.cpRecMarkAllGiven = function() {
        cpConfirm({
            title: 'Mark all remaining Given',
            body: 'Stage every still-planned award on this court as Given, under the default giver? Rows you already marked Given or Skipped are left alone. You can still undo individual grants before finalizing.',
            confirmLabel: 'Mark All Given',
            onConfirm: function() {
                var btn = gid('cp-rec-bulk-btn');
                if (btn) btn.disabled = true;
                var fd = new FormData();
                fd.append('CourtId', courtId);
                post('CourtAjax/bulk_record_grants', fd).then(function(d) {
                    if (d.status === 0) { location.reload(); return; }
                    if (btn) btn.disabled = false;
                    if (!d._postFailed) cpAlert(d.error || 'Could not record grants.');
                });
            }
        });
    };

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
            cpRecGiverPopClose();
            cpRecRankPopClose();
        }
    });
})();
</script>
<?php endif; ?>
