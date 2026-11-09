-- 2026-07-04 · Scroll · persist the knotwork border config (was client-only; never saved).
-- knot is a JSON object ({enabled, style, color1, color2}; see scroll-border.js) or NULL = no border.
ALTER TABLE ork_scroll_template ADD COLUMN knot JSON NULL AFTER award_keys;
