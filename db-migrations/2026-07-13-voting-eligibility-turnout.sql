-- Voting: freeze the eligible electorate + turnout at publish.
-- Producer contract for the Tally/quorum domain: eligible_count is the immutable
-- quorum denominator, ballots_cast the turnout numerator, both stamped at Publish().
-- The frozen eligible SET lives in ork_voting_eligibility_snapshot (eligible = 1 rows).

ALTER TABLE `ork_voting_event`
    ADD COLUMN `eligible_count` int(11) NOT NULL DEFAULT 0 AFTER `tally_snapshot`,
    ADD COLUMN `ballots_cast`   int(11) NOT NULL DEFAULT 0 AFTER `eligible_count`;
