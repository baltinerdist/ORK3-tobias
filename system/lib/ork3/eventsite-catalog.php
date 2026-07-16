<?php

/**
 * Curated catalogs for the event Site tab.
 * Shared by the Eventnew template (rendering) and Controller_EventAjax
 * (validation) — single source of truth, no admin surface.
 * Severity drives rule-chip color: restrictive=red, neutral=gray,
 * permissive=green. Icons are FontAwesome 5.8.2 names (no fa/fas prefix).
 */
if (!function_exists('event_site_rule_catalog')) {
    function event_site_rule_catalog(): array
    {
        return [
            'smoking' => ['label' => 'Smoking', 'icon' => 'fa-smoking-ban', 'values' => [
                'none'       => ['label' => 'None on site',     'severity' => 'restrictive'],
                'designated' => ['label' => 'Designated areas', 'severity' => 'neutral'],
                'outdoors'   => ['label' => 'Outdoors only',    'severity' => 'neutral'],
            ]],
            'alcohol' => ['label' => 'Alcohol', 'icon' => 'fa-wine-bottle', 'values' => [
                'none'    => ['label' => 'None on site',       'severity' => 'restrictive'],
                'private' => ['label' => 'Private areas only', 'severity' => 'neutral'],
                'legal'   => ['label' => 'Permitted 21+',      'severity' => 'permissive'],
                'byob'    => ['label' => 'BYOB',               'severity' => 'permissive'],
            ]],
            'pets' => ['label' => 'Pets', 'icon' => 'fa-paw', 'values' => [
                'none'    => ['label' => 'No pets',              'severity' => 'restrictive'],
                'service' => ['label' => 'Service animals only', 'severity' => 'restrictive'],
                'leashed' => ['label' => 'Leashed pets welcome', 'severity' => 'permissive'],
            ]],
            'fires' => ['label' => 'Fires', 'icon' => 'fa-fire', 'values' => [
                'none'   => ['label' => 'No open flame',          'severity' => 'restrictive'],
                'rings'  => ['label' => 'Fire rings only',        'severity' => 'neutral'],
                'stoves' => ['label' => 'Camp stoves only',       'severity' => 'neutral'],
                'open'   => ['label' => 'Ground fires permitted', 'severity' => 'permissive'],
            ]],
            'weapons' => ['label' => 'Weapons', 'icon' => 'fa-shield-alt', 'values' => [
                'amtgard'    => ['label' => 'Amtgard-legal only',    'severity' => 'neutral'],
                'peace-tied' => ['label' => 'Live steel peace-tied', 'severity' => 'neutral'],
                'no-steel'   => ['label' => 'No live steel',         'severity' => 'restrictive'],
            ]],
            'minors' => ['label' => 'Minors', 'icon' => 'fa-child', 'values' => [
                'welcome'  => ['label' => 'Minors welcome',       'severity' => 'permissive'],
                'guardian' => ['label' => 'Minors with guardian', 'severity' => 'neutral'],
                'adults'   => ['label' => '18+ site',             'severity' => 'restrictive'],
            ]],
            'quiet' => ['label' => 'Quiet Hours', 'icon' => 'fa-moon', 'values' => [
                'enforced' => ['label' => 'Quiet hours enforced', 'severity' => 'neutral'],
                'none'     => ['label' => 'No quiet hours',       'severity' => 'permissive'],
            ]],
            'vehicles' => ['label' => 'Vehicles', 'icon' => 'fa-car', 'values' => [
                'lot'     => ['label' => 'Designated parking only', 'severity' => 'neutral'],
                'no-gate' => ['label' => 'No vehicles past gate',   'severity' => 'restrictive'],
                'camp'    => ['label' => 'Drive-in camping OK',     'severity' => 'permissive'],
            ]],
            'swimming' => ['label' => 'Swimming', 'icon' => 'fa-swimmer', 'values' => [
                'allowed'  => ['label' => 'Allowed',     'severity' => 'permissive'],
                'own-risk' => ['label' => 'At own risk', 'severity' => 'neutral'],
                'no'       => ['label' => 'Prohibited',  'severity' => 'restrictive'],
            ]],
            'trash' => ['label' => 'Trash', 'icon' => 'fa-trash-alt', 'values' => [
                'packout'   => ['label' => 'Pack in, pack out', 'severity' => 'neutral'],
                'dumpsters' => ['label' => 'Dumpsters on site', 'severity' => 'permissive'],
            ]],
        ];
    }
}

if (!function_exists('event_site_location_categories')) {
    function event_site_location_categories(): array
    {
        return [
            'battlefield' => ['label' => 'Battlefield', 'icon' => 'fa-flag',           'color' => '#c53030'],
            'feast'       => ['label' => 'Feast Hall',  'icon' => 'fa-utensils',       'color' => '#dd6b20'],
            'camping'     => ['label' => 'Camping',     'icon' => 'fa-campground',     'color' => '#38a169'],
            'parking'     => ['label' => 'Parking',     'icon' => 'fa-parking',        'color' => '#3182ce'],
            'water'       => ['label' => 'Water',       'icon' => 'fa-tint',           'color' => '#00b5d8'],
            'firstaid'    => ['label' => 'First Aid',   'icon' => 'fa-first-aid',      'color' => '#e53e3e'],
            'privies'     => ['label' => 'Restrooms',   'icon' => 'fa-restroom',       'color' => '#805ad5'],
            'vendors'     => ['label' => 'Vendors',     'icon' => 'fa-store',          'color' => '#d69e2e'],
            'stage'       => ['label' => 'Stage/Court', 'icon' => 'fa-theater-masks',  'color' => '#6b46c1'],
            'other'       => ['label' => 'Other',       'icon' => 'fa-map-marker-alt', 'color' => '#4a5568'],
        ];
    }
}
