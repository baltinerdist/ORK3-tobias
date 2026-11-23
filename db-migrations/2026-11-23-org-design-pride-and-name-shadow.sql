-- Org design: Amtpride nameplate + name shadow for Kingdom / Park / Unit.
--
-- Brings two player Design My Profile options to the org profiles:
--   hero_gradient  Amtpride preset key (validated against the keys of
--                  system/lib/ork3/pride_gradients.php). When set it replaces
--                  the primary/secondary hero background. '' = off.
--   name_shadow    1 = draw a crisp halo behind the org name and tagline so
--                  they stay legible over light backgrounds. 0 = off.
--
-- Same column shapes as ork_mundane_design (2026-05-19 hero_gradient,
-- 2026-05-29 name_shadow). NOT NULL with defaults: yapo drops nulls on UPDATE.
-- Must sort after the three *_design CREATE migrations (2026-05-16/17).
-- Idempotent.

ALTER TABLE ork_kingdom_design
    ADD COLUMN IF NOT EXISTS hero_gradient VARCHAR(32) NOT NULL DEFAULT '' AFTER color_secondary,
    ADD COLUMN IF NOT EXISTS name_shadow   TINYINT(1)  NOT NULL DEFAULT 0  AFTER name_font;

ALTER TABLE ork_park_design
    ADD COLUMN IF NOT EXISTS hero_gradient VARCHAR(32) NOT NULL DEFAULT '' AFTER color_secondary,
    ADD COLUMN IF NOT EXISTS name_shadow   TINYINT(1)  NOT NULL DEFAULT 0  AFTER name_font;

ALTER TABLE ork_unit_design
    ADD COLUMN IF NOT EXISTS hero_gradient VARCHAR(32) NOT NULL DEFAULT '' AFTER color_secondary,
    ADD COLUMN IF NOT EXISTS name_shadow   TINYINT(1)  NOT NULL DEFAULT 0  AFTER name_font;
