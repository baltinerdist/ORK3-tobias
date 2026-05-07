<?php
/**
 * Standalone tally test runner. Avoids the full Ork3 bootstrap so we can
 * unit-test Voting::tally_pure without DB or framework dependencies.
 *
 * Run from project root:
 *   php tests/voting/tally_test_runner.php
 * Or via Docker:
 *   docker exec -i ork3-php8-app php /var/www/html/tests/voting/tally_test_runner.php
 */

// Stub the Ork3 base so we can include class.Voting.php without booting the framework.
if (!class_exists('Ork3')) {
	class Ork3 { public static $Lib = null; public function __construct() {} }
}

require_once __DIR__ . '/../../system/lib/ork3/class.Voting.php';
require_once __DIR__ . '/tally_test.php';

$tests = get_class_methods('VotingTallyTests');
$pass = 0; $fail = 0; $failures = [];

foreach ($tests as $t) {
	if (strpos($t, 'test_') !== 0) continue;
	try {
		(new VotingTallyTests())->$t();
		echo "PASS  $t\n";
		$pass++;
	} catch (Throwable $e) {
		echo "FAIL  $t — " . $e->getMessage() . "\n";
		$fail++;
		$failures[] = $t;
	}
}

echo "\n────────\n$pass passed, $fail failed\n";
if ($fail > 0) {
	echo "Failed: " . implode(', ', $failures) . "\n";
}
exit($fail === 0 ? 0 : 1);
