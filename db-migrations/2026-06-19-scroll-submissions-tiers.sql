-- 2026-06-19 · Scroll Graphic Submissions · add sharing-tier + category columns
-- to ork_scroll_artwork. Additive + re-runnable-safe.

ALTER TABLE ork_scroll_artwork
  ADD COLUMN visibility ENUM('global','kingdom') NOT NULL DEFAULT 'global' AFTER status,
  ADD COLUMN owner_kingdom_id INT UNSIGNED NULL AFTER visibility,
  ADD COLUMN category_id INT UNSIGNED NULL AFTER owner_kingdom_id,
  ADD INDEX idx_vis_status_loc (visibility, status, layout_location),
  ADD INDEX idx_owner_kingdom_status (owner_kingdom_id, status);

-- Down (commented):
-- ALTER TABLE ork_scroll_artwork
--   DROP INDEX idx_vis_status_loc, DROP INDEX idx_owner_kingdom_status,
--   DROP COLUMN category_id, DROP COLUMN owner_kingdom_id, DROP COLUMN visibility;
