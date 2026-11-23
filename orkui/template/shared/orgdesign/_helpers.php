<?php

/**
 * Shared Org Design helpers (Kingdom / Park / Unit).
 *
 * Plain-PHP include — NOT Smarty. Provides ONE markdown renderer, the social
 * platform map, the decorative font list, and the quick-snippet text used by the
 * shared design modal / connect block / timeline partials.
 *
 * All defs are guarded so multiple org templates on a page (and re-includes)
 * never redeclare. Consumers read the populated $ctx array that the org template
 * builds before including the design partials.
 */

if (!function_exists('org_design_markdown')) {
    /**
     * Render user-authored Markdown for org About / History / Reign lore, etc.
     * Mirrors the legacy kn_markdown / pk_markdown / un_markdown: Parsedown in
     * SafeMode with line-breaks, then strip any <img> tags.
     */
    function org_design_markdown(string $text): string
    {
        if (!class_exists('Parsedown')) {
            require_once(DIR_LIB . 'Parsedown.php');
        }
        static $pd = null;
        if ($pd === null) {
            $pd = (new Parsedown())->setSafeMode(true)->setBreaksEnabled(true);
        }
        $html = $pd->text($text);
        return preg_replace('/<img[^>]*>/i', '', $html);
    }
}

/**
 * PRESENTATION ONLY: how each social platform is drawn. icon = Font Awesome
 * class, bg = pill/chip background (may be a gradient), label = human-readable,
 * placeholder = input hint.
 *
 * This table does NOT decide which platforms exist — the domain does, via
 * OrgDesign::orgSocialPlatformHosts(), surfaced to the view as
 * $OdSocialPlatformSlugs by the Kingdom/Park/Unit controllers. Keeping a second
 * slug list here is what let the two drift: a slug rendered as an input but
 * unknown to the domain is discarded on save with no error shown.
 */
if (!isset($OD_SOCIAL_CHROME) || !is_array($OD_SOCIAL_CHROME)) {
    $OD_SOCIAL_CHROME = [
        'discord'   => ['label' => 'Discord',   'icon' => 'fab fa-discord',   'bg' => '#5865f2', 'placeholder' => 'https://discord.gg/...'],
        'facebook'  => ['label' => 'Facebook',  'icon' => 'fab fa-facebook',  'bg' => '#1877f2', 'placeholder' => 'https://facebook.com/...'],
        'instagram' => ['label' => 'Instagram', 'icon' => 'fab fa-instagram', 'bg' => 'linear-gradient(135deg,#f09433,#e6683c,#dc2743,#cc2366,#bc1888)', 'placeholder' => 'https://instagram.com/...'],
        'threads'   => ['label' => 'Threads',   'icon' => 'fas fa-at',        'bg' => '#000000', 'placeholder' => 'https://threads.net/...'],
        'bluesky'   => ['label' => 'Bluesky',   'icon' => 'fas fa-cloud',     'bg' => '#1185fe', 'placeholder' => 'https://bsky.app/...'],
        'twitter'   => ['label' => 'X',         'icon' => 'fab fa-twitter',   'bg' => '#000000', 'placeholder' => 'https://x.com/...'],
        'youtube'   => ['label' => 'YouTube',   'icon' => 'fab fa-youtube',   'bg' => '#ff0000', 'placeholder' => 'https://youtube.com/...'],
        'amtwiki'   => ['label' => 'AmtWiki',   'icon' => 'fas fa-book',      'bg' => '#6b7280', 'placeholder' => 'https://amtwiki.net/...'],
    ];
}

/**
 * The platform map the partials actually consume: the domain's slug list, in
 * the domain's order, dressed with the chrome above. A slug the domain knows
 * but this file has no entry for still renders (generic link icon) rather than
 * silently vanishing from the editor.
 */
if (!isset($OD_SOCIAL_PLATFORMS) || !is_array($OD_SOCIAL_PLATFORMS)) {
    $OD_SOCIAL_PLATFORMS = [];
    $_odSlugs = (isset($OdSocialPlatformSlugs) && is_array($OdSocialPlatformSlugs) && $OdSocialPlatformSlugs)
        ? $OdSocialPlatformSlugs
        : array_keys($OD_SOCIAL_CHROME);
    foreach ($_odSlugs as $_odSlug) {
        $_odSlug = (string)$_odSlug;
        $OD_SOCIAL_PLATFORMS[$_odSlug] = $OD_SOCIAL_CHROME[$_odSlug] ?? [
            'label'       => ucfirst($_odSlug),
            'icon'        => 'fas fa-link',
            'bg'          => '#6b7280',
            'placeholder' => 'https://...',
        ];
    }
    unset($_odSlugs, $_odSlug);
}

/**
 * Decorative fonts offered in the Header tab's font picker. key === '' means
 * "Default" (inherit). family is the CSS font-family expression for the sample.
 */
