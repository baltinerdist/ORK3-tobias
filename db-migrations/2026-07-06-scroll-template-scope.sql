-- 2026-07-06 · Scroll · 3-tier visibility scoping (Amtgard-wide / Kingdom / Park) on templates.
-- Mirrors ork_scroll_artwork's visibility/owner tiering. Additive + re-runnable-safe.
-- visibility values: 'global' | 'kingdom' | 'park'. Authoritative scope column.
--   global  -> kingdom_id NULL, park_id NULL, is_starter=1
--   kingdom -> kingdom_id set,  park_id NULL, is_starter=0
--   park    -> kingdom_id set (park's kingdom), park_id set, is_starter=0
ALTER TABLE `ork_scroll_template`
  ADD COLUMN `visibility` VARCHAR(10) NOT NULL DEFAULT 'kingdom' AFTER `kingdom_id`,
  ADD COLUMN `park_id` INT UNSIGNED NULL AFTER `visibility`,
  ADD INDEX `idx_visibility_status` (`visibility`, `status`),
  ADD INDEX `idx_park_status` (`park_id`, `status`);

-- Backfill: existing shared starters are Amtgard-wide (global). Non-starter rows
-- keep the 'kingdom' default (they already carry a kingdom_id).
UPDATE `ork_scroll_template` SET `visibility` = 'global' WHERE `is_starter` = 1;

-- Down (commented):
-- ALTER TABLE `ork_scroll_template`
--   DROP INDEX `idx_visibility_status`, DROP INDEX `idx_park_status`,
--   DROP COLUMN `park_id`, DROP COLUMN `visibility`;
