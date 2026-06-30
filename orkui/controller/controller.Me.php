<?php

class Controller_Me extends Controller
{
    /** entity_type => canonical profile route prefix */
    private $routeMap = [
        'player'  => 'Player/profile/',
        'kingdom' => 'Kingdom/profile/',
        'park'    => 'Park/profile/',
        'unit'    => 'Unit/index/',
    ];

    public function __construct($call = null, $action = null)
    {
        parent::__construct($call, $action);
        $this->load_model('ShortLink');
    }

    public function go($stub = null)
    {
        $hit = $this->ShortLink->resolve($stub);
        if ($hit && isset($this->routeMap[$hit['type']])) {
            header('Location: ' . UIR . $this->routeMap[$hit['type']] . (int)$hit['id'], true, 302);
            exit;
        }
        // Miss: render a friendly not-found page (view() is called by the dispatcher).
        $this->template = '../revised-frontend/Me_notfound.tpl';
        $this->data['stub'] = htmlspecialchars((string)$stub, ENT_QUOTES);
        $this->data['search_url'] = UIR . 'Search/index';
        $this->data['home_url'] = HTTP_UI;
    }
}
