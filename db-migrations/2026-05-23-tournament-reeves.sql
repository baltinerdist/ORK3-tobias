-- Tournament Reeves: per-tournament staff roles (Feature 2)
-- 2026-05-23
--
-- One row per (tournament, mundane). Re-adding a person updates their role
-- via INSERT ... ON DUPLICATE KEY UPDATE on the unique key.
-- Roles:
--   organizer      — full manage rights for this tournament (passes check_auth)
--   bracket_runner — record match results / resets only (passes can_run_brackets)
-- Engine/charset match the other ork_tournament_* tables (MyISAM / utf8mb4).

CREATE TABLE IF NOT EXISTS `ork_tournament_reeve` (
  `tournament_reeve_id` int(11) NOT NULL AUTO_INCREMENT,
  `tournament_id` int(11) NOT NULL,
  `mundane_id` int(11) NOT NULL,
  `role` enum('organizer','bracket_runner') NOT NULL DEFAULT 'bracket_runner',
  `modified` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`tournament_reeve_id`),
  UNIQUE KEY `uq_tourn_mundane` (`tournament_id`,`mundane_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=1;
