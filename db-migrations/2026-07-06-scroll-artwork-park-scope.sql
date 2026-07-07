-- 2026-07-06 · Scroll · add Park visibility tier + pack provenance to the artwork
-- library (ork_scroll_artwork). Additive + re-runnable-safe (matches the
-- ork_scroll_template 3-tier migration style).
--
-- visibility values: 'global' | 'kingdom' | 'park'. Authoritative scope column.
--   global  -> owner_kingdom_id NULL, owner_park_id NULL
--   kingdom -> owner_kingdom_id set,  owner_park_id NULL
--   park    -> owner_kingdom_id set (park's kingdom), owner_park_id set
--
-- source_kind: 'upload' (user submission) | 'pack' (built-in Amtgard-wide art pack).

ALTER TABLE ork_scroll_artwork
  MODIFY COLUMN visibility ENUM('global','kingdom','park') NOT NULL DEFAULT 'global',
  ADD COLUMN owner_park_id INT UNSIGNED NULL AFTER owner_kingdom_id,
  ADD COLUMN source_kind VARCHAR(10) NOT NULL DEFAULT 'upload' AFTER system_owned,
  ADD INDEX idx_owner_park_status (owner_park_id, status),
  ADD INDEX idx_source_kind (source_kind);

-- Down (commented):
-- ALTER TABLE ork_scroll_artwork
--   DROP INDEX idx_owner_park_status, DROP INDEX idx_source_kind,
--   DROP COLUMN source_kind, DROP COLUMN owner_park_id,
--   MODIFY COLUMN visibility ENUM('global','kingdom') NOT NULL DEFAULT 'global';
