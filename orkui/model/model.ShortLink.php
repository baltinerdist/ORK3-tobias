<?php

class Model_ShortLink extends Model
{
    public function resolve($stub)
    {
        return Ork3::$Lib->shortlink->Resolve($stub);
    }

    public function check($slug, $type, $id)
    {
        return Ork3::$Lib->shortlink->CheckAvailability($slug, $type, $id);
    }

    public function set($type, $id, $slug, $mundaneId)
    {
        return Ork3::$Lib->shortlink->SetStub($type, $id, $slug, $mundaneId);
    }

    public function release($type, $id)
    {
        return Ork3::$Lib->shortlink->ReleaseStub($type, $id);
    }

    public function get_stub($type, $id)
    {
        return Ork3::$Lib->shortlink->GetStubFor($type, $id);
    }

    public function derived($type, $id)
    {
        return Ork3::$Lib->shortlink->DerivedStub($type, $id);
    }
}
