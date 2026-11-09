-- 2026-06-19 · Scroll Graphic Submissions · admin-managed thematic categories.

CREATE TABLE IF NOT EXISTS `ork_scroll_artwork_category` (
  `category_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `slug` VARCHAR(64) NOT NULL,
  `label` VARCHAR(120) NOT NULL,
  `sort_order` SMALLINT NOT NULL DEFAULT 0,
  `active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `modified` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`category_id`),
  UNIQUE KEY `uniq_slug` (`slug`),
  KEY `idx_active_sort` (`active`, `sort_order`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `ork_scroll_artwork_category` (slug, label, sort_order, active)
SELECT * FROM (
  SELECT 'heraldic' AS slug, 'Heraldic' AS label, 10 AS sort_order, 1 AS active UNION ALL
  SELECT 'celtic_knotwork', 'Celtic & Knotwork', 20, 1 UNION ALL
  SELECT 'floral_botanical', 'Floral & Botanical', 30, 1 UNION ALL
  SELECT 'norse_viking', 'Norse & Viking', 40, 1 UNION ALL
  SELECT 'religious_sacred', 'Religious & Sacred', 50, 1 UNION ALL
  SELECT 'geometric', 'Geometric', 60, 1 UNION ALL
  SELECT 'beasts_creatures', 'Beasts & Creatures', 70, 1 UNION ALL
  SELECT 'flourishes_dividers', 'Flourishes & Dividers', 80, 1 UNION ALL
  SELECT 'other', 'Other', 90, 1
) seed
WHERE NOT EXISTS (SELECT 1 FROM `ork_scroll_artwork_category` LIMIT 1);
