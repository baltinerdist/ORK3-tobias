<?php
// Shared email/name normalization + junk detection.
// Used by BOTH the cleanup migration audit and CreateGuest/EmailIsAvailable,
// so capture-time rules can never drift from cleanup-time rules.
class GuestValidator {
	// Lowercased exact-match junk values that are never real emails.
	public static $emailDenylist = [
		'n/a','na','none','-','test','unknown','no','x','.','none@none.com',
		'na@na.com','test@test.com','none@gmail.com','a@a.com'
	];
	public static $nameDenylist = ['asdf','test','guest','x','n/a','none','.'];

	// Normalize an email for storage + comparison. Returns '' if it should be NULL.
	public static function normalizeEmail($email) {
		$e = strtolower(trim((string)$email));
		if ($e === '') return '';
		if (in_array($e, self::$emailDenylist, true)) return '';
		// basic format sanity: something@something.tld
		if (!preg_match('/^[^@\s]+@[^@\s]+\.[^@\s]+$/', $e)) return '';
		return $e;
	}

	public static function isJunkEmail($email) {
		return self::normalizeEmail($email) === '';
	}

	// Normalize a person name: trim, collapse whitespace, reject obvious junk.
	public static function normalizeName($name) {
		$n = trim(preg_replace('/\s+/', ' ', (string)$name));
		if ($n === '') return '';
		if (in_array(strtolower($n), self::$nameDenylist, true)) return '';
		if (mb_strlen($n) < 2) return '';
		return $n;
	}
}
