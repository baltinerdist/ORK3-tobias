<?php

class Controller_EventAjax extends Controller
{
    public function create($p = null)
    {
        header('Content-Type: application/json');

        if (!isset($this->session->user_id)) {
            echo json_encode(['status' => 5, 'error' => 'Not logged in']);
            exit;
        }

        $this->load_model('EventPlanning');
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

        $r = $this->EventPlanning->create_event(
            $this->session->token,
            $kingdom_id,
            $park_id,
            0,
            0,
            $name,
            (string)($_POST['Status'] ?? 'published')
        );

        if ($r['Status'] == 0) {
            $newId = (int)($r['Detail'] ?? 0);
            echo json_encode(['status' => 0, 'eventId' => $newId]);
        } else {
            echo json_encode(['status' => $r['Status'], 'error' => rtrim(($r['Error'] ?? 'Error') . ': ' . ($r['Detail'] ?? ''), ': ')]);
        }
        exit;
    }

    // Publish / unpublish an event. Caller must hold AUTH_EVENT/AUTH_EDIT.
    public function set_status($p = null)
    {
        header('Content-Type: application/json');
        if (!isset($this->session->user_id)) {
            echo json_encode(['status' => 5, 'error' => 'Not logged in']);
            exit;
        }
        $uid    = (int)$this->session->user_id;
        $evtId  = (int)($_POST['EventId'] ?? 0);
        $status = (string)($_POST['Status'] ?? '');
        if ($evtId <= 0 || !in_array($status, ['published', 'draft'], true)) {
            echo json_encode(['status' => 1, 'error' => 'Invalid parameters']);
            exit;
        }
        $this->load_model('EventPlanning');
        $r = $this->EventPlanning->set_status($this->session->token, $evtId, $status);
        if (($r['Status'] ?? 1) == 0) {
            echo json_encode(['status' => 0, 'event_status' => $status]);
        } else {
            $this->EventPlanning->emit_json($r);
        }
        exit;
    }

    // Lightweight event preview for the calendar grid quick-look modal.
    // Path: EventAjax/preview/{event_id}/{detail_id}
    public function preview($p = null)
    {
        header('Content-Type: application/json');
        $parts    = explode('/', (string)$p);
        $eventId  = (int)preg_replace('/[^0-9]/', '', $parts[0] ?? '');
        $detailId = (int)preg_replace('/[^0-9]/', '', $parts[1] ?? '');
        if ($eventId <= 0) {
            echo json_encode(['status' => 1, 'error' => 'Invalid event id']);
            exit;
        }
        $uid = isset($this->session->user_id) ? (int)$this->session->user_id : 0;
        $this->load_model('EventPlanning');
        $r = $this->EventPlanning->get_preview($eventId, $detailId, $uid);
        $statusCode = is_array($r['Status'] ?? null) ? (int)($r['Status']['Status'] ?? 1) : (int)($r['Status'] ?? 1);
        if ($statusCode !== 0 || !isset($r['Preview'])) {
            if ($statusCode === ServiceErrorIds::NoAuthorization) {
                echo json_encode(['status' => 5, 'error' => 'Not authorized']);
            } elseif ($statusCode === ServiceErrorIds::InvalidParameter) {
                $detail = is_array($r['Status'] ?? null) ? (string)($r['Status']['Detail'] ?? 'Invalid request') : 'Invalid request';
                echo json_encode(['status' => 1, 'error' => $detail]);
            } else {
                echo json_encode(['status' => 1, 'error' => 'Event not found']);
            }
            exit;
        }

        $preview = $r['Preview'];
        $resolvedDetailId = (int)($preview['event_calendardetail_id'] ?? 0);
        echo json_encode([
            'status'           => 0,
            'event_id'         => $eventId,
            'event_calendardetail_id' => $resolvedDetailId,
            'name'             => $preview['name'],
            'park_id'          => (int)$preview['park_id'],
            'park_name'        => $preview['park_name'],
            'is_park_event'    => (bool)$preview['is_park_event'],
            'is_draft'         => (bool)$preview['is_draft'],
            'has_heraldry'     => (bool)$preview['has_heraldry'],
            'date_label'       => $preview['date_label'],
            'time_label'       => $preview['time_label'],
            'price'            => (float)$preview['price'],
            'description_excerpt' => $preview['description_excerpt'],
            'going_count'      => (int)$preview['going_count'],
            'interested_count' => (int)$preview['interested_count'],
            'my_rsvp'          => $preview['my_rsvp'],
            'detail_url'       => $resolvedDetailId > 0 ? (UIR . 'Event/detail/' . $eventId . '/' . $resolvedDetailId) : (UIR . 'Event/index/' . $eventId),
            'can_edit'         => (bool)$preview['can_edit'],
        ]);
        exit;
    }

    public function add_attendance($p = null)
    {
        header('Content-Type: application/json');

        if (!isset($this->session->user_id)) {
            echo json_encode(['status' => 5, 'error' => 'Not logged in']);
            exit;
        }

        $this->load_model('Attendance');
        $this->load_model('EventPlanning');

        $params    = explode('/', $p ?? '');
        $event_id  = (int)preg_replace('/[^0-9]/', '', $params[0] ?? '');
        $detail_id = (int)preg_replace('/[^0-9]/', '', $params[1] ?? '');

        if (!valid_id($event_id) || !valid_id($detail_id)) {
            echo json_encode(['status' => 1, 'error' => 'Invalid Event ID.']);
            exit;
        }

        $uid = (int)$this->session->user_id;
        if (!$this->EventPlanning->can_add_attendance($uid, $event_id, $detail_id)) {
            echo json_encode(['status' => 3, 'error' => 'Not authorized.']);
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

        $eventStartTs = $detail['EventStart'] ? strtotime($detail['EventStart']) : 0;
        if ($eventStartTs && time() < $eventStartTs - 86400) {
            $openLabel = date('D, M j, Y \\a\\t g:i A T', $eventStartTs - 86400);
            echo json_encode(['status' => 1, 'error' => 'Sign-ins for this event can be processed starting on ' . $openLabel . '.']);
            exit;
        }

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
            $aid = (int)$r['Detail'];
            $row = $this->EventPlanning->get_attendance_display_row($aid);
            if ($row) {
                echo json_encode(['status' => 0, 'attendance' => $row + [
                    'ClassId' => (int)($_POST['ClassId'] ?? 0),
                    'Date'    => $_POST['AttendanceDate'] ?? date('Y-m-d'),
                ]]);
            } else {
                echo json_encode(['status' => 0, 'attendance' => null]);
            }
        } else {
            echo json_encode(['status' => $r['Status'], 'error' => rtrim(($r['Error'] ?? 'Error') . ': ' . ($r['Detail'] ?? ''), ': ')]);
        }
        exit;
    }

