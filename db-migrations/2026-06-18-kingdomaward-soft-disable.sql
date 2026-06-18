-- Soft-disable for kingdom awards.
-- Disabled awards are hidden from the grant flow and award modals
-- but retained for historical records (existing grants are unaffected).
ALTER TABLE ork_kingdomaward
  ADD COLUMN `disabled` tinyint(1) NOT NULL DEFAULT 0 AFTER `title_class`;
