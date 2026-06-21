-- Notifications system (in-app) — one row per recipient (fan-out).
-- Additive / non-destructive. Applied manually (no runner).
-- Design: docs/superpowers/specs/2026-06-20-notifications-system-design.md

-- Fresh install: create the table to spec.
CREATE TABLE IF NOT EXISTS `ork_notification` (
  `notification_id` int(11) NOT NULL AUTO_INCREMENT,
  `mundane_id` int(11) NOT NULL,
  `type` varchar(32) NOT NULL,
  `title` varchar(255) NOT NULL,
  `body` text DEFAULT NULL,
  `icon` varchar(64) DEFAULT NULL,
  `link_url` varchar(512) DEFAULT NULL,
  `payload` text DEFAULT NULL,
  `read_at` datetime DEFAULT NULL,
  `dismissed_at` datetime DEFAULT NULL,
  `created_by` int(11) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`notification_id`),
  KEY `recipient_panel` (`mundane_id`, `dismissed_at`, `created_at`),
  KEY `recipient_unread` (`mundane_id`, `read_at`, `dismissed_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Reconcile an existing (pre-spec) ork_notification to the authoritative columns.
-- Each statement is guarded so re-running is a no-op. MariaDB/MySQL 8 support
-- IF NOT EXISTS on ADD COLUMN/INDEX; the IF EXISTS / IGNORE wrapping keeps this
-- safe across engines that already have the spec columns.
ALTER TABLE `ork_notification`
  ADD COLUMN IF NOT EXISTS `title`      varchar(255) NOT NULL DEFAULT '' AFTER `type`,
  ADD COLUMN IF NOT EXISTS `body`       text         DEFAULT NULL        AFTER `title`,
  ADD COLUMN IF NOT EXISTS `icon`       varchar(64)  DEFAULT NULL        AFTER `body`,
  ADD COLUMN IF NOT EXISTS `link_url`   varchar(512) DEFAULT NULL        AFTER `icon`,
  ADD COLUMN IF NOT EXISTS `payload`    text         DEFAULT NULL        AFTER `link_url`,
  ADD COLUMN IF NOT EXISTS `created_by` int(11)      DEFAULT NULL        AFTER `dismissed_at`;

ALTER TABLE `ork_notification`
  ADD INDEX IF NOT EXISTS `recipient_panel` (`mundane_id`, `dismissed_at`, `created_at`);

ALTER TABLE `ork_notification`
  ADD INDEX IF NOT EXISTS `recipient_unread` (`mundane_id`, `read_at`, `dismissed_at`);

-- If a pre-spec table carried a NOT-NULL legacy `message` column that the spec
-- contract never populates, give it an empty default so spec-shaped INSERTs
-- (which omit it) still succeed. Guarded via information_schema so it is a no-op
-- on fresh installs (column absent) and harmless to re-run.
SET @legacy_message := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'ork_notification'
    AND COLUMN_NAME = 'message'
);
SET @ddl := IF(@legacy_message > 0,
  "ALTER TABLE `ork_notification` MODIFY COLUMN `message` varchar(400) NOT NULL DEFAULT ''",
  'SELECT 1');
PREPARE _stmt FROM @ddl;
EXECUTE _stmt;
DEALLOCATE PREPARE _stmt;
