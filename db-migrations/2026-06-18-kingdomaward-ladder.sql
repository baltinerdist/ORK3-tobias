-- Kingdom Ladders (Phase C): let a kingdom-original award be tracked as a leveled
-- "Order" with a kingdom-defined max level. Backfill the legacy $pseudoLadderIds
-- so existing kingdom pseudo-ladders keep working once that hardcoded list is retired.
ALTER TABLE ork_kingdomaward
  ADD COLUMN is_ladder tinyint(1) NOT NULL DEFAULT 0 AFTER award_id,
  ADD COLUMN max_level tinyint(1) NOT NULL DEFAULT 0 AFTER is_ladder;

UPDATE ork_kingdomaward
   SET is_ladder = 1, max_level = 10
 WHERE kingdomaward_id IN (7067,7249,6628,5813,6045,6050,6430,6283,7055,
                           6403,6297,7273,7070,6311,6310,7277,6411,6771,
                           6577,94,7084,6171,6574,7254);
