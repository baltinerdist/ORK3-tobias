-- Restructure competition date/time fields:
--   competition_date   -- a single date for the show (no time portion)
--   entries_due_at     -- moment entries must be submitted by
--   judging_starts_at  -- judges start scoring
--   judging_ends_at    -- judging window closes
-- Legacy start_date_time/end_date_time/judging_deadline stay for backward compat
-- and are kept in sync by SaveCompetition.

ALTER TABLE ork_as_competition
  ADD COLUMN IF NOT EXISTS competition_date  DATE     DEFAULT NULL AFTER event_id,
  ADD COLUMN IF NOT EXISTS entries_due_at    DATETIME DEFAULT NULL AFTER competition_date,
  ADD COLUMN IF NOT EXISTS judging_starts_at DATETIME DEFAULT NULL AFTER entries_due_at,
  ADD COLUMN IF NOT EXISTS judging_ends_at   DATETIME DEFAULT NULL AFTER judging_starts_at;

-- Backfill only the fields that map cleanly from legacy data:
--   competition_date <- date portion of the legacy event span
--   entries_due_at   <- legacy judging_deadline (the submission cutoff)
-- The legacy start/end_date_time described the EVENT span, not the judging window,
-- so mapping them onto judging_starts_at/judging_ends_at was wrong (F55). Leave those
-- two NULL for pre-migration rows; the app will populate them going forward.
UPDATE ork_as_competition
SET competition_date = COALESCE(DATE(start_date_time), DATE(end_date_time), DATE(judging_deadline)),
    entries_due_at   = judging_deadline
WHERE competition_date IS NULL;
