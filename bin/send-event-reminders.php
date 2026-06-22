#!/usr/bin/env php
<?php

/**
 * Sends "event coming up" notifications to everyone who RSVP'd "going" to an
 * event occurrence happening 7 days out and again 2 days out. One notification
 * per recipient per (occurrence, window) — CreateBulkOnce dedupes on a payload
 * marker so re-running the cron the same day never double-notifies.
 *
 * Intended host cron (daily 7am, server local):
 *
 *     # /etc/cron.d/ork-event-reminders
 *     0 7 * * * www-data /usr/bin/php /var/www/ORK3/bin/send-event-reminders.php >> /var/log/ork-event-reminders.log 2>&1
 *
 * Flags:
 *   --dry-run        compute + print what WOULD send; insert nothing
 *   --window=7|2     restrict to a single reminder window (default: both 7 and 2)
 *
 * Examples:
 *     php bin/send-event-reminders.php --dry-run
 *     php bin/send-event-reminders.php --window=2
 *
 * Reads via Event::GetEventReminderTargets(); writes via
 * Notification::CreateBulkOnce(). No raw $DB here — lib calls only.
 */

// CLI has no HTTP_HOST; config.dev.php reads it for asset URL constants. Default it
// so bootstrap doesn't emit warnings (this job only uses relative ?Route= links).
if (!isset($_SERVER['HTTP_HOST'])) {
    $_SERVER['HTTP_HOST'] = 'localhost';
}

require_once dirname(__DIR__) . '/startup.php';

$event        = Ork3::$Lib->event;
$notification = Ork3::$Lib->notification;

// Window day-count => short label embedded in the dedupe key / payload.
$ALL_WINDOWS = [7 => '7d', 2 => '2d'];

$dry_run = false;
$only_window = null;
foreach (array_slice($argv, 1) as $arg) {
    if ($arg === '--dry-run') {
        $dry_run = true;
    } elseif (preg_match('/^--window=(\d+)$/', $arg, $m)) {
        $w = (int) $m[1];
        if (!isset($ALL_WINDOWS[$w])) {
            fprintf(STDERR, "Invalid --window=%d. Allowed: 7, 2.\n", $w);
            exit(1);
        }
        $only_window = $w;
    } else {
        fprintf(STDERR, "Invalid arg '%s'. Expected --dry-run or --window=7|2.\n", $arg);
        exit(1);
    }
}

$windows = $ALL_WINDOWS;
if ($only_window !== null) {
    $windows = [$only_window => $ALL_WINDOWS[$only_window]];
}

$grand_events     = 0;
$grand_recipients = 0;
$grand_inserted   = 0;
$grand_skipped    = 0;

foreach ($windows as $days => $label) {
    $rows = $event->GetEventReminderTargets($days);

    // Group RSVP rows by occurrence (event_calendardetail_id).
    $groups = [];
    foreach ($rows as $row) {
        $detailId = (int) $row['event_calendardetail_id'];
        if ($detailId <= 0) {
            continue;
        }
        if (!isset($groups[$detailId])) {
            $groups[$detailId] = [
                'event_id'    => (int) $row['event_id'],
                'event_name'  => (string) $row['event_name'],
                'event_start' => $row['event_start'],
                'mundaneIds'  => [],
            ];
        }
        $mid = (int) $row['mundane_id'];
        if ($mid > 0) {
            $groups[$detailId]['mundaneIds'][$mid] = true;
        }
    }

    $win_events     = 0;
    $win_recipients = 0;
    $win_inserted   = 0;
    $win_skipped    = 0;

    foreach ($groups as $detailId => $g) {
        $mundaneIds = array_keys($g['mundaneIds']);
        if (count($mundaneIds) === 0) {
            continue;
        }

        $eventId   = (int) $g['event_id'];
        $eventName = trim((string) $g['event_name']);
        $start     = $g['event_start'];
        $startTs   = $start ? strtotime($start) : false;

        $dedupeKey = 'evt:' . $detailId . ':' . $label;
        $fields = [
            'title'    => $eventName . ' is coming up',
            'body'     => 'Starts ' . ($startTs !== false ? date('M j', $startTs) : '?')
                          . ' — in ' . $days . ' days',
            'icon'     => 'fas fa-clock',
            'link_url' => '?Route=Event/index/' . $eventId,
            'payload'  => json_encode([
                'event_detail_id' => $detailId,
                'window'          => $label,
                'k'               => $dedupeKey,
            ]),
        ];

        $win_events++;
        $win_recipients += count($mundaneIds);

        if ($dry_run) {
            fprintf(
                STDOUT,
                "[dry-run %s] window=%s detail=%d event=%d \"%s\" recipients=%d key=%s\n",
                date('Y-m-d H:i:s'),
                $label,
                $detailId,
                $eventId,
                $eventName,
                count($mundaneIds),
                $dedupeKey
            );
            continue;
        }

        $result = $notification->CreateBulkOnce($mundaneIds, 'event_reminder', $fields, $dedupeKey);
        $inserted = isset($result['Count']) ? (int) $result['Count'] : 0;
        $skipped  = isset($result['Skipped']) ? (int) $result['Skipped'] : 0;
        $win_inserted += $inserted;
        $win_skipped  += $skipped;

        if (isset($result['Status']) && (int) $result['Status'] !== 0) {
            fprintf(
                STDERR,
                "[%s] window=%s detail=%d event=%d — CreateBulkOnce ERROR: %s (inserted=%d skipped=%d)\n",
                date('Y-m-d H:i:s'),
                $label,
                $detailId,
                $eventId,
                $result['Error'] ?? 'unknown',
                $inserted,
                $skipped
            );
        }
    }

    fprintf(
        STDOUT,
        "[%s] window=%s%s — events=%d recipients=%d inserted=%d skipped=%d\n",
        date('Y-m-d H:i:s'),
        $label,
        $dry_run ? ' (dry-run)' : '',
        $win_events,
        $win_recipients,
        $win_inserted,
        $win_skipped
    );

    $grand_events     += $win_events;
    $grand_recipients += $win_recipients;
    $grand_inserted   += $win_inserted;
    $grand_skipped    += $win_skipped;
}

fprintf(
    STDOUT,
    "[%s] TOTAL%s — events=%d recipients=%d inserted=%d skipped=%d\n",
    date('Y-m-d H:i:s'),
    $dry_run ? ' (dry-run)' : '',
    $grand_events,
    $grand_recipients,
    $grand_inserted,
    $grand_skipped
);
exit(0);
