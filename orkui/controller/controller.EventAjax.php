<?php

class Controller_EventAjax extends Controller {

	public function create($p = null) {
		header('Content-Type: application/json');

		if (!isset($this->session->user_id)) {
			echo json_encode(['status' => 5, 'error' => 'Not logged in']);
			exit;
		}

		$this->load_model('Event');
		$name       = trim($_POST['Name']       ?? '');
		$kingdom_id = (int)($_POST['KingdomId'] ?? 0);
		$park_id    = (int)($_POST['ParkId']    ?? 0);

		if (!strlen($name)) {
			echo json_encode(['status' => 1, 'error' => 'Event name is required.']);
			exit;
		}
		if (!valid_id($kingdom_id) && !valid_id($park_id)) {
			echo json_encode(['status' => 1, 'error' => 'A kingdom or park is required.']);
			exit;
		}

		$r = $this->Event->create_event(
			$this->session->token,
			$kingdom_id,
			$park_id,
			0,
			0,
			$name
		);

		if ($r['Status'] == 0) {
			echo json_encode(['status' => 0, 'eventId' => (int)($r['Detail'] ?? 0)]);
		} else {
			echo json_encode(['status' => $r['Status'], 'error' => ($r['Error'] ?? 'Error') . ': ' . ($r['Detail'] ?? '')]);
		}
		exit;
	}

	public function add_attendance($p = null) {
		header('Content-Type: application/json');

		if (!isset($this->session->user_id)) {
			echo json_encode(['status' => 5, 'error' => 'Not logged in']);
			exit;
		}

		$this->load_model('Attendance');

		$params    = explode( '/', $p ?? '' );
		$event_id  = (int)preg_replace( '/[^0-9]/', '', $params[0] ?? '' );
		$detail_id = (int)preg_replace( '/[^0-9]/', '', $params[1] ?? '' );

		if (!valid_id($event_id) || !valid_id($detail_id)) {
			echo json_encode(['status' => 1, 'error' => 'Invalid Event ID.']);
			exit;
		}

		if (!valid_id($_POST['MundaneId'] ?? 0)) {
			echo json_encode(['status' => 1, 'error' => 'A player must be selected.']);
			exit;
		}

		if (!valid_id($_POST['ClassId'] ?? 0)) {
			echo json_encode(['status' => 1, 'error' => 'A class must be selected.']);
			exit;
		}

		$detail = $this->Attendance->get_eventdetail_info($detail_id);
		$r = $this->Attendance->add_attendance(
			$this->session->token,
			$_POST['AttendanceDate'] ?? date('Y-m-d'),
			valid_id($detail['AtParkId']) ? $detail['AtParkId'] : null,
			$detail_id,
			$_POST['MundaneId'] ?? 0,
			$_POST['ClassId'] ?? 0,
			$_POST['Credits'] ?? 1
		);

		if ($r['Status'] == 0) {
			global $DB;
			$aid = (int)$r['Detail'];
			$row = $DB->DataSet("SELECT a.attendance_id AS AttendanceId, a.mundane_id AS MundaneId, m.persona AS Persona, a.kingdom_id AS KingdomId, k.name AS KingdomName, a.park_id AS ParkId, p.name AS ParkName, c.name AS ClassName, a.credits AS Credits FROM ork_attendance a LEFT JOIN ork_mundane m ON m.mundane_id = a.mundane_id LEFT JOIN ork_park p ON p.park_id = a.park_id LEFT JOIN ork_kingdom k ON k.kingdom_id = a.kingdom_id LEFT JOIN ork_class c ON c.class_id = a.class_id WHERE a.attendance_id = $aid");
			if ($row && $row->Size() > 0 && $row->Next()) {
				echo json_encode(['status' => 0, 'attendance' => [
					'AttendanceId' => $row->AttendanceId,
					'MundaneId'    => $row->MundaneId,
					'Persona'      => $row->Persona,
					'KingdomId'    => $row->KingdomId,
					'KingdomName'  => $row->KingdomName,
					'ParkId'       => $row->ParkId,
					'ParkName'     => $row->ParkName,
					'ClassName'    => $row->ClassName,
					'Credits'      => $row->Credits,
				]]);
			} else {
				echo json_encode(['status' => 0, 'attendance' => null]);
			}
		} else {
			echo json_encode(['status' => $r['Status'], 'error' => ($r['Error'] ?? 'Error') . ': ' . ($r['Detail'] ?? '')]);
		}
		exit;
	}

