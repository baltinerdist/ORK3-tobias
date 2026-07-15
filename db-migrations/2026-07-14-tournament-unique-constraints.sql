-- Uniqueness backstops for the tournament registration / assignment races (#40, #99, #100).
--
-- Runs AFTER the tables + columns it constrains exist:
--   ork_point_score          (2026-05-28-add-points-bracket.sql)
--   ork_participant.participant_number (2026-03-18-participant-number.sql)
--   ork_participant_teams.team_number  (2026-06-01-team-registration.sql)
--
-- DATA MODEL: registration rows and per-bracket entrant rows share one table each,
-- distinguished by bracket_id (NULL = tournament-level registration, NOT NULL = bracket
-- entrant), and they intentionally SHARE the same participant_number / team_number across
-- brackets. A plain UNIQUE(tournament_id, participant_number) is therefore impossible on
-- the combined table. We enforce:
--   * registration-scoped uniqueness via a nullable generated column narrowed to the
--     bracket_id-IS-NULL rows (yapo never writes nullable/generated columns, so INSERT
--     paths are unaffected), and
--   * per-bracket entrant uniqueness via a composite index; the bracket_id-IS-NULL
--     registration rows carry a NULL in the key tuple and are excluded from enforcement.
-- ork_participant is MyISAM (its START TRANSACTION guard is a no-op), so these indexes are
-- the only real backstop for the number-allocation race. The lib layer is being updated
-- to catch the resulting duplicate-key errors and retry.
--
-- Idempotent: dedupe passes are no-ops once clean; all index/column adds use IF NOT EXISTS.

-- =====================================================================================
-- ork_point_score — enforce one score cell per (bracket, participant, round)  [#40]
-- (The CREATE TABLE already declares uq_cell; this repairs any table created without it.)
-- =====================================================================================
DELETE ps FROM ork_point_score ps
  JOIN (
    SELECT point_score_id FROM (
      SELECT point_score_id,
             ROW_NUMBER() OVER (PARTITION BY bracket_id, participant_id, round
                                ORDER BY point_score_id) AS rn
      FROM ork_point_score
    ) z WHERE z.rn > 1
  ) d ON d.point_score_id = ps.point_score_id;

ALTER TABLE ork_point_score
  ADD UNIQUE INDEX IF NOT EXISTS uq_cell (bracket_id, participant_id, round);

-- =====================================================================================
-- ork_participant — per-bracket entrant uniqueness  [#100]
--   UNIQUE(tournament_id, bracket_id, participant_number); NULL bracket_id (registration)
--   rows are excluded automatically.
-- =====================================================================================
-- Dedupe duplicate entrant rows (same number twice in one bracket) — race artifacts.
DELETE pm FROM ork_participant_mundane pm
  WHERE pm.participant_id IN (
    SELECT participant_id FROM (
      SELECT participant_id FROM (
        SELECT participant_id,
               ROW_NUMBER() OVER (PARTITION BY tournament_id, bracket_id, participant_number
                                  ORDER BY participant_id) AS rn
        FROM ork_participant
        WHERE bracket_id IS NOT NULL AND participant_number > 0
      ) z WHERE z.rn > 1
    ) d
  );

DELETE FROM ork_participant
  WHERE participant_id IN (
    SELECT participant_id FROM (
      SELECT participant_id FROM (
        SELECT participant_id,
               ROW_NUMBER() OVER (PARTITION BY tournament_id, bracket_id, participant_number
                                  ORDER BY participant_id) AS rn
        FROM ork_participant
        WHERE bracket_id IS NOT NULL AND participant_number > 0
      ) z WHERE z.rn > 1
    ) d
  );

-- NOTE: team brackets store one ork_participant identity row per team with
-- participant_number = 0 (teams are uniqued separately via ork_participant_teams.team_number),
-- so the entrant index must exclude number = 0 rows (as well as bracket_id-IS-NULL
-- registration rows) or multiple teams in one bracket would collide. A generated column
-- narrows enforcement to real individual entrants (bracket_id NOT NULL AND number > 0).
ALTER TABLE ork_participant
  ADD COLUMN IF NOT EXISTS entrant_number_uk INT
    AS (IF(bracket_id IS NOT NULL AND participant_number > 0, participant_number, NULL)) PERSISTENT;
ALTER TABLE ork_participant
  ADD UNIQUE INDEX IF NOT EXISTS uq_participant_bracket_number
    (tournament_id, bracket_id, entrant_number_uk);

-- ork_participant — registration-scoped number uniqueness  [#99]
-- Generated column is NULL except on registration rows (bracket_id IS NULL, number > 0),
-- so the UNIQUE index enforces one registration per number per tournament only.
-- Dedupe duplicate registration rows first.
DELETE pm FROM ork_participant_mundane pm
  WHERE pm.participant_id IN (
    SELECT participant_id FROM (
      SELECT participant_id FROM (
        SELECT participant_id,
               ROW_NUMBER() OVER (PARTITION BY tournament_id, participant_number
                                  ORDER BY participant_id) AS rn
        FROM ork_participant
        WHERE bracket_id IS NULL AND participant_number > 0
      ) z WHERE z.rn > 1
    ) d
  );

DELETE FROM ork_participant
  WHERE participant_id IN (
    SELECT participant_id FROM (
      SELECT participant_id FROM (
        SELECT participant_id,
               ROW_NUMBER() OVER (PARTITION BY tournament_id, participant_number
                                  ORDER BY participant_id) AS rn
        FROM ork_participant
        WHERE bracket_id IS NULL AND participant_number > 0
      ) z WHERE z.rn > 1
    ) d
  );

ALTER TABLE ork_participant
  ADD COLUMN IF NOT EXISTS reg_number_uk INT
    AS (IF(bracket_id IS NULL AND participant_number > 0, participant_number, NULL)) PERSISTENT;
ALTER TABLE ork_participant
  ADD UNIQUE INDEX IF NOT EXISTS uq_participant_reg_number (tournament_id, reg_number_uk);

-- =====================================================================================
-- ork_participant_teams — per-bracket entrant + registration-scoped uniqueness  [#99/#100]
-- =====================================================================================
-- Dedupe duplicate team entrant rows (same team_number twice in one bracket).
DELETE ptm FROM ork_participant_team_members ptm
  WHERE ptm.team_id IN (
    SELECT team_id FROM (
      SELECT team_id FROM (
        SELECT team_id,
               ROW_NUMBER() OVER (PARTITION BY tournament_id, bracket_id, team_number
                                  ORDER BY team_id) AS rn
        FROM ork_participant_teams
        WHERE bracket_id IS NOT NULL AND team_number > 0
      ) z WHERE z.rn > 1
    ) d
  );

DELETE FROM ork_participant_teams
  WHERE team_id IN (
    SELECT team_id FROM (
      SELECT team_id FROM (
        SELECT team_id,
               ROW_NUMBER() OVER (PARTITION BY tournament_id, bracket_id, team_number
                                  ORDER BY team_id) AS rn
        FROM ork_participant_teams
        WHERE bracket_id IS NOT NULL AND team_number > 0
      ) z WHERE z.rn > 1
    ) d
  );

ALTER TABLE ork_participant_teams
  ADD UNIQUE INDEX IF NOT EXISTS uq_pteams_bracket_number
    (tournament_id, bracket_id, team_number);

-- Registration-scoped: one registration team per team_number per tournament.
DELETE ptm FROM ork_participant_team_members ptm
  WHERE ptm.team_id IN (
    SELECT team_id FROM (
      SELECT team_id FROM (
        SELECT team_id,
               ROW_NUMBER() OVER (PARTITION BY tournament_id, team_number
                                  ORDER BY team_id) AS rn
        FROM ork_participant_teams
        WHERE bracket_id IS NULL AND team_number > 0
      ) z WHERE z.rn > 1
    ) d
  );

DELETE FROM ork_participant_teams
  WHERE team_id IN (
    SELECT team_id FROM (
      SELECT team_id FROM (
        SELECT team_id,
               ROW_NUMBER() OVER (PARTITION BY tournament_id, team_number
                                  ORDER BY team_id) AS rn
        FROM ork_participant_teams
        WHERE bracket_id IS NULL AND team_number > 0
      ) z WHERE z.rn > 1
    ) d
  );

ALTER TABLE ork_participant_teams
  ADD COLUMN IF NOT EXISTS reg_team_number_uk INT
    AS (IF(bracket_id IS NULL AND team_number > 0, team_number, NULL)) PERSISTENT;
ALTER TABLE ork_participant_teams
  ADD UNIQUE INDEX IF NOT EXISTS uq_pteams_reg_number (tournament_id, reg_team_number_uk);