    public function delete_rsvp($p = null)
    {
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
        $this->load_model('EventPlanning');
        if (!$this->EventPlanning->can_remove_rsvp($uid, $event_id, $detail_id)) {
            echo json_encode(['status' => 3, 'error' => 'Not authorized.']);
            exit;
        }

        $this->EventPlanning->remove_rsvp($detail_id, $mundane_id, $this->session->token);
        echo json_encode(['status' => 0]);
        exit;
    }

    public function cancel($p = null)
    {
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

        $uid = (int)$this->session->user_id;
        if (!$this->Authorization->has_authority($uid, AUTH_EVENT, $event_id, AUTH_CREATE)) {
            echo json_encode(['status' => 3, 'error' => 'Not authorized.']);
            exit;
        }

        $this->load_model('EventPlanning');
        $r = $this->EventPlanning->delete_event($this->session->token, $event_id);

        if (isset($r['Status']) && $r['Status'] == 0) {
            echo json_encode(['status' => 0]);
        } else {
            echo json_encode(['status' => $r['Status'] ?? 1, 'error' => $r['Detail'] ?? 'Could not cancel event.']);
        }
        exit;
    }

    public function auth($p = null)
    {
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

        $uid = (int)$this->session->user_id;

        if ($action === 'playersearch') {
            if (!$this->Authorization->has_authority($uid, AUTH_EVENT, $event_id, AUTH_CREATE)) {
                echo json_encode([]);
                exit;
            }
            $q = trim($_GET['q'] ?? '');
            if (strlen($q) < 2) {
                echo json_encode([]);
                exit;
            }
            $this->load_model('Search');
            $results = $this->Search->scoped_player_search([
                'Query'   => $q,
                'Scope'   => 'event_prioritized',
                'EventId' => $event_id,
                'Limit'   => 15,
                'Format'  => 'event',
            ]);
            echo json_encode($results);

        } elseif ($action === 'addauth') {
            if (!$this->Authorization->has_authority($uid, AUTH_EVENT, $event_id, AUTH_CREATE)) {
                echo json_encode(['status' => 5, 'error' => 'Not authorized.']);
                exit;
            }
            $mid  = (int)($_POST['MundaneId'] ?? 0);
            $role = in_array($_POST['Role'] ?? '', ['create', 'edit']) ? $_POST['Role'] : 'create';
            if (!$mid) {
                echo json_encode(['status' => 1, 'error' => 'Invalid player.']);
                exit;
            }
            $this->load_model('Authorization');
            $r = $this->Authorization->add_auth([
                'Token'     => $this->session->token,
                'MundaneId' => $mid,
                'Type'      => AUTH_EVENT,
                'Id'        => $event_id,
                'Role'      => $role,
            ]);
            if ($r['Status'] != 0) {
                echo json_encode(['status' => $r['Status'], 'error' => ($r['Error'] ?? 'Error') . (isset($r['Detail']) && $r['Detail'] !== '' ? ': ' . $r['Detail'] : '')]);
                exit;
            }
            $authId = (int)($r['Detail'] ?? 0);
            $this->load_model('Player');
            $persona = $this->Player->get_persona($mid);
            $this->Authorization->audit('Authorization::AddAuthorization', ['MundaneId' => $mid, 'Type' => AUTH_EVENT, 'Id' => $event_id, 'Role' => $role], 'Player', $mid, null, [
                'authorization_id' => $authId,
                'mundane_id'       => $mid,
                'park_id'          => 0,
                'kingdom_id'       => 0,
                'event_id'         => (int)$event_id,
                'unit_id'          => 0,
                'role'             => $role,
            ]);
            echo json_encode(['status' => 0, 'authId' => $authId, 'persona' => $persona]);

        } elseif ($action === 'removeauth') {
            if (!$this->Authorization->has_authority($uid, AUTH_EVENT, $event_id, AUTH_CREATE)) {
                echo json_encode(['status' => 5, 'error' => 'Not authorized.']);
                exit;
            }
            $this->load_model('Authorization');
            $r = $this->Authorization->del_auth([
                'Token'           => $this->session->token,
                'AuthorizationId' => (int)($_POST['AuthorizationId'] ?? 0),
            ]);
            echo ($r['Status'] == 0)
                ? json_encode(['status' => 0])
                : json_encode(['status' => $r['Status'], 'error' => rtrim(($r['Error'] ?? 'Error') . ': ' . ($r['Detail'] ?? ''), ': ')]);

        } else {
            echo json_encode(['status' => 1, 'error' => 'Unknown action']);
        }
        exit;
    }

    // --- Event staff and schedule management methods ---

