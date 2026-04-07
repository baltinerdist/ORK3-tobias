<?php

class Controller_TournamentAjax extends Controller {

	/** Returns a compact JSON error string from a model response array. */
	private function modelError(array $r): string {
		$msg = $r['Error'] ?? 'Error';
		$det = trim((string)($r['Detail'] ?? ''));
		return json_encode(['status' => $r['Status'], 'error' => $det !== '' ? "$msg: $det" : $msg]);
	}

	/**
	 * GET/POST to tournament-level actions.
	 * Route: TournamentAjax/tournament/{tournament_id}/{action}
	 *
	 * GET  brackets   — list brackets for a tournament
	 * POST addbracket — add a new bracket
	 */
	public function tournament($p = null) {
		header('Content-Type: application/json');
		$parts         = explode('/', $p ?? '');
		$tournament_id = (int)preg_replace('/[^0-9]/', '', $parts[0] ?? '');
		$action        = $parts[1] ?? '';

		if (!isset($this->session->user_id)) {
			echo json_encode(['status' => 5, 'error' => 'Not logged in']);
			exit;
		}

		if (!valid_id($tournament_id)) {
			echo json_encode(['status' => 1, 'error' => 'Invalid tournament ID']);
			exit;
		}

		$this->load_model('Tournament');

		if ($action === 'brackets') {
			$r = $this->Tournament->get_brackets($tournament_id);
			echo ($r['Status'] == 0)
				? json_encode(['status' => 0, 'brackets' => $r['Detail'] ?? []])
				: $this->modelError($r);

		} elseif ($action === 'addbracket') {
			$style = trim($_POST['Style']  ?? '');
			$method = trim($_POST['Method'] ?? '');
			if (!strlen($style) || !strlen($method)) {
				echo json_encode(['status' => 1, 'error' => 'Style and method are required.']); exit;
			}
			$allowed_methods = ['single','double','swiss','round-robin','ironman','score'];
			if (!in_array($method, $allowed_methods, true)) {
				echo json_encode(['status' => 1, 'error' => 'Invalid bracket method.']); exit;
			}
			$r = $this->Tournament->add_bracket([
				'Token'        => $this->session->token,
				'TournamentId' => $tournament_id,
				'Style'        => $style,
				'StyleNote'    => trim($_POST['StyleNote']   ?? ''),
				'Method'       => $method,
				'Rings'        => max(1, min(20, (int)($_POST['Rings'] ?? 1))),
				'Participants' => trim($_POST['Participants'] ?? 'individual'),
				'Seeding'         => trim($_POST['Seeding']         ?? 'random'),
				'DurationMinutes' => max(0, (int)($_POST['DurationMinutes'] ?? 0)),
			]);
			echo ($r['Status'] == 0)
				? json_encode(['status' => 0, 'bracketId' => (int)($r['Detail'] ?? 0)])
				: $this->modelError($r);

		} elseif ($action === 'generate') {
			$bracket_id = (int)($_POST['BracketId'] ?? 0);
			if (!valid_id($bracket_id)) {
				echo json_encode(['status' => 1, 'error' => 'BracketId required.']); exit;
			}
			$r = $this->Tournament->generate_matches([
				'Token'        => $this->session->token,
				'TournamentId' => $tournament_id,
				'BracketId'    => $bracket_id,
			]);
			echo ($r['Status'] == 0)
				? json_encode(['status' => 0, 'bracketId' => (int)($r['Detail'] ?? 0)])
				: $this->modelError($r);

		} elseif ($action === 'updatebracket') {
			$bracket_id = (int)($_POST['BracketId'] ?? 0);
			if (!valid_id($bracket_id)) {
				echo json_encode(['status' => 1, 'error' => 'BracketId required.']); exit;
			}
			$style = trim($_POST['Style'] ?? '');
			$method = trim($_POST['Method'] ?? '');
			if (!strlen($style) || !strlen($method)) {
				echo json_encode(['status' => 1, 'error' => 'Style and method are required.']); exit;
			}
			$allowed_methods = ['single','double','swiss','round-robin','ironman','score'];
			if (!in_array($method, $allowed_methods, true)) {
				echo json_encode(['status' => 1, 'error' => 'Invalid bracket method.']); exit;
			}
			$r = $this->Tournament->update_bracket([
				'Token'        => $this->session->token,
				'TournamentId' => $tournament_id,
				'BracketId'    => $bracket_id,
				'Style'        => $style,
				'StyleNote'    => trim($_POST['StyleNote']   ?? ''),
				'Method'       => $method,
				'Rings'        => max(1, min(20, (int)($_POST['Rings'] ?? 1))),
				'Participants' => trim($_POST['Participants'] ?? 'individual'),
				'Seeding'         => trim($_POST['Seeding']         ?? 'random'),
				'DurationMinutes' => max(0, (int)($_POST['DurationMinutes'] ?? 0)),
			]);
			echo ($r['Status'] == 0)
				? json_encode(['status' => 0, 'bracketId' => (int)($r['Detail'] ?? 0)])
				: $this->modelError($r);

		} elseif ($action === 'confirmationmatch') {
			$bracket_id = (int)($_POST['BracketId'] ?? 0);
			if (!valid_id($bracket_id)) {
				echo json_encode(['status' => 1, 'error' => 'BracketId required.']); exit;
			}
			$r = $this->Tournament->create_confirmation_match([
				'Token'        => $this->session->token,
				'TournamentId' => $tournament_id,
				'BracketId'    => $bracket_id,
			]);
			echo ($r['Status'] == 0)
				? json_encode(['status' => 0, 'matchId' => (int)($r['Detail'] ?? 0)])
				: $this->modelError($r);

		} elseif ($action === 'tiebreakerfor3rd') {
			$bracket_id = (int)($_POST['BracketId'] ?? 0);
			if (!valid_id($bracket_id)) {
				echo json_encode(['status' => 1, 'error' => 'BracketId required.']); exit;
			}
			$r = $this->Tournament->create_tiebreaker_match([
				'Token'        => $this->session->token,
				'TournamentId' => $tournament_id,
				'BracketId'    => $bracket_id,
			]);
			echo ($r['Status'] == 0)
				? json_encode(['status' => 0, 'matchId' => (int)($r['Detail'] ?? 0)])
				: $this->modelError($r);

		} elseif ($action === 'completebracket') {
			$bracket_id = (int)($_POST['BracketId'] ?? 0);
			if (!valid_id($bracket_id)) {
				echo json_encode(['status' => 1, 'error' => 'BracketId required.']); exit;
			}
			$r = $this->Tournament->complete_bracket([
				'Token'        => $this->session->token,
				'TournamentId' => $tournament_id,
				'BracketId'    => $bracket_id,
			]);
			echo ($r['Status'] == 0)
				? json_encode(['status' => 0, 'bracketId' => $bracket_id])
				: $this->modelError($r);


		} elseif ($action === 'deletebracket') {
			$bracket_id = (int)($_POST['BracketId'] ?? 0);
			if (!valid_id($bracket_id)) {
				echo json_encode(['status' => 1, 'error' => 'BracketId required.']); exit;
			}
			$r = $this->Tournament->delete_bracket([
				'Token'        => $this->session->token,
				'TournamentId' => $tournament_id,
				'BracketId'    => $bracket_id,
			]);
			echo ($r['Status'] == 0)
				? json_encode(['status' => 0, 'bracketId' => $bracket_id])
				: $this->modelError($r);

		} elseif ($action === 'savestandingspoints') {
			$r = $this->Tournament->auth_check(['Token' => $this->session->token, 'TournamentId' => $tournament_id]);
			if (!isset($r) || (isset($r['Status']) && $r['Status'] != 0)) {
				echo json_encode(['status' => 5, 'error' => 'Not authorized.']); exit;
			}
			$points_raw = trim($_POST['Points'] ?? '');
			if ($points_raw === '') {
				echo json_encode(['status' => 1, 'error' => 'Points data is required.']); exit;
			}
			$points_arr = json_decode($points_raw, true);
			if (!is_array($points_arr) || count($points_arr) < 1 || count($points_arr) > 16) {
				echo json_encode(['status' => 1, 'error' => 'Invalid points data (must be 1-16 positions).']); exit;
			}
			$points_clean = array_map(function($v) { return max(0, (int)$v); }, $points_arr);
			global $DB;
			$DB->query(
				"UPDATE ork_tournament SET standings_points = :points WHERE tournament_id = :tid",
				[':points' => json_encode($points_clean), ':tid' => $tournament_id]
			);
			echo json_encode(['status' => 0, 'points' => $points_clean]);

		} elseif ($action === 'updatetournament') {
			$name = trim($_POST['Name'] ?? '');
			if (!strlen($name)) {
				echo json_encode(['status' => 1, 'error' => 'Name is required.']); exit;
			}
			$r = $this->Tournament->update_tournament([
				'Token'                 => $this->session->token,
				'TournamentId'          => $tournament_id,
				'Name'                  => $name,
				'Description'           => trim($_POST['Description'] ?? ''),
				'Url'                   => trim($_POST['Url']         ?? ''),
				'When'                  => trim($_POST['When']        ?? ''),
				'ParkId'                => (int)($_POST['ParkId']                ?? 0),
				'KingdomId'             => (int)($_POST['KingdomId']             ?? 0),
				'EventCalendarDetailId' => (int)($_POST['EventCalendarDetailId'] ?? 0),
			]);
			echo ($r['Status'] == 0)
				? json_encode(['status' => 0, 'tournamentId' => $tournament_id])
				: $this->modelError($r);

		} elseif ($action === 'copybracket') {
			$source_bid = (int)($_POST['BracketId'] ?? 0);
			if (!valid_id($source_bid)) {
				echo json_encode(['status' => 1, 'error' => 'Source BracketId required.']); exit;
			}
			$r = $this->Tournament->add_bracket([
				'Token'        => $this->session->token,
				'TournamentId' => $tournament_id,
				'CopyOfId'     => $source_bid,
			]);
			echo ($r['Status'] == 0)
				? json_encode(['status' => 0, 'bracketId' => (int)($r['Detail'] ?? 0)])
				: $this->modelError($r);

		} else {
			echo json_encode(['status' => 1, 'error' => 'Unknown action']);
		}
		exit;
	}

