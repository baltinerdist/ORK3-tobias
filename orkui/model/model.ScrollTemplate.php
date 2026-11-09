<?php

class Model_ScrollTemplate extends Model
{
    public function __construct($call = null, $method = null)
    {
        parent::__construct($call, $method);
        $this->ScrollTemplate = new APIModel('ScrollTemplate');
    }

    public function index()
    {

    }

    public function create($request)
    {
        return $this->ScrollTemplate->create($request);
    }

    public function get($id)
    {
        return $this->ScrollTemplate->get($id);
    }

    public function list_for_kingdom($kingdomId)
    {
        return $this->ScrollTemplate->listForKingdom($kingdomId);
    }

    public function update($id, $request)
    {
        return $this->ScrollTemplate->update($id, $request);
    }

    public function del($id)
    {
        return $this->ScrollTemplate->delete($id);
    }
}
