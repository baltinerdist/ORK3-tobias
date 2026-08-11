-- Allow one desktop and one phone-browser session to coexist per user.
--
-- Previously a single `token` slot per user meant any new login overwrote it,
-- and the Controller logged out every session whose token no longer matched.
-- We add a second slot dedicated to mobile (phone) browser sessions so the two
-- device classes no longer evict each other. Login writes only the slot for the
-- requesting device class; the session check accepts a match against either.

ALTER TABLE `ork_mundane`
  ADD COLUMN `token_mobile` varchar(35) NOT NULL DEFAULT '' AFTER `token`,
  ADD COLUMN `token_mobile_expires` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' AFTER `token_expires`,
  ADD KEY `token_mobile` (`token_mobile`);
