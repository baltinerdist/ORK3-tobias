<?php
/**
 * "Our Next Event" About tile (Kingdom / Park).
 *
 * Expects in scope:
 *   $odNextEvents  : list from Kingdom::GetKingdomNextEvents / Park::GetParkNextEvents
 *                    (['EventId','DetailId','Name','Start','End','City','Province','InProgress'])
 *   $odEventsTabJs : JS that opens this page's Events tab, e.g. "knActivateTab('events')"
 *
 * Layout: the next event large (name, dates, city/state), the one after it
 * small (name, date). With only one event, a "See Our Events" link takes the
 * second slot; with none, the tile is just a link to the Events tab.
 */
$_odNe       = is_array($odNextEvents ?? null) ? array_values($odNextEvents) : [];
$_odNeFirst  = $_odNe[0] ?? null;
$_odNeSecond = $_odNe[1] ?? null;
$_odNeTabJs  = (string)($odEventsTabJs ?? '');
$_odNeLink   = function (array $ev): string {
    return UIR . 'Event/detail/' . (int)$ev['EventId'] . ((int)$ev['DetailId'] > 0 ? '/' . (int)$ev['DetailId'] : '');
};
$_odNeAllLink = function (string $label) use ($_odNeTabJs): string {
    return '<a href="#" class="od-nextevt-all" onclick="event.preventDefault();' . htmlspecialchars($_odNeTabJs) . ';window.scrollTo({top:0,behavior:\'smooth\'})">'
        . htmlspecialchars($label) . ' <i class="fas fa-arrow-right" aria-hidden="true"></i></a>';
};
?>
<div class="od-about-section od-nextevt">
    <div class="od-about-section-head">
        <div class="od-about-label"><i class="fas fa-calendar-alt" style="margin-right:6px;opacity:0.7" aria-hidden="true"></i>Our Next Event</div>
    </div>
    <?php if ($_odNeFirst): ?>
    <a class="od-nextevt-main" href="<?= htmlspecialchars($_odNeLink($_odNeFirst)) ?>">
        <span class="od-nextevt-cal" aria-hidden="true">
            <span class="od-nextevt-cal-mon"><?= date('M', strtotime($_odNeFirst['Start'])) ?></span>
            <span class="od-nextevt-cal-day"><?= date('j', strtotime($_odNeFirst['Start'])) ?></span>
        </span>
        <span class="od-nextevt-body">
            <?php if (!empty($_odNeFirst['InProgress'])): ?><span class="od-nextevt-now">Happening now</span><?php endif; ?>
            <span class="od-nextevt-name"><?= htmlspecialchars($_odNeFirst['Name']) ?></span>
            <span class="od-nextevt-meta"><i class="far fa-calendar" aria-hidden="true"></i><?= htmlspecialchars(org_design_event_when($_odNeFirst['Start'], $_odNeFirst['End'])) ?></span>
            <?php $_odNeLoc = implode(', ', array_filter([$_odNeFirst['City'], $_odNeFirst['Province']], 'strlen')); ?>
            <?php if ($_odNeLoc !== ''): ?>
            <span class="od-nextevt-meta"><i class="fas fa-map-marker-alt" aria-hidden="true"></i><?= htmlspecialchars($_odNeLoc) ?></span>
            <?php endif; ?>
        </span>
    </a>
    <?php if ($_odNeSecond): ?>
    <a class="od-nextevt-then" href="<?= htmlspecialchars($_odNeLink($_odNeSecond)) ?>">
        <span class="od-nextevt-then-label">Then</span>
        <span class="od-nextevt-then-name"><?= htmlspecialchars($_odNeSecond['Name']) ?></span>
        <span class="od-nextevt-then-date"><?= htmlspecialchars(org_design_event_when($_odNeSecond['Start'], $_odNeSecond['End'], true)) ?></span>
    </a>
    <?php else: ?>
    <div class="od-nextevt-foot"><?= $_odNeAllLink('See Our Events') ?></div>
    <?php endif; ?>
    <?php else: ?>
    <div class="od-nextevt-empty">Nothing on the calendar right now. <?= $_odNeAllLink('See our events') ?></div>
    <?php endif; ?>
</div>
