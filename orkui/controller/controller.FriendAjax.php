<?php

/**
 * Controller_FriendAjax — JSON AJAX surface for the friend graph.
 *
 * Routes: index.php?Route=FriendAjax/{action}
 *   request/accept/decline/cancel/unfriend/block/unblock → relationship mutations
 *   status  → relationship state for one target (drives button re-render)
 *   list    → a user's friends (FRIENDS-ONLY visibility gate)
 *   pending → your incoming requests
 *   feed    → friends' activity feed (awards + RSVPs)
 *
 * All actions scoped to $this->session->user_id. Registered in $_skipTokenCheck
 * (class.Controller.php). Response: {status:0,...} | {status:1,error:"..."}.
 * Design: docs/superpowers/specs/2026-06-20-friends-system-design.md
 */
class Controller_FriendAjax extends Controller
{
    /** Shared JSON + auth preamble. Returns int user_id, or null (already responded). */
    private function guard()
    {
        header('Content-Type: application/json');
        if (!isset($this->session->user_id) || (int) $this->session->user_id <= 0) {
            echo json_encode(['status' => 1, 'error' => 'Not logged in']);
            exit;
        }
        return (int) $this->session->user_id;
    }

    /** Read the target/other mundane id from POST/GET. */
    private function targetId()
    {
        return (int) ($_POST['target'] ?? $_GET['target'] ?? $_POST['id'] ?? $_GET['id'] ?? 0);
    }

    /** Map a lib status tuple to the JSON response and exit. */
    private function respond(array $res)
    {
        if ((int) ($res['Status'] ?? 1) !== 0) {
            echo json_encode(['status' => 1, 'error' => ($res['Error'] ?? 'Action failed')]);
            exit;
        }
        echo json_encode(['status' => 0]);
        exit;
    }

    public function request()
    {
        $uid = $this->guard();
        $this->load_model('Friendship');
        $this->respond($this->Friendship->request($uid, $this->targetId()));
    }

    public function accept()
    {
        $uid = $this->guard();
        $this->load_model('Friendship');
        $this->respond($this->Friendship->accept($uid, $this->targetId()));
    }

    public function decline()
    {
        $uid = $this->guard();
        $this->load_model('Friendship');
        $this->respond($this->Friendship->decline($uid, $this->targetId()));
    }

    public function cancel()
    {
        $uid = $this->guard();
        $this->load_model('Friendship');
        $this->respond($this->Friendship->cancel($uid, $this->targetId()));
    }

    public function unfriend()
    {
        $uid = $this->guard();
        $this->load_model('Friendship');
        $this->respond($this->Friendship->unfriend($uid, $this->targetId()));
    }

    public function block()
    {
        $uid = $this->guard();
        $this->load_model('Friendship');
        $this->respond($this->Friendship->block($uid, $this->targetId()));
    }

    public function unblock()
    {
        $uid = $this->guard();
        $this->load_model('Friendship');
        $this->respond($this->Friendship->unblock($uid, $this->targetId()));
    }

    /** GET FriendAjax/status&target=N → {status:0, state, blocked_by_me} */
    public function status()
    {
        $uid = $this->guard();
        $this->load_model('Friendship');
        $res = $this->Friendship->get_status($uid, $this->targetId());
        echo json_encode([
            'status'        => 0,
            'state'         => $res['State'] ?? 'none',
            'blocked_by_me' => (bool) ($res['BlockedByMe'] ?? false),
        ]);
        exit;
    }

    /**
     * GET FriendAjax/list&owner=N → {status:0, friends:[...]}
     * FRIENDS-ONLY gate: only the owner, or a confirmed friend of the owner, may
     * see the list. Everyone else gets an empty, unrevealing response.
     */
    public function list()
    {
        $uid = $this->guard();
        $owner = (int) ($_GET['owner'] ?? $_POST['owner'] ?? $uid);
        if ($owner <= 0) {
            $owner = $uid;
        }
        $this->load_model('Friendship');

        $allowed = ($owner === $uid) || $this->Friendship->are_friends($uid, $owner);
        if (!$allowed) {
            // Hide both list and count from non-friends.
            echo json_encode(['status' => 0, 'friends' => [], 'visible' => false]);
            exit;
        }

        $res = $this->Friendship->get_friends($owner);
        echo json_encode(['status' => 0, 'visible' => true, 'friends' => ($res['Friends'] ?? [])]);
        exit;
    }

    /** GET FriendAjax/pending → {status:0, requests:[...]} (your incoming requests) */
    public function pending()
    {
        $uid = $this->guard();
        $this->load_model('Friendship');
        $res = $this->Friendship->get_pending_incoming($uid);
        echo json_encode(['status' => 0, 'requests' => ($res['Requests'] ?? [])]);
        exit;
    }

    /** GET FriendAjax/feed → {status:0, items:[{type,text,icon,ago,link_url}]} */
    public function feed()
    {
        $uid = $this->guard();
        $this->load_model('Friendship');
        $res = $this->Friendship->get_activity_feed($uid, 30);
        $items = [];
        foreach (($res['Items'] ?? []) as $it) {
            $items[] = [
                'type'     => $it['Type'],
                'text'     => $it['Text'],
                'icon'     => $it['Icon'],
                'ago'      => $it['Ago'] ?? '',
                'link_url' => $it['LinkUrl'] ?? '',
            ];
        }
        echo json_encode(['status' => 0, 'items' => $items]);
        exit;
    }
}
