#!/usr/bin/env php
<?php

/**
 * Posts owed survey attendance credits
 * (docs/superpowers/specs/2026-09-10-survey-sharing-and-credits-design.md §3.5).
 *
 * Credits are normally posted when a player submits, when an officer turns a
 * credit on, and when the Credits panel opens; this sweep repairs any grant
 * that failed in between. Reconcile is idempotent, so running it often is
 * harmless. Optional cron:
 *
 *     # /etc/cron.d/ork-survey-credit-sweep
 *     15 * * * * www-data /usr/bin/php /var/www/ORK3/bin/survey-credit-sweep.php >> /var/log/ork-survey-credit-sweep.log 2>&1
 */

require_once dirname(__DIR__) . '/startup.php';

$credit = Ork3::$Lib->surveycredit;
foreach ($credit->surveysWithConfigs() as $surveyId) {
    $r = $credit->reconcile($surveyId);
    if ($r['Granted'] > 0 || $r['Pending'] > 0) {
        fprintf(
            STDOUT,
            "[%s] survey=%d granted=%d pending=%d skipped_no_park=%d\n",
            date('Y-m-d H:i:s'),
            $surveyId,
            $r['Granted'],
            $r['Pending'],
            $r['SkippedNoPark']
        );
    }
}
exit(0);