	public function delete_rsvp($p = null) {
		header('Content-Type: application/json');

		if (!isset($this->session->user_id)) {
			echo json_encode(['status' => 5, 'error' => 'Not logged in']);
			exit;
		}

		$params     = explode('/', $p ?? '');
		$event_id   = (int)preg_replace('/[^0-9]/', '', $params[0] ?? '');
		$detail_id  = (int)preg_replace('/[^0-9]/', '', $params[1] ?? '');
		$mundane_id = (int)($_POST['MundaneId'] ?? 0);

		if (!valid_id($event_id) || !valid_id($detail_id) || !valid_id($mundane_id)) {
			echo json_encode(['status' => 1, 'error' => 'Invalid parameters.']);
			exit;
		}

		$uid = (int)$this->session->user_id;
		if (!Ork3::$Lib->authorization->HasAuthority($uid, AUTH_EVENT, $event_id, AUTH_CREATE)) {
			global $DB;
			$DB->Clear();
			$staffRow = $DB->DataSet('SELECT 1 FROM ' . DB_PREFIX . 'event_staff WHERE event_calendardetail_id = ' . $detail_id . ' AND mundane_id = ' . $uid . ' AND can_attendance = 1 LIMIT 1');
			if (!($staffRow && $staffRow->Next())) {
				echo json_encode(['status' => 3, 'error' => 'Not authorized.']);
				exit;
			}
		}

		$this->load_model('Event');
		$this->Event->remove_rsvp($detail_id, $mundane_id);
		echo json_encode(['status' => 0]);
		exit;
	}

	public function cancel($p = null) {
		header('Content-Type: application/json');

		if (!isset($this->session->user_id)) {
			echo json_encode(['status' => 5, 'error' => 'Not logged in']);
			exit;
		}

		$event_id = (int)($_POST['EventId'] ?? 0);

		if (!valid_id($event_id)) {
			echo json_encode(['status' => 1, 'error' => 'Invalid Event ID.']);
			exit;
		}

		$this->load_model('Event');
		$r = $this->Event->delete_event($this->session->token, $event_id);

		if (isset($r['Status']) && $r['Status'] == 0) {
			echo json_encode(['status' => 0]);
		} else {
			echo json_encode(['status' => $r['Status'] ?? 1, 'error' => $r['Detail'] ?? 'Could not cancel event.']);
		}
		exit;
	}

