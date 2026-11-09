-- 2026-07-04 · Scroll · persist the knotwork border config (was client-only; never saved).
-- knot is a JSON object (see scroll-design.js KNOT_PRESETS shape) or NULL = no border.
ALTER TABLE ork_scroll_template ADD COLUMN knot JSON NULL AFTER award_keys;
