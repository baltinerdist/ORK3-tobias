<?php

require_once __DIR__ . '/lib/assert.php';
// resolveTokens is a pure static method; load the (side-effect-free) base class so the
// `extends Ork3` declaration resolves without booting the full runtime/DB.
require_once __DIR__ . '/../../system/lib/ork3/class.Ork3.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollTemplate.php';

test_section('resolveTokens');
$map = ['PlayerName' => 'Auromax Silverhawke', 'AwardName' => 'Order of the Rose', 'Date' => 'the 17th of January'];
assert_equals('Auromax Silverhawke', ScrollTemplate::resolveTokens('{PlayerName}', $map), 'single token');
assert_equals('for Order of the Rose!', ScrollTemplate::resolveTokens('for {AwardName}!', $map), 'token in sentence');
assert_equals('{Unknown}', ScrollTemplate::resolveTokens('{Unknown}', $map), 'unknown token preserved');
assert_equals('A Order of the Rose on the 17th of January', ScrollTemplate::resolveTokens('A {AwardName} on {Date}', $map), 'multiple tokens');
echo "\nALL PASS\n";
