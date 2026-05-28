-- Dedup: collapse the 'score' bracket method into 'points'. Conceptually identical
-- (per-round scored format), so the UI now only exposes 'points'. Existing score
-- brackets (if any) become points brackets; enum value 'score' is dropped.
UPDATE ork_bracket SET method = 'points' WHERE method = 'score';

ALTER TABLE ork_bracket
  MODIFY method enum('single','double','swiss','round-robin','ironman','points')
    NOT NULL DEFAULT 'single';
