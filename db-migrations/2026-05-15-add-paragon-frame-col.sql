-- Paragon Photo Frame: per-player choice of which Paragon class to render as the
-- circular ring around their hero portrait on Playernew.
--   NULL → auto-mode: render the most-recently-awarded Paragon's class color
--   0    → "No Frame" (explicit opt-out)
--   >0   → explicit class_id (validated server-side against player's actual Paragons)
ALTER TABLE ork_mundane_design
  ADD COLUMN paragon_frame_class_id INT NULL DEFAULT NULL AFTER belt_display;
