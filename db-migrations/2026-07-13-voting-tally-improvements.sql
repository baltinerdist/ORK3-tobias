-- Voting tally & outcomes improvements (findings 11, 26, 33)
ALTER TABLE `ork_voting_race`
    ADD COLUMN `majority_denominator` ENUM('choice_votes','ballots_cast') NOT NULL DEFAULT 'choice_votes';
