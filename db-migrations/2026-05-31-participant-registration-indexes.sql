-- Registration/assignment support: speed up registrant lookups by stable number,
-- and roster/assignment scans. bracket_id is NOT NULL on both tables (existing schema);
-- no column change is needed here — nullability will be addressed in a separate migration
-- if/when the registration-vs-assignment split is introduced.
-- status is varchar(20) (not an enum), so no MODIFY is needed.

-- Stable-identity lookups (ensureRegistrant, GetRegistrants assignment join):
ALTER TABLE ork_participant
  ADD INDEX idx_participant_tourn_number (tournament_id, participant_number);

-- Roster scan (bracket_id IS NULL) and per-bracket entrant scan:
ALTER TABLE ork_participant
  ADD INDEX idx_participant_tourn_bracket (tournament_id, bracket_id);
