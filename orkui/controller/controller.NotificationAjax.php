<?php

/**
 * Controller_NotificationAjax — JSON AJAX surface for in-app notifications.
 *
 * Routes: index.php?Route=NotificationAjax/{action}
 *   list      → GetForMundane(user_id)            (lazy-fetched panel contents)
 *   mark_read → MarkRead(user_id, ids[]|all)      (clears badge for read items)
 *   dismiss   → Dismiss(user_id, id)              (hides one item; row persists)
 *   send      → audience-gated announcement → CreateBulk
 *
 * All read/mutate actions are scoped to $this->session->user_id. `send` is gated
 * by an audience-authority check (global=AUTH_ADMIN, kingdom/park=scoped officer).
 *
 * Registered in $_skipTokenCheck (class.Controller.php) so the stale-session
 * redirect does not fire on these AJAX calls.
 *
 * Response convention: {status:0, ...} success, {status:1, error:"..."} failure.
 * Design: docs/superpowers/specs/2026-06-20-notifications-system-design.md
 */
class Controller_NotificationAjax extends Controller
{
    /** Shared JSON + auth preamble. Returns the int user_id, or null (already responded). */
    private function guard()
    {
        header('Content-Type: application/json');
        if (!isset($this->session->user_id) || (int) $this->session->user_id <= 0) {
            echo json_encode(['status' => 1, 'error' => 'Not logged in']);
            exit;
            return null;
        }
        return (int) $this->session->user_id;
    }

    /**
     * GET/POST NotificationAjax/list
     * → {status:0, items:[{id,type,icon,title,body,link_url,ago,read}]}
     */
    public function list()
    {
        $uid = $this->guard();
        if ($uid === null) {
            return;
        }

        $this->load_model('Notification');
        $res = $this->Notification->get_for_mundane($uid, 15);
        $rows = ($res['Notifications'] ?? []);

        $items = [];
        foreach ($rows as $n) {
            $items[] = [
                'id'       => (int) $n['NotificationId'],
                'type'     => $n['Type'],
                'icon'     => $n['Icon'],
                'title'    => $n['Title'],
                'body'     => $n['Body'],
                'link_url' => $n['LinkUrl'],
                'ago'      => $n['Ago'],
                'read'     => (bool) $n['Read'],
            ];
        }

        echo json_encode(['status' => 0, 'items' => $items]);
        exit;
    }

    /**
     * POST NotificationAjax/mark_read
     *   ids[]=1&ids[]=2   → mark those read
     *   all=1             → mark every unread row read
     * → {status:0}
     */
    public function mark_read()
    {
        $uid = $this->guard();
        if ($uid === null) {
            return;
        }

        $this->load_model('Notification');

        $all = !empty($_POST['all']) || !empty($_GET['all']);
        $ids = null;
        if (!$all) {
            $raw = $_POST['ids'] ?? $_GET['ids'] ?? null;
            if ($raw !== null) {
                if (!is_array($raw)) {
                    // accept a comma-separated string too
                    $raw = explode(',', (string) $raw);
                }
                $ids = [];
                foreach ($raw as $id) {
                    $id = (int) $id;
                    if ($id > 0) {
                        $ids[] = $id;
                    }
                }
            }
            // No ids and not all → nothing to do, but succeed idempotently.
            if ($ids === null || count($ids) === 0) {
                echo json_encode(['status' => 0]);
                exit;
            }
        }

        $this->Notification->mark_read($uid, $all ? null : $ids);
        echo json_encode(['status' => 0]);
        exit;
    }

    /**
     * POST NotificationAjax/dismiss   id=123
     * → {status:0}
     */
    public function dismiss()
    {
        $uid = $this->guard();
        if ($uid === null) {
            return;
        }

        $id = (int) ($_POST['id'] ?? $_GET['id'] ?? 0);
        if ($id <= 0) {
            echo json_encode(['status' => 1, 'error' => 'Missing notification id']);
            exit;
        }

        $this->load_model('Notification');
        $this->Notification->dismiss($uid, $id);
        echo json_encode(['status' => 0]);
        exit;
    }

