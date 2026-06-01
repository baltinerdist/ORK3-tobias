<?php
/**
 * simulate_tournament.php
 *
 * Generates a realistic, fully-played-out test tournament in the ORK3 app
 * by driving the REAL tournament library API (class.Tournament.php).
 *
 * Usage:
 *   docker exec -i ork3-php8-app php /var/www/ork.amtgard.com/scripts/simulate_tournament.php --kingdom=17
 *   docker exec -i ork3-php8-app php /var/www/ork.amtgard.com/scripts/simulate_tournament.php --park=42
 */

// ── Bootstrap ────────────────────────────────────────────────────────────────

// Required for config.dev.php which references $_SERVER['HTTP_HOST']
if (!isset($_SERVER['HTTP_HOST'])) {
	$_SERVER['HTTP_HOST'] = 'localhost';
}
if (!isset($_SERVER['REMOTE_ADDR'])) {
	$_SERVER['REMOTE_ADDR'] = '127.0.0.1';
}

// Start a session so IsAuthorized_h can store/read is_authorized_mundane_id
if (session_status() === PHP_SESSION_NONE) {
	session_start();
}

define('ENVIRONMENT', 'DEV');
putenv('ENVIRONMENT=DEV');

$root = dirname(__DIR__);
require_once $root . '/startup.php';

// The ork3 lib classes and Common.definitions.php are loaded by startup.php.
// But Common.definitions.php (with Success/NoAuthorization/InvalidParameter) lives in
// orkservice/ and may not be auto-loaded. Include it explicitly.
if (!function_exists('Success')) {
	require_once $root . '/orkservice/Common.definitions.php';
}

// ── Argument parsing ─────────────────────────────────────────────────────────

$kingdom_id = 0;
$park_id    = 0;

foreach ($argv as $arg) {
	if (preg_match('/^--kingdom=(\d+)$/', $arg, $m)) {
		$kingdom_id = (int)$m[1];
	} elseif (preg_match('/^--park=(\d+)$/', $arg, $m)) {
		$park_id = (int)$m[1];
	}
}

if (!$kingdom_id && !$park_id) {
	fwrite(STDERR, "ERROR: Must supply exactly one of --kingdom=<id> or --park=<id>\n");
	exit(1);
}
if ($kingdom_id && $park_id) {
	fwrite(STDERR, "ERROR: Supply only one of --kingdom=<id> or --park=<id>, not both.\n");
	exit(1);
}

// ── Helpers ───────────────────────────────────────────────────────────────────

function sim_log($msg) {
	echo "[" . date('H:i:s') . "] " . $msg . "\n";
	flush();
}

function sim_abort($msg, $detail = null) {
	fwrite(STDERR, "ABORT: " . $msg . "\n");
	if ($detail !== null) {
		fwrite(STDERR, "  Detail: " . json_encode($detail, JSON_PRETTY_PRINT) . "\n");
	}
	exit(1);
}

function check_response($resp, $label) {
	if (!is_array($resp) || $resp['Status'] !== 0) {
		sim_abort("$label failed", $resp);
	}
	return $resp['Detail'];
}

/** Probabilistic match winner based on warrior_level */
function pick_winner_result($wl1, $wl2) {
	// Small % chance of forfeit/disqualified for variety (~3%)
	$r = mt_rand(1, 100);
	if ($r <= 2) {
		// forfeit: participant 2 wins (p1 forfeits)
		return 'forfeit';
	}
	if ($r === 3) {
		// disqualified: participant 2 wins (p1 dq'd)
		return 'disqualified';
	}
	// Weight by warrior_level+1 so unranked fighters still have a chance
	$p1_weight = $wl1 + 1;
	$p2_weight = $wl2 + 1;
	$total     = $p1_weight + $p2_weight;
	$roll      = mt_rand(1, $total);
	return ($roll <= $p1_weight) ? '1-wins' : '2-wins';
}

// ── Resolve scope (kingdom_id + optional park_id) ────────────────────────────

global $DB;

