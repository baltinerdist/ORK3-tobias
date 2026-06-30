<?php

class Controller_ShortLinkAjax extends Controller
{
    public function __construct($call = null, $action = null)
    {
        parent::__construct($call, $action);
        $this->load_model('ShortLink');
    }

    /** POST: type, id, slug -> availability for the management UI. */
    public function check()
    {
        header('Content-Type: application/json');
        $uid  = (int)($this->session->user_id ?? 0);
        $type = strtolower(trim($_POST['type'] ?? ''));
        $id   = (int)($_POST['id'] ?? 0);
        $slug = (string)($_POST['slug'] ?? '');

        if (!$uid) {
            echo json_encode(['status' => 5, 'error' => 'Not logged in']);
            exit;
        }
        if (!$this->canEdit($uid, $type, $id)) {
            echo json_encode(['status' => 5, 'error' => 'Not authorized']);
            exit;
        }

        $r = $this->ShortLink->check($slug, $type, $id);
        echo json_encode(['status' => 0, 'available' => (bool)$r['available'], 'reason' => $r['reason']]);
        exit;
    }

    /** POST: type, id, slug (empty slug = reset to default). */
    public function save()
    {
        header('Content-Type: application/json');
        $uid  = (int)($this->session->user_id ?? 0);
        $type = strtolower(trim($_POST['type'] ?? ''));
        $id   = (int)($_POST['id'] ?? 0);
        $slug = trim((string)($_POST['slug'] ?? ''));

        if (!$uid) {
            echo json_encode(['status' => 5, 'error' => 'Not logged in']);
            exit;
        }
        if (!$this->canEdit($uid, $type, $id)) {
            echo json_encode(['status' => 5, 'error' => 'Not authorized']);
            exit;
        }

        if ($slug === '') {
            $this->ShortLink->release($type, $id);
            $stub = $this->ShortLink->derived($type, $id);
            echo json_encode(['status' => 0, 'stub' => $stub, 'url' => $this->meUrl($stub)]);
            exit;
        }

        $res = $this->ShortLink->set($type, $id, $slug, $uid);
        if (($res['Status'] ?? 1) === 0) {
            $stub = $res['Detail'];
            echo json_encode(['status' => 0, 'stub' => $stub, 'url' => $this->meUrl($stub)]);
        } else {
            echo json_encode(['status' => 1, 'error' => $res['Error'] ?? 'Could not save shortcut.']);
        }
        exit;
    }

    /** Authority gate per entity type. */
    private function canEdit($uid, $type, $id)
    {
        if (!valid_id($id)) {
            return false;
        }
        $auth = Ork3::$Lib->authorization;
        if ($auth->HasAuthority($uid, AUTH_ADMIN, 0, AUTH_ADMIN)) {
            return true;
        }
        switch ($type) {
            case 'player':  return $uid === (int)$id; // self only
            case 'kingdom': return $auth->HasAuthority($uid, AUTH_KINGDOM, (int)$id, AUTH_EDIT);
            case 'park':    return $auth->HasAuthority($uid, AUTH_PARK, (int)$id, AUTH_EDIT);
            case 'unit':    return $auth->HasAuthority($uid, AUTH_UNIT, (int)$id, AUTH_EDIT);
            default:        return false;
        }
    }

    /** Build the public short URL. Host from HTTP_UI config; strip /orkui/ suffix. */
    private function meUrl($stub)
    {
        $host = defined('HTTP_UI') ? preg_replace('#/orkui/?$#', '/', HTTP_UI) : '/';
        return $host . 'me/' . $stub;
    }
}
