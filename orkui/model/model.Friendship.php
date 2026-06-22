<?php

/**
 * Model_Friendship — thin pass-through to Ork3::$Lib->friendship.
 * No DB/SQL here; forwards to the lib (single source of $DB access).
 * Design: docs/superpowers/specs/2026-06-20-friends-system-design.md
 */
class Model_Friendship extends Model
{
    public function __construct()
    {
        parent::__construct();
        $this->Friendship = new APIModel('Friendship');
    }

    public function request($fromId, $toId)
    {
        return $this->Friendship->Request($fromId, $toId);
    }
    public function accept($userId, $otherId)
    {
        return $this->Friendship->Accept($userId, $otherId);
    }
    public function decline($userId, $otherId)
    {
        return $this->Friendship->Decline($userId, $otherId);
    }
    public function cancel($userId, $otherId)
    {
        return $this->Friendship->Cancel($userId, $otherId);
    }
    public function unfriend($userId, $otherId)
    {
        return $this->Friendship->Unfriend($userId, $otherId);
    }
    public function block($userId, $targetId)
    {
        return $this->Friendship->Block($userId, $targetId);
    }
    public function unblock($userId, $targetId)
    {
        return $this->Friendship->Unblock($userId, $targetId);
    }
    public function get_status($userId, $otherId)
    {
        return $this->Friendship->GetStatus($userId, $otherId);
    }
    public function are_friends($a, $b)
    {
        return $this->Friendship->AreFriends($a, $b);
    }
    public function get_friend_ids($userId)
    {
        return $this->Friendship->GetFriendIds($userId);
    }
    public function get_relationship_sets($userId)
    {
        return $this->Friendship->GetRelationshipSets($userId);
    }
    public function get_friends($userId, $limit = null, $offset = 0)
    {
        return $this->Friendship->GetFriends($userId, $limit, $offset);
    }
    public function count_friends($userId)
    {
        return $this->Friendship->CountFriends($userId);
    }
    public function get_pending_incoming($userId)
    {
        return $this->Friendship->GetPendingIncoming($userId);
    }
    public function get_pending_outgoing($userId)
    {
        return $this->Friendship->GetPendingOutgoing($userId);
    }
    public function get_activity_feed($userId, $limit = 30)
    {
        return $this->Friendship->GetActivityFeed($userId, $limit);
    }
}