    public function add_staff($p = null)
    {
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

        $mundane_id    = (int)($_POST['MundaneId']    ?? 0);
        $role_name     = trim($_POST['RoleName']      ?? '');
        $can_manage    = (int)(bool)($_POST['CanManage']    ?? 0);
        $can_attendance = (int)(bool)($_POST['CanAttendance'] ?? 0);
        $can_schedule   = (int)(bool)($_POST['CanSchedule']   ?? 0);
        $can_feast      = (int)(bool)($_POST['CanFeast']      ?? 0);
        $staff_id_in  = (int)($_POST['StaffId'] ?? 0);

        if (!valid_id($mundane_id)) {
            echo json_encode(['status' => 1, 'error' => 'A player must be selected.']);
            exit;
        }
        if (!$role_name) {
            echo json_encode(['status' => 1, 'error' => 'A role is required.']);
            exit;
        }

        $this->load_model('EventPlanning');
        $r = $this->EventPlanning->add_staff([
            'Token' => $this->session->token,
            'EventId' => $event_id,
            'EventCalendarDetailId' => $detail_id,
            'StaffId' => $staff_id_in,
            'MundaneId' => $mundane_id,
            'RoleName' => $role_name,
            'CanManage' => $can_manage,
            'CanAttendance' => $can_attendance,
            'CanSchedule' => $can_schedule,
            'CanFeast' => $can_feast,
        ]);

        $statusCode = is_array($r['Status'] ?? null) ? (int)($r['Status']['Status'] ?? 1) : (int)($r['Status'] ?? 1);
        if ($statusCode !== 0) {
            $this->EventPlanning->emit_json($r);
        }

        $priorState = $r['PriorState'] ?? null;
        $staff = $r['Staff'] ?? [];
        $this->Authorization->audit(
            $priorState ? 'EventStaff::Update' : 'EventStaff::Add',
            [
                'EventId'       => $event_id,
                'DetailId'      => $detail_id,
                'MundaneId'     => $mundane_id,
                'RoleName'      => $role_name,
                'CanManage'     => $can_manage,
                'CanAttendance' => $can_attendance,
                'CanSchedule'   => $can_schedule,
                'CanFeast'      => $can_feast,
            ],
            'Event',
            $event_id,
            $priorState,
            [
                'event_staff_id' => (int)($staff['EventStaffId'] ?? 0),
                'role_name'      => $role_name,
                'can_manage'     => $can_manage,
                'can_attendance' => $can_attendance,
                'can_schedule'   => $can_schedule,
                'can_feast'      => $can_feast,
            ]
        );
        echo json_encode(['status' => 0, 'staff' => $staff]);
        exit;
    }

    public function remove_staff($p = null)
    {
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

        $this->load_model('EventPlanning');
        $r = $this->EventPlanning->remove_staff([
            'Token' => $this->session->token,
            'EventId' => $event_id,
            'EventCalendarDetailId' => $detail_id,
            'StaffId' => $staff_id,
        ]);

        $statusCode = is_array($r['Status'] ?? null) ? (int)($r['Status']['Status'] ?? 1) : (int)($r['Status'] ?? 1);
        if ($statusCode !== 0) {
            $this->EventPlanning->emit_json($r);
        }

        $priorState = $r['PriorState'] ?? null;
        if ($priorState) {
            $this->Authorization->audit(
                'EventStaff::Remove',
                ['EventId' => $event_id, 'DetailId' => $detail_id, 'StaffId' => $staff_id],
                'Event',
                $event_id,
                $priorState,
                null
            );
        }
        echo json_encode(['status' => 0]);
        exit;
    }

    private function _decodeScheduleLeads(): array
    {
        $leadsJson = trim($_POST['Leads'] ?? '');
        $leadsIn = ($leadsJson !== '') ? json_decode($leadsJson, true) : [];

        return is_array($leadsIn) ? $leadsIn : [];
    }

    private function _scheduleRequestFromPost(int $eventId, int $detailId, int $scheduleId = 0): array
    {
        return [
            'Token' => $this->session->token,
            'EventId' => $eventId,
            'EventCalendarDetailId' => $detailId,
            'ScheduleId' => $scheduleId,
            'Title' => trim($_POST['Title'] ?? ''),
            'StartTime' => trim($_POST['StartTime'] ?? ''),
            'EndTime' => trim($_POST['EndTime'] ?? ''),
            'Location' => trim($_POST['Location'] ?? ''),
            'SiteLocationId' => (int)($_POST['SiteLocationId'] ?? 0),
            'Description' => trim($_POST['Description'] ?? ''),
            'Category' => trim($_POST['Category'] ?? 'Other'),
            'SecondaryCategory' => trim($_POST['SecondaryCategory'] ?? ''),
            'Menu' => trim($_POST['Menu'] ?? ''),
            'Cost' => trim($_POST['Cost'] ?? ''),
            'Dietary' => trim($_POST['Dietary'] ?? ''),
            'Allergens' => trim($_POST['Allergens'] ?? ''),
            'Leads' => $this->_decodeScheduleLeads(),
        ];
    }

    public function add_schedule($p = null)
    {
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

        $this->load_model('EventPlanning');
        $r = $this->EventPlanning->add_schedule($this->_scheduleRequestFromPost($event_id, $detail_id));
        $statusCode = is_array($r['Status'] ?? null) ? (int)($r['Status']['Status'] ?? 1) : (int)($r['Status'] ?? 1);
        if ($statusCode !== 0) {
            $this->EventPlanning->emit_json($r);
        }
        echo json_encode(['status' => 0, 'schedule' => $r['Schedule'] ?? []]);
        exit;
    }

    public function remove_schedule($p = null)
    {
        header('Content-Type: application/json');
        if (!isset($this->session->user_id)) {
            echo json_encode(['status' => 5, 'error' => 'Not logged in']);
            exit;
        }

        $params      = explode('/', $p ?? '');
        $event_id    = (int)preg_replace('/[^0-9]/', '', $params[0] ?? '');
        $detail_id   = (int)preg_replace('/[^0-9]/', '', $params[1] ?? '');
        $schedule_id = (int)($_POST['ScheduleId'] ?? 0);

        if (!valid_id($event_id) || !valid_id($detail_id) || !valid_id($schedule_id)) {
            echo json_encode(['status' => 1, 'error' => 'Invalid parameters.']);
            exit;
        }

        $this->load_model('EventPlanning');
        $r = $this->EventPlanning->remove_schedule($this->session->token, $event_id, $detail_id, $schedule_id);
        $statusCode = is_array($r['Status'] ?? null) ? (int)($r['Status']['Status'] ?? 1) : (int)($r['Status'] ?? 1);
        if ($statusCode !== 0) {
            $this->EventPlanning->emit_json($r);
        }
        echo json_encode(['status' => 0]);
        exit;
    }

    public function update_schedule($p = null)
    {
        header('Content-Type: application/json');
        if (!isset($this->session->user_id)) {
            echo json_encode(['status' => 5, 'error' => 'Not logged in']);
            exit;
        }

        $params      = explode('/', $p ?? '');
        $event_id    = (int)preg_replace('/[^0-9]/', '', $params[0] ?? '');
        $detail_id   = (int)preg_replace('/[^0-9]/', '', $params[1] ?? '');
        $schedule_id = (int)($_POST['ScheduleId'] ?? 0);

        if (!valid_id($event_id) || !valid_id($detail_id) || !valid_id($schedule_id)) {
            echo json_encode(['status' => 1, 'error' => 'Invalid parameters.']);
            exit;
        }

        $this->load_model('EventPlanning');
        $r = $this->EventPlanning->update_schedule($this->_scheduleRequestFromPost($event_id, $detail_id, $schedule_id));
        $statusCode = is_array($r['Status'] ?? null) ? (int)($r['Status']['Status'] ?? 1) : (int)($r['Status'] ?? 1);
        if ($statusCode !== 0) {
            $this->EventPlanning->emit_json($r);
        }
        echo json_encode(['status' => 0, 'schedule' => $r['Schedule'] ?? []]);
        exit;
    }



