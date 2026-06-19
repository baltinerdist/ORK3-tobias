-- Voting Reopen Configuration & Impact-on-Save
-- See docs/superpowers/specs/2026-05-09-voting-reopen-and-impact-design.md

ALTER TABLE `ork_voting_choice`
    ADD COLUMN `withdrawn_at` datetime DEFAULT NULL,
    ADD COLUMN `withdrawn_by_mundane_id` int(11) DEFAULT NULL,
    ADD COLUMN `original_label` varchar(255) DEFAULT NULL;

ALTER TABLE `ork_voting_race`
    ADD COLUMN `original_title` varchar(255) DEFAULT NULL,
    ADD COLUMN `original_rationale` text DEFAULT NULL;

ALTER TABLE `ork_voting_event`
    ADD COLUMN `reopened_at` datetime DEFAULT NULL,
    ADD COLUMN `reopened_by_mundane_id` int(11) DEFAULT NULL;
