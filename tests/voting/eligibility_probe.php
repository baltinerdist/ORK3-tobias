<?php

// Focused probe for the pure default-resolver + reason mapper (no DB).
// Run: docker exec -i ork3-php8-app php /var/www/html/tests/voting/eligibility_probe.php
require_once __DIR__ . '/../../system/lib/ork3/class.Ork3.php';
require_once __DIR__ . '/../../system/lib/ork3/class.Voting.php';

// 1) Unlisted kingdom resolves to a usable default, flagged is_default.
$r = Voting::resolve_rules(99999);
assert($r['is_default'] === true, 'unlisted kingdom must default');
assert(($r['rules']['AttendanceRequired'] ?? null) === 6, 'default att_req is 6');

// 2) Listed kingdom keeps its own rule, not flagged default.
$r = Voting::resolve_rules(14);
assert($r['is_default'] === false, 'kingdom 14 is configured');
assert(($r['rules']['AttendanceRequired'] ?? null) === 7, 'kingdom 14 att_req is 7');

// 3) Reason mapper is pure and covers each gate.
$reason = Voting::reason_pure(false, ['Suspended' => true, 'SuspendedUntil' => '2026-08-01'], 6);
assert($reason['code'] === 'suspended', 'suspended gate');
$reason = Voting::reason_pure(false, ['Suspended' => false, 'Waivered' => 0], 6);
assert($reason['code'] === 'no_waiver', 'waiver gate');
$reason = Voting::reason_pure(false, ['Suspended' => false, 'Waivered' => 1, 'MembershipOk' => 1, 'DuesPaid' => 0, 'AttCount' => 9], 6);
assert($reason['code'] === 'dues', 'dues gate when attendance met');
$reason = Voting::reason_pure(false, ['Suspended' => false, 'Waivered' => 1, 'MembershipOk' => 1, 'DuesPaid' => 1, 'AttCount' => 2], 6);
assert($reason['code'] === 'attendance' && $reason['short'] === 4, 'attendance shortfall = 4');
echo "eligibility_probe OK\n";