    /**
     * POST NotificationAjax/send  — announcement composer submit.
     *   title (required), body, link, scope=global|kingdom|park, scope_id
     * Auth-gated by audience:
     *   global          → AUTH_ADMIN
     *   kingdom/park     → HasAuthority(uid, AUTH_KINGDOM|AUTH_PARK, scope_id, AUTH_ADMIN|AUTH_EDIT)
     * → {status:0, count:N} | {status:1, error}
     */
    public function send()
    {
        $uid = $this->guard();
        if ($uid === null) {
            return;
        }

        $title = trim((string) ($_POST['title'] ?? ''));
        $body  = trim((string) ($_POST['body']  ?? ''));
        $link  = trim((string) ($_POST['link']  ?? $_POST['link_url'] ?? ''));
        $scope = strtolower(trim((string) ($_POST['scope'] ?? '')));
        $scopeId = (int) ($_POST['scope_id'] ?? $_POST['scopeId'] ?? 0);

        // Only allow safe link schemes. The bell panel navigates to link_url via
        // window.location, so a javascript:/data: URI would execute in the
        // recipient's session. Permit absolute http(s), root-relative, or the
        // app's own "?Route=" form; otherwise drop the link.
        if ($link !== '' && !preg_match('#^(https?://|/|\?Route=)#i', $link)) {
            $link = '';
        }

        if ($title === '') {
            echo json_encode(['status' => 1, 'error' => 'Title is required']);
            exit;
        }
        if (!in_array($scope, ['global', 'kingdom', 'park'], true)) {
            echo json_encode(['status' => 1, 'error' => 'Invalid audience']);
            exit;
        }

        // ---- Audience authority gate -------------------------------------
        $authorized = false;
        if ($scope === 'global') {
            $authorized = Ork3::$Lib->authorization->HasAuthority($uid, AUTH_ADMIN, 0, AUTH_ADMIN);
        } elseif ($scope === 'kingdom') {
            if ($scopeId <= 0) {
                echo json_encode(['status' => 1, 'error' => 'Missing kingdom id']);
                exit;
            }
            $authorized = Ork3::$Lib->authorization->HasAuthority($uid, AUTH_KINGDOM, $scopeId, AUTH_ADMIN)
                || Ork3::$Lib->authorization->HasAuthority($uid, AUTH_KINGDOM, $scopeId, AUTH_EDIT);
        } elseif ($scope === 'park') {
            if ($scopeId <= 0) {
                echo json_encode(['status' => 1, 'error' => 'Missing park id']);
                exit;
            }
            $authorized = Ork3::$Lib->authorization->HasAuthority($uid, AUTH_PARK, $scopeId, AUTH_ADMIN)
                || Ork3::$Lib->authorization->HasAuthority($uid, AUTH_PARK, $scopeId, AUTH_EDIT);
        }

        if (!$authorized) {
            echo json_encode(['status' => 1, 'error' => 'Not authorized to notify this audience']);
            exit;
        }

        // ---- Resolve recipients + fan-out --------------------------------
        $this->load_model('Notification');
        $recipients = $this->Notification->get_recipients_for_scope($scope, $scopeId);
        if (!is_array($recipients) || count($recipients) === 0) {
            echo json_encode(['status' => 0, 'count' => 0]);
            exit;
        }

        $res = $this->Notification->create_bulk(
            $recipients,
            'announcement',
            [
                'title'      => $title,
                'body'       => ($body !== '' ? $body : null),
                'icon'       => null, // lib defaults announcement → fa-bullhorn
                'link_url'   => ($link !== '' ? $link : null),
                'created_by' => $uid,
            ]
        );

        if (($res['Status'] ?? 1) !== 0) {
            echo json_encode(['status' => 1, 'error' => ($res['Error'] ?? 'Send failed')]);
            exit;
        }

        echo json_encode(['status' => 0, 'count' => (int) ($res['Count'] ?? 0)]);
        exit;
    }
}
