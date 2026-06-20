-- Restructure competition date/time fields:
--   competition_date   -- a single date for the show (no time portion)
--   entries_due_at     -- moment entries must be submitted by
--   judging_starts_at  -- judges start scoring
--   judging_ends_at    -- judging window closes
-- Legacy start_date_time/end_date_time/judging_deadline stay for backward compat
-- and are kept in sync by SaveCompetition.

ALTER TABLE ork_as_competition
  ADD COLUMN competition_date  DATE     DEFAULT NULL AFTER event_id,
  ADD COLUMN entries_due_at    DATETIME DEFAULT NULL AFTER competition_date,
  ADD COLUMN judging_starts_at DATETIME DEFAULT NULL AFTER entries_due_at,
  ADD COLUMN judging_ends_at   DATETIME DEFAULT NULL AFTER judging_starts_at;

UPDATE ork_as_competition
SET competition_date  = COALESCE(DATE(start_date_time), DATE(end_date_time), DATE(judging_deadline)),
    entries_due_at    = judging_deadline,
    judging_starts_at = start_date_time,
    judging_ends_at   = end_date_time
WHERE competition_date IS NULL;
