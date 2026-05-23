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

		if (!valid_id($tournament_id)) {
			echo json_encode(['status' => 1, 'error' => 'Invalid tournament ID']);
			exit;
		}

		$this->load_model('Tournament');

		// ── Public, read-only actions (spectator) — no session required ──
		// These expose read-only data only; no mutation is reachable here.
		if ($action === 'version') {
			$r = $this->Tournament->get_version(['TournamentId' => $tournament_id]);
			echo ($r['Status'] == 0)
				? json_encode(['status' => 0, 'version' => $r['Detail']['Version'] ?? ''])
				: $this->modelError($r);
			exit;

		} elseif ($action === 'brackets') {
			$r = $this->Tournament->get_brackets($tournament_id);
			echo ($r['Status'] == 0)
				? json_encode(['status' => 0, 'brackets' => $r['Detail'] ?? []])
				: $this->modelError($r);
			exit;
		}

		// ── All other tournament actions require a logged-in session ──
		if (!isset($this->session->user_id)) {
			echo json_encode(['status' => 5, 'error' => 'Not logged in']);
			exit;
		}

		if ($action === 'reeves') {
			$r = $this->Tournament->get_reeves([
				'Token'        => $this->session->token,
				'TournamentId' => $tournament_id,
			]);
			echo ($r['Status'] == 0)
				? json_encode(['status' => 0, 'reeves' => $r['Detail'] ?? []])
				: $this->modelError($r);

		} elseif ($action === 'addreeve') {
			$mundaneId = (int)($_POST['MundaneId'] ?? 0);
			$role      = trim($_POST['Role'] ?? '');
			if (!valid_id($mundaneId)) {
				echo json_encode(['status' => 1, 'error' => 'MundaneId required.']); exit;
			}
			if (!in_array($role, ['organizer', 'bracket_runner'], true)) {
				echo json_encode(['status' => 1, 'error' => 'Invalid role.']); exit;
			}
			$r = $this->Tournament->add_reeve([
				'Token'        => $this->session->token,
				'TournamentId' => $tournament_id,
				'MundaneId'    => $mundaneId,
				'Role'         => $role,
			]);
			echo ($r['Status'] == 0)
				? json_encode(['status' => 0, 'mundaneId' => $mundaneId, 'role' => $role])
				: $this->modelError($r);

		} elseif ($action === 'removereeve') {
			$mundaneId = (int)($_POST['MundaneId'] ?? 0);
			if (!valid_id($mundaneId)) {
				echo json_encode(['status' => 1, 'error' => 'MundaneId required.']); exit;
			}
			$r = $this->Tournament->remove_reeve([
				'Token'        => $this->session->token,
				'TournamentId' => $tournament_id,
				'MundaneId'    => $mundaneId,
			]);
			echo ($r['Status'] == 0)
				? json_encode(['status' => 0, 'mundaneId' => $mundaneId])
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
				'BestOf'          => (int)($_POST['BestOf'] ?? 1),
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
				'BestOf'          => (int)($_POST['BestOf'] ?? 1),
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

		} elseif ($action === 'roundrobintiebreaker') {
			$bracket_id = (int)($_POST['BracketId'] ?? 0);
			if (!valid_id($bracket_id)) {
				echo json_encode(['status' => 1, 'error' => 'BracketId required.']); exit;
			}
			$r = $this->Tournament->create_round_robin_tiebreaker([
				'Token'        => $this->session->token,
				'TournamentId' => $tournament_id,
				'BracketId'    => $bracket_id,
			]);
			echo ($r['Status'] == 0)
				? json_encode(['status' => 0, 'detail' => $r['Detail']])
				: $this->modelError($r);

		} elseif ($action === 'roundrobindecline') {
			$bracket_id = (int)($_POST['BracketId'] ?? 0);
			if (!valid_id($bracket_id)) {
				echo json_encode(['status' => 1, 'error' => 'BracketId required.']); exit;
			}
			$r = $this->Tournament->decline_round_robin_tiebreaker([
				'Token'        => $this->session->token,
				'TournamentId' => $tournament_id,
				'BracketId'    => $bracket_id,
			]);
			echo ($r['Status'] == 0)
				? json_encode(['status' => 0, 'bracketId' => $bracket_id])
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
			$points_raw = trim($_POST['Points'] ?? '');
			if ($points_raw === '') {
				echo json_encode(['status' => 1, 'error' => 'Points data is required.']); exit;
			}
			$points_arr = json_decode($points_raw, true);
			$r = $this->Tournament->save_standings_points([
				'Token'        => $this->session->token,
				'TournamentId' => $tournament_id,
				'Points'       => $points_arr,
			]);
			echo ($r['Status'] == 0)
				? json_encode(['status' => 0, 'points' => $r['Detail'] ?? []])
				: $this->modelError($r);

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

		if (!valid_id($bracket_id)) {
			echo json_encode(['status' => 1, 'error' => 'Invalid bracket ID']);
			exit;
		}

		$this->load_model('Tournament');

		// ── Public, read-only actions (spectator) — no session required ──
		// These expose read-only data only; no mutation is reachable here.
		if ($action === 'participants') {
			$r = $this->Tournament->get_participants(['BracketId' => $bracket_id]);
			echo ($r['Status'] == 0)
				? json_encode(['status' => 0, 'participants' => $r['Detail'] ?? []])
				: $this->modelError($r);
			exit;

		} elseif ($action === 'matches') {
			$r = $this->Tournament->get_matches(['BracketId' => $bracket_id]);
			echo ($r['Status'] == 0)
				? json_encode(['status' => 0, 'matches' => $r['Detail'] ?? []])
				: $this->modelError($r);
			exit;
		}

		// ── All other bracket actions require a logged-in session ──
		if (!isset($this->session->user_id)) {
			echo json_encode(['status' => 5, 'error' => 'Not logged in']);
			exit;
		}

		if ($action === 'addparticipant') {
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
				? json_encode(array_merge(['status' => 0], is_array($r['Detail']) ? $r['Detail'] : ['FightNum' => (int)($r['Detail'] ?? 0)]))
				: $this->modelError($r);

		} elseif ($action === 'poolstobrackets') {
			// Create a single/double-elim playoff from the top X of this Ironman's pool.
			$tid = (int)($_POST['TournamentId'] ?? 0);
			if (!valid_id($tid)) {
				echo json_encode(['status' => 1, 'error' => 'TournamentId required.']); exit;
			}
			$r = $this->Tournament->pools_to_bracket([
				'Token'        => $this->session->token,
				'TournamentId' => $tid,
				'BracketId'    => $bracket_id,
				'Method'       => trim($_POST['Method'] ?? ''),
				'TopX'         => (int)($_POST['TopX'] ?? 0),
				'SeedMethod'   => trim($_POST['SeedMethod'] ?? 'standing'),
			]);
			echo ($r['Status'] == 0)
				? json_encode(['status' => 0, 'bracketId' => (int)($r['Detail'] ?? 0)])
				: $this->modelError($r);

		} elseif ($action === 'reorder') {
			// Update seed order for participants (Phase 7 — drag-drop)
			$tid = (int)($_POST['TournamentId'] ?? 0);
			if (!valid_id($tid)) {
				echo json_encode(['status' => 1, 'error' => 'TournamentId required.']); exit;
			}
			$order_json = trim($_POST['Order'] ?? '');
			$order_arr  = json_decode($order_json, true);
			$r = $this->Tournament->reorder_seeds([
				'Token'        => $this->session->token,
				'TournamentId' => $tid,
				'BracketId'    => $bracket_id,
				'Order'        => $order_arr,
			]);
			echo ($r['Status'] == 0)
				? json_encode(['status' => 0])
				: $this->modelError($r);

		} elseif ($action === 'updateparticipantstatus') {
			$tid = (int)($_POST['TournamentId'] ?? 0);
			if (!valid_id($tid)) {
				echo json_encode(['status' => 1, 'error' => 'TournamentId required.']); exit;
			}
			$participant_id = (int)($_POST['ParticipantId'] ?? 0);
			if (!valid_id($participant_id)) {
				echo json_encode(['status' => 1, 'error' => 'ParticipantId required.']); exit;
			}
			$r = $this->Tournament->update_participant_status([
				'Token'         => $this->session->token,
				'TournamentId'  => $tid,
				'BracketId'     => $bracket_id,
				'ParticipantId' => $participant_id,
				'Status'        => trim($_POST['Status'] ?? ''),
			]);
			echo ($r['Status'] == 0)
				? json_encode(['status' => 0, 'participantId' => (int)($r['Detail']['ParticipantId'] ?? $participant_id), 'newStatus' => $r['Detail']['Status'] ?? ''])
				: $this->modelError($r);

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
		$this->load_model('Tournament');
		$r = $this->Tournament->search_parks($q);
		echo json_encode(($r['Status'] == 0) ? ($r['Detail'] ?? []) : []);
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
		$this->load_model('Tournament');
		$r = $this->Tournament->search_events($q);
		echo json_encode(($r['Status'] == 0) ? ($r['Detail'] ?? []) : []);
		exit;
	}

}