if ($park_id && !$kingdom_id) {
	$r = $DB->query("SELECT kingdom_id FROM ork_park WHERE park_id = $park_id");
	if (!$r || !$r->next() || !(int)$r->kingdom_id) {
		sim_abort("Park $park_id not found or has no kingdom_id");
	}
	$kingdom_id = (int)$r->kingdom_id;
	sim_log("Park $park_id resolved to kingdom_id=$kingdom_id");
}

sim_log("Scope: kingdom_id=$kingdom_id" . ($park_id ? ", park_id=$park_id" : ""));

// ── Find an authorized mundane ────────────────────────────────────────────────

$auth_mundane_id = 0;

// 1. Try global admin
$r = $DB->query("SELECT mundane_id FROM ork_authorization WHERE kingdom_id = 0 AND park_id = 0 AND role = 'admin' LIMIT 1");
if ($r && $r->next() && (int)$r->mundane_id > 0) {
	$auth_mundane_id = (int)$r->mundane_id;
	sim_log("Using global admin mundane_id=$auth_mundane_id");
}

// 2. Try kingdom-level authorization
if (!$auth_mundane_id) {
	$r = $DB->query("SELECT mundane_id FROM ork_authorization WHERE kingdom_id = $kingdom_id AND role IN ('create','edit','admin') LIMIT 1");
	if ($r && $r->next() && (int)$r->mundane_id > 0) {
		$auth_mundane_id = (int)$r->mundane_id;
		sim_log("Using kingdom-level authorized mundane_id=$auth_mundane_id");
	}
}

// 3. Try park-level authorization
if (!$auth_mundane_id && $park_id) {
	$r = $DB->query("SELECT mundane_id FROM ork_authorization WHERE park_id = $park_id AND role IN ('create','edit','admin') LIMIT 1");
	if ($r && $r->next() && (int)$r->mundane_id > 0) {
		$auth_mundane_id = (int)$r->mundane_id;
		sim_log("Using park-level authorized mundane_id=$auth_mundane_id");
	}
}

if (!$auth_mundane_id) {
	sim_abort("No authorized mundane found for kingdom_id=$kingdom_id" . ($park_id ? " / park_id=$park_id" : "") . ". Cannot proceed.");
}

// Set session so IsAuthorized_h returns this mundane_id without token lookup
$_SESSION['is_authorized_mundane_id'] = $auth_mundane_id;
$dummy_token = str_pad('SIMTOKEN', 32, '0'); // 32-char dummy token

// Verify HasAuthority works for this mundane
$T = new Tournament();
sim_log("Auth check: mundane_id=$auth_mundane_id for kingdom_id=$kingdom_id");

// ── Build participant pool ────────────────────────────────────────────────────

if ($park_id) {
	$pool_sql = "
		SELECT DISTINCT a.mundane_id, m.persona
		FROM ork_attendance a
		JOIN ork_mundane m ON m.mundane_id = a.mundane_id
		WHERE m.park_id = $park_id AND a.date >= DATE_SUB(NOW(), INTERVAL 1 YEAR)
	";
} else {
	$pool_sql = "
		SELECT DISTINCT a.mundane_id, m.persona
		FROM ork_attendance a
		JOIN ork_mundane m ON m.mundane_id = a.mundane_id
		JOIN ork_park p ON p.park_id = m.park_id
		WHERE p.kingdom_id = $kingdom_id AND a.date >= DATE_SUB(NOW(), INTERVAL 1 YEAR)
	";
}

$pr = $DB->query($pool_sql);
if (!$pr || $pr->size() === 0) {
	sim_abort("No recent attendees found for the given scope (need at least 8).");
}

$pool = [];
while ($pr->next()) {
	$pool[] = ['mundane_id' => (int)$pr->mundane_id, 'persona' => $pr->persona];
}

sim_log("Attendance pool: " . count($pool) . " distinct members");

if (count($pool) < 8) {
	sim_abort("Pool has only " . count($pool) . " members; need at least 8. Aborting.");
}

// Shuffle pool and pick 8–32 participants
shuffle($pool);
$participant_count = mt_rand(8, min(32, count($pool)));
$participants      = array_slice($pool, 0, $participant_count);
sim_log("Tournament participants: $participant_count selected from pool");