	public function add_staff($p = null) {
		header('Content-Type: application/json');

		if (!isset($this->session->user_id)) {
			echo json_encode(['status' => 5, 'error' => 'Not logged in']);
			exit;
		}

		$params    = explode('/', $p ?? '');
		$event_id  = (int)preg_replace('/[^0-9]/', '', $params[0] ?? '');
		$detail_id = (int)preg_replace('/[^0-9]/', '', $params[1] ?? '');

		if (!valid_id($event_id) || !valid_id($detail_id)) {
			echo json_encode(['status' => 1, 'error' => 'Invalid Event ID.']);
			exit;
		}

		if (!Ork3::$Lib->authorization->HasAuthority((int)$this->session->user_id, AUTH_EVENT, $event_id, AUTH_CREATE)) {
			echo json_encode(['status' => 3, 'error' => 'Not authorized.']);
			exit;
		}

		$mundane_id    = (int)($_POST['MundaneId']    ?? 0);
		$role_name     = trim($_POST['RoleName']      ?? '');
		$can_manage    = (int)(bool)($_POST['CanManage']    ?? 0);
		$can_attendance = (int)(bool)($_POST['CanAttendance'] ?? 0);

		if (!valid_id($mundane_id)) {
			echo json_encode(['status' => 1, 'error' => 'A player must be selected.']);
			exit;
		}
		if (!$role_name) {
			echo json_encode(['status' => 1, 'error' => 'A role is required.']);
			exit;
		}

		global $DB;
		$role_safe = str_replace(["'", '\\'], ["''", '\\\\'], $role_name);
		$DB->Clear(); // reset stale bound params from prior ORM queries in this request
		$DB->Execute(
			'INSERT INTO ' . DB_PREFIX . 'event_staff
			(event_calendardetail_id, mundane_id, role_name, can_manage, can_attendance)
			VALUES (' . $detail_id . ', ' . $mundane_id . ', \'' . $role_safe . '\', ' . $can_manage . ', ' . $can_attendance . ')
			ON DUPLICATE KEY UPDATE role_name = VALUES(role_name), can_manage = VALUES(can_manage), can_attendance = VALUES(can_attendance)'
		);
		$DB->Clear();
		$idrow = $DB->DataSet('SELECT event_staff_id FROM ' . DB_PREFIX . 'event_staff WHERE event_calendardetail_id = ' . $detail_id . ' AND mundane_id = ' . $mundane_id . ' ORDER BY event_staff_id DESC LIMIT 1');
		$staff_id = ($idrow && $idrow->Next()) ? (int)$idrow->event_staff_id : 0;
		echo json_encode(['status' => 0, 'staff' => [
			'EventStaffId'  => $staff_id,
			'MundaneId'     => (int)$mundane_id,
			'Persona'       => trim($_POST['Persona'] ?? ''),
			'RoleName'      => $role_name,
			'CanManage'     => $can_manage,
			'CanAttendance' => $can_attendance,
		]]);
		exit;
	}

	public function remove_staff($p = null) {
		header('Content-Type: application/json');

		if (!isset($this->session->user_id)) {
			echo json_encode(['status' => 5, 'error' => 'Not logged in']);
			exit;
		}

		$params    = explode('/', $p ?? '');
		$event_id  = (int)preg_replace('/[^0-9]/', '', $params[0] ?? '');
		$detail_id = (int)preg_replace('/[^0-9]/', '', $params[1] ?? '');
		$staff_id  = (int)($_POST['StaffId'] ?? 0);

		if (!valid_id($event_id) || !valid_id($detail_id) || !valid_id($staff_id)) {
			echo json_encode(['status' => 1, 'error' => 'Invalid parameters.']);
			exit;
		}

		if (!Ork3::$Lib->authorization->HasAuthority((int)$this->session->user_id, AUTH_EVENT, $event_id, AUTH_CREATE)) {
			echo json_encode(['status' => 3, 'error' => 'Not authorized.']);
			exit;
		}

		global $DB;
		$DB->Clear();
		$DB->Execute(
			'DELETE FROM ' . DB_PREFIX . 'event_staff
			WHERE event_staff_id = ' . $staff_id . ' AND event_calendardetail_id = ' . $detail_id
		);
		echo json_encode(['status' => 0]);
		exit;
	}

	public function add_schedule($p = null) {
		header('Content-Type: application/json');
		if (!isset($this->session->user_id)) {
			echo json_encode(['status' => 5, 'error' => 'Not logged in']); exit;
		}

		$params    = explode('/', $p ?? '');
		$event_id  = (int)preg_replace('/[^0-9]/', '', $params[0] ?? '');
		$detail_id = (int)preg_replace('/[^0-9]/', '', $params[1] ?? '');

		if (!valid_id($event_id) || !valid_id($detail_id)) {
			echo json_encode(['status' => 1, 'error' => 'Invalid Event ID.']); exit;
		}

		$uid = (int)$this->session->user_id;
		if (!Ork3::$Lib->authorization->HasAuthority($uid, AUTH_EVENT, $event_id, AUTH_EDIT)) {
			global $DB;
			$DB->Clear();
			$staffRow = $DB->DataSet('SELECT 1 FROM ' . DB_PREFIX . 'event_staff WHERE event_calendardetail_id = ' . $detail_id . ' AND mundane_id = ' . $uid . ' AND can_manage = 1 LIMIT 1');
			if (!($staffRow && $staffRow->Next())) {
				echo json_encode(['status' => 3, 'error' => 'Not authorized.']); exit;
			}
		}

		$title       = trim($_POST['Title']       ?? '');
		$start_time  = trim($_POST['StartTime']   ?? '');
		$end_time    = trim($_POST['EndTime']     ?? '');
		$location    = trim($_POST['Location']    ?? '');
		$description = trim($_POST['Description'] ?? '');
		$category    = trim($_POST['Category']    ?? 'Other');
		$allowed_cats = ['Administrative','Tournament','Battlegame','Arts and Sciences','Class','Feast and Food','Court','Other'];
		if (!in_array($category, $allowed_cats)) $category = 'Other';

		if (!$title)      { echo json_encode(['status' => 1, 'error' => 'A title is required.']); exit; }
		if (!$start_time) { echo json_encode(['status' => 1, 'error' => 'A start time is required.']); exit; }
		if (!$end_time)   { echo json_encode(['status' => 1, 'error' => 'An end time is required.']); exit; }

		$startTs = strtotime($start_time);
		$endTs   = strtotime($end_time);
		if (!$startTs || !$endTs)  { echo json_encode(['status' => 1, 'error' => 'Invalid time format.']); exit; }
		if ($endTs < $startTs)     { echo json_encode(['status' => 1, 'error' => 'End time cannot be before start time.']); exit; }

		$title_safe       = str_replace(["'", '\\'], ["''", '\\\\'], $title);
		$location_safe    = str_replace(["'", '\\'], ["''", '\\\\'], $location);
		$description_safe = str_replace(["'", '\\'], ["''", '\\\\'], $description);
		$category_safe    = str_replace(["'", '\\'], ["''", '\\\\'], $category);
		$start_fmt = date('Y-m-d H:i:s', $startTs);
		$end_fmt   = date('Y-m-d H:i:s', $endTs);

		global $DB;
		$DB->Clear();
		$DB->Execute(
			'INSERT INTO ' . DB_PREFIX . 'event_schedule
			(event_calendardetail_id, title, start_time, end_time, location, description, category)
			VALUES (' . $detail_id . ', \'' . $title_safe . '\', \'' . $start_fmt . '\', \'' . $end_fmt . '\', \'' . $location_safe . '\', \'' . $description_safe . '\', \'' . $category_safe . '\')'
		);
		$DB->Clear();
		$idrow = $DB->DataSet('SELECT event_schedule_id FROM ' . DB_PREFIX . 'event_schedule WHERE event_calendardetail_id = ' . $detail_id . ' ORDER BY event_schedule_id DESC LIMIT 1');
		$schedule_id = ($idrow && $idrow->Next()) ? (int)$idrow->event_schedule_id : 0;

		// Sync leads
		$leadsJson = trim($_POST['Leads'] ?? '');
		$leadsIn = ($leadsJson !== '') ? json_decode($leadsJson, true) : [];
		$leadsOut = [];
		if (is_array($leadsIn)) {
			$DB->Clear();
			foreach ($leadsIn as $lead) {
				$lmid = (int)($lead['MundaneId'] ?? 0);
				if (!valid_id($lmid)) continue;
				$DB->Execute('INSERT IGNORE INTO ' . DB_PREFIX . 'event_schedule_lead (event_schedule_id, mundane_id) VALUES (' . $schedule_id . ', ' . $lmid . ')');
				$leadsOut[] = ['MundaneId' => $lmid, 'Persona' => $lead['Persona'] ?? ''];
			}
		}

		echo json_encode(['status' => 0, 'schedule' => [
			'EventScheduleId' => $schedule_id,
			'Title'           => $title,
			'StartTime'       => $start_fmt,
			'EndTime'         => $end_fmt,
			'Location'        => $location,
			'Description'     => $description,
			'Category'        => $category,
			'Leads'           => $leadsOut,
		]]);
		exit;
	}

	public function remove_schedule($p = null) {
		header('Content-Type: application/json');
		if (!isset($this->session->user_id)) {
			echo json_encode(['status' => 5, 'error' => 'Not logged in']); exit;
		}

		$params      = explode('/', $p ?? '');
		$event_id    = (int)preg_replace('/[^0-9]/', '', $params[0] ?? '');
		$detail_id   = (int)preg_replace('/[^0-9]/', '', $params[1] ?? '');
		$schedule_id = (int)($_POST['ScheduleId'] ?? 0);

		if (!valid_id($event_id) || !valid_id($detail_id) || !valid_id($schedule_id)) {
			echo json_encode(['status' => 1, 'error' => 'Invalid parameters.']); exit;
		}

		$uid = (int)$this->session->user_id;
		if (!Ork3::$Lib->authorization->HasAuthority($uid, AUTH_EVENT, $event_id, AUTH_EDIT)) {
			global $DB;
			$DB->Clear();
			$staffRow = $DB->DataSet('SELECT 1 FROM ' . DB_PREFIX . 'event_staff WHERE event_calendardetail_id = ' . $detail_id . ' AND mundane_id = ' . $uid . ' AND can_manage = 1 LIMIT 1');
			if (!($staffRow && $staffRow->Next())) {
				echo json_encode(['status' => 3, 'error' => 'Not authorized.']); exit;
			}
		}

		global $DB;
		$DB->Clear();
		$DB->Execute(
			'DELETE FROM ' . DB_PREFIX . 'event_schedule WHERE event_schedule_id = ' . $schedule_id . ' AND event_calendardetail_id = ' . $detail_id
		);
		echo json_encode(['status' => 0]);
		exit;
	}

	public function update_schedule($p = null) {
		header('Content-Type: application/json');
		if (!isset($this->session->user_id)) {
			echo json_encode(['status' => 5, 'error' => 'Not logged in']); exit;
		}

		$params      = explode('/', $p ?? '');
		$event_id    = (int)preg_replace('/[^0-9]/', '', $params[0] ?? '');
		$detail_id   = (int)preg_replace('/[^0-9]/', '', $params[1] ?? '');
		$schedule_id = (int)($_POST['ScheduleId'] ?? 0);

		if (!valid_id($event_id) || !valid_id($detail_id) || !valid_id($schedule_id)) {
			echo json_encode(['status' => 1, 'error' => 'Invalid parameters.']); exit;
		}

		$uid = (int)$this->session->user_id;
		if (!Ork3::$Lib->authorization->HasAuthority($uid, AUTH_EVENT, $event_id, AUTH_EDIT)) {
			global $DB;
			$DB->Clear();
			$staffRow = $DB->DataSet('SELECT 1 FROM ' . DB_PREFIX . 'event_staff WHERE event_calendardetail_id = ' . $detail_id . ' AND mundane_id = ' . $uid . ' AND can_manage = 1 LIMIT 1');
			if (!($staffRow && $staffRow->Next())) {
				echo json_encode(['status' => 3, 'error' => 'Not authorized.']); exit;
			}
		}

		$title       = trim($_POST['Title']       ?? '');
		$start_time  = trim($_POST['StartTime']   ?? '');
		$end_time    = trim($_POST['EndTime']     ?? '');
		$location    = trim($_POST['Location']    ?? '');
		$description = trim($_POST['Description'] ?? '');
		$category    = trim($_POST['Category']    ?? 'Other');
		$allowed_cats = ['Administrative','Tournament','Battlegame','Arts and Sciences','Class','Feast and Food','Court','Other'];
		if (!in_array($category, $allowed_cats)) $category = 'Other';

		if (!$title)      { echo json_encode(['status' => 1, 'error' => 'A title is required.']); exit; }
		if (!$start_time) { echo json_encode(['status' => 1, 'error' => 'A start time is required.']); exit; }
		if (!$end_time)   { echo json_encode(['status' => 1, 'error' => 'An end time is required.']); exit; }

		$startTs = strtotime($start_time);
		$endTs   = strtotime($end_time);
		if (!$startTs || !$endTs)  { echo json_encode(['status' => 1, 'error' => 'Invalid time format.']); exit; }
		if ($endTs < $startTs)     { echo json_encode(['status' => 1, 'error' => 'End time cannot be before start time.']); exit; }

		$title_safe       = str_replace(["'", '\\'], ["''", '\\\\'], $title);
		$location_safe    = str_replace(["'", '\\'], ["''", '\\\\'], $location);
		$description_safe = str_replace(["'", '\\'], ["''", '\\\\'], $description);
		$category_safe    = str_replace(["'", '\\'], ["''", '\\\\'], $category);
		$start_fmt = date('Y-m-d H:i:s', $startTs);
		$end_fmt   = date('Y-m-d H:i:s', $endTs);

		global $DB;
		$DB->Clear();
		$DB->Execute(
			'UPDATE ' . DB_PREFIX . 'event_schedule SET ' .
			'title = \'' . $title_safe . '\', ' .
			'start_time = \'' . $start_fmt . '\', ' .
			'end_time = \'' . $end_fmt . '\', ' .
			'location = \'' . $location_safe . '\', ' .
			'description = \'' . $description_safe . '\', ' .
			'category = \'' . $category_safe . '\' ' .
			'WHERE event_schedule_id = ' . $schedule_id . ' AND event_calendardetail_id = ' . $detail_id
		);

		// Sync leads (replace all)
		$leadsJson = trim($_POST['Leads'] ?? '');
		$leadsIn = ($leadsJson !== '') ? json_decode($leadsJson, true) : [];
		$leadsOut = [];
		$DB->Clear();
		$DB->Execute('DELETE FROM ' . DB_PREFIX . 'event_schedule_lead WHERE event_schedule_id = ' . $schedule_id);
		if (is_array($leadsIn)) {
			foreach ($leadsIn as $lead) {
				$lmid = (int)($lead['MundaneId'] ?? 0);
				if (!valid_id($lmid)) continue;
				$DB->Execute('INSERT IGNORE INTO ' . DB_PREFIX . 'event_schedule_lead (event_schedule_id, mundane_id) VALUES (' . $schedule_id . ', ' . $lmid . ')');
				$leadsOut[] = ['MundaneId' => $lmid, 'Persona' => $lead['Persona'] ?? ''];
			}
		}

		echo json_encode(['status' => 0, 'schedule' => [
			'EventScheduleId' => $schedule_id,
			'Title'           => $title,
			'StartTime'       => $start_fmt,
			'EndTime'         => $end_fmt,
			'Location'        => $location,
			'Description'     => $description,
			'Category'        => $category,
			'Leads'           => $leadsOut,
		]]);
		exit;
	}

	public function heraldry($p = null) {
		header('Content-Type: application/json');

		if (!isset($this->session->user_id)) {
			echo json_encode(['status' => 5, 'error' => 'Not logged in']);
			exit;
		}

		$params   = explode('/', $p ?? '');
		$event_id = (int)preg_replace('/[^0-9]/', '', $params[0] ?? '');
		$action   = $params[1] ?? '';

		if (!valid_id($event_id)) {
			echo json_encode(['status' => 1, 'error' => 'Invalid Event ID.']);
			exit;
		}

		$hUid = (int)$this->session->user_id;
		$hCanManage = Ork3::$Lib->authorization->HasAuthority($hUid, AUTH_EVENT, $event_id, AUTH_EDIT);
		if (!$hCanManage) {
			global $DB;
			$DB->Clear();
			$staffRow = $DB->DataSet('SELECT 1 FROM ' . DB_PREFIX . 'event_staff s JOIN ' . DB_PREFIX . 'event_calendardetail cd ON cd.event_calendardetail_id = s.event_calendardetail_id WHERE cd.event_id = ' . $event_id . ' AND s.mundane_id = ' . $hUid . ' AND s.can_manage = 1 LIMIT 1');
			$hCanManage = $staffRow && $staffRow->Next();
		}
		if (!$hCanManage) {
			echo json_encode(['status' => 3, 'error' => 'Not authorized.']);
			exit;
		}

		if ($action === 'remove') {
			global $DB;
			$DB->Execute('UPDATE ' . DB_PREFIX . 'event SET has_heraldry = 0 WHERE event_id = ' . $event_id);
			$base = DIR_EVENT_HERALDRY . sprintf('%05d', $event_id);
			if (file_exists($base . '.jpg')) unlink($base . '.jpg');
			if (file_exists($base . '.png')) unlink($base . '.png');
			echo json_encode(['status' => 0]);
			exit;
		}

		if ($action === 'update') {
			if (empty($_FILES['Heraldry']['tmp_name'])) {
				echo json_encode(['status' => 1, 'error' => 'No file uploaded.']);
				exit;
			}
			$tmp  = $_FILES['Heraldry']['tmp_name'];
			$mime = $_FILES['Heraldry']['type'] ?? 'image/jpeg';
			$r = Ork3::$Lib->heraldry->SetEventHeraldry([
				'Token'            => $this->session->token,
				'EventId'          => $event_id,
				'Heraldry'         => base64_encode(file_get_contents($tmp)),
				'HeraldryMimeType' => $mime,
			]);
			if (isset($r['Status']) && $r['Status'] == 0) {
				echo json_encode(['status' => 0]);
			} else {
				echo json_encode(['status' => 1, 'error' => $r['Error'] ?? 'Upload failed.']);
			}
			exit;
		}

		echo json_encode(['status' => 1, 'error' => 'Unknown action.']);
		exit;
	}
}
