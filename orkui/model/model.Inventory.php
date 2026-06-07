<?php

class Model_Inventory extends Model
{
    public function __construct()
    {
        parent::__construct();
        $this->Inventory = new APIModel('Inventory');
    }

    public function get_owner_name($token, $ot, $oid)                 { return $this->Inventory->GetOwnerName($token, $ot, $oid); }
    public function get_revision($token, $ot, $oid)                   { return $this->Inventory->GetRevision($token, $ot, $oid); }
    public function get_summary($token, $ot, $oid, $f)               { return $this->Inventory->GetSummary($token, $ot, $oid, $f); }
    public function get_items($token, $ot, $oid, $f)                 { return $this->Inventory->GetItems($token, $ot, $oid, $f); }
    public function get_item($token, $ot, $oid, $id)                 { return $this->Inventory->GetItem($token, $ot, $oid, $id); }
    public function save_item($token, $data)                         { return $this->Inventory->SaveItem($token, $data); }
    public function remove_item($token, $ot, $oid, $id, $r, $n)      { return $this->Inventory->RemoveItem($token, $ot, $oid, $id, $r, $n); }
    public function restore_item($token, $ot, $oid, $id)            { return $this->Inventory->RestoreItem($token, $ot, $oid, $id); }
    public function delete_item($token, $ot, $oid, $id)            { return $this->Inventory->DeleteItem($token, $ot, $oid, $id); }
}
