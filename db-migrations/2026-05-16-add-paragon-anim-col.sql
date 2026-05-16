-- Per-player toggle for Paragon-class nameplate animations (Archer arrow,
-- Druid flowers, etc.). Only fires for players who actually hold one of the
-- supported Paragon classes; defaults to 1 so eligible players see the new
-- animation on first load.
ALTER TABLE ork_mundane_design
  ADD COLUMN display_paragon_animation TINYINT(1) NOT NULL DEFAULT 1 AFTER display_master_phoenix;
