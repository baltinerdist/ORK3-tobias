-- Knight Color Shimmer toggle: when ON, the player's hero name gets a brief
-- color sweep every ~10 seconds in their knighthood color(s). Cycles through
-- multiple belts if the player holds more than one.
ALTER TABLE ork_mundane_design
  ADD COLUMN name_shimmer TINYINT(1) UNSIGNED NOT NULL DEFAULT 0 AFTER paragon_frame_class_id;
