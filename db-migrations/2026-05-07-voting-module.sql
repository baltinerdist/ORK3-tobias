-- Voting module schema
-- See docs/superpowers/specs/2026-05-07-voting-module-design.md
--
-- Tables: 9 (event, runner ACL, race, choice, ballot, active_ballot pointer,
--             vote, audit, eligibility_snapshot)

CREATE TABLE `ork_voting_event` (
    `voting_event_id` int(11) NOT NULL AUTO_INCREMENT,
    `event_type` ENUM('election','althing') NOT NULL,
    `scope_type` ENUM('kingdom','park') NOT NULL,
    `scope_id` int(11) NOT NULL,
    `title` varchar(255) NOT NULL,
    `description` text DEFAULT NULL,
    `start_date` datetime NOT NULL,
    `end_date` datetime NOT NULL,
    `anonymous_to_runner` tinyint(1) NOT NULL DEFAULT 0,
    `hide_results_from_candidate_runners` tinyint(1) NOT NULL DEFAULT 1,
    `allow_provisional` tinyint(1) NOT NULL DEFAULT 1,
    `status` ENUM('draft','open','closed','published','unpublished') NOT NULL DEFAULT 'draft',
    `published_at` datetime DEFAULT NULL,
    `published_by_mundane_id` int(11) DEFAULT NULL,
    `tally_snapshot` longtext DEFAULT NULL,    -- JSON, frozen at publish
    `created_by_mundane_id` int(11) NOT NULL,
    `created_at` datetime NOT NULL DEFAULT current_timestamp(),
    `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
    PRIMARY KEY (`voting_event_id`),
    KEY `scope_status_end` (`scope_type`, `scope_id`, `status`, `end_date`),
    KEY `created_by` (`created_by_mundane_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `ork_voting_runner` (
    `voting_event_id` int(11) NOT NULL,
    `mundane_id` int(11) NOT NULL,
    `created_at` datetime NOT NULL DEFAULT current_timestamp(),
    PRIMARY KEY (`voting_event_id`, `mundane_id`),
    KEY `mundane_id` (`mundane_id`),
    CONSTRAINT `fk_vt_runner_event` FOREIGN KEY (`voting_event_id`) REFERENCES `ork_voting_event` (`voting_event_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `ork_voting_race` (
    `voting_race_id` int(11) NOT NULL AUTO_INCREMENT,
    `voting_event_id` int(11) NOT NULL,
    `race_type` ENUM('position','yesno','multichoice') NOT NULL,
    `voting_mode` ENUM('majority','plurality','irv') NOT NULL DEFAULT 'plurality',
    `title` varchar(255) NOT NULL,
    `rationale` text DEFAULT NULL,
    `position_id` int(11) DEFAULT NULL,
    `allow_abstain` tinyint(1) NOT NULL DEFAULT 1,
    `allow_none_of_above` tinyint(1) NOT NULL DEFAULT 0,
    `nota_counts_as` ENUM('no','abstain') DEFAULT NULL,
    `is_non_binding` tinyint(1) NOT NULL DEFAULT 0,
    `display_order` int(11) NOT NULL DEFAULT 0,
    `tie_resolved_winner_choice_id` int(11) DEFAULT NULL,
    `tie_resolution_note` text DEFAULT NULL,
    `tie_resolution_at` datetime DEFAULT NULL,
    `tie_resolved_by_mundane_id` int(11) DEFAULT NULL,
    PRIMARY KEY (`voting_race_id`),
    KEY `event_order` (`voting_event_id`, `display_order`),
    CONSTRAINT `fk_vt_race_event` FOREIGN KEY (`voting_event_id`) REFERENCES `ork_voting_event` (`voting_event_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `ork_voting_choice` (
    `voting_choice_id` int(11) NOT NULL AUTO_INCREMENT,
    `voting_race_id` int(11) NOT NULL,
    `candidate_mundane_id` int(11) DEFAULT NULL,
    `label` varchar(255) NOT NULL,
    `display_order` int(11) NOT NULL DEFAULT 0,
    PRIMARY KEY (`voting_choice_id`),
    KEY `race_order` (`voting_race_id`, `display_order`),
    KEY `candidate` (`candidate_mundane_id`),
    CONSTRAINT `fk_vt_choice_race` FOREIGN KEY (`voting_race_id`) REFERENCES `ork_voting_race` (`voting_race_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `ork_voting_ballot` (
    `voting_ballot_id` int(11) NOT NULL AUTO_INCREMENT,
    `voting_event_id` int(11) NOT NULL,
    `voter_mundane_id` int(11) NOT NULL,
    `is_provisional` tinyint(1) NOT NULL DEFAULT 0,
    `provisional_released_at` datetime DEFAULT NULL,
    `provisional_released_by_mundane_id` int(11) DEFAULT NULL,
    `entered_by_runner_id` int(11) DEFAULT NULL,
    `submitted_at` datetime NOT NULL DEFAULT current_timestamp(),
    `superseded_by_ballot_id` int(11) DEFAULT NULL,
    PRIMARY KEY (`voting_ballot_id`),
    KEY `event_voter_super` (`voting_event_id`, `voter_mundane_id`, `superseded_by_ballot_id`),
    KEY `event_provisional` (`voting_event_id`, `is_provisional`),
    CONSTRAINT `fk_vt_ballot_event` FOREIGN KEY (`voting_event_id`) REFERENCES `ork_voting_event` (`voting_event_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `ork_voting_active_ballot` (
    `voting_event_id` int(11) NOT NULL,
    `voter_mundane_id` int(11) NOT NULL,
    `voting_ballot_id` int(11) NOT NULL,
    PRIMARY KEY (`voting_event_id`, `voter_mundane_id`),
    KEY `ballot` (`voting_ballot_id`),
    CONSTRAINT `fk_vt_active_event` FOREIGN KEY (`voting_event_id`) REFERENCES `ork_voting_event` (`voting_event_id`) ON DELETE CASCADE,
    CONSTRAINT `fk_vt_active_ballot` FOREIGN KEY (`voting_ballot_id`) REFERENCES `ork_voting_ballot` (`voting_ballot_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `ork_voting_vote` (
    `voting_vote_id` int(11) NOT NULL AUTO_INCREMENT,
    `voting_ballot_id` int(11) NOT NULL,
    `voting_race_id` int(11) NOT NULL,
    `voting_choice_id` int(11) DEFAULT NULL,
    `rank` int(11) DEFAULT NULL,
    `is_abstain` tinyint(1) NOT NULL DEFAULT 0,
    `is_none_of_above` tinyint(1) NOT NULL DEFAULT 0,
    PRIMARY KEY (`voting_vote_id`),
    KEY `race_ballot` (`voting_race_id`, `voting_ballot_id`),
    KEY `ballot_race` (`voting_ballot_id`, `voting_race_id`),
    CONSTRAINT `fk_vt_vote_ballot` FOREIGN KEY (`voting_ballot_id`) REFERENCES `ork_voting_ballot` (`voting_ballot_id`) ON DELETE CASCADE,
    CONSTRAINT `fk_vt_vote_race` FOREIGN KEY (`voting_race_id`) REFERENCES `ork_voting_race` (`voting_race_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `ork_voting_audit` (
    `voting_audit_id` int(11) NOT NULL AUTO_INCREMENT,
    `voting_event_id` int(11) NOT NULL,
    `actor_mundane_id` int(11) DEFAULT NULL,
    `action` varchar(64) NOT NULL,
    `detail` longtext DEFAULT NULL,
    `created_at` datetime NOT NULL DEFAULT current_timestamp(),
    PRIMARY KEY (`voting_audit_id`),
    KEY `event_created` (`voting_event_id`, `created_at`),
    KEY `actor` (`actor_mundane_id`),
    CONSTRAINT `fk_vt_audit_event` FOREIGN KEY (`voting_event_id`) REFERENCES `ork_voting_event` (`voting_event_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `ork_voting_eligibility_snapshot` (
    `voting_event_id` int(11) NOT NULL,
    `mundane_id` int(11) NOT NULL,
    `eligible` tinyint(1) NOT NULL,
    `was_provisional` tinyint(1) NOT NULL DEFAULT 0,
    `source_rules` longtext DEFAULT NULL,
    `evaluated_at` datetime NOT NULL DEFAULT current_timestamp(),
    PRIMARY KEY (`voting_event_id`, `mundane_id`),
    KEY `mundane_id` (`mundane_id`),
    CONSTRAINT `fk_vt_snap_event` FOREIGN KEY (`voting_event_id`) REFERENCES `ork_voting_event` (`voting_event_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
