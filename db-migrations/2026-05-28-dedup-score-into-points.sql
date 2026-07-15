-- Dedup: collapse the 'score' bracket method into 'points'. Conceptually identical
-- (per-round scored format), so the UI now only exposes 'points'. Existing score
-- brackets (if any) become points brackets; enum value 'score' is dropped.
--
-- ORDERING: must run AFTER 2026-05-28-add-points-bracket.sql (which adds 'points'
-- to the enum). The filenames are ordered so 'add-points-bracket' sorts first.
UPDATE ork_bracket SET method = 'points' WHERE method = 'score';

-- Repair: a previous run of this pair in the WRONG order (dedup before points-bracket)
-- set method='' on 'score' rows, because 'points' was not yet a valid enum value and
-- sql_mode is off. Those empty methods are unambiguously the collapsed score brackets;
-- restore them to 'points'. Runs before the enum MODIFY so '' is still a legal value.
UPDATE ork_bracket SET method = 'points' WHERE method = '';

ALTER TABLE ork_bracket
  MODIFY method enum('single','double','swiss','round-robin','ironman','points')
    NOT NULL DEFAULT 'single';
