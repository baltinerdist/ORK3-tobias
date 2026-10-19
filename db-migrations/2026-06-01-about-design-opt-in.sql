-- Opt-in gate for the new Mask-II "About design" on each org profile.
--
-- The Mask-II profile-customization feature (commit 635896d7) is opt-in: a
-- non-opted-in org's PUBLIC profile renders its About exactly as production did
-- before Mask-II. Hero styling (colors/font/tagline/announcement/recruitment) is
-- NOT gated and always applies. Only the org's proper authority can flip this on.
--
-- Default 0 = not opted in, so every existing org keeps its current-production
-- About until an authorized officer enables the new design. Authorized managers
-- always preview the new About (and see an "Unpublished" badge) regardless.
--
-- Idempotent (IF NOT EXISTS). Depends on the *_design tables existing
-- (2026-05-16/2026-05-17 design migrations + org-design-extras).

ALTER TABLE ork_kingdom_design
    ADD COLUMN IF NOT EXISTS about_enabled TINYINT(1) NOT NULL DEFAULT 0 AFTER our_history;

ALTER TABLE ork_park_design
    ADD COLUMN IF NOT EXISTS about_enabled TINYINT(1) NOT NULL DEFAULT 0 AFTER our_history;

ALTER TABLE ork_unit_design
    ADD COLUMN IF NOT EXISTS about_enabled TINYINT(1) NOT NULL DEFAULT 0 AFTER our_history;
