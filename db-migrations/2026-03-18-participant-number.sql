-- Add participant_number: auto-increments per tournament, same person across brackets keeps same number

ALTER TABLE ork_participant ADD COLUMN IF NOT EXISTS participant_number INT NOT NULL DEFAULT 0;

-- Backfill: each distinct person per tournament gets a sequential number ordered by first appearance
-- Person identity = mundane_id (if linked) else unique per participant_id

CREATE TEMPORARY TABLE _pnum AS
SELECT
    sub.tournament_id,
    sub.person_key,
    ROW_NUMBER() OVER (PARTITION BY sub.tournament_id ORDER BY MIN(sub.participant_id)) AS num
FROM (
    SELECT
        p.participant_id,
        p.tournament_id,
        COALESCE(NULLIF(pm.mundane_id, 0), -p.participant_id) AS person_key
    FROM ork_participant p
    LEFT JOIN ork_participant_mundane pm ON pm.participant_id = p.participant_id
) sub
GROUP BY sub.tournament_id, sub.person_key;

UPDATE ork_participant p
LEFT JOIN ork_participant_mundane pm ON pm.participant_id = p.participant_id
JOIN _pnum m
    ON  m.tournament_id = p.tournament_id
    AND m.person_key = COALESCE(NULLIF(pm.mundane_id, 0), -p.participant_id)
SET p.participant_number = m.num;

DROP TEMPORARY TABLE IF EXISTS _pnum;