	/**
	 * GET/POST to bracket-level actions.
	 * Route: TournamentAjax/bracket/{bracket_id}/{action}
	 *
	 * GET  participants    — list participants for a bracket
	 * GET  matches         — list matches for a bracket
	 * POST addparticipant  — add a participant to a bracket
	 */
	public function bracket($p = null) {
		header('Content-Type: application/json');
		$parts      = explode('/', $p ?? '');
		$bracket_id = (int)preg_replace('/[^0-9]/', '', $parts[0] ?? '');
		$action     = $parts[1] ?? '';

		if (!isset($this->session->user_id)) {
			echo json_encode(['status' => 5, 'error' => 'Not logged in']);
			exit;
		}

		if (!valid_id($bracket_id)) {
			echo json_encode(['status' => 1, 'error' => 'Invalid bracket ID']);
			exit;
		}

		$this->load_model('Tournament');

		if ($action === 'participants') {
			$r = $this->Tournament->get_participants(['BracketId' => $bracket_id]);
			echo ($r['Status'] == 0)
				? json_encode(['status' => 0, 'participants' => $r['Detail'] ?? []])
				: $this->modelError($r);

		} elseif ($action === 'matches') {
			$r = $this->Tournament->get_matches(['BracketId' => $bracket_id]);
			echo ($r['Status'] == 0)
				? json_encode(['status' => 0, 'matches' => $r['Detail'] ?? []])
				: $this->modelError($r);

		} elseif ($action === 'addparticipant') {
			$alias     = trim($_POST['Alias']        ?? '');
			$mundaneId = (int)($_POST['MundaneId']   ?? 0);
			$tid       = (int)($_POST['TournamentId'] ?? 0);

			if (!strlen($alias)) {
				echo json_encode(['status' => 1, 'error' => 'Alias is required.']); exit;
			}
			if (!valid_id($tid)) {
				echo json_encode(['status' => 1, 'error' => 'Invalid tournament ID.']); exit;
			}

			$params = [
				'Token'        => $this->session->token,
				'TournamentId' => $tid,
				'BracketId'    => $bracket_id,
				'Alias'        => $alias,
				'MundaneId'    => $mundaneId,
				'UnitId'       => (int)($_POST['UnitId']    ?? 0),
				'ParkId'       => (int)($_POST['ParkId']    ?? 0),
				'KingdomId'    => (int)($_POST['KingdomId'] ?? 0),
			];

			// Team participant: pass Members array of {MundaneId} objects
			$membersJson = $_POST['Members'] ?? '';
			if ($membersJson !== '') {
				$members = json_decode($membersJson, true);
				if (is_array($members) && count($members) > 0) {
					$params['Members'] = $members;
				}
			}

			$r = $this->Tournament->add_participant($params);
			echo ($r['Status'] == 0)
				? json_encode(['status' => 0, 'participantId' => (int)($r['Detail'] ?? 0)])
				: $this->modelError($r);

		} elseif ($action === 'removeparticipant') {
			$participant_id = (int)($_POST['ParticipantId'] ?? 0);
			if (!valid_id($participant_id)) {
				echo json_encode(['status' => 1, 'error' => 'ParticipantId required.']); exit;
			}
			$tid = (int)($_POST['TournamentId'] ?? 0);
			if (!valid_id($tid)) {
				echo json_encode(['status' => 1, 'error' => 'TournamentId required.']); exit;
			}
			$r = $this->Tournament->remove_participant([
				'Token'         => $this->session->token,
				'TournamentId'  => $tid,
				'ParticipantId' => $participant_id,
			]);
			echo ($r['Status'] == 0)
				? json_encode(['status' => 0, 'participantId' => $participant_id])
				: $this->modelError($r);

		} elseif ($action === 'clearmatches') {
			$tid = (int)($_POST['TournamentId'] ?? 0);
			if (!valid_id($tid)) {
				echo json_encode(['status' => 1, 'error' => 'TournamentId required.']); exit;
			}
			$r = $this->Tournament->clear_bracket_matches([
				'Token'        => $this->session->token,
				'TournamentId' => $tid,
				'BracketId'    => $bracket_id,
			]);
			echo ($r['Status'] == 0)
				? json_encode(['status' => 0])
				: $this->modelError($r);

		} elseif ($action === 'ironmanwin') {
			$winner_id   = (int)($_POST['WinnerId']    ?? 0);
			$tid         = (int)($_POST['TournamentId'] ?? 0);
			$ring_number = max(1, min(8, (int)($_POST['RingNumber'] ?? 1)));
			if (!valid_id($winner_id)) {
				echo json_encode(['status' => 1, 'error' => 'WinnerId required.']); exit;
			}
			if (!valid_id($tid)) {
				echo json_encode(['status' => 1, 'error' => 'TournamentId required.']); exit;
			}
			$r = $this->Tournament->record_ironman_win([
				'Token'        => $this->session->token,
				'TournamentId' => $tid,
				'BracketId'    => $bracket_id,
				'WinnerId'     => $winner_id,
				'RingNumber'   => $ring_number,
			]);
			echo ($r['Status'] == 0)
				? json_encode(['status' => 0, 'matchId' => (int)($r['Detail'] ?? 0)])
				: $this->modelError($r);

		} elseif ($action === 'reorder') {
			// Update seed order for participants (Phase 7 — drag-drop)
			$tid = (int)($_POST['TournamentId'] ?? 0);
			if (!valid_id($tid)) {
				echo json_encode(['status' => 1, 'error' => 'TournamentId required.']); exit;
			}
			$r = $this->Tournament->auth_check(['Token' => $this->session->token, 'TournamentId' => $tid]);
			if (!isset($r) || (isset($r['Status']) && $r['Status'] != 0)) {
				echo json_encode(['status' => 5, 'error' => 'Not authorized.']); exit;
			}
			// Block reordering on brackets that are already active, complete, or finalized
			global $DB;
			$DB->Clear();
			$bstatus_r = $DB->query("SELECT status FROM ork_bracket WHERE bracket_id = :bid", [':bid' => $bracket_id]);
			if (!$bstatus_r || !$bstatus_r->next()) {
				echo json_encode(['status' => 1, 'error' => 'Bracket not found.']); exit;
			}
			$bstatus = $bstatus_r->status ?? '';
			if (in_array($bstatus, ['active', 'complete', 'finalized'], true)) {
				echo json_encode(['status' => 1, 'error' => 'Cannot reorder seeds on an active or completed bracket.']); exit;
			}
			$order_json = trim($_POST['Order'] ?? '');
			$order_arr  = json_decode($order_json, true);
			if (!is_array($order_arr)) {
				echo json_encode(['status' => 1, 'error' => 'Invalid order data.']); exit;
			}
			global $DB;
			// Fetch the valid participant IDs for this bracket to prevent cross-bracket seed writes
			$DB->Clear();
			$validPids = [];
			$pRows = $DB->query("SELECT participant_id FROM ork_participant WHERE bracket_id = :bid", [":bid" => $bracket_id]);
			if ($pRows) { while ($pRows->next()) $validPids[(int)$pRows->participant_id] = true; }
			foreach ($order_arr as $seed => $participant_id) {
				$pid = (int)$participant_id;
				$s   = (int)$seed + 1;
				if (valid_id($pid) && isset($validPids[$pid])) {
					$DB->query(
						"UPDATE ork_participant SET seed = :s WHERE participant_id = :pid AND bracket_id = :bid",
						[':s' => $s, ':pid' => $pid, ':bid' => $bracket_id]
					);
				}
			}
			echo json_encode(['status' => 0]);

		} elseif ($action === 'updateparticipantstatus') {
			$tid = (int)($_POST['TournamentId'] ?? 0);
			if (!valid_id($tid)) {
				echo json_encode(['status' => 1, 'error' => 'TournamentId required.']); exit;
			}
			$r = $this->Tournament->auth_check(['Token' => $this->session->token, 'TournamentId' => $tid]);
			if (!isset($r) || (isset($r['Status']) && $r['Status'] != 0)) {
				echo json_encode(['status' => 5, 'error' => 'Not authorized.']); exit;
			}
			$participant_id = (int)($_POST['ParticipantId'] ?? 0);
			if (!valid_id($participant_id)) {
				echo json_encode(['status' => 1, 'error' => 'ParticipantId required.']); exit;
			}
			global $DB;
			$DB->Clear();
			$exists = $DB->query("SELECT participant_id FROM ork_participant WHERE participant_id = :pid AND bracket_id = :bid",
				[':pid' => $participant_id, ':bid' => $bracket_id]);
			if (!$exists || !$exists->next()) {
				echo json_encode(['status' => 1, 'error' => 'Participant not found in this bracket.']); exit;
			}
			$status = trim($_POST['Status'] ?? '');
			$allowed = ['active','withdrawn','disqualified'];
			if (!in_array($status, $allowed)) {
				echo json_encode(['status' => 1, 'error' => 'Invalid status. Allowed: ' . implode(', ', $allowed)]); exit;
			}
			global $DB;
			$DB->Clear();
			$DB->query(
				"UPDATE ork_participant SET status = :st WHERE participant_id = :pid AND bracket_id = :bid",
				[':st' => $status, ':pid' => $participant_id, ':bid' => $bracket_id]
			);
			echo json_encode(['status' => 0, 'participantId' => $participant_id, 'newStatus' => $status]);

		} else {
			echo json_encode(['status' => 1, 'error' => 'Unknown action']);
		}
		exit;
	}

