-- 2026-07-03 · Scroll · slot-based template store.
CREATE TABLE `ork_scroll_template` (
  `scroll_template_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `kingdom_id`  INT UNSIGNED NULL,                              -- NULL = shared starter
  `name`        VARCHAR(150) NOT NULL,
  `orientation` ENUM('portrait','landscape') NOT NULL DEFAULT 'portrait',
  `bg_type`     ENUM('color','texture','image') NOT NULL DEFAULT 'color',
  `bg_value`    VARCHAR(255) NOT NULL DEFAULT '#ffffff',
  `slots`       JSON NOT NULL,
  `zones`       JSON NOT NULL,
  `is_starter`  TINYINT(1) NOT NULL DEFAULT 0,
  `status`      ENUM('active','archived') NOT NULL DEFAULT 'active',
  `created_by`  INT UNSIGNED NOT NULL,
  `created_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `modified`    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`scroll_template_id`),
  KEY `idx_kingdom_status` (`kingdom_id`, `status`),
  KEY `idx_starter` (`is_starter`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
