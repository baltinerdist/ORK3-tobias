<?php

/**
 * Model_Notification — thin pass-through to Ork3::$Lib->notification.
 *
 * No DB/SQL work lives here; it only forwards to the lib (the architecture's
 * single source of $DB access for ork_notification).
 *
 * Design: docs/superpowers/specs/2026-06-20-notifications-system-design.md
 */
class Model_Notification extends Model
{
    public function __construct()
    {
        parent::__construct();
        $this->Notification = new APIModel('Notification');
    }

    /** Single insert. $fields: title, body, icon, link_url, payload, created_by. */
    public function create($mundaneId, $type, array $fields)
    {
        return $this->Notification->Create($mundaneId, $type, $fields);
    }

    /** Fan-out insert for many recipients. */
    public function create_bulk(array $mundaneIds, $type, array $fields)
    {
        return $this->Notification->CreateBulk($mundaneIds, $type, $fields);
    }

    /** Recent non-dismissed notifications for a recipient, newest-first. */
    public function get_for_mundane($mundaneId, $limit = 15)
    {
        return $this->Notification->GetForMundane($mundaneId, $limit);
    }

    /** Unread, non-dismissed count for the badge. */
    public function unread_count($mundaneId)
    {
        return $this->Notification->UnreadCount($mundaneId);
    }

    /** Mark read: $ids array of notification_ids, or null = all unread for user. */
    public function mark_read($mundaneId, $ids = null)
    {
        return $this->Notification->MarkRead($mundaneId, $ids);
    }

    /** Dismiss a single notification (scoped to the recipient). */
    public function dismiss($mundaneId, $notificationId)
    {
        return $this->Notification->Dismiss($mundaneId, $notificationId);
    }

    /** Resolve active recipient mundane_ids for an announcement audience. */
    public function get_recipients_for_scope($scope, $scopeId = 0)
    {
        return $this->Notification->GetRecipientsForScope($scope, $scopeId);
    }
}
