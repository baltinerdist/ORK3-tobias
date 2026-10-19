-- Arts & Sciences enhancements (second batch) — 2026-07-19
--
-- Adds the schema backing three cross-surface features:
--   * entrant-facing results sharing (share_with_entrants + entry.status),
--   * the immutable results snapshot written when a competition closes
--     (ork_as_result_snapshot + ork_as_winner), and
--   * a covering index for the hottest judge viewer-identity lookup.
--
-- Every statement is guarded with IF NOT EXISTS (or is a naturally-idempotent
-- MODIFY) so the whole file is safe to re-run on live production; the added
-- keys/columns build with MariaDB 10.x+ online DDL and do not block reads/writes.

-- ---------------------------------------------------------------------------
-- [18] Composite index for the hottest viewer-identity lookup.
-- ---------------------------------------------------------------------------
-- The blind-judging / "am I a judge on this competition?" checks repeatedly ask
-- "is mundane M a judge of competition C?". The base table only had single-column
-- idx_as_judge_comp (competition_id) and idx_as_judge_mundane (mundane_id), so
-- that two-column predicate could only seek on one side and scan the rest. This
-- covering composite lets it seek straight to the (competition_id, mundane_id)
-- pair — the dominant access pattern for GetMyEntries/GetMyEntryResults and the
-- anonymous-judging identity guard.
CREATE INDEX IF NOT EXISTS idx_as_judge_comp_mundane
    ON ork_as_judge (competition_id, mundane_id);

-- ---------------------------------------------------------------------------
-- [19] Make ork_as_score.scored_at track the last write.
-- ---------------------------------------------------------------------------
-- scored_at was DEFAULT CURRENT_TIMESTAMP only (set on INSERT, never touched on
-- UPDATE), so a judge revising a score left scored_at pinned to the original
-- entry time. Adding ON UPDATE CURRENT_TIMESTAMP makes it a true "last scored"
-- timestamp, which the results snapshot and feedback surfaces rely on to order
-- and freshness-check scores. We deliberately keep it NULL-able with the same
-- CURRENT_TIMESTAMP default so existing rows and inserts behave exactly as before
-- (MODIFY re-states the full column definition, so re-running is a no-op).
ALTER TABLE ork_as_score
    MODIFY scored_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP;

-- ---------------------------------------------------------------------------
-- [40-col] Competition-level entrant results sharing.
-- ---------------------------------------------------------------------------
-- share_with_entrants controls what, if anything, an entrant may see about their
-- own entry's judging AFTER the competition closes. Four modes:
--   'none'            — entrants see nothing (default; preserves current behavior).
--   'feedback'        — entrants see judges' written feedback, but no numeric scores.
--   'scores'          — entrants see numeric scores/aggregates, but no written feedback.
--   'scores_feedback' — entrants see both scores and feedback.
-- Judge identity stays blind in every mode; the lib (GetMyEntryResults) enforces
-- ownership, the status='closed' gate, and this sharing setting.
ALTER TABLE ork_as_competition
    ADD COLUMN IF NOT EXISTS share_with_entrants
        ENUM('none','feedback','scores','scores_feedback') NOT NULL DEFAULT 'none'
        AFTER anonymous_judging;

-- ---------------------------------------------------------------------------
-- [39-col] Entry lifecycle status.
-- ---------------------------------------------------------------------------
-- status tracks an entry through the competition. 'registered' (default) and
-- 'checked_in' are live entries counted in results; 'withdrawn' and
-- 'disqualified' are EXCLUDED from results computation, the leaderboard, and the
-- snapshot (the lib filters them out). Defaulting to 'registered' keeps every
-- existing entry live.
ALTER TABLE ork_as_entry
    ADD COLUMN IF NOT EXISTS status
        ENUM('registered','checked_in','withdrawn','disqualified') NOT NULL DEFAULT 'registered';

-- ---------------------------------------------------------------------------
-- [11-tables] Immutable results snapshot, written on competition close.
-- ---------------------------------------------------------------------------
-- When a competition transitions to 'closed' the lib computes the full results
-- bundle once and freezes it here, so later edits to scores/entries/awards can
-- never retroactively rewrite a published result. ork_as_result_snapshot holds
-- the whole computed bundle as JSON (leaderboard, per-field standings, aggregates,
-- redaction map) plus provenance (who/when/which aggregation method); ork_as_winner
-- is the flattened, queryable winners list derived from that same computation so
-- award grants and reports can join without re-parsing the JSON.
CREATE TABLE IF NOT EXISTS ork_as_result_snapshot (
    snapshot_id         INT AUTO_INCREMENT PRIMARY KEY,
    competition_id      INT NOT NULL,
    -- Full computed results bundle (leaderboard, standings, aggregates, redaction
    -- map) serialized as JSON. LONGTEXT so large competitions are never truncated.
    payload_json        LONGTEXT NOT NULL,
    -- Aggregation method in force at close time, captured so the frozen numbers
    -- remain interpretable even if the competition's method is later changed.
    aggregation_method  ENUM('average','sum','median','drop_high','drop_low','drop_both') NOT NULL DEFAULT 'average',
    closed_by           INT DEFAULT NULL,
    closed_at           TIMESTAMP NULL DEFAULT NULL,
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_as_snapshot_comp (competition_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Flattened winners derived from the snapshot computation. `rank` is backticked
-- because it is a reserved word in MariaDB 10.2+. place_label is the human-facing
-- placement ("1st", "Best in Show", "Honorable Mention"); warnings carries any
-- tie/insufficient-judges caveats surfaced at close.
CREATE TABLE IF NOT EXISTS ork_as_winner (
    winner_id       INT AUTO_INCREMENT PRIMARY KEY,
    competition_id  INT NOT NULL,
    award_id        INT DEFAULT NULL,
    entry_id        INT DEFAULT NULL,
    participant_id  INT DEFAULT NULL,
    mundane_id      INT DEFAULT NULL,
    aggregate       DECIMAL(6,2) DEFAULT NULL,
    `rank`          INT DEFAULT NULL,
    place_label     VARCHAR(120) DEFAULT NULL,
    warnings        TEXT,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_as_winner_comp (competition_id),
    INDEX idx_as_winner_award (award_id),
    INDEX idx_as_winner_entry (entry_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
