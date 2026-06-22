<?php

/**
 * Controller_Friend — "My Friends" hub (logged-in only).
 * Renders Friendnew_index.tpl with three tabs: Friends / Requests / Activity Feed.
 * First tab data is loaded server-side; tab switches + paging use FriendAjax.
 * Design: docs/superpowers/specs/2026-06-20-friends-system-design.md
 */
class Controller_Friend extends Controller
{
    // Signature must match base Controller::index($action = null) — PHP fatals on
    // an incompatible override (the route dispatcher constructs the method via Reflection).
    public function index($action = null)
    {
        $uid = isset($this->session->user_id) ? (int) $this->session->user_id : 0;
        if ($uid <= 0) {
            // Not logged in → bounce to login (match app convention for gated pages).
            header('Location: index.php?Route=Login');
            exit;
        }

        $this->load_model('Friendship');
        $friends  = $this->Friendship->get_friends($uid);
        $incoming = $this->Friendship->get_pending_incoming($uid);
        $outgoing = $this->Friendship->get_pending_outgoing($uid);

        $this->data['Friends']      = $friends['Friends'] ?? [];
        $this->data['Requests']     = $incoming['Requests'] ?? [];   // incoming
        $this->data['Sent']         = $outgoing['Requests'] ?? [];   // outgoing
        $this->data['FriendCount']  = $this->Friendship->count_friends($uid);
        $this->data['RequestCount'] = count($this->data['Requests']);
        $this->data['SentCount']    = count($this->data['Sent']);
        $this->data['Uid']          = $uid;

        $this->template = '../revised-frontend/Friendnew_index.tpl';
    }
}
