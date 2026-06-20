-- Supporting indexes for Arts & Sciences queries — 2026-06-20
--
-- Problem 1: DeleteCriterion runs `DELETE FROM ork_as_score WHERE criterion_id = ?`,
-- but ork_as_score only had indexes on entry_id and judge_id — never criterion_id.
-- That delete (fired whenever a competition's scoring criterion is removed) did a
-- full table scan of every score row. This index lets it seek directly.
--
-- Problem 2 (verified, no change needed): compute_ladder_counts_for_participants and
-- annotate_guild_ladders JOIN ork_kingdomaward filtering by award_id. ork_kingdomaward
-- already has KEY `award_id` (award_id) (see ork.sql), so no index is added here.
--
-- Safe to run on live production: CREATE INDEX ... IF NOT EXISTS uses online DDL in
-- MariaDB 10.x+ and does not block reads or writes during build.

CREATE INDEX IF NOT EXISTS idx_as_score_criterion
    ON ork_as_score (criterion_id);
