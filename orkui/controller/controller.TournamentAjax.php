<?php

class Controller_TournamentAjax extends Controller {

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
				: json_encode(['status' => $r['Status'], 'error' => ($r['Error'] ?? 'Error') . ': ' . ($r['Detail'] ?? '')]);

		} elseif ($action === 'addbracket') {
			$style = trim($_POST['Style']  ?? '');
			$method = trim($_POST['Method'] ?? '');
			if (!strlen($style) || !strlen($method)) {
				echo json_encode(['status' => 1, 'error' => 'Style and method are required.']); exit;
			}
			$r = $this->Tournament->add_bracket([
				'Token'        => $this->session->token,
				'TournamentId' => $tournament_id,
				'Style'        => $style,
				'StyleNote'    => trim($_POST['StyleNote']   ?? ''),
				'Method'       => $method,
				'Rings'        => max(1, min(20, (int)($_POST['Rings'] ?? 1))),
				'Participants' => trim($_POST['Participants'] ?? 'individual'),
				'Seeding'      => trim($_POST['Seeding']      ?? 'random'),
			]);
			echo ($r['Status'] == 0)
				? json_encode(['status' => 0, 'bracketId' => (int)($r['Detail'] ?? 0)])
				: json_encode(['status' => $r['Status'], 'error' => ($r['Error'] ?? 'Error') . ': ' . ($r['Detail'] ?? '')]);

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
				: json_encode(['status' => $r['Status'], 'error' => ($r['Error'] ?? 'Error') . ': ' . ($r['Detail'] ?? '')]);

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
			$r = $this->Tournament->update_bracket([
				'Token'        => $this->session->token,
				'TournamentId' => $tournament_id,
				'BracketId'    => $bracket_id,
				'Style'        => $style,
				'StyleNote'    => trim($_POST['StyleNote']   ?? ''),
				'Method'       => $method,
				'Rings'        => max(1, min(20, (int)($_POST['Rings'] ?? 1))),
				'Participants' => trim($_POST['Participants'] ?? 'individual'),
				'Seeding'      => trim($_POST['Seeding']      ?? 'random'),
			]);
			echo ($r['Status'] == 0)
				? json_encode(['status' => 0, 'bracketId' => (int)($r['Detail'] ?? 0)])
				: json_encode(['status' => $r['Status'], 'error' => ($r['Error'] ?? 'Error') . ': ' . ($r['Detail'] ?? '')]);

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
				: json_encode(['status' => $r['Status'], 'error' => ($r['Error'] ?? 'Error') . ': ' . ($r['Detail'] ?? '')]);

		} elseif ($action === 'matches') {
			$r = $this->Tournament->get_matches(['BracketId' => $bracket_id]);
			echo ($r['Status'] == 0)
				? json_encode(['status' => 0, 'matches' => $r['Detail'] ?? []])
				: json_encode(['status' => $r['Status'], 'error' => ($r['Error'] ?? 'Error') . ': ' . ($r['Detail'] ?? '')]);

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

			$r = $this->Tournament->add_participant([
				'Token'        => $this->session->token,
				'TournamentId' => $tid,
				'BracketId'    => $bracket_id,
				'Alias'        => $alias,
				'MundaneId'    => $mundaneId,
				'UnitId'       => (int)($_POST['UnitId']    ?? 0),
				'ParkId'       => (int)($_POST['ParkId']    ?? 0),
				'KingdomId'    => (int)($_POST['KingdomId'] ?? 0),
			]);
			echo ($r['Status'] == 0)
				? json_encode(['status' => 0, 'participantId' => (int)($r['Detail'] ?? 0)])
				: json_encode(['status' => $r['Status'], 'error' => ($r['Error'] ?? 'Error') . ': ' . ($r['Detail'] ?? '')]);

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
				: json_encode(['status' => $r['Status'], 'error' => ($r['Error'] ?? 'Error') . ': ' . ($r['Detail'] ?? '')]);

		} elseif ($action === 'reorder') {
			// Update seed order for participants (Phase 7 — drag-drop)
			$order_json = trim($_POST['Order'] ?? '');
			$order_arr  = json_decode($order_json, true);
			if (!is_array($order_arr)) {
				echo json_encode(['status' => 1, 'error' => 'Invalid order data.']); exit;
			}
			$this->load_model('Tournament');
			foreach ($order_arr as $seed => $participant_id) {
				$pid = (int)$participant_id;
				$s   = (int)$seed + 1;
				if (valid_id($pid)) {
					global $DB;
					$DB->query("UPDATE ork_participant SET seed = $s WHERE participant_id = $pid AND bracket_id = $bracket_id");
				}
			}
			echo json_encode(['status' => 0]);

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

		if (!isset($this->session->user_id)) {
			echo json_encode(['status' => 5, 'error' => 'Not logged in']);
			exit;
		}

		if (!valid_id($match_id) || !valid_id($tournament_id)) {
			echo json_encode(['status' => 1, 'error' => 'Invalid match or tournament ID']);
			exit;
		}

		$this->load_model('Tournament');

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
			: json_encode(['status' => $r['Status'], 'error' => ($r['Error'] ?? 'Error') . ': ' . ($r['Detail'] ?? '')]);
		exit;
	}

}
