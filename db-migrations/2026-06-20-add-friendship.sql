-- Friends system — mutual friendship graph + directional block list.
-- Additive / non-destructive. Applied manually (no runner).
-- Design: docs/superpowers/specs/2026-06-20-friends-system-design.md

-- One row per relationship, canonically ordered (mundane_lo < mundane_hi) so a
-- pair can never duplicate. status: pending|accepted. requested_by records who
-- initiated (direction for pending). Decline/cancel/unfriend DELETE the row.
CREATE TABLE IF NOT EXISTS `ork_friendship` (
  `friendship_id` int(11) NOT NULL AUTO_INCREMENT,
  `mundane_lo`    int(11) NOT NULL,
  `mundane_hi`    int(11) NOT NULL,
  `status`        enum('pending','accepted') NOT NULL DEFAULT 'pending',
  `requested_by`  int(11) NOT NULL,
  `requested_at`  datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `responded_at`  datetime DEFAULT NULL,
  PRIMARY KEY (`friendship_id`),
  UNIQUE KEY `uniq_pair` (`mundane_lo`, `mundane_hi`),
  KEY `by_lo` (`mundane_lo`, `status`),
  KEY `by_hi` (`mundane_hi`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Directional block: blocker prevents blocked from sending them a request.
-- Orthogonal to friendship (does NOT unfriend or hide anything).
CREATE TABLE IF NOT EXISTS `ork_friend_block` (
  `block_id`   int(11) NOT NULL AUTO_INCREMENT,
  `blocker_id` int(11) NOT NULL,
  `blocked_id` int(11) NOT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`block_id`),
  UNIQUE KEY `uniq_block` (`blocker_id`, `blocked_id`),
  KEY `by_blocked` (`blocked_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
