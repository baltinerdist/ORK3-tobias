-- Shortcut links (/me/ vanity redirects) — 2026-06-30
--
-- One row per CUSTOM stub. Derived defaults (pl46193, k17, p293, u3441) are
-- computed at resolve time and never stored here.
--
-- uq_slug      : a slug is globally unique across all entity types.
-- uq_entity    : an entity has at most ONE custom stub; changing it is an
--                in-place UPDATE of `slug`, which instantly frees the old slug.
--
-- Re-runnable: CREATE TABLE IF NOT EXISTS is a no-op once applied.

CREATE TABLE IF NOT EXISTS `ork_shortlink` (
  `shortlink_id` int(11)      NOT NULL AUTO_INCREMENT,
  `slug`         varchar(30)  NOT NULL,
  `entity_type`  enum('player','kingdom','park','unit') NOT NULL,
  `entity_id`    int(11)      NOT NULL,
  `created_by`   int(11)      NOT NULL DEFAULT 0,
  `created`      timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `modified`     timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`shortlink_id`),
  UNIQUE KEY `uq_slug` (`slug`),
  UNIQUE KEY `uq_entity` (`entity_type`, `entity_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
