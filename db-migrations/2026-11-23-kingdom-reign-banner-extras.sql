-- Kingdom Current Reign banner: configurable header, Message from the Crown,
-- and a banner style.
--
--   reign_title    Header text; '' renders the default "Current Reign".
--   crown_message  Plain-text quote shown under the Monarch/Regent cards.
--   reign_theme    Banner style key (system/lib/ork3/reign_themes.php);
--                  '' renders the default 'gold'.
--
-- NOT NULL with '' defaults: yapo drops nulls on UPDATE. Positioned after
-- reign_lore, which 2026-05-18-org-design-extras.sql creates, so this must
-- sort after it. Idempotent.

ALTER TABLE ork_kingdom_design
    ADD COLUMN IF NOT EXISTS reign_title   VARCHAR(60)  NOT NULL DEFAULT '' AFTER reign_lore,
    ADD COLUMN IF NOT EXISTS crown_message VARCHAR(600) NOT NULL DEFAULT '' AFTER reign_title,
    ADD COLUMN IF NOT EXISTS reign_theme   VARCHAR(20)  NOT NULL DEFAULT '' AFTER crown_message;