    public function heraldry($p = null)
    {
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
        $this->load_model('EventPlanning');
        if (!$this->EventPlanning->can_manage_event_detail($hUid, $event_id, 0, 'manage')) {
            echo json_encode(['status' => 3, 'error' => 'Not authorized.']);
            exit;
        }

        if ($action === 'remove') {
            $r = $this->EventPlanning->remove_heraldry($this->session->token, $event_id);
            if (($r['Status'] ?? 1) == 0) {
                echo json_encode(['status' => 0]);
            } else {
                $this->EventPlanning->emit_json($r);
            }
            exit;
        }

        if ($action === 'update') {
            if (empty($_FILES['Heraldry']['tmp_name'])) {
                echo json_encode(['status' => 1, 'error' => 'No file uploaded.']);
                exit;
            }
            // A7: validate the upload came via a real HTTP file upload (prevents spoofing).
            if (!is_uploaded_file($_FILES['Heraldry']['tmp_name'])) {
                echo json_encode(['status' => 1, 'error' => 'Invalid upload.']);
                exit;
            }
            // A7: server-side file size check (max 1 MB).
            if (($_FILES['Heraldry']['size'] ?? 0) > 1024 * 1024) {
                echo json_encode(['status' => 1, 'error' => 'File too large (max 1 MB).']);
                exit;
            }
            $tmp  = $_FILES['Heraldry']['tmp_name'];
            // A7: use exif_imagetype() (magic-byte check) instead of the
            // browser-supplied MIME type, which is trivially spoofable. Only
            // JPEG and PNG are supported downstream.
            $detectedType = exif_imagetype($tmp);
            if ($detectedType !== IMAGETYPE_JPEG && $detectedType !== IMAGETYPE_PNG) {
                echo json_encode(['status' => 1, 'error' => 'Only JPEG and PNG images are supported.']);
                exit;
            }
            $mime = ($detectedType === IMAGETYPE_PNG) ? 'image/png' : 'image/jpeg';
            $r = $this->EventPlanning->set_event_heraldry([
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

    public function copy_source_list($p = null)
    {
        header('Content-Type: application/json');
        if (!isset($this->session->user_id)) {
            echo json_encode(['status' => 5, 'error' => 'Not logged in']);
            exit;
        }

        $kingdom_id = (int)($_GET['KingdomId'] ?? 0);
        $park_id    = (int)($_GET['ParkId']    ?? 0);
        $query      = trim((string)($_GET['Query'] ?? ''));
        $exclude    = (int)($_GET['ExcludeEventId'] ?? 0);

        if (!valid_id($kingdom_id) && !valid_id($park_id)) {
            echo json_encode(['status' => 1, 'error' => 'A kingdom or park is required.']);
            exit;
        }

        $this->load_model('EventPlanning');
        $r = $this->EventPlanning->copy_source_list($kingdom_id, $park_id, $query, $exclude);
        $statusCode = is_array($r['Status'] ?? null) ? (int)($r['Status']['Status'] ?? 1) : (int)($r['Status'] ?? 1);
        if ($statusCode !== 0) {
            $this->EventPlanning->emit_json($r);
        }
        echo json_encode(['status' => 0, 'results' => $r['Results'] ?? []]);
        exit;
    }


    public function create_with_copy($p = null)
    {
        header('Content-Type: application/json');
        if (!isset($this->session->user_id)) {
            echo json_encode(['status' => 5, 'error' => 'Not logged in']);
            exit;
        }

        $name        = trim($_POST['Name']          ?? '');
        $kingdom_id  = (int)($_POST['KingdomId']    ?? 0);
        $park_id     = (int)($_POST['ParkId']       ?? 0);
        $src_evt_id  = (int)($_POST['SourceEventId'] ?? 0);
        $new_start   = trim($_POST['NewStart']      ?? '');
        $new_end     = trim($_POST['NewEnd']        ?? '');
        $modules_raw = trim($_POST['Modules']       ?? '{}');
        $status_in   = (string)($_POST['Status']    ?? 'published');

        $modules = json_decode($modules_raw, true);
        if (!is_array($modules)) {
            $modules = [];
        }

        if (!strlen($name)) {
            echo json_encode(['status' => 1, 'error' => 'Event name is required.']);
            exit;
        }
        if (!valid_id($kingdom_id) && !valid_id($park_id)) {
            echo json_encode(['status' => 1, 'error' => 'A kingdom or park is required.']);
            exit;
        }
        if (!valid_id($src_evt_id)) {
            echo json_encode(['status' => 1, 'error' => 'A source event is required.']);
            exit;
        }
        if (!strtotime($new_start) || !strtotime($new_end)) {
            echo json_encode(['status' => 1, 'error' => 'Valid start and end times are required.']);
            exit;
        }
        if (strtotime($new_end) < strtotime($new_start)) {
            echo json_encode(['status' => 1, 'error' => 'End time cannot be before start time.']);
            exit;
        }

        $this->load_model('EventPlanning');
        $r = $this->EventPlanning->create_with_copy([
            'Token' => $this->session->token,
            'Name' => $name,
            'KingdomId' => $kingdom_id,
            'ParkId' => $park_id,
            'SourceEventId' => $src_evt_id,
            'NewStart' => $new_start,
            'NewEnd' => $new_end,
            'Modules' => $modules,
            'Status' => $status_in,
        ]);

        $statusCode = is_array($r['Status'] ?? null) ? (int)($r['Status']['Status'] ?? 1) : (int)($r['Status'] ?? 1);
        if ($statusCode !== 0) {
            $detail = is_array($r['Status'] ?? null) ? (string)($r['Status']['Detail'] ?? '') : (string)($r['Detail'] ?? '');
            $error = $detail !== '' ? $detail : (string)($r['Error'] ?? 'Error');
            $jsonStatus = ($statusCode === ServiceErrorIds::NoAuthorization) ? 3 : (int)$statusCode;
            echo json_encode(['status' => $jsonStatus, 'error' => $error]);
            exit;
        }

        $newEventId = (int)($r['EventId'] ?? 0);
        $newDetailId = (int)($r['DetailId'] ?? 0);
        echo json_encode([
            'status'   => 0,
            'eventId'  => $newEventId,
            'detailId' => $newDetailId,
            'url'      => UIR . 'Event/detail/' . $newEventId . '/' . $newDetailId,
            'warnings' => $r['Warnings'] ?? [],
        ]);
        exit;
    }

    public function banner($p = null)
    {
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

        $this->load_model('Banner');
        $this->Banner->handle_ajax(
            'Event',
            $action,
            $event_id,
            $this->session->token,
            $_POST,
            $_FILES,
            3,
        );
    }

    private function _escSql(string $v): string
    {
        return str_replace(["'", '\\'], ["''", '\\\\'], $v);
    }

    private function _detailBelongsToEvent(int $event_id, int $detail_id): bool
    {
        global $DB;
        $DB->Clear();
        $row = $DB->DataSet('SELECT 1 FROM ' . DB_PREFIX . 'event_calendardetail WHERE event_calendardetail_id = ' . $detail_id . ' AND event_id = ' . $event_id . ' LIMIT 1');
        return $row && $row->Next();
    }

    // Site Details editing gate: full event managers only (AUTH_EDIT or a
    // staff row with can_manage). Also preflights that the detail belongs to
    // the event — site-map files are keyed by detail_id alone, so an id
    // mismatch here would let an editor of event A write files for event B.
    private function _canManageSite(int $event_id, int $detail_id): bool
    {
        if (!$this->_detailBelongsToEvent($event_id, $detail_id)) {
            return false;
        }
        $uid = (int)$this->session->user_id;
        if (Ork3::$Lib->authorization->HasAuthority($uid, AUTH_EVENT, $event_id, AUTH_EDIT)) {
            return true;
        }
        global $DB;
        $DB->Clear();
        $staffRow = $DB->DataSet('SELECT 1 FROM ' . DB_PREFIX . 'event_staff WHERE event_calendardetail_id = ' . $detail_id . ' AND mundane_id = ' . $uid . ' AND can_manage = 1 LIMIT 1');
        return $staffRow && $staffRow->Next();
    }

    private function _loadSiteRules(int $detail_id): array
    {
        global $DB;
        $DB->Clear();
        $rows = $DB->DataSet(
            'SELECT event_site_rule_id AS RuleId, rule_key AS RuleKey, value AS Value, title AS Title, details AS Details, sort_order AS SortOrder
			FROM ' . DB_PREFIX . 'event_site_rule
			WHERE event_calendardetail_id = ' . $detail_id . '
			ORDER BY sort_order, event_site_rule_id'
        );
        $out = [];
        if ($rows) {
            while ($rows->Next()) {
                $out[] = [
                    'RuleId'    => (int)$rows->RuleId,
                    'RuleKey'   => $rows->RuleKey !== null ? (string)$rows->RuleKey : null,
                    'Value'     => (string)($rows->Value ?? ''),
                    'Title'     => (string)($rows->Title ?? ''),
                    'Details'   => (string)($rows->Details ?? ''),
                    'SortOrder' => (int)$rows->SortOrder,
                ];
            }
        }
        return $out;
    }

    public function site_rules_save($p = null)
    {
        header('Content-Type: application/json');
        if (!isset($this->session->user_id)) {
            echo json_encode(['status' => 5, 'error' => 'Not logged in']);
            exit;
        }
        // CSRF mitigation: cross-site form POSTs cannot set a custom header,
        // and cross-origin XHR is preflight-blocked. No token system exists in
        // this codebase, so enforce the header the client already sends.
        if (($_SERVER['HTTP_X_REQUESTED_WITH'] ?? '') !== 'XMLHttpRequest') {
            echo json_encode(['status' => 4, 'error' => 'Bad request.']);
            exit;
        }

        $params    = explode('/', $p ?? '');
        $event_id  = (int)preg_replace('/[^0-9]/', '', $params[0] ?? '');
        $detail_id = (int)preg_replace('/[^0-9]/', '', $params[1] ?? '');
        if (!valid_id($event_id) || !valid_id($detail_id)) {
            echo json_encode(['status' => 1, 'error' => 'Invalid Event ID.']);
            exit;
        }
        if (!$this->_canManageSite($event_id, $detail_id)) {
            echo json_encode(['status' => 3, 'error' => 'Not authorized.']);
            exit;
        }

        require_once(DIR_LIB . 'ork3/eventsite-catalog.php');
        $catalog = event_site_rule_catalog();

        $rulesJson = trim($_POST['Rules'] ?? '');
        $rulesIn   = ($rulesJson !== '') ? json_decode($rulesJson, true) : [];
        if (!is_array($rulesIn)) {
            echo json_encode(['status' => 1, 'error' => 'Invalid rules payload.']);
            exit;
        }

        // Validate the full payload BEFORE any write (no transactions on
        // this branch — the failure window between DELETE and INSERT must
        // only ever contain pre-validated data).
        $pillRows   = [];
        $customRows = [];
        foreach ($rulesIn as $r) {
            if (!is_array($r)) {
                continue;
            }
            $key     = trim((string)($r['RuleKey'] ?? ''));
            $value   = trim((string)($r['Value']   ?? ''));
            $title   = trim((string)($r['Title']   ?? ''));
            // M-7: cap Details length — TEXT columns can hold far more than a
            // rule blurb ever should, and this endpoint is the only writer.
            $details = mb_substr(trim((string)($r['Details'] ?? '')), 0, 2000);
            if ($key !== '') {
                if (!isset($catalog[$key]['values'][$value])) {
                    echo json_encode(['status' => 1, 'error' => 'Unknown rule option.']);
                    exit;
                }
                $pillRows[$key] = ['value' => $value, 'details' => $details];
            } elseif ($title !== '') {
                // M-7: bound the number of custom rules a single save can create.
                // Reject silently past the cap rather than erroring — mirrors the
                // "just don't accept it" posture used for out-of-range inputs
                // elsewhere on this endpoint.
                if (count($customRows) >= 100) {
                    continue;
                }
                $customRows[] = ['title' => mb_substr($title, 0, 120), 'details' => $details];
            }
        }

        global $DB;

        // CONTRACT A (optimistic concurrency): the client posts the RuleId set
        // it rendered from. If the current set differs (rules added/removed by
        // another manager since the page loaded), reject and write nothing.
        $baselineRaw = trim((string)($_POST['BaselineRuleIds'] ?? ''));
        $baseline    = [];
        if ($baselineRaw !== '') {
            foreach (explode(',', $baselineRaw) as $bid) {
                $bid = (int)trim($bid);
                if ($bid > 0) {
                    $baseline[$bid] = true;
                }
            }
        }
        $current = [];
        foreach ($this->_loadSiteRules($detail_id) as $existing) {
            $current[(int)$existing['RuleId']] = true;
        }
        ksort($baseline);
        ksort($current);
        if (array_keys($baseline) !== array_keys($current)) {
            echo json_encode(['status' => 9, 'error' => 'These site rules were changed by someone else — reload the page and try again.']);
            exit;
        }

        $values = [];
        foreach ($pillRows as $key => $r) {
            $values[] = '(' . $detail_id . ", '" . $this->_escSql($key) . "', '" . $this->_escSql($r['value']) . "', '', '" . $this->_escSql($r['details']) . "', 0)";
        }
        $sort = 0;
        foreach ($customRows as $r) {
            $values[] = '(' . $detail_id . ", NULL, '', '" . $this->_escSql($r['title']) . "', '" . $this->_escSql($r['details']) . "', " . $sort++ . ')';
        }

        // Wrap the DELETE + INSERT in a transaction and drive COMMIT/ROLLBACK off
        // a row-count check taken INSIDE the transaction. YapoMysql::Execute() has
        // no return value and PDO runs in warning mode, so an Execute failure can't
        // be detected from a return code — the post-INSERT COUNT(*) is the only
        // reliable signal the rewrite fully landed. A mismatch ROLLs BACK, undoing
        // the DELETE, so a failed INSERT can never leave the rule set empty.
        $expected = count($pillRows) + count($customRows);
        $DB->Clear();
        $DB->Execute('START TRANSACTION');
        $DB->Clear();
        $DB->Execute('DELETE FROM ' . DB_PREFIX . 'event_site_rule WHERE event_calendardetail_id = ' . $detail_id);
        if (!empty($values)) {
            $DB->Clear();
            $DB->Execute(
                'INSERT INTO ' . DB_PREFIX . 'event_site_rule
				(event_calendardetail_id, rule_key, value, title, details, sort_order)
				VALUES ' . implode(', ', $values)
            );
        }
        // COUNT within the still-open transaction — it sees the uncommitted
        // rewrite. Committing only on an exact match makes a partial write
        // self-healing: ROLLBACK restores the pre-DELETE rows.
        $DB->Clear();
        $cntRow = $DB->DataSet('SELECT COUNT(*) AS cnt FROM ' . DB_PREFIX . 'event_site_rule WHERE event_calendardetail_id = ' . $detail_id);
        $actual = ($cntRow && $cntRow->Next()) ? (int)$cntRow->cnt : -1;
        $ok     = ($actual === $expected);
        $DB->Clear();
        $DB->Execute($ok ? 'COMMIT' : 'ROLLBACK');

        if (!$ok) {
            echo json_encode(['status' => 2, 'error' => 'Failed to save site rules — please retry.']);
            exit;
        }

        echo json_encode(['status' => 0, 'rules' => $this->_loadSiteRules($detail_id)]);
        exit;
    }

    public function site_map_upload($p = null)
    {
        header('Content-Type: application/json');
        if (!isset($this->session->user_id)) {
            echo json_encode(['status' => 5, 'error' => 'Not logged in']);
            exit;
        }
        // CSRF mitigation: cross-site form POSTs cannot set a custom header,
        // and cross-origin XHR is preflight-blocked. No token system exists in
        // this codebase, so enforce the header the client already sends.
        if (($_SERVER['HTTP_X_REQUESTED_WITH'] ?? '') !== 'XMLHttpRequest') {
            echo json_encode(['status' => 4, 'error' => 'Bad request.']);
            exit;
        }

        $params    = explode('/', $p ?? '');
        $event_id  = (int)preg_replace('/[^0-9]/', '', $params[0] ?? '');
        $detail_id = (int)preg_replace('/[^0-9]/', '', $params[1] ?? '');
        if (!valid_id($event_id) || !valid_id($detail_id)) {
            echo json_encode(['status' => 1, 'error' => 'Invalid Event ID.']);
            exit;
        }
        if (!$this->_canManageSite($event_id, $detail_id)) {
            echo json_encode(['status' => 3, 'error' => 'Not authorized.']);
            exit;
        }

        if (empty($_FILES['SiteMap']['tmp_name'])) {
            echo json_encode(['status' => 1, 'error' => 'No file uploaded.']);
            exit;
        }
        // Real HTTP upload only (prevents path spoofing).
        if (!is_uploaded_file($_FILES['SiteMap']['tmp_name'])) {
            echo json_encode(['status' => 1, 'error' => 'Invalid upload.']);
            exit;
        }
        // Server-side size gate — the client precheck is bypassable via curl.
        if (($_FILES['SiteMap']['size'] ?? 0) > 2 * 1024 * 1024) {
            echo json_encode(['status' => 1, 'error' => 'File too large (max 2 MB).']);
            exit;
        }
        $tmp = $_FILES['SiteMap']['tmp_name'];
        // Magic-byte check, not the browser-supplied MIME (trivially spoofed).
        $detectedType = exif_imagetype($tmp);
        if ($detectedType !== IMAGETYPE_JPEG && $detectedType !== IMAGETYPE_PNG) {
            echo json_encode(['status' => 1, 'error' => 'Only JPEG and PNG images are supported.']);
            exit;
        }
        // Dimensions from headers only — no GD decode, so no decompression
        // bomb. SMALLINT storage + Leaflet sanity both cap at 16000/edge.
        $dims = @getimagesize($tmp);
        if (!$dims || (int)$dims[0] < 1 || (int)$dims[1] < 1) {
            echo json_encode(['status' => 1, 'error' => 'Could not read image dimensions.']);
            exit;
        }
        if ((int)$dims[0] > 16000 || (int)$dims[1] > 16000 || (int)$dims[0] * (int)$dims[1] > 40000000) {
            echo json_encode(['status' => 1, 'error' => 'Image dimensions too large.']);
            exit;
        }

        $ext  = ($detectedType === IMAGETYPE_PNG) ? 'png' : 'jpg';
        if (!is_dir(DIR_SITEMAP)) {
            @mkdir(DIR_SITEMAP, 0775, true);
        }
        $base = DIR_SITEMAP . sprintf('%05d', $detail_id);
        // Land the new file under a temp name first so a failed move can
        // never destroy the existing map. The temp name is per-request-unique
        // (uniqid) so two concurrent same-ext uploads can't collide on it;
        // this same $newPath is the one moved, renamed, and cleaned up below.
        $newPath = $base . '.' . uniqid('', true) . '.new.' . $ext;
        if (!@move_uploaded_file($tmp, $newPath)) {
            echo json_encode(['status' => 1, 'error' => 'Could not save uploaded file.']);
            exit;
        }
        // POSIX rename() atomically replaces a same-ext old file, so the old
        // map stays fully intact right up until the new one lands — no
        // pre-unlink, no window where zero map files exist on disk.
        if (!@rename($newPath, $base . '.' . $ext)) {
            @unlink($newPath);
            echo json_encode(['status' => 1, 'error' => 'Could not save uploaded file.']);
            exit;
        }
        // Only now, with the new file safely in place, remove a stale
        // opposite-extension old map (e.g. replacing a .jpg with a .png).
        $oldExt = ($ext === 'jpg') ? 'png' : 'jpg';
        if (file_exists($base . '.' . $oldExt)) {
            @unlink($base . '.' . $oldExt);
        }

        global $DB;
        $DB->Clear();
        $DB->Execute(
            'INSERT INTO ' . DB_PREFIX . 'event_site_map (event_calendardetail_id, ext, width, height, uploaded_by)
			VALUES (' . $detail_id . ", '" . $ext . "', " . (int)$dims[0] . ', ' . (int)$dims[1] . ', ' . (int)$this->session->user_id . ")
			ON DUPLICATE KEY UPDATE ext = VALUES(ext), width = VALUES(width), height = VALUES(height), uploaded_by = VALUES(uploaded_by)"
        );
        // Execute() is void and the Yapo layer can silently swallow failures
        // (sql_mode etc.) — verify the row landed before reporting success.
        $DB->Clear();
        $verify = $DB->DataSet('SELECT ext, width FROM ' . DB_PREFIX . 'event_site_map WHERE event_calendardetail_id = ' . $detail_id . ' LIMIT 1');
        if (!$verify || !$verify->Next() || (string)$verify->ext !== $ext || (int)$verify->width !== (int)$dims[0]) {
            // Do NOT unlink the new file here: the read side (Controller_Event)
            // checks file_exists and degrades to "no map" if the DB row is
            // missing/stale, so an inconsistent row here is self-healing
            // rather than user-breaking (losing the just-uploaded image).
            echo json_encode(['status' => 1, 'error' => 'Saved file but could not update the database. Please try again.']);
            exit;
        }

        echo json_encode(['status' => 0, 'map' => [
            'Url'    => HTTP_SITEMAP . sprintf('%05d', $detail_id) . '.' . $ext . '?v=' . filemtime($base . '.' . $ext),
            'Width'  => (int)$dims[0],
            'Height' => (int)$dims[1],
        ]]);
        exit;
    }

    public function site_map_delete($p = null)
    {
        header('Content-Type: application/json');
        if (!isset($this->session->user_id)) {
            echo json_encode(['status' => 5, 'error' => 'Not logged in']);
            exit;
        }
        // CSRF mitigation: cross-site form POSTs cannot set a custom header,
        // and cross-origin XHR is preflight-blocked. No token system exists in
        // this codebase, so enforce the header the client already sends.
        if (($_SERVER['HTTP_X_REQUESTED_WITH'] ?? '') !== 'XMLHttpRequest') {
            echo json_encode(['status' => 4, 'error' => 'Bad request.']);
            exit;
        }

        $params    = explode('/', $p ?? '');
        $event_id  = (int)preg_replace('/[^0-9]/', '', $params[0] ?? '');
        $detail_id = (int)preg_replace('/[^0-9]/', '', $params[1] ?? '');
        if (!valid_id($event_id) || !valid_id($detail_id)) {
            echo json_encode(['status' => 1, 'error' => 'Invalid Event ID.']);
            exit;
        }
        if (!$this->_canManageSite($event_id, $detail_id)) {
            echo json_encode(['status' => 3, 'error' => 'Not authorized.']);
            exit;
        }

        global $DB;
        $DB->Clear();
        $DB->Execute('DELETE FROM ' . DB_PREFIX . 'event_site_map WHERE event_calendardetail_id = ' . $detail_id);
        // Execute() is void and the Yapo layer can silently swallow failures
        // — verify the row is actually gone before touching any files.
        $DB->Clear();
        $verify = $DB->DataSet('SELECT 1 FROM ' . DB_PREFIX . 'event_site_map WHERE event_calendardetail_id = ' . $detail_id . ' LIMIT 1');
        if ($verify && $verify->Next()) {
            echo json_encode(['status' => 1, 'error' => 'Could not remove the site map. Please try again.']);
            exit;
        }
        // Pins are intentionally KEPT (fractional coords survive a future
        // re-upload); only the image row + files go.
        $base = DIR_SITEMAP . sprintf('%05d', $detail_id);
        if (file_exists($base . '.jpg')) {
            @unlink($base . '.jpg');
        }
        if (file_exists($base . '.png')) {
            @unlink($base . '.png');
        }
        echo json_encode(['status' => 0]);
        exit;
    }

    public function site_location_save($p = null)
    {
        header('Content-Type: application/json');
        if (!isset($this->session->user_id)) {
            echo json_encode(['status' => 5, 'error' => 'Not logged in']);
            exit;
        }
        // CSRF mitigation: cross-site form POSTs cannot set a custom header,
        // and cross-origin XHR is preflight-blocked. No token system exists in
        // this codebase, so enforce the header the client already sends.
        if (($_SERVER['HTTP_X_REQUESTED_WITH'] ?? '') !== 'XMLHttpRequest') {
            echo json_encode(['status' => 4, 'error' => 'Bad request.']);
            exit;
        }

        $params    = explode('/', $p ?? '');
        $event_id  = (int)preg_replace('/[^0-9]/', '', $params[0] ?? '');
        $detail_id = (int)preg_replace('/[^0-9]/', '', $params[1] ?? '');
        if (!valid_id($event_id) || !valid_id($detail_id)) {
            echo json_encode(['status' => 1, 'error' => 'Invalid Event ID.']);
            exit;
        }
        if (!$this->_canManageSite($event_id, $detail_id)) {
            echo json_encode(['status' => 3, 'error' => 'Not authorized.']);
            exit;
        }

        require_once(DIR_LIB . 'ork3/eventsite-catalog.php');
        $loc_id   = (int)($_POST['LocationId'] ?? 0);
        $name     = mb_substr(trim($_POST['Name'] ?? ''), 0, 80);
        $category = trim($_POST['Category'] ?? 'other');
        // M-7: cap Description length — TEXT column, sole writer is this endpoint.
        $desc     = mb_substr(trim($_POST['Description'] ?? ''), 0, 2000);
        $x        = max(0.0, min(1.0, (float)($_POST['X'] ?? 0)));
        $y        = max(0.0, min(1.0, (float)($_POST['Y'] ?? 0)));
        if (!isset(event_site_location_categories()[$category])) {
            $category = 'other';
        }
        if ($name === '') {
            echo json_encode(['status' => 1, 'error' => 'A name is required.']);
            exit;
        }

        $name_safe = $this->_escSql($name);
        $cat_safe  = $this->_escSql($category);
        $desc_safe = $this->_escSql($desc);
        $x_sql     = sprintf('%.6F', $x);
        $y_sql     = sprintf('%.6F', $y);

        global $DB;
        if ($loc_id > 0) {
            $DB->Clear();
            $own = $DB->DataSet('SELECT 1 FROM ' . DB_PREFIX . 'event_site_location WHERE event_site_location_id = ' . $loc_id . ' AND event_calendardetail_id = ' . $detail_id . ' LIMIT 1');
            if (!($own && $own->Next())) {
                echo json_encode(['status' => 1, 'error' => 'Unknown location.']);
                exit;
            }
            $DB->Clear();
            $DB->Execute('UPDATE ' . DB_PREFIX . "event_site_location SET name = '" . $name_safe . "', category = '" . $cat_safe . "', description = '" . $desc_safe . "', x = " . $x_sql . ', y = ' . $y_sql . ' WHERE event_site_location_id = ' . $loc_id);
            // Re-sync the denormalized schedule location text on rename, but
            // ONLY for auto-filled copies (location = '') — mirrors the guarded
            // backfill in site_location_delete so a manager's custom schedule
            // text is never clobbered.
            $DB->Clear();
            $DB->Execute('UPDATE ' . DB_PREFIX . "event_schedule SET location = '" . $name_safe . "' WHERE site_location_id = " . $loc_id . " AND location = ''");
        } else {
            $DB->Clear();
            $DB->Execute('INSERT INTO ' . DB_PREFIX . "event_site_location (event_calendardetail_id, name, category, description, x, y) VALUES (" . $detail_id . ", '" . $name_safe . "', '" . $cat_safe . "', '" . $desc_safe . "', " . $x_sql . ', ' . $y_sql . ')');
            // lastInsertId is unreliable here (see project memory) — read back.
            $DB->Clear();
            $idrow = $DB->DataSet('SELECT event_site_location_id FROM ' . DB_PREFIX . 'event_site_location WHERE event_calendardetail_id = ' . $detail_id . ' ORDER BY event_site_location_id DESC LIMIT 1');
            $loc_id = ($idrow && $idrow->Next()) ? (int)$idrow->event_site_location_id : 0;
            if ($loc_id === 0) {
                echo json_encode(['status' => 1, 'error' => 'Could not save the location. Please try again.']);
                exit;
            }
        }

        echo json_encode(['status' => 0, 'location' => [
            'LocationId'  => $loc_id,
            'Name'        => $name,
            'Category'    => $category,
            'Description' => $desc,
            'X'           => $x,
            'Y'           => $y,
        ]]);
        exit;
    }

    public function site_location_delete($p = null)
    {
        header('Content-Type: application/json');
        if (!isset($this->session->user_id)) {
            echo json_encode(['status' => 5, 'error' => 'Not logged in']);
            exit;
        }
        // CSRF mitigation: cross-site form POSTs cannot set a custom header,
        // and cross-origin XHR is preflight-blocked. No token system exists in
        // this codebase, so enforce the header the client already sends.
        if (($_SERVER['HTTP_X_REQUESTED_WITH'] ?? '') !== 'XMLHttpRequest') {
            echo json_encode(['status' => 4, 'error' => 'Bad request.']);
            exit;
        }

        $params    = explode('/', $p ?? '');
        $event_id  = (int)preg_replace('/[^0-9]/', '', $params[0] ?? '');
        $detail_id = (int)preg_replace('/[^0-9]/', '', $params[1] ?? '');
        $loc_id    = (int)($_POST['LocationId'] ?? 0);
        if (!valid_id($event_id) || !valid_id($detail_id) || !valid_id($loc_id)) {
            echo json_encode(['status' => 1, 'error' => 'Invalid parameters.']);
            exit;
        }
        if (!$this->_canManageSite($event_id, $detail_id)) {
            echo json_encode(['status' => 3, 'error' => 'Not authorized.']);
            exit;
        }

        global $DB;
        $DB->Clear();
        $own = $DB->DataSet('SELECT name FROM ' . DB_PREFIX . 'event_site_location WHERE event_site_location_id = ' . $loc_id . ' AND event_calendardetail_id = ' . $detail_id . ' LIMIT 1');
        if (!($own && $own->Next())) {
            echo json_encode(['status' => 1, 'error' => 'Unknown location.']);
            exit;
        }
        $name_safe = $this->_escSql((string)$own->name);

        // Graceful degradation: make sure every linked schedule row keeps a
        // readable location string before the FK nulls the link.
        $DB->Clear();
        $DB->Execute('UPDATE ' . DB_PREFIX . "event_schedule SET location = '" . $name_safe . "' WHERE site_location_id = " . $loc_id . " AND location = ''");
        $DB->Clear();
        $DB->Execute('DELETE FROM ' . DB_PREFIX . 'event_site_location WHERE event_site_location_id = ' . $loc_id);

        echo json_encode(['status' => 0]);
        exit;
    }
}
