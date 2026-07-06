-- 2026-07-06 · Scroll · background opacity (0-100 %, 100 = opaque).
ALTER TABLE `ork_scroll_template`
  ADD COLUMN `bg_opacity` TINYINT UNSIGNED NOT NULL DEFAULT 100 AFTER `bg_fit`;
