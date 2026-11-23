<?php

// Current Reign banner styles (Kingdom About tab). key => label.
// The colors live in orgdesign.css as .od-reign-theme-<key> (a light and a
// dark variable set each); this map is the list of keys the picker offers
// and Kingdom::SetKingdomDesign accepts. '' / unknown = 'gold'.
//
// Adding a style: add the key here and both variable sets in orgdesign.css.

return [
    'gold'     => 'Royal Gold',
    'silver'   => 'Silver',
    'crimson'  => 'Crimson',
    'royal'    => 'Royal Purple',
    'emerald'  => 'Emerald',
    'sapphire' => 'Sapphire',
    'midnight' => 'Midnight',
];
