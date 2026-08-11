-- 2026-07-06 · Scroll · background image fit mode (tile / fill / stretch).
ALTER TABLE `ork_scroll_template`
  ADD COLUMN `bg_fit` ENUM('tile','fill','stretch') NOT NULL DEFAULT 'tile' AFTER `bg_value`;
