-- Per-player toggles for the new hero accolade pieces (coronet + master phoenix).
-- Both default to 1 (show) so existing players see the new visuals automatically;
-- a player can opt out via the Special tab in Design My Profile if they prefer
-- a quieter hero. Toggles are only surfaced in the modal when the player actually
-- holds the corresponding accolade.
ALTER TABLE ork_mundane_design
  ADD COLUMN display_coronet TINYINT(1) NOT NULL DEFAULT 1 AFTER paragon_frame_class_id,
  ADD COLUMN display_master_phoenix TINYINT(1) NOT NULL DEFAULT 1 AFTER display_coronet;
