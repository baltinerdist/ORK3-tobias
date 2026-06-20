-- Dynamic award formula support: a JSON column on ork_as_award holding
-- the eligibility / ranking / diversity / tiebreakers / winners spec.
ALTER TABLE ork_as_award
  ADD COLUMN rules LONGTEXT DEFAULT NULL AFTER novice_only;
