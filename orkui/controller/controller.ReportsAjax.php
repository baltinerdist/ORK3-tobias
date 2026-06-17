<?php

class Controller_ReportsAjax extends Controller {

	public function slicedice($p = null) {
		header('Content-Type: application/json');

		if (!isset($this->session->user_id)) {
			echo json_encode(['status' => 5, 'error' => 'Not logged in']);
			exit;
		}

		$session_kid = (int)($this->session->kingdom_id ?? 0);
		if (!valid_id($session_kid)) {
			echo json_encode(['status' => 1, 'error' => 'No kingdom associated with your account']);
			exit;
		}

		$dataset = trim($_POST['dataset'] ?? '');
		if (!in_array($dataset, ['awards', 'attendance', 'players'])) {
			echo json_encode(['status' => 1, 'error' => 'Invalid dataset']);
			exit;
		}

		$filters = [
			'kingdom_id'    => $session_kid,
			'park_id'       => (int)($_POST['park_id'] ?? 0),
			'date_start'    => $_POST['date_start'] ?? '',
			'date_end'      => $_POST['date_end'] ?? '',
			'award_type'    => trim($_POST['award_type'] ?? ''),
			'award_id'      => (int)($_POST['award_id'] ?? 0),
			'class_id'      => (int)($_POST['class_id'] ?? 0),
			'event_filter'  => trim($_POST['event_filter'] ?? 'all'),
			'player_id'     => (int)($_POST['player_id'] ?? 0),
			'active_status' => trim($_POST['active_status'] ?? 'all'),
			'waiver_status' => trim($_POST['waiver_status'] ?? 'all'),
		];

		if ($filters['date_start'] && !preg_match('/^\d{4}-\d{2}-\d{2}$/', $filters['date_start'])) {
			$filters['date_start'] = '';
		}
		if ($filters['date_end'] && !preg_match('/^\d{4}-\d{2}-\d{2}$/', $filters['date_end'])) {
			$filters['date_end'] = '';
		}

		if ($filters['award_type'] && !in_array($filters['award_type'], ['ladder', 'title', 'nonladder'])) {
			$filters['award_type'] = '';
		}
		if (!in_array($filters['event_filter'], ['all', 'events', 'regular'])) {
			$filters['event_filter'] = 'all';
		}
		if (!in_array($filters['active_status'], ['all', 'active', 'inactive'])) {
			$filters['active_status'] = 'all';
		}
		if (!in_array($filters['waiver_status'], ['all', 'waivered', 'unwaivered'])) {
			$filters['waiver_status'] = 'all';
		}

		$this->load_model('Reports');
		$result = $this->Reports->get_slicedice_data($dataset, $filters);
		echo json_encode($result);
		exit;
	}
}
