-- Scroll artwork placement taxonomy cleanup.
-- Aligns the ork_scroll_artwork.layout_location vocabulary with the rebuilt
-- slot-based scroll designer + the built-in pack catalog. Collapses the
-- Scroll-Forge-era placements into the 4 the designer actually uses:
--     watermark                                  -> background
--     top_graphic                                -> center_image
--     border_left/right/top/bottom               -> border_side
-- Date: 2026-07-06   Branch: feature/scroll-generator (PR #6)

-- 1) Widen the enum to a superset so the new canonical values are assignable
--    before the remap. (MODIFY preserves the existing indexes on this column.)
ALTER TABLE `ork_scroll_artwork`
    MODIFY `layout_location` ENUM(
        'full_border','border_left','border_right','border_top','border_bottom',
        'center_image','watermark','top_graphic','border_side','background'
    ) NOT NULL;

-- 2) Remap existing rows (includes the 139 imported built-in pack rows).
UPDATE `ork_scroll_artwork` SET `layout_location` = 'background'
    WHERE `layout_location` = 'watermark';
UPDATE `ork_scroll_artwork` SET `layout_location` = 'center_image'
    WHERE `layout_location` = 'top_graphic';
UPDATE `ork_scroll_artwork` SET `layout_location` = 'border_side'
    WHERE `layout_location` IN ('border_left','border_right','border_top','border_bottom');

-- 3) Narrow the enum to the final canonical taxonomy.
ALTER TABLE `ork_scroll_artwork`
    MODIFY `layout_location` ENUM('full_border','border_side','center_image','background') NOT NULL;
