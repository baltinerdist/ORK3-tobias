-- Backfill for #39: relabel tiebreaker matches that were silently stored with an
-- empty bracket_side before the enum carried the tiebreaker values.
--
-- Runs AFTER 2026-04-06-bracket-side-tiebreaker-enum.sql (adds 'tiebreaker-3rd') and
-- 2026-05-19-bracket-side-rr-tiebreaker-enum.sql (adds 'tiebreaker'), so both target
-- values are valid enum members here.
--
-- Reliable signal: every insert_match() call passes bracket_side explicitly and every
-- non-tiebreaker path passes a non-empty value ('winners' / 'losers' / 'grand-final').
-- The ONLY way a row acquired bracket_side='' is CreateTiebreakerMatch / the RR
-- tiebreaker flow writing a value that was not yet a valid enum member (sql_mode off).
-- We disambiguate the two tiebreaker kinds by the parent bracket's method:
--   single / double  -> 3rd-place tiebreaker ('tiebreaker-3rd')
--   round-robin      -> first-place tiebreaker ('tiebreaker')
-- Idempotent: once relabeled there are no bracket_side='' rows left to match.

UPDATE ork_match m
  JOIN ork_bracket b ON b.bracket_id = m.bracket_id
  SET m.bracket_side = 'tiebreaker-3rd'
  WHERE m.bracket_side = '' AND b.method IN ('single', 'double');

UPDATE ork_match m
  JOIN ork_bracket b ON b.bracket_id = m.bracket_id
  SET m.bracket_side = 'tiebreaker'
  WHERE m.bracket_side = '' AND b.method = 'round-robin';