// ── Fetch warrior levels for weighting ───────────────────────────────────────

$mundane_ids_str = implode(',', array_column($participants, 'mundane_id'));
// warrior_level is snapshotted onto ork_participant at AddParticipant time, but we
// also want it for probabilistic match weighting before we post results.
// We read it from ork_participant.warrior_level AFTER adding participants.
// For now, pre-fetch from ork_awards to use in match simulation.
$wl_map = [];
$aw_r = $DB->query("
	SELECT mundane_id,
		IFNULL(MAX(`rank`), 0) AS warrior_rank,
		COUNT(CASE WHEN award_id = 20 THEN 1 END) AS is_knight_sword,
		COUNT(CASE WHEN award_id = 12 THEN 1 END) AS is_warlord
	FROM ork_awards
	WHERE mundane_id IN ($mundane_ids_str) AND award_id IN (12, 20, 27) AND revoked = 0
	GROUP BY mundane_id
");
if ($aw_r && $aw_r->size() > 0) {
	while ($aw_r->next()) {
		$mid = (int)$aw_r->mundane_id;
		$is_ks = (int)$aw_r->is_knight_sword;
		$is_wl = (int)$aw_r->is_warlord;
		$wr    = (int)$aw_r->warrior_rank;
		$wl_map[$mid] = $is_ks ? 12 : ($is_wl ? 11 : min(10, $wr));
	}
}

// ── Determine tournament date (within past 90 days) ───────────────────────────

$days_ago      = mt_rand(1, 90);
$tournament_ts = time() - ($days_ago * 86400);
$tournament_date = date('Y-m-d H:i:s', $tournament_ts);
$tournament_name = 'Simulated Tourney — ' . date('F j, Y', $tournament_ts);

// ── Create the tournament ─────────────────────────────────────────────────────

sim_log("Creating tournament: \"$tournament_name\" on $tournament_date");

$create_req = [
	'Token'                  => $dummy_token,
	'KingdomId'              => $kingdom_id,
	'ParkId'                 => $park_id ?: 0,
	'EventCalendarDetailId'  => 0,
	'Name'                   => $tournament_name,
	'Description'            => 'Auto-generated simulation tournament for testing purposes.',
	'Url'                    => '',
	'When'                   => $tournament_date,
];

$resp = $T->CreateTournament($create_req);
$tournament_id = check_response($resp, 'CreateTournament');
sim_log("Tournament created: id=$tournament_id");

// ── Plan brackets (3–5, with ≥1 single + ≥1 double) ─────────────────────────

$all_styles  = ['Single Sword', 'Florentine', 'Sword and Shield', 'Great Weapon', 'Missile', 'Other', 'Open Weapons'];
$all_methods = ['single', 'double', 'round-robin'];  // swiss excluded per spec unless robust
$seedings    = ['random', 'warrior'];

$num_brackets = mt_rand(3, 5);

// Build the method list: ensure ≥1 single, ≥1 double; fill the rest randomly
$bracket_methods = ['single', 'double'];
for ($i = 2; $i < $num_brackets; $i++) {
	$bracket_methods[] = $all_methods[mt_rand(0, count($all_methods) - 1)];
}
shuffle($bracket_methods);

// Assign styles (cycle + shuffle to avoid repeats where possible)
$shuffled_styles = $all_styles;
shuffle($shuffled_styles);
$bracket_configs = [];
for ($i = 0; $i < $num_brackets; $i++) {
	$bracket_configs[] = [
		'method'  => $bracket_methods[$i],
		'style'   => $shuffled_styles[$i % count($shuffled_styles)],
		'seeding' => $seedings[mt_rand(0, 1)],
	];
}

sim_log("Bracket plan (" . count($bracket_configs) . " brackets):");
foreach ($bracket_configs as $bi => $bc) {
	sim_log("  Bracket " . ($bi + 1) . ": method={$bc['method']}, style={$bc['style']}, seeding={$bc['seeding']}");
}

// ── Add brackets, participants, generate matches, simulate results ────────────

$bracket_summaries = [];

foreach ($bracket_configs as $bi => $bc) {
	$bnum = $bi + 1;
	sim_log("--- Bracket $bnum/{$num_brackets}: {$bc['method']} ({$bc['style']}) ---");

	// Add bracket
	$add_bracket_req = [
		'Token'           => $dummy_token,
		'TournamentId'    => $tournament_id,
		'Style'           => $bc['style'],
		'StyleNote'       => '',
		'Method'          => $bc['method'],
		'Rings'           => 1,
		'Participants'    => 'individual',
		'Seeding'         => $bc['seeding'],
		'DurationMinutes' => 0,
		'BestOf'          => 1,
		'CopyOfId'        => 0,
	];
	$resp       = $T->AddBracket($add_bracket_req);
	$bracket_id = check_response($resp, "AddBracket[$bnum]");
	sim_log("  Bracket id=$bracket_id created");

	// Pick a roster subset: min(8, pool) to full pool size
	$roster_min  = min(8, $participant_count);
	$roster_size = mt_rand($roster_min, $participant_count);
	$shuffled_p = $participants;
	shuffle($shuffled_p);
	$roster = array_slice($shuffled_p, 0, $roster_size);
	sim_log("  Roster size: $roster_size");

	// Add each participant to this bracket
	$participant_id_map = []; // mundane_id => participant_id
	$warrior_level_map  = []; // participant_id => warrior_level

	foreach ($roster as $p) {
		$add_p_req = [
			'Token'        => $dummy_token,
			'TournamentId' => $tournament_id,
			'BracketId'    => $bracket_id,
			'MundaneId'    => $p['mundane_id'],
			'Alias'        => $p['persona'],
			'ParkId'       => 0,
			'KingdomId'    => $kingdom_id,
			'ParticipantId' => 0,
			'Members'      => [],
		];
		$resp  = $T->AddParticipant($add_p_req);
		$p_id  = check_response($resp, "AddParticipant[mundane={$p['mundane_id']}]");
		$participant_id_map[$p['mundane_id']] = $p_id;
		$warrior_level_map[$p_id]             = $wl_map[$p['mundane_id']] ?? 0;
	}
	sim_log("  Added " . count($roster) . " participants");

	// Generate matches
	$resp = $T->GenerateMatches([
		'Token'        => $dummy_token,
		'TournamentId' => $tournament_id,
		'BracketId'    => $bracket_id,
	]);
	check_response($resp, "GenerateMatches[$bnum]");
	sim_log("  Matches generated");

	// ── Simulate results until bracket is complete ────────────────────────────
	// PostMatchResult handles ALL match types including byes (one participant = 0).
	// When participant_2_id = 0, calling PostMatchResult with '1-wins' correctly:
	//   - advances the real participant (winner_id = p1_id)
	//   - sets loser_id = 0, so no phantom elimination occurs
	//   - routes WR losers to LB only when loser_id > 0
	//   - checks bracket completion after every result
	// No direct DB writes to ork_match are needed or permitted.
	//
	// The lib does NOT auto-create the double-elim confirmation match — that
	// requires an explicit CreateConfirmationMatch() call when the LB champion
	// wins the Grand Final (result = '2-wins' on bracket_side = 'grand-final').
	$max_iterations = 200;
	$iteration      = 0;
	$total_matches_posted = 0;

	while ($iteration < $max_iterations) {
		$iteration++;

		// Check bracket status first
		$bstat_r = $DB->query("SELECT status FROM ork_bracket WHERE bracket_id = $bracket_id");
		$bstat   = ($bstat_r && $bstat_r->next()) ? $bstat_r->status : 'unknown';
		if (in_array($bstat, ['complete', 'finalized'])) {
			sim_log("  Bracket complete after $iteration iteration(s)");
			break;
		}

		// Fetch current matches
		$match_resp  = $T->GetMatches([
			'TournamentId' => $tournament_id,
			'BracketId'    => $bracket_id,
		]);
		$all_matches = check_response($match_resp, "GetMatches iteration=$iteration");

		// Pending = unresolved AND at least one real participant.
		// Matches with BOTH participants = 0 are not yet ready (waiting for upstream winners).
		// Bye matches (exactly one participant > 0) are included — PostMatchResult handles them.
		$pending = array_filter($all_matches, function($m) {
			$p1 = (int)$m['Participant1Id'];
			$p2 = (int)$m['Participant2Id'];
			$has_result = !empty($m['Result']) && $m['Result'] !== null;
			return !$has_result && ($p1 > 0 || $p2 > 0);
		});

		if (empty($pending)) {
			// No pending matches but bracket not yet complete.
			// For double-elim: check if we need to create a confirmation match
			// (LB champion won the Grand Final → '2-wins' on bracket_side='grand-final').
			if ($bc['method'] === 'double') {
				$gf_r = $DB->query(
					"SELECT result, participant_1_id, participant_2_id, round
					 FROM ork_match
					 WHERE bracket_id = $bracket_id AND bracket_side = 'grand-final'
					 ORDER BY round DESC LIMIT 1"
				);
				if ($gf_r && $gf_r->next()) {
					$gf_result = $gf_r->result;
					$gf_round  = (int)$gf_r->round;
					$gf_p1     = (int)$gf_r->participant_1_id;
					$gf_p2     = (int)$gf_r->participant_2_id;
					// If the most recent GF had 2-wins and no confirmation match yet, create it
					if ($gf_result === '2-wins' && $gf_p1 > 0 && $gf_p2 > 0) {
						$conf_check = $DB->query(
							"SELECT COUNT(*) AS cnt FROM ork_match
							 WHERE bracket_id = $bracket_id AND bracket_side = 'grand-final' AND round > $gf_round"
						);
						if ($conf_check && $conf_check->next() && (int)$conf_check->cnt === 0) {
							sim_log("  Creating confirmation match (LB champion won Grand Final)");
							$cm_resp = $T->CreateConfirmationMatch([
								'Token'        => $dummy_token,
								'TournamentId' => $tournament_id,
								'BracketId'    => $bracket_id,
							]);
							if ($cm_resp['Status'] === 0) {
								sim_log("  Confirmation match created: id=" . $cm_resp['Detail']);
								continue; // Re-fetch and play confirmation match
							} else {
								sim_log("  Confirmation match creation failed: " . json_encode($cm_resp));
							}
						}
					}
				}
			}

			// Still no pending matches and no confirmation match needed — genuinely stuck
			sim_abort(
				"Bracket $bnum (id=$bracket_id) stalled: no pending matches but status='$bstat'",
				[
					'bracket_id'   => $bracket_id,
					'status'       => $bstat,
					'iteration'    => $iteration,
					'all_matches'  => array_map(function($m) {
						return [
							'match_id'  => $m['MatchId'],
							'round'     => $m['Round'],
							'side'      => $m['BracketSide'],
							'p1'        => $m['Participant1Id'],
							'p2'        => $m['Participant2Id'],
							'result'    => $m['Result'],
						];
					}, $all_matches),
				]
			);
		}

		sim_log("  Iteration $iteration: " . count($pending) . " pending match(es)");

		// Post result for each pending match via PostMatchResult only — no direct DB writes.
		foreach ($pending as $match) {
			$p1_id = (int)$match['Participant1Id'];
			$p2_id = (int)$match['Participant2Id'];

			// Determine result:
			// - Bye (one participant = 0): the real fighter wins unconditionally
			// - Both real: probabilistic weighted by warrior level
			if ($p1_id > 0 && $p2_id === 0) {
				$result = '1-wins';
			} elseif ($p2_id > 0 && $p1_id === 0) {
				$result = '2-wins';
			} else {
				$wl1    = $warrior_level_map[$p1_id] ?? 0;
				$wl2    = $warrior_level_map[$p2_id] ?? 0;
				$result = pick_winner_result($wl1, $wl2);
			}

			$post_resp = $T->PostMatchResult([
				'Token'        => $dummy_token,
				'TournamentId' => $tournament_id,
				'MatchId'      => $match['MatchId'],
				'Result'       => $result,
				'Score'        => '',
				'Bouts'        => '',
			]);
			if ($post_resp['Status'] !== 0) {
				// May already be recorded by a prior iteration pass (e.g. re-fetch lag), skip
				sim_log("  WARN: PostMatchResult for match_id={$match['MatchId']} failed: " . json_encode($post_resp));
			} else {
				$total_matches_posted++;
			}
		}
	}

	if ($iteration >= $max_iterations) {
		// Hit iteration cap — dump unresolved matches for diagnosis
		$match_resp = $T->GetMatches(['TournamentId' => $tournament_id, 'BracketId' => $bracket_id]);
		$all_m      = $match_resp['Detail'] ?? [];
		$unresolved_dump = array_filter($all_m, fn($mm) => empty($mm['Result']));
		sim_abort(
			"Bracket $bnum (id=$bracket_id) hit max iterations ($max_iterations) without completing",
			[
				'bracket_id'        => $bracket_id,
				'status'            => $bstat ?? 'unknown',
				'unresolved_matches' => array_map(function($mm) {
					return [
						'match_id' => $mm['MatchId'],
						'round'    => $mm['Round'],
						'side'     => $mm['BracketSide'],
						'p1'       => $mm['Participant1Id'],
						'p2'       => $mm['Participant2Id'],
					];
				}, array_values($unresolved_dump)),
			]
		);
	}

	// Final bracket status
	$bstat_r = $DB->query("SELECT status FROM ork_bracket WHERE bracket_id = $bracket_id");
	$bstat   = ($bstat_r && $bstat_r->next()) ? $bstat_r->status : 'unknown';
	sim_log("  Final bracket status: $bstat");

	// Get standings for the summary
	$standings_resp = $T->GetStandings([
		'BracketId'    => $bracket_id,
		'TournamentId' => $tournament_id,
	]);
	$standings = ($standings_resp['Status'] === 0) ? $standings_resp['Detail'] : [];

	// Count total matches for this bracket
	$match_count_r = $DB->query("SELECT COUNT(*) AS cnt FROM ork_match WHERE bracket_id = $bracket_id");
	$match_count   = ($match_count_r && $match_count_r->next()) ? (int)$match_count_r->cnt : 0;

	$bracket_summaries[] = [
		'num'           => $bnum,
		'bracket_id'    => $bracket_id,
		'method'        => $bc['method'],
		'style'         => $bc['style'],
		'roster_size'   => $roster_size,
		'match_count'   => $match_count,
		'posted'        => $total_matches_posted,
		'status'        => $bstat,
		'standings'     => $standings,
	];
}

// ── Final summary ─────────────────────────────────────────────────────────────

echo "\n";
echo "==========================================================\n";
echo "  SIMULATION COMPLETE\n";
echo "==========================================================\n";
echo "Scope          : kingdom_id=$kingdom_id" . ($park_id ? ", park_id=$park_id" : "") . "\n";
echo "Auth mundane   : $auth_mundane_id\n";
echo "Participants   : $participant_count selected from pool of " . count($pool) . "\n";
echo "Tournament ID  : $tournament_id\n";
echo "Tournament date: $tournament_date\n";
echo "Tournament name: $tournament_name\n";
echo "\n";

foreach ($bracket_summaries as $bs) {
	echo "----------------------------------------------------------\n";
	echo "Bracket #{$bs['num']} (id={$bs['bracket_id']})\n";
	echo "  Method     : {$bs['method']}\n";
	echo "  Style      : {$bs['style']}\n";
	echo "  Roster     : {$bs['roster_size']} participants\n";
	echo "  Matches    : {$bs['match_count']} total, {$bs['posted']} results posted\n";
	echo "  Status     : {$bs['status']}\n";
	echo "  Standings  :\n";
	$top = array_slice($bs['standings'], 0, 3);
	foreach ($top as $rank_i => $s) {
		$wl_label = $s['WarriorRank'] > 0 ? " (OotW {$s['WarriorRank']})" : '';
		echo "    " . ($rank_i + 1) . ". {$s['Alias']}{$wl_label} — W:{$s['Wins']} L:{$s['Losses']}\n";
	}
}

echo "\n";
echo "==========================================================\n";
echo "  VIEW RESULTS:\n";
echo "  /orkui/Reports/tournaments&KingdomId=$kingdom_id&AllTime=1\n";
echo "==========================================================\n";
