<?php
// Lightweight assertion helper for shell-runnable scroll tests.
// Each test file `requires` this and calls assert_*() helpers.
// Failures throw + non-zero exit; passes print a single line.

function assert_true($cond, $msg) {
	if (!$cond) { fwrite(STDERR, "FAIL: $msg\n"); exit(1); }
	echo "  ✓ $msg\n";
}
function assert_equals($expected, $actual, $msg) {
	if ($expected !== $actual) {
		fwrite(STDERR, "FAIL: $msg\n  expected: " . var_export($expected, true) . "\n  actual:   " . var_export($actual, true) . "\n");
		exit(1);
	}
	echo "  ✓ $msg\n";
}
function assert_in_array($needle, $haystack, $msg) {
	if (!in_array($needle, $haystack, true)) {
		fwrite(STDERR, "FAIL: $msg\n  needle: " . var_export($needle, true) . "\n  haystack: " . var_export($haystack, true) . "\n");
		exit(1);
	}
	echo "  ✓ $msg\n";
}
function assert_file_exists_msg($path, $msg) {
	if (!file_exists($path)) { fwrite(STDERR, "FAIL: $msg ($path)\n"); exit(1); }
	echo "  ✓ $msg\n";
}
function test_section($title) { echo "\n=== $title ===\n"; }