if (!isset($OD_FONTS) || !is_array($OD_FONTS)) {
    $OD_FONTS = [
        ['key' => '',                    'label' => 'Default',          'family' => 'inherit'],
        ['key' => 'Cinzel',              'label' => 'Cinzel',           'family' => 'Cinzel'],
        ['key' => 'Cinzel Decorative',   'label' => 'Cinzel Deco',      'family' => "'Cinzel Decorative'"],
        ['key' => 'IM Fell English',     'label' => 'IM Fell English',  'family' => "'IM Fell English'"],
        ['key' => 'UnifrakturMaguntia',  'label' => 'Unifraktur',       'family' => 'UnifrakturMaguntia'],
        ['key' => 'Metamorphous',        'label' => 'Metamorphous',     'family' => 'Metamorphous'],
        ['key' => 'Uncial Antiqua',      'label' => 'Uncial Antiqua',   'family' => "'Uncial Antiqua'"],
        ['key' => 'Pirata One',          'label' => 'Pirata One',       'family' => "'Pirata One'"],
        ['key' => 'Almendra',            'label' => 'Almendra',         'family' => 'Almendra'],
        ['key' => 'Pinyon Script',       'label' => 'Pinyon Script',    'family' => "'Pinyon Script'"],
        ['key' => 'Great Vibes',         'label' => 'Great Vibes',      'family' => "'Great Vibes'"],
    ];
}

/**
 * Quick-insert snippet text for the About / History Markdown fields.
 * Keys are referenced by the modal's data-odquick buttons.
 */
if (!isset($OD_SNIPPETS) || !is_array($OD_SNIPPETS)) {
    $OD_SNIPPETS = [
        'newbies'      => 'New players welcome! Every park in the kingdom keeps loaner gear on hand and our experienced fighters love teaching the ropes. Find a park near you on the Map tab.',
        'vibe'         => "## The Vibe\n\nFamily-friendly, hard-hitting, and warm. Whether you swing a sword, paint a banner, or sing a song around the fire, there's a place for you here.",
        'findus'       => "## Where We Play\n\nWe have parks across the kingdom — check the **Map** tab to find your nearest one. Visit a park day, an event, or both.",
        'founding'     => "## Founding\n\nThe kingdom was founded in **YYYY** by a group of players meeting at _location_. It was first chartered under _circumstances_.",
        'charter'      => "## Charter History\n\n- **YYYY** — Chartered as a Shire under Kingdom of _parent_\n- **YYYY** — Elevated to a Principality\n- **YYYY** — Elevated to a full Kingdom\n_(Edit dates and lines as appropriate)_",
        'pastmonarchs' => "## Past Monarchs & Regents\n\n- **YYYY–YYYY** — _Persona_ (Monarch), _Persona_ (Regent)\n- **YYYY–YYYY** — _Persona_ (Monarch), _Persona_ (Regent)",
    ];
}

/**
 * Resolve a player image URL for reign-banner avatars (mirrors kn_reign_avatar_url).
 */
if (!function_exists('org_design_avatar_url')) {
    function org_design_avatar_url($mundaneId): string
    {
        if ((int)$mundaneId <= 0) {
            return '';
        }
        return HTTP_PLAYER_IMAGE . Common::resolve_image_ext(DIR_PLAYER_IMAGE, sprintf('%06d', (int)$mundaneId));
    }
}

/**
 * Amtpride nameplate presets (key => ['name', 'colors']), the same map the
 * player profile uses. The domain validates saved keys against this file too
 * (OrgDesign::orgPrideGradients), so the picker and the save path agree.
 */
if (!function_exists('org_design_pride_gradients')) {
    function org_design_pride_gradients(): array
    {
        static $map = null;
        if ($map === null) {
            $map = require DIR_ORK3 . 'pride_gradients.php';
        }
        return $map;
    }
}

if (!function_exists('org_design_pride_css')) {
    /** CSS gradient for a pride key, or '' when the key is unknown. */
    function org_design_pride_css(string $key): string
    {
        $map = org_design_pride_gradients();
        if ($key === '' || !isset($map[$key])) {
            return '';
        }
        return 'linear-gradient(90deg, ' . implode(', ', $map[$key]['colors']) . ')';
    }
}

if (!function_exists('org_design_hero_extras')) {
    /**
     * Inline <style> for the Amtpride nameplate and the name shadow on an org
     * hero. Emitted right before the hero so it wins over the primary/secondary
     * rules above it. Flags render as-is in dark mode (no brightness filter):
     * the colors are identity-bearing. A pride flag always gets the name halo,
     * since light flag stops wash out a soft shadow (same rule as the player).
     *
     * @param string $heroSel e.g. '.kn-hero'
     * @param string $nameSel e.g. '.kn-kingdom-name'
     * @param string $infoSel the hero's text column, e.g. '.kn-hero-info'. With a
     *                        flag active its smaller lines (monarch, meta) get a
     *                        soft shadow too, as the player subline does.
     */
    function org_design_hero_extras(string $heroSel, string $nameSel, string $prideKey, bool $nameShadow, string $infoSel = ''): string
    {
        $pride = org_design_pride_css($prideKey);
        if ($pride === '' && !$nameShadow) {
            return '';
        }
        $h   = 'html body ' . $heroSel;
        $css = '';
        if ($pride !== '') {
            $css .= $h . '{background:' . $pride . ' !important;}'
                . 'html[data-theme="dark"] body ' . $heroSel . '{background:' . $pride . ' !important;filter:none !important;}';
            if ($infoSel !== '') {
                $css .= $h . ' ' . $infoSel . '{text-shadow:0 1px 3px rgba(0,0,0,.7);}';
            }
        }
        $halo = '0 0 2px rgba(0,0,0,.55),1px 1px 1px rgba(0,0,0,.5),-1px 1px 1px rgba(0,0,0,.5),'
            . '1px -1px 1px rgba(0,0,0,.5),-1px -1px 1px rgba(0,0,0,.5),0 2px 4px rgba(0,0,0,.45)';
        $css .= $h . ' ' . $nameSel . ',' . $h . ' .od-tagline{text-shadow:' . $halo . ' !important;}';
        return '<style>' . $css . '</style>';
    }
}
