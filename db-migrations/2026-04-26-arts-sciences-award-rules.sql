-- Dynamic award formula support: a JSON column on ork_as_award holding
-- the eligibility / ranking / diversity / tiebreakers / winners spec.
-- Typed JSON so the DB validates the payload; IF NOT EXISTS for re-run safety.
ALTER TABLE ork_as_award
  ADD COLUMN IF NOT EXISTS rules JSON DEFAULT NULL AFTER novice_only;
