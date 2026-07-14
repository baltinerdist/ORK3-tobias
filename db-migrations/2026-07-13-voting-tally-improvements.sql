-- Voting tally & outcomes improvements (findings 11, 26, 33)
ALTER TABLE `ork_voting_race`
    ADD COLUMN `majority_denominator` ENUM('choice_votes','ballots_cast') NOT NULL DEFAULT 'choice_votes';

-- Finding 26: optional per-event quorum / minimum turnout + override audit columns.
ALTER TABLE `ork_voting_event`
    ADD COLUMN `quorum_count` int(11) NOT NULL DEFAULT 0,
    ADD COLUMN `quorum_fraction` decimal(5,4) DEFAULT NULL,
    ADD COLUMN `quorum_overridden_at` datetime DEFAULT NULL,
    ADD COLUMN `quorum_overridden_by_mundane_id` int(11) DEFAULT NULL,
    ADD COLUMN `quorum_override_note` text DEFAULT NULL;