	/**
	 * POST match result.
	 * Route: TournamentAjax/match/{match_id}/{tournament_id}
	 *
	 * POST result — record a match result and advance bracket
	 */
	public function match($p = null) {
		header('Content-Type: application/json');
		$parts         = explode('/', $p ?? '');
		$match_id      = (int)preg_replace('/[^0-9]/', '', $parts[0] ?? '');
		$tournament_id = (int)preg_replace('/[^0-9]/', '', $parts[1] ?? '');
		$action        = $parts[2] ?? '';

		if (!isset($this->session->user_id)) {
			echo json_encode(['status' => 5, 'error' => 'Not logged in']);
			exit;
		}

		if (!valid_id($match_id) || !valid_id($tournament_id)) {
			echo json_encode(['status' => 1, 'error' => 'Invalid match or tournament ID']);
			exit;
		}

		$this->load_model('Tournament');

		if ($action === 'reset') {
			$r = $this->Tournament->reset_match([
				'Token'        => $this->session->token,
				'TournamentId' => $tournament_id,
				'MatchId'      => $match_id,
			]);
			echo ($r['Status'] == 0)
				? json_encode(['status' => 0, 'matchId' => $match_id])
				: $this->modelError($r);
			exit;
		}

		$result = trim($_POST['Result'] ?? '');
		$score  = trim($_POST['Score']  ?? '');
		$bouts  = trim($_POST['Bouts']  ?? '[]');

		$allowed_results = ['1-wins', '2-wins', 'tie', 'forfeit', 'disqualified'];
		if (!in_array($result, $allowed_results)) {
			echo json_encode(['status' => 1, 'error' => 'Invalid result value']); exit;
		}

		$r = $this->Tournament->post_match_result([
			'Token'        => $this->session->token,
			'TournamentId' => $tournament_id,
			'MatchId'      => $match_id,
			'Result'       => $result,
			'Score'        => $score,
			'Bouts'        => $bouts,
		]);
		echo ($r['Status'] == 0)
			? json_encode(['status' => 0, 'matchId' => $match_id])
			: $this->modelError($r);
		exit;
	}

