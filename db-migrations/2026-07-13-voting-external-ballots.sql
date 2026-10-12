-- Voting: dismissible "a paper ballot replaced your online ballot" notice.
-- NULL = voter has not dismissed the banner yet. Set to NOW() when the voter dismisses.
ALTER TABLE `ork_voting_ballot`
    ADD COLUMN `runner_notice_ack_at` DATETIME NULL DEFAULT NULL AFTER `superseded_by_ballot_id`;
