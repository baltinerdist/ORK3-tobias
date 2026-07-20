-- Unique constraints for Arts & Sciences integrity — 2026-07-19
--
-- Two data-integrity holes let duplicate rows slip in that later corrupt the
-- Results Grid / leaderboard and the ladder-award counting:
--
-- Fix 23: ork_as_entry.entry_number must be unique per competition. Two entries
--   sharing an entry_number collide in the spreadsheet Grid and in the blind
--   "Artisan #{n}" redaction, and there was no DB guard preventing it. Existing
--   rows may carry '' (empty string) or duplicate values, so we normalize the
--   empties to NULL first — NULL is allowed under a UNIQUE KEY and multiple NULLs
--   never collide, so unnumbered entries stay legal.
--
-- Fix 24: ork_as_taxonomy.ladder_award_id is set ONLY on the four system fields
--   (24/25/26/22) and is NULL for every user-created field. A competition should
--   therefore hold at most one taxonomy row per ladder_award_id. The system-field
--   seed (2026-04-26-arts-sciences-system-fields.sql) already guards with a
--   NOT EXISTS check, but nothing at the schema level stopped a double-seed or a
--   race from inserting a duplicate. NULLs (user fields) don't collide under a
--   UNIQUE KEY, so this only constrains the system rows.
--
-- Safe to run on live production: the UNIQUE KEYs are added only after the data
-- is normalized/de-duplicated, and MariaDB 10.x+ builds them with online DDL.
-- Do NOT run this against a database with un-reconciled duplicates without first
-- confirming the de-dup steps below removed them.

-- ---------------------------------------------------------------------------
-- Fix 23: UNIQUE (competition_id, entry_number) on ork_as_entry
-- ---------------------------------------------------------------------------

-- Normalize empty-string entry_number to NULL so blank entries don't collide
-- with each other (NULLs are permitted and non-colliding under a UNIQUE KEY).
UPDATE ork_as_entry SET entry_number = NULL WHERE entry_number = '';

-- Guard: if any genuine duplicate (competition_id, entry_number) pairs remain,
-- the ADD UNIQUE below will fail. Inspect them first with:
--   SELECT competition_id, entry_number, COUNT(*)
--     FROM ork_as_entry
--    WHERE entry_number IS NOT NULL
--    GROUP BY competition_id, entry_number HAVING COUNT(*) > 1;
-- and renumber the offending rows by hand before proceeding — entry_number is a
-- human-facing label, so automatic de-dup would silently relabel real entries.

ALTER TABLE ork_as_entry
    ADD UNIQUE KEY IF NOT EXISTS uniq_as_entry_number (competition_id, entry_number);

-- ---------------------------------------------------------------------------
-- Fix 24: UNIQUE (competition_id, ladder_award_id) on ork_as_taxonomy
-- ---------------------------------------------------------------------------

-- Guard: collapse any pre-existing duplicate system rows (same competition_id +
-- ladder_award_id) down to the lowest taxonomy_id before adding the constraint.
-- ladder_award_id IS NULL rows (user fields) are excluded and never collide.
DELETE t
  FROM ork_as_taxonomy t
  JOIN (
        SELECT competition_id, ladder_award_id, MIN(taxonomy_id) AS keep_id
          FROM ork_as_taxonomy
         WHERE ladder_award_id IS NOT NULL
         GROUP BY competition_id, ladder_award_id
        HAVING COUNT(*) > 1
       ) d
    ON t.competition_id  = d.competition_id
   AND t.ladder_award_id = d.ladder_award_id
 WHERE t.taxonomy_id <> d.keep_id;

ALTER TABLE ork_as_taxonomy
    ADD UNIQUE KEY IF NOT EXISTS uniq_as_tax_ladder_award (competition_id, ladder_award_id);