	/**
	 * Park autocomplete search.
	 * Route: TournamentAjax/parksearch?q={term}
	 */
	public function parksearch($p = null) {
		header('Content-Type: application/json');
		if (!isset($this->session->user_id)) {
			echo json_encode(['status' => 5, 'error' => 'Not logged in']);
			exit;
		}
		$q = trim($_GET['q'] ?? '');
		if (strlen($q) < 2) {
			echo json_encode([]);
			exit;
		}
		global $DB;
		$rows = $DB->query(
			'SELECT p.park_id, p.name AS park_name, k.kingdom_id, k.name AS kingdom_name '
			. 'FROM ork_park p '
			. 'LEFT JOIN ork_kingdom k ON k.kingdom_id = p.kingdom_id '
			. 'WHERE p.name LIKE :q '
			. 'ORDER BY p.name LIMIT 12',
			[':q' => '%' . $q . '%']
		);
		$results = [];
		if ($rows) {
			while ($rows->next()) {
				$results[] = [
					'ParkId'      => (int)$rows->park_id,
					'ParkName'    => $rows->park_name,
					'KingdomId'   => (int)$rows->kingdom_id,
					'KingdomName' => $rows->kingdom_name,
				];
			}
		}
		echo json_encode($results);
		exit;
	}

	/**
	 * Event autocomplete search.
	 * Route: TournamentAjax/eventsearch?q={term}
	 */
	public function eventsearch($p = null) {
		header('Content-Type: application/json');
		if (!isset($this->session->user_id)) {
			echo json_encode(['status' => 5, 'error' => 'Not logged in']);
			exit;
		}
		$q = trim($_GET['q'] ?? '');
		if (strlen($q) < 2) {
			echo json_encode([]);
			exit;
		}
		global $DB;
		$rows = $DB->query(
			'SELECT cd.event_calendardetail_id, e.name AS event_name, '
			. 'k.abbreviation AS kingdom_abbr, p.abbreviation AS park_abbr, '
			. 'cd.event_start '
			. 'FROM ork_event_calendardetail cd '
			. 'JOIN ork_event e ON e.event_id = cd.event_id '
			. 'LEFT JOIN ork_kingdom k ON k.kingdom_id = e.kingdom_id '
			. 'LEFT JOIN ork_park p ON p.park_id = e.park_id '
			. 'WHERE e.name LIKE :q '
			. 'ORDER BY cd.event_start DESC LIMIT 12',
			[':q' => '%' . $q . '%']
		);
		$results = [];
		if ($rows) {
			while ($rows->next()) {
				$abbr = '';
				if ($rows->kingdom_abbr) $abbr = $rows->kingdom_abbr;
				if ($rows->park_abbr)    $abbr .= ($abbr ? ':' : '') . $rows->park_abbr;
				$dateStr = '';
				if ($rows->event_start && substr($rows->event_start, 0, 10) !== '0000-00-00') {
					$dateStr = date('m/d/Y', strtotime($rows->event_start));
				}
				$label = $rows->event_name;
				if ($abbr)    $label .= ' ' . $abbr;
				if ($dateStr) $label .= ' - ' . $dateStr;
				$results[] = [
					'EcdId'     => (int)$rows->event_calendardetail_id,
					'Label'     => $label,
					'EventName' => $rows->event_name,
				];
			}
		}
		echo json_encode($results);
		exit;
	}

}
